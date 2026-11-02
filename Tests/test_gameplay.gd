extends SceneTree

const MainScene = preload("res://Scenes/Main.tscn")
const Store = preload("res://Persistence/Store.gd")
var checks: int = 0
var failed: int = 0
var game

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func hit_once() -> void:
	game.player.attack_time = 0.0
	game.player.stamina = 100.0
	game._receive_action(1, "attack")

func run() -> void:
	game = MainScene.instantiate()
	root.add_child(game)
	game.save_folder = "user://gameplay-tests/%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	while not game.ready_world:
		await process_frame
	game.new_game()
	game.set_process(false)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	await physics_frame
	await physics_frame
	check(game.running and game.player != null, "Main inicia jornada real com personagem")
	var tree = game.world.trees[0]
	game.player.position = tree.position + Vector3(0, 0.1, 2)
	game.player.rotation.y = 0.0
	game.player.yaw = 0.0
	game.inventory.items["wood"] = 9998
	hit_once()
	hit_once()
	hit_once()
	check(not tree.felled and tree.hits == 2 and game.inventory.count("wood") == 9998,
		"Inventário cheio não consome árvore nem concede madeira parcial")
	game.inventory.items["wood"] = 0
	hit_once()
	check(tree.felled and game.inventory.count("wood") == 4, "Árvore concede quatro madeiras uma única vez")
	hit_once()
	check(game.inventory.count("wood") == 4, "Novo golpe não duplica recompensa de árvore cortada")
	game.inventory.items["wood"] = 8
	game._receive_action(1, "craft_fire")
	check(game.inventory.count("wood") == 0 and game.inventory.count("campfire") == 1,
		"Comando autoritativo fabrica fogueira com custo exato")
	game._receive_action(1, "craft_fire")
	check(game.inventory.count("wood") == 0 and game.inventory.count("campfire") == 1,
		"Comando sem recursos não altera inventário")
	game.player.position = Vector3(0, game.world.height_at(0, 3) + 0.1, 3)
	await physics_frame
	var site: Dictionary = game.world.placement(game.player)
	check(bool(site["valid"]), "Main encontra terreno livre para construção")
	game._receive_action(1, "place_fire")
	check(game.world.fires.size() == 1 and game.inventory.count("campfire") == 0,
		"Posicionamento autoritativo cria fogueira e consome item")
	game.inventory.add("campfire", 1)
	await physics_frame
	game._receive_action(1, "place_fire")
	check(game.world.fires.size() == 1 and game.inventory.count("campfire") == 1,
		"Colisão recusa sobreposição sem consumir item")
	game.inventory.items["wood"] = 12
	game._receive_action(1, "craft_shelter")
	check(game.inventory.count("shelter") == 1 and game.inventory.count("wood") == 0,
		"Abrigo também possui fabricação funcional")
	var roof_at := Vector3(10, game.world.height_at(10, 0), 0)
	game.world.add_shelter(roof_at)
	game.player.position = roof_at + Vector3.UP * 0.05
	await physics_frame
	await physics_frame
	game.exposure.advance(54, true, false, game.player.vitals)
	check(game.world.is_sheltered(game.player), "Colisão física do telhado oferece abrigo")
	game.exposure.advance(1, true, game.world.is_sheltered(game.player), game.player.vitals)
	check(game.exposure.exposure_seconds == 0 and game.exposure.damage_count == 0,
		"Abrigo físico reinicia proteção climática antes do primeiro dano")
	game.player.position = roof_at + Vector3(4, 0.05, 0)
	await physics_frame
	game.exposure.advance(54, true, game.world.is_sheltered(game.player), game.player.vitals)
	game.player.vitals.hp = 60
	game.player.vitals.quiet_seconds = 2.5
	check(game.save_game(), "Main salva mundo completo com clima e jogadores")
	var before: Dictionary = game.snapshot()
	game.inventory.items["wood"] = 123
	game.player.vitals.hp = 20
	game.exposure.reset()
	game.load_game()
	game.player.set_physics_process(false)
	check(game.world.cut_ids().has(0) and game.world.fires.size() == 1 and game.world.shelters.size() == 1,
		"Carregar restaura árvore, fogueira e abrigo")
	check(game.inventory.count("wood") == before["players"]["1"]["inventory"]["wood"] and game.player.vitals.hp == 60,
		"Carregar restaura inventário e vida")
	check(is_equal_approx(game.exposure.exposure_seconds, 54) and is_equal_approx(game.player.vitals.quiet_seconds, 2.5),
		"Carregar preserva cronômetros de exposição e regeneração")
	game.exposure.advance(1, true, false, game.player.vitals)
	check(game.exposure.damage_count == 1, "Primeiro dano continua aos 55s após carregar")
	Store.release_lock(game.save_folder)
	game.running = false
	game.session.close()
	game.runtime.audio.stop()
	game.runtime.voice.stop()
	game._stop_audio(game)
	game.queue_free()
	await process_frame
	# Let the audio mixing thread release retired spatial playbacks after nodes exit.
	await create_timer(0.15).timeout
	print("GAMEPLAY CHECKS=%d FAILED=%d" % [checks, failed])
	quit(0 if failed == 0 else 1)
