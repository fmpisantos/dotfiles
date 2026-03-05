return {
    src = {
        "neovim/nvim-lspconfig",
        "williamboman/mason.nvim",
        "williamboman/mason-lspconfig.nvim",
        "mfussenegger/nvim-jdtls",
        -- Add nvim-cmp and its dependencies
        "hrsh7th/nvim-cmp",         -- The completion plugin itself
        "hrsh7th/cmp-nvim-lsp",     -- LSP completion source for nvim-cmp
        "L3MON4D3/LuaSnip",         -- Snippet engine (recommended for LSP snippets)
        "saadparwaiz1/cmp_luasnip", -- Snippet source for nvim-cmp
        "hrsh7th/cmp-buffer",       -- Buffer word completion source
        "hrsh7th/cmp-path",         -- File path completion source
    },
    event = { "BufReadPost", "BufWritePost", "BufNewFile" },
    setup = function()
        local on_attach = require("plugins.lsp-keymaps").on_attach
        local capabilities = vim.lsp.protocol.make_client_capabilities()

        require("mason").setup({
            registries = {
                -- 'github:fmpisantos/mason-registry', -- This will replace jdtls, java-test and java-debugger-adapter with the corresponding JAVA 17 version
                'github:mason-org/mason-registry'
            }
        });

        vim.cmd("MasonUpdate")

        -- Configure nvim-cmp
        local cmp = require("cmp")
        local luasnip = require("luasnip")

        cmp.setup {
            snippet = {
                expand = function(args)
                    luasnip.lsp_expand(args.body)
                end,
            },
            completion = {
                completeopt = 'menu,menuone,noinsert',
            },
            mapping = cmp.mapping.preset.insert {
                ['<C-n>'] = cmp.mapping.select_next_item(),
                ['<C-p>'] = cmp.mapping.select_prev_item(),
                ['<C-y>'] = cmp.mapping.confirm({ select = true }),
                ['<C-Space>'] = nil,
                ['<Tab>'] = nil,
                ['<S-Tab>'] = cmp.mapping.complete {},
            },
            sources = {
                { name = 'nvim_lsp' },
                { name = 'luasnip' },
                { name = 'path' },
            },
        }

        cmp.setup.filetype({ "sql" }, {
            sources = {
                { name = "vim-dadbod-completion" },
                { name = "buffer" },
            }
        })

        -- Your existing LSP configurations follow
        vim.lsp.config('*', {
            capabilities = capabilities,
            on_attach = on_attach,
        })

        vim.lsp.config('lua_ls', {
            capabilities = capabilities,
            on_attach = on_attach,
            settings = {
                Lua = {
                    workspace = { checkThirdParty = false },
                    telemetry = { enable = false },
                },
            },
        })

        local jdtls_config = require("plugins.java.config")
        local function on_attach_jdtls(client, _bufnr)
            on_attach(client, _bufnr)
            jdtls_config.jdtls_on_attach(client, _bufnr)
        end
        local cmd, path = jdtls_config.jdtls_setup()

        vim.lsp.config('jdtls', {
            cmd = cmd,
            capabilities = capabilities,
            on_attach = on_attach_jdtls,
            settings = {
                java = {
                    configuration = {
                        runtimes = path.runtimes
                    },
                    test = {
                        config = {
                            {
                                name = "JUnit 4",
                                testKind = "junit",
                                workingDirectory = "${workspaceFolder}",
                                classPaths = { "$Auto" },
                                modulePaths = { "$Auto" }
                            }
                        },
                        defaultConfig = "JUnit 4"
                    }
                }
            },
            init_options = {
                bundles = path.bundles,
            },
            root_dir = vim.fs.root(0, { '.git', 'mvnw', 'gradlew', 'pom.xml', 'build.gradle' })
        });

        vim.lsp.config("clangd", {
            on_attach = on_attach,
            capabilities = capabilities,
            root_markers = { "*.sln", "*.csproj" },
        });

        vim.lsp.config("omnisharp", {
            cmd = { "omnisharp", "--languageserver" },
            on_attach = on_attach,
            capabilities = capabilities,
            filetypes = { "cs", "vb", "razor", "cshtml" },
            root_markers = { "*.sln", "*.csproj" },
            init_options = {
                RazorSupport = true
            },
        });

        local vtsls_config = require("plugins.jsts.jsts-dap")
        local function on_attach_vtsls(client, _bufnr)
            on_attach(client, _bufnr)
            vtsls_config.setup()
        end
        vim.lsp.config("vtsls", {
            capabilities = capabilities,
            on_attach = on_attach_vtsls,
        });

        vim.diagnostic.config({
            float = {
                focusable = true,
                style = "minimal",
                border = "rounded",
                source = true,
                header = "",
                prefix = "",
            },
        })

        require("mason-lspconfig").setup({
            ensure_installed = {
                "omnisharp",
                -- "jdtls",
                "lua_ls",
                "vtsls"
            },
            automatic_installation = true,
            automatic_enable = true
        });

        vim.lsp.enable({
            'jdtls'
        });
    end
}
