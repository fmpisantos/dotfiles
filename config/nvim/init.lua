-- Leader
vim.g.mapleader = " ";
vim.g.maplocalleader = " "

require("set")
require("netrw_config")
require("remap")

if vim.env.FROM_WEZTERM == "1" then
    return
end

vim.pack.add({ "https://github.com/fmpisantos/pack.nvim" })
local pack = require("pack")

require("plugins.extensions");

pack.require("plugins");
pack.require("plugins.myPlugins.init");
pack.install()

-- Force wrap
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    pattern = "*/Notes/PersonalNotes/notes/notesForInterview(story).md",
    callback = function()
        vim.opt_local.wrap = true
    end,
})
