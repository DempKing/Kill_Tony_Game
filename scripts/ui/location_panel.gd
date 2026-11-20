class_name LocationPanel
extends VBoxContainer
## Interior view for a location: a simple illustrated vignette, who's here,
## and every available action with time cost and conflict warnings.

class InteriorArt extends Control:
	var loc: Dictionary = {}
	var npc_colors: Array = []
	var npc_names: Array = []
	var npc_female: Array = []
	var block: int = 0

	func _glow(c: Vector2, r: float, col: Color) -> void:
		draw_texture_rect(CharacterArt.glow_texture(), Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, col)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var it: Dictionary = loc.get("interior", {})
		var wall := Color(str(it.get("wall", loc.get("color", "#333344"))))
		var floor_c := Color(str(it.get("floor", "#222222")))
		var accent := Color(str(it.get("accent", loc.get("sign_color", "#ffffff"))))
		var fy := h * 0.68
		CharacterArt.vgradient(self, Rect2(0, 0, w, fy), wall.lightened(0.08), wall.darkened(0.2))
		CharacterArt.vgradient(self, Rect2(0, fy, w, h - fy), floor_c.lightened(0.1), floor_c.darkened(0.3))
		for i in range(12):
			var x0 := w * i / 11.0
			draw_line(Vector2(x0, fy), Vector2(w * 0.5 + (x0 - w * 0.5) * 1.8, h), Color(0, 0, 0, 0.12), 1.0)
		draw_rect(Rect2(0, fy - 8, w, 8), accent.darkened(0.45))
		draw_rect(Rect2(0, 0, w, 10), wall.darkened(0.4))
		var font := ThemeDB.fallback_font
		var id: String = str(loc.get("id", ""))
		match id:
			"rusty_spur", "lantern", "cellar", "mothership":
				CharacterArt.vgradient(self, Rect2(w * 0.58, fy - 20, w * 0.34, 28), Color("#3a2a1a"), Color("#1a120a"))
				draw_polygon(PackedVector2Array([Vector2(w * 0.74, 0), Vector2(w * 0.76, 0), Vector2(w * 0.86, fy), Vector2(w * 0.64, fy)]), PackedColorArray([Color(accent, 0.25), Color(accent, 0.25), Color(accent, 0.03), Color(accent, 0.03)]))
				_glow(Vector2(w * 0.75, fy - 10), 110, Color(accent, 0.3))
				draw_line(Vector2(w * 0.75, fy - 90), Vector2(w * 0.75, fy - 20), Color(0.75, 0.75, 0.8), 4)
				draw_circle(Vector2(w * 0.75, fy - 92), 6, Color(0.3, 0.3, 0.32))
				for i in range(3):
					draw_rect(Rect2(w * 0.06 + i * 70, h * 0.12, 54, 70), Color("#f0e6c8"))
					draw_rect(Rect2(w * 0.06 + i * 70, h * 0.12, 54, 16), accent.darkened(0.2))
			"diner", "coffee":
				for i in range(3):
					var tx := w * 0.08 + i * w * 0.17
					draw_rect(Rect2(tx, fy - 6, w * 0.12, 10), accent.darkened(0.3))
					draw_rect(Rect2(tx + w * 0.055, fy + 4, 6, h * 0.14), Color(0.2, 0.2, 0.22))
					draw_circle(Vector2(tx + 20, fy - 12), 6, Color("#f8f4f0"))
				CharacterArt.vgradient(self, Rect2(w * 0.62, fy - 70, w * 0.34, 74), accent.darkened(0.1), accent.darkened(0.45))
				for i in range(4):
					draw_circle(Vector2(w * 0.66 + i * 60, fy - 80), 8, Color(0.9, 0.9, 0.95))
				for i in range(3):
					var lx := w * 0.2 + i * w * 0.25
					draw_line(Vector2(lx, 0), Vector2(lx, 40), Color(0.2, 0.2, 0.2), 2)
					draw_circle(Vector2(lx, 46), 10, Color("#ffe8b0"))
					_glow(Vector2(lx, 50), 60, Color(1.0, 0.85, 0.5, 0.3))
			"hostel", "apartments":
				for i in range(3):
					var bx := w * 0.06 + i * w * 0.18
					draw_rect(Rect2(bx, fy - 140, 8, 140), Color(0.35, 0.28, 0.22))
					draw_rect(Rect2(bx + w * 0.13, fy - 140, 8, 140), Color(0.35, 0.28, 0.22))
					for yy in [fy - 120, fy - 40]:
						draw_rect(Rect2(bx, yy, w * 0.14, 16), Color(0.55, 0.5, 0.45))
						draw_rect(Rect2(bx + 6, yy - 8, 30, 10), Color(0.9, 0.9, 0.95))
				var win := Rect2(w * 0.72, h * 0.1, w * 0.2, h * 0.32)
				CharacterArt.vgradient(self, win, Color("#9fc4e8") if block < 2 else Color("#0a0a20"), Color("#e8d0a8") if block < 2 else Color("#2a1a40"))
				draw_rect(win, Color(0.3, 0.25, 0.2), false, 6.0)
				draw_line(Vector2(win.get_center().x, win.position.y), Vector2(win.get_center().x, win.end.y), Color(0.3, 0.25, 0.2), 4)
				draw_rect(Rect2(w * 0.6, fy - 30, 40, 30), Color("#2a6a3a"))
			"mart":
				for i in range(4):
					var sx := w * 0.06 + i * w * 0.14
					draw_rect(Rect2(sx, h * 0.18, w * 0.11, fy - h * 0.18), accent.darkened(0.55))
					for sy in range(4):
						var shy := h * 0.24 + sy * (fy - h * 0.24) / 4.0
						draw_rect(Rect2(sx + 4, shy, w * 0.11 - 8, 4), Color(0.8, 0.8, 0.85))
						for k in range(5):
							draw_rect(Rect2(sx + 8 + k * 16, shy - 14, 12, 14), Color.from_hsv(fmod(k * 0.21 + sy * 0.13 + i * 0.07, 1.0), 0.6, 0.85))
				draw_rect(Rect2(w * 0.7, fy - 60, w * 0.25, 64), Color("#d8d8e0"))
				_glow(Vector2(w * 0.5, 20), w * 0.5, Color(0.8, 0.9, 1.0, 0.15))
		draw_string(font, Vector2(24, 46), str(loc.get("name", "")).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, accent.lightened(0.2))
		if block >= 2:
			draw_rect(Rect2(0, 0, w, h), Color(0.05, 0.02, 0.15, 0.22))
		for i in range(npc_colors.size()):
			var px := w * 0.22 + i * 130.0
			var lk := CharacterArt.npc_look((npc_colors[i] as Color).to_html(false), bool(npc_female[i]), i * 7 + str(npc_names[i]).length())
			CharacterArt.draw(self, Vector2(px, h - 18), 1.75, lk, {"facing": 1.0 if px < w * 0.5 else -1.0, "expression": "smile"})
			draw_string(font, Vector2(px - 60, h - 150), str(npc_names[i]), HORIZONTAL_ALIGNMENT_CENTER, 120, 16, Color.WHITE)


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
		_art.npc_names.append(str(db.npcs[n]["name"]).split("'")[1] if str(db.npcs[n]["name"]).count("'") >= 2 else str(db.npcs[n]["name"]).split(" ")[0])
		_art.npc_female.append(str(db.npcs[n].get("gender", "")) == "female")
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
		"tour":
			host.start_tour()
			return
		"kt_panel":
			host.start_kt_panel(str(res["commitment_id"]))
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
	if res.has("summary"):
		host.show_day_summary(res["summary"], str(res.get("message", "")))
