local smuggler = {}
local log = require("smuggler.log")

if vim.fn.has("nvim-0.10") ~= 1 then
    log.warn("Neovim ≥ 0.10 is required.")
    smuggler.setup = function(opts) end
    return smuggler
end

local protocol = require("smuggler.protocol")
local slime = require("smuggler.reslime")
local smuggler_ui = require("smuggler.ui")

smuggler.send_range = slime.send_range
smuggler.send_lines = slime.send_lines
smuggler.send_op = slime.send_op
smuggler.interrupt = protocol.interrupt
smuggler.exit = protocol.exit
smuggler.configure_session = protocol.configure_session
smuggler.config = require("smuggler.config")

function smuggler.setup(opts)
	opts = opts or {}

    smuggler.config.init_config(opts)

	smuggler_ui.init_ui()

	-- Define commands
	smuggler_ui.create_user_commands()

	-- smuggler mappings
	smuggler_ui.create_mappings()

    log.new(smuggler.config.log, true)
end

return smuggler
