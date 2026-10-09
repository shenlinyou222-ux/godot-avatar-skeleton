extends Node3D
## AvatarSkeleton 主场景：装配角色、相机、输入，并把 部件化 + IK + 打斗 串起来。

const SPEED := 2.2

var character: Node3D
var humanoid: Humanoid
var swapper: PartSwapper
var combat: CombatSystem
var dummy: DummyTarget
var camera_pivot: Node3D
var cam: Camera3D
var ground: StaticBody3D

var ik_enabled := true
var foot_ik := true
var move_progress := 0.0
var _frame := 0
var _auto_shot := false

func _ready() -> void:
	_auto_shot = "--shot" in OS.get_cmdline_user_args()
	_setup_environment()
	# 角色根节点（旋转=朝向）
	character = Node3D.new()
	character.name = "Character"
	add_child(character)
	humanoid = Humanoid.new()
	humanoid.name = "Humanoid"
	character.add_child(humanoid)

	swapper = PartSwapper.new(humanoid)
	combat = CombatSystem.new(humanoid, character)
	combat.on_hit.connect(_on_hit)

	dummy = DummyTarget.new()
	dummy.name = "Dummy"
	add_child(dummy)
	dummy.position = Vector3(2.2, 0, 0)

	_setup_camera()
	print("[AvatarSkeleton] ready. 操作: WASD移动 / Space攻击 / 方向键调靶子角度 / Q,E转视角 / 1,2,3套装 / G武器 / H头型 / T关/开IK / F脚部IK")

func _process(delta: float) -> void:
	_frame += 1
	_handle_movement(delta)
	combat.update(delta, aim_point())
	_face_aim(delta)
	if ik_enabled:
		_apply_arm_ik()
	_apply_foot_ik(delta)
	_apply_head_look()
	_update_camera(delta)
	if _auto_shot and _frame == 40:
		_take_shot()
		get_tree().quit()

func _take_shot() -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://preview.png")
	print("[Main] screenshot saved -> res://preview.png")

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	match event.physical_keycode:
		KEY_SPACE:
			combat.attack()
		KEY_1, KEY_2, KEY_3:
			swapper.apply_outfit([0, 1, 2][event.physical_keycode - KEY_1])
		KEY_G:
			swapper.cycle_weapon()
		KEY_H:
			swapper.cycle_head_shape()
		KEY_T:
			ik_enabled = not ik_enabled
			print("[Main] 手臂IK: ", "开" if ik_enabled else "关")
		KEY_F:
			foot_ik = not foot_ik
			print("[Main] 脚部IK: ", "开" if foot_ik else "关")
		KEY_LEFT:
			_rotate_dummy(0.35)
		KEY_RIGHT:
			_rotate_dummy(-0.35)
		KEY_Q:
			camera_pivot.rotation.y += 0.35
		KEY_E:
			camera_pivot.rotation.y -= 0.35

# ---------------- 瞄准 / 目标 ----------------

func aim_point() -> Vector3:
	return dummy.global_position + Vector3(0, 0.55, 0)

func _rotate_dummy(angle: float) -> void:
	var p := dummy.position
	var r := Vector2(p.x, p.z).rotated(angle)
	dummy.position = Vector3(r.x, 0, r.y)

func _on_hit(at: Vector3) -> void:
	dummy.hit()
	var away := (dummy.global_position - character.global_position).normalized()
	dummy.position += Vector3(away.x, 0, away.z) * 0.15
	print("[Combat] 命中! 连击=", combat.combo)

# ---------------- IK ----------------

func _apply_arm_ik() -> void:
	var fwd := -character.global_basis.z
	var pole_r := humanoid.joint("shoulder_r").global_position + fwd * (-0.20) + Vector3(0, -0.28, 0.10)
	var pole_l := humanoid.joint("shoulder_l").global_position + fwd * (-0.20) + Vector3(0, -0.28, -0.10)
	TwoBoneIK.solve_chain(
		humanoid.joint("shoulder_r"), humanoid.joint("upperarm_r"), humanoid.joint("forearm_r"),
		combat.right_target, pole_r)
	TwoBoneIK.solve_chain(
		humanoid.joint("shoulder_l"), humanoid.joint("upperarm_l"), humanoid.joint("forearm_l"),
		combat.left_target, pole_l)

func _apply_foot_ik(delta: float) -> void:
	if not foot_ik:
		return
	move_progress += delta * (SPEED if _is_moving() else 0.0)
	var fwd := -character.global_basis.z
	var pole_l := humanoid.joint("hip_l").global_position + fwd * 0.4
	var pole_r := humanoid.joint("hip_r").global_position + fwd * 0.4
	for side in ["l", "r"]:
		var hip: Node3D = humanoid.joint("hip_" + side)
		var thigh: Node3D = humanoid.joint("thigh_" + side)
		var shin: Node3D = humanoid.joint("shin_" + side)
		var foot: Node3D = humanoid.joint("foot_" + side)
		var ankle := shin.global_position
		var desired := ankle
		# 地面贴合
		var gy := _ground_y(ankle)
		desired.y = gy + 0.06
		# 走路抬腿
		var phase := 0.0 if side == "l" else PI
		var lift := maxf(0.0, sin(move_progress * 5.0 + phase)) * 0.07
		desired.y += lift
		var pole: Vector3 = pole_l if side == "l" else pole_r
		TwoBoneIK.solve_chain(hip, thigh, shin, desired, pole)
		# 脚掌保持水平（只随朝向转）
		foot.global_basis = Basis(Vector3.UP, character.rotation.y)

func _apply_head_look() -> void:
	if not ik_enabled:
		return
	var neck: Node3D = humanoid.joint("neck")
	var local := neck.to_local(aim_point())
	var yaw := atan2(local.x, -local.z)
	var pitch := atan2(local.y, Vector2(local.x, local.z).length())
	neck.rotation.y = clampf(yaw, -1.2, 1.2)
	neck.rotation.x = clampf(pitch, -0.9, 0.9)

func _ground_y(from: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 0.8)
	q.exclude = [ground.get_rid()]
	var res := space.intersect_ray(q)
	return res.position.y if not res.is_empty() else 0.0

# ---------------- 朝向 / 移动 / 相机 ----------------

func _is_moving() -> bool:
	return Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_D)

func _handle_movement(delta: float) -> void:
	var cam_fwd := -cam.global_basis.z
	cam_fwd.y = 0.0
	cam_fwd = cam_fwd.normalized()
	var cam_right := cam_fwd.cross(Vector3.UP)
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		dir += cam_fwd
	if Input.is_key_pressed(KEY_S):
		dir -= cam_fwd
	if Input.is_key_pressed(KEY_D):
		dir += cam_right
	if Input.is_key_pressed(KEY_A):
		dir -= cam_right
	character.global_position += dir.normalized() * SPEED * delta

func _face_aim(delta: float) -> void:
	var to_aim := aim_point() - character.global_position
	var target_yaw := atan2(-to_aim.x, -to_aim.z)
	character.rotation.y = lerp_angle(character.rotation.y, target_yaw, minf(1.0, delta * 8.0))

func _update_camera(delta: float) -> void:
	var offset := Vector3(0, 2.6, 5.2).rotated(Vector3.UP, camera_pivot.rotation.y)
	cam.global_position = character.global_position + offset
	cam.look_at(character.global_position + Vector3(0, 1.15, 0))

# ---------------- 环境 ----------------

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.72, 0.80, 0.92)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.82, 0.95)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.shadow_enabled = true
	add_child(sun)

	ground = StaticBody3D.new()
	ground.name = "Ground"
	var gmesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(24, 0.2, 24)
	gmesh.mesh = box
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.55, 0.62, 0.70)
	gmesh.material_override = gmat
	gmesh.position.y = -0.1
	ground.add_child(gmesh)
	var col := CollisionShape3D.new()
	var col_box := BoxShape3D.new()
	col_box.size = Vector3(24, 0.2, 24)
	col.shape = col_box
	col.position.y = -0.1
	ground.add_child(col)
	add_child(ground)

func _setup_camera() -> void:
	camera_pivot = Node3D.new()
	add_child(camera_pivot)
	cam = Camera3D.new()
	camera_pivot.add_child(cam)
