class_name OpportunityRules
extends RefCounted
## Career opportunities: generated from authored templates when conditions are
## met, offered with an expiry, and turned into commitments on acceptance
## (with conflict checks; nothing is silently replaced).


static func conditions_met(s: GameState, db: ContentDB, cond: Dictionary) -> bool:
	if cond.has("min_rep") and s.reputation < float(cond["min_rep"]):
		return false
	if cond.has("min_fame") and s.fame < float(cond["min_fame"]):
		return false
	if cond.has("min_sets") and int(s.stats.get("sets", 0)) < int(cond["min_sets"]):
		return false
	if cond.has("min_tier") and s.career_tier < int(cond["min_tier"]):
		return false
	if cond.has("job") and not s.jobs.has(str(cond["job"])):
		return false
	if cond.has("flag") and not bool(s.flags.get(str(cond["flag"]), false)):
		return false
	if cond.has("rel") and not Relationships.meets(s, cond["rel"]):
		return false
	return true


static func active_for_template(s: GameState, template_id: String) -> bool:
	for o in s.opportunities:
		if str(o["template"]) == template_id and str(o["status"]) in ["offered", "accepted"]:
			if str(o["status"]) == "accepted":
				var c := Scheduler.find(s, str(o.get("commitment_id", "")))
				if c.is_empty() or str(c.get("status", "")) != "booked":
					continue
			return true
	return false


static func create_offer(s: GameState, db: ContentDB, template_id: String, from_day: int) -> Dictionary:
	var t: Dictionary = db.opportunities.get(template_id, {})
	if t.is_empty():
		return {}
	var lead: int = int(t.get("lead_days", 2))
	var day := CalendarRules.next_weekday(from_day + lead, int(t.get("weekday", 3)))
	var venue: Dictionary = db.venues.get(str(t["venue"]), {})
	var o := {
		"id": s.uid("offer"),
		"template": template_id,
		"title": str(t["title"]),
		"venue_id": str(t["venue"]),
		"location_id": str(venue.get("location", "")),
		"audience": str(t.get("audience", "")),
		"day": day,
		"block": int(t.get("block", 2)),
		"slot_seconds": int(t.get("slot_seconds", 300)),
		"pay": int(t.get("pay", 0)),
		"npc": str(t.get("npc", "")),
		"offered_day": s.day,
		"expires_day": mini(day - 1, s.day + int(t.get("expires_after_days", 3))),
		"status": "offered",
	}
	s.opportunities.append(o)
	s.flags["opp_last_" + template_id] = s.day
	s.add_message("New offer: %s on %s." % [o["title"], CalendarRules.describe_slot(day, int(o["block"]))])
	return o


## Daily generation (morning). Uses the world RNG stream.
static func daily_update(s: GameState, db: ContentDB) -> void:
	for o in s.opportunities:
		if str(o["status"]) == "offered" and s.day > int(o["expires_day"]):
			o["status"] = "expired"
			s.add_message("Offer expired: %s." % o["title"])
	var r := s.rng("world")
	for tid in db.opportunities:
		var t: Dictionary = db.opportunities[tid]
		if str(t.get("source", "")) == "kill_tony":
			continue
		if active_for_template(s, str(tid)):
			continue
		var last: int = int(s.flags.get("opp_last_" + str(tid), -999))
		if s.day - last < int(t.get("cooldown_days", 7)):
			continue
		if not conditions_met(s, db, t.get("conditions", {})):
			continue
		if r.randf() < float(t.get("chance", 0.3)):
			create_offer(s, db, str(tid), s.day)


static func find(s: GameState, offer_id: String) -> Dictionary:
	for o in s.opportunities:
		if str(o["id"]) == offer_id:
			return o
	return {}


static func offers(s: GameState) -> Array:
	return s.opportunities.filter(func(o): return str(o["status"]) == "offered")


static func accept(s: GameState, db: ContentDB, offer_id: String, force: bool = false) -> Dictionary:
	var o := find(s, offer_id)
	if o.is_empty() or str(o["status"]) != "offered":
		return {"ok": false, "message": "That offer isn't available."}
	if s.day > int(o["expires_day"]):
		o["status"] = "expired"
		return {"ok": false, "message": "That offer has expired."}
	var c := {"kind": "booking", "title": str(o["title"]), "day": int(o["day"]), "block": int(o["block"]), "length": 1,
		"location_id": str(o["location_id"]), "venue_id": str(o["venue_id"]), "slot_seconds": int(o["slot_seconds"]),
		"pay": int(o["pay"]), "fee": 0, "npc": str(o["npc"]), "offer_id": offer_id, "audience": str(o.get("audience", ""))}
	var res := Scheduler.add(s, db, c, force)
	if not bool(res["ok"]):
		return {"ok": false, "conflicts": res["conflicts"], "message": "That date conflicts with another booking."}
	o["status"] = "accepted"
	o["commitment_id"] = res["commitment"]["id"]
	Relationships.change(s, str(o["npc"]), {"familiarity": 2})
	return {"ok": true, "message": "Booked: %s, %s." % [o["title"], CalendarRules.describe_slot(int(o["day"]), int(o["block"]))]}


static func decline(s: GameState, offer_id: String) -> void:
	var o := find(s, offer_id)
	if not o.is_empty() and str(o["status"]) == "offered":
		o["status"] = "declined"


static func on_complete(s: GameState, db: ContentDB, offer_id: String) -> void:
	var o := find(s, offer_id)
	if o.is_empty():
		return
	o["status"] = "completed"
	var t: Dictionary = db.opportunities.get(str(o["template"]), {})
	var fx: Dictionary = t.get("on_complete", {})
	if bool(fx.get("paid", false)):
		s.stats["paid_sets"] = int(s.stats.get("paid_sets", 0)) + 1
	if bool(fx.get("opener", false)):
		s.stats["opener_sets"] = int(s.stats.get("opener_sets", 0)) + 1
	StatsRules.apply_effects(s, db, fx, "", "booking")
	if str(o["template"]) in ["opp_secret_show", "opp_secret_rebook"]:
		s.flags["secret_show_done"] = true
