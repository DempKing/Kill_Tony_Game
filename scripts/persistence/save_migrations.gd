class_name SaveMigrations
extends RefCounted
## Ordered migrations from older save versions to GameState.SAVE_VERSION.
## Add a function per version step; never edit an existing step.


static func migrate(d: Dictionary) -> Dictionary:
	var v: int = int(d.get("version", 0))
	if v < 1:
		d = _v0_to_v1(d)
	if v < 2:
		d = _v1_to_v2(d)
	return d


## Version 0 = prototype saves without a version field or rng block.
static func _v0_to_v1(d: Dictionary) -> Dictionary:
	if not d.has("rngs"):
		d["rngs"] = {}
	if not d.has("kt"):
		d["kt"] = {"draws": {}, "appearances": 0, "golden_tickets": 0, "regular_progress": 0, "history": []}
	if not d.has("books"):
		d["books"] = ["starter_journal"]
	d["version"] = 1
	return d


## Version 2 replaces player.pronouns with player.gender (male/female).
static func _v1_to_v2(d: Dictionary) -> Dictionary:
	var p: Dictionary = d.get("player", {})
	if not p.has("gender"):
		p["gender"] = "female" if str(p.get("pronouns", "")) == "she" else "male"
	p.erase("pronouns")
	d["player"] = p
	d["version"] = 2
	return d
