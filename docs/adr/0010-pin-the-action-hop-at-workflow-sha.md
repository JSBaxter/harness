---
status: accepted
supersedes: none
date: 2026-10-11
deciders: James
---

# 0010 — The reusable workflows check the harness out at their own commit; the action hop is pinned

## Context and problem statement

ADR 0006 pinned every project's caller stub to a harness commit SHA, with
Renovate opening the bumps, so a project's executable gate runs a known
harness commit. Its decision 3 left one hole: the reusable workflow's own
`uses:` of this repo's `setup-reviewer` action stayed at `@main`, because
this repo was private and the caller's `GITHUB_TOKEN` could not check it
out at the workflow's commit. That was accepted as a second hop carrying
prose only (the reviewer).

T11 (#61) added `setup-cell` on the same `@main` hop, and it delivers
`cellq`, an executable that writes issue state with the repo token. The hop
then carried executable CI unpinned, which is exactly what ADR 0006 set out
to end. Issue #63 recorded the options; James decided (2026-10-11) to make
the harness public, after a history scan found nothing secret in it, so the
hop can be pinned.

## Considered options

1. **Amend ADR 0006 decision 3 to accept `cellq` on the unpinned hop.**
   Rejected: a bad harness merge would reach every cell's next scope run
   with no bump PR in between.
2. **Pin the action `uses:` to a SHA inside the reusable workflow, tracked
   by Renovate.** Rejected: it is a second pin to keep in step with the
   first, and a harness PR could not test its own action without a
   two-commit dance.
3. **Make the harness public and check it out at `job.workflow_sha`.**
   `job.workflow_sha` is the commit of the workflow file that defines the
   current job, which in a reusable workflow is the called workflow's own
   commit, that is, the SHA the caller stub names. A local action reference
   (`uses: ./path`) inside a called workflow resolves against the caller's
   workspace, so a checkout of this repo under the workspace makes
   `uses: ./.harness/.github/actions/<name>` run that commit's action.
4. **A PAT per project.** Rejected by ADR 0006 already; a per-repo manual
   secret is on the design's never-list.

## Decision

We will adopt option 3. This replaces decision 3 of ADR 0006 only; the rest
of ADR 0006 (caller stubs pin to a SHA, Renovate bumps, skills unpinned,
the fixture-cell CI) stands.

1. **Every reusable workflow that uses a harness action checks the harness
   out first**, with `actions/checkout` pinned to a full SHA, at
   `repository: JSBaxter/harness`, `ref: ${{ job.workflow_sha }}`,
   `path: .harness`, and then runs the action as
   `uses: ./.harness/.github/actions/<name>`. The action's scripts find the
   plugin through `$GITHUB_ACTION_PATH/../../../plugins/...`, which
   resolves inside `.harness/` unchanged. Today that is `claude-review.yml`
   (`setup-reviewer`) and `cell-scope.yml` (`setup-cell`); the converge and
   ceremony workflows follow the same shape when they land.
2. **`.harness/` is removed as soon as the action has run**, and always
   before any step that could commit or push (today the fixer in the review
   gate; a sync workflow's `create-pull-request`, should one ever use a
   harness action), so the checkout can never reach a project's branch.
3. **The harness repository is public.** The Actions access-level setting
   on this repository (`actions/permissions/access`, set to `user`), which
   the `new-experiment` skill had every new machine apply so that a private
   harness could be referenced from other repositories' workflows, is no
   longer needed and no longer applied.

   > **Note (2026-10-12):** the multi-identity mechanism described here was
   > removed as unused (ADR 0011). One GitHub identity applies.

## Consequences

- The whole executable path of a project's gate and cell workflows now runs
  one harness commit: the stub's SHA selects the reusable workflow, and the
  reusable workflow selects its own actions, reviewer, skills and `cellq`
  from the same commit. One bump PR moves all of it.
- A harness PR tests its own actions: a stub that calls a workflow at a
  branch runs that branch's actions, with no `@main` lag.
- One extra checkout per run (a few seconds; the harness is small).
- Nothing in the harness may be secret from now on. Identities, tokens and
  anything stealth-scoped stay outside this repository, as they already do.
  > **Note (2026-10-12):** the multi-identity mechanism described here was
  > removed as unused (ADR 0011). One GitHub identity applies.
- The `cell-scope.yml` step comment that recorded the `@main` exposure is
  gone. ADR 0006's decision 3 keeps its text, as superseded decisions do,
  and carries a dated note pointing here.
- Verified on harness-test-drive before merge (run 38173205055, probe job
  114569994186): in a called workflow `job.workflow_sha` was the harness
  branch head, the checkout landed at exactly that SHA, both actions ran as
  `./.harness/.github/actions/<name>`, the delivered `cellq` and reviewer
  were byte-identical to that commit's copies, and `rm -rf .harness` left
  the workspace clean.
