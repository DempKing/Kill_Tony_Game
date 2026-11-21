class_name ModelLib
extends RefCounted
## Loads CC0 Poly Haven glTF models from assets/models/polyhaven/<id>/.
## Some Poly Haven files bundle variants (aged/rusty copies, kits laid out
## side by side), so callers can keep only the named mesh nodes; the
## result is re-centered so its base sits at the origin.

const DIR := "res://assets/models/polyhaven/"
static var _scenes: Dictionary = {}


static func _scene(id: String) -> PackedScene:
	if not _scenes.has(id):
		var p := "%s%s/%s_1k.gltf" % [DIR, id, id]
		_scenes[id] = load(p) if ResourceLoader.exists(p) else null
	return _scenes[id]


static func available(id: String) -> bool:
	return _scene(id) != null


## Returns a Node3D wrapper, or null when the model is missing.
## keep: exact mesh node names to keep (empty = keep everything).
static func instance(id: String, keep: Array = [], scale_f: float = 1.0) -> Node3D:
	var ps := _scene(id)
	if ps == null:
		return null
	var inner: Node3D = ps.instantiate()
	if not keep.is_empty():
		for child in _all_children(inner):
			if child is MeshInstance3D:
				if not keep.has(str(child.name)):
					(child as MeshInstance3D).visible = false
	var wrap := Node3D.new()
	wrap.name = id
	wrap.add_child(inner)
	# Re-center: base at y=0, centered in x/z.
	var box := _visible_aabb(inner)
	if box.size != Vector3.ZERO:
		inner.position = Vector3(-box.get_center().x, -box.position.y, -box.get_center().z)
	wrap.scale = Vector3.ONE * scale_f
	return wrap


static func _all_children(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		out.append(c)
		out.append_array(_all_children(c))
	return out


static func _visible_aabb(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for c in _all_children(root):
		if c is MeshInstance3D and (c as MeshInstance3D).visible and (c as MeshInstance3D).mesh != null:
			var mi := c as MeshInstance3D
			var xf := _relative_transform(root, mi)
			var b := xf * mi.mesh.get_aabb()
			if first:
				box = b
				first = false
			else:
				box = box.merge(b)
	return box


static func _relative_transform(root: Node3D, n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf
