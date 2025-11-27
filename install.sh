#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
DOTFILES_DIR="$SCRIPT_DIR"
CONFIG_DIR="$HOME/.config"

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

# Install bob (Neovim version manager)
echo "📦 Installing bob..."
if ! command -v bob &>/dev/null; then
    cargo install --git https://github.com/MordechaiHadad/bob.git
    echo "✔ bob installed"
else
    echo "✔ bob already installed"
fi

# Install Neovim 0.12.0 with bob
echo "📝 Installing Neovim 0.12.0 with bob..."
bob install 0.12.0
bob use 0.12.0
echo "✔ Neovim 0.12.0 installed and set as default"

# Install ripgrep
echo "🔍 Installing ripgrep..."
if [ "$PKG_MANAGER" = "apt-get" ]; then
    $INSTALL_CMD ripgrep
elif [ "$PKG_MANAGER" = "dnf" ]; then
    $INSTALL_CMD ripgrep
elif [ "$PKG_MANAGER" = "pacman" ]; then
    $INSTALL_CMD ripgrep
fi

# Install fd
echo "🔎 Installing fd..."
if [ "$PKG_MANAGER" = "apt-get" ]; then
    $INSTALL_CMD fd-find
elif [ "$PKG_MANAGER" = "dnf" ]; then
    $INSTALL_CMD fd-find
elif [ "$PKG_MANAGER" = "pacman" ]; then
    $INSTALL_CMD fd
fi

# Install tmux
echo "🖥️  Installing tmux..."
$INSTALL_CMD tmux

# Install fzf
echo "🔍 Installing fzf..."
if [ "$PKG_MANAGER" = "apt-get" ] || [ "$PKG_MANAGER" = "dnf" ]; then
    $INSTALL_CMD fzf
elif [ "$PKG_MANAGER" = "pacman" ]; then
    $INSTALL_CMD fzf
fi

# Install i3
echo "🪟 Installing i3..."
if [ "$PKG_MANAGER" = "apt-get" ]; then
    $INSTALL_CMD i3
elif [ "$PKG_MANAGER" = "dnf" ]; then
    $INSTALL_CMD i3
elif [ "$PKG_MANAGER" = "pacman" ]; then
    $INSTALL_CMD i3-wm
fi

# Install alacritty
echo "💻 Installing alacritty..."
if [ "$PKG_MANAGER" = "apt-get" ]; then
    $INSTALL_CMD alacritty
elif [ "$PKG_MANAGER" = "dnf" ]; then
    $INSTALL_CMD alacritty
elif [ "$PKG_MANAGER" = "pacman" ]; then
    $INSTALL_CMD alacritty
fi

# Install rofi
echo "🚀 Installing rofi..."
$INSTALL_CMD rofi

# Create config directory
echo "📁 Creating ~/.config directory..."
mkdir -p "$CONFIG_DIR"

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
if [ -f "$CONFIG_DIR/tmux/init.sh" ]; then
    echo "🔧 Running tmux initialization..."
    bash "$CONFIG_DIR/tmux/init.sh"
    echo "✔ tmux initialized"
else
    echo "⚠️  tmux init.sh not found, skipping"
fi

# Run i3 init script
if [ -f "$CONFIG_DIR/i3/init.sh" ]; then
    echo "🔧 Running i3 initialization..."
    bash "$CONFIG_DIR/i3/init.sh"
    echo "✔ i3 initialized"
else
    echo "⚠️  i3 init.sh not found, skipping"
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
