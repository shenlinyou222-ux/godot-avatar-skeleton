class_name TwoBoneIK
extends RefCounted
## 解析式两骨骼 IK（两骨链 + 极向量 pole）。
## 用法：solve_chain(upper, lower, end, target, pole)
##   upper/lower/end 为关节 Node3D，本工具只改它们的旋转（不改位置）。

## 让节点的局部 +Y 轴指向 dir_world（带 up 约束；方向与 up 共线时自动换 up）。
static func align_y(node: Node3D, dir_world: Vector3, up: Vector3 = Vector3.UP) -> void:
	var d := dir_world.normalized()
	if d.length_squared() < 0.000001:
		return
	var u := up.normalized()
	if absf(d.dot(u)) > 0.95:
		# 方向与 up 共线（如腿骨竖直向下）：换一个垂直轴当 up，避免退化
		var alt := d.cross(Vector3.RIGHT)
		if alt.length_squared() < 0.001:
			alt = d.cross(Vector3.FORWARD)
		u = alt.normalized()
	# Basis.looking_at 让 -Z 指向目标；再绕 X 轴转 -90°，把 +Y 对准目标。
	node.global_basis = Basis.looking_at(d, u) * Basis(Vector3.RIGHT, -PI / 2.0)

## 解析两骨 IK：upper(肩/髋) -> lower(肘/膝) -> end(腕/踝)。
## target 为 end 要达到的世界坐标，pole 决定肘/膝的弯曲方向。
static func solve_chain(upper: Node3D, lower: Node3D, end: Node3D, target: Vector3, pole: Vector3, up: Vector3 = Vector3.UP) -> void:
	var a := upper.global_position.distance_to(lower.global_position)
	var b := lower.global_position.distance_to(end.global_position)
	var base := target - upper.global_position
	var c := base.length()
	if c < 0.0001:
		return
	# 超过最大臂展时钳制到全伸状态
	var max_reach := a + b - 0.001
	if c > max_reach:
		base = base.normalized() * max_reach
		c = max_reach
	var base_dir := base.normalized()
	var cos_a := clampf((a * a + c * c - b * b) / (2.0 * a * c), -1.0, 1.0)
	var ang_a := acos(cos_a)
	# 肘/膝所在平面的法线（由链方向和 pole 决定）
	var pole_dir := (pole - upper.global_position).normalized()
	var axis := base_dir.cross(pole_dir)
	if axis.length_squared() < 0.0001:
		axis = up.cross(base_dir)
	if axis.length_squared() < 0.0001:
		axis = Vector3.UP
	axis = axis.normalized()
	# 两个镜像解，取更靠近 pole 的那个（肘/膝自然弯向极向量一侧）
	var elbow_plus := upper.global_position + base_dir.rotated(axis, ang_a) * a
	var elbow_minus := upper.global_position + base_dir.rotated(axis, -ang_a) * a
	var elbow_pos: Vector3 = elbow_plus if elbow_plus.distance_squared_to(pole) < elbow_minus.distance_squared_to(pole) else elbow_minus
	# 上骨对齐到肘点，下骨对齐到目标，末端骨沿链方向
	align_y(upper, elbow_pos - upper.global_position, up)
	var lower_dir := target - lower.global_position
	if lower_dir.length_squared() < 0.0001:
		lower_dir = target - upper.global_position
	align_y(lower, lower_dir, up)
	align_y(end, target - end.global_position, up)
