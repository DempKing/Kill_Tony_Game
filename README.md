# Kill Tony: The Game

A single-player comedy career and life simulation for Windows PC / Steam.
You arrive in Austin, Texas with $180, a bag, and a journal of bad jokes.
Work bad jobs, find material, write, bomb, improve, and try to turn a Kill
Tony bucket pull into a career.

> **Status: Phase 1 (Austin arrival) and the Phase 2 Kill Tony slice are
> written, but have never been run.** Godot wasn't available in the
> environment this was built in, so no scene, script or test here has been
> run or exported yet. Run the tests below first. See
> [docs/IMPLEMENTATION_STATUS.md](docs/IMPLEMENTATION_STATUS.md).

## Engine

- **Godot 4.3 stable** (standard build, not .NET), typed GDScript.
- Renderer: GL Compatibility (broad Windows GPU support).
- No external services, no AI services, no Steam needed to run.

## Run

1. Install Godot 4.3: https://godotengine.org/download
2. Open `project.godot` in the editor (this imports the project and builds
   the global class cache), then press F5. Or from a terminal:
   ```
   godot --path . --import          # first time only
   godot --path .
   ```
3. Main scene: `res://scenes/boot/boot.tscn`.

The game runs fully offline. In debug/editor runs, F12 opens the developer
panel.

## Tests

```
godot --headless --path . --import
godot --headless --path . -s res://tests/run_tests.gd
```
Exit code 0 means every test passed. See [docs/TESTING.md](docs/TESTING.md).

## Export (Windows)

1. Install the Godot 4.3 export templates (Editor → Manage Export Templates).
2. `export_presets.cfg` defines:
   - **Windows Desktop (Release)**: no developer panel, tests excluded.
   - **Windows Desktop (Dev)**: adds the `dev` feature tag so the developer panel works.
3. `godot --headless --path . --export-release "Windows Desktop (Release)" export/windows/KillTonyTheGame.exe`

The `include_filter` packs the JSON content under `data/`. **The export has
not been tested.**

## Controls

| Action | Keyboard | Controller |
|---|---|---|
| Move | WASD / arrows | D-pad / left stick |
| Interact | E | A |
| Journal | J | Y |
| Phone / calendar | P | X |
| Wait one block | T | RB |
| Menu / back | Esc | Start / B |

Keys can be remapped in Settings.

## Docs

- [GAME_DESIGN.md](docs/GAME_DESIGN.md): mechanics as implemented
- [ARCHITECTURE.md](docs/ARCHITECTURE.md): systems, scenes, persistence, platform adapters
- [BALANCING.md](docs/BALANCING.md): economy, scoring, probabilities
- [CONTENT_GUIDE.md](docs/CONTENT_GUIDE.md): adding jokes, venues, NPCs, events, interviews
- [ASSET_APPROVALS.md](docs/ASSET_APPROVALS.md): placeholder vs approved assets
- [TESTING.md](docs/TESTING.md): automated and manual tests
- [IMPLEMENTATION_STATUS.md](docs/IMPLEMENTATION_STATUS.md): what's done, what isn't
- [STEAM_RELEASE_CHECKLIST.md](docs/STEAM_RELEASE_CHECKLIST.md)
