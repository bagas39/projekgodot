extends StaticBody3D

@export var max_health: int = 15
@export var blast_damage: int = 70
@export var blast_radius: float = 4.5

var current_health: int
var is_exploding: bool = false

@onready var visual_mesh: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var blast_area: Area3D = $BlastArea

const HIT_VFX = preload("res://src/combat/hit_vfx.tscn")

func _ready() -> void:
	current_health = max_health

func take_damage(amount: int, _from_pos: Variant = null, _is_crit: bool = false) -> void:
	if is_exploding:
		return
	
	current_health -= amount
	if current_health <= 0:
		start_explosion()

func start_explosion() -> void:
	if is_exploding:
		return
	is_exploding = true
	if is_instance_valid(collision_shape):
		collision_shape.set_deferred("disabled", true)
	
	# Fuse flashing
	if is_inside_tree() and is_instance_valid(visual_mesh):
		var tween := create_tween()
		tween.tween_property(visual_mesh, "scale", Vector3(1.3, 1.3, 1.3), 0.25).set_trans(Tween.TRANS_BOUNCE)
		tween.chain().tween_callback(detonate)
	else:
		detonate()

func detonate() -> void:
	if AudioManager and AudioManager.has_method("play_boss_slam"):
		AudioManager.play_boss_slam()
	
	var parent_node := get_parent()
	if parent_node:
		# Spawn big explosion particles
		for i in range(3):
			var vfx := HIT_VFX.instantiate() as Node3D
			parent_node.add_child(vfx)
			vfx.global_position = global_position + Vector3(randf_range(-0.5, 0.5), randf_range(0.2, 0.8), randf_range(-0.5, 0.5))
	
	# Damage all overlapping bodies in blast radius
	if is_instance_valid(blast_area):
		var targets := blast_area.get_overlapping_bodies()
		for body in targets:
			if not is_instance_valid(body) or body == self:
				continue
			if body.is_in_group("enemies") and body.has_method("take_damage"):
				body.take_damage(blast_damage, global_position)
			elif body.is_in_group("player") and body.has_method("take_damage"):
				body.take_damage(18, global_position) # Player takes reduced blast damage
			elif body.is_in_group("destructibles") and body.has_method("take_damage"):
				body.take_damage(blast_damage, global_position)
	
	# Trigger camera shake on player
	var player = get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	if is_instance_valid(player):
		if player.has_method("add_camera_shake"):
			player.add_camera_shake(0.6)
		elif player.has_method("trigger_camera_shake"):
			player.trigger_camera_shake(0.6)
	
	queue_free()
