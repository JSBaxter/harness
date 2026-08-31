# Harness roadmap

Status as of 2026-08-31. Owner: James. Sequenced by James's priorities:
real-project shakeout → hands-off cloud → ops polish. Stealth identity is
parked until needed; observability stays on built-ins by choice.

## Phase 0 — prerequisites (blocking Phase 1)

- [x] Install uv: `curl -LsSf https://astral.sh/uv/install.sh | sh`
- [x] Install libseccomp2 (`sudo apt install libseccomp2`) — the native sandbox
      doesn't run without it, and it's the always-on isolation layer
- [ ] Merge/close out: delete `harness-test-drive` (needs
      `gh auth refresh -h github.com -s delete_repo`) or keep as reference

## Phase 1 — shake out the skills on a real project

The pipeline plumbing is proven; the skills have never been run cold by an
agent. Pick a real small project and drive it entirely through:

- [x] `/new-experiment <name>` (first cold run of the skill itself)
- [ ] `/python-setup`
- [x] `/spec` → `/split-spec` (exercises the spec-splitter agent + issue filing)
- [x] `/dispatch` (background agents + worktrees, 4 agents used)
- [x] `/ship` from an agent (exercises the local fresh-context reviewer path)
- [ ] One full human-feedback round on a real PR; verify the
      review-submission `@claude` trigger variant (deployed, untested —
      fallback: plain comment)
- [ ] Fix every rough edge found and commit the fixes here

Exit criteria: a real feature merged with zero manual steps outside
review-and-merge.

## Phase 2 — hands-off cloud

- [ ] Connect GitHub at claude.ai/code; test `claude --cloud "<task>"` on the
      Phase 1 repo, steer from web/mobile, `claude --teleport` it back down
- [ ] Set up first Routine (claude.ai/code/routines) from
      `routines/pr-review-loop.md` or simpler (e.g. nightly triage of open
      `agent-task` issues); learn the preview caps in practice
- [ ] Decide per-task-type defaults: what goes local vs cloud vs routine;
      write the outcome into this file and CLAUDE.md guidance

Exit criteria: kick off a task from the phone, review the PR next morning.

## Phase 3 — ops polish

- [ ] `/refresh-token` skill: update `CLAUDE_CODE_OAUTH_TOKEN` on all active
      repos from `~/.claude/claude-code-oauth-token` in one sweep
- [ ] Template-repo sync skill or CI: `templates/project/` →
      `JSBaxter/project-template` automatically on push to this repo
- [ ] Try beads (`bd`) for cross-repo/cross-week task memory; adopt or drop
- [ ] Review `/usage` + `/insights` after a few weeks of real load; only
      revisit external observability (SigNoz/Langfuse) if the built-ins
      leave real questions unanswered

## Parked (revisit when triggered)

- **Stealth identity end-to-end** — machinery is deployed and fails closed;
  activate when stealth work actually starts: fill
  `~/.claude/identities.local.json` + `~/.config/git/identity-stealth`,
  `GH_CONFIG_DIR=~/.config/gh-stealth gh auth login`, install the Claude app
  on that account, test `/new-experiment --identity stealth`
- **External observability** — trigger: regularly running 5+ concurrent
  agents, or quota surprises the built-ins can't explain
- **Always-on second machine** — trigger: laptop-closed becoming the
  bottleneck Phase 2 can't cover
