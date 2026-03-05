return {
    src = {
        "folke/tokyonight.nvim",
        "vague2k/vague.nvim",
    },
    setup = function()
        vim.cmd.colorscheme("tokyonight-night")
        vim.api.nvim_set_hl(0, 'LineNrAbove', { fg = 'white' })
        vim.api.nvim_set_hl(0, 'LineNr', { fg = 'orange' })
        vim.api.nvim_set_hl(0, 'LineNrBelow', { fg = 'white' })

        -- vim.cmd.colorscheme("vague");

        -- Ensure background transparency works
        vim.cmd([[
          highlight Normal guibg=NONE ctermbg=NONE
          highlight NonText guibg=NONE ctermbg=NONE
          highlight SignColumn guibg=NONE ctermbg=NONE
          highlight EndOfBuffer guibg=NONE ctermbg=NONE
        ]])
    end
}
