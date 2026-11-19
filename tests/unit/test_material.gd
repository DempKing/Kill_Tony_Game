extends TestCase


func test_joke_compatibility() -> void:
	var d := db()
	var coherent := JokeRules.evaluate(d, {"premise": "comp_heat_p", "setup": "comp_heat_s", "punchline": "comp_heat_u2"})
	eq(str(coherent["status"]), "coherent", "same-family pieces are coherent")
	var weak := JokeRules.evaluate(d, {"premise": "comp_heat_p", "setup": "comp_heat_s", "punchline": "comp_scooter_u2"})
	eq(str(weak["status"]), "weak", "different family sharing a topic (austin) is weak")
	var bad := JokeRules.evaluate(d, {"premise": "comp_heat_p", "setup": "comp_heat_s", "punchline": "comp_dating_u1"})
	eq(str(bad["status"]), "incompatible", "unrelated families are incompatible")
	var missing := JokeRules.evaluate(d, {"premise": "comp_heat_p", "setup": "comp_heat_s"})
	eq(str(missing["status"]), "missing", "no punchline = incomplete")
	var tagged := JokeRules.evaluate(d, {"premise": "comp_heat_p", "setup": "comp_heat_s", "punchline": "comp_heat_u2", "tag": "comp_heat_t"})
	eq(str(tagged["status"]), "coherent", "matching tag stays coherent")
	var q_good := JokeRules.quality_of_parts(d, {"premise": "comp_heat_p", "setup": "comp_heat_s", "punchline": "comp_heat_u2"}, 0)
	var q_weak := JokeRules.quality_of_parts(d, {"premise": "comp_heat_p", "setup": "comp_heat_s", "punchline": "comp_scooter_u2"}, 0)
	check(q_good > q_weak, "weak links reduce quality")


func test_duration_calculation() -> void:
	var d := db()
	var parts := {"premise": "comp_arrival_p", "setup": "comp_arrival_s", "punchline": "comp_arrival_u1", "tag": "comp_arrival_t"}
	eq(JokeRules.seconds_of_parts(d, parts), 5 + 12 + 6 + 5, "duration sums all parts")
	eq(JokeRules.seconds_of_parts(d, parts, false), 5 + 12 + 6, "core duration excludes optional parts")
	var s := new_state()
	var a := SetRules.analyze(s, d, s.jokes.keys(), 10)
	check(int(a["core_seconds"]) > 10, "starter joke is longer than 10s")
	var over := false
	for w in a["warnings"]:
		if str(w).find("over") >= 0:
			over = true
	check(over, "overrun warning when material exceeds the slot")


func test_callback_ordering() -> void:
	var s := new_state()
	var d := db()
	var heat := make_joke(s, "fam_heat", true)
	JokeRules.unlock_component(s, d, "comp_heat_cb")
	for c in ["comp_bucket_p", "comp_bucket_s", "comp_bucket_u1"]:
		JokeRules.unlock_component(s, d, c)
	for jid in s.jokes:
		s.jokes[jid]["status"] = "complete"
	var res := JokeRules.create_joke(s, d, "bucket with callback", {"premise": "comp_bucket_p", "setup": "comp_bucket_s", "punchline": "comp_bucket_u1", "callback": "comp_heat_cb"})
	check(bool(res["ok"]), "callback joke created")
	var cbj: String = str(res["id"])
	var wrong := SetRules.analyze(s, d, [cbj, heat], 300)
	var right := SetRules.analyze(s, d, [heat, cbj], 300)
	var has_warn := func(a: Dictionary) -> bool:
		for w in a["warnings"]:
			if str(w).find("callback") >= 0:
				return true
		return false
	check(has_warn.call(wrong), "callback before its reference warns")
	check(not has_warn.call(right), "callback after its reference is fine")


func test_wip_capacity_and_books() -> void:
	var s := new_state()
	var d := db()
	eq(s.book_capacity(d), 3, "starter journal holds 3 works in progress")
	for c in d.components:
		JokeRules.unlock_component(s, d, str(c))
	var made := 0
	for fam in ["fam_heat", "fam_scooter", "fam_coffee", "fam_bucket"]:
		var parts: Dictionary = {"premise": "comp_%s_p" % fam.substr(4), "setup": "comp_%s_s" % fam.substr(4), "punchline": "comp_%s_u1" % fam.substr(4)}
		if bool(JokeRules.create_joke(s, d, fam, parts)["ok"]):
			made += 1
	eq(made, 2, "starter joke + 2 new = 3 WIP; the 4th is refused")
	RewardRules.grant_book(s, "small_book")
	eq(s.book_capacity(d), 5, "small book raises capacity to 5")
	check(s.books.has("starter_journal"), "original journal is kept")
	var archived := JokeRules.set_status(s, d, s.jokes.keys()[0], "complete")
	check(bool(archived["ok"]), "jokes can move to the unlimited archive")


func test_revisions_preserve_history() -> void:
	var s := new_state()
	var d := db()
	var jid: String = s.jokes.keys()[0]
	var joke: Dictionary = s.jokes[jid]
	joke["history"].append({"perf": "p1", "rev": 1, "score": 30.0})
	JokeRules.unlock_component(s, d, "comp_arrival_u2")
	var r := JokeRules.revise_joke(s, d, jid, {"premise": "comp_arrival_p", "setup": "comp_arrival_s", "punchline": "comp_arrival_u2"})
	check(bool(r["ok"]), "revision saved")
	eq(int(joke["current_rev"]), 2, "current revision advanced")
	eq(str(JokeRules.revision(joke, 1)["parts"]["punchline"]), "comp_arrival_u1", "old revision unchanged")
	eq(int(joke["history"][0]["rev"]), 1, "performance history still points at rev 1")
	var r2 := JokeRules.revise_joke(s, d, jid, JokeRules.parts_of(joke), 1)
	check(bool(r2["ok"]) and int(JokeRules.current_revision(joke)["polish"]) == 1, "polish creates a new revision")


func test_writing_pity_guarantee() -> void:
	var s := new_state()
	var d := db()
	JokeRules.unlock_component(s, d, "comp_heat_p")
	s.pity["fam_heat"] = d.bali("writing.pity_threshold", 2)
	var before := s.components.size()
	var res := WritingRules.do_task(s, d, {"task": "develop", "family": "fam_heat"}, "hostel")
	check(bool(res["success"]), "pity threshold guarantees a discovery")
	eq(s.components.size(), before + 1, "one component discovered")
	check(s.components.has("comp_heat_s"), "setup is discovered first")


func test_strong_punchline_needs_skill() -> void:
	var s := new_state()
	var d := db()
	for c in ["comp_heat_p", "comp_heat_s", "comp_heat_u1", "comp_heat_t", "comp_heat_cb"]:
		JokeRules.unlock_component(s, d, c)
	s.skills["writing"] = 1.0
	var nd := WritingRules.next_discoverable(s, d, "fam_heat")
	check(str(nd["component"].get("id", "")) != "comp_heat_u2", "strong punchline is locked behind writing skill")
	s.skills["writing"] = 30.0
	nd = WritingRules.next_discoverable(s, d, "fam_heat")
	eq(str(nd["component"].get("id", "")), "comp_heat_u2", "available once writing is high enough")
