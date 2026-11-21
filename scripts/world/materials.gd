class_name Materials
extends RefCounted
## CC0 surface textures from Poly Haven (https://polyhaven.com), downscaled to
## 256px tiles in assets/textures/polyhaven/. See docs/ASSET_APPROVALS.md.

const DIR := "res://assets/textures/polyhaven/"
static var _cache: Dictionary = {}


static func tex(id: String) -> Texture2D:
	if not _cache.has(id):
		var p := DIR + id + ".jpg"
		_cache[id] = load(p) if ResourceLoader.exists(p) else null
	return _cache[id]


## Fills `r` with a tiled texture tinted by `tint`. scale < 1 shrinks the pattern.
static func fill(ci: CanvasItem, r: Rect2, id: String, tint: Color = Color.WHITE, scale: float = 1.0) -> void:
	var t := tex(id)
	if t == null:
		ci.draw_rect(r, tint.darkened(0.3))
		return
	if ci.texture_repeat != CanvasItem.TEXTURE_REPEAT_ENABLED:
		ci.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ci.draw_set_transform(r.position, 0.0, Vector2(scale, scale))
	ci.draw_texture_rect(t, Rect2(Vector2.ZERO, r.size / scale), true, tint)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Texture plus a vertical shading gradient on top (for depth).
static func shaded(ci: CanvasItem, r: Rect2, id: String, tint: Color, scale: float = 1.0, top_light: float = 0.0, bottom_dark: float = 0.35) -> void:
	fill(ci, r, id, tint, scale)
	CharacterArt.vgradient(ci, r, Color(1, 1, 1, top_light), Color(0, 0, 0, bottom_dark))
