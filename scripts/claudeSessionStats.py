#!/usr/bin/env python3
"""Report on Claude session states logged by ~/.claude/hooks/claudeWaiting.sh.

Splits sessions by role: workers (dispatched executors, CLAUDE_SESSION_ROLE=worker or
flipped with prefix + r), orchestrators (everything else), and unknown (logged before
roles were recorded). A session's latest recorded role applies to its whole history,
so flipping a pane reclassifies everything that session did. Workers lead, because a worker waiting on me is idle time; an
orchestrator waiting is usually me thinking. Within a role: responsiveness (how long
sessions wait on me), then parallelism. A wait longer than --idle-after minutes counts
as parked, not as a response time.

    claudeSessionStats.py            text summary
    claudeSessionStats.py --json     the same numbers as JSON
    claudeSessionStats.py --since 2026-10-19   only intervals starting on or after that day
    claudeSessionStats.py --since 2026-10-12 --until 2026-10-19   and before that day
"""

import argparse
import json
import statistics
import sys
import time
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

EVENT_LOG = Path.home() / ".local/state/claude-sessions/events.tsv"
WAITING_STATES = {"done", "permission", "question"}
ROLES = ("worker", "orchestrator", "unknown")


@dataclass
class Interval:
    session: str
    role: str
    label: str
    state: str
    start: float
    end: float

    @property
    def seconds(self) -> float:
        return self.end - self.start


def readEvents(path: Path):
    events = defaultdict(list)
    for line in path.read_text().splitlines():
        fields = line.split("\t")
        if len(fields) == 5:
            fields.append("unknown")
        if len(fields) != 6:
            continue
        timestamp, session, _pane, state, label, role = fields
        events[session].append((float(timestamp), state, label, role if role in ROLES else "unknown"))
    return events


def buildIntervals(events, now: float):
    intervals = []
    for session, rows in events.items():
        rows.sort()
        knownRoles = [role for *_, role in rows if role != "unknown"]
        sessionRole = knownRoles[-1] if knownRoles else "unknown"
        merged = []
        for timestamp, state, label, role in rows:
            kind = "waiting" if state in WAITING_STATES else state
            previousKind = merged[-1][1] if merged else None
            if previousKind == kind:
                continue
            merged.append((timestamp, kind, state, label, role))
        for index, (start, kind, state, label, _role) in enumerate(merged):
            if kind == "ended":
                continue
            end = merged[index + 1][0] if index + 1 < len(merged) else now
            intervals.append(Interval(session, sessionRole, label, state if kind == "waiting" else kind, start, end))
    return intervals


def percentile(values, fraction):
    ordered = sorted(values)
    return ordered[min(len(ordered) - 1, int(fraction * len(ordered)))]


def concurrency(intervals, idleAfter):
    changes = []
    for interval in intervals:
        kind = "working" if interval.state in ("working", "background", "scheduled") else "waiting"
        end = min(interval.end, interval.start + idleAfter) if kind == "waiting" else interval.end
        changes.append((interval.start, kind, 1))
        changes.append((end, kind, -1))
    changes.sort()
    counts = {"working": 0, "waiting": 0}
    weighted = {"working": 0.0, "waiting": 0.0}
    peaks = {"working": 0, "waiting": 0}
    activeSeconds = 0.0
    previous = None
    for timestamp, kind, delta in changes:
        if previous is not None and (counts["working"] or counts["waiting"]):
            span = timestamp - previous
            activeSeconds += span
            for name in counts:
                weighted[name] += counts[name] * span
        counts[kind] += delta
        peaks[kind] = max(peaks[kind], counts[kind])
        previous = timestamp
    return {
        "activeHours": round(activeSeconds / 3600, 1),
        "averageWorking": round(weighted["working"] / activeSeconds, 1) if activeSeconds else 0,
        "averageWaiting": round(weighted["waiting"] / activeSeconds, 1) if activeSeconds else 0,
        "peakWorking": peaks["working"],
        "peakWaiting": peaks["waiting"],
    }


def waitSummary(waits):
    minutes = [wait.seconds / 60 for wait in waits]
    if not minutes:
        return {"count": 0}
    return {
        "count": len(minutes),
        "medianMinutes": round(statistics.median(minutes), 1),
        "p90Minutes": round(percentile(minutes, 0.9), 1),
        "within2MinutesPercent": round(100 * sum(m <= 2 for m in minutes) / len(minutes)),
        "within5MinutesPercent": round(100 * sum(m <= 5 for m in minutes) / len(minutes)),
        "within15MinutesPercent": round(100 * sum(m <= 15 for m in minutes) / len(minutes)),
    }


def describe(interval):
    return {
        "label": interval.label,
        "reason": interval.state,
        "startedAt": datetime.fromtimestamp(interval.start).strftime("%a %d %b %H:%M"),
        "minutes": round(interval.seconds / 60, 1),
    }


def buildRoleReport(intervals, idleAfter):
    waitingIntervals = [i for i in intervals if i.state in WAITING_STATES]
    waits = [i for i in waitingIntervals if i.seconds <= idleAfter]
    parked = [i for i in waitingIntervals if i.seconds > idleAfter]
    runs = [i for i in intervals if i.state == "working"]
    byDay = defaultdict(list)
    for interval in intervals:
        byDay[datetime.fromtimestamp(interval.start).strftime("%Y-%m-%d")].append(interval)

    return {
        "sessions": len({i.session for i in intervals}),
        "responsiveness": {
            "all": waitSummary(waits),
            "permission": waitSummary([w for w in waits if w.state == "permission"]),
            "question": waitSummary([w for w in waits if w.state == "question"]),
            "finishedTurn": waitSummary([w for w in waits if w.state == "done"]),
            "parkedCount": len(parked),
            "longestWaits": [describe(w) for w in sorted(waits, key=lambda w: -w.seconds)[:10]],
        },
        "parallelism": concurrency(intervals, idleAfter),
        "runs": {
            "count": len(runs),
            "medianMinutes": round(statistics.median([r.seconds / 60 for r in runs]), 1) if runs else 0,
            "longestRuns": [describe(r) for r in sorted(runs, key=lambda r: -r.seconds)[:10]],
        },
        "byDay": {
            day: {
                "waits": waitSummary([i for i in dayIntervals if i.state in WAITING_STATES and i.seconds <= idleAfter]),
                "parallelism": concurrency(dayIntervals, idleAfter),
            }
            for day, dayIntervals in sorted(byDay.items())
        },
    }


def buildReport(intervals, idleAfter):
    return {
        "period": {
            "from": datetime.fromtimestamp(min(i.start for i in intervals)).isoformat(timespec="minutes"),
            "to": datetime.now().isoformat(timespec="minutes"),
            "sessions": len({i.session for i in intervals}),
        },
        "roles": {
            role: buildRoleReport(roleIntervals, idleAfter)
            for role in ROLES
            if (roleIntervals := [i for i in intervals if i.role == role])
        },
    }


ROLE_TITLES = {
    "worker": "WORKERS (dispatched executors)",
    "orchestrator": "ORCHESTRATORS (sessions I drive by hand)",
    "unknown": "UNKNOWN ROLE (logged before roles were recorded)",
}


def printText(report):
    period = report["period"]
    print(f"Claude sessions {period['from']} → {period['to']}  ({period['sessions']} sessions)")
    for role, roleReport in report["roles"].items():
        print(f"\n== {ROLE_TITLES[role]}: {roleReport['sessions']} sessions ==\n")
        printRole(roleReport)


def printRole(report):
    responsiveness = report["responsiveness"]
    print("Responsiveness (time a session waited on me)")
    for name in ("all", "permission", "question", "finishedTurn"):
        summary = responsiveness[name]
        if not summary["count"]:
            continue
        print(
            f"  {name:<13} {summary['count']:>4} waits  median {summary['medianMinutes']}m  "
            f"p90 {summary['p90Minutes']}m  ≤5m {summary['within5MinutesPercent']}%  ≤15m {summary['within15MinutesPercent']}%"
        )
    print(f"  parked (over the idle cut-off): {responsiveness['parkedCount']}\n")
    parallelism = report["parallelism"]
    print(
        f"Parallelism over {parallelism['activeHours']}h active: average {parallelism['averageWorking']} working, "
        f"{parallelism['averageWaiting']} waiting; peak {parallelism['peakWorking']} working, {parallelism['peakWaiting']} waiting\n"
    )
    for title, rows in (("Longest waits", responsiveness["longestWaits"]), ("Longest runs", report["runs"]["longestRuns"])):
        print(title)
        for row in rows:
            print(f"  {row['minutes']:>7}m  {row['startedAt']}  {row['reason']:<10} {row['label']}")
        print()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--idle-after", type=float, default=120, help="minutes before a wait counts as parked")
    parser.add_argument("--since", help="YYYY-MM-DD; report only intervals starting on or after this day")
    parser.add_argument("--until", help="YYYY-MM-DD; report only intervals starting before this day")
    args = parser.parse_args()
    if not EVENT_LOG.exists():
        sys.exit(f"No events yet at {EVENT_LOG}")
    intervals = buildIntervals(readEvents(EVENT_LOG), time.time())
    if args.since:
        since = datetime.strptime(args.since, "%Y-%m-%d").timestamp()
        intervals = [i for i in intervals if i.start >= since]
    if args.until:
        until = datetime.strptime(args.until, "%Y-%m-%d").timestamp()
        intervals = [i for i in intervals if i.start < until]
    if not intervals:
        sys.exit("No Claude session activity logged for that period")
    report = buildReport(intervals, args.idle_after * 60)
    if args.json:
        print(json.dumps(report, indent=2))
    else:
        printText(report)


if __name__ == "__main__":
    main()
