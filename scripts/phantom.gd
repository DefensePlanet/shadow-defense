extends Node2D
## The Phantom of the Opera — single-target control tower from Gaston Leroux (1910).
## Throws music notes (heavy damage). Upgrades by dealing damage.
## Tier 1 (5000 DMG): "Punjab Lasso" — periodically stuns closest enemy for 2.5s
## Tier 2 (10000 DMG): "Angel of Music" — passive slow aura on enemies in range
## Tier 3 (15000 DMG): "Chandelier" — periodic AoE burst (2x damage to all in range)
## Tier 4 (20000 DMG): "Phantom's Wrath" — notes apply DoT, all stats boosted

var damage: float = 70.0
var fire_rate: float = 1.0
var attack_range: float = 180.0
var fire_cooldown: float = 0.0
var aim_angle: float = 0.0
var target: Node2D = null
var gold_bonus: int = 5

# Damage tracking and upgrades
var damage_dealt: float = 0.0
var upgrade_tier: int = 0
var _upgrade_flash: float = 0.0
var _upgrade_name: String = ""

# Animation vars
var _time: float = 0.0
var _attack_anim: float = 0.0

# Tier 1: Punjab Lasso — stun
var lasso_timer: float = 0.0
var lasso_cooldown: float = 10.0
var _lasso_flash: float = 0.0

# Tier 2: Angel of Music — passive slow aura
var aura_tick: float = 0.0

# Tier 3: Chandelier — AoE
var chandelier_timer: float = 0.0
var chandelier_cooldown: float = 18.0
var _chandelier_flash: float = 0.0

# Tier 4: Phantom's Wrath — DoT on notes
var note_dot_dps: float = 0.0
var note_dot_duration: float = 0.0

const STAT_UPGRADE_INTERVAL: float = 500.0
const ABILITY_THRESHOLD: float = 1500.0
var stat_upgrade_level: int = 0
var ability_chosen: bool = false
var awaiting_ability_choice: bool = false
const TIER_NAMES = [
	"Punjab Lasso",
	"Angel of Music",
	"Chandelier",
	"Phantom's Wrath"
]
const ABILITY_DESCRIPTIONS = [
	"Periodically stuns closest enemy for 2.5s",
	"Passive slow aura on enemies in range",
	"Periodic AoE burst (2x damage to all)",
	"Notes apply DoT, all stats boosted"
]
const TIER_COSTS = [65, 130, 210, 360]
var is_selected: bool = false
var base_cost: int = 0

var note_scene = preload("res://scenes/phantom_note.tscn")

# Attack sound
var _attack_sound: AudioStreamWAV
var _attack_player: AudioStreamPlayer

func _ready() -> void:
	add_to_group("towers")
	# Generate deep organ note sound
	var mix_rate := 22050
	var duration := 0.15
	var samples := PackedFloat32Array()
	samples.resize(int(mix_rate * duration))
	for i in samples.size():
		var t := float(i) / mix_rate
		# Organ pipe: fundamental C4 (261Hz) + fifth (392Hz) + octave (522Hz)
		var fundamental := sin(t * 261.0 * TAU) * 0.4
		var fifth := sin(t * 392.0 * TAU) * 0.25
		var octave := sin(t * 522.0 * TAU) * 0.15
		# Fast attack, medium decay envelope
		var env := minf(t * 200.0, 1.0) * exp(-t * 10.0)
		# Slight breathy quality
		var breath := (randf() * 2.0 - 1.0) * 0.05 * env
		samples[i] = clampf((fundamental + fifth + octave) * env + breath, -1.0, 1.0)
	_attack_sound = _samples_to_wav(samples, mix_rate)
	_attack_player = AudioStreamPlayer.new()
	_attack_player.stream = _attack_sound
	_attack_player.volume_db = -8.0
	add_child(_attack_player)

func _process(delta: float) -> void:
	_time += delta
	_attack_anim = max(_attack_anim - delta * 3.0, 0.0)
	fire_cooldown -= delta
	_upgrade_flash = max(_upgrade_flash - delta * 0.5, 0.0)
	_lasso_flash = max(_lasso_flash - delta * 2.0, 0.0)
	_chandelier_flash = max(_chandelier_flash - delta * 1.5, 0.0)
	target = _find_nearest_enemy()

	if target:
		var desired = global_position.angle_to_point(target.global_position) + PI
		aim_angle = lerp_angle(aim_angle, desired, 8.0 * delta)
		if fire_cooldown <= 0.0:
			_shoot()
			fire_cooldown = 1.0 / fire_rate

	# Tier 1: Punjab Lasso stun
	if upgrade_tier >= 1:
		lasso_timer -= delta
		if lasso_timer <= 0.0 and _has_enemies_in_range():
			_punjab_lasso()
			lasso_timer = lasso_cooldown

	# Tier 2: Angel of Music aura (slow tick)
	if upgrade_tier >= 2:
		aura_tick -= delta
		if aura_tick <= 0.0:
			_music_aura()
			aura_tick = 0.5

	# Tier 3: Chandelier AoE
	if upgrade_tier >= 3:
		chandelier_timer -= delta
		if chandelier_timer <= 0.0 and _has_enemies_in_range():
			_chandelier_drop()
			chandelier_timer = chandelier_cooldown

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
	if _attack_player:
		_attack_player.play()
	var note = note_scene.instantiate()
	note.global_position = global_position + Vector2.from_angle(aim_angle) * 32.0
	note.damage = damage
	note.target = target
	note.gold_bonus = gold_bonus
	note.source_tower = self
	note.dot_dps = note_dot_dps
	note.dot_duration = note_dot_duration
	get_tree().get_first_node_in_group("main").add_child(note)
	_attack_anim = 1.0

func _punjab_lasso() -> void:
	_lasso_flash = 1.0
	var closest: Node2D = null
	var closest_dist: float = attack_range
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var dist = global_position.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest = enemy
			closest_dist = dist
	if closest and closest.has_method("apply_slow"):
		closest.apply_slow(0.0, 2.5)

func _music_aura() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(enemy.global_position) < attack_range:
			if enemy.has_method("apply_slow"):
				enemy.apply_slow(0.9, 0.6)

func _chandelier_drop() -> void:
	_chandelier_flash = 1.5
	var chandelier_dmg = damage * 2.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(enemy.global_position) < attack_range:
			if enemy.has_method("take_damage"):
				var will_kill = enemy.health - chandelier_dmg <= 0.0
				enemy.take_damage(chandelier_dmg)
				register_damage(chandelier_dmg)
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
	damage *= 1.15
	fire_rate *= 1.06
	attack_range += 7.0
	# Chandelier drop every 500 damage milestone
	if _has_enemies_in_range():
		_chandelier_drop()

func choose_ability(index: int) -> void:
	ability_chosen = true
	awaiting_ability_choice = false
	upgrade_tier = index + 1
	_apply_upgrade(upgrade_tier)
	_upgrade_flash = 3.0
	_upgrade_name = TIER_NAMES[index]

func _apply_upgrade(tier: int) -> void:
	match tier:
		1: # Punjab Lasso — stun ability
			damage = 90.0
			fire_rate = 1.2
			attack_range = 195.0
			lasso_cooldown = 8.0
		2: # Angel of Music — slow aura
			damage = 110.0
			fire_rate = 1.4
			attack_range = 210.0
			gold_bonus = 7
		3: # Chandelier — AoE burst
			damage = 140.0
			fire_rate = 1.6
			attack_range = 230.0
			chandelier_cooldown = 14.0
			gold_bonus = 10
			lasso_cooldown = 6.0
		4: # Phantom's Wrath — DoT + all enhanced
			damage = 180.0
			fire_rate = 2.0
			attack_range = 260.0
			note_dot_dps = 20.0
			note_dot_duration = 4.0
			gold_bonus = 15
			lasso_cooldown = 5.0
			chandelier_cooldown = 10.0

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
	return "The Phantom"

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

func _samples_to_wav(samples: PackedFloat32Array, mix_rate: int) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var val := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		data[i * 2] = val & 0xFF
		data[i * 2 + 1] = (val >> 8) & 0xFF
	wav.data = data
	return wav

func _draw() -> void:
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
	var bounce = abs(sin(_time * 3.0)) * 4.0
	var breathe = sin(_time * 2.0) * 2.0
	var sway = sin(_time * 1.5) * 1.5
	var bob = Vector2(sway, -bounce - breathe)
	var fly_offset = Vector2.ZERO
	if upgrade_tier >= 4:
		fly_offset = Vector2(0, -8.0 + sin(_time * 1.5) * 3.0)
	var body_offset = bob + fly_offset

	# === SKIN COLORS (pale, dramatic — classic Phantom) ===
	var skin_base = Color(0.88, 0.82, 0.78)
	var skin_shadow = Color(0.72, 0.65, 0.60)
	var skin_highlight = Color(0.95, 0.90, 0.88)

	# === UPGRADE GLOW ===
	if upgrade_tier > 0:
		var glow_alpha = 0.1 + 0.03 * upgrade_tier
		var glow_col: Color
		match upgrade_tier:
			1: glow_col = Color(0.5, 0.4, 0.3, glow_alpha)   # rope brown
			2: glow_col = Color(0.5, 0.3, 0.5, glow_alpha)   # music purple
			3: glow_col = Color(0.7, 0.6, 0.2, glow_alpha)   # chandelier gold
			4: glow_col = Color(0.6, 0.1, 0.1, glow_alpha + 0.08) # dark red
		draw_circle(Vector2.ZERO, 72.0, glow_col)

	# === UPGRADE FLASH ===
	if _upgrade_flash > 0.0:
		draw_circle(Vector2.ZERO, 80.0 + _upgrade_flash * 24.0, Color(0.6, 0.3, 0.8, _upgrade_flash * 0.25))
		for i in range(10):
			var ray_a = TAU * float(i) / 10.0 + _time * 0.5
			var ray_s = Vector2.from_angle(ray_a) * (50.0 + _upgrade_flash * 8.0)
			var ray_e = Vector2.from_angle(ray_a) * (85.0 + _upgrade_flash * 22.0)
			draw_line(ray_s, ray_e, Color(0.7, 0.4, 0.9, _upgrade_flash * 0.15), 1.5)

	# === LASSO FLASH (golden rope ring expanding) ===
	if _lasso_flash > 0.0:
		var lf_r = 56.0 + (1.0 - _lasso_flash) * 50.0
		draw_arc(Vector2.ZERO, lf_r, 0, TAU, 32, Color(0.8, 0.65, 0.2, _lasso_flash * 0.5), 4.0)
		draw_arc(Vector2.ZERO, lf_r - 3.0, 0, TAU, 32, Color(0.9, 0.75, 0.3, _lasso_flash * 0.25), 2.0)
		for lfi in range(4):
			var lf_a = TAU * float(lfi) / 4.0 + _time * 3.0
			var lf_p = Vector2.from_angle(lf_a) * lf_r
			draw_circle(lf_p, 4.0, Color(0.9, 0.75, 0.3, _lasso_flash * 0.6))

	# === CHANDELIER FLASH (golden burst with crystal shards) ===
	if _chandelier_flash > 0.0:
		var cf_r = 60.0 + (1.0 - _chandelier_flash) * 110.0
		draw_circle(Vector2.ZERO, cf_r, Color(0.95, 0.85, 0.3, _chandelier_flash * 0.3))
		draw_circle(Vector2.ZERO, cf_r * 0.4, Color(1.0, 0.95, 0.7, _chandelier_flash * 0.2))
		for i in range(12):
			var ca = TAU * float(i) / 12.0 + _chandelier_flash * 2.0
			var cp = Vector2.from_angle(ca) * cf_r
			draw_circle(cp, 6.0 + sin(float(i) * 1.3) * 2.0, Color(1.0, 0.95, 0.7, _chandelier_flash * 0.6))
			draw_line(Vector2.from_angle(ca) * 10.0, cp, Color(1.0, 0.92, 0.5, _chandelier_flash * 0.15), 2.0)
		for i in range(8):
			var sa = TAU * float(i) / 8.0 + _chandelier_flash * 3.5
			var sr = cf_r * (0.5 + fmod(float(i) * 0.37, 0.5))
			var sp = Vector2.from_angle(sa) * sr
			draw_circle(sp, 2.0, Color(1.0, 1.0, 1.0, _chandelier_flash * 0.5))

	# === TIER 4: Dark red opera aura with phantom energy wisps ===
	if upgrade_tier >= 4:
		for aura_i in range(5):
			var aura_r = 78.0 + float(aura_i) * 14.0 + sin(_time * 0.9 + float(aura_i) * 0.7) * 4.0
			var aura_a = 0.12 - float(aura_i) * 0.02
			draw_arc(Vector2.ZERO, aura_r, 0, TAU, 48, Color(0.6, 0.05, 0.1, aura_a), 4.0 + float(aura_i) * 1.5)
		for wi in range(6):
			var w_angle = _time * 0.4 + TAU * float(wi) / 6.0
			var w_r = 70.0 + sin(_time * 1.3 + float(wi) * 2.0) * 15.0
			var w_pos = Vector2.from_angle(w_angle) * w_r
			var w_alpha = 0.08 + sin(_time * 2.0 + float(wi)) * 0.04
			draw_circle(w_pos, 6.0 + sin(_time * 1.7 + float(wi)) * 2.0, Color(0.6, 0.05, 0.1, w_alpha))
			var w_tail = Vector2.from_angle(w_angle - 0.3) * (w_r - 12.0)
			draw_line(w_pos, w_tail, Color(0.5, 0.03, 0.12, w_alpha * 0.6), 2.0)

	# === STONE PLATFORM ===
	var plat_y = 22.0
	# Platform shadow
	draw_circle(Vector2(0, plat_y + 4), 28.0, Color(0, 0, 0, 0.15))
	# Stone platform ellipse
	draw_set_transform(Vector2(0, plat_y), 0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 28.0, Color(0.18, 0.16, 0.14))
	draw_circle(Vector2.ZERO, 25.0, Color(0.28, 0.25, 0.22))
	draw_circle(Vector2.ZERO, 20.0, Color(0.35, 0.32, 0.28))
	for si in range(8):
		var sa = TAU * float(si) / 8.0
		draw_circle(Vector2.from_angle(sa) * 16.0, 3.0, Color(0.25, 0.22, 0.20, 0.4))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# Platform top highlight
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
			0: pip_col = Color(0.5, 0.4, 0.3)    # rope brown
			1: pip_col = Color(0.5, 0.3, 0.65)    # music purple
			2: pip_col = Color(0.85, 0.75, 0.25)  # chandelier gold
			3: pip_col = Color(0.85, 0.15, 0.15)  # dark red
		draw_circle(pip_pos, 5.5, Color(pip_col.r, pip_col.g, pip_col.b, 0.15))
		draw_circle(pip_pos, 4.0, pip_col)
		draw_circle(pip_pos + Vector2(-0.5, -0.5), 1.5, Color(1.0, 1.0, 1.0, 0.3))

	# === T1+: Punjab Lasso rope coils around base of platform ===
	if upgrade_tier >= 1:
		var lasso_glow = _lasso_flash if _lasso_flash > 0.0 else 0.0
		# Main rope coil (left of platform)
		var rope_center = Vector2(-20, plat_y + 2) + body_offset * 0.15
		for i in range(14):
			var rope_a1 = float(i) * TAU / 6.0
			var rope_a2 = float(i + 1) * TAU / 6.0
			var rope_r = 8.0 + float(i) * 0.5
			var rp1 = rope_center + Vector2(cos(rope_a1) * rope_r, sin(rope_a1) * rope_r * 0.45)
			var rp2 = rope_center + Vector2(cos(rope_a2) * rope_r, sin(rope_a2) * rope_r * 0.45)
			var rope_col = Color(0.7 + lasso_glow * 0.3, 0.55 + lasso_glow * 0.3, 0.3 + lasso_glow * 0.1, 0.65)
			draw_line(rp1, rp2, rope_col, 2.5)
			if i % 3 == 0:
				draw_line(rp1, rp2, Color(0.8, 0.65, 0.35, 0.2), 1.0)
		# Glow when lasso activates
		if lasso_glow > 0.0:
			draw_circle(rope_center, 16.0, Color(0.9, 0.75, 0.3, lasso_glow * 0.2))
		# Second small coil (right side)
		var rope2_center = Vector2(18, plat_y + 3) + body_offset * 0.1
		for i in range(10):
			var rope_a1 = float(i) * TAU / 4.0 + 0.5
			var rope_a2 = float(i + 1) * TAU / 4.0 + 0.5
			var rope_r = 6.0 + float(i) * 0.45
			var rp1 = rope2_center + Vector2(cos(rope_a1) * rope_r, sin(rope_a1) * rope_r * 0.45)
			var rp2 = rope2_center + Vector2(cos(rope_a2) * rope_r, sin(rope_a2) * rope_r * 0.45)
			draw_line(rp1, rp2, Color(0.65 + lasso_glow * 0.25, 0.5 + lasso_glow * 0.2, 0.28, 0.55), 2.5)

	# === T2+: Organ pipe silhouettes behind/above character ===
	if upgrade_tier >= 2:
		for i in range(9):
			var pipe_x = body_offset.x - 40.0 + float(i) * 10.0
			var pipe_h = 30.0 + abs(float(i) - 4.0) * 12.0
			var pipe_base_y = body_offset.y - 56.0
			# Pipe shadow
			draw_line(Vector2(pipe_x + 2.0, pipe_base_y), Vector2(pipe_x + 2.0, pipe_base_y - pipe_h), Color(0.15, 0.12, 0.10, 0.25), 6.0)
			# Pipe body (bronze)
			draw_line(Vector2(pipe_x, pipe_base_y), Vector2(pipe_x, pipe_base_y - pipe_h), Color(0.45, 0.40, 0.30, 0.45), 6.0)
			# Pipe highlight
			draw_line(Vector2(pipe_x - 1.5, pipe_base_y), Vector2(pipe_x - 1.5, pipe_base_y - pipe_h), Color(0.60, 0.55, 0.45, 0.3), 2.0)
			# Pipe cap
			draw_circle(Vector2(pipe_x, pipe_base_y - pipe_h), 5.0, Color(0.50, 0.45, 0.35, 0.4))
			draw_circle(Vector2(pipe_x, pipe_base_y - pipe_h), 3.0, Color(0.60, 0.55, 0.45, 0.3))
		# Organ base bar
		draw_line(Vector2(body_offset.x - 42, body_offset.y - 56), Vector2(body_offset.x + 42, body_offset.y - 56), Color(0.30, 0.24, 0.18, 0.4), 2.5)

	# === T2+: Floating music notes orbiting character ===
	if upgrade_tier >= 2:
		for ni in range(3):
			var note_a = _time * 0.8 + float(ni) * TAU / 3.0
			var note_r = 32.0 + sin(_time * 1.5 + float(ni) * 1.2) * 5.0
			var note_bob = sin(_time * 2.0 + float(ni) * 2.0) * 3.0
			var note_pos = body_offset + Vector2(cos(note_a) * note_r, sin(note_a) * note_r * 0.5 + note_bob - 10.0)
			var n_alpha = 0.4 + sin(_time * 1.5 + float(ni) * 0.9) * 0.12
			# Note glow
			draw_circle(note_pos, 7.0, Color(0.5, 0.35, 0.8, n_alpha * 0.15))
			# Note head (oval)
			draw_circle(note_pos, 3.5, Color(0.55, 0.4, 0.85, n_alpha))
			draw_circle(note_pos, 2.2, Color(0.65, 0.5, 0.95, n_alpha * 0.6))
			# Note stem
			draw_line(note_pos + Vector2(2.5, 0), note_pos + Vector2(2.5, -12.0), Color(0.55, 0.4, 0.85, n_alpha * 0.8), 1.5)
			# Note flag
			draw_line(note_pos + Vector2(2.5, -12.0), note_pos + Vector2(7.0, -8.0), Color(0.55, 0.4, 0.85, n_alpha * 0.6), 1.5)
			draw_line(note_pos + Vector2(2.5, -9.0), note_pos + Vector2(6.0, -6.0), Color(0.55, 0.4, 0.85, n_alpha * 0.4), 1.2)

	# === T3+: Chandelier hovering above head ===
	if upgrade_tier >= 3:
		var chand_center = body_offset + Vector2(0, -66.0)
		var chand_sway = sin(_time * 0.8) * 2.0
		chand_center.x += chand_sway
		# Chain links
		for ci in range(4):
			var cy = chand_center.y + 18.0 - float(ci) * 5.0
			var cx_off = chand_sway * float(ci) * 0.12
			draw_arc(Vector2(chand_center.x + cx_off, cy), 2.5, 0, TAU, 8, Color(0.75, 0.65, 0.25, 0.4), 1.5)
		# Main chandelier frame
		draw_arc(chand_center, 18.0, 0, PI, 14, Color(0.82, 0.72, 0.3, 0.65), 3.0)
		draw_arc(chand_center, 15.0, 0, PI, 12, Color(0.70, 0.60, 0.2, 0.3), 2.0)
		# Cross bar
		draw_line(chand_center + Vector2(-18, 0), chand_center + Vector2(18, 0), Color(0.82, 0.72, 0.3, 0.55), 2.5)
		# Center gem
		draw_circle(chand_center, 5.0, Color(0.95, 0.85, 0.3, 0.75))
		draw_circle(chand_center, 3.0, Color(1.0, 0.95, 0.6, 0.5))
		draw_circle(chand_center, 1.5, Color(1.0, 1.0, 0.85, 0.7))
		# Dangling crystals
		for i in range(7):
			var cx = chand_center.x - 18.0 + float(i) * 6.0
			var crystal_swing = sin(_time * 2.0 + float(i) * 1.3) * 2.5 + chand_sway * 0.5
			var crystal_base = Vector2(cx + crystal_swing, chand_center.y)
			var c_len = 8.0 + float(i % 3) * 4.0
			var crystal_end = crystal_base + Vector2(0, c_len)
			# Thread
			draw_line(crystal_base, crystal_end, Color(0.85, 0.8, 0.6, 0.4), 0.8)
			# Diamond shape
			var c_mid = crystal_base + Vector2(0, c_len * 0.5)
			draw_line(c_mid - Vector2(2.5, 0), crystal_end, Color(0.9, 0.88, 0.75, 0.5), 1.2)
			draw_line(c_mid + Vector2(2.5, 0), crystal_end, Color(0.9, 0.88, 0.75, 0.5), 1.2)
			draw_line(c_mid - Vector2(2.5, 0), crystal_base + Vector2(0, c_len * 0.3), Color(0.9, 0.88, 0.75, 0.5), 1.2)
			draw_line(c_mid + Vector2(2.5, 0), crystal_base + Vector2(0, c_len * 0.3), Color(0.9, 0.88, 0.75, 0.5), 1.2)
			# Crystal drop glow
			draw_circle(crystal_end, 3.0, Color(1.0, 0.95, 0.8, 0.5))
			draw_circle(crystal_end, 1.5, Color(1.0, 1.0, 0.9, 0.35))
			# Prismatic sparkle
			var sparkle_phase = sin(_time * 3.5 + float(i) * 1.7)
			if sparkle_phase > 0.3:
				var prism_alpha = (sparkle_phase - 0.3) * 0.6
				var prism_hue = fmod(float(i) * 0.14 + _time * 0.3, 1.0)
				var r_c = 0.5 + sin(prism_hue * TAU) * 0.5
				var g_c = 0.5 + sin(prism_hue * TAU + TAU / 3.0) * 0.5
				var b_c = 0.5 + sin(prism_hue * TAU + 2.0 * TAU / 3.0) * 0.5
				draw_circle(crystal_end + Vector2(0, 1.5), 1.5, Color(r_c, g_c, b_c, prism_alpha * 0.35))
		# Candle flames on chandelier
		for i in range(5):
			var flame_x = chand_center.x - 12.0 + float(i) * 6.0
			var flicker = sin(_time * 6.0 + float(i) * 2.3) * 1.5
			var flicker2 = cos(_time * 4.5 + float(i) * 1.7) * 0.8
			# Outer glow
			draw_circle(Vector2(flame_x, chand_center.y - 3.0 + flicker), 5.0, Color(1.0, 0.7, 0.15, 0.18))
			# Main flame
			draw_circle(Vector2(flame_x, chand_center.y - 4.0 + flicker), 3.5, Color(1.0, 0.82, 0.25, 0.7))
			# Inner flame
			draw_circle(Vector2(flame_x + flicker2 * 0.3, chand_center.y - 5.5 + flicker), 2.0, Color(1.0, 1.0, 0.65, 0.55))
			# Tip
			draw_circle(Vector2(flame_x, chand_center.y - 7.0 + flicker * 1.2), 0.8, Color(1.0, 1.0, 0.9, 0.35))

	# === CHARACTER POSITIONS (tall dramatic anime proportions ~60px) ===
	var feet_y = body_offset + Vector2(0, 14.0)
	var leg_top = body_offset + Vector2(0, -4.0)
	var torso_center = body_offset + Vector2(0, -14.0)
	var neck_base = body_offset + Vector2(0, -24.0)
	var head_center = body_offset + Vector2(0, -36.0)

	# === CAPE (red-lined black cape — behind the body, dramatic full-length) ===
	var cape_sway_val = sin(_time * 1.3) * 4.0
	var cape_billow = 0.0
	if upgrade_tier >= 4:
		cape_billow = sin(_time * 0.7) * 6.0 + sin(_time * 1.9) * 3.0
	cape_sway_val += cape_billow

	# Outer cape (black) — dramatic sweep from shoulders past legs
	var cape_pts = PackedVector2Array([
		neck_base + Vector2(-20 - cape_sway_val * 0.3, 0),
		neck_base + Vector2(-24 - cape_sway_val * 0.5, 14),
		body_offset + Vector2(-22 - cape_sway_val * 0.7, 22),
		feet_y + Vector2(-14 - cape_sway_val * 0.4, 6),
		feet_y + Vector2(14 + cape_sway_val * 0.4, 6),
		body_offset + Vector2(22 + cape_sway_val * 0.7, 22),
		neck_base + Vector2(24 + cape_sway_val * 0.5, 14),
		neck_base + Vector2(20 + cape_sway_val * 0.3, 0),
	])
	draw_colored_polygon(cape_pts, Color(0.04, 0.02, 0.06))
	# Cape red lining (visible on left side — the dramatic flourish)
	var lining_pts = PackedVector2Array([
		neck_base + Vector2(-19 - cape_sway_val * 0.3, 2),
		neck_base + Vector2(-22 - cape_sway_val * 0.5, 12),
		body_offset + Vector2(-20 - cape_sway_val * 0.6, 20),
		feet_y + Vector2(-13 - cape_sway_val * 0.35, 4),
		torso_center + Vector2(-8, 12),
		torso_center + Vector2(-10, 0),
		neck_base + Vector2(-12, 2),
	])
	draw_colored_polygon(lining_pts, Color(0.65, 0.06, 0.08, 0.7))
	# Satin sheen on lining
	var sheen_pts = PackedVector2Array([
		neck_base + Vector2(-18 - cape_sway_val * 0.35, 4),
		neck_base + Vector2(-20 - cape_sway_val * 0.45, 14),
		torso_center + Vector2(-14 - cape_sway_val * 0.3, 8),
		torso_center + Vector2(-13, -2),
	])
	draw_colored_polygon(sheen_pts, Color(0.85, 0.15, 0.18, 0.25))
	# Red lining right side (less visible)
	var lining_r_pts = PackedVector2Array([
		neck_base + Vector2(12, 2),
		torso_center + Vector2(10, 0),
		torso_center + Vector2(8, 12),
		feet_y + Vector2(13 + cape_sway_val * 0.35, 4),
		body_offset + Vector2(20 + cape_sway_val * 0.6, 20),
		neck_base + Vector2(22 + cape_sway_val * 0.5, 12),
		neck_base + Vector2(19 + cape_sway_val * 0.3, 2),
	])
	draw_colored_polygon(lining_r_pts, Color(0.55, 0.05, 0.07, 0.4))
	# Cape fold lines
	for fold_i in range(4):
		var fold_t = float(fold_i) / 3.0
		var fold_x = -18.0 + fold_t * 36.0
		var fold_top = neck_base + Vector2(fold_x, 0)
		var fold_bot = feet_y + Vector2(fold_x + cape_sway_val * (fold_t - 0.5) * 0.3, 4)
		draw_line(fold_top, fold_bot, Color(0.08, 0.04, 0.1, 0.25), 1.0)
	# Cape outline
	for ci in range(cape_pts.size()):
		var next_i = (ci + 1) % cape_pts.size()
		draw_line(cape_pts[ci], cape_pts[next_i], Color(0.06, 0.03, 0.08, 0.4), 1.0)

	# === FORMAL BLACK DRESS SHOES (polished oxford) ===
	var l_foot = feet_y + Vector2(-7, 0)
	var r_foot = feet_y + Vector2(7, 0)
	# Shoe soles
	draw_circle(l_foot + Vector2(0, 1), 5.0, Color(0.02, 0.02, 0.02))
	draw_circle(r_foot + Vector2(0, 1), 5.0, Color(0.02, 0.02, 0.02))
	# Shoe bases (polished black)
	draw_circle(l_foot, 5.0, Color(0.04, 0.04, 0.04))
	draw_circle(l_foot, 3.8, Color(0.10, 0.10, 0.10))
	draw_circle(r_foot, 5.0, Color(0.04, 0.04, 0.04))
	draw_circle(r_foot, 3.8, Color(0.10, 0.10, 0.10))
	# Patent leather shine
	draw_circle(l_foot + Vector2(1, -1.5), 2.0, Color(0.30, 0.30, 0.35, 0.5))
	draw_circle(r_foot + Vector2(-1, -1.5), 2.0, Color(0.30, 0.30, 0.35, 0.5))
	# Shoe toe highlights
	draw_circle(l_foot + Vector2(2, 0.5), 1.2, Color(0.25, 0.25, 0.30, 0.35))
	draw_circle(r_foot + Vector2(-2, 0.5), 1.2, Color(0.25, 0.25, 0.30, 0.35))
	# Heel detail
	draw_line(l_foot + Vector2(-2, 1), l_foot + Vector2(-2, 3), Color(0.06, 0.06, 0.06), 2.0)
	draw_line(r_foot + Vector2(2, 1), r_foot + Vector2(2, 3), Color(0.06, 0.06, 0.06), 2.0)

	# === LONG ELEGANT LEGS (black tuxedo trousers with satin stripe, 18px) ===
	var l_knee = leg_top + Vector2(-5, 9)
	var r_knee = leg_top + Vector2(5, 9)
	# Upper legs (thigh — from leg_top to knee)
	draw_line(leg_top + Vector2(-5, 0), l_knee, Color(0.04, 0.03, 0.06), 6.0)
	draw_line(leg_top + Vector2(5, 0), r_knee, Color(0.04, 0.03, 0.06), 6.0)
	draw_line(leg_top + Vector2(-5, 0), l_knee, Color(0.08, 0.06, 0.10), 4.5)
	draw_line(leg_top + Vector2(5, 0), r_knee, Color(0.08, 0.06, 0.10), 4.5)
	# Lower legs (knee to ankle)
	draw_line(l_knee, l_foot + Vector2(0, -3), Color(0.04, 0.03, 0.06), 5.5)
	draw_line(r_knee, r_foot + Vector2(0, -3), Color(0.04, 0.03, 0.06), 5.5)
	draw_line(l_knee, l_foot + Vector2(0, -3), Color(0.08, 0.06, 0.10), 4.0)
	draw_line(r_knee, r_foot + Vector2(0, -3), Color(0.08, 0.06, 0.10), 4.0)
	# Satin side stripe (formal tuxedo detail — full length)
	draw_line(l_foot + Vector2(-2, -2), leg_top + Vector2(-3, 0), Color(0.18, 0.16, 0.20, 0.35), 1.0)
	draw_line(r_foot + Vector2(2, -2), leg_top + Vector2(3, 0), Color(0.18, 0.16, 0.20, 0.35), 1.0)
	# Knee crease detail
	draw_line(l_knee + Vector2(-3, 0), l_knee + Vector2(3, 0), Color(0.03, 0.02, 0.05, 0.3), 1.0)
	draw_line(r_knee + Vector2(-3, 0), r_knee + Vector2(3, 0), Color(0.03, 0.02, 0.05, 0.3), 1.0)

	# === BLACK TUXEDO TORSO — broad shoulders, V-taper to waist ===
	var torso_pts = PackedVector2Array([
		torso_center + Vector2(-9, 10),    # waist left
		torso_center + Vector2(-11, 2),
		neck_base + Vector2(-17, 0),       # shoulder left (broad ±17)
		neck_base + Vector2(17, 0),        # shoulder right
		torso_center + Vector2(11, 2),
		torso_center + Vector2(9, 10),     # waist right (narrow ±9)
	])
	draw_colored_polygon(torso_pts, Color(0.06, 0.04, 0.08))
	# Defined chest contour
	draw_arc(torso_center + Vector2(-4, -2), 6.0, PI * 0.2, PI * 0.9, 8, Color(0.10, 0.08, 0.12, 0.2), 1.5)
	draw_arc(torso_center + Vector2(4, -2), 6.0, PI * 0.1, PI * 0.8, 8, Color(0.10, 0.08, 0.12, 0.2), 1.5)
	# Torso shadow (darker sides for V-taper definition)
	var torso_shadow_l = PackedVector2Array([
		torso_center + Vector2(-9, 10),
		torso_center + Vector2(-11, 2),
		neck_base + Vector2(-17, 0),
		neck_base + Vector2(-10, 0),
		torso_center + Vector2(-6, 8),
	])
	draw_colored_polygon(torso_shadow_l, Color(0.02, 0.01, 0.04, 0.3))
	var torso_shadow_r = PackedVector2Array([
		neck_base + Vector2(10, 0),
		neck_base + Vector2(17, 0),
		torso_center + Vector2(11, 2),
		torso_center + Vector2(9, 10),
		torso_center + Vector2(6, 8),
	])
	draw_colored_polygon(torso_shadow_r, Color(0.02, 0.01, 0.04, 0.25))

	# White dress shirt front (visible between lapels)
	var shirt_pts = PackedVector2Array([
		neck_base + Vector2(-5, 2),
		neck_base + Vector2(5, 2),
		torso_center + Vector2(5, 6),
		torso_center + Vector2(-5, 6),
	])
	draw_colored_polygon(shirt_pts, Color(0.95, 0.93, 0.91))
	# Shirt pleat lines
	draw_line(neck_base + Vector2(-2, 2), torso_center + Vector2(-2, 5), Color(0.88, 0.86, 0.84, 0.3), 0.7)
	draw_line(neck_base + Vector2(2, 2), torso_center + Vector2(2, 5), Color(0.88, 0.86, 0.84, 0.3), 0.7)
	# Shirt buttons (spaced along taller torso)
	for bi in range(4):
		var btn_y_off = -6.0 + float(bi) * 4.5
		var btn_pos = torso_center + Vector2(0, btn_y_off)
		draw_circle(btn_pos, 1.2, Color(0.85, 0.83, 0.80))
		draw_circle(btn_pos + Vector2(-0.3, -0.3), 0.5, Color(1.0, 1.0, 1.0, 0.35))

	# Peaked lapels (V-shape, satin-faced) — adjusted for taller torso
	# Left lapel
	var lapel_l = PackedVector2Array([
		neck_base + Vector2(-15, 0),
		neck_base + Vector2(-5, 2),
		torso_center + Vector2(-3, 0),
		torso_center + Vector2(-8, -1),
		neck_base + Vector2(-16, 4),
	])
	draw_colored_polygon(lapel_l, Color(0.08, 0.06, 0.10))
	# Satin face on lapel
	draw_line(neck_base + Vector2(-15, 0), torso_center + Vector2(-5, 0), Color(0.14, 0.11, 0.18, 0.4), 1.5)
	# Peaked tip
	draw_line(neck_base + Vector2(-15, 0), neck_base + Vector2(-18, -2), Color(0.14, 0.11, 0.18, 0.4), 1.0)
	# Right lapel
	var lapel_r = PackedVector2Array([
		neck_base + Vector2(5, 2),
		neck_base + Vector2(15, 0),
		neck_base + Vector2(16, 4),
		torso_center + Vector2(8, -1),
		torso_center + Vector2(3, 0),
	])
	draw_colored_polygon(lapel_r, Color(0.08, 0.06, 0.10))
	draw_line(neck_base + Vector2(15, 0), torso_center + Vector2(5, 0), Color(0.14, 0.11, 0.18, 0.4), 1.5)
	draw_line(neck_base + Vector2(15, 0), neck_base + Vector2(18, -2), Color(0.14, 0.11, 0.18, 0.4), 1.0)

	# Black bow tie (at neck_base)
	var tie_pos = neck_base + Vector2(0, 2)
	# Left bow wing
	draw_arc(tie_pos + Vector2(-4, 0), 3.0, PI * 0.3, PI * 1.7, 8, Color(0.06, 0.04, 0.08), 2.5)
	# Right bow wing
	draw_arc(tie_pos + Vector2(4, 0), 3.0, -PI * 0.7, PI * 0.7, 8, Color(0.06, 0.04, 0.08), 2.5)
	# Knot center
	draw_circle(tie_pos, 1.8, Color(0.04, 0.03, 0.06))
	draw_circle(tie_pos, 1.0, Color(0.10, 0.08, 0.12))

	# === SHOULDERS / SLEEVES (broad tuxedo shoulders ±17) ===
	# Left shoulder
	draw_circle(neck_base + Vector2(-17, 0), 7.0, Color(0.04, 0.03, 0.06, 0.4))
	draw_circle(neck_base + Vector2(-17, 0), 6.0, Color(0.06, 0.04, 0.08))
	draw_circle(neck_base + Vector2(-17, 1), 3.5, Color(0.10, 0.08, 0.12, 0.3))
	# Right shoulder
	draw_circle(neck_base + Vector2(17, 0), 7.0, Color(0.04, 0.03, 0.06, 0.4))
	draw_circle(neck_base + Vector2(17, 0), 6.0, Color(0.06, 0.04, 0.08))
	draw_circle(neck_base + Vector2(17, 1), 3.5, Color(0.10, 0.08, 0.12, 0.3))

	# === CAPE CLASP at collar (golden brooch) ===
	var clasp_pos = neck_base + Vector2(-14, 0)
	draw_circle(clasp_pos, 3.5, Color(0.8, 0.65, 0.2, 0.8))
	draw_circle(clasp_pos, 2.2, Color(0.9, 0.78, 0.35, 0.6))
	draw_circle(clasp_pos, 1.0, Color(1.0, 0.9, 0.5, 0.5))
	var clasp2_pos = neck_base + Vector2(14, 0)
	draw_circle(clasp2_pos, 3.5, Color(0.8, 0.65, 0.2, 0.8))
	draw_circle(clasp2_pos, 2.2, Color(0.9, 0.78, 0.35, 0.6))

	# === LEFT ARM — holds cape edge (dramatic pose, elegant) ===
	var l_elbow = neck_base + Vector2(-20, 12 + sin(_time * 1.5) * 1.0)
	var l_hand_pos = torso_center + Vector2(-20, 6 + sin(_time * 1.5) * 1.5)
	# Upper arm (from shoulder to elbow, 4px)
	draw_line(neck_base + Vector2(-17, 0), l_elbow, Color(0.04, 0.03, 0.06), 5.0)
	draw_line(neck_base + Vector2(-17, 0), l_elbow, Color(0.06, 0.04, 0.08), 4.0)
	# Forearm (elbow to hand)
	draw_line(l_elbow, l_hand_pos, Color(0.04, 0.03, 0.06), 5.0)
	draw_line(l_elbow, l_hand_pos, Color(0.06, 0.04, 0.08), 4.0)
	# White glove cuff
	draw_arc(l_hand_pos + Vector2(0, -2), 3.5, 0, TAU, 8, Color(0.95, 0.93, 0.91), 2.0)
	# White-gloved hand (gripping cape)
	draw_circle(l_hand_pos, 3.5, Color(0.90, 0.88, 0.86))
	draw_circle(l_hand_pos, 2.8, Color(0.95, 0.93, 0.91))
	# Fingers curled around cape (white gloves)
	for fi in range(3):
		var finger_angle = PI * 0.6 + float(fi) * 0.3
		draw_circle(l_hand_pos + Vector2.from_angle(finger_angle) * 3.0, 1.2, Color(0.97, 0.95, 0.93))

	# === RIGHT ARM — extends toward aim (conducting hand, weapon arm, elegant) ===
	var attack_extend = _attack_anim * 12.0
	var r_elbow = neck_base + Vector2(19, 10)
	var r_hand_pos = neck_base + Vector2(17, 0) + dir * (18.0 + attack_extend)
	# Upper arm (from shoulder to elbow, 4px)
	draw_line(neck_base + Vector2(17, 0), r_elbow, Color(0.04, 0.03, 0.06), 5.0)
	draw_line(neck_base + Vector2(17, 0), r_elbow, Color(0.06, 0.04, 0.08), 4.0)
	# Forearm toward aim
	draw_line(r_elbow, r_hand_pos, Color(0.04, 0.03, 0.06), 4.5)
	draw_line(r_elbow, r_hand_pos, Color(0.06, 0.04, 0.08), 3.5)
	# White glove cuff
	draw_arc(r_hand_pos + dir * (-4.0), 3.5, 0, TAU, 8, Color(0.95, 0.93, 0.91), 2.0)
	# White-gloved hand
	draw_circle(r_hand_pos, 3.5, Color(0.90, 0.88, 0.86))
	draw_circle(r_hand_pos, 2.8, Color(0.95, 0.93, 0.91))
	# Conducting fingers (extended elegantly, white gloves)
	for fi in range(4):
		var fa = aim_angle + (float(fi) - 1.5) * 0.25
		draw_circle(r_hand_pos + Vector2.from_angle(fa) * 3.8, 1.2, Color(0.97, 0.95, 0.93))

	# === MUSIC NOTES near conducting hand (weapon) ===
	var note_base = r_hand_pos + dir * 8.0
	# Small music notes floating near hand
	for ni in range(2):
		var note_off = dir.rotated(PI * 0.3 * float(ni) - PI * 0.15) * (6.0 + float(ni) * 4.0)
		var note_pos = note_base + note_off
		var n_bob_y = sin(_time * 4.0 + float(ni) * 2.5) * 2.0
		note_pos.y += n_bob_y
		# Note head
		draw_circle(note_pos, 2.5, Color(0.55, 0.35, 0.85, 0.7))
		# Note stem
		draw_line(note_pos + Vector2(1.5, 0), note_pos + Vector2(1.5, -8.0), Color(0.55, 0.35, 0.85, 0.6), 1.2)
		# Note flag
		draw_line(note_pos + Vector2(1.5, -8.0), note_pos + Vector2(5.0, -5.0), Color(0.55, 0.35, 0.85, 0.45), 1.2)

	# Attack flash — music notes shooting toward aim direction
	if _attack_anim > 0.3:
		var flash_alpha = (_attack_anim - 0.3) * 1.4
		for ai in range(3):
			var a_dist = 12.0 + float(ai) * 10.0 + (1.0 - _attack_anim) * 20.0
			var a_spread = float(ai - 1) * 0.2
			var a_pos = r_hand_pos + dir.rotated(a_spread) * a_dist
			# Flying note
			draw_circle(a_pos, 3.0 - float(ai) * 0.5, Color(0.6, 0.3, 0.9, flash_alpha * (0.7 - float(ai) * 0.15)))
			# Trailing sparkle
			draw_circle(a_pos - dir * 4.0, 1.5, Color(0.7, 0.5, 1.0, flash_alpha * 0.3))

	# === ELEGANT NECK (visible, flesh-colored with white shirt collar) ===
	# Neck (3px wide, from neck_base up to head)
	draw_line(neck_base + Vector2(0, 0), head_center + Vector2(0, 12), Color(0.04, 0.03, 0.06), 8.0)
	draw_line(neck_base + Vector2(0, 0), head_center + Vector2(0, 12), skin_shadow, 6.0)
	draw_line(neck_base + Vector2(0, 0), head_center + Vector2(0, 12), skin_base, 5.0)
	# Neck highlight
	draw_line(neck_base + Vector2(-1, 1), head_center + Vector2(-1, 11), skin_highlight, 2.0)
	# White shirt collar points (visible at neck base)
	var collar_l = PackedVector2Array([
		neck_base + Vector2(-6, 2),
		neck_base + Vector2(-3, -2),
		neck_base + Vector2(0, 2),
	])
	draw_colored_polygon(collar_l, Color(0.95, 0.93, 0.91))
	draw_line(neck_base + Vector2(-6, 2), neck_base + Vector2(-3, -2), Color(0.85, 0.83, 0.80, 0.4), 0.8)
	var collar_r = PackedVector2Array([
		neck_base + Vector2(0, 2),
		neck_base + Vector2(3, -2),
		neck_base + Vector2(6, 2),
	])
	draw_colored_polygon(collar_r, Color(0.95, 0.93, 0.91))
	draw_line(neck_base + Vector2(6, 2), neck_base + Vector2(3, -2), Color(0.85, 0.83, 0.80, 0.4), 0.8)

	# === HEAD (proportional anime head, smaller than chibi) ===
	var head_r = 12.0

	# Head base (pale skin)
	draw_circle(head_center, head_r + 1.0, Color(0.0, 0.0, 0.0, 0.15))
	draw_circle(head_center, head_r, skin_shadow)
	draw_circle(head_center, head_r - 1.0, skin_base)
	# Skin highlight (upper left)
	draw_circle(head_center + Vector2(-2, -3), head_r * 0.5, skin_highlight)

	# === SLICKED BLACK HAIR (left side visible, swept back — scaled for 12px head) ===
	# Hair covers top and left side of head
	var hair_pts = PackedVector2Array([
		head_center + Vector2(-head_r + 1, 3),
		head_center + Vector2(-head_r + 1, -3),
		head_center + Vector2(-head_r + 3, -7),
		head_center + Vector2(-4, -head_r - 2),
		head_center + Vector2(2, -head_r - 1),
		head_center + Vector2(6, -head_r + 1),
		head_center + Vector2(head_r - 1, -4),
		head_center + Vector2(head_r - 2, -1),
		head_center + Vector2(5, -1),
		head_center + Vector2(0, -3),
		head_center + Vector2(-3, -1),
		head_center + Vector2(-6, 0),
	])
	draw_colored_polygon(hair_pts, Color(0.06, 0.04, 0.06))
	# Hair highlight streaks (slicked sheen)
	draw_line(head_center + Vector2(-3, -head_r), head_center + Vector2(-6, -1), Color(0.15, 0.12, 0.18, 0.4), 1.5)
	draw_line(head_center + Vector2(-1, -head_r - 1), head_center + Vector2(-3, -3), Color(0.18, 0.15, 0.22, 0.35), 1.2)
	draw_line(head_center + Vector2(2, -head_r), head_center + Vector2(1, -4), Color(0.15, 0.12, 0.18, 0.3), 1.0)
	# Hair over right side (above mask)
	draw_line(head_center + Vector2(5, -head_r + 1), head_center + Vector2(head_r - 2, -3), Color(0.06, 0.04, 0.06), 3.0)

	# === WHITE HALF-MASK (right side of face — scaled for 12px head) ===
	var mask_center = head_center + Vector2(4, -1)
	# Mask glow behind (subtle ethereal light)
	var mask_glow_alpha = 0.08 + sin(_time * 2.0) * 0.04
	draw_circle(mask_center, head_r * 0.65, Color(0.9, 0.9, 1.0, mask_glow_alpha))
	# Mask shape (scaled ~0.75x from original)
	var mask_pts = PackedVector2Array([
		head_center + Vector2(1, -9),
		head_center + Vector2(5, -10),
		head_center + Vector2(9, -7),
		head_center + Vector2(10, -3),
		head_center + Vector2(10, 1),
		head_center + Vector2(7, 5),
		head_center + Vector2(4, 7),
		head_center + Vector2(1, 4),
		head_center + Vector2(1, -2),
	])
	draw_colored_polygon(mask_pts, Color(0.96, 0.95, 0.93))
	# Mask porcelain sheen
	var mask_sheen_pts = PackedVector2Array([
		head_center + Vector2(2, -8),
		head_center + Vector2(6, -9),
		head_center + Vector2(8, -6),
		head_center + Vector2(7, -1),
		head_center + Vector2(4, -1),
		head_center + Vector2(2, -3),
	])
	draw_colored_polygon(mask_sheen_pts, Color(1.0, 1.0, 1.0, 0.35))
	# Mask edge line
	draw_line(head_center + Vector2(1, -9), head_center + Vector2(1, 4), Color(0.75, 0.72, 0.70, 0.5), 1.2)
	# Mask eye hole (right eye is hidden behind mask)
	var mask_eye_pos = head_center + Vector2(5, -2)
	draw_circle(mask_eye_pos, 2.8, Color(0.0, 0.0, 0.0, 0.4))
	draw_circle(mask_eye_pos, 2.0, Color(0.02, 0.02, 0.02, 0.3))
	# Mask nostril hint
	draw_circle(head_center + Vector2(4, 2), 0.8, Color(0.85, 0.83, 0.80, 0.3))
	# Mask outline
	for mi in range(mask_pts.size()):
		var next_mi = (mi + 1) % mask_pts.size()
		draw_line(mask_pts[mi], mask_pts[next_mi], Color(0.80, 0.78, 0.75, 0.4), 0.8)

	# Tier 4: Mask eye glows bright red/orange
	if upgrade_tier >= 4:
		var eye_glow_alpha = 0.5 + sin(_time * 3.0) * 0.25
		draw_circle(mask_eye_pos, 3.8, Color(0.9, 0.2, 0.05, eye_glow_alpha * 0.3))
		draw_circle(mask_eye_pos, 2.5, Color(1.0, 0.35, 0.1, eye_glow_alpha * 0.5))
		draw_circle(mask_eye_pos, 1.2, Color(1.0, 0.6, 0.2, eye_glow_alpha * 0.7))

	# === LEFT SIDE VISIBLE FACE — dramatic single eye (scaled for 12px head) ===
	var l_eye_pos = head_center + Vector2(-4, -2)
	# Eye socket shadow
	draw_circle(l_eye_pos, 3.8, Color(0.60, 0.52, 0.48, 0.25))
	# Eye white
	draw_circle(l_eye_pos, 3.0, Color(0.96, 0.96, 0.96))
	# Iris (dark, intense)
	draw_circle(l_eye_pos + dir * 0.8, 2.0, Color(0.15, 0.10, 0.08))
	# Pupil
	draw_circle(l_eye_pos + dir * 1.0, 1.2, Color(0.02, 0.02, 0.02))
	# Iris highlight (tiny catch light)
	draw_circle(l_eye_pos + Vector2(-0.4, -0.8), 0.6, Color(1.0, 1.0, 1.0, 0.6))
	# Intense eyebrow (angled dramatically)
	draw_line(head_center + Vector2(-7, -5), head_center + Vector2(-2, -6), Color(0.06, 0.04, 0.06), 1.8)
	# Under-eye shadow (tormented look)
	draw_arc(l_eye_pos, 3.5, 0.3, PI - 0.3, 8, Color(0.55, 0.45, 0.50, 0.2), 1.0)
	# Eyelid (upper, intense)
	draw_arc(l_eye_pos, 3.0, PI + 0.3, TAU - 0.3, 8, Color(0.06, 0.04, 0.06), 1.3)

	# Right eyebrow (on mask, subtle sculpted line)
	draw_line(head_center + Vector2(2, -6), head_center + Vector2(8, -5), Color(0.80, 0.78, 0.76, 0.3), 1.3)

	# === MOUTH / JAW (scaled for 12px head) ===
	# Strong angular jaw line
	draw_line(head_center + Vector2(-8, 3), head_center + Vector2(-3, 8), Color(0.65, 0.58, 0.52, 0.3), 1.3)
	draw_line(head_center + Vector2(-3, 8), head_center + Vector2(1, 8), Color(0.65, 0.58, 0.52, 0.25), 1.0)
	# Chin (angular, masculine)
	draw_circle(head_center + Vector2(-1, 8), 2.8, skin_shadow)
	draw_circle(head_center + Vector2(-1, 8), 2.0, skin_base)
	# Thin firm lips (slightly frowning, dramatic)
	draw_line(head_center + Vector2(-4, 4), head_center + Vector2(0, 4.5), Color(0.62, 0.45, 0.42), 1.3)
	draw_line(head_center + Vector2(-4, 4), head_center + Vector2(-2, 3.5), Color(0.70, 0.52, 0.48, 0.3), 0.7)
	# Nose (left side visible, elegant bridge)
	draw_line(head_center + Vector2(-1, -3), head_center + Vector2(-2, 1.5), Color(0.75, 0.68, 0.62, 0.4), 1.0)
	draw_line(head_center + Vector2(-2, 1.5), head_center + Vector2(-1, 2.5), Color(0.75, 0.68, 0.62, 0.3), 0.8)

	# === TIER 4: DARK RED OPERA AURA on character ===
	if upgrade_tier >= 4:
		# Subtle red glow around character silhouette (adjusted for taller body)
		draw_circle(torso_center, 28.0, Color(0.6, 0.08, 0.08, 0.06 + sin(_time * 2.0) * 0.03))
		draw_circle(head_center, 16.0, Color(0.6, 0.08, 0.08, 0.05 + sin(_time * 2.5) * 0.02))

	# === T2+: Music aura ring ===
	if upgrade_tier >= 2:
		draw_arc(Vector2.ZERO, attack_range * 0.9, 0, TAU, 48, Color(0.4, 0.25, 0.7, 0.08), 3.0)
		draw_arc(Vector2.ZERO, attack_range * 0.88, 0, TAU, 48, Color(0.5, 0.35, 0.8, 0.04), 2.0)
		# Ghostly music notes around perimeter
		for i in range(8):
			var na = TAU * float(i) / 8.0 + _time * 0.6
			var n_bob2 = sin(_time * 2.0 + float(i) * 1.5) * 6.0
			var n_rad = attack_range * 0.82 + n_bob2
			var np = Vector2.from_angle(na) * n_rad
			var n_alpha = 0.2 + sin(_time * 1.5 + float(i) * 0.9) * 0.08
			# Note head
			draw_circle(np, 4.0, Color(0.4, 0.55, 0.9, n_alpha))
			draw_circle(np, 2.5, Color(0.5, 0.65, 1.0, n_alpha * 0.6))
			# Note stem
			draw_line(np + Vector2(2.5, 0), np + Vector2(2.5, -12.0), Color(0.4, 0.55, 0.9, n_alpha * 0.7), 1.2)
			# Note flag
			draw_line(np + Vector2(2.5, -12.0), np + Vector2(6.0, -8.0), Color(0.4, 0.55, 0.9, n_alpha * 0.5), 1.2)
			# Ghost glow
			draw_circle(np, 7.0, Color(0.4, 0.5, 0.9, n_alpha * 0.1))

	# === T4: Crown of dark flame above head ===
	if upgrade_tier >= 4:
		var crown_hover = sin(_time * 1.8) * 1.5
		var crown_center = head_center + Vector2(0, -head_r - 6 + crown_hover)
		# Dark flame wisps rising above head
		for fi in range(5):
			var flame_x = crown_center.x - 8.0 + float(fi) * 4.0
			var flame_h = 8.0 + sin(_time * 5.0 + float(fi) * 2.0) * 3.0
			var flame_sway2 = sin(_time * 3.0 + float(fi) * 1.5) * 2.0
			var flame_base2 = Vector2(flame_x + flame_sway2, crown_center.y)
			var flame_tip2 = flame_base2 + Vector2(0, -flame_h)
			# Dark outer flame
			draw_line(flame_base2, flame_tip2, Color(0.5, 0.05, 0.05, 0.4), 3.0)
			# Bright inner flame
			draw_line(flame_base2 + Vector2(0, -1), flame_tip2 + Vector2(0, 2), Color(0.9, 0.25, 0.1, 0.3), 1.5)
		# Red glow beneath crown
		draw_circle(crown_center, 12.0, Color(0.7, 0.1, 0.05, 0.08))

	# === AWAITING ABILITY CHOICE INDICATOR ===
	if awaiting_ability_choice:
		var pulse = (sin(_time * 4.0) + 1.0) * 0.5
		draw_circle(Vector2.ZERO, 60.0 + pulse * 6.0, Color(0.6, 0.3, 0.8, 0.1 + pulse * 0.1))
		draw_arc(Vector2.ZERO, 60.0 + pulse * 6.0, 0, TAU, 32, Color(0.6, 0.3, 0.8, 0.3 + pulse * 0.3), 2.5)
		var font3 = ThemeDB.fallback_font
		draw_string(font3, Vector2(-16, -82), "!", HORIZONTAL_ALIGNMENT_CENTER, 32, 30, Color(0.6, 0.3, 0.8, 0.7 + pulse * 0.3))

	# === DAMAGE COUNTER ===
	if damage_dealt > 0:
		var font = ThemeDB.fallback_font
		var dmg_text = str(int(damage_dealt)) + " DMG"
		if stat_upgrade_level > 0:
			dmg_text += " • Lv." + str(stat_upgrade_level)
		draw_string(font, Vector2(-36, 56), dmg_text, HORIZONTAL_ALIGNMENT_LEFT, 160, 12, Color(1.0, 0.84, 0.0, 0.5))

	# === UPGRADE NAME FLASH ===
	if _upgrade_flash > 0.0 and _upgrade_name != "":
		var font2 = ThemeDB.fallback_font
		draw_string(font2, Vector2(-80, -74), _upgrade_name, HORIZONTAL_ALIGNMENT_CENTER, 160, 16, Color(0.6, 0.3, 0.8, min(_upgrade_flash, 1.0)))
