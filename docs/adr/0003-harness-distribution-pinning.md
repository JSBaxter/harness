# 0003 — Skills auto-update, executable CI is versioned

- Status: accepted
- Date: 2026-09-02
- Supersedes: none
- Deciders: James

## Context and problem statement

ADR 0001 made the review gate a reusable workflow and deliberately left the pin
open: "`@main` is zero-maintenance but a bad harness push breaks every repo's
gate at once. A moving `v1` tag or SHA pin trades that for controlled rollout;
the stub documents the knob. Starting on `@main`." That deferral has now expired,
and looking at the whole distribution surface rather than just the gate makes the
question sharper than it was.

Three channels carry harness changes into projects, and they are pinned
inconsistently and by accident rather than by decision:

- **Skills** — `templates/project/.claude/settings.json` names
  `JSBaxter/harness` with **no ref at all**, so projects track the default
  branch. Unpinned.
- **The review gate** — the caller stub uses
  `JSBaxter/harness/.github/workflows/claude-review.yml@main`. Unpinned.
- **The fix workflow** — `claude-fix.yml` is not a caller at all. It invokes
  `anthropics/claude-code-action@v1` directly and is **copied** into each repo at
  scaffold time, so harness improvements to it reach existing projects *never*.
  This is the drift ADR 0001 set out to eliminate, still present in the one
  workflow that ADR didn't cover.

Separately, this repo has no caller stub of its own, so PRs against
`JSBaxter/harness` receive no agent review. Skills are the most widely
propagated artifacts in the system and the only ones with no gate in front of
them.

Net: **there is neither prevention nor containment.** Nothing reviews a harness
change before it merges, and nothing limits its blast radius afterwards. Those
are the two available answers to the same question, and the system currently has
neither.

The constraint that decides the shape of the answer: the harness is patched
frequently, in response to defects that live projects surface. That is the
system working as intended, and it is the property to protect — a fix found in
one project must reach the others without per-project work.

## Considered options

1. **Full versioning: semver the harness, projects pin and bump.** Maximum
   control, and the conventional answer.
2. **Status quo** — everything on the tip, no gate.
3. **Asymmetric**: unpinned skills, versioned executable CI, review gate at the
   source.
4. **Vendor everything per repo.** Already rejected by ADR 0001; listed only
   because `claude-fix.yml` is currently in this state by omission.

Option 1 is rejected on the constraint above. Pinning is right when consumers
need stability more than fixes; here it inverts the property that makes the
harness useful. Every patch would become *fix harness → cut version → bump N
projects*, a tax that scales with patch frequency — and patch frequency is high
by design. A tax that size gets skipped, and skipped bumps rot into stale pins,
which is drift wearing a different hat.

## Decision

Adopt **option 3**, differentiating by blast radius and reversal cost rather
than treating "the harness" as one versioned thing.

**1. Skills auto-update, and are never pinned.** The marketplace pointer stays
ref-less. A bad skill is markdown: it degrades an agent's instructions, shows up
in the next PR, and is reverted with one commit that every session picks up
immediately. Low severity, fast reversal, and instant fix propagation is the
entire point. This is a decision, not an oversight — do not add a ref here.

**2. The reusable review workflow moves to a moving `v1` tag.** Push to `main`
freely; move `v1` once a change has been observed working. Project stubs use
`@v1` and therefore never need bumping — the per-project cost stays zero, which
is why this survives contact with the real workflow. Unlike a skill, a broken
gate is executable CI behind a *required* status: it does not degrade anything,
it wedges every project's PRs at once, and recovery is expensive (see the README
deadlock recipe — a workflow change in a gated repo needs the ruleset disabled
and re-enabled by hand).

**3. `claude-fix.yml` becomes reusable on the same terms.** Reusable core here
(`on: workflow_call`), thin caller stub in `templates/project/`, pinned `@v1`
alongside the gate. It is executable CI with the same blast radius as the review
gate, and today it is strictly worse off than a stale pin: it receives no fixes
at all.

**4. This repo gets a caller stub, pinned `@main`, so harness PRs are agent
reviewed.** The `@main` pin is deliberate and load-bearing: it makes the harness
repo the canary that earns `v1` its next move. Harness PRs exercise the tip;
projects only see what the tip survived.

Its limit must be recorded, because it is not obvious. A reusable-workflow
`uses:` takes a literal ref, so a harness PR that changes the reusable core is
reviewed by `main`'s copy of the gate, not by the version in the PR. **Changes
to the gate are not self-tested, by construction.** That blind spot is precisely
what the `v1` staging step in (2) covers, which is why (2) and (4) are
complementary rather than alternatives: the gate covers content and judgment,
`v1` covers runtime breakage that no reviewer reliably catches by reading a diff.

**5. `plugins/jsb-harness/plugin.json`'s `version` field is display metadata, not
a resolution target.** Nothing resolves against it — `enabledPlugins` keys are
`plugin@marketplace`, not `plugin@version`. It stays for schema/display
purposes; bumping it means nothing and gates nothing. Recorded here because a
version number sitting next to an unpinned distribution channel reads as an
oversight, and the next agent to notice will try to wire it up.

## Consequences

- **Positive:** every layer gets the protection matched to its failure mode. A
  bad skill is caught by review before merge; a bad workflow is caught on the
  harness repo before `v1` moves; projects get skill fixes instantly and CI
  changes only once vetted. The `claude-fix.yml` drift hole closes.
- **New recurring cost: exactly one manual step** — moving `v1` after a gate
  change proves out. That is the only ongoing tax this ADR introduces, and it is
  per-change, not per-project.
- **Migration is not free.** Retargeting an *existing* gated repo's stub from
  `@main` to `@v1` is a workflow-file change in a repo whose ruleset blocks
  direct pushes to main, so each one needs the disable-ruleset recipe from the
  README. New repos get it from the template for free. Budget for the dance
  once per existing repo.
- **The canary is a single repo.** A workflow change that breaks only under
  conditions this repo doesn't exercise — proposal labels, screenshot embedding,
  the fixer path — will move `v1` on incomplete evidence. Accepted: the
  alternative is per-project pins, and the failure is one repo's gate wedged
  rather than all of them.
- **Gate changes remain the weak spot**, per decision 4. Treat a PR that touches
  `claude-review.yml` as unreviewed by construction and give it human eyes.
- **Not covered:** stealth-identity repos keep self-contained copies of both
  workflows (ADR 0001) and gain nothing from `v1`. They accept drift by design.
- **Revisit trigger:** if moving `v1` gets skipped in practice and the tag drifts
  far behind `main`, it isn't earning its keep — collapse back to `@main` and
  rely on the gate alone rather than keeping a ceremony nobody performs.

## Alternatives considered

- **Semver with per-project pins** — see above; the per-fix tax scales with
  patch frequency, and skipped bumps become drift.
- **SHA pins instead of a moving tag** — same tax as semver with worse
  ergonomics; no upside here, since the point is controlled rollout rather than
  reproducibility.
- **Gate the harness with `@v1` instead of `@main`** — safer for this repo's own
  PRs, but it removes the canary: nothing would then exercise the tip before
  `v1` moves, and `v1` would advance on no evidence at all.
- **No harness gate, rely on `v1` alone** — containment without prevention.
  Leaves skills, the highest-leverage and most-changed artifacts, reviewed by
  nobody.
