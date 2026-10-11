---
name: steward
description: How an agent watching a PR in this repo should behave — when a review-gate finding is worth a push and when it is only worth a note. Read before acting on any CI or review event on a PR you opened here.
---

# Stewarding a PR in this repo

The built-in PR-watching posture assumes a gate that fails when something is
broken, and tells you to drive to green by pushing fixes. This repo's gate is
not that. `claude-review` runs an **agent** reviewer that returns a verdict plus
findings, and it re-runs on every `synchronize` — so a push made in response to
a finding produces another round, which produces more findings. Left unchecked
that loop is self-sustaining and costs a full agent review per iteration.

These rules govern *how proactive to be*. They do not relax anything the
built-in rules state as "never" — no skipping or disabling tests, no rewriting
someone else's branch, no empty commits to kick CI, no approving or merging.

## Read the verdict before the findings

- **APPROVE** means the gate is done. Findings under it are advisory, and the
  gate says so itself ("Minor findings noted (not fixed) — minor findings never
  block"). A finding the reviewer explicitly declined to fix and marked
  non-blocking is **not** a bug report. Do not push for it.
- **NEEDS_CHANGES**, or any **Important** finding, is real work. Fix it, verify,
  push — the normal posture applies.

## Don't spend a round on advisory findings

On an APPROVE verdict:

- Collect the Minor findings. Fix them **only** if you are already pushing for
  another reason (an Important finding, a conflict, a human's request) — ride
  along on that push rather than generating one.
- Otherwise put them in **one** comment, or just tell James, and stop. A green
  PR waiting on human approval is finished; it is not a red PR to grind on.
- Two exceptions worth a push of their own, because they are correctness rather
  than style: the artifact **says something untrue** (a label naming chords that
  aren't there, a comment claiming coverage that doesn't exist, a stale
  screenshot that disagrees with the code it documents), or the finding is about
  **music theory** — see CLAUDE.md, those get surfaced to James, never silently
  changed.

## If the gate is reviewing a proposal, the label is the bug

A spec, mockup, ADR draft or any PR asking James's opinion wears the `proposal`
label and the gate skips the reviewer entirely (CLAUDE.md, "Only finished work
gets agent review"). So if you are reading agent-review findings on a PR that
was only ever meant to ask an opinion, the finding to act on is **the missing
label**. Add it — the `labeled` event re-runs the gate and flips the verdict —
and do not work the findings.

## The smell

If you are on the third round of style nits against a file you intend to throw
away, stop pushing. Something upstream is wrong — usually a missing `proposal`
label, occasionally a gate pointed at the wrong kind of artifact. Say so to
James instead of continuing. Rounds are not free, and neither is his attention.

## Still always true

Push, promptly and without asking, for: a **red** gate, a **merge conflict**, an
**Important** finding, or a human reviewer's request. Those are the cases the
built-in posture is written for, and this file does not soften them.
