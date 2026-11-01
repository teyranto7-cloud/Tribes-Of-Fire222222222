extends CanvasLayer
## Presentation only: inventory, weather and networking commands are owned by Main.

var game
var language: int = 0
var mode: String = "loading"
var stats: Label
var hint: Label
var notice_label: Label
var exposure_label: Label
var panel: PanelContainer
var column: VBoxContainer
var shade: ColorRect
var cross: Label
var notice_left: float = 0.0
var previous_panel: String = "menu"
var inventory_signature: String = ""
var refresh_left: float = 0.0
var sensitivity_value: float = 0.003
var root: Control

const INK := Color("#e8e6d0")
const GOLD := Color("#eeb777")
const MUTED := Color("#b0c5b6")


func t(pt: String, en: String) -> String:
	return pt if language == 0 else en


func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme := Theme.new()
	theme.default_font_size = 17
	theme.set_color("font_color", "Label", INK)
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", GOLD)
	theme.set_color("font_disabled_color", "Button", Color("#6f827a"))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var button_style := StyleBoxFlat.new()
		button_style.bg_color = Color("#29433d")
		if state == "hover" or state == "focus":
			button_style.bg_color = Color("#3a5746")
		elif state == "pressed":
			button_style.bg_color = Color("#705735")
		elif state == "disabled":
			button_style.bg_color = Color("#1d302d")
		button_style.corner_radius_top_left = 6
		button_style.corner_radius_top_right = 6
		button_style.corner_radius_bottom_left = 6
		button_style.corner_radius_bottom_right = 6
		button_style.content_margin_left = 16
		button_style.content_margin_right = 16
		button_style.content_margin_top = 9
		button_style.content_margin_bottom = 9
		theme.set_stylebox(state, "Button", button_style)
	root.theme = theme
	stats = Label.new()
	stats.position = Vector2(24, 18)
	stats.add_theme_font_size_override("font_size", 18)
	stats.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	stats.add_theme_constant_override("shadow_offset_x", 2)
	stats.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(stats)
	exposure_label = Label.new()
	exposure_label.position = Vector2(24, 102)
	exposure_label.add_theme_color_override("font_color", Color("#b6d9ef"))
	root.add_child(exposure_label)
	hint = Label.new()
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -78
	hint.offset_bottom = -20
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	hint.add_theme_constant_override("shadow_offset_x", 1)
	hint.add_theme_constant_override("shadow_offset_y", 1)
	root.add_child(hint)
	notice_label = Label.new()
	notice_label.position = Vector2(24, 158)
	notice_label.add_theme_color_override("font_color", GOLD)
	notice_label.add_theme_font_size_override("font_size", 18)
	root.add_child(notice_label)
	cross = Label.new()
	cross.text = "·"
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cross.add_theme_font_size_override("font_size", 32)
	root.add_child(cross)
	shade = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.03, 0.03, 0.64)
	root.add_child(shade)
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -300
	panel.offset_right = 300
	panel.offset_top = -308
	panel.offset_bottom = 308
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.065, 0.125, 0.115, 0.98)
	style.border_color = Color("#a08052")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 25
	style.content_margin_right = 25
	style.content_margin_top = 20
	style.content_margin_bottom = 18
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 12
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	scroll.add_child(column)
	get_viewport().size_changed.connect(_fit_panel)
	_fit_panel()
	loading(t("Preparando o mundo…", "Preparing the world…"))


func _fit_panel() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var half_width := minf(300.0, viewport_size.x * 0.5 - 12.0)
	var half_height := minf(308.0, viewport_size.y * 0.5 - 12.0)
	panel.offset_left = -half_width
	panel.offset_right = half_width
	panel.offset_top = -half_height
	panel.offset_bottom = half_height


func text(value: String, size: int = 17, tint: Color = INK) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", tint)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(label)
	return label


func button(value: String, action: Callable) -> Button:
	var control := Button.new()
	control.text = value
	control.custom_minimum_size.y = 40
	control.pressed.connect(action)
	column.add_child(control)
	return control


func clear() -> void:
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()


func _heading(subtitle: String) -> void:
	text("TRIBES OF FIRE", 32, GOLD)
	text(subtitle, 17, MUTED)
	var divider := HSeparator.new()
	column.add_child(divider)


func _footer() -> void:
	text(t("Criado por felipealx", "Created by felipealx"), 14, MUTED)


func loading(value: String) -> void:
	mode = "loading"
	if game != null:
		game.set_controls(false)
	panel.show()
	shade.show()
	cross.hide()
	clear()
	_heading(t("Uma nova chama. Uma nova jornada.", "A new flame. A new journey."))
	text(value, 19)
	_footer()


func show_panel(value: String) -> void:
	mode = value
	game.set_controls(value == "")
	panel.visible = value != ""
	shade.visible = value != ""
	cross.visible = value == ""
	if value == "":
		return
	clear()
	match value:
		"inventory":
			_inventory()
		"network":
			_network()
		"settings":
			_settings()
		"weather":
			_weather()
		"menu":
			_main_menu()
		"loading":
			loading(t("Conectando…", "Connecting…"))
		_:
			_pause()
	_footer()


func _main_menu() -> void:
	_heading(t("Sobrevivência • exploração • construção", "Survival • exploration • building"))
	button(t("Continuar jornada salva", "Continue saved journey"), Callable(game, "load_game")).disabled = game.saved.is_empty()
	button(t("Nova jornada local", "New local journey"), Callable(game, "new_game"))
	button(t("Hospedar / Conectar por IP", "Host / Connect by IP"), func(): show_panel("network"))
	button(t("Configurações", "Settings"), func():
		previous_panel = "menu"
		show_panel("settings"))
	button(t("Sair", "Quit"), Callable(game, "quit_game"))
	text(t("Versão em desenvolvimento. A nova jornada substitui o progresso local ao salvar.",
		"Development build. A new journey replaces local progress when saved."), 14, MUTED)


func _pause() -> void:
	_heading(t("ACAMPAMENTO", "CAMP"))
	button(t("Retomar jornada", "Resume journey"), func(): show_panel(""))
	var save_button := button(t("Salvar [F5]", "Save [F5]"), Callable(game, "save_game"))
	var load_button := button(t("Carregar [F9]", "Load [F9]"), Callable(game, "load_game"))
	if game.session != null and not game.session.is_authority():
		save_button.disabled = true
		load_button.disabled = true
		text(t("O servidor salva o mundo compartilhado.", "The server saves the shared world."), 14, MUTED)
	button(t("Configurações", "Settings"), func():
		previous_panel = "pause"
		show_panel("settings"))
	if game.session == null or game.session.is_authority():
		button(t("Clima • administrador", "Weather • administrator"), func(): show_panel("weather"))
	button(t("Sair do jogo", "Quit game"), Callable(game, "quit_game"))
	text(t("O tempo do mundo continua enquanto o processo está ativo.",
		"World time continues while the process is running."), 14, MUTED)


func _inventory() -> void:
	_heading(t("INVENTÁRIO & FABRICAÇÃO", "INVENTORY & CRAFTING"))
	if game.inventory == null:
		text(t("Aguardando inventário do servidor…", "Waiting for server inventory…"))
		button(t("Voltar [Tab]", "Back [Tab]"), func(): show_panel(""))
		return
	inventory_signature = str(game.inventory.items)
	text(t("Madeira: %d    Fogueiras: %d    Abrigos: %d", "Wood: %d    Campfires: %d    Shelters: %d") % [
		game.inventory.count("wood"), game.inventory.count("campfire"), game.inventory.count("shelter")], 19)
	text(t("O machado está sempre disponível. Duas árvores fornecem madeira para uma fogueira.",
		"Your axe is always available. Two trees provide the wood for a campfire."), 14, MUTED)
	button(t("Fabricar fogueira • 8 madeiras", "Craft campfire • 8 wood"), Callable(game, "craft_fire")).disabled = game.inventory.count("wood") < 8
	button(t("Fabricar abrigo com telhado • 12 madeiras", "Craft roofed shelter • 12 wood"), Callable(game, "craft_shelter")).disabled = game.inventory.count("wood") < 12
	button(t("Equipar machado [1]", "Equip axe [1]"), func(): _equip(1))
	button(t("Equipar fogueira [2]", "Equip campfire [2]"), func(): _equip(2))
	button(t("Equipar abrigo [3]", "Equip shelter [3]"), func(): _equip(3))
	button(t("Voltar [Tab]", "Back [Tab]"), func(): show_panel(""))


func _equip(value: int) -> void:
	game.tool = value
	show_panel("")


func _network() -> void:
	_heading(t("PARTIDA MULTIPLAYER", "MULTIPLAYER GAME"))
	text(t("Conexão direta por IP. O anfitrião controla movimento, coleta, construções e clima.",
		"Direct IP connection. The host controls movement, gathering, building and weather."), 15, MUTED)
	text(t("Endereço do servidor", "Server address"))
	var address := LineEdit.new()
	address.text = "127.0.0.1"
	address.placeholder_text = "192.168.1.10"
	address.max_length = 253
	column.add_child(address)
	text(t("Porta UDP", "UDP port"))
	var port := SpinBox.new()
	port.min_value = 1024
	port.max_value = 65535
	port.value = 24567
	port.step = 1
	port.rounded = true
	column.add_child(port)
	button(t("Hospedar neste computador", "Host on this computer"), func():
		var selected_port := int(port.value)
		loading(t("Iniciando servidor…", "Starting server…"))
		game.host_game(selected_port))
	button(t("Conectar ao servidor", "Connect to server"), func():
		var selected_address := address.text.strip_edges()
		var selected_port := int(port.value)
		if selected_address.is_empty() or selected_address.contains("/") or selected_address.contains("://"):
			notify_message(t("Informe somente o IP ou nome do servidor.", "Enter only the server IP or hostname."))
			return
		loading(t("Conectando ao servidor…", "Connecting to server…"))
		game.join_game(selected_address, selected_port))
	button(t("Voltar", "Back"), func(): show_panel("menu"))
	text(t("Multiplayer experimental; capacidade de 100 jogadores ainda não validada. Pela Internet, o anfitrião precisa liberar a porta UDP no roteador.",
		"Experimental multiplayer; 100-player capacity has not been validated. Internet hosting requires forwarding the UDP port on your router."), 14, MUTED)


func _settings() -> void:
	_heading(t("CONFIGURAÇÕES", "SETTINGS"))
	var qualities := [t("Baixo", "Low"), t("Médio", "Medium"), t("Alto", "High"), "Ultra"]
	button(t("Qualidade: ", "Quality: ") + qualities[clampi(game.quality, 0, 3)], func():
		game.set_quality((game.quality + 1) % 4)
		show_panel("settings"))
	text(t("Resolução da janela", "Window resolution"), 15, MUTED)
	var resolutions := OptionButton.new()
	var sizes := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
	var current_size := DisplayServer.window_get_size()
	for i in range(sizes.size()):
		resolutions.add_item("%d × %d" % [sizes[i].x, sizes[i].y])
		if sizes[i] == current_size:
			resolutions.select(i)
	resolutions.item_selected.connect(func(index: int): game.set_resolution(sizes[index]))
	column.add_child(resolutions)
	var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	button(t("Tela cheia: ", "Fullscreen: ") + _on_off(fullscreen), func():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
		show_panel("settings"))
	button("VSync: " + _on_off(game.vsync), func():
		game.vsync = not game.vsync
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if game.vsync else DisplayServer.VSYNC_DISABLED)
		show_panel("settings"))
	text(t("Limite de FPS", "Frame rate limit"), 15, MUTED)
	var fps := OptionButton.new()
	var fps_values := [30, 60, 120, 144, 0]
	for i in range(fps_values.size()):
		fps.add_item(t("Sem limite", "Unlimited") if fps_values[i] == 0 else str(fps_values[i]))
		if fps_values[i] == Engine.max_fps:
			fps.select(i)
	fps.item_selected.connect(func(index: int): game.set_fps(fps_values[index]))
	column.add_child(fps)
	text(t("Sensibilidade do mouse", "Mouse sensitivity"), 15, MUTED)
	var sensitivity := HSlider.new()
	sensitivity.min_value = 0.001
	sensitivity.max_value = 0.008
	sensitivity.step = 0.0001
	sensitivity.value = sensitivity_value
	sensitivity.custom_minimum_size.y = 26
	sensitivity.value_changed.connect(func(value: float):
		sensitivity_value = value
		game.set_sensitivity(value))
	column.add_child(sensitivity)
	button(t("Som: ", "Sound: ") + _on_off(game.sound), func():
		game.sound = not game.sound
		AudioServer.set_bus_mute(0, not game.sound)
		show_panel("settings"))
	button("Português / English", func():
		language = 1 - language
		show_panel("settings"))
	button(t("Voltar", "Back"), func(): show_panel(previous_panel))


func _weather() -> void:
	_heading(t("CLIMA • ADMINISTRADOR", "WEATHER • ADMINISTRATOR"))
	if game.session != null and not game.session.is_authority():
		text(t("Somente o anfitrião pode alterar o clima.", "Only the host can change the weather."))
	else:
		text(t("Transições graduais. A chuva só causa o primeiro dano após 55 segundos contínuos sem abrigo.",
			"Gradual transitions. Rain causes its first damage after 55 continuous seconds without shelter."), 15, MUTED)
		for choice in [["clear", "Céu limpo", "Clear sky"], ["light_rain", "Chuva fraca", "Light rain"],
			["heavy_rain", "Chuva forte", "Heavy rain"], ["storm", "Tempestade", "Storm"], ["fog", "Neblina", "Fog"]]:
			var weather_name: String = choice[0]
			button(t(choice[1], choice[2]), func():
				game.request_weather(weather_name)
				notify_message(t("Transição climática solicitada.", "Weather transition requested.")))
	button(t("Voltar", "Back"), func(): show_panel("pause"))


func _on_off(value: bool) -> String:
	return t("LIGADO", "ON") if value else t("DESLIGADO", "OFF")


func notify_message(value: String) -> void:
	notice_label.text = value
	notice_left = 6.0
	# Also visible above the dimmed background in menus.
	notice_label.z_index = 3


func _process(delta: float) -> void:
	notice_left -= delta
	notice_label.visible = notice_left > 0
	if game == null or game.player == null:
		stats.text = ""
		hint.text = ""
		exposure_label.text = ""
		return
	var equipped := t("Machado", "Axe")
	if game.tool == 2:
		equipped = t("Fogueira", "Campfire")
	elif game.tool == 3:
		equipped = t("Abrigo", "Shelter")
	var wood_count: int = game.inventory.count("wood") if game.inventory != null else 0
	stats.text = t("VIDA %d / 100   RESISTÊNCIA %d\nMADEIRA %d   %s   %s",
		"HEALTH %d / 100   STAMINA %d\nWOOD %d   %s   %s") % [
		game.player.vitals.hp, int(game.player.stamina), wood_count, game.clock.label(), equipped]
	if game.exposure != null:
		var seconds: float = game.exposure.exposure_seconds
		var wet: float = game.exposure.wetness
		var temperature: float = game.exposure.temperature
		var comfort: bool = game.exposure.comfort
		if seconds > 0:
			var warning := t("Procurando abrigo", "Seek shelter") if seconds < 40.0 else t("Exposição prolongada", "Prolonged exposure")
			exposure_label.text = t("CHUVA %ds   UMIDADE %d%%   %.1f°C\n%s • primeiro dano aos 55s", "RAIN %ds   WETNESS %d%%   %.1f°C\n%s • first damage at 55s") % [int(seconds), int(wet * 100.0), temperature, warning]
		elif wet > 0.02 or comfort:
			exposure_label.text = t("UMIDADE %d%%   %.1f°C   %s", "WETNESS %d%%   %.1f°C   %s") % [int(wet * 100.0), temperature, t("Aquecendo", "Warming") if comfort else t("Secando", "Drying")]
		else:
			exposure_label.text = ""
	hint.visible = mode == ""
	hint.text = t("WASD mover • Mouse câmera • Shift correr • Espaço pular\n1 machado • 2 fogueira • 3 abrigo • Clique usar • Tab inventário • Esc menu",
		"WASD move • Mouse camera • Shift sprint • Space jump\n1 axe • 2 campfire • 3 shelter • Click use • Tab inventory • Esc menu")
	refresh_left -= delta
	if mode == "inventory" and refresh_left <= 0.0 and game.inventory != null:
		refresh_left = 0.2
		if inventory_signature != str(game.inventory.items):
			show_panel("inventory")
