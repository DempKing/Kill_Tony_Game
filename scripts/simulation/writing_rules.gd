class_name WritingRules
extends RefCounted
## Writing sessions (1 block). Tasks: develop a premise (discover the next
## component of a family), polish a joke, or rehearse a setlist. Discovery is
## bounded-random with a pity counter so failure still makes progress.

const DISCOVERY_ORDER: Array = ["setup", "punchline", "tag", "act_out", "callback"]


static func next_discoverable(s: GameState, db: ContentDB, family: String) -> Dictionary:
	## Returns {component, blocked_by_skill} for the next writing-unlockable piece.
	var writing := StatsRules.skill(s, "writing")
	var blocked: Dictionary = {}
	for t in DISCOVERY_ORDER:
		var candidates: Array = []
		for c in db.family_components(family):
			if str(c.get("type", "")) == t and str(c.get("unlock", "")) == "writing" and not s.components.has(str(c["id"])):
				candidates.append(c)
		candidates.sort_custom(func(a, b): return int(a.get("min_skill", 0)) < int(b.get("min_skill", 0)))
		for c in candidates:
			if writing >= float(c.get("min_skill", 0)):
				return {"component": c, "blocked": blocked}
			if blocked.is_empty():
				blocked = c
	return {"component": {}, "blocked": blocked}


static func tasks(s: GameState, db: ContentDB, location_id: String) -> Array:
	var out: Array = []
	var bonus := db.balf("writing.coffee_shop_bonus", 0.1) if location_id == "coffee" else 0.0
	for cid in s.components:
		var c := db.component(str(cid))
		if str(c.get("type", "")) != "premise":
			continue
		var fam: String = str(c["family"])
		var nd := next_discoverable(s, db, fam)
		var comp: Dictionary = nd["component"]
		if comp.is_empty():
			var blk: Dictionary = nd["blocked"]
			if not blk.is_empty():
				out.append({"task": "develop", "family": fam, "label": "Develop: %s" % c["text"], "enabled": false,
					"hint": "You sense a better angle here, but need Writing %d to crack it." % int(blk.get("min_skill", 0))})
			continue
		out.append({"task": "develop", "family": fam, "label": "Develop: %s" % c["text"], "enabled": true,
			"hint": "Find the next piece (%s). %d%% chance%s." % [str(comp["type"]).replace("_", "-"), int(chance(s, db, fam, bonus) * 100.0), " (guaranteed: you've been circling it)" if pity_ready(s, db, fam) else ""]})
	for jid in s.jokes:
		var j: Dictionary = s.jokes[jid]
		if str(j.get("status", "wip")) != "wip":
			continue
		var rev := JokeRules.current_revision(j)
		if JokeRules.status_of(db, j) == "missing":
			continue
		if int(rev.get("polish", 0)) < db.bali("writing.max_polish", 5):
			out.append({"task": "polish", "joke_id": jid, "label": "Polish: %s" % j["title"], "enabled": true,
				"hint": "Tighten wording and rhythm. Quality +%d. Creates a new revision." % int(db.balf("writing.polish_quality_per_level", 2.0))})
	for sid in s.setlists:
		var jokes := SetRules.jokes_in(s, str(sid))
		if jokes.size() > 0:
			out.append({"task": "rehearse", "setlist_id": sid, "label": "Rehearse: %s" % s.setlists[sid]["name"], "enabled": true,
				"hint": "Run it out loud. Familiarity +%d for %d jokes." % [db.bali("writing.rehearse_familiarity", 15), jokes.size()]})
	return out


static func pity_ready(s: GameState, db: ContentDB, family: String) -> bool:
	return int(s.pity.get(family, 0)) >= db.bali("writing.pity_threshold", 2)


static func chance(s: GameState, db: ContentDB, family: String, bonus: float) -> float:
	if pity_ready(s, db, family):
		return 1.0
	var c := db.balf("writing.base_chance", 0.4) + StatsRules.skill(s, "writing") / db.balf("writing.skill_divisor", 150.0) + float(s.confidence) / db.balf("writing.confidence_divisor", 400.0) + bonus
	return clampf(c, db.balf("writing.min_chance", 0.1), db.balf("writing.max_chance", 0.9))


## Executes a task. Caller is responsible for time advancement.
static func do_task(s: GameState, db: ContentDB, task: Dictionary, location_id: String) -> Dictionary:
	var notes: Array = []
	StatsRules.change_energy(s, -db.bali("writing.energy_cost", 8))
	match str(task.get("task", "")):
		"develop":
			var fam: String = str(task["family"])
			var nd := next_discoverable(s, db, fam)
			var comp: Dictionary = nd["component"]
			if comp.is_empty():
				return {"ok": false, "message": "Nothing more to find here right now."}
			var bonus := db.balf("writing.coffee_shop_bonus", 0.1) if location_id == "coffee" else 0.0
			var p := chance(s, db, fam, bonus)
			var roll := s.rng("world").randf()
			if roll < p:
				JokeRules.unlock_component(s, db, str(comp["id"]))
				s.pity[fam] = 0
				StatsRules.add_skill(s, "writing", db.balf("writing.success_skill_gain", 1.0))
				notes.append("You cracked it. New %s: \"%s\"" % [str(comp["type"]).replace("_", "-"), comp["text"]])
				return {"ok": true, "success": true, "message": "\n".join(PackedStringArray(notes)), "component": comp["id"]}
			s.pity[fam] = int(s.pity.get(fam, 0)) + 1
			StatsRules.add_skill(s, "writing", db.balf("writing.fail_skill_gain", 0.5))
			return {"ok": true, "success": false, "message": "Pages of nothing usable. But you know what doesn't work now, and you're closer."}
		"polish":
			var jid: String = str(task["joke_id"])
			var j: Dictionary = s.jokes.get(jid, {})
			if j.is_empty():
				return {"ok": false, "message": "No such joke."}
			var res := JokeRules.revise_joke(s, db, jid, JokeRules.parts_of(j), 1)
			StatsRules.add_skill(s, "writing", 0.4)
			return {"ok": bool(res["ok"]), "message": "You tighten \"%s\". %s" % [j["title"], res["message"]]}
		"rehearse":
			var sid: String = str(task["setlist_id"])
			var gain := db.bali("writing.rehearse_familiarity", 15)
			for jid2 in SetRules.jokes_in(s, sid):
				var jk: Dictionary = s.jokes[jid2]
				jk["familiarity"] = mini(100, int(jk.get("familiarity", 0)) + gain)
			StatsRules.change_confidence(s, db.bali("writing.rehearse_confidence", 2))
			StatsRules.add_skill(s, "delivery", 0.3)
			return {"ok": true, "message": "You run \"%s\" until you can do it in your sleep. Familiarity +%d." % [s.setlists[sid]["name"], gain]}
	return {"ok": false, "message": "Unknown writing task."}
