---
name: plan
description: Draft the technical approach for an approved spec — structure, contracts, boundaries — as a gated, ephemeral plan that /split-spec consumes and ADRs outlive. Runs between /spec and /split-spec.
---

# Plan

Decide **how** an approved spec gets built, before any agent starts building it.

Arguments: path to a spec file (defaults to the spec under discussion).

`/spec` fixes what and why. `/split-spec` needs module boundaries to produce a
real parallelism map. This is the step in between: the one place where "which
modules, which contracts, which library" is a deliberate choice rather than a
side effect of whichever agent picked up issue #1.

## Run it only when there's a real choice

Skip and say so when the approach is forced — a change confined to one existing
module, a library already established by an accepted ADR, or a spec small enough
that `/split-spec` will report "small enough as-is". A plan for work with one
obvious implementation is ceremony, and ceremony is what makes people stop
running the steps that matter.

Run it when any of these are true:
- More than one component or file boundary is in play.
- A dependency, protocol, storage format or interface shape is being chosen.
- Tasks will be dispatched in parallel (the boundaries decide what's safe).
- The obvious approach brushes against an accepted ADR.

## The plan is ephemeral. The ADRs are not.

A plan describes work in flight. Once the work has landed the code is the truth,
and a plan file that survives its implementation becomes a stale second source
that contradicts the spec — the exact failure this harness avoids by keeping
specs living and history in git and ADRs.

So a plan has a defined death:
- Every decision worth remembering is promoted to an ADR **before** the plan
  merges — the ADR is the durable artifact, the plan is scaffolding.
- When the last issue the plan spawned has merged, delete the plan file. Git
  keeps it; nothing else needs to.

## Plan file structure

Write to `specs/<area>.plan.md`. One page. If it runs long, the spec was too big
and belongs in `/split-spec` first.

```markdown
# <Area> — implementation plan

Derived from: specs/<area>.md (approved YYYY-MM-DD)
Status: active | retired (issues #NN, #NN merged)

## Approach
Two or three sentences: the shape of the solution. Not a restatement of the spec.

## Structure
Modules/files that will exist, and the boundary each owns. This is what makes
/split-spec's parallelism map real — be specific enough to tell whether two
tasks collide.

## Contracts
Interfaces, data shapes, wire/storage formats that cross a boundary. Anything
two tasks must agree on, written down so they don't have to negotiate at
implementation time.

## Constraints inherited
Accepted ADRs that bind this area, and what each one forecloses.

## Decisions requiring an ADR
Each real choice: the options, the pick, the reason. These become ADRs in step 5.

## Risks and unknowns
What could invalidate this plan, and the cheapest thing that would settle it.

## Out of scope
Approach questions deliberately deferred, so a later agent doesn't read silence
as an oversight.
```

Unlike a spec, a plan is deliberately technology-*specific*: name the library,
the version, the format.

## Steps

1. **Refuse unapproved specs.** Approved = the spec as it exists on `main`
   (James merged its PR). `git diff origin/main -- specs/<file>` must be empty;
   if not, stop and send it through the `/spec` human gate first. Planning
   against an unapproved spec plans the wrong thing more precisely.
2. **Read the constraints before drafting** — the spec, and every ADR in
   `docs/adr/` touching this area. If the approach you'd otherwise take
   contradicts an accepted ADR, **stop and surface it**. Do not route around it
   silently, and do not write the contradiction into the plan as though the ADR
   didn't exist. Either the plan changes or the ADR gets superseded via `/adr` —
   both are fine, deciding by omission is not.
3. **Assess first.** If there's no real choice here (see above), say so and stop.
   Do not manufacture a plan to have produced one.
4. **Draft** the plan file per the structure above.
5. **Extract the ADRs.** For each entry under *Decisions requiring an ADR*, run
   `/adr`. They are born `proposed`; James accepts them. Reference them from the
   plan's *Constraints inherited* once written.
6. **The human gate.** Same shape as `/spec`, for the same reason — the approach
   is the second-cheapest point in the pipeline to be wrong at:
   - Present a compact summary in chat: the approach in a sentence, the 2-4
     decisions being made, what's deliberately deferred.
   - Commit on a branch (`docs(plan): ...`) and open a PR titled `Plan: ...`
     whose body states "Merging this PR = approving the approach", links the
     spec, and lists the ADRs raised in step 5.
   - A plan asks James's opinion; it isn't finished work to critique. So it
     wears the **`proposal`** label, applied **at creation** — labelling
     afterwards works but only after a full agent review has already run
     (see /ship step 8):
     ```bash
     gh label create proposal -c "c5def7" \
       -d "opinion/spec/mockup PR — human review only, skip agent gate" --force
     gh pr create --title "Plan: ..." --body "..." --label proposal
     ```
   - STOP. Do not run `/split-spec`, file issues, or write implementation code
     until the plan PR is merged.
7. **Hand off.** Once merged, `/split-spec` reads the plan alongside the spec.

## Retirement

When the last issue traceable to this plan has merged:
1. Confirm every decision in the plan is either in an ADR or self-evident from
   the shipped code.
2. Confirm the spec's `Behavior` section reflects what was built (fold in any
   `Pending changes` delta — `/spec` step 4).
3. Delete `specs/<area>.plan.md` in the same PR as the last task, or in a small
   follow-up commit. Note the retirement in the PR body.

Do this when you notice it, not only when asked. A plan file older than the work
it describes is a bug.
