local M = {}

local config = require("smuggler.config")
local nio = require("nio")
local log = require("smuggler.log")
local run = require("smuggler.run")
local uv = vim.loop

function M.snitch_error(bufnbr, response)
    log.debug("Snitching error")
    local msgid = response[2]
    local exception_text = response[3][2]
    log.debug("text is", exception_text)
    local stacktrace = response[3][3]
    log.debug("stacktrace is", stacktrace)
    local buffer = run.buffers[bufnbr]
    if #buffer.diagnostics >= 1 and buffer.diagnostics[1].msgid ~= msgid then
        buffer.diagnostics = {}
    end
    buffer.diagnostics[#buffer.diagnostics + 1] = {
        text = exception_text,
        stacktrace = stacktrace,
        msgid = msgid,
        shown = false,
    }
    run.buffers[bufnbr].update_diagnostic_display_event.set()
    log.debug("Display loop notified.")
end

function M.snitch_result(bufnbr, response)
    local msgid = response[2]
    if run.buffers[bufnbr].results[msgid] == nil then
        run.buffers[bufnbr].results[msgid] = {}
    end
    local tbl_results = run.buffers[bufnbr].results[msgid]
    local mime = response[4][2]
    local output = response[4][3]
    local result = {
        linenumber = response[4][1],
        mime = mime,
        output = output,
        msgid = msgid,
        shown = false,
    }
    tbl_results[#tbl_results + 1] = result
    run.buffers[bufnbr].update_result_display_event.set()
end

function M.snitch(bufnbr, response)
    log.debug("Snitching :D ", response[1], response[2])
    if response[3] == vim.NIL then
        return M.snitch_result(bufnbr, response)
    else
        return M.snitch_error(bufnbr, response)
    end
end

return M
