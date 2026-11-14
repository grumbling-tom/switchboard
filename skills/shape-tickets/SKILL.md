---
name: shape-tickets
description: Break a project into a sequenced chain of tickets, agree it with you, then store it in your tracker.
disable-model-invocation: true
---

# Shape tickets

Turn a project and its source material into an agreed chain of tickets, then store the
chain in the user's tracker. Read two files first:

- `${CLAUDE_SKILL_DIR}/../../tickets/format.md`: the chain folder, `tickets.toml`, and the
  storing steps.
- `${CLAUDE_SKILL_DIR}/../../tickets/writing.md`: how the chain is written up, from where
  the change goes and the full flow to the delivery plan and the decisions.

## 1. Load the settings

- Tracker: `${user_config.tracker}`
- Linear team: `${user_config.linear_team}`
- Stack depth: `${user_config.max_stack_layers}`
- Data folder: `${CLAUDE_PLUGIN_DATA}`
- Plugin folder: `${CLAUDE_SKILL_DIR}/../..`

Follow `<plugin folder>/tickets/settings.md` with these values. This skill uses the chain
folder.

## 2. Understand

Run the store's `fetch` on whatever the user passed (a project, an issue, a doc), and read
every source in the conversation. Map the code the work touches, looking for what already
does part of the job. When sources disagree, the most recent wins; say so.

Done when every source is read and you can say what the work is for.

## 3. Propose in chat

Present, as `writing.md` describes them: where the change goes, the full flow with its
lettered decisions, and the data changes. Then the chain as a numbered list (per ticket,
its title, kind, what it delivers, what it waits for, and its stack), and the decisions
the user has to make, each with your proposal. Iterate until the user agrees. Mark a
ticket that came from you rather than the discussion as yours.

Done when the user says to store the tickets.

## 4. Write the chain

Write the chain folder as `format.md` describes, with `status = "agreed"`: `tickets.toml`,
`map.md` written as `writing.md` describes, and one body file per ticket, `map.md` and
every body opening with the AI-generated callout. Settled
decisions go under Decided; open ones stay under Not decided yet.

Done when every ticket has a table and a body file, every `after` names an earlier id,
and every lettered marker in the full flow has its line under Decided or Not decided yet.

## 5. Store

Follow **Storing** in `format.md`, running each verb as the store describes. It ends by
telling the user which `/sb:plan-ticket` to type next.

## Ordering

- **Data shape first**, then wiring that shows the whole flow on stub data, then
  instrumentation, then the real change, then rollout, then UI.
- **Stacks:** tickets that each build directly on the one before ship as one stack of at
  most the stack depth's layers; a longer run splits into stacks that follow each other. A
  ticket that needs nothing below it opens on its own.
