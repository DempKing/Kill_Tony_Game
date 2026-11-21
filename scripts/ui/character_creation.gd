extends Control
## Character creation: name, stage name, gender, appearance, background,
## starting style. Backgrounds give hooks, a small skill edge and a little
## starting material; they never lock any career path.

class Preview extends Control:
	var colors: Dictionary = {}
	var hair_style: int = 0
	var t: float = 0.0
	func _process(d: float) -> void:
		t += d
		queue_redraw()
	func _draw() -> void:
		CharacterArt.vgradient(self, Rect2(Vector2.ZERO, size), Color("#1c1430"), Color("#0a0812"))
		draw_texture_rect(CharacterArt.glow_texture(), Rect2(Vector2(size.x * 0.5 - 140, size.y - 120), Vector2(280, 120)), false, Color(1, 0.9, 0.7, 0.35))
		var look := CharacterArt.look_from(colors, {"hair_style": hair_style})
		CharacterArt.draw(self, Vector2(size.x * 0.5, size.y - 40), 3.4, look, {"facing": 1.0, "expression": "smile", "bob": 0.0 if GameSettings.reduced_motion() else sin(t * 2.0) * 1.5})


var setup: Dictionary = {"name": "", "stage_name": "", "gender": "male", "appearance": {"skin": 1, "hair": 0, "outfit": 0, "hair_style": 0}, "background": "server_vet", "style": "observational"}
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
	sc.offset_right = -400
	sc.offset_top = 30
	sc.offset_bottom = -30
	add_child(sc)
	var row := UiKit.hbox(30)
	sc.add_child(row)
	_box = UiKit.vbox(10)
	_box.custom_minimum_size = Vector2(1100, 0)
	row.add_child(_box)
	_preview = Preview.new()
	_preview.anchor_left = 1.0
	_preview.anchor_right = 1.0
	_preview.offset_left = -370
	_preview.offset_right = -40
	_preview.offset_top = 40
	_preview.offset_bottom = 520
	add_child(_preview)
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
	var hs := UiKit.hbox(6)
	hs.add_child(UiKit.label("Hair style", 19, UiKit.C_TEXT, false))
	for i in range(CharacterArt.HAIR_STYLES.size()):
		var idx := i
		hs.add_child(UiKit.button(("● " if int(setup["appearance"].get("hair_style", 0)) == i else "○ ") + str(CharacterArt.HAIR_STYLES[i]), func(): _pick_appearance("hair_style", idx)))
	_box.add_child(hs)
	_box.add_child(UiKit.label("Background (a head start, never a cage)", 21, UiKit.C_ACCENT))
	for bid in db.backgrounds:
		var bg: Dictionary = db.backgrounds[bid]
		var bid_c: String = bid
		_box.add_child(UiKit.button(("● " if setup["background"] == bid else "○ ") + "%s — %s" % [bg["name"], bg["desc"]], func(): _pick("background", bid_c)))
	_box.add_child(UiKit.label("Starting comedy style (you can blend in a second style later)", 21, UiKit.C_ACCENT))
	var sr := GridContainer.new()
	sr.columns = 1
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
	_preview.hair_style = int(setup["appearance"].get("hair_style", 0))
	_preview.queue_redraw()
	UiKit.focus_first(_box)


func _pick(key: String, v: String) -> void:
	setup[key] = v
	if key == "gender":
		setup["appearance"]["hair_style"] = 2 if v == "female" else 0
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
