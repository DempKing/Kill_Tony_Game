# Implementation Status

_Last updated: second pass. That pass replaced pronouns with gender, added 59
joke pieces, and added promises, street NPCs, venue stages, the day summary and
regular status._

## Critical limitation
The build environment had no Godot binary, and running a downloaded one was not
allowed. So:
- **None of this has been run:** no project, scene, script or test.
- There may be GDScript parse or type errors. Static cross-reference checks were
  done by script; real compilation was not.
- Nothing has been exported.

Second pass: every `.gd` file was parsed with `gdtoolkit` (a GDScript 4 parser),
and they all parse. Parsing checks syntax only, not types or runtime behavior.
Data cross-references were checked by script.

First step on a machine with Godot 4.3: open the project, fix any parse errors the
editor reports, then run the tests (TESTING.md).

## Existing project (before this pass)
The repository held only a one-line README. There were no conflicts with the spec.
The working title was changed to **Kill Tony: The Game** (`project.godot`,
README, exports).

## Done (code written, not run)

### Phase 1: Austin arrival slice
- Godot 4.3 desktop project with autoloads and export presets.
- Character creation: name, stage name, gender, appearance, 5 backgrounds,
  6 styles.
- Arrival tutorial driven by actions, with a goal tracker.
- Compressed fictional district: a main street, an alley, and 11 locations
  including the Comedy Mothership. Also observations, posters, crowds,
  time-of-day tint, collision, interaction prompts, and fast travel.
- Interiors: illustrated vignettes with action lists, NPC presence, and conflict
  warnings.
- Calendar with blocks and commitments, a wait action, an all-nighter penalty,
  and sleep.
- Economy: ledger, daily essentials, rent, debt, couch fallback, housing upgrade.
- Jobs: server, doorman, delivery, and emergency day labor, with shift events.
- Joke journal: build/rewrite, revisions, WIP capacity, archive, material
  browser, notes, shelf, secondary style.
- Writing sessions: develop, polish, rehearse, with a pity counter.
- Set builder (open-mic set plus prepared minute) with analysis.
- Seeded decision-based performance, explainable feedback, and result
  application.
- Save/load: autosave plus 3 slots, .bak recovery, migrations, export.
- Settings: window mode, resolution, 4 volume buses, text size, reduced motion,
  subtitles, key remap, focus outlines.
- Procedural placeholder SFX and music, with subtitle hooks.
- Developer panel (dev builds only).

### Phase 2: Kill Tony slice
- Monday signup with an information and conflict dialog.
- Bucket draw persisted before reveal.
- Dedicated stage blockout (mic, panel desk with 3 seats, band riser, audience
  rows, camera framings per phase).
- One-minute set with play-off.
- Panel reaction beat.
- 3-prompt contextual interview.
- Independent, idempotent rewards.
- Redban Secret Show invitation leading to a Thursday booking, with conflict
  check.
- Resumable phases.

### Phase 3 (partial)
- 8 NPCs with schedules and 5-axis relationships.
- 10 opportunity templates: showcases, late spots, an opener slot, the Secret
  Show, and rebooking.
- Career tiers 0–4.
- Housing upgrade.
- Posters and marquee change with progress.

### Second pass
- Gender (male/female) replaces pronouns, with save migration v1→v2.
- 10 new joke families plus extra pieces for existing ones. Each has a real
  in-play source, checked by a test.
- NPC promises/favors, including job-shift promises.
- Street NPCs that walk between scheduled spots.
- Priya as a second workshop partner.
- Four distinct venue stages and host intros.
- End-of-day summary.
- Kill Tony regular status (offer, biweekly spot, new-material strikes).
- 12 more world events and 3 more interview prompts.

### Content counts
- 22 families
- 124 components
- 8 NPCs
- 6 audiences
- 18 interview prompts
- 32 world events
- 10 opportunities
- 4 jobs
- 5 venues (open mic, showcase, late show, Kill Tony, Secret Show)

## Not done / known gaps
- **Untested and uncompiled** (see above).
- Interiors are vignette panels, not walkable side-view rooms.
- Audio is procedural beeps and noise. There's no ambience bus content yet.
- Partway-through performances restart from the same seed on reload; your
  choices made before quitting aren't replayed.
- No NPC dialogue trees beyond tiered lines, shift/world event choices, and
  workshopping.
- Housing has no visual room or memorabilia display beyond the journal's shelf
  tab.
- Not built at all:
  - Phase 4: touring, the tour planner, deposits and settlements.
  - Phase 5: arenas, production, opener hiring, panel-guest gameplay. The stage
    art supports a player panel seat, but no flow uses it.
  - Phase 6: Steam integration, achievements on Steam, cloud saves, release
    pipeline.
- Controller: menus use focusable buttons and default `ui_*` actions. Controller
  bindings can't be remapped, only keyboard ones.
- Text scaling applies when UI is rebuilt; already-open panels update on reopen.

## Assumptions made
- Day 0 is a Wednesday, so the first Monday comes 5 days in and players have time
  to prepare.
- Rent is due a week after you rent the bunk, which removes the forced night-one
  failure.
- The Secret Show venue is the Mothership by default; it's configurable in
  `data/venues/venues.json`.
- "Redban" and "The Host" are display placeholders in the partner package,
  pending review.
- JSON (not .tres) is used for content and balancing so it can be diffed and
  edited without the editor.
