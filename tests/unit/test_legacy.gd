extends TestCase
## Phase 5: arenas, production, opener hiring and mentorship, panel guest, legacy tiers.


func _star(seed_value: int = 50) -> GameState:
	var s := new_state(seed_value)
	s.career_tier = 7
	s.fame = 70.0
	s.reputation = 90.0
	s.cash = 2000000
	s.fans["houston"] = 400
	s.fans["dallas"] = 400
	return s


func _arena_plan(s: GameState, production: String = "standard", opener: String = "tasha") -> Dictionary:
	return {"start_day": s.day + 3, "legs": [{"market": "houston", "venue_type": "arena"}, {"market": "dallas", "venue_type": "arena"}],
		"price": 60, "marketing": 2500, "transport": "flight", "lodging": "hotel", "opener": opener, "production": production}


func test_arena_gating_and_production_costs() -> void:
	var s := _star()
	var d := db()
	var ev := TourRules.evaluate_plan(s, d, _arena_plan(s))
	check(bool(ev["ok"]), "arena plan valid for a tier-7 star: %s" % str(ev["errors"]))
	eq(int(ev["production_cost"]), 2 * int(TourRules.production(d, "standard")["cost"]), "production charged per arena show")
	var spectacle := TourRules.evaluate_plan(s, d, _arena_plan(s, "spectacle"))
	check(int(spectacle["committed"]) > int(ev["committed"]), "a bigger production costs more")
	check(int(ev["opener_cost"]) == 2 * 150 * 5, "openers cost more at arenas")
	s.career_tier = 6
	check(not bool(TourRules.evaluate_plan(s, d, _arena_plan(s))["ok"]), "arenas need the theater-headliner tier")


func test_sellout_and_profit_are_separate() -> void:
	var s := _star(51)
	var d := db()
	var tr: Dictionary = TourRules.book(s, d, _arena_plan(s))["tour"]
	# Force a sellout at a ticket price too low to cover costs on one leg.
	tr["legs"][0]["sold"] = int(tr["legs"][0]["cap"])
	tr["legs"][0]["gross"] = int(tr["legs"][0]["cap"]) * 5
	TourRules.settle_leg(s, d, tr, 0, 80.0)
	eq(int(s.stats.get("arena_sellouts", 0)), 1, "sellout counted")
	eq(int(s.stats.get("arena_profitable", 0)), 0, "but a sellout at $5 isn't profitable")
	check(int(tr["legs"][0]["show_profit"]) < 0, "show profit includes rent and production")
	tr["legs"][1]["sold"] = 9000
	tr["legs"][1]["gross"] = 9000 * 60
	TourRules.settle_leg(s, d, tr, 1, 80.0)
	eq(int(s.stats.get("arena_profitable", 0)), 1, "a profitable show without a sellout counts as profitable")
	eq(int(s.stats.get("arena_sellouts", 0)), 1, "...but not as a sellout")
	eq(int(s.stats.get("arena_sets", 0)), 2, "arena shows counted")


func test_arena_economics_reward_stars_not_newcomers() -> void:
	var d := db()
	var star := _star(52)
	var ev := TourRules.evaluate_plan(star, d, _arena_plan(star))
	check(int(ev["forecast_net"]) > 0, "a big star forecasts an arena profit (%d)" % int(ev["forecast_net"]))
	var mid := _star(53)
	mid.fame = 35.0
	mid.reputation = 60.0
	mid.fans = {}
	var ev2 := TourRules.evaluate_plan(mid, d, _arena_plan(mid))
	check(int(ev2["forecast_net"]) < 0, "a mid-career comic would lose money in arenas (%d)" % int(ev2["forecast_net"]))


func test_mentorship_breakout() -> void:
	var s := _star(54)
	var d := db()
	var op := TourRules.opener_for(s, d, "deshawn")
	var fee0: int = int(op["fee"])
	var fame0 := s.fame
	var notes: Array = []
	for i in range(int(op["breakout_shows"])):
		notes.append_array(TourRules.mentor(s, d, op))
	check(bool(s.flags.get("breakout_deshawn", false)), "Deshawn breaks out after enough shows")
	check(s.fame > fame0, "his breakout pays it forward to you")
	var after := TourRules.opener_for(s, d, "deshawn")
	check(int(after["fee"]) > fee0 and bool(after["broke_out"]), "a broken-out opener costs more")
	var n0 := notes.size()
	TourRules.mentor(s, d, op)
	eq(int(s.stats.get("breakouts", 0)), 1, "breakout happens once")
	check(n0 > 0, "breakout is announced")


func test_panel_scoring_is_contextual() -> void:
	var s := _star(55)
	var d := db()
	s.skills["crowd_work"] = 0.0
	var cocky := {"id": "c1", "name": "A", "persona": "cocky", "style": "deadpan", "quality": 50, "bit": "x"}
	var fragile := {"id": "c2", "name": "B", "persona": "fragile", "style": "deadpan", "quality": 50, "bit": "x"}
	var rc := float(PanelRules.score_contribution(s, d, cocky, "roast", [])["value"])
	var rf := float(PanelRules.score_contribution(s, d, fragile, "roast", [])["value"])
	var sf := float(PanelRules.score_contribution(s, d, fragile, "support", [])["value"])
	check(rc > rf + 8.0, "roasting a cocky comic beats roasting a fragile one")
	check(sf > rf, "support works on a fragile comic")
	var dud := {"quality": 25}
	var star := {"quality": 85}
	check(float(PanelRules.score_reaction(dud, "laugh")["value"]) < float(PanelRules.score_reaction(dud, "stone")["value"]), "faking a big laugh for a dud reads as fake")
	check(float(PanelRules.score_reaction(star, "laugh")["value"]) > float(PanelRules.score_reaction(star, "stone")["value"]), "stone-facing a killer reads as jealous")


func test_panel_scouting_and_resolution() -> void:
	var s := _star(56)
	var d := db()
	var comics := PanelRules.generate(s, d, 3)
	eq(comics.size(), 3, "three bucket comics")
	var good := {"id": "panel_x", "name": "Rae Nguyen", "persona": "polished", "style": "absurdist", "quality": 85, "bit": "a goose landlord"}
	check(PanelRules.can_scout(good), "a great set can be scouted")
	PanelRules.scout(s, good)
	PanelRules.scout(s, good)
	eq(s.discovered_openers.size(), 1, "scouted once")
	check(not TourRules.opener_for(s, d, "panel_x").is_empty(), "scouted comic appears as an opener candidate")
	var out := PanelRules.resolve(s, d, s.day, 20.0)
	check(out.size() > 0 and int(s.stats["panel_sets"]) == 1, "panel night resolved")
	eq(PanelRules.resolve(s, d, s.day, 20.0).size(), 0, "resolved once")


func test_panel_offer_creates_booking() -> void:
	var s := _star(57)
	var d := db()
	s.career_tier = 6
	var o := OpportunityRules.create_offer(s, d, "opp_kt_panel", s.day)
	eq(CalendarRules.weekday(int(o["day"])), CalendarRules.MONDAY, "panel nights are Mondays")
	check(bool(OpportunityRules.accept(s, d, str(o["id"]))["ok"]), "accepted")
	while s.day < int(o["day"]):
		GameSim.advance(s, d, 4, true)
	s.block = 2
	var found := false
	for a in GameSim.actions_for(s, d, "mothership"):
		if str(a["id"]) == "kt_panel":
			found = true
	check(found, "the panel seat action appears at the Mothership on the night")


func test_legacy_tiers_reachable() -> void:
	var s := _star(58)
	var d := db()
	s.career_tier = 0
	for k in ["sets", "paid_sets", "opener_sets", "road_sets", "headline_sets", "theater_sets"]:
		s.stats[k] = 20
	s.stats["arena_sets"] = 3
	s.stats["talent_helped"] = 6
	s.stats["panel_sets"] = 1
	CareerRules.update(s, d)
	eq(s.career_tier, 9, "established star and mentor reachable")
	eq(CareerRules.tier_name(d, 9), "Established star and mentor", "final tier name")
