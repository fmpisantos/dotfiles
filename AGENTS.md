# Agent Guidelines for Dotfiles Repository

## Overview
This repository contains personal dotfiles for Neovim, tmux, i3, alacritty, polybar, and rofi configurations. The primary focus is on Neovim Lua configuration with supporting shell scripts and other config files.

## Build/Lint/Test Commands

### General
- **Installation**: Run `./install.sh` to install all dotfiles and dependencies
- **Package Manager Detection**: The install script automatically detects apt-get, dnf, or pacman
- **Selective Installation**: Toggle variables at the top of install.sh to enable/disable specific components

### Neovim-Specific
- **Testing**: Manual testing - run Neovim (`nvim`) and verify configurations work
- **Single Module Test**: Load specific modules with `:lua require('module_name')`
- **LSP Diagnostics**: Lua language server provides diagnostics via `.luarc.json` in nvim config
- **No Formal Test Suite**: Configuration is validated by using it

### Shell Scripts
- **Syntax Check**: `bash -n script.sh` to check for syntax errors
- **ShellCheck**: Recommended for linting shell scripts (not formally configured)
- **Execution**: Most scripts are meant to be sourced or run during installation

### Other Configs
- **tmux**: Test by sourcing config (`tmux source-file ~/.tmux.conf`) or restarting tmux
- **i3/polybar/alacritty/rofi**: Test by reloading/restarting respective applications

## Code Style Guidelines

### Neovim Lua Configuration

#### Imports
- Use `require()` for module imports
- Import at the top of files or within setup functions
- Example: `local builtin = require('telescope.builtin')`
- Plugin modules typically return tables with `src` and `setup` fields
- Use `pack.require()` for lazy-loaded plugins via pack.nvim

#### Formatting
- 4-space indentation (tabs converted to spaces)
- Consistent spacing around operators and brackets
- Line length: no strict limit, break long lines logically
- End-of-file newline recommended
- Blank lines to separate logical sections

#### Naming Conventions
- Functions: snake_case (e.g., `toggle_fold_under_cursor`)
- Variables: snake_case (e.g., `buffer_dir`)
- Constants: UPPER_CASE (minimal usage)
- Plugin modules: return table with `src` and `setup` fields
- Autocommand groups: descriptive names in snake_case
- Key mapping descriptions: clear, concise phrases

#### Types
- Lua is dynamically typed - no explicit type annotations
- Use descriptive variable names to indicate expected types
- Common types: strings for paths/commands, booleans for toggles, tables for configuration
- Function parameters often documented via descriptive names

#### Error Handling
- Use `pcall()` for optional operations that might fail
- Check for nil values before using variables (especially with `os.getenv()`)
- Provide fallback behavior when operations fail
- Example pattern: `local var = os.getenv("VAR") or "default"`
- Wrap potentially failing operations in `pcall` with error logging

#### Structure
- Plugin files return configuration tables
- Setup functions contain initialization logic
- Key mappings use `vim.keymap.set()` with descriptive options
- Autocommands use `vim.api.nvim_create_autocmd()`
- Use `vim.api.nvim_create_augroup()` for autocommand groups
- Separate concerns: settings, mappings, plugins in different files

#### Best Practices
- Use `vim.keymap.set()` instead of legacy `vim.api.nvim_set_keymap()`
- Include `desc` field in key mappings for discoverability
- Group related functionality in separate files
- Use `vim.opt` for setting options
- Prefer `vim.api` functions over `vim.cmd()` when possible
- Leverage Lua's functional capabilities (anonymous functions, closures)
- Use `vim.fn` for Vimscript function calls when needed
- Environment variable checks: `vim.env.VAR_NAME`

### Shell Scripts

#### Imports/Sourcing
- Use `source` or `.` to include helper scripts
- Prefer absolute paths or paths relative to script location
- Check if files exist before sourcing

#### Formatting
- 2-space indentation (standard for shell scripts)
- Consistent spacing around operators in `[ ]` and `[[ ]]` tests
- Line length: aim for 80-100 characters, break long lines logically
- Use heredocs for multi-line content when appropriate

#### Naming Conventions
- Variables: snake_case (e.g., `install_dir`)
- Constants: UPPER_CASE with underscores
- Functions: snake_case
- Export only variables that need to be environment variables

#### Types
- Shell is untyped; all variables are strings
- Use descriptive names to indicate expected content (e.g., `file_path`, `count`)
- Boolean-like variables: use "true"/"false" strings or 0/1 integers

#### Error Handling
- `set -e` at top of scripts to exit on error
- `set -u` to treat unset variables as errors
- `set -o pipefail` to catch errors in pipelines
- Check command exit status when appropriate
- Provide informative error messages to stderr
- Use `||` and `&&` for conditional execution
- Wrap sections in subshells `( )` to isolate variable changes

#### Structure
- Shebang: `#!/usr/bin/env bash` for portability
- Constants and configuration at the top
- Helper functions defined before main logic
- Main execution flow in a `main()` function or at bottom
- Use functions to encapsulate reusable logic
- Comment sections clearly with descriptive headers

#### Best Practices
- Quote variables unless word splitting is specifically desired
- Use `[[ ]]` for conditionals instead of `[ ]` when bash-specific features are OK
- Prefer `$(command)` over backticks for command substitution
- Use `printf` instead of `echo` for formatted output
- Handle edge cases: empty variables, special characters in filenames
- Make scripts idempotent when possible
- Provide `--help` or usage information for complex scripts

### Other Config Files (JSON, TOML, YAML, etc.)

#### General
- Follow format-specific conventions (2-space indent for JSON, etc.)
- Validate syntax with appropriate tools when available
- Keep configurations minimal and well-commented
- Use consistent value types (don't mix strings and booleans for similar settings)

#### Specific Formats
- **JSON**: 2-space indentation, trailing commas avoided
- **TOML**: Follow standard TOML formatting conventions
- **YAML**: 2-space indentation, use explicit types when ambiguity possible

## Additional Guidelines

### Cross-Platform Considerations
- Check OS type before setting shell or platform-specific configurations
- Use `vim.loop.os_uname().sysname` in Lua for OS detection
- In shell scripts, use `uname -s` or check for specific commands
- Provide fallbacks for missing utilities
- Separate platform-specific configurations when complexity grows

### Performance Considerations
- Lazy-load plugins when possible
- Minimize autocommands; use events judiciously
- Avoid expensive operations in frequently triggered callbacks
- Cache results of expensive operations when appropriate
- Use debouncing/throttling for rapid-fire events

### Security Considerations
- Validate inputs from environment variables
- Avoid shell injection by properly quoting variables
- Be cautious with `vim.fn.system()` and similar functions
- Check existence and permissions of files before accessing
- Use neovim's built-in security features (sandboxing) when available

### Maintenance and Updates
- Keep configurations minimal and well-documented
- Remove unused configurations periodically
- Test changes thoroughly before committing
- Separate personal preferences from potentially shareable configurations
- Consider making configurable options into variables at the top of files
