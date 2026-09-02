# 0002 — Don't adopt GitHub Spec Kit; add a `/plan` phase instead

- Status: proposed
- Date: 2026-09-02
- Deciders: James

## Context and problem statement

GitHub's [Spec Kit](https://github.com/github/spec-kit) reached 1.0.0 and covers
visibly the same ground as this harness: a spec-driven chain of
`constitution → specify → clarify → plan → tasks → analyze → implement →
converge`, installed per-repo by a `uv`-installed `specify` CLI that writes
`.specify/` scaffolding plus generated agent command files, with specs landing
in `specs/NNN-shortname/{spec.md, plan.md, tasks.md, checklists/}`.

The overlap is real enough that a future agent will find it, notice that it
duplicates `/spec`, `/split-spec` and `/dispatch`, and try to "consolidate" onto
the better-known tool. This ADR exists so that decision has to argue with a
written record instead of happening by default.

Evaluating it also exposed a genuine hole in our pipeline. We go spec (what and
why) → `/split-spec` (task list) → `/dispatch`. Nothing in between captures the
**technical approach** — stack, module boundaries, contracts, data shapes. That
choice still gets made; it just gets made implicitly by whichever agent picks up
the first issue, and is only recorded if someone remembers to run `/adr`
afterwards. Spec Kit's `plan` phase names the gap even though its
implementation of it doesn't suit us.

## Considered options

1. **Adopt Spec Kit wholesale**, retire `/spec`, `/split-spec` and `/dispatch`,
   keep only the review gate.
2. **Adopt the front half** (`specify` + `plan` + `tasks`), keep `/ship` and the
   Actions gate behind it.
3. **Don't adopt; borrow the missing phase.** Add `/plan` in our own idiom,
   leave the rest alone.
4. **Do nothing** — accept that technical approach is decided ad hoc at
   implementation time.

## Decision

Adopt **option 3**. We will not install Spec Kit in harness projects. We will add
a `/plan` skill, sitting between `/spec` and `/split-spec`.

Four properties of this harness are load-bearing and each is incompatible with
Spec Kit as shipped:

- **Living specs beat per-feature specs.** Spec Kit writes one spec per feature
  into a numbered directory, and its most-reported failure mode in the field is
  drift — those documents don't self-update during implementation, and
  contradictions accumulate across them. Our specs are one-per-capability-area
  with changes written as deltas under `Pending changes` and folded into
  `Behavior` when they land; history is delegated to git and ADRs. We already
  pay the maintenance cost that keeps this from rotting, and adopting Spec Kit
  would trade a solved problem for an unsolved one.
- **The human gate is structural, not conversational.** A spec is a proposal
  until James merges its PR, and `/split-spec` step 0 refuses to decompose a spec
  that differs from `main`. Spec Kit's chain is designed to run agent-continuous
  from `specify` through `implement`; its `clarify` step asks up to three
  in-session questions and produces no durable approval artifact. The gate exists
  because of residual-stream-viz — a technically excellent implementation of the
  wrong thing — and nothing in Spec Kit's flow would have caught it.
- **The unit of work is one PR.** Spec Kit emits `T001`-style items grouped into
  user-story phases inside a single `tasks.md`, then `/implement` executes that
  file in one agent run. Our unit is one task = one issue = one PR = under ten
  minutes of review, roughly ≤400 diff lines and ≤5 files, dispatched to separate
  agents in separate worktrees. Batch size is the quality lever the whole harness
  is built around; `implement` discards it.
- **Distribution is already solved once, and copies are the enemy.** Skills
  resolve from one source of truth — the marketplace pointer in
  `.claude/settings.json`, with cloud sessions following skills from
  `JSBaxter/harness` source. Spec Kit is a per-repo `uv tool install` that writes
  `.specify/` and committed command files into every project: a second,
  copy-based mechanism, in exactly the environment where we have already verified
  that installers don't work headlessly. Its maintainers also state that 1.0.0
  "is now just a number," prioritising adaptability over stability, so the
  templates will move underneath any repo that vendors them.

Spec Kit additionally stops at `implement`/`converge`: it has no PR, no review
gate, no status check and no human-feedback round, so even option 2 would have
left the expensive half of our pipeline untouched while replacing the cheap half
with something worse.

**What we take from it,** because these are good ideas independent of the tool:

- A **plan phase**, implemented as `/plan` (this ADR's deliverable). Unlike Spec
  Kit's `plan.md`, ours is explicitly ephemeral: it is retired when the issues it
  spawned have landed, and any decision worth remembering is promoted to an ADR
  first. A plan that outlives its implementation is the drift problem again.
- A **bounded clarification step** in `/spec` — at most three critical questions,
  each offered with options, before the spec PR opens. This strengthens the human
  gate rather than substituting for it. *(Not implemented by this ADR; follow-up.)*
- An explicit **spec quality checklist**: no implementation details, every
  requirement testable and unambiguous, success criteria measurable and
  technology-agnostic, at most three open `[NEEDS CLARIFICATION]` markers.
  *(Not implemented by this ADR; follow-up.)*

We take none of: the constitution (CLAUDE.md plus ADRs cover it, and ADRs have
supersede semantics a flat constitution file lacks), the `specify` CLI,
`.specify/`, `tasks`, `implement`, `converge`, or extensions/presets/bundles.

## Consequences

- **Positive:** the gap between "approved what" and "parallel task list" gets a
  named, gated artifact. Approach mistakes — the class ADRs exist to catch — are
  now caught before code instead of retro-recorded after it. `spec-splitter` gets
  a real basis for its parallelism map (module boundaries from the plan) rather
  than inferring likely-touched files from prose.
- **Cost:** one more gated PR on the path from idea to code. Mitigated by making
  `/plan` skippable by design: it runs only when there is a real choice to make,
  and `/split-spec` does not require a plan file to exist.
- **New drift surface, deliberately bounded:** `specs/<area>.plan.md` files are
  a second document class that can rot. The retirement step in `/plan` is what
  keeps that from happening, and it is the part most likely to be skipped in
  practice. If plan files start accumulating in a stale state, that is the signal
  to revisit this ADR rather than to add more process on top.
- **Revisit trigger:** if Spec Kit later grows a living-spec model, a durable
  approval gate, and PR-sized task emission, the calculus changes. Supersede this
  ADR rather than quietly installing the tool.
- **Not covered:** the `/spec` clarify step and quality checklist described above
  remain unimplemented. They are additive to `/spec` and independent of `/plan`.
