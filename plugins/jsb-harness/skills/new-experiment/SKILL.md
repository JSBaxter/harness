---
name: new-experiment
description: Spin up an isolated scratch repo from the project template so an idea can be tried without polluting the dev environment. Creates the GitHub repo, applies branch protection, installs the review workflow.
---

# New experiment

Create an isolated scratch repository for trying out an idea.

Arguments: `<name>` (kebab-case repo name), optional one-line description,
optional `--identity <id>` (default: `primary`).

## Identity

Read `~/.claude/identities.local.json`. All `gh` commands below run as
`gh-as <identity> ...`, and the clone lands inside that identity's directory
tree — for `primary` that's `~/Documents/repos/scratch/<name>`, for any other
identity it's `<identity-dir>/scratch/<name>`. Never create a repo for a
non-primary identity outside its tree: the git includeIf identity swap and the
identity-guard hook are directory-scoped. The template repo lives on the
primary account; for non-primary identities don't use `--template` (it would
link the accounts) — instead copy the template *contents* from the local
harness checkout (`templates/project/`) into a fresh repo.

## Steps

1. Confirm the name doesn't already exist: `gh-as <identity> repo view <owner>/<name>` should fail.
2. Create the repo (private by default):
   - primary: `gh-as primary repo create <name> --template <owner>/project-template --private --clone`
   - other identities: `mkdir` in the identity tree, copy `templates/project/`
     contents from the harness checkout, `git init`, then
     `gh-as <identity> repo create <ghUser>/<name> --private --source . --push`
   Create the `scratch/` directory if missing.
   After cloning/creating, verify `git config user.email` matches the
   identity's email before the first commit — abort loudly if not.
   If the template repo doesn't exist yet, say so and offer to create it from
   the harness repo's `templates/project/` directory instead of failing silently.
3. Personalize BEFORE protecting: fill in the templated files (project name in
   `CLAUDE.md`, real test/lint commands, the description in `README.md`, an
   initial spec stub in `specs/` if the user described the idea), commit, and
   push to main. This must happen before the ruleset lands — the ruleset
   requires PRs for main with no admin bypass, so a later direct push would
   block (by design).
4. Enable branch auto-delete — REQUIRED for stacked PRs to retarget on merge:
   ```bash
   gh-as <identity> repo edit <owner>/<name> --delete-branch-on-merge
   ```
   Also create the `proposal` label — proposal/spec/mockup PRs wear it to skip
   the agent review gate (finished work only is reviewed):
   ```bash
   gh-as <identity> label create proposal -c "c5def7" \
     -d "opinion/spec/mockup PR — human review only, skip agent gate" --force
   ```
5. Apply the branch-protection ruleset (personal accounts can't use org rulesets):
   ```bash
   gh-as <identity> api repos/<owner>/<name>/rulesets --method POST \
     --input <harness-repo>/templates/ruleset.json
   ```
5. Add the `CLAUDE_CODE_OAUTH_TOKEN` secret so the review workflow can run
   (the token is Anthropic-side auth — the same one works for every identity):
   ```bash
   gh-as <identity> secret set CLAUDE_CODE_OAUTH_TOKEN --repo <owner>/<name> \
     < ~/.claude/claude-code-oauth-token
   ```
   The token file is created once per machine by the user
   (`claude setup-token`, saved to `~/.claude/claude-code-oauth-token`,
   mode 600). If the file is missing, tell the user to run `claude setup-token`
   and save it there — do not skip this step silently, and never echo the
   token into logs or chat.
5. Fill in the templated files: project name in `CLAUDE.md`, the description in
   `README.md`, and an initial spec stub in `specs/` if the user described the idea.
   - **Review workflow** — the template's `.github/workflows/claude-review.yml`
     is a thin caller of the harness reusable workflow (see harness ADR 0001).
     It needs the harness repo's Actions access set to `user` once per machine/
     account: `gh api -X PUT repos/JSBaxter/harness/actions/permissions/access
     -f access_level=user` (harmless to re-run).
   - **Stealth repos only:** the stub names `JSBaxter/harness`, which would link
     the accounts — a stealth repo must NOT use it. Replace the stub with a
     self-contained copy of the gate: take the harness reusable workflow, change
     `on: workflow_call` to the `pull_request` trigger block from the primary
     stub (with `types` and the concurrency group), and inline it. Accept the
     drift on those few repos.
6. Commit and push the personalization, then report: repo URL, local path, and
   what protection/workflow is active.

## Conventions

- Scratch repos are disposable. Note the creation date in the README so stale
  ones are easy to cull later.
- If the experiment graduates, its repo moves out of `scratch/` — don't build
  load-bearing things in `scratch/` paths.
