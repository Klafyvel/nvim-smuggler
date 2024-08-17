local ui = {}

-- TODO: displaying multiple results for a single msgid fails.

local nio = require("nio")
local default_mappings = require("smuggler.mappings")
local slime = require("smuggler.reslime")
local protocol = require("smuggler.protocol")
local config = require("smuggler.config")

ui.EVALUATED_SIGN_NAME = "smuggler-evaluated"
ui.INVALIDATED_SIGN_NAME = "smuggler-invalidated"
ui.SMUGGLER_SIGN_GROUP = "smuggler"

function ui.create_user_commands()
	vim.api.nvim_create_user_command("SmuggleRange", function(cmdargs)
		slime.send_range(cmdargs.line1, cmdargs.line2)
		ui.update_chunk_highlights()
	end, {
		desc = "Send a range of Julia code to the REPL.",
		range = true,
	})
	vim.api.nvim_create_user_command("SmuggleVisual", function(cmdargs)
		local startpos = vim.fn.getpos("'<")
		local endpos = vim.fn.getpos("'>")
		vmode = vim.fn.visualmode()
		slime.send_range(cmdargs.line1, cmdargs.line2, startpos[3], endpos[3], vmode)
		ui.update_chunk_highlights()
	end, {
		desc = "Send the visual selection to the REPL.",
		range = true, -- Allow range for convenience (calls from visual mode) even
		-- if they are ignored.
	})
	vim.api.nvim_create_user_command("Smuggle", function(cmdargs)
		slime.send_lines(cmdargs.count)
		ui.update_chunk_highlights()
	end, {
		desc = "Send Julia code to the REPL.",
		count = true,
	})
	vim.api.nvim_create_user_command("SmuggleConfig", function(_)
		protocol.bufconfig(nil, true, { evalbyblocks = config.eval_by_blocks })
	end, {
		desc = "(Re)configure the current buffer for smuggling.",
	})
	vim.api.nvim_create_user_command("SmuggleInterrupt", function(_)
		protocol.interrupt()
	end, {
		desc = "Interrupt the current execution",
	})
	vim.api.nvim_create_user_command("SmuggleExit", function(_)
		protocol.exit()
	end, {
		desc = "Exit the current smuggler session.",
	})
	vim.api.nvim_create_user_command("SmuggleEvalByBlocks", function(_)
		protocol.configure_session(nil, { evalbyblocks = true })
	end, {
		desc = "Configure the session to evaluate entries by block.",
	})
	vim.api.nvim_create_user_command("SmuggleEvalByStatement", function(_)
		protocol.configure_session(nil, { evalbyblocks = false })
	end, {
		desc = "Configure the session to evaluate entries by toplevel statements.",
	})
	vim.api.nvim_create_user_command("SmuggleHideDiagnostics", function(_)
		ui.hide_diagnostics()
	end, {
		desc = "Hide smuggler's diagnostics.",
	})
	vim.api.nvim_create_user_command("SmuggleShowDiagnostics", function(_)
		ui.show_diagnostics()
	end, {
		desc = "Show smuggler's diagnostics.",
	})
	vim.api.nvim_create_user_command("SmuggleLocList", function(_)
		ui.show_diagnostic_loclist()
	end, {
		desc = "Show smuggler's diagnostics loclist.",
	})
	vim.api.nvim_create_user_command("SmuggleHideLocList", function(_)
		ui.hide_diagnostic_loclist()
	end, {
		desc = "Hide smuggler's diagnostics loclist.",
	})
	vim.api.nvim_create_user_command("SmuggleHideEvaluated", function(_)
		ui.remove_chunk_highlights()
	end, {
		desc = "Hide highlight around evaluated chunks.",
	})
	vim.api.nvim_create_user_command("SmuggleShowEvaluated", function(_)
		ui.place_chunk_highlights()
	end, {
		desc = "Show highlight around evaluated chunks.",
	})
	vim.api.nvim_create_user_command("SmuggleHideResults", function(_)
		ui.hide_evaluation_results()
	end, {
		desc = "Hide evaluation results.",
	})
	vim.api.nvim_create_user_command("SmuggleShowResults", function(_)
		ui.show_evaluation_results()
	end, {
		desc = "Show evaluation results.",
	})
end

function ui.create_mappings(opts)
	if opts.mappings == false then
		return
	elseif opts.mappings == nil then
		opts.mappings = {}
	end
	for i, mapping in pairs(default_mappings) do
		local key = mapping.key
		if opts.mappings[i] ~= nil then
			key = opts.mappings[i]
		end
		vim.api.nvim_set_keymap(mapping.mode, key, mapping.command, mapping.opts)
	end
end

function ui.init_ui(opts)
	opts.evaluated_hl = (opts.evaluated_hl == nil) and "MoreMsg" or opts.evaluated_hl
	opts.invalidated_hl = (opts.invalidated_hl == nil) and "WarningMsg" or opts.invalidated_hl
	config.evaluated_hl = opts.evaluated_hl
	config.invalidated_hl = opts.invalidated_hl
end

function ui.remove_chunk_highlights(bufnbr)
	bufnbr = (bufnbr == nil) and vim.api.nvim_get_current_buf() or bufnbr
	local namespace = nio.api.nvim_create_namespace("smuggler")
	for i, chunk in pairs(config.buf[bufnbr].evaluated_chunks) do
		if chunk.extmark ~= nil then
			local extmark = vim.api.nvim_buf_get_extmark_by_id(bufnbr, namespace, chunk.extmark, {})
			local linespan = chunk.linestop - chunk.linestart
			vim.api.nvim_buf_set_extmark(bufnbr, namespace, extmark[1], extmark[2], {
				id = chunk.extmark,
				end_row = extmark[1] + linespan,
				sign_text = "",
				sign_hl_group = "",
			})
		end
	end
end

function ui.highlight_chunk(bufnbr, chunk)
	local namespace = nio.api.nvim_create_namespace("smuggler")
	local hl_group = chunk.valid and config.evaluated_hl or config.invalidated_hl
	if chunk.extmark == nil then
		local extmark_id = vim.api.nvim_buf_set_extmark(bufnbr, namespace, chunk.linestart - 1, 0, {
			end_row = chunk.linestop - 1,
			sign_text = "│",
			sign_hl_group = hl_group,
		})
		if extmark_id == -1 then
			error("Could not place extmark for chunk" .. vim.inspect(chunk) .. " at line " .. chunk.linestart)
		else
			chunk.extmark = extmark_id
		end
	else
		local extmark = vim.api.nvim_buf_get_extmark_by_id(bufnbr, namespace, chunk.extmark, {})
		local linespan = chunk.linestop - chunk.linestart
		vim.api.nvim_buf_set_extmark(bufnbr, namespace, extmark[1], extmark[2], {
			id = chunk.extmark,
			end_row = extmark[1] + linespan,
			sign_text = "│",
			sign_hl_group = hl_group,
		})
	end
	return chunk
end

function ui.place_chunk_highlights(bufnbr)
	bufnbr = (bufnbr == nil) and vim.api.nvim_get_current_buf() or bufnbr
	chunks = config.buf[bufnbr].evaluated_chunks
	for _, chunk in pairs(chunks) do
		ui.highlight_chunk(bufnbr, chunk)
	end
end

function ui.update_chunk_highlights(bufnbr)
	ui.remove_chunk_highlights(bufnbr)
	ui.place_chunk_highlights(bufnbr)
end

function ui.show_one_result(bufnbr, result)
	config.debug("Showing bufnbr=" .. bufnbr .. ", result=" .. vim.inspect(result))
	local line_length = 80
	local msgid = result.msgid
	config.debug("Got msgif=" .. msgid)
	local chunk = config.buf[bufnbr].evaluated_chunks[msgid]
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
	config.debug("Preparing lines.")
	local lines = {}
	for line in string.gmatch(result.output, "([^\n]+)") do
		if string.len(line) < line_length then
			line = line .. string.rep(" ", line_length - string.len(line))
		end
		lines[#lines + 1] = { { line, "DiagnosticVirtualTextInfo" } }
	end
	local namespace = nio.api.nvim_create_namespace("smuggler")
	result.mark_id = nio.api.nvim_buf_set_extmark(bufnbr, namespace, firstline, 0, { virt_lines = lines })
	result.shown = true
	config.debug("Done showing.")
end

function ui.show_evaluation_results(bufnbr)
	config.debug("Showing evaluation results")
	bufnbr = (bufnbr == nil) and vim.api.nvim_get_current_buf() or bufnbr
	local buffer = config.buf[bufnbr]
	for msgid, results in pairs(buffer.results) do
		for i, result in pairs(results) do
			if not result.shown then
				ui.show_one_result(bufnbr, result)
			end
		end
	end
end

function ui.hide_evaluation_results(bufnbr)
	bufnbr = (bufnbr == nil) and vim.api.nvim_get_current_buf() or bufnbr
	local buffer = config.buf[bufnbr]
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
    local buffer = config.buf[bufnbr]
	local namespace = nio.api.nvim_create_namespace("smuggler")
    for _,diagnostic in pairs(buffer.diagnostics) do 
        ui.set_one_diagnostic(bufnbr, diagnostic)
    end
    vim.diagnostic.show(namespace, bufnbr)
end

function ui.hide_diagnostics(bufnbr)
	bufnbr = (bufnbr == nil) and vim.api.nvim_get_current_buf() or bufnbr
    local buffer = config.buf[bufnbr]
	local namespace = nio.api.nvim_create_namespace("smuggler")
    vim.diagnostic.hide(namespace, bufnbr)
end

function ui.show_diagnostic_loclist(bufnbr)
	bufnbr = (bufnbr == nil) and vim.api.nvim_get_current_buf() or bufnbr
    local buffer = config.buf[bufnbr]
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

function ui.init_buffer(bufnbr)
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		callback = function(args)
			config.buf[bufnbr].update_chunk_display_event.set()
		end,
		buffer = bufnbr,
	})
end

return ui
