extends Node2D
## Spell Bolt — arcane magic projectile from Merlin. Blue-purple energy bolt with rune trail.
## Supports chaining (bounce) to additional enemies and curse debuff application.

var speed: float = 400.0
var damage: float = 40.0
var target: Node2D = null
var gold_bonus: int = 0
var source_tower: Node2D = null
var bounce_count: int = 0
var curse_on_hit: bool = false
var curse_mult: float = 1.2
var curse_duration: float = 5.0
var _lifetime: float = 3.0
var _angle: float = 0.0
var _hit_targets: Array = []
var _time: float = 0.0

func _process(delta: float) -> void:
	_time += delta
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()
		return

	if not is_instance_valid(target):
		if bounce_count > 0:
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
		t.take_damage(damage, true)
		if is_instance_valid(source_tower) and source_tower.has_method("register_damage"):
			source_tower.register_damage(damage)

		# Apply curse debuff — enemy takes more damage from all sources
		if curse_on_hit and is_instance_valid(t) and t.has_method("apply_mark"):
			t.apply_mark(curse_mult, curse_duration, false)

		if will_kill:
			if is_instance_valid(source_tower) and source_tower.has_method("register_kill"):
				source_tower.register_kill()
			if gold_bonus > 0:
				var main = get_tree().get_first_node_in_group("main")
				if main:
					main.add_gold(gold_bonus)

	# Chain bounce to next enemy
	if bounce_count > 0:
		bounce_count -= 1
		target = _find_next_target()
		if not is_instance_valid(target):
			queue_free()
	else:
		queue_free()

func _find_next_target() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist: float = 180.0
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

	# === Outer arcane glow (blue-purple) ===
	var pulse = sin(_time * 10.0) * 0.1 + 0.9
	draw_circle(Vector2.ZERO, 8.0 * pulse, Color(0.3, 0.2, 0.7, 0.15))
	draw_circle(Vector2.ZERO, 6.0 * pulse, Color(0.4, 0.25, 0.8, 0.25))

	# === Core energy orb ===
	draw_circle(Vector2.ZERO, 4.0, Color(0.45, 0.3, 0.85, 0.85))
	draw_circle(dir * 0.5, 2.8, Color(0.55, 0.4, 0.95, 0.9))
	# Bright white-blue center
	draw_circle(dir * 0.8, 1.6, Color(0.75, 0.7, 1.0))

	# === Swirling energy ring around core ===
	for si in range(4):
		var sa = _time * 6.0 + float(si) * TAU / 4.0
		var sr = 3.5 + sin(_time * 8.0 + float(si)) * 0.8
		var spark_pos = Vector2(cos(sa) * sr, sin(sa) * sr * 0.6)
		draw_circle(spark_pos, 0.9, Color(0.5, 0.35, 0.95, 0.6))
		draw_circle(spark_pos, 0.5, Color(0.7, 0.6, 1.0, 0.8))

	# === Arcane rune trail (3 fading rune symbols behind) ===
	for ri in range(3):
		var trail_dist = 8.0 + float(ri) * 7.0
		var trail_pos = -dir * trail_dist
		var trail_alpha = 0.4 - float(ri) * 0.12
		var rune_rot = _time * 3.0 + float(ri) * 1.5
		var rune_size = 2.2 - float(ri) * 0.3
		# Rune circle
		draw_arc(trail_pos, rune_size, rune_rot, rune_rot + TAU, 6, Color(0.4, 0.25, 0.8, trail_alpha), 0.7)
		# Rune cross inside circle
		var rd = Vector2.from_angle(rune_rot)
		var rp = rd.rotated(PI / 2.0)
		draw_line(trail_pos - rd * rune_size * 0.7, trail_pos + rd * rune_size * 0.7, Color(0.5, 0.35, 0.9, trail_alpha * 0.7), 0.5)
		draw_line(trail_pos - rp * rune_size * 0.7, trail_pos + rp * rune_size * 0.7, Color(0.5, 0.35, 0.9, trail_alpha * 0.7), 0.5)

	# === Energy trail wisps ===
	for wi in range(5):
		var wt = float(wi) * 0.18
		var w_pos = -dir * (5.0 + float(wi) * 5.0) + perp * sin(_time * 7.0 + float(wi) * 2.0) * (1.5 + float(wi) * 0.3)
		var w_alpha = 0.35 - float(wi) * 0.06
		var w_size = 1.8 - float(wi) * 0.25
		draw_circle(w_pos, w_size, Color(0.35, 0.2, 0.75, w_alpha))

	# === Star sparkle particles ===
	for spi in range(3):
		var sp_a = _time * 5.0 + float(spi) * TAU / 3.0
		var sp_r = 5.0 + sin(_time * 4.0 + float(spi) * 2.5) * 2.0
		var sp_pos = Vector2(cos(sp_a) * sp_r, sin(sp_a) * sp_r * 0.5)
		var sp_size = 0.8 + sin(_time * 6.0 + float(spi)) * 0.3
		# 4-point star sparkle
		draw_line(sp_pos + Vector2(-sp_size, 0), sp_pos + Vector2(sp_size, 0), Color(0.7, 0.6, 1.0, 0.5), 0.5)
		draw_line(sp_pos + Vector2(0, -sp_size), sp_pos + Vector2(0, sp_size), Color(0.7, 0.6, 1.0, 0.5), 0.5)
		# Diagonal arms (smaller)
		var ds = sp_size * 0.6
		draw_line(sp_pos + Vector2(-ds, -ds), sp_pos + Vector2(ds, ds), Color(0.8, 0.75, 1.0, 0.3), 0.4)
		draw_line(sp_pos + Vector2(ds, -ds), sp_pos + Vector2(-ds, ds), Color(0.8, 0.75, 1.0, 0.3), 0.4)

	# === Leading edge sparkle ===
	var lead_pulse = sin(_time * 12.0) * 0.5 + 0.5
	draw_circle(dir * 5.0, 1.5 + lead_pulse * 0.5, Color(0.6, 0.5, 1.0, 0.5 + lead_pulse * 0.2))
	draw_circle(dir * 5.0, 0.8, Color(0.85, 0.8, 1.0, 0.7))

	# === Curse indicator (dark purple wisps if curse active) ===
	if curse_on_hit:
		for ci in range(3):
			var ca = _time * 4.0 + float(ci) * TAU / 3.0
			var cr = 6.0 + sin(_time * 3.0 + float(ci)) * 1.5
			var c_pos = Vector2(cos(ca) * cr, sin(ca) * cr * 0.5)
			draw_circle(c_pos, 1.0, Color(0.2, 0.05, 0.3, 0.35))
			draw_circle(c_pos, 0.5, Color(0.4, 0.1, 0.5, 0.25))

	# === Cosmetic trail support ===
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
						draw_circle(off, 3.0 - tj * 0.5, Color(tc.r, tc.g, tc.b, 0.5 - tj * 0.12))
					break
