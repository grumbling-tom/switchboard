# Switchboard's look: walnut and brass, with a lamp for every Claude pane. hooks/load_tmux.sh
# loads it after switchboard.tmux unless ~/.claude/switchboard-theme-off exists.

set -g @switchboard_theme on
set -s terminal-features[90] '*:RGB'

# Lamp codes: red, blocked mid-turn (permission or question); amber, turn finished; both
# flash until the pane is seen. Green, working; dim diamond, stuck; hollow brass, waiting
# on a background job or a scheduled wakeup.
set -g @switchboard_lamp_glyph '#{?#{||:#{==:#{@claude_state},permission},#{==:#{@claude_state},question}},#[fg=#ff4a2e]#{?@switchboard_seen,,#[blink]}◉#[noblink],#{?#{||:#{==:#{@claude_state},done},#{@switchboard_expired}},#[fg=#ffb000]#{?@switchboard_seen,,#[blink]}◉#[noblink],#{?#{==:#{@claude_state},working},#{?@switchboard_stuck,#[fg=#8a7f6e]◇,#[fg=#7fbf6a]●},#{?#{||:#{==:#{@claude_state},background},#{==:#{@claude_state},scheduled}},#[fg=#b08d57]○,}}}}'
# A pane's lamp, or nothing when the pane isn't running Claude
set -g @switchboard_lamp '#{?#{m/r:^(claude|[0-9]+\.[0-9]+\.[0-9]+)$,#{pane_current_command}},#{E:@switchboard_lamp_glyph},}'

# Status bar: walnut panel, brass nameplate, each window's lamps after its name in pane order
set -g status-style 'bg=#2b1d14,fg=#efe6d2'
set -g status-left '#[fg=#2b1d14,bg=#b08d57,bold] SWITCHBOARD #[default] '
set -g status-left-length 20
set -g window-status-separator '  '
set -g window-status-format '#[fg=#b08d57]#I #[fg=#a99c85]#W #{P:#{E:@switchboard_lamp}}#[default]'
set -g window-status-current-format '#[fg=#d8b77c,bold]#I #W #{P:#{E:@switchboard_lamp}}#[default]'
set -g status-right '#[range=user|waiting]#(@SWITCHBOARD_ROOT@/hooks/claude_waiting.sh waiting)#[norange]#[fg=#b08d57]┃#[fg=#efe6d2] %H:%M '

# Pane borders: heavy brass on the active pane, walnut on the rest. The title starts with
# the pane's lamp; a worker waiting on you says WAITING.
set -g pane-border-lines heavy
set -g pane-border-style 'fg=#4a3424'
set -g pane-active-border-style 'fg=#d8b77c'
set -g pane-border-format ' #{E:@switchboard_lamp}#[fg=#d8b77c] #{pane_index} #[fg=#b08d57]┃ #[fg=#efe6d2]#{?@pane_label,#{@pane_label},#{pane_current_command}}#{?#{&&:#{==:#{@claude_role},worker},#{||:#{||:#{==:#{@claude_state},permission},#{==:#{@claude_state},question}},#{||:#{==:#{@claude_state},done},#{@switchboard_expired}}}}, #[fg=#b08d57]┃ #[fg=#ff4a2e]#[bold]WAITING#[nobold],}#{?#{==:#{@claude_role},worker}, #[fg=#b08d57]┃ ⚙,} '

# Popups (the picker): double brass rim on a dark board
set -g popup-style 'bg=#15100b'
set -g popup-border-style 'fg=#b08d57'
set -g popup-border-lines double

# Messages and copy-mode selection on a brass strip
set -g message-style 'bg=#b08d57,fg=#2b1d14,bold'
set -g mode-style 'bg=#b08d57,fg=#2b1d14'
