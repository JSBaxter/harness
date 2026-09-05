#!/usr/bin/env bash
# PreToolUse hook: block direct pushes to main/master from agent sessions.
# Branch protection is the hard stop; this fails faster and cheaper.
set -euo pipefail

input=$(cat)
tool=$(printf '%s' "$input" | jq -r '.tool_name // empty')
command=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')

# Shelling out is not the only route to main. Where the GitHub MCP tools are
# available they do the same things with no shell involved, and a guard that
# only reads .tool_input.command waves every one of them through — the exact
# gap chord-recommender#31's review found. Worse, CLAUDE.md tells agents to
# reach for these tools whenever `gh` is absent, so the bypass is the
# documented path, not an obscure one.
case "$tool" in
  mcp__github__merge_pull_request|mcp__github__enable_pr_auto_merge)
    echo "Blocked: merging PRs is human-only ($tool). Report the PR as ready and stop." >&2
    exit 2
    ;;
  mcp__github__create_or_update_file|mcp__github__push_files|mcp__github__delete_file)
    # These write straight to a named branch, bypassing the working tree
    # entirely — there is no `git push` for the branch guard below to catch.
    branch=$(printf '%s' "$input" | jq -r '.tool_input.branch // empty')
    if [[ "$branch" =~ ^(main|master)$ ]]; then
      echo "Blocked: $tool writes directly to '$branch'. Open a PR instead (see /ship)." >&2
      exit 2
    fi
    exit 0
    ;;
esac

if [[ -z "$command" ]]; then
  exit 0
fi

if printf '%s' "$command" | grep -qE 'git\s+push\b.*\s(origin\s+)?(main|master)\b' ||
   printf '%s' "$command" | grep -qE 'git\s+push\b.*HEAD:(main|master)\b'; then
  echo "Blocked: direct push to main/master. Open a PR instead (see /ship)." >&2
  exit 2
fi

# Merging is the human gate. On solo accounts the author can't formally
# approve their own PR, so the ruleset doesn't require reviews — which means
# agents must never merge. The human merges via the GitHub UI.
if printf '%s' "$command" | grep -qE '(^|[;&|(]\s*)gh\s+pr\s+merge\b'; then
  echo "Blocked: merging PRs is human-only. Report the PR as ready and stop." >&2
  exit 2
fi

exit 0
