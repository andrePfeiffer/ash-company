extends RefCounted
class_name Combatant

# Combatant is a small data object used by the combat system.
# It does not know anything about UI, scenes, cards, or windows.

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


func hp_percent() -> float:
	if max_hp <= 0:
		return 0.0
	return float(hp) / float(max_hp)


func receive_damage(amount: int) -> void:
	# Keep HP clamped so UI and combat rules never see negative health.
	hp = maxi(0, hp - amount)


func heal(amount: int) -> void:
	# Keep HP clamped so healing cannot exceed maximum health.
	hp = mini(max_hp, hp + amount)
