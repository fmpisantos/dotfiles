return {
    src = "https://github.com/mbbill/undotree",
    setup = function()
        vim.keymap.set('n', "<leader>u", vim.cmd.UndotreeToggle, { desc = "Open [U]ndotree" });
    end
};
