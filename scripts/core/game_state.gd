class_name GameState
extends RefCounted
## Complete persistent game state. Everything the simulation needs to resume
## lives here and round-trips through to_dict()/from_dict(). Versioned; see
## scripts/persistence/save_migrations.gd.

const SAVE_VERSION: int = 2
const RNG_STREAMS: Array = ["bucket", "performance", "world"]

var version: int = SAVE_VERSION
var master_seed: int = 0
var player: Dictionary = {}
var day: int = 0
var block: int = 1
var cash: int = 0
var energy: int = 80
var stress: int = 20
var confidence: int = 35
var skills: Dictionary = {}
var fame: float = 0.0
var reputation: float = 0.0
var local_demand: float = 0.0
var career_tier: int = 0
var location_id: String = "transit_stop"
var player_pos: Vector2 = Vector2.ZERO
var housing_id: String = ""
var rent: Dictionary = {"next_due_day": 7, "debt": 0, "missed": 0}
var jobs: Dictionary = {}          # job_id -> {reliability, shifts, last_shift_day, shifts_today}
var components: Array = []         # unlocked component ids
var jokes: Dictionary = {}         # joke_id -> joke record (see JokeRules)
var next_joke_num: int = 1
var books: Array = ["starter_journal"]
var setlists: Dictionary = {}      # setlist_id -> {name, jokes:[joke ids]}
var commitments: Array = []
var opportunities: Array = []
var relationships: Dictionary = {} # npc_id -> {familiarity, respect, chemistry, trust, reliability}
var flags: Dictionary = {}
var claimed: Dictionary = {}       # reward / payment claim ids -> day claimed
var ledger: Array = []
var kt: Dictionary = {"draws": {}, "appearances": 0, "golden_tickets": 0, "regular_progress": 0, "history": []}
var performances: Array = []
var pity: Dictionary = {}
var discovered_locations: Array = []
var messages: Array = []
var stats: Dictionary = {"sets": 0, "paid_sets": 0, "opener_sets": 0, "shifts": 0, "bombs": 0}
var pending_events: Array = []
var tours: Array = []             # tour records (see TourRules)
var fans: Dictionary = {}         # market_id -> local fan count     # world event ids queued for display
var next_uid: int = 1
var rngs: Dictionary = {}          # stream -> RandomNumberGenerator


func rng(stream: String) -> RandomNumberGenerator:
	if not rngs.has(stream):
		var r := RandomNumberGenerator.new()
		r.seed = hash(str(master_seed) + ":" + stream)
		rngs[stream] = r
	return rngs[stream]


func uid(prefix: String) -> String:
	var id := "%s_%d" % [prefix, next_uid]
	next_uid += 1
	return id


func add_message(text: String) -> void:
	messages.append({"day": day, "block": block, "text": text})
	while messages.size() > 60:
		messages.pop_front()


func rel(npc_id: String) -> Dictionary:
	if not relationships.has(npc_id):
		relationships[npc_id] = {"familiarity": 0, "respect": 0, "chemistry": 0, "trust": 0, "reliability": 50}
	return relationships[npc_id]


func has_component(id: String) -> bool:
	return components.has(id)


func flag(key: String, fallback: Variant = false) -> Variant:
	return flags.get(key, fallback)


func book_capacity(db: ContentDB) -> int:
	var cap := 0
	for b in books:
		cap = maxi(cap, db.book_capacity(str(b)))
	return cap


func to_dict() -> Dictionary:
	var rng_out: Dictionary = {}
	for k in rngs:
		var r: RandomNumberGenerator = rngs[k]
		# 64-bit values are stored as strings: JSON numbers are doubles.
		rng_out[k] = {"seed": str(r.seed), "state": str(r.state)}
	return {
		"version": version,
		"master_seed": str(master_seed),
		"player": player,
		"day": day,
		"block": block,
		"cash": cash,
		"energy": energy,
		"stress": stress,
		"confidence": confidence,
		"skills": skills,
		"fame": fame,
		"reputation": reputation,
		"local_demand": local_demand,
		"career_tier": career_tier,
		"location_id": location_id,
		"player_pos": [player_pos.x, player_pos.y],
		"housing_id": housing_id,
		"rent": rent,
		"jobs": jobs,
		"components": components,
		"jokes": jokes,
		"next_joke_num": next_joke_num,
		"books": books,
		"setlists": setlists,
		"commitments": commitments,
		"opportunities": opportunities,
		"relationships": relationships,
		"flags": flags,
		"claimed": claimed,
		"ledger": ledger,
		"kt": kt,
		"performances": performances,
		"pity": pity,
		"discovered_locations": discovered_locations,
		"messages": messages,
		"stats": stats,
		"pending_events": pending_events,
		"tours": tours,
		"fans": fans,
		"next_uid": next_uid,
		"rngs": rng_out,
	}


static func from_dict(d: Dictionary) -> GameState:
	var raw: Dictionary = normalize(d)
	var s := GameState.new()
	s.version = int(raw.get("version", SAVE_VERSION))
	s.master_seed = str(raw.get("master_seed", "0")).to_int()
	s.player = raw.get("player", {})
	s.day = int(raw.get("day", 0))
	s.block = int(raw.get("block", 0))
	s.cash = int(raw.get("cash", 0))
	s.energy = int(raw.get("energy", 80))
	s.stress = int(raw.get("stress", 20))
	s.confidence = int(raw.get("confidence", 35))
	s.skills = raw.get("skills", {})
	for k in s.skills:
		s.skills[k] = float(s.skills[k])
	s.fame = float(raw.get("fame", 0.0))
	s.reputation = float(raw.get("reputation", 0.0))
	s.local_demand = float(raw.get("local_demand", 0.0))
	s.career_tier = int(raw.get("career_tier", 0))
	s.location_id = str(raw.get("location_id", "transit_stop"))
	var pos: Array = raw.get("player_pos", [0, 0])
	s.player_pos = Vector2(float(pos[0]), float(pos[1])) if pos.size() >= 2 else Vector2.ZERO
	s.housing_id = str(raw.get("housing_id", ""))
	s.rent = raw.get("rent", s.rent)
	s.jobs = raw.get("jobs", {})
	s.components = raw.get("components", [])
	s.jokes = raw.get("jokes", {})
	s.next_joke_num = int(raw.get("next_joke_num", 1))
	s.books = raw.get("books", ["starter_journal"])
	s.setlists = raw.get("setlists", {})
	s.commitments = raw.get("commitments", [])
	s.opportunities = raw.get("opportunities", [])
	s.relationships = raw.get("relationships", {})
	s.flags = raw.get("flags", {})
	s.claimed = raw.get("claimed", {})
	s.ledger = raw.get("ledger", [])
	s.kt = raw.get("kt", s.kt)
	s.performances = raw.get("performances", [])
	s.pity = raw.get("pity", {})
	s.discovered_locations = raw.get("discovered_locations", [])
	s.messages = raw.get("messages", [])
	s.stats = raw.get("stats", s.stats)
	s.pending_events = raw.get("pending_events", [])
	s.tours = raw.get("tours", [])
	s.fans = raw.get("fans", {})
	s.next_uid = int(raw.get("next_uid", 1))
	var rng_in: Dictionary = raw.get("rngs", {})
	for k in rng_in:
		var r := RandomNumberGenerator.new()
		r.seed = str(rng_in[k].get("seed", "0")).to_int()
		r.state = str(rng_in[k].get("state", "0")).to_int()
		s.rngs[k] = r
	return s


## Converts whole-number floats produced by JSON parsing back to ints, so ids
## built from numbers ("day_7") and integer comparisons stay stable after load.
## Skills are re-cast to float in from_dict.
static func normalize(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			var f: float = v
			if is_finite(f) and f == floorf(f) and absf(f) < 9.0e15:
				return int(f)
			return f
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for k in v:
				out[k] = normalize(v[k])
			return out
		TYPE_ARRAY:
			var arr: Array = []
			for item in v:
				arr.append(normalize(item))
			return arr
	return v
