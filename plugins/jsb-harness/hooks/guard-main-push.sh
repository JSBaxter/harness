#!/usr/bin/env bash
# PreToolUse hook: block direct pushes to main/master from agent sessions.
# Branch protection is the hard stop; this fails faster and cheaper.
set -euo pipefail

input=$(cat)
command=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')

if [[ -z "$command" ]]; then
  exit 0
fi

if printf '%s' "$command" | grep -qE 'git\s+push\b.*\s(origin\s+)?(main|master)\b' ||
   printf '%s' "$command" | grep -qE 'git\s+push\b.*HEAD:(main|master)\b'; then
  echo "Blocked: direct push to main/master. Open a PR instead (see /ship)." >&2
  exit 2
fi

exit 0
