---
name: ceremony-health
description: Health check. Runs from a ceremony issue the cell-ceremony workflow files and ends in PRs James merges, issues, or a report, never a direct change to the default branch. Reads every active or draft spec's Behavior against the code and the test suite, classifies each statement as met, unmet or dead (or, when it is not about what the software does, as one to move out of Behavior), folds shipped behaviour still sitting in Pending changes, proposes deletions for behaviour that no longer exists, files an issue per unmet statement, and posts the self-description report. Invoked by name from the ceremony issue; never self-selected.
---

# Ceremony: health

Ask of every spec the cell carries: is each statement in Behavior still
true, and can the cell prove it? A statement is proved by its test passing
on the default branch, with no open gap issue against it and the gate green.
Statements the cell can no longer prove become issues; statements about
behaviour that is gone become a proposal to delete them; behaviour that
shipped but was never folded into Behavior is folded. Only statements about
what the software does are counted: one that is documentation, process or
convention does not belong in Behavior, so it is proposed for moving out,
not counted as met or unmet. The whole thing ends
in a self-description report: the features the cell offers and whether its
requirements are met. Everything the ceremony does is an adapter call, a
proposal PR, an issue, or a report; it never pushes to the default branch
and never merges.

Argument: the ceremony issue number (the workflow prompt is `Run
/ceremony-health on issue #<n>`). The issue carries `source:ceremony` and is
already `state:ready`; it is the place the report goes and the thing this
skill closes last.

`cellq` is the queue adapter (`plugins/jsb-harness/bin/cellq`; in a cloud
session without the plugin, `../harness/plugins/jsb-harness/bin/cellq`;
contract in the harness's `specs/cellq.md`). Every issue this skill opens
and every state it sets goes through it, and every threshold is read
through it from the cell's `thresholds.yml`; this skill carries no numbers.
Never set a label, state, body or priority with raw `gh`, a project board,
or a GitHub MCP write tool; the adapter is the only writer. Reading is
free: `gh issue view <n> --json ...`, `gh pr list`, `git log`, or the REST
endpoints under `repos/<o>/<r>/` when `gh` is absent. If a `cellq
threshold` read fails, stop and report its stderr line; never substitute a
value from memory or from another repository.

Record, as you go, one line per statement (spec, statement, class,
evidence) and one per action taken (PR, issue, what and why); step 7 turns
those lines into the report.

## Steps

1. **Open the ceremony issue and the specs.** Read the ceremony issue
   (`gh issue view <n> --json title,labels,state`): it must be open, carry
   `source:ceremony`, and its title must name health; otherwise stop and
   report what it is. Then list the specs in scope: every `specs/*.md`
   that is not a `*.plan.md` and whose `Status:` line reads `active` or
   `draft`. A spec marked `superseded by <file>` is out of scope and
   appears in the report only as a line saying so. For each spec in scope,
   keep its title, its `Purpose` paragraph (the first paragraph under `##
   Purpose`; the report quotes its first sentence) and its statements. A
   statement is each list item, bulleted or numbered, in the `## Behavior`
   section, that is, from that heading to the next `## ` heading, its
   `### ` sub-headings included, and each row of a table there whose cells
   state a rule (a key and what it does, a verb and its effect); a
   paragraph of prose is context, not a statement. A statement is a
   Behavior statement only when it is about what the software does
   (something runs, returns, exits, refuses, writes, shows). A list item
   in `## Behavior` that is documentation, process or convention (what a
   document says, a step a person takes by hand, how a thing is named or
   laid out) is not one: record it as `MOVE` (step 3), run nothing for
   it, and leave it out of every count. A statement names its test when
   it ends `— test: <name>` (the `spec` skill's form) and the name is a
   test: a test function or case the runner re-runs, or a screenshot
   comparison for UI appearance, as `converge` step 3 writes them. A
   command or a file and line after `— test:` is not a test name:
   treat such a statement as unnamed in step 2, so its test is searched
   for and, when found, named by step 5.

   Evidence must come from merged code, not from the branch this session
   happens to be on. Fetch, put the default branch in its own worktree
   (`git fetch origin`, `git worktree add --detach <dir> origin/<default>`;
   in an Actions run the checkout is usually the default branch already:
   when `git rev-parse HEAD` equals `git rev-parse origin/<default>` work
   in place, otherwise add the worktree as above) and read CLAUDE.md
   there for the test command. Every test and command below runs
   in that worktree, and the report names the commit it checked (`git
   rev-parse --short origin/<default>`).

2. **Find and run each statement's test.** For every statement:
   - **Named test.** Find the test by its name: a test function or case by
     grep across the test directory CLAUDE.md's test command points at
     (`grep -rn '<name>' tests/`, or the directory the command names), or
     a screenshot comparison by the test that runs it. Run the named
     test on its own through the cell's test runner (`pytest -k <name>`,
     `python3 -m unittest <module>.<Class>.<name>`, `bash <script>` for a
     shell test, as the test command indicates), and keep the runner's
     output line and exit code. When the named test is not found (deleted
     or renamed), also run the search below: a test that asserts the
     statement under another name is what step 5 fixes by a reference
     rather than an issue.
   - **Unnamed statement, or named test not found.** Search the test suite
     for the test that asserts it: the identifiers the statement uses (a
     function, a flag, a verb, an exact string it quotes) grepped across
     the tests. When one test clearly asserts the statement (its
     assertions check the behaviour the statement describes, not merely
     mention the name), or a compound statement is asserted clause by
     clause by a few tests that together cover all of it, those are its
     tests: run each as above and keep their names, so step 5 can write
     them after `— test:`. When no test asserts it, or the tests found
     cover only part of it, the statement has no test, and the evidence
     says which clause is uncovered.
   - **Not a Behavior statement** (documentation, process or convention,
     step 1): look for no test and run nothing, because a test that only
     asserts a document changed is not wanted; step 3 records it `MOVE`.

   Quote real output. Never report a run you did not do, and never run a
   test command from another repository because CLAUDE.md names a
   placeholder; a placeholder test command means every behaviour statement
   has no runnable test, and the report says so once at the top.

3. **Classify each statement.** Four records, decided in this order:
   - **Move out of Behavior**: the statement is not about what the
     software does (step 1). It is neither met nor unmet and is not
     counted; step 5 moves it by proposal PR. The evidence is where it
     belongs (`Constraints`, `Non-goals`, `README.md`, or an ADR) and why.
   - **Dead**: the behaviour no longer exists in code. The thing the
     statement describes (the function, the verb, the flag, the file, the
     endpoint) is absent from the default branch, and `git log -S'<name>'
     --oneline` or `git log --diff-filter=D -- <path>` shows the commit
     that removed it. A statement whose test and code are both gone is
     dead; a statement whose code remains is never dead, however its test
     fares. The evidence is the search that found nothing in the code plus
     the removing commit.
   - **Met**: all three hold: the test passed (step 2: the named test, or
     for an unnamed statement the test or tests found to assert it; a
     statement that names a test which no longer exists is not met even
     when another test asserts it, since its named test is missing); no
     open gap issue
     names it (`gh issue list --state open --search "Gap: in:title" --json
     number,title,body`, read each; a gap names the statement when its
     title or body quotes it or the criterion it was cut from); and the
     gate is green on the default branch. The gate stamps PR heads, not
     merge commits, so read it in one place: the `claude-review` status on
     the head commit of the most recently merged PR (`gh pr list --state
     merged --json headRefOid,mergedAt`, the newest `mergedAt`, then `gh
     api repos/<o>/<r>/commits/<sha>/statuses`, the newest entry with
     that context). Green is that status `success`; red is `failure` or
     `error`. Other workflows on the default branch are not the gate and
     do not count. A PR head with no `claude-review` status at all
     (merged before the gate existed, or the gate never ran) is green for
     this purpose and the report says so. Read the gate once, not per
     statement; it is the same answer for every statement.
   - **Unmet**: everything else: the test is missing (a named test that no
     file defines, or no test asserts an unnamed statement), failing, or
     deleted (`git log --diff-filter=D` finds the file, or `git log
     -S'<name>'` finds the commit that removed the function, with the code
     still present); or the test passes but an open gap issue names the
     statement or the gate is red. The evidence is the specific reason:
     the runner's failure line, the search that found no test, the
     deleting commit, the gap issue number, or the failing status; and,
     when step 2 found a test under another name, that test and its
     result.

   A draft spec whose linked issue (the parent in its `Linked issue:`
   line) is still open, or which has no such line but is named by an
   open issue (`gh issue list --state open --search "<spec path>"`, the
   path in the body, as `scope`'s blocker comment and a sub-spec's tasks
   write it), is being built: classify and report its statements
   like any other, so the self-description is honest, but mark the spec
   row `(draft, in progress: #<parent>)`, propose nothing for it in steps
   4 to 6, file no `Unmet:` issue for it in step 5 (its tasks are the
   work that will meet those statements, and an `Unmet:` issue would
   compete with them in `cellq ready`), and count its unmet statements
   separately in the verdict. Read the parent's state with `gh issue view
   <parent> --json state,stateReason,labels`.

   Keep one record line per statement, in this form, with the statement
   quoted word for word (the issue title in step 5 is cut from it):
   ```
   MET   <spec>: <statement> — <evidence>
   UNMET <spec>: <statement> — <evidence>
   DEAD  <spec>: <statement> — <evidence>
   MOVE  <spec>: <statement> — <destination>: <why it is not Behavior>
   ```

4. **Fold unfolded shipped behaviour.** For each spec in scope, read every
   `### ` entry under `## Pending changes` and its `Linked issue` (and a
   new spec's bare `Linked issue:` line, as `converge` step 1 describes the
   two shapes). For each linked issue:
   ```bash
   cellq parent <n>
   ```
   The delta is shipped but unfolded when the linked issue is closed as
   completed (`gh issue view <n> --json state,stateReason,labels`: closed
   with `stateReason` `COMPLETED`, whatever `state:` label it still
   carries, since a parent James closed by hand was never `cellq
   complete`d), its `sub_issues` is not empty and `all_closed` is true,
   and the delta is still in Pending changes. (Open parents are grooming's
   business, step 8 there; a parent closed as not planned, or labelled
   `state:dropped`, is an abandoned delta, listed in the report for James
   and left in place; a closed parent with no sub-issues was never split,
   so nothing was built to check: listed as "closed, never split".) Before folding, apply `converge`'s own guard as grooming
   step 8 does: a fold PR for this parent that is open, or merged, labelled
   `proposal` and naming the parent (`gh pr list --state open --label
   proposal --search "#<n>"`, then `--state merged`), or an open gap issue
   linked to it, means the delta is already in hand; list it as "fold PR
   #<p> pending" or "gap #<g> open" and fold nothing. Otherwise run
   `converge` steps 2 and 3 (the skill in
   `plugins/jsb-harness/skills/converge/SKILL.md`; from source in a cloud
   session) with two differences: the parent is already closed, so
   `converge` step 1's gate on it is replaced by the checks above, and
   from step 3 only the edits are taken (the spec, and the README or
   `docs/adr/` for items routed out of Behavior): the fold goes into this
   spec's proposal PR (step 6) rather than a PR of its own, so that one PR
   per spec carries everything health proposes for it, and `converge`'s
   closing `cellq state <n> in-review` is never run, because any state
   set on a closed issue reopens it (the adapter contract) and nothing
   would close it again.
   Evaluate every criterion exactly as `converge` step 2 says (one `PASS`
   or `FAIL` line each, real evidence, nothing partial). All pass: keep
   the fold edits from `converge` step 3 for the spec branch of step 6,
   with the evidence lines for the PR body. Any fail: open the gap issue
   exactly as `converge` step 4 does (`cellq idea "Gap: <criterion>"
   --source agent`, then `cellq link <parent> <gap>`), fold nothing from
   that delta, and list it in the report. When the gap closes,
   `cell-converge.yml` fires on the parent and `converge` step 1 stops
   because the parent is closed, so it is the next health run that
   re-checks the delta here. When the converge skill is not installed and
   cannot be read from source, do not improvise a fold; list the delta as
   "needs converge" and move on.

5. **Act on dead, unmet and moved statements.**
   - **Move out of Behavior**: as an edit kept for the spec branch of step
     6, delete the statement from Behavior, drop any `— test:` ending, and
     put its text where the record says: the spec's `## Constraints` (a
     rule the cell holds to), its `## Non-goals` (something the cell will
     not do), the README (what a reader of the repository needs), or a new
     ADR under `docs/adr/` in the `adr` skill's form (a decision worth
     remembering). No issue; the report lists it as moved, with the PR as
     its action.
   - **Dead**: as an edit kept for the spec branch of step 6, delete the
     statement from Behavior. When every statement of the spec is dead and another spec
     in `specs/` now describes the capability, instead change the spec's
     `Status:` line to `superseded by <that file>` and leave its text in
     place (the `spec` skill's form; a superseded spec is history, not a
     contract). When every statement is dead and no spec covers the
     capability, delete the statements and say in the PR body that
     Behavior is now empty and James should decide whether the spec goes.
   - **Unmet, test exists under another name** (the statement names a test
     that is missing, and step 2 found the test or tests that assert it,
     all passing): on the spec branch, replace the name after `— test:`
     with the names found; no issue for the missing name. The statement
     stays unmet in the report, with the PR as its action, until James
     merges the reference. An open gap or a red gate on top of that is a
     reason of its own, handled by the "Unmet, otherwise" bullet as well.
   - **Met but unnamed** (an unnamed statement whose tests step 2 found and
     ran): on the spec branch, append `— test: <names>` to the statement,
     replacing an ending that named a command or a file and line, so the
     next health run finds the tests by name; no issue, and the statement
     counts as met.
   - **Unmet, otherwise** (no test, a failing test, a deleted test with no
     test under another name, an open gap, or a red gate; a renamed test
     with a gap or a red gate gets the reference edit above and appears
     here only for the gap or the gate): one issue per statement, unless
     an issue with the same title already exists (`gh issue list --state
     all --search "Unmet: in:title" --json number,title,state`, compare
     titles word for word): an open one is this issue, file nothing; a
     closed one is refiled with a line in the new body naming it and the
     way out, as `converge` step 4 does: "Refiles #<old>, closed as
     <state>. If this statement should not hold, the fix is to edit or
     remove it in `specs/<spec>.md`; closing this issue again will file it
     again." Write a body file naming the spec and its line, the
     statement, the evidence line from step 3, the commit checked, and a
     `## Definition of done` section whose acceptance statement is that
     the statement has a test that asserts it, named after `— test:` in
     the spec, passing on the default branch (or, when the gap or gate was
     the reason, that the gap is closed or the gate green). Then open it
     and scope it, because the `scope` skill stops on `source:ceremony`
     and a ceremony scopes what it opens: route `small` (one test, one
     PR), priority as `scope` step 5 computes for a `source:ceremony`
     issue (the default hint it uses when the body has none, times `cellq
     threshold edges.default`, rounded halves up, clamped to the
     `priority:` range):
     ```bash
     cellq idea "Unmet: <statement>" --body <file> --source ceremony
     cellq scope <n> --dod <dod-file> --route small --priority <p>
     ```
     A statement too long for a title is cut at the first clause and the
     body carries it whole. When the gate itself is red, every statement
     is unmet for at least that reason; the statements whose only reason
     is the gate get one issue between them, titled `Unmet: gate red on
     <default>` (the sha and the status in the body, so the title dedupes
     across runs while the gate stays red), listing them in its body,
     while a statement
     with a reason of its own (a missing, failing or deleted test, an open
     gap) still gets its own issue, so the trace of that defect does not
     close with the gate.

6. **One proposal PR per spec.** For each spec with any fold (step 4),
   deletion, supersession or test reference (step 5), first look for a
   health PR already waiting on James: an open PR labelled `proposal`
   whose head branch starts `health/<spec-name>-` (`gh pr list --state
   open --label proposal --json number,headRefName,body`). When one
   exists, open no second PR: list it in the report as "PR #<p> pending
   James's merge", and when this run found changes its body does not
   carry, say which under that line, so the next run after the merge
   proposes them. Otherwise, one spec at a time: a branch from the default
   branch in the worktree of step 1 (`git switch -c
   health/<spec-name>-<date> origin/<default>`), the edits kept from
   steps 4 and 5 for this spec file (and, for a move or a fold's routed
   item, `README.md` or `docs/adr/`) and nothing else, commit, push, open
   the PR, and only then the next spec's branch, so no spec's edits sit
   uncommitted when another branch is cut. `git status` must show only
   that spec file and any README or ADR a move touched; if it shows
   anything else, revert it before committing. Commit as
   `docs(spec): health <spec-name> — fold, prune, name tests, move` (keep only
   the parts that apply), with a body saying why: the ceremony issue, the
   commit checked, and one line per change. Push the branch (never the
   default branch) and open the PR with the `proposal` label at creation,
   as `/ship` step 8 describes for each surface (with `gh`: `--label
   proposal`, creating the label first if the repo lacks it; without `gh`,
   the MCP draft route or the REST label-in-the-next-call route). A health
   PR asks James's opinion of the spec, so it does not run the `/ship`
   gate; this step is the whole exit:
   ```bash
   gh pr create --title "docs(spec): health <spec-name>" --base <default> \
     --label proposal --body-file <file>
   ```
   The body, written to a file first, holds: one line naming the ceremony
   issue and the commit checked; `## Folded` with each delta's name, its
   parent, and the `PASS` lines from step 4 verbatim; `## Removed` with
   each dead statement and its evidence; `## Test references` with each
   statement and the test now named; `## Moved out of Behavior` with each
   moved statement and where it went; `## Outside Behavior` as `converge`
   step 3 writes it, for a fold's routed items; a `## Spec changes`
   section in `/ship` step 9's form, one line per statement the diff adds
   to, changes in, or removes from Behavior (`<spec file>: "<statement>"
   — test: <name>`, or `— test: removed`, with `(moved to <where>)` after
   `removed` for a moved statement). A fold's parent is closed already, so
   no `Closes` line is needed; name the parent in `## Folded` instead.
   Open no PR for a spec with nothing to change.

7. **Report and close.** Post the self-description report as a comment on
   the ceremony issue (a comment is not state: `gh issue comment <n>
   --body-file <report>`, or `POST repos/<o>/<r>/issues/<n>/comments`
   through the REST API when `gh` is absent). The audit ceremony reads
   this comment as the cell's self-description, so its form is fixed:

   ```markdown
   ## Health report — <date>

   Checked: origin/<default> at <sha>. Gate: green | red (<status>).
   Test command: <command> | placeholder (no statement has a runnable test).

   ### Features
   | Spec | Purpose | Met | Unmet | Dead |
   |---|---|---|---|---|
   | <name> (<status> | draft, in progress: #<parent>) | <first sentence of Purpose> | <n> | <n> | <n> |

   ### Unmet statements
   | Spec | Statement | Evidence | Action |
   |---|---|---|---|
   | <name> | <statement> | <evidence> | #<issue> \| PR #<n> (test reference) \| in progress: #<parent> |

   ### Moved out of Behavior
   | Spec | Statement | Destination | Action |
   |---|---|---|---|
   | <name> | <statement> | Constraints \| Non-goals \| README.md \| docs/adr/<file> | PR #<n> |

   ### Proposals and gaps
   - PR #<n> <spec>: folded <delta>; removed <k> statements; named <k> tests; moved <k> out of Behavior
   - PR #<p> <spec>: pending James's merge (changes not in it: <list> | none)
   - Gap #<n>: <criterion> (delta <name>, parent #<p>)
   - Fold pending: <name> in <spec> (fold PR #<p> open | gap #<g> open)
   - Abandoned delta: <name> in <spec> (parent #<p> dropped)
   - Closed, never split: <name> in <spec> (parent #<p>)
   - Needs converge: <name> in <spec> (converge skill not available)
   - Superseded, out of scope: <spec> (by <file>)

   Verdict: requirements met | requirements not met: <n> statements (<k> of them in draft specs still being built)
   ```

   The verdict counts unmet statements only; dead statements are proposals
   and shipped-but-unfolded deltas are folds, neither a failed
   requirement; and the Met, Unmet and Dead columns count Behavior
   statements only, so a statement moved out of Behavior is in none of
   them. "requirements met" is the verdict when that count is zero
   across every spec in scope, dead statements notwithstanding; the
   parenthesis appears only when a draft spec in progress contributes to
   the count. Every PR, issue and statement the ceremony touched appears in
   the report, so James can check each one. Then close the ceremony issue:
   ```bash
   cellq complete <ceremony issue>
   ```
   Report the ceremony issue URL, the verdict and the PR and issue URLs in
   the reply.
