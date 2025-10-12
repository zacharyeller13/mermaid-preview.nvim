local window = require("mermaid-preview.window-manager")
local plenary = require("plenary.busted")

---@type MermaidPreview.Window
local win

describe("mermaid-preview", function()
    -- Reset the window so tests get a clean slate
    before_each(function()
        if win and win.bufnr then
            vim.api.nvim_buf_delete(win.bufnr, { force = true })
        end
        win = window.new()
    end)

    it("can create new preview window", function()
        local winid = win:open_preview_window()

        assert.equals(winid, win.winid)
        assert.True(vim.api.nvim_buf_is_valid(win.bufnr))
        assert.True(vim.api.nvim_win_is_valid(win.winid))
    end)

    it("opens window with default width", function()
        local expected_width = vim.o.columns / 2

        local winid = win:open_preview_window()
        assert.equals(vim.api.nvim_win_get_width(winid), expected_width)
    end)

    it("opens window with configured title", function()
        local expected_title = "Test"
        win = window.new({ title = "Test" })

        win:open_preview_window()
        local bufname = vim.fn.bufname(win.bufnr)

        assert.equals(bufname, expected_title)
    end)
    --
    it("creates preview buffer with required BufHidden autocmd", function()
        win:open_preview_window()
        local autocmds = vim.api.nvim_get_autocmds({
            group = "MermaidPreview.Window",
            event = "BufHidden",
            buffer = win.bufnr,
        })
        assert.equals(#autocmds, 1)
    end)

    it("can hide open window and preserve buffer", function()
        win:open_preview_window()
        win:hide_preview_window()

        local bufinfo = vim.fn.getbufinfo(win.bufnr)[1]

        assert.True(vim.api.nvim_buf_is_valid(win.bufnr))
        assert.equals(bufinfo.hidden, 1)
        assert.is_nil(win.winid)
    end)

    it("opens exactly one preview window", function()
        local winid = win:open_preview_window()
        local winid2 = win:open_preview_window()

        assert.equals(winid, winid2)
        assert.equals(win.winid, winid)
        assert.equals(win.winid, winid2)
    end)
end)
