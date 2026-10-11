#!/usr/bin/env bash
# PreToolUse hook: block direct pushes to main/master and agent merges.
# Branch protection is the hard stop; this fails faster and cheaper.
#
# Two rules this guard follows, both learned the hard way:
#
# 1. Judge each simple command, not the whole string. The first version
#    grepped the entire Bash command for `git push ... main`, so any chained
#    command that mentioned main after a push elsewhere in the line was
#    blocked (`git fetch origin main && git push -u origin feat/x`), and so
#    was any command whose quoted text happened to contain the words. Now the
#    string is split on `;`, `&&`, `||`, `|` and newlines with quoted text
#    removed first, and only a `git push` whose own arguments target
#    main/master is blocked.
#
# 2. Bootstrap is allowed. Creating a repository needs one push to main
#    before any ruleset exists (new-experiment step 3). That push is
#    recognisable: the remote has no main branch yet. If `git ls-remote`
#    shows the target branch absent on the remote, the push goes through;
#    if the remote cannot be reached, the guard fails closed.
set -euo pipefail

input=$(cat)
tool=$(printf '%s' "$input" | jq -r '.tool_name // empty')
command=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
[ -n "$cwd" ] || cwd=$(pwd)

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

[ -n "$command" ] || exit 0

is_protected() {
  # A refspec targets main/master if its destination side (after the last
  # colon, or the whole thing when there is no colon) names that branch,
  # with or without refs/heads/ and a leading + (force).
  local ref="${1#+}"
  ref="${ref##*:}"
  ref="${ref#refs/heads/}"
  [[ "$ref" =~ ^(main|master)$ ]]
}

remote_has_branch() {
  # 0: branch exists on the remote. 1: remote reachable, branch absent (the
  # bootstrap case). 2: remote unreachable or not a repo.
  local remote="$1" branch="$2" out
  if ! out=$(git -C "$cwd" ls-remote --heads "$remote" "refs/heads/$branch" 2>/dev/null); then
    return 2
  fi
  [ -n "$out" ] && return 0 || return 1
}

check_push() {
  # $@ = the arguments after `git push`.
  local remote="" target="" tok skip=0
  local -a refspecs=()
  for tok in "$@"; do
    if [ "$skip" = 1 ]; then skip=0; continue; fi
    case "$tok" in
      -o|--push-option|--receive-pack|--exec|--repo) skip=1 ;;
      --) ;;
      -*) ;;
      *) if [ -z "$remote" ]; then remote="$tok"; else refspecs+=("$tok"); fi ;;
    esac
  done

  if [ ${#refspecs[@]} -eq 0 ]; then
    # Bare `git push` (or `git push origin`) pushes the current branch.
    local head
    head=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    is_protected "$head" && target="$head"
  else
    for tok in "${refspecs[@]}"; do
      if is_protected "$tok"; then target="${tok#+}"; target="${target##*:}"; target="${target#refs/heads/}"; break; fi
    done
  fi
  [ -n "$target" ] || return 0

  [ -n "$remote" ] || remote=$(git -C "$cwd" config "branch.$target.remote" 2>/dev/null || echo origin)
  remote_has_branch "$remote" "$target"
  case $? in
    1)
      # Bootstrap: the remote has no such branch yet, so nothing is being
      # overwritten and no ruleset can exist. Let the first push through.
      return 0
      ;;
    0)
      echo "Blocked: direct push to $target. Open a PR instead (see /ship)." >&2
      return 2
      ;;
    *)
      echo "Blocked: could not check whether '$remote' already has '$target' (push to main is only allowed when the remote lacks it). Fix the remote or open a PR (see /ship)." >&2
      return 2
      ;;
  esac
}

# Strip quoted text (its contents are data, not commands), then split into
# simple commands. Subshell/group openers are stripped from the front of each.
stripped=$(printf '%s' "$command" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")
while IFS= read -r simple; do
  simple=$(printf '%s' "$simple" | sed -E 's/^[[:space:]]*[({]*[[:space:]]*//; s/[[:space:]]+$//')
  [ -n "$simple" ] || continue
  # shellcheck disable=SC2206
  words=($simple)
  # Skip leading VAR=value assignments.
  while [ ${#words[@]} -gt 0 ] && [[ "${words[0]}" =~ ^[A-Za-z_][A-Za-z_0-9]*= ]]; do
    words=("${words[@]:1}")
  done
  [ ${#words[@]} -gt 0 ] || continue
  case "${words[0]}" in
    git)
      # Skip global git options (-C <path>, -c <kv>) to find the subcommand.
      i=1
      while [ $i -lt ${#words[@]} ]; do
        case "${words[$i]}" in
          -C|-c|--git-dir|--work-tree) i=$((i+2)) ;;
          -*) i=$((i+1)) ;;
          *) break ;;
        esac
      done
      if [ $i -lt ${#words[@]} ] && [ "${words[$i]}" = "push" ]; then
        check_push "${words[@]:$((i+1))}" || exit $?
      fi
      ;;
    gh)
      # Merging is the human gate. On solo accounts the author can't formally
      # approve their own PR, so the ruleset doesn't require reviews — which
      # means agents must never merge. The human merges via the GitHub UI.
      if [ ${#words[@]} -ge 3 ] && [ "${words[1]}" = "pr" ] && [ "${words[2]}" = "merge" ]; then
        echo "Blocked: merging PRs is human-only. Report the PR as ready and stop." >&2
        exit 2
      fi
      ;;
  esac
done < <(printf '%s\n' "$stripped" | sed -E 's/\|\||&&|;|\|/\n/g')

exit 0
