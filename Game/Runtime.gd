extends Node
## Gameplay orchestration. Main keeps the legacy loop; modules own their rules.
const Needs = preload("res://Survival/Survival.gd")
const Tribes = preload("res://Tribes/System.gd")
const Channels = preload("res://Communication/Channels.gd")
const Voice = preload("res://Communication/Voice.gd")
const Appearance = preload("res://Character/Appearance.gd")
const Mining = preload("res://Mining/System.gd")
const Workshop = preload("res://Building/Workshop.gd")
const Combat = preload("res://Combat/Rules.gd")
const Wildlife = preload("res://Animals/Director.gd")
const Audio = preload("res://Audio/Manager.gd")
const Store = preload("res://Persistence/Store.gd")
var game
var tribes = Tribes.new()
var channels = Channels.new()
var voice
var needs: Dictionary = {}
var channel_state: Dictionary = {"groups": {}, "calls": {}, "invitation": {}, "blocked": []}
var messages: Array[Dictionary] = []
var mining
var workshops: Array = []
var _workshop_signature: int = 0
var _mine_signature: int = 0
var message_counter: int = 0
var drops: Array = []
var _drop_signature: int = 0
var combat = Combat.new()
var pvp_blocked: int = 0
var pvp_damage: int = 0
var wildlife
var _initial_animals: Array = []
var audio
signal message_added(data: Dictionary)
func configure(value) -> void:
	game = value
	voice = Voice.new()
	add_child(voice)
	voice.configure(game)
	audio = Audio.new()
	add_child(audio)
	audio.configure(game)
	game.session.event_received.connect(_event)
	game.session.voice_requested.connect(_route_voice)
	mining = Mining.new()
	game.world.add_child(mining)
	mining.setup(game.world)
	wildlife = Wildlife.new()
	game.world.add_child(wildlife)
	wildlife.setup(game.world)
	_initial_animals = wildlife.capture().duplicate(true)
	wildlife.damage_requested.connect(_animal_damage)
	var source := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.35
	sphere.height = 0.25
	source.mesh = sphere
	source.position = Vector3(4, game.world.height_at(4, 4) + 0.15, 4)
	source.material_override = preload("res://World/Shapes.gd").material(Color("#60a9b0"))
	source.add_to_group("potable_source")
	game.world.add_child(source)

func spawn(id: int, record: Dictionary) -> void:
	needs[id] = Needs.new()
	if record.get("survival") is Dictionary:
		needs[id].restore(record["survival"])
	var body = game.players[id]
	body.auto_respawn = false
	if record.get("appearance") is Dictionary:
		body.set_appearance(record["appearance"])
		body.creation_pending = false
	else:
		body.creation_pending = game.session.role == "dedicated" or (DisplayServer.get_name() != "headless" and game.cli.is_empty())
	body.visible = not body.creation_pending
	if record.get("inventory_state") is Dictionary:
		game.inventories[id].restore(record["inventory_state"])
	body.vitals.regen_block_left = float(record.get("regen_block_left", 0))
	body.respawned.connect(func():
		if needs.has(id):
			needs[id].reset())

func key(id: int) -> String:
	return game.session.player_key(id) if game.session.is_authority() else str(game.players[id].get_meta("key", ""))
func peer(identity: String) -> int:
	for id in game.players:
		if key(id) == identity:
			return id
	return 0
func positions() -> Dictionary:
	var result: Dictionary = {}
	for id in game.players:
		if not game.players[id].creation_pending:
			result[key(id)] = game.players[id].position
	return result
func player_record(id: int) -> Dictionary:
	var result := {"survival": needs[id].state(), "inventory_state": game.inventories[id].serialize(), "regen_block_left": game.players[id].vitals.regen_block_left}
	if not game.players[id].creation_pending:
		result["appearance"] = game.players[id].appearance.duplicate(true)
	return result
func save_state() -> Dictionary:
	var records: Array = []
	for station in workshops:
		records.append({"kind": station.kind, "position": [station.position.x, station.position.y, station.position.z], "owner": station.owner_key})
	var dropped: Array = []
	for drop in drops:
		dropped.append({"id": drop.get_meta("id"), "count": drop.get_meta("count"), "durability": drop.get_meta("durability", 100), "position": [drop.position.x, drop.position.y, drop.position.z]})
	return {"tribes": tribes.state(), "communication": channels.state(), "mining": mining.capture(), "workshops": records, "drops": dropped, "animals": wildlife.capture()}
func restore(data: Dictionary) -> void:
	tribes = Tribes.new()
	tribes.restore(data.get("tribes", {}))
	channels.restore(data.get("communication", {}))
	var resource_state: Array = data.get("mining", [])
	if resource_state.is_empty():
		resource_state.resize(22)
		resource_state.fill(8)
	mining.restore(resource_state)
	_restore_workshops(data.get("workshops", []))
	_restore_drops(data.get("drops", []))
	wildlife.restore(data.get("animals", _initial_animals), true)
func _restore_workshops(records: Array) -> void:
	for station in workshops:
		station.queue_free()
	workshops.clear()
	for record in records:
		var p: Array = record["position"]
		_add_workshop(record["kind"], Vector3(p[0], p[1], p[2]), record["owner"])
func _add_workshop(kind: String, at: Vector3, owner: String) -> void:
	var station := Workshop.new()
	game.world.add_child(station)
	station.setup(kind, at, owner)
	workshops.append(station)
func apply_state(data: Dictionary) -> void:
	tribes.restore(data.get("tribes", {}))
	wildlife.restore(data.get("animals", []), false)
	var mining_data: Array = data.get("mining", [])
	if hash(mining_data) != _mine_signature:
		mining.restore(mining_data)
		_mine_signature = hash(mining_data)
	var station_data: Array = data.get("workshops", [])
	if hash(station_data) != _workshop_signature:
		_restore_workshops(station_data)
		_workshop_signature = hash(station_data)
	var dropped: Array = data.get("drops", [])
	if hash(dropped) != _drop_signature:
		_restore_drops(dropped)
		_drop_signature = hash(dropped)

func _restore_drops(records: Array) -> void:
	for drop in drops:
		drop.queue_free()
	drops.clear()
	for record in records:
		var p: Array = record["position"]
		_add_drop(record["id"], int(record["count"]), Vector3(p[0], p[1], p[2]), int(record.get("durability", 100)))
func _add_drop(item: String, count: int, at: Vector3, wear: int = 100) -> void:
	var drop := Node3D.new()
	drop.position = at
	drop.set_meta("id", item)
	drop.set_meta("count", count)
	drop.set_meta("durability", clampi(wear, 0, 100))
	game.world.add_child(drop)
	var bag = preload("res://World/Shapes.gd").sphere(drop, 0.18, Vector3.UP * 0.2, Color("#b39761"))
	bag.scale.y = 1.3
	drops.append(drop)
func stations(body) -> Array:
	var result: Array = []
	if game.world.warmth_at(body.position):
		result.append("campfire")
	for station in workshops:
		if body.position.distance_to(station.position) < 4:
			result.append(station.kind)
	return result
func tick(delta: float) -> void:
	wildlife.tick(delta, game.players, game.session.is_authority())
	if game.session.is_authority():
		combat.tick(delta)
		for id in needs:
			if game.players.has(id) and not game.players[id].creation_pending:
				game.players[id].set_equipment(game.inventories[id].equipment)

func reset_local_communication() -> void:
	channel_state = {"groups": {}, "calls": {}, "invitation": {}, "blocked": []}
	messages.clear()
	message_counter = 0
	channels = Channels.new()
	tribes = Tribes.new()
	if voice != null:
		voice.stop()
func safe(id: int) -> bool:
	return needs.has(id) and needs[id].is_safe() and game.players[id].attack_time <= 0 and not game.players[id].blocking and game.players[id].dodging <= 0
func command(id: int, action: String, data: Dictionary) -> void:
	if not game.session.is_authority() or not game.running or not game.players.has(id):
		return
	var body = game.players[id]
	var inv = game.inventories[id]
	var identity := key(id)
	var accepted := false
	if action == "appearance":
		if not Appearance.valid(data) or str(data.get("name", "")).to_lower() in ["admin", "server", "system"]:
			_notify(id, false)
			return
		body.set_appearance(data)
		body.creation_pending = false
		body.show()
		if id == game.session.local_id:
			game.hud.show_panel("")
		accepted = true
	elif body.creation_pending:
		return
	elif action.begins_with("tribe_"):
		if action in ["tribe_invite", "tribe_kick", "tribe_leader"] and peer(str(data.get("target", ""))) == 0:
			return
		var before := tribes.state()
		accepted = tribes.command(identity, action, data)
		if accepted and not Store.payload_fits(game.snapshot()):
			tribes.restore(before)
			accepted = false
		publish_channels()
	elif action.begins_with("group_") or action.begins_with("call_") or action == "block":
		var before := channels.state()
		var before_calls: Dictionary = channels.calls.duplicate(true)
		var before_invites: Dictionary = channels.invitations.duplicate(true)
		accepted = channels.command(identity, action, data, positions().keys(), tribes)
		if accepted and not Store.payload_fits(game.snapshot()):
			channels.restore(before)
			channels.calls = before_calls
			channels.invitations = before_invites
			accepted = false
		publish_channels()
	elif action == "chat":
		var text := str(data.get("text", "")).strip_edges()
		if not channels.allow_text(identity, text):
			_notify(id, false)
			return
		var channel := str(data.get("channel", "global"))
		var targets := channels.recipients(identity, channel, str(data.get("target", "")), positions(), tribes)
		for recipient in targets:
			game.session.notify(peer(recipient), "chat", {"sender": body.appearance["name"], "key": identity, "channel": channel, "text": text, "timestamp": Time.get_unix_time_from_system()})
		return
	elif action == "respawn" and body.vitals.hp <= 0:
		body.respawn()
		accepted = true
	elif body.vitals.hp <= 0:
		return
	else:
		match action:
			"combat":
				var kind := str(data.get("kind", "light"))
				if kind == "light" and inv.equipped_item() == "bow":
					kind = "ranged"
				if kind in ["light", "heavy", "ranged"]:
					var result: Dictionary = combat.try_attack(body, inv, kind == "heavy", kind == "ranged")
					if result.get("ok", false):
						var target_body = combat.select_target(body, game.players.values() + wildlife.animals, float(result["range"]))
						if target_body != null:
							if target_body in wildlife.animals:
								wildlife.hit(target_body, int(result["damage"]))
							else:
								var target_id: int = game.players.find_key(target_body)
								if tribes.can_damage(identity, key(target_id)):
									var dealt: int = Combat.mitigate(int(result["damage"]), game.inventories[target_id], target_body.blocking, target_body.dodging > 0)
									target_body.vitals.damage(dealt)
									pvp_damage += dealt
								else:
									pvp_blocked += 1
						accepted = true
			"eat": accepted = needs[id].eat(inv, str(data.get("item", "berries")))
			"cook": accepted = needs[id].cook(inv, game.world.warmth_at(body.position))
			"drink":
				if inv.count("water") > 0 and needs[id].thirst < 100:
					inv.consume("water", 1)
					accepted = needs[id].drink()
				else:
					for source in get_tree().get_nodes_in_group("potable_source"):
						if source.global_position.distance_to(body.position) < 3:
							accepted = needs[id].drink()
			"craft": accepted = inv.craft_recipe(str(data.get("recipe", "")), stations(body))
			"equip": accepted = inv.equip(int(data.get("slot", -1)))
			"unequip": accepted = inv.unequip(str(data.get("equipment", "hand")))
			"inventory_move": accepted = inv.move_slot(int(data.get("from", -1)), int(data.get("to", -1)), int(data.get("amount", 9999)))
			"interact":
				accepted = wildlife.harvest(body, inv)
				for drop in drops:
					if accepted: break
					if drop.position.distance_to(body.position) < 2.5:
						if not _clear_interaction(body, drop.position + Vector3.UP * 0.2):
							continue
						if inv.add(str(drop.get_meta("id")), int(drop.get_meta("count")), int(drop.get_meta("durability", 100))):
							drops.erase(drop)
							drop.queue_free()
							accepted = true
						break
				if not accepted:
					accepted = mining.mine(body, inv, mining.closest(body), true)
				if not accepted:
					for source in get_tree().get_nodes_in_group("potable_source"):
						if source.global_position.distance_to(body.position) < 3:
							accepted = needs[id].drink()
			"inventory_drop":
				if drops.size() < 128:
					var taken: Dictionary = inv.take_slot(int(data.get("slot", -1)), int(data.get("amount", 1)))
					if not taken.is_empty():
						var at: Vector3 = body.position - body.global_basis.z
						at.y = game.world.height_at(at.x, at.z) + 0.1
						_add_drop(taken["id"], taken["count"], at, int(taken.get("durability", 100)))
						accepted = true
			"mine": accepted = mining.mine(body, inv, mining.closest(body, 3, true))
			"build":
				var kind := str(data.get("piece", ""))
				if kind in ["workbench", "furnace"] and workshops.size() < 32:
					var site: Dictionary = game.world.placement(body)
					var cost := {"wood": 12} if kind == "workbench" else {"stone": 12, "wood": 4}
					if site["valid"] and inv.transact(cost, {}):
						_add_workshop(kind, site["position"], identity)
						accepted = true
	if accepted:
		var sound: String = {"craft": "craft", "build": "build", "mine": "stone", "interact": "pickup", "combat": "combat"}.get(action, "pickup")
		emit_sound(sound, body.position)
	_notify(id, accepted)
func _notify(id: int, accepted: bool) -> void:
	game.session.notify(id, "notice", {"key": "Action completed" if accepted else "Action unavailable"})

func _clear_interaction(body, at: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(body.global_position + Vector3.UP, at, 1, [body.get_rid()])
	return game.world.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
func publish_channels() -> void:
	for id in game.players:
		game.session.notify(id, "channels", channels.public_state(key(id)))
func _event(kind: String, data: Dictionary) -> void:
	if kind == "chat":
		messages.append(data)
		message_counter += 1
		if messages.size() > 200:
			messages.pop_front()
		message_added.emit(data)
		audio.click()
	elif kind == "channels":
		channel_state = data
	elif kind == "notice":
		game.hud.notify_message(game.localization.text(str(data["key"])))
	elif kind == "sound":
		var p: Array = data["position"]
		audio.play(data["kind"], Vector3(p[0], p[1], p[2]))
func _route_voice(id: int, sequence: int, packet: PackedByteArray, channel: String, target: String) -> void:
	if not game.session.is_authority() or not game.running or not game.players.has(id) or game.players[id].creation_pending or game.players[id].vitals.hp <= 0:
		return
	if preload("res://Communication/ADPCM.gd").decode(packet).is_empty():
		return
	for recipient in channels.recipients(key(id), channel, target, positions(), tribes, true):
		var destination := peer(recipient)
		if destination != 0 and destination != id:
			game.session.relay_voice(destination, id, sequence, packet, channel)

func _animal_damage(id: int, amount: int) -> void:
	if game.session.is_authority() and game.players.has(id):
		var body = game.players[id]
		body.vitals.damage(Combat.mitigate(clampi(amount, 0, 20), game.inventories[id], body.blocking, body.dodging > 0))
		emit_sound("damage", body.position)

func emit_sound(kind: String, at: Vector3) -> void:
	for id in game.players:
		if game.players[id].position.distance_to(at) <= 24:
			game.session.notify(id, "sound", {"kind": kind, "position": [at.x, at.y, at.z]})
