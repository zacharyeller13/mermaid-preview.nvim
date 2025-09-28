--[[
    vim.treesitter.get_node()
    possible events for autocmd: CursorHold
    CursorHoldI
    CursorMoved (triggers very often)
    TextChanged
    TextChangedI (Triggers often)
--]]

---@class MermaidPreview.Config
---@field default_width integer Default width of preview window. May be overwritten by vim.o.columns
---@field preview_title string Title to give the preview window
---@field image_scale integer Scale to pass into mermaid-cli when generating the initial diagram preview
local config = {
    default_width = math.floor(vim.o.columns / 2),
    preview_title = "Diagram Preview",
    image_scale = 5,
}

---@class MermaidPreview
---@field image? Image From image.nvim, an instance of the renderable image
---@field tempfile? string Temp file holding the preview image
---@field _augroup integer autocmd group id
---@field window MermaidPreview.Window Window handler
local M = {
    ---@type MermaidPreview.Config
    config = config,

    image = nil,
    tempfile = nil,
}

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
                vim.print("In code block")
                -- If the preview window is already opened then we don't need to regenerate
                -- constantly
                if M.window.winid then
                    vim.print("M.window.winid not nil")
                    return
                end

                -- We only need to run this if it's not already open and generated
                local start_row, _, end_row, _ = code_block_root:range()
                -- Skip the first and last rows of the code block
                local chart_lines = vim.api.nvim_buf_get_lines(0, start_row + 1, end_row - 1, false)
                vim.print(chart_lines)
                M.generate_preview(chart_lines)
                M.render_preview()
                return
            end
            M.window.hide_preview_window()
        end,
        nested = true,
    })
end

---Generate a temporary .png file and write the preview image to it.
---@param chart_lines string[] Array of chart lines passed to stdin
function M.generate_preview(chart_lines)
    local tempfile = M.tempfile or (vim.fn.tempname() .. ".png")
    M.tempfile = tempfile
    vim.system(
        { "mmdc", "-i", "-", "-o", tempfile, "-e", "png", "-s", tostring(M.config.image_scale) },
        { stdin = chart_lines },
        function(out)
            if out.code ~= 0 then
                vim.schedule(function()
                    vim.notify("MermaidPreview: Error generating image\n" .. out.stderr, vim.log.levels.ERROR)
                end)
                return
            end
            M.image = require("image").from_file(tempfile, { width = config.default_width })
        end
    )
end

---Display the preview image in the preview window
function M.render_preview()
    -- Window closed but M.winid not nil
    if M.window.winid and not vim.api.nvim_win_is_valid(M.window.winid) then
        M.winid = nil
    end

    -- M.image is nil
    if not M.image then
        vim.notify("MermaidPreview: No preview image", vim.log.levels.WARN)
        return
    end

    -- preview window is open
    if M.window.bufnr and M.window.winid then
        M.image.window = M.window.winid
        M.image:render()
        return
    end

    -- preview window closed
    if not M.winid then
        M.image.window = M.window.open_preview_window()
        -- Sometimes rendering only partially renders, likely due to the window not being fully
        -- open yet. Delaying rendering fixes this
        vim.schedule(function()
            M.image:render()
        end)
    end
end

---@param opts? MermaidPreview.Config
M.setup = function(opts)
    vim.notify("Loaded MermaidPreview")
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})
    M._augroup = vim.api.nvim_create_augroup("MermaidPreview", { clear = true })
    M.window = require("mermaid-preview.window-manager")
    M.window.title = M.config.preview_title
    setup_autocmds()
end

return M
