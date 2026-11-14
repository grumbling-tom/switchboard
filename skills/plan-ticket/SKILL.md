---
name: plan-ticket
description: Plan one ticket, grounded in the code, and present it for your approval. With --stack, plan each layer of a stack in turn.
disable-model-invocation: true
---

# Plan one ticket

Produce one ticket's implementation plan, grounded in the code, and present it for
approval. Planning stops at approval; `/sb:dispatch` does the building.

## 1. Load the settings

- Tracker: `${user_config.tracker}`
- Linear team: `${user_config.linear_team}`
- Stack depth: `${user_config.max_stack_layers}`
- Data folder: `${CLAUDE_PLUGIN_DATA}`
- Plugin folder: `${CLAUDE_SKILL_DIR}/../..`

Follow `<plugin folder>/tickets/settings.md` with these values. This skill uses the plans
folder.

## 2. Read the ticket

The input is one ticket's key: `ENGH-1234` in Linear, `<slug>/T3` in the local store.
Run the store's `fetch` on it, then on its project: the project holds the full flow, the
data changes, and the Decided list this plan must not reopen. Given two keys, plan the
first and say the second comes after its approval.

The ticket's **branch** is the one `fetch` names (Linear's `gitBranchName`), else
`<key, lowercase, / as ->-<short slug>`.

Done when you have the ticket's requirement, context, acceptance criteria and stack line,
and the project's decisions.

## 3. Plan

1. **Enter plan mode.** The plan file is the only file written.
2. **Explore** with 1–3 Explore agents in parallel, each with one focus: the conventions
   the change must match (a sibling file to copy); the runtime sources a schema or
   predicate must validate against; how tests are written and run; and the gates the
   repo's CLAUDE.md and CI config apply to a change like this one (reviews matched on
   paths, rules over schema folders, checks on test data). Ask for paths with line
   numbers.
3. **Design** with one Plan agent. Give it the ticket text, the project's settled
   decisions it must not reopen, every exploration finding with its paths, and the repo's
   CLAUDE.md rules. Ask for file-by-file changes with code, tests as a list of cases, a
   commit plan, verification commands, and risks.
4. **Check before trusting.** Open the lines the planner cites for every claim the design
   rests on (where a write is parsed, where a node is wired, whether an import is
   type-only). Check its new names against the exports of the chain's other tickets, and
   rename now rather than collide later. Check which gates the change lands under and
   what that means for the PR, and check the plan against the repo's review rules. When
   text the ticket also holds changes (a prompt, a schema shape, a name), keep a "Changes
   from the ticket draft" table.

   Done when every path and line the plan relies on has been opened and matches.
5. **Write the plan file:** Context (why, what it blocks, the settled decisions), the
   verified facts that shape the design with their paths, one numbered section per file
   with its code, tests as cases, commits with titles, verification commands, risks, and
   a **Dispatch** section: "single ticket", or "stack layer N of M, dispatched with the
   stack".
6. **Present** it with ExitPlanMode. When the user rejects it with a correction, apply
   the correction and present again. Build nothing in this session.

## 4. After approval

1. **Freeze the plan**, since the next ticket's plan overwrites the session's plan file:
   copy it to `<plans folder>/<key, lowercase, / as ->.md`.
2. **Match the ticket to the plan.** When the plan changed text the ticket holds, run the
   store's `update` so both say the same.
3. Tell the user the next step: `Next, type /sb:dispatch <key>.`

## Stack mode (`--stack <key> <key> …`)

Plans the layers of one stack, bottom first, so one worker can build them all unattended.
Each layer still gets its own plan and its own approval.

- **At most the stack depth's layers.** Refuse one more and say it belongs in the next
  stack. Refuse a layer that needs a ticket outside the stack that hasn't merged to the
  default branch, such as a prompt with its own reviewers; it waits for the next stack.
- **Each layer plans against the one below.** Layer 1 explores the default branch. Each
  higher layer explores it plus the frozen plans beneath, which describe code that doesn't
  exist yet: give the Plan agent those plan files, and tell it every file, export and name
  they introduce is fixed. A layer that needs a lower layer changed goes back to that
  layer's plan, which is approved and frozen again first.
- **Each plan has a Layer boundary section:** the files this layer owns, and the lower
  layers' files it may only import from.
- **Freeze each plan on approval**, as in After approval.
- **Write the stack manifest** after each approval,
  `<plans folder>/stack-<bottom key, lowercase>.md`: one row per layer, bottom first, with
  its key, frozen plan path, branch, and status `approved`. Dispatch reads only this file.
- After the last layer's approval, tell the user:
  `Next, type /sb:dispatch --stack <bottom key>.` A partly approved stack is not
  dispatched.

## Rules

- One ticket per plan file.
- Only the recommended approach goes in; a rejected one gets one line in risks at most.
