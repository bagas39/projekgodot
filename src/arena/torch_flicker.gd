extends OmniLight3D

@export var base_energy: float = 3.0
@export var flicker_intensity: float = 0.45
@export var flicker_speed: float = 8.0

var flame_mesh: Node3D = null
var time_passed: float = 0.0
var phase_offset: float = 0.0
var speed_mult: float = 1.0

func _ready() -> void:
	phase_offset = randf() * 100.0
	speed_mult = randf_range(0.85, 1.15)
	if get_parent():
		flame_mesh = get_parent().get_node_or_null("Flame")

func _process(delta: float) -> void:
	time_passed += delta * flicker_speed * speed_mult
	var n := sin(time_passed + phase_offset) * 0.5 + sin((time_passed * 2.3) + (phase_offset * 1.7)) * 0.35 + sin((time_passed * 5.1) + (phase_offset * 3.1)) * 0.15
	light_energy = max(0.5, base_energy + (n * flicker_intensity))
	if is_instance_valid(flame_mesh):
		var s := 1.0 + (n * 0.12)
		flame_mesh.scale = Vector3(s, s * 1.1, s)
