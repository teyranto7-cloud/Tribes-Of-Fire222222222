extends Node3D
const Shapes = preload("res://World/Shapes.gd")
const KINDS := ["stone", "coal", "copper_ore", "tin_ore", "iron_ore", "silver_ore", "gold_ore", "sulfur", "rare_ore", "berries", "fiber", "wood"]
var world
var nodes: Array[StaticBody3D] = []
var stocks: Array[int] = []
var hits: Array[int] = []
var _cooldowns: Dictionary = {}
func setup(value) -> void:
	world = value
	for i in range(22):
		var kind: String = KINDS[i % KINDS.size()]
		var p := Vector3(4, 0, -1) if i == 0 else Vector3(sin(i * 2.4) * (8 + i * 1.6), 0, cos(i * 2.4) * (8 + i * 1.6))
		if i == 9:
			p = Vector3(-4, 0, 1)
		p.y = world.height_at(p.x, p.z)
		var body := StaticBody3D.new()
		body.position = p
		add_child(body)
		var color := Color("#747a78")
		if kind == "berries" or kind == "fiber":
			color = Color("#456e40")
		elif kind != "stone":
			color = Color.from_hsv(float(i % 9) / 9, 0.3, 0.6)
		var base := Shapes.sphere(body, 0.55, Vector3(0, 0.4, 0), color)
		base.scale = Vector3(1.1, 0.8, 1.0)
		for j in range(5):
			var gem := Shapes.sphere(body, 0.13 if kind == "berries" else 0.19, Vector3(sin(j * 2.4) * 0.35, 0.55, cos(j * 2.4) * 0.35), Color("#ab4944") if kind == "berries" else color.lightened(0.16))
			gem.scale.y = 1.3
		Shapes.consolidate(body)
		var shape := SphereShape3D.new()
		shape.radius = 0.56
		Shapes.collider(body, shape, Vector3(0, 0.4, 0))
		nodes.append(body)
		stocks.append(8)
		hits.append(0)
func closest(body: Node3D, reach: float = 3.0, facing: bool = false) -> int:
	var chosen := -1
	for i in range(nodes.size()):
		var offset := nodes[i].global_position - body.global_position
		if stocks[i] <= 0 or offset.length() > reach:
			continue
		if facing and offset.normalized().dot(-body.global_basis.z) < 0.3:
			continue
		reach = offset.length()
		chosen = i
	return chosen
func mine(body, inventory, id: int, hand: bool = false) -> bool:
	if id < 0 or id >= nodes.size() or not body.authoritative or body.position.distance_to(nodes[id].position) > 3.0 or stocks[id] <= 0:
		return false
	var kind: String = KINDS[id % KINDS.size()]
	if hand and kind not in ["berries", "fiber", "stone", "wood"]:
		return false
	if not hand and inventory.equipped_item() not in ["pickaxe", "iron_pickaxe"]:
		return false
	var now := Time.get_ticks_msec()
	var key: int = body.get_instance_id()
	if now < int(_cooldowns.get(key, 0)) or body.stamina < 8:
		return false
	if not inventory.can_add(kind, 1):
		return false
	_cooldowns[key] = now + 650
	body.stamina -= 8
	body.attack_time = 0.55
	if not hand:
		inventory.wear_equipment("hand", 1)
	inventory.add(kind, 1)
	stocks[id] -= 1
	hits[id] += 1
	_refresh(id)
	return true
func capture() -> Array:
	return stocks.duplicate()
func restore(data: Array) -> void:
	if data.size() != stocks.size():
		return
	for i in range(data.size()):
		if not (data[i] is int or data[i] is float) or data[i] < 0 or data[i] > 8 or data[i] != floorf(data[i]):
			return
	for i in range(data.size()):
		stocks[i] = int(data[i])
		_refresh(i)
func _refresh(i: int) -> void:
	nodes[i].visible = stocks[i] > 0
	nodes[i].collision_layer = 1 if stocks[i] > 0 else 0
