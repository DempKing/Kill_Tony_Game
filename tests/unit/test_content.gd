extends TestCase


func test_content_validates() -> void:
	var d := db()
	eq(d.errors.size(), 0, "content has no validation errors: %s" % str(d.errors))


func test_content_targets() -> void:
	var d := db()
	eq(d.families.size(), 12, "twelve joke families")
	check(d.components.size() >= 60, "at least sixty component records (%d)" % d.components.size())
	eq(d.npcs.size(), 8, "eight recurring fictional NPCs")
	eq(d.audiences.size(), 6, "six audience profiles")
	check(d.interviews.size() >= 15, "fifteen interview prompts (%d)" % d.interviews.size())
	check(d.opportunities.size() >= 10, "ten career opportunities (%d)" % d.opportunities.size())
	check(d.world_events.size() >= 20, "world events (%d of the 25 target)" % d.world_events.size())
	eq(d.jobs.size(), 4, "three job types plus emergency day labor")


func test_every_family_has_a_coherent_joke() -> void:
	var d := db()
	for fam in d.families:
		var parts: Dictionary = {}
		for c in d.family_components(fam):
			var t: String = str(c["type"])
			if t in ["premise", "setup", "punchline"] and not parts.has(t):
				parts[t] = str(c["id"])
		eq(str(JokeRules.evaluate(d, parts)["status"]), "coherent", "%s can form a coherent joke" % fam)


func test_partner_content_is_separate() -> void:
	var d := db()
	eq(str(d.partner.get("approval_status", "")), "pending_partner_review", "partner package is flagged as unapproved")
	for id in d.npcs:
		check(not str(id).begins_with("partner_"), "real/partner figures are not mixed into fictional NPC data")
