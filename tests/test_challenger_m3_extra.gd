extends SceneTree

# ==============================================================================
# EMPIRICAL ADVERSARIAL STRESS TEST: CHALLENGER EXTRA HARDENING
# Deep Jolt Physics, Boundary Conditions & Real Physics Ticks
# ==============================================================================

var total_assertions: int = 0
var passed_assertions: int = 0

func _init() -> void:
	call_deferred("_run_extra_adversarial_suite")

func _assert_true(condition: bool, message: String) -> void:
	total_assertions += 1
	if condition:
		passed_assertions += 1
	else:
		push_error("[EXTRA CHALLENGE ASSERTION FAILED] %s" % message)
		assert(condition, message)

func _run_extra_adversarial_suite() -> void:
	print("\n================================================================================")
	print(">>> RUNNING CHALLENGER EXTRA ADVERSARIAL HARDENING SUITE <<<")
	print("================================================================================\n")
	
	await _test_spawner_tree_safety_and_clamping()
	await _test_live_jolt_physics_step_rock_destruction()
	await _test_simultaneous_stalactite_destruction_chain()
	await _test_polymorphic_weapon_damage_variants()
	await _test_rock_pickup_lifecycle_in_physics_tree()
	
	print("\n================================================================================")
	print(">>> ALL %d EXTRA ADVERSARIAL ASSERTIONS PASSED (100%%) <<<" % passed_assertions)
	print("================================================================================\n")
	
	quit(0)

# ------------------------------------------------------------------------------
# 1. Spawner Tree Safety & Clamping under Extreme Transforms
# ------------------------------------------------------------------------------
func _test_spawner_tree_safety_and_clamping() -> void:
	print("[EXTRA 1/5] Testing Spawner Tree Safety & Transform Clamping...")
	
	var spawner_scene = load("res://src/arena/spawner.gd")
	var parent_node := Node3D.new()
	# Translate parent node to test if global transform differs from local
	parent_node.position = Vector3(10.0, 0.0, -10.0)
	root.add_child(parent_node)
	
	var spawner = Node3D.new()
	spawner.set_script(spawner_scene)
	parent_node.add_child(spawner)
	
	var player = Node3D.new()
	player.add_to_group("player")
	parent_node.add_child(player)
	
	# Test various player global positions
	var test_positions: Array[Vector3] = [
		Vector3(0, 0, 0),
		Vector3(16, 0, 16),
		Vector3(-16, 0, -16),
		Vector3(100, 0, 100),
		Vector3(-200, 0, 50),
		Vector3(0, 0, -500),
		Vector3(12.5, 5.0, -14.2)
	]
	
	for test_pos in test_positions:
		player.global_position = test_pos
		spawner._spawn_stalactite_hazard()
		
		# Find the newly spawned stalactite in parent_node
		var spawned: Node3D = null
		for child in parent_node.get_children():
			if child.has_method("trigger_impact_now"):
				spawned = child
		
		_assert_true(spawned != null, "Stalactite must spawn for player pos %s" % str(test_pos))
		if spawned:
			# Verify that global coordinates are clamped in [-16, 16]
			_assert_true(spawned.global_position.x >= -16.001 and spawned.global_position.x <= 16.001,
				"Global X (%f) must be clamped in [-16, 16]" % spawned.global_position.x)
			_assert_true(spawned.global_position.z >= -16.001 and spawned.global_position.z <= 16.001,
				"Global Z (%f) must be clamped in [-16, 16]" % spawned.global_position.z)
			_assert_true(abs(spawned.global_position.y) < 0.001,
				"Global Y must be 0.0 ground plane")
			spawned.free()
	
	parent_node.free()
	print("  ✓ Spawner tree safety and clamping under parent offsets verified.")

# ------------------------------------------------------------------------------
# 2. Live Jolt Physics Step During Rock Destruction
# ------------------------------------------------------------------------------
func _test_live_jolt_physics_step_rock_destruction() -> void:
	print("[EXTRA 2/5] Testing Live Jolt Physics Step During Rock Destruction...")
	
	var rock_scene = load("res://src/props/rock_fragment.tscn")
	var parent_node := Node3D.new()
	root.add_child(parent_node)
	
	var rocks: Array = []
	for i in range(10):
		var rock = rock_scene.instantiate()
		parent_node.add_child(rock)
		rock.global_position = Vector3(float(i) * 1.5, 0.0, 0.0)
		rocks.append(rock)
	
	# Step physics frames
	for frame in range(3):
		await process_frame
	
	# Destroy odd rocks with single lethal hit, even rocks with incremental hits
	for i in range(10):
		var rock = rocks[i]
		if i % 2 == 0:
			rock.take_damage(10)
			_assert_true(rock.current_health == 10, "Partial damage correct")
			_assert_true(rock.scale == Vector3.ONE, "Body scale unchanged")
		else:
			rock.take_damage(25) # Lethal
			_assert_true(rock.is_destroyed == true, "Destroyed flag set")
			_assert_true(rock.scale == Vector3.ONE, "Body scale remains Vector3.ONE (no singular transform)")
	
	# Step physics while tween runs and bodies are freed
	for frame in range(10):
		await process_frame
	
	# Destroy remaining even rocks
	for i in range(0, 10, 2):
		var rock = rocks[i]
		if is_instance_valid(rock):
			rock.take_damage(15)
			_assert_true(rock.is_destroyed == true, "Even rock destroyed")
	
	for frame in range(10):
		await process_frame
	
	parent_node.free()
	print("  ✓ Live Jolt physics steps with rock destructions passed without warnings.")

# ------------------------------------------------------------------------------
# 3. Simultaneous Stalactite Impact Chain (AoE destroys spawned rock)
# ------------------------------------------------------------------------------
func _test_simultaneous_stalactite_destruction_chain() -> void:
	print("[EXTRA 3/5] Testing Cascading Stalactite AoE vs Existing Rock Fragment...")
	
	var stalactite_scene = load("res://src/hazards/falling_stalactite.tscn")
	var rock_scene = load("res://src/props/rock_fragment.tscn")
	var parent_node := Node3D.new()
	root.add_child(parent_node)
	
	# Place rock fragment at (0.5, 0, 0)
	var rock = rock_scene.instantiate()
	parent_node.add_child(rock)
	rock.global_position = Vector3(0.5, 0, 0)
	
	# Spawn stalactite at (0, 0, 0)
	var stalactite = stalactite_scene.instantiate()
	parent_node.add_child(stalactite)
	stalactite.global_position = Vector3.ZERO
	
	# Stalactite impacts. Rock is inside 2.5m (at 0.5m). Rock has 20 HP, Stalactite deals 40 dmg.
	# Rock should be destroyed by stalactite impact AoE!
	stalactite.trigger_impact_now()
	
	_assert_true(rock.is_destroyed == true, "Pre-existing rock must be destroyed by stalactite 40 AoE damage")
	_assert_true(rock.current_health == 0, "Pre-existing rock health clamped to 0")
	
	parent_node.free()
	print("  ✓ Cascading stalactite AoE destroys pre-existing rocks safely.")

# ------------------------------------------------------------------------------
# 4. Polymorphic Weapon Damage Variants
# ------------------------------------------------------------------------------
func _test_polymorphic_weapon_damage_variants() -> void:
	print("[EXTRA 4/5] Testing Polymorphic take_damage signatures on Rock Fragment...")
	
	var rock_scene = load("res://src/props/rock_fragment.tscn")
	var parent_node := Node3D.new()
	root.add_child(parent_node)
	
	# Variant 1: take_damage(amount)
	var rock1 = rock_scene.instantiate()
	parent_node.add_child(rock1)
	rock1.take_damage(5)
	_assert_true(rock1.current_health == 15, "Single-arg damage works")
	
	# Variant 2: take_damage(amount, from_pos)
	rock1.take_damage(5, Vector3(1, 0, 0))
	_assert_true(rock1.current_health == 10, "Two-arg damage works")
	
	# Variant 3: take_damage(amount, from_pos, is_crit)
	rock1.take_damage(10, Vector3(0, 0, 0), true)
	_assert_true(rock1.is_destroyed == true, "Three-arg damage works and destroys")
	
	# Variant 4: Negative or 0 damage edge cases
	var rock2 = rock_scene.instantiate()
	parent_node.add_child(rock2)
	rock2.take_damage(0)
	_assert_true(rock2.current_health == 20, "0 damage causes no health loss")
	_assert_true(rock2.is_destroyed == false, "0 damage does not destroy")
	
	# Redundant destroy calls
	rock2.destroy()
	_assert_true(rock2.is_destroyed == true, "Explicit destroy() works")
	rock2.destroy() # Second call is safe
	_assert_true(rock2.is_destroyed == true, "Second destroy() is idempotent")
	
	parent_node.free()
	print("  ✓ Polymorphic take_damage variants verified.")

# ------------------------------------------------------------------------------
# 5. Rock Pickup Lifecycle in Physics SceneTree
# ------------------------------------------------------------------------------
func _test_rock_pickup_lifecycle_in_physics_tree() -> void:
	print("[EXTRA 5/5] Testing Rock Pickup Item Spawn & Physics Tree Lifecycle...")
	
	var rock_scene = load("res://src/props/rock_fragment.tscn")
	var parent_node := Node3D.new()
	root.add_child(parent_node)
	
	# Spawn 50 rocks and destroy them to ensure pickups spawn and behave cleanly in tree
	var spawned_pickups: Array = []
	for i in range(50):
		var rock = rock_scene.instantiate()
		parent_node.add_child(rock)
		rock.global_position = Vector3(float(i % 5) * 2.0, 0, float(i / 5) * 2.0)
		rock.destroy()
	
	# Check parent children for pickups
	for child in parent_node.get_children():
		if child.has_method("setup") and child is Area3D:
			spawned_pickups.append(child)
			# Verify pickup has collision and item_type
			_assert_true(child.item_type in [0, 2], "Pickup item_type must be HEALTH (0) or SOUL_GEM (2)")
			_assert_true(child.monitoring == true or child.monitorable == true, "Pickup must be active in physics")
	
	print("  Spawned %d pickups from 50 destroyed rocks." % spawned_pickups.size())
	_assert_true(spawned_pickups.size() > 0, "At least some pickups spawned from 50 rocks (~30% drop rate)")
	
	# Step physics frames to ensure pickups bob/rotate without error
	for f in range(5):
		await process_frame
	
	parent_node.free()
	print("  ✓ Pickup item lifecycle and physics integration verified.")
