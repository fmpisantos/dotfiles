local M = {}
function M.on_attach(_, bufnr)
    local xmap = function(type, keys, func, desc)
        if desc then
            desc = 'LSP: ' .. desc
        end

        vim.keymap.set(type, keys, func, { buffer = bufnr, desc = desc })
    end
    local imap = function(keys, func, desc)
        xmap('i', keys, func, desc)
    end
    local nmap = function(keys, func, desc)
        xmap('n', keys, func, desc)
    end

    nmap('<leader>vd', vim.diagnostic.open_float, '[V]iew [D]ialog');
    nmap('grd', vim.diagnostic.open_float, '[V]iew [D]ialog');
    nmap('<M-\\>', require('telescope.builtin').lsp_document_symbols, '[D]ocument [S]ymbols')
    nmap('K', vim.lsp.buf.hover, 'Hover Documentation')
    nmap('H', vim.lsp.buf.signature_help, 'Signature help')
    nmap('<M-Tab>', vim.lsp.buf.hover, 'Hover Documentation')
    imap('<M-Tab>', vim.lsp.buf.signature_help, 'Signature help');
    imap('<C-k>', function()
        print("here!");
        vim.lsp.buf.signature_help()
        print("here2");
    end, 'Signature help');

    local function organize_imports()
        local line_count = vim.api.nvim_buf_line_count(bufnr)
        local range = {
            start = { line = 0, character = 0 },
            ["end"] = { line = line_count - 1, character = 0 }
        }

        local params = {
            textDocument = vim.lsp.util.make_text_document_params(),
            range = range,
            context = { only = { "source.organizeImports" }, diagnostics = {} }
        }

        local function silent_handler()
            return true
        end

        vim.lsp.buf_request(bufnr, "textDocument/codeAction", params, function(err, actions, ctx)
            if err or not actions or #actions == 0 then return end

            for _, action in ipairs(actions) do
                if action.kind == "source.organizeImports" or
                    (action.title and action.title:match("Organize Imports")) then
                    vim.lsp.handlers["workspace/executeCommand"] = silent_handler

                    if action.edit then
                        vim.lsp.util.apply_workspace_edit(action.edit, "utf-16")
                    elseif action.command then
                        vim.lsp.buf.execute_command(action.command)
                    else
                        local client = vim.lsp.get_client_by_id(ctx.client_id)
                        if client then
                            client:request("codeAction/resolve", action, function(err, resolved_action)
                                if err or not resolved_action then return end

                                if resolved_action.edit then
                                    vim.lsp.util.apply_workspace_edit(resolved_action.edit, "utf-16")
                                end
                                if resolved_action.command then
                                    client:exec_cmd(resolved_action.command)
                                end

                                vim.lsp.handlers["workspace/executeCommand"] = nil
                            end, bufnr)
                            return
                        end
                    end

                    vim.defer_fn(function()
                        vim.lsp.handlers["workspace/executeCommand"] = nil
                    end, 1000)

                    return
                end
            end
        end)
    end

    local function format()
        vim.cmd('setlocal expandtab')
        vim.cmd('setlocal shiftwidth=4')
        local before = vim.fn.getline(1, '$')
        vim.lsp.buf.format()
        if vim.bo.filetype == 'java' then
            require('jdtls').organize_imports()
        else
            organize_imports()
        end
        local after = vim.fn.getline(1, '$')
        if before ~= after then
            vim.cmd('update')
        end
    end
    local function format_all_files()
        local current_buffer = vim.fn.bufname('%')
        local current_win_view = vim.fn.winsaveview()

        -- Get all non-gitignored files
        local git_files = vim.fn.systemlist('git ls-files --cached --others --exclude-standard')

        for _, filename in ipairs(git_files) do
            if vim.fn.filereadable(filename) == 1 then
                vim.cmd('keepalt edit ' .. vim.fn.fnameescape(filename))
                format()
            else
                print("File doesn't exist: " .. filename)
            end
        end

        if current_buffer ~= '' then
            vim.cmd('buffer ' .. vim.fn.fnameescape(current_buffer))
            vim.fn.winrestview(current_win_view)
        end
    end
    vim.api.nvim_buf_create_user_command(bufnr, 'Format', function(_)
        format()
    end, { desc = 'Format current buffer with LSP' })
    nmap('<leader>dF', ':Format<CR>', '[D]ocument [F]ormat')
    vim.api.nvim_buf_create_user_command(bufnr, 'FormatAll', function(_)
        format_all_files()
    end, { desc = 'Format all project files with LSP' });
    nmap('<leader>pF', ':FormatAll<CR>', '[P]roject [F]ormat')

    local function rename_file()
        local current_name = vim.fn.expand('%:t')
        local new_name = vim.fn.input('New file name: ', current_name)

        if new_name == '' then
            print("No new name provided, aborting.")
            return
        end

        vim.lsp.buf.rename(new_name)

        local current_path = vim.fn.expand('%:p')
        local new_path = vim.fn.fnamemodify(current_path, ':h') .. '/' .. new_name
        vim.fn.rename(current_path, new_path)

        vim.cmd('e ' .. new_path)
        vim.cmd('bwipeout ' .. current_path)
    end

    vim.api.nvim_buf_create_user_command(bufnr, 'Rename', function(_)
        rename_file()
    end, { desc = 'Rename current file and update lsp_references' });

    local cached_files = nil
    local cached_headers = nil

    local function get_project_headers()
        if not cached_headers then
            cached_headers = vim.fn.systemlist(
                'fd --type f --extension h --extension hpp'
            )
        end
        return cached_headers
    end

    local function get_project_files()
        if not cached_files then
            cached_files = vim.fn.systemlist(
                'fd --type f --extension cpp --extension cc --extension c'
            )
        end
        return cached_files
    end

    local function find_corresponding_file()
        local filename = vim.fn.expand("%:t:r")
        local ext = vim.fn.expand("%:e")

        local header_exts = { "h", "hpp" }
        local source_exts = { "cpp", "cc", "c" }
        local is_header = false

        local targets = {}
        if vim.tbl_contains(header_exts, ext) then
            is_header = true
            for _, e in ipairs(source_exts) do
                table.insert(targets, filename .. "." .. e)
            end
        elseif vim.tbl_contains(source_exts, ext) then
            for _, e in ipairs(header_exts) do
                table.insert(targets, filename .. "." .. e)
            end
        else
            vim.cmd("ClangdSwitchSourceHeader")
            return
        end

        local results = {}
        local all_files
        if is_header then
            all_files = get_project_files()
        else
            all_files = get_project_headers()
        end

        for _, file in ipairs(all_files) do
            for _, target in ipairs(targets) do
                if file:match(target .. "$") then
                    table.insert(results, file)
                end
            end
        end

        if #results == 0 then
            print("No matching file found")
        elseif #results == 1 then
            vim.cmd("edit " .. results[1])
        else
            local fzf = require("fzf-lua")
            fzf.fzf_exec(results, {
                prompt = "Select corresponding file> ",
                actions = {
                    ["default"] = function(selected)
                        vim.cmd("edit " .. selected[1])
                    end
                }
            })
        end
    end

    nmap("<leader>hh", find_corresponding_file, "Find source/header file");
end

return M
