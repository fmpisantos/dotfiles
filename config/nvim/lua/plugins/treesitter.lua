return {
    src = {
        "nvim-treesitter/nvim-treesitter",
        "nvim-treesitter/nvim-treesitter-context",
    },
    event = { "BufReadPost", "BufWritePost", "BufNewFile" },
    setup = function()
        require('nvim-treesitter.install').prefer_git = true
        require('nvim-treesitter.configs').setup({
            ensure_installed = { 'c', 'cpp', 'c_sharp', 'lua', 'markdown', 'xml', 'json', 'java' },
            auto_install = true,
            highlight = {
                enable = true,
                additional_vim_regex_highlighting = { "markdown" },
            },
            indent = { enable = true },
        });
    end
}
