extends TestCase
## Gender, promises, workshops, regular status, day summaries.


func test_gender_and_text_tokens() -> void:
	var d := db()
	var f := GameSim.new_game(d, {"name": "Jo", "stage_name": "Jojo", "gender": "female"}, 1)
	eq(str(f.player["gender"]), "female", "female selected")
	eq(GameSim.fmt(f, d, "{He} said {his} name is {stage}. Look at {him}."), "She said her name is Jojo. Look at her.", "tokens use her pronouns")
	var m := GameSim.new_game(d, {"name": "Al", "gender": "male"}, 1)
	eq(GameSim.fmt(m, d, "{he}/{him}/{his}"), "he/him/his", "male pronouns")
	var bad := GameSim.new_game(d, {"name": "X", "gender": "unknown"}, 1)
	eq(str(bad.player["gender"]), "male", "unknown gender falls back to a valid option")
	check(not f.player.has("pronouns"), "pronoun field no longer stored")


func test_v1_save_migrates_pronouns_to_gender() -> void:
	var old := {"version": 1, "player": {"name": "Old", "pronouns": "she"}, "day": 2, "block": 0}
	var m := SaveMigrations.migrate(old)
	eq(int(m["version"]), GameState.SAVE_VERSION, "migrated to current version")
	eq(str(m["player"]["gender"]), "female", "she/her save becomes female")
	check(not m["player"].has("pronouns"), "old field removed")
	var m2 := SaveMigrations.migrate({"version": 1, "player": {"pronouns": "they"}, "day": 0})
	eq(str(m2["player"]["gender"]), "male", "other values default to male")


func test_promise_keep_and_miss() -> void:
	var s := new_state(21)
	var d := db()
	s.block = 1
	var msg := PromiseRules.create(s, d, {"npc": "deshawn", "title": "Watch Deshawn", "location": "rusty_spur", "days_ahead": 0, "block": 2, "reward": {"rel": {"deshawn": {"trust": 6}}}})
	check(msg.begins_with("Promised"), "promise booked: " + msg)
	GameSim.advance(s, d, 1)
	var acts := GameSim.actions_for(s, d, "rusty_spur")
	var keep: Dictionary = {}
	for a in acts:
		if str(a["id"]) == "keep_promise":
			keep = a
	check(not keep.is_empty(), "keep-promise action appears at the right place and time")
	var t0 := int(s.rel("deshawn")["trust"])
	GameSim.run_action(s, d, keep)
	eq(int(s.rel("deshawn")["trust"]), t0 + 6, "keeping a promise applies its reward")
	eq(PromiseRules.keep(s, d, str(keep["params"]["commitment_id"])).size(), 0, "reward applies only once")
	# Missing one.
	var s2 := new_state(22)
	s2.rel("priya")["trust"] = 20
	PromiseRules.create(s2, d, {"npc": "priya", "title": "Read pages", "location": "coffee", "days_ahead": 1, "block": 1})
	var rep0 := s2.reputation
	GameSim.advance(s2, d, 8, true)
	check(int(s2.rel("priya")["trust"]) < 20, "breaking a promise costs trust")
	eq(s2.reputation, rep0, "a broken personal promise doesn't hit professional reputation")


func test_promise_refused_when_booked() -> void:
	var s := new_state(23)
	var d := db()
	Scheduler.add(s, d, {"kind": "booking", "title": "Gig", "day": 0, "block": 2, "length": 1, "location_id": "lantern"})
	var msg := PromiseRules.create(s, d, {"npc": "deshawn", "title": "Watch", "location": "rusty_spur", "days_ahead": 0, "block": 2})
	check(msg.find("already booked") >= 0, "a promise never silently replaces a booking")
	eq(Scheduler.booked(s).size(), 1, "only the original booking remains")


func test_shift_promise_pays_bonus() -> void:
	var s := new_state(24)
	var d := db()
	JobRules.hire(s, d, "server")
	PromiseRules.create(s, d, {"npc": "gus", "title": "Cover dinner", "location": "diner", "days_ahead": 1, "block": 1, "length": 2, "job_shift": {"job": "server", "shift": "dinner"}, "reward": {"pay": 20, "rel": {"gus": {"trust": 6}}}})
	GameSim.advance(s, d, 4, true)
	eq(s.block, 1, "next afternoon")
	var work: Dictionary = {}
	for a in GameSim.actions_for(s, d, "diner"):
		if str(a["id"]) == "work" and a["params"].has("promise_id"):
			work = a
	check(not work.is_empty(), "promised shift is offered at the diner")
	var res := GameSim.run_action(s, d, work)
	var t0 := int(s.rel("gus")["trust"])
	GameSim.finish_shift(s, d, [0, 0])
	check(int(s.rel("gus")["trust"]) >= t0 + 6, "covering the shift earns trust")
	eq(str(Scheduler.find(s, str(res["shift"]["promise_id"]))["status"]), "done", "promise marked kept")


func test_priya_workshop_gives_punchlines() -> void:
	var d := db()
	var got := false
	for seed_value in range(1, 30):
		var s := new_state(seed_value)
		JokeRules.unlock_component(s, d, "comp_heat_p")
		s.rel("priya")["chemistry"] = 60
		var before := s.components.duplicate()
		GameSim.workshop(s, d, "priya")
		for c in s.components:
			if not before.has(c) and str(d.component(str(c))["type"]) == "punchline":
				got = true
	check(got, "Priya's workshops can surface punchlines")


func test_regular_status_flow() -> void:
	var s := new_state(25)
	var d := db()
	for day in [5, 12, 19]:
		KillTonyRules.resolve_rewards(s, d, day, 85.0, 70.0)
	check(bool(s.flags.get("kt_regular_ready", false)), "three strong appearances make you regular-ready")
	s.flags["kt_regular"] = true
	while CalendarRules.weekday(s.day) != 0:
		GameSim.advance(s, d, 4, true)
	s.block = 0
	var have := false
	for c in Scheduler.booked(s):
		if bool(c.get("regular", false)):
			have = true
	if not have:
		KillTonyRules.schedule_regular(s, d)
		for c in Scheduler.booked(s):
			if bool(c.get("regular", false)):
				have = true
	check(have, "a regular spot is scheduled on Monday")
	var draw := KillTonyRules.ensure_draw(s, d, s.day)
	check(bool(draw["selected"]) and bool(draw["regular"]), "regulars skip the bucket")
	# Recycled material earns strikes; three strikes ends regular status.
	var jid: String = s.jokes.keys()[0]
	s.jokes[jid]["exposure"] = {"kill_tony": 2}
	for i in range(3):
		KillTonyRules.regular_review(s, d, [{"joke_id": jid}])
	check(not bool(s.flags.get("kt_regular", false)), "three recycled sets lose regular status")


func test_day_summary() -> void:
	var s := new_state(26)
	var d := db()
	GameSim.run_action(s, d, {"id": "rent_bunk", "params": {}})
	StatsRules.add_cash(s, 40, "test income")
	JokeRules.unlock_component(s, d, "comp_bats_p")
	var res := GameSim.sleep(s, d)
	var sm: Dictionary = res["summary"]
	eq(int(sm["earned"]), 40, "summary counts the day's income")
	eq(int(sm["found"]), 1, "summary counts material found")
	eq(int(sm["rent_in"]), 6, "summary shows days until rent")
