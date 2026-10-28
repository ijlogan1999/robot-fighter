# CLAUDE.md

Guidance for Claude Code sessions working on this project.

## Project
**Robot Fighter** (working title): *Street Fighter meets Slay the Spire.* A roguelike 1v1 fighting game
where one modular robot drafts body parts (moves) and software chips (passives/synergies) between duels on
a branching map.

- **Full design:** `docs/GDD.md`. Read it before designing or building any feature. Section 16 is the
  build plan, and Section 17 lists open questions and risks.
- **Engine:** Godot **4.6** (the developer uses 4.6.2), GDScript only. Don't use features newer than 4.6.
- **Platform:** PC first. Controller, keyboard and arcade stick/hitbox are all first-class inputs.

## About the developer
- A **beginner programmer.** Claude writes most of the code. Keep it **simple, readable and commented
  where the intent isn't obvious**. Prefer plain, explicit GDScript over clever abstractions.
- Works part-time. Each milestone must end with something **playable in the editor (F5)**.
- Explain *what to click or press in Godot* to test each change.

## Technical ground rules
- **Fixed 60 ticks/sec simulation.** All combat logic runs in `_physics_process`. Frame data is in ticks.
- **Deterministic combat:** integer or fixed-point positions and velocities, custom hitbox/hurtbox
  rectangles, no Godot physics engine for gameplay, no floats in combat logic, no randomness without a
  seeded RNG. (This keeps replays and future rollback netcode possible.)
- **Visuals are separate from logic.** 3D models and animations only *display* the simulation state.
  Placeholder capsules are used until build-plan step 12.
- **Content is data.** Moves, parts, chips, opponents and events are Godot Resources (`.tres`) in `data/`.
- Don't hard-code "exactly one opponent" (crowd fights may come later).
- **Inputs:** an ~8-frame buffer, lenient motion parsing, a ~3-frame simultaneous-press window, SOCD
  cleaning, full remapping. Classic (motion) controls first; Simple controls come later.

## Conventions
- Folder layout is described in `README.md`.
- GDScript style: tabs, `snake_case` for functions and variables, `PascalCase` for classes, static types
  where practical.
- Commit after each working milestone or sub-step with a clear message. `main` is backed up on GitHub
  (`ijlogan1999/robot-fighter`). Push when the developer asks.

## Current status
- ✅ Step 0: project setup (boot scene reports 60/60 ticks)
- ⏭️ Next: **Step 1**, the input system (buffer, SOCD, remapping, motion parser groundwork) and a capsule
  robot walking, crouching and jumping in a training room, with an on-screen input display.

Update this "Current status" section when a milestone is finished.
