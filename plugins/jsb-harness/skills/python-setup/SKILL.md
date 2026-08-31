---
name: python-setup
description: Set up a Python project with the default toolchain — uv (env/deps), ruff (lint+format), ty (types), pytest (tests) — and wire the commands into CLAUDE.md so agents and the review gate use them.
---

# Python setup

Stamp the standard Python toolchain onto the current repo. Works on a fresh
`/new-experiment` repo or an existing project.

Toolchain (non-negotiable defaults): **uv** for environments and dependencies,
**ruff** for linting and formatting, **ty** for type checking, **pytest** for
tests. Never introduce pip/poetry/black/mypy/flake8 alongside these.

## Steps

1. **Preflight** — `uv --version` must work; if not, stop and tell the user to
   install uv (https://docs.astral.sh/uv/). Never fall back to pip silently.
2. **Layout** — if the repo has no Python code yet, ask nothing and default to
   src layout: `uv init --lib` for something importable, `uv init` for an
   app/script project (pick from the repo's stated purpose in README/specs).
   If code already exists, keep its layout and only add the tooling.
3. **Dependencies**:
   ```bash
   uv add --dev ruff ty pytest
   ```
4. **pyproject.toml** — append tool config (don't clobber existing sections;
   merge if present):
   ```toml
   [tool.ruff]
   line-length = 100

   [tool.ruff.lint]
   select = ["E", "F", "I", "UP", "B", "SIM"]

   [tool.ruff.format]
   # defaults

   [tool.pytest.ini_options]
   testpaths = ["tests"]
   ```
   ty currently needs no config for defaults; add `[tool.ty]` only when a
   real setting is required.
5. **CLAUDE.md** — set the commands agents and the review gate run:
   - Test command: `uv run pytest -q`
   - Lint command: `uv run ruff check . && uv run ruff format --check .`
   - Type check command: `uv run ty check`
   Add the type-check line if CLAUDE.md doesn't have one, and add a rule:
   "All three must pass before /ship opens a PR."
6. **.gitignore** — ensure `.venv/`, `__pycache__/`, `*.pyc`, `.pytest_cache/`,
   `.ruff_cache/` are present.
7. **CI (optional but default yes)** — write `.github/workflows/ci.yml`:
   ```yaml
   name: CI
   on:
     pull_request:
   jobs:
     checks:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v6
         - uses: astral-sh/setup-uv@v7
         - run: uv sync --dev
         - run: uv run ruff check . && uv run ruff format --check .
         - run: uv run ty check
         - run: uv run pytest -q
   ```
   Tell the user they can make `checks` a required status alongside
   `claude-review` by adding it to the repo ruleset (offer to do it via
   `gh api` if they want it enforced).
8. **Smoke test** — `uv run pytest -q` and `uv run ruff check .` must both
   succeed (an empty test suite is fine) before you commit. Commit with
   message "Set up Python toolchain: uv, ruff, ty, pytest".

## Notes

- The review-gate runner has no uv preinstalled; the gate reads commands from
  CLAUDE.md, and `uv run` bootstraps the venv on first use — but the fastest
  path in CI is the ci.yml above, so lean on that for mechanical checks and
  let the reviewer agent focus on semantics.
- ty is young; if it false-positives on something load-bearing, prefer a
  targeted `# ty: ignore` with a comment over turning the checker off, and
  note it in the PR body.
