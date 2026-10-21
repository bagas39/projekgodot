extends Area3D

enum Type { HEALTH, GEM, SOUL_GEM }
@export var item_type: Type = Type.HEALTH
@export var value: int = 1
@export var heal_amount: int = 25

var gem_value: int:
	get:
		return value
	set(v):
		value = v

var _collected: bool = false
var _time_alive: float = 0.0
var _is_elite: bool = false
var _target_spawn_pos: Vector3 = Vector3.ZERO
var _has_target_spawn_pos: bool = false
var _pop_tween: Tween = null

@onready var visual_mesh: MeshInstance3D = $MeshInstance3D
@onready var light: OmniLight3D = $OmniLight3D

func _get_visual_mesh() -> MeshInstance3D:
	if is_instance_valid(visual_mesh):
		return visual_mesh
	if has_node("MeshInstance3D"):
		visual_mesh = get_node("MeshInstance3D") as MeshInstance3D
		return visual_mesh
	return null

func _get_light() -> OmniLight3D:
	if is_instance_valid(light):
		return light
	if has_node("OmniLight3D"):
		light = get_node("OmniLight3D") as OmniLight3D
		return light
	return null

func setup(type: int, spawn_pos: Vector3) -> void:
	item_type = type as Type
	_target_spawn_pos = spawn_pos
	_has_target_spawn_pos = true
	
	if is_inside_tree():
		global_position = spawn_pos
		_apply_visuals()
		_play_spawn_pop()

func setup_elite(type: int, spawn_pos: Vector3) -> void:
	_is_elite = true
	scale = Vector3(1.35, 1.35, 1.35)
	if type == Type.HEALTH or type == 0:
		item_type = Type.HEALTH
		heal_amount = 40
	elif type == Type.SOUL_GEM or type == 2:
		item_type = Type.SOUL_GEM
		value = 5
	
	setup(item_type, spawn_pos)

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	if _has_target_spawn_pos:
		global_position = _target_spawn_pos
		_play_spawn_pop()
	
	_apply_visuals()

func _apply_visuals() -> void:
	var mesh := _get_visual_mesh()
	if not is_instance_valid(mesh):
		return
	
	var omni := _get_light()
	
	var mat := mesh.get_active_material(0)
	if not mat:
		mat = StandardMaterial3D.new()
		mesh.material_override = mat
	elif mat is StandardMaterial3D:
		mat = mat.duplicate()
		mesh.material_override = mat
	
	if mat is StandardMaterial3D:
		mat.emission_enabled = true
		match item_type:
			Type.HEALTH:
				mat.albedo_color = Color(0.2, 0.9, 0.3, 1.0)
				mat.emission = Color(0.2, 0.9, 0.3, 1.0)
				mat.emission_energy_multiplier = 3.0
				if is_instance_valid(omni):
					omni.light_color = Color(0.2, 0.9, 0.3, 1.0)
					omni.light_energy = 1.8
			Type.GEM:
				mat.albedo_color = Color(1.0, 0.85, 0.2, 1.0)
				mat.emission = Color(1.0, 0.85, 0.2, 1.0)
				mat.emission_energy_multiplier = 3.0
				if is_instance_valid(omni):
					omni.light_color = Color(1.0, 0.85, 0.2, 1.0)
					omni.light_energy = 1.8
			Type.SOUL_GEM:
				mat.albedo_color = Color(0.80, 0.25, 1.0, 1.0)
				mat.emission = Color(0.88, 0.35, 1.0, 1.0)
				mat.emission_energy_multiplier = 4.0
				if is_instance_valid(omni):
					omni.light_color = Color(0.82, 0.30, 1.0, 1.0)
					omni.light_energy = 2.4
	
	if _is_elite:
		mesh.scale = Vector3(1.35, 1.35, 1.35)
	else:
		mesh.scale = Vector3.ONE

func _play_spawn_pop() -> void:
	if not is_inside_tree():
		return
	if _pop_tween and _pop_tween.is_valid():
		_pop_tween.kill()
	
	var base_y: float = global_position.y
	var target_floor_y: float = maxf(base_y, 0.4)
	var peak_pos := global_position + Vector3(randf_range(-0.6, 0.6), 1.2, randf_range(-0.6, 0.6))
	var floor_pos := Vector3(peak_pos.x, target_floor_y, peak_pos.z)
	
	_pop_tween = create_tween().set_parallel(true)
	_pop_tween.tween_property(self, "global_position:y", peak_pos.y, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_pop_tween.chain().tween_property(self, "global_position", floor_pos, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	if _collected:
		return
	
	_time_alive += delta
	# Bobbing and spinning
	var mesh := _get_visual_mesh()
	if is_instance_valid(mesh):
		mesh.rotate_y(3.0 * delta)
		mesh.position.y = 0.3 + sin(_time_alive * 4.0) * 0.1

func _on_body_entered(body: Node3D) -> void:
	if _collected or not body.is_in_group("player"):
		return
	
	_collected = true
	var audio_mgr := get_node_or_null("/root/AudioManager")
	
	match item_type:
		Type.HEALTH:
			if body.has_method("heal"):
				body.heal(heal_amount)
			if audio_mgr:
				if audio_mgr.has_method("play_pickup_heal"):
					audio_mgr.play_pickup_heal()
				elif audio_mgr.has_method("play_fanfare"):
					audio_mgr.play_fanfare()
		Type.GEM:
			if body.has_method("add_kill"):
				body.add_kill() # Bonus kill / score count
			if audio_mgr:
				if audio_mgr.has_method("play_pickup_score"):
					audio_mgr.play_pickup_score()
				elif audio_mgr.has_method("play_crit"):
					audio_mgr.play_crit()
		Type.SOUL_GEM:
			var save_mgr := get_node_or_null("/root/SaveManager")
			if save_mgr and save_mgr.has_method("add_soul_gems"):
				save_mgr.add_soul_gems(value)
			if is_inside_tree() and get_tree():
				get_tree().call_group("hud", "add_run_gems", value)
			if audio_mgr:
				if audio_mgr.has_method("play_soul_gem"):
					audio_mgr.play_soul_gem()
				elif audio_mgr.has_method("play_wave_fanfare"):
					audio_mgr.play_wave_fanfare()
				elif audio_mgr.has_method("play_crit"):
					audio_mgr.play_crit()
	
	# Disable collision/monitoring immediately to avoid duplicate triggers and physics anomalies
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	# Shrink mesh and light instead of Area3D to avoid Jolt singular transform warning
	if is_inside_tree():
		var mesh := _get_visual_mesh()
		var omni := _get_light()
		var tween := create_tween()
		if is_instance_valid(mesh):
			tween.tween_property(mesh, "scale", Vector3.ZERO, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		if is_instance_valid(omni):
			tween.parallel().tween_property(omni, "light_energy", 0.0, 0.12)
		tween.chain().tween_callback(queue_free)
	else:
		queue_free()
