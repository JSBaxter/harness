---
status: accepted
supersedes: none
date: 2026-10-12
deciders: James
---

# 0011 — One GitHub identity; the multi-identity machinery is removed

## Context and problem statement

The harness carried machinery for operating under more than one GitHub
account by directory: an identity map, a per-directory push guard, and a
`gh` wrapper. It was never used in practice and the roadmap had it parked.
Unused machinery still has to be read, kept consistent with the skills, and
carried into every cell's rules.

## Decision

We will support one GitHub identity. The identity map, the identity-guard
hook, the `gh-as` wrapper and the install step that seeded them are
removed; `new-experiment` takes no identity argument and runs plain `gh`.

## Consequences

- One fewer hook on every Bash call and one fewer concept in the skills.
- ADRs 0001, 0003 and 0010 mention the old mechanism; each carries a dated
  note pointing here. Their text is unchanged, per ADR 0000.
- Any future need for a second identity is a separate repository, not a
  mode of this one.
