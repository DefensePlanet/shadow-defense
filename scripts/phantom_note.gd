extends Node2D
## Phantom's Music Note — heavy single-target projectile. Can apply DoT at tier 4.

var speed: float = 320.0
var damage: float = 35.0
var target: Node2D = null
var gold_bonus: int = 0
var source_tower: Node2D = null
var dot_dps: float = 0.0
var dot_duration: float = 0.0
var _lifetime: float = 3.0
var _angle: float = 0.0
var _float_offset: float = 0.0

func _process(delta: float) -> void:
	_lifetime -= delta
	_float_offset += delta * 6.0
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
		t.take_damage(damage, true)
		if is_instance_valid(source_tower) and source_tower.has_method("register_damage"):
			source_tower.register_damage(damage)

		# Apply DoT (Phantom's Wrath)
		if dot_dps > 0.0 and is_instance_valid(t) and t.has_method("apply_dot"):
			t.apply_dot(dot_dps, dot_duration)

		if will_kill:
			if gold_bonus > 0:
				var main = get_tree().get_first_node_in_group("main")
				if main:
					main.add_gold(gold_bonus)

	queue_free()

func _draw() -> void:
	var dir = Vector2.from_angle(_angle)
	var perp = dir.rotated(PI / 2.0)
	var bob = sin(_float_offset) * 2.0

	# Music note shape
	# Note head (filled oval)
	draw_circle(Vector2(0, bob), 3.5, Color(0.5, 0.25, 0.65))
	# Stem
	draw_line(Vector2(0, bob) + perp * 3.0, Vector2(0, bob) + perp * 3.0 + Vector2(0, -10), Color(0.5, 0.25, 0.65), 1.5)
	# Flag
	draw_line(Vector2(0, bob) + perp * 3.0 + Vector2(0, -10), Vector2(0, bob) + perp * 3.0 + Vector2(4, -7), Color(0.5, 0.25, 0.65), 1.5)

	# Glow
	draw_circle(Vector2(0, bob), 5.5, Color(0.5, 0.3, 0.7, 0.2))

	# Trail
	draw_line(-dir * 8.0 + Vector2(0, bob), Vector2(0, bob), Color(0.4, 0.2, 0.6, 0.3), 2.0)

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
						var off = -dir * (10.0 + tj * 7.0) + Vector2(0, bob)
						draw_circle(off, 3.0 - tj * 0.5, Color(tc.r, tc.g, tc.b, 0.5 - tj * 0.12))
					break
