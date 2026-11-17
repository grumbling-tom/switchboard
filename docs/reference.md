# Reference

## Features

- **Status bar:** a lamp for every Claude session, after its window's name, and how many
  are waiting on you. Click the count to open the picker.
- **Pane borders:** each Claude pane shows whether it's waiting on you, and whether it's a
  worker or an orchestrator.
- **Picker (`prefix + j`):** every session, waiting ones first, with a live preview of the
  pane. Enter jumps to it.
- **Notifications:** when a session finishes, asks a question or needs permission, unless
  you're already looking at it. Clicking one takes you to the pane.
- **Links to code:** Claude writes each reference to code as a link that opens the file
  at that line in VS Code.
- **Links to tickets:** Claude writes each reference to a Linear or Jira ticket or
  project as a link titled with its name, so a click opens it.
- **`/sb:branch`:** copies the conversation into a new Claude session in a pane
  beside this one, with the same role. Unlike `/branch`, this session stays as it was.
- **`/sb:shape-tickets`:** breaks a project into a sequenced chain of tickets,
  with stacks of dependent PRs, agrees it with you, then stores it in your tracker:
  Linear, or files the plugin keeps for you. Nothing is written to your repo.
- **`/sb:plan-ticket`:** plans one ticket from that chain, grounded in the code,
  and presents the plan for your approval. With `--stack`, it plans each layer of a stack
  in turn, each against the frozen plans below it.
- **`/sb:dispatch`:** hands an approved plan to a worker Claude in its own git
  worktree and pane, and marks the ticket started. The worker opens a draft PR, waits for
  its CI checks and fixes any that fail, then asks you for the sections its template
  leaves to the author. With `--stack`, one worker
  builds every layer and opens a draft PR for each.
- **`/sb:grill-me`:** interviews you about a plan, a round of questions at a time,
  each with a recommended answer, until nothing is left assumed. Claude also starts it
  when you ask to be grilled.
- **`/sb:wait-what`:** when Claude's last message didn't land, has it pitch that
  again in plain words, with a little context. Claude also starts it when you write
  `/wait-what` partway through a message, such as after quoting the part that lost you.
  From Matt Pocock's [skills](https://github.com/mattpocock/skills).

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

`/sb:dispatch` also needs the GitHub CLI (`brew install gh`), and for stacks its
[gh-stack](https://github.com/github/gh-stack) extension
(`gh extension install github/gh-stack`). It checks for them when it runs.

## tmux

When a Claude session starts inside tmux, switchboard loads its tmux lines into that tmux
server: `status-right`, `pane-border-status` and `pane-border-format`,
`automatic-rename-format`, the `hyperlinks` terminal feature, and the `prefix + j`,
`prefix + r` and `prefix + t` bindings.
They replace your own values for those options. The filled-in file is written to
`~/.local/state/switchboard/switchboard.tmux`; source it from `~/.tmux.conf` if you want
the status bar before the first Claude session starts.

| Key | Does |
|---|---|
| `prefix + j` | Open the picker |
| `prefix + r` | Mark the current pane as a worker or an orchestrator |
| `prefix + t` | Set the current pane's label by hand |

### Theme

Switchboard also loads a theme, `tmux/switchboard_theme.tmux`, styled after a telephone
operator's switchboard: a walnut status bar with brass trim, and a lamp for every Claude
pane after its window's name. The same lamp starts each pane's border title, and the
picker uses the lamps and colours too. A window's lamps follow the order its panes were
opened in, which can differ from their positions after a split; the border shows which
lamp is which.

| Lamp | Means |
|---|---|
| Red `◉` | Blocked mid-turn: a permission prompt or a question |
| Amber `◉` | Turn finished; your move |
| Green `●` | Working |
| Brass `○` | Waiting on a background job or a scheduled wakeup |
| Dim `◇` | Stuck? Working, but no tool call for an hour |

A red or amber lamp in the status bar pulses slowly, bright to dim and back over eight
seconds, until you visit that pane; after that it stays steady. The pulse needs the status
bar to redraw every second, so the theme sets `status-interval` to 1. Lamps on pane
borders and in the picker don't pulse.
The theme needs a terminal with 24-bit colour.

For Claude's own diffs, pick **Switchboard** in `/theme`. It's Claude Code's dark theme
with only the diff colours changed: darker shades of the lamps' green and red, so text on
them stays readable.

To keep your own status bar and colours, turn the **Theme** setting off (see
[Settings](#settings)). It takes effect when the next Claude session starts; to drop a
theme that's already loaded, restart the tmux server or re-source your `~/.tmux.conf`.

To open the picker with a single key such as Cmd+J, map that key in your terminal to send
your tmux prefix followed by `j`.

## Settings

Claude Code asks for these when you install or enable the plugin. Change them later with
`/plugin configure switchboard@switchboard`, or in `/config`. They apply from the next
session.

| Setting | Default | Does |
|---|---|---|
| Notifications | on | Post a notification when a session waits on you and you aren't looking at it |
| Theme | on | Load the walnut-and-brass tmux theme |
| Links to code | `vscode` | Have Claude link code references so they open in VS Code; `off` to stop |
| Links to tickets | on | Have Claude link ticket and project references, titled with their name |
| Terminal app | `iTerm2` | The app that runs tmux, as the Dock names it: how switchboard tells you're looking at a pane, and what a notification click brings forward |
| Tracker | `local` | Where `/sb:shape-tickets` stores tickets |
| Linear team | (none) | The team key tickets go to, when Tracker is `linear` |
| Stack depth | `3` | The most tickets one stack of dependent PRs may hold |

Links need a terminal that supports clickable links, such as iTerm2; inside tmux,
switchboard turns on tmux's `hyperlinks` terminal feature so they pass through.

A pane started with `CLAUDE_SESSION_ROLE=worker` counts as a worker; everything else is
an orchestrator until you press `prefix + r`.

## State

Switchboard keeps its state in tmux pane options (`@claude_state`, `@claude_role` and
the rest), so it disappears when the tmux server stops. Besides that it writes the
filled-in tmux snippet, `~/.local/state/switchboard/switchboard.tmux`, and
the ticket commands keep their chains and plans in the plugin's data folder,
`~/.claude/plugins/data/switchboard-switchboard/`. A chain stored in Linear is deleted
from there once Linear holds it. `/sb:dispatch` puts each worktree in the repo's
`.claude/worktrees/` and adds that folder to the clone's own `.git/info/exclude`, so it
never shows in `git status`.

