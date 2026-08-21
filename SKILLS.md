# SKILLS.md — CalisthenicsJourney

## Purpose

This document defines the current canonical V1 skill-content direction for **CalisthenicsJourney**.

It complements `AGENTS.md` and `ARCHITECTURE.md`.

- `AGENTS.md` protects product philosophy and core mechanics.
- `ARCHITECTURE.md` protects software structure and implementation boundaries.
- `SKILLS.md` protects the approved V1 skill catalog, mastery trees, and training-content decisions.

The V1 prescription philosophy is defined below. Its implementation details,
remaining exercise-specific standards, frequency, and workout-generation
behavior are still under discussion.

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

## 1.9 Prefer simple, specific training

Training should prioritize, in order:

1. the movement the athlete is trying to learn;
2. easier or current versions of that movement for additional quality work
   when useful;
3. previously learned relevant movements;
4. bridge or accessory exercises only when they solve a meaningful progression
   gap.

Do not add exercises merely because they might theoretically help. Prefer a
small number of obvious, high-value movements over unnecessarily large or
complicated exercise lists.

Most mastery nodes are trainable movements as well as checkpoints for ability
demonstrated at a defined standard. Passing a node does not retire its movement;
it remains available for useful later training. Not every exercise must be a
mastery node, and a competency node such as a safety or control skill may not
behave like a normal repeated exercise.

When practical, training toward a node should directly practice its target
movement. Previously mastered or easier versions may add volume or lower-
difficulty practice. Use a special bridge exercise only when it clearly closes
a meaningful gap.

## 1.10 Coaching is lightweight, optional help

Progression determines what the athlete should achieve. Coaching helps the
athlete understand how to achieve it. Coaching content must never become a
progression prerequisite merely because it exists.

V1 coaching should remain concise, optional, easy to access, and out of the way
when it is not needed. It may eventually include short instructions, a few
important form cues, common mistakes, relevant safety information, and optional
visual or video media. Do not require the athlete to read coaching before
performing an exercise, and do not design a large coaching curriculum for V1.

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

## Approved training sequence

### Wall Push-up → Incline Push-up

- Incline Push-ups
- Wall Push-ups if needed

### Incline Push-up → Knee Push-up

- Knee Push-ups
- Incline Push-ups

### Knee Push-up → 1 Strict Push-up

- Strict Push-up attempts
- Low Incline Push-ups
- Knee Push-ups

### 1 → 5 Strict Push-ups

- Strict Push-ups
- Easier Push-up variation only when useful for additional volume

### 5 → 10 Strict Push-ups

- Strict Push-ups

Negative Push-ups are not part of the approved default Push-up training
sequence.

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

## Approved training sequence

### Dead Hang → Active Hang / Scapular Pull

- Scapular Pulls
- Dead Hangs

### Active Hang / Scapular Pull → Assisted Pull-up

- Assisted Pull-ups
- Scapular Pulls

### Assisted Pull-up → Negative Pull-up

- Negative Pull-ups
- Assisted Pull-ups

### Negative Pull-up → 1 Strict Pull-up

- Strict Pull-up attempts
- Negative Pull-ups
- Assisted Pull-ups

### 1 → 3 Strict Pull-ups

- Strict Pull-ups
- Assisted Pull-ups if useful for additional volume

### 3 → 5 Strict Pull-ups

- Strict Pull-ups

Negative Pull-ups are an approved important bridge exercise.

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

## Approved training sequence

### Parallel Bar Support Hold → Assisted Dip

- Assisted Dips
- Support Holds

### Assisted Dip → Negative Dip

- Negative Dips
- Assisted Dips

### Negative Dip → 1 Strict Dip

- Strict Dip attempts
- Negative Dips
- Assisted Dips

### 1 → 3 Strict Dips

- Strict Dips
- Assisted Dips if useful for additional volume

### 3 → 5 Strict Dips

- Strict Dips

Negative Dips are an approved important bridge exercise.

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

## Approved training sequence

### Supported L-Sit Press → Single-Leg Lift

- Single-Leg Lifts
- Supported L-Sit Presses

### Single-Leg Lift → Seated Leg Raises

- Seated Leg Raise attempts
- Single-Leg Lifts

### Seated Leg Raises → Tuck L-Sit

- Tuck L-Sit attempts
- Seated Leg Raises

### Tuck L-Sit → One-Leg L-Sit

- One-Leg L-Sit attempts
- Tuck L-Sits
- both sides

### One-Leg L-Sit → Full L-Sit

- Full L-Sit attempts
- One-Leg L-Sits
- Tuck L-Sits if easier work is useful

### Full L-Sit → 10s Full L-Sit

- Full L-Sit holds

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

## Approved training sequence

### Deep Bodyweight Squat → Assisted Pistol Squat

- Assisted Pistol attempts
- Deep Bodyweight Squats

### Assisted Pistol Squat → Negative Pistol Squat

- Negative Pistols
- Assisted Pistols

### Negative Pistol Squat → 1 Pistol Squat on each leg

- Full Pistol attempts
- Negative Pistols
- Assisted Pistols if needed

### 1 → 3 Pistol Squats on each leg

- Pistol Squats
- Assisted Pistols if useful for additional volume

### 3 → 5 Pistol Squats on each leg

- Pistol Squats

Left/right evidence requirements continue to apply. Ankle and hip preparation
belongs to optional preparation, not the mastery tree.

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

## Approved training sequence

### Wall Walk → 30s Chest-to-Wall Handstand

- Chest-to-Wall Handstands
- Wall Walks

### 30s Chest-to-Wall Handstand → Safe Handstand Bail

- Safe Bail practice
- Chest-to-Wall Handstands

### Safe Handstand Bail → Wall Handstand Balance

- Wall Balance attempts
- Chest-to-Wall Handstands
- Safe Bail practice only as needed

### Wall Handstand Balance → Controlled Handstand Kick-Up

- Kick-Up attempts
- Wall Balance

### Controlled Handstand Kick-Up → First Freestanding Handstand

- Freestanding Handstand attempts
- Kick-Ups
- Wall Balance if easier practice is useful

### First Freestanding Handstand → 5s Freestanding Handstand

- Freestanding Handstands

### 5s → 10s Freestanding Handstand

- Freestanding Handstands

Recommended optional preparation:

- wrists
- shoulders

Safe Handstand Bail remains an independent competency.

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

## Approved training sequence

### Foundations → High Pull-up

- High Pull-up attempts
- Strict Pull-ups

### High Pull-up → Straight-Bar Dip

- Straight-Bar Dips
- Regular Dips if easier volume is useful

### Straight-Bar Dip → Assisted Muscle-up

- Assisted Muscle-ups
- High Pull-ups
- Straight-Bar Dips

### Assisted Muscle-up → Muscle-up Transition

- Muscle-up Transition practice
- Assisted Muscle-ups

### Muscle-up Transition → Negative Muscle-up

- Negative Muscle-ups
- Transition practice

### Negative Muscle-up → 1 Strict Bar Muscle-up

- Strict Muscle-up attempts
- Negative Muscle-ups
- Assisted Muscle-ups if needed

### 1 → 3 Strict Bar Muscle-ups

- Strict Bar Muscle-ups

Previously learned Pull-up and Dip movements are reused rather than treated as
new isolated content.

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

## Approved training sequence

### Pull-up Foundation → Tuck Front Lever

- Tuck Front Lever attempts
- Pull-ups
- Scapular Pulls

### Tuck Front Lever → Advanced Tuck Front Lever

- Advanced Tuck attempts
- Tuck Front Lever holds

### Advanced Tuck Front Lever → One-Leg Front Lever

- One-Leg Front Lever attempts
- Advanced Tuck holds
- both sides

### One-Leg Front Lever → Straddle Front Lever

- Straddle Front Lever attempts
- One-Leg Front Lever holds

### Straddle Front Lever → Full Front Lever

- Full Front Lever attempts
- Straddle Front Lever holds

### Full Front Lever → 5s Full Front Lever

- Full Front Lever holds

Scapular Pulls are intentionally reused as an important previously learned
pulling and scapular movement.

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

## Approved training sequence

### Push-up Foundation → Planche Lean

- Planche Leans
- Push-ups

### Planche Lean → Frog Stand

- Frog Stand attempts
- Planche Leans

### Frog Stand → Tuck Planche

- Tuck Planche attempts
- Frog Stands
- Planche Leans

### Tuck Planche → Advanced Tuck Planche

- Advanced Tuck attempts
- Tuck Planche holds
- Planche Leans

### Advanced Tuck Planche → One-Leg Planche

- One-Leg Planche attempts
- Advanced Tuck holds
- both sides

### One-Leg Planche → Straddle Planche

- Straddle Planche attempts
- One-Leg Planche holds

### Straddle Planche → Full Planche

- Full Planche attempts
- Straddle Planche holds

### Full Planche → 5s Full Planche

- Full Planche holds

Planche Leans remain regular training during early Planche progression through
the Tuck Planche → Advanced Tuck Planche transition. After that, they may become
optional rather than automatically prescribed.

Recommended optional preparation:

- wrists
- shoulders

---

# 12. V1 training-prescription philosophy

## 12.1 The first workout is calibration

The first workout for a selected skill is calibration rather than normal
training. Its purpose is to establish a comfortable, user-controlled starting
estimate quickly, without exhausting the athlete, testing their absolute
maximum, or requiring three full sets for every selected skill.

### Choose the variation

For each selected skill, the athlete first chooses the progression or movement
variation they believe currently fits their ability:

```text
Push-up variation:
[ Strict Push-up ▾ ]
```

This choice is an initial estimate. Selecting a harder variation is not mastery
evidence by itself; actual demonstrated performance remains the meaningful
evidence.

### Choose a comfortable repeatable target

Instead of asking how many repetitions or seconds the athlete can achieve at
maximum, calibration should conceptually ask:

> How many could you comfortably repeat for 3 sets?

For hold-based movements:

> How long could you comfortably repeat for 3 sets?

The athlete chooses a conservative target they believe is repeatable with clean
form, manageable fatigue, and some capacity remaining. The target may include:

- repetitions for rep-based movements;
- seconds for hold-based movements;
- left/right targets where applicable;
- appropriate attempt or quality information for technique/control movements
  once that design is finalized.

This direct repeatable-three-set estimate replaces the need for a mathematical
calibration formula. In particular, do not introduce a "comfortable result ÷ 2"
rule.

### Try one calibration set

The athlete performs one set at the selected variation and target as a quick
reality check and records what they actually performed. This is not a full
three-set workout or a maximum-effort test.

```text
Selected:
Strict Push-up
5 reps × 3 sets

Calibration check:
Try 5 reps once.
```

### Adjust before confirmation

After the calibration set, the athlete may adjust the selected variation,
repeatable rep or hold target, and side-specific targets before confirming.

```text
How did that feel?

Variation:
[ Strict Push-up ▾ ]

Repeatable target:
[ 5 reps ]

[ Confirm starting level ]
```

Exact UI wording and controls remain open. The required behavior is that the
estimate stays adjustable before confirmation.

### Confirm the starting estimate

Once satisfied, the athlete confirms the estimated starting prescription and
moves to the next selected skill:

```text
Strict Push-up
Estimated starting prescription:
3 × 5
```

Repeat this lightweight process for each selected skill. The confirmed result
is an estimate, not proven multi-set working capacity.

## 12.2 Normal workouts establish working capacity

After calibration, normal workouts use actual multi-set performance to learn
the athlete's working capacity. The first normal workout is especially useful
as the strengthening and training baseline.

For example, a calibration estimate of `Strict Push-up — 3 × 5` may produce any
of these first normal-workout results:

```text
5 / 5 / 5
```

```text
5 / 4 / 3
```

```text
7 / 6 / 5
```

This real three-set performance is stronger evidence for future adaptation than
the starting estimate.

Evaluate the full workout rather than only the best single set:

```text
Target:
3 × 3 Push-ups

Actual:
4 / 4 / 3
```

The complete three-set result describes working capacity more usefully than a
best set of 4 alone.

Preserve the lifecycle distinction:

```text
Calibration
→ user-controlled starting estimate

First normal workout
→ first strong evidence of repeatable working capacity

Later workouts
→ progressive overload and adaptation from actual performance
```

## 12.3 Three predictable sets are the V1 default

For normal rep- and hold-based strength work, **3 sets are the default
prescription structure**. Calibration begins with equal estimated targets:

```text
5 / 5 / 5
```

Once normal training begins, targets may become slightly uneven through the
deterministic progressive-overload rule in section 12.5. The three targets
should remain close together, predictable, and understandable.

Prefer this controlled structure over an unnecessarily irregular prescription
such as:

```text
11 / 13 / 8 / 12 / 16
```

Slight unevenness created by progressive overload is not arbitrary uneven
programming. Three sets are a default, not a universal rule for every exercise;
technique/control work may eventually use attempts or another appropriate
structure.

## 12.4 Do not prescribe failure by default

Normal prescriptions should be conservative enough to support clean
repetitions, good technique, manageable fatigue, and repeatable training. The
athlete is not required to reach muscular failure. Personal-best attempts and
performance beyond the target are optional.

## 12.5 Progressive overload

Progressive overload should remain simple and understandable. For rep-based
and hold-based work, successful completion of the entire prescription uses the
athlete's actual three-set performance to establish a normalized baseline, then
progresses all three sets for the next relevant workout:

- each set receives at least **+1**;
- one set receives one additional **+1**, making its increase **+2**;
- the set receiving the additional increment rotates across workouts; and
- the prescription therefore increases by **4 total units** after each
  successful workout.

The exact starting position in the rotation is not important. The additional
increment must rotate rather than permanently making the same set the largest.
Conceptually:

```text
5 / 5 / 5
→ 7 / 6 / 6
→ 7 / 8 / 7
→ 8 / 8 / 9
→ 10 / 9 / 9
→ ...
```

For rep-based work, the unit is repetitions:

```text
Push-ups

5 / 5 / 5 reps
→ 7 / 6 / 6
→ 7 / 8 / 7
→ 8 / 8 / 9
```

For hold-based work, the unit is seconds and the same progression applies:

```text
L-Sit

5 / 5 / 5 seconds
→ 7 / 6 / 6
→ 7 / 8 / 7
→ 8 / 8 / 9
```

This supersedes the previous equal-target, +1-per-set progression and resolves
the generic hold-time increment for normal rep- and hold-based prescriptions.

### Normalize actual performance before applying progression

After the athlete successfully completes a normal three-set prescription:

1. add the actual results from all three sets;
2. divide the total by 3;
3. round down to the whole unit;
4. use that value as an equal normalized baseline for all three sets; and
5. apply the next rotating +2/+1/+1 increment to produce the next relevant
   workout's prescription.

For rep-based movements, the unit is repetitions. For hold-based movements,
the unit is seconds.

For example, actual rep performance of `7 / 6 / 6` produces:

```text
(7 + 6 + 6) / 3
= 6.33
→ round down to 6
→ normalized baseline: 6 / 6 / 6
```

If Set 2 is next in the rotation, the next prescription is:

```text
7 / 8 / 7 reps
```

Significant overperformance uses the same rule. For example:

```text
Actual:
10 / 7 / 6 reps

(10 + 7 + 6) / 3
= 7.67
→ round down to 7
→ normalized baseline: 7 / 7 / 7

Next workout, if Set 1 receives the rotating extra increment:
9 / 8 / 8 reps
```

Do not apply +2/+1/+1 independently to `10 / 7 / 6`. Normalization prevents
an unusually strong or weak individual set from creating increasingly
distorted prescriptions.

The same calculation applies to hold seconds:

```text
Actual L-Sit holds:
9 / 7 / 6 seconds

22 / 3
= 7.33
→ round down to 7 seconds
→ normalized baseline: 7 / 7 / 7 seconds

Next workout, if Set 3 receives the rotating extra increment:
8 / 8 / 9 seconds
```

Normalization does not reset the rotation. The set receiving the extra +1
continues to rotate across successful workouts regardless of the normalized
baseline.

Conceptually:

```text
Actual full-workout performance
→ average all three sets
→ round down
→ equal normalized baseline
→ apply the next rotating +2/+1/+1
→ next prescription
```

## 12.6 Incomplete workouts repeat before regression

One unsuccessful session should not immediately regress the athlete. If the
full prescription is incomplete, repeat the same prescription at the next
relevant workout by default:

```text
Target:
7 / 6 / 6

Actual:
7 / 5 / 5

Next workout:
7 / 6 / 6 again
```

Do not normalize a failed result downward or automatically regress the
prescription.

Already-earned mastery is never removed by an incomplete workout.

## 12.7 Actual performance drives adaptation without erasing history

The prescribed target is the minimum training goal. The athlete should record
actual performance even when it exceeds that target:

```text
Target:
7 / 6 / 6

Actual:
10 / 9 / 8
```

Full-workout performance is evidence of repeatable working capacity. The
normalization rule in section 12.5 lets stronger actual performance raise the
next baseline without requiring a separate percentage threshold,
small/moderate/large classification, or accelerated-progression bonus.

Normalization affects only the next prescription. It does not replace or erase
the recorded set results. In this example, the athlete's 10-rep first set
remains part of workout history and may remain personal-best evidence where
appropriate.

## 12.8 Personal bests motivate; they do not prescribe

The prescribed target represents what the athlete should train today. A shown
previous or personal best is an optional challenge, not a requirement to set a
new record every workout.

```text
Today's target:
3 × 5 Push-ups

Best:
7 reps

Feeling strong?
You may try to beat your best.
```

Any performance beyond the target must still be recorded as actual reality.

## 12.9 Technique and control use successful-attempt confirmation

Some technique, control, coordination, or safety competencies do not fit normal
rep or hold prescriptions. Examples may include Safe Handstand Bail,
Handstand Kick-Up, transitions, and other competencies whose meaningful
evidence is successful execution.

For V1, these use **successful-attempt confirmation**:

```text
Attempted
≠
Successfully demonstrated
```

Trying a competency is not mastery evidence. The athlete must confirm that it
was successfully performed to the required standard. V1 does not require
camera analysis, sensors, or automated form recognition to judge the movement.

Do not invent a mandatory number of attempts for every technique/control node.
The exact confirmation UI and the approved performance standard for each such
competency remain later content and UI decisions.

## 12.10 Holds and timers

Hold-based movements follow the same calibration and progressive-overload
philosophy as rep-based movements. An in-app timer may eventually be offered as
a convenience, but it must not be required for progression.

For movements such as Handstand, Front Lever, Planche, and L-Sit, the athlete
may enter the achieved duration after the attempt when interacting with the
phone during the hold is impractical.

## 12.11 Rest is recommended, not enforced

For normal strength-oriented V1 training, **90 seconds is the default rest
recommendation between sets**. It is a pacing aid, not a gate:

```text
Set complete

Recommended rest:
1:30

[ Start timer ]   [ Skip ]
```

The exact UI is not locked by this example. Rest may be optionally timed,
skipped, or extended, and the athlete remains in control of when to continue.
They may continue after approximately 60 seconds if ready, or rest for 2
minutes, 2.5 minutes, or longer when a demanding exercise requires it.

The app must not force the athlete to wait for a timer, punish a different rest
duration, reduce progression, or mark a workout failed because rest was shorter
or longer than recommended. Rest duration is not progression evidence.

## 12.12 Equipment philosophy

Core V1 progression should prioritize bodyweight and minimal necessary
calisthenics equipment. Some skills inherently require an appropriate structure
such as a pull-up bar or equivalent hanging/support equipment; minimal equipment
does not mean literally zero equipment.

Gym machines and additional equipment may later offer optional supplemental
work or alternatives without becoming unnecessary progression barriers.
Examples include:

- TRX or another suspension trainer;
- resistance bands;
- lat pulldown;
- chest press;
- leg press;
- guided squat rack;
- other gym equipment.

These machine exercises are not additions to the currently approved default
skill sequences.

---

# 13. V1 multi-skill workout assembly

Multi-skill workout generation should remain simple. For the active skills:

1. determine the exercises relevant to their current stages;
2. combine those candidate exercises;
3. deduplicate genuinely shared exercises where appropriate;
4. avoid filler exercises added merely to make the workout appear larger; and
5. keep the final workout manageable.

The approved trees and training sequences provide the core exercise content.
Do not add accessory work solely to fill workout space. Optional preparation
remains separate from the main required exercise count as already documented.

Workout duration should emerge from relevant exercises, the normal set
structure, optional preparation, and athlete-controlled rest. Favor useful,
manageable training over filling an arbitrary duration target. Detailed
conflict resolution, trimming, and duration optimization remain implementation
and testing decisions; do not introduce a complex scoring or optimization
algorithm without a demonstrated need.

---

# 14. Prescription and workout decisions still deferred

Do not yet implement or finalize:

- individual technique/control standards and confirmation UI;
- detailed multi-skill conflict resolution and trimming behavior;
- exercise-specific rest recommendations beyond the 90-second default;
- weekly frequency;
- richer coaching presentation and media;
- application models or seed data;
- workout-generator behavior or UI.

Calibration does not use a divide-by-two or other one-set conversion formula.
Its variation and repeatable three-set target are confirmed directly after a
single adjustable reality-check set.

Additional exercise choices require approval rather than being inferred from
this document. Do not hardcode the current trees, sequences, or prescriptions as
name-based special-case application logic. They remain editable product content
that should ultimately use the generic Skill / SkillStage / Requirement /
exercise architecture defined by the project.
