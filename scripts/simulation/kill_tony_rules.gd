class_name KillTonyRules
extends RefCounted
## Monday signup, bucket draw, interview and reward resolution.
## The draw is stored on state before reveal, so reloading never rerolls it.
## Fame is not an input to the draw.

const VENUE_ID := "kill_tony"


static func show_block(db: ContentDB) -> int:
	return db.bali("bucket.show_block", 2)


static func signup_info(s: GameState, db: ContentDB) -> Dictionary:
	var pulls := db.bali("bucket.pulls", 8)
	var lo := db.bali("bucket.entrants_min", 35)
	var hi := db.bali("bucket.entrants_max", 60)
	var lines: Array = [
		"Attendance: you must be at the Comedy Mothership for the %s block tonight." % CalendarRules.block_name(show_block(db)),
		"Selection: about %d names are pulled from a bucket of %d-%d entrants. Everyone's slip counts the same." % [pulls, lo, hi],
		"If pulled: one minute at the mic, then an interview with the panel.",
	]
	if int(s.kt.get("golden_tickets", 0)) > 0:
		lines.append("Access: your golden ticket guarantees you a spot. It will be used tonight.")
	var minute := SetRules.jokes_in(s, SetRules.KT_MINUTE_ID)
	if minute.is_empty():
		lines.append("Warning: your prepared minute is empty. Build it in the journal.")
	else:
		var a := SetRules.analyze(s, db, minute, 60, VENUE_ID)
		lines.append("Your prepared minute runs %ds (core %ds)." % [int(a["seconds"]), int(a["core_seconds"])])
	var conf := Scheduler.conflicts(s, s.day, show_block(db), 1)
	for c in conf:
		lines.append("Conflict: %s." % c.get("title", "booking"))
	return {"lines": lines, "conflicts": conf}


static func can_signup(s: GameState, db: ContentDB) -> Dictionary:
	if CalendarRules.weekday(s.day) != CalendarRules.MONDAY:
		return {"ok": false, "reason": "Kill Tony signups are on Mondays."}
	var blocks: Array = db.bal("bucket.signup_blocks", [0, 1])
	if not blocks.has(s.block):
		return {"ok": false, "reason": "Signups happen before the show, in the morning or afternoon."}
	for c in Scheduler.booked(s):
		if str(c.get("kind", "")) == "kill_tony" and int(c["day"]) == s.day:
			return {"ok": false, "reason": "You're already signed up for tonight."}
	if s.kt.get("draws", {}).has(str(s.day)):
		return {"ok": false, "reason": "Tonight's bucket has already been drawn."}
	return {"ok": true, "reason": ""}


static func signup(s: GameState, db: ContentDB, force: bool = false) -> Dictionary:
	var chk := can_signup(s, db)
	if not bool(chk["ok"]):
		return {"ok": false, "message": chk["reason"]}
	var c := {"kind": "kill_tony", "title": "Kill Tony (bucket signup)", "day": s.day, "block": show_block(db), "length": 1,
		"location_id": "mothership", "venue_id": VENUE_ID, "slot_seconds": db.bali("bucket.set_seconds", 60), "pay": 0, "fee": 0, "npc": ""}
	var res := Scheduler.add(s, db, c, force)
	if not bool(res["ok"]):
		return {"ok": false, "conflicts": res["conflicts"], "message": "That conflicts with another booking."}
	return {"ok": true, "message": "Your name is on a slip of paper in the bucket. Be here tonight.", "commitment": res["commitment"]}


## Pure draw: shuffles entrant indices without replacement, returns the
## pulled indices in order. Index 0 is the player.
static func draw_order(r: RandomNumberGenerator, entrants: int, pulls: int) -> Array:
	var idx: Array = []
	for i in range(entrants):
		idx.append(i)
	for i in range(entrants - 1, 0, -1):
		var j := r.randi_range(0, i)
		var tmp: int = idx[i]
		idx[i] = idx[j]
		idx[j] = tmp
	return idx.slice(0, mini(pulls, entrants))


static func _random_name(db: ContentDB, r: RandomNumberGenerator) -> String:
	var first: Array = db.bucket_names.get("first", ["Comic"])
	var last: Array = db.bucket_names.get("last", ["Doe"])
	return "%s %s" % [first[r.randi_range(0, first.size() - 1)], last[r.randi_range(0, last.size() - 1)]]


## Returns the stored draw for a day, creating (and storing) it if missing.
## The caller must save immediately after creation and before reveal.
static func ensure_draw(s: GameState, db: ContentDB, day: int) -> Dictionary:
	var draws: Dictionary = s.kt["draws"]
	var key := str(day)
	if draws.has(key):
		return draws[key]
	var r := s.rng("bucket")
	var entrants := r.randi_range(db.bali("bucket.entrants_min", 35), db.bali("bucket.entrants_max", 60))
	var pulls := db.bali("bucket.pulls", 8)
	var order := draw_order(r, entrants, pulls)
	var selected: bool = order.has(0)
	var position: int = order.find(0) + 1
	var golden := false
	if not selected and int(s.kt.get("golden_tickets", 0)) > 0:
		# Golden ticket access rule: a guaranteed spot, separate from the bucket odds.
		selected = true
		golden = true
		position = r.randi_range(2, pulls)
		s.kt["golden_tickets"] = int(s.kt["golden_tickets"]) - 1
	elif selected and int(s.kt.get("golden_tickets", 0)) > 0:
		pass  # Pulled fairly; the ticket is kept for another week.
	# Regulars are on the lineup: no bucket for their scheduled Mondays.
	var regular := false
	for c in s.commitments:
		if str(c.get("kind", "")) == "kill_tony" and int(c["day"]) == day and bool(c.get("regular", false)):
			selected = true
			position = 1
			regular = true
	var forced: String = str(s.flags.get("dev_force_bucket", ""))
	if forced == "selected":
		selected = true
		position = maxi(position, 1) if position > 0 else 3
	elif forced == "not_selected":
		selected = false
		position = 0
	s.flags.erase("dev_force_bucket")
	var names: Array = []
	for i in range(pulls):
		names.append(_random_name(db, r))
	if selected:
		names[clampi(position - 1, 0, pulls - 1)] = "__player__"
	var d := {"day": day, "entrants": entrants, "pulls": pulls, "selected": selected, "position": position if selected else 0,
		"names": names, "golden": golden, "regular": regular, "forced": forced, "stage": "drawn", "resolved": false}
	draws[key] = d
	return d


static func set_band(score: float) -> String:
	if score < 45.0:
		return "low"
	if score < 70.0:
		return "mid"
	return "high"


static func _prompt_ok(s: GameState, p: Dictionary, band: String) -> bool:
	var c: Dictionary = p.get("conditions", {})
	if c.has("background") and str(s.player.get("background", "")) != str(c["background"]):
		return false
	if c.has("job") and not s.jobs.has(str(c["job"])):
		return false
	if c.has("hook"):
		var hooks: Array = s.player.get("hooks", [])
		if not hooks.has(str(c["hook"])):
			return false
	var apps: int = int(s.kt.get("appearances", 0))
	if c.has("min_appearances") and apps < int(c["min_appearances"]):
		return false
	if c.has("max_appearances") and apps > int(c["max_appearances"]):
		return false
	if c.has("min_day") and s.day < int(c["min_day"]):
		return false
	if c.has("set_band") and str(c["set_band"]) != band:
		return false
	return true


## Picks prompts: context-specific prompts first, then generic ones.
static func pick_prompts(s: GameState, db: ContentDB, set_score: float, r: RandomNumberGenerator) -> Array:
	var band := set_band(set_score)
	var specific: Array = []
	var generic: Array = []
	for p in db.interviews:
		if not _prompt_ok(s, p, band):
			continue
		if (p.get("conditions", {}) as Dictionary).is_empty():
			generic.append(p)
		else:
			specific.append(p)
	var out: Array = []
	var count := db.bali("interview.prompt_count", 3)
	for pool in [specific, generic]:
		var bag: Array = pool.duplicate()
		while out.size() < count and not bag.is_empty():
			var i := r.randi_range(0, bag.size() - 1)
			out.append(bag[i])
			bag.remove_at(i)
	return out


## Scores one response in context. Tone effectiveness depends on the prompt,
## on how the set went, and on repetition: no tone always wins.
static func score_response(db: ContentDB, prompt: Dictionary, response: Dictionary, set_score: float, tones_used: Array) -> Dictionary:
	var tone: String = str(response.get("tone", "honest"))
	var band := set_band(set_score)
	var by_set: Dictionary = db.bal("interview.tone_by_set_result", {}).get(band, {})
	var v := float(response.get("base", 0))
	v += float(prompt.get("tone_mods", {}).get(tone, 0))
	v += float(by_set.get(tone, 0))
	var repeats := tones_used.count(tone)
	v -= repeats * db.balf("interview.repeat_tone_penalty", 5.0)
	var reaction := "The panel laughs." if v >= 8.0 else ("A few chuckles from the panel." if v >= 3.0 else "The panel stares. The host moves on.")
	if repeats > 0 and v < 3.0:
		reaction = "They've seen that move from you already tonight."
	return {"value": v, "tone": tone, "reaction": reaction}


static func interview_score(db: ContentDB, values: Array) -> float:
	var total := 0.0
	for v in values:
		total += float(v)
	return clampf(db.balf("interview.base_score", 50.0) + total * db.balf("interview.score_scale", 1.6), 0.0, 100.0)


## Resolves outcomes. Each outcome is independent (not a ladder) and claimed
## exactly once with a stable claim id.
static func resolve_rewards(s: GameState, db: ContentDB, day: int, set_score: float, iv_score: float) -> Array:
	var out: Array = []
	var key := str(day)
	var R: Dictionary = db.bal("kill_tony_rewards", {})
	var r := s.rng("bucket")
	# Visibility always applies.
	if RewardRules.claim(s, "kt_%s_visibility" % key):
		var fame_gain := set_score * float(R.get("visibility_fame_scale", 0.15))
		var rep_gain := set_score * float(R.get("visibility_rep_scale", 0.08))
		s.fame += fame_gain
		s.reputation += rep_gain
		s.kt["appearances"] = int(s.kt.get("appearances", 0)) + 1
		out.append({"id": "visibility", "label": "Visibility", "text": "Thousands of people just watched your minute. Fame +%.1f, reputation +%.1f." % [fame_gain, rep_gain]})
	# Joke book: depends on the set, needs a passable interview.
	var book := ""
	if iv_score >= float(R.get("book_interview_min", 35)):
		if set_score >= float(R.get("large_book_min", 82)):
			book = "large_book"
		elif set_score >= float(R.get("medium_book_min", 70)):
			book = "medium_book"
		elif set_score >= float(R.get("small_book_min", 58)):
			book = "small_book"
	if book != "" and RewardRules.claim(s, "kt_%s_book" % key):
		RewardRules.grant_book(s, book)
		out.append({"id": book, "label": str(db.books[book]["name"]), "text": "%s Active writing capacity is now %d." % [db.partner.get("lines", {}).get("joke_book", "You get a joke book."), s.book_capacity(db)]})
	# Secret Show: depends on chemistry in the interview as much as the set.
	if set_score >= float(R.get("secret_show_set_min", 55)) and iv_score >= float(R.get("secret_show_interview_min", 55)):
		if RewardRules.claim(s, "kt_%s_secret_show" % key):
			var offer := OpportunityRules.create_offer(s, db, "opp_secret_show", day)
			Relationships.change(s, "partner_redban", {"familiarity": 6, "respect": 4})
			out.append({"id": "secret_show", "label": "Secret Show invitation", "text": "%s (%s)" % [db.partner.get("lines", {}).get("redban_invite", "You're invited to The Secret Show."), CalendarRules.describe_slot(int(offer.get("day", day)), int(offer.get("block", 2)))]})
	# Golden ticket: rare, needs both an exceptional set and interview.
	if set_score >= float(R.get("golden_ticket_set_min", 86)) and iv_score >= float(R.get("golden_ticket_interview_min", 65)):
		if r.randf() < float(R.get("golden_ticket_chance", 0.5)) and RewardRules.claim(s, "kt_%s_golden" % key):
			s.kt["golden_tickets"] = int(s.kt.get("golden_tickets", 0)) + int(db.bal("golden_ticket.uses", 1))
			out.append({"id": "golden_ticket", "label": "Golden ticket", "text": str(db.partner.get("lines", {}).get("golden_ticket", "Golden ticket!")) + " It guarantees you a future spot."})
	# Opening invitation from a panel guest whose style fits.
	if set_score >= float(R.get("opening_offer_set_min", 70)) and RewardRules.claim(s, "kt_%s_opening" % key):
		OpportunityRules.create_offer(s, db, "opp_kt_opening", day)
		out.append({"id": "opening_offer", "label": "Opening invitation", "text": str(db.partner.get("lines", {}).get("opening_offer", "A panel guest asks you to open."))})
	# Regular track: only progress is tracked; regular status needs an authored event.
	if set_score >= float(R.get("regular_track_set_min", 80)) and RewardRules.claim(s, "kt_%s_regular_progress" % key):
		s.kt["regular_progress"] = int(s.kt.get("regular_progress", 0)) + 1
		out.append({"id": "regular_progress", "label": "Noticed", "text": "The panel will remember you. (Regular-track progress %d/%d.)" % [int(s.kt["regular_progress"]), db.bali("regular.progress_needed", 3)]})
		if int(s.kt["regular_progress"]) >= db.bali("regular.progress_needed", 3) and not bool(s.flags.get("kt_regular", false)) and not bool(s.flags.get("kt_regular_declined", false)):
			s.flags["kt_regular_ready"] = true
	var draw: Dictionary = s.kt["draws"].get(key, {})
	if not draw.is_empty():
		draw["resolved"] = true
		draw["stage"] = "resolved"
		draw["set_score"] = set_score
		draw["interview_score"] = iv_score
	s.kt["history"].append({"day": day, "set_score": set_score, "interview": iv_score, "rewards": out.map(func(o): return o["id"])})
	return out


## Schedules the next regular spot (every other Monday) once regular status is on.
static func schedule_regular(s: GameState, db: ContentDB) -> String:
	if not bool(s.flags.get("kt_regular", false)):
		return ""
	if not s.flags.has("kt_regular_next_day"):
		s.flags["kt_regular_next_day"] = CalendarRules.next_weekday(s.day, CalendarRules.MONDAY)
	var next_day: int = int(s.flags["kt_regular_next_day"])
	if s.day < next_day:
		return ""
	s.flags["kt_regular_next_day"] = next_day + 14
	if next_day < s.day:
		return ""
	var c := {"kind": "kill_tony", "title": "Kill Tony (regular spot)", "day": next_day, "block": show_block(db), "length": 1,
		"location_id": "mothership", "venue_id": VENUE_ID, "slot_seconds": db.bali("bucket.set_seconds", 60), "pay": 0, "fee": 0, "npc": "partner_redban", "regular": true}
	var res := Scheduler.add(s, db, c, false)
	if not bool(res["ok"]):
		return "Your regular Kill Tony spot tonight conflicts with another booking. Sort it out, or you'll miss it."
	return "You're on the Kill Tony lineup tonight as a regular. Bring new material."


## Regulars must keep producing. Call BEFORE applying the performance (exposure
## is still the pre-show count). Returns a panel note.
static func regular_review(s: GameState, db: ContentDB, results: Array) -> String:
	if not bool(s.flags.get("kt_regular", false)) or results.is_empty():
		return ""
	var fresh := 0
	for r in results:
		var joke: Dictionary = s.jokes.get(str(r["joke_id"]), {})
		if int(joke.get("exposure", {}).get(VENUE_ID, 0)) == 0:
			fresh += 1
	var ratio := float(fresh) / results.size()
	if ratio >= 0.5:
		s.kt["regular_strikes"] = 0
		return "The panel notices the new material. That's what being a regular means."
	s.kt["regular_strikes"] = int(s.kt.get("regular_strikes", 0)) + 1
	if int(s.kt["regular_strikes"]) >= 3:
		s.flags["kt_regular"] = false
		s.flags.erase("kt_regular_next_day")
		return "The host, gently: 'We've heard this one.' After three recycled sets, you're off the regular lineup. The bucket's still there."
	return "The host: 'Didn't we hear this last time?' Regulars need new material. (Strike %d of 3.)" % int(s.kt["regular_strikes"])
