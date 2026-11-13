#!/bin/bash
# SessionStart hook: tells Claude to write references to tickets and projects in a task
# tracker (Linear, Jira and the like) as links titled with their name, so a click opens
# them. Off when the plugin's `ticket_links` setting is off.
[ "${CLAUDE_PLUGIN_OPTION_TICKET_LINKS:-true}" = true ] || exit 0

read -r -d '' rule <<'EOF'
Write each reference to a ticket, issue or project in a task tracker (Linear, Jira and
the like) as a Markdown link titled with its name, not a bare URL or ID: the title as
the text, the tracker's URL as the target, like
[Broker and carrier on quotes](https://linear.app/acme/project/broker-and-carrier-on-quotes-8f089e6e9c24/overview).
For an issue, lead the text with its key, like [ENG-123 Fix quote totals](https://linear.app/acme/issue/ENG-123).
Use the real URL from the tracker; if you don't have it, give the key or title as plain
text rather than guessing one. Links don't render inside backticks or code blocks, so
keep plain text there.
EOF

jq -n --arg rule "$rule" \
    '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $rule}}' 2>/dev/null
exit 0
