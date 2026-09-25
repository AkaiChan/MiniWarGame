# MiniWarGame

> A tiny turn-based tactics game I started building because I wanted to understand tabletop wargames.

![Status](https://img.shields.io/badge/status-MVP%20v0.1-green)
![Engine](https://img.shields.io/badge/Godot-4.x-blue)
![Genre](https://img.shields.io/badge/genre-turn--based%20tactics-orange)

A [BB Studio](#about-bb-studio) experiment.

## Why I Made This

I've wanted to try tabletop wargames for a long time.

There was just one problem:

I didn't really understand how they worked.

Whenever I watched people play, it looked something like this:

> Pick up a handful of dice.  
> Roll them.  
> Hit.  
> Wound.  
> Save.  
> Remove a few miniatures.

And I was sitting there thinking:

**"...Wait. What just happened?"**

Tabletop wargames looked incredibly cool to me, but there was always a barrier between watching the game and actually understanding it.

So I had an idea:

**If I can't understand the rules, why don't I build a small wargame myself?**

Not a full-scale commercial game.

Not a Warhammer clone.

Just something small enough that I could take movement, attacks, dice rolls, positioning, action points, and unit stats apart one piece at a time.

That idea became **MiniWarGame**.

---

## What Is MiniWarGame?

MiniWarGame is a small turn-based tactical game built with Godot.

Two small forces fight on an 8×8 battlefield.

The player controls Human units while a simple AI controls Goblins.

Each unit has:

- HP
- Action Points
- Movement Range
- Attacks
- Hit
- Wound
- Save
- Damage
- Board Footprint

The combat system is inspired by the flow of tabletop miniature games:

**Attack → Hit → Wound → Save → Damage**

Instead of hiding those calculations, MiniWarGame tries to make them visible.

When an attack happens, you can see the actual dice rolls:

```text
PlayerGuard × EnemyBerserker

HIT 4+    [6] [1]
          1 HIT

WOUND 4+  [4]
          1 WOUND

SAVE 4+   [5]
          1 SAVED / 0 FAILED

DAMAGE    0
```

That is an important part of the project.

I don't just want the game to calculate the rules.

I want to be able to **see and understand why something happened**.

---

## MVP v0.1

The first playable MVP includes:

- 8×8 tactical battlefield
- Turn-based gameplay
- Action Point system
- Grid movement
- BFS movement range
- Player and enemy teams
- Simple enemy AI
- Unit selection and hover information
- Movement highlighting
- HP and unit death
- Exhausted unit state
- Hidden/visible enemy HP option
- Multi-tile units
- Footprint-aware movement and collision
- Footprint-aware melee combat
- Visible combat dice results
- Human and Goblin pixel-art units
- In-game quick rules

At this point, MiniWarGame can be played as a small Human-vs-Goblin battle from beginning to end.

---

## Units

The current prototype has three unit archetypes.

### Scout

Fast and fragile.

| Stat      | Value |
| --------- | ----: |
| Footprint |   1×1 |
| HP        |     4 |
| AP        |     3 |
| Move      |     3 |
| Attacks   |     2 |
| Hit       |    4+ |
| Wound     |    4+ |
| Save      |    5+ |
| Damage    |     1 |

### Guard

Slow but durable.

| Stat      | Value |
| --------- | ----: |
| Footprint |   1×1 |
| HP        |     7 |
| AP        |     2 |
| Move      |     1 |
| Attacks   |     2 |
| Hit       |    4+ |
| Wound     |    4+ |
| Save      |    3+ |
| Damage    |     1 |

### Berserker

A larger, aggressive unit.

| Stat      | Value |
| --------- | ----: |
| Footprint |   2×1 |
| HP        |     6 |
| AP        |     2 |
| Move      |     2 |
| Attacks   |     3 |
| Hit       |    4+ |
| Wound     |    3+ |
| Save      |    4+ |
| Damage    |     1 |

These numbers are still experimental.

Balance is not the goal yet.

Understanding what makes these units *feel different* is.

---

## Multi-Tile Units

One of the first larger systems I wanted to explore was unit size.

Units are not required to occupy a single tile.

A unit has a footprint:

```text
1×1

[X]
```

```text
2×1

[X][X]
```

```text
2×2

[X][X]
[X][X]
```

Movement, collision, placement, melee range, highlighting, and board boundaries all use the same generic footprint system.

One principle became especially important while building this:

> **Footprint is data, not another set of rules.**

There is no special `move_2x1_unit()` or `can_place_2x2_unit()`.

The same movement and placement logic works from the unit's footprint.

That means larger unit shapes can be explored without rewriting the core movement system.

---

## Combat

Combat currently follows five steps:

```text
ATTACK
   ↓
HIT
   ↓
WOUND
   ↓
SAVE
   ↓
DAMAGE
```

For example, a unit with:

```text
Attacks: 3
Hit:     4+
Wound:   3+
Damage:  1
```

rolls three Hit dice.

Every successful Hit creates a Wound roll.

Every successful Wound gives the defender a Save roll.

Failed Saves become Damage.

The game deliberately shows these rolls instead of only showing the final result.

For me, this project is partly about learning **why** tabletop combat systems work the way they do.

---

## Action Points

Units receive Action Points each turn.

Currently:

```text
Move   = 1 AP
Attack = 1 AP
```

When a unit reaches 0 AP, it becomes exhausted and can no longer act during that turn.

Its visual appearance also becomes darker so it is easy to see which units have already finished acting.

At the beginning of its team's next turn, its AP is restored.

---

## Architecture

MiniWarGame is intentionally kept small.

I am trying not to build systems simply because a "proper game architecture" might need them someday.

The current responsibilities are roughly:

```text
Game
├── Turn flow
└── Enemy AI

Board
├── Grid
├── Occupancy
├── Placement
├── Movement
├── Selection
├── Highlighting
├── Attack legality
└── Combat resolution

Unit
├── Team
├── Archetype
├── Stats
├── Footprint
├── HP
├── AP
└── Visual state

HUD
└── Display
```

There is currently no:

- CombatManager
- TurnManager
- AbilityManager
- OccupancyManager
- Event Bus
- Behavior Tree
- Resource Database

That is intentional.

If the prototype eventually becomes complex enough to need those abstractions, they can be introduced when there is an actual problem for them to solve.

---

## Design Philosophy

A few principles have emerged while building the project.

### Rules should have one authority

The UI should explain the game.

It should not decide the game.

A green movement tile does not make movement legal.

The movement system decides whether a destination is legal, and the highlight simply communicates that result.

### Systems should be generic where it matters

A 2×1 unit should not require an entirely new movement system.

Different unit types should provide different data to shared rules whenever possible.

### Build the smallest thing that teaches me something

This project started as a way to understand tabletop games.

So the goal is not to predict every feature I might need six months from now.

The goal is:

**Build → Play → Understand → Adjust.**

---

## Art Direction

The current visual style combines:

- a simple 3D tabletop board
- 2D pixel-art characters
- colored miniature bases
- minimal tactical UI

Humans and Goblins are displayed as billboarded pixel-art standees on a 3D battlefield.

The idea is to keep the feeling of moving miniatures around a tabletop without requiring full 3D character production.

---

## What's Next?

MVP v0.1 is intentionally small.

Some ideas for later versions include:

### Better Enemy AI

The current AI is deliberately simple.

Future versions may improve target selection and make the AI understand unit footprints more accurately.

### Unit Abilities

The first planned ability is for the Berserker:

**Momentum**

```text
Defeat an enemy
→ Recover 1 AP
→ Maximum once per turn
→ Cannot exceed Max AP
```

This is also an experiment in giving units stronger identities without turning every rule into a special case.

### Balance & Playtesting

An important question has already appeared:

**Why am I losing to the AI so much?**

Is the Berserker too strong?

Is the Guard too slow?

Are the dice simply being cruel?

Or am I just bad at my own game?

That's something I'd rather answer through playtesting than guessing.

---

## What This Project Is Really About

MiniWarGame started because tabletop wargames looked fascinating to me, but also strangely inaccessible.

Building one changed the way I looked at them.

Movement became something I could break down.

Attack rolls became understandable.

Hit, Wound, Save, positioning, unit size, action economy — things that once looked like a pile of rules started becoming individual systems I could reason about.

And somewhere along the way, something else happened.

I stopped asking:

> "Does this feature work?"

and started asking:

> "Why can't I beat the AI?"

That was probably the moment MiniWarGame stopped feeling like a programming exercise...

and started feeling like a game.

---

## Built With

- Godot 4
- GDScript
- Pixel-art unit visuals
- A lot of dice rolls

---

## Status

**MVP v0.1 — Playable**

The rules, balance, visuals, and architecture are all still evolving.

And that's the point.

MiniWarGame is a project for learning how games work by building one.

---

## About BB Studio

**Soul partners × business experiments — turning warm trust into products that actually run.**

BB Studio is co-named by two engineers — a workspace where we experiment with a "solo company × partnership" model.

We don't build bloated all-in-one platforms. We focus on real scenarios and ship small, deliverable tools and services where data stays in the user's hands.

### What we believe

- **Sell outcomes, not generic bots** — clients want their time back and their schedules handled, not another dashboard to learn.
- **Works offline too** — not every team can or should put their data in the cloud; we respect data sovereignty.

### How we work

We prefer: small pilot → interview-driven packaging → a runnable MVP — not selling a massive blueprint upfront.

**Built with care — leave the complexity to the system, return calm to the user.**
