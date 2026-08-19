-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
--

-- Doc floats keep smoothscroll ON (global default, see options.lua) so long
-- wrapped text scrolls one screen row per <C-e>/<C-y> — never a whole block at
-- once. smoothscroll's cost is the hardcoded 3-cell `<<<` marker (hl-NonText; not
-- disableable in 0.12 — verified: no fillchars/option exists, see neovim #8715)
-- drawn at window column 1 whenever a wrapped line is partially scrolled. The
-- marker REPLACES the text in its cells (there's no layer underneath, so opacity
-- can't reveal it), so we handle it with two settings working together:
--   1. foldcolumn = `pad` (>= 3): a left gutter the marker parks in, so it never
--      eats doc text.
--   2. hide_float_marker(): recolour NonText -> float bg so the `<<<` renders
--      blank, turning the gutter into clean Zed-style left padding instead of a
--      visible marker column (FoldColumn is also blended into the float bg).
-- Net: smooth per-row scrolling, no visible marker, zero blocked text — at the
-- cost of a constant 3-cell left padding.
--
-- Theme-coupled: the hide colour must match the float bg, so recompute on
-- ColorScheme. The gutter (pad >= 3) is the safety net: even if a transparent-bg
-- theme makes the hide a no-op, the marker is in padding, so text is never eaten.
local function sync_float_nontext_hl()
  local function bg_of(name)
    local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
    return hl and hl.bg
  end
  -- LspDocFloat first: doc floats are remapped onto that surface by
  -- style_doc_float() below, so it -- not NormalFloat -- is the background the
  -- marker has to disappear into. Falls back for any float we don't restyle.
  local bg = bg_of("LspDocFloat") or bg_of("NormalFloat") or bg_of("Normal")
  if bg then
    -- fg == bg: the glyph is painted in the background colour, i.e. invisible.
    vim.api.nvim_set_hl(0, "FloatNonTextHidden", { fg = bg, bg = bg })
  end
end
sync_float_nontext_hl()
-- Named augroup (clear = true) so re-sourcing keymaps.lua can't stack duplicate
-- callbacks — shared by the ColorScheme refresh and the blink doc hook below.
local float_doc_grp = vim.api.nvim_create_augroup("float_doc_ui", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", { group = float_doc_grp, callback = sync_float_nontext_hl })

-- Neutralise the `<<<` marker in `win`: remap NonText to the float bg (so the
-- glyph renders invisibly) and FoldColumn to NormalFloat (so the gutter reads as
-- plain padding, not a tinted strip). Append so we keep whatever winhighlight the
-- float already set (e.g. Normal:NormalFloat); guard against duplicate entries on
-- the focus-reuse / blink re-open paths.
local function hide_float_marker(win)
  local wh = vim.wo[win].winhighlight
  if not wh:find("FloatNonTextHidden", 1, true) then
    -- FoldColumn -> LspDocFloat, not NormalFloat: both callers (LSP doc floats
    -- and blink's doc popup) now sit on the base03 surface, so pointing the
    -- gutter at NormalFloat's bg would paint a visibly darker strip beside the
    -- text instead of blending into plain padding.
    local add = "NonText:FloatNonTextHidden,FoldColumn:LspDocFloat"
    vim.wo[win].winhighlight = (wh ~= "" and wh .. "," or "") .. add
  end
end

-- Put `win` on the dedicated LSP-documentation surface (defined in
-- lua/colorschemes/solarized-osaka/init.lua). The colours live in the theme; this is
-- only the mechanism that scopes them to doc floats, so the Snacks picker and
-- the blink completion menu -- which share NormalFloat / bg_float -- are left
-- untouched. Same append-and-guard shape as hide_float_marker above.
local function style_doc_float(win)
  local wh = vim.wo[win].winhighlight
  -- Guard on the full `Normal:LspDocFloat` pair, not the bare group name:
  -- hide_float_marker() above also writes `FoldColumn:LspDocFloat`, and on a
  -- wrapping float it runs FIRST, so a bare-name check would see that entry and
  -- skip the surface entirely.
  if not wh:find("Normal:LspDocFloat", 1, true) then
    -- The last two entries remap TREESITTER capture groups, which winhighlight
    -- handles the same as any other group. That is what keeps the inline-code
    -- restyle scoped to doc floats: @markup.raw.markdown_inline is also every
    -- inline span in a real .md file, and those keep the theme's own colours.
    -- RenderMarkdownCodeInline is listed defensively -- render-markdown attaches
    -- to these floats (their filetype is markdown) and paints inline code itself
    -- on some versions; the entry is a no-op when it does not.
    local add = "Normal:LspDocFloat,NormalFloat:LspDocFloat,FloatBorder:LspDocBorder,FloatTitle:LspDocTitle"
      .. ",@markup.raw.markdown_inline:LspDocInlineCode,RenderMarkdownCodeInline:LspDocInlineCode"
    vim.wo[win].winhighlight = (wh ~= "" and wh .. "," or "") .. add
  end
end

-- The `<<<` marker only ever appears on a WRAPPED line, so the padding gutter is
-- only worth reserving when content actually wraps. Short LSP info (type defs,
-- object shapes) fits within `width` on every line — there the gutter is just an
-- ugly dead strip. Return true iff any line's display width exceeds `width`, i.e.
-- the float will wrap at least one row and could show the marker.
local function float_content_wraps(bufnr, width)
  if not width or width <= 0 then
    return false
  end
  for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    if vim.fn.strdisplaywidth(line) > width then
      return true
    end
  end
  return false
end
-- Put back the gap between a signature block and the prose that describes it.
--
-- Servers emit the signature as a fenced block with the description on the very
-- next line. VSCode renders that to HTML, where the `<pre>` gets a CSS margin
-- for free. A cell grid has no margins, and render-markdown's
-- `code.border = "hide"` (plugins/render-markdown.lua) conceals the closing
-- fence with `conceal_lines`, which removes the ROW rather than blanking it --
-- so the description ends up welded to the last line of the signature. A blank
-- line is the only unit of vertical space a grid actually has.
--
-- Only after a CLOSING fence, and only when real text follows: that skips the
-- trailing fence of a signature-help popup (nothing after it) and never doubles
-- a gap the server already sent. Builds a new table rather than mutating, so the
-- caller's `contents` is untouched. One pass over ~10-40 lines, once per popup
-- open -- not a hot path.
-- NOTE: a top/bottom padding row was built here on 2026-08-09 and REMOVED the
-- same day. Recorded because the obvious way to add it does not work and the
-- reason it was dropped is not a bug:
--   * `""` cannot be the padding row. `_normalize_markdown` trims exactly-empty
--     lines off the head and tail (measured: 7 lines in, 6 out). A line holding
--     one SPACE survives, because only truly empty lines are trimmed.
--   * It has to go in `contents`, not into the window afterwards, so that
--     open_floating_preview sizes and positions the float with the padding
--     counted. Resizing after the fact can push a float off screen.
--   * It cannot be made thinner. Vertical space on a cell grid is quantised to
--     whole rows -- `nvim_open_win` takes height in cells, there is no pixel or
--     fractional unit -- so one row is the floor, and one row read as too tall.
-- Dropped to zero by choice. The gap after the code fence below is kept: that
-- one separates two things, rather than padding the frame.
local function space_after_code_fences(contents)
  local out, in_fence = {}, false
  for i = 1, #contents do
    local line = contents[i]
    out[#out + 1] = line
    if line:match("^%s*```") then
      in_fence = not in_fence
      local next_line = contents[i + 1]
      if not in_fence and next_line and next_line:match("%S") then
        out[#out + 1] = ""
      end
    end
  end
  return out
end

local orig_open_floating_preview = vim.lsp.util.open_floating_preview
vim.lsp.util.open_floating_preview = function(contents, syntax, opts)
  opts = opts or {}
  -- Markdown only. Diagnostic floats come through as "plaintext" and have no
  -- fences, so they are left exactly as they were.
  if syntax == "markdown" and type(contents) == "table" then
    contents = space_after_code_fences(contents)
  end
  -- so below exp is basically manipulating the bufnr, wind object hover docs pop up behavior
  local bufnr, winid = orig_open_floating_preview(contents, syntax, opts)
  -- Skip post-processing on the focus-reuse path: when the second `K` (or
  -- second `<M-i>`) refocuses an existing popup, open_floating_preview
  -- returns the already-open winid AND has just made it the current window.
  -- Re-running our nvim_win_set_config with a `relative=cursor` config would
  -- then anchor to the popup's own cursor and dismiss it.
  local is_focus_reuse = winid and vim.api.nvim_get_current_win() == winid
  if winid and vim.api.nvim_win_is_valid(winid) and not is_focus_reuse then
    local config = vim.api.nvim_win_get_config(winid)
    -- Only reserve the gutter when content actually wraps; for short popups the
    -- marker never shows, so the padding would just be dead space on the left.
    if config.width and float_content_wraps(bufnr, config.width) then
      local pad = 3 -- left padding; the smoothscroll marker parks in this gutter (>= 3 keeps text clear)
      vim.wo[winid].foldcolumn = tostring(pad)
      hide_float_marker(winid)
      -- Widen by the padding so the text area keeps its full width.
      config.width = config.width + pad
      vim.api.nvim_win_set_config(winid, config)
    end
  end
  -- Clean docs popup UI (Zed/WebStorm-style):
  -- - nospell: hide SpellBad squiggles on identifiers like `stdout`, `vm`, `runInThisContext`
  -- - conceallevel=3: fully hide markdown fences/emphasis markers
  -- - concealcursor=n: keep them hidden even when cursor enters the float (no flicker
  --   between rendered markdown and raw source when refocusing)
  if winid and vim.api.nvim_win_is_valid(winid) then
    vim.wo[winid].spell = false
    vim.wo[winid].conceallevel = 3
    vim.wo[winid].concealcursor = "n"
    -- Unconditional, unlike the gutter block above: every doc float gets the
    -- surface, wrapping or not. This branch also runs on the focus-reuse path,
    -- which is what we want -- winhighlight is idempotent (guarded) and cannot
    -- re-anchor the window the way nvim_win_set_config can.
    style_doc_float(winid)
  end
  return bufnr, winid
end

-- Same `<<<` hide for blink.cmp's documentation popup. That float does NOT go
-- through open_floating_preview (above) and keeps smoothscroll on, so we hide its
-- marker the same way. blink re-sets the buffer's filetype on every (re)open, so a
-- FileType hook re-applies each time; the window is resolvable via bufwinid even
-- though blink opens it unfocused. (If blink's doc bg differs from NormalFloat the
-- hidden cells may show a faint smudge — link BlinkCmpDoc to NormalFloat to match.)
vim.api.nvim_create_autocmd("FileType", {
  group = float_doc_grp,
  pattern = "blink-cmp-documentation",
  callback = function(args)
    local win = vim.fn.bufwinid(args.buf)
    -- Same wrap gate as the hover path: skip the gutter for short, non-wrapping docs.
    if win ~= -1 and float_content_wraps(args.buf, vim.api.nvim_win_get_width(win)) then
      vim.wo[win].foldcolumn = "3"
      hide_float_marker(win)
    end
  end,
})

local hover_opts = {
  border = "rounded",
  max_width = 80,
  max_height = 30,
}

-- Override default K hover with enhanced popup
vim.keymap.set("n", "K", function()
  vim.lsp.buf.hover(hover_opts)
end, { desc = "Hover Documentation" })

-- NES wraps <Esc> with expr=true (copilot/keymaps/init.lua:126). Expression-mode
-- keymaps forbid text/window mutation, so calling nvim_win_close directly here
-- raises E565 when NES delegates back to this handler. vim.schedule defers the
-- side effects to the next event tick where window operations are allowed
-- again. Imperceptible delay in the un-wrapped path.
vim.keymap.set("n", "<Esc>", function()
  vim.schedule(function()
    local closed_float = false
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_config(win).relative ~= "" then
        local buf = vim.api.nvim_win_get_buf(win)
        local ft = vim.bo[buf].filetype
        -- Skip snacks picker/explorer windows — they manage their own lifetime
        if ft:match("^snacks_picker") then
          goto continue
        end
        vim.api.nvim_win_close(win, false)
        closed_float = true
      end
      ::continue::
    end

    if not closed_float then
      vim.cmd("noh")
    end
  end)
end, { desc = "Dismiss hover docs / Clear highlights" })

-- Save file (Ctrl+S, works in normal and insert mode)
vim.keymap.set({ "n", "i" }, "<C-s>", "<cmd>w<cr>", { desc = "Save File" })

local scroll_depth = 3

-- Mouse/trackpad: scroll viewport without moving cursor (VSCode/WebStorm behavior)
-- <C-e> scrolls viewport down, <C-y> scrolls viewport up — cursor stays in place
-- Adjust the multiplier (3) if trackpad feels too slow or too fast.
-- TODO(smooth-scroll): The timer-based experiment is parked in
-- lua/config/smooth-scroll.lua but intentionally not enabled. It improved
-- transition feel in some files, then stuttered/paused in heavier TSX buffers.
vim.keymap.set({ "n", "v" }, "<ScrollWheelDown>", scroll_depth .. "<C-e>", { noremap = true })
vim.keymap.set({ "n", "v" }, "<ScrollWheelUp>", scroll_depth .. "<C-y>", { noremap = true })
vim.keymap.set("i", "<ScrollWheelDown>", "<C-o>" .. scroll_depth .. "<C-e>", { noremap = true })
vim.keymap.set("i", "<ScrollWheelUp>", "<C-o>" .. scroll_depth .. "<C-y>", { noremap = true })

-- Horizontal mouse/trackpad scroll: override Neovim's default 6-column jump
-- with native sideways scrolling at a small 3-column step.
-- the Horizontal scroll is still not very smooth compared to vertical scrolling, but in this current time thats the best we can do with Neovim's input system.
-- may be in future Neovim or ghostty might add native support for smooth horizontal scrolling which we can then leverage here.
vim.keymap.set({ "n", "v" }, "<ScrollWheelLeft>", "3zh", { noremap = true, silent = true })
vim.keymap.set({ "n", "v" }, "<ScrollWheelRight>", "3zl", { noremap = true, silent = true })
vim.keymap.set("i", "<ScrollWheelLeft>", "<C-o>3zh", { noremap = true, silent = true })
vim.keymap.set("i", "<ScrollWheelRight>", "<C-o>3zl", { noremap = true, silent = true })
vim.keymap.set({ "n", "v" }, "<S-ScrollWheelLeft>", "3zh", { noremap = true, silent = true })
vim.keymap.set({ "n", "v" }, "<S-ScrollWheelRight>", "3zl", { noremap = true, silent = true })
vim.keymap.set("i", "<S-ScrollWheelLeft>", "<C-o>3zh", { noremap = true, silent = true })
vim.keymap.set("i", "<S-ScrollWheelRight>", "<C-o>3zl", { noremap = true, silent = true })

-- Disable buffer navigation with Shift+H/L (LazyVim defaults). Will be
-- reclaimed by bufferline.nvim when that plugin is re-enabled — see journal.md.
vim.keymap.del("n", "<S-h>")
vim.keymap.del("n", "<S-l>")

vim.keymap.set("n", "<leader>L", "<cmd>restart<cr>", { desc = "Restart Neovim" })
vim.keymap.set("n", "<leader>R", "<cmd>Lazy log<cr>", { desc = "Lazy Log" })
vim.keymap.set("n", "<leader>we", "<cmd>split<cr>", { desc = "Split Window Horizontal" })

local comment_key = "<M-/>"

vim.keymap.set("n", "<leader>va", "ggVG", { desc = "Select all the text in the current file" })
vim.keymap.set("n", "<leader>ya", "ggyG", { desc = "Yank all text" })

-- Copy current file path (relative) to clipboard for Claude Code CLI
vim.keymap.set("n", "<leader>as", function()
  local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":.")
  vim.fn.setreg("+", path)
  vim.notify("Copied: " .. path, vim.log.levels.INFO)
end, { desc = "Copy File Path to Clipboard" })

-- Copy "path:line" to the system clipboard. Companion to <leader>as, which
-- copies the bare relative path. The `path:line` form is what Claude Code CLI /
-- LSP / most editors parse as a jump target.
vim.keymap.set("n", "<leader>al", function()
  local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":.")
  local ref = path .. ":" .. vim.fn.line(".")
  vim.fn.setreg("+", ref)
  vim.notify("Copied: " .. ref, vim.log.levels.INFO)
end, { desc = "Copy File Path + Line to Clipboard" })

-- Visual variant: copy "path:start-end" for the selected line range.
vim.keymap.set("v", "<leader>al", function()
  local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":.")
  local a, b = vim.fn.line("v"), vim.fn.line(".")
  local first, last = math.min(a, b), math.max(a, b)
  local ref = first == last and (path .. ":" .. first) or (path .. ":" .. first .. "-" .. last)
  vim.fn.setreg("+", ref)
  vim.notify("Copied: " .. ref, vim.log.levels.INFO)
end, { desc = "Copy File Path + Line Range to Clipboard" })

require("config.ai-prompts").setup()

-- Normal mode: Comment the current line
vim.keymap.set("n", comment_key, "<cmd>normal gcc<CR>", { desc = "Toggle comment line" })

-- Visual mode: Comment the highlighted selection
vim.keymap.set("v", comment_key, "<Esc>:normal gvgc<CR>", { desc = "Toggle comment block" })

vim.keymap.set({ "n", "v" }, "<C-d>", "<C-d>zz", { desc = "Scroll Down and Recenter" })
vim.keymap.set({ "n", "v" }, "<C-u>", "<C-u>zz", { desc = "Scroll Up and Recenter" })

-- <C-e> / <C-y>: scroll a visible info popup (LSP hover, signature help,
-- diagnostic float) in place without moving focus into it. Semantically a
-- match: <C-e>/<C-y> are vim's "scroll viewport by N lines without moving
-- cursor" keys — ideal for smooth doc reading. POPUP_SCROLL_LINES tunes the
-- per-press step. When no popup is visible, fall back to native <C-e>/<C-y>
-- (no recenter — these are fine viewport nudges, not jumps). nvim_win_call
-- runs `normal!` with the float temporarily current and restores focus; the
-- buffer never changes, so the mouse-hover BufLeave-close path
-- (mouse-hover.lua) won't fire. No collision with the existing scroll-wheel
-- mappings — those use <C-e>/<C-y> on the RHS with noremap, hitting native.
local POPUP_SCROLL_LINES = 1
local popup_scroll_down = POPUP_SCROLL_LINES .. vim.api.nvim_replace_termcodes("<C-e>", true, true, true)
local popup_scroll_up = POPUP_SCROLL_LINES .. vim.api.nvim_replace_termcodes("<C-y>", true, true, true)

local function scroll_popup_or(popup_scroll_cmd, fallback_keys)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local cfg = vim.api.nvim_win_get_config(win)
    if cfg.relative ~= "" and cfg.focusable ~= false then
      local buf = vim.api.nvim_win_get_buf(win)
      if not vim.bo[buf].filetype:match("^snacks_picker") then
        vim.api.nvim_win_call(win, function()
          vim.cmd("normal! " .. popup_scroll_cmd)
        end)
        return
      end
    end
  end
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(fallback_keys, true, true, true), "n", false)
end

vim.keymap.set("n", "<C-e>", function()
  scroll_popup_or(popup_scroll_down, "<C-e>")
end, { desc = "Scroll Popup Down / Viewport Down" })
vim.keymap.set("n", "<C-y>", function()
  scroll_popup_or(popup_scroll_up, "<C-y>")
end, { desc = "Scroll Popup Up / Viewport Up" })

-- Arrow keys are the ergonomic, fine-grained reading controls in normal,
-- non-floating file windows. Sidebars, panels, terminals, help, Oil, Snacks,
-- and floats retain native arrow-key cursor movement.
local function is_editor_window()
  return vim.bo.buftype == "" and vim.api.nvim_win_get_config(0).relative == ""
end

local function editor_scroll_or_arrow(scroll_key, arrow_key)
  return function()
    return is_editor_window() and scroll_key or arrow_key
  end
end

vim.keymap.set("n", "<Up>", editor_scroll_or_arrow("<C-e>", "<Down>"), {
  expr = true,
  desc = "Scroll Viewport Down",
})
vim.keymap.set("n", "<Down>", editor_scroll_or_arrow("<C-y>", "<Up>"), {
  expr = true,
  desc = "Scroll Viewport Up",
})
vim.keymap.set("n", "<Right>", editor_scroll_or_arrow("2zl", "<Right>"), {
  expr = true,
  desc = "Scroll Viewport Right",
})
vim.keymap.set("n", "<Left>", editor_scroll_or_arrow("2zh", "<Left>"), {
  expr = true,
  desc = "Scroll Viewport Left",
})

vim.keymap.set({ "n", "v" }, "<C-f>", "<C-f>zz", { desc = "Scroll Down Page and Recenter" })
vim.keymap.set({ "n", "v" }, "<C-b>", "<C-b>zz", { desc = "Scroll Up Page and Recenter" })

-- Tab in normal mode: accept NES if pending, else focus float, else native
-- jumplist forward (the built-in <C-i> behavior, since <Tab> and <C-i> share the
-- same byte in the terminal). Hover is on K.
vim.keymap.set("n", "<Tab>", function()
  local bufnr = vim.api.nvim_get_current_buf()
  if vim.b[bufnr].nes_state then
    local ok, nes = pcall(require, "copilot-lsp.nes")
    if ok then
      local _ = nes.walk_cursor_start_edit(bufnr) or (nes.apply_pending_nes(bufnr) and nes.walk_cursor_end_edit(bufnr))
      return
    end
  end
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local cfg = vim.api.nvim_win_get_config(win)
    if cfg.relative ~= "" and cfg.focusable ~= false then
      local buf = vim.api.nvim_win_get_buf(win)
      local ft = vim.bo[buf].filetype
      if not ft:match("^snacks_picker") and not vim.b[buf].mouse_hover_popup then
        -- Defer the window switch: when NES delegates here via its expr=true
        -- <Tab> wrapper, nvim_set_current_win raises E565 (no text/window
        -- mutation allowed in expression context). Same fix as <Esc> above.
        vim.schedule(function()
          if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_set_current_win(win)
          end
        end)
        return
      end
    end
  end
  -- Fall through to native <C-i> jumplist-forward. The "1" count prefix is
  -- required: without it, the bare <C-i> byte (0x09) gets stripped as
  -- whitespace by :normal!'s argument parser and the command silently fails
  -- with E471. :normal! bypasses user mappings so this can't re-enter the
  -- <Tab> mapping. Scheduled + pcall'd to stay safe in expression-context
  -- invocations (avoids E565, same reason as the deferred set_current_win
  -- above) and to swallow E78 when the jumplist is exhausted.
  vim.schedule(function()
    pcall(vim.cmd, [[execute "normal! 1\<C-i>"]])
  end)
end, { desc = "NES Accept / Focus Float / Jump Forward" })

-- Signature help for insert mode and normal mode (Option+i via Ghostty)
vim.keymap.set({ "i", "n" }, "<M-i>", function()
  vim.lsp.buf.signature_help(hover_opts)
end, { desc = "Signature Help" })

-- terminal mode
vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { noremap = true })

-- Override LazyVim's <C-/> to open terminal on the right
local function toggle_right_term()
  Snacks.terminal.toggle(nil, {
    win = {
      position = "right",
      width = 0.3,
    },
  })
end
vim.keymap.set({ "n", "t" }, "<C-->", toggle_right_term, { desc = "Toggle Terminal (right)" })
vim.keymap.set({ "n", "t" }, "<C-_>", toggle_right_term, { desc = "Toggle Terminal (right)" })

vim.keymap.set("i", "<Tab>", function()
  local bufnr = vim.api.nvim_get_current_buf()
  if vim.b[bufnr].nes_state then
    local ok, nes = pcall(require, "copilot-lsp.nes")
    if ok then
      local _ = nes.walk_cursor_start_edit(bufnr) or (nes.apply_pending_nes(bufnr) and nes.walk_cursor_end_edit(bufnr))
      return ""
    end
  end
  return vim.api.nvim_replace_termcodes("<Tab>", true, true, true)
end, { expr = true, desc = "NES Accept or Indent" })
vim.keymap.set("i", "<S-Tab>", "<C-d>", { desc = "Outdent" })

-- Relocated off native `gi` (resume insert at last edit position) to reclaim it.
vim.keymap.set("n", "<leader>cd", function()
  local _, winid = vim.diagnostic.open_float({
    focusable = true,
    border = "rounded",
    source = "always",
  })
  if winid then
    vim.api.nvim_set_current_win(winid)
  end
end, { desc = "Line Diagnostics (Focus)" })

-- Disabled g-prefixed error jumps (ge/gp) live in config/diagnostics-keymaps.lua;
-- LazyVim's standard ]e/[e (and ]w/[w, ]d/[d) cover next/prev error instead.
require("config.diagnostics-keymaps")

-- Resize window using Shift + arrow keys
vim.keymap.set("n", "<S-Up>", "<cmd>resize +2<cr>", { desc = "Increase Window Height" })
vim.keymap.set("n", "<S-Down>", "<cmd>resize -2<cr>", { desc = "Decrease Window Height" })
vim.keymap.set("n", "<S-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease Window Width" })
vim.keymap.set("n", "<S-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase Window Width" })

-- Explicit state flags for fold toggle (foldlevel is unreliable with ufo)
vim.g.folds_closed = false
vim.g.fold_keep_current_open = false

-- zm: toggle all folds but keep current open
vim.keymap.set("n", "zm", function()
  if vim.g.folds_closed then
    vim.g.folds_closed = false
    vim.g.fold_keep_current_open = false
    require("ufo").openAllFolds()
  else
    vim.g.folds_closed = true
    vim.g.fold_keep_current_open = true
    require("ufo").closeAllFolds()
    vim.cmd("normal! zv")
  end
end, { desc = "Toggle All Folds (keep current open)" })

-- zn: toggle all folds including current
vim.keymap.set("n", "zn", function()
  if vim.g.folds_closed then
    vim.g.folds_closed = false
    vim.g.fold_keep_current_open = false
    require("ufo").openAllFolds()
  else
    vim.g.folds_closed = true
    vim.g.fold_keep_current_open = false
    require("ufo").closeAllFolds()
  end
end, { desc = "Toggle All Folds" })

-- Re-open the fold at cursor after editing when zm mode is active
-- (ufo re-evaluates folds on InsertLeave which re-closes everything)
vim.api.nvim_create_autocmd("InsertLeave", {
  callback = function()
    if vim.g.fold_keep_current_open then
      vim.schedule(function()
        vim.cmd("normal! zv")
      end)
    end
  end,
})

-- Search word under cursor and stay in place (Cmd+F via Ghostty → M-f)
vim.keymap.set("n", "<M-f>", "*N", { desc = "Highlight word under cursor" })

-- Git who: compact blame info (author, date, message) for current line
vim.keymap.set("n", "<leader>gw", function()
  local lnum = vim.fn.line(".")
  local file = vim.fn.expand("%:p")

  -- Pipe current buffer content so line numbers match even with unsaved changes
  local buf_content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  local blame = vim.fn.system(
    { "git", "blame", "-L", lnum .. "," .. lnum, "--porcelain", "--contents", "-", "--", file },
    buf_content
  )
  if vim.v.shell_error ~= 0 then
    vim.notify("Not in a git repository", vim.log.levels.WARN)
    return
  end

  local commit = blame:match("^(%x+)")
  if not commit or commit:match("^0+$") then
    vim.notify("Line not yet committed", vim.log.levels.INFO)
    return
  end

  local author = blame:match("author ([^\n]+)") or "Unknown"
  local author_mail = blame:match("author%-mail ([^\n]+)") or ""
  local author_time = blame:match("author%-time (%d+)")
  local summary = blame:match("summary ([^\n]+)") or ""
  local date = author_time and os.date("%Y-%m-%d %H:%M", tonumber(author_time)) or "Unknown"

  local lines = {
    "Commit:  " .. commit:sub(1, 10),
    "Author:  " .. author .. " " .. author_mail,
    "Date:    " .. date,
    "",
    "  " .. summary,
  }

  local float_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(float_buf, 0, -1, false, lines)
  vim.bo[float_buf].buftype = "nofile"
  vim.bo[float_buf].modifiable = false
  vim.bo[float_buf].bufhidden = "wipe"
  vim.bo[float_buf].filetype = "git"

  local width = 0
  for _, l in ipairs(lines) do
    width = math.max(width, #l)
  end
  width = math.min(width + 4, 80)

  vim.api.nvim_open_win(float_buf, true, {
    relative = "cursor",
    width = width,
    height = #lines,
    row = 1,
    col = 0,
    style = "minimal",
    border = "rounded",
    title = " Git Who ",
    title_pos = "center",
  })

  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = float_buf, nowait = true })
  vim.keymap.set("n", "<Esc>", "<cmd>close<cr>", { buffer = float_buf, nowait = true })
end, { desc = "Git Who (blame info)" })

-- Git blame for current line (custom: shows both + and - lines in diff)
vim.keymap.set("n", "<leader>gb", function()
  local lnum = vim.fn.line(".")
  local file = vim.fn.expand("%:p")

  -- Pipe current buffer content so line numbers match even with unsaved changes
  local buf_content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  local blame = vim.fn.system(
    { "git", "blame", "-L", lnum .. "," .. lnum, "--porcelain", "--contents", "-", "--", file },
    buf_content
  )
  if vim.v.shell_error ~= 0 then
    vim.notify("Not in a git repository", vim.log.levels.WARN)
    return
  end

  local commit = blame:match("^(%x+)")
  if not commit or commit:match("^0+$") then
    vim.notify("Line not yet committed", vim.log.levels.INFO)
    return
  end

  local output = vim.fn.system({ "git", "show", commit, "--", file })
  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to get commit info", vim.log.levels.ERROR)
    return
  end

  local lines = vim.split(output, "\n")
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = "git"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  local width = math.min(120, vim.o.columns - 4)
  local height = math.min(#lines, math.floor(vim.o.lines * 0.8))

  vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = "rounded",
    title = " Git Blame ",
    title_pos = "center",
  })

  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, nowait = true })
  vim.keymap.set("n", "<Esc>", "<cmd>close<cr>", { buffer = buf, nowait = true })
end, { desc = "Git Blame Line" })

-- Git file history (override LazyVim default):
-- Open the Snacks file-log picker; pressing <CR> opens the selected commit's
-- diff in Diffview (vs. its parent) instead of checking out the file.
vim.keymap.set("n", "<leader>gf", function()
  Snacks.picker.git_log_file({
    confirm = function(picker, item)
      picker:close()
      if item and item.commit then
        vim.cmd("DiffviewOpen " .. item.commit .. "^!")
      end
    end,
  })
end, { desc = "Git File History (diff on enter)" })

-- Snacks picker: grep within current file
vim.keymap.set("n", "<leader>sl", function()
  Snacks.picker.grep({
    dirs = { vim.api.nvim_buf_get_name(0) },
  })
end, { desc = "Grep in Current File" })

-- Disabled g-prefixed treesitter function nav (gf/gh) lives in config/treesitter-keymaps.lua;
-- LazyVim's standard ]f/[f (function start), ]F/[F (end), ]c/[c (class), ]a/[a (param) cover it.
require("config.treesitter-keymaps")

-- Unsaved files popup: list all modified buffers with jump/save actions
local function show_unsaved_files()
  local modified = {}
  for _, buf in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
    if buf.changed == 1 then
      local name = buf.name ~= "" and vim.fn.fnamemodify(buf.name, ":~:.") or "[No Name]"
      table.insert(modified, { bufnr = buf.bufnr, name = name })
    end
  end

  if #modified == 0 then
    vim.notify("All files saved", vim.log.levels.INFO)
    return
  end

  local lines = {}
  local max_len = 0
  for i, f in ipairs(modified) do
    local line = string.format("  %d  %s", i, f.name)
    table.insert(lines, line)
    max_len = math.max(max_len, #line)
  end

  -- Footer hint line
  local hint = "  <CR> jump  s save  S save all  q close"
  max_len = math.max(max_len, #hint)
  table.insert(lines, "")
  table.insert(lines, hint)

  local width = math.max(max_len + 2, 44)
  local height = #lines
  local float_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(float_buf, 0, -1, false, lines)
  vim.bo[float_buf].buftype = "nofile"
  vim.bo[float_buf].modifiable = false
  vim.bo[float_buf].bufhidden = "wipe"

  local win = vim.api.nvim_open_win(float_buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " ● Unsaved Files (" .. #modified .. ") ",
    title_pos = "center",
  })

  -- Dim the hint line
  vim.api.nvim_buf_add_highlight(float_buf, -1, "Comment", #modified + 1, 0, -1)

  local map_opts = { buffer = float_buf, nowait = true }

  vim.keymap.set("n", "<CR>", function()
    local row = vim.api.nvim_win_get_cursor(win)[1]
    if row > #modified then
      return
    end
    local target = modified[row]
    vim.api.nvim_win_close(win, true)
    vim.api.nvim_set_current_buf(target.bufnr)
  end, map_opts)

  vim.keymap.set("n", "s", function()
    local row = vim.api.nvim_win_get_cursor(win)[1]
    if row > #modified then
      return
    end
    local target = modified[row]
    vim.api.nvim_buf_call(target.bufnr, function()
      vim.cmd("write")
    end)
    vim.api.nvim_win_close(win, true)
    show_unsaved_files()
  end, map_opts)

  vim.keymap.set("n", "S", function()
    vim.api.nvim_win_close(win, true)
    vim.cmd("wa")
    vim.notify("All files saved", vim.log.levels.INFO)
  end, map_opts)

  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, map_opts)
  vim.keymap.set("n", "<Esc>", function()
    vim.api.nvim_win_close(win, true)
  end, map_opts)
end

vim.keymap.set("n", "<leader>bu", show_unsaved_files, { desc = "Unsaved Files" })

-- Native quickfix toggle, matching LazyVim's default <leader>xq behavior.
vim.keymap.set("n", "<leader>cc", function()
  local success, err = pcall(vim.fn.getqflist({ winid = 0 }).winid ~= 0 and vim.cmd.cclose or vim.cmd.copen)
  if not success and err then
    vim.notify(err, vim.log.levels.ERROR)
  end
end, { desc = "Quickfix List" })

-- Location list under the <leader>c cluster (Trouble view).
vim.keymap.set("n", "<leader>ce", "<cmd>Trouble loclist toggle<cr>", { desc = "Location List (Trouble)" })
-- Manually curate the quickfix list while reading code: <leader>m marks the current line
-- (normal) or each selected line (visual); browse with <leader>cc, clear with <leader>cx.
-- Inside the Trouble window, `dd` (or visual `d`) removes a single entry for good.
local manual_qf = require("config.quickfix-persistence")
local function qf_add(lines)
  local items = {}
  for _, l in ipairs(lines) do
    items[#items + 1] = manual_qf.item(l, vim.trim(vim.fn.getline(l)))
  end
  vim.fn.setqflist(items, "a") -- append; keep any existing entries
  vim.notify(("Quickfix: +%d (%d total)"):format(#items, #vim.fn.getqflist()), vim.log.levels.INFO)
end

vim.keymap.set("n", "<leader>m", function()
  qf_add({ vim.fn.line(".") })
end, { desc = "Add line to Quickfix" })

vim.keymap.set("x", "<leader>m", function()
  local s, e = vim.fn.getpos("v")[2], vim.fn.getpos(".")[2]
  if s > e then
    s, e = e, s
  end
  local lines = {}
  for l = s, e do
    lines[#lines + 1] = l
  end
  qf_add(lines)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
end, { desc = "Add selection to Quickfix" })

vim.keymap.set("n", "<leader>cx", function()
  vim.fn.setqflist({}, "r")
  manual_qf.clear()
  vim.notify("Quickfix cleared", vim.log.levels.INFO)
end, { desc = "Clear Quickfix list" })

-- Mason toggle on <leader>M.
vim.keymap.set("n", "<leader>M", function()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "mason" then
      vim.api.nvim_win_close(win, true)
      return
    end
  end
  vim.cmd("Mason")
end, { desc = "Mason (toggle)" })

-- Relocate LazyVim's Inspect tools off <leader>ui / <leader>uI so <leader>ui can
-- drive the markdown browser preview (see lua/plugins/markdown-preview.lua).
-- Both remain available as the :Inspect / :InspectTree ex-commands regardless.
pcall(vim.keymap.del, "n", "<leader>ui")
pcall(vim.keymap.del, "n", "<leader>uI")
vim.keymap.set("n", "<leader>uj", vim.show_pos, { desc = "Inspect Pos" })
vim.keymap.set("n", "<leader>uk", function()
  vim.treesitter.inspect_tree()
  vim.api.nvim_input("I")
end, { desc = "Inspect Tree" })
