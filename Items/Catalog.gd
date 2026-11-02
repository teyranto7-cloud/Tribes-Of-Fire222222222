extends RefCounted
const Balance = preload("res://Game/Balance.gd")
## Stable item identifiers shared by authority, UI and save migration.
const RESOURCES := ["wood", "stone", "fiber", "coal", "copper_ore", "tin_ore", "iron_ore", "silver_ore", "gold_ore", "sulfur", "rare_ore", "copper_ingot", "bronze_ingot", "iron_ingot", "steel_ingot", "raw_meat", "cooked_meat", "raw_fish", "cooked_fish", "berries", "water", "leather", "bone", "arrow"]
const WEAPONS := {"axe": 10, "club": 10, "spear": 15, "stone_sword": 12, "copper_sword": 17, "bronze_sword": 22, "iron_sword": 28, "steel_sword": 35, "bow": 16, "pickaxe": 5, "iron_pickaxe": 8}
const ARMOR := {"leather_armor": 0.12, "bone_armor": 0.18, "copper_armor": 0.25, "bronze_armor": 0.32, "iron_armor": 0.45, "steel_armor": 0.55}
const RECIPES := {
	"axe": {"cost": {"wood": 2, "stone": 3}, "station": "hand"},
	"campfire": {"cost": {"wood": 8}, "station": "hand"}, "shelter": {"cost": {"wood": 12}, "station": "hand"},
	"pickaxe": {"cost": {"wood": 4, "stone": 4}, "station": "hand"}, "club": {"cost": {"wood": 3}, "station": "hand"},
	"spear": {"cost": {"wood": 5, "stone": 3}, "station": "hand"}, "stone_sword": {"cost": {"wood": 3, "stone": 6}, "station": "workbench"},
	"copper_ingot": {"cost": {"copper_ore": 2, "coal": 1}, "station": "furnace"}, "bronze_ingot": {"cost": {"copper_ingot": 2, "tin_ore": 1, "coal": 1}, "station": "furnace"},
	"iron_ingot": {"cost": {"iron_ore": 2, "coal": 1}, "station": "furnace"}, "steel_ingot": {"cost": {"iron_ingot": 2, "coal": 2}, "station": "furnace"},
	"copper_sword": {"cost": {"copper_ingot": 3, "wood": 2}, "station": "workbench"}, "bronze_sword": {"cost": {"bronze_ingot": 3, "wood": 2}, "station": "workbench"},
	"iron_sword": {"cost": {"iron_ingot": 3, "wood": 2}, "station": "workbench"}, "steel_sword": {"cost": {"steel_ingot": 3, "wood": 2}, "station": "workbench"},
	"bow": {"cost": {"wood": 6, "fiber": 4}, "station": "workbench"}, "arrow": {"cost": {"wood": 1, "stone": 1}, "station": "hand"},
	"shield": {"cost": {"wood": 6, "leather": 2}, "station": "workbench"}, "leather_armor": {"cost": {"leather": 6, "fiber": 2}, "station": "workbench"},
	"bone_armor": {"cost": {"bone": 6, "leather": 3}, "station": "workbench"}, "iron_armor": {"cost": {"iron_ingot": 6, "leather": 3}, "station": "workbench"},
	"iron_pickaxe": {"cost": {"iron_ingot": 3, "wood": 4}, "station": "workbench"},
	"copper_armor": {"cost": {"copper_ingot": 3, "leather": 3}, "station": "workbench"},
	"bronze_armor": {"cost": {"bronze_ingot": 3, "leather": 3}, "station": "workbench"},
	"steel_armor": {"cost": {"steel_ingot": 3, "leather": 3}, "station": "workbench"},
	"cooked_fish": {"cost": {"raw_fish": 1}, "station": "campfire"}, "cooked_meat": {"cost": {"raw_meat": 1}, "station": "campfire"}}
static func ids() -> Array:
	return ["axe", "wood", "campfire", "shelter"] + RESOURCES.filter(func(id): return id != "wood") + WEAPONS.keys().filter(func(id): return id != "axe") + ["shield"] + ARMOR.keys()
static func known(id: String) -> bool:
	return id in ["campfire", "shelter", "shield"] or id in RESOURCES or WEAPONS.has(id) or ARMOR.has(id)
static func get_item(id: String) -> Dictionary:
	return {"id": id, "stack": 1 if WEAPONS.has(id) or ARMOR.has(id) or id == "shield" else 99, "durability": 100} if known(id) else {}
static func damage(id: String) -> int:
	return int(Balance.section("weapons").get(id, WEAPONS.get(id, 0)))
static func armor(id: String) -> float:
	return float(Balance.section("armor").get(id, ARMOR.get(id, 0.0)))
static func recipe(id: String) -> Dictionary:
	return Balance.section("recipes").get(id, RECIPES.get(id, {})).duplicate(true)
static func display_name(id: String) -> String:
	var text := id.replace("_", " ").to_lower()
	if text.is_empty():
		return "—"
	# Catalog keys use sentence case; String.capitalize() title-cases every word.
	return TranslationServer.translate(text.left(1).to_upper() + text.substr(1))
