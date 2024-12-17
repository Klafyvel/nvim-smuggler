local M = {}

local uv = vim.loop

function M.socketsdir()
    if vim.fn.has("mac") == 1 then
        return vim.fn.expand("$HOME") .. "/Library/Application Support/lang.julia.REPLSmuggler/"
    elseif vim.fn.has("unix") == 1 then
        return "/run/user/" .. tostring(uv.getuid()) .. "/julia/replsmuggler/"
    elseif vim.fn.has("win32") == 1 then
        return "\\\\.\\pipe\\"
    else
        error("Unsupported platform.")
    end
end

function M.getavailablesockets()
    local directory = M.socketsdir()
    local res = {}
    for v in vim.fs.dir(directory) do
        res[#res + 1] = directory .. v
    end
    return res
end

return M
