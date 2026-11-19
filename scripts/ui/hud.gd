class_name Hud
extends PanelContainer
## Top bar: day, block, cash, energy, stress, confidence, next obligation,
## current objective and quick buttons. Meters show numbers and text bars so
## nothing relies on color alone.

signal journal_pressed
signal phone_pressed
signal wait_pressed
signal menu_pressed
signal go_now_pressed(commitment_id: String)

var _time: Label
var _stats: Label
var _next: Label
var _objective: Label
var _go_now: Button


func _ready() -> void:
	theme = GameSettings.theme
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var v := UiKit.vbox(4)
	add_child(v)
	var row := UiKit.hbox(18)
	v.add_child(row)
	_time = UiKit.label("", 22, UiKit.C_ACCENT, false)
	row.add_child(_time)
	_stats = UiKit.label("", 19, UiKit.C_TEXT, false)
	_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_stats)
	row.add_child(UiKit.button("Journal [%s]" % GameSettings.key_label("journal"), func(): journal_pressed.emit()))
	row.add_child(UiKit.button("Phone [%s]" % GameSettings.key_label("phone"), func(): phone_pressed.emit()))
	row.add_child(UiKit.button("Wait [%s]" % GameSettings.key_label("wait"), func(): wait_pressed.emit()))
	row.add_child(UiKit.button("Menu [Esc]", func(): menu_pressed.emit()))
	var row2 := UiKit.hbox(18)
	v.add_child(row2)
	_next = UiKit.label("", 18, UiKit.C_WARN, false)
	row2.add_child(_next)
	_go_now = UiKit.button("Go there now", func(): go_now_pressed.emit(str(_go_now.get_meta("cid", ""))))
	_go_now.visible = false
	row2.add_child(_go_now)
	_objective = UiKit.label("", 18, UiKit.C_GOOD, false)
	_objective.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row2.add_child(_objective)
	Game.state_changed.connect(refresh)
	refresh()


func refresh() -> void:
	var s: GameState = Game.state
	if s == null:
		return
	_time.text = "Week %d · %s" % [CalendarRules.week_number(s.day), CalendarRules.describe(s.day, s.block)]
	_stats.text = "Cash %s   Energy %d %s   Stress %d %s   Confidence %d" % [UiKit.money(s.cash), s.energy, UiKit.bar_text(s.energy, 100, 8), s.stress, UiKit.bar_text(s.stress, 100, 8), s.confidence]
	var up := Scheduler.upcoming(s, 1)
	_go_now.visible = false
	if up.is_empty():
		var due: int = int(s.rent.get("next_due_day", 7))
		_next.text = "Next: rent due %s" % CalendarRules.describe_slot(due, 0) if s.housing_id != "" and int(Game.db.housing.get(s.housing_id, {}).get("weekly", 0)) > 0 else "No bookings."
	else:
		var c: Dictionary = up[0]
		var now := CalendarRules.slot(s.day, s.block) == Scheduler.start_slot(c)
		_next.text = ("NOW: " if now else "Next: ") + "%s · %s · %s" % [c["title"], CalendarRules.describe_slot(int(c["day"]), int(c["block"])), Game.db.locations.get(str(c["location_id"]), {}).get("name", "")]
		if now and s.location_id != str(c["location_id"]):
			_go_now.visible = true
			_go_now.set_meta("cid", str(c["id"]))
	var obj := GameSim.objective_text(s)
	_objective.text = ("Goal: " + obj) if obj != "" else CareerRules.tier_name(Game.db, s.career_tier)
