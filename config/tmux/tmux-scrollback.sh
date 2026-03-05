#!/usr/bin/env bash
set -euo pipefail

tmpfile=$(mktemp /tmp/scrollback.XXXXXX)

tmux capture-pane -S - -E - -b scrollback
tmux save-buffer -b scrollback "$tmpfile"
tmux delete-buffer -b scrollback

# Clean blank lines
awk '/^[[:space:]]*$/{blank++; next} {for(i=0;i<blank;i++)print ""; blank=0; print}' "$tmpfile" > "${tmpfile}.clean"
mv "${tmpfile}.clean" "$tmpfile"

tmux new-window -n "Scrollback" "FROM_WEZTERM=1 nvim + '$tmpfile'; rm -f '$tmpfile'"
