-- File outline — the IDE "Structure" pane (WebStorm Alt+7 / VS Code Outline).
--
-- Reuses trouble.nvim's `symbols` mode (already installed via LazyVim): no new plugin, and
-- nothing runs on the scroll/keypress hot path — the panel only works while it's open and
-- Trouble throttles its own updates. Safe for big files.
--
-- Toggle with <leader>cs. The ONLY display override is making the followed-symbol highlight
-- visible (your themes set the global CursorLine bg to NONE, which hides Trouble's marker).
--
-- Shape: the panel opens as a flat list of the file's TOP-LEVEL declarations, like an IDE
-- structure pane. Everything a symbol contains is still in the tree, just folded: `za`
-- toggles a row, `zo`/`zc` open/close it, `zR`/`zM` open/close all. See fold_to_declarations
-- below for why this cannot be done with `win.wo.foldlevel`.
--
-- Filtering applies to the TOP LEVEL ONLY; once a declaration is kept, all of its children
-- come with it, so expanding a function shows whatever the server reports inside it. Three
-- detail levels control how permissive that top level is, cycled by pressing `a`:
--   1. STRUCTURE (default) — callables and containers: functions, methods, classes, structs,
--      interfaces, plus JS/TS arrow functions, React hooks and components. No loose data.
--   2. + MEMBERS     — level 1 plus fields, properties, enum members, and JS/TS variables
--      holding an object (a zod schema, `module.exports`), so data shapes get a row too.
--   3. ALL           — everything the LSP reports, unfiltered.
-- `a` steps 1 → 2 → 3 → 1.
--
-- Per-language reality (measured, not assumed):
--   Go (gopls)    — reports package-level declarations and struct fields / interface methods
--                   only. It does NOT report locals, so expanding a func shows nothing. That
--                   is a server limit, not a filter: `zR` on a Go file proves it.
--   TS/JS (vtsls) — reports nested locals, so expanding a function or component works.

-- Level 1: structural symbols only — callables + type/containers. Package is dropped on
-- purpose (file/package declaration + lua_ls control-flow blocks: never a useful entry).
local STRUCTURE_KINDS = {
  Class = true,
  Constructor = true,
  Enum = true,
  Function = true,
  Interface = true,
  Method = true,
  Module = true,
  Namespace = true,
  Struct = true,
  Trait = true,
}

-- Level 2 adds these on top of STRUCTURE_KINDS: object/class members (the shape of a type),
-- but deliberately NOT Variable/Constant — loose locals only appear at level 3.
local MEMBER_KINDS = {
  EnumMember = true,
  Field = true,
  Property = true,
}

-- vtsls reports every anonymous arrow function as a Function symbol, but names it with a
-- placeholder: `<function>`, `<unknown>`, or `<call>() callback` for callbacks passed inline.
-- Those rows carry no information (WebStorm's Structure pane hides them too), yet their kind
-- is Function, so they slipped past STRUCTURE_KINDS and buried the real structure at level 1.
-- Dropped at levels 1 and 2; level 3 is deliberately unfiltered, so they still appear there.
local function is_placeholder_name(name)
  if type(name) ~= "string" or name == "" then
    return true
  end
  -- `<function>`, `<unknown>`, `<class>`, ... : any fully bracketed placeholder.
  if name:match("^<.*>$") then
    return true
  end
  -- `setValues() callback`, `providersList.manualPaymentMethods.find() callback`.
  return name:match("%(%)%s+callback$") ~= nil
end

-- Reading source text is the only way to classify a JS/TS variable (see js_variable_role),
-- so keep it to ONE nvim_buf_get_lines per buffer revision. The outline follows a single
-- buffer at a time, which makes a one-entry cache keyed on changedtick enough.
local line_cache = {}
local function get_line(buf, row) -- row is 0-indexed, as in an LSP range
  buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
  if not vim.api.nvim_buf_is_valid(buf) then
    return nil
  end
  local tick = vim.api.nvim_buf_get_changedtick(buf)
  if line_cache.buf ~= buf or line_cache.tick ~= tick then
    line_cache = { buf = buf, tick = tick, lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false) }
  end
  return line_cache.lines[row + 1]
end

-- A multi-line parameter list leaves the first line ending at `(`, with the `=>` further down,
-- so the arrow is looked for across the symbol's range. Capped: a declaration whose parameters
-- run past this many lines is not worth a buffer scan on every refresh.
local ARROW_SCAN_LINES = 10
local function range_has_arrow(buf, srow, erow)
  for row = srow, math.min(erow, srow + ARROW_SCAN_LINES) do
    local line = get_line(buf, row)
    if line and line:find("=>", 1, true) then
      return true
    end
  end
  return false
end

-- vtsls reports `const submit = () => {}` with the SAME kind (Variable) and an empty `detail`
-- as `const LIMIT = 10`, so the kind cannot separate a function from a plain value. The only
-- signal left is the source, so classify the initializer: the text after the first `=`.
--
-- Returns "function" for `() => …`, `async (…) => …`, `x => …` and `function (…) {}`;
-- "hook" plus the hook's name for `useThing(…)` / `useThing<T>(…)`; nil for everything else.
-- Plain values MUST fall through, or `[1, 2].map(n => n)`, `new Map()` and every string
-- constant land in the outline and bury the structure again.
local function js_variable_role(item)
  local range = item.symbol and item.symbol.range
  if not range then
    return nil
  end
  local srow = range.start.line
  local line = get_line(item.buf, srow)
  if not line then
    return nil
  end
  -- vtsls reports `type AccountRow = { … }` as a Variable, like any other. A type alias is a
  -- declaration worth listing, and its right-hand side is an object literal, so it has to be
  -- recognised from the `type` keyword before the initializer is looked at.
  if line:match("^%s*type%s") or line:match("^%s*export%s+type%s") then
    return "type"
  end
  local init = line:match("=%s*(%S.*)$")
  if not init then
    return nil
  end
  -- `const checkout = useRecurringCheckout()`: the row worth showing is the HOOK, not the
  -- variable it lands in. This is the entry WebStorm's Structure pane lists.
  local hook = init:match("^(use%u[%w_%$]*)%s*[%(<]")
  if hook then
    return "hook", hook
  end
  local body = init:gsub("^async%f[%W]%s*", "")
  if body:match("^function%f[%W]") or body:match("^[%w_%$]+%s*=>") then
    return "function"
  end
  -- `^%(` is a parameter list, `^<` a generic one (`const identity = <T,>(v: T) => v`).
  -- Both need the arrow confirmed across the range, or `const total = (base * 2)` and a
  -- JSX-valued const would pass as functions.
  if (body:match("^%(") or body:match("^<")) and range_has_arrow(item.buf, srow, range["end"].line) then
    return "function"
  end
  return nil
end

-- PascalCase, and NOT SCREAMING_CASE: `^%u` alone also matched `ROUTE_PREFIX` and `API_URL`,
-- which are plain constants, not components.
local function is_component_name(name)
  return type(name) == "string" and name:match("^%u") ~= nil and name:match("^[%u%d_%$]+$") == nil
end

-- The Variable/Constant rescue is JS/TS-specific: only there do functions, hooks and
-- components arrive as Variable. Gating it to these filetypes stops e.g. Go's exported
-- (PascalCase) package vars/consts from leaking into the structure view. gopls and
-- basedpyright already report every callable as Function/Method, so they need none of it.
local JS_FILETYPES = {
  javascript = true,
  javascriptreact = true,
  typescript = true,
  typescriptreact = true,
}

-- The PascalCase rule is for component patterns the initializer test cannot see: `styled.div`,
-- `memo(…)`, `forwardRef(…)`. Plain arrow components already match as "function". Restricted
-- to JSX files because in Node code PascalCase Variables are destructured imports
-- (`const { Pool } = require('pg')`, `const { Router } = require('express')`), which are noise.
local JSX_FILETYPES = {
  javascriptreact = true,
  typescriptreact = true,
}

-- Current detail level (1/2/3); cycled by `a`, read by the symbols `filter` on every refresh.
local level = 1
local LEVEL_LABEL = {
  [1] = "structure (functions / classes / components)",
  [2] = "+ fields & properties",
  [3] = "all symbols (incl. variables)",
}

-- Remove the quickfix row(s) under the cursor (or visual selection) from the ACTUAL
-- quickfix list, not just Trouble's in-memory tree. Trouble's built-in `dd`/`delete`
-- only filters its own tree (view/tree.lua: node:delete()), so the entry returns the
-- moment the list is re-read on reopen. We prune the live list + persisted state, then
-- refresh — which re-fetches the now-smaller qflist source (view/section.lua: refresh).
local function remove_from_qflist(view)
  local targets = {}
  local function collect(node)
    local item = node.item
    -- Leaf rows carry the entry; filename group headers don't — recurse into them so a
    -- `dd` on a header removes all of that file's entries too.
    if item and (not node.children or #node.children == 0) then
      targets[#targets + 1] = {
        bufnr = item.buf,
        filename = item.filename,
        lnum = item.pos and item.pos[1] or nil,
        text = item.text,
      }
    end
    for _, child in ipairs(node.children or {}) do
      collect(child)
    end
  end

  for _, node in ipairs(view:selection()) do
    collect(node)
  end

  require("config.quickfix-persistence").remove(targets)
  view:refresh()
end

-- Open the panel as a flat list of declarations, expandable on demand.
--
-- `win.wo.foldlevel` does NOT work here: Trouble merges its own Window.FOLDS (foldlevel = 99)
-- over the user's win opts with "force" (view/init.lua), so the option is always 99 by the
-- time it renders. Its fold state is also keyed by node id, and symbol node ids contain the
-- buffer and range, so every new file re-renders fully expanded no matter what was folded
-- before. So re-apply the fold level per file, through the same view:fold_level() call the
-- built-in `zm`/`zr` actions use.
--
-- The filter is the only config hook that runs on every refresh, which makes it the hook.
-- Folding ONLY when the buffer changed matters: auto_refresh fires while you type, and
-- re-folding there would collapse a function you had just opened.
--
-- Depth 2 is the filename node (measured: root, section, filename, symbol, ...), so folding
-- AT 2 keeps the declarations visible and folds what is inside them.
local DECLARATION_DEPTH = 2
local FOLD_RETRIES = 10
local folded_buf = nil

-- The tree is built during render, which happens AFTER the refresh that runs the filter, so
-- folding immediately hits an empty tree: fold_level clamps against max_depth (0 at that
-- point), lands on 0, and because Trouble only auto-folds while renderer.foldlevel is nil,
-- every later render then keeps the file fully expanded. So retry until nodes exist.
local function apply_fold(tries)
  for _, v in ipairs(require("trouble.view").get({ mode = "symbols", open = true })) do
    local view = v.view
    local depth = type(view) == "table" and view.renderer and view.renderer.max_depth or 0
    if depth == 0 then
      break -- not rendered yet
    elseif depth > DECLARATION_DEPTH then
      view:fold_level({ level = DECLARATION_DEPTH })
      return
    else
      return -- nothing nested in this file; folding here would hide the declarations
    end
  end
  if tries > 0 then
    vim.defer_fn(function()
      apply_fold(tries - 1)
    end, 30)
  end
end

local function fold_to_declarations(buf)
  if buf == folded_buf then
    return
  end
  folded_buf = buf
  vim.schedule(function()
    apply_fold(FOLD_RETRIES)
  end)
end

return {
  "folke/trouble.nvim",
  opts = {
    modes = {
      symbols = {
        win = {
          position = "right",
          size = 0.28, -- dock right, ~28% of editor width
          wo = {
            -- `follow` marks the current symbol via cursorline. The editor's own band is a
            -- dim teal tuned to stay under text (colorschemes/solarized-osaka/init.lua); in a
            -- one-column list the followed row has to POP, so remap CursorLine to the shared
            -- list band for this panel only, leaving code buffers on the quiet band.
            --
            -- `ListCursorLine`, NOT `Visual`: this pointed at `Visual` until 2026-09-23, which
            -- meant retuning the selection colour silently repainted the outline and every
            -- snacks picker with it. The panels now share one group of their own.
            cursorline = true,
            cursorlineopt = "line",
            winhighlight = "CursorLine:ListCursorLine",
            -- Hybrid line numbers for count-jumps (7j / 8k) after focusing the panel (<C-w>l).
            number = true,
            relativenumber = true,
          },
        },
        -- focus=false keeps your cursor in the code so the panel can FOLLOW you and the
        -- highlight tracks as you move. (focus=true would jump into the panel, freezing it.)
        focus = false,
        follow = true,
        auto_refresh = true,
        -- Default level 1 (structure only). `a` cycles the detail level; see the top comment.
        filter = function(items)
          fold_to_declarations(vim.api.nvim_get_current_buf())
          if level >= 3 then
            return items
          end
          -- Trouble hands the filter a FLAT list; `item.parent` carries the LSP nesting, and
          -- `add_child` only sets that back-pointer, so build the forward map here.
          local children = {}
          for _, item in ipairs(items) do
            local parent = item.parent
            if parent then
              children[parent] = children[parent] or {}
              table.insert(children[parent], item)
            end
          end

          -- `const handlers = { async credit() {}, debit() {} }` is a module's structure in
          -- Node code, but its kind is Variable and its initializer is an object literal, so
          -- only its contents give it away.
          local function has_callable_child(item)
            for _, child in ipairs(children[item] or {}) do
              if child.kind == "Function" or child.kind == "Method" or child.kind == "Constructor" then
                return true
              end
            end
            return false
          end

          local function keep_top_level(item)
            local name = item.symbol and item.symbol.name
            if STRUCTURE_KINDS[item.kind] then
              return not is_placeholder_name(name)
            end
            if level >= 2 and MEMBER_KINDS[item.kind] then
              return true
            end
            -- Functions, types, hooks and React components all arrive as Variable/Constant
            -- from vtsls (arrow functions, type aliases, call results), so rescue those and
            -- let plain values fall through. JS/TS only, see JS_FILETYPES.
            local filetype = vim.bo[item.buf or 0].filetype
            if JS_FILETYPES[filetype] and (item.kind == "Variable" or item.kind == "Constant") then
              if js_variable_role(item) ~= nil or has_callable_child(item) then
                return true
              end
              if JSX_FILETYPES[filetype] and is_component_name(name) then
                return true
              end
              -- Level 2 is "show me the data shapes too": a variable holding an object is
              -- worth a row once its members are being listed.
              return level >= 2 and children[item] ~= nil
            end
            return false
          end

          -- Only the top level is judged: a kept declaration keeps its whole subtree, so the
          -- folds stay useful. The recursion matters as much in the other direction. A child
          -- whose parent was dropped must go too, or the members of a filtered-out object
          -- (`module.exports = { … }`, a zod schema) are re-parented to the root and show up
          -- as bogus top-level rows, duplicating the real declarations.
          local memo = {}
          local function keep(item)
            if memo[item] == nil then
              if item.parent == nil then
                memo[item] = keep_top_level(item)
              else
                local name = item.symbol and item.symbol.name
                memo[item] = keep(item.parent)
                  and not (STRUCTURE_KINDS[item.kind] and is_placeholder_name(name))
              end
            end
            return memo[item]
          end

          return vim.tbl_filter(keep, items)
        end,
        keys = {
          a = {
            desc = "Outline: cycle detail level (structure / +members / all)",
            action = function(view)
              level = level % 3 + 1
              view:refresh()
              vim.notify("Outline: " .. LEVEL_LABEL[level], vim.log.levels.INFO)
            end,
          },
        },
        -- Trim each row to icon + name (the default also appends the signature + [pos], which
        -- overflow a narrow panel). Empty-named symbols fall back to their signature text.
        format = "{kind_icon} {symbol.name}",
        formatters = {
          ["symbol.name"] = function(ctx)
            local name = ctx.value
            local item = ctx.item
            -- Label a hook row with the hook, then the variable it binds (dimmed): the useful
            -- identity of `const checkout = useRecurringCheckout()` is the hook, but the name
            -- is what you search the file for, so show both.
            if
              JS_FILETYPES[vim.bo[item.buf or 0].filetype]
              and (item.kind == "Variable" or item.kind == "Constant")
            then
              local role, hook = js_variable_role(item)
              if role == "hook" and hook ~= name then
                return { { text = hook }, { text = "  " .. tostring(name), hl = "Comment" } }
              end
            end
            if type(name) == "string" and name ~= "" then
              return name
            end
            local text = ctx.item.text
            if type(text) == "string" and text ~= "" then
              return { { text = text, hl = "Comment" } }
            end
            return { { text = "<anonymous>", hl = "Comment" } }
          end,
        },
      },
      -- Quickfix list (you use it as code pins, harpoon-style). Rebind delete so it
      -- removes the entry from the real list + persisted state, not just the tree.
      qflist = {
        keys = {
          dd = {
            desc = "Remove from quickfix (live + persisted)",
            action = remove_from_qflist,
          },
          d = {
            mode = "v",
            desc = "Remove from quickfix (live + persisted)",
            action = remove_from_qflist,
          },
        },
      },
    },
  },
}
