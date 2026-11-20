class_name KtStage3D
extends Node3D
## 3D Kill Tony stage blockout, driven by data/partner/kill_tony_stage_layout.json.
## Stage-left to stage-right (from the audience): Redban's sound station, the
## panel desk (up to three guests, then Tony in the host seat nearest the mic),
## the mic and the bucket at center, and the band riser. The audience faces
## the stage. Horizontal positions come from the layout's design-pixel x
## values ((x - 800) / 100 meters); depths are fixed here. Original placeholder
## geometry, not architecturally accurate, pending partner-approved references.
##
## Same knobs as the old 2D KtStageArt: reaction, panel_reaction, band_cue,
## redban_cue, player_at_mic, player_at_panel_seat, guest_at_mic,
## guest_color, guests, show_bucket. frame(phase) moves the camera.

var layout: Dictionary = {}
var partner: Dictionary = {}
var player_colors: Dictionary = {}
var player_look: Dictionary = {}
var reaction: float = 0.0
var panel_reaction: float = 0.0
var band_cue: float = 0.0
var redban_cue: float = 0.0
var player_at_mic: bool = false
var player_at_panel_seat: int = -1
var guest_at_mic: bool = false
var guest_color := Color("#88aacc")
var guests: Array = []
var show_bucket: bool = true
var reduced: bool = false

const H := 0.5          # stage height
const Z_MIC := -0.3
const Z_DESK := -1.9
const Z_SEAT := -2.55
const Z_BACK := -4.2

var cam: Camera3D
var _look := Vector3(0, 1.8, -2)
var _cam_tween: Tween
var _people: Node3D
var _sig: String = ""
var _panel: Array = []        # Character3D seated at the desk (Tony last)
var _redban: Character3D
var _at_mic: Character3D
var _band: Array = []
var _cymbals: Array = []
var _pads: Array = []
var _bucket: Node3D
var _crowd: Crowd3D
var _ribs: Array = []
var _sign: Label3D
var _t: float = 0.0


static func lx(x: float) -> float:
	return (x - 800.0) / 100.0


func _v(arr: Array) -> Vector2:
	return Vector2(float(arr[0]), float(arr[1]))


func _r(key: String, sub: String = "rect") -> Rect2:
	var a: Array = layout.get(key, {}).get(sub, [0, 0, 10, 10])
	return Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 50.0
	add_child(cam)
	cam.make_current()
	_build_room()
	_build_panel_furniture()
	_build_redban_station()
	_build_band()
	_build_center()
	_build_audience()
	_people = Node3D.new()
	add_child(_people)
	frame("arrival", true)


# --- Room ------------------------------------------------------------------

func _build_room() -> void:
	var trim := Color(str(layout.get("backdrop", {}).get("trim", "#b88cff")))
	var bdc := Color(str(layout.get("backdrop", {}).get("color", "#141430")))
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#05040a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#6a5a9a")
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.7
	we.environment = env
	add_child(we)
	# Floor, walls, ceiling.
	# Inside the Comedy Mothership: clean room, painted panels, plain carpet.
	Mat3D.box(self, Vector3(0, -0.05, 4), Vector3(22, 0.1, 20), Mat3D.color(Color("#1c1828"), 0.95))
	for sx in [-1.0, 1.0]:
		Mat3D.box(self, Vector3(sx * 10.5, 3.5, 4), Vector3(0.2, 7, 20), Mat3D.color(Color("#1e1c30"), 0.8))
		for k in range(6):
			Mat3D.box(self, Vector3(sx * 10.38, 3.2, -2.0 + k * 3.0), Vector3(0.05, 4.4, 2.6), Mat3D.color(Color("#2a2644"), 0.95))
	Mat3D.box(self, Vector3(0, 7.0, 4), Vector3(22, 0.2, 20), Mat3D.color(Color("#08070e"), 0.9))
	# Backdrop: purple velvet wall, glowing ribs, trim frame.
	var bd := _r("backdrop")
	var bx0 := lx(bd.position.x)
	var bx1 := lx(bd.end.x)
	var bw := bx1 - bx0
	Mat3D.box(self, Vector3(0, 3.5, Z_BACK - 0.2), Vector3(21, 7, 0.2), Mat3D.color(Color("#05040a"), 0.9))
	Mat3D.box(self, Vector3((bx0 + bx1) * 0.5, 3.0, Z_BACK), Vector3(bw, 5.4, 0.12), Mat3D.surface("velour_velvet", bdc.lightened(0.55), 0.6))
	for i in range(13):
		var x := bx0 + 0.3 + i * (bw - 0.6) / 12.0
		var rib := Mat3D.box(self, Vector3(x, 2.4, Z_BACK + 0.08), Vector3(0.08, 3.6, 0.03), Mat3D.glow(trim, 0.8))
		_ribs.append(rib)
	for e in [[Vector3((bx0 + bx1) * 0.5, 5.7, Z_BACK + 0.08), Vector3(bw + 0.1, 0.06, 0.05)], [Vector3((bx0 + bx1) * 0.5, 0.3 + H, Z_BACK + 0.08), Vector3(bw + 0.1, 0.06, 0.05)], [Vector3(bx0, 3.0, Z_BACK + 0.08), Vector3(0.06, 5.4, 0.05)], [Vector3(bx1, 3.0, Z_BACK + 0.08), Vector3(0.06, 5.4, 0.05)]]:
		Mat3D.box(self, e[0], e[1], Mat3D.glow(trim, 2.0))
	# Signage panel (placeholder text, no logo).
	var sg: Dictionary = layout.get("signage", {})
	var sign_text: String = str(partner.get("show", {}).get(str(sg.get("text_key", "")), "SHOW SIGNAGE (placeholder)"))
	Mat3D.box(self, Vector3(0, 4.9, Z_BACK + 0.1), Vector3(8.8, 0.9, 0.08), Mat3D.color(Color("#07060e"), 0.5))
	_sign = Mat3D.label(self, Vector3(0, 4.9, Z_BACK + 0.16), sign_text, 64, Color(str(sg.get("color", "#d8c2ff"))), false, 8)
	Mat3D.label(self, Vector3(bx1 - 2.2, 5.45, Z_BACK + 0.12), "STAGE BLOCKOUT · placeholder · not architecturally accurate", 16, Color(trim, 0.6), false, 2)
	# Stage floor, lip and footlights.
	var sf := _r("stage_floor")
	var sfc := Color(str(layout.get("stage_floor", {}).get("color", "#2a2440")))
	var sx0 := lx(sf.position.x)
	var sx1 := lx(sf.end.x)
	Mat3D.box(self, Vector3((sx0 + sx1) * 0.5, H * 0.5, -1.7), Vector3(sx1 - sx0, H, 5.2), Mat3D.surface("wood_floor", sfc.lightened(0.7), 0.5, 0.5))
	Mat3D.box(self, Vector3((sx0 + sx1) * 0.5, H * 0.5, 0.92), Vector3(sx1 - sx0 + 0.1, H, 0.06), Mat3D.color(Color("#0e0c18"), 0.7))
	for i in range(24):
		Mat3D.box(self, Vector3(sx0 + 0.3 + i * (sx1 - sx0 - 0.6) / 23.0, H * 0.45, 0.96), Vector3(0.1, 0.05, 0.03), Mat3D.glow(Color("#ffe8c0"), 2.5))
	# House light and a wash on the panel.
	_omni(Vector3(0, 6, 3), Color("#c8b8ff"), 1.0, 16.0)
	_omni(Vector3(-3.5, 4.5, 0.5), Color("#e8dcff"), 1.2, 7.0)
	_omni(Vector3(4.8, 4.5, 0.0), Color("#aac8ff"), 0.9, 6.0)


func _omni(p: Vector3, c: Color, e: float, r: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = p
	l.light_color = c
	l.light_energy = e
	l.omni_range = r
	add_child(l)
	return l


func _cyl(parent: Node3D, pos: Vector3, top: float, bottom: float, h: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = h
	cm.radial_segments = 14
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _table_mic(parent: Node3D, pos: Vector3) -> void:
	var m := Mat3D.color(Color("#a0a0a8"), 0.3, 0.8)
	var arm := _cyl(parent, pos + Vector3(0, 0.14, 0.05), 0.012, 0.012, 0.3, m)
	arm.rotation.x = -0.6
	_cyl(parent, pos + Vector3(0, 0.0, 0), 0.06, 0.07, 0.03, Mat3D.color(Color("#202024"), 0.4, 0.6))
	var head := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.035
	sph.height = 0.07
	head.mesh = sph
	head.material_override = Mat3D.color(Color("#505058"), 0.3, 0.8)
	head.position = pos + Vector3(0, 0.27, 0.15)
	parent.add_child(head)


# --- Panel ----------------------------------------------------------------

func _panel_seats() -> Array:
	var pl: Dictionary = layout.get("panel", {})
	var out: Array = [Vector3(lx(_v(pl.get("host_seat", [655, 395])).x), H, Z_SEAT)]
	for gs in pl.get("guest_seats", []):
		out.append(Vector3(lx(float(gs[0])), H, Z_SEAT))
	return out   # [host, guest0, guest1, guest2]


func _build_panel_furniture() -> void:
	var desk := _r("panel", "desk_rect")
	var x0 := lx(desk.position.x)
	var x1 := lx(desk.end.x)
	var cx := (x0 + x1) * 0.5
	Mat3D.box(self, Vector3(cx, H + 0.4, Z_DESK), Vector3(x1 - x0, 0.8, 0.7), Mat3D.surface("dark_wood", Color("#b8a0d8"), 1.0))
	Mat3D.box(self, Vector3(cx, H + 0.82, Z_DESK - 0.05), Vector3(x1 - x0 + 0.1, 0.05, 0.85), Mat3D.surface("dark_wood", Color("#8a78a8"), 1.0))
	Mat3D.box(self, Vector3(cx, H + 0.15, Z_DESK + 0.36), Vector3(x1 - x0 - 0.2, 0.04, 0.02), Mat3D.glow(Color("#b88cff"), 2.0))
	Mat3D.label(self, Vector3(x0 + 0.5, H + 0.5, Z_DESK + 0.36), "PANEL", 28, Color("#e0d0ff"), false, 3)
	for sp in _panel_seats():
		var p: Vector3 = sp
		Mat3D.box(self, p + Vector3(0, 0.25, -0.05), Vector3(0.55, 0.5, 0.5), Mat3D.surface("velour_velvet", Color("#5a4870"), 1.0))
		Mat3D.box(self, p + Vector3(0, 0.75, -0.3), Vector3(0.55, 0.6, 0.1), Mat3D.surface("velour_velvet", Color("#5a4870"), 1.0))
	# Tony's cue cards and water.
	var hs: Vector3 = _panel_seats()[0]
	Mat3D.box(self, Vector3(hs.x - 0.25, H + 0.86, Z_DESK + 0.05), Vector3(0.2, 0.01, 0.13), Mat3D.color(Color("#f0ead8"), 0.9))
	_cyl(self, Vector3(hs.x + 0.3, H + 0.95, Z_DESK), 0.035, 0.035, 0.18, Mat3D.color(Color(0.7, 0.85, 1.0, 0.6), 0.1))


func _partner_look(id: String) -> Dictionary:
	var lk: Dictionary = partner.get("characters", {}).get(id, {}).get("look", {})
	if lk.is_empty():
		return CharacterArt.npc_look("#888888", false, id.length())
	return lk


func _char(id: String) -> Dictionary:
	return partner.get("characters", {}).get(id, {})


func _plook() -> Dictionary:
	return player_look if not player_look.is_empty() else CharacterArt.look_from(player_colors)


func _seat_person(look: Dictionary, pos: Vector3, tag: String, col: Color, tag_row: int = 0) -> Character3D:
	var c := Character3D.create(look)
	# Seats are close together, so alternate tag heights to keep them readable.
	c.set_tag(tag, col, 1.95 + 0.32 * tag_row, 26)
	c.seated = true
	c.position = pos
	# Turn slightly toward the mic at center stage.
	c.rotation.y = clampf(-pos.x * 0.06, -0.5, 0.5)
	_people.add_child(c)
	return c


## Rebuilds who sits where whenever the guest list or player role changes.
func _sync_people() -> void:
	var sig := "%s|%d|%s|%s|%s" % [str(guests), player_at_panel_seat, str(player_at_mic), str(guest_at_mic), guest_color.to_html()]
	if sig == _sig:
		return
	_sig = sig
	for c in _people.get_children():
		c.queue_free()
	_panel.clear()
	var seats := _panel_seats()
	var occupants: Array = []
	if player_at_panel_seat >= 0:
		occupants.append({"player": true})
	for g in guests:
		if occupants.size() >= seats.size() - 1:
			break
		occupants.append(g)
	for i in range(occupants.size()):
		var o: Dictionary = occupants[i]
		var p: Vector3 = seats[i + 1]
		if bool(o.get("player", false)):
			_panel.append(_seat_person(_plook(), p, "YOU (panel guest)", Color("#ffe27a"), (i + 1) % 2))
		else:
			var col := Color(str(o.get("color", "#d0d0d0")))
			_panel.append(_seat_person(CharacterArt.npc_look(col.to_html(false), bool(o.get("female", false)), str(o.get("name", "")).length() * 3 + i), p, str(o.get("name", "Guest")), col, (i + 1) % 2))
		_table_mic(_people, Vector3(p.x + 0.15, H + 0.85, Z_DESK - 0.1))
	var host := _char("partner_host")
	_panel.append(_seat_person(_partner_look("partner_host"), seats[0], str(host.get("label", "Host")) + " · host", Color(str(host.get("color", "#e0d0ff")))))
	_table_mic(_people, Vector3(seats[0].x + 0.15, H + 0.85, Z_DESK - 0.1))
	var rb := _char("partner_redban")
	var st: Dictionary = layout.get("redban_station", {})
	if not st.is_empty():
		var seat := _v(st.get("seat", [140, 412]))
		_redban = _seat_person(_partner_look("partner_redban"), Vector3(lx(seat.x), H, Z_SEAT), str(rb.get("label", "Redban")) + " · sound", Color(str(rb.get("color", "#ff7a7a"))), 1 if occupants.size() % 2 == 0 else 0)
	# Whoever is at the mic.
	_at_mic = null
	if player_at_mic:
		_at_mic = Character3D.create(_plook())
	elif guest_at_mic:
		_at_mic = Character3D.create(CharacterArt.npc_look(guest_color.to_html(false), int(guest_color.g * 10.0) % 2 == 0, int(guest_color.r * 100.0)))
	if _at_mic != null:
		_at_mic.mic_hand = true
		var mic := _v(layout.get("mic", {}).get("pos", [800, 500]))
		_at_mic.position = Vector3(lx(mic.x) + 0.25, H, Z_MIC + 0.15)
		_at_mic.rotation.y = -0.1
		_people.add_child(_at_mic)


# --- Redban's station -----------------------------------------------------

func _build_redban_station() -> void:
	var st: Dictionary = layout.get("redban_station", {})
	if st.is_empty():
		return
	var d := _r("redban_station", "desk_rect")
	var x0 := lx(d.position.x)
	var x1 := lx(d.end.x)
	var cx := (x0 + x1) * 0.5
	var seat := _v(st.get("seat", [140, 412]))
	Mat3D.box(self, Vector3(cx, H + 0.4, Z_DESK), Vector3(x1 - x0, 0.8, 0.7), Mat3D.surface("dark_wood", Color("#a08878"), 1.0))
	Mat3D.box(self, Vector3(lx(seat.x), H + 0.25, Z_SEAT - 0.05), Vector3(0.55, 0.5, 0.5), Mat3D.surface("velour_velvet", Color("#5a3a48"), 1.0))
	# Soundboard with faders and drop pads.
	var board := Mat3D.box(self, Vector3(cx - 0.2, H + 0.86, Z_DESK + 0.05), Vector3(0.9, 0.06, 0.45), Mat3D.color(Color("#1a1a20"), 0.5))
	board.rotation.x = 0.15
	for k in range(9):
		Mat3D.box(self, Vector3(cx - 0.6 + k * 0.1, H + 0.9, Z_DESK - 0.05 + float(k * 37 % 7) * 0.02), Vector3(0.03, 0.02, 0.04), Mat3D.color(Color("#d8d8e0"), 0.4))
	for k in range(4):
		var pad := Mat3D.box(self, Vector3(cx - 0.55 + k * 0.13, H + 0.9, Z_DESK + 0.2), Vector3(0.1, 0.02, 0.08), Mat3D.color(Color.from_hsv(k * 0.22, 0.8, 0.45), 0.5))
		_pads.append([pad, Color.from_hsv(k * 0.22, 0.8, 1.0)])
	var laptop := ModelLib.instance("classic_laptop", [], 0.75)
	if laptop != null:
		laptop.position = Vector3(cx + 0.45, H + 0.83, Z_DESK)
		laptop.rotation.y = PI
		add_child(laptop)
	_omni(Vector3(cx + 0.45, H + 1.2, Z_DESK - 0.3), Color("#9ac0ff"), 0.5, 1.6)
	_table_mic(self, Vector3(lx(seat.x) + 0.2, H + 0.85, Z_DESK - 0.1))


# --- Band ---------------------------------------------------------------------

func _build_band() -> void:
	var rr := _r("band", "riser_rect")
	var x0 := lx(rr.position.x)
	var x1 := lx(rr.end.x)
	var cx := (x0 + x1) * 0.5
	var rh := 0.35
	Mat3D.box(self, Vector3(cx, H + rh * 0.5, -2.6), Vector3(x1 - x0, rh, 2.4), Mat3D.surface("dark_wood", Color("#8a7ab0"), 1.0))
	Mat3D.label(self, Vector3(x0 + 0.5, H + 0.17, -1.39), "BAND", 28, Color("#aac8ff"), false, 3)
	var top := H + rh
	var players: Array = layout.get("band", {}).get("players", [])
	for i in range(players.size()):
		var px := lx(float(players[i][0]))
		var lk := CharacterArt.npc_look("#3a4a7a", i == 1, i * 13 + 2)
		var c := Character3D.create(lk)
		c.position = Vector3(px, top, -2.9)
		c.rotation.y = -0.25
		add_child(c)
		_band.append(c)
		match i:
			0:  # Drums.
				c.seated = true
				c.set_expression("smile")
				var kick := _cyl(self, Vector3(px, top + 0.35, -2.2), 0.34, 0.34, 0.3, Mat3D.color(Color("#c03040"), 0.4))
				kick.rotation.x = PI * 0.5
				for sx in [-0.55, 0.55]:
					_cyl(self, Vector3(px + sx, top + 0.6, -2.35), 0.2, 0.2, 0.18, Mat3D.color(Color("#3a3a4a"), 0.4))
					_cyl(self, Vector3(px + sx * 1.4, top + 0.55, -2.5), 0.012, 0.012, 1.1, Mat3D.color(Color("#8a8a90"), 0.3, 0.8))
					var cym := _cyl(self, Vector3(px + sx * 1.4, top + 1.12, -2.5), 0.3, 0.3, 0.015, Mat3D.color(Color("#d8c050"), 0.25, 0.9))
					_cymbals.append(cym)
			1:  # Keys.
				c.set_expression("smile")
				Mat3D.box(self, Vector3(px, top + 0.9, -2.45), Vector3(1.2, 0.08, 0.35), Mat3D.color(Color("#1a1a20"), 0.4))
				Mat3D.box(self, Vector3(px, top + 0.945, -2.38), Vector3(1.1, 0.012, 0.16), Mat3D.color(Color("#f0f0f0"), 0.5))
				for sx in [-0.45, 0.45]:
					var leg := Mat3D.box(self, Vector3(px + sx, top + 0.43, -2.45), Vector3(0.04, 0.9, 0.04), Mat3D.color(Color("#5a5a60"), 0.4, 0.7))
					leg.rotation.z = sx * 0.3
			_:  # Bass.
				var body := Mat3D.box(c, Vector3(0.05, 1.05, 0.2), Vector3(0.4, 0.5, 0.08), Mat3D.color(Color("#8a4a22"), 0.4))
				body.rotation.z = -0.5
				var neck := Mat3D.box(c, Vector3(-0.3, 1.35, 0.22), Vector3(0.06, 0.9, 0.04), Mat3D.color(Color("#4a2a12"), 0.5))
				neck.rotation.z = -1.0
	# Amp.
	Mat3D.box(self, Vector3(x1 - 0.5, top + 0.35, -3.5), Vector3(0.6, 0.7, 0.4), Mat3D.color(Color("#1a1a1a"), 0.6))
	Mat3D.box(self, Vector3(x1 - 0.5, top + 0.35, -3.29), Vector3(0.5, 0.5, 0.02), Mat3D.color(Color("#3a3a3a"), 0.9))


# --- Center: mic, bucket, spotlight ---------------------------------------

func _build_center() -> void:
	var mic := _v(layout.get("mic", {}).get("pos", [800, 500]))
	var mx := lx(mic.x)
	var stand_m := Mat3D.color(Color("#b0b0b8"), 0.3, 0.8)
	_cyl(self, Vector3(mx - 0.15, H + 0.75, Z_MIC - 0.15), 0.015, 0.015, 1.5, stand_m)
	_cyl(self, Vector3(mx - 0.15, H + 0.02, Z_MIC - 0.15), 0.22, 0.22, 0.03, Mat3D.color(Color("#202024"), 0.4, 0.8))
	var bp := _v(layout.get("bucket", {}).get("pos", [mic.x - 170, mic.y - 20]))
	_bucket = Node3D.new()
	_bucket.position = Vector3(lx(bp.x), H, Z_MIC + 0.1)
	add_child(_bucket)
	_cyl(_bucket, Vector3(0, 0.45, 0), 0.02, 0.02, 0.9, Mat3D.color(Color("#6a6a74"), 0.3, 0.8))
	_cyl(_bucket, Vector3(0, 1.05, 0), 0.24, 0.18, 0.32, Mat3D.color(Color("#b8bcc8"), 0.25, 0.85))
	for i in range(6):
		var slip := Mat3D.box(_bucket, Vector3(-0.12 + i * 0.05, 1.24 + (i % 2) * 0.03, -0.02 + (i % 3) * 0.03), Vector3(0.05, 0.08, 0.005), Mat3D.color(Color("#f8f4e0"), 0.9))
		slip.rotation.z = (i - 2.5) * 0.2
	Mat3D.label(_bucket, Vector3(0, 0.55, 0.05), "the bucket", 20, Color("#c8c8d0"), true, 4)
	var spot := SpotLight3D.new()
	add_child(spot)
	spot.look_at_from_position(Vector3(mx, 6.6, 3.5), Vector3(mx, H + 1.0, Z_MIC))
	spot.light_color = Color("#fff0d8")
	spot.light_energy = 6.0
	spot.spot_range = 14.0
	spot.spot_angle = 14.0
	spot.shadow_enabled = true
	_cone(Vector3(mx, 6.6, 3.5), Vector3(mx, H, Z_MIC), 1.2, Color("#fff0d8"), 0.09)
	var pspot := SpotLight3D.new()
	add_child(pspot)
	pspot.look_at_from_position(Vector3(-3.5, 6.6, 3.0), Vector3(-3.5, H + 1.2, Z_SEAT))
	pspot.light_color = Color("#e8dcff")
	pspot.light_energy = 3.0
	pspot.spot_range = 14.0
	pspot.spot_angle = 28.0


func _cone(from: Vector3, to: Vector3, radius: float, col: Color, alpha: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(col, alpha)
	var cm := CylinderMesh.new()
	cm.top_radius = 0.08
	cm.bottom_radius = radius
	cm.height = from.distance_to(to)
	cm.cap_top = false
	cm.cap_bottom = false
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var up := (from - to).normalized()
	var side := up.cross(Vector3.FORWARD).normalized()
	mi.transform = Transform3D(Basis(side, up, side.cross(up)), (from + to) * 0.5)


func _build_audience() -> void:
	var aud: Dictionary = layout.get("audience", {})
	var counts: Array = aud.get("count_per_row", [18, 20, 22, 24])
	var rows := int(aud.get("rows", counts.size()))
	var spots: Array = []
	for r in range(rows):
		var n: int = int(counts[r]) if r < counts.size() else 18
		for i in range(n):
			spots.append(Vector3(-9.0 + 18.0 * (i + 0.5) / n, r * 0.22, 2.4 + r * 1.1))
	for r in range(rows):
		Mat3D.box(self, Vector3(0, r * 0.22 - 0.1, 2.4 + r * 1.1 + 0.3), Vector3(20, 0.2, 1.1), Mat3D.color(Color("#141220"), 0.9))
	_crowd = Crowd3D.new()
	_crowd.setup(spots, Color(str(aud.get("color", "#1c1a2a"))).darkened(0.3), Color("#b8a0ff"), true)
	add_child(_crowd)


# --- Camera ---------------------------------------------------------------

func camera_for(phase: String) -> Dictionary:
	var cams: Dictionary = layout.get("cameras_3d", {})
	var c: Dictionary = cams.get(phase, cams.get("arrival", {"pos": [0, 3.2, 11], "look": [0, 1.8, -2]}))
	var p: Array = c["pos"]
	var l: Array = c["look"]
	return {"pos": Vector3(float(p[0]), float(p[1]), float(p[2])), "look": Vector3(float(l[0]), float(l[1]), float(l[2]))}


func frame(phase: String, instant: bool = false) -> void:
	var c := camera_for(phase)
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	if instant or reduced:
		cam.position = c["pos"]
		_look = c["look"]
		cam.look_at(_look, Vector3.UP)
		return
	_cam_tween = create_tween().set_parallel(true)
	_cam_tween.tween_property(cam, "position", c["pos"], 0.9).set_trans(Tween.TRANS_SINE)
	_cam_tween.tween_property(self, "_look", c["look"], 0.9).set_trans(Tween.TRANS_SINE)


func _expr(v: float) -> String:
	if v > 0.4:
		return "laugh"
	if v > 0.1:
		return "smile"
	if v < -0.3:
		return "flat"
	return "neutral"


func _process(delta: float) -> void:
	_t += delta
	reaction = move_toward(reaction, 0.0, delta * 0.3)
	panel_reaction = move_toward(panel_reaction, 0.0, delta * 0.25)
	band_cue = move_toward(band_cue, 0.0, delta * 0.8)
	redban_cue = move_toward(redban_cue, 0.0, delta * 0.9)
	_sync_people()
	cam.look_at(_look, Vector3.UP)
	_bucket.visible = show_bucket
	_crowd.reaction = maxf(_crowd.reaction, reaction)
	for c in _panel:
		var ch: Character3D = c
		ch.set_expression(_expr(panel_reaction))
		ch.bounce = maxf(panel_reaction, 0.0)
	if _redban != null:
		_redban.set_expression("laugh" if redban_cue > 0.3 else _expr(panel_reaction))
		_redban.bounce = maxf(panel_reaction, redban_cue)
	if _at_mic != null:
		_at_mic.set_expression(_expr(reaction))
	for i in range(_pads.size()):
		var lit := redban_cue > 0.2 and (i + int(_t * 8.0)) % 2 == 0
		var col: Color = _pads[i][1]
		(_pads[i][0] as MeshInstance3D).material_override = Mat3D.glow(col, 2.5) if lit else Mat3D.color(col.darkened(0.55), 0.5)
	for cym in _cymbals:
		(cym as Node3D).rotation.x = 0.0 if reduced else band_cue * 0.25 * sin(_t * 30.0)
	for b in _band:
		(b as Character3D).bounce = 0.4 + band_cue
	if not reduced:
		for i in range(_ribs.size()):
			(_ribs[i] as Node3D).scale.y = 0.75 + 0.25 * sin(_t * 1.5 + i * 0.6)
		_sign.modulate.a = 0.85 + 0.15 * sin(_t * 2.0)
