extends Node2D
class_name CombatantActor

# CombatantActor is a visual-only state machine.
# CombatSystem decides that an attack/heal happened; this node decides how that
# action is presented on the 2D stage.

enum ActorState {
	IDLE,
	MOVING_TO_RANGE,
	MELEE_STRIKE,
	CASTING,
	DYING,
}

const MOVE_SPEED := 82.0
const MELEE_STRIKE_TIME := 0.34
const MELEE_IMPACT_TIME := 0.16
const CAST_TIME := 0.48
const CAST_IMPACT_TIME := 0.26
const IDLE_BOB_SPEED := 5.2
const IDLE_BOB_AMOUNT := 1.6
const PARTY_ADVANCE_SPEED := 44.0
const LEFT_ADVANCE_LIMIT := 210.0
const ENEMY_SPAWN_X := -44.0

const HERO_FRAMES: SpriteFrames = preload("res://resources/actor_sprite_frames.tres")
const SLIME_FRAMES: SpriteFrames = preload("res://resources/slime_sprite_frames.tres")

@onready var sprite: AnimatedSprite2D = %Sprite
@onready var name_label: Label = %NameLabel
@onready var hp_bar: ProgressBar = %HpBar

var combatant_id: int = 0
var home_position: Vector2 = Vector2.ZERO
var hold_position: Vector2 = Vector2.ZERO
var has_hold_position := false
var has_been_placed := false
var is_enemy := false
var is_dying := false

var state: int = ActorState.IDLE
var state_timer := 0.0
var impact_done := false
var phase_offset := 0.0

var target_actor: CombatantActor = null
var current_action_type := ""
var current_attack_range := 34.0
var impact_callback: Callable = Callable()
var queued_actions: Array[Dictionary] = []


func _ready() -> void:
	phase_offset = randf() * TAU
	play_animation("idle")


func _process(delta: float) -> void:
	if is_dying:
		return

	match state:
		ActorState.IDLE:
			process_idle(delta)
		ActorState.MOVING_TO_RANGE:
			process_moving_to_range(delta)
		ActorState.MELEE_STRIKE:
			process_melee_strike(delta)
		ActorState.CASTING:
			process_casting(delta)
		ActorState.DYING:
			pass


func update_from_combatant(combatant: Combatant) -> void:
	if is_dying:
		return

	combatant_id = combatant.combatant_id
	is_enemy = combatant.is_enemy

	name_label.text = combatant.display_name
	hp_bar.max_value = combatant.max_hp
	hp_bar.value = combatant.hp

	# Swap the visual resource instead of tinting every enemy into a hero shape.
	# Heroes use the humanoid placeholder; enemies use a classic first-level slime.
	var desired_frames: SpriteFrames = SLIME_FRAMES if combatant.is_enemy else HERO_FRAMES
	if sprite.sprite_frames != desired_frames:
		sprite.sprite_frames = desired_frames
		play_animation("idle")

	# The party walks from right to left, so heroes face left and enemies face right.
	sprite.flip_h = not combatant.is_enemy
	sprite.modulate = color_for_visual_key(combatant.visual_key)


func set_home_position(next_home_position: Vector2) -> void:
	if not has_been_placed:
		home_position = next_home_position
		# Heroes start in formation on the right. New enemies enter from off-screen
		# on the left and walk into their blocking positions instead of teleporting.
		if is_enemy:
			position = Vector2(ENEMY_SPAWN_X, home_position.y)
		else:
			position = home_position
		hold_position = position
		has_been_placed = true
		return

	if is_enemy:
		# Enemies can shift as the blocking group changes.
		home_position = next_home_position
		return

	# Heroes travel from right to left. Formation updates should never pull a hero
	# backwards to the right, especially after a frontliner dies.
	var next_x := minf(minf(next_home_position.x, home_position.x), position.x)
	home_position = Vector2(next_x, next_home_position.y)


func clear_engagement() -> void:
	# Used when a wave/reset needs the actor to resume formation movement.
	has_hold_position = false
	hold_position = home_position


func advance_left(delta: float) -> void:
	# Between waves the party keeps walking from right to left, like a small
	# side-scroller. This only runs while the actor is idle; attacks and casts keep
	# their own movement/state machine.
	if is_enemy or is_dying or state != ActorState.IDLE or not queued_actions.is_empty():
		return

	var base_position := hold_position if has_hold_position else position
	var next_x := maxf(LEFT_ADVANCE_LIMIT, base_position.x - PARTY_ADVANCE_SPEED * delta)
	var next_position := Vector2(next_x, home_position.y)

	has_hold_position = true
	hold_position = next_position
	home_position = Vector2(minf(home_position.x, next_position.x), home_position.y)

	var bob := sin(Time.get_ticks_msec() / 1000.0 * IDLE_BOB_SPEED + phase_offset) * IDLE_BOB_AMOUNT
	position = position.move_toward(next_position + Vector2(0, bob), MOVE_SPEED * delta)
	play_animation("walk")

func queue_melee_attack(target: CombatantActor, attack_range: float, callback: Callable) -> void:
	queue_targeted_action("melee", target, attack_range, callback)


func queue_ranged_action(target: CombatantActor, attack_range: float, callback: Callable) -> void:
	queue_targeted_action("ranged", target, attack_range, callback)


func queue_targeted_action(action_type: String, target: CombatantActor, attack_range: float, callback: Callable) -> void:
	if is_dying or target == null or not is_instance_valid(target):
		return

	queued_actions.append({
		"type": action_type,
		"target": target,
		"range": attack_range,
		"callback": callback,
	})
	start_next_action_if_idle()


func play_hit_flash() -> void:
	if is_dying:
		return

	var original_modulate := modulate
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.4, 1.4, 1.4, 1.0), 0.05)
	tween.tween_property(self, "modulate", original_modulate, 0.12)


func play_death_and_free() -> void:
	if is_dying:
		return

	is_dying = true
	state = ActorState.DYING
	queued_actions.clear()
	play_animation("hurt")

	var tween := create_tween()
	tween.tween_interval(0.08)
	tween.tween_property(self, "modulate:a", 0.0, 0.26)
	tween.parallel().tween_property(self, "position:y", position.y + 10.0, 0.26)
	tween.parallel().tween_property(self, "scale", Vector2(0.72, 0.72), 0.26)
	tween.finished.connect(func() -> void:
		queue_free()
	)


func get_hit_global_position() -> Vector2:
	return global_position + Vector2(0, -28)


func get_projectile_spawn_global_position() -> Vector2:
	var x_offset := 16.0 if is_enemy else -16.0
	return global_position + Vector2(x_offset, -20)


func process_idle(delta: float) -> void:
	if not queued_actions.is_empty():
		start_next_action_if_idle()
		return

	var base_position := hold_position if has_hold_position else home_position
	var bob := sin(Time.get_ticks_msec() / 1000.0 * IDLE_BOB_SPEED + phase_offset) * IDLE_BOB_AMOUNT
	var target_position := base_position + Vector2(0, bob)
	position = position.move_toward(target_position, MOVE_SPEED * delta)

	if position.distance_to(target_position) > 3.5:
		play_animation("walk")
	else:
		play_animation("idle")


func process_moving_to_range(delta: float) -> void:
	if target_actor == null or not is_instance_valid(target_actor):
		finish_action_without_impact()
		return

	var attack_position := get_attack_position()
	position = position.move_toward(attack_position, MOVE_SPEED * delta)
	play_animation("walk")

	if position.distance_to(attack_position) <= 3.0:
		state_timer = 0.0
		impact_done = false
		if current_action_type == "melee":
			state = ActorState.MELEE_STRIKE
			play_animation("attack")
		else:
			state = ActorState.CASTING
			play_animation("cast")


func process_melee_strike(delta: float) -> void:
	state_timer += delta

	if not impact_done and state_timer >= MELEE_IMPACT_TIME:
		impact_done = true
		call_impact_callback()

	if state_timer >= MELEE_STRIKE_TIME:
		# Melee actors stay engaged instead of returning to their formation slot.
		has_hold_position = true
		hold_position = position
		finish_action_without_impact()


func process_casting(delta: float) -> void:
	state_timer += delta

	if not impact_done and state_timer >= CAST_IMPACT_TIME:
		impact_done = true
		call_impact_callback()

	if state_timer >= CAST_TIME:
		# Ranged actors also keep their casting position. This lets the Mender stop
		# closer than the Arcanist while still attacking from range.
		has_hold_position = true
		hold_position = position
		finish_action_without_impact()


func start_next_action_if_idle() -> void:
	if state != ActorState.IDLE or queued_actions.is_empty():
		return

	var action: Dictionary = queued_actions.pop_front()
	var raw_target: Variant = action.get("target", null)

	# A target may have died and been freed before this queued visual action starts.
	# Check validity before casting, otherwise Godot can throw "Trying to cast a freed object".
	if not is_instance_valid(raw_target):
		finish_action_without_impact()
		return

	target_actor = raw_target as CombatantActor
	if target_actor == null:
		finish_action_without_impact()
		return

	current_action_type = action.get("type", "melee")
	current_attack_range = float(action.get("range", 34.0))
	impact_callback = action.get("callback", Callable())
	impact_done = false
	state_timer = 0.0
	state = ActorState.MOVING_TO_RANGE
	play_animation("walk")


func finish_action_without_impact() -> void:
	state = ActorState.IDLE
	state_timer = 0.0
	impact_done = false
	target_actor = null
	current_action_type = ""
	impact_callback = Callable()
	play_animation("idle")
	start_next_action_if_idle()


func call_impact_callback() -> void:
	if impact_callback.is_valid():
		impact_callback.call()


func get_attack_position() -> Vector2:
	if target_actor == null or not is_instance_valid(target_actor):
		return home_position

	# The party travels from right to left. Party members stand to the right of
	# their target; enemies stand to the left of their target. Heroes should not
	# move backwards to the right for self-heals or formation changes.
	var desired_x := target_actor.position.x - current_attack_range if is_enemy else target_actor.position.x + current_attack_range
	if not is_enemy:
		desired_x = minf(desired_x, position.x)

	return Vector2(desired_x, target_actor.position.y)


func play_animation(animation_name: String) -> void:
	if sprite.animation == animation_name and sprite.is_playing():
		return

	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_name):
		sprite.play(animation_name)


func color_for_visual_key(visual_key: String) -> Color:
	match visual_key:
		"vanguard":
			return Color(0.45, 0.75, 1.0, 1.0)
		"striker":
			return Color(1.0, 0.82, 0.35, 1.0)
		"mender":
			return Color(0.45, 1.0, 0.55, 1.0)
		"arcanist":
			return Color(0.78, 0.55, 1.0, 1.0)
		"slime":
			return Color(1.0, 1.0, 1.0, 1.0)
		"ashling":
			return Color(1.0, 0.35, 0.3, 1.0)
		_:
			return Color.WHITE
