# Switchboard's look: walnut and brass, with a lamp for every Claude pane. hooks/load_tmux.sh
# loads it after switchboard.tmux unless ~/.claude/switchboard-theme-off exists.

set -g @switchboard_theme on
set -s terminal-features[90] '*:RGB'

# Lamp codes: red, blocked mid-turn (permission or question); amber, turn finished; both
# pulse until the pane is seen. Green, working; dim diamond, stuck; hollow brass, waiting
# on a background job or a scheduled wakeup.
#
# The pulse steps through five brightness levels and back over eight seconds, one step per
# status redraw, so status-interval is 1. Pane borders aren't redrawn on a timer, so their
# lamps stay steady.
set -g status-interval 1
set -g @switchboard_pulse_level '#{?#{e|<:#{T:@switchboard_pulse_phase},5},#{T:@switchboard_pulse_phase},#{e|-:8,#{T:@switchboard_pulse_phase}}}'
set -g @switchboard_pulse_phase '#{e|m:%S,8}'
set -g @switchboard_red_pulse '#{?#{==:#{E:@switchboard_pulse_level},0},#ff4a2e,#{?#{==:#{E:@switchboard_pulse_level},1},#d84128,#{?#{==:#{E:@switchboard_pulse_level},2},#b13823,#{?#{==:#{E:@switchboard_pulse_level},3},#8b2f1d,#642618}}}}'
set -g @switchboard_amber_pulse '#{?#{==:#{E:@switchboard_pulse_level},0},#ffb000,#{?#{==:#{E:@switchboard_pulse_level},1},#db9703,#{?#{==:#{E:@switchboard_pulse_level},2},#b67e05,#{?#{==:#{E:@switchboard_pulse_level},3},#926508,#6e4c0a}}}}'
set -g @switchboard_is_blocked '#{||:#{==:#{@claude_state},permission},#{==:#{@claude_state},question}}'
set -g @switchboard_is_finished '#{||:#{==:#{@claude_state},done},#{@switchboard_expired}}'
set -g @switchboard_quiet_glyph '#{?#{==:#{@claude_state},working},#{?@switchboard_stuck,#[fg=#8a7f6e]◇,#[fg=#7fbf6a]●},#{?#{||:#{==:#{@claude_state},background},#{==:#{@claude_state},scheduled}},#[fg=#b08d57]○,}}'
set -g @switchboard_is_claude '#{m/r:^(claude|[0-9]+\.[0-9]+\.[0-9]+)$,#{pane_current_command}}'
# A pane's lamp, or nothing when the pane isn't running Claude: pulsing in the status bar
set -g @switchboard_lamp '#{?#{E:@switchboard_is_claude},#{?#{E:@switchboard_is_blocked},#[fg=#{?@switchboard_seen,#ff4a2e,#{E:@switchboard_red_pulse}}]◉,#{?#{E:@switchboard_is_finished},#[fg=#{?@switchboard_seen,#ffb000,#{E:@switchboard_amber_pulse}}]◉,#{E:@switchboard_quiet_glyph}}},}'
# and steady on pane borders
set -g @switchboard_border_lamp '#{?#{E:@switchboard_is_claude},#{?#{E:@switchboard_is_blocked},#[fg=#ff4a2e]◉,#{?#{E:@switchboard_is_finished},#[fg=#ffb000]◉,#{E:@switchboard_quiet_glyph}}},}'

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
set -g pane-border-format ' #{E:@switchboard_border_lamp}#[fg=#d8b77c] #{pane_index} #[fg=#b08d57]┃ #[fg=#efe6d2]#{?@pane_label,#{@pane_label},#{pane_current_command}}#{?#{&&:#{==:#{@claude_role},worker},#{||:#{E:@switchboard_is_blocked},#{E:@switchboard_is_finished}}}, #[fg=#b08d57]┃ #[fg=#ff4a2e]#[bold]WAITING#[nobold],}#{?#{==:#{@claude_role},worker}, #[fg=#b08d57]┃ ⚙,} '

# Popups (the picker): double brass rim on a dark board
set -g popup-style 'bg=#15100b'
set -g popup-border-style 'fg=#b08d57'
set -g popup-border-lines double

# Messages and copy-mode selection on a brass strip
set -g message-style 'bg=#b08d57,fg=#2b1d14,bold'
set -g mode-style 'bg=#b08d57,fg=#2b1d14'
