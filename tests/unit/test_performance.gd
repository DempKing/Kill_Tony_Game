extends TestCase


func _run(sim: PerformanceSim, policy: String) -> Dictionary:
	while sim.has_next():
		sim.perform_next()
		var ch := sim.available_choices()
		if ch.is_empty():
			continue
		var pick: String = str(ch[0]["id"])
		for c in ch:
			if str(c["id"]) == policy:
				pick = policy
		sim.choose(pick)
	return sim.finish()


func _set_state(seed_value: int, prepared: bool) -> GameState:
	var s := new_state(seed_value)
	var ids: Array = []
	for fam in ["fam_heat", "fam_bucket"]:
		ids.append(make_joke(s, fam, prepared, prepared))
	if prepared:
		for jid in ids:
			s.jokes[jid]["familiarity"] = 80
			JokeRules.revise_joke(s, db(), jid, JokeRules.parts_of(s.jokes[jid]), 3)
		s.skills["delivery"] = 25.0
		s.confidence = 55
	SetRules.save_setlist(s, SetRules.DEFAULT_ID, "", ids)
	return s


func test_performance_determinism() -> void:
	var s := _set_state(1, false)
	var ids := SetRules.jokes_in(s, SetRules.DEFAULT_ID)
	var a := _run(PerformanceSim.build(s, db(), "spur_open_mic", ids, 4242), "continue")
	var b := _run(PerformanceSim.build(s, db(), "spur_open_mic", ids, 4242), "continue")
	eq(snappedf(float(a["score"]), 0.001), snappedf(float(b["score"]), 0.001), "same seed and choices give the same result")
	eq(a["results"].size(), b["results"].size(), "same number of jokes performed")


func test_decisions_change_outcome() -> void:
	## Over many seeds, different policies must produce different results:
	## no decorative choices.
	var s := _set_state(2, false)
	var ids := SetRules.jokes_in(s, SetRules.DEFAULT_ID)
	var diffs := 0
	for seed_value in range(1, 60):
		var a := _run(PerformanceSim.build(s, db(), "spur_open_mic", ids, seed_value), "push")
		var b := _run(PerformanceSim.build(s, db(), "spur_open_mic", ids, seed_value), "acknowledge")
		var c := _run(PerformanceSim.build(s, db(), "spur_open_mic", ids, seed_value), "crowd")
		if absf(float(a["score"]) - float(b["score"])) > 0.01 or absf(float(a["score"]) - float(c["score"])) > 0.01:
			diffs += 1
	check(diffs > 20, "choices change outcomes in most sets (%d/59)" % diffs)


func test_preparation_improves_results() -> void:
	var raw := _set_state(3, false)
	var prep := _set_state(3, true)
	var raw_ids := SetRules.jokes_in(raw, SetRules.DEFAULT_ID)
	var prep_ids := SetRules.jokes_in(prep, SetRules.DEFAULT_ID)
	var raw_total := 0.0
	var prep_total := 0.0
	for seed_value in range(100, 300):
		raw_total += float(_run(PerformanceSim.build(raw, db(), "spur_open_mic", raw_ids, seed_value), "continue")["score"])
		prep_total += float(_run(PerformanceSim.build(prep, db(), "spur_open_mic", prep_ids, seed_value), "continue")["score"])
	check(prep_total / 200.0 > raw_total / 200.0 + 10.0, "better preparation improves average results (raw %.1f vs prepared %.1f)" % [raw_total / 200.0, prep_total / 200.0])


func test_fame_does_not_make_sets_good() -> void:
	var s := _set_state(4, false)
	var ids := SetRules.jokes_in(s, SetRules.DEFAULT_ID)
	var a := _run(PerformanceSim.build(s, db(), "spur_open_mic", ids, 99), "continue")
	s.fame = 100.0
	s.reputation = 100.0
	var b := _run(PerformanceSim.build(s, db(), "spur_open_mic", ids, 99), "continue")
	eq(snappedf(float(a["score"]), 0.001), snappedf(float(b["score"]), 0.001), "fame and reputation are not performance inputs")


func test_weak_set_gives_feedback() -> void:
	var s := new_state(5)
	s.energy = 15
	s.stress = 80
	var ids: Array = s.jokes.keys()
	var r := _run(PerformanceSim.build(s, db(), "spur_open_mic", ids, 7), "push")
	check(float(r["score"]) < 45.0, "starter joke while exhausted is a weak set")
	check(not (r["suggestions"] as Array).is_empty(), "weak sets produce specific suggestions")
	var f: Dictionary = r["results"][0]["factors"]
	for k in ["material", "delivery", "warmth", "fit", "momentum", "exposure", "difficulty", "condition", "extras", "luck"]:
		check(f.has(k), "factor %s recorded for explanation" % k)


func test_overrun_and_kill_tony_playoff() -> void:
	var s := new_state(6)
	var ids: Array = []
	for fam in ["fam_heat", "fam_bucket", "fam_coffee", "fam_delivery"]:
		ids.append(make_joke(s, fam, false, true))
	var sim := PerformanceSim.build(s, db(), "kill_tony", ids, 11)
	var r := _run(sim, "tag")
	check(bool(r["played_off"]), "running far past the minute at Kill Tony gets you played off")
	check(float(r["overrun_penalty"]) > 0.0, "overrun penalized")


func test_bombing_teaches() -> void:
	var s := new_state(8)
	var d := db()
	s.energy = 10
	s.stress = 90
	s.confidence = 0
	SetRules.save_setlist(s, SetRules.DEFAULT_ID, "", s.jokes.keys())
	var b := GameSim.begin_performance(s, d, "spur_open_mic", SetRules.DEFAULT_ID, "")
	var sim := GameSim.build_sim(s, d, b["context"])
	var summary := _run(sim, "push")
	summary["score"] = 10.0
	GameSim.apply_performance(s, d, b["context"], summary)
	check(s.components.has("comp_bombing_p"), "bombing unlocks new material")
	var again := GameSim.apply_performance(s, d, b["context"], summary)
	check(not bool(again["ok"]), "a performance is applied exactly once")
