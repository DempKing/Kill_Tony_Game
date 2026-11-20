class_name DistrictGlow
extends Node2D
## Additive light pass for the district at dusk and night: street lamps, neon
## signs, lit doorways, the Mothership marquee, headlights. Lives on its own
## CanvasLayer so the time-of-day CanvasModulate doesn't dim it.

var map: DistrictMap


func _ready() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m


func _process(_d: float) -> void:
	queue_redraw()


func _glow(center: Vector2, radius: float, col: Color) -> void:
	draw_texture_rect(CharacterArt.glow_texture(), Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, col)


func _draw() -> void:
	if map == null or map.state == null:
		return
	var block := map.state.block
	if block < 2:
		return
	var k := 1.0 if block == 2 else 1.4
	var flick := 1.0 if GameSettings.reduced_motion() else 0.9 + 0.1 * sin(map.t * 3.0)
	for p in map.lamp_positions():
		var lp: Vector2 = p
		_glow(lp + Vector2(16, -58), 34, Color(1.0, 0.85, 0.55, 0.55 * k))
		_glow(lp + Vector2(16, -10), 110, Color(1.0, 0.75, 0.45, 0.22 * k))
	for id in map.db.location_order:
		var loc: Dictionary = map.db.locations[id]
		var r := map.rect_of(loc)
		var sc := Color(str(loc.get("sign_color", "#ffffff")))
		var open := GameSim.location_open(map.db, id, block)
		if str(loc.get("kind", "")) == "hotspot":
			_glow(r.get_center(), 70, Color(sc, 0.18 * k))
			continue
		if bool(loc.get("landmark", false)):
			var c := Vector2(r.get_center().x, r.position.y + 120)
			_glow(c, 260, Color(0.6, 0.45, 1.0, 0.35 * k * flick))
			_glow(Vector2(r.get_center().x, r.position.y + 220), 200, Color(1.0, 0.85, 0.4, 0.25 * k))
			_glow(map.door_of(loc) + Vector2(0, -40), 150, Color(1.0, 0.8, 0.5, 0.35 * k))
			continue
		if r.position.y < 600.0:
			_glow(Vector2(r.get_center().x, r.end.y - 90), r.size.x * 0.6, Color(sc, 0.22 * k * flick))
		else:
			_glow(Vector2(r.position.x + r.size.x * 0.3, r.position.y + 18), r.size.x * 0.4, Color(sc, 0.2 * k * flick))
		if open:
			_glow(map.door_of(loc) + Vector2(0, -24 if r.position.y < 600.0 else 24), 60, Color(1.0, 0.8, 0.5, 0.35 * k))
	for c in map.cars:
		var cp := Vector2(float(c["x"]) + float(c["len"]), float(c["y"]))
		_glow(cp, 22, Color(1.0, 0.95, 0.75, 0.3 * k))
