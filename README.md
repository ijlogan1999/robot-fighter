# Robot Fighter (working title)

*Street Fighter meets Slay the Spire.* A roguelike 1v1 fighting game where a modular robot
drafts new parts and software between duels.

- **Design doc:** [`docs/GDD.md`](docs/GDD.md)
- **Engine:** Godot 4.6 (GDScript)

## Running the project
1. Open Godot 4.6.x.
2. In the Project Manager, click **Import**, select this folder's `project.godot`, and open it.
3. Press **F5** (Run Project). You should see the Step 0 boot screen reporting
   **60 / 60** simulation ticks per second.

## Folder layout
| Folder | Contents |
|---|---|
| `docs/` | Game Design Document and other notes |
| `scenes/` | Godot scenes (`.tscn`) |
| `scripts/core/` | Boot, game flow, the fixed-tick simulation loop |
| `scripts/combat/` | Fighters, moves, hitboxes, meter, damage |
| `scripts/input/` | Input buffer, motion parser, SOCD cleaning, remapping |
| `scripts/ai/` | AI personalities |
| `scripts/run/` | Map, nodes, rewards, shop, events, run state |
| `scripts/ui/` | HUD, menus, training overlays |
| `data/` | Content as Godot Resources: moves, parts, chips, opponents, events |
| `art/` | Models, shaders, VFX, UI art |
| `audio/` | Music and sound effects |
| `tests/` | Automated tests |

## Ground rules
- **All combat logic runs in `_physics_process` at a fixed 60 ticks/sec**, using integer math,
  separate from visuals. Frame data is in ticks.
- **Content is data.** Moves, parts and chips are resource files, so adding content rarely needs new code.

## Build plan
See GDD Section 16. Current milestone: **Step 0 (project setup) ✅**. Next: **Step 1**, the input
system and a capsule robot moving in a training room.
