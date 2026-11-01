extends RefCounted

const WeatherModel = preload("res://Weather/Weather.gd")
const ExposureModel = preload("res://Weather/Exposure.gd")
const MAX_BYTES := 2097152
const MAX_PLAYERS := 100
static var owned_locks: Dictionary = {}

static func number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and float(value) >= low and float(value) <= high

static func integer(value: Variant, low: int, high: int) -> bool:
	return number(value, low, high) and float(value) == floorf(float(value))

static func position_valid(value: Variant) -> bool:
	if not value is Array or value.size() != 3:
		return false
	return number(value[0], -61, 61) and number(value[1], -15, 40) \
		and number(value[2], -61, 61)

static func inventory_valid(value: Variant, legacy: bool = false) -> bool:
	if not value is Dictionary or value.size() != (3 if legacy else 4):
		return false
	for key in ["wood", "campfire", "axe"]:
		if not integer(value.get(key), 0, 9999):
			return false
	return value["axe"] == 1 and (legacy or integer(value.get("shelter"), 0, 9999))

static func positions_valid(value: Variant, limit: int) -> bool:
	if not value is Array or value.size() > limit:
		return false
	for p in value:
		if not position_valid(p):
			return false
	return true

static func valid(data: Variant) -> bool:
	if not data is Dictionary or not integer(data.get("version"), 1, 2):
		return false
	if not integer(data.get("seed"), 1337, 1337) or not number(data.get("phase"), 0, 2700):
		return false
	var cut: Variant = data.get("cut")
	if not cut is Array or cut.size() > 160:
		return false
	var seen: Dictionary = {}
	for id in cut:
		if not integer(id, 0, 159) or seen.has(int(id)):
			return false
		seen[int(id)] = true
	if not positions_valid(data.get("fires"), 32):
		return false
	if int(data["version"]) == 1:
		return position_valid(data.get("position")) and inventory_valid(data.get("inventory"), true) \
			and integer(data.get("hp"), 0, 100)
	if not positions_valid(data.get("shelters"), 32) or not data.get("players") is Dictionary:
		return false
	var players: Dictionary = data["players"]
	if players.size() > MAX_PLAYERS:
		return false
	for id in players:
		if not id is String or id.is_empty() or id.length() > 128:
			return false
		var player: Variant = players[id]
		if not player is Dictionary or not position_valid(player.get("position")) \
				or not inventory_valid(player.get("inventory")) or not integer(player.get("hp"), 0, 100):
			return false
		if player.has("quiet_seconds") and not number(player["quiet_seconds"], 0, 3):
			return false
		if player.has("exposure") and (not player["exposure"] is Dictionary or not ExposureModel.valid(player["exposure"])):
			return false
	return data.get("weather") is Dictionary and WeatherModel.valid(data["weather"])

static func migrate(data: Dictionary) -> Dictionary:
	var output := data.duplicate(true)
	if int(output.get("version", 0)) == 1:
		var items: Dictionary = output["inventory"].duplicate()
		items["shelter"] = 0
		output = {"version": 2, "seed": output["seed"],
			"players": {"1": {"position": output["position"], "hp": output["hp"], "inventory": items}},
			"cut": output["cut"], "fires": output["fires"], "shelters": [],
			"phase": output["phase"], "weather": WeatherModel.new().serialize()}
	for i in range(output["cut"].size()):
		output["cut"][i] = int(output["cut"][i])
	for id in output["players"]:
		var player: Dictionary = output["players"][id]
		player["hp"] = int(player["hp"])
		for key in player["inventory"]:
			player["inventory"][key] = int(player["inventory"][key])
	return output

static func read_slot(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	if file.get_length() > MAX_BYTES:
		file.close()
		return {}
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK or not parser.data is Dictionary:
		return {}
	var envelope: Dictionary = parser.data
	var seq: Variant = envelope.get("sequence")
	var payload: Variant = envelope.get("payload")
	var digest: Variant = envelope.get("digest")
	if not integer(seq, 1, 1000000000) or not payload is String or not digest is String:
		return {}
	if ("%d:%s" % [int(seq), payload]).sha256_text() != digest:
		return {}
	if parser.parse(payload) != OK or not valid(parser.data):
		return {}
	return {"sequence": int(seq), "data": migrate(parser.data)}

static func newest(folder: String) -> Dictionary:
	var a := read_slot(folder.path_join("world.a.json"))
	var b := read_slot(folder.path_join("world.b.json"))
	if a.is_empty():
		return b
	if b.is_empty():
		return a
	return a if a["sequence"] >= b["sequence"] else b

static func load_world(folder: String = "user://world") -> Dictionary:
	return newest(folder).get("data", {}).duplicate(true)

static func lock_key(folder: String) -> String:
	return ProjectSettings.globalize_path(folder).simplify_path().trim_suffix("/")

static func acquire_lock(folder: String = "user://world") -> String:
	var absolute := lock_key(folder)
	if owned_locks.has(absolute):
		return ""
	var error := DirAccess.make_dir_recursive_absolute(absolute)
	if error != OK:
		return "Não foi possível criar a pasta de salvamento: %s" % error_string(error)
	var lock_path := absolute.path_join(".writer-lock")
	error = DirAccess.make_dir_absolute(lock_path)
	if error != OK:
		return "Salvamento bloqueado por .writer-lock. Pare outros servidores; após uma queda, remova o lock somente com todos os escritores parados."
	var owner := FileAccess.open(lock_path.path_join("owner.txt"), FileAccess.WRITE)
	if owner == null:
		DirAccess.remove_absolute(lock_path)
		return "Não foi possível registrar o proprietário do lock."
	owner.store_string("pid=%d\n" % OS.get_process_id())
	owner.close()
	owned_locks[absolute] = true
	return ""

static func release_lock(folder: String = "user://world") -> void:
	var absolute := lock_key(folder)
	if not owned_locks.has(absolute):
		return
	var lock_path := absolute.path_join(".writer-lock")
	DirAccess.remove_absolute(lock_path.path_join("owner.txt"))
	DirAccess.remove_absolute(lock_path)
	owned_locks.erase(absolute)

static func save_world(data: Dictionary, folder: String = "user://world") -> String:
	if not valid(data):
		return "Estado inválido; nenhum snapshot foi substituído."
	var lock_error := acquire_lock(folder)
	if not lock_error.is_empty():
		return lock_error
	var latest := newest(folder)
	var seq: int = int(latest.get("sequence", 0)) + 1
	if seq > 1000000000:
		return "Limite de sequência atingido."
	var suffix := "a" if seq % 2 == 1 else "b"
	var target := folder.path_join("world.%s.json" % suffix)
	var temporary := target + ".tmp"
	var payload := JSON.stringify(migrate(data))
	if payload.to_utf8_buffer().size() > MAX_BYTES / 2:
		return "Snapshot excede o limite de tamanho."
	var envelope := {"sequence": seq, "payload": payload,
		"digest": ("%d:%s" % [seq, payload]).sha256_text()}
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return "Falha ao abrir snapshot temporário: %s" % error_string(FileAccess.get_open_error())
	file.store_string(JSON.stringify(envelope))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return "Falha de escrita: %s" % error_string(error)
	if read_slot(temporary).is_empty():
		return "A verificação do snapshot temporário falhou."
	var absolute_target := ProjectSettings.globalize_path(target)
	if FileAccess.file_exists(target):
		error = DirAccess.remove_absolute(absolute_target)
		if error != OK:
			return "Falha ao substituir snapshot inativo: %s" % error_string(error)
	error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), absolute_target)
	if error != OK:
		return "Falha ao promover snapshot: %s" % error_string(error)
	return ""
