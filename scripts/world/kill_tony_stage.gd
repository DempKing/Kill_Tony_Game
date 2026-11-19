extends Node2D
## Kill Tony night. Phase state lives in state.flags.active_kill_tony and the
## draw in state.kt.draws, both saved before anything is revealed, so a reload
## resumes the same night with the same outcome.
## Phases: waiting -> (not selected: watch) | minute -> set -> panel ->
## interview -> rewards -> return.

var s: GameState
var db: ContentDB
var night: Dictionary
var draw: Dictionary
var art: KtStageArt
var cam: Camera2D
var ui: UiLayer
var runner: PerformanceRunner
var sim: PerformanceSim
var caption: Label
var _cam_tween: Tween


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
	art = KtStageArt.new()
	art.layout = db.stage_layout
	art.partner = db.partner
	art.reduced = GameSettings.reduced_motion()
	var pa := PlayerActor.new()
	pa.configure(db, s)
	art.player_colors = pa.colors
	pa.free()
	add_child(art)
	cam = Camera2D.new()
	add_child(cam)
	cam.make_current()
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
	var c := art.camera_for(phase)
	if instant or GameSettings.reduced_motion():
		cam.position = c["center"]
		cam.zoom = Vector2.ONE * float(c["zoom"])
		return
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	_cam_tween = create_tween().set_parallel(true)
	_cam_tween.tween_property(cam, "position", c["center"], 0.8).set_trans(Tween.TRANS_SINE)
	_cam_tween.tween_property(cam, "zoom", Vector2.ONE * float(c["zoom"]), 0.8).set_trans(Tween.TRANS_SINE)


func _save_phase(phase: String) -> void:
	night["phase"] = phase
	s.flags["active_kill_tony"] = night
	SaveManager.autosave()


func _resume() -> void:
	# The draw is created and saved before any reveal.
	draw = KillTonyRules.ensure_draw(s, db, int(night["day"]))
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
	var body := "%s\n\nTonight: %d names in the bucket. %d will be pulled. Fame doesn't help; your slip is just a slip." % [lines.get("bucket_intro", ""), int(draw["entrants"]), int(draw["pulls"])]
	ui.dialog("The bucket", body, [{"label": "Watch the names get pulled", "cb": func(): _reveal(0)}])


func _reveal(i: int) -> void:
	var names: Array = draw["names"]
	if i >= names.size():
		_not_selected()
		return
	var n: String = str(names[i])
	if n == "__player__":
		Sfx.play("sting")
		art.reaction = 0.6
		art.band_cue = 1.0
		var golden := " (Your golden ticket guarantees this spot.)" if bool(draw.get("golden", false)) else ""
		ui.dialog("Name #%d" % (i + 1), "\"%s!\"\n\n%s%s" % [s.player.get("stage_name", ""), db.partner.get("lines", {}).get("called_up", "Your name is called."), golden], [{"label": "Walk to the mic", "cb": func(): _goto_minute()}])
		return
	ui.dialog("Name #%d" % (i + 1), "\"%s.\"\n\nA comic in a denim jacket jogs to the stage. You clap. You're still in the bucket..." % n if i < names.size() - 1 else "\"%s.\"\n\nThat's the last name." % n, [{"label": "Next name", "cb": func(): _reveal(i + 1)}])


func _not_selected() -> void:
	draw["stage"] = "watched"
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
	runner.offset_top = -330
	runner.offset_bottom = -20
	ui.root.add_child(runner)
	runner.reacted.connect(_on_reacted)
	runner.finished.connect(_on_set_finished)


func _on_reacted(res: Dictionary) -> void:
	var score := float(res.get("score", 0))
	art.reaction = clampf((score - 40.0) / 40.0, -1.0, 1.0)
	art.panel_reaction = art.reaction
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
	ui.dialog("The panel", "%s  ·  %d/100.%s\n\n%s" % [summary["tier_label"], int(float(summary["score"])), played_off, line], [{"label": "The host waves you over to talk", "cb": func(): _interview()}])


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
