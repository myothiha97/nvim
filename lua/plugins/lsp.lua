-- previously we used, the 300 value for performance case
-- but 300 feels a bit slow and so i re-adjusted to 200 for more snappier feeling at - 09 June 2026
local debounce_text_change = 200
local lsp_hover_popup_opts = {
  border = "rounded",
  max_width = 65,
  max_height = 20,
}

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      inlay_hints = {
        enabled = false,
      },
      -- Performance: Don't update diagnostics in insert mode
      diagnostics = {
        update_in_insert = false,
        severity_sort = true,
        -- Hide end-of-line diagnostic text; keep the sign-column color + underline.
        -- Read the full message via the hover/line-diagnostic float (<leader>k).
        virtual_text = false,
      },
      servers = {
        -- Free <C-k> in insert mode for our Copilot toggle.
        -- LazyVim binds it to vim.lsp.buf.signature_help via servers["*"].keys
        -- (see lazy/LazyVim/lua/lazyvim/plugins/lsp/init.lua:87).
        -- opts_extend = { "servers.*.keys" } appends this to LazyVim's defaults,
        -- and Keys.resolve drops entries whose rhs is false.
        ["*"] = {
          keys = {
            { "<c-k>", false, mode = "i" },
            { "<leader>cc", false, mode = { "n", "x" } },
            { "<leader>cC", false, mode = "n" },
            -- Override LazyVim's `K → vim.lsp.buf.hover()` (no opts) so popup
            -- size/style is consistent across gopls / pyright / vtsls / etc.
            {
              "<leader>k",
              function()
                vim.lsp.buf.hover(lsp_hover_popup_opts)
              end,
              desc = "Hover",
            },
          },
        },
        -- Disable nvim-lspconfig's stock copilot config so mason-lspconfig's automatic_enable
        -- skips it. Otherwise it auto-starts the binary copilot-language-server and fights
        -- with the zbirenbaum/copilot.lua plugin for the "copilot" client slot — the plugin's
        -- per-buffer state never initializes and ghost text never renders.
        copilot = { enabled = false },
        -- nvim-lspconfig otherwise requires postgres-language-server.jsonc before
        -- starting. Attach to SQL projects for syntax support, while still
        -- preferring that file when a project provides database settings.
        postgres_lsp = {
          root_dir = function(bufnr, on_dir)
            local fname = vim.api.nvim_buf_get_name(bufnr)
            local root = vim.fs.root(fname, { "postgres-language-server.jsonc" })
            if not root then
              local git = vim.fs.root(fname, { ".git" })
              if git and git ~= vim.uv.os_homedir() then
                root = git
              end
            end
            on_dir(root or vim.fs.dirname(fname))
          end,
        },
        emmet_ls = {
          -- Only HTML/CSS - TSX/JSX use custom snippets for tag completion
          filetypes = {
            "html",
            -- "css",
            -- "sass",
            -- "scss",
            -- "less",
          },
        },
        -- ESLint disabled - TypeScript alone is sufficient for current project
        -- Re-enable by setting enabled = true when needed
        eslint = {
          enabled = false,
          settings = {
            run = "onSave",
            workingDirectory = { mode = "location" },
            rulesCustomizations = {
              { rule = "*", severity = "warn" },
            },
          },
        },
        lua_ls = {
          settings = {
            Lua = {
              codeLens = {
                enable = false,
              },
            },
          },
        },
        -- Python (basedpyright).
        --
        -- root_dir: $HOME is a git repo (~/.git), so the stock .git-based root
        -- makes a loose .py file treat ALL of $HOME as its workspace, and
        -- basedpyright tries to enumerate every file under it (">10s enumeration
        -- of workspace source files"). Root on Python project markers ONLY; when
        -- none are found, fall back to the file's own directory instead of
        -- climbing to ~/.git. Real projects (with pyproject.toml etc.) still root
        -- correctly and get full-project checking.
        --
        -- diagnosticMode: only type-check open files, never the whole tree —
        -- matches the perf-first stance and is a second line of defense.
        basedpyright = {
          root_dir = function(bufnr, on_dir)
            local markers =
              { "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", "Pipfile", "pyrightconfig.json" }
            local fname = vim.api.nvim_buf_get_name(bufnr)
            local root = vim.fs.root(fname, markers)
            if not root then
              -- Real repos with no Python marker: fall back to the .git root so
              -- cross-package imports resolve — but NEVER $HOME (~/.git would make
              -- all of $HOME the workspace and trigger the 10s+ enumeration).
              local git = vim.fs.root(fname, { ".git" })
              if git and git ~= vim.uv.os_homedir() then
                root = git
              end
            end
            on_dir(root or vim.fs.dirname(fname))
          end,
          settings = {
            basedpyright = {
              analysis = {
                diagnosticMode = "openFilesOnly",
              },
            },
          },
        },
        ruff = {
          root_dir = function(bufnr, on_dir)
            local fname = vim.api.nvim_buf_get_name(bufnr)
            local root = vim.fs.root(fname, { "pyproject.toml", "ruff.toml", ".ruff.toml" })
            if not root then
              local git = vim.fs.root(fname, { ".git" })
              if git and git ~= vim.uv.os_homedir() then
                root = git
              end
            end
            on_dir(root or vim.fs.dirname(fname))
          end,
        },
        -- Go (gopls). Same $HOME/.git footgun as basedpyright: a loose .go file
        -- with no go.mod would climb to ~/.git and treat all of $HOME as the
        -- module root (slow enumeration). Root on Go module markers only; fall
        -- back to the file's own directory otherwise. Real Go projects always
        -- have go.mod/go.work, so they root correctly with full module features.
        gopls = {
          root_dir = function(bufnr, on_dir)
            local fname = vim.api.nvim_buf_get_name(bufnr)
            on_dir(vim.fs.root(fname, { "go.work", "go.mod" }) or vim.fs.dirname(fname))
          end,
        },
        -- TypeScript LSP optimization (React/TSX focused). Genuinely
        -- TS-specific tuning only; shared behavior (debounce, keys) is global.
        vtsls = {
          settings = {
            typescript = {
              suggest = {
                completeFunctionCalls = false,
              },
              preferences = {
                -- Don't scan package.json for auto-imports (big perf win for large React projects)
                includePackageJsonAutoImports = "off",
              },
              tsserver = {
                -- Balanced tsserver heap cap: more React/TS headroom than the
                -- ~3GB default without allowing the very large pauses possible
                -- with an 8192MB heap. Raise only if tsserver OOMs in a large repo.
                maxTsServerMemory = 3072,
                -- Don't watch node_modules for changes
                watchOptions = {
                  watchFile = "useFsEvents",
                  watchDirectory = "useFsEvents",
                  fallbackPolling = "dynamicPriority",
                  synchronousWatchDirectory = true,
                  excludeDirectories = { "**/node_modules", "**/.git" },
                },
              },
            },
            javascript = {
              suggest = {
                completeFunctionCalls = false,
              },
              preferences = {
                includePackageJsonAutoImports = "off",
              },
            },
          },
        },
      },
      -- Override LazyVim's extras/lang/go.lua workaround. It reads
      -- client.config.capabilities.textDocument.semanticTokens, which can be nil
      -- under blink.cmp, and we disable semanticTokensProvider globally below anyway.
      setup = {
        gopls = function() end,
      },
    },
    init = function()
      -- Shared LSP defaults for EVERY language server (native 0.12 wildcard
      -- config). Cross-cutting behavior lives here once; the per-server tables
      -- above hold only what's genuinely server-specific (filetypes, settings).
      -- This didChange debounce now keeps typing snappy on every language —
      -- gopls, basedpyright, rust_analyzer, vtsls, lua_ls — not just a hand-
      -- picked few. Per-language LSP/linter/DAP selection lives in the LazyVim
      -- lang extras, not here.
      vim.lsp.config("*", {
        flags = { debounce_text_changes = debounce_text_change },
      })

      -- Neovim 0.12 enables vim.lsp.document_color by default. Its provider is created
      -- from client.lua's post-attach hook, which only checks the capability's enable
      -- marker -- it never routes through document_color.enable(), so stubbing that
      -- function out did nothing. Calling the real enable(false) here (before any client
      -- starts) clears the global marker, so no provider is ever created.
      --
      -- This also avoids an upstream 0.12.2 crash: the provider keeps per-client state
      -- and re-requests documentColor on every buffer change, but a client that exits
      -- right after attaching leaves a stale id behind, so document_color.lua:225
      -- (`assert(get_client_by_id(id))`) throws on every keystroke.
      if vim.lsp.document_color then
        vim.lsp.document_color.enable(false)
      end

      -- Disable semantic tokens globally: stops LSP from computing/sending token payloads.
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if client then
            client.server_capabilities.semanticTokensProvider = nil
          end
        end,
      })

      -- Restart LSP to refresh type diagnostics after external file changes (e.g., Grug-far)
      vim.keymap.set("n", "<leader>cL", function()
        local clients = vim.lsp.get_clients()
        for _, client in ipairs(clients) do
          client.stop()
        end
        vim.notify("LSP stopped, restarting...", vim.log.levels.INFO)
        vim.defer_fn(function()
          vim.cmd("edit!")
          vim.notify("LSP restarted", vim.log.levels.INFO)
        end, 100)
      end, { noremap = true, silent = false, desc = "Restart LSP" })

      -- Custom gd to filter node_modules (only when LSP is attached)
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          -- vim.schedule ensures this runs AFTER LazyVim's LspAttach keymaps
          vim.schedule(function()
            vim.keymap.set("n", "gd", function()
              vim.lsp.buf.definition({
                on_list = function(options)
                  local items = options.items
                  if #items > 1 then
                    local filtered = {}
                    -- Filter 1: Remove node_modules
                    for _, item in ipairs(items) do
                      if not string.match(item.filename or "", "node_modules") then
                        table.insert(filtered, item)
                      end
                    end

                    -- Filter 2: If multiple items remain, remove the current file (to skip imports)
                    if #filtered > 1 then
                      local current_file = vim.api.nvim_buf_get_name(0)
                      local external_defs = {}
                      for _, item in ipairs(filtered) do
                        if item.filename ~= current_file then
                          table.insert(external_defs, item)
                        end
                      end

                      -- Only apply this filter if we found an external definition
                      -- (Prevents breaking gd if the definition IS in the current file)
                      if #external_defs > 0 then
                        filtered = external_defs
                      end
                    end

                    if #filtered > 0 then
                      items = filtered
                    end
                  end

                  if #items == 1 then
                    local item = items[1]
                    vim.cmd("edit " .. vim.fn.fnameescape(item.filename))
                    vim.schedule(function()
                      local lnum = item.lnum or 1
                      local col = (item.col or 1) - 1
                      local line_count = vim.api.nvim_buf_line_count(0)
                      if lnum > line_count then
                        lnum = line_count
                      end
                      vim.api.nvim_win_set_cursor(0, { lnum, math.max(0, col) })
                    end)
                  else
                    vim.fn.setqflist({}, " ", { title = "LSP Definitions", items = items })
                    vim.cmd("copen")
                  end
                end,
              })
            end, { buffer = args.buf, desc = "Goto Definition (Skip node_modules & imports)" })
          end)
        end,
      })
    end,
  },
}
