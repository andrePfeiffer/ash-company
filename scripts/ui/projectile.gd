extends Node2D
class_name StageProjectile

const PROJECTILE_SPEED := 420.0
const MIN_TRAVEL_TIME := 0.18
const MAX_TRAVEL_TIME := 0.65

@onready var sprite: Sprite2D = %Sprite

var hit_callback: Callable = Callable()


func fire(from_position: Vector2, to_position: Vector2, color: Color, _hit_callback: Callable) -> void:
	position = from_position
	hit_callback = _hit_callback
	sprite.modulate = color

	var distance := from_position.distance_to(to_position)
	var travel_time := clampf(distance / PROJECTILE_SPEED, MIN_TRAVEL_TIME, MAX_TRAVEL_TIME)

	var tween := create_tween()
	tween.tween_property(self, "position", to_position, travel_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func() -> void:
		if hit_callback.is_valid():
			hit_callback.call()
		queue_free()
	)
