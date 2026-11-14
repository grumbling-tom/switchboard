#!/bin/bash
# /sb:dispatch: gives a ticket its own git worktree and starts a worker Claude
# there, in a tmux pane split beside this one.
#
#   dispatch_pane.sh <worktree name> <branch | --detach> <prompt file>
#
# The worktree goes in the main checkout's .claude/worktrees/, which is added to the
# clone's own .git/info/exclude so it never shows in git status. A new branch starts from
# the default branch; --detach leaves the worktree detached there, for gh stack init to
# make the first branch. An existing worktree of that name is reused, as a stack's later
# layers do. The worker runs in auto mode, since nobody watches its permission prompts,
# and as a worker, which switchboard's pane borders and picker read.
TMUX_BIN=$(command -v tmux || echo /opt/homebrew/bin/tmux)

if [ -z "$TMUX_PANE" ]; then
    echo "Not inside tmux, so there's no pane to split." >&2
    exit 1
fi
if [ $# -ne 3 ]; then
    echo "Usage: dispatch_pane.sh <worktree name> <branch | --detach> <prompt file>" >&2
    exit 1
fi
name=$1
branch=$2
prompt=$3
if [ ! -f "$prompt" ]; then
    echo "No prompt file at $prompt." >&2
    exit 1
fi

main=$(git worktree list --porcelain 2>/dev/null | awk 'NR == 1 { print $2 }')
if [ -z "$main" ]; then
    echo "Not in a git repo." >&2
    exit 1
fi
default=$(git -C "$main" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)
default=${default#origin/}
default=${default:-main}

exclude="$(git -C "$main" rev-parse --path-format=absolute --git-common-dir)/info/exclude"
mkdir -p "$(dirname "$exclude")"
grep -qxF '.claude/worktrees/' "$exclude" 2>/dev/null || echo '.claude/worktrees/' >>"$exclude"

worktree="$main/.claude/worktrees/$name"
if [ ! -d "$worktree" ]; then
    if [ "$branch" = --detach ]; then
        git -C "$main" worktree add -q --detach "$worktree" "$default" || exit 1
        git -C "$worktree" config rerere.enabled true
    else
        git -C "$main" worktree add -q "$worktree" -b "$branch" "$default" || exit 1
    fi
fi

command="claude --permission-mode auto \"\$(cat $(printf %q "$prompt"))\""
new_pane=$("$TMUX_BIN" split-window -h -P -F '#{pane_id}' -t "$TMUX_PANE" \
    -c "$worktree" -e CLAUDE_SESSION_ROLE=worker "$command") || exit 1

echo "Started a worker in pane $new_pane, in $worktree."
