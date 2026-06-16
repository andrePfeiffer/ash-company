extends Control

# This MVP keeps everything in one file on purpose.
# Later we will split this into smaller scripts, such as Combatant.gd, CombatSystem.gd, and CombatLog.gd.

class Combatant:
	# Display data.
	var display_name: String
	var role: String

	# Combat stats.
	var max_hp: int
	var hp: int
	var attack: int
	var defense: int
	var heal_power: int
	var speed: float

	# Runtime state.
	var action_timer: float = 0.0
	var is_enemy: bool = false

	func _init(
		_display_name: String,
		_role: String,
		_max_hp: int,
		_attack: int,
		_defense: int,
		_heal_power: int,
		_speed: float,
		_is_enemy: bool = false
	) -> void:
		display_name = _display_name
		role = _role
		max_hp = _max_hp
		hp = _max_hp
		attack = _attack
		defense = _defense
		heal_power = _heal_power
		speed = _speed
		is_enemy = _is_enemy

	func is_alive() -> bool:
		return hp > 0

	func hp_text() -> String:
		return "%s/%s" % [hp, max_hp]


const INITIAL_WINDOW_SIZE := Vector2i(960, 300)
const LOG_MIN_HEIGHT := 104
const MAX_LOG_LINES := 80

var party: Array[Combatant] = []
var enemies: Array[Combatant] = []
var wave: int = 1
var combat_started: bool = false

# UI references.
# These are stored as variables because update_ui() rebuilds parts of the interface every frame.
var root_box: VBoxContainer
var top_bar: HBoxContainer
var battlefield: HBoxContainer
var party_box: HBoxContainer
var enemy_box: HBoxContainer
var log_label: RichTextLabel
var status_label: Label

# The log keeps more lines than the visible area.
# RichTextLabel will provide the scrollbar.
var combat_log: Array[String] = []


func _ready() -> void:
	setup_window()
	build_ui()
	start_new_run()


func _process(delta: float) -> void:
	if not combat_started:
		return

	# Lose condition: every party member is dead.
	if get_alive(party).is_empty():
		combat_started = false
		push_log("The Ash Company fell on wave %s." % wave)
		update_ui()
		return

	# Wave clear: all enemies are dead, then the next wave starts immediately.
	if get_alive(enemies).is_empty():
		wave += 1
		spawn_wave(wave)
		push_log("Wave %s approaches." % wave)
		update_ui()
		return

	# Party members act automatically when their action timer reaches their speed value.
	for hero in get_alive(party):
		hero.action_timer += delta
		if hero.action_timer >= hero.speed:
			hero.action_timer = 0.0
			party_action(hero)

	# Enemies use the same timer system as the party.
	for enemy in get_alive(enemies):
		enemy.action_timer += delta
		if enemy.action_timer >= enemy.speed:
			enemy.action_timer = 0.0
			enemy_action(enemy)

	update_ui()


func setup_window() -> void:
	# Start as a normal resizable window so development is comfortable.
	# Later we can expose borderless / always-on-top / compact mode as in-game settings.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(INITIAL_WINDOW_SIZE)
	DisplayServer.window_set_title("Ash Company - Combat MVP")
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)

	# Transparent windows need both the window flag and a transparent viewport background.
	# The visible dark panels below are semi-transparent; the empty space around them should show the desktop.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true)
	get_tree().root.transparent_bg = true


func build_ui() -> void:
	# MarginContainer gives us padding without drawing an opaque background.
	# This is important because a full-screen PanelContainer would cover the transparent window.
	var screen_margin := MarginContainer.new()
	screen_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_margin.add_theme_constant_override("margin_left", 8)
	screen_margin.add_theme_constant_override("margin_top", 8)
	screen_margin.add_theme_constant_override("margin_right", 8)
	screen_margin.add_theme_constant_override("margin_bottom", 8)
	add_child(screen_margin)

	root_box = VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 8)
	screen_margin.add_child(root_box)

	build_top_bar()
	build_battlefield()
	build_log()


func build_top_bar() -> void:
	var top_panel := PanelContainer.new()
	top_panel.add_theme_stylebox_override("panel", make_panel_style(0.78))
	root_box.add_child(top_panel)

	top_bar = HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 10)
	top_panel.add_child(top_bar)

	var title := Label.new()
	title.text = "Ash Company"
	title.add_theme_font_size_override("font_size", 18)
	top_bar.add_child(title)

	status_label = Label.new()
	status_label.text = ""
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(status_label)

	var restart_button := Button.new()
	restart_button.text = "Restart"
	restart_button.pressed.connect(start_new_run)
	top_bar.add_child(restart_button)


func build_battlefield() -> void:
	var battlefield_panel := PanelContainer.new()
	battlefield_panel.add_theme_stylebox_override("panel", make_panel_style(0.72))
	battlefield_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(battlefield_panel)

	battlefield = HBoxContainer.new()
	battlefield.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battlefield.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battlefield.add_theme_constant_override("separation", 16)
	battlefield_panel.add_child(battlefield)

	party_box = HBoxContainer.new()
	party_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	party_box.add_theme_constant_override("separation", 8)
	battlefield.add_child(party_box)

	var divider := VSeparator.new()
	battlefield.add_child(divider)

	enemy_box = HBoxContainer.new()
	enemy_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_box.add_theme_constant_override("separation", 8)
	battlefield.add_child(enemy_box)


func build_log() -> void:
	var log_panel := PanelContainer.new()
	log_panel.add_theme_stylebox_override("panel", make_panel_style(0.82))
	log_panel.custom_minimum_size = Vector2(0, LOG_MIN_HEIGHT)
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(log_panel)

	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.fit_content = false

	# This is the important part for the combat log.
	# scroll_active enables the scrollbar, and scroll_following keeps the newest line visible.
	log_label.scroll_active = true
	log_label.scroll_following = true
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_panel.add_child(log_label)


func make_panel_style(alpha: float) -> StyleBoxFlat:
	# StyleBoxFlat lets us create readable panels without making the whole window opaque.
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.035, 0.04, alpha)
	style.border_color = Color(0.23, 0.23, 0.25, minf(alpha + 0.12, 1.0))
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_top = 6
	style.content_margin_right = 8
	style.content_margin_bottom = 6
	return style


func start_new_run() -> void:
	wave = 1
	combat_log.clear()

	# Four fixed archetypes for the first MVP.
	# Builds/items will make them flexible later, but the base roles stay readable.
	party = [
		Combatant.new("Vanguard", "Tank", 120, 9, 5, 0, 1.4),
		Combatant.new("Striker", "DPS", 75, 17, 1, 0, 1.0),
		Combatant.new("Mender", "Healer", 70, 7, 1, 15, 1.7),
		Combatant.new("Arcanist", "Mage", 62, 20, 0, 0, 1.8),
	]

	spawn_wave(wave)
	combat_started = true
	push_log("The Ash Company enters the first ruin.")
	update_ui()


func spawn_wave(current_wave: int) -> void:
	# Enemy count slowly increases, but is capped so the UI stays readable.
	var enemy_count := mini(2 + int(current_wave / 2), 5)
	enemies.clear()

	for index in enemy_count:
		var hp := 28 + current_wave * 8 + index * 3
		var atk := 5 + current_wave * 2
		var def := int(current_wave / 3)
		var speed := maxf(0.8, 1.8 - current_wave * 0.03)
		enemies.append(Combatant.new("Ashling %s" % (index + 1), "Enemy", hp, atk, def, 0, speed, true))


func party_action(hero: Combatant) -> void:
	# Mender tries to heal before attacking.
	# The 72% threshold is arbitrary for now; later this can become a build/stat setting.
	if hero.display_name == "Mender":
		var wounded := get_most_wounded_ally()
		if wounded != null and wounded.hp < wounded.max_hp * 0.72:
			var amount := hero.heal_power + randi_range(0, 4)
			wounded.hp = mini(wounded.max_hp, wounded.hp + amount)
			push_log("Mender heals %s for %s." % [wounded.display_name, amount])
			return

	# Everyone else attacks the first living enemy.
	# Later we can add targeting rules such as lowest HP, highest threat, marked target, etc.
	var target := get_first_alive(enemies)
	if target == null:
		return

	var damage := calculate_damage(hero.attack, target.defense)
	target.hp = maxi(0, target.hp - damage)
	push_log("%s hits %s for %s." % [hero.display_name, target.display_name, damage])

	if not target.is_alive():
		push_log("%s is defeated." % target.display_name)


func enemy_action(enemy: Combatant) -> void:
	var target := get_enemy_target()
	if target == null:
		return

	var damage := calculate_damage(enemy.attack, target.defense)
	target.hp = maxi(0, target.hp - damage)
	push_log("%s strikes %s for %s." % [enemy.display_name, target.display_name, damage])

	if not target.is_alive():
		push_log("%s has fallen." % target.display_name)


func calculate_damage(raw_attack: int, target_defense: int) -> int:
	# Small random variance keeps the log from feeling too mechanical.
	var variance := randi_range(-2, 3)
	return maxi(1, raw_attack + variance - target_defense)


func get_enemy_target() -> Combatant:
	# Enemies prefer the Vanguard while he is alive.
	# This gives us the first version of a tank/aggro system.
	for hero in party:
		if hero.display_name == "Vanguard" and hero.is_alive():
			return hero
	return get_first_alive(party)


func get_most_wounded_ally() -> Combatant:
	var alive_party := get_alive(party)
	if alive_party.is_empty():
		return null

	# Sort by HP percentage, not raw HP.
	# Example: 30/60 is more wounded than 50/120.
	alive_party.sort_custom(func(a: Combatant, b: Combatant) -> bool:
		return float(a.hp) / float(a.max_hp) < float(b.hp) / float(b.max_hp)
	)
	return alive_party[0]


func get_first_alive(combatants: Array[Combatant]) -> Combatant:
	for combatant in combatants:
		if combatant.is_alive():
			return combatant
	return null


func get_alive(combatants: Array[Combatant]) -> Array[Combatant]:
	var alive: Array[Combatant] = []
	for combatant in combatants:
		if combatant.is_alive():
			alive.append(combatant)
	return alive


func update_ui() -> void:
	status_label.text = "Wave %s | Party: %s/4 | Enemies: %s" % [wave, get_alive(party).size(), get_alive(enemies).size()]
	rebuild_combatant_cards(party_box, party)
	rebuild_combatant_cards(enemy_box, enemies)
	log_label.text = "\n".join(combat_log)


func rebuild_combatant_cards(container: HBoxContainer, combatants: Array[Combatant]) -> void:
	# This is simple and readable, but not the most efficient approach.
	# Later we can keep card nodes alive and only update their labels/bars.
	for child in container.get_children():
		child.queue_free()

	for combatant in combatants:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(105, 80)
		card.add_theme_stylebox_override("panel", make_card_style(combatant))
		container.add_child(card)

		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 3)
		card.add_child(box)

		var name_label := Label.new()
		name_label.text = combatant.display_name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(name_label)

		var role_label := Label.new()
		role_label.text = combatant.role
		role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(role_label)

		var hp_bar := ProgressBar.new()
		hp_bar.max_value = combatant.max_hp
		hp_bar.value = combatant.hp
		hp_bar.show_percentage = false
		box.add_child(hp_bar)

		var hp_label := Label.new()
		hp_label.text = combatant.hp_text()
		hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(hp_label)


func make_card_style(combatant: Combatant) -> StyleBoxFlat:
	# Dead units are darker so it is easier to read the battlefield quickly.
	var alpha := 0.72 if combatant.is_alive() else 0.36
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


func push_log(message: String) -> void:
	# New messages go to the bottom.
	# This matches the scrollbar behavior: the log follows the newest line.
	combat_log.push_back(message)
	if combat_log.size() > MAX_LOG_LINES:
		combat_log.pop_front()
