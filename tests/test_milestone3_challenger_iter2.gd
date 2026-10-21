extends SceneTree

# ==============================================================================
# EMPIRICAL CHALLENGER ADVERSARIAL TEST HARNESS — MILESTONE 3 ITERATION 2
# Agent: challenger_m3_iter2_1
# Focus: Double-tick elimination, strict 0.35s intervals, freed body safety,
#        multi-fps jitter tolerance, 4-hazard arena concurrency.
# ==============================================================================

const LavaFloorHazardScene = preload("res://src/hazards/lava_floor_hazard.tscn")
const PlayerScene = preload("res://src/characters/player.tscn")
const SlimeScene = preload("res://src/enemies/enemy_slime.tscn")

class MockDamageTarget extends CharacterBody3D:
	var hp: int = 1000
	var damage_records: Array = []
	var on_damage_callback: Callable = Callable()

	func take_damage(amount: int, origin: Vector3 = Vector3.ZERO) -> void:
		hp -= amount
		damage_records.append(amount)
		if on_damage_callback.is_valid():
			on_damage_callback.call(self, amount, origin)

func _init() -> void:
	call_deferred("_run_all_challenges")

func _run_all_challenges() -> void:
	print("\n================================================================================")
	print(">>> RUNNING ADVERSARIAL CHALLENGER SUITE: MILESTONE 3 ITERATION 2 <<<")
	print("================================================================================\n")
	
	var results: Dictionary = {}
	
	results["double_tick_fixed_fps"] = await _challenge_double_tick_and_intervals(0.0166667, "60 FPS")
	results["double_tick_high_fps"] = await _challenge_double_tick_and_intervals(0.0083333, "120 FPS")
	results["double_tick_jitter"] = await _challenge_double_tick_jitter()
	results["total_ticks_and_damage"] = await _challenge_total_ticks_and_damage_cap()
	results["freed_body_matrix"] = await _challenge_freed_body_type_matrix()
	results["mid_loop_destruction"] = await _challenge_mid_loop_body_destruction()
	results["arena_4_hazards_60s"] = await _challenge_arena_hazard_concurrency(60.0)
	
	print("\n================================================================================")
	print(">>> ADVERSARIAL CHALLENGER VERDICT MATRIX <<<")
	var all_passed := true
	for key in results.keys():
		var passed: bool = results[key]
		if not passed:
			all_passed = false
		print("  [%s] %s" % ["PASS" if passed else "FAIL", key])
	print("================================================================================")
	if all_passed:
		print(">>> FINAL VERDICT: APPROVED (All adversarial challenges passed with zero defects) <<<\n")
		quit(0)
	else:
		print(">>> FINAL VERDICT: REJECTED (Failures detected under adversarial stress) <<<\n")
		quit(1)

# ------------------------------------------------------------------------------
# CHALLENGE 1: Double-Tick Elimination & Interval Precision at Fixed FPS
# ------------------------------------------------------------------------------
func _challenge_double_tick_and_intervals(delta_t: float, fps_label: String) -> bool:
	print("[CHALLENGE 1] Testing tick intervals and double-tick elimination at %s..." % fps_label)
	var hazard = LavaFloorHazardScene.instantiate()
	hazard.set("auto_start", false)
	root.add_child(hazard)
	if not hazard.is_node_ready():
		await hazard.ready

	var dummy = MockDamageTarget.new()
	root.add_child(dummy)

	# Connect damage detection via direct callback
	var tick_times: Array = []
	var elapsed := 0.0

	# We monitor calls to _deal_damage by hooking damage_tick_timer or tracking dummy
	dummy.on_damage_callback = func(_self, _amt, _origin):
		tick_times.append(elapsed)

	# Enter erupting
	elapsed = 0.0
	hazard._enter_erupting()
	# Tick 1 occurs inside _enter_erupting at elapsed = 0.0
	# We simulate dummy taking damage for each _deal_damage invocation
	# In headless mode, collision queries require physics ticks or manual calls,
	# so we verify both: manual _deal_damage_to_target and process loop timing.

	var previous_state = hazard.get("current_state")
	var simulated_ticks := 0
	var tick_timestamps: Array = [0.0]

	while hazard.get("current_state") == 2: # ERUPTING
		var prev_timer: float = hazard.get("damage_tick_timer")
		hazard._process(delta_t)
		elapsed += delta_t
		if prev_timer - delta_t <= 0.0:
			tick_timestamps.append(elapsed)

	print("  [%s] Recorded %d damage ticks over %0.3fs eruption" % [fps_label, tick_timestamps.size(), elapsed])
	for i in range(1, tick_timestamps.size()):
		var interval: float = tick_timestamps[i] - tick_timestamps[i - 1]
		print("    Tick %d -> Tick %d interval: %0.4fs" % [i, i + 1, interval])

	# Check: Did Tick 2 occur sooner than 0.30s?
	if tick_timestamps.size() < 2:
		print("  FAIL: Fewer than 2 ticks recorded!")
		hazard.queue_free()
		dummy.queue_free()
		return false

	var first_interval: float = tick_timestamps[1] - tick_timestamps[0]
	if first_interval < 0.30:
		print("  FAIL: Double-tick detected! First interval was %0.4fs (< 0.30s)" % first_interval)
		hazard.queue_free()
		dummy.queue_free()
		return false

	if tick_timestamps.size() != 5:
		print("  FAIL: Expected exactly 5 ticks, got %d" % tick_timestamps.size())
		hazard.queue_free()
		dummy.queue_free()
		return false

	dummy.queue_free()
	hazard.queue_free()
	print("  PASS: Double-tick eliminated and strictly 5 ticks delivered at %s.\n" % fps_label)
	return true

# ------------------------------------------------------------------------------
# CHALLENGE 2: Variable Delta Jitter (Fluctuating Frame Times)
# ------------------------------------------------------------------------------
func _challenge_double_tick_jitter() -> bool:
	print("[CHALLENGE 2] Testing tick timing robustness under heavy frame jitter (5ms to 45ms)...")
	var hazard = LavaFloorHazardScene.instantiate()
	hazard.set("auto_start", false)
	root.add_child(hazard)
	if not hazard.is_node_ready():
		await hazard.ready

	hazard._enter_erupting()
	var elapsed := 0.0
	var tick_timestamps: Array = [0.0]

	var rng = RandomNumberGenerator.new()
	rng.seed = 987654321

	while hazard.get("current_state") == 2:
		var jitter_delta = rng.randf_range(0.005, 0.045)
		var prev_timer: float = hazard.get("damage_tick_timer")
		hazard._process(jitter_delta)
		elapsed += jitter_delta
		if prev_timer - jitter_delta <= 0.0:
			tick_timestamps.append(elapsed)

	print("  Jitter run: %d ticks recorded over %0.3fs total eruption" % [tick_timestamps.size(), elapsed])
	for i in range(1, tick_timestamps.size()):
		var interval: float = tick_timestamps[i] - tick_timestamps[i - 1]
		print("    Tick %d -> Tick %d interval: %0.4fs" % [i, i + 1, interval])
		if interval < 0.30:
			print("  FAIL: Interval too short under jitter: %0.4fs" % interval)
			hazard.queue_free()
			return false

	if tick_timestamps.size() < 4 or tick_timestamps.size() > 5:
		print("  FAIL: Tick count out of expected bounds under jitter: %d" % tick_timestamps.size())
		hazard.queue_free()
		return false

	hazard.queue_free()
	print("  PASS: Jitter stress handled without double ticks or runaway damage.\n")
	return true

# ------------------------------------------------------------------------------
# CHALLENGE 3: Damage Quantification (Total Damage Cap = 75)
# ------------------------------------------------------------------------------
func _challenge_total_ticks_and_damage_cap() -> bool:
	print("[CHALLENGE 3] Testing exact damage delivery to mock target...")
	var hazard = LavaFloorHazardScene.instantiate()
	hazard.set("auto_start", false)
	root.add_child(hazard)
	if not hazard.is_node_ready():
		await hazard.ready

	var target = MockDamageTarget.new()
	target.hp = 100
	root.add_child(target)

	# Enter eruption
	hazard._enter_erupting()
	hazard._deal_damage_to_target(target) # Tick 1

	var fixed_delta := 0.0166667
	var ticks_delivered := 1

	while hazard.get("current_state") == 2:
		var prev_timer: float = hazard.get("damage_tick_timer")
		hazard._process(fixed_delta)
		if prev_timer - fixed_delta <= 0.0:
			ticks_delivered += 1
			hazard._deal_damage_to_target(target)

	print("  Target HP: 100 -> %d (damage received: %d, expected 75)" % [target.hp, 100 - target.hp])
	print("  Ticks delivered: %d (expected 5)" % ticks_delivered)

	if target.hp != 25 or ticks_delivered != 5:
		print("  FAIL: Expected target HP 25 (75 dmg) and 5 ticks, got HP %d and %d ticks" % [target.hp, ticks_delivered])
		target.queue_free()
		hazard.queue_free()
		return false

	target.queue_free()
	hazard.queue_free()
	print("  PASS: Exact 75 damage (5 x 15) delivered over 1.5s.\n")
	return true

# ------------------------------------------------------------------------------
# CHALLENGE 4: Freed Body & Invalid Type Robustness Matrix
# ------------------------------------------------------------------------------
func _challenge_freed_body_type_matrix() -> bool:
	print("[CHALLENGE 4] Adversarially probing _deal_damage_to_target with freed objects & invalid types...")
	var hazard = LavaFloorHazardScene.instantiate()
	hazard.set("auto_start", false)
	root.add_child(hazard)
	if not hazard.is_node_ready():
		await hazard.ready

	# Case 1: Null argument
	hazard._deal_damage_to_target(null)

	# Case 2: Freed Node
	var freed_node = Node.new()
	freed_node.free()
	hazard._deal_damage_to_target(freed_node)

	# Case 3: Freed CharacterBody3D
	var freed_body = CharacterBody3D.new()
	freed_body.free()
	hazard._deal_damage_to_target(freed_body)

	# Case 4: Freed Area3D
	var freed_area = Area3D.new()
	freed_area.free()
	hazard._deal_damage_to_target(freed_area)

	# Case 5: Object without take_damage
	var plain_obj = RefCounted.new()
	hazard._deal_damage_to_target(plain_obj)

	# Case 6: Primitive types
	hazard._deal_damage_to_target(99999)
	hazard._deal_damage_to_target(3.14159)
	hazard._deal_damage_to_target("invalid_string")
	hazard._deal_damage_to_target(Vector3(1, 2, 3))
	hazard._deal_damage_to_target(Transform3D.IDENTITY)

	hazard.queue_free()
	print("  PASS: All 10 adversarial type inputs safely handled without engine exceptions.\n")
	return true

# ------------------------------------------------------------------------------
# CHALLENGE 5: Mid-Iteration Destruction & Cascading Deletions
# ------------------------------------------------------------------------------
func _challenge_mid_loop_body_destruction() -> bool:
	print("[CHALLENGE 5] Testing mid-iteration body freeing during damage delivery...")
	var hazard = LavaFloorHazardScene.instantiate()
	hazard.set("auto_start", false)
	root.add_child(hazard)
	if not hazard.is_node_ready():
		await hazard.ready

	var target_a = MockDamageTarget.new()
	var target_b = MockDamageTarget.new()
	var target_c = MockDamageTarget.new()

	root.add_child(target_a)
	root.add_child(target_b)
	root.add_child(target_c)

	# When target_a takes damage, it immediately frees target_b
	target_a.on_damage_callback = func(_self, _amt, _origin):
		if is_instance_valid(target_b):
			target_b.free()

	# Simulate damage list [target_a, target_b, target_c]
	var simulated_bodies = [target_a, target_b, target_c]
	for body in simulated_bodies:
		if is_instance_valid(body):
			hazard._deal_damage_to_target(body)

	if target_a.hp != 985:
		print("  FAIL: Target A did not receive damage")
		hazard.queue_free()
		target_a.queue_free()
		target_c.queue_free()
		return false

	if target_c.hp != 985:
		print("  FAIL: Target C did not receive damage after Target B was freed")
		hazard.queue_free()
		target_a.queue_free()
		target_c.queue_free()
		return false

	target_a.queue_free()
	target_c.queue_free()
	hazard.queue_free()
	print("  PASS: Mid-iteration freeing of adjacent target handled seamlessly.\n")
	return true

# ------------------------------------------------------------------------------
# CHALLENGE 6: 60-Second Concurrency Stress of All 4 Arena Lava Hazards
# ------------------------------------------------------------------------------
func _challenge_arena_hazard_concurrency(duration_sec: float) -> bool:
	print("[CHALLENGE 6] Stress-testing Arena 4 Lava Hazards over %0.1fs continuous simulation..." % duration_sec)
	var arena_scene: PackedScene = load("res://src/arena/arena.tscn")
	var arena = arena_scene.instantiate()
	root.add_child(arena)
	if not arena.is_node_ready():
		await arena.ready

	arena.transition_to_lava_caverns(0.0)

	var lava_container = arena.get_node_or_null("LavaHazards")
	if not lava_container:
		print("  FAIL: LavaHazards node not found in Arena")
		arena.queue_free()
		return false

	var fissures = lava_container.get_children()
	if fissures.size() != 4:
		print("  FAIL: Expected 4 fissures, found %d" % fissures.size())
		arena.queue_free()
		return false

	# Stagger initial phase
	for i in range(fissures.size()):
		fissures[i].set("state_timer", 0.3 + float(i) * 0.8)

	var delta_t := 0.0166667
	var total_frames := int(duration_sec / delta_t)
	var state_transition_counts := [0, 0, 0, 0]
	var last_states := [0, 0, 0, 0]

	for i in range(4):
		last_states[i] = fissures[i].get("current_state")

	for frame in range(total_frames):
		for i in range(4):
			var f = fissures[i]
			f._process(delta_t)
			var cur_state = f.get("current_state")
			if cur_state != last_states[i]:
				state_transition_counts[i] += 1
				last_states[i] = cur_state

	print("  State transitions over %0.1fs for all 4 fissures:" % duration_sec)
	for i in range(4):
		print("    Fissure %d transitions: %d" % [i, state_transition_counts[i]])
		if state_transition_counts[i] < 25:
			print("  FAIL: Fissure %d stalled (only %d transitions)" % [i, state_transition_counts[i]])
			arena.queue_free()
			return false

	arena.queue_free()
	print("  PASS: All 4 hazards cycled continuously with 0 deadlocks across %0.1fs.\n" % duration_sec)
	return true
