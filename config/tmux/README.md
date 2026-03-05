# Usage:
## Script
    ```bash
    chmod +x init.sh && ./init.sh
    ```
## Manual
    - Move .tmux.conf to ~/
    - Create ~/local/bin if it doesnt exist
    - Move tmux-sessionizer.sh to ~/local/bin
    - ```bash
    chmod +x tmux-sessionizer.sh
    ```
    - tmux source-file ~/.tmux.conf

## Profile
```bash
setxkbmap -option caps:escape
if [[ ! -z "$TMUX" && -n "$SSH_CONNECTION" ]]; then
    tmux attach
else
    first_session=$(tmux list-sessions -F "#{session_id}" | head -n 1)
    if [[ -n "$first_session" ]]; then
        tmux attach-session -t "$first_session"
    else
        tmux new-session -s default
    fi
fi
```
## Install
```bash
sudo apt install fzf
```
