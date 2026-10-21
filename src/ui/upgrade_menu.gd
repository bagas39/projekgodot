extends CanvasLayer

signal upgrade_selected(upgrade_id: String)

@onready var container: HBoxContainer = $Control/Panel/VBoxContainer/CardsContainer
@onready var panel: Panel = $Control/Panel

var player: Node3D = null
var _is_selecting: bool = false

const ALL_UPGRADES = [
	{
		"id": "damage",
		"icon": "🗡️",
		"title": "Serrated Blade",
		"desc": "+15 Attack Damage.\nSlice through monster hordes faster."
	},
	{
		"id": "speed",
		"icon": "⚡",
		"title": "Wind Stride",
		"desc": "+2.0 Movement Speed.\nGlide across the arena with ease."
	},
	{
		"id": "orb",
		"icon": "🔮",
		"title": "Arcane Aegis",
		"desc": "+1 Orbiting Energy Orb.\nContinuously damages nearby foes."
	},
	{
		"id": "heal",
		"icon": "💖",
		"title": "Holy Elixir",
		"desc": "Restore 40 Health Points.\nBolster your life essence."
	},
	{
		"id": "colossal",
		"icon": "⚔️",
		"title": "Colossal Blade",
		"desc": "+35% Sword Size & Reach.\nWide sweeping arcs strike more foes."
	},
	{
		"id": "crit",
		"icon": "🎯",
		"title": "Critical Focus",
		"desc": "+25% Critical Strike Chance.\nLand devastating double-damage blows."
	},
	{
		"id": "vampiric",
		"icon": "🩸",
		"title": "Vampiric Touch",
		"desc": "Chance to heal +10 HP on kill.\nFeast upon the souls of fallen enemies."
	},
	{
		"id": "vitality",
		"icon": "🛡️",
		"title": "Titan's Vitality",
		"desc": "+35 Max Health.\nFortifies life and instantly heals 35 HP."
	},
	{
		"id": "haste",
		"icon": "🌪️",
		"title": "Swift Slash",
		"desc": "-20% Attack Cooldown.\nUnleash rapid sword flurries."
	},
	{
		"id": "phantom",
		"icon": "💨",
		"title": "Phantom Dash",
		"desc": "-25% Dash Cooldown.\nDart across the battlefield more often."
	},
	{
		"id": "earthquake",
		"icon": "💥",
		"title": "Earthquake",
		"desc": "-25% Shockwave Cooldown & +35 Damage.\nShatter hordes with devastating tremors."
	},
	{
		"id": "wand_haste",
		"icon": "⚡",
		"title": "Arcane Haste",
		"desc": "-25% Arcane Wand Cooldown.\nUnleash rapid homing energy volleys."
	},
	{
		"id": "wand_multishot",
		"icon": "✨",
		"title": "Arcane Volley",
		"desc": "+1 Simultaneous Arcane Orb.\nLaunch additional seeking missiles."
	},
	{
		"id": "wand_pierce",
		"icon": "☄️",
		"title": "Piercing Arcana",
		"desc": "+1 Projectile Pierce.\nOrbs phase through foes to strike targets behind."
	}
]

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func open_menu() -> void:
	_is_selecting = false
	visible = true
	get_tree().paused = true
	
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	
	# Clear old buttons
	for child in container.get_children():
		child.queue_free()
	
	# Filter out capped upgrades so player never receives a useless choice
	var available_pool: Array[Dictionary] = []
	for item in ALL_UPGRADES:
		if is_instance_valid(player):
			if item["id"] == "crit" and "crit_chance" in player and player.crit_chance >= 1.0:
				continue
			if item["id"] == "colossal" and "sword_scale_multiplier" in player and player.sword_scale_multiplier >= 2.05:
				continue
			if item["id"] == "haste" and "attack_cooldown" in player and player.attack_cooldown <= 0.13:
				continue
			if item["id"] == "phantom" and "dash_cooldown" in player and player.dash_cooldown <= 0.35:
				continue
			if item["id"] == "earthquake" and "special_cooldown" in player and player.special_cooldown <= 2.6:
				continue
			if item["id"] == "wand_haste":
				if "arcane_wand" in player and is_instance_valid(player.arcane_wand):
					if player.arcane_wand.attack_cooldown <= 0.35:
						continue
			if item["id"] == "wand_multishot":
				if "arcane_wand" in player and is_instance_valid(player.arcane_wand):
					if player.arcane_wand.projectile_count >= 4:
						continue
			if item["id"] == "wand_pierce":
				if "arcane_wand" in player and is_instance_valid(player.arcane_wand):
					if player.arcane_wand.pierce_count >= 3:
						continue
		available_pool.append(item)
	
	if available_pool.size() < 3:
		available_pool = ALL_UPGRADES.duplicate()
	
	available_pool.shuffle()
	var selected_pool := available_pool.slice(0, 3)
	
	for item in selected_pool:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(190, 230)
		btn.text = "%s\n\n%s\n\n%s" % [item["icon"], item["title"], item["desc"]]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.pressed.connect(_on_card_picked.bind(item["id"]))
		container.add_child(btn)

func _on_card_picked(upgrade_id: String) -> void:
	if _is_selecting:
		return
	_is_selecting = true
	
	# Disable all buttons immediately to avoid rapid double-activation
	for child in container.get_children():
		if child is Button:
			child.disabled = true
	
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	
	if is_instance_valid(player):
		match upgrade_id:
			"damage":
				player.bonus_damage += 15
			"speed":
				player.bonus_speed += 2.0
			"orb":
				player.add_orb_upgrade()
			"heal":
				player.heal(40)
			"colossal":
				if player.has_method("apply_colossal_blade"):
					player.apply_colossal_blade(0.35)
			"crit":
				if player.has_method("apply_critical_focus"):
					player.apply_critical_focus(0.25)
			"vampiric":
				if player.has_method("apply_vampiric_touch"):
					player.apply_vampiric_touch(10)
			"vitality":
				if player.has_method("apply_vitality"):
					player.apply_vitality(35)
			"haste":
				if player.has_method("apply_haste"):
					player.apply_haste(0.20)
			"phantom":
				if player.has_method("apply_phantom_dash"):
					player.apply_phantom_dash(0.25)
			"earthquake":
				if player.has_method("apply_earthquake"):
					player.apply_earthquake(0.25, 35)
			"wand_haste":
				if player.has_method("apply_wand_fire_rate"):
					player.apply_wand_fire_rate(0.25)
			"wand_multishot":
				if player.has_method("apply_wand_extra_projectile"):
					player.apply_wand_extra_projectile(1)
			"wand_pierce":
				if player.has_method("apply_wand_pierce"):
					player.apply_wand_pierce(1)
	
	visible = false
	get_tree().paused = false
	upgrade_selected.emit(upgrade_id)
