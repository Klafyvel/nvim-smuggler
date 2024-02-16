local M = {}

local config= require("config")
local nio=require("nio")

function M.snitch(bufnbr, response)
  config.debug("Snitching :D ", response)
  if response[3] == nil then
    return
  end
  local exception_text = response[3][2]
  config.debug("text is", exception_text)
  local stacktrace = response[3][3]
  config.debug("stacktrace is", stacktrace)
  local namespace = nio.api.nvim_create_namespace("smuggler")
  config.debug("namespace is", namespace)
  vim.diagnostic.reset(namespace, bufnbr)
  local diagnostics = {}
  for _, stackrow in ipairs(stacktrace) do
    config.debug("Doing stacktrace element: ", stackrow)
    if vim.api.nvim_buf_get_name(bufnbr) ~= stackrow[1] then
      goto continue
    end
    diagnostics[#diagnostics+1] =  {
      lnum = stackrow[2],
      col = 1,
      message = exception_text .. " in " .. stackrow[3],
      severity = vim.diagnostic.severity.ERROR,
      source = "Julia REPL",
    }
    ::continue::
  end
  config.debug("Created the diagnostic list", diagnostics)
  vim.diagnostic.set(namespace, bufnbr, diagnostics, {})
  vim.diagnostic.setloclist({
    namespace=namespace,
    title="REPL error: " .. exception_text,
  })
  vim.diagnostic.show(namespace, bufnbr)
end

return M
