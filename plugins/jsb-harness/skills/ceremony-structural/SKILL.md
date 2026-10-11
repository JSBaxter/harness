---
name: ceremony-structural
description: Structural review. Runs from a ceremony issue the cell-ceremony workflow files and ends in PRs James merges, issues, or a report, never a direct change to the default branch. An architecture pass over the repository (convention drift against CLAUDE.md and the ADRs, layering violations, security smells, doc rot), one issue per finding, and a sibling-cell candidate issue when the repository serves a second purpose. Invoked by name from the ceremony issue; never self-selected.
---

# Ceremony: structural

Read the repository the way a new maintainer would, with CLAUDE.md, the
ADRs and the specs in hand, and write down where the code has drifted from
what those documents say, where one layer reaches into another, where
something looks unsafe, and where a document says something the code
contradicts. Each finding becomes one issue, filed into new for `scope`.
Nothing is fixed here: the ceremony produces issues and a report, never a
commit on the default branch and never a merge.

Argument: the ceremony issue number (the workflow prompt is `Run
/ceremony-structural on issue #<n>`). The issue carries `source:ceremony`
and is already `state:ready`; the report goes there and it is closed last.

`cellq` is the queue adapter (`plugins/jsb-harness/bin/cellq`; in a cloud
session without the plugin, `../harness/plugins/jsb-harness/bin/cellq`;
contract in the harness's `specs/cellq.md`). Every issue this skill opens
and every state it sets goes through it, and every threshold is read
through it from the cell's `thresholds.yml`; this skill carries no numbers.
Never set a label, state or body with raw `gh`, a project board, or a
GitHub MCP write tool. Reading is free.

## Steps

1. **Open the ceremony issue and the rulebook.** Read the ceremony issue
   (`gh issue view <n> --json title,labels,state`): it must be open, carry
   `source:ceremony`, and its title must start `Ceremony: structural` (the
   form the cell-ceremony workflow files); otherwise stop and report what
   it is. Then read, in full, `CLAUDE.md`, every file in
   `docs/adr/` (an ADR marked superseded still matters: the superseding
   one says what replaced it), every spec in `specs/` and the README. List
   the conventions these state as one line each, with the file that states
   it; that list is what step 2 checks the code against. Read the previous
   structural report, if any (the most recently closed `source:ceremony`
   issue whose title starts `Ceremony: structural`; `cellq list --state
   done --source ceremony`, then by title; a finding a ceremony opened
   carries the same label without the `Ceremony: ` prefix and is not one),
   so that a finding it already raised is not raised twice.

2. **The pass.** Walk the repository top down: the layout, then each
   top-level directory, then the files that other files depend on most.
   Look for exactly these four kinds of finding, and record each as
   "where, what, which rule, how to check":
   - **Convention drift.** Code, config or a workflow that does what a
     line in CLAUDE.md or an accepted ADR says not to, or omits what one
     says to do: a rule carrying a literal number where the thresholds
     file should be read, an issue write that bypasses the adapter, a
     workflow caller not pinned the way the pinning ADR requires, a
     commit style or test command CLAUDE.md names that the repository
     does not follow.
   - **Layering violations.** A module that reaches past the boundary a
     spec, ADR or the directory layout draws: the only code allowed to
     know a thing (field names, labels, an external API) is not the only
     code that knows it; a lower layer importing a higher one; a template
     carrying logic the plugin owns, or the reverse.
   - **Security smells.** Secrets or tokens in tracked files; a workflow
     with broader permissions than its steps use; an unpinned action or
     dependency that runs with write access; shell built from untrusted
     input (issue titles, PR bodies) without quoting; a token passed to a
     place that does not need it. Report these first.
   - **Doc rot.** A statement in the README, CLAUDE.md or a spec's
     `## Behavior` section that the code contradicts, or that names a
     file, command or path that no longer exists. Quote the statement and
     point at the code that disagrees. (A Behavior statement whose *test*
     is missing belongs to the health ceremony, not here; a statement that
     is simply false belongs here.)

   Run the cell's lint and test commands from CLAUDE.md and read the
   output only for structure (an import cycle, a skipped test, a warning
   about a deprecated path); their green or red is not this ceremony's
   finding. Ignore style a linter would catch, and ignore anything an open
   issue already covers (`cellq list` for the titles; `gh issue view <n>
   --json body` for the bodies of the likely ones).

3. **A second purpose?** Ask of the whole repository: does it do one
   thing? Signs of a second purpose: a directory with its own
   dependencies, deploy path or audience that the Purpose section of no
   spec covers; two specs with disjoint vocabularies and no shared code; a
   README that needs "and also" to describe the cell. When the answer is
   yes, name the second purpose in one noun phrase. The design's rule is
   that a cell is split by birth of a sibling, never by sub-directory, and
   that the ceremony flags it and James decides.

4. **One issue per finding.** For each finding from step 2, write a body
   with the finding (where, what, which rule, how to check) and what
   closing it looks like, concretely enough that `scope` can write the
   definition of done from it without asking: the files the fix touches,
   and the checks an agent with no other context can run, the first of
   which is that the check from the finding no longer fails. Then open it
   through the adapter and leave it in `new`:
   ```bash
   cellq idea "<kind>: <where> — <what>" --body <file> --source ceremony
   ```
   Set no route, priority or state and write no `## Definition of done`
   section: that is `scope`'s job, and it treats a `source:ceremony`
   finding like any other issue (it skips only the ceremony issue itself,
   the one whose title starts `Ceremony: `). `scope` reaches the issue
   through grooming's routing of what is still new, by hand (`/scope
   <n>`), or through the cell-scope workflow when its guard lets a
   `source:ceremony` issue through. A finding that calls an ADR into
   question is still one issue, whose body says that closing it is a
   superseding ADR through `/adr` rather than a code change.

   A finding where you can see the smell but not the fix is still a task,
   not a question: say in the body that the first thing closing it means
   is the question which settles it answered in the issue with the
   evidence (the agent that claims it investigates first), and describe
   the fix conditional on that answer. A question only James can answer
   goes in the report instead, under "Questions for James", not into the
   finding's body, so that `scope` is not the one left to ask it.

5. **The sibling-cell candidate.** When step 3 found a second purpose and
   no open issue already names it, open one issue titled exactly
   `Sibling-cell candidate: <purpose>` whose body gives the evidence from
   step 3, which specs and directories would move, and what the dependency
   between the two cells would become as a cross-cell request. It is not
   a task: splitting is James's decision, not an agent's work, and the
   issue is his decision record. So it is the one issue this ceremony
   does not leave in new for `scope`; it goes to `blocked`, with the
   question as the reason, on purpose. `scope` stops on a blocked issue
   (step 1 there: a state other than new or needs-input), the cell-scope
   re-run fires only on `needs-input`, and grooming never rescores or
   routes a blocked issue, so nothing in the cell moves it on; James
   closes it as not planned, or births the sibling (the project-creation
   path) and closes it when the moved capability's spec is marked
   superseded here. It appears in grooming's drop candidates once a
   period passes untouched, which is the reminder.
   ```bash
   cellq idea "Sibling-cell candidate: <purpose>" --body <file> --source ceremony
   cellq state <n> blocked --reason "James's decision: split <purpose> into a sibling cell?"
   ```
   The two calls belong together: if the second fails, repeat it before
   doing anything else, and if it keeps failing say so in the report with
   the issue number, because a decision record left in `new` is what
   grooming's routing step would next hand to `scope` as a task.

6. **Report and close.** Post the report as a comment on the ceremony
   issue (a comment is not state: `gh issue comment <n> --body-file
   <report>`, or `POST repos/<o>/<r>/issues/<n>/comments` through the REST
   API when `gh` is absent):

   ```markdown
   ## Structural report — <date>

   Previous structural review: #<n> (<date>) | none
   Rulebook read: CLAUDE.md, <count> ADRs, <count> specs, README

   | Kind | Findings | Issues opened | Already open |
   |---|---|---|---|
   | Security smells | <n> | <n> | <n> |
   | Convention drift | <n> | <n> | <n> |
   | Layering violations | <n> | <n> | <n> |
   | Doc rot | <n> | <n> | <n> |
   | Sibling-cell candidate | yes: <purpose> / no | <n> | <n> |

   ### Findings
   - #<n> <title> — <where>; rule: <file and line, or ADR>; in new for `scope`
   - (already open as #<m>) <title>

   ### Not raised
   - <what was looked at and found sound, one line each area>

   ### Questions for James
   - <a question only he can answer, with the finding it bears on> | none
   ```

   "Not raised" matters: a pass that found nothing in an area says the
   area was read. A review with no findings is a valid outcome; the report
   says so and nothing is opened. Then close the ceremony issue:
   ```bash
   cellq complete <ceremony issue>
   ```
   Report the ceremony issue URL and the counts in the reply.
