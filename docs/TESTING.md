# Testing

> **These tests have never been run.** The build environment had no Godot.
> Run them on a machine with Godot 4.3 before trusting any result below.

## Automated
```
godot --headless --path . --import                 # builds the class cache
godot --headless --path . -s res://tests/run_tests.gd
```

| Suite | Covers |
|---|---|
| `test_calendar_schedule` | calendar advancement, all-nighters, sleep, scheduling conflicts, missed bookings, activity conflict detection |
| `test_economy` | rent and income, shift income and daily caps, shift idempotency, recovery from low cash (couch fallback, debt payoff, emergency work), a four-week survival simulation |
| `test_material` | compatibility (coherent/weak/incompatible/missing), duration and overrun warnings, callback ordering, WIP capacity and books, revisions preserving history, writing pity, skill-gated punchlines |
| `test_performance` | determinism, decisions changing outcomes, preparation improving averages, fame not affecting scores, weak-set feedback, overrun and play-off, bombing teaching, apply-once |
| `test_kill_tony` | draw without replacement, fair odds, fame not affecting the draw, signup rules, reload not rerolling, forced draws and golden tickets, reward idempotency, non-ladder outcomes, contextual interview tones, Secret Show conflict check |
| `test_save_load` | lossless round trip, RNG stream persistence, stream independence, migration, malformed-JSON detection, int normalization |
| `test_progression` | career without a bucket pull, opportunity generation and expiry, tutorial completion through normal actions, every door reachable on foot, NPC schedules |
| `test_life` | gender and text tokens, v1→v2 migration, keeping and breaking promises, promises never replacing bookings, shift promises, Priya workshops, regular-status flow and strikes, day summary |
| `test_content` | validation, content targets, every family can form a coherent joke, every family obtainable in play, partner separation |

`test_tour_cash_flow` is reported as SKIP because touring isn't implemented.

## Manual checklist (first playable)
1. New career → character creation → arrive at the bus stop.
2. Pick up the bag → J (journal intro) → walk east (landmark pan) → hostel
   (talk to Mari, rent the bunk).
3. Notice board → read leads → take a job. Work one shift and resolve its events.
4. Rusty Spur in the evening → talk to Dusty → sign up → set builder → perform →
   make choices → read the feedback.
5. Go home → sleep → Menu → Save to slot 1 → title → Load slot 1 → continue the next day.
6. Monday: sign up at the Mothership. In the evening, attend. Use the dev panel
   (F12) to force a SELECTED result. Check the mic, panel and band are all visible,
   do the minute, interview and rewards. Reload mid-night to confirm nothing rerolls.
7. Accept a Secret Show invite (phone → Offers) and perform it on Thursday.
8. Settings: text size, reduced motion, subtitles, key remap, window modes.
9. Controller: every menu is reachable with the D-pad and A/B.

## Developer panel
F12, or Menu → Developer panel. It only exists when `OS.is_debug_build()` is true
or the export has the `dev` feature tag. It can change cash and energy, jump in
time, unlock material, raise skills, reputation and tier, force the next bucket
result, raise relationships, trigger opportunities, teleport, and show seeds and
RNG states, the last performance's factor breakdown and content errors.
