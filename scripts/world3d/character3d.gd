class_name Character3D
extends Node3D
## A 3D person: Quaternius' CC0 Universal Base Characters (male / female body)
## animated with clips from Quaternius' CC0 Universal Animation Library.
## The base bodies come without clothes, so a shader paints the outfit from a
## baked clothing mask (shirt / pants / shoes) in the look's colors and tints
## the skin; a Quaternius hairstyle hangs off the head bone.
##
## Uses the same `look` dictionaries as the 2D CharacterArt (skin, hair,
## outfit, pants, accent, hair_style, long_hair = female body), so creator
## choices carry over. Feet at the origin; faces +Z.
##
## Pose knobs (set any time): walking, seated, mic_hand, bounce (0..1, laughs),
## anim_override ("Dance", ...). expression is kept for API compatibility;
## the base bodies have no facial rig, so laughs show as body bounce.

const DIR := "res://assets/models/quaternius/"
const ANIMS := DIR + "animations/ual_basic.res"
## Average color of the skin texture, used to re-tint it to any skin tone.
const SKIN_AVG := Color(0.65, 0.465, 0.332)
const HAIR_AVG := 0.56
const HAIR_FILES := {
	"male": ["Hair_SimpleParted", "Hair_SimpleParted", "Hair_Long", "Hair_Buns", "Hair_Buzzed"],
	"female": ["Hair_SimpleParted", "Hair_Buns", "Hair_Long", "Hair_Buns", "Hair_BuzzedFemale"],
}

static var _scenes: Dictionary = {}
static var _lib: AnimationLibrary
static var _body_shader: Shader
static var _hair_shader: Shader
static var _textures: Dictionary = {}

var look: Dictionary = {}
var walking: bool = false
var seated: bool = false
var mic_hand: bool = false
var expression: String = "neutral"
var bounce: float = 0.0
var reduced: bool = false
var anim_override: String = ""

var _body: Node3D
var _skel: Skeleton3D
var _anim: AnimationPlayer
var _label: Label3D
var _mic: Node3D
var _current: String = ""
var _t: float = 0.0
var _spine: int = -1
var _head: int = -1
var _built: bool = false


static func create(p_look: Dictionary, name_tag: String = "", tag_color: Color = Color.WHITE) -> Character3D:
	var c := Character3D.new()
	c.look = p_look
	c.reduced = GameSettings.reduced_motion()
	c._build()
	if name_tag != "":
		c.set_tag(name_tag, tag_color)
	return c


static func _scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path) if ResourceLoader.exists(path) else null
	return _scenes[path]


static func _tex(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path)
	return _textures[path]


static func _shaders() -> void:
	if _body_shader != null:
		return
	_body_shader = Shader.new()
	_body_shader.code = """
shader_type spatial;
uniform sampler2D skin_tex : source_color, filter_linear_mipmap;
uniform sampler2D mask_tex : filter_linear;
uniform vec4 skin_tint : source_color = vec4(1.0);
uniform vec4 shirt : source_color = vec4(0.3, 0.4, 0.6, 1.0);
uniform vec4 pants : source_color = vec4(0.15, 0.15, 0.18, 1.0);
uniform vec4 shoes : source_color = vec4(0.08, 0.08, 0.09, 1.0);
void fragment() {
	vec3 m = texture(mask_tex, UV).rgb;
	vec3 skin = texture(skin_tex, UV).rgb * skin_tint.rgb;
	// Soft fold shading so flat cloth colors don't look painted on.
	float fold = 0.88 + 0.12 * sin(UV.y * 180.0 + UV.x * 40.0);
	vec3 col = skin;
	col = mix(col, shirt.rgb * fold, m.r);
	col = mix(col, pants.rgb * fold, m.g);
	col = mix(col, shoes.rgb, m.b);
	ALBEDO = col;
	ROUGHNESS = mix(0.55, 0.9, max(m.r, m.g));
	SPECULAR = 0.3;
}
"""
	_hair_shader = Shader.new()
	_hair_shader.code = """
shader_type spatial;
uniform sampler2D hair_tex : source_color, filter_linear_mipmap;
uniform vec4 hair_col : source_color = vec4(0.15, 0.1, 0.08, 1.0);
uniform float avg = 0.56;
void fragment() {
	float l = dot(texture(hair_tex, UV).rgb, vec3(0.333));
	ALBEDO = hair_col.rgb * clamp(l / avg, 0.3, 1.8);
	ROUGHNESS = 0.75;
}
"""


func _col(key: String, fallback: Color) -> Color:
	var v: Variant = look.get(key, fallback)
	return v if typeof(v) == TYPE_COLOR else Color(str(v))


func _female() -> bool:
	return bool(look.get("long_hair", false)) or bool(look.get("female", false))


func _build() -> void:
	if _built:
		return
	_built = true
	_shaders()
	var g := "Female" if _female() else "Male"
	var ps := _scene(DIR + "characters/Superhero_%s_FullBody.gltf" % g)
	if ps == null:
		push_error("Character3D: missing Quaternius body")
		return
	_body = ps.instantiate()
	add_child(_body)
	_skel = _body.get_node("Armature/Skeleton3D")
	_spine = _skel.find_bone("spine_03")
	_head = _skel.find_bone("Head")
	var hair_c := _col("hair", Color("#2a2420"))
	# Body: skin + painted-on outfit.
	var bm := ShaderMaterial.new()
	bm.shader = _body_shader
	var light := "T_Superhero_Female_Light_BaseColor.png" if g == "Female" else "T_Superhero_Male_Ligh.png"
	bm.set_shader_parameter("skin_tex", _tex(DIR + "characters/" + light))
	bm.set_shader_parameter("mask_tex", _tex(DIR + "characters/T_%s_ClothesMask.png" % g))
	var skin := _col("skin", Color("#d9a77f"))
	bm.set_shader_parameter("skin_tint", Color(skin.r / SKIN_AVG.r, skin.g / SKIN_AVG.g, skin.b / SKIN_AVG.b))
	bm.set_shader_parameter("shirt", _col("outfit", Color("#3a5f8f")))
	bm.set_shader_parameter("pants", _col("pants", Color("#23232c")))
	bm.set_shader_parameter("shoes", _col("pants", Color("#23232c")).darkened(0.55))
	var hm := ShaderMaterial.new()
	hm.shader = _hair_shader
	hm.set_shader_parameter("hair_tex", _tex(DIR + "hair/T_Hair_1_BaseColor.png"))
	hm.set_shader_parameter("hair_col", hair_c)
	hm.set_shader_parameter("avg", HAIR_AVG)
	for mi in _skel.get_children():
		if mi is MeshInstance3D:
			var n := str(mi.name)
			if n == "Eyebrows":
				mi.material_override = hm
			elif n != "Eyes":
				mi.material_override = bm
	# Hair on the head bone (hair meshes are authored at their rest position).
	var styles: Array = HAIR_FILES["female" if _female() else "male"]
	var hair_id: String = styles[clampi(int(look.get("hair_style", 0)), 0, styles.size() - 1)]
	var hs := _scene(DIR + "hair/%s.gltf" % hair_id)
	if hs != null and _head >= 0:
		var att := BoneAttachment3D.new()
		att.bone_name = "Head"
		_skel.add_child(att)
		var hair: Node3D = hs.instantiate()
		hair.transform = _skel.get_bone_global_rest(_head).affine_inverse()
		att.add_child(hair)
		for mi in hair.find_children("*", "MeshInstance3D", true, false):
			var hm2 := hm.duplicate() as ShaderMaterial
			hm2.set_shader_parameter("hair_tex", _tex(DIR + "hair/T_Hair_%d_BaseColor.png" % (2 if hair_id in ["Hair_Long", "Hair_Buns"] else 1)))
			(mi as MeshInstance3D).material_override = hm2
	# Microphone in the right hand.
	var hand := BoneAttachment3D.new()
	hand.bone_name = "hand_r"
	_skel.add_child(hand)
	_mic = Node3D.new()
	hand.add_child(_mic)
	_mic.position = Vector3(0.02, 0.08, 0.04)
	_mic.rotation = Vector3(0.0, 0.0, -1.2)
	var handle := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.018
	cm.bottom_radius = 0.014
	cm.height = 0.18
	handle.mesh = cm
	handle.material_override = Mat3D.color(Color("#202024"), 0.4, 0.6)
	_mic.add_child(handle)
	var grill := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.035
	sm.height = 0.07
	grill.mesh = sm
	grill.material_override = Mat3D.color(Color("#6a6a74"), 0.3, 0.8)
	grill.position = Vector3(0, 0.11, 0)
	_mic.add_child(grill)
	_mic.visible = false
	# Animation.
	if _lib == null:
		_lib = load(ANIMS)
	_anim = AnimationPlayer.new()
	_body.add_child(_anim)
	_anim.root_node = NodePath("..")
	_anim.add_animation_library("ual", _lib)
	_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_play(_wanted(), true)


func _wanted() -> String:
	if anim_override != "":
		return anim_override
	if seated:
		return "Sitting_Talking" if bounce > 0.25 else "Sitting_Idle"
	if walking:
		return "Walk"
	if mic_hand:
		return "Idle_Talking"
	return "Idle"


func _play(n: String, instant: bool = false) -> void:
	if n == _current or _anim == null:
		return
	_current = n
	_anim.play("ual/" + n, 0.0 if instant else 0.25)
	if instant:
		# Desync identical clips across a crowd.
		_anim.seek(fmod(absf(position.x * 1.7 + position.z * 0.9 + get_instance_id() % 97 * 0.13), _anim.current_animation_length), true)


func set_tag(text: String, col: Color, height: float = 2.25, size: int = 36) -> void:
	if _label == null:
		_label = Mat3D.label(self, Vector3(0, height, 0), text, size, col, true, 10)
		_label.no_depth_test = true
	_label.position.y = height
	_label.font_size = size
	_label.text = text
	_label.modulate = col


func set_expression(e: String) -> void:
	expression = e


func _process(delta: float) -> void:
	if _anim == null:
		return
	_t += delta
	_play(_wanted())
	_mic.visible = mic_hand
	_anim.advance(0.0 if reduced and not walking else delta)
	# Laughing: a procedural bob of the upper body on top of the clip.
	if bounce > 0.05 and not reduced and _spine >= 0:
		var b := absf(sin(_t * 9.0 + position.x)) * 0.12 * bounce
		var q := _skel.get_bone_pose_rotation(_spine)
		_skel.set_bone_pose_rotation(_spine, q * Quaternion(Vector3.RIGHT, -b))
