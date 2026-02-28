extends Node2D
## Arrow — flies toward a target. Supports piercing, silver arrows, and splash damage.

var speed: float = 500.0
var damage: float = 25.0
var target: Node2D = null
var gold_bonus: int = 0
var source_tower: Node2D = null
var pierce_count: int = 0
var is_silver: bool = false
var is_gold: bool = false
var splash_radius: float = 0.0
var _lifetime: float = 3.0
var _angle: float = 0.0
var _hit_targets: Array = []

func _process(delta: float) -> void:
	_lifetime -= delta
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
			if is_instance_valid(source_tower) and source_tower.has_method("register_kill"):
				source_tower.register_kill()
			if gold_bonus > 0:
				var main = get_tree().get_first_node_in_group("main")
				if main:
					main.add_gold(gold_bonus)

	# Splash damage to nearby enemies
	if splash_radius > 0.0:
		_apply_splash(t.global_position)

	# Pierce through to next enemy
	if pierce_count > 0:
		pierce_count -= 1
		target = _find_next_target()
		if not is_instance_valid(target):
			queue_free()
	else:
		queue_free()

func _apply_splash(center: Vector2) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy in _hit_targets:
			continue
		if enemy.has_method("is_targetable") and not enemy.is_targetable():
			continue
		if center.distance_to(enemy.global_position) < splash_radius:
			if enemy.has_method("take_damage"):
				var splash_dmg = damage * 0.4
				enemy.take_damage(splash_dmg)
				if is_instance_valid(source_tower) and source_tower.has_method("register_damage"):
					source_tower.register_damage(splash_dmg)

func _find_next_target() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist: float = 150.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy in _hit_targets:
			continue
		if enemy.has_method("is_targetable") and not enemy.is_targetable():
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest = enemy
			nearest_dist = dist
	return nearest

func _draw() -> void:
	var dir = Vector2.from_angle(_angle)
	var perp = dir.rotated(PI / 2.0)

	if is_gold:
		# Gold arrow — "The Final Arrow" — gleaming gold with shimmer
		# Shaft — rich gold
		draw_line(-dir * 10.0, dir * 7.0, Color(0.95, 0.85, 0.30), 2.5)
		draw_line(-dir * 9.0, dir * 6.0, Color(1.0, 0.92, 0.45, 0.5), 1.2)
		# Arrowhead — bright gold
		var head_pts_g = PackedVector2Array([
			dir * 10.0,
			dir * 4.0 + perp * 4.0,
			dir * 5.0,
			dir * 4.0 - perp * 4.0,
		])
		draw_colored_polygon(head_pts_g, Color(1.0, 0.88, 0.25))
		draw_line(dir * 10.0, dir * 5.5, Color(1.0, 1.0, 0.7, 0.7), 1.0)
		# Fletching — gold
		draw_line(-dir * 8.0, -dir * 5.0 + perp * 3.5, Color(1.0, 0.90, 0.35), 2.0)
		draw_line(-dir * 8.0, -dir * 5.0 - perp * 3.5, Color(1.0, 0.90, 0.35), 2.0)
		# Gold glow
		draw_circle(Vector2.ZERO, 9.0, Color(1.0, 0.88, 0.2, 0.25))
		draw_circle(dir * 6.0, 5.0, Color(1.0, 0.95, 0.4, 0.4))
		# Shimmer sparkles
		var _t = fmod(global_position.x + global_position.y, 10.0)
		for si in range(3):
			var sp = dir * (float(si) * 4.0 - 4.0) + perp * sin(_t + float(si) * 2.0) * 3.0
			draw_circle(sp, 1.5, Color(1.0, 1.0, 0.8, 0.3 + sin(_t * 3.0 + float(si)) * 0.15))
	elif is_silver:
		# Silver arrow — "The Silver Arrow" from the Sheriff's tournament
		# Shaft — white silver
		draw_line(-dir * 10.0, dir * 7.0, Color(0.88, 0.82, 0.6), 2.2)
		# Arrowhead — red gold
		var head_pts = PackedVector2Array([
			dir * 9.0,
			dir * 4.0 + perp * 3.5,
			dir * 5.0,
			dir * 4.0 - perp * 3.5,
		])
		draw_colored_polygon(head_pts, Color(0.95, 0.8, 0.25))
		draw_line(dir * 9.0, dir * 5.0, Color(1.0, 0.92, 0.5, 0.7), 0.8)
		# Fletching — silver white
		draw_line(-dir * 8.0, -dir * 5.0 + perp * 3.0, Color(0.92, 0.9, 0.95), 1.8)
		draw_line(-dir * 8.0, -dir * 5.0 - perp * 3.0, Color(0.92, 0.9, 0.95), 1.8)
		# Glow
		draw_circle(Vector2.ZERO, 7.0, Color(1.0, 0.92, 0.4, 0.2))
		draw_circle(dir * 6.0, 4.0, Color(1.0, 0.95, 0.6, 0.35))
	else:
		# Normal arrow — ash shaft, iron broadhead, goose fletching
		draw_line(-dir * 10.0, dir * 7.0, Color(0.6, 0.45, 0.25), 1.8)
		# Broadhead
		draw_line(dir * 7.0, dir * 3.5 + perp * 2.5, Color(0.5, 0.5, 0.55), 1.5)
		draw_line(dir * 7.0, dir * 3.5 - perp * 2.5, Color(0.5, 0.5, 0.55), 1.5)
		# Fletching
		draw_line(-dir * 8.0, -dir * 5.5 + perp * 2.5, Color(0.8, 0.2, 0.15), 1.3)
		draw_line(-dir * 8.0, -dir * 5.5 - perp * 2.5, Color(0.8, 0.2, 0.15), 1.3)

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
						var off = -dir * (12.0 + tj * 8.0)
						draw_circle(off, 3.0 - tj * 0.5, Color(tc.r, tc.g, tc.b, 0.5 - tj * 0.12))
					break
