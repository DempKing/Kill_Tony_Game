class_name WorldRules
extends RefCounted
## Day transitions (upkeep, rent, opportunities, events), NPC schedules,
## observations and world events.


# --- NPC schedules ---------------------------------------------------------

static func npc_location(db: ContentDB, npc_id: String, day: int, block: int) -> String:
	var npc: Dictionary = db.npcs.get(npc_id, {})
	var wd := CalendarRules.weekday(day)
	for entry in npc.get("schedule", []):
		var days: Variant = entry.get("days", "all")
		var day_ok: bool = typeof(days) == TYPE_STRING or (days as Array).has(wd)
		if day_ok and (entry.get("blocks", []) as Array).has(block):
			return str(entry["location"])
	return ""


static func npcs_at(s: GameState, db: ContentDB, location_id: String) -> Array:
	var out: Array = []
	for id in db.npcs:
		if npc_location(db, str(id), s.day, s.block) == location_id:
			out.append(str(id))
	return out


static func talk(s: GameState, db: ContentDB, npc_id: String) -> String:
	var npc: Dictionary = db.npcs.get(npc_id, {})
	if npc.is_empty():
		return ""
	var key := "talked_%s_%d" % [npc_id, s.day]
	if not s.flags.has(key):
		s.flags[key] = true
		Relationships.change(s, npc_id, {"familiarity": db.bali("relationships.talk_familiarity", 3)})
	var tier := Relationships.tier(s, npc_id)
	var lines: Array = npc.get("lines", {}).get(tier, npc.get("lines", {}).get("stranger", ["..."]))
	var idx: int = (s.day + int(s.rel(npc_id)["familiarity"])) % maxi(1, lines.size())
	return str(lines[idx])


# --- Observations ----------------------------------------------------------

static func observation_available(s: GameState, obs: Dictionary) -> bool:
	if s.flags.has("seen_" + str(obs["id"])):
		return false
	var wd := CalendarRules.weekday(s.day)
	if obs.has("weekdays") and not (obs["weekdays"] as Array).has(wd):
		return false
	if obs.has("blocks") and not (obs["blocks"] as Array).has(s.block):
		return false
	return true


static func observe(s: GameState, db: ContentDB, obs_id: String) -> Dictionary:
	var obs: Dictionary = db.observations.get(obs_id, {})
	if obs.is_empty() or not observation_available(s, obs):
		return {"ok": false, "message": "Nothing new here right now."}
	s.flags["seen_" + obs_id] = true
	var notes: Array = []
	for cid in obs.get("unlock", []):
		if JokeRules.unlock_component(s, db, str(cid)):
			notes.append("New premise: \"%s\"" % db.component(str(cid)).get("text", ""))
	if notes.is_empty():
		notes.append("You already had this one in the journal.")
	return {"ok": true, "message": str(obs["text"]) + "\n" + "\n".join(PackedStringArray(notes))}


# --- World events ----------------------------------------------------------

static func event_conditions_ok(s: GameState, db: ContentDB, ev: Dictionary) -> bool:
	var c: Dictionary = ev.get("conditions", {})
	var wd := CalendarRules.weekday(s.day)
	if bool(ev.get("once", false)) and s.flags.has("ev_done_" + str(ev["id"])):
		return false
	if c.has("weekdays") and not (c["weekdays"] as Array).has(wd):
		return false
	if c.has("blocks") and not (c["blocks"] as Array).has(s.block):
		return false
	if c.has("min_day") and s.day < int(c["min_day"]):
		return false
	if c.has("max_day") and s.day > int(c["max_day"]):
		return false
	if c.has("job") and not s.jobs.has(str(c["job"])):
		return false
	if c.has("min_rep") and s.reputation < float(c["min_rep"]):
		return false
	if c.has("min_sets") and int(s.stats.get("sets", 0)) < int(c["min_sets"]):
		return false
	if c.has("housing") and s.housing_id != str(c["housing"]):
		return false
	if c.has("min_cash") and s.cash < int(c["min_cash"]):
		return false
	if c.has("max_cash") and s.cash > int(c["max_cash"]):
		return false
	if c.has("flag") and not bool(s.flags.get(str(c["flag"]), false)):
		return false
	# Only one roll per event per block, so re-entering a door can't farm it.
	if s.flags.has("ev_roll_%s_%d" % [ev["id"], CalendarRules.slot(s.day, s.block)]):
		return false
	return true


## Rolls events for a trigger. At most one event per trigger. Queued events are
## stored on state so a reload shows the same event.
static func roll_events(s: GameState, db: ContentDB, trigger: String) -> String:
	if not s.flags.get("tutorial_done", false) and trigger == "day_start" and s.day < 1:
		return ""
	var r := s.rng("world")
	for ev in db.world_events:
		if str(ev.get("trigger", "")) != trigger:
			continue
		if not event_conditions_ok(s, db, ev):
			continue
		s.flags["ev_roll_%s_%d" % [ev["id"], CalendarRules.slot(s.day, s.block)]] = true
		if r.randf() < float(ev.get("chance", 0.2)):
			s.pending_events.append(str(ev["id"]))
			if bool(ev.get("once", false)):
				s.flags["ev_done_" + str(ev["id"])] = true
			return str(ev["id"])
	return ""


static func find_event(db: ContentDB, id: String) -> Dictionary:
	for ev in db.world_events:
		if str(ev["id"]) == id:
			return ev
	return {}


static func resolve_event(s: GameState, db: ContentDB, event_id: String, choice: int) -> Dictionary:
	var idx := s.pending_events.find(event_id)
	if idx < 0:
		return {"ok": false, "message": ""}
	s.pending_events.remove_at(idx)
	var ev := find_event(db, event_id)
	var opts: Array = ev.get("choices", [])
	if opts.is_empty():
		return {"ok": true, "message": ""}
	var ch: Dictionary = opts[clampi(choice, 0, opts.size() - 1)]
	var notes := StatsRules.apply_effects(s, db, ch.get("effects", {}), "", "event")
	return {"ok": true, "message": "\n".join(PackedStringArray(notes))}


# --- Day start --------------------------------------------------------------

static func start_day(s: GameState, db: ContentDB) -> Array:
	var notes: Array = []
	# Daily essentials. If unaffordable you skip meals: recoverable, no debt.
	var upkeep := db.bali("economy.daily_essentials", 8)
	if not StatsRules.charge(s, upkeep, "Food & essentials"):
		StatsRules.change_energy(s, db.bali("economy.skipped_meal_energy", -5))
		StatsRules.change_stress(s, db.bali("economy.skipped_meal_stress", 5))
		notes.append("You couldn't cover food today. You skipped meals.")
	var rn := process_rent(s, db)
	if rn != "":
		notes.append(rn)
	OpportunityRules.daily_update(s, db)
	roll_events(s, db, "day_start")
	# Clean up old per-block roll flags to keep saves small.
	var cutoff := CalendarRules.slot(s.day - 2, 0)
	for k in s.flags.keys():
		var ks: String = str(k)
		if ks.begins_with("ev_roll_"):
			var parts := ks.split("_")
			if parts.size() > 0 and parts[parts.size() - 1].to_int() < cutoff:
				s.flags.erase(k)
		elif ks.begins_with("talked_"):
			var p2 := ks.split("_")
			if p2[p2.size() - 1].to_int() < s.day - 1:
				s.flags.erase(k)
	for n in notes:
		s.add_message(str(n))
	return notes


## Weekly rent. Shortfalls become debt with a single late fee; repeated misses
## move you to a free fallback (a friend's couch) instead of a death spiral.
static func process_rent(s: GameState, db: ContentDB) -> String:
	if s.housing_id == "":
		return ""
	var h: Dictionary = db.housing.get(s.housing_id, {})
	if s.day < int(s.rent.get("next_due_day", 7)):
		return ""
	s.rent["next_due_day"] = int(s.rent.get("next_due_day", 7)) + 7
	var weekly: int = int(h.get("weekly", 0))
	if weekly <= 0:
		return ""
	var due: int = weekly + int(s.rent.get("debt", 0))
	var paid := mini(due, s.cash)
	if paid > 0:
		StatsRules.add_cash(s, -paid, "Rent: " + str(h.get("name", "housing")))
	var remaining := due - paid
	if remaining <= 0:
		s.rent["debt"] = 0
		s.rent["missed"] = 0
		return "Rent paid: $%d." % paid
	s.rent["missed"] = int(s.rent.get("missed", 0)) + 1
	s.rent["debt"] = remaining + db.bali("economy.late_fee", 15)
	StatsRules.change_stress(s, 10)
	var msg := "Rent short by $%d. You owe $%d including a late fee." % [remaining, int(s.rent["debt"])]
	if int(s.rent["missed"]) >= db.bali("economy.missed_rent_weeks_before_fallback", 2):
		var fb := str(db.bal("economy.fallback_housing", "deshawn_couch"))
		s.housing_id = fb
		msg += " Mari can't hold your bunk any longer. Deshawn offers his couch until you're back on your feet. (Pay off the debt at the hostel to move back.)"
	return msg


static func pay_debt(s: GameState, db: ContentDB) -> Dictionary:
	var debt: int = int(s.rent.get("debt", 0))
	if debt <= 0:
		return {"ok": false, "message": "You don't owe anything."}
	if not StatsRules.charge(s, debt, "Rent debt"):
		return {"ok": false, "message": "You need $%d to clear your debt." % debt}
	s.rent["debt"] = 0
	s.rent["missed"] = 0
	Relationships.change(s, "mari", {"trust": 4})
	var msg := "Debt cleared."
	if bool(db.housing.get(s.housing_id, {}).get("fallback", false)):
		s.housing_id = "bunkhouse"
		s.rent["next_due_day"] = s.day + 7
		msg += " Mari gives you your bunk back."
	return {"ok": true, "message": msg}
