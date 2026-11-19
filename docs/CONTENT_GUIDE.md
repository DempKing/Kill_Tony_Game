# Content Guide

All content is JSON under `data/`, keyed by **stable string ids**. Never rename an
id that has shipped, because saves reference ids. The game validates references
at load time; problems appear on the title screen and in the developer panel.

## Jokes (`data/material/components.json`)
- A **family** is a coherent joke topic: `{"id": "fam_x", "title": ..., "topics": [...]}`.
  Topics drive audience fit and "weak" compatibility.
- A **component** is `{id, family, type, text, styles, quality, originality,
  difficulty, seconds, unlock, min_skill?, requires?, provides?, callback_ref?}`.
- `type` is one of premise, setup, punchline, tag, act_out or callback.
- If you omit `requires`/`provides`, they're derived:
  - premise provides `fam`
  - setup requires `fam` and provides `fam_setup`
  - punchline requires `fam_setup` and provides `fam_punch`
  - tag and act-out require `fam_punch`
  - `extra_requires` adds authored cross-family links
- A callback needs an explicit `requires` (the punchlines it can attach to) and a
  `callback_ref` (the family that must come earlier in the set).
- `unlock` values:
  - `start`
  - `start_bg:<background>` (actually granted via the background's `starting_components`)
  - `observe:<id>`, `job:<id>`, `event:<id>`: documentation only; the source grants it
  - `writing`: discoverable in writing sessions
  - `bomb`: granted after a set under 30
  - `npc:<id>`
- Every family needs at least one coherent premise → setup → punchline path. A
  test checks this.
- **Write original material.** Don't copy real comedians' jokes or transcripts.

## Venues and audiences (`data/venues/venues.json`)
- **Audiences:** `warmth`, `regulars` (repeat penalty), `crowdwork`, `topic_prefs`,
  `style_prefs`, `originality_weight`.
- **Venues:** `location`, `audience` (and optional `late_audience`), `slot_seconds`,
  `fee`, `pay`, `weekdays`, `blocks`, `host_npc`, `booking_only`, and `stage`
  colors and sign.

## Locations (`data/venues/locations.json`)
- Building `rect` and `door` are in world pixels. `open_blocks` sets opening
  hours. `observations` are street or interior notice spots. `posters` can be
  inspected. A test checks that every door can be reached on foot.
- Venue-specific actions are wired in `GameSim.actions_for()`.

## NPCs (`data/npcs/npcs.json`)
- `schedule`: the first matching `{days, blocks, location}` wins.
- `lines`: keyed by relationship tier (`stranger`, `known`, `close`).
- Fictional characters only. Real or partner figures go in `data/partner/`.

## Events
- **World events** (`data/events/world_events.json`): `trigger` is `day_start` or
  `enter:<location>`, plus `chance`, `once`, `conditions` and `choices[].effects`.
- **Shift events** (`data/jobs/jobs.json`): the same choice/effects format, plus
  `chance` with `fail_effects`.
- Effect keys: cash, pay, tips, energy, stress, confidence, rep, fame,
  reliability, skill{}, rel{npc:{field:delta}}, unlock[], flag{}.

## Interviews (`data/interviews/interviews.json`)
- Each prompt has `conditions` (background, job, hook, min/max_appearances,
  set_band), `tone_mods`, and `responses[] {text, tone, base}`.
- Tones: self_deprecating, honest, confident, absurd, roast. Keep each prompt
  balanced so that no single tone always wins.

## Opportunities (`data/opportunities/opportunities.json`)
- Fields: `venue`, `weekday`, `block`, `slot_seconds`, `pay`, `npc`, `chance`,
  `lead_days`, `expires_after_days`, `cooldown_days`, `conditions`, `on_complete`.
- `source: "kill_tony"` templates are only created by Kill Tony rewards.

## Partner package (`data/partner/`)
`partner_content.json` holds display names, show signage text and show lines.
`kill_tony_stage_layout.json` holds the stage blockout and camera framings.
Everything is flagged `approved: false` until the partner signs off.
