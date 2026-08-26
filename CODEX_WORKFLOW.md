# CODEX_WORKFLOW.md — CalisthenicsJourney

## Purpose

This file defines **how coding agents work** on CalisthenicsJourney. It keeps
repeatable engineering protocol in the repository so task prompts can stay
short and high-information.

It does not replace canonical product, architecture, or training truth in
`AGENTS.md`, `ARCHITECTURE.md`, and `SKILLS.md`.

## 1. Required reading

For substantial repository work, read in this order:

1. `AGENTS.md`;
2. `ARCHITECTURE.md`;
3. `SKILLS.md` when relevant;
4. `CODEX_WORKFLOW.md`;
5. the current `CODEX_HANDOFF.md` when relevant; and
6. source and tests directly relevant to the task.

A fresh agent context must be able to continue from repository state and the
handoff without old conversation transcripts.

## 2. Source-of-truth discipline

Current explicit task instructions and approved or locked product decisions
govern the requested work.

Canonical product and architecture truth belongs in:

- `AGENTS.md`;
- `ARCHITECTURE.md`; and
- `SKILLS.md`.

Regression tests protect approved behavior. Existing implementation and
prototype behavior are not automatically product truth.

If canonical documents materially conflict or a product decision is genuinely
ambiguous, do not invent a resolution. Report the smallest decision needed from
the project owner.

## 3. General engineering protocol

Prefer:

```text
understand
→ smallest coherent change
→ focused tests
→ full regression verification when appropriate
→ build
→ inspect diff and working tree
→ handoff
```

Avoid speculative abstractions, unrelated cleanup, future-phase
implementation, broad refactors without need, and name-based product behavior.

Preserve stable identity, historical evidence, derived-state boundaries, and
data-driven behavior.

## 4. Implementation checkpoints

Before editing:

- inspect relevant source and tests;
- inspect the working tree and identify unrelated changes;
- understand the approved phase boundary; and
- confirm the requested checkpoint and stopping point.

Implement only the requested checkpoint. Do not begin the next phase early.

For an approved implementation checkpoint:

- run focused tests;
- run the full regression suite when domain or persistence behavior changes;
- build;
- inspect the final diff and working tree;
- commit only checkpoint files;
- push; and
- stop and report if commit or push fails.

## 5. Testing

Tests are permanent regression protection.

For new semantics or corrected bugs:

- add focused regression coverage;
- test observable behavior;
- include important negative or malformed cases where relevant;
- preserve previous regression coverage; and
- avoid mechanically creating redundant tests.

A passing test suite is evidence, not proof.

### 5.1 Test-execution efficiency

During implementation, run the smallest relevant focused test set needed for
fast feedback. Do not rerun the entire regression suite after every edit. Reuse
existing build and test artifacts when safe, and avoid unnecessary clean
builds, rebuilds, simulator resets, or repeated full-suite runs.

When checkpoint implementation is complete, run the full regression suite
once. If it fails:

1. inspect the failing tests;
2. fix the issue;
3. rerun only the affected or failing tests first; and
4. after they pass, rerun the full regression suite before declaring the
   checkpoint complete.

For domain or persistence checkpoints, final verification is:

```text
focused tests during implementation
→ full regression suite once at implementation-complete
→ standalone build once
→ final diff and working-tree inspection
```

Keep successful test and build output concise in agent context. Store verbose
logs and result bundles outside conversational context, such as under `/tmp`,
and inspect detailed output only when a failure requires it.

Never delete, disable, skip, weaken, or consolidate meaningful regression tests
merely to reduce usage, runtime, or context. Focused testing is an execution
optimization, not a reduction in test coverage. Reuse migration fixtures and
other expensive regression fixtures once created; regenerate them only when
the schema checkpoint changes and regeneration is required.

Do not perform another exhaustive phase re-audit as part of a bounded
correction unless the correction changes foundational architecture or reveals
new systemic uncertainty.

## 6. SwiftData and migration

When persistence models change:

- prefer additive migration when practical;
- preserve stable IDs and historical evidence;
- inspect delete and relationship-nullification behavior;
- distinguish durable semantic IDs from optional live relationships where
  appropriate;
- test persistence round trips; and
- prove migration from the immediately preceding locked schema/store when the
  schema changes materially and such a fixture is feasible.

Do not claim migration safety solely from fresh or in-memory stores. Never
discard user history merely to simplify development unless explicitly
authorized.

## 7. Malformed persisted data

Domain services should terminate deterministically, avoid crashes, avoid
fabricating mastery or progression, and fail conservatively when semantic
identity cannot be resolved.

Use the smallest appropriate validation mechanism rather than creating a large
generic framework.

## 8. Launch sanity

Simulator launch duration is not production performance evidence.

Launch checks should focus on concrete app-controlled issues:

- crashes or hangs;
- migration loops;
- repeated expensive bootstrap work;
- unnecessary writes;
- obvious blocking work; and
- corrupted initial state.

Separate simulator and system overhead from app-controlled work.

## 9. Git discipline

Never modify, revert, stage, or delete unrelated working-tree changes.

Do not force-push, rewrite published history, amend published commits, or
include unrelated generated project-file normalization.

Audit-only tasks do not commit or push unless explicitly requested.

## 10. `CODEX_HANDOFF.md`

`CODEX_HANDOFF.md` is the durable bridge between fresh contexts.

For substantial implementation work, overwrite it with a concise,
self-contained report including:

- task or phase;
- result;
- what changed and important semantics;
- files changed;
- tests and verification;
- persistence or migration notes;
- risks and deferred work;
- working-tree and Git state;
- recommended next step; and
- commit hash when applicable.

Include exact model, service, function, and file names where important. Do not
paste giant diffs or transcripts.

## 11. Re-audit protocol

A re-audit challenges the completed phase rather than trusting its handoff.

Inspect:

- actual implementation and tests;
- relevant canonical decisions;
- interfaces with prerequisite locked phases;
- persistence and migration risks;
- competing sources of truth;
- name-based behavior;
- malformed-data behavior;
- missing regression coverage; and
- accidental scope expansion.

Do not automatically re-audit the entire historical application.

Classify findings as:

- Required before next phase;
- Recommended but safe to defer; or
- Later cleanup / optimization.

Use one final verdict:

- PASS;
- PASS WITH MINOR FOLLOW-UP; or
- FAIL / BLOCKED.

Audit-only work must not silently implement its findings.

## 12. Correction protocol

After an audit:

- implement only approved required corrections;
- do not repeat the entire phase;
- add regression tests for corrected failure modes;
- run appropriate affected and full verification; and
- write a new handoff.

Correction verification should be focused. Do not perform another exhaustive
full-phase audit unless the correction changes foundational architecture,
reveals systemic uncertainty, or the project owner explicitly requests one.

## 13. Phase locking

A phase is lockable when:

- approved semantics are implemented;
- required audit findings are resolved;
- relevant regression tests pass;
- required persistence or migration proof exists;
- the build succeeds;
- no blocker remains; and
- the handoff records the final state.

Later phases preserve locked behavior unless an explicit approved decision
changes it.

## 14. Context efficiency

Agent context is a limited engineering resource. Stable workflow instructions
belong here rather than in every prompt.

Task prompts should primarily contain the requested task or phase, unique
decisions, unusual risks, scope, and stopping point.

Prefer focused source inspection over repeatedly loading broad unrelated areas.
Do not repeatedly reread large unchanged files without reason.

Efficiency should come from concise prompts, durable repository instructions,
bounded scope, focused audits, and avoiding repeated proof of already locked
behavior. Do not trade correctness for lower usage.

The goal is maximum engineering confidence per unit of context and compute.

## 15. Stop instead of guessing

Stop and report when:

- an approved product rule is ambiguous;
- canonical sources materially conflict;
- implementation requires changing a locked decision;
- migration threatens existing data;
- required commit or push fails;
- an unrelated working-tree change would need modification; or
- the requested phase requires prematurely implementing a future phase.

Explain:

1. what is known;
2. what is blocked or ambiguous; and
3. the smallest owner decision needed.

## Project workflow

```text
durable product truth
→ bounded implementation
→ permanent regression evidence
→ independent focused audit
→ bounded correction
→ locked foundation
→ next phase
```
