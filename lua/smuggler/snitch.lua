local M = {}

local config= require("smuggler.config")
local nio=require("nio")
local uv = vim.loop

function M.snitch_error(bufnbr, response)
  config.debug("Snitching error")
  local msgid = response[2]
  local exception_text = response[3][2]
  config.debug("text is", exception_text)
  local stacktrace = response[3][3]
  config.debug("stacktrace is", stacktrace)
  local buffer = config.buf[bufnbr]
  if #buffer.diagnostics >= 1 and buffer.diagnostics[1].msgid ~= msgid then
    buffer.diagnostics = {}
  end
  buffer.diagnostics[#buffer.diagnostics+1] = {
    text = exception_text,
    stacktrace = stacktrace,
    msgid = msgid,
    shown = false,
  }
  config.buf[bufnbr].update_diagnostic_display_event.set()
  config.debug("Display loop notified.")
end

function M.snitch_result(bufnbr, response)
  local msgid = response[2]
  if config.buf[bufnbr].results[msgid] == nil then
    config.buf[bufnbr].results[msgid] = {}
  end
  local tbl_results = config.buf[bufnbr].results[msgid]
  local mime = response[4][2]
  local output = response[4][3]
  local result = {
    linenumber = response[4][1],
    mime = mime,
    output = output,
    msgid = msgid,
    shown = false,
  }
  tbl_results[#tbl_results+1] = result
  config.buf[bufnbr].update_result_display_event.set()
end

function M.snitch(bufnbr, response)
  config.debug("Snitching :D ", response[1], response[2])
  if response[3] == vim.NIL then
      return M.snitch_result(bufnbr, response)
  else
      return M.snitch_error(bufnbr, response)
  end
end

return M
