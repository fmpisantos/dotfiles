#!/bin/sh

FILE="$1"

if [ "$(uname)" = "Darwin" ]; then
  sed -i '' '/^$/d' "$FILE"
else
  sed -i '/^$/d' "$FILE"
fi
