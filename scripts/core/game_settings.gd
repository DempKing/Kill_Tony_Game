extends Node
## Autoload "GameSettings". Display, audio, accessibility and key bindings,
## persisted to user://settings.cfg. Also registers the game's input actions
## (so remapping works without hand-editing project.godot).

signal changed

const PATH := "user://settings.cfg"
const BUSES: Array = ["Music", "Ambience", "SFX"]
const RESOLUTIONS: Array = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]

## Rebindable actions: id -> [label, default physical keycode, joypad button or -1]
const ACTIONS: Dictionary = {
	"move_up": ["Move up", KEY_W, JOY_BUTTON_DPAD_UP],
	"move_down": ["Move down", KEY_S, JOY_BUTTON_DPAD_DOWN],
	"move_left": ["Move left", KEY_A, JOY_BUTTON_DPAD_LEFT],
	"move_right": ["Move right", KEY_D, JOY_BUTTON_DPAD_RIGHT],
	"interact": ["Interact", KEY_E, JOY_BUTTON_A],
	"journal": ["Journal", KEY_J, JOY_BUTTON_Y],
	"phone": ["Phone / calendar", KEY_P, JOY_BUTTON_X],
	"wait": ["Wait one block", KEY_T, JOY_BUTTON_RIGHT_SHOULDER],
	"pause": ["Pause menu", KEY_ESCAPE, JOY_BUTTON_START],
	"dev_panel": ["Developer panel (dev builds)", KEY_F12, -1],
}

var values: Dictionary = {
	"window_mode": "windowed",
	"resolution": 1,
	"master": 0.8,
	"Music": 0.7,
	"Ambience": 0.7,
	"SFX": 0.8,
	"text_scale": 1.0,
	"reduced_motion": false,
	"subtitles": true,
	"bindings": {},
}
var theme: Theme


func _ready() -> void:
	_add_symbol_fallback()
	_ensure_buses()
	_load()
	_register_actions()
	apply()


## Browsers have no system font fallback, so symbols like ● ○ → ⚠ would show
## as boxes in the web build. Bundle DejaVu Sans (permissive license, see
## assets/fonts/DejaVu-LICENSE.txt) as a fallback behind the default font.
func _add_symbol_fallback() -> void:
	var path := "res://assets/fonts/DejaVuSans.ttf"
	if not ResourceLoader.exists(path):
		return
	var dv: Font = load(path)
	var base: Font = ThemeDB.fallback_font
	if dv != null and base != null:
		var fb: Array[Font] = [dv]
		base.fallbacks = fb


func _ensure_buses() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, "Master")


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for k in values.keys():
		if cfg.has_section_key("settings", k):
			values[k] = cfg.get_value("settings", k)


func save() -> void:
	var cfg := ConfigFile.new()
	for k in values:
		cfg.set_value("settings", k, values[k])
	cfg.save(PATH)


func _register_actions() -> void:
	for id in ACTIONS:
		if not InputMap.has_action(id):
			InputMap.add_action(id, 0.4)
		InputMap.action_erase_events(id)
		var key_code: int = int(values["bindings"].get(id, ACTIONS[id][1]))
		var ev := InputEventKey.new()
		ev.physical_keycode = key_code as Key
		InputMap.action_add_event(id, ev)
		var jb: int = int(ACTIONS[id][2])
		if jb >= 0:
			var je := InputEventJoypadButton.new()
			je.button_index = jb as JoyButton
			InputMap.action_add_event(id, je)
	# Arrow keys and the left stick also move.
	var extra := {"move_up": [KEY_UP, JOY_AXIS_LEFT_Y, -1.0], "move_down": [KEY_DOWN, JOY_AXIS_LEFT_Y, 1.0], "move_left": [KEY_LEFT, JOY_AXIS_LEFT_X, -1.0], "move_right": [KEY_RIGHT, JOY_AXIS_LEFT_X, 1.0]}
	for id in extra:
		var k := InputEventKey.new()
		k.physical_keycode = int(extra[id][0]) as Key
		InputMap.action_add_event(id, k)
		var m := InputEventJoypadMotion.new()
		m.axis = int(extra[id][1]) as JoyAxis
		m.axis_value = float(extra[id][2])
		InputMap.action_add_event(id, m)


func rebind(action: String, keycode: int) -> void:
	var b: Dictionary = values["bindings"]
	b[action] = keycode
	values["bindings"] = b
	_register_actions()
	save()
	changed.emit()


func reset_bindings() -> void:
	values["bindings"] = {}
	_register_actions()
	save()
	changed.emit()


func key_label(action: String) -> String:
	var key_code: int = int(values["bindings"].get(action, ACTIONS.get(action, ["", KEY_NONE])[1]))
	return OS.get_keycode_string(key_code as Key)


func set_value(key: String, v: Variant) -> void:
	values[key] = v
	apply()
	save()
	changed.emit()


func apply() -> void:
	# Display (skipped in headless runs; the browser owns the window on web).
	if OS.has_feature("web"):
		var fs := str(values["window_mode"]) != "windowed"
		var cur := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		if fs != cur:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fs else DisplayServer.WINDOW_MODE_WINDOWED)
	elif DisplayServer.get_name() != "headless":
		match str(values["window_mode"]):
			"fullscreen":
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			"exclusive":
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
			_:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				var res: Vector2i = RESOLUTIONS[clampi(int(values["resolution"]), 0, RESOLUTIONS.size() - 1)]
				DisplayServer.window_set_size(res)
	# Audio.
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, float(values["master"]))))
	for b in BUSES:
		var idx := AudioServer.get_bus_index(b)
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(0.0001, float(values[b]))))
	_build_theme()


func text_scale() -> float:
	return float(values["text_scale"])


func reduced_motion() -> bool:
	return bool(values["reduced_motion"])


func font_size(base: int) -> int:
	return int(round(base * text_scale()))


## Shared UI theme: readable sizes, high-contrast focus outlines for
## keyboard/controller navigation.
func _build_theme() -> void:
	theme = Theme.new()
	theme.default_font_size = font_size(20)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("#15131f")
	panel.border_color = Color("#4a4466")
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(8)
	panel.set_content_margin_all(14)
	theme.set_stylebox("panel", "PanelContainer", panel)
	var btn := StyleBoxFlat.new()
	btn.bg_color = Color("#2a2640")
	btn.set_corner_radius_all(6)
	btn.set_content_margin_all(8)
	var btn_hover := btn.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color("#3b3560")
	var btn_focus := StyleBoxFlat.new()
	btn_focus.draw_center = false
	btn_focus.border_color = Color("#ffe27a")
	btn_focus.set_border_width_all(3)
	btn_focus.set_corner_radius_all(6)
	var btn_disabled := btn.duplicate() as StyleBoxFlat
	btn_disabled.bg_color = Color("#1c1a28")
	var btn_pressed := btn.duplicate() as StyleBoxFlat
	btn_pressed.bg_color = Color("#514a80")
	theme.set_stylebox("normal", "Button", btn)
	theme.set_stylebox("hover", "Button", btn_hover)
	theme.set_stylebox("pressed", "Button", btn_pressed)
	theme.set_stylebox("focus", "Button", btn_focus)
	theme.set_stylebox("disabled", "Button", btn_disabled)
	theme.set_color("font_color", "Button", Color("#f0ecff"))
	theme.set_color("font_disabled_color", "Button", Color("#7a7690"))
	theme.set_color("font_color", "Label", Color("#f0ecff"))
	theme.set_color("default_color", "RichTextLabel", Color("#f0ecff"))
	theme.set_font_size("normal_font_size", "RichTextLabel", font_size(19))
	theme.set_font_size("bold_font_size", "RichTextLabel", font_size(19))
	theme.set_stylebox("focus", "LineEdit", btn_focus)
	theme.set_stylebox("focus", "OptionButton", btn_focus)
	theme.set_stylebox("focus", "CheckBox", btn_focus)
	theme.set_stylebox("focus", "HSlider", btn_focus)
	theme.set_stylebox("focus", "ItemList", btn_focus)
