extends TestCase


func test_bucket_draw_without_replacement() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 5
	var order := KillTonyRules.draw_order(r, 50, 8)
	eq(order.size(), 8, "pulls the configured number of names")
	var seen: Dictionary = {}
	for i in order:
		check(not seen.has(i), "no entrant pulled twice")
		seen[i] = true
		check(int(i) >= 0 and int(i) < 50, "pulled index is an entrant")


func test_bucket_odds_are_fair() -> void:
	var hits := 0
	var trials := 4000
	for t in range(trials):
		var r := RandomNumberGenerator.new()
		r.seed = t * 7919 + 1
		if KillTonyRules.draw_order(r, 40, 8).has(0):
			hits += 1
	var rate := float(hits) / trials
	check(rate > 0.17 and rate < 0.23, "selection rate ~ pulls/entrants = 0.20 (got %.3f)" % rate)


func test_fame_does_not_change_draw() -> void:
	var a := new_state(31)
	var b := new_state(31)
	b.fame = 100.0
	b.reputation = 100.0
	var da := KillTonyRules.ensure_draw(a, db(), 5)
	var dbb := KillTonyRules.ensure_draw(b, db(), 5)
	eq(bool(da["selected"]), bool(dbb["selected"]), "fame does not alter selection")
	eq(int(da["entrants"]), int(dbb["entrants"]), "same entrants")


func test_signup_rules() -> void:
	var s := new_state()
	var d := db()
	check(not bool(KillTonyRules.can_signup(s, d)["ok"]), "no signup on a Wednesday")
	while CalendarRules.weekday(s.day) != 0:
		GameSim.advance(s, d, 4, true)
	s.block = 0
	var res := KillTonyRules.signup(s, d)
	check(bool(res["ok"]), "Monday morning signup works")
	var c: Dictionary = res["commitment"]
	eq(int(c["block"]), 2, "signup reserves the evening block")
	check(not bool(KillTonyRules.signup(s, d)["ok"]), "cannot sign up twice")


func test_reload_does_not_reroll() -> void:
	var s := new_state(99)
	var d := db()
	var first := KillTonyRules.ensure_draw(s, d, 5)
	var json := JSON.stringify(s.to_dict())
	var loaded := GameState.from_dict(JSON.parse_string(json))
	var again := KillTonyRules.ensure_draw(loaded, d, 5)
	eq(bool(again["selected"]), bool(first["selected"]), "reloaded save shows the same draw result")
	eq(int(again["position"]), int(first["position"]), "same position")
	eq(str(again["names"]), str(first["names"]), "same names")


func test_forced_bucket_and_golden_ticket() -> void:
	var s := new_state(1)
	var d := db()
	s.flags["dev_force_bucket"] = "selected"
	check(bool(KillTonyRules.ensure_draw(s, d, 5)["selected"]), "dev force selects")
	check(not s.flags.has("dev_force_bucket"), "force flag consumed")
	var found_unselected := false
	for seed_value in range(1, 200):
		var t := new_state(seed_value)
		t.kt["golden_tickets"] = 1
		var dr := KillTonyRules.ensure_draw(t, d, 5)
		check(bool(dr["selected"]), "golden ticket guarantees a spot")
		if bool(dr["golden"]):
			found_unselected = true
			eq(int(t.kt["golden_tickets"]), 0, "ticket consumed when it was needed")
	check(found_unselected, "golden ticket used at least once in 200 draws")


func test_reward_idempotency() -> void:
	var s := new_state(3)
	var d := db()
	var out1 := KillTonyRules.resolve_rewards(s, d, 5, 90.0, 80.0)
	var books_after := s.books.size()
	var fame_after := s.fame
	var offers_after := s.opportunities.size()
	var out2 := KillTonyRules.resolve_rewards(s, d, 5, 90.0, 80.0)
	check(out1.size() >= 3, "a great night yields several independent outcomes")
	eq(out2.size(), 0, "resolving the same night again grants nothing")
	eq(s.books.size(), books_after, "no duplicate joke books")
	eq(s.fame, fame_after, "no duplicate visibility")
	eq(s.opportunities.size(), offers_after, "no duplicate offers")
	check(s.books.has("large_book"), "a 90 set earns a large joke book")
	var has_secret := false
	for o in s.opportunities:
		if str(o["template"]) == "opp_secret_show":
			has_secret = true
			eq(CalendarRules.weekday(int(o["day"])), CalendarRules.THURSDAY, "Secret Show is on a Thursday")
	check(has_secret, "strong set + interview gets a Secret Show invitation")


func test_outcomes_are_not_a_ladder() -> void:
	var s := new_state(4)
	var out := KillTonyRules.resolve_rewards(s, db(), 5, 75.0, 20.0)
	var ids: Array = out.map(func(o): return str(o["id"]))
	check(not ids.has("medium_book"), "a bad interview can cost the book even after a good set")
	check(ids.has("opening_offer"), "but a good set can still get an opening invitation")


func test_interview_tones_are_contextual() -> void:
	var d := db()
	var p: Dictionary = {"tone_mods": {}}
	var self_dep := {"tone": "self_deprecating", "base": 3}
	var confident := {"tone": "confident", "base": 3}
	var low_sd := float(KillTonyRules.score_response(d, p, self_dep, 30.0, [])["value"])
	var low_cf := float(KillTonyRules.score_response(d, p, confident, 30.0, [])["value"])
	var high_sd := float(KillTonyRules.score_response(d, p, self_dep, 90.0, [])["value"])
	var high_cf := float(KillTonyRules.score_response(d, p, confident, 90.0, [])["value"])
	check(low_sd > low_cf, "after bombing, self-deprecation beats confidence")
	check(high_cf > high_sd, "after killing, confidence beats self-deprecation")
	var repeated := float(KillTonyRules.score_response(d, p, self_dep, 30.0, ["self_deprecating", "self_deprecating"])["value"])
	check(repeated < low_sd, "repeating the same tone loses value")


func test_secret_show_booking_conflict_check() -> void:
	var s := new_state(5)
	var d := db()
	var o := OpportunityRules.create_offer(s, d, "opp_secret_show", s.day)
	Scheduler.add(s, d, {"kind": "booking", "title": "Other gig", "day": int(o["day"]), "block": 2, "length": 1, "location_id": "cellar"})
	var r := OpportunityRules.accept(s, d, str(o["id"]))
	check(not bool(r["ok"]), "accepting a conflicting invitation is refused without confirmation")
	var r2 := OpportunityRules.accept(s, d, str(o["id"]), true)
	check(bool(r2["ok"]), "accepted after confirmation")
	var missed := 0
	for c in s.commitments:
		if str(c["status"]) == "missed":
			missed += 1
	eq(missed, 1, "the replaced booking is explicitly marked missed, not silently dropped")
