class_name Humanoid
extends Node3D
## 正常人比例的角色骨架（约 1.72m 高），纯代码生成、零外部资产。
## 关节层级：每个关节是一个 Node3D（命名见 joints），视觉部件是挂在其上的 BodyPart。
##
## 关节命名（IK / 换装都靠这些名字取关节）：
##   hips spine chest neck head
##   shoulder_l upperarm_l forearm_l hand_l  (右: _r)
##   hip_l thigh_l shin_l foot_l            (右: _r)
##
## 约定：每个关节节点的局部 +Y 指向它的子关节（骨头沿 +Y 伸展）。

const SKIN := Color(0.96, 0.78, 0.64)
const OUTFIT := Color(0.30, 0.46, 0.85)
const BOOT := Color(0.30, 0.25, 0.22)
const HAIR := Color(0.25, 0.20, 0.18)

var joints := {}   # name -> Node3D
var parts := {}    # name -> BodyPart

func _init() -> void:
	_build()

func joint(name: String) -> Node3D:
	return joints[name]

func part(name: String) -> BodyPart:
	return parts[name]

# ---------------- 构建 ----------------

func _build() -> void:
	# --- 躯干 ---
	var hips := _joint("hips", self, Vector3(0, 0.98, 0))
	var spine := _joint("spine", hips, Vector3(0, 0.20, 0))
	var chest := _joint("chest", spine, Vector3(0, 0.20, 0))
	var neck := _joint("neck", chest, Vector3(0, 0.14, 0))
	var head := _joint("head", neck, Vector3(0, 0.09, 0))

	# --- 手臂（左/右）---
	var shoulder_l := _joint("shoulder_l", chest, Vector3(-0.21, 0.10, 0))
	var upperarm_l := _joint("upperarm_l", shoulder_l, Vector3(0, -0.29, 0))
	var forearm_l := _joint("forearm_l", upperarm_l, Vector3(0, -0.27, 0))
	var hand_l := _joint("hand_l", forearm_l, Vector3(0, -0.11, 0))

	var shoulder_r := _joint("shoulder_r", chest, Vector3(0.21, 0.10, 0))
	var upperarm_r := _joint("upperarm_r", shoulder_r, Vector3(0, -0.29, 0))
	var forearm_r := _joint("forearm_r", upperarm_r, Vector3(0, -0.27, 0))
	var hand_r := _joint("hand_r", forearm_r, Vector3(0, -0.11, 0))

	# --- 腿（左/右）---
	var hip_l := _joint("hip_l", hips, Vector3(-0.10, 0.0, 0))
	var thigh_l := _joint("thigh_l", hip_l, Vector3(0, -0.44, 0))
	var shin_l := _joint("shin_l", thigh_l, Vector3(0, -0.41, 0))
	var foot_l := _joint("foot_l", shin_l, Vector3(0, -0.05, 0))

	var hip_r := _joint("hip_r", hips, Vector3(0.10, 0.0, 0))
	var thigh_r := _joint("thigh_r", hip_r, Vector3(0, -0.44, 0))
	var shin_r := _joint("shin_r", thigh_r, Vector3(0, -0.41, 0))
	var foot_r := _joint("foot_r", shin_r, Vector3(0, -0.05, 0))

	# --- 视觉部件 ---
	_part("pelvis", hips, 0.20, 0.14, OUTFIT)
	_part("spine_vis", spine, 0.20, 0.14, OUTFIT)
	_part("chest_vis", chest, 0.16, 0.17, OUTFIT)
	_part("neck_vis", neck, 0.10, 0.055, SKIN)

	# 头（球体），放高一点做"正常头型"
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.125
	head_mesh.height = 0.26
	var head_part := BodyPart.create("head", head_mesh, SKIN)
	head_part.position = Vector3(0, 0.10, 0.0)
	head.add_child(head_part)
	parts["head"] = head_part
	# 头发（简单盖在头顶）
	var hair_mesh := SphereMesh.new()
	hair_mesh.radius = 0.13
	hair_mesh.height = 0.14
	var hair_part := BodyPart.create("hair", hair_mesh, HAIR)
	hair_part.position = Vector3(0, 0.175, 0.0)
	head.add_child(hair_part)
	parts["hair"] = hair_part

	_part("upperarm_l_vis", upperarm_l, 0.29, 0.055, OUTFIT)
	_part("forearm_l_vis", forearm_l, 0.27, 0.045, OUTFIT)
	_part("upperarm_r_vis", upperarm_r, 0.29, 0.055, OUTFIT)
	_part("forearm_r_vis", forearm_r, 0.27, 0.045, OUTFIT)

	# 手（拳头方块）
	_add_box_part("hand_l", hand_l, Vector3(0, -0.05, 0), Vector3(0.075, 0.10, 0.05), SKIN)
	_add_box_part("hand_r", hand_r, Vector3(0, -0.05, 0), Vector3(0.075, 0.10, 0.05), SKIN)

	_part("thigh_l_vis", thigh_l, 0.44, 0.085, OUTFIT)
	_part("shin_l_vis", shin_l, 0.41, 0.06, OUTFIT)
	_part("thigh_r_vis", thigh_r, 0.44, 0.085, OUTFIT)
	_part("shin_r_vis", shin_r, 0.41, 0.06, OUTFIT)

	# 脚（鞋子方块，向前伸出）
	_add_box_part("foot_l", foot_l, Vector3(0.0, -0.035, 0.10), Vector3(0.10, 0.07, 0.24), BOOT)
	_add_box_part("foot_r", foot_r, Vector3(0.0, -0.035, 0.10), Vector3(0.10, 0.07, 0.24), BOOT)

	# 眼睛（给"正常头"加两颗小眼球，方便看朝向）
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.1, 0.1, 0.12)
	var eye := MeshInstance3D.new()
	var eye_sphere := SphereMesh.new()
	eye_sphere.radius = 0.015
	eye_sphere.height = 0.03
	eye.mesh = eye_sphere
	eye.material_override = eye_mat
	eye.position = Vector3(0.05, 0.115, 0.115)
	head.add_child(eye)
	var eye2 := eye.duplicate()
	eye2.position.x = -0.05
	head.add_child(eye2)

# ---------------- 小工具 ----------------

func _joint(name: String, parent: Node3D, local_pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = local_pos
	parent.add_child(n)
	joints[name] = n
	return n

## 胶囊部件：从关节原点沿局部 -Y 伸展 length，跨度 0..-(len+2r)，两端帽盖遮住关节。
func _part(name: String, joint: Node3D, length: float, radius: float, color: Color) -> BodyPart:
	var cap := CapsuleMesh.new()
	cap.radius = radius
	cap.height = length + radius * 2.0
	var p := BodyPart.create(name, cap, color)
	p.position = Vector3(0, -length / 2.0 - radius, 0)
	joint.add_child(p)
	parts[name] = p
	return p

func _add_box_part(name: String, joint: Node3D, local_pos: Vector3, size: Vector3, color: Color) -> BodyPart:
	var box := BoxMesh.new()
	box.size = size
	var p := BodyPart.create(name, box, color)
	p.position = local_pos
	joint.add_child(p)
	parts[name] = p
	return p
