local M = {}

local default_mappings = require("smuggler.mappings")
local slime = require("smuggler.reslime")
local protocol = require("smuggler.protocol")
local toggle_diagnostics = require("smuggler.toggle_diagnostics")

function M.create_user_commands()
  vim.api.nvim_create_user_command("SmuggleRange", function(cmdargs)
    slime.send_range(cmdargs.line1, cmdargs.line2)
  end, {
    desc = "Send a range of Julia code to the REPL.",
    range = true,
  })
  vim.api.nvim_create_user_command("SmuggleVisual", function(cmdargs)
    local startpos = vim.fn.getpos("'<") 
    local endpos = vim.fn.getpos("'>")
    vmode = vim.fn.visualmode()
    slime.send_range(cmdargs.line1, cmdargs.line2,startpos[3],endpos[3],vmode)
  end, {
    desc = "Send the visual selection to the REPL.",
    range = true, -- Allow range for convenience (calls from visual mode) even 
                  -- if they are ignored.
  })
  vim.api.nvim_create_user_command("Smuggle", function(cmdargs)
    slime.send_lines(cmdargs.count)
  end, {
    desc = "Send Julia code to the REPL.",
    count = true,
  })
  vim.api.nvim_create_user_command("SmuggleConfig", function(_)
    protocol.bufconfig(nil, true, { evalbyblocks = smuggler.config.eval_by_blocks })
  end, {
    desc = "(Re)configure the current buffer for smuggling.",
  })
  vim.api.nvim_create_user_command("SmuggleInterrupt", function (_)
    protocol.interrupt()
  end, {
    desc = "Interrupt the current execution",
  })
  vim.api.nvim_create_user_command("SmuggleExit", function (_)
    protocol.exit()
  end, {
    desc = "Exit the current smuggler session.",
  })
  vim.api.nvim_create_user_command("SmuggleEvalByBlocks", function(_)
    protocol.configure_session({ evalbyblocks = true })
  end, {
    desc = "Configure the session to evaluate entries by block.",
  })
  vim.api.nvim_create_user_command("SmuggleEvalByStatement", function(_)
    protocol.configure_session({ evalbyblocks = false })
  end, {
    desc = "Configure the session to evaluate entries by toplevel statements.",
  })
  vim.api.nvim_create_user_command("SmuggleHideDiagnostics", function (_)
    toggle_diagnostics.hide()
  end, {
    desc = "Hide smuggler's diagnostics.",
  })
  vim.api.nvim_create_user_command("SmuggleShowDiagnostics", function (_)
    toggle_diagnostics.show()
  end, {
    desc = "Show smuggler's diagnostics.",
  })
  vim.api.nvim_create_user_command("SmuggleResetDiagnostics", function (_)
    toggle_diagnostics.reset()
  end, {
    desc = "Reset smuggler's diagnostics.",
  })
end

function M.create_mappings(opts)
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

return M
