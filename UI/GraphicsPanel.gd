extends VBoxContainer
var game
var previous: Dictionary = {}
var confirm_left: float = 0.0
var confirm_label: Label
func configure(value, _language: int = 0) -> void:
	game = value
	game.graphics.begin_edit()
	build()
func label_text(key: String) -> Label:
	var label := Label.new()
	label.text = tr(key)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
	return label
func button(key: String, callback: Callable) -> Button:
	var control := Button.new()
	control.text = tr(key)
	control.pressed.connect(callback)
	add_child(control)
	return control
func option(key: String, choices: Array, selected: int, callback: Callable) -> void:
	label_text(key)
	var control := OptionButton.new()
	for choice in choices:
		control.add_item(tr(str(choice)))
	control.select(selected)
	control.item_selected.connect(callback)
	add_child(control)
func slider(key: String, minimum: float, maximum: float, step: float, current: float, callback: Callable) -> void:
	var label := label_text(key)
	label.text += "  %.2f" % current
	var control := HSlider.new()
	control.min_value = minimum
	control.max_value = maximum
	control.step = step
	control.value = current
	control.value_changed.connect(func(v): label.text = tr(key) + "  %.2f" % v; callback.call(v))
	add_child(control)
func build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var settings = game.graphics
	option("Graphics", ["Very Low", "Low", "Medium", "High", "Ultra", "Custom"], int(settings.pending["preset"]), func(i): settings.choose_preset(i); build())
	option("Resolution", ["1280 × 720", "1600 × 900", "1920 × 1080"], [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)].find(settings.pending["resolution"]), func(i): settings.set_pending("resolution", [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)][i]))
	option("Window mode", ["Windowed", "Fullscreen", "Borderless"], int(settings.pending["window_mode"]), func(i): settings.set_pending("window_mode", i))
	slider("Render scale", 0.5, 1.0, 0.05, float(settings.pending["render_scale"]), func(v): settings.set_pending("render_scale", v))
	for entry in [["Shadows", "shadows", 0, 3, 1], ["Vegetation", "vegetation", 0, 4200, 100], ["View distance", "view_distance", 30, 200, 5], ["Water", "water", 0, 2, 1], ["Particles", "particles", 0, 3, 1], ["Lighting", "lighting", 0, 2, 1], ["Antialiasing", "antialiasing", 0, 3, 1], ["FPS", "fps", 0, 240, 30]]:
		var key: String = entry[1]
		slider(entry[0], entry[2], entry[3], entry[4], float(settings.pending[key]), func(v): settings.set_pending(key, v if key == "view_distance" else int(v)))
	for entry in [["VSync", "vsync"], ["Reflections", "reflections"], ["Clouds", "clouds"], ["Rain", "rain"], ["Postprocessing", "postprocess"], ["Show performance", "performance"]]:
		var key: String = entry[1]
		var check := CheckBox.new()
		check.text = tr(entry[0])
		check.button_pressed = settings.pending[key]
		check.toggled.connect(func(v): settings.set_pending(key, v))
		add_child(check)
	var support: Dictionary = settings.support()
	for entry in [["Ambient occlusion", "ao"], ["Volumetric fog", "volumetric"]]:
		if support[entry[1]]:
			var key: String = entry[1]
			var check := CheckBox.new()
			check.text = tr(entry[0])
			check.button_pressed = settings.pending[key]
			check.toggled.connect(func(v): settings.set_pending(key, v))
			add_child(check)
		else:
			label_text(tr(entry[0]) + ": " + tr("Not available") + " (Compatibility)")
	button("Apply", _apply)
	button("Cancel", func(): _rollback(); settings.cancel(); build())
	button("Reset defaults", func(): settings.reset_pending(); build())
	button("Detect automatically", func(): settings.detect_automatically(); build())
	confirm_label = label_text("")
	var keep := button("Confirm", _confirm)
	keep.name = "KeepSettings"
	var hw: Dictionary = settings.hardware()
	label_text("%s\n%s\n%s" % [hw["gpu"], hw["cpu"], hw["renderer"]])
func _apply() -> void:
	if confirm_left > 0:
		_rollback()
		game.graphics.begin_edit()
		build()
		return
	previous = game.graphics.applied.duplicate(true)
	var changed: bool = previous["resolution"] != game.graphics.pending["resolution"] or previous["window_mode"] != game.graphics.pending["window_mode"]
	var success: bool = game.graphics.preview(game.world, game.get_viewport(), game.player) if changed else game.graphics.apply_to(game.world, game.get_viewport(), game.player)
	if not success:
		game.hud.notify_message(game.graphics.last_error)
		return
	confirm_left = 15.0 if changed else 0.0
	if not changed:
		previous.clear()
func _confirm() -> void:
	if confirm_left <= 0:
		return
	if not game.graphics.persist():
		game.hud.notify_message(game.graphics.last_error)
		_rollback()
		return
	confirm_left = 0
	previous.clear()
	confirm_label.text = ""
func _rollback() -> void:
	if confirm_left > 0 and not previous.is_empty():
		game.graphics.applied = previous.duplicate(true)
		game.graphics.pending = previous.duplicate(true)
		if is_instance_valid(game.world) and game.is_inside_tree():
			game.graphics.apply_current(game.world, game.get_viewport(), game.player)
	confirm_left = 0
	previous.clear()
func _process(delta: float) -> void:
	if confirm_left > 0:
		confirm_left -= delta
		confirm_label.text = tr("Keep these settings?") + " %ds" % ceili(confirm_left)
		if confirm_left <= 0:
			confirm_left = 0.01
			_rollback()
			build()
func _exit_tree() -> void:
	_rollback()
