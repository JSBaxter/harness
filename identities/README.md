# Multi-identity setup

The harness supports multiple GitHub accounts with **directory = identity**
semantics. Which account commits, pushes, and runs `gh` operations is decided
by where the repo lives on disk — deterministic, no `gh auth switch` races
between parallel agents.

**Privacy rule: identity details for non-default accounts live ONLY in local,
untracked files on each machine.** This repo (hosted on the default account)
contains the machinery and placeholders, never the real values.

## The three mechanisms

1. **Commits** — `~/.gitconfig` sets the default identity and uses
   `includeIf "gitdir:..."` to swap `user.name`/`user.email` (and the
   credential helper) inside each identity's directory tree. See
   `example.gitconfig-identity`.
2. **Pushes (HTTPS)** — the per-directory include overrides
   `credential.helper` to call gh with that identity's own config dir
   (`GH_CONFIG_DIR`), so pushes from that tree can only authenticate as that
   account, whatever gh's "active account" happens to be.
3. **`gh` operations** — `bin/gh-as <identity> <args>` pins `GH_CONFIG_DIR`.
   The `identity-guard` hook blocks `git push` with a mismatched email and
   blocks raw `gh` mutations inside non-default identity directories.

## Per-machine setup

1. `cp identities/identities.local.example.json ~/.claude/identities.local.json`
   and fill in the real values (this file is never committed anywhere).
2. Add the include blocks to `~/.gitconfig` and create
   `~/.config/git/identity-<name>` per `example.gitconfig-identity`.
3. One-time login for each extra identity:
   `GH_CONFIG_DIR=~/.config/gh-<name> gh auth login`
4. `install.sh` symlinks `gh-as` into `~/.local/bin`.

## Per-identity GitHub-side setup (once per account)

- Install the Claude GitHub app on that account's repos (`/install-github-app`
  from a repo owned by it, or github.com/apps/claude).
- The `CLAUDE_CODE_OAUTH_TOKEN` secret is Anthropic-side auth — the same
  Max-subscription token works for every account's repos.
- If using Routines for that account's repos, connect the account in
  claude.ai/code's GitHub integration.

## Leak vectors to stay conscious of

- Commits carry name + email: the includeIf swap plus the identity-guard's
  email check cover this, but verify with `git config user.email` after
  creating a repo in a new location.
- One Claude/Anthropic account spans all identities. GitHub can't see that,
  but agent-written text can leak context across identities (e.g. referencing
  default-account projects in a stealth PR description). The reviewer agent
  should treat cross-identity references in stealth repos as Important
  findings — this rule belongs in the stealth repos' CLAUDE.md.
- `gh auth switch` is banned by the guard hook — switching global state is
  exactly the race that leaks.
