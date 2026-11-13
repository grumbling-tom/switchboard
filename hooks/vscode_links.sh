#!/bin/bash
# SessionStart hook: tells Claude to write references to code as VS Code links, so a
# click opens the file at that line. Off when the plugin's `code_links` setting is off.
[ "${CLAUDE_PLUGIN_OPTION_CODE_LINKS:-vscode}" = vscode ] || exit 0

read -r -d '' rule <<'EOF'
Write each reference to code as a Markdown link that opens it in VS Code, not a bare
`file_path:line_number`: the repo-relative path as the text, the absolute path
(percent-encoded) as the target, like
[hooks/load_tmux.sh:12](vscode://file/abs/path/to/repo/hooks/load_tmux.sh:12).
Links don't render inside backticks or code blocks, so keep plain paths there.
EOF

jq -n --arg rule "$rule" \
    '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $rule}}' 2>/dev/null
exit 0
