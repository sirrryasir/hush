-- Hush: use the matugen-generated colorscheme and reload it when the theme changes.
return {
  { "LazyVim/LazyVim", opts = { colorscheme = "hush" } },
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts) opts.options.theme = "auto" end,
  },
  {
    "Mofiqul/vscode.nvim",
    enabled = false,
  },
  {
    name = "hush-theme-watcher",
    virtual = true,
    lazy = false,
    config = function()
      -- Watch the directory: hush replaces hush.lua atomically (new inode).
      local dir = vim.fn.stdpath("config") .. "/colors"
      local w = vim.uv.new_fs_event()
      if not w then return end
      _G.__hush_watcher = w -- keep a reference so it is not garbage-collected
      local pending = false
      w:start(dir, {}, function(err, filename)
        if err or filename ~= "hush.lua" or pending then return end
        pending = true
        vim.defer_fn(function()
          pending = false
          pcall(vim.cmd, "colorscheme hush")
        end, 100)
      end)
    end,
  },
}
