local M = {}

local uv = vim.loop
local nio = require("nio")
local config = require("smuggler.config")
local snitch = require("smuggler.snitch")

function M.socketsdir()
  if vim.fn.has("unix") or vim.fn.has("mac") then
    return "/run/user/" .. tostring(uv.getuid()) .. "/julia/replsmuggler/"
  elseif vim.fn.has("win32") then
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

function M.choosesocket()
  local sockets = M.getavailablesockets()
  local choice = nil
  vim.ui.select(sockets, {
    prompt = 'Select a socket:',
  }, function(c)
    choice = c
  end)
  return choice
end

function M.serialize_requests(handle, queue)
  local msgid = 0
  while not handle:is_closing() do
    local data = queue.get()
    if data.payload == nil then
      data.payload = {}
    end
    config.debug("Sending data: ", data)
    handle:write(vim.mpack.encode({ 0x00, msgid, data.type, data.payload }))
    msgid = msgid + 1
  end
end

function M.deserialize_answers(handle, queue)
  nio.sleep(500)
  config.debug("Now listening to server.")
  local buffer = ""
  handle:read_start(function(err, chunk)
    config.debug("Received err,chunk:", err, chunk)
    if err then
      error("Error while reading stream: " .. vim.inspect(err))
    elseif chunk then
      buffer = buffer .. chunk
      local parsed, res = pcall(vim.mpack.decode, buffer)
      if parsed then
        config.debug("Pushing to queue", buffer, res)
        buffer = ""
        nio.run(function()
          queue.put(res)
        end)
      end
    end
  end)
  while not handle:is_closing() do
    nio.sleep(500)
  end
  config.debug("Pushing nil.")
  nio.run(function()
    queue.put(nil)
  end)
  config.debug("Leaving deserialize_answers.")
end

function M.treat_incoming(bufnbr, queue)
  config.debug("Starting treat_incoming")
  while true do
    config.debug("Waiting for queue")
    local value = queue.get()
    config.debug("Treating: ", value)
    if value == nil then
      break
    elseif value[1] == 2 then -- Received a notification.
      if value[2] == "handshake" then
        -- TODO: perform version control here?
        config.debug("Received Handshake. ", value)
        config.buf[bufnbr].initialized = true
      elseif value[2] == "diagnostic" then
        config.debug("Oh, my. A diagnostic. ")
        snitch.snitch(bufnbr, value)
      else 
        error("Unexpected notification call." .. vim.inspect(value))
      end
    elseif value[1] == 1 then -- This is an answer.
      config.debug("Received Response")
      snitch.snitch(bufnbr, value)
    else -- Something unexpected happened.
      error("Unexpected value received." .. vim.inspect(value))
    end
  end
  config.debug("Leaving treat_incoming")
end

function M.runclient(bufnbr, socket_path)
  local socket = uv.new_pipe(true)
  socket:connect(socket_path)
  local bufconfig = {
    socket = socket,
    path = socket_path,
    incoming_queue = nio.control.queue(),
    outgoing_queue = nio.control.queue(),
    initialized = false,
    sent_requests = {},
    lines = '',
  }
  config.debug("Preparing configuration for bufnbr=", bufnbr, bufconfig)
  config.buf[bufnbr] = bufconfig
  nio.run(function() M.deserialize_answers(socket, bufconfig.incoming_queue) end)
  nio.run(function () M.treat_incoming(bufnbr, bufconfig.incoming_queue) end)
  while not config.buf[bufnbr].initialized do
    nio.sleep(200)
  end
  nio.run(function() M.serialize_requests(socket, bufconfig.outgoing_queue) end)
end

function M.bufconfig(bufnbr, force, settings)
  if bufnbr == nil then
    bufnbr = vim.api.nvim_get_current_buf()
  end
  if force == nil then
    force = false
  end
  if settings == nil then
    settings = {evalbyblocks = config.eval_by_blocks }
  end

  local current_config = config.buf[bufnbr]

  if current_config ~= nil then
    local closed = current_config.socket:is_closing()
    if not closed and not force then
      return 0
    elseif not closed and force then
      current_config.socket:close()
    end
  end

  local socket_path = M.choosesocket()
  if socket_path == nil then
    return -1
  end
  nio.run(function() M.runclient(vim.api.nvim_get_current_buf(), socket_path) end)
  M.configure_session(settings)
  return 0
end

function M.send(code, firstline, filename)
  local bufnbr = vim.api.nvim_get_current_buf()
  if filename == nil then
    filename = vim.api.nvim_buf_get_name(bufnbr)
  end
  -- Clear previous diagnostics
  local namespace = nio.api.nvim_create_namespace("smuggler")
  vim.diagnostic.reset(namespace, bufnbr)
  nio.run(function ()
    config.buf[bufnbr].outgoing_queue.put({ type="eval", payload={filename, firstline, code }})
  end)
end

function M.interrupt()
  local bufnbr = vim.api.nvim_get_current_buf()
  nio.run(function ()
    config.buf[bufnbr].outgoing_queue.put({ type="interrupt" })
  end)
end

function M.exit()
  local bufnbr = vim.api.nvim_get_current_buf()
  nio.run(function ()
    config.buf[bufnbr].outgoing_queue.put({ type="exit" })
  end)
end

function M.configure_session(settings)
  local bufnbr = vim.api.nvim_get_current_buf()
  nio.run(function ()
    config.buf[bufnbr].outgoing_queue.put({ type="configure", payload={settings} })
  end)
end

return M
