extends Node2D
class_name FloatingNumber

@onready var label: Label = %ValueLabel


func show_value(text: String, color: Color) -> void:
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)

	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - 26.0, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.65)
	tween.finished.connect(func() -> void:
		queue_free()
	)
