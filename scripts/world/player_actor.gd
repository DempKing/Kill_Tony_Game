class_name PlayerActor
extends Node2D
## The player's character in the district. Simple drawn placeholder using the
## appearance chosen at character creation. Movement is free (no time cost);
## collisions keep the player out of building footprints.

const SPEED := 340.0

var appearance: Dictionary = {}
var colors: Dictionary = {}
var has_bag: bool = false
var blocked: Array = []      # Rect2 list
var bounds := Rect2(0, 0, 2600, 1200)
var input_enabled: bool = true
var _bob: float = 0.0


func configure(db: ContentDB, s: GameState) -> void:
	appearance = s.player.get("appearance", {})
	var ap: Dictionary = db.appearance
	colors = {
		"skin": Color(str(ap.get("skin", ["#d9a77f"])[int(appearance.get("skin", 0)) % ap.get("skin", ["#d9a77f"]).size()])),
		"hair": Color(str(ap.get("hair", ["#222222"])[int(appearance.get("hair", 0)) % ap.get("hair", ["#222222"]).size()])),
		"outfit": Color(str(ap.get("outfit", ["#3a5f8f"])[int(appearance.get("outfit", 0)) % ap.get("outfit", ["#3a5f8f"]).size()])),
	}
	has_bag = s.flags.has("has_bag")
	queue_redraw()


func _process(delta: float) -> void:
	if not input_enabled:
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir.length() > 0.01:
		var step := dir * SPEED * delta
		var next := position + Vector2(step.x, 0)
		if not _hits(next):
			position = next
		next = position + Vector2(0, step.y)
		if not _hits(next):
			position = next
		position = position.clamp(bounds.position + Vector2(20, 20), bounds.end - Vector2(20, 20))
		_bob += delta * 10.0
		queue_redraw()


func _hits(p: Vector2) -> bool:
	var box := Rect2(p - Vector2(14, 10), Vector2(28, 20))
	for r in blocked:
		if (r as Rect2).intersects(box):
			return true
	return false


func _draw() -> void:
	var bob := 0.0 if GameSettings.reduced_motion() else sin(_bob) * 2.0
	draw_circle(Vector2(0, 8), 16, Color(0, 0, 0, 0.3))
	draw_rect(Rect2(-12, -30 + bob, 24, 34), colors.get("outfit", Color.SLATE_BLUE))
	draw_circle(Vector2(0, -42 + bob), 13, colors.get("skin", Color.TAN))
	draw_arc(Vector2(0, -44 + bob), 13, PI, TAU, 12, colors.get("hair", Color.BLACK), 7)
	if has_bag:
		draw_rect(Rect2(10, -22 + bob, 12, 18), Color("#6b4a2a"))
	draw_colored_polygon(PackedVector2Array([Vector2(-6, -70), Vector2(6, -70), Vector2(0, -62)]), Color("#ffe27a"))
