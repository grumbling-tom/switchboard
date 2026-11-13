#!/bin/bash
# SessionStart hook: loads tmux/switchboard.tmux, then the theme while the plugin's
# `theme` setting is on, into the tmux server this session runs in.
[ -n "$TMUX" ] || exit 0
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
generated=~/.local/state/switchboard/switchboard.tmux
mkdir -p "$(dirname "$generated")"
sources=("$root/tmux/switchboard.tmux")
[ "${CLAUDE_PLUGIN_OPTION_THEME:-true}" = true ] && sources+=("$root/tmux/switchboard_theme.tmux")
sed "s|@SWITCHBOARD_ROOT@|$root|g" "${sources[@]}" >"$generated"
tmux source-file "$generated" >/dev/null 2>&1
exit 0
