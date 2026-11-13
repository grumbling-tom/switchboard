# Writing a chain

How `map.md` and the ticket bodies are written. Five things carry the document: where the
change goes, the full flow, the data changes, the delivery plan, and the decisions. Each is
specific to this codebase: name the real functions, files and fields.

When the source project already has one of these (a flow diagram, a data section), point
to it, update it if the chain changed it, and draw nothing twice.

## Where the change goes

The first thing a reader sees: a few lines of the existing flow, with the new step marked
`◀── NEW`, and beside it the call site as it will read, with the untouched path saying so.

```
Nylas webhook → handle-email task → answerLogisticsEmail
    ├─ ingestEmailAttachments     (exists: GCS + Firestore File)
    ├─ ingestFiles                ◀── NEW
    └─ runLogisticsEmail (Wilson) only when a file was not recognised
```

```ts
const ingested = await ingestFiles({ orgId, files: savedAttachments, source })

if (ingested.every((file) => file.isRecognised)) {
    return { status: "skipped", reason: "ingested-by-engine" }
}
return runLogisticsEmail(...)   // today's path, unchanged
```

Keep it to what shows the size of the change: five to ten lines of diagram, one snippet.

## The full flow

How the system hangs together, as one boxed ASCII diagram from the trigger to every
outcome:

- Label each box `EXISTS` or `NEW`.
- Follow every branch to where it ends: an outcome, a hand-off, or a stop with its reason.
- Number the steps to match the numbered steps in the text.
- Put a lettered marker, `[A]`, `[B]`, …, on each branch that carries a decision, and
  follow the diagram with a legend table.

For example, condensed from a file ingestion project:

```
 NetSuite report ──email──▶ Nylas webhook
                               │  verify; insert messages row
                               ▼
                     handle-email task (3 attempts)
                               │
           ┌───────────────────▼──────────────────────┐
           │ ingestEmailAttachments            EXISTS │
           │   bytes → GCS · File record              │
           │   processingHistory: [received]      NEW │
           └───────────────────┬──────────────────────┘
                               │ saved files
 ┌─────────────────────────────▼────────────────────────────────┐
 │ ingestFiles, once per attachment                     NEW     │
 │                                                              │
 │ 1 CLASSIFY  header matches an enrolled config?               │
 │               no  ─▶ NOT RECOGNISED ────────────────────┐    │
 │               yes ─▶ RECOGNISED                         │    │
 │ 2 CLAIM     last history entry received or retryable?   │    │
 │               no  ─▶ stop: in hand, done or failed  [G] │    │
 │ 3 PARSE     one payload per Document Number         [A] │    │
 │             bad value → invalidValues, never thrown     │    │
 │ 4 MATCH     by referenceNumber, doc_claims lock         │    │
 │ 5 CHECK     another writer since our last entry?        │    │
 │               yes ─▶ HELD: write nothing                │    │
 │ 6 SAVE      upsert · sourceFiles += this file           │    │
 │ 7 ROUTE     open, no shipment ─▶ pending shipment  [C]  │    │
 │             shipment procuring+ ─▶ Wilson work list     │    │
 │ 8 FINISH    append succeeded or failed… to history      │    │
 └─────────────────────────────┬───────────────────────────┼────┘
                               ▼                           │
                   every file recognised?  [E]             │
                       yes │           │ no                │
                           │           ▼                   │
                           │       Wilson runs as today ◀──┘
                           ▼
                   work list empty?
                   yes │         │ no
                       ▼         ▼
                 skip Wilson  one framed Wilson run on the work list  [F]
```

|  | Decision |
| -- | -- |
| **A** | Decided: the ship date is `Shipping Priority`; its year is inferred |
| **C** | UPS orders: does the engine still create a `pending` shipment? |
| **E** | Should a human-written email with a recognised CSV still reach Wilson? |
| **F** | Decided: the work list carries everything; Wilson prioritises from the org's instructions |
| **G** | How old a claim must be before another task may take it over |

A term the diagram introduces gets a sentence under it: "The **Wilson work list** is what
the engine collects for Wilson while it processes an email's files: shipments it created
and changes to shipments already in procurement. Empty means no Wilson run."

## Data changes

Number each change, and show it as code:

- **New fields** as the schema code that defines them, with an inline comment giving a
  real example value:

  ```ts
  invalidValues: z.array(z.object({
      field: z.string(),         // "requestedShipDate"
      sourceValue: z.string(),   // "13/45/2026"
      reason: z.string(),        // "not a date"
  })).nullish()
  ```
- **Derived values** as the function that computes them.
- **A lifecycle** as a state diagram:

  ```
  received ──▶ processing ──▶ succeeded
                   ├──▶ failedRetryable ──▶ processing (retry)
                   └──▶ failedTerminal
  ```
- **Rules with two columns** as a table: "The write → Effect", "Last entry → Result".
- **An existing field that looks reusable but isn't** gets one sentence saying why, such as
  "`processingStatus` already means embedding; the knowledge window reads it".

Snippets are illustrative: each names the file it lands in and what it reuses. The ticket
that makes a change carries the same snippet in its Context.

## Delivery

1. **A framing paragraph** on how the work flows: what opens on day one in parallel, which
   tickets have their own reviewers, which tickets form each stack and who builds it, and
   what waits on what.
2. **A numbered list in merge order**, one line per ticket: its key, a `**Fix:**` prefix
   for a fix, what it delivers, and `Stack 2 of 3` for a stack layer.
3. **The chain diagram**: every ticket by key and short name, each stack boxed, blockers
   joining from the side.

   ```
   ENGH-3027                  ENGH-3028       ENGH-3029
   SO fields+status           Inverse links   Prompt
          │                       │               │
   ┌──────▼── Stack ─────────┐    │               │
   │ ENGH-3030 File history  │    │               │
   │ ENGH-3031 Telemetry     │    │               │
   │ ENGH-3032 ingestFiles   │◀───┴───────────────┘
   └──────┬──────────────────┘
          ▼
   ENGH-3034 Enroll
   ```
4. **Superseded**: which decisions in the tickets override the sections above, each
   linked to its ticket.

## Decided and Not decided yet

**Decided** lists each settled decision with who made it and when, `(decision: Tom,
2026-11-13)`. A decision that came from a customer or a meeting quotes it and links the
source.

**Not decided yet** lists each open question with a proposal and whose it is, the ticket
it blocks, and a precedent in the codebase when there is one ("the way
`sweep-stuck-thread-runs-cron` reclaims a thread"). Its lettered marker in the full flow
points here.
