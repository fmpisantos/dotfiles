vim.keymap.set("n", "-", "<cmd>edit %:p:h<CR><cmd>normal! gv<CR>",
    { noremap = true, silent = true, desc = "Netrw with current file highlighted" })
vim.g.netrw_browse_split = 0
vim.g.netrw_banner = 0
vim.g.netrw_winsize = 25
-- Make find search recursively
vim.opt.path:append("**")
-- Make it so that I can tab on :find
vim.opt.wildmenu = true
-- Auto-select current file in netrw
vim.api.nvim_create_augroup("netrw_select_current", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
    group = "netrw_select_current",
    pattern = "netrw",
    callback = function()
        local current_file = vim.fn.expand('#:t')
        if current_file ~= '' then
            vim.fn.search('\\V\\^' .. vim.fn.escape(current_file, '\\') .. '\\$')
        end
    end,
})

local file_cache = {
    files = {},
    timestamp = 0,
    cache_duration = 5000
}

local function get_files(args)
    local now = vim.fn.reltime()
    local now_ms = vim.fn.reltimestr(now) * 1000

    if not file_cache.files or (now_ms - file_cache.timestamp) > file_cache.cache_duration then
        args = args:gsub("\\", "\\\\")
        file_cache.files = vim.fn.systemlist("fd " .. args .. " --max-results 50")
        file_cache.timestamp = now_ms
    end

    return file_cache.files
end

vim.api.nvim_create_user_command("Fd", function(opts)
    local matches = get_files(opts.args)
    if #matches == 1 then
        vim.cmd("edit " .. vim.fn.fnameescape(matches[1]))
    elseif #matches > 1 then
        vim.ui.select(matches, {
            prompt = "Select file to open:",
            format_item = function(item)
                return vim.fn.fnamemodify(item, ":.")
            end
        }, function(choice)
            if choice then
                vim.cmd("edit " .. vim.fn.fnameescape(choice))
            end
        end)
    else
        vim.notify("No files found matching: " .. opts.args, vim.log.levels.WARN)
    end
end, {
    nargs = 1,
    desc = "Find and open files using fd",
    complete = function(argLead, _, _)
        return get_files(argLead);
    end
});

local function glob_to_pattern(glob)
    local pattern = glob:lower()
    pattern = pattern:gsub("[%(%)%.%+%-%?%[%]%^%$%%]", "%%%1")
    pattern = pattern:gsub("%*", ".*")
    return pattern
end

vim.api.nvim_create_user_command("Find", function(opts)
    local files = vim.fn.systemlist("git ls-files --cached --others --exclude-standard")
    local matches = {}
    local query = opts.args
    local has_wildcards = query:find("[*?]")

    if has_wildcards then
        local pattern = glob_to_pattern(query)
        for _, f in ipairs(files) do
            if f:lower():match(pattern) then
                table.insert(matches, f)
            end
        end
    else
        local lower_query = query:lower()
        for _, f in ipairs(files) do
            if f:lower():find(lower_query, 1, true) then
                table.insert(matches, f)
            end
        end
    end
    if #matches == 1 then
        vim.cmd("edit " .. vim.fn.fnameescape(matches[1]))
    elseif #matches > 1 then
        vim.ui.select(matches, { prompt = "Multiple matches:" }, function(choice)
            if choice then
                vim.cmd("edit " .. vim.fn.fnameescape(choice))
            end
        end)
    else
        print("No match found")
    end
end, {
    nargs = 1,
    complete = function(_, line, _)
        local files = vim.fn.systemlist("git ls-files --cached --others --exclude-standard")
        local prefix = line:match("%S+$") or ""
        local lower_prefix = prefix:lower()
        local matches = {}
        for _, f in ipairs(files) do
            if f:lower():find(lower_prefix, 1, true) then
                table.insert(matches, f)
            end
        end
        return matches
    end,
})

if vim.fn.executable("rg") == 1 then
    vim.api.nvim_create_user_command("Rg", function(opts)
        local args = vim.split(opts.args, " ")
        if #args == 0 then
            print("Usage: :Rg {pattern}")
            return
        end

        local pattern = args[1]
        local flags = {}
        for i = 2, #args do
            table.insert(flags, args[i])
        end

        local cmd = { "rg", "--vimgrep", "--smart-case" }
        vim.list_extend(cmd, flags)
        table.insert(cmd, pattern)

        local output = vim.fn.systemlist(cmd)
        if vim.v.shell_error ~= 0 or #output == 0 then
            print("No matches found")
            return
        end

        vim.fn.setqflist({}, " ", { title = "Ripgrep", lines = output })
        vim.cmd("copen")
    end, { nargs = "+" })
end
