#!/usr/bin/env bash
# Install the jsb-harness on this machine.
# Idempotent: safe to re-run after pulling updates.
set -euo pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"

say()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN\033[0m %s\n' "$*"; }

# --- dependency checks -------------------------------------------------------
missing=0
for dep in claude gh jq git; do
  if ! command -v "$dep" >/dev/null 2>&1; then
    warn "missing dependency: $dep"
    missing=1
  fi
done
[ "$missing" -eq 1 ] && warn "install missing dependencies, then re-run"

if ! ldconfig -p 2>/dev/null | grep -q libseccomp; then
  warn "libseccomp not found — Claude Code's Linux sandbox needs it (apt install libseccomp2)"
fi

if ! command -v bd >/dev/null 2>&1; then
  warn "beads (bd) not installed — /split-spec and /dispatch degrade gracefully without it"
fi

if ! command -v uv >/dev/null 2>&1; then
  warn "uv not installed — /python-setup needs it (curl -LsSf https://astral.sh/uv/install.sh | sh)"
fi

# --- settings ----------------------------------------------------------------
mkdir -p "$CLAUDE_DIR"
if [ ! -f "$CLAUDE_DIR/settings.json" ]; then
  cp "$HARNESS_DIR/settings/settings.json" "$CLAUDE_DIR/settings.json"
  say "installed settings.json"
else
  if ! diff -q "$HARNESS_DIR/settings/settings.json" "$CLAUDE_DIR/settings.json" >/dev/null 2>&1; then
    warn "~/.claude/settings.json exists and differs from harness settings/"
    warn "merge manually, e.g.: jq -s '.[0] * .[1]' ~/.claude/settings.json $HARNESS_DIR/settings/settings.json"
  else
    say "settings.json already up to date"
  fi
fi

# --- identities --------------------------------------------------------------
mkdir -p "${HOME}/.local/bin"
ln -sf "$HARNESS_DIR/bin/gh-as" "${HOME}/.local/bin/gh-as"
say "linked gh-as into ~/.local/bin"
if [ ! -f "$CLAUDE_DIR/identities.local.json" ]; then
  cp "$HARNESS_DIR/identities/identities.local.example.json" "$CLAUDE_DIR/identities.local.json"
  warn "created ~/.claude/identities.local.json with PLACEHOLDER values"
  warn "fill it in and follow identities/README.md (gitconfig includes + gh logins)"
fi

# --- plugin marketplace ------------------------------------------------------
# Registered by GITHUB SOURCE, not local path: every environment (local, cloud,
# routines) resolves the same pushed marketplace — skills exist when merged,
# nowhere else. This checkout is for DEVELOPING the harness; test unpushed
# skills only via: claude --plugin-dir "$HARNESS_DIR/plugins/jsb-harness"
say "registering plugin marketplace (github: JSBaxter/harness)"
if claude plugin marketplace add JSBaxter/harness 2>/dev/null; then
  claude plugin install jsb-harness@jsb-harness 2>/dev/null || true
  say "plugin installed from github source"
else
  warn "CLI plugin registration unavailable — inside Claude Code run:"
  warn "  /plugin marketplace add JSBaxter/harness"
  warn "  /plugin install jsb-harness@jsb-harness"
fi

say "done. Verify inside Claude Code with /plugin and try /spec or /new-experiment."
