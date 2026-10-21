extends Node3D

enum State { TELEGRAPH, FALLING, IMPACTED }

@export var warning_duration: float = 1.0
@export var fall_duration: float = 0.20
@export var impact_radius: float = 2.5
@export var damage: int = 40
@export var ceiling_height: float = 14.0

var current_state: State = State.TELEGRAPH
var state_timer: float = 0.0
var _target_ground_pos: Vector3 = Vector3.ZERO

const ROCK_FRAGMENT_SCENE = preload("res://src/props/rock_fragment.tscn")
const ROCK_DEBRIS_VFX = preload("res://src/combat/rock_debris_vfx.tscn")

@onready var telegraph_root: Node3D = $TelegraphIndicator
@onready var warning_circle: MeshInstance3D = $TelegraphIndicator/WarningCircleMesh
@onready var warning_shadow: MeshInstance3D = $TelegraphIndicator/WarningShadowMesh
@onready var warning_light: OmniLight3D = $TelegraphIndicator/WarningLight
@onready var stalactite_mesh: MeshInstance3D = $StalactiteMesh
@onready var impact_area: Area3D = $ImpactArea

func _ready() -> void:
	current_state = State.TELEGRAPH
	state_timer = warning_duration
	_target_ground_pos = Vector3(global_position.x, 0.0, global_position.z)
	if is_instance_valid(stalactite_mesh):
		stalactite_mesh.position.y = ceiling_height
		stalactite_mesh.visible = false
	if is_instance_valid(telegraph_root):
		telegraph_root.visible = true

func _process(delta: float) -> void:
	match current_state:
		State.TELEGRAPH:
			state_timer -= delta
			var progress: float = 1.0 - clampf(state_timer / warning_duration, 0.0, 1.0)
			if is_instance_valid(warning_light):
				warning_light.light_energy = 1.8 + (progress * 2.2)
			if is_instance_valid(warning_circle):
				var pulse: float = 1.0 + 0.08 * sin(progress * TAU * 4.0)
				warning_circle.scale = Vector3(pulse, 1.0, pulse)
			
			if state_timer <= 0.0:
				_start_falling()
				
		State.FALLING:
			state_timer -= delta
			var t: float = 1.0 - clampf(state_timer / fall_duration, 0.0, 1.0)
			if is_instance_valid(stalactite_mesh):
				stalactite_mesh.position.y = lerpf(ceiling_height, 0.0, t * t)
			if state_timer <= 0.0 or (is_instance_valid(stalactite_mesh) and stalactite_mesh.position.y <= 0.0):
				_trigger_impact()

func _start_falling() -> void:
	current_state = State.FALLING
	state_timer = fall_duration
	if is_instance_valid(stalactite_mesh):
		stalactite_mesh.visible = true

func _trigger_impact() -> void:
	if current_state == State.IMPACTED:
		return
	current_state = State.IMPACTED
	_target_ground_pos = Vector3(global_position.x, 0.0, global_position.z)
	
	if is_instance_valid(telegraph_root):
		telegraph_root.visible = false
	if is_instance_valid(stalactite_mesh):
		stalactite_mesh.visible = false
	
	# 1. Audio Crash
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if not audio_mgr and is_inside_tree():
		audio_mgr = get_tree().root.get_node_or_null("AudioManager")
	if audio_mgr and audio_mgr.has_method("play_rock_crash"):
		audio_mgr.play_rock_crash()
	elif audio_mgr and audio_mgr.has_method("play_stalactite_impact"):
		audio_mgr.play_stalactite_impact()
	
	# 2. Camera Shake
	var player: Node = null
	if is_inside_tree():
		player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and player.has_method("add_camera_shake"):
		player.add_camera_shake(0.50)
	
	# 3. Apply Impact Damage (Area3D + deterministic distance fallback)
	_apply_impact_damage()
	
	# 4. Spawn VFX and Destructible Rock Fragment
	var parent := get_parent()
	if parent:
		var debris := ROCK_DEBRIS_VFX.instantiate() as Node3D
		parent.add_child(debris)
		debris.global_position = _target_ground_pos + Vector3(0, 0.25, 0)
		
		var rock := ROCK_FRAGMENT_SCENE.instantiate() as Node3D
		parent.add_child(rock)
		rock.global_position = _target_ground_pos
	
	if is_instance_valid(impact_area):
		impact_area.set_deferred("monitoring", false)
		impact_area.set_deferred("monitorable", false)
	
	queue_free()

func _apply_impact_damage() -> void:
	var hit_targets: Array = []
	
	if is_instance_valid(impact_area):
		for b in impact_area.get_overlapping_bodies():
			if is_instance_valid(b) and b != self and not (b in hit_targets):
				hit_targets.append(b)
	
	if is_inside_tree():
		for group_name in ["player", "enemies", "destructibles"]:
			for entity in get_tree().get_nodes_in_group(group_name):
				if is_instance_valid(entity) and entity is Node3D and entity != self and not (entity in hit_targets):
					var dist: float = _target_ground_pos.distance_to(entity.global_position)
					if dist <= impact_radius:
						hit_targets.append(entity)
		
		# Direct sibling fallback for deterministic headless tests without physics tick
		var parent_node := get_parent()
		if parent_node:
			for sibling in parent_node.get_children():
				if is_instance_valid(sibling) and sibling != self and not (sibling in hit_targets):
					if sibling.has_method("take_damage") and (sibling is CharacterBody3D or sibling is StaticBody3D):
						var dist: float = _target_ground_pos.distance_to(sibling.global_position)
						if dist <= impact_radius:
							hit_targets.append(sibling)
	
	for target in hit_targets:
		if not is_instance_valid(target):
			continue
		if target.has_method("take_damage"):
			target.take_damage(damage, _target_ground_pos)

# Test helper for instant deterministic headless execution
func trigger_impact_now() -> void:
	_trigger_impact()
