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
supersedes: none | NNNN
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

3. **Record supersession in both directions.** Every ADR carries both fields,
   always — `supersedes: none` when it replaces nothing, so a missing link is
   distinguishable from a forgotten one. When this ADR does replace an earlier
   decision:
   - set this ADR's `supersedes: NNNN`
   - set the old ADR's `status: superseded by NNNN`

   Never delete or rewrite the old one's content. One direction alone is a
   trap: marked only on the old ADR, a reader of the new one cannot tell it
   replaced anything and will not know to read the history; marked only on the
   new one, someone who opens the old ADR follows a decision that has already
   been reversed.
4. If the decision changes current conventions, update `CLAUDE.md` to state the
   new rule and link the ADR (CLAUDE.md holds the "what", ADRs hold the "why").
5. New ADRs are born `proposed`; the human flips them to `accepted`. Say so in
   your report rather than self-accepting.
