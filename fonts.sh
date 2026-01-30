#!/usr/bin/env bash
set -euo pipefail

# Which font should become the system default after installation?
# Set to the full family name exactly as the Nerd Font provides, e.g.
# default="Iosevka Nerd Font"
# Leave empty to skip changing the system default font.
default="Terminess"

FONTS=(
  "BlexMono"
  "Terminess"
  "Iosevka"
  "Monaspice"
)

# Icons used in log output. Unicode chosen for clarity in terminals.
ICON_OK="✔"
ICON_FAIL="✖"

cleanup_cursor() {
  tput cnorm -- normal 2>/dev/null || printf "\e[?25h"
}
trap cleanup_cursor EXIT INT TERM

if [[ "$(uname)" == "Darwin" ]]; then
  DEST_DIR="$HOME/Library/Fonts"
else
  DEST_DIR="$HOME/.local/share/fonts/nerd-fonts"
fi
TMPDIR=$(mktemp -d)
mkdir -p "$DEST_DIR"

echo "🔧 Running fonts initialization..."
echo "Installing fonts to: $DEST_DIR"
echo "Using temporary dir: $TMPDIR"

FONTS_JSON="$TMPDIR/fonts.json"

init_fonts_data() {
  local json_url="https://raw.githubusercontent.com/ryanoasis/nerd-fonts/master/bin/scripts/lib/fonts.json"
  echo "  Downloading fonts metadata..."
  if ! curl --silent --show-error --fail -L -o "$FONTS_JSON" "$json_url"; then
    echo "  Failed to download fonts.json metadata. Falling back to simple name usage."
    FONTS_JSON=""
  fi
}

get_font_download_url() {
  local name="$1"
  local folder_name=""

  # If we have the metadata, try to find the correct folder name (asset name)
  if [ -n "$FONTS_JSON" ] && [ -f "$FONTS_JSON" ]; then
    folder_name=$(jq -r --arg name "$name" '.fonts[] | select(.patchedName == $name or .folderName == $name) | .folderName' "$FONTS_JSON" | head -n 1)
  fi

  # Fallback: if not found or no json, assume the name provided is the asset name
  if [ -z "$folder_name" ]; then
    folder_name="$name"
  fi

  echo "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${folder_name}.zip"
}

init_fonts_data

download_and_extract() {
  local name="$1"
  local url
  url=$(get_font_download_url "$name")
  local asset
  asset=$(basename "$url")

  # Run the download and extraction in the background
  (
    # Redirect stdout/stderr to null, errors captured to files
    exec >/dev/null 2>&1

    # Download
    if ! curl --silent --show-error --fail -L -o "$TMPDIR/$asset" "$url" 2>"$TMPDIR/${name}.curl.err"; then
      exit 10
    fi

    # Extract
    if ! unzip -q -o "$TMPDIR/$asset" -d "$TMPDIR/$name"; then
      exit 11
    fi

    # Install
    find "$TMPDIR/$name" -type f \( -iname '*.ttf' -o -iname '*.otf' \) -print0 | xargs -0 -I{} cp -f "{}" "$DEST_DIR/"
  ) &
  local pid=$!

  # Animation loop
  local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  tput civis -- invisible 2>/dev/null || printf "\e[?25l"

  while kill -0 "$pid" 2>/dev/null; do
    local frame="${spinstr:0:1}"
    printf "\r  [%s] %s" "$frame" "$name"
    spinstr="${spinstr:1}${spinstr:0:1}"
    sleep 0.1
  done

  tput cnorm -- normal 2>/dev/null || printf "\e[?25h"
  wait "$pid"
  local exit_code=$?

  # Clear the line to prepare for final status
  printf "\r\033[K"

  if [ $exit_code -eq 0 ]; then
    # Count installed files from the extraction dir
    local count
    count=$(find "$TMPDIR/$name" -type f \( -iname '*.ttf' -o -iname '*.otf' \) | wc -l | tr -d ' ')
    printf "  [%s] %s - installed %d font(s)\n" "$ICON_OK" "$name" "$count"
    return 0
  elif [ $exit_code -eq 10 ]; then
    local err
    err=$(cat "$TMPDIR/${name}.curl.err" 2>/dev/null || echo "download failed")
    printf "  [%s] %s - %s\n" "$ICON_FAIL" "$name" "$err"
    return 1
  elif [ $exit_code -eq 11 ]; then
    printf "  [%s] %s - failed to extract %s\n" "$ICON_FAIL" "$name" "$asset"
    return 1
  else
    printf "  [%s] %s - unknown error\n" "$ICON_FAIL" "$name"
    return 1
  fi
}

is_installed() {
  local name="$1"
  if [ -d "$DEST_DIR" ] && find "$DEST_DIR" -type f \( -iname "*${name}*.ttf" -o -iname "*${name}*.otf" \) -print -quit | grep -q .; then
    return 0
  fi
  return 1
}

for f in "${FONTS[@]}"; do
  if is_installed "$f"; then
    printf "  [%s] %s - already installed\n" "$ICON_OK" "$f"
    continue
  fi
  download_and_extract "$f" || true
done

echo "Refreshing font cache..."
if command -v fc-cache >/dev/null 2>&1; then
  fc-cache -fv "$DEST_DIR" || fc-cache -fv || true
else
  echo "fc-cache not found, skipping..."
fi

# If default is empty, don't try to change the system font
if [ -z "${default}" ]; then
  echo "No default font requested (variable 'default' is empty) — skipping system font change."
  rm -rf "$TMPDIR"
  exit 0
fi

# Look for an installed font file that contains the requested default name
installed_match=$(find "$DEST_DIR" -type f \( -iname '*.ttf' -o -iname '*.otf' \) -print0 | xargs -0 -n1 basename | grep -iF -- "$default" || true)

if [ -z "$installed_match" ]; then
  echo "Requested default font '$default' was not found in $DEST_DIR — not changing system font."
  rm -rf "$TMPDIR"
  exit 0
fi

echo "Found installed files matching default font:"
echo "$installed_match"

# Try GNOME gsettings if available
if command -v gsettings >/dev/null 2>&1; then
  # gsettings font keys require a size. Use 11 as a sensible default.
  gsettings set org.gnome.desktop.interface font-name "${default} 11" || true
  gsettings set org.gnome.desktop.interface monospace-font-name "${default} 11" || true
  echo "Tried to set GNOME fonts to '${default} 11' (if GNOME is in use)."
else
  echo "gsettings not found — script cannot set DE font defaults automatically."
  echo "If you use GNOME, install 'gsettings' or set the font in your DE settings."
fi

rm -rf "$TMPDIR"
echo "Done. Installed fonts are in: $DEST_DIR"
