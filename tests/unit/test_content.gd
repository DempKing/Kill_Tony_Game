extends TestCase


func test_content_validates() -> void:
	var d := db()
	eq(d.errors.size(), 0, "content has no validation errors: %s" % str(d.errors))


func test_content_targets() -> void:
	var d := db()
	eq(d.families.size(), 22, "twenty-two joke families")
	check(d.components.size() >= 120, "at least 120 component records (%d)" % d.components.size())
	eq(d.npcs.size(), 8, "eight recurring fictional NPCs")
	check(d.audiences.size() >= 6, "at least six audience profiles")
	check(d.interviews.size() >= 18, "eighteen interview prompts (%d)" % d.interviews.size())
	check(d.opportunities.size() >= 10, "ten career opportunities (%d)" % d.opportunities.size())
	check(d.world_events.size() >= 25, "at least 25 world events (%d)" % d.world_events.size())
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


func test_every_family_is_reachable_in_play() -> void:
	## Each family's premise must have a real source: start, a background, an
	## observation, a job, an event, a shift event, or bombing.
	var d := db()
	var sources: Dictionary = {}
	for cid in d.bal("start.starting_components", []):
		sources[str(cid)] = true
	for bg in d.backgrounds.values():
		for cid in bg.get("starting_components", []):
			sources[str(cid)] = true
	for o in d.observations.values():
		for cid in o.get("unlock", []):
			sources[str(cid)] = true
	for j in d.jobs.values():
		for cid in j.get("first_shift_unlock", []):
			sources[str(cid)] = true
	var effect_lists: Array = []
	for ev in d.world_events:
		effect_lists.append(ev.get("choices", []))
	for ev in d.shift_events.values():
		effect_lists.append(ev.get("choices", []))
	for choices in effect_lists:
		for ch in choices:
			for key in ["effects", "fail_effects"]:
				for cid in ch.get(key, {}).get("unlock", []):
					sources[str(cid)] = true
	for c in d.components.values():
		if str(c.get("unlock", "")) == "bomb":
			sources[str(c["id"])] = true
	for fam in d.families:
		var ok := false
		for c in d.family_components(fam):
			if str(c["type"]) == "premise" and sources.has(str(c["id"])):
				ok = true
		check(ok, "%s premise can be obtained in play" % fam)


func test_kill_tony_panel_characters_and_layout() -> void:
	var d := db()
	var chars: Dictionary = d.partner.get("characters", {})
	eq(str(chars.get("partner_host", {}).get("display_name", "")), "Tony Hinchcliffe", "Tony is the host")
	eq(str(chars.get("partner_redban", {}).get("display_name", "")), "Brian Redban", "Redban is present")
	eq(d.character_name("partner_host"), "Tony", "on-screen label")
	eq(d.character_name("partner_redban"), "Redban", "on-screen label")
	check(not bool(chars["partner_host"].get("approved", true)), "real-person content flagged pending approval")
	var panel: Dictionary = d.stage_layout.get("panel", {})
	var guests: Array = panel.get("guest_seats", [])
	eq(guests.size(), 3, "up to three guest seats besides Tony")
	var mic_x := float(d.stage_layout["mic"]["pos"][0])
	var host_x := float(panel["host_seat"][0])
	for g in guests:
		check(absf(mic_x - host_x) < absf(mic_x - float(g[0])), "Tony sits nearest the mic")
	check(d.stage_layout.has("redban_station"), "Redban has his own sound station")
	var rb_x := float(d.stage_layout["redban_station"]["seat"][0])
	for g in guests:
		check(rb_x < float(g[0]), "Redban's station is at the far end of the desk")
	var cnt: Array = d.partner.get("panel_guest_count", [])
	check(int(cnt[1]) <= 3 and int(cnt[0]) >= 1, "1-3 guest comedians per night")
	check((d.partner.get("guest_pool", []) as Array).size() >= 3, "fictional guest pool")


func test_polyhaven_textures_present() -> void:
	for id in ["red_brick_03", "factory_brick", "plastered_wall", "concrete_wall_003", "asphalt_01", "concrete_tiles_02", "gravel_concrete", "wood_floor", "dark_wood", "velour_velvet", "corrugated_iron", "dirty_carpet"]:
		check(Materials.tex(id) != null, "Poly Haven texture %s loads" % id)
