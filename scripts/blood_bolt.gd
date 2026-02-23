extends Node2D
## Blood Bolt — dark vampiric projectile fired by Dracula tower.
## Drains life on hit and reports heal amount back to source tower.

var speed: float = 450.0
var damage: float = 55.0
var target: Node2D = null
var gold_bonus: int = 0
var source_tower: Node2D = null
var life_drain_percent: float = 0.05
var _lifetime: float = 3.0
var _angle: float = 0.0
var _time: float = 0.0
var _trail_particles: Array = []

func _process(delta: float) -> void:
	_lifetime -= delta
	_time += delta
	if _lifetime <= 0.0:
		queue_free()
		return

	if not is_instance_valid(target):
		queue_free()
		return

	var dir = global_position.direction_to(target.global_position)
	_angle = dir.angle()
	position += dir * speed * delta

	# Spawn trail particles
	if randf() < 0.6:
		_trail_particles.append({
			"pos": Vector2.ZERO,
			"vel": Vector2(randf_range(-15.0, 15.0), randf_range(-15.0, 15.0)),
			"life": randf_range(0.15, 0.35),
			"max_life": 0.3,
			"size": randf_range(1.0, 2.5),
		})

	# Update trail particles
	var i = _trail_particles.size() - 1
	while i >= 0:
		_trail_particles[i]["life"] -= delta
		_trail_particles[i]["pos"] += _trail_particles[i]["vel"] * delta
		_trail_particles[i]["vel"] *= 0.92
		if _trail_particles[i]["life"] <= 0.0:
			_trail_particles.remove_at(i)
		i -= 1

	if global_position.distance_to(target.global_position) < 12.0:
		_hit_target(target)

	queue_redraw()

func _hit_target(t: Node2D) -> void:
	if t.has_method("take_damage"):
		var will_kill = t.health - damage <= 0.0
		t.take_damage(damage)
		if is_instance_valid(source_tower) and source_tower.has_method("register_damage"):
			source_tower.register_damage(damage)
		# Report life drain back to source tower
		var drain_amount = damage * life_drain_percent
		if is_instance_valid(source_tower) and source_tower.has_method("receive_life_drain"):
			source_tower.receive_life_drain(drain_amount)
		if will_kill:
			if is_instance_valid(source_tower) and source_tower.has_method("register_kill"):
				source_tower.register_kill()
			if gold_bonus > 0:
				var main = get_tree().get_first_node_in_group("main")
				if main:
					main.add_gold(gold_bonus)
	queue_free()

func _draw() -> void:
	var dir = Vector2.from_angle(_angle)
	var perp = dir.rotated(PI / 2.0)

	# --- Trail particles (dark red mist behind bolt) ---
	for p in _trail_particles:
		var alpha = clampf(p["life"] / p["max_life"], 0.0, 1.0)
		var ppos: Vector2 = p["pos"] - dir * 12.0
		draw_circle(ppos, p["size"] * alpha, Color(0.5, 0.05, 0.05, alpha * 0.4))
		draw_circle(ppos, p["size"] * alpha * 0.5, Color(0.7, 0.1, 0.1, alpha * 0.25))

	# --- Dripping effect (blood drops falling from bolt) ---
	for di in range(3):
		var dt = fmod(_time * 2.5 + float(di) * 0.35, 1.0)
		var drip_x = float(di - 1) * 3.0
		var drip_y = dt * 8.0
		var drip_alpha = 1.0 - dt
		var drip_pos = -dir * (4.0 + float(di) * 3.0) + perp * (float(di - 1) * 1.5) + Vector2(0, drip_y)
		draw_circle(drip_pos, 1.0 * drip_alpha, Color(0.6, 0.02, 0.02, drip_alpha * 0.5))
		# Elongated drip shape
		draw_line(drip_pos, drip_pos + Vector2(0, 2.0 * drip_alpha), Color(0.5, 0.0, 0.0, drip_alpha * 0.35), 1.2)

	# --- Main bolt body (dark crimson energy core) ---
	# Outer dark aura
	draw_circle(Vector2.ZERO, 6.0, Color(0.2, 0.0, 0.0, 0.15))
	draw_circle(Vector2.ZERO, 4.5, Color(0.35, 0.02, 0.02, 0.25))

	# Bolt shape — elongated along direction
	# Dark crimson body
	var bolt_pts = PackedVector2Array([
		dir * 8.0,
		dir * 3.0 + perp * 3.5,
		-dir * 6.0 + perp * 2.0,
		-dir * 8.0,
		-dir * 6.0 - perp * 2.0,
		dir * 3.0 - perp * 3.5,
	])
	draw_colored_polygon(bolt_pts, Color(0.45, 0.02, 0.02))

	# Inner crimson glow
	var inner_pts = PackedVector2Array([
		dir * 6.0,
		dir * 2.0 + perp * 2.2,
		-dir * 4.0 + perp * 1.2,
		-dir * 5.5,
		-dir * 4.0 - perp * 1.2,
		dir * 2.0 - perp * 2.2,
	])
	draw_colored_polygon(inner_pts, Color(0.6, 0.05, 0.05))

	# Bright glowing core
	draw_circle(dir * 1.0, 2.8, Color(0.8, 0.1, 0.1, 0.7))
	draw_circle(dir * 1.5, 1.8, Color(0.95, 0.2, 0.15, 0.85))
	draw_circle(dir * 2.0, 1.0, Color(1.0, 0.4, 0.3, 0.9))

	# Pulsing energy at tip
	var pulse = sin(_time * 12.0) * 0.3 + 0.7
	draw_circle(dir * 7.0, 2.0 * pulse, Color(0.9, 0.15, 0.1, 0.5 * pulse))
	draw_circle(dir * 7.5, 1.2 * pulse, Color(1.0, 0.3, 0.2, 0.6 * pulse))

	# Dark energy wisps curling around bolt
	for wi in range(3):
		var wa = _time * 6.0 + float(wi) * TAU / 3.0
		var wr = 3.0 + sin(_time * 4.0 + float(wi)) * 1.0
		var wpos = dir * (float(wi) * 2.0 - 2.0) + perp * sin(wa) * wr * 0.5 + Vector2(0, cos(wa) * wr * 0.3)
		draw_circle(wpos, 0.8, Color(0.3, 0.0, 0.0, 0.35))

	# Red mist trailing behind
	for mi in range(4):
		var moff = -dir * (10.0 + float(mi) * 5.0)
		var msize = 2.5 - float(mi) * 0.4
		var malpha = 0.25 - float(mi) * 0.05
		var mwobble = sin(_time * 5.0 + float(mi) * 1.5) * 1.5
		draw_circle(moff + perp * mwobble, msize, Color(0.4, 0.02, 0.02, malpha))

	# --- Cosmetic trail support ---
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
