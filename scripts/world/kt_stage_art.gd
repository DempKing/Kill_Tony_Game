class_name KtStageArt
extends Node2D
## Dedicated Kill Tony stage blockout, driven by data/partner/kill_tony_stage_layout.json.
## Composition: comedian at the mic (center), panel seated at its desk (stage
## left), band on its own riser (stage right), audience facing the stage.
## All art is original placeholder geometry pending partner-approved
## references; it is labelled as such and is not architecturally accurate.

var layout: Dictionary = {}
var partner: Dictionary = {}
var player_colors: Dictionary = {}
var player_look: Dictionary = {}
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


func _plook() -> Dictionary:
	return player_look if not player_look.is_empty() else CharacterArt.look_from(player_colors)


func _glow(c: Vector2, r: float, col: Color) -> void:
	draw_texture_rect(CharacterArt.glow_texture(), Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, col)


func _expr(v: float) -> String:
	if v > 0.4:
		return "laugh"
	if v > 0.1:
		return "smile"
	if v < -0.3:
		return "flat"
	return "neutral"


func _draw() -> void:
	var font := ThemeDB.fallback_font
	CharacterArt.vgradient(self, Rect2(-400, -400, 2400, 1700), Color("#05040a"), Color("#0c0a18"))
	# Backdrop: deep gradient wall with vertical light ribs and a trim frame.
	var bd := _r("backdrop")
	var bdc := Color(str(layout.get("backdrop", {}).get("color", "#141430")))
	var trim := Color(str(layout.get("backdrop", {}).get("trim", "#b88cff")))
	CharacterArt.vgradient(self, bd, bdc.lightened(0.12), bdc.darkened(0.4))
	for i in range(13):
		var x := bd.position.x + 30 + i * 110
		var pulse := 0.5 + 0.5 * sin(t * 1.5 + i * 0.6) if not reduced else 0.6
		draw_polygon(PackedVector2Array([Vector2(x, bd.position.y + 150), Vector2(x + 10, bd.position.y + 150), Vector2(x + 10, bd.end.y), Vector2(x, bd.end.y)]),
			PackedColorArray([Color(trim, 0.0), Color(trim, 0.0), Color(trim, 0.18 * pulse), Color(trim, 0.18 * pulse)]))
	draw_rect(bd, trim, false, 4.0)
	draw_rect(bd.grow(8), Color(trim, 0.25), false, 2.0)
	# Signage panel (placeholder text, no logo).
	var sg: Dictionary = layout.get("signage", {})
	var sp0 := _v(sg.get("pos", [800, 130]))
	var sign_text: String = str(partner.get("show", {}).get(str(sg.get("text_key", "")), "SHOW SIGNAGE (placeholder)"))
	var sign_rect := Rect2(sp0.x - 440, sp0.y - 58, 880, 84)
	draw_rect(sign_rect, Color("#07060e"))
	draw_rect(sign_rect, Color(trim, 0.7), false, 3.0)
	_glow(sp0 + Vector2(0, -16), 360, Color(trim, 0.12))
	var glow := 1.0 if reduced else 0.85 + 0.15 * sin(t * 2.0)
	draw_string(font, sp0 - Vector2(420, 0), sign_text, HORIZONTAL_ALIGNMENT_CENTER, 840, 42, Color(Color(str(sg.get("color", "#d8c2ff"))), glow))
	draw_string(font, bd.position + Vector2(12, bd.size.y - 12), "STAGE BLOCKOUT · placeholder · not architecturally accurate", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(trim, 0.55))
	# Stage floor with a lip and footlights.
	var sf := _r("stage_floor")
	var sfc := Color(str(layout.get("stage_floor", {}).get("color", "#2a2440")))
	CharacterArt.vgradient(self, sf, sfc.lightened(0.15), sfc.darkened(0.2))
	draw_rect(Rect2(sf.position.x, sf.position.y, sf.size.x, 5), sfc.lightened(0.4))
	draw_rect(Rect2(sf.position.x - 10, sf.end.y, sf.size.x + 20, 16), Color("#0e0c18"))
	for i in range(24):
		var fp := Vector2(sf.position.x + 30 + i * (sf.size.x - 60) / 23.0, sf.end.y + 8)
		draw_circle(fp, 3.0, Color("#ffe8c0"))
		_glow(fp, 16, Color(1.0, 0.9, 0.7, 0.25))
	_draw_band()
	_draw_panel()
	# Bucket on a stand near the mic.
	var mic_pos := _v(layout.get("mic", {}).get("pos", [800, 500]))
	if show_bucket:
		var bp := mic_pos + Vector2(-170, -20)
		draw_line(bp + Vector2(0, 40), bp + Vector2(0, 100), Color("#6a6a74"), 4)
		draw_colored_polygon(PackedVector2Array([bp + Vector2(-26, -6), bp + Vector2(26, -6), bp + Vector2(20, 40), bp + Vector2(-20, 40)]), Color("#b8bcc8"))
		draw_rect(Rect2(bp + Vector2(-28, -10), Vector2(56, 6)), Color("#d8dce8"))
		for i in range(5):
			draw_rect(Rect2(bp + Vector2(-16 + i * 7, -16 - (i % 2) * 4), Vector2(6, 9)), Color("#f8f4e0"))
		draw_string(font, bp + Vector2(-26, 62), "the bucket", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#c8c8d0"))
	# Spotlight on the mic.
	var light := Color("#fff0d8")
	draw_polygon(PackedVector2Array([mic_pos + Vector2(-20, -560), mic_pos + Vector2(20, -560), mic_pos + Vector2(140, 100), mic_pos + Vector2(-140, 100)]),
		PackedColorArray([Color(light, 0.16), Color(light, 0.16), Color(light, 0.02), Color(light, 0.02)]))
	_glow(mic_pos + Vector2(0, 90), 170, Color(light, 0.35))
	# Mic stand.
	draw_line(mic_pos + Vector2(-30, -60), mic_pos + Vector2(-30, 100), Color("#b0b0b8"), 4)
	draw_line(mic_pos + Vector2(-50, 100), mic_pos + Vector2(-10, 100), Color("#b0b0b8"), 4)
	var feet := mic_pos + Vector2(20, 100)
	if guest_at_mic and not player_at_mic:
		var gl := CharacterArt.npc_look(guest_color.to_html(false), int(guest_color.g * 10.0) % 2 == 0, int(guest_color.r * 100.0))
		CharacterArt.draw(self, feet, 2.1, gl, {"mic_hand": true, "facing": -1.0, "bob": 0.0 if reduced else sin(t * 3.0) * 1.5, "expression": _expr(reaction)})
	if player_at_mic:
		CharacterArt.draw(self, feet, 2.1, _plook(), {"mic_hand": true, "facing": -1.0, "bob": 0.0 if reduced else sin(t * 2.2) * 1.5, "expression": _expr(reaction)})
	_draw_audience()


func _draw_panel() -> void:
	var font := ThemeDB.fallback_font
	var desk := _r("panel", "desk_rect")
	var seats: Array = layout.get("panel", {}).get("seats", [])
	var members: Array = layout.get("panel", {}).get("members", [])
	var chars: Dictionary = partner.get("characters", {})
	for i in range(seats.size()):
		var sp := _v(seats[i]) + Vector2(0, 20)
		var laugh := 0.0
		if not reduced and panel_reaction > 0.2:
			laugh = absf(sin(t * 8.0 + i * 1.7)) * 6.0 * panel_reaction
		var mid: String = str(members[i]) if i < members.size() else ""
		var col := Color(str(chars.get(mid, {}).get("color", "#d0d0d0")))
		draw_rect(Rect2(sp.x - 26, sp.y - 70, 52, 50), Color("#1a1626"))
		if player_at_panel_seat == i:
			CharacterArt.draw(self, sp, 1.25, _plook(), {"seated": true, "facing": 1.0, "bob": -laugh, "expression": _expr(panel_reaction)})
			draw_string(font, sp + Vector2(-70, -104), "YOU (panel guest)", HORIZONTAL_ALIGNMENT_CENTER, 140, 14, Color("#ffe27a"))
		else:
			var lk := CharacterArt.npc_look(col.to_html(false), i == 2, i * 11 + 4)
			CharacterArt.draw(self, sp, 1.25, lk, {"seated": true, "facing": 1.0, "bob": -laugh, "expression": _expr(panel_reaction)})
			draw_string(font, sp + Vector2(-72, -104), str(chars.get(mid, {}).get("display_name", "Panel")), HORIZONTAL_ALIGNMENT_CENTER, 144, 13, col)
	CharacterArt.vgradient(self, desk, Color("#3a2e4e"), Color("#1e182c"))
	draw_rect(Rect2(desk.position.x, desk.position.y, desk.size.x, 6), Color("#6a5a8a"))
	draw_rect(Rect2(desk.position.x + 10, desk.end.y - 14, desk.size.x - 20, 4), Color("#b88cff"))
	_glow(Vector2(desk.get_center().x, desk.end.y - 12), desk.size.x * 0.5, Color(0.7, 0.55, 1.0, 0.15))
	draw_string(font, desk.position + Vector2(14, desk.size.y - 22), "PANEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#e0d0ff"))
	for i in range(seats.size()):
		var mp := _v(seats[i]) + Vector2(18, 14)
		draw_line(mp, mp + Vector2(10, -26), Color("#a0a0a8"), 3)
		draw_circle(mp + Vector2(11, -28), 4, Color("#505058"))


func _draw_band() -> void:
	var font := ThemeDB.fallback_font
	var rr := _r("band", "riser_rect")
	CharacterArt.vgradient(self, rr, Color("#262040"), Color("#141024"))
	draw_rect(Rect2(rr.position.x, rr.position.y, rr.size.x, 5), Color("#4a4470"))
	draw_string(font, rr.position + Vector2(10, rr.size.y - 12), "BAND", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#aac8ff"))
	var players: Array = layout.get("band", {}).get("players", [])
	for i in range(players.size()):
		var p := _v(players[i]) + Vector2(0, 50)
		var bob := 0.0 if reduced else sin(t * 4.0 + i) * 1.5
		var lk := CharacterArt.npc_look("#3a4a7a", i == 1, i * 13 + 2)
		match i:
			0:
				CharacterArt.draw(self, p + Vector2(0, -6), 1.15, lk, {"seated": true, "bob": bob - band_cue * 6.0, "facing": -1.0, "expression": "smile"})
				draw_circle(p + Vector2(0, 2), 32, Color("#2a2a3a"))
				draw_circle(p + Vector2(0, 2), 26, Color("#c03040"))
				draw_circle(p + Vector2(0, 2), 12, Color("#e8e8f0"))
				draw_circle(p + Vector2(-38, -14), 14, Color("#3a3a4a"))
				draw_circle(p + Vector2(38, -14), 14, Color("#3a3a4a"))
				var cy := 0.0 if reduced else band_cue * 4.0
				draw_line(p + Vector2(-70, -56 + cy), p + Vector2(-30, -60 - cy), Color("#d8c050"), 4)
				draw_line(p + Vector2(30, -62 - cy), p + Vector2(72, -56 + cy), Color("#d8c050"), 4)
				draw_line(p + Vector2(-50, -58), p + Vector2(-50, 10), Color("#8a8a90"), 2)
				draw_line(p + Vector2(50, -58), p + Vector2(50, 10), Color("#8a8a90"), 2)
				if band_cue > 0.3:
					_glow(p + Vector2(-50, -58), 30, Color(1, 0.9, 0.5, 0.4 * band_cue))
			1:
				CharacterArt.draw(self, p, 1.15, lk, {"bob": bob, "facing": -1.0, "expression": "smile"})
				draw_rect(Rect2(p.x - 56, p.y - 44, 112, 14), Color("#1a1a20"))
				for k in range(14):
					draw_rect(Rect2(p.x - 54 + k * 8, p.y - 42, 7, 9), Color("#f0f0f0"))
				draw_line(p + Vector2(-40, -30), p + Vector2(-48, 0), Color("#5a5a60"), 3)
				draw_line(p + Vector2(40, -30), p + Vector2(48, 0), Color("#5a5a60"), 3)
			_:
				CharacterArt.draw(self, p, 1.15, lk, {"bob": bob, "facing": -1.0, "expression": "neutral"})
				draw_set_transform(p + Vector2(-6, -44), -0.5, Vector2.ONE)
				draw_circle(Vector2(0, 8), 13, Color("#8a4a22"))
				draw_circle(Vector2(0, -4), 10, Color("#8a4a22"))
				draw_circle(Vector2(0, 4), 4, Color("#2a1408"))
				draw_rect(Rect2(-2.5, -46, 5, 40), Color("#4a2a12"))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2(rr.end.x - 70, rr.position.y - 50, 56, 50), Color("#1a1a1a"))
	draw_rect(Rect2(rr.end.x - 64, rr.position.y - 44, 44, 30), Color("#3a3a3a"))


func _draw_audience() -> void:
	var aud: Dictionary = layout.get("audience", {})
	var row_y: Array = aud.get("row_y", [700, 760, 820])
	var counts: Array = aud.get("count_per_row", [18, 20, 22])
	var ac := Color(str(aud.get("color", "#1c1a2a")))
	for r in range(row_y.size()):
		var n: int = int(counts[r]) if r < counts.size() else 18
		for i in range(n):
			var x := 1600.0 * (i + 0.5) / n
			var y := float(row_y[r])
			var jump := 0.0
			if not reduced and reaction > 0.15:
				jump = absf(sin(t * 9.0 + i * 0.7 + r)) * 10.0 * reaction
			CharacterArt.silhouette(self, Vector2(x, y - jump), 1.2 + r * 0.12, ac.darkened(0.3 + r * 0.05), Color(0.85, 0.75, 1.0, 0.45 - r * 0.07))


func camera_for(phase: String) -> Dictionary:
	var cams: Dictionary = layout.get("cameras", {})
	var c: Dictionary = cams.get(phase, {"center": [800, 450], "zoom": 1.0})
	return {"center": _v(c["center"]), "zoom": float(c["zoom"])}
