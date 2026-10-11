# Cell operation — implementation plan

Derived from: specs/cell-operation.md (approved 2026-10-11)
Status: active

## Approach

Everything new is one of three kinds: a skill (prose, in the plugin), a
reusable Actions workflow that starts a Claude session on a GitHub event
(the same shape as the review gate), or a file the project template
renders into each cell. One Python script is the only code that touches
issue state. Nothing runs anywhere a cloud session or an Actions runner
cannot reach.

## Structure

| Path | Owns |
|---|---|
| `plugins/jsb-harness/bin/cellq` | The queue adapter: Python 3, stdlib only, REST only. Every verb in the spec. The only code that knows labels, sub-issue calls and comment formats. |
| `plugins/jsb-harness/skills/queue/` | How skills call `cellq`; the state vocabulary. |
| `plugins/jsb-harness/skills/scope/` | The scope procedure. |
| `plugins/jsb-harness/skills/implement/` | The small route, with the R3 exit. |
| `plugins/jsb-harness/skills/converge/` | Converge and the fold PR. |
| `plugins/jsb-harness/skills/ceremony-{grooming,health,structural,retro,audit}/` | One ceremony each. |
| `plugins/jsb-harness/skills/steward/` | Moved from `templates/project/.claude/skills/steward/`. |
| `plugins/jsb-harness/skills/{ship,spec,split-spec}/` | Edited: thresholds read, spec-change heading, completeness check. |
| `plugins/jsb-harness/agents/reviewer.md` | Edited: the three Behavior checks. |
| `.github/workflows/cell-scope.yml` | Reusable: on issue opened, and on an issue comment by the repo owner on a needs-input issue, start a session that runs `scope`. |
| `.github/workflows/cell-converge.yml` | Reusable: on issue closed, if the closed issue has a parent and all the parent's sub-issues are closed, start a session that runs `converge` on the parent. |
| `.github/workflows/cell-ceremony.yml` | Reusable: on PR closed and merged, count merged PRs; for each ceremony whose period divides the count, file its issue through `cellq`. No session. |
| `templates/project/.github/workflows/cell-{scope,converge,ceremony}.yml` | Caller stubs, pinned per ADR 0006. |
| `templates/project/thresholds.yml` | The starter values from the spec. |
| `templates/project/.github/ISSUE_TEMPLATE/request.yml` | The cross-cell request form. |
| `templates/project/CLAUDE.md` | Names the skills; adds the rule that issue state goes through `cellq`. |

Executing ready issues (build) is unchanged: `/dispatch` locally, or a
cloud session James starts. Auto-starting implementation on a ready issue
is a separate decision about hands-off operation, not made here.

## Contracts

**Label vocabulary**, single-valued per group, enforced by `cellq`:

| Group | Values |
|---|---|
| `state:` | `new`, `needs-input`, `ready`, `blocked`, `in-progress`, `in-review`; `done` and `dropped` are the issue closed as completed or not planned, with the label kept |
| `route:` | `small`, `spec` |
| `source:` | `own`, `ceremony`, `agent`, `cell:<name>` |

**Parent and tasks**: GitHub sub-issues (REST `.../issues/{n}/sub_issues`).
A claim is `state:in-progress` plus a comment `claimed by <session ref> at
<iso time>`. Stale-claim age is read from that comment.

**`cellq` CLI**: the full contract, including output shapes, the
`priority:` label group, the `Depends on:` body line, the request mirror
issue and the read verbs, is the sub-spec `specs/cellq.md` (split 2026-10-11).
Skills and workflows code against that file.

**`thresholds.yml`**: the keys in the spec, under `route`, `task`, `spec`,
`claim`, `review`, `ceremonies`, `edges`. Skills read it with a one-line
YAML-subset parser in `cellq` (`cellq threshold <dotted.key>`), so no
skill depends on a YAML library.

**PR body heading**: `## Spec changes` followed by `none` or one line per
changed Behavior statement with its test name. Written by `ship`, read by
the reviewer.

**Converge evidence**: one line per criterion, `PASS|FAIL <criterion> —
<evidence>`, in the fold PR body or the gap issue body.

**Session start from a workflow**: each reusable workflow invokes
`anthropics/claude-code-action` with `claude_code_oauth_token` and a prompt
of one line: `Run /<skill> on issue #<n>`. The skill is the procedure; the
workflow only names it. Skills and `cellq` reach the runner through a
composite action `setup-cell`, a sibling of `setup-reviewer`, because no
plugin install exists in Actions (found at split: the plan's "session-start
hook" does not exist; the hook that copies the plugin lives in project
repos for cloud sessions, not here).

**Done state**: `Closes #n` closes the issue on merge but leaves its
`state:` label. `cell-ceremony.yml`, which runs on every merge, calls
`cellq complete` for each issue the merged PR closes.

## Constraints inherited

- ADR 0001, 0006: logic in reusable workflows here; stubs pinned to a SHA.
- ADR 0005: the reviewer is delivered at run time; its checklist change
  ships through that path.
- ADR 0002: plan before split; this file is that plan.
- Design 7.4 and spec: no numbers in skills; only the retro edits
  `thresholds.yml`.
- Cloud proxy: no GraphQL, no repo-settings writes, no Actions-path
  writes; labels and issue writes allowed (probed 2026-09-03). Sub-issue
  REST is a repository path and is expected to pass; unverified.

## Decisions requiring an ADR

1. Issue state lives in labels and sub-issues, not in a Projects status
   field. Projects v2 is GraphQL-only and needs the `project` scope; the
   cloud proxy serves no GraphQL and the Actions token has no project
   access. ADR 0007.
2. Process triggers are reusable Actions workflows that start
   claude-code-action sessions, the same shape as the gate; not routines.
   ADR 0008.
3. The queue adapter is one Python stdlib script in the plugin, REST
   only; not bash over `gh` (absent in cloud), not an MCP server (May's
   second store). ADR 0009.

## Risks and unknowns

| Risk | Cheapest check |
|---|---|
| Sub-issue REST paths blocked by the cloud proxy | One `curl` from a cloud session against a test issue; fallback is a `parent:#n` line in the issue body parsed by `cellq` |
| `issues` events do not reach claude-code-action with subscription auth, or need `allowed_bots` | Run `cell-scope.yml` once on harness-test-drive |
| Actions minutes: one session per issue open and per parent close | Count after the first cell's first fortnight; routines are the fallback for scope only |
| Merged-count search caps at 1000 results | Use the search `total_count`, not a list |
| Converge run per parent misses a spec PR that carried several deltas | Spec open question 2: default per parent; revisit when it happens |
| Events created with `GITHUB_TOKEN` do not trigger workflows: a ceremony issue filed by `cell-ceremony.yml` fires no `cell-scope.yml`, and a sub-issue closed by `cellq complete` from inside Actions fires no `cell-converge.yml` | Ceremony issues are filed directly in ready (scope skips `source:ceremony`). Grooming also detects a parent whose sub-issues are all closed with no fold PR and runs converge on it. |

## Out of scope

- Which cell is first and where its sessions run.
- Auto-starting implementation on ready issues.
- Projects boards for James's phone view; a label-filtered issue list
  serves until a board is wanted.
