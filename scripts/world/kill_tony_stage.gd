extends Node3D
## Kill Tony night. Phase state lives in state.flags.active_kill_tony and the
## bucket_draw in state.kt.draws, both saved before anything is revealed, so a reload
## resumes the same night with the same outcome.
## Phases: waiting -> (not selected: watch) | minute -> set -> panel ->
## interview -> rewards -> return.

var s: GameState
var db: ContentDB
var night: Dictionary
var bucket_draw: Dictionary
var art: KtStage3D
var ui: UiLayer
var runner: PerformanceRunner
var sim: PerformanceSim
var caption: Label


func _ready() -> void:
	s = Game.state
	db = Game.db
	if s == null:
		Game.goto(Game.SCENE_BOOT)
		return
	night = s.flags.get("active_kill_tony", {})
	if night.is_empty():
		Game.goto(Game.SCENE_DISTRICT)
		return
	art = KtStage3D.new()
	art.layout = db.stage_layout
	art.partner = db.partner
	art.reduced = GameSettings.reduced_motion()
	var pa := PlayerActor.new()
	pa.configure(db, s)
	art.player_colors = pa.colors
	art.player_look = pa.look
	pa.free()
	add_child(art)
	ui = UiLayer.new()
	add_child(ui)
	caption = UiKit.label("", 24, Color("#ffe27a"))
	caption.position = Vector2(30, 20)
	caption.custom_minimum_size = Vector2(1200, 0)
	caption.add_theme_color_override("font_outline_color", Color.BLACK)
	caption.add_theme_constant_override("outline_size", 6)
	ui.root.add_child(caption)
	Sfx.play_music("band_loop")
	_frame("arrival", true)
	_resume()


func _frame(phase: String, instant: bool = false) -> void:
	art.frame(phase, instant)


func _save_phase(phase: String) -> void:
	night["phase"] = phase
	s.flags["active_kill_tony"] = night
	SaveManager.autosave()


## Tonight's guest panelists (fictional placeholders), chosen once and saved.
func _ensure_guests() -> void:
	if not night.has("guests"):
		var pool: Array = (db.partner.get("guest_pool", []) as Array).duplicate()
		var rng_count: Array = db.partner.get("panel_guest_count", [1, 3])
		var r := s.rng("bucket")
		var n := r.randi_range(int(rng_count[0]), int(rng_count[1]))
		if str(night.get("mode", "")) == "panel":
			n = mini(n, 2)  # The player takes one of the three guest seats.
		var picked: Array = []
		for i in range(mini(n, pool.size())):
			var k := r.randi_range(0, pool.size() - 1)
			picked.append(pool[k])
			pool.remove_at(k)
		night["guests"] = picked
		s.flags["active_kill_tony"] = night
	art.guests = night["guests"]


func _resume() -> void:
	_ensure_guests()
	if str(night.get("mode", "")) == "panel":
		_panel_start()
		return
	# The bucket_draw is created and saved before any reveal.
	bucket_draw = KillTonyRules.ensure_draw(s, db, int(night["day"]))
	SaveManager.autosave()
	match str(night.get("phase", "waiting")):
		"waiting":
			_waiting()
		"minute":
			_confirm_minute()
		"set":
			_start_set()
		"interview":
			_interview()
		"rewards":
			_rewards()
		_:
			_waiting()


# --- Bucket --------------------------------------------------------------

func _waiting() -> void:
	art.show_bucket = true
	art.player_at_mic = false
	caption.text = "Kill Tony · Comedy Mothership · %s" % CalendarRules.describe(s.day, s.block)
	var lines: Dictionary = db.partner.get("lines", {})
	if bool(bucket_draw.get("regular", false)):
		ui.dialog("Regular spot", GameSim.fmt(s, db, str(lines.get("regular_intro", "You're on the lineup tonight."))), [{"label": "Walk to the mic", "cb": func(): _goto_minute()}])
		return
	var body := "%s\n\nTonight: %d names in the bucket. %d will be pulled. Fame doesn't help; your slip is just a slip." % [lines.get("bucket_intro", ""), int(bucket_draw["entrants"]), int(bucket_draw["pulls"])]
	ui.dialog("The bucket", body, [{"label": "Watch the names get pulled", "cb": func(): _reveal(0)}])


func _reveal(i: int) -> void:
	var names: Array = bucket_draw["names"]
	if i >= names.size():
		_not_selected()
		return
	var n: String = str(names[i])
	if n == "__player__":
		Sfx.play("sting")
		art.reaction = 0.6
		art.band_cue = 1.0
		var golden := " (Your golden ticket guarantees this spot.)" if bool(bucket_draw.get("golden", false)) else ""
		ui.dialog("Name #%d" % (i + 1), "\"%s!\"\n\n%s%s" % [s.player.get("stage_name", ""), GameSim.fmt(s, db, str(db.partner.get("lines", {}).get("called_up", "Your name is called."))), golden], [{"label": "Walk to the mic", "cb": func(): _goto_minute()}])
		return
	ui.dialog("Name #%d" % (i + 1), "\"%s.\"\n\nA comic in a denim jacket jogs to the stage. You clap. You're still in the bucket..." % n if i < names.size() - 1 else "\"%s.\"\n\nThat's the last name." % n, [{"label": "Next name", "cb": func(): _reveal(i + 1)}])


func _not_selected() -> void:
	bucket_draw["stage"] = "watched"
	var lines: Dictionary = db.partner.get("lines", {})
	var gain := db.balf("bucket.watch_skill_gain", 0.5)
	StatsRules.add_skill(s, "delivery", gain)
	StatsRules.add_skill(s, "writing", gain * 0.5)
	var msg := "%s\n\nDelivery +%.1f, writing +%.1f from watching." % [lines.get("not_called", ""), gain, gain * 0.5]
	# Occasional networking, never a guaranteed consolation prize.
	var claim := "kt_%d_network" % int(night["day"])
	if RewardRules.claim(s, claim) and s.rng("world").randf() < db.balf("bucket.networking_chance", 0.25):
		var who := "deshawn" if s.rng("world").randf() < 0.5 else "lonnie"
		Relationships.change(s, who, {"familiarity": 4, "chemistry": 2})
		msg += "\n\nAfter the show you end up talking with %s outside. Good hang." % db.character_name(who)
	_end_night(msg)


# --- Set -------------------------------------------------------------------

func _goto_minute() -> void:
	_save_phase("minute")
	_confirm_minute()


func _confirm_minute() -> void:
	art.show_bucket = false
	art.player_at_mic = true
	_frame("arrival")
	caption.text = "One minute."
	var minute := SetRules.jokes_in(s, SetRules.KT_MINUTE_ID)
	var a := SetRules.analyze(s, db, minute, 60, KillTonyRules.VENUE_ID)
	var body := "Your prepared minute: %d joke(s), %ds (core %ds)." % [int(a["count"]), int(a["seconds"]), int(a["core_seconds"])]
	for w in a["warnings"]:
		body += "\n⚠ " + str(w)
	body += "\n\nGo past the minute and the band plays you off."
	var opts: Array = [{"label": "Do the prepared minute", "cb": func(): _choose_set(SetRules.KT_MINUTE_ID), "enabled": not minute.is_empty()}]
	var main := SetRules.jokes_in(s, SetRules.DEFAULT_ID)
	if not main.is_empty():
		opts.append({"label": "Do your open-mic set instead (%ds)" % int(SetRules.analyze(s, db, main, 60)["seconds"]), "cb": func(): _choose_set(SetRules.DEFAULT_ID)})
	if minute.is_empty() and main.is_empty():
		opts.append({"label": "Wing it with nothing", "cb": func(): _choose_set(SetRules.KT_MINUTE_ID)})
	ui.dialog("At the mic", body, opts)


func _choose_set(setlist_id: String) -> void:
	var res := GameSim.begin_performance(s, db, KillTonyRules.VENUE_ID, setlist_id, str(night["commitment_id"]))
	night["perf"] = res.get("context", {})
	_save_phase("set")
	_start_set()


func _start_set() -> void:
	art.player_at_mic = true
	art.show_bucket = false
	_frame("set")
	var ctx: Dictionary = night.get("perf", {})
	if ctx.is_empty():
		_confirm_minute()
		return
	sim = GameSim.build_sim(s, db, ctx)
	caption.text = "Kill Tony · your minute"
	runner = PerformanceRunner.new().setup(sim)
	runner.anchor_left = 0.5
	runner.anchor_right = 0.5
	runner.anchor_top = 1.0
	runner.anchor_bottom = 1.0
	runner.offset_left = -560
	runner.offset_right = 560
	runner.offset_top = -250
	runner.offset_bottom = -20
	ui.root.add_child(runner)
	runner.reacted.connect(_on_reacted)
	runner.finished.connect(_on_set_finished)


func _on_reacted(res: Dictionary) -> void:
	var score := float(res.get("score", 0))
	art.reaction = clampf((score - 40.0) / 40.0, -1.0, 1.0)
	art.panel_reaction = art.reaction
	if score >= 65.0:
		art.redban_cue = 1.0
	if score >= 80.0:
		Sfx.play("applause")
		art.band_cue = 1.0
	elif score >= 65.0:
		Sfx.play("big_laugh")
	elif score >= 45.0:
		Sfx.play("laugh")
	else:
		Sfx.play("silence")
	# Quick cut to the panel's reaction, then back to the mic.
	if not GameSettings.reduced_motion():
		_frame("panel")
		await get_tree().create_timer(0.9).timeout
		if is_instance_valid(sim) and not sim.ended:
			_frame("set")
	if sim.played_off:
		Sfx.play("playoff")
		art.band_cue = 1.0
		_frame("band")


func _on_set_finished(summary: Dictionary) -> void:
	var ctx: Dictionary = night.get("perf", {})
	var review := KillTonyRules.regular_review(s, db, summary["results"])
	GameSim.apply_performance(s, db, ctx, summary, false)
	night["set_score"] = float(summary["score"])
	night["set_tier"] = str(summary["tier_label"])
	night["suggestions"] = summary["suggestions"]
	runner.queue_free()
	runner = null
	# Panel reaction beat.
	_frame("panel")
	var band := KillTonyRules.set_band(float(summary["score"]))
	var reactions: Array = db.partner.get("lines", {}).get("panel_reactions", {}).get(band, ["The panel reacts."])
	var line: String = str(reactions[int(float(summary["score"])) % reactions.size()])
	art.panel_reaction = 1.0 if band == "high" else (0.3 if band == "mid" else -0.5)
	# Pick and store interview prompts before showing any.
	var prompts := KillTonyRules.pick_prompts(s, db, float(summary["score"]), s.rng("performance"))
	night["prompts"] = prompts.map(func(p): return str(p["id"]))
	night["answers"] = []
	night["tones"] = []
	_save_phase("interview")
	var played_off := " The band played you off." if bool(summary.get("played_off", false)) else ""
	if review != "":
		line += "\n\n" + review
	ui.dialog("The panel", "%s  ·  %d/100.%s\n\n%s" % [summary["tier_label"], int(float(summary["score"])), played_off, line], [{"label": "%s waves you over to talk" % db.character_name("partner_host"), "cb": func(): _interview()}])


# --- Interview --------------------------------------------------------------

func _prompt_by_id(id: String) -> Dictionary:
	for p in db.interviews:
		if str(p["id"]) == id:
			return p
	return {}


func _interview() -> void:
	art.player_at_mic = true
	_frame("interview")
	caption.text = "Interview"
	var ids: Array = night.get("prompts", [])
	var answers: Array = night.get("answers", [])
	if answers.size() >= ids.size():
		_save_phase("rewards")
		_rewards()
		return
	var p := _prompt_by_id(str(ids[answers.size()]))
	var opts: Array = []
	for r in p.get("responses", []):
		var resp: Dictionary = r
		opts.append({"label": str(resp["text"]), "cb": func(): _answer(p, resp)})
	ui.dialog("%s asks:" % db.character_name("partner_host"), "\"%s\"" % p.get("text", ""), opts)


func _answer(p: Dictionary, resp: Dictionary) -> void:
	var tones: Array = night.get("tones", [])
	var res := KillTonyRules.score_response(db, p, resp, float(night.get("set_score", 0.0)), tones)
	tones.append(res["tone"])
	var answers: Array = night.get("answers", [])
	answers.append(float(res["value"]))
	night["tones"] = tones
	night["answers"] = answers
	art.panel_reaction = clampf(float(res["value"]) / 10.0, -1.0, 1.0)
	if float(res["value"]) >= 8.0:
		Sfx.play("laugh")
	_save_phase("interview")
	ui.dialog("", str(res["reaction"]), [{"label": "Continue", "cb": func(): _interview()}])


# --- Rewards ------------------------------------------------------------------

func _rewards() -> void:
	_frame("reward")
	caption.text = "After the interview"
	var iv := KillTonyRules.interview_score(db, night.get("answers", []))
	var set_score := float(night.get("set_score", 0.0))
	var out := KillTonyRules.resolve_rewards(s, db, int(night["day"]), set_score, iv)
	var body := "Set: %d/100 (%s) · Interview: %d/100\n" % [int(set_score), night.get("set_tier", ""), int(iv)]
	if out.is_empty():
		body += "\n(Already resolved.)"
	for o in out:
		body += "\n• %s: %s" % [o["label"], o["text"]]
	for sg in night.get("suggestions", []):
		body += "\n\nPanel note: " + str(sg)
	Sfx.play("applause")
	art.reaction = 0.8
	_end_night(body)


func _end_night(body: String) -> void:
	var cid: String = str(night.get("commitment_id", ""))
	if cid != "":
		Scheduler.mark_done(s, cid)
	s.flags.erase("active_kill_tony")
	var notes := GameSim.advance(s, db, 1)
	if not notes.is_empty():
		body += "\n\n" + "\n".join(PackedStringArray(notes))
	SaveManager.autosave()
	Game.notify()
	ui.dialog("Kill Tony", body, [{"label": "Head back out into the night", "cb": _leave}])


func _leave() -> void:
	Sfx.stop_music()
	Game.goto(Game.SCENE_DISTRICT)


# --- Panel guest (Phase 5) ------------------------------------------------------

func _panel_start() -> void:
	art.show_bucket = false
	art.player_at_mic = false
	art.player_at_panel_seat = 0
	if not night.has("comics"):
		night["comics"] = PanelRules.generate(s, db, 3)
		night["idx"] = 0
		night["total"] = 0.0
		night["tones"] = []
		night["step"] = "intro"
		_save_phase("panel")
	_panel_step()


func _panel_save(step: String) -> void:
	night["step"] = step
	_save_phase("panel")


func _panel_step() -> void:
	var comics: Array = night["comics"]
	var i: int = int(night["idx"])
	if str(night["step"]) == "intro":
		_frame("panel")
		caption.text = "Kill Tony · you're on the panel"
		ui.dialog("Panel guest", GameSim.fmt(s, db, str(db.partner.get("lines", {}).get("panel_intro", ""))), [{"label": "Pull the first name", "cb": func():
			_panel_save("walkup")
			_panel_step()}])
		return
	if i >= comics.size():
		_panel_end()
		return
	var c: Dictionary = comics[i]
	art.guest_color = Color(str(c["color"]))
	art.guest_at_mic = true
	var persona: Dictionary = db.panel_comics.get("personas", {}).get(str(c["persona"]), {})
	match str(night["step"]):
		"walkup":
			_frame("arrival")
			caption.text = "Bucket pull #%d: %s" % [i + 1, c["name"]]
			ui.dialog("Bucket pull #%d" % (i + 1), "\"%s!\" %s" % [c["name"], persona.get("desc", "")], [{"label": "Watch their minute", "cb": func():
				_panel_save("set")
				_panel_step()}])
		"set":
			_frame("set")
			var q: int = int(c["quality"])
			art.reaction = clampf((q - 40.0) / 40.0, -1.0, 1.0)
			Sfx.play("applause" if q >= 75 else ("laugh" if q >= 45 else "silence"))
			var opts: Array = []
			for rx in PanelRules.REACTIONS:
				var rxc: String = rx
				opts.append({"label": str(PanelRules.REACTION_LABELS[rx]), "cb": func(): _panel_react(c, rxc)})
			ui.dialog("%s's minute" % c["name"], "%s does %s (%s style).\n\n%s\n\nHow do you react?" % [c["name"], c["bit"], str(c["style"]).replace("_", "-"), PanelRules.crowd_reaction(q)], opts)
		"interview":
			_frame("interview")
			var opts2: Array = []
			var tones: Dictionary = db.panel_comics.get("tones", {})
			for tone in tones:
				var tn: String = tone
				opts2.append({"label": str(tones[tone]), "cb": func(): _panel_contribute(c, tn)})
			ui.dialog("Interview", "%s asks %s about their life. They're %s.\n\n%s turns to you: \"Anything for them?\"" % [db.character_name("partner_host"), c["name"], str(persona.get("label", "")).to_lower(), db.character_name("partner_host")], opts2)
		"scout":
			if PanelRules.can_scout(c):
				ui.dialog("Talent", "%s has something. You could ask them to open for you on the road." % c["name"], [
					{"label": "Ask them to open for you", "cb": func():
						PanelRules.scout(s, c)
						_panel_next()},
					{"label": "Not tonight", "cb": func(): _panel_next()}])
			else:
				_panel_next()


func _panel_react(c: Dictionary, rx: String) -> void:
	var r := PanelRules.score_reaction(c, rx)
	night["total"] = float(night["total"]) + float(r["value"])
	art.panel_reaction = clampf(float(r["value"]) / 6.0, -1.0, 1.0)
	if float(r["value"]) >= 4.0:
		art.redban_cue = 1.0
	_panel_save("interview")
	ui.dialog("", str(r["text"]), [{"label": "On to the interview", "cb": func(): _panel_step()}])


func _panel_contribute(c: Dictionary, tone: String) -> void:
	var tones: Array = night.get("tones", [])
	var r := PanelRules.score_contribution(s, db, c, tone, tones)
	tones.append(tone)
	night["tones"] = tones
	night["total"] = float(night["total"]) + float(r["value"])
	art.reaction = clampf(float(r["value"]) / 8.0, -1.0, 1.0)
	if float(r["value"]) >= 7.0:
		Sfx.play("big_laugh")
	_panel_save("scout")
	ui.dialog("", str(r["text"]), [{"label": "Continue", "cb": func(): _panel_step()}])


func _panel_next() -> void:
	night["idx"] = int(night["idx"]) + 1
	art.guest_at_mic = false
	_panel_save("walkup")
	_panel_step()


func _panel_end() -> void:
	art.guest_at_mic = false
	_frame("reward")
	var total := float(night.get("total", 0.0))
	var notes := PanelRules.resolve(s, db, int(night["day"]), total)
	var body := "Panel score: %d.\n\n%s" % [int(total), "\n".join(PackedStringArray(notes))]
	if not s.discovered_openers.is_empty():
		body += "\n\nScouted openers on your list: %d." % s.discovered_openers.size()
	_end_night(body)
