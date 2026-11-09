# Switchboard's tmux lines. hooks/loadTmux.sh swaps @SWITCHBOARD_ROOT@ for the plugin's folder,
# writes the result to ~/.local/state/switchboard/switchboard.tmux and sources it.

set -g pane-border-status top
set -g pane-border-format '#{?#{==:#{@claude_state},background}, 🔄,#{?#{&&:#{@claude_state},#{!=:#{@claude_state},working}},#{?#{==:#{@claude_role},worker},#[fg=red bold] ⏳ WAITING#[default], 💬},}}#{?#{==:#{@claude_role},worker}, ⚙,} #[bold]#{pane_index}#[nobold]: #{?@pane_label,#{@pane_label},#{pane_current_command}} '
# Override a pane's label: prefix + t
bind t command-prompt -p "Pane title:" "set-option -p @pane_manual '%%'"

set -g status-interval 5
set -g status-right-length 80
set -g status-right '#[range=user|waiting]#(@SWITCHBOARD_ROOT@/hooks/claudeWaiting.sh status)#[norange]%H:%M '
# Pick a Claude session, with a live preview of its pane: click the counts, or prefix + j
bind j display-popup -E -w 90% -h 80% -T ' Claude sessions ' '@SWITCHBOARD_ROOT@/hooks/claudeWaiting.sh picker'
bind -n MouseDown1Status if -F '#{==:#{mouse_status_range},waiting}' "display-popup -E -w 90% -h 80% -T ' Claude sessions ' '@SWITCHBOARD_ROOT@/hooks/claudeWaiting.sh picker'" 'switch-client -t ='

# Unnamed windows running Claude show the folder: Claude reports its version as the command
set -g automatic-rename-format '#{?pane_in_mode,[tmux],#{?#{m/r:^[0-9]+\.[0-9]+\.[0-9]+$,#{pane_current_command}},#{b:pane_current_path},#{pane_current_command}}}#{?pane_dead,[dead],}'

# Flip the current Claude pane between worker and orchestrator for the session stats: prefix + r
bind r if -F '#{==:#{@claude_role},worker}' 'set -p @claude_role orchestrator ; display-message "Claude role: orchestrator"' 'set -p @claude_role worker ; display-message "Claude role: worker"'
