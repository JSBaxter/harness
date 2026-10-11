---
name: ceremony-audit
description: Understanding audit. Runs from a ceremony issue the cell-ceremony workflow files and ends in PRs James merges, issues, or a report, never a direct change to the default branch. Prepares a top-down walk of the cell from the latest health report, the ADRs and the plans; quizzes James one question at a time in three levels (functional, approaches and patterns, implementation decisions); writes a dated log entry to infra-experiment-notes as a PR; opens one issue per gap. The short form after each fold is a comment thread on the fold PR. Invoked by name from the ceremony issue; never self-selected.
---

# Ceremony: audit

Walk James through the cell from the top until he can explain each part of
it back, and write down where he could not, or where the cell could not
explain itself. The agent asks, James explains, the agent confirms or
corrects. A gap is either in James's understanding or in the cell; both get
an issue, because a part of the cell its owner cannot explain is a part the
cell has failed to document. The ceremony produces a log entry (a PR to
the notes repository), issues, and a report; never a change to the default
branch of either repository and never a merge.

Argument: the ceremony issue number (the workflow prompt is `Run
/ceremony-audit on issue #<n>`). The issue carries `source:ceremony` and is
already `state:ready`; the report goes there and it is closed last.

`cellq` is the queue adapter (`plugins/jsb-harness/bin/cellq`; in a cloud
session without the plugin, `../harness/plugins/jsb-harness/bin/cellq`;
contract in the harness's `specs/cellq.md`). Every issue this skill opens
and every state it sets goes through it, and every threshold is read
through it; this skill carries no numbers. Never set a label, state or body
with raw `gh`, a project board, or a GitHub MCP write tool. Reading is
free.

This is a sit-down session, not a phone touchpoint: step 3 needs James
present and answering. When the session is not interactive (an Actions
run, or James is absent), do steps 1 and 2 only, post the prepared walk as
a comment on the ceremony issue as the agenda, leave the issue open, and
stop; James starts an interactive session from the issue and the skill
resumes at step 3 from that agenda.

## Steps

1. **Open the ceremony issue and gather the inputs.** Read the ceremony
   issue (`gh issue view <n> --json title,labels,state,comments`): it must
   be open, carry `source:ceremony`, and name the audit; otherwise stop and
   report what it is. If a comment on it already holds a prepared walk
   (from a non-interactive run), skip to step 3 with that agenda. Then
   gather:
   - **The latest health self-description report**: the most recent
     comment holding a health report on the most recent issue with
     `source:ceremony` whose title names the health ceremony (`cellq list
     --state done --source ceremony` and `cellq list --source ceremony`,
     then by title and `created_at`; read the comments). It lists the
     features the cell offers and whether its requirements are met. When
     no health report exists yet, derive the feature list yourself from
     the Purpose and Behavior sections of every active spec, and say in
     the log entry that the walk was prepared without one.
   - **The ADRs**: every file in `docs/adr/`, superseded ones included.
   - **The plans**: every `specs/*.plan.md`, and the Decisions and Open
     questions sections of every spec.
   - **The previous audit**: the most recent entry for this cell under
     `design/audit-log/` in the notes repository, so that a gap it logged
     can be checked for closure.

2. **Prepare the walk.** Write the agenda as three ordered levels, each a
   list of questions with the answer you expect and the source the answer
   comes from (a spec statement, an ADR, a plan line, a file). Top down:
   the first question at each level is about the whole cell, the last
   about a part.
   - **Functional**: what the cell offers (one question per feature in the
     self-description), what it provides to and consumes from other cells,
     and whether the requirements are met (what the health report said,
     and why).
   - **Approaches and patterns**: the shape of the solution: the layers,
     the one place each kind of knowledge lives, the trigger and flow
     patterns, the conventions CLAUDE.md states and the reason behind
     each.
   - **Implementation decisions**: one question per accepted ADR (what was
     decided and what it rejected), plus the plan's choices that an ADR
     does not cover and the open questions a spec still carries.

   Questions a previous audit logged as gaps come first at their level,
   so that closure is checked. Keep each question answerable in a few
   sentences; a question whose expected answer you cannot source is not
   asked, it is a gap in the cell and goes straight to step 4.

3. **Run the quiz.** Level by level, in the order above; within a level,
   one question at a time. Ask the question, then wait for James's answer
   before saying anything else: no hints, no batching, no moving on. When
   he answers, say one of three things and record it:
   - **Confirmed**: his answer matches the source. Cite the source in one
     line and move on.
   - **Corrected**: his answer differs from the source. Say what the
     source says and where. This is a gap in James's understanding, and
     by the rule above a gap in the cell's self-explanation: note which
     document should have carried it.
   - **The cell is wrong**: his answer is what the cell *should* do and the
     source says otherwise, or he names a behaviour the cell has and no
     document describes. This is a gap in the cell: note the document and
     the expected statement.
   James may also say "skip" or "stop"; record it and respect it. A level
   is finished when its questions are asked or James stops. Do not start
   the next level before the current one is finished.

4. **One issue per gap.** For each gap from steps 2 and 3, write a body
   with the question, the answer given, the source consulted, and what
   closing the gap looks like, with a `## Definition of done` in the form
   the `scope` skill writes: for an understanding gap, the document that
   should carry the explanation carries it (a README, CLAUDE.md, spec or
   ADR edit, as a PR); for a cell gap, the spec statement or behaviour that
   is missing or wrong, with the test that will assert it. Open it and
   make it ready through the adapter (the `scope` skill stops on
   `source:ceremony`, so this ceremony scopes what it opens):
   ```bash
   cellq idea "Audit gap: <short name>" --body <file> --source ceremony
   cellq scope <n> --dod <dod-file> --route <small|spec> --priority <p>
   ```
   The route is `small` unless the fix touches more files than
   `cellq threshold route.spec_if.files_over` or needs more sessions than
   `cellq threshold route.spec_if.sessions_over`; then it is `spec`, with
   `--blocked "awaiting spec PR: specs/<area>.md"`. The priority is what
   `scope` step 5 gives a `source:ceremony` issue: the default hint times
   `cellq threshold edges.default`, rounded to the nearest integer, halves
   up, clamped to the `priority:` range. A gap that is a decision James
   has to make (two readings of the cell, both defensible) goes to him
   instead of ready, with the one question:
   ```bash
   cellq state <n> needs-input --reason "<question>?"
   ```
   Do not open an issue a previous audit already opened and that is still
   open (`cellq list --source ceremony`, by title); link to it in the log
   instead.

5. **The log entry.** Write the entry to the notes repository
   (`JSBaxter/infra-experiment-notes`; locally a sibling checkout at
   `../infra-experiment-notes`, else clone it to a temporary directory)
   at `design/audit-log/<cell>-<date>.md`, where `<cell>` is this
   repository's name and `<date>` is today in ISO form, on a branch
   `audit/<cell>-<date>`, as one commit and a PR against that repository's
   default branch titled `Audit log: <cell> <date>`. Never commit to its
   default branch. The entry:

   ```markdown
   # Understanding audit: <cell>, <date>

   Ceremony issue: <url>. Health report: <url> | none (walk prepared from
   the specs). Previous audit: <path> | none.

   ## Functional
   | Question | Answer | Verdict | Source |
   |---|---|---|---|
   | <q> | <James's answer, in his words, shortened> | confirmed / corrected / cell wrong / skipped | <file or url> |

   ## Approaches and patterns
   (same table)

   ## Implementation decisions
   (same table)

   ## Gaps
   | Gap | Kind | Issue |
   |---|---|---|
   | <short name> | understanding / cell | <url> |

   ## Closed since last audit
   - <gap from the previous entry> — <closed by: PR or issue url> | still open
   ```

   The entry records what James said, not a cleaned-up version of what he
   should have said; the verdict column is where the judgement goes.

6. **Report and close.** Post the report as a comment on the ceremony
   issue (a comment is not state: `gh issue comment <n> --body-file
   <report>`, or `POST repos/<o>/<r>/issues/<n>/comments` through the REST
   API when `gh` is absent):

   ```markdown
   ## Audit report — <date>

   Log entry: <PR url in infra-experiment-notes>

   | Level | Asked | Confirmed | Corrected | Cell wrong | Skipped |
   |---|---|---|---|---|---|
   | Functional | <n> | <n> | <n> | <n> | <n> |
   | Approaches and patterns | <n> | <n> | <n> | <n> | <n> |
   | Implementation decisions | <n> | <n> | <n> | <n> | <n> |

   Gaps: <n> issues opened (<n> understanding, <n> cell), <n> already open,
   <n> sent to James as questions.
   Closed since last audit: <n> of <n>.
   ```

   Then close the ceremony issue:
   ```bash
   cellq complete <ceremony issue>
   ```
   Report the ceremony issue URL, the log PR URL and the counts in the
   reply.

## Short form after a fold

The full walk runs on the ceremony's period. The short form runs on one
capability, the one a fold PR just moved from Pending changes into
Behavior, and it lives on that fold PR: `converge` step 6 opens the thread
there, so the audit is attached to the thing James is about to merge and
there is no separate issue. The same three levels, in the same order, but
only about that capability: what it offers and whether its criteria are
met (the converge evidence lines are the source); the approach the
delta took and why; the decisions it made, with the ADR or plan line that
made them. Few questions, one at a time, as comments on the fold PR; James
answers in the thread; the agent confirms or corrects in a reply. Each gap
is an issue through the adapter exactly as step 4, with the fold PR linked
in its body. No log entry is written for the short form; the thread on the
PR is the record, and the next full audit reads those threads (step 1,
"the previous audit") when it checks what has closed.
