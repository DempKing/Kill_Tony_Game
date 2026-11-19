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
	print("[playtest] done. kt appearances=", s.kt.get("appearances"), " books=", s.books)
	get_tree().quit()
