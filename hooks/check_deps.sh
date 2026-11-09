#!/bin/bash
# SessionStart hook: warns about missing tools. Never installs anything.
[ -n "$TMUX" ] || exit 0

warnings=()
missing() {
    warnings+=("$1 is missing, so $2. Install it with: $3")
}

command -v tmux >/dev/null || missing tmux "nothing in switchboard works" "brew install tmux"
command -v jq >/dev/null || missing jq "pane labels, the event log and notification text stay empty" "brew install jq"
command -v fzf >/dev/null || missing fzf "prefix + j won't open the picker" "brew install fzf"

# Without the Command Line Tools, /usr/bin/python3 is a stub that opens Apple's install
# prompt, so check for the tools rather than running it.
pythonPath=$(command -v python3)
if [ -z "$pythonPath" ] || { [ "$pythonPath" = /usr/bin/python3 ] && ! xcode-select -p >/dev/null 2>&1; }; then
    missing python3 "background jobs aren't detected, so a session waiting on one counts as waiting on you" "xcode-select --install"
fi

if [ ! -e ~/.claude/notify-off ]; then
    command -v alerter >/dev/null || missing alerter "you get no notification when a session waits on you" "brew install vjeantet/tap/alerter"
fi

[ ${#warnings[@]} -eq 0 ] && exit 0
message="switchboard:"
for warning in "${warnings[@]}"; do
    message+=$'\n'"- $warning"
done
jq -n --arg message "$message" '{systemMessage: $message}' 2>/dev/null ||
    printf '{"systemMessage": "switchboard: jq is missing, so pane labels, the event log and notification text stay empty. Install it with: brew install jq"}\n'
exit 0
