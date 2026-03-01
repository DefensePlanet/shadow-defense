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
var _trail: Array = []
var _trail_time: float = 0.0

func _process(delta: float) -> void:
	_trail_time += delta
	# Trail: store positions in local space (offset behind projectile)
	if is_instance_valid(target):
		_trail.push_front(Vector2.ZERO)
		if _trail.size() > 5:
			_trail.pop_back()
		# Age trail positions backward
		var dir = Vector2.from_angle(_angle)
		for i in range(_trail.size()):
			_trail[i] -= dir * speed * delta
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
		t.take_damage(damage, "physical")
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
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("report_aoe_impact"):
		var col = Color(1.0, 0.88, 0.25, 0.6) if is_gold else Color(0.7, 0.7, 0.75, 0.5)
		main.report_aoe_impact(center, splash_radius, col)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy in _hit_targets:
			continue
		if enemy.has_method("is_targetable") and not enemy.is_targetable():
			continue
		if center.distance_to(enemy.global_position) < splash_radius:
			if enemy.has_method("take_damage"):
				var splash_dmg = damage * 0.4
				enemy.take_damage(splash_dmg, "physical")
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

	# Default motion trail
	if is_gold or is_silver:
		# Golden/silver sparkle trail
		for ti in range(_trail.size()):
			var t_alpha = 1.0 - float(ti) / float(_trail.size())
			var sparkle_col = Color(1.0, 0.92, 0.4, t_alpha * 0.4) if is_gold else Color(0.9, 0.9, 1.0, t_alpha * 0.35)
			draw_circle(_trail[ti], 2.5 - float(ti) * 0.3, sparkle_col)
	else:
		# Normal arrow: fading ghost circles
		for ti in range(_trail.size()):
			var t_alpha = 1.0 - float(ti) / float(_trail.size())
			draw_circle(_trail[ti], 2.0 - float(ti) * 0.25, Color(0.6, 0.45, 0.25, t_alpha * 0.25))

	# Tier 4+ enhanced trail: extra sparkle particles behind arrow
	if is_instance_valid(source_tower) and source_tower.get("upgrade_tier") != null and source_tower.upgrade_tier >= 4:
		var _t2 = _trail_time
		for si in range(3):
			var s_off = -dir * (6.0 + float(si) * 8.0) + perp * sin(_t2 * 5.0 + float(si) * 2.5) * 4.0
			var s_alpha = 0.4 - float(si) * 0.1
			var s_size = 2.0 - float(si) * 0.3
			if is_gold:
				draw_circle(s_off, s_size, Color(1.0, 0.95, 0.5, s_alpha))
				draw_circle(s_off, s_size * 0.5, Color(1.0, 1.0, 0.8, s_alpha * 0.7))
			else:
				draw_circle(s_off, s_size, Color(0.3, 0.8, 0.2, s_alpha))

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
