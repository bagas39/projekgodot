# res://src/ui/sanctuary_armory.gd
extends CanvasLayer

signal closed
signal talent_purchased(talent_id: String, new_level: int)

@onready var gem_count_label: Label = $Control/MainPanel/MarginContainer/VBoxContainer/HeaderBox/GemPanel/HBoxContainer/GemCountLabel
@onready var close_button: Button = $Control/MainPanel/MarginContainer/VBoxContainer/FooterBox/CloseButton
@onready var cards_container: HBoxContainer = $Control/MainPanel/MarginContainer/VBoxContainer/CardsContainer

var _cards: Dictionary = {}

const TALENTS = [
	{
		"id": "max_health",
		"name": "Titan Vitality",
		"icon": "❤️",
		"desc": "+20 Max Health per level.",
		"bonus_unit": "HP",
		"bonus_per_level": 20.0,
		"fallback_cost": 10
	},
	{
		"id": "base_damage",
		"name": "Warrior Might",
		"icon": "⚔️",
		"desc": "+5 Base Damage per level.",
		"bonus_unit": "ATK",
		"bonus_per_level": 5.0,
		"fallback_cost": 15
	},
	{
		"id": "move_speed",
		"name": "Wind Strider",
		"icon": "👟",
		"desc": "+0.4 Movement Speed per level.",
		"bonus_unit": "SPD",
		"bonus_per_level": 0.4,
		"fallback_cost": 10
	},
	{
		"id": "dash_cooldown",
		"name": "Shadow Step",
		"icon": "💨",
		"desc": "-0.08s Dash Cooldown per level.",
		"bonus_unit": "CD",
		"bonus_per_level": 0.08,
		"fallback_cost": 12
	}
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 15
	visible = false
	if close_button:
		close_button.pressed.connect(close)
	_setup_cards()

func _setup_cards() -> void:
	if not is_instance_valid(cards_container):
		return
	for talent in TALENTS:
		var tid: String = talent["id"]
		var card_name: String = "Card_" + tid
		var card: Node = cards_container.get_node_or_null(card_name)
		if card:
			var btn := card.find_child("BuyButton", true, false) as Button
			if btn and not btn.pressed.is_connected(_on_buy_pressed.bind(tid)):
				btn.pressed.connect(_on_buy_pressed.bind(tid))
			_cards[tid] = card

func open() -> void:
	visible = true
	refresh_ui()
	if close_button:
		close_button.grab_focus()

func close() -> void:
	visible = false
	closed.emit()

func refresh_ui() -> void:
	var save_mgr := get_node_or_null("/root/SaveManager")
	var gems: int = 0
	if save_mgr and save_mgr.has_method("get_soul_gems"):
		gems = save_mgr.get_soul_gems()
	
	if is_instance_valid(gem_count_label):
		gem_count_label.text = "%d" % gems
	
	for talent in TALENTS:
		var tid: String = talent["id"]
		if not _cards.has(tid):
			continue
		var card: Node = _cards[tid]
		_update_card(card, talent, gems, save_mgr)

func _update_card(card: Node, talent: Dictionary, current_gems: int, save_mgr: Node) -> void:
	var tid: String = talent["id"]
	var level: int = 0
	var max_level: int = 5
	var cost: int = talent["fallback_cost"]
	var current_bonus: float = 0.0
	
	if save_mgr:
		if save_mgr.has_method("get_talent_level"):
			level = save_mgr.get_talent_level(tid)
		if save_mgr.has_method("get_talent_max_level"):
			max_level = save_mgr.get_talent_max_level(tid)
		elif save_mgr.has_method("get_talent_spec"):
			var spec: Dictionary = save_mgr.get_talent_spec(tid)
			max_level = spec.get("max_level", 5)
		if save_mgr.has_method("get_talent_cost"):
			cost = save_mgr.get_talent_cost(tid)
		if save_mgr.has_method("get_talent_bonus"):
			current_bonus = save_mgr.get_talent_bonus(tid)
	else:
		current_bonus = float(level) * float(talent["bonus_per_level"])
	
	var level_lbl := card.find_child("LevelLabel", true, false) as Label
	var pip_bar := card.find_child("PipBar", true, false) as ProgressBar
	var current_lbl := card.find_child("CurrentBonusLabel", true, false) as Label
	var next_lbl := card.find_child("NextBonusLabel", true, false) as Label
	var cost_lbl := card.find_child("CostLabel", true, false) as Label
	var buy_btn := card.find_child("BuyButton", true, false) as Button
	
	if level_lbl:
		level_lbl.text = "Level %d / %d" % [level, max_level]
	if pip_bar:
		pip_bar.max_value = max_level
		pip_bar.value = level
	if current_lbl:
		current_lbl.text = "Current: " + _format_bonus(talent, current_bonus)
	
	var is_maxed: bool = (level >= max_level or cost < 0)
	if is_maxed:
		if next_lbl:
			next_lbl.text = "MAX LEVEL REACHED"
			next_lbl.modulate = Color(1.0, 0.85, 0.3, 1.0)
		if cost_lbl:
			cost_lbl.text = "MASTERED"
			cost_lbl.modulate = Color(1.0, 0.85, 0.3, 1.0)
		if buy_btn:
			buy_btn.text = "Mastered"
			buy_btn.disabled = true
	else:
		var next_bonus: float = current_bonus + float(talent["bonus_per_level"])
		if next_lbl:
			next_lbl.text = "Next: " + _format_bonus(talent, next_bonus)
			next_lbl.modulate = Color(0.4, 1.0, 0.5, 1.0)
		if cost_lbl:
			cost_lbl.text = "Cost: %d 💎" % cost
		if buy_btn:
			buy_btn.text = "Upgrade"
			var can_afford: bool = (current_gems >= cost)
			buy_btn.disabled = not can_afford
			if cost_lbl:
				cost_lbl.modulate = Color(0.85, 0.65, 1.0, 1.0) if can_afford else Color(0.9, 0.35, 0.35, 1.0)

func _format_bonus(talent: Dictionary, bonus: float) -> String:
	if talent["id"] == "dash_cooldown":
		return "-%.2fs CD" % bonus
	elif talent["id"] == "move_speed":
		return "+%.1f SPD" % bonus
	else:
		return "+%d %s" % [int(round(bonus)), talent["bonus_unit"]]

func _on_buy_pressed(talent_id: String) -> void:
	var save_mgr := get_node_or_null("/root/SaveManager")
	if not save_mgr or not save_mgr.has_method("purchase_talent"):
		return
	
	var success: bool = save_mgr.purchase_talent(talent_id)
	var audio_mgr := get_node_or_null("/root/AudioManager")
	
	if success:
		if audio_mgr and audio_mgr.has_method("play_crit"):
			audio_mgr.play_crit()
		elif audio_mgr and audio_mgr.has_method("play_wave_fanfare"):
			audio_mgr.play_wave_fanfare()
		
		if _cards.has(talent_id) and is_inside_tree():
			var card: Node = _cards[talent_id]
			var tween := create_tween()
			tween.tween_property(card, "scale", Vector2(1.03, 1.03), 0.08)
			tween.tween_property(card, "scale", Vector2.ONE, 0.12)
		
		refresh_ui()
		var new_lvl: int = save_mgr.get_talent_level(talent_id) if save_mgr.has_method("get_talent_level") else 1
		talent_purchased.emit(talent_id, new_lvl)
	else:
		if audio_mgr and audio_mgr.has_method("play_player_hurt"):
			audio_mgr.play_player_hurt()
