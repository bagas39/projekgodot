extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var arena: Node3D = $Arena
@onready var spawner: Node3D = $Spawner
@onready var hud: CanvasLayer = $HUD
@onready var upgrade_menu: CanvasLayer = $UpgradeMenu

var _run_ended: bool = false
var _is_lava_biome: bool = false

func _ready() -> void:
	get_tree().paused = false
	if AudioManager and AudioManager.has_method("set_volcanic_ambience"):
		AudioManager.set_volcanic_ambience(false)
	
	# Add player and HUD to respective groups
	player.add_to_group("player")
	if is_instance_valid(hud):
		hud.add_to_group("hud")
	
	# Connect player signals
	if not player.health_changed.is_connected(hud.update_health):
		player.health_changed.connect(hud.update_health)
	if not player.kills_changed.is_connected(hud.update_kills):
		player.kills_changed.connect(hud.update_kills)
	if not player.player_died.is_connected(_on_player_died):
		player.player_died.connect(_on_player_died)
	if player.has_signal("special_cooldown_updated") and hud.has_method("update_special_cooldown"):
		if not player.special_cooldown_updated.is_connected(hud.update_special_cooldown):
			player.special_cooldown_updated.connect(hud.update_special_cooldown)
	
	# Connect wave signals
	if not spawner.wave_started.is_connected(_on_wave_started):
		spawner.wave_started.connect(_on_wave_started)
	if not spawner.wave_cleared.is_connected(_on_wave_cleared):
		spawner.wave_cleared.connect(_on_wave_cleared)
	
	# Connect upgrade signals
	if not upgrade_menu.upgrade_selected.is_connected(_on_upgrade_selected):
		upgrade_menu.upgrade_selected.connect(_on_upgrade_selected)
	
	# Initialize HUD displays immediately
	if is_instance_valid(player) and is_instance_valid(hud):
		hud.update_health(player.current_health, player.max_health)
		hud.update_kills(player.kills)
		if hud.has_method("update_special_cooldown"):
			hud.update_special_cooldown(0.0, player.special_cooldown)
	if is_instance_valid(spawner) and is_instance_valid(hud):
		hud.update_wave(spawner.current_wave)

func _on_wave_started(wave: int) -> void:
	hud.update_wave(wave)
	var is_boss_wave: bool = (wave % 5 == 0)
	if AudioManager and AudioManager.has_method("set_boss_bgm"):
		AudioManager.set_boss_bgm(is_boss_wave)
	
	if wave >= 6 and not _is_lava_biome:
		_transition_to_lava_caverns()

func _transition_to_lava_caverns() -> void:
	if _is_lava_biome:
		return
	_is_lava_biome = true
	
	var arena_node: Node = arena
	if not is_instance_valid(arena_node):
		arena_node = get_node_or_null("Arena")
	if is_instance_valid(arena_node) and arena_node.has_method("transition_to_lava_caverns"):
		arena_node.transition_to_lava_caverns()
	
	var hud_node: Node = hud
	if not is_instance_valid(hud_node):
		hud_node = get_node_or_null("HUD")
	if is_instance_valid(hud_node) and hud_node.has_method("show_biome_banner"):
		hud_node.show_biome_banner("DESCENDING INTO LAVA CAVERNS")

func _on_wave_cleared(_wave: int) -> void:
	if AudioManager and AudioManager.has_method("set_boss_bgm"):
		AudioManager.set_boss_bgm(false)
	
	# Brief breather for last enemy death animation and particles to settle
	# process_always = false ensures the timer respects tree pauses
	await get_tree().create_timer(0.55, false).timeout
	if not is_inside_tree() or not is_instance_valid(player) or player.current_health <= 0 or get_tree().paused:
		return
	upgrade_menu.open_menu()

func _on_upgrade_selected(_upgrade_id: String) -> void:
	spawner.start_wave(spawner.current_wave + 1)

func _on_player_died() -> void:
	if _run_ended:
		return
	_run_ended = true
	
	var final_wave: int = spawner.current_wave if is_instance_valid(spawner) else 1
	var final_kills: int = player.kills if is_instance_valid(player) else 0
	
	var save_mgr := get_node_or_null("/root/SaveManager")
	var is_new_record: bool = false
	if save_mgr and save_mgr.has_method("get_high_score_wave"):
		is_new_record = (final_wave > save_mgr.get_high_score_wave())
	
	if save_mgr and save_mgr.has_method("record_run_end"):
		save_mgr.record_run_end(final_wave, final_kills)
	
	if is_instance_valid(hud):
		if hud.has_method("update_wave"):
			hud.update_wave(final_wave)
		if hud.has_method("update_kills"):
			hud.update_kills(final_kills)
		if hud.has_method("show_game_over"):
			hud.show_game_over(is_new_record)
