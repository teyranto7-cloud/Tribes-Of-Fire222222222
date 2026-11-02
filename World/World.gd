extends Node3D

const Shapes = preload("res://World/Shapes.gd")
const TreeScript = preload("res://World/Tree.gd")
const FireScript = preload("res://Building/Campfire.gd")
const ShelterScript = preload("res://Building/Shelter.gd")
const Foliage = preload("res://Assets/Shaders/foliage.gdshader")
const WaterShader = preload("res://Assets/Shaders/water.gdshader")
const SEED := 1337
const TREE_COUNT := 160
const LIMIT := 60.0

var trees: Array = []
var fires: Array[Node3D] = []
var shelters: Array[Node3D] = []
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var environment: Environment
var sky_material: ProceduralSkyMaterial
var preview: MeshInstance3D
var quality: int = 1
var grass: MultiMeshInstance3D
var grass_material: ShaderMaterial
var weather: Dictionary = {"rain": 0.0, "cloud": 0.0, "wind": 0.2, "fog": 0.0, "lightning": 0.0}
var rain_mesh: MultiMeshInstance3D
var rain_drops: Array[Dictionary] = []
var rain_rng := RandomNumberGenerator.new()
var rain_audio: AudioStreamPlayer
var thunder_audio: AudioStreamPlayer
var last_lightning: float = 0.0
var thunder_delay: float = -1.0
var rain_focus: Vector3 = Vector3.ZERO
var rain_enabled: bool = true
var water_material: ShaderMaterial
var reflection_probe: ReflectionProbe
var generated: bool = false
var generation_cancelled: bool = false
var last_daylight: float = 1.0
var last_wind: float = -1.0
var graphics_config: Dictionary = {}
var cloud_mesh: MeshInstance3D

static func height_at(x: float, z: float) -> float:
	return sin(x * 0.052) * 1.6 + cos(z * 0.047) * 1.4 + sin((x + z) * 0.031) * 0.8

func generate(progress: Callable) -> void:
	generation_cancelled = false
	setup_environment()
	for z in range(-4, 4):
		for x in range(-4, 4):
			make_chunk(x * 16, z * 16)
		progress.call("Terreno / Terrain %d%%" % int((z + 5) / 8.0 * 65.0))
		await get_tree().process_frame
		if generation_cancelled:
			return
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for i in range(TREE_COUNT):
		var p := Vector3(rng.randf_range(-58, 58), 0, rng.randf_range(-58, 58))
		while Vector2(p.x, p.z).length() < 7.0:
			p = Vector3(rng.randf_range(-58, 58), 0, rng.randf_range(-58, 58))
		if i < 3:
			p = [Vector3(3, 0, -3), Vector3(-3, 0, -3), Vector3(0, 0, -6)][i]
		p.y = height_at(p.x, p.z)
		var tree = TreeScript.new()
		add_child(tree)
		tree.setup(i, p, rng.randf_range(0.85, 1.35), Color("#2e6043").lerp(Color("#577c48"), rng.randf()))
		trees.append(tree)
		if i % 16 == 0:
			progress.call("Floresta / Forest %d%%" % (65 + int(i / 160.0 * 30)))
			await get_tree().process_frame
			if generation_cancelled:
				return
	make_scenery()
	make_grass()
	make_rain()
	var shape := CylinderMesh.new()
	shape.top_radius = 0.7
	shape.bottom_radius = 0.7
	shape.height = 0.15
	preview = MeshInstance3D.new()
	preview.mesh = shape
	preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 1.0, 0.55, 0.45)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	preview.material_override = m
	add_child(preview)
	preview.hide()
	generated = true
	set_quality(quality)
	progress.call("Pronto / Ready")

func cancel_generation() -> void:
	generation_cancelled = true

func make_chunk(x0: int, z0: int) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(8):
		for x in range(8):
			var a := Vector2(x0 + x * 2, z0 + z * 2)
			var b := a + Vector2(2, 0)
			var c := a + Vector2(0, 2)
			var d := a + Vector2(2, 2)
			for p in [a, b, c, b, d, c]:
				var h := height_at(p.x, p.y)
				var dx := (height_at(p.x + 0.1, p.y) - height_at(p.x - 0.1, p.y)) / 0.2
				var dz := (height_at(p.x, p.y + 0.1) - height_at(p.x, p.y - 0.1)) / 0.2
				surface.set_normal(Vector3(-dx, 1, -dz).normalized())
				var color := Color("#356744").lerp(Color("#668243"), clampf((h + 3.0) / 7.0, 0, 1))
				if h < -2.1:
					color = color.lerp(Color("#b7a574"), clampf((-h - 2.1) * 2, 0, 1))
				if Vector2(p.x, p.y).length() < 5.0:
					color = color.lerp(Color("#94845a"), 0.4)
				surface.set_color(color)
				surface.add_vertex(Vector3(p.x, h, p.y))
	var mesh := surface.commit()
	var terrain := MeshInstance3D.new()
	terrain.mesh = mesh
	var mat := Shapes.material(Color.WHITE)
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	terrain.material_override = mat
	add_child(terrain)
	var ground := StaticBody3D.new()
	ground.add_to_group("terrain")
	add_child(ground)
	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = true
	Shapes.collider(ground, shape, Vector3.ZERO)

func setup_environment() -> void:
	var node := WorldEnvironment.new()
	environment = Environment.new()
	sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#4387a1")
	sky_material.sky_horizon_color = Color("#c4d6be")
	sky_material.ground_bottom_color = Color("#324b42")
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#aac7d2")
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.fog_enabled = true
	environment.fog_light_color = Color("#a3bab2")
	environment.fog_density = 0.003
	node.environment = environment
	add_child(node)
	sun = DirectionalLight3D.new()
	sun.light_color = Color("#fff0cc")
	sun.directional_shadow_max_distance = 65.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.light_angular_distance = 0.6
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.light_color = Color("#7e9dc2")
	add_child(moon)
	cloud_mesh = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(800, 800)
	cloud_mesh.mesh = plane
	cloud_mesh.position.y = 45
	cloud_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cloud_material := ShaderMaterial.new()
	cloud_material.shader = preload("res://Assets/Shaders/clouds.gdshader")
	cloud_mesh.material_override = cloud_material
	add_child(cloud_mesh)

func make_scenery() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 1
	for i in range(65):
		var p := Vector3(rng.randf_range(-60, 60), 0, rng.randf_range(-60, 60))
		if Vector2(p.x, p.z).length() < 7:
			continue
		p.y = height_at(p.x, p.z) + 0.2
		var rock := Shapes.sphere(self, rng.randf_range(0.3, 0.75), p, Color("#78827b"))
		rock.scale = Vector3(1.3, 0.6, 1.0)
		rock.rotation.y = rng.randf() * TAU
	var water := PlaneMesh.new()
	water.size = Vector2(160, 160)
	water.subdivide_width = 32
	water.subdivide_depth = 32
	var lake := Shapes.mesh(self, water, Vector3(0, -2.9, 0), Color("#4a929a"))
	water_material = ShaderMaterial.new()
	water_material.shader = WaterShader
	lake.material_override = water_material
	# A captured cubemap supplies environment reflections in Compatibility.
	# This is a local static probe, not planar reflections or screen-space SSR.
	reflection_probe = ReflectionProbe.new()
	reflection_probe.position = Vector3(0, 3, 0)
	reflection_probe.size = Vector3(140, 30, 140)
	reflection_probe.max_distance = 110
	reflection_probe.update_mode = ReflectionProbe.UPDATE_ONCE
	reflection_probe.box_projection = false
	reflection_probe.intensity = 0.65
	add_child(reflection_probe)

func make_grass() -> void:
	grass = MultiMeshInstance3D.new()
	grass.multimesh = MultiMesh.new()
	grass.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	grass.multimesh.use_colors = true
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for direction in [0.0, PI * 0.5]:
		var side := Vector3(cos(direction), 0, sin(direction)) * 0.16
		for p in [-side, Vector3(0.07, 0.55, 0), side]:
			surface.set_normal(Vector3.UP)
			surface.add_vertex(p)
	grass.multimesh.mesh = surface.commit()
	grass.multimesh.instance_count = 4200
	grass_material = ShaderMaterial.new()
	grass_material.shader = Foliage
	grass_material.set_shader_parameter("tint", Color("#71935a"))
	grass.material_override = grass_material
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 20
	for i in range(4200):
		var p := Vector3(rng.randf_range(-61, 61), 0, rng.randf_range(-61, 61))
		p.y = height_at(p.x, p.z) - 0.02
		var scale_value := rng.randf_range(0.5, 1.4) if p.y > -2.6 else 0.0
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * scale_value)
		grass.multimesh.set_instance_transform(i, Transform3D(basis, p))
		grass.multimesh.set_instance_color(i, Color.WHITE.lerp(Color("#b4bd80"), rng.randf() * 0.45))
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(grass)

func illuminate(clock) -> void:
	if sun == null:
		return
	var day: float = clock.daylight()
	last_daylight = day
	var hour: float = clock.hour()
	var cloud := float(weather.get("cloud", 0))
	var flash := float(weather.get("lightning", 0))
	sun.rotation_degrees = Vector3(-(hour - 6.0) * 15.0, -25, 0)
	moon.rotation_degrees = sun.rotation_degrees + Vector3(180, 0, 0)
	sun.light_energy = day * 0.85 * (1 - cloud * 0.62) + flash * 3.0
	moon.light_energy = (1.0 - day) * 0.18
	if reflection_probe != null:
		reflection_probe.intensity = lerpf(0.06, 0.65, day) * (1 - cloud * 0.4)
	var dusk := clampf(1.0 - day * 2.8, 0, 1)
	sun.light_color = Color("#fff0cc").lerp(Color("#ffac69"), dusk)
	environment.ambient_light_energy = lerpf(0.14, 0.40, day) * (1 - cloud * 0.35) + flash * 0.8
	sky_material.sky_top_color = Color("#0b162e").lerp(Color("#4387a1"), day).lerp(Color("#414d5b"), cloud * 0.7)
	sky_material.sky_horizon_color = Color("#26394d").lerp(Color("#d5d9b5"), day).lerp(Color("#68767b"), cloud * 0.7)
	environment.fog_light_color = Color("#1e2f42").lerp(Color("#a3bab2"), day)
	environment.fog_density = 0.003 + float(weather.get("fog", 0)) * 0.025 + float(weather.get("rain", 0)) * 0.008

func apply_weather(state: Dictionary) -> void:
	if cloud_mesh != null:
		cloud_mesh.material_override.set_shader_parameter("density", float(state.get("cloud", 0.05)) + 0.15)
		cloud_mesh.material_override.set_shader_parameter("tint", Color("#9baab3").lerp(Color("#d8e1d7"), last_daylight))
	var flash := float(state.get("lightning", 0))
	if flash > 0.5 and last_lightning <= 0.5:
		thunder_delay = 1.5 + rain_rng.randf() * 2.0
	last_lightning = flash
	weather = state.duplicate()
	var wind := float(state.get("wind", 0.2))
	if absf(wind - last_wind) >= 0.01:
		last_wind = wind
		if grass_material != null:
			grass_material.set_shader_parameter("wind", wind)
		for tree in trees:
			if tree.foliage_material != null:
				tree.foliage_material.set_shader_parameter("wind", wind)
	if rain_audio != null:
		rain_audio.volume_db = lerpf(-65, -18, float(weather.get("rain", 0)))
	if water_material != null:
		water_material.set_shader_parameter("rain", float(weather.get("rain", 0)))

func set_quality(value: int) -> void:
	quality = clampi(value, 0, 3)
	if sun == null:
		return
	sun.shadow_enabled = quality > 0
	sun.directional_shadow_max_distance = [25.0, 45.0, 60.0, 80.0][quality]
	if grass != null:
		grass.multimesh.visible_instance_count = [700, 1600, 2800, 4200][quality]
		grass.visibility_range_end = [22.0, 35.0, 50.0, 75.0][quality]
		grass.visibility_range_end_margin = 4.0
	for tree in trees:
		tree.set_quality(quality)
	if reflection_probe != null:
		reflection_probe.visible = quality >= 2
	for fire in fires:
		fire.set_quality(quality)
	if rain_mesh != null:
		rain_mesh.multimesh.visible_instance_count = [70, 130, 200, 280][quality]

func apply_graphics(config: Dictionary) -> void:
	graphics_config = config.duplicate(true)
	set_quality([0, 0, 1, 2, 3, 1][int(config["preset"])])
	sun.shadow_enabled = int(config["shadows"]) > 0
	sun.directional_shadow_max_distance = [20.0, 45.0, 65.0, 90.0][int(config["shadows"])]
	grass.multimesh.visible_instance_count = int(config["vegetation"])
	grass.visibility_range_end = float(config["view_distance"]) * 0.6
	reflection_probe.visible = bool(config["reflections"])
	rain_enabled = bool(config["rain"])
	cloud_mesh.visible = bool(config["clouds"])
	var distance := float(config["view_distance"])
	for tree in trees:
		var lod_distance := distance * 0.55
		if not tree.detail_meshes.is_empty():
			lod_distance = minf(tree.detail_meshes[0].visibility_range_end, lod_distance)
		for mesh in tree.detail_meshes:
			mesh.visibility_range_end = lod_distance
		for mesh in tree.distant_meshes:
			mesh.visibility_range_begin = lod_distance
			mesh.visibility_range_end = distance
	water_material.set_shader_parameter("detail", int(config["water"]))
	for fire in fires:
		fire.set_quality(int(config["particles"]))
		_apply_fire_graphics(fire, fires.find(fire))
	environment.ssao_enabled = bool(config["ao"]) and RenderingServer.get_current_rendering_method() == "forward_plus"
	environment.volumetric_fog_enabled = bool(config["volumetric"]) and RenderingServer.get_current_rendering_method() == "forward_plus"

func nearest_tree(player: Node3D):
	var result = null
	var distance := 3.5
	var forward := -player.global_basis.z
	for tree in trees:
		if tree.felled:
			continue
		var offset: Vector3 = tree.global_position - player.global_position
		offset.y = 0
		var length := offset.length()
		if length < distance and length > 0.01 and offset.normalized().dot(forward) > 0.35:
			distance = length
			result = tree
	return result

func placement(player: CharacterBody3D, kind: String = "campfire") -> Dictionary:
	var shelter := kind == "shelter"
	if (shelters.size() >= 16 if shelter else fires.size() >= 32):
		return {"valid": false, "position": player.global_position}
	var target := player.global_position - player.global_basis.z * (5.5 if shelter else 3.0)
	target.x = clampf(target.x, -LIMIT + 3, LIMIT - 3)
	target.z = clampf(target.z, -LIMIT + 3, LIMIT - 3)
	var query := PhysicsRayQueryParameters3D.create(target + Vector3.UP * 6, target - Vector3.UP * 9, 1, [player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {"valid": false, "position": target}
	var p: Vector3 = hit["position"]
	var valid: bool = hit["collider"].is_in_group("terrain") and hit["normal"].dot(Vector3.UP) > (0.96 if shelter else 0.88) and p.y > -2.7
	for fire in fires:
		if fire.position.distance_to(p) < (3.0 if shelter else 1.8):
			valid = false
	for building in shelters:
		if Vector2(building.position.x - p.x, building.position.z - p.z).length() < (5.5 if shelter else 0.5):
			valid = false
	var volume := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 2.8 if shelter else 0.85
	volume.shape = shape
	volume.transform = Transform3D(Basis.IDENTITY, p + Vector3.UP * (3.0 if shelter else 1.0))
	volume.collision_mask = 1
	volume.exclude = [player.get_rid()]
	if not get_world_3d().direct_space_state.intersect_shape(volume, 1).is_empty():
		valid = false
	return {"valid": valid, "position": p + Vector3.UP * 0.03}

func add_fire(at: Vector3) -> void:
	var fire = FireScript.new()
	fire.position = at
	add_child(fire)
	fire.set_quality(quality)
	fires.append(fire)
	if not graphics_config.is_empty():
		fire.set_quality(int(graphics_config["particles"]))
		_apply_fire_graphics(fire, fires.size() - 1)

func _apply_fire_graphics(fire, index: int) -> void:
	var lighting: int = int(graphics_config.get("lighting", 1))
	fire.light.omni_range = [5.0, 8.0, 10.0][lighting]
	fire.light.visible = index < [6, 12, 24][lighting]
	fire.light.shadow_enabled = int(graphics_config.get("shadows", 1)) >= 2

func add_shelter(at: Vector3) -> void:
	var shelter = ShelterScript.new()
	shelter.position = at
	add_child(shelter)
	shelters.append(shelter)
	# Existing drops must recompute the roof occlusion before falling again.
	for drop in rain_drops:
		drop["active"] = false

func is_sheltered(player: Node3D) -> bool:
	var start := player.global_position + Vector3.UP * 1.65
	var query := PhysicsRayQueryParameters3D.create(start, start + Vector3.UP * 20, 1)
	if player is CollisionObject3D:
		query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit["collider"].is_in_group("rain_roof")

func warmth_at(at: Vector3) -> bool:
	for fire in fires:
		if fire.global_position.distance_to(at) < 4.0:
			return true
	return false

func restore(data: Dictionary) -> void:
	for tree in trees:
		tree.restore_cut(tree.tree_id in data.get("cut", []))
	for fire in fires:
		remove_child(fire)
		fire.queue_free()
	fires.clear()
	for shelter in shelters:
		remove_child(shelter)
		shelter.queue_free()
	shelters.clear()
	for p in data.get("fires", []):
		add_fire(Vector3(p[0], p[1], p[2]))
	for p in data.get("shelters", []):
		add_shelter(Vector3(p[0], p[1], p[2]))

func cut_ids() -> Array:
	var ids: Array = []
	for tree in trees:
		if tree.felled:
			ids.append(tree.tree_id)
	return ids

func fire_positions() -> Array:
	var positions: Array = []
	for fire in fires:
		positions.append([fire.position.x, fire.position.y, fire.position.z])
	return positions

func shelter_positions() -> Array:
	var positions: Array = []
	for shelter in shelters:
		positions.append([shelter.position.x, shelter.position.y, shelter.position.z])
	return positions

func make_rain() -> void:
	rain_rng.seed = 83117
	rain_mesh = MultiMeshInstance3D.new()
	rain_mesh.multimesh = MultiMesh.new()
	rain_mesh.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var drop := BoxMesh.new()
	drop.size = Vector3(0.018, 0.65, 0.018)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.65, 0.79, 0.87, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop.material = mat
	rain_mesh.multimesh.mesh = drop
	rain_mesh.multimesh.instance_count = 280
	rain_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rain_mesh)
	for i in range(280):
		rain_drops.append({"p": Vector3.ZERO, "bottom": 0.0, "active": false})
		rain_mesh.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))
	rain_audio = AudioStreamPlayer.new()
	rain_audio.stream = weather_sound(false)
	rain_audio.volume_db = -65
	add_child(rain_audio)
	rain_audio.play()
	thunder_audio = AudioStreamPlayer.new()
	thunder_audio.stream = weather_sound(true)
	thunder_audio.volume_db = -17
	add_child(thunder_audio)

static func weather_sound(thunder: bool) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4141 if thunder else 7239
	var frames := 44100 if thunder else 22050
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var filtered := 0.0
	for i in range(frames):
		filtered = lerpf(filtered, rng.randf_range(-1, 1), 0.025 if thunder else 0.6)
		var amplitude := pow(1 - float(i) / frames, 1.2) if thunder else 0.4
		bytes.encode_s16(i * 2, int(filtered * amplitude * 26000))
	var result := AudioStreamWAV.new()
	result.format = AudioStreamWAV.FORMAT_16_BITS
	result.mix_rate = 22050
	result.data = bytes
	if not thunder:
		result.loop_mode = AudioStreamWAV.LOOP_FORWARD
		result.loop_end = frames
	return result

func _physics_process(delta: float) -> void:
	if not generated or rain_mesh == null:
		return
	if thunder_delay >= 0:
		thunder_delay -= delta
		if thunder_delay < 0:
			thunder_audio.play()
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		rain_focus = camera.global_position
	var rain := float(weather.get("rain", 0))
	var count := int([70, 130, 200, 280][int(graphics_config.get("particles", quality))])
	rain_mesh.visible = rain > 0.02 and rain_enabled
	if not rain_mesh.visible:
		return
	for i in range(count):
		var drop: Dictionary = rain_drops[i]
		var p: Vector3 = drop["p"]
		p.y -= delta * (10.0 + rain * 6.0)
		if not drop["active"] or p.y < float(drop["bottom"]) + 0.4 or Vector2(p.x - rain_focus.x, p.z - rain_focus.z).length() > 24:
			p = rain_focus + Vector3(rain_rng.randf_range(-18, 18), rain_rng.randf_range(5, 13), rain_rng.randf_range(-18, 18))
			drop["bottom"] = rain_stop_at(p.x, p.z, rain_focus.y + 18)
			p.y = maxf(p.y, float(drop["bottom"]) + 0.7)
			drop["active"] = true
		drop["p"] = p
		var scale_value := 1.0 if float(i) / count < rain else 0.0
		rain_mesh.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale_value), p))

func rain_stop_at(x: float, z: float, top: float) -> float:
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, top, z), Vector3(x, -15, z), 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return float(hit["position"].y) + 0.2 if not hit.is_empty() else -8.0
