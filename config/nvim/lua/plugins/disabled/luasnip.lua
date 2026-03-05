return {
    src = "L3MON4D3/LuaSnip",
    -- version = "v2.*",
    -- build = "make install_jsregexp", -- optional, for regex snippets
    event = { "BufRead", "BufWritePost", "BufNewFile" },
    setup = function()
        local ls = require("lua.plugins.disabled.luasnip")
        ls.setup({ enable_autosnippets = true, })
        require("luasnip.loaders.from_lua").load({ paths = "~/.config/nvim/snippets/" })

        vim.keymap.set({ "i" }, "<C-e>", ls.expand, { silent = true })
        vim.keymap.set({ "i", "s" }, "<C-J>", function() ls.jump(1) end, { silent = true })
        vim.keymap.set({ "i", "s" }, "<C-K>", function() ls.jump(-1) end, { silent = true })
    end
}
