---
name: ship
description: Exit checklist before opening a PR — tests, self-review against spec and ADRs, small-commit hygiene, then open the PR with the issue linked.
---

# Ship

Run the pre-PR gate, then open the PR. Run this at the end of every implementation
task; don't open PRs any other way.

## Steps

1. **Scope check** — `git diff <base>...HEAD --stat`. If the diff exceeds ~400
   lines or ~5 files, stop and propose splitting into stacked PRs before
   continuing. Big diffs are the main cause of bad agent PRs.
2. **Tests** — run the project's test suite (see CLAUDE.md for the command). All
   green or you stop and fix; never open a PR with known-failing tests. Report
   actual output, not a summary of hope.
3. **Lint/format** — run the project's linters (ruff/clippy/eslint etc. per
   CLAUDE.md).
4. **Self-review** — invoke the **reviewer** agent (fresh context) on the diff.
   Fix Important findings, rerun tests, re-review until the reviewer approves or
   twice with no progress — in the no-progress case, note the disputed findings
   in the PR body for the human.
5. **ADR check** — did this work establish a new convention or make a real
   choice? If yes, run /adr before opening the PR.
6. **Commit hygiene** — commits should be small and each message should say why,
   not just what. Squash fixups.
7. **Frontend/visual changes: screenshots with the PR.** Render 1-3
   deterministic screenshots of the key states this PR changed (use the
   project's shot helper), commit them under `docs/screenshots/<branch>/`,
   and add a `## Screenshots` section to the PR body with a one-line
   caption per shot saying what to look at.
   - **Private repos** (the default): inline `![]()` embeds DO NOT render
     (GitHub's proxy can't fetch private raw URLs — verified 2026-08-31).
     Use plain links to the blob pages instead, and note that the
     committed PNGs render inline in the **Files changed** tab — that's
     the primary review surface (image diffs show before/after).
   - Public repos only: `![caption](.../blob/<branch>/<path>?raw=true)`
     embeds work.
   Show the changed state, not the idle page.
8. **Open the PR**:
   ```bash
   gh pr create --title "..." --body "..." --base <default-branch>
   ```
   PR body must include: `Closes #NN` (the driving issue), a summary of what
   changed and why, test evidence (what was run, result), screenshots per
   step 7 for visual changes, and any disputed reviewer findings from
   step 4. If `gh pr edit` hits the projectCards GraphQL deprecation error,
   PATCH the body via `gh api -X PATCH repos/<owner>/<repo>/pulls/<n>`.
8. Report the PR URL and the review-gate status once CI kicks off.
