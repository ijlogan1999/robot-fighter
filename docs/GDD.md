# Game Design Document — Robot Roguelike Fighter

**Working title:** TBD ("Aetheros" came up during the interview; it may have been a transcription slip, so it's unconfirmed)
**Version:** 0.1 (post-interview draft)
**Date:** 2026-10-28

> All numbers in this document (frame data, costs, HP, prices) are **starting values for tuning**, not final balance.

---

## 1. The Pitch

**One sentence:** *Street Fighter meets Slay the Spire.* You're a modular fighting robot climbing a branching ladder of 1v1 duels, ripping parts and software off the robots you beat and bolting them onto yourself until your build is busted.

**The feeling we want:**
- **Early run:** grounded, deliberate, readable. You win by spacing, blocking and reading your opponent.
- **Late run:** your robot is a monster you built. Combos get long or hits get enormous, the screen freezes and flashes, and you think "oh my gosh."
- **Every run:** skill and build matter about equally (Hades-like). A great build makes fights easier, but you still have to execute.

**Core design idea: depth by choice, not overload.** You start with almost nothing (4 buttons and one chain combo). Every new move, cancel route and synergy is something *you chose* to draft, the way a Slay the Spire deck grows from Strikes and Defends.

**Reference games**
| Love / borrow | What we take |
|---|---|
| Guilty Gear Strive | General combat feel, Roman Cancel, Burst, wall interactions |
| Street Fighter 6 | Drive system (Drive Rush, Overdrive), Classic and Modern controls |
| Slay the Spire | Branching map, drafting, persistent HP, rest sites, events, shop removal |
| Hades | Reward types shown on map nodes, themed boon sources leading to manufacturers, Duo boons |
| Balatro | Wild, stacking synergies, seeing your build trigger |
| Risk of Rain 2 | Difficulty tiers plus toggleable run modifiers (Artifacts) |
| Hi-Fi Rush | Art style: cel-shaded comic book with robots |

| Avoid | Why |
|---|---|
| Tekken-style combo memorization | Too much to learn up front |
| A roguelike fighter the designer played (name forgotten): side-scrolling levels, clunky combat, gross art | Walking levels felt bad, and polish is the whole point |

---

## 2. Project Context

| | |
|---|---|
| **Developer** | Solo designer and beginner programmer; Claude writes most of the code, kept simple and readable |
| **Art** | Friend or paid artist (placeholder art until the combat is fun) |
| **Goal** | Passion and learning project first, with a possible commercial (Steam) release later |
| **Pace** | Assumed 5–10 hrs/week, no deadline → small, always-playable milestones |
| **Platform** | PC (Windows/Mac/Linux). Optional browser build for sharing. Console = "maybe someday." |
| **Engine** | **Godot 4, GDScript** (free, no royalties, beginner-friendly, text-based code) |
| **Perspective** | **2.5D**: 3D models on a 2D fighting plane, single-screen arenas, side view |
| **Input** | Controller, keyboard and arcade stick/hitbox treated equally. Fully remappable. SOCD cleaning. |
| **Online** | Never required. Works fully offline. |
| **Monetization** | **No microtransactions.** Ever. |

---

## 3. Core Loop

```
Garage (pick difficulty, modifiers, starting robot)
   ↓
Act Map ──► choose node (reward type visible) ──► Fight / Elite / Event / Shop / Rest
   ↑                                                   │
   └───────── draft reward (pick 1 of 3), HP persists ◄┘
   ↓ (end of act)
Rest node → Boss (best-of-3) → full heal → next act
   ↓ (after Act 3 boss, or death)
Unlocks (boss parts, modifiers) → back to Garage
```

**Moment-to-moment:** fight a 1v1, then cut to the map, choose your next node, and draft.
**Run:** 3 acts, about 45–60 minutes, about 15–20 fights total.
**Meta:** beat bosses to unlock their parts, build new starting robots, unlock run modifiers.

---

## 4. Combat System Spec

### 4.1 Simulation fundamentals
- **Fixed 60 ticks/second** game logic in `_physics_process`, fully separate from rendering. All frame data is in ticks ("frames").
- **Integer (fixed-point) positions and velocities** for gameplay (e.g. 1 unit = 1/1000 of a pixel-equivalent). Avoid floats in combat logic, so the game is **deterministic**: same inputs give the same result. That enables replays, reliable testing and rollback netcode later.
- **Custom hitbox/hurtbox system** (axis-aligned rectangles on the 2D plane), **not** Godot's physics engine (which isn't deterministic or frame-exact).
- The 3D model and animation are **visual only**. The animation is driven by seeking to `move_frame / 60` each tick, so visuals always match the frame data.
- Fighters always **auto-face** each other. A **pushbox** prevents overlapping.

### 4.2 Controls
**Buttons:** `L` Light · `M` Medium · `H` Heavy · `S` Special
**Directions:** numpad notation (`4` = back, `6` = forward, `2` = down, `236` = quarter-circle forward, etc.)

**Control schemes**
- **Classic (MVP):** specials use motion inputs (`236S`, `623S`, `214S`, `22S`).
- **Simple (post-MVP):** specials use direction + S (`5S`, `6S`, `4S`, `2S`). Assisted specials deal **~80% damage** (tunable).
- Each move is defined **once**, with both input recipes attached.

**Input system requirements**
- **Input buffer** of about 8 frames (a press slightly early still comes out).
- **Motion input parser** with lenient windows (e.g. `236` completed within about 12 frames, `623` accepts `6236` shortcuts).
- **Simultaneous-press window** of about 3 frames for multi-button inputs (throw, meter actions). ⚠️ This must not collide with fast `L→M` chains (see Risks).
- **SOCD cleaning:** Left+Right = neutral, Up+Down = Up (configurable).
- Remapping for all devices from day one.

### 4.3 Base kit (every run starts here)
| Category | Contents |
|---|---|
| Movement | Walk, crouch, jump (neutral/forward/back), forward dash `66`, backdash `44` |
| Normals | `5L 5M 5H` standing, `2L 2M 2H` crouching (2H = sweep), `j.L j.M j.H` air |
| Special | One basic special from the starting Head part (`236S`) |
| Chain | **L → M → H → S** (each normal cancels into the next on hit or block) |
| Defense | High/low block, timed Parry, Throw (`L+M`) and Throw Tech |
| Meter | Full 6-bar meter with 4 actions, plus **one Super move** at max meter (below) |

**Example starting frame data (placeholder)**
| Move | Startup | Active | Recovery | On block | Notes |
|---|---|---|---|---|---|
| 5L | 4 | 2 | 8 | +1 | Fast jab, chains to M |
| 5M | 7 | 3 | 14 | −2 | Mid-range poke |
| 5H | 11 | 4 | 20 | −6 | Big hit, chains to S |
| 2H | 9 | 3 | 24 | −12 | Sweep, hits low, knockdown |
| 236S | 14 | 4 | 22 | −8 | Basic dash punch (starter Head) |
| Throw L+M | 5 | 3 | 22 | — | Beats block, techable |

### 4.4 Defense
- **Block:** hold `4` for a standing block (stops highs and mids), hold `1` for a crouching block (stops lows and mids). Overheads must be blocked standing, lows crouching. Specials deal small **chip damage** on block.
- **Parry ("Just Defend"):** press `4` or `1` within about **5 frames** before a hit lands.
  - No chip damage, **bonus meter**, about **+4 frame advantage** (enough to punish with a light, not a full combo), and a distinct flash and sound.
  - A mistimed parry is just a normal block, so it's low-risk, and the reward stays deliberately modest. Chips can boost it.
- **Throw:** `L+M` at close range. **Tech:** press `L+M` within about 7 frames of being grabbed. Throws beat blocking, strikes beat throws.

### 4.5 The Drive Meter (6 bars)
**Gain:** **only from fighting.** Landing hits (most), getting hit, blocking, parrying (bonus). **Starts at 0 every fight.** No passive regeneration.

| Action | Inspired by | Input (proposed) | Cost |
|---|---|---|---|
| **Drive Rush** | SF6 | `M+H` in neutral | 1 bar |
| **Cancel Rush** | SF6 | `M+H` during a cancelable move | 3 bars |
| **Overdrive special** | SF6 OD | Special motion + `S+H` | 2 bars |
| **Move Cancel** | GG Roman Cancel | `L+M+H` during any move | 3 bars |
| **Combo Breaker** | GG Burst | `M+H` while in hitstun | 4 bars |
| **Super** | SF/GG supers | `236236S` (Simple: `S+L`) | **6 bars (full meter only)** |

The normal dash `66` is free. Drive Rush is the meter-powered version.

**Super:** every robot starts with **one Super move**, usable only at full meter (6 bars) and spending all of it. The starting Core part provides a basic super (e.g. a big cinematic rush punch). **Drafted Core parts replace it** with different supers, so the super is part of your build. It gets the cinematic camera, a big freeze and slow-mo, and it's the main way to spend a full meter besides holding it for Combo Breakers and Move Cancels. Chips and Core parts can modify costs and effects (e.g. "Combo Breaker costs 3," "Drive Rush leaves a fire trail").

### 4.6 Combos, hitstun and juggles
- **Hitstun/blockstun** per move. Counter-hits get extra hitstun and a big "COUNTER!" effect.
- **Damage scaling:** 100%, 100%, then −10% per hit, minimum 20% (tunable). Keeps combo builds and power builds in similar damage ranges.
- **Juggle limit:** each launching move has a juggle cost, and the opponent falls out when the limit is reached. Chips can raise it (combo builds).
- **Walls:** screen-edge walls. **Wall bounce/splat** comes from specific parts and chips. **Wall break** (GG-style stage transition) is a later polish feature.
- **Speed curve:** the base kit is grounded and deliberate (short 3–5 hit combos). Drafted parts and chips add air dashes, launchers, cancels and bounces, pushing toward Guilty Gear speed **if the player builds that way**, or toward short, brutal high-damage combos.

### 4.7 Game feel
| Tool | Baseline | Scales up with |
|---|---|---|
| Hitstop | L 6f, M 8f, H 11f, counter +4f | Legendary/Duo effects up to 20–30f freezes |
| Screen shake | Small on H and counters | Big hits, KOs, Legendaries |
| Effects | Sparks, debris, comic impact text ("CRUNCH!") | Unique VFX per Legendary/Duo |
| Camera | Static framing on both fighters | Zoom/tilt on big hits, cinematic KO |
| Slow-mo | Final KO hit | Perfect parries, Duo triggers |
| Audio | Layered metal impacts, servo whirs, crowd | Bigger, distinct stingers |

**Rule:** the effects **scale with the build.** Restrained at run start, explosive by Act 3. Includes an **effects intensity slider** in settings.

---

## 5. The Robot: Parts and Chips

### 5.1 One fighter, one skeleton
There's a single playable robot on **one humanoid skeleton.** Identity comes entirely from what you install.

**🔧 Hard art rule:** every part, including boss parts, fits the shared skeleton. Parts can be bigger or weirder (a giant claw arm), but they bend at the same joints. Truly different bodies (treads, quadrupeds) are boss-only exceptions, if ever.

### 5.2 Part slots and input ownership
Each part **owns specific inputs.** Swapping a part replaces exactly those moves.

| Slot | Owns | Classic special | Simple special |
|---|---|---|---|
| **Head** | Neutral special | `236S` | `5S` |
| **Right Arm** | `5L`, `5M`, `j.L`, plus 1 special | `623S` | `6S` |
| **Left Arm** | `5H`, `j.H`, plus 1 special | `214S` | `4S` |
| **Legs** | `2L 2M 2H`, `j.M`, movement options (air dash, double jump, run), plus 1 special | `22S` | `2S` |
| **Core** | **Super move**, Overdrive versions, meter behavior and gain modifiers | `236236S` (super) | `S+L` (super) |

- The starting robot ("Frame-0") has basic parts. Only the Head has a special. The other special slots are empty until you draft parts that fill them.
- **Replaced parts are gone** (no selling, no inventory). Every swap is a commitment.
- Some **chips add extra motion-input moves** to a part (e.g. *"Rising Uppercut.exe": Right Arm gains `214H`*).

### 5.3 Chips (software)
- Passive effects and synergies, shown in the **HUD chip strip**, which flashes when a chip triggers.
- Built on **event hooks:** `on_hit`, `on_counter_hit`, `on_block`, `on_parry`, `on_throw`, `on_meter_spent`, `on_combo_n`, `on_wall_bounce`, `on_fight_start`, `on_ko`, etc.
- No hard chip limit at first (Balatro-style stacking). Add a cap later if playtests demand one.

### 5.4 Synergy structure
**Manufacturers** (flavor, visuals, set bonuses, Duos). Placeholder names:
| Manufacturer | Theme | Archetype |
|---|---|---|
| **Kinetik** | Speed, cancels, multi-hit | Combo builds *(MVP)* |
| **Forge Heavy** | Heat, burn, huge single hits | Power builds *(MVP)* |
| **Voltline** | Electric, stun, chain lightning | Control |
| **Bastion** | Armor, parry, counters | Defense |
| **Scrapjack** | Junkyard randomness, gambling | Chaos (Act 1 flavor) |
| **Apex Corp** | Polished, meter manipulation | Act 3 corporate brand |

- **Set bonuses:** e.g. 2 Forge items give "Heavies burn," and 4 Forge items give "Burn explodes on KO."
- **Duo chips:** require items from two brands. E.g. *Kinetik + Voltline gives "Static Flurry": every 5th hit in a combo chains lightning.*

**Tags** (deep synergies): `Multi-hit`, `Heavy`, `Projectile`, `Low`, `Overhead`, `Grab`, `Parry`, `Counter`, `Overdrive`, `Meter`, `Air`, `Wall`, `Burn`, `Shock`.
Example: *"Momentum Engine: +4% damage per Multi-hit move you own."*

### 5.5 Rarity
| Rarity | Power level |
|---|---|
| Common | Solid, in "even split" territory |
| Rare | Build-shaping, still fair |
| Epic | Strong, archetype-defining |
| **Legendary / Duo** | **Allowed to break the game.** This is where the Balatro moments live. |

### 5.6 Consumables
Post-MVP option (Slay the Spire potions): repair kits, overclock charges, one-fight buffs.

---

## 6. Run Structure

### 6.1 Map
- Slay the Spire-style **branching map**, 3 acts.
- Each act has about 12 rows: **~5–7 fights, 1–2 elites, 2–3 events, 1 shop, 1–2 rest nodes**, then a **guaranteed rest node** and the **Boss**.
- **Node icons show the reward type** (Hades-style): Head / Right Arm / Left Arm / Legs / Core / Chip / Rare / Scrap. Part nodes are **less common** than chip nodes.
- Some fight nodes show an **arena hazard** icon (electric walls, crusher, oil slick).

### 6.2 Acts and setting
| Act | Setting | Music (assumed) | Opponents |
|---|---|---|---|
| 1 | **Junkyard pits** | Grungy rock / industrial | Scrappy, few parts, slow reactions, rarely parry |
| 2 | **Underground circuits** | Electronic / bass-heavy | Better builds, mixed personalities, tech throws |
| 3 | **Corporate championship** | Big arena rock / synth | Full builds, fast reactions, parry often |

### 6.3 Health and death
- **Hull HP persists** across all normal and elite fights. Each is **one round**, ending at 0 HP.
- **Healing:** rest nodes (Repair), shop (repairs), chips and events.
- **Boss:** optional rest node right before it (no guaranteed heal). The boss is a **best-of-3 set** that escalates each round (round 2 adds moves, round 3 is desperation mode). **Guaranteed full heal after.**
- **Death:** 0 HP or losing the boss set ends the run. Revives exist only as rare drafted items.

### 6.4 Node types
| Node | What happens |
|---|---|
| **Fight** | 1v1 vs a part-built AI robot. Reward: pick 1 of 3 of the node's type, plus Scrap. |
| **Elite** | Tougher robot, more chips, smarter AI. Reward: Rare+ pick, plus more Scrap. |
| **Event "?"** | Text event with choices (trade-offs, gambles, flavor), **or** a challenge fight (time trial, no-block, no-meter, mini-fight, later light crowd fights) |
| **Shop** | Spend Scrap on parts, chips, repairs, chip upgrades, chip removal |
| **Rest** | Choose one: **Repair** (~30% HP), **Tune-up** (upgrade a part or chip), **Train** (skill challenge for a reward) |
| **Boss** | Best-of-3, signature robot. Drops a signature part (choice) and unlocks it for meta. |

### 6.5 Economy
- **One currency: Scrap.** Earned from fights (more from elites and clean wins), spent at shops.
- No selling or scrapping of items.
- Placeholder prices: Common chip 50, Rare 100, part 120–200, repair 40, removal 75 (escalating).

---

## 7. Opponents and AI

### 7.1 Opponent design
- **Every opponent is a robot built from the same part and chip pool** as the player. New enemies are mostly **new combinations**, so content is cheap, and the player can see what they might earn.
- **Elites:** stronger builds, set bonuses, better AI tier.
- **Bosses:** **signature parts and unique mechanics**, escalation between rounds, distinct silhouettes, still on the shared skeleton so their parts can be stolen. One boss per act; the Act 3 boss is the corporate champion.

### 7.2 AI architecture
- **Personality profiles:** Rusher, Turtle, Zoner, Grappler (more later). Each is a set of weights over actions (approach, poke, jump, block, parry attempt, throw, special, meter use).
- **Perception via game state, never raw inputs.** The AI sees what a human could see (your current animation after it starts, distance, meter, HP).
- **Human-like reaction delay** per difficulty (e.g. Act 1 about 20f, Act 3 about 10f, plus randomness).
- **Difficulty scales** by reaction speed, action options (e.g. parry and throw tech only unlocked from Act 2) and build quality. **Never by cheating.**
- **Later:** habit tracking for elites and bosses (e.g. "player jumps a lot, so anti-air more").

---

## 8. Difficulty and Modifiers (Risk of Rain 2 style)
- **3–4 difficulty tiers** chosen in the Garage (placeholder: *Scrap / Standard / Overclocked / Meltdown*). They scale enemy builds, AI reaction speed, healing and damage.
- **Run modifiers**, unlocked through meta-progression and toggled before a run. Good, bad, or weird:
  - *Glass Cannon:* 3× damage, 1/3 HP
  - *Scrapyard:* all rewards are random parts
  - *Mirror Match:* every opponent copies your current build
  - *Low Gravity*
  - *Black Market:* all chips are Legendary, but you get half as many

---

## 9. Meta-Progression
- **Unlocks only. No permanent stat power.**
- **Boss parts:** beating a boss unlocks its signature parts for **building custom starting robots** in the Garage. Some also enter the in-run draft pool.
- **Pool unlocks:** new parts, chips and manufacturers.
- **Modifiers and difficulty tiers** unlocked through wins and challenges.
- **Garage screen** (menu, not a walkable hub): build the starting robot, choose difficulty and modifiers, open training mode, view unlocks.

---

## 10. Story and World
- **Light environmental story.** No cutscenes.
- Underdog robot climbing from the junkyard pits to the corporate championship.
- Delivered through **boss intros and defeat lines**, **flavor text on parts and chips** ("Arm of the former champion. Still smells like ozone."), and **event writing**.
- Manufacturers act as in-world corporations and sponsors.

---

## 11. Art and Audio Direction

### 11.1 Visuals
- **Hi-Fi Rush style:** cel-shaded comic book, **bold black outlines**, flat bright colors, halftone shading, comic impact text.
- Clean, readable silhouettes. Parts should be recognizable at a glance (brand color plus shape language per manufacturer).
- Each act has its own palette (rusty junkyard, then neon underground, then glossy corporate arena).
- Godot implementation: toon shader (stepped lighting), inverted-hull or post-process outlines, halftone shader, sprite or decal comic text.

### 11.2 Artist spec (starter)
- One humanoid **skeleton**. All parts are skinned meshes swapped per slot.
- Animations are **per move, not per part.** A new part with new moves needs new animations, but no new rig.
- Each attack animation is delivered with **startup / active / recovery** key poses at defined frame counts (from the move's frame data).
- Core animation list (approx. 30): idle, walk F/B, crouch, jump (3), dash F/B, block stand/crouch, parry, hit reactions (high/low/air), knockdown, wakeup, throw/thrown, tech, 9 normals, 3 air normals, starter special, KO, intro, win pose.

### 11.3 Audio
- **Music:** high-quality, **no gameplay connection.** Act-themed (rock/industrial, then electronic, then arena rock/synth). Music licensing should be sorted before any commercial release.
- **SFX:** layered metal impacts by hit strength, mechanical servos, a distinct parry "ting," a crowd that reacts in later acts. Optional commentator later.

---

## 12. UI / HUD
- **Fight HUD:** health bars with a red **recoverable-damage trail**, both 6-bar meters, combo counter with damage, round indicators (boss only), and a **chip strip** under your health bar where chips **flash when they trigger**.
- **Pause menu:** full **move list with inputs** (per installed part), installed parts and chips with descriptions.
- **Map screen:** branching map with reward-type and hazard icons, current HP, Scrap.
- **Reward screen:** pick 1 of 3 cards showing name, rarity, manufacturer, tags and, for parts, which inputs change.
- **Garage:** robot builder, difficulty, modifiers, training, unlocks.
- **Training mode** (staged):
  1. **Dev room:** dummy, reset, hitbox view, frame data overlay, input display. *(Day one.)*
  2. **Player training:** any unlocked parts and chips, dummy settings (stand/crouch/block/jump/record and playback).
  3. **Tutorials and combo trials:** basics (block, parry, throw, meter) and per-part trials. These also supply the **Train** rest-node challenges.
- Settings: full remapping, control scheme (Classic/Simple), effects intensity slider, SOCD mode.

---

## 13. MVP Feature List — "One act, one robot, does it feel good?"
- [ ] 1 robot, base kit: L/M/H/S, chain, block high/low, parry, throw and tech, walk, crouch, jump, dash
- [ ] **Classic** motion inputs, input buffer, SOCD, remapping
- [ ] Full 6-bar meter with Drive Rush, Overdrive, Move Cancel, Combo Breaker, plus **one starting Super** (6 bars)
- [ ] Damage scaling, juggle limit, basic walls
- [ ] Game feel baseline: hitstop, shake, sparks, sounds, combo counter
- [ ] Parts system (5 slots, input ownership), **~10–12 parts**
- [ ] Chip system (event hooks, tags), **~20 chips**, **2 manufacturers** (Kinetik, Forge Heavy), Common and Rare only
- [ ] **4–5 AI opponents** (personality AI on part-built robots), **1 elite**, **1 boss** (best-of-3)
- [ ] **1 act** of branching map: fights, elite, shop, rest (Repair/Tune-up), ~5 text events, boss
- [ ] Reward-type icons on nodes, pick 1 of 3, persistent HP, Scrap
- [ ] Fight HUD with chip strip, pause move list
- [ ] Dev training room
- [ ] Placeholder or simple art

## 14. Later / Stretch Features
**Next after MVP (roughly in priority order)**
1. Real robot model and Hi-Fi Rush shader pass
2. Acts 2 and 3, Act 2 and 3 bosses, more opponents
3. Simple control scheme
4. Epic and Legendary rarity, Duo chips, set bonuses, 2–4 more manufacturers
5. Meta-progression: Garage, boss-part unlocks, custom starting robots
6. Difficulty tiers and run modifiers
7. Train rest option, player training mode, tutorials and combo trials
8. Challenge-fight events (time trial, no-block, etc.)
9. Arena hazards on nodes, wall bounce/splat content
10. Build-scaling game feel (Legendary freezes, slow-mo, unique VFX)

**Stretch**
- AI habit-punishing for elites and bosses
- Consumables
- GG-style wall breaks
- Light crowd-fight nodes (the code avoids assuming exactly one opponent)
- **Draft Duel PvP** (loser of each round drafts an upgrade), local first, then online with rollback
- Commentator voice lines
- Steam release: achievements, Steam Deck verification, controller glyphs

## 15. Hard "No" List
- ❌ Side-scrolling or walking levels
- ❌ Clunky, stiff combat
- ❌ Gross or ugly art
- ❌ Memorization-heavy combos at the start
- ❌ Music-synced gameplay
- ❌ Permanent stat power from meta-progression
- ❌ AI that reads inputs or cheats
- ❌ Microtransactions
- ❌ Required internet connection

---

## 16. Build Plan (playable as early as possible)

Each milestone ends with **something you can play.** Placeholder art (capsules and boxes) until Milestone 12.

| # | Milestone | Playable result |
|---|---|---|
| **0** | Setup: install Godot 4, create project, git repo, folder structure | Empty project runs |
| **1** | Fixed 60-tick loop, input system (buffer, SOCD, remapping), capsule robot walks/crouches/jumps in a training room, input display | **Move a capsule around with any controller** |
| **2** | `MoveData` resource (startup/active/recovery, hitboxes, damage, hitstun), hitbox/hurtbox system, training dummy with HP, hitstop, frame-data debug overlay | ⭐ **One robot hitting a training dummy** |
| **3** | All normals, L→M→H chain, high/low block, blockstun, pushback, dash, knockdown | Pressure the dummy, which can block |
| **4** | Motion input parser, `236S` special, throw and tech, parry | Full base kit vs dummy |
| **5** | Drive Meter, 4 actions and the starting Super, damage scaling, juggle limit, walls | Combos, meter and a Super in training |
| **6** | Game feel pass 1: shake, sparks, sounds, combo counter, fight HUD | It *feels* good |
| **7** | Fight flow (intro, KO, win/lose) and **first AI** (one personality) | ⭐ **First real fight vs AI** |
| **8** | Parts system: 5 slots, parts override inputs, swap in training room, part meshes (placeholder shapes) | Swap an arm and get a new move |
| **9** | Chips: event hooks, tags, chip strip HUD, 2 manufacturers | Synergies firing in training |
| **10** | Run loop: map generation, node types, reward icons, pick 1 of 3, persistent HP, Scrap, shop, rest, text events | ⭐ **First full roguelike run (1 act)** |
| **11** | More AI personalities, elite, boss best-of-3, MVP content (~12 parts, ~20 chips, 5 events), balance passes | ✅ **MVP complete** |
| **12** | Art pipeline: real robot model, toon/outline/halftone shaders, first animations | MVP looks like the game |
| 13+ | Work down the Later list (Section 14) | — |

**Code architecture notes for the beginner-friendly build**
- Moves, parts, chips, opponents and events are all **data files (Godot Resources, `.tres`)**, so most content is added without new code.
- The fighter is a **state machine** (Idle, Walk, Crouch, Jump, Attack, Hitstun, Blockstun, Knockdown, Thrown, etc.).
- Combat logic is **separate from visuals**, so placeholder capsules can be swapped for real models without touching combat code.
- Nothing hard-codes "exactly one opponent," which leaves room for crowd nodes later.

---

## 17. Open Questions and Risky Decisions

### Open questions
1. **Title:** was "Aetheros" meant as the game's name?
2. ~~Super moves~~ **Decided:** one Super from the start, costs the full 6-bar meter. Core parts swap which super you have.
3. **Hours per week:** assumed 5–10. Affects milestone pacing.
4. **Music genre:** assumed act-based rock, then electronic, then arena rock/synth. Confirm with your composer.
5. **Meter inputs:** proposed `M+H` / `L+M+H` / `S+H` layouts need playtesting, especially on keyboard.
6. **Part slot count:** 5 slots proposed. Is that enough build space with no chip limit?
7. **Clean-win rewards:** how much bonus Scrap for low-damage wins?
8. **Boss loss:** confirmed as run-ending. Should a modifier or difficulty tier soften it?

### Risks
| Risk | Why it's risky | Mitigation |
|---|---|---|
| **Fighting game as a first project** | Frame precision, input handling and AI are hard to get right | Very small milestones, debug overlays from day one, Claude writes the code |
| **3D for a beginner** | Rigging, animation import and shaders are complex | Capsules until Milestone 12. Combat is decoupled from visuals. |
| **Animation volume** | Every drafted move needs an animation, so the artist is the bottleneck | Shared skeleton, animations per move, parts reuse animations where possible, frame specs given to the artist |
| **Fighting AI quality** | Usually either dumb or cheating | Personality weights plus reaction delays, playtest each profile, adaptation later |
| **Persistent HP + fighting-game variance** | One bad fight early can ruin a run | Tune enemy damage, rest/shop healing and clean-win rewards. Difficulty tiers. |
| **Balatro-level breakage** | Can trivialize the AI and make fights pointless | Breakage limited to Legendary and Duo items, damage scaling, juggle limits, boss escalation |
| **`L+M` throw vs `L→M` chain** | Fast chain presses can turn into accidental throws | Tight simultaneity window (about 2–3f), throw only at close range, playtest |
| **Low-risk parry** | A mistimed parry is a free block, so players may mash back | Modest parry reward, possibly a lockout after a failed timing |
| **Determinism in Godot** | Floats and physics break rollback and replays | Integer math in combat logic, custom collision, no Godot physics for gameplay |
| **Scope creep** | Many attractive systems (Draft Duel, story, wall breaks) | Stick to the MVP list. Everything else waits in Section 14. |
