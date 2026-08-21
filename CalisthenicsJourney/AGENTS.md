# AGENTS.md --- CalisthenicsJourney

## Purpose

This file defines the product philosophy, core mechanics, and
architectural rules for **CalisthenicsJourney**. Any agent or developer
working on this project must read it before making product or
architectural changes.

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
stages, unlocking harder progressions, meeting level requirements,
watching workouts evolve as ability improves, and seeing completed
branches of a skill tree.

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

### Journey

The high-level overview. It answers: **Where am I overall, what am I
working toward, and what must I master next?**

It should eventually show current overall level, level requirements and
their completion, active skills, important current targets, and
meaningful recent unlocks/mastery where useful.

### Workout

Where training happens. It provides a workout based on active skills,
allows overrides/editing, presents exercises one at a time, shows
previous results, records actual performance, and uses logged results as
progression evidence.

**The user's entered result is the source of truth.**

### Skills

The central progression system: available/active/locked skills, skill
trees, completed/current/future stages, prerequisites, and meaningful
mastery milestones.

Skills include advanced movements and basic movement families. Examples:
Handstand, Pull-up, L-Sit, Dips, Muscle-up, Push-up.

A Push-up can itself be a skill tree with easier and harder variants.

## 4. No dedicated Progress tab for now

A standalone Progress tab is not part of the current direction. Workout
history is useful but is not important enough for primary navigation.

Historical information should appear contextually: exercise history from
an exercise, skill-specific progress inside a skill, previous results
during workouts, workout history as a secondary screen, and future
graphs/PRs as secondary views.

## 5. Skills drive training

This is a core mechanic.

The user chooses skills they want to learn. The app uses the user's
**current stage in each active skill** to determine relevant training.

Core flow:

**Choose skill → determine current stage → determine exercises
supporting that stage → assemble workout → train and log reality →
evaluate requirements → master stage → unlock next stage → future
workouts adapt.**

Workouts and skill trees must not become unrelated systems. Exercises in
generated workouts should have a clear purpose. General strength work
may exist when it supports overall foundation or relevant skills.

## 6. Skill trees

Each skill consists of progression stages/nodes. A conceptual Handstand
tree could be:

**Wrist/shoulder preparation → Wall Handstand → Wall Balance Drills →
Freestanding Attempts → 5s Freestanding → 15s Freestanding → 30s
Freestanding → Mastered**

Exact stages are editable product content and must not be permanently
encoded as application logic.

Nodes may be completed, current, available, or locked. Objective
completion requirements are preferred.

The tree itself is a major reward mechanism. It should make completed,
current, next, and locked progress obvious without decorative game
assets.

The architecture should not assume every tree will remain strictly
linear forever; future branches/connections must remain possible.

## 7. Mastery means repeatable ability

A single lucky result should not necessarily equal mastery.

Important mastery requirements are confirmed across **separate workout
sessions**. The initial convention is often **2 confirmations**, but
confirmation count should ultimately be configurable.

Example: `20 clean Push-ups ×2`.

Workout A reaches 20 → 1/2. A later Workout B reaches 20+ → 2/2 →
mastered.

Two qualifying sets in the same workout do not count as two separate
confirmations unless a future requirement explicitly defines different
semantics.

## 8. Normal workouts provide progression evidence

Do not require a separate test mode for ordinary mastery.

If the user reaches a requirement during a normal workout, that result
can satisfy the requirement automatically.

**Training → logged result → requirement evaluator →
confirmation/mastery → skill/level progression.**

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

Example: Shoulder Press `3 × 8–12`.

`10/9/8 → 11/10/9 → 12/11/10 → 12/12/12`

Once the target is mastered with appropriate form/effort, weight can
increase and reps can fall toward the lower end.

The app may recommend progression later, but recommendations never
override actual logged performance.

## 13. Workout generation and control

Generated workouts should be assembled from:

1.  active skills/current stages;
2.  exercises required to progress those stages;
3.  relevant general foundation work;
4.  current overall level where appropriate;
5.  recovery/frequency rules if implemented later.

Generated workouts remain editable. The user should ultimately be able
to add/remove/reorder/replace exercises, alter sets and ranges, and
change appropriate tracking configuration.

Generation is assistance, not loss of control.

## 14. Overall levels

Overall Level and individual Skill progression are separate.

Example: a user may be Level 3 overall while Handstand is 5/7, Pull-up
3/6, L-Sit 2/6, and Push-up 6/8.

Overall levels represent broader calisthenics development/foundation.
Skill trees represent specific abilities.

Overall levels should advance through meaningful requirements, not
arbitrary XP totals.

Exact level content must be discussed and approved before being
considered canonical.

## 15. No XP system for now

Do **not** add XP as a core mechanic without approval.

XP was considered and intentionally deferred because it creates a second
artificial progression system, requires balancing, can invite grinding,
makes overall levels less meaningful, and adds complexity without
strengthening the fundamental training loop.

**The skill tree is the game.**

## 16. Achievements

Do not create a generic achievement tab merely to award arbitrary
badges.

Meaningful achievements are actual mastery: First Pull-up, 20 clean
Push-ups, 30-second Handstand, L-Sit, mastering a node, unlocking a new
progression.

These belong naturally in Journey/Skills.

Product philosophy: **"My achievements are real life."**

## 17. Locked skills and prerequisites

Some skills may require explicit prerequisites. Example: Muscle-up may
depend on sufficient Pull-up and Dip development.

Prerequisites should be represented as data rather than hardcoded UI
text.

Skill trees may eventually branch/connect, so do not design storage
under the assumption that every skill is forever a single linear list.

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

### Levels

Names/numbers, requirements, confirmation counts, unlock conditions.

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
-   metric-specific inputs;
-   numeric keyboard;
-   one Done control at the exercise-screen level;
-   Next Exercise / Finish Workout flow.

Workout UX must remain fast because it is used between real sets. Avoid
unnecessary dialogs and confirmation steps.

## 21. Training content is NOT finalized

Architecture is becoming defined, but exact training content is still
under discussion.

Do not assume these prototype seed choices are final:

-   Hollow Body Hold as a Level 1 requirement;
-   exact Level 1 exercises;
-   exact Level 1 mastery requirements;
-   exact Pull-up progression;
-   exact L-Sit progression;
-   exact Handstand progression;
-   future level contents.

Before substantially expanding training content, discuss active skills,
correct progression stages, exercises supporting each stage, measurable
mastery conditions, and how those exercises form a balanced workout.

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

## 23. Core loop

**Choose what you want to learn** → **See your current skill-tree
position** → **Receive training based on current stages** → **Perform
the workout and log reality** → **Compare against previous performance**
→ **Automatically evaluate mastery** → **Confirm repeatable achievements
across sessions** → **Master nodes/unlock progressions** → **Workout
adapts to new ability** → **Continue the journey**

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
10. Keep levels editable/extensible.
11. Keep overall levels separate from skill progression.
12. Treat actual logged performance as authoritative.
13. Let normal workouts satisfy progression requirements.
14. Preserve separate-session mastery confirmation.
15. Keep V1 local-first.
16. Prioritize functionality over visual polish.
17. Do not treat seed workout content as finalized.
18. Avoid systems that do not directly support the core loop.
19. Before changing a documented decision, explain why and obtain
    approval.
20. Prefer the smallest implementation change that preserves the agreed
    architecture.
21. When uncertain about product behavior, ask the project owner rather
    than inventing a new rule.
22. Treat each coherent change as a separate checkpoint. Document what
    changed and how it was verified in a clear Git commit message and in
    the agent's handoff. Update the relevant project documentation when
    product behavior, architecture, setup, or usage changes.
23. After verifying each change, commit only the files belonging to that
    change and push the commit to the current branch's configured remote
    before beginning the next change.
24. If committing or pushing fails, stop before making another change and
    report the failure to the project owner. Do not leave multiple
    completed changes accumulated only in the working tree.
25. Do not amend, squash, rewrite published history, or force-push unless
    the project owner explicitly requests it.

## 25. Current development state

The project currently has a functioning SwiftUI/SwiftData prototype with
local persistence, workout sessions, exercise/set logs,
previous-vs-current results, metric-driven entry (reps, seconds,
weight + reps), numeric keyboard dismissal, initial
Journey/Skills/level-requirement models, and a workout-history
prototype.

The repository has an initial V1 Git checkpoint.

The current prototype is a foundation, not the final information
architecture.

The next major design task is to finalize **skill-driven workout
architecture and initial training content** before broad editing
interfaces or visual polish.

## 26. Product test

For every new idea, ask:

> **Does this help the user understand what they are trying to learn,
> train toward it, record reality, and visibly master the next
> real-world ability?**

If yes, it probably belongs.

If it mostly creates artificial engagement without improving that
journey, it probably does not.
