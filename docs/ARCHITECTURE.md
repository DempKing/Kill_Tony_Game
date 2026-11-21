# Architecture

```
res://
  project.godot            autoloads, display, renderer
  export_presets.cfg       Windows release + dev presets (untested)
  scenes/                  thin .tscn roots; UI is built in code
    boot/ character_creation/ district/ performances/
  scripts/
    core/                  ContentDB, GameState, autoloads (Game, GameSettings, Sfx)
    simulation/            pure rules, no scene or autoload dependencies
    persistence/           SaveManager (autoload), SaveMigrations
    platform/              PlatformAdapter interface, NullPlatform, SteamPlatform stub, PlatformService (autoload)
    world/                 scene controllers (district, club stage, Kill Tony, tour) and 2D logic nodes
    world3d/               3D presentation: District3D, Stage3D, KtStage3D, Character3D, Crowd3D, Mat3D, ModelLib
    ui/                    UiKit, UiLayer (modals), HUD, journal, phone, settings, saves, dev panel
  data/                    authored content (JSON, stable string ids)
    balancing/ character/ events/ interviews/ jobs/ material/ npcs/ opportunities/ venues/
    partner/               ALL real-person, show-identity and partner-specific content
  assets/textures/polyhaven/ assets/models/polyhaven/   CC0 Poly Haven textures and models
  assets/models/quaternius/   CC0 Quaternius characters, hair, animations, cars
  assets/placeholder/ assets/approved/   (empty)
  tests/                   headless runner + unit suites
  tools/                   dev-only asset prep (Quaternius import helpers); excluded from exports
  docs/
```

## Layers
1. **Content** (`ContentDB`): loads JSON into id-keyed dictionaries, derives
   compatibility tags, and validates references (unknown families, events, venues,
   audiences, locations, components). Validation errors appear in the developer
   panel and on the title screen.
2. **State** (`GameState`): one serializable object. `to_dict()`/`from_dict()`,
   `SAVE_VERSION`, three RNG streams (`bucket`, `performance`, `world`) whose seed
   and state are stored as strings so 64-bit values survive JSON.
   `normalize()` turns whole-number floats back into ints after parsing.
3. **Rules** (`scripts/simulation/*`): static functions over `(GameState, ContentDB)`.
   - `CalendarRules`, `Scheduler`: time and commitments
   - `StatsRules`: ledger, stats, the generic effects processor
   - `JokeRules`, `SetRules`, `WritingRules`: material
   - `PerformanceSim`: a stateful, seeded set
   - `JobRules`, `WorldRules`: day start, rent, NPC schedules, observations, events
   - `OpportunityRules`, `KillTonyRules`, `RewardRules`, `CareerRules`, `Relationships`
   - `GameSim`: the facade scenes call (actions, time, performances)
4. **Scenes and UI** read state, call GameSim, then call `Game.notify()` to refresh the HUD.
5. **Platform** (`PlatformService` → `PlatformAdapter`): achievements, save
   directory, identity. `NullPlatform` is always used in this build.

## 3D presentation
The game renders in 3D (GL Compatibility renderer, so the web build works).
The rules didn't change: they still work in 2D "map pixels".
- **District:** `DistrictMap`, `PlayerActor` and `StreetNpc` still handle
  layout, collision, input and schedules. They sit in a hidden `CanvasLayer`.
  `District3D` mirrors them at 0.04 m per pixel (map y becomes +Z, south).
  It also runs the follow camera, time-of-day lighting, and the cutaway of
  south buildings that would block the view.
- **Stages:** `Stage3D` and `KtStage3D` keep the knobs the scene controllers
  already set (`reaction`, `light_on`, `guests`, `redban_cue`, ...).
  `KtStage3D` places the panel, Redban's station, the mic, the bucket and the
  band from the x positions in `kill_tony_stage_layout.json`. Its cameras
  come from `cameras_3d`.
- **UI** is unchanged: 2D `Control`s on a `CanvasLayer` over the 3D view.
  Interiors are still 2D panels.

## Autoloads (in order)
`GameSettings` → `PlatformService` → `Sfx` → `Game` → `SaveManager`.

## Scene flow
`boot` → `character_creation` → `district` ⇄ `performance` (generic stage) /
`kill_tony_stage`. Loading a save resumes an interrupted performance or Kill
Tony night in its own scene.

## Persistence
- Slots: `autosave`, `slot_1..3` under `PlatformService.save_directory()`
  (default `user://saves`).
- Writes go to `.tmp`, the previous file is copied to `.bak`, then the `.tmp` is
  renamed into place. A malformed main file falls back to `.bak`.
- `SaveMigrations.migrate()` upgrades older versions step by step. A save from a
  newer version is refused.
- Export copies a slot to `user://exports/` with a timestamp.
- Autosave runs whenever time moves, before every performance, before the bucket
  reveal, and at each Kill Tony phase.

## Exactly-once
`state.claimed` holds claim ids:
- `shift_<job>_<day>_<block>`
- `applied_<perf id>`
- `pay_<commitment id>`
- `kt_<day>_<reward>`
- `kt_<day>_network`

`RewardRules.claim()` returns true only the first time.

## Randomness
- **bucket:** draw, golden-ticket roll.
- **performance:** per-set seeds, interview prompt choice.
- **world:** events, shift events and tips, writing rolls, opportunities.

Each performance stores its seed in `flags.active_performance` before it starts.

## Platform adapter
`PlatformAdapter` defines `initialize`, `unlock_achievement`,
`is_achievement_unlocked`, `save_directory`, `user_display_name` and `shutdown`.
`SteamPlatform` is a non-functional stub that `PlatformService` never selects.
Achievement hooks: `first_set`, `first_bomb`, `bucket_pull`, `secret_show`,
`first_paid_set`.

## Partner content separation
Real-person names, show signage text, panel/band placeholders, show-specific lines
and the Kill Tony stage layout live only in `data/partner/`. Fictional NPCs live
in `data/npcs/`. A test enforces that partner ids don't leak into the NPC file.
