# Game Design: As Implemented

This file covers only what exists in code. Planned work is listed in
IMPLEMENTATION_STATUS.md. Numbers come from `data/balancing/balancing.json`.

_See the sections at the end for character creation, street life, promises,
workshops, venue stages, the day summary and Kill Tony regular status._

## Opening sequence
1. A short intro dialog at the bus stop (day 0 is a Wednesday afternoon).
2. **Pick up your bag** at the curb (interact).
3. **Open the journal** (J). The first page states the dream and explains joke pieces.
4. Walk east. Once you pass the coffee shop, the camera pans to the **Comedy Mothership**
   (skipped with reduced motion), followed by a short dialog.
5. **Lodging:** talk to Mari at the Bunkhouse Hostel. The bunk costs $140/week and
   the first payment is due in 7 days, so you can't fail on night one.
6. **Work:** the notice board lists leads. Get hired at the diner (server), at The
   Cellar (doorman), or on the delivery app.
7. **Open mic:** talk to Dusty at The Rusty Spur ($5 bar minimum, 3-minute slots).
8. Build a set in the journal and perform.
The HUD's goal line tracks these steps. They can be done in any order and never block play.

## Calendar
- 7-day weeks, 4 blocks a day (Morning, Afternoon, Evening, Late Night).
- Walking and fast travel never cost time. Every timed activity shows its block
  cost before you confirm.
- Anything that overlaps a booked commitment raises a warning dialog first. A
  booking is only ever marked "missed" after you confirm, or when its block passes
  without you. Nothing is cancelled silently.
- Waiting past Late Night without sleeping is an all-nighter (energy −15, stress +6).
- Fixed anchors: Kill Tony on Monday evening, and The Secret Show on Thursday evening
  (invitation only).

## Economy
- Start: $180, energy 80, stress 20, confidence 35.
- Daily essentials cost $8. If you can't pay, you skip meals (−5 energy, +5 stress).
  This never creates debt.
- Rent is charged weekly. Any shortfall becomes debt plus one $15 late fee. After two
  missed weeks you move to Deshawn's couch (free, less restful), so debt stops
  growing. Pay it off at the hostel to get your bunk back.
- Jobs:
  - **Server** (Big Sky Diner): lunch or dinner, 2 blocks, $30 base + $15–50 tips.
  - **Doorman** (The Cellar): evening to close, $55 flat + small tips. Watching sets
    improves delivery and builds staff trust.
  - **Delivery** (bus stop): any block, up to 3 runs a day, $12 + $6–22 tips − $4 bike costs.
  - **Day labor** (notice board): an always-available emergency job, $55, heavy energy cost.
- Each shift draws 1–2 authored events with choices. Choices affect pay, tips,
  reliability, energy, stress, relationships and material.
- Coffee and energy drinks are limited to one purchase per block. Daily shift caps
  keep any single action from producing unlimited money.
- Leasing a basic room at Oak Street Apartments ($300 deposit, $215/week, better
  rest) unlocks after your first set.

## Joke journal
- Pieces: premise, setup, punchline, plus optional tag, act-out and callback.
  Each piece has quality, originality, difficulty, seconds, styles and topic
  tags (via its family).
- **Compatibility is authored**, not AI. A link is *coherent* if the receiving
  piece's `requires` matches what the earlier pieces `provide`. It is *weak* if
  the families only share a topic, and *incompatible* otherwise. A missing required
  piece makes the joke *incomplete*. A callback that comes before the joke it
  calls back to makes the set *missing context*.
- Quality = 10 × (0.2·premise + 0.3·setup + 0.5·punchline) × coherence multiplier
  + 2 per polish level (max 5).
- Works in progress are capped by your largest book (journal 3, small 5, medium 8,
  large 12). The finished archive has no limit. The original journal is never removed.
- Rewriting creates a new revision. Old revisions and performance history are
  never changed.
- Titles and notes are editable. The UI says plainly that results come from
  attributes, not from the text.

## Getting material
- Street observations (the "!" markers), interiors (hostel bunks, coffee laptops),
  first shifts at each job, shift events, world events, workshopping with Deshawn,
  writing sessions, and bombing (unlocks the "Bombing" premise).
- **Writing session** (1 block, at home or the coffee shop, which gives +10%):
  - *Develop* finds the next undiscovered piece of a family you hold a premise for.
    Chance = 40% + writing/150 + confidence/400 (+10% coffee), clamped to 10–90%.
    Two failures in a row guarantee the next one. Strong punchlines need a minimum
    writing skill, and the UI says which level.
  - *Polish* adds +2 quality and creates a new revision.
  - *Rehearse* gives +15 familiarity to every joke in a setlist.
- Money can't buy material.

## Set building
Two setlists persist: the open-mic set and the **prepared minute** for Kill Tony.
The editor shows the running order (opener and closer), length with and without
extras compared to the slot, average familiarity, times this room has already
heard each joke, and callback-order warnings.

## Performance
Each joke's score is the sum of named factors, recorded for feedback:

| Factor | Formula |
|---|---|
| material | quality × 0.55 |
| delivery | (delivery·0.35 + familiarity·0.30 + confidence·0.20 + presence·0.15) × 0.45 |
| room | audience warmth × 0.35 |
| fit | topic and style preferences, style match, originality × audience weight (±12) |
| momentum | carries between jokes (±20) |
| heard-before | exposure at this venue (regulars punish repeats) |
| difficulty | −(difficulty×10 − (delivery + familiarity/2)) × 0.15 |
| condition | penalties when energy < 40 or stress > 50 |
| extras | act-out (needs energy ≥ 50), callback (needs the earlier joke to have landed) |
| luck | seeded ±12 |

Fame and reputation are **not** inputs. After each joke you choose what to do.
The options depend on how the joke went:
- **Landed:** pause for the laugh (risky if it's smaller than it feels), keep
  rolling, add the tag.
- **Died:** acknowledge it (stage presence; deadpan and self-deprecating styles
  help), push through, try crowd work (crowd-work skill × audience affinity), or
  jump to your most reliable bit.
- **Near time:** skip to your closer, or say goodnight.

Choices are never timed. Overrunning past the grace period costs 8 points per
joke, and at Kill Tony the band plays you off 10 seconds past the minute.
Set score = weighted average (opener ×1.2, closer ×1.5) + bonuses (±15) − overrun.
Feedback names the best and weakest jokes, gives up to 4 suggestions derived from
the largest factor shortfall, and shows the full factor breakdown, earnings,
skill/reputation/confidence changes and relationship notes.

## Kill Tony
- **Signup:** Monday morning or afternoon at the Mothership. A dialog shows the
  attendance commitment, the selection rules, golden-ticket status, your prepared
  minute's length and any conflicts. Signing up reserves Monday evening.
- **Draw:** 35–60 entrants, 8 pulled without replacement (Fisher–Yates on the bucket
  RNG stream). Fame isn't an input. The draw is stored and autosaved **before** the
  reveal, so reloading never rerolls it.
- **Not pulled:** you watch the show (skill gains), with a 25% chance of a networking
  moment. There's no guaranteed consolation prize, and your career continues.
- **Pulled:** walk to the mic, confirm the prepared minute (or swap to your open-mic
  set), perform, see the panel's reaction, then answer 3 interview prompts. Prompts
  are filtered by background, job, hooks, past appearances and how the set went.
  A tone's value depends on the prompt, the set result (self-deprecation works
  after bombing but reads as false modesty after killing) and repetition
  (−5 per repeat).
- **Outcomes** are independent and each is claimed exactly once:
  - visibility (fame and reputation)
  - joke book (small/medium/large by set score; needs a passable interview)
  - Secret Show invitation (needs a good set *and* interview chemistry)
  - golden ticket (rare; guarantees a future bucket spot)
  - opening invitation
  - regular-track progress (counter only)
- **Golden ticket rule:** if you aren't pulled fairly, the ticket guarantees a spot
  and is used up. If you are pulled fairly, you keep it.

## The Secret Show
The invitation is a dated Thursday-evening offer: 5-minute set, $100, expires the
day before, from Redban (partner placeholder). Accepting it checks for conflicts.
Performing it gives reputation, fame, a relationship with Redban, and unlocks a
possible rebooking offer.

## Relationships and NPCs
There are 8 fictional recurring NPCs, each with a weekly schedule. Relationships
track familiarity, respect, chemistry, trust and reliability, and change only
through actions:
- talking once a day
- shift choices
- covering shifts
- workshopping
- performing well for a venue's host
- running long (costs trust)
- missing bookings (costs reliability, trust and respect)

## Career
There are 10 tiers. Tiers 1–4 (open-mic beginner, local regular, paid club
performer, opening act) can be reached through open mics, showcases and opening
offers without ever being pulled from the bucket. Tiers 5–9 need touring and arenas,
which aren't built yet, and the game says so. Opportunities are 10 authored
templates generated each morning when their conditions are met. They have expiry
dates and cooldowns.

The district changes with progress: poster text, the Mothership marquee by
weekday, the Monday bucket line, Thursday buzz, more pedestrians in the evening,
"Inside:" labels at doors, and staff recognition after a Kill Tony appearance.

## Home
Home is where you sleep, rest, write and rehearse; the phone covers finances and
week planning. The journal's shelf tab shows your books and souvenirs. There's no
visual room decoration yet.

## Character creation
Name, stage name, **gender (male or female)**, skin/hair/outfit colors, background
and starting style. Gender sets the player's pronouns in authored text: host
intros, the Kill Tony call-up and NPC lines use `{he}/{him}/{his}/{guy}` tokens,
filled in by `GameSim.fmt()`. It also changes the hair silhouette on every
character drawing. It has no effect on any gameplay number.

## Street life
The 8 recurring NPCs stand outside wherever their schedule puts them. When the
block changes they walk to their next spot (instantly with reduced motion), and
people with nowhere to be leave the map. You can talk to them on the street
with E, which works the same as talking indoors (familiarity once a day).

## Promises
NPCs ask for favors through world events. Each favor is a dated commitment:
- watch Deshawn's new set
- cover Gus's dinner shift or Rhonda's door
- read Priya's script pages
- help Mari paint (−$20 rent)
- get notes from Lonnie

A promise never replaces an existing booking. If you're already booked, you
turn it down. To keep a promise, be at the right place at the right block and
pick "Keep your promise". Promises tied to a job open the normal shift, plus
bonus pay. Keeping one applies its reward exactly once. Breaking one costs
reliability, trust and respect with that person, but not professional
reputation.

## Workshops
Deshawn (coffee shop / Rusty Spur) can surface tags. Priya (coffee shop) can
surface punchlines. The chance is 50% + chemistry/200, and workshops ignore the
writing-skill gate.

## Venue stages
Each venue has its own stage art:
- **Rusty Spur:** brick, bar counter, beer sign, string bulbs.
- **Lantern Room:** velvet curtain, sconces, candlelit tables.
- **The Cellar:** low ceiling, pipes, pulsing neon, standing crowd.
- **Secret Show:** industrial beams, string lights, a "NO PHONES" sign.

Each venue's host introduces you before your set.

## Day summary
Sleeping shows a recap of the day: money earned and spent, cash, sets and their
results, new material found, days until rent, and upcoming commitments.

## Kill Tony regular status
1. Every set of 80+ adds one regular-track point.
2. At 3 points, Redban calls with an offer.
3. If you accept, every other Monday has a "Kill Tony (regular spot)" booking.
   There's no bucket: you're on the lineup.
4. At least half the jokes in each regular set must be new to Kill Tony.
   Otherwise you get a strike (a fresh set resets strikes).
5. Three strikes and you're off the regular lineup. The bucket is still open to you.

## Touring (Phase 4)
Austin stays home. Touring is played through a planner and a leg-by-leg tour
scene, not explorable cities.

**Road offers (opener).** Phone → Offers, from tier 4 (Opening act). These are
2-city runs opening for Lonnie, a touring headliner, or a Kill Tony panelist:
- Flat pay per show ($150–250); travel is covered.
- They count toward tier 5 (Touring opener).

**Headline tours.** Phone → Tours → Plan, from tier 4. Theaters unlock at tier 6.
You choose:
- A leave date.
- Up to 5 cities: Texas drive markets, US flight markets, Toronto (fame 20),
  London (fame 35).
- Club or theater in each city.
- Ticket price, marketing, transport (van for Texas only, or fly), lodging
  (motel or hotel), and an opener: Deshawn, Tasha or Benji, each with fee,
  reliability, style and potential.

**Money.**
- Deposits and marketing are paid when you book.
- Travel, lodging and opener fees are reserved, then charged when you depart.
- Forecast revenue is shown, labelled as not spendable, and never added to cash.
- Each night settles: payout = gross × (1 − venue cut) − (rent − deposit).
- The trip summary shows tickets, settlements, all costs and profit/loss.
  Selling out and making a profit are reported separately.

**Demand.** Market base × (fame, reputation and local fans) × venue draw
(theaters ×3) × price elasticity × marketing (up to +40%) × recency (−40% if
you played the city in the last 21 days). Sales are rolled once and stored.

**Time.**
- The whole trip is one calendar commitment, from the departure morning to the
  return afternoon, and it conflict-checks against Austin bookings.
- Each city takes the morning and afternoon to travel, with the show in the
  evening; then a night at the motel or hotel (rest depends on lodging).
- You must leave from the bus stop on the departure morning. Missing it cancels
  the tour.
- Austin world events pause while you're away.

**Setbacks and rules.**
- A 12% chance per leg of a travel setback (flat tire or delayed flight) that
  costs money and stress.
- Cancelling before departure forfeits deposits and marketing, costs
  reputation, and (for road runs) trust with whoever booked you.

**Your act.**
- Road sets use your best material: the game auto-fills from your strongest
  jokes, and you can edit the set.
- Headline sets need 5 jokes and opening sets need 3; each missing joke is a
  penalty.
- An opener's reliability can mean a no-show; a good opener warms the room.
- Bringing a friend along builds the relationship and is tracked as
  "talent helped".

**Career.**
- Tier 5 (Touring opener): 3 road shows and reputation 45.
- Tier 6 (Club headliner): 4 headline shows and reputation 55.
- Tier 7 (Theater headliner): 3 theater shows and fame 40.
- Tiers 8–9 (arenas) wait on Phase 5.
