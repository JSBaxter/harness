---
name: converge
description: "Check a parent issue's delta against main after its last sub-issue closes; fold it into the spec by proposal PR (behaviour into Behavior with its test; documentation, process and convention elsewhere), or open a gap issue. Never edits code."
---

# Converge

When every task cut from a spec delta has closed, check the delta's
acceptance criteria against what actually merged. All pass: fold the delta
into the spec as a proposal PR that closes the parent: what the software
does goes into Behavior, each statement naming a real, re-runnable test;
what is documentation, process or convention goes into Constraints,
Non-goals, the README or an ADR, with no test. Any fail: open a gap
issue under the parent and leave the spec alone. A
behaviour criterion with no test is a fail: a command or a file and line
is evidence of a check, not a test. This skill reads code and runs tests;
it never changes code, tests or workflows.

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
   every line under the delta's `Acceptance criteria`, and after them
   each claim about what the software does that no criterion covers: in
   **What changes** for a delta entry, in the written `## Behavior` for a
   new spec (nothing enters or stays in Behavior without a test, step 3,
   so such a claim is checked for one here). Cut each claim whole, as the
   delta's own sentence or list item, so a later run cuts it the same and
   step 4's title search finds its gap. The criteria are what the delta
   promised, the uncovered claims are what it described, and the
   fold-or-gap decision below turns on all of them. For each, decide pass
   or fail and keep the evidence: for a behaviour criterion or claim, a
   test name and its result; for a criterion about documentation, process
   or convention, the file and line that shows it, or, when it says
   something is absent, the search that found nothing. Write one line per
   criterion or claim, exactly in this form, with the criterion quoted
   word for word as the delta states it (the gap title in step 4 is
   matched on it):
   ```
   PASS <criterion> — <evidence>
   FAIL <criterion> — <evidence>
   ```
   For example, for a delta whose criteria read "`cellq threshold
   task.max_files` prints the value from `thresholds.yml`" and "`cellq
   threshold no.such.key` exits non-zero and stderr names `no.such.key`":
   ```
   PASS `cellq threshold task.max_files` prints the value from `thresholds.yml` — test_threshold_reads_scalar passed (pytest, exit 0)
   FAIL `cellq threshold no.such.key` exits non-zero and stderr names `no.such.key` — no test asserts it (`grep -rn 'no.such.key' tests/` returned nothing); `cellq threshold no.such.key` printed `null` and exited 0, stderr empty
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
   - A behaviour criterion (something runs, returns, exits, refuses,
     writes, shows) passes only on the result of a real, re-runnable test:
     a test function or case the cell's test runner runs, or, for UI
     appearance, a screenshot comparison. A command's output or a file and
     line is evidence of a check, not a test: it may follow the test's
     result on a `PASS` line and it belongs on a `FAIL` line, but it never
     makes a `PASS` on its own. Find the test by its name, or by grepping
     the test directory for the identifiers the criterion uses, and run it
     on its own through the runner. A behaviour criterion with no test
     that asserts it is a `FAIL` whose evidence begins `no test asserts
     it` and quotes the search that found nothing (`grep -rn '<name>'
     tests/` returned nothing), then what a command showed if you ran one;
     the gap it opens (step 4) is read as a request for the test. Writing
     the missing test is a fix, and fixes are not this skill's work (step
     5). An uncovered claim is evaluated the same way: its test is the
     one the search finds, and when none asserts it, its gap is closed by
     a test, or by editing the delta to drop the claim or move it out of
     What changes (or out of a new spec's Behavior).
   - A criterion about documentation, process or convention (a file says,
     contains or names something; a step a person takes by hand; a name
     or layout that holds) passes on the file and line that shows it, or,
     for one that says something is absent, on the search that found
     nothing (`grep -rn '<value>' plugins/` returned nothing). No
     test is asked of it, because a test that only asserts a document
     changed is not wanted; and what it describes is not a Behavior
     statement, so step 3 folds it outside Behavior.
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
   the worktree from step 2), edit the spec file, and the README or
   `docs/adr/` only for what the documentation, process or convention
   bullet below routes there, and nothing else:
   - Sort the delta's **What changes** content into statements and route
     each by what it is about:
     - **What the software does** (something runs, returns, exits,
       refuses, writes, shows) goes into `## Behavior`, under the heading
       of the area it belongs to (add a heading only when none fits). Cut
       one statement per behaviour criterion, worded from What changes,
       and end it by naming the test that criterion's evidence line named:
       ```markdown
       - <the statement> — test: <test name>
       ```
       The thing after `test:` is a test name and nothing else: a test
       function or case the runner re-runs, or a screenshot comparison
       for UI appearance; never a command and never a file and line.
       Behaviour content that no criterion covers has its test from its
       own evidence line in step 2 (a fold happens only when every line
       passed, so each has one): name it the same way. A statement
       without a test never enters Behavior.
     - **Documentation, process or convention** (what a document says, a
       step a person takes by hand, how a thing is named or laid out)
       never enters Behavior and gets no `— test:` line. Fold it where it
       belongs: a rule the cell holds to into the spec's `## Constraints`;
       something the cell will not do into `## Non-goals`; what a reader
       of the repository needs into the README; a decision worth
       remembering into an ADR under `docs/adr/`, in the `adr` skill's
       form, filed `accepted` because a merged `proposal` PR is the
       acceptance (that skill's step 5 exception), and linked from the
       spec's `## Decisions`; take nothing else from that skill. The PR
       body lists each
       such item and where it went under `## Outside Behavior`.
   - For a new spec, Behavior is already written: add the `— test:` ending
     to each statement a criterion covers, and to each behaviour
     statement no criterion covers the test its step 2 line names; route
     a statement that is documentation, process or convention out of
     Behavior as above. Then change `Status: draft` to
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
   - Do not touch `## Acceptance criteria`. `git status` must show only
     the spec file and, for items routed out of Behavior, `README.md` or
     files under `docs/adr/`; if it shows anything else, revert that file
     before committing.

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
     removed`, which is also the line for a statement a new-spec fold
     routed out of Behavior; a new-spec fold lists each statement it
     gave a test);
   - `## Outside Behavior`, listing each What-changes item (or new-spec
     Behavior statement) that did not stay a Behavior statement and where
     it went (`Constraints`, `Non-goals`, `README.md`, `docs/adr/<file>`),
     or omitted when there is none;
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
   Gap found by converge on #<n> (parent). The criterion (or uncovered
   claim) in the title
   failed against origin/<default> at <short sha>; the delta `<delta name>`
   in `specs/<area>.md` stays in Pending changes until this closes.

   ## Evidence
   PASS <criterion> — <evidence>
   FAIL <criterion> — <evidence>

   ## Audit
   <the three questions from step 6>
   ```
   When the criterion failed for want of a test, say so under
   `## Suggested fix` (step 5): which test to write and where, so the gap
   reads as a request for a test, not for a code change; for an uncovered
   claim, also that editing the delta to drop or move the claim closes
   it.
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

5. **Only documents change.** Whatever the evidence suggests, this skill
   edits no code, no test and no workflow, and opens no PR but the fold.
   If a fix looks obvious while reading, put it in the gap issue body
   under `## Suggested fix`, as prose for the implementing agent, and move
   on. A fold's diff is the spec and, for items step 3 routes out of
   Behavior, `README.md` or `docs/adr/`; a fold PR whose diff touches
   anything else is wrong even if every criterion passed.

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
