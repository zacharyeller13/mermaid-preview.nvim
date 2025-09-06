# mermaid-preview.nvim

A plugin to preview mermaid diagrams in a split window

## Table of Contents
<!-- mtoc-start -->

* [Documentation](#documentation)
* [Dependencies](#dependencies)
* [Installation](#installation)
  * [lazy](#lazy)
* [Default Config](#default-config)
* [TODOs](#todos)

<!-- mtoc-end -->
## Documentation

See `:help mermaid-preview.nvim`

## Dependencies

- **Neovim 0.11** or later
- [mermaid-cli](https://github.com/mermaid-js/mermaid-cli) - For rendering mermaid diagrams from text
- [image.nvim](https://github.com/3rd/image.nvim) and related dependencies - Performs the heavy-lifting of image rendering

## Installation

### lazy

```lua
{
    "zacharyeller13/mermaid-preview.nvim",
    dependencies = {
        {
            "3rd/image.nvim",
            build = false,
            opts = {
                processor = "magick_cli",
            },
        },
    },
    ft = "markdown",
    opts = {}
}
```

## Default Config

```lua
---@class MermaidPreview.Config
---@field default_width integer Default width of preview window. May be overwritten by vim.o.columns
---@field preview_title? string Title to give the preview window
{
    default_width = 100,
    preview_title = "Diagram Preview",
}
```


## TODOs

- [x] vertical split opening
- [ ] rendering
- [ ] supporting more than 1 diagram and more than 1 markdown file in the same session
- [ ] autocmds
    - [ ] `CursorMoved`
    - [ ] `CursorMovedI`?
- [ ] vimdocs
- [ ] tests
- [ ] health
- [ ] readme

