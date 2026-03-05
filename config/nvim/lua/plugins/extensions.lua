local api = vim.api

function trim(s)
    return s:match("^%s*(.-)%s*$")
end

_G.urlencode = function(str)
    if str then
        str = str:gsub("\n", "\r\n")
        str = str:gsub("([^%w%-_%.~])", function(c)
            return string.format("%%%02X", string.byte(c))
        end)
    end
    return str or ""
end

_G.CreateFloatingWindow = function(opts)
    local ui = vim.api.nvim_list_uis()[1]
    if not ui then
        vim.notify("Unable to get UI dimensions!", vim.log.levels.ERROR)
        return
    end

    local default_width = math.floor(ui.width * 0.8)
    local default_height = math.floor(ui.height * 0.8)

    local width = opts and opts.width or default_width
    local height = opts and opts.height or default_height

    width = math.min(width, ui.width)
    height = math.min(height, ui.height)

    local col = opts and opts.col or math.floor((ui.width - width) / 2)
    local row = opts and opts.row or math.floor((ui.height - height) / 2)

    local buf = nil
    if opts and opts.buf and vim.api.nvim_buf_is_valid(opts.buf) then
        buf = opts.buf
    else
        local scratch = true
        if opts and opts.keep then
            scratch = false
        end
        buf = vim.api.nvim_create_buf(false, scratch)
    end

    local win_opts = {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        border = "rounded",
    }

    if not (opts and opts.keepStyle) then
        win_opts.style = "minimal"
    end

    local win = vim.api.nvim_open_win(buf, true, win_opts)

    return { buf = buf, win = win }
end

function OpenFloatingWindow(content)
    local screen_width = vim.o.columns
    local screen_height = vim.o.lines

    local num_lines = #content
    local max_line_length = 0
    for _, line in ipairs(content) do
        if #line > max_line_length then
            max_line_length = #line
        end
    end

    local min_width = 20
    local min_height = 5
    local max_width = math.floor(screen_width * 0.9)
    local max_height = math.floor(screen_height * 0.9)

    local win_width = math.max(min_width, math.min(max_width, max_line_length + 4))
    local win_height = math.max(min_height, math.min(max_height, num_lines + 2))

    local win_row = math.floor((screen_height - win_height) / 2)
    local win_col = math.floor((screen_width - win_width) / 2)

    local buf = api.nvim_create_buf(false, true)

    local function sanitize_lines(content)
        local lines = {}

        if type(content) == "string" then
            for line in content:gmatch("[^\r\n]+") do
                table.insert(lines, line)
            end
        elseif type(content) == "table" then
            for _, line in ipairs(content) do
                for subline in line:gmatch("[^\r\n]+") do
                    table.insert(lines, subline)
                end
            end
        else
            error("content must be string or table of strings")
        end

        return lines
    end

    api.nvim_buf_set_lines(buf, 0, -1, false, sanitize_lines(content))


    local win = api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = win_width,
        height = win_height,
        row = win_row,
        col = win_col,
        style = 'minimal',
        border = 'single',
    })

    api.nvim_win_set_option(win, 'wrap', true)
    api.nvim_win_set_option(win, 'cursorline', false)
    api.nvim_win_set_option(win, 'number', false)

    api.nvim_buf_set_keymap(buf, 'n', 'q', '<cmd>lua vim.api.nvim_win_close(' .. win .. ', true)<cr>',
        { noremap = true, silent = true })
end

_G.getVisualSelection = function()
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")

    local start_line = start_pos[2]
    local start_col = start_pos[3]
    local end_line = end_pos[2]
    local end_col = end_pos[3]

    local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)

    if #lines == 0 then
        return ""
    end

    if #lines == 1 then
        return lines[1]:sub(start_col, end_col)
    end

    lines[#lines] = lines[#lines]:sub(1, end_col)
    lines[1] = lines[1]:sub(start_col)

    return table.concat(lines, "\n")
end

-- _G.getVisualSelection = function()
--     local start_pos = vim.fn.getpos("'<")
--     local end_pos = vim.fn.getpos("'>")
--     local bufnr = vim.api.nvim_get_current_buf()
--
--     local lines = vim.api.nvim_buf_get_lines(bufnr, start_pos[2] - 1, end_pos[2], false)
--     local selected_text = table.concat(lines, "\n"):sub(start_pos[3], end_pos[3])
--
--     return selected_text:match("^%s*(.-)%s*$")
-- end

_G.getLastVisualSelection = function()
    vim.cmd('noau normal! "vy"')
    local text = vim.fn.getreg('v')
    vim.fn.setreg('v', {})

    text = string.gsub(text, "\n", "")
    if #text > 0 then
        return text
    else
        return ''
    end
end

_G.show_current_line_popup = function()
    local current_line = api.nvim_get_current_line()
    current_line = trim(current_line)

    OpenFloatingWindow({ current_line })
end

function Exit_visual_and_wait_for_marks()
    vim.cmd('normal! <Esc>')
    vim.cmd('undo')

    vim.cmd('redraw')
    vim.defer_fn(function()
        if vim.fn.line('v') ~= 0 then
            return ""
        else
            Exit_visual_and_wait_for_marks()
        end
    end, 100)
end

_G.GetSelectedText = function(hasTable)
    local _hasTable = hasTable or false
    local mode = vim.api.nvim_get_mode().mode
    Exit_visual_and_wait_for_marks()

    local start_pos = vim.api.nvim_buf_get_mark(0, '<')
    local end_pos = vim.api.nvim_buf_get_mark(0, '>')

    if start_pos[1] == end_pos[1] and start_pos[2] == end_pos[2] then
        return ""
    end

    local buf = 0
    local lines = {}

    if mode == 'V' then
        if start_pos[1] == end_pos[1] then
            local line = vim.api.nvim_buf_get_lines(buf, start_pos[1] - 1, end_pos[1], false)[1]
            lines = { line }
        else
            lines = vim.api.nvim_buf_get_lines(buf, start_pos[1] - 1, end_pos[1], false)
        end
    elseif mode == 'v' then
        for i = start_pos[1], end_pos[1] do
            local line = vim.api.nvim_buf_get_lines(buf, i - 1, i, false)[1]
            if i == start_pos[1] then
                line = line:sub(start_pos[2] + 1)
            end
            if i == end_pos[1] then
                line = line:sub(1, end_pos[2])
            end
            table.insert(lines, line)
        end
    elseif mode == '<C-v>' then
        if _hasTable then
            return {}
        end
        return ""
    end
    if _hasTable then
        return lines
    end
    return table.concat(lines, "\n")
end

_G.FilterQFListToFile = function()
    local replace_string = vim.fn.input(':%s/')
    if replace_string ~= nil and replace_string ~= '' then
        vim.cmd('copen')
        vim.cmd('%y a')
        vim.cmd('cclose')
        vim.cmd('vnew')
        vim.cmd('put a')
        replace_string = '%s/' .. replace_string
        vim.cmd(replace_string)
    else
        vim.cmd('copen')
        vim.cmd('w! a')
        vim.cmd('cclose')
        vim.cmd('vnew')
        vim.cmd('put a')
    end
end

function Custom_picker(opts, title, callback)
    local actions = require('telescope.actions')
    local action_state = require('telescope.actions.state')
    local pickers = require('telescope.pickers')
    local finders = require('telescope.finders')
    local conf = require('telescope.config').values

    local _title = title
    if #title == 0 then
        _title = "Custom Picker"
    end

    pickers.new({}, {
        prompt_title = _title,
        finder = finders.new_table {
            results = opts,
        },
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr, _)
            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                actions.close(prompt_bufnr)
                if selection and selection.value then
                    callback(selection.value)
                end
            end)
            return true
        end,
    }):find()
end

function Custom_picker_id_description(opts, title, callback)
    local actions = require('telescope.actions')
    local action_state = require('telescope.actions.state')
    local pickers = require('telescope.pickers')
    local finders = require('telescope.finders')
    local conf = require('telescope.config').values

    local _title = title or "Custom Picker"

    pickers.new({}, {
        prompt_title = _title,
        finder = finders.new_table {
            results = opts,
            entry_maker = function(entry)
                return {
                    value = entry,
                    display = entry.description,
                    ordinal = entry.description,
                }
            end,
        },
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr, _)
            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                actions.close(prompt_bufnr)
                if selection and selection.value then
                    callback(selection.value)
                end
            end)
            return true
        end,
    }):find()
end

function Run_windows_command(cmd)
    local full_command = 'powershell -Command "' .. cmd .. '"'
    local handle = io.popen(full_command)
    if handle == nil then
        print("Error: Failed to run the command: " .. cmd)
        return nil
    end
    local result = handle:read("*a")
    handle:close()
    return result
end

function Input_from_file(title, callback)
    print(title)
    _G.temp_callback = callback

    local function write_to_temp_file()
        local temp_file = os.tmpname() .. os.time()
        vim.cmd('split ' .. temp_file)
        local bufnr = vim.api.nvim_get_current_buf()

        vim.api.nvim_create_autocmd({ "BufLeave" }, {
            buffer = bufnr,
            callback = function()
                ReadAndDeleteFile(temp_file)
            end
        })

        return temp_file
    end

    function ReadAndDeleteFile(temp_file)
        local file = io.open(temp_file, "r")
        if file then
            local content = file:read("*a")
            file:close()
            os.remove(temp_file)

            if _G.temp_callback then
                _G.temp_callback(content)
                _G.temp_callback = nil
            else
            end
        else
        end
    end

    write_to_temp_file()
end

vim.api.nvim_create_user_command('ClearMarks', function(_)
    vim.cmd('delm A-Z 0-9 a-z')
end, { desc = 'Clear all marks (0-9 A-Z a-z)' })

vim.api.nvim_create_user_command('DelAllMarks', function(_)
    vim.cmd('delm A-Z 0-9 a-z')
end, { desc = 'Clear all marks (0-9 A-Z a-z)' })
