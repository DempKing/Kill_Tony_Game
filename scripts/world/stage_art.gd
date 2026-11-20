class_name StageArt
extends Node2D
## Generic club stage (open mic, showcase, late show, secret show): backdrop,
## spotlight, mic, the player, the light, and an audience that reacts.

var stage: Dictionary = {}
var player_colors: Dictionary = {}
var audience_size: int = 30
var reaction: float = 0.0     # -1 silence .. 1 applause
var light_on: bool = false
var t: float = 0.0
var reduced: bool = false
var production: String = ""   # arena production level
var player_look: Dictionary = {}
var show_light: bool = true


func _process(delta: float) -> void:
	t += delta
	reaction = move_toward(reaction, 0.0, delta * 0.35)
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var back := Color(str(stage.get("backdrop", "#2a1a10")))
	var light := Color(str(stage.get("light", "#ffcf8a")))
	var floor_c := Color(str(stage.get("floor", "#1a1008")))
	var style: String = str(stage.get("style", "dive"))
	CharacterArt.vgradient(self, Rect2(0, 0, 1600, 900), back.darkened(0.3), back.darkened(0.75))
	match style:
		"lantern":
			_draw_lantern(back, light)
		"cellar":
			_draw_cellar(back, light)
		"secret":
			_draw_secret(back, light)
		"road_club":
			_draw_road_club(back, light)
		"theater":
			_draw_theater(back, light)
		"arena":
			_draw_arena(back, light)
		_:
			_draw_dive(back, light)
	# Sign.
	var sign_text := str(stage.get("sign", ""))
	var fs := 54
	while fs > 18 and font.get_string_size(sign_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > 560:
		fs -= 2
	var sign_col := Color(light, 0.75 + 0.25 * sin(t * 3.0)) if style == "cellar" and not reduced else light
	for o in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, 2), Vector2(0, -2)]:
		draw_string(font, Vector2(520, 170) + o, sign_text, HORIZONTAL_ALIGNMENT_CENTER, 560, fs, Color(sign_col, 0.18))
	draw_string(font, Vector2(520, 170), sign_text, HORIZONTAL_ALIGNMENT_CENTER, 560, fs, sign_col.lightened(0.2))
	# Stage: riser with a lip and footlights.
	CharacterArt.vgradient(self, Rect2(260, 560, 1080, 70), floor_c.lightened(0.15), floor_c)
	draw_rect(Rect2(260, 560, 1080, 5), floor_c.lightened(0.35))
	draw_rect(Rect2(250, 630, 1100, 14), floor_c.darkened(0.5))
	for i in range(14):
		draw_circle(Vector2(300 + i * 76, 636), 3.0, Color(light, 0.9))
	# Spotlight: soft cone and a pool on the floor.
	var top := Vector2(800, -20)
	var cone := PackedVector2Array([top + Vector2(-30, 0), top + Vector2(30, 0), Vector2(990, 600), Vector2(610, 600)])
	draw_polygon(cone, PackedColorArray([Color(light, 0.22), Color(light, 0.22), Color(light, 0.02), Color(light, 0.02)]))
	draw_texture_rect(CharacterArt.glow_texture(), Rect2(560, 470, 480, 200), false, Color(light, 0.45))
	# Time light (open mics only).
	if show_light:
		draw_rect(Rect2(172, 236, 56, 90), Color("#1a1414"))
		draw_circle(Vector2(200, 266), 18, Color("#ff2a2a") if light_on else Color("#3a1010"))
		if light_on:
			draw_texture_rect(CharacterArt.glow_texture(), Rect2(140, 206, 120, 120), false, Color(1, 0.2, 0.2, 0.6))
		draw_string(font, Vector2(160, 312), "LIGHT ON" if light_on else "light", HORIZONTAL_ALIGNMENT_CENTER, 80, 14, Color.WHITE if light_on else Color("#806060"))
	# Stool with a water bottle, mic stand (mic is in hand), cable.
	draw_line(Vector2(1010, 520), Vector2(1000, 600), Color("#4a3a2a"), 4)
	draw_line(Vector2(1050, 520), Vector2(1060, 600), Color("#4a3a2a"), 4)
	draw_rect(Rect2(996, 512, 68, 10), Color("#6a4a2a"))
	draw_rect(Rect2(1040, 490, 10, 22), Color(0.7, 0.85, 1.0, 0.7))
	draw_line(Vector2(760, 470), Vector2(760, 600), Color("#9a9aa4"), 4)
	draw_line(Vector2(740, 600), Vector2(780, 600), Color("#9a9aa4"), 4)
	draw_line(Vector2(760, 470), Vector2(784, 452), Color("#9a9aa4"), 3)
	draw_polyline(PackedVector2Array([Vector2(840, 470), Vector2(812, 540), Vector2(790, 598), Vector2(700, 604), Vector2(560, 600)]), Color("#141414"), 3.0)
	_performer(Vector2(850, 600))
	_draw_audience(style)


func _draw_dive(back: Color, light: Color) -> void:
	for y in range(80, 560, 40):
		for x in range(0, 1600, 90):
			var off := 45 if (y / 40) % 2 == 0 else 0
			var shade := 0.04 * ((x * 7 + y * 3) % 4)
			draw_rect(Rect2(x + off, y, 84, 34), back.lightened(shade))
	CharacterArt.vgradient(self, Rect2(0, 80, 1600, 480), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.35))
	# Bar counter, stools, beer signs, string bulbs.
	CharacterArt.vgradient(self, Rect2(1180, 380, 420, 190), Color("#4a2c18"), Color("#2a1a0e"))
	draw_rect(Rect2(1180, 370, 420, 16), Color("#7a5030"))
	for i in range(6):
		draw_rect(Rect2(1200 + i * 66, 300, 14, 60), Color(0.4 + 0.1 * (i % 3), 0.25, 0.1, 0.9))
	for i in range(4):
		draw_rect(Rect2(1210 + i * 95, 470, 50, 10), Color("#202020"))
		draw_line(Vector2(1235 + i * 95, 480), Vector2(1235 + i * 95, 560), Color("#202020"), 5)
	draw_rect(Rect2(1220, 200, 140, 60), Color("#101010"))
	draw_string(ThemeDB.fallback_font, Vector2(1228, 240), "COLD BEER", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#40d0ff"))
	draw_texture_rect(CharacterArt.glow_texture(), Rect2(1180, 150, 220, 160), false, Color(0.25, 0.8, 1.0, 0.25))
	var prev := Vector2(40, 110)
	for i in range(19):
		var bp := Vector2(40 + i * 80, 110 + 18 * absf(sin(i * 0.9)))
		draw_line(prev, bp, Color("#222222"), 1.5)
		prev = bp
		draw_circle(bp, 5, Color(light, 0.95))
		draw_texture_rect(CharacterArt.glow_texture(), Rect2(bp - Vector2(18, 18), Vector2(36, 36)), false, Color(light, 0.35))


func _draw_lantern(back: Color, light: Color) -> void:
	# Red velvet curtain with folds, wall sconces.
	for x in range(240, 1360, 40):
		var c := Color("#6a1420") if (x / 40) % 2 == 0 else Color("#561018")
		draw_rect(Rect2(x, 40, 40, 520), c)
	draw_rect(Rect2(220, 30, 1160, 30), Color("#3a0a10"))
	for sx in [140, 1460]:
		draw_rect(Rect2(sx - 10, 260, 20, 40), Color("#8a6a30"))
		draw_circle(Vector2(sx, 250), 40, Color(light, 0.18))
		draw_circle(Vector2(sx, 252), 10, light)


func _draw_cellar(back: Color, light: Color) -> void:
	# Low ceiling, pipes, concrete, pink neon.
	draw_rect(Rect2(0, 0, 1600, 560), Color("#26262a"))
	for x in range(0, 1600, 160):
		draw_rect(Rect2(x, 0, 150, 560), Color("#2c2c30"))
	draw_rect(Rect2(0, 0, 1600, 70), Color("#151518"))
	for y in [80, 110]:
		draw_line(Vector2(0, y), Vector2(1600, y), Color("#5a5a60"), 10)
	draw_line(Vector2(300, 70), Vector2(300, 560), Color("#5a5a60"), 8)
	draw_rect(Rect2(540, 110, 520, 64), Color(light, 0.08))


func _draw_secret(back: Color, light: Color) -> void:
	# Dark industrial room, beams, zig-zag string lights, "no phones" sign.
	draw_rect(Rect2(0, 0, 1600, 560), Color("#0c0c14"))
	for x in range(100, 1600, 300):
		draw_rect(Rect2(x, 0, 24, 560), Color("#1c1c28"))
	draw_rect(Rect2(0, 60, 1600, 20), Color("#1c1c28"))
	var pts := PackedVector2Array()
	for i in range(17):
		pts.append(Vector2(i * 100.0, 90.0 + (30.0 if i % 2 == 0 else 0.0)))
	draw_polyline(pts, Color("#303040"), 2)
	for p in pts:
		draw_circle(p, 5, Color(light, 0.9))
	draw_rect(Rect2(1250, 300, 220, 70), Color("#202030"))
	draw_string(ThemeDB.fallback_font, Vector2(1262, 345), "NO PHONES", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("#ff6060"))


func _draw_road_club(back: Color, light: Color) -> void:
	# Corporate club: logo wall, brick veneer, neon outline.
	draw_rect(Rect2(0, 0, 1600, 560), Color("#2a1c24"))
	for x in range(0, 1600, 64):
		draw_rect(Rect2(x, 0, 60, 560), Color("#32222c"))
	draw_rect(Rect2(490, 100, 620, 80), Color("#160e14"))
	draw_rect(Rect2(490, 100, 620, 80), Color(light, 0.8), false, 3.0)
	draw_rect(Rect2(240, 250, 120, 60), Color("#101010"))
	draw_string(ThemeDB.fallback_font, Vector2(250, 290), "2-DRINK MIN", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#ffb040"))


func _draw_theater(back: Color, light: Color) -> void:
	# Proscenium arch, gold trim, balconies.
	draw_rect(Rect2(0, 0, 1600, 560), Color("#1a0c10"))
	draw_rect(Rect2(160, 30, 1280, 530), Color("#4a0c18"))
	for x in range(180, 1420, 36):
		draw_rect(Rect2(x, 40, 18, 520), Color("#5a1020"))
	draw_rect(Rect2(140, 10, 1320, 40), Color("#b08a30"))
	draw_rect(Rect2(140, 10, 40, 560), Color("#b08a30"))
	draw_rect(Rect2(1420, 10, 40, 560), Color("#b08a30"))
	for bx in [40, 1500]:
		for by in [140, 300]:
			draw_rect(Rect2(bx, by, 80, 50), Color("#3a2010"))
			draw_circle(Vector2(bx + 40, by + 20), 8, Color(light, 0.6))


func _draw_arena(back: Color, light: Color) -> void:
	# Huge black space, video screens, truss rig, light beams scaled by production.
	draw_rect(Rect2(0, 0, 1600, 560), Color("#06060c"))
	var beams := {"minimal": 2, "standard": 6, "spectacle": 12}.get(production, 6) as int
	for i in range(beams):
		var x := 100.0 + i * (1400.0 / maxf(1.0, beams - 1))
		var sway := 0.0 if reduced else sin(t * 0.8 + i) * 80.0
		var col := Color.from_hsv(fmod(0.62 + i * 0.07, 1.0), 0.6, 1.0, 0.10)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 6, 40), Vector2(x + 6, 40), Vector2(x + 140 + sway, 560), Vector2(x - 140 + sway, 560)]), col)
	draw_rect(Rect2(0, 30, 1600, 14), Color("#3a3a46"))
	if production != "minimal":
		for sx in [60, 1260]:
			draw_rect(Rect2(sx, 140, 280, 170), Color("#101828"))
			draw_rect(Rect2(sx + 8, 148, 264, 154), Color(light, 0.25))
			_draw_mini_performer(Vector2(sx + 140, 290))


func _draw_mini_performer(p: Vector2) -> void:
	draw_rect(Rect2(p.x - 16, p.y - 70, 32, 70), Color(player_colors.get("outfit", Color.SLATE_BLUE), 0.8))
	draw_circle(Vector2(p.x, p.y - 86), 16, Color(player_colors.get("skin", Color.TAN), 0.8))


func _draw_audience(style: String) -> void:
	var light := Color(str(stage.get("light", "#ffcf8a")))
	var rows := 3
	var per_row := 9
	var sc := 1.9
	var dark := Color("#0c0a10")
	match style:
		"theater":
			rows = 5
			per_row = 16
			sc = 1.2
		"arena":
			rows = 7
			per_row = 26
			sc = 0.8
		"cellar":
			sc = 2.0
	var shown := clampi(audience_size, 6, rows * per_row)
	var n := 0
	for row in range(rows):
		var y := 720.0 + row * (150.0 / rows) + (row * 8.0)
		var count := per_row + (row % 2)
		for i in range(count):
			if n >= shown:
				return
			n += 1
			var x := 1600.0 * (i + 0.5 + (0.5 if row % 2 else 0.0)) / count
			var jump := 0.0
			if not reduced and reaction > 0.2:
				jump = absf(sin(t * 9.0 + i * 1.3 + row)) * 10.0 * reaction
			var rim := Color(light, 0.55 - row * 0.05)
			CharacterArt.silhouette(self, Vector2(x, y - jump), sc * (1.0 + row * 0.06), dark.lightened(row * 0.02), rim)
	if style == "lantern":
		for i in range(6):
			var tx := 160.0 + i * 260.0
			draw_rect(Rect2(tx - 40, 800, 80, 12), Color("#2a1a10"))
			draw_circle(Vector2(tx, 792), 6, Color("#ffd070"))
			draw_texture_rect(CharacterArt.glow_texture(), Rect2(tx - 40, 752, 80, 80), false, Color(1.0, 0.8, 0.4, 0.4))


func _performer(p: Vector2) -> void:
	var bob := 0.0 if reduced else sin(t * 2.0) * 1.5
	var expr := "neutral"
	if reaction > 0.35:
		expr = "laugh"
	elif reaction > 0.1:
		expr = "smile"
	elif reaction < -0.2:
		expr = "nervous"
	var look := player_look if not player_look.is_empty() else CharacterArt.look_from(player_colors)
	CharacterArt.draw(self, p, 2.6, look, {"bob": bob, "facing": -1.0, "mic_hand": true, "expression": expr})
