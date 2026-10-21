extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var spawner: Node3D = $Spawner

func _ready() -> void:
	get_tree().paused = false
	player.add_to_group("player")
	
	player.health_changed.connect(hud.update_health)
	player.kills_changed.connect(hud.update_kills)
	player.player_died.connect(hud.show_game_over)
	if player.has_signal("special_cooldown_updated"):
		player.special_cooldown_updated.connect(hud.update_special_cooldown)
	
	hud.update_health(player.current_health, player.max_health)
	hud.update_kills(player.kills)
	
	# Start directly on wave 5 (Boss Wave!)
	spawner.start_wave(5)
