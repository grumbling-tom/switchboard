---
name: shape-tickets
description: Break a project into a sequenced chain of tickets, agree it with you, then store it in your tracker.
disable-model-invocation: true
---

# Shape tickets

Turn a project and its source material into an agreed chain of tickets, then store the
chain in the user's tracker. Read `${CLAUDE_SKILL_DIR}/../../tickets/format.md` first: it
defines the chain folder, `tickets.toml`, and the storing steps.

## 1. Load the settings

- Tracker: `${user_config.tracker}`
- Linear team: `${user_config.linear_team}`

A value starting with `$` is a setting the user never saved: the tracker is then `local`
and the team is empty.

- **The repo.** Its name is the `origin` remote's path with `/` replaced by `-`
  (`grumbling-tom-switchboard`), else the repo folder's name.
- **A team for this repo.** `${CLAUDE_PLUGIN_DATA}/repos/<repo>.toml` may hold a
  `linear_team` that overrides the setting for this repo. With the tracker `linear` and no
  team from either, ask the user for one, and offer to remember it there.
- **The store.** Read `${CLAUDE_SKILL_DIR}/../../tickets/stores/<tracker>.md`. Its verbs
  (`create`, `deliver`, `fetch`, `start`) say how to do each step on that tracker. When
  `${CLAUDE_PLUGIN_DATA}/checked.txt` lacks a `<tracker> <team>` line, run the store's
  **First use** before storing, then add the line.
- **The chain folder** is `${CLAUDE_PLUGIN_DATA}/chains/<repo>/<slug>/`.

Done when you can name the tracker, the team, and the chain folder's path.

## 2. Understand

Run the store's `fetch` on whatever the user passed (a project, an issue, a doc), and read
every source in the conversation. Map the code the work touches, looking for what already
does part of the job. When sources disagree, the most recent wins; say so.

Done when every source is read and you can say what the work is for.

## 3. Propose in chat

Present the chain as a numbered list: per ticket, its title, kind, what it delivers, what
it waits for, and its stack. Then the decisions the user has to make. Iterate until the
user agrees. Mark a ticket that came from you rather than the discussion as yours.

Done when the user says to store the tickets.

## 4. Write the chain

Write the chain folder as `format.md` describes, with `status = "agreed"`: `tickets.toml`,
`map.md`, and one body file per ticket. Only agreed decisions go into any of them.

Done when every ticket has a table and a body file, and every `after` names an earlier id.

## 5. Store

Follow **Storing** in `format.md`, running each verb as the store describes. It ends by
telling the user which `/switchboard:plan-ticket` to type next.

## Ordering

- **Data shape first**, then wiring that shows the whole flow on stub data, then
  instrumentation, then the real change, then rollout, then UI.
- **Stacks:** tickets that each build directly on the one before ship as one stack of up
  to three layers. A ticket that needs nothing below it opens on its own.
- **Context carries a code snippet** wherever the mechanism matters, naming the file it
  lands in.
