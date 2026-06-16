extends Control

# Main.gd now focuses on window behavior and UI updates.
# Combat rules and combatant data live in scripts/combat/.
# Card layout lives in scenes/combatant_card.tscn.
# Later we can split window behavior into its own script too.

const COMBAT_SYSTEM_SCRIPT := preload("res://scripts/combat/combat_system.gd")
const COMBATANT_CARD_SCENE := preload("res://scenes/combatant_card.tscn")

const INITIAL_WINDOW_SIZE := Vector2i(960, 300)
const EXPANDED_WINDOW_SIZE := Vector2i(960, 520)
const CONTENT_WIDTH := 944.0
const WINDOW_MARGIN := 8.0
const BATTLEFIELD_HEIGHT := 90.0
const BACKGROUND_TEST_GAP_HEIGHT := 40.0
const LOG_COLLAPSED_HEIGHT := 92.0
const LOG_EXPANDED_HEIGHT := 300.0
const MAX_LOG_LINES := 80

# Combat state is owned by CombatSystem.
var combat_system: CombatSystem

# UI references from scenes/main.tscn.
# The % syntax works because those scene nodes are marked as unique names.
@onready var content_layer: Control = %ContentLayer
@onready var root_box: VBoxContainer = %RootBox
@onready var top_panel: PanelContainer = %TopPanel
@onready var battlefield_panel: PanelContainer = %BattlefieldPanel
@onready var background_test_gap: Control = %BackgroundTestGap
@onready var party_box: HBoxContainer = %PartyBox
@onready var enemy_box: HBoxContainer = %EnemyBox
@onready var log_panel: PanelContainer = %LogPanel
@onready var log_label: RichTextLabel = %LogLabel
@onready var status_label: Label = %StatusLabel
@onready var log_toggle_button: Button = %LogToggleButton
@onready var restart_button: Button = %RestartButton
@onready var close_button: Button = %CloseButton

# Borderless windows do not have a native title bar, so we implement simple drag behavior.
var is_log_expanded := false
var is_dragging_window := false
var drag_mouse_start := Vector2i.ZERO
var drag_window_start := Vector2i.ZERO


func _ready() -> void:
	combat_system = COMBAT_SYSTEM_SCRIPT.new(MAX_LOG_LINES)

	setup_window()
	configure_scene_ui()
	connect_ui_signals()

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
	if combat_system == null:
		return

	# CombatSystem returns true only when something changed.
	# That keeps Main.gd from rebuilding the UI more often than needed.
	if combat_system.tick(delta):
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


func configure_scene_ui() -> void:
	# ContentLayer does not draw anything by itself. The real UI is inside RootBox,
	# so transparent areas can be passed through to the desktop.
	content_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Most layout values now live in the scene. These runtime values stay here
	# because they are behavior/settings that the script updates while the game runs.
	root_box.custom_minimum_size = Vector2(CONTENT_WIDTH, 0)

	top_panel.add_theme_stylebox_override("panel", make_panel_style(0.78))
	battlefield_panel.add_theme_stylebox_override("panel", make_panel_style(0.72))
	log_panel.add_theme_stylebox_override("panel", make_panel_style(0.82))

	battlefield_panel.custom_minimum_size = Vector2(0, BATTLEFIELD_HEIGHT)
	battlefield_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	background_test_gap.custom_minimum_size = Vector2(0, BACKGROUND_TEST_GAP_HEIGHT)
	background_test_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE

	log_panel.custom_minimum_size = Vector2(0, LOG_COLLAPSED_HEIGHT)
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	status_label.clip_text = true

	# This is the important part for the combat log.
	# scroll_active enables the scrollbar, and scroll_following keeps the newest line visible.
	log_label.bbcode_enabled = true
	log_label.fit_content = false
	log_label.scroll_active = true
	log_label.scroll_following = true
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL


func connect_ui_signals() -> void:
	# The scene owns the buttons; the script owns their behavior.
	top_panel.gui_input.connect(on_top_panel_gui_input)
	log_toggle_button.pressed.connect(toggle_log_size)
	restart_button.pressed.connect(start_new_run)
	close_button.pressed.connect(func() -> void:
		get_tree().quit()
	)


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
	combat_system.start_new_run()
	update_ui()


func update_ui() -> void:
	if combat_system == null:
		return

	status_label.text = "W%s | P:%s/4 | E:%s" % [
		combat_system.wave,
		combat_system.get_alive(combat_system.party).size(),
		combat_system.get_alive(combat_system.enemies).size(),
	]

	rebuild_combatant_cards(party_box, combat_system.party)
	rebuild_combatant_cards(enemy_box, combat_system.enemies)
	log_label.text = "\n".join(combat_system.log_entries)


func rebuild_combatant_cards(container: HBoxContainer, combatants: Array[Combatant]) -> void:
	# We still rebuild the cards every state update for simplicity, but each card layout
	# now lives in its own scene. The next optimization will be to keep cards alive
	# and only update their data when combat state changes.
	for child in container.get_children():
		child.queue_free()

	for combatant in combatants:
		var card := COMBATANT_CARD_SCENE.instantiate()
		container.add_child(card)
		card.update_from_combatant(
			combatant.display_name,
			combatant.role,
			combatant.hp,
			combatant.max_hp,
			combatant.is_alive()
		)
