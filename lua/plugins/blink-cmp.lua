-- Visual toggle for the blink.cmp menu, scoped to the current buffer.
--
-- Mechanism: blink's OWN native per-buffer gate. blink/cmp/config/init.lua
-- M.enabled() checks `if vim.b.completion == false then return false end`
-- early on every trigger, independent of (and before) the user `enabled`
-- function. So flipping vim.b.completion off just stops the menu from drawing
-- -- it does NOT touch blink's enabled logic, sources, scoring, LSP, or
-- treesitter. Toggle ON = identical to default behavior in every way.
local function toggle_blink()
  if vim.b.completion == false then
    vim.b.completion = true
  else
    vim.b.completion = false
    -- enabled() gates *future* triggers; hide any menu that's open right now.
    local ok, blink = pcall(require, "blink.cmp")
    if ok then
      blink.hide()
    end
  end
  local on = vim.b.completion ~= false
  vim.notify(
    "Blink Completion: " .. (on and "Enabled" or "Disabled"),
    on and vim.log.levels.INFO or vim.log.levels.WARN,
    { title = "blink.cmp" }
  )
end

return {
  {
    "saghen/blink.cmp",
    keys = {
      { "<leader>ab", toggle_blink, desc = "Blink: Toggle Completion Menu" },
      { "<C-b>", toggle_blink, mode = "i", desc = "Blink: Toggle Completion Menu" },
    },
    opts = {
      keymap = {
        preset = "none",
        ["<C-n>"] = { "select_next", "fallback" },
        ["<C-p>"] = { "select_prev", "fallback" },
        ["<C-l>"] = { "select_and_accept", "fallback" },
        ["<CR>"] = { "select_and_accept", "fallback" },
        ["<Tab>"] = { "fallback" },
        ["<S-Tab>"] = { "fallback" },
        ["<C-i>"] = { "show", "hide" },
        -- <Esc>: cancel menu first (second Esc exits insert via copilot's handler)
        ["<ESC>"] = { "cancel", "fallback" },
        -- <C-f> toggles the docs window (auto_show is off). Insert-mode key, no
        -- Ghostty binding needed; snacks only uses <C-f> inside pickers.
        ["<C-f>"] = { "show_documentation", "hide_documentation", "fallback" },
      },
      -- cd cd
      snippets = {
        score_offset = 0,
      },
      fuzzy = {
        sorts = { "exact", "score", "sort_text" },
      },
      completion = {
        accept = {
          auto_brackets = { enabled = false },
        },
        ghost_text = { enabled = false },
        list = {
          max_items = 25,
          selection = {
            preselect = true,
            auto_insert = false,
          },
        },
        trigger = {
          show_on_accept_on_trigger_character = false,
        },
        documentation = {
          auto_show = false, -- if u want the docs to show up automatically, set this to true
          auto_show_delay_ms = 150,
          window = {
            border = "rounded",
            max_width = 80,
            max_height = 30,
          },
        },
        menu = {
          border = "rounded",
        },
      },
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
        transform_items = function(_, items)
          return items
        end,
        providers = {
          lsp = {
            score_offset = 100,
            min_keyword_length = 0,
            -- Filter bracket-only completions from emmet
            transform_items = function(_, items)
              return vim.tbl_filter(function(item)
                return not (item.label or ""):match("^[%{%}%(%)%[%]<>]+$")
              end, items)
            end,
          },
          snippets = {
            score_offset = 100,
            async = true,
            min_keyword_length = 1,
            should_show_items = true,
          },
          buffer = {
            min_keyword_length = 3,
            max_items = 10,
          },
        },
      },

      -- Cmdline completion: keep blink's defaults, but go silent while typing a
      -- `:CodeCompanion ...` prompt. That text is free-form input for the AI, not
      -- a command/argument, so the adapter=/slash-command suggestions are just
      -- noise. Command-name completion still works while typing `:CodeC...` --
      -- suppression only kicks in once the full command name is on the line.
      cmdline = {
        sources = function()
          if vim.fn.getcmdline():find("CodeCompanion") then
            return {}
          end
          local type = vim.fn.getcmdtype()
          if type == "/" or type == "?" then
            return { "buffer" }
          end
          if type == ":" or type == "@" then
            return { "cmdline" }
          end
          return {}
        end,
      },

      enabled = function()
        local ft = vim.bo.filetype
        return not (ft:match("^Avante") or ft == "AvanteInput" or vim.bo.buftype == "prompt")
      end,
    },
  },
}
