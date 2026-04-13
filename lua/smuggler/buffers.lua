--- Abstraction for a buffer
local M = {}

local log = require("smuggler.log")
local config = require("smuggler.config")

--- Represent a chunk of code.
---@class smuggler.Chunk
---@field linestart number The starting line of the chunk.
---@field linestop number The stopping line of the chunk, inclusive.
---@field colstart number The starting column of the chunk.
---@field colstop number The stopping column of the chunk, exclusive.
---@field valid boolean Wether this chunk of code is still valid.
---@field extmark? number The id of the corresponding extmark (see `nvim_buf_get_extmark_by_id`)
M.Chunk = {}
--- Create a new `smuggler.Chunk`
---@param linestart number
---@param linestop number
---@param colstart number
---@param colstop number
---@param valid? boolean
---@return smuggler.Chunk
M.Chunk.new = function(linestart, linestop, colstart, colstop, valid)
    if valid == nil then
        valid = true
    end
    local chunk = {
        linestart = linestart,
        linestop = linestop,
        colstart = colstart,
        colstop = colstop,
        valid = valid,
        extmark = nil,
    }
    return setmetatable(chunk, { __index = M.Chunk })
end

--- An evaluation result
---@class smuggler.Result
---@field linenumber number The number of the line that produced that result.
---@field mime string The mime type of the result.
---@field output string The output corresponding to the result.
---@field shown boolean Toggles the display of the result.
M.Result = {}
--- Create a new `smuggle.Result`.
---@param linenumber number The number of the line that produced that result.
---@param mime string The mime type of the result.
---@param output string The output corresponding to the result.
---@param shown? boolean Toggles the display of the result.
M.Result.new = function(linenumber, mime, output, msgid, shown)
    if shown == nil then
        shown = false
    end
    local result = {
        linenumber = linenumber,
        mime = mime,
        output = output,
        msgid = msgid,
        shown = shown
    }
    return setmetatable(result, {__index = M.Result})
end

--- A diagnostic (i.e. an error)
---@class smuggler.Diagnostic
---@field text string The text corresponding to the error.
---@field stacktrace ([string, number, string, string?])[] The corresponding stack trace (file, line, function, module).
---@field msgid number The message id that produced the diagnostic.
---@field shown boolean Toggles the display of the result.
M.Diagnostic = {}
--- Create a new `smuggler.Diagnostic`.
---@param text string The text corresponding to the error.
---@param stacktrace ([string, number, string, string?])[] The corresponding stack trace (file, line, function, module).
---@param msgid number The message id that produced the diagnostic.
---@param shown boolean Toggles the display of the result.
M.Diagnostic.new = function(text, stacktrace, msgid, shown)
    if shown == nil then
        shown = false
    end
    local diagnostic = {
        text = text,
        stacktrace = stacktrace,
        msgid = msgid,
        shown = shown,
    }
    return setmetatable(diagnostic, {__index = M.Diagnostic})
end

local MpscQueue = require('coop.mpsc-queue').MpscQueue

---@class smuggler.SessionSettings
---@field evalbyblocks? boolean Toggles block evaluation of chunks.
---@field showdir? string Directory for REPLSmuggler.jl to save images to.
---@field iocontext? smuggler.JuliaIOContext Julia IO context used for this buffer.
---@field enableimages? boolean Toggles images use in this buffer.
M.SessionSettings = {}
---@class smuggler.InternalSessionSettings
---@field evalbyblocks boolean Toggles block evaluation of chunks.
---@field showdir string Directory for REPLSmuggler.jl to save images to.
---@field iocontext smuggler.JuliaIOContext Julia IO context used for this buffer.
---@field enableimages boolean Toggles images use in this buffer.
M.InternalSessionSettings = {}
--- Create an internal setting from user-provided settings (i.e. replace options
--- with plugin-level configuration)
---@param settings smuggler.SessionSettings
---@return smuggler.InternalSessionSettings
M.InternalSessionSettings.new = function(settings)
    local config = require("smuggler.config")
    local default_settings = {
        evalbyblocks = config.buffers.eval_by_blocks,
        showdir = vim.fs.joinpath(config.buffers.showdir, bufnbr),
        iocontext = config.buffers.iocontext,
        enableimages = config.ui.display_images,
    }
    for k,v in pairs(settings) do
        if default_settings[k] ~= nil then
            default_settings[k] = v
        end
    end
    return setmetatable(default_settings, {__index=M.InternalSessionSettings})
end

---@class smuggler.Buffer
---@field number number The buffer number.
---@field socket? uv_handle_t The socket in use. Initialized when the client starts running.
---@field path? string Path to the socket that is to be used.
---@field incoming_queue Coop.MpscQueue Queue of incoming diagnostics.
---@field outgoing_queue Coop.MpscQueue Queue of outgoing commands.
---@field last_msgid number To keep track of the last used message id.
---@field evaluated_chunks table<number, smuggler.Chunk> Association table of message id to chunk.
---@field results table<number, smuggler.Result[]> Association table of a message id to a table of results.
---@field diagnostics smuggler.Diagnostic[] A list of diagnostics created by the last message sent.
---@field chunks_shown boolean Toggles the display of chunks.
---@field results_shown boolean Toggles the display of results.
---@field diagnostics_shown boolean Toggles the display of diagnostics.
---@field aucommands number[] A table of auticimmand id created for the buffer.
---@field session_settings smuggler.InternalSessionSettings session settings to be provided when initiating connection.
---@field tasks table<string, Coop.Task> a map of tasks running within the buffer.
M.Buffer = {}

--- A table of all declared `smuggler.Buffer`.
---@type table<number, smuggler.Buffer>
M.Buffer.buffers = {}

--- A list of callbacks to be called when configuring a buffer.
---@type fun(buffer: smuggler.Buffer)[]
M.buffer_configuration_callbacks = {}
--- Register a callback to be called when a buffer is configured. This typically
--- Typically used by the user interface to select a socket.
---@param callback fun(buffer: smuggler.Buffer)
M.on_configure_buffer = function(callback)
    M.buffer_configuration_callbacks[#M.buffer_configuration_callbacks+1] = callback
end

--- A list of callbacks to be called after creating a new buffer.
---@type fun(buffer: smuggler.Buffer)[]
M.new_buffer_callbacks = {}
--- Register a callback to be called when a new buffer is created. This typically
--- allows other modules to hook into the creation of buffers to follow their
--- incoming and outgoing queues.
---@param callback fun(buffer: smuggler.Buffer)
M.on_new_buffer = function(callback)
    M.new_buffer_callbacks[#M.new_buffer_callbacks+1] = callback
end

--- Create a new `smuggler.Buffer`
---@param bufnbr? number The NeoVim buffer number. Defaults to the current one.
---@param force? boolean When `true` re-create the buffer if it exists. Defaults to false.
---@param settings? smuggler.SessionSettings Parameters to e used when creating a new session.
M.Buffer.new = function(bufnbr, force, settings)
    if bufnbr == nil then
        bufnbr = vim.api.nvim_get_current_buf()
    end
    if force == nil then
        force = false
    end
    if settings == nil then
        settings = {}
    end
    settings = M.InternalSessionSettings.new(settings)
    local current_buffer = M.Buffer.buffers[bufnbr]
    if current_buffer ~= nil then
        local closed = current_buffer.socket == nil or current_buffer.socket:is_closing()
        if not closed and not force then
            return current_buffer
        elseif not closed and force then
            current_buffer:terminate()
        end
    end
    local bufname = vim.fn.bufname(bufnbr)
    local splitted_name = vim.split(vim.fs.basename(bufname), ".")[1]
    local images_path = vim.fs.joinpath(vim.fs.dirname(bufname), splitted_name .. "_images")
    local buffer = setmetatable({
        number = bufnbr,
        socket = nil,
        path = nil,
        incoming_queue = MpscQueue.new(),
        outgoing_queue = MpscQueue.new(),
        last_msgid = 0x00,
        evaluated_chunks = {},
        results = {},
        diagnostics = {},
        chunks_shown = {},
        results_shown = {},
        diagnostics_shown = {},
        aucommands = {},
        session_settings = settings,
        tasks = {},
    }, {__index = M.Buffer})
    M.Buffer.buffers[bufnbr] = buffer
    for i,callback in ipairs(M.buffer_configuration_callbacks) do
        callback(buffer)
    end
    for i,callback in ipairs(M.new_buffer_callbacks) do
        callback(buffer)
    end
    return buffer
end

--- Add a tracked chunk to the buffer.
---@param msgid number Message id
---@param chunk smuggler.Chunk
M.Buffer.add_chunk = function(self, msgid, chunk)
    if chunk.extmark == nil then
        local namespace = vim.api.nvim_create_namespace("smuggler")
        local hl_group = chunk.valid and config.ui.evaluated_hl or config.ui.invalidated_hl
        local opts = {
            end_row = chunk.linestop,
            end_col = chunk.colstop,
            sign_text = config.ui.eval_sign_text,
            sign_hl_group = hl_group,
            end_right_gravity = true,
            right_gravity = false,
        }
        if config.log.level == "debug" then
            opts.hl_group = "TermCursor"
        end
        local extmark_id = vim.api.nvim_buf_set_extmark(self.number, namespace, chunk.linestart, chunk.colstart, opts)
        if extmark_id == -1 then
            log.error("Could not place extmark for chunk", vim.inspect(chunk), "at line", chunk.linestart)
        else
            chunk.extmark = extmark_id
        end
    end
    self.evaluated_chunks[msgid] = chunk
end

--- Add a diagnostic to the buffer
---@param diagnostic smuggler.Diagnostic
M.Buffer.add_diagnostic = function(self, diagnostic)
    self.diagnostics[#self.diagnostics+1] = diagnostic
end

--- Add a result to the buffer
---@param msgid number Message ID
---@param result smuggler.Result
M.Buffer.add_result = function(self, msgid, result)
    if self.results[msgid] == nil then
        self.results[msgid] = {}
    end
    local tbl_results = self.results[msgid]
    tbl_results[#tbl_results+1] = result
end

--- Get the update chunk in the buffer using the extmark to retrieve the new position
--- if it has been set.
---@param chunk smuggler.Chunk
---@return smuggler.Chunk
M.Buffer.updated_chunk = function(self, chunk)
    if chunk.extmark == nil then
        return chunk
    else
        local namespace = vim.api.nvim_create_namespace("smuggler")
        local extmark = vim.api.nvim_buf_get_extmark_by_id(self.number, namespace, chunk.extmark, {details=true})
        local new_linestart = extmark[1]
        local new_colstart = extmark[2]
        local new_linestop = extmark[3].end_row
        local new_colstop = extmark[3].end_col
        return M.Chunk.new(new_linestart, new_linestop, new_colstart, new_colstop)
    end
end

--- Detect chunks intersecting a given chunk.
---@param chunk smuggler.Chunk
---@return smuggler.Chunk[]
M.Buffer.intersected_chunks = function(self, chunk)
    local namespace = vim.api.nvim_create_namespace("smuggler")
    local intersected_extmarks = vim.iter(
        vim.api.nvim_buf_get_extmarks(
            self.number,
            namespace,
            { chunk.linestart - 1, chunk.colstart },
            { chunk.linestop - 1, chunk.colstop },
            { overlap = true }
        )
    )
    intersected_extmarks:map(function(item)
        return item[1]
    end)
    intersected_extmarks = intersected_extmarks:fold({}, function(t, v)
        if v ~= nil then
            t[v] = true
        end
        return t
    end)
    return vim.iter(pairs(self.evaluated_chunks)):filter(function(i, chunk)
        return intersected_extmarks[chunk.extmark] ~= nil
    end):totable()
end

--- Delete the chunks associated to a message id. Remove the associated extmarks
--- and results.
---@param msgid number
M.Buffer.delete_chunk = function(self, msgid)
    local namespace = vim.api.nvim_create_namespace("smuggler")
    if self.results[msgid] ~= nil then
        for _, result in ipairs(self.results[msgid]) do
            if result.mark_id ~= nil then
                vim.api.nvim_buf_del_extmark(self.number, namespace, result.mark_id)
            end
        end
    end
    local chunk = self.evaluated_chunks[msgid]
    if chunk.extmark ~= nil then
        vim.api.nvim_buf_del_extmark(self.number, namespace, chunk.extmark)
    end
    if self.results[msgid] ~= nil then
        for _, result in pairs(self.results[msgid]) do
            if result.images ~= nil then
                for _, img in pairs(result.images) do
                    img:clear()
                end
            end
        end
        self.results[msgid] = nil
    end
    self.evaluated_chunks[msgid] = nil
end

--- Delete the chunks intersecting a given chunk
---@param new_chunk smuggler.Chunk
M.Buffer.delete_intersected_chunks = function(self, new_chunk)
    for msgid, _ in M.find_intersected_chunks(self, new_chunk) do
        self:delete_chunk(msgid)
    end
end

--- Invalidate any chunk that intersects a given chunk.
---@param changed_chunk smuggler.Chunk The chunk that invalidates the others.
M.Buffer.invalidate_intersected_chunks = function(self, changed_chunk)
    log.debug("Updating for chunk:", changed_chunk)
    for _, chunk in M.find_intersected_chunks(self, changed_chunk) do
        chunk.valid = false
        -- Use extmark to track the new length of the self (in particular, delete it if empty)
        log.debug("Invalidating chunk:", chunk)
    end
end

--- Synchronize the chunks in memory with the extmarks set in a Neovim buffer.
M.Buffer.synchronize_chunks_with_marks = function(self)
    local namespace = vim.api.nvim_create_namespace("smuggler")
    for msgid, chunk in pairs(self.evaluated_chunks) do
        log.debug("Synchronizing chunk ", chunk)
        if chunk.extmark ~= nil then
            local extmark = vim.api.nvim_buf_get_extmark_by_id(self.number, namespace, chunk.extmark, { details = true })
            chunk.linestart = extmark[1] + 1
            chunk.colstart = extmark[2]
            chunk.linestop = extmark[3].end_row + 1
            chunk.colstop = extmark[3].end_col
            log.debug("New value is", chunk)
            if (chunk.linestart == chunk.linestop) and (chunk.colstart == chunk.colstop) then
                log.debug("It's empty, so it gets deleted.")
                self:delete_chunk(msgid)
            end
        end
    end
end

--- Invalidate the chunks within the previously changed text (see `:help '[`).
--- TODO: The [ marks seem to be uncorrectly placed for the very first edit to a buffer,
--- this triggers the invalidation of the block even though it shouldn't...
M.Buffer.invalidate_changed_chunks_marks = function(self)
    log.debug("Invalidating!")
    local tmp = vim.api.nvim_buf_get_mark(self.number, "[")
    local rowstart = tmp[1]
    local colstart = tmp[2]
    tmp = vim.api.nvim_buf_get_mark(self.number, "]")
    local rowstop = tmp[1]
    local colstop = tmp[2]
    local changed_chunk = M.Chunk.new(rowstart, rowstop, colstart, colstop)
    self:invalidate_intersected_chunks(changed_chunk)
end

--- Invalidate the chunk currently under the cursor.
M.invalidate_changed_chunks_cursor = function(self)
    log.debug("Invalidating!")
    local cur = vim.api.nvim_win_get_cursor(0)
    local row = cur[1]
    local col = cur[2]
    local changed_chunk = M.Chunk.new(row, row, col, col)
    self:invalidate_intersected_chunks(changed_chunk)
end

--- Clear the diagnostics associated to a buffer.
M.Buffer.clear_diagnostics = function(self)
    local namespace = vim.api.nvim_create_namespace("smuggler")
    vim.diagnostic.reset(namespace, self.number)
end

--- Get the code within a given chunk
---@param chunk smuggler.Chunk
---@return string text
M.Buffer.get_text = function(self, chunk)
    local text = vim.api.nvim_buf_get_text(self.number, chunk.linestart, chunk.colstart, chunk.linestop, chunk.colstop, {})
    return table.concat(text, "\n")
end

--- Add a task to the buffer. It allows the buffer to terminate it.
---@param id string Identifier of the task
---@param task Coop.Task
M.Buffer.add_task = function(self, id, task)
    self.tasks[id] = task
end

--- Terminate all tasks related to a buffer and clear the buffer from smuggler's
--- things.
M.Buffer.terminate = function(self)
    for id,task in pairs(self.tasks) do
        if not task:is_cancelled() then
            log.trace("Cancelling task with id:", id)
            task:cancel()
        end
    end
    self.tasks = {}
    for msgid,_ in pairs(self.evaluated_chunks) do
        self:delete_chunk(msgid)
    end
end

return M

