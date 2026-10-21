extends Area3D

@export var speed: float = 10.0
@export var damage: int = 18
@export var lifetime: float = 4.0

var direction: Vector3 = Vector3.FORWARD
var _is_destroyed: bool = false
const HIT_VFX = preload("res://src/combat/hit_vfx.tscn")

func _ready() -> void:
	add_to_group("enemy_projectiles")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# Gentle spinning effect for visual juice
	var mesh := get_node_or_null("VisualRoot")
	if mesh:
		var tween := create_tween().set_loops()
		tween.tween_property(mesh, "rotation:y", TAU, 1.2).as_relative()
	
	if direction.length_squared() > 0.001:
		look_at(global_position + direction, Vector3.UP)

func setup(dir: Vector3, dmg: int = 18, spd: float = 10.0) -> void:
	direction = dir.normalized()
	direction.y = 0.0 # Stay on flat plane
	damage = dmg
	speed = spd
	if is_inside_tree() and direction.length_squared() > 0.001:
		look_at(global_position + direction, Vector3.UP)

func _physics_process(delta: float) -> void:
	if _is_destroyed:
		return
	
	global_position += direction * speed * delta
	lifetime -= delta
	
	# Arena boundaries clamp/despawn
	if abs(global_position.x) > 22.0 or abs(global_position.z) > 22.0 or lifetime <= 0.0:
		_destroy(false)

func _on_body_entered(body: Node3D) -> void:
	if _is_destroyed:
		return
	if body.is_in_group("player"):
		_hit_player(body)
	elif body is StaticBody3D:
		_destroy(true)

func _on_area_entered(area: Area3D) -> void:
	if _is_destroyed:
		return
	var parent := area.get_parent()
	if parent and parent.is_in_group("player"):
		_hit_player(parent)

func _hit_player(p: Node3D) -> void:
	if _is_destroyed:
		return
	
	if "is_dashing" in p and p.is_dashing:
		# Player dodged with invulnerable dash!
		_destroy(false)
		return
	
	if is_instance_valid(p) and p.has_method("take_damage"):
		p.take_damage(damage, global_position)
	
	_destroy(true)

func _destroy(spawn_vfx: bool = true) -> void:
	if _is_destroyed:
		return
	_is_destroyed = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	
	var mesh := get_node_or_null("VisualRoot")
	if mesh:
		mesh.visible = false
	
	if spawn_vfx:
		var parent := get_parent()
		if parent:
			var vfx := HIT_VFX.instantiate() as Node3D
			parent.add_child(vfx)
			vfx.global_position = global_position
	queue_free()
