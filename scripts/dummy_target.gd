class_name DummyTarget
extends Node3D
## 练习目标：一个能被打、会闪白的假人。演示用（无物理碰撞，命中判定在 CombatSystem 里用距离算）。

const BASE_COLOR := Color(0.86, 0.62, 0.30)
const HIT_COLOR := Color(1.0, 1.0, 1.0)

var flash := 0.0
var _mat := StandardMaterial3D.new()
var _body: MeshInstance3D

func _init() -> void:
	_mat.albedo_color = BASE_COLOR
	var cap := CapsuleMesh.new()
	cap.radius = 0.26
	cap.height = 1.25
	_body = MeshInstance3D.new()
	_body.mesh = cap
	_body.material_override = _mat
	_body.position = Vector3(0, 0.63, 0)
	add_child(_body)
	var head := SphereMesh.new()
	head.radius = 0.20
	head.height = 0.40
	var head_mi := MeshInstance3D.new()
	head_mi.mesh = head
	head_mi.material_override = _mat
	head_mi.position = Vector3(0, 1.40, 0)
	add_child(head_mi)

func hit() -> void:
	flash = 0.15

func _process(delta: float) -> void:
	flash = maxf(0.0, flash - delta)
	if flash > 0.0:
		_mat.albedo_color = BASE_COLOR.lerp(HIT_COLOR, flash / 0.15)
	else:
		_mat.albedo_color = BASE_COLOR
