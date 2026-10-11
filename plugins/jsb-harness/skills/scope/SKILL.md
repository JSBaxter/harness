---
name: scope
description: Turn a newly opened issue into a routed, ready task with a definition of done, or send it to needs-input with one question. Invoked by the cell-scope workflow or by name; never self-selected.
---

# Scope

Turn one newly opened issue into a task an agent can claim: a definition of
done in the issue body, a route label, a priority, and a state of ready or
blocked. When that cannot be done from the issue plus the cell's specs, ask
James exactly one question and stop.

Argument: an issue number in the current repository (the workflow prompt is
`Run /scope on issue #<n>`).

`cellq` below is the queue adapter (`plugins/jsb-harness/bin/cellq`; contract
in the harness's `specs/cellq.md`). Every issue-state change in this skill
goes through it, and every threshold is read through it from the cell's
`thresholds.yml`; this skill carries no numbers. Never set a label, state,
body or comment with raw `gh`, a project board, or a GitHub MCP write tool;
the adapter is the only writer. Reading is free: read the issue
with `gh issue view <n> --json number,title,body,labels,comments,url` (or the
REST endpoints `repos/<o>/<r>/issues/<n>` and `.../issues/<n>/comments` when
`gh` is absent).

## Steps

1. **Read the issue, then the specs.**
   - If the issue carries `source:ceremony` and its title starts
     `Ceremony: `, it is the ceremony issue the cell-ceremony workflow
     files (`Ceremony: <name> (merged PR <count>)`, straight into ready, for
     `/ceremony-<name>` to run on): stop and report that. Only that
     combination is skipped. An issue a ceremony opened for a finding
     carries `source:ceremony` without that prefix and is scoped like any
     other; its body says what closing the finding looks like, which is the
     draft of the definition of done.
   - An issue with no `state:` label is new: it was opened from the web UI or
     with raw `gh` and nothing has labelled it yet. Scope it. If it carries
     a `state:` label other than `new` or `needs-input`, stop and report the
     state: it has been scoped already, or someone is working it.
   - If it is in `state:needs-input`, this is a re-run: James has commented.
     Treat every comment by the repository owner that follows the question
     comment (`state: needs-input — ...?`) as part of the issue body from
     here on.
   - Read every spec in `specs/` the issue names, and every spec whose
     Purpose or Behavior section names the issue's subject (grep `specs/` for
     the nouns in the title). Note which Behavior statements the change would
     touch; they belong in the definition of done.

2. **Cross-cell request?** The body has a `Requesting cell and issue` heading
   (the request form renders it as `### Requesting cell and issue`) when it
   came through `request.yml`. Then the definition of done is written in
   this cell's terms, derived from the `Example` field, not from the
   requester's prose:
   - Quote the example's input and its expected output inside the definition
     of done, and state what this cell will observably do to turn the one
     into the other: which command, endpoint, file or function, and what it
     returns.
   - Never reuse the `What is needed` sentence, or a paraphrase of it, as an
     acceptance statement. It says what the requester wants to be true; the
     definition of done says how this cell proves it, in the vocabulary of
     this cell's specs.
   - `Why` links the requester's spec; read it for context, not for wording.
   - The heading says how the issue was written, not where it came from: a
     request a cell's agent filed with `cellq request-feature` carries
     `source:cell:<name>`; one a person typed into the form carries no
     `source:` label. Step 5 weights by the label, not the heading.

3. **Write the definition of done, or ask one question.** The form is in
   "Definition of done" below: concrete inputs, observable outputs, and
   acceptance statements each of which an agent with no other context can
   check on its own and call pass or fail.
   - Draft it from the issue plus the specs read in step 1. Resolve small
     gaps by reading the code; do not invent requirements.
   - If it cannot be written — the outcome is ambiguous, the input or output
     is unknown, two readings of the issue lead to different changes — ask
     the one question whose answer unblocks the draft, ending in `?`:
     ```bash
     cellq state <n> needs-input --reason "<question>?"
     ```
     Set no route and no priority, do not write a definition of done, and
     stop. Report the issue URL and the question. The cell-scope workflow
     re-runs this skill when James comments; the re-run starts at step 1
     with his comment as part of the issue.

4. **Route (R1).** List the files the change touches: those the issue names,
   plus those a reader of the specs and the code can see must change with
   them (tests; the spec's Behavior section when a described behaviour
   changes). Count the distinct paths. Estimate sessions: one, unless the
   change cannot land in a single PR (a contract and its consumers, more
   than one independent component, a migration and the code that needs it)
   or the approach is a real choice that needs a plan first. Then read the
   thresholds:
   ```bash
   cellq threshold route.spec_if.files_over
   cellq threshold route.spec_if.sessions_over
   ```
   Above either value the route is `spec`; otherwise `small`. If either
   read fails, stop and report what the failure line says: exit 1 naming
   `thresholds.yml` means the cell has no thresholds file; exit 2 means no
   repository or token; command not found means the plugin is not installed
   (in a cloud session run it as `../harness/plugins/jsb-harness/bin/cellq`).
   Never substitute a value from memory or from another repository. Record
   the file list and the session estimate in the definition of done so the
   route is checkable.

5. **Priority.** Take the hint from the `Priority hint` field when the body
   has one with a value (the form renders an unset hint as `_No response_`,
   which is no value), else `3`. Multiply by the edge weight for the issue's
   `source:` label:
   - `source:own`, or no `source:` label: `cellq threshold edges.self`
   - `source:cell:<name>`: `cellq threshold edges.<name>`; if that exits 1
     because the key is absent (the failure line names the key, not the
     file), use `cellq threshold edges.default`
   - `source:agent` or `source:ceremony`: `cellq threshold edges.default`

   Round to the nearest integer, halves up, and clamp to the `priority:`
   range of `1` to `5`.

6. **Record it through cellq.** Write the definition of done to a temporary
   file (its first line is the `## Definition of done` heading; cellq
   replaces or appends that section in the issue body) and call:
   ```bash
   cellq scope <n> --dod <file> --route <route> --priority <p>
   ```
   - Route `spec`: add `--blocked "awaiting spec PR: specs/<area>.md"`, naming
     the spec file the change will be written into — an existing spec whose
     Behavior covers the subject (the change becomes a pending delta there),
     else a new `specs/<area>.md`. The issue stays open as the parent: say
     so in the definition of done, so that `split-spec` links the spec's
     tasks to it as sub-issues and `converge` closes it when they land.
   - If the change depends on another open issue (`#m` must land first,
     because the change builds on what it delivers), record the dependency:
     ```bash
     cellq depend <n> <m>
     ```
     `cellq ready` then holds `<n>` back until `#m` closes. If the work
     cannot even start before `#m` closes (as opposed to merging after it),
     also block it, with the reason:
     ```bash
     cellq state <n> blocked --reason "depends on #<m>"
     ```

7. **Report** the issue URL and the state cellq set (`ready`, `blocked` with
   its reason, or `needs-input` with the question), the route and the
   priority.

## Definition of done

What `cellq scope --dod` writes into the issue body. One section, in this
form; every bullet under "Acceptance" is a statement someone can check
without having read this conversation.

```markdown
## Definition of done

Inputs: <the concrete starting state: the command, request, file or event
  that exercises the change, with values>
Outputs: <what is observable afterwards: output, file, response, label,
  comment — with the expected values>
Files: `path/one`, `path/two` (<count>)
Sessions: one | more than one — <why>
Specs: `specs/<area>.md` — <Behavior statements touched, or "none">

Acceptance:
- <statement: given <input>, <command or check> shows <output>>
- <statement>

<Route spec only:> This issue is the parent. The spec is written to
`specs/<area>.md` as a PR James merges; `split-spec` files its tasks as
sub-issues of this issue, and `converge` closes it when they all land.

<Cross-cell request only:> Derived from the requester's example:
input `<quoted input>`, expected output `<quoted output>`. Requested by
<owner/repo#number>.
```

A statement is testable when it names what to run or look at and what must
be there. "The parser handles bad input" is not; "`cellq threshold
no.such.key` exits 1 and names `no.such.key` on stderr" is.
