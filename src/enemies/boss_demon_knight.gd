extends "res://src/enemies/enemy_base.gd"

signal boss_health_changed(current: int, max_hp: int)
signal boss_defeated

@export var cleave_range: float = 3.2
@export var slam_radius: float = 6.5
@export var slam_cooldown: float = 7.0

var slam_timer: float = 3.5 # First slam after brief engagement
var is_performing_slam: bool = false
var has_summoned_minions: bool = false

@onready var sword_pivot: Node3D = get_node_or_null("VisualRoot/SwordPivot")
@onready var telegraph_ring: MeshInstance3D = get_node_or_null("TelegraphRing")

const SLIME_SCENE = preload("res://src/enemies/enemy_slime.tscn")

func _ready() -> void:
	max_health = 750
	move_speed = 2.8
	attack_damage = 32
	attack_rate = 1.3
	exp_value = 100
	knockback_resistance = 0.90
	
	add_to_group("boss")
	super._ready()
	
	if telegraph_ring:
		telegraph_ring.visible = false
	
	# Connect to HUD boss bar
	call_deferred("_connect_to_hud")

func _connect_to_hud() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if not hud:
		var main := get_tree().current_scene
		if main and main.has_node("HUD"):
			hud = main.get_node("HUD")
	
	if hud and hud.has_method("show_boss_bar"):
		hud.show_boss_bar("DEMON OVERLORD", current_health, max_health)
		if not boss_health_changed.is_connected(hud.update_boss_health):
			boss_health_changed.connect(hud.update_boss_health)
		if not boss_defeated.is_connected(hud.hide_boss_bar):
			boss_defeated.connect(hud.hide_boss_bar)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	if is_performing_slam:
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		move_and_slide()
		return
	
	# Normal Enemy Movement & Cleave
	super._physics_process(delta)
	
	# Slam Cooldown
	slam_timer -= delta
	if slam_timer <= 0.0 and not is_performing_slam and is_instance_valid(player):
		var dist := global_position.distance_to(player.global_position)
		if dist <= 12.0:
			_execute_ground_slam()

func _attack_player(target: Node3D) -> void:
	# Heavy cleave animation
	can_deal_damage = false
	attack_timer = attack_rate
	
	if is_instance_valid(sword_pivot):
		var tween := create_tween()
		sword_pivot.rotation.x = deg_to_rad(-60.0)
		tween.tween_property(sword_pivot, "rotation:x", deg_to_rad(70.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_property(sword_pivot, "rotation:x", 0.0, 0.25)
	
	if is_instance_valid(target) and target.has_method("take_damage"):
		target.take_damage(attack_damage, global_position)
		if target.has_method("add_camera_shake"):
			target.add_camera_shake(0.25)
		
		var audio_mgr := get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_hit"):
			audio_mgr.play_hit()

func _execute_ground_slam() -> void:
	is_performing_slam = true
	slam_timer = slam_cooldown
	
	# Telegraph phase: Sword raises high, telegraph ring pulses
	if is_instance_valid(sword_pivot):
		var raise_tween := create_tween()
		raise_tween.tween_property(sword_pivot, "rotation:x", deg_to_rad(-105.0), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	if is_instance_valid(telegraph_ring):
		telegraph_ring.visible = true
		telegraph_ring.scale = Vector3(0.2, 1.0, 0.2)
		var ring_tween := create_tween()
		ring_tween.tween_property(telegraph_ring, "scale", Vector3(1.0, 1.0, 1.0), 0.95).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Anticipation pause (process_always = false so tree pause pauses the slam)
	await get_tree().create_timer(1.05, false).timeout
	
	if is_dead or not is_inside_tree():
		if is_instance_valid(telegraph_ring):
			telegraph_ring.visible = false
		is_performing_slam = false
		return
	
	# Slam down!
	if is_instance_valid(sword_pivot):
		var slam_tween := create_tween()
		slam_tween.tween_property(sword_pivot, "rotation:x", deg_to_rad(80.0), 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		slam_tween.tween_property(sword_pivot, "rotation:x", 0.0, 0.4)
	
	if is_instance_valid(telegraph_ring):
		telegraph_ring.visible = false
	
	# Audio & Screen shake
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_boss_slam"):
		audio_mgr.play_boss_slam()
	
	# Spawn shockwave impact visual
	var parent := get_parent()
	if parent:
		var vfx := HIT_VFX.instantiate() as Node3D
		parent.add_child(vfx)
		vfx.global_position = global_position + Vector3(0, 0.3, 0)
		vfx.scale = Vector3.ONE * 2.5
	
	# Damage check in AoE radius
	if is_instance_valid(player):
		if player.has_method("add_camera_shake"):
			player.add_camera_shake(0.55)
		
		var dist := global_position.distance_to(player.global_position)
		if dist <= slam_radius:
			if "is_dashing" in player and player.is_dashing:
				pass # Dodged!
			elif player.has_method("take_damage"):
				player.take_damage(int(float(attack_damage) * 1.3), global_position)
	
	# Recovery time
	await get_tree().create_timer(0.4, false).timeout
	if not is_inside_tree() or is_dead:
		is_performing_slam = false
		return
	is_performing_slam = false

func take_damage(amount: int, from_pos: Variant = null, is_crit: bool = false) -> void:
	super.take_damage(amount, from_pos, is_crit)
	boss_health_changed.emit(current_health, max_health)
	
	# Check 50% HP summon mechanic
	if not has_summoned_minions and current_health <= int(max_health * 0.5) and not is_dead:
		has_summoned_minions = true
		_summon_minions()

func _summon_minions() -> void:
	if is_instance_valid(player) and player.has_method("add_camera_shake"):
		player.add_camera_shake(0.3)
	
	var parent := get_parent()
	if not parent:
		return
	
	# Summon 3 crimson slimes in a triangle around boss
	for i in range(3):
		var angle: float = (TAU / 3.0) * float(i)
		var spawn_offset := Vector3(cos(angle) * 3.5, 0.4, sin(angle) * 3.5)
		var slime := SLIME_SCENE.instantiate() as CharacterBody3D
		parent.add_child(slime)
		slime.global_position = global_position + spawn_offset
		slime.max_health = 40
		slime.current_health = 40

func die() -> void:
	if is_dead:
		return
	
	is_performing_slam = false
	if is_instance_valid(telegraph_ring):
		telegraph_ring.visible = false
	
	boss_defeated.emit()
	
	if is_instance_valid(player) and player.has_method("add_camera_shake"):
		player.add_camera_shake(0.65)
	
	super.die()
