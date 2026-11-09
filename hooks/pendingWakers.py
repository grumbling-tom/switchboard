#!/usr/bin/env python3
"""Reads a Claude session transcript and prints what will wake the session on its own.

Prints "<state> <deadline>" — state is background (a task the harness will report
back on) or scheduled (only a /loop wakeup or a cron); deadline is the epoch second
after which the pane counts as waiting on me again, 0 when nothing bounds it. Prints
nothing when no waker is pending.

A background Bash job never has to end (a dev server), so it counts for
BASH_JOB_COUNTS_FOR_SECONDS only; a Monitor counts until its own timeout; a wakeup or
one-shot cron until its prompt is delivered, or it was due plus WAKEUP_GRACE_SECONDS.
"""

import json
import re
import sys
import time
from datetime import datetime

BASH_JOB_COUNTS_FOR_SECONDS = 3600
WAKEUP_GRACE_SECONDS = 300
TERMINAL_NOTIFICATION = re.compile(
    r"<task-id>([^<]+)</task-id>.*?<status>(?:completed|failed|killed|stopped)</status>",
    re.S,
)
WAKER_TOOLS = {"Bash", "Monitor", "Agent", "Workflow", "ScheduleWakeup", "CronCreate", "CronDelete", "TaskStop"}
LINE_HINTS = ("tool_use", "task-notification", "queue-operation")


def epochSeconds(timestamp):
    try:
        return datetime.fromisoformat(timestamp.replace("Z", "+00:00")).timestamp()
    except (AttributeError, ValueError):
        return time.time()


def notificationTexts(entry):
    if entry.get("type") == "queue-operation":
        yield entry.get("content") or ""
    attachment = entry.get("attachment") or {}
    if attachment.get("type") == "queued_command":
        yield attachment.get("prompt") or ""
    if (entry.get("origin") or {}).get("kind") == "task-notification":
        content = (entry.get("message") or {}).get("content")
        yield content if isinstance(content, str) else json.dumps(content)


def deliveredPrompt(entry):
    if entry.get("type") == "queue-operation" and entry.get("operation") == "enqueue":
        return entry.get("content")
    return None


def main(transcriptPath):
    now = time.time()
    toolUses = {}
    tasks = {}
    endedTaskIds = set()
    crons = {}
    cronPrompts = {}
    wakeupAt = 0
    wakeupPrompt = None

    with open(transcriptPath, errors="ignore") as transcript:
        for line in transcript:
            if not any(hint in line for hint in LINE_HINTS):
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue

            for text in notificationTexts(entry):
                endedTaskIds.update(match.group(1) for match in TERMINAL_NOTIFICATION.finditer(text))

            prompt = deliveredPrompt(entry)
            if prompt is not None:
                if prompt == wakeupPrompt:
                    wakeupAt = 0
                for cronId, cronPrompt in list(cronPrompts.items()):
                    if prompt == cronPrompt and crons.get(cronId):
                        crons.pop(cronId)

            content = (entry.get("message") or {}).get("content")
            if not isinstance(content, list):
                continue
            for block in content:
                if not isinstance(block, dict):
                    continue
                if block.get("type") == "tool_use" and block.get("name") in WAKER_TOOLS:
                    toolUses[block.get("id")] = (block.get("name"), block.get("input") or {})
                if block.get("type") != "tool_result":
                    continue
                name, toolInput = toolUses.get(block.get("tool_use_id"), (None, {}))
                result = entry.get("toolUseResult")
                if not name or not isinstance(result, dict):
                    continue
                launchedAt = epochSeconds(entry.get("timestamp"))
                if name == "Bash" and result.get("backgroundTaskId"):
                    tasks[result["backgroundTaskId"]] = launchedAt + BASH_JOB_COUNTS_FOR_SECONDS
                elif name == "Monitor" and result.get("taskId"):
                    tasks[result["taskId"]] = launchedAt + (result.get("timeoutMs") or 1800000) / 1000 + 60
                elif name == "Agent" and result.get("isAsync") and result.get("agentId"):
                    tasks[result["agentId"]] = 0
                elif name == "Workflow" and result.get("taskId"):
                    tasks[result["taskId"]] = 0
                elif name == "TaskStop" and result.get("task_id"):
                    endedTaskIds.add(result["task_id"])
                elif name == "ScheduleWakeup":
                    wakeupAt = 0 if result.get("stopped") else (result.get("scheduledFor") or 0) / 1000
                    wakeupPrompt = toolInput.get("prompt")
                elif name == "CronCreate" and result.get("id"):
                    crons[result["id"]] = 0 if result.get("recurring") else (result.get("nextFireAt") or 0) / 1000 + WAKEUP_GRACE_SECONDS
                    cronPrompts[result["id"]] = toolInput.get("prompt")
                elif name == "CronDelete" and result.get("id"):
                    crons.pop(result["id"], None)

    def isLive(deadline):
        return deadline == 0 or deadline > now

    taskDeadlines = [deadline for taskId, deadline in tasks.items() if taskId not in endedTaskIds and isLive(deadline)]
    scheduleDeadlines = [deadline for deadline in crons.values() if isLive(deadline)]
    if wakeupAt and wakeupAt + WAKEUP_GRACE_SECONDS > now:
        scheduleDeadlines.append(wakeupAt + WAKEUP_GRACE_SECONDS)

    deadlines = taskDeadlines + scheduleDeadlines
    if not deadlines:
        return
    state = "background" if taskDeadlines else "scheduled"
    print(state, 0 if 0 in deadlines else int(max(deadlines)))


if __name__ == "__main__":
    if len(sys.argv) > 1:
        main(sys.argv[1])
