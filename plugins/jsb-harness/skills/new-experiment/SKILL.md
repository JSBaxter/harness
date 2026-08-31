---
name: new-experiment
description: Spin up an isolated scratch repo from the project template so an idea can be tried without polluting the dev environment. Creates the GitHub repo, applies branch protection, installs the review workflow.
---

# New experiment

Create an isolated scratch repository for trying out an idea.

Arguments: `<name>` (kebab-case repo name), optional one-line description.

## Steps

1. Confirm the name doesn't already exist: `gh repo view <owner>/<name>` should fail.
2. Create from the template repo (private by default):
   ```bash
   gh repo create <name> --template <owner>/project-template --private --clone
   ```
   Clone destination: `~/Documents/repos/scratch/<name>`. Create `scratch/` if missing.
   If the template repo doesn't exist yet, say so and offer to create it from
   the harness repo's `templates/project/` directory instead of failing silently.
3. Apply the branch-protection ruleset (personal accounts can't use org rulesets):
   ```bash
   gh api repos/<owner>/<name>/rulesets --method POST \
     --input <harness-repo>/templates/project/ruleset.json
   ```
4. Add the `CLAUDE_CODE_OAUTH_TOKEN` secret so the review workflow can run:
   ```bash
   gh secret set CLAUDE_CODE_OAUTH_TOKEN --repo <owner>/<name> --body "$(claude setup-token 2>/dev/null || true)"
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
