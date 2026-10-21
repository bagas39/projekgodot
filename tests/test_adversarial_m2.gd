extends SceneTree

func _init() -> void:
	call_deferred("_run_adversarial_stress_tests")

func _run_adversarial_stress_tests() -> void:
	print("\n--- RUNNING ADVERSARIAL STRESS TESTS FOR MILESTONE 2 ---")
	
	# -------------------------------------------------------------
	# Stress Test 1: Rapid idempotency attack on transition_to_lava_caverns
	# -------------------------------------------------------------
	print("[Stress 1] 100 rapid transition_to_lava_caverns calls...")
	var arena_scene: PackedScene = load("res://src/arena/arena.tscn")
	assert(arena_scene != null)
	var arena = arena_scene.instantiate()
	root.add_child(arena)
	if not arena.is_node_ready():
		await arena.ready
	
	for i in range(100):
		arena.transition_to_lava_caverns(0.5)
	
	assert(arena.is_lava_biome == true, "Must remain in lava biome")
	assert(arena.current_biome == 1, "Must remain current_biome 1")
	var embers: GPUParticles3D = arena.get_node("VolcanicEmbers")
	assert(embers.emitting == true, "Embers must be emitting")
	var motes: GPUParticles3D = arena.get_node("DungeonMotes")
	assert(motes.emitting == false, "Motes must be stopped")
	print("✓ 100 rapid transitions handled seamlessly with zero state corruption.")
	arena.queue_free()
	
	# -------------------------------------------------------------
	# Stress Test 2: Headless arena with missing lights / env
	# -------------------------------------------------------------
	print("[Stress 2] Arena outside tree and with isolated hierarchy...")
	var isolated_arena = arena_scene.instantiate()
	# Call transition before adding to root/tree
	isolated_arena.transition_to_lava_caverns(0.0)
	assert(isolated_arena.is_lava_biome == true)
	isolated_arena.free()
	print("✓ Isolated/out-of-tree arena transitions with zero crashes.")
	
	# -------------------------------------------------------------
	# Stress Test 3: Rapid consecutive show_biome_banner calls on HUD
	# -------------------------------------------------------------
	print("[Stress 3] Rapid show_biome_banner invocations on HUD...")
	var hud_scene: PackedScene = load("res://src/ui/hud.tscn")
	var hud = hud_scene.instantiate()
	root.add_child(hud)
	if not hud.is_node_ready():
		await hud.ready
	
	for i in range(20):
		hud.show_biome_banner("RAPID BANNER %d" % i, "SUBTITLE %d" % i, 1.0)
	
	var banner = hud.get_node("Control/AnnouncementBanner")
	assert(banner.visible == true)
	var title = hud.get_node("Control/AnnouncementBanner/BannerTitle") as Label
	assert(title.text == "RAPID BANNER 19")
	print("✓ Rapid banner calls handled without crash.")
	hud.queue_free()
	
	# -------------------------------------------------------------
	# Stress Test 4: Full wave simulation 1 through 10
	# -------------------------------------------------------------
	print("[Stress 4] Full wave simulation 1 -> 10 on Main scene...")
	var main_scene: PackedScene = load("scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	if not main.is_node_ready():
		await main.ready
	
	var main_arena = main.get_node("Arena")
	for wave in range(1, 6):
		main._on_wave_started(wave)
		assert(main._is_lava_biome == false, "Wave %d must remain dungeon biome" % wave)
		assert(main_arena.is_lava_biome == false, "Arena must remain dungeon biome at wave %d" % wave)
	
	for wave in range(6, 11):
		main._on_wave_started(wave)
		assert(main._is_lava_biome == true, "Wave %d must be lava biome" % wave)
		assert(main_arena.is_lava_biome == true, "Arena must be lava biome at wave %d" % wave)
	
	print("✓ Full wave lifecycle from 1 to 10 verified.")
	main.queue_free()
	
	# -------------------------------------------------------------
	# Stress Test 5: Shader parameter boundary checks
	# -------------------------------------------------------------
	print("[Stress 5] Shader parameter boundary checks...")
	var shader = load("res://src/shaders/lava_basalt_floor.gdshader")
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("crack_scale", 5.0)
	mat.set_shader_parameter("crack_scale", 50.0)
	mat.set_shader_parameter("pulse_speed", 0.5)
	mat.set_shader_parameter("pulse_speed", 6.0)
	mat.set_shader_parameter("roughness_val", 0.0)
	mat.set_shader_parameter("roughness_val", 1.0)
	print("✓ Shader handles boundary uniform extremes without crash.")
	
	print("\n=======================================================")
	print(">>> ALL ADVERSARIAL STRESS TESTS PASSED 100%! <<<")
	print("=======================================================\n")
	
	await create_timer(0.05, true, false, true).timeout
	quit(0)
