--[[
The whole point is to figure out, are we inside of a mermaid diagram code block?
    vim.treesitter.get_node():parent()
    TSNode:parent():type() == "fenced_code_block"
    (language) == "mermaid"
    ignoring injections is very helpful here so we don't get the extra
    mermaid tree

      • {opts}  (`table?`) Optional keyword arguments:
                • {bufnr} (`integer?`) Buffer number (nil or 0 for current
                  buffer)
                • {pos} (`[integer, integer]?`) 0-indexed (row, col) tuple.
                  Defaults to cursor position in the current window. Required
                  if {bufnr} is not the current buffer
                • {lang} (`string?`) Parser language. (default: from buffer
                  filetype)
                • {ignore_injections} (`boolean?`) Ignore injected languages
                  (default true)
                • {include_anonymous} (`boolean?`) Include anonymous nodes
                  (default false)


    possible events for autocmd: CursorHold
    CursorHoldI
    CursorMoved (triggers very often)
    TextChanged
    TextChangedI (Triggers often)
--]]

---@class MermaidPreview.Config
---@field default_width integer Default width of preview window. May be overwritten by vim.o.columns
---@field preview_title? string Title to give the preview window
local config = {
    default_width = 100,
    preview_title = "Diagram Preview",
}

---@class MermaidPreview
---@field image? Image From image.nvim, an instance of the renderable image
---@field bufnr? integer Active preview bufnr
---@field winid? integer Active preview winid
---@field tempfile? string Temp file holding the preview image
---@field _augroup integer autocmd group id
local M = {
    ---@type MermaidPreview.Config
    config = config,

    image = nil,
    bufnr = nil,
    winid = nil,
    tempfile = nil,
}

---Create a new preview buffer
---@return integer #bufid for new buffer
function M._create_buf()
    local bufnr = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_buf_set_name(bufnr, M.config.preview_title)
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
    -- First make sure the preview buffer exists
    local bufnr = M.bufnr
    if not bufnr then
        bufnr = M._create_buf()
        M.bufnr = bufnr

        -- Create an autocmd to set M.winid = nil when this buffer is hidden
        vim.api.nvim_create_autocmd("BufHidden", {
            buffer = M.bufnr,
            group = M._augroup,
            callback = function(ev)
                vim.print(vim.inspect(ev))
                M.winid = nil
            end,
            desc = "Invalidate winid on buffer hidden",
        })
    end

    local width = (M.image or {}).image_width or M.config.default_width
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
    else
        -- If for some reason winid is not nil but also isn't valid
        -- we need to reset it
        M.winid = nil
    end
end

---Generate a temporary .png file and write the preview image to it.
---@param chart_lines string[] Array of chart lines passed to stdin
function M.generate_preview(chart_lines)
    local tempfile = M.tempfile or (vim.fn.tempname() .. ".png")
    M.tempfile = tempfile
    vim.system({ "mmdc", "-i", "-", "-o", tempfile, "-e", "png" }, { stdin = chart_lines }, function(out)
        if out.code ~= 0 then
            vim.schedule(function()
                vim.notify("MermaidPreview: Error generating image\n" .. out.stderr, vim.log.levels.ERROR)
            end)
            return
        end
        M.image = require("image").from_file(tempfile)
    end)
end

---Display the preview image in the preview window
function M.render_preview()
    -- Case window closed but M.winid not nil
    if not vim.api.nvim_win_is_valid(M.winid) then
        M.winid = nil
    end

    -- Case M.image is nil
    if not M.image then
        vim.notify("MermaidPreview: No preview image", vim.log.levels.WARN)
        return
    end

    -- Case preview window is open
    if M.bufnr and M.winid then
        M.image.window = M.winid
        M.image:render()
        return
    end

    -- Case preview window closed.
    if not M.winid then
        M.image.window = M.open_preview_window()
        M.image:render()
    end
end

---@param opts? MermaidPreview.Config
M.setup = function(opts)
    vim.notify("Loaded MermaidPreview")
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})
    M._augroup = vim.api.nvim_create_augroup("MermaidPreview", { clear = true })
end

-- local m = require("mermaid-preview")
-- vim.print(m.winid)
-- m.open_preview_window()
-- m.render_preview()
-- m.generate_preview({ "flowchart LR", "A --> B", "B --> A" })

return M
