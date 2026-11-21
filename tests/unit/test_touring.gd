extends TestCase
## Phase 4: tour planning, cash flow, settlements, cancellations, road offers.


func _tour_ready_state(seed_value: int = 40) -> GameState:
	var s := new_state(seed_value)
	s.career_tier = 6
	s.fame = 30.0
	s.reputation = 60.0
	s.cash = 5000
	return s


func _plan(s: GameState) -> Dictionary:
	return {"start_day": s.day + 3, "legs": [{"market": "houston", "venue_type": "club"}, {"market": "dallas", "venue_type": "club"}],
		"price": 25, "marketing": 400, "transport": "van", "lodging": "motel", "opener": "deshawn"}


func test_tour_cash_flow() -> void:
	var s := _tour_ready_state()
	var d := db()
	var cash0 := s.cash
	var ev := TourRules.evaluate_plan(s, d, _plan(s))
	check(bool(ev["ok"]), "plan valid: %s" % str(ev["errors"]))
	var res := TourRules.book(s, d, _plan(s))
	check(bool(res["ok"]), "tour booked")
	var tr: Dictionary = res["tour"]
	eq(s.cash, cash0 - int(ev["upfront"]), "booking charges only deposits + marketing")
	check(int(ev["forecast_revenue"]) > 0, "there is a forecast")
	check(s.cash < cash0, "forecast revenue is never added to cash")
	# Travel to the start day and depart.
	while s.day < int(tr["start_day"]):
		GameSim.advance(s, d, 1, true)
	eq(s.block, 0, "departure morning")
	var cash_before_depart := s.cash
	var dep := TourRules.depart(s, d, str(tr["id"]))
	check(bool(dep["ok"]), "departed")
	eq(s.cash, cash_before_depart - int(tr["committed"]), "committed costs charged at departure")
	var paid := 0
	for i in range(tr["legs"].size()):
		TourRules.travel_event(s, d, tr, i)
		var sold := TourRules.sell_leg(s, d, tr, i)
		check(sold >= 0 and sold <= int(tr["legs"][i]["cap"]), "sales within capacity")
		eq(TourRules.sell_leg(s, d, tr, i), sold, "sales are stored, not rerolled")
		var st := TourRules.settle_leg(s, d, tr, i, 70.0)
		paid += int(st["payout"])
		check(not bool(TourRules.settle_leg(s, d, tr, i, 70.0)["ok"]), "a leg settles only once")
	var delays := 0
	for leg in tr["legs"]:
		if str(leg["event"]) != "none":
			delays += 1
	var sm := TourRules.finish(s, d, tr)
	eq(int(sm["revenue"]), paid, "revenue = settlements")
	eq(int(sm["profit"]), paid - int(tr["deposits"]) - int(tr["marketing"]) - int(tr["committed"]), "profit = settlements - all costs")
	var living := 0
	for e in s.ledger:
		if str(e["reason"]) == "Food & essentials":
			living += -int(e["amount"])
	if delays == 0:
		eq(s.cash - cash0 + living, int(sm["profit"]), "cash change matches tour profit (plus daily living costs)")
	eq(str(tr["status"]), "done", "tour done")
	check(int(s.stats.get("headline_sets", 0)) == 2, "headline sets counted")
	check(int(s.fans.get("houston", 0)) > 0, "good shows build local fans")
	check(int(s.stats.get("talent_helped", 0)) == 2, "bringing Deshawn along is tracked")


func test_cancel_forfeits_deposits() -> void:
	var s := _tour_ready_state(41)
	var d := db()
	var res := TourRules.book(s, d, _plan(s))
	var tr: Dictionary = res["tour"]
	var cash_after_booking := s.cash
	var rep0 := s.reputation
	var c := TourRules.cancel(s, d, str(tr["id"]))
	check(bool(c["ok"]), "cancelled")
	eq(s.cash, cash_after_booking, "deposits and marketing are not refunded")
	check(s.reputation < rep0, "cancelling costs reputation")
	eq(str(Scheduler.find(s, str(tr["commitment_id"]))["status"]), "cancelled", "calendar freed")
	check(not bool(TourRules.cancel(s, d, str(tr["id"]))["ok"]), "can't cancel twice")


func test_missing_departure_cancels() -> void:
	var s := _tour_ready_state(42)
	var d := db()
	var tr: Dictionary = TourRules.book(s, d, _plan(s))["tour"]
	while s.day <= int(tr["start_day"]):
		GameSim.advance(s, d, 1, true)
	eq(str(tr["status"]), "cancelled", "sleeping through departure cancels the tour")


func test_demand_responds_to_choices() -> void:
	var s := _tour_ready_state(43)
	var d := db()
	var base := float(TourRules.demand(s, d, "houston", 25, 0.0, 10)["people"])
	check(float(TourRules.demand(s, d, "houston", 50, 0.0, 10)["people"]) < base, "higher prices sell fewer tickets")
	check(float(TourRules.demand(s, d, "houston", 25, 400.0, 10)["people"]) > base, "marketing sells more")
	s.fame += 20.0
	check(float(TourRules.demand(s, d, "houston", 25, 0.0, 10)["people"]) > base, "fame draws crowds")
	s.flags["tour_last_houston"] = 5
	check(float(TourRules.demand(s, d, "houston", 25, 0.0, 10)["people"]) < base * 1.5, "playing a city again too soon hurts")


func test_plan_rules() -> void:
	var s := _tour_ready_state(44)
	var d := db()
	var p := _plan(s)
	p["legs"] = [{"market": "chicago", "venue_type": "club"}]
	check(not bool(TourRules.evaluate_plan(s, d, p)["ok"]), "the van can't reach Chicago")
	p["transport"] = "flight"
	check(bool(TourRules.evaluate_plan(s, d, p)["ok"]), "flying works")
	p["legs"] = [{"market": "london", "venue_type": "club"}]
	check(not bool(TourRules.evaluate_plan(s, d, p)["ok"]), "London needs more fame")
	s.career_tier = 4
	p["legs"] = [{"market": "houston", "venue_type": "theater"}]
	check(not bool(TourRules.evaluate_plan(s, d, p)["ok"]), "theaters need a higher career tier")
	s.career_tier = 2
	check(not bool(TourRules.can_plan(s, d)["ok"]), "headline tours need the opening-act tier")
	s.career_tier = 6
	s.cash = 10
	check(not bool(TourRules.evaluate_plan(s, d, _plan(s))["ok"]), "can't book what you can't afford")


func test_tour_blocks_calendar() -> void:
	var s := _tour_ready_state(45)
	var d := db()
	var tr: Dictionary = TourRules.book(s, d, _plan(s))["tour"]
	var conf := Scheduler.conflicts(s, int(tr["start_day"]) + 1, 2, 1)
	eq(conf.size(), 1, "an Austin booking during the tour is flagged as a conflict")


func test_road_offer_as_opener() -> void:
	var s := new_state(46)
	var d := db()
	s.career_tier = 4
	s.reputation = 45.0
	var o := OpportunityRules.create_offer(s, d, "road_lonnie_texas", s.day)
	eq(str(o["kind"]), "road", "road offer created")
	var r := OpportunityRules.accept(s, d, str(o["id"]))
	check(bool(r["ok"]), "road run accepted")
	var tr: Dictionary = s.tours.back()
	eq(str(tr["role"]), "opener", "you're the opener")
	eq(int(tr["committed"]), 0, "travel covered")
	while s.day < int(tr["start_day"]):
		GameSim.advance(s, d, 1, true)
	var cash0 := s.cash
	check(bool(TourRules.depart(s, d, str(tr["id"]))["ok"]), "departed")
	for i in range(tr["legs"].size()):
		TourRules.sell_leg(s, d, tr, i)
		TourRules.settle_leg(s, d, tr, i, 60.0)
	TourRules.finish(s, d, tr)
	eq(s.cash - cash0, 300, "paid $150 per show")
	eq(int(s.stats.get("road_sets", 0)), 2, "road sets counted")
	s.stats["road_sets"] = 3
	s.stats["sets"] = 20
	s.stats["paid_sets"] = 4
	s.stats["opener_sets"] = 1
	s.career_tier = 0
	CareerRules.update(s, d)
	eq(s.career_tier, 5, "touring opener tier reachable")
