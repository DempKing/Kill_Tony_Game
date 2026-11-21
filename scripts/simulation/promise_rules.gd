class_name PromiseRules
extends RefCounted
## Promises: small dated favors for NPCs (watch a set, cover a shift, read
## pages). Keeping one applies its reward; missing one goes through the normal
## missed-commitment path and costs the relationship.


## Creates a promise commitment from an event effect. Never overrides another
## booking: if the time is taken, the player has to decline.
static func create(s: GameState, db: ContentDB, spec: Dictionary) -> String:
	var day: int = s.day + int(spec.get("days_ahead", 0))
	var block: int = int(spec.get("block", 2))
	if CalendarRules.slot(day, block) < CalendarRules.slot(s.day, s.block):
		return "It's too late for that today."
	var npc: String = str(spec.get("npc", ""))
	var c := {
		"kind": "promise",
		"title": str(spec.get("title", "Promise")),
		"day": day,
		"block": block,
		"length": int(spec.get("length", 1)),
		"location_id": str(spec.get("location", "")),
		"npc": npc,
		"slot_seconds": 0,
		"pay": 0,
		"fee": 0,
		"reward": spec.get("reward", {}),
		"job_shift": spec.get("job_shift", {}),
	}
	var res := Scheduler.add(s, db, c, false)
	if not bool(res["ok"]):
		Relationships.change(s, npc, {"familiarity": 1})
		return "You check your calendar: you're already booked then. You tell %s you can't make it." % db.character_name(npc)
	return "Promised: %s (%s)." % [c["title"], CalendarRules.describe_slot(day, block)]


## Applies the reward for keeping a promise exactly once.
static func keep(s: GameState, db: ContentDB, commitment_id: String) -> Array:
	var c := Scheduler.find(s, commitment_id)
	if c.is_empty() or str(c.get("status", "")) != "booked":
		return []
	if not RewardRules.claim(s, "promise_" + commitment_id):
		return []
	Scheduler.mark_done(s, commitment_id)
	var fx: Dictionary = (c.get("reward", {}) as Dictionary).duplicate(true)
	var pay: int = int(fx.get("pay", 0))
	fx.erase("pay")
	var notes: Array = ["You kept your word to %s." % db.character_name(str(c.get("npc", "")))]
	if pay > 0:
		StatsRules.add_cash(s, pay, "Thanks from " + db.character_name(str(c.get("npc", ""))))
		notes.append("+$%d for the favor." % pay)
	notes.append_array(StatsRules.apply_effects(s, db, fx, "", "promise"))
	s.stats["promises_kept"] = int(s.stats.get("promises_kept", 0)) + 1
	return notes
