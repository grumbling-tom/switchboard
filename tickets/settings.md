# Loading the settings

Each ticket skill starts by listing the values Claude Code substituted into it: Tracker,
Linear team, Stack depth, the data folder and the plugin folder. This file says what to do
with them.

## Unsaved settings

A value still starting with `$` is a setting the user never saved. Use its default:

| Setting | Default |
|---|---|
| Tracker | `local` |
| Linear team | empty |
| Stack depth | `3` |

## The repo

Its name is the `origin` remote's path with `/` replaced by `-`
(`grumbling-tom-switchboard`), else the repo folder's name. Every per-repo path below uses
it.

## The Linear team for this repo

`<data folder>/repos/<repo>.toml` may hold a `linear_team` that overrides the setting for
this repo. With the tracker `linear` and no team from either, ask the user for one, and
offer to remember it there.

## The store

Read `<plugin folder>/tickets/stores/<tracker>.md`. Its verbs (`create`, `update`,
`deliver`, `fetch`, `start`) say how to do each step on that tracker. Before the first verb
that writes, check `<data folder>/checked.txt` for a `<tracker> <team>` line; without one,
run the store's **First use**, then add the line.

## Folders

| Folder | Holds |
|---|---|
| `<data folder>/chains/<repo>/<slug>/` | A chain being shaped, as `format.md` describes |
| `<data folder>/plans/<repo>/` | Frozen plans, stack manifests and worker prompts |

Both are outside the user's repo, so nothing these skills write shows up in `git status`.

Done when you can name the tracker, the team, the stack depth, and the folders this skill
uses.
