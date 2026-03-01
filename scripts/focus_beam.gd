extends Node2D
## Focus Beam — concentrated light projectile from Sherlock's magnifying glass.
## Supports piercing, splash, and deduction marking.

var speed: float = 600.0
var damage: float = 45.0
var target: Node2D = null
var gold_bonus: int = 0
var source_tower: Node2D = null
var pierce_count: int = 0
var splash_radius: float = 0.0
var mark_on_hit: bool = false
var _lifetime: float = 3.0
var _angle: float = 0.0
var _hit_targets: Array = []
var _trail_points: Array = []
var _time: float = 0.0

func _process(delta: float) -> void:
	_lifetime -= delta
	_time += delta
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

	# Store trail points
	_trail_points.append(global_position)
	if _trail_points.size() > 8:
		_trail_points.pop_front()

	if global_position.distance_to(target.global_position) < 12.0:
		_hit_target(target)

	queue_redraw()

func _hit_target(t: Node2D) -> void:
	_hit_targets.append(t)

	# Apply deduction mark before damage
	if mark_on_hit and is_instance_valid(source_tower) and source_tower.has_method("_mark_enemy"):
		source_tower._mark_enemy(t)

	if t.has_method("take_damage"):
		# Check if target has deduction mark for bonus damage
		var effective_damage = damage
		if t.get("deduction_marked") == true:
			effective_damage *= 1.3
		var will_kill = t.health - effective_damage <= 0.0
		t.take_damage(effective_damage, "physical")
		if is_instance_valid(source_tower) and source_tower.has_method("register_damage"):
			source_tower.register_damage(effective_damage)
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

	# === FOCUSED LIGHT BEAM ===
	# Outer warm glow (wide, soft)
	draw_line(-dir * 6.0, dir * 10.0, Color(1.0, 0.85, 0.4, 0.12), 8.0)
	# Mid beam (golden-white core)
	draw_line(-dir * 8.0, dir * 8.0, Color(1.0, 0.92, 0.55, 0.3), 4.5)
	# Bright core beam (intense white-gold center)
	draw_line(-dir * 7.0, dir * 9.0, Color(1.0, 0.97, 0.8, 0.6), 2.5)
	# Hottest center line (near-white)
	draw_line(-dir * 5.0, dir * 7.0, Color(1.0, 1.0, 0.95, 0.8), 1.2)

	# === LENS FLARE AT TIP ===
	var tip = dir * 9.0
	# Outer flare halo
	draw_circle(tip, 6.0, Color(1.0, 0.9, 0.5, 0.15))
	# Mid flare
	draw_circle(tip, 4.0, Color(1.0, 0.95, 0.65, 0.25))
	# Bright flare core
	draw_circle(tip, 2.5, Color(1.0, 0.98, 0.85, 0.5))
	# White hot center
	draw_circle(tip, 1.2, Color(1.0, 1.0, 1.0, 0.75))

	# Cross flare (lens artifact — horizontal and vertical light lines)
	var flare_pulse = 0.7 + sin(_time * 8.0) * 0.3
	draw_line(tip - perp * 8.0 * flare_pulse, tip + perp * 8.0 * flare_pulse, Color(1.0, 0.95, 0.7, 0.2), 1.0)
	draw_line(tip - dir * 3.0, tip + dir * 5.0 * flare_pulse, Color(1.0, 0.97, 0.8, 0.15), 0.8)

	# Diagonal cross flare
	var diag1 = dir.rotated(PI / 4.0)
	var diag2 = dir.rotated(-PI / 4.0)
	draw_line(tip - diag1 * 5.0 * flare_pulse, tip + diag1 * 5.0 * flare_pulse, Color(1.0, 0.92, 0.6, 0.12), 0.6)
	draw_line(tip - diag2 * 5.0 * flare_pulse, tip + diag2 * 5.0 * flare_pulse, Color(1.0, 0.92, 0.6, 0.12), 0.6)

	# === WARM GLOW TRAIL (fading behind beam) ===
	# Trailing light particles
	for ti in range(5):
		var trail_off = -dir * (8.0 + float(ti) * 6.0)
		var trail_alpha = 0.25 - float(ti) * 0.045
		var trail_size = 3.0 - float(ti) * 0.4
		# Warm golden trail circle
		draw_circle(trail_off, trail_size, Color(1.0, 0.88, 0.45, trail_alpha))
		# Inner brighter trail
		draw_circle(trail_off, trail_size * 0.5, Color(1.0, 0.95, 0.7, trail_alpha * 1.3))

	# Shimmer particles along beam body
	for si in range(3):
		var sp = float(si) / 2.0
		var shimmer_pos = dir * (-4.0 + sp * 10.0) + perp * sin(_time * 12.0 + float(si) * 2.5) * 2.0
		draw_circle(shimmer_pos, 0.8, Color(1.0, 1.0, 0.9, 0.3 + sin(_time * 10.0 + float(si)) * 0.15))

	# === MARK INDICATOR (small deduction symbol if marking) ===
	if mark_on_hit:
		# Tiny magnifying glass icon at tip
		var icon_pos = tip + perp * 4.0
		draw_circle(icon_pos, 2.0, Color(0.85, 0.72, 0.25, 0.4))
		draw_arc(icon_pos, 2.0, 0, TAU, 8, Color(1.0, 0.85, 0.3, 0.5), 0.6)
		draw_line(icon_pos + Vector2(1.2, 1.2), icon_pos + Vector2(3.0, 3.0), Color(0.85, 0.72, 0.25, 0.4), 0.8)

	# === COSMETIC TRAIL ===
	var main = get_tree().get_first_node_in_group("main")
	if main and main.get("equipped_cosmetics") != null:
		var trail_id = main.equipped_cosmetics.get("trails", "")
		if trail_id != "":
			var trail_items = main.trophy_store_items.get("trails", [])
			for ti_item in trail_items:
				if ti_item["id"] == trail_id:
					var tc = ti_item["color"]
					for tj in range(4):
						var off = -dir * (12.0 + tj * 8.0)
						draw_circle(off, 3.0 - tj * 0.5, Color(tc.r, tc.g, tc.b, 0.5 - tj * 0.12))
					break
