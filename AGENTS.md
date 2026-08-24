# AGENTS.md --- CalisthenicsJourney

## Purpose

This file defines the product philosophy, core mechanics, and
architectural rules for **CalisthenicsJourney**. Any agent or developer
working on this project must read it before making product or
architectural changes.

It complements `ARCHITECTURE.md`, which protects software architecture
and implementation boundaries, and `SKILLS.md`, which is the canonical
source for approved V1 skill content and mastery progression.

**Do not silently redesign, remove, replace, or reinterpret the
decisions documented here.** If an implementation appears to require
changing one, explain the proposed change to the project owner and
obtain approval first. Implementation details may evolve when necessary,
but product behavior must not drift merely because another approach is
easier to code.

## 1. Product vision

CalisthenicsJourney is a personal iPhone training app that makes
learning calisthenics feel like a progression game **without artificial
game clutter**.

The game is the user's real physical progression.

The rewarding moments are mastering movements, completing skill-tree
stages, unlocking harder progressions, watching workouts evolve as ability
improves, and seeing completed branches of a skill tree.

Do not depend on coins, currencies, daily-login rewards, arbitrary
badges, energy systems, loot, or reward spam.

**Core principle: the user's real-world abilities are the
achievements.**

## 2. Development priorities

Prioritize, in order:

1.  Correct core mechanics.
2.  Reliable local persistence.
3.  Excellent workout logging UX.
4.  Correct skill progression and skill-driven workout generation.
5.  Editability/extensibility.
6.  Clear minimal interface.
7.  Visual polish and subtle feedback.
8.  Optional services such as iCloud.

V1 should be basic, dependable, and understandable before substantial
design work is added.

## 3. Primary navigation

The intended primary navigation has three areas.

### Dashboard

The high-level overview of the user's real demonstrated abilities and current
training state. It answers: **What can I do, what am I working toward, and what
has changed recently?**

The Dashboard summarizes progression; it does not own a separate progression
system. Skills and logged performance remain the sources of truth. Likely
Dashboard content includes active skills/goals, important current or next
targets, demonstrated abilities, and meaningful recent mastery/progress. Exact
V1 Dashboard content and visual design are intentionally deferred until later in
V1, after the skill/progression/workout systems produce meaningful data to
summarize.

### Workout

Where training happens. It provides a workout based on focused trainable skills,
allows overrides/editing, presents exercises one at a time, shows
previous results, records actual performance, and uses logged results as
progression evidence.

**The user's entered result is the source of truth.**

### Skills

The central progression system: visible/selectable skills, ordered goal
priority, skill trees, completed/current/future stages,
prerequisites, and meaningful mastery milestones.

Skills include advanced movements and basic movement families. Examples:
Handstand, Pull-up, L-Sit, Dips, Muscle-up, Push-up.

A Push-up can itself be a skill tree with easier and harder variants.

All skills should remain discoverable. The Skills area may present the same
underlying progression through both a **node map** and a **categorized list**.
A future/locked stage or incomplete prerequisite may affect progression
state or guidance, but should not hide a skill from exploration.

## 4. No dedicated Progress tab for now

A standalone Progress tab is not part of the current direction. Workout
history is useful but is not important enough for primary navigation.

Historical information should appear contextually: exercise history from
an exercise, skill-specific progress inside a skill, previous results
during workouts, workout history as a secondary screen, and future
graphs/PRs as secondary views.

## 5. Skills drive training

This is a core mechanic.

The user chooses and orders skills they want to learn. The app uses the
**current stage in each focused, trainable skill** to determine relevant
training.

Core flow:

**Choose skill → determine current stage → determine exercises
supporting that stage → assemble workout → train and log reality →
evaluate requirements → master stage → unlock next stage → future
workouts adapt.**

Workouts and skill trees must not become unrelated systems. Exercises in
generated workouts should have a clear purpose. General strength work
may exist when it supports overall foundation or relevant skills.

## 6. Skill trees

Each skill consists of progression stages/nodes. The approved V1 skill
catalog and mastery trees are defined in `SKILLS.md`; do not substitute
older conceptual examples for that canonical content.

Exact stages are editable product content and must not be permanently
encoded as application logic.

Nodes may be completed, current, available, or locked. Objective
completion requirements are preferred.

The tree itself is a major reward mechanism. It should make completed,
current, next, and locked progress obvious without decorative game
assets.

The architecture should not assume every tree will remain strictly
linear forever; future branches/connections must remain possible.

## 7. Mastery means demonstrated ability

One valid successful performance is sufficient when it meets an approved
mastery standard. Mastery records **what capability the athlete has actually
demonstrated**; it is separate from the multi-set prescription used to manage
repeatable training workload.

Mastery is derived from durable performance evidence. Current underperformance,
failed workouts, easier training choices, or temporary strength loss do not
erase it. If historical evidence is edited or deleted, affected mastery must be
reevaluated and may be revoked only when no remaining valid evidence proves it.

## 8. Normal workouts provide progression evidence

Do not require a separate test mode for ordinary mastery.

If the user reaches a requirement during a normal workout, that result
can satisfy the requirement automatically.

**Training → logged result → requirement evaluator →
evidence/mastery → skill progression.**

Progression should emerge naturally from training.

## 9. Exercise tracking is metric-driven

Do not create a separate coded screen/model class for every exercise.
Exercises specify what must be measured; the reusable workout UI adapts.

Current metrics:

### Reps

Examples: Push-ups, Pull-ups, Dips.

`Previous: 14 reps` `Today: [ ] reps`

### Seconds

Examples: Wall Handstand, timed holds, future L-Sit holds.

`Previous: 24 sec` `Today: [ ] sec`

### Weight + Reps

Examples: Lat Pulldown, Shoulder Press, Seated Cable Row, Leg Press, DB
Romanian Deadlift.

`Previous: 80 lb × 10` `Today: [ weight ] × [ reps ]`

Future measurements should extend this metric-driven architecture rather
than require hardcoded exercise screens.

## 10. Set semantics

For strength exercises, each recorded row is a set.

For skill practice such as Handstand, a timed effort may be better
presented as an **attempt**, even if storage reuses set-like records.

Presentation language may vary by exercise semantics without requiring
separate storage architecture.

## 11. Previous → current loop

During a workout, show the previous result and let the user enter
today's result.

If the app suggests a value that is too difficult and the user performs
something else, the user records what actually happened. That result
becomes the previous result next time.

**Reality overwrites the suggestion.**

## 12. Progressive overload

For rep-range strength work, the intended foundation is double
progression.

The goal is gradual improvement, not maximal effort on every set. A first
skill workout should calibrate a comfortable starting estimate with good
form and capacity remaining. Subsequent normal multi-set performance,
especially the first normal workout, establishes practical training
capacity as defined in `SKILLS.md`.

For typical supporting strength exercises, **8–12 reps is the default
starting range** unless the exercise or training purpose calls for a
different prescription. This is a default, not a universal rule.

The user should choose a resistance that allows controlled reps without
maximal effort. Future workouts should aim for gradual improvement within
the prescribed range. V1 skill-movement prescriptions follow the
calibration and deterministic three-set progression principles in `SKILLS.md`.

Example: Shoulder Press `3 × 8–12`.

`10/9/8 → 11/10/9 → 12/11/10 → 12/12/12`

For a typical `3 × 8–12` double-progression exercise, reaching the top
of the range across all prescribed sets with appropriate form and effort
(e.g. `12/12/12`) is the signal to increase resistance or difficulty.
Reps may then fall back toward the lower end of the range and build
upward again.

Not every exercise should use `8–12`. Skill practice, isometric holds,
controlled eccentrics, technique work, and other exercise types may use
different progression methods appropriate to their purpose.

Training prescriptions answer **how to improve**; mastery requirements
answer **what ability has been proven**. Normal workout results may
satisfy mastery requirements automatically, but workouts should not
become constant max-effort tests.

The app may recommend progression later, but recommendations never
override actual logged performance. Introductory guidance should be
contextual and concise rather than repeatedly interrupting every workout.

## 13. Workout generation and control

Generated workouts should be assembled from:

1.  focused trainable skills/current stages;
2.  exercises required to progress those stages;
3.  relevant general foundation work;
4.  available equipment;
5.  recovery/frequency rules if implemented later.

Users may select any number of skill goals and arrange them as an ordered
priority list. The top three selected, trainable, unfinished skills are the
current workout focus. Lower-priority selections wait in order until a focus
position opens or the user reorders them; do not rotate every selected skill
from workout to workout.

Generated workouts should normally fit within about **30–40 minutes** and
must not exceed **8 main exercises**. Eight is a ceiling, never a target. When
multiple focused skills benefit from
the same exercise or training quality, the generator should prefer useful
overlap rather than simply stacking separate exercise lists. Do not add filler
exercises merely to reach the duration target; workout duration should emerge
from useful training, optional preparation, and athlete-controlled rest.

Order useful work as optional preparation, direct skill work by skill priority,
then supporting work. Direct skill exercises outrank shared supporting work,
which outranks single-skill supporting work. Deduplicate a shared exercise
before spending workout slots on lower-value support.

Equipment availability is global, current athlete-profile data established
during onboarding and editable later. It changes the **training route**, not
the underlying skill goal, priority, or mastery standard. Never infer equipment
from selected skills, prescribe unavailable equipment, or invent a substitute
unless an explicit approved alternative exists. A selected but temporarily
untrainable skill keeps its history and priority while the next trainable skill
fills the current focus.

Generated workouts remain editable. The user should ultimately be able
to add/remove/reorder/replace exercises, alter sets and ranges, and
change appropriate tracking configuration.

Generation is assistance, not loss of control.

## 14. Overall levels are deferred from V1

Overall/Journey Levels are not part of the current V1 direction. The user's
progression should be represented directly by demonstrated abilities, mastered
skill-tree nodes, and current skill goals rather than compressed into an
artificial overall level.

Do not build new V1 product behavior around `JourneyLevel` or level
requirements. Existing prototype level models/UI are provisional legacy
foundation and should only be removed or migrated as an explicit implementation
checkpoint; do not delete them opportunistically while making unrelated changes.

The concept may be reconsidered later only if it gains a clear purpose that
strengthens the core training loop without duplicating the Skills progression
system.

## 15. No XP system for now

Do **not** add XP as a core mechanic without approval.

XP was considered and intentionally deferred because it creates a second
artificial progression system, requires balancing, can invite grinding,
creates another balancing burden, and adds complexity without
strengthening the fundamental training loop.

**The skill tree is the game.**

## 16. Achievements

Do not create a generic achievement tab merely to award arbitrary
badges.

Meaningful achievements are actual mastery: First Pull-up, 20 clean
Push-ups, 30-second Handstand, L-Sit, mastering a node, unlocking a new
progression.

These belong naturally in Dashboard/Skills.

Product philosophy: **"My achievements are real life."**

## 17. Skill availability, shared foundations, and prerequisites

Skills should remain **visible and selectable even when they are advanced**.
A user should be able to inspect the full progression of any skill and may
choose an advanced skill as one of their active goals without first
completing an artificial unlock sequence.

Advanced skills may have longer mastery paths that include a small number
of meaningful foundational requirements before skill-specific stages.
These foundations should reflect abilities that genuinely support the
skill, not arbitrary game gates.

Previously demonstrated ability must carry forward. If workout history has
already satisfied a requirement used by another skill path, that evidence
must count there as well. The user should not be required to repeat an
ability merely because it appears in a newly selected skill.

Completed foundational parts should remain visible in the skill progression
and appear completed rather than disappearing. This shows the user why
their previous training has moved them further into a newly selected skill.

Shared foundations must remain based on concrete requirements and logged
evidence rather than vague artificial capability levels. Avoid overcrowding
advanced skills with long prerequisite checklists; include only the minimum
meaningful foundation requirements needed to make the progression useful.

Skill selection controls intentional training, not progression eligibility.
Logged performance may satisfy requirements for any selected or deselected
skill when the same real ability is explicitly relevant.

Skill trees may eventually branch/connect, so do not design storage under
the assumption that every skill is forever a single linear list.

## 18. Editability is core

The app must not have a permanent content ceiling.

Eventually editable:

### Exercises

Name, tracking metrics, targets, and relevant properties.

### Workouts

Exercises, order, sets, target ranges, substitutions.

### Skills

Name, stages, stage order, prerequisites, requirements, exercises
supporting stages.

Initial built-in content is **seed data**, not immutable application
logic. Do not hardcode product content when it can reasonably be data.

## 19. Local-first persistence

V1 is intentionally local-first using SwiftData.

iCloud/CloudKit may be added later. Keep the model
migration/sync-friendly where practical: stable unique IDs,
creation/update timestamps for important editable entities, explicit
relationships, and minimal reliance on hardcoded positions/transient
state.

Do not introduce iCloud complexity before local mechanics are stable.

## 20. Current workout UX

Current principles:

-   one exercise screen at a time;
-   previous result when available;
-   directly editable current results;
-   targets prefilled for quick confirmation while actual results remain
    distinct and editable throughout the active workout;
-   metric-specific inputs;
-   numeric keyboard;
-   one Done control at the exercise-screen level;
-   Next Exercise / Finish Workout flow.

Workout UX must remain fast because it is used between real sets. Avoid
unnecessary dialogs and confirmation steps.

## 21. Remaining training content is NOT finalized

The V1 skill catalog, mastery trees, default exercise sequences, and
training-prescription philosophy are approved in `SKILLS.md`, while the
remaining training details and workout behavior are still under discussion.

Do not assume these prototype seed choices are final:

-   additional exercise choices beyond the approved default sequences;
-   exercise-specific rest, weekly frequency, and individual
    technique/control standards;
-   detailed multi-skill conflict/trimming behavior and coaching presentation;
-   workout-generation behavior.

Before substantially expanding training content, discuss additions to the
approved sequences, their prescriptions, objective form standards, and
how they form a balanced workout.

**Prototype seed data is not approved training doctrine.**

## 22. Minimal visual philosophy

The app should feel like a game **without game bling**.

Prefer clean typography, restrained icons, progress bars, connected
skill-tree nodes, clear current/completed/locked states, checkmarks,
subtle animations, restrained unlock feedback, future haptics where
useful, generous spacing, and strong hierarchy.

Avoid coins, gems, fake currencies, loot, daily-login mechanics, reward
spam, excessive glow/gradients, and custom assets merely to look
game-like.

Minimalism may be a permanent part of the product identity.

Meaningful feedback should respond to real training events such as completing
or exceeding a target, setting a personal best, validating a mastery node,
receiving a new prescription, completing a workout, or repeating an incomplete
target. The detailed emotional presentation is a later UI decision. Real
progression remains the primary game loop; do not add artificial reward systems
to substitute for it.

## 23. Core loop

**Choose what you want to learn** → **See your current skill-tree
position** → **Receive training based on current stages** → **Perform
the workout and log reality** → **Compare against previous performance**
→ **Automatically evaluate mastery** → **Recognize demonstrated
achievements** → **Master nodes/unlock progressions** → **Workout
adapts to new ability** → **Continue progressing**

If a feature does not strengthen this loop, question it before adding
it.

## 24. Agent rules

1.  Read this file first.
2.  Preserve the core loop.
3.  Do not add/change major product mechanics without project-owner
    approval.
4.  Do not introduce XP without approval.
5.  Do not restore a dedicated Progress tab without approval.
6.  Do not hardcode every exercise into a separate screen/class.
7.  Keep exercise logging metric-driven.
8.  Keep workouts editable/extensible.
9.  Keep skills editable/extensible.
10. Do not introduce Overall/Journey Levels into V1 without approval.
11. Treat actual logged performance as authoritative.
12. Let normal workouts satisfy progression requirements.
13. Keep mastery derived from valid historical evidence and separate from
    prescription state.
14. Keep V1 local-first.
15. Prioritize functionality over visual polish.
16. Do not treat seed workout content as finalized.
17. Avoid systems that do not directly support the core loop.
18. Before changing a documented decision, explain why and obtain
    approval.
19. Prefer the smallest implementation change that preserves the agreed
    architecture.
20. When uncertain about product behavior, ask the project owner rather
    than inventing a new rule.
21. Treat each coherent change as a separate checkpoint. Document what
    changed and how it was verified in a clear Git commit message and in
    the agent's handoff. Update the relevant project documentation when
    product behavior, architecture, setup, or usage changes.
22. After verifying each change, commit only the files belonging to that
    change and push the commit to the current branch's configured remote
    before beginning the next change.
23. If committing or pushing fails, stop before making another change and
    report the failure to the project owner. Do not leave multiple
    completed changes accumulated only in the working tree.
24. Do not amend, squash, rewrite published history, or force-push unless
    the project owner explicitly requests it.
25. Before committing a checkpoint, inspect the working tree and
    distinguish changes made for the current task from pre-existing or
    unrelated changes. Commit only files and changes required for the
    approved checkpoint. Do not modify, revert, stage, clean up, or include
    unrelated working-tree changes without explicit project-owner approval.
    Leave unrelated changes untouched and mention them in the checkpoint
    handoff. Automatically generated or normalized project-file changes
    must not be included unless they are required by the current
    implementation.

## 25. Current development state

The project currently has a functioning SwiftUI/SwiftData prototype with
local persistence, workout sessions, exercise/set logs,
previous-vs-current results, metric-driven entry (reps, seconds,
weight + reps), numeric keyboard dismissal, an initial Dashboard/Journey
prototype, Skills, provisional level-requirement models, and a
workout-history prototype.

The repository has an initial V1 Git checkpoint.

The current prototype is a foundation, not the final information
architecture.

The next major design task is to finalize **remaining validation standards,
weekly frequency, and edge-case workout-generation behavior** before
broad editing interfaces or visual polish.

## 26. Product test

For every new idea, ask:

> **Does this help the user understand what they are trying to learn,
> train toward it, record reality, and visibly master the next
> real-world ability?**

If yes, it probably belongs.

If it mostly creates artificial engagement without improving that
journey, it probably does not.
