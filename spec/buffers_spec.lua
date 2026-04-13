describe("Buffers unit testing", function()
    local bufnbr
    local buffer
    local buffers = require("smuggler.buffers")
    setup(function()
        require("smuggler").setup({log={use_console=true, level="trace"}})
        bufnbr = vim.api.nvim_create_buf(true, true)
    end)
    before_each(function()
        buffer = buffers.Buffer.new(bufnbr)
        vim.api.nvim_buf_set_lines(bufnbr, 0, -1, true, {
            "This is a buffer",
            "With some text",
            "",
            "Oh, a paragraph!",
        })
    end)
    after_each(function()
        buffer:terminate()
    end)
    it("Selects the text correctly.", function()
        local chunk = buffers.Chunk.new(1, 3, 0, 1000)
        local selected_text = buffer:get_text(chunk)
        assert.are.equals(selected_text, table.concat({
            "With some text",
            "",
            "Oh, a paragraph!",
        }, "\n")
        )
        chunk = buffers.Chunk.new(0, 0, 10, 13)
        selected_text = buffer:get_text(chunk)
        assert.are.equals(selected_text, "buf")
    end)
    it("Adds and delete chunks correctly", function()
        local chunk = buffers.Chunk.new(1, 3, 0, 5)
        buffer:add_chunk(0x00, chunk)
        assert.are.equals(buffer.evaluated_chunks[0x00], chunk)
        buffer:delete_chunk(0x00)
        assert.are.equals(buffer.evaluated_chunks[0x00], nil)
    end)
    it("Adds diagnostics correctly", function()
        local diagnostic = buffers.Diagnostic.new("test", {}, 0x00, true)
        buffer:add_diagnostic(diagnostic)
        assert.are.equals(buffer.diagnostics[1], diagnostic)
    end)
    it("Adds results correctly", function()
        local result = buffers.Result.new(0, "text/plain", "Test output", true)
        buffer:add_result(0x00, result)
        assert.are.equals(buffer.results[0x00][1], result)
    end)
    it("Calls configuration callbacks at initialization.", function()
        local test_function = spy.new(function(buffer) end)
        buffers.on_configure_buffer(test_function)
        buffer = buffers.Buffer.new(bufnbr, true)
        assert.spy(test_function).was.called()
        assert.spy(test_function).was.called_with(buffer)
    end)
    it("Calls initialization callbacks at initialization.", function()
        local test_function = spy.new(function(buffer) end)
        buffers.on_new_buffer(test_function)
        buffer = buffers.Buffer.new(bufnbr, true)
        assert.spy(test_function).was.called()
        assert.spy(test_function).was.called_with(buffer)
    end)
    it("Updates chunks correctly after in line edit.", function()
        local chunk = buffers.Chunk.new(0, 0, 10, 13)
        local initial_text = buffer:get_text(chunk)
        buffer:add_chunk(0x00, chunk)
        vim.api.nvim_buf_set_text(bufnbr, 0, 9, 0, 9, { "beautiful ", })
        local updated = buffer:updated_chunk(chunk)
        local updated_text = buffer:get_text(updated)
        assert.are.equals(initial_text, updated_text)
    end)
    it("Detects the intersected chunks correctly.", function()
        local chunk = buffers.Chunk.new(0, 0, 10, 13)
        local non_intersecting_chunks = {
            buffers.Chunk.new(0, 0, 0, 4),
            buffers.Chunk.new(1, 3, 0, 4),
        }
        local intersecting_chunks = {
            buffers.Chunk.new(0, 0, 0, 11),
            buffers.Chunk.new(0, 0, 10, 11),
            buffers.Chunk.new(0, 1, 10, 4),
            buffers.Chunk.new(0, 1, 0, 4),
        }
        buffer:add_chunk(0x00, chunk)
        for _,c in pairs(non_intersecting_chunks) do
            buffer:add_chunk(0x00, c)
        end
        for _,c in pairs(intersecting_chunks) do
            buffer:add_chunk(0x00, c)
        end
        local detected_intersections = buffer:intersected_chunks(chunk)
        require("smuggler.log").trace("non intersecting_chunks", vim.inspect(non_intersecting_chunks), "detected_intersections", vim.inspect(detected_intersections))
        for _,registered_chunk in pairs(non_intersecting_chunks) do
            for _,detected_chunk in pairs(detected_intersections) do
                assert.are_not.same(registered_chunk, detected_chunk)
            end
        end
        require("smuggler.log").trace("intersecting_chunks", vim.inspect(intersecting_chunks), "detected_intersections", vim.inspect(detected_intersections))
        for _,registered_chunk in pairs(intersecting_chunks) do
            local matched = 0
            for _,detected_chunk in pairs(detected_intersections) do
                if registered_chunk == detected_chunk then
                    matched = matched + 1
                end
            end
            assert.is_not_true(matched == 0)
        end
    end)
end)
