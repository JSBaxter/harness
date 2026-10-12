---
name: new-experiment
description: Spin up an isolated scratch repo from the project template so an idea can be tried without polluting the dev environment. Creates the GitHub repo, applies branch protection, installs the review workflow.
---

# New experiment

Create an isolated scratch repository for trying out an idea.

Arguments: `<name>` (kebab-case repo name), optional one-line description.

All `gh` commands below run as the one GitHub account `gh` is logged in to
(ADR 0011); the clone lands in `~/Documents/repos/scratch/<name>`.

## Steps

1. Confirm the name doesn't already exist: `gh repo view <owner>/<name>` should fail.
2. Create the repo (private by default), cloning into `scratch/`:
   `gh repo create <name> --template <owner>/project-template --private --clone`
   Create the `scratch/` directory if missing.
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
   gh repo edit <owner>/<name> --delete-branch-on-merge
   ```
   Also create the `proposal` label — proposal/spec/mockup PRs wear it to skip
   the agent review gate (finished work only is reviewed):
   ```bash
   gh label create proposal -c "c5def7" \
     -d "opinion/spec/mockup PR — human review only, skip agent gate" --force
   ```
5. Apply the branch-protection ruleset (personal accounts can't use org rulesets):
   ```bash
   gh api repos/<owner>/<name>/rulesets --method POST \
     --input <harness-repo>/templates/ruleset.json
   ```
5. Add the `CLAUDE_CODE_OAUTH_TOKEN` secret so the review workflow can run
   (the token is Anthropic-side auth, not a GitHub credential):
   ```bash
   gh secret set CLAUDE_CODE_OAUTH_TOKEN --repo <owner>/<name> \
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
     The harness is public, so no Actions access-level setting on it is
     needed for the stub to resolve (ADR 0010).
6. Commit and push the personalization, then report: repo URL, local path, and
   what protection/workflow is active.

## Conventions

- Scratch repos are disposable. Note the creation date in the README so stale
  ones are easy to cull later.
- If the experiment graduates, its repo moves out of `scratch/` — don't build
  load-bearing things in `scratch/` paths.
