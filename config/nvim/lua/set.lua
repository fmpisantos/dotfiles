vim.opt.winborder = "rounded"
vim.opt.guicursor = ""

vim.opt.nu = true
vim.opt.relativenumber = true

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

vim.opt.smartindent = true

vim.opt.wrap = false

vim.opt.swapfile = false
vim.opt.backup = false

local home_dir = os.getenv("HOME")
if not home_dir then
    home_dir = os.getenv("USERPROFILE")
end

vim.opt.undodir = home_dir .. "/.vim/undodir"
vim.opt.undofile = true

vim.opt.hlsearch = false
vim.opt.incsearch = true

-- In your init.lua or wherever you configure nvim
vim.opt.termguicolors = true

-- Force true color support
if vim.fn.has('termguicolors') == 1 then
    vim.opt.termguicolors = true
end

vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.isfname:append("@-@")

vim.opt.updatetime = 50
vim.opt.foldmethod = "indent"
vim.opt.foldlevelstart = 99

-- Remove statusline
vim.cmd("hi statusline guibg=NONE")

vim.o.ignorecase = true

-- Kickstart include
vim.g.have_nerd_font = true
vim.opt.showmode = false
vim.opt.breakindent = true
vim.opt.updatetime = 250
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.inccommand = 'split'
vim.opt.cursorline = true
vim.opt.scrolloff = 10
vim.opt.hlsearch = true

vim.api.nvim_create_autocmd('TextYankPost', {
    desc = 'Highlight when yanking (copying) text',
    group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
    callback = function()
        vim.highlight.on_yank()
    end,
})

vim.api.nvim_create_autocmd('TermOpen', {
    group = vim.api.nvim_create_augroup('custom-term-open', { clear = true }),
    callback = function()
        vim.opt.number = false
        vim.opt.relativenumber = false
        vim.cmd("startinsert")
    end,
})

if vim.loop.os_uname().sysname == 'Darwin' or vim.loop.os_uname().sysname == 'Linux' then
    -- macOS → use zsh
    vim.opt.shell = "/bin/zsh"
    if vim.loop.os_uname().sysname == 'Linux' then
        vim.opt.shellcmdflag = "-i -c"
    else
        vim.opt.shellcmdflag = "-c"
    end
    vim.opt.shellquote = ""
    vim.opt.shellxquote = ""
else
    -- Windows → use PowerShell Core (pwsh)
    vim.opt.shell = "pwsh"
    vim.opt.shellcmdflag = "-NoProfile -ExecutionPolicy Bypass -Command"
    vim.opt.shellquote = ""
    vim.opt.shellxquote = ""
end

-- Set up the autocmd for redrawing
vim.api.nvim_create_autocmd('VimResume', {
    callback = function() vim.cmd('redraw!') end
})

-- Run Sessionizer
vim.keymap.set({ 'n', 'v', 'i' }, '<C-f>', function()
    if vim.fn.mode() == 'c' then
        return '<C-f>'
    else
        if vim.env.TMUX then
            vim.fn.jobstart('tmux neww ~/.local/bin/tmux-sessionizer')
        elseif vim.env.TERM_PROGRAM == "tmux" then
            vim.fn.jobstart('tmux neww ~/.local/bin/tmux-sessionizer')
        elseif vim.env.TERM_PROGRAM == "WezTerm" then
            if vim.loop.os_uname().sysname == 'Darwin' or vim.loop.os_uname().sysname == 'Linux' then
                vim.fn.jobstart({ "osascript", "-e", 'tell application "System Events" to key code 105' }) -- 105 is F13
            elseif vim.loop.os_uname().sysname == 'Windows_NT' then
                vim.fn.jobstart({
                    "powershell",
                    "-Command",
                    [[
Add-Type -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;
    public class Keyboard {
        [DllImport("user32.dll")]
        public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
        public const int VK_F13 = 0x7C;
        public const int KEYEVENTF_KEYDOWN = 0x0000;
        public const int KEYEVENTF_KEYUP = 0x0002;
        public static void PressF13() {
            keybd_event(VK_F13, 0, KEYEVENTF_KEYDOWN, UIntPtr.Zero);
            keybd_event(VK_F13, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
        }
    }
"@
[Keyboard]::PressF13()
    ]]
                })
            else
                vim.fn.jobstart({ "wtype", "F13" })
            end
        end
        return '';
    end
end, { expr = true })
