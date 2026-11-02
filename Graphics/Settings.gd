extends RefCounted
## Transactional client presentation settings. Never changes simulation rules.
const PRESET_NAMES := ["Muito Baixo", "Baixo", "Médio", "Alto", "Ultra", "Personalizado"]
const PRESET_NAMES_EN := ["Very Low", "Low", "Medium", "High", "Ultra", "Custom"]
const DEFAULTS := {"preset": 2, "resolution": Vector2i(1280, 720), "render_scale": 1.0,
	"window_mode": 0, "vsync": true, "fps": 60, "shadows": 1, "vegetation": 2600,
	"view_distance": 105.0, "water": 1, "reflections": false, "particles": 1,
	"clouds": true, "rain": true, "lighting": 1, "antialiasing": 1,
	"postprocess": true, "ao": false, "volumetric": false, "performance": false}
const TIERS := [
	{"shadows": 0, "vegetation": 350, "view_distance": 55.0, "water": 0, "reflections": false, "particles": 0, "clouds": true, "lighting": 0, "antialiasing": 0, "postprocess": false},
	{"shadows": 1, "vegetation": 1200, "view_distance": 75.0, "water": 0, "reflections": false, "particles": 0, "clouds": true, "lighting": 0, "antialiasing": 0, "postprocess": true},
	{"shadows": 1, "vegetation": 2600, "view_distance": 105.0, "water": 1, "reflections": false, "particles": 1, "clouds": true, "lighting": 1, "antialiasing": 1, "postprocess": true},
	{"shadows": 2, "vegetation": 3800, "view_distance": 145.0, "water": 2, "reflections": true, "particles": 2, "clouds": true, "lighting": 2, "antialiasing": 2, "postprocess": true},
	{"shadows": 3, "vegetation": 4200, "view_distance": 170.0, "water": 2, "reflections": true, "particles": 3, "clouds": true, "lighting": 2, "antialiasing": 3, "postprocess": true}
]
var applied: Dictionary = DEFAULTS.duplicate(true)
var pending: Dictionary = DEFAULTS.duplicate(true)
var last_error: String = ""

func load_settings(path: String = "user://graphics.cfg") -> void:
	var config := ConfigFile.new()
	if config.load(path) == OK:
		var values: Variant = config.get_value("graphics", "settings", {})
		if values is Dictionary and valid(values):
			applied = values.duplicate(true)
	pending = applied.duplicate(true)

func begin_edit() -> void:
	pending = applied.duplicate(true)

func cancel() -> void:
	begin_edit()

func reset_pending() -> void:
	pending = DEFAULTS.duplicate(true)

func choose_preset(index: int) -> void:
	if index < 0 or index > 5:
		return
	pending["preset"] = index
	if index < 5:
		for key in TIERS[index]:
			pending[key] = TIERS[index][key]

func set_pending(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key):
		return
	var candidate := pending.duplicate(true)
	candidate[key] = value
	if valid(candidate):
		pending = candidate
		if key in ["shadows", "vegetation", "view_distance", "water", "reflections", "particles", "clouds", "lighting", "antialiasing", "postprocess", "ao", "volumetric"]:
			pending["preset"] = 5

static func valid(values: Dictionary) -> bool:
	if values.size() != DEFAULTS.size():
		return false
	for key in DEFAULTS:
		if not values.has(key):
			return false
	for key in ["vsync", "reflections", "clouds", "rain", "postprocess", "ao", "volumetric", "performance"]:
		if not values[key] is bool:
			return false
	var size: Variant = values["resolution"]
	if not size is Vector2i or size.x < 640 or size.y < 360 or size.x > 7680 or size.y > 4320:
		return false
	for entry in [["preset", 0, 5], ["window_mode", 0, 2], ["fps", 0, 240], ["shadows", 0, 3], ["vegetation", 0, 4200], ["water", 0, 2], ["particles", 0, 3], ["lighting", 0, 2], ["antialiasing", 0, 3]]:
		var value: Variant = values[entry[0]]
		if not value is int or value < entry[1] or value > entry[2]:
			return false
	for entry in [["render_scale", 0.5, 1.0], ["view_distance", 30.0, 200.0]]:
		var value: Variant = values[entry[0]]
		if not (value is float or value is int) or not is_finite(float(value)) or value < entry[1] or value > entry[2]:
			return false
	return true

func apply_to(world: Node, viewport: Viewport, player: Node = null, path: String = "user://graphics.cfg") -> bool:
	last_error = ""
	if not valid(pending):
		last_error = "Configuração gráfica inválida / Invalid graphics settings."
		return false
	var previous := applied.duplicate(true)
	applied = pending.duplicate(true)
	if not persist(path):
		applied = previous
		return false
	apply_current(world, viewport, player)
	return true

func preview(world: Node, viewport: Viewport, player: Node = null) -> bool:
	if not valid(pending):
		return false
	applied = pending.duplicate(true)
	apply_current(world, viewport, player)
	return true

func persist(path: String = "user://graphics.cfg") -> bool:
	last_error = ""
	var config := ConfigFile.new()
	config.set_value("graphics", "settings", applied)
	var result := config.save(path)
	if result != OK:
		last_error = error_string(result)
		return false
	return true

func apply_current(world: Node, viewport: Viewport, player: Node = null) -> void:
	if world != null and world.has_method("apply_graphics"):
		world.apply_graphics(applied)
	viewport.scaling_3d_scale = float(applied["render_scale"])
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.msaa_3d = int(applied["antialiasing"]) as Viewport.MSAA
	Engine.max_fps = int(applied["fps"])
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if applied["vsync"] else DisplayServer.VSYNC_DISABLED)
		match int(applied["window_mode"]):
			0:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
				DisplayServer.window_set_size(applied["resolution"])
			1:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
			2:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	apply_camera(player)
	var post: CanvasLayer = viewport.get_node_or_null("TribesColorGrade")
	if post == null:
		post = CanvasLayer.new()
		post.name = "TribesColorGrade"
		post.layer = 0
		var rect := ColorRect.new()
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var material := ShaderMaterial.new()
		material.shader = preload("res://Assets/Shaders/color_grade.gdshader")
		rect.material = material
		post.add_child(rect)
		viewport.add_child(post)
	post.visible = bool(applied["postprocess"])

func apply_camera(player: Node) -> void:
	if player != null and "camera" in player and player.camera != null:
		player.camera.far = float(applied["view_distance"])

static func hardware() -> Dictionary:
	var name := RenderingServer.get_video_adapter_name()
	var cpu := OS.get_processor_name()
	var memory: Dictionary = OS.get_memory_info()
	return {"gpu": name if not name.is_empty() else "Não disponível / Not available",
		"cpu": cpu if not cpu.is_empty() else "Não disponível / Not available",
		"memory_bytes": int(memory.get("physical", 0)), "cores": OS.get_processor_count(),
		"renderer": RenderingServer.get_current_rendering_method()}

static func support() -> Dictionary:
	var forward := RenderingServer.get_current_rendering_method() == "forward_plus"
	return {"ao": forward, "volumetric": forward, "textures": false}

func detect_automatically() -> int:
	var info := hardware()
	var gpu := str(info["gpu"]).to_lower()
	var tier := 2
	if gpu.contains("llvmpipe") or gpu.contains("softpipe") or gpu.contains("swiftshader"):
		tier = 0
	elif (int(info["memory_bytes"]) > 0 and int(info["memory_bytes"]) < 4 * 1024 * 1024 * 1024) or int(info["cores"]) < 4:
		tier = 1
	choose_preset(tier)
	return tier
