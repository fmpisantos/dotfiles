#!/bin/bash
# Workspace auto-launcher for i3
# This script monitors workspace changes and launches apps if they're not running

# Use a file-based lock system instead of array in subshell
LOCK_DIR="/tmp/i3-workspace-launcher"
mkdir -p "$LOCK_DIR"

check_and_launch() {
    local workspace=$1
    local check_class=$2
    local launch_cmd=$3
    local lock_file="$LOCK_DIR/$workspace.lock"
    
    # Get current workspace
    current_ws=$(i3-msg -t get_workspaces | jq -r '.[] | select(.focused==true).name')
    
    # Only proceed if we're on the target workspace
    if [ "$current_ws" != "$workspace" ]; then
        return
    fi
    
    # Check if we have a recent lock (launch in progress)
    if [ -f "$lock_file" ]; then
        # Check if lock is older than 5 seconds
        if [ $(($(date +%s) - $(stat -c %Y "$lock_file" 2>/dev/null || echo 0))) -lt 5 ]; then
            return
        fi
        # Old lock, remove it
        rm -f "$lock_file"
    fi
    
    # Check if any window with the specified class exists on this workspace
    window_count=$(i3-msg -t get_tree | jq -r "
        .. | 
        select(.type? == \"workspace\" and .name? == \"$workspace\") | 
        .. | 
        select(.window_properties?.class? != null) | 
        select(.window_properties.class | test(\"$check_class\"; \"i\")) | 
        .id" | wc -l)
    
    # If no matching window found, launch the application
    if [ "$window_count" -eq 0 ]; then
        # Create lock file
        touch "$lock_file"
        
        # Launch app in background
        eval "$launch_cmd" &
        
        # Remove lock after delay (in background)
        (sleep 5 && rm -f "$lock_file") &
    fi
}

# Clean up lock files on exit
trap "rm -f $LOCK_DIR/*.lock" EXIT

# Listen to workspace events
i3-msg -t subscribe -m '["workspace"]' | while read -r event; do
    # Only process focus changes
    change=$(echo "$event" | jq -r '.change')
    if [ "$change" != "focus" ]; then
        continue
    fi
    
    # Get the workspace that was focused
    workspace=$(echo "$event" | jq -r '.current.name')
    
    case "$workspace" in
        "T")
            # Terminal workspace - check for alacritty
            check_and_launch "T" "alacritty" "alacritty"
            ;;
        "B")
            # Browser workspace - check for Edge
            check_and_launch "B" "microsoft-edge" "microsoft-edge"
            ;;
        "P")
            # Postman workspace
            check_and_launch "P" "Postman" "postman"
            ;;
        "3")
            # Outlook on Edge workspace
            check_and_launch "3" "microsoft-edge.*outlook" "microsoft-edge --app=https://outlook.office.com"
            ;;
        "4")
            # Teams on Edge workspace
            check_and_launch "4" "microsoft-edge.*teams" "microsoft-edge --app=https://teams.microsoft.com"
            ;;
    esac
done
