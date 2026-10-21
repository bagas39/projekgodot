extends StaticBody3D

@export var max_health: int = 25
var current_health: int
var is_destroyed: bool = false

@onready var visual_mesh: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

const PICKUP_SCENE = preload("res://src/props/pickup_item.tscn")
const HIT_VFX = preload("res://src/combat/hit_vfx.tscn")

func _ready() -> void:
	current_health = max_health

func take_damage(amount: int, _from_pos: Variant = null, _is_crit: bool = false) -> void:
	if is_destroyed:
		return
	
	current_health -= amount
	
	# Squash impact
	if is_inside_tree() and is_instance_valid(visual_mesh):
		var tween := create_tween()
		visual_mesh.scale = Vector3(1.15, 0.85, 1.15)
		tween.tween_property(visual_mesh, "scale", Vector3.ONE, 0.12)
	
	if current_health <= 0:
		destroy()

func destroy() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	if is_instance_valid(collision_shape):
		collision_shape.set_deferred("disabled", true)
	
	# Play sound
	if AudioManager and AudioManager.has_method("play_hit"):
		AudioManager.play_hit()
	
	# Spawn hit VFX
	var parent_node := get_parent()
	if parent_node:
		var vfx := HIT_VFX.instantiate() as Node3D
		parent_node.add_child(vfx)
		vfx.global_position = global_position + Vector3(0, 0.5, 0)
		
		# Drop pickup item (70% gem, 30% health)
		var pickup := PICKUP_SCENE.instantiate()
		parent_node.add_child(pickup)
		var is_heal := randf() < 0.35
		pickup.setup(0 if is_heal else 1, global_position + Vector3(0, 0.5, 0))
	
	# Fade and free
	if is_inside_tree() and is_instance_valid(visual_mesh):
		var tween := create_tween()
		tween.tween_property(visual_mesh, "scale", Vector3.ZERO, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(queue_free)
	else:
		queue_free()
