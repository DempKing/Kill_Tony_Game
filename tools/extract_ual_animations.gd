extends SceneTree
## Dev tool. Copies the animations the game uses out of Quaternius' Universal
## Animation Library (CC0) into a small AnimationLibrary resource, so the
## 7.6 MB source .glb doesn't ship. Usage (with the .glb temporarily copied
## to assets/models/quaternius/animations/_ual_tmp.glb and imported):
##   godot --headless --path . -s res://tools/extract_ual_animations.gd

const SRC := "res://assets/models/quaternius/animations/_ual_tmp.glb"
const DST := "res://assets/models/quaternius/animations/ual_basic.res"
## Godot's importer strips the "_Loop" suffix and marks those clips as looping.
const KEEP := ["Idle", "Idle_Talking", "Walk", "Walk_Formal", "Sitting_Idle", "Sitting_Talking", "Dance", "Interact"]


func _init() -> void:
	var root: Node = (load(SRC) as PackedScene).instantiate()
	var ap: AnimationPlayer = root.find_children("*", "AnimationPlayer", true, false)[0]
	print("player root: ", ap.root_node, "  path from scene root: ", root.get_path_to(ap))
	var lib := AnimationLibrary.new()
	for n in KEEP:
		var a: Animation = ap.get_animation(n)
		if a == null:
			push_error("missing " + n)
			continue
		a = a.duplicate(true)
		if n != "Interact":
			a.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation(n, a)
		print(n, " len=", a.length, " tracks=", a.get_track_count(), " first=", a.track_get_path(0))
	print(ResourceSaver.save(lib, DST, ResourceSaver.FLAG_COMPRESS))
	root.free()
	quit()
