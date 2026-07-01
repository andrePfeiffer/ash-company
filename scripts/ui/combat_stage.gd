extends Control
class_name CombatStage

# CombatStage owns the visual 2D fight lane.
# It receives Combatant data from Main.gd and visual events from CombatSystem.
# It does not decide damage, healing, targeting, or wave progression.

const ACTOR_SCENE: PackedScene = preload("res://scenes/combatant_actor.tscn")
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/projectile.tscn")
const FLOATING_NUMBER_SCENE: PackedScene = preload("res://scenes/floating_number.tscn")

const EDGE_PADDING := 74.0
const ACTOR_SPACING := 50.0
const GROUND_Y_RATIO := 0.76
const FALLBACK_STAGE_SIZE := Vector2(944.0, 132.0)

var is_party_advancing := false

@onready var actors_layer: Node2D = %ActorsLayer
@onready var projectiles_layer: Node2D = %ProjectilesLayer
@onready var floating_numbers_layer: Node2D = %FloatingNumbersLayer

var actors_by_id: Dictionary = {}


func _process(delta: float) -> void:
	if not is_party_advancing:
		return

	for actor_value in actors_by_id.values():
		var actor: CombatantActor = actor_value as CombatantActor
		if actor != null and is_instance_valid(actor) and not actor.is_enemy:
			actor.advance_left(delta)


func clear_stage() -> void:
	is_party_advancing = false
	for actor in actors_by_id.values():
		if is_instance_valid(actor):
			actor.queue_free()
	actors_by_id.clear()

	for child in projectiles_layer.get_children():
		child.queue_free()

	for child in floating_numbers_layer.get_children():
		child.queue_free()


func sync_combatants(party: Array[Combatant], enemies: Array[Combatant]) -> void:
	var active_ids: Array[int] = []
	var alive_party: Array[Combatant] = get_alive_combatants(party)
	var alive_enemies: Array[Combatant] = get_alive_combatants(enemies)

	# When there are no enemies alive, the party should keep walking forward until
	# the next group enters from the left.
	is_party_advancing = not alive_party.is_empty() and alive_enemies.is_empty()

	# Keep all combatants in active_ids, including dead ones. Dead actors are
	# removed by visual events after their hit/heal feedback is shown.
	for combatant in party:
		active_ids.append(combatant.combatant_id)

	for combatant in enemies:
		active_ids.append(combatant.combatant_id)

	for index in alive_party.size():
		var combatant: Combatant = alive_party[index]
		var actor: CombatantActor = ensure_actor(combatant)
		actor.set_home_position(get_party_position(index, alive_party.size()))
		actor.update_from_combatant(combatant)

	for index in alive_enemies.size():
		var combatant: Combatant = alive_enemies[index]
		var actor: CombatantActor = ensure_actor(combatant)
		actor.set_home_position(get_enemy_position(index, alive_enemies.size()))
		actor.update_from_combatant(combatant)

	for combatant_id in actors_by_id.keys():
		if not active_ids.has(combatant_id):
			var actor: CombatantActor = get_actor(combatant_id)
			actors_by_id.erase(combatant_id)
			if actor != null:
				actor.play_death_and_free()


func play_events(events: Array[Dictionary]) -> void:
	for event in events:
		var actor_id: int = int(event.get("actor_id", 0))
		var target_id: int = int(event.get("target_id", 0))
		var actor: CombatantActor = get_actor(actor_id)
		var target: CombatantActor = get_actor(target_id)

		if actor == null or target == null:
			continue

		match event.get("type"):
			"heal":
				queue_heal_event(actor, target, event)
			"attack":
				if event.get("attack_style") == "ranged":
					queue_ranged_attack_event(actor, target, event)
				else:
					queue_melee_attack_event(actor, target, event)


func queue_melee_attack_event(actor: CombatantActor, target: CombatantActor, event: Dictionary) -> void:
	var target_id: int = int(event.get("target_id", 0))
	var amount: int = int(event.get("amount", 0))
	var target_died: bool = bool(event.get("target_died", false))
	var attack_range: float = float(event.get("attack_range", 34.0))

	actor.queue_melee_attack(target, attack_range, func() -> void:
		show_hit_feedback_by_id(target_id, amount, target_died, false)
	)


func queue_ranged_attack_event(actor: CombatantActor, target: CombatantActor, event: Dictionary) -> void:
	var actor_id: int = int(event.get("actor_id", 0))
	var target_id: int = int(event.get("target_id", 0))
	var amount: int = int(event.get("amount", 0))
	var target_died: bool = bool(event.get("target_died", false))
	var attack_range: float = float(event.get("attack_range", 180.0))

	actor.queue_ranged_action(target, attack_range, func() -> void:
		spawn_projectile_between(
			actor_id,
			target_id,
			Color(0.65, 0.8, 1.0, 1.0),
			func() -> void:
				show_hit_feedback_by_id(target_id, amount, target_died, false)
		)
	)


func queue_heal_event(actor: CombatantActor, target: CombatantActor, event: Dictionary) -> void:
	var actor_id: int = int(event.get("actor_id", 0))
	var target_id: int = int(event.get("target_id", 0))
	var amount: int = int(event.get("amount", 0))
	var attack_range: float = float(event.get("attack_range", 150.0))

	actor.queue_ranged_action(target, attack_range, func() -> void:
		spawn_projectile_between(
			actor_id,
			target_id,
			Color(0.35, 1.0, 0.45, 1.0),
			func() -> void:
				show_hit_feedback_by_id(target_id, amount, false, true)
		)
	)


func ensure_actor(combatant: Combatant) -> CombatantActor:
	var existing_actor := get_actor(combatant.combatant_id)
	if existing_actor != null:
		return existing_actor

	var actor: CombatantActor = ACTOR_SCENE.instantiate() as CombatantActor
	actors_layer.add_child(actor)
	actors_by_id[combatant.combatant_id] = actor
	actor.tree_exited.connect(func() -> void:
		if actors_by_id.get(combatant.combatant_id) == actor:
			actors_by_id.erase(combatant.combatant_id)
	)
	actor.update_from_combatant(combatant)
	return actor


func get_actor(combatant_id: int) -> CombatantActor:
	if not actors_by_id.has(combatant_id):
		return null

	var candidate: Variant = actors_by_id[combatant_id]
	if not is_instance_valid(candidate):
		actors_by_id.erase(combatant_id)
		return null

	return candidate as CombatantActor


func spawn_projectile_between(actor_id: int, target_id: int, color: Color, hit_callback: Callable) -> void:
	var actor := get_actor(actor_id)
	var target := get_actor(target_id)
	if actor == null or target == null:
		# The target may have died before the projectile was spawned. In that case we
		# skip the projectile and run the feedback callback directly.
		if hit_callback.is_valid():
			hit_callback.call()
		return

	spawn_projectile(
		actor.get_projectile_spawn_global_position(),
		target.get_hit_global_position(),
		color,
		hit_callback
	)


func spawn_projectile(from_global_position: Vector2, to_global_position: Vector2, color: Color, hit_callback: Callable) -> void:
	var projectile: StageProjectile = PROJECTILE_SCENE.instantiate() as StageProjectile
	projectiles_layer.add_child(projectile)
	projectile.fire(
		projectiles_layer.to_local(from_global_position),
		projectiles_layer.to_local(to_global_position),
		color,
		hit_callback
	)


func show_hit_feedback_by_id(target_id: int, amount: int, target_died: bool, is_heal: bool) -> void:
	var target := get_actor(target_id)
	var hit_position := Vector2.ZERO

	if target != null:
		hit_position = target.get_hit_global_position()
		if not is_heal:
			target.play_hit_flash()
	else:
		hit_position = global_position + size / 2.0

	if is_heal:
		spawn_floating_number(hit_position, "+%s" % amount, Color(0.35, 1.0, 0.45, 1.0))
	else:
		spawn_floating_number(hit_position, "-%s" % amount, Color(1.0, 0.35, 0.25, 1.0))

	if target_died and target != null:
		actors_by_id.erase(target_id)
		target.play_death_and_free()


func spawn_floating_number(from_global_position: Vector2, text: String, color: Color) -> void:
	var floating_number: FloatingNumber = FLOATING_NUMBER_SCENE.instantiate() as FloatingNumber
	floating_numbers_layer.add_child(floating_number)
	floating_number.position = floating_numbers_layer.to_local(from_global_position)
	floating_number.show_value(text, color)


func get_party_position(index: int, count: int) -> Vector2:
	# Party starts on the right side and travels toward the left.
	# Index 0 is the Vanguard, so he is placed at the front of the party.
	var stage_size := get_safe_stage_size()
	var ground_y := stage_size.y * GROUND_Y_RATIO
	var back_x := stage_size.x - EDGE_PADDING
	var front_offset := float(count - 1 - index) * ACTOR_SPACING
	return Vector2(back_x - front_offset, ground_y)


func get_enemy_position(index: int, count: int) -> Vector2:
	# Enemies block the path on the left. Index 0 is the front enemy, closest to the party.
	var stage_size := get_safe_stage_size()
	var ground_y := stage_size.y * GROUND_Y_RATIO
	var front_x := EDGE_PADDING + float(count - 1) * ACTOR_SPACING
	return Vector2(front_x - float(index) * ACTOR_SPACING, ground_y)


func get_safe_stage_size() -> Vector2:
	# During the first frame, the Control may not have received its container size yet.
	# Using a fallback keeps actors from spawning around x=0 and walking in from the wrong side.
	return Vector2(maxf(size.x, FALLBACK_STAGE_SIZE.x), maxf(size.y, FALLBACK_STAGE_SIZE.y))


func get_alive_combatants(combatants: Array[Combatant]) -> Array[Combatant]:
	var alive: Array[Combatant] = []
	for combatant in combatants:
		if combatant.is_alive():
			alive.append(combatant)
	return alive
