-- Changed files in the repo (staged, unstaged, untracked), as absolute paths sorted by
-- path. Deleted files are skipped: there is nothing to open. Runs git only on keypress,
-- with a timeout so a stuck git (index.lock, slow disk) cannot freeze the UI.
local GIT_TIMEOUT_MS = 5000
local function changed_files()
  local dir = vim.fn.expand("%:p:h")
  if dir == "" or vim.fn.isdirectory(dir) == 0 then
    dir = vim.fn.getcwd()
  end
  local root = vim.system({ "git", "-C", dir, "rev-parse", "--show-toplevel" }, { text = true }):wait(GIT_TIMEOUT_MS)
  if root.code ~= 0 then
    return nil, "Not in a git repository"
  end
  root = vim.trim(root.stdout)
  local status_cmd = { "git", "-C", root, "status", "--porcelain=v1", "-z" }
  local status = vim.system(status_cmd, { text = true }):wait(GIT_TIMEOUT_MS)
  if status.code ~= 0 then
    return nil, "git status failed"
  end

  local files = {}
  local entries = vim.split(status.stdout, "\0", { plain = true, trimempty = true })
  local i = 1
  while i <= #entries do
    local code, path = entries[i]:sub(1, 2), entries[i]:sub(4)
    -- A rename/copy is followed by an extra entry holding the OLD path; skip it.
    if code:find("[RC]") then
      i = i + 1
    end
    if not code:find("D") then
      files[#files + 1] = vim.fs.joinpath(root, path)
    end
    i = i + 1
  end
  table.sort(files)
  return files
end

-- Jump to the first hunk (staged or unstaged) once gitsigns has attached. A freshly
-- opened file is not diffed yet, so poll until gitsigns has a hunk list for it (nil until
-- the first diff lands; `gitsigns_status_dict` appears earlier, so it is not a usable
-- signal). Give up after ~10 s (untracked files never attach) and stay on line 1.
--
-- The budget is generous on purpose: the diff takes ~0.5 s on its own (measured), and a
-- language server starting on the same file (vtsls in a big project) competes for the
-- main loop and stretches it well past that. Polling only runs after a keypress and stops
-- at the first hunk, so a long budget costs nothing.
local ATTACH_POLL_MS = 50
local ATTACH_TRIES = 200
-- Retries left once the unstaged diff is in but the jump found nothing (staged-only file).
local STAGED_TRIES = 20
local function goto_first_hunk(buf, tries)
  if not vim.api.nvim_buf_is_valid(buf) or buf ~= vim.api.nvim_get_current_buf() then
    return
  end
  -- Never yank the cursor away if you already started moving in the file.
  local cur = vim.api.nvim_win_get_cursor(0)
  if cur[1] ~= 1 or cur[2] ~= 0 then
    return
  end
  if require("gitsigns").get_hunks(buf) ~= nil then
    require("gitsigns").nav_hunk("first", { target = "all", navigation_message = false }, function()
      vim.schedule(function()
        local moved = vim.api.nvim_win_get_cursor(0)[1] ~= 1
        if moved then
          vim.cmd("normal! zz")
        elseif #(require("gitsigns").get_hunks(buf) or {}) == 0 and tries > 0 then
          -- Staged hunks are diffed after the unstaged ones, so a staged-only file can
          -- report no hunks on the first pass. Retry briefly. When unstaged hunks exist
          -- and the cursor still did not move, the first hunk IS line 1: done.
          vim.defer_fn(function()
            goto_first_hunk(buf, math.min(tries - 1, STAGED_TRIES))
          end, ATTACH_POLL_MS)
        end
      end)
    end)
  elseif tries > 0 then
    vim.defer_fn(function()
      goto_first_hunk(buf, tries - 1)
    end, ATTACH_POLL_MS)
  end
end

-- The window a changed file should open in. `:edit` from a sidebar (Trouble, the
-- explorer) or a float would load the file INTO that panel, so prefer the current
-- window only when it holds a normal file, then the previous window, then any file
-- window in the tab. With none (only the dashboard open) the current one is replaced.
local function file_window()
  local function is_file_win(win)
    return vim.api.nvim_win_get_config(win).relative == "" and vim.bo[vim.api.nvim_win_get_buf(win)].buftype == ""
  end
  local cur = vim.api.nvim_get_current_win()
  if is_file_win(cur) then
    return cur
  end
  local prev = vim.fn.win_getid(vim.fn.winnr("#"))
  if prev ~= 0 and is_file_win(prev) then
    return prev
  end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if is_file_win(win) then
      return win
    end
  end
  return cur
end

-- Open the next (step = 1) or previous (step = -1) changed file, wrapping around.
local function goto_changed_file(step)
  -- Resolve the repo from the file window, and only move focus once there is a file to go to.
  local win = file_window()
  local files, err
  vim.api.nvim_win_call(win, function()
    files, err = changed_files()
  end)
  if not files then
    vim.notify(err, vim.log.levels.WARN)
    return
  end
  if #files == 0 then
    vim.notify("No changed files", vim.log.levels.INFO)
    return
  end
  vim.api.nvim_set_current_win(win)

  -- Find where the current file sits in the sorted list; a file that is not changed
  -- still gets a position, so the step lands on its nearest changed neighbour.
  -- git reports PHYSICAL paths, so resolve symlinks before comparing: a repo opened
  -- through a symlinked path never matched and always restarted from the first file.
  local current = vim.fn.expand("%:p")
  current = current ~= "" and (vim.uv.fs_realpath(current) or vim.fs.normalize(current)) or ""
  local idx = step > 0 and 0 or #files + 1
  for n, file in ipairs(files) do
    if file == current then
      idx = n
      break
    elseif file > current and current ~= "" then
      idx = step > 0 and n - 1 or n
      break
    end
  end
  local target = files[(idx + step - 1) % #files + 1]

  -- `:edit` can refuse (swap-file prompt, unsaved buffer with 'nohidden'); report it
  -- instead of throwing a Lua traceback.
  local ok, edit_err = pcall(vim.cmd.edit, vim.fn.fnameescape(target))
  if not ok then
    vim.notify(tostring(edit_err), vim.log.levels.ERROR)
    return
  end
  local buf = vim.api.nvim_get_current_buf()
  -- Start from the top, not the last-edit position LazyVim restores on open, so the
  -- file never lands somewhere unrelated while gitsigns is still attaching.
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  vim.notify(
    ("Changed file %d/%d: %s"):format(vim.fn.index(files, target) + 1, #files, vim.fn.fnamemodify(target, ":~:."))
  )
  goto_first_hunk(buf, ATTACH_TRIES)
end

-- `n`/`N` step through hunks while a ghp preview is open (see preview_hunk below). gitsigns
-- keeps a single preview at a time, so one slot of state is enough, and one augroup that
-- is cleared on every release keeps the cleanup autocmds bounded to two.
local preview_keys = { pwin = nil, buf = nil }
local preview_group = vim.api.nvim_create_augroup("GitsignsPreviewKeys", { clear = true })

-- Give `n`/`N` back to the code buffer. Keyed on the popup window: a callback left over
-- from an older preview must not strip the keys a newer preview just set.
local function release_preview_keys(pwin)
  if preview_keys.pwin ~= pwin then
    return
  end
  vim.api.nvim_clear_autocmds({ group = preview_group })
  local buf = preview_keys.buf
  if buf and vim.api.nvim_buf_is_valid(buf) then
    pcall(vim.keymap.del, "n", "n", { buffer = buf })
    pcall(vim.keymap.del, "n", "N", { buffer = buf })
  end
  preview_keys.pwin, preview_keys.buf = nil, nil
end

return {
  {
    "lewis6991/gitsigns.nvim",
    event = "LazyFile", -- LazyVim event: fires on file open, deferred past first paint
    -- `gn`/`gN` are the primary keys; the <leader> twins are SECONDARY, kept until they
    -- are rebound. Normal mode ONLY: native `gn` (select next search match) matters in
    -- operator-pending and visual mode (`cgn` + `.`), and those modes are untouched.
    keys = {
      {
        "gn",
        function()
          goto_changed_file(1)
        end,
        desc = "Next Changed File",
      },
      {
        "gN",
        function()
          goto_changed_file(-1)
        end,
        desc = "Prev Changed File",
      },
      {
        "<leader>gn",
        function()
          goto_changed_file(1)
        end,
        desc = "Next Changed File (secondary)",
      },
      {
        "<leader>gN",
        function()
          goto_changed_file(-1)
        end,
        desc = "Prev Changed File (secondary)",
      },
    },
    opts = {
      -- Sign-column hunk markers only. Blame stays with the custom <leader>gw/gb
      -- floats in keymaps.lua; inline blame is opt-in via <leader>ghb.
      numhl = false,
      linehl = false,
      word_diff = false,
      current_line_blame = false, -- the only per-cursor-move option; off for perf
      current_line_blame_opts = { delay = 300, virt_text_pos = "eol" },
      attach_to_untracked = false,
      update_debounce = 100,
      -- Bordered popup for ghp so it reads as a distinct window.
      preview_config = {
        border = "rounded",
        style = "minimal",
        relative = "cursor",
        row = 1,
        col = 1,
      },
      on_attach = function(buffer)
        local gs = require("gitsigns")
        local function map(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = buffer, desc = desc })
        end

        -- Hunk navigation. NOTE: ]c/[c were previously treesitter class-start moves
        -- (freed in plugins/treesitter.lua); repurposed here for hunks. Inside a diff
        -- split they fall back to native ]c/[c (next/prev diff change) via normal!.
        local function next_hunk()
          if vim.wo.diff then
            vim.cmd.normal({ "]c", bang = true })
          else
            gs.nav_hunk("next")
          end
        end
        local function prev_hunk()
          if vim.wo.diff then
            vim.cmd.normal({ "[c", bang = true })
          else
            gs.nav_hunk("prev")
          end
        end
        map("n", "]c", next_hunk, "Next hunk")
        map("n", "[c", prev_hunk, "Prev hunk")
        -- ]]/[[ as a second pair. LazyVim binds them to Snacks.words only while words
        -- is enabled, and it is off in plugins/snacks.lua, so nothing else claims them.
        map("n", "]]", next_hunk, "Next hunk")
        map("n", "[[", prev_hunk, "Prev hunk")

        -- Hunk actions. `ghs`/`ghr`/`ghp` are the primary keys; the <leader>gh* twins are
        -- SECONDARY, kept for muscle memory until they are rebound to something else.
        -- Native `gh` (start Select mode) is unused, so claiming it only makes a bare `gh`
        -- wait out timeoutlen.
        --
        -- Visual mode passes the selected lines, so only those are staged/reset (partial
        -- hunk). `<cmd>Gitsigns stage_hunk<cr>` gets no range from visual mode and used to
        -- stage the WHOLE hunk under a one-line selection. This is gitsigns' README form.
        local function selected_lines()
          return { vim.fn.line("."), vim.fn.line("v") }
        end
        local function stage_selection()
          gs.stage_hunk(selected_lines())
        end
        local function reset_selection()
          gs.reset_hunk(selected_lines())
        end
        map("n", "ghs", gs.stage_hunk, "Stage hunk")
        map("n", "ghr", gs.reset_hunk, "Reset hunk")
        map("v", "ghs", stage_selection, "Stage selected lines")
        map("v", "ghr", reset_selection, "Reset selected lines")
        map("n", "<leader>ghs", gs.stage_hunk, "Stage hunk (secondary)")
        map("n", "<leader>ghr", gs.reset_hunk, "Reset hunk (secondary)")
        map("v", "<leader>ghs", stage_selection, "Stage selected lines (secondary)")
        map("v", "<leader>ghr", reset_selection, "Reset selected lines (secondary)")
        map("n", "<leader>ghS", gs.stage_buffer, "Stage buffer")
        map("n", "<leader>ghR", gs.reset_buffer, "Reset buffer")
        map("n", "<leader>ghu", gs.undo_stage_hunk, "Undo stage hunk")
        -- Bordered popup diff of the hunk. Opens UNFOCUSED; press <Tab> to focus
        -- it (keymaps.lua's <Tab> focuses any float) and navigate with Vim motions.
        -- Inside the popup (CodeCompanion-style):
        --   c1 → toggle stage/unstage the hunk   c2 → revert the hunk   q → close
        -- Diff colors are gitsigns' native theme defaults (readable, not washed out).
        local function preview_hunk()
          local src_win = vim.api.nvim_get_current_win()
          gs.preview_hunk()
          vim.schedule(function()
            local pwin
            for _, win in ipairs(vim.api.nvim_list_wins()) do
              if vim.w[win].gitsigns_preview ~= nil then
                pwin = win
                break
              end
            end
            if not pwin or not vim.api.nvim_win_is_valid(pwin) then
              return
            end
            local pbuf = vim.api.nvim_win_get_buf(pwin)

            -- Clamp width so tiny hunks aren't cramped and huge ones don't sprawl.
            local max_w = math.min(120, vim.o.columns - 8)
            local min_w = math.min(50, max_w)
            local w = math.max(min_w, math.min(max_w, vim.api.nvim_win_get_width(pwin)))
            vim.api.nvim_win_set_width(pwin, w)

            -- Wrap long code lines (with hanging indent) instead of truncating them
            -- at the edge — the global 'nowrap' the popup inherits would hide overflow.
            vim.wo[pwin].wrap = true
            vim.wo[pwin].breakindent = true
            vim.wo[pwin].linebreak = false -- code: break anywhere, not only at spaces

            -- Blank line under the "Hunk X of Y" title (virt line keeps the diff's
            -- highlight extmarks aligned). Recompute height to fit the wrapped lines.
            local pad_ns = vim.api.nvim_create_namespace("gitsigns_preview_pad")
            pcall(vim.api.nvim_buf_set_extmark, pbuf, pad_ns, 0, 0, {
              virt_lines = { { { "", "Normal" } } },
            })
            local rows = 1 -- the title pad virt line
            for _, line in ipairs(vim.api.nvim_buf_get_lines(pbuf, 0, -1, false)) do
              rows = rows + math.max(1, math.ceil(vim.fn.strdisplaywidth(line) / w))
            end
            local max_h = math.max(1, vim.o.lines - vim.o.cmdheight - 4)
            pcall(vim.api.nvim_win_set_height, pwin, math.min(rows, max_h))

            -- Run a Gitsigns action against the source hunk, then close the popup.
            local function act(cmd)
              return function()
                if vim.api.nvim_win_is_valid(src_win) then
                  vim.api.nvim_win_call(src_win, function()
                    vim.cmd(cmd)
                  end)
                end
                pcall(vim.api.nvim_win_close, pwin, true)
              end
            end
            local kopts = { buffer = pbuf, nowait = true, silent = true }
            vim.keymap.set(
              "n",
              "c1",
              act("Gitsigns stage_hunk"),
              vim.tbl_extend("force", kopts, { desc = "Toggle stage/unstage hunk" })
            )
            vim.keymap.set(
              "n",
              "c2",
              act("Gitsigns reset_hunk"),
              vim.tbl_extend("force", kopts, { desc = "Revert hunk" })
            )

            -- n/N step to the next/prev hunk and re-open this preview, from the code
            -- window or the focused popup. Buffer-local, so LazyVim's global search n/N
            -- return once these are removed (release_preview_keys).
            --
            -- The popup must be closed BEFORE navigating: gitsigns' preview_hunk focuses
            -- an already-open preview instead of opening a new one.
            local src_buf = vim.api.nvim_win_get_buf(src_win)
            local function step(direction, key)
              return function()
                -- Fallback only: the autocmds below release the keys as the popup
                -- closes. Should one be missed, the key still does its normal job.
                if not vim.api.nvim_win_is_valid(pwin) then
                  release_preview_keys(pwin)
                  vim.api.nvim_feedkeys((vim.v.count > 0 and vim.v.count or "") .. key, "m", false)
                  return
                end
                pcall(vim.api.nvim_win_close, pwin, true)
                if not vim.api.nvim_win_is_valid(src_win) then
                  return
                end
                vim.api.nvim_set_current_win(src_win)
                gs.nav_hunk(direction, nil, function()
                  vim.schedule(preview_hunk)
                end)
              end
            end
            -- Leave the code buffer alone if something ELSE owns a local n.
            local src_n = vim.fn.maparg("n", "n", false, true)
            local owns_src_keys = src_n.buffer ~= 1 or src_n.desc == "Next hunk preview"
            release_preview_keys(preview_keys.pwin)
            preview_keys.pwin, preview_keys.buf = pwin, owns_src_keys and src_buf or nil
            for _, buf in ipairs(owns_src_keys and { pbuf, src_buf } or { pbuf }) do
              local bopts = { buffer = buf, nowait = true, silent = true }
              vim.keymap.set(
                "n",
                "n",
                step("next", "n"),
                vim.tbl_extend("force", bopts, { desc = "Next hunk preview" })
              )
              vim.keymap.set(
                "n",
                "N",
                step("prev", "N"),
                vim.tbl_extend("force", bopts, { desc = "Prev hunk preview" })
              )
            end
            -- q and :close fire WinClosed.
            vim.api.nvim_create_autocmd("WinClosed", {
              group = preview_group,
              pattern = tostring(pwin),
              callback = function()
                release_preview_keys(pwin)
              end,
            })
            -- WARN: SILENT FAILURE — WinClosed alone leaks the keys. gitsigns closes
            -- the popup on cursor move from inside its own (non-nested) CursorMoved
            -- autocmd, and autocmds do not fire from inside another one, so WinClosed
            -- never runs on that path. Check on our own CursorMoved instead, scheduled
            -- so it runs after gitsigns' callback whatever the autocmd order. Exists
            -- only while a preview is open; the first real move closes it.
            if owns_src_keys then
              vim.api.nvim_create_autocmd("CursorMoved", {
                group = preview_group,
                buffer = src_buf,
                callback = function()
                  vim.schedule(function()
                    if not vim.api.nvim_win_is_valid(pwin) then
                      release_preview_keys(pwin)
                    end
                  end)
                end,
              })
            end
          end)
        end
        map("n", "ghp", preview_hunk, "Preview hunk (Tab focus · c1 stage · c2 revert)")
        map("n", "<leader>ghp", preview_hunk, "Preview hunk (secondary)")
        map("n", "<leader>ghb", gs.toggle_current_line_blame, "Toggle inline blame")
      end,
    },
  },

  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
    keys = {
      -- Toggle diff view (same key opens and closes)
      {
        "<leader>gd",
        function()
          local view = require("diffview.lib").get_current_view()
          if view then
            vim.cmd("DiffviewClose")
          else
            vim.cmd("DiffviewOpen")
          end
        end,
        desc = "Toggle Diff View",
      },
      -- Git log with per-commit diff for current file
      { "<leader>gl", "<cmd>DiffviewFileHistory %<cr>", desc = "File History (current file)" },
      -- Git log for entire repo
      { "<leader>gL", "<cmd>DiffviewFileHistory<cr>", desc = "File History (repo)" },
    },
    opts = {
      enhanced_diff_hl = true,
      view = {
        default = {
          layout = "diff2_horizontal",
        },
      },
      keymaps = {
        view = {
          { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close Diffview" } },
        },
        file_panel = {
          { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close Diffview" } },
        },
        file_history_panel = {
          { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close Diffview" } },
        },
      },
    },
  },
}
