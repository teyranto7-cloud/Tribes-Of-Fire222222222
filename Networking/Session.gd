extends Node
## ENet transports intentions to the authority; clients never provide gameplay results.
## All peers must mount this node at /root/TribesOfFire/Session.

signal peer_joined(id: int)
signal peer_left(id: int)
signal state_received(state: Dictionary)
signal intent_received(id: int, intent: Dictionary)
signal action_received(id: int, action: String)
signal connection_ready()
signal failed(message: String)
signal command_received(id: int, command: String, data: Dictionary)
signal event_received(kind: String, data: Dictionary)
signal voice_requested(id: int, sequence: int, packet: PackedByteArray, channel: String, target: String)
signal voice_received(id: int, sequence: int, packet: PackedByteArray, channel: String)
const COMMANDS := ["appearance", "eat", "drink", "cook", "respawn", "inventory_move", "inventory_drop", "equip", "unequip", "craft", "interact", "combat", "mine", "build", "tribe_create", "tribe_invite", "tribe_accept", "tribe_leave", "tribe_kick", "tribe_leader", "chat", "group_create", "group_invite", "group_accept", "group_leave", "group_kick", "call_invite", "call_accept", "call_leave", "block"]

const DEFAULT_PORT := 24567
const MAX_PLAYERS := 100
const INPUTS_PER_SECOND := 90
const ACTIONS_PER_SECOND := 12
const GAME_ACTIONS := ["attack", "craft_fire", "craft_shelter", "place_fire", "place_shelter"]
const ADMIN_ACTIONS := ["save", "weather_clear", "weather_light_rain", "weather_heavy_rain", "weather_storm", "weather_fog"]

var role: String = "offline"
var local_id: int = 1
var maximum_players: int = 16
var accepted_peers: Dictionary = {}
var rejected_commands: int = 0
var _rate: Dictionary = {}
var _pending: Dictionary = {}
var _keys: Dictionary = {}
var _identity: String = ""
var _leaving: bool = false
var _world_owner: String = ""

func _ready() -> void:
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_server_disconnected)

func _process(_delta: float) -> void:
	if role not in ["host", "dedicated"]:
		return
	for id in _pending.keys():
		if Time.get_ticks_msec() - int(_pending[id]) > 10000:
			_pending.erase(id)
			multiplayer.multiplayer_peer.disconnect_peer(id)

func player_key(id: int) -> String:
	return "1" if id == 1 else str(_keys.get(id, ""))

func local_identity_hash() -> String:
	if _identity.is_empty() and not _load_identity():
		return ""
	return _identity.sha256_text()

func set_world_owner(identity_hash: String) -> void:
	_world_owner = identity_hash if _valid_identity(identity_hash) else ""

func set_local_profile_key(key: String) -> void:
	if role == "client" and local_id > 1 and (key == "1" or _valid_identity(key)):
		_keys[local_id] = key

func profile_key_for_identity(identity_hash: String) -> String:
	var key := "1" if not _world_owner.is_empty() and identity_hash == _world_owner else identity_hash
	if key in _keys.values() or (role == "host" and key == "1"):
		return ""
	return key

static func _valid_identity(value: String) -> bool:
	if value.length() != 64:
		return false
	for character in value:
		if character not in "0123456789abcdef":
			return false
	return true

func _load_identity() -> bool:
	var config := ConfigFile.new()
	var error: Error = config.load("user://identity.cfg")
	if error == OK:
		var stored: Variant = config.get_value("identity", "token", "")
		if stored is String and _valid_identity(stored):
			_identity = stored
			return true
	var random := Crypto.new().generate_random_bytes(32)
	if random.size() != 32:
		return false
	_identity = random.hex_encode()
	config = ConfigFile.new()
	config.set_value("identity", "token", _identity)
	return config.save("user://identity.cfg") == OK

func is_authority() -> bool:
	return role in ["offline", "host", "dedicated"]

func offline() -> void:
	close()
	role = "offline"
	local_id = 1
	_leaving = false
	connection_ready.emit.call_deferred()

func host_game(port: int = DEFAULT_PORT, max_players: int = 16, dedicated: bool = false) -> Error:
	if port < 1 or port > 65535 or max_players < 1 or max_players > MAX_PLAYERS:
		return ERR_INVALID_PARAMETER
	close()
	var peer := ENetMultiplayerPeer.new()
	var remote_capacity: int = max_players if dedicated else maxi(1, max_players - 1)
	var error: Error = peer.create_server(port, remote_capacity, 4)
	if error != OK:
		return error
	maximum_players = max_players
	role = "dedicated" if dedicated else "host"
	local_id = 1
	# Gameplay is server-only: clients do not need peer-to-peer relay or peer announcements.
	# This also avoids racing relay notifications when several clients leave together.
	if multiplayer is SceneMultiplayer:
		multiplayer.server_relay = false
	multiplayer.multiplayer_peer = peer
	connection_ready.emit.call_deferred()
	return OK

func join_game(address: String, port: int = DEFAULT_PORT) -> Error:
	if address.strip_edges().is_empty() or address.length() > 253 or port < 1 or port > 65535:
		return ERR_INVALID_PARAMETER
	close()
	role = "client"
	local_id = 0
	if not _load_identity():
		failed.emit("Não foi possível salvar a identidade local / Could not save the local identity.")
		return ERR_FILE_CANT_WRITE
	var peer := ENetMultiplayerPeer.new()
	var error: Error = peer.create_client(address.strip_edges(), port, 4)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	return OK

func close() -> void:
	var transport: MultiplayerPeer = multiplayer.multiplayer_peer
	# Detach SceneMultiplayer before destroying ENet channels; its teardown can send packets.
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if transport != null:
		transport.close()
	accepted_peers.clear()
	_pending.clear()
	_keys.clear()
	_rate.clear()
	_world_owner = ""
	role = "offline"
	local_id = 1

func graceful_leave() -> void:
	if _client_connected():
		_leaving = true
		_leave.rpc_id(1)
		# Allow the server to stop streaming before the underlying ENet channels disappear.
		await get_tree().create_timer(0.5).timeout
	close()

func send_intent(data: Dictionary) -> void:
	var clean := sanitize_intent(data)
	if clean.is_empty():
		rejected_commands += 1
		return
	if is_authority():
		if role != "dedicated":
			intent_received.emit(1, clean)
	elif _client_connected():
		_submit_intent.rpc_id(1, clean)

func send_action(action: String) -> void:
	if action not in GAME_ACTIONS and action not in ADMIN_ACTIONS:
		rejected_commands += 1
		return
	if is_authority():
		if role != "dedicated" or action in ADMIN_ACTIONS:
			action_received.emit(1, action)
	elif action in GAME_ACTIONS and _client_connected():
		_submit_action.rpc_id(1, action)
	else:
		rejected_commands += 1

func broadcast(state: Dictionary) -> void:
	if role not in ["host", "dedicated"]:
		return
	var transport: ENetMultiplayerPeer = multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if transport == null:
		return
	# A full world snapshot may exceed the MTU, so use ENet's reliable fragmentation.
	# Check each transport too: disconnect callbacks can arrive after a physics frame.
	for id in accepted_peers:
		var peer: ENetPacketPeer = transport.get_peer(id)
		if peer != null and peer.get_state() == ENetPacketPeer.STATE_CONNECTED and peer.get_channels() > 0:
			_receive_state.rpc_id(id, state)

func _client_connected() -> bool:
	return role == "client" and local_id > 1 and multiplayer.multiplayer_peer is ENetMultiplayerPeer \
		and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func sanitize_intent(data: Dictionary) -> Dictionary:
	# Bound every accepted component before constructing vectors or touching physics.
	if data.size() > 7:
		return {}
	for key in data:
		if key not in ["move", "yaw", "jump", "sprint", "crouch", "block", "dodge"]:
			return {}
	var movement: Variant = data.get("move", [0.0, 0.0])
	var vector := Vector2.ZERO
	if movement is Vector2:
		vector = movement
	elif movement is Array and movement.size() == 2 \
			and _number(movement[0]) and _number(movement[1]):
		vector = Vector2(float(movement[0]), float(movement[1]))
	else:
		return {}
	if not vector.is_finite() or absf(vector.x) > 1.0 or absf(vector.y) > 1.0:
		return {}
	var angle: Variant = data.get("yaw", 0.0)
	var jumping: Variant = data.get("jump", false)
	var sprinting: Variant = data.get("sprint", false)
	if not _number(angle) or absf(float(angle)) > 100000.0 \
			or not jumping is bool or not sprinting is bool:
		return {}
	vector = vector.limit_length(1.0)
	var result := {"move": [vector.x, vector.y], "yaw": wrapf(float(angle), -PI, PI), "jump": jumping, "sprint": sprinting}
	for key in ["crouch", "block", "dodge"]:
		if data.has(key):
			if not data[key] is bool:
				return {}
			result[key] = data[key]
	return result

func _allowed(sender: int, kind: String, limit: int) -> bool:
	if role not in ["host", "dedicated"] or not accepted_peers.has(sender):
		rejected_commands += 1
		return false
	var key := "%d:%s" % [sender, kind]
	var now := Time.get_ticks_msec()
	var bucket: Dictionary = _rate.get(key, {"start": now, "count": 0})
	if now - int(bucket["start"]) >= 1000:
		bucket = {"start": now, "count": 0}
	bucket["count"] = int(bucket["count"]) + 1
	_rate[key] = bucket
	if int(bucket["count"]) > limit:
		rejected_commands += 1
		return false
	return true

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _submit_intent(data: Dictionary) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if not _allowed(sender, "input", INPUTS_PER_SECOND):
		return
	var clean := sanitize_intent(data)
	if clean.is_empty():
		rejected_commands += 1
		return
	intent_received.emit(sender, clean)

@rpc("any_peer", "call_remote", "reliable", 2)
func _submit_action(action: String) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if not _allowed(sender, "action", ACTIONS_PER_SECOND):
		return
	if action not in GAME_ACTIONS:
		rejected_commands += 1
		return
	action_received.emit(sender, action)

@rpc("authority", "call_remote", "reliable", 0)
func _receive_state(state: Dictionary) -> void:
	if role == "client":
		state_received.emit(state)

@rpc("any_peer", "call_remote", "reliable", 2)
func _authenticate(token: String) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if role not in ["host", "dedicated"] or not _pending.has(sender):
		return
	if not _valid_identity(token):
		_pending.erase(sender)
		multiplayer.multiplayer_peer.disconnect_peer(sender)
		return
	var key := profile_key_for_identity(token.sha256_text())
	# A reconnect can reclaim an offline record, never another currently active peer.
	if key.is_empty():
		_pending.erase(sender)
		multiplayer.multiplayer_peer.disconnect_peer(sender)
		return
	_pending.erase(sender)
	_keys[sender] = key
	accepted_peers[sender] = true
	peer_joined.emit(sender)

@rpc("any_peer", "call_remote", "reliable", 2)
func _leave() -> void:
	if role not in ["host", "dedicated"]:
		return
	var sender: int = multiplayer.get_remote_sender_id()
	_peer_disconnected(sender)
	var transport: ENetMultiplayerPeer = multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if transport != null:
		var peer: ENetPacketPeer = transport.get_peer(sender)
		if peer != null and peer.get_state() == ENetPacketPeer.STATE_CONNECTED:
			peer.peer_disconnect_later()

func _peer_connected(id: int) -> void:
	if role not in ["host", "dedicated"]:
		return
	var local_count := 1 if role == "host" else 0
	if accepted_peers.size() + _pending.size() + local_count >= maximum_players:
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	_pending[id] = Time.get_ticks_msec()

func _peer_disconnected(id: int) -> void:
	_pending.erase(id)
	if accepted_peers.erase(id):
		for bucket in _rate.keys():
			if str(bucket).begins_with("%d:" % id):
				_rate.erase(bucket)
		peer_left.emit(id)
		# peer_left handlers can still resolve the stable player key while persisting.
		_keys.erase(id)

func reject_peer(id: int, reason: String) -> void:
	if role not in ["host", "dedicated"] or not accepted_peers.has(id):
		return
	_rejected.rpc_id(id, reason.left(240))
	_peer_disconnected(id)
	var transport := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if transport != null:
		var peer := transport.get_peer(id)
		if peer != null:
			peer.peer_disconnect_later()

@rpc("authority", "call_remote", "reliable")
func _rejected(reason: String) -> void:
	if role == "client":
		failed.emit(reason)

func _connected() -> void:
	if role == "client":
		local_id = multiplayer.get_unique_id()
		_keys[local_id] = _identity.sha256_text()
		_authenticate.rpc_id(1, _identity)
		connection_ready.emit()

func _connection_failed() -> void:
	if role != "client":
		return
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	local_id = 0
	failed.emit("Não foi possível conectar ao servidor / Could not connect to server.")

static func valid_command(command: String, data: Dictionary) -> bool:
	if command not in COMMANDS or not _bounded(data, 0) or JSON.stringify(data).length() > 4096:
		return false
	if command == "appearance":
		return preload("res://Character/Appearance.gd").valid(data)
	var fields: Dictionary = {
		"eat": ["item"], "drink": [], "cook": [], "respawn": [], "inventory_move": ["from", "to", "amount"],
		"inventory_drop": ["slot", "amount"], "equip": ["slot"], "unequip": ["equipment"], "craft": ["recipe"], "interact": [], "mine": [], "combat": ["kind"], "build": ["piece"],
		"tribe_create": ["name"], "tribe_invite": ["target"], "tribe_accept": [], "tribe_leave": [], "tribe_kick": ["target"], "tribe_leader": ["target"],
		"chat": ["channel", "target", "text"], "group_create": ["name", "kind"], "group_invite": ["id", "target"], "group_accept": [], "group_leave": ["id"], "group_kick": ["id", "target"], "call_invite": ["target"], "call_accept": ["id"], "call_leave": ["id"], "block": ["target", "enabled"]}
	if not fields.has(command) or data.size() != fields[command].size():
		return false
	for key in fields[command]:
		if not data.has(key): return false
		if key in ["slot", "from", "to", "amount"]:
			if not (data[key] is int or data[key] is float) or data[key] != floorf(data[key]) or data[key] < (1 if key == "amount" else 0) or data[key] > (9999 if key == "amount" else 35): return false
		elif key == "enabled":
			if not data[key] is bool: return false
		elif not data[key] is String:
			return false
	if command == "combat" and data["kind"] not in ["light", "heavy", "ranged"]: return false
	if command == "unequip" and data["equipment"] not in ["hand", "offhand", "armor"]: return false
	if command == "chat" and (data["channel"] not in ["global", "local", "private", "group", "tribe", "diplomacy"] or data["text"].length() > 240): return false
	if command == "group_create" and data["kind"] not in ["group", "diplomacy"]: return false
	return true

static func _bounded(value: Variant, depth: int) -> bool:
	if depth > 3:
		return false
	if value is String:
		return value.length() <= 256 and not value.to_utf8_buffer().has(0)
	if value is bool or value == null:
		return true
	if value is int or value is float:
		return is_finite(float(value)) and absf(float(value)) <= 1000000000
	if value is Dictionary:
		if value.size() > 32:
			return false
		for key in value:
			if not key is String or not _bounded(key, depth + 1) or not _bounded(value[key], depth + 1):
				return false
		return true
	if value is Array:
		if value.size() > 24:
			return false
		for entry in value:
			if not _bounded(entry, depth + 1):
				return false
		return true
	return false

func send_command(command: String, data: Dictionary = {}) -> void:
	if not valid_command(command, data):
		rejected_commands += 1
		return
	if is_authority():
		command_received.emit(1, command, data.duplicate(true))
	elif _client_connected():
		_submit_command.rpc_id(1, command, data)

@rpc("any_peer", "call_remote", "reliable", 2)
func _submit_command(command: String, data: Dictionary) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not _allowed(sender, "command", 16) or not valid_command(command, data):
		rejected_commands += 1
		return
	command_received.emit(sender, command, data)

func notify(id: int, kind: String, data: Dictionary) -> void:
	if not is_authority():
		return
	if id == 1 and role != "dedicated":
		event_received.emit(kind, data)
	elif accepted_peers.has(id):
		_deliver_event.rpc_id(id, kind, data)

@rpc("authority", "call_remote", "reliable", 2)
func _deliver_event(kind: String, data: Dictionary) -> void:
	if role == "client":
		event_received.emit(kind, data)

func send_voice(sequence: int, packet: PackedByteArray, channel: String, target: String) -> void:
	if packet.size() < 5 or packet.size() > 512 or sequence < 0 or channel.length() > 24 or target.length() > 128:
		return
	if is_authority() and role != "dedicated":
		voice_requested.emit(1, sequence, packet, channel, target)
	elif _client_connected():
		_submit_voice.rpc_id(1, sequence, packet, channel, target)

@rpc("any_peer", "call_remote", "unreliable_ordered", 3)
func _submit_voice(sequence: int, packet: PackedByteArray, channel: String, target: String) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not _allowed(sender, "voice", 30) or sequence < 0 or packet.size() < 5 or packet.size() > 512 or channel.length() > 24 or target.length() > 128:
		return
	voice_requested.emit(sender, sequence, packet, channel, target)

func relay_voice(recipient: int, sender: int, sequence: int, packet: PackedByteArray, channel: String) -> void:
	if not is_authority():
		return
	if recipient == 1 and role != "dedicated":
		voice_received.emit(sender, sequence, packet, channel)
	elif accepted_peers.has(recipient):
		_deliver_voice.rpc_id(recipient, sender, sequence, packet, channel)

@rpc("authority", "call_remote", "unreliable_ordered", 3)
func _deliver_voice(sender: int, sequence: int, packet: PackedByteArray, channel: String) -> void:
	if role == "client" and packet.size() >= 5 and packet.size() <= 512:
		voice_received.emit(sender, sequence, packet, channel)

func _server_disconnected() -> void:
	if role != "client":
		return
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	local_id = 0
	if not _leaving:
		failed.emit("Servidor desconectado / Server disconnected.")
