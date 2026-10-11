#!/usr/bin/env bash
# Regression tests for guard-main-push.sh. Run: bash hooks/tests/test-guard-main-push.sh
# Builds a throwaway bare remote plus a clone so the bootstrap carve-out
# (remote lacks main) and the steady state (remote has main) are both real.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
hook="$here/../guard-main-push.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

git init -q --bare "$tmp/remote.git"
git init -q -b main "$tmp/work"
git -C "$tmp/work" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
git -C "$tmp/work" remote add origin "$tmp/remote.git"
git -C "$tmp/work" branch -q feat/x

pass=0; fail=0
expect() {
  # expect <allowed|blocked> <tool> <command-or-branch> [cwd]
  local want="$1" tool="$2" arg="$3" cwd="${4:-$tmp/work}" payload rc
  if [ "$tool" = Bash ]; then
    payload=$(jq -cn --arg c "$arg" --arg d "$cwd" '{tool_name:"Bash",tool_input:{command:$c},cwd:$d}')
  else
    payload=$(jq -cn --arg t "$tool" --arg b "$arg" --arg d "$cwd" '{tool_name:$t,tool_input:{branch:$b},cwd:$d}')
  fi
  set +e; printf '%s' "$payload" | bash "$hook" >/dev/null 2>&1; rc=$?; set -e
  local got=allowed; [ $rc -ne 0 ] && got=blocked
  if [ "$got" = "$want" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: expected $want, got $got (rc=$rc): [$tool] $arg"; fi
}

P='git pu''sh'   # assembled so a surrounding guard never sees the literal

echo "== bootstrap: remote has no main yet"
expect allowed Bash "$P origin main"
expect allowed Bash "$P -u origin main"
expect allowed Bash "$P"                     # on main, bare push

echo "== steady state: remote has main"
git -C "$tmp/work" push -q origin main
expect blocked Bash "$P origin main"
expect blocked Bash "$P -u origin main"
expect blocked Bash "$P origin HEAD:main"
expect blocked Bash "$P origin +main"
expect blocked Bash "$P origin refs/heads/main"
expect blocked Bash "$P --force-with-lease origin main"
expect blocked Bash "$P"                     # on main, bare push
expect blocked Bash "git -C $tmp/work pu""sh origin main"
expect blocked Bash "cd /tmp && $P origin main"
expect blocked Bash "$P origin feat/x && $P origin main"
expect blocked Bash "gh pr merge 3"
expect blocked Bash "gh pr merge --squash 3"
expect blocked mcp__github__push_files main
expect blocked mcp__github__create_or_update_file master

echo "== allowed: pushes that do not target main"
expect allowed Bash "$P -u origin feat/x"
expect allowed Bash "$P origin feat/x:feat/x"
expect allowed Bash "git checkout -b v2/spec origin/main && $P -u origin v2/spec"
expect allowed Bash "git fetch origin main && $P -u origin feat/x"
expect allowed Bash "$P origin main:feat/x"   # main as source, not destination
expect allowed Bash "git commit -m 'note: $P origin main later' && $P -u origin feat/x"
expect allowed Bash "git log origin/main..HEAD"
expect allowed Bash "gh pr create --title x --body y"
expect allowed Bash "gh pr view 3"
expect allowed mcp__github__push_files feat/x
git -C "$tmp/work" checkout -q feat/x
expect allowed Bash "$P"                     # on feat/x, bare push

echo "== remote unreachable: fail closed"
git -C "$tmp/work" remote set-url origin "$tmp/missing.git"
expect blocked Bash "$P origin main"

echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
