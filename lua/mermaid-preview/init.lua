--[[
    vim.treesitter.get_node()
    possible events for autocmd: CursorHold
    CursorHoldI
    CursorMoved (triggers very often)
    TextChanged
    TextChangedI (Triggers often)
--]]
-- FIX: Loads on hover because info is "rendered" in hovers

---@param message any
local function notify(message)
    if type(message) ~= "string" then
        message = vim.inspect(message)
    end
    vim.system({ "hyprctl", "notify", "-1", "1000", "rgb(ff1ea3)", message })
end

local ts_utils = require("mermaid-preview.ts-utils")

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
---@field nodes table<string, TSNode>
local M = {
    ---@type MermaidPreview.Config
    config = config,

    image = nil,
    tempfile = nil,
    nodes = {},
}

local function setup_autocmds()
    vim.api.nvim_create_autocmd("CursorMoved", {
        pattern = { "*.md" },
        group = M._augroup,
        callback = function()
            if DEBUG then
                notify(M.window)
                if M.image then
                    notify(M.image.path)
                end
            end
            local node = vim.treesitter.get_node()

            local code_block_root = ts_utils.get_code_block_root(node)
            if code_block_root and ts_utils.is_mermaid_diagram(code_block_root) then
                if DEBUG then
                    notify("In code block")
                end
                -- If the preview window is already opened then we don't need to regenerate
                -- constantly
                -- TODO: May need to regenerate in the case we switch from 1 diagram
                -- to another in the same cursor move
                if M.window.winid then
                    notify("M.window.winid not nil")
                    return
                end

                -- We only need to run this if it's not already open and generated
                local start_row, _, end_row, _ = code_block_root:range()
                -- Skip the first and last rows of the code block
                local chart_lines = vim.api.nvim_buf_get_lines(0, start_row + 1, end_row - 1, false)
                if DEBUG then
                    notify(chart_lines)
                end
                M.generate_preview(chart_lines)
                return
            end
            M.window:hide_preview_window()
        end,
        nested = true,
    })
end

---Generate a temporary .png file and write the preview image to it.
---@param chart_lines string[] Array of chart lines passed to stdin
function M.generate_preview(chart_lines)
    local tempfile = M.tempfile or (vim.fn.tempname() .. ".png")
    -- local tempfile = vim.fn.tempname() .. ".png"
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
            vim.schedule(M.render_preview)
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
        M.image.window = M.window:open_preview_window()
        -- Sometimes rendering only partially renders, likely due to the window not being fully
        -- open yet. Delaying rendering with a specific duration seems to fix this
        vim.defer_fn(function()
            M.image:render()
        end, 100)
    end
end

---@param opts? MermaidPreview.Config
M.setup = function(opts)
    vim.notify("Loaded MermaidPreview")
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})
    M._augroup = vim.api.nvim_create_augroup("MermaidPreview", { clear = true })
    M.window = require("mermaid-preview.window-manager")
    M.window.title = M.config.preview_title

    -- vim.api.nvim_buf_attach(0, false, {
    --     on_lines = function(...) end,
    -- })

    -- setup_autocmds()
end

return M
