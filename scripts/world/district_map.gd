class_name DistrictMap
extends Node2D
## Draws the compressed, fictional Austin entertainment district. All art is
## original and procedural: sky and skyline, facades with cornices, windows,
## awnings and neon, a saucer-marquee for the Mothership (an original design,
## not the real building), sidewalks, road, props, street life.
## Since the 3D conversion this node is hidden: it supplies layout and moving-crowd data that District3D renders.
## Layout data comes from data/venues/locations.json.

var db: ContentDB
var state: GameState
var t: float = 0.0
var pedestrians: Array = []
var cars: Array = []
var trees: Array = []
var _rng := RandomNumberGenerator.new()

static func sky_colors(block: int) -> Array:
	match block:
		0: return [Color("#8fb8e0"), Color("#f2d4ac")]
		1: return [Color("#6fa6dc"), Color("#cfe3f2")]
		2: return [Color("#1c1440"), Color("#d8705a")]
	return [Color("#04050e"), Color("#181232")]


func setup(p_db: ContentDB, p_state: GameState) -> void:
	db = p_db
	state = p_state
	_rng.seed = 99
	for i in range(22):
		var female := _rng.randf() < 0.5
		pedestrians.append({"x": _rng.randf_range(0, 2600), "y": [584.0, 728.0][i % 2] + _rng.randf_range(-6, 6),
			"v": _rng.randf_range(35, 65) * (1.0 if i % 3 else -1.0), "phase": _rng.randf() * TAU,
			"look": CharacterArt.npc_look(Color.from_hsv(_rng.randf(), 0.45, 0.75).to_html(false), female, i * 7 + 3)})
	var car_cols: Array = ["#c23b3b", "#3b6fc2", "#d8d8d8", "#2a2a2a", "#e0b040", "#3c8a5a", "#7a4ac0"]
	var x := 60.0
	while x < 2560.0:
		if absf(x - 1300.0) > 140.0 and absf(x - 1930.0) > 120.0:
			cars.append({"x": x, "y": 612.0 if cars.size() % 2 == 0 else 686.0, "col": Color(car_cols[cars.size() % car_cols.size()]), "len": _rng.randf_range(78, 96)})
		x += _rng.randf_range(170, 320)
	for tx in [40, 400, 720, 1010, 1590, 1990, 2370, 2550]:
		trees.append(Vector2(tx, 548))
	for tx in [330, 640, 820, 1240, 1450, 1850, 2100, 2300]:
		trees.append(Vector2(tx, 760))
	queue_redraw()


func _process(delta: float) -> void:
	t += delta
	var busy := 0.35 + 0.25 * state.block
	if not GameSettings.reduced_motion():
		for p in pedestrians:
			p["x"] = fposmod(float(p["x"]) + float(p["v"]) * delta * busy, 2600.0)
			p["phase"] = float(p["phase"]) + delta * 8.0 * busy
	queue_redraw()


func rect_of(loc: Dictionary) -> Rect2:
	var r: Array = loc["rect"]
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


func door_of(loc: Dictionary) -> Vector2:
	var d: Array = loc["door"]
	return Vector2(float(d[0]), float(d[1]))


func is_night() -> bool:
	return state.block >= 2


# --- Drawing ------------------------------------------------------------------

func _draw() -> void:
	if db == null:
		return
	var W := float(db.world.get("width", 2600))
	var H := float(db.world.get("height", 1200))
	_draw_sky(W)
	_draw_skyline(W)
	_draw_ground(W, H)
	for id in db.location_order:
		var loc: Dictionary = db.locations[id]
		if str(loc.get("kind", "")) == "hotspot":
			continue
		if rect_of(loc).position.y < 600.0:
			if bool(loc.get("landmark", false)):
				_draw_mothership(loc)
			else:
				_draw_facade(loc)
		else:
			_draw_roof_building(loc)
	_draw_hotspots()
	_draw_props()
	_draw_life()
	_draw_markers()


func _draw_sky(W: float) -> void:
	var c: Array = sky_colors(state.block)
	CharacterArt.vgradient(self, Rect2(-400, -500, W + 800, 1020), c[0], c[1])
	if is_night():
		var r := RandomNumberGenerator.new()
		r.seed = 7
		for i in range(90):
			var p := Vector2(r.randf_range(-300, W + 300), r.randf_range(-480, 240))
			var tw := 0.6 + 0.4 * sin(t * 2.0 + i) if not GameSettings.reduced_motion() else 0.8
			draw_circle(p, r.randf_range(0.8, 2.0), Color(1, 1, 1, 0.55 * tw))
		draw_circle(Vector2(2300, -300), 34, Color("#f4f0d8"))
		draw_circle(Vector2(2314, -308), 30, c[0])
	else:
		draw_circle(Vector2(300 if state.block == 0 else 2200, -260), 46, Color(1.0, 0.95, 0.75, 0.9))


func _draw_skyline(W: float) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 11
	var base := Color("#2a2f45") if not is_night() else Color("#0e1020")
	var x := -300.0
	while x < W + 300.0:
		var w := r.randf_range(70, 160)
		var h := r.randf_range(160, 460)
		var top := 520.0 - h
		draw_rect(Rect2(x, top, w, h), base.lerp(Color("#3a4060"), r.randf() * 0.3))
		if r.randf() < 0.3:
			draw_rect(Rect2(x + w * 0.45, top - 30, 4, 30), base)
		for wy in range(int(top) + 14, 500, 22):
			for wx in range(int(x) + 8, int(x + w) - 8, 16):
				if r.randf() < (0.28 if is_night() else 0.08):
					draw_rect(Rect2(wx, wy, 6, 8), Color(1.0, 0.85, 0.5, 0.55) if is_night() else Color(0.8, 0.9, 1.0, 0.25))
		x += w + r.randf_range(-10, 20)


func _draw_ground(W: float, H: float) -> void:
	var st := float(db.world.get("street_top", 560))
	var sb := float(db.world.get("street_bottom", 740))
	var rt := float(db.world.get("road_top", 600))
	var rb := float(db.world.get("road_bottom", 700))
	# South blocks behind the south-side buildings.
	Materials.shaded(self, Rect2(-400, sb, W + 800, H - sb + 400), "asphalt_01", Color("#4a4c56"), 0.5, 0.0, 0.4)
	# Sidewalks with tiles and curbs.
	Materials.shaded(self, Rect2(-400, 520, W + 800, rt - 520), "concrete_tiles_02", Color("#c8ccd6"), 0.35, 0.05, 0.25)
	Materials.shaded(self, Rect2(-400, rb, W + 800, 780 - rb), "concrete_tiles_02", Color("#b4b8c2"), 0.35, 0.0, 0.3)
	for x in range(-400, int(W) + 400, 44):
		draw_line(Vector2(x, 522), Vector2(x, rt - 4), Color(0, 0, 0, 0.12), 1.0)
		draw_line(Vector2(x + 22, rb + 4), Vector2(x + 22, 778), Color(0, 0, 0, 0.12), 1.0)
	draw_line(Vector2(-400, 562), Vector2(W + 400, 562), Color(0, 0, 0, 0.1), 1.0)
	draw_rect(Rect2(-400, rt - 5, W + 800, 5), Color("#9a9ea8"))
	draw_rect(Rect2(-400, rb, W + 800, 5), Color("#9a9ea8"))
	# Road.
	Materials.shaded(self, Rect2(-400, rt, W + 800, rb - rt), "asphalt_01", Color("#7a7c86"), 0.5, 0.0, 0.25)
	for x in range(-400, int(W) + 400, 120):
		draw_rect(Rect2(x, (rt + rb) * 0.5 - 3, 64, 6), Color("#d6c25a"))
	for cx in [1300.0, 1930.0]:
		for i in range(7):
			draw_rect(Rect2(cx - 60 + i * 18, rt + 4, 10, rb - rt - 8), Color(0.92, 0.92, 0.92, 0.75))
	for mx in [540.0, 1640.0, 2250.0]:
		draw_circle(Vector2(mx, rt + 24), 12, Color("#1c1d22"))
		draw_arc(Vector2(mx, rt + 24), 12, 0, TAU, 16, Color("#46484f"), 2.0)
	# Side alley and south lot.
	Materials.shaded(self, Rect2(1880, 60, 120, 460), "asphalt_01", Color("#6a6c76"), 0.5, 0.0, 0.2)
	draw_rect(Rect2(1220, sb + 40, 140, H - sb), Color("#30343c"))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(40, rt + 40), "MAIN DRAG", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.18))


## Glowing sign text: a few soft passes plus the crisp text.
func neon_text(pos: Vector2, text: String, size: int, col: Color, width: float = -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var font := ThemeDB.fallback_font
	var flick := 1.0
	if is_night() and not GameSettings.reduced_motion():
		flick = 0.85 + 0.15 * sin(t * 3.0 + text.length())
	if is_night():
		for o in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
			draw_string(font, pos + o, text, align, width, size, Color(col, 0.22 * flick))
	draw_string(font, pos, text, align, width, size, Color(col.lightened(0.25) if is_night() else col.darkened(0.15), flick))


func fit_size(text: String, width: float, max_size: int) -> int:
	var font := ThemeDB.fallback_font
	var fs := max_size
	while fs > 10 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
		fs -= 1
	return fs


func _window(r: Rect2, lit: bool, seed_i: int) -> void:
	draw_rect(r.grow(3), Color(0, 0, 0, 0.35))
	if lit:
		CharacterArt.vgradient(self, r, Color("#ffe6a8"), Color("#e8a85a"))
		if seed_i % 5 == 0:
			draw_circle(r.get_center() + Vector2(0, 4), r.size.x * 0.22, Color(0.2, 0.12, 0.1, 0.55))
			draw_rect(Rect2(r.get_center() + Vector2(-r.size.x * 0.22, 6), Vector2(r.size.x * 0.44, r.size.y * 0.4)), Color(0.2, 0.12, 0.1, 0.55))
	else:
		CharacterArt.vgradient(self, r, Color("#3d5a78"), Color("#1c2a3a"))
		draw_line(r.position + Vector2(3, r.size.y - 3), r.position + Vector2(r.size.x - 3, 3), Color(1, 1, 1, 0.12), 2.0)
	draw_line(Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y), Color(0, 0, 0, 0.4), 2.0)
	draw_rect(Rect2(r.position.x - 4, r.end.y, r.size.x + 8, 4), Color(1, 1, 1, 0.18))


func _awning(x: float, y: float, w: float, col: Color) -> void:
	var pts := PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w + 10, y + 22), Vector2(x - 10, y + 22)])
	draw_colored_polygon(pts, col)
	var stripes := int(w / 18)
	for i in range(stripes):
		if i % 2 == 0:
			var sx := x + i * (w / stripes)
			draw_colored_polygon(PackedVector2Array([Vector2(sx, y), Vector2(sx + w / stripes, y), Vector2(sx + w / stripes + 10 * (float(i + 1) / stripes - 0.5) * 2, y + 22), Vector2(sx + 10 * (float(i) / stripes - 0.5) * 2, y + 22)]), col.lightened(0.35))
	for i in range(stripes + 1):
		draw_circle(Vector2(x - 10 + i * ((w + 20) / max(1, stripes)), y + 22), 5, col.darkened(0.1))


## North-side building seen from the street.
func _draw_facade(loc: Dictionary) -> void:
	var id: String = str(loc["id"])
	var r := rect_of(loc)
	var base := Color(str(loc.get("color", "#333344")))
	var sign_c := Color(str(loc.get("sign_color", "#ffffff")))
	var open := GameSim.location_open(db, id, state.block)
	var night := is_night()
	# Roof props behind the parapet.
	draw_rect(Rect2(r.position.x + 30, r.position.y - 26, 46, 26), Color("#55595f"))
	draw_rect(Rect2(r.position.x + 34, r.position.y - 22, 38, 3), Color("#3a3d42"))
	if r.size.x > 260:
		draw_rect(Rect2(r.end.x - 70, r.position.y - 46, 34, 46), Color("#6a4a32"))
		draw_rect(Rect2(r.end.x - 74, r.position.y - 50, 42, 8), Color("#4a3222"))
	# Body with brick courses.
	var mat: String = {"hostel": "red_brick_03", "lantern": "red_brick_03", "diner": "plastered_wall", "coffee": "plastered_wall", "apartments": "plastered_wall"}.get(id, "red_brick_03")
	Materials.shaded(self, r, mat, base.lightened(0.55), 0.45 if mat == "red_brick_03" else 0.6, 0.08, 0.3)
	draw_rect(Rect2(r.position.x, r.position.y, 10, r.size.y), Color(1, 1, 1, 0.05))
	draw_rect(Rect2(r.end.x - 12, r.position.y, 12, r.size.y), Color(0, 0, 0, 0.18))
	# Cornice with dentils.
	draw_rect(Rect2(r.position.x - 8, r.position.y - 6, r.size.x + 16, 16), base.darkened(0.35))
	draw_rect(Rect2(r.position.x - 8, r.position.y - 6, r.size.x + 16, 4), base.lightened(0.3))
	for x in range(int(r.position.x), int(r.end.x), 14):
		draw_rect(Rect2(x, r.position.y + 10, 7, 5), base.darkened(0.3))
	# Upper windows.
	var cols := maxi(2, int((r.size.x - 40) / 62))
	var gap := (r.size.x - 40) / cols
	var upper_bottom := r.end.y - 110
	var row := 0
	var y := r.position.y + 34
	while y + 40 < upper_bottom:
		for c in range(cols):
			var wr := Rect2(r.position.x + 20 + c * gap + (gap - 30) * 0.5, y, 30, 38)
			var lit := night and open and (c * 7 + row * 3 + id.length()) % 4 != 0
			lit = lit or (night and (c + row + id.length()) % 5 == 1)
			_window(wr, lit, c + row * 3)
		y += 56
		row += 1
	# Storefront: sign board, awning, display windows, door.
	var d := door_of(loc)
	var sign_rect := Rect2(r.position.x + 14, r.end.y - 104, r.size.x - 28, 30)
	draw_rect(sign_rect, Color("#141218"))
	draw_rect(sign_rect, Color(sign_c, 0.6), false, 2.0)
	var name := str(loc["name"]).to_upper()
	neon_text(Vector2(sign_rect.position.x, sign_rect.position.y + 23), name, fit_size(name, sign_rect.size.x - 16, 22), sign_c, sign_rect.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	_awning(r.position.x + 16, r.end.y - 70, r.size.x - 32, base.lerp(sign_c, 0.45))
	for sx in [r.position.x + 26, d.x + 34]:
		var wr2 := Rect2(sx, r.end.y - 44, minf(90.0, d.x - 30 - r.position.x - 26) if sx < d.x else minf(90.0, r.end.x - sx - 20), 38)
		if wr2.size.x > 20:
			_window(wr2, open and (night or state.block >= 1), int(sx))
	var door := Rect2(d.x - 18, r.end.y - 48, 36, 48)
	draw_rect(door.grow(4), base.darkened(0.45))
	CharacterArt.vgradient(self, door, Color("#2a1a12") if not open else Color("#ffd890") if night else Color("#5a3a22"), Color("#120c08") if not open else Color("#a8642a") if night else Color("#2a1a12"))
	draw_circle(Vector2(door.end.x - 7, door.get_center().y), 2.5, Color("#d8c070"))
	draw_rect(Rect2(door.position.x - 8, door.end.y, door.size.x + 16, 5), Color("#8a8e96"))
	if not open:
		draw_rect(Rect2(d.x - 28, r.end.y - 30, 56, 18), Color("#3a1414"))
		draw_string(ThemeDB.fallback_font, Vector2(d.x - 26, r.end.y - 16), "CLOSED", HORIZONTAL_ALIGNMENT_CENTER, 52, 13, Color("#ff9a9a"))
	_flavor(id, r, sign_c)


func _flavor(id: String, r: Rect2, sign_c: Color) -> void:
	var font := ThemeDB.fallback_font
	match id:
		"hostel":
			draw_rect(Rect2(r.end.x - 70, r.position.y + 40, 60, 22), Color("#101010"))
			neon_text(Vector2(r.end.x - 66, r.position.y + 56), "VACANCY", 13, Color("#ff5050"))
		"diner":
			draw_rect(Rect2(r.position.x - 26, r.position.y + 20, 22, 120), Color("#202024"))
			for i in range(3):
				neon_text(Vector2(r.position.x - 22, r.position.y + 48 + i * 34), "EAT"[i], 24, Color("#ff6b6b"))
			draw_rect(Rect2(r.position.x, r.end.y - 112, r.size.x, 4), Color("#d8d8e0"))
		"coffee":
			draw_circle(Vector2(r.end.x - 34, r.position.y + 46), 16, Color("#2a1a12"))
			draw_arc(Vector2(r.end.x - 34, r.position.y + 46), 16, 0, TAU, 20, sign_c, 3.0)
			draw_arc(Vector2(r.end.x - 16, r.position.y + 46), 6, -PI * 0.5, PI * 0.5, 8, sign_c, 3.0)
		"lantern":
			for i in range(int(r.size.x / 18)):
				var on := not is_night() or GameSettings.reduced_motion() or int(t * 6.0 + i) % 3 != 0
				draw_circle(Vector2(r.position.x + 10 + i * 18, r.end.y - 108), 3.5, Color("#ffe27a") if on else Color("#6a5a2a"))
		"apartments":
			for i in range(3):
				var by := r.position.y + 76 + i * 56
				draw_rect(Rect2(r.position.x + 30, by, r.size.x - 60, 4), Color("#a0a8b0"))
				for bx in range(int(r.position.x) + 30, int(r.end.x) - 30, 10):
					draw_line(Vector2(bx, by), Vector2(bx, by - 14), Color("#a0a8b0"), 1.5)
			draw_string(font, Vector2(r.position.x + 20, r.end.y - 112), "NOW LEASING", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#cde8ff"))


## The Comedy Mothership: original saucer-marquee design (placeholder, not
## the real building's architecture).
func _draw_mothership(loc: Dictionary) -> void:
	var r := rect_of(loc)
	var sign_c := Color(str(loc.get("sign_color", "#b88cff")))
	var night := is_night()
	var wd := CalendarRules.weekday(state.day)
	Materials.shaded(self, r, "concrete_wall_003", Color("#5a60b8"), 0.6, 0.0, 0.55)
	for x in range(int(r.position.x) + 20, int(r.end.x), 40):
		draw_rect(Rect2(x, r.position.y + 60, 8, r.size.y - 60), Color(1, 1, 1, 0.05))
	draw_rect(Rect2(r.position.x - 10, r.position.y - 8, r.size.x + 20, 14), Color("#3a3e6a"))
	# Searchlights from the roof at night.
	if night:
		for i in range(2):
			var ang := -PI * 0.5 + (sin(t * 0.5 + i * 2.0) * 0.35 if not GameSettings.reduced_motion() else (i - 0.5) * 0.4)
			var o := Vector2(r.position.x + 120 + i * (r.size.x - 240), r.position.y)
			var tip := o + Vector2(cos(ang), sin(ang)) * 700.0
			var perp := Vector2(-sin(ang), cos(ang)) * 60.0
			draw_colored_polygon(PackedVector2Array([o, tip + perp, tip - perp]), Color(0.75, 0.65, 1.0, 0.07))
	# The saucer.
	var c := Vector2(r.get_center().x, r.position.y + 120)
	draw_set_transform(c + Vector2(0, -30), 0.0, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, 110, Color("#3a3e6a"))
	draw_circle(Vector2.ZERO, 92, Color("#5a5ea8"))
	draw_circle(Vector2(-25, -30), 34, Color(1, 1, 1, 0.12))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_set_transform(c, 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, 230, Color("#1c1e38"))
	draw_arc(Vector2.ZERO, 230, 0, TAU, 64, sign_c.darkened(0.2), 6.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var bulbs := 36
	for i in range(bulbs):
		var a := TAU * i / bulbs
		var p := c + Vector2(cos(a) * 230.0, sin(a) * 230.0 * 0.22)
		var on := (not night) or GameSettings.reduced_motion() or (i + int(t * 10.0)) % 4 != 0
		draw_circle(p, 4.0, Color("#fff2b0") if on and night else (Color("#e8d890") if on else Color("#6a6040")))
	neon_text(Vector2(c.x - 220, c.y + 10), "COMEDY MOTHERSHIP", 34, sign_c, 440, HORIZONTAL_ALIGNMENT_CENTER)
	# Marquee board.
	var mb := Rect2(r.position.x + 70, r.position.y + 190, r.size.x - 140, 62)
	draw_rect(mb, Color("#0a0a14"))
	draw_rect(mb, Color("#ffe27a", 0.8), false, 3.0)
	var marquee := "TONIGHT: KILL TONY" if wd == 0 else ("THURSDAY: THE SECRET SHOW" if wd == 3 else "HEADLINE SHOWS NIGHTLY")
	neon_text(Vector2(mb.position.x, mb.position.y + 42), marquee, fit_size(marquee, mb.size.x - 20, 30), Color("#ffe27a"), mb.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	# Entrance with a lit canopy.
	var d := door_of(loc)
	draw_colored_polygon(PackedVector2Array([Vector2(d.x - 120, r.end.y - 92), Vector2(d.x + 120, r.end.y - 92), Vector2(d.x + 140, r.end.y - 70), Vector2(d.x - 140, r.end.y - 70)]), Color("#2c2c54"))
	for i in range(12):
		draw_circle(Vector2(d.x - 130 + i * 23.6, r.end.y - 70), 3.5, Color("#ffe8a8") if night else Color("#a89870"))
	for side in [-1.0, 1.0]:
		var dr := Rect2(d.x - 36 + (side * 40.0 if side > 0 else -4.0) - 0.0, r.end.y - 62, 40, 62)
		draw_rect(dr, Color("#ffd890") if night else Color("#3a3050"))
		draw_rect(dr, Color("#8a7ac0"), false, 3.0)
	draw_rect(Rect2(d.x - 140, r.end.y - 6, 280, 6), Color("#8a8e96"))


## South-side building: seen from above, with its front facing the street.
func _draw_roof_building(loc: Dictionary) -> void:
	var id: String = str(loc["id"])
	var r := rect_of(loc)
	var base := Color(str(loc.get("color", "#333344")))
	var sign_c := Color(str(loc.get("sign_color", "#ffffff")))
	var open := GameSim.location_open(db, id, state.block)
	var night := is_night()
	# Roof.
	var roof := Rect2(r.position.x, r.position.y + 62, r.size.x, r.size.y - 62)
	Materials.shaded(self, roof, "gravel_concrete", Color("#8a8c96"), 0.5, 0.05, 0.3)
	draw_rect(roof, Color(0, 0, 0, 0.35), false, 4.0)
	for i in range(3):
		var vx := roof.position.x + 30 + i * (roof.size.x - 80) / 2.0
		draw_rect(Rect2(vx, roof.position.y + 30, 40, 26), Color("#6a6e76"))
		draw_rect(Rect2(vx + 4, roof.position.y + 34, 32, 4), Color("#8a8e96"))
	draw_rect(Rect2(roof.position.x + 20, roof.end.y - 40, 60, 24), Color("#2a6a8a", 0.6))
	# Front facade strip.
	var f := Rect2(r.position.x, r.position.y, r.size.x, 62)
	Materials.shaded(self, f, "plastered_wall" if id == "mart" else "factory_brick", base.lightened(0.6), 0.35, 0.05, 0.25)
	draw_rect(Rect2(f.position.x - 4, f.position.y - 4, f.size.x + 8, 6), base.darkened(0.4))
	var d := door_of(loc)
	var name := str(loc["name"]).to_upper()
	var name_w := maxf(80.0, d.x - 22.0 - (f.position.x + 8))
	neon_text(Vector2(f.position.x + 8, f.position.y + 24), name, fit_size(name, name_w, 20), sign_c)
	for wx in range(int(f.position.x) + 14, int(f.end.x) - 40, 70):
		if absf(wx + 25 - d.x) > 50:
			_window(Rect2(wx, f.position.y + 32, 46, 24), open and night, wx)
	var door := Rect2(d.x - 18, f.position.y + 18, 36, 44)
	draw_rect(door.grow(3), base.darkened(0.45))
	CharacterArt.vgradient(self, door, Color("#ffd890") if open and night else Color("#3a2a1a"), Color("#a8642a") if open and night else Color("#1a120a"))
	match id:
		"mart":
			draw_rect(Rect2(f.end.x - 84, f.position.y + 6, 76, 22), Color("#101018"))
			neon_text(Vector2(f.end.x - 80, f.position.y + 23), "OPEN 24", 16, Color("#40ff80"))
		"rusty_spur":
			draw_arc(Vector2(f.end.x - 40, f.position.y + 22), 14, PI * 0.15, PI * 1.85, 14, Color("#c8a060"), 5.0)
			draw_rect(Rect2(f.position.x, f.end.y - 6, f.size.x, 6), Color("#7a4a22"))
		"cellar":
			for i in range(4):
				draw_rect(Rect2(d.x - 24, f.end.y - 6 + i * 8, 48, 6), Color(0.25, 0.25, 0.28).darkened(i * 0.15))
			neon_text(Vector2(f.end.x - 120, f.position.y + 24), "LATE SHOW", 15, Color("#ff4fa3"))
	if not open:
		draw_string(ThemeDB.fallback_font, Vector2(d.x - 26, f.position.y + 14), "CLOSED", HORIZONTAL_ALIGNMENT_CENTER, 52, 12, Color("#ff9a9a"))


func _draw_hotspots() -> void:
	var font := ThemeDB.fallback_font
	# Bus shelter.
	var bs := rect_of(db.locations["transit_stop"])
	draw_rect(Rect2(bs.position.x, bs.position.y - 6, bs.size.x, 8), Color("#7fd1ff", 0.8))
	draw_rect(Rect2(bs.position.x, bs.position.y, bs.size.x, bs.size.y), Color(0.6, 0.8, 1.0, 0.18))
	draw_rect(Rect2(bs.position.x, bs.position.y, 6, bs.size.y), Color("#8a9aa8"))
	draw_rect(Rect2(bs.end.x - 6, bs.position.y, 6, bs.size.y), Color("#8a9aa8"))
	draw_rect(Rect2(bs.position.x + 20, bs.end.y - 18, bs.size.x - 40, 8), Color("#6a5040"))
	draw_line(Vector2(bs.end.x + 16, bs.end.y), Vector2(bs.end.x + 16, bs.position.y - 30), Color("#9aa0a8"), 4.0)
	draw_circle(Vector2(bs.end.x + 16, bs.position.y - 34), 12, Color("#2a6ac8"))
	draw_string(font, Vector2(bs.end.x + 9, bs.position.y - 29), "B", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	draw_string(font, Vector2(bs.position.x + 8, bs.position.y + 20), "BUS · RIDESHARE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#cfeaff"))
	# Notice board.
	var jb := rect_of(db.locations["job_board"])
	draw_rect(jb.grow(4), Color("#5a3a1a"))
	draw_rect(jb, Color("#b08850"))
	var r := RandomNumberGenerator.new()
	r.seed = 3
	for i in range(9):
		var p := Vector2(jb.position.x + 6 + (i % 3) * 28, jb.position.y + 4 + int(i / 3) * 15)
		draw_rect(Rect2(p, Vector2(22, 12)), Color.from_hsv(r.randf() * 0.15, 0.15, 0.95))
		draw_circle(p + Vector2(11, 1), 1.5, Color("#c02020"))
	draw_line(Vector2(jb.position.x + 10, jb.end.y + 4), Vector2(jb.position.x + 10, jb.end.y + 22), Color("#5a3a1a"), 4)
	draw_line(Vector2(jb.end.x - 10, jb.end.y + 4), Vector2(jb.end.x - 10, jb.end.y + 22), Color("#5a3a1a"), 4)
	draw_string(font, Vector2(jb.position.x, jb.position.y - 6), "JOBS · NOTICES", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#ffd28a"))


func _draw_props() -> void:
	var night := is_night()
	# Trees in planters.
	for tp in trees:
		var p: Vector2 = tp
		draw_rect(Rect2(p.x - 16, p.y - 4, 32, 14), Color("#5a4a3a"))
		draw_rect(Rect2(p.x - 3, p.y - 30, 6, 28), Color("#4a3424"))
		var sway := 0.0 if GameSettings.reduced_motion() else sin(t * 1.2 + p.x) * 2.0
		for o in [Vector2(-12, -40), Vector2(12, -42), Vector2(0, -56), Vector2(-4, -36), Vector2(8, -30)]:
			draw_circle(p + o + Vector2(sway, 0), 15, Color("#2f6a3a").darkened(0.25 if night else 0.0))
		draw_circle(p + Vector2(-6, -50 + sway), 8, Color("#4a8a4a", 0.6))
	# Parked cars.
	for c in cars:
		var x: float = float(c["x"])
		var y: float = float(c["y"])
		var L: float = float(c["len"])
		var col: Color = c["col"]
		draw_set_transform(Vector2(x + L * 0.5, y + 18), 0.0, Vector2(1.0, 0.3))
		draw_circle(Vector2.ZERO, L * 0.55, Color(0, 0, 0, 0.3))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_rect(Rect2(x, y - 6, L, 20), col)
		draw_colored_polygon(PackedVector2Array([Vector2(x + L * 0.22, y - 6), Vector2(x + L * 0.32, y - 20), Vector2(x + L * 0.7, y - 20), Vector2(x + L * 0.8, y - 6)]), col.darkened(0.1))
		draw_colored_polygon(PackedVector2Array([Vector2(x + L * 0.27, y - 7), Vector2(x + L * 0.35, y - 17), Vector2(x + L * 0.67, y - 17), Vector2(x + L * 0.75, y - 7)]), Color("#9ac8e8", 0.8))
		draw_rect(Rect2(x, y - 6, L, 4), col.lightened(0.25))
		for wx in [x + L * 0.2, x + L * 0.8]:
			draw_circle(Vector2(wx, y + 14), 8, Color("#141414"))
			draw_circle(Vector2(wx, y + 14), 3.5, Color("#8a8a8a"))
		draw_rect(Rect2(x + L - 6, y - 2, 6, 5), Color("#fff2b0") if night else Color("#e8e0c0"))
	# Benches and bike rack.
	for bx in [180.0, 900.0, 2130.0]:
		draw_rect(Rect2(bx, 572, 50, 6), Color("#7a5a3a"))
		draw_rect(Rect2(bx, 564, 50, 4), Color("#7a5a3a"))
		draw_line(Vector2(bx + 6, 578), Vector2(bx + 6, 590), Color("#3a3a3a"), 3)
		draw_line(Vector2(bx + 44, 578), Vector2(bx + 44, 590), Color("#3a3a3a"), 3)
	for i in range(4):
		draw_arc(Vector2(1110 + i * 18, 760), 8, PI, TAU, 8, Color("#9aa0a8"), 3.0)
	# Scooter pile (observation spot).
	for i in range(4):
		var sp := Vector2(985 + i * 12, 556 + (i % 2) * 6)
		draw_line(sp, sp + Vector2(24, -4), Color("#30c0a0"), 4.0)
		draw_circle(sp, 4, Color("#202020"))
		draw_circle(sp + Vector2(24, -4), 4, Color("#202020"))
	# Ambulance taco truck.
	var tt := Vector2(1352, 752)
	draw_rect(Rect2(tt, Vector2(124, 46)), Color("#ececec"))
	draw_rect(Rect2(tt + Vector2(0, 18), Vector2(124, 7)), Color("#d03030"))
	draw_rect(Rect2(tt + Vector2(92, 4), Vector2(28, 16)), Color("#80b0d0"))
	draw_rect(Rect2(tt + Vector2(20, 6), Vector2(54, 12)), Color("#ffd070") if night else Color("#806040"))
	draw_circle(tt + Vector2(22, 48), 8, Color("#202020"))
	draw_circle(tt + Vector2(100, 48), 8, Color("#202020"))
	draw_rect(Rect2(tt + Vector2(54, -8), Vector2(14, 8)), Color("#ff3030") if night and int(t * 2.0) % 2 == 0 else Color("#802020"))
	draw_string(ThemeDB.fallback_font, tt + Vector2(6, 40), "TACO EMS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#d03030"))
	# Street lamps.
	for x in lamp_positions():
		var p: Vector2 = x
		draw_line(p, p + Vector2(0, -58), Color("#4a4e56"), 5)
		draw_line(p + Vector2(0, -58), p + Vector2(14, -62), Color("#4a4e56"), 4)
		draw_rect(Rect2(p.x + 8, p.y - 66, 16, 8), Color("#2a2c30"))
		draw_rect(Rect2(p.x + 10, p.y - 59, 12, 4), Color("#fff2c0") if night else Color("#9aa0a8"))
	# Bucket line with stanchions on Monday.
	var wd := CalendarRules.weekday(state.day)
	if wd == 0 and state.block in [1, 2]:
		draw_line(Vector2(1070, 556), Vector2(1530, 556), Color("#c03040"), 3)
		for sx in range(1070, 1540, 92):
			draw_line(Vector2(sx, 556), Vector2(sx, 576), Color("#c8b060"), 4)


func lamp_positions() -> Array:
	var out: Array = []
	for x in range(150, 2600, 300):
		out.append(Vector2(x, 596))
		out.append(Vector2(x + 150, 712))
	return out


func _draw_life() -> void:
	var wd := CalendarRules.weekday(state.day)
	var shown := 6 + state.block * 4
	for i in range(mini(shown, pedestrians.size())):
		var p: Dictionary = pedestrians[i]
		var pose := {"walk": float(p["phase"]), "facing": signf(float(p["v"])), "bob": abs(sin(float(p["phase"]))) * -1.5}
		CharacterArt.draw(self, Vector2(float(p["x"]), float(p["y"])), 0.82, p["look"], pose)
	if wd == 0 and state.block in [1, 2]:
		for i in range(18):
			var lp := Vector2(1090 + i * 24, 560 + (i % 2) * 6)
			var bob := 0.0 if GameSettings.reduced_motion() else sin(t * 2.0 + i) * 1.0
			CharacterArt.draw(self, lp, 0.7, CharacterArt.npc_look(Color.from_hsv(fmod(i * 0.13, 1.0), 0.4, 0.7).to_html(false), i % 3 == 0, i * 5 + 1), {"bob": bob, "facing": 1.0, "expression": "nervous" if i % 4 == 0 else "neutral"})
		draw_string(ThemeDB.fallback_font, Vector2(1090, 500), "BUCKET LINE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#ffe27a"))
	if wd == 3 and is_night():
		draw_string(ThemeDB.fallback_font, Vector2(1380, 552), "Whispers about a secret show...", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#a0c0ff"))


func _draw_markers() -> void:
	var font := ThemeDB.fallback_font
	for po in db.posters:
		var pp: Array = po["pos"]
		var p := Vector2(float(pp[0]), float(pp[1]))
		draw_rect(Rect2(p - Vector2(16, 40), Vector2(32, 44)), Color("#3a3a40"))
		draw_rect(Rect2(p - Vector2(14, 38), Vector2(28, 38)), Color("#f0e6c8"))
		draw_rect(Rect2(p - Vector2(14, 38), Vector2(28, 10)), Color("#c04040"))
		for i in range(3):
			draw_line(p + Vector2(-10, -22 + i * 7), p + Vector2(10, -22 + i * 7), Color(0, 0, 0, 0.35), 1.5)
	for oid in db.observations:
		var o: Dictionary = db.observations[oid]
		if not o.has("pos") or not WorldRules.observation_available(state, o):
			continue
		var op: Array = o["pos"]
		var p := Vector2(float(op[0]), float(op[1])) + Vector2(0, -50)
		var pulse := 1.0 if GameSettings.reduced_motion() else 0.8 + 0.2 * sin(t * 4.0)
		draw_circle(p, 15 * pulse, Color(0.55, 1.0, 0.75, 0.35))
		draw_rect(Rect2(p - Vector2(8, 10), Vector2(16, 20)), Color("#f8f0d0"))
		draw_line(p + Vector2(-4, -4), p + Vector2(5, -4), Color("#506080"), 1.5)
		draw_line(p + Vector2(-4, 1), p + Vector2(5, 1), Color("#506080"), 1.5)
		draw_line(p + Vector2(-4, 6), p + Vector2(2, 6), Color("#506080"), 1.5)
	if not state.flags.has("has_bag"):
		draw_rect(Rect2(232, 742, 30, 22), Color("#6b4a2a"))
		draw_rect(Rect2(240, 736, 14, 6), Color("#4a3018"))
		draw_string(font, Vector2(222, 732), "your bag", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)


## Text shown when inspecting a poster; it changes as the career progresses.
func poster_text(poster_id: String) -> String:
	var stage: String = str(state.player.get("stage_name", "you"))
	match poster_id:
		"poster_mothership":
			var t2 := "KILL TONY · MONDAYS\nBucket signups before the show. Anyone can put their name in."
			if int(state.kt.get("appearances", 0)) > 0:
				t2 += "\n\nSomeone has scrawled \"%s was here\" next to it. People keep taking pictures of it." % stage
			return t2
		"poster_spur":
			var t3 := "OPEN MIC · NIGHTLY EXCEPT MONDAY\n$5 bar minimum · 3 minutes · respect the light"
			if state.career_tier >= 2:
				t3 += "\n\nHandwritten at the bottom: \"Spur regulars: Deshawn, %s, ...\"" % stage
			return t3
		"poster_lantern":
			for c in Scheduler.booked(state):
				if str(c.get("location_id", "")) == "lantern":
					return "THE LANTERN ROOM\nComing up: %s featuring %s (%s)." % [c["title"], stage, CalendarRules.describe_slot(int(c["day"]), int(c["block"]))]
			return "THE LANTERN ROOM\nThursday-Saturday: LONNIE SZABO. Showcases most Wednesdays."
	return ""
