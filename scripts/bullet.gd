extends Node2D
## Bullet — flies toward a target and deals damage on contact.

var speed: float = 450.0
var damage: float = 25.0
var target: Node2D = null
var _lifetime: float = 3.0
var _angle: float = 0.0
var _trail: Array = []

func _process(delta: float) -> void:
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()
		return

	if not is_instance_valid(target):
		queue_free()
		return

	var dir = global_position.direction_to(target.global_position)
	_angle = dir.angle()
	position += dir * speed * delta

	# Trail positions
	_trail.push_front(Vector2.ZERO)
	if _trail.size() > 3:
		_trail.pop_back()
	for i in range(_trail.size()):
		_trail[i] -= dir * speed * delta

	if global_position.distance_to(target.global_position) < 12.0:
		if target.has_method("take_damage"):
			target.take_damage(damage, "physical")
		queue_free()

	queue_redraw()

func _draw() -> void:
	# Shrinking trail circles
	for ti in range(_trail.size()):
		var t_alpha = 1.0 - float(ti) / 3.0
		draw_circle(_trail[ti], 3.0 - float(ti) * 0.7, Color(1.0, 0.85, 0.2, t_alpha * 0.3))
	# Bullet glow
	draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.85, 0.2, 0.5))
	# Bullet core
	draw_circle(Vector2.ZERO, 3.0, Color(1.0, 0.95, 0.6))
