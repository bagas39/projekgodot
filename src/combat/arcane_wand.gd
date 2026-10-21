extends Node3D
class_name ArcaneWand

@export var base_damage: int = 22
@export var attack_cooldown: float = 1.2
@export var targeting_range: float = 14.0
@export var projectile_count: int = 1
@export var pierce_count: int = 0
@export var projectile_scene: PackedScene = preload("res://src/combat/arcane_projectile.tscn")

var cooldown_timer: float = 0.0
var player: Node3D = null

var can_fire: bool:
	get:
		return cooldown_timer <= 0.0

func _ready() -> void:
	_resolve_player()

func _resolve_player() -> void:
	if is_instance_valid(player):
		return
	var p := get_parent()
	if p and p.is_in_group("player"):
		player = p
	elif p and p.get_parent() and p.get_parent().is_in_group("player"):
		player = p.get_parent()
	else:
		var tree := get_tree()
		if tree:
			player = tree.get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		_resolve_player()
	
	if is_instance_valid(player) and ("is_dead" in player and player.is_dead or "current_health" in player and player.current_health <= 0):
		set_physics_process(false)
		return
	
	if cooldown_timer > 0.0:
		cooldown_timer -= delta
	
	if cooldown_timer <= 0.0:
		var target := get_nearest_target()
		if target != null:
			fire()

func get_total_damage() -> int:
	var bonus: int = 0
	if is_instance_valid(player) and "bonus_damage" in player:
		bonus = int(float(player.bonus_damage) * 0.5)
	return base_damage + bonus

func get_targets(count: int = 1) -> Array[Node3D]:
	var tree := get_tree()
	if not tree:
		return []
	var enemies := tree.get_nodes_in_group("enemies")
	var candidates: Array[Dictionary] = []
	var max_dist_sq: float = targeting_range * targeting_range
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not (enemy is Node3D) or not enemy.is_inside_tree():
			continue
		var is_dead_val = enemy.get("is_dead")
		if ("is_dead" in enemy and enemy.is_dead) or (is_dead_val != null and bool(is_dead_val)):
			continue
		var hp_val = enemy.get("current_health")
		if ("current_health" in enemy and enemy.current_health <= 0) or (hp_val != null and int(hp_val) <= 0):
			continue
		var dist_sq: float = global_position.distance_squared_to(enemy.global_position)
		if dist_sq <= max_dist_sq:
			candidates.append({"enemy": enemy, "dist_sq": dist_sq})
	
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["dist_sq"] < b["dist_sq"]
	)
	
	var result: Array[Node3D] = []
	for i in range(min(count, candidates.size())):
		result.append(candidates[i]["enemy"])
	return result

func get_nearest_target() -> Node3D:
	var targets := get_targets(1)
	return targets[0] if targets.size() > 0 else null

func fire() -> void:
	var targets := get_targets(projectile_count)
	if targets.is_empty():
		return
	
	cooldown_timer = attack_cooldown
	
	var primary_target: Node3D = targets[0]
	var target_aim_pos: Vector3 = primary_target.global_position + Vector3(0.0, 0.6, 0.0)
	var spawn_pos: Vector3 = global_position
	var crystal := get_node_or_null("VisualModel/FocusCrystal")
	if crystal and crystal is Node3D:
		spawn_pos = crystal.global_position
	
	var base_dir: Vector3 = (target_aim_pos - spawn_pos).normalized()
	if base_dir.length_squared() < 0.001:
		base_dir = -global_transform.basis.z if global_transform.basis.z.length_squared() > 0.001 else Vector3.FORWARD
	
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_cast"):
		audio_mgr.play_cast()
	
	var spawn_root: Node = null
	if is_instance_valid(player) and player.get_parent():
		spawn_root = player.get_parent()
	elif get_tree() and get_tree().current_scene:
		spawn_root = get_tree().current_scene
	elif get_parent():
		spawn_root = get_parent()
	else:
		spawn_root = self
	
	var fan_step: float = deg_to_rad(16.0)
	var dmg: int = get_total_damage()
	
	for i in range(projectile_count):
		var proj_target: Node3D = targets[i % targets.size()]
		var angle_offset: float = (float(i) - float(projectile_count - 1) * 0.5) * fan_step
		var proj_dir: Vector3 = base_dir.rotated(Vector3.UP, angle_offset).normalized()
		
		var proj = projectile_scene.instantiate()
		spawn_root.add_child(proj)
		proj.global_position = spawn_pos
		proj.setup(proj_target, dmg, proj_dir, pierce_count)

func apply_fire_rate_upgrade(reduction_pct: float = 0.25) -> void:
	attack_cooldown = maxf(0.20, attack_cooldown * (1.0 - reduction_pct))

func apply_multishot_upgrade(extra_projectiles: int = 1) -> void:
	projectile_count += extra_projectiles

func apply_pierce_upgrade(extra_pierce: int = 1) -> void:
	pierce_count += extra_pierce
