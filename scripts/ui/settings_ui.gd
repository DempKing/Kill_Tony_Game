class_name SettingsUI
extends VBoxContainer
## Display, audio, accessibility and key remapping.

var ui: UiLayer
var _waiting_action: String = ""
var _wait_label: Label


func setup(p_ui: UiLayer) -> SettingsUI:
	ui = p_ui
	add_theme_constant_override("separation", 8)
	_build()
	return self


func _build() -> void:
	UiKit.clear(self)
	var v: Dictionary = GameSettings.values
	add_child(UiKit.title("Settings"))
	# Display.
	var row := UiKit.hbox(6)
	row.add_child(UiKit.label("Window:", 18, UiKit.C_TEXT, false))
	for m in [["windowed", "Windowed"], ["fullscreen", "Fullscreen"], ["exclusive", "Exclusive fullscreen"]]:
		var mid: String = m[0]
		row.add_child(UiKit.button(("● " if str(v["window_mode"]) == mid else "○ ") + str(m[1]), func(): _apply_setting("window_mode", mid)))
	add_child(row)
	var row2 := UiKit.hbox(6)
	row2.add_child(UiKit.label("Resolution:", 18, UiKit.C_TEXT, false))
	for i in range(GameSettings.RESOLUTIONS.size()):
		var r: Vector2i = GameSettings.RESOLUTIONS[i]
		var idx := i
		row2.add_child(UiKit.button(("● " if int(v["resolution"]) == i else "○ ") + "%dx%d" % [r.x, r.y], func(): _apply_setting("resolution", idx)))
	add_child(row2)
	# Audio.
	for bus in ["master", "Music", "Ambience", "SFX"]:
		var b: String = bus
		var h := UiKit.hbox(8)
		var l := UiKit.label("%s volume: %d%%" % [b.capitalize(), int(float(v[b]) * 100)], 18, UiKit.C_TEXT, false)
		l.custom_minimum_size = Vector2(260, 0)
		h.add_child(l)
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = float(v[b])
		sl.custom_minimum_size = Vector2(320, 24)
		sl.focus_mode = Control.FOCUS_ALL
		sl.value_changed.connect(func(x: float):
			GameSettings.set_value(b, x)
			l.text = "%s volume: %d%%" % [b.capitalize(), int(x * 100)])
		h.add_child(sl)
		add_child(h)
	# Accessibility.
	var row3 := UiKit.hbox(6)
	row3.add_child(UiKit.label("Text size:", 18, UiKit.C_TEXT, false))
	for ts in [0.85, 1.0, 1.2, 1.4]:
		var tsv: float = ts
		row3.add_child(UiKit.button(("● " if absf(float(v["text_scale"]) - tsv) < 0.01 else "○ ") + "%d%%" % int(tsv * 100), func(): _apply_setting("text_scale", tsv)))
	add_child(row3)
	add_child(UiKit.button(("☑" if bool(v["reduced_motion"]) else "☐") + " Reduced motion (no camera pans, bobbing or flashing signs)", func(): _apply_setting("reduced_motion", not bool(GameSettings.values["reduced_motion"]))))
	add_child(UiKit.button(("☑" if bool(v["subtitles"]) else "☐") + " Subtitles for important sounds", func(): _apply_setting("subtitles", not bool(GameSettings.values["subtitles"]))))
	add_child(UiKit.label("Dialogue choices are never timed. The game pauses whenever a menu is open.", 16, UiKit.C_DIM))
	# Key remapping.
	add_child(UiKit.label("KEYBOARD (controller buttons are fixed: A interact, Y journal, X phone, RB wait, Start menu, D-pad / left stick move)", 17, UiKit.C_ACCENT))
	_wait_label = UiKit.label("", 18, UiKit.C_WARN)
	add_child(_wait_label)
	var grid := GridContainer.new()
	grid.columns = 2
	for a in GameSettings.ACTIONS:
		var aid: String = a
		grid.add_child(UiKit.label(str(GameSettings.ACTIONS[a][0]), 17, UiKit.C_TEXT, false))
		grid.add_child(UiKit.button("[%s]  change" % GameSettings.key_label(aid), func(): _start_rebind(aid)))
	add_child(grid)
	add_child(UiKit.button("Reset key bindings", func():
		GameSettings.reset_bindings()
		_build()))


func _apply_setting(key: String, val: Variant) -> void:
	GameSettings.set_value(key, val)
	_build()
	UiKit.focus_first(self)


func _start_rebind(action: String) -> void:
	_waiting_action = action
	_wait_label.text = "Press a key for \"%s\" (Esc cancels)..." % GameSettings.ACTIONS[action][0]


func _input(event: InputEvent) -> void:
	if _waiting_action == "" or not (event is InputEventKey) or not event.is_pressed():
		return
	var k := event as InputEventKey
	get_viewport().set_input_as_handled()
	if k.physical_keycode == KEY_ESCAPE and _waiting_action != "pause":
		_waiting_action = ""
		_wait_label.text = ""
		return
	GameSettings.rebind(_waiting_action, int(k.physical_keycode))
	_waiting_action = ""
	_build()
