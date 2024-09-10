local M = {}

M.check = function()
    vim.health.start("nvim-smuggler report")
    -- make sure setup function parameters are ok
    if vim.fn.has("nvim-0.10") == 1 then
        vim.health.ok("Neovim version is OK.")
    else
        vim.health.error("Neovim ≥ 0.10 is required for nvim-smuggler.")
    end
end

return M

