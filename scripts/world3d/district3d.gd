class_name District3D
extends Node3D
## 3D view of the district. The game logic still runs in 2D map pixels
## (DistrictMap / PlayerActor / StreetNpc, invisible); this node mirrors it in
## 3D at S meters per pixel. Buildings and ground use Poly Haven CC0 surface
## textures, street furniture uses Poly Haven CC0 models, people are
## Character3D. The Comedy Mothership is an original saucer-marquee design.

const S := 0.04

var db: ContentDB
var state: GameState
var map: DistrictMap
var player2d: PlayerActor
var npcs2d: Dictionary = {}

var cam: Camera3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D
var player3d: Character3D
var npc3d: Dictionary = {}
var peds3d: Array = []
var line3d: Array = []
var lamp_lights: Array = []
var windows: Array = []        # [MeshInstance3D, lit_at_night: bool]
var doors: Array = []          # [MeshInstance3D, location_id]
var markers: Dictionary = {}   # observation id -> Node3D
var bag3d: Node3D
var bulbs: Array = []
var marquee_label: Label3D
var south_full: Array = []    # [Node3D full, Node3D cutaway, Rect2 footprint]
var _last_block: int = -1
var _last_player := Vector3.ZERO
var _cam_override: Vector3 = Vector3.INF
var _cam_far: bool = false
var reduced: bool = false


static func to3(p: Vector2, y: float = 0.0) -> Vector3:
	return Vector3(p.x * S, y, p.y * S)


func setup(p_db: ContentDB, p_state: GameState, p_map: DistrictMap, p_player: PlayerActor, p_npcs: Dictionary) -> void:
	db = p_db
	state = p_state
	map = p_map
	player2d = p_player
	npcs2d = p_npcs
	reduced = GameSettings.reduced_motion()
	_build_environment()
	_build_ground()
	for id in db.location_order:
		var loc: Dictionary = db.locations[id]
		if str(loc.get("kind", "")) == "hotspot":
			continue
		if map.rect_of(loc).position.y < 600.0:
			if bool(loc.get("landmark", false)):
				_build_mothership(loc)
			else:
				_build_north(loc)
		else:
			_build_south(loc)
	_build_fillers()
	_build_hotspots()
	_build_props()
	_build_people()
	cam = Camera3D.new()
	cam.fov = 50.0
	cam.far = 400.0
	add_child(cam)
	cam.make_current()
	_snap_camera()
	refresh_time()


# --- Environment & time of day ------------------------------------------------

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_density = 0.004
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)


func refresh_time() -> void:
	var b := state.block
	_last_block = b
	var night := b >= 2
	match b:
		0:
			sky_mat.sky_top_color = Color("#6f9fd8")
			sky_mat.sky_horizon_color = Color("#f2d4ac")
			sun.light_color = Color("#ffe2b8")
			sun.light_energy = 1.0
			sun.rotation_degrees = Vector3(-25, -60, 0)
		1:
			sky_mat.sky_top_color = Color("#3f86d8")
			sky_mat.sky_horizon_color = Color("#cfe3f2")
			sun.light_color = Color("#fff6e8")
			sun.light_energy = 1.25
			sun.rotation_degrees = Vector3(-55, 20, 0)
		2:
			sky_mat.sky_top_color = Color("#1c1440")
			sky_mat.sky_horizon_color = Color("#d8705a")
			sun.light_color = Color("#ffb080")
			sun.light_energy = 0.45
			sun.rotation_degrees = Vector3(-10, 70, 0)
		_:
			sky_mat.sky_top_color = Color("#04050e")
			sky_mat.sky_horizon_color = Color("#181232")
			sun.light_color = Color("#8090d0")
			sun.light_energy = 0.18
			sun.rotation_degrees = Vector3(-60, -30, 0)
	sky_mat.ground_bottom_color = Color("#101014")
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	env.ambient_light_energy = 0.9 if not night else 0.45
	env.fog_light_color = sky_mat.sky_horizon_color
	for l in lamp_lights:
		(l as OmniLight3D).visible = night
	for w in windows:
		var mi: MeshInstance3D = w[0]
		mi.material_override = Mat3D.glow(Color("#ffd98a"), 1.4) if night and bool(w[1]) else Mat3D.color(Color("#2c4058"), 0.15, 0.4)
	for d in doors:
		var dm: MeshInstance3D = d[0]
		var open := GameSim.location_open(db, str(d[1]), b)
		dm.material_override = Mat3D.glow(Color("#ffcf80"), 1.2) if open and night else Mat3D.color(Color("#3a2414") if open else Color("#1a1210"), 0.6)
	var wd := CalendarRules.weekday(state.day)
	if marquee_label != null:
		marquee_label.text = "TONIGHT: KILL TONY" if wd == 0 else ("THURSDAY: THE SECRET SHOW" if wd == 3 else "HEADLINE SHOWS NIGHTLY")
	var line_on := wd == 0 and b in [1, 2]
	for c in line3d:
		(c as Node3D).visible = line_on


# --- Ground -------------------------------------------------------------------

func _build_ground() -> void:
	var W := float(db.world.get("width", 2600)) * S
	var H := float(db.world.get("height", 1200)) * S
	var st := 520.0 * S
	var rt := float(db.world.get("road_top", 600)) * S
	var rb := float(db.world.get("road_bottom", 700)) * S
	var sb := 780.0 * S
	Mat3D.box(self, Vector3(W * 0.5, -0.06, H * 0.5), Vector3(W + 60, 0.1, H + 60), Mat3D.surface("asphalt_01", Color("#6a6c74"), 0.25))
	Mat3D.box(self, Vector3(W * 0.5, 0.0, (rt + rb) * 0.5), Vector3(W + 60, 0.02, rb - rt), Mat3D.surface("asphalt_01", Color("#8a8c94"), 0.25))
	Mat3D.box(self, Vector3(W * 0.5, 0.075, (st + rt) * 0.5), Vector3(W + 60, 0.15, rt - st), Mat3D.surface("concrete_tiles_02", Color("#d0d2d8"), 0.5))
	Mat3D.box(self, Vector3(W * 0.5, 0.075, (rb + sb) * 0.5), Vector3(W + 60, 0.15, sb - rb), Mat3D.surface("concrete_tiles_02", Color("#c4c6cc"), 0.5))
	var lane := Mat3D.color(Color("#e0c860"), 0.6)
	var x := 0.0
	while x < W:
		Mat3D.box(self, Vector3(x + 1.2, 0.015, (rt + rb) * 0.5), Vector3(2.4, 0.01, 0.15), lane)
		x += 4.8
	var white := Mat3D.color(Color("#e8e8e8"), 0.6)
	for cx in [1300.0, 1930.0]:
		for i in range(7):
			Mat3D.box(self, Vector3((cx - 54 + i * 18) * S, 0.016, (rt + rb) * 0.5), Vector3(0.4, 0.01, rb - rt - 0.4), white)
	# Alley.
	Mat3D.box(self, Vector3(1940 * S, 0.01, 290 * S), Vector3(120 * S, 0.02, 460 * S), Mat3D.surface("asphalt_01", Color("#6a6c74"), 0.25))


# --- Buildings ----------------------------------------------------------------

func _rect3(loc: Dictionary) -> Rect2:
	var r := map.rect_of(loc)
	return Rect2(r.position * S, r.size * S)


func _sign(pos: Vector3, text: String, col: Color, width: float, rot_y: float = 0.0, parent: Node3D = null) -> void:
	if parent == null:
		parent = self
	var board := Mat3D.box(parent, pos + Vector3(0, 0, -0.06).rotated(Vector3.UP, rot_y), Vector3(width, 0.9, 0.12), Mat3D.color(Color("#141218"), 0.5))
	board.rotation.y = rot_y
	var fs := 64
	while fs > 24 and ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 0.01 > width - 0.3:
		fs -= 2
	var l := Mat3D.label(parent, pos + Vector3(0, 0, 0.02).rotated(Vector3.UP, rot_y), text, fs, col.lightened(0.2), false, 6)
	l.rotation.y = rot_y


func _awning(center: Vector3, width: float, col: Color) -> void:
	var a := Mat3D.box(self, center, Vector3(width, 0.08, 1.4), Mat3D.color(col, 0.8))
	a.rotation.x = deg_to_rad(18)
	var stripes := int(width / 0.7)
	for i in range(stripes):
		if i % 2 == 0:
			var s := Mat3D.box(self, center + Vector3(-width * 0.5 + (i + 0.5) * width / stripes, 0.045, 0), Vector3(width / stripes, 0.01, 1.4), Mat3D.color(col.lightened(0.45), 0.8))
			s.rotation.x = deg_to_rad(18)


func _window(pos: Vector3, size: Vector2, lit: bool) -> void:
	Mat3D.box(self, pos + Vector3(0, 0, -0.03), Vector3(size.x + 0.16, size.y + 0.16, 0.06), Mat3D.color(Color("#1c1a1c"), 0.6))
	var g := Mat3D.box(self, pos, Vector3(size.x, size.y, 0.04), Mat3D.color(Color("#2c4058"), 0.15, 0.4))
	windows.append([g, lit])
	Mat3D.box(self, pos + Vector3(0, -size.y * 0.5 - 0.06, 0.06), Vector3(size.x + 0.3, 0.08, 0.16), Mat3D.color(Color("#bdbab4"), 0.8))


func _build_north(loc: Dictionary) -> void:
	var id: String = str(loc["id"])
	var r := _rect3(loc)
	var heights := {"hostel": 10.0, "diner": 7.5, "coffee": 7.0, "lantern": 9.0, "apartments": 14.0}
	var h: float = float(heights.get(id, 8.0))
	var base := Color(str(loc.get("color", "#555566")))
	var sign_c := Color(str(loc.get("sign_color", "#ffffff")))
	var mat_id: String = {"hostel": "red_brick_03", "lantern": "red_brick_03"}.get(id, "plastered_wall")
	var front := r.end.y
	var cx := r.get_center().x
	Mat3D.box(self, Vector3(cx, h * 0.5, r.get_center().y), Vector3(r.size.x, h, r.size.y), Mat3D.surface(mat_id, base.lightened(0.55), 0.5 if mat_id == "red_brick_03" else 0.35))
	# Cornice and roof.
	Mat3D.box(self, Vector3(cx, h + 0.15, front - 0.05), Vector3(r.size.x + 0.4, 0.3, 0.5), Mat3D.color(base.darkened(0.35), 0.7))
	Mat3D.box(self, Vector3(cx, h + 0.02, r.get_center().y), Vector3(r.size.x, 0.05, r.size.y), Mat3D.surface("gravel_concrete", Color("#9a9ca4"), 0.4))
	var ac := ModelLib.instance("exterior_aircon_unit", ["exterior_aircon_unit"])
	if ac != null:
		ac.position = Vector3(r.position.x + 2.0, h + 0.05, r.get_center().y)
		add_child(ac)
	# Upper windows.
	var cols := maxi(2, int(r.size.x / 2.6))
	var rows := maxi(1, int((h - 4.2) / 2.3))
	for c in range(cols):
		for row in range(rows):
			var wx := r.position.x + (c + 0.5) * r.size.x / cols
			var wy := 4.6 + row * 2.3
			_window(Vector3(wx, wy, front + 0.03), Vector2(1.1, 1.4), (c * 7 + row * 3 + id.length()) % 4 != 0)
	# Storefront.
	var d3 := to3(map.door_of(loc))
	_sign(Vector3(cx, 3.3, front + 0.15), str(loc["name"]).to_upper(), sign_c, minf(r.size.x - 0.6, 9.0))
	_awning(Vector3(cx, 2.65, front + 0.62), r.size.x - 0.8, base.lerp(sign_c, 0.45))
	for sx in [r.position.x + 1.6, d3.x + 2.2]:
		if absf(sx - d3.x) > 1.2 and sx < r.end.x - 0.8:
			_window(Vector3(sx, 1.35, front + 0.03), Vector2(2.0, 1.5), true)
	var door := Mat3D.box(self, Vector3(d3.x, 1.1, front + 0.03), Vector3(1.2, 2.2, 0.05), Mat3D.color(Color("#3a2414"), 0.6))
	doors.append([door, id])
	Mat3D.box(self, Vector3(d3.x, 1.1, front), Vector3(1.45, 2.4, 0.04), Mat3D.color(base.darkened(0.5), 0.6))


## South-side buildings face north, away from the follow camera, so the camera
## mostly sees their roofs. When one would block the view of the player it
## swaps to a low cutaway (walls at knee height, name painted on the floor).
func _build_south(loc: Dictionary) -> void:
	var id: String = str(loc["id"])
	var r := _rect3(loc)
	var h := 4.6
	var base := Color(str(loc.get("color", "#555566")))
	var sign_c := Color(str(loc.get("sign_color", "#ffffff")))
	var front := r.position.y
	var cx := r.get_center().x
	var mat_id := "plastered_wall" if id == "mart" else "factory_brick"
	var wall := Mat3D.surface(mat_id, base.lightened(0.6), 0.4)
	var full := Node3D.new()
	add_child(full)
	Mat3D.box(full, Vector3(cx, h * 0.5, r.get_center().y), Vector3(r.size.x, h, r.size.y), wall)
	Mat3D.box(full, Vector3(cx, h + 0.02, r.get_center().y), Vector3(r.size.x, 0.05, r.size.y), Mat3D.surface("gravel_concrete", Color("#9a9ca4"), 0.4))
	Mat3D.box(full, Vector3(cx, h + 0.2, front + 0.05), Vector3(r.size.x + 0.3, 0.4, 0.3), Mat3D.color(base.darkened(0.4), 0.7))
	var ac := ModelLib.instance("exterior_aircon_unit", ["exterior_aircon_unit"])
	if ac != null:
		ac.position = Vector3(r.end.x - 2.0, h + 0.05, r.get_center().y)
		full.add_child(ac)
	Mat3D.label(full, Vector3(cx, h + 0.35, r.get_center().y), str(loc["name"]).to_upper(), 120, sign_c.lightened(0.2), false, 10).rotation.x = -PI * 0.5
	var d3 := to3(map.door_of(loc))
	# Storefront (faces -Z): sign, awning, windows, door.
	_sign(Vector3(cx, 3.4, front - 0.15), str(loc["name"]).to_upper(), sign_c, minf(r.size.x - 0.6, 9.0), PI, full)
	var aw := Mat3D.box(full, Vector3(cx, 2.65, front - 0.62), Vector3(r.size.x - 0.8, 0.08, 1.4), Mat3D.color(base.lerp(sign_c, 0.4), 0.8))
	aw.rotation.x = deg_to_rad(-18)
	for sx in [r.position.x + 1.6, r.end.x - 1.6]:
		if absf(sx - d3.x) > 1.4:
			var g := Mat3D.box(full, Vector3(sx, 1.35, front - 0.03), Vector3(2.0, 1.5, 0.04), Mat3D.color(Color("#2c4058"), 0.15, 0.4))
			windows.append([g, true])
	if id == "mart":
		Mat3D.label(full, Vector3(r.end.x - 1.4, 3.4, front - 0.2), "OPEN 24", 48, Color("#40ff80")).rotation.y = PI
	if id == "cellar":
		Mat3D.label(full, Vector3(r.end.x - 2.0, 2.2, front - 0.2), "LATE SHOW", 44, Color("#ff4fa3")).rotation.y = PI
	# Cutaway version.
	var cut := Node3D.new()
	cut.visible = false
	add_child(cut)
	var floor_c := Color("#3a2a22") if id != "mart" else Color("#c8c8c0")
	Mat3D.box(cut, Vector3(cx, 0.05, r.get_center().y), Vector3(r.size.x, 0.1, r.size.y), Mat3D.surface("wood_floor" if id != "mart" else "concrete_tiles_02", floor_c.lightened(0.4), 0.6))
	for side in [[Vector3(cx, 0.45, front + 0.12), Vector3(r.size.x, 0.9, 0.24)], [Vector3(cx, 0.45, r.end.y - 0.12), Vector3(r.size.x, 0.9, 0.24)], [Vector3(r.position.x + 0.12, 0.45, r.get_center().y), Vector3(0.24, 0.9, r.size.y)], [Vector3(r.end.x - 0.12, 0.45, r.get_center().y), Vector3(0.24, 0.9, r.size.y)]]:
		Mat3D.box(cut, side[0], side[1], wall)
	Mat3D.label(cut, Vector3(cx, 0.14, front + 1.4), str(loc["name"]).to_upper(), 110, sign_c.lightened(0.25), false, 12).rotation.x = -PI * 0.5
	Mat3D.box(cut, Vector3(d3.x, 0.12, front + 0.5), Vector3(1.4, 0.04, 0.8), Mat3D.glow(sign_c, 0.8))
	south_full.append([full, cut, r])
	var door := Mat3D.box(full, Vector3(d3.x, 1.1, front - 0.03), Vector3(1.2, 2.2, 0.05), Mat3D.color(Color("#3a2414"), 0.6))
	doors.append([door, id])


## Original saucer-marquee design (not the real building).
func _build_mothership(loc: Dictionary) -> void:
	var r := _rect3(loc)
	var h := 16.0
	var front := r.end.y
	var cx := r.get_center().x
	var sign_c := Color(str(loc.get("sign_color", "#b88cff")))
	# A well-kept flagship club: smooth satin panels, a polished granite base,
	# brushed-metal fins with LED strips, and a glass lobby. No grime textures.
	Mat3D.box(self, Vector3(cx, h * 0.5, r.get_center().y), Vector3(r.size.x, h, r.size.y), Mat3D.color(Color("#3c3f86"), 0.35, 0.25))
	Mat3D.box(self, Vector3(cx, 1.3, front + 0.06), Vector3(r.size.x + 0.1, 2.6, 0.14), Mat3D.color(Color("#141420"), 0.12, 0.3))
	Mat3D.box(self, Vector3(cx, 2.62, front + 0.14), Vector3(r.size.x + 0.1, 0.06, 0.04), Mat3D.glow(sign_c, 1.6))
	Mat3D.box(self, Vector3(cx, h + 0.15, front - 0.1), Vector3(r.size.x + 0.4, 0.3, 0.6), Mat3D.color(Color("#c8cad8"), 0.25, 0.8))
	var n_fins := int(r.size.x / 2.6)
	for i in range(n_fins + 1):
		var fx := r.position.x + i * r.size.x / n_fins
		Mat3D.box(self, Vector3(fx, h * 0.5 + 1.3, front + 0.12), Vector3(0.3, h - 2.6, 0.24), Mat3D.color(Color("#b8bccc"), 0.3, 0.85))
		Mat3D.box(self, Vector3(fx, h * 0.5 + 1.3, front + 0.25), Vector3(0.05, h - 2.6, 0.02), Mat3D.glow(sign_c.lerp(Color.WHITE, 0.3), 1.2))
	# Glass lobby band.
	Mat3D.box(self, Vector3(cx, 1.4, front + 0.15), Vector3(12.0, 2.4, 0.05), Mat3D.color(Color(0.55, 0.65, 0.95, 0.55), 0.05, 0.4))
	# Saucer.
	var c := Vector3(cx, h * 0.72, front + 2.4)
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 9.0
	cyl.bottom_radius = 7.0
	cyl.height = 0.9
	cyl.radial_segments = 48
	disc.mesh = cyl
	disc.material_override = Mat3D.color(Color("#2a2c52"), 0.4, 0.6)
	disc.position = c
	add_child(disc)
	var dome := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 4.2
	sph.height = 4.2
	sph.is_hemisphere = true
	dome.mesh = sph
	dome.material_override = Mat3D.color(Color("#6a70d8", 0.85), 0.1, 0.3)
	dome.position = c + Vector3(0, 0.45, 0)
	add_child(dome)
	var bulb_mesh := SphereMesh.new()
	bulb_mesh.radius = 0.16
	bulb_mesh.height = 0.32
	for i in range(40):
		var a := TAU * i / 40.0
		var b := MeshInstance3D.new()
		b.mesh = bulb_mesh
		b.position = c + Vector3(cos(a) * 9.0, 0.45, sin(a) * 9.0)
		add_child(b)
		bulbs.append(b)
	Mat3D.label(self, Vector3(cx, 9.4, front + 0.2), "COMEDY MOTHERSHIP", 120, sign_c.lightened(0.3), false, 12)
	# Marquee.
	var mq := Vector3(cx, 6.2, front + 0.6)
	Mat3D.box(self, mq, Vector3(r.size.x * 0.7, 1.8, 0.8), Mat3D.color(Color("#0a0a14"), 0.4))
	Mat3D.box(self, mq + Vector3(0, 0.95, 0), Vector3(r.size.x * 0.7 + 0.2, 0.1, 0.9), Mat3D.glow(Color("#ffe27a"), 1.5))
	Mat3D.box(self, mq + Vector3(0, -0.95, 0), Vector3(r.size.x * 0.7 + 0.2, 0.1, 0.9), Mat3D.glow(Color("#ffe27a"), 1.5))
	marquee_label = Mat3D.label(self, mq + Vector3(0, 0, 0.42), "", 84, Color("#ffe27a"), false, 6)
	# Canopy and doors.
	var d3 := to3(map.door_of(loc))
	Mat3D.box(self, Vector3(d3.x, 3.3, front + 1.4), Vector3(10.0, 0.25, 2.8), Mat3D.color(Color("#2c2c54"), 0.5))
	for i in range(14):
		var bp := Mat3D.box(self, Vector3(d3.x - 4.6 + i * 0.71, 3.15, front + 2.75), Vector3(0.14, 0.14, 0.14), Mat3D.glow(Color("#fff2b0"), 2.0))
		bulbs.append(bp)
	for sx in [-1.0, 1.0]:
		var door := Mat3D.box(self, Vector3(d3.x + sx * 0.8, 1.2, front + 0.04), Vector3(1.4, 2.4, 0.05), Mat3D.color(Color("#3a3050"), 0.5))
		doors.append([door, str(loc["id"])])
	var search := SpotLight3D.new()
	search.position = Vector3(cx, h + 1.0, r.get_center().y)
	search.rotation_degrees = Vector3(80, 0, 0)
	search.light_color = Color("#c8b0ff")
	search.spot_range = 60.0
	search.light_energy = 0.0
	add_child(search)


## Plain background blocks that close off both ends of the street.
func _build_fillers() -> void:
	var W := float(db.world.get("width", 2600)) * S
	var front := 520.0 * S
	var south := 780.0 * S
	var blocks := [
		[Vector2(-22.0, 2.6), 13.0, "factory_brick", Color("#c8a898"), true],
		[Vector2(95.0, W + 22.0), 11.0, "plastered_wall", Color("#b8c0d0"), true],
		[Vector2(-22.0, 3.6), 2.6, "factory_brick", Color("#a89888"), false],
		[Vector2(W - 3.0, W + 22.0), 2.6, "plastered_wall", Color("#a0a8b8"), false],
	]
	for bl in blocks:
		var xr: Vector2 = bl[0]
		var h: float = bl[1]
		var north: bool = bl[4]
		var depth := 12.0
		var cz := front - depth * 0.5 if north else south + depth * 0.5
		Mat3D.box(self, Vector3((xr.x + xr.y) * 0.5, h * 0.5, cz), Vector3(xr.y - xr.x, h, depth), Mat3D.surface(bl[2], bl[3], 0.4))
		if north:
			var x := xr.x + 1.5
			while x < xr.y - 1.0:
				for row in range(int((h - 2.0) / 2.6)):
					_window(Vector3(x, 1.8 + row * 2.6, front + 0.03), Vector2(1.1, 1.4), int(x * 3.0 + row) % 3 != 0)
				x += 2.8


func _build_hotspots() -> void:
	# Bus shelter.
	var bs := _rect3(db.locations["transit_stop"])
	var bc := Vector3(bs.get_center().x, 0.15, bs.get_center().y)
	for sx in [-1.0, 1.0]:
		Mat3D.box(self, bc + Vector3(sx * bs.size.x * 0.45, 1.25, 0), Vector3(0.1, 2.5, 0.1), Mat3D.color(Color("#8a9aa8"), 0.4, 0.7))
	Mat3D.box(self, bc + Vector3(0, 2.55, 0), Vector3(bs.size.x, 0.1, bs.size.y + 0.6), Mat3D.color(Color(0.6, 0.85, 1.0, 0.22), 0.1))
	Mat3D.box(self, bc + Vector3(0, 1.2, bs.size.y * 0.5), Vector3(bs.size.x, 2.0, 0.05), Mat3D.color(Color(0.6, 0.85, 1.0, 0.15), 0.1))
	Mat3D.box(self, bc + Vector3(0, 0.45, 0.4), Vector3(bs.size.x * 0.7, 0.08, 0.4), Mat3D.surface("dark_wood", Color("#c09070"), 1.0))
	Mat3D.box(self, bc + Vector3(bs.size.x * 0.5 + 0.5, 1.6, 0), Vector3(0.08, 3.2, 0.08), Mat3D.color(Color("#9aa0a8"), 0.4, 0.7))
	Mat3D.label(self, bc + Vector3(bs.size.x * 0.5 + 0.5, 3.0, 0.1), "BUS", 48, Color("#7fd1ff"), true)
	# Notice board.
	var jb := _rect3(db.locations["job_board"])
	var jc := Vector3(jb.get_center().x, 0.15, jb.get_center().y)
	Mat3D.box(self, jc + Vector3(0, 1.4, 0), Vector3(jb.size.x + 0.4, 1.4, 0.12), Mat3D.surface("dark_wood", Color("#b08850"), 1.0))
	for i in range(9):
		var pc := Color.from_hsv(fmod(i * 0.07, 0.15), 0.12, 0.96)
		Mat3D.box(self, jc + Vector3(-1.2 + (i % 3) * 1.0, 1.0 + int(i / 3) * 0.4, -0.07), Vector3(0.7, 0.3, 0.01), Mat3D.color(pc, 0.9))
	for sx in [-1.0, 1.0]:
		Mat3D.box(self, jc + Vector3(sx * (jb.size.x * 0.5), 0.5, 0), Vector3(0.1, 1.0, 0.1), Mat3D.surface("dark_wood", Color("#8a6a40"), 1.0))
	var jl := Mat3D.label(self, jc + Vector3(0, 2.4, -0.1), "JOBS · NOTICES", 40, Color("#ffd28a"))
	jl.rotation.y = PI


func _build_props() -> void:
	# Street lamps (Poly Haven) with lights at night.
	for p in map.lamp_positions():
		var lp := to3(p, 0.15)
		var toward_road := 1.0 if p.y < 650 else -1.0
		var pole := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.06
		cyl.bottom_radius = 0.09
		cyl.height = 3.6
		pole.mesh = cyl
		pole.material_override = Mat3D.color(Color("#24262a"), 0.5, 0.7)
		pole.position = lp + Vector3(0, 1.8, 0)
		add_child(pole)
		Mat3D.box(self, lp + Vector3(0, 0.15, 0), Vector3(0.3, 0.3, 0.3), Mat3D.color(Color("#24262a"), 0.5, 0.7))
		var lamp := ModelLib.instance("street_lamp_02")
		if lamp != null:
			# Poly Haven wall lantern (bracket points -Z) mounted on top of the pole.
			lamp.position = lp + Vector3(0, 2.6, 0.2 * toward_road)
			lamp.rotation.y = 0.0 if toward_road < 0 else PI
			add_child(lamp)
		var light := OmniLight3D.new()
		light.position = lp + Vector3(0, 3.6, 0.6 * toward_road)
		light.light_color = Color("#ffd8a0")
		light.light_energy = 1.6
		light.omni_range = 9.0
		add_child(light)
		lamp_lights.append(light)
	# Hydrants, trash cans, utility boxes, plants.
	var hyd_keep := ["fire_hydrant", "fire_hydrant_cap_01", "fire_hydrant_cap_02", "fire_hydrant_cap_03", "fire_hydrant_chain"]
	for x in [470.0, 1560.0, 2330.0]:
		var hy := ModelLib.instance("fire_hydrant", hyd_keep)
		if hy != null:
			hy.position = Vector3(x * S, 0.15, 590 * S)
			add_child(hy)
	var can_keep := ["metal_trash_can", "metal_trash_can_lid", "metal_trash_can_handle_left", "metal_trash_can_handle_right"]
	for p in [Vector2(760, 588), Vector2(1210, 712), Vector2(2050, 588), Vector2(300, 712)]:
		var tc := ModelLib.instance("metal_trash_can", can_keep)
		if tc != null:
			tc.position = to3(p, 0.15)
			add_child(tc)
	for p in [Vector2(1840, 712), Vector2(640, 588)]:
		var ub := ModelLib.instance("utility_box_01")
		if ub != null:
			ub.position = to3(p, 0.15)
			add_child(ub)
	for tp in map.trees:
		var p2: Vector2 = tp
		var pl := ModelLib.instance("potted_plant_02", [], 2.2)
		if pl != null:
			pl.position = to3(p2 + Vector2(0, 30 if p2.y < 650 else -30), 0.15)
			add_child(pl)
	# Benches (built: the Poly Haven bench is a modular kit).
	for bx in [180.0, 900.0, 2130.0]:
		var bc := Vector3(bx * S + 1.0, 0.15, 572 * S)
		Mat3D.box(self, bc + Vector3(0, 0.45, 0), Vector3(2.0, 0.08, 0.5), Mat3D.surface("dark_wood", Color("#c09070"), 1.0))
		Mat3D.box(self, bc + Vector3(0, 0.75, -0.22), Vector3(2.0, 0.4, 0.06), Mat3D.surface("dark_wood", Color("#c09070"), 1.0))
		for sx in [-0.85, 0.85]:
			Mat3D.box(self, bc + Vector3(sx, 0.22, 0), Vector3(0.06, 0.45, 0.45), Mat3D.color(Color("#2a2a2e"), 0.4, 0.7))
	# Parked cars.
	for c in map.cars:
		var L: float = float(c["len"]) * S
		var col: Color = c["col"]
		var cp := Vector3((float(c["x"]) + float(c["len"]) * 0.5) * S, 0.0, (float(c["y"]) + 4.0) * S)
		Mat3D.box(self, cp + Vector3(0, 0.6, 0), Vector3(L, 0.7, 1.7), Mat3D.color(col, 0.35, 0.5))
		Mat3D.box(self, cp + Vector3(-L * 0.05, 1.2, 0), Vector3(L * 0.55, 0.55, 1.5), Mat3D.color(Color("#9ac8e8", 0.85), 0.05, 0.3))
		for wx in [-L * 0.32, L * 0.32]:
			for wz in [-0.85, 0.85]:
				var wheel := MeshInstance3D.new()
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.34
				cyl.bottom_radius = 0.34
				cyl.height = 0.25
				wheel.mesh = cyl
				wheel.material_override = Mat3D.color(Color("#141414"), 0.8)
				wheel.position = cp + Vector3(wx, 0.34, wz)
				wheel.rotation.x = PI * 0.5
				add_child(wheel)
	# Taco truck (a converted ambulance), parked at the south curb.
	var tt := Node3D.new()
	tt.position = Vector3(1414 * S, 0.0, 686 * S)
	add_child(tt)
	Mat3D.box(tt, Vector3(0, 1.45, 0), Vector3(5.2, 2.3, 2.1), Mat3D.color(Color("#e8e4dc"), 0.45))
	Mat3D.box(tt, Vector3(2.9, 1.05, 0), Vector3(1.0, 1.5, 2.0), Mat3D.color(Color("#e8e4dc"), 0.45))
	Mat3D.box(tt, Vector3(3.15, 1.45, 0), Vector3(0.5, 0.6, 1.9), Mat3D.color(Color("#9ac8e8", 0.85), 0.05, 0.3))
	for side in [-1.0, 1.0]:
		Mat3D.box(tt, Vector3(0, 1.1, side * 1.06), Vector3(5.22, 0.25, 0.02), Mat3D.color(Color("#d03030"), 0.5))
		var tl := Mat3D.label(tt, Vector3(-0.6, 1.95, side * 1.075), "TACO EMS", 54, Color("#d03030"), false, 6)
		tl.rotation.y = 0.0 if side > 0 else PI
		Mat3D.box(tt, Vector3(0.9, 1.75, side * 1.06), Vector3(1.6, 0.8, 0.03), Mat3D.glow(Color("#ffd890"), 1.0))
		for wx in [-1.7, 2.6]:
			var wheel := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.4
			cyl.bottom_radius = 0.4
			cyl.height = 0.3
			wheel.mesh = cyl
			wheel.material_override = Mat3D.color(Color("#141414"), 0.8)
			wheel.position = Vector3(wx, 0.4, side * 0.9)
			wheel.rotation.x = PI * 0.5
			tt.add_child(wheel)
	Mat3D.box(tt, Vector3(-0.5, 2.7, 0), Vector3(0.7, 0.2, 0.5), Mat3D.glow(Color("#ff3030"), 1.5))
	# Observation markers, posters, the bag.
	for oid in db.observations:
		var o: Dictionary = db.observations[oid]
		if not o.has("pos"):
			continue
		var m := Node3D.new()
		var op: Array = o["pos"]
		m.position = Vector3(float(op[0]) * S, 1.8, float(op[1]) * S)
		Mat3D.box(m, Vector3.ZERO, Vector3(0.35, 0.45, 0.05), Mat3D.glow(Color("#c8ffd8"), 1.2))
		Mat3D.label(m, Vector3(0, 0.45, 0), "!", 72, Color("#8affb0"), true)
		add_child(m)
		markers[oid] = m
	for po in db.posters:
		var pp: Array = po["pos"]
		var pc := Vector3(float(pp[0]) * S, 0.15, float(pp[1]) * S)
		Mat3D.box(self, pc + Vector3(0, 0.6, 0), Vector3(0.08, 1.2, 0.08), Mat3D.color(Color("#3a3a40"), 0.5))
		Mat3D.box(self, pc + Vector3(0, 1.5, 0), Vector3(0.9, 1.2, 0.05), Mat3D.color(Color("#f0e6c8"), 0.9))
		Mat3D.box(self, pc + Vector3(0, 1.95, 0.03), Vector3(0.9, 0.3, 0.02), Mat3D.color(Color("#c04040"), 0.7))
	bag3d = Node3D.new()
	Mat3D.box(bag3d, Vector3(0, 0.3, 0), Vector3(0.7, 0.5, 0.35), Mat3D.color(Color("#6b4a2a"), 0.8))
	Mat3D.label(bag3d, Vector3(0, 1.0, 0), "your bag", 36, Color.WHITE, true)
	bag3d.position = Vector3(247 * S, 0.15, 753 * S)
	add_child(bag3d)


# --- People -------------------------------------------------------------------

func _build_people() -> void:
	player3d = Character3D.create(player2d.look)
	add_child(player3d)
	for id in npcs2d:
		var sn: StreetNpc = npcs2d[id]
		var c := Character3D.create(sn.look, sn.display_name, sn.body_color.lightened(0.3))
		add_child(c)
		npc3d[id] = c
	for i in range(mini(16, map.pedestrians.size())):
		var p: Dictionary = map.pedestrians[i]
		var c := Character3D.create(p["look"])
		c.walking = true
		add_child(c)
		peds3d.append(c)
	for i in range(16):
		var lc := Character3D.create(CharacterArt.npc_look(Color.from_hsv(fmod(i * 0.13, 1.0), 0.4, 0.7).to_html(false), i % 3 == 0, i * 5 + 1))
		lc.position = Vector3((1090 + i * 26) * S, 0.15, 548 * S)
		lc.rotation.y = PI * 0.5
		lc.set_expression("nervous" if i % 4 == 0 else "neutral")
		add_child(lc)
		line3d.append(lc)


## Swings the camera out to a wide establishing view of `world_target`.
func pan_to(world_target: Vector3, seconds: float) -> void:
	_cam_override = world_target
	_cam_far = true
	get_tree().create_timer(seconds).timeout.connect(func():
		_cam_override = Vector3.INF
		_cam_far = false)


func _cam_target() -> Array:
	var focus := player3d.position if _cam_override == Vector3.INF else _cam_override
	if _cam_far:
		return [focus + Vector3(0, 9.0, 24.0), focus + Vector3(0, 9.0, -4.0)]
	return [focus + Vector3(0, 7.5, 11.0), focus + Vector3(0, 1.6, -3.5)]


func _snap_camera() -> void:
	var tg := _cam_target()
	cam.position = tg[0]
	cam.look_at(tg[1], Vector3.UP)


func _process(delta: float) -> void:
	if state == null:
		return
	if state.block != _last_block:
		refresh_time()
	# Player (rebuilt if the look changes, e.g. after picking up the bag).
	if player3d.look != player2d.look:
		var rot := player3d.rotation
		player3d.queue_free()
		player3d = Character3D.create(player2d.look)
		player3d.rotation = rot
		add_child(player3d)
	var p3 := to3(player2d.position, 0.15)
	var mv := p3 - _last_player
	if mv.length() > 0.002:
		player3d.rotation.y = atan2(mv.x, mv.z)
	player3d.position = p3
	player3d.walking = player2d.moving
	_last_player = p3
	# NPCs.
	for id in npcs2d:
		var sn: StreetNpc = npcs2d[id]
		var c: Character3D = npc3d[id]
		c.visible = sn.visible
		var np := to3(sn.position, 0.15)
		var d := np - c.position
		c.walking = d.length() > 0.01
		if c.walking:
			c.rotation.y = atan2(d.x, d.z)
		else:
			c.rotation.y = 0.0
		c.position = np
	# Pedestrians.
	var shown := 6 + state.block * 3
	for i in range(peds3d.size()):
		var p: Dictionary = map.pedestrians[i]
		var c: Character3D = peds3d[i]
		c.visible = i < shown
		c.position = Vector3(float(p["x"]) * S, 0.15, float(p["y"]) * S)
		c.rotation.y = PI * 0.5 if float(p["v"]) > 0 else -PI * 0.5
	# Markers and the bag.
	for oid in markers:
		var m: Node3D = markers[oid]
		m.visible = WorldRules.observation_available(state, db.observations[oid])
		if not reduced:
			m.rotation.y += delta * 1.5
	bag3d.visible = not state.flags.has("has_bag")
	# Chasing marquee bulbs.
	var night := state.block >= 2
	var tick := int(Time.get_ticks_msec() / 100)
	for i in range(bulbs.size()):
		var on := (not night) or reduced or (i + tick) % 4 != 0
		(bulbs[i] as MeshInstance3D).material_override = Mat3D.glow(Color("#fff2b0"), 2.5) if on else Mat3D.color(Color("#6a6040"), 0.5)
	# Cut away south buildings that would block the view.
	for e in south_full:
		var r: Rect2 = e[2]
		var block := player3d.position.z < r.position.y and cam.position.x > r.position.x - 7.0 and cam.position.x < r.end.x + 7.0
		(e[0] as Node3D).visible = not block
		(e[1] as Node3D).visible = block
	# Camera follow.
	var tg := _cam_target()
	var k := 1.0 if reduced else clampf(delta * 4.0, 0.0, 1.0)
	cam.position = cam.position.lerp(tg[0], k)
	cam.look_at(tg[1], Vector3.UP)
