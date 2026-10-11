---
status: accepted
supersedes: none
date: 2026-10-11
deciders: James
---

# 0008 — Process triggers are reusable Actions workflows that start a session

## Context and problem statement

The operating model needs three things to happen without James: scoping
when an issue opens, converge when a parent's last task closes, and a
ceremony issue when the merged-PR count reaches a period. Each must start
from a GitHub event and, for the first two, run a Claude session with
fresh context. Candidate homes: GitHub Actions, Claude Code routines, or a
laptop process.

## Considered options

1. **Reusable Actions workflows in the harness, called by pinned stubs,
   starting `claude-code-action` with the subscription OAuth token.** The
   shape the review gate already has (ADR 0001, 0006).
2. **Routines.** Zero Actions minutes, but hourly caps, no status
   writes, and a GitHub connection that was found disconnected on
   2026-10-11.
3. **A laptop process.** Unreachable from cloud and Actions; not always on.

## Decision

We will adopt option 1. Three reusable workflows: `cell-scope.yml`,
`cell-converge.yml`, `cell-ceremony.yml`. The ceremony workflow files
issues without a session; the other two start a session whose whole
prompt is `Run /<skill> on issue #<n>`. Fresh context is by construction:
every run is a new session.

## Consequences

- Actions minutes rise by one session per issue opened and per parent
  completed. Measure on the first cell; routines remain the fallback for
  scoping if minutes bind.
- The per-repo OAuth secret the gate already needs covers these too; no
  new credential.
- Logic changes propagate through bump PRs like the gate (ADR 0006).
- A run that fails leaves the issue in its prior state; the grooming
  ceremony routes any issue still in `state:new`.
