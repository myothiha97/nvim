# Registers & Macros: Beginner → Advanced

A staged guide for day-to-day editing in Neovim (LazyVim). Written for this setup:

- `clipboard=unnamedplus` (LazyVim default outside SSH)
- yanky extra (`p` then `[y` / `]y`, `<leader>p` yank history)
- `<leader>s"` register picker, which-key register popups
- LSP rename, grug-far, multi-cursor, Copilot, mini.pairs
- No custom insert-mode navigation maps. Insert mode uses built-ins only (`Ctrl-R {reg}`, `Ctrl-W`, `Ctrl-U`, `Ctrl-O`).

You already know: `"0p`, named `a`–`z`, `"_`, `"+`, `Ctrl-R 0`, `Ctrl-R Ctrl-O 0`, `viwp`, `*` + `cgn` + `.`, `qq…q`, `@q`, `@@`, `10@q`, `:'<,'>norm @q`. This guide recaps those briefly and builds past them.

How to use it: do one level per week. Each level ends with drills. A level is "done" when you use its moves without thinking about them in real work, not when you've read it.

---

## Level 0: The mental model (read once)

A register is a named slot holding text. Every yank, delete, and change writes to one or more slots. Every put reads from one. Macros are just keystrokes stored in a register, so the same slots power both.

| Register | Written by | Notes |
|---|---|---|
| `""` unnamed | every yank/delete/change | With `unnamedplus`, this **is** `"+` (system clipboard) |
| `"0` | yanks only | Survives deletes. Your safest "what I copied" slot |
| `"1`–`"9` | deletes/changes of a line or more | Shift down each time: `"1` newest, `"9` oldest |
| `"-` | deletes smaller than a line | `dw`, `x`, `ciw` land here |
| `"a`–`"z` | only when you name them | `"ayy` overwrites, `"Ayy` **appends** |
| `"+` / `"*` | system clipboard | Same thing on macOS |
| `"_` | black hole | Write-only. Delete without touching anything |
| `".` | last inserted text | Read-only |
| `":` | last Ex command | Read-only. `@:` re-runs it |
| `"/` | last search pattern | Read-only |
| `"%` / `"#` | current / alternate file name | Read-only |
| `"=` | expression | Evaluates Vimscript, e.g. `=2*1024` |

**The one gotcha that matters most with your setup:** because `""` is the clipboard, `dd`, `x`, `ciw` all overwrite your system clipboard. You copy a URL in the browser, `dd` a line in Neovim, and the URL is gone from `"+`. Fixes, in order of preference:

1. Paste with `"0p` when you mean "what I yanked".
2. Delete with `"_d…` when you know you won't need the text.
3. Use yanky history (`<leader>p`) to recover anything lost.

Ways to look inside registers:

- `:reg` or `:reg 0 a q` shows contents (`^[` = Esc, `^M` = Enter).
- `<leader>s"` opens the picker; select to paste.
- Press `"` or `@` in normal mode, or `Ctrl-R` in insert mode, and pause: which-key shows the contents.

---

## Level 1: Stop losing yanks (recap, week 1)

| Move | What it does |
|---|---|
| `yiw` … `"0p` | Paste the yank even after deletes in between |
| `Ctrl-R 0` (insert) | Insert the last yank while typing |
| `Ctrl-R Ctrl-O 0` (insert) | Same, but literal and without auto-indent mangling multi-line text |
| `p` then `[y` / `]y` | Cycle the just-pasted text through yank history |
| `"_dd`, `"_ciw` | Delete or change without touching clipboard or `"1` |

### Drill 1.1 (TypeScript): copy a type into several places

```ts
type UserId = string;

function getUser(id: string) {}
function deleteUser(id: string) {}
function banUser(id: string) {}
```

Goal: replace each `string` in the three signatures with `UserId`.

1. Cursor on `UserId`, `yiw`.
2. Jump to the first param `string`, `ciw`, then `Ctrl-R 0`, `Esc`.
3. On the next one, `ciw` would have overwritten `""`, but `"0` still holds `UserId`. Repeat with `ciw` + `Ctrl-R 0`, or just press `.` (it replays the insert of `UserId`).

What to notice: `Ctrl-R "` would insert `string` (the text your `ciw` just deleted). `Ctrl-R 0` doesn't.

### Drill 1.2 (Go): recover after an accidental delete

```go
dsn := os.Getenv("DATABASE_URL")
timeout := 30 * time.Second
```

1. `yy` on the first line.
2. Go to line 2 and `dd`.
3. `p` pastes the **deleted** line, not the yanked one. Press `[y` to swap in the older entry from history. Or undo and use `"0p`.

---

## Level 2: Put-over and repeatable changes (recap, week 2)

| Move | What it does |
|---|---|
| `viwp` | Replace a word with the register, no `ciw` needed |
| `viw"0p` | Same, guaranteed to use the yank (repeatable across many words) |
| `*` then `cgn{text}<Esc>` then `.` | Change the next match, `.` changes the next one, `n` skips |
| `"1p` then `u.u.u.` | Walk back through older line deletes: `.` after a numbered put bumps to `"2`, `"3`… |

`viwp` writes the replaced word into `""`, so a second plain `viwp` pastes the old word. That's why `viw"0p` exists. Neovim also has `P` in visual mode (`viwP`), which replaces without overwriting the unnamed register.

### Drill 2.1 (Python): rename a local at a few spots

```python
def load(path):
    data = read(path)
    data = clean(data)
    return parse(data)
```

1. Cursor on `data`, `*` (search whole word), `N` to go back to the first.
2. `cgnrecords<Esc>`.
3. `.` `.` `.` to change the remaining matches. Use `n` to skip one you want to keep.

Use LSP rename (`<leader>cr`) when it's a real symbol across files. `cgn` wins for a handful of visible spots, strings, comments, or files where the LSP is slow or absent.

### Drill 2.2: reclaim deleted lines

Delete three separate lines with `dd` in a scratch buffer. Then `"1p`. Wrong one? `u` then `.` (now `"2p`), `u` then `.` (`"3p`).

---

## Level 3: Named slots and appending (recap, week 3)

| Move | What it does |
|---|---|
| `"ayiw`, `"byi"` | Store two things at once |
| `"ap`, `Ctrl-R a` | Put them back in normal or insert mode |
| `"Ayy` | Append a line to `a` (collect lines from around a file) |
| `qaq` | Clear `a` before collecting (record an empty macro into it) |

### Drill 3.1 (Go): collect imports from scattered code

You're splitting a file and want all `*Handler` func signatures in one place.

```go
func (s *Server) UserHandler(w http.ResponseWriter, r *http.Request) {
...
func (s *Server) OrderHandler(w http.ResponseWriter, r *http.Request) {
...
func (s *Server) AuthHandler(w http.ResponseWriter, r *http.Request) {
```

1. `qhq` to empty `h`.
2. On each signature line: `"Hyy`.
3. Open the new file, `"hp`. All three lines land together.

Faster version (Level 6 preview): `qhq` then `:g/Handler(/yank H`.

### Drill 3.2 (TS): two values, one template

Store a key and a label: `"kyi"` on `'user.created'`, `"lyi"` on `'User created'`. Then in insert mode type `{ key: '` `Ctrl-R k` `', label: '` `Ctrl-R l` `' }`. Two slots, no back-and-forth.

---

## Level 4: Registers in the command line and the expression register

Everything `Ctrl-R` does in insert mode also works on the `:` and `/` lines. This is where registers start saving real time.

| Move | What it does |
|---|---|
| `:%s/Ctrl-R Ctrl-W/new/g` | Insert the **word under cursor** into the command line |
| `:%s/Ctrl-R 0/new/g` | Insert the last yank into a substitute |
| `/Ctrl-R 0` | Search for what you yanked |
| `Ctrl-R =60*60*24 Enter` (insert) | Insert `86400` |
| `Ctrl-R =strftime('%Y-%m-%d') Enter` | Insert today's date |
| `:put 0`, `:put +`, `:put =range(1,5)` | Put a register (or expression result) on its own new line |
| `@:` then `@@` | Repeat the last Ex command, then again |

**Escaping:** a yank like `user.id[0]` contains regex characters. Search for it literally with:

```
/\V<C-r>=escape(@0, '/\')<CR>
```

`\V` is "very nomagic" (only `\` is special), and `escape()` handles the rest.

### Drill 4.1 (Python): substitute the word under cursor

```python
max_retries = 3
if attempt > max_retries:
    log(f"gave up after {max_retries}")
```

Cursor on `max_retries`, then `:%s/\<Ctrl-R Ctrl-W\>/MAX_RETRIES/g`. The `\<…\>` keeps it to whole words. For a real symbol rename across a project, use LSP rename. For text in strings or across many files, use grug-far (`<leader>sr`) and paste into its search field with `Ctrl-R 0` (it's a normal buffer in insert mode, so `Ctrl-R` works).

### Drill 4.2 (Go): compute in place

You need `const maxBody = ` 10 MiB in bytes. In insert mode: `Ctrl-R =10*1024*1024 Enter` gives `10485760`.

---

## Level 5: Macros you can trust

You know `qq…q` and `@q`. Most macros fail on replay for three reasons: the cursor started in a different column, a motion depended on content that varies, or a popup ate a key. Rules that fix all three:

1. **Normalize position first.** Start with `0`, `^`, or a search (`/`, `f`), never "wherever I am".
2. **Move by structure, not counts.** `f,`, `t)`, `w`, `/foo` instead of `5l`.
3. **End where the next run starts.** Usually `j` (and `0` or `^` at the start of the next run).
4. **Fail loudly.** A macro stops at the first failed motion. That's a feature: a failed `f,` on a line without a comma stops `100@q` instead of corrupting the file.
5. **Avoid completion menus during recording.** blink.cmp and Copilot depend on timing and LSP state, so a menu that appeared while recording might not appear on replay (or vice versa). Type the full text, and don't press `Tab` / `Enter` while a menu could be open. Leave insert mode with `Esc` before moving.
6. mini.pairs is deterministic, so auto-closed `(`, `"`, `[` replay the same way. Type the closing character anyway; mini.pairs steps over it.

Recording shows `recording @q` in the cmdline. `q` ends it.

### Drill 5.1 (Go): table-test rows

```go
"empty", "", false
"valid", "a@b.co", true
"no at", "ab.co", false
```

Goal:

```go
{name: "empty", in: "", want: false},
```

Record on the first line:

```
qq ^ I{name: <Esc> f, a in:<Esc> f, a want:<Esc> A},<Esc> j q
```

(spaces between chunks are for reading; type only what's inside them, including the space in `{name: `.)

Then `2@q` or `@q` `@@`.

Break it on purpose: add a row `"a,b", "x", true`. The first `f,` hits the comma inside the string. Lesson: `f,` assumes content. A sturdier choice here is `f"` / `%`-style structure, or use a substitute. Knowing when a macro is the wrong tool is part of this level.

### Drill 5.2 (Python): env vars to typed settings

```
DATABASE_URL
REDIS_URL
SENTRY_DSN
```

Goal: `database_url: str = os.environ["DATABASE_URL"]`

```
qq 0yiw A: str = os.environ["<C-r>0"]<Esc> 0guiw j q
```

Then `2@q`. Note the macro yanks and uses `"0` internally. That's fine, it rewrites `"0` each run.

### Drill 5.3 (TypeScript): Neovim's visual-mode `@q`

In Neovim, `@q` (and `Q`) in Visual mode run the macro once per selected line, the same as `:'<,'>norm @q`. `Q` in Normal mode replays the last recorded macro.

```ts
userId
userName
createdAt
```

Record on line 1: `qqA: string;<Esc>q`. Then `Vj` over the other two lines, `@q`. No trailing `j` needed, because each line runs separately.

---

## Level 6: Macros at scale

### Run a macro on matching lines: `:g`

```
:g/pattern/norm @q
```

Runs on every line matching `pattern`, cursor at column 1 of each. Normalize inside the macro anyway.

**Drill 6.1 (Go):** add a nil-receiver guard to every method of `*Cache`.

```go
func (c *Cache) Get(k string) (V, bool) {
func (c *Cache) Set(k string, v V) {
```

Record on the first signature: `qqoif c == nil {<CR>return<Esc>q`. mini.pairs turns `{` + Enter into the full block. If blink's menu is open when you press Enter, it accepts a completion instead, so check `:reg q` after recording. (Get needs `return V{}, false`, so you'd fix that one by hand. Many macros do 90% and leave you the odd case.) Then `:g/^func (c \*Cache)/norm @q`.

### Run a macro across files: quickfix + `:cdo`

1. Find targets: `<leader>sg` (grep) for the pattern, then `Ctrl-Q` to send results to quickfix. Or `:vimgrep /pattern/ **/*.ts`.
2. Record `q` on one match.
3. `:cdo norm @q | update` runs it at every match and saves each file.
4. Check with `:cfdo` / git diff before committing.

Use `:cfdo` instead of `:cdo` to run once per file rather than once per match.

**Drill 6.2 (TypeScript):** move a module from `console.log` to a logger. Do the replacement with grug-far (`console.log(` → `logger.debug(`). Then grep `logger.debug(` into quickfix and add the import once per file: record `qiggOimport { logger } from "@/lib/logger";<Esc>q` in one file, then `:cfdo norm @i | update` (`:cfdo`, not `:cdo`, or files with three calls get three imports). grug-far for the text, macro for the per-file structure.

### Counters inside a macro

Two ways to number things:

**Visual block increment (no macro):**

```ts
enum Status {
  Pending = 0,
  Active = 0,
  Archived = 0,
}
```

Select the three `0`s with `Ctrl-V`, then `g Ctrl-A`. Result: `1, 2, 3`. Select from the second line to get `0, 1, 2`.

**Expression register (when the number is computed):**

```
:let i = 100
qq 0f,i = <C-r>=i<CR><Esc>:let i += 10<CR>j q
```

Turns `Pending,` / `Active,` into `Pending = 100,` / `Active = 110,`.

---

## Level 7: Editing, chaining, and keeping macros

### Edit a macro instead of re-recording

1. On an empty line: `"qp` (the macro appears as text, `^[` for Esc).
2. Fix it like normal text.
3. `0"qy$` to yank it back **without** the trailing newline. (`"qyy` would add a newline, which runs as an extra `Enter`/`j` on replay.)
4. `"_dd` the scratch line.

Or set it directly: `:let @q = 'A;' . "\<Esc>" . 'j'`. Double quotes are needed for `"\<Esc>"`.

Append to an existing macro: `qQ…q` (uppercase) adds keys to the end of `q`.

### Recursive macros

Run until something fails (end of file, no more matches) without guessing a count.

```
qqq            " clear q first, or the recursive call runs the old contents
qq ... j@q q   " the macro calls itself at the end
@q
```

It stops at the first failed motion, usually the `j` on the last line. Use this for "every line until the end" when the line count isn't known. Prefer a visual selection or `:g` when you can see the range; they're easier to stop.

### Persistence

Registers, including macros, survive restarts (Neovim saves them in shada). A macro you recorded yesterday is still in `q` today. Use stable letters so you know what's where, for example `q` for throwaway, `l` for a long-lived one.

To pin one in your config, set it at startup:

```lua
-- lua/config/autocmds.lua (runs after shada loads, so it isn't overwritten by the saved value)
vim.fn.setreg("l", 'yiwoconsole.log("' .. vim.keycode("<C-r>") .. '0:", ' .. vim.keycode("<C-r>") .. "0);" .. vim.keycode("<Esc>"))
```

`@l` on a variable adds `console.log("var:", var);` below. If you use something like this daily, a keymap or a snippet is the better home. Pinned macros are for jobs you do weekly, not hourly.

---

## Choosing the tool

| Task | Use |
|---|---|
| Rename a symbol (code-aware, across files) | LSP rename `<leader>cr` |
| Literal or regex replace across many files | grug-far `<leader>sr` |
| Same change at a few visible spots | `*` + `cgn` + `.`, or multi-cursor |
| Same change in one column / block | `Ctrl-V` block edit, `g Ctrl-A` for numbers |
| Per-line transform where each line's content differs | Macro (visual `@q` or `:g/…/norm @q`) |
| Same structural edit at matches in many files | Macro + quickfix + `:cdo` |
| Text you need while typing | `Ctrl-R {reg}` |
| Same edit you do daily | Keymap or snippet, not a macro |

A macro is worth it when recording it takes less than doing it twice by hand. For two lines, just edit. From three lines up, record.

---

## Practice plan (continues from weeks 1–3)

| Week | Focus | Daily target |
|---|---|---|
| 4 | Level 4: `Ctrl-R Ctrl-W` in `:s`, `Ctrl-R 0` in `/` and grug-far, `Ctrl-R =` | Once a day, use a register in the command line instead of retyping |
| 5 | Level 5: macro rules, visual `@q` | Record at least one macro a day on real code. Normalize position, end on next line |
| 6 | Level 6: `:g/…/norm @q`, quickfix + `:cdo` | Twice this week, run a macro over matches instead of a count |
| 7 | Level 7: edit with `"qp` / `0"qy$`, recursive macros | Fix one broken macro by editing it instead of re-recording |
| 8+ | Mixed | When you hit a repetitive edit, pick from the table above before starting |

Check yourself at the end of each week: when the situation came up, did you reach for the move without thinking? If not, repeat the week. Speed comes after the habit, not before.

---

## Quick reference

```
REGISTERS
""  unnamed (= "+ with unnamedplus)    "0  last yank
"1-"9  line deletes (newest first)     "-  small delete
"a-"z  named ("A appends)              "_  black hole
".  last insert   ":  last cmd   "/  last search   "=  expression

NORMAL                  INSERT / CMDLINE
"ayiw  yank to a        Ctrl-R a        insert a
"ap    put a            Ctrl-R Ctrl-O a insert literal, no autoindent
"0p    put last yank    Ctrl-R Ctrl-W   word under cursor (cmdline)
viw"0p replace word     Ctrl-R =expr    expression result
"1pu.  older deletes    :put a          put on new line
[y ]y  yanky cycle      <leader>s"      register picker

MACROS
qq … q        record           @q / @@ / Q      run / repeat / last recorded
10@q          run 10 times     V…@q             once per selected line (nvim)
:g/pat/norm @q   matching lines   :cdo norm @q | update   quickfix matches
qQ … q        append to q      "qp … 0"qy$      edit q as text
qqq qq…@qq    recursive        :reg q           inspect
```
