class_name TourRules
extends RefCounted
## Touring (Phase 4). Austin stays the hub; tours are planned, booked as one
## calendar commitment covering the whole trip, and played leg by leg.
##
## Money model (shown to the player in the planner):
##  - Deposits + marketing are paid when you book.
##  - Committed costs (transport, lodging, opener fees) are reserved at booking
##    and charged when you depart.
##  - Forecast revenue is only a forecast: it is never added to cash.
##  - Each show settles after it happens:
##      payout = gross * (1 - venue cut) - (rent - deposit)
##    Deposits equal rent in the data, so a payout is never negative; losses come
##    from upfront costs that ticket sales didn't cover.
##
## Tour record: {id, title, role ("headliner"|"opener"), status
## (booked|active|done|cancelled), start_day, legs:[...], price, marketing,
## transport, lodging, opener, deposits, committed, forecast_revenue,
## commitment_id, offer_id, pay_per_show, npc}


static func t(db: ContentDB, key: String, fallback: Variant = 0) -> Variant:
	return db.touring.get("tuning", {}).get(key, fallback)


static func market(db: ContentDB, id: String) -> Dictionary:
	for m in db.touring.get("markets", []):
		if str(m["id"]) == id:
			return m
	return {}


static func venue_id(market_id: String, vtype: String) -> String:
	return "tour_%s_%s" % [market_id, vtype]


static func opener(db: ContentDB, id: String) -> Dictionary:
	for o in db.touring.get("openers", []):
		if str(o["id"]) == id:
			return o
	return {}


## Built-in openers plus comics you discovered from the Kill Tony panel.
static func openers_all(s: GameState, db: ContentDB) -> Array:
	var out: Array = (db.touring.get("openers", []) as Array).duplicate()
	out.append_array(s.discovered_openers)
	return out


static func opener_for(s: GameState, db: ContentDB, id: String) -> Dictionary:
	if id == "":
		return {}
	for o in openers_all(s, db):
		if str(o["id"]) == id:
			var copy: Dictionary = (o as Dictionary).duplicate(true)
			if bool(s.flags.get("breakout_" + id, false)):
				copy["fee"] = int(copy.get("fee", 50)) * 2
				copy["reliability"] = mini(100, int(copy.get("reliability", 60)) + 15)
				copy["broke_out"] = true
			return copy
	return {}


## How well an opener's style suits a venue type's audience (-5..+5).
static func audience_fit(db: ContentDB, op: Dictionary, vtype: String) -> float:
	var aud_id: String = str(db.touring.get("venue_types", {}).get(vtype, {}).get("audience", "showcase_crowd"))
	var aud: Dictionary = db.audiences.get(aud_id, {})
	return float(aud.get("style_prefs", {}).get(str(op.get("style", "")), 0)) + (1.0 if str(op.get("potential", "")) == "high" else 0.0)


static func production(db: ContentDB, level: String) -> Dictionary:
	return t(db, "production", {}).get(level, {"cost": 0, "warmth": 0, "fame_mult": 1.0})


static func find(s: GameState, tour_id: String) -> Dictionary:
	for tr in s.tours:
		if str(tr["id"]) == tour_id:
			return tr
	return {}


static func can_plan(s: GameState, db: ContentDB) -> Dictionary:
	var need := int(t(db, "planner_min_tier", 4))
	if s.career_tier < need:
		return {"ok": false, "reason": "Headline tours open up at career tier %d (%s). Take road offers as an opener first." % [need, CareerRules.tier_name(db, need)]}
	return {"ok": true, "reason": ""}


# --- Demand and forecasting ---------------------------------------------------

## Expected ticket demand (people) for a market at a price, with explanations.
static func demand(s: GameState, db: ContentDB, market_id: String, price: int, marketing_share: float, on_day: int, vtype: String = "club") -> Dictionary:
	var m := market(db, market_id)
	var fans: int = int(s.fans.get(market_id, 0))
	var star := float(t(db, "base_star", 0.1)) + s.fame * float(t(db, "fame_weight", 0.08)) + s.reputation * float(t(db, "rep_weight", 0.02)) + fans * float(t(db, "fan_weight", 0.01))
	var ref := float(m.get("ref_price", 25)) * float(db.touring.get("venue_types", {}).get(vtype, {}).get("price_ref_mult", 1.0))
	var pf := clampf(pow(ref / maxf(1.0, float(price)), float(t(db, "price_elasticity", 1.2))), float(t(db, "price_factor_min", 0.3)), float(t(db, "price_factor_max", 1.6)))
	var mk := 1.0 + minf(float(t(db, "marketing_max_bonus", 0.4)), marketing_share / float(t(db, "marketing_per_point", 1000.0)))
	var rec := 1.0
	var last: int = int(s.flags.get("tour_last_" + market_id, -999))
	if on_day - last < int(t(db, "recency_days", 21)):
		rec = 1.0 - float(t(db, "recency_penalty", 0.4))
	var draw := float(db.touring.get("venue_types", {}).get(vtype, {}).get("draw_mult", 1.0))
	var people := float(m.get("base_demand", 150)) * star * draw * pf * mk * rec
	return {"people": people, "star": star, "price_factor": pf, "marketing_factor": mk, "recency": rec, "fans": fans}


static func forecast_leg(s: GameState, db: ContentDB, market_id: String, vtype: String, price: int, marketing_share: float, on_day: int) -> Dictionary:
	var m := market(db, market_id)
	var v: Dictionary = m.get("venues", {}).get(vtype, {})
	var vt: Dictionary = db.touring.get("venue_types", {}).get(vtype, {})
	var dm := demand(s, db, market_id, price, marketing_share, on_day, vtype)
	var cap: int = int(v.get("cap", 200))
	var expected: int = mini(cap, int(round(float(dm["people"]))))
	var gross := expected * price
	var cut := float(vt.get("cut", 0.3))
	var rent: int = int(v.get("rent", 0))
	var deposit: int = int(v.get("deposit", 0))
	var payout := int(round(gross * (1.0 - cut))) - (rent - deposit)
	return {"market": market_id, "venue_type": vtype, "venue_name": str(v.get("name", "")), "cap": cap, "expected": expected,
		"gross": gross, "cut": cut, "rent": rent, "deposit": deposit, "payout": payout, "demand": dm}


## Validates and prices a plan without changing anything.
## plan: {start_day, legs:[{market, venue_type}], price, marketing, transport, lodging, opener}
static func evaluate_plan(s: GameState, db: ContentDB, plan: Dictionary) -> Dictionary:
	var errors: Array = []
	var chk := can_plan(s, db)
	if not bool(chk["ok"]):
		errors.append(str(chk["reason"]))
	var legs_in: Array = plan.get("legs", [])
	var start_day: int = int(plan.get("start_day", s.day + 2))
	if legs_in.is_empty():
		errors.append("Add at least one city.")
	if legs_in.size() > int(t(db, "max_legs", 5)):
		errors.append("At most %d cities per tour." % int(t(db, "max_legs", 5)))
	if start_day < s.day + 2:
		errors.append("Tours need at least two days of lead time.")
	var price: int = int(plan.get("price", 25))
	var marketing: int = int(plan.get("marketing", 0))
	var transport: String = str(plan.get("transport", "van"))
	var lodging: String = str(plan.get("lodging", "motel"))
	var op := opener_for(s, db, str(plan.get("opener", "")))
	var prod_level: String = str(plan.get("production", "standard"))
	var prod := production(db, prod_level)
	var production_cost := 0
	var opener_cost := 0
	var fee_mult: Dictionary = t(db, "opener_fee_mult", {})
	var share := float(marketing) / maxf(1.0, float(legs_in.size()))
	var legs: Array = []
	var deposits := 0
	var transport_cost := 0
	var lodging_cost := 0
	var forecast := 0
	var all_drive := true
	for i in range(legs_in.size()):
		var li: Dictionary = legs_in[i]
		var mid: String = str(li["market"])
		var vtype: String = str(li.get("venue_type", "club"))
		var m := market(db, mid)
		if m.is_empty():
			errors.append("Unknown city.")
			continue
		if s.fame < float(m.get("min_fame", 0)):
			errors.append("%s needs fame %d to draw a crowd (you have %.0f)." % [m["name"], int(m["min_fame"]), s.fame])
		if vtype == "arena":
			production_cost += int(prod.get("cost", 0))
			if s.career_tier < int(t(db, "arena_min_tier", 7)):
				errors.append("Arenas need career tier %d (%s)." % [int(t(db, "arena_min_tier", 7)), CareerRules.tier_name(db, int(t(db, "arena_min_tier", 7)))])
		if not op.is_empty():
			opener_cost += int(op.get("fee", 0)) * int(fee_mult.get(vtype, 1))
		if vtype == "theater" and s.career_tier < int(t(db, "theater_min_tier", 6)):
			errors.append("Theaters need career tier %d (%s)." % [int(t(db, "theater_min_tier", 6)), CareerRules.tier_name(db, int(t(db, "theater_min_tier", 6)))])
		if not bool(m.get("drive", false)):
			all_drive = false
		var day := start_day + i
		var f := forecast_leg(s, db, mid, vtype, price, share, day)
		f["day"] = day
		legs.append(f)
		deposits += int(f["deposit"])
		forecast += int(f["gross"]) - int(round(int(f["gross"]) * float(f["cut"])))
		lodging_cost += int(m.get("hotel" if lodging == "hotel" else "motel", 80))
		if transport == "van" and bool(m.get("drive", false)):
			transport_cost += int(m.get("drive_cost", 60))
		else:
			transport_cost += int(m.get("flight_cost", 250))
	if transport == "van" and not all_drive:
		errors.append("The van only reaches Texas cities. Fly, or keep this run in Texas.")
	# Getting home again.
	if not legs.is_empty():
		var lastm := market(db, str(legs.back()["market"]))
		transport_cost += int(lastm.get("drive_cost", 60)) if (transport == "van" and all_drive) else int(lastm.get("flight_cost", 250))
	var committed := transport_cost + lodging_cost + opener_cost + production_cost
	var upfront := deposits + marketing
	var rent_total := 0
	for f in legs:
		rent_total += int(f["rent"])
	var forecast_net := forecast - rent_total - marketing - committed
	if s.cash < upfront + committed:
		errors.append("You need %s available (deposits + marketing now, travel/lodging/opener reserved). You have %s." % [money_text(upfront + committed), money_text(s.cash)])
	var n := legs.size()
	var conf: Array = Scheduler.conflicts(s, start_day, 0, n * 4 + 2) if n > 0 else []
	return {"ok": errors.is_empty(), "errors": errors, "legs": legs, "start_day": start_day, "price": price, "marketing": marketing,
		"transport": transport, "lodging": lodging, "opener": str(plan.get("opener", "")), "deposits": deposits, "upfront": upfront,
		"transport_cost": transport_cost, "lodging_cost": lodging_cost, "opener_cost": opener_cost, "production": prod_level, "production_cost": production_cost, "committed": committed,
		"forecast_revenue": forecast, "rent_total": rent_total, "forecast_net": forecast_net, "conflicts": conf, "nights": n}


static func money_text(v: int) -> String:
	return ("-$%d" % absi(v)) if v < 0 else ("$%d" % v)


# --- Booking, cancelling, departing -----------------------------------------

static func book(s: GameState, db: ContentDB, plan: Dictionary, force: bool = false) -> Dictionary:
	var ev := evaluate_plan(s, db, plan)
	if not bool(ev["ok"]):
		return {"ok": false, "message": "\n".join(PackedStringArray(ev["errors"]))}
	if not (ev["conflicts"] as Array).is_empty() and not force:
		return {"ok": false, "conflicts": ev["conflicts"], "message": "The tour overlaps other commitments."}
	var cities: Array = []
	for f in ev["legs"]:
		cities.append(str(market(db, str(f["market"]))["name"]).split(",")[0])
	var id := s.uid("tour")
	var title := "Headline tour: " + ", ".join(PackedStringArray(cities))
	var c := {"kind": "tour", "title": title, "day": int(ev["start_day"]), "block": 0, "length": int(ev["nights"]) * 4 + 2,
		"location_id": "transit_stop", "npc": "", "slot_seconds": 0, "pay": 0, "fee": 0, "tour_id": id}
	var res := Scheduler.add(s, db, c, force)
	if not bool(res["ok"]):
		return {"ok": false, "message": "Calendar conflict."}
	StatsRules.add_cash(s, -int(ev["deposits"]), "Tour venue deposits")
	if int(ev["marketing"]) > 0:
		StatsRules.add_cash(s, -int(ev["marketing"]), "Tour marketing")
	var legs: Array = []
	for f in ev["legs"]:
		legs.append({"market": f["market"], "venue_type": f["venue_type"], "venue_name": f["venue_name"], "day": f["day"], "cap": f["cap"],
			"rent": f["rent"], "deposit": f["deposit"], "cut": f["cut"], "forecast": f["expected"], "sold": -1, "gross": 0, "payout": 0, "score": -1.0, "event": ""})
	var tr := {"id": id, "title": title, "role": "headliner", "status": "booked", "start_day": int(ev["start_day"]), "legs": legs,
		"price": int(ev["price"]), "marketing": int(ev["marketing"]), "transport": ev["transport"], "lodging": ev["lodging"], "opener": ev["opener"],
		"production": ev["production"], "production_cost": int(ev["production_cost"]),
		"deposits": int(ev["deposits"]), "committed": int(ev["committed"]), "forecast_revenue": int(ev["forecast_revenue"]),
		"commitment_id": str(res["commitment"]["id"]), "booked_day": s.day}
	s.tours.append(tr)
	return {"ok": true, "tour": tr, "message": "Booked %s. Paid %s in deposits and marketing; %s reserved for travel, lodging and opener." % [title, money_text(int(ev["upfront"])), money_text(int(ev["committed"]))]}


## Road offer (you open for someone): no costs, flat pay per show.
static func book_road(s: GameState, db: ContentDB, offer: Dictionary, force: bool = false) -> Dictionary:
	var tmpl: Dictionary = db.opportunities.get(str(offer["template"]), {})
	var cities: Array = tmpl.get("cities", [])
	var start_day: int = int(offer["day"])
	var c := {"kind": "tour", "title": str(offer["title"]), "day": start_day, "block": 0, "length": cities.size() * 4 + 2,
		"location_id": "transit_stop", "npc": str(offer.get("npc", "")), "slot_seconds": 0, "pay": 0, "fee": 0}
	var res := Scheduler.add(s, db, c, force)
	if not bool(res["ok"]):
		return {"ok": false, "conflicts": res["conflicts"], "message": "That run overlaps other commitments."}
	var id := s.uid("tour")
	res["commitment"]["tour_id"] = id
	var legs: Array = []
	for i in range(cities.size()):
		var m := market(db, str(cities[i]))
		var v: Dictionary = m.get("venues", {}).get("club", {})
		legs.append({"market": cities[i], "venue_type": "club", "venue_name": str(v.get("name", "")), "day": start_day + i, "cap": int(v.get("cap", 250)),
			"rent": 0, "deposit": 0, "cut": 0.0, "forecast": int(v.get("cap", 250)), "sold": -1, "gross": 0, "payout": 0, "score": -1.0, "event": ""})
	var tr := {"id": id, "title": str(offer["title"]), "role": "opener", "status": "booked", "start_day": start_day, "legs": legs,
		"price": 0, "marketing": 0, "transport": "covered", "lodging": "hotel", "opener": "", "deposits": 0, "committed": 0, "forecast_revenue": 0,
		"pay_per_show": int(tmpl.get("pay_per_show", 150)), "npc": str(offer.get("npc", "")), "offer_id": str(offer["id"]),
		"commitment_id": str(res["commitment"]["id"]), "booked_day": s.day}
	s.tours.append(tr)
	return {"ok": true, "tour": tr, "message": "Booked: %s, starting %s." % [offer["title"], CalendarRules.describe_slot(start_day, 0)]}


## Cancels before departure. Deposits and marketing are not refunded.
static func cancel(s: GameState, db: ContentDB, tour_id: String, reason: String = "cancelled") -> Dictionary:
	var tr := find(s, tour_id)
	if tr.is_empty() or str(tr["status"]) != "booked":
		return {"ok": false, "message": "That tour can't be cancelled now."}
	tr["status"] = "cancelled"
	tr["cancel_reason"] = reason
	var c := Scheduler.find(s, str(tr["commitment_id"]))
	if not c.is_empty() and str(c["status"]) == "booked":
		c["status"] = "cancelled"
	s.reputation = maxf(0.0, s.reputation - float(t(db, "cancel_rep_penalty", 3.0)))
	if str(tr.get("npc", "")) != "":
		Relationships.change(s, str(tr["npc"]), {"trust": -8, "reliability": -10})
	var lost: int = int(tr["deposits"]) + int(tr["marketing"])
	var msg := "Tour cancelled (%s). Lost %s in deposits and marketing. Promoters remember." % [reason, money_text(lost)]
	s.add_message(msg)
	return {"ok": true, "message": msg}


static func departing_today(s: GameState) -> Dictionary:
	for tr in s.tours:
		if str(tr["status"]) == "booked" and int(tr["start_day"]) == s.day:
			return tr
	return {}


static func depart(s: GameState, db: ContentDB, tour_id: String) -> Dictionary:
	var tr := find(s, tour_id)
	if tr.is_empty() or str(tr["status"]) != "booked":
		return {"ok": false, "message": "No tour to depart on."}
	if s.day != int(tr["start_day"]) or s.block != 0:
		return {"ok": false, "message": "Tours leave first thing in the morning on the start day."}
	if not StatsRules.charge(s, int(tr["committed"]), "Tour travel, lodging and opener"):
		return {"ok": false, "message": "You need %s for travel, lodging and your opener. You spent money that was set aside. Raise it, or cancel the tour." % money_text(int(tr["committed"]))}
	tr["status"] = "active"
	Scheduler.mark_done(s, str(tr["commitment_id"]))
	s.flags["active_tour"] = {"id": tour_id, "leg": 0, "phase": "arrive"}
	return {"ok": true, "message": "You're on the road."}


# --- Playing legs ---------------------------------------------------------------

## Ticket sales for a leg: computed once and stored, so reloading doesn't change them.
static func sell_leg(s: GameState, db: ContentDB, tr: Dictionary, i: int) -> int:
	var leg: Dictionary = tr["legs"][i]
	if int(leg["sold"]) >= 0:
		return int(leg["sold"])
	if str(tr["role"]) == "opener":
		leg["sold"] = int(leg["cap"])
		return int(leg["sold"])
	var share := float(tr["marketing"]) / maxf(1.0, float(tr["legs"].size()))
	var dm := demand(s, db, str(leg["market"]), int(tr["price"]), share, int(leg["day"]), str(leg["venue_type"]))
	var noise := float(t(db, "sales_noise", 0.15))
	var sold := int(round(float(dm["people"]) * s.rng("world").randf_range(1.0 - noise, 1.0 + noise)))
	leg["sold"] = clampi(sold, 0, int(leg["cap"]))
	leg["gross"] = int(leg["sold"]) * int(tr["price"])
	return int(leg["sold"])


## Bounded travel setback, rolled once per leg.
static func travel_event(s: GameState, db: ContentDB, tr: Dictionary, i: int) -> String:
	var leg: Dictionary = tr["legs"][i]
	if str(leg.get("event", "")) != "":
		return str(leg["event"]) if str(leg["event"]) != "none" else ""
	var txt := "none"
	if str(tr["role"]) == "headliner" and s.rng("world").randf() < float(t(db, "delay_chance", 0.12)):
		var cost: int = mini(int(t(db, "delay_cost", 90)), s.cash)
		StatsRules.add_cash(s, -cost, "Travel setback")
		StatsRules.change_stress(s, 6)
		txt = "Travel trouble: a %s. It costs you %s and some nerves, but you make the show." % ["flat tire on the van" if str(tr["transport"]) == "van" else "delayed flight", money_text(cost)]
	leg["event"] = txt
	return txt if txt != "none" else ""


## Opener's warmth bonus for a headline show (0 if none or a no-show).
static func opener_bonus(s: GameState, db: ContentDB, tr: Dictionary, i: int) -> Dictionary:
	var vtype: String = str(tr["legs"][i]["venue_type"])
	var prod_w := float(production(db, str(tr.get("production", "standard"))).get("warmth", 0)) if vtype == "arena" else 0.0
	var op := opener_for(s, db, str(tr.get("opener", "")))
	if op.is_empty():
		return {"bonus": prod_w - (3.0 if vtype == "arena" else 0.0), "text": "No opener: you walk out to a cold room."}
	var rel := float(op.get("reliability", 60))
	if str(op.get("npc", "")) != "":
		rel = clampf(rel + float(s.rel(str(op["npc"]))["trust"]) * 0.3, 0.0, 100.0)
	var key := "noshow_%s_%d" % [tr["id"], i]
	if not s.flags.has(key):
		s.flags[key] = s.rng("world").randf() < (1.0 - rel / 100.0) * 0.5
	if bool(s.flags[key]):
		return {"bonus": prod_w - 2.0, "text": "%s missed the call time. You go up cold." % op["name"]}
	var fit := 5.0 if str(op.get("style", "")) != str(s.player.get("style", "")) else 2.0
	fit += audience_fit(db, op, vtype)
	return {"bonus": rel / 20.0 + fit + prod_w, "text": "%s opens and warms the room up." % op["name"]}


## Settles a played leg exactly once. score: the set score (0-100).
static func settle_leg(s: GameState, db: ContentDB, tr: Dictionary, i: int, score: float) -> Dictionary:
	var leg: Dictionary = tr["legs"][i]
	if not RewardRules.claim(s, "tour_%s_leg_%d" % [tr["id"], i]):
		return {"ok": false, "payout": int(leg["payout"])}
	leg["score"] = score
	var mid: String = str(leg["market"])
	var payout := 0
	var lines: Array = []
	if str(tr["role"]) == "opener":
		payout = int(tr.get("pay_per_show", 150))
		lines.append("Opener fee: %s." % money_text(payout))
		s.stats["road_sets"] = int(s.stats.get("road_sets", 0)) + 1
	else:
		var gross: int = int(leg["gross"])
		var cut_amt := int(round(gross * float(leg["cut"])))
		payout = gross - cut_amt - (int(leg["rent"]) - int(leg["deposit"]))
		lines.append("Gross %s (%d × $%d) − venue cut %s − rent balance %s = payout %s." % [money_text(gross), int(leg["sold"]), int(tr["price"]), money_text(cut_amt), money_text(int(leg["rent"]) - int(leg["deposit"])), money_text(payout)])
		s.stats["headline_sets"] = int(s.stats.get("headline_sets", 0)) + 1
		var vtype: String = str(leg["venue_type"])
		if vtype == "theater":
			s.stats["theater_sets"] = int(s.stats.get("theater_sets", 0)) + 1
		var prod_cost: int = int(production(db, str(tr.get("production", "standard"))).get("cost", 0)) if vtype == "arena" else 0
		leg["show_profit"] = gross - cut_amt - int(leg["rent"]) - prod_cost
		if vtype == "arena":
			s.stats["arena_sets"] = int(s.stats.get("arena_sets", 0)) + 1
			if int(leg["sold"]) >= int(leg["cap"]):
				s.stats["arena_sellouts"] = int(s.stats.get("arena_sellouts", 0)) + 1
			if int(leg["show_profit"]) > 0:
				s.stats["arena_profitable"] = int(s.stats.get("arena_profitable", 0)) + 1
			lines.append("Show profit after rent and production: %s." % money_text(int(leg["show_profit"])))
		if int(leg["sold"]) >= int(leg["cap"]):
			s.stats["sellouts"] = int(s.stats.get("sellouts", 0)) + 1
			lines.append("SOLD OUT.")
		var op := opener_for(s, db, str(tr.get("opener", "")))
		if not op.is_empty():
			if str(op.get("npc", "")) != "":
				Relationships.change(s, str(op["npc"]), {"chemistry": 2, "trust": 2, "respect": 1})
			s.stats["talent_helped"] = int(s.stats.get("talent_helped", 0)) + 1
			lines.append_array(mentor(s, db, op))
	leg["payout"] = payout
	if payout > 0:
		StatsRules.add_cash(s, payout, "Tour settlement: " + str(market(db, mid).get("name", mid)))
	# Fans grow with good shows, shrink with bad ones.
	var fan_delta: int = int(t(db, "fans_per_good_show", 40)) if score >= 60.0 else (int(t(db, "fans_per_bad_show", -15)) if score < 40.0 else 10)
	s.fans[mid] = maxi(0, int(s.fans.get(mid, 0)) + fan_delta)
	s.flags["tour_last_" + mid] = int(leg["day"])
	var fame_mult := {"club": 1.0, "theater": 2.0, "arena": 5.0}.get(str(leg["venue_type"]), 1.0) as float
	if str(leg["venue_type"]) == "arena":
		fame_mult *= float(production(db, str(tr.get("production", "standard"))).get("fame_mult", 1.0))
	s.fame += maxf(0.0, (score - 50.0) * 0.03) * fame_mult
	lines.append("Local fans %+d." % fan_delta)
	return {"ok": true, "payout": payout, "lines": lines}


## Mentorship: openers you keep booking grow. At their breakout they get
## pricier but more reliable, and the payoff comes back to you.
static func mentor(s: GameState, db: ContentDB, op: Dictionary) -> Array:
	var id: String = str(op["id"])
	s.mentees[id] = int(s.mentees.get(id, 0)) + 1
	var out: Array = []
	if int(s.mentees[id]) >= int(op.get("breakout_shows", 6)) and not s.flags.has("breakout_" + id):
		s.flags["breakout_" + id] = true
		var bo: Dictionary = op.get("breakout", {"text": "%s is headlining on their own now, and tells everyone you gave them their start." % op["name"], "effects": {"rep": 2}})
		var txt := GameSim.fmt(s, db, str(bo.get("text", "")))
		out.append("BREAKOUT: " + txt)
		out.append_array(StatsRules.apply_effects(s, db, bo.get("effects", {}), "", "mentorship"))
		s.add_message(txt)
		s.stats["breakouts"] = int(s.stats.get("breakouts", 0)) + 1
	return out


static func finish(s: GameState, db: ContentDB, tr: Dictionary) -> Dictionary:
	if str(tr["status"]) == "done":
		return summary(tr)
	tr["status"] = "done"
	s.flags.erase("active_tour")
	if str(tr.get("offer_id", "")) != "":
		OpportunityRules.on_complete(s, db, str(tr["offer_id"]))
	CareerRules.update(s, db)
	return summary(tr)


static func summary(tr: Dictionary) -> Dictionary:
	var revenue := 0
	var sold := 0
	var cap := 0
	for leg in tr["legs"]:
		revenue += int(leg["payout"])
		sold += maxi(0, int(leg["sold"]))
		cap += int(leg["cap"])
	var costs: int = int(tr["deposits"]) + int(tr["marketing"]) + int(tr["committed"])
	return {"revenue": revenue, "costs": costs, "profit": revenue - costs, "sold": sold, "cap": cap}
