extends Node2D
## Peter Pan — fast attacker tower from JM Barrie's Peter and Wendy (1911).
## Throws daggers rapidly. Upgrades by dealing damage.
## Tier 1 (5000 DMG): "Shadow" — fires a shadow dagger at a 2nd target each shot
## Tier 2 (10000 DMG): "Fairy Dust" — periodic sparkle AoE (damage + slow)
## Tier 3 (15000 DMG): "Tick-Tock Croc" — periodically chomps strongest enemy for 3x damage
## Tier 4 (20000 DMG): "Never Land" — daggers pierce, all stats boosted, gold bonus doubled

var damage: float = 38.0
var fire_rate: float = 1.63
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

const STAT_UPGRADE_INTERVAL: float = 4000.0
const ABILITY_THRESHOLD: float = 12000.0
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

var dagger_scene = preload("res://scenes/peter_dagger.tscn")
var _game_font: Font

func _ready() -> void:
	_game_font = load("res://fonts/Cinzel.ttf")
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
		if enemy.has_method("is_targetable") and not enemy.is_targetable():
			continue
		if global_position.distance_to(enemy.global_position) < attack_range:
			return true
	return false

func _find_nearest_enemy() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist: float = attack_range
	for enemy in enemies:
		if enemy.has_method("is_targetable") and not enemy.is_targetable():
			continue
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
		if enemy.has_method("is_targetable") and not enemy.is_targetable():
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
		if enemy.has_method("is_targetable") and not enemy.is_targetable():
			continue
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
		if enemy.has_method("is_targetable") and not enemy.is_targetable():
			continue
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
	damage += 2.0
	fire_rate += 0.03
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
			fire_rate = 3.9
			attack_range = 185.0
		2: # Fairy Dust — AoE slow burst
			damage = 60.0
			fire_rate = 4.56
			attack_range = 200.0
			fairy_cooldown = 10.0
			gold_bonus = 6
		3: # Tick-Tock Croc — chomp strongest
			damage = 75.0
			fire_rate = 5.2
			attack_range = 220.0
			croc_cooldown = 10.0
			fairy_cooldown = 8.0
			gold_bonus = 8
		4: # Never Land — everything enhanced
			damage = 95.0
			fire_rate = 6.5
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

func _draw() -> void:
	# Selection ring
	if is_selected:
		var pulse = (sin(_time * 3.0) + 1.0) * 0.5
		var ring_alpha = 0.5 + pulse * 0.3
		draw_arc(Vector2.ZERO, 36.0, 0, TAU, 48, Color(1.0, 0.84, 0.0, ring_alpha), 2.5)
		draw_arc(Vector2.ZERO, 39.0, 0, TAU, 48, Color(1.0, 0.84, 0.0, ring_alpha * 0.4), 1.5)

	# Attack range arc
	draw_arc(Vector2.ZERO, attack_range, 0, TAU, 64, Color(1, 1, 1, 0.06), 1.0)

	var dir = Vector2.from_angle(aim_angle)
	var perp = dir.rotated(PI / 2.0)

	# Bouncy idle animation — more energetic
	var bounce = abs(sin(_time * 3.5)) * 7.0
	var breathe = sin(_time * 2.2) * 3.5
	var sway = sin(_time * 1.8) * 2.0
	var bob = Vector2(sway, -bounce - breathe)

	# Tier 4: Flying pose
	var fly_offset = Vector2.ZERO
	if upgrade_tier >= 4:
		fly_offset = dir * 8.0 + Vector2(0, -14.0 + sin(_time * 1.5) * 3.0)

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

	# Fairy dust flash (golden sparkles) — enhanced with more particles and star shapes
	if _fairy_flash > 0.0:
		for i in range(12):
			var sa = TAU * float(i) / 12.0 + _fairy_flash * 4.0
			var sp = Vector2.from_angle(sa) * (50.0 + (1.0 - _fairy_flash) * 100.0)
			var spark_size = 5.0 + _fairy_flash * 5.0
			draw_circle(sp, spark_size, Color(1.0, 0.9, 0.3, _fairy_flash * 0.6))
			# Star cross on each sparkle
			draw_line(sp - Vector2(spark_size, 0), sp + Vector2(spark_size, 0), Color(1.0, 1.0, 0.7, _fairy_flash * 0.4), 1.0)
			draw_line(sp - Vector2(0, spark_size), sp + Vector2(0, spark_size), Color(1.0, 1.0, 0.7, _fairy_flash * 0.4), 1.0)
		draw_circle(Vector2.ZERO, 36.0 + (1.0 - _fairy_flash) * 70.0, Color(0.9, 0.85, 0.3, _fairy_flash * 0.15))
		# Inner golden wave
		draw_arc(Vector2.ZERO, 30.0 + (1.0 - _fairy_flash) * 50.0, 0, TAU, 32, Color(1.0, 0.85, 0.2, _fairy_flash * 0.3), 2.5)

	# Croc flash (green burst with teeth pattern)
	if _croc_flash > 0.0:
		var croc_r = 48.0 + (1.0 - _croc_flash) * 60.0
		draw_circle(Vector2.ZERO, croc_r, Color(0.2, 0.6, 0.15, _croc_flash * 0.3))
		# Jaw snap lines radiating outward
		for ci in range(8):
			var ca = TAU * float(ci) / 8.0
			var c_inner = Vector2.from_angle(ca) * (croc_r - 15.0)
			var c_outer = Vector2.from_angle(ca) * (croc_r + 5.0)
			draw_line(c_inner, c_outer, Color(0.95, 0.95, 0.8, _croc_flash * 0.5), 2.0)

	# === Base — Neverland forest floor ===
	# Outer mossy ring
	draw_circle(Vector2.ZERO, 64.0, Color(0.08, 0.18, 0.06))
	draw_arc(Vector2.ZERO, 64.0, 0, TAU, 48, Color(0.12, 0.28, 0.08), 2.0)
	draw_circle(Vector2.ZERO, 60.0, Color(0.15, 0.32, 0.10))
	# Earthy brown undertone
	draw_circle(Vector2.ZERO, 56.0, Color(0.18, 0.30, 0.12))
	# Mossy patches with varied greens
	for i in range(10):
		var a = TAU * float(i) / 10.0 + 0.3
		var p = Vector2.from_angle(a) * (42.0 + sin(float(i) * 1.7) * 8.0)
		var moss_r = 7.0 + sin(float(i) * 2.3) * 3.0
		draw_circle(p, moss_r, Color(0.12 + sin(float(i)) * 0.04, 0.35 + cos(float(i)) * 0.06, 0.10, 0.5))
	draw_circle(Vector2.ZERO, 44.0, Color(0.20, 0.36, 0.14))
	# Tiny mushrooms on base
	for i in range(4):
		var fa = TAU * float(i) / 4.0 + 0.8
		var fp = Vector2.from_angle(fa) * 52.0
		# Mushroom stem
		draw_line(fp, fp + Vector2(0, -6.0), Color(0.85, 0.80, 0.65), 1.5)
		# Mushroom cap (red with white spots)
		draw_circle(fp + Vector2(0, -6.5), 3.5, Color(0.75, 0.15, 0.10))
		draw_circle(fp + Vector2(0, -7.0), 1.8, Color(0.75, 0.18, 0.12))
		draw_circle(fp + Vector2(-1.0, -7.2), 0.8, Color(1.0, 1.0, 0.9, 0.7))
		draw_circle(fp + Vector2(1.2, -6.5), 0.6, Color(1.0, 1.0, 0.9, 0.5))
	# Small fern fronds
	for i in range(6):
		var fa2 = TAU * float(i) / 6.0 + 0.2
		var fp2 = Vector2.from_angle(fa2) * 48.0
		var fern_dir = Vector2.from_angle(fa2 + PI * 0.5)
		draw_line(fp2, fp2 + fern_dir * 8.0 + Vector2(0, -3.0), Color(0.14, 0.40, 0.12), 1.2)
		# Fern leaflets
		for fl in range(3):
			var frac = float(fl + 1) / 4.0
			var fern_pt = fp2 + fern_dir * 8.0 * frac + Vector2(0, -3.0 * frac)
			draw_line(fern_pt, fern_pt + Vector2(2.0, -2.0), Color(0.16, 0.42, 0.14, 0.7), 0.8)
			draw_line(fern_pt, fern_pt + Vector2(-2.0, -2.0), Color(0.16, 0.42, 0.14, 0.7), 0.8)
	# Tiny flowers (pixie blooms)
	for i in range(3):
		var fl_a = TAU * float(i) / 3.0 + 1.5
		var fl_p = Vector2.from_angle(fl_a) * 55.0
		draw_circle(fl_p, 2.0, Color(0.9, 0.75, 0.2, 0.6))
		for petal in range(5):
			var pa = TAU * float(petal) / 5.0
			draw_circle(fl_p + Vector2.from_angle(pa) * 2.2, 1.2, Color(1.0, 0.85, 0.95, 0.5))

	# Tier pips
	for i in range(upgrade_tier):
		var pip_angle = -PI / 2.0 + float(i) * (TAU / 4.0) - (float(upgrade_tier - 1) * TAU / 8.0)
		var pip_pos = Vector2.from_angle(pip_angle) * 56.0
		var pip_col: Color
		match i:
			0: pip_col = Color(0.4, 0.4, 0.5)
			1: pip_col = Color(0.6, 0.85, 0.3)
			2: pip_col = Color(0.3, 0.75, 0.4)
			3: pip_col = Color(0.4, 1.0, 0.5)
		draw_circle(pip_pos, 6.0, pip_col)
		# Pip glow
		draw_circle(pip_pos, 8.0, Color(pip_col.r, pip_col.g, pip_col.b, 0.15))

	# === Ground shadow under feet ===
	var ground_shadow_pos = body_offset - dir * 22.0
	draw_circle(ground_shadow_pos, 18.0, Color(0.05, 0.08, 0.03, 0.25))
	draw_circle(ground_shadow_pos, 12.0, Color(0.05, 0.08, 0.03, 0.15))

	# === Tier 4: Fairy dust particles everywhere ===
	if upgrade_tier >= 4:
		for fd in range(14):
			var fd_seed = float(fd) * 2.37
			var fd_angle = _time * (0.4 + fmod(fd_seed, 0.6)) + fd_seed
			var fd_radius = 30.0 + fmod(fd_seed * 7.3, 40.0)
			var fd_y_off = sin(_time * 1.5 + fd_seed) * 15.0
			var fd_pos = body_offset + Vector2(cos(fd_angle) * fd_radius, sin(fd_angle) * fd_radius * 0.6 + fd_y_off)
			var fd_alpha = 0.3 + sin(_time * 3.0 + fd_seed * 2.0) * 0.2
			var fd_size = 1.5 + sin(_time * 2.5 + fd_seed) * 0.8
			draw_circle(fd_pos, fd_size, Color(1.0, 0.92, 0.4, fd_alpha))
			# Tiny cross sparkle
			draw_line(fd_pos - Vector2(fd_size + 1.0, 0), fd_pos + Vector2(fd_size + 1.0, 0), Color(1.0, 1.0, 0.8, fd_alpha * 0.5), 0.6)
			draw_line(fd_pos - Vector2(0, fd_size + 1.0), fd_pos + Vector2(0, fd_size + 1.0), Color(1.0, 1.0, 0.8, fd_alpha * 0.5), 0.6)

	# === Tier 3+: Crocodile lurking below ===
	if upgrade_tier >= 3:
		var croc_pos = -dir * 44.0 + body_offset * 0.3
		var jaw_angle = sin(_time * 2.0) * 0.35
		# Body with scale texture
		draw_circle(croc_pos, 17.0, Color(0.22, 0.42, 0.15))
		draw_circle(croc_pos, 14.0, Color(0.28, 0.48, 0.20))
		# Belly lighter patch
		draw_circle(croc_pos - dir * 2.0, 10.0, Color(0.45, 0.58, 0.32))
		# Scale pattern on back
		for sx in range(7):
			var sp_x = croc_pos - dir * (float(sx) * 5.0 - 10.0)
			for sy_i in range(2):
				var sp_offset = perp * (float(sy_i) * 4.0 - 2.0)
				var scale_pos = sp_x + sp_offset
				draw_arc(scale_pos, 2.8, aim_angle + PI * 0.2, aim_angle + PI * 0.8, 4, Color(0.20, 0.36, 0.12, 0.6), 0.8)
		# Bumpy scutes along spine
		for b in range(6):
			var bp = croc_pos - dir * (float(b) * 5.0 - 8.0)
			draw_circle(bp, 3.0, Color(0.20, 0.38, 0.13))
			draw_circle(bp, 1.5, Color(0.18, 0.34, 0.10))
		# Snout (tapered)
		draw_line(croc_pos + dir * 16.0, croc_pos + dir * 34.0, Color(0.26, 0.48, 0.18), 9.0)
		draw_line(croc_pos + dir * 16.0, croc_pos + dir * 34.0, Color(0.30, 0.52, 0.22), 6.0)
		# Snout nostrils
		draw_circle(croc_pos + dir * 33.0 + perp * 2.5, 1.2, Color(0.12, 0.20, 0.08))
		draw_circle(croc_pos + dir * 33.0 - perp * 2.5, 1.2, Color(0.12, 0.20, 0.08))
		# Upper jaw
		var jaw_up = Vector2(0, -jaw_angle * 9.0)
		draw_line(croc_pos + dir * 34.0, croc_pos + dir * 27.0 + perp * 10.0 + jaw_up, Color(0.22, 0.42, 0.16), 4.5)
		draw_line(croc_pos + dir * 34.0, croc_pos + dir * 27.0 - perp * 10.0 + jaw_up, Color(0.22, 0.42, 0.16), 4.5)
		# Lower jaw
		var jaw_dn = Vector2(0, jaw_angle * 9.0)
		draw_line(croc_pos + dir * 34.0, croc_pos + dir * 27.0 + perp * 9.0 + jaw_dn, Color(0.20, 0.38, 0.14), 3.5)
		draw_line(croc_pos + dir * 34.0, croc_pos + dir * 27.0 - perp * 9.0 + jaw_dn, Color(0.20, 0.38, 0.14), 3.5)
		# Eyes with slit pupils
		var croc_eye_r = croc_pos + dir * 10.0 + perp * 8.0
		var croc_eye_l = croc_pos + dir * 10.0 - perp * 8.0
		draw_circle(croc_eye_r, 4.0, Color(0.92, 0.82, 0.08))
		draw_circle(croc_eye_r, 2.8, Color(0.85, 0.75, 0.05))
		# Vertical slit pupil
		draw_line(croc_eye_r - dir * 2.5, croc_eye_r + dir * 2.5, Color(0.08, 0.08, 0.04), 1.5)
		draw_circle(croc_eye_l, 4.0, Color(0.92, 0.82, 0.08))
		draw_circle(croc_eye_l, 2.8, Color(0.85, 0.75, 0.05))
		draw_line(croc_eye_l - dir * 2.5, croc_eye_l + dir * 2.5, Color(0.08, 0.08, 0.04), 1.5)
		# Teeth (upper) — sharper triangles
		for t in range(5):
			var tp = croc_pos + dir * (24.0 + float(t) * 2.2)
			draw_line(tp + perp * 6.5 + jaw_up, tp + perp * 11.0 + jaw_up, Color(0.98, 0.96, 0.88), 1.8)
			draw_line(tp - perp * 6.5 + jaw_up, tp - perp * 11.0 + jaw_up, Color(0.98, 0.96, 0.88), 1.8)
		# Teeth (lower)
		for t in range(4):
			var tp = croc_pos + dir * (25.0 + float(t) * 2.2)
			draw_line(tp + perp * 5.5 + jaw_dn, tp + perp * 10.0 + jaw_dn, Color(0.94, 0.94, 0.84), 1.4)
			draw_line(tp - perp * 5.5 + jaw_dn, tp - perp * 10.0 + jaw_dn, Color(0.94, 0.94, 0.84), 1.4)
		# Tail (wavy, segmented)
		var tail_sway = sin(_time * 1.8) * 7.0
		draw_line(croc_pos - dir * 14.0, croc_pos - dir * 28.0 + perp * (9.0 + tail_sway), Color(0.25, 0.45, 0.18), 6.0)
		draw_line(croc_pos - dir * 28.0 + perp * (9.0 + tail_sway), croc_pos - dir * 38.0 + perp * (3.0 - tail_sway), Color(0.23, 0.42, 0.16), 4.0)
		draw_line(croc_pos - dir * 38.0 + perp * (3.0 - tail_sway), croc_pos - dir * 44.0 + perp * (-1.0 + tail_sway * 0.5), Color(0.20, 0.38, 0.14), 2.5)
		# Tick-tock clock symbol on belly (the swallowed clock!)
		var clock_pos = croc_pos - dir * 1.0
		draw_arc(clock_pos, 5.0, 0, TAU, 12, Color(0.70, 0.60, 0.20, 0.4), 0.8)
		# Clock hands
		var clock_h = _time * 0.5
		draw_line(clock_pos, clock_pos + Vector2.from_angle(clock_h) * 3.0, Color(0.70, 0.60, 0.20, 0.5), 0.8)
		draw_line(clock_pos, clock_pos + Vector2.from_angle(clock_h * 3.0) * 4.0, Color(0.70, 0.60, 0.20, 0.5), 0.6)

	# === Tier 1+: Peter's detached shadow ===
	if upgrade_tier >= 1:
		var shadow_lag = perp * sin(_time * 1.5 - 0.5) * 7.0
		var shadow_drift = dir * cos(_time * 0.9) * 4.0
		var shadow_offset = -dir * 9.0 + perp * 7.0 + shadow_lag + shadow_drift + body_offset
		var shadow_alpha: float = 0.25 + 0.1 * float(min(upgrade_tier, 4))
		var shadow_thickness: float = 1.5 + 0.75 * float(min(upgrade_tier, 4))
		var sc = Color(0.04, 0.04, 0.08, shadow_alpha)
		var sc_light = Color(0.04, 0.04, 0.08, shadow_alpha - 0.06)
		var sc_edge = Color(0.04, 0.04, 0.08, shadow_alpha - 0.12)
		# Wavy edge offset for unstable shadow
		var wave1 = sin(_time * 3.0) * 2.5
		var wave2 = cos(_time * 2.5 + 1.0) * 2.5
		var wave3 = sin(_time * 4.0 + 2.0) * 2.0
		var wave4 = cos(_time * 3.5 + 0.5) * 1.5
		# Shadow silhouette torso — ghostly shifting shape
		var s_body = PackedVector2Array([
			shadow_offset - dir * 17.0 - perp * (19.0 + wave1),
			shadow_offset - dir * 17.0 + perp * (19.0 + wave2),
			shadow_offset + dir * 10.0 + perp * (16.0 + wave3),
			shadow_offset + dir * 10.0 - perp * (16.0 + wave4),
		])
		draw_colored_polygon(s_body, sc)
		# Wispy tendrils at shadow edges
		for wi in range(5):
			var w_t = float(wi) / 4.0
			var w_base = shadow_offset - dir * 17.0 + perp * (-19.0 + w_t * 38.0)
			var w_tip = w_base - dir * (6.0 + sin(_time * 2.5 + float(wi)) * 3.0)
			draw_line(w_base, w_tip, Color(0.04, 0.04, 0.08, shadow_alpha * 0.4), 1.5)
		# Shadow head
		draw_circle(shadow_offset + dir * 21.0, 14.5, sc_light)
		# Shadow hat silhouette
		var s_hat_base = shadow_offset + dir * 30.0
		var s_hat_pts = PackedVector2Array([
			s_hat_base - perp * (12.0 + wave2 * 0.5),
			s_hat_base + perp * (12.0 + wave1 * 0.5),
			s_hat_base + dir * 10.0 + perp * (18.0 + wave3),
		])
		draw_colored_polygon(s_hat_pts, sc_light)
		# Shadow arms (wispy, slightly misaligned from Peter)
		draw_line(shadow_offset + perp * 19.0 + dir * 4.0, shadow_offset + dir * 32.0 + perp * (5.0 + wave1), sc_edge, shadow_thickness)
		draw_line(shadow_offset - perp * 19.0 + dir * 4.0, shadow_offset - perp * (14.0 + wave2) - dir * 8.0, sc_edge, shadow_thickness)
		# Shadow reaching out (mischievous — sometimes reaches differently)
		var reach = sin(_time * 0.7) * 5.0
		draw_line(shadow_offset + dir * 32.0 + perp * (5.0 + wave1), shadow_offset + dir * (40.0 + reach) + perp * (3.0 + wave3), sc_edge, shadow_thickness * 0.7)
		# Shadow legs
		draw_line(shadow_offset - dir * 17.0 - perp * (9.0 + wave3 * 0.5), shadow_offset - dir * 27.0 - perp * (11.0 + wave1), sc_edge, shadow_thickness)
		draw_line(shadow_offset - dir * 17.0 + perp * (9.0 + wave2 * 0.5), shadow_offset - dir * 27.0 + perp * (11.0 + wave3), sc_edge, shadow_thickness)
		# Shadow feet silhouettes
		draw_circle(shadow_offset - dir * 27.0 - perp * (11.0 + wave1), 5.5, Color(0.04, 0.04, 0.08, shadow_alpha - 0.15))
		draw_circle(shadow_offset - dir * 27.0 + perp * (11.0 + wave3), 5.5, Color(0.04, 0.04, 0.08, shadow_alpha - 0.15))
		# Shadow dagger silhouette
		draw_line(shadow_offset + dir * 32.0 + perp * 5.0, shadow_offset + dir * 48.0 + perp * (3.0 + wave2), Color(0.04, 0.04, 0.08, shadow_alpha - 0.10), shadow_thickness * 0.8)

	# === Green leaf tunic with overlapping leaf textures ===
	var tunic_center = body_offset
	# Main tunic shape with jagged leaf-cut bottom
	var tunic_top_left = tunic_center + dir * 9.0 - perp * 18.0
	var tunic_top_right = tunic_center + dir * 9.0 + perp * 18.0
	var jagged_bottom: PackedVector2Array = PackedVector2Array()
	jagged_bottom.append(tunic_top_left)
	var jag_count = 12
	for i in range(jag_count + 1):
		var t_val = float(i) / float(jag_count)
		var base_pos = tunic_center - dir * 18.0 + perp * (-22.0 + t_val * 44.0)
		var jag_depth = 0.0
		if i % 2 == 0:
			jag_depth = 7.0 + sin(float(i) * 2.3 + _time * 1.2) * 3.0
		jagged_bottom.append(base_pos - dir * jag_depth)
	jagged_bottom.append(tunic_top_right)
	# Base green tunic
	draw_colored_polygon(jagged_bottom, Color(0.20, 0.52, 0.14))
	# Lighter inner tunic
	var tunic_hi_pts = PackedVector2Array([
		tunic_center - dir * 10.0 - perp * 10.0,
		tunic_center - dir * 10.0 + perp * 10.0,
		tunic_center + dir * 6.0 + perp * 8.0,
		tunic_center + dir * 6.0 - perp * 8.0,
	])
	draw_colored_polygon(tunic_hi_pts, Color(0.26, 0.60, 0.20, 0.35))

	# Overlapping leaf shapes on tunic (skeleton leaf suit)
	for row in range(3):
		for col in range(4):
			var leaf_x = -12.0 + float(row) * 9.0 + float(col % 2) * 4.5
			var leaf_y = -16.0 + float(col) * 8.5
			var leaf_pos = tunic_center + dir * leaf_x + perp * leaf_y
			var leaf_size = 6.0 + sin(float(row + col) * 1.7) * 1.5
			var leaf_ang = aim_angle + float(row - col) * 0.3
			var leaf_d = Vector2.from_angle(leaf_ang)
			var leaf_p = leaf_d.rotated(PI / 2.0)
			# Leaf shape: pointed oval
			var lf_pts = PackedVector2Array([
				leaf_pos - leaf_d * leaf_size,
				leaf_pos + leaf_p * leaf_size * 0.45,
				leaf_pos + leaf_d * leaf_size,
				leaf_pos - leaf_p * leaf_size * 0.45,
			])
			var lf_green = 0.48 + sin(float(row * 4 + col) * 1.3) * 0.08
			draw_colored_polygon(lf_pts, Color(0.18, lf_green, 0.12, 0.6))
			# Leaf center vein
			draw_line(leaf_pos - leaf_d * (leaf_size * 0.8), leaf_pos + leaf_d * (leaf_size * 0.8), Color(0.14, 0.36, 0.08, 0.5), 0.7)
			# Side veins
			for v in range(2):
				var vf = float(v + 1) / 3.0
				var v_origin = leaf_pos + leaf_d * (leaf_size * (vf - 0.5) * 2.0)
				draw_line(v_origin, v_origin + leaf_p * leaf_size * 0.3, Color(0.14, 0.36, 0.08, 0.35), 0.5)
				draw_line(v_origin, v_origin - leaf_p * leaf_size * 0.3, Color(0.14, 0.36, 0.08, 0.35), 0.5)

	# Fabric fold shadows on tunic
	draw_line(tunic_center + dir * 2.0 - perp * 14.0, tunic_center - dir * 12.0 - perp * 12.0, Color(0.12, 0.36, 0.08, 0.5), 1.5)
	draw_line(tunic_center + dir * 2.0 + perp * 14.0, tunic_center - dir * 12.0 + perp * 12.0, Color(0.12, 0.36, 0.08, 0.5), 1.5)
	draw_line(tunic_center - dir * 5.0 - perp * 4.0, tunic_center - dir * 16.0 - perp * 6.0, Color(0.12, 0.36, 0.08, 0.4), 1.2)
	draw_line(tunic_center - dir * 5.0 + perp * 4.0, tunic_center - dir * 16.0 + perp * 6.0, Color(0.12, 0.36, 0.08, 0.4), 1.2)

	# Cobweb detail across tunic (spider silk threads — from the novel)
	var web_col = Color(0.85, 0.88, 0.92, 0.12)
	draw_line(tunic_center + dir * 7.0 - perp * 16.0, tunic_center - dir * 8.0 + perp * 12.0, web_col, 0.5)
	draw_line(tunic_center + dir * 5.0 + perp * 15.0, tunic_center - dir * 10.0 - perp * 8.0, web_col, 0.5)
	draw_line(tunic_center + dir * 0.0 - perp * 14.0, tunic_center - dir * 14.0 + perp * 6.0, web_col, 0.4)
	# Web intersection nodes
	var web_node = tunic_center - dir * 2.0 + perp * 2.0
	draw_circle(web_node, 1.0, Color(0.85, 0.88, 0.92, 0.15))

	# Side ragged edges (leaf-cut triangles)
	for i in range(6):
		var sy = tunic_center + dir * (-14.0 + float(i) * 5.0) + perp * 20.0
		var zig2 = sin(float(i) * 2.2 + _time * 1.2) * 2.0
		draw_line(sy, sy + perp * (5.0 + zig2) - dir * 3.0, Color(0.18, 0.48, 0.12), 2.0)
		draw_line(sy + perp * (5.0 + zig2) - dir * 3.0, sy + perp * 1.0 + dir * 2.5, Color(0.16, 0.44, 0.10), 1.5)
		var sy2 = tunic_center + dir * (-14.0 + float(i) * 5.0) - perp * 20.0
		draw_line(sy2, sy2 - perp * (5.0 + zig2) - dir * 3.0, Color(0.18, 0.48, 0.12), 2.0)
		draw_line(sy2 - perp * (5.0 + zig2) - dir * 3.0, sy2 - perp * 1.0 + dir * 2.5, Color(0.16, 0.44, 0.10), 1.5)

	# === Vine belt with leaf buckle ===
	var belt_y = tunic_center - dir * 1.5
	# Twisted vine belt (dual-color intertwined)
	draw_line(belt_y - perp * 22.0, belt_y + perp * 22.0, Color(0.22, 0.38, 0.10), 6.0)
	draw_line(belt_y - perp * 22.0, belt_y + perp * 22.0, Color(0.30, 0.48, 0.15), 4.0)
	# Vine twist pattern (alternating bumps)
	for vi in range(9):
		var vt = float(vi) / 8.0
		var vine_pt = belt_y + perp * (-20.0 + vt * 40.0)
		var vine_bulge = sin(float(vi) * PI + _time * 2.0) * 1.5
		draw_circle(vine_pt + dir * vine_bulge, 3.2, Color(0.26, 0.44, 0.12))
		# Tiny vine tendrils curling off
		if vi % 3 == 0:
			var tendril_end = vine_pt + dir * (5.0 + vine_bulge) + perp * 2.0
			draw_line(vine_pt, tendril_end, Color(0.20, 0.40, 0.10, 0.5), 0.8)
			draw_arc(tendril_end, 2.0, aim_angle, aim_angle + PI, 4, Color(0.20, 0.40, 0.10, 0.4), 0.6)
	# Leaf-shaped buckle
	var buckle_c = belt_y
	var buckle_d = dir
	var buckle_p = perp
	var buckle_pts = PackedVector2Array([
		buckle_c - buckle_d * 4.0,
		buckle_c + buckle_p * 5.0,
		buckle_c + buckle_d * 7.0,
		buckle_c - buckle_p * 5.0,
	])
	draw_colored_polygon(buckle_pts, Color(0.35, 0.60, 0.20))
	draw_colored_polygon(buckle_pts, Color(0.40, 0.65, 0.25, 0.5))
	# Buckle leaf veins
	draw_line(buckle_c - buckle_d * 3.0, buckle_c + buckle_d * 6.0, Color(0.25, 0.48, 0.14), 0.8)
	draw_line(buckle_c, buckle_c + buckle_p * 3.5 + buckle_d * 2.0, Color(0.25, 0.48, 0.14, 0.6), 0.6)
	draw_line(buckle_c, buckle_c - buckle_p * 3.5 + buckle_d * 2.0, Color(0.25, 0.48, 0.14, 0.6), 0.6)
	# Belt pouch (fairy dust pouch — golden tinted)
	var pouch_pos = belt_y + perp * 14.0 - dir * 3.0
	var pouch_pts = PackedVector2Array([
		pouch_pos - perp * 4.0 + dir * 1.0,
		pouch_pos + perp * 4.0 + dir * 1.0,
		pouch_pos + perp * 4.5 - dir * 7.0,
		pouch_pos - perp * 4.5 - dir * 7.0,
	])
	draw_colored_polygon(pouch_pts, Color(0.42, 0.30, 0.12))
	var pouch_flap = PackedVector2Array([
		pouch_pos - perp * 4.5 + dir * 1.0,
		pouch_pos + perp * 4.5 + dir * 1.0,
		pouch_pos + perp * 3.5 - dir * 2.0,
		pouch_pos - perp * 3.5 - dir * 2.0,
	])
	draw_colored_polygon(pouch_flap, Color(0.48, 0.34, 0.16))
	# Fairy dust spilling from pouch (golden specks)
	if upgrade_tier >= 2:
		for sp_i in range(3):
			var sp_off = pouch_pos - dir * (8.0 + float(sp_i) * 3.0) + perp * sin(_time * 3.0 + float(sp_i)) * 2.0
			draw_circle(sp_off, 1.0, Color(1.0, 0.9, 0.3, 0.4 - float(sp_i) * 0.1))
	draw_circle(pouch_pos - dir * 0.5, 1.2, Color(0.55, 0.40, 0.18))
	# Dagger sheath
	var sheath_pos = belt_y - perp * 13.0 - dir * 2.0
	var sheath_pts = PackedVector2Array([
		sheath_pos - perp * 2.5 + dir * 2.0,
		sheath_pos + perp * 2.5 + dir * 2.0,
		sheath_pos + perp * 1.5 - dir * 14.0,
		sheath_pos - perp * 1.5 - dir * 14.0,
	])
	draw_colored_polygon(sheath_pts, Color(0.35, 0.22, 0.08))
	draw_circle(sheath_pos - dir * 13.5, 2.0, Color(0.50, 0.38, 0.18))
	draw_line(sheath_pos - perp * 3.0, sheath_pos + perp * 3.0, Color(0.30, 0.18, 0.06), 1.5)
	draw_line(sheath_pos - perp * 2.5 - dir * 6.0, sheath_pos + perp * 2.5 - dir * 6.0, Color(0.30, 0.18, 0.06), 1.2)

	# === Shoulders with leaf pauldrons ===
	# Right shoulder
	draw_circle(tunic_center + perp * 21.0 + dir * 3.0, 10.0, Color(0.16, 0.44, 0.11))
	draw_circle(tunic_center + perp * 21.0 + dir * 3.0, 8.0, Color(0.22, 0.52, 0.16))
	# Leaf overlay on right shoulder
	var r_sh = tunic_center + perp * 21.0 + dir * 3.0
	draw_line(r_sh - dir * 4.0, r_sh + dir * 6.0, Color(0.14, 0.38, 0.09, 0.5), 0.7)
	draw_line(r_sh, r_sh + perp * 4.0 + dir * 2.0, Color(0.14, 0.38, 0.09, 0.4), 0.5)
	draw_line(r_sh, r_sh - perp * 4.0 + dir * 2.0, Color(0.14, 0.38, 0.09, 0.4), 0.5)
	# Left shoulder
	draw_circle(tunic_center - perp * 21.0 + dir * 3.0, 10.0, Color(0.16, 0.44, 0.11))
	draw_circle(tunic_center - perp * 21.0 + dir * 3.0, 8.0, Color(0.22, 0.52, 0.16))
	var l_sh = tunic_center - perp * 21.0 + dir * 3.0
	draw_line(l_sh - dir * 4.0, l_sh + dir * 6.0, Color(0.14, 0.38, 0.09, 0.5), 0.7)
	draw_line(l_sh, l_sh + perp * 4.0 + dir * 2.0, Color(0.14, 0.38, 0.09, 0.4), 0.5)
	draw_line(l_sh, l_sh - perp * 4.0 + dir * 2.0, Color(0.14, 0.38, 0.09, 0.4), 0.5)

	# === Arms ===
	# Dagger hand — swipe with lunge
	var dagger_hand: Vector2
	if _attack_anim > 0.0:
		var swipe_angle = _attack_anim * PI * 0.6
		var swipe_dir = dir.rotated(-swipe_angle + PI * 0.3)
		var lunge = dir * _attack_anim * 5.0
		dagger_hand = tunic_center + swipe_dir * 36.0 + perp * 3.0 + lunge
	else:
		dagger_hand = tunic_center + dir * 36.0 + perp * 3.0
	var r_shoulder = tunic_center + perp * 21.0 + dir * 3.0
	# Upper arm
	draw_line(r_shoulder, dagger_hand, skin_shadow, 6.5)
	draw_line(r_shoulder, dagger_hand, skin_base, 5.0)
	# Elbow joint
	var r_elbow = r_shoulder + (dagger_hand - r_shoulder) * 0.5
	draw_circle(r_elbow, 4.5, skin_base)
	draw_circle(r_elbow, 3.0, skin_highlight)
	# Hand
	draw_circle(dagger_hand, 6.0, skin_shadow)
	draw_circle(dagger_hand, 5.0, skin_base)
	# Fingers gripping
	var grip_dir: Vector2
	if _attack_anim > 0.0:
		grip_dir = dir.rotated(-_attack_anim * PI * 0.6 + PI * 0.3)
	else:
		grip_dir = dir
	for fi in range(4):
		var fang = float(fi - 1.5) * 0.35
		var finger_pos = dagger_hand + grip_dir.rotated(fang) * 5.5
		draw_circle(finger_pos, 2.0, skin_highlight)
		# Knuckle detail
		draw_circle(finger_pos, 1.2, Color(0.94, 0.80, 0.66, 0.4))

	# Off-hand (akimbo / on hip)
	var off_hand = tunic_center - perp * 15.0 - dir * 6.0
	var l_shoulder = tunic_center - perp * 21.0 + dir * 3.0
	draw_line(l_shoulder, off_hand, skin_shadow, 6.5)
	draw_line(l_shoulder, off_hand, skin_base, 5.0)
	var l_elbow = l_shoulder + (off_hand - l_shoulder) * 0.5
	draw_circle(l_elbow, 4.0, skin_base)
	draw_circle(l_elbow, 2.5, skin_highlight)
	draw_circle(off_hand, 5.0, skin_shadow)
	draw_circle(off_hand, 4.0, skin_base)
	# Fingers on hip
	for fi2 in range(3):
		var f_off = off_hand - dir * (2.0 + float(fi2) * 2.5) + perp * 1.0
		draw_circle(f_off, 1.5, skin_highlight)

	# === Ornate dagger ===
	var dagger_dir: Vector2
	if _attack_anim > 0.0:
		var swipe_angle2 = _attack_anim * PI * 0.6
		dagger_dir = dir.rotated(-swipe_angle2 + PI * 0.3)
	else:
		dagger_dir = dir
	var dagger_perp = dagger_dir.rotated(PI / 2.0)
	# Handle (leather wrapped with green vine accent)
	draw_line(dagger_hand, dagger_hand + dagger_dir * 12.0, Color(0.32, 0.22, 0.10), 5.0)
	draw_line(dagger_hand, dagger_hand + dagger_dir * 12.0, Color(0.40, 0.28, 0.14), 3.5)
	# Handle leather wrapping
	for wi in range(4):
		var wp = dagger_hand + dagger_dir * (2.5 + float(wi) * 2.8)
		draw_line(wp - dagger_perp * 2.5, wp + dagger_perp * 2.5, Color(0.52, 0.40, 0.20), 1.0)
	# Vine wrap on handle
	for vi2 in range(3):
		var vp = dagger_hand + dagger_dir * (1.5 + float(vi2) * 3.5)
		draw_circle(vp + dagger_perp * 2.2, 1.0, Color(0.22, 0.45, 0.15, 0.6))
	# Pommel (acorn-shaped)
	draw_circle(dagger_hand - dagger_dir * 1.0, 3.5, Color(0.50, 0.38, 0.18))
	draw_circle(dagger_hand - dagger_dir * 1.0, 2.2, Color(0.58, 0.45, 0.22))
	# Pommel cap
	draw_arc(dagger_hand - dagger_dir * 1.0, 3.0, aim_angle + PI * 0.3, aim_angle + PI * 0.7, 4, Color(0.42, 0.32, 0.14), 1.5)
	# Cross-guard (ornate leaf-shaped)
	var guard_c = dagger_hand + dagger_dir * 12.0
	draw_line(guard_c + dagger_perp * 9.0, guard_c - dagger_perp * 9.0, Color(0.55, 0.45, 0.18), 4.0)
	draw_line(guard_c + dagger_perp * 9.0, guard_c - dagger_perp * 9.0, Color(0.62, 0.52, 0.22), 2.5)
	# Guard leaf tips
	var guard_tip_r = guard_c + dagger_perp * 9.0 + dagger_dir * 2.0
	var guard_tip_l = guard_c - dagger_perp * 9.0 + dagger_dir * 2.0
	draw_line(guard_c + dagger_perp * 8.0, guard_tip_r, Color(0.60, 0.50, 0.20), 2.0)
	draw_line(guard_c - dagger_perp * 8.0, guard_tip_l, Color(0.60, 0.50, 0.20), 2.0)
	# Guard gem (tiny emerald)
	draw_circle(guard_c, 2.0, Color(0.15, 0.55, 0.25))
	draw_circle(guard_c + dagger_dir * 0.3 + dagger_perp * 0.3, 1.0, Color(0.3, 0.75, 0.4, 0.7))
	# Blade (wider, curved like a fairy dagger)
	var blade_base = guard_c
	var blade_tip = dagger_hand + dagger_dir * 35.0
	# Blade body with slight curve
	var blade_mid = blade_base + (blade_tip - blade_base) * 0.5 + dagger_perp * 1.5
	draw_line(blade_base + dagger_perp * 3.0, blade_mid + dagger_perp * 2.0, Color(0.70, 0.73, 0.78), 2.5)
	draw_line(blade_mid + dagger_perp * 2.0, blade_tip, Color(0.70, 0.73, 0.78), 1.5)
	draw_line(blade_base - dagger_perp * 3.0, blade_mid - dagger_perp * 0.5, Color(0.70, 0.73, 0.78), 2.5)
	draw_line(blade_mid - dagger_perp * 0.5, blade_tip, Color(0.70, 0.73, 0.78), 1.5)
	# Blade fill (center)
	draw_line(blade_base, blade_tip, Color(0.78, 0.80, 0.85), 3.5)
	# Blade edge highlight
	draw_line(blade_base + dagger_perp * 1.5, blade_tip, Color(0.88, 0.90, 0.95, 0.6), 1.0)
	# Blade spine
	draw_line(blade_base, blade_tip, Color(0.65, 0.68, 0.72, 0.5), 0.8)
	# Blade shine
	draw_line(dagger_hand + dagger_dir * 16.0 + dagger_perp * 1.0, dagger_hand + dagger_dir * 30.0 + dagger_perp * 0.5, Color(0.95, 0.96, 1.0, 0.6), 1.2)
	# Attack glint — bright flash when attacking
	if _attack_anim > 0.5:
		var glint_alpha = (_attack_anim - 0.5) * 2.0
		draw_circle(blade_tip, 4.0 + glint_alpha * 3.0, Color(1.0, 1.0, 0.95, glint_alpha * 0.6))
		draw_line(blade_tip - dagger_perp * (6.0 * glint_alpha), blade_tip + dagger_perp * (6.0 * glint_alpha), Color(1.0, 1.0, 0.9, glint_alpha * 0.4), 1.0)
		draw_line(blade_tip - dagger_dir * (4.0 * glint_alpha), blade_tip + dagger_dir * (2.0 * glint_alpha), Color(1.0, 1.0, 0.9, glint_alpha * 0.3), 1.0)

	# === Leaf-wrapped moccasin boots ===
	var left_foot = tunic_center - dir * 21.0 - perp * 10.5
	var right_foot = tunic_center - dir * 21.0 + perp * 10.5
	# Legs (slightly visible below tunic)
	draw_line(tunic_center - dir * 16.0 - perp * 10.0, left_foot, skin_shadow, 5.5)
	draw_line(tunic_center - dir * 16.0 - perp * 10.0, left_foot, skin_base, 4.0)
	draw_line(tunic_center - dir * 16.0 + perp * 10.0, right_foot, skin_shadow, 5.5)
	draw_line(tunic_center - dir * 16.0 + perp * 10.0, right_foot, skin_base, 4.0)
	# Moccasin base shapes (brown leather)
	draw_circle(left_foot, 8.0, Color(0.38, 0.26, 0.12))
	draw_circle(left_foot, 6.5, Color(0.45, 0.32, 0.16))
	draw_circle(right_foot, 8.0, Color(0.38, 0.26, 0.12))
	draw_circle(right_foot, 6.5, Color(0.45, 0.32, 0.16))
	# Moccasin front extension (pointed toe area)
	var l_toe_tip = left_foot - dir * 7.0
	var r_toe_tip = right_foot - dir * 7.0
	draw_line(left_foot, l_toe_tip, Color(0.42, 0.30, 0.14), 6.0)
	draw_line(right_foot, r_toe_tip, Color(0.42, 0.30, 0.14), 6.0)
	draw_circle(l_toe_tip, 3.5, Color(0.45, 0.32, 0.16))
	draw_circle(r_toe_tip, 3.5, Color(0.45, 0.32, 0.16))
	# Leaf wrapping on moccasins
	for boot_i in range(2):
		var boot_pos = left_foot if boot_i == 0 else right_foot
		# Overlapping leaf pieces
		for bl in range(3):
			var bl_a = aim_angle + PI + float(bl) * 0.8 - 0.8
			var bl_pos = boot_pos + Vector2.from_angle(bl_a) * 5.0
			var bl_d = Vector2.from_angle(bl_a)
			var bl_p = bl_d.rotated(PI / 2.0)
			var bl_pts = PackedVector2Array([
				bl_pos - bl_d * 4.0,
				bl_pos + bl_p * 2.5,
				bl_pos + bl_d * 4.0,
				bl_pos - bl_p * 2.5,
			])
			draw_colored_polygon(bl_pts, Color(0.20, 0.46, 0.14, 0.7))
			draw_line(bl_pos - bl_d * 3.0, bl_pos + bl_d * 3.0, Color(0.15, 0.36, 0.10, 0.5), 0.5)
	# Vine laces crisscrossing
	for boot_i2 in range(2):
		var boot_pos2 = left_foot if boot_i2 == 0 else right_foot
		var ankle = tunic_center - dir * 17.0 + perp * (-10.5 if boot_i2 == 0 else 10.5)
		# Criss-cross laces
		for lace_i in range(3):
			var lf = float(lace_i + 1) / 4.0
			var lace_pt = boot_pos2 + (ankle - boot_pos2) * lf
			draw_line(lace_pt - perp * 3.5, lace_pt + perp * 3.5 - dir * 1.5, Color(0.22, 0.42, 0.12, 0.6), 0.8)
			draw_line(lace_pt + perp * 3.5, lace_pt - perp * 3.5 - dir * 1.5, Color(0.22, 0.42, 0.12, 0.6), 0.8)
	# Ankle cuff (leaf trim)
	for boot_i3 in range(2):
		var ankle2 = tunic_center - dir * 17.0 + perp * (-10.5 if boot_i3 == 0 else 10.5)
		draw_arc(ankle2, 5.0, 0, TAU, 8, Color(0.18, 0.44, 0.12, 0.5), 1.5)

	# === Head ===
	var head_center = tunic_center + dir * 21.0
	# Neck with collar detail
	draw_line(tunic_center + dir * 10.0, head_center - dir * 5.0, skin_shadow, 7.5)
	draw_line(tunic_center + dir * 10.0, head_center - dir * 5.0, skin_base, 5.5)
	# Leaf collar at neckline
	for nc in range(5):
		var nc_a = aim_angle + PI + float(nc) * 0.4 - 0.8
		var nc_pos = tunic_center + dir * 10.0 + Vector2.from_angle(nc_a) * 6.0
		var nc_d = Vector2.from_angle(nc_a)
		draw_line(nc_pos, nc_pos + nc_d * 4.0, Color(0.18, 0.46, 0.12, 0.6), 2.0)
		draw_line(nc_pos + nc_d * 4.0, nc_pos + nc_d * 5.5 + nc_d.rotated(0.4) * 1.0, Color(0.16, 0.42, 0.10, 0.5), 1.0)

	# Auburn/red-brown messy hair (back layer)
	var hair_sway = sin(_time * 2.5) * 3.5
	var hair_base_col = Color(0.52, 0.26, 0.12)
	var hair_mid_col = Color(0.58, 0.30, 0.14)
	var hair_hi_col = Color(0.65, 0.35, 0.16)
	var hair_light_col = Color(0.72, 0.40, 0.18)
	# Hair base mass (larger for more volume)
	draw_circle(head_center, 21.0, hair_base_col)
	draw_circle(head_center - dir * 1.0, 19.5, hair_mid_col)
	# Volume highlight on top
	draw_circle(head_center + dir * 5.0, 14.0, Color(0.56, 0.28, 0.13, 0.4))

	# Messy sideburns with more strands
	var sideburn_r = head_center + perp * 17.0 - dir * 4.0
	draw_line(sideburn_r, sideburn_r - dir * 11.0 + perp * 2.5, hair_base_col, 4.5)
	draw_line(sideburn_r - dir * 4.0, sideburn_r - dir * 13.0 + perp * 4.0 + Vector2(hair_sway * 0.3, 0), hair_mid_col, 2.5)
	draw_line(sideburn_r - dir * 6.0 + perp * 1.0, sideburn_r - dir * 10.0 + perp * 4.5 + Vector2(-hair_sway * 0.2, 0), hair_base_col, 2.0)
	draw_line(sideburn_r - dir * 8.0, sideburn_r - dir * 14.0 + perp * 3.0, hair_hi_col, 1.5)
	var sideburn_l = head_center - perp * 17.0 - dir * 4.0
	draw_line(sideburn_l, sideburn_l - dir * 11.0 - perp * 2.5, hair_base_col, 4.5)
	draw_line(sideburn_l - dir * 4.0, sideburn_l - dir * 13.0 - perp * 4.0 + Vector2(-hair_sway * 0.3, 0), hair_mid_col, 2.5)
	draw_line(sideburn_l - dir * 6.0 - perp * 1.0, sideburn_l - dir * 10.0 - perp * 4.5 + Vector2(hair_sway * 0.2, 0), hair_base_col, 2.0)
	draw_line(sideburn_l - dir * 8.0, sideburn_l - dir * 14.0 - perp * 3.0, hair_hi_col, 1.5)

	# 12 individual messy tuft strands
	var tuft_angles = [0.15, 0.65, 1.15, 1.65, 2.15, 2.65, 3.15, 3.65, 4.15, 4.65, 5.15, 5.65]
	var tuft_lengths = [11.0, 13.0, 10.0, 12.0, 14.0, 9.0, 12.0, 11.0, 13.0, 10.0, 11.0, 12.0]
	var tuft_widths = [3.0, 2.5, 3.5, 2.0, 3.0, 2.5, 2.0, 3.0, 2.5, 3.5, 2.5, 3.0]
	for h in range(12):
		var ha = tuft_angles[h]
		var tlen = tuft_lengths[h]
		var twid = tuft_widths[h]
		var tuft_base_pos = head_center + Vector2.from_angle(ha) * 19.0
		var sway_dir_val = 1.0 if h % 2 == 0 else -1.0
		var sway_amount = hair_sway * sway_dir_val * 0.7
		var tuft_tip_pos = tuft_base_pos + Vector2.from_angle(ha) * tlen + perp * sway_amount
		var tcol = hair_mid_col if h % 4 == 0 else hair_hi_col if h % 4 == 1 else hair_light_col if h % 4 == 2 else hair_base_col
		draw_line(tuft_base_pos, tuft_tip_pos, tcol, twid)
		# Wispy secondary strand
		var offset_angle = ha + (0.12 if h % 2 == 0 else -0.12)
		var tuft2_base = head_center + Vector2.from_angle(offset_angle) * 18.0
		var tuft2_tip = tuft2_base + Vector2.from_angle(offset_angle) * (tlen * 0.65) + perp * (sway_amount * 0.7)
		draw_line(tuft2_base, tuft2_tip, hair_base_col, twid * 0.5)
		# Tertiary ultra-thin strand for windswept look
		if h % 3 == 0:
			var offset_angle2 = ha - 0.2
			var tuft3_base = head_center + Vector2.from_angle(offset_angle2) * 17.0
			var tuft3_tip = tuft3_base + Vector2.from_angle(offset_angle2) * (tlen * 0.5) + perp * (sway_amount * 1.2)
			draw_line(tuft3_base, tuft3_tip, hair_hi_col, 1.0)

	# Face (warm skin)
	draw_circle(head_center + dir * 3.0, 17.0, skin_base)
	# Face shading
	draw_arc(head_center + dir * 3.0, 16.0, aim_angle + PI * 0.6, aim_angle + PI * 1.4, 16, skin_shadow, 2.0)
	# Chin definition
	draw_arc(head_center + dir * 3.0, 15.0, aim_angle - PI * 0.3, aim_angle + PI * 0.3, 8, Color(0.85, 0.68, 0.52, 0.3), 1.5)
	# Slight blush on cheeks
	draw_circle(head_center + dir * 4.0 - perp * 9.5, 4.5, Color(0.95, 0.60, 0.52, 0.22))
	draw_circle(head_center + dir * 4.0 + perp * 9.5, 4.5, Color(0.95, 0.60, 0.52, 0.22))

	# Button nose with upturn
	var nose_pos = head_center + dir * 12.0
	draw_line(nose_pos - dir * 4.5, nose_pos, Color(0.82, 0.66, 0.52, 0.6), 2.0)
	draw_circle(nose_pos, 3.0, skin_highlight)
	draw_circle(nose_pos + dir * 0.5, 2.4, Color(0.93, 0.78, 0.65))
	draw_circle(nose_pos - perp * 1.8 - dir * 0.5, 1.0, Color(0.55, 0.40, 0.32, 0.5))
	draw_circle(nose_pos + perp * 1.8 - dir * 0.5, 1.0, Color(0.55, 0.40, 0.32, 0.5))
	draw_circle(nose_pos + dir * 1.2, 1.3, Color(1.0, 0.88, 0.78, 0.4))

	# Freckles (10 natural dots in clusters)
	var freckle_col = Color(0.62, 0.42, 0.28, 0.55)
	# Left cheek cluster
	draw_circle(head_center + dir * 5.5 - perp * 7.0, 1.0, freckle_col)
	draw_circle(head_center + dir * 4.0 - perp * 5.5, 0.9, freckle_col)
	draw_circle(head_center + dir * 6.5 - perp * 5.0, 1.1, freckle_col)
	draw_circle(head_center + dir * 3.5 - perp * 8.0, 0.8, freckle_col)
	draw_circle(head_center + dir * 5.0 - perp * 9.0, 0.7, freckle_col)
	# Right cheek cluster
	draw_circle(head_center + dir * 5.5 + perp * 7.0, 1.0, freckle_col)
	draw_circle(head_center + dir * 4.0 + perp * 5.5, 0.9, freckle_col)
	draw_circle(head_center + dir * 6.5 + perp * 5.0, 1.1, freckle_col)
	draw_circle(head_center + dir * 3.5 + perp * 8.0, 0.8, freckle_col)
	draw_circle(head_center + dir * 5.0 + perp * 9.0, 0.7, freckle_col)
	# Nose bridge freckle
	draw_circle(head_center + dir * 10.0 + perp * 1.0, 0.6, Color(0.62, 0.42, 0.28, 0.4))

	# Eyebrows — mischievous asymmetric arch
	var left_brow_inner = head_center + dir * 10.0 - perp * 3.5
	var left_brow_outer = head_center + dir * 7.5 - perp * 10.0
	var left_brow_peak = head_center + dir * 12.5 - perp * 6.5
	draw_line(left_brow_inner, left_brow_peak, Color(0.45, 0.24, 0.10), 2.5)
	draw_line(left_brow_peak, left_brow_outer, Color(0.45, 0.24, 0.10), 2.0)
	# Brow hair detail
	draw_line(left_brow_peak, left_brow_peak + dir * 1.5 - perp * 1.0, Color(0.50, 0.28, 0.12, 0.5), 1.0)
	var right_brow_inner = head_center + dir * 10.0 + perp * 3.5
	var right_brow_outer = head_center + dir * 7.5 + perp * 10.0
	var right_brow_peak = head_center + dir * 14.0 + perp * 6.5
	draw_line(right_brow_inner, right_brow_peak, Color(0.45, 0.24, 0.10), 2.5)
	draw_line(right_brow_peak, right_brow_outer, Color(0.45, 0.24, 0.10), 2.0)
	draw_line(right_brow_peak, right_brow_peak + dir * 1.5 + perp * 1.0, Color(0.50, 0.28, 0.12, 0.5), 1.0)

	# Bright green eyes with detailed iris
	var left_eye_pos = head_center + dir * 8.0 - perp * 6.0
	var right_eye_pos = head_center + dir * 8.0 + perp * 6.0
	# Eye socket shadow
	draw_circle(left_eye_pos, 5.5, Color(0.72, 0.56, 0.44, 0.3))
	draw_circle(right_eye_pos, 5.5, Color(0.72, 0.56, 0.44, 0.3))
	# Eye whites
	draw_circle(left_eye_pos, 5.0, Color(0.96, 0.96, 0.98))
	draw_circle(right_eye_pos, 5.0, Color(0.96, 0.96, 0.98))
	# Eye white shadow
	draw_arc(left_eye_pos, 4.5, aim_angle + PI * 0.15, aim_angle + PI * 0.85, 8, Color(0.82, 0.82, 0.88, 0.4), 1.5)
	draw_arc(right_eye_pos, 4.5, aim_angle + PI * 0.15, aim_angle + PI * 0.85, 8, Color(0.82, 0.82, 0.88, 0.4), 1.5)
	# Green irises (outer darker, inner bright, gold ring)
	draw_circle(left_eye_pos + dir * 1.0, 3.5, Color(0.10, 0.48, 0.20))
	draw_circle(left_eye_pos + dir * 1.0, 2.8, Color(0.16, 0.65, 0.28))
	draw_circle(left_eye_pos + dir * 1.0, 2.2, Color(0.22, 0.72, 0.32))
	draw_circle(right_eye_pos + dir * 1.0, 3.5, Color(0.10, 0.48, 0.20))
	draw_circle(right_eye_pos + dir * 1.0, 2.8, Color(0.16, 0.65, 0.28))
	draw_circle(right_eye_pos + dir * 1.0, 2.2, Color(0.22, 0.72, 0.32))
	# Gold limbal ring
	draw_arc(left_eye_pos + dir * 1.0, 3.3, 0, TAU, 12, Color(0.65, 0.55, 0.15, 0.3), 0.6)
	draw_arc(right_eye_pos + dir * 1.0, 3.3, 0, TAU, 12, Color(0.65, 0.55, 0.15, 0.3), 0.6)
	# Iris radial detail
	for ri in range(8):
		var ra = TAU * float(ri) / 8.0
		var rstart = left_eye_pos + dir * 1.0 + Vector2.from_angle(ra) * 1.0
		var rend = left_eye_pos + dir * 1.0 + Vector2.from_angle(ra) * 3.0
		draw_line(rstart, rend, Color(0.12, 0.55, 0.24, 0.35), 0.5)
		rstart = right_eye_pos + dir * 1.0 + Vector2.from_angle(ra) * 1.0
		rend = right_eye_pos + dir * 1.0 + Vector2.from_angle(ra) * 3.0
		draw_line(rstart, rend, Color(0.12, 0.55, 0.24, 0.35), 0.5)
	# Pupils
	draw_circle(left_eye_pos + dir * 1.6, 1.7, Color(0.05, 0.05, 0.07))
	draw_circle(right_eye_pos + dir * 1.6, 1.7, Color(0.05, 0.05, 0.07))
	# Primary highlight
	draw_circle(left_eye_pos + dir * 0.4 + perp * 1.2, 1.4, Color(1.0, 1.0, 1.0, 0.9))
	draw_circle(right_eye_pos + dir * 0.4 + perp * 1.2, 1.4, Color(1.0, 1.0, 1.0, 0.9))
	# Secondary highlight
	draw_circle(left_eye_pos + dir * 2.0 - perp * 0.8, 0.8, Color(1.0, 1.0, 1.0, 0.55))
	draw_circle(right_eye_pos + dir * 2.0 - perp * 0.8, 0.8, Color(1.0, 1.0, 1.0, 0.55))
	# Mischievous glint (tiny green sparkle in eyes)
	var glint_t = sin(_time * 2.0) * 0.3
	draw_circle(left_eye_pos + dir * 0.8 - perp * 0.5, 0.5, Color(0.4, 0.9, 0.5, 0.3 + glint_t))
	draw_circle(right_eye_pos + dir * 0.8 - perp * 0.5, 0.5, Color(0.4, 0.9, 0.5, 0.3 + glint_t))
	# Eyelid lines
	draw_arc(left_eye_pos, 5.0, aim_angle + PI * 0.15, aim_angle + PI * 0.85, 8, Color(0.40, 0.22, 0.12), 1.3)
	draw_arc(right_eye_pos, 5.0, aim_angle + PI * 0.15, aim_angle + PI * 0.85, 8, Color(0.40, 0.22, 0.12), 1.3)
	# Eyelashes (3 tiny lashes on upper lid)
	for el in range(3):
		var el_a = aim_angle + PI * 0.25 + float(el) * PI * 0.2
		var el_base_l = left_eye_pos + Vector2.from_angle(el_a) * 5.0
		var el_tip_l = el_base_l + Vector2.from_angle(el_a) * 2.5
		draw_line(el_base_l, el_tip_l, Color(0.38, 0.20, 0.10, 0.6), 0.8)
		var el_base_r = right_eye_pos + Vector2.from_angle(el_a) * 5.0
		var el_tip_r = el_base_r + Vector2.from_angle(el_a) * 2.5
		draw_line(el_base_r, el_tip_r, Color(0.38, 0.20, 0.10, 0.6), 0.8)
	# Lower lash line
	draw_arc(left_eye_pos, 4.8, aim_angle - PI * 0.7, aim_angle - PI * 0.3, 6, Color(0.45, 0.28, 0.18, 0.4), 0.8)
	draw_arc(right_eye_pos, 4.8, aim_angle - PI * 0.7, aim_angle - PI * 0.3, 6, Color(0.45, 0.28, 0.18, 0.4), 0.8)

	# Cheeky cocky grin — wider, more mischievous
	var mouth_center = head_center + dir * 2.0
	# Mouth curve (wider asymmetric grin — one side higher)
	draw_arc(mouth_center + perp * 1.0, 9.5, aim_angle - 0.95, aim_angle + 0.85, 16, Color(0.65, 0.30, 0.25), 2.5)
	# Upper lip with cupid's bow shape
	draw_arc(mouth_center, 8.5, aim_angle - 0.5, aim_angle + 0.5, 10, Color(0.72, 0.38, 0.32), 1.5)
	# Mouth opening
	draw_arc(mouth_center, 7.5, aim_angle - 0.7, aim_angle + 0.7, 12, Color(0.32, 0.10, 0.08, 0.7), 2.5)
	# Teeth (cocky grin showing more teeth)
	for ti in range(5):
		var tooth_angle = aim_angle + float(ti - 2) * 0.26
		var tooth_pos = mouth_center + Vector2.from_angle(tooth_angle) * 7.0
		draw_circle(tooth_pos, 1.3, Color(0.98, 0.96, 0.92))
		draw_circle(tooth_pos, 0.9, Color(0.92, 0.90, 0.86, 0.5))
	# One slightly crooked front tooth (boyish charm)
	var crooked_tooth = mouth_center + Vector2.from_angle(aim_angle + 0.05) * 6.5
	draw_circle(crooked_tooth, 1.5, Color(0.98, 0.97, 0.93))
	# Grin dimples (deeper)
	draw_circle(head_center + dir * 0.5 - perp * 10.0, 1.8, Color(0.78, 0.56, 0.46, 0.5))
	draw_circle(head_center + dir * 0.5 + perp * 10.0, 1.8, Color(0.78, 0.56, 0.46, 0.5))
	# Lower lip
	draw_arc(mouth_center, 8.0, aim_angle - 0.4, aim_angle + 0.4, 8, Color(0.88, 0.52, 0.48, 0.3), 1.0)
	# Cocky smirk line (right corner turned up extra)
	draw_line(mouth_center + Vector2.from_angle(aim_angle + 0.85) * 9.0, mouth_center + Vector2.from_angle(aim_angle + 1.1) * 10.5, Color(0.65, 0.30, 0.25, 0.5), 1.2)

	# Pointed elf ears (more prominent with glow at higher tiers)
	# Right ear
	var r_ear_base_top = head_center + perp * 16.5 + dir * 6.0
	var r_ear_base_bot = head_center + perp * 16.5 - dir * 2.0
	var r_ear_tip = head_center + perp * 32.0 + dir * 9.0
	var r_ear_pts = PackedVector2Array([r_ear_base_top, r_ear_base_bot, r_ear_tip])
	draw_colored_polygon(r_ear_pts, skin_base)
	draw_line(r_ear_base_top, r_ear_tip, skin_shadow, 2.5)
	draw_line(r_ear_tip, r_ear_base_bot, Color(0.80, 0.64, 0.50), 2.0)
	draw_line(r_ear_base_bot, r_ear_base_top, skin_base, 1.5)
	# Inner ear detail
	var r_ear_inner = head_center + perp * 23.0 + dir * 4.0
	draw_circle(r_ear_inner, 3.8, Color(0.92, 0.70, 0.60, 0.5))
	draw_line(r_ear_inner - dir * 2.5, r_ear_tip, Color(0.90, 0.68, 0.58, 0.4), 1.5)
	# Ear point highlight
	draw_circle(r_ear_tip, 1.5, Color(0.95, 0.80, 0.68, 0.4))
	# Left ear
	var l_ear_base_top = head_center - perp * 16.5 + dir * 6.0
	var l_ear_base_bot = head_center - perp * 16.5 - dir * 2.0
	var l_ear_tip = head_center - perp * 32.0 + dir * 9.0
	var l_ear_pts = PackedVector2Array([l_ear_base_top, l_ear_base_bot, l_ear_tip])
	draw_colored_polygon(l_ear_pts, skin_base)
	draw_line(l_ear_base_top, l_ear_tip, skin_shadow, 2.5)
	draw_line(l_ear_tip, l_ear_base_bot, Color(0.80, 0.64, 0.50), 2.0)
	draw_line(l_ear_base_bot, l_ear_base_top, skin_base, 1.5)
	var l_ear_inner = head_center - perp * 23.0 + dir * 4.0
	draw_circle(l_ear_inner, 3.8, Color(0.92, 0.70, 0.60, 0.5))
	draw_line(l_ear_inner - dir * 2.5, l_ear_tip, Color(0.90, 0.68, 0.58, 0.4), 1.5)
	draw_circle(l_ear_tip, 1.5, Color(0.95, 0.80, 0.68, 0.4))
	# Tier 4: Ear tip glow (fairy magic)
	if upgrade_tier >= 4:
		var ear_glow = 0.3 + sin(_time * 3.0) * 0.15
		draw_circle(r_ear_tip, 3.0, Color(1.0, 0.9, 0.4, ear_glow))
		draw_circle(l_ear_tip, 3.0, Color(1.0, 0.9, 0.4, ear_glow))

	# === Peter Pan Hat with leaf texture ===
	var hat_base = head_center + dir * 10.0
	var hat_tip = hat_base + dir * 14.0 + perp * 23.0
	var hat_pts = PackedVector2Array()
	hat_pts.append(hat_base - perp * 16.0)
	for ci in range(7):
		var ct = float(ci) / 6.0
		var brim_pos = hat_base + perp * (-16.0 + ct * 32.0)
		var brim_curve = sin(ct * PI) * 3.5
		hat_pts.append(brim_pos + dir * brim_curve)
	hat_pts.append(hat_tip)
	draw_colored_polygon(hat_pts, Color(0.20, 0.50, 0.14))
	# Hat depth shading
	var hat_shade_pts = PackedVector2Array([
		hat_base - perp * 14.0 + dir * 1.0,
		hat_base + perp * 8.0 + dir * 1.0,
		hat_tip - perp * 2.0,
	])
	draw_colored_polygon(hat_shade_pts, Color(0.16, 0.42, 0.10, 0.4))
	# Hat brim
	draw_line(hat_base - perp * 16.0, hat_base + perp * 16.0, Color(0.14, 0.38, 0.08), 4.0)
	draw_line(hat_base - perp * 16.0 + dir * 0.5, hat_base + perp * 16.0 + dir * 0.5, Color(0.24, 0.52, 0.16), 2.5)
	# Leaf veins on hat (more detailed)
	var hat_vein_col = Color(0.13, 0.36, 0.08, 0.6)
	draw_line(hat_base + perp * 2.0, hat_tip - dir * 2.0, hat_vein_col, 1.3)
	var vein_mid1 = hat_base + (hat_tip - hat_base) * 0.25
	var vein_mid2 = hat_base + (hat_tip - hat_base) * 0.45
	var vein_mid3 = hat_base + (hat_tip - hat_base) * 0.65
	var vein_mid4 = hat_base + (hat_tip - hat_base) * 0.82
	draw_line(vein_mid1, vein_mid1 - perp * 9.0 - dir * 2.5, hat_vein_col, 0.9)
	draw_line(vein_mid1, vein_mid1 + perp * 4.5 + dir * 3.0, hat_vein_col, 0.9)
	draw_line(vein_mid2, vein_mid2 - perp * 7.0 - dir * 2.0, hat_vein_col, 0.8)
	draw_line(vein_mid2, vein_mid2 + perp * 3.5 + dir * 2.5, hat_vein_col, 0.8)
	draw_line(vein_mid3, vein_mid3 - perp * 5.0 - dir * 1.5, hat_vein_col, 0.7)
	draw_line(vein_mid3, vein_mid3 + perp * 2.5 + dir * 1.5, hat_vein_col, 0.7)
	draw_line(vein_mid4, vein_mid4 - perp * 3.0 - dir * 1.0, hat_vein_col, 0.6)
	# Secondary vein branches
	draw_line(vein_mid1 - perp * 5.0 - dir * 1.5, vein_mid1 - perp * 8.0 - dir * 4.0, hat_vein_col, 0.5)
	draw_line(vein_mid2 - perp * 4.0 - dir * 1.0, vein_mid2 - perp * 6.5 - dir * 3.5, hat_vein_col, 0.5)

	# Red feather with detailed barbs
	var feather_base = hat_base + dir * 7.0 + perp * 15.0
	var feather_tip_pos = feather_base + dir * -14.0 + perp * 34.0
	var feather_mid_pt = feather_base + (feather_tip_pos - feather_base) * 0.5
	# Feather quill
	draw_line(feather_base, feather_tip_pos, Color(0.72, 0.10, 0.06), 2.2)
	# Feather body
	draw_line(feather_base + (feather_tip_pos - feather_base) * 0.12, feather_tip_pos - (feather_tip_pos - feather_base) * 0.08, Color(0.88, 0.16, 0.08), 4.5)
	# Gradient coloring (darker at base, brighter at tip)
	draw_line(feather_base + (feather_tip_pos - feather_base) * 0.5, feather_tip_pos - (feather_tip_pos - feather_base) * 0.08, Color(0.92, 0.22, 0.12), 3.5)
	# Feather barbs
	var feather_dir_vec = (feather_tip_pos - feather_base).normalized()
	var feather_perp_vec = feather_dir_vec.rotated(PI / 2.0)
	for bi in range(10):
		var bt = 0.1 + float(bi) * 0.085
		var barb_origin = feather_base + (feather_tip_pos - feather_base) * bt
		var barb_len = 5.0 - abs(float(bi) - 4.5) * 0.5
		var barb_col = Color(0.85 + float(bi % 2) * 0.08, 0.14 + float(bi % 3) * 0.05, 0.06, 0.85)
		draw_line(barb_origin, barb_origin + feather_perp_vec * barb_len + feather_dir_vec * 1.8, barb_col, 1.0)
		draw_line(barb_origin, barb_origin - feather_perp_vec * barb_len + feather_dir_vec * 1.8, barb_col, 1.0)
	# Feather tip
	draw_line(feather_tip_pos - feather_dir_vec * 3.5 + feather_perp_vec * 2.5, feather_tip_pos, Color(0.82, 0.14, 0.08), 1.5)
	draw_line(feather_tip_pos - feather_dir_vec * 3.5 - feather_perp_vec * 2.5, feather_tip_pos, Color(0.82, 0.14, 0.08), 1.5)
	# Feather shine
	draw_line(feather_mid_pt + feather_perp_vec * 0.5, feather_mid_pt + feather_dir_vec * 7.0 + feather_perp_vec * 0.5, Color(0.95, 0.40, 0.30, 0.4), 1.2)
	# Feather sway (wind effect on tip)
	var feather_sway = sin(_time * 3.0) * 2.0
	draw_line(feather_tip_pos, feather_tip_pos + feather_perp_vec * feather_sway + feather_dir_vec * 3.0, Color(0.85, 0.18, 0.10, 0.6), 1.5)

	# === Tier 2+: Tinker Bell orbiting with enhanced sparkle trail ===
	if upgrade_tier >= 2:
		var tink_orbit_speed = 1.8
		var tink_orbit_radius = 46.0
		var tink_bob = sin(_time * 4.0) * 4.0
		var tink_angle = _time * tink_orbit_speed
		var tink_pos = body_offset + Vector2(cos(tink_angle), sin(tink_angle)) * tink_orbit_radius + Vector2(0, tink_bob)
		# Sparkle trail (6 fading with star shapes)
		for trail_i in range(6):
			var trail_angle = tink_angle - float(trail_i + 1) * 0.3
			var trail_bob = sin((_time - float(trail_i) * 0.15) * 4.0) * 4.0
			var trail_pos = body_offset + Vector2(cos(trail_angle), sin(trail_angle)) * tink_orbit_radius + Vector2(0, trail_bob)
			var trail_alpha = 0.45 - float(trail_i) * 0.07
			var trail_size = 4.0 - float(trail_i) * 0.5
			draw_circle(trail_pos, trail_size, Color(1.0, 0.92, 0.4, trail_alpha))
			# Star cross on trail sparkles
			if trail_i < 3:
				draw_line(trail_pos - Vector2(trail_size, 0), trail_pos + Vector2(trail_size, 0), Color(1.0, 1.0, 0.8, trail_alpha * 0.5), 0.6)
				draw_line(trail_pos - Vector2(0, trail_size), trail_pos + Vector2(0, trail_size), Color(1.0, 1.0, 0.8, trail_alpha * 0.5), 0.6)
		# Tinker Bell outer glow
		draw_circle(tink_pos, 12.0, Color(1.0, 0.9, 0.3, 0.15))
		draw_circle(tink_pos, 8.0, Color(1.0, 0.92, 0.35, 0.25))
		# Tinker Bell body (golden)
		draw_circle(tink_pos, 5.0, Color(1.0, 0.95, 0.4, 0.85))
		draw_circle(tink_pos, 3.0, Color(1.0, 1.0, 0.7, 0.95))
		# Tiny head
		var tink_head = tink_pos + Vector2.from_angle(tink_angle) * 4.0
		draw_circle(tink_head, 2.2, Color(1.0, 0.95, 0.5, 0.9))
		draw_circle(tink_head, 1.5, Color(1.0, 1.0, 0.8))
		# Hair bun
		draw_circle(tink_head + Vector2.from_angle(tink_angle) * 1.5, 1.2, Color(1.0, 0.85, 0.3))
		# Tiny dress shape
		var tink_body_dir = Vector2.from_angle(tink_angle + PI)
		var dress_pts = PackedVector2Array([
			tink_pos - tink_body_dir * 1.0 + tink_body_dir.rotated(PI / 2.0) * 2.0,
			tink_pos - tink_body_dir * 1.0 - tink_body_dir.rotated(PI / 2.0) * 2.0,
			tink_pos + tink_body_dir * 4.0 - tink_body_dir.rotated(PI / 2.0) * 3.5,
			tink_pos + tink_body_dir * 4.0 + tink_body_dir.rotated(PI / 2.0) * 3.5,
		])
		draw_colored_polygon(dress_pts, Color(0.5, 0.95, 0.4, 0.6))
		# Wings (fluttering rapidly)
		var tink_perp = Vector2.from_angle(tink_angle + PI / 2.0)
		var wing_flutter = sin(_time * 14.0) * 3.5
		# Upper wings (larger, translucent)
		var wing_r_tip = tink_pos + tink_perp * (11.0 + wing_flutter) + Vector2(0, -3.0)
		var wing_l_tip = tink_pos - tink_perp * (11.0 - wing_flutter) + Vector2(0, -3.0)
		draw_line(tink_pos + tink_perp * 2.0, wing_r_tip, Color(0.9, 0.95, 1.0, 0.55), 2.5)
		draw_line(tink_pos - tink_perp * 2.0, wing_l_tip, Color(0.9, 0.95, 1.0, 0.55), 2.5)
		# Lower wings (smaller)
		draw_line(tink_pos + tink_perp * 1.5, tink_pos + tink_perp * (7.0 + wing_flutter * 0.7) + Vector2(0, 2.0), Color(0.85, 0.92, 1.0, 0.4), 1.8)
		draw_line(tink_pos - tink_perp * 1.5, tink_pos - tink_perp * (7.0 - wing_flutter * 0.7) + Vector2(0, 2.0), Color(0.85, 0.92, 1.0, 0.4), 1.8)
		# Wing sparkle at tips
		draw_circle(wing_r_tip, 1.5, Color(1.0, 1.0, 0.9, 0.4 + sin(_time * 6.0) * 0.2))
		draw_circle(wing_l_tip, 1.5, Color(1.0, 1.0, 0.9, 0.4 + cos(_time * 6.0) * 0.2))

	# === Tier 4: Golden fairy-dust aura ===
	if upgrade_tier >= 4:
		var aura_pulse = sin(_time * 2.5) * 6.0
		# Multi-layered aura
		draw_circle(body_offset, 58.0 + aura_pulse, Color(1.0, 0.85, 0.3, 0.04))
		draw_circle(body_offset, 48.0 + aura_pulse * 0.7, Color(1.0, 0.88, 0.35, 0.06))
		draw_circle(body_offset, 38.0 + aura_pulse * 0.4, Color(1.0, 0.90, 0.4, 0.08))
		draw_arc(body_offset, 54.0 + aura_pulse, 0, TAU, 36, Color(1.0, 0.85, 0.35, 0.2), 3.0)
		draw_arc(body_offset, 44.0 + aura_pulse * 0.5, 0, TAU, 28, Color(1.0, 0.90, 0.4, 0.12), 2.0)
		# Golden sparkles orbiting (more, varied sizes)
		for gs in range(10):
			var gs_angle = _time * (0.8 + float(gs % 3) * 0.3) + float(gs) * TAU / 10.0
			var gs_radius = 42.0 + aura_pulse + float(gs % 4) * 5.0
			var gs_pos = body_offset + Vector2.from_angle(gs_angle) * gs_radius
			var gs_size = 1.8 + sin(_time * 3.0 + float(gs) * 1.5) * 1.0
			var gs_alpha = 0.4 + sin(_time * 3.0 + float(gs)) * 0.25
			draw_circle(gs_pos, gs_size, Color(1.0, 0.9, 0.4, gs_alpha))
		# Rising fairy dust motes
		for rm in range(5):
			var rm_seed = float(rm) * 3.14
			var rm_x = sin(_time * 0.8 + rm_seed) * 30.0
			var rm_y = -fmod(_time * 20.0 + rm_seed * 10.0, 80.0) + 40.0
			var rm_alpha = 0.3 * (1.0 - abs(rm_y) / 40.0)
			if rm_alpha > 0.0:
				draw_circle(body_offset + Vector2(rm_x, rm_y), 1.5, Color(1.0, 0.92, 0.5, rm_alpha))

	# === Awaiting ability choice indicator ===
	if awaiting_ability_choice:
		var pulse = (sin(_time * 4.0) + 1.0) * 0.5
		draw_circle(Vector2.ZERO, 76.0 + pulse * 8.0, Color(0.5, 1.0, 0.6, 0.1 + pulse * 0.1))
		draw_arc(Vector2.ZERO, 76.0 + pulse * 8.0, 0, TAU, 32, Color(0.5, 1.0, 0.6, 0.3 + pulse * 0.3), 3.0)
		var font3 = _game_font
		draw_string(font3, Vector2(-16, -88), "!", HORIZONTAL_ALIGNMENT_CENTER, 32, 36, Color(0.5, 1.0, 0.6, 0.7 + pulse * 0.3))

	# Damage dealt counter + level
	if damage_dealt > 0:
		var font = _game_font
		var dmg_text = str(int(damage_dealt)) + " DMG"
		if stat_upgrade_level > 0:
			dmg_text += " • Lv." + str(stat_upgrade_level)
		draw_string(font, Vector2(-36, 84), dmg_text, HORIZONTAL_ALIGNMENT_LEFT, 160, 14, Color(1.0, 0.84, 0.0, 0.6))

	# Upgrade name
	if _upgrade_flash > 0.0 and _upgrade_name != "":
		var font2 = _game_font
		draw_string(font2, Vector2(-80, -80), _upgrade_name, HORIZONTAL_ALIGNMENT_CENTER, 160, 16, Color(0.5, 1.0, 0.6, min(_upgrade_flash, 1.0)))
