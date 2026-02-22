extends Node2D
## Robin Hood — long-range archer tower. Upgrades by dealing damage ("Rob the Rich").
## Tier 1 (5000 DMG): Splitting the Wand — arrows pierce to a 2nd enemy
## Tier 2 (10000 DMG): The Silver Arrow — every 5th shot deals 3x damage
## Tier 3 (15000 DMG): Three Blasts of the Horn — volley of 5 arrows every 18s
## Tier 4 (20000 DMG): The Final Arrow — splash damage, doubled gold, double pierce

# Base stats
var damage: float = 50.0
var fire_rate: float = 2.0
var attack_range: float = 200.0
var fire_cooldown: float = 0.0
var bow_angle: float = 0.0
var target: Node2D = null
var _draw_progress: float = 0.0
var gold_bonus: int = 5

# Animation timers
var _time: float = 0.0
var _attack_anim: float = 0.0

# Damage tracking and upgrades
var damage_dealt: float = 0.0
var upgrade_tier: int = 0
var _upgrade_flash: float = 0.0
var _upgrade_name: String = ""

# Tier 1: Splitting the Wand — pierce
var pierce_count: int = 0

# Tier 2: The Silver Arrow — every Nth shot is silver (3x damage)
var shot_count: int = 0
var silver_interval: int = 5

# Tier 3: Three Blasts of the Horn — periodic volley
var horn_timer: float = 0.0
var horn_cooldown: float = 18.0
var _horn_flash: float = 0.0

# Tier 4: The Final Arrow — splash
var splash_radius: float = 0.0

# Kill tracking — steal coins every 10th kill
var kill_count: int = 0

const STAT_UPGRADE_INTERVAL: float = 500.0
const ABILITY_THRESHOLD: float = 1500.0
var stat_upgrade_level: int = 0
var ability_chosen: bool = false
var awaiting_ability_choice: bool = false
const TIER_NAMES = [
	"Splitting the Wand",
	"The Silver Arrow",
	"Three Blasts of the Horn",
	"The Final Arrow"
]
const ABILITY_DESCRIPTIONS = [
	"Arrows pierce to a 2nd enemy",
	"Every 5th shot deals 3x damage",
	"Volley of 5 arrows every 18s",
	"Splash damage, double gold, double pierce"
]
const TIER_COSTS = [60, 120, 200, 350]
var is_selected: bool = false
var base_cost: int = 0

var arrow_scene = preload("res://scenes/arrow.tscn")

func _ready() -> void:
	add_to_group("towers")

func _process(delta: float) -> void:
	_time += delta
	fire_cooldown -= delta
	_upgrade_flash = max(_upgrade_flash - delta * 0.5, 0.0)
	_horn_flash = max(_horn_flash - delta * 2.0, 0.0)
	_attack_anim = max(_attack_anim - delta * 3.0, 0.0)
	target = _find_nearest_enemy()

	if target:
		var desired = global_position.angle_to_point(target.global_position) + PI
		bow_angle = lerp_angle(bow_angle, desired, 10.0 * delta)
		_draw_progress = min(_draw_progress + delta * 3.0, 1.0)
		if fire_cooldown <= 0.0:
			_shoot()
			fire_cooldown = 1.0 / fire_rate
			_draw_progress = 0.0
			_attack_anim = 1.0
	else:
		_draw_progress = max(_draw_progress - delta * 2.0, 0.0)

	# Tier 3+: Horn volley
	if upgrade_tier >= 3:
		horn_timer -= delta
		if horn_timer <= 0.0 and _has_enemies_in_range():
			_horn_volley()
			horn_timer = horn_cooldown

	queue_redraw()

func _has_enemies_in_range() -> bool:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(enemy.global_position) < attack_range:
			return true
	return false

func _find_nearest_enemy() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist: float = attack_range
	for enemy in enemies:
		var dist = global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest = enemy
			nearest_dist = dist
	return nearest

func _shoot() -> void:
	if not target:
		return
	shot_count += 1
	var silver = upgrade_tier >= 2 and shot_count % silver_interval == 0
	_fire_arrow(target, silver)

func _fire_arrow(t: Node2D, silver: bool = false) -> void:
	var arrow = arrow_scene.instantiate()
	arrow.global_position = global_position + Vector2.from_angle(bow_angle) * 18.0
	arrow.damage = damage * (3.0 if silver else 1.0)
	arrow.target = t
	arrow.gold_bonus = gold_bonus
	arrow.source_tower = self
	arrow.pierce_count = pierce_count
	arrow.is_silver = silver
	arrow.splash_radius = splash_radius
	get_tree().get_first_node_in_group("main").add_child(arrow)

func _horn_volley() -> void:
	_horn_flash = 1.0
	var enemies = get_tree().get_nodes_in_group("enemies")
	var in_range: Array = []
	for enemy in enemies:
		if global_position.distance_to(enemy.global_position) < attack_range:
			in_range.append(enemy)
	in_range.shuffle()
	var count = mini(5, in_range.size())
	for i in range(count):
		_fire_arrow(in_range[i], false)

func register_kill() -> void:
	kill_count += 1
	if kill_count % 10 == 0:
		var stolen = 5 + kill_count / 10
		var main = get_tree().get_first_node_in_group("main")
		if main:
			main.add_gold(stolen)
		_upgrade_flash = 1.0
		_upgrade_name = "Robbed %d gold!" % stolen

func register_damage(amount: float) -> void:
	damage_dealt += amount

func _check_upgrades() -> void:
	var new_level = int(damage_dealt / STAT_UPGRADE_INTERVAL)
	while stat_upgrade_level < new_level:
		stat_upgrade_level += 1
		_apply_stat_boost()
		_upgrade_flash = 2.0
		_upgrade_name = "Level %d" % stat_upgrade_level
	if damage_dealt >= ABILITY_THRESHOLD and not ability_chosen and not awaiting_ability_choice:
		awaiting_ability_choice = true
		var main = get_tree().get_first_node_in_group("main")
		if main and main.has_method("show_ability_choice"):
			main.show_ability_choice(self)

func _apply_stat_boost() -> void:
	damage *= 1.12
	fire_rate *= 1.08
	attack_range += 8.0
	gold_bonus += 1

func choose_ability(index: int) -> void:
	ability_chosen = true
	awaiting_ability_choice = false
	upgrade_tier = index + 1
	_apply_upgrade(upgrade_tier)
	_upgrade_flash = 3.0
	_upgrade_name = TIER_NAMES[index]

func _apply_upgrade(tier: int) -> void:
	match tier:
		1: # Splitting the Wand — arrows pierce one extra enemy
			pierce_count = 1
			damage = 65.0
			fire_rate = 2.5
			attack_range = 220.0
		2: # The Silver Arrow — every 5th shot triple damage
			damage = 85.0
			fire_rate = 3.0
			attack_range = 240.0
			gold_bonus = 8
		3: # Three Blasts of the Horn — volley + range boost
			damage = 100.0
			fire_rate = 3.5
			attack_range = 270.0
			horn_cooldown = 14.0
			gold_bonus = 10
		4: # The Final Arrow — splash, double pierce, double gold
			damage = 130.0
			fire_rate = 4.0
			attack_range = 300.0
			gold_bonus = 15
			splash_radius = 80.0
			pierce_count = 3
			horn_cooldown = 10.0

func purchase_upgrade() -> bool:
	if upgrade_tier >= 4:
		return false
	var cost = TIER_COSTS[upgrade_tier]
	var main_node = get_tree().get_first_node_in_group("main")
	if not main_node or not main_node.spend_gold(cost):
		return false
	upgrade_tier += 1
	_apply_upgrade(upgrade_tier)
	_upgrade_flash = 3.0
	_upgrade_name = TIER_NAMES[upgrade_tier - 1]
	return true

func get_tower_display_name() -> String:
	return "Robin Hood"

func get_next_upgrade_info() -> Dictionary:
	if upgrade_tier >= 4:
		return {}
	return {
		"name": TIER_NAMES[upgrade_tier],
		"description": ABILITY_DESCRIPTIONS[upgrade_tier],
		"cost": TIER_COSTS[upgrade_tier]
	}

func get_sell_value() -> int:
	var total = base_cost
	for i in range(upgrade_tier):
		total += TIER_COSTS[i]
	return int(total * 0.6)

func _draw() -> void:
	# === 1. SELECTION RING ===
	if is_selected:
		var pulse = (sin(_time * 3.0) + 1.0) * 0.5
		var ring_alpha = 0.5 + pulse * 0.3
		draw_arc(Vector2.ZERO, 40.0, 0, TAU, 48, Color(1.0, 0.84, 0.0, ring_alpha), 2.5)
		draw_arc(Vector2.ZERO, 43.0, 0, TAU, 48, Color(1.0, 0.84, 0.0, ring_alpha * 0.4), 1.5)

	# === 2. RANGE ARC ===
	draw_arc(Vector2.ZERO, attack_range, 0, TAU, 64, Color(1, 1, 1, 0.06), 1.0)

	# === 3. AIM DIRECTION ===
	var dir = Vector2.from_angle(bow_angle)
	var perp = dir.rotated(PI / 2.0)

	# === 4. IDLE ANIMATION ===
	var bounce = abs(sin(_time * 3.0)) * 4.0
	var breathe = sin(_time * 2.0) * 2.0
	var sway = sin(_time * 1.5) * 1.5
	var bob = Vector2(sway, -bounce - breathe)

	# Tier 4: Floating pose (legendary archer levitating)
	var fly_offset = Vector2.ZERO
	if upgrade_tier >= 4:
		fly_offset = Vector2(0, -10.0 + sin(_time * 1.5) * 3.0)

	var body_offset = bob + fly_offset

	# String vibration after shot
	var string_vib = 0.0
	if _attack_anim > 0.3:
		string_vib = sin(_attack_anim * 40.0) * 2.0 * _attack_anim

	# === 5. SKIN COLORS ===
	var skin_base = Color(0.91, 0.74, 0.58)
	var skin_shadow = Color(0.78, 0.60, 0.45)
	var skin_highlight = Color(0.96, 0.82, 0.68)

	# === 6. UPGRADE GLOW ===
	if upgrade_tier > 0:
		var glow_alpha = 0.1 + 0.03 * upgrade_tier
		var glow_col: Color
		match upgrade_tier:
			1: glow_col = Color(0.2, 0.5, 0.1, glow_alpha)    # leaf green
			2: glow_col = Color(0.6, 0.7, 0.8, glow_alpha)    # silver
			3: glow_col = Color(0.75, 0.65, 0.2, glow_alpha)   # gold
			4: glow_col = Color(0.4, 0.8, 0.3, glow_alpha + 0.08) # golden-green
		draw_circle(Vector2.ZERO, 72.0, glow_col)

	# === 7. UPGRADE FLASH ===
	if _upgrade_flash > 0.0:
		draw_circle(Vector2.ZERO, 80.0 + _upgrade_flash * 24.0, Color(0.3, 0.7, 0.2, _upgrade_flash * 0.25))

	# === 8. HORN FLASH (T3 ability) ===
	if _horn_flash > 0.0:
		var horn_ring_r = 36.0 + (1.0 - _horn_flash) * 70.0
		draw_circle(Vector2.ZERO, horn_ring_r, Color(1.0, 0.85, 0.3, _horn_flash * 0.15))
		draw_arc(Vector2.ZERO, horn_ring_r, 0, TAU, 32, Color(1.0, 0.9, 0.4, _horn_flash * 0.3), 2.5)
		# Inner ripple rings
		draw_arc(Vector2.ZERO, horn_ring_r * 0.7, 0, TAU, 24, Color(1.0, 0.85, 0.3, _horn_flash * 0.2), 2.0)
		draw_arc(Vector2.ZERO, horn_ring_r * 0.4, 0, TAU, 16, Color(1.0, 0.9, 0.5, _horn_flash * 0.15), 1.5)
		# Radiating golden sparkle bursts
		for hi in range(8):
			var ha = TAU * float(hi) / 8.0 + _horn_flash * 2.0
			var h_inner = Vector2.from_angle(ha) * (horn_ring_r * 0.5)
			var h_outer = Vector2.from_angle(ha) * (horn_ring_r + 5.0)
			draw_line(h_inner, h_outer, Color(1.0, 0.92, 0.4, _horn_flash * 0.4), 1.5)

	# === 9. STONE PLATFORM ===
	var plat_y = 22.0
	# Platform shadow
	draw_circle(Vector2(0, plat_y + 4), 28.0, Color(0, 0, 0, 0.15))
	# Stone platform ellipse (drawn as squished circles)
	draw_set_transform(Vector2(0, plat_y), 0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 28.0, Color(0.18, 0.16, 0.14))
	draw_circle(Vector2.ZERO, 25.0, Color(0.28, 0.25, 0.22))
	draw_circle(Vector2.ZERO, 20.0, Color(0.35, 0.32, 0.28))
	# Stone texture dots
	for si in range(8):
		var sa = TAU * float(si) / 8.0
		draw_circle(Vector2.from_angle(sa) * 16.0, 3.0, Color(0.25, 0.22, 0.20, 0.4))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# Platform top highlight
	draw_set_transform(Vector2(0, plat_y - 2), 0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 22.0, Color(0.40, 0.36, 0.32, 0.3))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	# === 10. SHADOW TENDRILS ===
	for ti in range(5):
		var ta = TAU * float(ti) / 5.0 + _time * 0.3
		var t_base = Vector2(cos(ta) * 24.0, plat_y + sin(ta) * 8.0)
		var t_end = t_base + Vector2(sin(_time * 0.8 + float(ti)) * 6.0, 8.0 + sin(_time * 1.2 + float(ti)) * 4.0)
		draw_line(t_base, t_end, Color(0.04, 0.02, 0.06, 0.2), 2.0)
		draw_line(t_end, t_end + Vector2(sin(_time + float(ti)) * 3.0, 5.0), Color(0.04, 0.02, 0.06, 0.1), 1.5)

	# === 11. TIER PIPS (forest/silver/gold) ===
	for i in range(upgrade_tier):
		var pip_angle = -PI / 2.0 + float(i) * (TAU / 4.0) - (float(upgrade_tier - 1) * TAU / 8.0)
		var pip_pos = Vector2(cos(pip_angle) * 22.0, plat_y + sin(pip_angle) * 8.0)
		var pip_col: Color
		match i:
			0: pip_col = Color(0.2, 0.6, 0.15)   # forest green
			1: pip_col = Color(0.7, 0.75, 0.82)   # silver
			2: pip_col = Color(0.85, 0.72, 0.25)   # gold
			3: pip_col = Color(0.4, 0.85, 0.35)   # golden-green
		draw_circle(pip_pos, 4.0, pip_col)
		draw_circle(pip_pos, 5.5, Color(pip_col.r, pip_col.g, pip_col.b, 0.15))

	# === 12. CHARACTER POSITIONS (chibi proportions) ===
	var feet_y = body_offset + Vector2(0, 14.0)
	var torso_center = body_offset + Vector2(0, -2.0)
	var head_center = body_offset + Vector2(0, -20.0)

	# === 13. TIER-SPECIFIC EFFECTS (drawn BEFORE/AROUND body) ===

	# Tier 1+: Green leaf particles swirling around feet
	if upgrade_tier >= 1:
		for li in range(5 + upgrade_tier):
			var la = _time * (0.6 + fmod(float(li) * 1.37, 0.5)) + float(li) * TAU / float(5 + upgrade_tier)
			var lr = 22.0 + fmod(float(li) * 3.7, 15.0)
			var leaf_pos = body_offset + Vector2(cos(la) * lr, sin(la) * lr * 0.5 + 10.0)
			var leaf_alpha = 0.2 + sin(_time * 2.0 + float(li)) * 0.1
			var leaf_size = 1.5 + sin(_time * 1.5 + float(li) * 2.0) * 0.5
			# Leaf shape (tiny diamond)
			var leaf_rot = _time * 2.0 + float(li) * 1.5
			var ld = Vector2.from_angle(leaf_rot)
			var lp = ld.rotated(PI / 2.0)
			draw_line(leaf_pos - ld * leaf_size, leaf_pos + ld * leaf_size, Color(0.25, 0.6, 0.15, leaf_alpha), 1.2)
			draw_line(leaf_pos - lp * leaf_size * 0.5, leaf_pos + lp * leaf_size * 0.5, Color(0.3, 0.65, 0.2, leaf_alpha * 0.7), 0.8)

	# Tier 2+: Silver shimmer on bow area
	if upgrade_tier >= 2:
		var silver_pulse = (sin(_time * 2.8) + 1.0) * 0.5
		for spi in range(4):
			var sp_seed = float(spi) * 2.13
			var sp_a = _time * 1.2 + sp_seed
			var sp_r = 16.0 + sin(_time * 1.5 + sp_seed) * 4.0
			var sp_pos = body_offset + Vector2(12.0 + cos(sp_a) * sp_r, sin(sp_a) * sp_r * 0.4)
			var sp_alpha = 0.15 + silver_pulse * 0.12
			draw_circle(sp_pos, 1.2, Color(0.85, 0.88, 0.95, sp_alpha))

	# Tier 4: Fiery arrow particles floating around
	if upgrade_tier >= 4:
		for fd in range(8):
			var fd_seed = float(fd) * 2.37
			var fd_angle = _time * (0.5 + fmod(fd_seed, 0.5)) + fd_seed
			var fd_radius = 30.0 + fmod(fd_seed * 5.3, 25.0)
			var fd_pos = body_offset + Vector2(cos(fd_angle) * fd_radius, sin(fd_angle) * fd_radius * 0.6)
			var fd_alpha = 0.25 + sin(_time * 3.0 + fd_seed * 2.0) * 0.15
			var fd_size = 1.8 + sin(_time * 2.5 + fd_seed) * 0.6
			# Fire colors
			var fire_t = fmod(fd_seed * 1.7, 1.0)
			var fire_col = Color(1.0, 0.5 + fire_t * 0.4, 0.1, fd_alpha)
			draw_circle(fd_pos, fd_size, fire_col)
			draw_circle(fd_pos, fd_size * 0.5, Color(1.0, 0.9, 0.4, fd_alpha * 0.6))
			# Tiny sparkle cross
			draw_line(fd_pos - Vector2(fd_size, 0), fd_pos + Vector2(fd_size, 0), Color(1.0, 1.0, 0.8, fd_alpha * 0.3), 0.5)
			draw_line(fd_pos - Vector2(0, fd_size), fd_pos + Vector2(0, fd_size), Color(1.0, 1.0, 0.8, fd_alpha * 0.3), 0.5)

	# === 14. CHIBI CHARACTER BODY ===

	# --- Brown leather boots (practical, not curled) ---
	var l_foot = feet_y + Vector2(-7, 0)
	var r_foot = feet_y + Vector2(7, 0)
	# Boot base (dark brown leather)
	draw_circle(l_foot, 5.5, Color(0.30, 0.18, 0.08))
	draw_circle(l_foot, 4.2, Color(0.38, 0.24, 0.10))
	draw_circle(r_foot, 5.5, Color(0.30, 0.18, 0.08))
	draw_circle(r_foot, 4.2, Color(0.38, 0.24, 0.10))
	# Boot toe (rounded, practical — not curled like Peter Pan)
	draw_line(l_foot + Vector2(-3, 0), l_foot + Vector2(-7, -1), Color(0.38, 0.24, 0.10), 4.0)
	draw_circle(l_foot + Vector2(-7, -1), 2.5, Color(0.36, 0.22, 0.09))
	draw_line(r_foot + Vector2(3, 0), r_foot + Vector2(7, -1), Color(0.38, 0.24, 0.10), 4.0)
	draw_circle(r_foot + Vector2(7, -1), 2.5, Color(0.36, 0.22, 0.09))
	# Boot highlight (top)
	draw_arc(l_foot, 3.5, PI + 0.3, TAU - 0.3, 6, Color(0.48, 0.32, 0.16, 0.35), 1.5)
	draw_arc(r_foot, 3.5, PI + 0.3, TAU - 0.3, 6, Color(0.48, 0.32, 0.16, 0.35), 1.5)
	# Boot sole (dark line at bottom)
	draw_arc(l_foot, 5.0, 0.3, PI - 0.3, 8, Color(0.15, 0.08, 0.03, 0.5), 1.5)
	draw_arc(r_foot, 5.0, 0.3, PI - 0.3, 8, Color(0.15, 0.08, 0.03, 0.5), 1.5)
	# Boot top cuffs (folded-over leather)
	draw_line(l_foot + Vector2(-4, -3), l_foot + Vector2(4, -3), Color(0.42, 0.28, 0.12), 2.5)
	draw_line(l_foot + Vector2(-3.5, -3.5), l_foot + Vector2(3.5, -3.5), Color(0.50, 0.34, 0.18, 0.5), 1.2)
	draw_line(r_foot + Vector2(-4, -3), r_foot + Vector2(4, -3), Color(0.42, 0.28, 0.12), 2.5)
	draw_line(r_foot + Vector2(-3.5, -3.5), r_foot + Vector2(3.5, -3.5), Color(0.50, 0.34, 0.18, 0.5), 1.2)
	# Boot laces (criss-cross)
	for bi in range(2):
		var boot = l_foot if bi == 0 else r_foot
		for bl in range(2):
			var by = -1.0 - float(bl) * 2.0
			draw_line(boot + Vector2(-2, by), boot + Vector2(2, by - 1.0), Color(0.28, 0.16, 0.06, 0.5), 0.7)
			draw_line(boot + Vector2(2, by), boot + Vector2(-2, by - 1.0), Color(0.28, 0.16, 0.06, 0.5), 0.7)

	# --- Short chibi legs (forest green tights) ---
	draw_line(l_foot + Vector2(0, -3), torso_center + Vector2(-6, 8), Color(0.12, 0.36, 0.06), 5.0)
	draw_line(l_foot + Vector2(0, -3), torso_center + Vector2(-6, 8), Color(0.18, 0.46, 0.10), 3.5)
	draw_line(r_foot + Vector2(0, -3), torso_center + Vector2(6, 8), Color(0.12, 0.36, 0.06), 5.0)
	draw_line(r_foot + Vector2(0, -3), torso_center + Vector2(6, 8), Color(0.18, 0.46, 0.10), 3.5)
	# Knee highlights
	var l_knee = l_foot.lerp(torso_center + Vector2(-6, 8), 0.45)
	var r_knee = r_foot.lerp(torso_center + Vector2(6, 8), 0.45)
	draw_circle(l_knee, 2.5, Color(0.22, 0.52, 0.14, 0.3))
	draw_circle(r_knee, 2.5, Color(0.22, 0.52, 0.14, 0.3))

	# --- 16. QUIVER on back (drawn behind torso) ---
	var quiver_pos = torso_center + Vector2(-8, -4)
	# Quiver body (brown leather, tall rectangle)
	var q_pts = PackedVector2Array([
		quiver_pos + Vector2(-4, 6),
		quiver_pos + Vector2(4, 6),
		quiver_pos + Vector2(3, -14),
		quiver_pos + Vector2(-3, -14),
	])
	draw_colored_polygon(q_pts, Color(0.42, 0.26, 0.10))
	# Quiver inner leather
	var q_inner = PackedVector2Array([
		quiver_pos + Vector2(-2.5, 4),
		quiver_pos + Vector2(2.5, 4),
		quiver_pos + Vector2(2, -12),
		quiver_pos + Vector2(-2, -12),
	])
	draw_colored_polygon(q_inner, Color(0.48, 0.30, 0.14, 0.5))
	# Quiver stitching
	for qi in range(4):
		var qy = 3.0 - float(qi) * 4.5
		draw_line(quiver_pos + Vector2(-3.5, qy), quiver_pos + Vector2(3.5, qy), Color(0.35, 0.20, 0.08, 0.4), 0.7)
	# Quiver rim (top opening)
	draw_line(quiver_pos + Vector2(-3.5, -14), quiver_pos + Vector2(3.5, -14), Color(0.50, 0.34, 0.16), 2.5)
	draw_line(quiver_pos + Vector2(-3, -14.5), quiver_pos + Vector2(3, -14.5), Color(0.56, 0.38, 0.20), 1.5)
	# Quiver strap (crosses chest)
	draw_line(quiver_pos + Vector2(2, -8), torso_center + Vector2(8, -6), Color(0.38, 0.22, 0.08), 2.5)
	draw_line(quiver_pos + Vector2(2, -8), torso_center + Vector2(8, -6), Color(0.44, 0.28, 0.12), 1.5)
	# Strap brass fitting
	var strap_mid = quiver_pos.lerp(torso_center + Vector2(5, -6), 0.5)
	draw_circle(strap_mid, 1.5, Color(0.70, 0.55, 0.20))
	draw_circle(strap_mid, 0.8, Color(0.85, 0.70, 0.30, 0.5))
	# Arrows in quiver (feathers sticking out at top)
	var arrow_count = 3 + upgrade_tier
	for ai in range(arrow_count):
		var ax = -2.0 + float(ai) * (4.0 / float(max(arrow_count - 1, 1)))
		var arrow_top = quiver_pos + Vector2(ax, -16.0 - float(ai % 2) * 2.0)
		var shaft_col = Color(0.58, 0.45, 0.25)
		if upgrade_tier >= 2 and ai == 0:
			shaft_col = Color(0.80, 0.78, 0.65)  # Silver arrow
		if upgrade_tier >= 4 and ai <= 1:
			shaft_col = Color(0.88, 0.72, 0.28)  # Golden arrows
		# Arrow shaft
		draw_line(quiver_pos + Vector2(ax, -13), arrow_top, shaft_col, 1.2)
		# Fletching (3 feathers per arrow, colored)
		var fletch_col = Color(0.75, 0.75, 0.7, 0.7) if ai % 3 == 0 else Color(0.72, 0.18, 0.12, 0.7) if ai % 3 == 1 else Color(0.2, 0.5, 0.2, 0.7)
		draw_line(arrow_top, arrow_top + Vector2(-1.5, -2.5), fletch_col, 1.0)
		draw_line(arrow_top, arrow_top + Vector2(1.5, -2.5), fletch_col.darkened(0.15), 1.0)
		draw_line(arrow_top, arrow_top + Vector2(0, -3.0), fletch_col.lightened(0.1), 0.8)
		# Tier 4: fiery tips
		if upgrade_tier >= 4 and ai < 2:
			var fire_pos = quiver_pos + Vector2(ax, -13)
			draw_circle(fire_pos, 1.5, Color(1.0, 0.6, 0.1, 0.35 + sin(_time * 5.0 + float(ai)) * 0.15))
			draw_circle(fire_pos, 0.8, Color(1.0, 0.9, 0.4, 0.25))

	# --- Lincoln green tunic (broader chibi build than Peter Pan) ---
	var tunic_pts = PackedVector2Array([
		torso_center + Vector2(-15, 10),
		torso_center + Vector2(-16, -2),
		torso_center + Vector2(-12, -10),
		torso_center + Vector2(12, -10),
		torso_center + Vector2(16, -2),
		torso_center + Vector2(15, 10),
	])
	draw_colored_polygon(tunic_pts, Color(0.16, 0.44, 0.10))
	# Lighter inner tunic
	var tunic_hi = PackedVector2Array([
		torso_center + Vector2(-8, 8),
		torso_center + Vector2(-10, -2),
		torso_center + Vector2(10, -2),
		torso_center + Vector2(8, 8),
	])
	draw_colored_polygon(tunic_hi, Color(0.22, 0.54, 0.16, 0.4))
	# V-neckline
	draw_line(torso_center + Vector2(-4, -10), torso_center + Vector2(0, -4), Color(0.12, 0.34, 0.08, 0.6), 1.2)
	draw_line(torso_center + Vector2(4, -10), torso_center + Vector2(0, -4), Color(0.12, 0.34, 0.08, 0.6), 1.2)
	# Undershirt visible at V-neck
	var vneck_pts = PackedVector2Array([
		torso_center + Vector2(-3.5, -10),
		torso_center + Vector2(3.5, -10),
		torso_center + Vector2(0, -5),
	])
	draw_colored_polygon(vneck_pts, Color(0.72, 0.66, 0.52, 0.4))
	# Tunic fold shadows
	draw_line(torso_center + Vector2(-11, -6), torso_center + Vector2(-9, 6), Color(0.10, 0.32, 0.06, 0.4), 1.2)
	draw_line(torso_center + Vector2(11, -6), torso_center + Vector2(9, 6), Color(0.10, 0.32, 0.06, 0.4), 1.2)
	draw_line(torso_center + Vector2(-3, -8), torso_center + Vector2(-2, 4), Color(0.12, 0.36, 0.08, 0.25), 0.8)
	draw_line(torso_center + Vector2(3, -8), torso_center + Vector2(2, 4), Color(0.12, 0.36, 0.08, 0.25), 0.8)
	# Tunic hem (slightly scalloped — Lincoln green style)
	for hi in range(7):
		var hx = -12.0 + float(hi) * 4.0
		var h_depth = 2.5 + sin(float(hi) * 2.1 + _time * 1.2) * 1.5
		var h_pts = PackedVector2Array([
			torso_center + Vector2(hx - 1.5, 9),
			torso_center + Vector2(hx + 1.5, 9),
			torso_center + Vector2(hx, 9 + h_depth),
		])
		draw_colored_polygon(h_pts, Color(0.14, 0.40, 0.08))
	# Cobweb thread (gothic detail)
	draw_line(torso_center + Vector2(-13, -5), torso_center + Vector2(9, 5), Color(0.85, 0.88, 0.92, 0.06), 0.5)

	# --- Brown leather belt with brass buckle ---
	draw_line(torso_center + Vector2(-15, -1), torso_center + Vector2(15, -1), Color(0.32, 0.18, 0.06), 4.0)
	draw_line(torso_center + Vector2(-14, -1), torso_center + Vector2(14, -1), Color(0.40, 0.24, 0.10), 2.5)
	# Belt highlight (top edge)
	draw_line(torso_center + Vector2(-14, -2.5), torso_center + Vector2(14, -2.5), Color(0.48, 0.30, 0.14, 0.35), 0.8)
	# Belt stitch marks
	for bsi in range(6):
		var bsx = -10.0 + float(bsi) * 4.0
		draw_line(torso_center + Vector2(bsx, -2.2), torso_center + Vector2(bsx, 0.2), Color(0.45, 0.28, 0.12, 0.4), 0.6)
	# Brass buckle (center)
	var buckle_c = torso_center + Vector2(0, -1)
	draw_circle(buckle_c, 3.5, Color(0.75, 0.60, 0.18))
	draw_circle(buckle_c, 2.5, Color(0.85, 0.72, 0.28))
	draw_circle(buckle_c, 1.5, Color(0.35, 0.20, 0.08))
	# Buckle highlight
	draw_arc(buckle_c, 2.8, PI + 0.5, TAU - 0.5, 6, Color(1.0, 0.92, 0.50, 0.4), 0.8)
	draw_arc(buckle_c, 3.5, 0, TAU, 8, Color(0.60, 0.48, 0.14, 0.3), 0.6)
	# Coin pouch on belt (left side)
	var pouch_pos = torso_center + Vector2(-10, 1)
	draw_circle(pouch_pos, 3.2, Color(0.38, 0.22, 0.08))
	draw_circle(pouch_pos + Vector2(0, -0.5), 2.5, Color(0.44, 0.28, 0.12))
	# Pouch drawstring
	draw_line(pouch_pos + Vector2(-1, -2.5), pouch_pos + Vector2(1, -2.5), Color(0.32, 0.18, 0.06, 0.5), 0.6)
	# Coins peeking out
	draw_circle(pouch_pos + Vector2(0.5, -3.0), 0.8, Color(0.85, 0.72, 0.22, 0.5))

	# --- Tier 3+: Golden hunting horn hanging from belt ---
	if upgrade_tier >= 3:
		var horn_base = torso_center + Vector2(10, 2)
		var horn_curve = horn_base + Vector2(6, 5)
		var horn_bell = horn_base + Vector2(10, 9)
		# Horn shadow
		draw_line(horn_base + Vector2(0.5, 0.5), horn_curve + Vector2(0.5, 0.5), Color(0, 0, 0, 0.1), 3.5)
		draw_line(horn_curve + Vector2(0.5, 0.5), horn_bell + Vector2(0.5, 0.5), Color(0, 0, 0, 0.1), 4.0)
		# Horn body (tapered brass)
		draw_line(horn_base, horn_curve, Color(0.70, 0.55, 0.18), 3.0)
		draw_line(horn_curve, horn_bell, Color(0.75, 0.60, 0.22), 3.5)
		# Horn golden highlight
		draw_line(horn_base, horn_curve, Color(0.88, 0.75, 0.35, 0.4), 1.5)
		draw_line(horn_curve, horn_bell, Color(0.92, 0.80, 0.40, 0.35), 1.8)
		# Decorative bands
		var hb1 = horn_base.lerp(horn_curve, 0.4)
		var hb2 = horn_curve.lerp(horn_bell, 0.5)
		draw_line(hb1 + Vector2(-1.5, 0), hb1 + Vector2(1.5, 0), Color(0.85, 0.70, 0.28), 1.2)
		draw_line(hb2 + Vector2(-2.0, 0), hb2 + Vector2(2.0, 0), Color(0.85, 0.70, 0.28), 1.2)
		# Horn bell (flared end)
		draw_circle(horn_bell, 3.5, Color(0.78, 0.62, 0.22))
		draw_circle(horn_bell, 2.0, Color(0.52, 0.38, 0.14))
		draw_arc(horn_bell, 3.0, PI + 0.4, TAU - 0.4, 6, Color(0.95, 0.82, 0.42, 0.5), 1.0)
		# Mouthpiece
		draw_circle(horn_base, 1.5, Color(0.85, 0.72, 0.32))
		# Leather cord from belt
		draw_line(horn_base, torso_center + Vector2(8, -1), Color(0.42, 0.26, 0.10), 1.5)
		# Tier 4: horn glow
		if upgrade_tier >= 4:
			draw_circle(horn_bell, 5.5, Color(1.0, 0.85, 0.3, 0.1 + sin(_time * 3.0) * 0.05))

	# --- Shoulder pads (broader build than Peter Pan) ---
	draw_circle(torso_center + Vector2(-14, -8), 6.5, Color(0.14, 0.38, 0.08))
	draw_circle(torso_center + Vector2(-14, -8), 5.0, Color(0.20, 0.48, 0.12))
	draw_line(torso_center + Vector2(-17, -8), torso_center + Vector2(-11, -8), Color(0.10, 0.30, 0.06, 0.5), 0.7)
	draw_circle(torso_center + Vector2(14, -8), 6.5, Color(0.14, 0.38, 0.08))
	draw_circle(torso_center + Vector2(14, -8), 5.0, Color(0.20, 0.48, 0.12))
	draw_line(torso_center + Vector2(11, -8), torso_center + Vector2(17, -8), Color(0.10, 0.30, 0.06, 0.5), 0.7)
	# Shoulder seam stitching
	draw_arc(torso_center + Vector2(-14, -8), 5.5, 0, TAU, 10, Color(0.10, 0.30, 0.06, 0.35), 0.7)
	draw_arc(torso_center + Vector2(14, -8), 5.5, 0, TAU, 10, Color(0.10, 0.30, 0.06, 0.35), 0.7)

	# --- Arms ---
	# Left arm: bow-holding arm (reaches toward aim with bow)
	var bow_hand = torso_center + Vector2(12, -6) + dir * 18.0
	# Upper arm to bow hand
	draw_line(torso_center + Vector2(14, -8), bow_hand, skin_shadow, 4.5)
	draw_line(torso_center + Vector2(14, -8), bow_hand, skin_base, 3.5)
	# Sleeve on upper arm
	var bow_elbow = torso_center + Vector2(14, -8) + (bow_hand - torso_center - Vector2(14, -8)) * 0.4
	draw_line(torso_center + Vector2(14, -8), bow_elbow, Color(0.18, 0.46, 0.10), 5.0)
	draw_line(torso_center + Vector2(14, -8), bow_elbow, Color(0.22, 0.52, 0.14), 3.5)
	# Leather bracer on bow arm
	var bracer_start = bow_elbow + (bow_hand - bow_elbow).normalized() * 2.0
	var bracer_end = bow_hand - (bow_hand - bow_elbow).normalized() * 3.0
	draw_line(bracer_start, bracer_end, Color(0.38, 0.22, 0.08), 5.0)
	draw_line(bracer_start, bracer_end, Color(0.46, 0.30, 0.12), 3.5)
	# Bracer strap details
	for bri in range(3):
		var brt = float(bri + 1) / 4.0
		var br_pos = bracer_start.lerp(bracer_end, brt)
		var br_perp = (bow_hand - bow_elbow).normalized().rotated(PI / 2.0)
		draw_line(br_pos - br_perp * 2.5, br_pos + br_perp * 2.5, Color(0.32, 0.18, 0.06, 0.5), 0.7)
	# Bow hand
	draw_circle(bow_hand, 3.2, skin_shadow)
	draw_circle(bow_hand, 2.5, skin_base)
	# Fingers gripping bow
	for fi in range(3):
		var fa = float(fi - 1) * 0.35
		draw_circle(bow_hand + dir.rotated(fa) * 3.0, 1.0, skin_highlight)

	# Right arm: string-pulling arm (draws arrow back)
	var string_pull_vec = dir * (-12.0 * _draw_progress)
	var draw_hand = torso_center + Vector2(-8, -4) + dir * 6.0 + string_pull_vec
	# Arm
	draw_line(torso_center + Vector2(-14, -8), draw_hand, skin_shadow, 4.5)
	draw_line(torso_center + Vector2(-14, -8), draw_hand, skin_base, 3.5)
	# Sleeve on upper arm
	var draw_elbow = torso_center + Vector2(-14, -8) + (draw_hand - torso_center - Vector2(-14, -8)) * 0.4
	draw_line(torso_center + Vector2(-14, -8), draw_elbow, Color(0.18, 0.46, 0.10), 5.0)
	draw_line(torso_center + Vector2(-14, -8), draw_elbow, Color(0.22, 0.52, 0.14), 3.5)
	# Leather tab/glove on drawing hand
	draw_circle(draw_hand, 3.0, Color(0.40, 0.24, 0.10))
	draw_circle(draw_hand, 2.2, skin_base)
	# Three fingers on string (archer's draw)
	draw_line(draw_hand, draw_hand + dir * 2.5 + perp * 1.2, Color(0.78, 0.62, 0.48), 1.3)
	draw_line(draw_hand, draw_hand + dir * 2.8, Color(0.78, 0.62, 0.48), 1.3)
	draw_line(draw_hand, draw_hand + dir * 2.5 - perp * 1.2, Color(0.78, 0.62, 0.48), 1.3)
	# Fingertips
	draw_circle(draw_hand + dir * 2.5 + perp * 1.2, 0.6, skin_highlight)
	draw_circle(draw_hand + dir * 2.8, 0.6, skin_highlight)
	draw_circle(draw_hand + dir * 2.5 - perp * 1.2, 0.6, skin_highlight)

	# === 15. WEAPON — LONGBOW ===
	var bow_center = bow_hand + dir * 2.0
	var bow_top = bow_center + Vector2(0, -22.0)
	var bow_bottom = bow_center + Vector2(0, 22.0)
	var bow_curve_pt = bow_center + dir * 8.0

	# Bow limb colors (yew wood, silver-tinted at tier 2+)
	var bow_dark = Color(0.48, 0.28, 0.10) if upgrade_tier < 2 else Color(0.50, 0.45, 0.40).lerp(Color(0.65, 0.68, 0.72), 0.3)
	var bow_light = Color(0.60, 0.38, 0.16) if upgrade_tier < 2 else Color(0.60, 0.56, 0.50).lerp(Color(0.75, 0.78, 0.82), 0.3)

	# Tier 2+: Silver glow along bow
	if upgrade_tier >= 2:
		var silver_p = (sin(_time * 2.8) + 1.0) * 0.5
		var silver_a = 0.06 + silver_p * 0.04
		for sgi in range(5):
			var sgt = float(sgi) / 4.0
			draw_circle(bow_top.lerp(bow_curve_pt, sgt), 4.0, Color(0.8, 0.85, 0.95, silver_a))
			draw_circle(bow_curve_pt.lerp(bow_bottom, sgt), 4.0, Color(0.8, 0.85, 0.95, silver_a))

	# Bow upper limb
	draw_line(bow_top, bow_curve_pt, bow_dark, 4.5)
	draw_line(bow_top, bow_curve_pt, bow_light, 2.5)
	# Bow lower limb
	draw_line(bow_curve_pt, bow_bottom, bow_dark, 4.5)
	draw_line(bow_curve_pt, bow_bottom, bow_light, 2.5)
	# Wood grain lines
	draw_line(bow_top.lerp(bow_curve_pt, 0.1) + perp * 0.5, bow_top.lerp(bow_curve_pt, 0.75) + perp * 0.5, Color(bow_light.r + 0.05, bow_light.g + 0.02, bow_light.b, 0.3), 0.6)
	draw_line(bow_curve_pt.lerp(bow_bottom, 0.15) - perp * 0.4, bow_curve_pt.lerp(bow_bottom, 0.8) - perp * 0.4, Color(bow_dark.r - 0.05, bow_dark.g - 0.02, bow_dark.b, 0.25), 0.5)
	# Wood knot
	draw_circle(bow_top.lerp(bow_curve_pt, 0.35), 0.8, Color(bow_dark.r - 0.1, bow_dark.g - 0.05, bow_dark.b, 0.4))
	# Horn nocks at tips
	draw_circle(bow_top, 2.0, Color(0.88, 0.85, 0.78))
	draw_circle(bow_top, 1.3, Color(0.92, 0.90, 0.84))
	draw_circle(bow_bottom, 2.0, Color(0.88, 0.85, 0.78))
	draw_circle(bow_bottom, 1.3, Color(0.92, 0.90, 0.84))
	# Nock grooves
	draw_line(bow_top + Vector2(-0.5, 0), bow_top + Vector2(0.5, 0), Color(0.60, 0.55, 0.45, 0.5), 0.5)
	draw_line(bow_bottom + Vector2(-0.5, 0), bow_bottom + Vector2(0.5, 0), Color(0.60, 0.55, 0.45, 0.5), 0.5)
	# Leather grip wrap
	draw_line(bow_curve_pt + Vector2(0, -3.5), bow_curve_pt + Vector2(0, 3.5), Color(0.35, 0.20, 0.08), 5.5)
	draw_line(bow_curve_pt + Vector2(0, -2.5), bow_curve_pt + Vector2(0, 2.5), Color(0.42, 0.26, 0.10), 4.0)
	draw_line(bow_curve_pt + Vector2(0, -1.5), bow_curve_pt + Vector2(0, 1.5), Color(0.48, 0.30, 0.14), 2.5)
	# Grip cross-hatch wrapping
	for gi in range(4):
		var gy = -2.5 + float(gi) * 1.5
		var gp = bow_curve_pt + Vector2(0, gy)
		draw_line(gp + Vector2(-2.0, -0.5), gp + Vector2(2.0, 0.5), Color(0.32, 0.18, 0.06, 0.4), 0.6)

	# Bowstring
	var string_pull_offset = dir * (-10.0 * _draw_progress)
	var vib_offset = perp * string_vib
	var string_nock_pt = bow_center + string_pull_offset + vib_offset
	# String shadow
	draw_line(bow_top, string_nock_pt, Color(0.4, 0.35, 0.25, 0.12), 1.5)
	draw_line(bow_bottom, string_nock_pt, Color(0.4, 0.35, 0.25, 0.12), 1.5)
	# Main bowstring
	draw_line(bow_top, string_nock_pt, Color(0.78, 0.72, 0.58), 1.2)
	draw_line(bow_bottom, string_nock_pt, Color(0.78, 0.72, 0.58), 1.2)
	# String sheen
	draw_line(bow_top, string_nock_pt, Color(0.90, 0.85, 0.72, 0.25), 0.5)
	draw_line(bow_bottom, string_nock_pt, Color(0.90, 0.85, 0.72, 0.25), 0.5)
	# Serving (thicker wrap where arrow nocks)
	var serving_c = bow_center + string_pull_offset * 0.5 + vib_offset * 0.5
	draw_line(serving_c + Vector2(0, -2.0), serving_c + Vector2(0, 2.0), Color(0.70, 0.65, 0.50, 0.3), 2.0)

	# Arrow nocked on string (visible when drawing)
	if _draw_progress > 0.15:
		var arrow_nock = bow_center + string_pull_offset
		var arrow_tip = bow_center + dir * 28.0

		# Silver arrow detection
		var next_is_silver = upgrade_tier >= 2 and (shot_count + 1) % silver_interval == 0
		var shaft_col = Color(0.82, 0.78, 0.55) if next_is_silver else Color(0.58, 0.46, 0.28)
		var head_col = Color(0.88, 0.80, 0.35) if next_is_silver else Color(0.50, 0.50, 0.55)

		# Arrow shaft shadow
		draw_line(arrow_nock + perp * 0.3, arrow_tip + perp * 0.3, Color(0.3, 0.2, 0.1, 0.12), 2.0)
		# Arrow shaft
		draw_line(arrow_nock, arrow_tip, shaft_col, 1.5)
		# Wood grain highlight
		draw_line(arrow_nock, arrow_tip, Color(shaft_col.r + 0.08, shaft_col.g + 0.08, shaft_col.b + 0.04, 0.25), 0.5)

		# Broadhead
		var head_base = arrow_tip - dir * 4.0
		var head_pts = PackedVector2Array([
			arrow_tip,
			head_base + perp * 3.5,
			head_base - dir * 1.0,
			head_base - perp * 3.5,
		])
		draw_colored_polygon(head_pts, head_col)
		# Broadhead edge
		draw_line(arrow_tip, head_base + perp * 3.5, Color(head_col.r + 0.1, head_col.g + 0.1, head_col.b + 0.05, 0.5), 0.6)
		draw_line(arrow_tip, head_base - perp * 3.5, Color(head_col.r - 0.05, head_col.g - 0.05, head_col.b, 0.4), 0.6)
		# Center blade line
		draw_line(arrow_tip, head_base - dir * 1.0, Color(0.72, 0.72, 0.78, 0.5), 0.8)

		# Fletching (3 feathers)
		var fletch_start = arrow_nock + dir * 1.5
		var fletch_end = arrow_nock + dir * 6.0
		draw_line(fletch_start + perp * 2.2, fletch_end + perp * 1.2, Color(0.82, 0.82, 0.78), 1.5)
		draw_line(fletch_start - perp * 2.2, fletch_end - perp * 1.2, Color(0.82, 0.82, 0.78), 1.5)
		draw_line(fletch_start + dir * 0.3, fletch_end + dir * 0.3, Color(0.75, 0.18, 0.12), 1.5)
		# Feather barb lines
		for fli in range(4):
			var flt = float(fli + 1) / 5.0
			var fl_top = fletch_start.lerp(fletch_end, flt)
			draw_line(fl_top, fl_top + perp * (2.0 - flt * 0.8) * 0.3, Color(0.78, 0.78, 0.72, 0.35), 0.4)
			draw_line(fl_top, fl_top - perp * (2.0 - flt * 0.8) * 0.3, Color(0.78, 0.78, 0.72, 0.35), 0.4)
		# Nock point
		draw_circle(arrow_nock, 1.0, Color(0.88, 0.84, 0.74))

		# Silver glow on arrow
		if next_is_silver:
			var sglow = (sin(_time * 4.0) + 1.0) * 0.5
			draw_circle(arrow_tip, 5.0 + sglow * 2.0, Color(0.88, 0.90, 1.0, 0.2))
			draw_circle(arrow_tip, 2.5 + sglow, Color(1.0, 0.95, 0.72, 0.25))

		# Tier 4: Fiery arrow tip
		if upgrade_tier >= 4:
			var ff1 = sin(_time * 8.0) * 0.5 + 0.5
			var ff2 = sin(_time * 11.0 + 1.5) * 0.5 + 0.5
			draw_circle(arrow_tip, 4.5 + ff1 * 2.0, Color(1.0, 0.4, 0.05, 0.18 + ff1 * 0.08))
			draw_circle(arrow_tip, 2.5 + ff2 * 1.0, Color(1.0, 0.7, 0.1, 0.25))
			draw_circle(arrow_tip, 1.2 + ff1 * 0.5, Color(1.0, 0.95, 0.5, 0.3))
			# Flame tongues
			draw_line(arrow_tip, arrow_tip + dir * (3.5 + ff1 * 1.5) + perp * sin(_time * 6.0) * 1.2, Color(1.0, 0.5, 0.1, 0.25), 1.2)
			draw_line(arrow_tip, arrow_tip + dir * (2.5 + ff2 * 1.0) - perp * sin(_time * 7.0) * 0.8, Color(1.0, 0.6, 0.15, 0.2), 1.0)
			# Ember particles
			for ei in range(3):
				var ea = _time * 5.0 + float(ei) * TAU / 3.0
				var er = 2.0 + sin(_time * 3.0 + float(ei)) * 1.2
				var epos = arrow_tip + Vector2(cos(ea) * er, sin(ea) * er * 0.5) + dir * 1.5
				draw_circle(epos, 0.5, Color(1.0, 0.65 + sin(_time * 4.0 + float(ei)) * 0.2, 0.2, 0.35))

	# === HEAD (big chibi head ~40% of total height) ===
	# Neck
	draw_line(torso_center + Vector2(0, -10), head_center + Vector2(0, 8), skin_shadow, 5.0)
	draw_line(torso_center + Vector2(0, -10), head_center + Vector2(0, 8), skin_base, 3.5)

	# Auburn/brown messy hair (back layer, drawn before face)
	var hair_sway = sin(_time * 2.5) * 2.0
	var hair_base_col = Color(0.42, 0.22, 0.10)
	var hair_mid_col = Color(0.50, 0.28, 0.12)
	var hair_hi_col = Color(0.58, 0.34, 0.16)
	# Hair mass (slightly shorter/messier than Peter Pan)
	draw_circle(head_center, 14.0, hair_base_col)
	draw_circle(head_center + Vector2(0, -1), 12.5, hair_mid_col)
	# Volume highlight
	draw_circle(head_center + Vector2(-2, -3), 7.0, Color(0.52, 0.30, 0.14, 0.3))
	# Messy tufts (windswept but shorter)
	var tuft_data = [
		[0.3, 5.5, 2.5], [1.0, 6.0, 2.2], [1.7, 5.0, 2.8], [2.4, 6.5, 2.0],
		[3.2, 5.5, 2.5], [4.0, 6.0, 2.3], [4.8, 5.5, 2.6], [5.5, 6.0, 2.0],
	]
	for h in range(8):
		var ha: float = tuft_data[h][0]
		var tlen: float = tuft_data[h][1]
		var twid: float = tuft_data[h][2]
		var tuft_base_pos = head_center + Vector2.from_angle(ha) * 12.0
		var sway_d = 1.0 if h % 2 == 0 else -1.0
		var tuft_tip_pos = tuft_base_pos + Vector2.from_angle(ha) * tlen + Vector2(hair_sway * sway_d * 0.4, 0)
		var tcol = hair_mid_col if h % 3 == 0 else hair_hi_col if h % 3 == 1 else hair_base_col
		draw_line(tuft_base_pos, tuft_tip_pos, tcol, twid)
		# Secondary wispy strand
		var ha2 = ha + (0.12 if h % 2 == 0 else -0.12)
		var t2_base = head_center + Vector2.from_angle(ha2) * 11.0
		var t2_tip = t2_base + Vector2.from_angle(ha2) * (tlen * 0.5) + Vector2(hair_sway * sway_d * 0.2, 0)
		draw_line(t2_base, t2_tip, hair_base_col, twid * 0.5)

	# Face
	draw_circle(head_center + Vector2(0, 1), 11.5, skin_base)
	# Face shading (jaw)
	draw_arc(head_center + Vector2(0, 1), 10.5, PI * 0.6, PI * 1.4, 12, skin_shadow, 1.5)
	# Slight weathering (outdoor skin)
	draw_arc(head_center + Vector2(0, 0), 9.0, PI * 0.7, PI * 1.3, 10, Color(0.82, 0.66, 0.50, 0.15), 2.0)

	# Ears (partially visible under hair/cap)
	# Right ear
	var r_ear = head_center + Vector2(11, -1)
	draw_circle(r_ear, 3.0, skin_base)
	draw_circle(r_ear + Vector2(0.5, 0), 2.0, Color(0.88, 0.68, 0.55, 0.5))
	draw_arc(r_ear, 2.5, -0.5, 1.0, 6, skin_shadow, 0.8)
	# Left ear
	var l_ear = head_center + Vector2(-11, -1)
	draw_circle(l_ear, 3.0, skin_base)
	draw_circle(l_ear + Vector2(-0.5, 0), 2.0, Color(0.88, 0.68, 0.55, 0.5))
	draw_arc(l_ear, 2.5, PI - 0.5, PI + 1.0, 6, skin_shadow, 0.8)

	# Short stubbly beard / 5 o'clock shadow on jawline
	var stubble_c = head_center + Vector2(0, 6)
	draw_arc(stubble_c, 6.0, 0.3, PI - 0.3, 10, Color(0.40, 0.26, 0.16, 0.18), 2.5)
	# Individual stubble dots
	for sti in range(10):
		var st_a = 0.4 + float(sti) * (PI - 0.8) / 9.0
		var st_r = 4.5 + sin(float(sti) * 2.1) * 1.2
		var st_pos = stubble_c + Vector2.from_angle(st_a) * st_r
		draw_circle(st_pos, 0.35, Color(0.38, 0.24, 0.14, 0.22))
	for sti in range(7):
		var st_a = 0.5 + float(sti) * (PI - 1.0) / 6.0
		var st_r = 3.5 + cos(float(sti) * 1.8) * 0.8
		var st_pos = stubble_c + Vector2.from_angle(st_a) * st_r
		draw_circle(st_pos, 0.3, Color(0.36, 0.22, 0.12, 0.18))
	# Chin stubble (thicker patch)
	draw_arc(head_center + Vector2(0, 9), 3.0, 0.5, PI - 0.5, 6, Color(0.38, 0.24, 0.14, 0.2), 1.5)

	# Big green eyes that track aim direction
	var look_dir = dir * 1.5
	var l_eye = head_center + Vector2(-5, -1)
	var r_eye = head_center + Vector2(5, -1)
	# Eye socket shadow
	draw_circle(l_eye, 5.5, Color(0.72, 0.56, 0.44, 0.25))
	draw_circle(r_eye, 5.5, Color(0.72, 0.56, 0.44, 0.25))
	# Eye whites
	draw_circle(l_eye, 5.0, Color(0.96, 0.96, 0.98))
	draw_circle(r_eye, 5.0, Color(0.96, 0.96, 0.98))
	# Green irises (large for chibi, following aim)
	draw_circle(l_eye + look_dir, 3.2, Color(0.10, 0.42, 0.15))
	draw_circle(l_eye + look_dir, 2.5, Color(0.16, 0.58, 0.22))
	draw_circle(l_eye + look_dir, 1.8, Color(0.22, 0.65, 0.28))
	draw_circle(r_eye + look_dir, 3.2, Color(0.10, 0.42, 0.15))
	draw_circle(r_eye + look_dir, 2.5, Color(0.16, 0.58, 0.22))
	draw_circle(r_eye + look_dir, 1.8, Color(0.22, 0.65, 0.28))
	# Limbal ring (gold-green)
	draw_arc(l_eye + look_dir, 3.0, 0, TAU, 10, Color(0.55, 0.48, 0.12, 0.25), 0.5)
	draw_arc(r_eye + look_dir, 3.0, 0, TAU, 10, Color(0.55, 0.48, 0.12, 0.25), 0.5)
	# Iris radial detail
	for iri in range(6):
		var ir_a = TAU * float(iri) / 6.0
		var ir_v = Vector2.from_angle(ir_a)
		draw_line(l_eye + look_dir + ir_v * 0.6, l_eye + look_dir + ir_v * 1.6, Color(0.14, 0.48, 0.18, 0.2), 0.3)
		draw_line(r_eye + look_dir + ir_v * 0.6, r_eye + look_dir + ir_v * 1.6, Color(0.14, 0.48, 0.18, 0.2), 0.3)
	# Pupils
	draw_circle(l_eye + look_dir * 1.15, 1.5, Color(0.05, 0.05, 0.07))
	draw_circle(r_eye + look_dir * 1.15, 1.5, Color(0.05, 0.05, 0.07))
	# Primary highlight (big sparkle)
	draw_circle(l_eye + Vector2(-1.2, -1.5), 1.4, Color(1.0, 1.0, 1.0, 0.9))
	draw_circle(r_eye + Vector2(-1.2, -1.5), 1.4, Color(1.0, 1.0, 1.0, 0.9))
	# Secondary highlight
	draw_circle(l_eye + Vector2(1.5, 0.5), 0.7, Color(1.0, 1.0, 1.0, 0.5))
	draw_circle(r_eye + Vector2(1.5, 0.5), 0.7, Color(1.0, 1.0, 1.0, 0.5))
	# Keen archer glint (focused green)
	var glint_t = sin(_time * 2.0) * 0.2
	draw_circle(l_eye + Vector2(0.5, -0.5), 0.5, Color(0.3, 0.8, 0.4, 0.2 + glint_t))
	draw_circle(r_eye + Vector2(0.5, -0.5), 0.5, Color(0.3, 0.8, 0.4, 0.2 + glint_t))
	# Upper eyelids (slightly narrowed — focused look)
	draw_arc(l_eye, 5.0, PI + 0.25, TAU - 0.25, 8, Color(0.38, 0.22, 0.10), 1.3)
	draw_arc(r_eye, 5.0, PI + 0.25, TAU - 0.25, 8, Color(0.38, 0.22, 0.10), 1.3)
	# Eyelashes (subtle — masculine but defined)
	for el in range(2):
		var ela = PI + 0.45 + float(el) * 0.65
		draw_line(l_eye + Vector2.from_angle(ela) * 5.0, l_eye + Vector2.from_angle(ela) * 6.5, Color(0.35, 0.20, 0.10, 0.4), 0.6)
		draw_line(r_eye + Vector2.from_angle(ela) * 5.0, r_eye + Vector2.from_angle(ela) * 6.5, Color(0.35, 0.20, 0.10, 0.4), 0.6)
	# Lower eyelid line
	draw_arc(l_eye, 4.5, 0.3, PI - 0.3, 8, Color(0.50, 0.38, 0.28, 0.25), 0.5)
	draw_arc(r_eye, 4.5, 0.3, PI - 0.3, 8, Color(0.50, 0.38, 0.28, 0.25), 0.5)

	# Eyebrows — bold, one slightly cocked (roguish confidence)
	# Left brow (arched higher — cocky raised brow)
	draw_line(l_eye + Vector2(-4.0, -5.5), l_eye + Vector2(0, -6.5), Color(0.40, 0.24, 0.12), 2.0)
	draw_line(l_eye + Vector2(0, -6.5), l_eye + Vector2(3.5, -5.0), Color(0.40, 0.24, 0.12), 1.5)
	# Right brow (slightly lower — asymmetric for character)
	draw_line(r_eye + Vector2(-3.5, -5.0), r_eye + Vector2(0, -6.0), Color(0.40, 0.24, 0.12), 2.0)
	draw_line(r_eye + Vector2(0, -6.0), r_eye + Vector2(4.0, -4.5), Color(0.40, 0.24, 0.12), 1.5)
	# Brow hair texture
	for bhi in range(3):
		var bht = float(bhi) / 2.0
		var bh_l = (l_eye + Vector2(-3.5, -5.5)).lerp(l_eye + Vector2(3.0, -5.5), bht)
		draw_line(bh_l, bh_l + Vector2(0.5, -0.8), Color(0.42, 0.28, 0.14, 0.35), 0.5)
		var bh_r = (r_eye + Vector2(-3.0, -5.0)).lerp(r_eye + Vector2(3.5, -5.0), bht)
		draw_line(bh_r, bh_r + Vector2(-0.5, -0.8), Color(0.42, 0.28, 0.14, 0.35), 0.5)

	# Nose (strong, slightly aquiline — handsome rogue)
	draw_circle(head_center + Vector2(0, 3.5), 2.0, skin_highlight)
	draw_circle(head_center + Vector2(0.3, 3.8), 1.5, Color(0.92, 0.76, 0.62))
	# Nose bridge highlight
	draw_line(head_center + Vector2(0, 0), head_center + Vector2(0, 3.0), Color(0.94, 0.80, 0.66, 0.3), 0.8)
	# Nostrils
	draw_circle(head_center + Vector2(-1.2, 4.2), 0.6, Color(0.55, 0.40, 0.30, 0.4))
	draw_circle(head_center + Vector2(1.2, 4.2), 0.6, Color(0.55, 0.40, 0.30, 0.4))
	# Nose shadow (side)
	draw_line(head_center + Vector2(-1.0, 1.5), head_center + Vector2(-1.2, 3.5), Color(0.62, 0.45, 0.32, 0.25), 0.6)

	# Cheek blush (weathered outdoorsman)
	draw_circle(head_center + Vector2(-7, 3), 3.5, Color(0.90, 0.55, 0.45, 0.15))
	draw_circle(head_center + Vector2(7, 3), 3.5, Color(0.90, 0.55, 0.45, 0.15))

	# Confident cocky smirk
	draw_arc(head_center + Vector2(0.5, 7), 5.5, 0.2, PI - 0.4, 12, Color(0.58, 0.28, 0.20), 1.8)
	# Teeth showing (just a flash of white behind smirk)
	for thi in range(3):
		var tooth_x = -1.5 + float(thi) * 1.5
		draw_circle(head_center + Vector2(tooth_x, 7.2), 0.8, Color(0.98, 0.96, 0.92))
	# Asymmetric smirk upturn (right side curves up more — cocky)
	draw_line(head_center + Vector2(4.5, 6.5), head_center + Vector2(6.5, 5.0), Color(0.58, 0.28, 0.20, 0.5), 1.2)
	# Dimple at smirk corner
	draw_circle(head_center + Vector2(6.5, 5.5), 1.0, Color(0.78, 0.56, 0.44, 0.35))
	draw_circle(head_center + Vector2(-5.5, 6.5), 1.0, Color(0.78, 0.56, 0.44, 0.25))
	# Laugh lines (slight, adds character to weathered face)
	draw_arc(head_center + Vector2(-5, 2.5), 4.0, PI * 0.5, PI * 0.85, 4, Color(0.65, 0.48, 0.35, 0.1), 0.5)
	draw_arc(head_center + Vector2(5, 2.5), 4.0, PI * 0.15, PI * 0.5, 4, Color(0.65, 0.48, 0.35, 0.1), 0.5)

	# === Robin Hood feathered cap/hood ===
	var hat_base = head_center + Vector2(0, -9)
	var hat_tip = hat_base + Vector2(12, -16)
	# Hat shape (pointed like classic Robin Hood cap, slightly structured)
	var hat_pts = PackedVector2Array([
		hat_base + Vector2(-12, 2),
	])
	# Curved brim
	for hbi in range(5):
		var ht = float(hbi) / 4.0
		var brim_pos = hat_base + Vector2(-12.0 + ht * 24.0, 2.0 + sin(ht * PI) * 2.0)
		hat_pts.append(brim_pos)
	hat_pts.append(hat_tip)
	draw_colored_polygon(hat_pts, Color(0.16, 0.44, 0.10))
	# Hat depth shading (darker left side)
	var hat_shade = PackedVector2Array([
		hat_base + Vector2(-10, 1),
		hat_base + Vector2(4, 1),
		hat_tip + Vector2(-2, 1),
	])
	draw_colored_polygon(hat_shade, Color(0.12, 0.36, 0.06, 0.4))
	# Hat highlight (right side catches light)
	var hat_hl = PackedVector2Array([
		hat_base + Vector2(4, 1),
		hat_base + Vector2(12, 1),
		hat_tip + Vector2(1, -1),
	])
	draw_colored_polygon(hat_hl, Color(0.22, 0.54, 0.16, 0.2))
	# Hat brim line
	draw_line(hat_base + Vector2(-13, 2), hat_base + Vector2(13, 2), Color(0.12, 0.36, 0.06), 3.5)
	draw_line(hat_base + Vector2(-13, 2.5), hat_base + Vector2(13, 2.5), Color(0.22, 0.48, 0.14), 2.0)
	# Hat band (thin darker band above brim)
	draw_line(hat_base + Vector2(-12, 0), hat_base + Vector2(12, 0), Color(0.10, 0.30, 0.06), 2.0)
	draw_line(hat_base + Vector2(-11.5, -0.5), hat_base + Vector2(11.5, -0.5), Color(0.14, 0.36, 0.08, 0.5), 1.0)
	# Hat fold/crease lines
	draw_line(hat_base + Vector2(2, 0), hat_tip + Vector2(-1, 1), Color(0.10, 0.30, 0.06, 0.45), 0.8)
	draw_line(hat_base + Vector2(-4, 0), hat_tip + Vector2(-4, 3), Color(0.10, 0.30, 0.06, 0.3), 0.7)
	# Hat outline
	draw_line(hat_base + Vector2(-12, 2), hat_tip, Color(0.10, 0.28, 0.05, 0.45), 0.8)
	draw_line(hat_base + Vector2(12, 2), hat_tip, Color(0.10, 0.28, 0.05, 0.45), 0.8)
	# Tip of hat (droops slightly)
	draw_circle(hat_tip, 2.0, Color(0.14, 0.40, 0.08))
	draw_circle(hat_tip, 1.3, Color(0.18, 0.46, 0.12))

	# Red feather on hat (classic Robin Hood detail)
	var feather_bob = sin(_time * 3.0) * 1.5
	var feather_base = hat_base + Vector2(8, -1)
	var feather_tip = feather_base + Vector2(18, -12 + feather_bob)
	var feather_mid = feather_base + (feather_tip - feather_base) * 0.5
	# Quill (rachis)
	draw_line(feather_base, feather_tip, Color(0.72, 0.10, 0.06), 2.0)
	# Feather body (red plume)
	draw_line(feather_base + (feather_tip - feather_base) * 0.1, feather_tip - (feather_tip - feather_base) * 0.05, Color(0.88, 0.16, 0.08), 4.0)
	draw_line(feather_mid, feather_tip, Color(0.92, 0.22, 0.12), 3.0)
	# Feather barbs (diagonal lines off spine)
	var f_d = (feather_tip - feather_base).normalized()
	var f_p = f_d.rotated(PI / 2.0)
	for fbi in range(7):
		var bt = 0.1 + float(fbi) * 0.12
		var barb_o = feather_base + (feather_tip - feather_base) * bt
		var blen = 3.5 - abs(float(fbi) - 3.0) * 0.4
		draw_line(barb_o, barb_o + f_p * blen + f_d * 1.2, Color(0.85, 0.14, 0.06, 0.8), 0.8)
		draw_line(barb_o, barb_o - f_p * blen + f_d * 1.2, Color(0.85, 0.14, 0.06, 0.8), 0.8)
	# Feather shine
	draw_line(feather_mid + f_p * 0.3, feather_mid + f_d * 5.0, Color(0.95, 0.40, 0.30, 0.35), 1.0)
	# Feather tip sway
	draw_line(feather_tip, feather_tip + f_p * sin(_time * 3.0) * 2.0 + f_d * 2.0, Color(0.85, 0.18, 0.10, 0.4), 1.0)
	# Quill base (white)
	draw_circle(feather_base, 1.0, Color(0.92, 0.88, 0.78))

	# Tier 4: Golden feather overlaid
	if upgrade_tier >= 4:
		var gold_tip = feather_base + Vector2(20, -14 + feather_bob)
		draw_line(feather_base, gold_tip, Color(1.0, 0.85, 0.2), 2.5)
		draw_line(feather_base, gold_tip, Color(1.0, 0.95, 0.5, 0.35), 1.0)
		var gf_d = (gold_tip - feather_base).normalized()
		var gf_p = gf_d.rotated(PI / 2.0)
		for gbi in range(6):
			var gbt = 0.1 + float(gbi) * 0.14
			var gb_o = feather_base + (gold_tip - feather_base) * gbt
			var gb_scale = 1.0 - gbt * 0.25
			draw_line(gb_o, gb_o + gf_p * 3.0 * gb_scale + gf_d * 1.0, Color(1.0, 0.9, 0.35, 0.7), 1.2 * gb_scale)
			draw_line(gb_o, gb_o - gf_p * 2.5 * gb_scale + gf_d * 0.8, Color(0.9, 0.75, 0.2, 0.5), 0.8 * gb_scale)
		# Gold feather glow
		var gf_glow = 0.1 + sin(_time * 3.0) * 0.05
		draw_circle(feather_base.lerp(gold_tip, 0.5), 5.0, Color(1.0, 0.9, 0.3, gf_glow))

	# === Tier 4: Golden-green aura around whole character ===
	if upgrade_tier >= 4:
		var aura_pulse = sin(_time * 2.5) * 5.0
		draw_circle(body_offset, 52.0 + aura_pulse, Color(0.4, 0.8, 0.3, 0.04))
		draw_circle(body_offset, 42.0 + aura_pulse * 0.6, Color(0.5, 0.85, 0.35, 0.06))
		draw_circle(body_offset, 34.0 + aura_pulse * 0.3, Color(1.0, 0.90, 0.4, 0.06))
		draw_arc(body_offset, 48.0 + aura_pulse, 0, TAU, 32, Color(0.4, 0.8, 0.35, 0.15), 2.5)
		draw_arc(body_offset, 38.0 + aura_pulse * 0.5, 0, TAU, 24, Color(1.0, 0.90, 0.4, 0.08), 1.8)
		# Orbiting golden-green sparkles
		for gs in range(6):
			var gs_a = _time * (0.7 + float(gs % 3) * 0.25) + float(gs) * TAU / 6.0
			var gs_r = 38.0 + aura_pulse + float(gs % 3) * 3.5
			var gs_p = body_offset + Vector2.from_angle(gs_a) * gs_r
			var gs_size = 1.3 + sin(_time * 3.0 + float(gs) * 1.5) * 0.6
			var gs_alpha = 0.3 + sin(_time * 3.0 + float(gs)) * 0.18
			draw_circle(gs_p, gs_size, Color(0.5, 0.9, 0.4, gs_alpha))

	# === 21. AWAITING ABILITY CHOICE INDICATOR ===
	if awaiting_ability_choice:
		var pulse = (sin(_time * 4.0) + 1.0) * 0.5
		draw_circle(Vector2.ZERO, 60.0 + pulse * 6.0, Color(0.3, 0.7, 0.2, 0.1 + pulse * 0.1))
		draw_arc(Vector2.ZERO, 60.0 + pulse * 6.0, 0, TAU, 32, Color(0.3, 0.7, 0.2, 0.3 + pulse * 0.3), 2.5)
		var font3 = ThemeDB.fallback_font
		draw_string(font3, Vector2(-16, -68), "!", HORIZONTAL_ALIGNMENT_CENTER, 32, 30, Color(0.3, 0.7, 0.2, 0.7 + pulse * 0.3))

	# === 22. DAMAGE COUNTER ===
	if damage_dealt > 0:
		var font = ThemeDB.fallback_font
		var dmg_text = str(int(damage_dealt)) + " DMG"
		if stat_upgrade_level > 0:
			dmg_text += " • Lv." + str(stat_upgrade_level)
		draw_string(font, Vector2(-36, 56), dmg_text, HORIZONTAL_ALIGNMENT_LEFT, 160, 12, Color(1.0, 0.84, 0.0, 0.5))

	# === 23. UPGRADE NAME FLASH ===
	if _upgrade_flash > 0.0 and _upgrade_name != "":
		var font2 = ThemeDB.fallback_font
		draw_string(font2, Vector2(-80, -60), _upgrade_name, HORIZONTAL_ALIGNMENT_CENTER, 160, 16, Color(0.3, 0.7, 0.2, min(_upgrade_flash, 1.0)))
