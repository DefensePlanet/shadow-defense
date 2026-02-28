extends Node2D
## Scrooge's Coin — spinning gold coin projectile. Low damage but triggers gold bonus.

var speed: float = 350.0
var damage: float = 10.0
var target: Node2D = null
var gold_bonus: int = 0
var source_tower: Node2D = null
var _lifetime: float = 3.0
var _angle: float = 0.0
var _spin: float = 0.0

func _process(delta: float) -> void:
	_lifetime -= delta
	_spin += delta * 10.0
	if _lifetime <= 0.0:
		queue_free()
		return

	if not is_instance_valid(target):
		queue_free()
		return

	var dir = global_position.direction_to(target.global_position)
	_angle = dir.angle()
	position += dir * speed * delta

	if global_position.distance_to(target.global_position) < 12.0:
		_hit_target(target)

	queue_redraw()

func _hit_target(t: Node2D) -> void:
	if t.has_method("take_damage"):
		var will_kill = t.health - damage <= 0.0
		t.take_damage(damage)
		if is_instance_valid(source_tower) and source_tower.has_method("register_damage"):
			source_tower.register_damage(damage)
		if will_kill:
			if is_instance_valid(source_tower) and source_tower.has_method("register_kill"):
				source_tower.register_kill()
			if gold_bonus > 0:
				var main = get_tree().get_first_node_in_group("main")
				if main:
					main.add_gold(gold_bonus)

	queue_free()

func _draw() -> void:
	var spin_scale = abs(cos(_spin))

	# Gold coin — spinning
	var hw = 4.0 * spin_scale + 1.0

	# Coin body
	draw_circle(Vector2.ZERO, hw, Color(0.85, 0.72, 0.2))

	# Coin shine
	if spin_scale > 0.4:
		draw_circle(Vector2(-1, -1), hw * 0.5, Color(1.0, 0.92, 0.4, 0.5))

	# Coin edge ring
	draw_arc(Vector2.ZERO, hw, 0, TAU, 12, Color(0.7, 0.58, 0.12), 1.0)

	# "£" or face detail when face is showing
	if spin_scale > 0.6:
		draw_circle(Vector2.ZERO, 1.5, Color(0.7, 0.58, 0.15))

	# Trail (golden sparkle)
	var dir = Vector2.from_angle(_angle)
	draw_line(-dir * 6.0, Vector2.ZERO, Color(0.85, 0.72, 0.2, 0.3), 2.0)
