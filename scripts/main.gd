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
const EXPANDED_WINDOW_SIZE := Vector2i(960, 520)
const CONTENT_WIDTH := 944.0
const WINDOW_MARGIN := 8.0
const BATTLEFIELD_HEIGHT := 90.0
const BACKGROUND_TEST_GAP_HEIGHT := 40.0
const LOG_COLLAPSED_HEIGHT := 92.0
const LOG_EXPANDED_HEIGHT := 300.0
const COMBATANT_CARD_WIDTH := 88.0
const COMBATANT_CARD_HEIGHT := 72.0
const MAX_LOG_LINES := 80

var party: Array[Combatant] = []
var enemies: Array[Combatant] = []
var wave: int = 1
var combat_started: bool = false

# UI references.
# These are stored as variables because update_ui() rebuilds parts of the interface every frame.
var content_layer: Control
var root_box: VBoxContainer
var top_panel: PanelContainer
var top_bar: HBoxContainer
var battlefield_panel: PanelContainer
var background_test_gap: Control
var battlefield: HBoxContainer
var party_box: HBoxContainer
var enemy_box: HBoxContainer
var log_panel: PanelContainer
var log_label: RichTextLabel
var status_label: Label
var log_toggle_button: Button

# Borderless windows do not have a native title bar, so we implement simple drag behavior.
var is_log_expanded := false
var is_dragging_window := false
var drag_mouse_start := Vector2i.ZERO
var drag_window_start := Vector2i.ZERO

# The log keeps more lines than the visible area.
# RichTextLabel will provide the scrollbar.
var combat_log: Array[String] = []


func _ready() -> void:
	setup_window()
	build_ui()

	# Recalculate the content bounds when the game window is resized.
	# This also updates the mouse passthrough region.
	get_viewport().size_changed.connect(update_layout_bounds)

	start_new_run()
	update_layout_bounds()


func _input(event: InputEvent) -> void:
	# Allows the custom top bar to move the borderless window.
	if not is_dragging_window:
		return

	if event is InputEventMouseMotion:
		var mouse_delta := DisplayServer.mouse_get_position() - drag_mouse_start
		DisplayServer.window_set_position(drag_window_start + mouse_delta)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		is_dragging_window = false


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
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(INITIAL_WINDOW_SIZE)
	DisplayServer.window_set_title("Ash Company - Combat MVP")

	# Desktop-game behavior:
	# - always on top keeps the game visible above normal windows;
	# - borderless hides the native Windows title bar/toolbar;
	# - transparent lets the desktop show through empty pixels.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true)

	# Transparent windows need both the window flag and a transparent viewport background.
	get_tree().root.transparent_bg = true


func build_ui() -> void:
	# This full-screen layer does not draw anything by itself.
	# We keep the real game UI inside root_box so transparent areas can be passed through to the desktop.
	content_layer = Control.new()
	content_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content_layer)

	root_box = VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 8)
	root_box.custom_minimum_size = Vector2(CONTENT_WIDTH, 0)
	content_layer.add_child(root_box)

	build_top_bar()
	build_battlefield()
	build_background_test_gap()
	build_log()


func build_top_bar() -> void:
	top_panel = PanelContainer.new()
	top_panel.add_theme_stylebox_override("panel", make_panel_style(0.78))
	top_panel.gui_input.connect(on_top_panel_gui_input)
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
	# Keep the status text from pushing the Restart / Close buttons out of the window.
	status_label.clip_text = true
	top_bar.add_child(status_label)

	log_toggle_button = Button.new()
	log_toggle_button.text = "Log +"
	log_toggle_button.tooltip_text = "Expand or collapse the combat log"
	log_toggle_button.pressed.connect(toggle_log_size)
	top_bar.add_child(log_toggle_button)

	var restart_button := Button.new()
	restart_button.text = "Restart"
	restart_button.pressed.connect(start_new_run)
	top_bar.add_child(restart_button)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.tooltip_text = "Close Ash Company"
	close_button.pressed.connect(get_tree().quit)
	top_bar.add_child(close_button)


func build_battlefield() -> void:
	battlefield_panel = PanelContainer.new()
	battlefield_panel.add_theme_stylebox_override("panel", make_panel_style(0.72))

	# The fight/stage area should stay compact.
	# When the window grows, the log expands instead of stretching the battlefield.
	battlefield_panel.custom_minimum_size = Vector2(0, BATTLEFIELD_HEIGHT)
	battlefield_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	root_box.add_child(battlefield_panel)

	battlefield = HBoxContainer.new()
	battlefield.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battlefield.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battlefield.add_theme_constant_override("separation", 10)
	battlefield_panel.add_child(battlefield)

	party_box = HBoxContainer.new()
	party_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	party_box.add_theme_constant_override("separation", 6)
	battlefield.add_child(party_box)

	var divider := VSeparator.new()
	battlefield.add_child(divider)

	enemy_box = HBoxContainer.new()
	enemy_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_box.add_theme_constant_override("separation", 6)
	battlefield.add_child(enemy_box)


func build_background_test_gap() -> void:
	# Temporary transparent gap between the combat stage and the log.
	# Most of this gap is outside the mouse passthrough polygon, so it is useful
	# for testing whether clicks reach the window behind Ash Company.
	background_test_gap = Control.new()
	background_test_gap.custom_minimum_size = Vector2(0, BACKGROUND_TEST_GAP_HEIGHT)
	background_test_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_box.add_child(background_test_gap)


func build_log() -> void:
	log_panel = PanelContainer.new()
	log_panel.add_theme_stylebox_override("panel", make_panel_style(0.82))
	log_panel.custom_minimum_size = Vector2(0, LOG_COLLAPSED_HEIGHT)

	# The log is the only area that expands vertically for now.
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


func toggle_log_size() -> void:
	# Borderless windows do not have native resize handles.
	# This gives us a controlled way to test a larger combat log while keeping the compact mode.
	is_log_expanded = not is_log_expanded

	var next_size := EXPANDED_WINDOW_SIZE if is_log_expanded else INITIAL_WINDOW_SIZE
	var next_log_height := LOG_EXPANDED_HEIGHT if is_log_expanded else LOG_COLLAPSED_HEIGHT

	DisplayServer.window_set_size(next_size)
	log_panel.custom_minimum_size = Vector2(0, next_log_height)
	log_toggle_button.text = "Log -" if is_log_expanded else "Log +"

	call_deferred("update_layout_bounds")


func on_top_panel_gui_input(event: InputEvent) -> void:
	# Borderless windows have no native drag area.
	# This makes the custom top panel behave like a small title bar.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_dragging_window = event.pressed
		if is_dragging_window:
			drag_mouse_start = DisplayServer.mouse_get_position()
			drag_window_start = DisplayServer.window_get_position()


func update_layout_bounds() -> void:
	if root_box == null:
		return

	var viewport_size := get_viewport_rect().size
	var content_width := minf(CONTENT_WIDTH, maxf(320.0, viewport_size.x - WINDOW_MARGIN * 2.0))
	var content_height := maxf(220.0, viewport_size.y - WINDOW_MARGIN * 2.0)

	root_box.position = Vector2(WINDOW_MARGIN, WINDOW_MARGIN)
	root_box.size = Vector2(content_width, content_height)

	# The passthrough polygon depends on the final Control sizes, so update it after layout.
	call_deferred("update_mouse_passthrough_polygon")


func update_mouse_passthrough_polygon() -> void:
	if top_panel == null or battlefield_panel == null or log_panel == null:
		return

	# Godot can pass mouse events outside this polygon to the windows behind it.
	# Instead of using one big rectangle, we trace the top bar, the combat panel,
	# and the log panel with a tiny left-side bridge between them.
	# That leaves most of the transparent gap between combat and log clickable.
	var top_rect := Rect2(top_panel.global_position, top_panel.size).grow(2.0)
	var battle_rect := Rect2(battlefield_panel.global_position, battlefield_panel.size).grow(2.0)
	var log_rect := Rect2(log_panel.global_position, log_panel.size).grow(2.0)

	var x0 := minf(top_rect.position.x, minf(battle_rect.position.x, log_rect.position.x))
	var x1 := maxf(top_rect.end.x, maxf(battle_rect.end.x, log_rect.end.x))
	var bridge_x := x0 + 6.0

	get_window().mouse_passthrough_polygon = PackedVector2Array([
		Vector2(x0, top_rect.position.y),
		Vector2(x1, top_rect.position.y),
		Vector2(x1, top_rect.end.y),
		Vector2(bridge_x, top_rect.end.y),
		Vector2(bridge_x, battle_rect.position.y),
		Vector2(x1, battle_rect.position.y),
		Vector2(x1, battle_rect.end.y),
		Vector2(bridge_x, battle_rect.end.y),
		Vector2(bridge_x, log_rect.position.y),
		Vector2(x1, log_rect.position.y),
		Vector2(x1, log_rect.end.y),
		Vector2(x0, log_rect.end.y),
		Vector2(x0, top_rect.position.y),
	])


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
	status_label.text = "W%s | P:%s/4 | E:%s" % [wave, get_alive(party).size(), get_alive(enemies).size()]
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
		card.custom_minimum_size = Vector2(COMBATANT_CARD_WIDTH, COMBATANT_CARD_HEIGHT)
		card.add_theme_stylebox_override("panel", make_card_style(combatant))
		container.add_child(card)

		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
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
