local M = {}
M.buf = {}

M.debug_enabled = false
M.debug_restart = true

if M.debug_enabled then
	M.log_fh = io.open("smuggler.log", M.debug_restart and "w" or "a")
end

function M.image_nvim_available()
    -- The package is available if it's already loaded!
    if package.loaded["image"] ~= nil then
        return true
    else -- Else, try to load it.
        local st,_ = pcall(require, "image")
        return st
    end
end

function M.debug(...)
	if M.debug_enabled then
		local objects = {}
		for i = 1, select("#", ...) do
			local v = select(i, ...)
			table.insert(objects, vim.inspect(v))
		end
		M.log_fh:write(table.concat(objects, "\n") .. "\n")
		M.log_fh:flush()
	end
end

return M
