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

# --- plugin marketplace ------------------------------------------------------
say "registering plugin marketplace"
if claude plugin marketplace add "$HARNESS_DIR" 2>/dev/null; then
  claude plugin install jsb-harness@jsb-harness 2>/dev/null || true
  say "plugin installed"
else
  warn "CLI plugin registration unavailable — inside Claude Code run:"
  warn "  /plugin marketplace add $HARNESS_DIR"
  warn "  /plugin install jsb-harness@jsb-harness"
fi

say "done. Verify inside Claude Code with /plugin and try /spec or /new-experiment."
