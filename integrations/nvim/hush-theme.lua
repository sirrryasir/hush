-- Hush: use the matugen-generated colorscheme and reload it when the theme changes.
--
-- lazy.nvim requires this file (lua/plugins/*.lua) once at startup, so the watcher
-- is started here at module level instead of in a plugin spec: a spec with no
-- source (`virtual = true` and no `dir`) is rejected by lazy.nvim as invalid.
do
  -- Watch the directory: hush replaces hush.lua atomically (new inode).
  local dir = vim.fn.stdpath("config") .. "/colors"
  local w = vim.uv and vim.uv.new_fs_event() or nil
  if w and not _G.__hush_watcher then
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
  end
end

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
}
