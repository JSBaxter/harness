# PROJECT_NAME

<!-- Replace PROJECT_NAME and this line with a one-paragraph description. -->

## Ground rules for agents

- **Read before you act:** the relevant spec in `specs/` and any ADR in
  `docs/adr/` touching the area you're changing. If your change contradicts an
  accepted ADR, stop and surface it — don't silently "fix" the decision away.
- **Never push to main.** All changes go: branch → small commits → `/ship` → PR.
  One issue = one PR = reviewable in under ten minutes.
- **Definition of done lives in the issue.** If the issue you're working has no
  acceptance criteria, send it back through `/split-spec` before writing code.
- **New conventions get an ADR** (`/adr`), and CLAUDE.md gets the resulting rule.
- **Tests run before every PR.** Test command: `TEST_COMMAND_HERE`.
  Lint command: `LINT_COMMAND_HERE`.

## Cloud sessions (claude.ai/code) — read this first

- The harness skills referenced here (`/ship`, `/adr`, `/spec`, …) may not
  be installed as slash commands in cloud containers. If `ListPlugins` is
  empty: the session should be configured with the `JSBaxter/harness` repo
  alongside this one — then READ the skill you need from
  `../harness/plugins/jsb-harness/skills/<name>/SKILL.md` and follow it,
  noting "followed /<name> from source" in your PR body. Never improvise a
  substitute procedure silently.
- `gh` is not installed in cloud containers — use the GitHub MCP tools
  (e.g. `create_pull_request`) where a skill says `gh ...`.
- You cannot set commit statuses or check runs from a cloud session (the
  agent proxy blocks those writes). Don't try; the Actions gate stamps the
  status. Report state via PR comments only.

## Layout

- `specs/` — living specs: current intended behavior + pending deltas
- `docs/adr/` — decision history (MADR-style, supersede-don't-delete)
- `.github/workflows/claude-review.yml` — agent review gate on every PR
