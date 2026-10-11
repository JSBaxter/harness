---
status: accepted
supersedes: none
date: 2026-10-11
deciders: James
---

# 0007 — Issue state lives in labels and sub-issues, not a Projects field

## Context and problem statement

The operating model (infra-experiment-notes, design 4.2) decided that an
issue is in exactly one of eight states and recommended a GitHub Projects
status field to hold it. Projects v2 is GraphQL-only and needs the
`project` token scope. The cloud session proxy serves no GraphQL, the
Actions `GITHUB_TOKEN` has no Projects access, and the local `gh` token
lacks the scope (probed 2026-10-11). Agents on two of the four surfaces
could not read or write the state.

## Considered options

1. **Projects v2 status field.** The recommended mechanism; unreachable
   from cloud sessions and Actions.
2. **Labels, single-valued per group, plus GitHub sub-issues for parent
   and tasks.** REST, repository-scoped, reachable everywhere.
3. **A state file in the repository.** A second store; drifted in May.

## Decision

We will adopt option 2. `state:<name>` labels carry the eight states;
`route:` and `source:` labels carry route and source; a parent and its
tasks are linked with sub-issues. The queue adapter (`cellq`) is the only
writer and keeps each group single-valued. Done and dropped are the issue
closed as completed or not planned, label kept.

## Consequences

- Every surface can read and write state over REST.
- James's phone view is the issue list filtered by `state:` labels. A
  Projects board, if wanted later, is a mirror fed by automation, never
  the source.
- Labels are not enforced single-valued by GitHub; only the adapter keeps
  them so. Raw `gh issue edit` on state labels is forbidden by the
  entrypoint rule.
- The design document's recommendation of a Projects field is amended by
  this record; the states and verbs are unchanged.
