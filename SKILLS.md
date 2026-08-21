# SKILLS.md — CalisthenicsJourney

## Purpose

This document defines the current canonical V1 skill-content direction for **CalisthenicsJourney**.

It complements `AGENTS.md` and `ARCHITECTURE.md`.

- `AGENTS.md` protects product philosophy and core mechanics.
- `ARCHITECTURE.md` protects software structure and implementation boundaries.
- `SKILLS.md` protects the approved V1 skill catalog, mastery trees, and training-content decisions.

The exact supporting exercises, training prescriptions, training set/rep schemes, rest periods, and workout-generation behavior are still under discussion and will be added later.

Do not silently redesign these skill trees. If a progression node or mastery standard appears to need changing, explain the proposed change to the project owner and obtain approval first.

---

# 1. Skill-content principles

## 1.1 Skill trees represent meaningful demonstrated abilities

A skill tree should contain meaningful physical milestones, not every drill or exercise that may help someone progress.

A movement may be useful training without deserving its own mastery node.

Examples:

- Inverted Rows may help someone earn a Pull-up without being a Pull-up mastery node.
- Front Lever Negatives may help someone progress without every negative variation appearing on the Front Lever tree.
- Wrist preparation may help Handstand and Planche training without becoming a mastery node.

The tree should remain understandable and rewarding rather than overcrowded.

## 1.2 Supporting exercises are separate from mastery nodes

Supporting exercises answer:

> What should I train to reach the next node?

Mastery nodes answer:

> What ability have I actually demonstrated?

The same movement may be both a mastery node in one context and a reusable exercise later.

For example, Scapular Pulls are learned during Pull-up progression and may later be reused as training for Front Lever or other pulling goals.

## 1.3 Mastered movements remain useful

Mastering a node does not retire that movement.

Previously learned movements become part of the athlete's reusable training toolbox and may appear later when they meaningfully support current goals.

However, previously mastered beginner movements should not be forced into every later workout merely because they were once part of a tree.

## 1.4 Skill mastery does not cap future ability

The mastery tree defines when the user has learned the skill to the approved base standard.

Performance beyond that standard continues to be logged as demonstrated ability.

Examples:

- Push-up is mastered at 10 strict reps, but a later 20-rep result remains valid evidence.
- Pull-up is mastered at 5 strict reps, but later 8 or 10 rep performances remain valid evidence.
- Handstand is mastered at 10 seconds, but longer holds remain valid evidence.
- Front Lever and Planche are mastered at 5 clean seconds, but longer holds remain valid evidence.

Other skills may use stronger later performances as foundational evidence without extending the original base skill tree.

## 1.5 Progression evidence is global

Previously logged workout evidence may satisfy requirements anywhere that the same demonstrated ability is relevant.

Evidence is never consumed by one skill path.

If a later skill requires an ability the user already demonstrated, the corresponding foundation or requirement should already appear satisfied.

## 1.6 Side-specific evidence must remain side-specific

Unilateral or directional movements must preserve which side was demonstrated.

A result on one side must never silently count as proof of equal ability on the other side.

Requirements may need:

- left side;
- right side;
- either side;
- both sides independently.

Examples in the current V1 trees include:

- One-Leg L-Sit;
- Pistol Squat;
- One-Leg Front Lever;
- One-Leg Planche.

## 1.7 Preparation blocks are recommended, not mandatory

Some workouts require preparation for the joints and positions they load.

Examples:

- Handstand and Planche may need wrist and shoulder preparation.
- Pistol Squat may need ankle and hip preparation.
- Pull-up and Front Lever may need shoulder/scapular preparation.

The workout generator should eventually support short, goal-specific **Preparation** blocks.

Preparation blocks:

- are recommendations;
- may be skipped by the user;
- must never block the workout or progression;
- should combine overlapping preparation needs rather than duplicate them;
- are separate from mastery progression;
- should not consume the normal main-workout exercise budget in the same way as primary training exercises.

Exact preparation exercises and generator behavior are still to be designed.

## 1.8 Mastery nodes may be dependent or independent

Progression order and validation implication are not always identical.

A **dependent node** represents an ability where successfully demonstrating a
harder ability with the required form and standard can logically prove one or
more easier abilities beneath it. For example:

```text
10 Strict Push-ups
→ implies 5 Strict Push-ups
→ implies 1 Strict Push-up
→ implies Knee Push-up
→ implies Incline Push-up
→ implies Wall Push-up
```

Only explicitly implied dependent nodes may be validated this way. This allows
experienced users to establish an appropriate starting position without being
forced to perform obviously easier versions merely to check progression boxes.

An **independent node** represents a distinct competency that must be
demonstrated separately. A later or more difficult-looking achievement does not
automatically validate it. For example, a 10-second Freestanding Handstand does
not automatically prove Safe Handstand Bail; the bail is a separate safety and
control competency.

Do not apply a global rule that completing a node automatically completes every
earlier node. Future content and architecture should represent explicit
implication relationships between demonstrated abilities and the dependent
nodes they validate. Independent nodes must remain outside those relationships.
The detailed dependent/independent classification of the nine V1 trees is still
to be approved alongside exercise and validation design.

This behavior should eventually support initial athlete placement, automatic
progression validation, non-linear and mixed-competency trees, and a future
`Too Easy` workout action. `Too Easy` does not grant mastery; it only lets the
user try an appropriate harder progression, whose successful performance may
provide evidence. A future `Too Hard` action may offer an appropriate regression
without removing mastery the user has already earned.

---

# 2. V1 skill catalog

The current approved V1 skill pool contains nine skills:

1. Push-up
2. Pull-up
3. Dip
4. Handstand
5. L-Sit
6. Pistol Squat
7. Muscle-up
8. Front Lever
9. Planche

Future skills and variations such as Diamond Push-up, Decline Push-up, Archer Push-up, One-Arm Push-up, V-Sit, Handstand Push-up, Press to Handstand, Ring Muscle-up, and other advanced movements are outside the current V1 skill-content scope.

---

# 3. Push-up

## Mastery tree

```text
Wall Push-up
    ↓
Incline Push-up
    ↓
Knee Push-up
    ↓
1 Strict Push-up
    ↓
5 Strict Push-ups
    ↓
10 Strict Push-ups
    ↓
★ PUSH-UP MASTERED
```

## Locked decisions

- Knee Push-up remains a visible mastery node.
- Different incline heights belong to training progression within the Incline Push-up stage rather than separate mastery nodes.
- **10 clean strict Push-ups = Push-up mastery.**
- Higher repetition ability continues to be logged after mastery.
- Other Push-up variations are deferred for later content work.

---

# 4. Pull-up

## Mastery tree

```text
Dead Hang
    ↓
Active Hang / Scapular Pull
    ↓
Assisted Pull-up
    ↓
Negative Pull-up
    ↓
1 Strict Pull-up
    ↓
3 Strict Pull-ups
    ↓
5 Strict Pull-ups
    ↓
★ PULL-UP MASTERED
```

## Locked decisions

- Dead Hang remains a visible mastery node.
- Active Hang / Scapular Pull remains a visible mastery node.
- Assisted Pull-up is one node; changing assistance levels belongs to training progression.
- Negative Pull-up remains a visible mastery node.
- **5 clean strict Pull-ups = Pull-up mastery.**
- Pull-ups, Scapular Pulls, hangs, and other mastered pulling movements may later be reused as exercises for skills such as Muscle-up and Front Lever.

---

# 5. Dip

## Mastery tree

```text
Parallel Bar Support Hold
    ↓
Assisted Dip
    ↓
Negative Dip
    ↓
1 Strict Dip
    ↓
3 Strict Dips
    ↓
5 Strict Dips
    ↓
★ DIP MASTERED
```

## Locked decisions

- Parallel Bar Support Hold remains a visible mastery node.
- Assisted Dip is one node; changing assistance belongs to training progression.
- Negative Dip remains a visible mastery node.
- **5 clean strict Dips = Dip mastery.**
- Bench Dips are not part of the current V1 Dip mastery tree.
- Mastered Dip-related movements may later be reused where useful, especially for Muscle-up training.

---

# 6. L-Sit

## Mastery tree

```text
Supported L-Sit Press
    ↓
Single-Leg Lift
    ↓
Seated Leg Raises
    ↓
Tuck L-Sit
    ↓
One-Leg L-Sit
    (both sides)
    ↓
First Full L-Sit
    ↓
10s Full L-Sit
    ↓
★ L-SIT MASTERED
```

## Locked decisions

- Supported L-Sit Press remains a visible beginner node.
- Single-Leg Lift remains a visible node.
- Seated Leg Raises remain a visible mastery node rather than supporting training.
- Seated Leg Raises represent the two-leg compression and coordination bridge between Single-Leg Lift and Tuck L-Sit.
- Partial L-Sit / partial extension work is supporting training rather than a visible mastery node.
- One-Leg L-Sit requires both sides.
- **10 clean seconds in a Full L-Sit = L-Sit mastery.**
- Longer holds continue to be logged as demonstrated ability.

---

# 7. Pistol Squat

## Mastery tree

```text
Deep Bodyweight Squat
    ↓
Assisted Pistol Squat
    ↓
Negative Pistol Squat
    ↓
1 Pistol Squat / each leg
    ↓
3 Pistol Squats / each leg
    ↓
5 Pistol Squats / each leg
    ↓
★ PISTOL SQUAT MASTERED
```

## Locked decisions

- Deep Bodyweight Squat remains a visible foundation node.
- Assisted Pistol Squat remains a visible node.
- Negative Pistol Squat remains a visible node.
- Both legs must satisfy the repetition target independently.
- **5 clean Pistol Squats on each leg = Pistol Squat mastery.**
- Side-specific performance must remain visible in the underlying evidence.
- Shrimp Squat and other single-leg squat variations are outside the current V1 tree.

---

# 8. Handstand

## Mastery tree

```text
Wall Walk
    ↓
30s Chest-to-Wall Handstand
    ↓
Safe Handstand Bail
    ↓
Wall Handstand Balance
    ↓
Controlled Handstand Kick-Up
    ↓
First Freestanding Handstand
    ↓
5s Freestanding Handstand
    ↓
10s Freestanding Handstand
    ↓
★ HANDSTAND MASTERED
```

## Locked decisions

- Wall Walk remains the beginner entry node.
- **30 seconds Chest-to-Wall Handstand** is the current wall-hold milestone.
- Safe Handstand Bail remains a visible mastery node because safe exit/control is part of handstand competence.
- Wall Handstand Balance remains a visible node.
- Controlled Handstand Kick-Up remains a visible node.
- First Freestanding Handstand is a meaningful achievement even before duration mastery.
- **10 clean seconds Freestanding Handstand = Handstand mastery.**
- Longer holds continue to be logged as demonstrated ability.
- Wrist/shoulder preparation is recommended training preparation, not a mastery node.

---

# 9. Muscle-up

For V1, **Muscle-up means Bar Muscle-up**, not Ring Muscle-up.

## Foundations

The Muscle-up path recognizes previously demonstrated Pull-up and Dip ability.

Current foundational reference points:

```text
5 Strict Pull-ups
5 Strict Dips
```

If already demonstrated, these foundations should appear satisfied rather than being repeated.

## Mastery tree

```text
FOUNDATIONS
5 Pull-ups ✓
5 Dips ✓
    ↓
High Pull-up
    ↓
Straight-Bar Dip
    ↓
Assisted Muscle-up
    ↓
Muscle-up Transition
    ↓
Negative Muscle-up
    ↓
1 Strict Bar Muscle-up
    ↓
3 Strict Bar Muscle-ups
    ↓
★ MUSCLE-UP MASTERED
```

## Locked decisions

- High Pull-up remains a visible node.
- Straight-Bar Dip remains a visible node because it is an important bridge between Pull-up/Dip ability and getting above the bar.
- Assisted Muscle-up remains a visible node.
- Muscle-up Transition remains a visible node.
- Negative Muscle-up remains a visible node.
- The target movement is a clean/strict Bar Muscle-up rather than an uncontrolled kip-based rep.
- **3 clean strict Bar Muscle-ups = Muscle-up mastery.**
- Higher-rep or weighted Muscle-up work is beyond base mastery and may be explored later.

---

# 10. Front Lever

## Foundation

Previously demonstrated Pull-up ability is a meaningful foundation and may be reused by Front Lever training.

The exact Front Lever foundational requirement beyond the current Pull-up tree is still to be finalized when supporting exercises and prescriptions are designed.

## Mastery tree

```text
Pull-up Foundation
    ↓
Tuck Front Lever
    ↓
Advanced Tuck Front Lever
    ↓
One-Leg Front Lever
    (both sides)
    ↓
Straddle Front Lever
    ↓
Full Front Lever
    ↓
5s Full Front Lever
    ↓
★ FRONT LEVER MASTERED
```

## Locked decisions

- Tuck Front Lever remains a visible node.
- Advanced Tuck Front Lever remains a visible node.
- One-Leg Front Lever remains a visible node and requires both sides.
- Straddle Front Lever remains a visible node.
- Negatives, rows, assistance, and similar drills are supporting training rather than separate mastery nodes unless later approved.
- **5 clean seconds in a Full Front Lever = Front Lever mastery.**
- Longer holds remain demonstrated ability after mastery.

---

# 11. Planche

## Foundation

Push-up mastery is recognized as meaningful foundational pushing ability.

The additional straight-arm strength, wrist tolerance, shoulder strength, scapular control, and balance needed for Planche are developed within the Planche progression rather than by requiring an artificial long prerequisite chain.

## Mastery tree

```text
Push-up Foundation
    ↓
Planche Lean
    ↓
Frog Stand
    ↓
Tuck Planche
    ↓
Advanced Tuck Planche
    ↓
One-Leg Planche
    (both sides)
    ↓
Straddle Planche
    ↓
Full Planche
    ↓
5s Full Planche
    ↓
★ PLANCHE MASTERED
```

## Locked decisions

- Planche Lean remains a visible node.
- Frog Stand remains a visible node because balance, hand loading, and safe bodyweight support are important bridges toward Planche.
- Tuck Planche remains a visible node.
- Advanced Tuck Planche remains a visible node.
- One-Leg Planche remains a visible node and requires both sides.
- Straddle Planche remains a visible node.
- Many smaller Planche drills belong to supporting training rather than the visible mastery tree.
- **5 clean seconds in a Full Planche = Planche mastery.**
- Wrist preparation is recommended and optional, not a mastery gate.

---

# 12. Training content still to be designed

The nine V1 mastery trees above are approved, but the training system beneath them is not yet finalized.

For each transition, the project still needs to define:

- supporting exercises;
- which previously mastered movements should be reused;
- exercise roles;
- sets;
- reps;
- hold times;
- assistance levels;
- progression rules;
- rest periods;
- frequency considerations;
- preparation needs;
- equipment alternatives;
- objective form/ROM standards;
- what evidence validates technique/control nodes that are not simple rep or duration thresholds.

The next major content-design task is to work through these skill trees and define how the app should train the user from one node to the next.

Do not prematurely hardcode the current trees as special-case application logic. They remain editable product content and should ultimately be represented through the generic Skill / SkillStage / Requirement / exercise architecture defined by the project.
