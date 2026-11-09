# switchboard

See which of your parallel Claude Code sessions in tmux are waiting on you, get a macOS
notification when one is, and jump to it.

- **Status bar:** counts of sessions working, in the background, stuck, and waiting on you.
  Click the counts to open the picker.
- **Pane borders:** each Claude pane shows whether it's waiting on you, and whether it's a
  worker or an orchestrator.
- **Picker (`prefix + j`):** every session, waiting ones first, with a live preview of the
  pane. Enter jumps to it.
- **Notifications:** when a session finishes, asks a question or needs permission, unless
  you're already looking at it. Clicking one takes you to the pane.

macOS only.

## Requirements

Switchboard checks for these when a session starts and warns about anything missing. It
never installs anything.

| Tool | Used for | Install |
|---|---|---|
| tmux | Everything | `brew install tmux` |
| jq | Reading what each hook receives | `brew install jq` |
| fzf | The picker | `brew install fzf` |
| python3 | Background-job detection; macOS's own is fine | `xcode-select --install` |
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
| `prefix + r` | Mark the current pane as a worker or an orchestrator |
| `prefix + t` | Set the current pane's label by hand |

To open the picker with a single key such as Cmd+J, map that key in your terminal to send
your tmux prefix followed by `j`.

## Settings

- Notifications are off while `~/.claude/notify-off` exists.
- A pane started with `CLAUDE_SESSION_ROLE=worker` counts as a worker; everything else is
  an orchestrator until you press `prefix + r`.

## State

Switchboard keeps its state in tmux pane options (`@claude_state`, `@claude_role` and
the rest), so it disappears when the tmux server stops. The only file it writes is the
filled-in tmux snippet, `~/.local/state/switchboard/switchboard.tmux`.

## Development

Python and shell scripts both use snake_case for file, function and variable names;
constants and environment variables are UPPER_SNAKE_CASE. A pre-commit hook checks every
commit: ruff lints and formats Python, shellcheck lints and shfmt formats shell, and
`scripts/check_shell_names.sh` checks shell file and function names. Set it up once per
clone:

```
uv tool install pre-commit
pre-commit install
```

To run it by hand: `pre-commit run --all-files`.
