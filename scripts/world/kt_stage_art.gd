class_name KtStageArt
extends Node2D
## Dedicated Kill Tony stage blockout, driven by data/partner/kill_tony_stage_layout.json.
## Clearly composed: comedian at the mic, panel seated at its desk, band on
## its own riser, audience facing the stage. All art is labeled placeholder
## geometry pending partner-approved references.

var layout: Dictionary = {}
var partner: Dictionary = {}
var player_colors: Dictionary = {}
var t: float = 0.0
var reaction: float = 0.0        # audience: -1 .. 1
var panel_reaction: float = 0.0  # panel: -1 .. 1
var band_cue: float = 0.0        # 0..1 decays
var player_at_mic: bool = false
var player_at_panel_seat: int = -1
var guest_at_mic: bool = false
var guest_color := Color("#88aacc")
var show_bucket: bool = true
var reduced: bool = false


func _process(delta: float) -> void:
	t += delta
	reaction = move_toward(reaction, 0.0, delta * 0.3)
	panel_reaction = move_toward(panel_reaction, 0.0, delta * 0.25)
	band_cue = move_toward(band_cue, 0.0, delta * 0.8)
	queue_redraw()


func _r(key: String, sub: String = "rect") -> Rect2:
	var a: Array = layout.get(key, {}).get(sub, [0, 0, 10, 10])
	return Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))


func _v(arr: Array) -> Vector2:
	return Vector2(float(arr[0]), float(arr[1]))


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(-400, -400, 2400, 1700), Color("#07060c"))
	# Backdrop with trim and placeholder signage.
	var bd := _r("backdrop")
	var bdc := Color(str(layout.get("backdrop", {}).get("color", "#141430")))
	var trim := Color(str(layout.get("backdrop", {}).get("trim", "#b88cff")))
	draw_rect(bd, bdc)
	for i in range(12):
		var x := bd.position.x + 40 + i * 120
		draw_line(Vector2(x, bd.position.y + 160), Vector2(x, bd.end.y - 20), Color(trim, 0.08), 3)
	draw_rect(bd, trim, false, 4.0)
	var sg: Dictionary = layout.get("signage", {})
	var sign_text: String = str(partner.get("show", {}).get(str(sg.get("text_key", "")), "SHOW SIGNAGE (placeholder)"))
	var glow := 1.0 if reduced else 0.8 + 0.2 * sin(t * 2.0)
	draw_string(font, _v(sg.get("pos", [800, 130])) - Vector2(420, 0), sign_text, HORIZONTAL_ALIGNMENT_CENTER, 840, 44, Color(Color(str(sg.get("color", "#d8c2ff"))), glow))
	draw_string(font, bd.position + Vector2(12, bd.size.y - 12), "STAGE BLOCKOUT · placeholder · not architecturally accurate", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(trim, 0.6))
	# Stage floor.
	draw_rect(_r("stage_floor"), Color(str(layout.get("stage_floor", {}).get("color", "#2a2440"))))
	# Band riser (stage right) with three players.
	var rr := _r("band", "riser_rect")
	draw_rect(rr, Color("#1e1a30"))
	draw_rect(rr, Color("#3a3460"), false, 2.0)
	draw_string(font, rr.position + Vector2(10, -10), "BAND", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#aac8ff"))
	var players: Array = layout.get("band", {}).get("players", [])
	for i in range(players.size()):
		var p := _v(players[i])
		var hit := band_cue * 10.0 if not reduced else 0.0
		var bob := 0.0 if reduced else sin(t * 4.0 + i) * 3.0
		_figure(p + Vector2(0, bob - (hit if i == 0 else 0.0)), Color("#3a4a7a"), Color("#c8a888"))
		match i:
			0:
				draw_circle(p + Vector2(0, 70), 34, Color("#555a70"))
				draw_circle(p + Vector2(42, 30), 16, Color("#d8c050") if band_cue > 0.3 else Color("#8a7a40"))
			1:
				draw_rect(Rect2(p.x - 50, p.y + 40, 100, 20), Color("#e0e0e0"))
			2:
				draw_line(p + Vector2(-20, 40), p + Vector2(30, 0), Color("#8a5a30"), 8)
	# Panel desk (stage left) with seated panel members.
	var desk := _r("panel", "desk_rect")
	var seats: Array = layout.get("panel", {}).get("seats", [])
	var members: Array = layout.get("panel", {}).get("members", [])
	var mic_pos := _v(layout.get("mic", {}).get("pos", [800, 500]))
	var chars: Dictionary = partner.get("characters", {})
	for i in range(seats.size()):
		var sp := _v(seats[i])
		var look := 0.0 if reduced else clampf((mic_pos.x - sp.x) / 400.0, -1.0, 1.0) * 6.0
		var laugh := 0.0
		if not reduced and panel_reaction > 0.2:
			laugh = absf(sin(t * 8.0 + i * 1.7)) * 8.0 * panel_reaction
		var mid: String = str(members[i]) if i < members.size() else ""
		var col := Color(str(chars.get(mid, {}).get("color", "#d0d0d0")))
		if player_at_panel_seat == i:
			_figure(sp + Vector2(look, -laugh), player_colors.get("outfit", Color.SLATE_BLUE), player_colors.get("skin", Color.TAN))
			draw_string(font, sp + Vector2(-60, -90), "YOU (panel guest)", HORIZONTAL_ALIGNMENT_CENTER, 120, 14, Color("#ffe27a"))
		else:
			_figure(sp + Vector2(look, -laugh), col.darkened(0.4), Color("#d8b898"))
			draw_string(font, sp + Vector2(-72, -90), str(chars.get(mid, {}).get("display_name", "Panel")), HORIZONTAL_ALIGNMENT_CENTER, 144, 13, col)
	draw_rect(desk, Color("#2c2238"))
	draw_rect(desk, Color("#6a5a8a"), false, 2.0)
	draw_string(font, desk.position + Vector2(10, desk.size.y - 14), "PANEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#e0d0ff"))
	for i in range(seats.size()):
		var sp2 := _v(seats[i])
		draw_line(sp2 + Vector2(20, 20), sp2 + Vector2(30, -10), Color("#a0a0a8"), 3)
	# Bucket on a stand near the mic.
	if show_bucket:
		draw_rect(Rect2(mic_pos.x - 160, mic_pos.y - 10, 50, 50), Color("#a8a8b0"))
		draw_string(font, Vector2(mic_pos.x - 172, mic_pos.y + 60), "bucket", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#c8c8d0"))
	# Microphone and the comedian.
	draw_circle(mic_pos + Vector2(0, 20), 120, Color(1, 0.95, 0.85, 0.10))
	draw_line(mic_pos + Vector2(0, -70), mic_pos + Vector2(0, 20), Color("#c0c0c8"), 5)
	draw_circle(mic_pos + Vector2(0, -74), 9, Color("#404048"))
	if guest_at_mic and not player_at_mic:
		_figure(mic_pos + Vector2(40, -10), guest_color, Color("#d8b090"), Color("#2a2420"), 1.3)
	if player_at_mic:
		var bob2 := 0.0 if reduced else sin(t * 2.2) * 2.0
		var fp := mic_pos + Vector2(40, -10 + bob2)
		_figure(fp, player_colors.get("outfit", Color.SLATE_BLUE), player_colors.get("skin", Color.TAN), player_colors.get("hair", Color.BLACK), 1.3)
		if bool(player_colors.get("long_hair", false)):
			draw_rect(Rect2(fp.x - 26, fp.y - 80, 7, 30), player_colors.get("hair", Color.BLACK))
			draw_rect(Rect2(fp.x + 19, fp.y - 80, 7, 30), player_colors.get("hair", Color.BLACK))
	# Audience rows facing the stage.
	var aud: Dictionary = layout.get("audience", {})
	var row_y: Array = aud.get("row_y", [700, 760, 820])
	var counts: Array = aud.get("count_per_row", [18, 20, 22])
	var ac := Color(str(aud.get("color", "#1c1a2a")))
	for r in range(row_y.size()):
		var n: int = int(counts[r]) if r < counts.size() else 18
		for i in range(n):
			var x := 40.0 + (1520.0 / n) * (i + 0.5)
			var y := float(row_y[r])
			var jump := 0.0
			if not reduced and reaction > 0.15:
				jump = absf(sin(t * 9.0 + i * 0.7 + r)) * 10.0 * reaction
			draw_circle(Vector2(x, y - jump), 20, ac.lightened(0.04 * r))
			draw_rect(Rect2(x - 26, y + 12 - jump, 52, 60), ac.lightened(0.04 * r))


func _figure(p: Vector2, body: Color, skin: Color, hair: Color = Color("#2a2a2a"), scale_f: float = 1.0) -> void:
	draw_rect(Rect2(p.x - 18 * scale_f, p.y - 40 * scale_f, 36 * scale_f, 60 * scale_f), body)
	draw_circle(Vector2(p.x, p.y - 56 * scale_f), 17 * scale_f, skin)
	draw_arc(Vector2(p.x, p.y - 59 * scale_f), 17 * scale_f, PI, TAU, 12, hair, 7 * scale_f)


func camera_for(phase: String) -> Dictionary:
	var cams: Dictionary = layout.get("cameras", {})
	var c: Dictionary = cams.get(phase, {"center": [800, 450], "zoom": 1.0})
	return {"center": _v(c["center"]), "zoom": float(c["zoom"])}
