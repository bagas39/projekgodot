extends "res://src/enemies/enemy_base.gd"

@export var preferred_dist_min: float = 7.0
@export var preferred_dist_max: float = 12.5
@export var projectile_scene: PackedScene = preload("res://src/combat/projectile.tscn")
@export var projectile_speed: float = 11.0

var cast_cooldown: float = 2.3
var cast_timer: float = 1.0 # First shot comes out relatively soon
var is_casting: bool = false
var strafe_direction: float = 1.0
var strafe_timer: float = 0.0

@onready var staff_crystal: MeshInstance3D = get_node_or_null("VisualRoot/Staff/StaffCrystal")

func _ready() -> void:
	max_health = 65
	move_speed = 3.2
	attack_damage = 18
	exp_value = 20
	knockback_resistance = 0.2
	super._ready()

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	if not is_instance_valid(player):
		_find_player()
		return
	
	if "current_health" in player and player.current_health <= 0:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	
	var to_player := (player.global_position - global_position)
	to_player.y = 0.0
	var dist := to_player.length()
	var dir_to_player := to_player.normalized() if dist > 0.001 else Vector3.FORWARD
	
	# Always look towards player
	if dir_to_player.length_squared() > 0.01:
		look_at(global_position + dir_to_player, Vector3.UP)
	
	# Cast cooldown & execution
	cast_timer -= delta
	if cast_timer <= 0.0 and not is_casting and dist <= 16.0:
		_start_cast(dir_to_player)
	
	# Kiting and repositioning AI (only move when not locked in cast windup)
	if not is_casting:
		strafe_timer -= delta
		if strafe_timer <= 0.0:
			strafe_timer = randf_range(2.0, 4.0)
			strafe_direction = -strafe_direction if randf() < 0.6 else strafe_direction
		
		var move_dir := Vector3.ZERO
		if dist < preferred_dist_min:
			# Too close: Back away from player
			move_dir = -dir_to_player
		elif dist > preferred_dist_max:
			# Too far: Move closer
			move_dir = dir_to_player
		else:
			# Ideal range: Strafe tangentially
			var tangent := Vector3(-dir_to_player.z, 0, dir_to_player.x) * strafe_direction
			move_dir = tangent * 0.7
		
		velocity.x = move_dir.x * move_speed
		velocity.z = move_dir.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
	
	# Gravity
	if not is_on_floor():
		velocity.y -= 25.0 * delta
	else:
		velocity.y = 0.0
	
	move_and_slide()

func _start_cast(aim_dir: Vector3) -> void:
	is_casting = true
	cast_timer = cast_cooldown
	
	# Cast charge animation: Staff crystal flare & float
	if is_instance_valid(staff_crystal) and is_inside_tree():
		var tween := create_tween()
		tween.tween_property(staff_crystal, "scale", Vector3.ONE * 1.8, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(staff_crystal, "scale", Vector3.ONE, 0.1)
	
	await get_tree().create_timer(0.45, false).timeout
	
	if is_dead or not is_inside_tree():
		is_casting = false
		return
	
	# Re-check aim direction towards player
	if is_instance_valid(player):
		var fresh_dir := (player.global_position - global_position)
		fresh_dir.y = 0.0
		if fresh_dir.length_squared() > 0.01:
			aim_dir = fresh_dir.normalized()
	
	# Spawn Projectile
	var parent := get_parent()
	if parent and projectile_scene:
		var proj := projectile_scene.instantiate()
		parent.add_child(proj)
		var spawn_pos := global_position + Vector3(0, 1.2, 0) + aim_dir * 0.8
		proj.global_position = spawn_pos
		proj.setup(aim_dir, attack_damage, projectile_speed)
		
		# Audio feedback
		var audio_mgr := get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_cast"):
			audio_mgr.play_cast()
	
	is_casting = false

func die() -> void:
	is_casting = false
	super.die()
