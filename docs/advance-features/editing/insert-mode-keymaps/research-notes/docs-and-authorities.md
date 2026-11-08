# Vim insert-mode navigation: what the official docs and recognized authorities say

Versions checked: Vim help files on `vim/vim` master (header: "For Vim version 9.2. Last change: 2026 Oct 25"). Neovim help on `neovim/neovim` master (Nvim HEAD, i.e. after 0.12), compared against the `release-0.10`, `release-0.11` and `release-0.12` branches. The raw help files were downloaded and read directly. Rendered versions are at vimhelp.org and neovim.io/doc/user.

Primary doc URLs used throughout:
- Vim insert.txt: https://vimhelp.org/insert.txt.html (raw: https://raw.githubusercontent.com/vim/vim/master/runtime/doc/insert.txt)
- Neovim insert.txt: https://neovim.io/doc/user/insert.html (raw: https://raw.githubusercontent.com/neovim/neovim/master/runtime/doc/insert.txt)
- Vim undo.txt: https://vimhelp.org/undo.txt.html
- Vim usr_24.txt: https://vimhelp.org/usr_24.txt.html

## Q1. Exact documented behavior of the built-in insert-mode keys

### Takeaway
Vim has a small set of built-in insert-mode editing keys: `CTRL-H`, `CTRL-W`, `CTRL-U`, `CTRL-T`, `CTRL-D` and `CTRL-R`. The docs list the cursor and navigation keys (arrows, `<S-Left>`/`<S-Right>`, `<Home>`/`<End>`, `CTRL-O`) separately as "special special keys". These keys "stop the current insert, do something, and then restart insertion." That design is the source of every undo and repeat side effect covered in Q2.

### Cited Findings
**Deletion and editing keys (insert.txt, section 1 `ins-special-keys`)**
- `CTRL-H` / `<BS>`: "Delete the character before the cursor (see |i_backspacing| about joining lines)." — [Vim insert.txt](https://vimhelp.org/insert.txt.html#i_CTRL-H)
- `CTRL-W`: "Delete the word before the cursor (see |i_backspacing| about joining lines). See the section 'word motions', |word-motions|, for the definition of a word." — [Vim insert.txt](https://vimhelp.org/insert.txt.html#i_CTRL-W)
- `CTRL-U`: "Delete all characters that were entered after starting Insert mode and before the cursor in the current line. If there are no newly entered characters and 'backspace' is not empty, delete all characters before the cursor in the current line." — [Vim insert.txt](https://vimhelp.org/insert.txt.html#i_CTRL-U)
- 'backspace' controls all three keys. `start` means "allow backspacing over the start of insert; CTRL-W and CTRL-U stop once at the start of insert". `nostop` means "like start, except CTRL-W and CTRL-U do not stop at the start of insert". "When 'backspace' is empty, Vi compatible backspacing is used." — [Vim insert.txt, i_backspacing](https://vimhelp.org/insert.txt.html#i_backspacing)
- `CTRL-T`: "Insert one shiftwidth of indent at the start of the current line. The indent is always rounded to a 'shiftwidth' (this is vi compatible)." `CTRL-D` deletes one shiftwidth in the same way. `0 CTRL-D` means "Delete all indent in the current line." — [Vim insert.txt](https://vimhelp.org/insert.txt.html#i_CTRL-T)
- `CTRL-R {register}`: "Insert the contents of a register… The text is inserted as if you typed it, but mappings and abbreviations are not used. If you have options like 'textwidth', 'formatoptions', or 'autoindent' set, this will influence what will be inserted." `CTRL-R CTRL-R` inserts "literally, not as if typed". `CTRL-R CTRL-O` inserts "literally and don't auto-indent". `CTRL-R CTRL-P` inserts "literally and fix the indent". For `CTRL-R =` the docs say "When append() or setline() is invoked the undo sequence will be broken." — [Vim insert.txt](https://vimhelp.org/insert.txt.html#i_CTRL-R)
- `CTRL-R -` (small-delete register) "is repeatable using |.| since it remembers the register to put instead of the literal text to insert." — [Vim insert.txt](https://vimhelp.org/insert.txt.html#i_CTRL-R_-)
- `CTRL-C`: "Quit insert mode, go back to Normal mode. Do not check for abbreviations. Does not trigger the |InsertLeave| autocommand event." — [Vim insert.txt](https://vimhelp.org/insert.txt.html#i_CTRL-C)

**Navigation keys (insert.txt, section 2 `ins-special-special`)**
- Intro paragraph, quoted in full: "The following keys are special. They stop the current insert, do something, and then restart insertion. This means you can do something without getting out of Insert mode. This is very handy if you prefer to use the Insert mode all the time, just like editors that don't have a separate Normal mode." — [Vim insert.txt](https://vimhelp.org/insert.txt.html#ins-special-special)
- Table entries:
  - `<S-Left>`/`<C-Left>`: "cursor one word back (like "b" command)"
  - `<S-Right>`/`<C-Right>`: "cursor one word forward (like "w" command)"
  - `<Home>`: "cursor to first char in the line"
  - `<End>`: "cursor to after last char in the line"
  - `<C-Home>`/`<C-End>`: first char, or after last char, in the file
  - `CTRL-G k`/`j`: "cursor one line up/down, insert start column"
  - `CTRL-O`: "execute one command, return to Insert mode"
  - `CTRL-\ CTRL-O`: "like CTRL-O but don't move the cursor"
  - `CTRL-G u`: "close undo sequence, start new change"
  - `CTRL-G U`: "don't start a new undo block with the next left/right cursor movement, if the cursor stays within the same line"
  - Source: [Vim insert.txt](https://vimhelp.org/insert.txt.html#ins-special-special)
- "The shifted cursor keys are not available on all terminals." — [Vim insert.txt](https://vimhelp.org/insert.txt.html#ins-special-special)
- With an appropriate 'whichwrap' setting, `<Left>`/`<Right>` on the first or last character of a line wrap to the previous or next line. — [Vim insert.txt](https://vimhelp.org/insert.txt.html#ins-special-special)
- Vim (not Neovim) also says: "If the cursor keys take you out of Insert mode, check the 'noesckeys' option." — [Vim insert.txt](https://vimhelp.org/insert.txt.html#ins-special-special)

**Vim's own user manual on fixing typos from inside insert mode (usr_24.1 "Making corrections")**
- It introduces `CTRL-W` ("When you typed a whole word wrong") and `CTRL-U` ("If you really messed up a line and want to start over"). — [usr_24.txt](https://vimhelp.org/usr_24.txt.html#24.1)
- For a typo a few words back, the manual first gives `<Esc>4blraA` (leave insert mode, use normal-mode motions, re-enter with `A`). It then shows the insert-mode alternative `<C-Left><C-Left><C-Left><C-Left><Right><Del>a<End>` and judges it: "This uses special keys to move around, while remaining in Insert mode. This resembles what you would do in a modeless editor. It's easier to remember, but takes more time (you have to move your hand from the letters to the cursor keys, and the <End> key is hard to press without looking at the keyboard). These special keys are most useful when writing a mapping that doesn't leave Insert mode. The extra typing doesn't matter then." — [usr_24.txt](https://vimhelp.org/usr_24.txt.html#24.1)
- On CTRL-O (usr_24.x): "When you want to use one, you usually leave Insert mode with <Esc>, execute the Normal mode command, and re-enter Insert mode with "i" or "a". There is a quicker way. With CTRL-O {command} you can execute any Normal mode command from Insert mode." It gives the examples `CTRL-O D` and `CTRL-O "g3dw`. "You can execute only one Normal mode command this way. But you can specify a register or a count." — [usr_24.txt](https://vimhelp.org/usr_24.txt.html)

### Inferences
- Vim's own manual presents `<Esc>`, then a motion, then re-entering insert as the usual route ("you usually leave Insert mode"). It calls `CTRL-O` "a quicker way" for running one normal-mode command. It calls arrow-key navigation the "modeless editor" style: easier to remember but slower, and mainly useful in mappings.

### Gaps
- None for the key definitions. All of them were read verbatim from the current help files.

## Q2. Undo granularity and dot-repeat with arrow keys and `<C-o>`; what `i_CTRL-G_U` is for; Neovim differences

### Takeaway
In Vim 9.x and Neovim up to 0.12:
- Every special-special key, including the arrows and `<C-o>`, splits the insert into separately undoable changes.
- `.` then repeats only the last segment, as if it were a plain `i` command.
- `CTRL-G U` (added in Vim 7.4.849, Sept 2015) exists so mappings can move left or right within a line without breaking undo or repeat.

Neovim HEAD (after 0.12, unreleased) changed this: `.` now replays the whole insert, including relative cursor moves. Undo and the `.` register still split at each move.

### Cited Findings
- Vim 9.2: "The changes (inserted or deleted characters) before and after these keys can be undone separately. Only the last change can be redone and always behaves like an "i" command." — [Vim insert.txt](https://vimhelp.org/insert.txt.html#ins-special-special)
- "Using CTRL-O splits undo: the text typed before and after it is undone separately. If you want to avoid this (e.g., in a mapping) you might be able to use CTRL-R = |i_CTRL-R|. E.g., to call a function: `:imap <F2> <C-R>=MyFunc()<CR>`" — [Vim insert.txt](https://vimhelp.org/insert.txt.html#ins-special-special)
- The CTRL-G U example mappings are `inoremap <Left> <C-G>U<Left>`, `inoremap <Right> <C-G>U<Right>`, `<expr>` versions of `<Home>`/`<End>`, and `inoremap ( ()<C-G>U<Left>`. The docs say: "This makes it possible to use the cursor keys in Insert mode, without starting a new undo block and therefore using |.| (redo) will work as expected. Also entering a text like (with the "(" mapping from above): Lorem ipsum (dolor will be repeatable by using |.| to the expected Lorem ipsum (dolor)". — [Vim insert.txt](https://vimhelp.org/insert.txt.html#i_CTRL-G_U)
- Origin of CTRL-G U: Patch 7.4.849, "Problem: Moving the cursor in Insert mode starts new undo sequence. Solution: Add CTRL-G U to keep the undo sequence for the following cursor movement command. (Christian Brabandt)". The diff timestamps are from 2015-09-01. — [Patch 7.4.849 (CentOS mirror)](https://git.centos.org/rpms/vim/raw/1eb8d3f8219cf7511626bf40a83ed39c437684b0/f/7.4.849)
- Follow-up Patch 8.1.1055: "CTRL-G U in Insert mode doesn't work to avoid splitting the undo sequence for shift-left and shift-right. Solution: Also check dont_sync_undo for shifted cursor keys. (Christian Brabandt)" — [Vim version8.txt](https://vimhelp.org/version8.txt.html#patch-8.1.1055)
- CTRL-G u, the opposite tool: "To do the opposite, use a new undo block for the next change, in Insert mode use CTRL-G u. This is useful if you want an insert command to be undoable in parts. E.g., for each sentence." — [Vim undo.txt, undo-break](https://vimhelp.org/undo.txt.html#undo-break)
- insert.txt gives example uses of CTRL-G u:
  - `:inoremap <C-H> <C-G>u<C-H>`, described as "You can now undo the effect of the backspace key, without changing what you typed before that, with CTRL-O u."
  - `:inoremap <CR> <C-]><C-G>u<CR>`, described as "starts a new undo block at each line break. It also expands abbreviations before this."
  - Source: [Vim insert.txt](https://vimhelp.org/insert.txt.html#i_CTRL-G_u)
- Default mappings built on this:
  - Vim's `defaults.vim` ships `inoremap <C-U> <C-G>u<C-U>`, with the comment: "CTRL-U in insert mode deletes a lot. Use CTRL-G u to first break undo, so that you can undo CTRL-U after inserting a line break." — [vim/runtime/defaults.vim](https://github.com/vim/vim/blob/master/runtime/defaults.vim)
  - Neovim's `default-mappings` include `<C-U>` (`i_CTRL-U-default`) and `<C-W>` (`i_CTRL-W-default`): "By default, sets a new undo point before deleting." — [Neovim vim_diff.txt default-mappings](https://neovim.io/doc/user/vim_diff.html#default-mappings); [Neovim insert.txt](https://neovim.io/doc/user/insert.html#i_CTRL-W-default)
- Neovim HEAD changed repeat behavior (new `*ins-repeat*` tag):
  - "Relative cursor-moves (the cursor keys, <S-Left>, <Home>, CTRL-G j, …) are part of the insert: |.| repeats the whole insert, including cursor-moves. After a jump (mouse, scroll, <PageUp>, …) only the last change can be redone, and it behaves like an "i" command. The |quote.| register always holds just the text typed after the last cursor-move." — [Neovim insert.txt (master)](https://neovim.io/doc/user/insert.html#ins-repeat)
  - news.txt, "changes since Nvim 0.12": "|ins-repeat| replays the full Insert session, including cursor-moves. Undo and |quote.| still restart at each cursor-move. Use |i_CTRL-O| to get the old behavior: `inoremap <Left> <C-o><Left>` / `inoremap <Right> <C-o><Right>`" — [Neovim news.txt (master)](https://github.com/neovim/neovim/blob/master/runtime/doc/news.txt)
  - The CTRL-G U section gained the note: "Cursor keys are captured by |.| (|ins-repeat|), so these mappings are only needed to keep the cursor-move from starting a new undo block." — [Neovim insert.txt (master)](https://neovim.io/doc/user/insert.html#i_CTRL-G_U)
  - The `ins-repeat` tag does not appear in the `release-0.10`, `release-0.11` or `release-0.12` branches of insert.txt, so released Neovim 0.10–0.12 behave like Vim. — [Neovim release-0.11 insert.txt](https://github.com/neovim/neovim/blob/release-0.11/runtime/doc/insert.txt)
- Practical Vim, Tip 8 "Chunk Your Undos" (secondary notes quoting the book): "If we use the <Up>, <Down>, <Left>, or <Right> cursor keys while in Insert mode, a new undo chunk is created. It's just as though we had switched back to Normal mode to move around with the h, j, k, or l commands, except that we don't have to leave Insert mode. This also has implications on the operation of the dot command." — [notes on Practical Vim](https://yesterlife.github.io/2018/03/17/practical-vim-modes); the tip's opening ("i{insert some text}<Esc> constitutes a change") is on [O'Reilly preview, Tip 8](https://www.oreilly.com/library/view/practical-vim-2nd/9781680501629/f_0027.xhtml)

### Inferences
- For the user's question, on Vim 9.x and Neovim 0.10–0.12, two habits behave the same for undo and repeat:
  - Moving with arrows or `<C-o>` inside insert mode.
  - Pressing `<Esc>`, moving, and pressing `i` again.

  Both split the edit into separate undo steps, and `.` repeats only the final piece. `<C-o>` therefore saves keystrokes but not undo or repeat "atomicity".
- Only `<C-G>U<Left>`/`<C-G>U<Right>` within one line keep a single undo and repeat unit. That is why auto-pair plugins use it. Readline-style mappings such as `inoremap <C-b> <Left>` split undo and break `.` unless they are written as `<C-G>U<Left>`.
- Neovim HEAD's change narrows this gap for `.`, but undo is still split.

### Gaps
- The exact Neovim release that will ship `ins-repeat` (presumably 0.13) could not be confirmed. news.txt only places it under "changes since Nvim 0.12" on master.
- Practical Vim's full Tip 8 text is paywalled. The quote above comes from a reader's notes, not the publisher's page.

## Q3. Quirks of `<C-o>`: cursor at end of line, `virtualedit=onemore`, InsertLeave/ModeChanged, abbreviations, counts

### Takeaway
`<C-o>` leaves insert mode for real:
- It fires InsertLeavePre and InsertLeave, and the mode becomes `niI`.
- It can shift the cursor left by one at end of line, unless 'virtualedit' contains `onemore`.
- It triggers pending abbreviations.
- It discards counts on the original `i`/`a`.
- It splits undo.

### Cited Findings
- End-of-line side effect: "The CTRL-O command sometimes has a side effect: If the cursor was beyond the end of the line, it will be put on the last character in the line. In mappings it's often better to use <Esc> (first put an "x" in the text, <Esc> will then always put the cursor on it). Or use CTRL-\ CTRL-O, but then beware of the cursor possibly being beyond the end of the line. Note that the command following CTRL-\ CTRL-O can still move the cursor, it is not restored to its original position." — [Vim insert.txt](https://vimhelp.org/insert.txt.html#i_CTRL-O)
- `virtualedit=onemore`: Vim's source handles `Ctrl_O` with the comment "don't move the cursor left when 'virtualedit' has "onemore"" and sets `ins_at_eol = FALSE; nomove = TRUE;`. — [vim/src/edit.c](https://github.com/vim/vim/blob/master/src/edit.c)
- The option doc says onemore will "only allow moving the cursor just after the last character of the line… It may also break some plugins or Vim scripts. For example because |l| can move the cursor after the last character. Use with care!" — [Vim options.txt 'virtualedit'](https://vimhelp.org/options.txt.html#%27virtualedit%27)
- Nesting: "The CTRL-O command takes you to Normal mode. If you then use a command enter Insert mode again it normally doesn't nest. Thus when typing "a<C-O>a" and then <Esc> takes you back to Normal mode, you do not need to type <Esc> twice. An exception is when not typing the command, e.g. when executing a mapping or sourcing a script." — [Vim insert.txt](https://vimhelp.org/insert.txt.html#i_CTRL-O)
- Counts: "a count specified before the "i" or "a" command is ignored. That is because repeating the effect of the command after CTRL-O is too complicated." Also, under `i`: "When using CTRL-O in Insert mode |i_CTRL-O| the count is not supported." — [Vim insert.txt](https://vimhelp.org/insert.txt.html#i)
- Autocommands:
  - "InsertLeavePre — Just before leaving Insert mode. Also when using CTRL-O |i_CTRL-O|."
  - "InsertLeave — Just after leaving Insert mode. Also when using CTRL-O |i_CTRL-O|. But not for |i_CTRL-C|."
  - Source: [Vim autocmd.txt](https://vimhelp.org/autocmd.txt.html#InsertLeave)
  - Neovim has the same text. — [Neovim autocmd.txt](https://neovim.io/doc/user/autocmd.html#InsertLeave)
- Mode string: `mode(1)` returns `niI` for "Normal using |i_CTRL-O| in |Insert-mode|" and `niR` for Replace mode. ModeChanged fires "After changing the mode", matched against `'old_mode:new_mode'`. — [Vim builtin.txt mode()](https://vimhelp.org/builtin.txt.html#mode%28%29); [Vim autocmd.txt ModeChanged](https://vimhelp.org/autocmd.txt.html#ModeChanged)
- Abbreviations:
  - The docs say: "An abbreviation is only recognized when you type a non-keyword character. This can also be the <Esc> that ends Insert mode…" — [Vim map.txt abbreviations](https://vimhelp.org/map.txt.html#abbreviations)
  - The source also checks abbreviations on CTRL-O (`case Ctrl_O: … if (echeck_abbr(Ctrl_O + ABBR_OFF)) break;`), so a pending abbreviation expands when `<C-o>` is pressed. — [vim/src/edit.c](https://github.com/vim/vim/blob/master/src/edit.c)
  - `CTRL-C` explicitly does "not check for abbreviations". — [Vim insert.txt](https://vimhelp.org/insert.txt.html#i_CTRL-C)
- `<Cmd>` mappings are the modern alternative: "This is more flexible than `:<C-U>` in Visual and Operator-pending mode, or `<C-O>:` in Insert mode, because the commands are executed directly in the current mode, instead of always going to Normal mode." — [Vim map.txt :map-cmd](https://vimhelp.org/map.txt.html#%3Amap-cmd)

### Inferences
- Plugins that react to InsertLeave or ModeChanged see a mode change on every `<C-o>`. Examples include auto-save, linters, IME switching, and statusline mode indicators. This is a practical cost of heavy `<C-o>` use compared with `<Cmd>` mappings.
- The `ModeChanged` firing on `<C-o>` is inferred from the documented mode change to `niI`. The docs do not say it in so many words.

### Gaps
- Whether arrow keys (as opposed to `<C-o>`) trigger abbreviation expansion is not documented. The `echeck_abbr` calls found in edit.c cover `<Esc>`, CTRL-O, CTRL-L, Tab, non-keyword characters, and the CR/NL path. Arrows were not verified.
- No doc line explicitly confirms that ModeChanged fires for `i:niI`. It follows from the `mode()` table.

## Q4. What Moolenaar, Drew Neil, Tom Ryder and others recommend; is navigating within insert mode ever endorsed?

### Takeaway
The consensus among recognized authorities is "Normal mode is the resting state, insert mode is for inserting". Practical Vim and Tom Ryder say so explicitly. Vim's user manual implies it by calling Esc-then-motion the "usual" route.

The only official endorsement of navigating inside insert mode is narrow:
- Vim's docs call the special keys "very handy if you prefer to use the Insert mode all the time, just like editors that don't have a separate Normal mode".
- The user manual calls them "easier to remember, but takes more time" and "most useful when writing a mapping".
- `<C-o>` is presented as a "quicker way" for a single command.
- Practical Vim endorses insert-mode corrections (`<C-h>`/`<C-w>`/`<C-u>`) and `<C-o>zz` (Insert Normal mode), not arrow navigation.

### Cited Findings
- **Bram Moolenaar, "Seven habits of effective text editing" (2000)**:
  - He does not discuss modes. His method is the three-step loop: "Detect inefficiency… Find a quicker way… Make it a habit."
  - He promotes CTRL-N completion while typing ("type "XpmCr", then hit CTRL-N").
  - His framing: "Most time is spent reading, checking for errors and looking for the right place to work on, rather than inserting new text or changing it."
  - Source: [moolenaar.net/habits.html](https://www.moolenaar.net/habits.html)
- **Vim user manual (written by Moolenaar)**: "you usually leave Insert mode with <Esc>, execute the Normal mode command, and re-enter Insert mode with "i" or "a". There is a quicker way. With CTRL-O {command}…" On arrow-key correction: "easier to remember, but takes more time… most useful when writing a mapping that doesn't leave Insert mode." — [usr_24.txt](https://vimhelp.org/usr_24.txt.html)
- **Drew Neil, Practical Vim (2nd ed.)**:
  - Chapter 2: "Normal mode is Vim's natural resting state. If this chapter seems surprisingly short, then that's because most of this book is about how to use Normal mode!" — [O'Reilly preview, Ch. 2](https://www.oreilly.com/library/view/practical-vim-2nd/9781680501629/f_0025.xhtml)
  - Same page: "Other text editors spend most of their time in something that resembles Insert mode."
  - Insert-mode chapter tips: 13 "Make Corrections Instantly from Insert Mode" (`<C-h>`, `<C-w>`, `<C-u>`), 14 "Get Back to Normal Mode" (`<Esc>`, `<C-[>`, `<C-o>` = "Switch to Insert Normal mode"), 15 "Paste from a Register Without Leaving Insert Mode" (`<C-r>{register}`). — [O'Reilly Tip 14 preview](https://www.oreilly.com/library/view/practical-vim-2nd/9781680501629/f_0034.xhtml); [tip summary](https://komputerwiz.net/practical-vim/)
  - Tip 14 (via reader notes): "Insert Normal mode is a special version of Normal mode… It allows one command to execute, after which it will return to Insert mode immediately… in Insert mode, <C-o>zz helps to move our input flow into the middle of the window." — [notes on Practical Vim](https://yesterlife.github.io/2018/03/17/practical-vim-modes)
  - Tip 8 advice: to keep undo granular, press `<Esc>o` instead of `<CR>` when opening a new line. Per the tip summary: "If you are wondering if you should leave insert mode, just do it." — [notes on Practical Vim](https://yesterlife.github.io/2018/03/17/practical-vim-modes); [tip summary](https://komputerwiz.net/practical-vim/)
- **Tom Ryder, "Vim anti-patterns" (2012-02-07)**:
  - "Moving in insert mode" section: "…ease you into thinking less about insert mode as a mode in which you move around; that's what normal mode is for. You should, in general, spend as little time in insert mode as possible… This distinction also helps to keep your insert operations more *atomic*, and hence more useful to repeat."
  - On arrow keys: "once you're used to using hjkl to navigate, moving to the arrow keys to move around in text feels clumsy… wean yourself off the arrow keys, by… disabling them entirely, at least temporarily."
  - Source: [blog.sanctum.geek.nz/?p=282](https://blog.sanctum.geek.nz/?p=282)
- **'insertmode' (modeless Vim)**:
  - Vim still documents `'insertmode'`: "Makes Vim work in a way that Insert mode is the default mode. Useful if you want to use Vim as a modeless editor. Used for |evim|." Its suggested tools are "Use the cursor keys to move around. Use CTRL-O to execute one Normal mode command… Use CTRL-L to execute a number of Normal mode commands." — [Vim options.txt 'insertmode'](https://vimhelp.org/options.txt.html#%27insertmode%27)
  - Neovim removed `'insertmode'`. It offers an emulation instead: `autocmd BufWinEnter * startinsert` / `inoremap <Esc> <C-X><C-Z><C-]>`. Neovim's `ins-special-special` intro also dropped the advice to set 'insertmode'. — [Neovim vim_diff.txt](https://neovim.io/doc/user/vim_diff.html); [Neovim insert.txt](https://neovim.io/doc/user/insert.html#ins-special-special)

### Inferences
- Officially, insert-mode navigation is a supported, documented way to work. Vim frames it as the modeless-editor or mapping use case rather than best practice for fluent users.
- Every recognized authority found (Vim user manual, Practical Vim, Tom Ryder) points users toward `<Esc>` → motion → `i`/`a`/`A` for anything beyond a tiny fix. Their stated reasons are speed (home row) and atomic undo and repeat.
- Neovim removing `'insertmode'` signals that modeless use is not a goal there.
- Insert-mode keys that authorities do endorse are deletions (`<C-h>`, `<C-w>`, `<C-u>`), `<C-r>` for pasting, `<C-n>`/`<C-p>` completion, and a single `<C-o>` command (e.g. `<C-o>zz`).

### Gaps
- No primary-source Vimcasts episode specifically about insert-mode navigation was found within the research budget.
- "Learn to speak vim" (Ted Naleid / Yan Pritzker essays) was not fetched, so no claim is made about it.
- Bram's habits essay does not address the question directly. Attributing a "stay in Normal mode" view to him rests on the user manual he wrote, not on the essay.

## Q5. Readline/Emacs-style keys in Vim's own docs (`emacs-keys`, `tcsh-style`)

### Takeaway
Vim's docs give Emacs/tcsh-style mappings only for the command line (`:cnoremap`), not for insert mode. Neither Vim nor Neovim ships readline insert-mode bindings by default.

### Cited Findings
- `:help emacs-keys` (tips.txt) is titled "For Emacs-style editing on the command-line". It lists `:cnoremap <C-A> <Home>`, `<C-B> <Left>`, `<C-D> <Del>`, `<C-E> <End>`, `<C-F> <Right>`, `<C-N> <Down>`, `<C-P> <Up>`, `<Esc><C-B> <S-Left>`, `<Esc><C-F> <S-Right>`. "NOTE: This requires that the '<' flag is excluded from 'cpoptions'." — [Vim tips.txt](https://vimhelp.org/tips.txt.html#emacs-keys); also in [Neovim tips.txt](https://neovim.io/doc/user/tips.html#emacs-keys)
- `:help tcsh-style` (cmdline.txt): "if your keyboard does not have working cursor keys or any of the other special keys, you can use ":cnoremap" to define another key for them. For example, to define tcsh style editing keys: `:cnoremap <C-A> <Home>` / `<C-F> <Right>` / `<C-B> <Left>` / `<Esc>b <S-Left>` / `<Esc>f <S-Right>`" — [Vim cmdline.txt](https://vimhelp.org/cmdline.txt.html#tcsh-style)
- In Vim's insert mode, several readline keys already mean something else:
  - `CTRL-A` = "Insert previously inserted text"
  - `CTRL-E`/`CTRL-Y` = insert the character below/above the cursor
  - `CTRL-D` = de-indent
  - `CTRL-N`/`CTRL-P` = keyword completion
  - `CTRL-K` = digraph
  - Source: [Vim insert.txt](https://vimhelp.org/insert.txt.html#ins-special-keys)
- Practical Vim notes that `<C-h>`, `<C-w>` and `<C-u>` "also typically work in the shell" (bash/readline). — [tip summary](https://komputerwiz.net/practical-vim/)

### Inferences
- Readline-style insert-mode navigation (`<C-a>`, `<C-e>`, `<C-b>`, `<C-f>`) is a third-party convention (e.g. tpope's vim-rsi), not an official recommendation. Mapping it overrides built-in insert keys (`CTRL-A`, `CTRL-E`, `CTRL-D`).
- Unless such maps use `<C-G>U<Left>`/`<C-G>U<Right>` or `<Cmd>`, they split undo and break `.`, as covered in Q2.

### Gaps
- vim-rsi and other plugin docs were outside this assignment's scope ("official docs and authorities") and were not fetched.
