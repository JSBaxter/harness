---
status: accepted
supersedes: 0003
date: 2026-10-11
deciders: James
---

# 0006 — Caller stubs pin the harness to a commit SHA; Renovate opens the bumps

## Context and problem statement

ADR 0003 decided that project caller stubs would use a moving `v1` tag
which James moves by hand after a gate change proves out on the harness
repo. Five weeks later the tag does not exist, both template stubs still
call the reusable workflows at `main`, and the harness repo has neither a
caller stub nor a ruleset. The ADR's own revisit trigger fired: a manual
ceremony nobody performed.

The operating-model design (infra-experiment-notes,
`design/cell-operating-model.md`, 2026-10-11) refit distribution to
established practice for shared CI:

- GitHub's hardening guidance: pin actions and reusable workflows to a full
  commit SHA, with the human-readable ref in a trailing comment.
- Updates reach pinned consumers as automated bump PRs through the
  consumer's own CI (Renovate, with one shared config every repository
  extends), not as a tag someone remembers to move.
- The producer tests downstream use before release.

## Considered options

1. **Keep the moving `v1` tag and start moving it.** Rejected: it was not
   moved once in five weeks, and the design's never-list rules out
   per-release chores James performs by hand.
2. **Pin callers to a commit SHA; Renovate bumps.** The standard pattern.
3. **Stay on `main`.** Rejected: a bad harness merge breaks every repo's
   gate at once, with no containment.

## Decision

We will adopt option 2.

1. **Caller stubs pin to a full commit SHA** with the branch name in a
   trailing comment (`@<sha> # main`). The template ships with the SHA of
   the harness commit it was cut from.
2. **Renovate opens bump PRs.** This repository holds the shared preset
   (`default.json` at the root); every project's `renovate.json` extends
   it with `github>JSBaxter/harness`. The preset pins action digests and
   treats reusable-workflow references as digest-tracked dependencies.
   Each bump is a PR that runs the project's own gate and James merges.
3. **The reusable workflow's call to this repo's `setup-reviewer` action
   stays at `main`.** It cannot be pinned to the workflow's own commit:
   `uses:` takes a literal ref, and checking the harness out at
   `job.workflow_sha` from a project workflow fails because this repo is
   private and the caller's token cannot read it (the Actions access
   setting is what allows the `uses:` reference at all). The action
   delivers one markdown file, the reviewer, which is prose and so falls
   under decision 4. Accepted as a second hop that carries no executable
   CI.
4. **Skills stay unpinned**, as ADR 0003 decided. That part carries over
   unchanged and remains a deliberate exception to standard practice: a
   skill is prose, a bad one shows up in the next PR, and one commit
   reverts it everywhere.
5. **The harness runs its gate against a fixture cell on every harness
   PR** (downstream compatibility CI). Not implemented in this ADR's PR;
   recorded as the replacement for 0003's "harness repo as canary", which
   depended on a caller stub that was never added.

## Consequences

- Every project's executable gate runs a known harness commit. A bad
  harness merge reaches a project only through a bump PR that project's
  gate rejects.
- One account-level manual step: install the Renovate GitHub App on the
  account and enable it for each repository. Recorded in README setup.
- Until Renovate runs, pins go stale silently. The first Renovate run is
  the test that the preset tracks a branch-head SHA with a `# main`
  comment; if it does not, switch the comment to a moving tag that
  Renovate can follow and move that tag from the fixture-cell workflow.
- Existing gated repos need their stub changed once, through the
  disable-ruleset recipe in the README, as 0003 already noted.

## Alternatives considered

- **`$/` same-repository references** are for a reusable workflow in the
  same repo as the caller; they do not apply across repositories.
- **A moving major tag** (`@v1`, the `actions/*` convention) is readable
  and Renovate can track it, but it is mutable and GitHub's policy can now
  require SHA pins; the SHA with a comment gives the same readability.
- **A PAT secret per project** would let the reusable workflow check this
  repo out at its own commit and pin the second hop. Rejected: a per-repo
  manual secret is on the design's never-list.
