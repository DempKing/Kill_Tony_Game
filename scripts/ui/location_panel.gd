class_name LocationPanel
extends VBoxContainer
## Interior view for a location: a simple illustrated vignette, who's here,
## and every available action with time cost and conflict warnings.

class InteriorArt extends Control:
	var loc: Dictionary = {}
	var npc_colors: Array = []
	var npc_names: Array = []
	var block: int = 0

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var it: Dictionary = loc.get("interior", {})
		var wall := Color(str(it.get("wall", loc.get("color", "#333344"))))
		var floor_c := Color(str(it.get("floor", "#222222")))
		var accent := Color(str(it.get("accent", loc.get("sign_color", "#ffffff"))))
		draw_rect(Rect2(0, 0, w, h * 0.68), wall)
		draw_rect(Rect2(0, h * 0.68, w, h * 0.32), floor_c)
		draw_rect(Rect2(0, h * 0.66, w, 6), accent.darkened(0.3))
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(24, 44), str(loc.get("name", "")).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, accent)
		var id: String = str(loc.get("id", ""))
		match id:
			"rusty_spur", "lantern", "cellar", "mothership":
				# Small stage, mic, spotlight.
				draw_rect(Rect2(w * 0.6, h * 0.55, w * 0.32, h * 0.13), Color(0.1, 0.08, 0.06))
				draw_circle(Vector2(w * 0.76, h * 0.3), h * 0.28, Color(accent, 0.12))
				draw_line(Vector2(w * 0.76, h * 0.38), Vector2(w * 0.76, h * 0.56), Color(0.75, 0.75, 0.8), 4)
				draw_circle(Vector2(w * 0.76, h * 0.37), 7, Color(0.3, 0.3, 0.32))
				for i in range(6):
					draw_circle(Vector2(w * 0.1 + i * w * 0.08, h * 0.85), 14, Color(0.08, 0.08, 0.1))
			"diner", "coffee":
				for i in range(3):
					var x := w * 0.1 + i * w * 0.18
					draw_rect(Rect2(x, h * 0.6, w * 0.12, h * 0.05), accent.darkened(0.4))
					draw_rect(Rect2(x + w * 0.05, h * 0.65, 8, h * 0.15), Color(0.2, 0.2, 0.2))
				draw_rect(Rect2(w * 0.65, h * 0.45, w * 0.3, h * 0.2), accent.darkened(0.2))
			"hostel", "apartments":
				for i in range(3):
					var bx := w * 0.08 + i * w * 0.2
					draw_rect(Rect2(bx, h * 0.38, w * 0.15, h * 0.08), Color(0.5, 0.45, 0.4))
					draw_rect(Rect2(bx, h * 0.58, w * 0.15, h * 0.08), Color(0.5, 0.45, 0.4))
					draw_rect(Rect2(bx, h * 0.3, 6, h * 0.4), Color(0.3, 0.25, 0.2))
				draw_rect(Rect2(w * 0.75, h * 0.15, w * 0.15, h * 0.2), Color(0.55, 0.7, 0.9, 0.6))
			"mart":
				for i in range(4):
					draw_rect(Rect2(w * 0.08 + i * w * 0.14, h * 0.25, w * 0.1, h * 0.42), accent.darkened(0.5))
		# Night window tint.
		if block >= 2:
			draw_rect(Rect2(0, 0, w, h), Color(0.05, 0.02, 0.15, 0.25))
		# People present.
		for i in range(npc_colors.size()):
			var px := w * 0.2 + i * 120.0
			var py := h * 0.72
			draw_circle(Vector2(px, py - 52), 18, Color("#e8c8a8"))
			draw_rect(Rect2(px - 18, py - 34, 36, 52), npc_colors[i])
			draw_string(font, Vector2(px - 50, py + 40), str(npc_names[i]), HORIZONTAL_ALIGNMENT_CENTER, 100, 15, Color.WHITE)


var host: Node   # District
var ui: UiLayer
var location_id: String
var _actions_box: VBoxContainer
var _log: RichTextLabel
var _art: InteriorArt


func setup(p_host: Node, p_ui: UiLayer, p_location: String) -> LocationPanel:
	host = p_host
	ui = p_ui
	location_id = p_location
	add_theme_constant_override("separation", 8)
	custom_minimum_size = Vector2(1000, 0)
	_build()
	return self


func _build(log_text: String = "") -> void:
	UiKit.clear(self)
	var s: GameState = Game.state
	var db: ContentDB = Game.db
	var loc: Dictionary = db.locations.get(location_id, {})
	_art = InteriorArt.new()
	_art.loc = loc
	_art.block = s.block
	_art.custom_minimum_size = Vector2(980, 230)
	var here := WorldRules.npcs_at(s, db, location_id)
	for n in here:
		_art.npc_colors.append(Color(str(db.npcs[n].get("color", "#888888"))))
		_art.npc_names.append(str(db.npcs[n]["name"]).split(" ")[0])
	add_child(_art)
	add_child(UiKit.label("%s  ·  %s" % [loc.get("desc", ""), CalendarRules.describe(s.day, s.block)], 18, UiKit.C_DIM))
	_log = UiKit.rich(log_text)
	add_child(_log)
	var sc := UiKit.scroll(300)
	add_child(sc)
	_actions_box = UiKit.vbox(6)
	_actions_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_actions_box)
	var actions := GameSim.actions_for(s, db, location_id)
	if actions.is_empty():
		_actions_box.add_child(UiKit.label("Nothing to do here right now. Places change through the day and week.", 18, UiKit.C_DIM))
	for a in actions:
		var act: Dictionary = a
		var cost := ""
		if int(act["blocks"]) > 0:
			cost = "  [%d block%s]" % [int(act["blocks"]), "s" if int(act["blocks"]) > 1 else ""]
		var hint := str(act["hint"]) if bool(act["enabled"]) else str(act["reason"])
		var b := UiKit.button(str(act["label"]) + cost, func(): _try(act), bool(act["enabled"]), hint)
		_actions_box.add_child(b)
		_actions_box.add_child(UiKit.label("     " + hint, 15, UiKit.C_DIM if bool(act["enabled"]) else UiKit.C_BAD))
	UiKit.focus_first(_actions_box)


func refresh(log_text: String = "") -> void:
	_build(log_text)


## Warns about conflicts before running anything that takes time.
func _try(a: Dictionary) -> void:
	var s: GameState = Game.state
	var conf := GameSim.conflicts_for(s, a)
	if not conf.is_empty():
		var names: Array = []
		for c in conf:
			names.append("%s (%s)" % [c["title"], CalendarRules.describe_slot(int(c["day"]), int(c["block"]))])
		ui.confirm("Scheduling conflict", "This takes %d block(s) and overlaps:\n• %s\n\nIf you go ahead, you'll miss it, and the people involved will notice." % [int(a["blocks"]), "\n• ".join(PackedStringArray(names))], "Do it anyway", func(): _run(a, true))
		return
	if str(a["id"]) == "kt_signup":
		var info := KillTonyRules.signup_info(s, Game.db)
		ui.confirm("Kill Tony signup", "\n".join(PackedStringArray(info["lines"])), "Put my name in", func(): _run(a, not (info["conflicts"] as Array).is_empty()))
		return
	_run(a, false)


func _run(a: Dictionary, force: bool) -> void:
	var act := a.duplicate(true)
	act["force"] = force
	var res := GameSim.run_action(Game.state, Game.db, act)
	Game.notify()
	var open: String = str(res.get("open", ""))
	match open:
		"writing":
			host.open_writing(location_id)
			return
		"shift":
			host.open_shift(res["shift"])
			return
		"set_builder":
			host.open_set_builder(str(res["venue_id"]), str(res.get("commitment_id", "")))
			return
		"kill_tony":
			host.start_kill_tony(str(res["commitment_id"]))
			return
		"leads", "schedule":
			ui.info("", str(res["message"]))
			refresh()
			return
	var msg := str(res.get("message", ""))
	if not bool(res.get("ok", true)):
		msg = "[color=#ff8a8a]%s[/color]" % msg
	host.after_action()
	refresh(msg)
