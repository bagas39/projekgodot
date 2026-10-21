extends Node3D

enum State {
	DORMANT = 0,
	TELEGRAPH = 1,
	ERUPTING = 2
}

# Also support BUBBLING as alias to TELEGRAPH in State enum for test compatibility
const BUBBLING: int = 1

signal state_changed(new_state: State)

@export var damage_per_tick: int = 15
@export var tick_interval: float = 0.35
@export var telegraph_duration: float = 1.2
@export var erupting_duration: float = 1.5
@export var dormant_duration_min: float = 2.5
@export var dormant_duration_max: float = 3.5
@export var auto_start: bool = true
@export var is_active: bool = true

# Compatibility accessors
var erupt_duration: float:
	get: return erupting_duration
	set(val): erupting_duration = val

var damage: int:
	get: return damage_per_tick
	set(val): damage_per_tick = val

var damage_interval: float:
	get: return tick_interval
	set(val): tick_interval = val

var current_state: State = State.DORMANT
var state_timer: float = 0.0
var damage_tick_timer: float = 0.0

@onready var lava_surface: MeshInstance3D = $LavaSurface
@onready var warning_light: OmniLight3D = $WarningLight
@onready var telegraph_light: OmniLight3D = $WarningLight
@onready var bubbling_particles: GPUParticles3D = $BubblingParticles
@onready var eruption_particles: GPUParticles3D = $EruptionParticles
@onready var damage_area: Area3D = $DamageArea

func _ready() -> void:
	if not is_active:
		visible = false
		_enter_dormant()
	elif auto_start:
		_enter_dormant()

func activate() -> void:
	is_active = true
	visible = true
	_enter_dormant()

func deactivate() -> void:
	is_active = false
	visible = false
	_enter_dormant()

func _process(delta: float) -> void:
	if not is_active:
		return
	
	state_timer -= delta
	
	match current_state:
		State.DORMANT:
			if state_timer <= 0.0:
				_enter_telegraph()
		State.TELEGRAPH:
			if is_instance_valid(lava_surface):
				lava_surface.position.y = 0.02 + sin(state_timer * 25.0) * 0.015
			if state_timer <= 0.0:
				_enter_erupting()
		State.ERUPTING:
			damage_tick_timer -= delta
			if damage_tick_timer <= 0.0:
				damage_tick_timer = tick_interval
				_deal_damage()
			if state_timer <= 0.0:
				_enter_dormant()

func _enter_dormant() -> void:
	current_state = State.DORMANT
	state_timer = randf_range(dormant_duration_min, dormant_duration_max)
	if is_instance_valid(warning_light):
		warning_light.visible = false
	if is_instance_valid(bubbling_particles):
		bubbling_particles.emitting = false
	if is_instance_valid(eruption_particles):
		eruption_particles.emitting = false
	if is_instance_valid(lava_surface):
		lava_surface.position.y = 0.0
	state_changed.emit(current_state)

func _enter_telegraph() -> void:
	current_state = State.TELEGRAPH
	state_timer = telegraph_duration
	if is_instance_valid(warning_light):
		warning_light.visible = true
		warning_light.light_color = Color(1.0, 0.72, 0.12, 1.0)
		warning_light.light_energy = 2.5
		warning_light.omni_range = 4.0
	if is_instance_valid(bubbling_particles):
		bubbling_particles.emitting = true
	
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_lava_bubble"):
		audio_mgr.play_lava_bubble()
	state_changed.emit(current_state)

func _enter_bubbling() -> void:
	_enter_telegraph()

func _enter_erupting() -> void:
	current_state = State.ERUPTING
	state_timer = erupting_duration
	damage_tick_timer = tick_interval
	if is_instance_valid(warning_light):
		warning_light.visible = true
		warning_light.light_color = Color(1.0, 0.25, 0.05, 1.0)
		warning_light.light_energy = 4.8
		warning_light.omni_range = 5.5
	if is_instance_valid(bubbling_particles):
		bubbling_particles.emitting = false
	if is_instance_valid(eruption_particles):
		eruption_particles.emitting = true
	if is_instance_valid(lava_surface):
		lava_surface.position.y = 0.15
	
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_lava_erupt"):
		audio_mgr.play_lava_erupt()
	
	_deal_damage()
	state_changed.emit(current_state)

func _deal_damage() -> void:
	if not is_instance_valid(damage_area):
		return
	var bodies := damage_area.get_overlapping_bodies()
	for body in bodies:
		if is_instance_valid(body):
			_deal_damage_to_target(body)

func _deal_damage_to_target(target: Variant) -> void:
	if is_instance_valid(target) and target.has_method("take_damage"):
		target.take_damage(damage_per_tick, global_position)
