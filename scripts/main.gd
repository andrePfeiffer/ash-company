extends Control

class Combatant:
	var display_name: String
	var role: String
	var max_hp: int
	var hp: int
	var attack: int
	var defense: int
	var heal_power: int
	var speed: float
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


var party: Array[Combatant] = []
var enemies: Array[Combatant] = []
var wave: int = 1
var combat_started: bool = false

var root_box: VBoxContainer
var top_bar: HBoxContainer
var battlefield: HBoxContainer
var party_box: HBoxContainer
var enemy_box: HBoxContainer
var log_label: RichTextLabel
var status_label: Label

const MAX_LOG_LINES := 8
var combat_log: Array[String] = []


func _ready() -> void:
	setup_window()
	build_ui()
	start_new_run()


func _process(delta: float) -> void:
	if not combat_started:
		return

	if get_alive(party).is_empty():
		combat_started = false
		push_log("The Ash Company fell on wave %s." % wave)
		update_ui()
		return

	if get_alive(enemies).is_empty():
		wave += 1
		spawn_wave(wave)
		push_log("Wave %s approaches." % wave)
		update_ui()
		return

	for hero in get_alive(party):
		hero.action_timer += delta
		if hero.action_timer >= hero.speed:
			hero.action_timer = 0.0
			party_action(hero)

	for enemy in get_alive(enemies):
		enemy.action_timer += delta
		if enemy.action_timer >= enemy.speed:
			enemy.action_timer = 0.0
			enemy_action(enemy)

	update_ui()


func setup_window() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(960, 220))
	DisplayServer.window_set_title("Ash Company - Combat MVP")

	# Keep it off for development. Later we can expose this as a player setting.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, false)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)


func build_ui() -> void:
	var background := PanelContainer.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	root_box = VBoxContainer.new()
	root_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_box.add_theme_constant_override("separation", 8)
	root_box.offset_left = 10
	root_box.offset_top = 8
	root_box.offset_right = -10
	root_box.offset_bottom = -8
	background.add_child(root_box)

	top_bar = HBoxContainer.new()
	root_box.add_child(top_bar)

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

	battlefield = HBoxContainer.new()
	battlefield.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battlefield.add_theme_constant_override("separation", 16)
	root_box.add_child(battlefield)

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

	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.fit_content = false
	log_label.scroll_active = false
	log_label.custom_minimum_size = Vector2(0, 56)
	root_box.add_child(log_label)


func start_new_run() -> void:
	wave = 1
	combat_log.clear()
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
	var enemy_count := mini(2 + int(current_wave / 2), 5)
	enemies.clear()
	for index in enemy_count:
		var hp := 28 + current_wave * 8 + index * 3
		var atk := 5 + current_wave * 2
		var def := int(current_wave / 3)
		var speed := maxf(0.8, 1.8 - current_wave * 0.03)
		enemies.append(Combatant.new("Ashling %s" % (index + 1), "Enemy", hp, atk, def, 0, speed, true))


func party_action(hero: Combatant) -> void:
	if hero.display_name == "Mender":
		var wounded := get_most_wounded_ally()
		if wounded != null and wounded.hp < wounded.max_hp * 0.72:
			var amount := hero.heal_power + randi_range(0, 4)
			wounded.hp = mini(wounded.max_hp, wounded.hp + amount)
			push_log("Mender heals %s for %s." % [wounded.display_name, amount])
			return

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
	var variance := randi_range(-2, 3)
	return maxi(1, raw_attack + variance - target_defense)


func get_enemy_target() -> Combatant:
	# Enemies prefer the Vanguard while he is alive.
	for hero in party:
		if hero.display_name == "Vanguard" and hero.is_alive():
			return hero
	return get_first_alive(party)


func get_most_wounded_ally() -> Combatant:
	var alive_party := get_alive(party)
	if alive_party.is_empty():
		return null

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
	for child in container.get_children():
		child.queue_free()

	for combatant in combatants:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(105, 78)
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


func push_log(message: String) -> void:
	combat_log.push_front(message)
	if combat_log.size() > MAX_LOG_LINES:
		combat_log.resize(MAX_LOG_LINES)
