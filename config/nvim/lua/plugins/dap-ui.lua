return {
    src = {
        "rcarriga/nvim-dap-ui",
        "mfussenegger/nvim-dap",
        "nvim-neotest/nvim-nio",
        "folke/neodev.nvim"
    },
    setup = function()
        require("neodev").setup({
            library = { plugins = { "nvim-dap-ui" }, types = true },
        })

        local dap, dapui = require("dap"), require("dapui")
        function Toggle_terminal()
            local console_buf = dapui.elements.console.buffer()
            if console_buf then
                vim.cmd('split')
                vim.api.nvim_set_current_buf(console_buf)
            end
        end

        function Toggle_stacks()
            local stacks_buf = dapui.elements.stacks.buffer()
            if stacks_buf then
                vim.cmd('vsplit')
                vim.api.nvim_set_current_buf(stacks_buf)
            end
        end

        function Toggle_breakpoints()
            vim.cmd('vsplit')
            dap.list_breapoints()
        end

        function Toggle_watches()
            local watches_buf = dapui.elements.watches.buffer()
            if watches_buf then
                vim.cmd('split')
                vim.api.nvim_set_current_buf(watches_buf)
            end
        end

        function Run_To_Cursor()
            dap.run_to_cursor()
        end

        function Run_Focus()
            dap.focus_frame()
        end

        local normal_config = {
            controls = {
                element = "repl",
                enabled = true,
                icons = {
                    disconnect = "",
                    pause = "",
                    play = "",
                    run_last = "",
                    step_back = "",
                    step_into = "",
                    step_out = "",
                    step_over = "",
                    terminate = ""
                }
            },
            element_mappings = {},
            expand_lines = true,
            floating = {
                border = "single",
                mappings = {
                    close = { "q", "<Esc>" }
                }
            },
            force_buffers = true,
            icons = {
                collapsed = "",
                current_frame = "",
                expanded = ""
            },
            layouts = {
                -- {
                --     elements = {
                --         {
                --             id = "console",
                --             size = 0.5
                --         },
                --         {
                --             id = "stacks",
                --             size = 1
                --         },
                --     },
                --     position = "left",
                --     size = 30
                -- },
                {
                    elements = {
                        {
                            id = "watches",
                            size = 0.5
                        },
                        {
                            id = "scopes",
                            size = 0.5
                        },
                    },
                    position = "bottom",
                    size = 15
                } },
            mappings = {
                edit = "e",
                expand = { "<CR>", "<2-LeftMouse>" },
                open = "o",
                remove = "d",
                repl = "r",
                toggle = "t",
            },
            render = {
                indent = 1,
                max_value_lines = 100
            },
        }

        vim.api.nvim_create_user_command("DapConsole", Toggle_terminal, { desc = "Open terminal" })
        vim.api.nvim_create_user_command("DapStacks", Toggle_stacks, { desc = "Open stacks" })
        vim.api.nvim_create_user_command("DapBreakpointsList", Toggle_breakpoints, { desc = "List breakpoints" })
        vim.api.nvim_create_user_command("DapWatch", Toggle_watches, { desc = "Open watches" })
        vim.api.nvim_create_user_command("DapRunToCursor", Run_To_Cursor, { desc = "Run until cursor" })
        vim.api.nvim_create_user_command("DapFocus", Run_Focus, { desc = "Focus cursor to current frame" })
        vim.api.nvim_create_user_command("DapBreakpointCondition", function()
                dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
            end,
            { desc = "Add a breakpoint with the given condition" })
        vim.keymap.set("n", "<leader>Dt", Toggle_terminal, { desc = "Open terminal" })
        vim.keymap.set("n", "<leader>Ds", Toggle_stacks, { desc = "Open stacks" })
        vim.keymap.set("n", "<leader>Dw", Toggle_watches, { desc = "Open watches" })
        vim.keymap.set("n", "<leader>Db", Toggle_breakpoints, { desc = "List breakpoints" })
        vim.keymap.set("n", "<leader>Dgc", Run_To_Cursor, { desc = "Run until cursor" })
        vim.keymap.set("n", "<leader>Df", Run_Focus, { desc = "Focus cursor to current frame" })

        dapui.setup(normal_config)

        vim.keymap.set('n', '<leader>Dw', function() dapui.elements.watches.add() end, { noremap = true, silent = true })
        vim.keymap.set('n', '<S-F9>', function() dapui.eval() end, { noremap = true, silent = true })

        dap.listeners.before.attach.dapui_config = function()
            dapui.open()
        end
        dap.listeners.before.launch.dapui_config = function()
            dapui.open()
        end
        dap.listeners.before.event_terminated.dapui_config = function()
            local console_buf = dapui.elements.console.buffer()
            if console_buf then
                vim.cmd('split')
                vim.api.nvim_set_current_buf(console_buf)
                vim.api.nvim_win_set_cursor(0, { vim.api.nvim_buf_line_count(console_buf), 0 })
            end
            dapui.close()
        end
        dap.listeners.before.event_exited.dapui_config = function()
            dapui.close()
        end
    end
}
