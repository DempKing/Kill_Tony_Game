class_name PerformanceSim
extends RefCounted
## Decision-based standup performance. Seeded and explainable: every joke's
## score is a sum of named factors, recorded for feedback and the developer
## inspector. Same seed + same choices => same result.
##
## Flow: perform_next() delivers the next joke -> available_choices() ->
## choose(id) -> repeat until has_next() is false or the set ends -> finish().

var db: ContentDB
var venue: Dictionary = {}
var audience: Dictionary = {}
var slot_seconds: int = 180
var queue: Array = []
var results: Array = []
var elapsed: float = 0.0
var momentum: float = 0.0
var bonus: float = 0.0
var overrun_penalty: float = 0.0
var choices_log: Array = []
var rng := RandomNumberGenerator.new()
var perf_seed: int = 0
var ctx: Dictionary = {}
var ended: bool = false
var played_off: bool = false
var crowd_work_used: bool = false
var awaiting_choice: bool = false
var last: Dictionary = {}
var notes: Array = []          # narrative beats for display
var performed_families: Array = []
var good_families: Array = []


## Builds a performance from game state. Jokes are snapshotted (revision
## included) so later rewrites never alter this performance's record.
static func build(s: GameState, content: ContentDB, venue_id: String, joke_ids: Array, seed_value: int, slot_override: int = 0, audience_override: String = "") -> PerformanceSim:
	var p := PerformanceSim.new()
	p.db = content
	p.venue = content.venues.get(venue_id, {})
	var aud_id: String = audience_override if audience_override != "" else str(p.venue.get("audience", "open_mic_regulars"))
	if audience_override == "" and s.block == 3 and p.venue.has("late_audience"):
		aud_id = str(p.venue["late_audience"])
	p.audience = content.audiences.get(aud_id, {})
	p.slot_seconds = slot_override if slot_override > 0 else int(p.venue.get("slot_seconds", 180))
	p.perf_seed = seed_value
	p.rng.seed = seed_value
	p.ctx = {
		"delivery": StatsRules.skill(s, "delivery"),
		"crowd_work": StatsRules.skill(s, "crowd_work"),
		"stage_presence": StatsRules.skill(s, "stage_presence"),
		"writing": StatsRules.skill(s, "writing"),
		"confidence": float(s.confidence),
		"energy": float(s.energy),
		"stress": float(s.stress),
		"style": str(s.player.get("style", "observational")),
		"style2": str(s.player.get("secondary_style", "")),
		"venue_id": venue_id,
	}
	for jid in joke_ids:
		var joke: Dictionary = s.jokes.get(str(jid), {})
		if joke.is_empty():
			continue
		var rev := JokeRules.current_revision(joke)
		var parts: Dictionary = rev.get("parts", {})
		if JokeRules.evaluate(content, parts)["status"] == "missing":
			continue
		p.queue.append(p._snapshot(joke, rev, parts))
	return p


func _snapshot(joke: Dictionary, rev: Dictionary, parts: Dictionary) -> Dictionary:
	var lines: Array = []
	for part in ["setup", "punchline"]:
		lines.append(str(db.component(str(parts[part])).get("text", "")))
	var tag_id: String = str(parts.get("tag", ""))
	var ao_id: String = str(parts.get("act_out", ""))
	var cb_id: String = str(parts.get("callback", ""))
	return {
		"joke_id": str(joke["id"]),
		"rev": int(rev.get("rev", 1)),
		"title": str(joke["title"]),
		"quality": JokeRules.quality_of_parts(db, parts, int(rev.get("polish", 0))),
		"coherence": str(JokeRules.evaluate(db, parts)["status"]),
		"core_seconds": JokeRules.seconds_of_parts(db, parts, false),
		"familiarity": float(joke.get("familiarity", 0)),
		"exposure": int(joke.get("exposure", {}).get(str(ctx["venue_id"]), 0)),
		"difficulty": JokeRules.stat_avg(db, parts, "difficulty"),
		"originality": JokeRules.stat_avg(db, parts, "originality"),
		"topics": JokeRules.topics_of(db, parts),
		"styles": JokeRules.styles_of(db, parts),
		"family": str(db.component(str(parts["premise"])).get("family", "")),
		"lines": lines,
		"tag": db.component(tag_id) if tag_id != "" else {},
		"act_out": db.component(ao_id) if ao_id != "" else {},
		"callback": db.component(cb_id) if cb_id != "" else {},
	}


func has_next() -> bool:
	return not ended and queue.size() > 0


func is_kill_tony() -> bool:
	return str(venue.get("kind", "")) == "kill_tony"


func _b(path: String, fallback: float) -> float:
	return db.balf("performance." + path, fallback)


func delivery_value(familiarity: float) -> float:
	var mix: Dictionary = db.bal("performance.delivery_mix", {})
	return (float(ctx["delivery"]) * float(mix.get("delivery", 0.35))
		+ familiarity * float(mix.get("familiarity", 0.3))
		+ float(ctx["confidence"]) * float(mix.get("confidence", 0.2))
		+ float(ctx["stage_presence"]) * float(mix.get("stage_presence", 0.15)))


func _style_matches(st: Array) -> bool:
	return st.has(str(ctx["style"])) or (str(ctx["style2"]) != "" and st.has(str(ctx["style2"])))


## Computes the factor breakdown for a joke without consuming randomness.
func factors_for(j: Dictionary) -> Dictionary:
	var f: Dictionary = {}
	f["material"] = float(j["quality"]) * _b("material_weight", 0.55)
	f["delivery"] = delivery_value(float(j["familiarity"])) * _b("delivery_weight", 0.45)
	f["warmth"] = float(audience.get("warmth", 40)) * _b("warmth_weight", 0.35)
	# Audience fit: topic and style preferences.
	var fit := 0.0
	var prefs: Dictionary = audience.get("topic_prefs", {})
	for t in j["topics"]:
		fit += float(prefs.get(t, 0))
	var sprefs: Dictionary = audience.get("style_prefs", {})
	for st in j["styles"]:
		fit += float(sprefs.get(st, 0)) * 0.5
	if _style_matches(j["styles"]):
		fit += _b("style_match_bonus", 3.0)
	var se: Dictionary = db.bal("styles_effects", {})
	var style: String = str(ctx["style"])
	if style == "observational":
		for t in j["topics"]:
			if se.get("observational", {}).get("topic_bonus_topics", []).has(t):
				fit += float(se["observational"].get("topic_bonus", 2.0))
				break
	if style == "storytelling" and int(j["core_seconds"]) >= int(se.get("storytelling", {}).get("long_joke_seconds", 30)):
		fit += float(se["storytelling"].get("long_joke_bonus", 3.0))
	var ow: float = float(audience.get("originality_weight", 0.0))
	if style == "absurdist":
		ow += float(se.get("absurdist", {}).get("originality_bonus", 0.6))
	fit += (float(j["originality"]) - 5.0) * ow
	var clamp_v := _b("fit_clamp", 12.0)
	f["fit"] = clampf(fit, -clamp_v, clamp_v)
	f["momentum"] = momentum
	# Exposure: rooms that have heard the joke react less.
	var n: int = int(j["exposure"])
	if bool(audience.get("regulars", false)):
		f["exposure"] = -minf(n * _b("exposure_regulars_per", 6.0), _b("exposure_regulars_cap", 18.0))
	else:
		f["exposure"] = -minf(n * _b("exposure_general_per", 2.0), _b("exposure_general_cap", 6.0))
	# Difficulty: hard material needs delivery and familiarity to land.
	var capability := float(ctx["delivery"]) + float(j["familiarity"]) * 0.5
	f["difficulty"] = -maxf(0.0, float(j["difficulty"]) * 10.0 - capability) * _b("difficulty_per_point", 0.15)
	# Condition: fatigue and stress.
	var cond := 0.0
	var e_thr := _b("fatigue_energy_threshold", 40)
	if float(ctx["energy"]) < e_thr:
		cond -= (e_thr - float(ctx["energy"])) * _b("fatigue_per_point", 0.3)
	var s_thr := _b("stress_threshold", 50)
	if float(ctx["stress"]) > s_thr:
		cond -= (float(ctx["stress"]) - s_thr) * _b("stress_per_point", 0.3)
	f["condition"] = cond
	# Act-out and callback extras (part of the joke if included).
	var extra := 0.0
	var ao: Dictionary = j["act_out"]
	if not ao.is_empty():
		if float(ctx["energy"]) >= _b("act_out_energy_min", 50):
			extra += float(ao.get("quality", 5)) * _b("act_out_bonus_per_quality", 1.5)
			if style == "high_energy":
				extra += float(se.get("high_energy", {}).get("act_out_bonus", 4.0))
		else:
			extra -= _b("act_out_low_energy_penalty", 5.0)
	var cb: Dictionary = j["callback"]
	if not cb.is_empty():
		var ref: String = str(cb.get("callback_ref", ""))
		if good_families.has(ref):
			extra += float(cb.get("quality", 5)) * _b("callback_bonus_per_quality", 1.5)
		else:
			extra -= _b("callback_missing_penalty", 6.0)
	f["extras"] = extra
	return f


func response_for(score: float) -> Dictionary:
	var tiers: Array = db.bal("performance.response_tiers", [])
	var out: Dictionary = {"id": "silence", "label": "Silence"}
	for t in tiers:
		if score >= float(t["min"]):
			out = t
	return out


func perform_next() -> Dictionary:
	if not has_next():
		return {}
	var j: Dictionary = queue.pop_front()
	var f := factors_for(j)
	var rr := _b("random_range", 12.0)
	f["luck"] = rng.randf_range(-rr, rr)
	var score := 0.0
	for k in f:
		score += float(f[k])
	score = clampf(score, 0.0, 100.0)
	var secs: float = float(j["core_seconds"])
	var ao: Dictionary = j["act_out"]
	if not ao.is_empty():
		secs += float(ao.get("seconds", 0))
	var cb: Dictionary = j["callback"]
	if not cb.is_empty():
		secs += float(cb.get("seconds", 0))
	elapsed += secs
	var resp := response_for(score)
	var res: Dictionary = {
		"joke_id": j["joke_id"], "rev": j["rev"], "title": j["title"], "lines": j["lines"],
		"score": score, "response": resp["id"], "response_label": resp["label"],
		"factors": f, "tag": j["tag"], "tag_used": false, "tag_score": 0.0,
		"family": j["family"], "seconds": secs, "position": results.size(), "topics": j["topics"],
	}
	results.append(res)
	performed_families.append(j["family"])
	if score >= 45.0:
		good_families.append(j["family"])
	# Momentum drifts toward the response.
	momentum = clampf(momentum + (score - 50.0) * 0.15, -_b("momentum_clamp", 20.0), _b("momentum_clamp", 20.0))
	last = res
	_check_overrun()
	awaiting_choice = not ended
	return res


func _check_overrun() -> void:
	var grace := slot_seconds * _b("overrun_grace_fraction", 0.1)
	if is_kill_tony():
		grace = db.balf("bucket.play_off_after_seconds", 10.0)
	if elapsed > slot_seconds + grace:
		overrun_penalty += _b("overrun_penalty_per_joke", 8.0)
		if is_kill_tony():
			played_off = true
			ended = true
			notes.append("The band plays you off.")
		else:
			notes.append("The light has been on for a while. The host is glaring.")


func time_left() -> float:
	return slot_seconds - elapsed


## Choices offered after the last joke. Every option has a distinct mechanical
## effect described in its hint.
func available_choices() -> Array:
	if ended or last.is_empty():
		return []
	var c := db.bal("performance.choices", {}) as Dictionary
	var good := float(c.get("good_threshold", 55))
	var bad := float(c.get("bad_threshold", 45))
	var score: float = float(last["score"])
	var out: Array = []
	var has_tag: bool = not (last["tag"] as Dictionary).is_empty() and not bool(last["tag_used"])
	if score >= good:
		out.append({"id": "pause", "label": "Pause for the laugh", "hint": "Let it land. Builds momentum; risky if the laugh is smaller than it feels. (+4s)"})
		out.append({"id": "continue", "label": "Keep rolling", "hint": "Ride the energy into the next bit."})
	elif score < bad:
		out.append({"id": "acknowledge", "label": "Acknowledge it", "hint": "Comment on the silence. Stage presence and a deadpan or self-deprecating style help. (+5s)"})
		out.append({"id": "push", "label": "Push through", "hint": "Pretend it worked. Costs momentum, saves time."})
		out.append({"id": "crowd", "label": "Try crowd work", "hint": "High risk, high reward. Depends on crowd-work skill and this audience. (+15s)"})
		if queue.size() > 1:
			out.append({"id": "recover", "label": "Go to your most reliable bit", "hint": "Jump to your safest remaining joke next."})
	else:
		out.append({"id": "continue", "label": "Keep rolling", "hint": "Move on to the next bit."})
		out.append({"id": "crowd", "label": "Try crowd work", "hint": "Could turn a lukewarm room. (+15s)"})
	if has_tag:
		var tag: Dictionary = last["tag"]
		out.append({"id": "tag", "label": "Add the tag", "hint": "\"%s\" (+%ds). Better when the joke landed." % [str(tag.get("text", "")), int(tag.get("seconds", 0))]})
	if queue.size() > 0 and elapsed + float(queue[0]["core_seconds"]) > slot_seconds:
		out.append({"id": "end_strong", "label": "Skip to your closer", "hint": "You're nearly out of time. Drop everything but the last joke."})
	if results.size() > 0 and (queue.size() == 0 or time_left() < 15.0):
		out.append({"id": "end_now", "label": "Say goodnight", "hint": "End the set right here."})
	return out


func choose(choice_id: String) -> Dictionary:
	if not awaiting_choice:
		return {"message": ""}
	awaiting_choice = false
	var c := db.bal("performance.choices", {}) as Dictionary
	var msg := ""
	var score: float = float(last["score"])
	var mclamp := _b("momentum_clamp", 20.0)
	var se: Dictionary = db.bal("styles_effects", {})
	match choice_id:
		"pause":
			elapsed += float(c.get("pause_seconds", 4))
			if score < float(c.get("pause_risk_below", 65)) and rng.randf() < float(c.get("pause_risk_chance", 0.35)):
				momentum -= 4.0
				bonus -= 2.0
				msg = "You wait for a laugh that's already over. Dead air."
			else:
				momentum += 6.0
				bonus += (score - 55.0) * 0.3 + 2.0
				msg = "You let it breathe. The laugh rolls a little longer."
		"continue":
			momentum += 3.0 if score >= 55.0 else 0.0
			msg = "You keep it moving."
		"push":
			momentum -= 6.0
			msg = "You push on. The room is still thinking about the last one."
		"acknowledge":
			elapsed += float(c.get("acknowledge_seconds", 5))
			var style_bonus := 0.0
			for st in ["deadpan", "self_deprecating"]:
				if str(ctx["style"]) == st or str(ctx["style2"]) == st:
					style_bonus = maxf(style_bonus, float(se.get(st, {}).get("acknowledge_bonus", 15.0)))
			var roll := float(ctx["stage_presence"]) * 0.6 + style_bonus + rng.randf_range(-20.0, 20.0)
			if roll >= float(c.get("acknowledge_target", 30)):
				momentum = maxf(momentum, 0.0) + 4.0
				bonus += 3.0
				msg = "\"Yeah, that one's still in development.\" It gets a real laugh."
			else:
				momentum -= 3.0
				msg = "You comment on the silence. The silence agrees."
		"crowd":
			crowd_work_used = true
			elapsed += float(c.get("crowd_seconds", 15))
			var roll2 := float(ctx["crowd_work"]) * 0.7 + float(audience.get("crowdwork", 0.4)) * 40.0 + rng.randf_range(-25.0, 25.0)
			if roll2 >= float(c.get("crowd_target", 45)):
				momentum += 8.0
				bonus += 6.0
				msg = "You find a guy in the front row with a great answer. The room wakes up."
			else:
				momentum -= 8.0
				bonus -= 4.0
				msg = "You ask the front row where they're from. They don't want to say."
		"recover":
			var best_i := -1
			var best_v := -1.0
			for i in range(queue.size()):
				var q: Dictionary = queue[i]
				var v := float(q["quality"]) * 0.6 + float(q["familiarity"]) * 0.4
				if v > best_v:
					best_v = v
					best_i = i
			if best_i > 0:
				var pick: Dictionary = queue[best_i]
				queue.remove_at(best_i)
				queue.push_front(pick)
			momentum -= 2.0
			msg = "You skip ahead to the bit you trust most."
		"tag":
			var tag: Dictionary = last["tag"]
			elapsed += float(tag.get("seconds", 0))
			var t := float(tag.get("quality", 5)) * 8.0 + momentum * 0.5 + float(last["factors"]["delivery"]) * 0.3 + (score - 50.0) * 0.4 + rng.randf_range(-10.0, 10.0)
			last["tag_used"] = true
			last["tag_score"] = t
			if t >= 50.0:
				bonus += (t - 50.0) * 0.25 + 2.0
				momentum += 5.0
				msg = "The tag hits. Bigger than the punchline."
			else:
				bonus -= 3.0
				momentum -= 5.0
				msg = "The tag lands on nobody."
			_check_overrun()
		"end_strong":
			if queue.size() > 1:
				var closer: Dictionary = queue.back()
				queue.clear()
				queue.append(closer)
			bonus += 2.0
			msg = "You cut straight to your closer."
		"end_now":
			ended = true
			queue.clear()
			if score >= 55.0:
				bonus += 3.0
				msg = "You leave them wanting more. Goodnight!"
			else:
				msg = "\"That's my time.\" Scattered, polite applause."
		_:
			msg = ""
	momentum = clampf(momentum, -mclamp, mclamp)
	choices_log.append({"after": results.size() - 1, "choice": choice_id, "message": msg})
	if msg != "":
		notes.append(msg)
	return {"message": msg}


func set_score() -> float:
	if results.is_empty():
		return 0.0
	var total := 0.0
	var weight := 0.0
	for i in range(results.size()):
		var w := 1.0
		if i == 0:
			w = _b("opener_weight", 1.2)
		if i == results.size() - 1 and results.size() > 1:
			w = _b("closer_weight", 1.5)
		total += float(results[i]["score"]) * w
		weight += w
	var bc := _b("bonus_clamp", 15.0)
	return clampf(total / weight + clampf(bonus, -bc, bc) - overrun_penalty, 0.0, 100.0)


func tier_for(score: float) -> Dictionary:
	var tiers: Array = db.bal("performance.set_tiers", [])
	var out: Dictionary = {"id": "bombed", "label": "Bombed"}
	for t in tiers:
		if score >= float(t["min"]):
			out = t
	return out


## Builds explainable feedback from the recorded factors.
func finish() -> Dictionary:
	ended = true
	var score := set_score()
	var tier := tier_for(score)
	var best: Dictionary = {}
	var worst: Dictionary = {}
	for r in results:
		if best.is_empty() or float(r["score"]) > float(best["score"]):
			best = r
		if worst.is_empty() or float(r["score"]) < float(worst["score"]):
			worst = r
	var suggestions: Array = []
	for r in results:
		var s := suggestion_for(r)
		if s != "" and not suggestions.has(s):
			suggestions.append(s)
	if overrun_penalty > 0.0:
		suggestions.append("You ran past the light. Trim setups or skip tags when time is short.")
	if not results.is_empty() and elapsed < slot_seconds * 0.5 and not played_off:
		suggestions.append("You used %ds of a %ds slot. More tested material would fill it." % [int(elapsed), slot_seconds])
	if results.is_empty():
		suggestions.append("You had nothing coherent to perform. Build a complete joke in your journal first.")
	return {
		"score": score,
		"tier": tier["id"],
		"tier_label": tier["label"],
		"results": results,
		"best": best,
		"worst": worst if results.size() > 1 else {},
		"suggestions": suggestions.slice(0, 4),
		"elapsed": elapsed,
		"slot_seconds": slot_seconds,
		"played_off": played_off,
		"crowd_work_used": crowd_work_used,
		"choices": choices_log,
		"seed": perf_seed,
		"bonus": bonus,
		"overrun_penalty": overrun_penalty,
		"venue_id": str(venue.get("id", "")),
		"audience_id": str(audience.get("id", "")),
	}


## Picks the factor with the largest shortfall and maps it to advice.
func suggestion_for(r: Dictionary) -> String:
	var f: Dictionary = r["factors"]
	var title: String = str(r["title"])
	var shortfalls: Dictionary = {
		"material": 30.0 - float(f.get("material", 0)),
		"delivery": 14.0 - float(f.get("delivery", 0)),
		"fit": -float(f.get("fit", 0)) - 2.0,
		"exposure": -float(f.get("exposure", 0)) - 3.0,
		"difficulty": -float(f.get("difficulty", 0)) - 2.0,
		"condition": -float(f.get("condition", 0)) - 2.0,
		"extras": -float(f.get("extras", 0)) - 1.0,
	}
	var worst_k := ""
	var worst_v := 0.0
	for k in shortfalls:
		if float(shortfalls[k]) > worst_v:
			worst_v = float(shortfalls[k])
			worst_k = k
	if float(r["score"]) >= 65.0 and worst_v < 8.0:
		return ""
	match worst_k:
		"material":
			return "\"%s\": the writing is thin. Polish it, or develop a stronger punchline." % title
		"delivery":
			return "\"%s\": the delivery wasn't there. Rehearse it until it's automatic." % title
		"fit":
			return "\"%s\": wrong room. This audience doesn't care about %s." % [title, ", ".join(PackedStringArray(_neg_topics(r)))]
		"exposure":
			return "\"%s\": this crowd has heard it before. Bring something new here." % title
		"difficulty":
			return "\"%s\": the bit is harder than your current skill. More reps first." % title
		"condition":
			return "You were exhausted or stressed. Rest before shows."
		"extras":
			return "\"%s\": the act-out or callback fell flat. Check energy and set order." % title
	return ""


func _neg_topics(r: Dictionary) -> Array:
	var out: Array = []
	var prefs: Dictionary = audience.get("topic_prefs", {})
	for t in r.get("topics", []):
		if float(prefs.get(t, 0)) < 0.0:
			out.append(str(t))
	if out.is_empty():
		out.append("this kind of bit")
	return out
