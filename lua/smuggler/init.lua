local smuggler = {}

local protocol = require("smuggler.protocol")
local slime = require("smuggler.reslime")
local smuggler_ui = require("smuggler.ui")

smuggler.send_range = slime.send_range
smuggler.send_lines = slime.send_lines
smuggler.bufconfig = protocol.bufconfig
smuggler.send_op = slime.send_op
smuggler.interrupt = protocol.interrupt
smuggler.exit = protocol.exit
smuggler.configure_session = protocol.configure_session
smuggler.config = require("smuggler.config")

function smuggler.setup(opts)
  opts = opts or {}
  if opts.eval_by_blocks == nil then
    opts.eval_by_blocks = false
  end
  smuggler.config.eval_by_blocks = opts.eval_by_blocks

  smuggler_ui.init_ui(opts)

  -- Define commands
  smuggler_ui.create_user_commands()

  -- smuggler mappings
  smuggler_ui.create_mappings(opts)
end

return smuggler

