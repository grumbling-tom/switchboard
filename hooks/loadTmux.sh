#!/bin/bash
# SessionStart hook: loads tmux/switchboard.tmux into the tmux server this session runs in.
[ -n "$TMUX" ] || exit 0
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
generated=~/.local/state/switchboard/switchboard.tmux
mkdir -p "$(dirname "$generated")"
sed "s|@SWITCHBOARD_ROOT@|$root|g" "$root/tmux/switchboard.tmux" >"$generated"
tmux source-file "$generated" >/dev/null 2>&1
exit 0
