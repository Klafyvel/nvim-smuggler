local M = {}

local uv = vim.uv

M.debug_server_clone_url = "/home/klafyvel/Documents/projets/dev/REPLSmugglerDebugServer.jl"
M.debug_server_project = "nvim-smuggler-tests"
M.server_installed = false

function M:install()
    if self.server_installed == false then
        local install = vim.system({
            "julia",
            "--project=@" .. self.debug_server_project,
            "-e", "import Pkg;Pkg.add(\"" .. self.debug_server_clone_url .. "\")"
        })
        self.server_installed = true
    end
end

M.Pipe = {}
function M.Pipe:new()
    local uv_pipe = uv.new_pipe()
    local pipe =  {
        uv_pipe = uv_pipe,
        semaphore = uv.new_sem(1),
        buffer_head = nil,
        buffer_tail = nil,
        empty = function(self)
            local result = true
            self.semaphore:wait()
            result = self.buffer_tail == nil
            self.semaphore:post()
            return result
        end,
        read = function(self)
            local result = nil
            self.semaphore:wait()
            if self.buffer_head ~= nil then
                result = self.buffer_head.value
                self.buffer_head = self.buffer_head.next
                if self.buffer_head == nil then
                    self.buffer_tail = nil
                end
            end
            self.semaphore:post()
            return result
        end,
        write = function(self, str)
            uv.write(self.uv_pipe, str)
        end,
        read_all = function(self)
            result = ""
            while self:empty() == false do
                result = result * self:read()
            end
            return result
        end
    }
    vim.uv.read_start(uv_pipe, function(err, data)
		if not err then
            pipe.semaphore:wait()
            new_chunk = {value = data, next = nil}
            if pipe:empty() then
                pipe.buffer_tail = new_chunk
                pipe.buffer_head = new_chunk
            else
                pipe.buffer_tail.next = new_chunk
                pipe.buffer_tail = new_chunk
            end
            pipe.semaphore:post()
		end
	end)
    return pipe
end

function M:getserver(socketpath)
    self:install()
    local stdin = self.Pipe.new()
    local stdout = self.Pipe.new()
    local stderr = self.Pipe.new()
    local handle, pid = uv.spawn("julia", {
        args = {
                "--project=@" .. M.debug_server_project,
                "-m", "REPLSmugglerDebugServer", "socketpath"
        },
        stdio = {stdin.uv_pipe,stdout.uv_pipe,stderr.uv_pipe}
    })
    return {
        stdin = stdin,
        stdout = stdout,
        stderr = stderr,
        socketpath = socketpath,
        handle = handle,
        pid = pid,
        kill = function(self, signal)
            return uv.process_kill(self.handle, signal)
        end
    }
end

return M
