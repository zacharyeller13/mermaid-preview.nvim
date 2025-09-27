---@class MermaidPreview.Window
---@field augroup integer autocmd group id
---@field title string Title of window
---@field width integer Width of the window
---@field bufnr? integer Active preview bufnr
---@field winid? integer Active preview winid
local M = {
    augroup = vim.api.nvim_create_augroup("MermaidPreview.Window", { clear = true }),
}

---Create a new preview buffer
---@return integer #bufid for new buffer
local function create_buf()
    local bufnr = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_buf_set_name(bufnr, M.title)
    vim.api.nvim_set_option_value("modifiable", false, {
        buf = bufnr,
    })
    return bufnr
end

---Open a new preview window in a vertical split.
---If a preview buffer already exists, reuse it
---otherwise create a new one
---@return integer #id of newly opened window
function M.open_preview_window()
    -- If a window is already open, don't do anything
    if M.winid then
        return M.winid
    end

    -- First make sure the preview buffer exists
    local bufnr = M.bufnr
    if not bufnr then
        bufnr = create_buf()
        M.bufnr = bufnr

        -- Create an autocmd to set M.winid = nil when this buffer is hidden
        -- For instance by focusing and doing `:q`
        vim.api.nvim_create_autocmd("BufHidden", {
            buffer = M.bufnr,
            group = M.augroup,
            callback = function(ev)
                M.winid = nil
            end,
            desc = "Invalidate winid on buffer hidden",
        })
    end

    local width = M.width
    local winid = vim.api.nvim_open_win(bufnr, false, {
        split = "right",
        focusable = false,
        style = "minimal",
        width = width,
    })
    M.winid = winid
    return winid
end

---Hide open preview window
function M.hide_preview_window()
    if M.winid == nil then
        return
    end

    if vim.api.nvim_win_is_valid(M.winid) then
        vim.api.nvim_win_hide(M.winid)
    end
    -- Always set M.winid to nil
    M.winid = nil
end

return M
