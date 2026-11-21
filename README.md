# Kill Tony: The Game

A single-player comedy career and life simulation for Windows PC / Steam.
You arrive in Austin, Texas with $180, a bag, and a journal of bad jokes.
Work bad jobs, find material, write, bomb, improve, and try to turn a Kill
Tony bucket pull into a career.

## [▶ Play in your browser](https://dempking.github.io/Kill_Tony_Game/)

[![Play now](https://img.shields.io/badge/%E2%96%B6%20PLAY%20NOW-in%20your%20browser-b88cff?style=for-the-badge)](https://dempking.github.io/Kill_Tony_Game/)

No install needed: **https://dempking.github.io/Kill_Tony_Game/**. Click the
page once to enable sound. Progress saves in your browser.

> **Status:** prototype. All six phases run in Godot 4.3: Austin arrival,
> Kill Tony nights, the living Austin career, touring, arenas and legacy, and
> a Steam stub.
> - **3D:** the street, the clubs, tour venues and the Kill Tony stage are 3D.
>   Art is CC0 from Poly Haven and Quaternius; nothing is partner-approved.
> - **Tests:** 944 automated checks pass, and a scripted playtest drives the
>   game from the title screen to an arena show.
> - **Not yet done:** a human playtest, running the Windows build on Windows,
>   frame-rate checks on real GPUs, and Steam.
>
> See [docs/IMPLEMENTATION_STATUS.md](docs/IMPLEMENTATION_STATUS.md).

## Browser build

Every push to `main` runs the tests, builds the web version, and publishes it
to GitHub Pages (`.github/workflows/pages.yml`). Use a desktop browser
(Chrome, Edge or Firefox) with WebGL 2. It has been tested in headless
Chromium only, not yet on real hardware.

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

## Automated playtest (dev only)

```
godot --path . -- --playtest=/some/output/dir
```
Add `--artshots` for a quick visual pass (about 10 key screens). The full run
plays through the title screen, character creation, the arrival, the
journal, the hostel, an open-mic set with results, Monday signup, and a full
Kill Tony night (forced pull, set, interview, rewards). It saves a numbered
screenshot at each step. It needs a display; on a headless Linux box use
`xvfb-run`.

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
