extends Node2D
## Peter's Dagger — fast thrown dagger. Shadow variant is translucent. Supports pierce.

var speed: float = 450.0
var damage: float = 18.0
var target: Node2D = null
var gold_bonus: int = 0
var source_tower: Node2D = null
var is_shadow: bool = false
var pierce_count: int = 0
var _lifetime: float = 3.0
var _angle: float = 0.0
var _spin: float = 0.0
var _hit_targets: Array = []

func _process(delta: float) -> void:
	_lifetime -= delta
	_spin += delta * 15.0
	if _lifetime <= 0.0:
		queue_free()
		return

	if not is_instance_valid(target):
		if pierce_count > 0:
			target = _find_next_target()
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
	_hit_targets.append(t)
	if t.has_method("take_damage"):
		var will_kill = t.health - damage <= 0.0
		t.take_damage(damage)
		if is_instance_valid(source_tower) and source_tower.has_method("register_damage"):
			source_tower.register_damage(damage)
		if will_kill:
			if gold_bonus > 0:
				var main = get_tree().get_first_node_in_group("main")
				if main:
					main.add_gold(gold_bonus)

	if pierce_count > 0:
		pierce_count -= 1
		target = _find_next_target()
		if not is_instance_valid(target):
			queue_free()
	else:
		queue_free()

func _find_next_target() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist: float = 150.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy in _hit_targets:
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest = enemy
			nearest_dist = dist
	return nearest

func _draw() -> void:
	var dir = Vector2.from_angle(_angle)
	var perp = dir.rotated(PI / 2.0)
	var alpha = 0.4 if is_shadow else 1.0

	# Spinning dagger
	var spin_scale = cos(_spin)

	if is_shadow:
		# Shadow dagger — dark, translucent
		draw_line(-dir * 5.0, dir * 6.0, Color(0.15, 0.15, 0.2, alpha), 2.0)
		draw_line(dir * 4.0, dir * 7.0, Color(0.2, 0.2, 0.25, alpha), 2.5)
		# Shadow trail
		draw_line(-dir * 8.0, Vector2.ZERO, Color(0.1, 0.1, 0.15, 0.2), 3.0)
	else:
		# Normal dagger — steel blade
		# Handle
		draw_line(-dir * 5.0, -dir * 1.0, Color(0.45, 0.3, 0.15), 2.5)
		# Cross-guard
		draw_line(-dir * 1.0 + perp * 2.5 * spin_scale, -dir * 1.0 - perp * 2.5 * spin_scale, Color(0.6, 0.5, 0.2), 1.5)
		# Blade
		draw_line(-dir * 1.0, dir * 7.0, Color(0.7, 0.72, 0.78), 2.0)
		draw_line(dir * 3.0, dir * 7.0, Color(0.85, 0.87, 0.92), 1.2)
		# Blade tip
		draw_line(dir * 6.0, dir * 8.0, Color(0.8, 0.82, 0.88), 1.5)

	# Cosmetic trail
	var main = get_tree().get_first_node_in_group("main")
	if main and main.get("equipped_cosmetics") != null:
		var trail_id = main.equipped_cosmetics.get("trails", "")
		if trail_id != "":
			var trail_items = main.trophy_store_items.get("trails", [])
			for ti in trail_items:
				if ti["id"] == trail_id:
					var tc = ti["color"]
					for tj in range(4):
						var off = -dir * (10.0 + tj * 7.0)
						draw_circle(off, 3.0 - tj * 0.5, Color(tc.r, tc.g, tc.b, (0.5 - tj * 0.12) * alpha))
					break
