local mermaid = require("mermaid-preview.mermaid")

-- idk man, running with plenarybusted breaks this and I don't care enough anymore
-- to try to fix it
local img = mermaid.generate_image({ "flowchart LR", "A --> B" }, 5, 100)
assert(img ~= nil)
vim.print(img.id)

local ok, img_or_err = pcall(mermaid.generate_image, { "flowchart", "A -- B" }, 5, 100)
assert(ok)
assert(img_or_err == nil)

mermaid.generate_image({ "flowchart LR", "A --> B" }, 5, 100, function(img)
    assert(img ~= nil)
    vim.print(img.id)
end)
