extends CharacterBody3D

signal health_changed(current: int, max_hp: int)
signal kills_changed(count: int)
signal player_died
signal special_cooldown_updated(remaining: float, max_time: float)

@export var max_health: int = 100
@export var move_speed: float = 7.5
@export var attack_damage: int = 30
@export var attack_cooldown: float = 0.30
@export var dash_speed: float = 22.0
@export var dash_duration: float = 0.18
@export var dash_cooldown: float = 0.8
@export var special_cooldown: float = 6.0

var current_health: int
var kills: int = 0
var can_attack: bool = true
var attack_cooldown_timer: float = 0.0
var is_dashing: bool = false
var can_dash: bool = true
var dash_timer: float = 0.0
var dash_direction: Vector3 = Vector3.FORWARD
var dash_cooldown_timer: float = 0.0

# Special Ability (Ground Shockwave)
var special_cooldown_timer: float = 0.0
var can_special: bool = true
var special_radius: float = 7.0
var special_damage: int = 70

# Juice: Camera shake & Hitstop
var camera_trauma: float = 0.0
var trauma_decay: float = 4.0
var is_in_hitstop: bool = false

# Upgrades
var bonus_damage: int = 0
var bonus_speed: float = 0.0
var orb_count: int = 0
var active_orbs: Array[Node3D] = []
var sword_scale_multiplier: float = 1.0
var crit_chance: float = 0.20
var vampiric_heal: int = 0
var vampiric_chance: float = 0.50

@onready var visual_pivot: Node3D = $VisualPivot
@onready var sword_pivot: Node3D = $VisualPivot/SwordPivot
@onready var sword_hitbox: Area3D = $VisualPivot/SwordPivot/SwordHitbox
@onready var hurtbox: Area3D = $Hurtbox
@onready var camera_3d: Camera3D = $CameraPivot/Camera3D
@onready var arcane_wand: Node3D = get_node_or_null("VisualPivot/ArcaneWand")

const HIT_VFX = preload("res://src/combat/hit_vfx.tscn")
const DAMAGE_NUMBER = preload("res://src/combat/damage_number.tscn")
const ORBITING_ORB = preload("res://src/combat/orbiting_orb.tscn")

# Base stats before meta-talent scaling
var _base_max_health: int = 100
var _base_move_speed: float = 7.5
var _base_attack_damage: int = 30
var _base_dash_cooldown: float = 0.8
var _meta_talents_applied: bool = false

func _ready() -> void:
	apply_meta_talents()
	current_health = max_health
	health_changed.emit(current_health, max_health)
	kills_changed.emit(kills)
	special_cooldown_updated.emit(0.0, special_cooldown)
	sword_hitbox.monitoring = false
	sword_hitbox.body_entered.connect(_on_sword_hit)
	
	if not is_instance_valid(arcane_wand):
		arcane_wand = get_node_or_null("VisualPivot/ArcaneWand")
		if not is_instance_valid(arcane_wand):
			var wand_scene = load("res://src/combat/arcane_wand.tscn")
			if wand_scene:
				arcane_wand = wand_scene.instantiate()
				if is_instance_valid(visual_pivot):
					visual_pivot.add_child(arcane_wand)
				else:
					add_child(arcane_wand)
	if is_instance_valid(arcane_wand) and "player" in arcane_wand:
		arcane_wand.player = self

func apply_meta_talents() -> void:
	# Cache original export baseline stats once
	if not _meta_talents_applied:
		_base_max_health = max_health
		_base_move_speed = move_speed
		_base_attack_damage = attack_damage
		_base_dash_cooldown = dash_cooldown
		_meta_talents_applied = true
	
	var save_mgr = get_node_or_null("/root/SaveManager")
	if not save_mgr or not save_mgr.has_method("get_talent_bonus"):
		# Default fallback: 0 bonus (preserves exact base stats)
		max_health = _base_max_health
		move_speed = _base_move_speed
		attack_damage = _base_attack_damage
		dash_cooldown = _base_dash_cooldown
		return
	
	var hp_bonus: int = int(round(save_mgr.get_talent_bonus("max_health")))
	var dmg_bonus: int = int(round(save_mgr.get_talent_bonus("base_damage")))
	var spd_bonus: float = save_mgr.get_talent_bonus("move_speed")
	var dash_cd_reduc: float = save_mgr.get_talent_bonus("dash_cooldown")
	
	max_health = _base_max_health + hp_bonus
	attack_damage = _base_attack_damage + dmg_bonus
	move_speed = _base_move_speed + spd_bonus
	dash_cooldown = maxf(0.2, _base_dash_cooldown - dash_cd_reduc)
	
	current_health = max_health
	health_changed.emit(current_health, max_health)

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	_cleanup_orbs()

func _process(delta: float) -> void:
	if camera_trauma > 0.0 and is_instance_valid(camera_3d):
		camera_trauma = max(0.0, camera_trauma - (trauma_decay * delta))
		var shake := camera_trauma * camera_trauma * 0.7
		camera_3d.h_offset = randf_range(-1.0, 1.0) * shake
		camera_3d.v_offset = randf_range(-1.0, 1.0) * shake
	elif is_instance_valid(camera_3d) and (camera_3d.h_offset != 0.0 or camera_3d.v_offset != 0.0):
		camera_3d.h_offset = 0.0
		camera_3d.v_offset = 0.0

func _physics_process(delta: float) -> void:
	# Cooldown countdowns
	if not can_dash:
		dash_cooldown_timer -= delta
		if dash_cooldown_timer <= 0.0:
			can_dash = true

	if not can_attack:
		attack_cooldown_timer -= delta
		if attack_cooldown_timer <= 0.0:
			can_attack = true

	if not can_special:
		special_cooldown_timer -= delta
		special_cooldown_updated.emit(max(0.0, special_cooldown_timer), special_cooldown)
		if special_cooldown_timer <= 0.0:
			can_special = true
			special_cooldown_updated.emit(0.0, special_cooldown)

	# Handling Dash state
	if is_dashing:
		dash_timer -= delta
		velocity = dash_direction * dash_speed
		move_and_slide()
		if dash_timer <= 0.0:
			is_dashing = false
		return

	# Movement Input (WASD / Arrows / InputMap)
	var move_x := 0.0
	var move_z := 0.0

	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or (InputMap.has_action("move_left") and Input.is_action_pressed("move_left")):
		move_x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or (InputMap.has_action("move_right") and Input.is_action_pressed("move_right")):
		move_x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or (InputMap.has_action("move_up") and Input.is_action_pressed("move_up")):
		move_z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN) or (InputMap.has_action("move_down") and Input.is_action_pressed("move_down")):
		move_z += 1.0

	var move_dir := Vector3(move_x, 0, move_z)
	if move_dir.length_squared() > 0.0:
		move_dir = move_dir.normalized()

	velocity.x = move_dir.x * (move_speed + bonus_speed)
	velocity.z = move_dir.z * (move_speed + bonus_speed)
	
	# Gravity
	if not is_on_floor():
		velocity.y -= 25.0 * delta
	else:
		velocity.y = 0.0

	move_and_slide()

	# Aim towards mouse cursor on ground plane
	_aim_towards_mouse(move_dir)

	# Attack Input (Left click, Space, J key, or action)
	var attack_pressed := false
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_J):
		attack_pressed = true
	elif InputMap.has_action("attack") and Input.is_action_pressed("attack"):
		attack_pressed = true

	if attack_pressed and can_attack:
		attack()

	# Dash Input (Right click, Shift, K key, or action)
	var dash_pressed := false
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_K):
		dash_pressed = true
	elif InputMap.has_action("dash") and Input.is_action_just_pressed("dash"):
		dash_pressed = true

	if dash_pressed and can_dash:
		start_dash(move_dir if move_dir != Vector3.ZERO else -visual_pivot.global_basis.z)

	# Special Ability Input (Q, E, or action)
	var special_pressed := false
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_E):
		special_pressed = true
	elif InputMap.has_action("special_ability") and Input.is_action_just_pressed("special_ability"):
		special_pressed = true

	if special_pressed and can_special and not is_dashing and current_health > 0:
		trigger_special_ability()

func _aim_towards_mouse(fallback_move_dir: Vector3) -> void:
	var viewport := get_viewport()
	if not viewport:
		return
	var mouse_pos := viewport.get_mouse_position()
	var camera := viewport.get_camera_3d()
	if not camera:
		if fallback_move_dir != Vector3.ZERO:
			visual_pivot.look_at(visual_pivot.global_position + fallback_move_dir, Vector3.UP)
		return
	
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_normal := camera.project_ray_normal(mouse_pos)
	
	var ground_plane := Plane(Vector3.UP, global_position.y)
	var intersection = ground_plane.intersects_ray(ray_origin, ray_normal)
	
	if intersection:
		var target: Vector3 = intersection
		target.y = visual_pivot.global_position.y
		if (target - visual_pivot.global_position).length_squared() > 0.2:
			visual_pivot.look_at(target, Vector3.UP)
	elif fallback_move_dir != Vector3.ZERO:
		visual_pivot.look_at(visual_pivot.global_position + fallback_move_dir, Vector3.UP)

func attack() -> void:
	can_attack = false
	attack_cooldown_timer = attack_cooldown
	sword_hitbox.monitoring = true
	
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_slash"):
		audio_mgr.play_slash()
	
	# Slash swing tween
	var tween := create_tween()
	sword_pivot.rotation.y = deg_to_rad(-85.0)
	tween.tween_property(sword_pivot, "rotation:y", deg_to_rad(85.0), 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(func():
		if is_instance_valid(sword_hitbox):
			sword_hitbox.monitoring = false
		if is_instance_valid(sword_pivot):
			sword_pivot.rotation.y = 0.0
	)

func start_dash(direction: Vector3) -> void:
	can_dash = false
	is_dashing = true
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	dash_direction = direction.normalized()
	
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_dash"):
		audio_mgr.play_dash()
	
	# Dash visual squash & stretch
	var tween := create_tween()
	tween.tween_property(visual_pivot, "scale", Vector3(0.7, 1.4, 1.4), 0.08)
	tween.tween_property(visual_pivot, "scale", Vector3.ONE, 0.1)

func trigger_special_ability() -> void:
	can_special = false
	special_cooldown_timer = special_cooldown
	special_cooldown_updated.emit(special_cooldown, special_cooldown)
	
	add_camera_shake(0.40)
	trigger_hitstop(0.05)
	
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_special"):
		audio_mgr.play_special()
	
	# Visual slam squish
	if is_instance_valid(visual_pivot):
		var tween := create_tween()
		visual_pivot.scale = Vector3(1.35, 0.45, 1.35)
		tween.tween_property(visual_pivot, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Spawn shockwave impact VFX
	var parent := get_parent()
	if parent:
		var vfx := HIT_VFX.instantiate() as Node3D
		parent.add_child(vfx)
		vfx.global_position = global_position + Vector3(0, 0.2, 0)
		vfx.scale = Vector3.ONE * 2.2
	
	# Clear projectiles in shockwave range
	var projs := get_tree().get_nodes_in_group("enemy_projectiles")
	for p in projs:
		if is_instance_valid(p) and "global_position" in p:
			if global_position.distance_to(p.global_position) <= (special_radius + 1.2):
				if p.has_method("_destroy"):
					p._destroy(true)
				else:
					p.queue_free()
	
	# Damage all enemies in shockwave range with outward knockback
	var enemies := get_tree().get_nodes_in_group("enemies")
	var total_dmg: int = special_damage + int(float(bonus_damage) * 1.5)
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.has_method("take_damage") and enemy != self:
			var dist := global_position.distance_to(enemy.global_position)
			if dist <= special_radius:
				enemy.take_damage(total_dmg, global_position, true)
	
	# Damage all destructibles in shockwave range
	var destructibles := get_tree().get_nodes_in_group("destructibles")
	for prop in destructibles:
		if is_instance_valid(prop) and prop.has_method("take_damage") and prop != self:
			var dist := global_position.distance_to(prop.global_position)
			if dist <= special_radius:
				prop.take_damage(total_dmg, global_position, true)

func _on_sword_hit(body: Node3D) -> void:
	if not is_instance_valid(body) or body == self:
		return
	if body.has_method("take_damage"):
		var is_crit := randf() < crit_chance
		var dmg: int = (attack_damage + bonus_damage) * (2 if is_crit else 1)
		var hit_pos := body.global_position
		body.take_damage(dmg, global_position, is_crit)
		
		# Audio feedback
		var audio_mgr := get_node_or_null("/root/AudioManager")
		if audio_mgr:
			if is_crit and audio_mgr.has_method("play_crit"):
				audio_mgr.play_crit()
			elif audio_mgr.has_method("play_hit"):
				audio_mgr.play_hit()
		
		# Spawn hit VFX
		var parent := get_parent()
		if parent:
			var vfx := HIT_VFX.instantiate() as Node3D
			parent.add_child(vfx)
			vfx.global_position = hit_pos + Vector3(0, 0.8, 0)
		
		# Juice: Screen shake & Hit-stop on impact
		if is_crit:
			add_camera_shake(0.28)
			trigger_hitstop(0.04)
		else:
			add_camera_shake(0.08)

func take_damage(amount: int, from_pos: Variant = null, _is_crit: bool = false) -> void:
	if is_dashing or current_health <= 0:
		return # Invulnerable during dash or already dead
	
	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)
	
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_player_hurt"):
		audio_mgr.play_player_hurt()
	
	# Strong camera shake on taking damage
	add_camera_shake(0.42)
	
	# Horizontal knockback only (prevent pushing into the floor)
	if from_pos != null and from_pos is Vector3:
		var knock_dir: Vector3 = (global_position - from_pos)
		knock_dir.y = 0.0
		if knock_dir.length_squared() > 0.001:
			velocity += knock_dir.normalized() * 10.0
		else:
			var facing_back := visual_pivot.global_basis.z if is_instance_valid(visual_pivot) else Vector3.BACK
			velocity += facing_back * 10.0
	
	# Hit reaction: squash & stretch on scale, keep position.y fixed at 0.9
	visual_pivot.position.y = 0.9
	var tween := create_tween()
	visual_pivot.scale = Vector3(1.25, 0.75, 1.25)
	tween.tween_property(visual_pivot, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	if current_health <= 0:
		die()

func heal(amount: int) -> void:
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)

func add_kill() -> void:
	kills += 1
	kills_changed.emit(kills)
	if vampiric_heal > 0 and randf() < vampiric_chance:
		heal(vampiric_heal)

func add_camera_shake(amount: float) -> void:
	camera_trauma = clamp(camera_trauma + amount, 0.0, 1.0)

func trigger_camera_shake(amount: float = 0.5) -> void:
	add_camera_shake(min(1.0, amount * 0.05 if amount > 1.0 else amount))

func trigger_hitstop(duration: float = 0.04) -> void:
	if is_in_hitstop or not is_inside_tree() or current_health <= 0:
		return
	is_in_hitstop = true
	Engine.time_scale = 0.05
	var tree := get_tree()
	if not tree:
		Engine.time_scale = 1.0
		is_in_hitstop = false
		return
	await tree.create_timer(duration, true, false, true).timeout
	if not is_inside_tree():
		Engine.time_scale = 1.0
		is_in_hitstop = false
		return
	if Engine.time_scale == 0.05:
		Engine.time_scale = 1.0
	is_in_hitstop = false

func apply_colossal_blade(scale_boost: float = 0.35) -> void:
	sword_scale_multiplier = min(2.4, sword_scale_multiplier + scale_boost)
	if is_instance_valid(sword_pivot):
		var tween := create_tween()
		var target_scale := Vector3.ONE * sword_scale_multiplier
		tween.tween_property(sword_pivot, "scale", target_scale * 1.3, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(sword_pivot, "scale", target_scale, 0.1)

func apply_critical_focus(chance_boost: float = 0.25) -> void:
	crit_chance = min(1.0, crit_chance + chance_boost)

func apply_vampiric_touch(heal_boost: int = 10) -> void:
	vampiric_heal += heal_boost

func apply_vitality(hp_boost: int = 35) -> void:
	max_health += hp_boost
	heal(hp_boost)

func apply_haste(cooldown_reduction_pct: float = 0.20) -> void:
	attack_cooldown = max(0.12, attack_cooldown * (1.0 - cooldown_reduction_pct))

func apply_phantom_dash(cooldown_reduction_pct: float = 0.25) -> void:
	dash_cooldown = max(0.30, dash_cooldown * (1.0 - cooldown_reduction_pct))

func apply_earthquake(cooldown_reduction_pct: float = 0.25, dmg_boost: int = 35) -> void:
	special_cooldown = max(2.5, special_cooldown * (1.0 - cooldown_reduction_pct))
	special_damage += dmg_boost

func add_orb_upgrade() -> void:
	orb_count += 1
	_cleanup_orbs()
	
	var parent := get_parent()
	if not parent:
		return
	for i in range(orb_count):
		var orb := ORBITING_ORB.instantiate()
		parent.add_child(orb)
		var angle: float = (TAU / float(orb_count)) * float(i)
		orb.setup(self, angle)
		active_orbs.append(orb)

func apply_wand_fire_rate(pct: float = 0.25) -> void:
	if is_instance_valid(arcane_wand) and arcane_wand.has_method("apply_fire_rate_upgrade"):
		arcane_wand.apply_fire_rate_upgrade(pct)

func apply_wand_extra_projectile(amount: int = 1) -> void:
	if is_instance_valid(arcane_wand) and arcane_wand.has_method("apply_multishot_upgrade"):
		arcane_wand.apply_multishot_upgrade(amount)

func apply_wand_pierce(amount: int = 1) -> void:
	if is_instance_valid(arcane_wand) and arcane_wand.has_method("apply_pierce_upgrade"):
		arcane_wand.apply_pierce_upgrade(amount)

func die() -> void:
	Engine.time_scale = 1.0
	is_in_hitstop = false
	is_dashing = false
	can_attack = false
	can_dash = false
	if is_instance_valid(sword_hitbox):
		sword_hitbox.monitoring = false
	if is_instance_valid(arcane_wand):
		arcane_wand.set_physics_process(false)
	_cleanup_orbs()
	
	var parent := get_parent()
	if parent:
		var vfx := HIT_VFX.instantiate() as Node3D
		parent.add_child(vfx)
		vfx.global_position = global_position + Vector3(0, 0.8, 0)
	
	if is_instance_valid(visual_pivot):
		var tween := create_tween()
		tween.tween_property(visual_pivot, "scale", Vector3(1.3, 0.15, 1.3), 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	player_died.emit()
	set_physics_process(false)

func _cleanup_orbs() -> void:
	for orb in active_orbs:
		if is_instance_valid(orb):
			orb.queue_free()
	active_orbs.clear()
