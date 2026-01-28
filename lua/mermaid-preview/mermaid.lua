---@class MermaidPreview.Mermaid
local M = {}

---Generate a temporary .png file, write the diagram img into it, load into an Image object.
---If image_callback is provided, run asynchronously and vim.schedule the callback with the resulting
---Image. Otherwise, run synchronously and return the Image
---@param chart_lines string[] Array of chart lines passed to stdin
---@param image_scale integer Scale factor for output image
---@param width integer Width of image to display
---@param image_callback? fun(img: Image) Function to call on the resulting Image. If nil, Image will be returned instead
---@return Image?
function M.generate_image(chart_lines, image_scale, width, image_callback)
    local tempfile = vim.fn.tempname() .. ".png"
    local image_api = require("image")
    local mmdc = { "mmdc", "-i", "-", "-o", tempfile, "-e", "png", "-s", tostring(image_scale) }

    if image_callback then
        vim.system(mmdc, { stdin = chart_lines }, function(out)
            if out.code ~= 0 then
                vim.schedule(function()
                    vim.notify("MermaidPreview: Error generating image\n" .. out.stderr, vim.log.levels.ERROR)
                end)
                return
            end
            local img = image_api.from_file(tempfile, { width = width })
            vim.schedule(function()
                if not img then
                    vim.notify("MermaidPreview: No image sourced at\n" .. tempfile, vim.log.levels.WARN)
                    return
                end
                image_callback(img)
            end)
        end)
        return nil
    end

    local out = vim.system(mmdc, { stdin = chart_lines }):wait()
    if out.code ~= 0 then
        vim.notify("MermaidPreview: Error generating image\n" .. out.stderr, vim.log.levels.ERROR)
        return nil
    end
    return image_api.from_file(tempfile, { width = width })
end

return M
