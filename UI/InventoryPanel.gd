extends VBoxContainer
const Catalog = preload("res://Items/Catalog.gd")
var game
var selected: int = 0
var buttons: Array[Button] = []
var detail: Label
var _signature: int = 0
func configure(value, _language: int = 0) -> void:
	game = value
	var grid := GridContainer.new()
	grid.columns = 6
	add_child(grid)
	for i in range(36):
		var button := preload("res://UI/InventorySlot.gd").new()
		button.game = game
		button.index = i
		button.custom_minimum_size = Vector2(72, 62)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 13)
		button.pressed.connect(func(): selected = i; _refresh(true))
		grid.add_child(button)
		buttons.append(button)
	detail = Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(detail)
	for action in ["Equip", "Unequip", "Eat", "Drop", "Repair"]:
		var button := Button.new()
		button.text = tr(action)
		button.pressed.connect(func(): _action(action))
		add_child(button)
	var instructions := Label.new()
	instructions.text = "⇄ " + tr("Split") + ": Shift + drag"
	add_child(instructions)
	var era: int = game.runtime.Profile.era(game.runtime.known_technologies(game.session.local_id))
	for id in Catalog.RECIPES:
		if int(Catalog.recipe(id).get("era",0))>era: continue
		var recipe_id: String = id
		var button := Button.new()
		var recipe: Dictionary = Catalog.recipe(id)
		button.text = tr("Crafting") + ": " + item_name(id) + "  " + cost_text(recipe["cost"]) + "  [" + tr(str(recipe["station"]).capitalize()) + "]"
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(func(): game.request_command("craft", {"recipe": recipe_id}))
		add_child(button)
	for entry in [["Campfire", 2], ["Shelter", 3]]:
		var value_tool: int = entry[1]
		var button := Button.new()
		button.text = tr("Equip") + ": " + tr(entry[0])
		button.pressed.connect(func(): game.tool = value_tool; game.hud.show_panel(""))
		add_child(button)
	for kind in ["foundation","floor","wall","window","door","roof","stairs","fence","bed","chest","garden","workbench","furnace"]:
		var piece: String = kind
		var button := Button.new()
		button.text = tr("Build") + ": " + tr(kind.capitalize()) + " • " + cost_text(preload("res://Game/Balance.gd").section("building")["costs"][kind])
		button.pressed.connect(func(): game.select_building(piece))
		add_child(button)
	_refresh(true)
func item_name(id: String) -> String:
	return Catalog.display_name(id)
func cost_text(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	for item in cost:
		parts.append("%s × %d" % [item_name(item), cost[item]])
	return ", ".join(parts)
func _process(_delta: float) -> void:
	_refresh()
func _action(action: String) -> void:
	var slot: Dictionary = game.inventory.serialize()["slots"][selected]
	match action:
		"Repair": game.request_command("repair", {"slot": selected})
		"Equip":
			game.request_command("equip", {"slot": selected})
			game.tool = 1
		"Unequip":
			game.request_command("unequip", {"equipment": "hand"})
		"Eat":
			game.request_command("eat", {"item": slot.get("id", "")})
		"Drop":
			game.request_command("inventory_drop", {"slot": selected, "amount": 1})
func _refresh(force: bool = false) -> void:
	if game == null or game.inventory == null:
		return
	var state: Dictionary = game.inventory.serialize()
	if not force and hash(state) == _signature:
		return
	_signature = hash(state)
	for i in range(buttons.size()):
		var slot: Dictionary = state["slots"][i]
		buttons[i].text = "—" if slot.is_empty() else item_name(slot["id"]) + "\n%d" % slot["count"]
		buttons[i].tooltip_text = buttons[i].text
	var current: Dictionary = state["slots"][selected]
	detail.text = str(selected + 1) + " • " + ("—" if current.is_empty() else item_name(current["id"]))
	for slot in state["equipment"]:
		var item: String = state["equipment"][slot]
		detail.text += "\n" + tr(slot.capitalize()) + ": " + (item_name(item) if item != "" else "—")
