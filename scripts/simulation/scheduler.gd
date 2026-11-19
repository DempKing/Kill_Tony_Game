class_name Scheduler
extends RefCounted
## Commitments are dated bookings occupying one or more blocks.
## A commitment is never silently cancelled: conflicts are reported to the
## caller, who must confirm before anything is marked missed.
##
## Commitment fields: id, kind, title, day, block, length, location_id,
## venue_id, slot_seconds, pay, fee, npc, offer_id, status
## (booked | done | missed | cancelled).


static func start_slot(c: Dictionary) -> int:
	return CalendarRules.slot(int(c["day"]), int(c["block"]))


static func overlaps(c: Dictionary, from_slot: int, length: int) -> bool:
	var a0 := start_slot(c)
	var a1 := a0 + int(c.get("length", 1))
	var b1 := from_slot + length
	return a0 < b1 and from_slot < a1


static func booked(s: GameState) -> Array:
	var out: Array = []
	for c in s.commitments:
		if str(c.get("status", "")) == "booked":
			out.append(c)
	return out


static func conflicts(s: GameState, day: int, block: int, length: int, ignore_id: String = "") -> Array:
	var out: Array = []
	var from_slot := CalendarRules.slot(day, block)
	for c in booked(s):
		if str(c["id"]) == ignore_id:
			continue
		if overlaps(c, from_slot, length):
			out.append(c)
	return out


## Adds a commitment. Without force, refuses when conflicts exist and returns
## them so the UI can warn. With force, conflicting bookings are explicitly
## marked missed (with consequences) - the player confirmed this.
static func add(s: GameState, db: ContentDB, c: Dictionary, force: bool = false) -> Dictionary:
	var found := conflicts(s, int(c["day"]), int(c["block"]), int(c.get("length", 1)))
	if found.size() > 0 and not force:
		return {"ok": false, "conflicts": found}
	for other in found:
		mark_missed(s, db, other, "Replaced by " + str(c.get("title", "another booking")))
	if not c.has("id"):
		c["id"] = s.uid("c")
	c["status"] = "booked"
	if not c.has("length"):
		c["length"] = 1
	s.commitments.append(c)
	return {"ok": true, "conflicts": found, "commitment": c}


static func find(s: GameState, id: String) -> Dictionary:
	for c in s.commitments:
		if str(c["id"]) == id:
			return c
	return {}


## Booked commitments starting in the current block.
static func current(s: GameState) -> Array:
	var out: Array = []
	var now := CalendarRules.slot(s.day, s.block)
	for c in booked(s):
		if start_slot(c) == now:
			out.append(c)
	return out


static func upcoming(s: GameState, limit: int = 5) -> Array:
	var list := booked(s)
	list.sort_custom(func(a, b): return start_slot(a) < start_slot(b))
	return list.slice(0, limit)


static func mark_done(s: GameState, id: String) -> void:
	var c := find(s, id)
	if not c.is_empty():
		c["status"] = "done"


static func mark_missed(s: GameState, db: ContentDB, c: Dictionary, reason: String) -> void:
	if str(c.get("status", "")) != "booked":
		return
	c["status"] = "missed"
	c["missed_reason"] = reason
	var npc: String = str(c.get("npc", ""))
	if npc != "":
		var pen: Dictionary = db.bal("relationships.missed_booking", {})
		Relationships.change(s, npc, pen)
	# Missing a Kill Tony signup has no professional penalty: it's a lottery.
	if str(c.get("kind", "")) != "kill_tony":
		s.reputation = maxf(0.0, s.reputation + db.balf("relationships.missed_booking_rep", -2.0))
	s.add_message("Missed: %s (%s)." % [str(c.get("title", "booking")), reason])


## Called when time leaves `slot_left`. Any booked commitment that started at or
## before that slot and was not attended is now missed.
static func process_missed(s: GameState, db: ContentDB, slot_left: int) -> void:
	for c in booked(s):
		if start_slot(c) <= slot_left:
			mark_missed(s, db, c, "you weren't there")
