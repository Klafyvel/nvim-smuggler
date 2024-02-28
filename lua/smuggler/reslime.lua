-- vim-slime (https://github.com/jpalardy/vim-slime) is an amazing plugin that
-- allows user to send code to REPL. Unfortunately, it does not allow sending
-- metadata such as what we want to do with smuggler.nvim. Here we replicate the
-- core of vim-slime for our purpose.
local M = {}

local protocol = require "smuggler.protocol"

function M.send(code, firstline, filename)
  protocol.bufconfig()
  protocol.send(code, firstline, filename)
end

-- This is intended to be used as an operator. See `:help :map-operator`.
function M.send_op(type)
  protocol.bufconfig()

  local row_start = 1
  local text = ""

  if type == "line" then
    row_start = vim.api.nvim_buf_get_mark(0, "[")[1]
    local row_stop = vim.api.nvim_buf_get_mark(0, "]")[1]
    text = table.concat(vim.api.nvim_buf_get_lines(0, row_start - 1, row_stop, false), "\n")
  elseif type == "block" then
    -- not implemented yet.
  else -- type == "char"
    local tmp = vim.api.nvim_buf_get_mark(0, "[")
    row_start = tmp[1]
    local col_start = tmp[2]
    tmp = vim.api.nvim_buf_get_mark(0, "]")
    local row_stop = tmp[1]
    local col_stop = tmp[2]
    text = table.concat(vim.api.nvim_buf_get_text(0, row_start, col_start, row_stop, col_stop), "\n")
  end

  M.send(text, row_start, vim.api.nvim_buf_get_name(0))
end

function M.send_range(linestart, linestop)
  protocol.bufconfig()
  local text = table.concat(
    vim.api.nvim_buf_get_lines(0, linestart - 1, linestop, false),
    "\n"
  )
  M.send(text, linestart, vim.api.nvim_buf_get_name(0))
end

function M.send_lines(count)
  protocol.bufconfig()
  if count < 1 then
    count = 1
  end
  local rowcol = vim.api.nvim_win_get_cursor(0)
  local text = table.concat(
    vim.api.nvim_buf_get_lines(0, rowcol[1] - 1, rowcol[1] - 1 + count, false),
    "\n"
  )
  M.send(text, rowcol[1], vim.api.nvim_buf_get_name(0))
end

return M
