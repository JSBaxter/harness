---
name: implement
description: "The small route: claim a `route:small` issue, build it on a branch within the task thresholds, hand off to /ship; exit through R3 when it outgrows the route."
---

# Implement

Build one `route:small` issue, on one branch, inside the cell's task
thresholds, and hand the result to `/ship`. When the work turns out to be
bigger than the route, leave through R3 rather than carry on.

Argument: an issue number.

`cellq` is the queue adapter (`plugins/jsb-harness/bin/cellq`; in a cloud
session without the plugin, `../harness/plugins/jsb-harness/bin/cellq`;
contract in the harness's `specs/cellq.md`). Every threshold is read through
it from the cell's `thresholds.yml`; this skill carries no numbers. Issue
state is set only through it: never `gh issue edit`, `gh project`, or an MCP
issue-write tool. Reading an issue with `gh issue view --json` or the REST
API is fine.

## Steps

1. **Read, then claim.** Read before claiming, so that a stop leaves the
   issue where it was. Read the issue (`gh issue view <n> --json
   labels,body`): it must carry `route:small` (a `route:spec` issue is not
   this skill's work: stop and say so, touching nothing) and its
   `## Definition of done` must contain at least one testable statement
   (if not, stop and send it back through the adapter so `scope` sees it:
   `cellq state <n> new --reason "implement: definition of done has no
   testable statement"`). Then read every spec the definition names
   (`specs/*.md`) and any ADR in `docs/adr/` touching the area. Only now:
   ```bash
   cellq claim <n>
   ```
   Non-zero exit means the issue is not `state:ready` (or the environment is
   not set up); stop and report the stderr line. Do not work it anyway and
   do not move its state by hand. After a successful claim, every stop in
   this skill goes through the adapter (step 5's exit, or `cellq state <n>
   ready --reason "<why>"` to release the claim); never end a session with
   the issue left in progress.

2. **Plan in-session when it is not obvious.** If the change touches more
   than one file, or you are not sure of the approach, write a short plan in
   the reply before editing: the files you will touch, the change to each,
   the test that proves it, and anything the definition of done leaves open.
   A plan here is a few lines in chat, not a plan file. Otherwise go
   straight to the change. Either way, this is the first moment to notice
   that the work may not fit the route: if the plan already lists more
   files than the route allows (step 5), take the exit now rather than
   after building: the count in the reason is then the planned file count,
   and the `; branch <name>` suffix is omitted because no branch exists yet.

3. **Branch and build.** Branch from the default branch (fetch first;
   `git switch -c <branch> origin/<default>`), implement, and commit small
   Conventional Commits whose bodies say why. Then run every test, lint and
   type command CLAUDE.md names and report their real output in the reply:
   the command, the exit status, and the last lines of what it printed. If
   CLAUDE.md names a placeholder or no command for one of them, say so;
   never substitute a command from another repo or report a run you did
   not do. All green, or fix and rerun.

4. **Keep the spec true.** If the change alters behaviour a spec's
   `## Behavior` section describes, edit that statement in the same branch,
   in the same commit series. Every statement you change, add or remove
   ends by naming the test that asserts it:
   ```markdown
   - <the statement> — test: <test name>
   ```
   A test that does not yet exist is not a test name; write it first. For
   each statement, keep a line in the form `/ship`'s `## Spec changes`
   section wants, ready to hand over in step 6:
   ```markdown
   <spec file>: "<statement>" — test: <test name>
   ```
   A removed statement is listed with `— test: removed`. Spec edits outside
   `## Behavior` (an open question settled, a non-goal added) produce no
   line. When nothing a spec describes changed, the hand-off says `none`.

5. **The R3 exit.** Run this check before `/ship`, and again every time the
   diff grows (another file touched, a fix after a review finding). Read the
   limits:
   ```bash
   cellq threshold task.max_diff_lines
   cellq threshold task.max_files
   git diff --shortstat <base>...HEAD   # files changed, insertions, deletions
   ```
   If `cellq threshold` fails because the repo has no `thresholds.yml`, stop
   and say so; do not substitute a number from memory. The measured file
   count is the `files changed` figure; the measured line count is
   insertions plus deletions. The spec edits from step 4 are part of the
   diff and count.

   Take the exit when any of these holds:
   - the file count exceeds `task.max_files`, or the line count exceeds
     `task.max_diff_lines`;
   - a second session would be needed to finish (the work is not done and
     the context, time or budget left will not finish it);
   - the change alters a contract another cell consumes: an interface
     named in a request-template issue or in an issue labelled
     `source:cell:<name>` (`cellq list` shows the source; read those
     issues' bodies for the interface they depend on), or an output the
     spec marks as consumed by another cell.

   The exit, in this order and nothing else:
   1. Do not open a PR. If `/ship` is already running, abandon it before it
      opens one. If a PR already exists, this skill is finished and the
      threshold trip is reported as a comment on that PR for James; the
      exit below is not taken.
   2. Comment the reason on the issue and move it back to new, through the
      adapter, in one call. The reason names R3 and the measured count or
      cause:
      ```bash
      cellq state <n> new --reason "R3: <count> files > task.max_files"
      cellq state <n> new --reason "R3: <count> diff lines > task.max_diff_lines"
      cellq state <n> new --reason "R3: second session needed — <what remains>"
      cellq state <n> new --reason "R3: contract change — <interface>, consumed by <cell or issue>"
      ```
      For example, `R3: 7 files > task.max_files`. Append `; branch <name>`
      so the next session can find the work.
   3. Delete nothing: the branch, its commits and the worktree stay. Push
      the branch (never the default branch) if the session is remote, so
      it survives the container.
   4. End the session. Say in the reply which condition tripped and the
      count. The issue is in `new`; `scope` re-routes it, usually to the
      spec route. It is not this session's job to carry on, split the work
      into stacked PRs, or trim the diff to fit — a change that does not
      fit the small route needs a spec, not a smaller diff.

6. **Hand off to `/ship`.** With the R3 check passed, run `/ship`, giving it
   the issue number and the spec-change lines from step 4 (or `none`). It
   drafts the `## Spec changes` section from those lines before the first
   review round, opens the PR with `Closes #<n>`, and moves the issue to
   in-review through the adapter. While `/ship` runs, step 5 still applies:
   if a review-round fix pushes the diff past a threshold, take the exit
   instead of opening the PR.
