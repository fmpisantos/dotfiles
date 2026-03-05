local M = {}

-- local js_debug_path = vim.fn.stdpath("data") .. "/mason/packages/js-debug-adapter"
--
-- vim.print("Setting up dap-vscode-js with debugger path: " .. js_debug_path);
--
-- require("dap-vscode-js").setup({
--     debugger_path = js_debug_path,
--     adapters = { 'chrome', 'pwa-node', 'pwa-chrome', 'node-terminal' },
-- })

function M.setup()
    local dap = require('dap')

    -- Configure the adapter for JavaScript/TypeScript
    dap.adapters["pwa-node"] = {
        type = 'server',
        host = 'localhost',
        port = '${port}',
        executable = {
            command = 'js-debug-adapter',
            args = { '${port}' },
        }
    }

    dap.adapters["pwa-chrome"] = {
        type = "server",
        host = "localhost",
        port = "${port}",
        executable = {
            command = "js-debug-adapter",
            args = { "${port}" },
        }
    }

    for _, language in ipairs({ "typescript", "javascript", "typescriptreact", "javascriptreact" }) do
        dap.configurations[language] = {
            -- For launching Expo
            {
                name = "Launch React Native Expo",
                type = "pwa-node",
                request = "launch",
                cwd = "${workspaceFolder}",
                runtimeExecutable = "npx",
                runtimeArgs = {
                    "expo",
                    "start"
                },
                console = "integratedTerminal",
                sourceMaps = true,
                skipFiles = { "<node_internals>/**" },
            },
            -- For attaching to a running Expo process
            -- {
            --     name = "Attach to Expo",
            --     type = "pwa-node",
            --     request = "attach",
            --     processId = require('dap.utils').pick_process,
            --     cwd = "${workspaceFolder}",
            --     sourceMaps = true,
            --     skipFiles = { "<node_internals>/**" },
            -- },
            -- -- For debugging in Chrome/browser
            -- {
            --     name = "Debug Expo Web",
            --     type = "pwa-chrome",
            --     request = "launch",
            --     url = "http://localhost:19006", -- Default Expo web port
            --     webRoot = "${workspaceFolder}",
            --     sourceMaps = true,
            -- }
        }
    end
end

return M
