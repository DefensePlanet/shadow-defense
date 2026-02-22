extends Node2D
## Ebenezer Scrooge — economy/support tower from Dickens' A Christmas Carol (1843).
## Throws coins for low damage but generates gold. Upgrades by dealing damage.
## Tier 1 (5000 DMG): "Bah, Humbug!" — gold bonus +5, faster attacks
## Tier 2 (10000 DMG): "Ghost of Christmas Past" — periodically mark random enemy (+25% dmg)
## Tier 3 (15000 DMG): "Ghost of Christmas Present" — mark all in range, passive gold gen
## Tier 4 (20000 DMG): "Ghost of Christmas Yet to Come" — marks fear-slow, stronger gold gen

var damage: float = 22.0
var fire_rate: float = 1.8
var attack_range: float = 140.0
var fire_cooldown: float = 0.0
var aim_angle: float = 0.0
var target: Node2D = null
var gold_bonus: int = 3

# Damage tracking and upgrades
var damage_dealt: float = 0.0
var upgrade_tier: int = 0
var _upgrade_flash: float = 0.0
var _upgrade_name: String = ""

# Animation vars
var _time: float = 0.0
var _attack_anim: float = 0.0

# Tier 2: Ghost of Christmas Past — mark one enemy
var ghost_past_timer: float = 0.0
var ghost_past_cooldown: float = 12.0
var _ghost_flash: float = 0.0

# Tier 3: Ghost of Christmas Present — mark all + passive gold
var ghost_present_timer: float = 0.0
var ghost_present_cooldown: float = 10.0
var passive_gold_timer: float = 0.0
var passive_gold_interval: float = 5.0
var passive_gold_amount: int = 1

# Tier 4: Ghost of Yet to Come — fear slow on marks
var fear_enabled: bool = false

const STAT_UPGRADE_INTERVAL: float = 500.0
const ABILITY_THRESHOLD: float = 1500.0
var stat_upgrade_level: int = 0
var ability_chosen: bool = false
var awaiting_ability_choice: bool = false
const TIER_NAMES = [
	"Bah, Humbug!",
	"Ghost of Christmas Past",
	"Ghost of Christmas Present",
	"Ghost of Yet to Come"
]
const ABILITY_DESCRIPTIONS = [
	"Gold bonus +5, faster attacks",
	"Periodically mark enemy (+25% dmg taken)",
	"Mark all in range, passive gold gen",
	"Marks fear-slow, stronger gold gen"
]
const TIER_COSTS = [40, 80, 150, 280]
var is_selected: bool = false
var base_cost: int = 0

var coin_scene = preload("res://scenes/coin.tscn")

func _ready() -> void:
	add_to_group("towers")

func _process(delta: float) -> void:
	_time += delta
	_attack_anim = max(_attack_anim - delta * 3.0, 0.0)
	fire_cooldown -= delta
	_upgrade_flash = max(_upgrade_flash - delta * 0.5, 0.0)
	_ghost_flash = max(_ghost_flash - delta * 1.5, 0.0)
	target = _find_nearest_enemy()

	if target:
		var desired = global_position.angle_to_point(target.global_position) + PI
		aim_angle = lerp_angle(aim_angle, desired, 8.0 * delta)
		if fire_cooldown <= 0.0:
			_shoot()
			fire_cooldown = 1.0 / fire_rate

	# Tier 2: Ghost of Christmas Past — mark single enemy
	if upgrade_tier == 2:
		ghost_past_timer -= delta
		if ghost_past_timer <= 0.0 and _has_enemies_in_range():
			_ghost_of_past()
			ghost_past_timer = ghost_past_cooldown

	# Tier 3+: Ghost of Christmas Present — mark all in range
	if upgrade_tier >= 3:
		ghost_present_timer -= delta
		if ghost_present_timer <= 0.0 and _has_enemies_in_range():
			_ghost_of_present()
			ghost_present_timer = ghost_present_cooldown

		# Passive gold generation
		passive_gold_timer -= delta
		if passive_gold_timer <= 0.0:
			passive_gold_timer = passive_gold_interval
			var main = get_tree().get_first_node_in_group("main")
			if main:
				main.add_gold(passive_gold_amount)

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
	var coin = coin_scene.instantiate()
	coin.global_position = global_position + Vector2.from_angle(aim_angle) * 14.0
	coin.damage = damage
	coin.target = target
	coin.gold_bonus = gold_bonus
	coin.source_tower = self
	get_tree().get_first_node_in_group("main").add_child(coin)
	_attack_anim = 1.0

func _ghost_of_past() -> void:
	_ghost_flash = 1.0
	var enemies = get_tree().get_nodes_in_group("enemies")
	var in_range: Array = []
	for enemy in enemies:
		if global_position.distance_to(enemy.global_position) < attack_range:
			in_range.append(enemy)
	if in_range.size() > 0:
		var picked = in_range[randi() % in_range.size()]
		if picked.has_method("apply_mark"):
			picked.apply_mark(1.25, 5.0, fear_enabled)

func _ghost_of_present() -> void:
	_ghost_flash = 1.2
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(enemy.global_position) < attack_range:
			if enemy.has_method("apply_mark"):
				enemy.apply_mark(1.25, 5.0, fear_enabled)

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
	attack_range += 5.0
	gold_bonus += 2
	# Cash bundle every 500 damage milestone
	var main = get_tree().get_first_node_in_group("main")
	if main:
		main.add_gold(10 + stat_upgrade_level * 5)

func choose_ability(index: int) -> void:
	ability_chosen = true
	awaiting_ability_choice = false
	upgrade_tier = index + 1
	_apply_upgrade(upgrade_tier)
	_upgrade_flash = 3.0
	_upgrade_name = TIER_NAMES[index]

func _apply_upgrade(tier: int) -> void:
	match tier:
		1: # Bah, Humbug! — more gold, faster
			damage = 30.0
			gold_bonus = 10
			fire_rate = 2.2
			attack_range = 155.0
		2: # Ghost of Christmas Past — mark enemies
			damage = 40.0
			fire_rate = 2.5
			attack_range = 170.0
			gold_bonus = 12
			ghost_past_cooldown = 10.0
		3: # Ghost of Christmas Present — mark all + passive gold
			damage = 55.0
			fire_rate = 3.0
			attack_range = 190.0
			gold_bonus = 15
			passive_gold_amount = 3
			passive_gold_interval = 4.0
			ghost_present_cooldown = 8.0
		4: # Ghost of Yet to Come — fear + stronger gold gen
			damage = 70.0
			fear_enabled = true
			fire_rate = 3.5
			gold_bonus = 20
			attack_range = 220.0
			passive_gold_amount = 5
			passive_gold_interval = 2.5
			ghost_present_cooldown = 6.0

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
	return "Scrooge"

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
	var is_kind = upgrade_tier >= 3

	# === SELECTION RING ===
	if is_selected:
		var pulse = (sin(_time * 3.0) + 1.0) * 0.5
		var ring_alpha = 0.5 + pulse * 0.3
		draw_arc(Vector2.ZERO, 40.0, 0, TAU, 48, Color(1.0, 0.84, 0.0, ring_alpha), 2.5)
		draw_arc(Vector2.ZERO, 43.0, 0, TAU, 48, Color(1.0, 0.84, 0.0, ring_alpha * 0.4), 1.5)

	# === RANGE ARC ===
	draw_arc(Vector2.ZERO, attack_range, 0, TAU, 64, Color(1, 1, 1, 0.06), 1.0)

	# === AIM DIRECTION ===
	var dir = Vector2.from_angle(aim_angle)
	var perp = dir.rotated(PI / 2.0)

	# === IDLE ANIMATION ===
	var bounce = abs(sin(_time * 2.5)) * 3.0
	var breathe = sin(_time * 1.8) * 1.5
	var sway = sin(_time * 1.2) * 1.0
	var bob = Vector2(sway, -bounce - breathe)
	var fly_offset = Vector2.ZERO
	if upgrade_tier >= 4:
		fly_offset = Vector2(0, -6.0 + sin(_time * 1.5) * 2.0)
	var body_offset = bob + fly_offset

	# === SKIN COLORS (pale, elderly) ===
	var skin_base = Color(0.85, 0.78, 0.72)
	var skin_shadow = Color(0.70, 0.62, 0.55)
	var skin_highlight = Color(0.92, 0.86, 0.80)

	# === UPGRADE GLOW — cold/ghostly tones ===
	if upgrade_tier > 0:
		var glow_alpha = 0.1 + 0.03 * upgrade_tier
		var glow_col: Color
		match upgrade_tier:
			1: glow_col = Color(0.7, 0.6, 0.2, glow_alpha)
			2: glow_col = Color(0.4, 0.5, 0.8, glow_alpha)
			3: glow_col = Color(0.3, 0.6, 0.3, glow_alpha)
			4: glow_col = Color(0.2, 0.15, 0.25, glow_alpha + 0.08)
		draw_circle(Vector2.ZERO, 72.0, glow_col)

	# === UPGRADE FLASH ===
	if _upgrade_flash > 0.0:
		draw_circle(Vector2.ZERO, 80.0 + _upgrade_flash * 24.0, Color(0.9, 0.85, 0.4, _upgrade_flash * 0.25))
		for i in range(10):
			var ray_a = TAU * float(i) / 10.0 + _time * 0.5
			var ray_inner = 60.0 + _upgrade_flash * 8.0
			var ray_outer = 90.0 + _upgrade_flash * 25.0
			draw_line(Vector2.from_angle(ray_a) * ray_inner, Vector2.from_angle(ray_a) * ray_outer, Color(1.0, 0.95, 0.5, _upgrade_flash * 0.15), 2.0)

	# === GHOST FLASH (spectral expanding ring) ===
	if _ghost_flash > 0.0:
		var ghost_col: Color
		if upgrade_tier >= 4:
			ghost_col = Color(0.15, 0.1, 0.2, _ghost_flash * 0.4)
		elif upgrade_tier >= 3:
			ghost_col = Color(0.3, 0.6, 0.2, _ghost_flash * 0.3)
		else:
			ghost_col = Color(0.5, 0.6, 0.8, _ghost_flash * 0.3)
		var ripple_r = 40.0 + (1.0 - _ghost_flash) * 100.0
		draw_circle(Vector2.ZERO, ripple_r * 0.8, ghost_col)
		draw_arc(Vector2.ZERO, ripple_r, 0, TAU, 48, Color(ghost_col.r, ghost_col.g, ghost_col.b, _ghost_flash * 0.5), 2.5)
		draw_arc(Vector2.ZERO, ripple_r * 0.6, 0, TAU, 36, Color(ghost_col.r, ghost_col.g, ghost_col.b, _ghost_flash * 0.25), 1.5)
		for i in range(6):
			var wisp_a = TAU * float(i) / 6.0 + _time * 0.8
			var wisp_r2 = ripple_r * (0.5 + sin(_time * 3.0 + float(i)) * 0.2)
			var wisp_p = Vector2.from_angle(wisp_a) * wisp_r2
			draw_circle(wisp_p, 3.0, Color(ghost_col.r, ghost_col.g, ghost_col.b, _ghost_flash * 0.3))

	# === STONE PLATFORM ===
	var plat_y = 22.0
	draw_circle(Vector2(0, plat_y + 4), 28.0, Color(0, 0, 0, 0.15))
	draw_set_transform(Vector2(0, plat_y), 0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 28.0, Color(0.18, 0.16, 0.14))
	draw_circle(Vector2.ZERO, 25.0, Color(0.28, 0.25, 0.22))
	draw_circle(Vector2.ZERO, 20.0, Color(0.35, 0.32, 0.28))
	for si in range(8):
		var sa = TAU * float(si) / 8.0
		draw_circle(Vector2.from_angle(sa) * 16.0, 3.0, Color(0.25, 0.22, 0.20, 0.4))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	draw_set_transform(Vector2(0, plat_y - 2), 0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 22.0, Color(0.40, 0.36, 0.32, 0.3))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	# === SHADOW TENDRILS from platform edges ===
	for ti in range(5):
		var ta = TAU * float(ti) / 5.0 + _time * 0.3
		var t_base = Vector2(cos(ta) * 24.0, plat_y + sin(ta) * 8.0)
		var t_end = t_base + Vector2(sin(_time * 0.8 + float(ti)) * 6.0, 8.0 + sin(_time * 1.2 + float(ti)) * 4.0)
		draw_line(t_base, t_end, Color(0.04, 0.02, 0.06, 0.2), 2.0)
		draw_line(t_end, t_end + Vector2(sin(_time + float(ti)) * 3.0, 5.0), Color(0.04, 0.02, 0.06, 0.1), 1.5)

	# === TIER PIPS on platform edge ===
	for i in range(upgrade_tier):
		var pip_angle = -PI / 2.0 + float(i) * (TAU / 4.0) - (float(upgrade_tier - 1) * TAU / 8.0)
		var pip_pos = Vector2(cos(pip_angle) * 22.0, plat_y + sin(pip_angle) * 8.0)
		var pip_col: Color
		match i:
			0: pip_col = Color(0.85, 0.75, 0.2)
			1: pip_col = Color(0.4, 0.55, 0.85)
			2: pip_col = Color(0.3, 0.65, 0.3)
			3: pip_col = Color(0.25, 0.15, 0.3)
		draw_circle(pip_pos, 4.0, pip_col)
		draw_circle(pip_pos, 5.5, Color(pip_col.r, pip_col.g, pip_col.b, 0.15))

	# === T1+: GOLD COIN PILE at base of platform ===
	if upgrade_tier >= 1:
		var coin_base = Vector2(16, plat_y - 2) + body_offset * 0.15
		# Stack of gold coins
		for ci in range(5):
			var cx = coin_base.x - 6.0 + float(ci) * 3.0
			var cy = coin_base.y - float(ci) * 1.5
			draw_circle(Vector2(cx, cy), 3.5, Color(0.75, 0.6, 0.1))
			draw_circle(Vector2(cx, cy), 2.8, Color(0.9, 0.78, 0.2))
			# Coin highlight glint
			draw_circle(Vector2(cx - 0.5, cy - 0.8), 1.0, Color(1.0, 0.95, 0.5, 0.6))
		# Extra coins scattered
		draw_circle(Vector2(coin_base.x + 5, coin_base.y + 1), 2.5, Color(0.8, 0.65, 0.15))
		draw_circle(Vector2(coin_base.x - 8, coin_base.y + 2), 2.2, Color(0.85, 0.7, 0.18))
		# Animated glint on top coin
		var glint_alpha = (sin(_time * 4.0) + 1.0) * 0.3
		draw_circle(Vector2(coin_base.x, coin_base.y - 7), 2.0, Color(1.0, 1.0, 0.8, glint_alpha))

	# === T4: GHOST OF YET TO COME — dark hooded figure looming behind ===
	if upgrade_tier >= 4:
		var hood_bob = sin(_time * 1.2) * 3.0
		var dark_center = -dir * 38.0 + Vector2(0, -14.0 + hood_bob)
		# Ominous dark mist at base
		for i in range(6):
			var mist_a = _time * 0.4 + float(i) * TAU / 6.0
			var mist_r = 50.0 + sin(_time * 1.5 + float(i) * 2.0) * 10.0
			var mist_p = Vector2.from_angle(mist_a) * mist_r
			var mist_s = 12.0 + sin(_time * 2.0 + float(i)) * 4.0
			draw_circle(mist_p, mist_s, Color(0.02, 0.01, 0.04, 0.1 + sin(_time * 1.8 + float(i)) * 0.03))
		# Tall dark robe body — looming behind Scrooge
		var dark_robe = PackedVector2Array([
			dark_center + Vector2(-18, 30 + hood_bob),
			dark_center + Vector2(18, 30 + hood_bob),
			dark_center + Vector2(14, 5),
			dark_center + Vector2(10, -15),
			dark_center + Vector2(-10, -15),
			dark_center + Vector2(-14, 5),
		])
		draw_colored_polygon(dark_robe, Color(0.03, 0.02, 0.05, 0.5))
		# Inner darker shadow on robe
		var dark_inner = PackedVector2Array([
			dark_center + Vector2(-12, 26 + hood_bob),
			dark_center + Vector2(12, 26 + hood_bob),
			dark_center + Vector2(8, 2),
			dark_center + Vector2(-8, 2),
		])
		draw_colored_polygon(dark_inner, Color(0.01, 0.01, 0.02, 0.3))
		# Tattered hem wisps
		for i in range(5):
			var rag_x = -12.0 + float(i) * 6.0
			var rag_base = dark_center + Vector2(rag_x, 30 + hood_bob)
			var rag_end = rag_base + Vector2(sin(_time * 2.0 + float(i) * 1.3) * 4.0, 8.0 + sin(_time * 1.5 + float(i)) * 3.0)
			draw_line(rag_base, rag_end, Color(0.04, 0.03, 0.06, 0.3), 1.5)
		# Hood
		var hood_center = dark_center + Vector2(0, -18)
		draw_circle(hood_center, 14.0, Color(0.04, 0.02, 0.07, 0.55))
		draw_circle(hood_center + Vector2(0, 2), 11.0, Color(0.05, 0.03, 0.08, 0.5))
		# Void face
		draw_circle(hood_center + Vector2(0, 4), 8.0, Color(0.0, 0.0, 0.0, 0.7))
		# Faint red eyes
		var eye_flicker_t4 = 0.3 + sin(_time * 3.0) * 0.2
		draw_circle(hood_center + Vector2(-3, 3), 1.5, Color(0.8, 0.1, 0.05, eye_flicker_t4))
		draw_circle(hood_center + Vector2(3, 3), 1.5, Color(0.8, 0.1, 0.05, eye_flicker_t4))
		# Eye glow halo
		draw_circle(hood_center + Vector2(-3, 3), 3.5, Color(0.6, 0.05, 0.02, eye_flicker_t4 * 0.2))
		draw_circle(hood_center + Vector2(3, 3), 3.5, Color(0.6, 0.05, 0.02, eye_flicker_t4 * 0.2))
		# Bony skeletal hand pointing outward
		var point_hand = dark_center + Vector2(16, 0)
		draw_line(dark_center + Vector2(10, -4), point_hand, Color(0.5, 0.48, 0.42, 0.35), 2.0)
		draw_line(point_hand, point_hand + Vector2(6, -2), Color(0.55, 0.5, 0.45, 0.3), 1.5)
		draw_line(point_hand, point_hand + Vector2(7, 0), Color(0.55, 0.5, 0.45, 0.3), 1.2)
		draw_line(point_hand, point_hand + Vector2(5, 2), Color(0.55, 0.5, 0.45, 0.25), 1.0)
		# Chains (Marley's chains) floating around
		for i in range(6):
			var chain_a = TAU * float(i) / 6.0 + sin(_time * 2.5 + float(i)) * 0.3
			var chain_r = 62.0 + sin(_time * 3.0 + float(i) * 1.5) * 5.0
			var chain_p = Vector2.from_angle(chain_a) * chain_r
			draw_arc(chain_p, 5.0, 0, TAU, 8, Color(0.4, 0.4, 0.45, 0.35), 2.0)
			var link2 = chain_p + Vector2.from_angle(chain_a + 0.5) * 6.0
			draw_arc(link2, 3.5, 0, TAU, 6, Color(0.45, 0.45, 0.5, 0.3), 1.5)

	# === T3+: GHOST OF CHRISTMAS PRESENT — green jolly spirit (right side) ===
	if upgrade_tier >= 3:
		var green_bob = sin(_time * 1.8 + 2.0) * 5.0
		var green_center = perp * 32.0 + Vector2(0, -8 + green_bob)
		# Warm green aura
		draw_circle(green_center, 20.0, Color(0.25, 0.6, 0.15, 0.08))
		# Large flowing green robe body — chibi ghost shape
		var green_body = PackedVector2Array([
			green_center + Vector2(-12, 14),
			green_center + Vector2(12, 14),
			green_center + Vector2(10, 2),
			green_center + Vector2(8, -8),
			green_center + Vector2(-8, -8),
			green_center + Vector2(-10, 2),
		])
		draw_colored_polygon(green_body, Color(0.2, 0.55, 0.15, 0.22))
		# Inner lighter green
		var green_inner = PackedVector2Array([
			green_center + Vector2(-8, 12),
			green_center + Vector2(8, 12),
			green_center + Vector2(6, 0),
			green_center + Vector2(-6, 0),
		])
		draw_colored_polygon(green_inner, Color(0.3, 0.65, 0.25, 0.15))
		# Fur-trimmed edges
		for i in range(5):
			var fur_x = -10.0 + float(i) * 5.0
			var fur_p = green_center + Vector2(fur_x, 14)
			draw_circle(fur_p, 2.5, Color(0.65, 0.6, 0.5, 0.2))
		# Jovial round head
		var gh_head = green_center + Vector2(0, -12)
		draw_circle(gh_head, 9.0, Color(0.35, 0.7, 0.3, 0.25))
		draw_circle(gh_head, 7.0, Color(0.4, 0.75, 0.35, 0.2))
		# Holly wreath crown
		draw_arc(gh_head, 10.0, 0, TAU, 14, Color(0.2, 0.5, 0.15, 0.22), 2.0)
		# Holly berries
		for i in range(4):
			var berry_a = TAU * float(i) / 4.0 + 0.3
			var berry_p = gh_head + Vector2.from_angle(berry_a) * 10.0
			draw_circle(berry_p, 1.5, Color(0.8, 0.15, 0.1, 0.3))
		# Cheerful face dots
		draw_circle(gh_head + Vector2(-3, -1), 1.2, Color(0.1, 0.3, 0.05, 0.3))
		draw_circle(gh_head + Vector2(3, -1), 1.2, Color(0.1, 0.3, 0.05, 0.3))
		# Jovial grin
		draw_arc(gh_head + Vector2(0, 2), 3.5, 0.2, PI - 0.2, 8, Color(0.15, 0.35, 0.1, 0.25), 1.5)
		# Gold abundance sparkles
		for i in range(6):
			var spark_a = _time * 1.5 + float(i) * TAU / 6.0
			var spark_r = 22.0 + sin(_time * 3.0 + float(i)) * 6.0
			var spark_pos = green_center + Vector2.from_angle(spark_a) * spark_r
			var spark_alpha = 0.3 + sin(_time * 5.0 + float(i) * 2.0) * 0.2
			draw_circle(spark_pos, 2.0 + sin(_time * 4.0 + float(i)) * 1.0, Color(1.0, 0.85, 0.2, spark_alpha))

	# === T2+: GHOST OF CHRISTMAS PAST — blue-white ethereal spirit (left side) ===
	if upgrade_tier >= 2:
		var blue_bob = sin(_time * 1.5) * 4.0
		var blue_center = -perp * 30.0 + Vector2(0, -10 + blue_bob)
		# Ethereal blue-white aura
		draw_circle(blue_center, 18.0, Color(0.35, 0.45, 0.85, 0.07))
		draw_circle(blue_center, 12.0, Color(0.5, 0.6, 0.95, 0.05))
		# Translucent wispy body — chibi ghost shape
		var blue_body = PackedVector2Array([
			blue_center + Vector2(-9, 12),
			blue_center + Vector2(9, 12),
			blue_center + Vector2(7, 0),
			blue_center + Vector2(6, -8),
			blue_center + Vector2(-6, -8),
			blue_center + Vector2(-7, 0),
		])
		draw_colored_polygon(blue_body, Color(0.5, 0.6, 0.9, 0.15))
		# Inner shimmer
		var blue_inner = PackedVector2Array([
			blue_center + Vector2(-6, 10),
			blue_center + Vector2(6, 10),
			blue_center + Vector2(4, -2),
			blue_center + Vector2(-4, -2),
		])
		draw_colored_polygon(blue_inner, Color(0.6, 0.7, 1.0, 0.1))
		# Wispy tail at bottom (ghostly dissipation)
		for i in range(3):
			var wisp_x = -5.0 + float(i) * 5.0
			var wisp_base = blue_center + Vector2(wisp_x, 12)
			var wisp_end = wisp_base + Vector2(sin(_time * 2.5 + float(i)) * 3.0, 6.0 + sin(_time * 1.8 + float(i)) * 2.0)
			draw_line(wisp_base, wisp_end, Color(0.5, 0.6, 0.9, 0.12), 2.0)
		# Small round head
		var bh_head = blue_center + Vector2(0, -11)
		draw_circle(bh_head, 7.0, Color(0.55, 0.65, 0.95, 0.2))
		draw_circle(bh_head, 5.5, Color(0.65, 0.75, 1.0, 0.15))
		# Gentle eyes
		draw_circle(bh_head + Vector2(-2.5, -1), 1.0, Color(0.3, 0.4, 0.8, 0.3))
		draw_circle(bh_head + Vector2(2.5, -1), 1.0, Color(0.3, 0.4, 0.8, 0.3))
		# Candle-like glow on top of head (spirit's flame)
		var flame_bob = sin(_time * 6.0) * 1.5
		draw_circle(bh_head + Vector2(0, -8 + flame_bob), 3.0, Color(0.7, 0.8, 1.0, 0.2))
		draw_circle(bh_head + Vector2(0, -9 + flame_bob), 2.0, Color(0.85, 0.9, 1.0, 0.3))
		# Ethereal light rays from spirit
		for i in range(4):
			var ray_a = TAU * float(i) / 4.0 + _time * 0.5
			var ray_start = blue_center + Vector2.from_angle(ray_a) * 8.0
			var ray_end = blue_center + Vector2.from_angle(ray_a) * 16.0
			draw_line(ray_start, ray_end, Color(0.5, 0.6, 0.95, 0.1), 1.0)

	# === CHARACTER POSITIONS (chibi) ===
	var feet_y = body_offset + Vector2(0, 14.0)
	var torso_center = body_offset + Vector2(0, -2.0)
	var head_center = body_offset + Vector2(0, -22.0)

	# === WORN SLIPPERS ===
	var l_foot = feet_y + Vector2(-7, 0)
	var r_foot = feet_y + Vector2(7, 0)
	# Slipper base — old, worn brown
	draw_circle(l_foot, 5.0, Color(0.35, 0.25, 0.15))
	draw_circle(l_foot, 4.0, Color(0.45, 0.35, 0.22))
	draw_circle(r_foot, 5.0, Color(0.35, 0.25, 0.15))
	draw_circle(r_foot, 4.0, Color(0.45, 0.35, 0.22))
	# Slipper worn patches
	draw_circle(l_foot + Vector2(1, -1), 2.0, Color(0.38, 0.28, 0.18, 0.5))
	draw_circle(r_foot + Vector2(-1, -1), 2.0, Color(0.38, 0.28, 0.18, 0.5))
	# Slipper opening (darker inside)
	draw_circle(l_foot + Vector2(0, -2), 2.5, Color(0.2, 0.15, 0.1, 0.4))
	draw_circle(r_foot + Vector2(0, -2), 2.5, Color(0.2, 0.15, 0.1, 0.4))

	# === THIN CHIBI LEGS (visible below nightgown hem) ===
	var l_knee = feet_y + Vector2(-6, -6)
	var r_knee = feet_y + Vector2(6, -6)
	# Thin elderly legs — barely visible, nightgown covers most
	draw_line(l_foot + Vector2(0, -3), l_knee, Color(0.08, 0.08, 0.08), 4.5)
	draw_line(l_foot + Vector2(0, -3), l_knee, skin_shadow, 3.0)
	draw_line(r_foot + Vector2(0, -3), r_knee, Color(0.08, 0.08, 0.08), 4.5)
	draw_line(r_foot + Vector2(0, -3), r_knee, skin_shadow, 3.0)

	# === LONG WHITE VICTORIAN NIGHTGOWN (ankle-length, flowing) ===
	var gown_sway = sin(_time * 1.5) * 2.0
	var nightgown_pts = PackedVector2Array([
		torso_center + Vector2(-16, 18 + gown_sway),      # Left hem
		torso_center + Vector2(-18, 12 + gown_sway * 0.5), # Left lower body
		torso_center + Vector2(-14, -4),                    # Left waist
		torso_center + Vector2(-11, -10),                   # Left shoulder
		torso_center + Vector2(11, -10),                    # Right shoulder
		torso_center + Vector2(14, -4),                     # Right waist
		torso_center + Vector2(18, 12 - gown_sway * 0.5),  # Right lower body
		torso_center + Vector2(16, 18 - gown_sway),        # Right hem
	])
	# Nightgown shadow / outline
	draw_colored_polygon(nightgown_pts, Color(0.78, 0.76, 0.74))
	# Main nightgown white
	var nightgown_inner = PackedVector2Array([
		torso_center + Vector2(-14, 16 + gown_sway),
		torso_center + Vector2(-16, 10 + gown_sway * 0.5),
		torso_center + Vector2(-12, -3),
		torso_center + Vector2(-9, -8),
		torso_center + Vector2(9, -8),
		torso_center + Vector2(12, -3),
		torso_center + Vector2(16, 10 - gown_sway * 0.5),
		torso_center + Vector2(14, 16 - gown_sway),
	])
	draw_colored_polygon(nightgown_inner, Color(0.9, 0.88, 0.86))
	# Lighter center panel
	var center_panel = PackedVector2Array([
		torso_center + Vector2(-6, 14 + gown_sway * 0.5),
		torso_center + Vector2(-7, -2),
		torso_center + Vector2(7, -2),
		torso_center + Vector2(6, 14 - gown_sway * 0.5),
	])
	draw_colored_polygon(center_panel, Color(0.95, 0.93, 0.91, 0.6))
	# Button line down center
	for bi in range(4):
		var by = torso_center.y - 4 + float(bi) * 5.0
		draw_circle(Vector2(torso_center.x, by), 1.0, Color(0.7, 0.68, 0.65))
	# Worn patches / texture on nightgown
	draw_circle(torso_center + Vector2(-8, 6), 3.0, Color(0.82, 0.8, 0.78, 0.3))
	draw_circle(torso_center + Vector2(10, 2), 2.5, Color(0.84, 0.82, 0.79, 0.25))
	draw_circle(torso_center + Vector2(-5, 12), 2.0, Color(0.80, 0.78, 0.75, 0.2))
	# Nightgown collar (V-neckline)
	draw_line(torso_center + Vector2(-8, -9), torso_center + Vector2(0, -5), Color(0.75, 0.73, 0.70), 1.5)
	draw_line(torso_center + Vector2(8, -9), torso_center + Vector2(0, -5), Color(0.75, 0.73, 0.70), 1.5)
	# Collar fold highlight
	draw_line(torso_center + Vector2(-7, -9), torso_center + Vector2(0, -6), Color(0.95, 0.93, 0.90, 0.4), 1.0)
	draw_line(torso_center + Vector2(7, -9), torso_center + Vector2(0, -6), Color(0.95, 0.93, 0.90, 0.4), 1.0)
	# Gown hem fringe detail
	for hi in range(6):
		var hx = -14.0 + float(hi) * 5.6
		var hy = torso_center.y + 17 + gown_sway * (0.5 - float(hi) / 6.0)
		draw_line(Vector2(torso_center.x + hx, hy), Vector2(torso_center.x + hx, hy + 3.0), Color(0.82, 0.80, 0.78, 0.3), 1.0)

	# === NON-WEAPON ARM (left side — clutching nightgown) ===
	var off_arm_shoulder = torso_center + Vector2(-12, -6)
	var off_arm_elbow = torso_center + Vector2(-16, 2)
	var off_arm_hand = torso_center + Vector2(-10, 6)
	# Nightgown sleeve
	draw_line(off_arm_shoulder, off_arm_elbow, Color(0.82, 0.80, 0.78), 6.0)
	draw_line(off_arm_shoulder, off_arm_elbow, Color(0.88, 0.86, 0.84), 4.5)
	# Forearm / hand
	draw_line(off_arm_elbow, off_arm_hand, Color(0.82, 0.80, 0.78), 5.0)
	draw_line(off_arm_elbow, off_arm_hand, Color(0.88, 0.86, 0.84), 3.5)
	# Bony elderly hand (clutching gown fabric)
	draw_circle(off_arm_hand, 3.5, skin_base)
	draw_circle(off_arm_hand, 2.5, skin_highlight)
	# Thin bony fingers gripping
	draw_line(off_arm_hand, off_arm_hand + Vector2(-2, 3), skin_shadow, 1.5)
	draw_line(off_arm_hand, off_arm_hand + Vector2(0, 4), skin_shadow, 1.5)
	draw_line(off_arm_hand, off_arm_hand + Vector2(2, 3), skin_shadow, 1.2)
	# Knuckle detail
	draw_circle(off_arm_hand + Vector2(-1, 1), 0.8, skin_shadow)
	draw_circle(off_arm_hand + Vector2(1, 1), 0.8, skin_shadow)

	# === WEAPON ARM (right side — holding brass candlestick, tracks aim) ===
	var weapon_shoulder = torso_center + Vector2(12, -6)
	var attack_recoil = _attack_anim * 4.0
	var weapon_extend = dir * (14.0 + attack_recoil) + body_offset
	var weapon_elbow = weapon_shoulder + (weapon_extend - weapon_shoulder) * 0.5 + Vector2(0, 3)
	var weapon_hand = weapon_shoulder + (weapon_extend - weapon_shoulder) * 0.85
	# Nightgown sleeve on weapon arm
	draw_line(weapon_shoulder, weapon_elbow, Color(0.82, 0.80, 0.78), 6.0)
	draw_line(weapon_shoulder, weapon_elbow, Color(0.88, 0.86, 0.84), 4.5)
	# Forearm
	draw_line(weapon_elbow, weapon_hand, Color(0.82, 0.80, 0.78), 5.0)
	draw_line(weapon_elbow, weapon_hand, Color(0.88, 0.86, 0.84), 3.5)
	# Bony hand
	draw_circle(weapon_hand, 3.5, skin_base)
	draw_circle(weapon_hand, 2.5, skin_highlight)

	# === BRASS CANDLESTICK (weapon) ===
	var candle_base = weapon_hand + dir * 4.0
	var candle_top = candle_base + Vector2(0, -18)
	# Candlestick base plate (brass)
	draw_circle(candle_base, 5.0, Color(0.65, 0.5, 0.15))
	draw_circle(candle_base, 4.0, Color(0.8, 0.65, 0.2))
	draw_circle(candle_base, 3.0, Color(0.9, 0.75, 0.3))
	# Candlestick stem
	draw_line(candle_base + Vector2(0, -2), candle_base + Vector2(0, -10), Color(0.65, 0.5, 0.15), 3.5)
	draw_line(candle_base + Vector2(0, -2), candle_base + Vector2(0, -10), Color(0.85, 0.7, 0.25), 2.5)
	# Stem highlight
	draw_line(candle_base + Vector2(-0.5, -3), candle_base + Vector2(-0.5, -9), Color(0.95, 0.85, 0.4, 0.4), 1.0)
	# Candlestick knob (middle decorative bump)
	draw_circle(candle_base + Vector2(0, -6), 2.5, Color(0.75, 0.6, 0.2))
	draw_circle(candle_base + Vector2(0, -6), 1.8, Color(0.9, 0.75, 0.3))
	# Cup / drip tray
	draw_circle(candle_base + Vector2(0, -10), 4.0, Color(0.7, 0.55, 0.18))
	draw_circle(candle_base + Vector2(0, -10), 3.0, Color(0.85, 0.7, 0.25))
	# Candle (white/cream wax)
	draw_line(candle_base + Vector2(0, -11), candle_top, Color(0.88, 0.85, 0.78), 4.0)
	draw_line(candle_base + Vector2(0, -11), candle_top, Color(0.95, 0.93, 0.88), 2.8)
	# Wax drip details
	draw_circle(candle_base + Vector2(-1.5, -11), 1.2, Color(0.92, 0.88, 0.82))
	draw_circle(candle_base + Vector2(1, -13), 0.8, Color(0.92, 0.88, 0.82))

	# === CANDLE FLAME (animated flicker) ===
	var flame_flicker = sin(_time * 8.0) * 1.5 + cos(_time * 11.0) * 0.8
	var flame_flicker2 = sin(_time * 6.5) * 1.0
	var flame_pos = candle_top + Vector2(flame_flicker * 0.3, -2.0)
	# Outer glow
	draw_circle(flame_pos, 8.0, Color(1.0, 0.7, 0.2, 0.12))
	draw_circle(flame_pos, 5.0, Color(1.0, 0.75, 0.25, 0.2))
	# Flame body (teardrop shape via overlapping circles)
	draw_circle(flame_pos + Vector2(0, 1), 3.5, Color(1.0, 0.6, 0.1, 0.7))
	draw_circle(flame_pos, 3.0, Color(1.0, 0.75, 0.15, 0.8))
	draw_circle(flame_pos + Vector2(0, -1.5), 2.2, Color(1.0, 0.85, 0.3, 0.85))
	# Inner bright core
	draw_circle(flame_pos + Vector2(flame_flicker2 * 0.2, 0), 1.5, Color(1.0, 0.95, 0.7, 0.9))
	draw_circle(flame_pos + Vector2(0, -2.5), 1.0, Color(1.0, 1.0, 0.85, 0.7))
	# Flame tip
	draw_line(flame_pos, flame_pos + Vector2(flame_flicker * 0.4, -4.0 + flame_flicker2 * 0.5), Color(1.0, 0.8, 0.2, 0.5), 1.5)

	# === ATTACK FLASH — coin/light burst toward target ===
	if _attack_anim > 0.3:
		var burst_pos = weapon_hand + dir * 18.0
		var burst_alpha = (_attack_anim - 0.3) * 1.4
		# Gold coin burst
		draw_circle(burst_pos, 6.0 + _attack_anim * 4.0, Color(1.0, 0.85, 0.2, burst_alpha * 0.4))
		draw_circle(burst_pos, 3.0 + _attack_anim * 2.0, Color(1.0, 0.95, 0.5, burst_alpha * 0.6))
		# Coin sparkle rays
		for i in range(5):
			var ray_a = TAU * float(i) / 5.0 + _time * 6.0
			var ray_end = burst_pos + Vector2.from_angle(ray_a) * (8.0 + _attack_anim * 6.0)
			draw_line(burst_pos, ray_end, Color(1.0, 0.9, 0.3, burst_alpha * 0.3), 1.5)
		# Candle flare on attack
		draw_circle(flame_pos, 10.0, Color(1.0, 0.8, 0.2, burst_alpha * 0.3))

	# === HEAD (big chibi head ~40% of total) ===
	# Thin neck (elderly, scrawny)
	draw_line(torso_center + Vector2(0, -9), head_center + Vector2(0, 8), skin_shadow, 5.0)
	draw_line(torso_center + Vector2(0, -9), head_center + Vector2(0, 8), skin_base, 3.5)
	# Adam's apple detail
	draw_circle(torso_center + Vector2(0, -12), 1.2, skin_shadow)

	# Head shape — slightly elongated, angular
	draw_circle(head_center, 15.0, Color(0.06, 0.05, 0.04))  # Outline
	draw_circle(head_center, 14.0, skin_shadow)
	draw_circle(head_center, 13.0, skin_base)
	# Highlight on forehead
	draw_circle(head_center + Vector2(-2, -4), 6.0, Color(skin_highlight.r, skin_highlight.g, skin_highlight.b, 0.4))
	# Prominent chin (angular, pointed — lower part of head)
	var chin_tip = head_center + Vector2(0, 13)
	draw_circle(chin_tip, 4.0, skin_base)
	draw_circle(chin_tip + Vector2(0, 1), 3.0, skin_shadow)
	# Chin highlight
	draw_circle(chin_tip + Vector2(-0.5, -0.5), 1.5, skin_highlight)

	# === BALDING HEAD WITH WISPS OF WHITE HAIR ===
	# Bald dome on top — slightly shinier skin tone
	draw_circle(head_center + Vector2(0, -6), 8.0, Color(0.88, 0.82, 0.76, 0.5))
	# Shine on bald head
	draw_circle(head_center + Vector2(-2, -8), 4.0, Color(1.0, 0.96, 0.90, 0.3))
	draw_circle(head_center + Vector2(-3, -9), 2.0, Color(1.0, 0.98, 0.95, 0.4))
	# Thin white hair wisps on sides
	# Left side wisps
	for i in range(4):
		var wisp_start = head_center + Vector2(-12, -4 + float(i) * 3.0)
		var wisp_end = wisp_start + Vector2(-4.0 + sin(_time * 1.5 + float(i)) * 1.5, 3.0 + float(i) * 0.5)
		draw_line(wisp_start, wisp_end, Color(0.92, 0.90, 0.88, 0.6), 1.2)
	# Right side wisps
	for i in range(4):
		var wisp_start = head_center + Vector2(12, -4 + float(i) * 3.0)
		var wisp_end = wisp_start + Vector2(4.0 + sin(_time * 1.5 + float(i) + 1.0) * 1.5, 3.0 + float(i) * 0.5)
		draw_line(wisp_start, wisp_end, Color(0.92, 0.90, 0.88, 0.6), 1.2)
	# Tuft at back
	for i in range(3):
		var tuft_start = head_center + Vector2(-3 + float(i) * 3.0, -13)
		var tuft_end = tuft_start + Vector2(sin(_time * 1.0 + float(i)) * 2.0, -4.0)
		draw_line(tuft_start, tuft_end, Color(0.92, 0.90, 0.88, 0.4), 1.0)

	# === DROOPING NIGHTCAP WITH POMPOM ===
	var cap_base_left = head_center + Vector2(-10, -8)
	var cap_base_right = head_center + Vector2(10, -8)
	var cap_tip_sway = sin(_time * 1.8) * 5.0
	var cap_tip = head_center + Vector2(14 + cap_tip_sway, -2)
	# Nightcap body — white with slight grey
	var cap_pts = PackedVector2Array([
		cap_base_left,
		head_center + Vector2(0, -14),
		cap_base_right,
		head_center + Vector2(12, -6),
		cap_tip,
	])
	draw_colored_polygon(cap_pts, Color(0.85, 0.83, 0.80))
	# Lighter inner cap
	var cap_inner = PackedVector2Array([
		cap_base_left + Vector2(2, 1),
		head_center + Vector2(0, -12),
		cap_base_right + Vector2(-2, 1),
		head_center + Vector2(10, -5),
		cap_tip + Vector2(-2, 1),
	])
	draw_colored_polygon(cap_inner, Color(0.92, 0.90, 0.88))
	# Cap fold/band at base
	draw_line(cap_base_left, cap_base_right, Color(0.78, 0.76, 0.73), 3.0)
	draw_line(cap_base_left + Vector2(1, 0.5), cap_base_right + Vector2(-1, 0.5), Color(0.88, 0.86, 0.84), 1.5)
	# Cap crease/fold lines
	draw_line(head_center + Vector2(4, -10), cap_tip + Vector2(-4, 0), Color(0.8, 0.78, 0.75, 0.3), 1.0)
	draw_line(head_center + Vector2(6, -8), cap_tip + Vector2(-2, -1), Color(0.82, 0.80, 0.77, 0.2), 0.8)
	# Pompom at tip
	draw_circle(cap_tip, 5.0, Color(0.8, 0.78, 0.75))
	draw_circle(cap_tip, 4.0, Color(0.92, 0.90, 0.88))
	draw_circle(cap_tip + Vector2(-1, -1), 2.0, Color(0.98, 0.96, 0.94, 0.5))
	# Pompom texture bumps
	for i in range(5):
		var bump_a = TAU * float(i) / 5.0 + 0.5
		var bump_p = cap_tip + Vector2.from_angle(bump_a) * 3.5
		draw_circle(bump_p, 1.2, Color(0.85, 0.83, 0.80, 0.4))

	# === ROUND SPECTACLES ===
	var glasses_y = head_center.y + 1
	var glasses_bridge = head_center.x
	var l_lens_center = Vector2(glasses_bridge - 5, glasses_y)
	var r_lens_center = Vector2(glasses_bridge + 5, glasses_y)
	# Wire frames (dark thin metal)
	draw_arc(l_lens_center, 5.0, 0, TAU, 16, Color(0.3, 0.28, 0.25), 1.5)
	draw_arc(r_lens_center, 5.0, 0, TAU, 16, Color(0.3, 0.28, 0.25), 1.5)
	# Bridge connecting lenses
	draw_line(l_lens_center + Vector2(4, -1), r_lens_center + Vector2(-4, -1), Color(0.3, 0.28, 0.25), 1.2)
	# Temple arms going to ears
	draw_line(l_lens_center + Vector2(-5, 0), head_center + Vector2(-13, 0), Color(0.3, 0.28, 0.25, 0.6), 1.0)
	draw_line(r_lens_center + Vector2(5, 0), head_center + Vector2(13, 0), Color(0.3, 0.28, 0.25, 0.6), 1.0)
	# Glass lens fill (very slight blue tint)
	draw_circle(l_lens_center, 4.5, Color(0.7, 0.75, 0.85, 0.12))
	draw_circle(r_lens_center, 4.5, Color(0.7, 0.75, 0.85, 0.12))
	# Lens glare / shine
	draw_circle(l_lens_center + Vector2(-1.5, -1.5), 1.5, Color(1.0, 1.0, 1.0, 0.25))
	draw_circle(r_lens_center + Vector2(-1.5, -1.5), 1.5, Color(1.0, 1.0, 1.0, 0.25))

	# === SMALL SQUINTING EYES BEHIND GLASSES ===
	var l_eye_pos = l_lens_center + Vector2(0, 0.5)
	var r_eye_pos = r_lens_center + Vector2(0, 0.5)
	# Eye whites (small, squinty)
	draw_circle(l_eye_pos, 2.5, Color(0.95, 0.93, 0.90))
	draw_circle(r_eye_pos, 2.5, Color(0.95, 0.93, 0.90))
	if is_kind:
		# Kind eyes — warmer, more open, slight upward curve
		# Irises (warm brown)
		draw_circle(l_eye_pos, 1.8, Color(0.45, 0.35, 0.2))
		draw_circle(r_eye_pos, 1.8, Color(0.45, 0.35, 0.2))
		# Pupils
		draw_circle(l_eye_pos, 1.0, Color(0.1, 0.08, 0.05))
		draw_circle(r_eye_pos, 1.0, Color(0.1, 0.08, 0.05))
		# Warm eye shine
		draw_circle(l_eye_pos + Vector2(-0.5, -0.5), 0.6, Color(1.0, 0.95, 0.8, 0.7))
		draw_circle(r_eye_pos + Vector2(-0.5, -0.5), 0.6, Color(1.0, 0.95, 0.8, 0.7))
		# Kind crinkle lines (smile lines at corners)
		draw_line(l_eye_pos + Vector2(-3, -1), l_eye_pos + Vector2(-4, -2.5), skin_shadow, 0.8)
		draw_line(r_eye_pos + Vector2(3, -1), r_eye_pos + Vector2(4, -2.5), skin_shadow, 0.8)
	else:
		# Stern/suspicious squinting eyes
		# Irises (cold grey-blue)
		draw_circle(l_eye_pos, 1.5, Color(0.4, 0.42, 0.5))
		draw_circle(r_eye_pos, 1.5, Color(0.4, 0.42, 0.5))
		# Pupils (tiny, suspicious)
		draw_circle(l_eye_pos, 0.8, Color(0.08, 0.08, 0.1))
		draw_circle(r_eye_pos, 0.8, Color(0.08, 0.08, 0.1))
		# Cold eye shine
		draw_circle(l_eye_pos + Vector2(-0.3, -0.3), 0.5, Color(0.9, 0.9, 1.0, 0.5))
		draw_circle(r_eye_pos + Vector2(-0.3, -0.3), 0.5, Color(0.9, 0.9, 1.0, 0.5))
		# Squint lines (heavy lids pressing down)
		draw_line(l_eye_pos + Vector2(-3, -1.5), l_eye_pos + Vector2(3, -1.5), skin_shadow, 1.5)
		draw_line(r_eye_pos + Vector2(-3, -1.5), r_eye_pos + Vector2(3, -1.5), skin_shadow, 1.5)
		# Furrowed brow wrinkle
		draw_line(l_eye_pos + Vector2(-2, -4), l_eye_pos + Vector2(2, -3.5), skin_shadow, 1.0)
		draw_line(r_eye_pos + Vector2(-2, -3.5), r_eye_pos + Vector2(2, -4), skin_shadow, 1.0)

	# === NOSE (prominent, pointed) ===
	var nose_pos = head_center + Vector2(0, 4)
	draw_circle(nose_pos, 2.5, skin_base)
	draw_circle(nose_pos + Vector2(0, 1), 2.0, skin_shadow)
	# Nose bridge
	draw_line(head_center + Vector2(0, 0), nose_pos, skin_shadow, 1.5)
	# Nose highlight
	draw_circle(nose_pos + Vector2(-0.5, -0.5), 1.0, skin_highlight)

	# === MOUTH / EXPRESSION ===
	var mouth_pos = head_center + Vector2(0, 7.5)
	if is_kind:
		# Warm, gentle smile (transformed Scrooge)
		draw_arc(mouth_pos, 4.0, 0.3, PI - 0.3, 10, Color(0.6, 0.35, 0.3), 1.5)
		# Slight open warmth to the smile
		draw_arc(mouth_pos + Vector2(0, 0.5), 3.0, 0.4, PI - 0.4, 8, Color(0.5, 0.25, 0.2, 0.5), 1.0)
		# Rosy cheeks (warm kind glow)
		draw_circle(head_center + Vector2(-8, 3), 3.0, Color(0.9, 0.55, 0.45, 0.2))
		draw_circle(head_center + Vector2(8, 3), 3.0, Color(0.9, 0.55, 0.45, 0.2))
	else:
		# Stern, mean, suspicious frown
		draw_arc(mouth_pos, 3.5, PI + 0.4, TAU - 0.4, 10, Color(0.5, 0.3, 0.25), 1.5)
		# Thin pressed lips
		draw_line(mouth_pos + Vector2(-4, 0), mouth_pos + Vector2(4, 0), Color(0.6, 0.4, 0.35), 1.2)
		# Grimace lines at corners of mouth
		draw_line(mouth_pos + Vector2(-4, 0), mouth_pos + Vector2(-5, 2), skin_shadow, 0.8)
		draw_line(mouth_pos + Vector2(4, 0), mouth_pos + Vector2(5, 2), skin_shadow, 0.8)

	# === WRINKLES AND AGE DETAILS ===
	# Forehead wrinkles
	draw_line(head_center + Vector2(-6, -8), head_center + Vector2(6, -8), Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.25), 0.8)
	draw_line(head_center + Vector2(-5, -6), head_center + Vector2(5, -6), Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.2), 0.7)
	# Crow's feet at eye corners
	draw_line(head_center + Vector2(-12, -1), head_center + Vector2(-14, -3), Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.2), 0.7)
	draw_line(head_center + Vector2(-12, 0), head_center + Vector2(-14, 0), Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.15), 0.6)
	draw_line(head_center + Vector2(12, -1), head_center + Vector2(14, -3), Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.2), 0.7)
	draw_line(head_center + Vector2(12, 0), head_center + Vector2(14, 0), Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.15), 0.6)
	# Nasolabial folds (nose to mouth creases)
	draw_line(nose_pos + Vector2(-2, 2), mouth_pos + Vector2(-5, -1), Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.15), 0.7)
	draw_line(nose_pos + Vector2(2, 2), mouth_pos + Vector2(5, -1), Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.15), 0.7)
	# Under-eye bags
	draw_arc(l_eye_pos + Vector2(0, 3), 2.5, 0.3, PI - 0.3, 6, Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.15), 0.7)
	draw_arc(r_eye_pos + Vector2(0, 3), 2.5, 0.3, PI - 0.3, 6, Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.15), 0.7)

	# === EARS (large, elderly) ===
	draw_circle(head_center + Vector2(-14, 1), 3.5, skin_base)
	draw_circle(head_center + Vector2(-14, 1), 2.5, skin_shadow)
	draw_circle(head_center + Vector2(-14, 1), 1.5, Color(0.75, 0.65, 0.58, 0.4))
	draw_circle(head_center + Vector2(14, 1), 3.5, skin_base)
	draw_circle(head_center + Vector2(14, 1), 2.5, skin_shadow)
	draw_circle(head_center + Vector2(14, 1), 1.5, Color(0.75, 0.65, 0.58, 0.4))

	# === T4: EERIE DARK AURA around Scrooge himself ===
	if upgrade_tier >= 4:
		var aura_pulse = sin(_time * 2.0) * 0.03
		draw_circle(body_offset, 40.0, Color(0.1, 0.05, 0.15, 0.06 + aura_pulse))
		draw_arc(body_offset, 42.0, 0, TAU, 32, Color(0.15, 0.08, 0.2, 0.08 + aura_pulse), 1.5)
		# Dark energy wisps around body
		for i in range(4):
			var w_a = _time * 0.6 + float(i) * TAU / 4.0
			var w_r = 35.0 + sin(_time * 1.5 + float(i) * 2.0) * 5.0
			var w_pos = body_offset + Vector2.from_angle(w_a) * w_r
			draw_circle(w_pos, 3.0, Color(0.1, 0.05, 0.15, 0.1))
			var w_tail = body_offset + Vector2.from_angle(w_a - 0.4) * (w_r - 8.0)
			draw_line(w_pos, w_tail, Color(0.1, 0.05, 0.15, 0.06), 1.5)

	# === CANDLELIGHT WARM GLOW on face (proximity lighting from held candle) ===
	var candle_light_pos = weapon_hand + dir * 4.0 + Vector2(0, -14)
	var face_dist = candle_light_pos.distance_to(head_center)
	var light_strength = clamp(1.0 - face_dist / 60.0, 0.0, 0.4)
	if light_strength > 0.05:
		draw_circle(head_center, 16.0, Color(1.0, 0.85, 0.5, light_strength * 0.15))
		draw_circle(torso_center, 18.0, Color(1.0, 0.8, 0.4, light_strength * 0.08))

	# === AWAITING ABILITY CHOICE INDICATOR ===
	if awaiting_ability_choice:
		var pulse = (sin(_time * 4.0) + 1.0) * 0.5
		draw_circle(Vector2.ZERO, 60.0 + pulse * 6.0, Color(0.85, 0.75, 0.3, 0.1 + pulse * 0.1))
		draw_arc(Vector2.ZERO, 60.0 + pulse * 6.0, 0, TAU, 32, Color(0.85, 0.75, 0.3, 0.3 + pulse * 0.3), 2.5)
		var font3 = ThemeDB.fallback_font
		draw_string(font3, Vector2(-16, -68), "!", HORIZONTAL_ALIGNMENT_CENTER, 32, 30, Color(0.85, 0.75, 0.3, 0.7 + pulse * 0.3))

	# === DAMAGE DEALT COUNTER ===
	if damage_dealt > 0:
		var font = ThemeDB.fallback_font
		var dmg_text = str(int(damage_dealt)) + " DMG"
		if stat_upgrade_level > 0:
			dmg_text += " • Lv." + str(stat_upgrade_level)
		draw_string(font, Vector2(-36, 56), dmg_text, HORIZONTAL_ALIGNMENT_LEFT, 160, 12, Color(1.0, 0.84, 0.0, 0.5))

	# === UPGRADE NAME FLASH ===
	if _upgrade_flash > 0.0 and _upgrade_name != "":
		var font2 = ThemeDB.fallback_font
		draw_string(font2, Vector2(-80, -60), _upgrade_name, HORIZONTAL_ALIGNMENT_CENTER, 160, 16, Color(0.9, 0.85, 0.4, min(_upgrade_flash, 1.0)))
