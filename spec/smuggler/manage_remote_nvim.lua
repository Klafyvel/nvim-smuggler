local M = {}

local jobopts = {
    rpc = true,
    width = 80,
    height = 24,
    env = {
        XDG_DATA_HOME = vim.fn.getcwd() .. "/spec/xdg/local/share",
        XDG_STATE_HOME = vim.fn.getcwd() .. "/spec/xdg/local/state",
        XDG_CONFIG_HOME = vim.fn.getcwd() .. "/spec/xdg/config",
    },
}
local config_link = jobopts.env.XDG_DATA_HOME .. "/nvim/site/pack/testing/start/smuggler"

function M.create_nvim_instance()
    vim.uv.fs_symlink(vim.fn.getcwd(), config_link)
    local nvim = vim.fn.jobstart({ vim.v.progpath, "--embed", "--headless" }, jobopts)
    return nvim
end

function M.terminate_nvim_instance(nvim)
    vim.fn.jobstop(nvim)
    vim.uv.fs_unlink(config_link)
end

return M
