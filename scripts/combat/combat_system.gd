extends RefCounted
class_name CombatSystem

const CombatantScript := preload("res://scripts/combat/combatant.gd")

# CombatSystem owns the current run state: party, enemies, wave, combat log,
# and combat events. It does not know anything about nodes or animation.
# Main.gd and CombatStage.gd decide how to display this data.

const MELEE_RANGE := 34.0
const MENDER_RANGE := 150.0
const ARCANIST_RANGE := 235.0
const WAVE_TRANSITION_DELAY := 1.15

var party: Array[Combatant] = []
var enemies: Array[Combatant] = []
var wave: int = 1
var combat_started: bool = false
var log_entries: Array[String] = []
var visual_events: Array[Dictionary] = []
var wave_transition_timer := 0.0

var max_log_lines: int = 80
var next_combatant_id: int = 1


func _init(_max_log_lines: int = 80) -> void:
	max_log_lines = _max_log_lines


func start_new_run() -> void:
	wave = 1
	next_combatant_id = 1
	log_entries.clear()
	visual_events.clear()
	wave_transition_timer = 0.0

	# Four fixed archetypes for the first MVP.
	# attack_style and attack_range are visual/combat intent. The 2D stage decides
	# how to move actors until they are close enough to perform their action.
	party = [
		create_combatant("Vanguard", "Tank", 120, 9, 5, 0, 1.4, false, "vanguard", "melee", MELEE_RANGE),
		create_combatant("Striker", "DPS", 75, 17, 1, 0, 1.0, false, "striker", "melee", MELEE_RANGE),
		create_combatant("Mender", "Healer", 70, 7, 1, 15, 1.7, false, "mender", "ranged", MENDER_RANGE),
		create_combatant("Arcanist", "Mage", 62, 20, 0, 0, 1.8, false, "arcanist", "ranged", ARCANIST_RANGE),
	]

	spawn_wave(wave)
	combat_started = true
	push_log("The Ash Company enters the first ruin.")


func create_combatant(
	display_name: String,
	role: String,
	max_hp: int,
	attack: int,
	defense: int,
	heal_power: int,
	speed: float,
	is_enemy: bool,
	visual_key: String,
	attack_style: String,
	attack_range: float
) -> Combatant:
	var combatant: Combatant = CombatantScript.new(
		display_name,
		role,
		max_hp,
		attack,
		defense,
		heal_power,
		speed,
		is_enemy,
		visual_key,
		attack_style,
		attack_range
	)
	combatant.combatant_id = next_combatant_id
	next_combatant_id += 1
	return combatant


func tick(delta: float) -> bool:
	# Returns true when combat state changed and the UI should refresh.
	if not combat_started:
		return false

	# Lose condition: every party member is dead.
	if get_alive(party).is_empty():
		combat_started = false
		push_log("The Ash Company fell on wave %s." % wave)
		return true

	# After a wave is cleared, the party keeps walking for a short moment before
	# the next blocking group enters from the left. This makes the stage feel like
	# a lane instead of teleporting enemies onto the party.
	if wave_transition_timer > 0.0:
		wave_transition_timer = maxf(0.0, wave_transition_timer - delta)
		if wave_transition_timer <= 0.0:
			wave += 1
			spawn_wave(wave)
			push_log("Wave %s blocks the road." % wave)
		return true

	# Wave clear: enemies are gone, then the party gets a short walking window
	# before the next wave appears from off-screen.
	if get_alive(enemies).is_empty():
		wave_transition_timer = WAVE_TRANSITION_DELAY
		push_log("The Ash Company pushes forward.")
		return true

	var changed := false

	# Party members act automatically when their action timer reaches their speed value.
	for hero in get_alive(party):
		hero.action_timer += delta
		if hero.action_timer >= hero.speed:
			hero.action_timer = 0.0
			party_action(hero)
			changed = true

	# Enemies use the same timer system as the party.
	for enemy in get_alive(enemies):
		enemy.action_timer += delta
		if enemy.action_timer >= enemy.speed:
			enemy.action_timer = 0.0
			enemy_action(enemy)
			changed = true

	return changed


func spawn_wave(current_wave: int) -> void:
	# Enemy count slowly increases, but is capped so the window stays readable.
	var enemy_count := mini(2 + int(current_wave / 2), 5)
	enemies.clear()

	for index in enemy_count:
		var hp := 28 + current_wave * 8 + index * 3
		var atk := 5 + current_wave * 2
		var def := int(current_wave / 3)
		var speed := maxf(0.8, 1.8 - current_wave * 0.03)
		enemies.append(create_combatant(
			"Ash Slime %s" % (index + 1),
			"Enemy",
			hp,
			atk,
			def,
			0,
			speed,
			true,
			"slime",
			"melee",
			MELEE_RANGE
		))


func party_action(hero: Combatant) -> void:
	# Mender tries to heal before attacking.
	# The 72% threshold is arbitrary for now; later this can become a build/stat setting.
	if hero.display_name == "Mender":
		var wounded := get_most_wounded_ally()
		if wounded != null and wounded.hp_percent() < 0.72:
			var amount := hero.heal_power + randi_range(0, 4)
			wounded.heal(amount)
			push_log("Mender heals %s for %s." % [wounded.display_name, amount])
			push_visual_event("heal", hero, wounded, amount)
			return

	var target := get_first_alive(enemies)
	if target == null:
		return

	var damage := calculate_damage(hero.attack, target.defense)
	target.receive_damage(damage)
	push_log("%s hits %s for %s." % [hero.display_name, target.display_name, damage])
	push_visual_event("attack", hero, target, damage)

	if not target.is_alive():
		push_log("%s is defeated." % target.display_name)


func enemy_action(enemy: Combatant) -> void:
	var target := get_enemy_target()
	if target == null:
		return

	var damage := calculate_damage(enemy.attack, target.defense)
	target.receive_damage(damage)
	push_log("%s strikes %s for %s." % [enemy.display_name, target.display_name, damage])
	push_visual_event("attack", enemy, target, damage)

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
		return a.hp_percent() < b.hp_percent()
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


func push_log(message: String) -> void:
	# New messages go to the bottom.
	# This matches the scrollbar behavior: the log follows the newest line.
	log_entries.push_back(message)
	if log_entries.size() > max_log_lines:
		log_entries.pop_front()


func push_visual_event(event_type: String, actor: Combatant, target: Combatant, amount: int) -> void:
	# Visual events are intentionally data-only so CombatSystem stays UI-free.
	# amount is used only for visual feedback; damage/healing has already been
	# applied to the combat data before this event is consumed by CombatStage.
	visual_events.append({
		"type": event_type,
		"actor_id": actor.combatant_id,
		"target_id": target.combatant_id,
		"attack_style": actor.attack_style,
		"attack_range": actor.attack_range,
		"amount": amount,
		"target_died": not target.is_alive(),
	})


func consume_visual_events() -> Array[Dictionary]:
	var events := visual_events.duplicate()
	visual_events.clear()
	return events
