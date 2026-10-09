class_name BodyPart
extends Node3D
## 单个身体部件节点：一个挂点 + 一个可替换的 Mesh。
## 部件化更换的最小单元 —— 换 mesh / 换色都在这一个类上完成。

var slot_id: String = ""
var mesh_inst: MeshInstance3D
var material: StandardMaterial3D

static func create(slot: String, mesh: Mesh, color: Color) -> BodyPart:
	var p := BodyPart.new()
	p.slot_id = slot
	p.material = StandardMaterial3D.new()
	p.material.albedo_color = color
	p.mesh_inst = MeshInstance3D.new()
	p.mesh_inst.mesh = mesh
	p.mesh_inst.material_override = p.material
	p.add_child(p.mesh_inst)
	return p

func set_color(c: Color) -> void:
	material.albedo_color = c

func swap_mesh(m: Mesh) -> void:
	mesh_inst.mesh = m
