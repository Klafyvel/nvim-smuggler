local M = {}

local nio = require("nio")
local config = require("smuggler.config")
local uv = vim.loop
local run = require("smuggler.run")
local log = require("smuggler.log")

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
	local current_config = run.buffers[bufnbr]
	if force == nil then
		force = false
	end
    local default_settings =  { 
        evalbyblocks = config.buffers.eval_by_blocks, 
        showdir=vim.fs.joinpath(config.buffers.showdir, bufnbr),
        iocontext=config.buffers.iocontext,
        enableimages=config.ui.display_images,
    }
	if settings == nil then
        settings = {}
	end
    settings = vim.tbl_extend("keep", settings, default_settings)
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
    local bufname = vim.fn.bufname(bufnbr)
    local splitted_name = vim.split(vim.fs.basename(bufname), ".")[1]
    local images_path = vim.fs.joinpath(vim.fs.dirname(bufname), splitted_name .. "_images")
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
        diagnostics = {}, -- list of diagnostics from last msgid
		update_result_display_event = nio.control.event(),
		update_chunk_display_event = nio.control.event(),
		update_diagnostic_display_event = nio.control.event(),
        images_path = images_path, 
        chunks_shown = true,
        results_shown = true,
        diagnostics_shown = true,
	}
    run.buffers[bufnbr] = buffer
	local ui = require("smuggler.ui")
    local protocol = require("smuggler.protocol")
	nio.run(function()
		while true do
			log.debug("Display loop waiting.")
			nio.first({ buffer.update_result_display_event.wait, buffer.stopped_event.wait })
			log.debug("Display loop waited.")
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

function M.find_intersected_chunks(buffer, chunk)
	local namespace = vim.api.nvim_create_namespace("smuggler")
    local intersected_extmarks = vim.iter(vim.api.nvim_buf_get_extmarks(
        buffer.number, namespace, {chunk.linestart-1, chunk.colstart}, {chunk.linestop-1, chunk.colstop}, {overlap=true}))
    intersected_extmarks:map(function(item) 
        return item[1] 
    end)
    intersected_extmarks = intersected_extmarks:fold({}, function(t, v) 
        if v ~= nil then
            t[v] = true 
        end
        return t
    end)
    return vim.iter(pairs(buffer.evaluated_chunks)):filter(function(i,chunk)
        return intersected_extmarks[chunk.extmark] ~= nil
    end)
end

function M.delete_intersected_chunks(buffer, new_chunk)
	local namespace = nio.api.nvim_create_namespace("smuggler")
	for msgid, chunk in M.find_intersected_chunks(buffer, new_chunk) do
        if buffer.results[msgid] ~= nil then
            for _,result in ipairs(buffer.results[msgid]) do 
                if result.mark_id ~= nil then 
                    vim.api.nvim_buf_del_extmark(buffer.number, namespace, result.mark_id)
                end
            end
        end
        vim.api.nvim_buf_del_extmark(buffer.number, namespace, chunk.extmark)
        if buffer.results[msgid] ~= nil then
            for _,result in pairs(buffer.results[msgid]) do 
                if result.images ~= nil then
                    for _,img in pairs(result.images) do 
                        img:clear()
                    end
                end
            end
            buffer.results[msgid] = nil
        end
        buffer.evaluated_chunks[msgid] = nil
	end
    buffer.update_result_display_event.set()
    buffer.update_chunk_display_event.set()
end

--- TODO: The [ marks seem to be uncorrectly placed for the very first edit to a buffer,
--- this triggers the invalidation of the block even though it shouldn't...
function M.invalidate_changed_chunks(buffer)
	log.debug("Invalidating!")
	local tmp = vim.api.nvim_buf_get_mark(buffer.number, "[")
	local rowstart = tmp[1]
	local colstart = tmp[2]
	tmp = vim.api.nvim_buf_get_mark(buffer.number, "]")
	local rowstop = tmp[1]
	local colstop = tmp[2]
    local changed_chunk = M.chunk(rowstart, rowstop, colstart, colstop)
    log.debug({rowstart=rowstart, colstart=colstart, rowstop=rowstop, colstop=colstop})
	for msgid, chunk in M.find_intersected_chunks(buffer, changed_chunk) do
        chunk.valid = false
	end
end

return M
