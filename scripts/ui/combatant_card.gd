extends PanelContainer

# A small UI component for one combatant in the battle panel.
# It does not know anything about combat rules; it only receives display data
# and renders labels, HP bar, and dead/alive styling.

@onready var name_label: Label = %NameLabel
@onready var role_label: Label = %RoleLabel
@onready var hp_bar: ProgressBar = %HpBar
@onready var hp_label: Label = %HpLabel


func update_from_combatant(
	display_name: String,
	role: String,
	hp: int,
	max_hp: int,
	is_alive: bool
) -> void:
	name_label.text = display_name
	role_label.text = role

	hp_bar.max_value = max_hp
	hp_bar.value = hp
	hp_bar.show_percentage = false

	hp_label.text = "%s/%s" % [hp, max_hp]
	add_theme_stylebox_override("panel", make_card_style(is_alive))


func make_card_style(is_alive: bool) -> StyleBoxFlat:
	# Dead units are darker so it is easier to read the battlefield quickly.
	var alpha := 0.72 if is_alive else 0.36
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.09, alpha)
	style.border_color = Color(0.22, 0.22, 0.24, alpha)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 6
	style.content_margin_top = 5
	style.content_margin_right = 6
	style.content_margin_bottom = 5
	return style
