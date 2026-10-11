---
name: ceremony-retro
description: Workflow retro. Runs from a ceremony issue the cell-ceremony workflow files and ends in PRs James merges, issues, or a report, never a direct change to the default branch. Computes the fixed report over the PRs merged since the previous retro (review rounds and rework by PR size band, route and source; cost per merged PR by surface and model; gate load; re-routes, gaps and breaks) and proposes threshold and edge-weight changes as one proposal PR to thresholds.yml, each change citing the report, or posts the report with no change proposed. Invoked by name from the ceremony issue; never self-selected.
---

# Ceremony: retro

Compute the same report every time (design section ten) from what GitHub
already keeps about the PRs merged since the last retro, and let the report
decide whether any value in `thresholds.yml` should move. The retro is the
only thing in the cell that proposes a change to that file, and it does so
as one PR that James merges; a change with no row of the report behind it
is not proposed. Everything the ceremony does is a read, an adapter call,
one proposal PR, or a report; it never pushes to the default branch and
never merges.

Argument: the ceremony issue number (the workflow prompt is `Run
/ceremony-retro on issue #<n>`). The issue carries `source:ceremony` and is
already `state:ready`; it is the place the report goes when no PR is
opened, and the thing this skill closes last.

`cellq` is the queue adapter (`plugins/jsb-harness/bin/cellq`; in a cloud
session without the plugin, `../harness/plugins/jsb-harness/bin/cellq`;
contract in the harness's `specs/cellq.md`). Every state this skill sets
goes through it, and every threshold is read through it from the cell's
`thresholds.yml`; this skill carries no numbers. Never set a label, state
or body with raw `gh`, a project board, or a GitHub MCP write tool. Reading
is free, and this ceremony is mostly reading: the REST endpoints under
`repos/<o>/<r>/` (`gh api --paginate`, or `curl` with the token when `gh`
is absent) for pulls, issues, commits, statuses and comments. If a `cellq
threshold` read fails, stop and report its stderr line; never substitute a
value from memory or from another repository.

Record, as you go, one row per merged PR (number, linked issue, route,
source, diff lines, files, size band, review runs, rounds, rework commits,
surface, model, cost) and one per counted event (re-route, gap, break, with
the issue or comment URL); steps 3 and 4 are computed from those rows and
the PR body or report cites them.

## Steps

1. **Open the ceremony issue and fix the window.** Read the ceremony issue
   (`gh issue view <n> --json title,labels,state`): it must be open, carry
   `source:ceremony`, and its title must name the retro; otherwise stop and
   report what it is. Find the previous retro: the most recently closed
   issue with `source:ceremony` whose title names the retro (`cellq list
   --state done --source ceremony`, then by title and `created_at`), and
   read its close time (`gh issue view <m> --json closedAt`). The window
   is everything merged after that time; when there is no previous retro,
   the window is the whole repository and the report says so.

2. **Gather the merged PRs and their issues** (reads only). List closed
   PRs (`gh api --paginate "repos/<o>/<r>/pulls?state=closed&sort=updated&
   direction=desc"`) and keep those whose `merged_at` is inside the window;
   stop paginating once a page's every `updated_at` is older than the
   window start. For each merged PR read from the pull endpoint
   (`repos/<o>/<r>/pulls/<p>`): `additions`, `deletions` and
   `changed_files` (diff lines are additions plus deletions, the measure
   `implement` step 5 uses); the labels (`proposal` means the gate skipped
   it); the body; `merge_commit_sha` and `head.sha`. Then:
   - **Linked issue.** The issue a closing keyword in the body names
     (`Closes #n`, `Fixes #n`, `Resolves #n`, any case), else the first
     `#n` in the body or the branch name that is an issue in this
     repository; none when there is none. Its `route:` and `source:` labels
     come from `cellq list --state done` (one call, matched by `number`),
     and from `cellq list` across the open states when the issue is still
     open (a PR merged against an open issue). A PR with no linked issue,
     or one whose issue carries no route or source label, is counted under
     `none` in those rows, never dropped: a merged PR that bypassed the
     queue is itself a finding.
   - **Review runs and rounds.** The gate stamps one `claude-review` status
     per run on the head it reviewed and posts one summary comment per run
     (`rounds run, findings fixed, Minor findings noted`). Review runs for
     a PR are the `claude-review` statuses across its commits
     (`repos/<o>/<r>/pulls/<p>/commits`, then
     `repos/<o>/<r>/commits/<sha>/statuses` filtered to that context; one
     per distinct run, so a status re-read on the same sha counts once).
     Rounds are the sum of the rounds each gate summary comment states
     (`repos/<o>/<r>/issues/<p>/comments`, the comments by the Actions
     bot); a `proposal` PR's summary says the gate was skipped and counts
     as zero rounds; a summary that states no round count is recorded as
     "not stated" and the PR is left out of the rounds average but kept in
     every other column.
   - **Rework commits.** Commits of the PR whose subject carries the gate's
     `review` scope: `fix(review):`, `refactor(review):` or
     `test(review):` (the three forms the gate's prompt writes).
   - **Surface.** From the claim comment on the linked issue (`claimed by
     <ref> at <time>`, the `claimed_by` field of the `cellq list` row): a
     ref of digits only is an Actions run id, so `Actions`; a ref of the
     form `user@host` is `local`; any other ref is a Claude Code session id
     from the laptop or the cloud, which the ref alone does not tell apart:
     it is `cloud` when the PR body carries the cloud marker CLAUDE.md asks
     cloud sessions to write (`followed /<skill> from source`) or a
     `claude.ai` session link, else `local`. No claim comment (a PR with no
     linked issue, or an issue moved by hand) is `unknown`. Say the rule
     once in the report so the surface column is read for what it is.
   - **Model.** The gate summary comment, when it names the model it ran
     with; else `not named`. (The design's usage record, when the cell has
     one, names the model per session; read it when CLAUDE.md says where
     it is.)
   - **Cost.** The usage record of design section ten, when the cell keeps
     one and CLAUDE.md or the README says where: the sum of the cost
     estimates of the rows attributed to the PR, its branch or its issue.
     When there is no usage record, the column reads `not recorded` and the
     table still carries the count of merged PRs per surface and model, so
     the denominator exists the day cost lands.
   - **Events.** Re-routes are the adapter's R3 comments: every issue
     comment in the window (`repos/<o>/<r>/issues/comments?since=<window
     start>`, paginated) whose body starts `state: new — R3:`. Gaps are
     issues created in the window whose title starts `Gap:` (`gh issue list
     --state all --search "Gap: in:title created:>=<date>"`). Breaks are
     issues created in the window carrying a `source:cell:` label whose
     body reports a contract break: the design's "request back along the
     edge", an issue saying that behaviour this cell already promised (a
     Behavior statement the requester consumes, the requester's example
     that became that statement's test) stopped holding. Read each
     `source:cell:` issue's body; the words `contract break`, `broke`, `no
     longer`, or a quoted statement this cell's spec already carries decide
     it, and the report lists each break with the line that decided it, so
     a keyword alone never counts.

3. **Compute the report.** One markdown table each, always all of them,
   even when a table has a single row or every cell is `none`; an empty
   window produces a report whose every count is zero and no PR. Read the
   band boundary once:
   ```bash
   cellq threshold task.max_diff_lines
   ```
   The size bands are: `small`, diff lines below half of that value;
   `medium`, from half up to and including it; `large`, above it. Each
   table carries the row count it averages over, so a mean of one PR is
   read as such.

   ```markdown
   ## Retro report — <date>

   Window: merged after <previous retro close time> (#<m>) | whole repository.
   Merged PRs: <n>. Surface rule: run id = Actions; user@host = local; session id = cloud with the cloud marker, else local.

   ### Review rounds and rework by PR size band
   | Band (task.max_diff_lines) | PRs | Mean rounds | Mean rework commits | PRs with rework |
   |---|---|---|---|---|
   | small (below half) | | | | |
   | medium (half to the limit) | | | | |
   | large (above the limit) | | | | |

   ### Review rounds and rework by route
   | Route | PRs | Mean rounds | Mean rework commits | PRs with rework |
   |---|---|---|---|---|
   | small | | | | |
   | spec | | | | |
   | none | | | | |

   ### Review rounds and rework by source
   | Source | PRs | Mean rounds | Mean rework commits | PRs with rework |
   |---|---|---|---|---|
   | own | | | | |
   | ceremony | | | | |
   | agent | | | | |
   | cell:<name> (one row per cell) | | | | |
   | none | | | | |

   ### Cost per merged PR by surface and model
   | Surface | Model | PRs | Cost (sum) | Cost per PR |
   |---|---|---|---|---|
   | local \| cloud \| Actions \| unknown | <model> \| not named | | <sum> \| not recorded | |

   ### Gate load
   | Measure | Value |
   |---|---|
   | Merged PRs | |
   | Review runs | |
   | Review runs per merged PR | |
   | PRs the gate skipped (`proposal`) | |
   | PRs that reached `review.max_rounds` | |
   | PRs merged with `needs-human` | |

   ### Re-routes, gaps and breaks
   | Count | Value | Items |
   |---|---|---|
   | Re-routes (R3 comments) | | <issue#comment URLs> |
   | Gaps (`Gap:` issues) | | <issue numbers> |
   | Breaks (`source:cell:` contract breaks) | | <issue numbers, with the deciding line> |
   ```

   `PRs that reached review.max_rounds` compares each PR's rounds with
   `cellq threshold review.max_rounds`. Under the tables, one line per
   merged PR with the row it fed (number, band, route, source, runs,
   rounds, rework, surface, model), so every cell of every table can be
   checked against the PR it came from.

4. **Decide the threshold changes.** Read every key of `thresholds.yml`
   (the file, not memory) and, for each, the rows of the report that are
   evidence about it. A key is changed only when a row compares two sides
   of what the key bounds and the side the current value permits is the
   worse one, and then by one step at a time; never on a hunch, never two
   keys from one row, and never a key the report has no row for. The
   evidence each key can have:

   | Key | Evidence row | Direction |
   |---|---|---|
   | `task.max_diff_lines`, `task.max_files` | size band table | lower when `medium` has more rounds or rework per PR than `small` by a margin the PR counts support; raise when `large` PRs merged with no more rounds or rework than `medium` and no re-route named the limit |
   | `route.spec_if.files_over`, `route.spec_if.sessions_over` | route table and the re-route items | lower when `small`-route PRs re-routed through R3 for files or a second session, or needed more rounds than `spec`-route PRs; raise when `spec`-route work of few files merged in one round |
   | `review.max_rounds` | gate load | raise when PRs reached the limit and merged with `needs-human` after a fix James made by hand; lower when every PR merged under it with rounds to spare |
   | `edges.<cell>`, `edges.default` | source table and the breaks row | lower a cell's weight when its requests cost more rounds or rework per PR than `own` or caused breaks; raise it when its requests merged as cleanly as `own` |
   | `spec.max_unfolded_deltas`, `claim.stale_after_hours`, `ceremonies.<name>.every_merges` | none in this report | never changed by the retro; grooming's and health's reports are their evidence, and a change to them is an issue for James, not a retro proposal |

   A step is the smallest move that puts the value on the other side of
   the evidence: for a size key, the largest or smallest diff that merged
   cleanly in the row cited, rounded as the current value is written; for
   a count key, one; for a weight, the same move as the difference between
   `edges.self` and `edges.default` divides into. Write, for each changed
   key, one sentence citing the table and row (`task.max_diff_lines: the
   size-band table's medium row shows more rounds per PR than the small
   row over <n> PRs`). A key with evidence pointing both ways, or with a
   row of one PR, is left alone and the report says so under "Considered".

5. **One PR touching only `thresholds.yml`, or the report on the issue.**
   - **Changes proposed.** On a branch from the default branch (`git fetch
     origin`, `git switch -c retro/thresholds-<date> origin/<default>`),
     edit `thresholds.yml` and nothing else; `git diff --stat
     origin/<default>` must list that one file, or revert everything
     else. Commit as `chore(thresholds): retro <date>`, with a body saying
     why: the ceremony issue and the one sentence per key from step 4.
     Push the branch (never the default branch) and open the PR with the
     `proposal` label at creation, as `/ship` step 8 describes for each
     surface (with `gh`: `--label proposal`, creating the label first if
     the repo lacks it; without `gh`, the MCP draft route or the REST
     label-in-the-next-call route). A threshold change asks James's
     opinion, so it does not run the `/ship` gate; this step is the whole
     exit:
     ```bash
     gh pr create --title "chore(thresholds): retro <date>" --base <default> \
       --label proposal --body-file <file>
     ```
     The body, written to a file first, holds: one line naming the
     ceremony issue; the whole report from step 3, tables and per-PR
     lines; `## Changes`, one sentence per changed key citing its table
     and row, and `## Considered`, the keys with evidence that did not
     justify a move; a `## Spec changes` section reading `none` (the file
     is not a spec). No `Closes` line: the ceremony issue is closed by the
     adapter below, not by the merge. Then post one comment on the
     ceremony issue naming the PR, so the issue thread leads to the
     report:
     ```bash
     gh issue comment <ceremony issue> --body "Retro report and threshold proposal: <PR URL>"
     ```
   - **No change justified.** Open no PR and no branch. Post the whole
     report from step 3 as a comment on the ceremony issue (a comment is
     not state: `gh issue comment <n> --body-file <report>`, or `POST
     repos/<o>/<r>/issues/<n>/comments` through the REST API when `gh` is
     absent), ending with the keys considered and the line, on its own:
     ```
     No threshold change proposed.
     ```

6. **Close.** Through the adapter, last:
   ```bash
   cellq complete <ceremony issue>
   ```
   Report the ceremony issue URL, the window, the merged-PR count, and the
   PR URL or "No threshold change proposed." in the reply.
