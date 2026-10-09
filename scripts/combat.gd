class_name CombatSystem
extends RefCounted
## 程序化打斗：不依赖动画剪辑，直接用 IK 目标点画出连招轨迹。
## 状态机 IDLE -> WINDUP -> STRIKE -> RECOVER，最多 3 连击。
## 每帧把"右手/左手应到达的世界坐标"写进 right_target / left_target，由 main 喂给 IK。

enum State { IDLE, WINDUP, STRIKE, RECOVER }

const WINDUP_TIME := 0.10
const STRIKE_TIME := 0.22
const RECOVER_TIME := 0.16
const HIT_RADIUS := 0.42
const COMBO_WINDOW := 0.7

signal on_hit(at: Vector3)

var humanoid: Humanoid
var root: Node3D
var state := State.IDLE
var t := 0.0
var combo := 0
var hit_this_swing := false
var idle_time := 0.0

# 每帧更新：两只手的目标世界坐标（供 IK 使用）
var right_target := Vector3.ZERO
var left_target := Vector3.ZERO

func _init(h: Humanoid, r: Node3D) -> void:
	humanoid = h
	root = r

func attack() -> void:
	match state:
		State.IDLE:
			_start_swing()
		State.RECOVER:
			if t > 0.05:
				_start_swing()
		_:
			pass  # 挥砍中不能打断

func _start_swing() -> void:
	combo = (combo % 3) + 1
	state = State.WINDUP
	t = 0.0
	hit_this_swing = false

func update(delta: float, aim: Vector3) -> void:
	t += delta
	match state:
		State.IDLE:
			idle_time += delta
			if idle_time > COMBO_WINDOW:
				combo = 0
			var sway := sin(Time.get_ticks_msec() * 0.004) * 0.03
			right_target = _rest_hand("hand_r") + Vector3(sway, 0, 0)
			left_target = _guard(aim) + Vector3(0, sway, 0)
		State.WINDUP:
			var p := clampf(t / WINDUP_TIME, 0.0, 1.0)
			right_target = _windup_pos().lerp(_windup_end(aim), smoothstep(0.0, 1.0, p))
			left_target = _guard(aim)
			if p >= 1.0:
				state = State.STRIKE
				t = 0.0
		State.STRIKE:
			var p := clampf(t / STRIKE_TIME, 0.0, 1.0)
			right_target = _swing_arc(aim, p)
			left_target = _guard(aim)
			_hit_check(aim)
			if p >= 1.0:
				state = State.RECOVER
				t = 0.0
		State.RECOVER:
			var p := clampf(t / RECOVER_TIME, 0.0, 1.0)
			right_target = _swing_arc(aim, 1.0).lerp(_rest_hand("hand_r"), smoothstep(0.0, 1.0, p))
			left_target = _guard(aim)
			if p >= 1.0:
				state = State.IDLE
				t = 0.0
				idle_time = 0.0

func _hit_check(aim: Vector3) -> void:
	if hit_this_swing:
		return
	var hand := humanoid.joint("hand_r").global_position
	if hand.distance_to(aim) < HIT_RADIUS:
		hit_this_swing = true
		on_hit.emit(aim)

# ---------------- 轨迹点 ----------------

func _fwd() -> Vector3:
	return -root.global_basis.z

func _rest_hand(hand_name: String) -> Vector3:
	var shoulder := humanoid.joint("shoulder_" + hand_name[-1]).global_position
	return shoulder + _fwd() * 0.10 + Vector3(0, -0.30, 0)

func _guard(aim: Vector3) -> Vector3:
	var chest := humanoid.joint("chest").global_position
	return chest + _fwd() * 0.38 + Vector3(0, 0.16, 0)

func _windup_pos() -> Vector3:
	var shoulder := humanoid.joint("shoulder_r").global_position
	return shoulder + _fwd() * (-0.22) + Vector3(0, 0.30, 0.18)

func _windup_end(aim: Vector3) -> Vector3:
	var shoulder := humanoid.joint("shoulder_r").global_position
	return aim + (aim - shoulder).normalized() * 0.10

func _swing_arc(aim: Vector3, p: float) -> Vector3:
	var start := _windup_pos()
	var end := _windup_end(aim)
	var eased := smoothstep(0.0, 1.0, p)
	var pos := start.lerp(end, eased)
	pos += Vector3(0, sin(p * PI) * 0.30, 0)  # 弧线
	return pos
