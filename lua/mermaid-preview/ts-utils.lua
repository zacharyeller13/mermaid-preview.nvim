---@class MermaidPreview.TSNodes
---@field nodes TSNode[] List of mermaid diagram TSNodes
local M = {
    nodes = {},
}

local query = vim.treesitter.query.parse(
    "markdown",
    [[(fenced_code_block
        (info_string) @lang
        (#eq? @lang "mermaid")) @diagram]]
)

---Add captured mermaid diagram nodes to nodes list
function M:cache_nodes()
    local parser, err = vim.treesitter.get_parser(0, "markdown")
    if err then
        vim.notify("MermaidPreview.ts-utils: Couldn't get markdown parser " .. err, vim.log.levels.WARN)
        return
    end
    assert(parser, "parser should not be nil")

    local trees = parser:parse()
    if not trees then
        vim.notify("MermaidPreview.ts-utils: tree not parsed", vim.log.levels.WARN)
        return
    end

    local root = trees[1]:root()
    local nodes = {}

    for id, node in query:iter_captures(root, 0) do
        local name = query.captures[id]
        if name == "diagram" then
            table.insert(nodes, node)
        end
    end
    self.nodes = nodes
end

function M:print_nodes()
    for _, node in ipairs(self.nodes) do
        print(node:type(), node:range())
    end
end

-- TODO: On buf enter (not necessarily the autocmd), parse and mmdc all mermaid diagrams
-- cache them as a list of nodes? or maybe a key<range>, value<text> table?
-- A different vim.fn.tempname() for each diagram
-- add nodes to list of nodes

-- TODO: nvim-treesitter.ts_utils.memoize_by_buf_tick?
-- Instead of doing M.nodes; could just memoize cache_nodes as a get_nodes func
-- and return the table instead of saving it to a field

---Check if node is in a mermaid diagram
---@param node? TSNode A TSNode
---@return boolean #True if node is inside a mermaid diagram code block
local function is_mermaid_diagram(node)
    if not node then
        return false
    end

    -- FIX: Is this actually necessary here? We should probably never be hitting this
    -- function without having already cached at least once
    if #M.nodes == 0 then
        M:cache_nodes()
    end

    for _, code_block in ipairs(M.nodes) do
        if vim.treesitter.is_ancestor(code_block, node) then
            vim.notify("MermaidPreview.ts-utils: In mermaid diagram", vim.log.levels.DEBUG)
            return true
        end
    end
    return false
end

-- TODO: buf attach
-- onchanged update list of mermaid nodes
-- regenerate diagram if it is under the current cursor position
vim.api.nvim_buf_attach(0, false, {
    on_lines = function()
        -- Re-cache nodes because they've probably moved
        M:cache_nodes()

        -- TODO: Do we schedule instead?
        -- Seemingly no, b/c we need the nodes cached correctly for the next check
        -- Maybe schedule the entire block here?
        -- vim.schedule(function()
        --     M:cache_nodes()
        -- end)

        -- TODO: Regenerate diagram for current cursor, only if editing a diagram
        local node = vim.treesitter.get_node()
        if is_mermaid_diagram(node) then
        end
    end,
})

M.is_mermaid_diagram = is_mermaid_diagram

-- vim.keymap.set({ "n", "v" }, "<leader>t", function()
--     require("mermaid-preview.ts-utils"):cache_nodes()
--     local node = vim.treesitter.get_node()
--     require("mermaid-preview.ts-utils").is_mermaid_diagram2(node)
-- end)

return M
