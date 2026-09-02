---
name: spec
description: Create or update a living spec in specs/. Specs are the persistent source of truth for intended behavior; plan mode plans a session, specs outlive sessions.
---

# Spec

Create or update a living specification under `specs/`.

## Principles

- Specs describe **current intended behavior** plus **pending changes**, not
  history. History lives in git and ADRs.
- One spec per capability/feature area, named `specs/<area>.md`. Sub-specs
  derived by /split-spec live alongside with a `Derived from:` line.
- A spec change for existing behavior is written as a **delta**: what changes,
  what stays, what's removed — then merged into the spec body once implemented.
- Acceptance criteria are written to be executable by an agent with no other
  context: concrete inputs, observable outputs, testable statements.

## Spec file structure

```markdown
# <Area>

Status: draft | active | superseded by <file>

## Purpose
One paragraph: what this exists to do, for whom.

## Behavior
The contract. Bullet points, each independently testable where possible.

## Non-goals
Things deliberately not done. Prevents scope creep by future agents.

## Pending changes
### <change-name> (<date>)
Delta: what changes / what stays / what's removed.
Acceptance criteria: ...
Linked issues: #NN

## Decisions
Links to relevant ADRs: [[docs/adr/NNNN-*.md]]
```

## The human gate (non-negotiable)

A spec is a proposal until James merges it. After drafting:
1. Present a compact summary in chat for workshopping: purpose, the 3-5 key
   design decisions, what's deliberately out of scope — and for anything
   educational or user-facing, **what the user should learn or be able to
   do afterwards**.
2. Commit the spec on a branch (Conventional Commits, e.g. `docs(spec): ...`)
   and **open a PR titled `Spec: ...`** whose body states "Merging this PR =
   approving the spec." The PR is the durable approval artifact; chat approval
   alone is not sufficient. The **`proposal`** label makes the review gate skip
   the agent reviewer — a spec asks James's opinion, it isn't finished work to
   critique. Apply it **at creation**; labelling afterwards works but only after
   a full agent review has already run (see /ship step 8):
   ```bash
   gh label create proposal -c "c5def7" \
     -d "opinion/spec/mockup PR — human review only, skip agent gate" --force
   gh pr create --title "Spec: ..." --body "..." --label proposal
   ```
3. STOP. Do not run /split-spec, file issues, or write implementation code
   until the spec PR is merged. James's merge is the signature.

The spec is where the human steers; it is the cheapest point in the pipeline
to be wrong at. Building against an unreviewed spec produces technically
excellent implementations of the wrong thing (this happened; see the
residual-stream-viz first iteration).

## Steps

1. Read existing specs in `specs/` before writing — extend, don't duplicate.
   (`<area>.plan.md` files there are implementation plans, not specs — they
   describe how in-flight work is being built and get retired when it lands.)
2. If the user described a change to existing behavior, write it under
   **Pending changes** as a delta; don't rewrite the body until the change lands.
3. Say what comes next, and that it comes *after* James merges the spec PR:
   /plan when the approach involves a real choice (multiple components, a
   dependency or interface being picked, parallel dispatch ahead), then
   /split-spec if the spec looks too big for one agent to implement in one PR.
   Neither is mandatory — /plan is skipped when the approach is forced, and
   /split-spec reports "small enough as-is" when it is.
4. When implementation of a pending change merges, fold the delta into the
   Behavior section and delete it from Pending changes (do this when asked, or
   when you notice a merged PR references the delta).
