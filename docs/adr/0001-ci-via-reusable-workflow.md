# 0001 — Distribute the CI review gate as a reusable workflow

- Status: accepted
- Date: 2026-08-31
- Supersedes: none
- Deciders: James

## Context and problem statement

The agent review gate is a GitHub Actions workflow, and an Actions workflow must
physically live in `.github/workflows/` of the repo it runs in — it cannot be
followed from the plugin marketplace the way the skills are. `/new-experiment`
therefore **copies** `templates/project/.github/workflows/claude-review.yml` into
each new repo at scaffold time. That copy is a frozen snapshot: editing the
template never reaches back into already-created repos.

The pain surfaced immediately. The `proposal`-label change (skip agent review on
spec/mockup PRs) was merged into the harness, and the skills picked it up live —
but `chord-recommender`, scaffolded earlier, kept running the old ~125-line
workflow and agent-reviewed a spec PR for three rounds. Propagating a workflow
fix would have meant hand-editing every repo, forever.

## Considered options

1. **Copy the full workflow per repo, edit each on change** (status quo). No new
   infrastructure, but O(repos) manual work per change and guaranteed drift.
2. **Reusable workflow (`workflow_call`)** — logic lives once in the harness; each
   repo carries a ~15-line caller stub that `uses:` it with `secrets: inherit`.
3. **Org "required workflows"** — inject a workflow into all repos centrally, no
   stub at all. Requires a GitHub **organization**; James is on a personal
   account, so unavailable without restructuring accounts.
4. **File-sync bot** — a scheduled action opens PRs propagating files across
   repos. Still N copies, just automated; more moving parts than (2) for CI.

## Decision

Adopt **option 2**. The reusable core lives at
`.github/workflows/claude-review.yml` in the harness (`on: workflow_call`); the
project template ships only a thin caller stub that pins
`JSBaxter/harness/.github/workflows/claude-review.yml@main` and forwards secrets.
`github` context (actor, `event.pull_request.*`, labels) is inherited from the
caller's `pull_request` event, so the guards and the proposal check work
unchanged. Logic edits now propagate to every primary repo on its next PR.

The harness repo is private, so `PUT /repos/JSBaxter/harness/actions/permissions/access`
is set to `access_level: user` (one-time) to let the user's other private repos
call the workflow.

## Consequences

- **Positive:** one source of truth for gate logic; the per-repo stub is stable
  and essentially never changes; `chord-recommender` and future repos track the
  harness automatically.
- **Pin trade-off:** `@main` is zero-maintenance but a bad harness push breaks
  every repo's gate at once. A moving `v1` tag or SHA pin trades that for
  controlled rollout; the stub documents the knob. Starting on `@main`.
- **Stealth constraint (important):** a caller stub names `JSBaxter/harness`,
  which would link a stealth repo to the primary account in plaintext. So the
  stub is **primary-identity only**. Stealth repos keep a self-contained copy of
  the gate (derive it from the reusable workflow: swap `on: workflow_call` for
  the `pull_request` trigger + concurrency block). Those few repos accept drift,
  which is acceptable — they are meant to be isolated anyway.
- **Not covered:** non-executing per-repo files (`CLAUDE.md`, etc.) still drift;
  a future `/sync-template` skill can roll those forward deliberately. Low-stakes
  because they don't run.
