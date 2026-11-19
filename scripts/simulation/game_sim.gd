class_name GameSim
extends RefCounted
## Facade over the simulation rules. Scenes and UI call into GameSim; GameSim
## never touches scenes. Time only advances through GameSim.advance()/sleep().


# --- New game ---------------------------------------------------------------

static func new_game(db: ContentDB, setup: Dictionary, seed_value: int) -> GameState:
	var s := GameState.new()
	s.master_seed = seed_value
	var st: Dictionary = db.bal("start", {})
	s.cash = int(st.get("cash", 180))
	s.energy = int(st.get("energy", 80))
	s.stress = int(st.get("stress", 20))
	s.confidence = int(st.get("confidence", 35))
	s.day = int(st.get("day", 0))
	s.block = int(st.get("block", 1))
	s.location_id = str(st.get("location", "transit_stop"))
	s.housing_id = str(st.get("housing", ""))
	s.skills = (st.get("skills", {}) as Dictionary).duplicate()
	for k in s.skills:
		s.skills[k] = float(s.skills[k])
	var bg_id: String = str(setup.get("background", "server_vet"))
	var bg: Dictionary = db.backgrounds.get(bg_id, {})
	for k in bg.get("skills", {}):
		StatsRules.add_skill(s, str(k), float(bg["skills"][k]))
	s.confidence = clampi(s.confidence + int(bg.get("confidence", 0)), 0, 100)
	s.player = {
		"name": str(setup.get("name", "Alex")),
		"stage_name": str(setup.get("stage_name", setup.get("name", "Alex"))),
		"pronouns": str(setup.get("pronouns", "they")),
		"appearance": setup.get("appearance", {"skin": 0, "hair": 0, "outfit": 0}),
		"background": bg_id,
		"style": str(setup.get("style", "observational")),
		"secondary_style": "",
		"hooks": bg.get("hooks", []),
	}
	for cid in st.get("starting_components", []):
		JokeRules.unlock_component(s, db, str(cid))
	for cid in bg.get("starting_components", []):
		JokeRules.unlock_component(s, db, str(cid))
	SetRules.ensure_defaults(s)
	var sj: Dictionary = st.get("starter_joke", {})
	if not sj.is_empty():
		var res := JokeRules.create_joke(s, db, str(sj.get("title", "First joke")), sj.get("parts", {}))
		if bool(res.get("ok", false)):
			s.jokes[res["id"]]["notes"] = "Written on the bus. It's... a start."
			SetRules.save_setlist(s, SetRules.DEFAULT_ID, "", [res["id"]])
			SetRules.save_setlist(s, SetRules.KT_MINUTE_ID, "", [res["id"]])
	for id in db.location_order:
		if bool(db.locations[id].get("start_known", false)):
			s.discovered_locations.append(id)
	var ps: Array = db.world.get("player_start", [200, 735])
	s.player_pos = Vector2(float(ps[0]), float(ps[1]))
	for stream in GameState.RNG_STREAMS:
		s.rng(str(stream))
	s.flags["tutorial_step"] = "bag"
	s.add_message("You arrive in Austin with $%d, a bag, and a journal of bad jokes." % s.cash)
	return s


# --- Time ---------------------------------------------------------------

## Advances `blocks` blocks. Missed commitments are processed as each block
## ends. Crossing midnight without sleeping is an all-nighter.
static func advance(s: GameState, db: ContentDB, blocks: int, sleeping: bool = false) -> Array:
	var notes: Array = []
	for i in range(blocks):
		var leaving := CalendarRules.slot(s.day, s.block)
		Scheduler.process_missed(s, db, leaving)
		s.block += 1
		if s.block >= CalendarRules.BLOCKS_PER_DAY:
			s.block = 0
			s.day += 1
			if not sleeping:
				StatsRules.change_energy(s, db.bali("time.all_nighter_energy", -15))
				StatsRules.change_stress(s, db.bali("time.all_nighter_stress", 6))
				notes.append("You stayed up all night. You feel it.")
			notes.append_array(WorldRules.start_day(s, db))
	CareerRules.update(s, db)
	return notes


static func home_location(s: GameState, db: ContentDB) -> String:
	return str(db.housing.get(s.housing_id, {}).get("location", ""))


static func blocks_until_morning(s: GameState) -> int:
	return CalendarRules.BLOCKS_PER_DAY - s.block


static func sleep(s: GameState, db: ContentDB) -> Dictionary:
	var h: Dictionary = db.housing.get(s.housing_id, {})
	if h.is_empty():
		return {"ok": false, "message": "You don't have anywhere to sleep yet."}
	var n := blocks_until_morning(s)
	var notes := advance(s, db, n, true)
	var gain: int = int(h.get("rest", 40)) + db.bali("time.sleep_bonus_per_extra_block", 6) * maxi(0, n - 1)
	StatsRules.change_energy(s, gain)
	StatsRules.change_stress(s, int(h.get("stress", -5)))
	var msg := "You sleep at %s. Energy +%d." % [h.get("name", "home"), gain]
	notes.push_front(msg)
	return {"ok": true, "message": "\n".join(PackedStringArray(notes))}


# --- Actions ----------------------------------------------------------------

static func _act(id: String, label: String, blocks: int, hint: String, params: Dictionary = {}, enabled: bool = true, reason: String = "") -> Dictionary:
	return {"id": id, "label": label, "blocks": blocks, "hint": hint, "params": params, "enabled": enabled, "reason": reason}


static func location_open(db: ContentDB, location_id: String, block: int) -> bool:
	var loc: Dictionary = db.locations.get(location_id, {})
	return (loc.get("open_blocks", [0, 1, 2, 3]) as Array).has(block)


static func actions_for(s: GameState, db: ContentDB, location_id: String) -> Array:
	var out: Array = []
	var wd := CalendarRules.weekday(s.day)
	var home := home_location(s, db)
	# Tutorial: the bag at the curb.
	if location_id == "transit_stop" and not s.flags.has("has_bag"):
		out.append(_act("pick_up_bag", "Pick up your bag", 0, "Everything you own is in it."))
	# Bookings that start now at this location.
	for c in Scheduler.current(s):
		if str(c.get("location_id", "")) != location_id:
			continue
		if str(c["kind"]) == "kill_tony":
			out.append(_act("kt_attend", "Kill Tony: wait for the bucket", 1, "Tonight's draw. One block.", {"commitment_id": c["id"]}))
		else:
			out.append(_act("perform_booking", "Perform: %s" % c["title"], 1, "%ds slot. Pay $%d." % [int(c["slot_seconds"]), int(c["pay"])], {"commitment_id": c["id"]}))
	match location_id:
		"hostel":
			if s.housing_id == "":
				out.append(_act("rent_bunk", "Ask Mari about a bunk", 0, "$%d/week, first payment due in a week." % int(db.housing["bunkhouse"]["weekly"])))
			if int(s.rent.get("debt", 0)) > 0:
				out.append(_act("pay_debt", "Pay rent debt ($%d)" % int(s.rent["debt"]), 0, "Clears what you owe Mari."))
			out.append(_act("observe", "Survey the bunk room", 0, "Look for material.", {"obs": "hostel_bunks"}, WorldRules.observation_available(s, db.observations.get("hostel_bunks", {"id": "x"}))))
		"apartments":
			var oak: Dictionary = db.housing.get("oak_room", {})
			if s.housing_id != "oak_room":
				var need: int = int(oak.get("deposit", 0)) + int(oak.get("weekly", 0))
				var ok_tier: bool = s.career_tier >= int(oak.get("min_tier", 0))
				var ok := ok_tier and s.cash >= need and int(s.rent.get("debt", 0)) == 0
				var why := ""
				if not ok_tier:
					why = "The leasing office wants proof of income. Get some sets under your belt first."
				elif int(s.rent.get("debt", 0)) > 0:
					why = "Clear your rent debt first."
				elif s.cash < need:
					why = "Needs $%d (deposit + first week)." % need
				out.append(_act("lease", "Lease a basic room ($%d/week)" % int(oak.get("weekly", 0)), 0, str(oak.get("desc", "")) + " Deposit $%d." % int(oak.get("deposit", 0)), {"housing": "oak_room"}, ok, why))
		"diner":
			if not JobRules.is_hired(s, "server"):
				out.append(_act("hire", "Ask Gus for a server job", 0, "Lunch or dinner shifts, every day.", {"job_id": "server"}))
			else:
				for sh in JobRules.shift_options(s, db, "server"):
					out.append(_act("work", "Work: %s" % sh["label"], int(sh["length"]), "Base pay plus tips. Energy %d." % int(sh["energy"]), sh, bool(sh["enabled"]), str(sh["reason"])))
		"cellar":
			if not JobRules.is_hired(s, "doorman"):
				out.append(_act("hire", "Ask Rhonda about door work", 0, "Evenings till close. Industry access.", {"job_id": "doorman"}))
			else:
				for sh in JobRules.shift_options(s, db, "doorman"):
					out.append(_act("work", "Work: %s" % sh["label"], int(sh["length"]), "Flat pay, small tips, watch sets. Energy %d." % int(sh["energy"]), sh, bool(sh["enabled"]), str(sh["reason"])))
		"transit_stop":
			if JobRules.is_hired(s, "delivery"):
				for sh in JobRules.shift_options(s, db, "delivery"):
					out.append(_act("work", "Work: %s" % sh["label"], int(sh["length"]), "Flexible. Lower, unpredictable pay minus bike costs.", sh, bool(sh["enabled"]), str(sh["reason"])))
		"job_board":
			out.append(_act("read_leads", "Read the job leads", 0, "See who's hiring."))
			if not JobRules.is_hired(s, "delivery"):
				out.append(_act("hire", "Sign up for the delivery app", 0, "Work any block, from the bus stop.", {"job_id": "delivery"}))
			for sh in JobRules.shift_options(s, db, "day_labor"):
				out.append(_act("work", "Emergency: %s" % sh["label"], int(sh["length"]), "$55 cash, hard labor. Always available in the morning.", sh, bool(sh["enabled"]), str(sh["reason"])))
		"coffee":
			out.append(_act("buy", "Buy a coffee ($4)", 0, "Energy +8.", {"item": "coffee", "price": 4, "energy": 8, "stress": 0}, not s.flags.has("bought_%d" % CalendarRules.slot(s.day, s.block)), "You've had enough coffee this block."))
			out.append(_act("observe", "Watch the laptop crowd", 0, "Look for material.", {"obs": "coffee_laptops"}, WorldRules.observation_available(s, db.observations.get("coffee_laptops", {"id": "x"}))))
			if WorldRules.npcs_at(s, db, "coffee").has("deshawn"):
				out.append(_act("workshop", "Workshop jokes with Deshawn", 1, "Trade notes. Builds chemistry; he may help you find a tag.", {"npc": "deshawn"}))
		"mart":
			var bought := s.flags.has("bought_%d" % CalendarRules.slot(s.day, s.block))
			out.append(_act("buy", "Buy a cheap coffee ($3)", 0, "Energy +6.", {"item": "coffee", "price": 3, "energy": 6, "stress": 0}, not bought, "One purchase per block."))
			out.append(_act("buy", "Buy an energy drink ($4)", 0, "Energy +15, stress +4.", {"item": "energy_drink", "price": 4, "energy": 15, "stress": 4}, not bought, "One purchase per block."))
		"rusty_spur":
			var v: Dictionary = db.venues["spur_open_mic"]
			var tonight: bool = (v["weekdays"] as Array).has(wd) and (v["blocks"] as Array).has(s.block)
			var why2 := ""
			if not tonight:
				why2 = "Open mic runs evenings and late night, every night except Monday."
			elif s.flags.has("spur_set_%d" % s.day):
				tonight = false
				why2 = "Dusty only puts you up once a night."
			out.append(_act("open_mic", "Sign up for the open mic ($%d)" % int(v["fee"]), 1, "Three minutes. Respect the light. Audience: %s." % ("bar crowd" if s.block == 3 else "other comics"), {"venue_id": "spur_open_mic"}, tonight, why2))
			if (v["weekdays"] as Array).has(wd) and (v["blocks"] as Array).has(s.block):
				out.append(_act("watch", "Watch the mic", 1, "Learn from other comics' sets. Free.", {"venue_id": "spur_open_mic", "price": 0}))
		"mothership":
			out.append(_act("read_schedule", "Read the schedule", 0, "What's on this week."))
			if wd == CalendarRules.MONDAY:
				var chk := KillTonyRules.can_signup(s, db)
				var signed := false
				for c in Scheduler.booked(s):
					if str(c.get("kind", "")) == "kill_tony" and int(c["day"]) == s.day:
						signed = true
				if not signed:
					out.append(_act("kt_signup", "Put your name in the Kill Tony bucket", 0, "Reserves tonight's %s block. Free." % CalendarRules.block_name(KillTonyRules.show_block(db)), {}, bool(chk["ok"]), str(chk["reason"])))
			if s.block >= 2 and wd != CalendarRules.MONDAY:
				out.append(_act("watch", "Buy a ticket to tonight's show ($20)", 1, "Watch professionals work. Delivery and presence improve.", {"venue_id": "mothership_show", "price": 20}, s.cash >= 20, "Not enough cash."))
		"lantern":
			if [3, 4, 5].has(wd) and s.block == 2:
				out.append(_act("watch", "Watch the headliner ($15)", 1, "Lonnie Szabo is in town. Good for your writing.", {"venue_id": "lantern_show", "price": 15}, s.cash >= 15, "Not enough cash."))
	# Home actions.
	if home != "" and home == location_id:
		var h: Dictionary = db.housing[s.housing_id]
		out.append(_act("sleep", "Sleep until morning", blocks_until_morning(s), "At %s. Rest %d." % [h["name"], int(h["rest"])]))
		out.append(_act("rest", "Rest for a block", 1, "Energy +%d, stress %d." % [db.bali("time.rest_energy", 15), db.bali("time.rest_stress", -8)]))
		out.append(_act("write", "Write in your journal", 1, "Develop premises, polish jokes, or rehearse."))
	elif location_id == "coffee":
		out.append(_act("write", "Write at the corner table", 1, "Writing here is a little easier (+10% discovery)."))
	# NPCs present.
	for npc_id in WorldRules.npcs_at(s, db, location_id):
		out.append(_act("talk", "Talk to %s" % db.npcs[npc_id]["name"], 0, str(db.npcs[npc_id]["role"]), {"npc": npc_id}))
	# Energy gating for timed actions.
	for a in out:
		if int(a["blocks"]) > 0 and a["id"] in ["work", "open_mic", "perform_booking", "workshop", "write"]:
			var cost := _energy_cost(db, a)
			if s.energy - cost < 0 and bool(a["enabled"]):
				a["enabled"] = false
				a["reason"] = "Too exhausted. Rest or sleep first."
	return out


static func _energy_cost(db: ContentDB, a: Dictionary) -> int:
	match str(a["id"]):
		"work":
			return absi(int(a["params"].get("energy", 20)))
		"open_mic", "perform_booking":
			return db.bali("performance.energy_cost", 12)
		"write", "workshop":
			return db.bali("writing.energy_cost", 8)
	return 0


static func conflicts_for(s: GameState, a: Dictionary) -> Array:
	var blocks: int = int(a.get("blocks", 0))
	if blocks <= 0:
		return []
	var ignore: String = str(a.get("params", {}).get("commitment_id", ""))
	return Scheduler.conflicts(s, s.day, s.block, blocks, ignore)


## Runs instant actions or prepares UI-driven ones. Returns
## {ok, message, open?: "writing"|"shift"|"set_builder"|"kill_tony"|"leads"|"schedule"}.
static func run_action(s: GameState, db: ContentDB, a: Dictionary) -> Dictionary:
	var p: Dictionary = a.get("params", {})
	match str(a["id"]):
		"pick_up_bag":
			_tutorial_advance(s, "bag")
			s.flags["has_bag"] = true
			return {"ok": true, "message": "You sling the bag over your shoulder. Clothes, a phone charger, and your joke journal. Press J to open the journal."}
		"rent_bunk":
			s.housing_id = "bunkhouse"
			s.rent = {"next_due_day": s.day + 7, "debt": 0, "missed": 0}
			Relationships.change(s, "mari", {"familiarity": 4, "trust": 2})
			_tutorial_advance(s, "lodging")
			return {"ok": true, "message": "Mari hands you a key on a lanyard. \"Bunk nine. $140 a week, first payment due %s. Don't touch the top-bunk guy's plant.\"" % CalendarRules.day_name(s.day + 7)}
		"pay_debt":
			return WorldRules.pay_debt(s, db)
		"lease":
			var h: Dictionary = db.housing.get(str(p["housing"]), {})
			var total: int = int(h["deposit"]) + int(h["weekly"])
			if not StatsRules.charge(s, total, "Lease: " + str(h["name"])):
				return {"ok": false, "message": "Not enough cash."}
			s.housing_id = str(p["housing"])
			s.rent = {"next_due_day": s.day + 7, "debt": 0, "missed": 0}
			s.flags["moved_oak"] = true
			return {"ok": true, "message": "You sign the lease. A room with a door. Your original journal gets its own shelf."}
		"hire":
			var res := JobRules.hire(s, db, str(p["job_id"]))
			if bool(res["ok"]):
				_tutorial_advance(s, "job")
			return res
		"read_leads":
			return {"ok": true, "open": "leads", "message": _leads_text(s, db)}
		"read_schedule":
			return {"ok": true, "open": "schedule", "message": _schedule_text(s, db)}
		"observe":
			return WorldRules.observe(s, db, str(p["obs"]))
		"talk":
			var npc: String = str(p["npc"])
			var line := WorldRules.talk(s, db, npc)
			if npc == "dusty":
				_tutorial_advance(s, "open_mic_info")
			return {"ok": true, "message": "%s: \"%s\"" % [db.npcs[npc]["name"], line]}
		"buy":
			if not StatsRules.charge(s, int(p["price"]), str(p["item"])):
				return {"ok": false, "message": "Not enough cash."}
			StatsRules.change_energy(s, int(p["energy"]))
			StatsRules.change_stress(s, int(p["stress"]))
			s.flags["bought_%d" % CalendarRules.slot(s.day, s.block)] = true
			return {"ok": true, "message": "That helps."}
		"rest":
			StatsRules.change_energy(s, db.bali("time.rest_energy", 15))
			StatsRules.change_stress(s, db.bali("time.rest_stress", -8))
			var n := advance(s, db, 1)
			n.push_front("You rest for a while.")
			return {"ok": true, "message": "\n".join(PackedStringArray(n))}
		"sleep":
			return sleep(s, db)
		"write":
			return {"ok": true, "open": "writing"}
		"work":
			return {"ok": true, "open": "shift", "shift": JobRules.begin_shift(s, db, str(p["job_id"]), str(p["shift_id"]))}
		"open_mic":
			return {"ok": true, "open": "set_builder", "venue_id": str(p["venue_id"]), "commitment_id": ""}
		"perform_booking":
			var c := Scheduler.find(s, str(p["commitment_id"]))
			return {"ok": true, "open": "set_builder", "venue_id": str(c.get("venue_id", "")), "commitment_id": str(c.get("id", ""))}
		"kt_signup":
			var r := KillTonyRules.signup(s, db, bool(a.get("force", false)))
			return r
		"kt_attend":
			return {"ok": true, "open": "kill_tony", "commitment_id": str(p["commitment_id"])}
		"watch":
			return watch_show(s, db, str(p["venue_id"]), int(p.get("price", 0)))
		"workshop":
			return workshop(s, db, str(p["npc"]))
	return {"ok": false, "message": "Nothing happens."}


static func _tutorial_advance(s: GameState, reached: String) -> void:
	var order: Array = ["bag", "journal", "landmark", "lodging", "job", "open_mic_info", "first_set", "done"]
	var cur := order.find(str(s.flags.get("tutorial_step", "done")))
	var target := order.find(reached)
	if cur < 0 or target < 0:
		return
	# Steps can be completed out of order; the tracker moves past completed ones.
	s.flags["tut_" + reached] = true
	while cur < order.size() - 1 and s.flags.has("tut_" + str(order[cur])):
		cur += 1
	s.flags["tutorial_step"] = order[cur]
	if order[cur] == "done":
		s.flags["tutorial_done"] = true


static func tutorial_mark(s: GameState, step: String) -> void:
	_tutorial_advance(s, step)


static func objective_text(s: GameState) -> String:
	match str(s.flags.get("tutorial_step", "done")):
		"bag": return "Pick up your bag at the bus stop (walk to it and press E)."
		"journal": return "Open your joke journal (J)."
		"landmark": return "Walk east along the main drag and look at the Comedy Mothership."
		"lodging": return "Find somewhere to sleep: talk to Mari at the Bunkhouse Hostel."
		"job": return "Find work: check the notice board, the diner, or The Cellar."
		"open_mic_info": return "Find out how the open mic works at The Rusty Spur (talk to Dusty)."
		"first_set": return "Build a set in your journal, then perform at the Rusty Spur open mic."
	return ""


static func _leads_text(s: GameState, db: ContentDB) -> String:
	var lines: Array = ["JOB LEADS"]
	lines.append("• Big Sky Diner needs servers. Lunch or dinner shifts. Talk to Gus. %s" % ("(hired)" if s.jobs.has("server") else ""))
	lines.append("• The Cellar is hiring door staff, evenings till close. Talk to Rhonda. %s" % ("(hired)" if s.jobs.has("doorman") else ""))
	lines.append("• Delivery app: sign up here, work any block from the bus stop. %s" % ("(signed up)" if s.jobs.has("delivery") else ""))
	lines.append("• MOVERS NEEDED, cash same day, mornings. (Always available.)")
	lines.append("")
	lines.append("OPEN MIC: The Rusty Spur, nightly except Mondays. $5 bar minimum to sign up.")
	return "\n".join(PackedStringArray(lines))


static func _schedule_text(s: GameState, db: ContentDB) -> String:
	var lines: Array = ["COMEDY MOTHERSHIP · THIS WEEK"]
	lines.append("MONDAY: KILL TONY. Bucket signups before the show. Show in the %s." % CalendarRules.block_name(KillTonyRules.show_block(db)))
	lines.append("TUESDAY-SUNDAY EVENINGS: Headline shows. Tickets $20.")
	lines.append("THURSDAY: The Secret Show (invitation only).")
	var next_mon := CalendarRules.next_weekday(s.day, CalendarRules.MONDAY)
	lines.append("")
	lines.append("Next Kill Tony: %s." % ("tonight" if next_mon == s.day else CalendarRules.describe_slot(next_mon, KillTonyRules.show_block(db))))
	if int(s.kt.get("appearances", 0)) > 0:
		lines.append("A staffer recognizes you: \"Hey, you did the show!\"")
	return "\n".join(PackedStringArray(lines))


static func watch_show(s: GameState, db: ContentDB, venue_id: String, price: int) -> Dictionary:
	if price > 0 and not StatsRules.charge(s, price, "Show ticket"):
		return {"ok": false, "message": "Not enough cash."}
	var msg := ""
	match venue_id:
		"spur_open_mic":
			StatsRules.add_skill(s, "crowd_work", 0.4)
			StatsRules.add_skill(s, "delivery", 0.3)
			Relationships.change(s, "dusty", {"familiarity": 2})
			msg = "You watch twelve comics. Three are good. You learn more from the other nine."
		"mothership_show":
			StatsRules.add_skill(s, "delivery", 0.8)
			StatsRules.add_skill(s, "stage_presence", 0.6)
			msg = "You watch a headliner work a packed room. Every pause is on purpose."
		"lantern_show":
			StatsRules.add_skill(s, "writing", 0.8)
			Relationships.change(s, "lonnie", {"familiarity": 2})
			msg = "Lonnie Szabo does forty-five minutes. You fill four pages of notes."
	StatsRules.change_stress(s, -4)
	var n := advance(s, db, 1)
	n.push_front(msg)
	return {"ok": true, "message": "\n".join(PackedStringArray(n))}


static func workshop(s: GameState, db: ContentDB, npc_id: String) -> Dictionary:
	StatsRules.change_energy(s, -db.bali("writing.energy_cost", 8))
	Relationships.change(s, npc_id, {"chemistry": 4, "familiarity": 2, "trust": 1})
	StatsRules.add_skill(s, "writing", 0.6)
	var msg := "You and Deshawn trade bits for an hour."
	# Workshopping can surface a tag for one of your families.
	var r := s.rng("world")
	if r.randf() < 0.5:
		for cid in s.components:
			var fam: String = str(db.component(str(cid)).get("family", ""))
			for c in db.family_components(fam):
				if str(c["type"]) == "tag" and not s.components.has(str(c["id"])):
					JokeRules.unlock_component(s, db, str(c["id"]))
					msg += " He pitches a tag you love: \"%s\"" % c["text"]
					var n0 := advance(s, db, 1)
					n0.push_front(msg)
					return {"ok": true, "message": "\n".join(PackedStringArray(n0))}
	msg += " Nothing new, but he laughed at your stuff and you laughed at his."
	var n := advance(s, db, 1)
	n.push_front(msg)
	return {"ok": true, "message": "\n".join(PackedStringArray(n))}


## Completes a writing task and spends the block.
static func write(s: GameState, db: ContentDB, task: Dictionary, location_id: String) -> Dictionary:
	var res := WritingRules.do_task(s, db, task, location_id)
	if not bool(res.get("ok", false)):
		return res
	var n := advance(s, db, 1)
	n.push_front(str(res["message"]))
	res["message"] = "\n".join(PackedStringArray(n))
	return res


static func finish_shift(s: GameState, db: ContentDB, choices: Array) -> Dictionary:
	var res := JobRules.finish_shift(s, db, choices)
	if not bool(res.get("ok", false)):
		return res
	var n := advance(s, db, int(res["blocks"]))
	var lines: Array = [str(res["message"])]
	lines.append_array(res["notes"])
	lines.append_array(n)
	res["message"] = "\n".join(PackedStringArray(lines))
	return res


# --- Performances -----------------------------------------------------------

## Stores the performance context (including its seed) before the set starts,
## so quitting mid-set and reloading replays the same seeded set.
static func begin_performance(s: GameState, db: ContentDB, venue_id: String, setlist_id: String, commitment_id: String) -> Dictionary:
	var existing: Dictionary = s.flags.get("active_performance", {})
	if not existing.is_empty() and str(existing.get("venue_id", "")) == venue_id and str(existing.get("commitment_id", "")) == commitment_id:
		return {"ok": true, "context": existing}
	var venue: Dictionary = db.venues.get(venue_id, {})
	var c: Dictionary = Scheduler.find(s, commitment_id) if commitment_id != "" else {}
	var fee: int = int(venue.get("fee", 0)) if commitment_id == "" else int(c.get("fee", 0))
	if fee > 0 and not StatsRules.charge(s, fee, "Stage fee: " + str(venue.get("name", ""))):
		return {"ok": false, "message": "You need $%d for the bar minimum." % fee}
	var joke_ids := SetRules.jokes_in(s, setlist_id)
	var ctx := {
		"id": s.uid("perf"),
		"venue_id": venue_id,
		"setlist_id": setlist_id,
		"joke_ids": joke_ids,
		"commitment_id": commitment_id,
		"slot_seconds": int(c.get("slot_seconds", 0)) if not c.is_empty() else 0,
		"audience": str(c.get("audience", "")) if not c.is_empty() else "",
		"pay": int(c.get("pay", venue.get("pay", 0))) if not c.is_empty() else int(venue.get("pay", 0)),
		"seed": s.rng("performance").randi(),
		"day": s.day,
		"block": s.block,
	}
	s.flags["active_performance"] = ctx
	if venue_id == "spur_open_mic":
		s.flags["spur_set_%d" % s.day] = true
	return {"ok": true, "context": ctx}


static func build_sim(s: GameState, db: ContentDB, ctx: Dictionary) -> PerformanceSim:
	return PerformanceSim.build(s, db, str(ctx["venue_id"]), ctx["joke_ids"], int(ctx["seed"]), int(ctx.get("slot_seconds", 0)), str(ctx.get("audience", "")))


## Applies a finished performance exactly once. Returns a results summary for
## the feedback screen. `advance_time` is false for Kill Tony (the show block
## is advanced by the Kill Tony flow).
static func apply_performance(s: GameState, db: ContentDB, ctx: Dictionary, summary: Dictionary, advance_time: bool = true) -> Dictionary:
	var claim := "applied_" + str(ctx["id"])
	if not RewardRules.claim(s, claim):
		return {"ok": false, "message": "Already recorded."}
	var g: Dictionary = db.bal("performance.gains", {})
	var score: float = float(summary["score"])
	var venue_id: String = str(ctx["venue_id"])
	var venue: Dictionary = db.venues.get(venue_id, {})
	var notes: Array = []
	# Jokes: history (with revision), familiarity, exposure, test count.
	for r in summary["results"]:
		var joke: Dictionary = s.jokes.get(str(r["joke_id"]), {})
		if joke.is_empty():
			continue
		joke["familiarity"] = mini(100, int(joke.get("familiarity", 0)) + int(g.get("familiarity_per_performance", 10)))
		joke["test_count"] = int(joke.get("test_count", 0)) + 1
		var ex: Dictionary = joke.get("exposure", {})
		ex[venue_id] = int(ex.get(venue_id, 0)) + 1
		joke["exposure"] = ex
		joke["history"].append({"perf": ctx["id"], "rev": r["rev"], "day": s.day, "venue": venue_id, "score": snappedf(float(r["score"]), 0.1), "response": r["response"]})
	for sg in summary["suggestions"]:
		var w: Dictionary = summary.get("worst", {})
		if not w.is_empty() and s.jokes.has(str(w["joke_id"])):
			var fb: Array = s.jokes[str(w["joke_id"])]["feedback"]
			fb.append(str(sg))
			while fb.size() > 6:
				fb.pop_front()
			break
	# Skills.
	StatsRules.add_skill(s, "delivery", float(g.get("delivery_per_set", 1.0)) + (float(g.get("delivery_good_bonus", 1.0)) if score >= 60.0 else 0.0))
	StatsRules.add_skill(s, "stage_presence", float(g.get("presence_per_set", 0.8)))
	if bool(summary.get("crowd_work_used", false)):
		StatsRules.add_skill(s, "crowd_work", float(g.get("crowd_work_when_used", 1.0)))
	# Confidence, stress, energy.
	StatsRules.change_confidence(s, int(round((score - 45.0) * float(g.get("confidence_scale", 0.25)))))
	StatsRules.change_stress(s, db.bali("performance.stress_good", -6) if score >= 55.0 else db.bali("performance.stress_bad", 8))
	var drain := db.bali("performance.energy_cost", 12)
	if str(s.player.get("style", "")) == "high_energy":
		drain += int(db.bal("styles_effects.high_energy.energy_drain_extra", 4))
	StatsRules.change_energy(s, -drain)
	# Reputation is earned by doing well where people notice.
	var rep_gain := maxf(0.0, (score - 40.0)) * float(g.get("rep_scale", 0.06))
	if str(venue.get("kind", "")) in ["showcase", "secret_show", "late_show"]:
		rep_gain *= 1.5
	s.reputation += rep_gain
	s.local_demand = clampf(s.local_demand + (score - 50.0) * 0.05, 0.0, 100.0)
	# Host relationship.
	var host: String = str(venue.get("host_npc", ""))
	if host != "":
		var rd: Dictionary = {"familiarity": 2}
		if score >= 72.0:
			rd["respect"] = db.bali("relationships.great_set_respect", 6)
		elif score >= 55.0:
			rd["respect"] = db.bali("relationships.good_set_respect", 3)
		if bool(summary.get("overrun_penalty", 0.0) > 0.0):
			rd["trust"] = -3
			notes.append("%s noticed you ran long." % db.character_name(host))
		Relationships.change(s, host, rd)
	# Pay (exactly once per booking / performance).
	var pay: int = int(ctx.get("pay", 0))
	var cid: String = str(ctx.get("commitment_id", ""))
	if pay > 0 and RewardRules.pay_booking(s, cid if cid != "" else str(ctx["id"]), pay, "Paid set: " + str(venue.get("name", ""))):
		notes.append("Paid $%d." % pay)
	if cid != "":
		var c := Scheduler.find(s, cid)
		Scheduler.mark_done(s, cid)
		if str(c.get("offer_id", "")) != "":
			OpportunityRules.on_complete(s, db, str(c["offer_id"]))
	# Bombing teaches.
	s.stats["sets"] = int(s.stats.get("sets", 0)) + 1
	if score < 30.0:
		s.stats["bombs"] = int(s.stats.get("bombs", 0)) + 1
		for comp in db.components.values():
			if str(comp.get("unlock", "")) == "bomb" and JokeRules.unlock_component(s, db, str(comp["id"])):
				notes.append("Bombing gave you something: new premise \"%s\"." % comp["text"])
	var record := {"id": ctx["id"], "day": s.day, "block": s.block, "venue": venue_id, "score": snappedf(score, 0.1), "tier": summary["tier"], "seed": str(ctx["seed"]), "jokes": summary["results"].map(func(x): return {"joke_id": x["joke_id"], "rev": x["rev"], "score": snappedf(float(x["score"]), 0.1)})}
	s.performances.append(record)
	while s.performances.size() > 80:
		s.performances.pop_front()
	s.flags["last_performance_breakdown"] = summary["results"].map(func(x): return {"title": x["title"], "score": snappedf(float(x["score"]), 0.1), "factors": x["factors"]})
	s.flags.erase("active_performance")
	if venue_id == "spur_open_mic":
		_tutorial_advance(s, "first_set")
	if advance_time:
		notes.append_array(advance(s, db, 1))
	else:
		var m := CareerRules.update(s, db)
		if m != "":
			notes.append(m)
	return {"ok": true, "notes": notes}
