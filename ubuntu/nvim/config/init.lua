vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0

-- Reuse the local Python provider when available; otherwise let Neovim detect it.
local python_host = vim.fn.expand("~/.local/bin/pynvim-python")
if vim.fn.executable(python_host) == 1 then
  vim.g.python3_host_prog = python_host
end

-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
