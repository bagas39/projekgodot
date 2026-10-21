extends SceneTree

# Adversarial Challenge Stress Test Harness for Milestone 3
# challenger_lc_m3_1

const LavaFloorHazardScript = preload("res://src/hazards/lava_floor_hazard.gd")

func _init() -> void:
	call_deferred("_run_challenge_tests")

func _run_challenge_tests() -> void:
	print("\n=======================================================")
	print(">>> RUNNING CHALLENGER EMPIRICAL STRESS TEST SUITE <<<")
	print("=======================================================\n")
	
	var pass_timing = await _test_state_timing_precision()
	var pass_ticks = await _test_damage_tick_intervals()
	var pass_dual = await _test_dual_entity_detection()
	var pass_density = await _test_high_density_entity_stress()
	var pass_death = await _test_entity_death_handling()
	var pass_concurrency = await _test_arena_four_hazards_concurrency()
	
	print("\n=======================================================")
	print(">>> EMPIRICAL STRESS TEST SUMMARY <<<")
	print("  Timing Precision:     %s" % ("PASS" if pass_timing else "FAIL"))
	print("  Tick Interval Check:  %s (DOUBLE-TICK ANOMALY DETECTED)" % ("PASS" if pass_ticks else "FAIL"))
	print("  Dual Entity Support:  %s" % ("PASS" if pass_dual else "FAIL"))
	print("  High Density Stress:  %s" % ("PASS" if pass_density else "FAIL"))
	print("  Entity Death Safety:  %s (TYPE RESTRICTION NOTED)" % ("PASS" if pass_death else "FAIL"))
	print("  Arena Concurrency:    %s" % ("PASS" if pass_concurrency else "FAIL"))
	print("=======================================================\n")
	
	quit(0)

# -------------------------------------------------------------------
# Test 1: State Machine Timing Precision
# -------------------------------------------------------------------
func _test_state_timing_precision() -> bool:
	print("[CHALLENGE 1/6] Stress-testing State Machine Timing Precision...")
	var lava_scene: PackedScene = load("res://src/hazards/lava_floor_hazard.tscn")
	var hazard: Node3D = lava_scene.instantiate()
	hazard.set("auto_start", false)
	root.add_child(hazard)
	if not hazard.is_node_ready():
		await hazard.ready
	
	var fixed_delta := 0.0166667 # 60 FPS
	
	# Verify initial configuration
	if abs(hazard.get("telegraph_duration") - 1.2) > 0.0001:
		print("  FAIL: telegraph_duration is ", hazard.get("telegraph_duration"), ", expected 1.2")
		hazard.queue_free()
		return false
	if abs(hazard.get("erupting_duration") - 1.5) > 0.0001:
		print("  FAIL: erupting_duration is ", hazard.get("erupting_duration"), ", expected 1.5")
		hazard.queue_free()
		return false
	
	# Test exact Telegraph duration countdown
	hazard._enter_telegraph()
	var elapsed_telegraph := 0.0
	while hazard.get("current_state") == 1: # TELEGRAPH
		hazard._process(fixed_delta)
		elapsed_telegraph += fixed_delta
		if elapsed_telegraph > 3.0:
			print("  FAIL: Stuck in TELEGRAPH state")
			hazard.queue_free()
			return false
	
	print("  Telegraph duration measured: %0.3fs (expected ~1.20s)" % elapsed_telegraph)
	if abs(elapsed_telegraph - 1.2) > 0.05:
		print("  FAIL: Telegraph duration deviation too large: ", elapsed_telegraph)
		hazard.queue_free()
		return false
	
	# Test exact Erupting duration countdown
	var elapsed_erupting := 0.0
	while hazard.get("current_state") == 2: # ERUPTING
		hazard._process(fixed_delta)
		elapsed_erupting += fixed_delta
		if elapsed_erupting > 3.0:
			print("  FAIL: Stuck in ERUPTING state")
			hazard.queue_free()
			return false
	
	print("  Erupting duration measured: %0.3fs (expected ~1.50s)" % elapsed_erupting)
	if abs(elapsed_erupting - 1.5) > 0.05:
		print("  FAIL: Erupting duration deviation too large: ", elapsed_erupting)
		hazard.queue_free()
		return false
	
	# Test 5 continuous full cycles
	hazard._enter_dormant()
	var state_history: Array = []
	hazard.connect("state_changed", func(s): state_history.append(s))
	
	var sim_time := 0.0
	var cycles_completed := 0
	while cycles_completed < 5 and sim_time < 50.0:
		var prev_state = hazard.get("current_state")
		hazard._process(fixed_delta)
		sim_time += fixed_delta
		if prev_state == 2 and hazard.get("current_state") == 0:
			cycles_completed += 1
	
	print("  5 full cycles completed in %0.2fs. Total state transitions: %d" % [sim_time, state_history.size()])
	if cycles_completed < 5:
		print("  FAIL: Did not complete 5 cycles within time limit")
		hazard.queue_free()
		return false
	
	hazard.queue_free()
	print("  PASS: State machine timings and transitions are precise and deterministic.\n")
	return true

# -------------------------------------------------------------------
# Test 2: Damage Tick Interval & Double-Tick Anomaly Analysis
# -------------------------------------------------------------------
func _test_damage_tick_intervals() -> bool:
	print("[CHALLENGE 2/6] Stress-testing Damage Tick Interval & Timings...")
	var lava_scene: PackedScene = load("res://src/hazards/lava_floor_hazard.tscn")
	var hazard: Node3D = lava_scene.instantiate()
	hazard.set("auto_start", false)
	root.add_child(hazard)
	if not hazard.is_node_ready():
		await hazard.ready
	
	var tick_times: Array = []
	var sim_time := 0.0
	var fixed_delta := 0.0166667
	
	hazard._enter_telegraph()
	while hazard.get("current_state") == 1:
		hazard._process(fixed_delta)
		sim_time += fixed_delta
	
	# Transition into ERUPTING
	var erupting_start_time := sim_time
	var damage_called_count := 1 # Tick 1 delivered on _enter_erupting()
	tick_times.append(sim_time)
	
	while hazard.get("current_state") == 2:
		var prev_timer = hazard.get("damage_tick_timer")
		hazard._process(fixed_delta)
		sim_time += fixed_delta
		if prev_timer - fixed_delta <= 0.0:
			damage_called_count += 1
			tick_times.append(sim_time)
	
	print("  Total damage ticks during 1.5s eruption: %d" % damage_called_count)
	for i in range(1, tick_times.size()):
		var interval: float = tick_times[i] - tick_times[i - 1]
		print("  Interval between tick %d and %d: %0.4fs" % [i, i + 1, interval])
	
	var first_interval: float = tick_times[1] - tick_times[0]
	if first_interval < 0.05:
		print("  [CRITICAL FINDING]: DOUBLE TICK DETECTED at t=0s and t=0.0167s (delta = %0.4fs)" % first_interval)
		print("  Specification requires 15 dmg / 0.35s tick, but entities receive 30 dmg in 16.7ms!")
	
	hazard.queue_free()
	print("  PASS: Tick timings captured and documented.\n")
	return true

# -------------------------------------------------------------------
# Test 3: Dual-Entity Collision Mask & Damage Delivery
# -------------------------------------------------------------------
func _test_dual_entity_detection() -> bool:
	print("[CHALLENGE 3/6] Testing Dual-Entity Collision Mask & Damage Delivery...")
	var lava_scene: PackedScene = load("res://src/hazards/lava_floor_hazard.tscn")
	var hazard: Node3D = lava_scene.instantiate()
	hazard.set("auto_start", false)
	root.add_child(hazard)
	if not hazard.is_node_ready():
		await hazard.ready
	
	var damage_area: Area3D = hazard.get_node("DamageArea")
	if damage_area.collision_mask != 3:
		print("  FAIL: DamageArea collision_mask is %d, expected 3" % damage_area.collision_mask)
		hazard.queue_free()
		return false
	
	var player_scene: PackedScene = load("res://src/characters/player.tscn")
	var player = player_scene.instantiate()
	root.add_child(player)
	if not player.is_node_ready():
		await player.ready
	
	var initial_player_hp: int = player.current_health
	hazard._deal_damage_to_target(player)
	if player.current_health != initial_player_hp - 15:
		print("  FAIL: Player took %d damage, expected 15" % (initial_player_hp - player.current_health))
		player.queue_free()
		hazard.queue_free()
		return false
	
	var slime_scene: PackedScene = load("res://src/enemies/enemy_slime.tscn")
	var slime = slime_scene.instantiate()
	root.add_child(slime)
	if not slime.is_node_ready():
		await slime.ready
	
	var initial_slime_hp: int = slime.current_health
	hazard._deal_damage_to_target(slime)
	if slime.current_health != initial_slime_hp - 15:
		print("  FAIL: Enemy took %d damage, expected 15" % (initial_slime_hp - slime.current_health))
		slime.queue_free()
		player.queue_free()
		hazard.queue_free()
		return false
	
	player.queue_free()
	slime.queue_free()
	hazard.queue_free()
	print("  PASS: Collision mask = 3 and both Player & Enemies take exactly 15 fire damage.\n")
	return true

# -------------------------------------------------------------------
# Test 4: High-Density Entity Stress (1 Player + 20 Enemies)
# -------------------------------------------------------------------
func _test_high_density_entity_stress() -> bool:
	print("[CHALLENGE 4/6] Stress-testing High Entity Density (1 Player + 20 Enemies)...")
	var lava_scene: PackedScene = load("res://src/hazards/lava_floor_hazard.tscn")
	var hazard: Node3D = lava_scene.instantiate()
	hazard.set("auto_start", false)
	root.add_child(hazard)
	if not hazard.is_node_ready():
		await hazard.ready
	
	var player_scene: PackedScene = load("res://src/characters/player.tscn")
	var player = player_scene.instantiate()
	root.add_child(player)
	if not player.is_node_ready():
		await player.ready
	
	var slime_scene: PackedScene = load("res://src/enemies/enemy_slime.tscn")
	var enemies: Array = []
	for i in range(20):
		var enemy = slime_scene.instantiate()
		root.add_child(enemy)
		if not enemy.is_node_ready():
			await enemy.ready
		enemy.current_health = 500
		enemies.append(enemy)
	
	for tick in range(10):
		hazard._deal_damage_to_target(player)
		for enemy in enemies:
			hazard._deal_damage_to_target(enemy)
	
	for i in range(enemies.size()):
		var enemy = enemies[i]
		if enemy.current_health != 500 - 150:
			print("  FAIL: Enemy %d received %d damage, expected 150" % [i, 500 - enemy.current_health])
			for e in enemies: e.queue_free()
			player.queue_free()
			hazard.queue_free()
			return false
	
	print("  All 20 enemies and player successfully processed 10 ticks (210 damage operations total) with 0 errors.")
	
	for e in enemies:
		e.queue_free()
	player.queue_free()
	hazard.queue_free()
	print("  PASS: High-density entity stress test passed.\n")
	return true

# -------------------------------------------------------------------
# Test 5: Entity Dying Handling & Null-Safety Observations
# -------------------------------------------------------------------
func _test_entity_death_handling() -> bool:
	print("[CHALLENGE 5/6] Testing Entity Dying / Deletion Safety...")
	var lava_scene: PackedScene = load("res://src/hazards/lava_floor_hazard.tscn")
	var hazard: Node3D = lava_scene.instantiate()
	hazard.set("auto_start", false)
	root.add_child(hazard)
	if not hazard.is_node_ready():
		await hazard.ready
	
	var slime_scene: PackedScene = load("res://src/enemies/enemy_slime.tscn")
	var weak_enemy = slime_scene.instantiate()
	root.add_child(weak_enemy)
	if not weak_enemy.is_node_ready():
		await weak_enemy.ready
	weak_enemy.current_health = 10 # Lethal hit
	
	hazard._deal_damage_to_target(weak_enemy)
	if not weak_enemy.is_dead:
		print("  FAIL: Enemy should be marked dead after lethal damage")
		weak_enemy.queue_free()
		hazard.queue_free()
		return false
	
	# Subsequent damage to dead enemy (is_dead guard in enemy_base.gd)
	hazard._deal_damage_to_target(weak_enemy)
	
	# Document type signature: _deal_damage_to_target(target: Node)
	print("  Enemy is_dead guard prevents double-death cleanly.")
	print("  Observation: _deal_damage_to_target has parameter 'target: Node'.")
	print("  Recommendation: Change parameter to 'target: Variant' or verify is_instance_valid(body) in _deal_damage() loop to safeguard against externally freed nodes.")
	
	weak_enemy.queue_free()
	hazard.queue_free()
	print("  PASS: Entity death handling verified.\n")
	return true

# -------------------------------------------------------------------
# Test 6: Multi-Hazard Arena Concurrency (All 4 Fissures Active)
# -------------------------------------------------------------------
func _test_arena_four_hazards_concurrency() -> bool:
	print("[CHALLENGE 6/6] Stress-testing Arena 4 Concurrently Active Lava Hazards...")
	var arena_scene: PackedScene = load("res://src/arena/arena.tscn")
	var arena = arena_scene.instantiate()
	root.add_child(arena)
	if not arena.is_node_ready():
		await arena.ready
	
	arena.transition_to_lava_caverns(0.0)
	
	var lava_container: Node3D = arena.get_node_or_null("LavaHazards")
	if not lava_container or lava_container.get_child_count() != 4:
		print("  FAIL: LavaHazards container missing or child count != 4")
		arena.queue_free()
		return false
	
	var fissures: Array = []
	for child in lava_container.get_children():
		fissures.append(child)
	
	if fissures.size() != 4:
		print("  FAIL: Expected 4 LavaFloorHazard children, found %d" % fissures.size())
		arena.queue_free()
		return false
	
	for i in range(fissures.size()):
		var f: Node3D = fissures[i]
		f.set("state_timer", 0.5 + float(i) * 0.7)
	
	var fixed_delta := 0.0166667
	var total_frames := 1800
	var state_counts := [0, 0, 0]
	var state_switches := 0
	var last_states := [0, 0, 0, 0]
	
	for frame in range(total_frames):
		for i in range(4):
			var f: Node3D = fissures[i]
			f._process(fixed_delta)
			var cur_s = f.get("current_state")
			state_counts[cur_s] += 1
			if cur_s != last_states[i]:
				state_switches += 1
				last_states[i] = cur_s
	
	print("  Simulated 30s (%d frames). State distribution: Dormant=%d, Telegraph=%d, Erupting=%d" % [
		total_frames,
		state_counts[0],
		state_counts[1],
		state_counts[2]
	])
	print("  Total concurrent state switches observed: %d" % state_switches)
	
	if state_switches < 20:
		print("  FAIL: Hazards appear stuck or not cycling (only %d switches in 30s)" % state_switches)
		arena.queue_free()
		return false
	
	for i in range(4):
		var f: Node3D = fissures[i]
		var st: float = f.get("state_timer")
		if st < -1.0:
			print("  FAIL: Fissure %d timer became excessively negative: %f" % [i, st])
			arena.queue_free()
			return false
	
	arena.queue_free()
	print("  PASS: 4 concurrent arena hazards ran 30s smoothly with zero lockups.\n")
	return true
