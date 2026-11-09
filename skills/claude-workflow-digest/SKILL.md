---
name: claude-workflow-digest
description: Report how the user's parallel Claude Code sessions are running, by running ~/.claude/scripts/claudeSessionStats.py over the session-state log the claudeWaiting.sh hooks write, and summarising it. Leads with responsiveness (how long sessions waited on the user, split by permission prompt, question and finished turn), then how many sessions worked or waited at once, then the longest waits and runs. Use when the user says "claude workflow digest", "session stats", "how long are my Claudes waiting on me", "how many Claudes ran at once", "workflow report for my manager", or asks for this week's or today's numbers. Read-only; never edits the script, the hooks or the log.
allowed-tools: Bash, Read
---

# Claude workflow digest

Report how quickly the user answers their Claude sessions, and how many run in parallel.

## Run

```
~/.claude/scripts/claudeSessionStats.py --since <YYYY-MM-DD> [--until <YYYY-MM-DD>]
```

Pick the period from the request; `--until` is exclusive. "Today" is `--since` today.
"This week" is `--since` this Monday. "Last week" is `--since` last Monday `--until`
this Monday. With no period given, run this week and last week and lead with what
changed between them. Add `--json` when you need the per-day numbers
(`byDay`), and `--idle-after <minutes>` only when the user asks for a different
parked cut-off than the default 120.

If it exits with "No events yet" or "No Claude session activity logged", say logging
started on 2026-10-23 and nothing is recorded for that period; do not offer to backfill
from transcripts, which the user declined.

## What the numbers mean

- The log is `~/.local/state/claude-sessions/events.tsv`, one row per state change:
  epoch, session id, tmux pane, state (`working`, `done`, `permission`, `question`,
  `ended`), pane label (`folder [branch]`), role.
- Every number is split by role. **Workers** are executors launched by
  `/dispatch-ticket` (`CLAUDE_SESSION_ROLE=worker`) or panes flipped with `prefix + r`;
  **orchestrators** are every other session, the ones the user drives by hand;
  **unknown** rows were logged before roles were recorded (before 2026-10-23 11:35).
  A session's latest role applies to its whole history, so a pane flipped with
  `prefix + r` is reclassified back to its start.
- A wait runs from a session stopping for the user until it works again. A wait over
  the idle cut-off is parked: counted, but kept out of the response-time figures, so an
  overnight session does not count against the user.
- Parallelism is time-weighted over the hours at least one session was active.
- A session that crashed without a SessionEnd keeps its last state until now, so one
  very long run or wait at the top of a list is usually that; say so rather than
  presenting it as real.

## Report

Lead with the workers: their median wait, the share answered within 5 and 15 minutes,
and permission waits on their own line because those block a session. A worker waiting
is idle executor time; an orchestrator waiting is usually the user thinking or talking,
so give orchestrators one line (sessions, median wait) and never fold them into the
worker figures. Then one line of worker parallelism (average and peak working). If any
sessions are unknown, say how many and that they are left out. Then the longest waits and longest runs, at
most five each, as the script printed them. Close with at most two sentences on what
stands out. Do not restate what the columns mean unless asked.

When the user wants it for their manager, offer to publish the `--json` numbers as a
private page that leads with responsiveness and shows only folder and branch labels,
never transcript content.
