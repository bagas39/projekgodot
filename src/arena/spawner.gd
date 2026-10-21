extends Node3D

signal wave_started(wave: int)
signal wave_cleared(wave: int)

@export var slime_scene: PackedScene = preload("res://src/enemies/enemy_slime.tscn")
@export var golem_scene: PackedScene = preload("res://src/enemies/enemy_golem.tscn")
@export var mage_scene: PackedScene = preload("res://src/enemies/enemy_mage.tscn")
@export var boss_scene: PackedScene = preload("res://src/enemies/boss_demon_knight.tscn")
@export var enemy_scene: PackedScene = preload("res://src/enemies/enemy_slime.tscn")
@export var stalactite_scene: PackedScene = preload("res://src/hazards/falling_stalactite.tscn")
@export var spawn_radius_min: float = 12.0
@export var spawn_radius_max: float = 18.0

var current_wave: int = 1
var enemies_to_spawn: int = 0
var enemies_alive: int = 0
var is_wave_active: bool = false
var spawn_timer: float = 0.0
var spawn_interval: float = 1.2
var stalactite_hazard_timer: float = 0.0

var player: Node3D = null

func _ready() -> void:
	call_deferred("_start_first_wave")

func _start_first_wave() -> void:
	player = get_tree().get_first_node_in_group("player")
	if not is_wave_active:
		start_wave(1)

func start_wave(wave: int) -> void:
	current_wave = wave
	enemies_alive = 0
	is_wave_active = true
	spawn_timer = 0.2
	
	# Wave Fanfare SFX
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_wave_fanfare"):
		audio_mgr.play_wave_fanfare()
	
	var is_boss_wave := (current_wave % 5 == 0)
	if is_boss_wave:
		# Boss encounter: Boss + minion escort
		enemies_to_spawn = 6 + (current_wave * 2)
		spawn_interval = 2.0
		_spawn_boss()
	else:
		enemies_to_spawn = 6 + (current_wave * 4)
		spawn_interval = max(0.4, 1.2 - (float(current_wave) * 0.08))
	
	if current_wave >= 6:
		stalactite_hazard_timer = randf_range(4.5, 7.0)
	
	wave_started.emit(current_wave)

func _process(delta: float) -> void:
	if not is_wave_active:
		return
	
	if current_wave >= 6:
		stalactite_hazard_timer -= delta
		if stalactite_hazard_timer <= 0.0:
			stalactite_hazard_timer = randf_range(4.5, 7.0)
			_spawn_stalactite_hazard()
	
	if enemies_to_spawn > 0:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			spawn_timer = spawn_interval
			_spawn_enemy()
	else:
		# Check if all enemies in group are defeated
		var enemies := get_tree().get_nodes_in_group("enemies")
		if enemies.is_empty() and enemies_to_spawn <= 0:
			_on_all_enemies_cleared()

func _spawn_stalactite_hazard() -> void:
	if not is_inside_tree() or not stalactite_scene:
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if not is_instance_valid(player):
			return
	
	var parent := get_parent()
	if not parent:
		return
	
	var spawn_pos := player.global_position + Vector3(randf_range(-5.0, 5.0), 0.0, randf_range(-5.0, 5.0))
	spawn_pos.x = clampf(spawn_pos.x, -16.0, 16.0)
	spawn_pos.z = clampf(spawn_pos.z, -16.0, 16.0)
	spawn_pos.y = 0.0
	
	var stalactite := stalactite_scene.instantiate() as Node3D
	stalactite.position = spawn_pos
	parent.add_child(stalactite)
	stalactite.global_position = spawn_pos

func _spawn_boss() -> void:
	if not boss_scene:
		return
	var parent := get_parent()
	if not parent:
		return
	var boss := boss_scene.instantiate() as CharacterBody3D
	parent.add_child(boss)
	# Position boss in northern half of arena facing south
	boss.global_position = Vector3(0.0, 0.5, -9.0)
	
	# Scale boss HP for subsequent boss cycles (Wave 10, 15, etc.)
	if current_wave > 5 and "max_health" in boss:
		var mult: float = 1.0 + (float(current_wave - 5) * 0.25)
		boss.max_health = int(float(boss.max_health) * mult)
		boss.current_health = boss.max_health

func _spawn_enemy() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if not is_instance_valid(player):
			return
	
	enemies_to_spawn -= 1
	var angle := randf() * TAU
	var dist := randf_range(spawn_radius_min, spawn_radius_max)
	var spawn_pos := player.global_position + Vector3(cos(angle) * dist, 0.5, sin(angle) * dist)
	
	# Clamp inside arena
	spawn_pos.x = clamp(spawn_pos.x, -18.0, 18.0)
	spawn_pos.z = clamp(spawn_pos.z, -18.0, 18.0)
	
	# Prevent spawning inside arena pillars
	var pillars := [
		Vector2(-10.0, -10.0),
		Vector2(10.0, -10.0),
		Vector2(-10.0, 10.0),
		Vector2(10.0, 10.0)
	]
	for pillar in pillars:
		var spawn_2d := Vector2(spawn_pos.x, spawn_pos.z)
		if spawn_2d.distance_to(pillar) < 1.8:
			var push_dir: Vector2 = (spawn_2d - pillar).normalized()
			if push_dir == Vector2.ZERO:
				push_dir = Vector2(1.0, 0.0)
			spawn_pos.x = clamp(pillar.x + push_dir.x * 2.2, -18.0, 18.0)
			spawn_pos.z = clamp(pillar.y + push_dir.y * 2.2, -18.0, 18.0)
	
	# Weighted enemy archetype selection based on current wave
	var chosen_scene: PackedScene = slime_scene if slime_scene else enemy_scene
	var roll := randf()
	
	if current_wave == 2 and golem_scene:
		if roll < 0.30:
			chosen_scene = golem_scene
		else:
			chosen_scene = slime_scene
	elif current_wave >= 3:
		var mage_chance: float = clamp(0.20 + (float(current_wave) * 0.04), 0.20, 0.35)
		var golem_chance: float = clamp(0.25 + (float(current_wave) * 0.04), 0.25, 0.35)
		
		if mage_scene and roll < mage_chance:
			chosen_scene = mage_scene
		elif golem_scene and roll < (mage_chance + golem_chance):
			chosen_scene = golem_scene
		else:
			chosen_scene = slime_scene
	
	var parent := get_parent()
	if not parent:
		return
	var enemy := chosen_scene.instantiate() as CharacterBody3D
	parent.add_child(enemy)
	enemy.global_position = spawn_pos
	
	# Scale enemy HP slightly with wave
	if current_wave > 1 and "max_health" in enemy:
		enemy.max_health = int(float(enemy.max_health) * (1.0 + (float(current_wave - 1) * 0.15)))
		enemy.current_health = enemy.max_health
	
	# Elite modifier from Wave 3 onwards (0% in Wave 1 and 2)
	if current_wave >= 3 and enemy.has_method("make_elite") and not enemy.is_in_group("boss"):
		var elite_chance: float = clamp(0.15 + (float(current_wave - 3) * 0.04), 0.15, 0.40)
		if randf() < elite_chance:
			enemy.make_elite()

func _on_all_enemies_cleared() -> void:
	is_wave_active = false
	wave_cleared.emit(current_wave)
