# res://scenes/main_menu.gd
extends Control

@onready var start_button: Button = $CenterBox/ButtonsBox/StartButton
@onready var armory_button: Button = $CenterBox/ButtonsBox/ArmoryButton
@onready var stats_button: Button = $CenterBox/ButtonsBox/StatsButton
@onready var quit_button: Button = $CenterBox/ButtonsBox/QuitButton

@onready var gem_count_label: Label = $HeaderContainer/GemDisplay/HBoxContainer/GemCountLabel
@onready var stats_modal: Panel = $StatsModal
@onready var close_stats_button: Button = $StatsModal/MarginContainer/VBoxContainer/CloseStatsButton
@onready var stat_high_wave: Label = $StatsModal/MarginContainer/VBoxContainer/StatHighWave
@onready var stat_kills: Label = $StatsModal/MarginContainer/VBoxContainer/StatKills
@onready var stat_gems: Label = $StatsModal/MarginContainer/VBoxContainer/StatGems
@onready var stat_runs: Label = $StatsModal/MarginContainer/VBoxContainer/StatRuns

@onready var sanctuary_armory: CanvasLayer = $SanctuaryArmory

func _ready() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	
	if start_button:
		start_button.pressed.connect(_on_start_pressed)
		start_button.grab_focus()
	if armory_button:
		armory_button.pressed.connect(_on_armory_pressed)
	if stats_button:
		stats_button.pressed.connect(_on_stats_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)
	if close_stats_button:
		close_stats_button.pressed.connect(_on_close_stats_pressed)
	
	if sanctuary_armory:
		sanctuary_armory.closed.connect(_on_armory_closed)
	
	refresh_gem_display()
	
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_combat_music"):
		audio_mgr.play_combat_music()

func refresh_gem_display() -> void:
	var save_mgr := get_node_or_null("/root/SaveManager")
	var gems: int = 0
	if save_mgr and save_mgr.has_method("get_soul_gems"):
		gems = save_mgr.get_soul_gems()
	if is_instance_valid(gem_count_label):
		gem_count_label.text = "%d" % gems

func _on_start_pressed() -> void:
	if is_instance_valid(start_button):
		start_button.disabled = true
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_armory_pressed() -> void:
	if sanctuary_armory:
		sanctuary_armory.open()

func _on_armory_closed() -> void:
	refresh_gem_display()
	if armory_button:
		armory_button.grab_focus()

func _on_stats_pressed() -> void:
	var save_mgr := get_node_or_null("/root/SaveManager")
	var high_wave: int = 0
	var kills: int = 0
	var gems: int = 0
	var runs: int = 0
	
	if save_mgr:
		if save_mgr.has_method("get_high_score_wave"):
			high_wave = save_mgr.get_high_score_wave()
		if save_mgr.has_method("get_lifetime_kills"):
			kills = save_mgr.get_lifetime_kills()
		if save_mgr.has_method("get_soul_gems"):
			gems = save_mgr.get_soul_gems()
		if save_mgr.has_method("get_runs_played"):
			runs = save_mgr.get_runs_played()
	
	if is_instance_valid(stat_high_wave):
		stat_high_wave.text = "Highest Wave Cleared: %d" % high_wave
	if is_instance_valid(stat_kills):
		stat_kills.text = "Total Enemies Slain: %d" % kills
	if is_instance_valid(stat_gems):
		stat_gems.text = "Total Soul Gems: %d" % gems
	if is_instance_valid(stat_runs):
		stat_runs.text = "Runs Attempted: %d" % runs
	
	if is_instance_valid(stats_modal):
		stats_modal.visible = true
	if is_instance_valid(close_stats_button):
		close_stats_button.grab_focus()

func _on_close_stats_pressed() -> void:
	if is_instance_valid(stats_modal):
		stats_modal.visible = false
	if stats_button:
		stats_button.grab_focus()

func _on_quit_pressed() -> void:
	get_tree().quit()
