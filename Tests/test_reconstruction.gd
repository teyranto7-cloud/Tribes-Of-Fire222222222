extends SceneTree
const Scene = preload("res://Scenes/Main.tscn")
const Terrain = preload("res://World/Terrain.gd")
const Store = preload("res://Persistence/Store.gd")
const Shapes = preload("res://World/Shapes.gd")
var checks: int = 0
var failed: int = 0
var game
func check(value: bool, message: String) -> void:
	checks+=1
	if not value: failed+=1;push_error(message)
func _initialize() -> void: call_deferred("run")
func advance(seconds: float) -> void: game.runtime._tick_activities(seconds)
func run() -> void:
	var a=Terrain.new({"seed":123,"generator":1,"size":320})
	var b=Terrain.new({"seed":123,"generator":1,"size":320})
	var c=Terrain.new({"seed":321,"generator":1,"size":320})
	var different:=false
	for p in [Vector2(40,30),Vector2(-83,65),Vector2(108,-39)]:
		check(is_equal_approx(a.height(p.x,p.y),b.height(p.x,p.y)),"Same seed reproduces sampled terrain")
		if absf(a.height(p.x,p.y)-c.height(p.x,p.y))>0.1: different=true
	check(different,"Distinct seeds produce distinct terrain")
	check(320*320>=6*128*128,"New continent exceeds six times the previous mesh area")
	check(a.locations[0]["position"]!=c.locations[0]["position"],"POI placement varies by seed")
	game=Scene.instantiate();root.add_child(game)
	while not game.ready_world: await process_frame
	game.save_folder="user://reconstruction/%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	game.new_game(123)
	game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
	await physics_frame;await physics_frame
	check(game.world.descriptor()["seed"]==123 and game.world.half_extent()==160,"Main creates the seeded expanded world")
	check(game.world._chunks.size()<400,"Terrain streams a subset of the 400 chunks")
	var tree=game.world.trees.filter(func(t):return t.tree_id==0)[0]
	game.player.position=tree.position+Vector3(0,0.1,2)
	game.player.rotation.y=0;game.player.yaw=0
	var wall:=StaticBody3D.new();game.world.add_child(wall)
	var shape:=BoxShape3D.new();shape.size=Vector3(3,3,0.25)
	Shapes.collider(wall,shape,tree.position+Vector3(0,1,1))
	await physics_frame;await physics_frame
	check(game.world.nearest_tree(game.player)==null,"A real wall blocks tree selection")
	check(not game.runtime.harvest_tree(1),"Server refuses tree harvesting through a wall")
	wall.free();await physics_frame
	game.player.position.y+=25
	check(game.world.nearest_tree(game.player)==null,"Tree reach includes the vertical distance")
	game.player.position=tree.position+Vector3(0,0.1,2)
	for i in range(3):
		game.player.attack_time=0;game.player.stamina=100
		check(game.runtime.harvest_tree(1),"A nearby valid axe strike begins an action")
		check(game.player.rig.action_kind=="gather" and game.player.rig.action_left>0,"Gathering is connected to the real skeleton animation controller")
		check(tree.hits==i and not tree.felled,"Resource changes only after the action finishes")
		advance(0.7)
	check(tree.felled and game.inventory.count("wood")==0 and game.runtime.drops.size()==1,"Felling creates physical wood on the ground rather than granting it")
	check(game.inventory.durability["axe"]==97,"Every valid tree strike wears the axe")
	check(game.world.resource_timers.has("0"),"Tree regeneration deadline is recorded")
	check(game.runtime._interact(1),"Collecting the ground object begins a real action")
	check(game.inventory.count("wood")==0,"Pickup does not grant items before the animation")
	advance(0.6)
	check(game.inventory.count("wood")==4 and game.runtime.drops.is_empty(),"Pickup completes once with the exact reward")
	game.player.attack_time=0
	check(not game.runtime.harvest_tree(1),"The felled tree cannot grant a second reward")
	game.inventory.add("wood",4)
	game.runtime.command(1,"craft",{"recipe":"campfire"})
	check(game.inventory.count("wood")==0 and game.inventory.count("campfire")==0,"Crafting escrows ingredients before producing output")
	check(game.runtime.activities.cancel(1,0,game.inventory) and game.inventory.count("wood")==8,"Cancelling refunds ingredients atomically")
	check(not game.runtime.activities.cancel(1,0,game.inventory),"A stale cancellation cannot duplicate ingredients")
	game.runtime.command(1,"craft",{"recipe":"campfire"});advance(3)
	check(game.inventory.count("campfire")==1 and game.inventory.count("wood")==0,"Craft queue produces one output after completion")
	var ceiling:=StaticBody3D.new();game.world.add_child(ceiling)
	var roof:=BoxShape3D.new();roof.size=Vector3(4,0.3,4)
	Shapes.collider(ceiling,roof,game.player.position+Vector3.UP*3)
	await physics_frame;await physics_frame
	check(game.world.is_sheltered(game.player),"Any valid physical ceiling protects against rain")
	ceiling.free()
	var at:=Vector3(12,game.world.terrain_height(12,0),0)
	game.world.add_structure("foundation",at,0,"1")
	var door=game.world.add_structure("door",at+Vector3(0,0,2),0,"1")
	game.world.add_structure("roof",at,0,"1")
	var chest=game.world.add_structure("chest",at+Vector3(1,0,0),0,"1")
	game.player.position=at+Vector3(0,0.3,0)
	await physics_frame;await physics_frame
	check(game.world.is_sheltered(game.player),"A constructed modular roof supplies physical shelter")
	check(game.world.toggle_door(door.structure_id) and door.open,"The door really opens")
	game.inventory.add("wood",3)
	var wood_slot: int = -1
	for i in range(36):
		if game.inventory.serialize()["slots"][i].get("id","")=="wood": wood_slot=i
	check(game.runtime._chest_transfer(1,{"structure":chest.structure_id,"slot":wood_slot,"amount":2,"to_chest":true}),"Authorized nearby player stores materials in a real chest")
	check(game.inventory.count("wood")==1 and chest.storage["wood"]==2,"Storage conserves material quantities")
	check(game.runtime._chest_transfer(1,{"structure":chest.structure_id,"slot":0,"amount":1,"to_chest":false}),"Withdrawing transfers one item atomically")
	check(game.inventory.count("wood")==2 and chest.storage["wood"]==1,"Withdrawal cannot multiply resources")
	game.journal.explore("1",game.player.position,game.world.descriptor(),1)
	check(game.journal.command("1","map_mark",{"position":[at.x,at.z],"name":"Camp","color":1,"shared":false},game.runtime.tribes),"Explored terrain accepts a personal marker")
	check(not game.journal.command("1","map_mark",{"position":[-155,-155],"name":"Unknown","color":1,"shared":false},game.runtime.tribes),"Unexplored terrain refuses marker injection")
	var original: Dictionary = game.snapshot()
	check(Store.valid(original),"Expanded world and new player modules pass the version-four schema")
	check(Store.save_world(original,game.save_folder)=="","The real expanded world writes successfully")
	var restored: Dictionary = Store.load_world(game.save_folder)
	check(restored.get("version")==4 and restored["world"]["seed"]==123 and restored["structures"].size()==4,"Reload preserves seed and every modular structure")
	check(restored["players"]["1"]["journal"]["markers"].size()==1,"Exploration markers persist in the player record")
	var old: Dictionary = original.duplicate(true);old["version"]=3;old["seed"]=1337
	old["players"]["1"]["position"]=[0,2,0]
	old["cut"]=[];old["fires"]=[];old["shelters"]=[];old["workshops"]=[];old["drops"]=[]
	var migrated: Dictionary = Store.migrate(old)
	check(migrated["world"]["generator"]==0 and migrated["world"]["size"]==128,"Legacy migration preserves the old terrain generator and size")
	var broken: Dictionary = original.duplicate(true);broken["world"]["seed"]=124
	check(not Store.valid(broken),"Save rejects mismatched generation seeds")
	broken=original.duplicate(true);broken["structures"].append(broken["structures"][0].duplicate())
	check(not Store.valid(broken),"Save rejects duplicate structure identifiers")
	game.session._keys[2]="a".repeat(64);game._spawn_player(2)
	game.inventories[2].add("rare_ore",5)
	var public_state: Dictionary = game.network_state(1)
	check(not public_state["players"]["2"].has("inventory") and not public_state["players"]["2"].has("inventory_state") and not public_state["players"]["2"].has("progression"),"Other players' inventories and progression are private")
	check(public_state["players"]["1"].has("inventory_state") and public_state["players"]["2"].has("equipment"),"Owner receives private state and remote equipment remains visible")
	check(game.network_state(2)["players"]["2"]["inventory"]["rare_ore"]==5,"The correct peer receives its own authoritative inventory")
	game._remove_player(2);game.session._keys.erase(2)
	var boar=game.runtime.wildlife.animals[2]
	game.player.position=Vector3(0,game.world.terrain_height(0,0),0)
	boar.position=game.player.position+Vector3(1,0,0);boar.home=boar.position;boar.state="idle";boar.attack_left=0
	game.runtime.wildlife.tick(0.1,game.players,true)
	check(boar.state!="windup" and boar.state!="chase","A neutral boar does not attack an unprovoked nearby player")
	game.runtime.wildlife.hit(boar,1,1);game.runtime.wildlife.tick(0.1,game.players,true)
	check(boar.state=="windup" or boar.state=="chase","A provoked neutral animal can defend itself")
	var rabbit=game.runtime.wildlife.animals[0];rabbit.position=game.player.position+Vector3(-1,0,0)
	game.inventory.add("berries",3)
	check(game.runtime.wildlife.tame(game.player,game.inventory,"1") and rabbit.owner_key=="1","Feeding a nearby passive animal establishes real ownership")
	var wildlife: Array = game.runtime.wildlife.capture()
	check(game.runtime.wildlife.valid_state(wildlife) and wildlife[0]["owner"]=="1","Tamed ownership is included in validated persisted animal state")
	var fire_at:=Vector3(-7,game.world.terrain_height(-7,0),0)
	game.world.add_fire(fire_at)
	var fire=game.world.fires[-1];fire.advance(1,true,false)
	check(not fire.lit,"Rain extinguishes an uncovered fire")
	check(fire.add_fuel(120) and fire.lit,"Refuelling relights a real fire")
	game.running=false;Store.release_lock(game.save_folder)
	game.runtime.audio.stop();game.runtime.voice.stop();game._stop_audio(game);game.session.close()
	game.queue_free();await process_frame;await create_timer(0.6).timeout
	print("RECONSTRUCTION CHECKS=%d FAILED=%d" % [checks,failed])
	quit(1 if failed else 0)
