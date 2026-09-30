-- Options are automatically loaded before lazy.nvim startup
-- Add any additional options here
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua

vim.o.number = true
vim.o.scrolloff = 13
-- smoothscroll only has any effect when a window has `wrap = true`. Our code
-- editing uses `wrap = false` (see below), so this option is inert there — it
-- only matters inside wrapped doc/float views (LSP hover, completion docs).
--
-- `true`  → the top of the window may park in the MIDDLE of a wrapped line, so
--           <C-e>/<C-y>/wheel scroll one SCREEN ROW at a time. Smooth, fine-
--           grained reading. Cost: Neovim draws a `<<<` indicator in the top-
--           left to flag that the first line is partially scrolled (an info
--           marker, not a glitch; it sits over the first ~3 cells of that row).
-- `false` → a wrapped line is all-or-nothing at the top, so one scroll step
--           jumps the ENTIRE multi-row logical line at once (and the mouse,
--           mapped to 3<C-e>, jumps 3 logical lines). No marker, but reading
--           long wrapped paragraphs in floats feels jarring/jumpy.
--
-- We keep `true` everywhere, including doc floats, so long wrapped text scrolls
-- one screen row at a time (never a whole block per <C-e>). The `<<<` marker this
-- normally draws is hidden inside the floats by recolouring NonText to the float
-- bg — see keymaps.lua — so we get smooth scrolling without the marker or a gutter.
vim.o.smoothscroll = true
-- material.nvim variant. Loading the `material-oceanic` colorscheme (see
-- colorschemes/config.lua) also sets this, but keep it aligned so a manual
-- `:colorscheme material` resolves to the same variant.
vim.g.material_style = "oceanic" -- note: this config will only effect if you set the colorscheme to material-oceanic
vim.opt.list = false
vim.opt.listchars = { leadmultispace = "│ ", tab = "▸ ", trail = "·" }
vim.opt.ttyfast = true

-- animations
vim.g.snacks_animate = false

-- enabled mouse
vim.o.mouse = "a"
-- popup_setpos: right-click moves the cursor to the click first, so LSP
-- hover / signature_help fire on the symbol under the pointer (not wherever
-- the cursor happened to be). Use "popup" if you'd rather keep the cursor.
vim.o.mousemodel = "popup_setpos"
vim.opt.sidescroll = 1

-- Right-click menu: pin LSP actions at the top of the popup.
-- Neovim's defaults add items without explicit priorities (so they share
-- priority 500 and order by insertion). Giving ours priority 1.10/1.20/1.30
-- floats them above everything else. We also unmenu the default
-- "Go to definition" so it isn't duplicated -- the MenuPopup autocmd in
-- runtime/lua/vim/_core/defaults.lua still gates it by LSP-client presence
-- because the menu is addressed by path, not by definition site.
pcall(vim.cmd, [[aunmenu PopUp.Go\ to\ definition]])
pcall(vim.cmd, [[aunmenu PopUp.Show\ Hover\ Docs]])
pcall(vim.cmd, [[aunmenu PopUp.Show\ Signature\ Help]])
pcall(vim.cmd, [[aunmenu PopUp.-LspExtras-]])

local hover_opts_literal = [[{ border = "rounded", max_width = 80, max_height = 30 }]]

vim.cmd([[anoremenu 1.10 PopUp.Go\ to\ definition <Cmd>lua vim.lsp.buf.definition()<CR>]])
vim.cmd([[anoremenu 1.20 PopUp.-LspExtras- <Nop>]])
vim.cmd(
  "anoremenu 1.30 PopUp.Show\\ Signature\\ Help <Cmd>lua vim.lsp.buf.signature_help(" .. hover_opts_literal .. ")<CR>"
)
vim.cmd("anoremenu 1.40 PopUp.Show\\ Hover\\ Docs <Cmd>lua vim.lsp.buf.hover(" .. hover_opts_literal .. ")<CR>")

-- horizontal scroll setting
vim.o.wrap = false
vim.o.sidescrolloff = 5

-- Ghostty terminal optimizations
local is_ghostty = vim.env.TERM_PROGRAM == "ghostty" or vim.env.GHOSTTY_RESOURCES_DIR ~= nil

if is_ghostty then
  -- Enable 24-bit true colors (Ghostty fully supports this)
  vim.opt.termguicolors = true

  -- Undercurl support - Ghostty renders these beautifully
  vim.cmd([[let &t_Cs = "\e[4:3m"]]) -- undercurl
  vim.cmd([[let &t_Ce = "\e[4:0m"]]) -- undercurl end
  vim.cmd([[let &t_AU = "\e[58:5:%dm"]]) -- underline color (256)
  vim.cmd([[let &t_8u = "\e[58:2:%lu:%lu:%lum"]]) -- underline color (true color)

  -- Cursor shape changes (Ghostty handles these correctly)
  vim.opt.guicursor = "n-v-c-sm:block,i-ci-ve:ver25,r-cr-o:hor20"

  -- Synchronized output (prevents tearing during redraws)
  -- Ghostty supports this via kitty protocol
  vim.opt.termsync = true
end

-- Top breathing room: a 1-row winbar holding a single space. The string is
-- static, so it is never re-evaluated on redraw (zero hot-path cost). WinBar is
-- made transparent in autocmds.lua on every ColorScheme — setting the highlight
-- here doesn't stick because the theme loads after options.lua and repaints it.
vim.opt.winbar = " "

vim.diagnostic.config({
  float = {
    border = "rounded",
    max_width = 80,
    source = "always",
    header = "",
    prefix = "",
  },
})

vim.opt.clipboard = "unnamedplus"

-- Ghostty supports OSC 52 for clipboard - faster than pbcopy/pbpaste
-- Falls back to pbcopy/pbpaste for non-Ghostty terminals
-- if is_ghostty then
--   vim.g.clipboard = {
--     name = "OSC 52",
--     copy = {
--       ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
--       ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
--     },
--     paste = {
--       ["+"] = require("vim.ui.clipboard.osc52").paste("+"),
--       ["*"] = require("vim.ui.clipboard.osc52").paste("*"),
--     },
--   }
-- else
--   vim.g.clipboard = {
--     name = "macOS-clipboard",
--     copy = {
--       ["+"] = "pbcopy",
--       ["*"] = "pbcopy",
--     },
--     paste = {
--       ["+"] = "pbpaste",
--       ["*"] = "pbpaste",
--     },
--     cache_enabled = 1,
--   }
-- end

-- Fix paste in tmux + Ghostty: modifyOtherKeys / kitty keyboard protocol
-- encodes control characters as CSI sequences instead of literal bytes.
-- Decode them before passing to the default paste handler.
vim.paste = (function(overridden)
  return function(lines, phase)
    local result = {}
    for _, line in ipairs(lines) do
      -- modifyOtherKeys format: \e[27;modifier;keycode~
      -- modifier can vary (5=Ctrl, 2=Shift, etc.) so match any digit sequence
      line = line:gsub("\27%[27;%d+;106~", "\n") -- Ctrl+J (newline)
      line = line:gsub("\27%[27;%d+;109~", "\r") -- Ctrl+M (carriage return)
      line = line:gsub("\27%[27;%d+;105~", "\t") -- Ctrl+I (tab)
      line = line:gsub("\27%[27;%d+;10~", "\n") -- LF keycode direct
      line = line:gsub("\27%[27;%d+;13~", "\r") -- CR keycode direct
      line = line:gsub("\27%[27;%d+;9~", "\t") -- Tab keycode direct
      -- Kitty keyboard protocol (CSI u): \e[codepoint;modifiers u
      line = line:gsub("\27%[10;%d+u", "\n")
      line = line:gsub("\27%[10u", "\n")
      line = line:gsub("\27%[13;%d+u", "\r")
      line = line:gsub("\27%[13u", "\r")
      line = line:gsub("\27%[9;%d+u", "\t")
      line = line:gsub("\27%[9u", "\t")
      -- Strip any remaining CSI sequences (shouldn't appear in pasted text)
      line = line:gsub("\27%[[%d;]*[A-Za-z~]", "")
      -- Re-split by decoded newlines
      for _, part in ipairs(vim.split(line, "\n", { plain = true })) do
        result[#result + 1] = part
      end
    end
    return overridden(result, phase)
  end
end)(vim.paste)

-- Performance optimizations
vim.opt.updatetime = 400 -- faster CursorHold (default 4000ms)
vim.opt.timeoutlen = 300 -- faster keymap timeout (default 1000ms)
vim.opt.signcolumn = "yes" -- fixed signcolumn prevents layout shift
-- vim.opt.statuscolumn = "%s%=%{v:relnum == 0 ? v:lnum : v:relnum}  %C"
-- vim.opt.lazyredraw = true -- DISABLED: causes async UI freezes with LSP
vim.opt.synmaxcol = 300 -- don't syntax highlight super long lines

-- Fold settings
vim.o.foldcolumn = "1"
vim.o.foldlevel = 99
vim.o.foldlevelstart = 99
vim.o.foldenable = true
-- foldmethod intentionally left as default ("manual") here.
-- nvim-ufo sets it to "manual" per-buffer after async attachment and runs its
-- own treesitter provider off the main thread. Setting foldmethod=expr globally
-- would trigger a synchronous per-line treesitter scan on every buffer open,
-- blocking render before ufo ever gets a chance to attach.

-- fold ui options
-- vim.opt.fillchars = {
--   foldopen  = "⌄",
--   foldclose = "›",
--   fold      = " ",
--   foldsep   = " ",
-- }

-- Disable unused providers
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_node_provider = 0

-- Python LSP: use basedpyright (faster, free, more complete than pyright).
-- Read by lazyvim.plugins.extras.lang.python at spec-resolution time, which is
-- why this lives in options.lua (loaded before plugin specs are configured).
vim.g.lazyvim_python_lsp = "basedpyright"
vim.g.lazyvim_python_ruff = "ruff"

-- Auto-reload buffers when an external process (e.g. agentic AI) writes to disk
vim.opt.autoread = true
vim.api.nvim_create_autocmd({ "FocusGained", "CursorHold" }, {
  callback = function()
    vim.cmd("checktime")
  end,
})

-- Auto-clear command line messages after inactivity (lightweight)
local msg_clear_timer
vim.api.nvim_create_autocmd("CursorHold", {
  callback = function()
    if msg_clear_timer then
      pcall(vim.fn.timer_stop, msg_clear_timer)
    end
    msg_clear_timer = vim.fn.timer_start(2000, function()
      vim.schedule(function()
        if vim.fn.mode() == "n" then
          vim.cmd("echo ''")
        end
      end)
    end)
  end,
})
