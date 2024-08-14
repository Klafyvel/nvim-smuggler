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

function M.serialize_requests(bufnbr)
  config.debug("Started serializer.")
  local bufconfig = config.buf[bufnbr]
  local queue = bufconfig.outgoing_queue
  local handle = bufconfig.socket
  while not bufconfig.stopped_event.is_set() do
    config.debug("serializer waiting for data.")
    local data = queue.get()
    if data.payload == nil then
      data.payload = {}
    end
    config.debug("Sending data: ", data)
    handle:write(vim.mpack.encode({ 0x00, data.msgid, data.type, data.payload }))
  end
  config.debug("Stopped serializer.")
end

function M.deserialize_answers(bufnbr)
  local bufconfig = config.buf[bufnbr]
  if bufconfig.stopped_event.is_set() then
    return
  end
  local handle = bufconfig.socket
  local queue = bufconfig.incoming_queue
  config.debug("Started deserialize answer.")
  local buffer = ""
  handle:read_start(function(err, chunk)
    config.debug("Received err,chunk:", err, chunk)
    if err then
      error("Error while reading stream: " .. vim.inspect(err))
      bufconfig.stopped_event.set()
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
  bufconfig.stopped_event.wait()
  handle:read_stop()
  config.debug("Pushing nil.")
  nio.run(function()
    queue.put(nil)
  end)
  config.debug("Leaving deserialize_answers.")
end

function M.treat_incoming(bufnbr)
  local bufconfig = config.buf[bufnbr]
  local queue = bufconfig.incoming_queue
  config.debug("Starting treat_incoming")
  while not bufconfig.stopped_event.is_set() do
    config.debug("Waiting for queue")
    local value = queue.get()
    config.debug("Treating: ", value)
    if value == nil then
      break
    elseif value[1] == 2 then -- Received a notification.
      if value[2] == "handshake" then
        -- TODO: perform version control here?
        config.debug("Received Handshake. ", value)
        config.debug(bufconfig.session_initialized_event)
        bufconfig.session_initialized_event.set()
        config.debug(bufconfig.session_initialized_event.is_set())
        config.debug("Notified session initialized.")
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

function M.runclient(bufnbr)
  local bufconfig = config.buf[bufnbr]
  bufconfig.socket  = uv.new_pipe(true)
  bufconfig.socket:connect(bufconfig.path, function(err)
    if err ~= nil then
      error("Could not connect to socket. " .. vim.inspect(err)) 
      bufconfig.stopped_event.set()
    end
    bufconfig.session_connected_event.set()
  end)
  nio.run(function() 
    config.debug("Serializer is waiting...")
    bufconfig.session_initialized_event.wait()
    config.debug("Serializer is done waiting!")
    M.serialize_requests(bufnbr) 
  end)
  nio.run(function() 
    config.debug("Configuration is waiting...")
    bufconfig.session_initialized_event.wait()
    config.debug("Configuration is done waiting!")
    M.configure_session(bufnbr)
  end)
  nio.run(function() 
    bufconfig.session_connected_event.wait()
    M.deserialize_answers(bufnbr)
  end)
  nio.run(function ()
    bufconfig.session_connected_event.wait()
    M.treat_incoming(bufnbr)
  end)
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
  local bufconfig = {
    socket = socket,
    path = socket_path,
    incoming_queue = nio.control.queue(),
    outgoing_queue = nio.control.queue(),
    sent_requests = {},
    lines = '',
    sent_messages = {},
    session_connected_event = nio.control.event(),
    session_initialized_event = nio.control.event(),
    session_settings = settings,
    stopped_event = nio.control.event(),
    last_msgid = 0x00,
  }
  config.buf[bufnbr] = bufconfig

  nio.run(function() M.runclient(vim.api.nvim_get_current_buf()) end)
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
  config.buf[bufnbr].last_msgid = config.buf[bufnbr].last_msgid + 1
  nio.run(function ()
    config.buf[bufnbr].outgoing_queue.put({ msgid=config.buf[bufnbr].last_msgid, type="eval", payload={filename, firstline, code }})
  end)
  return config.buf[bufnbr].last_msgid
end

function M.interrupt()
  local bufnbr = vim.api.nvim_get_current_buf()
  config.buf[bufnbr].last_msgid = config.buf[bufnbr].last_msgid + 1
  nio.run(function ()
    config.buf[bufnbr].outgoing_queue.put({ msgid=config.buf[bufnbr].last_msgid, type="interrupt" })
  end)
  return config.buf[bufnbr].last_msgid
end

function M.exit()
  local bufnbr = vim.api.nvim_get_current_buf()
  config.buf[bufnbr].last_msgid = config.buf[bufnbr].last_msgid + 1
  nio.run(function ()
    config.buf[bufnbr].outgoing_queue.put({ msgid=config.buf[bufnbr].last_msgid, type="exit" })
  end)
  return config.buf[bufnbr].last_msgid
end

function M.configure_session(bufnbr)
  if bufnbr == nil then
    bufnbr = vim.api.nvim_get_current_buf()
  end
  local settings = config.buf[bufnbr].session_settings
  config.buf[bufnbr].last_msgid = config.buf[bufnbr].last_msgid + 1
  nio.run(function ()
    config.buf[bufnbr].outgoing_queue.put({ msgid=config.buf[bufnbr].last_msgid, type="configure", payload={settings} })
  end)
  return config.buf[bufnbr].last_msgid
end

return M
