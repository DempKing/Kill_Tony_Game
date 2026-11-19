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
	draw_rect(Rect2(0, 0, 1600, 900), back.darkened(0.4))
	match style:
		"lantern":
			_draw_lantern(back, light)
		"cellar":
			_draw_cellar(back, light)
		"secret":
			_draw_secret(back, light)
		_:
			_draw_dive(back, light)
	var sign_text := str(stage.get("sign", ""))
	if style == "cellar":
		draw_string(font, Vector2(560, 150), sign_text, HORIZONTAL_ALIGNMENT_CENTER, 480, 50, Color(light, 0.75 + 0.25 * sin(t * 3.0)) if not reduced else light)
	else:
		draw_string(font, Vector2(560, 120), sign_text, HORIZONTAL_ALIGNMENT_CENTER, 480, 54, light)
	draw_rect(Rect2(300, 560, 1000, 90), floor_c)
	# Spotlight cone.
	draw_colored_polygon(PackedVector2Array([Vector2(760, 0), Vector2(840, 0), Vector2(980, 600), Vector2(620, 600)]), Color(light, 0.10))
	draw_circle(Vector2(800, 590), 170, Color(light, 0.12))
	# The light (time warning). Shown as text too, so it never relies on color.
	draw_circle(Vector2(1380, 200), 22, Color("#ff3030") if light_on else Color("#401010"))
	draw_string(font, Vector2(1300, 250), "LIGHT ON" if light_on else "light", HORIZONTAL_ALIGNMENT_CENTER, 160, 18, Color.WHITE if light_on else Color("#806060"))
	# Mic stand and performer.
	draw_line(Vector2(800, 440), Vector2(800, 590), Color("#b0b0b8"), 5)
	draw_circle(Vector2(800, 436), 9, Color("#404048"))
	_performer(Vector2(860, 580))
	_draw_audience(style)


func _draw_dive(back: Color, light: Color) -> void:
	for y in range(0, 560, 40):
		for x in range(0, 1600, 90):
			var off := 45 if (y / 40) % 2 == 0 else 0
			draw_rect(Rect2(x + off, y, 84, 34), back.lightened(0.05 * ((x + y) % 3)))
	# Bar counter, stools, beer signs, string bulbs.
	draw_rect(Rect2(1180, 380, 420, 190), Color("#3a2414"))
	draw_rect(Rect2(1180, 370, 420, 16), Color("#6a4424"))
	for i in range(4):
		draw_rect(Rect2(1210 + i * 95, 470, 50, 10), Color("#202020"))
		draw_line(Vector2(1235 + i * 95, 480), Vector2(1235 + i * 95, 560), Color("#202020"), 5)
	draw_rect(Rect2(1220, 260, 140, 60), Color("#101010"))
	draw_string(ThemeDB.fallback_font, Vector2(1228, 300), "COLD BEER", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#40d0ff"))
	for i in range(14):
		var bx := 60.0 + i * 80.0
		draw_circle(Vector2(bx, 40 + 18 * sin(i * 0.9)), 6, Color(light, 0.9))


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


func _draw_audience(style: String) -> void:
	var n := clampi(audience_size, 8, 60)
	for i in range(n):
		var row := i % 3
		var x := 60.0 + (i * 997 % 1480)
		var y := 700.0 + row * 70.0
		var jump := 0.0
		if not reduced and reaction > 0.2:
			jump = absf(sin(t * 9.0 + i)) * 12.0 * reaction
		if style == "cellar":
			y -= 20.0  # standing crowd
		draw_circle(Vector2(x, y - jump), 26, Color("#0c0a10"))
		draw_rect(Rect2(x - 34, y + 14 - jump, 68, 80), Color("#0c0a10"))
	if style == "lantern":
		for i in range(6):
			var tx := 160.0 + i * 260.0
			draw_rect(Rect2(tx - 40, 790, 80, 12), Color("#2a1a10"))
			draw_circle(Vector2(tx, 782), 6, Color("#ffd070"))
			draw_circle(Vector2(tx, 782), 22, Color(1.0, 0.8, 0.4, 0.15))


func _performer(p: Vector2) -> void:
	var bob := 0.0 if reduced else sin(t * 2.0) * 2.0
	draw_rect(Rect2(p.x - 22, p.y - 120 + bob, 44, 90), player_colors.get("outfit", Color.SLATE_BLUE))
	draw_rect(Rect2(p.x - 20, p.y - 30, 16, 30), Color("#202028"))
	draw_rect(Rect2(p.x + 4, p.y - 30, 16, 30), Color("#202028"))
	draw_circle(Vector2(p.x, p.y - 142 + bob), 22, player_colors.get("skin", Color.TAN))
	draw_arc(Vector2(p.x, p.y - 146 + bob), 22, PI, TAU, 16, player_colors.get("hair", Color.BLACK), 10)
	if bool(player_colors.get("long_hair", false)):
		draw_rect(Rect2(p.x - 26, p.y - 150 + bob, 8, 40), player_colors.get("hair", Color.BLACK))
		draw_rect(Rect2(p.x + 18, p.y - 150 + bob, 8, 40), player_colors.get("hair", Color.BLACK))
	draw_line(Vector2(p.x - 20, p.y - 100 + bob), Vector2(p.x - 54, p.y - 140), player_colors.get("outfit", Color.SLATE_BLUE), 10)
