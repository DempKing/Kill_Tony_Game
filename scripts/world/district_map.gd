class_name DistrictMap
extends Node2D
## Draws the compressed, fictional Austin entertainment district with simple
## original placeholder art: street, sidewalks, modular buildings, neon
## signs, lamps, posters, crowds. Layout data comes from data/venues/locations.json.

var db: ContentDB
var state: GameState
var t: float = 0.0
var pedestrians: Array = []
var _rng := RandomNumberGenerator.new()


func setup(p_db: ContentDB, p_state: GameState) -> void:
	db = p_db
	state = p_state
	_rng.seed = 99
	for i in range(18):
		pedestrians.append({"x": _rng.randf_range(0, 2600), "y": [575.0, 725.0][i % 2], "v": _rng.randf_range(30, 70) * (1 if i % 3 else -1), "c": Color.from_hsv(_rng.randf(), 0.4, 0.8)})
	queue_redraw()


func _process(delta: float) -> void:
	t += delta
	var busy := 0.3 + 0.25 * state.block
	if not GameSettings.reduced_motion():
		for p in pedestrians:
			p["x"] = fposmod(float(p["x"]) + float(p["v"]) * delta * busy, 2600.0)
	queue_redraw()


func rect_of(loc: Dictionary) -> Rect2:
	var r: Array = loc["rect"]
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


func door_of(loc: Dictionary) -> Vector2:
	var d: Array = loc["door"]
	return Vector2(float(d[0]), float(d[1]))


func _draw() -> void:
	if db == null:
		return
	var w: Dictionary = db.world
	var W := float(w.get("width", 2600))
	var H := float(w.get("height", 1200))
	var font := ThemeDB.fallback_font
	# Ground, blocks, alley.
	draw_rect(Rect2(-400, -400, W + 800, H + 800), Color("#141a22"))
	draw_rect(Rect2(0, 0, W, H), Color("#1c232c"))
	var st := float(w.get("street_top", 560))
	var sb := float(w.get("street_bottom", 740))
	var rt := float(w.get("road_top", 600))
	var rb := float(w.get("road_bottom", 700))
	draw_rect(Rect2(0, st, W, sb - st), Color("#3a3f48"))
	draw_rect(Rect2(0, rt, W, rb - rt), Color("#24272d"))
	for x in range(0, int(W), 120):
		draw_rect(Rect2(x, (rt + rb) * 0.5 - 3, 60, 6), Color("#c9b45a"))
	# Side alley and south lot.
	draw_rect(Rect2(1880, 80, 120, st - 80), Color("#30353d"))
	draw_string(font, Vector2(1890, 120), "ALLEY", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#7a808c"))
	draw_rect(Rect2(1220, sb, 120, H - sb), Color("#30353d"))
	draw_string(font, Vector2(40, rt + 36), "MAIN DRAG  (fictional, compressed district)", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#6a707c"))
	var wd := CalendarRules.weekday(state.day)
	var night := state.block >= 2
	# Buildings.
	for id in db.location_order:
		var loc: Dictionary = db.locations[id]
		var r := rect_of(loc)
		var base := Color(str(loc.get("color", "#333344")))
		var sign_c := Color(str(loc.get("sign_color", "#ffffff")))
		var open := GameSim.location_open(db, id, state.block)
		if str(loc.get("kind", "")) == "hotspot":
			draw_rect(r, base)
			draw_rect(r, sign_c, false, 2.0)
			draw_string(font, r.position + Vector2(6, 22), str(loc["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, sign_c)
		else:
			draw_rect(r, base)
			draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 14), base.darkened(0.3))
			# Windows.
			var lit := Color("#ffe9a8") if night and open else Color("#3a4150")
			var cols := int(r.size.x / 60)
			var rows := int((r.size.y - 80) / 60)
			for cx in range(cols):
				for cy in range(rows):
					draw_rect(Rect2(r.position.x + 18 + cx * 60, r.position.y + 30 + cy * 60, 26, 30), lit if (cx + cy + id.length()) % 3 != 0 else lit.darkened(0.5))
			# Door.
			var d := door_of(loc)
			draw_rect(Rect2(d.x - 22, r.end.y - 50 if d.y > r.end.y else r.position.y, 44, 50), Color("#120e0a") if open else Color("#3a2a2a"))
			# Sign / marquee.
			var glow := 0.75 + 0.25 * sin(t * 3.0 + id.length()) if night and not GameSettings.reduced_motion() else 0.9
			var sign_y := r.end.y - 72 if d.y > r.end.y else r.position.y + 70
			if bool(loc.get("landmark", false)):
				draw_rect(Rect2(r.position.x + 40, r.position.y + 40, r.size.x - 80, 70), Color("#0a0a18"))
				draw_rect(Rect2(r.position.x + 40, r.position.y + 40, r.size.x - 80, 70), Color(sign_c, glow), false, 4.0)
				draw_string(font, Vector2(r.position.x + 60, r.position.y + 88), "COMEDY MOTHERSHIP", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(sign_c, glow))
				var marquee := "TONIGHT: KILL TONY" if wd == 0 else ("THURSDAY: THE SECRET SHOW" if wd == 3 else "HEADLINE SHOWS NIGHTLY")
				draw_string(font, Vector2(r.position.x + 60, r.position.y + 140), marquee, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#ffe27a"))
			else:
				var sign_txt := str(loc["name"]).to_upper()
				var fs := 20
				while fs > 11 and font.get_string_size(sign_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > r.size.x - 20:
					fs -= 1
				draw_string(font, Vector2(r.position.x + 10, sign_y), sign_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(sign_c, glow))
			if not open:
				draw_string(font, Vector2(d.x - 30, sign_y + 22), "CLOSED", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#ff8a8a"))
	# Street lamps.
	for x in range(150, int(W), 300):
		for y in [st + 6, sb - 6]:
			draw_line(Vector2(x, y), Vector2(x, y - 40), Color("#5a606a"), 4)
			if night:
				draw_circle(Vector2(x, y - 40), 60, Color(1.0, 0.9, 0.6, 0.08))
			draw_circle(Vector2(x, y - 40), 6, Color("#ffe9a8") if night else Color("#8a8f98"))
	# Monday line outside the Mothership.
	if wd == 0 and state.block in [1, 2]:
		for i in range(40):
			var px := 1080.0 + (i % 20) * 22.0
			var py := 548.0 + int(i / 20) * 14.0
			draw_circle(Vector2(px, py), 7, Color.from_hsv(fmod(i * 0.13, 1.0), 0.4, 0.75))
		draw_string(font, Vector2(1080, 530), "Bucket line", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#ffe27a"))
	# Thursday secret show buzz.
	if wd == 3 and state.block >= 2:
		draw_string(font, Vector2(1360, 552), "Whispers about a secret show...", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#a0c0ff"))
	# Pedestrians (more in the evening).
	var shown := 6 + state.block * 4
	for i in range(mini(shown, pedestrians.size())):
		var p: Dictionary = pedestrians[i]
		draw_circle(Vector2(float(p["x"]), float(p["y"])), 8, p["c"])
	# Ambulance taco truck (decorative).
	draw_rect(Rect2(1352, 756, 120, 44), Color("#e8e8e8"))
	draw_rect(Rect2(1352, 772, 120, 6), Color("#d03030"))
	draw_rect(Rect2(1440, 760, 26, 16), Color("#80b0d0"))
	draw_circle(Vector2(1375, 802), 8, Color("#202020"))
	draw_circle(Vector2(1450, 802), 8, Color("#202020"))
	draw_string(font, Vector2(1356, 770), "TACO EMS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#d03030"))
	# Posters.
	for po in db.posters:
		var pp: Array = po["pos"]
		var ppos := Vector2(float(pp[0]), float(pp[1]))
		draw_rect(Rect2(ppos - Vector2(14, 18), Vector2(28, 36)), Color("#e8e0c8"))
		draw_rect(Rect2(ppos - Vector2(10, 12), Vector2(20, 8)), Color("#c04040"))
	# Observation spots (only when there's something new to notice).
	for oid in db.observations:
		var o: Dictionary = db.observations[oid]
		if not o.has("pos") or not WorldRules.observation_available(state, o):
			continue
		var op: Array = o["pos"]
		var opos := Vector2(float(op[0]), float(op[1]))
		var pulse := 1.0 if GameSettings.reduced_motion() else 0.7 + 0.3 * sin(t * 4.0)
		draw_circle(opos, 12 * pulse + 4, Color(0.7, 1.0, 0.8, 0.25))
		draw_string(font, opos + Vector2(-8, 6), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#c8ffd8"))
	# Arrival bag.
	if not state.flags.has("has_bag"):
		draw_rect(Rect2(232, 742, 30, 22), Color("#6b4a2a"))
		draw_string(font, Vector2(226, 736), "your bag", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)


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
