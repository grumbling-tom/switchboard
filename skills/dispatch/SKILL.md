---
name: dispatch
description: Hand an approved plan to a worker Claude in its own git worktree and tmux pane, and mark the ticket started. With --stack, one worker builds every layer of an approved stack.
disable-model-invocation: true
---

# Dispatch

Start a worker against an approved plan, in its own worktree and pane, without blocking
this session.

## 1. Load the settings

- Tracker: `${user_config.tracker}`
- Linear team: `${user_config.linear_team}`
- Stack depth: `${user_config.max_stack_layers}`
- Data folder: `${CLAUDE_PLUGIN_DATA}`
- Plugin folder: `${CLAUDE_SKILL_DIR}/../..`

Follow `<plugin folder>/tickets/settings.md` with these values. This skill uses the plans
folder.

## 2. Check the plan

- **One ticket:** its frozen plan, `<plans folder>/<key, lowercase, / as ->.md`, exists.
- **A stack** (`--stack <bottom key>`): the manifest
  `<plans folder>/stack-<bottom key, lowercase>.md` lists every layer as `approved` with a
  frozen plan on disk. The layers whose PRs haven't merged (`gh pr view <branch> --json
  state` for each `dispatched` layer) plus the new ones number at most the stack depth;
  more, and the extra layer waits until the bottom PR merges. `gh extension list` shows
  `github/gh-stack`; without it, ask the user to run `! gh extension install
  github/gh-stack`.

Only an approved plan is dispatched. Done when the plan, or every layer's plan, is on
disk and approved.

## 3. Write the worker prompt

Write it to `<plans folder>/<key>-worker.md`. The worker starts with nothing but this
prompt, so it carries everything:

- "You are in your own worktree at `<path>`, on branch `<branch>`, made from
  `<default branch>`. Work only here, on this branch."
- The frozen plan's path: "Read it in full and follow it exactly."
- Three to five lines on what to build, naming the files.
- The commits with their titles, and the commit trailers from this session's system
  reminder.
- **Checks after each commit:** the plan's verification commands, that the diff contains
  exactly the plan's files, the repo's formatter on touched files, and its type check.
  Install dependencies first when modules don't resolve.
- **The full test suite once, before opening the PR:** the command CI runs, from the
  repo's CLAUDE.md or CI config. A failure in a file the diff doesn't touch is rerun on its
  own. If it passes alone, open the PR and name it in the closing report as a suspected
  flake. If it fails alone, fix it when this branch caused it; otherwise open the PR and
  report the failure and its cause.
- **The PR:** `gh pr create --draft`, with the title and body the repo's PR template and
  CLAUDE.md ask for. A section the template leaves to the author, such as Problem or
  Motivation, holds only `_To be written by the author._`. Pushing is for opening the PR.
  The PR stays a draft, with no reviewers or labels, and the tracker stays as it is.
- A "Changes from the ticket draft" table, or any long comparison, goes in a block GitHub
  collapses, with a blank line after `</summary>`:
  `<details><summary><strong>Changes from the ticket draft</strong></summary>`.
- What the plan says to expect from gates ("the prompt-owner check goes red; that's
  expected").
- "Delete files with `rm` in a command of its own, naming each path literally, inside the
  worktree or your scratchpad. Nobody is watching this pane to answer a permission
  prompt."
- **The closing step:** print the branch, commit SHAs, test results, PR URL and any
  departures from the plan. Then ask the user, in this pane, for each section left to the
  author, and write their words in verbatim with `gh pr edit <number> --body-file`.

## 4. Start the worker

Pick the worktree's name, `<key, lowercase, / as ->`, unless `git worktree list` already
has it, in which case add a short slug. Then run:

```sh
"${CLAUDE_SKILL_DIR}/dispatch_pane.sh" <worktree name> <branch> <prompt file>
```

It makes the worktree in the main checkout's `.claude/worktrees/`, hidden from
`git status`, and starts the worker in auto mode in a pane split beside this one. It
prints the new pane's id. Check the pane with
`tmux display -p -t <pane id> '#{pane_current_command} #{pane_current_path}'`: the path
is the worktree. If its screen (`tmux capture-pane -p -t <pane id>`) shows Claude Code
asking whether to trust the folder, tell the user to answer it in that pane.

Done when the worker is running in its worktree.

## 5. Mark the ticket started

Run the store's `start` on the ticket, or on every layer of a stack, and set each layer
to `dispatched` in the manifest.

## 6. Report and move on

A short table: pane, worktree, branch, and the ticket's new status. Say the worker stops
at the end to ask for the author's sections in its own pane. Then carry on without
waiting.

## Stack mode

Everything above applies, with these differences.

- **Names:** the worktree is `stack-<bottom key, lowercase>`, and the branch argument is
  `--detach`, so `gh stack init` makes the first branch. A stack grown after a merge gets
  its new layer appended to the manifest and runs in the stack's existing worktree, once
  the previous worker has exited.
- **The worker prompt**, in place of the single-ticket one:
  - The manifest's path and every frozen plan's path: "Read them all before starting."
  - "Build bottom-up: `gh stack init --base <default branch> <layer 1 branch>`, then
    `gh stack add <branch>` for each later layer. `gh stack view --json` shows where you
    are. When a command is rejected, read its `--help` before trying another form." Each
    layer follows only its own plan and its own Layer boundary, and leaves lower layers'
    files as they are.
  - **Each layer is finished before the next starts:** its commits, formatter, tests and
    type check, and its "diff contains exactly these files" check against the branch
    below.
  - **A fix to a lower layer goes on that layer:** check it out, commit there, then
    `gh stack rebase --upstack`, `gh stack top` and `gh stack push`. On exit code 3,
    resolve, `git add`, then `gh stack rebase --continue`. Rebases happen locally.
  - **Stop and report instead of improvising** when a layer's checks fail and the plan has
    no fix, when a layer needs a change to a lower layer's file or export that its plan
    didn't include, or when `gh stack` can't do a step this prompt describes. The finished
    layers stay in place, in order.
  - **The stack's shape is the manifest's:** the commands above are the whole set. Never
    run `gh stack modify`, `switch`, `unstack` or `merge`.
  - **Opening the PRs:** run the full suite once on the top layer built, then
    `gh stack submit --auto`, which opens one draft PR per layer, each targeting the layer
    below. Always pass `--auto` and never `--open`: either way round, the PRs are marked
    ready. Exit code 9 means the repository hasn't enabled stacked PRs: stop and report,
    with nothing pushed. Then set each PR's title and body as the single-ticket prompt
    says, plus a line `Stack: layer N of M, builds on #<PR below>`.
  - **The closing step, once for the whole stack:** a table of layer, branch, PR URL,
    SHAs, test results and departures, then the author's sections for each PR in turn,
    bottom first.
- **After the worker finishes,** the user reviews bottom-up, marking each layer ready only
  once the one below is approved. `gh stack sync` brings the stack up to date; it prints
  `Sync aborted` when the local and GitHub stacks disagree, so read its output as well as
  its exit code. `gh stack merge <PR> --yes` merges a PR with every layer below it. The
  user merges.
