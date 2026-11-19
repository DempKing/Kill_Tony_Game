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
	draw_rect(Rect2(0, 0, 1600, 900), back.darkened(0.4))
	# Brick wall backdrop.
	for y in range(0, 560, 40):
		for x in range(0, 1600, 90):
			var off := 45 if (y / 40) % 2 == 0 else 0
			draw_rect(Rect2(x + off, y, 84, 34), back.lightened(0.05 * ((x + y) % 3)))
	draw_string(font, Vector2(560, 120), str(stage.get("sign", "")), HORIZONTAL_ALIGNMENT_CENTER, 480, 54, light)
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
	# Audience in the foreground, facing the stage.
	var n := clampi(audience_size, 8, 60)
	for i in range(n):
		var row := i % 3
		var x := 60.0 + (i * 997 % 1480)
		var y := 700.0 + row * 70.0
		var jump := 0.0
		if not reduced and reaction > 0.2:
			jump = absf(sin(t * 9.0 + i)) * 12.0 * reaction
		draw_circle(Vector2(x, y - jump), 26, Color("#0c0a10"))
		draw_rect(Rect2(x - 34, y + 14 - jump, 68, 80), Color("#0c0a10"))


func _performer(p: Vector2) -> void:
	var bob := 0.0 if reduced else sin(t * 2.0) * 2.0
	draw_rect(Rect2(p.x - 22, p.y - 120 + bob, 44, 90), player_colors.get("outfit", Color.SLATE_BLUE))
	draw_rect(Rect2(p.x - 20, p.y - 30, 16, 30), Color("#202028"))
	draw_rect(Rect2(p.x + 4, p.y - 30, 16, 30), Color("#202028"))
	draw_circle(Vector2(p.x, p.y - 142 + bob), 22, player_colors.get("skin", Color.TAN))
	draw_arc(Vector2(p.x, p.y - 146 + bob), 22, PI, TAU, 16, player_colors.get("hair", Color.BLACK), 10)
	draw_line(Vector2(p.x - 20, p.y - 100 + bob), Vector2(p.x - 54, p.y - 140), player_colors.get("outfit", Color.SLATE_BLUE), 10)
