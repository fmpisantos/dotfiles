return {
    src = {"stevearc/oil.nvim", "nvim-tree/nvim-web-devicons"},
    setup = function()
        require('oil').setup {
            keymaps = {
                ["<C-h>"] = false,
                ["<Tab>"] = "actions.preview",
                ["<C-v>"] = "actions.select_vsplit",
            },
            view_options = {
                show_hidden = true,
                is_hidden_file = function(name, _)
                    return vim.startswith(name, ".")
                end,
                is_always_hidden = function(_, _)
                    return false
                end,
            },
            skip_confirm_for_simple_edits = true,
        }
        vim.keymap.set("n", "-", require('oil').open, { noremap = true, silent = true, desc = "Open file" });
        vim.keymap.set("n", "<leader>pv", require('.oil').open,
            { noremap = true, silent = true, desc = "Open parent directory" });
    end
}
