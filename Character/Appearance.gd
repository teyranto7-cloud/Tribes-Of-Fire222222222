extends RefCounted
## Compact cosmetic data. Physics, reach and movement never depend on appearance.
const Shapes = preload("res://World/Shapes.gd")
const DEFAULT := {"name": "Survivor", "body": 0, "height": 1.48, "shoulders": 1.0, "volume": 1.0, "skin": 2, "eyes": 0, "eye_size": 1.0, "eye_spacing": 1.0, "eye_color": 0, "face": 1.0, "nose": 1.0, "mouth": 1.0, "ears": 1.0, "hair": 0, "hair_color": 0, "beard": 0, "clothing": 0}
const SKIN := [Color("#efd0ab"), Color("#dbaf83"), Color("#bc875e"), Color("#926244"), Color("#684832"), Color("#463426")]
const HAIR := [Color("#29251f"), Color("#50372a"), Color("#80583a"), Color("#c29b58"), Color("#a05332"), Color("#8a8c83"), Color("#ddd6bf")]
const EYES := [Color("#4b3024"), Color("#886140"), Color("#af8d36"), Color("#507850"), Color("#527e9c"), Color("#8a969b"), Color("#bb7835")]
static func valid(data: Dictionary) -> bool:
	if data.size() != DEFAULT.size():
		return false
	for key in DEFAULT:
		if not data.has(key):
			return false
	if not data["name"] is String or data["name"].strip_edges().length() < 2 or data["name"].length() > 24:
		return false
	for character in data["name"]:
		if character.unicode_at(0) < 32 or character in "<>[]{}\\/":
			return false
	for entry in [["body", 0, 1], ["skin", 0, 5], ["eyes", 0, 2], ["eye_color", 0, 6], ["hair", 0, 8], ["hair_color", 0, 6], ["beard", 0, 5], ["clothing", 0, 5]]:
		var value: Variant = data[entry[0]]
		if not (value is int or value is float) or not is_finite(float(value)) or value != floorf(value) or value < entry[1] or value > entry[2]:
			return false
	for entry in [["height", 1.35, 1.65], ["shoulders", 0.9, 1.15], ["volume", 0.85, 1.15], ["eye_size", 0.8, 1.2], ["eye_spacing", 0.85, 1.15], ["face", 0.85, 1.15], ["nose", 0.8, 1.2], ["mouth", 0.8, 1.2], ["ears", 0.8, 1.2]]:
		var value: Variant = data[entry[0]]
		if not (value is int or value is float) or not is_finite(float(value)) or value < entry[1] or value > entry[2]:
			return false
	return true

static func apply(player, data: Dictionary) -> void:
	if not valid(data):
		return
	var old: Node3D = player.avatar
	if is_instance_valid(old):
		player.remove_child(old)
		old.queue_free()
	player._materials.clear()
	player._build_avatar()
	player.appearance = data.duplicate(true)
	var skin: Color = SKIN[int(data["skin"])]
	player._materials["skin"].albedo_color = skin
	player._materials["skin_shadow"].albedo_color = skin.darkened(0.18)
	player._materials["hair"].albedo_color = HAIR[int(data["hair_color"])]
	player._materials["hair_highlight"].albedo_color = HAIR[int(data["hair_color"])].lightened(0.1)
	player._materials["eye"].albedo_color = EYES[int(data["eye_color"])]
	player.avatar.scale = Vector3(1.15 * float(data["volume"]), float(data["height"]) / 1.98, 1.07)
	player.torso.scale.x = float(data["shoulders"]) * (0.94 if int(data["body"]) == 1 else 1.0)
	player.head.scale = Vector3(float(data["face"]) * 1.13, 1.08, 1.04)
	var garments := ShaderMaterial.new()
	garments.shader = preload("res://Assets/Shaders/hide.gdshader")
	garments.set_shader_parameter("style", int(data["clothing"]))
	for mesh in player.torso.find_children("*", "MeshInstance3D", true, false):
		if mesh.material_override == player._materials["tunic"]:
			mesh.material_override = garments
	for mesh in player.head.get_children():
		if not mesh is MeshInstance3D:
			continue
		if mesh.material_override == player._materials["eye_white"] or mesh.material_override == player._materials["eye"]:
			mesh.scale *= Vector3.ONE * float(data["eye_size"])
			mesh.scale.y *= [1.0, 0.8, 1.2][int(data["eyes"])]
			mesh.position.x *= float(data["eye_spacing"])
		elif mesh.material_override in [player._materials["hair"], player._materials["hair_highlight"]] and mesh.position.y > 0.08:
			mesh.hide()
		elif absf(mesh.position.x) > 0.18:
			mesh.scale *= float(data["ears"])
		elif mesh.material_override == player._materials["skin"] and mesh.position.z < -0.17:
			mesh.scale *= float(data["nose"])
		elif mesh.material_override == player._materials["skin_shadow"]:
			mesh.scale.x *= float(data["mouth"])
	var hair := Node3D.new()
	hair.name = "HairStyle"
	player.head.add_child(hair)
	var hair_color: Color = HAIR[int(data["hair_color"])]
	var style := int(data["hair"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 102 + style
	for i in range(9 if style != 6 else 15):
		var angle := float(i) / 9 * TAU
		var location := Vector3(sin(angle) * 0.14, 0.15 + rng.randf() * 0.05, cos(angle) * 0.1)
		var lock := Shapes.sphere(hair, 0.10 if style != 6 else 0.07, location, hair_color.lightened(rng.randf() * 0.06))
		lock.scale = Vector3(0.85, [1.0, 1.5, 2.4, 1.1, 1.8, 1.1, 1.0, 1.9, 2.5][style], 0.85)
		lock.rotation.z = sin(angle) * 0.6
		if style in [2, 4, 7, 8]:
			lock.position.z += 0.08
			lock.position.y -= 0.05
		if style in [3, 4] and i > 4:
			lock.position = Vector3(0, 0.15 - (i - 5) * 0.08, 0.18)
		if style == 5 and absf(location.x) > 0.1:
			lock.hide()
	if int(data["beard"]) > 0:
		var beard := Shapes.sphere(player.head, 0.14, Vector3(0, -0.12, -0.10), hair_color)
		beard.scale = Vector3(0.9 if int(data["beard"]) != 4 else 0.45, 0.5 + int(data["beard"]) * 0.17, 0.9)
		if int(data["beard"]) == 5:
			beard.position.y = -0.06
			beard.scale = Vector3(0.9, 0.16, 0.5)
	# Original modeled knots, irregular hem and ties: not just a flat body texture.
	for i in range(7):
		var angle := float(i) / 7 * TAU
		var flap := Shapes.sphere(player.torso, 0.09, Vector3(sin(angle) * 0.23, -0.16, cos(angle) * 0.15), Color("#aa8350"))
		flap.scale = Vector3(0.8, 1.25 + sin(i * 4) * 0.25, 0.35)
		flap.material_override = garments
	if player.label != null:
		player.label.text = data["name"]
		player.label.font = preload("res://Assets/Fonts/NotoSansCJK-Regular.ttc")
		player.label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var rig = preload("res://Character/Rig.gd").new()
	rig.name = "CharacterRig"
	rig.setup(player)
	player.avatar.add_child(rig)
	player.set_equipment(player.visual_equipment, true)
