extends TestCase


func test_calendar_advancement() -> void:
	var s := new_state()
	eq(CalendarRules.day_name(0), "Wednesday", "arrival day is a Wednesday")
	eq(s.block, 1, "game starts in the afternoon")
	GameSim.advance(s, db(), 3)
	eq(s.day, 1, "three blocks from afternoon rolls into the next day")
	eq(s.block, 0, "next day starts in the morning")
	eq(CalendarRules.next_weekday(0, CalendarRules.MONDAY), 5, "first Monday is day 5")
	eq(CalendarRules.weekday(CalendarRules.next_weekday(3, CalendarRules.THURSDAY)), CalendarRules.THURSDAY, "next Thursday is a Thursday")


func test_all_nighter_penalty_and_sleep() -> void:
	var s := new_state()
	s.housing_id = "bunkhouse"
	s.block = 3
	var e0 := s.energy
	GameSim.advance(s, db(), 1)
	check(s.energy < e0, "staying up past late night costs energy")
	s.block = 2
	s.energy = 20
	var res := GameSim.sleep(s, db())
	check(bool(res["ok"]), "can sleep with housing")
	eq(s.block, 0, "sleep ends in the morning")
	check(s.energy > 20, "sleep restores energy")


func test_scheduling_conflicts() -> void:
	var s := new_state()
	var d := db()
	var a := Scheduler.add(s, d, {"kind": "booking", "title": "A", "day": 2, "block": 2, "length": 1, "location_id": "lantern", "npc": "bea"})
	check(bool(a["ok"]), "first booking accepted")
	var b := Scheduler.add(s, d, {"kind": "booking", "title": "B", "day": 2, "block": 2, "length": 1, "location_id": "cellar"})
	check(not bool(b["ok"]), "overlapping booking refused without confirmation")
	eq((b["conflicts"] as Array).size(), 1, "conflict reported")
	eq(Scheduler.booked(s).size(), 1, "original booking untouched")
	var c := Scheduler.add(s, d, {"kind": "booking", "title": "B", "day": 2, "block": 2, "length": 1, "location_id": "cellar"}, true)
	check(bool(c["ok"]), "forced booking accepted after confirmation")
	eq(str(Scheduler.find(s, str(a["commitment"]["id"]))["status"]), "missed", "replaced booking explicitly marked missed")
	var multi := Scheduler.conflicts(s, 2, 1, 2)
	eq(multi.size(), 1, "two-block activity starting afternoon overlaps evening booking")
	eq(Scheduler.conflicts(s, 2, 0, 2).size(), 0, "morning+afternoon activity does not overlap evening")


func test_missed_commitment_when_time_passes() -> void:
	var s := new_state()
	var d := db()
	s.rel("bea")["trust"] = 10
	Scheduler.add(s, d, {"kind": "booking", "title": "Showcase", "day": 0, "block": 2, "length": 1, "location_id": "lantern", "npc": "bea"})
	GameSim.advance(s, d, 2)
	var c: Dictionary = s.commitments[0]
	eq(str(c["status"]), "missed", "booking missed after its block passes")
	check(int(s.rel("bea")["trust"]) < 10, "missing a booking costs trust")


func test_activity_conflict_detection() -> void:
	var s := new_state()
	var d := db()
	Scheduler.add(s, d, {"kind": "booking", "title": "Mic", "day": 0, "block": 2, "length": 1, "location_id": "rusty_spur"})
	var conf := GameSim.conflicts_for(s, {"id": "work", "blocks": 2, "params": {}})
	eq(conf.size(), 1, "a 2-block shift starting in the afternoon warns about the evening booking")
