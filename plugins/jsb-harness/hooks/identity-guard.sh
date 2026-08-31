#!/usr/bin/env bash
# PreToolUse hook: enforce per-directory GitHub identity.
# Blocks `git push` when the effective git user.email doesn't match the
# identity this directory requires, and blocks raw `gh` mutations in
# non-default-identity directories (use gh-as instead). Fails closed on
# placeholder config; no-op when no identity map exists.
set -euo pipefail

input=$(cat)
command=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')

MAP="$HOME/.claude/identities.local.json"
[ -f "$MAP" ] || exit 0
[ -n "$command" ] || exit 0

# Only guard pushes and gh mutations. (`gh-as` deliberately doesn't match.)
printf '%s' "$command" | grep -qE '(^|[;&|(]\s*)(git\s+push|gh\s+(repo|pr|issue|api|secret|release|gist|auth\s+switch))' || exit 0

[ -n "$cwd" ] || cwd=$(pwd)
cwd_abs=$(readlink -f "$cwd" 2>/dev/null || printf '%s' "$cwd")

# Longest-prefix match of cwd against each identity's dirs.
best=""
best_len=0
while IFS=$'\t' read -r name dir; do
  dir="${dir/#\~/$HOME}"
  dir_abs=$(readlink -f "$dir" 2>/dev/null || printf '%s' "$dir")
  case "$cwd_abs/" in
    "$dir_abs"/*)
      if [ "${#dir_abs}" -gt "$best_len" ]; then
        best="$name"
        best_len=${#dir_abs}
      fi
      ;;
  esac
done < <(jq -r '.identities | to_entries[] | .key as $k | .value.dirs[]? | [$k, .] | @tsv' "$MAP")

[ -n "$best" ] || exit 0

expected_email=$(jq -r --arg k "$best" '.identities[$k].email // empty' "$MAP")
gh_config_dir=$(jq -r --arg k "$best" '.identities[$k].ghConfigDir // empty' "$MAP")

if printf '%s' "$expected_email$gh_config_dir" | grep -q 'PLACEHOLDER'; then
  echo "Blocked: identity '$best' still has PLACEHOLDER values in ~/.claude/identities.local.json — fill them in first." >&2
  exit 2
fi

if printf '%s' "$command" | grep -qE '(^|[;&|(]\s*)git\s+push'; then
  actual_email=$(git -C "$cwd_abs" config user.email 2>/dev/null || echo "")
  if [ "$actual_email" != "$expected_email" ]; then
    echo "Blocked: git user.email here is '${actual_email:-unset}' but directory identity '$best' requires '$expected_email'. Check the includeIf blocks in ~/.gitconfig." >&2
    exit 2
  fi
fi

if [ -n "$gh_config_dir" ] && printf '%s' "$command" | grep -qE '(^|[;&|(]\s*)gh\s'; then
  if ! printf '%s' "$command" | grep -q 'GH_CONFIG_DIR'; then
    echo "Blocked: raw 'gh' in identity '$best' directory would act as the default account. Use: gh-as $best <args>" >&2
    exit 2
  fi
fi

exit 0
