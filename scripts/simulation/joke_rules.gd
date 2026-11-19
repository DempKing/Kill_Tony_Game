class_name JokeRules
extends RefCounted
## Joke components, authored compatibility, quality, duration, revisions and
## work-in-progress capacity.
##
## Joke record:
##   id, title, notes, status ("wip" | "complete"), current_rev,
##   revisions: [{rev, parts:{premise,setup,punchline,tag,act_out,callback}, polish, day}],
##   familiarity, test_count, exposure:{venue_id: count}, history:[...], feedback:[...]
## Old revisions are never mutated, so performance history keeps pointing at
## the exact material that was performed.

const REQUIRED: Array = ["premise", "setup", "punchline"]
const OPTIONAL: Array = ["tag", "act_out", "callback"]
const PART_ORDER: Array = ["premise", "setup", "punchline", "tag", "act_out", "callback"]
const STATUS_RANK: Dictionary = {"coherent": 0, "weak": 1, "missing_context": 2, "incompatible": 3, "missing": 4}
const STATUS_LABEL: Dictionary = {
	"coherent": "Coherent",
	"weak": "Weak link",
	"incompatible": "Incompatible",
	"missing": "Incomplete",
	"missing_context": "Missing context",
}


static func unlock_component(s: GameState, db: ContentDB, id: String) -> bool:
	if id == "" or s.components.has(id) or not db.components.has(id):
		return false
	s.components.append(id)
	return true


static func current_revision(joke: Dictionary) -> Dictionary:
	var revs: Array = joke.get("revisions", [])
	var want: int = int(joke.get("current_rev", 1))
	for r in revs:
		if int(r["rev"]) == want:
			return r
	return revs.back() if revs.size() > 0 else {}


static func revision(joke: Dictionary, rev: int) -> Dictionary:
	for r in joke.get("revisions", []):
		if int(r["rev"]) == rev:
			return r
	return {}


static func parts_of(joke: Dictionary) -> Dictionary:
	return current_revision(joke).get("parts", {})


static func family_topics(db: ContentDB, fam_id: String) -> Array:
	return db.families.get(fam_id, {}).get("topics", [])


static func _intersects(a: Array, b: Array) -> bool:
	for x in a:
		if b.has(x):
			return true
	return false


## Rates the link from `src` (one or more components) into `dst`.
static func link_status(db: ContentDB, src: Array, dst: Dictionary) -> String:
	var provided: Array = []
	var topics: Array = []
	for c in src:
		provided.append_array(c.get("provides", []))
		topics.append_array(family_topics(db, str(c.get("family", ""))))
	if _intersects(dst.get("requires", []), provided):
		return "coherent"
	if _intersects(family_topics(db, str(dst.get("family", ""))), topics):
		return "weak"
	return "incompatible"


static func _worse(a: String, b: String) -> String:
	return a if int(STATUS_RANK.get(a, 0)) >= int(STATUS_RANK.get(b, 0)) else b


## Evaluates a parts dictionary. Returns {status, links:[{a,b,status}], missing:[...]}.
## The game does not understand humor: this is purely authored tag matching.
static func evaluate(db: ContentDB, parts: Dictionary) -> Dictionary:
	var missing: Array = []
	for p in REQUIRED:
		if str(parts.get(p, "")) == "" or not db.components.has(str(parts.get(p, ""))):
			missing.append(p)
	if missing.size() > 0:
		return {"status": "missing", "links": [], "missing": missing}
	var P: Dictionary = db.component(str(parts["premise"]))
	var S: Dictionary = db.component(str(parts["setup"]))
	var U: Dictionary = db.component(str(parts["punchline"]))
	var links: Array = []
	var worst := "coherent"
	var ps := link_status(db, [P], S)
	links.append({"a": "premise", "b": "setup", "status": ps})
	worst = _worse(worst, ps)
	var su := link_status(db, [P, S], U)
	links.append({"a": "setup", "b": "punchline", "status": su})
	worst = _worse(worst, su)
	for opt in OPTIONAL:
		var cid: String = str(parts.get(opt, ""))
		if cid == "":
			continue
		var C: Dictionary = db.component(cid)
		if C.is_empty():
			continue
		var st := link_status(db, [U], C)
		links.append({"a": "punchline", "b": opt, "status": st})
		worst = _worse(worst, st)
	return {"status": worst, "links": links, "missing": []}


static func status_of(db: ContentDB, joke: Dictionary) -> String:
	return str(evaluate(db, parts_of(joke))["status"])


static func seconds_of_parts(db: ContentDB, parts: Dictionary, include_optional: bool = true) -> int:
	var total := 0
	for p in PART_ORDER:
		if not include_optional and OPTIONAL.has(p):
			continue
		var cid: String = str(parts.get(p, ""))
		if cid != "":
			total += int(db.component(cid).get("seconds", 0))
	return total


static func seconds_of(db: ContentDB, joke: Dictionary) -> int:
	return seconds_of_parts(db, parts_of(joke))


## Core joke quality 0-100 from premise/setup/punchline, coherence and polish.
## Tag, act-out and callback are scored separately during performance.
static func quality_of_parts(db: ContentDB, parts: Dictionary, polish: int) -> float:
	var ev := evaluate(db, parts)
	var st: String = str(ev["status"])
	if st == "missing":
		return 0.0
	var w: Dictionary = db.bal("joke.weights", {"premise": 0.2, "setup": 0.3, "punchline": 0.5})
	var q := 0.0
	for p in REQUIRED:
		q += float(db.component(str(parts[p])).get("quality", 1)) * float(w.get(p, 0.33))
	q *= 10.0
	var mult: Dictionary = db.bal("joke.coherence_multiplier", {})
	q *= float(mult.get(st, 1.0))
	q += float(polish) * db.balf("writing.polish_quality_per_level", 2.0)
	return clampf(q, 0.0, 100.0)


static func quality_of(db: ContentDB, joke: Dictionary) -> float:
	var r := current_revision(joke)
	return quality_of_parts(db, r.get("parts", {}), int(r.get("polish", 0)))


static func topics_of(db: ContentDB, parts: Dictionary) -> Array:
	var out: Array = []
	for p in PART_ORDER:
		var cid: String = str(parts.get(p, ""))
		if cid == "":
			continue
		for t in family_topics(db, str(db.component(cid).get("family", ""))):
			if not out.has(t):
				out.append(t)
	return out


static func styles_of(db: ContentDB, parts: Dictionary) -> Array:
	var out: Array = []
	for p in PART_ORDER:
		var cid: String = str(parts.get(p, ""))
		if cid == "":
			continue
		for st in db.component(cid).get("styles", []):
			if not out.has(st):
				out.append(st)
	return out


static func stat_avg(db: ContentDB, parts: Dictionary, key: String) -> float:
	var total := 0.0
	var n := 0
	for p in REQUIRED:
		var cid: String = str(parts.get(p, ""))
		if cid != "":
			total += float(db.component(cid).get(key, 0))
			n += 1
	return total / float(n) if n > 0 else 0.0


static func family_of(db: ContentDB, joke: Dictionary) -> String:
	return str(db.component(str(parts_of(joke).get("premise", ""))).get("family", ""))


# --- Journal operations ---------------------------------------------------

static func wip_count(s: GameState) -> int:
	var n := 0
	for id in s.jokes:
		if str(s.jokes[id].get("status", "wip")) == "wip":
			n += 1
	return n


static func can_add_wip(s: GameState, db: ContentDB) -> bool:
	return wip_count(s) < s.book_capacity(db)


static func _validate_parts(s: GameState, db: ContentDB, parts: Dictionary) -> String:
	for p in parts:
		var cid: String = str(parts[p])
		if cid == "":
			continue
		if not s.components.has(cid):
			return "You haven't discovered that material yet."
		if str(db.component(cid).get("type", "")) != str(p):
			return "That piece doesn't go in the %s slot." % p
	return ""


## Creates a new work-in-progress joke. Limited by active book capacity.
static func create_joke(s: GameState, db: ContentDB, title: String, parts: Dictionary) -> Dictionary:
	if not can_add_wip(s, db):
		return {"ok": false, "message": "Your journal only has room for %d works in progress. Finish or shelve one first." % s.book_capacity(db)}
	var err := _validate_parts(s, db, parts)
	if err != "":
		return {"ok": false, "message": err}
	var id := "joke_%d" % s.next_joke_num
	s.next_joke_num += 1
	var clean := _clean_parts(parts)
	s.jokes[id] = {
		"id": id,
		"title": title if title.strip_edges() != "" else "Untitled bit",
		"notes": "",
		"status": "wip",
		"current_rev": 1,
		"revisions": [{"rev": 1, "parts": clean, "polish": 0, "day": s.day}],
		"familiarity": 0,
		"test_count": 0,
		"exposure": {},
		"history": [],
		"feedback": [],
	}
	return {"ok": true, "id": id, "message": "Wrote \"%s\" into the journal." % s.jokes[id]["title"]}


static func _clean_parts(parts: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for p in PART_ORDER:
		var cid: String = str(parts.get(p, ""))
		if cid != "":
			out[p] = cid
	return out


## Rewrites a joke as a new revision. Previous revisions remain untouched.
static func revise_joke(s: GameState, db: ContentDB, joke_id: String, parts: Dictionary, polish_delta: int = 0) -> Dictionary:
	if not s.jokes.has(joke_id):
		return {"ok": false, "message": "No such joke."}
	var joke: Dictionary = s.jokes[joke_id]
	var err := _validate_parts(s, db, parts)
	if err != "":
		return {"ok": false, "message": err}
	var cur := current_revision(joke)
	var clean := _clean_parts(parts)
	var same_parts: bool = clean == cur.get("parts", {})
	var new_polish: int = clampi(int(cur.get("polish", 0)) + polish_delta, 0, db.bali("writing.max_polish", 5))
	if same_parts and polish_delta == 0:
		return {"ok": false, "message": "Nothing changed."}
	var next_rev: int = 1
	for r in joke["revisions"]:
		next_rev = maxi(next_rev, int(r["rev"]) + 1)
	# Changing components resets polish and costs familiarity.
	if not same_parts:
		new_polish = 0
		joke["familiarity"] = int(float(joke.get("familiarity", 0)) * db.balf("writing.revise_familiarity_keep", 0.6))
	joke["revisions"].append({"rev": next_rev, "parts": clean, "polish": new_polish, "day": s.day})
	joke["current_rev"] = next_rev
	return {"ok": true, "rev": next_rev, "message": "\"%s\" is now revision %d." % [joke["title"], next_rev]}


static func set_status(s: GameState, db: ContentDB, joke_id: String, status: String) -> Dictionary:
	if not s.jokes.has(joke_id):
		return {"ok": false, "message": "No such joke."}
	var joke: Dictionary = s.jokes[joke_id]
	if status == "wip" and str(joke["status"]) != "wip" and not can_add_wip(s, db):
		return {"ok": false, "message": "No room for another work in progress."}
	joke["status"] = status
	var msg := "Moved \"%s\" to the finished archive." % joke["title"] if status == "complete" else "Reopened \"%s\" for work." % joke["title"]
	return {"ok": true, "message": msg}


static func rename(s: GameState, joke_id: String, title: String, notes: String) -> void:
	if s.jokes.has(joke_id):
		if title.strip_edges() != "":
			s.jokes[joke_id]["title"] = title.strip_edges()
		s.jokes[joke_id]["notes"] = notes


static func components_of_type(s: GameState, db: ContentDB, type: String) -> Array:
	var out: Array = []
	for cid in s.components:
		var c := db.component(str(cid))
		if str(c.get("type", "")) == type:
			out.append(c)
	return out
