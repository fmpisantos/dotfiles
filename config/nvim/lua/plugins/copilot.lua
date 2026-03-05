return {
    src = "CopilotC-Nvim/CopilotChat.nvim",
    deps = {
        "zbirenbaum/copilot.lua",
    },
    setup = function()
        local copilot = require("copilot")

        copilot.setup({
            suggestion = {
                enabled = true,
                auto_trigger = true,
                keymap = {
                    accept = false,
                    accept_word = false,
                    accept_line = false,
                    next = false,
                    prev = false,
                    dismiss = false,
                },
            },
            panel = {
                enabled = false,
            },
        })

        require("CopilotChat").setup()

        vim.keymap.set("n", "<C-c><C-c>", "<cmd>CopilotChat<CR>", { noremap = true, silent = true })
        vim.keymap.set("i", "<C-c><C-a>", function() require("copilot.suggestion").accept() end,
            { noremap = true, silent = true })
        vim.keymap.set("i", "<C-c><C-l>", function() require("copilot.suggestion").accept_line() end,
            { noremap = true, silent = true })
        vim.keymap.set("i", "<C-c><C-w>", function() require("copilot.suggestion").accept_word() end,
            { noremap = true, silent = true })
        vim.keymap.set("i", "<C-c><C-n>", function() require("copilot.suggestion").next() end,
            { noremap = true, silent = true })
        vim.keymap.set("i", "<C-c><C-p>", function() require("copilot.suggestion").prev() end,
            { noremap = true, silent = true })
        vim.keymap.set("i", "<C-c><C-d>", function() require("copilot.suggestion").dismiss() end,
            { noremap = true, silent = true })
        vim.keymap.set("i", "<C-c><C-s>", function() require("copilot.suggestion").toggle_auto_trigger() end,
            { noremap = true, silent = true })
        vim.keymap.set("n", "<C-c><C-p>", "<cmd>Copilot panel<CR>", { noremap = true, silent = true })
    end,
}
