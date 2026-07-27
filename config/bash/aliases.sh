# Sourced from ~/.bashrc — see scripts/apply-settings.sh

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'
alias cleanup-vscode='ls -dt ~/.vscode-server/code-* | tail -n +2 | xargs rm -rf'
alias sc='DISPLAY=:0 xclip -selection clipboard < /tmp/screen-exchange'

assh() {
  local host="${1:-ws02}"
  local target
  local resolved_hostname

  local ssh_config
  ssh_config=$(ssh -G "$host" 2>/dev/null)
  resolved_hostname=$(awk '/^hostname / { print $2; exit }' <<< "$ssh_config")
  local proxyjump
  proxyjump=$(awk '/^proxyjump / { print $2; exit }' <<< "$ssh_config")

  if [[ "$resolved_hostname" == *"lightning.ai"* ]]; then
    target="/teamspace/studios/this_studio"
  elif [[ "$resolved_hostname" == *"rwth"* || "$resolved_hostname" == *"hpc"* || "$proxyjump" == "hpc" ]]; then
    target="/home/yn030245"
  else
    echo "assh: unknown host type for '$host' (resolved: ${resolved_hostname:-unresolved})" >&2
    return 1
  fi

  if [[ -n "$3" ]]; then
    code -r --remote "ssh-remote+$host" "$target/$2" "$target/$3"
  else
    code --remote "ssh-remote+$host" "$target/$2"
  fi
}
