local M = {}
local nio = require("nio")
local Path = require("pathlib")

M.JULIA_COMMAND = string.gsub(vim.system({ "which", "julia" }, { text = true }):wait().stdout, "\n$", "")
M.JULIA_ENV_PATH = Path.cwd() / "spec" / "smuggler" / "julia_test_env"
M.JULIA_SOCKET = (M.JULIA_ENV_PATH / "test_socket"):tostring()

function M.run_single_julia_command(cmd)
    return vim.system({ M.JULIA_COMMAND, "--project=" .. M.JULIA_ENV_PATH:tostring(), "-e", cmd }, { text = true })
        :wait()
end

function M.instantiate_env()
    M.JULIA_ENV_PATH:mkdir(Path.permission("rwxr-xr-x"), true)
    return M.run_single_julia_command('import Pkg;Pkg.add(Pkg.PackageSpec(name="REPLSmuggler", rev="main"))')
end

function M.start_repl_process()
    vim.notify("Starting Julia REPL...", vim.log.levels.INFO)
    M.instantiate_env()
    local stdin = vim.uv.new_pipe()
    local stdout = vim.uv.new_pipe()
    local stderr = vim.uv.new_pipe()
    local handle, pid = vim.uv.spawn(M.JULIA_COMMAND, {
        stdio = { stdin, stdout, stderr },
        args = { "-i", "--banner=no", "--project=" .. M.JULIA_ENV_PATH:tostring() },
        cwd = M.JULIA_ENV_PATH:tostring(),
    }, function(code, signal)
        print("Julia process exited. Code ", code, ", signal ", signal, ".")
    end)
    vim.notify("Julia REPL started.\n", vim.log.levels.DEBUG)
    local function close()
        stdin:shutdown(function(_)
            handle:close()
        end)
        stdin:close()
        stdout:close()
        stderr:close()
    end
    local function write(s)
        stdin:write(s)
    end
    local readline_buffer = ""
    local function readline(timeout)
        local result = nil
        if timeout == nil then
            timeout = 1000
        end
        local match = string.match(readline_buffer, "^([^\n]*)\n")
        if match ~= nil then
            result = match
            local remaining_buffer_length = match:len() - readline_buffer:len() + 1
            if remaining_buffer_length == 0 then
                readline_buffer = ""
            else
                readline_buffer = readline_buffer:sub(remaining_buffer_length)
            end
        else
            stdout:read_start(function(err, data)
                if err then
                    -- todo: handle errors
                elseif data then
                    readline_buffer = readline_buffer .. data
                    local match = string.match(readline_buffer, "^([^\n]*)\n")
                    vim.print("Step, buffer=" .. vim.inspect(readline_buffer) .. " match=" .. vim.inspect(match))
                    if match ~= nil then
                        result = match
                        local remaining_buffer_length = match:len() - readline_buffer:len() + 1
                        if remaining_buffer_length == 0 then
                            readline_buffer = ""
                        else
                            readline_buffer = readline_buffer:sub(remaining_buffer_length)
                        end
                        stdout:read_stop()
                    end
                end
            end)
            local waitsuccess = vim.wait(timeout, function()
                return not stdout:is_active()
            end)
            if not waitsuccess then
                vim.notify(
                    "Waiting for stdout timeouted. Buffer is: " .. vim.inspect(readline_buffer),
                    vim.log.levels.WARN
                )
            end
            stdout:read_stop()
        end
        vim.print("Buffer=" .. vim.inspect(readline_buffer) .. ", result=" .. vim.inspect(result))
        return result
    end
    local readline_err_buffer = ""
    local function readline_err(timeout)
        local result = nil
        if timeout == nil then
            timeout = 1000
        end
        local match = string.match(readline_err_buffer, "^([^\n]*)\n")
        if match ~= nil then
            result = match
            local remaining_buffer_length = match:len() - readline_err_buffer:len() + 1
            if remaining_buffer_length == 0 then
                readline_err_buffer = ""
            else
                readline_err_buffer = readline_err_buffer:sub(remaining_buffer_length)
            end
        else
            stderr:read_start(function(err, data)
                if err then
                    -- todo: handle errors
                elseif data then
                    readline_err_buffer = readline_err_buffer .. data
                    local match = string.match(readline_err_buffer, "^([^\n]*)\n")
                    if match ~= nil then
                        result = match
                        local remaining_buffer_length = match:len() - readline_err_buffer:len() + 1
                        if remaining_buffer_length == 0 then
                            readline_err_buffer = ""
                        else
                            readline_err_buffer = readline_err_buffer:sub(remaining_buffer_length)
                        end
                        stderr:read_stop()
                    end
                end
            end)
            local waitsuccess = vim.wait(timeout, function()
                return not stderr:is_active()
            end)
            if not waitsuccess then
                vim.notify("Waiting for stderr timeouted.\n", vim.log.levels.WARN)
            end
            stderr:read_stop()
        end
        return result
    end
    local obj = {
        close = close,
        write = write,
        readline = readline,
        readline_err = readline_err,
        handle = handle,
    }
    obj.write([[
    using REPLSmuggler
    smuggle("test_socket", basepath=pwd())
    ]])
    assert(obj.readline_err(10000) ~= nil, "REPLSmuggler did not start in time.") -- REPLSmuggler server starting
    assert(obj.readline(10000) ~= nil, "REPLSmuggler did not start in time.") -- REPLSmuggler server starting
    return obj
end

function M.cleanup_julia_directory()
    for path in M.JULIA_ENV_PATH:fs_iterdir() do
        if path:basename() ~= "Manifest.toml" and path:basename() ~= "Project.toml" then
            if path:is_dir() then
                vim.fn.delete(path:tostring())
            else
                path:unlink()
            end
        end
    end
end

function M.terminate_repl_process(repl)
    repl:close()
    M.cleanup_julia_directory()
end

return M
