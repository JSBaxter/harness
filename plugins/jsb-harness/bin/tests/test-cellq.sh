#!/usr/bin/env bash
# Tests for bin/cellq. Run: bash plugins/jsb-harness/bin/tests/test-cellq.sh
# Offline section always runs (threshold reads, usage exits). The online
# section runs only when CELLQ_TEST_REPO=o/r names a throwaway repository;
# it creates issues there, checks them through `gh api` (independently of
# the adapter) and closes them at the end. Needs gh and jq when online.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
cellq="$here/../cellq"
tmp=$(mktemp -d)
created=()   # online: issue numbers to close on exit

pass=0; fail=0
ok()   { pass=$((pass+1)); }
bad()  { fail=$((fail+1)); echo "FAIL: $*"; }
# expect_out <expected-stdout> <args...>: exit 0 and stdout matches exactly
expect_out() {
  local want="$1"; shift
  local got rc; set +e; got=$("$cellq" "$@" 2>"$tmp/err"); rc=$?; set -e
  if [ $rc -eq 0 ] && [ "$got" = "$want" ]; then ok; else bad "cellq $* -> rc=$rc stdout=[$got] stderr=[$(cat "$tmp/err")], wanted [$want]"; fi
}
# expect_rc <rc> <args...>: exits with rc, nothing on stdout, one line on stderr
expect_rc() {
  local want="$1"; shift
  local out rc lines; set +e; out=$("$cellq" "$@" 2>"$tmp/err"); rc=$?; set -e
  lines=$(wc -l <"$tmp/err")
  if [ $rc -eq "$want" ] && [ -z "$out" ] && [ "$lines" -eq 1 ]; then ok; else bad "cellq $* -> rc=$rc (wanted $want) stdout=[$out] stderr lines=$lines: $(cat "$tmp/err")"; fi
}

cleanup() {
  for n in "${created[@]:-}"; do
    [ -n "$n" ] && "$cellq" state "$n" dropped --repo "$CELLQ_TEST_REPO" >/dev/null 2>&1 || true
  done
  rm -rf "$tmp"
}
trap cleanup EXIT

echo "== offline: threshold"
cat >"$tmp/thresholds.yml" <<'EOF'
# starter table from specs/cell-operation.md; header comment and blank
# lines between mappings as the project template renders them
route:
  spec_if:
    files_over: 5
    sessions_over: 1

task:
  max_diff_lines: 400  # R4
  max_files: 5
  max_review_minutes: 10
spec:
  max_unfolded_deltas: 3
claim:
  stale_after_hours: 24
review:
  max_rounds: 3
ceremonies:
  grooming:
    every_merges: 5
  health:
    every_merges: 10
  retro:
    every_merges: 15
  structural:
    every_merges: 20
  audit:
    every_merges: 40
edges:
  self: 1.0
  default: 0.5
  other: 0.5
EOF
expect_out 400   threshold task.max_diff_lines --file "$tmp/thresholds.yml"
expect_out 0.5   threshold edges.default --file "$tmp/thresholds.yml"
expect_out 5     threshold ceremonies.grooming.every_merges --file "$tmp/thresholds.yml"
expect_out 40    threshold ceremonies.audit.every_merges --file "$tmp/thresholds.yml"
expect_out 1.0   threshold edges.self --file "$tmp/thresholds.yml"
expect_rc  1     threshold task.nope --file "$tmp/thresholds.yml"          # missing key
expect_rc  1     threshold task --file "$tmp/thresholds.yml"               # mapping, not scalar
expect_rc  1     threshold task.max_files --file "$tmp/missing.yml"        # missing file
printf 'a:\n\tb: 1\n' >"$tmp/tab.yml";        expect_rc 1 threshold a.b --file "$tmp/tab.yml"       # tab indent
printf 'a: 1\n  b: 2\n' >"$tmp/nest.yml";     expect_rc 1 threshold b --file "$tmp/nest.yml"        # nested under a scalar
printf 'a: "x #y"  # c\nb: nan\n' >"$tmp/q.yml"
expect_out '"x #y"' threshold a --file "$tmp/q.yml"                        # quotes keep #, comment after
expect_out '"nan"'  threshold b --file "$tmp/q.yml"                        # not a float
printf 'a: 1\na: 2\n' >"$tmp/dup.yml";        expect_rc 1 threshold a --file "$tmp/dup.yml"         # duplicate key
printf 'a: "x" tail\n' >"$tmp/tail.yml";      expect_rc 1 threshold a --file "$tmp/tail.yml"        # text after a quoted value
# default path: <git toplevel>/thresholds.yml from a subdirectory
git init -q "$tmp/repo" && mkdir -p "$tmp/repo/sub" && cp "$tmp/thresholds.yml" "$tmp/repo/"
cd "$tmp/repo/sub"
expect_out 10    threshold task.max_review_minutes
cd "$here"

echo "== offline: usage"
expect_rc 2 bogus
expect_rc 2 ready
expect_rc 2 scope 1
expect_rc 2 state notanumber ready
expect_rc 2 state 1 ready --repo not-a-repo

if [ -z "${CELLQ_TEST_REPO:-}" ]; then
  echo "skipped: CELLQ_TEST_REPO unset"
else
  R="$CELLQ_TEST_REPO"
  api() { gh api "repos/$R/$1" "${@:2}"; }
  labels_of() { api "issues/$1/labels" --jq '.[].name'; }
  # one_state <n> <state>: exactly one state: label and it is the one given
  one_state() {
    local got; got=$(labels_of "$1" | grep '^state:' || true)
    if [ "$got" = "state:$2" ]; then ok; else bad "issue #$1 state labels [$got], wanted [state:$2]"; fi
  }
  # issue_is <n> <open|closed> [state_reason]
  issue_is() {
    local got; got=$(api "issues/$1" --jq '"\(.state) \(.state_reason // "")"' | sed 's/ *$//')
    local want="$2${3:+ $3}"
    if [ "$got" = "$want" ]; then ok; else bad "issue #$1 is [$got], wanted [$want]"; fi
  }
  cq() { "$cellq" "$@" --repo "$R"; }

  echo "== online: idea + state ($R)"
  expect_rc 1 state 1 nonsense --repo "$R"                                 # validation fails before any write
  expect_rc 1 idea "cellq test bad source" --source weird --repo "$R"
  out=$(cq idea "cellq test $(date -u +%Y%m%dT%H%M%SZ)")
  n=$(jq -r .number <<<"$out"); created+=("$n")
  [ "$n" -gt 0 ] && [ "$(jq -r .url <<<"$out")" = "https://github.com/$R/issues/$n" ] && ok || bad "idea output: $out"
  one_state "$n" new
  labels_of "$n" | grep -x 'source:own' >/dev/null && ok || bad "idea did not set source:own"
  for s in new ready; do
    expect_out "{\"number\": $n, \"state\": \"$s\"}" state "$n" "$s" --repo "$R"
    one_state "$n" "$s"; issue_is "$n" open
  done
  expect_out "{\"number\": $n, \"state\": \"blocked\"}" state "$n" blocked --reason x --repo "$R"
  one_state "$n" blocked
  api "issues/$n/comments" --jq '.[].body' | grep -xF 'state: blocked — x' >/dev/null && ok || bad "reason comment missing"
  expect_out "{\"number\": $n, \"state\": \"done\"}" state "$n" done --repo "$R"
  one_state "$n" done; issue_is "$n" closed completed
  expect_out "{\"number\": $n, \"state\": \"ready\"}" state "$n" ready --repo "$R"       # reopens
  one_state "$n" ready; issue_is "$n" open reopened
  expect_out "{\"number\": $n, \"state\": \"dropped\"}" state "$n" dropped --repo "$R"
  one_state "$n" dropped; issue_is "$n" closed not_planned

  echo "== online: link"
  p=$(cq idea "cellq test parent" | jq -r .number); created+=("$p")
  c=$(cq idea "cellq test child" --source agent | jq -r .number); created+=("$c")
  labels_of "$c" | grep -x 'source:agent' >/dev/null && ok || bad "idea --source agent not set"
  expect_out "{\"parent\": $p, \"child\": $c}" link "$p" "$c" --repo "$R"
  api "issues/$p/sub_issues" --jq '.[].number' | grep -x "$c" >/dev/null && ok || bad "#$c not in sub-issues of #$p"
  expect_rc 1 link 999999 "$c" --repo "$R"                                 # bad parent fails
fi

echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
