class_name CharacterView
extends Node3D
## Animated person built from a KayKit body, re-dressed with our palette.
## look = {body, skin, hair, top, bottom, shoes, accent, height}

const BODIES := {
	# body -> [scene, texture, keep meshes, cell roles {cell_index: role}]
	# roles: 1 skin, 2 hair, 3 top, 4 top (shade), 5 bottom, 6 shoes, 7 accent
	"rogue": ["Rogue", "rogue", ["Rogue_ArmLeft", "Rogue_ArmRight", "Rogue_Body", "Rogue_Head", "Rogue_LegLeft", "Rogue_LegRight"],
		{0: 1, 1: 2, 8: 4, 9: 3, 19: 5, 15: 6, 21: 4}],
	"hooded": ["Rogue_Hooded", "rogue", ["Rogue_ArmLeft", "Rogue_ArmRight", "Rogue_Body", "Rogue_Head_Hooded", "Rogue_LegLeft", "Rogue_LegRight"],
		{0: 1, 1: 2, 8: 4, 9: 3, 19: 5, 15: 6, 21: 4}],
	"mage": ["Mage", "mage", ["Mage_ArmLeft", "Mage_ArmRight", "Mage_Body", "Mage_Head", "Mage_LegLeft", "Mage_LegRight"],
		{0: 1, 1: 2, 8: 4, 9: 3, 10: 7, 17: 7, 19: 5, 15: 6, 18: 4}],
	"barbarian": ["Barbarian", "barbarian", ["Barbarian_ArmLeft", "Barbarian_ArmRight", "Barbarian_Body", "Barbarian_Head", "Barbarian_LegLeft", "Barbarian_LegRight"],
		{0: 1, 1: 2, 8: 4, 9: 3, 6: 4, 19: 5, 15: 6}],
	"knight": ["Knight", "knight", ["Knight_ArmLeft", "Knight_ArmRight", "Knight_Body", "Knight_Head", "Knight_LegLeft", "Knight_LegRight"],
		{0: 1, 1: 2, 3: 3, 11: 4, 7: 5, 6: 6, 15: 6, 8: 4}],
}

const ANIMS := {
	"idle": "Idle", "walk": "Walking_A", "reach": "Interact", "pay": "Use_Item", "work": "Interact",
	"carry": "Walking_C", "angry": "Hit_B", "happy": "Cheer", "sweep": "Use_Item", "fall": "Lie_Down",
	"sit": "Sit_Chair_Idle", "pickup": "PickUp",
}

static var _scenes := {}
static var _lums := {}
static var _shader: Shader

var body: Node3D
var anim: AnimationPlayer
var mat: ShaderMaterial
var current := ""
var basket: Node3D
var basket_items: Node3D
var carry_box: Node3D
var head_y := 1.5
var walk_speed := 1.4

func setup(look: Dictionary) -> void:
	var b: Array = BODIES[look.get("body", "rogue")]
	if not _scenes.has(b[0]): _scenes[b[0]] = load("res://assets/characters/%s.glb" % b[0])
	body = _scenes[b[0]].instantiate()
	add_child(body)
	var keep: Array = b[2]
	if _shader == null: _shader = load("res://shaders/character.gdshader")
	mat = ShaderMaterial.new()
	mat.shader = _shader
	var tex: Texture2D = load("res://assets/characters/%s_texture.png" % b[1])
	mat.set_shader_parameter("tex", tex)
	var roles := PackedInt32Array(); roles.resize(32)
	for k in b[3]: roles[k] = b[3][k]
	mat.set_shader_parameter("roles", roles)
	mat.set_shader_parameter("cell_lum", _cell_lum(b[1], tex))
	for k in ["skin", "hair", "top", "bottom", "shoes", "accent"]:
		mat.set_shader_parameter("c_" + k, look.get(k, Color.WHITE))
	mat.set_shader_parameter("c_top2", (look.get("top", Color.WHITE) as Color).darkened(0.18))
	mat.next_pass = Art.outline()
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		if not keep.has(String(mi.name)): mi.visible = false
		else: mi.material_override = mat
	var sc := 0.6 * float(look.get("height", 1.0))
	body.scale = Vector3.ONE * sc
	head_y = 2.2 * sc
	anim = body.find_child("AnimationPlayer", true, false)
	for a in ["Walking_A", "Walking_C", "Idle", "Sit_Chair_Idle"]:
		if anim.has_animation(a): anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	play("idle")

static func _cell_lum(key: String, tex: Texture2D) -> PackedFloat32Array:
	if _lums.has(key): return _lums[key]
	var img := tex.get_image()
	if img.is_compressed(): img.decompress()
	var out := PackedFloat32Array(); out.resize(32)
	var cw := img.get_width() / 8
	var ch := img.get_height() / 4
	for r in 4:
		for c in 8:
			var s := 0.0
			var n := 0
			for y in range(r * ch + 4, (r + 1) * ch - 4, 8):
				for x in range(c * cw + 4, c * cw + cw / 2, 8):
					var p := img.get_pixel(x, y)
					s += p.r * 0.299 + p.g * 0.587 + p.b * 0.114; n += 1
			out[r * 8 + c] = s / maxf(1, n)
	_lums[key] = out
	return out

func play(name: String, speed := 1.0) -> void:
	if name == current: return
	current = name
	var a: String = ANIMS.get(name, "Idle")
	if anim and anim.has_animation(a):
		anim.play(a, 0.18, speed)

func set_walk_rate(r: float) -> void:
	if anim and (current == "walk" or current == "carry"): anim.speed_scale = clampf(r, 0.5, 1.8)
	elif anim: anim.speed_scale = 1.0

func flash(v: float) -> void:
	mat.set_shader_parameter("flash", v)

# ------------------------------------------------------------ props in hands
func _hand(side := "r") -> Node3D:
	var sk: Skeleton3D = body.find_child("Skeleton3D", true, false)
	var att := BoneAttachment3D.new()
	att.bone_name = "handslot." + side
	sk.add_child(att)
	return att

func ensure_basket() -> void:
	if basket: return
	var att := _hand("r")
	basket = Node3D.new(); att.add_child(basket)
	basket.scale = Vector3.ONE / body.scale.x
	basket.position = Vector3(0, -0.12, 0)
	var red := Art.mat(Color("d6333a"), 0.55)
	Art.box(basket, Vector3(0.3, 0.14, 0.2), red, Vector3(0, -0.12, 0), 0.03)
	Art.box(basket, Vector3(0.26, 0.012, 0.16), Art.mat(Color("8f1f25")), Vector3(0, -0.05, 0), 0.0)
	for sx in [-1, 1]: Art.box(basket, Vector3(0.02, 0.16, 0.02), Art.mat(Color("2a2233")), Vector3(sx * 0.08, 0.02, 0), 0.008)
	Art.box(basket, Vector3(0.18, 0.02, 0.02), Art.mat(Color("2a2233")), Vector3(0, 0.1, 0), 0.008)
	basket_items = Node3D.new(); basket_items.position = Vector3(0, -0.07, 0); basket.add_child(basket_items)

func set_basket_items(pids: Array) -> void:
	if not basket: return
	for c in basket_items.get_children(): c.queue_free()
	for i in mini(pids.size(), 4):
		var mi := MeshInstance3D.new()
		mi.mesh = Products3D.mesh(pids[i])
		mi.material_override = Art.vcol_mat()
		mi.scale = Vector3.ONE * 0.6
		mi.position = Vector3(-0.08 + (i % 2) * 0.12, 0.0, -0.04 + (i / 2) * 0.07)
		basket_items.add_child(mi)

func set_carry(on: bool) -> void:
	if on and not carry_box:
		carry_box = Node3D.new(); add_child(carry_box)
		carry_box.position = Vector3(0, 0.62, 0.28)
		Art.box(carry_box, Vector3(0.42, 0.3, 0.34), Art.mat(Color("c99a62"), 0.9), Vector3.ZERO, 0.02)
		Art.box(carry_box, Vector3(0.07, 0.005, 0.35), Art.mat(Color("e8d7b5")), Vector3(0, 0.152, 0), 0.0)
		carry_box.get_child(0).material_overlay = null
	if carry_box: carry_box.visible = on
