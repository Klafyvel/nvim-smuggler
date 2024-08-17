local M = {}

local nio = require("nio")
local config = require("smuggler.config")
local uv = vim.loop

function M.socketsdir()
	if vim.fn.has("unix") or vim.fn.has("mac") then
		return "/run/user/" .. tostring(uv.getuid()) .. "/julia/replsmuggler/"
	elseif vim.fn.has("win32") then
		return "\\\\.\\pipe\\"
	else
		error("Unsupported platform.")
	end
end

function M.getavailablesockets()
	local directory = M.socketsdir()
	local res = {}
	for v in vim.fs.dir(directory) do
		res[#res + 1] = directory .. v
	end
	return res
end

function M.choosesocket()
	local sockets = M.getavailablesockets()
	local choice = nil
	vim.ui.select(sockets, {
		prompt = "Select a socket:",
	}, function(c)
		choice = c
	end)
	return choice
end

function M.buffer(bufnbr, force, settings)
	if bufnbr == nil then
		bufnbr = vim.api.nvim_get_current_buf()
	end
	local current_config = config.buf[bufnbr]
	if force == nil then
		force = false
	end
	if settings == nil then
		settings = { evalbyblocks = config.eval_by_blocks }
	end
	if current_config ~= nil then
		local closed = current_config.socket:is_closing()
		if not closed and not force then
			return current_config
		elseif not closed and force then
			current_config.socket:close()
		end
	end
	local socket_path = M.choosesocket()
	if socket_path == nil then
		return -1
	end
	local buffer = {
		number = bufnbr,
		socket = nil,
		path = socket_path,
		incoming_queue = nio.control.queue(),
		outgoing_queue = nio.control.queue(),
		session_connected_event = nio.control.event(),
		session_initialized_event = nio.control.event(),
		session_settings = settings,
		stopped_event = nio.control.event(),
		last_msgid = 0x00,
		evaluated_chunks = {}, -- msgid -> chunk
		results = {}, -- msgid -> list of results
        diagnostics = {}, -- msgid -> list of diagnostics
		update_result_display_event = nio.control.event(),
		update_chunk_display_event = nio.control.event(),
		update_diagnostic_display_event = nio.control.event(),
	}
    config.buf[bufnbr] = buffer
	local ui = require("smuggler.ui")
    local protocol = require("smuggler.protocol")
	nio.run(function()
		while true do
			config.debug("Display loop waiting.")
			nio.first({ buffer.update_result_display_event.wait, buffer.stopped_event.wait })
			config.debug("Display loop waited.")
			if buffer.stopped_event.is_set() then
				break
			end
			ui.show_evaluation_results(buffer.number)
			buffer.update_result_display_event.clear()
		end
	end)
	nio.run(function()
		while true do
			nio.first({ buffer.update_chunk_display_event.wait, buffer.stopped_event.wait })
			if buffer.stopped_event.is_set() then
				break
			end
			M.invalidate_changed_chunks(buffer)
			ui.update_chunk_highlights(buffer.number)
			buffer.update_chunk_display_event.clear()
		end
	end)
    nio.run(function()
        while true do
			nio.first({ buffer.update_diagnostic_display_event.wait, buffer.stopped_event.wait })
			if buffer.stopped_event.is_set() then
				break
			end
			ui.show_diagnostics(buffer.number)
			buffer.update_diagnostic_display_event.clear()
        end
    end)
	nio.run(function()
		protocol.runclient(buffer.number)
	end)
	ui.init_buffer(bufnbr)
	return buffer
end

function M.chunk(linestart, linestop, colstart, colstop, valid)
	if valid == nil then
		valid = true
	end
	return {
		linestart = linestart,
		linestop = linestop,
		colstart = colstart,
		colstop = colstop,
		valid = valid,
		extmark = nil,
	}
end

function M.intersect(chunkA, chunkB)
	local chunkB_is_sameline_and_starts_before_A = chunkB.linestart == chunkA.linestart
		and chunkB.colstart ~= nil
		and chunkA.colstart ~= nil
		and chunkB.colstart < chunkA.colstart
	if chunkB.linestart < chunkA.linestart or chunkB_is_sameline_and_starts_before_A then
		return M.intersect(chunkB, chunkA)
	elseif chunkA.linestart == chunkB.linestart then
		if chunkA.linestop > chunkA.linestart then
			return true
		elseif chunkA.colstart == nil or chunkB.colstart == nil or chunkA.colstop == nil then
			return true
		else
			return chunkA.colstop >= chunkB.colstart
		end
	elseif chunkA.linestart < chunkB.linestart and chunkB.linestart < chunkA.linestop then
		return true
	elseif chunkA.linestop == chunkB.linestart then
		if chunkA.colstop == nil or chunkB.colstart == nil then
			return true
		else
			return chunkB.colstart <= chunkA.colstop
		end
	else
		return false
	end
end

function M.get_chunk_position(buffer, chunk)
	if chunk.extmark == nil then
		return chunk
	else
		local namespace = vim.api.nvim_create_namespace("smuggler")
		local extmark = vim.api.nvim_buf_get_extmark_by_id(buffer.number, namespace, chunk.extmark, {})
		local linespan = chunk.linestop - chunk.linestart
		return {
			linestart = extmark[1],
			linestop = extmark[1] + linespan,
			colstart = extmark[2],
			colstop = chunk.colstop,
		}
	end
end

-- TODO: The [ marks seem to be uncorrectly placed for the very first edit to a buffer,
-- this triggers the invalidation of the block even though it shouldn't...
-- TODO: one-liner chunks seem to not get invalidated.
function M.invalidate_changed_chunks(buffer)
	config.debug("Invalidating!")
	local tmp = vim.api.nvim_buf_get_mark(buffer.number, "[")
	local rowstart = tmp[1]
	local colstart = tmp[2]
	tmp = vim.api.nvim_buf_get_mark(buffer.number, "]")
	local rowstop = tmp[1]
	local colstop = tmp[2]
	local changed_chunk = M.chunk(rowstart, rowstop, colstart, colstop)
	config.debug("changed_chunk=" .. vim.inspect(tmp))
	for msgid, chunk in pairs(buffer.evaluated_chunks) do
		config.debug(
			"Checking invalidation chunk=" .. vim.inspect(chunk),
			"changed_chunk=" .. vim.inspect(changed_chunk)
		)
		if M.intersect(M.get_chunk_position(buffer, chunk), changed_chunk) then
			chunk.valid = false
		end
	end
end

return M
