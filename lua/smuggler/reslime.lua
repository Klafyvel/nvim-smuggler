-- vim-slime (https://github.com/jpalardy/vim-slime) is an amazing plugin that
-- allows user to send code to REPL. Unfortunately, it does not allow sending
-- metadata such as what we want to do with smuggler.nvim. Here we replicate the
-- core of vim-slime for our purpose.
local M = {}
local protocol = require("smuggler.protocol")
local config = require("smuggler.config")
local buffers = require("smuggler.buffers")

-- TODO: delete old chunks and results

function M.select_block(linestart, linestop, colstart, colstop)
  result = {}
  for line=linestart,linestop do
    result[#result+1] = vim.api.nvim_buf_get_text(0, line-1, colstart-1, line-1, colstop, {})[1]
  end
  return result
end

-- This is intended to be used as an operator. See `:help :map-operator`.
function M.send_op(type)
  local r = protocol.bufconfig()
  if r == -1 then
    return -1
  end
  local bufnbr = vim.api.nvim_get_current_buf()
  local row_start = 1
  local row_stop = nil
  local col_start = nil
  local col_stop = nil
  local text = ""

  config.debug(type)
  if type == "line" then
    local tmp = vim.api.nvim_buf_get_mark(bufnbr, "[")
    row_start = tmp[1]
    col_start = tmp[2]
    tmp = vim.api.nvim_buf_get_mark(bufnbr, "]")
    row_stop = tmp[1]
    col_stop = tmp[2]
    text = table.concat(vim.api.nvim_buf_get_lines(bufnbr, row_start - 1, row_stop, false), "\n")
  elseif type == "block" then
    row_start,col_start = vim.api.nvim_buf_get_mark(bufnbr, "[")
    row_stop,col_stop = vim.api.nvim_buf_get_mark(bufnbr, "]")
    text = table.concat(
      M.select_block(row_start, row_stop, col_start, col_stop),
      "\n"
    )
  else -- type == "char"
    config.debug("Sending data using operator as char ")
    local tmp = vim.api.nvim_buf_get_mark(bufnbr, "[")
    config.debug("start mark is ", tmp)
    row_start = tmp[1]
    col_start = tmp[2]
    tmp = vim.api.nvim_buf_get_mark(bufnbr, "]")
    config.debug("stop mark is ", tmp)
    row_stop = tmp[1]-1
    col_stop = tmp[2]+1
    text = table.concat(vim.api.nvim_buf_get_text(bufnbr, row_start-1, col_start, row_stop, col_stop, {}), "\n")
  end
  config.debug({row_start=row_start})

  local msgid = protocol.send(text, row_start, vim.api.nvim_buf_get_name(bufnbr))
  config.buf[bufnbr].evaluated_chunks[msgid] = buffers.chunk(row_start, row_stop, col_start, cols_top)
  require("smuggler.ui").update_chunk_highlights()
end

function M.send_range(linestart, linestop, colstart, colstop , vmode)
  local r = protocol.bufconfig()
  if r == -1 then
    return -1
  end
  local bufnbr = vim.api.nvim_get_current_buf()
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
  local msgid = protocol.send(text, linestart, vim.api.nvim_buf_get_name(0))
  config.buf[bufnbr].evaluated_chunks[msgid] = buffers.chunk(linestart, linestop, colstart, colstop)
end

function M.send_lines(count)
  local r = protocol.bufconfig()
  if r == -1 then
    return -1
  end
  if count < 1 then
    count = 1
  end
  local bufnbr = vim.api.nvim_get_current_buf()
  local rowcol = vim.api.nvim_win_get_cursor(0)
  local linestart = rowcol[1]
  local linestop = linestart + count - 1
  local text = table.concat(
    vim.api.nvim_buf_get_lines(0, linestart-1, linestop, false),
    "\n"
  )
  local msgid = protocol.send(text, rowcol[1], vim.api.nvim_buf_get_name(0))
  config.buf[bufnbr].evaluated_chunks[msgid] = buffers.chunk(linestart, linestop)
end

return M
