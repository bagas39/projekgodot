extends SceneTree

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	print("\n--- RUNNING MILESTONE 3: HAZARDS & FALLING STALACTITES VERIFICATION ---")
	
	# -------------------------------------------------------------
	# 1. Molten Lava Floor Hazard verification (R2)
	# -------------------------------------------------------------
	print("[1/5] Verifying Molten Lava Floor Hazard...")
	var lava_scene: PackedScene = load("res://src/hazards/lava_floor_hazard.tscn")
	assert(lava_scene != null, "Lava floor hazard scene failed to load")
	var lava_hazard = lava_scene.instantiate()
	lava_hazard.auto_start = false
	root.add_child(lava_hazard)
	if not lava_hazard.is_node_ready():
		await lava_hazard.ready
	
	# Verify timing exports
	assert(abs(lava_hazard.telegraph_duration - 1.2) < 0.001, "Telegraph duration must be 1.2s")
	assert(abs(lava_hazard.erupting_duration - 1.5) < 0.001, "Erupting duration must be 1.5s")
	assert(abs(lava_hazard.erupt_duration - 1.5) < 0.001, "erupt_duration alias must be 1.5s")
	assert(lava_hazard.damage_per_tick == 15, "Damage per tick must be 15")
	assert(abs(lava_hazard.tick_interval - 0.35) < 0.001, "Tick interval must be 0.35s")
	
	# Verify Phase 1: Dormant
	lava_hazard._enter_dormant()
	assert(lava_hazard.current_state == 0, "current_state must be DORMANT (0)")
	assert(lava_hazard.warning_light.visible == false, "Warning light must be off when dormant")
	assert(lava_hazard.bubbling_particles.emitting == false, "Bubbling particles must be off when dormant")
	assert(lava_hazard.eruption_particles.emitting == false, "Eruption particles must be off when dormant")
	
	# Verify Phase 2: Telegraph (1.2s)
	lava_hazard._enter_telegraph()
	assert(lava_hazard.current_state == 1, "current_state must be TELEGRAPH (1)")
	assert(lava_hazard.warning_light.visible == true, "Warning light must be on when telegraphing")
	assert(lava_hazard.warning_light.light_color.r > 0.8 and lava_hazard.warning_light.light_color.g > 0.6, "Warning light must be yellow/orange telegraph color")
	assert(lava_hazard.bubbling_particles.emitting == true, "Bubbling particles must be emitting during telegraph")
	assert(lava_hazard.eruption_particles.emitting == false, "Eruption particles must be off during telegraph")
	
	# Verify Phase 3: Erupting (1.5s)
	lava_hazard._enter_erupting()
	assert(lava_hazard.current_state == 2, "current_state must be ERUPTING (2)")
	assert(lava_hazard.warning_light.visible == true, "Warning light must be on when erupting")
	assert(lava_hazard.warning_light.light_color.r > 0.8 and lava_hazard.warning_light.light_color.g < 0.4, "Warning light must be fiery red-orange when erupting")
	assert(lava_hazard.bubbling_particles.emitting == false, "Bubbling particles must be off when erupting")
	assert(lava_hazard.eruption_particles.emitting == true, "Eruption particles must be emitting when erupting")
	
	# Test Dual-Entity Damage (Player + Enemy)
	var player_scene: PackedScene = load("res://src/characters/player.tscn")
	assert(player_scene != null, "Player scene must load")
	var p_test = player_scene.instantiate()
	root.add_child(p_test)
	if not p_test.is_node_ready():
		await p_test.ready
	
	var slime_scene: PackedScene = load("res://src/enemies/enemy_slime.tscn")
	assert(slime_scene != null, "Slime scene must load")
	var e_test = slime_scene.instantiate()
	root.add_child(e_test)
	if not e_test.is_node_ready():
		await e_test.ready
	
	var p_hp_before: int = p_test.current_health
	var e_hp_before: int = e_test.current_health
	
	lava_hazard._deal_damage_to_target(p_test)
	lava_hazard._deal_damage_to_target(e_test)
	
	assert(p_test.current_health == p_hp_before - 15, "Player must take exactly 15 fire damage from lava")
	assert(e_test.current_health == e_hp_before - 15, "Enemy must take exactly 15 fire damage from lava")
	
	# Jolt transform safety
	assert(lava_hazard.scale.x > 0.0 and lava_hazard.scale.y > 0.0 and lava_hazard.scale.z > 0.0, "Lava hazard root scale must be positive")
	assert(lava_hazard.damage_area.scale == Vector3.ONE, "DamageArea scale must remain Vector3.ONE for Jolt safety")
	
	p_test.queue_free()
	e_test.queue_free()
	lava_hazard.queue_free()
	print("✓ Molten Lava Floor Hazard state cycle, telegraph timings, and dual-entity damage verified.")
	
	# -------------------------------------------------------------
	# 2. Rock Debris VFX & Rock Fragment verification
	# -------------------------------------------------------------
	print("[2/5] Verifying Rock Debris VFX and Rock Fragment...")
	var debris_scene: PackedScene = load("res://src/combat/rock_debris_vfx.tscn")
	assert(debris_scene != null, "Rock debris VFX scene must load")
	var debris = debris_scene.instantiate()
	root.add_child(debris)
	if not debris.is_node_ready():
		await debris.ready
	assert(debris.amount == 16, "Rock debris particle amount must be 16")
	assert(debris.one_shot == true, "Rock debris must be one_shot")
	debris.queue_free()
	
	var rock_scene: PackedScene = load("res://src/props/rock_fragment.tscn")
	assert(rock_scene != null, "Rock fragment scene must load")
	var rock = rock_scene.instantiate()
	root.add_child(rock)
	if not rock.is_node_ready():
		await rock.ready
	
	assert(rock.is_in_group("destructibles"), "Rock fragment must be in destructibles group")
	assert(rock.max_health == 20, "Rock fragment max health must be 20")
	assert(rock.current_health == 20, "Rock fragment current health must start at 20")
	
	# Damage reaction
	rock.take_damage(5)
	assert(rock.current_health == 15, "Rock fragment must have 15 HP after taking 5 damage")
	assert(rock.scale.x > 0.0 and rock.scale.y > 0.0 and rock.scale.z > 0.0, "Rock body scale must remain positive for Jolt safety")
	
	# Lethal hit & destruction
	rock.take_damage(20)
	assert(rock.is_destroyed == true, "Rock fragment must be flagged is_destroyed")
	assert(rock.collision_shape.disabled == true, "Collision shape must be disabled on destruction")
	assert(rock.scale.x > 0.0 and rock.scale.y > 0.0 and rock.scale.z > 0.0, "Rock body transform must never scale to zero in Jolt physics")
	rock.queue_free()
	print("✓ Rock Debris VFX and Rock Fragment health/destruction verified.")
	
	# -------------------------------------------------------------
	# 3. Falling Stalactite verification (R3)
	# -------------------------------------------------------------
	print("[3/5] Verifying Falling Stalactite Hazard...")
	var stalactite_scene: PackedScene = load("res://src/hazards/falling_stalactite.tscn")
	assert(stalactite_scene != null, "Falling stalactite scene must load")
	var stalactite = stalactite_scene.instantiate()
	root.add_child(stalactite)
	if not stalactite.is_node_ready():
		await stalactite.ready
	stalactite.global_position = Vector3(0, 0, 0)
	
	assert(abs(stalactite.warning_duration - 1.0) < 0.001, "Stalactite warning duration must be 1.0s")
	assert(abs(stalactite.fall_duration - 0.20) < 0.001, "Stalactite fall duration must be 0.20s")
	assert(abs(stalactite.impact_radius - 2.5) < 0.001, "Stalactite impact radius must be 2.5m")
	assert(stalactite.damage == 40, "Stalactite damage must be 40")
	assert(stalactite.current_state == 0, "Stalactite initial state must be TELEGRAPH (0)")
	
	# Setup test entities for impact test
	var p_victim = player_scene.instantiate()
	root.add_child(p_victim)
	if not p_victim.is_node_ready():
		await p_victim.ready
	p_victim.add_to_group("player")
	p_victim.global_position = Vector3(1.0, 0, 1.0) # within 2.5m
	
	var e_victim = slime_scene.instantiate()
	root.add_child(e_victim)
	if not e_victim.is_node_ready():
		await e_victim.ready
	e_victim.add_to_group("enemies")
	e_victim.global_position = Vector3(-1.0, 0, 0.5) # within 2.5m
	
	var e_safe = slime_scene.instantiate()
	root.add_child(e_safe)
	if not e_safe.is_node_ready():
		await e_safe.ready
	e_safe.add_to_group("enemies")
	e_safe.global_position = Vector3(10.0, 0, 10.0) # outside 2.5m
	
	var p_hp_init: int = p_victim.current_health
	var e_hp_init: int = e_victim.current_health
	var safe_hp_init: int = e_safe.current_health
	
	# Trigger deterministic impact
	stalactite.trigger_impact_now()
	
	assert(p_victim.current_health == p_hp_init - 40, "Player in impact zone must take 40 damage")
	assert(e_victim.current_health == e_hp_init - 40, "Enemy in impact zone must take 40 damage")
	assert(e_safe.current_health == safe_hp_init, "Enemy outside impact zone must take 0 damage")
	
	p_victim.queue_free()
	e_victim.queue_free()
	e_safe.queue_free()
	print("✓ Falling Stalactite drop parameters and 40 AoE impact damage verified.")
	
	# -------------------------------------------------------------
	# 4. Arena Scene Integration (4 Lava Fissures at Choke Points)
	# -------------------------------------------------------------
	print("[4/5] Verifying Arena Lava Fissures choke point deployment...")
	var arena_scene: PackedScene = load("res://src/arena/arena.tscn")
	assert(arena_scene != null, "Arena scene must load")
	var arena = arena_scene.instantiate()
	root.add_child(arena)
	if not arena.is_node_ready():
		await arena.ready
	
	var lava_container: Node3D = arena.get_node_or_null("LavaHazards")
	assert(lava_container != null, "Arena must contain LavaHazards node")
	assert(lava_container.get_child_count() == 4, "LavaHazards must contain exactly 4 fissures")
	
	var fiss1 = lava_container.get_node_or_null("LavaFissure1")
	var fiss2 = lava_container.get_node_or_null("LavaFissure2")
	var fiss3 = lava_container.get_node_or_null("LavaFissure3")
	var fiss4 = lava_container.get_node_or_null("LavaFissure4")
	assert(fiss1 != null and fiss2 != null and fiss3 != null and fiss4 != null, "All 4 fissures must exist")
	
	assert(fiss1.transform.origin.is_equal_approx(Vector3(-7, 0, 0)), "Fissure 1 must be at (-7, 0, 0)")
	assert(fiss2.transform.origin.is_equal_approx(Vector3(7, 0, 0)), "Fissure 2 must be at (7, 0, 0)")
	assert(fiss3.transform.origin.is_equal_approx(Vector3(0, 0, -4.5)), "Fissure 3 must be at (0, 0, -4.5)")
	assert(fiss4.transform.origin.is_equal_approx(Vector3(0, 0, 4.5)), "Fissure 4 must be at (0, 0, 4.5)")
	
	# Initial state: inactive
	assert(lava_container.visible == false, "LavaHazards container must be initially hidden")
	assert(fiss1.is_active == false, "Fissures must be initially inactive")
	
	# Transition activates them
	arena.transition_to_lava_caverns(0.0)
	assert(lava_container.visible == true, "LavaHazards container must be visible after transition")
	assert(fiss1.is_active == true, "Fissures must be activated after transition")
	assert(fiss2.is_active == true, "Fissure 2 must be active")
	assert(fiss3.is_active == true, "Fissure 3 must be active")
	assert(fiss4.is_active == true, "Fissure 4 must be active")
	
	arena.queue_free()
	print("✓ Arena 4 lava fissures choke points and dynamic activation verified.")
	
	# -------------------------------------------------------------
	# 5. Spawner Wave 6+ Dynamic Hazard Loop & Polish Fixes
	# -------------------------------------------------------------
	print("[5/5] Verifying Spawner dynamic hazard loop and polish fixes...")
	var spawner_script: GDScript = load("res://src/arena/spawner.gd")
	var spawner = Node3D.new()
	spawner.set_script(spawner_script)
	root.add_child(spawner)
	
	# Wave 1: stalactite_hazard_timer not set
	spawner.start_wave(1)
	assert(spawner.stalactite_hazard_timer == 0.0, "Wave 1 should not set stalactite timer")
	
	# Wave 6: stalactite_hazard_timer initialized between 4.5 and 7.0
	spawner.start_wave(6)
	assert(spawner.stalactite_hazard_timer >= 4.5 and spawner.stalactite_hazard_timer <= 7.0, "Wave 6 must set hazard timer in [4.5, 7.0]")
	
	# Verify HUD banner tween kill safety
	var hud_scene: PackedScene = load("res://src/ui/hud.tscn")
	var hud = hud_scene.instantiate()
	root.add_child(hud)
	if not hud.is_node_ready():
		await hud.ready
	hud.show_biome_banner("TEST 1")
	assert(hud._banner_tween != null and hud._banner_tween.is_valid(), "Banner tween must be active")
	hud.show_biome_banner("TEST 2") # Second call kills previous tween cleanly
	assert(hud._banner_tween != null and hud._banner_tween.is_valid(), "New banner tween created safely")
	
	hud.queue_free()
	spawner.queue_free()
	print("✓ Spawner hazard loop and HUD tween lifecycle verified.")
	
	print("\n=======================================================")
	print(">>> ALL MILESTONE 3 VERIFICATION CHECKS PASSED 100%! <<<")
	print("=======================================================\n")
	
	quit(0)
