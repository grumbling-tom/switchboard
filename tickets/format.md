# Ticket chains

The files `shape-tickets` writes while it shapes and stores a chain. They live in the
**chain folder**, in the plugin's own data folder, never in the user's repo; the skill
gives its path.

```
<chain folder>/
  tickets.toml           the chain's structure: ids, order, dependencies, stacks, where each ticket lives
  map.md                 where the change goes, the flow, data changes, delivery, decisions
  T1-<ticket-slug>.md    one body per ticket, until the store holds it
  T2-<ticket-slug>.md
```

## The AI-generated callout

Everything shape-tickets writes for people to read starts with this callout: `map.md`,
and so the section it becomes on the project, and every ticket body.

```
> [!WARNING]
> AI generated, proceed with caution.
```

It tells readers a person still has to amend or rewrite what follows. The callout is
theirs to remove once they have; the skill writes it every time and removes it never.

## One place for each body

**A ticket's `url` says where its body lives.** While `url` is empty, the body is the
ticket's `T<n>-*.md` file. Once `url` is set, the body lives there, and nowhere else. The
same holds for the map and `project_url`.

A store that keeps tickets elsewhere, such as Linear, deletes each local file as it takes
the content, and the chain folder once the map is delivered. A change to a stored ticket
is made where its `url` points.

## tickets.toml

```toml
title = "Tracker-agnostic ticket shaping"
status = "agreed"          # draft | agreed | storing | stored
created = 2026-11-13
agreed = 2026-11-13
source = ""                # the project the work came from, as the store's `fetch` takes it
project_url = ""           # set when the map is delivered

[[ticket]]
id = "T1"                  # permanent once agreed
title = "Ticket chain format and store starters"
kind = "schema"
after = []                 # ids this ticket can't merge before
stack = "S1·1/2"           # "S<n>·<layer>/<layers>", or "" for a ticket on its own
parallel_with = ["T2"]     # PRs that open at the same time; for people, not dependencies
labels = []                # the tracker's own label names
key = ""                   # set by `create`
url = ""                   # set by `create`
```

- **Table order is merge order**, and ids run `T1`, `T2`, … in that order. A ticket
  dropped after agreement keeps its table, with `kind = "dropped"`, and is never stored.
- **Kinds** are `schema`, `prompt`, `wiring`, `instrumentation`, `change`, `rollout`,
  `ui`, `other` and `dropped`.
- **Stacks** have at most the stack depth's layers (the Stack depth setting, 3 unless the
  user changed it), numbered bottom first, and each layer's `after` includes the layer
  below.
- `status` moves to `agreed` when the user agrees to the chain, to `storing` when the
  first ticket is created, and to `stored` once the map is delivered.

## map.md

```
> [!WARNING]
> AI generated, proceed with caution.

# <title>

## Where the change goes
## The full flow
## Data changes
## Delivery
## Decided
## Not decided yet
## Later
```

`writing.md`, beside this file, says what each of the first six holds and how to draw
it. **Later** is work deliberately left out, one line each with the reason. A section
with nothing in it holds `None.`; one the source project already covers points to it.

The user agreeing to the chain moves it to `agreed` with questions still open: each stays
under **Not decided yet**, with its proposal and the ticket it blocks.

## Ticket bodies

`T<n>-<ticket-slug>.md` holds the body the store gets: the AI-generated callout, then
Requirement, Context, and Acceptance Criteria as testable `- [ ]` items. It is plain Markdown. Context carries the
snippets and diagram slices from `map.md` that this ticket implements, as `writing.md`
describes.

A body refers to a ticket earlier in the table as `[[T2]]`; storing swaps in that
ticket's key, which exists by then. It names a later ticket by its title.

## Storing

1. **Create each ticket**, in table order, with the store's `create`. Before saving,
   replace each `[[T<n>]]` with that ticket's key, and add a last line to a stack layer's
   body: `Stack: layer 2 of 2, builds on <key of the layer below>`. Pass the keys of the
   ticket's `after` as its blockers. Write its `key` and `url` into `tickets.toml`, and set
   `status = "storing"` after the first.
2. **Deliver the map** with the store's `deliver`: map.md, callout first, with keys in
   place of ids, Delivery's numbered list linking each key, and the chain redrawn so its
   box edges and arrows line up around the longer keys. Set `project_url`.
3. **Finish.** Set `status = "stored"`, then tell the user the next step:
   `The chain is stored. Next, type /sb:plan-ticket <key>.` Name the first ticket
   with an empty `after`, and any others that can start alongside it.
