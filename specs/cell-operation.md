# Cell operation

Status: draft

Derived from: the cell operating model, infra-experiment-notes
`design/cell-operating-model.md` (2026-10-11). Section numbers below refer
to that document.

## Purpose

The skills, agents and template files that let a cell run the operating
model once it exists: intake, scoping, the two build routes, converge and
fold, the five ceremonies, cross-cell requests, and the thresholds the
rules read. Project creation is a separate spec (`project-creation.md`);
that one covers birth, this one covers life.

## Behavior

### Skills are invoked, never discovered

- Every skill below is named by the cell's entrypoint or started by a
  trigger or a named step in another skill. No skill relies on the agent
  choosing to load it.
- Skills carry no threshold numbers. Every rule reads the cell's
  thresholds file.
- Skills never set issue state with raw `gh` or GitHub MCP calls; they
  call the queue adapter.

### Thresholds file

`thresholds.yml` at the cell root, rendered by the project template, read
by every skill that applies a rule.

| Key | Starter value | Rule (design 7.2) |
|---|---|---|
| `route.spec_if.files_over` | 5 | R1 |
| `route.spec_if.sessions_over` | 1 | R1 |
| `task.max_diff_lines` | 400 | R4 |
| `task.max_files` | 5 | R4 |
| `task.max_review_minutes` | 10 | R4 |
| `spec.max_unfolded_deltas` | 3 | R7 |
| `claim.stale_after_hours` | 24 | R8 |
| `review.max_rounds` | 3 | R9 |
| `ceremonies.<name>.every_merges` | grooming 5, health 10, retro 15, structural 20, audit 40 | design 9.3 and the May periods |
| `edges.self`, `edges.default`, `edges.<cell>` | 1.0, 0.5, as set | design 8.4 |

Only the workflow retro changes this file, as a PR James merges.

### Queue adapter

One skill, `queue`, backed by one script. Verbs: `idea`, `scope`, `claim`,
`complete`, `request-feature`, plus `state <issue> <state>` and `ready`.

- States are the eight in design 4.1. The adapter maps them to a Projects
  status field; route and source are labels; parent and tasks are
  sub-issues; a claim is the move to in progress plus a comment naming the
  session.
- `ready` lists issues in ready state with no unmet dependency, ranked by
  priority times the arriving edge's weight, ties by age.
- The adapter is the only code that knows field names, labels and
  sub-issue calls.

### scope

Runs on every newly opened issue, from any source.

1. Reads the issue and the specs it names or that name its subject.
2. Writes the definition of done into the issue body: concrete inputs,
   observable outputs, testable statements.
3. Applies R1 and records the route label, `small` or `spec`.
4. Sets priority from the source label and the edge table.
5. Moves the issue to ready, or to blocked naming the blocker.
6. If a definition of done cannot be written, posts one question to James
   in the issue, moves it to needs input, sets no route, and stops.
   Re-runs when James comments.
7. For a cross-cell request, writes the definition of done in this cell's
   terms from the requester's example; never copies the requester's
   wording as the acceptance criteria.
8. For the spec route, keeps the issue open as the parent, blocked until
   the spec PR merges.

### implement (the small route)

Runs after a claim on a `small` issue. Design 7.3.

1. Reads the definition of done and the specs it names.
2. Plans in-session if more than one file is touched or the approach is
   uncertain; otherwise goes straight to the change.
3. Implements on a branch; runs the cell's test, lint and type commands.
4. If behaviour a spec describes changed, edits that spec's Behavior
   section in the same PR; every changed statement names its test, a test
   name and never a command or a file and line. A statement that is
   documentation, process or convention goes to Constraints or Non-goals,
   not Behavior, with no test line.
5. Hands off to `ship`.
6. R3, the exit: if the diff passes `task.max_diff_lines` or
   `task.max_files`, a second session is needed, or a contract another
   cell consumes changes, the agent stops, comments on the issue with the
   reason, moves it to new, and ends. It does not carry on.

### ship (changes)

- Step 1 reads R4 from the thresholds file instead of carrying numbers.
- The PR body states, under a fixed heading, whether any spec's Behavior
  changed and which statements, so the reviewer and James can check it.

### spec and split-spec (changes)

- `spec` writes every delta with the fields the completeness check
  requires: what changes, stays, is removed; acceptance criteria;
  non-goals; constraints; open questions; linked issue.
- `split-spec` runs the completeness check first and refuses a delta
  missing any field, naming the field. Then the "small enough as-is"
  assessment. Then tasks as sub-issues of the parent, each with its
  definition of done, through the queue adapter. Sub-specs only under R5.

### converge

Runs in a fresh session when the last sub-issue of a parent closes.

1. Reads the delta's acceptance criteria and the merged code on main.
2. For each criterion, states pass or fail with the evidence. A behaviour
   criterion passes only on the result of a real, re-runnable test (for
   UI appearance, a screenshot comparison); a command's output or a file
   and line is evidence of a check, not a test, and a behaviour criterion
   with no test fails. A criterion about documentation, process or
   convention passes on the file and line that shows it. A What-changes
   claim about what the software does that no criterion covers is checked
   for a test the same way, so nothing enters Behavior without one.
3. All pass: opens a docs-only PR with the `proposal` label that deletes
   the delta from Pending changes and moves its content out: what the
   software does into Behavior, each statement naming its test;
   documentation, process or convention into Constraints, Non-goals, the
   README or an ADR, with no test line. A statement without a test never
   enters Behavior. The PR closes the parent when merged.
4. Any fail: opens a gap issue naming the criterion and evidence (for a
   behaviour criterion with no test, the missing test), linked to the
   parent, and leaves the delta in place. The parent stays open.
5. Never edits code, tests or workflows.

### reviewer (changes)

Adds to the review checklist, as an Important finding when missed:

- Behaviour a spec describes changed, and the spec's Behavior section was
  not edited in the same PR.
- A changed Behavior statement names no test, or names a test that does
  not assert it; a command or a file and line is not a test.
- The PR body's spec-change heading disagrees with the diff.

### Ceremonies

Five skills, `ceremony-<name>`. Each runs from an issue the trigger files
when the merged-PR count reaches a multiple of its period. Each ends in
PRs James merges, issues, or a report; none changes main directly.

| Skill | Does |
|---|---|
| `ceremony-grooming` | Returns stale claims to ready (R8); drops issues with no activity past a threshold and says why; rescores by the edge table; links dependencies; flags specs over `spec.max_unfolded_deltas` for splitting (R7); routes any issue still in new. |
| `ceremony-health` | Reads each active spec's Behavior against the code and the test suite. Folds unfolded shipped behaviour, marks superseded, or deletes text for behaviour that no longer exists, each as a proposal PR. Produces the self-description report: features offered; whether requirements are met (every Behavior statement has a passing test, no open gap issue, gate green). Counts Behavior statements only: a statement in Behavior that is not about what the software does is reported as one to move out of Behavior, with a proposal PR that moves it, and is neither met nor unmet. |
| `ceremony-structural` | Architecture pass: convention drift, layering, security smells, doc rot; one issue per finding; flags a second purpose as a sibling-cell candidate. |
| `ceremony-retro` | Computes the fixed report (design 10.4): review rounds and rework by PR size band, route and source; cost per merged PR by surface and model; gate load; counts of re-routes, gaps and breaks. Proposes threshold and edge-weight changes as one PR to `thresholds.yml`, each change citing the report. |
| `ceremony-audit` | Prepares a top-down walk from the self-description, ADRs and plans; runs the quiz with James, functional level first, then approaches and patterns, then implementation decisions; writes a log entry to infra-experiment-notes; opens an issue per gap. Also runs in short form on one capability after each fold. |

### Cross-cell request template

An issue template, `request.yml`, in the project template, with the six
fields of design 8.2: requesting cell and issue (required); what is
needed as an observable outcome (required); an example input and expected
output (required); why, linking the requester's spec; priority hint;
definition of done (left blank; `scope` fills it). The requester's agent
also opens a mirror issue in its own cell, blocked, linking across.

### steward

Moves from the project template into the plugin unchanged.

## Acceptance criteria

Each is executable by an agent with no other context, against a cell
rendered from the project template.

- `scope` on an issue whose body is one sentence: the issue is in needs
  input, has a comment ending in a question, and has no route label.
- `scope` on an issue describing a one-file change: the body contains a
  definition of done with at least one testable statement, the route label
  is `small`, and the issue is in ready.
- `scope` on an issue naming six files: the route label is `spec`, the
  issue is blocked, and the blocker comment names the spec PR to come.
- `scope` on a request-template issue: the definition of done differs
  textually from the requester's example and references it.
- `implement` on a `small` issue whose change exceeds `task.max_files`:
  the agent ends with the issue in new, a comment naming R3 and the count,
  and no PR open.
- `implement` on a change that alters a Behavior statement: the PR diff
  touches the spec file, and the PR body's spec-change heading lists the
  statement and its test.
- `reviewer` on a PR that alters described behaviour without touching the
  spec: verdict REQUEST_CHANGES with an Important finding naming the
  spec.
- `split-spec` on a delta lacking non-goals: stops before the splitter
  runs and names the missing field; no issues are created.
- `converge` when every criterion passes: one open PR, labelled
  `proposal`, whose diff removes the delta from Pending changes and adds
  its behaviour content to Behavior, each statement naming a test; any
  documentation, process or convention content is in Constraints,
  Non-goals, the README or an ADR with no test line; no gap issue.
- `converge` when one criterion fails: one open gap issue naming the
  criterion and its evidence; the delta unchanged; no PR.
- `converge` on a behaviour criterion whose only evidence is a command's
  output or a file and line: one open gap issue naming the criterion and
  the missing test; the delta unchanged; no PR.
- `queue ready` on a cell with one own issue at priority 2 and one
  request from a cell weighted 0.5 at priority 3: the own issue ranks
  first.
- `ceremony-retro` on a cell with ten merged PRs: a PR changing only
  `thresholds.yml`, whose body contains the report table and cites it for
  each changed key, or a report stating no change is proposed.
- `ceremony-health` on a cell with a Behavior statement whose test was
  deleted: the self-description report lists that statement as unmet and
  a proposal PR or issue exists for it.
- `ceremony-health` on a cell whose Behavior holds a statement about what
  a document says: the report lists it as to move out of Behavior, not as
  unmet, and a proposal PR moves it.
- No skill in this spec contains a numeric threshold; `grep` for the
  starter values across `plugins/jsb-harness/skills/` returns nothing.
- No skill in this spec invokes `gh issue edit`, `gh project`, or an MCP
  issue-write tool directly; all go through the queue script.

## Non-goals

- Project creation and the one-time repository setup (`project-creation.md`).
- The project template's other changes: entrypoint shrink, removal of
  rendered rulebooks, the sync Action (stem-cell's spec, design step 3).
- The triggers: what starts a `scope` or `converge` session, and the
  Action that files ceremony issues. They depend on the execution surface
  and go in this spec's plan.
- Fixture-cell CI and Renovate (ADR 0006).
- The derived self-description as a standalone command; the health
  ceremony's report is its first form.
- Bot identity for agent PRs (deferred in the design).
- Inner-source PRs between cells (design 8.5: request only).

## Constraints

- No API billing; everything runs on the Max subscription.
- Agents never merge; James merges every PR, including fold and
  threshold PRs.
- Skills do not install in cloud sessions by marketplace; the existing
  session-start hook copies the plugin in. Unchanged here.
- The queue adapter's GitHub surface must work with `gh` locally and with
  the REST API through the cloud proxy; it must not need repo-settings
  writes.
- The reviewer is delivered at run time from the harness (ADR 0005); its
  checklist change ships through that path.

## Open questions

1. Whether the Projects status field can be created and read through the
   cloud proxy; if not, the adapter falls back to a `state:<name>` label
   set with the same vocabulary. To settle in the plan.
2. Whether `converge` runs as one session per parent or one per delta
   when a spec PR carried several deltas. Default: per parent issue.
3. The ceremony-audit short form after each fold: whether it is a
   separate issue or a comment thread on the fold PR. Default: a comment
   thread.

## Pending changes

None. This spec is new; its Behavior is the intended contract and the
acceptance criteria above are what the implementing tasks are cut from.

Linked issue: #31

## Decisions

- [[docs/adr/0007-issue-state-in-labels-and-sub-issues.md]] — issue state
  in labels and sub-issues; the Projects field in the design is amended.
- [[docs/adr/0008-process-triggers-are-actions-workflows.md]] — scope,
  converge and ceremony triggers as reusable Actions workflows.
- [[docs/adr/0009-queue-adapter-is-one-stdlib-script.md]] — `cellq`, one
  Python stdlib script, REST only.
- [[docs/adr/0006-pin-callers-to-sha-renovate-bumps.md]] — executable CI
  pinned; skills unpinned. This spec adds skills only.
- [[docs/adr/0002-no-spec-kit-add-plan-phase.md]] — plan between spec and
  split; unchanged, `split-spec` gains the completeness check before it.
- [[docs/adr/0005-reviewer-delivered-from-harness.md]] — the reviewer
  checklist change ships through the harness delivery path.
