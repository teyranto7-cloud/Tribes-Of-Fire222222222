extends Node
## The same authoritative simulation powers solo, listen host and dedicated server.
const WorldScript = preload("res://World/World.gd")
const PlayerScript = preload("res://Player/Player.gd")
const Inventory = preload("res://Core/Inventory.gd")
const Clock = preload("res://World/Clock.gd")
const WeatherModel = preload("res://Weather/Weather.gd")
const ExposureModel = preload("res://Weather/Exposure.gd")
const Store = preload("res://Persistence/Store.gd")
const HUDScript = preload("res://UI/HUD.gd")
const SessionScript = preload("res://Networking/Session.gd")
const RuntimeScript = preload("res://Game/Runtime.gd")
const Localization = preload("res://Localization/Manager.gd")
const GraphicsSettings = preload("res://Graphics/Settings.gd")
const Diagnostics = preload("res://Game/Diagnostics.gd")

var world
var player
var hud
var session
var runtime
var localization
var graphics
var diagnostics
var survival
var chat_ui
var inventory = Inventory.new()
var exposure = ExposureModel.new()
var clock = Clock.new()
var weather = WeatherModel.new()
var players: Dictionary = {}
var inventories: Dictionary = {}
var exposures: Dictionary = {}
var saved: Dictionary = {}
var ready_world: bool = false
var running: bool = false
var tool: int = 1
var quality: int = 1
var vsync: bool = true
var sound: bool = true
var sensitivity: float = 0.003
var camera_smoothing: bool = true
var autosave: float = 0.0
var snapshot_timer: float = 0.0
var save_folder: String = "user://world"
var commands: Array[Dictionary] = []
var menu_camera: Camera3D
var world_signature: int = 0
var cli: Dictionary = {}
var smoke_elapsed: float = 0.0
var snapshots_received: int = 0
var smoke_origin: Vector3
var smoke_seen: bool = false
var smoke_action_sent: bool = false
var smoke_attack_timer: float = 0.0
var smoke_progress: float = 0.0
var smoke_moved: bool = false
var smoke_completed: bool = false
var quitting: bool = false
var _last_wall_usec: int = Time.get_ticks_usec()

func _ready() -> void:
	get_tree().auto_accept_quit = false
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		cli[parts[0]] = parts[1] if parts.size() > 1 else "true"
	save_folder = str(cli.get("save-dir", save_folder))
	diagnostics = Diagnostics.new()
	localization = Localization.new()
	graphics = GraphicsSettings.new()
	graphics.load_settings()
	if cli.has("safe") or cli.has("reset-graphics"):
		graphics.pending = GraphicsSettings.DEFAULTS.duplicate(true)
		graphics.choose_preset(0)
		graphics.pending["fps"] = 30
		graphics.applied = graphics.pending.duplicate(true)
		diagnostics.record("safe_graphics")
	install_inputs()
	load_settings()
	world = WorldScript.new()
	add_child(world)
	session = SessionScript.new()
	session.name = "Session"
	add_child(session)
	session.peer_joined.connect(_spawn_player)
	session.peer_left.connect(_remove_player)
	session.intent_received.connect(_receive_intent)
	session.action_received.connect(func(id: int, action: String): commands.append({"id": id, "action": action}))
	session.state_received.connect(_receive_state)
	session.failed.connect(_network_failure)
	session.command_received.connect(func(id: int, command: String, data: Dictionary): commands.append({"id": id, "command": command, "data": data}))
	hud = HUDScript.new()
	hud.game = self
	add_child(hud)
	var settings := ConfigFile.new()
	settings.load("user://settings.cfg")
	hud.language = int(_config_number(settings.get_value("ui", "language", 0), 0, 0, 5))
	menu_camera = Camera3D.new()
	menu_camera.position = Vector3(13, 9, 15)
	add_child(menu_camera)
	menu_camera.look_at(Vector3(0, 2, -4))
	menu_camera.current = true
	await world.generate(Callable(hud, "loading"))
	if quitting:
		return
	graphics.apply_current(world, get_viewport())
	runtime = RuntimeScript.new()
	runtime.name = "Runtime"
	add_child(runtime)
	runtime.configure(self)
	load_audio_levels()
	chat_ui = preload("res://UI/ChatWidget.gd").new()
	add_child(chat_ui)
	chat_ui.configure(self)
	var performance := preload("res://UI/PerformanceOverlay.gd").new()
	add_child(performance)
	performance.configure(self)
	ready_world = true
	saved = Store.load_world(save_folder)
	hud.show_panel("language" if not localization.chosen and DisplayServer.get_name() != "headless" else "menu")
	diagnostics.record("world_ready")
	if cli.has("server") or OS.has_feature("dedicated_server"):
		_start_host(int(cli.get("port", 24567)), true)
		if not running:
			await quit_game(1, false)
			return
	elif cli.has("join"):
		join_game(str(cli["join"]), int(cli.get("port", 24567)))
	elif cli.has("play"):
		new_game()
	print("GAME_READY role=%s Godot=%s" % [session.role, Engine.get_version_info()["string"]])

func install_inputs() -> void:
	var keys := {"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D,
		"sprint": KEY_SHIFT, "jump": KEY_SPACE, "inventory": KEY_TAB,
		"menu": KEY_ESCAPE, "save": KEY_F5, "load": KEY_F9,
		"axe": KEY_1, "build": KEY_2, "shelter": KEY_3, "interact": KEY_E,
		"crouch": KEY_C, "dodge": KEY_Q, "heavy": KEY_F, "push_to_talk": KEY_V, "chat": KEY_ENTER}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = keys[action]
		InputMap.action_add_event(action, event)
	if not InputMap.has_action("use"):
		InputMap.add_action("use")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("use", click)
	if not InputMap.has_action("block"):
		InputMap.add_action("block")
	var guard := InputEventMouseButton.new()
	guard.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("block", guard)
	preload("res://UI/ControlsPanel.gd").load_bindings()

func _empty_world() -> Dictionary:
	return {"version": 2, "seed": 1337, "players": {}, "cut": [], "fires": [],
		"shelters": [], "phase": 450.0, "weather": WeatherModel.new().serialize()}

func _begin_authority(data: Dictionary) -> bool:
	var error: String = Store.acquire_lock(save_folder)
	if error != "":
		hud.notify_message(error)
		push_error(error)
		return false
	_clear_players()
	_reset_communication()
	saved = data.duplicate(true)
	world.restore(data)
	runtime.restore(data)
	clock.elapsed = float(data.get("phase", 450.0))
	weather.restore(data.get("weather", {}))
	running = true
	_last_wall_usec = Time.get_ticks_usec()
	autosave = 0.0
	return true

func new_game() -> void:
	session.offline()
	if _begin_authority(_empty_world()):
		_spawn_player(1)
		if player == null: return
		hud.show_panel("character" if player.creation_pending else "")

func host_game(port: int = 24567) -> void:
	_start_host(port, false)

func _start_host(port: int, dedicated: bool) -> void:
	var opened: Dictionary = Store.open_world(save_folder, true)
	if not opened["error"].is_empty():
		hud.notify_message(opened["error"])
		printerr("PERSISTENCE_REFUSED ", opened["error"])
		return
	var data: Dictionary = opened["data"]
	if data.is_empty():
		data = _empty_world()
	if not _begin_authority(data):
		return
	var error: int = session.host_game(port, int(cli.get("max-players", 16)), dedicated)
	if error != OK:
		running = false
		Store.release_lock(save_folder)
		_network_failure(error_string(error))
		return
	session.set_world_owner(str(saved.get("host_identity", "")) if dedicated else session.local_identity_hash())
	if not dedicated:
		_spawn_player(1)
		if player == null: return
	hud.show_panel("character" if player != null and player.creation_pending else "")
	print("SERVER_LISTENING port=%d dedicated=%s" % [port, dedicated])

func join_game(address: String, port: int = 24567) -> void:
	if running and session.is_authority():
		if not save_game():
			return
		Store.release_lock(save_folder)
	_clear_players()
	_reset_communication()
	running = false
	hud.loading(hud.t("Conectando…", "Connecting…"))
	var error: int = session.join_game(address, port)
	if error != OK:
		_network_failure(error_string(error))

func _network_failure(message: String) -> void:
	if diagnostics != null:
		diagnostics.record("network_failure")
	running = false
	commands.clear()
	if session != null:
		session.close()
	_clear_players()
	_reset_communication()
	saved = Store.load_world(save_folder)
	set_controls(false)
	hud.show_panel("menu")
	hud.notify_message(message)
	printerr("NETWORK_FAILURE ", message)

func _clear_players() -> void:
	for body in players.values():
		remove_child(body)
		body.queue_free()
	players.clear()
	inventories.clear()
	exposures.clear()
	if runtime != null:
		runtime.needs.clear()
		runtime.combat.cooldowns.clear()
		runtime.combat.dodge_cooldowns.clear()
		if runtime.mining != null: runtime.mining._cooldowns.clear()
		if runtime.audio != null:
			runtime.audio.step_positions.clear()
			runtime.audio.step_distance.clear()
	player = null
	menu_camera.current = true

func _reset_communication() -> void:
	if runtime != null:
		runtime.reset_local_communication()
	if chat_ui != null:
		chat_ui.reset_session()

func _spawn_player(id: int) -> void:
	if players.has(id) or not running:
		return
	if session.is_authority():
		var known: Dictionary = saved.get("players", {}).duplicate()
		for existing in players:
			known[session.player_key(existing)] = true
		var identity: String = session.player_key(id)
		if not known.has(identity) and (known.size() >= Store.MAX_PLAYERS or not Store.profile_room(snapshot())):
			var reason := "Limite de perfis salvos atingido / Saved player profile limit reached."
			if id == 1:
				Store.release_lock(save_folder)
				_network_failure(reason)
			else:
				session.reject_peer(id, reason)
			return
	var body = PlayerScript.new()
	body.name = "Player_%d" % id
	body.world = world
	body.camera_smoothing = camera_smoothing
	body.authoritative = session.is_authority()
	body.local_control = id == session.local_id and session.role != "dedicated"
	add_child(body)
	body.set_local(body.local_control)
	var record_key: String = session.player_key(id) if session.is_authority() else str(id)
	var record: Dictionary = saved.get("players", {}).get(record_key, {})
	var origin: Array = record.get("position", [float(players.size()) * 1.5, world.height_at(float(players.size()) * 1.5, 0) + 0.2, 0])
	body.position = Vector3(origin[0], origin[1], origin[2])
	body.vitals.hp = int(record.get("hp", 100))
	body.vitals.regen_delay = _config_number(float(cli.get("regen-delay", "6")), 6, 0, 60)
	body.vitals.quiet_seconds = float(record.get("quiet_seconds", 0.0))
	players[id] = body
	inventories[id] = Inventory.new()
	if record.has("inventory"):
		inventories[id].restore(record["inventory"])
	exposures[id] = ExposureModel.new()
	if record.has("exposure"):
		exposures[id].restore(record["exposure"])
	runtime.spawn(id, record)
	body.respawned.connect(func():
		if exposures.has(id):
			exposures[id].reset()
			exposures[id].wetness = 0.0)
	if body.local_control:
		player = body
		inventory = inventories[id]
		exposure = exposures[id]
		survival = runtime.needs[id]
		body.enabled = hud.mode == ""
	print("PLAYER_JOINED id=%d count=%d" % [id, players.size()])
	if session.is_authority():
		runtime.publish_channels.call_deferred()

func _remove_player(id: int) -> void:
	if not players.has(id):
		return
	# Retain disconnected state in the current server snapshot; IDs are session-scoped.
	if session.is_authority():
		if not saved.has("players"):
			saved["players"] = {}
		saved["players"][session.player_key(id)] = _player_record(id)
	var body = players[id]
	var instance: int = body.get_instance_id()
	runtime.combat.cooldowns.erase(instance)
	runtime.combat.dodge_cooldowns.erase(instance)
	runtime.mining._cooldowns.erase(instance)
	runtime.audio.step_positions.erase(id)
	runtime.audio.step_distance.erase(id)
	runtime.channels.disconnected(session.player_key(id))
	runtime.needs.erase(id)
	remove_child(body)
	body.queue_free()
	players.erase(id)
	inventories.erase(id)
	exposures.erase(id)
	if session.is_authority():
		runtime.publish_channels.call_deferred()
	print("PLAYER_LEFT id=%d" % id)

func _receive_intent(id: int, intent: Dictionary) -> void:
	if running and session.is_authority() and players.has(id):
		if not players[id].creation_pending:
			players[id].set_intent(intent)

func _receive_action(id: int, action: String) -> void:
	if not running or not session.is_authority():
		return
	if id == 1 and action.begins_with("weather_"):
		weather.set_weather(action.trim_prefix("weather_"))
		return
	if id == 1 and action == "save":
		save_game()
		return
	if not players.has(id):
		return
	var body = players[id]
	var inv = inventories[id]
	if body.creation_pending:
		return
	if body.vitals.hp <= 0:
		return
	match action:
		"attack":
			if inv.equipped_item() in ["pickaxe", "iron_pickaxe"]:
				runtime.command(id, "mine", {})
				return
			if inv.equipped_item() != "axe" or world.nearest_tree(body) == null:
				runtime.command(id, "combat", {"kind": "ranged" if inv.equipped_item() == "bow" else "light"})
				return
			if not body.attack():
				return
			var target = world.nearest_tree(body)
			if target != null:
				runtime.emit_sound("wood", body.position)
			if cli.has("network-debug"):
				print("NETWORK_ATTACK id=%d position=%s yaw=%s target=%s" % [id, body.position, body.yaw, target.tree_id if target != null else -1])
			if target != null:
				# Reserve the reward before felling: full inventories cannot consume trees.
				if target.hits >= 2:
					if not inv.add("wood", 4):
						return
					target.hit()
				else:
					target.hit()
		"craft_fire":
			inv.craft_fire()
		"craft_shelter":
			inv.craft_shelter()
		"place_fire", "place_shelter":
			var kind := "shelter" if action == "place_shelter" else "campfire"
			var place: Dictionary = world.placement(body, kind)
			if place["valid"] and inv.consume(kind, 1):
				if kind == "shelter":
					world.add_shelter(place["position"])
				else:
					world.add_fire(place["position"])

func _player_record(id: int) -> Dictionary:
	var body = players[id]
	var record := {"position": [body.position.x, body.position.y, body.position.z],
		"inventory": inventories[id].items.duplicate(), "hp": body.vitals.hp,
		"quiet_seconds": body.vitals.quiet_seconds, "exposure": exposures[id].state()}
	record.merge(runtime.player_record(id), true)
	return record

func snapshot() -> Dictionary:
	var records: Dictionary = saved.get("players", {}).duplicate(true)
	for id in players:
		records[session.player_key(id)] = _player_record(id)
	var data := {"version": 3, "seed": 1337, "players": records, "cut": world.cut_ids(),
		"fires": world.fire_positions(), "shelters": world.shelter_positions(),
		"phase": clock.elapsed, "weather": weather.serialize()}
	data.merge(runtime.save_state(), true)
	var owner: String = session.local_identity_hash() if session.role in ["offline", "host"] else str(saved.get("host_identity", ""))
	if not owner.is_empty():
		data["host_identity"] = owner
	return data

func network_state() -> Dictionary:
	var bodies: Dictionary = {}
	for id in players:
		var state: Dictionary = players[id].export_state()
		state["inventory"] = inventories[id].items.duplicate()
		state["exposure"] = exposures[id].state()
		state["inventory_state"] = inventories[id].serialize()
		state["survival"] = runtime.needs[id].state()
		state["key"] = session.player_key(id)
		bodies[str(id)] = state
	var data := {"players": bodies, "cut": world.cut_ids(), "fires": world.fire_positions(),
		"shelters": world.shelter_positions(), "phase": clock.elapsed, "weather": weather.serialize()}
	data.merge(runtime.save_state(), true)
	# Group membership and block lists are sent only through authorized channel events.
	data.erase("communication")
	return data

func _receive_state(data: Dictionary) -> void:
	if session.is_authority() or not ready_world:
		return
	snapshots_received += 1
	running = true
	var signature: int = hash([data["cut"], data["fires"], data["shelters"]])
	if signature != world_signature:
		world.restore(data)
		world_signature = signature
	clock.elapsed = float(data["phase"])
	weather.restore(data["weather"])
	runtime.apply_state(data)
	var ids: Array = []
	for key in data["players"]:
		var id := int(key)
		ids.append(id)
		if not players.has(id):
			_spawn_player(id)
		players[id].apply_state(data["players"][key])
		inventories[id].restore(data["players"][key].get("inventory_state", data["players"][key]["inventory"]))
		players[id].set_meta("key", data["players"][key].get("key", ""))
		if id == session.local_id:
			session.set_local_profile_key(str(data["players"][key].get("key", "")))
		runtime.needs[id].restore(data["players"][key].get("survival", {}))
		var e: Dictionary = data["players"][key]["exposure"]
		exposures[id].exposure_seconds = float(e["exposure"])
		exposures[id].wetness = float(e["wetness"])
		exposures[id].temperature = float(e["temperature"])
		exposures[id].comfort = bool(e["comfort"])
		exposures[id].damage_count = int(e["rain_damage"])
	for id in players.keys():
		if not id in ids:
			_remove_player(id)
	if player != null:
		if player.creation_pending:
			if DisplayServer.get_name() == "headless":
				session.send_command("appearance", PlayerScript.Appearance.DEFAULT.duplicate(true))
			elif hud.mode != "character":
				hud.show_panel("character")
		elif hud.mode in ["loading", "character"]:
			hud.show_panel("")

func save_game() -> bool:
	if not running:
		return true
	if not session.is_authority():
		hud.notify_message(hud.t("O servidor salva o mundo.", "The server saves the world."))
		return false
	var data := snapshot()
	var error: String = Store.save_world(data, save_folder)
	if error != "":
		hud.notify_message(error)
		push_error(error)
		diagnostics.record("save_failed", {"reason": error})
		return false
	saved = data
	diagnostics.record("save_complete", {"players": data["players"].size()})
	autosave = 0.0
	hud.notify_message(hud.t("Progresso salvo.", "Progress saved."))
	return true

func load_game() -> void:
	if session.role != "offline":
		hud.notify_message(hud.t("Carregamento manual disponível no modo solo.", "Manual loading is available in solo mode."))
		return
	var opened: Dictionary = Store.open_world(save_folder, false)
	if not opened["error"].is_empty():
		hud.notify_message(opened["error"])
		return
	var data: Dictionary = opened["data"]
	if _begin_authority(data):
		_spawn_player(1)
		if player == null: return
		hud.show_panel("character" if player.creation_pending else "")

func set_controls(active: bool) -> void:
	active = active and running and player != null and not player.creation_pending and player.vitals.hp > 0
	if hud != null:
		active = active and hud.mode == ""
	if chat_ui != null and chat_ui.panel != null:
		active = active and not chat_ui.panel.visible
	if player != null:
		player.enabled = active
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if active and player != null else Input.MOUSE_MODE_VISIBLE
	if world != null and world.preview != null:
		world.preview.hide()

func set_quality(value: int) -> void:
	quality = clampi(value, 0, 3)
	world.set_quality(quality)
	save_settings()

func set_fps(value: int) -> void:
	Engine.max_fps = clampi(value, 0, 240)
	save_settings()

func set_resolution(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	save_settings()

func set_sensitivity(value: float) -> void:
	sensitivity = clampf(value, 0.0005, 0.01)
	save_settings()

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("video", "quality", quality)
	config.set_value("video", "fps", Engine.max_fps)
	config.set_value("video", "vsync", vsync)
	config.set_value("video", "resolution", DisplayServer.window_get_size())
	config.set_value("video", "fullscreen", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	config.set_value("audio", "sound", sound)
	config.set_value("input", "sensitivity", sensitivity)
	config.set_value("input", "camera_smoothing", camera_smoothing)
	for bus in ["Master", "Music", "Ambient", "Effects", "UI", "Vocalizations", "Voice"]:
		var index := AudioServer.get_bus_index(bus)
		if index >= 0:
			config.set_value("audio_levels", bus, db_to_linear(AudioServer.get_bus_volume_db(index)))
	if hud != null:
		config.set_value("ui", "language", hud.language)
	config.save("user://settings.cfg")

static func _config_number(value: Variant, fallback: float, minimum: float, maximum: float) -> float:
	if not (value is int or value is float) or not is_finite(float(value)):
		return fallback
	return clampf(float(value), minimum, maximum)

static func _config_bool(value: Variant, fallback: bool) -> bool:
	return value if value is bool else fallback

func load_settings(path: String = "user://settings.cfg") -> void:
	var config := ConfigFile.new()
	config.load(path)
	quality = int(_config_number(config.get_value("video", "quality", 1), 1, 0, 3))
	Engine.max_fps = int(_config_number(config.get_value("video", "fps", 60), 60, 0, 240))
	sensitivity = _config_number(config.get_value("input", "sensitivity", 0.003), 0.003, 0.0005, 0.01)
	camera_smoothing = _config_bool(config.get_value("input", "camera_smoothing", true), true)
	vsync = _config_bool(config.get_value("video", "vsync", true), true)
	sound = _config_bool(config.get_value("audio", "sound", true), true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	AudioServer.set_bus_mute(0, not sound)
	if DisplayServer.get_name() != "headless" and not cli.has("safe") and not cli.has("reset-graphics"):
		var resolution: Variant = config.get_value("video", "resolution", Vector2i(1280, 720))
		if resolution is Vector2i and resolution.x >= 640 and resolution.y >= 360 and resolution.x <= 7680 and resolution.y <= 4320:
			DisplayServer.window_set_size(resolution)
		if _config_bool(config.get_value("video", "fullscreen", false), false):
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func craft_fire() -> void:
	session.send_action("craft_fire")

func craft_shelter() -> void:
	session.send_action("craft_shelter")

func request_weather(value: String) -> void:
	session.send_action("weather_" + value)

func use_tool() -> void:
	session.send_action({1: "attack", 2: "place_fire", 3: "place_shelter"}.get(tool, "attack"))

func _unhandled_input(event: InputEvent) -> void:
	if not ready_world or player == null or (event is InputEventKey and event.echo):
		return
	if player.creation_pending:
		return
	if event.is_action_pressed("interact") and hud.mode == "":
		request_command("interact", {})
		return
	if event.is_action_pressed("heavy") and hud.mode == "":
		request_command("combat", {"kind": "heavy"})
		return
	if event.is_action_pressed("menu"):
		hud.show_panel("pause" if hud.mode == "" else "")
	elif event.is_action_pressed("inventory"):
		hud.show_panel("" if hud.mode == "inventory" else "inventory")
	elif event.is_action_pressed("save"):
		save_game()
	elif event.is_action_pressed("load"):
		load_game()
	elif hud.mode == "":
		if event.is_action_pressed("axe"):
			tool = 1
		elif event.is_action_pressed("build"):
			tool = 2
		elif event.is_action_pressed("shelter"):
			tool = 3
		elif event.is_action_pressed("use"):
			use_tool()

func _physics_process(delta: float) -> void:
	if not running or quitting:
		return
	if player != null:
		if "sensitivity" in player:
			player.sensitivity = sensitivity
		var intent: Dictionary = player.input_intent()
		if cli.has("smoke-client"):
			var destination := Vector3(3, 0, -1) if str(cli["smoke-client"]) == "2" else Vector3(0, 0, -4)
			var offset := Vector2(destination.x - player.position.x, destination.z - player.position.z)
			var movement := offset.normalized() if offset.length() > 0.3 else Vector2.ZERO
			intent = {"move": [movement.x, movement.y], "yaw": 0.0, "jump": false, "sprint": false}
			smoke_progress += delta
		session.send_intent(intent)
	runtime.tick(delta)
	if session.is_authority():
		while not commands.is_empty():
			var command: Dictionary = commands.pop_front()
			if command.has("command"):
				runtime.command(command["id"], command["command"], command["data"])
			else:
				_receive_action(command["id"], command["action"])

func _process(delta: float) -> void:
	if not ready_world or quitting:
		return
	var now := Time.get_ticks_usec()
	var wall_delta := maxf(0, float(now - _last_wall_usec) / 1000000.0)
	_last_wall_usec = now
	if session.is_authority():
		clock.advance(wall_delta)
		weather.advance(wall_delta)
		if running:
			var state: Dictionary = weather.state()
			for id in players:
				if not players[id].creation_pending:
					runtime.needs[id].advance(wall_delta, players[id].vitals)
					exposures[id].advance(wall_delta, bool(state["raining"]), world.is_sheltered(players[id]), players[id].vitals, world.warmth_at(players[id].position), runtime.safe(id))
	world.apply_weather(weather.state())
	world.illuminate(clock)
	_run_cli_checks(delta)
	if not running or quitting:
		return
	if session.is_authority():
		autosave += wall_delta
		snapshot_timer += delta
		if autosave >= 45.0:
			autosave = 0.0
			save_game()
		if snapshot_timer >= 0.1:
			snapshot_timer = 0.0
			session.broadcast(network_state())
	world.preview.visible = player != null and hud.mode == "" and tool in [2, 3] and inventory.count("shelter" if tool == 3 else "campfire") > 0
	if world.preview.visible:
		var place: Dictionary = world.placement(player, "shelter" if tool == 3 else "campfire")
		world.preview.position = place["position"]
		world.preview.scale = Vector3(3.6, 1, 3.6) if tool == 3 else Vector3.ONE
		world.preview.material_override.albedo_color = Color(0.3, 1, 0.55, 0.45) if place["valid"] else Color(1, 0.25, 0.2, 0.45)

func _run_cli_checks(delta: float) -> void:
	if quitting:
		return
	smoke_elapsed += delta
	if cli.has("smoke-client") and player != null:
		if not smoke_seen:
			smoke_origin = player.position
			smoke_seen = true
		if Vector2(player.position.x - smoke_origin.x, player.position.z - smoke_origin.z).length() > 1.0:
			smoke_moved = true
		if smoke_progress >= 2.0:
			smoke_attack_timer -= delta
			if smoke_attack_timer <= 0.0:
				session.send_action("attack")
				smoke_action_sent = true
				smoke_attack_timer = 0.65
		var collected := 0
		for inv in inventories.values():
			collected += inv.count("wood")
		if not smoke_completed and players.size() >= 2 and snapshots_received >= 30 and smoke_moved and smoke_action_sent and not world.cut_ids().is_empty() and collected >= 4:
			print("MULTIPLAYER_SMOKE_OK client=%s players=%d snapshots=%d moved=true shared_tree=true wood=%d" % [cli["smoke-client"], players.size(), snapshots_received, collected])
			# Keep the peer present so the other client can verify the same shared state.
			smoke_completed = true
	if cli.has("quit-after-seconds") and smoke_elapsed >= float(cli["quit-after-seconds"]):
		quit_game()
	if cli.has("smoke-client") and smoke_elapsed > 20.0:
		printerr("MULTIPLAYER_SMOKE_FAILED snapshots=%d players=%d moved=%s" % [snapshots_received, players.size(), smoke_moved])
		Store.release_lock(save_folder)
		get_tree().quit(1)

func quit_game(exit_code: int = 0, save_progress: bool = true) -> void:
	if quitting:
		return
	if save_progress and session != null and session.is_authority() and not save_game():
		return
	quitting = true
	if world != null:
		world.cancel_generation()
	save_settings()
	if diagnostics != null:
		diagnostics.record("shutdown", {"role": session.role if session != null else "starting"})
	Store.release_lock(save_folder)
	if runtime != null:
		if runtime.audio != null: runtime.audio.stop()
		if runtime.voice != null: runtime.voice.stop()
	_stop_audio(self)
	if session != null:
		await session.graceful_leave()
	# Spatial audio releases its mixer-thread playbacks asynchronously.
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(exit_code)

func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
		node.stop()
	for child in node.get_children():
		_stop_audio(child)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and session != null:
		quit_game()

func request_command(command: String, data: Dictionary = {}) -> void:
	session.send_command(command, data)

func load_audio_levels() -> void:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") != OK: return
	for bus in ["Master", "Music", "Ambient", "Effects", "UI", "Vocalizations", "Voice"]:
		var index := AudioServer.get_bus_index(bus)
		var level: Variant = config.get_value("audio_levels", bus, 1.0)
		if index >= 0 and (level is int or level is float) and is_finite(float(level)):
			AudioServer.set_bus_volume_db(index, linear_to_db(clampf(float(level), 0.0001, 1.0)))
