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
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var v := UiKit.vbox(2)
	add_child(v)
	var row := UiKit.hbox(16)
	v.add_child(row)
	_time = UiKit.label("", 20, UiKit.C_ACCENT, false)
	row.add_child(_time)
	_stats = UiKit.label("", 17, UiKit.C_TEXT, false)
	_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats.clip_text = true
	row.add_child(_stats)
	for spec in [["Journal", "journal"], ["Phone", "phone"], ["Wait", "wait"]]:
		var sig: String = spec[1]
		var bt := UiKit.button("%s [%s]" % [spec[0], GameSettings.key_label(sig)], func(): _emit(sig))
		bt.add_theme_font_size_override("font_size", GameSettings.font_size(16))
		row.add_child(bt)
	var mb := UiKit.button("Menu [Esc]", func(): menu_pressed.emit())
	mb.add_theme_font_size_override("font_size", GameSettings.font_size(16))
	row.add_child(mb)
	var row2 := UiKit.hbox(14)
	v.add_child(row2)
	_next = UiKit.label("", 16, UiKit.C_WARN, false)
	_next.clip_text = true
	_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(_next)
	_go_now = UiKit.button("Go there now", func(): go_now_pressed.emit(str(_go_now.get_meta("cid", ""))))
	_go_now.visible = false
	row2.add_child(_go_now)
	_objective = UiKit.label("", 16, UiKit.C_GOOD, false)
	_objective.clip_text = true
	_objective.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row2.add_child(_objective)
	Game.state_changed.connect(refresh)
	refresh()


func _emit(sig: String) -> void:
	match sig:
		"journal": journal_pressed.emit()
		"phone": phone_pressed.emit()
		"wait": wait_pressed.emit()


func refresh() -> void:
	var s: GameState = Game.state
	if s == null:
		return
	_time.text = "Wk %d · %s %s" % [CalendarRules.week_number(s.day), CalendarRules.day_short(s.day), CalendarRules.block_name(s.block)]
	_stats.text = "%s  ·  Energy %d %s  ·  Stress %d %s  ·  Conf %d" % [UiKit.money(s.cash), s.energy, UiKit.bar_text(s.energy, 100, 6), s.stress, UiKit.bar_text(s.stress, 100, 6), s.confidence]
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
