---
name: ship
description: Exit checklist before opening a PR — tests, self-review against spec and ADRs, small-commit hygiene, then open the PR with the issue linked.
---

# Ship

Run the pre-PR gate, then open the PR. Run this at the end of every implementation
task; don't open PRs any other way.

`cellq` below is the queue adapter (`plugins/jsb-harness/bin/cellq`, contract in
the harness's `specs/cellq.md`). Every threshold is read through it from the
cell's `thresholds.yml`; this skill carries no numbers. Issue state is set
through it too, never with raw `gh issue edit`.

## Steps

1. **Scope check** — `git diff <base>...HEAD --stat`, against the cell's
   limits:
   ```bash
   cellq threshold task.max_diff_lines
   cellq threshold task.max_files
   ```
   If `cellq threshold` fails because the repo has no `thresholds.yml` (exit
   1, naming the file), stop and say so; do not substitute a number from
   memory or from another repo. If the diff exceeds either value, stop and
   propose splitting into stacked PRs before continuing. Big diffs are the
   main cause of bad agent PRs.
2. **Tests** — run the project's test suite (see CLAUDE.md for the command). All
   green or you stop and fix; never open a PR with known-failing tests. Report
   actual output, not a summary of hope.
3. **Lint/format** — run the project's linters (ruff/clippy/eslint etc. per
   CLAUDE.md).
4. **Self-review** — invoke the **reviewer** agent (fresh context) on the diff.
   Fix Important findings, rerun tests, re-review until the reviewer approves
   or `cellq threshold review.max_rounds` rounds have run, whichever comes
   first — if the bound is hit, note the outstanding and disputed findings in
   the PR body for the human. Before the first round, draft the PR body's
   `## Spec changes` section (the form is in step 9: `none`, or one line per
   Behavior statement the diff changes or adds) and hand it to the reviewer
   with the diff, because its spec-behaviour check reads that section.
5. **ADR check** — did this work establish a new convention or make a real
   choice? If yes, run /adr before opening the PR.
6. **Commit hygiene** — commits should be small and each message follows
   Conventional Commits (`type(scope): summary`, e.g. `feat(auth): ...`); the
   body says why, not just what. Squash fixups.
7. **Frontend/visual changes: screenshots in the PR body.** Render 1-3
   deterministic screenshots of the key states this PR changed (use the
   project's shot helper), commit them under `docs/screenshots/<branch>/`,
   and embed each in a `## Screenshots` section with a one-line caption
   saying what to look at:
   ```markdown
   ![caption](https://github.com/<owner>/<repo>/blob/<branch>/docs/screenshots/<branch>/<name>.png?raw=true)
   ```
   Works on private repos (verified 2026-08-31, correctly this time —
   an earlier "doesn't render" conclusion was actually a missing file).
   Before embedding, VERIFY the file is on the remote:
   `gh api repos/<o>/<r>/contents/<path>?ref=<branch>` — `git add -A`
   silently skips gitignored paths, and a broken embed looks identical to
   an unsupported one. Show the changed state, not the idle page.

   **From a cloud session (claude.ai/code), do not embed — you cannot.**
   That session's egress path rewrites outbound bodies: absolute URLs get
   wrapped in backticks and the leading `!` is stripped, so every embed
   arrives as a defanged link. Measured on chord-recommender#26 across six
   forms — inline, reference-style, `<img>`, raw.githubusercontent,
   root-relative and protocol-relative — all six neutralised; only
   `claude.ai` URLs pass, so it is a domain allowlist, not a syntax problem.
   Two independent sessions have now spent a round rediscovering this
   (chord-recommender#3 hit it first and wrote it up in its own PR body).
   Instead: commit the shots under `docs/screenshots/<branch>/`, and in the
   body give a table of filenames and what to look at, pointing at the
   **Files changed** tab, where GitHub renders committed PNGs inline.

   Note the remote check above is necessary but NOT sufficient: it proves the
   file is fetchable, not that your markdown survived the write. If you do
   embed, read the body back (`gh api repos/<o>/<r>/pulls/<n> --jq .body`)
   and confirm the `![` is still there.
8. **Is this a proposal?** A spec, a mockup, an ADR draft, a sketch — anything
   opened to ask James's opinion rather than to land finished work — wears the
   **`proposal`** label. The review gate then skips the agent reviewer and
   stamps `claude-review` green directly; James's merge is the gate instead.
   Apply it **at creation** (`--label proposal` in step 9). Labelling afterwards
   does work — `labeled` re-runs the gate and flips the verdict — but only after
   a full agent review has already run.
   If the repo doesn't have the label yet:
   ```bash
   gh label create proposal -c "c5def7" \
     -d "opinion/spec/mockup PR — human review only, skip agent gate" --force
   ```
   **No `gh`? (cloud sessions.)** `create_pull_request` takes no `labels`
   parameter, so labelling at creation isn't directly possible — but the gate
   skips drafts (`!github.event.pull_request.draft`), which gets the same result
   in three MCP calls:
   1. `create_pull_request` with `draft: true`
   2. `issue_write` — method `update`, the PR number, `labels: ["proposal"]`.
      PRs are issues, so this works, and it creates the label if the repo
      lacks one.
   3. `update_pull_request` with `draft: false`

   **If the GitHub MCP tools are absent too** (they are not guaranteed — a
   cloud session may have neither `gh` nor them, only the REST API through the
   proxy's injected `GITHUB_TOKEN`), the draft route is a dead end and you must
   not take it. A draft cannot be un-drafted from there:

   - `PATCH /repos/{o}/{r}/pulls/{n}` with `{"draft": false}` returns 200 and
     does nothing. That is upstream GitHub behaviour — the REST PR endpoint does
     not accept `draft` at all — not a sandbox restriction, so no amount of
     retrying or reshaping the payload will help.
   - The GraphQL `markPullRequestReadyForReview` mutation is the only real
     route, and `/graphql` is not repository-scoped, so the session's GitHub
     proxy will not serve it.

   So with REST only: **open the PR non-draft, then label it in your very next
   call**, with the labels endpoint — which is repository-scoped, works on a PR
   at any time, and needs no un-drafting:

   ```
   POST /repos/{owner}/{repo}/issues/{number}/labels   {"labels": ["proposal"]}
   ```

   This is safe despite the warning below, for two reasons worth knowing rather
   than trusting: the caller's concurrency group is per-PR with
   `cancel-in-progress: true`, so the `labeled` run cancels the `opened` run
   still in flight; and the gate's classify step reads labels at run time, so if
   the label lands first the `opened` run skips on its own. The cost is seconds
   of a runner, not a review round. Label **immediately** — do no other work
   between the two calls, because that window is the whole margin.

   Do not instead leave the PR as a draft and ask the human to click **Ready for
   review**. It looks cheap and is not: the PR sits invisible until they notice,
   and they will sometimes be on a phone, and will sometimes forget.

   The gate then sees the PR labelled, or cancels the run that saw it unlabelled.
   Where you *do* have `gh` or the MCP tools, still apply the label at creation
   rather than afterwards: with those routes it costs nothing, and an
   `opened` run that completes before the label lands spends the exact review
   round the label exists to save.

   Forgetting this is costly and the failure is silent: the gate reviews an
   unlabelled mockup as if it were production code, and because it re-runs on
   every push, each fix you make in response spawns another round. If you find
   yourself on round three of style nits against a file you plan to throw away,
   this label is what you missed — add it rather than continuing to push.
9. **Open the PR**:
   ```bash
   gh pr create --title "..." --body "..." --base <default-branch> [--label proposal]
   ```
   PR body must include: `Closes #NN` (the driving issue), a summary of what
   changed and why, test evidence (what was run, result), screenshots per
   step 7 for visual changes, any disputed reviewer findings from step 4,
   and a **`## Spec changes`** section. That section is either the single
   word `none`, or one line per Behavior statement the diff changes or adds
   in a `specs/*.md` file, in exactly this form:
   ```markdown
   ## Spec changes
   <spec file>: "<statement>" — test: <test name>
   ```
   The reviewer and James check this heading against the diff: `none` when
   the diff changes a statement under a spec's `## Behavior`, or a listed
   statement the diff does not touch, is an Important finding. Spec edits
   outside `## Behavior` (an open question settled, a non-goal added) are
   `none` here. If `gh pr edit` hits the projectCards GraphQL
   deprecation error, PATCH the body via
   `gh api -X PATCH repos/<owner>/<repo>/pulls/<n>`.
10. **Move the issue to in-review** as soon as the PR exists:
   ```bash
   cellq state <issue> in-review
   ```
11. Report the PR URL and the review-gate status once CI kicks off. On a
   proposal PR, expect `claude-review` to pass immediately with "Proposal PR
   (`proposal` label)" as its reason — if it instead starts an agent review,
   the label didn't take.
