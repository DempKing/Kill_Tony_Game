# Implementation Status

_Last updated: second pass. That pass replaced pronouns with gender, added 59
joke pieces, and added promises, street NPCs, venue stages, the day summary and
regular status._

## Verification status
- **Godot 4.3:** the project imports with no script errors. Two compile errors
  were found and fixed on the first real run: a type-inference failure in
  `save_manager.gd`, and `var draw` clashing with Node2D's `draw` signal.
- **Tests:** 838 checks, 0 failures, 1 skipped (touring). The first run also
  found and fixed a real bug: JSON numbers load as floats, which broke NPC
  schedules, opening hours and Kill Tony signup. Content is now normalized
  to ints on load.
- **Automated playtest with screenshots:** title → character creation →
  arrival → journal → landmark → hostel → evening street → set builder → open
  mic (set, choices, results) → Monday → Kill Tony (bucket, mic, set, panel,
  interview, rewards). It runs with no errors. The UI fixes this led to:
  - the HUD now fits the screen
  - modals no longer cover the HUD
  - building signs are sized to fit
  - NPC name tags no longer overlap
  - the choice panel takes less of the stage
- **Windows export:** builds a single-file x86_64 .exe with the pack embedded.
  It hasn't been launched on Windows yet.
- **Not verified:** a human playtest with keyboard or controller, audio on real
  hardware, and Steam.

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

### 3D conversion (seventh pass)
The street, the club stages, tour stages and the Kill Tony stage now render
in 3D. Menus, the HUD, the journal, the phone, interiors, the title screen and
the character creator are still 2D UI. All art is still placeholder; nothing is
partner-approved.
- **District:** textured 3D buildings with lit windows, awnings and signs,
  the original saucer-marquee Mothership with chasing bulbs, and the street.
  Props include Poly Haven lamps, hydrants, trash cans, planters, AC units and
  utility boxes, plus built benches, parked cars and the taco truck.
- **People and time:** walking 3D people (player, NPCs with name tags,
  pedestrians, the Monday bucket line) and time-of-day sky and sun. Lamp
  lights come on at night.
- **Camera:** a follow camera. South-side buildings switch to a cutaway when
  they would hide the player. The landmark tutorial swings out to a wide shot.
- **Stages:** seven room styles with Poly Haven props, a spotlight with a
  visible cone, the time light, and an instanced audience that bounces on
  laughs.
- **Kill Tony stage:** Tony is in the host seat nearest the mic, up to three
  guests are along the desk, and Redban is at his own sound station with a
  soundboard, drop pads and a laptop. It also has the band riser (drums,
  keys, bass), the bucket, and camera moves for arrival, set, panel,
  interview, reward and band.
- **Verified:**
  - 944 test checks pass.
  - The art-shot run and the full scripted playtest both run with no script
    errors. They were checked by screenshots under Xvfb and llvmpipe.
- **Not verified:**
  - frame rate on real GPUs and in browsers
  - how the web build performs with the 3D scenes

### Art pass (fifth pass)
All art is still original procedural placeholder art; nothing is
partner-approved.
- **Characters:** a shared renderer (`CharacterArt`) draws everyone. It has
  shading, faces with five expressions, five hair styles (chosen in the
  creator), walk cycles and seated poses.
- **District:**
  - time-of-day gradient sky, stars, moon/sun, and a lit skyline
  - facades with cornices, rooftop units, framed lit windows, awnings and
    neon-glow signs
  - the Mothership as an original saucer marquee with chasing bulbs and
    searchlights
  - roof-plus-storefront south buildings; sidewalks, curbs, crosswalks,
    manholes
  - trees, parked cars, benches, a bus shelter and a notice board
  - walking pedestrians, and a Monday bucket line with stanchions
  - an additive night-glow layer for lamps, signs, doors and headlights
- **Stages:** gradient backdrops, a soft spotlight cone and floor pool, a
  stage lip with footlights, a stool and cable, and rim-lit audience
  silhouettes. The comedian holds the mic and reacts to the room.
- **Kill Tony stage:** seated panel with reactions, a drum kit, keys and
  guitar, desk mics, a lit desk, and the bucket on a stand.
- **Other screens:** interiors with perspective floors, props, lighting and
  full NPC figures; an animated title screen; the creator preview uses the
  new renderer.

### Phase 5: arenas and legacy (fourth pass)
- Arena venues, including an Austin home arena, with production levels.
- Separate sellout and profitability stats.
- Opener hiring cards: fee, reliability, style, audience fit, relationship,
  potential, mentorship progress.
- Mentorship breakouts with payoffs.
- Kill Tony panel-guest nights: react, contribute, scout.
- Tiers 8–9.
- Tests in `test_legacy`.

### Phase 4: touring (third pass)
- 10 markets with clubs and theaters.
- Road offers as an opener.
- A headline tour planner: dates, route, price, marketing, transport, lodging,
  opener, a live forecast and a money breakdown.
- Deposits, reserved costs, settlements and a profit/loss summary.
- A tour scene: travel, setbacks, box office, set, show, settlement, lodging,
  return.
- Recency, local fans, cancellations, missed departures, career tiers 5–7.
- Tests in `test_touring`.

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
