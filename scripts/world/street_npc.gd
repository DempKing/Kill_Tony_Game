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
var look: Dictionary = {}
var facing: float = 1.0
var _last_x: float = 0.0


func setup(id: String, npc: Dictionary) -> StreetNpc:
	npc_id = id
	var full := str(npc.get("name", id))
	display_name = full.split("'")[1] if full.count("'") >= 2 else full.split(" ")[0]
	body_color = Color(str(npc.get("color", "#888888")))
	long_hair = str(npc.get("gender", "")) == "female"
	look = CharacterArt.npc_look(str(npc.get("color", "#888888")), long_hair, id.length() * 7 + id.unicode_at(0))
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
	if absf(position.x - _last_x) > 0.5:
		facing = signf(position.x - _last_x)
	_last_x = position.x
	queue_redraw()


func _draw() -> void:
	var moving := _tween != null and _tween.is_running()
	var phase := _t * 10.0 if moving and not GameSettings.reduced_motion() else 0.0
	var idle := 0.0 if GameSettings.reduced_motion() else sin(_t * 1.6 + position.x) * 0.8
	CharacterArt.draw(self, Vector2(0, 8), 1.0, look, {"walk": phase, "bob": idle, "facing": facing, "expression": "smile"})
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-50, -66) + Vector2(1, 1), display_name, HORIZONTAL_ALIGNMENT_CENTER, 100, 15, Color(0, 0, 0, 0.7))
	draw_string(font, Vector2(-50, -66), display_name, HORIZONTAL_ALIGNMENT_CENTER, 100, 15, body_color.lightened(0.35))
