#!/bin/bash
# pre-commit hook: shell file and function names must be lower_snake_case.
status=0
for file in "$@"; do
    name=$(basename "$file")
    if ! [[ "$name" =~ ^[a-z0-9_]+(\.sh)?$ ]]; then
        echo "$file: file name must be lower_snake_case"
        status=1
    fi
    while IFS= read -r match; do
        line=${match%%:*}
        definition=${match#*:}
        function_name=$(sed -E 's/^[[:space:]]*(function[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*).*/\2/' <<<"$definition")
        if ! [[ "$function_name" =~ ^[a-z0-9_]+$ ]]; then
            echo "$file:$line: function name must be lower_snake_case: $function_name"
            status=1
        fi
    done < <(grep -nE '^[[:space:]]*(function[[:space:]]+[A-Za-z_][A-Za-z0-9_]*|[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(\))' "$file")
done
exit $status
