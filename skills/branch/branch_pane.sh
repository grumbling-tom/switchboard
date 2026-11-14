#!/bin/bash
# /sb:branch: copies this conversation into a new Claude session in a tmux pane
# split beside this one, like /branch but leaving this session where it is. The new pane
# starts in the directory Claude was launched from and takes this pane's role.
TMUX_BIN=$(command -v tmux || echo /opt/homebrew/bin/tmux)

if [ -z "$TMUX_PANE" ]; then
    echo "Not inside tmux, so there's no pane to split. Use /branch instead." >&2
    exit 1
fi
if [ -z "$CLAUDE_CODE_SESSION_ID" ]; then
    echo "CLAUDE_CODE_SESSION_ID isn't set, so there's no session to copy." >&2
    exit 1
fi

role=$("$TMUX_BIN" display -p -t "$TMUX_PANE" '#{@claude_role}')
new_pane=$("$TMUX_BIN" split-window -h -P -F '#{pane_id}' -t "$TMUX_PANE" \
    -c '#{pane_current_path}' -e "CLAUDE_SESSION_ROLE=${role:-orchestrator}" \
    "claude --resume '$CLAUDE_CODE_SESSION_ID' --fork-session") || exit 1

echo "Branched this conversation into pane $new_pane."
