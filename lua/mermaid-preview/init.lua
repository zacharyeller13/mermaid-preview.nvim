--[[
    vim.treesitter.get_node()
    possible events for autocmd: CursorHold
    CursorHoldI
    CursorMoved (triggers very often)
    TextChanged
    TextChangedI (Triggers often)
--]]
-- FIX: Loads on hover because info is "rendered" in hovers

local ts_utils = require("mermaid-preview.ts-utils")

---@class MermaidPreview.Config
---@field default_width integer Default width of preview window. May be overwritten by vim.o.columns
---@field preview_title string Title to give the preview window
---@field image_scale integer Scale to pass into mermaid-cli when generating the initial diagram preview
---@field use_autocmds boolean Use autocmds to show/hide mermaid preview automatically on cursor enter/exit
local config = {
    default_width = math.floor(vim.o.columns / 2),
    preview_title = "Diagram Preview",
    image_scale = 5,
    use_autocmds = false,
}

---@class MermaidPreview
---@field _augroup integer autocmd group id
---@field image? Image From image.nvim, an instance of the renderable image
---@field tempfile? string Temp file holding the preview image
---@field window MermaidPreview.Window Window handler
---@field nodes table<string, TSNode>
local M = {
    ---@type MermaidPreview.Config
    config = config,

    image = nil,
    tempfile = nil,
    nodes = {},
}

---Display preview of chart at cursor
function M.preview()
    local node = vim.treesitter.get_node()
    local is_mermaid = ts_utils.is_mermaid_diagram(node)
    vim.notify("MermaidPreview: " .. tostring(is_mermaid))
    if is_mermaid then
        -- FIX: This isn't correct because of a couple node areas that are in a mermaid
        -- but not technically the correct text: "```", "mermaid", "```"
        local lines = vim.treesitter.get_node_text(node, 0)
        vim.notify("MermaidPreview: " .. lines)
        local img = require("mermaid-preview.mermaid").generate_image(lines, config.image_scale, config.default_width)
        if not img then
            vim.notify("MermaidPreview: No image created")
            return
        end
        M.window:show(img)
    end
end

---@param opts? MermaidPreview.Config
M.setup = function(opts)
    vim.notify("Loaded MermaidPreview")
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})
    M._augroup = vim.api.nvim_create_augroup("MermaidPreview", { clear = true })
    M.window = require("mermaid-preview.window").new({
        title = M.config.preview_title,
        width = M.config.default_width,
    })

    -- onchanged update list of mermaid nodes
    -- regenerate diagram if it is under the current cursor position
    vim.api.nvim_buf_attach(0, false, {
        on_lines = function()
            -- Re-cache nodes because they've probably moved
            ts_utils:cache_nodes()

            -- TODO: Do we schedule instead?
            -- Seemingly no, b/c we need the nodes cached correctly for the next check
            -- Maybe schedule the entire block here?
            -- vim.schedule(function()
            --     M:cache_nodes()
            -- end)

            local node = vim.treesitter.get_node()
            if ts_utils.is_mermaid_diagram(node) then
                vim.notify("MermaidPreview: " .. node:type())
                -- TODO: Regenerate diagram for current cursor, only if editing a diagram
            end
        end,
    })
end

return M
