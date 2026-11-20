extends Node
## DEV ONLY. Drives the real game through its main flows and saves screenshots.
## Launched by Game when started with:  godot --path . -- --playtest=<out_dir>
## Not part of release exports (tests/ is excluded).

var out_dir: String = "user://playtest"
var shot_n: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	shot_n += 1
	var path := out_dir.path_join("%02d_%s.png" % [shot_n, label])
	img.save_png(path)
	print("[playtest] shot ", path)


func scene() -> Node:
	return get_tree().current_scene


func _run() -> void:
	await _wait(1.0)
	await shot("title")
	Game.goto(Game.SCENE_CREATE)
	await _wait(1.0)
	var cc := scene()
	cc.setup["name"] = "Sam"
	cc.setup["stage_name"] = "Sammy Vale"
	cc.setup["gender"] = "female"
	cc.setup["background"] = "theater_kid"
	cc.setup["style"] = "absurdist"
	cc.setup["appearance"] = {"skin": 2, "hair": 5, "outfit": 3}
	cc._build()
	await _wait(0.4)
	await shot("character_creation")
	Game.start_new_game(cc.setup)
	await _wait(1.5)
	await shot("arrival_intro")
	var d := scene()
	d.ui.close_all()
	var s: GameState = Game.state
	GameSim.run_action(s, Game.db, {"id": "pick_up_bag", "params": {}})
	d.player.configure(Game.db, s)
	Game.notify()
	await _wait(0.5)
	await shot("street_bus_stop")
	d.open_journal()
	await _wait(0.6)
	await shot("journal_intro")
	d.ui.close_all()
	d.open_journal()
	await _wait(0.6)
	await shot("journal_jokes")
	d.ui.close_all()
	d.player.position = Vector2(1250, 620)
	await _wait(3.0)
	await shot("mothership_landmark")
	d.ui.close_all()
	d.teleport_to("hostel")
	d.open_location("hostel")
	await _wait(0.6)
	await shot("hostel_interior")
	d.ui.close_all()
	GameSim.run_action(s, Game.db, {"id": "rent_bunk", "params": {}})
	JobRules.hire(s, Game.db, "server")
	GameSim.run_action(s, Game.db, {"id": "talk", "params": {"npc": "dusty"}})
	GameSim.advance(s, Game.db, 1)
	Game.notify()
	d.teleport_to("rusty_spur")
	await _wait(1.0)
	await shot("street_evening")
	d.open_set_builder("spur_open_mic", "")
	await _wait(0.6)
	await shot("set_builder")
	d.ui.close_all()
	var b := GameSim.begin_performance(s, Game.db, "spur_open_mic", SetRules.DEFAULT_ID, "")
	print("[playtest] begin_performance ", b.get("ok"))
	Game.goto(Game.SCENE_PERFORMANCE)
	await _wait(1.2)
	await shot("open_mic_stage")
	var ps := scene()
	ps.runner._pick("_start")
	await _wait(2.5)
	await shot("open_mic_choice")
	var guard := 0
	while not ps.sim.ended and ps.sim.has_next() or (ps.sim.awaiting_choice and guard < 20):
		guard += 1
		if guard > 20:
			break
		var ch: Array = ps.sim.available_choices()
		if ps.sim.awaiting_choice and not ch.is_empty():
			ps.runner._pick(str(ch[0]["id"]))
			await _wait(0.2)
		if ps.sim.has_next():
			ps.runner._pick("_next")
			await _wait(2.2)
	ps.runner._pick("_finish")
	await _wait(1.0)
	await shot("open_mic_results")
	Game.goto(Game.SCENE_DISTRICT)
	await _wait(1.0)
	d = scene()
	d.ui.close_all()
	# Jump to Monday morning and sign up for Kill Tony.
	while CalendarRules.weekday(s.day) != 0 or s.block != 0:
		GameSim.advance(s, Game.db, 1, true)
	s.energy = 90
	Game.notify()
	d.teleport_to("mothership")
	await _wait(1.0)
	await shot("monday_line")
	print("[playtest] signup ", KillTonyRules.signup(s, Game.db).get("message"))
	GameSim.advance(s, Game.db, 2, true)
	s.flags["dev_force_bucket"] = "selected"
	d.ui.close_all()
	d.start_kill_tony(str(Scheduler.current(s)[0]["id"]))
	await _wait(1.5)
	await shot("kt_bucket")
	var kt := scene()
	kt.ui.close_all()
	kt._goto_minute()
	await _wait(1.2)
	await shot("kt_at_mic")
	kt.ui.close_all()
	kt._choose_set(SetRules.KT_MINUTE_ID)
	await _wait(1.2)
	kt.runner._pick("_start")
	await _wait(2.4)
	await shot("kt_set")
	guard = 0
	while kt.runner != null and guard < 10:
		guard += 1
		var ch2: Array = kt.sim.available_choices()
		if kt.sim.awaiting_choice and not ch2.is_empty():
			kt.runner._pick(str(ch2[0]["id"]))
			await _wait(0.3)
		if kt.sim.has_next():
			kt.runner._pick("_next")
			await _wait(2.5)
		else:
			kt.runner._pick("_finish")
			await _wait(1.5)
			break
	await shot("kt_panel")
	kt.ui.close_all()
	kt._interview()
	await _wait(1.0)
	await shot("kt_interview")
	for i in range(3):
		var ids: Array = kt.night.get("prompts", [])
		var answers: Array = kt.night.get("answers", [])
		if answers.size() >= ids.size():
			break
		kt.ui.close_all()
		var p: Dictionary = kt._prompt_by_id(str(ids[answers.size()]))
		kt._answer(p, p["responses"][0])
		await _wait(0.4)
	kt.ui.close_all()
	kt._interview()
	await _wait(1.5)
	await shot("kt_rewards")
	print("[playtest] kt appearances=", s.kt.get("appearances"), " books=", s.books)
	await _tour_segment()
	await _legacy_segment()
	print("[playtest] done.")
	get_tree().quit()


func _tour_segment() -> void:
	var s: GameState = Game.state
	var db: ContentDB = Game.db
	kt_leave()
	await _wait(1.2)
	var d := scene()
	d.ui.close_all()
	# Fast-forward the career so headline touring is unlocked.
	s.career_tier = 6
	s.fame = 30.0
	s.reputation = 60.0
	StatsRules.add_cash(s, 4000, "DEV playtest")
	for id in db.components:
		JokeRules.unlock_component(s, db, str(id))
	for fam in ["fam_heat", "fam_bucket", "fam_coffee", "fam_delivery", "fam_bbq", "fam_grandma"]:
		var parts := {}
		for c in db.family_components(fam):
			var t: String = str(c["type"])
			if t in ["premise", "setup"] or (t == "punchline" and str(c["id"]).ends_with("_u2")):
				parts[t] = str(c["id"])
		for jid in s.jokes:
			s.jokes[jid]["status"] = "complete"
		JokeRules.create_joke(s, db, db.families[fam]["title"], parts)
	for jid in s.jokes:
		s.jokes[jid]["familiarity"] = 70
	Game.notify()
	d.open_phone("tours")
	await _wait(0.6)
	await shot("phone_tours")
	d.ui.close_all()
	var planner := TourPlannerUI.new().setup(d.ui, func(_m): pass)
	planner.plan["legs"] = [{"market": "houston", "venue_type": "club"}, {"market": "dallas", "venue_type": "club"}, {"market": "san_antonio", "venue_type": "club"}]
	planner.plan["opener"] = "deshawn"
	planner.plan["marketing"] = 400
	planner._build()
	d.ui.open(planner, 1220)
	await _wait(0.6)
	await shot("tour_planner")
	var res := TourRules.book(s, db, planner.plan)
	print("[playtest] book: ", res.get("message"))
	d.ui.close_all()
	var tr: Dictionary = res["tour"]
	while s.day < int(tr["start_day"]):
		GameSim.advance(s, db, 1, true)
	d.teleport_to("transit_stop")
	d.open_location("transit_stop")
	await _wait(0.6)
	await shot("depart_action")
	var dep := GameSim.run_action(s, db, {"id": "depart_tour", "params": {"tour_id": tr["id"]}})
	print("[playtest] depart: ", dep.get("message"))
	d.start_tour()
	await _wait(1.5)
	await shot("tour_arrive")
	var ts := scene()
	for i in range(tr["legs"].size()):
		ts.ui.close_all()
		ts._sales()
		await _wait(0.5)
		if i == 0:
			await shot("tour_box_office")
		ts.ui.close_all()
		ts._pick_set()
		await _wait(0.6)
		if i == 0:
			await shot("tour_set_pick")
		ts._start_show()
		await _wait(0.8)
		ts.runner._pick("_start")
		await _wait(2.3)
		if i == 0:
			await shot("tour_show_houston")
		var guard := 0
		while ts.runner != null and guard < 30:
			guard += 1
			if ts.sim.awaiting_choice:
				var ch: Array = ts.sim.available_choices()
				ts.runner._pick(str(ch[0]["id"]) if not ch.is_empty() else "_finish")
				await _wait(0.2)
			if ts.runner != null and ts.sim.has_next() and not ts.sim.awaiting_choice:
				ts.runner._pick("_next")
				await _wait(2.1)
			elif ts.runner != null and not ts.sim.has_next() and not ts.sim.awaiting_choice:
				ts.runner._pick("_finish")
				await _wait(0.8)
		await shot("tour_settlement_%d" % i)
		ts.ui.close_all()
		ts._night()
		await _wait(1.0)
	await shot("tour_home")
	var sm := TourRules.summary(tr)
	print("[playtest] tour summary: ", sm, " tier=", s.career_tier, " fans=", s.fans)


func kt_leave() -> void:
	Sfx.stop_music()
	Game.goto(Game.SCENE_DISTRICT)


func _legacy_segment() -> void:
	var s: GameState = Game.state
	var db: ContentDB = Game.db
	Game.goto(Game.SCENE_DISTRICT)
	await _wait(1.2)
	var d := scene()
	d.ui.close_all()
	s.career_tier = 7
	s.fame = 75.0
	s.reputation = 90.0
	s.fans["houston"] = 400
	StatsRules.add_cash(s, 900000, "DEV playtest")
	# Panel night.
	var o := OpportunityRules.create_offer(s, db, "opp_kt_panel", s.day)
	OpportunityRules.accept(s, db, str(o["id"]))
	while s.day < int(o["day"]) or s.block < 2:
		GameSim.advance(s, db, 1, true)
	var cid := ""
	for c in Scheduler.current(s):
		if str(c["kind"]) == "kt_panel":
			cid = str(c["id"])
	d.start_kt_panel(cid)
	await _wait(1.5)
	await shot("panel_intro")
	var kt := scene()
	for i in range(3):
		kt.ui.close_all()
		kt._panel_save("walkup")
		kt._panel_step()
		await _wait(1.0)
		if i == 0:
			await shot("panel_walkup")
		kt.ui.close_all()
		kt._panel_save("set")
		kt._panel_step()
		await _wait(1.0)
		if i == 0:
			await shot("panel_minute")
		kt.ui.close_all()
		kt._panel_react(kt.night["comics"][i], "laugh")
		kt.ui.close_all()
		kt._panel_step()
		await _wait(1.0)
		if i == 0:
			await shot("panel_interview")
		kt.ui.close_all()
		kt._panel_contribute(kt.night["comics"][i], ["roast", "support", "absurd"][i])
		kt.ui.close_all()
		if PanelRules.can_scout(kt.night["comics"][i]):
			PanelRules.scout(s, kt.night["comics"][i])
		kt.night["idx"] = i + 1
		kt.night["step"] = "walkup"
	kt.ui.close_all()
	kt._panel_end()
	await _wait(1.0)
	await shot("panel_results")
	# Arena show.
	Game.goto(Game.SCENE_DISTRICT)
	await _wait(1.0)
	d = scene()
	d.ui.close_all()
	var planner := TourPlannerUI.new().setup(d.ui, func(_m): pass)
	planner.plan["legs"] = [{"market": "houston", "venue_type": "arena"}]
	planner.plan["transport"] = "flight"
	planner.plan["price"] = 75
	planner.plan["marketing"] = 2500
	planner.plan["production"] = "spectacle"
	planner.plan["opener"] = "deshawn"
	planner._build()
	d.ui.open(planner, 1220)
	await _wait(0.6)
	await shot("arena_planner")
	var res := TourRules.book(s, db, planner.plan)
	print("[playtest] arena book: ", res.get("message"))
	d.ui.close_all()
	var tr: Dictionary = res["tour"]
	while s.day < int(tr["start_day"]):
		GameSim.advance(s, db, 1, true)
	TourRules.depart(s, db, str(tr["id"]))
	d.start_tour()
	await _wait(1.5)
	var ts := scene()
	ts.ui.close_all()
	ts._sales()
	await _wait(0.5)
	ts.ui.close_all()
	ts._start_show()
	await _wait(0.8)
	ts.runner._pick("_start")
	await _wait(2.4)
	await shot("arena_show")
	var guard := 0
	while ts.runner != null and guard < 40:
		guard += 1
		if ts.sim.awaiting_choice:
			var ch: Array = ts.sim.available_choices()
			ts.runner._pick(str(ch[0]["id"]) if not ch.is_empty() else "_finish")
			await _wait(0.2)
		if ts.runner != null and ts.sim.has_next() and not ts.sim.awaiting_choice:
			ts.runner._pick("_next")
			await _wait(2.1)
		elif ts.runner != null and not ts.sim.has_next() and not ts.sim.awaiting_choice:
			ts.runner._pick("_finish")
			await _wait(0.8)
	await shot("arena_settlement")
	ts.ui.close_all()
	ts._night()
	await _wait(1.0)
	await shot("arena_home")
	print("[playtest] arena: ", TourRules.summary(tr), " tier=", s.career_tier, " stats=", s.stats)
