extends SceneTree

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	print("\n--- RUNNING MILESTONE 2: BIOME PROGRESSION & DYNAMIC ARENA VERIFICATION ---")
	
	# -------------------------------------------------------------
	# 1. Shader verification
	# -------------------------------------------------------------
	print("[1/4] Verifying lava_basalt_floor.gdshader...")
	var shader: Shader = load("res://src/shaders/lava_basalt_floor.gdshader")
	assert(shader != null, "Shader failed to load")
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = shader
	assert(shader_mat.shader != null, "ShaderMaterial shader must be assigned")
	print("✓ Shader loads and assigns to ShaderMaterial successfully.")
	
	# -------------------------------------------------------------
	# 2. Arena scene & controller verification
	# -------------------------------------------------------------
	print("[2/4] Verifying Arena scene, controller, and transition...")
	var arena_scene: PackedScene = load("res://src/arena/arena.tscn")
	assert(arena_scene != null, "Arena scene failed to load")
	var arena = arena_scene.instantiate()
	root.add_child(arena)
	if not arena.is_node_ready():
		await arena.ready
	
	assert(arena.get_script() != null, "Arena must have arena.gd script attached")
	assert(arena.current_biome == 0, "Initial biome must be DUNGEON (0)")
	assert(arena.is_lava_biome == false, "Initial is_lava_biome must be false")
	
	var embers: GPUParticles3D = arena.get_node_or_null("VolcanicEmbers")
	assert(embers != null, "VolcanicEmbers node must exist in Arena")
	assert(embers is GPUParticles3D, "VolcanicEmbers must be GPUParticles3D")
	assert(embers.amount == 140, "VolcanicEmbers particle count must be 140")
	assert(embers.emitting == false, "VolcanicEmbers must NOT be emitting initially")
	
	var motes: GPUParticles3D = arena.get_node_or_null("DungeonMotes")
	assert(motes != null, "DungeonMotes node must exist")
	assert(motes.emitting == true, "DungeonMotes must be emitting initially")
	
	# Trigger transition
	arena.transition_to_lava_caverns(0.0)
	assert(arena.is_lava_biome == true, "is_lava_biome must be true after transition")
	assert(arena.current_biome == 1, "current_biome must be 1 (LAVA_CAVERNS)")
	assert(embers.emitting == true, "VolcanicEmbers must be emitting after transition")
	assert(motes.emitting == false, "DungeonMotes must stop emitting after transition")
	
	var floor_mesh: MeshInstance3D = arena.get_node_or_null("Floor/MeshInstance3D")
	assert(floor_mesh != null, "Floor MeshInstance3D must exist")
	assert(floor_mesh.material_override is ShaderMaterial, "Floor material_override must be a ShaderMaterial")
	var applied_shader = (floor_mesh.material_override as ShaderMaterial).shader
	assert(applied_shader == shader, "Floor shader must be lava_basalt_floor.gdshader")
	
	# Idempotency test: calling transition again should be safe and maintain state
	arena.transition_to_lava_caverns(0.0)
	assert(arena.is_lava_biome == true, "Idempotent transition maintains is_lava_biome == true")
	assert(arena.current_biome == 1, "Idempotent transition maintains current_biome == 1")
	print("✓ Arena controller, embers, floor shader, and idempotency verified.")
	arena.queue_free()
	
	# -------------------------------------------------------------
	# 3. HUD AnnouncementBanner verification
	# -------------------------------------------------------------
	print("[3/4] Verifying HUD AnnouncementBanner and show_biome_banner()...")
	var hud_scene: PackedScene = load("res://src/ui/hud.tscn")
	assert(hud_scene != null, "HUD scene failed to load")
	var hud = hud_scene.instantiate()
	root.add_child(hud)
	if not hud.is_node_ready():
		await hud.ready
	
	var banner: VBoxContainer = hud.get_node_or_null("Control/AnnouncementBanner")
	assert(banner != null, "AnnouncementBanner node must exist under Control in HUD")
	var title_lbl: Label = banner.get_node_or_null("BannerTitle")
	var subtitle_lbl: Label = banner.get_node_or_null("BannerSubtitle")
	assert(title_lbl != null, "BannerTitle must exist in AnnouncementBanner")
	assert(subtitle_lbl != null, "BannerSubtitle must exist in AnnouncementBanner")
	assert(banner.visible == false, "AnnouncementBanner must be initially hidden")
	assert(banner.modulate.a == 0.0, "AnnouncementBanner modulate.a must be 0 initially")
	
	# Trigger banner display
	hud.show_biome_banner("DESCENDING INTO LAVA CAVERNS", "BIOME II: VOLCANIC UNDERWORLD", 2.8)
	assert(banner.visible == true, "AnnouncementBanner must become visible when shown")
	assert(title_lbl.text == "DESCENDING INTO LAVA CAVERNS", "BannerTitle text must match")
	assert(subtitle_lbl.text == "BIOME II: VOLCANIC UNDERWORLD", "BannerSubtitle text must match")
	print("✓ HUD AnnouncementBanner and show_biome_banner() verified.")
	hud.queue_free()
	
	# -------------------------------------------------------------
	# 4. Main Scene Wave 6+ Transition Hook verification
	# -------------------------------------------------------------
	print("[4/4] Verifying Main scene Wave 6+ biome transition hook...")
	var main_scene: PackedScene = load("scenes/main.tscn")
	assert(main_scene != null, "Main scene failed to load")
	var main = main_scene.instantiate()
	root.add_child(main)
	if not main.is_node_ready():
		await main.ready
	
	assert(main._is_lava_biome == false, "Main _is_lava_biome must be false initially")
	var main_arena = main.get_node("Arena")
	assert(main_arena.is_lava_biome == false, "Main arena must be dungeon biome initially")
	
	# Trigger wave 1..5: should NOT trigger lava biome
	main._on_wave_started(1)
	assert(main._is_lava_biome == false, "Wave 1 must not trigger lava transition")
	main._on_wave_started(5)
	assert(main._is_lava_biome == false, "Wave 5 must not trigger lava transition")
	
	# Trigger wave 6: MUST trigger lava biome transition
	main._on_wave_started(6)
	assert(main._is_lava_biome == true, "Wave 6 must trigger lava transition in Main")
	assert(main_arena.is_lava_biome == true, "Arena must transition to lava biome")
	assert(main_arena.current_biome == 1, "Arena current_biome must be 1")
	var main_banner = main.get_node("HUD/Control/AnnouncementBanner")
	assert(main_banner.visible == true, "AnnouncementBanner must be shown in HUD")
	
	# Trigger wave 7: idempotent, no crash, maintains lava biome
	main._on_wave_started(7)
	assert(main._is_lava_biome == true, "Wave 7 maintains lava biome")
	print("✓ Main scene Wave 6+ biome transition hook and idempotency verified.")
	main.queue_free()
	
	print("\n=======================================================")
	print(">>> ALL MILESTONE 2 VERIFICATION CHECKS PASSED 100%! <<<")
	print("=======================================================\n")
	
	await create_timer(0.1, true, false, true).timeout
	quit(0)
