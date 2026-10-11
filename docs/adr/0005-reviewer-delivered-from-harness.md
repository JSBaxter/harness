---
status: accepted
supersedes: none
date: 2026-09-04
deciders: James
---

# 0005 — The reviewer agent is delivered from the harness, not carried by projects

## Context and problem statement

The reviewer agent existed twice: `plugins/jsb-harness/agents/reviewer.md`
(used by `/ship` locally, via the plugin) and
`templates/project/.claude/agents/reviewer.md` (copied into every project,
because GitHub Actions cannot load a plugin).

The two were **never identical**. Both were created in the same commit
(`57b2776`, the original scaffold) and neither was edited afterwards, so this
was not drift — it was a copy-paste divergence present from day one, with no
event that would ever surface it. The template copy told the reviewer:

> A reviewer prompted to find gaps will always find some — findings must be
> defects, not improvements.

The plugin copy did not. So the CI reviewer was told to resist inventing
findings and the local `/ship` reviewer was not, and nobody knew.

The obvious fix — a CI check asserting the two match — treats the symptom. The
question underneath is why two copies exist, and the answer had been assumed
rather than tested: Actions can't load plugins, and a project's `GITHUB_TOKEN`
cannot read the private harness, so the file "had to" be vendored.

**That assumption was wrong.** A probe (harness-test-drive run 33906265369)
established that a composite action hosted in the private harness has its
**entire repository** fetched onto the runner, and can copy any file from it
into the calling repo's workspace — using only the `access_level: user` setting
that already makes the reusable workflow resolve. No token, no PAT.

## Considered options

1. **Consistency check** — CI asserts the two copies match. Fixes this
   instance, keeps the duplication, and the check is one more thing to maintain.
2. **Deliver at run time** — one copy in the harness; the gate writes it into
   the workspace before reviewing.
3. **Deliver, with a project opt-out** — as (2), but a project may replace the
   reviewer by committing a distinctly-named override file.
4. **Do nothing** — accept the divergence.

## Decision

Adopt **option 3**.

- **One canonical reviewer**, at `plugins/jsb-harness/agents/reviewer.md`. It
  serves `/ship` locally through the plugin and CI through the action. The
  template copy is deleted; project repos carry no reviewer at all.
- **`.github/actions/setup-reviewer`** (composite) delivers it into the
  workspace and outputs the agent name to spawn. The reusable workflow calls it
  after checkout and interpolates that name into the fixer's prompt.
- **A project opts out** by committing `.claude/agents/reviewer-override.md`.
  When present, the harness default is *not* written — one reviewer on disk,
  matching what the repo declares.

Two details are load-bearing:

- **The override has a distinct filename.** Had it kept the name
  `reviewer.md`, a deliberate customisation would be indistinguishable from a
  stale vendored copy — the exact ambiguity this ADR exists to remove. Its
  existence is therefore an unambiguous declaration of intent.
- **The run logs which reviewer was used.** Presence of the override proves
  *intent*, not *selection*: if the pick logic were wrong, the file would sit
  there looking authoritative while the default quietly ran. The log line is
  the only thing that closes that gap, so it is not decoration.

The gate's self-skip rule now keys on `reviewer-override.md` rather than
`reviewer.md`, since projects no longer carry the latter.

## Consequences

- **Positive:** the duplication is gone rather than policed. A reviewer
  improvement reaches every repo on its next PR, with nothing to sync and no
  consistency check to maintain. New projects carry one fewer file.
- **An override reintroduces drift deliberately.** It is a copy plus edits and
  stops tracking harness improvements silently. That is the price of opting
  out; the template's CLAUDE.md says so where someone will read it.
- **Most customisations are probably additive, not replacements** — "the
  standard reviewer, plus flag musical errors" rather than a different
  reviewer. A full override forces copying the whole file to add a line, and
  that copy rots. If this bites, add an *addendum* file alongside the override
  rather than reworking it. Nothing here forecloses that.
- **Blast radius, and `v1`.** The action is pinned `@main`, so a bad harness
  push changes review behaviour in every repo immediately — the same argument
  ADR 0003 decision 2 makes for the workflow. Cutting `v1` and retargeting both
  the workflow stub and this action is now more pressing than it was.

  > **Note (2026-10-11):** no longer true. The stub pins a commit SHA (ADR
  > 0006) and the workflow runs this action from a checkout of the harness
  > at its own commit (ADR 0010), so the action is pinned to the same SHA.
- **Existing repos** (`chord-recommender`, `harness-test-drive`) carry a
  now-dead `reviewer.md`: still in git, ignored at review time. Both are
  byte-identical to the old template — neither had customised it — so they are
  deleted in follow-up PRs rather than converted to overrides.
- **Not verified end to end.** The delivery mechanism is proven by probe; this
  wiring is validated by parsing only. The first real PR in a gated repo is the
  test, and the step summary will name which reviewer ran.
- **Revisit trigger:** if a project ever needs a reviewer that is neither the
  default nor a full replacement, that is the signal to add the addendum file.

## Alternatives considered

- **Consistency check between the two copies** — polices a duplication instead
  of removing it, and would not have prevented the original divergence, which
  was present from the first commit.
- **Always overwrite, no opt-out** — simpler, and no project has customised the
  reviewer today. Rejected because silently clobbering a deliberate
  customisation is a nasty failure, and the opt-out costs one `if`.
- **Override keeping the `reviewer.md` name** — see above; makes intent and
  leftovers indistinguishable.
