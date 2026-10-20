# Hush shell integration: a command that ran HUSH_JOB_SECS (default 20) seconds or longer raises a
# card on the island when it ends, unless this terminal is the focused window: a tick or cross, the
# command, how long it took, its exit code, and Open focuses the terminal. Source it from ~/.zshrc
# or ~/.bashrc:  source ~/.config/hush/shell.sh
_hush_window() { hyprctl activewindow -j 2>/dev/null | sed -n 's/.*"address": *"\([^"]*\)".*/\1/p'; }
_hush_job_end() { # exit-code start-epoch command
  local secs=$((EPOCHSECONDS - $2)) took
  [ "$secs" -ge "${HUSH_JOB_SECS:-20}" ] && [ -n "$3" ] || return 0
  [ "$(_hush_window)" != "${_hush_win:-x}" ] || return 0
  if [ "$secs" -ge 60 ]; then took="$((secs / 60)) m $((secs % 60)) s"; else took="$secs s"; fi
  notify-send -a hush -h string:x-hush-kind:job -h "int:x-hush-exit:$1" -h "string:x-hush-window:${_hush_win:-}" -- "$3" "$took" 2>/dev/null
}
if [ -n "${ZSH_VERSION:-}" ]; then
  zmodload zsh/datetime
  # The window is read once, at the first command typed here (the terminal is focused then).
  _hush_preexec() { _hush_cmd=$1; _hush_t0=$EPOCHSECONDS; [ -n "${_hush_win:-}" ] || _hush_win=$(_hush_window); }
  _hush_precmd() { local rc=$?; [ -z "${_hush_t0:-}" ] || _hush_job_end "$rc" "$_hush_t0" "$_hush_cmd"; _hush_t0=; return $rc; }
  autoload -Uz add-zsh-hook
  add-zsh-hook preexec _hush_preexec
  add-zsh-hook precmd _hush_precmd
else
  # bash has no preexec: the command and its start come from its history entry (bash stamps every
  # entry; HISTCONTROL=ignoredups then skips a repeated command). The hook runs first in
  # PROMPT_COMMAND and returns $? so the prompt still sees the command's exit code.
  _hush_precmd() {
    local rc=$? h n=0
    [ -n "${_hush_win:-}" ] || _hush_win=$(_hush_window)
    h=$(HISTTIMEFORMAT='%s ' builtin history 1)
    [[ $h =~ ^\ *([0-9]+)\ +([0-9]+)\ (.*)$ ]] && n=${BASH_REMATCH[1]}
    # The first prompt only records where the history stands (its last entry is an old one).
    [ -z "${_hush_last:-}" ] || [ "$n" = "$_hush_last" ] || _hush_job_end "$rc" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
    _hush_last=$n
    return "$rc"
  }
  PROMPT_COMMAND=(_hush_precmd "${PROMPT_COMMAND[@]}")
fi
