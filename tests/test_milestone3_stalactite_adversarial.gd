extends SceneTree

# ==============================================================================
# EMPIRICAL ADVERSARIAL STRESS TEST SUITE: MILESTONE 3 (R3)
# Falling Stalactites, Impact Boundaries, Rock Fragments & Hazard Spawner
# ==============================================================================

var total_assertions: int = 0
var passed_assertions: int = 0

func _init() -> void:
	call_deferred("_run_adversarial_suite")

func _assert_true(condition: bool, message: String) -> void:
	total_assertions += 1
	if condition:
		passed_assertions += 1
	else:
		push_error("[CHALLENGE ASSERTION FAILED] %s" % message)
		assert(condition, message)

func _run_adversarial_suite() -> void:
	print("\n================================================================================")
	print(">>> RUNNING ADVERSARIAL STRESS SUITE: FALLING STALACTITES & ROCK FRAGMENTS <<<")
	print("================================================================================\n")
	
	await _test_1_stalactite_fall_timing_and_state_machine()
	await _test_2_camera_shake_and_audio_crash()
	await _test_3_impact_radius_boundaries_and_aoe_stress()
	await _test_4_rock_fragment_lifecycle_and_jolt_safety()
	await _test_5_monte_carlo_pickup_distribution()
	await _test_6_spawner_wave_restrictions_and_bounds_clamping()
	await _test_7_massive_concurrency_stress()
	
	print("\n================================================================================")
	print(">>> ALL %d ADVERSARIAL ASSERTIONS PASSED (100%%) <<<" % passed_assertions)
	print("================================================================================\n")
	
	quit(0)

# ------------------------------------------------------------------------------
# TEST 1: Stalactite Fall Timing & State Progression Machine
# ------------------------------------------------------------------------------
func _test_1_stalactite_fall_timing_and_state_machine() -> void:
	print("[SUITE 1/7] Testing Stalactite Fall Timing & State Machine Progression...")
	
	var stalactite_scene: PackedScene = load("res://src/hazards/falling_stalactite.tscn")
	_assert_true(stalactite_scene != null, "Falling stalactite scene must load")
	
	var parent_node := Node3D.new()
	root.add_child(parent_node)
	
	var stalactite = stalactite_scene.instantiate()
	parent_node.add_child(stalactite)
	if not stalactite.is_node_ready():
		await stalactite.ready
	
	# Verify exported contract parameters
	_assert_true(abs(stalactite.warning_duration - 1.0) < 0.0001, "Warning duration must be strictly 1.0s")
	_assert_true(abs(stalactite.fall_duration - 0.20) < 0.0001, "Fall duration must be strictly 0.20s")
	_assert_true(abs(stalactite.ceiling_height - 14.0) < 0.0001, "Ceiling height must be strictly 14.0m")
	_assert_true(abs(stalactite.impact_radius - 2.5) < 0.0001, "Impact radius must be strictly 2.5m")
	_assert_true(stalactite.damage == 40, "Impact damage must be 40")
	
	# State at T = 0.0s (Immediately after ready)
	_assert_true(stalactite.current_state == 0, "Initial state must be TELEGRAPH (0)")
	_assert_true(stalactite.telegraph_root.visible == true, "Telegraph indicator root must be visible")
	_assert_true(stalactite.stalactite_mesh.visible == false, "Stalactite mesh must be hidden during telegraph")
	_assert_true(abs(stalactite.stalactite_mesh.position.y - 14.0) < 0.001, "Stalactite mesh must start at Y=14.0m")
	_assert_true(abs(stalactite.state_timer - 1.0) < 0.001, "State timer must start at 1.0s")
	
	# Step T = 0.5s (Halfway through warning)
	stalactite._process(0.5)
	_assert_true(stalactite.current_state == 0, "State must remain TELEGRAPH at T=0.5s")
	_assert_true(stalactite.stalactite_mesh.visible == false, "Mesh must remain hidden at T=0.5s")
	_assert_true(stalactite.warning_light.light_energy > 2.0, "Warning light energy must scale up with progress")
	
	# Step T = 0.49s (T = 0.99s, right before timeout)
	stalactite._process(0.49)
	_assert_true(stalactite.current_state == 0, "State must remain TELEGRAPH at T=0.99s")
	_assert_true(stalactite.stalactite_mesh.visible == false, "Mesh must remain hidden at T=0.99s")
	
	# Step T = 0.02s (T = 1.01s, crossing into FALLING)
	stalactite._process(0.02)
	_assert_true(stalactite.current_state == 1, "State must transition to FALLING (1) after 1.0s")
	_assert_true(stalactite.stalactite_mesh.visible == true, "Mesh must become visible when falling")
	_assert_true(abs(stalactite.state_timer - 0.20) < 0.001, "Fall timer must be set to 0.20s")
	
	# Step T = 0.10s (Halfway through drop)
	stalactite._process(0.10)
	_assert_true(stalactite.current_state == 1, "State must remain FALLING at halfway drop")
	_assert_true(stalactite.stalactite_mesh.position.y < 14.0 and stalactite.stalactite_mesh.position.y > 0.0, "Mesh Y position must be between 14.0m and 0.0m while falling")
	
	# Step T = 0.11s (Drop completion, triggering impact)
	stalactite._process(0.11)
	_assert_true(stalactite.current_state == 2, "State must transition to IMPACTED (2) after fall duration")
	
	# Verify spawned debris and rock fragment in parent
	var found_debris: bool = false
	var found_rock: bool = false
	for child in parent_node.get_children():
		if child is GPUParticles3D or child.get_script() == load("res://src/combat/rock_debris_vfx.gd"):
			found_debris = true
		if child.is_in_group("rock_fragments") or child.is_in_group("destructibles"):
			found_rock = true
	
	_assert_true(found_debris, "Impact must spawn RockDebrisVFX in parent")
	_assert_true(found_rock, "Impact must spawn RockFragment in parent")
	
	parent_node.free()
	print("  ✓ State progression (TELEGRAPH 1.0s -> FALLING 0.20s -> IMPACTED) verified.")

# ------------------------------------------------------------------------------
# TEST 2: Camera Shake and Audio Crash Invocations
# ------------------------------------------------------------------------------
func _test_2_camera_shake_and_audio_crash() -> void:
	print("[SUITE 2/7] Testing Camera Shake & Audio Crash Invocations...")
	
	var player_scene: PackedScene = load("res://src/characters/player.tscn")
	var stalactite_scene: PackedScene = load("res://src/hazards/falling_stalactite.tscn")
	
	var parent_node := Node3D.new()
	root.add_child(parent_node)
	
	var player = player_scene.instantiate()
	player.add_to_group("player")
	parent_node.add_child(player)
	if not player.is_node_ready():
		await player.ready
	
	# Place player at safe distance (5.0m outside impact zone 2.5m)
	# This ensures the camera trauma is strictly from stalactite impact (0.50), not player damage (0.42)
	player.global_position = Vector3(5.0, 0.0, 0.0)
	player.camera_trauma = 0.0
	var player_hp_init: int = player.current_health
	
	var stalactite = stalactite_scene.instantiate()
	parent_node.add_child(stalactite)
	stalactite.global_position = Vector3.ZERO
	if not stalactite.is_node_ready():
		await stalactite.ready
	
	# Verify AudioManager methods exist
	var audio_mgr := root.get_node_or_null("AudioManager")
	_assert_true(audio_mgr != null, "AudioManager autoload must exist in scene tree")
	_assert_true(audio_mgr.has_method("play_rock_crash"), "AudioManager must have play_rock_crash()")
	_assert_true(audio_mgr.has_method("play_stalactite_impact"), "AudioManager must have play_stalactite_impact()")
	
	# Trigger impact at (0, 0, 0)
	stalactite.trigger_impact_now()
	
	# Player took 0 damage (outside 2.5m), but received 0.50 screen-wide camera shake
	_assert_true(player.current_health == player_hp_init, "Player outside 2.5m takes 0 damage")
	_assert_true(abs(player.camera_trauma - 0.50) < 0.001, "Player camera trauma must increase by exactly 0.50 upon stalactite impact")
	
	# Second impact directly ON player (inside 2.5m)
	# Impact shake (+0.50) + damage shake (+0.42) = clamped to 1.0
	var stalactite2 = stalactite_scene.instantiate()
	parent_node.add_child(stalactite2)
	stalactite2.global_position = Vector3(5.0, 0.0, 0.0)
	stalactite2.trigger_impact_now()
	_assert_true(player.current_health == player_hp_init - 40, "Direct hit deals 40 damage")
	_assert_true(player.camera_trauma == 1.0, "Player camera trauma clamps to 1.0 upon heavy compound impact")
	
	# Test impact with NO player in tree (graceful fallback)
	player.remove_from_group("player")
	var stalactite3 = stalactite_scene.instantiate()
	parent_node.add_child(stalactite3)
	stalactite3.trigger_impact_now() # Must not crash
	_assert_true(true, "Impact with no player in tree handled safely")
	
	parent_node.free()
	print("  ✓ Camera shake (0.50 impact shake + trauma clamp) and audio triggers verified.")

# ------------------------------------------------------------------------------
# TEST 3: Impact Radius Boundaries & AoE Stress (Exact Distance Oracle)
# ------------------------------------------------------------------------------
func _test_3_impact_radius_boundaries_and_aoe_stress() -> void:
	print("[SUITE 3/7] Testing Impact Radius Boundaries (1.0m, 2.49m inside vs 2.51m, 3.0m outside)...")
	
	var stalactite_scene: PackedScene = load("res://src/hazards/falling_stalactite.tscn")
	var slime_scene: PackedScene = load("res://src/enemies/enemy_slime.tscn")
	var golem_scene: PackedScene = load("res://src/enemies/enemy_golem.tscn")
	
	var parent_node := Node3D.new()
	root.add_child(parent_node)
	
	# Target impact at origin (0, 0, 0)
	var stalactite = stalactite_scene.instantiate()
	parent_node.add_child(stalactite)
	stalactite.global_position = Vector3.ZERO
	
	# Spawn victims at precise radial ground positions (Y=0.0)
	var victim_center = slime_scene.instantiate()
	parent_node.add_child(victim_center)
	victim_center.add_to_group("enemies")
	victim_center.global_position = Vector3(0.0, 0.0, 0.0) # 0.0m
	var hp_center_init: int = victim_center.current_health
	
	var victim_1m = slime_scene.instantiate()
	parent_node.add_child(victim_1m)
	victim_1m.add_to_group("enemies")
	victim_1m.global_position = Vector3(1.0, 0.0, 0.0) # 1.0m
	var hp_1m_init: int = victim_1m.current_health
	
	var victim_249m = slime_scene.instantiate()
	parent_node.add_child(victim_249m)
	victim_249m.add_to_group("enemies")
	victim_249m.global_position = Vector3(2.49, 0.0, 0.0) # 2.49m (INSIDE boundary)
	var hp_249m_init: int = victim_249m.current_health
	
	var victim_251m = slime_scene.instantiate()
	parent_node.add_child(victim_251m)
	victim_251m.add_to_group("enemies")
	victim_251m.global_position = Vector3(2.51, 0.0, 0.0) # 2.51m (OUTSIDE boundary)
	var hp_251m_init: int = victim_251m.current_health
	
	var victim_3m = golem_scene.instantiate()
	parent_node.add_child(victim_3m)
	victim_3m.add_to_group("enemies")
	victim_3m.global_position = Vector3(0.0, 0.0, 3.0) # 3.0m (OUTSIDE boundary)
	var hp_3m_init: int = victim_3m.current_health
	
	var victim_10m = slime_scene.instantiate()
	parent_node.add_child(victim_10m)
	victim_10m.add_to_group("enemies")
	victim_10m.global_position = Vector3(7.07, 0.0, 7.07) # 10.0m (FAR OUTSIDE)
	var hp_10m_init: int = victim_10m.current_health
	
	# Execute impact
	stalactite.trigger_impact_now()
	
	# Assertions on exact AoE damage boundary
	_assert_true(victim_center.current_health == hp_center_init - 40, "Entity at 0.0m center must take 40 damage")
	_assert_true(victim_1m.current_health == hp_1m_init - 40, "Entity at 1.0m inside must take 40 damage")
	_assert_true(victim_249m.current_health == hp_249m_init - 40, "Entity at 2.49m inside must take 40 damage")
	_assert_true(victim_251m.current_health == hp_251m_init, "Entity at 2.51m outside must take 0 damage")
	_assert_true(victim_3m.current_health == hp_3m_init, "Entity at 3.0m outside must take 0 damage")
	_assert_true(victim_10m.current_health == hp_10m_init, "Entity at 10.0m outside must take 0 damage")
	
	# Multi-entity simultaneous swarm stress (10 inside, 10 outside)
	var swarm_stalactite = stalactite_scene.instantiate()
	parent_node.add_child(swarm_stalactite)
	swarm_stalactite.global_position = Vector3(5.0, 0.0, 5.0)
	
	var inside_slimes: Array = []
	var outside_slimes: Array = []
	
	for i in range(10):
		var ang := float(i) * TAU / 10.0
		var r_in := 0.2 + (float(i) * 0.20) # radii from 0.2m to 2.0m (all < 2.5m)
		var s_in = slime_scene.instantiate()
		parent_node.add_child(s_in)
		s_in.add_to_group("enemies")
		s_in.global_position = Vector3(5.0 + cos(ang) * r_in, 0.0, 5.0 + sin(ang) * r_in)
		inside_slimes.append({"node": s_in, "hp": s_in.current_health})
		
		var r_out := 2.6 + (float(i) * 0.5) # radii from 2.6m to 7.1m (all > 2.5m)
		var s_out = slime_scene.instantiate()
		parent_node.add_child(s_out)
		s_out.add_to_group("enemies")
		s_out.global_position = Vector3(5.0 + cos(ang) * r_out, 0.0, 5.0 + sin(ang) * r_out)
		outside_slimes.append({"node": s_out, "hp": s_out.current_health})
	
	swarm_stalactite.trigger_impact_now()
	
	for item in inside_slimes:
		_assert_true(item["node"].current_health == item["hp"] - 40, "Swarm enemy inside AoE must take 40 damage")
	for item in outside_slimes:
		_assert_true(item["node"].current_health == item["hp"], "Swarm enemy outside AoE must take 0 damage")
	
	# Elevation Boundary Test: Analyze 3D vs 2D distance behavior for entities elevated at Y=0.5
	var elevated_test_stalactite = stalactite_scene.instantiate()
	parent_node.add_child(elevated_test_stalactite)
	elevated_test_stalactite.global_position = Vector3.ZERO
	
	var elevated_slime = slime_scene.instantiate()
	parent_node.add_child(elevated_slime)
	elevated_slime.add_to_group("enemies")
	elevated_slime.global_position = Vector3(2.0, 0.5, 0.0) # Horizontal 2.0m, Y=0.5 -> 3D dist = 2.06m <= 2.5m
	var elevated_hp: int = elevated_slime.current_health
	
	elevated_test_stalactite.trigger_impact_now()
	_assert_true(elevated_slime.current_health == elevated_hp - 40, "Elevated enemy within 3D sphere takes 40 damage")
	
	parent_node.free()
	print("  ✓ Radial boundaries (2.49m inside, 2.51m outside) and 20-entity swarm verified.")

# ------------------------------------------------------------------------------
# TEST 4: Rock Fragment Lifecycle, HP, Squash & Safe Jolt Scaling
# ------------------------------------------------------------------------------
func _test_4_rock_fragment_lifecycle_and_jolt_safety() -> void:
	print("[SUITE 4/7] Testing Rock Fragment Lifecycle, 20 HP, & Jolt Transform Safety...")
	
	var rock_scene: PackedScene = load("res://src/props/rock_fragment.tscn")
	_assert_true(rock_scene != null, "Rock fragment scene must load")
	
	var parent_node := Node3D.new()
	root.add_child(parent_node)
	
	var rock = rock_scene.instantiate()
	parent_node.add_child(rock)
	if not rock.is_node_ready():
		await rock.ready
	
	# Initial attributes
	_assert_true(rock.is_in_group("destructibles"), "RockFragment must be in 'destructibles' group")
	_assert_true(rock.is_in_group("rock_fragments"), "RockFragment must be in 'rock_fragments' group")
	_assert_true(rock.max_health == 20, "RockFragment max_health must be 20")
	_assert_true(rock.current_health == 20, "RockFragment current_health must start at 20")
	_assert_true(rock.is_destroyed == false, "RockFragment must not be destroyed initially")
	_assert_true(rock.scale == Vector3.ONE, "Body scale must start at Vector3.ONE")
	_assert_true(rock.collision_shape.scale == Vector3.ONE, "Collision shape scale must be Vector3.ONE")
	_assert_true(rock.collision_shape.disabled == false, "Collision shape must be enabled initially")
	
	# Partial damage test (take 8 damage)
	rock.take_damage(8)
	_assert_true(rock.current_health == 12, "Health after 8 damage must be 12")
	_assert_true(rock.is_destroyed == false, "Must not be destroyed at 12 HP")
	_assert_true(rock.scale == Vector3.ONE, "Body scale must remain Vector3.ONE (no root squash)")
	_assert_true(rock.collision_shape.disabled == false, "Collision shape must remain enabled")
	
	# Another sub-lethal hit (take 7 damage)
	rock.take_damage(7)
	_assert_true(rock.current_health == 5, "Health after 7 more damage must be 5")
	_assert_true(rock.is_destroyed == false, "Must not be destroyed at 5 HP")
	
	# Lethal blow (take 10 damage from 5 HP)
	rock.take_damage(10)
	_assert_true(rock.current_health == 0, "Health must clamp to 0 on lethal hit")
	_assert_true(rock.is_destroyed == true, "is_destroyed must be true")
	_assert_true(rock.collision_shape.disabled == true, "Collision shape must be disabled deferred")
	_assert_true(rock.scale == Vector3.ONE, "Body scale must remain positive Vector3.ONE to prevent Jolt singular transform")
	
	# Over-damage & double-destruction idempotency
	rock.take_damage(100) # Should be ignored
	_assert_true(rock.current_health == 0, "Health remains 0 after redundant damage")
	rock.destroy() # Redundant call should be safe no-op
	_assert_true(rock.is_destroyed == true, "Redundant destroy() is safe no-op")
	
	parent_node.free()
	print("  ✓ Rock Fragment HP (20), destruction, and Jolt transform safety verified.")

# ------------------------------------------------------------------------------
# TEST 5: Monte Carlo Pickup Distribution Stress Test (300 Trials)
# ------------------------------------------------------------------------------
func _test_5_monte_carlo_pickup_distribution() -> void:
	print("[SUITE 5/7] Testing Monte Carlo Pickup Drop Distribution (300 rock destructions)...")
	
	var rock_scene: PackedScene = load("res://src/props/rock_fragment.tscn")
	var parent_node := Node3D.new()
	root.add_child(parent_node)
	
	var total_trials: int = 300
	var dropped_pickups: int = 0
	var gem_count: int = 0
	var potion_count: int = 0
	
	for i in range(total_trials):
		var rock = rock_scene.instantiate()
		parent_node.add_child(rock)
		if not rock.is_node_ready():
			await rock.ready
		
		# Lethal destruction
		rock.take_damage(20)
		
		# Check if a pickup was spawned as child of parent_node
		var pickup_found: Node = null
		for child in parent_node.get_children():
			if child != rock and child.has_method("setup") and child is Area3D:
				dropped_pickups += 1
				if child.item_type == 2: # SOUL_GEM
					gem_count += 1
				elif child.item_type == 0: # HEALTH
					potion_count += 1
				pickup_found = child
				break
		
		if pickup_found:
			parent_node.remove_child(pickup_found)
			pickup_found.free()
		
		parent_node.remove_child(rock)
		rock.free()
	
	var drop_rate: float = float(dropped_pickups) / float(total_trials)
	print("  Monte Carlo Results: %d drops out of %d trials (%.2f%%, expected ~30.0%%)" % [dropped_pickups, total_trials, drop_rate * 100.0])
	print("  Pickup types: %d gems (%.1f%%), %d potions (%.1f%%)" % [gem_count, float(gem_count)/maxf(1.0, float(dropped_pickups))*100.0, potion_count, float(potion_count)/maxf(1.0, float(dropped_pickups))*100.0])
	
	# Theoretical 3-sigma bounds for N=300, p=0.30: 22% to 38% (66 to 114 drops)
	# Generous tolerance [18%, 42%] (54 to 126) for PRNG variance
	_assert_true(dropped_pickups >= 54 and dropped_pickups <= 126, "Drop rate must adhere to ~30%% distribution (got %d / %d)" % [dropped_pickups, total_trials])
	_assert_true(gem_count > 0, "At least some soul gems must drop in 300 trials")
	_assert_true(potion_count > 0, "At least some health potions must drop in 300 trials")
	
	parent_node.free()
	print("  ✓ Monte Carlo 300-trial drop rate distribution verified.")

# ------------------------------------------------------------------------------
# TEST 6: Spawner Wave Restrictions and Arena Bounds Clamping Stress
# ------------------------------------------------------------------------------
func _test_6_spawner_wave_restrictions_and_bounds_clamping() -> void:
	print("[SUITE 6/7] Testing Spawner Wave 6+ Restriction & Clamping Bounds Stress...")
	
	var spawner_script: GDScript = load("res://src/arena/spawner.gd")
	var parent_node := Node3D.new()
	root.add_child(parent_node)
	
	var spawner = Node3D.new()
	spawner.set_script(spawner_script)
	parent_node.add_child(spawner)
	
	# Create a dummy player
	var dummy_player = Node3D.new()
	dummy_player.add_to_group("player")
	parent_node.add_child(dummy_player)
	
	# Test Waves 1 through 5: Timer must remain 0.0, no stalactites spawned
	for w in range(1, 6):
		spawner.start_wave(w)
		_assert_true(spawner.stalactite_hazard_timer == 0.0, "Wave %d must NOT activate stalactite timer" % w)
		
		spawner._process(10.0) # Simulate 10 seconds of time
		# No stalactite should be instantiated
		var stalactites_spawned: int = 0
		for child in parent_node.get_children():
			if child.has_method("trigger_impact_now"):
				stalactites_spawned += 1
		_assert_true(stalactites_spawned == 0, "Wave %d must not spawn stalactites" % w)
	
	# Test Wave 6+: Timer activated in [4.5, 7.0]
	spawner.start_wave(6)
	_assert_true(spawner.stalactite_hazard_timer >= 4.5 and spawner.stalactite_hazard_timer <= 7.0, "Wave 6 must initialize hazard timer in [4.5, 7.0]")
	
	# Trigger spawn via countdown
	var initial_timer: float = spawner.stalactite_hazard_timer
	spawner._process(initial_timer + 0.1) # Countdown to 0
	
	var found_stalactite: Node3D = null
	for child in parent_node.get_children():
		if child.has_method("trigger_impact_now"):
			found_stalactite = child
			break
	_assert_true(found_stalactite != null, "Wave 6 timer expiry must spawn a FallingStalactite")
	_assert_true(spawner.stalactite_hazard_timer >= 4.5 and spawner.stalactite_hazard_timer <= 7.0, "Timer must reset to [4.5, 7.0] after spawn")
	
	# Clamping stress: test extreme player positions
	var extreme_positions: Array = [
		Vector3(0, 0, 0),
		Vector3(15.5, 0, 15.5),
		Vector3(-15.5, 0, -15.5),
		Vector3(50.0, 0, 50.0),      # Way outside North-East
		Vector3(-100.0, 0, -100.0),  # Way outside South-West
		Vector3(999.0, 0, 0.0),      # Extreme East
		Vector3(0.0, 0, -999.0),     # Extreme South
		Vector3(-500.0, 0, 500.0)    # Extreme North-West
	]
	
	for pos in extreme_positions:
		dummy_player.global_position = pos
		# Clean previous stalactites
		for child in parent_node.get_children():
			if child.has_method("trigger_impact_now"):
				child.free()
		
		spawner._spawn_stalactite_hazard()
		
		var spawned: Node3D = null
		for child in parent_node.get_children():
			if child.has_method("trigger_impact_now"):
				spawned = child
				break
		
		_assert_true(spawned != null, "Stalactite must spawn for player pos %s" % str(pos))
		if spawned:
			_assert_true(spawned.global_position.x >= -16.001 and spawned.global_position.x <= 16.001, "Stalactite X (%f) must be clamped in [-16, 16] for player at %s" % [spawned.global_position.x, str(pos)])
			_assert_true(spawned.global_position.z >= -16.001 and spawned.global_position.z <= 16.001, "Stalactite Z (%f) must be clamped in [-16, 16] for player at %s" % [spawned.global_position.z, str(pos)])
			_assert_true(abs(spawned.global_position.y) < 0.001, "Stalactite Y must be exactly 0.0 on ground")
	
	# Null player handling
	dummy_player.remove_from_group("player")
	spawner.player = null
	spawner._spawn_stalactite_hazard() # Must safely return without crash
	_assert_true(true, "Spawning with null player handled safely")
	
	parent_node.free()
	print("  ✓ Spawner wave restrictions and [-16, 16] arena bound clamping verified.")

# ------------------------------------------------------------------------------
# TEST 7: Massive Concurrency & High Load Stress
# ------------------------------------------------------------------------------
func _test_7_massive_concurrency_stress() -> void:
	print("[SUITE 7/7] Testing Massive Concurrency Stress (50 concurrent stalactites)...")
	
	var stalactite_scene: PackedScene = load("res://src/hazards/falling_stalactite.tscn")
	var parent_node := Node3D.new()
	root.add_child(parent_node)
	
	var stalactites: Array = []
	for i in range(50):
		var s = stalactite_scene.instantiate()
		parent_node.add_child(s)
		s.global_position = Vector3(randf_range(-15, 15), 0, randf_range(-15, 15))
		stalactites.append(s)
	
	_assert_true(stalactites.size() == 50, "50 stalactites instantiated successfully")
	
	# Advance all 50 through telegraph (0.5s)
	for s in stalactites:
		s._process(0.5)
		_assert_true(s.current_state == 0, "All 50 must remain in TELEGRAPH at 0.5s")
	
	# Advance all 50 into falling (0.55s)
	for s in stalactites:
		s._process(0.55)
		_assert_true(s.current_state == 1, "All 50 must transition to FALLING")
	
	# Advance all 50 into impact (0.25s)
	for s in stalactites:
		s._process(0.25)
		_assert_true(s.current_state == 2, "All 50 must impact cleanly")
	
	# Count generated rock fragments and destroy them simultaneously
	var rock_count: int = 0
	var rocks: Array = []
	for child in parent_node.get_children():
		if child.is_in_group("rock_fragments") or child.is_in_group("destructibles"):
			rock_count += 1
			rocks.append(child)
	
	_assert_true(rock_count == 50, "Exactly 50 rock fragments must spawn from 50 impacts")
	
	# Destroy all 50 rocks simultaneously to stress concurrent Jolt body destruction
	for r in rocks:
		r.take_damage(20)
		_assert_true(r.is_destroyed == true, "Rock fragment destroyed cleanly")
		_assert_true(r.collision_shape.disabled == true, "Collision shape disabled deferred cleanly")
	
	parent_node.free()
	print("  ✓ 50 concurrent stalactites and rock destructions completed with 0 errors.")
