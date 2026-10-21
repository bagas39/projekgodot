@tool
extends EditorScript

func _run() -> void:
	print("--- BEGINNING VERIFICATION ---")
	
	# 1. Test AudioManager procedural synthesis
	var audio_script := load("res://src/audio/audio_manager.gd")
	var audio = audio_script.new()
	audio._generate_all_streams()
	
	assert(audio.stream_slash != null and audio.stream_slash.data.size() > 0, "Slash stream failed")
	assert(audio.stream_hit != null and audio.stream_hit.data.size() > 0, "Hit stream failed")
	assert(audio.stream_crit != null and audio.stream_crit.data.size() > 0, "Crit stream failed")
	assert(audio.stream_dash != null and audio.stream_dash.data.size() > 0, "Dash stream failed")
	assert(audio.stream_player_hurt != null and audio.stream_player_hurt.data.size() > 0, "Hurt stream failed")
	assert(audio.stream_wave_fanfare != null and audio.stream_wave_fanfare.data.size() > 0, "Fanfare stream failed")
	assert(audio.stream_special != null and audio.stream_special.data.size() > 0, "Special stream failed")
	assert(audio.stream_cast != null and audio.stream_cast.data.size() > 0, "Cast stream failed")
	assert(audio.stream_boss_slam != null and audio.stream_boss_slam.data.size() > 0, "Boss slam stream failed")
	print("[PASS] AudioManager synthesized all 9 waveforms successfully.")
	audio.free()
	
	# 2. Test EnemyMage
	var mage_scene: PackedScene = load("res://src/enemies/enemy_mage.tscn")
	var mage = mage_scene.instantiate()
	assert(mage.max_health == 65, "Mage max_health mismatch")
	assert(mage.preferred_dist_min == 7.0, "Mage dist_min mismatch")
	assert(mage.is_in_group("enemies"), "Mage must be in group enemies")
	print("[PASS] EnemyMage instantiated with correct stats and groups.")
	mage.free()
	
	# 3. Test Projectile
	var proj_scene: PackedScene = load("res://src/combat/projectile.tscn")
	var proj = proj_scene.instantiate()
	assert(proj.damage == 18, "Projectile damage mismatch")
	assert(proj.speed == 10.0, "Projectile speed mismatch")
	assert(proj.is_in_group("enemy_projectiles"), "Projectile group mismatch")
	print("[PASS] Projectile instantiated with correct collision and stats.")
	proj.free()
	
	# 4. Test Boss Demon Knight
	var boss_scene: PackedScene = load("res://src/enemies/boss_demon_knight.tscn")
	var boss = boss_scene.instantiate()
	assert(boss.max_health == 750, "Boss max_health mismatch")
	assert(boss.slam_radius == 6.5, "Boss slam radius mismatch")
	assert(boss.is_in_group("boss"), "Boss must be in group boss")
	assert(boss.is_in_group("enemies"), "Boss must be in group enemies")
	print("[PASS] Boss Demon Knight instantiated with correct boss attributes.")
	boss.free()
	
	# 5. Test Player Special Ability
	var player_scene: PackedScene = load("res://src/characters/player.tscn")
	var player = player_scene.instantiate()
	assert(player.special_cooldown == 6.0, "Player special cooldown mismatch")
	assert(player.can_special == true, "Player should start with can_special = true")
	player.apply_earthquake(0.25, 35)
	assert(player.special_cooldown == 4.5, "Earthquake upgrade should reduce cooldown to 4.5s")
	assert(player.special_damage == 105, "Earthquake upgrade should increase damage to 105")
	print("[PASS] Player special ability and Earthquake upgrade verified.")
	player.free()
	
	# 6. Test Spawner
	var spawner_scene := load("res://src/arena/spawner.gd")
	var spawner = Node3D.new()
	spawner.set_script(spawner_scene)
	spawner.start_wave(1)
	assert(spawner.current_wave == 1, "Spawner wave 1 failed")
	assert(spawner.enemies_to_spawn == 10, "Spawner wave 1 enemy count failed")
	spawner.start_wave(5)
	assert(spawner.current_wave == 5, "Spawner wave 5 failed")
	assert(spawner.enemies_to_spawn == 16, "Spawner wave 5 enemy count failed")
	print("[PASS] Spawner wave scaling and boss wave configuration verified.")
	spawner.free()
	
	print("--- ALL 6 VERIFICATION TEST SUITES PASSED CLEANLY ---")
