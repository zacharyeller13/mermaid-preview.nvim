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
    local parser = vim.treesitter.get_parser(0, "markdown")
    local root = parser:parse()[1]:root()
    self.nodes = {}

    for id, node in query:iter_captures(root, 0) do
        local name = query.captures[id]
        if name == "diagram" then
            print(node, name)
            table.insert(self.nodes, node)
        end
    end
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

-- TODO: buf attach
-- onchanged update list of mermaid nodes
-- regenerate diagram if it is under the current cursor position

-- TODO: nvim-treesitter.ts_utils.memoize_by_buf_tick?
-- iter_captures?

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
---@param node? TSNode A TSNode
---@return boolean #True if node is inside a mermaid diagram code block
local function is_mermaid_diagram2(node)
    -- TODO: If cached nodes is empty, populate it
    for _, code_block in ipairs(M.nodes) do
        if vim.treesitter.is_ancestor(code_block, node) then
            print("Diagram")
            return true
        end
    end
    return false
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
    for n in node:iter_children() do
        if n:type() == "info_string" then
            return vim.treesitter.get_node_text(n, 0) == "mermaid"
        end
    end
    return false
end

M.get_code_block_root = get_code_block_root
M.is_mermaid_diagram = is_mermaid_diagram
M.is_mermaid_diagram2 = is_mermaid_diagram2

-- vim.keymap.set({ "n", "v" }, "<leader>t", function()
--     require("mermaid-preview.ts-utils"):cache_nodes()
--     local node = vim.treesitter.get_node()
--     require("mermaid-preview.ts-utils").is_mermaid_diagram2(node)
-- end)

return M
