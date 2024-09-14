local ui = {}

local nio = require("nio")
local default_mappings = require("smuggler.mappings")
local slime = require("smuggler.reslime")
local protocol = require("smuggler.protocol")
local config = require("smuggler.config")
local buffers = require("smuggler.buffers")
local log = require("smuggler.log")
local run = require("smuggler.run")

local image = nil
if config.image_nvim_available() then
    image = require("image")
end

ui.EVALUATED_SIGN_NAME = "smuggler-evaluated"
ui.INVALIDATED_SIGN_NAME = "smuggler-invalidated"
ui.SMUGGLER_SIGN_GROUP = "smuggler"

function ui.create_user_commands()
	vim.api.nvim_create_user_command("SmuggleRange", function(cmdargs)
        local bufnbr = vim.api.nvim_get_current_buf()
		slime.send_range(bufnbr, cmdargs.line1, cmdargs.line2)
		ui.update_chunk_highlights(bufnbr)
	end, {
		desc = "Send a range of Julia code to the REPL.",
		range = true,
	})
	vim.api.nvim_create_user_command("SmuggleVisual", function(cmdargs)
        local bufnbr = vim.api.nvim_get_current_buf()
		local startpos = vim.fn.getpos("'<")
		local endpos = vim.fn.getpos("'>")
		vmode = vim.fn.visualmode()
		slime.send_range(bufnbr, cmdargs.line1, cmdargs.line2, startpos[3], endpos[3], vmode)
		ui.update_chunk_highlights(bufnbr)
	end, {
		desc = "Send the visual selection to the REPL.",
		range = true, -- Allow range for convenience (calls from visual mode) even
		-- if they are ignored.
	})
	vim.api.nvim_create_user_command("Smuggle", function(cmdargs)
        local bufnbr = vim.api.nvim_get_current_buf()
		slime.send_lines(bufnbr, cmdargs.count)
		ui.update_chunk_highlights(bufnbr)
	end, {
		desc = "Send Julia code to the REPL.",
		count = true,
	})
	vim.api.nvim_create_user_command("SmuggleConfig", function(_)
		buffers.buffer(vim.api.nvim_get_current_buf(), true, { evalbyblocks = config.buffers.eval_by_blocks })
	end, {
		desc = "(Re)configure the current buffer for smuggling.",
	})
	vim.api.nvim_create_user_command("SmuggleInterrupt", function(_)
		protocol.interrupt(vim.api.nvim_get_current_buf())
	end, {
		desc = "Interrupt the current execution",
	})
	vim.api.nvim_create_user_command("SmuggleExit", function(_)
		protocol.exit(vim.api.nvim_get_current_buf())
	end, {
		desc = "Exit the current smuggler session.",
	})
	vim.api.nvim_create_user_command("SmuggleEvalByBlocks", function(_)
		protocol.configure_session(vim.api.nvim_get_current_buf(), { evalbyblocks = true })
	end, {
		desc = "Configure the session to evaluate entries by block.",
	})
	vim.api.nvim_create_user_command("SmuggleEvalByStatement", function(_)
		protocol.configure_session(vim.api.nvim_get_current_buf(), { evalbyblocks = false })
	end, {
		desc = "Configure the session to evaluate entries by toplevel statements.",
	})
	vim.api.nvim_create_user_command("SmuggleHideDiagnostics", function(_)
		ui.hide_diagnostics(vim.api.nvim_get_current_buf())
	end, {
		desc = "Hide smuggler's diagnostics.",
	})
	vim.api.nvim_create_user_command("SmuggleShowDiagnostics", function(_)
		ui.show_diagnostics(vim.api.nvim_get_current_buf())
	end, {
		desc = "Show smuggler's diagnostics.",
	})
	vim.api.nvim_create_user_command("SmuggleLocList", function(_)
		ui.show_diagnostic_loclist(vim.api.nvim_get_current_buf())
	end, {
		desc = "Show smuggler's diagnostics loclist.",
	})
	vim.api.nvim_create_user_command("SmuggleHideLocList", function(_)
		ui.hide_diagnostic_loclist(vim.api.nvim_get_current_buf())
	end, {
		desc = "Hide smuggler's diagnostics loclist.",
	})
	vim.api.nvim_create_user_command("SmuggleHideEvaluated", function(_)
		ui.hide_chunk_highlights(vim.api.nvim_get_current_buf())
	    config.ui.show_eval = false 
	end, {
		desc = "Hide highlight around evaluated chunks, continues to track evaluated code which can be show with SmuggleShowEvaluated later",
	})
	vim.api.nvim_create_user_command("SmuggleDisableEvaluated", function(_)
		ui.hide_chunk_highlights(vim.api.nvim_get_current_buf())
	    ui.disable_autocommands(vim.api.nvim_get_current_buf())
        run.buffers[vim.api.nvim_get_current_buf()].evaluated_chunks={}
	    config.ui.show_eval = false
	end, {
		desc = "Disable tracking of evaluated chunks and delete evaluated chunks info from buffer",
	})
	vim.api.nvim_create_user_command("SmuggleShowEvaluated", function(_)
		ui.init_autocommands(vim.api.nvim_get_current_buf())
	    config.ui.show_eval = true 
	    ui.place_chunk_highlights(vim.api.nvim_get_current_buf())
	end, {
		desc = "Show highlight around evaluated chunks. Enables tracking of evaluated code if not enabled",
	})
	vim.api.nvim_create_user_command("SmuggleHideResults", function(_)
		ui.hide_evaluation_results(vim.api.nvim_get_current_buf())
	end, {
		desc = "Hide evaluation results.",
	})
	vim.api.nvim_create_user_command("SmuggleShowResults", function(_)
		ui.show_evaluation_results(vim.api.nvim_get_current_buf())
	end, {
		desc = "Show evaluation results.",
	})
end

function ui.create_mappings()
	for i, mapping in pairs(default_mappings) do
		local key = mapping.key
		if config.ui.mappings[i] ~= nil then
			key = config.ui.mappings[i]
		end
		vim.api.nvim_set_keymap(mapping.mode, key, mapping.command, mapping.opts)
	end
end

function ui.init_ui()
    vim.api.nvim_create_autocmd("WinNew", {
        callback = function(args)
            -- cannot get win id from arguments, and buffer number is not trustworthy
            -- in args, since BuffEnter hasn't been called yet.
            local winid = math.max(unpack(vim.api.nvim_list_wins()))
            -- Register buffer when it is shown inside window
            vim.schedule(function() ui.add_window(winid) end)
        end
    })
end

function ui.hide_chunk_highlights(bufnbr)
	bufnbr = (bufnbr == nil) and vim.api.nvim_get_current_buf() or bufnbr
	local namespace = nio.api.nvim_create_namespace("smuggler")
	for i, chunk in pairs(run.buffers[bufnbr].evaluated_chunks) do
		if chunk.extmark ~= nil then
			local extmark = vim.api.nvim_buf_get_extmark_by_id(bufnbr, namespace, chunk.extmark, {details=true})
            if #extmark == 0 then -- failed to retrieve the extmark. 
                log.warn("Failed to retrieve extmark for chunk " .. vim.inspect(chunk) .. ". That's likely a bug in nvim-smuggler")
            else
                vim.api.nvim_buf_set_extmark(bufnbr, namespace, extmark[1], extmark[2], {
                    id = chunk.extmark,
                    end_row = extmark[3].end_row,
                    end_col = extmark[3].end_col,
                    sign_text = "",
                    sign_hl_group = "",
                    end_right_gravity = true,
                    right_gravity=false,
                })
            end
		end
	end
    run.buffers[bufnbr].chunks_shown = false
end

function ui.highlight_chunk(bufnbr, chunk)
	local namespace = nio.api.nvim_create_namespace("smuggler")
	local hl_group = chunk.valid and config.ui.evaluated_hl or config.ui.invalidated_hl
    local opts = {
        end_row = chunk.linestop - 1,
        end_col = chunk.colstop,
        sign_text = config.ui.eval_sign_text,
        sign_hl_group = hl_group,
        end_right_gravity = true,
        right_gravity=false
    }
    if config.log.level == "debug" then
        opts.hl_group = "TermCursor"
    end
	if chunk.extmark == nil then
		local extmark_id = vim.api.nvim_buf_set_extmark(bufnbr, namespace, chunk.linestart - 1, chunk.colstart, opts)
		if extmark_id == -1 then
			error("Could not place extmark for chunk" .. vim.inspect(chunk) .. " at line " .. chunk.linestart)
		else
			chunk.extmark = extmark_id
		end
	else
		local extmark = vim.api.nvim_buf_get_extmark_by_id(bufnbr, namespace, chunk.extmark, {details=true})
        if #extmark == 0 then -- failed to retrieve the extmark. 
            log.warn("Failed to retrieve extmark for chunk " .. vim.inspect(chunk) .. ". That's likely a bug in nvim-smuggler")
        else
            vim.api.nvim_buf_set_extmark(bufnbr, namespace, extmark[1], extmark[2], vim.tbl_extend("force", opts, {
                id = chunk.extmark,
                end_row = extmark[3].end_row,
                end_col = extmark[3].end_col
            }))
        end
	end
	return chunk
end

function ui.place_chunk_highlights(bufnbr)
	if config.ui.show_eval then
		bufnbr = (bufnbr == nil) and vim.api.nvim_get_current_buf() or bufnbr
		chunks = run.buffers[bufnbr].evaluated_chunks
		for _, chunk in pairs(chunks) do
			ui.highlight_chunk(bufnbr, chunk)
    	end
        run.buffers[bufnbr].chunks_shown = true
    end
end

function ui.update_chunk_highlights(bufnbr)
    log.trace("Updating chunk highlights with bufnbr=", bufnbr)
	ui.hide_chunk_highlights(bufnbr)
	ui.place_chunk_highlights(bufnbr)
end

function ui.show_images(bufnbr)
    for msgid,results in pairs(run.buffers[bufnbr].results) do 
        for _,result in pairs(results) do
            if result.images ~= nil then
                for _,img in pairs(result.images) do 
                    img:render()
                end
            end
        end
    end
end

function ui.clear_images(bufnbr)
    for msgid,results in pairs(run.buffers[bufnbr].results) do 
        for _,result in pairs(results) do
            if result.images ~= nil then
                for _,img in pairs(result.images) do 
                    img:clear()
                end
            end
        end
    end
end

function ui.add_window(winid)
    local bufnbr = vim.api.nvim_win_get_buf(winid)
    if run.buffers[bufnbr] == nil then
        return
    end
    for msgid,results in pairs(run.buffers[bufnbr].results) do 
        for _,result in pairs(results) do
            local type = vim.split(result.mime, "/")
            if type[1] == "image" then
                ui.add_an_image_to_result(bufnbr, result, winid)
            end
        end
    end
    if run.buffers[bufnbr].results_shown then
        ui.show_images(bufnbr)
    end
end

function ui.add_an_image_to_result(bufnbr, result, winid)
    -- Do not display images when the module is not loaded.
    if image == nil or not config.ui.display_images then
        return
    end
    local winlist = {}
    if winid == nil then
        winlist = vim.fn.win_findbuf(bufnbr)
    else 
        winlist = {winid}
    end
    for _,win in pairs(winlist) do 
        log.debug("Loading an image")
        local img = image.from_file(result.output, {
            with_virtual_padding = true,
            buffer=bufnbr,
            window=win,
            x = 0,
            y = result.firstline,
            height=config.ui.images_height,
        })
        log.debug("Image created", img)
        if img ~= nil then
            if result.images == nil then
                result.images = {}
            end
            result.images[#result.images+1] = img
        else 
            error("Error while loading image " .. result.output)
        end
    end
end

function ui.show_one_result(bufnbr, result)
	log.debug("Showing bufnbr=" .. bufnbr .. ", result=" .. vim.inspect(result))
	local line_length = config.ui.result_line_length
	local msgid = result.msgid
	log.debug("Got msgid=" .. msgid)
	local chunk = run.buffers[bufnbr].evaluated_chunks[msgid]
	if chunk == nil then
		error("Could not find evaluated chunk corresponding to result " .. vim.inspect(result))
	end
	local rellinenumber = result.linenumber - chunk.linestart
	local namespace = nio.api.nvim_create_namespace("smuggler")
	local extmark = nio.api.nvim_buf_get_extmark_by_id(bufnbr, namespace, chunk.extmark, {})
	if #extmark == 0 then
		error("Could not retrieve extmark for chunk " .. vim.inspect(chunk))
	end
	local firstmarkline = extmark[1]
	local firstline = firstmarkline + rellinenumber
    local type = vim.split(result.mime, "/")
    result.firstline = firstline
    if type[1] == "image" then
        ui.add_an_image_to_result(bufnbr, result)
    else
        log.debug("Preparing lines.")
        if result.output ~= nil then
            local lines = {}
            for line in string.gmatch(result.output, "([^\n]+)") do
                if string.len(line) < line_length then
                    line = line .. string.rep(" ", line_length - string.len(line))
                end
                lines[#lines + 1] = { { line, config.ui.result_hl_group} }
            end
            local namespace = nio.api.nvim_create_namespace("smuggler")
            result.mark_id = nio.api.nvim_buf_set_extmark(bufnbr, namespace, firstline, 0, { virt_lines = lines })
        end
    end
	result.shown = true
	log.debug("Done showing.")
end

function ui.show_evaluation_results(bufnbr)
	log.debug("Showing evaluation results")
    if not config.ui.display_results then
        return
    end
	bufnbr = (bufnbr == nil) and vim.api.nvim_get_current_buf() or bufnbr
	local buffer = run.buffers[bufnbr]
	for msgid, results in pairs(buffer.results) do
		for i, result in pairs(results) do
			if not result.shown then
				ui.show_one_result(bufnbr, result)
			end
		end
	end
    ui.show_images(bufnbr)
    buffer.results_shown = true
    log.debug("Evaluation results shown.")
end

function ui.hide_evaluation_results(bufnbr)
	bufnbr = (bufnbr == nil) and vim.api.nvim_get_current_buf() or bufnbr
	local buffer = run.buffers[bufnbr]
	local namespace = nio.api.nvim_create_namespace("smuggler")
	for msgid, results in pairs(buffer.results) do
		for i, result in pairs(results) do
			if result.mark_id ~= nil then
				vim.api.nvim_buf_del_extmark(bufnbr, namespace, result.mark_id)
				result.mark_id = nil
				result.shown = false
			end
		end
	end
    ui.clear_images(bufnbr)
    buffer.results_shown = false
end

function ui.set_one_diagnostic(bufnbr, diagnostic)
    if diagnostic.shown then
        return
    end
	local namespace = nio.api.nvim_create_namespace("smuggler")
    local diagnostics = vim.diagnostic.get(bufnbr, {namespace=namespace})
    for stackidx, stackrow in ipairs(diagnostic.stacktrace) do
        if vim.api.nvim_buf_get_name(bufnbr) ~= stackrow[1] then
            goto continue
        end
        diagnostics[#diagnostics+1] =  {
            lnum = stackrow[2]-1,
            col = 0,
            message = "[" .. stackidx .. "] " .. diagnostic.text .. " in " .. stackrow[3],
            severity = vim.diagnostic.severity.ERROR,
            source = "Julia REPL",
        }
        ::continue::
    end
    vim.diagnostic.set(namespace, bufnbr, diagnostics, {})
    diagnostic.shown = true
end

function ui.show_diagnostics(bufnbr)
	bufnbr = (bufnbr == nil) and vim.api.nvim_get_current_buf() or bufnbr
    local buffer = run.buffers[bufnbr]
	local namespace = nio.api.nvim_create_namespace("smuggler")
    for _,diagnostic in pairs(buffer.diagnostics) do 
        ui.set_one_diagnostic(bufnbr, diagnostic)
    end
    vim.diagnostic.show(namespace, bufnbr)
    buffer.diagnostics_shown = true
end

function ui.hide_diagnostics(bufnbr)
	bufnbr = (bufnbr == nil) and vim.api.nvim_get_current_buf() or bufnbr
    local buffer = run.buffers[bufnbr]
	local namespace = nio.api.nvim_create_namespace("smuggler")
    vim.diagnostic.hide(namespace, bufnbr)
    buffer.diagnostics_shown = false
end

function ui.show_diagnostic_loclist(bufnbr)
	bufnbr = (bufnbr == nil) and vim.api.nvim_get_current_buf() or bufnbr
    local buffer = run.buffers[bufnbr]
	local namespace = nio.api.nvim_create_namespace("smuggler")
    if #buffer.diagnostics == 0 then
        return
    elseif #buffer.diagnostics == 1 then
        local exception_text = buffer.diagnostics[1].text
        vim.diagnostic.setloclist({
            namespace=namespace,
            title="REPL error: " .. exception_text,
        })
    else
        vim.ui.select(buffer.diagnostics, {
            format_item = function(item) 
                return item.text 
            end
        }, function(item, idx)
            if item == nil then
                return
            else
                vim.diagnostic.setloclist({
                    namespace=namespace,
                    title="REPL error: " .. item.text,
                })
            end
        end)
    end
end

function ui.hide_diagnostic_loclist()
    vim.fn.setloclist(0, {})
end

function ui.init_autocommands(bufnbr)
    if run.buffers[bufnbr].aucommands[1] == nil then
        run.buffers[bufnbr].aucommands[1] = vim.api.nvim_create_autocmd({ "TextChangedI" }, {
            callback = function(args)
                run.buffers[bufnbr].update_chunk_cursor_display_event.set()
            end,
            buffer = bufnbr,
        })
    end
    if run.buffers[bufnbr].aucommands[2] == nil then
        run.buffers[bufnbr].aucommands[2] = vim.api.nvim_create_autocmd({ "TextChanged" }, {
            callback = function(args)
                run.buffers[bufnbr].update_chunk_mark_display_event.set()
            end,
            buffer = bufnbr,
        })
    end
end

function ui.disable_autocommands(bufnbr)
    if run.buffers[bufnbr].aucommands[1]~=nil then 
        vim.api.nvim_del_autocmd(run.buffers[bufnbr].aucommands[1])
    end
    if run.buffers[bufnbr].aucommands[2]~=nil then 
        vim.api.nvim_del_autocmd(run.buffers[bufnbr].aucommands[2])
    end
    run.buffers[bufnbr].aucommands = {}
end

function ui.init_buffer(bufnbr)
	if config.ui.show_eval then
		ui.init_autocommands(bufnbr)
	end
end

return ui
