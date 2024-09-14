local config = {}

-- Default config
config.ui = {
    evaluated_hl = "MoreMsg",
    invalidated_hl = "WarningMsg",
    result_line_length = 80,
    result_hl_group = "DiagnosticVirtualTextInfo",
    display_results = true,
    display_images = true,
    mappings = {}, -- Default mappings are defined in their own file.
    images_height = 10,
    eval_sign_text = "│",
    show_eval = true,
}

config.log = {
    level = "warn",
    use_file = false,
    use_console = true
}

config.buffers = {
    eval_by_blocks = false,
    autoselect_single_socket=true,
    showdir = vim.fs.dirname(vim.fn.tempname()),
    iocontext = {
        compact = true,
        limit = true,
        displaysize = {10, 80},
    },
}
-- End of default config

function config.image_nvim_available()
    -- The package is available if it's already loaded!
    if package.loaded["image"] ~= nil then
        return true
    else -- Else, try to load it.
        local st,_ = pcall(require, "image")
        return st
    end
end

function config.init_config(opts)
    local sections = {"ui", "log", "buffers"}
    for _,section in pairs(sections) do
        if type(opts[section]) == "table" then
            config[section] = vim.tbl_deep_extend("force", config[section], opts[section])
        end
    end
end

return config
