local M = {}
-- local nio = require("nio")
--
-- M.buf_config_semaphore = nio.control.semaphore()
M.buf = {}

M.debug=true
M.debug_restart=true

if M.debug then
    M.log_fh = io.open("smuggler.log", M.debug_restart and 'w' or 'a')
end

function M.debug(...)
  if M.debug then
    local objects = {}
    for i = 1, select('#', ...) do
      local v = select(i, ...)
      table.insert(objects, vim.inspect(v))
    end
    M.log_fh:write(table.concat(objects, '\n') .. '\n')
    M.log_fh:flush()
  end
end

return M
