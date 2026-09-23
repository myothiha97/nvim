-- File outline — the IDE "Structure" pane (WebStorm Alt+7 / VS Code Outline).
--
-- Reuses trouble.nvim's `symbols` mode (already installed via LazyVim): no new plugin, and
-- nothing runs while the panel is CLOSED (Trouble drops its autocmds on close). While it is
-- OPEN, Trouble re-runs the `filter` below on every CursorMoved in the code window (20 ms
-- throttle), which is why the filter memoizes its result: a cursor move hands it the same
-- cached symbol list, so it returns the previous answer without looking at a single row.
--
-- Toggle with <leader>cs. Two display overrides: the followed-symbol row gets a band of its
-- own (CursorLine -> ListCursorLine, window-locally; code buffers have no band at all), and
-- JS/TS rows that vtsls mislabels as `Variable` get the icon their real role deserves (see
-- ROLE_KIND).
--
-- Shape: the panel opens as a flat list of the file's TOP-LEVEL declarations, like an IDE
-- structure pane. Everything a symbol contains is still in the tree, just folded: `za`
-- toggles a row, `zo`/`zc` open/close it, `zR`/`zM` open/close all. See apply_fold below for
-- why this cannot be done with `win.wo.foldlevel`.
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
--
-- One exception: an effect hook's callback (`useEffect() callback`, `useLayoutEffect() …`,
-- `React.useEffect() …`, a custom `useMountEffect()` / `useEffectOnce()` …). An effect is a
-- bare statement with no variable to carry it, so this row is the ONLY entry the component's
-- effect ever gets. `useCallback`/`useMemo` callbacks stay dropped: their variable row
-- already stands for them. So does `useEffectEvent`, which is bound to a variable too.
--
-- The object prefix must END IN A DOT (`React.`): a bare prefix would let `abuseEffect()`
-- through as a hook.
local function effect_hook_name(name)
  if type(name) ~= "string" then
    return nil
  end
  local hook = name:match("^(use%u[%w_%$]*)%(%)%s+callback$")
    or name:match("^[%w_%$%.]*%.(use%u[%w_%$]*)%(%)%s+callback$")
  if hook and hook:find("Effect", 1, true) and not hook:find("EffectEvent", 1, true) then
    return hook
  end
  return nil
end

local function is_placeholder_name(name)
  if type(name) ~= "string" or name == "" then
    return true
  end
  if effect_hook_name(name) then
    return false
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

-- The declaration is read as ONE string: its first line plus the lines after it, up to the
-- symbol's own end. A multi-line parameter list leaves the first line ending at `(`, and
-- Prettier can put the whole initializer on the next line (`const handler =`), so neither the
-- `=` nor the `=>` is guaranteed to share a line with the name. Capped: a declaration whose
-- head runs past this many lines is not worth reading.
local DECLARATION_SCAN_LINES = 10
local function declaration_text(buf, srow, erow)
  local first = get_line(buf, srow)
  local last = math.min(erow, srow + DECLARATION_SCAN_LINES)
  if not first or last <= srow then
    return first
  end
  local parts = { first }
  for row = srow + 1, last do
    parts[#parts + 1] = get_line(buf, row) or ""
  end
  return table.concat(parts, "\n")
end

-- vtsls reports `const submit = () => {}` with the SAME kind (Variable) and an empty `detail`
-- as `const LIMIT = 10`, so the kind cannot separate a function from a plain value. The only
-- signal left is the source, so classify the initializer: the text after the assignment.
--
-- Returns "type" for a `type` alias; "function" for `() => …`, `async (…) => …`, `x => …`,
-- `<T,>(v: T) => …` and `function (…) {}`; "hook" plus the hook's name for `useThing(…)` /
-- `useThing<T>(…)`; nil for everything else. Plain values MUST fall through, or
-- `[1, 2].map(n => n)`, `new Map()` and every string constant land in the outline and bury
-- the structure again.
local function js_variable_role(item)
  local range = item.symbol and item.symbol.range
  if not range then
    return nil
  end
  local text = declaration_text(item.buf, range.start.line, range["end"].line)
  if not text then
    return nil
  end
  -- vtsls reports `type AccountRow = { … }` as a Variable, like any other. A type alias is a
  -- declaration worth listing, and its right-hand side is an object literal, so it has to be
  -- recognised from the `type` keyword before the initializer is looked at.
  if text:match("^%s*type%s") or text:match("^%s*export%s+type%s") then
    return "type"
  end
  -- The ASSIGNMENT `=`, not the first `=` on the line: that one can sit inside `=>`, `==`,
  -- `<=`, `>=` or `!=`. In `const f: (e: T) => void = (e) => {}` the first `=` is the type
  -- annotation's arrow, and taking it made every function-typed const read as a plain value.
  local init = text:match("[^=!<>]=%s*([^=>%s].*)$")
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
  -- A parameter list is a BALANCED `(…)` followed directly by `=>` (or by a return type and
  -- then `=>`), after at most one generic list. Do NOT go back to "starts with `(` and an
  -- `=>` appears somewhere in the range": `const el = (<button onClick={() => go()} />)`,
  -- `const x = (items.map(n => n))` and `const el = <div onClick={() => go()} />` all pass
  -- that test and were listed as functions.
  local params = body:gsub("^%b<>%s*", "", 1)
  if params:match("^%b()%s*=>") or params:match("^%b()%s*:[^=]-=>") then
    return "function"
  end
  return nil
end

-- The kind a rescued role should RENDER as. vtsls sends every one of these as `Variable`,
-- so without this the outline paints a component, an arrow handler and a type alias with
-- the same glyph as `const LIMIT = 10`.
--
-- `hook` is deliberately absent: `const checkout = useCheckout()` really is a variable
-- holding a value, and its row is already labelled with the hook name. Same for the
-- component patterns the initializer cannot see (`memo(…)`, `styled.div`) -- they keep the
-- Variable icon rather than risk a wrong one.
local ROLE_KIND = {
  ["function"] = "Function",
  -- To a reader, a `type` alias and an `interface` are the same declaration.
  type = "Interface",
}

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

-- `vim.bo[buf].filetype` is an option lookup through a metatable, and the panel asks for it
-- ONCE PER ROW in three places (the filter, the icon, the label). Measured 2026-09-23: on a
-- 400-row panel it was 5.9 ms of the icon formatter's 6.4 ms -- 92% of the cost, for a value
-- that is identical on every row. The outline follows ONE buffer, so a one-entry cache keyed
-- on the buffer removes it.
--
-- Keyed on the buffer only, NOT on changedtick: a filetype does not change when you type. The
-- gap is `:set ft=` on the buffer being outlined with no edit and no buffer switch, which
-- would keep the previous verdict until either happens. Cosmetic, and not worth an always-on
-- FileType autocmd for a panel that is usually closed.
local ft_cache = {}
local function filetype_of(buf)
  buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
  if ft_cache.buf ~= buf then
    ft_cache = { buf = buf, ft = vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype or nil }
  end
  return ft_cache.ft
end

-- The role of a JS/TS Variable/Constant row, or nil for any other row. Three places ask (the
-- filter, the icon, the label), so the verdict is kept per item. Weak keys: Trouble builds new
-- items for every symbol fetch, so an old item's entry goes when the item does, and a new
-- revision of the file is always classified afresh.
local role_cache = setmetatable({}, { __mode = "k" })
local function js_role(item)
  local kind = item.kind
  if (kind ~= "Variable" and kind ~= "Constant") or not JS_FILETYPES[filetype_of(item.buf)] then
    return nil
  end
  local cached = role_cache[item]
  if not cached then
    local role, hook = js_variable_role(item)
    cached = { role = role, hook = hook }
    role_cache[item] = cached
  end
  return cached.role, cached.hook
end

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
-- time it renders. Trouble keeps fold state per node id, and a node it has never folded
-- renders OPEN, so every file shown for the first time in a view comes up fully expanded. So
-- fold once per (view, buffer), through the same view:fold_level() call the built-in
-- `zm`/`zr` actions use.
--
-- ONCE, not on every refresh: auto_refresh fires while you type and on every cursor move,
-- and re-folding there would collapse a function you had just opened. Coming back to a
-- buffer the view has already folded keeps whatever you opened in it.
--
-- Depth 2 is the filename node (measured: root, section, filename, symbol, ...), so folding
-- AT 2 keeps the declarations visible and folds what is inside them.
local DECLARATION_DEPTH = 2
local FOLD_RETRIES = 10
local FOLD_RETRY_MS = 30

-- view -> { [buf] = true } for every buffer that view has folded. Weak keys: Trouble builds a
-- NEW view each time the panel opens, so a closed view's marks are collected with it and a
-- reopened panel folds again. One global "last folded buffer" was the previous design, and it
-- skipped the fold on every reopen and after every empty first open.
local folded = setmetatable({}, { __mode = "k" })
local fold_pending = {} -- buf -> true while an apply_fold chain for it is queued

local function open_symbol_views()
  return require("trouble.view").get({ mode = "symbols", open = true })
end

local function is_folded(view, buf)
  local marks = folded[view]
  return marks ~= nil and marks[buf] == true
end

-- WARN: SILENT FAILURE. Fold only once the view has RENDERED the tree its section built
-- last, and that tree is `buf`'s. The filter runs before Trouble builds and renders the new
-- tree, and both steps are scheduled, so at the moment a fold is first attempted the window
-- still shows the PREVIOUS tree. Folding then (checking `max_depth > 0` was the old test)
-- folds the old buffer's nodes, the new ones render open, and nothing reports it.
local function shows_latest_tree_of(view, buf)
  local section = view.sections and view.sections[1]
  local built = section and section.node and section.node.children[1]
  local shown = view.renderer and view.renderer.root_nodes[1]
  return built ~= nil and shown == built and built.item ~= nil and built.item.buf == buf
end

local function apply_fold(buf, tries)
  fold_pending[buf] = nil
  local waiting = false
  for _, v in ipairs(open_symbol_views()) do
    local view = v.view
    if not is_folded(view, buf) then
      if not shows_latest_tree_of(view, buf) then
        waiting = true
      elseif view.renderer.max_depth > DECLARATION_DEPTH then
        view:fold_level({ level = DECLARATION_DEPTH })
        folded[view] = folded[view] or {}
        folded[view][buf] = true
      end
      -- Otherwise nothing is nested yet, and fold_level would clamp to a level that hides
      -- the declarations themselves. Left UNMARKED, so the first nesting an edit adds is
      -- still folded.
    end
  end
  if waiting and tries > 0 then
    fold_pending[buf] = true
    vim.defer_fn(function()
      apply_fold(buf, tries - 1)
    end, FOLD_RETRY_MS)
  end
end

-- Called from the filter on every refresh, so the common case (already folded) must cost no
-- more than one lookup per open symbols view.
local function request_fold(buf)
  if fold_pending[buf] then
    return
  end
  for _, v in ipairs(open_symbol_views()) do
    if not is_folded(v.view, buf) then
      fold_pending[buf] = true
      vim.schedule(function()
        apply_fold(buf, FOLD_RETRIES)
      end)
      return
    end
  end
end

-- WARN: SILENT FAILURE. Trouble keys fold state by node id, and the LSP source builds that id
-- from the symbol's POSITION (sources/lsp.lua: buf|row|col|end_row|end_col|kind). Adding one
-- line at the top of the file therefore gave every symbol below it a new id, and a node
-- Trouble has never seen renders OPEN: the whole outline unfolded after an import was added,
-- with no error. Do not drop this pass, or put a position back into the id.
--
-- So replace the id with the symbol's PATH: buffer, then each ancestor's `kind:name`, plus a
-- counter for siblings that share one (two `useEffect() callback`s in a component). Edits
-- that move a symbol keep its id, and with it both the fold and anything you opened.
-- Deterministic, so running it again over the same cached items changes nothing. Trouble's
-- other id users stay correct: `follow` matches rows by range, not id, and restoring the
-- cursor row after a render compares ids, which are now more stable than before.
local function assign_path_ids(items)
  local ids = {} ---@type table<table, string>
  local count = {} ---@type table<string, number>
  local function path_id(item)
    local id = ids[item]
    if id then
      return id
    end
    local parent = item.parent
    local base = (parent and path_id(parent) or tostring(item.buf))
      .. "/"
      .. tostring(item.kind)
      .. ":"
      .. tostring(item.symbol and item.symbol.name)
    local n = (count[base] or 0) + 1
    count[base] = n
    id = n == 1 and base or (base .. "#" .. n)
    ids[item] = id
    return id
  end
  for _, item in ipairs(items) do
    item.id = path_id(item)
  end
end

-- The filter proper; see the `filter` option for when it runs.
local function filter_symbols(items)
  assign_path_ids(items)
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

  -- `const handlers = { async credit() {}, debit() {} }` is a module's structure in Node
  -- code, but its kind is Variable and its initializer is an object literal, so only its
  -- contents give it away. Placeholder callbacks do NOT count: `const doubled =
  -- [1, 2].map(n => n)` has a `map() callback` child, and counting it listed every value
  -- computed with a callback.
  local function has_callable_child(item)
    for _, child in ipairs(children[item] or {}) do
      local kind = child.kind
      if
        (kind == "Function" or kind == "Method" or kind == "Constructor")
        and not is_placeholder_name(child.symbol and child.symbol.name)
      then
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
    -- Functions, types, hooks and React components all arrive as Variable/Constant from
    -- vtsls (arrow functions, type aliases, call results), so rescue those and let plain
    -- values fall through. JS/TS only, see JS_FILETYPES.
    local filetype = filetype_of(item.buf)
    if JS_FILETYPES[filetype] and (item.kind == "Variable" or item.kind == "Constant") then
      if js_role(item) ~= nil or has_callable_child(item) then
        return true
      end
      if JSX_FILETYPES[filetype] and is_component_name(name) then
        return true
      end
      -- Level 2 is "show me the data shapes too": a variable holding an object is worth a
      -- row once its members are being listed.
      return level >= 2 and children[item] ~= nil
    end
    return false
  end

  -- Only the top level is judged: a kept declaration keeps its whole subtree, so the folds
  -- stay useful. The recursion matters as much in the other direction. A child whose parent
  -- was dropped must go too, or the members of a filtered-out object (`module.exports =
  -- { … }`, a zod schema) are re-parented to the root and show up as bogus top-level rows,
  -- duplicating the real declarations.
  local kept = {}
  local function keep(item)
    if kept[item] == nil then
      if item.parent == nil then
        kept[item] = keep_top_level(item)
      else
        local name = item.symbol and item.symbol.name
        kept[item] = keep(item.parent) and not (STRUCTURE_KINDS[item.kind] and is_placeholder_name(name))
      end
    end
    return kept[item]
  end

  return vim.tbl_filter(keep, items)
end

-- One-entry memo of the last filter result. Trouble caches a buffer's symbol list until the
-- next edit (sources/lsp.lua: Cache.symbols, cleared on TextChanged) and hands the filter
-- that SAME table on every cursor-move refresh, so table identity plus the level is a
-- complete key. Measured on a 3300-symbol file: 2.4 ms per cursor move without it.
-- Trouble sorts the returned table IN PLACE (sort.lua), which is harmless here: the same
-- rows sorted by the same keys again.
local filter_memo = {}

-- Items the panel may hold, counted AFTER the filter and including every folded child.
-- Trouble's default is 200, and every nested local of a kept declaration counts toward it
-- even while folded: a 2700-line file stopped at line ~200 with nothing to say so.
--
-- Measured 2026-09-24 (per cursor-move refresh + render, median): the largest real file in
-- the work repos (3905 lines, 1707 symbols) costs ~4 ms at level 3 against ~2.5 ms capped at
-- 200. The cost follows VISIBLE rows, not this number, so it only bites on a file with
-- thousands of top-level declarations: a synthetic 3300-symbol file with 900 of them costs
-- ~12 ms at level 1. 3000 leaves ~1.75x headroom over the largest real file.
local MAX_ITEMS = 3000

return {
  "folke/trouble.nvim",
  opts = {
    modes = {
      symbols = {
        win = {
          position = "right",
          size = 0.28, -- dock right, ~28% of editor width
          wo = {
            -- `follow` marks the current symbol via cursorline. The editor's own CursorLine
            -- is empty (off since 2026-09-23, colorschemes/solarized-osaka/init.lua), so
            -- without a remap the followed row would not be marked at all. Remap it to the
            -- shared list band for this panel only; code buffers stay band-free.
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
        max_items = MAX_ITEMS, -- see MAX_ITEMS: Trouble's own 200 cut big files short
        -- Default level 1 (structure only). `a` cycles the detail level; see the top comment.
        -- Runs on EVERY refresh (cursor moves included) while the panel is open.
        filter = function(items)
          if filter_memo.items ~= items or filter_memo.level ~= level then
            filter_memo = { items = items, level = level, result = filter_symbols(items) }
          end
          -- Only once there is something to fold: before the LSP answers the list is empty,
          -- and marking that as "folded" is what left the real symbols open afterwards.
          if #filter_memo.result > 0 then
            request_fold(vim.api.nvim_get_current_buf())
          end
          return filter_memo.result
        end,
        keys = {
          a = {
            desc = "Outline: cycle detail level (structure / +members / all)",
            action = function(view)
              level = level % 3 + 1
              -- The new level reveals rows the fold never saw, and those render OPEN. Forget
              -- every buffer this view folded, not only the current one: the level applies
              -- to all of them, so each would otherwise come back with its new rows open.
              folded[view] = nil
              view:refresh()
              vim.notify("Outline: " .. LEVEL_LABEL[level], vim.log.levels.INFO)
            end,
          },
        },
        -- Trim each row to icon + name (the default also appends the signature + [pos], which
        -- overflow a narrow panel). Empty-named symbols fall back to their signature text.
        format = "{kind_icon} {symbol.name}",
        formatters = {
          -- The default `kind_icon` reads `item.kind`, which vtsls sets to Variable for
          -- arrow functions, components and `type` aliases alike. `js_role` has already
          -- classified the row for the filter above, so reuse that verdict here and the icon
          -- says what the filter decided. Non-JS rows and unclassified variables fall
          -- through to exactly the built-in behaviour (format.lua: kind_icon).
          ["kind_icon"] = function(ctx)
            local item = ctx.item
            local kind = item.kind
            if not kind then
              return
            end
            kind = ROLE_KIND[js_role(item)] or kind
            local icon = ctx.opts.icons.kinds[kind]
            if icon then
              return { text = icon, hl = "TroubleIcon" .. kind }
            end
          end,
          ["symbol.name"] = function(ctx)
            local name = ctx.value
            local item = ctx.item
            -- Label a hook row with the hook, then the variable it binds (dimmed): the useful
            -- identity of `const checkout = useRecurringCheckout()` is the hook, but the name
            -- is what you search the file for, so show both.
            local role, hook = js_role(item)
            if role == "hook" and hook ~= name then
              return { { text = hook }, { text = "  " .. tostring(name), hl = "Comment" } }
            end
            -- `useEffect() callback` reads as a placeholder; the hook name is the identity.
            local effect = effect_hook_name(name)
            if effect then
              return effect
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
