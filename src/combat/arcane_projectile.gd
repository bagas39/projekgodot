extends Area3D
class_name ArcaneProjectile

@export var speed: float = 13.0
@export var damage: int = 22
@export var turn_speed: float = 9.0
@export var lifetime: float = 3.5
@export var pierce_count: int = 0:
	set(val):
		pierce_count = val
		pierce_remaining = val

var pierce_remaining: int = 0
var target: Node3D = null
var current_direction: Vector3 = Vector3.FORWARD
var _hit_entities: Array[Node3D] = []
var _is_destroyed: bool = false

const HIT_VFX = preload("res://src/combat/hit_vfx.tscn")

func _ready() -> void:
	add_to_group("player_projectiles")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	if pierce_remaining == 0 and pierce_count > 0:
		pierce_remaining = pierce_count
	
	# Gentle spinning effect for visual juice
	var visual := get_node_or_null("VisualRoot")
	if visual:
		var tween := create_tween().set_loops()
		tween.tween_property(visual, "rotation:y", TAU, 0.8).as_relative()
	
	if current_direction.length_squared() > 0.001:
		_align_rotation(current_direction)

func setup(init_target: Variant = null, dmg: int = 22, init_dir: Vector3 = Vector3.FORWARD, pierces: int = 0) -> void:
	if is_instance_valid(init_target) and init_target is Node3D:
		target = init_target as Node3D
	else:
		target = null
	damage = dmg
	pierce_count = pierces
	pierce_remaining = pierces
	if init_dir.length_squared() > 0.001:
		current_direction = init_dir.normalized()
	if is_inside_tree() and current_direction.length_squared() > 0.001:
		_align_rotation(current_direction)

func _physics_process(delta: float) -> void:
	if _is_destroyed:
		return
	
	lifetime -= delta
	if lifetime <= 0.0 or abs(global_position.x) > 30.0 or abs(global_position.z) > 30.0:
		_destroy(false)
		return
	
	# Dynamic re-acquisition if target becomes invalid or dead
	if not is_instance_valid(target) or not _is_valid_target(target):
		target = _find_nearest_target()
	
	if is_instance_valid(target):
		var target_pos: Vector3 = target.global_position + Vector3(0.0, 0.6, 0.0)
		var to_target: Vector3 = target_pos - global_position
		if to_target.length_squared() > 0.0001:
			var desired_dir: Vector3 = to_target.normalized()
			var angle: float = current_direction.angle_to(desired_dir)
			if angle > 0.001:
				var t: float = clampf((turn_speed * delta) / angle, 0.0, 1.0)
				current_direction = current_direction.slerp(desired_dir, t).normalized()
			else:
				current_direction = desired_dir
	
	global_position += current_direction * speed * delta
	if current_direction.length_squared() > 0.001:
		_align_rotation(current_direction)

func _align_rotation(dir: Vector3) -> void:
	if dir.length_squared() <= 0.001:
		return
	var up_vec: Vector3 = Vector3.UP if abs(dir.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
	look_at(global_position + dir, up_vec)

func _is_valid_target(t: Variant) -> bool:
	if not is_instance_valid(t):
		return false
	if not (t is Node3D) or not (t as Node3D).is_inside_tree():
		return false
	var is_dead_val = t.get("is_dead")
	if ("is_dead" in t and t.is_dead) or (is_dead_val != null and bool(is_dead_val)):
		return false
	var hp_val = t.get("current_health")
	if ("current_health" in t and t.current_health <= 0) or (hp_val != null and int(hp_val) <= 0):
		return false
	if t in _hit_entities:
		return false
	return true

func _find_nearest_target() -> Node3D:
	var tree := get_tree()
	if not tree:
		return null
	var enemies := tree.get_nodes_in_group("enemies")
	var nearest: Node3D = null
	var min_dist_sq: float = INF
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy is Node3D and _is_valid_target(enemy):
			var dist_sq: float = global_position.distance_squared_to(enemy.global_position)
			if dist_sq < min_dist_sq:
				min_dist_sq = dist_sq
				nearest = enemy
	return nearest

func _on_body_entered(body: Node3D) -> void:
	_handle_hit(body)

func _on_area_entered(area: Area3D) -> void:
	var parent := area.get_parent()
	if parent is Node3D and (parent.is_in_group("enemies") or parent.is_in_group("destructibles")):
		_handle_hit(parent)
	elif area.is_in_group("enemies") or area.is_in_group("destructibles"):
		_handle_hit(area)

func _hit_entity(entity: Node3D) -> void:
	_handle_hit(entity)

func _handle_hit(entity: Node3D) -> void:
	if _is_destroyed or not is_instance_valid(entity):
		return
	if entity in _hit_entities:
		return
	if entity.is_in_group("player"):
		return
	
	var is_enemy := entity.is_in_group("enemies")
	var is_destructible := entity.is_in_group("destructibles")
	if not is_enemy and not is_destructible and not entity.has_method("take_damage"):
		return
	
	_hit_entities.append(entity)
	
	if entity.has_method("take_damage"):
		entity.take_damage(damage, global_position)
	
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_hit"):
		audio_mgr.play_hit()
	
	var parent := get_parent()
	if parent:
		var vfx := HIT_VFX.instantiate() as Node3D
		parent.add_child(vfx)
		vfx.global_position = global_position
	
	if pierce_remaining > 0:
		pierce_remaining -= 1
		target = _find_nearest_target()
	else:
		_destroy(false)

func _destroy(spawn_vfx: bool = true) -> void:
	if _is_destroyed:
		return
	_is_destroyed = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	
	var visual := get_node_or_null("VisualRoot")
	if visual:
		visual.visible = false
	var light := get_node_or_null("OmniLight3D")
	if light:
		light.visible = false
	
	if spawn_vfx:
		var parent := get_parent()
		if parent:
			var vfx := HIT_VFX.instantiate() as Node3D
			parent.add_child(vfx)
			vfx.global_position = global_position
	
	queue_free()
