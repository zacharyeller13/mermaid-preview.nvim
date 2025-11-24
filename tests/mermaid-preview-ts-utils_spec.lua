local ts_utils = require("mermaid-preview.ts-utils")
local plenary = require("plenary.busted")

local test_lines = vim.split(
    [[
# Head 1

```mermaid
flowchart LR
    A --> B
    B --> A
```

```mermaid
flowchart RL
    A --> B
    B --> C
    C --> A
```

```bash
ls
```
]],
    "\n"
)

---@type integer
local buf = vim.api.nvim_create_buf(false, false)

describe("mermaid-preview.ts-utils", function()
    -- Reset the buffer so tests get a clean slate
    before_each(function()
        vim.api.nvim_buf_set_lines(buf, 0, 0, false, test_lines)
        vim.api.nvim_set_current_buf(buf)
        vim.treesitter.get_parser(buf, "markdown"):parse()
    end)

    it("can cache nodes", function()
        assert.True(#ts_utils.nodes == 0)

        ts_utils:cache_nodes()
        assert.True(#ts_utils.nodes > 0)
    end)

    it("can identify a mermaid diagram", function()
        vim.api.nvim_win_set_cursor(0, { 4, 1 })
        local node = vim.treesitter.get_node()

        assert.True(ts_utils.is_mermaid_diagram(node))
    end)
end)
