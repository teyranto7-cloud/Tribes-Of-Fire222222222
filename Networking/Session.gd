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
	var error: Error = peer.create_server(port, remote_capacity, 3)
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
	var error: Error = peer.create_client(address.strip_edges(), port, 3)
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
	if data.size() > 4:
		return {}
	for key in data:
		if key not in ["move", "yaw", "jump", "sprint"]:
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
	return {"move": [vector.x, vector.y], "yaw": wrapf(float(angle), -PI, PI),
		"jump": jumping, "sprint": sprinting}

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
	var key := token.sha256_text()
	# A reconnect can reclaim an offline record, never another currently active peer.
	if key in _keys.values():
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
		_rate.erase("%d:input" % id)
		_rate.erase("%d:action" % id)
		peer_left.emit(id)
		# peer_left handlers can still resolve the stable player key while persisting.
		_keys.erase(id)

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

func _server_disconnected() -> void:
	if role != "client":
		return
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	local_id = 0
	if not _leaving:
		failed.emit("Servidor desconectado / Server disconnected.")
