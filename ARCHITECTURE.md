# ARCHITECTURE.md --- CalisthenicsJourney

## Purpose

This document defines the intended software architecture for
**CalisthenicsJourney**.

It complements `AGENTS.md`.

-   `AGENTS.md` protects the **product mechanics and design
    philosophy**.
-   `ARCHITECTURE.md` protects the **code structure and implementation
    boundaries**.

Any coding agent or developer making structural changes should read both
files first.

The goal is a codebase that is:

-   minimal enough for a personal iOS app;
-   modular enough to understand quickly;
-   easy to extend;
-   easy to change;
-   resistant to hardcoded special cases;
-   data-driven;
-   testable at the core-logic level;
-   friendly to future features such as editing, iCloud sync, richer
    skill trees, and workout generation.

Do not introduce enterprise complexity for its own sake. Avoid
unnecessary frameworks, service layers, dependency-injection systems,
protocol hierarchies, and abstractions unless the product actually needs
them.

**Prefer the smallest architecture that keeps product logic separate,
data-driven, and replaceable.**

------------------------------------------------------------------------

# 1. Core architectural principles

## 1.1 Views display state and collect input

SwiftUI views should primarily:

-   display model state;
-   collect user input;
-   navigate;
-   trigger actions;
-   render reusable components.

Views should **not own the core training rules**.

Bad:

``` swift
if exercise.name == "Push-ups" && reps >= 20 {
    level.isCompleted = true
}
```

Better:

``` text
View logs result
→ RequirementEvaluator evaluates result
→ ProgressionEngine determines what becomes mastered/unlocked
→ model state changes
→ View reflects new state
```

This boundary is extremely important.

------------------------------------------------------------------------

## 1.2 Behavior must be data-driven, not name-driven

Never depend on display names such as:

-   `"Push-ups"`
-   `"Wall Handstand"`
-   `"Lat Pulldown"`
-   `"Muscle-up"`

to determine behavior.

Names are editable content.

Behavior should depend on data such as:

-   exercise ID;
-   tracking metrics;
-   target reps;
-   target duration;
-   target weight;
-   linked skill stage;
-   linked requirement;
-   prerequisites;
-   confirmation count;
-   unlock relationships.

The app should continue to work if the user renames:

`Push-ups`

to:

`Standard Push-up`

or any custom name.

------------------------------------------------------------------------

## 1.3 IDs establish identity

Editable entities should use stable unique IDs.

Examples:

-   Exercise
-   WorkoutTemplate
-   WorkoutSession
-   Skill
-   SkillStage
-   Requirement

Relationships should use model relationships or stable IDs rather than
string matching.

Display names are not identifiers.

------------------------------------------------------------------------

## 1.4 Core rules belong in engines

Complex or reusable product logic should live in small focused
engine/service types rather than views.

Likely core engines:

-   `WorkoutGenerator`
-   `RequirementEvaluator`
-   `ProgressionEngine`

Potential later additions:

-   `ProgressiveOverloadAdvisor`
-   `WorkoutValidator`
-   `MigrationCoordinator`

Do not create an engine merely because it sounds architectural. Create
one when logic has become reusable or should be isolated from UI.

------------------------------------------------------------------------

## 1.5 Seed content is data

Initial workouts, skills, and stages are seed data.

They are not application logic.

A coding agent must not add special-case code just because the current
seed content happens to contain Handstand, Push-ups, or Pull-ups.

------------------------------------------------------------------------

## 1.6 Extend the model before adding special-case UI

If a new exercise needs different tracking behavior, first ask:

> Is this actually a new measurement type or semantic property?

If yes, extend the data model.

Do not create:

``` swift
if exercise.name == "Handstand" { ... }
```

when the real distinction is:

``` swift
exercise.metric == .seconds
```

------------------------------------------------------------------------

# 2. Suggested project organization

The project should gradually move toward a feature-based modular
structure.

A practical target:

``` text
CalisthenicsJourney
│
├── App
│   ├── CalisthenicsJourneyApp.swift
│   └── RootTabView.swift
│
├── Models
│   ├── Exercise.swift
│   ├── WorkoutTemplate.swift
│   ├── WorkoutSession.swift
│   ├── TrainingLog.swift
│   ├── Skill.swift
│   ├── SkillStage.swift
│   ├── Requirement.swift
│   └── UnlockRule.swift
│
├── Features
│   │
│   ├── Dashboard
│   │   ├── DashboardView.swift
│   │   └── ...
│   │
│   ├── Workout
│   │   ├── WorkoutHomeView.swift
│   │   ├── ActiveWorkoutView.swift
│   │   ├── ExerciseEntryView.swift
│   │   ├── SetEntryCard.swift
│   │   └── ...
│   │
│   └── Skills
│       ├── SkillsView.swift
│       ├── SkillDetailView.swift
│       ├── SkillTreeView.swift
│       └── ...
│
├── Engine
│   ├── WorkoutGenerator.swift
│   ├── RequirementEvaluator.swift
│   └── ProgressionEngine.swift
│
├── Components
│   ├── MetricInputView.swift
│   ├── ProgressBar.swift
│   ├── SkillNodeView.swift
│   └── ...
│
├── Data
│   ├── SeedData.swift
│   └── ...
│
└── Utilities
    └── ...
```

This is a direction, not a requirement to immediately split every
existing file.

Avoid creating dozens of tiny files solely to satisfy the diagram.

Refactor when a file becomes difficult to reason about or when logic
gains a clear reusable responsibility.

------------------------------------------------------------------------

# 3. Model responsibilities

## 3.1 Exercise

An `Exercise` represents a trainable activity.

It should eventually contain data such as:

-   stable ID;
-   display name;
-   tracking configuration;
-   semantic category if useful;
-   equipment requirements where relevant;
-   progression guidance where relevant;
-   creation/update timestamps.

Progression guidance should describe how the exercise is normally trained
without tying behavior to its name. Examples may include rep-range/double
progression, duration progression, controlled eccentric work, or a harder
variation. Keep this representation small and add new progression types
only when the product needs them.

It should **not** contain UI-specific state.

An Exercise does not know which SwiftUI screen renders it.

------------------------------------------------------------------------

## 3.2 Exercise metric configuration

Exercise entry must remain metric-driven.

Current supported measurement patterns:

### Reps

``` text
[ reps ]
```

### Seconds

``` text
[ seconds ]
```

### Weight + Reps

``` text
[ weight ] × [ reps ]
```

Future possibilities might include:

-   distance;
-   assisted weight;
-   added weight;
-   hold duration plus reps;
-   RIR/RPE;
-   tempo;
-   unilateral side.

Future extensions should be modeled as data, not exercise-name branches.

If the simple `ExerciseMetric` enum eventually becomes too restrictive,
it may evolve toward something like a set of measurement components.

Example conceptual future model:

``` text
ExerciseMeasurement
- reps
- weight
- seconds
```

and an Exercise could specify:

``` text
measurements = [.weight, .reps]
```

Do not introduce this complexity until needed.

------------------------------------------------------------------------

## 3.3 WorkoutTemplate

A workout template represents a planned collection of exercises.

It should contain:

-   stable ID;
-   name;
-   ordered exercise entries;
-   target sets;
-   target rep ranges or duration where relevant;
-   optional generation metadata later.

A generated workout may become a template/snapshot before the user
starts.

The user must be able to override generated content.

------------------------------------------------------------------------

## 3.4 WorkoutSession

A `WorkoutSession` represents something the user actually performed.

It is historical truth.

It should store a snapshot of what happened rather than depend entirely
on the current workout template.

If a template changes tomorrow, yesterday's session must remain
understandable.

Store relevant snapshot data such as:

-   session date;
-   workout name at the time;
-   exercise ID;
-   exercise name at the time if useful for history;
-   exercise metric configuration at the time;
-   entered sets/results.

This distinction helps future editing and migrations.

------------------------------------------------------------------------

## 3.5 ExerciseLog and SetLog

An `ExerciseLog` represents the result of one exercise within a workout
session.

A `SetLog` represents one recorded effort.

Set-like storage may also represent attempts for skill practice.

Keep storage generic, while UI language may display:

-   Set
-   Attempt

depending on semantic context.

------------------------------------------------------------------------

## 3.6 Skill

A Skill represents an ability/progression family.

Examples:

-   Handstand
-   Pull-up
-   Push-up
-   L-Sit
-   Dips
-   Muscle-up

A Skill should own or relate to:

-   stable ID;
-   name;
-   optional display icon/emoji;
-   ordered or graph-connected stages;
-   shared/foundational requirements where relevant;
-   one or more presentation category tags where useful;
-   active/inactive selection state.

Category tags are for discovery and filtering only. A skill may appear in
multiple categories (for example Foundation + Push, or Pull + Core +
Advanced). Categories must not determine mastery, prerequisites, or workout
behavior.

Skills remain visible/selectable independently of progression state. Active
state means the WorkoutGenerator should prioritize that goal; it does not
mean inactive skills are unable to receive valid progression evidence.

A Skill must remain editable.

------------------------------------------------------------------------

## 3.7 SkillStage

A SkillStage represents one progression node.

It may eventually include:

-   stable ID;
-   title;
-   explanation;
-   progression order or graph connections;
-   mastery requirements;
-   prerequisite stage IDs;
-   exercises recommended for this stage;
-   unlocked/completed state derived from progression data.

Avoid storing too much redundant state if it can be derived reliably.

For example, if completion can be determined from requirements, do not
also maintain multiple competing booleans unless there is a clear
reason.

------------------------------------------------------------------------

## 3.8 Dashboard

Dashboard is a presentation feature, not a progression model. It should derive
its overview from existing skill, requirement, workout-history, and progression
data rather than persist a competing overall-level state. Exact Dashboard
content is intentionally deferred until later in V1.

`JourneyLevel` is not part of the intended V1 architecture. Existing prototype
level code may remain temporarily until a deliberate cleanup/migration
checkpoint, but new V1 architecture should not depend on it.

------------------------------------------------------------------------

# 4. Generic requirement architecture

Requirements are central to the progression system.

A requirement should describe **what must become true**, not contain
custom code for a named exercise.

Conceptual data:

``` text
Requirement
- id
- metric type
- linked exercise / skill / stage
- target value(s)
- confirmations needed
- confirmation scope
```

Examples:

### Reps requirement

``` text
Exercise ID: <standard push-up UUID>
Metric: reps
Target: 20
Confirmations: 2 separate sessions
```

### Duration requirement

``` text
Exercise ID: <wall handstand UUID>
Metric: seconds
Target: 30
Confirmations: 2 separate sessions
```

### Weight + reps requirement

``` text
Exercise ID: <lat pulldown UUID>
Metric: weightAndReps
Target weight: 100 lb
Target reps: 12
Confirmations: 2 separate sessions
```

The evaluator should not care about the display name.

------------------------------------------------------------------------

# 5. RequirementEvaluator

`RequirementEvaluator` should answer questions such as:

> Does this logged performance satisfy this requirement?

and:

> How many distinct qualifying sessions exist for this requirement?

It should understand requirement metrics but not UI.

Conceptual responsibilities:

``` text
Input:
- Requirement
- relevant workout history

Output:
- confirmation count
- satisfied/mastered state
```

For separate-session mastery, it should count qualifying **sessions**,
not qualifying sets.

If one session contains three qualifying sets, that still counts as one
confirmation when the requirement's scope is separate sessions.

------------------------------------------------------------------------

# 6. Generic progression architecture

Progression logic must be generic and data-driven.

Do not write special methods such as:

``` swift
unlockNamedSkillStage()
unlockHandstandStage4()
unlockLevel2()
```

unless such methods are thin conveniences around a generic engine.

The generic flow is:

``` text
Logged performance
        ↓
RequirementEvaluator
        ↓
Requirement state
        ↓
ProgressionEngine
        ↓
Stage / level / shared requirement state changes
```

Skills themselves are normally visible and selectable rather than hidden
behind hard unlocks. Progression may still determine which stages are
completed/current/future and skill-stage progression state.

A requirement may be relevant to more than one skill path. The same logged
evidence must be reusable wherever the same concrete ability is required.
Do not duplicate or reset proof simply because a user activates a different
skill.

Possible progression consequences include:

-   a SkillStage becoming completed/current;
-   another SkillStage branch becoming relevant;
-   shared foundational requirements appearing already completed;
-   a new exercise/progression becoming appropriate;
-   another future progression consequence.

------------------------------------------------------------------------

# 7. Progression rule types

Keep progression rules simple but extensible.

The engine should eventually support concepts such as:

## ALL

Every prerequisite must be satisfied.

Example:

``` text
Complete Stage X when:
- requirement A mastered
AND
- requirement B mastered
```

## ANY

At least one prerequisite is sufficient.

Example:

``` text
Make an alternate progression current when:
- requirement A
OR
- requirement B
```

## CONFIRMATIONS

A measurable result must be achieved N times under a defined scope.

Current important scope:

``` text
N distinct workout sessions
```

## PREREQUISITE ENTITY

Another entity must already be mastered/completed.

Examples:

``` text
SkillStage A completed
Skill B prerequisite node completed
```

Do not overgeneralize this into an elaborate rules DSL until the product
requires it.

A small clear model is preferred.

------------------------------------------------------------------------

# 8. ProgressionEngine

`ProgressionEngine` decides what progression consequences follow from
evaluated requirements.

It should be independent from SwiftUI.

Possible responsibilities:

-   determine whether a SkillStage is mastered;
-   determine the user's current position in a skill progression;
-   reuse qualifying evidence across every requirement that references the
    same demonstrated ability;
-   recognize already-satisfied foundational requirements when a new skill
    is selected;
-   expose progression changes so the UI can present meaningful mastery
    feedback.

The engine should not generate celebration UI.

It determines **what changed**.

The View determines **how to present it**.

------------------------------------------------------------------------

# 9. Skill tree topology

V1 may begin with ordered/linear stages.

However, storage should not make branching impossible.

Avoid deeply encoding:

``` text
stageIndex + 1 == next stage
```

as the only possible progression model forever.

A simple implementation can still use order initially, but stable stage
IDs should make later graph connections possible.

A future node may have:

``` text
prerequisiteStageIDs = [...]
nextStageIDs = [...]
```

Only add this when branching is actually implemented.

------------------------------------------------------------------------

# 10. WorkoutGenerator

`WorkoutGenerator` should eventually assemble a workout based on current
user goals.

Inputs may include:

-   active Skills;
-   current Stage for each Skill;
-   exercises linked to those stages;
-   general foundation exercises;
-   available equipment;
-   user overrides/preferences;
-   later recovery/frequency information.

Product constraints for generation:

-   no more than 3 active skills;
-   no more than 8 exercises in a generated workout;
-   target a practical workout duration of roughly 30–40 minutes;
-   prefer useful exercise overlap when multiple skills need similar work;
-   adapt supporting exercises to available equipment without changing the
    underlying skill mastery requirement.

Equipment should be modeled as data (for example, pull-up bar, resistance
band, dumbbell, cable machine) rather than inferred from exercise names.
A supporting exercise may declare one or more equipment requirements.
The generator may choose an appropriate alternative route when one exists;
it must not invent a false equivalent when a skill stage genuinely needs
specific equipment.

Output:

``` text
Generated WorkoutTemplate
```

The generator should not save fake performance.

It creates a plan.

The actual `WorkoutSession` remains separate and stores what the user
really did.

------------------------------------------------------------------------

# 11. Generated workout vs performed workout

This separation is important.

## Planned / generated

``` text
Wall Handstand
3 attempts
target: 20–30 sec
```

## Performed

``` text
Attempt 1: 24 sec
Attempt 2: 21 sec
Attempt 3: 18 sec
```

The app may recommend.

The session records reality.

If the user changes weight, reps, exercise selection, or another value,
historical data must reflect the real result.

------------------------------------------------------------------------

# 12. Manual workout editing

Generated workouts must remain editable.

Editing should modify the plan, not progression history.

Potential operations:

-   add exercise;
-   remove exercise;
-   reorder exercise;
-   replace exercise;
-   change target sets;
-   change target rep range;
-   change target duration.

If an edit breaks a relationship to a skill requirement, the UI may
eventually warn the user, but the app should not silently overwrite
their choices.

------------------------------------------------------------------------

# 13. Skill-to-exercise relationships

Skills and workout exercises need explicit data relationships.

A SkillStage may relate to exercises by role, for example:

``` text
SkillStageExercise
- stage ID
- exercise ID
- role
- priority
```

Possible roles later:

-   primary skill practice;
-   strength support;
-   accessory;
-   prerequisite preparation.

Do not add this extra model until needed, but preserve the conceptual
separation.

An exercise can support multiple skills.

Example:

Shoulder Press may support:

-   Handstand strength;
-   pushing foundation.

Therefore, do not enforce one Exercise → one Skill.

------------------------------------------------------------------------

# 14. Requirement ownership

A requirement can belong to different progression concepts.

Examples:

-   SkillStage mastery requirement;
-   shared/foundational skill requirement;

Avoid duplicating evaluation logic for each owner type.

Instead:

``` text
Owner
→ has requirements
→ RequirementEvaluator evaluates them
→ ProgressionEngine interprets completion for that owner
```

Ownership must not make evidence exclusive. Multiple skill paths may define
or reference requirements satisfied by the same real performance evidence.
A workout result is global historical evidence and should not become
"consumed" by one skill.

------------------------------------------------------------------------

# 15. Avoid duplicated progression state

Be careful with storing both:

-   `isCompleted`
-   and requirements that independently imply completion.

If both exist, define a clear source of truth.

Preferred direction:

-   requirements/results are source data;
-   progression status is derived where practical;
-   persisted status is acceptable when needed for performance,
    migrations, or explicit historical unlock moments, but it must not
    contradict requirement state.

Any cached/derived state should have a clear update path.

------------------------------------------------------------------------

# 16. Persistence boundaries

SwiftData is the current persistence layer.

Views may use SwiftData queries for straightforward display, but complex
logic should not be tightly coupled to SwiftData-specific query syntax.

For example:

Bad architecture:

``` text
Every view implements its own progression query and requirement math.
```

Preferred:

``` text
SwiftData provides models/history
→ evaluator receives model collections
→ evaluator returns progression result
```

This makes future changes and testing easier.

Do not add a repository abstraction purely to hide SwiftData unless
there is an actual need.

------------------------------------------------------------------------

# 17. iCloud readiness

V1 is local-first.

Architecture should make eventual CloudKit/iCloud migration possible
without forcing it now.

Useful practices:

-   stable UUIDs;
-   created/updated timestamps;
-   explicit relationships;
-   historical snapshots where needed;
-   avoid relying on global singleton memory state;
-   avoid identity based on names.

Do not implement sync logic until requested.

------------------------------------------------------------------------

# 18. Performance and resource principles

CalisthenicsJourney should remain lightweight by default.

This is not a mandate for premature micro-optimization. It is an
architectural constraint that normal usage should stay fast, responsive,
memory-conscious, and energy-efficient.

The app is a local-first training tool with relatively small amounts of
structured data. Core screens and workout entry should therefore feel
effectively instant under normal use.

The scalability guidance in this section is forward-looking. Direct
queries and full-history evaluation are acceptable while they remain the
smallest clear solution for the current data scale. Do not introduce
caches, repository layers, migration infrastructure, or other complexity
until measurement or an actual product need justifies them.

## 18.1 Startup

Keep launch-time work minimal.

Do not:

-   scan or evaluate the complete workout history synchronously on every
    launch unless genuinely required;
-   rebuild every skill tree at startup;
-   perform expensive migrations repeatedly after they have completed;
-   block initial UI presentation on work that can safely happen later;
-   start unnecessary network requests, timers, or background tasks
    during launch.

Required migrations and first-install seed work should be bounded and
idempotent. If migration work later becomes expensive at realistic data
scale, measure it before adding version markers or other infrastructure
to separate it from ordinary runtime work.

## 18.2 Data loading

Fetch only the data a screen or engine actually needs.

As the amount of stored history grows, consider:

-   narrow SwiftData queries;
-   relevant recent/history slices when full history is unnecessary;
-   targeted evaluation for requirements currently being displayed or
    changed;
-   lazy or on-demand loading for secondary history screens.

Avoid loading the complete training database into memory merely for
convenience once measurement shows that doing so is materially costly.
The architecture should eventually handle long histories without
requiring the user to delete old workouts.

## 18.3 Recalculation

Do not repeatedly recompute expensive derived state on every SwiftUI
redraw.

Examples of derived work that may eventually need careful handling:

-   requirement confirmation counts;
-   complete skill-tree state;
-   generated workout plans;
-   historical personal-record calculations;
-   charts across long histories.

Keep the source of truth clear. Cache derived results only when
measurement shows a meaningful benefit and when the cache has a reliable
invalidation/update path.

Do not persist redundant derived state merely to avoid simple
calculations.

## 18.4 Background work and energy

Background activity should be minimal.

Do not add:

-   continuous polling;
-   constantly running timers outside active use;
-   unnecessary location/background modes;
-   frequent background refreshes;
-   repeated database scans while the app is idle.

Timers needed during an active workout should stop when no longer
needed.

Future iCloud synchronization should use platform-provided mechanisms
rather than aggressive manual polling.

## 18.5 Dependencies

Prefer native Apple frameworks such as SwiftUI, SwiftData, Charts,
CloudKit, HealthKit, and related platform APIs when they satisfy the
requirement.

Do not introduce a third-party framework for functionality that can be
implemented clearly with native APIs unless the dependency provides
substantial value.

Every dependency adds potential:

-   app size;
-   startup cost;
-   memory cost;
-   update burden;
-   security/supply-chain surface;
-   architectural coupling.

Dependencies should therefore be deliberate.

## 18.6 Assets

Keep bundled assets appropriately sized.

Avoid:

-   large decorative image packs;
-   unnecessarily high-resolution assets;
-   bundled video/audio that does not serve core functionality;
-   duplicate asset variants that the platform can generate or scale
    efficiently.

The minimal visual philosophy should also help keep the binary and
runtime footprint small.

## 18.7 Measurement before optimization

Do not guess at performance problems.

When startup time, CPU, memory, database work, or energy use becomes a
concern, measure it with appropriate Xcode/Instruments tooling before
making significant optimization changes.

Do not add speculative caches, background queues, persistence layers, or
architectural complexity solely because they might be faster.

The preferred sequence is:

``` text
observe a real performance concern
→ measure
→ identify the actual bottleneck
→ make the smallest effective change
→ measure again
```

## 18.8 Performance invariant

> **Core screens and workout entry must not depend on network access or
> heavy background computation and should feel immediate during normal
> use.**

Performance improvements must not compromise the product's sources of
truth, editability, or correctness.

------------------------------------------------------------------------

# 19. Components vs features

A UI component belongs in `Components` when it is reusable across
features and has little feature-specific business logic.

Examples:

-   metric input control;
-   progress bar;
-   generic card;
-   skill node visual.

A UI element belongs inside a feature when it only makes sense there.

The Skills feature may expose multiple presentations, such as a node map
and a categorized list. Both must derive from the same `Skill`,
`SkillStage`, requirement, and `ProgressionEngine` data. They must never
maintain separate progression state.

Do not prematurely move every small View into a shared-components
folder.

------------------------------------------------------------------------

# 20. Example: correct exercise rendering

Correct:

``` text
Exercise.metric = .seconds

ActiveWorkoutView
→ MetricInputView sees .seconds
→ renders seconds field
```

Incorrect:

``` swift
if exercise.name == "Wall Handstand" {
    showSeconds()
}
```

Correct:

``` text
Exercise.metric = .weightAndReps
→ Weight + reps UI
```

This is one of the most important architectural rules in the project.

------------------------------------------------------------------------

# 21. Example: correct mastery evaluation

Correct:

``` text
Requirement:
exerciseID = X
metric = reps
targetReps = 20
confirmationsNeeded = 2

Workout history:
Session A → exercise X → max reps 20
Session B → exercise X → max reps 21

RequirementEvaluator → 2 qualifying sessions
ProgressionEngine → requirement mastered
```

Incorrect:

``` swift
if exercise.name == "Push-ups" && reps >= 20 {
    pushupAchievement += 1
}
```

------------------------------------------------------------------------

# 22. Example: correct generic stage progression

Correct:

``` text
SkillStage: Assisted Pull-up Mastery

Requirements:
- exercise X
- reps >= target
- confirmations = 2

When mastered:
ProgressionEngine examines graph/order
→ next stage becomes available
```

Incorrect:

``` swift
if assistedPullupCompleted {
    unlockNegativePullups()
}
```

The first approach lets editing and custom skills work without new
source code.

------------------------------------------------------------------------

# 23. Example: shared evidence across skills

Conceptual advanced-skill foundation:

``` text
Planche path

Foundation requirement A:
Concrete pushing requirement

Foundation requirement B:
Concrete core/support requirement
```

If earlier Push-up, L-Sit, or other training has already produced workout
evidence satisfying one of those exact requirements, the
`RequirementEvaluator` should report it as satisfied immediately when the
Planche path is viewed or activated.

The completed foundation remains visible in the Planche progression. It is
not repeated, hidden, or manually copied from another skill.

No `if skill.name == "Planche"` special case is necessary.

------------------------------------------------------------------------

# 24. Minimalism over abstraction

Do not create abstractions solely because they might become useful.

Before introducing a new layer/type, ask:

1.  Does this isolate meaningful product logic?
2.  Is this logic reused or likely to change independently?
3.  Does this reduce coupling?
4.  Does this make future product changes easier?
5.  Is the new abstraction simpler than the duplication it replaces?

If not, keep the implementation direct.

------------------------------------------------------------------------

# 25. Feature development rule

When adding a new feature, identify which category it belongs to.

## Model change

Needed when new persistent concepts/data are required.

## Engine change

Needed when product rules or evaluation logic change.

## Feature/UI change

Needed when presentation or user interaction changes.

## Component change

Needed for reusable visual/input behavior.

Try not to mix all four categories into one giant SwiftUI View.

------------------------------------------------------------------------

# 26. Refactoring threshold

Refactor when:

-   a view becomes difficult to understand;
-   product rules appear inside UI branches;
-   the same logic exists in multiple places;
-   a change to one feature regularly breaks another;
-   name-based special cases appear;
-   editing requires source-code modifications;
-   testing a rule requires launching the UI.

Do not refactor merely because a file exceeds an arbitrary line count.

------------------------------------------------------------------------

# 27. Testing strategy

Core mechanics should eventually be testable without opening the
simulator.

High-value unit tests:

### RequirementEvaluator

-   reps threshold;
-   seconds threshold;
-   weight + reps threshold;
-   separate-session confirmation;
-   multiple qualifying sets in one session count once;
-   insufficient confirmation count.

### ProgressionEngine

-   stage remains future/current as appropriate when requirements fail;
-   stage becomes completed when required evidence passes;
-   already-recorded evidence can satisfy a newly selected skill's
    foundational requirement;
-   the same evidence can satisfy equivalent requirements across multiple
    skill paths without being consumed;
-   inactive skills may reflect valid progress from global workout history;
-   future branching/ANY behavior when those rules are implemented.

### WorkoutGenerator

-   active skill contributes appropriate exercise;
-   inactive skill does not;
-   generated plan respects current stage;
-   general foundation work included when required;
-   manual override persists separately.

Testing should focus on mechanics, not pixel-perfect UI.

------------------------------------------------------------------------

# 28. Migration strategy

Because content is editable and the model will evolve:

-   avoid destructive schema changes when possible;
-   preserve stable IDs;
-   treat seed-data versioning carefully;
-   never re-run seed logic in a way that overwrites user-customized
    content;
-   distinguish first-install seeding from later migrations.

Future seed changes must not silently reset the user's skills/workouts.

------------------------------------------------------------------------

# 29. Seed-data rules

Seed installation should:

-   create defaults only when appropriate;
-   use stable or safely identifiable seeded relationships;
-   avoid duplicating seed content on every launch;
-   never overwrite user data without explicit migration logic.

As editing becomes available, seed content becomes user-owned data after
creation.

------------------------------------------------------------------------

# 30. Editing architecture

Editing must operate on data models.

Existing prototype `Requirement` persistence may still contain level-related
ownership from earlier work. Treat that as provisional legacy structure. New V1
requirement behavior should be skill/stage-focused, and any removal or migration
of legacy level ownership must be handled as an explicit checkpoint rather than
an unrelated cleanup.

Example:

``` text
Edit Exercise
→ modify Exercise.metric
→ future workout UI automatically adapts
```

Not:

``` text
Edit Exercise
→ add special switch in ActiveWorkoutView
```

Likewise:

``` text
Edit Skill
→ add/reorder stage data
→ Skill tree UI renders the new structure
```

and:

``` text
Edit Requirement
→ change target from 20 reps to 25
→ evaluator automatically uses 25
```

This is the primary reason the architecture must remain data-driven.

------------------------------------------------------------------------

# 31. Recommended near-term implementation order

Before adding visual polish:

1.  Finalize initial skill/workout content with the project owner.
2.  Remove the dedicated Progress tab from primary navigation.
3.  Preserve workout history as a secondary destination.
4.  Refine models so Skills/Stages can explicitly reference
    requirements.
5.  Implement `RequirementEvaluator`.
6.  Implement generic progression handling.
7.  Build active-skill selection.
8.  Implement simple skill-driven `WorkoutGenerator`.
9.  Add workout editing/override.
10. Add Skill/Stage/Requirement editing.
11. Build/refine Dashboard late in V1 from real progression data.
12. Only then consider richer visuals, animations, iCloud, widgets, etc.

This order may change with explicit project-owner approval.

------------------------------------------------------------------------

# 32. Architectural invariants

Unless the project owner explicitly changes them:

-   Exercise behavior is never inferred from its name.
-   Logged performance is authoritative.
-   Workouts are plans; sessions are historical reality.
-   Skills drive workout generation.
-   Progression is requirement-driven.
-   Mastery may require repeated confirmation across sessions.
-   Progression consequences are generic/data-driven.
-   V1 progression is represented directly by Skills and demonstrated abilities; Overall/Journey Levels are deferred.
-   Seed content is editable data.
-   Views do not own training rules.
-   V1 remains local-first.
-   Minimalism is preferred over speculative abstraction.
-   Normal app use should remain lightweight, responsive, and
    energy-conscious.
-   Core screens and workout entry must not require network access or
    heavy background computation.
-   Workout generation must respect active-skill, exercise-count, duration,
    and equipment constraints from product rules.
-   Equipment changes the available training route, not the identity or
    mastery standard of a skill.
-   Skills remain discoverable/selectable regardless of current progression
    state; active selection controls workout priority, not visibility.
-   Logged evidence is global and reusable across every relevant skill
    requirement; progression evidence is never consumed by one path.
-   Multiple Skills views must derive from the same progression source of
    truth, and categories remain presentation-only metadata.

------------------------------------------------------------------------

# 33. Agent checklist before structural changes

Before implementing a structural change, confirm:

-   Does it preserve `AGENTS.md`?
-   Is it data-driven?
-   Does it avoid exercise-name branching?
-   Is this logic UI, model, or engine responsibility?
-   Can future custom exercises use it?
-   Can future custom skills use it?
-   Can future editing work without source-code changes?
-   Does it preserve historical workout truth?
-   Does it keep local persistence simple?
-   Is the abstraction actually necessary?
-   Would a smaller implementation work just as well?
-   Does this add unnecessary startup work, background activity, or broad
    data loading?
-   If this is an optimization, was the bottleneck measured first?
-   Does workout-generation logic respect available equipment without
    hardcoding exercise names or inventing misleading substitutions?
-   Does this preserve shared historical evidence across skill paths?
-   Does any Skills presentation accidentally create its own progression
    state or use category tags as progression logic?

If a proposed change violates an invariant, stop and ask the project
owner.

------------------------------------------------------------------------

# 34. Architecture summary

The intended architecture is deliberately simple:

``` text
Models
store editable training data and historical reality

Views / Features
display state and collect user input

RequirementEvaluator
decides whether performance satisfies requirements

ProgressionEngine
decides what mastery and current/future progression state follows

WorkoutGenerator
builds training plans by prioritizing active skills/current needs

SwiftData
persists everything locally
```

The central rule is:

> **Product content is data. Product rules are engines. Views are
> interfaces. Names are presentation.**

That separation is what allows CalisthenicsJourney to stay minimal today
while remaining easy to extend tomorrow.
