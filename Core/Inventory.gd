extends RefCounted

const COST := 8
const SHELTER_COST := 12
const MAX_STACK := 9999
var items: Dictionary = {"axe": 1, "wood": 0, "campfire": 0, "shelter": 0}

func count(item: String) -> int:
	return int(items.get(item, 0))

func can_add(item: String, amount: int) -> bool:
	return items.has(item) and amount > 0 and count(item) <= MAX_STACK - amount

func add(item: String, amount: int) -> bool:
	if not can_add(item, amount):
		return false
	items[item] = count(item) + amount
	return true

func consume(item: String, amount: int) -> bool:
	if not items.has(item) or amount <= 0 or count(item) < amount:
		return false
	items[item] = count(item) - amount
	return true

func craft(item: String, cost: int) -> bool:
	if not can_add(item, 1) or cost <= 0 or count("wood") < cost:
		return false
	items["wood"] = count("wood") - cost
	items[item] = count(item) + 1
	return true

func craft_fire() -> bool:
	return craft("campfire", COST)

func craft_shelter() -> bool:
	return craft("shelter", SHELTER_COST)

func restore(data: Dictionary) -> void:
	for key in items:
		items[key] = clampi(int(data.get(key, 0)), 0, MAX_STACK)
	items["axe"] = 1
