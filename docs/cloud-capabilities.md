# What a cloud session can and cannot do

Verified capability matrix for agents running in claude.ai/code sessions
against GitHub. Written because the same questions kept being re-derived, each
time by probing, and the answers are not guessable from the docs.

**Last probed: 2026-09-03**, against `JSBaxter/harness-test-drive` from a cloud
session and from a workflow inside that repo. Re-probe before trusting rows
marked untested, and when the agent proxy changes.

## Environment

- `gh` is **absent** from cloud containers (newer images may pre-install it —
  check `command -v gh`).
- `GH_TOKEN` and `GITHUB_TOKEN` **are** set, and the agent proxy injects auth,
  so plain `curl https://api.github.com/...` is authenticated. The tool surface
  is not the constraint; the proxy's allowlist is.
- Plugins do **not** auto-install (upstream #32606, closed not-planned), so
  plugin skills are not slash commands. Repo-committed `.claude/skills/` *does*
  load. Follow harness skills from source instead.

## Matrix

| Operation | Cloud session | In-repo workflow (`GITHUB_TOKEN`) | Local session |
|---|---|---|---|
| Clone, commit, push a branch | ✅ | n/a | ✅ |
| **Delete a branch** (push or `DELETE /git/refs`) | ❌ 403 *"Write access to this GitHub API path is not permitted"* | untested | ✅ |
| Read repo, rulesets, labels | ✅ 200 | ✅ 200 | ✅ |
| Create / delete a label | ✅ 201 / 204 | untested | ✅ |
| Open a PR, comment, label a PR | ✅ (MCP) | ✅ | ✅ |
| **Write repo settings** (`PATCH /repos`) | ❌ 403 *"Repository settings writes are not permitted"* | ❌ 403 *"Resource not accessible by integration"* | ✅ |
| **Create a ruleset** (`POST /rulesets`) | untested | ❌ 403 *"Resource not accessible by integration"* | ✅ |
| **Actions secrets** (read key, set secret) | ❌ 403 *"Access to this GitHub Actions path is not permitted"* | ❌ 403 *"Resource not accessible by integration"* | ✅ |
| Read Actions runs and job logs | ❌ via `curl`, ✅ **via MCP** | n/a | ✅ |
| Write commit statuses / check runs | ❌ 403 (status reads hit a proxy 502) | ✅ | n/a |

`administration` is **not a valid workflow `permissions` scope**. Declaring it
makes the workflow file invalid and the run fails with zero jobs — so an
in-repo workflow cannot be elevated to do repo admin.

## What follows

- **Repo setup is local-only.** The ruleset, `delete_branch_on_merge` and
  `CLAUDE_CODE_OAUTH_TOKEN` are refused to a cloud session *and* to an in-repo
  workflow. Only a session holding the user's own credentials can apply them,
  short of a cross-repo PAT. See `specs/project-creation.md`.
- **The review gate must stay in Actions.** Only a workflow token can stamp the
  required `claude-review` status (ADR 0001).
- **MCP is not a superset of raw HTTP.** It exposes no repo-settings, ruleset,
  secret or branch-delete tools at all — but it reads Actions where `curl`
  cannot. Prefer MCP for anything it covers: it is the sanctioned surface, and
  the raw allowlist is the more likely of the two to tighten.
- **Cloud sessions can watch CI.** Runs and logs are readable via MCP, so an
  agent can diagnose a failure it cannot have caused a status for.
