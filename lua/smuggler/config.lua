--- Configuration format for nvim-smuggler. They all have default values defined
--- in `default_config`.
---
---@class smuggler.Config
---@field ui? smuggler.UIConfig User interface configuration
---@field log? smuggler.LogConfig Logging configuration
---@field buffers? smuggler.BuffersConfig Buffers configuration
---@class smuggler.UIConfig
---@field evaluated_hl? string Highlight group for evaluated chunks.
---@field invalidated_hl? string Highlight group for invalidated evaluated chunks.
---@field result_line_length? number Line length of displayed results.
---@field result_hl_group? string Highlight group used for results.
---@field display_results? boolean Display evaluation results.
---@field display_images? boolean Display images if `images.nvim` is present.
---@field images_height? number Number of lines an image should occupy.
---@field eval_sign_text? string Symbol in signcolumn to mark evaluated/invalidated , set to "" to disable
---@field show_eval? boolean If set to false, do not attempt to track modifications in evaluated code chunks.
---@field qf_skip_base? boolean If true, do not show errors in `Base`.
---@field qf_auto_refresh? boolean If true, the quickfix list is refreshed each time an error is smuggled.
---@field qf_auto_open? boolean If true, the quickfix window is opened each time nvim-smuggler refreshes the quickfix window.
---@field qf_custom_text? boolean If true, the quickfix text will be altered to look like Julia REPL Exception printing.
---@field qf_custom_display? boolean If true, the quickfix window will be given an opinionated look (works with qf_custom_text).
---@class smuggler.LogConfig
---@field level? LogLevel Available: trace, debug, info, warn, error, fatal
---@field use_file? boolean Output logs to `stdpath("data")/smuggler.log`, e.g. `~/.local/share/nvim/smuggler.log `
---@field use_console? boolean Output logs to the console.
---@class smuggler.BuffersConfig
---@field eval_by_blocks? boolean Configure each new session eval by block attribute.
---@field autoselect_single_socket? boolean When true, skip socket selection dialog if there's only one choice possible.
---@field showdir? Directory for REPLSmuggler to save images to.
---@field availablesockets? string|string[]|fun():string|fun():string[] Return the list of available sockets.
---@field iocontext? smuggler.JuliaIOContext the IO context passed to Julia (https://docs.julialang.org/en/v1/base/io-network/#Base.IOContext-Tuple%7BIO,%20Pair%7D).
---@class smuggler.JuliaIOContext
---@field compact? boolean
---@field limit? boolean
---@field displaysize? [number, number]

--- An internal type used to hold the default and in-use configuration of the module.
---@class smuggler.InternalConfig
local config = {
    ui = {
        ---@type string
        evaluated_hl = "MoreMsg",
        ---@type string
        invalidated_hl = "WarningMsg",
        ---@type number
        result_line_length = 80,
        ---@type string
        result_hl_group = "DiagnosticVirtualTextInfo",
        ---@type boolean
        display_results = true,
        ---@type boolean
        display_images = true,
        mappings = {}, -- Default mappings are defined in their own file.
        ---@type number
        images_height = 10,
        ---@type string
        eval_sign_text = "│",
        ---@type boolean
        show_eval = true,
        ---@type boolean
        qf_skip_base = false,
        ---@type boolean
        qf_auto_refresh = true,
        ---@type boolean
        qf_auto_open = false,
        ---@type boolean
        qf_custom_text = false,
        ---@type boolean
        qf_custom_display = false,
    },
    log = {
        ---@type string
        level = "warn",
        ---@type boolean
        use_file = false,
        ---@type boolean
        use_console = true,
    },
    buffers = {
        ---@type boolean
        eval_by_blocks = false,
        ---@type boolean
        autoselect_single_socket = true,
        showdir = vim.fs.dirname(vim.fn.tempname()),
        iocontext = {
            ---@type boolean
            compact = true,
            ---@type boolean
            limit = true,
            ---@type [number, number]
            displaysize = { 10, 80 },
        },
        availablesockets = require("smuggler.utils").getavailablesockets,
    },
}

--- Detect the image.nvim plugin.
---@return boolean 
function config:image_nvim_available()
    -- The package is available if it's already loaded!
    if package.loaded["image"] ~= nil then
        return true
    else -- Else, try to load it.
        local st, _ = pcall(require, "image")
        return st
    end
end

--- Initialize the internal configuration by merging the user configuration with
--- the default one.
---@param opts smuggler.Config The user-provided configuration.
function config:init(opts)
    local sections = { "ui", "log", "buffers" }
    for _, section in pairs(sections) do
        if type(opts[section]) == "table" then
            self[section] = vim.tbl_deep_extend("force", self[section], opts[section])
        end
    end
end

return config
