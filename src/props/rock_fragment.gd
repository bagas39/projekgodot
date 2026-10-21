extends StaticBody3D

@export var max_health: int = 20
var current_health: int
var is_destroyed: bool = false

@onready var visual_mesh: MeshInstance3D = $VisualMesh
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

const HIT_VFX = preload("res://src/combat/hit_vfx.tscn")
const PICKUP_SCENE = preload("res://src/props/pickup_item.tscn")

func _ready() -> void:
	current_health = max_health
	add_to_group("destructibles")
	add_to_group("rock_fragments")

func take_damage(amount: int, _from_pos: Variant = null, _is_crit: bool = false) -> void:
	if is_destroyed:
		return
	
	current_health = max(0, current_health - amount)
	
	# Squash impact on visual mesh only to preserve Jolt body transform
	if is_inside_tree() and is_instance_valid(visual_mesh):
		var tween := create_tween()
		visual_mesh.scale = Vector3(1.25, 0.75, 1.25)
		tween.tween_property(visual_mesh, "scale", Vector3.ONE, 0.12)
	
	if current_health <= 0:
		destroy()

func destroy() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	
	# Disable collision deferred to prevent Jolt queries against freeing body
	if is_instance_valid(collision_shape):
		collision_shape.disabled = true
		collision_shape.set_deferred("disabled", true)
	
	# Audio hit
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if not audio_mgr and is_inside_tree():
		audio_mgr = get_tree().root.get_node_or_null("AudioManager")
	if audio_mgr and audio_mgr.has_method("play_hit"):
		audio_mgr.play_hit()
	
	# Hit VFX debris
	var parent := get_parent()
	if parent:
		var vfx := HIT_VFX.instantiate() as Node3D
		parent.add_child(vfx)
		vfx.global_position = global_position + Vector3(0, 0.35, 0)
		
		# 30% drop chance for Soul Gem or Potion
		if randf() < 0.30:
			var pickup := PICKUP_SCENE.instantiate()
			parent.add_child(pickup)
			var is_gem: bool = randf() < 0.70
			pickup.setup(2 if is_gem else 0, global_position + Vector3(0, 0.35, 0))
	
	# Safe visual shrink (never scale root body or collision shape to 0)
	if is_inside_tree() and is_instance_valid(visual_mesh):
		var tween := create_tween()
		tween.tween_property(visual_mesh, "scale", Vector3(0.01, 0.01, 0.01), 0.10)
		tween.chain().tween_callback(queue_free)
	else:
		queue_free()
