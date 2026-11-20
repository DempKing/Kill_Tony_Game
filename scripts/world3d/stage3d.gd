class_name Stage3D
extends Node3D
## Generic 3D club stage (open mic, showcase, late show, secret show, road
## clubs, theaters, arenas). Same knobs as the old 2D StageArt so the scene
## controllers barely changed: stage, audience_size, reaction, light_on,
## production, player_look, show_light. Call rebuild() after changing `stage`.
##
## Layout (meters): stage riser x -6..6, front lip at z 0.6, back wall at
## z -4; audience rows from z 2.2 toward the camera (+Z).

var stage: Dictionary = {}
var player_colors: Dictionary = {}
var player_look: Dictionary = {}
var audience_size: int = 30
var reaction: float = 0.0
var light_on: bool = false
var reduced: bool = false
var production: String = ""
var show_light: bool = true

var cam: Camera3D
var _root: Node3D
var _performer: Character3D
var _crowd: Crowd3D
var _light_lamp: MeshInstance3D
var _light_label: Label3D
var _light_glow: OmniLight3D
var _beams: Array = []
var _sign: Label3D
var _t: float = 0.0
var _built_key: String = ""
var _crowd_total: int = 0

const H := 0.6   # riser height


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 50.0
	add_child(cam)
	cam.make_current()
	rebuild()


## Kept so older callers that "redraw" still work.
func queue_redraw() -> void:
	rebuild()


func rebuild() -> void:
	var key := "%s|%s|%d|%s|%s" % [str(stage), production, audience_size, str(show_light), str(player_look.size())]
	if key == _built_key and _root != null:
		if _crowd != null:
			_crowd.set_count(_shown())
		return
	_built_key = key
	if _root != null:
		_root.queue_free()
	_root = Node3D.new()
	add_child(_root)
	_beams.clear()
	var back := Color(str(stage.get("backdrop", "#2a1a10")))
	var light := Color(str(stage.get("light", "#ffcf8a")))
	var floor_c := Color(str(stage.get("floor", "#1a1008")))
	var style: String = str(stage.get("style", "dive"))
	_environment(back, light, style)
	# Room shell: floor, side walls, ceiling.
	var wide := style in ["theater", "arena"]
	var hw := 16.0 if wide else 9.0
	# Early-career rooms (dive, cellar) are grimy; nicer rooms get clean carpet.
	var grimy := style in ["dive", "cellar"]
	var floor_mat: Material = Mat3D.surface("dirty_carpet", back.lightened(0.35), 0.5) if grimy else Mat3D.color(back.darkened(0.35), 0.9)
	Mat3D.box(_root, Vector3(0, -0.05, 6), Vector3(hw * 2, 0.1, 24), floor_mat)
	if style != "arena":
		for sx in [-1.0, 1.0]:
			var wall_mat: Material = Mat3D.surface(_wall_tex(style), back.lightened(0.3), 0.4) if _wall_tex(style) != "" else Mat3D.color(back.lightened(0.15), 0.6)
			Mat3D.box(_root, Vector3(sx * hw, 3.5, 6), Vector3(0.2, 7, 24), wall_mat)
		Mat3D.box(_root, Vector3(0, 7.0 if style != "cellar" else 4.6, 6), Vector3(hw * 2, 0.2, 24), Mat3D.color(back.darkened(0.7), 0.9))
	# Riser.
	Mat3D.box(_root, Vector3(0, H * 0.5, -1.7), Vector3(12, H, 4.6), Mat3D.surface("wood_floor", floor_c.lightened(0.6), 0.5, 0.6))
	Mat3D.box(_root, Vector3(0, H * 0.5, 0.62), Vector3(12.1, H, 0.06), Mat3D.color(floor_c.darkened(0.4), 0.8))
	for i in range(14):
		Mat3D.box(_root, Vector3(-5.6 + i * 0.86, H * 0.4, 0.66), Vector3(0.12, 0.06, 0.04), Mat3D.glow(light, 2.0))
	match style:
		"lantern":
			_lantern(back, light)
		"cellar":
			_cellar(back, light)
		"secret":
			_secret(back, light)
		"road_club":
			_road_club(back, light)
		"theater":
			_theater(back, light)
		"arena":
			_arena(back, light)
		_:
			_dive(back, light)
	# Sign.
	var sign_text := str(stage.get("sign", ""))
	var fs := 120
	while fs > 40 and ThemeDB.fallback_font.get_string_size(sign_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 0.01 > 7.0:
		fs -= 4
	_sign = Mat3D.label(_root, Vector3(0, 4.7 if style != "cellar" else 3.6, -3.85), sign_text, fs, light.lightened(0.25), false, 14)
	# Spotlight on the performer, plus a visible cone.
	var spot := SpotLight3D.new()
	_root.add_child(spot)
	spot.look_at_from_position(Vector3(0.6, 6.5, 3.5), Vector3(0.6, H + 1.0, -1.2))
	spot.light_color = light.lerp(Color.WHITE, 0.5)
	spot.light_energy = 6.0
	spot.spot_range = 14.0
	spot.spot_angle = 16.0
	spot.shadow_enabled = true
	_cone(Vector3(0.6, 6.5, 3.5), Vector3(0.6, H, -1.2), 1.4, light, 0.10)
	# Mic stand (the mic is in hand), cable, stool with water.
	var stand := _cyl(_root, Vector3(-0.1, H + 0.75, -1.0), 0.02, 0.02, 1.5, Mat3D.color(Color("#9a9aa4"), 0.3, 0.8))
	stand.rotation.z = 0.05
	_cyl(_root, Vector3(-0.1, H + 0.02, -1.0), 0.25, 0.25, 0.04, Mat3D.color(Color("#2a2a2e"), 0.4, 0.8))
	var stool := ModelLib.instance("metal_stool_01")
	if stool != null:
		stool.position = Vector3(2.0, H, -1.9)
		_root.add_child(stool)
		_cyl(_root, Vector3(2.0, H + 1.0, -1.9), 0.035, 0.035, 0.22, Mat3D.color(Color(0.7, 0.85, 1.0, 0.6), 0.1))
	# Time light (open mics).
	if show_light:
		Mat3D.box(_root, Vector3(-4.9, 3.0, -3.85), Vector3(0.7, 1.0, 0.2), Mat3D.color(Color("#1a1414"), 0.6))
		_light_lamp = MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.2
		sph.height = 0.4
		_light_lamp.mesh = sph
		_light_lamp.position = Vector3(-4.9, 3.15, -3.72)
		_root.add_child(_light_lamp)
		_light_label = Mat3D.label(_root, Vector3(-4.9, 2.7, -3.74), "light", 22, Color("#806060"), false, 4)
		_light_glow = OmniLight3D.new()
		_light_glow.position = Vector3(-4.9, 3.15, -3.2)
		_light_glow.light_color = Color(1, 0.15, 0.15)
		_light_glow.omni_range = 4.0
		_root.add_child(_light_glow)
	# Performer.
	var look := player_look if not player_look.is_empty() else CharacterArt.look_from(player_colors)
	_performer = Character3D.create(look)
	_performer.mic_hand = true
	_performer.position = Vector3(0.6, H, -1.2)
	_performer.rotation.y = -0.15
	_root.add_child(_performer)
	_build_crowd(style, light)
	_frame(style)


## Clubs show one figure per audience member. Theaters and arenas treat
## audience_size (capped at 60 by the callers) as a fill fraction of the house.
func _shown() -> int:
	if str(stage.get("style", "")) in ["theater", "arena"]:
		return int(_crowd_total * clampf(audience_size / 60.0, 0.15, 1.0))
	return audience_size


func _wall_tex(style: String) -> String:
	# "" = clean painted wall (no texture).
	return {"dive": "red_brick_03", "lantern": "plastered_wall", "cellar": "concrete_wall_003", "secret": "", "road_club": "factory_brick", "theater": "velour_velvet"}.get(style, "")


func _environment(back: Color, light: Color, style: String) -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = back.darkened(0.85)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = back.lightened(0.3)
	env.ambient_light_energy = 0.55 if style != "arena" else 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	we.environment = env
	_root.add_child(we)
	var house := OmniLight3D.new()
	house.position = Vector3(0, 5.5, 4)
	house.light_color = light
	house.light_energy = 1.2
	house.omni_range = 16.0
	_root.add_child(house)


func _frame(style: String) -> void:
	match style:
		"arena":
			cam.position = Vector3(0, 6.5, 20)
			cam.look_at(Vector3(0, 2.4, -2), Vector3.UP)
		"theater":
			cam.position = Vector3(0, 4.0, 14)
			cam.look_at(Vector3(0.2, 2.0, -1.5), Vector3.UP)
		_:
			cam.position = Vector3(0, 2.6, 9.0)
			cam.look_at(Vector3(0.3, 1.7, -1.5), Vector3.UP)


func _build_crowd(style: String, light: Color) -> void:
	var rows := 4
	var per_row := 9
	var spread := 7.0
	var gap := 1.15
	match style:
		"theater":
			rows = 7
			per_row = 16
			spread = 12.0
			gap = 1.0
		"arena":
			rows = 10
			per_row = 30
			spread = 15.0
			gap = 1.0
	var spots: Array = []
	for r in range(rows):
		var n := per_row + (r % 2)
		var rise := r * (0.25 if style in ["theater", "arena"] else 0.0)
		for i in range(n):
			var x := -spread + 2.0 * spread * (i + 0.5) / n
			spots.append(Vector3(x, rise, 2.3 + r * gap))
	# Fill from the front rows first, spread evenly within each row.
	_crowd = Crowd3D.new()
	_crowd.setup(spots, Color("#0e0c14"), light, true)
	_root.add_child(_crowd)
	_crowd_total = spots.size()
	_crowd.set_count(_shown())
	if style in ["theater", "arena"]:
		for r in range(rows):
			Mat3D.box(_root, Vector3(0, r * 0.25 - 0.1, 2.3 + r * gap + 0.4), Vector3(spread * 2 + 1, 0.2, gap), Mat3D.color(Color("#18141c"), 0.9))


# --- Room styles ---------------------------------------------------------

func _dive(back: Color, light: Color) -> void:
	Mat3D.box(_root, Vector3(0, 3.5, -4.0), Vector3(18, 7, 0.2), Mat3D.surface("red_brick_03", Color("#e0b0a0"), 0.6))
	# Bar along the right wall with Poly Haven bar chairs and bottles.
	Mat3D.box(_root, Vector3(7.6, 0.55, 3.5), Vector3(1.0, 1.1, 8.0), Mat3D.surface("dark_wood", Color("#c89870"), 1.0))
	Mat3D.box(_root, Vector3(7.6, 1.12, 3.5), Vector3(1.2, 0.06, 8.2), Mat3D.surface("dark_wood", Color("#a07050"), 1.0))
	for i in range(4):
		var ch := ModelLib.instance("bar_chair_round_01")
		if ch != null:
			ch.position = Vector3(6.6, 0, 0.8 + i * 1.8)
			_root.add_child(ch)
	var bottles := ModelLib.instance("wine_bottles_01")
	if bottles != null:
		bottles.position = Vector3(7.7, 1.15, 2.0)
		bottles.rotation.y = PI * 0.5
		_root.add_child(bottles)
	var neon := Mat3D.label(_root, Vector3(8.85, 3.2, 3.0), "COLD BEER", 64, Color("#40d0ff"), false, 4)
	neon.rotation.y = -PI * 0.5
	_point(Vector3(8.4, 3.2, 3.0), Color("#40d0ff"), 1.0, 4.0)
	# String bulbs across the back.
	for i in range(19):
		var x := -8.5 + i * 0.95
		var b := _cyl(_root, Vector3(x, 6.1 - 0.35 * absf(sin(i * 0.9)), -3.7), 0.07, 0.07, 0.12, Mat3D.glow(light, 3.0))
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for x in [-4.0, 4.0]:
		var lamp := ModelLib.instance("hanging_industrial_lamp")
		if lamp != null:
			lamp.position = Vector3(x, 5.6, 2.0)
			_root.add_child(lamp)
		_point(Vector3(x, 5.5, 2.0), light, 0.8, 6.0)


func _lantern(back: Color, light: Color) -> void:
	# Red velvet curtain with folds, sconces, candle-lit tables.
	for i in range(28):
		var f := Mat3D.box(_root, Vector3(-6.75 + i * 0.5, 3.3, -3.9 + (0.08 if i % 2 else 0.0)), Vector3(0.52, 6.6, 0.12), Mat3D.surface("velour_velvet", Color("#d03040") if i % 2 else Color("#a02030"), 0.6))
		f.rotation.y = 0.25 if i % 2 else -0.25
	Mat3D.box(_root, Vector3(0, 6.6, -3.8), Vector3(14, 0.6, 0.3), Mat3D.color(Color("#3a0a10"), 0.6))
	Mat3D.box(_root, Vector3(0, 3.5, -4.1), Vector3(18, 7, 0.2), Mat3D.surface("plastered_wall", back.lightened(0.4), 0.4))
	for sx in [-7.5, 7.5]:
		Mat3D.box(_root, Vector3(sx, 3.0, -3.9), Vector3(0.2, 0.5, 0.2), Mat3D.color(Color("#8a6a30"), 0.3, 0.8))
		_point(Vector3(sx, 3.3, -3.6), light, 1.2, 5.0)
	for i in range(5):
		var tbl := ModelLib.instance("round_wooden_table_01", [], 0.75)
		if tbl != null:
			tbl.position = Vector3(-6.0 + i * 3.0, 0, 3.0 + (i % 2) * 2.2)
			_root.add_child(tbl)
			_cyl(_root, tbl.position + Vector3(0, 0.8, 0), 0.04, 0.04, 0.08, Mat3D.glow(Color("#ffd070"), 3.0))


func _cellar(back: Color, light: Color) -> void:
	Mat3D.box(_root, Vector3(0, 2.3, -4.0), Vector3(18, 4.6, 0.2), Mat3D.surface("concrete_wall_003", Color("#8a8894"), 0.5))
	for y in [4.1, 3.8]:
		var pipe := _cyl(_root, Vector3(0, y, -3.6), 0.12, 0.12, 18.0, Mat3D.color(Color("#5a5a60"), 0.4, 0.7))
		pipe.rotation.z = PI * 0.5
	_cyl(_root, Vector3(-5.0, 2.3, -3.7), 0.1, 0.1, 4.6, Mat3D.color(Color("#5a5a60"), 0.4, 0.7))
	_point(Vector3(0, 3.6, -3.2), light, 1.5, 6.0)


## The Secret Show runs inside the Comedy Mothership, so the room is clean:
## dark acoustic wall panels, wood slats, warm string lights.
func _secret(back: Color, light: Color) -> void:
	Mat3D.box(_root, Vector3(0, 3.5, -4.0), Vector3(18, 7, 0.2), Mat3D.color(Color("#161624"), 0.8))
	for i in range(12):
		Mat3D.box(_root, Vector3(-7.7 + i * 1.4, 3.2, -3.85), Vector3(1.25, 4.6, 0.1), Mat3D.color(Color("#262840") if i % 2 else Color("#20223a"), 0.95))
	for i in range(36):
		Mat3D.box(_root, Vector3(-8.75 + i * 0.5, 6.2, -3.85), Vector3(0.22, 1.2, 0.12), Mat3D.surface("dark_wood", Color("#c8a080"), 1.0))
	for i in range(17):
		_cyl(_root, Vector3(-8 + i, 5.4 + (0.3 if i % 2 == 0 else 0.0), -3.6), 0.06, 0.06, 0.1, Mat3D.glow(light, 3.0))
	Mat3D.box(_root, Vector3(6.0, 2.5, -3.78), Vector3(2.4, 0.7, 0.06), Mat3D.color(Color("#0c0c14"), 0.4))
	Mat3D.label(_root, Vector3(6.0, 2.5, -3.74), "NO PHONES", 40, Color("#ff6060"), false, 4)


func _road_club(back: Color, light: Color) -> void:
	Mat3D.box(_root, Vector3(0, 3.5, -4.0), Vector3(18, 7, 0.2), Mat3D.surface("factory_brick", Color("#b08090"), 0.5))
	Mat3D.box(_root, Vector3(0, 4.7, -3.9), Vector3(7.6, 1.2, 0.1), Mat3D.color(Color("#160e14"), 0.5))
	for e in [[Vector3(0, 5.32, -3.84), Vector3(7.6, 0.05, 0.05)], [Vector3(0, 4.08, -3.84), Vector3(7.6, 0.05, 0.05)], [Vector3(-3.8, 4.7, -3.84), Vector3(0.05, 1.25, 0.05)], [Vector3(3.8, 4.7, -3.84), Vector3(0.05, 1.25, 0.05)]]:
		Mat3D.box(_root, e[0], e[1], Mat3D.glow(light, 2.5))
	Mat3D.box(_root, Vector3(-6.0, 2.6, -3.85), Vector3(1.6, 0.6, 0.1), Mat3D.color(Color("#101010"), 0.6))
	Mat3D.label(_root, Vector3(-6.0, 2.6, -3.78), "2-DRINK MIN", 30, Color("#ffb040"), false, 4)


func _theater(back: Color, light: Color) -> void:
	Mat3D.box(_root, Vector3(0, 3.5, -4.1), Vector3(32, 7, 0.2), Mat3D.color(Color("#1a0c10"), 0.9))
	for i in range(30):
		var f := Mat3D.box(_root, Vector3(-7.25 + i * 0.5, 3.2, -3.9), Vector3(0.52, 6.4, 0.12), Mat3D.surface("velour_velvet", Color("#c02838") if i % 2 else Color("#901828"), 0.6))
		f.rotation.y = 0.25 if i % 2 else -0.25
	var gold := Mat3D.color(Color("#c8a040"), 0.35, 0.8)
	Mat3D.box(_root, Vector3(0, 6.7, -3.6), Vector3(16.4, 0.8, 0.5), gold)
	for sx in [-8.0, 8.0]:
		Mat3D.box(_root, Vector3(sx, 3.4, -3.6), Vector3(0.6, 6.8, 0.5), gold)
	for sx in [-12.5, 12.5]:
		for by in [2.8, 4.8]:
			Mat3D.box(_root, Vector3(sx, by, 1.0), Vector3(3.0, 0.8, 2.0), Mat3D.color(Color("#3a2010"), 0.6))
			Mat3D.box(_root, Vector3(sx, by + 0.42, 1.0), Vector3(3.1, 0.08, 2.1), gold)
			_point(Vector3(sx, by + 0.6, 1.0), light, 0.6, 3.0)


func _arena(back: Color, light: Color) -> void:
	Mat3D.box(_root, Vector3(0, 8, -6), Vector3(40, 16, 0.2), Mat3D.color(Color("#06060c"), 0.9))
	var truss := Mat3D.color(Color("#5a5a66"), 0.4, 0.8)
	Mat3D.box(_root, Vector3(0, 8.0, -1.5), Vector3(20, 0.35, 0.35), truss)
	for sx in [-10.0, 10.0]:
		Mat3D.box(_root, Vector3(sx, 4.0, -1.5), Vector3(0.35, 8.0, 0.35), truss)
	var beams := {"minimal": 2, "standard": 6, "spectacle": 12}.get(production, 6) as int
	for i in range(beams):
		var x := -9.0 + i * (18.0 / maxf(1.0, beams - 1))
		var col := Color.from_hsv(fmod(0.62 + i * 0.07, 1.0), 0.6, 1.0)
		var cone := _cone(Vector3(x, 7.8, -1.5), Vector3(x * 0.4, 0.0, 4.0), 1.6, col, 0.08)
		_beams.append([cone, x])
	if production != "minimal":
		for sx in [-11.0, 11.0]:
			Mat3D.box(_root, Vector3(sx, 5.0, -2.5), Vector3(6.4, 3.8, 0.2), Mat3D.color(Color("#101828"), 0.4))
			Mat3D.box(_root, Vector3(sx, 5.0, -2.38), Vector3(6.0, 3.4, 0.04), Mat3D.glow(light.darkened(0.55), 1.0))
			var mini := Character3D.create(player_look if not player_look.is_empty() else CharacterArt.look_from(player_colors))
			mini.scale = Vector3.ONE * 1.6
			mini.position = Vector3(sx, 3.3, -2.3)
			mini.mic_hand = true
			_root.add_child(mini)


# --- Helpers -------------------------------------------------------------

func _cyl(parent: Node3D, pos: Vector3, top: float, bottom: float, h: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = h
	cm.radial_segments = 12
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _point(pos: Vector3, col: Color, energy: float, rng: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	_root.add_child(l)


## A soft additive light cone from `from` to `to`.
func _cone(from: Vector3, to: Vector3, radius: float, col: Color, alpha: float) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(col, alpha)
	var len := from.distance_to(to)
	var cm := CylinderMesh.new()
	cm.top_radius = 0.08
	cm.bottom_radius = radius
	cm.height = len
	cm.radial_segments = 20
	cm.cap_top = false
	cm.cap_bottom = false
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(mi)
	_aim(mi, from, to)
	return mi


func _aim(mi: Node3D, from: Vector3, to: Vector3) -> void:
	var dir := (to - from).normalized()
	var up := -dir   # cylinder +Y points at the narrow top (the source)
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT).normalized()
	var fwd := side.cross(up).normalized()
	mi.transform = Transform3D(Basis(side, up, fwd), (from + to) * 0.5)


func _process(delta: float) -> void:
	_t += delta
	reaction = move_toward(reaction, 0.0, delta * 0.35)
	if _crowd != null:
		_crowd.reaction = maxf(_crowd.reaction, reaction)
	if _performer != null:
		var expr := "neutral"
		if reaction > 0.35:
			expr = "laugh"
		elif reaction > 0.1:
			expr = "smile"
		elif reaction < -0.2:
			expr = "nervous"
		_performer.set_expression(expr)
	if _light_lamp != null:
		_light_lamp.material_override = Mat3D.glow(Color("#ff2a2a"), 3.0) if light_on else Mat3D.color(Color("#3a1010"), 0.5)
		_light_label.text = "LIGHT ON" if light_on else "light"
		_light_label.modulate = Color.WHITE if light_on else Color("#806060")
		_light_glow.visible = light_on
	if _sign != null and str(stage.get("style", "")) == "cellar" and not reduced:
		_sign.modulate.a = 0.75 + 0.25 * sin(_t * 3.0)
	if not reduced:
		for b in _beams:
			var cone: MeshInstance3D = b[0]
			var x: float = b[1]
			_aim(cone, Vector3(x, 7.8, -1.5), Vector3(x * 0.4 + sin(_t * 0.8 + x) * 3.0, 0.0, 4.0))
