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
    [ -n "$n" ] || continue
    # one retry: a burst of creates can trip GitHub's secondary rate limit
    "$cellq" state "$n" dropped --repo "$CELLQ_TEST_REPO" >/dev/null 2>&1 \
      || { sleep 5; "$cellq" state "$n" dropped --repo "$CELLQ_TEST_REPO" >/dev/null; } \
      || echo "WARN: could not close fixture issue #$n in $CELLQ_TEST_REPO"
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

  # one_label <n> <group> <value>: exactly one <group>: label and it is the one given
  one_label() {
    local got; got=$(labels_of "$1" | grep "^$2:" || true)
    if [ "$got" = "$2:$3" ]; then ok; else bad "issue #$1 $2 labels [$got], wanted [$2:$3]"; fi
  }
  body_of() { api "issues/$1" --jq '.body'; }

  echo "== online: scope"
  s=$(cq idea "cellq test scope" | jq -r .number); created+=("$s")
  printf '## Definition of done\n\nInputs: x\n\nAcceptance:\n- `cellq x` prints y\n' >"$tmp/dod.md"
  expect_rc 1 scope "$s" --dod "$tmp/dod.md" --route weird --priority 2 --repo "$R"   # bad route
  expect_rc 1 scope "$s" --dod "$tmp/dod.md" --route small --priority 9 --repo "$R"   # priority out of range
  expect_rc 1 scope "$s" --dod "$tmp/nope.md" --route small --priority 2 --repo "$R"  # missing dod file
  printf '## Definition of done\n\n' >"$tmp/bare.md"
  expect_rc 1 scope "$s" --dod "$tmp/bare.md" --route small --priority 2 --repo "$R"  # heading only
  one_state "$s" new                                                                   # nothing written by the failures
  labels_of "$s" | grep -E '^(route|priority):' >/dev/null && bad "failed scope wrote labels" || ok
  [ "$(body_of "$s")" = "" ] && ok || bad "failed scope wrote a body: $(body_of "$s")"
  expect_out "{\"number\": $s, \"route\": \"small\", \"priority\": 2, \"state\": \"ready\"}" \
    scope "$s" --dod "$tmp/dod.md" --route small --priority 2 --repo "$R"
  one_label "$s" route small; one_label "$s" priority 2; one_state "$s" ready
  body_of "$s" | grep -xF '## Definition of done' >/dev/null && ok || bad "scope did not write the heading"
  body_of "$s" | grep -F -- '- `cellq x` prints y' >/dev/null && ok || bad "scope did not write the dod text"
  # re-scope: replaces the section (one heading), moves route and priority, blocks with a reason
  printf '## Definition of done\n\nInputs: z\n' >"$tmp/dod2.md"
  expect_out "{\"number\": $s, \"route\": \"spec\", \"priority\": 4, \"state\": \"blocked\"}" \
    scope "$s" --dod "$tmp/dod2.md" --route spec --priority 4 --blocked "awaiting spec PR" --repo "$R"
  one_label "$s" route spec; one_label "$s" priority 4; one_state "$s" blocked
  [ "$(body_of "$s" | grep -cxF '## Definition of done')" -eq 1 ] && ok || bad "re-scope left more than one dod heading"
  body_of "$s" | grep -F 'Inputs: z' >/dev/null && ok || bad "re-scope did not replace the dod text"
  body_of "$s" | grep -F 'Inputs: x' >/dev/null && bad "re-scope kept the old dod text" || ok
  api "issues/$s/comments" --jq '.[].body' | grep -xF 'state: blocked — awaiting spec PR' >/dev/null && ok || bad "blocked reason comment missing"

  echo "== online: claim + complete"
  k=$(cq idea "cellq test claim" | jq -r .number); created+=("$k")
  expect_rc 1 claim "$k" --repo "$R"                                       # state:new refuses
  one_state "$k" new
  cq state "$k" ready >/dev/null
  out=$(CLAUDE_SESSION_ID=cellq-test-session cq claim "$k")
  [ "$(jq -r .number <<<"$out")" = "$k" ] && [ "$(jq -r .claimed_by <<<"$out")" = "cellq-test-session" ] \
    && jq -r .claimed_at <<<"$out" | grep -Ex '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z' >/dev/null \
    && ok || bad "claim output: $out"
  one_state "$k" in-progress
  api "issues/$k/comments" --jq '.[].body' | grep -E '^claimed by cellq-test-session at [0-9]{4}-' >/dev/null && ok || bad "claim comment missing"
  expect_rc 1 claim "$k" --repo "$R"                                       # in-progress refuses too
  expect_out "{\"number\": $k, \"state\": \"done\"}" complete "$k" --repo "$R"
  one_state "$k" done; issue_is "$k" closed completed
  # an explicit --session wins over the environment; an empty one is refused
  cq state "$k" ready >/dev/null
  expect_rc 1 claim "$k" --session "" --repo "$R"
  one_state "$k" ready
  out=$(CLAUDE_SESSION_ID=from-env cq claim "$k" --session explicit-ref)
  [ "$(jq -r .claimed_by <<<"$out")" = "explicit-ref" ] && ok || bad "claim --session output: $out"
  api "issues/$k/comments" --jq '.[].body' | grep -E '^claimed by explicit-ref at ' >/dev/null && ok || bad "claim --session comment missing"

  echo "== online: depend"
  d=$(cq idea "cellq test depend" | jq -r .number); created+=("$d")
  expect_rc 1 depend "$d" "$d" --repo "$R"                                 # self
  expect_rc 1 depend "$d" 999999 --repo "$R"                               # missing target
  pr=$(api "pulls?state=all&per_page=1" --jq '.[0].number // empty')
  [ -n "$pr" ] && expect_rc 1 depend "$d" "$pr" --repo "$R"                 # a pull request is not an issue
  expect_out "{\"number\": $d, \"depends_on\": [$s]}" depend "$d" "$s" --repo "$R"
  expect_out "{\"number\": $d, \"depends_on\": [$s]}" depend "$d" "$s" --repo "$R"   # idempotent
  [ "$(body_of "$d" | grep -c "^Depends on:")" -eq 1 ] && ok || bad "depend left more than one line"
  [ "$(body_of "$d" | grep -o "#$s\b" | wc -l)" -eq 1 ] && ok || bad "depend twice left more than one #$s"
  expect_out "{\"number\": $d, \"depends_on\": [$s, $k]}" depend "$d" "$k" --repo "$R"
  body_of "$d" | grep -xF "Depends on: #$s, #$k" >/dev/null && ok || bad "depend line: $(body_of "$d" | grep '^Depends on:')"
  # the line sits after the definition-of-done section when one is written later
  cq scope "$d" --dod "$tmp/dod.md" --route small --priority 1 >/dev/null
  body_of "$d" | tr -d '\r' | awk '/^## Definition of done$/{f=1} /^Depends on:/{if(f) print "after"}' | grep -x after >/dev/null \
    && ok || bad "Depends on line is not after the dod section"

  echo "== online: merged-count"
  out=$(cq merged-count)
  grep -Ex '\{"count": [0-9]+\}' <<<"$out" >/dev/null && ok || bad "merged-count output: $out"

  echo "== online: request-feature (self-request to $R)"
  printf 'input: `cellq x`\nexpected: `{"y": 1}`\n' >"$tmp/example.md"
  printf 'https://github.com/%s/blob/main/specs/area.md\n' "$R" >"$tmp/why.md"
  expect_rc 1 request-feature "x" --to not-a-repo --kind api --example "$tmp/example.md" --why "$tmp/why.md" --repo "$R"
  expect_rc 1 request-feature "x" --to "$R" --kind api --example "$tmp/example.md" --why "$tmp/why.md" --priority-hint 7 --repo "$R"
  expect_rc 2 request-feature "x" --to "$R" --kind api --example "$tmp/example.md" --repo "$R"   # --why is required
  out=$(cq request-feature "cellq test request" --to "$R" --kind api --example "$tmp/example.md" --why "$tmp/why.md" --priority-hint 2)
  rn=$(jq -r .remote.number <<<"$out"); mn=$(jq -r .mirror.number <<<"$out"); created+=("$rn" "$mn")
  [ "$rn" -gt 0 ] && [ "$mn" -gt "$rn" ] \
    && [ "$(jq -r .remote.url <<<"$out")" = "https://github.com/$R/issues/$rn" ] \
    && [ "$(jq -r .mirror.url <<<"$out")" = "https://github.com/$R/issues/$mn" ] && ok || bad "request-feature output: $out"
  one_state "$rn" new; one_label "$rn" source "cell:${R#*/}"
  one_state "$mn" blocked; one_label "$mn" source own
  [ "$(api "issues/$rn" --jq .title)" = "cellq test request" ] && ok || bad "remote title"
  [ "$(api "issues/$mn" --jq .title)" = "Request to $R: cellq test request" ] && ok || bad "mirror title"
  for h in 'Requesting cell and issue' 'What is needed' 'Example' 'Why' 'Priority hint' 'Definition of done'; do
    body_of "$rn" | grep -xF "### $h" >/dev/null && ok || bad "remote body lacks heading $h"
  done
  body_of "$rn" | grep -xF "Kind: api" >/dev/null && ok || bad "remote body lacks Kind"
  body_of "$rn" | grep -xF "$R#$mn" >/dev/null && ok || bad "remote body does not name the mirror"
  body_of "$rn" | grep -F 'expected: `{"y": 1}`' >/dev/null && ok || bad "remote body lacks the example"
  body_of "$mn" | grep -F "https://github.com/$R/issues/$rn" >/dev/null && ok || bad "mirror body does not link the remote"
  api "issues/$rn/comments" --jq '.[].body' | grep -F "https://github.com/$R/issues/$mn" >/dev/null && ok || bad "remote has no comment linking the mirror"
  # scope on the form-rendered body: the empty `### Definition of done` becomes the `##` section, the other headings stay
  printf '## Definition of done\n\nInputs: from the example\n\nDepends on: #1\n' >"$tmp/dod3.md"   # a stray convention line is dropped
  expect_out "{\"number\": $rn, \"route\": \"small\", \"priority\": 1, \"state\": \"ready\"}" \
    scope "$rn" --dod "$tmp/dod3.md" --route small --priority 1 --repo "$R"
  [ "$(body_of "$rn" | grep -cxF '## Definition of done')" -eq 1 ] && ok || bad "scope on a form body: ## heading count"
  body_of "$rn" | grep -xF '### Definition of done' >/dev/null && bad "scope on a form body kept the ### heading" || ok
  body_of "$rn" | grep -F 'Inputs: from the example' >/dev/null && ok || bad "scope on a form body did not write the dod"
  body_of "$rn" | grep '^Depends on:' >/dev/null && bad "scope wrote a Depends on line from the dod file" || ok
  for h in 'Requesting cell and issue' 'What is needed' 'Example' 'Why' 'Priority hint'; do
    body_of "$rn" | grep -xF "### $h" >/dev/null && ok || bad "scope on a form body lost heading $h"
  done
fi

echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
