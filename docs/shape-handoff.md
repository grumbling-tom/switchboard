# Shape handoff format

`switchboard:shape-tickets` breaks a piece of work into a sequenced chain of tickets and
writes the agreed chain to one file. Whatever stores it somewhere — an org's own skill
that writes to Linear, Jira or GitHub Issues — reads that file. The shape skill only
writes this file, and a persister only stores what it reads. This file is the whole
contract between them.

## Where it lives

`~/.claude/plans/shape-<project-slug>.md`, beside the plan files `plan-ticket` freezes.
`<project-slug>` is lowercase, hyphenated, and at most 40 characters. If the file
already exists, the shape skill asks before overwriting it, and refuses to overwrite one
whose status is `persisted` or `partly-persisted`.

## Who writes what

| Part | Written by |
|---|---|
| Frontmatter, apart from `status` once agreed | Shape |
| `status: draft` → `agreed` | Shape, only when the user agrees to the chain |
| `status: partly-persisted` → `persisted`, and the `## Persisted` section | The persister |
| Everything else | Shape |

A persister only acts on a file whose status is `agreed` or `partly-persisted`.

## Ticket ids

Before they are stored, tickets have no keys, so the file uses local ids: `T1`, `T2`, …
in merge order. Once the file is `agreed`, each id is fixed: a ticket dropped after
that keeps its id and its row in the Sequence, with Kind `dropped`.

Wherever prose refers to another ticket (Context, Acceptance Criteria, Decisions), it
writes `[[T2]]`. The persister replaces each one with the stored issue's reference in
the tracker's own form: a link, a mention, or a bare key. In tables and in the chain,
ids appear bare (`T2`), since those are structured and the persister rewrites them by
position.

## Layout

The file is Markdown with YAML frontmatter. Section headings are fixed, appear in this
order, and are matched exactly. A section with nothing in it holds `None.`

```
---
title: <project title>
slug: <project-slug>
status: draft | agreed | partly-persisted | persisted
created: <YYYY-MM-DD>
agreed: <YYYY-MM-DD, once agreed>
source: <opaque reference to the project, passed through untouched; optional>
conventions: <path to the conventions file used; optional>
---

# <project title>

## Framing
## Decisions
## Superseded
## Sequence
## Stacks
## Chain
## Later
## Tickets
### T1 · <title>
### T2 · <title>
…
## Persisted
```

### Frontmatter

- `source` is whatever the wrapper said the work came from: a Linear project URL, a
  Jira epic key, a doc link. Shape only copies it; the persister uses it to find where
  the Delivery section goes.
- `conventions` is the file whose ordering rule, ticket kinds and template shaped this
  chain, so a reader can tell which rules it followed. If it's absent, the plugin's
  defaults were used.

### Framing

One paragraph: what the chain delivers and why it's ordered the way it is. It's written
for someone who didn't sit through the discussion. The persister puts it at the top of
the Delivery section.

### Decisions

What the user decided while shaping, one per line, numbered `D1`, `D2`, …, with who
decided it and the date:

```
- D1: "Reviewer" is renamed "manager" throughout. (Tom, 2026-11-13)
```

Only settled decisions go here. Open questions stay in the conversation and keep the
file in `draft`.

### Superseded

The parts of the source material that a decision overrides, each naming the decision:
"The project brief's 'reviewer runs nightly' is replaced by D3." The persister appends
this to the project and never edits the original text.

### Sequence

One row per ticket, in merge order:

| Id | Title | Kind | Depends on | Stack | Parallel with |
|---|---|---|---|---|---|
| T1 | Schema and authoring script | schema | — | S1·1/3 | T2 |
| T2 | Manager prompt | prompt | — | — | T1 |
| T3 | Wiring with stub data | wiring | T1 | S1·2/3 | — |

- **Kind** comes from the conventions' list of ticket kinds. The default list is
  `schema`, `prompt`, `wiring`, `instrumentation`, `change`, `rollout`, `ui`, `other`,
  plus `dropped`. A persister may map a kind to labels; it never changes the ticket's
  meaning.
- **Depends on** holds the ids this ticket can't merge before. These become the
  tracker's "blocked by" links. Only real dependencies go here.
- **Stack** is `S<n>·<layer>/<layers>`, or `—` for a ticket that opens on its own.
- **Parallel with** lists tickets whose PRs open at the same time, usually because they
  have different reviewers. It's for people reading; it isn't a dependency.

### Stacks

One line per stack, bottom layer first, at most three layers each:

```
- S1: T1 → T3 → T4
- S2: T6 → T7 (starts after S1 merges)
```

### Chain

The ASCII diagram, in a fenced block, using bare ids padded to four characters (`T1  `)
so the persister can swap in longer keys and re-pad the columns without breaking the
arrows. A box marks each stack.

### Later

Tickets deliberately left out of this chain, such as phase-two work, one line each with
the reason. These aren't tickets and get no id.

### Tickets

One `### T<n> · <title>` section per ticket, in id order, each starting with a field
list and then the body sections the conventions name (by default Requirement, Context
and Acceptance Criteria):

```
### T3 · Wiring with stub data

- Kind: wiring
- Labels: Feature
- Depends on: T1
- Stack: S1·2/3, builds on T1

#### Requirement
…
#### Context
…
#### Acceptance Criteria
- [ ] …
```

- **Labels** are the conventions' own label names, spelled and cased exactly as the
  tracker has them. If the conventions name no labels, leave this field out.
- The body is plain Markdown (headings, lists, tables and fenced code), since every
  tracker renders that or can convert it. A persister whose tracker doesn't take
  Markdown converts it.
- Code snippets name the file they land in and what they reuse, and say they're
  illustrative.

### Persisted

Shape writes `None.` here. The persister replaces it with one row per ticket as each one
is stored, and saves the file after each row:

| Id | Key | Title | URL |
|---|---|---|---|
| T1 | ENGH-1133 | Schema and authoring script | https://linear.app/… |

Then it adds one line saying where the Delivery section went. This table is what makes
a persister safe to rerun. A ticket that already has a row is skipped, so a run that
failed halfway picks up where it stopped, and status stays `partly-persisted` until
every non-dropped ticket has a key and the Delivery section is written. `plan-ticket`
also reads it, to turn a key back into the ticket's section in this file.

## What a persister does

In this order, so that every reference exists before anything points at it:

1. Create each ticket without a row in Persisted, in id order, with its body as it
   stands. Record its row straight away.
2. Rewrite every `[[T<n>]]` in the stored bodies to the real reference, and set the
   "blocked by" links from Depends on.
3. Append the Delivery section to the project in `source`: Framing, the Sequence with
   keys, Stacks, the Chain with keys swapped in and re-padded, Later, Decisions and
   Superseded. Add it after the project's existing text, leaving that text as it is.
4. Set `status: persisted`.

A ticket's text, kind, order and dependencies are shape's. A fix to any of them goes
back through shape, which updates the file and keeps the ids.
