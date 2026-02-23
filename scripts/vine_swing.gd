extends Node2D
## Vine Swing — Tarzan's extended melee projectile. A vine lash that whips toward enemies.

var speed: float = 800.0
var damage: float = 70.0
var target: Node2D = null
var gold_bonus: int = 0
var source_tower: Node2D = null
var knockback: bool = false
var pull_closer: bool = false
var _lifetime: float = 0.5
var _angle: float = 0.0
var _hit_targets: Array = []
var _trail: Array = []  # Trail positions for vine rendering
var _age: float = 0.0

func _process(delta: float) -> void:
	_lifetime -= delta
	_age += delta
	if _lifetime <= 0.0:
		queue_free()
		return

	if not is_instance_valid(target):
		queue_free()
		return

	var dir = global_position.direction_to(target.global_position)
	_angle = dir.angle()
	position += dir * speed * delta

	# Store trail positions for vine rendering
	_trail.append(global_position)
	if _trail.size() > 8:
		_trail.remove_at(0)

	if global_position.distance_to(target.global_position) < 20.0:
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

	# Knockback — push enemy away
	if knockback and is_instance_valid(t):
		if t.has_method("apply_knockback"):
			var kb_dir = global_position.direction_to(t.global_position)
			t.apply_knockback(kb_dir * 40.0)
		else:
			t.global_position += global_position.direction_to(t.global_position) * 30.0

	# Pull closer — drag enemy toward tower
	if pull_closer and is_instance_valid(t) and is_instance_valid(source_tower):
		var pull_dir = t.global_position.direction_to(source_tower.global_position)
		t.global_position += pull_dir * 30.0

	queue_free()

func _draw() -> void:
	var dir = Vector2.from_angle(_angle)
	var perp = dir.rotated(PI / 2.0)
	var life_t = clampf(_age / 0.5, 0.0, 1.0)  # 0 at birth, 1 at max age

	# === VINE BODY ===
	# Base (thick, brown near origin)
	var vine_base = -dir * 12.0
	var vine_tip = dir * 10.0

	# Main vine stem — wavy organic line
	var vine_pts: Array = []
	var vine_count = 8
	for i in range(vine_count + 1):
		var t = float(i) / float(vine_count)
		var pos = vine_base.lerp(vine_tip, t)
		# Organic wave
		var wave = sin(t * PI * 3.0 + _age * 12.0) * (2.0 - t * 1.5)
		pos += perp * wave
		vine_pts.append(pos)

	# Draw vine segments (thick to thin)
	for i in range(vine_pts.size() - 1):
		var t = float(i) / float(vine_pts.size() - 1)
		var width = lerp(3.5, 1.5, t)
		# Base is brown, transitions to green
		var col_r = lerp(0.40, 0.15, t)
		var col_g = lerp(0.28, 0.50, t)
		var col_b = lerp(0.12, 0.08, t)
		draw_line(vine_pts[i], vine_pts[i + 1], Color(col_r, col_g, col_b), width)
		# Inner highlight
		draw_line(vine_pts[i], vine_pts[i + 1], Color(col_r + 0.1, col_g + 0.1, col_b + 0.04, 0.3), width * 0.4)

	# Bark texture along vine
	for bi in range(4):
		var bt = 0.15 + float(bi) * 0.2
		var bpos = vine_base.lerp(vine_tip, bt)
		var bwave = sin(bt * PI * 3.0 + _age * 12.0) * (2.0 - bt * 1.5)
		bpos += perp * bwave
		draw_line(bpos - perp * 1.5, bpos + perp * 1.5, Color(0.30, 0.20, 0.08, 0.3), 0.6)

	# Tendrils — small curly offshoots
	for ti in range(3):
		var tt = 0.2 + float(ti) * 0.3
		var tpos = vine_base.lerp(vine_tip, tt)
		var twave = sin(tt * PI * 3.0 + _age * 12.0) * (2.0 - tt * 1.5)
		tpos += perp * twave
		var tendril_dir = perp * (1.0 if ti % 2 == 0 else -1.0)
		var curl = sin(_age * 8.0 + float(ti) * 2.0) * 1.5
		var t_end = tpos + tendril_dir * (4.0 + curl) + dir * 1.5
		draw_line(tpos, t_end, Color(0.18, 0.45, 0.10, 0.6), 1.2)
		# Tiny curl at end
		var curl_end = t_end + tendril_dir * 1.5 + dir.rotated(0.5 * (1.0 if ti % 2 == 0 else -1.0)) * 1.5
		draw_line(t_end, curl_end, Color(0.20, 0.48, 0.12, 0.4), 0.8)

	# === LEAVES AT TIP ===
	var tip = vine_tip + dir * 2.0
	# Main leaf cluster (3 leaves)
	for li in range(3):
		var la = float(li - 1) * 0.8 + sin(_age * 6.0) * 0.3
		var leaf_dir = dir.rotated(la)
		var leaf_perp = leaf_dir.rotated(PI / 2.0)
		var leaf_len = 5.0 + sin(_age * 4.0 + float(li)) * 1.0
		var leaf_tip_pt = tip + leaf_dir * leaf_len
		var leaf_mid = tip + leaf_dir * (leaf_len * 0.5)
		# Leaf shape (pointed oval via lines)
		var leaf_col = Color(0.18, 0.52, 0.12, 0.8 - float(li) * 0.1)
		draw_line(tip, leaf_tip_pt, leaf_col, 2.5 - float(li) * 0.3)
		# Leaf width via perpendicular lines at midpoint
		draw_line(leaf_mid - leaf_perp * 2.0, leaf_mid + leaf_perp * 2.0, leaf_col, 1.5)
		# Leaf vein
		draw_line(tip, leaf_tip_pt, Color(0.14, 0.40, 0.08, 0.4), 0.6)
		# Leaf highlight
		draw_line(tip.lerp(leaf_tip_pt, 0.2), tip.lerp(leaf_tip_pt, 0.6), Color(0.3, 0.65, 0.2, 0.3), 0.8)

	# Small buds near leaves
	draw_circle(tip + perp * 2.5, 1.2, Color(0.22, 0.50, 0.15, 0.5))
	draw_circle(tip - perp * 2.0, 1.0, Color(0.20, 0.48, 0.12, 0.4))

	# === IMPACT FLASH (at tip when close to hitting) ===
	if is_instance_valid(target):
		var dist = global_position.distance_to(target.global_position)
		if dist < 40.0:
			var flash_alpha = (1.0 - dist / 40.0) * 0.3
			draw_circle(vine_tip, 6.0, Color(0.3, 0.7, 0.15, flash_alpha))
			draw_circle(vine_tip, 3.0, Color(0.5, 0.9, 0.25, flash_alpha * 0.5))

	# === MOTION TRAIL ===
	# Fading green trail behind the vine
	for tri in range(5):
		var trail_t = float(tri) / 4.0
		var trail_off = -dir * (8.0 + float(tri) * 6.0)
		var trail_alpha = 0.25 - trail_t * 0.2
		var trail_size = 2.5 - trail_t * 0.4
		draw_circle(trail_off, trail_size, Color(0.2, 0.55, 0.12, trail_alpha))

	# === KNOCKBACK INDICATOR ===
	if knockback:
		# Red-orange impact lines at tip
		for ki in range(3):
			var ka = float(ki - 1) * 0.4 + _angle
			var k_start = vine_tip + Vector2.from_angle(ka) * 3.0
			var k_end = vine_tip + Vector2.from_angle(ka) * 7.0
			draw_line(k_start, k_end, Color(0.9, 0.5, 0.15, 0.4), 1.5)

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
