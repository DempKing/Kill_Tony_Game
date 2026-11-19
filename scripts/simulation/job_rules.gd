class_name JobRules
extends RefCounted
## Jobs: hiring, shift availability, shift event layer and pay resolution.
## A shift is begun (events drawn from the world RNG and stored on state, so a
## reload shows the same events) then finished with the player's choices.


static func is_hired(s: GameState, job_id: String) -> bool:
	return s.jobs.has(job_id)


static func hire(s: GameState, db: ContentDB, job_id: String) -> Dictionary:
	if not db.jobs.has(job_id):
		return {"ok": false, "message": "Unknown job."}
	if s.jobs.has(job_id):
		return {"ok": false, "message": "You already have that job."}
	var start_rel := 30
	var bg: Dictionary = db.backgrounds.get(str(s.player.get("background", "")), {})
	var bonus: Dictionary = bg.get("job_bonus", {}).get(job_id, {})
	start_rel += int(bonus.get("reliability_start", 0))
	s.jobs[job_id] = {"reliability": start_rel, "shifts": 0, "last_day": -1, "today": 0}
	var job: Dictionary = db.jobs[job_id]
	var boss: String = str(job.get("boss", ""))
	if boss != "":
		Relationships.change(s, boss, {"familiarity": 3})
	return {"ok": true, "message": str(job.get("hire_text", "You're hired."))}


## Shift options available right now for a job (respecting block and daily limits).
static func shift_options(s: GameState, db: ContentDB, job_id: String) -> Array:
	var out: Array = []
	if not s.jobs.has(job_id) and not bool(db.jobs.get(job_id, {}).get("emergency", false)):
		return out
	var job: Dictionary = db.jobs[job_id]
	var rec: Dictionary = s.jobs.get(job_id, {"last_day": -1, "today": 0})
	var today: int = int(rec.get("today", 0)) if int(rec.get("last_day", -1)) == s.day else 0
	var max_per_day: int = int(job.get("max_per_day", 1))
	for sh in job.get("shifts", []):
		var start: int = int(sh["start"])
		var length: int = int(sh["length"])
		var ok := true
		var reason := ""
		if start >= 0 and s.block != start:
			ok = false
			reason = "Starts in the %s." % CalendarRules.block_name(start)
		elif s.block + length > 4:
			ok = false
			reason = "Too late in the day."
		elif today >= max_per_day:
			ok = false
			reason = "You've already worked this job today."
		out.append({"job_id": job_id, "shift_id": str(sh["id"]), "label": "%s (%s, %d block%s)" % [sh["name"], CalendarRules.block_name(s.block if start < 0 else start), length, "s" if length > 1 else ""],
			"length": length, "enabled": ok, "reason": reason, "energy": int(job.get("energy", -20))})
	return out


static func begin_shift(s: GameState, db: ContentDB, job_id: String, shift_id: String) -> Dictionary:
	var job: Dictionary = db.jobs.get(job_id, {})
	var pool: Array = job.get("events", []).duplicate()
	var r := s.rng("world")
	var picks: Array = []
	var count := 1 if pool.size() < 3 else 2
	for i in range(count):
		if pool.is_empty():
			break
		var idx := r.randi_range(0, pool.size() - 1)
		picks.append(str(pool[idx]))
		pool.remove_at(idx)
	var tip_range: Array = job.get("tips", [0, 0])
	var tips := r.randi_range(int(tip_range[0]), int(tip_range[1]))
	var shift := {"job_id": job_id, "shift_id": shift_id, "events": picks, "tips_roll": tips, "day": s.day, "block": s.block}
	s.flags["active_shift"] = shift
	return shift


## Resolves the shift. choices: Array of choice indices, one per event.
## Idempotent per shift via a claim id.
static func finish_shift(s: GameState, db: ContentDB, choices: Array) -> Dictionary:
	var shift: Dictionary = s.flags.get("active_shift", {})
	if shift.is_empty():
		return {"ok": false, "message": "No shift in progress."}
	var claim := "shift_%s_%d_%d" % [shift["job_id"], int(shift["day"]), int(shift["block"])]
	if s.claimed.has(claim):
		s.flags.erase("active_shift")
		return {"ok": false, "message": "Shift already paid."}
	var job_id: String = str(shift["job_id"])
	var job: Dictionary = db.jobs[job_id]
	if not s.jobs.has(job_id):
		s.jobs[job_id] = {"reliability": 30, "shifts": 0, "last_day": -1, "today": 0}
	var rec: Dictionary = s.jobs[job_id]
	var pay: int = int(job.get("base_pay", 0))
	var tips: int = int(shift["tips_roll"])
	var notes: Array = []
	var r := s.rng("world")
	var events: Array = shift["events"]
	for i in range(events.size()):
		var ev: Dictionary = db.shift_events.get(str(events[i]), {})
		var opts: Array = ev.get("choices", [])
		if opts.is_empty():
			continue
		var ci: int = clampi(int(choices[i]) if i < choices.size() else 0, 0, opts.size() - 1)
		var ch: Dictionary = opts[ci]
		var fx: Dictionary = ch.get("effects", {})
		if ch.has("chance") and r.randf() >= float(ch["chance"]):
			fx = ch.get("fail_effects", {})
			notes.append("It didn't go how you hoped.")
		pay += int(fx.get("pay", 0))
		tips += int(fx.get("tips", 0))
		notes.append_array(StatsRules.apply_effects(s, db, fx, job_id, "shift"))
	# Reliability scales tips slightly; background bonuses apply.
	var bg: Dictionary = db.backgrounds.get(str(s.player.get("background", "")), {})
	var mult: float = float(bg.get("job_bonus", {}).get(job_id, {}).get("tips_mult", 1.0))
	mult *= 0.85 + float(rec.get("reliability", 30)) / 200.0
	if bool(s.flags.get("delivery_surge", false)) and job_id == "delivery":
		pay *= 2
		s.flags.erase("delivery_surge")
		notes.append("Surge pay!")
	tips = maxi(0, int(round(tips * mult)))
	var costs: int = int(job.get("costs", 0))
	var total := maxi(0, pay + tips - costs)
	StatsRules.add_cash(s, total, "%s shift" % job.get("name", job_id))
	StatsRules.change_energy(s, int(job.get("energy", -20)))
	StatsRules.change_stress(s, int(job.get("stress", 5)))
	rec["shifts"] = int(rec.get("shifts", 0)) + 1
	rec["reliability"] = clampi(int(rec.get("reliability", 30)) + 1, 0, 100)
	if int(rec.get("last_day", -1)) != s.day:
		rec["today"] = 0
	rec["last_day"] = s.day
	rec["today"] = int(rec.get("today", 0)) + 1
	s.stats["shifts"] = int(s.stats.get("shifts", 0)) + 1
	var boss: String = str(job.get("boss", ""))
	if boss != "":
		Relationships.change(s, boss, {"familiarity": 1, "reliability": 1})
	if int(rec["shifts"]) == 1:
		for cid in job.get("first_shift_unlock", []):
			if JokeRules.unlock_component(s, db, str(cid)):
				notes.append("New premise from work: \"%s\"" % db.component(str(cid)).get("text", ""))
	s.claimed[claim] = s.day
	var promise_id: String = str(shift.get("promise_id", ""))
	if promise_id != "":
		notes.append_array(PromiseRules.keep(s, db, promise_id))
	s.flags.erase("active_shift")
	var length := 1
	for sh in job.get("shifts", []):
		if str(sh["id"]) == str(shift["shift_id"]):
			length = int(sh["length"])
	var summary := "Earned $%d (base $%d, tips $%d%s)." % [total, pay, tips, ", costs $%d" % costs if costs > 0 else ""]
	return {"ok": true, "earned": total, "blocks": length, "message": summary, "notes": notes}
