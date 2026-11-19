class_name StreetNpc
extends Node2D
## A recurring NPC hanging out in front of wherever their schedule puts them.
## Walks (tweened) to the new spot when the block changes. Talkable on the street.

var npc_id: String = ""
var display_name: String = ""
var body_color := Color.GRAY
var long_hair: bool = false
var location_id: String = ""
var _tween: Tween
var _t: float = 0.0


func setup(id: String, npc: Dictionary) -> StreetNpc:
	npc_id = id
	var full := str(npc.get("name", id))
	display_name = full.split("'")[1] if full.count("'") >= 2 else full.split(" ")[0]
	body_color = Color(str(npc.get("color", "#888888")))
	long_hair = str(npc.get("gender", "")) == "female"
	return self


func walk_to(target: Vector2, animate: bool) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not animate or position.distance_to(target) < 4.0:
		position = target
		return
	var dur := clampf(position.distance_to(target) / 220.0, 0.4, 6.0)
	_tween = create_tween()
	_tween.tween_property(self, "position", target, dur)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var moving := _tween != null and _tween.is_running()
	var bob := sin(_t * 10.0) * 2.0 if moving and not GameSettings.reduced_motion() else 0.0
	draw_circle(Vector2(0, 8), 14, Color(0, 0, 0, 0.3))
	draw_rect(Rect2(-11, -28 + bob, 22, 32), body_color.darkened(0.2))
	draw_circle(Vector2(0, -40 + bob), 12, Color("#d8b898"))
	draw_arc(Vector2(0, -42 + bob), 12, PI, TAU, 10, Color("#2a2420"), 6)
	if long_hair:
		draw_rect(Rect2(-14, -44 + bob, 4, 20), Color("#2a2420"))
		draw_rect(Rect2(10, -44 + bob, 4, 20), Color("#2a2420"))
	draw_string(ThemeDB.fallback_font, Vector2(-50, -60), display_name, HORIZONTAL_ALIGNMENT_CENTER, 100, 15, body_color.lightened(0.3))
