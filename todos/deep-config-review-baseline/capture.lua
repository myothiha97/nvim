local B = vim.env.BASE
vim.defer_fn(function()
  vim.cmd("edit " .. vim.env.SAMPLE)
  vim.defer_fn(function()
    -- highlights, minus lualine allocation-counter groups
    local hl = {}
    for _, name in ipairs(vim.fn.getcompletion("", "highlight")) do
      -- Group names are case-insensitive, and which spelling getcompletion returns
      -- depends on load order, so compare them lowercased.
      if not name:match("^lualine_[abcxyz]_%d+") then
        hl[#hl + 1] = name:lower() .. " " .. vim.inspect(vim.api.nvim_get_hl(0, { name = name }), { newline = "", indent = "" })
      end
    end
    table.sort(hl)
    vim.fn.writefile(hl, B .. "/highlights.txt")
    -- keymaps (global + buffer-local of a normal file buffer)
    local km = {}
    for _, mode in ipairs({ "n", "i", "v", "x", "s", "o", "t", "c" }) do
      for _, scope in ipairs({ "g", "b" }) do
        local maps = scope == "g" and vim.api.nvim_get_keymap(mode) or vim.api.nvim_buf_get_keymap(0, mode)
        for _, m in ipairs(maps) do
          -- <SNR> numbers are script load-order counters, not behaviour
          local rhs = (m.rhs or (m.callback and "<lua>") or ""):gsub("<SNR>%d+_", "<SNR>N_")
          km[#km + 1] = ("%s %s %s => %s | %s"):format(mode, scope, m.lhs, rhs, m.desc or "")
        end
      end
    end
    table.sort(km)
    vim.fn.writefile(km, B .. "/keymaps.txt")
    vim.fn.writefile({ "ok" }, vim.env.DONE)
    vim.cmd("qa!")
  end, 3000)
end, 300)
