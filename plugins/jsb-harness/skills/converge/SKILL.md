---
name: converge
description: "Check a parent issue's delta against main after its last sub-issue closes; fold it into Behavior by proposal PR, or open a gap issue. Never edits code."
---

# Converge

When every task cut from a spec delta has closed, check the delta's
acceptance criteria against what actually merged. All pass: fold the delta
into the spec's Behavior as a proposal PR that closes the parent. Any fail:
open a gap issue under the parent and leave the spec alone. This skill
reads code and runs tests; it never changes a file outside `specs/`.

Argument: the parent issue number (the cell-converge workflow prompt is
`Run /converge on issue #<n>`; a person or the grooming ceremony may also
start it by name).

`cellq` is the queue adapter (`plugins/jsb-harness/bin/cellq`; in a cloud
session without the plugin, `../harness/plugins/jsb-harness/bin/cellq`;
contract in the harness's `specs/cellq.md`). Every issue it creates, links or
moves goes through the adapter; this skill carries no numbers. Never set a
label, state or body with raw `gh`, a project board, or an MCP issue-write
tool. Reading is free: `gh issue view <n> --json number,title,body,labels,
state,url` (or the REST endpoint `repos/<o>/<r>/issues/<n>` when `gh` is
absent).

## Steps

1. **Gate on the parent, then find the delta.**
   ```bash
   cellq parent <n>
   ```
   The output is `{parent, sub_issues: [{number, closed}], all_closed}`.
   If `all_closed` is not `true`, stop and report which sub-issues are
   still open; touch nothing, because this is simply not the moment (the
   trigger fired early, or someone ran the skill by hand). If `sub_issues`
   is empty, stop and say so: nothing was split from this parent, so
   nothing has been built to check, whatever `all_closed` says. A non-zero
   exit is an environment or usage failure: report the stderr line and
   stop. If the parent itself is closed, stop and say so: it has already
   been folded or dropped. Then look for a fold PR that is already open
   for it (`gh pr list --state open --search "Closes #<n> in:body" --json
   number,url,headRefName`, or the REST search endpoint with the same
   query): if one exists, stop and report its URL, touching nothing, so
   that a task James reopened and re-closed, or a hand run, never opens a
   second PR. If the parent is `state:in-review` and no fold PR is open,
   James closed the last one without merging: read that PR's comments
   before going on, and if they say the fold itself was wrong, stop and
   record it (`cellq state <n> blocked --reason "converge: fold PR #<pr>
   closed: <his reason>; the delta in specs/<area>.md needs editing"`);
   otherwise carry on and fold again from the current default branch.

   Then find the delta. Read the parent (its definition of done names the
   spec: "The spec is written to `specs/<area>.md`") and search every spec
   for what links `#<n>` under `## Pending changes`. It has one of two
   shapes:
   - **A delta entry**: a `### ` heading under `## Pending changes` whose
     `Linked issue` field is `#<n>`. Its acceptance criteria are the
     entry's `Acceptance criteria` field, and its name is the heading
     without the date.
   - **A new spec**: `## Pending changes` has no `### ` entry (it says the
     spec is new) and carries a bare `Linked issue: #<n>` line. The whole
     spec is the delta: its criteria are the top-level `## Acceptance
     criteria`, its name is the spec's title, and its Behavior is already
     written.
   ```bash
   grep -lE 'Linked issues?\*?\*?:.*#<n>([^0-9]|$)' specs/*.md
   awk -v n='<n>' '
     /^## /        { if (hit) print name body; pc = ($0 == "## Pending changes"); name = ""; hit = 0 }
     pc && /^### / { if (hit) print name body; name = $0; body = ""; hit = 0; next }
     pc && name    { body = body "\n" $0;
                     if ($0 ~ "^(- )?(#+ |\\*\\*)?Linked issues?.*#" n "([^0-9]|$)") hit = 1 }
     END           { if (hit) print name body }' specs/<area>.md
   sed -n '/^## Pending changes/,/^## /p' specs/<area>.md | grep -E '^(- )?Linked issues?:.*#<n>([^0-9]|$)'
   ```
   The `grep -l` only names candidate files. In each, the awk decides: it
   prints every delta entry that links `#<n>`, in order, and when it
   prints anything those entries are the delta. Only when it prints
   nothing is the `sed | grep` consulted, and a line it finds means the
   new-spec shape (that grep also matches a field inside an entry, which
   is why it is not consulted first). If more than one entry links `#<n>`
   (a spec PR carried several deltas; the spec's open question on this
   defaults to one run per parent), treat their criteria as one list:
   everything below folds all of them in one PR when every criterion
   passes, and folds none when any fails.

   If nothing in any spec links `#<n>`, or the delta has no acceptance
   criteria, the spec is not foldable as written: record that on the
   parent through the adapter and stop, so the issue says why nothing
   happened and James or the grooming ceremony can see what to fix:
   ```bash
   cellq state <n> blocked --reason "converge: no delta in specs/ links #<n>"
   cellq state <n> blocked --reason "converge: delta <name> in specs/<area>.md has no Acceptance criteria"
   ```

2. **Evaluate each criterion on a fresh checkout of the default branch.**
   Evidence must come from merged code, not from the branch this session
   happens to be on. Fetch, then put the default branch in its own
   worktree and work there:
   ```bash
   git fetch origin
   git worktree add --detach <dir> origin/<default>
   ```
   (In an Actions run the checkout may already be the default branch:
   fetch, and if `git rev-parse HEAD` equals `git rev-parse
   origin/<default>` work in place; if not, add the worktree as above.)
   Read CLAUDE.md there for the test command. The list to evaluate is
   every line under the delta's `Acceptance criteria`, and nothing else:
   the criteria are what the delta promised and what the fold-or-gap
   decision below turns on. For each, decide pass or fail and keep the
   evidence: a test name and its result, a command and its output, or a
   file and line. Write one line per criterion, exactly in this form, with
   the criterion quoted word for word as the delta states it (the gap
   title in step 4 is matched on it):
   ```
   PASS <criterion> — <evidence>
   FAIL <criterion> — <evidence>
   ```
   For example, for a delta whose criteria read "`cellq threshold
   task.max_files` prints the value from `thresholds.yml`" and "`cellq
   threshold no.such.key` exits non-zero and stderr names `no.such.key`":
   ```
   PASS `cellq threshold task.max_files` prints the value from `thresholds.yml` — test_threshold_reads_scalar passed (pytest, exit 0)
   FAIL `cellq threshold no.such.key` exits non-zero and stderr names `no.such.key` — `cellq threshold no.such.key` printed `null` and exited 0; stderr empty
   ```
   Rules:
   - Every criterion gets a line; none is skipped, deferred or marked
     partial. A criterion stated against a fixture (a cell rendered from
     the project template, a temporary thresholds file) is exercised by
     building that fixture in the worktree; building it is part of the
     check, not a reason to fail it. One that needs a live issue is
     exercised against a scratch repository kept for that purpose, never
     against the cell's own queue, where an issue filed with `cellq idea`
     enters intake. A criterion you cannot exercise is one whose check
     needs a credential, network or surface this session has no way to
     obtain, or a command that does not exist; it is a `FAIL` whose
     evidence begins `environmental:` and says exactly what could not be
     run and why, so that the gap it opens (step 4) is read as a request
     for the resource, not for a code change.
   - The kind of evidence follows the kind of criterion. A criterion about
     behaviour (something runs, returns, exits, refuses) passes only on a
     test's result or a command's output; one about content (a file says,
     contains, names something) passes on the file and line that shows it.
     A behaviour criterion with no test that asserts it and no command
     that exercises it is a `FAIL` with the search that found nothing as
     evidence (`grep -rn '<name>' tests/` returned nothing). Writing the
     missing test is a fix, and fixes are not this skill's work (step 5).
   - Quote real output. Never report a run you did not do, and never run a
     test command from another repository because CLAUDE.md names a
     placeholder; say that the placeholder is there, and let that
     criterion fail if a test was what it needed.
   - The evidence lines are the same text in the PR body (step 3), the gap
     issue (step 4) and the session's reply.

3. **All pass: fold the delta, as a proposal PR.** On a branch from the
   default branch, named for the parent and the commit the evidence came
   from so that a later run never collides with it
   (`git switch -c converge/fold-<n>-<short sha> origin/<default>`, in
   the worktree from step 2), edit the spec file and nothing else:
   - Move all of the delta's **What changes** content into `## Behavior`,
     as statements, under the heading of the area each one belongs to
     (add a heading only when none fits). Cut one statement per
     acceptance criterion, worded from What changes, and end it by naming
     what that criterion's evidence line named:
     ```markdown
     - <the statement> — test: <test name>
     ```
     The thing after `test:` is what the next reader re-runs or re-reads
     to check the statement: the test name; the command, when the evidence
     was a command (`— test: cellq threshold no.such.key exits non-zero`);
     or the file and line, when the criterion was about content
     (`— test: README.md:12`). What-changes content that no criterion
     covers still moves, as its own statement with no `— test:` ending
     (a statement names its test once one exists), and the PR body lists
     each such statement under `## Untested`, so James sees what the
     delta described but never promised to check; the health ceremony
     reports it until a test exists.
   - For a new spec, Behavior is already written: add the `— test:` ending
     to each statement a criterion covers, change `Status: draft` to
     `Status: active`, leave the top-level `## Acceptance criteria` where
     it is, and replace the whole `## Pending changes` body (the "this
     spec is new" text and the bare `Linked issue:` line) with `None.`
   - Delete from `## Behavior` any statement **What is removed** names.
     **What stays** describes statements that are already there; leave
     them as they are.
   - Move any **Non-goals**, **Constraints** or **Open questions** of the
     delta that still hold after the fold into the spec's sections of the
     same name; the rest leave with the delta.
   - Delete the whole `### ` entry from `## Pending changes`. When no entry
     remains, the section reads `None.`
   - Do not touch `## Acceptance criteria` or any other file. `git status`
     must show only files under `specs/`; if it shows anything else, revert
     that file before committing.

   Commit as `docs(spec): fold <delta name>`, with a body saying why: the
   parent, and that every criterion passed on the default branch at the
   commit you checked (`git rev-parse --short origin/<default>`). Push the
   branch (never the default branch) and open the PR with the `proposal`
   label at creation, as `/ship` step 8 describes for each surface (with
   `gh`: `--label proposal`, creating the label first with `gh label
   create proposal -c "c5def7" -d "opinion/spec/mockup PR — human review
   only, skip agent gate" --force` if the repo lacks it; without `gh`, the
   MCP draft route or the REST label-in-the-next-call route from that
   step). A fold asks James's opinion of the spec, so it does not run the
   `/ship` gate; this step is the whole exit:
   ```bash
   gh pr create --title "docs(spec): fold <delta name>" --base <default> \
     --label proposal --body-file <file>
   ```
   The body, written to a file first, holds:
   - one line saying which delta folds and which parent it closes;
   - the evidence lines from step 2, verbatim, under `## Evidence`;
   - a `## Spec changes` section in `/ship` step 9's form, one line per
     statement the diff adds to, changes in, or removes from Behavior
     (`<spec file>: "<statement>" — test: <test name>`, or `— test:
     removed`; a new-spec fold lists each statement it gave a test);
   - `## Untested`, listing any statement folded without a test, or
     omitted when there is none;
   - `Closes #<n>`, so the merge closes the parent.
   Open no other PR and no issue. Then move the parent to in-review through
   the adapter, so the queue shows a PR exists for it and the grooming
   ceremony does not run converge on it again:
   ```bash
   cellq state <n> in-review
   ```
   If James closes the fold PR without merging, the parent stays in
   in-review with no PR; grooming's scan for a parent whose sub-issues
   are all closed and no fold PR is open brings it back to step 1, which
   reads his reason before folding again on a fresh branch.

4. **Any fail: open a gap issue, change nothing else.** No branch, no
   commit, no PR; the delta stays in Pending changes and the parent keeps
   its state. For each failing criterion, write a body file that names the
   parent and carries every evidence line from step 2, passes included, in
   this form:
   ```markdown
   Gap found by converge on #<n> (parent). The criterion in the title
   failed against origin/<default> at <short sha>; the delta `<delta name>`
   in `specs/<area>.md` stays in Pending changes until this closes.

   ## Evidence
   PASS <criterion> — <evidence>
   FAIL <criterion> — <evidence>

   ## Audit
   <the three questions from step 6>
   ```
   Before filing, look for an earlier gap with the same title: `gh issue
   list --state all --search "<words> in:title" --json
   number,title,state,labels`, where `<words>` are the criterion's words
   with no `Gap:` prefix, backticks, quotes or colons (a colon makes a
   search qualifier), and then compare the returned titles with
   `Gap: <criterion>` exactly; without `gh`, `GET search/issues?q=repo:
   <o>/<r>+<words>+in:title`. If the search cannot run at all, file
   anyway: a duplicate costs James a close, a lost gap costs a release.
   One that is open already is this gap: link it if it is not yet a
   sub-issue and file nothing new. One that is closed (`state:done` with
   the criterion still failing, or `state:dropped`, which the grooming
   ceremony also sets on a stale issue) is refiled, with a line in the new
   body naming the earlier one and how to end the loop if the criterion
   itself is wrong:
   "Refiles #<old>, closed as <state>. If this criterion should not hold,
   the fix is to edit the delta in `specs/<area>.md`; closing this issue
   again will file it again." Then file it and make it a sub-issue of the
   parent:
   ```bash
   cellq idea "Gap: <criterion>" --body <file> --source agent
   cellq link <n> <gap>
   ```
   `<gap>` is the `number` in the `idea` output. The link is what makes the
   loop close: `cellq parent <n>` now reports the parent not all closed,
   `scope` routes the gap like any new issue, and when the gap closes the
   converge trigger fires on the parent again and the criteria are
   re-evaluated from step 1. Do not write a `Parent: #<n>` line in the body
   yourself; that line is the adapter's fallback and `link` writes it when
   it must.

5. **Only `specs/` changes.** Whatever the evidence suggests, this skill
   edits no code, no test and no workflow, and opens no PR but the fold.
   If a fix looks obvious while reading, put it in the gap issue body
   under `## Suggested fix`, as prose for the implementing agent, and move
   on. A fold PR whose diff touches anything outside `specs/` is wrong
   even if every criterion passed.

6. **The short audit form.** Spec open question three defaults to a
   comment thread, so the questions live where James will already be
   reading. Write three questions about the capability at the functional
   level: what it does, for whom, and what should happen at an edge the
   criteria do not cover. Each is answerable in a sentence from the folded
   Behavior statements and the evidence, and none asks about approach,
   pattern or implementation (those are the full ceremony's later rounds).
   For example, after folding a threshold-reading delta: "Should a cell
   with no `thresholds.yml` refuse to scope, or scope with defaults?";
   "Who besides the skills reads these values?"; "When the retro changes a
   value, from which merge does it apply?"
   - On a fold PR: post them as one comment, headed `## Audit`:
     ```bash
     gh pr comment <pr> --body-file <file>
     ```
     Without `gh`, the same comment goes through the REST endpoint
     `POST repos/<o>/<r>/issues/<pr>/comments` (a PR is an issue there), or
     the GitHub MCP comment tool. A PR comment is not issue state, so no
     adapter verb is needed.
   - On a gap issue: they are already in the body under `## Audit` (step
     4), written through the adapter at creation, which keeps the adapter
     the issue's only writer; the thread under the issue is where James
     answers.

7. **Report**: the evidence lines; then the fold PR URL and the parent's
   new state, or each gap issue URL with the criterion it names. Say which
   commit of the default branch the evidence came from.
