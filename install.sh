#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
DOTFILES_DIR="$SCRIPT_DIR"
CONFIG_DIR="$HOME/.config"

# ──────────────────────────────────────────────────────────────
# Application toggle list
# Set to true/false to enable/disable installation of each app.
# ──────────────────────────────────────────────────────────────
INSTALL_ZSH=true
INSTALL_RUST=true
INSTALL_NEOVIM=true       # requires rust (bob is built with cargo)
INSTALL_RIPGREP=true
INSTALL_FD=true
INSTALL_TMUX=true
INSTALL_FZF=true
INSTALL_POLYBAR=true
INSTALL_I3=true
INSTALL_ALACRITTY=true
INSTALL_ROFI=true
INSTALL_FONTS=true
# ──────────────────────────────────────────────────────────────

# ──────────────────────────────────────────────────────────────
# Helper: append a line to the user's shell rc file if not already present.
# Uses ~/.zshrc if zsh is being installed or is the current shell,
# otherwise falls back to ~/.bashrc.
# ──────────────────────────────────────────────────────────────
append_to_shell_rc() {
    local line="$1"
    local rc_file

    if [ "$INSTALL_ZSH" = true ] || [ "$SHELL" = "$(which zsh 2>/dev/null)" ]; then
        rc_file="$HOME/.zshrc"
    else
        rc_file="$HOME/.bashrc"
    fi

    if ! grep -qF "$line" "$rc_file" 2>/dev/null; then
        echo "$line" >> "$rc_file"
        echo "  ✔ Added to $rc_file: $line"
    else
        echo "  ✔ Already in $rc_file: $line"
    fi
}

# ──────────────────────────────────────────────────────────────
# Helper: append a multi-line block to BOTH ~/.zshrc and ~/.bashrc.
# A marker line is used to avoid appending the block more than once.
# ──────────────────────────────────────────────────────────────
append_block_to_shell_rcs() {
    local marker="$1"
    local block="$2"
    local rc_file

    for rc_file in "$HOME/.zshrc" "$HOME/.bashrc"; do
        touch "$rc_file"
        if grep -qF "$marker" "$rc_file" 2>/dev/null; then
            echo "  ✔ Block already in $rc_file ($marker)"
        else
            printf '\n%s\n%s\n' "$marker" "$block" >> "$rc_file"
            echo "  ✔ Added block to $rc_file ($marker)"
        fi
    done
}

# Function to install dependencies from a dependencies file
install_dependencies() {
    local dir="$1"
    local deps_file="$dir/dependencies"
    
    if [ ! -f "$deps_file" ]; then
        return
    fi
    
    local dir_name=$(basename "$dir")
    echo "📦 Installing dependencies for $dir_name..."
    
    while IFS= read -r dep || [ -n "$dep" ]; do
        # Skip empty lines and comments
        [[ -z "$dep" || "$dep" =~ ^[[:space:]]*# ]] && continue
        
        # Trim whitespace
        dep=$(echo "$dep" | xargs)
        
        if command -v "$dep" &>/dev/null; then
            echo "  ✔ $dep already installed"
        else
            echo "  📥 Installing $dep..."
            $INSTALL_CMD "$dep"
        fi
    done < "$deps_file"
}

echo "🚀 Starting dotfiles installation..."

# Detect package manager
if command -v apt-get &>/dev/null; then
    PKG_MANAGER="apt-get"
    INSTALL_CMD="sudo apt-get install -y"
elif command -v dnf &>/dev/null; then
    PKG_MANAGER="dnf"
    INSTALL_CMD="sudo dnf install -y"
elif command -v pacman &>/dev/null; then
    PKG_MANAGER="pacman"
    INSTALL_CMD="sudo pacman -S --noconfirm"
else
    echo "❌ Unsupported package manager"
    exit 1
fi

echo "📦 Detected package manager: $PKG_MANAGER"

# Update package lists
echo "📥 Updating package lists..."
if [ "$PKG_MANAGER" = "apt-get" ]; then
    sudo apt-get update
fi

# Install zsh
if [ "$INSTALL_ZSH" = true ]; then
    echo "🐚 Installing zsh..."
    $INSTALL_CMD zsh

    # Make zsh the default shell
    echo "🔧 Setting zsh as default shell..."
    if [ "$SHELL" != "$(which zsh)" ]; then
        chsh -s "$(which zsh)"
        echo "✔ zsh is now the default shell (will take effect on next login)"
    else
        echo "✔ zsh is already the default shell"
    fi
fi

# Install build dependencies
echo "🔨 Installing build dependencies..."
if [ "$PKG_MANAGER" = "apt-get" ]; then
    $INSTALL_CMD build-essential libstdc++-10-dev curl git unzip
elif [ "$PKG_MANAGER" = "dnf" ]; then
    $INSTALL_CMD gcc gcc-c++ make libstdc++-devel curl git unzip
elif [ "$PKG_MANAGER" = "pacman" ]; then
    $INSTALL_CMD base-devel curl git unzip
fi

# Install Rust (if not already installed)
if [ "$INSTALL_RUST" = true ]; then
    echo "🦀 Installing Rust..."
    if ! command -v rustc &>/dev/null; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        # Source for the remainder of this script
        source "$HOME/.cargo/env"
        echo "✔ Rust installed"
    else
        echo "✔ Rust already installed"
    fi

    # Persist cargo bin to the user's shell rc
    append_to_shell_rc 'export PATH="$HOME/.cargo/bin:$PATH"'
    # Also export for the rest of this script session
    export PATH="$HOME/.cargo/bin:$PATH"
fi

# Install bob (Neovim version manager) and Neovim
if [ "$INSTALL_NEOVIM" = true ]; then
    echo "📦 Installing bob..."
    if ! command -v bob &>/dev/null; then
        cargo install --git https://github.com/MordechaiHadad/bob.git
        echo "✔ bob installed"
    else
        echo "✔ bob already installed"
    fi

    # Install Neovim v0.12.1 with bob
    echo "📝 Installing Neovim v0.12.1 with bob..."
    bob install v0.12.1
    bob use v0.12.1

    # bob places the active nvim binary in ~/.local/share/bob/nvim-bin
    append_to_shell_rc 'export PATH="$HOME/.local/share/bob/nvim-bin:$PATH"'
    export PATH="$HOME/.local/share/bob/nvim-bin:$PATH"

    echo "✔ Neovim v0.12.1 installed and set as default"
fi

# Install ripgrep
if [ "$INSTALL_RIPGREP" = true ]; then
    echo "🔍 Installing ripgrep..."
    if [ "$PKG_MANAGER" = "apt-get" ]; then
        $INSTALL_CMD ripgrep
    elif [ "$PKG_MANAGER" = "dnf" ]; then
        $INSTALL_CMD ripgrep
    elif [ "$PKG_MANAGER" = "pacman" ]; then
        $INSTALL_CMD ripgrep
    fi
fi

# Install fd
if [ "$INSTALL_FD" = true ]; then
    echo "🔎 Installing fd..."
    if [ "$PKG_MANAGER" = "apt-get" ]; then
        $INSTALL_CMD fd-find
    elif [ "$PKG_MANAGER" = "dnf" ]; then
        $INSTALL_CMD fd-find
    elif [ "$PKG_MANAGER" = "pacman" ]; then
        $INSTALL_CMD fd
    fi
fi

# Install tmux
if [ "$INSTALL_TMUX" = true ]; then
    echo "🖥️  Installing tmux..."
    $INSTALL_CMD tmux
fi

# Install fzf
if [ "$INSTALL_FZF" = true ]; then
    echo "🔍 Installing fzf..."
    if [ "$PKG_MANAGER" = "apt-get" ] || [ "$PKG_MANAGER" = "dnf" ]; then
        $INSTALL_CMD fzf
    elif [ "$PKG_MANAGER" = "pacman" ]; then
        $INSTALL_CMD fzf
    fi
fi

# Install polybar
if [ "$INSTALL_POLYBAR" = true ]; then
    echo "🪟 Installing polybar..."
    if [ "$PKG_MANAGER" = "apt-get" ]; then
        $INSTALL_CMD polybar
    elif [ "$PKG_MANAGER" = "dnf" ]; then
        $INSTALL_CMD polybar
    elif [ "$PKG_MANAGER" = "pacman" ]; then
        $INSTALL_CMD polybar
    fi
fi

# Install i3
if [ "$INSTALL_I3" = true ]; then
    echo "🪟 Installing i3..."
    if [ "$PKG_MANAGER" = "apt-get" ]; then
        $INSTALL_CMD i3
    elif [ "$PKG_MANAGER" = "dnf" ]; then
        $INSTALL_CMD i3
    elif [ "$PKG_MANAGER" = "pacman" ]; then
        $INSTALL_CMD i3-wm
    fi
fi

# Install alacritty
if [ "$INSTALL_ALACRITTY" = true ]; then
    echo "💻 Installing alacritty..."
    if [ "$PKG_MANAGER" = "apt-get" ]; then
        $INSTALL_CMD alacritty
    elif [ "$PKG_MANAGER" = "dnf" ]; then
        $INSTALL_CMD alacritty
    elif [ "$PKG_MANAGER" = "pacman" ]; then
        $INSTALL_CMD alacritty
    fi
fi

# Install rofi
if [ "$INSTALL_ROFI" = true ]; then
    echo "🚀 Installing rofi..."
    $INSTALL_CMD rofi
fi

# Initialize and update git submodules (nvim, tmux configs, etc.)
echo "📦 Initializing git submodules..."

# Use a temporary git configuration to prefer HTTPS for github.com URLs
# for the submodule init step only — this does NOT modify the user's global
# git config and therefore is automatically scoped to this command.
if command -v git &>/dev/null; then
    if [ -f "$DOTFILES_DIR/.gitmodules" ]; then
        echo "🔐 Initializing submodules using HTTPS for github.com URLs (temporary)..."
        git -c 'url."https://github.com/".insteadOf=git@github.com:' -C "$DOTFILES_DIR" submodule update --init --recursive
        echo "✔ Submodules initialized using temporary HTTPS override"
    else
        echo "⚠️  No .gitmodules found, skipping submodule init"
    fi
else
    echo "⚠️  git not found; skipping submodule init"
fi

# Create config directory
echo "📁 Creating ~/.config directory..."
mkdir -p "$CONFIG_DIR"

# Install dependencies for each config directory
echo "🔗 Checking for dependencies in config directories..."
for item in "$DOTFILES_DIR/config/"/*; do
    if [ -d "$item" ] && [ -f "$item/dependencies" ]; then
        install_dependencies "$item"
    fi
done

# Create symlinks
echo "🔗 Creating symlinks..."
for item in "$DOTFILES_DIR"/config/*; do
    if [ ! -e "$item" ]; then
        continue
    fi
    name=$(basename "$item")
    target="$CONFIG_DIR/$name"

    if [ -e "$target" ] || [ -L "$target" ]; then
        echo "  Backing up $target → $target.bak"
        mv "$target" "$target.bak"
    fi

    echo "  Linking $item → $target"
    ln -s "$item" "$target"
done
echo "✔ Symlinks created in ~/.config"

# Run tmux init script
if [ "$INSTALL_TMUX" = true ]; then
    if [ -f "$CONFIG_DIR/tmux/init.sh" ]; then
        echo "🔧 Running tmux initialization..."
        bash "$CONFIG_DIR/tmux/init.sh"
        echo "✔ tmux initialized"
    else
        echo "⚠️  tmux init.sh not found, skipping"
    fi
fi

# Run polybar init script
if [ "$INSTALL_POLYBAR" = true ]; then
    if [ -f "$CONFIG_DIR/polybar/init.sh" ]; then
        echo "🔧 Running polybar initialization..."
        bash "$CONFIG_DIR/polybar/init.sh"
        echo "✔ polybar initialized"
    else
        echo "⚠️  polybar init.sh not found, skipping"
    fi
fi

# Run i3 init script
if [ "$INSTALL_I3" = true ]; then
    if [ -f "$CONFIG_DIR/i3/init.sh" ]; then
        echo "🔧 Running i3 initialization..."
        bash "$CONFIG_DIR/i3/init.sh"
        echo "✔ i3 initialized"
    else
        echo "⚠️  i3 init.sh not found, skipping"
    fi
fi

# Run fonts script
if [ "$INSTALL_FONTS" = true ]; then
    if [ -f "$SCRIPT_DIR/fonts.sh" ]; then
        echo "🔧 Running fonts initialization..."
        bash "$SCRIPT_DIR/fonts.sh"
        echo "✔ fonts initialized"
    else
        echo "⚠️  fonts.sh not found, skipping"
    fi
fi

# ──────────────────────────────────────────────────────────────
# Install git worktree "agent" helper functions into both
# ~/.zshrc and ~/.bashrc.
# ──────────────────────────────────────────────────────────────
echo "🧩 Installing agent helper functions into shell rc files..."
AGENT_FUNCTIONS_BLOCK=$(cat <<'AGENT_FUNCTIONS_EOF'
list-agents() {
    local selected path
    selected=$(git worktree list | fzf) || return
    path="${selected%% *}"
    [[ -d "$path" ]] && cd "$path"
}

close-agent() {
    local git_dir common_dir
    git_dir=$(git rev-parse --git-dir 2>/dev/null) || { echo "Not in a git repository"; return 1; }
    common_dir=$(git rev-parse --git-common-dir 2>/dev/null)

    local abs_git_dir abs_common_dir
    abs_git_dir=$(cd "$git_dir" 2>/dev/null && pwd)
    abs_common_dir=$(cd "$common_dir" 2>/dev/null && pwd)

    if [[ "$abs_git_dir" == "$abs_common_dir" ]]; then
        echo "Not in a worktree (this is the main repository)"
        return 1
    fi

    if ! git diff --quiet || ! git diff --cached --quiet || [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
        claude "Commit the files that are not committed with a good message"
    fi

    local worktree_path main_worktree branch_name
    worktree_path=$(git rev-parse --show-toplevel)
    branch_name=$(git rev-parse --abbrev-ref HEAD)
    main_worktree=$(git worktree list | head -n 1 | awk '{print $1}')

    if [[ "$branch_name" == "master" || "$branch_name" == "HEAD" ]]; then
        echo "Refusing to merge: worktree is not on a feature branch (current: $branch_name)"
        return 1
    fi

    cd "$main_worktree" 2>/dev/null || cd ..
    git checkout master || return 1
    git pull --ff-only origin master || return 1
    git merge --no-ff "$branch_name" || { echo "Merge failed; resolve conflicts and finish manually"; return 1; }
    git push origin master || return 1

    git worktree remove "$worktree_path"
}

new-agent() {
    local main_worktree
    main_worktree=$(git worktree list | head -n 1 | awk '{print $1}')
    if [[ -z "$main_worktree" ]]; then
        echo "Not in a git repository"
        return 1
    fi

    cd "$main_worktree" || return 1
    git checkout master || return 1
    git pull || return 1

    local name
    if [ -n "$ZSH_VERSION" ]; then
        read "name?Worktree name: "
    else
        read -r -p "Worktree name: " name
    fi
    if [[ -z "$name" ]]; then
        echo "Name required"
        return 1
    fi

    # Sanitize name into a git-branch-friendly slug.
    # Replaces whitespace with underscores, strips characters disallowed
    # by git-check-ref-format, collapses repeats, and trims leading/trailing
    # separators and dots.
    local original_name="$name"
    name=$(printf '%s' "$name" | tr '[:space:]' '_')
    name=$(printf '%s' "$name" | tr -d '~^:?*[\\')
    name=$(printf '%s' "$name" | tr -cd '[:alnum:]_./-')
    name=$(printf '%s' "$name" | sed -e 's/\.\.\+/./g' -e 's|//\+|/|g' -e 's/__\+/_/g')
    name=$(printf '%s' "$name" | sed -e 's|^[-./_]\+||' -e 's|[-./_]\+$||')

    if [[ -z "$name" ]]; then
        echo "Name became empty after sanitization"
        return 1
    fi

    if [[ "$name" != "$original_name" ]]; then
        echo "Sanitized name: '$original_name' → '$name'"
    fi

    git worktree add "../$name" -b "$name" || return 1
    cd "../$name" || return 1

    # If we're inside tmux, rename the current window to the branch name.
    # Disable automatic-rename so the title sticks instead of being
    # overwritten by the running command.
    if [[ -n "$TMUX" ]]; then
        tmux set-window-option automatic-rename off >/dev/null 2>&1
        tmux rename-window "$name" >/dev/null 2>&1
    fi

    claude
}
AGENT_FUNCTIONS_EOF
)
append_block_to_shell_rcs "# >>> dotfiles: agent worktree helpers >>>" "$AGENT_FUNCTIONS_BLOCK"

echo ""
echo "✨ Installation complete! ✨"
echo ""
echo "📝 Notes:"
echo "  • zsh will be your default shell after you log out and back in"
echo "  • If you want run  'cp .bash_aliases ~/'"
echo "  • Rust and cargo are available in ~/.cargo/bin"
echo "  • Neovim nightly is managed by bob (~/.local/share/bob/nvim-bin)"
echo "  • Run 'bob list' to see installed Neovim versions"
echo ""
echo "🔄 Please restart your terminal or run: source ~/.zshrc"
