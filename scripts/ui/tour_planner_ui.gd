class_name TourPlannerUI
extends VBoxContainer
## Plan a headline tour: cities, venues, dates, ticket price, marketing,
## transport, lodging and opener, with a live forecast. Forecast revenue is
## labelled as a forecast and is never spendable cash.

var ui: UiLayer
var on_booked: Callable
var plan: Dictionary = {}


func setup(p_ui: UiLayer, p_on_booked: Callable) -> TourPlannerUI:
	ui = p_ui
	on_booked = p_on_booked
	var s: GameState = Game.state
	plan = {"start_day": s.day + 3, "legs": [], "price": 25, "marketing": 150, "transport": "van", "lodging": "motel", "opener": ""}
	add_theme_constant_override("separation", 6)
	custom_minimum_size = Vector2(1180, 640)
	_build()
	return self


func _row(title: String) -> HFlowContainer:
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", 6)
	h.add_theme_constant_override("v_separation", 4)
	var l := UiKit.label(title, 17, UiKit.C_ACCENT, false)
	l.custom_minimum_size = Vector2(130, 0)
	h.add_child(l)
	return h


func _opt(row: HFlowContainer, text: String, selected: bool, cb: Callable, enabled: bool = true, tip: String = "") -> void:
	var b := UiKit.button(("● " if selected else "○ ") + text, cb, enabled, tip)
	b.add_theme_font_size_override("font_size", GameSettings.font_size(15))
	row.add_child(b)


func _choose(key: String, v: Variant) -> void:
	plan[key] = v
	_build()


func _build() -> void:
	UiKit.clear(self)
	var s: GameState = Game.state
	var db: ContentDB = Game.db
	add_child(UiKit.title("Plan a headline tour"))
	var sc := UiKit.scroll(500)
	add_child(sc)
	var v := UiKit.vbox(6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	# Dates.
	var r0 := _row("Leave on")
	for d in range(s.day + 2, s.day + 12):
		var dd := d
		_opt(r0, CalendarRules.describe_slot(d, 0).replace(", Morning", ""), int(plan["start_day"]) == d, func(): _choose("start_day", dd))
	v.add_child(r0)
	# Cities.
	var legs: Array = plan["legs"]
	var r1 := _row("Route")
	if legs.is_empty():
		r1.add_child(UiKit.label("(add cities below, one per night)", 16, UiKit.C_DIM, false))
	for i in range(legs.size()):
		var idx := i
		var m := TourRules.market(db, str(legs[i]["market"]))
		_opt(r1, "%d. %s · %s  ✕" % [i + 1, str(m["name"]).split(",")[0], legs[i]["venue_type"]], true, func(): _remove_leg(idx))
	v.add_child(r1)
	var theater_ok := s.career_tier >= int(TourRules.t(db, "theater_min_tier", 6))
	var r2 := _row("Add city")
	for m in db.touring.get("markets", []):
		var mid: String = str(m["id"])
		var fame_ok := s.fame >= float(m.get("min_fame", 0))
		var label := "%s%s" % [str(m["name"]).split(",")[0], "" if bool(m.get("drive", false)) else " ✈"]
		_opt(r2, label + " (club)", false, func(): _add_leg(mid, "club"), fame_ok and legs.size() < int(TourRules.t(db, "max_legs", 5)), "Needs fame %d" % int(m.get("min_fame", 0)))
		if theater_ok:
			_opt(r2, label + " (theater)", false, func(): _add_leg(mid, "theater"), fame_ok and legs.size() < int(TourRules.t(db, "max_legs", 5)))
	v.add_child(r2)
	# Price / marketing / transport / lodging.
	var r3 := _row("Ticket price")
	for p in TourRules.t(db, "prices", [20, 25, 35]):
		var pv: int = int(p)
		_opt(r3, "$%d" % pv, int(plan["price"]) == pv, func(): _choose("price", pv))
	v.add_child(r3)
	var r4 := _row("Marketing")
	for mk in TourRules.t(db, "marketing_options", [0, 150, 400]):
		var mv: int = int(mk)
		_opt(r4, "none" if mv == 0 else "$%d" % mv, int(plan["marketing"]) == mv, func(): _choose("marketing", mv))
	v.add_child(r4)
	var r5 := _row("Transport")
	_opt(r5, "Van (Texas only, cheap, +stress)", plan["transport"] == "van", func(): _choose("transport", "van"))
	_opt(r5, "Fly", plan["transport"] == "flight", func(): _choose("transport", "flight"))
	v.add_child(r5)
	var r6 := _row("Lodging")
	_opt(r6, "Motels (cheap, poor rest)", plan["lodging"] == "motel", func(): _choose("lodging", "motel"))
	_opt(r6, "Hotels (better rest)", plan["lodging"] == "hotel", func(): _choose("lodging", "hotel"))
	v.add_child(r6)
	var r7 := _row("Opener")
	_opt(r7, "None", str(plan["opener"]) == "", func(): _choose("opener", ""))
	for o in db.touring.get("openers", []):
		var oid: String = str(o["id"])
		var relt := ""
		if str(o.get("npc", "")) != "":
			relt = ", trust %d" % int(s.rel(str(o["npc"]))["trust"])
		_opt(r7, "%s ($%d/show)" % [o["name"], int(o["fee"])], str(plan["opener"]) == oid, func(): _choose("opener", oid), true,
			"%s Reliability %d%s. Style: %s. Career potential: %s." % [o["desc"], int(o["reliability"]), relt, o["style"], o["potential"]])
	v.add_child(r7)
	# Forecast.
	var ev := TourRules.evaluate_plan(s, db, plan)
	var t := "[b]FORECAST[/b] (estimates, not money in the bank)\n"
	for f in ev["legs"]:
		var dm: Dictionary = f["demand"]
		t += "  %s · %s · %s (cap %d): expect ~%d sold → gross %s  [draw ×%.2f, price ×%.2f, marketing ×%.2f%s]\n" % [CalendarRules.describe_slot(int(f["day"]), 2), TourRules.market(db, str(f["market"]))["name"], f["venue_name"], int(f["cap"]), int(f["expected"]), TourRules.money_text(int(f["gross"])), float(dm["star"]), float(dm["price_factor"]), float(dm["marketing_factor"]), ", played recently ×0.6" if float(dm["recency"]) < 1.0 else ""]
	t += "\n[b]Pay now:[/b] deposits %s + marketing %s = %s" % [TourRules.money_text(int(ev["deposits"])), TourRules.money_text(int(ev["marketing"])), TourRules.money_text(int(ev["upfront"]))]
	t += "\n[b]Reserved, charged at departure:[/b] transport %s + lodging %s + opener %s = %s" % [TourRules.money_text(int(ev["transport_cost"])), TourRules.money_text(int(ev["lodging_cost"])), TourRules.money_text(int(ev["opener_cost"])), TourRules.money_text(int(ev["committed"]))]
	t += "\n[b]Forecast revenue after venue cuts:[/b] %s (not spendable)  ·  [b]Forecast profit:[/b] %s" % [TourRules.money_text(int(ev["forecast_revenue"])), TourRules.money_text(int(ev["forecast_net"]))]
	t += "\n[b]Cash available:[/b] %s  ·  Away %d night(s), back the following afternoon." % [TourRules.money_text(s.cash), int(ev["nights"])]
	for e in ev["errors"]:
		t += "\n[color=#ff8a8a]✕ %s[/color]" % str(e)
	for c in ev["conflicts"]:
		t += "\n[color=#ffd27a]⚠ Overlaps: %s (%s)[/color]" % [c["title"], CalendarRules.describe_slot(int(c["day"]), int(c["block"]))]
	v.add_child(UiKit.rich(t, 16))
	# Always-visible money summary next to the Book button.
	var sm := "[b]Pay now[/b] %s  ·  [b]Reserved[/b] %s  ·  [b]Forecast revenue[/b] %s [i](not spendable)[/i]  ·  [b]Forecast profit[/b] %s  ·  [b]Cash[/b] %s" % [TourRules.money_text(int(ev["upfront"])), TourRules.money_text(int(ev["committed"])), TourRules.money_text(int(ev["forecast_revenue"])), TourRules.money_text(int(ev["forecast_net"])), TourRules.money_text(s.cash)]
	if not (ev["errors"] as Array).is_empty():
		sm += "\n[color=#ff8a8a]✕ %s[/color]" % str(ev["errors"][0])
	add_child(UiKit.rich(sm, 16))
	add_child(UiKit.button("Book this tour", func(): _book(false), bool(ev["ok"]), "Fix the issues listed above first."))


func _add_leg(mid: String, vtype: String) -> void:
	(plan["legs"] as Array).append({"market": mid, "venue_type": vtype})
	_build()


func _remove_leg(i: int) -> void:
	(plan["legs"] as Array).remove_at(i)
	_build()


func _book(force: bool) -> void:
	var res := TourRules.book(Game.state, Game.db, plan, force)
	if not bool(res["ok"]) and res.has("conflicts"):
		ui.confirm("Conflicts", "The tour overlaps other commitments. Booking it means you'll miss them.", "Book anyway", func(): _book(true))
		return
	if not bool(res["ok"]):
		ui.info("Can't book", str(res["message"]))
		return
	Game.notify()
	if on_booked.is_valid():
		on_booked.call(str(res["message"]))
