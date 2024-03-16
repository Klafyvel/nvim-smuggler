local M = {}

function M.hide()
  local namespace = vim.api.nvim_create_namespace("smuggler")
  vim.diagnostic.hide(namespace, vim.api.nvim_get_current_buf())
  vim.cmd("lcl")
end

function M.show()
  local namespace = vim.api.nvim_create_namespace("smuggler")
  vim.diagnostic.show(namespace, vim.api.nvim_get_current_buf())
end

function M.reset()
  local namespace = vim.api.nvim_create_namespace("smuggler")
  M.hide()
  vim.diagnostic.reset(namespace, vim.api.nvim_get_current_buf())
  vim.fn.setloclist(0, {})
end

return M
