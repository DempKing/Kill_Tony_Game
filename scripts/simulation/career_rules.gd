class_name CareerRules
extends RefCounted
## Career tiers from balancing.career_tiers. Bucket selection is not required
## for any tier. Tiers requiring unbuilt features (touring, arenas) are
## unreachable in this build and reported as such.


static func evaluate(s: GameState, db: ContentDB) -> int:
	var tiers: Array = db.bal("career_tiers", [])
	var best := 0
	for t in tiers:
		if t.has("requires_feature"):
			break
		if t.has("sets") and int(s.stats.get("sets", 0)) < int(t["sets"]):
			break
		if t.has("paid_sets") and int(s.stats.get("paid_sets", 0)) < int(t["paid_sets"]):
			break
		if t.has("opener_sets") and int(s.stats.get("opener_sets", 0)) < int(t["opener_sets"]):
			break
		if t.has("rep") and s.reputation < float(t["rep"]):
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
			if t.has("sets"):
				parts.append("%d/%d sets" % [int(s.stats.get("sets", 0)), int(t["sets"])])
			if t.has("paid_sets"):
				parts.append("%d/%d paid sets" % [int(s.stats.get("paid_sets", 0)), int(t["paid_sets"])])
			if t.has("opener_sets"):
				parts.append("%d/%d opening sets" % [int(s.stats.get("opener_sets", 0)), int(t["opener_sets"])])
			if t.has("rep"):
				parts.append("reputation %.0f/%d" % [s.reputation, int(t["rep"])])
			return "Next: %s (%s)" % [t["name"], ", ".join(PackedStringArray(parts))]
	return ""
