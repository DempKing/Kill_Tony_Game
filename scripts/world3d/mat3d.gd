class_name Mat3D
extends RefCounted
## Material helpers for the 3D scenes: Poly Haven CC0 surfaces (triplanar, so
## they tile on any box) and cached flat / emissive colors.

static var _cache: Dictionary = {}


static func surface(tex_id: String, tint: Color = Color.WHITE, tiles_per_meter: float = 0.5, roughness: float = 0.85) -> StandardMaterial3D:
	var key := "s|%s|%s|%.3f" % [tex_id, tint.to_html(), tiles_per_meter]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = Materials.tex(tex_id)
	m.albedo_color = tint
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * tiles_per_meter
	m.roughness = roughness
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_cache[key] = m
	return m


static func color(c: Color, roughness: float = 0.7, metallic: float = 0.0) -> StandardMaterial3D:
	var key := "c|%s|%.2f|%.2f" % [c.to_html(), roughness, metallic]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = roughness
	m.metallic = metallic
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cache[key] = m
	return m


static func glow(c: Color, energy: float = 2.0) -> StandardMaterial3D:
	var key := "g|%s|%.2f" % [c.to_html(), energy]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cache[key] = m
	return m


## Convenience: a box MeshInstance3D centered at `center`.
static func box(parent: Node3D, center: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = center
	parent.add_child(mi)
	return mi


static func label(parent: Node3D, pos: Vector3, text: String, size: int, col: Color, billboard: bool = false, outline: int = 8) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.01
	l.modulate = col
	l.outline_size = outline
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.position = pos
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED if billboard else BaseMaterial3D.BILLBOARD_DISABLED
	l.double_sided = false
	l.font = ThemeDB.fallback_font
	parent.add_child(l)
	return l
