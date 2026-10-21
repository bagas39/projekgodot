extends CharacterBody3D

@export var max_health: int = 50
@export var move_speed: float = 4.0
@export var attack_damage: int = 12
@export var attack_rate: float = 0.75
@export var exp_value: int = 10
@export var knockback_resistance: float = 0.0

var current_health: int
var player: Node3D = null
var can_deal_damage: bool = true
var attack_timer: float = 0.0
var is_dead: bool = false
var is_elite: bool = false
var base_scale: Vector3 = Vector3.ONE

@onready var visual_mesh: Node3D = ($VisualRoot if has_node("VisualRoot") else ($MeshInstance3D if has_node("MeshInstance3D") else self))

const DAMAGE_NUMBER = preload("res://src/combat/damage_number.tscn")
const HIT_VFX = preload("res://src/combat/hit_vfx.tscn")
const PICKUP_ITEM_SCENE = preload("res://src/props/pickup_item.tscn")

func _ready() -> void:
	current_health = max_health
	# Find player in tree
	call_deferred("_find_player")

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	if is_elite and has_node("AuraGlow/AuraRing"):
		get_node("AuraGlow/AuraRing").rotate_y(2.5 * delta)
	
	if not can_deal_damage:
		attack_timer -= delta
		if attack_timer <= 0.0:
			can_deal_damage = true
	
	if not is_instance_valid(player):
		_find_player()
		return
	
	if "current_health" in player and player.current_health <= 0:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	
	var dir := (player.global_position - global_position)
	dir.y = 0.0
	var distance := dir.length()
	
	if distance > 0.3:
		dir = dir.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		
		# Look at player
		if dir.length_squared() > 0.01:
			var look_target := global_position + dir
			look_at(look_target, Vector3.UP)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	# Gravity
	if not is_on_floor():
		velocity.y -= 25.0 * delta
	else:
		velocity.y = 0.0

	move_and_slide()
	
	# Check collision with player
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider and collider.is_in_group("player") and can_deal_damage:
			_attack_player(collider)

func _attack_player(target: Node3D) -> void:
	can_deal_damage = false
	attack_timer = attack_rate
	if is_instance_valid(target) and target.has_method("take_damage"):
		target.take_damage(attack_damage, global_position)

func take_damage(amount: int, from_pos: Variant = null, is_crit: bool = false) -> void:
	if is_dead:
		return
	
	current_health = max(0, current_health - amount)
	
	# Floating damage number
	var parent := get_parent()
	if parent:
		var dmg_label := DAMAGE_NUMBER.instantiate()
		parent.add_child(dmg_label)
		dmg_label.global_position = global_position + Vector3(0, 1.2, 0)
		dmg_label.setup(amount, is_crit or amount >= 50)
	
	# Knockback
	if from_pos != null and from_pos is Vector3 and from_pos != Vector3.ZERO:
		var pos_vec: Vector3 = from_pos
		var knock_dir: Vector3 = (global_position - pos_vec).normalized()
		knock_dir.y = 0.2
		var force: float = 10.0 * (1.0 - clamp(knockback_resistance, 0.0, 0.95))
		velocity += knock_dir * force
	
	if current_health <= 0:
		die()
	else:
		# Hit flash effect (squash & stretch) only when surviving hit
		if is_instance_valid(visual_mesh) and is_inside_tree():
			var tween := create_tween()
			tween.tween_property(visual_mesh, "scale", base_scale * Vector3(1.3, 0.7, 1.3), 0.08)
			tween.tween_property(visual_mesh, "scale", base_scale, 0.1)

func die() -> void:
	if is_dead:
		return
	is_dead = true
	set_physics_process(false)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	remove_from_group("enemies")
	
	if is_instance_valid(player) and player.has_method("add_kill"):
		player.add_kill()
	
	# Guaranteed Elite Drops
	if is_elite:
		_drop_elite_rewards()
	
	# Death vfx
	var parent := get_parent()
	if parent:
		var vfx := HIT_VFX.instantiate() as Node3D
		parent.add_child(vfx)
		vfx.global_position = global_position + Vector3(0, 0.6, 0)
	
	# Death shrink animation on visual node to avoid Jolt Physics singular transform warning
	var shrink_target: Node3D = visual_mesh if is_instance_valid(visual_mesh) else self
	var target_scale := Vector3.ZERO if shrink_target != self else Vector3(0.01, 0.01, 0.01)
	if is_inside_tree():
		var tween := create_tween()
		tween.tween_property(shrink_target, "scale", target_scale, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		if has_node("AuraGlow"):
			tween.parallel().tween_property(get_node("AuraGlow"), "scale", Vector3.ZERO, 0.18)
		tween.chain().tween_callback(queue_free)
	else:
		queue_free()

func make_elite(hp_mult: float = 1.75, speed_mult: float = 1.20, dmg_mult: float = 1.25) -> void:
	if is_elite:
		return
	is_elite = true
	add_to_group("elite_enemies")
	
	# Stat scaling
	max_health = int(float(max_health) * hp_mult)
	current_health = max_health
	move_speed *= speed_mult
	attack_damage = int(float(attack_damage) * dmg_mult)
	exp_value *= 2
	
	# Scale
	base_scale = Vector3(1.25, 1.25, 1.25)
	if not is_instance_valid(visual_mesh):
		visual_mesh = ($VisualRoot if has_node("VisualRoot") else ($MeshInstance3D if has_node("MeshInstance3D") else self))
	if is_instance_valid(visual_mesh):
		visual_mesh.scale = base_scale
	if has_node("CollisionShape3D"):
		get_node("CollisionShape3D").scale = base_scale
	
	# Visual Aura
	_attach_elite_aura()

func _attach_elite_aura() -> void:
	if has_node("AuraGlow"):
		return
	var aura_root := Node3D.new()
	aura_root.name = "AuraGlow"
	add_child(aura_root)
	
	# AuraRing: MeshInstance3D with TorusMesh
	var aura_ring := MeshInstance3D.new()
	aura_ring.name = "AuraRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.65 * 1.25
	torus.outer_radius = 0.85 * 1.25
	aura_ring.mesh = torus
	aura_ring.position = Vector3(0.0, 0.08, 0.0)
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.75, 0.15, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.75, 0.15)
	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura_ring.material_override = mat
	aura_root.add_child(aura_ring)
	
	# AuraLight: OmniLight3D
	var aura_light := OmniLight3D.new()
	aura_light.name = "AuraLight"
	aura_light.light_color = Color(1.0, 0.75, 0.15)
	aura_light.light_energy = 2.2
	aura_light.omni_range = 3.5
	aura_light.position = Vector3(0.0, 0.5, 0.0)
	aura_root.add_child(aura_light)

func _drop_elite_rewards() -> void:
	var parent := get_parent()
	if not parent:
		return
	
	var pickup = PICKUP_ITEM_SCENE.instantiate()
	parent.add_child(pickup)
	
	var is_low_hp: bool = false
	if not is_instance_valid(player):
		_find_player()
	if is_instance_valid(player) and "current_health" in player and "max_health" in player:
		if player.max_health > 0 and (float(player.current_health) / float(player.max_health)) < 0.45:
			is_low_hp = true
	
	var drop_type: int = 2 # 0: HEALTH, 2: SOUL_GEM
	if is_low_hp:
		drop_type = 0 if randf() < 0.65 else 2
	else:
		drop_type = 0 if randf() < 0.40 else 2
	
	var drop_pos: Vector3 = global_position + Vector3(0.0, 0.5, 0.0)
	if pickup.has_method("setup_elite"):
		pickup.setup_elite(drop_type, drop_pos)
	elif pickup.has_method("setup"):
		pickup.setup(drop_type, drop_pos)
