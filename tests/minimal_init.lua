-- Minimal init.lua for testing with lazy.nvim and image.nvim

-- Set up paths
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

-- Bootstrap lazy.nvim if not installed
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable",
        lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

-- Setup lazy.nvim with image.nvim
require("lazy").setup({
    {
        "3rd/image.nvim",
        lazy = false,
        build = false,
        opts = {
            processor = "magick_cli",
        },
    },
})
