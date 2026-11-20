class_name TitleBackdrop
extends Control
## Animated title-screen backdrop: night skyline, the (original-design)
## Mothership saucer marquee with chasing bulbs, sweeping searchlights, and a
## lone comic under a spotlight in front of a crowd.

var t: float = 0.0
var look: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	look = CharacterArt.npc_look("#6b4f8f", true, 9)
	look["hair"] = Color("#c2452d")
	look["hair_style"] = 1


func _process(delta: float) -> void:
	if not GameSettings.reduced_motion():
		t += delta
	queue_redraw()


func _glow(c: Vector2, r: float, col: Color) -> void:
	draw_texture_rect(CharacterArt.glow_texture(), Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, col)


func _draw() -> void:
	var w := size.x
	var h := size.y
	CharacterArt.vgradient(self, Rect2(0, 0, w, h * 0.75), Color("#05040f"), Color("#2a1440"))
	CharacterArt.vgradient(self, Rect2(0, h * 0.75, w, h * 0.25), Color("#120a1c"), Color("#05040a"))
	var r := RandomNumberGenerator.new()
	r.seed = 5
	for i in range(140):
		var p := Vector2(r.randf() * w, r.randf() * h * 0.5)
		draw_circle(p, r.randf_range(0.6, 1.8), Color(1, 1, 1, 0.3 + 0.3 * sin(t * 2.0 + i)))
	# Searchlights.
	for i in range(3):
		var o := Vector2(w * (0.55 + i * 0.15), h * 0.62)
		var ang := -PI * 0.5 + sin(t * 0.4 + i * 2.1) * 0.5
		var tip := o + Vector2(cos(ang), sin(ang)) * h * 1.2
		var perp := Vector2(-sin(ang), cos(ang)) * 70.0
		draw_polygon(PackedVector2Array([o, tip + perp, tip - perp]), PackedColorArray([Color(0.8, 0.7, 1.0, 0.18), Color(0.8, 0.7, 1.0, 0.0), Color(0.8, 0.7, 1.0, 0.0)]))
	# Skyline.
	var x := -20.0
	r.seed = 21
	while x < w + 20:
		var bw := r.randf_range(50, 130)
		var bh := r.randf_range(h * 0.12, h * 0.42)
		draw_rect(Rect2(x, h * 0.75 - bh, bw, bh), Color("#0e0a1c"))
		for wy in range(int(h * 0.75 - bh) + 10, int(h * 0.75) - 10, 20):
			for wx in range(int(x) + 6, int(x + bw) - 8, 14):
				if r.randf() < 0.22:
					draw_rect(Rect2(wx, wy, 5, 7), Color(1.0, 0.82, 0.45, 0.6))
		x += bw + r.randf_range(0, 14)
	# Mothership saucer marquee.
	var c := Vector2(w * 0.7, h * 0.44)
	draw_rect(Rect2(c.x - 210, c.y, 420, h * 0.29), Color("#1a1c3a"))
	_glow(c, 380, Color(0.55, 0.4, 1.0, 0.35))
	draw_set_transform(c + Vector2(0, -26), 0.0, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, 120, Color("#3a3e6a"))
	draw_circle(Vector2.ZERO, 100, Color("#5a5ea8"))
	draw_set_transform(c, 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, 300, Color("#1c1e38"))
	draw_arc(Vector2.ZERO, 300, 0, TAU, 64, Color("#b88cff"), 6.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in range(44):
		var a := TAU * i / 44
		var on := (i + int(t * 10.0)) % 4 != 0
		var bp := c + Vector2(cos(a) * 300.0, sin(a) * 66.0)
		draw_circle(bp, 4.5, Color("#fff2b0") if on else Color("#6a6040"))
		if on:
			_glow(bp, 14, Color(1.0, 0.9, 0.6, 0.4))
	# Foreground: a comic under a spotlight, crowd silhouettes.
	var stage := Vector2(w * 0.7, h * 0.9)
	draw_polygon(PackedVector2Array([stage + Vector2(-20, -h * 0.9), stage + Vector2(20, -h * 0.9), stage + Vector2(120, 0), stage + Vector2(-120, 0)]),
		PackedColorArray([Color(1, 0.95, 0.85, 0.12), Color(1, 0.95, 0.85, 0.12), Color(1, 0.95, 0.85, 0.02), Color(1, 0.95, 0.85, 0.02)]))
	_glow(stage, 160, Color(1.0, 0.9, 0.75, 0.35))
	CharacterArt.draw(self, stage, 2.0, look, {"mic_hand": true, "facing": -1.0, "expression": "smile", "bob": sin(t * 2.0) * 1.2})
	for i in range(22):
		var sx := (i + 0.5) * w / 22.0
		if absf(sx - w * 0.7) < 120:
			continue
		CharacterArt.silhouette(self, Vector2(sx, h * 0.96 + (i % 2) * 10.0), 1.5, Color("#07050c"), Color(0.8, 0.7, 1.0, 0.35))
