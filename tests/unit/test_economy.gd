extends TestCase


func test_rent_and_income() -> void:
	var s := new_state()
	var d := db()
	GameSim.run_action(s, d, {"id": "rent_bunk", "params": {}})
	eq(s.housing_id, "bunkhouse", "rented a bunk")
	eq(int(s.rent["next_due_day"]), 7, "first rent due in a week")
	s.cash = 500
	while s.day < 7:
		GameSim.advance(s, d, 1, true)
	var rent_paid := false
	for e in s.ledger:
		if str(e["reason"]).begins_with("Rent") and int(e["amount"]) == -140:
			rent_paid = true
	check(rent_paid, "rent of $140 charged on day 7")
	eq(int(s.rent["debt"]), 0, "no debt when affordable")
	eq(int(s.rent["next_due_day"]), 14, "next rent due a week later")


func test_shift_income_and_daily_limit() -> void:
	var s := new_state()
	var d := db()
	JobRules.hire(s, d, "delivery")
	var cash0 := s.cash
	for i in range(3):
		var opts := JobRules.shift_options(s, d, "delivery")
		check(bool(opts[0]["enabled"]), "delivery run %d available" % i)
		JobRules.begin_shift(s, d, "delivery", "run")
		var r := GameSim.finish_shift(s, d, [0, 0])
		check(bool(r["ok"]), "shift resolved")
		s.block = 1
		s.energy = 100
	check(s.cash > cash0, "delivery earns money")
	var opts2 := JobRules.shift_options(s, d, "delivery")
	check(not bool(opts2[0]["enabled"]), "daily delivery limit prevents unlimited money")


func test_shift_idempotent() -> void:
	var s := new_state()
	var d := db()
	JobRules.hire(s, d, "server")
	s.block = 0
	JobRules.begin_shift(s, d, "server", "lunch")
	var shift: Dictionary = s.flags["active_shift"].duplicate(true)
	var r1 := JobRules.finish_shift(s, d, [0, 0])
	var cash_after := s.cash
	s.flags["active_shift"] = shift
	var r2 := JobRules.finish_shift(s, d, [0, 0])
	check(bool(r1["ok"]) and not bool(r2["ok"]), "same shift cannot be paid twice")
	eq(s.cash, cash_after, "no double payment")


func test_recovery_from_low_cash() -> void:
	var s := new_state()
	var d := db()
	GameSim.run_action(s, d, {"id": "rent_bunk", "params": {}})
	s.cash = 0
	for i in range(15 * 4):
		GameSim.advance(s, d, 1, true)
		check(s.cash >= 0, "cash never negative")
	eq(s.housing_id, "deshawn_couch", "two missed rents move you to a free couch, not the street")
	check(int(s.rent["debt"]) > 0, "debt recorded")
	var debt_before := int(s.rent["debt"])
	GameSim.advance(s, d, 28, true)
	eq(int(s.rent["debt"]), debt_before, "debt does not grow while on the free couch")
	# Emergency work is always there in the morning.
	s.block = 0
	s.energy = 80
	var opts := JobRules.shift_options(s, d, "day_labor")
	check(not opts.is_empty() and bool(opts[0]["enabled"]), "emergency day labor available")
	s.cash = debt_before
	var r := WorldRules.pay_debt(s, d)
	check(bool(r["ok"]), "debt can be paid off")
	eq(s.housing_id, "bunkhouse", "paying the debt returns your bunk")


func test_survive_four_weeks_reasonable_player() -> void:
	## A simple 'reasonable' policy: rent the bunk, take the server job, work
	## lunch most days, do an open mic some evenings, sleep every night.
	var s := new_state(777)
	var d := db()
	GameSim.run_action(s, d, {"id": "rent_bunk", "params": {}})
	JobRules.hire(s, d, "server")
	SetRules.save_setlist(s, SetRules.DEFAULT_ID, "", s.jokes.keys())
	var min_cash := s.cash
	while s.day < 28:
		if s.block == 0 and CalendarRules.weekday(s.day) != 6:
			JobRules.begin_shift(s, d, "server", "lunch")
			GameSim.finish_shift(s, d, [0, 0])
		elif s.block == 2 and CalendarRules.weekday(s.day) in [2, 4] and s.cash > 20:
			var b := GameSim.begin_performance(s, d, "spur_open_mic", SetRules.DEFAULT_ID, "")
			if bool(b["ok"]):
				var sim := GameSim.build_sim(s, d, b["context"])
				while sim.has_next():
					sim.perform_next()
					var ch := sim.available_choices()
					if not ch.is_empty():
						sim.choose(str(ch[0]["id"]))
				GameSim.apply_performance(s, d, b["context"], sim.finish())
		elif s.block >= 2:
			GameSim.sleep(s, d)
		else:
			GameSim.advance(s, d, 1)
		min_cash = mini(min_cash, s.cash)
	check(s.cash > 0, "reasonable player still has cash after four weeks (has $%d)" % s.cash)
	eq(s.housing_id, "bunkhouse", "reasonable player keeps their bunk")
	eq(int(s.rent["debt"]), 0, "no rent debt")
	check(min_cash >= 0, "cash never negative")
