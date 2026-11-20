class_name Character3D
extends Node3D
## Stylized low-poly 3D person built from primitives (Poly Haven has no
## people). Uses the same `look` dictionaries as CharacterArt (skin, hair,
## outfit, pants, accent, hair_style, long_hair) so the 2D creator choices
## carry over. Feet at the origin; faces +Z by default.
##
## Pose knobs (set any time): walking, seated, mic_hand, expression
## ("neutral" | "smile" | "laugh" | "nervous" | "flat"), bounce (0..1).

var look: Dictionary = {}
var walking: bool = false
var seated: bool = false
var mic_hand: bool = false
var expression: String = "neutral"
var bounce: float = 0.0
var reduced: bool = false

var _t: float = 0.0
var _hips: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _head: Node3D
var _mouth: MeshInstance3D
var _mic: Node3D
var _label: Label3D
var _built: bool = false


static func create(p_look: Dictionary, name_tag: String = "", tag_color: Color = Color.WHITE) -> Character3D:
	var c := Character3D.new()
	c.look = p_look
	c.reduced = GameSettings.reduced_motion()
	c._build()
	if name_tag != "":
		c.set_tag(name_tag, tag_color)
	return c


func _col(key: String, fallback: Color) -> Color:
	var v: Variant = look.get(key, fallback)
	return v if typeof(v) == TYPE_COLOR else Color(str(v))


func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 10
	m.rings = 4
	return m


func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 12
	m.rings = 6
	return m


func _build() -> void:
	if _built:
		return
	_built = true
	var skin := Mat3D.color(_col("skin", Color("#d9a77f")), 0.8)
	var hair_c := _col("hair", Color("#2a2420"))
	var hair := Mat3D.color(hair_c, 0.9)
	var outfit := Mat3D.color(_col("outfit", Color("#3a5f8f")), 0.8)
	var pants := Mat3D.color(_col("pants", Color("#23232c")), 0.85)
	var shoes := Mat3D.color(Color("#141216"), 0.6)
	var accent := Mat3D.color(_col("accent", Color("#cccccc")), 0.7)
	_hips = Node3D.new()
	_hips.position = Vector3(0, 0.92, 0)
	add_child(_hips)
	# Legs (pivot at hip).
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(0.1 * side, 0, 0)
		_hips.add_child(leg)
		_mesh(leg, _capsule(0.085, 0.86), pants, Vector3(0, -0.42, 0))
		_mesh(leg, BoxMesh.new(), shoes, Vector3(0, -0.86, 0.05), Vector3(0.13, 0.08, 0.26))
		if side < 0:
			_leg_l = leg
		else:
			_leg_r = leg
	# Torso.
	_mesh(_hips, _capsule(0.2, 0.72), outfit, Vector3(0, 0.36, 0), Vector3(1.0, 1.0, 0.72))
	_mesh(_hips, BoxMesh.new(), accent, Vector3(0, 0.62, 0.135), Vector3(0.12, 0.1, 0.02))
	# Arms (pivot at shoulder).
	for side in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(0.27 * side, 0.62, 0)
		_hips.add_child(arm)
		_mesh(arm, _capsule(0.065, 0.62), outfit, Vector3(0, -0.28, 0))
		_mesh(arm, _sphere(0.06), skin, Vector3(0, -0.6, 0))
		if side < 0:
			_arm_l = arm
		else:
			_arm_r = arm
	# Microphone (shown when mic_hand).
	_mic = Node3D.new()
	_mic.position = Vector3(0, -0.62, 0.04)
	_arm_r.add_child(_mic)
	_mesh(_mic, _capsule(0.022, 0.2), Mat3D.color(Color("#202024"), 0.4, 0.6), Vector3(0, 0.02, 0))
	_mesh(_mic, _sphere(0.04), Mat3D.color(Color("#5a5a64"), 0.3, 0.8), Vector3(0, 0.13, 0))
	_mic.visible = false
	# Neck and head.
	_mesh(_hips, _capsule(0.06, 0.16), skin, Vector3(0, 0.78, 0))
	_head = Node3D.new()
	_head.position = Vector3(0, 0.98, 0)
	_hips.add_child(_head)
	_mesh(_head, _sphere(0.155), skin, Vector3.ZERO, Vector3(1.0, 1.08, 1.0))
	var eye := Mat3D.color(Color("#141014"), 0.3)
	for side in [-1.0, 1.0]:
		_mesh(_head, _sphere(0.022), eye, Vector3(0.055 * side, 0.03, 0.14))
		_mesh(_head, _sphere(0.03), skin, Vector3(0.16 * side, 0.0, 0.0))
	_mouth = _mesh(_head, BoxMesh.new(), Mat3D.color(Color("#5a1e22"), 0.6), Vector3(0, -0.07, 0.145), Vector3(0.07, 0.015, 0.02))
	_build_hair(hair, hair_c)
	_apply_expression()


func _build_hair(hair: Material, hair_c: Color) -> void:
	var style := int(look.get("hair_style", 2 if bool(look.get("long_hair", false)) else 0))
	match style:
		1:  # Curly
			for i in range(10):
				var a := TAU * i / 10.0
				_mesh(_head, _sphere(0.07), hair, Vector3(cos(a) * 0.13, 0.08 + absf(sin(a)) * 0.04, sin(a) * 0.11 - 0.02))
			_mesh(_head, _sphere(0.1), hair, Vector3(0, 0.15, -0.02))
		2:  # Long
			_mesh(_head, _sphere(0.165), hair, Vector3(0, 0.04, -0.025), Vector3(1.0, 0.95, 1.0))
			_mesh(_head, BoxMesh.new(), hair, Vector3(0, -0.15, -0.09), Vector3(0.32, 0.34, 0.12))
		3:  # Bun
			_mesh(_head, _sphere(0.162), hair, Vector3(0, 0.05, -0.02), Vector3(1.0, 0.85, 1.0))
			_mesh(_head, _sphere(0.07), hair, Vector3(0, 0.2, -0.09))
		4:  # Buzz
			_mesh(_head, _sphere(0.158), Mat3D.color(hair_c.lightened(0.15), 0.95), Vector3(0, 0.035, -0.01), Vector3(1.0, 0.82, 1.0))
		_:  # Short crop
			_mesh(_head, _sphere(0.163), hair, Vector3(0, 0.055, -0.02), Vector3(1.0, 0.8, 1.0))
			_mesh(_head, BoxMesh.new(), hair, Vector3(0.03, 0.14, 0.09), Vector3(0.2, 0.05, 0.08))


func set_tag(text: String, col: Color, height: float = 2.25, size: int = 36) -> void:
	if _label == null:
		_label = Mat3D.label(self, Vector3(0, height, 0), text, size, col, true, 10)
		_label.no_depth_test = true
	_label.position.y = height
	_label.font_size = size
	_label.text = text
	_label.modulate = col


func _apply_expression() -> void:
	if _mouth == null:
		return
	match expression:
		"laugh":
			_mouth.scale = Vector3(0.08, 0.055, 0.02)
		"smile":
			_mouth.scale = Vector3(0.09, 0.02, 0.02)
		"nervous":
			_mouth.scale = Vector3(0.05, 0.012, 0.02)
		"flat":
			_mouth.scale = Vector3(0.07, 0.01, 0.02)
		_:
			_mouth.scale = Vector3(0.065, 0.015, 0.02)


func set_expression(e: String) -> void:
	if e != expression:
		expression = e
		_apply_expression()


func _process(delta: float) -> void:
	if not _built:
		return
	_t += delta
	var swing := 0.0
	if walking and not reduced:
		swing = sin(_t * 9.0) * 0.55
	if seated:
		_hips.position.y = 0.5
		_leg_l.rotation.x = -1.45
		_leg_r.rotation.x = -1.45
	else:
		_hips.position.y = 0.92 + (absf(sin(_t * 9.0)) * 0.03 if walking and not reduced else 0.0)
		_leg_l.rotation.x = swing
		_leg_r.rotation.x = -swing
	_arm_l.rotation.x = -swing * 0.8
	if mic_hand:
		_arm_r.rotation = Vector3(-1.95, 0.0, 0.35)
	else:
		_arm_r.rotation = Vector3(swing * 0.8, 0.0, 0.0)
	_mic.visible = mic_hand
	var b := 0.0
	if bounce > 0.05 and not reduced:
		b = absf(sin(_t * 8.0 + position.x)) * 0.06 * bounce
	_head.position.y = 0.98 + b
	if not reduced:
		_head.rotation.y = sin(_t * 0.7 + position.x) * 0.12
