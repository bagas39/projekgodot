extends Node3D

@onready var label: Label3D = $Label3D

func setup(amount: int, is_crit: bool = false) -> void:
	if not is_node_ready():
		await ready
	
	label.text = str(amount)
	if is_crit:
		label.modulate = Color(1.0, 0.85, 0.2, 1.0) # Golden yellow
		label.scale = Vector3(1.4, 1.4, 1.4)
	else:
		label.modulate = Color(1.0, 0.2, 0.2, 1.0) # Red
	
	# Animate pop and float up
	var tween := create_tween().set_parallel(true)
	var target_pos := position + Vector3(randf_range(-0.4, 0.4), 1.5, randf_range(-0.4, 0.4))
	tween.tween_property(self, "position", target_pos, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.2)
	tween.chain().tween_callback(queue_free)
