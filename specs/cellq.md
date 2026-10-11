# cellq — queue adapter contract

Status: draft
Derived from: specs/cell-operation.md (Queue adapter, Thresholds file) and
specs/cell-operation.plan.md (Contracts). Inherits the spec's constraints
(stdlib only, REST only, works through the cloud proxy, no repo-settings
writes) and ADRs 0007 and 0009. A change-scoped sub-spec: when its tasks
land, the parts that describe shipped behaviour fold into
cell-operation.md and this file is deleted.

## Purpose

The command-line contract of `plugins/jsb-harness/bin/cellq`. Ten of the
thirteen tasks cut from cell-operation.md invoke it, so the contract is
written once here rather than in each issue body. Skills and workflows code
against this file; the script is the only code that knows labels,
sub-issue endpoints and comment formats.

## Behavior

### Invocation

`cellq <verb> [args] [--repo o/r]`.

| Item | Rule |
|---|---|
| Repository | `--repo`, else `$GITHUB_REPOSITORY`, else the `origin` remote of the current directory |
| Token | `GH_TOKEN`, else `GITHUB_TOKEN`, else `gh auth token` |
| Success | exactly one JSON document on stdout, exit 0 |
| Failure | one line on stderr; exit 1 for an API or validation failure, exit 2 for usage or environment (no repo, no token, unknown verb) |
| Transport | REST only, `urllib`; no GraphQL, no `gh` for API calls |

### Labels

Single-valued per group; the adapter removes the other labels of a group
when it sets one, and creates a label in the repository on first use.

| Group | Values |
|---|---|
| `state:` | `new`, `needs-input`, `ready`, `blocked`, `in-progress`, `in-review`, `done`, `dropped`. `done` is the issue closed as completed, `dropped` closed as not planned; the label is kept. Any other state reopens a closed issue. |
| `route:` | `small`, `spec` |
| `source:` | `own`, `ceremony`, `agent`, `cell:<name>` |
| `priority:` | `1` to `5`, higher is more urgent |

`idea` passes its labels in the create request so they are present on the
`opened` event.

### Body conventions

| Line or section | Written by | Read by |
|---|---|---|
| `## Definition of done` | `scope` | implementing agents, the reviewer |
| `Depends on: #a, #b` (one line) | `depend` | `ready` |
| `Parent: #n` | `link`, only as the fallback when the sub-issue endpoints are unavailable | `parent`, `list` |

### Comments

| Event | Comment |
|---|---|
| claim | `claimed by <session ref> at <ISO-8601 UTC>` |
| state change with a reason | `state: <state> — <reason>` |

### Verbs

| Verb | Effect | Output |
|---|---|---|
| `idea <title> [--body f] [--source s]` | creates the issue with `state:new` and `source:<s>` (default `own`) | `{number, url}` |
| `scope <n> --dod f --route r --priority p [--blocked "<reason>"]` | replaces or appends the definition-of-done section from file `f`; sets `route:` and `priority:`; then `ready`, or `blocked` with the reason | `{number, route, priority, state}` |
| `claim <n> [--session ref]` | refuses unless `state:ready`; sets `in-progress`; posts the claim comment. Ref defaults to `$CLAUDE_SESSION_ID`, else `$GITHUB_RUN_ID`, else `user@host` | `{number, claimed_by, claimed_at}` |
| `complete <n>` | `done` | `{number, state}` |
| `state <n> <state> [--reason r]` | sets the state; with a reason, posts the comment | `{number, state}` |
| `depend <n> <m>` | adds `#m` to the `Depends on:` line of `n`; idempotent | `{number, depends_on}` |
| `link <parent> <child>` | makes `child` a sub-issue of `parent` (REST sub-issues, by issue id) | `{parent, child}` |
| `request-feature <title> --to o/r --kind k --example f --why f [--priority-hint p]` | opens the request in repo `o/r` with the six request-template headings, `state:new` and `source:cell:<this repo>`; opens a mirror issue here, `state:blocked`, linking it; comments the mirror's URL on the remote issue | `{remote: {number, url}, mirror: {number, url}}` |
| `ready` | `state:ready` issues with no open `Depends on` issue, ranked | `[{number, title, priority, source, weight, score, created_at}]` |
| `list [--state s] [--route r] [--source s]` | open issues, or closed ones when the state asked for is `done` or `dropped` | `[{number, title, state, route, source, priority, created_at, claimed_by, claimed_at, depends_on, parent}]` |
| `parent <n>` | the parent, the sub-issues and whether all are closed | `{parent, sub_issues: [{number, closed}], all_closed}` |
| `merged-count` | merged PRs in the repository, from the search endpoint's `total_count` | `{count}` |
| `threshold <dotted.key> [--file path]` | the scalar from `thresholds.yml` as JSON | the scalar |

### Ready ranking

`score = priority × weight`. Weight is `edges.self` for `source:own`;
`edges.<cell>` for `source:cell:<cell>` when that key exists, else
`edges.default`; `edges.default` for `source:ceremony` and
`source:agent`. Descending score; ties by older `created_at`. Issues not in
`state:ready`, or with any open `Depends on` issue, are excluded.

### thresholds.yml subset

Nested mappings by two-space indent; scalar values parsed as int, float or
string; no lists, anchors or flow syntax. Default path: the git toplevel of
the current directory, `thresholds.yml`. A missing file or key exits 1
naming which.

## Acceptance criteria

- `bash plugins/jsb-harness/bin/tests/test-cellq.sh` passes offline (threshold reads from a temp file: `task.max_diff_lines` prints `400`, `edges.default` prints `0.5`, `ceremonies.grooming.every_merges` prints `5`, a missing key exits 1).
- With `CELLQ_TEST_REPO` set, the online section passes: after each `state` move exactly one `state:` label is present; `done` closes the issue; `link` makes the child appear in the parent's sub-issue list; `claim` on a `state:new` issue exits 1; `depend` twice with the same target leaves one `#m`; `ready` ranks a `source:own` priority 2 issue above a `source:cell:other` priority 3 issue when `edges.other` is 0.5; an issue with an open dependency is absent from `ready` and present once the dependency closes.
- `grep -E '^import|^from' plugins/jsb-harness/bin/cellq` lists only standard-library modules.

## Non-goals

- Projects boards (ADR 0007).
- Any write to repository settings, rulesets or secrets.
- Caching or a local store; every call reads GitHub.

## Constraints

Those of cell-operation.md. Additionally: the sub-issue endpoints are
repository-scoped REST and expected to pass the cloud proxy; the `Parent:`
line is the fallback if they do not.

## Open questions

1. Whether a `priority:` label group is the right home for priority, or a
   body line. Default: label, so the issue list can filter on it from a
   phone.

## Decisions

- [[docs/adr/0007-issue-state-in-labels-and-sub-issues.md]]
- [[docs/adr/0009-queue-adapter-is-one-stdlib-script.md]]
