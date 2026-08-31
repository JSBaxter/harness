# harness

Portable multi-agent continuous-development harness for Claude Code.
Everything runs on a Claude Max subscription — no API billing anywhere.

## Install (any machine)

```bash
git clone https://github.com/JSBaxter/harness ~/Documents/repos/harness
cd ~/Documents/repos/harness && ./install.sh
```

Machine-specific config (auth, local paths, OTel endpoints) goes in
`~/.claude/settings.local.json` and is never committed here.

## Skill distribution (uniform — no environment diverges)

One source of truth: this repo's plugin marketplace on GitHub
(`JSBaxter/harness`). A skill exists when it's merged to main here, nowhere
else. Every environment resolves the same source:

- **Local cockpit**: `install.sh` registers the marketplace by GitHub
  source (this checkout is only for developing the harness).
- **Project repos**: carry a committed `.claude/settings.json` POINTER
  (`extraKnownMarketplaces` + `enabledPlugins`, from `templates/project/`)
  — local sessions, cloud sessions, and routines all install the plugin
  from it at session start. A pointer, never a copy.
- **Developing skills**: `claude --plugin-dir plugins/jsb-harness` is the
  only sanctioned way to run unpushed skills. Skill changes ship via
  branch → PR → merge like everything else.
- **Known gap**: GitHub Actions can't fetch private marketplaces
  (claude-code-action#850). Deliberately fine: the gate/fix workflow
  prompts are self-contained and the reviewer agent is repo-level. If CI
  ever needs the plugin: checkout the marketplace repo with a PAT in a
  prior step and pass its local path to `plugin_marketplaces`.

## What's inside

| Path | What |
|---|---|
| `plugins/jsb-harness/skills/` | `/new-experiment`, `/spec`, `/split-spec`, `/adr`, `/ship`, `/dispatch` |
| `plugins/jsb-harness/agents/` | `reviewer` (adversarial, read-only), `spec-splitter` |
| `plugins/jsb-harness/hooks/` | PreToolUse guard against direct pushes to main |
| `settings/settings.json` | Shared settings: agent teams on, worktree defaults, safe-command allowlist |
| `templates/project/` | Contents for the GitHub **template repo**: CLAUDE.md, review workflow, ruleset, ADR seed, specs scaffold |
| `routines/` | Prompt templates for Claude Code Routines (cloud sessions on GitHub events) |
| `identities/` | Multi-account machinery: directory = identity; real values live only in local untracked files (see `identities/README.md`) |
| `bin/gh-as` | Run `gh` pinned to a specific identity's login |

## The pipeline

1. **Idea** → `/new-experiment` — isolated scratch repo from the template,
   ruleset + review gate applied, cloned under `~/Documents/repos/scratch/`.
2. **Spec** → `/spec`; too big → `/split-spec` → GitHub issues (+ beads), each
   with agent-executable acceptance criteria.
3. **Build** → `/dispatch` — teammates/background sessions, one worktree each;
   watch with `claude agents`.
4. **Gate** → every PR runs `claude-review.yml`: fresh-context reviewer →
   fixer applies Important findings → re-review, bounded rounds; result lands
   as the `claude-review` status. Timeout/no-consensus → `needs-human` label,
   failing status. Merging is the human act (agents are hook-blocked from
   `gh pr merge`; on a solo account you can't formally approve your own PRs).
5. **Feedback** → leave PR review/inline comments mentioning `@claude`:
   `claude-fix.yml` collects all unresolved human comments, does one bounded
   round of work, re-runs the reviewer loop, re-stamps `claude-review` on the
   new head, and replies with a per-comment summary. One human comment = one
   round; the workflows never trigger each other.
5. **React** → Claude Code Routines (claude.ai/code/routines) handle non-gating
   event work on Anthropic compute — zero Actions minutes.

## Setup that lives outside this repo (once per account)

- **Template repo**: `JSBaxter/project-template` (created 2026-08-31 from
  `templates/project/`; when the template contents change here, sync them to
  that repo).
- **Claude GitHub app**: `/install-github-app` in any repo once;
  `claude setup-token` → `CLAUDE_CODE_OAUTH_TOKEN` secret per repo
  (`/new-experiment` step 4 automates the per-repo part). Known wart: the OAuth
  token needs occasional refreshing (claude-code-action issue #727).
- **Routines**: created at claude.ai/code/routines; prompt templates in
  `routines/`.
- **Observability** (optional): self-hosted SigNoz or Langfuse; point Claude
  Code's OpenTelemetry env vars at it in `settings.local.json`.

## Gate cost model (don't reintroduce the quadratic)

A stack of n PRs costs exactly **n gate runs + 1 per human push**. Merges and
retargets trigger nothing: `edited` events aren't listened to, and a
retargeted PR's diff vs its new base is the increment already reviewed
(status rides on the head commit). Two rules protect this — keep them:

- **Never** re-enable `strict_required_status_checks_policy` ("require
  branches up to date"): it forces bot-authored update merges into every
  remaining PR on every merge → O(n²) runs of already-reviewed content, by a
  bot identity the gate rejects.
- **Never** add a global Actions `concurrency` group as a rate cap: groups
  hold one running + ONE pending run and silently replace further arrivals →
  dropped runs → unstamped heads → wedged merges. Burst control lives in
  /dispatch's agent cap (default 4) instead.

Propagating a fix up a live stack costs one run per descendant — do it
deliberately, not habitually.

## Known constraints (by design)

- Personal GitHub plan: no org rulesets, no merge queues → per-repo rulesets
  (`templates/ruleset.json`) + auto-merge with "require branches up to
  date".
- Anthropic's managed Code Review product is Team/Enterprise-only → the
  self-hosted review workflow here is the substitute.
- Agent teams are experimental (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`):
  no resume with in-process teammates, one team per session.
- Hook/plugin schemas move fast — if `/plugin` reports a schema error after a
  Claude Code upgrade, check the current docs before debugging the files.
- **Updating `claude-review.yml` in an already-gated repo** deadlocks by
  design: claude-code-action skips itself when the PR branch's workflow file
  differs from main's (anti-tampering), and the ruleset blocks direct pushes
  to main with no admin bypass. Rollout recipe — temporarily disable the
  ruleset, push the workflow change to main, re-enable:
  ```bash
  rid=$(gh api repos/<owner>/<repo>/rulesets --jq '.[0].id')
  gh api -X PUT "repos/<owner>/<repo>/rulesets/$rid" -f enforcement=disabled
  git push origin main   # the workflow-sync commit
  gh api -X PUT "repos/<owner>/<repo>/rulesets/$rid" -f enforcement=active
  ```
  Keep this human-only; agents shouldn't touch rulesets.
