local M = {}

local uv = vim.loop
local nio = require("nio")
local config = require("smuggler.config")
local snitch = require("smuggler.snitch")
local buffers = require("smuggler.buffers")

function M.serialize_requests(bufnbr)
	local bufconfig = config.buf[bufnbr]
	local queue = bufconfig.outgoing_queue
	local handle = bufconfig.socket
	while not bufconfig.stopped_event.is_set() do
		local data = queue.get()
		if data.payload == nil then
			data.payload = {}
		end
		handle:write(vim.mpack.encode({ 0x00, data.msgid, data.type, data.payload }))
	end
end

function M.deserialize_answers(bufnbr)
	local bufconfig = config.buf[bufnbr]
	if bufconfig.stopped_event.is_set() then
		return
	end
	local handle = bufconfig.socket
	local queue = bufconfig.incoming_queue
	local buffer = ""
	handle:read_start(function(err, chunk)
		if err then
			error("Error while reading stream: " .. vim.inspect(err))
			bufconfig.stopped_event.set()
		elseif chunk then
			buffer = buffer .. chunk
			local parsed, res = pcall(vim.mpack.decode, buffer)
			if parsed then
				buffer = ""
				nio.run(function()
					queue.put(res)
				end)
			end
		end
	end)
	bufconfig.stopped_event.wait()
	handle:read_stop()
	nio.run(function()
		queue.put(nil)
	end)
end

function M.treat_incoming(bufnbr)
	local bufconfig = config.buf[bufnbr]
	local queue = bufconfig.incoming_queue
	while not bufconfig.stopped_event.is_set() do
		local value = queue.get()
		if value == nil then
			break
		elseif value[1] == 2 then -- Received a notification.
			if value[2] == "handshake" then
				-- TODO: perform version control here?
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
	local bufconfig = config.buf[bufnbr]
	bufconfig.socket = uv.new_pipe(true)
	bufconfig.socket:connect(bufconfig.path, function(err)
		if err ~= nil then
			error("Could not connect to socket. " .. vim.inspect(err))
			bufconfig.stopped_event.set()
		end
		bufconfig.session_connected_event.set()
	end)
	nio.run(function()
		bufconfig.session_initialized_event.wait()
		M.serialize_requests(bufnbr)
	end)
	nio.run(function()
		bufconfig.session_initialized_event.wait()
		M.configure_session(bufnbr)
	end)
	nio.run(function()
		bufconfig.session_connected_event.wait()
		M.deserialize_answers(bufnbr)
	end)
	nio.run(function()
		bufconfig.session_connected_event.wait()
		M.treat_incoming(bufnbr)
	end)
end

function M.send(code, firstline, filename)
	local bufnbr = vim.api.nvim_get_current_buf()
	if filename == nil then
		filename = vim.api.nvim_buf_get_name(bufnbr)
	end
	-- Clear previous diagnostics
	local namespace = nio.api.nvim_create_namespace("smuggler")
	vim.diagnostic.reset(namespace, bufnbr)
	config.buf[bufnbr].last_msgid = config.buf[bufnbr].last_msgid + 1
	nio.run(function()
		config.buf[bufnbr].outgoing_queue.put({
			msgid = config.buf[bufnbr].last_msgid,
			type = "eval",
			payload = { filename, firstline, code },
		})
	end)
	return config.buf[bufnbr].last_msgid
end

function M.interrupt()
	local bufnbr = vim.api.nvim_get_current_buf()
	config.buf[bufnbr].last_msgid = config.buf[bufnbr].last_msgid + 1
	nio.run(function()
		config.buf[bufnbr].outgoing_queue.put({ msgid = config.buf[bufnbr].last_msgid, type = "interrupt" })
	end)
	return config.buf[bufnbr].last_msgid
end

function M.exit()
	local bufnbr = vim.api.nvim_get_current_buf()
	config.buf[bufnbr].last_msgid = config.buf[bufnbr].last_msgid + 1
	nio.run(function()
		config.buf[bufnbr].outgoing_queue.put({ msgid = config.buf[bufnbr].last_msgid, type = "exit" })
	end)
	return config.buf[bufnbr].last_msgid
end

function M.configure_session(bufnbr, settings)
	if bufnbr == nil then
		bufnbr = vim.api.nvim_get_current_buf()
	end
	if settings == nil then
		settings = config.buf[bufnbr].session_settings
	else
		vim.tbl_extend("force", config.buf[bufnbr].session_settings, settings)
	end
	config.buf[bufnbr].last_msgid = config.buf[bufnbr].last_msgid + 1
	nio.run(function()
		config.buf[bufnbr].outgoing_queue.put({
			msgid = config.buf[bufnbr].last_msgid,
			type = "configure",
			payload = { settings },
		})
	end)
	return config.buf[bufnbr].last_msgid
end

return M
