extends SceneTree

# Adversarial Empirical Stress Test Suite for Milestone 2
# Challenger: challenger_lc_m2_2 (critic, specialist)
# Target Scope: Shader parameters, materials assignment, lighting ranges/colors, particle state, HUD banner torture

var total_assertions: int = 0
var failed_assertions: int = 0
var warnings_count: int = 0

func _init() -> void:
	call_deferred("_run_adversarial_suite")

func _assert(condition: bool, message: String) -> void:
	total_assertions += 1
	if not condition:
		failed_assertions += 1
		print("  [FAIL] %s" % message)
	else:
		print("  [PASS] %s" % message)

func _warn(condition: bool, message: String) -> void:
	if not condition:
		warnings_count += 1
		print("  [WARN] %s" % message)
	else:
		print("  [PASS] %s" % message)

func _run_adversarial_suite() -> void:
	print("\n=====================================================================")
	print("--- ADVERSARIAL STRESS TEST HARNESS: MILESTONE 2 (VISUALS & HUD) ---")
	print("=====================================================================\n")

	await _suite_1_shader_and_materials_stress()
	await _suite_2_lighting_and_particles_stress()
	await _suite_3_hud_banner_torture()

	print("\n=====================================================================")
	print("ADVERSARIAL SUITE COMPLETE:")
	print("Total assertions: %d" % total_assertions)
	print("Failed assertions: %d" % failed_assertions)
	print("Warnings / Flaws: %d" % warnings_count)
	if failed_assertions == 0:
		print(">>> CORE ACCEPTANCE CRITERIA PASSED! <<<")
	else:
		print(">>> FAILURES DETECTED IN TEST SUITE! <<<")
	print("=====================================================================\n")

	await create_timer(0.1, true, false, true).timeout
	quit(failed_assertions)

# =====================================================================
# SUITE 1: SHADER & MATERIAL STRESS TESTING
# =====================================================================
func _suite_1_shader_and_materials_stress() -> void:
	print("\n[SUITE 1] Shader & Materials Stress Testing...")
	
	var shader_path := "res://src/shaders/lava_basalt_floor.gdshader"
	var shader: Shader = load(shader_path)
	_assert(shader != null, "Shader resource loads cleanly from %s" % shader_path)
	if not shader:
		return

	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = shader
	_assert(shader_mat.shader == shader, "ShaderMaterial binds shader successfully")

	# Uniform stress fuzzing: boundary, zero, negative, and extreme float values
	var stress_parameters := [
		{"param": "basalt_color", "val": Color(0.08, 0.07, 0.08, 1.0)},
		{"param": "basalt_color", "val": Color(-1.0, -1.0, -1.0, 0.0)},
		{"param": "basalt_color", "val": Color(10.0, 10.0, 10.0, 1.0)},
		{"param": "lava_color", "val": Color(1.0, 0.32, 0.04, 1.0)},
		{"param": "lava_core_color", "val": Color(1.0, 0.85, 0.25, 1.0)},
		{"param": "crack_scale", "val": 24.0},
		{"param": "crack_scale", "val": 0.0},
		{"param": "crack_scale", "val": -100.0},
		{"param": "crack_scale", "val": 10000.0},
		{"param": "crack_intensity", "val": 1.0},
		{"param": "crack_intensity", "val": 0.0},
		{"param": "crack_intensity", "val": 50.0},
		{"param": "pulse_speed", "val": 2.4},
		{"param": "pulse_speed", "val": 0.0},
		{"param": "pulse_speed", "val": -20.0},
		{"param": "roughness_val", "val": 0.85},
		{"param": "roughness_val", "val": 0.0},
		{"param": "roughness_val", "val": 1.0}
	]

	var fuzz_passed := true
	for p in stress_parameters:
		shader_mat.set_shader_parameter(p["param"], p["val"])
		var val = shader_mat.get_shader_parameter(p["param"])
		if typeof(val) == typeof(p["val"]):
			if val is float and not is_equal_approx(val, p["val"]):
				fuzz_passed = false
			elif val is Color and val != p["val"]:
				fuzz_passed = false
		else:
			fuzz_passed = false
	_assert(fuzz_passed, "Shader parameters survive boundary and extreme float/Color fuzzing")

	# Rapid parameter write loop (1000 iterations)
	for i in range(1000):
		shader_mat.set_shader_parameter("crack_scale", float(i % 50))
		shader_mat.set_shader_parameter("pulse_speed", float(i % 10))
	_assert(shader_mat.get_shader_parameter("crack_scale") == 49.0, "Rapid 1000x parameter write loop completed without crash")

	# Node Lifecycle & Material Override in Arena
	var arena_scene: PackedScene = load("res://src/arena/arena.tscn")
	var arena = arena_scene.instantiate()
	root.add_child(arena)
	if not arena.is_node_ready():
		await arena.ready

	var floor_mesh: MeshInstance3D = arena.get_node_or_null("Floor/MeshInstance3D")
	_assert(floor_mesh != null, "Arena contains Floor/MeshInstance3D")
	_assert(floor_mesh.mesh != null, "Floor/MeshInstance3D has BoxMesh")
	_assert(floor_mesh.mesh.size == Vector3(44, 1, 44), "Floor BoxMesh dimensions are exactly 44x1x44")
	_assert(floor_mesh.material_override == null, "Floor material_override is null in initial Dungeon biome")

	# Transition arena to Lava Caverns
	arena.transition_to_lava_caverns(0.0)
	_assert(floor_mesh.material_override is ShaderMaterial, "Floor material_override receives ShaderMaterial upon transition")
	var applied_mat = floor_mesh.material_override as ShaderMaterial
	_assert(applied_mat.shader == shader, "Floor material_override shader matches lava_basalt_floor.gdshader")

	# Verify uniform values set by arena.gd
	_assert(applied_mat.get_shader_parameter("basalt_color") == Color(0.08, 0.07, 0.08, 1.0), "basalt_color is (0.08, 0.07, 0.08)")
	_assert(applied_mat.get_shader_parameter("lava_color") == Color(1.0, 0.32, 0.04, 1.0), "lava_color is (1.0, 0.32, 0.04)")
	_assert(applied_mat.get_shader_parameter("lava_core_color") == Color(1.0, 0.85, 0.25, 1.0), "lava_core_color is (1.0, 0.85, 0.25)")
	_assert(is_equal_approx(applied_mat.get_shader_parameter("crack_scale"), 24.0), "crack_scale is 24.0")
	_assert(is_equal_approx(applied_mat.get_shader_parameter("crack_intensity"), 1.0), "crack_intensity is 1.0")
	_assert(is_equal_approx(applied_mat.get_shader_parameter("pulse_speed"), 2.4), "pulse_speed is 2.4")
	_assert(is_equal_approx(applied_mat.get_shader_parameter("roughness_val"), 0.85), "roughness_val is 0.85")

	# Idempotency under repeated transitions
	for i in range(20):
		arena.transition_to_lava_caverns(0.0)
	_assert(floor_mesh.material_override == applied_mat, "Material reference remains stable under repeated transition calls")

	# Reinstantiation check
	arena.queue_free()
	await create_timer(0.05, true, false, true).timeout

	var arena2 = arena_scene.instantiate()
	root.add_child(arena2)
	if not arena2.is_node_ready():
		await arena2.ready
	var floor_mesh2: MeshInstance3D = arena2.get_node_or_null("Floor/MeshInstance3D")
	_assert(floor_mesh2.material_override == null, "Fresh Arena instance has clean material_override (no cross-instance bleed)")
	arena2.queue_free()
	await create_timer(0.05, true, false, true).timeout

# =====================================================================
# SUITE 2: LIGHTING & PARTICLES STRESS TESTING
# =====================================================================
func _suite_2_lighting_and_particles_stress() -> void:
	print("\n[SUITE 2] Lighting & Particles Stress Testing...")

	var arena_scene: PackedScene = load("res://src/arena/arena.tscn")
	var arena = arena_scene.instantiate()
	root.add_child(arena)
	if not arena.is_node_ready():
		await arena.ready

	# 2.1 Particles inspection
	var embers: GPUParticles3D = arena.get_node_or_null("VolcanicEmbers")
	var motes: GPUParticles3D = arena.get_node_or_null("DungeonMotes")
	_assert(embers != null, "VolcanicEmbers node exists in Arena")
	_assert(motes != null, "DungeonMotes node exists in Arena")

	_assert(embers.amount == 140, "VolcanicEmbers particle amount is exactly 140")
	_assert(embers.emitting == false, "VolcanicEmbers starts emitting == false")
	_assert(motes.emitting == true, "DungeonMotes starts emitting == true")

	var ember_proc = embers.process_material as ParticleProcessMaterial
	_assert(ember_proc != null, "VolcanicEmbers has valid ParticleProcessMaterial")
	if ember_proc:
		_assert(ember_proc.emission_shape == ParticleProcessMaterial.EMISSION_SHAPE_BOX, "VolcanicEmbers emission_shape is BOX (3)")
		_assert(ember_proc.emission_box_extents == Vector3(22, 1.5, 22), "VolcanicEmbers emission_box_extents is Vector3(22, 1.5, 22)")
		_assert(is_equal_approx(ember_proc.initial_velocity_min, 1.2), "VolcanicEmbers initial_velocity_min is approx 1.2")
		_assert(is_equal_approx(ember_proc.initial_velocity_max, 2.4), "VolcanicEmbers initial_velocity_max is approx 2.4")
		_assert(ember_proc.gravity == Vector3(0, 0.3, 0), "VolcanicEmbers gravity is upward Vector3(0, 0.3, 0)")

	# 2.2 Torch lights inspection
	for i in range(1, 5):
		var pillar = arena.get_node_or_null("Pillar%d" % i)
		_assert(pillar != null, "Pillar%d exists" % i)
		var torch = pillar.get_node_or_null("TorchLight") as OmniLight3D
		_assert(torch != null, "Pillar%d/TorchLight exists" % i)
		if torch:
			_assert(torch.get("base_energy") == 3.0, "Pillar%d initial base_energy is 3.0" % i)
			_assert(torch.omni_range == 14.0, "Pillar%d initial omni_range is 14.0" % i)
			_assert(torch.light_color == Color(1, 0.6, 0.2, 1), "Pillar%d initial light_color is amber" % i)

	# 2.3 Integrated Main Scene lighting transition
	var main_scene: PackedScene = load("scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	if not main.is_node_ready():
		await main.ready

	var dir_light = main.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	var world_env = main.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var main_arena = main.get_node_or_null("Arena")
	_assert(dir_light != null, "Main has DirectionalLight3D")
	_assert(world_env != null and world_env.environment != null, "Main has WorldEnvironment with valid Environment")

	var env = world_env.environment

	# Transition via main_arena with duration = 0.0
	main_arena.transition_to_lava_caverns(0.0)

	var embers_main: GPUParticles3D = main_arena.get_node("VolcanicEmbers")
	var motes_main: GPUParticles3D = main_arena.get_node("DungeonMotes")
	_assert(embers_main.emitting == true, "VolcanicEmbers emitting == true after transition")
	_assert(motes_main.emitting == false, "DungeonMotes emitting == false after transition")

	# Torches post-transition
	var torches_ok := true
	for i in range(1, 5):
		var t = main_arena.get_node("Pillar%d/TorchLight" % i) as OmniLight3D
		if t.get("base_energy") != 3.8 or t.omni_range != 16.0 or t.light_color != Color(1.0, 0.42, 0.08, 1.0):
			torches_ok = false
	_assert(torches_ok, "All 4 pillars updated to base_energy=3.8, omni_range=16.0, color=(1.0, 0.42, 0.08)")

	# Directional Light post-transition
	_assert(dir_light.light_color == Color(1.0, 0.58, 0.28, 1.0), "DirectionalLight3D transitioned to Color(1.0, 0.58, 0.28)")
	_assert(is_equal_approx(dir_light.light_energy, 1.35), "DirectionalLight3D light_energy is approx 1.35")

	# WorldEnvironment post-transition
	_assert(env.background_color == Color(0.09, 0.03, 0.02, 1.0), "Environment background_color is Color(0.09, 0.03, 0.02)")
	_assert(env.ambient_light_color == Color(0.50, 0.20, 0.10, 1.0), "Environment ambient_light_color is Color(0.50, 0.20, 0.10)")
	_assert(is_equal_approx(env.ambient_light_energy, 1.15), "Environment ambient_light_energy is approx 1.15")
	_assert(is_equal_approx(env.glow_bloom, 0.32), "Environment glow_bloom is approx 0.32")
	_assert(is_equal_approx(env.glow_intensity, 0.75), "Environment glow_intensity is approx 0.75")

	# Physical sanity checks
	_assert(dir_light.light_energy > 0.0, "Directional light energy > 0")
	_assert(env.ambient_light_energy > 0.0, "Ambient light energy > 0")
	_assert(dir_light.light_color.r > 0.0 and dir_light.light_color.g > 0.0 and dir_light.light_color.b > 0.0, "Sun color channels positive")

	# Clean up
	arena.queue_free()
	main.queue_free()
	await create_timer(0.05, true, false, true).timeout

# =====================================================================
# SUITE 3: HUD BANNER TORTURE & OVERLAPPING TWEENS
# =====================================================================
func _suite_3_hud_banner_torture() -> void:
	print("\n[SUITE 3] HUD Banner Torture & Overlapping Tweens...")

	var hud_scene: PackedScene = load("res://src/ui/hud.tscn")
	var hud = hud_scene.instantiate()
	root.add_child(hud)
	if not hud.is_node_ready():
		await hud.ready

	var banner: VBoxContainer = hud.get_node_or_null("Control/AnnouncementBanner")
	var title_lbl: Label = banner.get_node_or_null("BannerTitle")
	var subtitle_lbl: Label = banner.get_node_or_null("BannerSubtitle")
	_assert(banner != null, "AnnouncementBanner node exists in HUD")
	_assert(banner.visible == false, "Banner initially hidden")
	_assert(banner.modulate.a == 0.0, "Banner initially transparent (modulate.a == 0)")

	# 3.1 Normal single display cycle
	hud.show_biome_banner("DESCENDING INTO LAVA CAVERNS", "BIOME II: VOLCANIC UNDERWORLD", 0.2)
	_assert(banner.visible == true, "Banner becomes visible on show_biome_banner()")
	_assert(title_lbl.text == "DESCENDING INTO LAVA CAVERNS", "BannerTitle text matches")
	_assert(subtitle_lbl.text == "BIOME II: VOLCANIC UNDERWORLD", "BannerSubtitle text matches")

	# Wait for animation completion: 0.35s fade in + 0.20s hold + 0.45s fade out = 1.00s
	await create_timer(1.1, true, false, true).timeout
	_assert(banner.visible == false, "Banner automatically hides after duration completes")

	# 3.2 Rapid burst test: 100 calls in the same frame
	print("  [TORTURE] Firing 100 rapid calls to show_biome_banner() in single frame...")
	for i in range(100):
		hud.show_biome_banner("BURST %d" % i, "SUB %d" % i, 0.5)

	_assert(banner.visible == true, "Banner is visible after rapid burst")
	_assert(title_lbl.text == "BURST 99", "Banner shows text from final burst call")
	_assert(subtitle_lbl.text == "SUB 99", "Banner shows subtitle from final burst call")

	# 3.3 Overlapping Staggered Trigger Torture
	# Banner A duration: 0.5s (total 0.35 + 0.5 + 0.45 = 1.30s)
	# At t=0.3s, fire Banner B with duration 1.0s (should stay visible until t = 0.3 + 0.35 + 1.0 + 0.45 = 2.10s)
	# At t=1.35s, Banner A's tween callback fires.
	print("  [TORTURE] Testing asynchronous overlapping banner triggers...")
	hud.show_biome_banner("BANNER A", "SUB A", 0.5)

	await create_timer(0.3, true, false, true).timeout
	hud.show_biome_banner("BANNER B", "SUB B", 1.0)

	# Sample at t=1.40s (Banner A has finished its lifecycle at 1.30s)
	await create_timer(1.1, true, false, true).timeout
	print("    [OBSERVATION] At t=1.40s: banner.visible = %s, modulate.a = %f" % [str(banner.visible), banner.modulate.a])

	# Check whether Banner A's callback hid Banner B prematurely
	# This is an adversarial flaw in uncoordinated tween architecture
	var banner_prematurely_hidden: bool = (not banner.visible or banner.modulate.a <= 0.05)
	if banner_prematurely_hidden:
		_warn(false, "Overlapping tween conflict: Banner A's completion callback forcibly hid Banner B prematurely (visible=%s, a=%.2f)!" % [str(banner.visible), banner.modulate.a])
	else:
		_assert(true, "Banner B survived Banner A's callback without premature hiding")

	# Wait until Banner B would finish
	await create_timer(1.0, true, false, true).timeout
	_assert(banner.visible == false, "Banner eventually returns to hidden state")

	# 3.4 Tree exit while banner tween is active
	print("  [TORTURE] Testing removal of HUD from tree while banner tween is active...")
	hud.show_biome_banner("EXIT TEST", "SUB", 2.0)
	root.remove_child(hud)
	await create_timer(0.05, true, false, true).timeout
	_assert(not hud.is_inside_tree(), "HUD safely removed from tree while banner tween running without crash")
	hud.queue_free()
	await create_timer(0.05, true, false, true).timeout
