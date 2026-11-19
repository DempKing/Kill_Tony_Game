extends Node2D
## Generic performance scene (open mic, showcases, late shows, The Secret Show).
## Reads the stored performance context, runs the set, applies results once,
## shows explainable feedback, then returns to the district.

var s: GameState
var db: ContentDB
var ctx: Dictionary
var sim: PerformanceSim
var art: StageArt
var ui: UiLayer
var runner: PerformanceRunner
var _before: Dictionary = {}


func _ready() -> void:
	s = Game.state
	db = Game.db
	if s == null:
		Game.goto(Game.SCENE_BOOT)
		return
	ctx = s.flags.get("active_performance", {})
	if ctx.is_empty():
		Game.goto(Game.SCENE_DISTRICT)
		return
	var venue: Dictionary = db.venues.get(str(ctx["venue_id"]), {})
	sim = GameSim.build_sim(s, db, ctx)
	art = StageArt.new()
	art.stage = venue.get("stage", {})
	art.reduced = GameSettings.reduced_motion()
	art.audience_size = int(sim.audience.get("size", 30))
	var pa := PlayerActor.new()
	pa.configure(db, s)
	art.player_colors = pa.colors
	pa.free()
	add_child(art)
	var cam := Camera2D.new()
	cam.position = Vector2(800, 450)
	add_child(cam)
	cam.make_current()
	ui = UiLayer.new()
	add_child(ui)
	var top := UiKit.label("%s · %s" % [venue.get("name", ""), CalendarRules.describe(s.day, s.block)], 22, UiKit.C_ACCENT, false)
	top.position = Vector2(20, 14)
	ui.root.add_child(top)
	var intro: String = str(venue.get("host_intro", ""))
	if intro != "":
		var il := UiKit.label(GameSim.fmt(s, db, intro), 20, UiKit.C_WARN)
		il.position = Vector2(20, 52)
		il.custom_minimum_size = Vector2(1100, 0)
		il.add_theme_color_override("font_outline_color", Color.BLACK)
		il.add_theme_constant_override("outline_size", 5)
		ui.root.add_child(il)
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
	runner.finished.connect(_on_finished)
	_before = _snapshot()
	Sfx.stop_music()


func _snapshot() -> Dictionary:
	return {"cash": s.cash, "rep": s.reputation, "fame": s.fame, "confidence": s.confidence, "skills": s.skills.duplicate()}


func _on_reacted(res: Dictionary) -> void:
	var resp: String = str(res.get("response", "silence"))
	match resp:
		"applause":
			art.reaction = 1.0
			Sfx.play("applause")
		"big_laugh":
			art.reaction = 0.8
			Sfx.play("big_laugh")
		"laugh":
			art.reaction = 0.5
			Sfx.play("laugh")
		"chuckle":
			art.reaction = 0.15
			Sfx.play("groan")
		_:
			art.reaction = -0.5
			Sfx.play("silence")
	art.light_on = sim.elapsed >= sim.slot_seconds


func _on_finished(summary: Dictionary) -> void:
	var applied := GameSim.apply_performance(s, db, ctx, summary)
	SaveManager.autosave()
	Game.notify()
	runner.visible = false
	ui.open(_results_view(summary, applied.get("notes", [])), 1000, false)


func _results_view(summary: Dictionary, notes: Array) -> Control:
	var v := UiKit.vbox(8)
	v.add_child(UiKit.title("%s  ·  %d/100" % [summary["tier_label"], int(float(summary["score"]))]))
	var best: Dictionary = summary.get("best", {})
	var worst: Dictionary = summary.get("worst", {})
	if not best.is_empty():
		v.add_child(UiKit.label("Best: \"%s\" (%s, %d)" % [best["title"], best["response_label"], int(float(best["score"]))], 19, UiKit.C_GOOD))
	if not worst.is_empty():
		v.add_child(UiKit.label("Weakest: \"%s\" (%s, %d)" % [worst["title"], worst["response_label"], int(float(worst["score"]))], 19, UiKit.C_BAD))
	v.add_child(UiKit.label("Time: %ds of %ds%s" % [int(summary["elapsed"]), int(summary["slot_seconds"]), " (ran long)" if float(summary["overrun_penalty"]) > 0.0 else ""], 18))
	v.add_child(UiKit.label("WHAT TO WORK ON", 18, UiKit.C_ACCENT))
	for sg in summary["suggestions"]:
		v.add_child(UiKit.label("• " + str(sg), 18))
	if (summary["suggestions"] as Array).is_empty():
		v.add_child(UiKit.label("• Honestly? Keep doing exactly this.", 18))
	# Factor breakdown (explainable results).
	var why := "WHY: "
	for r in summary["results"]:
		var f: Dictionary = r["factors"]
		why += "\n  %s %d = material %.0f, delivery %.0f, room %.0f, fit %+.0f, momentum %+.0f, heard-before %+.0f, difficulty %+.0f, condition %+.0f, extras %+.0f, luck %+.0f" % [r["title"], int(float(r["score"])), float(f["material"]), float(f["delivery"]), float(f["warmth"]), float(f["fit"]), float(f["momentum"]), float(f["exposure"]), float(f["difficulty"]), float(f["condition"]), float(f["extras"]), float(f["luck"])]
	v.add_child(UiKit.label(why, 15, UiKit.C_DIM))
	# Changes.
	var ch: Array = []
	var dcash := s.cash - int(_before["cash"])
	if dcash != 0:
		ch.append("Cash %s" % UiKit.money(dcash))
	ch.append("Reputation %+.1f" % (s.reputation - float(_before["rep"])))
	ch.append("Confidence %+d" % (s.confidence - int(_before["confidence"])))
	for k in s.skills:
		var d := float(s.skills[k]) - float(_before["skills"].get(k, 0.0))
		if absf(d) > 0.01:
			ch.append("%s %+.1f" % [str(k).replace("_", " ").capitalize(), d])
	v.add_child(UiKit.label("CHANGES: " + ", ".join(PackedStringArray(ch)), 18))
	for n in notes:
		v.add_child(UiKit.label("• " + str(n), 17, UiKit.C_WARN))
	v.add_child(UiKit.button("Head back out", func():
		Sfx.play("confirm")
		Game.goto(Game.SCENE_DISTRICT)))
	return v
