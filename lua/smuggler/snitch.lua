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
  local line_length = 80
  config.debug("Snitching result")
  local linenumber = response[4][1]
  config.debug("linenumber", linenumber)
  local output = response[4][2]
  config.debug("output", output)
  local namespace = nio.api.nvim_create_namespace("smuggler")
  local lines = {}
  for line in string.gmatch(output, "([^\n]+)") do
    if string.len(line) < line_length then
        line = line .. string.rep(" ", line_length - string.len(line))
    end
    lines[#lines+1] = {{line, "DiagnosticVirtualTextInfo"}}
  end
  config.debug("lines", lines)
  vim.api.nvim_buf_set_extmark(bufnbr, namespace, linenumber-1, 0, {
    virt_lines = lines,
    hl_eol = true,
    })
  config.debug("done", lines)
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
