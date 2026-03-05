return {
    src = {
        { src = "theprimeagen/harpoon", version = "harpoon2" }
    },
    setup = function()
        local harpoon = require("harpoon")
        harpoon:setup({
            -- only include serializable options (no functions)
            settings = {
                save_on_toggle = true,
                sync_on_ui_close = true,
            },
        })
        -- REQUIRED

        vim.keymap.set("n", "<leader>a", function() harpoon:list():add() end, { desc = "[A]dd file to harpoon list" });

        -- basic telescope configuration
        local conf = require("telescope.config").values
        local function toggle_telescope(harpoon_files)
            local file_paths = {}
            for _, item in ipairs(harpoon_files.items) do
                table.insert(file_paths, item.value)
            end

            require("telescope.pickers").new({}, {
                prompt_title = "Harpoon",
                finder = require("telescope.finders").new_table({
                    results = file_paths,
                }),
                previewer = conf.file_previewer({}),
                sorter = conf.generic_sorter({}),
            }):find()
        end

        vim.keymap.set("n", "<C-E>", function() toggle_telescope(harpoon:list()) end,
            { desc = "Open harpoon window" })

        vim.keymap.set("n", "<C-e>", function() harpoon.ui:toggle_quick_menu(harpoon:list()) end,
            { desc = "[E]dit harpoon list" });

        vim.keymap.set("n", "<C-h>", function() harpoon:list():select(1) end, { desc = "Goto file in [h] position" });
        vim.keymap.set("n", "<C-j>", function() harpoon:list():select(2) end, { desc = "Goto file in [j] position" });
        vim.keymap.set("n", "<C-k>", function() harpoon:list():select(3) end, { desc = "Goto file in [k] position" });
        vim.keymap.set("n", "<C-l>", function() harpoon:list():select(4) end, { desc = "Goto file in [l] position" });
    end
}
