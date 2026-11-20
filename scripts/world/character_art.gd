class_name CharacterArt
extends RefCounted
## Shared procedural character renderer (original placeholder art).
## Every person in the game - player, NPCs, panel, band, bucket comics,
## creator preview - is drawn through here so the look is consistent.
##
## look: {skin, hair, outfit, pants, long_hair, hair_style (0-4), accent}
## pose: {bob, walk (phase radians, 0 = standing), facing (1/-1),
##        mic_hand (bool), seated (bool), expression ("neutral"|"smile"|"laugh"|"nervous"|"flat")}

const HAIR_STYLES: Array = ["Short crop", "Curly", "Long", "Bun", "Buzz"]


static func look_from(colors: Dictionary, appearance: Dictionary = {}) -> Dictionary:
	var outfit: Color = colors.get("outfit", Color("#3a5f8f"))
	return {
		"skin": colors.get("skin", Color("#d9a77f")),
		"hair": colors.get("hair", Color("#2a2420")),
		"outfit": outfit,
		"pants": colors.get("pants", Color("#23232c")),
		"long_hair": bool(colors.get("long_hair", false)),
		"hair_style": int(appearance.get("hair_style", colors.get("hair_style", 2 if bool(colors.get("long_hair", false)) else 0))),
		"accent": colors.get("accent", outfit.lightened(0.35)),
	}


static func npc_look(color_hex: String, female: bool, seed_value: int) -> Dictionary:
	var skins: Array = ["#f1d2b6", "#d9a77f", "#b07a52", "#7d4f32", "#e0b090"]
	var hairs: Array = ["#1d1a18", "#5a3a22", "#a8743d", "#2a2420", "#b8b8b8"]
	var base := Color(color_hex)
	return {
		"skin": Color(skins[seed_value % skins.size()]),
		"hair": Color(hairs[(seed_value / 3) % hairs.size()]),
		"outfit": base.darkened(0.15),
		"pants": Color("#25252e"),
		"long_hair": female,
		"hair_style": (2 if seed_value % 2 == 0 else 3) if female else [0, 1, 4][seed_value % 3],
		"accent": base.lightened(0.3),
	}


## Draws a character whose feet are at `pos`. `sc` = 1.0 is ~70px tall.
static func draw(ci: CanvasItem, pos: Vector2, sc: float, look: Dictionary, pose: Dictionary = {}) -> void:
	var skin: Color = look.get("skin", Color.TAN)
	var hair: Color = look.get("hair", Color.BLACK)
	var outfit: Color = look.get("outfit", Color.SLATE_BLUE)
	var pants: Color = look.get("pants", Color("#23232c"))
	var bob := float(pose.get("bob", 0.0))
	var walk := float(pose.get("walk", 0.0))
	var facing := float(pose.get("facing", 1.0))
	var seated := bool(pose.get("seated", false))
	var outline := Color(0, 0, 0, 0.55)
	# Shadow.
	ci.draw_set_transform(pos + Vector2(0, 1) * sc, 0.0, Vector2(1.0, 0.32))
	ci.draw_circle(Vector2.ZERO, 17.0 * sc, Color(0, 0, 0, 0.32))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var hip := pos + Vector2(0, (-28.0 if not seated else -18.0) + bob) * sc
	# Legs (swing while walking).
	var swing := sin(walk) * 7.0 * sc
	if seated:
		_limb(ci, hip + Vector2(-5, 0) * sc, hip + Vector2(-5 + 14 * facing, 2) * sc + Vector2(0, 0), 6.5 * sc, pants)
		_limb(ci, hip + Vector2(5, 0) * sc, hip + Vector2(5 + 14 * facing, 2) * sc, 6.5 * sc, pants)
	else:
		_limb(ci, hip + Vector2(-5, 0) * sc, pos + Vector2(-5 * sc + swing, -3 * sc), 6.5 * sc, pants)
		_limb(ci, hip + Vector2(5, 0) * sc, pos + Vector2(5 * sc - swing, -3 * sc), 6.5 * sc, pants)
		ci.draw_rect(Rect2(pos + Vector2(-10 * sc + swing, -5 * sc), Vector2(10, 5) * sc), Color("#18161a"))
		ci.draw_rect(Rect2(pos + Vector2(0 * sc - swing, -5 * sc), Vector2(10, 5) * sc), Color("#18161a"))
	# Torso: trapezoid with shoulders, shaded side.
	var sh := hip + Vector2(0, -26) * sc
	var torso := PackedVector2Array([sh + Vector2(-13, 0) * sc, sh + Vector2(13, 0) * sc, hip + Vector2(10, 2) * sc, hip + Vector2(-10, 2) * sc])
	ci.draw_colored_polygon(torso, outfit)
	var shade := PackedVector2Array([sh + Vector2(4 * facing, 0) * sc, sh + Vector2(13 * facing, 0) * sc, hip + Vector2(10 * facing, 2) * sc, hip + Vector2(3 * facing, 2) * sc])
	ci.draw_colored_polygon(shade, outfit.darkened(0.22))
	ci.draw_polyline(PackedVector2Array([torso[0], torso[1], torso[2], torso[3], torso[0]]), outline, 1.2 * sc)
	# Collar accent.
	ci.draw_colored_polygon(PackedVector2Array([sh + Vector2(-5, 0) * sc, sh + Vector2(5, 0) * sc, sh + Vector2(0, 6) * sc]), look.get("accent", outfit.lightened(0.3)))
	# Arms.
	var arm_swing := -swing * 0.8
	var back_hand := sh + Vector2(-12 * facing + arm_swing * 0.1, 22) * sc
	_limb(ci, sh + Vector2(-12 * facing, 2) * sc, back_hand, 5.5 * sc, outfit.darkened(0.1))
	ci.draw_circle(back_hand, 3.4 * sc, skin)
	var front_hand: Vector2
	if bool(pose.get("mic_hand", false)):
		front_hand = sh + Vector2(10 * facing, -8) * sc
		_limb(ci, sh + Vector2(12 * facing, 2) * sc, front_hand, 5.5 * sc, outfit)
		ci.draw_line(front_hand, front_hand + Vector2(-4 * facing, -9) * sc, Color("#2a2a30"), 3.5 * sc)
		ci.draw_circle(front_hand + Vector2(-5 * facing, -11) * sc, 3.4 * sc, Color("#55555e"))
	else:
		front_hand = sh + Vector2(12 * facing - arm_swing * 0.1, 22) * sc
		_limb(ci, sh + Vector2(12 * facing, 2) * sc, front_hand, 5.5 * sc, outfit)
	ci.draw_circle(front_hand, 3.4 * sc, skin)
	# Neck and head.
	var head := sh + Vector2(1.5 * facing, -11) * sc
	ci.draw_rect(Rect2(sh + Vector2(-3, -5) * sc, Vector2(6, 6) * sc), skin.darkened(0.12))
	var long_hair := bool(look.get("long_hair", false))
	var style := int(look.get("hair_style", 0))
	if style == 2 or (long_hair and style != 3 and style != 4):
		# Long hair behind the head.
		ci.draw_colored_polygon(PackedVector2Array([head + Vector2(-11, -4) * sc, head + Vector2(11, -4) * sc, head + Vector2(12, 14) * sc, head + Vector2(-12, 14) * sc]), hair.darkened(0.1))
	ci.draw_set_transform(head, 0.0, Vector2(1.0, 1.1))
	ci.draw_circle(Vector2.ZERO, 10.0 * sc, skin)
	ci.draw_arc(Vector2.ZERO, 10.0 * sc, 0.0, TAU, 24, outline, 1.2 * sc)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	ci.draw_circle(head + Vector2(-9.5 * facing, 1) * sc, 2.2 * sc, skin.darkened(0.1))
	_hair(ci, head, sc, hair, style, facing)
	_face(ci, head, sc, facing, str(pose.get("expression", "neutral")))


static func _limb(ci: CanvasItem, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	ci.draw_line(a, b, col, w)
	ci.draw_circle(a, w * 0.5, col)
	ci.draw_circle(b, w * 0.5, col)


static func _hair(ci: CanvasItem, head: Vector2, sc: float, hair: Color, style: int, facing: float) -> void:
	match style:
		1:  # Curly
			for i in range(9):
				var a := PI + (float(i) / 8.0) * PI
				ci.draw_circle(head + Vector2(cos(a), sin(a) * 1.05) * 10.0 * sc, 4.2 * sc, hair)
			ci.draw_circle(head + Vector2(0, -9) * sc, 5.0 * sc, hair)
		3:  # Bun
			ci.draw_arc(head + Vector2(0, -1) * sc, 10.0 * sc, PI * 1.02, TAU * 0.99, 16, hair, 5.5 * sc)
			ci.draw_circle(head + Vector2(-3 * facing, -13) * sc, 5.0 * sc, hair)
		4:  # Buzz
			ci.draw_arc(head + Vector2(0, -1) * sc, 10.0 * sc, PI * 1.08, TAU * 0.96, 16, hair.lightened(0.15), 2.5 * sc)
		2:  # Long (front fringe)
			ci.draw_arc(head + Vector2(0, -1) * sc, 10.5 * sc, PI * 1.0, TAU, 16, hair, 6.0 * sc)
			ci.draw_rect(Rect2(head + Vector2(-12, -2) * sc, Vector2(4, 14) * sc), hair)
			ci.draw_rect(Rect2(head + Vector2(8, -2) * sc, Vector2(4, 14) * sc), hair)
		_:  # Short crop with a swoop
			ci.draw_arc(head + Vector2(0, -1) * sc, 10.0 * sc, PI * 1.02, TAU * 0.99, 16, hair, 5.0 * sc)
			ci.draw_colored_polygon(PackedVector2Array([head + Vector2(-8 * facing, -9) * sc, head + Vector2(7 * facing, -11) * sc, head + Vector2(10 * facing, -4) * sc]), hair)


static func _face(ci: CanvasItem, head: Vector2, sc: float, facing: float, expression: String) -> void:
	var eye_y := -1.0
	var ex := 3.6
	var center := head + Vector2(2.0 * facing, 0) * sc
	var eye_col := Color("#1a1418")
	if expression == "laugh":
		ci.draw_arc(center + Vector2(-ex, eye_y) * sc, 1.8 * sc, PI, TAU, 6, eye_col, 1.3 * sc)
		ci.draw_arc(center + Vector2(ex, eye_y) * sc, 1.8 * sc, PI, TAU, 6, eye_col, 1.3 * sc)
	else:
		ci.draw_circle(center + Vector2(-ex, eye_y) * sc, 1.5 * sc, eye_col)
		ci.draw_circle(center + Vector2(ex, eye_y) * sc, 1.5 * sc, eye_col)
		ci.draw_circle(center + Vector2(-ex + 0.5, eye_y - 0.5) * sc, 0.5 * sc, Color(1, 1, 1, 0.8))
		ci.draw_circle(center + Vector2(ex + 0.5, eye_y - 0.5) * sc, 0.5 * sc, Color(1, 1, 1, 0.8))
	var m := center + Vector2(0, 5) * sc
	match expression:
		"smile":
			ci.draw_arc(m + Vector2(0, -2) * sc, 3.2 * sc, 0.2, PI - 0.2, 8, Color("#5a2a2a"), 1.3 * sc)
		"laugh":
			ci.draw_circle(m, 2.8 * sc, Color("#5a1e22"))
			ci.draw_rect(Rect2(m + Vector2(-2.4, -2.8) * sc, Vector2(4.8, 1.2) * sc), Color(1, 1, 1, 0.85))
		"nervous":
			ci.draw_polyline(PackedVector2Array([m + Vector2(-3, 0) * sc, m + Vector2(-1, -1) * sc, m + Vector2(1, 0) * sc, m + Vector2(3, -1) * sc]), Color("#5a2a2a"), 1.2 * sc)
		"flat":
			ci.draw_line(m + Vector2(-2.5, 0) * sc, m + Vector2(2.5, 0) * sc, Color("#5a2a2a"), 1.2 * sc)
		_:
			ci.draw_arc(m + Vector2(0, -1.5) * sc, 2.5 * sc, 0.4, PI - 0.4, 6, Color("#5a2a2a"), 1.2 * sc)


## A seated/standing audience silhouette (head + shoulders), lit from the stage.
static func silhouette(ci: CanvasItem, pos: Vector2, sc: float, col: Color, rim: Color) -> void:
	var shoulders := PackedVector2Array([pos + Vector2(-26, 40) * sc, pos + Vector2(-22, 12) * sc, pos + Vector2(-10, 4) * sc, pos + Vector2(10, 4) * sc, pos + Vector2(22, 12) * sc, pos + Vector2(26, 40) * sc])
	ci.draw_colored_polygon(shoulders, col)
	ci.draw_circle(pos + Vector2(0, -10) * sc, 13.0 * sc, col)
	ci.draw_arc(pos + Vector2(0, -10) * sc, 13.0 * sc, PI * 1.15, PI * 1.85, 10, rim, 2.0 * sc)
	ci.draw_polyline(PackedVector2Array([pos + Vector2(-22, 12) * sc, pos + Vector2(-10, 4) * sc, pos + Vector2(10, 4) * sc, pos + Vector2(22, 12) * sc]), rim, 1.6 * sc)


## Radial glow texture shared by lamps, neon and spotlights (additive).
static var _glow: Texture2D


static func glow_texture() -> Texture2D:
	if _glow == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.45))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_glow = t
	return _glow


## Vertical gradient rectangle via per-vertex colors.
static func vgradient(ci: CanvasItem, r: Rect2, top: Color, bottom: Color) -> void:
	ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), PackedColorArray([top, top, bottom, bottom]))
