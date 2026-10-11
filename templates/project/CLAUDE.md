# PROJECT_NAME

<!-- Replace PROJECT_NAME and this line with a one-paragraph description. -->

## Ground rules for agents

- **Read before you act:** the relevant spec in `specs/` and any ADR in
  `docs/adr/` touching the area you're changing. If your change contradicts an
  accepted ADR, stop and surface it — don't silently "fix" the decision away.
- **Never push to main.** All changes go: branch → small commits → `/ship` → PR.
  One issue = one PR = reviewable in under ten minutes.
- **Conventional Commits, always.** Every commit message uses the
  `type(scope): summary` form (`feat`, `fix`, `refactor`, `docs`, `test`,
  `chore`, …). The body still says *why*, not just *what*.
- **Only finished work gets agent review.** A PR that just asks James's opinion —
  a spec, a mockup, any proposal — carries the `proposal` label; the review gate
  then skips the agent reviewer and James's merge is the review. Finished
  implementation PRs are never labelled `proposal`. `/spec` applies the label
  for you; add it by hand for mockup/RFC PRs.
- **Definition of done lives in the issue.** If the issue you're working has no
  acceptance criteria, send it back through `/split-spec` before writing code.
- **Approach before tasks, when there's a real choice.** If a spec involves
  picking a dependency, an interface, or module boundaries — or work will be
  dispatched in parallel — run `/plan` after the spec merges and before
  `/split-spec`. Plans are ephemeral: durable decisions become ADRs, and
  `specs/<area>.plan.md` is deleted once its issues land.
- **New conventions get an ADR** (`/adr`), and CLAUDE.md gets the resulting rule.
- **Tests run before every PR.** Test command: `TEST_COMMAND_HERE`.
  Lint command: `LINT_COMMAND_HERE`.
- **Issue state is set only through `cellq`** (the queue adapter,
  `plugins/jsb-harness/bin/cellq` in the harness plugin): `cellq state`,
  `cellq claim`, `cellq complete`, and so on. Never `gh issue edit`,
  `gh project`, or an MCP issue-write tool. The adapter is the only code that
  knows the labels and fields behind a state.
- **No rule carries a number.** Every threshold — diff size, file count,
  review rounds, stale-claim age, ceremony periods, edge weights — comes from
  `thresholds.yml` at the repo root, read with `cellq threshold <dotted.key>`.
  If you need a limit, read it; never write one into a skill or this file.
- **Skills an agent in this cell uses, and when:** `scope` on a new issue;
  `implement` after a claim on a `small` issue; `ship` to open the PR;
  `converge` when a parent issue's tasks all close; `ceremony-<name>` from a
  ceremony issue (`grooming`, `health`, `retro`, `structural`, `audit`);
  `queue` for any issue-state change; `steward` when watching a PR you opened.
  Each is named by this entrypoint, a trigger, or a step in another skill —
  none is discovered.

## Cloud sessions (claude.ai/code) — read this first

- The harness skills referenced here (`/ship`, `/adr`, `/spec`, …) may not
  be installed as slash commands in cloud containers. If `ListPlugins` is
  empty: the session should be configured with the `JSBaxter/harness` repo
  alongside this one — then READ the skill you need from
  `../harness/plugins/jsb-harness/skills/<name>/SKILL.md` and follow it,
  noting "followed /<name> from source" in your PR body. Never improvise a
  substitute procedure silently.
- `gh` may or may not be present in cloud containers (newer images
  pre-install it; auth flows through the proxy automatically). Check with
  `command -v gh`; if absent, use the GitHub MCP tools (e.g.
  `create_pull_request`) where a skill says `gh ...`.
- You cannot set commit statuses or check runs from a cloud session (the
  agent proxy blocks those writes). Don't try; the Actions gate stamps the
  status. Report state via PR comments only.

## Layout

- `specs/` — living specs: current intended behavior + pending deltas
- `docs/adr/` — decision history (MADR-style, supersede-don't-delete)
- `.github/workflows/claude-review.yml` — thin caller of the harness reusable
  review workflow; the agent review gate on every PR (proposals skip it)
- `thresholds.yml` — every number a rule reads, via `cellq threshold`; only
  the workflow retro changes it, as a PR James merges
- `.github/ISSUE_TEMPLATE/request.yml` — the cross-cell request form: six
  fields, enters intake as `state:new`, `scope` writes the definition of done

The `steward` skill (how to weigh review-gate findings on a PR you are
watching) now comes from the harness plugin, not from this repo.
