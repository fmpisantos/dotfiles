#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
DOTFILES_DIR="$SCRIPT_DIR"
CONFIG_DIR="$HOME/.config"

# Files the shell-rc helpers append to for zsh:
#   ZSH_RC      → interactive rc (shell functions)  — .zshrc
#   ZSH_PROFILE → login env (PATH / exports)        — .zprofile
# Defaults live in $HOME. If INSTALL_ZSH is true we run config/zsh/init.sh,
# which moves ZDOTDIR to the repo's zsh config ($XDG_CONFIG_HOME/zsh — a symlink
# into this repo). After that zsh reads its startup files from there and ignores
# the ones in $HOME, so both vars get repointed at $ZDOTDIR/* (the files zsh
# actually reads; editing them there is reflected system-wide for the user).
ZSH_RC="$HOME/.zshrc"
ZSH_PROFILE="$HOME/.zprofile"

# ──────────────────────────────────────────────────────────────
# Application toggle list
# Set to true/false to enable/disable installation of each app.
# ──────────────────────────────────────────────────────────────
INSTALL_ZSH=true
INSTALL_RUST=true
INSTALL_NEOVIM=true # requires rust (bob is built with cargo)
INSTALL_RIPGREP=true
INSTALL_FD=true
INSTALL_TMUX=true
INSTALL_FZF=true
INSTALL_POLYBAR=true
INSTALL_I3=true
INSTALL_ALACRITTY=true
INSTALL_ROFI=true
INSTALL_FONTS=true
INSTALL_LSD=true # alternative to ls
# ──────────────────────────────────────────────────────────────

# ──────────────────────────────────────────────────────────────
# Helper: append an environment line (e.g. a PATH export) if not already
# present. For zsh this targets the login profile ($ZSH_PROFILE / .zprofile),
# since PATH/exports belong in the login shell; otherwise ~/.bashrc.
# The grep guard makes it idempotent — the line is only added if not there yet.
# ──────────────────────────────────────────────────────────────
append_to_shell_rc() {
    local line="$1"
    local rc_file

    if [ "$INSTALL_ZSH" = true ] || [ "$SHELL" = "$(which zsh 2>/dev/null)" ]; then
        rc_file="$ZSH_PROFILE"
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
# Helper: append a multi-line block to BOTH the active zsh rc and ~/.bashrc.
# A marker line is used to avoid appending the block more than once.
# Note: the zsh target is $ZSH_RC, which is $ZDOTDIR/.zshrc once
# config/zsh/init.sh has run (see ZSH_RC above), not necessarily $HOME/.zshrc.
# ──────────────────────────────────────────────────────────────
append_block_to_shell_rcs() {
    local marker="$1"
    local block="$2"
    local rc_file

    for rc_file in "$ZSH_RC" "$HOME/.bashrc"; do
        touch "$rc_file"
        if grep -qF "$marker" "$rc_file" 2>/dev/null; then
            echo "  ✔ Block already in $rc_file ($marker)"
        else
            printf '\n%s\n%s\n' "$marker" "$block" >> "$rc_file"
            echo "  ✔ Added block to $rc_file ($marker)"
        fi
    done
}

# ──────────────────────────────────────────────────────────────
# Helper: install one or more packages via the detected package manager,
# tolerating the transient failures that otherwise abort the whole script
# under `set -e`. On apt a 404 is usually a stale index/pool mismatch (common
# on dev releases), so we refresh the index and retry once with --fix-missing.
# Returns nonzero if the package still can't be installed, letting callers
# decide whether to fall back to another install method.
# ──────────────────────────────────────────────────────────────
pkg_install() {
    if $INSTALL_CMD "$@"; then
        return 0
    fi
    if [ "$PKG_MANAGER" = "apt-get" ]; then
        echo "  ⚠️  apt install failed; refreshing index and retrying..."
        sudo apt-get update || true
        $INSTALL_CMD --fix-missing "$@" && return 0
    fi
    return 1
}

# ──────────────────────────────────────────────────────────────
# Helper: map the host CPU to the Rust target arch used in release asset
# names. Echoes "x86_64" / "aarch64", or empty for anything we don't ship.
# ──────────────────────────────────────────────────────────────
host_arch() {
    case "$(uname -m)" in
        x86_64|amd64)  echo x86_64 ;;
        aarch64|arm64) echo aarch64 ;;
        *)             echo "" ;;
    esac
}

# ──────────────────────────────────────────────────────────────
# Helper: resolve a GitHub repo's latest release tag via the /releases/latest
# redirect — no API token or jq required. Echoes the tag (e.g. "15.1.0" or
# "v10.2.0"), empty on failure.
#   $1 = owner/repo
# ──────────────────────────────────────────────────────────────
github_latest_tag() {
    curl -fsSLI -o /dev/null -w '%{url_effective}' \
        "https://github.com/$1/releases/latest" 2>/dev/null | sed -n 's#.*/tag/##p'
}

# ──────────────────────────────────────────────────────────────
# Helper: download a .tar.gz, extract a single binary, and install it into
# ~/.local/bin (added to PATH). This avoids building from source with cargo,
# which can OOM or segfault rustc on small aarch64 VMs (heavy crates like
# regex-syntax at opt-level 3). Returns nonzero on any failure.
#   $1 = tarball URL   $2 = binary basename inside the archive   $3 = dest name
# ──────────────────────────────────────────────────────────────
install_tarball_binary() {
    local url="$1" inner="$2" dest="$3" tmp bin
    tmp="$(mktemp -d)" || return 1
    if ! curl -fsSL "$url" -o "$tmp/archive.tar.gz"; then rm -rf "$tmp"; return 1; fi
    if ! tar -xzf "$tmp/archive.tar.gz" -C "$tmp"; then rm -rf "$tmp"; return 1; fi
    bin="$(find "$tmp" -type f -name "$inner" -print -quit)"
    if [ -z "$bin" ]; then rm -rf "$tmp"; return 1; fi
    mkdir -p "$HOME/.local/bin"
    if ! install -m 0755 "$bin" "$HOME/.local/bin/$dest"; then rm -rf "$tmp"; return 1; fi
    rm -rf "$tmp"
    append_to_shell_rc 'export PATH="$HOME/.local/bin:$PATH"'
    export PATH="$HOME/.local/bin:$PATH"
    return 0
}

# Prebuilt ripgrep: BurntSushi ships x86_64-musl and aarch64-gnu binaries.
install_ripgrep_prebuilt() {
    local arch tag target
    arch="$(host_arch)"; [ -z "$arch" ] && return 1
    tag="$(github_latest_tag BurntSushi/ripgrep)"; [ -z "$tag" ] && return 1
    case "$arch" in
        x86_64)  target="x86_64-unknown-linux-musl" ;;
        aarch64) target="aarch64-unknown-linux-gnu" ;;
    esac
    install_tarball_binary \
        "https://github.com/BurntSushi/ripgrep/releases/download/${tag}/ripgrep-${tag}-${target}.tar.gz" \
        rg rg
}

# Prebuilt fd: sharkdp ships musl binaries for both arches (tags are vX.Y.Z).
install_fd_prebuilt() {
    local arch tag target
    arch="$(host_arch)"; [ -z "$arch" ] && return 1
    tag="$(github_latest_tag sharkdp/fd)"; [ -z "$tag" ] && return 1
    target="${arch}-unknown-linux-musl"
    install_tarball_binary \
        "https://github.com/sharkdp/fd/releases/download/${tag}/fd-${tag}-${target}.tar.gz" \
        fd fd
}

# Prebuilt lsd: lsd-rs ships musl binaries for both arches (tags are vX.Y.Z).
# musl is statically linked, so it runs on any glibc version / distro.
install_lsd_prebuilt() {
    local arch tag target
    arch="$(host_arch)"; [ -z "$arch" ] && return 1
    tag="$(github_latest_tag lsd-rs/lsd)"; [ -z "$tag" ] && return 1
    target="${arch}-unknown-linux-musl"
    install_tarball_binary \
        "https://github.com/lsd-rs/lsd/releases/download/${tag}/lsd-${tag}-${target}.tar.gz" \
        lsd lsd
}

# ──────────────────────────────────────────────────────────────
# Install Alacritty from source on Debian/Ubuntu, following the official
# INSTALL.md (https://github.com/alacritty/alacritty/blob/master/INSTALL.md).
# Alacritty isn't reliably packaged in apt — it's missing from older repos and
# the third-party aslatter PPA lags / breaks across releases — so upstream's
# supported path is a cargo build. We compile the latest release tag, then
# install the binary, terminfo, and desktop entry. Requires the Rust toolchain,
# which the INSTALL_RUST block installs earlier in this script.
# Returns nonzero on any failure so the caller can warn-and-continue.
# ──────────────────────────────────────────────────────────────
install_alacritty_from_source() {
    if ! command -v cargo &>/dev/null; then
        echo "  ❌ cargo not available; cannot build alacritty from source."
        return 1
    fi

    # Build/runtime deps from INSTALL.md (scdoc is for the man pages).
    sudo apt-get install -y cmake g++ pkg-config libfontconfig1-dev \
        libxcb-xfixes0-dev libxkbcommon-dev python3 scdoc || return 1

    local tag src
    tag="$(github_latest_tag alacritty/alacritty)"
    src="$(mktemp -d)" || return 1

    # Shallow-clone the latest release tag (fall back to the default branch if
    # the tag lookup failed).
    if [ -n "$tag" ]; then
        git clone --depth 1 --branch "$tag" \
            https://github.com/alacritty/alacritty.git "$src" || { rm -rf "$src"; return 1; }
    else
        git clone --depth 1 \
            https://github.com/alacritty/alacritty.git "$src" || { rm -rf "$src"; return 1; }
    fi

    ( cd "$src" && cargo build --release ) || { rm -rf "$src"; return 1; }

    # Binary → ~/.local/bin (already on PATH elsewhere), so no sudo needed here.
    mkdir -p "$HOME/.local/bin"
    install -m 0755 "$src/target/release/alacritty" "$HOME/.local/bin/alacritty" \
        || { rm -rf "$src"; return 1; }
    append_to_shell_rc 'export PATH="$HOME/.local/bin:$PATH"'
    export PATH="$HOME/.local/bin:$PATH"

    # Terminfo so TERM=alacritty works. Run as a normal user, tic installs to
    # ~/.terminfo, so no sudo is required.
    if command -v tic &>/dev/null; then
        tic -xe alacritty,alacritty-direct "$src/extra/alacritty.info" 2>/dev/null \
            || echo "  ⚠️  Could not install alacritty terminfo; continuing."
    fi

    # Desktop entry + icon so it shows up in app launchers (needs sudo; best
    # effort — a headless box may lack desktop-file-utils).
    if [ -f "$src/extra/linux/Alacritty.desktop" ]; then
        sudo cp "$src/extra/logo/alacritty-term.svg" /usr/share/pixmaps/Alacritty.svg 2>/dev/null || true
        sudo desktop-file-install "$src/extra/linux/Alacritty.desktop" 2>/dev/null || true
        sudo update-desktop-database 2>/dev/null || true
    fi

    rm -rf "$src"
    return 0
}

# ──────────────────────────────────────────────────────────────
# Helper: install a CLI tool that also ships as a Rust crate. Tries the OS
# package manager first (via pkg_install), then an optional prebuilt binary,
# then falls back to `cargo install`. cargo builds from source, so it works on
# any arch/libc as long as the Rust toolchain is present (it is by the time
# these run — see the INSTALL_RUST block), but it's the slowest and most
# fragile path — hence prebuilt is preferred when available. Returns nonzero if
# no path works, so a single unavailable tool never aborts the whole install.
#   $1 = OS package name   $2 = cargo crate name   $3 = prebuilt installer fn (optional)
# ──────────────────────────────────────────────────────────────
install_rust_cli() {
    local pkg="$1" crate="$2" prebuilt_fn="${3:-}"
    if pkg_install "$pkg"; then
        return 0
    fi
    echo "  ⚠️  '$pkg' unavailable via $PKG_MANAGER."
    if [ "$IS_MACOS" != true ] && [ -n "$prebuilt_fn" ]; then
        echo "  📥 Trying prebuilt binary for $pkg..."
        if "$prebuilt_fn"; then
            echo "  ✔ Installed $pkg from a prebuilt binary"
            return 0
        fi
        echo "  ⚠️  No usable prebuilt binary for $pkg."
    fi
    if command -v cargo &>/dev/null; then
        echo "  📥 Falling back to: cargo install $crate"
        cargo install "$crate" && return 0
    fi
    echo "  ❌ Could not install '$pkg' (no cargo for fallback). Skipping."
    return 1
}

# Function to install dependencies from a dependencies file
install_dependencies() {
    local dir="$1"
    local deps_file="$dir/dependencies"
    
    if [ ! -f "$deps_file" ]; then
        return
    fi
    
    local dir_name
    dir_name=$(basename "$dir")
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
            pkg_install "$dep" || echo "  ⚠️  Could not install $dep; continuing."
        fi
    done < "$deps_file"
}

echo "🚀 Starting dotfiles installation..."

# Detect operating system and package manager
IS_MACOS=false
if [[ "$(uname)" == "Darwin" ]]; then
    IS_MACOS=true
    PKG_MANAGER="brew"
    INSTALL_CMD="brew install"

    # Install Homebrew if it isn't present yet.
    if ! command -v brew &>/dev/null; then
        echo "🍺 Homebrew not found. Installing Homebrew..."
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    # Load brew into the current shell session (Apple Silicon vs Intel paths).
    if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
elif command -v apt-get &>/dev/null; then
    PKG_MANAGER="apt-get"
    INSTALL_CMD="sudo apt-get install -y"
elif command -v dnf &>/dev/null; then
    PKG_MANAGER="dnf"
    INSTALL_CMD="sudo dnf install -y"
elif command -v pacman &>/dev/null; then
    PKG_MANAGER="pacman"
    INSTALL_CMD="sudo pacman -S --noconfirm"
else
    echo "❌ Unsupported package manager (need brew, apt-get, dnf, or pacman)"
    exit 1
fi

echo "📦 Detected package manager: $PKG_MANAGER"

# Update package lists
echo "📥 Updating package lists..."
if [ "$PKG_MANAGER" = "apt-get" ]; then
    sudo apt-get update
elif [ "$PKG_MANAGER" = "brew" ]; then
    brew update
fi

# Install zsh
if [ "$INSTALL_ZSH" = true ]; then
    echo "🐚 Installing zsh..."
    pkg_install zsh

    # Make zsh the default shell
    echo "🔧 Setting zsh as default shell..."
    zsh_path="$(command -v zsh)"
    if [ "$SHELL" != "$zsh_path" ]; then
        # chsh only accepts shells listed in /etc/shells. A brew-installed
        # zsh (e.g. /opt/homebrew/bin/zsh) usually isn't there yet.
        if [ -n "$zsh_path" ] && ! grep -qxF "$zsh_path" /etc/shells 2>/dev/null; then
            echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
        fi
        if chsh -s "$zsh_path"; then
            echo "✔ zsh is now the default shell (will take effect on next login)"
        else
            echo "⚠️  Could not change default shell automatically; run: chsh -s $zsh_path"
        fi
    else
        echo "✔ zsh is already the default shell"
    fi
fi

# Install build dependencies
echo "🔨 Installing build dependencies..."
# jq + unzip are needed by fonts.sh; curl/git are needed throughout.
if [ "$PKG_MANAGER" = "apt-get" ]; then
    # build-essential pulls in g++, which depends on the libstdc++-N-dev that
    # matches this release's GCC. The version isn't stable across Ubuntu
    # releases (10 on 20.04, 12 on 22.04, 14 on 24.04...), so don't hardcode it.
    # Pick the highest libstdc++-*-dev apt actually offers; fall back to letting
    # build-essential pull its own if none is found explicitly.
    libstdcxx_dev=$(apt-cache --names-only search '^libstdc\+\+-[0-9]+-dev$' 2>/dev/null \
        | awk '{print $1}' | sort -V | tail -n1)
    pkg_install build-essential ${libstdcxx_dev:-} curl git unzip jq
elif [ "$PKG_MANAGER" = "dnf" ]; then
    pkg_install gcc gcc-c++ make libstdc++-devel curl git unzip jq
elif [ "$PKG_MANAGER" = "pacman" ]; then
    pkg_install base-devel curl git unzip jq
elif [ "$PKG_MANAGER" = "brew" ]; then
    # Compiler toolchain comes from the Xcode Command Line Tools.
    # Returns non-zero if already installed, so don't let set -e abort.
    xcode-select --install 2>/dev/null || true
    pkg_install curl git unzip jq
fi

# Bootstrap the zsh configuration.
# This must run BEFORE any append_to_shell_rc / append_block_to_shell_rcs call
# below, because init.sh moves ZDOTDIR to the repo's zsh config. From that point
# on zsh reads $ZDOTDIR/.zshrc and ignores $HOME/.zshrc, so we repoint ZSH_RC
# at the file zsh will actually read. It runs after build deps so curl/git are
# available for the starship installer fallback.
if [ "$INSTALL_ZSH" = true ]; then
    if [ -f "$DOTFILES_DIR/config/zsh/init.sh" ]; then
        echo "🔧 Running zsh initialization (config/zsh/init.sh)..."
        bash "$DOTFILES_DIR/config/zsh/init.sh"
        ZSH_RC="$CONFIG_DIR/zsh/.zshrc"
        ZSH_PROFILE="$CONFIG_DIR/zsh/.zprofile"
        echo "✔ zsh initialized; env → $ZSH_PROFILE, functions → $ZSH_RC"
    else
        echo "⚠️  config/zsh/init.sh not found, skipping zsh bootstrap"
    fi
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
    # Package is named "ripgrep" on every supported manager. If the repo can't
    # provide it, prefer a prebuilt binary (BurntSushi ships them) and only fall
    # back to `cargo install ripgrep` (binary: rg) as a last resort — building
    # regex-syntax from source can segfault rustc on small aarch64 VMs.
    install_rust_cli ripgrep ripgrep install_ripgrep_prebuilt
fi

# Install fd
if [ "$INSTALL_FD" = true ]; then
    echo "🔎 Installing fd..."
    fd_ok=false
    if [ "$PKG_MANAGER" = "apt-get" ]; then
        # Debian/Ubuntu ship the binary as "fdfind"; symlink it to "fd".
        if pkg_install fd-find; then
            fd_ok=true
            mkdir -p "$HOME/.local/bin"
            if [ -x /usr/bin/fdfind ] && [ ! -e "$HOME/.local/bin/fd" ]; then
                ln -s /usr/bin/fdfind "$HOME/.local/bin/fd"
            fi
            append_to_shell_rc 'export PATH="$HOME/.local/bin:$PATH"'
        fi
    elif [ "$PKG_MANAGER" = "dnf" ]; then
        pkg_install fd-find && fd_ok=true
    elif [ "$PKG_MANAGER" = "pacman" ] || [ "$PKG_MANAGER" = "brew" ]; then
        pkg_install fd && fd_ok=true
    fi

    # Fallbacks when the package manager couldn't provide fd. Prefer a prebuilt
    # binary (avoids a from-source cargo build that can segfault rustc on small
    # aarch64 VMs); the "fd-find" crate installs a binary named "fd" straight
    # into ~/.cargo/bin (already on PATH), so no symlink dance is needed there.
    if [ "$fd_ok" != true ]; then
        echo "  ⚠️  fd unavailable via $PKG_MANAGER."
        if [ "$IS_MACOS" != true ]; then
            echo "  📥 Trying prebuilt binary for fd..."
            if install_fd_prebuilt; then
                echo "  ✔ Installed fd from a prebuilt binary"
                fd_ok=true
            else
                echo "  ⚠️  No usable prebuilt binary for fd."
            fi
        fi
    fi
    if [ "$fd_ok" != true ]; then
        if command -v cargo &>/dev/null; then
            echo "  📥 Falling back to: cargo install fd-find"
            cargo install fd-find || echo "  ❌ Could not install fd. Skipping."
        else
            echo "  ❌ Could not install fd (no cargo for fallback). Skipping."
        fi
    fi
fi

# Install tmux
if [ "$INSTALL_TMUX" = true ]; then
    echo "🖥️  Installing tmux..."
    pkg_install tmux || echo "  ⚠️  Could not install tmux; continuing."
fi

# Install fzf
if [ "$INSTALL_FZF" = true ]; then
    echo "🔍 Installing fzf..."
    # Package is named "fzf" on every supported manager. When the repo lacks it
    # (older Debian/Ubuntu), fall back to the upstream git installer, which
    # fetches a prebuilt binary into ~/.fzf/bin.
    if ! pkg_install fzf; then
        echo "  ⚠️  fzf unavailable via $PKG_MANAGER; installing from git..."
        if [ ! -d "$HOME/.fzf" ]; then
            git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
        fi
        "$HOME/.fzf/install" --bin --no-update-rc
        mkdir -p "$HOME/.local/bin"
        ln -sf "$HOME/.fzf/bin/fzf" "$HOME/.local/bin/fzf"
        append_to_shell_rc 'export PATH="$HOME/.local/bin:$PATH"'
    fi
fi

# Install polybar (X11-only, not available on macOS)
if [ "$INSTALL_POLYBAR" = true ]; then
    if [ "$IS_MACOS" = true ]; then
        echo "⏭️  Skipping polybar (Linux/X11-only, not available on macOS)"
    else
        echo "🪟 Installing polybar..."
        pkg_install polybar || echo "  ⚠️  Could not install polybar; continuing."
    fi
fi

# Install i3 (X11-only, not available on macOS)
if [ "$INSTALL_I3" = true ]; then
    if [ "$IS_MACOS" = true ]; then
        echo "⏭️  Skipping i3 (Linux/X11-only, not available on macOS)"
    else
        echo "🪟 Installing i3..."
        if [ "$PKG_MANAGER" = "pacman" ]; then
            pkg_install i3-wm || echo "  ⚠️  Could not install i3-wm; continuing."
        else
            pkg_install i3 || echo "  ⚠️  Could not install i3; continuing."
        fi
    fi
fi

# Install alacritty
if [ "$INSTALL_ALACRITTY" = true ]; then
    echo "💻 Installing alacritty..."
    if [ "$PKG_MANAGER" = "brew" ]; then
        # On macOS alacritty is distributed as a cask.
        brew install --cask alacritty
    elif [ "$PKG_MANAGER" = "apt-get" ]; then
        # Alacritty has no official Debian/Ubuntu package, so follow upstream's
        # INSTALL.md and build it from source with cargo (installs the binary,
        # terminfo, and desktop entry). See install_alacritty_from_source above.
        if install_alacritty_from_source; then
            echo "✔ alacritty built from source and installed"
        else
            echo "  ⚠️  Could not build alacritty from source; continuing."
        fi
    else
        pkg_install alacritty || echo "  ⚠️  Could not install alacritty; continuing."
    fi
fi

# Install rofi (X11-only, not available on macOS)
if [ "$INSTALL_ROFI" = true ]; then
    if [ "$IS_MACOS" = true ]; then
        echo "⏭️  Skipping rofi (Linux/X11-only, not available on macOS)"
    else
        echo "🚀 Installing rofi..."
        pkg_install rofi || echo "  ⚠️  Could not install rofi; continuing."
    fi
fi

# Install lsd
if [ "$INSTALL_LSD" = true ]; then
    echo "🚀 Installing lsd..."
    # Repo package first, then a prebuilt binary (lsd-rs ships static musl
    # builds), then the "lsd" crate (binary: lsd) as a from-source last resort.
    install_rust_cli lsd lsd install_lsd_prebuilt
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

    # zsh is wired up by config/zsh/init.sh (symlinks ~/.config/zsh and
    # ~/.zshenv). Don't double-link it here — that would back up init.sh's
    # symlink to zsh.bak and relink it needlessly.
    if [ "$name" = "zsh" ] && [ "$INSTALL_ZSH" = true ]; then
        echo "  Skipping zsh (handled by config/zsh/init.sh)"
        continue
    fi

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

# Run polybar init script (Linux/X11-only)
if [ "$INSTALL_POLYBAR" = true ] && [ "$IS_MACOS" != true ]; then
    if [ -f "$CONFIG_DIR/polybar/init.sh" ]; then
        echo "🔧 Running polybar initialization..."
        bash "$CONFIG_DIR/polybar/init.sh"
        echo "✔ polybar initialized"
    else
        echo "⚠️  polybar init.sh not found, skipping"
    fi
fi

# Run i3 init script (Linux/X11-only)
if [ "$INSTALL_I3" = true ] && [ "$IS_MACOS" != true ]; then
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
if [ "$INSTALL_ZSH" = true ]; then
    echo "  • zsh now reads its config from \$ZDOTDIR ($CONFIG_DIR/zsh, a"
    echo "    symlink to this repo). PATH/exports went into $ZSH_PROFILE and"
    echo "    shell functions into $ZSH_RC."
fi
echo ""
echo "🔄 Please restart your terminal or run: exec zsh"
