extends Node2D
## Bullet — flies toward a target and deals damage on contact.

var speed: float = 450.0
var damage: float = 25.0
var target: Node2D = null
var _lifetime: float = 3.0

func _process(delta: float) -> void:
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()
		return

	if not is_instance_valid(target):
		queue_free()
		return

	var dir = global_position.direction_to(target.global_position)
	position += dir * speed * delta

	if global_position.distance_to(target.global_position) < 12.0:
		if target.has_method("take_damage"):
			target.take_damage(damage)
		queue_free()

func _draw() -> void:
	# Bullet glow
	draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.85, 0.2, 0.5))
	# Bullet core
	draw_circle(Vector2.ZERO, 3.0, Color(1.0, 0.95, 0.6))
