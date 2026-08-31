---
name: split-spec
description: Assess whether a spec is too big for one agent; if so, decompose it into sub-specs and one-PR-sized tasks, filed as GitHub issues (and beads issues when bd is available).
---

# Split spec

Decompose an oversized spec into agent-sized work.

Arguments: path to a spec file (defaults to the spec under discussion).

## Steps

0. **Refuse unapproved specs.** Approved = the spec as it exists on `main`
   (James merged its PR). If the spec file differs from main's version
   (unmerged branch, uncommitted edits), stop and send it through the /spec
   human gate instead — decomposition and build spend real tokens and gate
   runs; approval comes first. Check:
   `git diff origin/main -- specs/<file>` must be empty.
1. Invoke the **spec-splitter** agent with the spec content. It returns an
   assessment, ordered task list with acceptance criteria and dependencies, a
   parallelism map, and any proposed sub-specs.
2. If the assessment is "small enough as-is": report that and stop. Do not
   manufacture ceremony.
3. Otherwise, review the decomposition for overlap conflicts (two parallel tasks
   touching the same files) and fix the ordering if needed.
4. Write any proposed sub-specs to `specs/`, each with a `Derived from:` line
   pointing at the parent spec.
5. File the tasks:
   - **GitHub issues** (the human-visible queue): one issue per task, title from
     the task title, body = definition of done + dependency notes + link to the
     spec. Label `agent-task`.
     ```bash
     gh issue create --title "..." --body-file ... --label agent-task
     ```
   - **beads** (agent memory/dependency graph), if `bd` is on PATH: mirror the
     tasks with `bd create`, wire dependencies with blocker relationships so
     `bd ready` only surfaces unblocked work. Skip silently if bd isn't installed.
6. Report: the task table (title, deps, parallel-safe or serialized) and issue
   numbers. Suggest /dispatch if the user wants agents started on the ready set.

## Sizing rule (also enforced by spec-splitter)

One task = one PR = reviewable in under ten minutes = roughly ≤400 diff lines,
≤5 files. The 2026 lesson from agent-PR quality data is that batch size is the
main quality lever — when in doubt, split smaller.
