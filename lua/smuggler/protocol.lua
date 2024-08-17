local M = {}

local uv = vim.loop
local nio = require("nio")
local config = require("smuggler.config")
local snitch = require("smuggler.snitch")
local buffers = require("smuggler.buffers")

function M.serialize_requests(bufnbr)
	config.debug("Started serializer.")
	local bufconfig = config.buf[bufnbr]
	local queue = bufconfig.outgoing_queue
	local handle = bufconfig.socket
	while not bufconfig.stopped_event.is_set() do
		config.debug("serializer waiting for data.")
		local data = queue.get()
		if data.payload == nil then
			data.payload = {}
		end
		config.debug("Sending data: ", data)
		handle:write(vim.mpack.encode({ 0x00, data.msgid, data.type, data.payload }))
	end
	config.debug("Stopped serializer.")
end

function M.deserialize_answers(bufnbr)
	local bufconfig = config.buf[bufnbr]
	if bufconfig.stopped_event.is_set() then
		return
	end
	local handle = bufconfig.socket
	local queue = bufconfig.incoming_queue
	config.debug("Started deserialize answer.")
	local buffer = ""
	handle:read_start(function(err, chunk)
		config.debug("Received err,chunk:", err, chunk)
		if err then
			error("Error while reading stream: " .. vim.inspect(err))
			bufconfig.stopped_event.set()
		elseif chunk then
			buffer = buffer .. chunk
			local parsed, res = pcall(vim.mpack.decode, buffer)
			if parsed then
				config.debug("Pushing to queue", buffer, res)
				buffer = ""
				nio.run(function()
					queue.put(res)
				end)
			end
		end
	end)
	bufconfig.stopped_event.wait()
	handle:read_stop()
	config.debug("Pushing nil.")
	nio.run(function()
		queue.put(nil)
	end)
	config.debug("Leaving deserialize_answers.")
end

function M.treat_incoming(bufnbr)
	local bufconfig = config.buf[bufnbr]
	local queue = bufconfig.incoming_queue
	config.debug("Starting treat_incoming")
	while not bufconfig.stopped_event.is_set() do
		config.debug("Waiting for queue")
		local value = queue.get()
		config.debug("Treating: ", value)
		if value == nil then
			break
		elseif value[1] == 2 then -- Received a notification.
			if value[2] == "handshake" then
				-- TODO: perform version control here?
				config.debug("Received Handshake. ", value)
				config.debug(bufconfig.session_initialized_event)
				bufconfig.session_initialized_event.set()
				config.debug(bufconfig.session_initialized_event.is_set())
				config.debug("Notified session initialized.")
			elseif value[2] == "diagnostic" then
				config.debug("Oh, my. A diagnostic. ")
				snitch.snitch(bufnbr, value)
			else
				error("Unexpected notification call." .. vim.inspect(value))
			end
		elseif value[1] == 1 then -- This is an answer.
			config.debug("Received Response")
			snitch.snitch(bufnbr, value)
		else -- Something unexpected happened.
			error("Unexpected value received." .. vim.inspect(value))
		end
	end
	config.debug("Leaving treat_incoming")
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
		config.debug("Serializer is waiting...")
		bufconfig.session_initialized_event.wait()
		config.debug("Serializer is done waiting!")
		M.serialize_requests(bufnbr)
	end)
	nio.run(function()
		config.debug("Configuration is waiting...")
		bufconfig.session_initialized_event.wait()
		config.debug("Configuration is done waiting!")
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
	config.debug("bufnbr=" .. vim.inspect(bufnbr), "buf=" .. vim.inspect(config.buf[bufnbr]))
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
