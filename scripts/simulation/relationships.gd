class_name Relationships
extends RefCounted
## Relationship values (0-100): familiarity, respect, chemistry, trust,
## reliability. They change through actions (keeping promises, covering
## shifts, performing well, missing bookings), never through gift spam.

const FIELDS: Array = ["familiarity", "respect", "chemistry", "trust", "reliability"]


static func change(s: GameState, npc_id: String, deltas: Dictionary) -> void:
	if npc_id == "":
		return
	var r := s.rel(npc_id)
	for k in deltas:
		if FIELDS.has(k):
			r[k] = clampi(int(r.get(k, 0)) + int(deltas[k]), 0, 100)


static func tier(s: GameState, npc_id: String) -> String:
	var r := s.rel(npc_id)
	var f: int = int(r["familiarity"])
	var warm: int = int(r["chemistry"]) + int(r["trust"])
	if f >= 15 and warm >= 20:
		return "close"
	if f >= 3:
		return "known"
	return "stranger"


static func meets(s: GameState, req: Dictionary) -> bool:
	## req: {npc_id: {field: min}}
	for npc in req:
		var r := s.rel(str(npc))
		for field in req[npc]:
			if int(r.get(field, 0)) < int(req[npc][field]):
				return false
	return true
