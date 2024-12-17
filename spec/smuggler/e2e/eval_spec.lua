local julia_manager = require("spec.smuggler.manage_julia")
local nvim_manager = require("spec.smuggler.manage_remote_nvim")
local EXTERNALLY_MANAGED_JULIA = true
describe("Simple smuggling of code.", function()
    local nvim -- Channel of the embedded Neovim process
    local julia -- Channel of the embedded Julia process
    local buf -- Pointer to the current buffer
    local win -- Pointer to the current Window

    describe("Base operations", function()
        setup(function()
            -- Start a new Neovim process
            nvim = nvim_manager.create_nvim_instance()
            julia = julia_manager.start_repl_process()
            buf = vim.rpcrequest(nvim, "nvim_create_buf", true, false)
            vim.rpcrequest(nvim, "nvim_command", "set syntax=julia")
            win = vim.rpcrequest(nvim, "nvim_get_current_win")
            vim.rpcrequest(nvim, "nvim_win_set_buf", win, buf)
            local code_snippet = [[ 
            println("Print on the first line")

            1 + 1

            a = 1
            b = 2 
            c = 3

            error("This error is on line 9")
            ]]
            vim.rpcrequest(nvim, "nvim_buf_set_lines", buf, 0, -1, false, vim.split(code_snippet, "\n"))
            local cursor_pos = { 1, 0 }
            vim.rpcrequest(nvim, "nvim_win_set_cursor", win, cursor_pos)
            vim.rpcrequest(
                nvim,
                "nvim_command",
                'lua require("smuggler").setup({buffers={availablesockets="'
                    .. require("spec.smuggler.manage_julia").JULIA_SOCKET
                    .. '"}})'
            )
        end)
        teardown(function()
            -- Terminate the Neovim process
            nvim_manager.terminate_nvim_instance(nvim)
            julia_manager.terminate_repl_process(julia)
        end)
        it("Can connect to the Julia REPL", function()
            vim.rpcrequest(nvim, "nvim_command", "SmuggleConfig")
            -- REPLSmuggler.jl prints a newline character here for some reason...
            assert.is.equal("", julia.readline(1000))
            julia.write("println(length(REPLSmuggler.CURRENT_SMUGGLER.sessions))\n")
            local number_connected_sessions = tonumber(julia.readline(10000))
            assert.is.equal(1, number_connected_sessions)
        end)
        it("Can send code snippets to julia", function()
            vim.rpcrequest(nvim, "nvim_command", "Smuggle")
            local printresult = julia.readline()
            assert.is.equal("Print on the first line", printresult)
        end)
        pending("Can send a range")
        pending("Can send visual selection")
        pending("Can be used as an operator")
        pending("Can reconnect to the REPL")
        pending("Can interrupt a command")
        pending("Can exit a session")
        pending("Can exit a session")
        pending("Can re-connect to a session")
        pending("Gives the correct source file for the smuggled code")
        pending("Can report Julia exception")
        pending("Can evaluate by blocks")
        pending("Can toggle diagnostics")
        pending("Can toggle quickfix")
        pending("Can toggle evaluated chunks")
        pending("Reports the correct evaluation results")
        pending("Can toggle the display of evaluation results")
        pending("Can display image results")
    end)

    describe("Fix issue #27: Include all stacktrace entries in the list", function()
        pending("Includes all stacktrace entries in the list.")
    end)
    describe("Fix issue #35: Ablility to send single character chunks", function()
        pending("Can send single character chunks")
    end)
    describe("Fix issue #39: Code invalidation in insert mode", function()
        pending("Invalidates the correct code when editing in insert mode")
    end)
    describe("Fix issue #52: Graceful exit", function()
        pending("Does not leave undesired things in the buffer after exiting.")
    end)
    describe("Fix issue #55: Do not crash when deleting single-line chunks", function()
        pending("Does not crash when a single-line chunk gets deleted.")
    end)
end)
