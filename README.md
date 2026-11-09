# switchboard

See which of your parallel Claude Code sessions in tmux are waiting on you, get a macOS
notification when one is, and jump to it.

- **Status bar:** counts of sessions working, in the background, stuck, and waiting on you.
  Click the counts to open the picker.
- **Pane borders:** each Claude pane shows whether it's waiting on you, and whether it's a
  worker or an orchestrator.
- **Picker (`prefix + j`):** every session, waiting ones first, with a live preview of the
  pane under its `/outcome` note. Enter jumps to it.
- **Notifications:** when a session finishes, asks a question or needs permission, unless
  you're already looking at it. Clicking one takes you to the pane.
- **Skills:** `/outcome` records what a thread is for; `claude-workflow-digest` reports how
  long sessions waited on you.

macOS only.

## Requirements

Switchboard checks for these when a session starts and warns about anything missing. It
never installs anything.

| Tool | Used for | Install |
|---|---|---|
| tmux | Everything | `brew install tmux` |
| jq | Reading what each hook receives | `brew install jq` |
| fzf | The picker | `brew install fzf` |
| python3 | Background-job detection and session stats; macOS's own is fine | `xcode-select --install` |
| alerter | Clickable notifications | `brew install vjeantet/tap/alerter` |

## Install

From a local checkout:

```
/plugin marketplace add ~/code/switchboard
/plugin install switchboard@switchboard
```

Or try it for one session without installing: `claude --plugin-dir ~/code/switchboard`.

## tmux

When a Claude session starts inside tmux, switchboard loads its tmux lines into that tmux
server: `status-right`, `pane-border-status` and `pane-border-format`,
`automatic-rename-format`, and the `prefix + j`, `prefix + r` and `prefix + t` bindings.
They replace your own values for those options. The filled-in file is written to
`~/.local/state/switchboard/switchboard.tmux`; source it from `~/.tmux.conf` if you want
the status bar before the first Claude session starts.

| Key | Does |
|---|---|
| `prefix + j` | Open the picker |
| `prefix + r` | Mark the current pane as a worker or an orchestrator, for the stats |
| `prefix + t` | Set the current pane's label by hand |

To open the picker with a single key such as Cmd+J, map that key in your terminal to send
your tmux prefix followed by `j`.

## Settings

- Notifications are off while `~/.claude/notify-off` exists.
- A pane started with `CLAUDE_SESSION_ROLE=worker` counts as a worker; everything else is
  an orchestrator until you press `prefix + r`.
- After a finished turn, `hooks/updateThreadNote.py` asks Haiku (`claude -p --model haiku`)
  whether the thread's `/outcome` note needs updating, at most once every five minutes per
  thread. This uses your Claude usage.

## State

Everything switchboard keeps is under `~/.local/state/claude-sessions/`: `events.tsv`, the
log the stats read, and `threads/`, the `/outcome` notes.
