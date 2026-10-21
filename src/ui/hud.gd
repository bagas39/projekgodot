extends CanvasLayer

@onready var hp_bar: ProgressBar = $Control/MarginContainer/VBoxContainer/HBoxContainer/HPBar
@onready var hp_label: Label = $Control/MarginContainer/VBoxContainer/HBoxContainer/HPLabel
@onready var wave_label: Label = $Control/MarginContainer/VBoxContainer/WaveLabel
@onready var kill_label: Label = $Control/MarginContainer/VBoxContainer/KillLabel
@onready var gem_label: Label = $Control/MarginContainer/VBoxContainer/GemLabel
@onready var game_over_panel: Panel = $Control/GameOverPanel

# GameOverPanel Summary & Buttons
@onready var summary_wave_label: Label = $Control/GameOverPanel/VBox/StatsBox/SummaryWaveLabel
@onready var summary_kills_label: Label = $Control/GameOverPanel/VBox/StatsBox/SummaryKillsLabel
@onready var summary_gems_label: Label = $Control/GameOverPanel/VBox/StatsBox/SummaryGemsLabel
@onready var high_score_badge: Label = $Control/GameOverPanel/VBox/StatsBox/HighScoreBadge
@onready var restart_button: Button = $Control/GameOverPanel/VBox/ButtonsBox/RestartButton
@onready var armory_button: Button = $Control/GameOverPanel/VBox/ButtonsBox/ArmoryButton
@onready var main_menu_button: Button = $Control/GameOverPanel/VBox/ButtonsBox/MainMenuButton
@onready var sanctuary_armory: CanvasLayer = $SanctuaryArmory

# Boss UI
@onready var boss_container: VBoxContainer = $Control/BossContainer
@onready var boss_name_label: Label = $Control/BossContainer/BossNameLabel
@onready var boss_hp_bar: ProgressBar = $Control/BossContainer/BossHPBar
@onready var boss_hp_label: Label = $Control/BossContainer/BossHPLabel

# Skill UI
@onready var skill_status_label: Label = $Control/SkillPanel/VBox/SkillStatusLabel
@onready var skill_progress_bar: ProgressBar = $Control/SkillPanel/VBox/SkillProgressBar

# Announcement Banner UI
@onready var announcement_banner: VBoxContainer = $Control/AnnouncementBanner
@onready var banner_title: Label = $Control/AnnouncementBanner/BannerTitle
@onready var banner_subtitle: Label = $Control/AnnouncementBanner/BannerSubtitle
@onready var biome_banner_label: Label = $Control/AnnouncementBanner/BiomeBannerLabel if has_node("Control/AnnouncementBanner/BiomeBannerLabel") else null

var _banner_tween: Tween = null
var _current_wave: int = 1
var _current_kills: int = 0
var _run_gems: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("hud")
	if boss_container:
		boss_container.visible = false
	if announcement_banner:
		announcement_banner.visible = false
		announcement_banner.modulate.a = 0.0
	if restart_button:
		restart_button.pressed.connect(_on_restart_button_pressed)
	if armory_button:
		armory_button.pressed.connect(_on_armory_button_pressed)
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu_button_pressed)
	if sanctuary_armory:
		sanctuary_armory.closed.connect(_on_armory_closed)

func update_health(current: int, max_hp: int) -> void:
	if not is_instance_valid(hp_bar) or not is_instance_valid(hp_label):
		return
	hp_bar.max_value = max(1, max_hp)
	hp_bar.value = current
	hp_label.text = "%d / %d" % [current, max_hp]

func update_wave(wave: int) -> void:
	_current_wave = wave
	if not is_instance_valid(wave_label):
		return
	if wave % 5 == 0:
		wave_label.text = "WAVE %d - BOSS BATTLE!" % wave
		wave_label.modulate = Color(1.5, 0.4, 0.2, 1.0)
	else:
		wave_label.text = "WAVE %d" % wave
		wave_label.modulate = Color(1.0, 0.85, 0.3, 1.0)
	
	if is_inside_tree():
		var tween := create_tween()
		tween.tween_property(wave_label, "scale", Vector2(1.2, 1.2), 0.1)
		tween.tween_property(wave_label, "scale", Vector2.ONE, 0.25)

func show_biome_banner(title: String = "DESCENDING INTO LAVA CAVERNS", subtitle: String = "BIOME II: VOLCANIC UNDERWORLD", duration: float = 2.8) -> void:
	if not is_instance_valid(announcement_banner):
		announcement_banner = get_node_or_null("Control/AnnouncementBanner") as VBoxContainer
	if not announcement_banner:
		return
	
	if not is_instance_valid(banner_title):
		banner_title = announcement_banner.get_node_or_null("BannerTitle") as Label
	if not is_instance_valid(banner_subtitle):
		banner_subtitle = announcement_banner.get_node_or_null("BannerSubtitle") as Label
	
	if banner_title:
		banner_title.text = title
	if biome_banner_label:
		biome_banner_label.text = title
	if banner_subtitle:
		banner_subtitle.text = subtitle
	
	announcement_banner.visible = true
	announcement_banner.modulate.a = 0.0
	announcement_banner.scale = Vector2(0.85, 0.85)
	announcement_banner.pivot_offset = announcement_banner.size * 0.5
	
	if _banner_tween and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = null
	
	if is_inside_tree():
		_banner_tween = create_tween()
		_banner_tween.set_parallel(true)
		_banner_tween.tween_property(announcement_banner, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_CUBIC)
		_banner_tween.tween_property(announcement_banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
		_banner_tween.chain().tween_interval(duration)
		_banner_tween.chain().tween_property(announcement_banner, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_QUAD)
		_banner_tween.chain().tween_callback(func():
			if is_instance_valid(announcement_banner):
				announcement_banner.visible = false
		)
	else:
		announcement_banner.modulate.a = 1.0
		announcement_banner.scale = Vector2.ONE

func show_biome_announcement(title: String, subtitle: String = "BIOME II: VOLCANIC UNDERWORLD", duration: float = 2.8) -> void:
	show_biome_banner(title, subtitle, duration)

func update_kills(kills: int) -> void:
	_current_kills = kills
	if is_instance_valid(kill_label):
		kill_label.text = "ELIMINATED: %d" % kills

func update_gems(gems: int) -> void:
	_run_gems = gems
	if is_instance_valid(gem_label):
		gem_label.text = "SOUL GEMS: %d" % _run_gems
		if is_inside_tree():
			var tween := create_tween()
			tween.tween_property(gem_label, "scale", Vector2(1.15, 1.15), 0.08)
			tween.tween_property(gem_label, "scale", Vector2.ONE, 0.15)

func add_run_gems(amount: int) -> void:
	update_gems(_run_gems + amount)

func update_special_cooldown(remaining: float, max_time: float) -> void:
	if not is_instance_valid(skill_status_label) or not is_instance_valid(skill_progress_bar):
		return
	var safe_max: float = maxf(0.001, max_time)
	if remaining <= 0.0:
		skill_status_label.text = "READY"
		skill_status_label.modulate = Color(0.3, 1.0, 0.5, 1.0)
		skill_progress_bar.max_value = 1.0
		skill_progress_bar.value = 1.0
	else:
		skill_status_label.text = "%.1fs" % remaining
		skill_status_label.modulate = Color(1.0, 0.7, 0.3, 1.0)
		skill_progress_bar.max_value = safe_max
		skill_progress_bar.value = clampf(safe_max - remaining, 0.0, safe_max)

func show_boss_bar(boss_name: String, current: int, max_hp: int) -> void:
	if not is_instance_valid(boss_container) or not is_instance_valid(boss_hp_bar):
		return
	boss_name_label.text = boss_name
	boss_hp_bar.max_value = max(1, max_hp)
	boss_hp_bar.value = current
	boss_hp_label.text = "%d / %d" % [current, max_hp]
	boss_container.visible = true
	boss_container.modulate.a = 0.0
	if is_inside_tree():
		var tween := create_tween()
		tween.tween_property(boss_container, "modulate:a", 1.0, 0.5)

func update_boss_health(current: int, max_hp: int) -> void:
	if not is_instance_valid(boss_container) or not is_instance_valid(boss_hp_bar):
		return
	boss_hp_bar.max_value = max(1, max_hp)
	boss_hp_bar.value = current
	boss_hp_label.text = "%d / %d" % [current, max_hp]

func hide_boss_bar() -> void:
	if not is_instance_valid(boss_container):
		return
	if is_inside_tree():
		var tween := create_tween()
		tween.tween_property(boss_container, "modulate:a", 0.0, 0.6)
		tween.chain().tween_callback(func(): 
			if is_instance_valid(boss_container):
				boss_container.visible = false
		)
	else:
		boss_container.visible = false

func set_new_high_score(is_record: bool) -> void:
	if is_instance_valid(high_score_badge):
		high_score_badge.visible = is_record

func show_game_over(is_new_record: bool = false) -> void:
	await get_tree().create_timer(0.4, true, false, true).timeout
	if not is_inside_tree():
		return
	
	if is_instance_valid(summary_wave_label):
		summary_wave_label.text = "WAVE REACHED: %d" % _current_wave
	if is_instance_valid(summary_kills_label):
		summary_kills_label.text = "MONSTERS SLAIN: %d" % _current_kills
	if is_instance_valid(summary_gems_label):
		summary_gems_label.text = "SOUL GEMS HARVESTED: %d" % _run_gems
	
	if is_instance_valid(high_score_badge):
		high_score_badge.visible = is_new_record
	
	if is_instance_valid(game_over_panel):
		game_over_panel.visible = true
	get_tree().paused = true
	if is_instance_valid(restart_button):
		restart_button.grab_focus()

func _on_restart_button_pressed() -> void:
	if is_instance_valid(restart_button):
		restart_button.disabled = true
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()

func _on_armory_button_pressed() -> void:
	if is_instance_valid(sanctuary_armory):
		sanctuary_armory.open()

func _on_armory_closed() -> void:
	if is_instance_valid(armory_button):
		armory_button.grab_focus()

func _on_main_menu_button_pressed() -> void:
	if is_instance_valid(main_menu_button):
		main_menu_button.disabled = true
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
