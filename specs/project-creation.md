# Project creation

Status: draft

## Purpose

Create a fully-configured harness project **without a local harness checkout** —
from a phone, or by an agent — so that starting a project isn't gated on being at
a desk.

Today `/new-experiment` is local-only by construction, not by policy: it reads
`templates/ruleset.json` and `~/.claude/claude-code-oauth-token` off disk, and
copies template contents from the harness working tree. The execution-routing
table in the README puts it in the Local column for that reason.

## Behavior

### Two phases, separately triggerable

- **Create** — a repo comes into existence from `JSBaxter/project-template` by any
  checkout-free means: the GitHub web "Use this template" button, `gh repo create
  --template`, or the REST API. This phase needs no agent and no local machine.
- **Initialise** — an agent session running *in* the new repo brings it to the
  state `/new-experiment` produces today. This phase needs an agent but no local
  checkout.

A repo between the two phases is **uninitialised**, and says so plainly enough
that a human or an agent arriving later can tell without inspecting settings.

### Direction of data flow

Projects and the template **pull** from the harness. The harness never pushes
into a project or into the template repo. This is what removes the need for a
cross-repo credential.

### `/init-project`

Run inside a freshly created repo. It:

1. Detects whether the repo is uninitialised, and on an already-initialised repo
   reports that and stops. Running it twice is a no-op.
2. Resolves scaffolding from `JSBaxter/harness` **at run time** — live `main`,
   never a vendored copy — so a repo initialised today matches the harness today.
3. Fills the placeholders: project name in `CLAUDE.md` and `README.md`, the test
   and lint commands, the one-line description, and an initial spec stub in
   `specs/` when the user described the idea.
4. Applies repo settings: `--delete-branch-on-merge`, the `proposal` label, and
   the branch-protection ruleset from `templates/ruleset.json`.
5. Sets `CLAUDE_CODE_OAUTH_TOKEN` so the review gate can run.
6. Pushes the personalisation to `main` **before** the ruleset lands. The ruleset
   requires PRs for `main` with no admin bypass, so a later direct push is
   blocked by design.
7. Reports every step it could not complete, naming the exact command a human
   needs to run, and never skips one silently.

## Acceptance criteria

- Creating a repo from the template on github.com, then running `/init-project`
  in a cloud session with `JSBaxter/harness` attached, yields a repo
  indistinguishable from one `/new-experiment` produces locally. Verified by
  comparing tracked file contents, `gh api repos/<owner>/<repo>/rulesets`,
  `gh label list`, and the presence of `CLAUDE_CODE_OAUTH_TOKEN`.
- Running `/init-project` a second time changes no tracked file and reports the
  repo as already initialised.
- With the OAuth secret deliberately unavailable, `/init-project` completes every
  other step, leaves the repo usable, and reports the secret as outstanding with
  the command to set it. It does not leave the repo half-protected.
- No credential belonging to the harness is stored in any other repository.
- A repo created from the template but never initialised is identifiable as such
  by an agent reading only the repo.

## Non-goals

- **Rolling template changes into already-created repos.** Different problem
  (`copier update` territory); worth its own spec.
- **Removing the template repo.** It is the checkout-free creation path.
- **Fixing the upstream plugin auto-install gap.** This spec works within it.
- **Checkout-free stealth-identity creation.** A stealth repo must not name
  `JSBaxter/harness` in a workflow stub, so it needs a different flow.
- **Replacing the review gate or the ruleset.**

## Constraints (probed 2026-09-03 from a cloud session)

Measured against `JSBaxter/harness-test-drive` through the agent proxy. `gh` is
absent from cloud containers, but `GH_TOKEN` is set and the proxy injects auth,
so plain `curl` against `api.github.com` is authenticated — the tool surface is
not the limit; the proxy's allowlist is.

| Operation | Result |
|---|---|
| Read repo settings, rulesets, labels | 200 |
| Create and delete a label | 201 / 204 |
| Write repo settings (`PATCH /repos/…`) | **403** — "Repository settings writes are not permitted through this proxy" |
| Any Actions path (secrets, secrets public-key) | **403** — "Access to this GitHub Actions path is not permitted through this proxy" |
| Create a ruleset (`POST /rulesets`) | untested |
| Delete a git ref (branch) — push or REST | **403** — "Write access to this GitHub API path is not permitted through this proxy" |

And from inside a workflow in the repo itself (`harness-test-drive`, `GITHUB_TOKEN`):

| Operation | Result |
|---|---|
| Read repo | 200 |
| `PATCH /repos` (`delete_branch_on_merge`) | **403** — "Resource not accessible by integration" |
| `POST /rulesets` | **403** — "Resource not accessible by integration" |
| `GET /actions/secrets/public-key` | **403** — "Resource not accessible by integration" |

`administration` is **not a valid workflow `permissions` scope**: declaring it
makes the workflow file invalid, and the run fails before any job starts. So
there is no way to elevate a workflow's own token to do repo admin.

What follows from that:

- **All three setup steps need a credential nothing automatable has.** The
  ruleset, `delete_branch_on_merge` and the OAuth secret are refused to a cloud
  session (proxy) *and* to an in-repo workflow (integration token). With a
  cross-repo PAT ruled out, they require a session holding the user's own
  GitHub credentials — i.e. a local one.
- **The OAuth secret is structurally manual.** `CLAUDE_CODE_OAUTH_TOKEN` cannot
  be written from a cloud session, its value cannot be read back from anywhere,
  a cross-repo PAT is ruled out, and a personal account has no organisation to
  hold an org secret. `secrets: inherit` passes the *caller's* secrets, so the
  harness cannot supply it on a project's behalf either. One manual secret-set
  per repo is therefore part of the design, not a defect in it.
- **`--delete-branch-on-merge` is equally unreachable** from a cloud session.
- **Labels are reachable**, so the `proposal` label needs no human.

This narrows the honest promise from "start a project from your phone" to
"start a project from your phone, and finish two admin steps once". Whether
that is worth building is the question the plan has to answer, not assume.

## Unknowns to settle before /plan

1. **Does `POST /rulesets` pass the proxy from a cloud session?** Reads do;
   repo-settings writes do not. Untested — the probe was blocked locally, not by
   GitHub. Low value now: even if it passes, the other two steps do not.
2. **What triggers the initialise phase** — a cloud session the human opens, a
   Routine watching for new repos, or a workflow committed in the template that
   runs once on first push. The probe rules the third option out for the admin
   steps, but it can still do file personalisation.
3. **How much the template still needs to carry.** The copies exist because
   plugins do not auto-install in cloud/headless sessions and Actions has no
   plugin at all. `CLAUDE_CODE_PLUGIN_SEED_DIR` (documented, untested) may close
   the first half; the Actions half likely stays.
4. **Whether `/new-experiment` becomes a thin wrapper** (create, then invoke the
   same initialise path) or stays a separate local flow. Two implementations of
   repo setup is the outcome to avoid either way.

## Decisions

- [[docs/adr/0004-template-repo-is-a-mirror.md]] — the template repo is a
  CI-maintained mirror. If this spec lands, the mirror may become unnecessary:
  a bootstrap-sized template that rarely changes needs little syncing. That ADR
  would then be superseded by a new one, not edited.
- [[docs/adr/0003-harness-distribution-pinning.md]] — skills auto-update,
  executable CI is versioned. `/init-project` pulling live from `main` is the
  same principle applied to scaffolding.
