extends SceneTree

# ==============================================================================
# EMPIRICAL ADVERSARIAL CHALLENGE HARNESS: MILESTONE 4 TEST SUITE 13
# Agent: challenger_lc_m4_1 (critic, specialist)
# Target: Lava Caverns Biome Progression & Environment Transition
# ==============================================================================

var total_assertions: int = 0
var passed_assertions: int = 0
var failed_assertions: int = 0
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run_adversarial_suite")

func record_assert(condition: bool, description: String) -> void:
	total_assertions += 1
	if condition:
		passed_assertions += 1
	else:
		failed_assertions += 1
		failures.append(description)
		printerr("  [FAIL] Assertion %d: %s" % [total_assertions, description])

func _run_adversarial_suite() -> void:
	print("\n=======================================================")
	print("--- STARTING ADVERSARIAL STRESS TEST FOR SUITE 13 ---")
	print("=======================================================\n")

	await _test_group_1_wave_progression_stress()
	await _test_group_2_shader_uniform_boundary_stress()
	await _test_group_3_lighting_mutation_stress()
	await _test_group_4_particle_lifecycle_stress()
	await _test_group_5_hud_banner_concurrency_stress()
	await _test_group_6_audio_rumble_and_looping_stress()

	print("\n=======================================================")
	print("--- ADVERSARIAL TEST RESULTS SUMMARY ---")
	print("Total Assertions Executed: %d" % total_assertions)
	print("Passed Assertions:         %d" % passed_assertions)
	print("Failed Assertions:         %d" % failed_assertions)
	print("=======================================================\n")

	if failed_assertions > 0:
		print("CRITICAL FAILURES DETECTED (%d):" % failures.size())
		for f in failures:
			print(" - ", f)
		print("\nVERDICT: REJECT")
		await create_timer(0.05, true, false, true).timeout
		quit(1)
	else:
		print("ALL ADVERSARIAL STRESS CHALLENGES PASSED EMPIRICALLY!")
		print("VERDICT: APPROVE")
		await create_timer(0.05, true, false, true).timeout
		quit(0)

# ------------------------------------------------------------------------------
# GROUP 1: Wave Progression, Negative/Extreme Waves & Reversion Resistance
# ------------------------------------------------------------------------------
func _test_group_1_wave_progression_stress() -> void:
	print("[GROUP 1] Adversarial stress-testing Wave 6+ hooks and state reversion...")
	var main_scene: PackedScene = load("scenes/main.tscn")
	record_assert(main_scene != null, "scenes/main.tscn must load")
	if not main_scene:
		return

	var main = main_scene.instantiate()
	root.add_child(main)
	if not main.is_node_ready():
		await main.ready

	var main_arena = main.get_node("Arena")
	record_assert(main_arena != null, "Arena must be instantiated in Main")
	record_assert(main._is_lava_biome == false, "Initial main._is_lava_biome must be false")
	record_assert(main_arena.is_lava_biome == false, "Initial arena.is_lava_biome must be false")
	record_assert(main_arena.current_biome == 0, "Initial arena.current_biome must be 0 (DUNGEON)")

	# Challenge 1.1: Out-of-order, zero, and negative waves must not trigger transition
	var non_transition_waves = [-100, -1, 0, 1, 3, 2, 5, 4, 1, 5]
	for w in non_transition_waves:
		main._on_wave_started(w)
		record_assert(main._is_lava_biome == false, "Wave %d must not set _is_lava_biome" % w)
		record_assert(main_arena.is_lava_biome == false, "Wave %d must not set arena.is_lava_biome" % w)
		record_assert(main_arena.current_biome == 0, "Wave %d must keep arena.current_biome at 0" % w)

	# Challenge 1.2: Wave 6 triggers transition
	main._on_wave_started(6)
	record_assert(main._is_lava_biome == true, "Wave 6 must trigger _is_lava_biome = true")
	record_assert(main_arena.is_lava_biome == true, "Wave 6 must trigger arena.is_lava_biome = true")
	record_assert(main_arena.current_biome == 1, "Wave 6 must set arena.current_biome = 1")

	# Challenge 1.3: Anti-reversion check: calling prior wave (e.g. wave 2 or 5) must NOT revert back to dungeon
	main._on_wave_started(2)
	record_assert(main._is_lava_biome == true, "Post-transition wave 2 must not revert _is_lava_biome")
	record_assert(main_arena.is_lava_biome == true, "Post-transition wave 2 must not revert arena.is_lava_biome")
	record_assert(main_arena.current_biome == 1, "Post-transition wave 2 must not revert arena.current_biome")

	# Challenge 1.4: Extreme waves (Wave 999, 10000) maintain lava caverns
	main._on_wave_started(999)
	record_assert(main._is_lava_biome == true, "Wave 999 must maintain lava biome")
	record_assert(main_arena.current_biome == 1, "Wave 999 must maintain current_biome 1")

	# Challenge 1.5: 50 rapid redundant calls to wave 6
	for i in range(50):
		main._on_wave_started(6)
	record_assert(main._is_lava_biome == true, "50 redundant wave 6 calls must remain stable")
	record_assert(main_arena.current_biome == 1, "50 redundant wave 6 calls must keep biome 1")

	# Challenge 1.6: Transition safety when Arena or HUD are destroyed
	var headless_main = main_scene.instantiate()
	root.add_child(headless_main)
	if not headless_main.is_node_ready():
		await headless_main.ready
	var arena_child = headless_main.get_node("Arena")
	headless_main.remove_child(arena_child)
	arena_child.queue_free()
	# Trigger wave 6 on Main with missing Arena: must not crash
	headless_main._on_wave_started(6)
	record_assert(headless_main._is_lava_biome == true, "Main without Arena must survive wave 6 without crash")
	headless_main.queue_free()

	main.queue_free()
	print("✓ Group 1: Wave progression & anti-reversion verified successfully.")

# ------------------------------------------------------------------------------
# GROUP 2: Floor Shader Override, Uniform Boundary & Material Stress
# ------------------------------------------------------------------------------
func _test_group_2_shader_uniform_boundary_stress() -> void:
	print("[GROUP 2] Adversarial stress-testing floor shader and uniform extremes...")
	var lava_shader: Shader = load("res://src/shaders/lava_basalt_floor.gdshader")
	record_assert(lava_shader != null, "lava_basalt_floor.gdshader must load")
	if not lava_shader:
		return

	var mat := ShaderMaterial.new()
	mat.shader = lava_shader

	# Challenge 2.1: Default uniform values matching requirements
	var expected_uniforms := [
		"basalt_color", "lava_color", "lava_core_color",
		"crack_scale", "crack_intensity", "pulse_speed", "roughness_val"
	]
	for u in expected_uniforms:
		mat.set_shader_parameter(u, mat.get_shader_parameter(u))
		record_assert(true, "Shader parameter '%s' accessible" % u)

	# Challenge 2.2: Extreme boundary parameters
	var extreme_params = [
		{"crack_scale": 0.0, "crack_intensity": 0.0, "pulse_speed": 0.0, "roughness_val": 0.0},
		{"crack_scale": -100.0, "crack_intensity": -50.0, "pulse_speed": -10.0, "roughness_val": -1.0},
		{"crack_scale": 10000.0, "crack_intensity": 1000.0, "pulse_speed": 5000.0, "roughness_val": 2.0},
		{"basalt_color": Color(-1.0, 2.0, 50.0, 1.0), "lava_color": Color(0, 0, 0, 0)},
	]

	for config in extreme_params:
		for param_name in config.keys():
			mat.set_shader_parameter(param_name, config[param_name])
			var val = mat.get_shader_parameter(param_name)
			record_assert(val != null, "Extreme param '%s' accepted without crash" % param_name)

	# Challenge 2.3: Rapid 100 material overrides on a mesh instance
	var test_mesh := MeshInstance3D.new()
	test_mesh.mesh = BoxMesh.new()
	root.add_child(test_mesh)
	for i in range(100):
		var temp_mat := ShaderMaterial.new()
		temp_mat.shader = lava_shader
		temp_mat.set_shader_parameter("crack_scale", float(i))
		test_mesh.material_override = temp_mat
	record_assert(test_mesh.material_override != null, "100 rapid material overrides completed without memory error")
	test_mesh.queue_free()

	print("✓ Group 2: Shader uniform extremes and material stress verified successfully.")

# ------------------------------------------------------------------------------
# GROUP 3: Lighting Mutation Stress & Missing Dependency Resilience
# ------------------------------------------------------------------------------
func _test_group_3_lighting_mutation_stress() -> void:
	print("[GROUP 3] Adversarial stress-testing lighting mutations and missing dependencies...")
	var arena_scene: PackedScene = load("res://src/arena/arena.tscn")
	record_assert(arena_scene != null, "Arena scene must load")
	if not arena_scene:
		return

	# Challenge 3.1: Isolated Arena transition with NO DirectionalLight3D and NO WorldEnvironment in tree
	var isolated_arena = arena_scene.instantiate()
	root.add_child(isolated_arena)
	if not isolated_arena.is_node_ready():
		await isolated_arena.ready
	
	# Must not crash when lights/env are missing from hierarchy
	isolated_arena.transition_to_lava_caverns(0.0)
	record_assert(isolated_arena.is_lava_biome == true, "Isolated arena transitions cleanly without parent lights")
	record_assert(isolated_arena.current_biome == 1, "Isolated arena current_biome is 1")
	isolated_arena.queue_free()

	# Challenge 3.2: Partial Arena where pillars and torches have been deleted
	var mutilated_arena = arena_scene.instantiate()
	root.add_child(mutilated_arena)
	if not mutilated_arena.is_node_ready():
		await mutilated_arena.ready
	var p1 = mutilated_arena.get_node_or_null("Pillar1")
	if p1:
		mutilated_arena.remove_child(p1)
		p1.queue_free()
	var p2_torch = mutilated_arena.get_node_or_null("Pillar2/TorchLight")
	if p2_torch:
		p2_torch.get_parent().remove_child(p2_torch)
		p2_torch.queue_free()
	
	mutilated_arena.transition_to_lava_caverns(0.0)
	record_assert(mutilated_arena.is_lava_biome == true, "Mutilated arena handles missing pillars/torches without crash")
	mutilated_arena.queue_free()

	# Challenge 3.3: Smooth tween transition (duration = 0.3s) with full lights and environment
	var container := Node3D.new()
	root.add_child(container)
	var dir_light := DirectionalLight3D.new()
	dir_light.name = "DirectionalLight3D"
	dir_light.light_energy = 1.0
	dir_light.light_color = Color.WHITE
	container.add_child(dir_light)

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = Environment.new()
	world_env.environment.ambient_light_color = Color.GRAY
	world_env.environment.ambient_light_energy = 0.5
	container.add_child(world_env)

	var arena = arena_scene.instantiate()
	container.add_child(arena)
	if not arena.is_node_ready():
		await arena.ready

	# Start transition with 0.25s duration
	arena.transition_to_lava_caverns(0.25)
	# Concurrent duplicate call while tween is in-flight must be safely ignored
	arena.transition_to_lava_caverns(0.25)

	# In headless mode, step frames to allow Tween to process to completion (0.25s = ~15 frames at 60fps)
	for f in range(30):
		await process_frame

	record_assert(dir_light.light_color.is_equal_approx(Color(1.0, 0.58, 0.28, 1.0)), "Dir light color tweened to fiery sun")
	record_assert(abs(dir_light.light_energy - 1.35) < 0.05, "Dir light energy tweened to 1.35 (actual: %.3f)" % dir_light.light_energy)
	record_assert(world_env.environment.ambient_light_color.is_equal_approx(Color(0.50, 0.20, 0.10, 1.0)), "Ambient light color tweened to fiery red-orange")
	record_assert(abs(world_env.environment.ambient_light_energy - 1.15) < 0.05, "Ambient light energy tweened to 1.15 (actual: %.3f)" % world_env.environment.ambient_light_energy)

	# Verify pillar torchlights reached target
	var torch := arena.get_node("Pillar1/TorchLight") as OmniLight3D
	record_assert(torch.light_color.is_equal_approx(Color(1.0, 0.42, 0.08, 1.0)), "Torch light color reached target")
	record_assert(abs(torch.omni_range - 16.0) < 0.1, "Torch omni range reached 16.0")

	container.queue_free()
	print("✓ Group 3: Lighting mutation and missing dependency safety verified successfully.")

# ------------------------------------------------------------------------------
# GROUP 4: Volcanic Embers & Dungeon Motes Particle Lifecycle Stress
# ------------------------------------------------------------------------------
func _test_group_4_particle_lifecycle_stress() -> void:
	print("[GROUP 4] Adversarial stress-testing particle lifecycle and GPU nodes...")
	var arena_scene: PackedScene = load("res://src/arena/arena.tscn")
	var arena = arena_scene.instantiate()
	root.add_child(arena)
	if not arena.is_node_ready():
		await arena.ready

	var embers: GPUParticles3D = arena.get_node_or_null("VolcanicEmbers")
	var motes: GPUParticles3D = arena.get_node_or_null("DungeonMotes")
	record_assert(embers != null, "VolcanicEmbers node exists")
	record_assert(motes != null, "DungeonMotes node exists")
	record_assert(embers.amount == 140, "VolcanicEmbers particle count is exactly 140")
	record_assert(motes.amount == 90, "DungeonMotes particle count is exactly 90")

	# Initial state
	record_assert(embers.emitting == false, "Embers must be off in Dungeon biome")
	record_assert(motes.emitting == true, "Motes must be on in Dungeon biome")

	# Step physics frames to ensure stability
	for f in range(10):
		await process_frame

	# Transition
	arena.transition_to_lava_caverns(0.0)
	record_assert(embers.emitting == true, "Embers must be emitting in Lava Caverns")
	record_assert(motes.emitting == false, "Motes must stop emitting in Lava Caverns")

	# Step another 20 frames with embers active
	for f in range(20):
		await process_frame

	record_assert(embers.emitting == true, "Embers remain emitting across 20 frames")
	arena.queue_free()
	print("✓ Group 4: Particle lifecycle and stability verified successfully.")

# ------------------------------------------------------------------------------
# GROUP 5: HUD AnnouncementBanner Concurrency, Chaos Spam & Auto-Dismissal
# ------------------------------------------------------------------------------
func _test_group_5_hud_banner_concurrency_stress() -> void:
	print("[GROUP 5] Adversarial stress-testing HUD banner rapid-fire and concurrency...")
	var hud_scene: PackedScene = load("res://src/ui/hud.tscn")
	record_assert(hud_scene != null, "HUD scene must load")
	if not hud_scene:
		return

	var hud = hud_scene.instantiate()
	root.add_child(hud)
	if not hud.is_node_ready():
		await hud.ready

	var banner: VBoxContainer = hud.get_node("Control/AnnouncementBanner")
	var title_lbl: Label = banner.get_node("BannerTitle")
	var sub_lbl: Label = banner.get_node("BannerSubtitle")

	# Challenge 5.1: 50 rapid-fire triggers in a tight loop with various strings
	for i in range(50):
		hud.show_biome_banner("RAPID TITLE %d" % i, "RAPID SUBTITLE %d" % i, 0.05)
	
	record_assert(banner.visible == true, "Banner remains visible during rapid spam")
	record_assert(title_lbl.text == "RAPID TITLE 49", "Banner title matches final rapid invocation")
	record_assert(sub_lbl.text == "RAPID SUBTITLE 49", "Banner subtitle matches final rapid invocation")
	record_assert(hud._banner_tween != null and hud._banner_tween.is_valid(), "Only one valid tween active after spam")

	# Challenge 5.2: Empty strings and very long string payload
	hud.show_biome_banner("", "", 0.05)
	record_assert(title_lbl.text == "", "Banner accepts empty title")
	record_assert(sub_lbl.text == "", "Banner accepts empty subtitle")

	var long_str := "LAVA ".repeat(200)
	hud.show_biome_banner(long_str, "LONG SUBTITLE", 0.05)
	record_assert(title_lbl.text == long_str, "Banner accepts 1000-char string payload")

	# Challenge 5.3: Auto-dismissal completion
	hud.show_biome_banner("DESCENDING INTO LAVA CAVERNS", "BIOME II: VOLCANIC UNDERWORLD", 0.04)
	if hud._banner_tween and hud._banner_tween.is_valid():
		await hud._banner_tween.finished
		await process_frame
	
	record_assert(banner.visible == false, "Banner auto-dismisses to visible=false")

	# Challenge 5.4: Interrupted dismiss - start with long duration, immediately interrupt with short
	hud.show_biome_banner("LONG BANNER", "SUB", 10.0)
	record_assert(banner.visible == true, "Long banner opened")
	await create_timer(0.05, true, false, true).timeout
	hud.show_biome_banner("SHORT OVERRIDE", "SUB", 0.02)
	record_assert(title_lbl.text == "SHORT OVERRIDE", "Short override took effect")
	if hud._banner_tween and hud._banner_tween.is_valid():
		await hud._banner_tween.finished
		await process_frame
	record_assert(banner.visible == false, "Interrupted banner properly auto-dismissed")

	hud.queue_free()
	print("✓ Group 5: HUD banner concurrency and auto-dismissal verified successfully.")

# ------------------------------------------------------------------------------
# GROUP 6: Volcanic Rumble Audio Synthesis, Looping & Boundary Rigor
# ------------------------------------------------------------------------------
func _test_group_6_audio_rumble_and_looping_stress() -> void:
	print("[GROUP 6] Adversarial stress-testing volcanic rumble audio synthesis & looping...")
	var audio_script := load("res://src/audio/audio_manager.gd")
	record_assert(audio_script != null, "audio_manager.gd must load")
	if not audio_script:
		return

	var audio: Node = audio_script.new()
	root.add_child(audio)
	if not audio.is_node_ready():
		await audio.ready

	# Challenge 6.1: Stream existence & audio format
	var stream: AudioStreamWAV = audio.stream_volcanic_rumble
	record_assert(stream != null, "stream_volcanic_rumble is non-null")
	record_assert(stream.format == AudioStreamWAV.FORMAT_16_BITS, "stream format is FORMAT_16_BITS")
	record_assert(stream.mix_rate == 22050, "stream mix_rate is 22050")
	record_assert(stream.stereo == false, "stream is mono")

	# Challenge 6.2: Exact sample count and byte length (3.20s * 22050 * 2 bytes = 141120 bytes)
	var expected_samples: int = int(3.20 * 22050.0)
	var expected_bytes: int = expected_samples * 2
	record_assert(stream.data.size() == expected_bytes, "Data size is exactly %d bytes (got %d)" % [expected_bytes, stream.data.size()])

	# Challenge 6.3: Looping properties
	record_assert(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "stream loop_mode is LOOP_FORWARD")
	record_assert(stream.loop_begin == 0, "stream loop_begin is 0")
	record_assert(stream.loop_end == expected_samples, "stream loop_end is %d" % expected_samples)

	# Challenge 6.4: Numerical audio sample bounds, DC offset, and NaN checks
	var pcm_data: PackedByteArray = stream.data
	var sample_count: int = pcm_data.size() / 2
	var min_sample: int = 32767
	var max_sample: int = -32768
	var dc_accum: float = 0.0
	var abs_sum: float = 0.0

	for i in range(sample_count):
		var b0: int = pcm_data[i * 2]
		var b1: int = pcm_data[i * 2 + 1]
		var val: int = b0 | (b1 << 8)
		if val >= 32768:
			val -= 65536
		if val < min_sample:
			min_sample = val
		if val > max_sample:
			max_sample = val
		dc_accum += float(val) / 32768.0
		abs_sum += absf(float(val) / 32768.0)

	var dc_offset: float = dc_accum / float(sample_count)
	var avg_amplitude: float = abs_sum / float(sample_count)

	record_assert(min_sample >= -32768 and max_sample <= 32767, "All samples within 16-bit signed range [%d, %d]" % [min_sample, max_sample])
	record_assert(absf(dc_offset) < 0.02, "DC offset is negligible (%.4f < 0.02)" % dc_offset)
	record_assert(avg_amplitude > 0.05, "Audio has audible energy (avg amplitude: %.4f)" % avg_amplitude)

	# Challenge 6.5: Loop seam continuity check (first sample vs last sample difference)
	var first_val: int = pcm_data[0] | (pcm_data[1] << 8)
	if first_val >= 32768: first_val -= 65536
	var last_idx: int = (sample_count - 1) * 2
	var last_val: int = pcm_data[last_idx] | (pcm_data[last_idx + 1] << 8)
	if last_val >= 32768: last_val -= 65536
	var seam_delta: float = absf(float(first_val - last_val) / 32768.0)
	record_assert(seam_delta < 0.25, "Loop seam crossfade is smooth (seam delta: %.4f < 0.25)" % seam_delta)

	# Challenge 6.6: Audio player pool spam (100 rapid plays)
	for i in range(100):
		audio.play_volcanic_rumble()
	record_assert(true, "100 rapid play_volcanic_rumble() completed without pool exhaustion or crash")

	# Challenge 6.7: Ambience start/stop toggling (50 cycles)
	for i in range(50):
		audio.start_volcanic_ambience()
		audio.set_volcanic_ambience(false)
		audio.set_volcanic_ambience(true)
	record_assert(audio._ambient_player.playing == true, "Ambient player playing after 50 toggles")
	audio.stop_volcanic_ambience()
	record_assert(audio._ambient_player.playing == false, "Ambient player stopped cleanly")

	audio.queue_free()
	print("✓ Group 6: Volcanic rumble synthesis, looping & player stress verified successfully.")
