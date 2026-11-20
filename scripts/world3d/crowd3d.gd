class_name Crowd3D
extends Node3D
## A seated/standing audience drawn as two MultiMeshes (bodies and heads), so
## a few hundred people cost two draw calls. Faces -Z (toward the stage).
## `reaction` (-1..1) makes them bounce when the room is laughing.

var reaction: float = 0.0
var reduced: bool = false
var _spots: Array = []       # Vector3 base positions
var _body: MultiMeshInstance3D
var _head: MultiMeshInstance3D
var _t: float = 0.0


func setup(spots: Array, body_col: Color, rim_col: Color, seated: bool = true) -> Crowd3D:
	_spots = spots
	reduced = GameSettings.reduced_motion()
	var cap := CapsuleMesh.new()
	cap.radius = 0.24
	cap.height = 0.95 if seated else 1.45
	cap.radial_segments = 8
	cap.rings = 2
	var sph := SphereMesh.new()
	sph.radius = 0.15
	sph.height = 0.32
	sph.radial_segments = 10
	sph.rings = 5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = body_col
	mat.roughness = 0.9
	mat.rim_enabled = true
	mat.rim = 1.0
	mat.rim_tint = 0.2
	mat.emission_enabled = true
	mat.emission = rim_col
	mat.emission_energy_multiplier = 0.12
	_body = _mm(cap, mat)
	_head = _mm(sph, mat)
	_update(0.0)
	return self


func _mm(mesh: Mesh, mat: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = _spots.size()
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func set_count(n: int) -> void:
	_body.multimesh.visible_instance_count = clampi(n, 0, _spots.size())
	_head.multimesh.visible_instance_count = clampi(n, 0, _spots.size())


func _update(t: float) -> void:
	var bh: float = (_body.multimesh.mesh as CapsuleMesh).height
	for i in range(_spots.size()):
		var p: Vector3 = _spots[i]
		var jump := 0.0
		if not reduced and reaction > 0.15:
			jump = absf(sin(t * 9.0 + i * 0.7)) * 0.12 * reaction
		var sway := 0.0 if reduced else sin(t * 0.6 + i) * 0.03
		var basis := Basis(Vector3.FORWARD, sway)
		_body.multimesh.set_instance_transform(i, Transform3D(basis, p + Vector3(0, bh * 0.5 + jump, 0)))
		_head.multimesh.set_instance_transform(i, Transform3D(Basis(), p + Vector3(sway * 2.0, bh + 0.17 + jump, 0)))


func _process(delta: float) -> void:
	_t += delta
	reaction = move_toward(reaction, 0.0, delta * 0.3)
	if not reduced:
		_update(_t)
