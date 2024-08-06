local smuggler = {}

local protocol = require("smuggler.protocol")
local slime = require("smuggler.reslime")
local toggle_diagnostics = require("smuggler.toggle_diagnostics")

smuggler.send_range = slime.send_range
smuggler.send_lines = slime.send_lines
smuggler.bufconfig = protocol.bufconfig
smuggler.send_op = slime.send_op
smuggler.interrupt = protocol.interrupt
smuggler.exit = protocol.exit
smuggler.configure_session = protocol.configure_session

function smuggler.setup(opts)
  opts = opts or {}
  opts.mappings = (opts.mappings == nil) or opts.mappings
  opts.map_smuggle = (opts.map_smuggle == nil) and "<leader>cs" or opts.map_smuggle
  opts.map_smuggle_range = (opts.map_smuggle_range == nil) and "<leader>cs" or opts.map_smuggle_range
  opts.map_smuggle_config = (opts.map_smuggle_config == nil) and "<leader>ce" or opts.map_smuggle_config
  opts.map_smuggle_operator = (opts.map_smuggle_operator == nil) and "gcs" or opts.map_smuggle_operator
  if opts.eval_by_blocks == nil then
    opts.eval_by_blocks = false
  end

  -- Define commands
  vim.api.nvim_create_user_command("SmuggleRange", function(cmdargs)
    smuggler.send_range(cmdargs.line1, cmdargs.line2)
  end, {
    desc = "Send a range of Julia code to the REPL.",
    range = true,
  })
  vim.api.nvim_create_user_command("Smuggle", function(cmdargs)
    smuggler.send_lines(cmdargs.count)
  end, {
    desc = "Send Julia code to the REPL.",
    count = true,
  })
  vim.api.nvim_create_user_command("SmuggleConfig", function(_)
    smuggler.bufconfig(nil, true, { evalbyblocks = opts.eval_by_blocks })
  end, {
    desc = "(Re)configure the current buffer for smuggling.",
  })
  vim.api.nvim_create_user_command("SmuggleInterrupt", function (_)
    smuggler.interrupt()
  end, {
    desc = "Interrupt the current execution",
  })
  vim.api.nvim_create_user_command("SmuggleExit", function (_)
    smuggler.exit()
  end, {
    desc = "Exit the current smuggler session.",
  })
  vim.api.nvim_create_user_command("SmuggleEvalByBlocks", function(_)
    smuggler.configure_session({ evalbyblocks = true })
  end, {
    desc = "Configure the session to evaluate entries by block.",
  })
  vim.api.nvim_create_user_command("SmuggleEvalByStatement", function(_)
    smuggler.configure_session({ evalbyblocks = false })
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

  -- smugglerappings
  if opts.mappings then
    vim.api.nvim_set_keymap("n", opts.map_smuggle, "<Cmd>Smuggle<cr>", {
      desc = "Send <count> lines to the REPL."
    })
    vim.api.nvim_set_keymap("v", opts.map_smuggle_range, ":SmuggleRange<cr>", {
      desc = "Send <range> to the REPL."
    })
    vim.api.nvim_set_keymap("n", opts.map_smuggle_config, "<Cmd>SmuggleConfig<cr>", {
      desc = "(Re)configure the current buffer for smuggling."
    })
  vim.api.nvim_set_keymap("n", opts.map_smuggle_operator, "<Cmd>set opfunc=v:lua.require'smuggler'.send_op<cr>g@", {
      desc = "Send code to the REPL using a vim operator."
    })
  end
end

return smuggler
