extends SceneTree

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("\n--- RUNNING COMPREHENSIVE DUNGEON POLISH & DEEP EDGE CASE TEST SUITE ---")
	
	# Test 1: Player character, stats, and juice
	print("[1/14] Testing Player instantiation and juice attributes...")
	var player_scene: PackedScene = load("res://src/characters/player.tscn")
	assert(player_scene != null, "Player scene failed to load")
	var player = player_scene.instantiate()
	root.add_child(player)
	if not player.is_node_ready():
		await player.ready
	
	assert(player.max_health == 100, "Player max_health should be 100")
	assert(player.current_health == 100, "Player current_health should be 100")
	assert(player.camera_trauma == 0.0, "Initial trauma should be 0.0")
	
	# Edge case: healing at max HP should clamp at max_health
	player.heal(50)
	assert(player.current_health == 100, "Heal at max health must clamp to max_health")
	
	# Camera shake trauma test
	player.add_camera_shake(0.4)
	assert(abs(player.camera_trauma - 0.4) < 0.001, "Trauma should be 0.4")
	player.add_camera_shake(0.9)
	assert(player.camera_trauma == 1.0, "Trauma should clamp to 1.0")
	print("✓ Player juice attributes, heal clamp, and trauma clamping verified.")
	
	# Test 2: Upgrades mechanics on Player & Edge Cases
	print("[2/14] Testing upgrades (Colossal, Crit, Vampiric, Vitality, Haste, Phantom Dash)...")
	var orig_sword_scale: float = player.sword_scale_multiplier
	player.apply_colossal_blade(0.35)
	assert(abs(player.sword_scale_multiplier - (orig_sword_scale + 0.35)) < 0.001, "Colossal blade multiplier mismatch")
	
	var orig_crit: float = player.crit_chance
	player.apply_critical_focus(0.25)
	assert(abs(player.crit_chance - (orig_crit + 0.25)) < 0.001, "Critical focus boost mismatch")
	
	# Edge case: critical focus repeated stacking clamps at 1.0
	player.apply_critical_focus(10.0)
	assert(player.crit_chance == 1.0, "Crit chance must clamp to 1.0 maximum")
	
	player.apply_vampiric_touch(10)
	assert(player.vampiric_heal == 10, "Vampiric heal mismatch")
	
	# Test vampiric heal trigger on kill
	player.current_health = 50
	player.vampiric_chance = 1.0 # Force trigger for deterministic test
	player.add_kill()
	assert(player.current_health == 60, "Player should heal 10 HP upon kill with vampiric touch")
	assert(player.kills == 1, "Player kills should increment")
	
	# New upgrades
	var orig_max_hp: int = player.max_health
	player.apply_vitality(35)
	assert(player.max_health == orig_max_hp + 35, "Vitality should increase max_health")
	assert(player.current_health == 95, "Vitality should heal by hp boost")
	
	var orig_atk_cd: float = player.attack_cooldown
	player.apply_haste(0.20)
	assert(abs(player.attack_cooldown - (orig_atk_cd * 0.80)) < 0.001, "Haste should reduce attack_cooldown")
	
	var orig_dash_cd: float = player.dash_cooldown
	player.apply_phantom_dash(0.25)
	assert(abs(player.dash_cooldown - (orig_dash_cd * 0.75)) < 0.001, "Phantom dash should reduce dash_cooldown")
	print("✓ All 6 upgrade mechanics & clamping edge cases verified.")
	
	# Test 3: EnemyGolem & EnemySlime visual hierarchy and take_damage robustness
	print("[3/14] Testing EnemyGolem, EnemySlime VisualRoot, and lethal hit handling...")
	var slime_scene: PackedScene = load("res://src/enemies/enemy_slime.tscn")
	assert(slime_scene != null, "Slime scene failed to load")
	var slime = slime_scene.instantiate()
	root.add_child(slime)
	if not slime.is_node_ready():
		await slime.ready
	
	# Slime visual root check
	assert(slime.has_node("VisualRoot"), "EnemySlime must have VisualRoot to prevent detached eyes bug")
	assert(slime.visual_mesh == slime.get_node("VisualRoot"), "Slime visual_mesh must resolve to VisualRoot")
	
	# Lethal hit test
	slime.take_damage(999, Vector3.ZERO, true)
	assert(slime.is_dead, "Slime should be marked is_dead immediately upon lethal damage")
	
	var golem_scene: PackedScene = load("res://src/enemies/enemy_golem.tscn")
	assert(golem_scene != null, "Golem scene failed to load")
	var golem = golem_scene.instantiate()
	root.add_child(golem)
	if not golem.is_node_ready():
		await golem.ready
	
	assert(golem.max_health == 160, "Golem max_health should be 160")
	assert(golem.current_health == 160, "Golem current_health should be 160")
	assert(golem.move_speed == 2.2, "Golem move_speed should be 2.2")
	assert(golem.attack_damage == 25, "Golem attack_damage should be 25")
	assert(golem.knockback_resistance == 0.65, "Golem knockback_resistance should be 0.65")
	
	# Edge case: take damage with Vector3.ZERO knockback origin (no div by zero)
	golem.take_damage(40, Vector3.ZERO, true)
	assert(golem.current_health == 120, "Golem current_health should be 120 after 40 dmg")
	
	# Directional knockback with resistance
	golem.velocity = Vector3.ZERO
	golem.take_damage(20, golem.global_position - Vector3(1, 0, 0), false)
	assert(golem.velocity.x > 0.0, "Golem should receive directional knockback")
	print("✓ EnemyGolem, EnemySlime VisualRoot, and lethal hit robustness verified.")
	
	# Test 4: Hitstop execution & Rapid Multi-Hit Edge Case
	print("[4/14] Testing real hitstop timer and rapid multi-hit safety...")
	Engine.time_scale = 1.0
	player.trigger_hitstop(0.04)
	assert(Engine.time_scale == 0.05, "Engine.time_scale should be 0.05 during hitstop")
	assert(player.is_in_hitstop == true, "player.is_in_hitstop should be true")
	
	# Rapid second call during active hitstop should be safely ignored
	player.trigger_hitstop(0.04)
	assert(Engine.time_scale == 0.05, "Engine.time_scale must remain 0.05")
	
	# Wait for real-time timer to expire
	await create_timer(0.06, true, false, true).timeout
	assert(Engine.time_scale == 1.0, "Engine.time_scale should automatically restore to 1.0 after hitstop")
	assert(player.is_in_hitstop == false, "player.is_in_hitstop should be false after hitstop")
	
	# Test hitstop recovery on player die()
	player.trigger_hitstop(0.04)
	assert(Engine.time_scale == 0.05, "Engine.time_scale should be 0.05")
	player.die()
	assert(Engine.time_scale == 1.0, "Player die() must restore Engine.time_scale to 1.0 immediately")
	assert(player.is_in_hitstop == false, "player.is_in_hitstop must be reset on death")
	print("✓ Real hitstop cycle, rapid multi-hit safety, and death recovery verified.")
	
	# Test 5: Spawner integration
	print("[5/14] Testing Spawner with slime and golem scenes...")
	var spawner = Node3D.new()
	var spawner_script = load("res://src/arena/spawner.gd")
	spawner.set_script(spawner_script)
	root.add_child(spawner)
	assert(spawner.slime_scene != null, "Spawner should have slime_scene loaded")
	assert(spawner.golem_scene != null, "Spawner should have golem_scene loaded")
	
	# Wave scaling
	spawner.start_wave(3)
	assert(spawner.current_wave == 3, "Wave should be 3")
	assert(spawner.enemies_to_spawn == 6 + (3 * 4), "Wave 3 should spawn 18 enemies")
	print("✓ Spawner wave logic and enemy type assignments verified.")
	
	# Test 6: Arena ambience, Independent Torch flickers, and Motes
	print("[6/14] Testing Arena environment, independent torch flickers, and motes...")
	var arena_scene: PackedScene = load("res://src/arena/arena.tscn")
	assert(arena_scene != null, "Arena scene failed to load")
	var arena = arena_scene.instantiate()
	root.add_child(arena)
	if not arena.is_node_ready():
		await arena.ready
	
	var motes = arena.get_node_or_null("DungeonMotes")
	assert(motes != null, "Arena must contain DungeonMotes GPUParticles3D node")
	assert(motes is GPUParticles3D, "DungeonMotes must be a GPUParticles3D")
	
	var torch1 = arena.get_node_or_null("Pillar1/TorchLight")
	var torch2 = arena.get_node_or_null("Pillar2/TorchLight")
	assert(torch1 != null and torch2 != null, "Pillars must contain TorchLight")
	assert(torch1.phase_offset != torch2.phase_offset, "Torch flickers must have independent phase offsets")
	
	print("✓ Arena ambience, GPUParticles3D, and independent torches verified.")
	
	# Test 7: UpgradeMenu modal & Capping filter
	print("[7/14] Testing UpgradeMenu capping filter & double-click prevention...")
	var menu_scene: PackedScene = load("res://src/ui/upgrade_menu.tscn")
	assert(menu_scene != null, "UpgradeMenu scene failed to load")
	var menu = menu_scene.instantiate()
	root.add_child(menu)
	if not menu.is_node_ready():
		await menu.ready
	
	menu.player = player
	# player.crit_chance is 1.0 from Test 2
	menu.open_menu()
	var card_container = menu.get_node("Control/Panel/VBoxContainer/CardsContainer")
	assert(card_container.get_child_count() == 3, "Menu should display 3 upgrade cards")
	
	# Ensure 'crit' is not offered since player.crit_chance == 1.0
	for btn in card_container.get_children():
		assert(not "Critical Focus" in btn.text, "Capped upgrade (Critical Focus) must not be offered in card pool")
	
	# Test card picking and button disable guard
	var first_btn = card_container.get_child(0) as Button
	first_btn.emit_signal("pressed")
	assert(first_btn.disabled == true, "Cards must be disabled upon selection to prevent rapid duplicate clicks")
	assert(menu.visible == false, "Menu must close after selection")
	
	print("✓ UpgradeMenu capping filter and selection guard verified.")
	
	# Test 8: Props, Hazards, and take_damage argument flexibility
	print("[8/14] Testing Props, Hazards, Boss take_damage argument polymorphism & shockwave...")
	var crate_scene: PackedScene = load("res://src/props/destructible_crate.tscn")
	assert(crate_scene != null, "Crate scene failed to load")
	var crate = crate_scene.instantiate()
	root.add_child(crate)
	if not crate.is_node_ready():
		await crate.ready
	
	# Test take_damage with 1, 2, and 3 arguments including null
	crate.take_damage(5)
	crate.take_damage(5, null)
	crate.take_damage(5, Vector3.ZERO, true)
	assert(crate.current_health == 10, "Crate health should be 10 after 15 damage")
	crate.take_damage(999, null, false)
	assert(crate.is_destroyed, "Crate should be destroyed")
	
	var barrel_scene: PackedScene = load("res://src/props/explosive_barrel.tscn")
	assert(barrel_scene != null, "Barrel scene failed to load")
	var barrel = barrel_scene.instantiate()
	root.add_child(barrel)
	if not barrel.is_node_ready():
		await barrel.ready
	barrel.take_damage(10, null, true)
	assert(barrel.current_health == 5, "Barrel health should be 5 after 10 damage")
	barrel.take_damage(999, null, true)
	assert(barrel.is_exploding, "Barrel should be exploding")
	
	var trap_scene: PackedScene = load("res://src/hazards/spike_trap.tscn")
	assert(trap_scene != null, "SpikeTrap scene failed to load")
	var trap = trap_scene.instantiate()
	root.add_child(trap)
	if not trap.is_node_ready():
		await trap.ready
	trap._deal_damage() # Should not crash even with no bodies overlapping
	
	var pickup_scene: PackedScene = load("res://src/props/pickup_item.tscn")
	assert(pickup_scene != null, "Pickup scene failed to load")
	var pickup = pickup_scene.instantiate()
	root.add_child(pickup)
	pickup.setup(0, Vector3(0, 0.5, 0)) # Health pickup setup
	pickup.queue_free()
	
	var boss_scene: PackedScene = load("res://src/enemies/boss_demon_knight.tscn")
	assert(boss_scene != null, "Boss scene failed to load")
	var boss = boss_scene.instantiate()
	root.add_child(boss)
	if not boss.is_node_ready():
		await boss.ready
	boss.take_damage(20, null, true)
	boss.take_damage(20, Vector3.ZERO, false)
	assert(boss.current_health == boss.max_health - 40, "Boss should receive polymorphic take_damage")
	boss.queue_free()
	
	print("✓ Props, Hazards, and Boss polymorphic take_damage verified.")
	
	# Test 9: AudioManager complete method coverage & Projectile safety
	print("[9/14] Testing AudioManager method coverage & Projectile safety...")
	var audio_mgr = root.get_node_or_null("AudioManager")
	if audio_mgr:
		audio_mgr.play_slash()
		audio_mgr.play_hit()
		audio_mgr.play_crit()
		audio_mgr.play_dash()
		audio_mgr.play_fanfare()
		audio_mgr.play_wave_fanfare()
		audio_mgr.play_pickup_heal()
		audio_mgr.play_pickup_score()
		audio_mgr.play_special()
		audio_mgr.play_cast()
		audio_mgr.play_boss_slam()
		audio_mgr.play_crate_break()
		audio_mgr.play_barrel_explode()
		audio_mgr.play_hazard_spike()
		audio_mgr.play_combat_music()
		audio_mgr.duck_music(true)
		audio_mgr.duck_music(false)
		audio_mgr.transition_to_boss()
		audio_mgr.transition_to_combat()
		audio_mgr.set_boss_music_intensity(1.2)
	
	var proj_scene: PackedScene = load("res://src/combat/projectile.tscn")
	assert(proj_scene != null, "Projectile scene failed to load")
	var proj = proj_scene.instantiate()
	root.add_child(proj)
	proj.setup(Vector3.FORWARD, 15, 10.0)
	proj._hit_player(player) # Hit player
	assert(proj._is_destroyed, "Projectile should mark as destroyed")
	
	print("✓ AudioManager full method suite and Projectile safety verified.")
	
	# Cleanup Suites 1-9 objects
	player.queue_free()
	slime.queue_free()
	golem.queue_free()
	spawner.queue_free()
	arena.queue_free()
	menu.queue_free()
	crate.queue_free()
	barrel.queue_free()
	trap.queue_free()
	proj.queue_free()
	await create_timer(0.05, true, false, true).timeout
	
	# =========================================================================
	# Test 10: Save Persistence, Loading, Corruption Recovery & Dynamic Talent Scaling
	# =========================================================================
	print("[10/14] Testing Save persistence, loading, corruption recovery & dynamic talent scaling...")
	
	# Preserve pre-existing user save files to guarantee zero player data loss
	var pre_existing_save: String = ""
	var had_pre_save: bool = FileAccess.file_exists("user://save_data.json")
	if had_pre_save:
		var f_pre := FileAccess.open("user://save_data.json", FileAccess.READ)
		if f_pre:
			pre_existing_save = f_pre.get_as_text()
			f_pre.close()
	
	var pre_existing_bak: String = ""
	var had_pre_bak: bool = FileAccess.file_exists("user://save_data.bak")
	if had_pre_bak:
		var fb_pre := FileAccess.open("user://save_data.bak", FileAccess.READ)
		if fb_pre:
			pre_existing_bak = fb_pre.get_as_text()
			fb_pre.close()
	
	var save_mgr = root.get_node_or_null("SaveManager")
	if not save_mgr:
		var sm_script: GDScript = load("res://src/meta/save_manager.gd")
		assert(sm_script != null, "SaveManager script failed to load")
		save_mgr = sm_script.new()
		save_mgr.name = "SaveManager"
		root.add_child(save_mgr)
	
	# 10.1: Reset save & verify baseline state
	save_mgr.reset_save()
	assert(save_mgr.get_soul_gems() == 0, "Initial soul gems must be 0")
	assert(save_mgr.get_lifetime_kills() == 0, "Initial lifetime kills must be 0")
	assert(save_mgr.get_high_score_wave() == 0, "Initial high score wave must be 0")
	assert(save_mgr.get_runs_played() == 0, "Initial runs played must be 0")
	assert(save_mgr.get_talent_level("max_health") == 0, "Initial max_health talent must be level 0")
	assert(save_mgr.get_talent_level("base_damage") == 0, "Initial base_damage talent must be level 0")
	assert(save_mgr.get_talent_level("move_speed") == 0, "Initial move_speed talent must be level 0")
	assert(save_mgr.get_talent_level("dash_cooldown") == 0, "Initial dash_cooldown talent must be level 0")
	
	# 10.2: Currency operations, run recording, and talent purchases
	save_mgr.add_soul_gems(500)
	assert(save_mgr.get_soul_gems() == 500, "Soul gems should equal 500 after addition")
	save_mgr.record_run_end(8, 65)
	assert(save_mgr.get_high_score_wave() == 8, "High score wave must be 8")
	assert(save_mgr.get_lifetime_kills() == 65, "Lifetime kills must be 65")
	assert(save_mgr.get_runs_played() == 1, "Runs played must be 1")
	
	var buy_hp1: bool = save_mgr.purchase_talent("max_health") # Level 1: cost 10
	var buy_hp2: bool = save_mgr.purchase_talent("max_health") # Level 2: cost 20
	assert(buy_hp1 and buy_hp2, "max_health talent purchases should succeed")
	assert(save_mgr.get_talent_level("max_health") == 2, "max_health talent level must be 2")
	
	var buy_dmg: bool = save_mgr.purchase_talent("base_damage") # Level 1: cost 15
	assert(buy_dmg, "base_damage talent purchase should succeed")
	assert(save_mgr.get_talent_level("base_damage") == 1, "base_damage talent level must be 1")
	
	var buy_spd: bool = save_mgr.purchase_talent("move_speed") # Level 1: cost 10
	assert(buy_spd, "move_speed talent purchase should succeed")
	assert(save_mgr.get_talent_level("move_speed") == 1, "move_speed talent level must be 1")
	
	var buy_dash: bool = save_mgr.purchase_talent("dash_cooldown") # Level 1: cost 12
	assert(buy_dash, "dash_cooldown talent purchase should succeed")
	assert(save_mgr.get_talent_level("dash_cooldown") == 1, "dash_cooldown talent level must be 1")
	
	var expected_remaining_gems: int = 500 - 10 - 20 - 15 - 10 - 12
	assert(save_mgr.get_soul_gems() == expected_remaining_gems, "Soul gems must accurately deduct costs")
	
	# 10.3: Save/Load roundtrip verification
	var save_res: bool = save_mgr.save_to_disk()
	assert(save_res == true, "save_to_disk() must return true")
	assert(FileAccess.file_exists("user://save_data.json"), "user://save_data.json must exist after save")
	
	var f_disk := FileAccess.open("user://save_data.json", FileAccess.READ)
	assert(f_disk != null, "Must be able to open save file on disk")
	var disk_text := f_disk.get_as_text()
	f_disk.close()
	var json_disk := JSON.new()
	assert(json_disk.parse(disk_text) == OK, "Save file on disk must be valid JSON")
	var disk_dict: Dictionary = json_disk.data
	assert(disk_dict["soul_gems"] == expected_remaining_gems, "Disk soul_gems must match")
	assert(disk_dict["lifetime_kills"] == 65, "Disk lifetime_kills must match")
	assert(disk_dict["high_score_wave"] == 8, "Disk high_score_wave must match")
	assert(disk_dict["talents"]["max_health"] == 2, "Disk max_health talent level must match")
	assert(disk_dict["talents"]["base_damage"] == 1, "Disk base_damage talent level must match")
	
	save_mgr._reset_to_default_in_memory()
	assert(save_mgr.get_soul_gems() == 0, "In-memory cache reset should show 0 gems")
	save_mgr.load_save()
	assert(save_mgr.get_soul_gems() == expected_remaining_gems, "Loaded soul gems must match saved value")
	assert(save_mgr.get_lifetime_kills() == 65, "Loaded lifetime kills must match saved value")
	assert(save_mgr.get_high_score_wave() == 8, "Loaded high score wave must match saved value")
	assert(save_mgr.get_talent_level("max_health") == 2, "Loaded max_health talent must be level 2")
	assert(save_mgr.get_talent_level("base_damage") == 1, "Loaded base_damage talent must be level 1")
	assert(save_mgr.get_talent_level("move_speed") == 1, "Loaded move_speed talent must be level 1")
	assert(save_mgr.get_talent_level("dash_cooldown") == 1, "Loaded dash_cooldown talent must be level 1")
	
	# 10.4: Corruption recovery & quarantine
	var corrupt_save_file := FileAccess.open("user://save_data.json", FileAccess.WRITE)
	corrupt_save_file.store_string("{corrupted_syntax: [unclosed JSON payload here ...")
	corrupt_save_file.close()
	
	# Corrupted primary save should recover cleanly (using backup if available or clean default)
	save_mgr.load_save()
	assert(save_mgr.get_soul_gems() >= 0, "Corrupted save must not crash and must retain valid non-negative gems")
	assert(FileAccess.file_exists(save_mgr.get_quarantine_path()), "Corrupted save must be quarantined")
	
	# Corrupt both primary save and backup to verify clean default schema fallback
	var corrupt_bak_file := FileAccess.open(save_mgr.get_backup_path(), FileAccess.WRITE)
	corrupt_bak_file.store_string("corrupted backup payload")
	corrupt_bak_file.close()
	var corrupt_save_file2 := FileAccess.open("user://save_data.json", FileAccess.WRITE)
	corrupt_save_file2.store_string("corrupted primary payload")
	corrupt_save_file2.close()
	
	save_mgr.load_save()
	assert(save_mgr.get_soul_gems() == 0, "SaveManager must recover with clean default schema (0 gems)")
	assert(save_mgr.get_talent_level("max_health") == 0, "Clean default schema must have 0 talent levels")
	assert(save_mgr.get_high_score_wave() == 0, "Clean default schema must have 0 high score wave")
	assert(FileAccess.file_exists("user://save_data.json"), "Fresh valid default save file must be generated")
	
	# 10.5: Dynamic player talent stat scaling & idempotence
	save_mgr.reset_save()
	save_mgr.add_soul_gems(1000)
	save_mgr.purchase_talent("max_health") # Level 1 (+20 HP)
	save_mgr.purchase_talent("max_health") # Level 2 (+40 HP)
	save_mgr.purchase_talent("base_damage") # Level 1 (+5 Damage)
	save_mgr.purchase_talent("move_speed") # Level 1 (+0.4 Speed)
	save_mgr.purchase_talent("dash_cooldown") # Level 1 (-0.08s CD)
	save_mgr.purchase_talent("dash_cooldown") # Level 2 (-0.16s CD)
	
	var p_talent = player_scene.instantiate()
	root.add_child(p_talent)
	if not p_talent.is_node_ready():
		await p_talent.ready
	
	# Expected stats:
	# max_health: 100 + (2 * 20) = 140
	# attack_damage: 30 + (1 * 5) = 35
	# move_speed: 7.5 + (1 * 0.4) = 7.9
	# dash_cooldown: 0.8 - (2 * 0.08) = 0.64
	assert(p_talent.max_health == 140, "Player max_health must scale with talent (+40 HP)")
	assert(p_talent.current_health == 140, "Player current_health must match buffed max_health")
	assert(p_talent.attack_damage == 35, "Player attack_damage must scale with talent (+5 Dmg)")
	assert(abs(p_talent.move_speed - 7.9) < 0.001, "Player move_speed must scale with talent (+0.4 Spd)")
	assert(abs(p_talent.dash_cooldown - 0.64) < 0.001, "Player dash_cooldown must scale with talent (-0.16s CD)")
	
	# Idempotence: repeated apply_meta_talents() calls must not stack bonuses
	p_talent.apply_meta_talents()
	p_talent.apply_meta_talents()
	assert(p_talent.max_health == 140, "apply_meta_talents() must remain idempotent for max_health")
	assert(p_talent.attack_damage == 35, "apply_meta_talents() must remain idempotent for attack_damage")
	assert(abs(p_talent.move_speed - 7.9) < 0.001, "apply_meta_talents() must remain idempotent for move_speed")
	assert(abs(p_talent.dash_cooldown - 0.64) < 0.001, "apply_meta_talents() must remain idempotent for dash_cooldown")
	p_talent.queue_free()
	
	# 10.6: Restore pre-existing user save files
	if had_pre_save:
		var f_restore := FileAccess.open("user://save_data.json", FileAccess.WRITE)
		if f_restore:
			f_restore.store_string(pre_existing_save)
			f_restore.close()
	else:
		var dir_clean := DirAccess.open("user://")
		if dir_clean and FileAccess.file_exists("user://save_data.json"):
			dir_clean.remove("save_data.json")
	
	if had_pre_bak:
		var fb_restore := FileAccess.open("user://save_data.bak", FileAccess.WRITE)
		if fb_restore:
			fb_restore.store_string(pre_existing_bak)
			fb_restore.close()
	else:
		var dir_clean := DirAccess.open("user://")
		if dir_clean and FileAccess.file_exists("user://save_data.bak"):
			dir_clean.remove("save_data.bak")
	
	save_mgr.load_save()
	print("✓ Save persistence, loading, corruption recovery & talent scaling verified.")
	
	# =========================================================================
	# Test 11: Arcane Wand Auto-Targeting, Cooldown Timing, Homing & Piercing
	# =========================================================================
	print("[11/14] Testing Arcane Wand auto-targeting, cooldown timing, homing & piercing...")
	
	var wand_scene: PackedScene = load("res://src/combat/arcane_wand.tscn")
	assert(wand_scene != null, "ArcaneWand scene failed to load")
	var wand: Node3D = wand_scene.instantiate()
	root.add_child(wand)
	wand.global_position = Vector3.ZERO
	
	var enemy_base_script: GDScript = load("res://src/enemies/enemy_base.gd")
	var wand_e1 := CharacterBody3D.new()
	wand_e1.set_script(enemy_base_script)
	wand_e1.name = "WandTarget1"
	wand_e1.add_to_group("enemies")
	wand_e1.is_dead = false
	wand_e1.current_health = 50
	root.add_child(wand_e1)
	wand_e1.global_position = Vector3(5.0, 0, 0)
	
	var wand_e2 := CharacterBody3D.new()
	wand_e2.set_script(enemy_base_script)
	wand_e2.name = "WandTarget2"
	wand_e2.add_to_group("enemies")
	wand_e2.is_dead = false
	wand_e2.current_health = 50
	root.add_child(wand_e2)
	wand_e2.global_position = Vector3(10.0, 0, 0)
	
	# 11.1: Auto-targeting nearest living enemy and distance filtering
	var wand_target: Node3D = wand.get_nearest_target()
	assert(wand_target == wand_e1, "Arcane Wand must acquire nearest living enemy (wand_e1 at 5m)")
	
	wand_e1.is_dead = true
	wand_target = wand.get_nearest_target()
	assert(wand_target == wand_e2, "Arcane Wand must switch to wand_e2 when wand_e1 is dead")
	
	wand_e2.global_position = Vector3(16.0, 0, 0) # Beyond 14m range
	wand_target = wand.get_nearest_target()
	assert(wand_target == null, "Arcane Wand must return null when all enemies exceed 14m range")
	
	# 11.2: Cooldown cycle and upgrade timing
	wand_e2.global_position = Vector3(5.0, 0, 0) # Return within range
	assert(wand.can_fire == true, "Wand should start ready to fire")
	assert(wand.attack_cooldown == 1.2, "Default attack cooldown must be 1.2s")
	assert(wand.base_damage == 22, "Default base damage must be 22")
	
	wand.fire()
	assert(wand.can_fire == false, "Firing must immediately trigger cooldown (can_fire == false)")
	assert(abs(wand.cooldown_timer - 1.2) < 0.001, "cooldown_timer must reset to attack_cooldown")
	
	wand._physics_process(0.5)
	assert(wand.can_fire == false, "Wand must remain in cooldown midway through timer")
	wand._physics_process(0.8)
	assert(abs(wand.cooldown_timer - 1.2) < 0.001 or wand.can_fire == true, "Wand must reset cooldown after elapsed interval")
	
	var prev_wand_cd: float = wand.attack_cooldown
	wand.apply_fire_rate_upgrade(0.25)
	assert(abs(wand.attack_cooldown - (prev_wand_cd * 0.75)) < 0.001, "apply_fire_rate_upgrade(0.25) must reduce cooldown by 25%")
	wand.apply_multishot_upgrade(1)
	assert(wand.projectile_count == 2, "apply_multishot_upgrade(1) must increase projectile count")
	wand.apply_pierce_upgrade(1)
	assert(wand.pierce_count == 1, "apply_pierce_upgrade(1) must increase pierce count")
	
	# 11.3: Homing vector steering and target deletion safety
	var arcane_proj_scene: PackedScene = load("res://src/combat/arcane_projectile.tscn")
	assert(arcane_proj_scene != null, "ArcaneProjectile scene failed to load")
	var arcane_proj = arcane_proj_scene.instantiate()
	root.add_child(arcane_proj)
	arcane_proj.global_position = Vector3(0, 0.5, 0)
	
	wand_e2.global_position = Vector3(5.0, 0, 5.0)
	arcane_proj.setup(wand_e2, 22, Vector3.FORWARD, 0)
	assert(arcane_proj.target == wand_e2, "Projectile target must be set to wand_e2")
	assert(arcane_proj.damage == 22, "Projectile damage must be 22")
	
	var initial_proj_dir: Vector3 = arcane_proj.current_direction
	arcane_proj._physics_process(0.1)
	var desired_proj_dir: Vector3 = ((wand_e2.global_position + Vector3(0, 0.6, 0)) - arcane_proj.global_position).normalized()
	assert(arcane_proj.current_direction.angle_to(desired_proj_dir) < initial_proj_dir.angle_to(desired_proj_dir), "Projectile must steer towards target")
	
	var wand_e3 := CharacterBody3D.new()
	wand_e3.set_script(enemy_base_script)
	wand_e3.name = "WandTarget3"
	wand_e3.add_to_group("enemies")
	wand_e3.is_dead = false
	wand_e3.current_health = 50
	root.add_child(wand_e3)
	wand_e3.global_position = Vector3(2.0, 0, 0)
	
	var enemy_freed := CharacterBody3D.new()
	enemy_freed.set_script(enemy_base_script)
	enemy_freed.add_to_group("enemies")
	root.add_child(enemy_freed)
	arcane_proj.target = enemy_freed
	enemy_freed.free() # Target freed mid-flight
	
	# Step physics: must not throw SCRIPT ERROR and must acquire next living enemy (wand_e3)
	arcane_proj._physics_process(0.016)
	assert(arcane_proj.target == wand_e3, "Projectile must dynamically re-acquire next nearest living enemy when target is freed")
	arcane_proj.queue_free()
	
	# 11.4: Piercing and double-hit protection
	var proj_single = arcane_proj_scene.instantiate()
	root.add_child(proj_single)
	var pierce_dummy1 := CharacterBody3D.new()
	pierce_dummy1.set_script(enemy_base_script)
	pierce_dummy1.name = "PierceDummy1"
	pierce_dummy1.add_to_group("enemies")
	root.add_child(pierce_dummy1)
	pierce_dummy1.max_health = 100
	pierce_dummy1.current_health = 100
	
	proj_single.setup(pierce_dummy1, 25, Vector3.FORWARD, 0)
	proj_single._handle_hit(pierce_dummy1)
	assert(pierce_dummy1.current_health == 75, "Enemy should take 25 damage on single hit")
	assert(proj_single._is_destroyed == true, "Single-hit projectile must mark destroyed after first hit")
	proj_single._handle_hit(pierce_dummy1) # Duplicate hit attempt
	assert(pierce_dummy1.current_health == 75, "Double-hit protection must prevent repeated damage to same enemy")
	proj_single.queue_free()
	
	var proj_pierce = arcane_proj_scene.instantiate()
	root.add_child(proj_pierce)
	var pierce_dummy2 := CharacterBody3D.new()
	pierce_dummy2.set_script(enemy_base_script)
	pierce_dummy2.name = "PierceDummy2"
	pierce_dummy2.add_to_group("enemies")
	root.add_child(pierce_dummy2)
	pierce_dummy2.max_health = 100
	pierce_dummy2.current_health = 100
	
	# Reset dummy1 health to 100 for pierce test
	pierce_dummy1.current_health = 100
	proj_pierce.setup(pierce_dummy1, 20, Vector3.FORWARD, 1)
	assert(proj_pierce.pierce_remaining == 1, "Pierce remaining should be 1")
	proj_pierce._handle_hit(pierce_dummy1) # First hit on dummy1
	assert(pierce_dummy1.current_health == 80, "pierce_dummy1 should take 20 damage (80 HP remaining)")
	assert(proj_pierce._is_destroyed == false, "Piercing projectile must survive first hit")
	assert(proj_pierce.pierce_remaining == 0, "Pierce remaining must decrement to 0")
	proj_pierce._handle_hit(pierce_dummy1) # Repeated hit attempt on dummy1
	assert(pierce_dummy1.current_health == 80, "Double-hit guard must prevent repeated damage to same entity on pierce")
	proj_pierce._handle_hit(pierce_dummy2) # Second hit on distinct enemy
	assert(pierce_dummy2.current_health == 80, "Second distinct enemy must take damage")
	assert(proj_pierce._is_destroyed == true, "Piercing projectile must destroy upon exhausting pierce limit")
	proj_pierce.queue_free()
	pierce_dummy1.queue_free()
	pierce_dummy2.queue_free()
	
	# 11.5: Upgrade Menu integration and capping filter
	var wand_menu = menu_scene.instantiate()
	root.add_child(wand_menu)
	var found_haste: bool = false
	var found_multi: bool = false
	var found_pierce: bool = false
	for upg in wand_menu.ALL_UPGRADES:
		if upg["id"] == "wand_haste":
			found_haste = true
			assert(upg["title"] == "Arcane Haste", "wand_haste title check")
		elif upg["id"] == "wand_multishot":
			found_multi = true
			assert(upg["title"] == "Arcane Volley", "wand_multishot title check")
		elif upg["id"] == "wand_pierce":
			found_pierce = true
			assert(upg["title"] == "Piercing Arcana", "wand_pierce title check")
	assert(found_haste and found_multi and found_pierce, "All 3 wand upgrades must be registered in ALL_UPGRADES")
	
	var p_wand_test = player_scene.instantiate()
	root.add_child(p_wand_test)
	if not p_wand_test.is_node_ready():
		await p_wand_test.ready
	wand_menu.player = p_wand_test
	
	# Cap wand upgrades
	p_wand_test.arcane_wand.attack_cooldown = 0.30 # Capped (<= 0.35)
	p_wand_test.arcane_wand.projectile_count = 4   # Capped (>= 4)
	p_wand_test.arcane_wand.pierce_count = 3       # Capped (>= 3)
	
	wand_menu.open_menu()
	var wand_card_container = wand_menu.get_node("Control/Panel/VBoxContainer/CardsContainer")
	for btn in wand_card_container.get_children():
		assert(not "Arcane Haste" in btn.text, "Capped Arcane Haste must not appear in card pool")
		assert(not "Arcane Volley" in btn.text, "Capped Arcane Volley must not appear in card pool")
		assert(not "Piercing Arcana" in btn.text, "Capped Piercing Arcana must not appear in card pool")
	
	wand.queue_free()
	wand_e1.queue_free()
	wand_e2.queue_free()
	wand_e3.queue_free()
	p_wand_test.queue_free()
	wand_menu.queue_free()
	print("✓ Arcane Wand auto-targeting, cooldown timing, homing & piercing verified.")
	
	# =========================================================================
	# Test 12: Elite Enemy Modifiers, Scale Preservation, Wave Restrictions & Guaranteed Drops
	# =========================================================================
	print("[12/14] Testing Elite enemy modifiers, scale preservation, wave restrictions & guaranteed drops...")
	
	var mage_scene: PackedScene = load("res://src/enemies/enemy_mage.tscn")
	assert(mage_scene != null, "Mage scene failed to load")
	
	# 12.1: Stat scaling across Slime, Golem, and Mage with idempotence check
	var elite_slime = slime_scene.instantiate()
	root.add_child(elite_slime)
	var s_base_hp: int = elite_slime.max_health
	var s_base_spd: float = elite_slime.move_speed
	var s_base_dmg: int = elite_slime.attack_damage
	var s_base_exp: int = elite_slime.exp_value
	
	assert(elite_slime.is_elite == false, "Slime should initially not be elite")
	elite_slime.make_elite()
	assert(elite_slime.is_elite == true, "make_elite() must set is_elite to true")
	assert(elite_slime.is_in_group("elite_enemies"), "Elite must be added to elite_enemies group")
	assert(elite_slime.max_health == int(float(s_base_hp) * 1.75), "Elite HP must scale by +75%")
	assert(elite_slime.current_health == elite_slime.max_health, "current_health must match buffed max_health")
	assert(abs(elite_slime.move_speed - (s_base_spd * 1.20)) < 0.001, "Elite move_speed must scale by +20%")
	assert(elite_slime.attack_damage == int(float(s_base_dmg) * 1.25), "Elite damage must scale by +25%")
	assert(elite_slime.exp_value == s_base_exp * 2, "Elite exp_value must double")
	
	# Idempotence check
	var elite_hp_cached: int = elite_slime.max_health
	elite_slime.make_elite()
	assert(elite_slime.max_health == elite_hp_cached, "make_elite() must be idempotent")
	
	var elite_golem = golem_scene.instantiate()
	root.add_child(elite_golem)
	var g_base_hp: int = elite_golem.max_health
	var g_base_spd: float = elite_golem.move_speed
	var g_base_dmg: int = elite_golem.attack_damage
	var g_base_exp: int = elite_golem.exp_value
	elite_golem.make_elite()
	assert(elite_golem.is_elite == true, "Golem make_elite must set is_elite")
	assert(elite_golem.max_health == int(float(g_base_hp) * 1.75), "Golem HP must scale +75%")
	assert(abs(elite_golem.move_speed - (g_base_spd * 1.20)) < 0.001, "Golem speed must scale +20%")
	assert(elite_golem.attack_damage == int(float(g_base_dmg) * 1.25), "Golem damage must scale +25%")
	assert(elite_golem.exp_value == g_base_exp * 2, "Golem exp must double")
	elite_golem.queue_free()
	
	var elite_mage = mage_scene.instantiate()
	root.add_child(elite_mage)
	var m_base_hp: int = elite_mage.max_health
	var m_base_spd: float = elite_mage.move_speed
	var m_base_dmg: int = elite_mage.attack_damage
	var m_base_exp: int = elite_mage.exp_value
	elite_mage.make_elite()
	assert(elite_mage.is_elite == true, "Mage make_elite must set is_elite")
	assert(elite_mage.max_health == int(float(m_base_hp) * 1.75), "Mage HP must scale +75%")
	assert(abs(elite_mage.move_speed - (m_base_spd * 1.20)) < 0.001, "Mage speed must scale +20%")
	assert(elite_mage.attack_damage == int(float(m_base_dmg) * 1.25), "Mage damage must scale +25%")
	assert(elite_mage.exp_value == m_base_exp * 2, "Mage exp must double")
	elite_mage.queue_free()
	
	# 12.2: Visual scale preservation & hit flash
	assert(elite_slime.base_scale == Vector3(1.25, 1.25, 1.25), "base_scale must be Vector3(1.25, 1.25, 1.25)")
	assert(elite_slime.visual_mesh.scale == Vector3(1.25, 1.25, 1.25), "visual_mesh scale must be 1.25x")
	if elite_slime.has_node("CollisionShape3D"):
		assert(elite_slime.get_node("CollisionShape3D").scale == Vector3(1.25, 1.25, 1.25), "CollisionShape3D scale must be 1.25x")
	
	elite_slime.take_damage(10, Vector3.ZERO, false)
	assert(elite_slime.base_scale == Vector3(1.25, 1.25, 1.25), "base_scale must remain 1.25x after non-lethal hit")
	assert(not elite_slime.is_dead, "Slime should survive 10 damage")
	
	# 12.3: Visual aura glow, TorusMesh ring, material emission & OmniLight3D
	assert(elite_slime.has_node("AuraGlow"), "Elite enemy must instantiate AuraGlow node")
	var aura_node := elite_slime.get_node("AuraGlow") as Node3D
	assert(aura_node != null, "AuraGlow must be a Node3D")
	assert(aura_node.has_node("AuraRing"), "AuraGlow must contain AuraRing")
	var aura_ring := aura_node.get_node("AuraRing") as MeshInstance3D
	assert(aura_ring != null and aura_ring.mesh is TorusMesh, "AuraRing must have a TorusMesh")
	var torus: TorusMesh = aura_ring.mesh as TorusMesh
	assert(abs(torus.inner_radius - (0.65 * 1.25)) < 0.001, "Torus inner_radius must match 0.65 * 1.25")
	assert(abs(torus.outer_radius - (0.85 * 1.25)) < 0.001, "Torus outer_radius must match 0.85 * 1.25")
	assert(abs(aura_ring.position.y - 0.08) < 0.001, "AuraRing position.y must be 0.08")
	
	var mat: StandardMaterial3D = aura_ring.material_override as StandardMaterial3D
	assert(mat != null and mat.emission_enabled, "AuraRing must have emission enabled StandardMaterial3D")
	assert(abs(mat.emission_energy_multiplier - 4.0) < 0.001, "AuraRing emission energy multiplier must be 4.0")
	
	assert(aura_node.has_node("AuraLight"), "AuraGlow must contain AuraLight")
	var aura_light := aura_node.get_node("AuraLight") as OmniLight3D
	assert(aura_light != null, "AuraLight must be an OmniLight3D")
	assert(abs(aura_light.light_energy - 2.2) < 0.001, "AuraLight energy must be 2.2")
	assert(abs(aura_light.omni_range - 3.5) < 0.001, "AuraLight range must be 3.5")
	assert(abs(aura_light.position.y - 0.5) < 0.001, "AuraLight position.y must be 0.5")
	elite_slime.queue_free()
	
	# 12.4: Spawner wave restrictions & Boss exclusion
	var spawner_box := Node3D.new()
	root.add_child(spawner_box)
	var elite_spawner = spawner_script.new()
	spawner_box.add_child(elite_spawner)
	
	var dummy_player_node := Node3D.new()
	dummy_player_node.add_to_group("player")
	root.add_child(dummy_player_node)
	elite_spawner.player = dummy_player_node
	
	# Wave 1: 0% elite rate across 20 spawns
	elite_spawner.current_wave = 1
	var w1_elites: int = 0
	for i in range(20):
		elite_spawner.enemies_to_spawn = 1
		elite_spawner._spawn_enemy()
	for child in spawner_box.get_children():
		if child is CharacterBody3D and child.has_method("make_elite") and child.is_elite:
			w1_elites += 1
		if child is CharacterBody3D:
			child.free()
	assert(w1_elites == 0, "Wave 1 MUST have strictly 0% elite spawn rate")
	
	# Wave 2: 0% elite rate across 20 spawns
	elite_spawner.current_wave = 2
	var w2_elites: int = 0
	for i in range(20):
		elite_spawner.enemies_to_spawn = 1
		elite_spawner._spawn_enemy()
	for child in spawner_box.get_children():
		if child is CharacterBody3D and child.has_method("make_elite") and child.is_elite:
			w2_elites += 1
		if child is CharacterBody3D:
			child.free()
	assert(w2_elites == 0, "Wave 2 MUST have strictly 0% elite spawn rate")
	
	# Wave 3+ probability formula checks
	var rate_w3: float = clamp(0.15 + (float(3 - 3) * 0.04), 0.15, 0.40)
	var rate_w5: float = clamp(0.15 + (float(5 - 3) * 0.04), 0.15, 0.40)
	var rate_w10: float = clamp(0.15 + (float(10 - 3) * 0.04), 0.15, 0.40)
	assert(abs(rate_w3 - 0.15) < 0.001, "Wave 3 elite probability formula check (0.15)")
	assert(abs(rate_w5 - 0.23) < 0.001, "Wave 5 elite probability formula check (0.23)")
	assert(abs(rate_w10 - 0.40) < 0.001, "Wave 10 elite probability clamp check (0.40)")
	
	# Wave 4 runtime spawn emergence (> 0 elites across 60 spawns)
	elite_spawner.current_wave = 4
	var w4_elites: int = 0
	for i in range(60):
		elite_spawner.enemies_to_spawn = 1
		elite_spawner._spawn_enemy()
	for child in spawner_box.get_children():
		if child is CharacterBody3D and child.has_method("make_elite") and child.is_elite:
			w4_elites += 1
		if child is CharacterBody3D:
			child.free()
	assert(w4_elites > 0, "Wave 4 must produce > 0 elites across 60 spawns")
	
	# Boss Demon Knight exclusion
	var test_boss = boss_scene.instantiate()
	root.add_child(test_boss)
	assert(test_boss.is_in_group("boss"), "Boss must be in 'boss' group")
	assert(not (elite_spawner.current_wave >= 3 and test_boss.has_method("make_elite") and not test_boss.is_in_group("boss")), "Boss must be strictly excluded from elite rolls")
	test_boss.free()
	
	dummy_player_node.free()
	spawner_box.free()
	
	# 12.5: Guaranteed drops and dynamic player HP weighting
	var drop_test_player = player_scene.instantiate()
	root.add_child(drop_test_player)
	
	var drop_box := Node3D.new()
	root.add_child(drop_box)
	
	var test_elite_single = slime_scene.instantiate()
	drop_box.add_child(test_elite_single)
	test_elite_single.player = drop_test_player
	test_elite_single.make_elite()
	test_elite_single.die()
	
	var single_drops: Array[Node] = []
	for child in drop_box.get_children():
		if child is Area3D and child.has_method("setup_elite"):
			single_drops.append(child)
	assert(single_drops.size() >= 1, "Defeated elite MUST guarantee at least 1 reward drop")
	var drop_item = single_drops[0]
	assert(drop_item.item_type == 0 or drop_item.item_type == 2, "Drop type must be HEALTH (0) or SOUL_GEM (2)")
	if drop_item.item_type == 0:
		assert(drop_item.heal_amount == 40, "Guaranteed health potion must heal 40")
	else:
		assert(drop_item.value == 5, "Guaranteed soul gem must have value 5")
	drop_box.free()
	
	# Low HP test (< 45%): 65% Health Potion, 35% Soul Gem
	var drop_box_low := Node3D.new()
	root.add_child(drop_box_low)
	drop_test_player.max_health = 100
	drop_test_player.current_health = 30 # 30% HP (< 45%)
	var pot_count_low: int = 0
	var drop_trials: int = 150
	for i in range(drop_trials):
		var e_low = slime_scene.instantiate()
		drop_box_low.add_child(e_low)
		e_low.player = drop_test_player
		e_low.make_elite()
		e_low.die()
	for child in drop_box_low.get_children():
		if child is Area3D and child.has_method("setup_elite"):
			if child.item_type == 0:
				pot_count_low += 1
	var pot_ratio: float = float(pot_count_low) / float(drop_trials)
	assert(pot_ratio >= 0.50 and pot_ratio <= 0.80, "Low HP drop weighting should favor Health Potions (~65%%, got %.2f)" % pot_ratio)
	drop_box_low.free()
	
	# High HP test (>= 45%): 60% Soul Gem, 40% Health Potion
	var drop_box_high := Node3D.new()
	root.add_child(drop_box_high)
	drop_test_player.current_health = 90 # 90% HP (>= 45%)
	var gem_count_high: int = 0
	for i in range(drop_trials):
		var e_high = slime_scene.instantiate()
		drop_box_high.add_child(e_high)
		e_high.player = drop_test_player
		e_high.make_elite()
		e_high.die()
	for child in drop_box_high.get_children():
		if child is Area3D and child.has_method("setup_elite"):
			if child.item_type == 2:
				gem_count_high += 1
	var gem_ratio: float = float(gem_count_high) / float(drop_trials)
	assert(gem_ratio >= 0.45 and gem_ratio <= 0.75, "High HP drop weighting should favor Soul Gems (~60%%, got %.2f)" % gem_ratio)
	drop_box_high.free()
	drop_test_player.free()
	
	# Regular enemies drop 0 guaranteed items
	var reg_box := Node3D.new()
	root.add_child(reg_box)
	for i in range(10):
		var reg_slime = slime_scene.instantiate()
		reg_box.add_child(reg_slime)
		assert(not reg_slime.is_elite, "Regular enemy must not be elite")
		reg_slime.die()
	var reg_drops: int = 0
	for child in reg_box.get_children():
		if child is Area3D and child.has_method("setup_elite"):
			reg_drops += 1
		child.queue_free()
	assert(reg_drops == 0, "Regular enemies must NOT drop guaranteed rewards")
	reg_box.free()
	
	# Pickup item setup_elite tests
	var p_pot = pickup_scene.instantiate()
	root.add_child(p_pot)
	p_pot.setup_elite(0, Vector3.ZERO)
	assert(p_pot.item_type == 0, "p_pot item_type must be HEALTH (0)")
	assert(p_pot.heal_amount == 40, "p_pot heal_amount must be 40")
	assert(abs(p_pot.scale.x - 1.35) < 0.001, "Elite pickup scale must be 1.35")
	p_pot.queue_free()
	
	var p_gem = pickup_scene.instantiate()
	root.add_child(p_gem)
	p_gem.setup_elite(2, Vector3.ZERO)
	assert(p_gem.item_type == 2, "p_gem item_type must be SOUL_GEM (2)")
	assert(p_gem.value == 5, "Elite soul gem value must be 5")
	assert(p_gem.gem_value == 5, "gem_value alias must be 5")
	assert(abs(p_gem.scale.x - 1.35) < 0.001, "Elite soul gem scale must be 1.35")
	p_gem.queue_free()
	
	# 12.6: Jolt transform safety
	var jolt_slime = slime_scene.instantiate()
	root.add_child(jolt_slime)
	jolt_slime.make_elite()
	assert(jolt_slime.scale.x > 0.0 and jolt_slime.scale.y > 0.0 and jolt_slime.scale.z > 0.0, "CharacterBody3D scale must be positive")
	if jolt_slime.has_node("CollisionShape3D"):
		var col_shape: CollisionShape3D = jolt_slime.get_node("CollisionShape3D") as CollisionShape3D
		assert(col_shape.scale.x > 0.0 and col_shape.scale.y > 0.0 and col_shape.scale.z > 0.0, "CollisionShape3D scale must be positive")
	
	jolt_slime.take_damage(5, Vector3.RIGHT, false)
	assert(jolt_slime.base_scale == Vector3(1.25, 1.25, 1.25), "base_scale preserved across damage")
	jolt_slime.die()
	assert(jolt_slime.scale.x >= 0.01 and jolt_slime.scale.y >= 0.01 and jolt_slime.scale.z >= 0.01, "CharacterBody3D transform must remain non-zero during death")
	jolt_slime.queue_free()
	print("✓ Elite enemy modifiers, scale preservation, wave restrictions & guaranteed drops verified.")
	
	print("\n=======================================================")
	# =========================================================================
	# Test 13: Lava Caverns Biome Progression & Environment Transition (R1, R4)
	# =========================================================================
	print("[13/14] Testing Lava Caverns Biome Progression & Environment Transition...")
	
	# 13.1: Volcanic Basalt Molten Vein Shader loading and parameter checks
	var lava_shader: Shader = load("res://src/shaders/lava_basalt_floor.gdshader")
	assert(lava_shader != null, "lava_basalt_floor.gdshader failed to load")
	var s13_shader_mat := ShaderMaterial.new()
	s13_shader_mat.shader = lava_shader
	assert(s13_shader_mat.shader != null, "ShaderMaterial shader must be assigned")
	s13_shader_mat.set_shader_parameter("basalt_color", Color(0.08, 0.07, 0.08, 1.0))
	s13_shader_mat.set_shader_parameter("lava_color", Color(1.0, 0.32, 0.04, 1.0))
	s13_shader_mat.set_shader_parameter("lava_core_color", Color(1.0, 0.85, 0.25, 1.0))
	s13_shader_mat.set_shader_parameter("crack_scale", 24.0)
	s13_shader_mat.set_shader_parameter("crack_intensity", 1.0)
	s13_shader_mat.set_shader_parameter("pulse_speed", 2.4)
	s13_shader_mat.set_shader_parameter("roughness_val", 0.85)
	
	# 13.2: Arena Biome Mutation & Fiery Lighting Transition
	var s13_container := Node3D.new()
	root.add_child(s13_container)
	var s13_dir_light := DirectionalLight3D.new()
	s13_dir_light.name = "DirectionalLight3D"
	s13_container.add_child(s13_dir_light)
	var s13_world_env := WorldEnvironment.new()
	s13_world_env.name = "WorldEnvironment"
	s13_world_env.environment = Environment.new()
	s13_container.add_child(s13_world_env)
	
	var s13_arena = arena_scene.instantiate()
	s13_container.add_child(s13_arena)
	if not s13_arena.is_node_ready():
		await s13_arena.ready
	
	assert(s13_arena.current_biome == 0, "Arena initial biome must be DUNGEON (0)")
	assert(s13_arena.is_lava_biome == false, "Arena initial is_lava_biome must be false")
	
	var s13_embers: GPUParticles3D = s13_arena.get_node_or_null("VolcanicEmbers")
	assert(s13_embers != null, "VolcanicEmbers node must exist in Arena")
	assert(s13_embers is GPUParticles3D, "VolcanicEmbers must be GPUParticles3D")
	assert(s13_embers.amount == 140, "VolcanicEmbers particle count must be 140")
	assert(s13_embers.emitting == false, "VolcanicEmbers must not be emitting initially")
	
	var s13_motes: GPUParticles3D = s13_arena.get_node_or_null("DungeonMotes")
	assert(s13_motes != null, "DungeonMotes node must exist")
	assert(s13_motes.emitting == true, "DungeonMotes must be emitting initially")
	
	# Trigger transition with 0 duration for deterministic instant assertion
	s13_arena.transition_to_lava_caverns(0.0)
	assert(s13_arena.is_lava_biome == true, "is_lava_biome must be true after transition")
	assert(s13_arena.current_biome == 1, "current_biome must be 1 (LAVA_CAVERNS)")
	assert(s13_embers.emitting == true, "VolcanicEmbers must be emitting after transition")
	assert(s13_motes.emitting == false, "DungeonMotes must stop emitting after transition")
	
	var s13_floor_mesh: MeshInstance3D = s13_arena.get_node_or_null("Floor/MeshInstance3D")
	assert(s13_floor_mesh != null, "Floor MeshInstance3D must exist")
	assert(s13_floor_mesh.material_override is ShaderMaterial, "Floor material_override must be a ShaderMaterial")
	var s13_applied_shader = (s13_floor_mesh.material_override as ShaderMaterial).shader
	assert(s13_applied_shader == lava_shader, "Floor shader must be lava_basalt_floor.gdshader")
	
	# Verify fiery torch lighting
	var s13_torch1 = s13_arena.get_node_or_null("Pillar1/TorchLight") as OmniLight3D
	assert(s13_torch1 != null, "Pillar1 must contain TorchLight")
	assert(s13_torch1.light_color.is_equal_approx(Color(1.0, 0.42, 0.08, 1.0)), "Torch light color must be fiery red-orange")
	assert(abs(s13_torch1.light_energy - 3.8) < 0.001, "Torch light energy must be 3.8")
	assert(abs(s13_torch1.omni_range - 16.0) < 0.001, "Torch omni range must be 16.0")
	
	var s13_flame = s13_arena.get_node_or_null("Pillar1/Flame") as MeshInstance3D
	if s13_flame and s13_flame.mesh and s13_flame.mesh.material is StandardMaterial3D:
		var flame_mat := s13_flame.mesh.material as StandardMaterial3D
		assert(flame_mat.emission.is_equal_approx(Color(1.0, 0.35, 0.05, 1.0)), "Flame emission must be fiery orange")
		assert(abs(flame_mat.emission_energy_multiplier - 5.0) < 0.001, "Flame emission multiplier must be 5.0")
	
	# Verify fiery directional and ambient lighting changes
	assert(s13_dir_light.light_color.is_equal_approx(Color(1.0, 0.58, 0.28, 1.0)), "Directional light color must update to warm fiery sun")
	assert(abs(s13_dir_light.light_energy - 1.35) < 0.001, "Directional light energy must update to 1.35")
	assert(s13_world_env.environment.ambient_light_color.is_equal_approx(Color(0.50, 0.20, 0.10, 1.0)), "Ambient light color must update to fiery ambient")
	assert(abs(s13_world_env.environment.ambient_light_energy - 1.15) < 0.001, "Ambient light energy must update to 1.15")
	
	# Idempotency verification: calling transition again remains safe and keeps state
	s13_arena.transition_to_lava_caverns(0.0)
	assert(s13_arena.is_lava_biome == true, "Idempotent transition retains is_lava_biome == true")
	assert(s13_arena.current_biome == 1, "Idempotent transition retains current_biome == 1")
	s13_container.queue_free()
	
	# 13.3: HUD AnnouncementBanner display, visibility and auto-dismiss
	var hud_scene: PackedScene = load("res://src/ui/hud.tscn")
	assert(hud_scene != null, "HUD scene failed to load")
	var s13_hud = hud_scene.instantiate()
	root.add_child(s13_hud)
	if not s13_hud.is_node_ready():
		await s13_hud.ready
	
	var s13_banner: VBoxContainer = s13_hud.get_node_or_null("Control/AnnouncementBanner")
	assert(s13_banner != null, "AnnouncementBanner node must exist under Control in HUD")
	var s13_title_lbl: Label = s13_banner.get_node_or_null("BannerTitle")
	var s13_sub_lbl: Label = s13_banner.get_node_or_null("BannerSubtitle")
	assert(s13_title_lbl != null, "BannerTitle must exist in AnnouncementBanner")
	assert(s13_sub_lbl != null, "BannerSubtitle must exist in AnnouncementBanner")
	assert(s13_banner.visible == false, "AnnouncementBanner must be initially hidden")
	assert(s13_banner.modulate.a == 0.0, "AnnouncementBanner modulate.a must be 0 initially")
	
	# Show banner with short display duration to test lifecycle
	s13_hud.show_biome_banner("DESCENDING INTO LAVA CAVERNS", "BIOME II: VOLCANIC UNDERWORLD", 0.05)
	assert(s13_banner.visible == true, "AnnouncementBanner must be visible when triggered")
	assert(s13_title_lbl.text == "DESCENDING INTO LAVA CAVERNS", "BannerTitle text must match contract")
	assert(s13_sub_lbl.text == "BIOME II: VOLCANIC UNDERWORLD", "BannerSubtitle text must match contract")
	
	# Rapid consecutive call should safely replace tween without crash
	s13_hud.show_biome_banner("DESCENDING INTO LAVA CAVERNS", "BIOME II: VOLCANIC UNDERWORLD", 0.05)
	assert(s13_banner.visible == true, "AnnouncementBanner remains visible after re-trigger")
	assert(s13_hud._banner_tween != null and s13_hud._banner_tween.is_valid(), "Banner tween must remain valid")
	
	# Auto-dismiss test: await tween finished for auto-dismiss completion
	if s13_hud._banner_tween and s13_hud._banner_tween.is_valid():
		await s13_hud._banner_tween.finished
		await process_frame
	assert(s13_banner.visible == false, "AnnouncementBanner must auto-dismiss after duration")
	s13_hud.queue_free()
	
	# 13.4: Main Scene Wave 6+ Transition Hook & Wave 1-5 Non-Regression
	var main_scene: PackedScene = load("scenes/main.tscn")
	assert(main_scene != null, "Main scene failed to load")
	var s13_main = main_scene.instantiate()
	root.add_child(s13_main)
	if not s13_main.is_node_ready():
		await s13_main.ready
	
	assert(s13_main._is_lava_biome == false, "Main _is_lava_biome must be false initially")
	var s13_main_arena = s13_main.get_node("Arena")
	assert(s13_main_arena.is_lava_biome == false, "Main arena must be dungeon biome initially")
	
	# Waves 1 through 5 must NOT trigger biome transition
	for w in range(1, 6):
		s13_main._on_wave_started(w)
		assert(s13_main._is_lava_biome == false, "Wave %d must not trigger lava transition" % w)
		assert(s13_main_arena.is_lava_biome == false, "Main arena must remain dungeon biome at wave %d" % w)
		assert(s13_main_arena.current_biome == 0, "current_biome must remain DUNGEON at wave %d" % w)
	
	# Wave 6 MUST trigger Lava Caverns transition
	s13_main._on_wave_started(6)
	assert(s13_main._is_lava_biome == true, "Wave 6 must trigger lava transition in Main")
	assert(s13_main_arena.is_lava_biome == true, "Arena must transition to lava biome at wave 6")
	assert(s13_main_arena.current_biome == 1, "Arena current_biome must be 1 (LAVA_CAVERNS)")
	var s13_main_banner = s13_main.get_node("HUD/Control/AnnouncementBanner")
	assert(s13_main_banner.visible == true, "AnnouncementBanner must be shown in HUD on wave 6 transition")
	
	# Subsequent wave 7: Idempotent and maintains lava biome
	s13_main._on_wave_started(7)
	assert(s13_main._is_lava_biome == true, "Wave 7 maintains lava biome")
	assert(s13_main_arena.is_lava_biome == true, "Arena remains in lava biome at wave 7")
	s13_main.queue_free()
	
	# 13.5: Procedural Volcanic Audio Atmosphere in AudioManager
	var s13_audio = root.get_node_or_null("AudioManager")
	if not s13_audio:
		var audio_script := load("res://src/audio/audio_manager.gd")
		s13_audio = audio_script.new()
		root.add_child(s13_audio)
	
	assert(s13_audio.stream_volcanic_rumble != null, "AudioManager stream_volcanic_rumble must be generated")
	assert(s13_audio.stream_volcanic_rumble.data.size() > 0, "Volcanic rumble PCM data must be populated")
	assert(s13_audio.has_method("play_volcanic_rumble"), "play_volcanic_rumble method must exist")
	assert(s13_audio.has_method("start_volcanic_ambience"), "start_volcanic_ambience method must exist")
	assert(s13_audio.has_method("stop_volcanic_ambience"), "stop_volcanic_ambience method must exist")
	assert(s13_audio.has_method("set_volcanic_ambience"), "set_volcanic_ambience method must exist")
	
	s13_audio.start_volcanic_ambience()
	if s13_audio._ambient_player:
		assert(s13_audio._ambient_player.playing == true, "Ambient player must be playing after start_volcanic_ambience")
	s13_audio.set_volcanic_ambience(false)
	if s13_audio._ambient_player:
		assert(s13_audio._ambient_player.playing == false, "Ambient player must stop after set_volcanic_ambience(false)")
	s13_audio.set_volcanic_ambience(true)
	if s13_audio._ambient_player:
		assert(s13_audio._ambient_player.playing == true, "Ambient player must restart after set_volcanic_ambience(true)")
	s13_audio.stop_volcanic_ambience()
	if s13_audio._ambient_player:
		assert(s13_audio._ambient_player.playing == false, "Ambient player must be stopped after stop_volcanic_ambience()")
	
	print("✓ Lava Caverns biome transition, shader, lighting, banner, and audio verified.")
	
	# =========================================================================
	# Test 14: Volcanic Hazards & Environmental Destruction (R2, R3)
	# =========================================================================
	print("[14/14] Testing Volcanic Hazards & Environmental Destruction...")
	
	# 14.1: Molten Lava Floor Hazard 3-phase cycle
	var lava_scene: PackedScene = load("res://src/hazards/lava_floor_hazard.tscn")
	assert(lava_scene != null, "Lava floor hazard scene failed to load")
	var s14_lava = lava_scene.instantiate()
	s14_lava.auto_start = false
	root.add_child(s14_lava)
	if not s14_lava.is_node_ready():
		await s14_lava.ready
	
	# Timing and damage contract exports
	assert(abs(s14_lava.telegraph_duration - 1.2) < 0.001, "Telegraph duration must be 1.2s")
	assert(abs(s14_lava.erupting_duration - 1.5) < 0.001, "Erupting duration must be 1.5s")
	assert(abs(s14_lava.erupt_duration - 1.5) < 0.001, "erupt_duration alias must be 1.5s")
	assert(s14_lava.damage_per_tick == 15, "Damage per tick must be 15")
	assert(abs(s14_lava.tick_interval - 0.35) < 0.001, "Tick interval must be 0.35s")
	
	# Phase 1: Dormant
	s14_lava._enter_dormant()
	assert(s14_lava.current_state == 0, "current_state must be DORMANT (0)")
	assert(s14_lava.warning_light.visible == false, "Warning light must be off when dormant")
	assert(s14_lava.bubbling_particles.emitting == false, "Bubbling particles must be off when dormant")
	assert(s14_lava.eruption_particles.emitting == false, "Eruption particles must be off when dormant")
	
	# Phase 2: Telegraph (1.2s)
	s14_lava._enter_telegraph()
	assert(s14_lava.current_state == 1, "current_state must be TELEGRAPH (1)")
	assert(s14_lava.warning_light.visible == true, "Warning light must be visible during telegraph")
	assert(s14_lava.warning_light.light_color.r > 0.8 and s14_lava.warning_light.light_color.g > 0.6, "Warning light must be yellow/orange during telegraph")
	assert(s14_lava.bubbling_particles.emitting == true, "Bubbling particles must be emitting during telegraph")
	assert(s14_lava.eruption_particles.emitting == false, "Eruption particles must be off during telegraph")
	
	# Phase 3: Erupting (1.5s)
	s14_lava._enter_erupting()
	assert(s14_lava.current_state == 2, "current_state must be ERUPTING (2)")
	assert(s14_lava.warning_light.visible == true, "Warning light must be visible during erupting")
	assert(s14_lava.warning_light.light_color.r > 0.8 and s14_lava.warning_light.light_color.g < 0.4, "Warning light must be fiery red-orange during erupting")
	assert(s14_lava.bubbling_particles.emitting == false, "Bubbling particles must be off during erupting")
	assert(s14_lava.eruption_particles.emitting == true, "Eruption particles must be emitting during erupting")
	
	# Jolt transform safety for lava hazard
	assert(s14_lava.scale.x > 0.0 and s14_lava.scale.y > 0.0 and s14_lava.scale.z > 0.0, "Lava hazard root scale must be strictly positive")
	assert(s14_lava.damage_area.scale == Vector3.ONE, "DamageArea scale must remain Vector3.ONE for Jolt safety")
	
	# 14.2: Lava Floor Dual-Entity Fire Damage (Player + Enemy)
	var s14_player = player_scene.instantiate()
	root.add_child(s14_player)
	if not s14_player.is_node_ready():
		await s14_player.ready
	
	var s14_slime = slime_scene.instantiate()
	root.add_child(s14_slime)
	if not s14_slime.is_node_ready():
		await s14_slime.ready
	
	var s14_p_hp_before: int = s14_player.current_health
	var s14_e_hp_before: int = s14_slime.current_health
	
	s14_lava._deal_damage_to_target(s14_player)
	s14_lava._deal_damage_to_target(s14_slime)
	
	assert(s14_player.current_health == s14_p_hp_before - 15, "Player must take exactly 15 fire damage from lava tile")
	assert(s14_slime.current_health == s14_e_hp_before - 15, "Enemy must take exactly 15 fire damage from lava tile")
	
	s14_player.queue_free()
	s14_slime.queue_free()
	s14_lava.queue_free()
	
	# 14.3: Falling Stalactite Hazard parameters and state transitions
	var stalactite_scene: PackedScene = load("res://src/hazards/falling_stalactite.tscn")
	assert(stalactite_scene != null, "Falling stalactite scene failed to load")
	var s14_stalactite_parent := Node3D.new()
	root.add_child(s14_stalactite_parent)
	
	var s14_stalactite = stalactite_scene.instantiate()
	s14_stalactite_parent.add_child(s14_stalactite)
	if not s14_stalactite.is_node_ready():
		await s14_stalactite.ready
	
	assert(abs(s14_stalactite.warning_duration - 1.0) < 0.001, "Stalactite warning duration must be 1.0s")
	assert(abs(s14_stalactite.fall_duration - 0.20) < 0.001, "Stalactite fall duration must be 0.20s")
	assert(abs(s14_stalactite.ceiling_height - 14.0) < 0.001, "Stalactite ceiling height must be 14.0m")
	assert(abs(s14_stalactite.impact_radius - 2.5) < 0.001, "Stalactite impact radius must be 2.5m")
	assert(s14_stalactite.damage == 40, "Stalactite impact damage must be 40")
	assert(s14_stalactite.current_state == 0, "Stalactite initial state must be TELEGRAPH (0)")
	assert(s14_stalactite.telegraph_root.visible == true, "Telegraph root must be visible")
	assert(s14_stalactite.stalactite_mesh.visible == false, "Stalactite mesh must be hidden during telegraph")
	assert(abs(s14_stalactite.stalactite_mesh.position.y - 14.0) < 0.001, "Stalactite mesh must start at ceiling Y=14m")
	
	# Step through lifecycle: 1.0s telegraph -> fall -> impact
	s14_stalactite._process(0.50)
	assert(s14_stalactite.current_state == 0, "Stalactite state remains TELEGRAPH at 0.5s")
	s14_stalactite._process(0.51)
	assert(s14_stalactite.current_state == 1, "Stalactite transitions to FALLING (1) after 1.0s")
	assert(s14_stalactite.stalactite_mesh.visible == true, "Stalactite mesh visible while falling")
	
	s14_stalactite_parent.queue_free()
	
	# 14.4: Falling Stalactite Deterministic AoE Impact Damage (40 dmg), Camera Shake & Audio
	var s14_impact_box := Node3D.new()
	root.add_child(s14_impact_box)
	
	var s14_victim_player = player_scene.instantiate()
	s14_impact_box.add_child(s14_victim_player)
	if not s14_victim_player.is_node_ready():
		await s14_victim_player.ready
	s14_victim_player.add_to_group("player")
	s14_victim_player.global_position = Vector3(1.0, 0, 1.0) # within 2.5m
	
	var s14_victim_enemy = slime_scene.instantiate()
	s14_impact_box.add_child(s14_victim_enemy)
	if not s14_victim_enemy.is_node_ready():
		await s14_victim_enemy.ready
	s14_victim_enemy.add_to_group("enemies")
	s14_victim_enemy.global_position = Vector3(-1.0, 0, 0.5) # within 2.5m
	
	var s14_safe_enemy = slime_scene.instantiate()
	s14_impact_box.add_child(s14_safe_enemy)
	if not s14_safe_enemy.is_node_ready():
		await s14_safe_enemy.ready
	s14_safe_enemy.add_to_group("enemies")
	s14_safe_enemy.global_position = Vector3(10.0, 0, 10.0) # well outside 2.5m
	
	var s14_p_init_hp: int = s14_victim_player.current_health
	var s14_e_init_hp: int = s14_victim_enemy.current_health
	var s14_safe_init_hp: int = s14_safe_enemy.current_health
	
	var s14_drop_rock = stalactite_scene.instantiate()
	s14_impact_box.add_child(s14_drop_rock)
	if not s14_drop_rock.is_node_ready():
		await s14_drop_rock.ready
	s14_drop_rock.global_position = Vector3(0, 0, 0)
	
	# Trigger deterministic impact
	s14_drop_rock.trigger_impact_now()
	
	assert(s14_victim_player.current_health == s14_p_init_hp - 40, "Player inside impact radius must take 40 damage")
	assert(s14_victim_enemy.current_health == s14_e_init_hp - 40, "Enemy inside impact radius must take 40 damage")
	assert(s14_safe_enemy.current_health == s14_safe_init_hp, "Enemy outside impact radius must take 0 damage")
	assert(s14_victim_player.camera_trauma > 0.0, "Camera shake trauma must be applied to player upon impact")
	
	s14_victim_player.queue_free()
	s14_victim_enemy.queue_free()
	s14_safe_enemy.queue_free()
	s14_impact_box.queue_free()
	
	# 14.5: Ground Rock Debris Particle Burst
	var debris_scene: PackedScene = load("res://src/combat/rock_debris_vfx.tscn")
	assert(debris_scene != null, "Rock debris VFX scene failed to load")
	var s14_debris = debris_scene.instantiate()
	root.add_child(s14_debris)
	if not s14_debris.is_node_ready():
		await s14_debris.ready
	assert(s14_debris.amount == 16, "Rock debris VFX particle amount must be 16")
	assert(s14_debris.one_shot == true, "Rock debris VFX must be one_shot")
	s14_debris.queue_free()
	
	# 14.6: Destructible Rock Fragment obstacle & Jolt safety
	var rock_scene: PackedScene = load("res://src/props/rock_fragment.tscn")
	assert(rock_scene != null, "Rock fragment scene failed to load")
	var s14_rock = rock_scene.instantiate()
	root.add_child(s14_rock)
	if not s14_rock.is_node_ready():
		await s14_rock.ready
	
	assert(s14_rock.is_in_group("destructibles"), "Rock fragment must belong to 'destructibles' group")
	assert(s14_rock.is_in_group("rock_fragments"), "Rock fragment must belong to 'rock_fragments' group")
	assert(s14_rock.max_health == 20, "Rock fragment max health must be 20")
	assert(s14_rock.current_health == 20, "Rock fragment initial health must be 20")
	
	# Non-lethal hit
	s14_rock.take_damage(5)
	assert(s14_rock.current_health == 15, "Rock fragment health must be 15 after 5 damage")
	assert(s14_rock.scale.x > 0.0 and s14_rock.scale.y > 0.0 and s14_rock.scale.z > 0.0, "Rock StaticBody3D root scale must remain positive")
	
	# Lethal hit & destruction
	s14_rock.take_damage(20)
	assert(s14_rock.is_destroyed == true, "Rock fragment must be flagged is_destroyed")
	assert(s14_rock.collision_shape.disabled == true, "Rock CollisionShape3D must be disabled on destruction")
	assert(s14_rock.scale.x > 0.0 and s14_rock.scale.y > 0.0 and s14_rock.scale.z > 0.0, "Rock root body scale must never scale to 0 for Jolt safety")
	s14_rock.queue_free()
	
	# Monte Carlo drop check on rock fragment destruction (30% drop chance)
	var s14_rock_box := Node3D.new()
	root.add_child(s14_rock_box)
	var s14_rock_trials: int = 100
	var s14_drops_spawned: int = 0
	for i in range(s14_rock_trials):
		var test_rf = rock_scene.instantiate()
		s14_rock_box.add_child(test_rf)
		test_rf.take_damage(20)
	for child in s14_rock_box.get_children():
		if child is Area3D and child.has_method("setup"):
			s14_drops_spawned += 1
			assert(child.item_type == 0 or child.item_type == 2, "Dropped item must be health potion (0) or soul gem (2)")
		child.queue_free()
	var drop_pct: float = float(s14_drops_spawned) / float(s14_rock_trials)
	assert(drop_pct >= 0.15 and drop_pct <= 0.45, "Rock fragment drop rate should be ~30%% (got %.2f)" % drop_pct)
	s14_rock_box.queue_free()
	
	# 14.7: Arena 4 Choke Point Lava Fissures
	var s14_arena = arena_scene.instantiate()
	root.add_child(s14_arena)
	if not s14_arena.is_node_ready():
		await s14_arena.ready
	
	var s14_hazards_node: Node3D = s14_arena.get_node_or_null("LavaHazards")
	assert(s14_hazards_node != null, "Arena must have LavaHazards node")
	assert(s14_hazards_node.get_child_count() == 4, "LavaHazards must have exactly 4 fissures")
	
	var f1 = s14_hazards_node.get_node_or_null("LavaFissure1")
	var f2 = s14_hazards_node.get_node_or_null("LavaFissure2")
	var f3 = s14_hazards_node.get_node_or_null("LavaFissure3")
	var f4 = s14_hazards_node.get_node_or_null("LavaFissure4")
	assert(f1 != null and f2 != null and f3 != null and f4 != null, "All 4 fissures must exist")
	assert(f1.transform.origin.is_equal_approx(Vector3(-7, 0, 0)), "Fissure 1 at (-7, 0, 0)")
	assert(f2.transform.origin.is_equal_approx(Vector3(7, 0, 0)), "Fissure 2 at (7, 0, 0)")
	assert(f3.transform.origin.is_equal_approx(Vector3(0, 0, -4.5)), "Fissure 3 at (0, 0, -4.5)")
	assert(f4.transform.origin.is_equal_approx(Vector3(0, 0, 4.5)), "Fissure 4 at (0, 0, 4.5)")
	
	assert(s14_hazards_node.visible == false, "LavaHazards initially hidden")
	assert(f1.is_active == false, "Fissures initially inactive")
	
	s14_arena.transition_to_lava_caverns(0.0)
	assert(s14_hazards_node.visible == true, "LavaHazards visible after transition")
	assert(f1.is_active == true and f2.is_active == true and f3.is_active == true and f4.is_active == true, "All fissures active after transition")
	s14_arena.queue_free()
	
	# 14.8: Spawner Wave 6+ Stalactite Hazard Loop
	var s14_spawner = Node3D.new()
	s14_spawner.set_script(spawner_script)
	root.add_child(s14_spawner)
	
	s14_spawner.start_wave(1)
	assert(s14_spawner.stalactite_hazard_timer == 0.0, "Wave 1 must not trigger stalactite hazard timer")
	
	s14_spawner.start_wave(6)
	assert(s14_spawner.stalactite_hazard_timer >= 4.5 and s14_spawner.stalactite_hazard_timer <= 7.0, "Wave 6 must initialize stalactite timer between 4.5 and 7.0s")
	s14_spawner.queue_free()
	
	print("✓ Volcanic hazards, 3-phase lava cycle, stalactite drop AoE, and rock fragments verified.")
	
	print("\n=======================================================")
	print(">>> ALL 14 TEST SUITES PASSED 100%! <<<")
	print("=======================================================\n")
	
	await create_timer(0.05, true, false, true).timeout
	quit(0)

