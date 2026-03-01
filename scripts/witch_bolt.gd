extends Node2D
## Witch Bolt — green energy projectile. Can apply DoT and appear as wolf.

var speed: float = 350.0
var damage: float = 20.0
var target: Node2D = null
var gold_bonus: int = 0
var source_tower: Node2D = null
var dot_dps: float = 0.0
var dot_duration: float = 0.0
var is_wolf: bool = false
var _lifetime: float = 3.0
var _angle: float = 0.0

func _ready() -> void:
	if is_wolf:
		speed = 300.0

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

	if global_position.distance_to(target.global_position) < 12.0:
		_hit_target(target)

	queue_redraw()

func _hit_target(t: Node2D) -> void:
	if t.has_method("take_damage"):
		var will_kill = t.health - damage <= 0.0
		t.take_damage(damage, "magic")
		if is_instance_valid(source_tower) and source_tower.has_method("register_damage"):
			source_tower.register_damage(damage)

		# Apply DoT
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

	if is_wolf:
		# Dust puffs behind wolf
		for ti in range(2):
			var poff = -dir * (10.0 + float(ti) * 8.0) + Vector2(0, 3.0)
			var p_alpha = 0.25 - float(ti) * 0.1
			draw_circle(poff, 3.0 - float(ti) * 0.5, Color(0.6, 0.55, 0.45, p_alpha))
		# Wolf shape — grey, fast, feral
		# Body
		draw_circle(Vector2.ZERO, 5.0, Color(0.45, 0.42, 0.38))
		# Head
		draw_circle(dir * 5.0, 3.5, Color(0.5, 0.47, 0.42))
		# Ears
		draw_line(dir * 6.0 + perp * 2.0, dir * 8.0 + perp * 3.5, Color(0.4, 0.37, 0.33), 1.5)
		draw_line(dir * 6.0 - perp * 2.0, dir * 8.0 - perp * 3.5, Color(0.4, 0.37, 0.33), 1.5)
		# Eyes (fierce red)
		draw_circle(dir * 6.5 + perp * 1.5, 0.8, Color(0.9, 0.2, 0.1))
		draw_circle(dir * 6.5 - perp * 1.5, 0.8, Color(0.9, 0.2, 0.1))
		# Tail
		draw_line(-dir * 5.0, -dir * 8.0 + perp * 2.0, Color(0.45, 0.42, 0.38), 1.5)
		# Legs (running)
		draw_line(perp * 3.0, perp * 3.0 - dir * 4.0, Color(0.4, 0.37, 0.33), 1.2)
		draw_line(-perp * 3.0, -perp * 3.0 - dir * 4.0, Color(0.4, 0.37, 0.33), 1.2)
	else:
		# Green wisp trail — 3 fading green circles
		for ti in range(3):
			var woff = -dir * (8.0 + float(ti) * 6.0)
			var w_alpha = 0.3 - float(ti) * 0.08
			draw_circle(woff, 3.0 - float(ti) * 0.5, Color(0.3, 0.8, 0.15, w_alpha))
		# Green eye blast
		# Outer glow
		draw_circle(Vector2.ZERO, 6.0, Color(0.3, 0.8, 0.15, 0.3))
		# Core
		draw_circle(Vector2.ZERO, 3.5, Color(0.4, 0.9, 0.2, 0.8))
		# Bright center
		draw_circle(dir * 1.0, 2.0, Color(0.6, 1.0, 0.4))
		# Trail
		draw_line(-dir * 6.0, Vector2.ZERO, Color(0.3, 0.7, 0.1, 0.4), 2.5)

	# Tier 3+ enhanced trail: green fire wisps
	if is_instance_valid(source_tower) and source_tower.get("upgrade_tier") != null and source_tower.upgrade_tier >= 3:
		var _t2 = fmod(global_position.x + global_position.y, 20.0)
		for fi in range(4):
			var f_off = -dir * (8.0 + float(fi) * 6.0) + perp * sin(_t2 * 4.0 + float(fi) * 2.0) * 3.0
			f_off += Vector2(0, -float(fi) * 1.5)
			var f_alpha = 0.35 - float(fi) * 0.07
			draw_circle(f_off, 2.5 - float(fi) * 0.4, Color(0.3, 0.9, 0.1, f_alpha))
			draw_circle(f_off, 1.5 - float(fi) * 0.2, Color(0.5, 1.0, 0.3, f_alpha * 0.7))

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
						draw_circle(off, 3.0 - tj * 0.5, Color(tc.r, tc.g, tc.b, 0.5 - tj * 0.12))
					break
