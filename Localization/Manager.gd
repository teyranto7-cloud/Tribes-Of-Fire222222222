extends RefCounted
const CODES := ["pt_BR", "en_US", "es", "fr", "de", "ja"]
const NAMES := ["Português (Brasil)", "English", "Español", "Français", "Deutsch", "日本語"]
var locale: String = "pt_BR"
var chosen: bool = false
var catalog: Dictionary = {}
var config_path: String
func _init(path: String = "user://language.cfg") -> void:
	config_path = path
	for code in CODES:
		var resource = load("res://Localization/%s.po" % code)
		if resource is Translation:
			TranslationServer.add_translation(resource)
	var config := ConfigFile.new()
	if config.load(config_path) == OK:
		var stored: Variant = config.get_value("language", "locale", "")
		if stored is String and stored in CODES:
			locale = stored
			chosen = true
	TranslationServer.set_locale(locale)
func select(code: String) -> bool:
	if not code in CODES:
		return false
	var config := ConfigFile.new()
	config.set_value("language", "locale", code)
	if config.save(config_path) != OK:
		return false
	locale = code
	chosen = true
	TranslationServer.set_locale(code)
	return true
func text(english: String, portuguese: String = "") -> String:
	var translated := TranslationServer.translate(english)
	if translated == english and locale == "pt_BR" and portuguese != "":
		return portuguese
	return translated
