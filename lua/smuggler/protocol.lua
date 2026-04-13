local M = {}

local log = require("smuggler.log")
local uv = require("coop.uv")
local StreamReader = require('coop.uv-utils').StreamReader
local StreamWriter = require('coop.uv-utils').StreamWriter
local mpack = require("smuggler.partial_mpack")

--- SemVer protocol version compatibility
---@type vim.Version
M.PROTOCOL_VERSION = vim.version.parse("0.5.x")

--- Format a vim version to something usable for the protocol
---@param ver vim.Version
---@return string
M.format_version = function(ver)
    return string.format("%d.%d.%d", ver.major, ver.minor, ver.patch)
end

--- Verify protocol version from the handshake
---@param payload [string, string] Server name and protocol version
M.verify_handshake = function(payload)
    local servername, serverprotocolversion = unpack(handshake)
    serverprotocolversion = vim.version.parse(serverprotocolversion)
    local success = true
    if servername ~= "REPLSmuggler" then
        log.warn("The server is not REPLSmuggler, but ", servername, ".")
    end
    if vim.version.gt(M.PROTOCOL_VERSION, serverprotocolversion) then
        log.fatal(
            "The server uses version: "
                .. M.format_version(serverprotocolversion)
                .. " and we expect: "
                .. M.format_version(M.PROTOCOL_VERSION)
                .. ". Consider upgrading REPLSmuggler.jl."
        )
        success = false
    elseif vim.version.lt(M.PROTOCOL_VERSION, serverprotocolversion) then
        log.fatal(
            "The server uses version: "
                .. M.format_version(serverprotocolversion)
                .. " and we expect: "
                .. M.format_version(M.PROTOCOL_VERSION)
                .. ". Consider upgrading nvim-smuggler."
        )
        success = false
    end
    log.trace("Protocol verification success status:", success)
    return success
end

--- A request to be send to REPLSmuggler.jl
---@field msgid number The message id.
---@field type "configure"|"eval"|"interrupt"|"exit"
---@field payload? table
M.Request = {}
M.Request.new = function(msgid, type, payload)
    if payload == nil then
        payload = {}
    end
    local request = {
        msgid = msgid,
        type = type,
        payload = payload
    }
    return setmetatable(request, {__index=M.Request})
end

--- Configure the session of a buffer
---@param buffer smuggler.Buffer
---@return number last_msgid # Last message id sent.
M.configure = function(buffer)
    log.trace("Configuring session for buffer", buffer.number)
    buffer.last_msgid = buffer.last_msgid + 1
    buffer.outgoing_queue.push(M.Request.new(buffer.last_msgid, "configure", { buffer.session_settings }))
    return buffer.last_msgid
end

--- Exit Session
---@param buffer smuggler.Buffer
---@return number last_msgid # Last message id sent.
M.exit = function(buffer)
    buffer.last_msgid = buffer.last_msgid + 1
    buffer.outgoing_queue.push(M.Request.new(buffer.last_msgid, "exit"))
    return buffer.last_msgid
end

--- Interrupt current evaluation
---@param buffer smuggler.Buffer
---@return number last_msgid # Last message id sent.
M.interrupt = function(buffer)
    buffer.last_msgid = buffer.last_msgid + 1
    buffer.outgoing_queue.push(M.Request.new(buffer.last_msgid, "interrupt"))
    return buffer.last_msgid
end

--- Send a code chunk
---@param buffer smuggler.Buffer
---@param chunk smuggler.Chunk
---@return number last_msgid # Last message id sent.
M.send = function(buffer, chunk)
    local filename = vim.api.nvim_buf_get_name(buffer.number)
    buffer:clear_diagnostics()
    buffer.last_msgid = buffer.last_msgid + 1
    buffer.outgoing_queue.push(M.Request.new(
        buffer.last_msgid, "eval", 
        {filename, chunk.linestart, buffer:get_text(chunk)}
    ))
    return buffer.last_msgid
end

---
--- Infinite loop that writes to the socket and transmits messages from the buffer.
---
---@async
---@param buffer smuggler.Buffer
M.outgoing_loop = function (buffer)
    local queue = buffer.outgoing_queue
    local stream = StreamWriter.new(buffer.socket)
    log.trace("Starting outgoing loop for buffer ", buffer.number)
    while true do
        local data = queue:pop()
        log.trace("Sending request ", vim.inspect(data))
        strea:write(vim.mpack.encode({ 0x00, data.msgid, data.type, data.payload}))
    end
end

---
--- Infinite loop that reads from the socket and transmits messages to the buffer.
--- Takes care of closing the buffer if the initial handshake goes wrong.
---
---@async
---@param buffer smuggler.Buffer
M.incoming_loop = function (buffer)
    local queue = buffer.incoming_queue
    local incoming_buffer = ""
    local stream = StreamReader.new(buffer.socket)
    log.trace("Starting incoming loop for buffer ", buffer.number)
    while true do
        local partial = stream:read()
        local success = true
        local result = nil
        local offset = 1
        while success do
            log.trace("Attempting to decode new message. Buffer is ", incoming_buffer)
            success, result, offset = mpack.decode_one(incoming_buffer)
            log.trace("Decoded ", offset, " bytes with success=", success)
            if success then
                log.trace("Deserialized answer.", result)
                if offset == #incoming_buffer then
                    incoming_buffer = ""
                else
                    incoming_buffer = string.sub(incoming_buffer, offset - #incoming_buffer)
                end
                local type = result[1]
                if type == 2 then -- Received a notification
                    local method = result[2]
                    if method == "handshake" then
                        local payload = result[3]
                        log.trace("Received handshake.", payload)
                        local handshakevalid = M.verify_handshake(payload)
                        if not handshakevalid then
                            buffer:terminate()
                            return
                        end
                    elseif method == "diagnostic" then
                        queue:push(result)
                    else
                        log.fatal("Unexpected notification call.", vim.inspect(result))
                        buffer:terminate()
                        return
                    end
                elseif type == 1 then -- Received a response message
                    queue:push(result)
                else -- Something went wrong.
                    log.fatal("Unexpected message received: ", vim.inspect(result))
                    buffer:terminate()
                    return
                end
                queue:push(result)
            elseif offset > 0 then
                log.error("Failed to decode chunk of length ", offset, " in buffer: ", incoming_buffer)
                buffer:terminate()
                return
            end
            log.trace("Buffer is now:", incoming_buffer)
        end
    end
end
--- Run the client for the given buffer by registering two tasks reading and
--- writing the socket.
---@param buffer smuggler.Buffer
function M.run_client(buffer)
    if buffer.path == nil then
        return
    end
    buffer.socket = uv.new_pipe(true)
    result, errmsg = buffer.socket:connect(buffer.path)
    if result ~= nil then
        log.fatal("Could not connect to socket", buffer.path)
        buffer:terminate()
        return
    end
    log.debug("Connected to socket", buffer.path)
    local incoming_task = coop.create(M.incoming_loop)
    local outgoing_task = coop.create(M.outgoing_loop)
    buffer:add_task(incoming_task)
    buffer:add_task(outgoing_task)
    incoming_task:resume(buffer)
    outgoing_task:resume(buffer)
    return
end

require("smuggler.buffers").on_new_buffer(M.run_client)

return M
