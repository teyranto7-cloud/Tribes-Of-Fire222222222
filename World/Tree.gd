extends StaticBody3D

const Shapes = preload("res://World/Shapes.gd")
const Foliage = preload("res://Assets/Shaders/foliage.gdshader")
var tree_id: int
var hits: int = 0
var felled: bool = false
var crown: Node3D
var fall_tween: Tween
var foliage_material: ShaderMaterial
var detail_meshes: Array[GeometryInstance3D] = []
var distant_meshes: Array[GeometryInstance3D] = []

func setup(id: int, at: Vector3, size: float, tint: Color) -> void:
	tree_id = id
	position = at
	crown = Node3D.new()
	add_child(crown)
	var bark := Color("#6c503a")
	Shapes.beam(crown, Vector3(0, 0, 0), Vector3(0.12, 2.8, 0.05) * size, 0.22 * size, bark)
	Shapes.beam(crown, Vector3(0.12, 2.6, 0.05) * size, Vector3(-0.08, 4.3, 0) * size, 0.12 * size, bark.lightened(0.08))
	foliage_material = ShaderMaterial.new()
	foliage_material.shader = Foliage
	foliage_material.set_shader_parameter("tint", tint)
	for i in range(4):
		var angle := i * TAU / 4 + id * 0.7
		var end := Vector3(cos(angle) * 1.0, 3.2 + (i % 2) * 0.8, sin(angle) * 1.0) * size
		Shapes.beam(crown, Vector3(0.0, 2.1 + i * 0.18, 0) * size, end, 0.08 * size, bark)
		var leaf := Shapes.sphere(crown, (1.2 + (i % 2) * 0.2) * size, end + Vector3.UP * 0.4, tint)
		leaf.material_override = foliage_material
		leaf.scale = Vector3(1.1, 0.85 + (id % 3) * 0.12, 1.0)
	var top := Shapes.sphere(crown, 1.35 * size, Vector3(-0.1, 4.45, 0) * size, tint.lightened(0.08))
	top.material_override = foliage_material
	top.scale.y = 0.9
	for i in range(3):
		var angle := i * TAU / 3
		Shapes.beam(crown, Vector3(cos(angle) * 0.6, 0.05, sin(angle) * 0.6) * size,
			Vector3(0, 0.65, 0), 0.1 * size, bark)
	var shape := CylinderShape3D.new()
	shape.radius = 0.29 * size
	shape.height = 3.6 * size
	Shapes.collider(self, shape, Vector3(0, 1.8 * size, 0))
	for child in crown.get_children():
		if child is GeometryInstance3D:
			detail_meshes.append(child)
	# Two coarse meshes replace branches and clustered foliage at distance.
	var far_trunk := Shapes.cylinder(crown, 0.2 * size, 3.4 * size, Vector3(0, 1.7 * size, 0), bark)
	var far_crown := Shapes.sphere(crown, 1.8 * size, Vector3(0, 3.8 * size, 0), tint)
	far_crown.scale = Vector3(1.12, 1.2, 1.1)
	far_crown.material_override = foliage_material
	distant_meshes.append(far_trunk)
	distant_meshes.append(far_crown)
	set_quality(1)

func set_quality(value: int) -> void:
	var level := clampi(value, 0, 3)
	var detail_distance := float([22, 32, 45, 60][level])
	var far_distance := float([55, 75, 100, 125][level])
	for node in detail_meshes:
		node.visibility_range_end = detail_distance
		node.visibility_range_end_margin = 2.0
	for node in distant_meshes:
		node.visibility_range_begin = detail_distance
		node.visibility_range_end = far_distance
		node.visibility_range_begin_margin = 2.0
		node.visibility_range_end_margin = 2.0

func restore_cut(value: bool) -> void:
	if is_instance_valid(fall_tween):
		fall_tween.kill()
	felled = value
	hits = 0
	collision_layer = 0 if value else 1
	crown.visible = not value
	crown.rotation = Vector3.ZERO
	crown.position = Vector3.ZERO

func hit() -> bool:
	if felled:
		return false
	hits += 1
	if hits < 3:
		return false
	felled = true
	collision_layer = 0
	fall_tween = create_tween()
	fall_tween.tween_property(crown, "rotation:z", -1.45, 0.7)
	fall_tween.parallel().tween_property(crown, "position:y", -1.5, 0.8)
	fall_tween.tween_callback(func(): crown.hide())
	return true
