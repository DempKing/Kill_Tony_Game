class_name ContentDB
extends RefCounted
## Loads authored content (JSON under res://data) into lookup tables keyed by
## stable string IDs. Pure data: no scene or autoload dependencies, so tests
## can instantiate it directly.

const DATA_ROOT := "res://data/"

var balancing: Dictionary = {}
var families: Dictionary = {}
var components: Dictionary = {}
var jobs: Dictionary = {}
var shift_events: Dictionary = {}
var venues: Dictionary = {}
var audiences: Dictionary = {}
var npcs: Dictionary = {}
var bucket_names: Dictionary = {}
var world_events: Array = []
var observations: Dictionary = {}
var posters: Array = []
var interviews: Array = []
var opportunities: Dictionary = {}
var backgrounds: Dictionary = {}
var styles: Dictionary = {}
var genders: Dictionary = {}
var appearance: Dictionary = {}
var books: Dictionary = {}
var housing: Dictionary = {}
var locations: Dictionary = {}
var location_order: Array = []
var world: Dictionary = {}
var partner: Dictionary = {}
var stage_layout: Dictionary = {}
var errors: Array = []


static func load_default() -> ContentDB:
	var db := ContentDB.new()
	db.load_all(DATA_ROOT)
	return db


func load_all(root: String) -> void:
	errors.clear()
	balancing = _read_dict(root + "balancing/balancing.json")

	var mat: Dictionary = _read_dict(root + "material/components.json")
	for f in mat.get("families", []):
		families[str(f["id"])] = f
	for c in mat.get("components", []):
		var comp: Dictionary = c
		_derive_compat(comp)
		components[str(comp["id"])] = comp

	var j: Dictionary = _read_dict(root + "jobs/jobs.json")
	for job in j.get("jobs", []):
		jobs[str(job["id"])] = job
	for ev in j.get("shift_events", []):
		shift_events[str(ev["id"])] = ev

	var v: Dictionary = _read_dict(root + "venues/venues.json")
	for a in v.get("audiences", []):
		audiences[str(a["id"])] = a
	for ven in v.get("venues", []):
		venues[str(ven["id"])] = ven

	var loc: Dictionary = _read_dict(root + "venues/locations.json")
	world = loc.get("world", {})
	for l in loc.get("locations", []):
		locations[str(l["id"])] = l
		location_order.append(str(l["id"]))
	for o in loc.get("observations", []):
		observations[str(o["id"])] = o
	posters = loc.get("posters", [])

	var n: Dictionary = _read_dict(root + "npcs/npcs.json")
	for npc in n.get("npcs", []):
		npcs[str(npc["id"])] = npc
	bucket_names = n.get("bucket_names", {})

	world_events = _read_dict(root + "events/world_events.json").get("events", [])
	interviews = _read_dict(root + "interviews/interviews.json").get("prompts", [])

	for o in _read_dict(root + "opportunities/opportunities.json").get("opportunities", []):
		opportunities[str(o["id"])] = o

	var ch: Dictionary = _read_dict(root + "character/character.json")
	for g in ch.get("genders", []):
		genders[str(g["id"])] = g
	appearance = ch.get("appearance", {})
	for b in ch.get("backgrounds", []):
		backgrounds[str(b["id"])] = b
	for s in ch.get("styles", []):
		styles[str(s["id"])] = s
	for bk in ch.get("books", []):
		books[str(bk["id"])] = bk
	for h in ch.get("housing", []):
		housing[str(h["id"])] = h

	partner = _read_dict(root + "partner/partner_content.json")
	stage_layout = _read_dict(root + "partner/kill_tony_stage_layout.json")
	errors.append_array(validate())


func _read_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		errors.append("Missing data file: " + path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		errors.append("Cannot open: " + path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		errors.append("Malformed JSON: " + path)
		return {}
	# JSON numbers parse as floats; whole numbers become ints so lookups like
	# `[0, 1].has(block)` behave.
	return GameState.normalize(parsed)


## Derives authored compatibility tags from family + component type when the
## data does not list them explicitly. See docs/CONTENT_GUIDE.md.
static func _derive_compat(c: Dictionary) -> void:
	var fam: String = str(c.get("family", ""))
	var t: String = str(c.get("type", ""))
	if not c.has("provides"):
		match t:
			"premise": c["provides"] = [fam]
			"setup": c["provides"] = [fam + "_setup"]
			"punchline": c["provides"] = [fam + "_punch"]
			_: c["provides"] = []
	if not c.has("requires"):
		match t:
			"premise": c["requires"] = []
			"setup": c["requires"] = [fam]
			"punchline": c["requires"] = [fam + "_setup"]
			"tag", "act_out": c["requires"] = [fam + "_punch"]
			_: c["requires"] = []
	if c.has("extra_requires"):
		var r: Array = c["requires"].duplicate()
		r.append_array(c["extra_requires"])
		c["requires"] = r


func validate() -> Array:
	var out: Array = []
	for id in components:
		var c: Dictionary = components[id]
		if not families.has(str(c.get("family", ""))):
			out.append("Component %s has unknown family" % id)
	for id in jobs:
		for ev_id in jobs[id].get("events", []):
			if not shift_events.has(str(ev_id)):
				out.append("Job %s references unknown event %s" % [id, ev_id])
	for id in venues:
		var v: Dictionary = venues[id]
		if not audiences.has(str(v.get("audience", ""))):
			out.append("Venue %s has unknown audience" % id)
		if not locations.has(str(v.get("location", ""))):
			out.append("Venue %s has unknown location" % id)
	for id in opportunities:
		var o: Dictionary = opportunities[id]
		if not venues.has(str(o.get("venue", ""))):
			out.append("Opportunity %s has unknown venue" % id)
	for id in observations:
		for cid in observations[id].get("unlock", []):
			if not components.has(str(cid)):
				out.append("Observation %s unlocks unknown component %s" % [id, cid])
	return out


# --- Convenience accessors -------------------------------------------------

func bal(path: String, fallback: Variant = null) -> Variant:
	## Reads a balancing value with a dotted path, e.g. "economy.late_fee".
	var cur: Variant = balancing
	for key in path.split("."):
		if typeof(cur) != TYPE_DICTIONARY or not (cur as Dictionary).has(key):
			return fallback
		cur = (cur as Dictionary)[key]
	return cur


func balf(path: String, fallback: float = 0.0) -> float:
	return float(bal(path, fallback))


func bali(path: String, fallback: int = 0) -> int:
	return int(bal(path, fallback))


func component(id: String) -> Dictionary:
	return components.get(id, {})


func character_name(id: String) -> String:
	if npcs.has(id):
		return str(npcs[id]["name"])
	var chars: Dictionary = partner.get("characters", {})
	if chars.has(id):
		return str(chars[id].get("display_name", id))
	return id


func book_capacity(book_id: String) -> int:
	return int(books.get(book_id, {}).get("capacity", 3))


func family_components(family_id: String) -> Array:
	var out: Array = []
	for id in components:
		if str(components[id].get("family", "")) == family_id:
			out.append(components[id])
	return out
