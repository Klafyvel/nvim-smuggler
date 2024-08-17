local M = {}

local config= require("smuggler.config")
local nio=require("nio")

function M.snitch_error(bufnbr, response)
  config.debug("Snitching error")
  local exception_text = response[3][2]
  config.debug("text is", exception_text)
  local stacktrace = response[3][3]
  config.debug("stacktrace is", stacktrace)
  local namespace = nio.api.nvim_create_namespace("smuggler")
  config.debug("namespace is", namespace)
  local diagnostics = vim.diagnostic.get(bufnbr, {namespace=namespace})
  for stackidx, stackrow in ipairs(stacktrace) do
    config.debug("Doing stacktrace element: ", stackrow)
    if vim.api.nvim_buf_get_name(bufnbr) ~= stackrow[1] then
      goto continue
    end
    diagnostics[#diagnostics+1] =  {
      lnum = stackrow[2]-1,
      col = 0,
      message = "[" .. stackidx .. "] " .. exception_text .. " in " .. stackrow[3],
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

function M.snitch_result(bufnbr, response)
  local msgid = response[2]
  local result = {
    linenumber = response[4][1],
    output = response[4][2],
    msgid = msgid,
    shown = false,
  }
  if config.buf[bufnbr].results[msgid] == nil then
    config.buf[bufnbr].results[msgid] = {}
  end
  local tbl = config.buf[bufnbr].results[msgid]
  tbl[#tbl+1] = result
  config.debug("Results are " .. vim.inspect(config.buf[bufnbr].results))
  config.buf[bufnbr].update_result_display_event.set()
  config.debug("Display loop notified.")
end

function M.snitch(bufnbr, response)
  config.debug("Snitching :D ", response)
  if response[3] == vim.NIL then
      return M.snitch_result(bufnbr, response)
  else
      return M.snitch_error(bufnbr, response)
  end
end

return M
