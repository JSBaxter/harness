---
name: dispatch
description: Spawn parallel agents (teammates or background sessions) across one or more repos from the ready task queue, one worktree each, and report who is working on what.
---

# Dispatch

Start parallel agents on ready tasks.

Arguments: optional repo path(s) and/or issue numbers. Default: the current
repo's ready queue.

## Steps

1. **Build the ready set** — tasks with no unmet dependencies:
   - beads available: `bd ready`
   - otherwise: open `agent-task` issues with no "blocked by" note, via
     `gh issue list --label agent-task --state open`
2. **Check overlap** — don't dispatch two tasks that the /split-spec parallelism
   map (or the issue bodies) say touch the same files. Serialize those.
3. **Dispatch** — for each task, prefer in this order:
   - **Agent teams** (same repo, coordinated work): spawn teammates, one per
     task, each in its own worktree; the shared task list tracks progress.
   - **Background sessions** (independent tasks, possibly different repos):
     `claude --bg --name "<task>" "<prompt>"` from the repo, or `claude --cloud`
     when the machine shouldn't be tied up.
   The prompt for each agent is the issue body (definition of done) plus:
   "work in your worktree, follow CLAUDE.md, finish with /ship".
4. **Cap concurrency** — default max 4 concurrent agents unless told otherwise;
   quota is shared with interactive work. Say what was deferred and why.
5. **Report** — table of task → agent/session name → worktree/repo → how to
   watch (`claude agents`). Include anything left in the queue.

## Notes

- **Never trust an isolation/remote claim without verifying** (learned
  2026-08-31: a "remote" agent spawn silently ran locally — the launch
  result was indistinguishable). If a task is dispatched as remote/cloud,
  verify the execution locus from evidence: the agent reports its working
  paths/hostname, and no artifacts appear on the local machine. If work
  MUST NOT run locally (untrusted code, resource limits), do not use a
  mechanism that can silently downgrade — use claude.ai/code sessions or
  routines, where execution location is structural, not a parameter.

- Never dispatch to a task whose issue lacks acceptance criteria — send it back
  through /split-spec instead. A vague issue becomes a vague PR.
- Cross-repo dispatch: run the dispatch per-repo; beads syncs state across repos
  if configured with a shared remote.
