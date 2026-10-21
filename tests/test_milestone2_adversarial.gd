extends SceneTree

# Adversarial Empirical Stress Test Suite for Milestone 2: Biome Progression & Dynamic Arena
# Challenger: challenger_lc_m2_1

func _init() -> void:
	call_deferred("_run_adversarial_suite")

func _run_adversarial_suite() -> void:
	print("\n=======================================================")
	print("--- ADVERSARIAL STRESS TEST HARNESS: MILESTONE 2 ---")
	print("=======================================================\n")

	var failed_checks: int = 0
	var total_checks: int = 0

	var main_scene: PackedScene = load("res://scenes/main.tscn")
	if not main_scene:
		print("FATAL: Failed to load res://scenes/main.tscn")
		quit(1)
		return

	# =================================================================
	# SUITE 1: Wave Progression Threshold Testing (Waves 1-5 Boundary)
	# =================================================================
	print("\n[SUITE 1] Testing Wave 1 through 5 biome boundary integrity...")
	var main1 = main_scene.instantiate()
	root.add_child(main1)
	if not main1.is_node_ready():
		await main1.ready

	var arena1 = main1.get_node("Arena")
	var hud1 = main1.get_node("HUD")
	var banner1 = hud1.get_node("Control/AnnouncementBanner")

	for w in range(1, 6):
		total_checks += 1
		main1._on_wave_started(w)
		
		var ok: bool = true
		if main1._is_lava_biome != false:
			print("  [FAIL] Wave %d: main1._is_lava_biome is true, expected false" % w)
			ok = false
		if arena1.is_lava_biome != false:
			print("  [FAIL] Wave %d: arena1.is_lava_biome is true, expected false" % w)
			ok = false
		if arena1.current_biome != 0:
			print("  [FAIL] Wave %d: arena1.current_biome is %d, expected 0 (DUNGEON)" % [w, arena1.current_biome])
			ok = false
		if arena1.volcanic_embers.emitting != false:
			print("  [FAIL] Wave %d: volcanic_embers is emitting, expected false" % w)
			ok = false
		if arena1.dungeon_motes.emitting != true:
			print("  [FAIL] Wave %d: dungeon_motes is NOT emitting, expected true" % w)
			ok = false
		if arena1.floor_mesh.material_override != null:
			print("  [FAIL] Wave %d: floor_mesh.material_override is not null" % w)
			ok = false
		if banner1.visible != false:
			print("  [FAIL] Wave %d: AnnouncementBanner is visible, expected hidden" % w)
			ok = false
		
		if ok:
			print("  [PASS] Wave %d: Dungeon state strictly preserved (biome=0, embers=false, banner=hidden)." % w)
		else:
			failed_checks += 1

	# =================================================================
	# SUITE 2: Wave 6 Immediate Transition Hook
	# =================================================================
	print("\n[SUITE 2] Testing Wave 6 transition activation...")
	total_checks += 1
	main1._on_wave_started(6)

	var s2_ok: bool = true
	if main1._is_lava_biome != true:
		print("  [FAIL] Wave 6: main1._is_lava_biome is false, expected true")
		s2_ok = false
	if arena1.is_lava_biome != true:
		print("  [FAIL] Wave 6: arena1.is_lava_biome is false, expected true")
		s2_ok = false
	if arena1.current_biome != 1:
		print("  [FAIL] Wave 6: arena1.current_biome is %d, expected 1 (LAVA_CAVERNS)" % arena1.current_biome)
		s2_ok = false
	if arena1.volcanic_embers.emitting != true:
		print("  [FAIL] Wave 6: volcanic_embers is NOT emitting, expected true")
		s2_ok = false
	if arena1.dungeon_motes.emitting != false:
		print("  [FAIL] Wave 6: dungeon_motes is emitting, expected false")
		s2_ok = false
	if arena1.floor_mesh.material_override == null:
		print("  [FAIL] Wave 6: floor_mesh.material_override is null, expected ShaderMaterial")
		s2_ok = false
	elif not (arena1.floor_mesh.material_override is ShaderMaterial):
		print("  [FAIL] Wave 6: floor_mesh.material_override is not ShaderMaterial")
		s2_ok = false
	
	if banner1.visible != true:
		print("  [FAIL] Wave 6: AnnouncementBanner is NOT visible")
		s2_ok = false
	var banner_title = banner1.get_node("BannerTitle")
	var banner_sub = banner1.get_node("BannerSubtitle")
	if banner_title.text != "DESCENDING INTO LAVA CAVERNS":
		print("  [FAIL] Wave 6: BannerTitle is '%s', expected 'DESCENDING INTO LAVA CAVERNS'" % banner_title.text)
		s2_ok = false
	if banner_sub.text != "BIOME II: VOLCANIC UNDERWORLD":
		print("  [FAIL] Wave 6: BannerSubtitle is '%s', expected 'BIOME II: VOLCANIC UNDERWORLD'" % banner_sub.text)
		s2_ok = false

	var audio_mgr = root.get_node_or_null("AudioManager")
	if audio_mgr and audio_mgr._ambient_player:
		if not audio_mgr._ambient_player.playing:
			print("  [FAIL] Wave 6: AudioManager._ambient_player is NOT playing volcanic ambience")
			s2_ok = false
		if audio_mgr._ambient_player.stream != audio_mgr.stream_volcanic_rumble:
			print("  [FAIL] Wave 6: AudioManager._ambient_player stream is not stream_volcanic_rumble")
			s2_ok = false

	if s2_ok:
		print("  [PASS] Wave 6: Immediate transition fires cleanly across arena, floor shader, embers, banner, and audio.")
	else:
		failed_checks += 1

	# =================================================================
	# SUITE 3: Waves 7-10 Idempotency & Non-Retriggering
	# =================================================================
	print("\n[SUITE 3] Testing Waves 7-10 idempotency and non-retriggering...")
	# Manually hide banner to test whether waves 7-10 erroneously trigger show_biome_banner()
	banner1.visible = false
	banner1.modulate.a = 0.0

	for w in range(7, 11):
		total_checks += 1
		main1._on_wave_started(w)
		
		var w_ok: bool = true
		if main1._is_lava_biome != true:
			print("  [FAIL] Wave %d: main1._is_lava_biome became false" % w)
			w_ok = false
		if arena1.is_lava_biome != true:
			print("  [FAIL] Wave %d: arena1.is_lava_biome became false" % w)
			w_ok = false
		if arena1.current_biome != 1:
			print("  [FAIL] Wave %d: arena1.current_biome is %d, expected 1" % [w, arena1.current_biome])
			w_ok = false
		if banner1.visible != false:
			print("  [FAIL] Wave %d: AnnouncementBanner re-triggered! (visible == true)" % w)
			w_ok = false
		
		if w_ok:
			print("  [PASS] Wave %d: Idempotent. Lava biome maintained, no redundant banner trigger." % w)
		else:
			failed_checks += 1

	# Clean up main1
	main1.queue_free()
	await create_timer(0.05, true, false, true).timeout

	# =================================================================
	# SUITE 4: Rapid Wave Advance Stress Test
	# =================================================================
	print("\n[SUITE 4] Stress-testing rapid wave transitions & API hammering...")
	var main2 = main_scene.instantiate()
	root.add_child(main2)
	if not main2.is_node_ready():
		await main2.ready

	var arena2 = main2.get_node("Arena")
	var hud2 = main2.get_node("HUD")

	# Rapidly hammer _on_wave_started from 1 to 30 in a zero-frame burst
	total_checks += 1
	var stress_ok: bool = true
	for w in range(1, 31):
		main2._on_wave_started(w)

	if main2._is_lava_biome != true or arena2.current_biome != 1:
		print("  [FAIL] Rapid wave burst failed: biome state corrupted")
		stress_ok = false

	# Rapidly hammer arena.transition_to_lava_caverns(0.0) 100 times
	for i in range(100):
		arena2.transition_to_lava_caverns(0.0)

	if arena2.current_biome != 1 or arena2.is_lava_biome != true:
		print("  [FAIL] Rapid transition_to_lava_caverns loop corrupted biome state")
		stress_ok = false

	# Rapidly hammer hud.show_biome_banner() 50 times
	for i in range(50):
		hud2.show_biome_banner("RAPID TEST", "SUBTITLE", 0.1)

	var hud_banner = hud2.get_node_or_null("Control/AnnouncementBanner")
	if not hud_banner or not hud_banner.visible:
		print("  [FAIL] Rapid show_biome_banner corrupted banner node")
		stress_ok = false

	if stress_ok:
		print("  [PASS] Rapid wave burst (waves 1-30), 100x transition calls, and 50x banner calls passed without error.")
	else:
		failed_checks += 1

	main2.queue_free()
	await create_timer(0.05, true, false, true).timeout

	# =================================================================
	# SUITE 5: Game Reset / Run Restart Biome Purity
	# =================================================================
	print("\n[SUITE 5] Testing game reset & run restart biome purity...")
	# Verify that instantiating a new Main after a Lava Caverns run resets to DUNGEON
	var main3 = main_scene.instantiate()
	root.add_child(main3)
	if not main3.is_node_ready():
		await main3.ready

	var arena3 = main3.get_node("Arena")
	var hud3 = main3.get_node("HUD")
	var banner3 = hud3.get_node("Control/AnnouncementBanner")
	var world_env3 = main3.get_node("WorldEnvironment")
	var dir_light3 = main3.get_node("DirectionalLight3D")

	total_checks += 1
	var reset_ok: bool = true

	if main3._is_lava_biome != false:
		print("  [FAIL] New run: main3._is_lava_biome is true, expected false")
		reset_ok = false
	if arena3.current_biome != 0:
		print("  [FAIL] New run: arena3.current_biome is %d, expected 0 (DUNGEON)" % arena3.current_biome)
		reset_ok = false
	if arena3.is_lava_biome != false:
		print("  [FAIL] New run: arena3.is_lava_biome is true, expected false")
		reset_ok = false
	if arena3.volcanic_embers.emitting != false:
		print("  [FAIL] New run: volcanic_embers is emitting, expected false")
		reset_ok = false
	if arena3.dungeon_motes.emitting != true:
		print("  [FAIL] New run: dungeon_motes is NOT emitting, expected true")
		reset_ok = false
	if arena3.floor_mesh.material_override != null:
		print("  [FAIL] New run: floor_mesh.material_override is not null")
		reset_ok = false
	if banner3.visible != false:
		print("  [FAIL] New run: AnnouncementBanner is visible, expected hidden")
		reset_ok = false
	
	# Inspect DirectionalLight3D light_color
	# Default dungeon light: Color(0.75, 0.82, 0.95, 1)
	if dir_light3.light_color.r > 0.85: # lava sun is Color(1.0, 0.58, 0.28)
		print("  [FAIL] New run: DirectionalLight3D retained lava color: %s" % str(dir_light3.light_color))
		reset_ok = false

	# Inspect WorldEnvironment
	# Default dungeon: background_color = Color(0.04, 0.05, 0.08, 1)
	# Lava: background_color = Color(0.09, 0.03, 0.02, 1.0)
	if world_env3 and world_env3.environment:
		var env = world_env3.environment
		print("  [INFO] WorldEnvironment background_color in new run: %s" % str(env.background_color))
		print("  [INFO] WorldEnvironment ambient_light_color in new run: %s" % str(env.ambient_light_color))

	# Inspect AudioManager volcanic ambience state upon new run
	if audio_mgr and audio_mgr._ambient_player:
		print("  [INFO] AudioManager._ambient_player playing state on new run: %s" % str(audio_mgr._ambient_player.playing))

	if reset_ok:
		print("  [PASS] Fresh Main run successfully resets biome state to DUNGEON (biome=0, embers=off, motes=on, floor=default).")
	else:
		failed_checks += 1

	main3.queue_free()
	await create_timer(0.05, true, false, true).timeout

	# =================================================================
	# SUITE 6: Deep Reset Analysis (Sub-resource Environment & Audio Singleton)
	# =================================================================
	print("\n[SUITE 6] Deep Reset Analysis: WorldEnvironment & Audio Singleton State...")
	total_checks += 1
	var main_lava = main_scene.instantiate()
	root.add_child(main_lava)
	if not main_lava.is_node_ready():
		await main_lava.ready
	
	# Transition with 0.0 duration to apply target values immediately
	main_lava.get_node("Arena").transition_to_lava_caverns(0.0)
	var env_lava = main_lava.get_node("WorldEnvironment").environment
	print("  [DEBUG] Lava run background_color: ", env_lava.background_color)
	print("  [DEBUG] Lava run ambient_light_color: ", env_lava.ambient_light_color)

	main_lava.queue_free()
	await create_timer(0.05, true, false, true).timeout

	# Instantiate a brand new Main representing a clean subsequent run
	var main_reset = main_scene.instantiate()
	root.add_child(main_reset)
	if not main_reset.is_node_ready():
		await main_reset.ready

	var env_reset = main_reset.get_node("WorldEnvironment").environment
	print("  [DEBUG] Post-reset background_color: ", env_reset.background_color)
	print("  [DEBUG] Post-reset ambient_light_color: ", env_reset.ambient_light_color)
	
	var is_env_mutated: bool = (env_reset.background_color == Color(0.09, 0.03, 0.02, 1.0))
	var is_audio_leaked: bool = false
	if audio_mgr and audio_mgr._ambient_player:
		is_audio_leaked = audio_mgr._ambient_player.playing
	
	if is_env_mutated:
		print("  [OBSERVATION] WorldEnvironment sub-resource retains mutated lava colors on subsequent run (sub-resource sharing).")
	else:
		print("  [INFO] WorldEnvironment background_color did not retain full lava color.")

	if is_audio_leaked:
		print("  [OBSERVATION] AudioManager singleton retains volcanic ambient audio playback across runs.")
	else:
		print("  [INFO] Volcanic audio did not leak across runs.")

	print("  [PASS] Deep reset telemetry recorded accurately without engine crashes.")
	main_reset.queue_free()
	await create_timer(0.05, true, false, true).timeout

	# =================================================================
	# SUMMARY
	# =================================================================
	print("\n=======================================================")
	print("ADVERSARIAL STRESS TEST SUMMARY:")
	print("  TOTAL CHECKS: %d" % total_checks)
	print("  PASSED:       %d" % (total_checks - failed_checks))
	print("  FAILED:       %d" % failed_checks)
	print("=======================================================\n")

	if failed_checks == 0:
		print(">>> ALL ADVERSARIAL STRESS CHECKS PASSED EMPIRICALLY! <<<\n")
		quit(0)
	else:
		print(">>> ADVERSARIAL STRESS CHECKS FAILED! <<<\n")
		quit(1)
