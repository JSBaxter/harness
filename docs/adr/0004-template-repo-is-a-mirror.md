# 0004 — The template repo is a CI-maintained mirror, not a repo you edit

- Status: proposed
- Date: 2026-09-02
- Deciders: James

## Context and problem statement

ADR 0001 solved drift for the *executing* half of the project template by making
the review gate a reusable workflow, and explicitly left the rest open: "non-
executing per-repo files (`CLAUDE.md`, etc.) still drift; a future
`/sync-template` skill can roll those forward deliberately. Low-stakes because
they don't run."

That assessment turned out to be wrong twice over, and the evidence is recent.
`JSBaxter/project-template` was found months behind `templates/project/`, and
the gap was not limited to prose:

- It still shipped the **pre-ADR-0001 monolithic `claude-review.yml`**. Every
  repo `/new-experiment` scaffolded therefore received a frozen copy of the
  review logic — the precise drift ADR 0001 exists to prevent, reproducing the
  `chord-recommender` failure described in that ADR's own context.
- That copy lacked the `labeled, unlabeled` triggers, so applying the
  `proposal` label neither re-ran the gate nor flipped its verdict. `proposal`
  was **inert in every scaffolded repo**, silently breaking `/spec` (and `/plan`
  on first use): an opinion PR would be agent-reviewed as production code, with
  each fix spawning another round.
- `.claude/skills/steward/` was absent, and `CLAUDE.md` was missing three ground
  rules.

So the files did run, the stakes were not low, and — the part that matters for
this decision — **nobody noticed for months.** The failure mode is silence, not
error. A `/sync-template` skill only helps someone who remembers to run it, and
the whole history here is of no one remembering.

## Considered options

1. **`/sync-template` skill**, run by hand when template contents change. The
   option ADR 0001 anticipated.
2. **CI sync on push**, opening a PR against the template repo.
3. **Make the template repo the source of truth** and have the harness read from
   it, inverting the direction.
4. **Drop the template repo**, and have `/new-experiment` always copy from a
   local harness checkout. `/new-experiment` already contains this code path —
   it is the non-primary-identity branch — so this is cheaper than it looks.

Option 1 is rejected on the evidence above: it addresses a memory problem with a
thing you have to remember. Option 3 splits the harness across two repos and
puts template contents outside the review and ADR flow that governs everything
else here. Option 4 deletes the drift surface entirely and is genuinely tempting on
today's usage, since the copy path already exists. It is rejected on where this
is going rather than where it is: **the template repo is the only way to create
a project without a local harness checkout.** GitHub's "Use this template"
button is the checkout-free path, and creating projects from a phone — and
later, letting agents create them — is a stated goal. Option 4 forecloses it.

That reframes what the mirror is for. Keeping the template current is not
housekeeping on a convenience; it is what makes checkout-free project creation
safe. An unmaintained template repo is worse than no template repo: every
project created from it starts silently stale, which is the exact defect this
ADR is a response to.

## Decision

Adopt **option 2**, with the mirror relationship stated explicitly.

**`JSBaxter/project-template` is a pure mirror of `templates/project/`.** The
harness is the only place template contents are edited. A change made directly
in the template repo is not a change — it will be reverted by the next sync.

`.github/workflows/sync-template.yml` mirrors the directory on every push to
`main` that touches `templates/project/**`, plus weekly and on demand. Three
properties of it are deliberate:

- **It opens a PR; it never pushes to the template repo's `main`.** Merging
  stays a human act, consistent with the rest of the harness, and the PR is
  where an unintended deletion gets caught.
- **The sync is `rsync --delete`.** A file removed from `templates/project/` is
  removed in the template repo too. Without this, deletions never propagate and
  the template accretes files forever — a slower version of the same drift.
- **The weekly schedule is not redundant with the push trigger.** A
  path-triggered sync cannot see edits made directly in the template repo; the
  schedule is what catches those and re-asserts the mirror.

It requires a cross-repo `TEMPLATE_SYNC_TOKEN` secret, because a repo's own
`GITHUB_TOKEN` cannot write elsewhere. The workflow **fails loudly** when it is
absent rather than skipping: a sync that quietly stops running would recreate
the exact condition this ADR exists to end.

## Consequences

- **Positive:** template drift becomes a merge decision instead of an
  unobserved condition. The window between a harness template change and every
  future scaffolded repo receiving it closes to one PR review.
- **Hand-edits to the template repo are now destructive to themselves.** Someone
  will eventually make one and be surprised when it vanishes. That surprise is
  the cost of a single source of truth, and the PR body says so.
- **A new secret to hold and rotate.** If the PAT expires the workflow fails
  rather than no-ops, and a failing scheduled workflow is visible in Actions and
  emailed to the owner — so expiry surfaces as a failure, not as silence.
- **Existing scaffolded repos are not reached by any of this.** The mirror fixes
  what *new* repos inherit; repos already created still carry whatever they were
  given. Rolling a template change into live repos remains manual, and for
  workflow files it needs the README's disable-ruleset recipe.
- **Interacts with ADR 0003:** the stub the mirror ships is pinned `@main`
  today. When `v1` is cut, retargeting it is a one-line change here that reaches
  every future repo automatically — one of the first real payoffs of the mirror.
- **Not sufficient for phone/agent creation on its own.** "Use this template"
  produces a repo with `CLAUDE.md` placeholders unfilled, no ruleset, no
  `proposal` label and no OAuth token secret — everything `/new-experiment`
  steps 3-5 do. The mirror makes the *contents* trustworthy; making the rest
  work without a local checkout is separate, unbuilt work.
- **Revisit trigger:** if the template repo ever needs content that legitimately
  should not live in the harness, the pure-mirror model breaks. Move to an
  exclude list or a merge-based sync then — do not start hand-editing and hoping
  the sync leaves it alone. Note that "just delete the template repo" is *not*
  the escape hatch: it would remove checkout-free creation, so anything that
  makes the mirror painful should be solved inside the mirror.

## Alternatives considered

- **`/sync-template` skill** — see above; a memory fix for a memory problem.
- **Keep the template repo but stop depending on it** — tempting middle ground,
  but it does not survive the phone-creation goal: an unused template is an
  unmaintained one, and the button is still there for someone to press.
- **Auto-merging the sync PR** — removes the human check that catches a bad
  `--delete`, for a saving of one click on a repo that changes rarely.
- **A PR per sync instead of one long-lived branch** — spawns a PR per push to
  a repo nobody watches closely. One force-updated `sync/template` branch keeps
  a single open PR that always shows current drift.
