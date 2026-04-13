describe("Protocol integration tests", function()
    local socket_path, server
    setup(function()
        socket_path = vim.fn.tempname()
        server = require("debug_server"):getserver(socket_path)
    end)

    teardown(function()
        if server then
            server:kill()
        end
        vim.fs.rm(socket_path, {force=true})
    end)

    it("Did not generate any error in the server", function()
        local stderr = server.stderr:read_all()
        assert.are.equals(#stderr, 0)
    end)
end)
