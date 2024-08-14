-- vim-slime (https://github.com/jpalardy/vim-slime) is an amazing plugin that
-- allows user to send code to REPL. Unfortunately, it does not allow sending
-- metadata such as what we want to do with smuggler.nvim. Here we replicate the
-- core of vim-slime for our purpose.
local M = {}

local protocol = require "smuggler.protocol"
local config = require "smuggler.config"

function M.select_block(linestart, linestop, colstart, colstop)
  result = {}
  for line=linestart,linestop do
    result[#result+1] = vim.api.nvim_buf_get_text(0, line-1, colstart-1, line-1, colstop, {})[1]
  end
  return result
end

function M.send(code, firstline, filename)
  local r = protocol.bufconfig()
  if r == -1 then
    return -1
  end
  protocol.send(code, firstline, filename)
end

-- This is intended to be used as an operator. See `:help :map-operator`.
function M.send_op(type)
  local r = protocol.bufconfig()
  if r == -1 then
    return -1
  end

  local row_start = 1
  local text = ""

  config.debug(type)
  if type == "line" then
    row_start = vim.api.nvim_buf_get_mark(0, "[")[1]
    local row_stop = vim.api.nvim_buf_get_mark(0, "]")[1]
    text = table.concat(vim.api.nvim_buf_get_lines(0, row_start - 1, row_stop, false), "\n")
  elseif type == "block" then
    text = table.concat(
      M.select_block(linestart, linestop, colstart, colstop),
      "\n"
    )
  else -- type == "char"
    config.debug("Sending data using operator as char ")
    local tmp = vim.api.nvim_buf_get_mark(0, "[")
    config.debug("start mark is ", tmp)
    row_start = tmp[1]
    local col_start = tmp[2]
    tmp = vim.api.nvim_buf_get_mark(0, "]")
    config.debug("stop mark is ", tmp)
    local row_stop = tmp[1]-1
    local col_stop = tmp[2]+1
    text = table.concat(vim.api.nvim_buf_get_text(0, row_start-1, col_start, row_stop, col_stop, {}), "\n")
  end
  config.debug({row_start=row_start})

  protocol.send(text, row_start, vim.api.nvim_buf_get_name(0))
end

function M.send_range(linestart, linestop, colstart, colstop , vmode)
  local r = protocol.bufconfig()
  if r == -1 then
    return -1
  end
  local text = nil
  if vmode=='v' then
   text = table.concat(
    vim.api.nvim_buf_get_text(0, linestart - 1,colstart-1, linestop-1, colstop, {}),
    "\n"
  )
  elseif vmode=='V' or vmode==nil then
   text = table.concat(
    vim.api.nvim_buf_get_lines(0, linestart - 1, linestop, false),
    "\n"
  )
  elseif vmode == '\x16' then
    text = table.concat(
      M.select_block(linestart, linestop, colstart, colstop),
      "\n"
    )
  end
  config.debug(text)
  protocol.send(text, linestart, vim.api.nvim_buf_get_name(0))
end

function M.send_lines(count)
  local r = protocol.bufconfig()
  if r == -1 then
    return -1
  end
  if count < 1 then
    count = 1
  end
  local rowcol = vim.api.nvim_win_get_cursor(0)
  local text = table.concat(
    vim.api.nvim_buf_get_lines(0, rowcol[1] - 1, rowcol[1] - 1 + count, false),
    "\n"
  )
  protocol.send(text, rowcol[1], vim.api.nvim_buf_get_name(0))
end

return M
