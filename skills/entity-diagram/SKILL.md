---
name: entity-diagram
description: Draw a plain-ASCII entity-relationship diagram that explains how entities relate — tables as boxes with their keys, lines labelled with cardinality at both ends and a verb — followed by a one-line "read it as" sentence per relationship and callouts for anything surprising. Built from the real schema (migrations, ORM models, DDL), never from guesses. Use when the user says "/entity-diagram", "draw the ERD", "ascii diagram of these tables", "how do X and Y relate", "sketch the data model", "show me the relationships", or when explaining a relational data model, a join path or a proposed schema change would be clearer as a picture.
---

# Entity diagram

Explain how entities relate with a diagram that pastes cleanly anywhere: a terminal, a PR
body, Slack, a code comment. Plain ASCII only (`+ - | < > v ^ .`), no box-drawing characters,
inside a ```` ```text ```` fence.

## Steps

1. **Pin down the question.** What is the user trying to understand — one join path, a
   whole bounded context, a proposed change? That decides which entities go in. A diagram
   that answers one question beats a full dump of the schema.

2. **Read the schema, don't recall it.** Find the source of truth and read it: SQL
   migrations / DDL, Prisma `schema.prisma`, Drizzle tables, SQLAlchemy / Django / ActiveRecord
   models, TypeORM entities. Grep for the table names and their foreign keys. For each
   relationship note:
   - which side holds the foreign key, and whether that column is nullable;
   - whether the FK column is also `UNIQUE` (that makes it one-to-one, not one-to-many);
   - whether a real `FOREIGN KEY` constraint exists, or the link only lives in app code;
   - `ON DELETE` behaviour if it matters to the question.
   If the user describes a schema that doesn't exist yet, draw from their description and
   say so above the diagram.

3. **Choose the entities.** Aim for 2–7 boxes. If the question genuinely needs more, draw
   several small diagrams (one per cluster) and name the entity they share, rather than one
   sprawling picture.

4. **Draw it** following the notation and layout rules below.

5. **Check the alignment mechanically.** Misaligned edges are the usual failure. Write the
   diagram to a scratch file and run:

   ```bash
   python3 -c "import sys
   for i,l in enumerate(open(sys.argv[1]).read().splitlines(),1): print(f'{i:>3} {len(l):>3}', [j for j,c in enumerate(l) if c in '|+'])" FILE
   ```

   Every row of a box must have its `|`/`+` at the same columns, and each vertical
   connector must sit in one column all the way down. Fix and re-check before showing it.

6. **Present** the diagram, then the "read it as" lines, then callouts (format below).

## Notation

**Entity box** — name in the header, then only the columns that matter: the primary key,
foreign keys, unique columns, and any column the question is about. Pad every row to the
same width.

```text
+------------------+
| order            |
+------------------+
| PK id            |
| FK customer_id   |
|    status        |
|    placed_at     |
+------------------+
```

Column markers: `PK` primary key, `FK` foreign key, `UQ` unique (right-aligned), `?` after
the name for nullable (`FK coupon_id?`). Composite keys: mark each column `PK`.

**Relationship line** — cardinality at each end, next to the box it describes, and a verb
in the middle that reads from the left/top entity to the right/bottom one.

| Marker | Meaning                     | Typical cause in the schema               |
| ------ | --------------------------- | ----------------------------------------- |
| `1`    | exactly one                 | non-null FK points here                   |
| `0..1` | zero or one                 | nullable FK, or unique FK on the far side |
| `*`    | zero or many                | FK on this side, no other constraint      |
| `1..*` | one or many                 | enforced in app/trigger — say where       |

- `-----` solid: enforced by a database foreign key.
- `.....` dotted: logical relationship only (no FK constraint, polymorphic `*_type`/`*_id`,
  ID stored in JSON). Always call these out.

**Many-to-many** — always draw the join table as its own box; never hide it behind an
`* --- *` line. The join table is often where the interesting columns live.

## Layout rules

- Parents (the `1` side) left or above; children (the `*` side) right or below, so reading
  direction follows the foreign keys.
- Lines are straight horizontal or vertical runs; a bend is a `+`. No crossings — reorder
  the boxes instead, or split the diagram.
- Connect horizontal lines at a box's header row so the eye links names, not columns.
- Keep it within ~100 columns so it doesn't wrap in a terminal or a PR.
- Use the real table names exactly as in the schema (snake_case, plural or not).

## After the diagram

**Read it as** — one plain sentence per relationship, including the cardinality both ways:

- A customer places zero or many orders; each order belongs to exactly one customer.

**Callouts** — only what would trip someone up, each one line, citing the file it came from:
nullable FKs, missing FK constraints (dotted lines), one-to-ones hiding as unique FKs,
cascading deletes, denormalised copies of a column, polymorphic links, and anything where
the schema disagrees with how the code or the user describes it.

## Example

```text
+----------------+ 1      places      * +------------------+
| customer       |----------------------| order            |
+----------------+                      +------------------+
| PK id          |                      | PK id            |
|    email    UQ |                      | FK customer_id   |
+----------------+                      |    placed_at     |
                                        +------------------+
                                                 | 1
                                                 |
                                                 | contains
                                                 |
                                                 | 1..*
+----------------+ 1    appears in    * +------------------+
| product        |----------------------| order_line       |
+----------------+                      +------------------+
| PK id          |                      | PK id            |
|    sku      UQ |                      | FK order_id      |
+----------------+                      | FK product_id    |
                                        |    quantity      |
                                        +------------------+
```

Read it as:

- A customer places zero or many orders; each order belongs to exactly one customer.
- An order contains one or many order lines; each line belongs to exactly one order.
- A product appears in zero or many order lines; each line is for exactly one product.

Callouts:

- `1..*` on order lines is not enforced by the database — `OrderService.place` rejects
  empty orders (`src/orders/service.ts`).
