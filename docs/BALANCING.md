# Balancing

Every value lives in `data/balancing/balancing.json` (plus per-item numbers in
the jobs, venues, character and opportunities data). All of them are prototype
tuning values.

## Economy (per week, starting player)
| Item | Value |
|---|---|
| Starting cash | $180 |
| Bunk rent | $140/week, first due day 7 |
| Essentials | $8/day ($56/week) |
| Open mic | $5 per set |
| Server lunch/dinner | $30 + $15–50 tips (× reliability factor 0.85 + rel/200; × 1.1 for Restaurant Lifer) |
| Doorman | $55 + $0–10 |
| Delivery | $12 + $6–22 − $4, max 3/day |
| Day labor | $55, energy −34 |

A player working 5–6 server shifts a week clears about $330–$390 against about
$206 in costs. Tests simulate a "reasonable player" over four weeks.

## Failure handling
- Rent shortfall: debt plus a single $15 late fee per missed week.
- After 2 missed weeks: Deshawn's couch (weekly $0), so debt stops growing.
- No cash for food: skipped meals (energy and stress), never debt.

## Performance scoring
See GAME_DESIGN.md for the factor table.

Response tiers:

| Score | Response |
|---|---|
| < 25 | silence |
| 25 | chuckle |
| 45 | laugh |
| 65 | big laugh |
| 80 | applause |

Set tiers:

| Score | Tier |
|---|---|
| < 30 | bombed |
| 30 | rough |
| 45 | okay |
| 60 | solid |
| 72 | killed |
| 85 | destroyed |

Typical scores:
- A fresh starter joke at the open mic: about 25–40.
- A polished strong joke with high familiarity and delivery 25: about 60–75.

## Bucket
- 35–60 entrants, 8 pulls, so a 13–23% chance per Monday.
- Fame is not an input.
- A golden ticket guarantees a spot (1 use).

## Kill Tony rewards (each independent)
| Outcome | Requirement |
|---|---|
| Small book | set ≥ 58, interview ≥ 35 |
| Medium book | set ≥ 70, interview ≥ 35 |
| Large book | set ≥ 82, interview ≥ 35 |
| Secret Show | set ≥ 55 and interview ≥ 55 |
| Golden ticket | set ≥ 86, interview ≥ 65, 50% roll |
| Opening offer | set ≥ 70 |
| Regular progress | set ≥ 80 |

Interview score = 50 + 1.6 × Σ(response base + prompt tone modifier + set-result
tone modifier − 5 × repeats).

## Writing
- Discovery chance 40% + writing/150 + confidence/400 (+10% at the coffee shop),
  clamped to 10–90%.
- Pity guarantee after 2 failures.
- Strong punchlines need writing skill 10–16.

## Career tiers
| Tier | Requirement |
|---|---|
| 1 | 1 set |
| 2 | 8 sets, reputation 15 |
| 3 | 2 paid sets, reputation 25 |
| 4 | 1 opening set, reputation 40 |
| 5–9 | need touring/arenas (not built) |
