# Routine template: PR review loop on Anthropic cloud (zero Actions minutes)

Alternative home for the review gate, as a Claude Code Routine
(claude.ai/code/routines) instead of GitHub Actions. Same loop, compute on
Anthropic's side. Use this if Actions minutes ever become a constraint or you
want the gate on public + private repos uniformly.

## Trigger

- Event: `pull_request` — types: opened, ready_for_review
- Filters: author is NOT the Claude bot (prevents self-triggering);
  is_draft = false
- Do NOT trigger on `synchronize` — the loop handles its own re-review rounds
  in-session, and routine hourly caps make per-push triggering wasteful.

## Prompt

Paste into the routine, replacing OWNER/REPO placeholders:

---

You are the review gate for the pull request that triggered this session, in
OWNER/REPO. You are the FIXER; judging is done by the `reviewer` agent
(.claude/agents/reviewer.md), spawned FRESH each round.

Loop, at most 3 rounds:
1. Spawn the `reviewer` agent on `git diff origin/<base>...HEAD`.
2. VERDICT APPROVE → exit loop.
3. Fix ONLY Important findings (smallest correct fix), run the tests per
   CLAUDE.md, commit with prefix "review-fix:".

Then finalize (mandatory):
- Push commits. FINAL_SHA=$(git rev-parse HEAD).
- Approved → `gh api repos/OWNER/REPO/statuses/$FINAL_SHA -f state=success
  -f context=claude-review -f description="approved after N round(s)"`; remove
  the needs-human label if present.
- No consensus after 3 rounds → same call with `-f state=failure -f
  description="no consensus - needs human"`; `gh pr edit <n> --add-label
  needs-human`; post ONE comment listing unresolved Important findings and why
  each wasn't fixed.
- Minor findings never block and are mentioned at most once.

---

## Caveats vs the Actions version

- Routines are research-preview: per-routine and per-account hourly caps. If a
  routine run is skipped by a cap, no status gets stamped → with the ruleset's
  required `claude-review` status the PR fails safe (merge blocked, shows
  "expected") but nothing flags it — check claude.ai/code for missed runs.
- No `timeout-minutes` equivalent; the 3-round cap and the session's own limits
  are the bound.
- The Actions version (`templates/project/.github/workflows/claude-review.yml`)
  has a crash backstop step that routines can't replicate; treat a PR stuck on
  "expected — claude-review" as the needs-human signal.
