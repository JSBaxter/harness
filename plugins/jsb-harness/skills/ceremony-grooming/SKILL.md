---
name: ceremony-grooming
description: Backlog grooming. Runs from a ceremony issue the cell-ceremony workflow files and ends in PRs James merges, issues, or a report, never a direct change to the default branch. Returns stale claims to ready (R8), reports drop candidates, rescores by the edge table, links dependencies, flags specs for splitting (R7), routes issues still in new, and converges a parent whose tasks all closed. Invoked by name from the ceremony issue; never self-selected.
---

# Ceremony: grooming

Tidy the queue so that `cellq ready` tells the truth: nothing is held by a
session that went away, every ready issue carries the priority the current
edge table gives it, prose dependencies are recorded where `ready` can see
them, specs that have piled up deltas are flagged, and nothing sits in new.
Everything the ceremony does is an adapter call, an issue, or a report; it
never pushes to the default branch and never merges.

Argument: the ceremony issue number (the workflow prompt is `Run
/ceremony-grooming on issue #<n>`). The issue carries `source:ceremony` and
is already `state:ready`; it is the place the report goes and the thing this
skill closes last.

`cellq` is the queue adapter (`plugins/jsb-harness/bin/cellq`; in a cloud
session without the plugin, `../harness/plugins/jsb-harness/bin/cellq`;
contract in the harness's `specs/cellq.md`). Every issue-state change in
this skill goes through it, and every threshold is read through it from the
cell's `thresholds.yml`; this skill carries no numbers. Never set a label,
state, body or priority with raw `gh`, a project board, or a GitHub MCP
write tool; the adapter is the only writer. Reading is free: `gh issue view
<n> --json ...`, `gh pr list`, `git log`, or the REST endpoints under
`repos/<o>/<r>/` when `gh` is absent. If a `cellq threshold` read fails,
stop and report its stderr line; never substitute a value from memory or
from another repository.

Record, as you go, one line per action taken (issue, what changed, why);
step 9 turns those lines into the report.

## Steps

1. **Open the ceremony issue.** Read it (`gh issue view <n> --json
   title,labels,state,comments`). It must be open, carry `source:ceremony`,
   and its title must name grooming; otherwise stop and report what it is.
   Find the previous grooming: the most recently closed issue with
   `source:ceremony` whose title names grooming (`cellq list --state done
   --source ceremony`, then by title and `created_at`). Its creation time
   is "the last grooming" below; when there is none, the cell has not been
   groomed before and the steps that compare against it say so in the
   report instead of guessing.

2. **Stale claims (R8).** Read the age limit, then the claims:
   ```bash
   cellq threshold claim.stale_after_hours
   cellq list --state in-progress
   ```
   Each row carries `claimed_at` (from the adapter's `claimed by <ref> at
   <time>` comment). A claim is stale when now minus `claimed_at` exceeds
   the limit *and* the branch shows no activity since the claim: no open PR
   that references the issue (`gh pr list --state open --search "#<n>"`),
   and no commit on any branch newer than `claimed_at` whose message or
   branch name names the issue (`git fetch --all --prune`, then `git log
   --all --since=<claimed_at> --grep='#<n>'`, and for each branch matched
   by `git branch -r --list '*<n>*'` the date of `git show -s --format=%cI
   <branch>`). Activity means a session is still working it, even slowly:
   leave it alone and list it in the report as "old claim, active".
   Otherwise release it:
   ```bash
   cellq state <n> ready --reason "stale claim: R8"
   ```
   The adapter posts the reason as the comment; the row in the report
   carries the claimant and the claim time. An issue with no `claimed_at`
   while in progress (moved there by hand) is treated as a claim at its
   last update time (`gh issue view <n> --json updatedAt`) and the report
   says so.

3. **Drop candidates.** This ceremony never drops an issue on its own
   judgement. There are two parts:
   - **James said drop.** For every open issue (`cellq list` across every
     open state; `in-progress` and `in-review` included), read its comments.
     A comment by the repository owner whose whole body is the word `drop`,
     posted after the last grooming (or at any time, when there was none),
     is an instruction:
     ```bash
     cellq state <n> dropped --reason "drop: James's comment of <date>"
     ```
   - **Candidates for James.** For every other open issue in `new`,
     `needs-input`, `ready` or `blocked`, take its last activity as
     `updatedAt` (`gh issue view <n> --json updatedAt`; a label, body or
     comment change all move it). An issue whose last activity is older
     than the last grooming has gone a whole period untouched: list it in
     the report under "Drop candidates" with its number, title, state and
     last-activity date, oldest first. Do nothing to it. James decides by
     commenting `drop` on the issue, which the next grooming acts on, or by
     closing it himself. With no previous grooming, the section says "no
     reference period yet" and lists nothing.

   There is no drop threshold key in `thresholds.yml` and this skill does
   not invent one; the reference point is the previous ceremony.

4. **Rescore by the edge table.** Edge weights change when the retro's
   threshold PR merges, so a priority set at scoping can be out of date.
   For each issue in `cellq list --state ready`, recompute the priority
   exactly as `scope` step 5 does: the hint from the body's `Priority hint`
   field when it has a value, else the default `scope` uses when there is
   none; times the weight for the issue's `source:` label:
   - `source:own`, or none: `cellq threshold edges.self`
   - `source:cell:<name>`: `cellq threshold edges.<name>`, falling back to
     `cellq threshold edges.default` when the read exits 1 naming the key
   - `source:agent` or `source:ceremony`: `cellq threshold edges.default`

   Round to the nearest integer, halves up, and clamp to the `priority:`
   range. Compare with the `priority` the row carries. Only when it differs,
   re-apply through the adapter, keeping the route and the definition of
   done the issue already has: extract the `## Definition of done` section
   from the body into a temporary file (the heading is its first line) and
   call
   ```bash
   cellq scope <n> --dod <file> --route <its route label> --priority <p>
   ```
   The issue stays ready. An issue in ready with no definition of done or
   no route label is malformed: do not rescore it; send it back so step 7
   routes it properly:
   ```bash
   cellq state <n> new --reason "grooming: ready without a definition of done or route"
   ```

5. **Link dependencies.** `cellq ready` holds an issue back only for
   numbers on its `Depends on:` line. For each open issue (every open
   state), read the body for prose that names another issue as a
   prerequisite: "after #m", "depends on #m", "blocked by #m", "needs #m
   first", "once #m lands", and the like. For each such `#m` that is open,
   is in this repository, and is not already on the line:
   ```bash
   cellq depend <n> <m>
   ```
   Not a dependency: `Parent: #m`, `Closes #m`, a sub-issue listing, a
   "related" or "see also" mention, or a closed issue. When the issue is in
   ready and cannot start before `#m` closes (as opposed to merging after
   it), also block it, as `scope` step 6 does:
   ```bash
   cellq state <n> blocked --reason "depends on #<m>"
   ```

6. **Spec pile-up (R7).** For each `specs/*.md` that is not a plan file,
   count the deltas under `## Pending changes`: each `###` heading below it
   is one delta; `None` or no headings is none. Read the limit:
   ```bash
   cellq threshold spec.max_unfolded_deltas
   ```
   A spec whose count exceeds the limit is flagged, once: if no open issue
   is titled `Split spec: <path>` (`cellq list --source ceremony`, then by
   title), write a body naming the spec, the count, the limit key and each
   delta's heading, plus a `## Definition of done` section whose
   acceptance statements are that `/split-spec` has run on the spec and
   each delta is either a task sub-issue of its parent or a sub-spec of its
   own, and open it:
   ```bash
   cellq idea "Split spec: <path>" --body <file> --source ceremony
   ```
   Then make it ready (the `scope` skill stops on `source:ceremony`, so
   the ceremony scopes what it opens): the route is `small` (one
   `/split-spec` run, one PR), the priority as step 4 computes for
   `source:ceremony`:
   ```bash
   cellq scope <n> --dod <dod-file> --route small --priority <p>
   ```

7. **Route what is still new.** For each issue in `cellq list --state new`
   that does not carry `source:ceremony`, run `/scope` on it (the skill in
   `plugins/jsb-harness/skills/scope/SKILL.md`; from source in a cloud
   session) and record the state it set. An issue in new that carries
   `source:ceremony` was opened by a ceremony that did not scope it, or was
   sent back by step 4; write its definition of done from its body as that
   ceremony would have and record it with `cellq scope` as step 6 does.
   When `/scope` ends in `needs-input`, that is a result, not a failure:
   the report lists the question.

8. **Converge a parent whose tasks all closed.** Events created with the
   Actions token do not chain (the plan's risk table): a sub-issue that
   `cellq complete` closed from inside `cell-ceremony.yml` fires no
   `cell-converge.yml`, so a finished parent can sit unconverged. For each
   open issue with `route:spec`:
   ```bash
   cellq parent <n>
   ```
   When `all_closed` is true and `sub_issues` is not empty, look for its
   fold PR: a PR, open or merged, labelled `proposal`, whose body closes or
   names the parent (`gh pr list --state all --label proposal --search
   "#<n>"`). When there is none, run `/converge` on the parent (the skill in
   `plugins/jsb-harness/skills/converge/SKILL.md`) in this session, one
   parent at a time, and record what it produced: a fold PR URL or a gap
   issue URL. When the converge skill is not installed and cannot be read
   from source, do not improvise a fold; list the parent in the report as
   "needs converge" and move on.

9. **Report and close.** Post the report as a comment on the ceremony
   issue (a comment is not state: `gh issue comment <n> --body-file
   <report>`, or `POST repos/<o>/<r>/issues/<n>/comments` through the
   REST API when `gh` is absent), in this form:

   ```markdown
   ## Grooming report — <date>

   Previous grooming: #<n> (<date>) | none

   | Action | Count |
   |---|---|
   | Stale claims returned to ready (R8) | <n> |
   | Old claims left active | <n> |
   | Dropped on James's instruction | <n> |
   | Drop candidates (below) | <n> |
   | Priorities rescored | <n> |
   | Dependencies linked | <n> |
   | Specs flagged for splitting (R7) | <n> |
   | Issues routed from new | <n> (ready <n>, blocked <n>, needs-input <n>) |
   | Parents converged | <n> (fold PRs <n>, gap issues <n>, needs converge <n>) |

   ### Drop candidates
   | Issue | State | Last activity |
   |---|---|---|
   | #<n> <title> | <state> | <date> |

   ### Actions
   - #<n>: <what changed> — <why, with the threshold key or rule>
   ```

   Every issue, PR and threshold key the ceremony touched appears under
   "Actions", so James can check each one. Then close the ceremony issue:
   ```bash
   cellq complete <ceremony issue>
   ```
   Report the ceremony issue URL and the counts in the reply.
