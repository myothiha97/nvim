# Insert-mode navigation in real-world Vim/Neovim practice: distros, well-known users, plugins

Method note: distro and dotfile claims come from the raw source files on GitHub, fetched 2026-10-28 (current default branches). Star counts were only partly available, because the GitHub API was blocked from this environment. Where no count could be verified, the gap is noted.

## Q1. LazyVim defaults: which insert-mode keymaps does it ship?

### Takeaway
LazyVim ships no insert-mode cursor-navigation maps (no hjkl or readline motions). Its insert-mode maps are quality-of-life maps: `<A-j>/<A-k>` move the current line, undo break-points after `, . ;`, `<C-s>` save, and an `<Esc>` override that also clears hlsearch and stops any active snippet.

### Cited Findings
- `map("i", "<A-j>", "<esc><cmd>m .+1<cr>==gi", { desc = "Move Down" })` and `map("i", "<A-k>", "<esc><cmd>m .-2<cr>==gi", { desc = "Move Up" })` move the line, not the cursor. They leave insert mode briefly and return with `gi`. The same keys are mapped in normal and visual mode — [LazyVim keymaps.lua](https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua)
- Undo break-points: `map("i", ",", ",<c-g>u")`, `map("i", ".", ".<c-g>u")`, `map("i", ";", ";<c-g>u")`, under the comment "Add undo break-points" — [LazyVim keymaps.lua](https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua)
- Save: `map({ "i", "x", "n", "s" }, "<C-s>", "<cmd>w<cr><esc>", { desc = "Save File" })`. Saving from insert mode also drops you to normal mode — [LazyVim keymaps.lua](https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua)
- `<esc>` is mapped in i/n/s modes to run `noh`, stop the active snippet, and then return `<esc>` ("Escape and Clear hlsearch") — [LazyVim keymaps.lua](https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua)
- LazyVim's `n`/`N` maps cite mhinz/vim-galore as their origin. This shows the distro takes its maps from community "sane defaults" — [LazyVim keymaps.lua](https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua)

### Inferences
- LazyVim is the most widely used Neovim distro, and its design implies "navigate in normal mode". Its only Alt maps in insert mode edit the text structure (move a line). They are not cursor motions.

### Gaps
- The lazyvim.org keymaps page was not fetched separately. The source file is authoritative.
- No current GitHub star count, because the API was blocked.

## Q2. kickstart.nvim, AstroNvim, NvChad: insert-mode navigation maps?

### Takeaway
kickstart.nvim and AstroNvim ship no insert-mode navigation maps. Among the major distros, only NvChad ships them, and it still does in current v2.5: `<C-h/j/k/l>` as arrows, `<C-b>` for line start, `<C-e>` for line end. The same maps were in v2.0.

### Cited Findings
- kickstart.nvim's init.lua maps `<Esc>` in normal mode to `:nohlsearch`, `<Esc><Esc>` in terminal mode to exit, and normal-mode `<C-h/j/k/l>` to window focus. It defines no `"i"`-mode keymaps. The only insert-related keys are the completion keys (`<c-y>` accept, `<c-n>/<c-p>` select, `<c-e>` hide, `<c-space>` open, `<c-k>` signature help), documented in comments — [kickstart.nvim init.lua](https://github.com/nvim-lua/kickstart.nvim/blob/master/init.lua)
- AstroNvim's core mappings (`_astrocore_mappings.lua`) define normal-mode `<C-S>` force write, `<C-Q>` force quit, `<C-H/J/K/L>` split navigation and `<C-Up/Down>` resize. No `maps.i` entries were found in that file — [AstroNvim _astrocore_mappings.lua](https://github.com/AstroNvim/AstroNvim/blob/main/lua/astronvim/plugins/_astrocore_mappings.lua)
- NvChad v2.5 (current): `map("i", "<C-b>", "<ESC>^i", { desc = "move beginning of line" })`, `map("i", "<C-e>", "<End>", ...)`, and `<C-h>`→`<Left>`, `<C-l>`→`<Right>`, `<C-j>`→`<Down>`, `<C-k>`→`<Up>` — [NvChad v2.5 mappings.lua](https://github.com/NvChad/NvChad/blob/v2.5/lua/nvchad/mappings.lua)
- NvChad v2.0 had the same set under `M.general.i`, with the comment "-- navigate within insert mode", so this has not changed across major versions — [NvChad v2.0 core/mappings.lua](https://github.com/NvChad/NvChad/blob/v2.0/lua/core/mappings.lua)

### Inferences
- NvChad's `<C-h>` and `<C-k>` override built-in insert-mode keys: `i_CTRL-H` is backspace and `i_CTRL-K` enters a digraph. Its `<C-e>` overrides `i_CTRL-E`, which inserts the character from the line below. NvChad's `<C-b>` is not readline's "back one char". It jumps to the first non-blank character, which is the opposite of vim-rsi's `<C-b>`.
- 3 of the 4 major starter configs choose not to add insert-mode cursor motions.

### Gaps
- AstroNvim may add insert maps in other plugin specs, for example its completion or autopairs specs. Only the core mappings file was checked.

## Q3. Plugins: tpope/vim-rsi, readline-style plugins, and Alt+hjkl insert motions

### Takeaway
The standard plugin is tpope/vim-rsi. It gives readline keys in insert and command-line modes and tries not to break Vim's own keys, with about 645 stars. mini.basics (part of mini.nvim) has an opt-in `<M-hjkl>` insert-mode motion option, and its main stated use is stepping out of autopairs. Most other readline plugins target command-line mode rather than insert mode.

### Cited Findings
- vim-rsi README: "Readline mappings are provided in insert mode and command line mode. Normal mode is deliberately omitted." It also says: "Important Vim key bindings (like insert mode's C-n and C-p completion) are not overridden." And: "C-d, C-e, and C-f are mapped such that they perform the Readline behavior in the middle of the line and the Vim behavior at the end." Its rationale is "Get the most useful of the ubiquitous key bindings without blindly overriding built-in Vim functionality." — [vim-rsi README](https://github.com/tpope/vim-rsi)
- vim-rsi insert-mode maps:
  - `<C-a>`→`<C-O>^`. The original `i_CTRL-A` moves to `<C-x><C-a>`.
  - `<C-b>` = left, or joins a blank line upward.
  - `<C-d>` = delete forward, with `i_CTRL-D` at end of line.
  - `<C-e>` = `<End>`, with `i_CTRL-E` at end of line or when the popup menu is visible.
  - `<C-f>` = right, with `i_CTRL-F` at end of line.
  - Meta maps `<M-b>`/`<M-f>` (word back/forward via `<S-Left>/<S-Right>`), `<M-d>` (`<C-O>dw`), `<M-n>/<M-p>` (down/up), `<M-BS>` (`<C-W>`).
  - `<C-t>` transpose is mapped in command-line mode only, "as i_CTRL-T is too important to clobber". `<C-g>` was removed because it conflicts with `c_CTRL-G`.
  - Sources: [vim-rsi plugin/rsi.vim](https://github.com/tpope/vim-rsi/blob/master/plugin/rsi.vim); [vim-rsi doc/rsi.txt](https://github.com/tpope/vim-rsi/blob/master/doc/rsi.txt)
- Meta caveat, quoted from the help file: "In the terminal, the meta key sends escape, so mapping these would require mappings starting with escape in insert mode. This makes Vim appear to lag for a second if you actually press just escape. Instead, rsi.vim makes these available by telling Vim they are existing special keys." In terminal Vim it binds `<Esc>b` etc. to spare keys `<F29>`–`<F35>`. In GUI Vim and Neovim it maps `<M-…>` directly. `let g:rsi_no_meta = 1` disables the Meta maps — [vim-rsi doc/rsi.txt](https://github.com/tpope/vim-rsi/blob/master/doc/rsi.txt); [plugin/rsi.vim](https://github.com/tpope/vim-rsi/blob/master/plugin/rsi.vim)
- Adoption: vim-rsi has about 645 stars and 36 forks, with 16 open issues — [GitHub tpope/vim-rsi](https://github.com/tpope/vim-rsi)
- mini.basics `mappings.move_with_alt` (default `false`, opt-in) creates `<M-h>`/`<M-l>` in Insert, Terminal and Command modes and `<M-j>`/`<M-k>` in Insert and Terminal modes, mapped to arrow keys. The docs say: "creates mappings for a more consistent cursor move in Insert, Command, and Terminal modes. For example, it proves useful in combination of autopair plugin (like mini.pairs) to move right outside of inserted pairs." The insert maps are deliberately not `noremap`, "to have these keybindings behave exactly" like the arrows — [mini.basics source](https://github.com/echasnovski/mini.nvim/blob/main/lua/mini/basics.lua)
- ryvnf/readline.vim targets command-line mode. It "implements a subset of Readline's default keyboard commands" with closer Readline word semantics, for example punctuation skipped and `_` treated as a delimiter — [ryvnf/readline.vim README](https://github.com/ryvnf/readline.vim/blob/master/README.md)
- Other emacs-binding plugins exist: bsuth/emacs-bindings.nvim, sei40kr/nvimacs, millerjason/neovimacs.nvim, and mk12/vim-meta (makes Meta keys work in terminal Vim) — [emacs-bindings.nvim](https://github.com/bsuth/emacs-bindings.nvim); [nvimacs](https://github.com/sei40kr/nvimacs); [neovimacs.nvim on neovimcraft](https://erock-neovimcraft-1782466063.pgs.sh/plugin/millerjason/neovimacs.nvim/); [vim-meta](https://github.com/mk12/vim-meta)
- Related "escape faster" plugin: max397574/better-escape.nvim (about 797 stars) maps `jk`/`jj`→`<Esc>` in insert mode by default. It exists to avoid the `timeoutlen` lag that a plain `inoremap jk <Esc>` causes after every typed `j` — [better-escape.nvim](https://github.com/max397574/better-escape.nvim)

### Inferences
- In adoption, the "leave insert mode faster" plugin (better-escape, about 797 stars) is about as popular as the "navigate inside insert mode" plugin (vim-rsi, about 645 stars), even though vim-rsi is much older.
- Even the plugins that add insert-mode motion avoid clobbering core keys (vim-rsi), or keep the feature off by default and aim at a narrow case such as jumping past autopairs (mini.basics).

### Gaps
- linty-org/readline.nvim: the README fetch returned 404 on both `master` and `main`, so its maps and stars could not be verified.
- houtsnip/vim-emacscommandline and vim-utils/vim-husk (both command-line only, from memory) were not verified.
- The GitHub API was blocked, so there are no star counts for most repos, including LazyVim, kickstart, NvChad and mini.nvim.
- The vim-rsi issues page could not be fetched (robots_disallowed), so specific user complaints about Meta keys and accented characters could not be cited.

## Q4. Well-known users: Esc vs insert-mode movement, jk, Caps Lock as Esc, `<C-c>`

### Takeaway
None of the prominent users' configs that were checked add insert-mode cursor motions. ThePrimeagen maps `<C-c>` to `<Esc>`. TJ DeVries' keymaps have no insert-mode motions. Drew Neil teaches fast switching back to normal mode (`<C-[>`) and `<C-o>` for one-off commands. Community consensus is to leave insert mode to navigate, and make leaving cheap (Caps Lock as Esc, jk, Ctrl-C).

### Cited Findings
- ThePrimeagen's init.lua `remap.lua` has `-- This is going to get me cancelled` followed by `vim.keymap.set("i", "<C-c>", "<Esc>")`. The map makes `<C-c>` behave fully like Esc, for example firing InsertLeave. It adds no insert-mode motions — [ThePrimeagen/init.lua remap.lua](https://github.com/ThePrimeagen/init.lua/blob/master/lua/theprimeagen/remap.lua)
- TJ DeVries' `plugin/keymaps.lua` maps normal-mode `<c-hjkl>` for split navigation and normal-mode `<M-j>/<M-k>` for moving lines or diff hunks, plus `<CR>` to clear hlsearch. No insert-mode navigation maps were found — [tjdevries/config.nvim plugin/keymaps.lua](https://github.com/tjdevries/config.nvim/blob/master/plugin/keymaps.lua)
- Drew Neil (Practical Vim, Tip 14 "Get Back to Normal Mode"): "Insert mode is specialized for one task" and "it's important to be able to switch quickly between them". He notes Esc "can seem like a long reach" and that "we can press <C-[>, which has exactly the same effect". The same tip lists `<C-o>` as "Switch to Insert Normal mode" — [Practical Vim 2nd ed., Tip 14 (O'Reilly)](https://www.oreilly.com/library/view/practical-vim-2nd/9781680501629/f_0034.xhtml)
- Tim Pope, who wrote vim-rsi, limits readline keys to insert and command-line modes and avoids "blindly overriding built-in Vim functionality" — [vim-rsi README](https://github.com/tpope/vim-rsi)
- Igor Irianto (Learn-Vim, ch. 6): "I find <Esc> key too far to reach, so I map my computer <Caps-Lock> to behave like <Esc>." He calls `jj`/`jk` → Esc a common convention and describes `Ctrl-o` as "you can do *one* normal mode command". He lists `Ctrl-w` (delete word) and `Ctrl-u` (delete line) — [Learn-Vim ch06 (fork of iggredible/Learn-Vim)](https://github.com/sweetbiscuit-dy/Learn-Vim/blob/master/ch06_insert_mode.md)
- Brandur Leach (2016): "The use of Esc in Vim has always been considered a bit of an anti-pattern due to the travel distance required off of the home row." He found `Ctrl+[` awkward and switched to `Ctrl+C`. To break the habit, he remapped Esc in insert mode to insert junk text — [brandur.org "No escape"](https://brandur.org/fragments/no-escape)
- r/neovim thread "Ditching arrow keys: my biggest obstacle is [navigating in insert mode]" (Aug 2024, about 20 upvotes, 77 comments). The majority view: "Just don't navigate in insert mode. That's why god invented normal mode." and "I just quit insert mode when I need to navigate. Isn't that how its done?" Others recommend Caps Lock→Esc and Ctrl+C. A minority use Alt+hjkl, Ctrl+hjkl ("It's not because we use differently than you than it's a mistake") or `<C-o>` — [r/neovim thread (mirror)](https://red.127.pp.ua/r/neovim/comments/1f0tnxe/ditching_arrow_keys_my_biggest_obstacle_is)

### Inferences
- The dominant expert pattern is "Esc (made cheap), move in normal mode, re-enter with i/a/A/I/o", with `<C-o>` for one-off commands. Insert-mode motion maps are a minority habit, though a defensible one, mostly limited to small moves such as stepping past an auto-closed bracket.
- The "make Esc cheap" approaches are Caps Lock→Esc (Irianto, Reddit), `<C-[>` (Neil), `<C-c>` (Primeagen, Brandur) and `jk`/`jj` (better-escape.nvim).

### Gaps
- No direct video quote from ThePrimeagen, TJ or folke on navigating inside insert mode was found. The YouTube transcript search returned nothing usable. folke's personal dotfiles were not checked separately; LazyVim reflects his defaults.
- Drew Neil's full Tip 15 text on Insert Normal mode was not fetched.

## Q5. Insert-mode quality-of-life maps that people do keep

### Takeaway
Experts don't add insert-mode navigation. What they keep are editing aids: undo break-points, built-in `<C-w>`/`<C-u>` deletion, `<C-o>` one-shots, completion keys (`<C-n>/<C-p>/<C-y>`), autopairs, snippet jumps, and line-move maps.

### Cited Findings
- Undo break-points `inoremap , ,<c-g>u` (and `.` `;`) ship by default in LazyVim — [LazyVim keymaps.lua](https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua)
- Completion navigation: kickstart documents `<c-n>/<c-p>` to select, `<c-y>` to accept, `<c-e>` to hide and `<c-space>` to open, all native-style keys — [kickstart.nvim init.lua](https://github.com/nvim-lua/kickstart.nvim/blob/master/init.lua). vim-rsi deliberately preserves `<C-n>`/`<C-p>` completion and passes `<C-e>` through when the popup menu is visible — [vim-rsi README](https://github.com/tpope/vim-rsi); [plugin/rsi.vim](https://github.com/tpope/vim-rsi/blob/master/plugin/rsi.vim)
- Built-in deletion `Ctrl-w` (word) and `Ctrl-u` (line), plus `Ctrl-o` for one normal command — [Learn-Vim ch06](https://github.com/sweetbiscuit-dy/Learn-Vim/blob/master/ch06_insert_mode.md)
- The Escape key also stops snippet sessions in LazyVim (`LazyVim.cmp.actions.snippet_stop()`) — [LazyVim keymaps.lua](https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua)
- Autopairs interaction: mini.basics' `<M-l>` is presented as the way to step out of inserted pairs — [mini.basics source](https://github.com/echasnovski/mini.nvim/blob/main/lua/mini/basics.lua)
- Line moves from insert mode: LazyVim `<A-j>/<A-k>` — [LazyVim keymaps.lua](https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua)

### Inferences
- If you add insert-mode motions, the low-conflict choices are Alt-based keys (mini.basics style) or vim-rsi's context-aware Ctrl keys. NvChad-style `<C-h/j/k/l>` overrides the built-in `i_CTRL-H` (backspace) and `i_CTRL-K` (digraph).

### Gaps
- The snippet-jump keys of LuaSnip and blink.cmp (`<Tab>`/`<S-Tab>`, `<C-l>`/`<C-h>` in some configs) were not verified from source in this pass.
