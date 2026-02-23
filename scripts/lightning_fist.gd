extends Node2D
## Lightning Fist — AoE impact effect for Frankenstein's Monster tower.
## Not a traditional projectile — spawns at tower position, immediately damages
## all enemies in smash radius, then chains lightning to nearby enemies.
## Short lifetime (0.3s) for visual effect only after initial damage.

var damage: float = 80.0
var smash_radius: float = 60.0
var chain_count: int = 6
var gold_bonus: int = 0
var source_tower: Node2D = null
var apply_slow: bool = false

var _lifetime: float = 0.35
var _time: float = 0.0
var _hit_targets: Array = []
var _chain_targets: Array = []  # For visual chain lightning arcs
var _impact_done: bool = false
var _flash: float = 1.0

func _ready() -> void:
	# Immediately apply damage on spawn
	_apply_smash_damage()

func _process(delta: float) -> void:
	_time += delta
	_lifetime -= delta
	_flash = max(_flash - delta * 4.0, 0.0)

	if _lifetime <= 0.0:
		queue_free()
		return

	queue_redraw()

func _apply_smash_damage() -> void:
	_impact_done = true
	var enemies = get_tree().get_nodes_in_group("enemies")

	# Phase 1: Direct AoE smash — damage all enemies in smash radius
	var smash_targets: Array = []
	for enemy in enemies:
		if global_position.distance_to(enemy.global_position) < smash_radius:
			smash_targets.append(enemy)
			_hit_targets.append(enemy)

	for enemy in smash_targets:
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			var will_kill = enemy.health - damage <= 0.0
			enemy.take_damage(damage)
			if is_instance_valid(source_tower) and source_tower.has_method("register_damage"):
				source_tower.register_damage(damage)
			if will_kill:
				if is_instance_valid(source_tower) and source_tower.has_method("register_kill"):
					source_tower.register_kill()
				if gold_bonus > 0:
					var main = get_tree().get_first_node_in_group("main")
					if main:
						main.add_gold(gold_bonus)
			# Apply slow if Arctic Endurance ability active
			if apply_slow and enemy.has_method("apply_slow"):
				enemy.apply_slow(0.7, 2.0)  # 30% slow for 2s

	# Phase 2: Chain lightning — arc to additional enemies beyond smash radius
	var chain_candidates: Array = []
	for enemy in enemies:
		if enemy in _hit_targets:
			continue
		chain_candidates.append(enemy)
	# Sort by distance
	chain_candidates.sort_custom(func(a, b): return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position))

	var chain_dmg = damage * 0.5  # Chain does 50% of main damage
	var chains_done = 0
	var last_pos = global_position
	for enemy in chain_candidates:
		if chains_done >= chain_count:
			break
		if not is_instance_valid(enemy):
			continue
		# Chain range: up to 2x smash radius from last chain point
		if last_pos.distance_to(enemy.global_position) > smash_radius * 2.0:
			continue
		_chain_targets.append({"from": last_pos, "to": enemy.global_position})
		_hit_targets.append(enemy)
		if enemy.has_method("take_damage"):
			var will_kill = enemy.health - chain_dmg <= 0.0
			enemy.take_damage(chain_dmg)
			if is_instance_valid(source_tower) and source_tower.has_method("register_damage"):
				source_tower.register_damage(chain_dmg)
			if will_kill:
				if is_instance_valid(source_tower) and source_tower.has_method("register_kill"):
					source_tower.register_kill()
				if gold_bonus > 0:
					var main = get_tree().get_first_node_in_group("main")
					if main:
						main.add_gold(gold_bonus)
			if apply_slow and enemy.has_method("apply_slow"):
				enemy.apply_slow(0.7, 2.0)
		last_pos = enemy.global_position
		chains_done += 1

func _draw() -> void:
	var alpha = clampf(_lifetime / 0.35, 0.0, 1.0)
	var impact_t = clampf(_time / 0.35, 0.0, 1.0)

	# === 1. CENTRAL FLASH (bright white-blue) ===
	var flash_r = 12.0 + impact_t * 20.0
	draw_circle(Vector2.ZERO, flash_r, Color(0.9, 0.95, 1.0, alpha * 0.25))
	draw_circle(Vector2.ZERO, flash_r * 0.6, Color(0.8, 0.9, 1.0, alpha * 0.35))
	draw_circle(Vector2.ZERO, flash_r * 0.25, Color(1.0, 1.0, 1.0, alpha * 0.5))

	# === 2. FIST IMPACT MARK ===
	# Dark ground crack mark
	var crack_alpha = alpha * 0.6
	var crack_expand = impact_t * smash_radius * 0.4
	# Central crater
	draw_circle(Vector2.ZERO, 6.0 + crack_expand * 0.2, Color(0.15, 0.12, 0.10, crack_alpha * 0.5))
	draw_circle(Vector2.ZERO, 3.0, Color(0.10, 0.08, 0.06, crack_alpha * 0.7))

	# Radiating crack lines (jagged)
	for ci in range(10):
		var ca = TAU * float(ci) / 10.0 + 0.15
		var c_len = 15.0 + crack_expand + fmod(float(ci) * 5.3, 12.0)
		var c_start = Vector2.from_angle(ca) * 4.0
		var c_end = Vector2.from_angle(ca) * c_len
		# Add jaggedness with midpoints
		var c_mid1 = c_start.lerp(c_end, 0.3) + Vector2(sin(float(ci) * 3.7) * 4.0, cos(float(ci) * 2.9) * 3.0)
		var c_mid2 = c_start.lerp(c_end, 0.65) + Vector2(cos(float(ci) * 4.1) * 3.0, sin(float(ci) * 3.3) * 4.0)
		draw_line(c_start, c_mid1, Color(0.12, 0.10, 0.08, crack_alpha), 1.8)
		draw_line(c_mid1, c_mid2, Color(0.12, 0.10, 0.08, crack_alpha * 0.7), 1.3)
		draw_line(c_mid2, c_end, Color(0.12, 0.10, 0.08, crack_alpha * 0.4), 0.8)
		# Sub-cracks branching off
		if ci % 2 == 0:
			var branch_dir = Vector2.from_angle(ca + 0.5 + sin(float(ci)) * 0.3)
			var branch_start = c_mid1
			var branch_end = branch_start + branch_dir * (5.0 + fmod(float(ci) * 2.7, 6.0))
			draw_line(branch_start, branch_end, Color(0.12, 0.10, 0.08, crack_alpha * 0.4), 0.7)

	# === 3. LIGHTNING BOLT LINES radiating out ===
	var bolt_count = 8 + int(impact_t * 4.0)
	for bi in range(bolt_count):
		var ba = TAU * float(bi) / float(bolt_count) + _time * 2.0
		var b_len = smash_radius * 0.3 + smash_radius * 0.5 * impact_t
		var b_start = Vector2.from_angle(ba) * 6.0
		var b_end = Vector2.from_angle(ba) * b_len

		# Build jagged lightning path (3 segments)
		var seg1 = b_start.lerp(b_end, 0.33) + Vector2(sin(_time * 15.0 + float(bi) * 2.3) * 5.0, cos(_time * 12.0 + float(bi) * 1.7) * 4.0)
		var seg2 = b_start.lerp(b_end, 0.66) + Vector2(cos(_time * 13.0 + float(bi) * 3.1) * 4.0, sin(_time * 11.0 + float(bi) * 2.5) * 5.0)

		var bolt_alpha = alpha * (0.5 + sin(_time * 20.0 + float(bi) * 3.0) * 0.2)
		var bolt_col = Color(0.6, 0.8, 1.0, bolt_alpha)
		var bolt_bright = Color(0.9, 0.95, 1.0, bolt_alpha * 0.8)

		# Outer glow
		draw_line(b_start, seg1, bolt_col, 2.5)
		draw_line(seg1, seg2, bolt_col, 2.2)
		draw_line(seg2, b_end, bolt_col, 1.8)
		# Inner bright core
		draw_line(b_start, seg1, bolt_bright, 1.2)
		draw_line(seg1, seg2, bolt_bright, 1.0)
		draw_line(seg2, b_end, bolt_bright, 0.8)

		# Spark at bolt tip
		draw_circle(b_end, 2.0, Color(0.7, 0.85, 1.0, bolt_alpha * 0.6))
		draw_circle(b_end, 1.0, Color(1.0, 1.0, 1.0, bolt_alpha * 0.4))

	# === 4. SMASH RADIUS SHOCKWAVE RING ===
	var ring_r = smash_radius * impact_t
	if ring_r > 5.0:
		var ring_alpha = alpha * 0.4 * (1.0 - impact_t)
		draw_arc(Vector2.ZERO, ring_r, 0, TAU, 48, Color(0.5, 0.7, 1.0, ring_alpha), 3.0)
		draw_arc(Vector2.ZERO, ring_r * 0.95, 0, TAU, 36, Color(0.7, 0.85, 1.0, ring_alpha * 0.5), 1.5)
		# Inner secondary ring
		draw_arc(Vector2.ZERO, ring_r * 0.6, 0, TAU, 32, Color(0.5, 0.7, 1.0, ring_alpha * 0.3), 2.0)

	# === 5. CHAIN LIGHTNING ARCS (to enemies beyond smash radius) ===
	for chain in _chain_targets:
		var from_pos: Vector2 = chain["from"] - global_position
		var to_pos: Vector2 = chain["to"] - global_position
		var chain_alpha = alpha * 0.6

		# Build jagged arc path (4 segments for longer chains)
		var cp1 = from_pos.lerp(to_pos, 0.25) + Vector2(sin(_time * 18.0) * 6.0, cos(_time * 14.0) * 5.0)
		var cp2 = from_pos.lerp(to_pos, 0.5) + Vector2(cos(_time * 16.0) * 7.0, sin(_time * 12.0) * 6.0)
		var cp3 = from_pos.lerp(to_pos, 0.75) + Vector2(sin(_time * 20.0) * 5.0, cos(_time * 15.0) * 4.0)

		# Outer glow
		draw_line(from_pos, cp1, Color(0.5, 0.7, 1.0, chain_alpha), 2.5)
		draw_line(cp1, cp2, Color(0.5, 0.7, 1.0, chain_alpha * 0.9), 2.2)
		draw_line(cp2, cp3, Color(0.5, 0.7, 1.0, chain_alpha * 0.8), 2.0)
		draw_line(cp3, to_pos, Color(0.5, 0.7, 1.0, chain_alpha * 0.7), 1.8)
		# Inner bright core
		draw_line(from_pos, cp1, Color(0.85, 0.92, 1.0, chain_alpha * 0.7), 1.2)
		draw_line(cp1, cp2, Color(0.85, 0.92, 1.0, chain_alpha * 0.6), 1.0)
		draw_line(cp2, cp3, Color(0.85, 0.92, 1.0, chain_alpha * 0.5), 0.8)
		draw_line(cp3, to_pos, Color(0.85, 0.92, 1.0, chain_alpha * 0.4), 0.7)

		# Impact flash at target
		draw_circle(to_pos, 5.0, Color(0.6, 0.8, 1.0, chain_alpha * 0.4))
		draw_circle(to_pos, 2.5, Color(0.9, 0.95, 1.0, chain_alpha * 0.5))

	# === 6. ELECTRIC SPARKS flying outward ===
	for si in range(12):
		var sa = TAU * float(si) / 12.0 + _time * 5.0
		var s_dist = 8.0 + impact_t * smash_radius * 0.8
		var s_pos = Vector2.from_angle(sa) * s_dist
		var spark_size = 1.5 - impact_t * 0.8
		if spark_size > 0.2:
			var spark_alpha = alpha * (0.5 + sin(_time * 25.0 + float(si) * 4.0) * 0.3)
			draw_circle(s_pos, spark_size, Color(0.8, 0.9, 1.0, spark_alpha))
			# Spark trail (short line toward center)
			var trail_end = s_pos * 0.85
			draw_line(trail_end, s_pos, Color(0.6, 0.8, 1.0, spark_alpha * 0.5), 0.8)

	# === 7. DUST/DEBRIS PARTICLES ===
	for di in range(6):
		var da = TAU * float(di) / 6.0 + 0.3
		var d_dist = 5.0 + impact_t * 25.0
		var d_y_off = -impact_t * 8.0 + sin(_time * 6.0 + float(di)) * 3.0
		var d_pos = Vector2(cos(da) * d_dist, sin(da) * d_dist * 0.4 + d_y_off)
		var dust_alpha = alpha * 0.35 * (1.0 - impact_t * 0.5)
		draw_circle(d_pos, 2.0 + sin(_time * 3.0 + float(di)) * 0.5, Color(0.4, 0.38, 0.32, dust_alpha))
		draw_circle(d_pos, 1.0, Color(0.5, 0.48, 0.42, dust_alpha * 0.5))

	# === 8. COSMETIC TRAIL SUPPORT ===
	var main = get_tree().get_first_node_in_group("main")
	if main and main.get("equipped_cosmetics") != null:
		var trail_id = main.equipped_cosmetics.get("trails", "")
		if trail_id != "":
			var trail_items = main.trophy_store_items.get("trails", [])
			for ti in trail_items:
				if ti["id"] == trail_id:
					var tc = ti["color"]
					# Circular trail around impact
					for tj in range(8):
						var t_angle = TAU * float(tj) / 8.0 + _time * 3.0
						var t_r = 10.0 + impact_t * 15.0
						var t_pos = Vector2(cos(t_angle) * t_r, sin(t_angle) * t_r * 0.5)
						draw_circle(t_pos, 2.5 - impact_t * 1.0, Color(tc.r, tc.g, tc.b, alpha * 0.4 - float(tj) * 0.04))
					break
