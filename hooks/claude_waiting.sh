#!/bin/bash
# Tracks what each Claude session in tmux is doing, and notifies me when one waits on me.
#   mark <reason> — Stop / Notification hooks: reason is done, permission or question;
#                   flag the pane as waiting and post a clickable alert. A finished turn
#                   that left something to wake Claude (a background Bash job, Monitor,
#                   agent or workflow, or a /loop wakeup or cron) is marked background
#                   or scheduled instead, with no alert, until pending_wakers.py's
#                   deadline passes
#   work          — UserPromptSubmit / PostToolUse hooks: flag the pane as working
#   end           — SessionEnd hook: forget the pane
#   status        — tmux status-right: working / stuck / waiting counts
#   picker        — click the counts, or prefix + j (in a tmux popup): fzf list of
#                   sessions with a live preview of the selected pane
# Notifications are skipped while ~/.claude/notify-off exists. Each pane's role,
# @claude_role, is seeded from CLAUDE_SESSION_ROLE (worker) or defaults to orchestrator,
# and is flipped by prefix + r.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TMUX_BIN=$(command -v tmux || echo /opt/homebrew/bin/tmux)
STUCK_AFTER_SECONDS=3600

focus_pane() {
    "$TMUX_BIN" switch-client -t "$1" \; select-window -t "$1" \; select-pane -t "$1"
}

# alerter blocks until the notification is clicked or closed, so each pane keeps
# at most one running in the background, its pid held in @claude_notify_pid.
dismiss_notification() {
    pid=$("$TMUX_BIN" display -p -t "$TMUX_PANE" '#{@claude_notify_pid}')
    [ -n "$pid" ] && pkill -P "$pid" && kill "$pid" 2>/dev/null
    "$TMUX_BIN" set -p -t "$TMUX_PANE" -u @claude_notify_pid
}

set_pane() {
    "$TMUX_BIN" set -p -t "$TMUX_PANE" "$@"
}

# Same "dir [branch]" label the zsh precmd hook writes, which never runs while
# Claude holds the pane; @pane_manual (prefix + t) still wins.
update_label() {
    cwd=$(jq -r '.cwd // empty' <<<"$1" 2>/dev/null)
    [ -d "$cwd" ] || return
    manual=$("$TMUX_BIN" display -p -t "$TMUX_PANE" '#{@pane_manual}')
    if [ -n "$manual" ]; then
        label=$manual
    else
        branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
        label=$(basename "$cwd")${branch:+ [$branch]}
    fi
    set_pane @pane_label "$label"
}

seed_role() {
    role=$("$TMUX_BIN" display -p -t "$TMUX_PANE" '#{@claude_role}')
    [ -n "$role" ] || set_pane @claude_role "${CLAUDE_SESSION_ROLE:-orchestrator}"
}

pending_wakers() {
    transcript=$(jq -r '.transcript_path // empty' <<<"$1" 2>/dev/null)
    [ -f "$transcript" ] && python3 -I "$SCRIPT_DIR/pending_wakers.py" "$transcript" 2>/dev/null
}

reason_icon() {
    case "$1" in
    background) echo "🔄" ;;
    scheduled) echo "⏰" ;;
    permission) echo "🔐" ;;
    question) echo "❓" ;;
    stuck) echo "🟠" ;;
    working) echo "🟢" ;;
    *) echo "✅" ;;
    esac
}

first_line() {
    grep -v -E '^[[:space:]]*(#|---|```)' | sed -e 's/[*`]//g' -e 's/^[> -]*//' | awk 'NF { print; exit }' | cut -c1-180
}

# One line per live Claude pane: state, seconds in that state, pane id, location,
# window name, role, pane label. Claude reports its version as the pane's command, which
# drops panes whose Claude exited without a SessionEnd.
list_sessions() {
    now=$(date +%s)
    "$TMUX_BIN" list-panes -a -F $'#{?@claude_state,#{@claude_state},none}\t#{?@claude_since,#{@claude_since},0}\t#{?@claude_activity,#{@claude_activity},0}\t#{pane_current_command}\t#{pane_id}\t#{session_name}:#{window_index}.#{pane_index}\t#{window_name}\t#{?@claude_role,#{@claude_role},orchestrator}\t#{?@pane_label,#{@pane_label},#{pane_current_command}}\t#{?@claude_waker_deadline,#{@claude_waker_deadline},0}' |
        awk -F'\t' -v OFS='\t' -v now="$now" -v stuck_after="$STUCK_AFTER_SECONDS" '
            $1 == "none" { next }
            $4 !~ /^(claude|[0-9]+\.[0-9]+\.[0-9]+)$/ { next }
            {
                state = $1
                if (state == "working" && now - $3 > stuck_after) state = "stuck"
                if ((state == "background" || state == "scheduled") && $10 > 0 && now > $10) state = "done"
                print state, now - $2, $5, $6, $7, $8, $9
            }'
}

case "$1" in
mark)
    [ -n "$TMUX_PANE" ] || exit 0
    reason=${2:-done}
    input=$(cat)
    update_label "$input"
    if [ "$reason" = "done" ]; then
        read -r waker_state waker_deadline <<<"$(pending_wakers "$input")"
        if [ -n "$waker_state" ]; then
            set_pane @claude_state "$waker_state" \; set -p -t "$TMUX_PANE" @claude_since "$(date +%s)" \; set -p -t "$TMUX_PANE" @claude_waker_deadline "$waker_deadline"
            seed_role
            dismiss_notification
            exit 0
        fi
    fi
    if [ "$reason" = "done" ]; then
        message=$(jq -r '.last_assistant_message // empty' <<<"$input" 2>/dev/null | first_line)
    else
        message=$(jq -r '.message // empty' <<<"$input" 2>/dev/null | first_line)
    fi
    [ -n "$message" ] || message="Waiting for your reply"

    set_pane @claude_state "$reason" \; set -p -t "$TMUX_PANE" @claude_since "$(date +%s)"
    seed_role

    [ -e ~/.claude/notify-off ] && exit 0
    is_pane_visible=$("$TMUX_BIN" display -p -t "$TMUX_PANE" '#{&&:#{window_active},#{pane_active}}')
    front_app=$(lsappinfo info -only name "$(lsappinfo front)" | cut -d'"' -f4)
    [ "$is_pane_visible" = 1 ] && [ "$front_app" = iTerm2 ] && exit 0

    window_name=$("$TMUX_BIN" display -p -t "$TMUX_PANE" '#{window_name}')
    sound_args=()
    [ "$reason" = permission ] && sound_args=(--sound default)
    dismiss_notification
    pane=$TMUX_PANE
    (
        result=$(alerter --title "$(reason_icon "$reason") Claude: $window_name" --message "$message" \
            --group "claude-$pane" "${sound_args[@]}")
        case "$result" in
        @CONTENTCLICKED | @ACTIONCLICKED)
            open -a iTerm
            focus_pane "$pane"
            ;;
        esac
        "$TMUX_BIN" set -p -t "$pane" -u @claude_notify_pid
    ) </dev/null >/dev/null 2>&1 &
    set_pane @claude_notify_pid "$!"
    ;;
work)
    [ -n "$TMUX_PANE" ] || exit 0
    input=$(cat)
    update_label "$input"
    now=$(date +%s)
    state=$("$TMUX_BIN" display -p -t "$TMUX_PANE" '#{@claude_state}')
    if [ "$state" != working ]; then
        set_pane @claude_state working \; set -p -t "$TMUX_PANE" @claude_since "$now"
        seed_role
        dismiss_notification
    fi
    set_pane @claude_activity "$now"
    ;;
end)
    [ -n "$TMUX_PANE" ] || exit 0
    dismiss_notification
    set_pane -u @claude_role \; set -p -t "$TMUX_PANE" -u @claude_state \; set -p -t "$TMUX_PANE" -u @claude_since \; set -p -t "$TMUX_PANE" -u @claude_activity \; set -p -t "$TMUX_PANE" -u @claude_waker_deadline
    ;;
status)
    list_sessions | awk -F'\t' '
        $1 == "working" { working++; next }
        $1 == "stuck" { stuck++; next }
        $1 == "background" { background++; next }
        $1 == "scheduled" { scheduled++; next }
        $6 == "worker" { workers_waiting++; next }
        { orchestrators_open++ }
        END {
            if (working) printf "🟢 %d working ", working
            if (background) printf "🔄 %d background ", background
            if (scheduled) printf "⏰ %d scheduled ", scheduled
            if (stuck) printf "#[bold]🟠 %d stuck? #[nobold]", stuck
            if (workers_waiting) printf "#[fg=red bold]⚙⏳ %d waiting #[default]", workers_waiting
            if (orchestrators_open) printf "💬 %d open ", orchestrators_open
            printf "#[default]"
        }'
    ;;
rows)
    # Groups: workers waiting on me, open orchestrators, (scope all) working or an
    # orchestrator's background job, then workers waiting on a background job.
    # Header rows carry "-" as their pane id; the picker never selects them.
    list_sessions | awk -F'\t' -v OFS='\t' -v scope="$2" '
        function age(seconds,   minutes) {
            minutes = int(seconds / 60)
            return minutes < 60 ? minutes "m" : sprintf("%dh%02d", int(minutes / 60), minutes % 60)
        }
        {
            state = $1; role = $6
            if ((state == "background" || state == "scheduled") && role == "worker") group = 3
            else if (state == "working" || state == "background" || state == "scheduled") { if (scope == "waiting") next; group = 2 }
            else group = (role == "worker") ? 0 : 1
            priority = (state == "permission" || state == "question") ? 0 : (state == "stuck" ? 1 : 2)
            icon = state == "permission" ? "🔐" : state == "question" ? "❓" : state == "stuck" ? "🟠" : state == "working" ? "🟢" : state == "background" ? "🔄" : state == "scheduled" ? "⏰" : "✅"
            tag = (group == 2 && role == "worker") ? "⚙ " : ""
            line = sprintf("%s\t%s %5s  %-24.24s  %s  (%s)", $3, icon, age($2), tag $5, $7, $4)
            print group, priority, $2, line
            count[group]++
        }
        END {
            for (g in count) print g, -1, 0, "COUNT " count[g]
        }' |
        sort -t$'\t' -k1,1n -k2,2n -k3,3nr |
        awk -F'\t' '
            BEGIN {
                title[0] = "⚙ WORKERS WAITING ON YOU"
                title[1] = "💬 OPEN ORCHESTRATORS"
                title[2] = "🟢 WORKING · 🔄 BACKGROUND JOB · ⏰ SCHEDULED"
                title[3] = "🔄 WORKERS WAITING ON BACKGROUND TASKS"
            }
            $2 == -1 {
                sub(/^COUNT /, "", $4)
                printf "-\t\033[1m── %s (%s) ──\033[0m\n", title[$1], $4
                next
            }
            { print $4 "\t" $5 }'
    ;;
preview)
    [ "$2" = - ] && exit 0
    "$TMUX_BIN" capture-pane -e -p -t "$2" |
        awk '{ lines[NR] = $0 } NF { last = NR } END { for (i = 1; i <= last; i++) print lines[i] }' |
        tail -n "${FZF_PREVIEW_LINES:-40}"
    ;;
picker)
    scope=waiting
    [ -n "$(bash "$0" rows waiting)" ] || scope=all
    toggle_scope="if [ \"\$FZF_PROMPT\" = 'waiting> ' ]; then echo \"change-prompt(all> )+reload(bash $0 rows all)\"; else echo \"change-prompt(waiting> )+reload(bash $0 rows waiting)\"; fi"
    # shellcheck disable=SC2016 # fzf, not bash, expands $FZF_POS in the --bind actions
    selected=$(bash "$0" rows "$scope" |
        fzf --ansi --delimiter=$'\t' --with-nth=2 --no-sort --layout=reverse \
            --prompt "$scope> " --info=inline-right \
            --header 'enter jump · esc close · ctrl-a waiting/all · ctrl-r refresh preview' \
            --preview "bash $0 preview {1}" --preview-window 'right,60%,border-left' \
            --bind "focus:transform-preview-label:echo ' '{2}' '" \
            --bind "ctrl-a:transform:$toggle_scope" \
            --bind 'ctrl-r:refresh-preview' \
            --bind 'load:pos(2)' \
            --bind 'down:down+transform:[ {1} = - ] && echo down || true' \
            --bind 'up:up+transform:[ {1} = - ] && { [ "$FZF_POS" -le 1 ] && echo down || echo up; } || true' \
            --bind 'enter:transform:[ {1} = - ] || echo accept')
    pane_id=$(cut -f1 <<<"$selected")
    [ -n "$pane_id" ] && [ "$pane_id" != - ] && focus_pane "$pane_id"
    ;;
focus)
    focus_pane "$2"
    ;;
esac
exit 0
