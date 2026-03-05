return {
    src = "tpope/vim-fugitive",
    setup = function()
        vim.api.nvim_create_autocmd("FileType", {
            pattern = "git*",
            callback = function()
                vim.wo.foldmethod = "syntax"
            end,
        })
        vim.keymap.set("n", "<leader>zM", ":localset foldmethod=syntax<CR>zM", { desc = "Fold all git" });
        vim.keymap.set("n", "<leader>gs", vim.cmd.Git, { desc = "[G]it [S]tart" });
        vim.keymap.set("n", "<leader>gs", vim.cmd.Git, { desc = "Git commit" });
        vim.keymap.set("n", "<leader>gd", "<cmd>:Gdiff<CR>", { desc = "Git difference" });
        vim.keymap.set("n", "<leader>gh", "<cmd>diffget //2<CR>", { desc = "Use left" });
        vim.keymap.set("n", "gh", "<cmd>diffget //2<CR>", { desc = "Use left" });
        vim.keymap.set("n", "<leader>gl", "<cmd>diffget //3<CR>", { desc = "Use righ" });
        vim.keymap.set("n", "gl", "<cmd>diffget //3<CR>", { desc = "Use righ" });
        vim.keymap.set("n", "<leader>gc", "<cmd>:Git commit<CR>", { desc = "Git commit" });
        vim.keymap.set("n", "<leader>gp", "<cmd>:Git push -u origin<CR>", { desc = "Git commit" });
        vim.keymap.set("n", "<leader>gb", "<cmd>: Git blame<CR>", { desc = "Git blame" });
    end
}
