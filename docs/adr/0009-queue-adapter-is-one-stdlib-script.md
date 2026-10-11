---
status: accepted
supersedes: none
date: 2026-10-11
deciders: James
---

# 0009 — The queue adapter is one Python stdlib script, REST only

## Context and problem statement

The operating model (design 4.2) wants the queue verbs implemented once,
as the only code that knows GitHub's field names, labels and sub-issue
calls, so that every skill keeps working if the backend changes. It must
run on all four surfaces: `gh` is absent from cloud containers, GraphQL is
not served by the cloud proxy, and a dependency install per session costs
time and can fail.

## Considered options

1. **Bash over `gh`.** Fails in cloud sessions without `gh`.
2. **An MCP server with its own store.** The May queue; became a second
   store and drifted from Issues.
3. **One Python 3 file using only the standard library, REST only, token
   from `GH_TOKEN` or `gh auth token`.** Runs anywhere Python 3 exists,
   installs nothing.

## Decision

We will adopt option 3. The script lives at `plugins/jsb-harness/bin/cellq`
and reaches cloud sessions with the plugin copy. It prints JSON, exits
non-zero with a one-line reason, and also serves `thresholds.yml` reads so
no skill needs a YAML library.

## Consequences

- Skills call `cellq`, never `gh issue edit`, `gh project` or MCP
  issue-write tools, for state. The entrypoint states the rule and the
  reviewer flags violations.
- A backend change is a rewrite of one file.
- No tests framework exists in the harness yet; `cellq` ships with a test
  script under `plugins/jsb-harness/bin/tests/` that runs against a
  throwaway repository, in the pattern of the hook tests.
