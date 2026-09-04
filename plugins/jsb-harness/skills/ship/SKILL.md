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
6. **Commit hygiene** — commits should be small and each message follows
   Conventional Commits (`type(scope): summary`, e.g. `feat(auth): ...`); the
   body says why, not just what. Squash fixups.
7. **Frontend/visual changes: screenshots in the PR body.** Render 1-3
   deterministic screenshots of the key states this PR changed (use the
   project's shot helper), commit them under `docs/screenshots/<branch>/`,
   and embed each in a `## Screenshots` section with a one-line caption
   saying what to look at:
   ```markdown
   ![caption](https://github.com/<owner>/<repo>/blob/<branch>/docs/screenshots/<branch>/<name>.png?raw=true)
   ```
   Works on private repos (verified 2026-08-31, correctly this time —
   an earlier "doesn't render" conclusion was actually a missing file).
   Before embedding, VERIFY the file is on the remote:
   `gh api repos/<o>/<r>/contents/<path>?ref=<branch>` — `git add -A`
   silently skips gitignored paths, and a broken embed looks identical to
   an unsupported one. Show the changed state, not the idle page.
8. **Is this a proposal?** A spec, a mockup, an ADR draft, a sketch — anything
   opened to ask James's opinion rather than to land finished work — wears the
   **`proposal`** label. The review gate then skips the agent reviewer and
   stamps `claude-review` green directly; James's merge is the gate instead.
   Apply it **at creation** (`--label proposal` in step 9). Labelling afterwards
   does work — `labeled` re-runs the gate and flips the verdict — but only after
   a full agent review has already run.
   If the repo doesn't have the label yet:
   ```bash
   gh label create proposal -c "c5def7" \
     -d "opinion/spec/mockup PR — human review only, skip agent gate" --force
   ```
   **No `gh`? (cloud sessions.)** `create_pull_request` takes no `labels`
   parameter, so labelling at creation isn't directly possible — but the gate
   skips drafts (`!github.event.pull_request.draft`), which gets the same result
   in three MCP calls:
   1. `create_pull_request` with `draft: true`
   2. `issue_write` — method `update`, the PR number, `labels: ["proposal"]`.
      PRs are issues, so this works, and it creates the label if the repo
      lacks one.
   3. `update_pull_request` with `draft: false`

   The gate then sees the PR for the first time already labelled. Do NOT open a
   non-draft PR meaning to label it afterwards: that spends the exact review
   round the label exists to save, and it puts the job on the human — who will
   sometimes be on a phone, and will sometimes forget.

   Forgetting this is costly and the failure is silent: the gate reviews an
   unlabelled mockup as if it were production code, and because it re-runs on
   every push, each fix you make in response spawns another round. If you find
   yourself on round three of style nits against a file you plan to throw away,
   this label is what you missed — add it rather than continuing to push.
9. **Open the PR**:
   ```bash
   gh pr create --title "..." --body "..." --base <default-branch> [--label proposal]
   ```
   PR body must include: `Closes #NN` (the driving issue), a summary of what
   changed and why, test evidence (what was run, result), screenshots per
   step 7 for visual changes, and any disputed reviewer findings from
   step 4. If `gh pr edit` hits the projectCards GraphQL deprecation error,
   PATCH the body via `gh api -X PATCH repos/<owner>/<repo>/pulls/<n>`.
10. Report the PR URL and the review-gate status once CI kicks off. On a
   proposal PR, expect `claude-review` to pass immediately with "Proposal PR
   (`proposal` label)" as its reason — if it instead starts an agent review,
   the label didn't take.
