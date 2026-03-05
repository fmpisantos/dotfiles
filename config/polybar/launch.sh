#!/usr/bin/env sh

killall -q polybar

while pgrep -x polybar >/dev/null; do sleep 0.1; done

for m in $(xrandr --query | grep " connected" | cut -d" " -f1); do
    MONITOR=$m polybar --reload main --config=~/.config/polybar/config.ini &
done

echo "Polybar launched on all connected monitors."
