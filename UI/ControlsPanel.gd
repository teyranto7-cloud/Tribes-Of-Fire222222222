extends VBoxContainer
const ACTIONS := ["forward", "back", "left", "right", "sprint", "jump", "crouch", "dodge", "block", "heavy", "interact", "inventory", "push_to_talk", "chat"]
var waiting: String = ""
var game
var buttons: Dictionary = {}
func configure(value, _language: int = 0) -> void:
	game = value
	var label := Label.new()
	label.text = tr("Sensitivity")
	add_child(label)
	var sensitivity := HSlider.new()
	sensitivity.min_value = 0.0005
	sensitivity.max_value = 0.01
	sensitivity.step = 0.0001
	sensitivity.value = game.sensitivity
	sensitivity.value_changed.connect(game.set_sensitivity)
	add_child(sensitivity)
	var smooth := CheckBox.new()
	smooth.text = tr("Camera smoothing")
	smooth.button_pressed = game.camera_smoothing
	smooth.toggled.connect(func(v):
		game.camera_smoothing = v
		if game.player != null: game.player.camera_smoothing = v
		game.save_settings())
	add_child(smooth)
	for action in ACTIONS:
		var button := Button.new()
		buttons[action] = button
		button.pressed.connect(func(): waiting = action; button.text = tr(action.replace("_", " ").capitalize()) + ": …")
		add_child(button)
	refresh()
func refresh() -> void:
	for action in buttons:
		var events := InputMap.action_get_events(action)
		buttons[action].text = tr(action.replace("_", " ").capitalize()) + " : " + (events[0].as_text() if not events.is_empty() else "—")
func _unhandled_input(event: InputEvent) -> void:
	if waiting == "" or not event.is_pressed() or not (event is InputEventKey or event is InputEventMouseButton):
		return
	if event is InputEventKey and event.echo:
		return
	InputMap.action_erase_events(waiting)
	InputMap.action_add_event(waiting, event)
	var config := ConfigFile.new()
	config.load("user://controls.cfg")
	config.set_value("bindings", waiting, event)
	config.save("user://controls.cfg")
	waiting = ""
	get_viewport().set_input_as_handled()
	refresh()
static func load_bindings() -> void:
	var config := ConfigFile.new()
	if config.load("user://controls.cfg") != OK:
		return
	for action in ACTIONS:
		if not config.has_section_key("bindings", action): continue
		var event: Variant = config.get_value("bindings", action)
		if event is InputEventKey or event is InputEventMouseButton:
			InputMap.action_erase_events(action)
			InputMap.action_add_event(action, event)
