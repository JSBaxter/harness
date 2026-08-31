# harness

Portable multi-agent continuous-development harness for Claude Code.
Everything runs on a Claude Max subscription — no API billing anywhere.

## Install (any machine)

```bash
git clone git@github.com:OWNER/harness ~/Documents/repos/harness
cd ~/Documents/repos/harness && ./install.sh
```

Machine-specific config (auth, local paths, OTel endpoints) goes in
`~/.claude/settings.local.json` and is never committed here.

## What's inside

| Path | What |
|---|---|
| `plugins/jsb-harness/skills/` | `/new-experiment`, `/spec`, `/split-spec`, `/adr`, `/ship`, `/dispatch` |
| `plugins/jsb-harness/agents/` | `reviewer` (adversarial, read-only), `spec-splitter` |
| `plugins/jsb-harness/hooks/` | PreToolUse guard against direct pushes to main |
| `settings/settings.json` | Shared settings: agent teams on, worktree defaults, safe-command allowlist |
| `templates/project/` | Contents for the GitHub **template repo**: CLAUDE.md, review workflow, ruleset, ADR seed, specs scaffold |
| `routines/` | Prompt templates for Claude Code Routines (cloud sessions on GitHub events) |

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
   failing status. You are the only approver of record.
5. **React** → Claude Code Routines (claude.ai/code/routines) handle non-gating
   event work on Anthropic compute — zero Actions minutes.

## Setup that lives outside this repo (once per account)

- **Template repo**: create `OWNER/project-template` from `templates/project/`
  and mark it as a template repo on GitHub.
- **Claude GitHub app**: `/install-github-app` in any repo once;
  `claude setup-token` → `CLAUDE_CODE_OAUTH_TOKEN` secret per repo
  (`/new-experiment` step 4 automates the per-repo part). Known wart: the OAuth
  token needs occasional refreshing (claude-code-action issue #727).
- **Routines**: created at claude.ai/code/routines; prompt templates in
  `routines/`.
- **Observability** (optional): self-hosted SigNoz or Langfuse; point Claude
  Code's OpenTelemetry env vars at it in `settings.local.json`.

## Known constraints (by design)

- Personal GitHub plan: no org rulesets, no merge queues → per-repo rulesets
  (`templates/project/ruleset.json`) + auto-merge with "require branches up to
  date".
- Anthropic's managed Code Review product is Team/Enterprise-only → the
  self-hosted review workflow here is the substitute.
- Agent teams are experimental (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`):
  no resume with in-process teammates, one team per session.
- Hook/plugin schemas move fast — if `/plugin` reports a schema error after a
  Claude Code upgrade, check the current docs before debugging the files.
