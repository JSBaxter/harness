---
name: queue
description: The cell's issue queue through the cellq adapter; the state vocabulary, the rule that state changes only through cellq, where the script lives, and one example per verb. Read before touching an issue's state, route, source, priority, dependencies or parent.
---

# Queue

A cell's work queue is its GitHub issues. Each issue carries one state, a
route, a source and a priority as labels, its dependencies on a
`Depends on:` body line, and its parent as a sub-issue link. The queue
adapter, `cellq`, is the only code that knows those labels, endpoints and
comment formats (the harness's `specs/cellq.md` is the contract; the
decisions are the harness's ADRs on issue state and on the adapter).

## Where cellq lives

`plugins/jsb-harness/bin/cellq` in the harness plugin. In a cloud session
without the plugin, the harness is checked out beside the cell:
`../harness/plugins/jsb-harness/bin/cellq`. It is a Python script with
no dependencies beyond the standard library; it needs a token (`GH_TOKEN`,
`GITHUB_TOKEN`, or a `gh` login) and a repository (`--repo o/r`,
`GITHUB_REPOSITORY`, or the `origin` remote of the current directory).
Every success prints one JSON document; a failure prints one line on
stderr, exit code one for an API or validation failure, two for a usage
or environment problem.

## The one rule

Issue state, route, source, priority, dependencies and parent links are
set only through `cellq`. Never `gh issue edit`, `gh issue close`,
`gh project`, a project board, or an MCP issue-write tool: those leave
the labels and the sub-issue links inconsistent, and `ready` then lies.
Reading is free (`gh issue view`, `gh api`, the REST endpoints); writing
is not.

Thresholds and edge weights come from the cell's `thresholds.yml` through
`cellq threshold`; no skill carries a number of its own.

## States

Eight states, one per issue, each a `state:` label.

| State | Meaning |
|---|---|
| `new` | Opened, not yet scoped. The scope skill picks it up. |
| `needs-input` | Scoping stopped on one question to James, posted in the issue. Re-scoped when he answers. |
| `ready` | Has a definition of done, a route and a priority; claimable. Only `ready` issues appear in `cellq ready`, and only when every dependency is closed. |
| `blocked` | Waiting on something named in the reason comment: a spec PR, a cross-cell request, a dependency. Not claimable. |
| `in-progress` | Claimed by a session; the claim comment names it and the time. |
| `in-review` | A PR is open for it, waiting on the gate and James. |
| `done` | Closed as completed. The label stays on the closed issue. |
| `dropped` | Closed as not planned, with the reason in a comment. The label stays. |

Moving a closed issue to any state other than `done` or `dropped` reopens
it.

## Verbs

One example each; `<n>`, `<m>`, `<p>` and `<child>` are issue numbers in
this repository.

Open an idea (source `own` unless given; `ceremony`, `agent` or
`cell:<name>` for the others):

```bash
cellq idea "Rename the export command" --body idea.md --source agent
```

Scope it: write the definition of done from a file, set route and
priority, move it to `ready`, or to `blocked` with a reason:

```bash
cellq scope <n> --dod dod.md --route small --priority <p>
cellq scope <n> --dod dod.md --route spec --priority <p> --blocked "awaiting the spec PR"
```

Claim it (refused unless `ready`; the session ref defaults to the Claude
session, the Actions run, or user@host):

```bash
cellq claim <n>
```

Complete it:

```bash
cellq complete <n>
```

Move it to any state, with a reason that becomes a comment:

```bash
cellq state <n> blocked --reason "depends on #<m>"
```

Make it depend on another issue (idempotent; `ready` then holds it back
until `<m>` closes):

```bash
cellq depend <n> <m>
```

Make one issue a sub-issue of another:

```bash
cellq link <p> <child>
```

Ask another cell for a feature; opens the request there and a blocked
mirror here:

```bash
cellq request-feature "Export as CSV" --to owner/other-cell --kind api --example example.md --why why.md
```

What to work on next: `ready` issues with no open dependency, best score
first (priority times the arriving edge's weight), older first on a tie:

```bash
cellq ready
```

List issues with any of three filters; closed issues only when the state
asked for is `done` or `dropped`:

```bash
cellq list --state in-progress
cellq list --state done --source ceremony
```

An issue's parent and sub-issues, and whether every sub-issue is closed:

```bash
cellq parent <n>
```

Merged pull requests in the repository:

```bash
cellq merged-count
```

A scalar from `thresholds.yml` (the cell root by default):

```bash
cellq threshold claim.stale_after_hours
```

## Output shapes

`ready` rows: `{number, title, priority, source, weight, score,
created_at}`. `list` rows: `{number, title, state, route, source,
priority, created_at, claimed_by, claimed_at, depends_on, parent}`, where
`claimed_*` come from the latest claim comment and are null when there is
none. `parent`: `{parent, sub_issues: [{number, closed}], all_closed}`,
with `parent` null for a top-level issue and `all_closed` true when there
are no sub-issues at all, so check `sub_issues` before trusting it.
