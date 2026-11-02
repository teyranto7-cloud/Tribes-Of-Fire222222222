extends RefCounted

static var materials: Dictionary = {}

static func material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var key := "%s:%s" % [color.to_html(), glow]
	if materials.has(key):
		return materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.86
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	materials[key] = m
	return m

static func mesh(parent: Node3D, shape: Mesh, at: Vector3, color: Color, glow: float = 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.material_override = material(color, glow)
	node.position = at
	parent.add_child(node)
	return node

static func box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return mesh(parent, shape, at, color)

static func sphere(parent: Node3D, radius: float, at: Vector3, color: Color, glow: float = 0.0) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2.0
	shape.radial_segments = 12
	shape.rings = 6
	return mesh(parent, shape, at, color, glow)

static func cylinder(parent: Node3D, radius: float, height: float, at: Vector3, color: Color) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius * 0.85
	shape.bottom_radius = radius * 1.15
	shape.height = height
	shape.radial_segments = 9
	return mesh(parent, shape, at, color)

static func collider(parent: CollisionObject3D, shape: Shape3D, at: Vector3) -> CollisionShape3D:
	var node := CollisionShape3D.new()
	node.shape = shape
	node.position = at
	parent.add_child(node)
	return node

static func beam(parent: Node3D, start: Vector3, end: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var result := cylinder(parent, radius, start.distance_to(end), (start + end) * 0.5, color)
	result.quaternion = Quaternion(Vector3.UP, (end - start).normalized())
	return result

static func consolidate(parent: Node3D) -> void:
	# Bake static local transforms, preserving every triangle and material.
	# Moving joints and collision nodes are deliberately left alone.
	var surfaces: Dictionary = {}
	var used_materials: Dictionary = {}
	var originals: Array[MeshInstance3D] = []
	for child in parent.get_children():
		if not child is MeshInstance3D or child.mesh == null:
			continue
		originals.append(child)
		for index in range(child.mesh.get_surface_count()):
			var material: Material = child.material_override if child.material_override != null else child.mesh.surface_get_material(index)
			var key: int = material.get_instance_id() if material != null else 0
			if not surfaces.has(key):
				var surface := SurfaceTool.new()
				surface.begin(Mesh.PRIMITIVE_TRIANGLES)
				surfaces[key] = surface
				used_materials[key] = material
			surfaces[key].append_from(child.mesh, index, child.transform)
	for child in originals:
		parent.remove_child(child)
		child.free()
	for key in surfaces:
		var merged := MeshInstance3D.new()
		merged.mesh = surfaces[key].commit()
		merged.material_override = used_materials[key]
		parent.add_child(merged)
