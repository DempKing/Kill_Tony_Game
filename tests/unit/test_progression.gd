extends TestCase


func test_career_progression_without_bucket() -> void:
	var s := new_state(10)
	var d := db()
	eq(s.career_tier, 0, "start as a new arrival")
	s.stats["sets"] = 1
	CareerRules.update(s, d)
	eq(s.career_tier, 1, "first set: open-mic beginner")
	s.stats["sets"] = 8
	s.reputation = 15.0
	CareerRules.update(s, d)
	eq(s.career_tier, 2, "local regular without any Kill Tony appearance")
	# Paid work through the opportunity system.
	s.reputation = 26.0
	for i in range(2):
		var o := OpportunityRules.create_offer(s, d, "opp_lantern_showcase", s.day + i * 7)
		OpportunityRules.accept(s, d, str(o["id"]))
		OpportunityRules.on_complete(s, d, str(o["id"]))
	CareerRules.update(s, d)
	eq(s.career_tier, 3, "paid club performer via showcases")
	eq(int(s.kt.get("appearances", 0)), 0, "no bucket pull needed")
	check(CareerRules.next_requirements(s, d) != "", "next tier requirements are explained")


func test_opportunities_generate_from_conditions() -> void:
	var s := new_state(11)
	var d := db()
	s.stats["sets"] = 5
	s.reputation = 12.0
	var got := false
	for i in range(40):
		GameSim.advance(s, d, 4, true)
		for o in s.opportunities:
			if str(o["template"]) == "opp_lantern_showcase":
				got = true
	check(got, "meeting conditions eventually produces a showcase offer")
	for o in s.opportunities:
		check(int(o["expires_day"]) < int(o["day"]), "offers expire before the booking date")


func test_tutorial_completes_without_dev_tools() -> void:
	var s := new_state(12)
	var d := db()
	GameSim.run_action(s, d, {"id": "pick_up_bag", "params": {}})
	GameSim.tutorial_mark(s, "journal")
	GameSim.tutorial_mark(s, "landmark")
	GameSim.run_action(s, d, {"id": "rent_bunk", "params": {}})
	GameSim.run_action(s, d, {"id": "hire", "params": {"job_id": "server"}})
	GameSim.run_action(s, d, {"id": "talk", "params": {"npc": "dusty"}})
	s.block = 2
	SetRules.save_setlist(s, SetRules.DEFAULT_ID, "", s.jokes.keys())
	var b := GameSim.begin_performance(s, d, "spur_open_mic", SetRules.DEFAULT_ID, "")
	check(bool(b["ok"]), "can afford the first open mic with starting cash")
	var sim := GameSim.build_sim(s, d, b["context"])
	while sim.has_next():
		sim.perform_next()
		sim.choose("continue")
	GameSim.apply_performance(s, d, b["context"], sim.finish())
	check(bool(s.flags.get("tutorial_done", false)), "tutorial completes through normal actions (step: %s)" % s.flags.get("tutorial_step", ""))
	var sl := GameSim.sleep(s, d)
	check(bool(sl["ok"]), "can sleep at the hostel after the first set")


func test_locations_reachable() -> void:
	## Grid flood fill from the player start, avoiding building footprints.
	var d := db()
	var cell := 20
	var w := int(d.world["width"]) / cell
	var h := int(d.world["height"]) / cell
	var rects: Array = []
	for id in d.locations:
		var r: Array = d.locations[id]["rect"]
		rects.append(Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])))
	var blocked := func(x: int, y: int) -> bool:
		var p := Rect2(x * cell + 4, y * cell + 4, cell - 8, cell - 8)
		for rr in rects:
			if (rr as Rect2).intersects(p):
				return true
		return false
	var ps: Array = d.world["player_start"]
	var start := Vector2i(int(ps[0]) / cell, int(ps[1]) / cell)
	var seen: Dictionary = {start: true}
	var frontier: Array = [start]
	while not frontier.is_empty():
		var c: Vector2i = frontier.pop_back()
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + dv
			if n.x < 1 or n.y < 1 or n.x >= w - 1 or n.y >= h - 1 or seen.has(n):
				continue
			if blocked.call(n.x, n.y):
				continue
			seen[n] = true
			frontier.append(n)
	for id in d.locations:
		var dp: Array = d.locations[id]["door"]
		var dc := Vector2i(int(dp[0]) / cell, int(dp[1]) / cell)
		check(seen.has(dc), "%s door is reachable on foot" % id)


func test_npc_schedules_place_people() -> void:
	var d := db()
	var s := new_state(13)
	var placed: Dictionary = {}
	for day in range(7):
		for b in range(4):
			s.day = day
			s.block = b
			for id in d.npcs:
				var loc := WorldRules.npc_location(d, str(id), day, b)
				if loc != "":
					check(d.locations.has(loc), "%s scheduled at a real location" % id)
					placed[id] = true
	eq(placed.size(), d.npcs.size(), "every recurring NPC appears somewhere during the week")


func test_tour_cash_flow() -> String:
	return "SKIP touring (Phase 4) is not implemented in this build"
