local smuggler = {}

local protocol = require("smuggler.protocol")
local slime = require("smuggler.reslime")

smuggler.send_range = slime.send_range
smuggler.send_lines = slime.send_lines
smuggler.bufconfig = protocol.bufconfig
smuggler.send_op = slime.send_op

function smuggler.setup(opts)
  opts = opts or {}
  opts.mappings = (opts.mappings == nil) or opts.mappings
  opts.map_smuggle = (opts.map_smuggle == nil) and "<leader>cs" or opts.map_smuggle
  opts.map_smuggle_range = (opts.map_smuggle_range == nil) and "<leader>cs" or opts.map_smuggle_range
  opts.map_smuggle_config = (opts.map_smuggle_config == nil) and "<leader>ce" or opts.map_smuggle_config
  opts.map_smuggle_operator = (opts.map_smuggle_operator == nil) and "gcs" or opts.map_smuggle_operator

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
    smuggler.bufconfig(nil, true)
  end, {
    desc = "(Re)configure the current buffer for smuggling.",
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
