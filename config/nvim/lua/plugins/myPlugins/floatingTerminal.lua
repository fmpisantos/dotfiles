local state = {
    shared = {
        buf = -1
    },
    floating = {
        buf = -1,
        win = -1
    },
    small = {
        buf = -1,
        win = -1
    }
}

vim.keymap.set({ 'n', 't' }, "<leader>tf", function()
    local buf = -1
    if vim.api.nvim_buf_is_valid(state.shared.buf) then
        buf = state.shared.buf
    else
        buf = state.floating.buf
    end

    if vim.api.nvim_win_is_valid(state.small.win) then
        vim.api.nvim_win_hide(state.small.win)
    end

    if not vim.api.nvim_win_is_valid(state.floating.win) then
        state.floating = CreateFloatingWindow { buf = buf }
        state.shared.buf = state.floating.buf
        if vim.api.nvim_buf_get_option(state.floating.buf, "buftype") ~= "terminal" then
            vim.cmd.terminal()
        end
        vim.cmd("startinsert")
    else
        vim.api.nvim_win_hide(state.floating.win)
    end
end, { noremap = true, silent = true, desc = "Open floating terminal" })

vim.keymap.set({ "n", "t" }, "<leader>ts", function()
    local buf = -1
    if vim.api.nvim_buf_is_valid(state.shared.buf) then
        buf = state.shared.buf
    else
        buf = state.small.buf
    end

    if vim.api.nvim_win_is_valid(state.floating.win) then
        vim.api.nvim_win_hide(state.floating.win)
    end

    if vim.api.nvim_win_is_valid(state.small.win) then
        vim.api.nvim_win_hide(state.small.win)
    else
        vim.cmd.vnew()
        if not vim.api.nvim_buf_is_valid(buf) then
            vim.cmd.term()
            state.small.buf = vim.api.nvim_get_current_buf()
            state.shared.buf = state.small.buf
        else
            vim.api.nvim_win_set_buf(0, buf)
        end
        state.small.win = vim.api.nvim_get_current_win()
        vim.cmd.wincmd("J")
        vim.api.nvim_win_set_height(0, 20)
        vim.cmd("startinsert")
    end
end, { desc = "Open [T]erminal [S]mall" })

local job_id = 0
vim.keymap.set({ "n", "t" }, "<leader>tn", function()
    vim.cmd.vnew()
    vim.cmd.term()
    vim.cmd.wincmd("J")
    vim.api.nvim_win_set_height(0, 20)
    job_id = vim.bo.channel
end, { desc = "Open [T]erminal [S]mall" })

vim.keymap.set("n", "<leader>example", function()
    -- make
    -- mvn clean install
    -- mvn spring-boot:run
    -- mvn clean test
    vim.fn.chansend(job_id, "echo 'Hello World'\r\n")
end, { desc = "Send example command to terminal" })
