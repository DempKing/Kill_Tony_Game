extends Node2D
## On the road. State lives in state.flags.active_tour {id, leg, phase} and in
## the tour record, so a reload resumes the same leg with the same sales.
## Phases: arrive -> sales -> show -> night -> (next leg) ... -> return.

var s: GameState
var db: ContentDB
var tour: Dictionary
var art: StageArt
var ui: UiLayer
var runner: PerformanceRunner
var sim: PerformanceSim
var caption: Label
var route: Label


func _ready() -> void:
	s = Game.state
	db = Game.db
	if s == null:
		Game.goto(Game.SCENE_BOOT)
		return
	var at: Dictionary = s.flags.get("active_tour", {})
	tour = TourRules.find(s, str(at.get("id", "")))
	if tour.is_empty():
		s.flags.erase("active_tour")
		Game.goto(Game.SCENE_DISTRICT)
		return
	art = StageArt.new()
	art.reduced = GameSettings.reduced_motion()
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
	var strip := ColorRect.new()
	strip.color = Color(0, 0, 0, 0.65)
	strip.set_anchors_preset(Control.PRESET_TOP_WIDE)
	strip.offset_bottom = 92
	ui.root.add_child(strip)
	caption = UiKit.label("", 22, UiKit.C_ACCENT, false)
	caption.position = Vector2(20, 12)
	ui.root.add_child(caption)
	route = UiKit.label("", 17, UiKit.C_WARN, false)
	route.position = Vector2(20, 50)
	ui.root.add_child(route)
	ui.top_margin = 92
	Sfx.stop_music()
	_resume()


func _state() -> Dictionary:
	return s.flags.get("active_tour", {})


func _leg_i() -> int:
	return int(_state().get("leg", 0))


func _leg() -> Dictionary:
	return tour["legs"][_leg_i()]


func _set_phase(phase: String, leg: int = -1) -> void:
	var st := _state()
	st["phase"] = phase
	if leg >= 0:
		st["leg"] = leg
	s.flags["active_tour"] = st
	SaveManager.autosave()


func _update_header() -> void:
	var leg := _leg()
	var m := TourRules.market(db, str(leg["market"]))
	caption.text = "%s · %s · %s" % [tour["title"], m.get("name", ""), CalendarRules.describe(s.day, s.block)]
	var parts: Array = []
	for i in range(tour["legs"].size()):
		var lm := TourRules.market(db, str(tour["legs"][i]["market"]))
		var nm: String = str(lm.get("name", "")).split(",")[0]
		parts.append(("▶ " + nm.to_upper()) if i == _leg_i() else nm)
	route.text = "Austin → " + " → ".join(PackedStringArray(parts)) + " → Austin    ·    Cash " + TourRules.money_text(s.cash) + "    ·    Energy %d" % s.energy
	var venue: Dictionary = db.venues.get(TourRules.venue_id(str(leg["market"]), str(leg["venue_type"])), {})
	art.stage = venue.get("stage", {})
	art.audience_size = clampi(int(leg["sold"]) / (40 if str(leg["venue_type"]) == "theater" else 5), 8, 60) if int(leg["sold"]) >= 0 else 20
	art.production = str(tour.get("production", "standard")) if str(leg["venue_type"]) == "arena" else ""
	art.queue_redraw()


func _resume() -> void:
	match str(_state().get("phase", "arrive")):
		"arrive":
			_arrive()
		"sales":
			_sales()
		"show":
			_pick_set()
		"night":
			_night()
		"return":
			_return_home()
		_:
			_arrive()


# --- Phases ---------------------------------------------------------------------

func _arrive() -> void:
	var i := _leg_i()
	var leg := _leg()
	var key := "tour_adv_%s_%d" % [tour["id"], i]
	if not s.flags.has(key):
		s.flags[key] = true
		# Travel takes the morning and afternoon; the show is in the evening.
		var target := CalendarRules.slot(int(leg["day"]), 2)
		var guard := 0
		while CalendarRules.slot(s.day, s.block) < target and guard < 12:
			GameSim.advance(s, db, 1, true)
			guard += 1
		if str(tour["transport"]) == "van":
			StatsRules.change_stress(s, int(TourRules.t(db, "van_stress_per_leg", 4)))
		StatsRules.change_energy(s, -8)
	var ev := TourRules.travel_event(s, db, tour, i)
	_set_phase("arrive")
	_update_header()
	var m := TourRules.market(db, str(leg["market"]))
	var body := "You arrive in %s. Tonight: %s." % [m.get("name", ""), leg["venue_name"]]
	if str(tour["role"]) == "opener":
		body += "\nYou're the opener tonight: short set, warm them up, don't overstay."
	if ev != "":
		body += "\n\n" + ev
	ui.dialog("On the road · Night %d of %d" % [i + 1, tour["legs"].size()], body, [{"label": "Check the box office", "cb": func(): _sales()}])


func _sales() -> void:
	_set_phase("sales")
	var i := _leg_i()
	var leg := _leg()
	var sold := TourRules.sell_leg(s, db, tour, i)
	SaveManager.autosave()
	_update_header()
	var body := ""
	if str(tour["role"]) == "opener":
		body = "The headliner sold the room out: %d seats. They're not here for you. Yet." % sold
	else:
		body = "Tickets sold: %d / %d at $%d (forecast was ~%d).\nGross: %s." % [sold, int(leg["cap"]), int(tour["price"]), int(leg["forecast"]), TourRules.money_text(int(leg["gross"]))]
		if sold >= int(leg["cap"]):
			body += "\nIt's a SELLOUT."
		elif sold < int(leg["forecast"]) * 0.8:
			body += "\nSoft night. Marketing, pricing or fame might help next time."
		body += "\n\n" + str(TourRules.opener_bonus(s, db, tour, i)["text"])
	ui.dialog("Box office", body, [{"label": "Pick tonight's set", "cb": func(): _pick_set()}])


func _pick_set() -> void:
	_set_phase("show")
	var leg := _leg()
	var vid := TourRules.venue_id(str(leg["market"]), str(leg["venue_type"]))
	SetRules.ensure_defaults(s)
	if SetRules.jokes_in(s, SetRules.TOUR_ID).is_empty():
		# Start from your best material so the road set is never empty.
		var ranked: Array = s.jokes.keys()
		ranked.sort_custom(func(a, b): return JokeRules.quality_of(db, s.jokes[a]) > JokeRules.quality_of(db, s.jokes[b]))
		var picks: Array = []
		for jid in ranked:
			if JokeRules.status_of(db, s.jokes[jid]) != "missing":
				picks.append(jid)
		SetRules.save_setlist(s, SetRules.TOUR_ID, "", picks.slice(0, 8))
	var need := _min_jokes()
	var v := UiKit.vbox(8)
	v.add_child(UiKit.title("Tonight's set"))
	v.add_child(UiKit.label("Road sets are longer, so they're judged on your strongest material rather than the clock. %s sets need at least %d jokes; each missing one costs you." % ["Headline" if str(tour["role"]) == "headliner" else "Opening", need], 16, UiKit.C_DIM))
	var sc := UiKit.scroll(400)
	var ed := SetEditor.new().setup(SetRules.TOUR_ID, 0, vid)
	ed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(ed)
	v.add_child(sc)
	v.add_child(UiKit.button("Walk out on stage", func(): _start_show()))
	ui.open(v, 1060, false)


func _min_jokes() -> int:
	if str(tour["role"]) != "headliner":
		return 3
	if str(_leg()["venue_type"]) == "arena":
		return int(TourRules.t(db, "arena_min_jokes", 8))
	return int(TourRules.t(db, "headline_min_jokes", 5))


func _start_show() -> void:
	ui.close_all()
	var i := _leg_i()
	var leg := _leg()
	var vid := TourRules.venue_id(str(leg["market"]), str(leg["venue_type"]))
	var res := GameSim.begin_performance(s, db, vid, SetRules.TOUR_ID, "")
	var ctx: Dictionary = res.get("context", {})
	var a := SetRules.analyze(s, db, ctx.get("joke_ids", []), 0)
	ctx["slot_seconds"] = maxi(60, int(float(a["seconds"]) * 1.25))
	ctx["tour_leg"] = "%s_%d" % [tour["id"], i]
	s.flags["active_performance"] = ctx
	SaveManager.autosave()
	sim = GameSim.build_sim(s, db, ctx)
	if str(tour["role"]) == "headliner":
		sim.warmth_bonus = float(TourRules.opener_bonus(s, db, tour, i)["bonus"])
	var missing := maxi(0, _min_jokes() - sim.queue.size())
	sim.overrun_penalty += missing * float(TourRules.t(db, "thin_act_penalty_per_joke", 4.0))
	art.light_on = false
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
	runner.finished.connect(_on_finished.bind(ctx, missing))


func _on_reacted(res: Dictionary) -> void:
	var sc := float(res.get("score", 0))
	art.reaction = clampf((sc - 40.0) / 40.0, -1.0, 1.0)
	if sc >= 80.0:
		Sfx.play("applause")
	elif sc >= 65.0:
		Sfx.play("big_laugh")
	elif sc >= 45.0:
		Sfx.play("laugh")
	else:
		Sfx.play("silence")


func _on_finished(summary: Dictionary, ctx: Dictionary, missing: int) -> void:
	runner.queue_free()
	runner = null
	GameSim.apply_performance(s, db, ctx, summary, false)
	var st := TourRules.settle_leg(s, db, tour, _leg_i(), float(summary["score"]))
	_set_phase("night")
	Game.notify()
	_update_header()
	var body := "%s · %d/100\n" % [summary["tier_label"], int(float(summary["score"]))]
	if missing > 0:
		body += "Your act ran thin: %d joke(s) short of a full set.\n" % missing
	for sg in (summary["suggestions"] as Array).slice(0, 2):
		body += "• %s\n" % str(sg)
	body += "\nSETTLEMENT\n" + "\n".join(PackedStringArray(st.get("lines", [])))
	var last: bool = _leg_i() >= tour["legs"].size() - 1
	ui.dialog("After the show", body, [{"label": "Head home to Austin" if last else "Back to the %s" % ("hotel" if str(tour["lodging"]) == "hotel" else "motel"), "cb": func(): _night()}])


func _night() -> void:
	var i := _leg_i()
	if i >= tour["legs"].size() - 1:
		_set_phase("return")
		_return_home()
		return
	var key := "tour_night_%s_%d" % [tour["id"], i]
	if not s.flags.has(key):
		s.flags[key] = true
		var n := GameSim.blocks_until_morning(s)
		GameSim.advance(s, db, n, true)
		var rest := int(TourRules.t(db, "hotel_rest" if str(tour["lodging"]) == "hotel" else "motel_rest", 40))
		StatsRules.change_energy(s, rest)
	_set_phase("arrive", i + 1)
	_arrive()


func _return_home() -> void:
	var key := "tour_home_%s" % tour["id"]
	if not s.flags.has(key):
		s.flags[key] = true
		GameSim.advance(s, db, GameSim.blocks_until_morning(s), true)
		StatsRules.change_energy(s, int(TourRules.t(db, "motel_rest", 30)))
		GameSim.advance(s, db, 2, true)
	var sm := TourRules.finish(s, db, tour)
	s.location_id = "transit_stop"
	var door: Array = db.locations["transit_stop"]["door"]
	s.player_pos = Vector2(float(door[0]), float(door[1]) - 20.0)
	SaveManager.autosave()
	Game.notify()
	var body := ""
	if str(tour["role"]) == "headliner":
		body = "Tickets: %d / %d.\nSettled: %s · Costs (deposits, marketing, travel, lodging, opener): %s\n%s: %s" % [int(sm["sold"]), int(sm["cap"]), TourRules.money_text(int(sm["revenue"])), TourRules.money_text(int(sm["costs"])), "PROFIT" if int(sm["profit"]) >= 0 else "LOSS", TourRules.money_text(int(sm["profit"]))]
		if int(sm["sold"]) >= int(sm["cap"]):
			body += "\nEvery show sold out."
	else:
		body = "You opened %d show(s) and earned %s. The headliner's people have your number now." % [tour["legs"].size(), TourRules.money_text(int(sm["revenue"]))]
	body += "\n\n" + CareerRules.next_requirements(s, db)
	ui.dialog("Back in Austin", body, [{"label": "Get off the bus", "cb": func(): Game.goto(Game.SCENE_DISTRICT)}])
