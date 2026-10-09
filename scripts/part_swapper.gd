class_name PartSwapper
extends RefCounted
## 部件化更换系统：换配色 / 换头型 / 装备武器盾牌。
## 演示"正常人体型 + 部件槽"的换装思路（后续可换成 UMA 式体型 DNA 或真蒙皮网格）。

var humanoid: Humanoid

# 三套配色（套装）
const PALETTES: Array = [
	{ "name": "士兵", "outfit": Color(0.30, 0.46, 0.85), "boot": Color(0.28, 0.25, 0.22) },
	{ "name": "武者", "outfit": Color(0.75, 0.18, 0.16), "boot": Color(0.12, 0.10, 0.10) },
	{ "name": "运动", "outfit": Color(0.20, 0.65, 0.35), "boot": Color(0.95, 0.95, 0.95) },
]

const OUTFIT_PARTS: Array = [
	"pelvis", "spine_vis", "chest_vis",
	"upperarm_l_vis", "forearm_l_vis", "upperarm_r_vis", "forearm_r_vis",
	"thigh_l_vis", "shin_l_vis", "thigh_r_vis", "shin_r_vis",
]
const BOOT_PARTS: Array = ["foot_l", "foot_r"]

var outfit_idx := 0
var head_shape := "sphere"
var weapon_idx := 0  # 0 none, 1 sword(r), 2 hammer(r), 3 sword(r)+shield(l)

func _init(h: Humanoid) -> void:
	humanoid = h
	apply_outfit(outfit_idx)

# ---------------- 配色 ----------------

func cycle_outfit() -> void:
	outfit_idx = (outfit_idx + 1) % PALETTES.size()
	apply_outfit(outfit_idx)

func apply_outfit(idx: int) -> void:
	var p: Dictionary = PALETTES[idx]
	for part_name in OUTFIT_PARTS:
		if humanoid.parts.has(part_name):
			humanoid.part(part_name).set_color(p["outfit"])
	for part_name in BOOT_PARTS:
		if humanoid.parts.has(part_name):
			humanoid.part(part_name).set_color(p["boot"])
	print("[PartSwapper] 套装: ", p["name"])

# ---------------- 头型 ----------------

func cycle_head_shape() -> void:
	head_shape = "box" if head_shape == "sphere" else "sphere"
	var head := humanoid.part("head")
	if head_shape == "sphere":
		var s := SphereMesh.new()
		s.radius = 0.125
		s.height = 0.26
		head.swap_mesh(s)
	else:
		var b := BoxMesh.new()
		b.size = Vector3(0.24, 0.28, 0.22)
		head.swap_mesh(b)
	print("[PartSwapper] 头型: ", head_shape)

# ---------------- 武器 / 盾牌（挂点到手） ----------------

func cycle_weapon() -> void:
	weapon_idx = (weapon_idx + 1) % 4
	_clear_held("hand_r")
	_clear_held("hand_l")
	match weapon_idx:
		1:
			_equip_weapon("hand_r", "sword")
		2:
			_equip_weapon("hand_r", "hammer")
		3:
			_equip_weapon("hand_r", "sword")
			_equip_weapon("hand_l", "shield")
	print("[PartSwapper] 装备: ", ["无", "剑", "锤", "剑+盾"][weapon_idx])

func _clear_held(hand_name: String) -> void:
	var hand := humanoid.joint(hand_name)
	for child in hand.get_children():
		if child.name.begins_with("held_"):
			child.queue_free()

func _equip_weapon(hand_name: String, kind: String) -> void:
	var hand := humanoid.joint(hand_name)
	var holder := Node3D.new()
	holder.name = "held_" + kind
	holder.position = Vector3(0, -0.04, 0)
	hand.add_child(holder)
	match kind:
		"sword":
			holder.add_child(_box(Vector3(0.045, 0.48, 0.02), Vector3(0, 0.34, 0), Color(0.85, 0.87, 0.92)))
			holder.add_child(_box(Vector3(0.13, 0.02, 0.05), Vector3(0, 0.10, 0), Color(0.55, 0.42, 0.25)))
			holder.add_child(_box(Vector3(0.03, 0.10, 0.03), Vector3(0, 0.02, 0), Color(0.4, 0.28, 0.18)))
		"hammer":
			holder.add_child(_cyl(0.025, 0.30, Vector3(0, 0.12, 0), Color(0.55, 0.42, 0.25)))
			holder.add_child(_box(Vector3(0.20, 0.14, 0.12), Vector3(0, 0.30, 0), Color(0.35, 0.36, 0.40)))
		"shield":
			holder.add_child(_box(Vector3(0.34, 0.44, 0.06), Vector3(0, 0.05, 0.09), Color(0.30, 0.50, 0.80)))

func _box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	m.material_override = mat
	m.position = pos
	return m

func _cyl(radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.radius = radius
	cm.height = height
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	m.material_override = mat
	m.position = pos
	return m
