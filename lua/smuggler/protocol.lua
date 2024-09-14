local M = {}

-- SemVer protocol version compatibility
M.PROTOCOL_VERSION = vim.version.parse("0.4.x")

local uv = vim.loop
local nio = require("nio")
local config = require("smuggler.config")
local snitch = require("smuggler.snitch")
local buffers = require("smuggler.buffers")
local run = require("smuggler.run")
local log = require("smuggler.log")
local mpack = require("smuggler.partial_mpack")

function M.serialize_requests(bufnbr)
    local bufconfig = run.buffers[bufnbr]
    local queue = bufconfig.outgoing_queue
    local handle = bufconfig.socket
    while not bufconfig.stopped_event.is_set() do
        local data = queue.get()
        if data.payload == nil then
            data.payload = {}
        end
        log.trace("Serializing request", data)
        handle:write(vim.mpack.encode({ 0x00, data.msgid, data.type, data.payload }))
    end
end

function M.deserialize_answers(bufnbr)
    local bufconfig = run.buffers[bufnbr]
    if bufconfig.stopped_event.is_set() then
        return
    end
    local handle = bufconfig.socket
    local queue = bufconfig.incoming_queue
    local buffer = ""
    log.trace("Starting deserialization thread.")
    handle:read_start(function(err, chunk)
        if err then
            log.fatal("Error while reading stream: ", err)
            error("Error while reading stream: " .. vim.inspect(err))
            bufconfig.stopped_event.set()
        elseif chunk then
            buffer = buffer .. chunk
            local success = true
            local result = nil
            local offset = 1
            while success do
                log.trace("Attempting to decode new buffer=", buffer)
                success, result, offset = mpack.decode_one(buffer)
                log.trace("Decoded ", offset, " bytes with success=", success)
                if success then
                    log.trace("Deserialized answer.", result)
                    if offset == #buffer then
                        buffer = ""
                    else
                        buffer = string.sub(buffer, offset - #buffer)
                    end
                    nio.run(function()
                        queue.put(result)
                    end)
                elseif offset > 0 then
                    error("Failed to decode message.")
                    log.error("Failed to decode chunk of length ", offset, " in buffer: ", buffer)
                    if offset == #buffer then
                        buffer = ""
                    else
                        buffer = string.sub(buffer, offset - #buffer)
                    end
                end
                log.trace("Buffer is now:", buffer)
            end
        end
    end)
    bufconfig.stopped_event.wait()
    handle:read_stop()
    nio.run(function()
        queue.put(nil)
    end)
end

function format_version(ver)
    return string.format("%d.%d.%d", ver.major, ver.minor, ver.patch)
end

function M.verify_protocol(handshake)
    local servername, serverprotocolversion = unpack(handshake)
    serverprotocolversion = vim.version.parse(serverprotocolversion)
    local success = true
    if servername ~= "REPLSmuggler" then
        log.warn("The server is not REPLSmuggler, but ", servername, ".")
    end
    if vim.version.gt(M.PROTOCOL_VERSION, serverprotocolversion) then
        log.fatal(
            "The server uses version: "
                .. format_version(serverprotocolversion)
                .. " and we expect: "
                .. format_version(M.PROTOCOL_VERSION)
                .. ". Consider upgrading REPLSmuggler.jl."
        )
        success = false
    elseif vim.version.lt(M.PROTOCOL_VERSION, serverprotocolversion) then
        log.fatal(
            "The server uses version: "
                .. format_version(serverprotocolversion)
                .. " and we expect: "
                .. format_version(M.PROTOCOL_VERSION)
                .. ". Consider upgrading nvim-smuggler."
        )
        success = false
    end
    return success
end

function M.treat_incoming(bufnbr)
    local bufconfig = run.buffers[bufnbr]
    local queue = bufconfig.incoming_queue
    while not bufconfig.stopped_event.is_set() do
        log.trace("Waiting incoming.")
        local value = queue.get()
        log.trace("Received incoming:", value)
        if value == nil then
            break
        elseif value[1] == 2 then -- Received a notification.
            if value[2] == "handshake" then
                log.trace("Received handshake.", value[3])
                local handshakevalid = M.verify_protocol(value[3])
                if not handshakevalid then
                    bufconfig.stopped_event.set()
                end
                bufconfig.session_initialized_event.set()
            elseif value[2] == "diagnostic" then
                snitch.snitch(bufnbr, value)
            else
                error("Unexpected notification call." .. vim.inspect(value))
            end
        elseif value[1] == 1 then -- This is an answer.
            snitch.snitch(bufnbr, value)
        else -- Something unexpected happened.
            error("Unexpected value received." .. vim.inspect(value))
        end
    end
end

function M.runclient(bufnbr)
    local bufconfig = run.buffers[bufnbr]
    if bufconfig.path == nil then
        return
    end
    bufconfig.socket = uv.new_pipe(true)
    log.debug("Connecting socket.")
    bufconfig.socket:connect(bufconfig.path, function(err)
        if err ~= nil then
            log.fatal("Connection error: ", err)
            error("Could not connect to socket. " .. vim.inspect(err))
            log.fatal("Setting stop buffer event.")
            bufconfig.stopped_event.set()
        end
        log.trace("Setting connected buffer event.")
        bufconfig.session_connected_event.set()
    end)
    nio.run(function()
        log.trace("Waiting for session initialization before serialization starts.")
        bufconfig.session_initialized_event.wait()
        M.serialize_requests(bufnbr)
    end)
    nio.run(function()
        log.trace("Waiting for session initialization before session configuration.")
        bufconfig.session_initialized_event.wait()
        M.configure_session(bufnbr)
    end)
    nio.run(function()
        log.trace("Waiting for session connection before deserialization starts.")
        bufconfig.session_connected_event.wait()
        M.deserialize_answers(bufnbr)
    end)
    nio.run(function()
        log.trace("Waiting for session connection before requests treatement starts.")
        bufconfig.session_connected_event.wait()
        M.treat_incoming(bufnbr)
    end)
end

function M.send(bufnbr, code, firstline, filename)
    if filename == nil then
        filename = vim.api.nvim_buf_get_name(bufnbr)
    end
    -- Clear previous diagnostics
    local namespace = nio.api.nvim_create_namespace("smuggler")
    vim.diagnostic.reset(namespace, bufnbr)
    run.buffers[bufnbr].last_msgid = run.buffers[bufnbr].last_msgid + 1
    nio.run(function()
        run.buffers[bufnbr].outgoing_queue.put({
            msgid = run.buffers[bufnbr].last_msgid,
            type = "eval",
            payload = { filename, firstline, code },
        })
    end)
    return run.buffers[bufnbr].last_msgid
end

function M.interrupt(bufnbr)
    run.buffers[bufnbr].last_msgid = run.buffers[bufnbr].last_msgid + 1
    nio.run(function()
        run.buffers[bufnbr].outgoing_queue.put({ msgid = run.buffers[bufnbr].last_msgid, type = "interrupt" })
    end)
    return run.buffers[bufnbr].last_msgid
end

function M.exit(bufnbr)
    run.buffers[bufnbr].last_msgid = run.buffers[bufnbr].last_msgid + 1
    nio.run(function()
        run.buffers[bufnbr].outgoing_queue.put({ msgid = run.buffers[bufnbr].last_msgid, type = "exit" })
    end)
    return run.buffers[bufnbr].last_msgid
end

function M.configure_session(bufnbr, settings)
    if bufnbr == nil then
        bufnbr = vim.api.nvim_get_current_buf()
    end
    if settings == nil then
        settings = run.buffers[bufnbr].session_settings
    else
        vim.tbl_extend("force", run.buffers[bufnbr].session_settings, settings)
    end
    run.buffers[bufnbr].last_msgid = run.buffers[bufnbr].last_msgid + 1
    nio.run(function()
        run.buffers[bufnbr].outgoing_queue.put({
            msgid = run.buffers[bufnbr].last_msgid,
            type = "configure",
            payload = { settings },
        })
    end)
    return run.buffers[bufnbr].last_msgid
end

return M
