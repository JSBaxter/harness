---
name: adr
description: Draft an Architecture Decision Record (MADR format) in docs/adr/ when a decision worth remembering is made. Supersede, never delete.
---

# ADR

Record an architecture decision.

## When to write one

- A choice between real alternatives was made (library, pattern, protocol,
  boundary) and a future agent could plausibly "fix" it back.
- A convention is being established that isn't obvious from the code.
- An existing ADR is being reversed → write a new ADR that supersedes it.

Not for: routine implementation choices with no realistic alternative, or
anything fully captured by the spec.

## Steps

1. Find the next number: `ls docs/adr/` → `NNNN` zero-padded to 4 digits.
2. Write `docs/adr/NNNN-<kebab-title>.md`:

```markdown
---
status: proposed | accepted | superseded by NNNN
date: YYYY-MM-DD
---

# <Decision title, stated as the decision>

## Context
What forces are at play. Why a decision was needed. 2–5 sentences.

## Decision
What was decided, stated actively ("We will ...").

## Consequences
What becomes easier, what becomes harder, what we're accepting.

## Alternatives considered
- <Alternative> — why not.
```

3. If this supersedes an earlier ADR, edit the old one's status to
   `superseded by NNNN` — never delete or rewrite its content.
4. If the decision changes current conventions, update `CLAUDE.md` to state the
   new rule and link the ADR (CLAUDE.md holds the "what", ADRs hold the "why").
5. New ADRs are born `proposed`; the human flips them to `accepted`. Say so in
   your report rather than self-accepting.
