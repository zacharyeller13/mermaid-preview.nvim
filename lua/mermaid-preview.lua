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
    default_width = vim.o.columns / 2,
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
local function create_buf()
    local bufnr = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_buf_set_name(bufnr, M.config.preview_title)
    vim.api.nvim_set_option_value("modifiable", false, {
        buf = bufnr,
    })
    return bufnr
end

---If node is in a `fenced_code_block`, find that root node
---@param node? TSNode
---@return TSNode? #`fenced_code_block` root node if there is one
local function get_code_block_root(node)
    if node == nil then
        return nil
    end

    while node do
        if node:type() == "fenced_code_block" then
            return node
        end
        node = node:parent()
    end
    return nil
end

---Check if node is in a mermaid diagram
---@param node? TSNode A `fenced_code_block` TSNode
---@return boolean #True if node is inside a mermaid diagram code block
local function is_mermaid_diagram(node)
    if node == nil then
        return false
    end
    if node:type() ~= "fenced_code_block" then
        return false
    end
    for n, _ in node:iter_children() do
        if n:type() == "info_string" then
            return vim.treesitter.get_node_text(n, 0) == "mermaid"
        end
    end
    return false
end

local function setup_autocmds()
    vim.api.nvim_create_autocmd("CursorMoved", {
        pattern = { "*.md" },
        group = M._augroup,
        callback = function()
            local node = vim.treesitter.get_node()

            local code_block_root = get_code_block_root(node)
            if code_block_root and is_mermaid_diagram(code_block_root) then
                M.open_preview_window()

                local start_row, _, end_row, _ = code_block_root:range()
                -- Skip the first and last rows of the code block
                local chart_lines = vim.api.nvim_buf_get_lines(0, start_row + 1, end_row - 1, false)
                M.generate_preview(chart_lines)
                M.render_preview()
                return
            end
            M.hide_preview_window()
        end,
        nested = true,
    })
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
            group = M._augroup,
            callback = function(ev)
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
    end
    -- Always set M.winid to nil
    M.winid = nil
end

---Generate a temporary .png file and write the preview image to it.
---@param chart_lines string[] Array of chart lines passed to stdin
function M.generate_preview(chart_lines)
    local tempfile = M.tempfile or (vim.fn.tempname() .. ".png")
    M.tempfile = tempfile
    -- Scale 5 seems to be a reasonable size to generate a higher quality initial image
    vim.system({ "mmdc", "-i", "-", "-o", tempfile, "-e", "png", "-s", "5" }, { stdin = chart_lines }, function(out)
        if out.code ~= 0 then
            vim.schedule(function()
                vim.notify("MermaidPreview: Error generating image\n" .. out.stderr, vim.log.levels.ERROR)
            end)
            return
        end
        M.image = require("image").from_file(tempfile, { width = config.default_width })
    end)
end

---Display the preview image in the preview window
function M.render_preview()
    -- Window closed but M.winid not nil
    if not vim.api.nvim_win_is_valid(M.winid) then
        M.winid = nil
    end

    -- M.image is nil
    if not M.image then
        vim.notify("MermaidPreview: No preview image", vim.log.levels.WARN)
        return
    end

    -- preview window is open
    if M.bufnr and M.winid then
        M.image.window = M.winid
        M.image:render()
        return
    end

    -- preview window closed
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
    setup_autocmds()
end

-- local m = require("mermaid-preview")
-- m.open_preview_window()
-- local m = require("mermaid-preview")
-- m.hide_preview_window()
-- vim.print(m.winid)
-- m.render_preview()
-- m.generate_preview({ "flowchart LR", "A --> B", "B --> A" })

return M
