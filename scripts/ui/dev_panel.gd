class_name DevPanel
extends VBoxContainer
## DEVELOPMENT ONLY. Only reachable when Game.is_dev_build() is true (debug
## builds, the editor, or exports with the "dev" feature tag). Release
## exports exclude it; see docs/TESTING.md.

var host: Node
var ui: UiLayer
var _out: RichTextLabel


func setup(p_host: Node, p_ui: UiLayer) -> DevPanel:
	host = p_host
	ui = p_ui
	add_theme_constant_override("separation", 6)
	_build()
	return self


func _btn(row: HBoxContainer, text: String, cb: Callable) -> void:
	row.add_child(UiKit.button(text, func():
		cb.call()
		Game.notify()
		_refresh_out()))


func _build() -> void:
	UiKit.clear(self)
	var s: GameState = Game.state
	var db: ContentDB = Game.db
	add_child(UiKit.title("Developer panel (dev builds only)"))
	var r1 := UiKit.hbox(4)
	_btn(r1, "Cash +100", func(): StatsRules.add_cash(s, 100, "DEV"))
	_btn(r1, "Cash -100", func(): StatsRules.add_cash(s, -mini(100, s.cash), "DEV"))
	_btn(r1, "Energy 100", func(): s.energy = 100)
	_btn(r1, "Energy 10", func(): s.energy = 10)
	_btn(r1, "Stress 0", func(): s.stress = 0)
	add_child(r1)
	var r2 := UiKit.hbox(4)
	_btn(r2, "+1 block", func(): GameSim.advance(s, db, 1))
	_btn(r2, "+1 day", func(): GameSim.advance(s, db, 4, true))
	_btn(r2, "Jump to Monday morning", func(): _jump_to(0, 0))
	_btn(r2, "Jump to Thursday afternoon", func(): _jump_to(3, 1))
	add_child(r2)
	var r3 := UiKit.hbox(4)
	_btn(r3, "Unlock all material", func(): _unlock_all())
	_btn(r3, "Writing +10", func(): StatsRules.add_skill(s, "writing", 10.0))
	_btn(r3, "Delivery +10", func(): StatsRules.add_skill(s, "delivery", 10.0))
	_btn(r3, "Rep +10", func(): s.reputation += 10.0)
	_btn(r3, "Career tier +1", func(): s.career_tier = mini(s.career_tier + 1, 9))
	add_child(r3)
	var r4 := UiKit.hbox(4)
	_btn(r4, "Force next bucket: SELECTED", func(): s.flags["dev_force_bucket"] = "selected")
	_btn(r4, "Force next bucket: NOT selected", func(): s.flags["dev_force_bucket"] = "not_selected")
	_btn(r4, "All relationships +10", func(): _rel_all())
	add_child(r4)
	var r5 := UiKit.hbox(4)
	_btn(r5, "Trigger: Secret Show invite", func(): OpportunityRules.create_offer(s, db, "opp_secret_show", s.day))
	_btn(r5, "Trigger: Lantern showcase", func(): OpportunityRules.create_offer(s, db, "opp_lantern_showcase", s.day))
	_btn(r5, "Trigger: Cellar late spot", func(): OpportunityRules.create_offer(s, db, "opp_cellar_late", s.day))
	add_child(r5)
	var r6 := UiKit.hbox(4)
	for id in ["hostel", "mothership", "rusty_spur", "diner", "cellar", "lantern", "coffee"]:
		var lid: String = id
		r6.add_child(UiKit.button("TP " + lid, func():
			ui.close_all()
			host.teleport_to(lid)))
	add_child(r6)
	_out = UiKit.rich("")
	add_child(_out)
	_refresh_out()


func _jump_to(wd: int, block: int) -> void:
	var s: GameState = Game.state
	var guard := 0
	while (CalendarRules.weekday(s.day) != wd or s.block != block) and guard < 40:
		GameSim.advance(s, Game.db, 1, true)
		guard += 1


func _unlock_all() -> void:
	for id in Game.db.components:
		JokeRules.unlock_component(Game.state, Game.db, str(id))


func _rel_all() -> void:
	for id in Game.db.npcs:
		Relationships.change(Game.state, str(id), {"familiarity": 10, "respect": 10, "chemistry": 10, "trust": 10})


func _refresh_out() -> void:
	var s: GameState = Game.state
	var t := "[b]Seeds[/b] master=%s" % str(s.master_seed)
	for k in s.rngs:
		var r: RandomNumberGenerator = s.rngs[k]
		t += "  %s: seed=%s state=%s" % [k, str(r.seed), str(r.state)]
	t += "\n[b]Platform[/b] %s" % PlatformService.platform_name()
	t += "\n[b]Content errors[/b] %d" % Game.db.errors.size()
	for e in Game.db.errors:
		t += "\n  [color=#ff8a8a]%s[/color]" % str(e)
	var br: Array = s.flags.get("last_performance_breakdown", [])
	if not br.is_empty():
		t += "\n[b]Last performance factors[/b]"
		for j in br:
			var parts: Array = []
			for k in j["factors"]:
				parts.append("%s %.1f" % [k, float(j["factors"][k])])
			t += "\n  %s = %.1f  ←  %s" % [j["title"], float(j["score"]), ", ".join(PackedStringArray(parts))]
	_out.text = t
