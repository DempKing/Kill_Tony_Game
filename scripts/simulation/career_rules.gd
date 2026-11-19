class_name CareerRules
extends RefCounted
## Career tiers from balancing.career_tiers. Bucket selection is not required
## for any tier. Tiers requiring unbuilt features (touring, arenas) are
## unreachable in this build and reported as such.


const STAT_KEYS: Array = ["sets", "paid_sets", "opener_sets", "road_sets", "headline_sets", "theater_sets"]
const STAT_LABELS: Dictionary = {"sets": "sets", "paid_sets": "paid sets", "opener_sets": "opening sets", "road_sets": "road shows as an opener", "headline_sets": "headline shows", "theater_sets": "theater shows"}


static func meets_tier(s: GameState, t: Dictionary) -> bool:
	if t.has("requires_feature"):
		return false
	for k in STAT_KEYS:
		if t.has(k) and int(s.stats.get(k, 0)) < int(t[k]):
			return false
	if t.has("rep") and s.reputation < float(t["rep"]):
		return false
	if t.has("fame") and s.fame < float(t["fame"]):
		return false
	return true


static func evaluate(s: GameState, db: ContentDB) -> int:
	var best := 0
	for t in db.bal("career_tiers", []):
		if not meets_tier(s, t):
			break
		best = int(t["tier"])
	return best


static func update(s: GameState, db: ContentDB) -> String:
	var t := evaluate(s, db)
	if t > s.career_tier:
		s.career_tier = t
		var msg := "Career milestone: %s." % tier_name(db, t)
		s.add_message(msg)
		return msg
	return ""


static func tier_name(db: ContentDB, tier: int) -> String:
	for t in db.bal("career_tiers", []):
		if int(t["tier"]) == tier:
			return str(t["name"])
	return "?"


static func next_requirements(s: GameState, db: ContentDB) -> String:
	for t in db.bal("career_tiers", []):
		if int(t["tier"]) == s.career_tier + 1:
			if t.has("requires_feature"):
				return "Next tier needs %s, which isn't in this build yet." % t["requires_feature"]
			var parts: Array = []
			for k in STAT_KEYS:
				if t.has(k):
					parts.append("%d/%d %s" % [int(s.stats.get(k, 0)), int(t[k]), STAT_LABELS[k]])
			if t.has("rep"):
				parts.append("reputation %.0f/%d" % [s.reputation, int(t["rep"])])
			if t.has("fame"):
				parts.append("fame %.0f/%d" % [s.fame, int(t["fame"])])
			return "Next: %s (%s)" % [t["name"], ", ".join(PackedStringArray(parts))]
	return ""
