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
        source "$HOME/.cargo/env"
        echo "✔ Rust installed"
    else
        echo "✔ Rust already installed"
    fi

    # Ensure cargo is in PATH
    export PATH="$HOME/.cargo/bin:$PATH"
fi

# Install bob (Neovim version manager) and Neovim
if [ "$INSTALL_NEOVIM" = true ]; then
    # Ensure cargo is in PATH (needed for bob)
    export PATH="$HOME/.cargo/bin:$PATH"

    echo "📦 Installing bob..."
    if ! command -v bob &>/dev/null; then
        cargo install --git https://github.com/MordechaiHadad/bob.git
        echo "✔ bob installed"
    else
        echo "✔ bob already installed"
    fi

    # Install Neovim nightly with bob
    echo "📝 Installing Neovim nightly with bob..."
    bob install nightly
    bob use nightly
    echo "✔ Neovim nightly installed and set as default"
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

# Create config directory
echo "📁 Creating ~/.config directory..."
mkdir -p "$CONFIG_DIR"

# Install dependencies for each config directory
echo "🔗 Checking for dependencies in config directories..."
for item in "$DOTFILES_DIR"/*; do
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

echo ""
echo "✨ Installation complete! ✨"
echo ""
echo "📝 Notes:"
echo "  • zsh will be your default shell after you log out and back in"
echo "  • Rust and cargo are available in ~/.cargo/bin"
echo "  • Neovim 0.12.0 is managed by bob"
echo "  • Run 'bob list' to see installed Neovim versions"
echo ""
echo "🔄 Please restart your terminal or run: source ~/.zshrc"
