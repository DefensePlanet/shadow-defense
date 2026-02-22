extends Node2D
## Peter Pan — fast attacker tower from JM Barrie's Peter and Wendy (1911).
## Throws daggers rapidly. Upgrades by dealing damage.
## Tier 1 (5000 DMG): "Shadow" — fires a shadow dagger at a 2nd target each shot
## Tier 2 (10000 DMG): "Fairy Dust" — periodic sparkle AoE (damage + slow)
## Tier 3 (15000 DMG): "Tick-Tock Croc" — periodically chomps strongest enemy for 3x damage
## Tier 4 (20000 DMG): "Never Land" — daggers pierce, all stats boosted, gold bonus doubled

var damage: float = 38.0
var fire_rate: float = 2.5
var attack_range: float = 170.0
var fire_cooldown: float = 0.0
var aim_angle: float = 0.0
var target: Node2D = null
var gold_bonus: int = 4

# Damage tracking and upgrades
var damage_dealt: float = 0.0
var upgrade_tier: int = 0
var _upgrade_flash: float = 0.0
var _upgrade_name: String = ""

# Animation variables
var _time: float = 0.0
var _attack_anim: float = 0.0

# Tier 1: Shadow — second dagger
var shadow_enabled: bool = false

# Tier 2: Fairy Dust — AoE burst
var fairy_timer: float = 0.0
var fairy_cooldown: float = 12.0
var _fairy_flash: float = 0.0

# Tier 3: Tick-Tock Croc — chomp strongest
var croc_timer: float = 0.0
var croc_cooldown: float = 15.0
var _croc_flash: float = 0.0

# Tier 4: Never Land
var pierce_count: int = 0

const STAT_UPGRADE_INTERVAL: float = 500.0
const ABILITY_THRESHOLD: float = 1500.0
var stat_upgrade_level: int = 0
var ability_chosen: bool = false
var awaiting_ability_choice: bool = false
const TIER_NAMES = [
	"Shadow",
	"Fairy Dust",
	"Tick-Tock Croc",
	"Never Land"
]
const ABILITY_DESCRIPTIONS = [
	"Shadow dagger at a 2nd target each shot",
	"Periodic sparkle AoE (damage + slow)",
	"Chomps strongest enemy for 3x damage",
	"Daggers pierce, all stats boosted"
]
const TIER_COSTS = [55, 110, 190, 340]
var is_selected: bool = false
var base_cost: int = 0

var dagger_scene = preload("res://scenes/peter_dagger.tscn")

func _ready() -> void:
	add_to_group("towers")

func _process(delta: float) -> void:
	_time += delta
	_attack_anim = max(_attack_anim - delta * 3.0, 0.0)
	fire_cooldown -= delta
	_upgrade_flash = max(_upgrade_flash - delta * 0.5, 0.0)
	_fairy_flash = max(_fairy_flash - delta * 2.0, 0.0)
	_croc_flash = max(_croc_flash - delta * 2.0, 0.0)
	target = _find_nearest_enemy()

	if target:
		var desired = global_position.angle_to_point(target.global_position) + PI
		aim_angle = lerp_angle(aim_angle, desired, 12.0 * delta)
		if fire_cooldown <= 0.0:
			_shoot()
			fire_cooldown = 1.0 / fire_rate

	# Tier 2: Fairy Dust AoE
	if upgrade_tier >= 2:
		fairy_timer -= delta
		if fairy_timer <= 0.0 and _has_enemies_in_range():
			_fairy_dust()
			fairy_timer = fairy_cooldown

	# Tier 3: Tick-Tock Croc
	if upgrade_tier >= 3:
		croc_timer -= delta
		if croc_timer <= 0.0 and _has_enemies_in_range():
			_croc_chomp()
			croc_timer = croc_cooldown

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

func _find_second_target(exclude: Node2D) -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist: float = attack_range
	for enemy in enemies:
		if enemy == exclude:
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest = enemy
			nearest_dist = dist
	return nearest

func _find_strongest_enemy() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var strongest: Node2D = null
	var most_hp: float = 0.0
	for enemy in enemies:
		if global_position.distance_to(enemy.global_position) < attack_range:
			if enemy.health > most_hp:
				strongest = enemy
				most_hp = enemy.health
	return strongest

func _shoot() -> void:
	if not target:
		return
	_attack_anim = 1.0
	_fire_dagger(target, false)
	# Shadow dagger at second target
	if shadow_enabled:
		var second = _find_second_target(target)
		if second:
			_fire_dagger(second, true)

func _fire_dagger(t: Node2D, is_shadow: bool) -> void:
	var dagger = dagger_scene.instantiate()
	dagger.global_position = global_position + Vector2.from_angle(aim_angle) * 14.0
	dagger.damage = damage * (0.6 if is_shadow else 1.0)
	dagger.target = t
	dagger.gold_bonus = gold_bonus
	dagger.source_tower = self
	dagger.is_shadow = is_shadow
	dagger.pierce_count = pierce_count
	get_tree().get_first_node_in_group("main").add_child(dagger)

func _fairy_dust() -> void:
	_fairy_flash = 1.0
	var fairy_dmg = damage * 0.5
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(enemy.global_position) < attack_range * 0.7:
			if enemy.has_method("take_damage"):
				var will_kill = enemy.health - fairy_dmg <= 0.0
				enemy.take_damage(fairy_dmg)
				register_damage(fairy_dmg)
				if is_instance_valid(enemy) and enemy.has_method("apply_slow"):
					enemy.apply_slow(0.65, 1.5)
				if will_kill:
					if gold_bonus > 0:
						var main = get_tree().get_first_node_in_group("main")
						if main:
							main.add_gold(gold_bonus)

func _croc_chomp() -> void:
	_croc_flash = 1.0
	var strongest = _find_strongest_enemy()
	if strongest and strongest.has_method("take_damage"):
		var chomp_dmg = damage * 3.0
		var will_kill = strongest.health - chomp_dmg <= 0.0
		strongest.take_damage(chomp_dmg)
		register_damage(chomp_dmg)
		if will_kill:
			if gold_bonus > 0:
				var main = get_tree().get_first_node_in_group("main")
				if main:
					main.add_gold(gold_bonus)

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
	fire_rate *= 1.10
	attack_range += 6.0

func choose_ability(index: int) -> void:
	ability_chosen = true
	awaiting_ability_choice = false
	upgrade_tier = index + 1
	_apply_upgrade(upgrade_tier)
	_upgrade_flash = 3.0
	_upgrade_name = TIER_NAMES[index]

func _apply_upgrade(tier: int) -> void:
	match tier:
		1: # Shadow — double daggers
			shadow_enabled = true
			damage = 50.0
			fire_rate = 3.0
			attack_range = 185.0
		2: # Fairy Dust — AoE slow burst
			damage = 60.0
			fire_rate = 3.5
			attack_range = 200.0
			fairy_cooldown = 10.0
			gold_bonus = 6
		3: # Tick-Tock Croc — chomp strongest
			damage = 75.0
			fire_rate = 4.0
			attack_range = 220.0
			croc_cooldown = 10.0
			fairy_cooldown = 8.0
			gold_bonus = 8
		4: # Never Land — everything enhanced
			damage = 95.0
			fire_rate = 5.0
			pierce_count = 2
			attack_range = 250.0
			gold_bonus = 12
			fairy_cooldown = 6.0
			croc_cooldown = 7.0

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
	return "Peter Pan"

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
	# Selection ring
	if is_selected:
		var pulse = (sin(_time * 3.0) + 1.0) * 0.5
		var ring_alpha = 0.5 + pulse * 0.3
		draw_arc(Vector2.ZERO, 40.0, 0, TAU, 48, Color(1.0, 0.84, 0.0, ring_alpha), 2.5)
		draw_arc(Vector2.ZERO, 43.0, 0, TAU, 48, Color(1.0, 0.84, 0.0, ring_alpha * 0.4), 1.5)

	# Attack range arc
	draw_arc(Vector2.ZERO, attack_range, 0, TAU, 64, Color(1, 1, 1, 0.06), 1.0)

	var dir = Vector2.from_angle(aim_angle)
	var perp = dir.rotated(PI / 2.0)

	# Chibi idle animation
	var bounce = abs(sin(_time * 3.0)) * 4.0
	var breathe = sin(_time * 2.0) * 2.0
	var sway = sin(_time * 1.5) * 1.5
	var bob = Vector2(sway, -bounce - breathe)

	# Tier 4: Flying pose
	var fly_offset = Vector2.ZERO
	if upgrade_tier >= 4:
		fly_offset = Vector2(0, -10.0 + sin(_time * 1.5) * 3.0)

	var body_offset = bob + fly_offset

	# Skin colors
	var skin_base = Color(0.91, 0.74, 0.58)
	var skin_shadow = Color(0.78, 0.60, 0.45)
	var skin_highlight = Color(0.96, 0.82, 0.68)

	# Upgrade glow
	if upgrade_tier > 0:
		var glow_alpha = 0.1 + 0.03 * upgrade_tier
		var glow_col: Color
		match upgrade_tier:
			1: glow_col = Color(0.3, 0.3, 0.4, glow_alpha)
			2: glow_col = Color(0.6, 0.8, 0.3, glow_alpha)
			3: glow_col = Color(0.3, 0.7, 0.4, glow_alpha)
			4: glow_col = Color(0.4, 0.9, 0.5, glow_alpha + 0.08)
		draw_circle(Vector2.ZERO, 72.0, glow_col)

	if _upgrade_flash > 0.0:
		draw_circle(Vector2.ZERO, 80.0 + _upgrade_flash * 24.0, Color(0.5, 1.0, 0.6, _upgrade_flash * 0.25))

	# Fairy dust flash
	if _fairy_flash > 0.0:
		for i in range(12):
			var sa = TAU * float(i) / 12.0 + _fairy_flash * 4.0
			var sp = Vector2.from_angle(sa) * (50.0 + (1.0 - _fairy_flash) * 100.0)
			var spark_size = 5.0 + _fairy_flash * 5.0
			draw_circle(sp, spark_size, Color(1.0, 0.9, 0.3, _fairy_flash * 0.6))
			draw_line(sp - Vector2(spark_size, 0), sp + Vector2(spark_size, 0), Color(1.0, 1.0, 0.7, _fairy_flash * 0.4), 1.0)
			draw_line(sp - Vector2(0, spark_size), sp + Vector2(0, spark_size), Color(1.0, 1.0, 0.7, _fairy_flash * 0.4), 1.0)
		draw_circle(Vector2.ZERO, 36.0 + (1.0 - _fairy_flash) * 70.0, Color(0.9, 0.85, 0.3, _fairy_flash * 0.15))
		draw_arc(Vector2.ZERO, 30.0 + (1.0 - _fairy_flash) * 50.0, 0, TAU, 32, Color(1.0, 0.85, 0.2, _fairy_flash * 0.3), 2.5)

	# Croc flash
	if _croc_flash > 0.0:
		var croc_r = 48.0 + (1.0 - _croc_flash) * 60.0
		draw_circle(Vector2.ZERO, croc_r, Color(0.2, 0.6, 0.15, _croc_flash * 0.3))
		for ci in range(8):
			var ca = TAU * float(ci) / 8.0
			var c_inner = Vector2.from_angle(ca) * (croc_r - 15.0)
			var c_outer = Vector2.from_angle(ca) * (croc_r + 5.0)
			draw_line(c_inner, c_outer, Color(0.95, 0.95, 0.8, _croc_flash * 0.5), 2.0)

	# === STONE PLATFORM (Bloons-style placed tower base) ===
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

	# Shadow tendrils from platform edges (gothic)
	for ti in range(5):
		var ta = TAU * float(ti) / 5.0 + _time * 0.3
		var t_base = Vector2(cos(ta) * 24.0, plat_y + sin(ta) * 8.0)
		var t_end = t_base + Vector2(sin(_time * 0.8 + float(ti)) * 6.0, 8.0 + sin(_time * 1.2 + float(ti)) * 4.0)
		draw_line(t_base, t_end, Color(0.04, 0.02, 0.06, 0.2), 2.0)
		draw_line(t_end, t_end + Vector2(sin(_time + float(ti)) * 3.0, 5.0), Color(0.04, 0.02, 0.06, 0.1), 1.5)

	# Tier pips on platform edge
	for i in range(upgrade_tier):
		var pip_angle = -PI / 2.0 + float(i) * (TAU / 4.0) - (float(upgrade_tier - 1) * TAU / 8.0)
		var pip_pos = Vector2(cos(pip_angle) * 22.0, plat_y + sin(pip_angle) * 8.0)
		var pip_col: Color
		match i:
			0: pip_col = Color(0.4, 0.4, 0.5)
			1: pip_col = Color(0.6, 0.85, 0.3)
			2: pip_col = Color(0.3, 0.75, 0.4)
			3: pip_col = Color(0.4, 1.0, 0.5)
		draw_circle(pip_pos, 4.0, pip_col)
		draw_circle(pip_pos, 5.5, Color(pip_col.r, pip_col.g, pip_col.b, 0.15))

	# === CHARACTER POSITIONS (chibi proportions) ===
	var feet_y = body_offset + Vector2(0, 14.0)
	var torso_center = body_offset + Vector2(0, -2.0)
	var head_center = body_offset + Vector2(0, -20.0)

	# === Tier 4: Fairy dust particles floating around ===
	if upgrade_tier >= 4:
		for fd in range(10):
			var fd_seed = float(fd) * 2.37
			var fd_angle = _time * (0.4 + fmod(fd_seed, 0.6)) + fd_seed
			var fd_radius = 28.0 + fmod(fd_seed * 7.3, 35.0)
			var fd_pos = body_offset + Vector2(cos(fd_angle) * fd_radius, sin(fd_angle) * fd_radius * 0.6)
			var fd_alpha = 0.3 + sin(_time * 3.0 + fd_seed * 2.0) * 0.2
			var fd_size = 1.5 + sin(_time * 2.5 + fd_seed) * 0.6
			draw_circle(fd_pos, fd_size, Color(1.0, 0.92, 0.4, fd_alpha))
			draw_line(fd_pos - Vector2(fd_size + 0.5, 0), fd_pos + Vector2(fd_size + 0.5, 0), Color(1.0, 1.0, 0.8, fd_alpha * 0.4), 0.5)
			draw_line(fd_pos - Vector2(0, fd_size + 0.5), fd_pos + Vector2(0, fd_size + 0.5), Color(1.0, 1.0, 0.8, fd_alpha * 0.4), 0.5)

	# === Tier 3+: Crocodile lurking beside platform ===
	if upgrade_tier >= 3:
		var croc_base = Vector2(body_offset.x + 24.0, plat_y + 4.0)
		var jaw_open = sin(_time * 2.0) * 0.35
		# Body
		draw_circle(croc_base, 10.0, Color(0.22, 0.42, 0.15))
		draw_circle(croc_base, 7.5, Color(0.28, 0.48, 0.20))
		# Belly
		draw_circle(croc_base + Vector2(2, 2), 5.0, Color(0.45, 0.58, 0.32))
		# Scale bumps on back
		for sb in range(4):
			var sbp = croc_base + Vector2(-6.0 + float(sb) * 3.5, -5.0)
			draw_circle(sbp, 2.0, Color(0.20, 0.38, 0.13))
		# Snout
		draw_line(croc_base + Vector2(8, 0), croc_base + Vector2(22, 0), Color(0.26, 0.48, 0.18), 6.0)
		draw_line(croc_base + Vector2(8, 0), croc_base + Vector2(22, 0), Color(0.30, 0.52, 0.22), 4.0)
		# Nostrils
		draw_circle(croc_base + Vector2(21, -1.5), 0.8, Color(0.12, 0.20, 0.08))
		draw_circle(croc_base + Vector2(21, 1.5), 0.8, Color(0.12, 0.20, 0.08))
		# Upper jaw
		draw_line(croc_base + Vector2(22, 0), croc_base + Vector2(16, -5.0 - jaw_open * 7.0), Color(0.22, 0.42, 0.16), 3.0)
		draw_line(croc_base + Vector2(22, 0), croc_base + Vector2(10, -4.0 - jaw_open * 5.0), Color(0.22, 0.42, 0.16), 2.5)
		# Lower jaw
		draw_line(croc_base + Vector2(22, 0), croc_base + Vector2(16, 5.0 + jaw_open * 7.0), Color(0.20, 0.38, 0.14), 2.5)
		draw_line(croc_base + Vector2(22, 0), croc_base + Vector2(10, 4.0 + jaw_open * 5.0), Color(0.20, 0.38, 0.14), 2.0)
		# Teeth
		for t in range(4):
			var tx = 19.0 - float(t) * 2.2
			draw_line(croc_base + Vector2(tx, -3.0 - jaw_open * 5.0), croc_base + Vector2(tx, -5.5 - jaw_open * 5.0), Color(0.98, 0.96, 0.88), 1.2)
			draw_line(croc_base + Vector2(tx, 3.0 + jaw_open * 5.0), croc_base + Vector2(tx, 5.5 + jaw_open * 5.0), Color(0.94, 0.94, 0.84), 1.0)
		# Eye with slit pupil
		draw_circle(croc_base + Vector2(4, -6), 3.5, Color(0.92, 0.82, 0.08))
		draw_circle(croc_base + Vector2(4, -6), 2.2, Color(0.85, 0.75, 0.05))
		draw_line(croc_base + Vector2(4, -8), croc_base + Vector2(4, -4), Color(0.08, 0.08, 0.04), 1.2)
		# Tail
		var tail_sway = sin(_time * 1.8) * 5.0
		draw_line(croc_base + Vector2(-8, 0), croc_base + Vector2(-20, tail_sway), Color(0.25, 0.45, 0.18), 4.5)
		draw_line(croc_base + Vector2(-20, tail_sway), croc_base + Vector2(-28, -tail_sway * 0.5), Color(0.23, 0.42, 0.16), 3.0)
		draw_line(croc_base + Vector2(-28, -tail_sway * 0.5), croc_base + Vector2(-33, tail_sway * 0.3), Color(0.20, 0.38, 0.14), 2.0)
		# Tick-tock clock on belly
		var clock_pos = croc_base + Vector2(-1, 1)
		draw_arc(clock_pos, 4.0, 0, TAU, 10, Color(0.70, 0.60, 0.20, 0.5), 0.7)
		var ch = _time * 0.5
		draw_line(clock_pos, clock_pos + Vector2.from_angle(ch) * 2.5, Color(0.70, 0.60, 0.20, 0.6), 0.6)
		draw_line(clock_pos, clock_pos + Vector2.from_angle(ch * 3.0) * 3.0, Color(0.70, 0.60, 0.20, 0.6), 0.5)

	# === Tier 1+: Peter's detached shadow ===
	if upgrade_tier >= 1:
		var shadow_off = body_offset + Vector2(14.0 + sin(_time * 1.5) * 5.0, 3.0 + cos(_time * 0.9) * 3.0)
		var shadow_alpha: float = 0.2 + 0.08 * float(min(upgrade_tier, 4))
		var sc = Color(0.04, 0.04, 0.08, shadow_alpha)
		var sc_light = Color(0.04, 0.04, 0.08, shadow_alpha * 0.7)
		# Shadow head
		draw_circle(shadow_off + Vector2(0, -18.0), 9.0, sc)
		# Shadow hat
		var s_hat = PackedVector2Array([
			shadow_off + Vector2(-8, -22),
			shadow_off + Vector2(8, -22),
			shadow_off + Vector2(10, -34),
		])
		draw_colored_polygon(s_hat, sc_light)
		# Shadow body
		var s_body = PackedVector2Array([
			shadow_off + Vector2(-8, -10),
			shadow_off + Vector2(8, -10),
			shadow_off + Vector2(10, 6),
			shadow_off + Vector2(-10, 6),
		])
		draw_colored_polygon(s_body, sc)
		# Shadow legs
		draw_line(shadow_off + Vector2(-5, 6), shadow_off + Vector2(-7, 16), sc, 2.5)
		draw_line(shadow_off + Vector2(5, 6), shadow_off + Vector2(7, 16), sc, 2.5)
		# Shadow arms (wispy, misaligned)
		var wave = sin(_time * 3.0) * 3.0
		draw_line(shadow_off + Vector2(-8, -6), shadow_off + Vector2(-18 - wave, -2), sc, 2.0)
		draw_line(shadow_off + Vector2(8, -6), shadow_off + Vector2(18 + wave, -8), sc, 2.0)
		# Shadow reaching out (mischievous)
		var reach = sin(_time * 0.7) * 4.0
		draw_line(shadow_off + Vector2(18 + wave, -8), shadow_off + Vector2(22 + reach, -10 + wave * 0.5), sc_light, 1.5)
		# Wispy tendrils at shadow edges
		for wi in range(4):
			var w_base = shadow_off + Vector2(sin(float(wi) * 1.5) * 10.0, 6.0 + float(wi) * 2.5)
			var w_tip = w_base + Vector2(sin(_time * 2.0 + float(wi)) * 4.0, 5.0)
			draw_line(w_base, w_tip, Color(0.04, 0.04, 0.08, shadow_alpha * 0.4), 1.5)

	# === CHIBI CHARACTER BODY ===

	# Pointed elf boots (curled-up toes)
	var l_foot = feet_y + Vector2(-7, 0)
	var r_foot = feet_y + Vector2(7, 0)
	# Boot base
	draw_circle(l_foot, 5.0, Color(0.32, 0.22, 0.08))
	draw_circle(l_foot, 3.8, Color(0.40, 0.28, 0.12))
	draw_circle(r_foot, 5.0, Color(0.32, 0.22, 0.08))
	draw_circle(r_foot, 3.8, Color(0.40, 0.28, 0.12))
	# Curled pointed toes
	draw_line(l_foot + Vector2(-3, -1), l_foot + Vector2(-9, -5), Color(0.40, 0.28, 0.12), 3.5)
	draw_circle(l_foot + Vector2(-9, -5), 2.0, Color(0.42, 0.30, 0.14))
	draw_line(r_foot + Vector2(3, -1), r_foot + Vector2(9, -5), Color(0.40, 0.28, 0.12), 3.5)
	draw_circle(r_foot + Vector2(9, -5), 2.0, Color(0.42, 0.30, 0.14))
	# Tiny bells on toe tips
	draw_circle(l_foot + Vector2(-9, -5), 1.3, Color(0.85, 0.75, 0.2))
	draw_circle(l_foot + Vector2(-9, -5.5), 0.6, Color(1.0, 0.92, 0.4, 0.6))
	draw_circle(r_foot + Vector2(9, -5), 1.3, Color(0.85, 0.75, 0.2))
	draw_circle(r_foot + Vector2(9, -5.5), 0.6, Color(1.0, 0.92, 0.4, 0.6))
	# Leaf wrapping on boots
	for bi in range(2):
		var boot = l_foot if bi == 0 else r_foot
		for bl in range(2):
			var ba = PI * 0.5 + float(bl) * 0.8 - 0.4
			var leaf_c = boot + Vector2.from_angle(ba) * 3.5
			draw_line(leaf_c - Vector2(2.5, 0), leaf_c + Vector2(2.5, 0), Color(0.18, 0.44, 0.12, 0.6), 1.5)

	# Short chibi legs with green tights
	draw_line(l_foot + Vector2(0, -3), torso_center + Vector2(-6, 8), Color(0.14, 0.40, 0.08), 5.0)
	draw_line(l_foot + Vector2(0, -3), torso_center + Vector2(-6, 8), Color(0.18, 0.48, 0.12), 3.5)
	draw_line(r_foot + Vector2(0, -3), torso_center + Vector2(6, 8), Color(0.14, 0.40, 0.08), 5.0)
	draw_line(r_foot + Vector2(0, -3), torso_center + Vector2(6, 8), Color(0.18, 0.48, 0.12), 3.5)

	# Green leaf tunic (dark forest green, gothic)
	var tunic_pts = PackedVector2Array([
		torso_center + Vector2(-14, 10),
		torso_center + Vector2(-15, -2),
		torso_center + Vector2(-11, -10),
		torso_center + Vector2(11, -10),
		torso_center + Vector2(15, -2),
		torso_center + Vector2(14, 10),
	])
	draw_colored_polygon(tunic_pts, Color(0.14, 0.40, 0.08))
	# Lighter inner tunic
	var tunic_hi = PackedVector2Array([
		torso_center + Vector2(-7, 8),
		torso_center + Vector2(-9, -2),
		torso_center + Vector2(9, -2),
		torso_center + Vector2(7, 8),
	])
	draw_colored_polygon(tunic_hi, Color(0.20, 0.52, 0.14, 0.45))
	# V-neckline detail
	draw_line(torso_center + Vector2(-3, -10), torso_center + Vector2(0, -5), Color(0.10, 0.32, 0.06, 0.6), 1.2)
	draw_line(torso_center + Vector2(3, -10), torso_center + Vector2(0, -5), Color(0.10, 0.32, 0.06, 0.6), 1.2)
	# Jagged leaf bottom edge
	for ji in range(7):
		var jx = -12.0 + float(ji) * 4.0
		var jag = 3.5 + sin(float(ji) * 2.3 + _time * 1.5) * 2.0
		var jag_pts = PackedVector2Array([
			torso_center + Vector2(jx - 1.5, 9),
			torso_center + Vector2(jx + 1.5, 9),
			torso_center + Vector2(jx, 9 + jag),
		])
		draw_colored_polygon(jag_pts, Color(0.12, 0.38, 0.06))
	# Leaf texture overlay on tunic
	for li in range(4):
		var lx = -6.0 + float(li % 2) * 6.0
		var ly = -6.0 + float(li / 2) * 7.0
		var leaf_pos = torso_center + Vector2(lx, ly)
		var leaf_a = float(li) * 0.7 + 0.3
		var ld = Vector2.from_angle(leaf_a)
		var lp = ld.rotated(PI / 2.0)
		var leaf_pts = PackedVector2Array([
			leaf_pos - ld * 4.0,
			leaf_pos + lp * 2.0,
			leaf_pos + ld * 4.0,
			leaf_pos - lp * 2.0,
		])
		draw_colored_polygon(leaf_pts, Color(0.16, 0.44, 0.10, 0.5))
		draw_line(leaf_pos - ld * 3.0, leaf_pos + ld * 3.0, Color(0.12, 0.34, 0.06, 0.4), 0.6)
	# Fold shadows
	draw_line(torso_center + Vector2(-10, -6), torso_center + Vector2(-8, 6), Color(0.10, 0.32, 0.06, 0.4), 1.2)
	draw_line(torso_center + Vector2(10, -6), torso_center + Vector2(8, 6), Color(0.10, 0.32, 0.06, 0.4), 1.2)
	# Cobweb thread across tunic (gothic detail)
	draw_line(torso_center + Vector2(-12, -6), torso_center + Vector2(8, 4), Color(0.85, 0.88, 0.92, 0.08), 0.5)

	# Vine belt with leaf buckle
	draw_line(torso_center + Vector2(-14, -1), torso_center + Vector2(14, -1), Color(0.20, 0.36, 0.08), 4.0)
	draw_line(torso_center + Vector2(-14, -1), torso_center + Vector2(14, -1), Color(0.28, 0.46, 0.14), 2.5)
	# Vine twists
	for vi in range(5):
		var vp = torso_center + Vector2(-10.0 + float(vi) * 5.0, -1.0 + sin(float(vi) * PI + _time * 2.0) * 1.0)
		draw_circle(vp, 2.2, Color(0.24, 0.42, 0.10))
	# Leaf buckle
	var buckle = torso_center + Vector2(0, -1)
	var buckle_pts = PackedVector2Array([
		buckle + Vector2(-3.5, 0),
		buckle + Vector2(0, -4.5),
		buckle + Vector2(3.5, 0),
		buckle + Vector2(0, 4.5),
	])
	draw_colored_polygon(buckle_pts, Color(0.32, 0.58, 0.18))
	draw_colored_polygon(buckle_pts, Color(0.38, 0.64, 0.22, 0.5))
	draw_line(buckle + Vector2(-2.5, 0), buckle + Vector2(2.5, 0), Color(0.22, 0.44, 0.12), 0.6)
	draw_line(buckle + Vector2(0, -3), buckle + Vector2(0, 3), Color(0.22, 0.44, 0.12), 0.6)
	# Fairy dust pouch on belt
	if upgrade_tier >= 2:
		var pouch = torso_center + Vector2(10, -1)
		draw_circle(pouch, 3.5, Color(0.42, 0.30, 0.12))
		draw_circle(pouch + Vector2(0, -1), 2.8, Color(0.48, 0.34, 0.16))
		# Golden specks spilling
		for sp in range(2):
			var spp = pouch + Vector2(float(sp) * 2.0 - 1.0, 4.0 + float(sp) * 2.0 + sin(_time * 3.0 + float(sp)) * 1.5)
			draw_circle(spp, 0.8, Color(1.0, 0.9, 0.3, 0.4))

	# === Shoulder leaf pauldrons ===
	draw_circle(torso_center + Vector2(-13, -8), 6.0, Color(0.14, 0.40, 0.10))
	draw_circle(torso_center + Vector2(-13, -8), 4.5, Color(0.20, 0.50, 0.14))
	draw_line(torso_center + Vector2(-16, -8), torso_center + Vector2(-10, -8), Color(0.12, 0.34, 0.08, 0.5), 0.6)
	draw_circle(torso_center + Vector2(13, -8), 6.0, Color(0.14, 0.40, 0.10))
	draw_circle(torso_center + Vector2(13, -8), 4.5, Color(0.20, 0.50, 0.14))
	draw_line(torso_center + Vector2(10, -8), torso_center + Vector2(16, -8), Color(0.12, 0.34, 0.08, 0.5), 0.6)

	# === Arms ===
	# Dagger arm (right) — swipes toward aim direction
	var dagger_hand: Vector2
	if _attack_anim > 0.0:
		var swipe = dir.rotated(-_attack_anim * PI * 0.5 + PI * 0.3)
		dagger_hand = torso_center + Vector2(12, -6) + swipe * 16.0
	else:
		dagger_hand = torso_center + Vector2(12, -6) + dir * 16.0
	# Upper arm
	draw_line(torso_center + Vector2(12, -8), dagger_hand, skin_shadow, 4.5)
	draw_line(torso_center + Vector2(12, -8), dagger_hand, skin_base, 3.5)
	# Elbow
	var r_elbow = torso_center + Vector2(12, -8) + (dagger_hand - torso_center - Vector2(12, -8)) * 0.5
	draw_circle(r_elbow, 3.0, skin_base)
	# Hand
	draw_circle(dagger_hand, 3.5, skin_shadow)
	draw_circle(dagger_hand, 2.8, skin_base)
	# Fingers gripping
	var grip_dir = dir if _attack_anim <= 0.0 else dir.rotated(-_attack_anim * PI * 0.5 + PI * 0.3)
	for fi in range(3):
		var fa = float(fi - 1) * 0.4
		draw_circle(dagger_hand + grip_dir.rotated(fa) * 3.5, 1.3, skin_highlight)

	# Off-hand (on hip, cocky pose)
	var off_hand = torso_center + Vector2(-12, 2)
	draw_line(torso_center + Vector2(-12, -8), off_hand, skin_shadow, 4.5)
	draw_line(torso_center + Vector2(-12, -8), off_hand, skin_base, 3.5)
	var l_elbow = torso_center + Vector2(-12, -8) + (off_hand - torso_center - Vector2(-12, -8)) * 0.5
	draw_circle(l_elbow, 2.5, skin_base)
	draw_circle(off_hand, 3.0, skin_shadow)
	draw_circle(off_hand, 2.5, skin_base)

	# === Ornate dagger ===
	var dagger_dir: Vector2
	if _attack_anim > 0.0:
		dagger_dir = dir.rotated(-_attack_anim * PI * 0.5 + PI * 0.3)
	else:
		dagger_dir = dir
	var dagger_perp = dagger_dir.rotated(PI / 2.0)
	# Handle (leather wrapped)
	draw_line(dagger_hand, dagger_hand + dagger_dir * 8.0, Color(0.38, 0.26, 0.12), 3.5)
	draw_line(dagger_hand, dagger_hand + dagger_dir * 8.0, Color(0.44, 0.32, 0.16), 2.0)
	# Leather wrapping marks
	for wi in range(3):
		var wp = dagger_hand + dagger_dir * (2.0 + float(wi) * 2.5)
		draw_line(wp - dagger_perp * 2.0, wp + dagger_perp * 2.0, Color(0.50, 0.38, 0.18), 0.7)
	# Pommel (acorn)
	draw_circle(dagger_hand - dagger_dir * 1.0, 2.5, Color(0.48, 0.36, 0.16))
	draw_circle(dagger_hand - dagger_dir * 1.0, 1.5, Color(0.56, 0.42, 0.20))
	# Cross-guard (ornate leaf shape)
	var guard_c = dagger_hand + dagger_dir * 8.0
	draw_line(guard_c + dagger_perp * 6.5, guard_c - dagger_perp * 6.5, Color(0.52, 0.42, 0.16), 3.5)
	draw_line(guard_c + dagger_perp * 6.5, guard_c - dagger_perp * 6.5, Color(0.60, 0.50, 0.20), 2.0)
	# Guard gem (emerald)
	draw_circle(guard_c, 1.5, Color(0.15, 0.55, 0.25))
	draw_circle(guard_c + dagger_dir * 0.2, 0.8, Color(0.3, 0.75, 0.4, 0.6))
	# Blade (bright steel, slightly curved)
	var blade_tip = dagger_hand + dagger_dir * 28.0
	var blade_mid = guard_c + (blade_tip - guard_c) * 0.5 + dagger_perp * 1.0
	draw_line(guard_c, blade_mid, Color(0.72, 0.74, 0.80), 2.8)
	draw_line(blade_mid, blade_tip, Color(0.72, 0.74, 0.80), 1.8)
	# Blade fill
	draw_line(guard_c, blade_tip, Color(0.80, 0.82, 0.88), 2.0)
	# Edge highlight
	draw_line(guard_c + dagger_perp * 0.8, blade_tip, Color(0.90, 0.92, 0.96, 0.5), 0.8)
	# Blade shine
	draw_line(dagger_hand + dagger_dir * 12.0, dagger_hand + dagger_dir * 22.0, Color(0.95, 0.96, 1.0, 0.5), 1.0)
	# Attack glint
	if _attack_anim > 0.5:
		var glint_a = (_attack_anim - 0.5) * 2.0
		draw_circle(blade_tip, 3.5 + glint_a * 2.5, Color(1.0, 1.0, 0.95, glint_a * 0.6))
		draw_line(blade_tip - dagger_perp * (5.0 * glint_a), blade_tip + dagger_perp * (5.0 * glint_a), Color(1.0, 1.0, 0.9, glint_a * 0.4), 0.8)

	# === HEAD (big chibi head ~40% of total height) ===
	# Neck
	draw_line(torso_center + Vector2(0, -10), head_center + Vector2(0, 8), skin_shadow, 5.0)
	draw_line(torso_center + Vector2(0, -10), head_center + Vector2(0, 8), skin_base, 3.5)
	# Leaf collar
	for nc in range(4):
		var ncx = -5.0 + float(nc) * 3.5
		draw_line(torso_center + Vector2(ncx, -10), torso_center + Vector2(ncx, -13), Color(0.16, 0.42, 0.10, 0.6), 2.0)

	# Auburn messy hair (back layer — drawn before face)
	var hair_sway = sin(_time * 2.5) * 2.5
	var hair_base_col = Color(0.48, 0.24, 0.10)
	var hair_mid_col = Color(0.55, 0.28, 0.12)
	var hair_hi_col = Color(0.62, 0.34, 0.15)
	# Hair mass
	draw_circle(head_center, 14.5, hair_base_col)
	draw_circle(head_center + Vector2(0, -1), 13.0, hair_mid_col)
	# Volume highlight
	draw_circle(head_center + Vector2(-2, -4), 8.0, Color(0.52, 0.26, 0.12, 0.35))
	# Messy tufts (8 windswept strands)
	var tuft_data = [
		[0.2, 7.0, 2.8], [0.8, 8.0, 2.5], [1.5, 6.0, 3.0], [2.2, 7.5, 2.2],
		[3.5, 8.5, 2.5], [4.2, 6.5, 3.0], [5.0, 7.0, 2.8], [5.6, 8.0, 2.3],
	]
	for h in range(8):
		var ha: float = tuft_data[h][0]
		var tlen: float = tuft_data[h][1]
		var twid: float = tuft_data[h][2]
		var tuft_base_pos = head_center + Vector2.from_angle(ha) * 12.5
		var sway_d = 1.0 if h % 2 == 0 else -1.0
		var tuft_tip_pos = tuft_base_pos + Vector2.from_angle(ha) * tlen + Vector2(hair_sway * sway_d * 0.5, 0)
		var tcol = hair_mid_col if h % 3 == 0 else hair_hi_col if h % 3 == 1 else hair_base_col
		draw_line(tuft_base_pos, tuft_tip_pos, tcol, twid)
		# Wispy secondary strand
		var ha2 = ha + (0.1 if h % 2 == 0 else -0.1)
		var t2_base = head_center + Vector2.from_angle(ha2) * 11.5
		var t2_tip = t2_base + Vector2.from_angle(ha2) * (tlen * 0.6) + Vector2(hair_sway * sway_d * 0.3, 0)
		draw_line(t2_base, t2_tip, hair_base_col, twid * 0.5)

	# Face
	draw_circle(head_center + Vector2(0, 1), 11.5, skin_base)
	# Face shading
	draw_arc(head_center + Vector2(0, 1), 10.5, PI * 0.6, PI * 1.4, 12, skin_shadow, 1.5)
	# Cheek blush
	draw_circle(head_center + Vector2(-7, 3), 3.5, Color(0.95, 0.60, 0.52, 0.2))
	draw_circle(head_center + Vector2(7, 3), 3.5, Color(0.95, 0.60, 0.52, 0.2))

	# Pointed elf ears (prominent)
	# Right ear
	var r_ear_tip = head_center + Vector2(18, -4)
	var r_ear_pts = PackedVector2Array([
		head_center + Vector2(10, -5),
		head_center + Vector2(10, 2),
		r_ear_tip,
	])
	draw_colored_polygon(r_ear_pts, skin_base)
	draw_line(head_center + Vector2(10, -5), r_ear_tip, skin_shadow, 1.8)
	draw_line(r_ear_tip, head_center + Vector2(10, 2), Color(0.80, 0.64, 0.50), 1.2)
	# Inner ear
	draw_circle(head_center + Vector2(14, -2), 2.5, Color(0.92, 0.70, 0.60, 0.5))
	# Left ear
	var l_ear_tip = head_center + Vector2(-18, -4)
	var l_ear_pts = PackedVector2Array([
		head_center + Vector2(-10, -5),
		head_center + Vector2(-10, 2),
		l_ear_tip,
	])
	draw_colored_polygon(l_ear_pts, skin_base)
	draw_line(head_center + Vector2(-10, -5), l_ear_tip, skin_shadow, 1.8)
	draw_line(l_ear_tip, head_center + Vector2(-10, 2), Color(0.80, 0.64, 0.50), 1.2)
	draw_circle(head_center + Vector2(-14, -2), 2.5, Color(0.92, 0.70, 0.60, 0.5))
	# Tier 4: Ear tip fairy glow
	if upgrade_tier >= 4:
		var ear_glow = 0.3 + sin(_time * 3.0) * 0.15
		draw_circle(r_ear_tip, 2.5, Color(1.0, 0.9, 0.4, ear_glow))
		draw_circle(l_ear_tip, 2.5, Color(1.0, 0.9, 0.4, ear_glow))

	# Big chibi eyes (large, expressive)
	var look_dir = dir * 1.5
	var l_eye = head_center + Vector2(-5, -1)
	var r_eye = head_center + Vector2(5, -1)
	# Eye socket shadow
	draw_circle(l_eye, 5.5, Color(0.72, 0.56, 0.44, 0.25))
	draw_circle(r_eye, 5.5, Color(0.72, 0.56, 0.44, 0.25))
	# Eye whites
	draw_circle(l_eye, 5.0, Color(0.96, 0.96, 0.98))
	draw_circle(r_eye, 5.0, Color(0.96, 0.96, 0.98))
	# Green irises (large for chibi)
	draw_circle(l_eye + look_dir, 3.2, Color(0.10, 0.48, 0.20))
	draw_circle(l_eye + look_dir, 2.5, Color(0.16, 0.62, 0.28))
	draw_circle(l_eye + look_dir, 1.8, Color(0.22, 0.70, 0.32))
	draw_circle(r_eye + look_dir, 3.2, Color(0.10, 0.48, 0.20))
	draw_circle(r_eye + look_dir, 2.5, Color(0.16, 0.62, 0.28))
	draw_circle(r_eye + look_dir, 1.8, Color(0.22, 0.70, 0.32))
	# Gold limbal ring
	draw_arc(l_eye + look_dir, 3.0, 0, TAU, 10, Color(0.65, 0.55, 0.15, 0.25), 0.5)
	draw_arc(r_eye + look_dir, 3.0, 0, TAU, 10, Color(0.65, 0.55, 0.15, 0.25), 0.5)
	# Pupils
	draw_circle(l_eye + look_dir * 1.15, 1.5, Color(0.05, 0.05, 0.07))
	draw_circle(r_eye + look_dir * 1.15, 1.5, Color(0.05, 0.05, 0.07))
	# Primary highlight (big sparkle)
	draw_circle(l_eye + Vector2(-1.2, -1.5), 1.4, Color(1.0, 1.0, 1.0, 0.9))
	draw_circle(r_eye + Vector2(-1.2, -1.5), 1.4, Color(1.0, 1.0, 1.0, 0.9))
	# Secondary highlight
	draw_circle(l_eye + Vector2(1.5, 0.5), 0.7, Color(1.0, 1.0, 1.0, 0.5))
	draw_circle(r_eye + Vector2(1.5, 0.5), 0.7, Color(1.0, 1.0, 1.0, 0.5))
	# Mischievous green glint
	var glint_t = sin(_time * 2.0) * 0.25
	draw_circle(l_eye + Vector2(0.5, -0.5), 0.5, Color(0.4, 0.9, 0.5, 0.25 + glint_t))
	draw_circle(r_eye + Vector2(0.5, -0.5), 0.5, Color(0.4, 0.9, 0.5, 0.25 + glint_t))
	# Eyelid lines
	draw_arc(l_eye, 5.0, PI + 0.3, TAU - 0.3, 8, Color(0.40, 0.22, 0.12), 1.2)
	draw_arc(r_eye, 5.0, PI + 0.3, TAU - 0.3, 8, Color(0.40, 0.22, 0.12), 1.2)
	# Eyelashes (2 tiny lashes per eye)
	for el in range(2):
		var ela = PI + 0.5 + float(el) * 0.6
		draw_line(l_eye + Vector2.from_angle(ela) * 5.0, l_eye + Vector2.from_angle(ela) * 7.0, Color(0.38, 0.20, 0.10, 0.5), 0.7)
		draw_line(r_eye + Vector2.from_angle(ela) * 5.0, r_eye + Vector2.from_angle(ela) * 7.0, Color(0.38, 0.20, 0.10, 0.5), 0.7)

	# Mischievous asymmetric eyebrows
	draw_line(l_eye + Vector2(-3.5, -4.5), l_eye + Vector2(1.5, -5.5), Color(0.45, 0.24, 0.10), 1.8)
	draw_line(r_eye + Vector2(-1.5, -6.0), r_eye + Vector2(3.5, -4.0), Color(0.45, 0.24, 0.10), 1.8)

	# Button nose
	draw_circle(head_center + Vector2(0, 3.5), 2.2, skin_highlight)
	draw_circle(head_center + Vector2(0.3, 3.8), 1.6, Color(0.93, 0.78, 0.65))
	# Nostrils
	draw_circle(head_center + Vector2(-1.2, 4.2), 0.6, Color(0.55, 0.40, 0.32, 0.4))
	draw_circle(head_center + Vector2(1.2, 4.2), 0.6, Color(0.55, 0.40, 0.32, 0.4))

	# Cocky Peter Pan grin
	draw_arc(head_center + Vector2(0.5, 7), 5.5, 0.15, PI - 0.15, 12, Color(0.62, 0.28, 0.22), 2.0)
	# Teeth showing (cocky grin)
	for ti in range(4):
		var tooth_x = -2.5 + float(ti) * 1.7
		draw_circle(head_center + Vector2(tooth_x, 7.2), 0.9, Color(0.98, 0.96, 0.92))
	# Smirk line (right side curves up more)
	draw_line(head_center + Vector2(4.5, 6.5), head_center + Vector2(6.0, 5.5), Color(0.62, 0.28, 0.22, 0.5), 1.0)
	# Dimples
	draw_circle(head_center + Vector2(-6.5, 6), 1.2, Color(0.78, 0.56, 0.46, 0.4))
	draw_circle(head_center + Vector2(6.5, 6), 1.2, Color(0.78, 0.56, 0.46, 0.4))

	# Freckles
	var frk = Color(0.62, 0.42, 0.28, 0.5)
	draw_circle(head_center + Vector2(-5.5, 2.5), 0.8, frk)
	draw_circle(head_center + Vector2(-6.5, 4.0), 0.7, frk)
	draw_circle(head_center + Vector2(-4.5, 3.5), 0.6, frk)
	draw_circle(head_center + Vector2(5.5, 2.5), 0.8, frk)
	draw_circle(head_center + Vector2(6.5, 4.0), 0.7, frk)
	draw_circle(head_center + Vector2(4.5, 3.5), 0.6, frk)

	# === Peter Pan hat with leaf texture ===
	var hat_base_pos = head_center + Vector2(0, -9)
	var hat_tip_pos = hat_base_pos + Vector2(13, -18)
	var hat_pts = PackedVector2Array([
		hat_base_pos + Vector2(-13, 2),
	])
	# Curved brim
	for hbi in range(5):
		var ht = float(hbi) / 4.0
		var brim_pos = hat_base_pos + Vector2(-13.0 + ht * 26.0, 2.0 + sin(ht * PI) * 2.5)
		hat_pts.append(brim_pos)
	hat_pts.append(hat_tip_pos)
	draw_colored_polygon(hat_pts, Color(0.14, 0.42, 0.08))
	# Hat depth shading
	var hat_shade = PackedVector2Array([
		hat_base_pos + Vector2(-11, 1),
		hat_base_pos + Vector2(5, 1),
		hat_tip_pos + Vector2(-3, 1),
	])
	draw_colored_polygon(hat_shade, Color(0.10, 0.34, 0.06, 0.4))
	# Hat brim line
	draw_line(hat_base_pos + Vector2(-14, 2), hat_base_pos + Vector2(14, 2), Color(0.12, 0.36, 0.06), 3.5)
	draw_line(hat_base_pos + Vector2(-14, 2.5), hat_base_pos + Vector2(14, 2.5), Color(0.22, 0.50, 0.14), 2.0)
	# Leaf veins on hat
	var hat_vein = Color(0.10, 0.32, 0.06, 0.5)
	draw_line(hat_base_pos + Vector2(2, 0), hat_tip_pos + Vector2(-1, 1), hat_vein, 1.0)
	var vm1 = hat_base_pos + (hat_tip_pos - hat_base_pos) * 0.3
	var vm2 = hat_base_pos + (hat_tip_pos - hat_base_pos) * 0.55
	draw_line(vm1, vm1 + Vector2(-7, -2), hat_vein, 0.7)
	draw_line(vm1, vm1 + Vector2(3, 2), hat_vein, 0.7)
	draw_line(vm2, vm2 + Vector2(-5, -1.5), hat_vein, 0.6)

	# Red feather with barbs
	var feather_base = hat_base_pos + Vector2(9, -1)
	var feather_tip = feather_base + Vector2(20, -14)
	var feather_mid = feather_base + (feather_tip - feather_base) * 0.5
	# Quill
	draw_line(feather_base, feather_tip, Color(0.72, 0.10, 0.06), 2.0)
	# Feather body
	draw_line(feather_base + (feather_tip - feather_base) * 0.1, feather_tip - (feather_tip - feather_base) * 0.05, Color(0.88, 0.16, 0.08), 4.0)
	draw_line(feather_mid, feather_tip, Color(0.92, 0.22, 0.12), 3.0)
	# Feather barbs
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
	# Feather sway
	var f_sway = sin(_time * 3.0) * 2.0
	draw_line(feather_tip, feather_tip + f_p * f_sway + f_d * 2.5, Color(0.85, 0.18, 0.10, 0.5), 1.2)

	# === Tier 2+: Tinker Bell orbiting with sparkle trail ===
	if upgrade_tier >= 2:
		var tink_angle = _time * 1.8
		var tink_radius = 38.0
		var tink_bob_val = sin(_time * 4.0) * 3.5
		var tink_pos = body_offset + Vector2(cos(tink_angle) * tink_radius, sin(tink_angle) * tink_radius * 0.6 + tink_bob_val)
		# Sparkle trail
		for trail_i in range(5):
			var trail_a = tink_angle - float(trail_i + 1) * 0.3
			var trail_b = sin((_time - float(trail_i) * 0.15) * 4.0) * 3.5
			var trail_p = body_offset + Vector2(cos(trail_a) * tink_radius, sin(trail_a) * tink_radius * 0.6 + trail_b)
			var trail_alpha = 0.4 - float(trail_i) * 0.07
			var trail_size = 3.5 - float(trail_i) * 0.5
			draw_circle(trail_p, trail_size, Color(1.0, 0.92, 0.4, trail_alpha))
			if trail_i < 2:
				draw_line(trail_p - Vector2(trail_size, 0), trail_p + Vector2(trail_size, 0), Color(1.0, 1.0, 0.8, trail_alpha * 0.4), 0.5)
				draw_line(trail_p - Vector2(0, trail_size), trail_p + Vector2(0, trail_size), Color(1.0, 1.0, 0.8, trail_alpha * 0.4), 0.5)
		# Outer glow
		draw_circle(tink_pos, 10.0, Color(1.0, 0.9, 0.3, 0.12))
		draw_circle(tink_pos, 7.0, Color(1.0, 0.92, 0.35, 0.2))
		# Tinker Bell body
		draw_circle(tink_pos, 4.0, Color(1.0, 0.95, 0.4, 0.85))
		draw_circle(tink_pos, 2.5, Color(1.0, 1.0, 0.7, 0.95))
		# Head
		var tink_head = tink_pos + Vector2.from_angle(tink_angle) * 3.5
		draw_circle(tink_head, 2.0, Color(1.0, 0.95, 0.5, 0.9))
		draw_circle(tink_head, 1.3, Color(1.0, 1.0, 0.8))
		# Hair bun
		draw_circle(tink_head + Vector2.from_angle(tink_angle) * 1.3, 1.0, Color(1.0, 0.85, 0.3))
		# Dress
		var tink_body_dir = Vector2.from_angle(tink_angle + PI)
		var tink_perp_dir = tink_body_dir.rotated(PI / 2.0)
		var dress_pts = PackedVector2Array([
			tink_pos - tink_body_dir * 1.0 + tink_perp_dir * 1.5,
			tink_pos - tink_body_dir * 1.0 - tink_perp_dir * 1.5,
			tink_pos + tink_body_dir * 3.5 - tink_perp_dir * 3.0,
			tink_pos + tink_body_dir * 3.5 + tink_perp_dir * 3.0,
		])
		draw_colored_polygon(dress_pts, Color(0.5, 0.95, 0.4, 0.55))
		# Wings (rapid flutter)
		var wing_flutter = sin(_time * 14.0) * 3.0
		draw_line(tink_pos + tink_perp_dir * 2.0, tink_pos + tink_perp_dir * (9.0 + wing_flutter) + Vector2(0, -2.0), Color(0.9, 0.95, 1.0, 0.5), 2.0)
		draw_line(tink_pos - tink_perp_dir * 2.0, tink_pos - tink_perp_dir * (9.0 - wing_flutter) + Vector2(0, -2.0), Color(0.9, 0.95, 1.0, 0.5), 2.0)
		# Lower wings
		draw_line(tink_pos + tink_perp_dir * 1.5, tink_pos + tink_perp_dir * (6.0 + wing_flutter * 0.6) + Vector2(0, 1.5), Color(0.85, 0.92, 1.0, 0.35), 1.5)
		draw_line(tink_pos - tink_perp_dir * 1.5, tink_pos - tink_perp_dir * (6.0 - wing_flutter * 0.6) + Vector2(0, 1.5), Color(0.85, 0.92, 1.0, 0.35), 1.5)
		# Wing tip sparkle
		var wing_r_tip = tink_pos + tink_perp_dir * (9.0 + wing_flutter) + Vector2(0, -2.0)
		var wing_l_tip = tink_pos - tink_perp_dir * (9.0 - wing_flutter) + Vector2(0, -2.0)
		draw_circle(wing_r_tip, 1.2, Color(1.0, 1.0, 0.9, 0.35 + sin(_time * 6.0) * 0.15))
		draw_circle(wing_l_tip, 1.2, Color(1.0, 1.0, 0.9, 0.35 + cos(_time * 6.0) * 0.15))

	# === Tier 4: Golden fairy-dust aura ===
	if upgrade_tier >= 4:
		var aura_pulse = sin(_time * 2.5) * 5.0
		draw_circle(body_offset, 52.0 + aura_pulse, Color(1.0, 0.85, 0.3, 0.04))
		draw_circle(body_offset, 42.0 + aura_pulse * 0.6, Color(1.0, 0.88, 0.35, 0.06))
		draw_circle(body_offset, 34.0 + aura_pulse * 0.3, Color(1.0, 0.90, 0.4, 0.08))
		draw_arc(body_offset, 48.0 + aura_pulse, 0, TAU, 32, Color(1.0, 0.85, 0.35, 0.18), 2.5)
		draw_arc(body_offset, 38.0 + aura_pulse * 0.5, 0, TAU, 24, Color(1.0, 0.90, 0.4, 0.1), 1.8)
		# Orbiting golden sparkles
		for gs in range(8):
			var gs_a = _time * (0.8 + float(gs % 3) * 0.3) + float(gs) * TAU / 8.0
			var gs_r = 40.0 + aura_pulse + float(gs % 3) * 4.0
			var gs_p = body_offset + Vector2.from_angle(gs_a) * gs_r
			var gs_size = 1.5 + sin(_time * 3.0 + float(gs) * 1.5) * 0.8
			var gs_alpha = 0.35 + sin(_time * 3.0 + float(gs)) * 0.2
			draw_circle(gs_p, gs_size, Color(1.0, 0.9, 0.4, gs_alpha))
		# Rising fairy dust motes
		for rm in range(4):
			var rm_seed = float(rm) * 3.14
			var rm_x = sin(_time * 0.8 + rm_seed) * 25.0
			var rm_y = -fmod(_time * 18.0 + rm_seed * 10.0, 70.0) + 35.0
			var rm_alpha = 0.25 * (1.0 - abs(rm_y) / 35.0)
			if rm_alpha > 0.0:
				draw_circle(body_offset + Vector2(rm_x, rm_y), 1.2, Color(1.0, 0.92, 0.5, rm_alpha))

	# === Awaiting ability choice indicator ===
	if awaiting_ability_choice:
		var pulse = (sin(_time * 4.0) + 1.0) * 0.5
		draw_circle(Vector2.ZERO, 60.0 + pulse * 6.0, Color(0.5, 1.0, 0.6, 0.1 + pulse * 0.1))
		draw_arc(Vector2.ZERO, 60.0 + pulse * 6.0, 0, TAU, 32, Color(0.5, 1.0, 0.6, 0.3 + pulse * 0.3), 2.5)
		var font3 = ThemeDB.fallback_font
		draw_string(font3, Vector2(-16, -68), "!", HORIZONTAL_ALIGNMENT_CENTER, 32, 30, Color(0.5, 1.0, 0.6, 0.7 + pulse * 0.3))

	# Damage dealt counter
	if damage_dealt > 0:
		var font = ThemeDB.fallback_font
		var dmg_text = str(int(damage_dealt)) + " DMG"
		if stat_upgrade_level > 0:
			dmg_text += " • Lv." + str(stat_upgrade_level)
		draw_string(font, Vector2(-36, 56), dmg_text, HORIZONTAL_ALIGNMENT_LEFT, 160, 12, Color(1.0, 0.84, 0.0, 0.5))

	# Upgrade name flash
	if _upgrade_flash > 0.0 and _upgrade_name != "":
		var font2 = ThemeDB.fallback_font
		draw_string(font2, Vector2(-80, -60), _upgrade_name, HORIZONTAL_ALIGNMENT_CENTER, 160, 16, Color(0.5, 1.0, 0.6, min(_upgrade_flash, 1.0)))
