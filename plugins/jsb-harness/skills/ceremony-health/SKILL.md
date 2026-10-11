---
name: ceremony-health
description: Health check. Runs from a ceremony issue the cell-ceremony workflow files and ends in PRs James merges, issues, or a report, never a direct change to the default branch. Reads every active or draft spec's Behavior against the code and the test suite, classifies each statement as met, unmet or dead, folds shipped behaviour still sitting in Pending changes, proposes deletions for behaviour that no longer exists, files an issue per unmet statement, and posts the self-description report. Invoked by name from the ceremony issue; never self-selected.
---

# Ceremony: health

Ask of every spec the cell carries: is each statement in Behavior still
true, and can the cell prove it? A statement is proved by its test passing
on the default branch, with no open gap issue against it and the gate green.
Statements the cell can no longer prove become issues; statements about
behaviour that is gone become a proposal to delete them; behaviour that
shipped but was never folded into Behavior is folded. The whole thing ends
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
   statement is each list item, bulleted or numbered, under `## Behavior`
   or any heading below it, and each row of a table there whose cells
   state a rule (a key and what it does, a verb and its effect); a
   paragraph of prose is context, not a statement. A statement names its
   test when it ends `— test: <name>` (the `spec` skill's form), where the
   name is a test function, a command, or a file and line, as `converge`
   step 3 writes them.

   Evidence must come from merged code, not from the branch this session
   happens to be on. Fetch, put the default branch in its own worktree
   (`git fetch origin`, `git worktree add --detach <dir> origin/<default>`;
   in an Actions run the checkout already is the default branch; confirm
   `git rev-parse HEAD` equals `git rev-parse origin/<default>`) and read
   CLAUDE.md there for the test command. Every test and command below runs
   in that worktree, and the report names the commit it checked (`git
   rev-parse --short origin/<default>`).

2. **Find and run each statement's test.** For every statement:
   - **Named test.** Find the test by its name: a test function or case by
     grep across the test directory CLAUDE.md's test command points at
     (`grep -rn '<name>' tests/`, or the directory the command names); a
     command by running it; a file and line by reading it. Run the named
     test on its own through the cell's test runner (`pytest -k <name>`,
     `python3 -m unittest <module>.<Class>.<name>`, `bash <script>` for a
     shell test, as the test command indicates), and keep the runner's
     output line and exit code.
   - **Unnamed statement.** Search the test suite for the test that asserts
     it: the identifiers the statement uses (a function, a flag, a verb, an
     exact string it quotes) grepped across the tests. When one test
     clearly asserts the statement (its assertions check the behaviour the
     statement describes, not merely mention the name), or a compound
     statement is asserted clause by clause by a few tests that together
     cover all of it, those are "the test that exists under another name":
     run each as above and mark the statement for a test reference naming
     each in step 5. When no test asserts it, or the tests found cover
     only part of it, the statement has no test, and the evidence says
     which clause is uncovered.
   - **Content statements** (a file says, contains, names something) are
     checked by reading the file at the line; the evidence is the file and
     line, and "passing" means the line still says it.

   Quote real output. Never report a run you did not do, and never run a
   test command from another repository because CLAUDE.md names a
   placeholder; a placeholder test command means every behaviour statement
   has no runnable test, and the report says so once at the top.

3. **Classify each statement.** Three classes, decided in this order:
   - **Dead**: the behaviour no longer exists in code. The thing the
     statement describes (the function, the verb, the flag, the file, the
     endpoint) is absent from the default branch, and `git log -S'<name>'
     --oneline` or `git log --diff-filter=D -- <path>` shows the commit
     that removed it. A statement whose test and code are both gone is
     dead; a statement whose code remains is never dead, however its test
     fares. The evidence is the search that found nothing in the code plus
     the removing commit.
   - **Met**: all three hold: the test passed (step 2); no open gap issue
     names it (`gh issue list --state open --search "Gap: in:title" --json
     number,title,body`, read each; a gap names the statement when its
     title or body quotes it or the criterion it was cut from); and the
     gate is green on the default branch. The gate is green when the
     combined status of the default branch's head (`gh api
     repos/<o>/<r>/commits/<sha>/status`, state `success`, or no statuses
     and no failed check runs under `.../check-runs`) is not failing; when
     the head carries no statuses at all because the gate stamps PR heads,
     read the `claude-review` status on the head commit of the most
     recently merged PR instead (`gh pr list --state merged --json
     headRefOid,mergedAt`, the newest `mergedAt`, then
     `.../commits/<sha>/statuses`). Read the gate
     once, not per statement; it is the same answer for every statement.
   - **Unmet**: everything else: the test is missing (a named test that no
     file defines, or no test asserts an unnamed statement), failing, or
     deleted (`git log --diff-filter=D` finds the file, or `git log
     -S'<name>'` finds the commit that removed the function, with the code
     still present); or the test passes but an open gap issue names the
     statement or the gate is red. The evidence is the specific reason:
     the runner's failure line, the search that found no test, the
     deleting commit, the gap issue number, or the failing status.

   Keep one record line per statement, in this form, with the statement
   quoted word for word (the issue title in step 5 is cut from it):
   ```
   MET   <spec>: <statement> — <evidence>
   UNMET <spec>: <statement> — <evidence>
   DEAD  <spec>: <statement> — <evidence>
   ```

4. **Fold unfolded shipped behaviour.** For each spec in scope, read every
   `### ` entry under `## Pending changes` and its `Linked issue` (and a
   new spec's bare `Linked issue:` line, as `converge` step 1 describes the
   two shapes). For each linked issue:
   ```bash
   cellq parent <n>
   ```
   The delta is shipped but unfolded when the linked issue is closed, its
   `sub_issues` is not empty and `all_closed` is true, and the delta is
   still in Pending changes. (Open parents are grooming's business, step 8
   there; a parent closed as `state:dropped` is an abandoned delta, listed
   in the report for James and left in place; a closed parent with no
   sub-issues was never split, so nothing was built to check: listed as
   "closed, never split".) For each shipped unfolded delta, run `converge`
   steps 2 and 3 (the skill in
   `plugins/jsb-harness/skills/converge/SKILL.md`; from source in a cloud
   session) with one difference: the parent is already closed, so
   `converge` step 1's gate on it is replaced by the check above, and the
   fold goes into this spec's proposal PR (step 6) rather than a PR of its
   own, so that one PR per spec carries everything health proposes for it.
   Evaluate every criterion exactly as `converge` step 2 says (one `PASS`
   or `FAIL` line each, real evidence, nothing partial). All pass: make the
   fold edits from `converge` step 3 on the spec branch of step 6 and keep
   the evidence lines for the PR body. Any fail: open the gap issue exactly
   as `converge` step 4 does (`cellq idea "Gap: <criterion>" --source
   agent`, then `cellq link <parent> <gap>`), fold nothing from that delta,
   and list it in the report; the parent being closed, the converge
   trigger will not refire, so the next health run re-checks it here. When
   the converge skill is not installed and cannot be read from source, do
   not improvise a fold; list the delta as "needs converge" and move on.

5. **Act on dead and unmet statements.**
   - **Dead**: on the spec branch of step 6, delete the statement from
     Behavior. When every statement of the spec is dead and another spec
     in `specs/` now describes the capability, instead change the spec's
     `Status:` line to `superseded by <that file>` and leave its text in
     place (the `spec` skill's form; a superseded spec is history, not a
     contract). When every statement is dead and no spec covers the
     capability, delete the statements and say in the PR body that
     Behavior is now empty and James should decide whether the spec goes.
   - **Unmet, test exists under another name** (step 2 found exactly one
     test that asserts it, and it passed): on the spec branch, append
     `— test: <name>` to the statement; no issue.
   - **Unmet, otherwise** (no test, a failing test, a deleted test, an
     open gap, or a red gate): one issue per statement, unless an open
     issue with the same title already exists (`gh issue list --state open
     --search "Unmet: in:title" --json number,title`, compare titles word
     for word). Write a body file naming the spec and its line, the
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
     is unmet for that reason; open one issue titled `Unmet: gate red on
     <default> at <sha>` instead of one per statement, and list the
     statements in its body.

6. **One proposal PR per spec.** For each spec with any fold (step 4),
   deletion, supersession or test reference (step 5), one branch from the
   default branch in the worktree of step 1 (`git switch -c
   health/<spec-name>-<date> origin/<default>`), editing that spec file
   and nothing else. `git status` must show only that file under `specs/`;
   if it shows anything else, revert it before committing. Commit as
   `docs(spec): health <spec-name> — fold, prune, name tests` (keep only
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
   statement and the test now named; a `## Spec changes` section in
   `/ship` step 9's form, one line per statement the diff adds to, changes
   in, or removes from Behavior (`<spec file>: "<statement>" — test:
   <name>`, or `— test: removed`). A fold's parent is closed already, so
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
   | <name> (<status>) | <first sentence of Purpose> | <n> | <n> | <n> |

   ### Unmet statements
   | Spec | Statement | Evidence | Action |
   |---|---|---|---|
   | <name> | <statement> | <evidence> | #<issue> \| PR #<n> (test reference) |

   ### Proposals and gaps
   - PR #<n> <spec>: folded <delta>; removed <k> statements; named <k> tests
   - Gap #<n>: <criterion> (delta <name>, parent #<p>)
   - Abandoned delta: <name> in <spec> (parent #<p> dropped)
   - Superseded, out of scope: <spec> (by <file>)

   Verdict: requirements met | requirements not met: <n> statements
   ```

   The verdict counts unmet statements only; dead statements are proposals
   and shipped-but-unfolded deltas are folds, neither a failed
   requirement. "requirements met" needs every statement in every spec in
   scope met. Every PR, issue and statement the ceremony touched appears in
   the report, so James can check each one. Then close the ceremony issue:
   ```bash
   cellq complete <ceremony issue>
   ```
   Report the ceremony issue URL, the verdict and the PR and issue URLs in
   the reply.
