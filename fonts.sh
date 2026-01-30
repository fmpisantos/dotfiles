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
  "MonaspiceNe"
)

# Icons used in log output. Unicode chosen for clarity in terminals.
ICON_LOADING="⏳"
ICON_OK="✔"
ICON_FAIL="✖"

DEST_DIR="$HOME/.local/share/fonts/nerd-fonts"
TMPDIR=$(mktemp -d)
mkdir -p "$DEST_DIR"

echo "🔧 Running fonts initialization..."
echo "Using temporary dir: $TMPDIR"

download_and_extract() {
  local name="$1"
  local asset="${name}.zip"
  local url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${asset}"

  # Print a compact loading line for this font
  printf "  [%s] %s\n" "$ICON_LOADING" "$name"

  # Download quietly but capture error output so we can show a useful message on failure
  if ! curl --silent --show-error --fail -L -o "$TMPDIR/$asset" "$url" 2>"$TMPDIR/${name}.curl.err"; then
    err=$(cat "$TMPDIR/${name}.curl.err" 2>/dev/null || echo "download failed")
    printf "  [%s] %s - %s\n" "$ICON_FAIL" "$name" "$err"
    return 1
  fi

  # Extract and copy fonts. Suppress per-file verbose output and display a concise success line.
  if ! unzip -q -o "$TMPDIR/$asset" -d "$TMPDIR/$name"; then
    printf "  [%s] %s - failed to extract %s\n" "$ICON_FAIL" "$name" "$asset"
    return 1
  fi

  # Copy font files and count how many were installed
  count=0
  while IFS= read -r -d '' file; do
    cp -f -- "$file" "$DEST_DIR/"
    count=$((count + 1))
  done < <(find "$TMPDIR/$name" -type f \( -iname '*.ttf' -o -iname '*.otf' \) -print0)

  printf "  [%s] %s - installed %d font(s)\n" "$ICON_OK" "$name" "$count"
  return 0
}

for f in "${FONTS[@]}"; do
  download_and_extract "$f" || true
done

echo "Refreshing font cache..."
fc-cache -fv "$DEST_DIR" || fc-cache -fv || true

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
