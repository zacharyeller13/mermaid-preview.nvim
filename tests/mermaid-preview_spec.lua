local preview = require("mermaid-preview")

describe("mermaid-preview", function()
    before_each(function()
        if preview.window and preview.window.bufnr then
            vim.api.nvim_buf_delete(preview.window.bufnr, { force = true })
            preview.window.bufnr = nil
        end
        -- Typically the gui is going to be larger than default 80
        -- vim.o.columns = 160
    end)

    it("works with default setup", function()
        local expected_width = vim.o.columns / 2
        local expected_title = "Diagram Preview"
        preview.setup()

        assert.equals(preview.config.preview_title, expected_title)
        assert.equals(preview.config.default_width, expected_width)
    end)

    it("works with custom setup", function()
        local expected_width = 150
        local expected_title = "Test"
        preview.setup({ preview_title = expected_title, default_width = expected_width })

        assert.equals(preview.config.preview_title, expected_title)
        assert.equals(preview.config.default_width, expected_width)
    end)

    it("can create new preview window", function()
        local winid = preview.window.open_preview_window()
        assert.equals(winid, preview.window.winid)
        assert.True(vim.api.nvim_buf_is_valid(preview.window.bufnr))
        assert.True(vim.api.nvim_win_is_valid(preview.window.winid))
    end)

    it("opens window with default width", function()
        local expected_width = vim.o.columns / 2
        preview.setup({ default_width = expected_width })

        local winid = preview.window.open_preview_window()
        assert.equals(vim.api.nvim_win_get_width(winid), expected_width)
    end)

    it("opens window with configured title", function()
        local expected_title = "Test"
        preview.setup({ preview_title = "Test" })

        _ = preview.window.open_preview_window()
        local bufname = vim.fn.bufname(preview.window.bufnr)

        assert.equals(bufname, expected_title)
    end)

    it("creates preview buffer with required autocmds", function()
        _ = preview.window.open_preview_window()
        local autocmds = vim.api.nvim_get_autocmds({
            group = "MermaidPreview.Window",
            event = "BufHidden",
            buffer = preview.window.bufnr,
        })
        assert.equals(#autocmds, 1)
    end)

    it("can hide open window and preserve buffer", function()
        preview.setup()

        _ = preview.window.open_preview_window()
        preview.window.hide_preview_window()

        local bufinfo = vim.fn.getbufinfo(preview.window.bufnr)[1]

        assert.True(vim.api.nvim_buf_is_valid(preview.window.bufnr))
        assert.equals(bufinfo.hidden, 1)
        assert.equals(preview.window.winid, nil)
    end)

    it("opens exactly one preview window", function()
        local winid = preview.window.open_preview_window()
        local winid2 = preview.window.open_preview_window()

        assert.equals(winid, winid2)
        assert.equals(preview.window.winid, winid)
        assert.equals(preview.window.winid, winid2)
    end)
end)
