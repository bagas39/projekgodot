extends Area3D

@export var damage: int = 15
@export var orbit_radius: float = 2.2
@export var orbit_speed: float = 3.5

var current_angle: float = 0.0
var parent_target: Node3D = null

const HIT_VFX = preload("res://src/combat/hit_vfx.tscn")

func setup(target: Node3D, initial_angle: float = 0.0) -> void:
	parent_target = target
	current_angle = initial_angle

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(parent_target):
		queue_free()
		return
	
	current_angle += orbit_speed * delta
	var offset := Vector3(cos(current_angle) * orbit_radius, 0.8, sin(current_angle) * orbit_radius)
	global_position = parent_target.global_position + offset

func _on_body_entered(body: Node3D) -> void:
	if is_instance_valid(body) and body.has_method("take_damage") and body != parent_target:
		var hit_pos := body.global_position
		body.take_damage(damage, global_position)
		var parent := get_parent()
		if parent:
			var vfx := HIT_VFX.instantiate() as Node3D
			parent.add_child(vfx)
			vfx.global_position = hit_pos + Vector3(0, 0.6, 0)
