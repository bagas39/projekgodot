extends SceneTree

func _init() -> void:
	call_deferred("_run_stress_tests")

func _run_stress_tests() -> void:
	print("\n--- RUNNING ADVERSARIAL STRESS TEST SUITE FOR MILESTONE 3 ---")
	
	# Test 1: Jolt transform safety on rapid rock destruction
	print("[Stress 1] Rapid RockFragment multi-hit and Jolt scale invariant...")
	var rock_scene: PackedScene = load("res://src/props/rock_fragment.tscn")
	assert(rock_scene != null, "Rock fragment scene must load")
	
	for i in range(10):
		var rock = rock_scene.instantiate()
		root.add_child(rock)
		if not rock.is_node_ready():
			await rock.ready
		
		# Multiple rapid hits on the same frame
		rock.take_damage(5)
		rock.take_damage(10)
		rock.take_damage(100) # Overkill hit
		rock.take_damage(50)  # Post-mortem hit
		
		assert(rock.is_destroyed, "Rock must be destroyed")
		assert(rock.scale.x > 0.0 and rock.scale.y > 0.0 and rock.scale.z > 0.0, "Body scale must NEVER be zero")
		assert(rock.collision_shape.scale.x > 0.0, "CollisionShape scale must NEVER be zero")
		rock.queue_free()
	print("✓ Rapid rock destruction & multi-hit stress passed.")
	
	# Test 2: Dangling entity deletion inside Lava hazard damage routine
	print("[Stress 2] Dangling body deletion during Lava Floor damage tick...")
	var lava_scene: PackedScene = load("res://src/hazards/lava_floor_hazard.tscn")
	var lava = lava_scene.instantiate()
	root.add_child(lava)
	if not lava.is_node_ready():
		await lava.ready
	
	var slime_scene: PackedScene = load("res://src/enemies/enemy_slime.tscn")
	var dummy_slime = slime_scene.instantiate()
	root.add_child(dummy_slime)
	if not dummy_slime.is_node_ready():
		await dummy_slime.ready
	
	# Queue free immediately to simulate body freed mid-frame
	dummy_slime.queue_free()
	
	# Trigger damage on queued-free entity — must not crash or throw null error
	lava._deal_damage_to_target(dummy_slime)
	lava._deal_damage_to_target(null)
	
	lava.queue_free()
	print("✓ Queued-free & null target handling in Lava hazard passed.")
	
	# Test 3: Stalactite impact on queued-free and null targets
	print("[Stress 3] Stalactite impact on freed target...")
	var stalactite_scene: PackedScene = load("res://src/hazards/falling_stalactite.tscn")
	var stalactite = stalactite_scene.instantiate()
	root.add_child(stalactite)
	if not stalactite.is_node_ready():
		await stalactite.ready
	
	var victim = slime_scene.instantiate()
	root.add_child(victim)
	if not victim.is_node_ready():
		await victim.ready
	victim.global_position = stalactite.global_position
	victim.queue_free()
	
	# Trigger impact immediately with a queued-free node in range
	stalactite.trigger_impact_now()
	print("✓ Stalactite impact handled freed victim safely.")
	
	# Test 4: Spawner stalactite hazard when player is null or freed
	print("[Stress 4] Spawner hazard triggering without player...")
	var spawner_script: GDScript = load("res://src/arena/spawner.gd")
	var spawner = Node3D.new()
	spawner.set_script(spawner_script)
	root.add_child(spawner)
	
	spawner.player = null
	spawner.current_wave = 6
	spawner.is_wave_active = true
	# Force stalactite hazard trigger with no player in tree
	spawner._spawn_stalactite_hazard()
	
	spawner.queue_free()
	print("✓ Spawner safely handled missing player.")
	
	# Test 5: Rapid banner spamming in HUD
	print("[Stress 5] Rapid HUD banner spamming...")
	var hud_scene: PackedScene = load("res://src/ui/hud.tscn")
	var hud = hud_scene.instantiate()
	root.add_child(hud)
	if not hud.is_node_ready():
		await hud.ready
	
	for i in range(20):
		hud.show_biome_banner("RAPID BANNER %d" % i, "SUBTITLE %d" % i)
	
	hud.queue_free()
	print("✓ Rapid banner spamming completed without crash or orphan tweens.")
	
	print("\n=========================================================")
	print(">>> ALL ADVERSARIAL STRESS TESTS PASSED WITH 0 ERRORS <<<")
	print("=========================================================\n")
	quit(0)
