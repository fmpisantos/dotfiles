local function get_project_name()
    local full_path = vim.fn.expand("%:p")
    if full_path == "" then
        full_path = vim.fn.getcwd()
    end

    full_path = full_path:gsub("\\", "/")

    local project_name = full_path:match("^D:/src/([^/]+)")
    if not project_name then
        return nil
    end

    local develop_num = project_name:match("^develop(%d*)$")
    if develop_num then
        if develop_num == "" then
            return 1
        else
            return tonumber(develop_num)
        end
    end

    return project_name
end


vim.opt_local.makeprg = 'pwsh -Command "incredibuild ' .. get_project_name() .. ' -l -silent"';

vim.opt_local.errorformat = "%f(%l): error %m";
