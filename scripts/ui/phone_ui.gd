class_name PhoneUI
extends VBoxContainer
## The phone: calendar & obligations, offers, money, contacts, career, map
## (fast travel to known places; walking never costs time so neither does this).

var host: Node
var ui: UiLayer
var tab: String = "calendar"
var _body: VBoxContainer


func setup(p_host: Node, p_ui: UiLayer, p_tab: String = "calendar") -> PhoneUI:
	host = p_host
	ui = p_ui
	tab = p_tab
	custom_minimum_size = Vector2(1060, 600)
	add_theme_constant_override("separation", 8)
	_build()
	return self


func _build() -> void:
	UiKit.clear(self)
	add_child(UiKit.title("Phone"))
	var tabs := UiKit.hbox(6)
	var offers_n := OpportunityRules.offers(Game.state).size()
	for t in [["calendar", "Calendar"], ["offers", "Offers (%d)" % offers_n], ["money", "Money"], ["contacts", "Contacts"], ["career", "Career"], ["tours", "Tours"], ["map", "Map / travel"], ["log", "Messages"]]:
		var tid: String = t[0]
		tabs.add_child(UiKit.button(("▶ " if tab == tid else "") + str(t[1]), func(): _switch(tid)))
	add_child(tabs)
	var sc := UiKit.scroll(480)
	add_child(sc)
	_body = UiKit.vbox(6)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_body)
	match tab:
		"calendar": _calendar()
		"offers": _offers()
		"money": _money()
		"contacts": _contacts()
		"career": _career()
		"map": _map()
		"tours": _tours()
		"log": _log()


func _switch(t: String) -> void:
	tab = t
	_build()
	UiKit.focus_first(self)


func _calendar() -> void:
	var s: GameState = Game.state
	var db: ContentDB = Game.db
	_body.add_child(UiKit.label("Now: " + CalendarRules.describe(s.day, s.block), 20, UiKit.C_ACCENT))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 4)
	grid.add_child(UiKit.label("Day", 17, UiKit.C_DIM, false))
	for b in CalendarRules.BLOCK_NAMES:
		grid.add_child(UiKit.label(str(b), 17, UiKit.C_DIM, false))
	for d in range(s.day, s.day + 7):
		var wd := CalendarRules.weekday(d)
		grid.add_child(UiKit.label("%s %d" % [CalendarRules.day_short(d), d + 1], 17, UiKit.C_TEXT, false))
		for b in range(4):
			var txt := "·"
			if d == s.day and b < s.block:
				txt = "(past)"
			for c in Scheduler.booked(s):
				if Scheduler.overlaps(c, CalendarRules.slot(d, b), 1):
					txt = "■ " + str(c["title"]).left(22)
			if txt == "·":
				if wd == CalendarRules.MONDAY and b == KillTonyRules.show_block(db):
					txt = "Kill Tony (signup)"
				elif wd != CalendarRules.MONDAY and b >= 2:
					txt = "open mic"
			var l := UiKit.label(txt, 16, UiKit.C_WARN if txt.begins_with("■") else UiKit.C_DIM, false)
			l.custom_minimum_size = Vector2(190, 0)
			grid.add_child(l)
	_body.add_child(grid)
	_body.add_child(UiKit.label("■ = booked commitment. Ordinary walking in the district never costs time; activities show their cost before you confirm.", 15, UiKit.C_DIM))
	if s.housing_id != "":
		var h: Dictionary = db.housing.get(s.housing_id, {})
		if int(h.get("weekly", 0)) > 0:
			_body.add_child(UiKit.label("Rent: $%d due %s." % [int(h["weekly"]), CalendarRules.describe_slot(int(s.rent["next_due_day"]), 0)], 18, UiKit.C_WARN))


func _offers() -> void:
	var s: GameState = Game.state
	var list := OpportunityRules.offers(s)
	if list.is_empty():
		_body.add_child(UiKit.label("No offers right now. Bookers notice reputation, relationships and reliability.", 18, UiKit.C_DIM))
	for o in list:
		var oid: String = str(o["id"])
		var box := UiKit.vbox(4)
		box.add_child(UiKit.label("%s · %s · %ds set · pay $%d · reply by %s" % [o["title"], CalendarRules.describe_slot(int(o["day"]), int(o["block"])), int(o["slot_seconds"]), int(o["pay"]), CalendarRules.describe_slot(int(o["expires_day"]), 3)], 18))
		box.add_child(UiKit.label("From: %s · Venue: %s" % [Game.db.character_name(str(o["npc"])), Game.db.locations.get(str(o["location_id"]), {}).get("name", "")], 16, UiKit.C_DIM))
		var row := UiKit.hbox(6)
		row.add_child(UiKit.button("Accept", func(): _accept(oid, false)))
		row.add_child(UiKit.button("Decline", func():
			OpportunityRules.decline(Game.state, oid)
			_build()))
		box.add_child(row)
		_body.add_child(box)
	var booked := Scheduler.upcoming(s, 10)
	_body.add_child(UiKit.spacer(8))
	_body.add_child(UiKit.label("UPCOMING COMMITMENTS", 18, UiKit.C_ACCENT))
	for c in booked:
		_body.add_child(UiKit.label("■ %s · %s · %s" % [c["title"], CalendarRules.describe_slot(int(c["day"]), int(c["block"])), Game.db.locations.get(str(c["location_id"]), {}).get("name", "")], 17))
	if booked.is_empty():
		_body.add_child(UiKit.label("(none)", 17, UiKit.C_DIM))


func _accept(oid: String, force: bool) -> void:
	var res := OpportunityRules.accept(Game.state, Game.db, oid, force)
	if not bool(res["ok"]) and res.has("conflicts"):
		var names: Array = []
		for c in res["conflicts"]:
			names.append(str(c["title"]))
		ui.confirm("Conflict", "This booking overlaps: %s.\nAccepting will cancel that commitment (and the people involved will remember)." % ", ".join(PackedStringArray(names)), "Accept and cancel the other", func(): _accept(oid, true))
		return
	ui.toast(str(res["message"]))
	Game.notify()
	_build()


func _money() -> void:
	var s: GameState = Game.state
	var db: ContentDB = Game.db
	_body.add_child(UiKit.label("Cash: %s" % UiKit.money(s.cash), 22, UiKit.C_ACCENT))
	var h: Dictionary = db.housing.get(s.housing_id, {})
	_body.add_child(UiKit.label("Housing: %s ($%d/week). Debt: $%d. Daily essentials: $%d." % [h.get("name", "none yet"), int(h.get("weekly", 0)), int(s.rent.get("debt", 0)), db.bali("economy.daily_essentials", 8)], 18))
	var week_in := 0
	var week_out := 0
	for e in s.ledger:
		if int(e["day"]) > s.day - 7:
			if int(e["amount"]) > 0:
				week_in += int(e["amount"])
			else:
				week_out -= int(e["amount"])
	_body.add_child(UiKit.label("Last 7 days: earned $%d, spent $%d." % [week_in, week_out], 18))
	_body.add_child(UiKit.label("LEDGER", 18, UiKit.C_ACCENT))
	for i in range(s.ledger.size() - 1, maxi(-1, s.ledger.size() - 30), -1):
		var e: Dictionary = s.ledger[i]
		_body.add_child(UiKit.label("%s  %s  %s  (balance %s)" % [CalendarRules.describe_slot(int(e["day"]), int(e["block"])), UiKit.money(int(e["amount"])), e["reason"], UiKit.money(int(e["balance"]))], 16, UiKit.C_GOOD if int(e["amount"]) > 0 else UiKit.C_TEXT))


func _contacts() -> void:
	var s: GameState = Game.state
	var db: ContentDB = Game.db
	for id in db.npcs:
		var npc: Dictionary = db.npcs[id]
		var r := s.rel(id)
		var where := WorldRules.npc_location(db, id, s.day, s.block)
		_body.add_child(UiKit.label("%s — %s" % [npc["name"], npc["role"]], 19, UiKit.C_ACCENT))
		_body.add_child(UiKit.label("   Familiarity %d · Respect %d · Chemistry %d · Trust %d · Reliability %d · Now: %s" % [int(r["familiarity"]), int(r["respect"]), int(r["chemistry"]), int(r["trust"]), int(r["reliability"]), db.locations.get(where, {}).get("name", "somewhere else")], 16))
	for pid in ["partner_redban", "partner_host"]:
		if s.relationships.has(pid):
			var r2 := s.rel(pid)
			_body.add_child(UiKit.label("%s — %s" % [db.character_name(pid), "partner character (placeholder, pending approval)"], 19, UiKit.C_ACCENT))
			_body.add_child(UiKit.label("   Familiarity %d · Respect %d" % [int(r2["familiarity"]), int(r2["respect"])], 16))


func _career() -> void:
	var s: GameState = Game.state
	var db: ContentDB = Game.db
	_body.add_child(UiKit.label("%s (\"%s\")" % [s.player.get("name", ""), s.player.get("stage_name", "")], 22, UiKit.C_ACCENT))
	_body.add_child(UiKit.label("Career: %s" % CareerRules.tier_name(db, s.career_tier), 20))
	_body.add_child(UiKit.label(CareerRules.next_requirements(s, db), 17, UiKit.C_DIM))
	_body.add_child(UiKit.label("Fame %.1f · Professional reputation %.1f · Local demand %.1f" % [s.fame, s.reputation, s.local_demand], 18))
	_body.add_child(UiKit.label("Writing %.1f · Delivery %.1f · Crowd work %.1f · Stage presence %.1f" % [StatsRules.skill(s, "writing"), StatsRules.skill(s, "delivery"), StatsRules.skill(s, "crowd_work"), StatsRules.skill(s, "stage_presence")], 18))
	_body.add_child(UiKit.label("Sets %d · Paid sets %d · Bombs %d · Shifts worked %d · Kill Tony appearances %d · Golden tickets %d" % [int(s.stats.get("sets", 0)), int(s.stats.get("paid_sets", 0)), int(s.stats.get("bombs", 0)), int(s.stats.get("shifts", 0)), int(s.kt.get("appearances", 0)), int(s.kt.get("golden_tickets", 0))], 18))
	var jobs: Array = []
	for j in s.jobs:
		jobs.append("%s (reliability %d)" % [db.jobs.get(j, {}).get("name", j), int(s.jobs[j].get("reliability", 0))])
	_body.add_child(UiKit.label("Jobs: " + (", ".join(PackedStringArray(jobs)) if not jobs.is_empty() else "none"), 18))


func _tours() -> void:
	var s: GameState = Game.state
	var db: ContentDB = Game.db
	var chk := TourRules.can_plan(s, db)
	_body.add_child(UiKit.label("Austin is home. Tours are booked here and played on the road. Road offers (opening for headliners) show up under Offers.", 16, UiKit.C_DIM))
	var plan_btn := UiKit.button("Plan a headline tour…", func(): _open_planner(), bool(chk["ok"]), str(chk["reason"]))
	_body.add_child(plan_btn)
	if not bool(chk["ok"]):
		_body.add_child(UiKit.label(str(chk["reason"]), 16, UiKit.C_WARN))
	if s.tours.is_empty():
		_body.add_child(UiKit.label("No tours yet.", 17, UiKit.C_DIM))
	for i in range(s.tours.size() - 1, -1, -1):
		var tr: Dictionary = s.tours[i]
		var sm := TourRules.summary(tr)
		_body.add_child(UiKit.label("%s  ·  %s  ·  leaves %s" % [tr["title"], str(tr["status"]).to_upper(), CalendarRules.describe_slot(int(tr["start_day"]), 0)], 18, UiKit.C_ACCENT))
		for leg in tr["legs"]:
			var sold_txt := ("forecast ~%d" % int(leg["forecast"])) if int(leg["sold"]) < 0 else ("sold %d/%d, payout %s" % [int(leg["sold"]), int(leg["cap"]), TourRules.money_text(int(leg["payout"]))])
			_body.add_child(UiKit.label("   %s · %s · %s" % [CalendarRules.describe_slot(int(leg["day"]), 2), leg["venue_name"], sold_txt], 15))
		if str(tr["role"]) == "headliner":
			_body.add_child(UiKit.label("   Paid: deposits %s, marketing %s · Reserved: %s · Settled so far: %s · Profit so far: %s" % [TourRules.money_text(int(tr["deposits"])), TourRules.money_text(int(tr["marketing"])), TourRules.money_text(int(tr["committed"])), TourRules.money_text(int(sm["revenue"])), TourRules.money_text(int(sm["profit"]))], 15, UiKit.C_WARN))
		else:
			_body.add_child(UiKit.label("   Opening spot: %s per show, travel covered." % TourRules.money_text(int(tr.get("pay_per_show", 0))), 15, UiKit.C_WARN))
		if str(tr["status"]) == "booked":
			var tid: String = str(tr["id"])
			_body.add_child(UiKit.button("Cancel this tour (deposits are not refunded)", func(): _confirm_cancel(tid)))


func _open_planner() -> void:
	ui.open(TourPlannerUI.new().setup(ui, _on_tour_booked), 1220)


func _on_tour_booked(msg: String) -> void:
	ui.close()
	ui.toast(msg)
	_build()


func _confirm_cancel(tid: String) -> void:
	ui.confirm("Cancel tour?", "You'll lose deposits and marketing, and take a reputation hit.", "Cancel tour", func(): _do_cancel(tid))


func _do_cancel(tid: String) -> void:
	ui.toast(str(TourRules.cancel(Game.state, Game.db, tid)["message"]))
	Game.notify()
	_build()


func _map() -> void:
	var s: GameState = Game.state
	var db: ContentDB = Game.db
	_body.add_child(UiKit.label("Fast travel to places you know. Walking costs no time, so neither does this.", 17, UiKit.C_DIM))
	for id in db.location_order:
		if not s.discovered_locations.has(id):
			continue
		var lid: String = id
		var open := GameSim.location_open(db, id, s.block)
		_body.add_child(UiKit.button("%s%s" % [db.locations[id]["name"], "" if open else "  (closed now)"], func():
			ui.close_all()
			host.teleport_to(lid)))


func _log() -> void:
	var s: GameState = Game.state
	for i in range(s.messages.size() - 1, -1, -1):
		var m: Dictionary = s.messages[i]
		_body.add_child(UiKit.label("%s — %s" % [CalendarRules.describe_slot(int(m["day"]), int(m["block"])), m["text"]], 16))
