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

## Layout

- `specs/` — living specs: current intended behavior + pending deltas
- `docs/adr/` — decision history (MADR-style, supersede-don't-delete)
- `.github/workflows/claude-review.yml` — agent review gate on every PR
