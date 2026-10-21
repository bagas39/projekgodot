extends Node3D

enum Biome {
	DUNGEON = 0,
	LAVA_CAVERNS = 1
}

const LAVA_FLOOR_SHADER: Shader = preload("res://src/shaders/lava_basalt_floor.gdshader")

var current_biome: int = Biome.DUNGEON
var is_lava_biome: bool = false

@onready var floor_body: StaticBody3D = $Floor
@onready var floor_mesh: MeshInstance3D = $Floor/MeshInstance3D
@onready var walls: StaticBody3D = $Walls
@onready var dungeon_motes: GPUParticles3D = $DungeonMotes
@onready var volcanic_embers: GPUParticles3D = $VolcanicEmbers
@onready var lava_hazards: Node3D = $LavaHazards

func _ready() -> void:
	add_to_group("arena")
	if not is_lava_biome:
		_deactivate_lava_hazards()

func transition_to_lava_caverns(duration: float = 2.0) -> void:
	if is_lava_biome:
		return
	is_lava_biome = true
	current_biome = Biome.LAVA_CAVERNS
	
	_apply_lava_floor(duration)
	_apply_lava_lighting(duration)
	_activate_particles()
	_activate_lava_hazards()
	_trigger_audio()

func _apply_lava_floor(_duration: float) -> void:
	if not is_instance_valid(floor_mesh):
		floor_mesh = get_node_or_null("Floor/MeshInstance3D") as MeshInstance3D
	if not floor_mesh:
		return
	
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = LAVA_FLOOR_SHADER
	shader_mat.set_shader_parameter("basalt_color", Color(0.08, 0.07, 0.08, 1.0))
	shader_mat.set_shader_parameter("lava_color", Color(1.0, 0.32, 0.04, 1.0))
	shader_mat.set_shader_parameter("lava_core_color", Color(1.0, 0.85, 0.25, 1.0))
	shader_mat.set_shader_parameter("crack_scale", 24.0)
	shader_mat.set_shader_parameter("crack_intensity", 1.0)
	shader_mat.set_shader_parameter("pulse_speed", 2.4)
	shader_mat.set_shader_parameter("roughness_val", 0.85)
	
	floor_mesh.material_override = shader_mat

func _apply_lava_lighting(duration: float) -> void:
	var target_torch_color := Color(1.0, 0.42, 0.08, 1.0)
	var target_torch_energy := 3.8
	var target_torch_range := 16.0
	
	for pillar_path in ["Pillar1", "Pillar2", "Pillar3", "Pillar4"]:
		var pillar := get_node_or_null(pillar_path)
		if not pillar:
			continue
		var torch := pillar.get_node_or_null("TorchLight") as OmniLight3D
		if torch:
			if "base_energy" in torch:
				torch.set("base_energy", target_torch_energy)
			if duration > 0.0 and is_inside_tree():
				var t := create_tween()
				t.tween_property(torch, "light_color", target_torch_color, duration)
				t.parallel().tween_property(torch, "omni_range", target_torch_range, duration)
			else:
				torch.light_color = target_torch_color
				torch.omni_range = target_torch_range
				torch.light_energy = target_torch_energy
		
		var flame := pillar.get_node_or_null("Flame") as MeshInstance3D
		if flame and flame.mesh and flame.mesh.material is StandardMaterial3D:
			var flame_mat := flame.mesh.material as StandardMaterial3D
			flame_mat.emission = Color(1.0, 0.35, 0.05, 1.0)
			flame_mat.emission_energy_multiplier = 5.0
	
	var dir_light: DirectionalLight3D = null
	var world_env: WorldEnvironment = null
	
	if get_parent():
		dir_light = get_parent().get_node_or_null("DirectionalLight3D") as DirectionalLight3D
		world_env = get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	
	if not dir_light and is_inside_tree():
		dir_light = get_tree().root.find_child("DirectionalLight3D", true, false) as DirectionalLight3D
	if not world_env and is_inside_tree():
		world_env = get_tree().root.find_child("WorldEnvironment", true, false) as WorldEnvironment
	
	var target_sun_color := Color(1.0, 0.58, 0.28, 1.0)
	var target_sun_energy := 1.35
	if dir_light:
		if duration > 0.0 and is_inside_tree():
			var t := create_tween()
			t.tween_property(dir_light, "light_color", target_sun_color, duration)
			t.parallel().tween_property(dir_light, "light_energy", target_sun_energy, duration)
		else:
			dir_light.light_color = target_sun_color
			dir_light.light_energy = target_sun_energy
	
	if world_env and world_env.environment:
		var env := world_env.environment
		var target_bg_color := Color(0.09, 0.03, 0.02, 1.0)
		var target_amb_color := Color(0.50, 0.20, 0.10, 1.0)
		var target_amb_energy := 1.15
		var target_bloom := 0.32
		var target_glow := 0.75
		
		if duration > 0.0 and is_inside_tree():
			var t := create_tween()
			t.tween_property(env, "background_color", target_bg_color, duration)
			t.parallel().tween_property(env, "ambient_light_color", target_amb_color, duration)
			t.parallel().tween_property(env, "ambient_light_energy", target_amb_energy, duration)
			t.parallel().tween_property(env, "glow_bloom", target_bloom, duration)
			t.parallel().tween_property(env, "glow_intensity", target_glow, duration)
		else:
			env.background_color = target_bg_color
			env.ambient_light_color = target_amb_color
			env.ambient_light_energy = target_amb_energy
			env.glow_bloom = target_bloom
			env.glow_intensity = target_glow

func _activate_particles() -> void:
	if not is_instance_valid(volcanic_embers):
		volcanic_embers = get_node_or_null("VolcanicEmbers") as GPUParticles3D
	if not is_instance_valid(dungeon_motes):
		dungeon_motes = get_node_or_null("DungeonMotes") as GPUParticles3D
	
	if volcanic_embers:
		volcanic_embers.emitting = true
	if dungeon_motes:
		dungeon_motes.emitting = false

func _activate_lava_hazards() -> void:
	if not is_instance_valid(lava_hazards):
		lava_hazards = get_node_or_null("LavaHazards") as Node3D
	if lava_hazards:
		lava_hazards.visible = true
		for child in lava_hazards.get_children():
			if child.has_method("activate"):
				child.activate()

func _deactivate_lava_hazards() -> void:
	if not is_instance_valid(lava_hazards):
		lava_hazards = get_node_or_null("LavaHazards") as Node3D
	if lava_hazards:
		lava_hazards.visible = false
		for child in lava_hazards.get_children():
			if child.has_method("deactivate"):
				child.deactivate()

func _trigger_audio() -> void:
	if not is_inside_tree():
		return
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if not audio_mgr and is_inside_tree():
		audio_mgr = get_tree().root.get_node_or_null("AudioManager")
	if audio_mgr and audio_mgr.has_method("set_volcanic_ambience"):
		audio_mgr.set_volcanic_ambience(true)
