alias vim='nvim'
alias fd='fdfind'

# alias idea='~/snap/idea-IU-252.27397.103/bin/idea >/dev/null 2>&1 &'
alias docker-cleanup='docker stop $(docker ps -aq) && docker rm $(docker ps -aq)'
alias git-search='git log --pretty=format:"%h %s" --abbrev-commit | \
  fzf --no-sort --reverse \
    --preview '\''git show $(echo {} | awk "{print \$1}")'\'' \
    --preview-window=right:70% | \
  awk '\''{print $1}'\'' | \
  xargs git show'

export JDTLS_JVM_ARGS="-javaagent:$HOME/.local/share/nvim/mason/packages/jdtls/lombok.jar"
export JAVA_HOME="$HOME/.jdks/jbrsdk_jcef-17.0.14"
# This will make intune not work
# export JAVA_TOOL_OPTIONS="-Dhttp.nonProxyHosts=\"localhost|127.*|[::1]\""

export EDITOR="nvim"
export VISUAL="nvim"
export PATH="$HOME/snap/idea-IU/current/bin:$PATH"
