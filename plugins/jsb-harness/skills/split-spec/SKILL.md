---
name: split-spec
description: Check a spec's delta is complete, assess whether it is too big for one agent, and if so decompose it into one-PR-sized tasks filed through cellq as sub-issues of the spec's parent issue (sub-specs only when an issue body cannot hold the context).
---

# Split spec

Decompose an oversized spec into agent-sized work.

Arguments: path to a spec file (defaults to the spec under discussion).

`cellq` below is the queue adapter (`plugins/jsb-harness/bin/cellq`, contract in
the harness's `specs/cellq.md`). Thresholds are read through it from the cell's
`thresholds.yml`; this skill carries no numbers. Issues are filed through it,
never with raw `gh` issue writes.

## Steps

0. **Refuse unapproved specs.** Approved = the spec as it exists on `main`
   (James merged its PR). If the spec file differs from main's version
   (unmerged branch, uncommitted edits), stop and send it through the /spec
   human gate instead — decomposition and build spend real tokens and gate
   runs; approval comes first. Check:
   `git diff origin/main -- specs/<file>` must be empty.
1. **Pick up the plan, if there is one.** If `specs/<area>.plan.md` exists on
   `main`, pass it to spec-splitter alongside the spec: its *Structure* section
   is what makes the parallelism map real rather than inferred, and its
   *Contracts* section is what stops two parallel agents negotiating an
   interface in two PRs. If the spec involves a real choice of approach and no
   plan exists, say so and offer /plan before decomposing — but don't block on
   it; a forced approach needs no plan.
1a. **Completeness check.** Before the splitter runs, verify the delta carries
   every field /spec requires: **What changes**, **What stays**, **What is
   removed**, **Acceptance criteria**, **Non-goals**, **Constraints**, **Open
   questions**, **Linked issue**. A field is present when a line of the delta
   starts with its name (as `Field:`, `**Field**`, or a `#### Field` heading;
   case does not matter); a field whose value is `none` is present. Check each
   `###` entry under `## Pending changes`:
   ```bash
   delta=$(sed -n '/^## Pending changes/,/^## /p' specs/<file>)
   for f in "What changes" "What stays" "What is removed" "Acceptance criteria" \
            "Non-goals" "Constraints" "Open questions" "Linked issue"; do
     grep -qiE "^(#+ |\*\*)?$f" <<<"$delta" || echo "Incomplete delta: missing $f"
   done
   ```
   (With several entries, run the loop per entry, not over the whole section,
   or one entry's fields would cover another's gaps.) For a new spec, whose
   Pending changes says it is new and whose Behavior is the whole contract,
   check the top-level sections instead: `## Behavior` stands in for the three
   "What" fields, and `## Acceptance criteria`, `## Non-goals`,
   `## Constraints`, `## Open questions` and a `Linked issue:` line must each
   be present. For every missing field print `Incomplete delta: missing
   <field>` on its own line, then stop: do not invoke spec-splitter and file
   no issues. Send the spec back through /spec to complete it.
2. Invoke the **spec-splitter** agent with the spec content and the three
   sizing values from the rule below. It returns an assessment, ordered task
   list with acceptance criteria and dependencies, a parallelism map, and any
   proposed sub-specs.
3. If the assessment is "small enough as-is": report that and stop. Do not
   manufacture ceremony.
4. Otherwise, review the decomposition for overlap conflicts (two parallel tasks
   touching the same files) and fix the ordering if needed.
5. Write any proposed sub-specs to `specs/`, each with a `Derived from:` line
   pointing at the parent spec. Only under R5: a sub-spec exists when a task's
   context (the contract it codes against, shared by several tasks) exceeds
   what an issue body holds; otherwise the issue body is the whole brief.
6. File the tasks through `cellq`, as sub-issues of the spec's linked parent
   issue (the delta's `Linked issue`):
   - one issue per task, title from the task title, body file = definition of
     done + dependency notes + link to the spec (and sub-spec, if any):
     ```bash
     cellq idea "<title>" --body <dod file> --source agent   # -> {number, url}
     ```
   - link each task to the parent:
     ```bash
     cellq link <parent> <n>
     ```
   - wire each dependency (`<n>` depends on `<m>`), so `cellq ready` only
     surfaces unblocked work:
     ```bash
     cellq depend <n> <m>
     ```
   Tasks start in `state:new`; `scope` writes their route and moves them to
   ready.
7. Report: the task table (title, deps, parallel-safe or serialized) and issue
   numbers. Suggest /dispatch if the user wants agents started on the ready set.

## Sizing rule (also enforced by spec-splitter)

One task = one PR. The limits are the cell's, read from its thresholds file,
never carried here:
```bash
cellq threshold task.max_diff_lines
cellq threshold task.max_files
cellq threshold task.max_review_minutes
```
A task fits when its expected diff is within `task.max_diff_lines` and
`task.max_files` and a reviewer can read it in under
`task.max_review_minutes`. If `cellq threshold` fails because the repo has no
`thresholds.yml`, stop and say so rather than substituting a number. The 2026
lesson from agent-PR quality data is that batch size is the main quality
lever — when in doubt, split smaller. Sub-specs only when the context exceeds
what an issue body holds (R5); size does not by itself call for one.
