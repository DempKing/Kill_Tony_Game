extends Control
## Character creation: name, stage name, gender, appearance, background,
## starting style. Backgrounds give hooks, a small skill edge and a little
## starting material; they never lock any career path.

class Preview extends Control:
	var colors: Dictionary = {}
	func _draw() -> void:
		var c := size * 0.5
		draw_rect(Rect2(c.x - 40, c.y - 20, 80, 120), colors.get("outfit", Color.SLATE_BLUE))
		draw_circle(Vector2(c.x, c.y - 55), 38, colors.get("skin", Color.TAN))
		draw_arc(Vector2(c.x, c.y - 60), 38, PI, TAU, 16, colors.get("hair", Color.BLACK), 16)
		if bool(colors.get("long_hair", false)):
			draw_rect(Rect2(c.x - 46, c.y - 64, 12, 56), colors.get("hair", Color.BLACK))
			draw_rect(Rect2(c.x + 34, c.y - 64, 12, 56), colors.get("hair", Color.BLACK))
		draw_rect(Rect2(c.x + 36, c.y, 26, 40), Color("#6b4a2a"))


var setup: Dictionary = {"name": "", "stage_name": "", "gender": "male", "appearance": {"skin": 1, "hair": 0, "outfit": 0}, "background": "server_vet", "style": "observational"}
var _box: VBoxContainer
var _preview: Preview
var _name_edit: LineEdit
var _stage_edit: LineEdit
var ui: UiLayer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GameSettings.theme
	var bg := ColorRect.new()
	bg.color = Color("#110e1c")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.offset_left = 60
	sc.offset_right = -60
	sc.offset_top = 30
	sc.offset_bottom = -30
	add_child(sc)
	var row := UiKit.hbox(30)
	sc.add_child(row)
	_box = UiKit.vbox(10)
	_box.custom_minimum_size = Vector2(1050, 0)
	row.add_child(_box)
	_preview = Preview.new()
	_preview.custom_minimum_size = Vector2(260, 320)
	row.add_child(_preview)
	ui = UiLayer.new()
	add_child(ui)
	_build()


func _colors() -> Dictionary:
	var ap: Dictionary = Game.db.appearance
	var a: Dictionary = setup["appearance"]
	return {"skin": Color(str(ap["skin"][int(a["skin"])])), "hair": Color(str(ap["hair"][int(a["hair"])])), "outfit": Color(str(ap["outfit"][int(a["outfit"])])), "long_hair": setup["gender"] == "female"}


func _build() -> void:
	var db: ContentDB = Game.db
	UiKit.clear(_box)
	_box.add_child(UiKit.title("Who's getting off the bus?"))
	var r1 := UiKit.hbox(10)
	r1.add_child(UiKit.label("Name", 19, UiKit.C_TEXT, false))
	_name_edit = LineEdit.new()
	_name_edit.text = str(setup["name"])
	_name_edit.placeholder_text = "Your name"
	_name_edit.custom_minimum_size = Vector2(300, 0)
	_name_edit.max_length = 30
	_name_edit.text_changed.connect(func(t: String): setup["name"] = t)
	r1.add_child(_name_edit)
	r1.add_child(UiKit.label("Stage name", 19, UiKit.C_TEXT, false))
	_stage_edit = LineEdit.new()
	_stage_edit.text = str(setup["stage_name"])
	_stage_edit.placeholder_text = "What the host will call you"
	_stage_edit.custom_minimum_size = Vector2(300, 0)
	_stage_edit.max_length = 30
	_stage_edit.text_changed.connect(func(t: String): setup["stage_name"] = t)
	r1.add_child(_stage_edit)
	_box.add_child(r1)
	var r2 := UiKit.hbox(6)
	r2.add_child(UiKit.label("Gender", 19, UiKit.C_TEXT, false))
	for gid in ["male", "female"]:
		var g: Dictionary = db.genders.get(gid, {"label": gid.capitalize()})
		var gid_c: String = gid
		r2.add_child(UiKit.button(("● " if setup["gender"] == gid else "○ ") + str(g["label"]), func(): _pick("gender", gid_c)))
	_box.add_child(r2)
	for part in ["skin", "hair", "outfit"]:
		var pr := UiKit.hbox(6)
		pr.add_child(UiKit.label(str(part).capitalize(), 19, UiKit.C_TEXT, false))
		var opts: Array = db.appearance.get(part, [])
		for i in range(opts.size()):
			var idx := i
			var pt: String = part
			var b := UiKit.button(("● " if int(setup["appearance"][part]) == i else "○ ") + "%d" % (i + 1), func(): _pick_appearance(pt, idx))
			b.add_theme_color_override("font_color", Color(str(opts[i])).lightened(0.2))
			pr.add_child(b)
		_box.add_child(pr)
	_box.add_child(UiKit.label("Background (a head start, never a cage)", 21, UiKit.C_ACCENT))
	for bid in db.backgrounds:
		var bg: Dictionary = db.backgrounds[bid]
		var bid_c: String = bid
		_box.add_child(UiKit.button(("● " if setup["background"] == bid else "○ ") + "%s — %s" % [bg["name"], bg["desc"]], func(): _pick("background", bid_c)))
	_box.add_child(UiKit.label("Starting comedy style (you can blend in a second style later)", 21, UiKit.C_ACCENT))
	var sr := GridContainer.new()
	sr.columns = 2
	for sid in db.styles:
		var st: Dictionary = db.styles[sid]
		var sid_c: String = sid
		sr.add_child(UiKit.button(("● " if setup["style"] == sid else "○ ") + "%s — %s" % [st["name"], st["desc"]], func(): _pick("style", sid_c)))
	_box.add_child(sr)
	_box.add_child(UiKit.spacer(10))
	var go := UiKit.button("Get on the bus to Austin  →", func(): _start())
	_box.add_child(go)
	_box.add_child(UiKit.button("Back to title", func(): Game.goto(Game.SCENE_BOOT)))
	_preview.colors = _colors()
	_preview.queue_redraw()
	UiKit.focus_first(_box)


func _pick(key: String, v: String) -> void:
	setup[key] = v
	_build()


func _pick_appearance(part: String, idx: int) -> void:
	setup["appearance"][part] = idx
	_build()


func _start() -> void:
	var n := str(setup["name"]).strip_edges()
	if n == "":
		ui.info("Name", "Give yourself a name first.")
		return
	setup["name"] = n
	if str(setup["stage_name"]).strip_edges() == "":
		setup["stage_name"] = n
	Game.start_new_game(setup)
