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
3. Apply the branch-protection ruleset (personal accounts can't use org rulesets):
   ```bash
   gh-as <identity> api repos/<owner>/<name>/rulesets --method POST \
     --input <harness-repo>/templates/project/ruleset.json
   ```
4. Add the `CLAUDE_CODE_OAUTH_TOKEN` secret so the review workflow can run
   (the token is Anthropic-side auth — the same one works for every identity):
   ```bash
   gh-as <identity> secret set CLAUDE_CODE_OAUTH_TOKEN --repo <owner>/<name> --body "$(claude setup-token 2>/dev/null || true)"
   ```
   If `claude setup-token` requires interaction, tell the user to run it
   themselves and set the secret manually — do not skip this silently.
5. Fill in the templated files: project name in `CLAUDE.md`, the description in
   `README.md`, and an initial spec stub in `specs/` if the user described the idea.
6. Commit and push the personalization, then report: repo URL, local path, and
   what protection/workflow is active.

## Conventions

- Scratch repos are disposable. Note the creation date in the README so stale
  ones are easy to cull later.
- If the experiment graduates, its repo moves out of `scratch/` — don't build
  load-bearing things in `scratch/` paths.
