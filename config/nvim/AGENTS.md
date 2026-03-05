# Agent Guidelines for Neovim Configuration

## Build/Lint/Test Commands

- **Lint**: No dedicated linter configured. Lua LSP provides diagnostics via `.luarc.json`
- **Test**: Manual testing - run Neovim and verify plugin configurations work
- **Single test**: Not applicable - this is configuration code, test by loading specific modules

## Code Style Guidelines

### Imports
- Use `require()` for module imports
- Import at the top of files or within setup functions
- Example: `local builtin = require('telescope.builtin')`

### Formatting
- 4-space indentation (tabs converted to spaces)
- Consistent spacing around operators and brackets
- Line length: no strict limit, break long lines logically

### Naming Conventions
- Functions: snake_case (e.g., `toggle_fold_under_cursor`)
- Variables: snake_case (e.g., `buffer_dir`)
- Constants: UPPER_CASE (minimal usage)
- Plugin modules: return table with `src` and `setup` fields

### Types
- Lua is dynamically typed - no explicit type annotations
- Use descriptive variable names to indicate expected types

### Error Handling
- Use `pcall()` for optional operations that might fail
- Check for nil values before using variables
- Provide fallback behavior when operations fail

### Structure
- Plugin files return configuration tables
- Setup functions contain initialization logic
- Key mappings use `vim.keymap.set()` with descriptive options
- Autocommands use `vim.api.nvim_create_autocmd()`

### Best Practices
- Use `vim.keymap.set()` instead of legacy `vim.api.nvim_set_keymap()`
- Include `desc` field in key mappings for discoverability
- Group related functionality in separate files
- Use `vim.opt` for setting options
- Prefer `vim.api` functions over `vim.cmd()` when possible