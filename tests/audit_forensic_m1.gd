extends SceneTree

# Independent Forensic Auditor Verification Script for Milestone 1
# Tests all requirements, mathematical contracts, failure modes, and edge cases.

func _init() -> void:
	call_deferred("_run_audit")

func _run_audit() -> void:
	print("\n=======================================================")
	print("--- AUDITOR FORENSIC INTEGRITY SUITE: MILESTONE 1 ---")
	print("=======================================================\n")

	var test_save_path := "user://forensic_audit_save.json"
	var save_mgr_script := load("res://src/meta/save_manager.gd")
	assert(save_mgr_script != null, "FATAL: SaveManager script failed to load")

	# -----------------------------------------------------------------
	# CHECK 1: SaveManager Genuine JSON Serialization & Schema Integrity
	# -----------------------------------------------------------------
	print("[CHECK 1] Verifying genuine JSON serialization and file creation on disk...")
	var sm = save_mgr_script.new(test_save_path)
	root.add_child(sm)
	if not sm.is_node_ready():
		await sm.ready

	sm.reset_save()
	assert(FileAccess.file_exists(test_save_path), "FAIL: Save file must exist on disk")

	# Read raw file content directly from disk
	var raw_file := FileAccess.open(test_save_path, FileAccess.READ)
	assert(raw_file != null, "FAIL: Could not open save file on disk")
	var raw_text := raw_file.get_as_text()
	raw_file.close()

	var json := JSON.new()
	var parse_status := json.parse(raw_text)
	assert(parse_status == OK, "FAIL: Raw save file must be valid JSON")
	var parsed_dict: Dictionary = json.data
	assert(parsed_dict.has("version") and parsed_dict["version"] == 1, "FAIL: Schema version mismatch")
	assert(parsed_dict.has("soul_gems") and parsed_dict["soul_gems"] == 0, "FAIL: soul_gems mismatch")
	assert(parsed_dict.has("lifetime_kills") and parsed_dict["lifetime_kills"] == 0, "FAIL: lifetime_kills mismatch")
	assert(parsed_dict.has("high_score_wave") and parsed_dict["high_score_wave"] == 0, "FAIL: high_score_wave mismatch")
	assert(parsed_dict.has("runs_played") and parsed_dict["runs_played"] == 0, "FAIL: runs_played mismatch")
	assert(parsed_dict.has("talents") and parsed_dict["talents"] is Dictionary, "FAIL: talents dict missing")
	print("  -> Raw JSON file genuinely verified on disk.")

	# -----------------------------------------------------------------
	# CHECK 2: Mathematical Precision of Interface Contracts
	# -----------------------------------------------------------------
	print("[CHECK 2] Verifying mathematical precision of talent contracts...")
	# Contract 1: max_health = level * 20.0
	# Contract 2: base_damage = level * 5.0
	# Contract 3: move_speed = level * 0.4
	# Contract 4: dash_cooldown = level * 0.08
	var expected_bonuses := {
		"max_health": [0.0, 20.0, 40.0, 60.0, 80.0, 100.0],
		"base_damage": [0.0, 5.0, 10.0, 15.0, 20.0, 25.0],
		"move_speed": [0.0, 0.4, 0.8, 1.2, 1.6, 2.0],
		"dash_cooldown": [0.0, 0.08, 0.16, 0.24, 0.32, 0.40]
	}

	for tid in expected_bonuses.keys():
		sm.reset_save()
		sm.add_soul_gems(1000)
		for lvl in range(6):
			var current_lvl: int = sm.get_talent_level(tid)
			assert(current_lvl == lvl, "FAIL: Level mismatch for %s: got %d, expected %d" % [tid, current_lvl, lvl])
			var actual_bonus: float = sm.get_talent_bonus(tid)
			var expected_bonus: float = expected_bonuses[tid][lvl]
			assert(abs(actual_bonus - expected_bonus) < 0.001, "FAIL: Formula mismatch for %s at lvl %d: got %f, expected %f" % [tid, lvl, actual_bonus, expected_bonus])
			if lvl < 5:
				var cost: int = sm.get_talent_cost(tid)
				assert(cost > 0, "FAIL: Cost should be positive at lvl %d" % lvl)
				var bought: bool = sm.purchase_talent(tid)
				assert(bought == true, "FAIL: Purchase should succeed at lvl %d" % lvl)
			else:
				var max_cost: int = sm.get_talent_cost(tid)
				assert(max_cost == -1, "FAIL: Max level cost must be -1")
				var over_buy: bool = sm.purchase_talent(tid)
				assert(over_buy == false, "FAIL: Over-purchasing must return false")
				assert(sm.get_talent_level(tid) == 5, "FAIL: Level must remain capped at 5")

	# Unknown talent handling
	assert(sm.get_talent_bonus("unknown_talent") == 0.0, "FAIL: Unknown talent bonus must be 0.0")
	assert(sm.get_talent_cost("unknown_talent") == -1, "FAIL: Unknown talent cost must be -1")
	assert(sm.purchase_talent("unknown_talent") == false, "FAIL: Purchasing unknown talent must return false")
	print("  -> Mathematical formulas and boundary caps strictly confirmed.")

	# -----------------------------------------------------------------
	# CHECK 3: Currency Operations, Overdraw Protection & Idempotence
	# -----------------------------------------------------------------
	print("[CHECK 3] Verifying currency operations and overdraw protection...")
	sm.reset_save()
	assert(sm.get_soul_gems() == 0, "FAIL: Gems should be 0")
	
	# Negative gem addition rejection
	sm.add_soul_gems(-50)
	assert(sm.get_soul_gems() == 0, "FAIL: Negative soul gems should not deduct")

	# Insufficient gems purchase failure
	var cost_hp: int = sm.get_talent_cost("max_health")
	assert(cost_hp == 10, "FAIL: Base cost should be 10")
	var buy_result: bool = sm.purchase_talent("max_health")
	assert(buy_result == false, "FAIL: Purchasing with 0 gems must return false")
	assert(sm.get_soul_gems() == 0, "FAIL: Gems must remain 0 after failed purchase")
	assert(sm.get_talent_level("max_health") == 0, "FAIL: Level must remain 0")

	# Exact currency purchase
	sm.add_soul_gems(10)
	assert(sm.get_soul_gems() == 10, "FAIL: Gems should be 10")
	buy_result = sm.purchase_talent("max_health")
	assert(buy_result == true, "FAIL: Purchasing with exact cost must return true")
	assert(sm.get_soul_gems() == 0, "FAIL: Gems should be exactly 0 after exact purchase")
	assert(sm.get_talent_level("max_health") == 1, "FAIL: Level should be 1")
	print("  -> Currency transactions and overdraw protection confirmed.")

	# -----------------------------------------------------------------
	# CHECK 4: Corruption Recovery & Schema Quarantine
	# -----------------------------------------------------------------
	print("[CHECK 4] Verifying corruption recovery and quarantine...")
	var corrupt_path := "user://forensic_corrupt_test.json"
	
	# Test 4A: Syntactically invalid JSON
	var cf := FileAccess.open(corrupt_path, FileAccess.WRITE)
	cf.store_string("{ this is total garbage ::: syntax error !!! }")
	cf.close()
	
	var c_sm = save_mgr_script.new(corrupt_path)
	root.add_child(c_sm)
	if not c_sm.is_node_ready():
		await c_sm.ready
	assert(c_sm.get_soul_gems() == 0, "FAIL: Corrupt file must recover with 0 gems")
	assert(c_sm.get_talent_level("max_health") == 0, "FAIL: Corrupt file must recover with 0 talents")
	
	# Verify backup file was created
	assert(FileAccess.file_exists(save_mgr_script.BACKUP_PATH), "FAIL: Corrupt file must be backed up")
	var bak_f := FileAccess.open(save_mgr_script.BACKUP_PATH, FileAccess.READ)
	var bak_content := bak_f.get_as_text()
	bak_f.close()
	assert(bak_content.contains("syntax error"), "FAIL: Backup file content must match corrupted data")
	c_sm.queue_free()

	# Test 4B: Out-of-bounds values in JSON (e.g. negative gems, level > 5)
	var malformed_f := FileAccess.open(corrupt_path, FileAccess.WRITE)
	malformed_f.store_string('{"version": 1, "soul_gems": -999, "lifetime_kills": -50, "high_score_wave": -2, "runs_played": -1, "talents": {"max_health": 999, "base_damage": -5}}')
	malformed_f.close()

	var m_sm = save_mgr_script.new(corrupt_path)
	root.add_child(m_sm)
	if not m_sm.is_node_ready():
		await m_sm.ready
	assert(m_sm.get_soul_gems() == 0, "FAIL: Negative gems in JSON must clamp to 0")
	assert(m_sm.get_lifetime_kills() == 0, "FAIL: Negative kills in JSON must clamp to 0")
	assert(m_sm.get_high_score_wave() == 0, "FAIL: Negative wave in JSON must clamp to 0")
	assert(m_sm.get_runs_played() == 0, "FAIL: Negative runs in JSON must clamp to 0")
	assert(m_sm.get_talent_level("max_health") == 5, "FAIL: Out-of-bounds talent level 999 must clamp to max 5")
	assert(m_sm.get_talent_level("base_damage") == 0, "FAIL: Negative talent level must clamp to 0")
	m_sm.queue_free()

	# Clean up corrupt test files
	var da := DirAccess.open("user://")
	if da:
		da.remove("forensic_corrupt_test.json")
		da.remove("forensic_corrupt_test.json.tmp")
	print("  -> Corruption recovery, quarantine, and data sanitization confirmed.")

	# -----------------------------------------------------------------
	# CHECK 5: Player Dynamic Meta-Talent Scaling & Idempotence
	# -----------------------------------------------------------------
	print("[CHECK 5] Verifying Player meta-talent dynamic scaling and idempotence...")
	var player_scene := load("res://src/characters/player.tscn")
	assert(player_scene != null, "FAIL: Player scene failed to load")

	# Register our sm at /root/SaveManager for Player query
	if root.has_node("SaveManager"):
		var old = root.get_node("SaveManager")
		root.remove_child(old)
		old.queue_free()

	sm.name = "SaveManager"
	sm.reset_save()

	# Test 5A: Baseline preservation at Level 0
	var player_inst = player_scene.instantiate()
	root.add_child(player_inst)
	if not player_inst.is_node_ready():
		await player_inst.ready

	assert(player_inst.max_health == 100, "FAIL: Baseline max_health must be 100")
	assert(player_inst.current_health == 100, "FAIL: Baseline current_health must be 100")
	assert(player_inst.attack_damage == 30, "FAIL: Baseline attack_damage must be 30")
	assert(abs(player_inst.move_speed - 7.5) < 0.001, "FAIL: Baseline move_speed must be 7.5")
	assert(abs(player_inst.dash_cooldown - 0.8) < 0.001, "FAIL: Baseline dash_cooldown must be 0.8")
	player_inst.queue_free()

	# Test 5B: Max level talent application (Level 5 all)
	sm.add_soul_gems(5000)
	for i in range(5):
		sm.purchase_talent("max_health")
		sm.purchase_talent("base_damage")
		sm.purchase_talent("move_speed")
		sm.purchase_talent("dash_cooldown")

	var player_buffed = player_scene.instantiate()
	root.add_child(player_buffed)
	if not player_buffed.is_node_ready():
		await player_buffed.ready

	# Expected:
	# max_health: 100 + (5 * 20) = 200
	# attack_damage: 30 + (5 * 5) = 55
	# move_speed: 7.5 + (5 * 0.4) = 9.5
	# dash_cooldown: 0.8 - (5 * 0.08) = 0.40
	assert(player_buffed.max_health == 200, "FAIL: Buffed max_health should be 200, got %d" % player_buffed.max_health)
	assert(player_buffed.current_health == 200, "FAIL: Buffed current_health should be 200, got %d" % player_buffed.current_health)
	assert(player_buffed.attack_damage == 55, "FAIL: Buffed attack_damage should be 55, got %d" % player_buffed.attack_damage)
	assert(abs(player_buffed.move_speed - 9.5) < 0.001, "FAIL: Buffed move_speed should be 9.5, got %f" % player_buffed.move_speed)
	assert(abs(player_buffed.dash_cooldown - 0.40) < 0.001, "FAIL: Buffed dash_cooldown should be 0.40, got %f" % player_buffed.dash_cooldown)

	# Test 5C: Idempotence test (calling apply_meta_talents multiple times must not stack)
	player_buffed.apply_meta_talents()
	player_buffed.apply_meta_talents()
	assert(player_buffed.max_health == 200, "FAIL: Multiple calls to apply_meta_talents must remain idempotent (expected 200, got %d)" % player_buffed.max_health)
	assert(player_buffed.attack_damage == 55, "FAIL: Multiple calls to apply_meta_talents must remain idempotent (expected 55, got %d)" % player_buffed.attack_damage)
	assert(abs(player_buffed.move_speed - 9.5) < 0.001, "FAIL: Multiple calls to apply_meta_talents must remain idempotent (expected 9.5, got %f)" % player_buffed.move_speed)
	player_buffed.queue_free()
	print("  -> Player meta-talent dynamic scaling and idempotence confirmed.")

	# -----------------------------------------------------------------
	# CHECK 6: SanctuaryArmory Interactive Purchasing & State Sync
	# -----------------------------------------------------------------
	print("[CHECK 6] Verifying SanctuaryArmory interactive UI and purchase cycle...")
	var armory_scene := load("res://src/ui/sanctuary_armory.tscn")
	assert(armory_scene != null, "FAIL: SanctuaryArmory scene failed to load")
	var armory = armory_scene.instantiate()
	root.add_child(armory)
	if not armory.is_node_ready():
		await armory.ready

	sm.reset_save()
	armory.open()
	assert(armory.visible == true, "FAIL: Armory should be visible after open()")

	var gem_lbl = armory.find_child("GemCountLabel", true, false) as Label
	assert(gem_lbl != null, "FAIL: GemCountLabel missing")
	assert(gem_lbl.text == "0", "FAIL: Gem count display should be '0'")

	# Inspect Card_max_health
	var card_hp = armory.find_child("Card_max_health", true, false)
	assert(card_hp != null, "FAIL: Card_max_health missing")
	var buy_btn = card_hp.find_child("BuyButton", true, false) as Button
	assert(buy_btn != null, "FAIL: BuyButton missing on Card_max_health")
	assert(buy_btn.disabled == true, "FAIL: Buy button must be disabled with 0 gems")

	# Add 10 gems and refresh
	sm.add_soul_gems(10)
	armory.refresh_ui()
	assert(gem_lbl.text == "10", "FAIL: Gem count display should be '10'")
	assert(buy_btn.disabled == false, "FAIL: Buy button should be enabled with 10 gems")

	# Perform buy via armory
	armory._on_buy_pressed("max_health")
	assert(sm.get_talent_level("max_health") == 1, "FAIL: Talent level should be 1 after purchase")
	assert(sm.get_soul_gems() == 0, "FAIL: Gems should be 0 after purchase")
	assert(gem_lbl.text == "0", "FAIL: Gem count label should update to '0'")
	assert(buy_btn.disabled == true, "FAIL: Buy button should be re-disabled with 0 gems")

	armory.close()
	assert(armory.visible == false, "FAIL: Armory should be hidden after close()")
	armory.queue_free()
	print("  -> SanctuaryArmory interactive purchasing and state sync confirmed.")

	# -----------------------------------------------------------------
	# CHECK 7: PickupItem Drops, Soul Gems, and Elite Setup
	# -----------------------------------------------------------------
	print("[CHECK 7] Verifying PickupItem SOUL_GEM integration and player collection...")
	var pickup_scene := load("res://src/props/pickup_item.tscn")
	assert(pickup_scene != null, "FAIL: PickupItem scene failed to load")

	sm.reset_save()
	var test_player_for_pickup = player_scene.instantiate()
	root.add_child(test_player_for_pickup)
	test_player_for_pickup.add_to_group("player")
	if not test_player_for_pickup.is_node_ready():
		await test_player_for_pickup.ready

	# Standard Soul Gem (Type 2, value 1)
	var gem1 = pickup_scene.instantiate()
	root.add_child(gem1)
	gem1.setup(gem1.Type.SOUL_GEM, Vector3.ZERO)
	gem1._on_body_entered(test_player_for_pickup)
	assert(sm.get_soul_gems() == 1, "FAIL: Standard soul gem must grant 1 soul gem (got %d)" % sm.get_soul_gems())
	if is_instance_valid(gem1):
		gem1.queue_free()

	# Elite Soul Gem (Type 2, setup_elite -> value 5)
	var gem_elite = pickup_scene.instantiate()
	root.add_child(gem_elite)
	gem_elite.setup_elite(gem_elite.Type.SOUL_GEM, Vector3.ZERO)
	assert(gem_elite.value == 5, "FAIL: Elite soul gem value must be 5")
	gem_elite._on_body_entered(test_player_for_pickup)
	assert(sm.get_soul_gems() == 6, "FAIL: Elite soul gem must grant 5 soul gems (total 6, got %d)" % sm.get_soul_gems())
	if is_instance_valid(gem_elite):
		gem_elite.queue_free()

	# Elite Health Potion (Type 0, setup_elite -> heal 40)
	var pot_elite = pickup_scene.instantiate()
	root.add_child(pot_elite)
	pot_elite.setup_elite(pot_elite.Type.HEALTH, Vector3.ZERO)
	assert(pot_elite.heal_amount == 40, "FAIL: Elite health potion heal_amount must be 40")
	test_player_for_pickup.current_health = 10
	pot_elite._on_body_entered(test_player_for_pickup)
	assert(test_player_for_pickup.current_health == 50, "FAIL: Elite health potion must heal 40 HP (got %d)" % test_player_for_pickup.current_health)
	if is_instance_valid(pot_elite):
		pot_elite.queue_free()

	test_player_for_pickup.queue_free()
	print("  -> PickupItem drops, Soul Gems, and Elite setups confirmed.")

	# -----------------------------------------------------------------
	# CHECK 8: Run End Persistence & High Score Logic
	# -----------------------------------------------------------------
	print("[CHECK 8] Verifying run end recording and high score tracking...")
	sm.reset_save()
	sm.record_run_end(3, 15)
	assert(sm.get_high_score_wave() == 3, "FAIL: High score wave should be 3")
	assert(sm.get_lifetime_kills() == 15, "FAIL: Lifetime kills should be 15")
	assert(sm.get_runs_played() == 1, "FAIL: Runs played should be 1")

	sm.record_run_end(7, 30)
	assert(sm.get_high_score_wave() == 7, "FAIL: High score wave should update to 7")
	assert(sm.get_lifetime_kills() == 45, "FAIL: Lifetime kills should accumulate to 45")
	assert(sm.get_runs_played() == 2, "FAIL: Runs played should update to 2")

	# Lower wave should not overwrite high score wave
	sm.record_run_end(4, 10)
	assert(sm.get_high_score_wave() == 7, "FAIL: High score wave should retain max (7)")
	assert(sm.get_lifetime_kills() == 55, "FAIL: Lifetime kills should accumulate to 55")
	assert(sm.get_runs_played() == 3, "FAIL: Runs played should update to 3")
	print("  -> Run end recording and high score logic confirmed.")

	# Clean up test save files
	if da:
		da.remove("forensic_audit_save.json")
		da.remove("forensic_audit_save.json.tmp")
	sm.queue_free()

	print("\n=======================================================")
	print(">>> ALL 8 FORENSIC INTEGRITY CHECKS PASSED 100%! <<<")
	print("=======================================================\n")
	quit(0)
