local preview = require("mermaid-preview")

describe("mermaid-preview", function()
    before_each(function()
        if preview.bufnr then
            vim.api.nvim_buf_delete(preview.bufnr, { force = true })
            preview.bufnr = nil
        end
    end)

    it("works with default setup", function()
        preview.setup()
        _ = preview.open_preview_window()
        local bufname = vim.fn.bufname(preview.bufnr)
        local bufinfo = vim.fn.getbufinfo(preview.bufnr)
        assert.equals(preview.config.preview_title, "Diagram Preview")
        assert.equals(bufname, "Diagram Preview")
    end)

    it("works with custom setup", function()
        preview.setup({ preview_title = "Test" })
        _ = preview.open_preview_window()
        local bufname = vim.fn.bufname(preview.bufnr)
        local bufinfo = vim.fn.getbufinfo(preview.bufnr)
        assert.equals(preview.config.preview_title, "Test")
        assert.equals(bufname, "Test")
    end)

    it("can create new preview window", function()
        local winid = preview.open_preview_window()
        assert.equals(winid, preview.winid)
        assert.True(vim.api.nvim_buf_is_valid(preview.bufnr))
        assert.True(vim.api.nvim_win_is_valid(preview.winid))
    end)

    it("preview buffer has autocmds", function()
        _ = preview.open_preview_window()
        local autocmds = vim.api.nvim_get_autocmds({
            group = "MermaidPreview",
            event = "BufHidden",
            buffer = preview.bufnr,
        })
        assert.equals(#autocmds, 1)
    end)
end)
