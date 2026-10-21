extends Node3D

@export var damage: int = 15
@export var active_duration: float = 1.0
@export var warning_duration: float = 0.8
@export var cooldown_duration: float = 2.2

enum State { INACTIVE, WARNING, ACTIVE }
var current_state: State = State.INACTIVE
var state_timer: float = 0.0
var damage_interval_timer: float = 0.0

@onready var spikes_mesh: Node3D = $SpikesRoot
@onready var plate_mesh: MeshInstance3D = $BasePlate
@onready var damage_area: Area3D = $DamageArea
@onready var warning_light: OmniLight3D = $WarningLight

func _ready() -> void:
	current_state = State.INACTIVE
	state_timer = cooldown_duration + randf_range(0.0, 1.0)
	spikes_mesh.position.y = -0.4
	warning_light.visible = false

func _process(delta: float) -> void:
	state_timer -= delta
	
	match current_state:
		State.INACTIVE:
			if state_timer <= 0.0:
				_enter_warning()
		State.WARNING:
			# Telegraph shake
			plate_mesh.position.x = randf_range(-0.04, 0.04)
			if state_timer <= 0.0:
				_enter_active()
		State.ACTIVE:
			damage_interval_timer -= delta
			if damage_interval_timer <= 0.0:
				damage_interval_timer = 0.35
				_deal_damage()
			if state_timer <= 0.0:
				_enter_inactive()

func _enter_warning() -> void:
	current_state = State.WARNING
	state_timer = warning_duration
	warning_light.visible = true
	warning_light.light_color = Color(1.0, 0.8, 0.1, 1.0) # Yellow warning
	warning_light.light_energy = 2.0

func _enter_active() -> void:
	current_state = State.ACTIVE
	state_timer = active_duration
	damage_interval_timer = 0.0
	plate_mesh.position.x = 0.0
	warning_light.light_color = Color(1.0, 0.2, 0.1, 1.0) # Red danger
	warning_light.light_energy = 3.5
	
	# Spikes thrust up
	if is_inside_tree() and is_instance_valid(spikes_mesh):
		var tween := create_tween()
		tween.tween_property(spikes_mesh, "position:y", 0.0, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	if AudioManager and AudioManager.has_method("play_slash"):
		AudioManager.play_slash()

func _enter_inactive() -> void:
	current_state = State.INACTIVE
	state_timer = cooldown_duration
	warning_light.visible = false
	
	# Retract spikes
	if is_inside_tree() and is_instance_valid(spikes_mesh):
		var tween := create_tween()
		tween.tween_property(spikes_mesh, "position:y", -0.4, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

func _deal_damage() -> void:
	if not is_instance_valid(damage_area):
		return
	var bodies := damage_area.get_overlapping_bodies()
	for body in bodies:
		if is_instance_valid(body) and body.has_method("take_damage"):
			body.take_damage(damage, global_position)
