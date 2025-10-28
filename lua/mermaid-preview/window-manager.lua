---@class MermaidPreview.Window
---@field augroup integer autocmd group id
---@field title string Title of window
---@field width integer Width of the window
---@field bufnr? integer Active preview bufnr
---@field winid? integer Active preview winid
local M = {
    augroup = vim.api.nvim_create_augroup("MermaidPreview.Window", { clear = true }),
}
M.__index = M

---Create a new preview buffer
---@param title string Title of preview buffer
---@return integer #bufid for new buffer
local function create_buf(title)
    local bufnr = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_buf_set_name(bufnr, title)
    vim.api.nvim_set_option_value("modifiable", false, {
        buf = bufnr,
    })
    return bufnr
end

---Open a new preview window in a vertical split.
---If a preview buffer already exists, reuse it
---otherwise create a new one
---@return integer #id of newly opened window
function M:open_preview_window()
    -- If a window is already open, don't do anything
    if self.winid then
        return self.winid
    end

    -- First make sure the preview buffer exists
    local bufnr = self.bufnr
    if not bufnr then
        bufnr = create_buf(self.title)
        self.bufnr = bufnr

        -- Create an autocmd to set M.winid = nil when this buffer is hidden
        -- For instance by focusing and doing `:q`
        vim.api.nvim_create_autocmd("BufHidden", {
            buffer = self.bufnr,
            group = self.augroup,
            callback = function(ev)
                self.winid = nil
            end,
            desc = "Invalidate winid on buffer hidden",
        })
    end

    local width = self.width
    local winid = vim.api.nvim_open_win(bufnr, false, {
        split = "right",
        focusable = false,
        style = "minimal",
        width = width,
    })
    self.winid = winid
    return winid
end

---Hide open preview window
function M:hide_preview_window()
    if self.winid == nil then
        return
    end

    if vim.api.nvim_win_is_valid(self.winid) then
        vim.api.nvim_win_hide(self.winid)
    end
    self.winid = nil
end

local default_opts = {
    title = "Diagram Preview",
    width = math.floor(vim.o.columns / 2),
}

---Create new preview window instance
---@param opts? {title: string?, width: integer?}
---@return MermaidPreview.Window
M.new = function(opts)
    opts = vim.tbl_deep_extend("force", default_opts, opts or {})
    local instance = setmetatable({ title = opts.title, width = opts.width }, M)

    return instance
end

return M
