extends Node2D
## Frankenstein's Monster — Tank/AoE tower. Lightning-charged fist smash with devastating area damage.
## Tier 1 (5000 DMG): Galvanic Surge — smash radius +30%
## Tier 2 (10000 DMG): Stitched Resilience — kill stacks give +3% instead of +2%
## Tier 3 (15000 DMG): Lightning Conductor — chain lightning arcs to 10 enemies
## Tier 4 (20000 DMG): Modern Prometheus — 500 base dmg storm, permanent electric aura

# Base stats
var damage: float = 40.0
var fire_rate: float = 0.65
var attack_range: float = 140.0
var fire_cooldown: float = 0.0
var aim_angle: float = 0.0
var target: Node2D = null
var gold_bonus: int = 2

# Targeting priority: 0=First, 1=Last, 2=Close, 3=Strong
var targeting_priority: int = 0

# Animation timers
var _time: float = 0.0
var _attack_anim: float = 0.0
var _smash_anim: float = 0.0

# Damage tracking and upgrades
var damage_dealt: float = 0.0
var upgrade_tier: int = 0
var _upgrade_flash: float = 0.0
var _upgrade_name: String = ""

# Kill stack system — each kill grants permanent damage bonus
var kill_count: int = 0
var kill_stack_bonus: float = 0.0  # Accumulated permanent % bonus
var _kill_stack_rate: float = 0.02  # +2% per kill (T2: +3%)
var _kill_stack_cap: int = 25  # Linear scaling cap; logarithmic past this

# Smash radius
var smash_radius: float = 60.0

# Chain lightning
var chain_count: int = 6

# Thunder storm ability
var _thunder_storm_timer: float = 25.0
var _thunder_storm_cooldown: float = 25.0
var _thunder_flash: float = 0.0

# Tier 4: permanent electric aura
var _aura_active: bool = false
var _aura_timer: float = 0.0
var _aura_tick: float = 0.0

# Progressive abilities (9 tiers, unlocked via lifetime damage)
const PROG_ABILITY_NAMES = [
	"Reanimated Strength", "Pain Resistance", "Electric Charge", "Blind Man's Kindness",
	"Arctic Endurance", "Creator's Sorrow", "Promethean Fire",
	"Rage of Rejection", "Immortal Construct"
]
const PROG_ABILITY_DESCS = [
	"Smash damage +25%, attack speed +10%",
	"Absorbs the next 50 points of damage every 20s (shield mechanic)",
	"Every attack chains lightning to 2 extra enemies",
	"Every 25s, heal 1 life for the player",
	"Enemies hit are slowed 30% for 2s",
	"Every 15s, stun all enemies in range for 2s",
	"Every 12s, lightning bolt hits strongest enemy for 8x damage",
	"Below 50% kill stacks, smash deals 2x damage",
	"Every 10s, massive AoE pulse deals 3x damage within 3x range"
]
var prog_abilities: Array = [false, false, false, false, false, false, false, false, false]
# Pain Resistance shield — absorbs next N damage points
var _pain_resistance_shield: float = 0.0
var _pain_resistance_max: float = 0.0  # Set when ability activates
var _pain_resistance_timer: float = 20.0  # Cooldown to recharge shield
# Ability timers
var _kindness_timer: float = 25.0
var _sorrow_timer: float = 15.0
var _promethean_timer: float = 12.0
var _immortal_timer: float = 10.0
# Visual flash timers
var _sorrow_flash: float = 0.0
var _promethean_flash: float = 0.0
var _immortal_flash: float = 0.0

const STAT_UPGRADE_INTERVAL: float = 4000.0
const ABILITY_THRESHOLD: float = 12000.0
var stat_upgrade_level: int = 0
var ability_chosen: bool = false
var awaiting_ability_choice: bool = false
const TIER_NAMES = [
	"Galvanic Surge",
	"Stitched Resilience",
	"Lightning Conductor",
	"Modern Prometheus"
]
const ABILITY_DESCRIPTIONS = [
	"Smash radius +30%",
	"Kill stacks give +3% instead of +2%",
	"Chain lightning arcs to 10 enemies",
	"Massive storm, permanent electric aura"
]
const TIER_COSTS = [100, 200, 350, 550]
var is_selected: bool = false
var base_cost: int = 0

# Promethean Fire — track last strike target position for visual alignment
var _promethean_target_pos: Vector2 = Vector2.ZERO
var _promethean_had_target: bool = false

# Accumulated stat boosts from leveling (to restore after tier upgrade)
var _accumulated_stat_boosts: Dictionary = {
	"damage": 0.0,
	"fire_rate": 0.0,
	"attack_range": 0.0,
	"gold_bonus": 0,
}

var lightning_fist_scene = preload("res://scenes/lightning_fist.tscn")

# Attack sounds — heavy impact thud with electric crackle
var _attack_sounds: Array = []
var _attack_sounds_by_tier: Array = []
var _attack_player: AudioStreamPlayer

# Ability sounds
var _thunder_sound: AudioStreamWAV
var _thunder_player: AudioStreamPlayer
var _upgrade_sound: AudioStreamWAV
var _upgrade_player: AudioStreamPlayer
var _main_node: Node2D = null

func _ready() -> void:
	_main_node = get_tree().get_first_node_in_group("main")
	add_to_group("towers")
	_load_progressive_abilities()
	_generate_tier_sounds()
	_attack_sounds = _attack_sounds_by_tier[0]
	_attack_player = AudioStreamPlayer.new()
	_attack_player.stream = _attack_sounds[0]
	_attack_player.volume_db = -3.0
	add_child(_attack_player)

	# Thunder storm — deep rumbling crack with electric sizzle
	var th_rate := 44100
	var th_dur := 0.8
	var th_samples := PackedFloat32Array()
	th_samples.resize(int(th_rate * th_dur))
	for i in th_samples.size():
		var t := float(i) / th_rate
		# Deep thunder rumble
		var rumble := sin(TAU * 45.0 * t) * 0.3 * exp(-t * 3.0)
		rumble += sin(TAU * 65.0 * t + sin(TAU * 8.0 * t) * 2.0) * 0.2 * exp(-t * 4.0)
		# Sharp crack at start
		var crack := (randf() * 2.0 - 1.0) * exp(-t * 80.0) * 0.5
		# Electric sizzle mid-section
		var sizzle := sin(TAU * 2200.0 * t + sin(TAU * 150.0 * t) * 6.0) * 0.15 * exp(-t * 6.0)
		sizzle += (randf() * 2.0 - 1.0) * 0.08 * exp(-t * 5.0)
		# Low sub-bass body hit
		var sub := sin(TAU * 30.0 * t) * 0.25 * exp(-t * 5.0)
		th_samples[i] = clampf(rumble + crack + sizzle + sub, -1.0, 1.0)
	_thunder_sound = _samples_to_wav(th_samples, th_rate)
	_thunder_player = AudioStreamPlayer.new()
	_thunder_player.stream = _thunder_sound
	_thunder_player.volume_db = -4.0
	add_child(_thunder_player)

	# Upgrade chime — bright ascending arpeggio (C5, E5, G5)
	var up_rate := 22050
	var up_dur := 0.35
	var up_samples := PackedFloat32Array()
	up_samples.resize(int(up_rate * up_dur))
	var up_notes := [523.25, 659.25, 783.99]
	var up_note_len := int(up_rate * up_dur) / 3
	for i in up_samples.size():
		var t := float(i) / up_rate
		var ni := mini(i / up_note_len, 2)
		var nt := float(i - ni * up_note_len) / float(up_rate)
		var freq: float = up_notes[ni]
		var env := minf(nt * 50.0, 1.0) * exp(-nt * 10.0) * 0.4
		up_samples[i] = clampf((sin(TAU * freq * t) + sin(TAU * freq * 2.0 * t) * 0.3) * env, -1.0, 1.0)
	_upgrade_sound = _samples_to_wav(up_samples, up_rate)
	_upgrade_player = AudioStreamPlayer.new()
	_upgrade_player.stream = _upgrade_sound
	_upgrade_player.volume_db = -4.0
	add_child(_upgrade_player)

func _process(delta: float) -> void:
	_time += delta
	fire_cooldown -= delta
	_upgrade_flash = max(_upgrade_flash - delta * 0.5, 0.0)
	_thunder_flash = max(_thunder_flash - delta * 2.0, 0.0)
	_attack_anim = max(_attack_anim - delta * 3.0, 0.0)
	_smash_anim = max(_smash_anim - delta * 4.0, 0.0)
	target = _find_nearest_enemy()

	if target:
		var desired = global_position.angle_to_point(target.global_position) + PI
		aim_angle = lerp_angle(aim_angle, desired, 6.0 * delta)
		if fire_cooldown <= 0.0:
			_attack()
			fire_cooldown = 1.0 / (fire_rate * _speed_mult())
			_attack_anim = 1.0
			_smash_anim = 1.0

	# Thunder storm ability (active ability on timer — tier 3+ upgrade only)
	if upgrade_tier >= 3:
		_thunder_storm_timer -= delta
		if _thunder_storm_timer <= 0.0 and _has_enemies_in_range():
			_thunder_storm()
			_thunder_storm_timer = _thunder_storm_cooldown

	# Tier 4: permanent electric aura damages nearby enemies
	if _aura_active:
		_aura_timer += delta
		_aura_tick += delta
		if _aura_tick >= 0.5:
			_aura_tick -= 0.5
			_aura_pulse()

	# Progressive abilities
	_process_progressive_abilities(delta)

	queue_redraw()

func _has_enemies_in_range() -> bool:
	var eff_range = attack_range * _range_mult()
	for enemy in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if enemy.has_method("is_targetable") and not enemy.is_targetable():
			continue
		if global_position.distance_to(enemy.global_position) < eff_range:
			return true
	return false

func _get_note_index() -> int:
	var main = get_tree().get_first_node_in_group("main")
	if main and "music_beat_index" in main:
		return main.music_beat_index
	return 0

func _is_sfx_muted() -> bool:
	var main = get_tree().get_first_node_in_group("main")
	return main and main.get("sfx_muted") == true

func _find_nearest_enemy() -> Node2D:
	var enemies = (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies"))
	var best: Node2D = null
	var max_range: float = attack_range * _range_mult()
	var best_val: float = 999999.0 if (targeting_priority == 1 or targeting_priority == 2) else -1.0
	for enemy in enemies:
		if enemy.has_method("is_targetable") and not enemy.is_targetable():
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist > max_range:
			continue
		match targeting_priority:
			0:  # First — furthest along path
				if enemy.progress_ratio > best_val:
					best = enemy
					best_val = enemy.progress_ratio
			1:  # Last — earliest on path
				if enemy.progress_ratio < best_val:
					best = enemy
					best_val = enemy.progress_ratio
			2:  # Close — nearest to tower
				if best == null or dist < best_val:
					best = enemy
					best_val = dist
			3:  # Strong — highest HP
				var hp = enemy.health if "health" in enemy else 0.0
				if hp > best_val:
					best = enemy
					best_val = hp
	return best

func cycle_targeting() -> void:
	targeting_priority = (targeting_priority + 1) % 4

func get_targeting_label() -> String:
	match targeting_priority:
		0: return "FIRST"
		1: return "LAST"
		2: return "CLOSE"
		3: return "STRONG"
	return "FIRST"

func _attack() -> void:
	if not target:
		return
	if _attack_player and _attack_sounds.size() > 0 and not _is_sfx_muted():
		_attack_player.stream = _attack_sounds[_get_note_index() % _attack_sounds.size()]
		_attack_player.play()

	# Calculate effective damage with kill stack bonus
	var eff_damage = damage * _damage_mult() * (1.0 + kill_stack_bonus)
	# Ability 8: Rage of Rejection — below 50% of max potential kill stacks, 2x damage
	# Max potential = _kill_stack_cap * _kill_stack_rate (the linear portion)
	var rage_threshold = float(_kill_stack_cap) * _kill_stack_rate * 0.5
	if prog_abilities[7] and kill_stack_bonus < rage_threshold:
		eff_damage *= 2.0

	# Spawn lightning fist visual effect
	var fist = lightning_fist_scene.instantiate()
	fist.global_position = global_position
	fist.damage = eff_damage
	fist.smash_radius = smash_radius * _range_mult()
	fist.chain_count = chain_count
	# Ability 3: Electric Charge — +2 chain targets per attack
	if prog_abilities[2]:
		fist.chain_count += 2
	fist.source_tower = self
	fist.gold_bonus = int(gold_bonus * _gold_mult())
	# Ability 5: Arctic Endurance — slow enemies
	fist.apply_slow = prog_abilities[4]
	get_tree().get_first_node_in_group("main").add_child(fist)

func _thunder_storm() -> void:
	if _thunder_player and not _is_sfx_muted():
		_thunder_player.play()
	_thunder_flash = 1.0
	var enemies = (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies"))
	var in_range: Array = []
	for enemy in enemies:
		if enemy.has_method("is_targetable") and not enemy.is_targetable():
			continue
		if global_position.distance_to(enemy.global_position) < attack_range * _range_mult():
			in_range.append(enemy)
	in_range.shuffle()
	var count = mini(chain_count, in_range.size())
	var storm_dmg = damage * 2.0 * _damage_mult() * (1.0 + kill_stack_bonus)
	for i in range(count):
		if is_instance_valid(in_range[i]) and in_range[i].has_method("take_damage"):
			var hp_before = in_range[i].health if "health" in in_range[i] else 0.0
			in_range[i].take_damage(storm_dmg)
			register_damage(storm_dmg)
			if hp_before > 0.0 and (not is_instance_valid(in_range[i]) or in_range[i].health <= 0.0):
				register_kill()

func _aura_pulse() -> void:
	var aura_dmg = damage * 0.3 * _damage_mult() * (1.0 + kill_stack_bonus)
	for enemy in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if global_position.distance_to(enemy.global_position) < smash_radius * 1.2:
			if enemy.has_method("take_damage"):
				enemy.take_damage(aura_dmg)
				register_damage(aura_dmg)

func register_kill() -> void:
	kill_count += 1
	# Linear scaling up to cap, logarithmic past it, hard cap at 60%
	if kill_stack_bonus >= 0.60:
		# Hard cap — no more growth
		pass
	elif kill_count <= _kill_stack_cap:
		kill_stack_bonus = minf(kill_stack_bonus + _kill_stack_rate, 0.60)
	else:
		var over = kill_count - _kill_stack_cap
		var prev_over = over - 1
		var factor = _kill_stack_rate * 0.5
		var new_bonus_total = float(_kill_stack_cap) * _kill_stack_rate + log(float(over) + 1.0) * factor
		var old_bonus_total = float(_kill_stack_cap) * _kill_stack_rate + log(float(prev_over) + 1.0) * factor
		kill_stack_bonus = minf(kill_stack_bonus + (new_bonus_total - old_bonus_total), 0.60)
	_upgrade_flash = 0.5
	_upgrade_name = "+%.0f%% damage!" % (kill_stack_bonus * 100.0)

func register_damage(amount: float) -> void:
	damage_dealt += amount
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("register_tower_damage"):
		main.register_tower_damage(main.TowerType.FRANKENSTEIN, amount)
	_check_upgrades()

# Pain Resistance shield: absorb incoming damage, return remaining damage after absorption
func absorb_damage(incoming: float) -> float:
	if _pain_resistance_shield <= 0.0:
		return incoming
	var absorbed = minf(incoming, _pain_resistance_shield)
	_pain_resistance_shield -= absorbed
	return incoming - absorbed

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
	var dmg_boost = 3.0
	var rate_boost = 0.03
	var range_boost = 5.0
	var gold_boost_val = 1
	damage += dmg_boost
	fire_rate += rate_boost
	attack_range += range_boost
	gold_bonus += gold_boost_val
	_accumulated_stat_boosts["damage"] += dmg_boost
	_accumulated_stat_boosts["fire_rate"] += rate_boost
	_accumulated_stat_boosts["attack_range"] += range_boost
	_accumulated_stat_boosts["gold_bonus"] += gold_boost_val

func choose_ability(index: int) -> void:
	ability_chosen = true
	awaiting_ability_choice = false
	upgrade_tier = index + 1
	_apply_upgrade(upgrade_tier)
	_upgrade_flash = 3.0
	_upgrade_name = TIER_NAMES[index]

func _apply_upgrade(tier: int) -> void:
	match tier:
		1: # Galvanic Surge — smash radius +30%
			smash_radius = 78.0
			damage = 50.0
			fire_rate = 1.44
			attack_range = 155.0
		2: # Stitched Resilience — kill stacks +3% instead of +2%
			_kill_stack_rate = 0.03
			damage = 60.0
			fire_rate = 1.56
			attack_range = 165.0
			gold_bonus = 3
		3: # Lightning Conductor — chain lightning arcs to 10
			chain_count = 10
			damage = 73.0
			fire_rate = 1.70
			attack_range = 175.0
			gold_bonus = 4
			_thunder_storm_cooldown = 20.0
		4: # Modern Prometheus — massive storm + permanent aura
			damage = 75.0
			fire_rate = 1.70
			attack_range = 190.0
			gold_bonus = 5
			chain_count = 10
			smash_radius = 90.0
			_thunder_storm_cooldown = 18.0
			_aura_active = true
	# Re-apply accumulated stat boosts so tier upgrade doesn't clobber them
	damage += _accumulated_stat_boosts["damage"]
	fire_rate += _accumulated_stat_boosts["fire_rate"]
	attack_range += _accumulated_stat_boosts["attack_range"]
	gold_bonus += _accumulated_stat_boosts["gold_bonus"]

func purchase_upgrade() -> bool:
	if upgrade_tier >= 4:
		return false
	var cost = TIER_COSTS[upgrade_tier]
	var main_node = get_tree().get_first_node_in_group("main")
	if not main_node or not main_node.spend_gold(cost):
		return false
	upgrade_tier += 1
	_apply_upgrade(upgrade_tier)
	_refresh_tier_sounds()
	_upgrade_flash = 3.0
	_upgrade_name = TIER_NAMES[upgrade_tier - 1]
	if _upgrade_player and not _is_sfx_muted():
		_upgrade_player.play()
	return true

func get_tower_display_name() -> String:
	return "Frankenstein's Monster"

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

func _generate_tier_sounds() -> void:
	# Heavy impact thud frequencies with electric crackle overtones
	var impact_notes := [36.71, 55.00, 73.42, 55.00, 36.71, 73.42, 55.00, 98.00]  # D1, A1, D2, A1, D1, D2, A1, G2 (D minor timpani ostinato)
	var mix_rate := 44100
	_attack_sounds_by_tier = []

	# --- Tier 0: Basic fist smash (low thud + brief crackle) ---
	var t0 := []
	for note_idx in impact_notes.size():
		var freq: float = impact_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.2))
		for i in samples.size():
			var t := float(i) / mix_rate
			# Heavy meaty thud
			var env := exp(-t * 15.0) * 0.4
			var thud := sin(TAU * freq * t) + sin(TAU * freq * 0.5 * t) * 0.3
			# Brief impact noise
			var impact := (randf() * 2.0 - 1.0) * exp(-t * 200.0) * 0.3
			# Faint electric crackle
			var crackle := sin(TAU * 1800.0 * t + sin(TAU * 120.0 * t) * 3.0) * 0.06 * exp(-t * 20.0)
			samples[i] = clampf(thud * env + impact + crackle, -1.0, 1.0)
		t0.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t0)

	# --- Tier 1: Galvanic smash (deeper thud + louder crackle) ---
	var t1 := []
	for note_idx in impact_notes.size():
		var freq: float = impact_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.25))
		for i in samples.size():
			var t := float(i) / mix_rate
			var env := exp(-t * 12.0) * 0.42
			var thud := sin(TAU * freq * t) + sin(TAU * freq * 0.5 * t) * 0.35
			var impact := (randf() * 2.0 - 1.0) * exp(-t * 180.0) * 0.32
			# More prominent crackle
			var crackle := sin(TAU * 2000.0 * t + sin(TAU * 140.0 * t) * 4.0) * 0.1 * exp(-t * 15.0)
			crackle += (randf() * 2.0 - 1.0) * 0.05 * exp(-t * 18.0)
			var sub := sin(TAU * 28.0 * t) * 0.15 * exp(-t * 8.0)
			samples[i] = clampf(thud * env + impact + crackle + sub, -1.0, 1.0)
		t1.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t1)

	# --- Tier 2: Resilient smash (meaty impact + sustained zap) ---
	var t2 := []
	for note_idx in impact_notes.size():
		var freq: float = impact_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.28))
		for i in samples.size():
			var t := float(i) / mix_rate
			var env := exp(-t * 10.0) * 0.42
			var thud := sin(TAU * freq * t) + sin(TAU * freq * 0.5 * t) * 0.4
			thud += sin(TAU * freq * 1.5 * t) * 0.1 * exp(-t * 20.0)
			var impact := (randf() * 2.0 - 1.0) * exp(-t * 160.0) * 0.3
			# Sustained electric zap
			var zap := sin(TAU * 2400.0 * t + sin(TAU * 180.0 * t) * 5.0) * 0.12 * exp(-t * 8.0)
			zap += (randf() * 2.0 - 1.0) * 0.06 * exp(-t * 10.0)
			var sub := sin(TAU * 25.0 * t) * 0.18 * exp(-t * 6.0)
			samples[i] = clampf(thud * env + impact + zap + sub, -1.0, 1.0)
		t2.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t2)

	# --- Tier 3: Lightning conductor (heavy thud + bright electric arc) ---
	var t3 := []
	for note_idx in impact_notes.size():
		var freq: float = impact_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.3))
		for i in samples.size():
			var t := float(i) / mix_rate
			var env := exp(-t * 9.0) * 0.4
			var thud := sin(TAU * freq * t) + sin(TAU * freq * 0.5 * t) * 0.35
			var impact := (randf() * 2.0 - 1.0) * exp(-t * 150.0) * 0.28
			# Bright arcing electric sound
			var arc := sin(TAU * 3000.0 * t + sin(TAU * 250.0 * t) * 8.0) * 0.15 * exp(-t * 7.0)
			arc += sin(TAU * 4500.0 * t + sin(TAU * 300.0 * t) * 4.0) * 0.06 * exp(-t * 10.0)
			arc += (randf() * 2.0 - 1.0) * 0.07 * exp(-t * 8.0)
			var sub := sin(TAU * 22.0 * t) * 0.2 * exp(-t * 5.0)
			samples[i] = clampf(thud * env + impact + arc + sub, -1.0, 1.0)
		t3.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t3)

	# --- Tier 4: Prometheus slam (massive earth-shaking hit + storm) ---
	var t4 := []
	for note_idx in impact_notes.size():
		var freq: float = impact_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.35))
		for i in samples.size():
			var t := float(i) / mix_rate
			# Massive earth-shaking impact
			var env := exp(-t * 7.0) * 0.45
			var thud := sin(TAU * freq * t) + sin(TAU * freq * 0.5 * t) * 0.4
			thud += sin(TAU * freq * 1.5 * t) * 0.15 * exp(-t * 12.0)
			var impact := (randf() * 2.0 - 1.0) * exp(-t * 120.0) * 0.35
			# Full storm electric effect
			var storm := sin(TAU * 3500.0 * t + sin(TAU * 350.0 * t) * 10.0) * 0.14 * exp(-t * 5.0)
			storm += sin(TAU * 5000.0 * t + sin(TAU * 400.0 * t) * 6.0) * 0.08 * exp(-t * 7.0)
			storm += (randf() * 2.0 - 1.0) * 0.1 * exp(-t * 6.0)
			# Deep sub-bass resonance
			var sub := sin(TAU * 18.0 * t) * 0.25 * exp(-t * 4.0)
			# Heroic shimmer
			var shim := sin(TAU * freq * 4.0 * t) * 0.05 * exp(-t * 3.0)
			samples[i] = clampf(thud * env + impact + storm + sub + shim, -1.0, 1.0)
		t4.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t4)

func _refresh_tier_sounds() -> void:
	var tier := mini(upgrade_tier, _attack_sounds_by_tier.size() - 1)
	_attack_sounds = _attack_sounds_by_tier[tier]

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

# === PROGRESSIVE ABILITY SYSTEM ===

func _load_progressive_abilities() -> void:
	var main = get_tree().get_first_node_in_group("main")
	if main and main.survivor_progress.has(main.TowerType.FRANKENSTEIN):
		var p = main.survivor_progress[main.TowerType.FRANKENSTEIN]
		var unlocked = p.get("abilities_unlocked", [])
		for i in range(mini(9, unlocked.size())):
			if unlocked[i]:
				activate_progressive_ability(i)

func activate_progressive_ability(index: int) -> void:
	if index < 0 or index >= 9:
		return
	prog_abilities[index] = true
	_apply_progressive_stats()

func _apply_progressive_stats() -> void:
	if prog_abilities[0]:  # Reanimated Strength: +25% damage, +10% speed applied in _attack
		pass

func get_progressive_ability_name(index: int) -> String:
	if index >= 0 and index < PROG_ABILITY_NAMES.size():
		return PROG_ABILITY_NAMES[index]
	return ""

func get_progressive_ability_desc(index: int) -> String:
	if index >= 0 and index < PROG_ABILITY_DESCS.size():
		return PROG_ABILITY_DESCS[index]
	return ""

func _process_progressive_abilities(delta: float) -> void:
	# Visual flash decay
	_sorrow_flash = max(_sorrow_flash - delta * 2.0, 0.0)
	_promethean_flash = max(_promethean_flash - delta * 2.0, 0.0)
	_immortal_flash = max(_immortal_flash - delta * 2.0, 0.0)

	# Ability 2: Pain Resistance — recharge damage absorption shield every 20s
	if prog_abilities[1]:
		if _pain_resistance_shield <= 0.0:
			_pain_resistance_timer -= delta
			if _pain_resistance_timer <= 0.0:
				_pain_resistance_shield = 50.0
				_pain_resistance_max = 50.0
				_pain_resistance_timer = 20.0

	# Ability 4: Blind Man's Kindness — heal 1 life every 25s
	if prog_abilities[3]:
		_kindness_timer -= delta
		if _kindness_timer <= 0.0:
			var main = get_tree().get_first_node_in_group("main")
			if main and main.has_method("restore_life"):
				main.restore_life(1)
			_kindness_timer = 25.0

	# Ability 6: Creator's Sorrow — stun all in range
	if prog_abilities[5]:
		_sorrow_timer -= delta
		if _sorrow_timer <= 0.0 and _has_enemies_in_range():
			_creators_sorrow_stun()
			_sorrow_timer = 15.0

	# Ability 7: Promethean Fire — lightning bolt on strongest
	if prog_abilities[6]:
		_promethean_timer -= delta
		if _promethean_timer <= 0.0 and _has_enemies_in_range():
			_promethean_fire_strike()
			_promethean_timer = 12.0

	# Ability 9: Immortal Construct — massive AoE pulse
	if prog_abilities[8]:
		_immortal_timer -= delta
		if _immortal_timer <= 0.0:
			_immortal_construct_pulse()
			_immortal_timer = 10.0

func _creators_sorrow_stun() -> void:
	_sorrow_flash = 1.0
	for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if global_position.distance_to(e.global_position) < attack_range * _range_mult():
			if e.has_method("apply_sleep"):
				e.apply_sleep(2.0)

func _promethean_fire_strike() -> void:
	_promethean_flash = 1.0
	var strongest: Node2D = null
	var most_hp: float = 0.0
	for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if global_position.distance_to(e.global_position) < attack_range * _range_mult():
			if e.health > most_hp:
				most_hp = e.health
				strongest = e
	if strongest and strongest.has_method("take_damage"):
		# Store the target position for visual alignment
		_promethean_target_pos = strongest.global_position
		_promethean_had_target = true
		var dmg = damage * 8.0 * _damage_mult() * (1.0 + kill_stack_bonus)
		strongest.take_damage(dmg)
		register_damage(dmg)
		if strongest.has_method("apply_sleep"):
			strongest.apply_sleep(1.5)
	else:
		_promethean_had_target = false

func _immortal_construct_pulse() -> void:
	_immortal_flash = 1.0
	var dmg = damage * 3.0 * _damage_mult() * (1.0 + kill_stack_bonus)
	var pulse_range = attack_range * _range_mult() * 3.0
	for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if global_position.distance_to(e.global_position) <= pulse_range and e.has_method("take_damage"):
			var hp_before = e.health if "health" in e else 0.0
			e.take_damage(dmg)
			register_damage(dmg)
			if hp_before > 0.0 and (not is_instance_valid(e) or e.health <= 0.0):
				register_kill()

# === SYNERGY BUFFS ===
var _synergy_buffs: Dictionary = {}
var _meta_buffs: Dictionary = {}

func set_synergy_buff(buffs: Dictionary) -> void:
	for key in buffs:
		_synergy_buffs[key] = _synergy_buffs.get(key, 0.0) + buffs[key]

func clear_synergy_buff() -> void:
	_synergy_buffs.clear()

func remove_synergy_buff(buffs: Dictionary) -> void:
	for key in buffs:
		if _synergy_buffs.has(key):
			_synergy_buffs[key] = _synergy_buffs.get(key, 0.0) - buffs[key]
			if absf(_synergy_buffs[key]) < 0.001:
				_synergy_buffs.erase(key)

func set_meta_buffs(buffs: Dictionary) -> void:
	_meta_buffs = buffs

var power_damage_mult: float = 1.0

func _damage_mult() -> float:
	var mult: float = (1.0 + _synergy_buffs.get("damage", 0.0) + _meta_buffs.get("damage", 0.0)) * power_damage_mult
	# Ability 1: Reanimated Strength — +25% damage
	if prog_abilities[0]:
		mult *= 1.25
	return mult

func _range_mult() -> float:
	return 1.0 + _synergy_buffs.get("range", 0.0) + _meta_buffs.get("range", 0.0)

func _speed_mult() -> float:
	var mult: float = 1.0 + _synergy_buffs.get("attack_speed", 0.0) + _meta_buffs.get("attack_speed", 0.0)
	# Ability 1: Reanimated Strength — +10% speed
	if prog_abilities[0]:
		mult *= 1.1
	return mult

func _gold_mult() -> float:
	return 1.0 + _synergy_buffs.get("gold_bonus", 0.0) + _meta_buffs.get("gold_bonus", 0.0)

# === DRAW ===

func _draw() -> void:
	# === 1. SELECTION RING ===
	var eff_range = attack_range * _range_mult()
	if is_selected:
		var pulse = (sin(_time * 3.0) + 1.0) * 0.5
		var ring_alpha = 0.5 + pulse * 0.3
		draw_circle(Vector2.ZERO, eff_range, Color(1.0, 1.0, 1.0, 0.04))
		draw_arc(Vector2.ZERO, eff_range, 0, TAU, 64, Color(0.4, 0.7, 1.0, 0.25 + pulse * 0.15), 2.0)
		draw_arc(Vector2.ZERO, 40.0, 0, TAU, 48, Color(0.4, 0.7, 1.0, ring_alpha), 2.5)
		draw_arc(Vector2.ZERO, 43.0, 0, TAU, 48, Color(0.4, 0.7, 1.0, ring_alpha * 0.4), 1.5)
	else:
		draw_arc(Vector2.ZERO, eff_range, 0, TAU, 64, Color(1, 1, 1, 0.06), 1.0)

	# === 3. AIM DIRECTION ===
	var dir = Vector2.from_angle(aim_angle)
	var perp = dir.rotated(PI / 2.0)

	# === 4. IDLE ANIMATION (heavy lumbering weight shift) ===
	var bounce = abs(sin(_time * 1.8)) * 3.0  # Slower, heavier bounce
	var breathe = sin(_time * 1.5) * 3.0  # Slow deep breathing
	var weight_shift = sin(_time * 0.8) * 3.5  # Heavy lumbering sway
	var bob = Vector2(weight_shift, -bounce - breathe)

	# Tier 4: Floating electric levitation
	var fly_offset = Vector2.ZERO
	if upgrade_tier >= 4:
		fly_offset = Vector2(0, -8.0 + sin(_time * 1.2) * 4.0)

	var body_offset = bob + fly_offset

	# Per-joint differential offsets (heavy, lumbering)
	var hip_shift = sin(_time * 0.8) * 2.5
	var shoulder_counter = -sin(_time * 0.8) * 1.2

	# Smash animation — arm slam
	var smash_offset = 0.0
	if _smash_anim > 0.0:
		smash_offset = sin(_smash_anim * PI) * 8.0

	# === 5. SKIN COLORS (greenish-grey) ===
	var skin_base = Color(0.55, 0.62, 0.48)
	var skin_shadow = Color(0.42, 0.50, 0.36)
	var skin_highlight = Color(0.65, 0.72, 0.56)
	var skin_green = Color(0.48, 0.58, 0.40)  # More greenish tint

	# Stitch color
	var stitch_col = Color(0.2, 0.18, 0.15, 0.7)

	# === 6. UPGRADE FLASH ===
	if _upgrade_flash > 0.0:
		draw_circle(Vector2.ZERO, 80.0 + _upgrade_flash * 24.0, Color(0.3, 0.5, 0.9, _upgrade_flash * 0.25))

	# === 7. THUNDER FLASH ===
	if _thunder_flash > 0.0:
		var flash_r = 40.0 + (1.0 - _thunder_flash) * 80.0
		draw_circle(Vector2.ZERO, flash_r, Color(0.5, 0.7, 1.0, _thunder_flash * 0.15))
		draw_arc(Vector2.ZERO, flash_r, 0, TAU, 32, Color(0.6, 0.8, 1.0, _thunder_flash * 0.35), 2.5)
		# Inner crackle rings
		draw_arc(Vector2.ZERO, flash_r * 0.6, 0, TAU, 24, Color(0.5, 0.7, 1.0, _thunder_flash * 0.25), 2.0)
		# Radiating lightning bolt bursts
		for hi in range(6):
			var ha = TAU * float(hi) / 6.0 + _thunder_flash * 3.0
			var h_inner = Vector2.from_angle(ha) * (flash_r * 0.4)
			var h_outer = Vector2.from_angle(ha) * (flash_r + 8.0)
			# Jagged lightning lines
			var mid1 = h_inner.lerp(h_outer, 0.33) + Vector2(sin(_time * 10.0 + float(hi)) * 6.0, cos(_time * 8.0 + float(hi)) * 6.0)
			var mid2 = h_inner.lerp(h_outer, 0.66) + Vector2(cos(_time * 12.0 + float(hi)) * 4.0, sin(_time * 9.0 + float(hi)) * 4.0)
			draw_line(h_inner, mid1, Color(0.7, 0.85, 1.0, _thunder_flash * 0.5), 2.0)
			draw_line(mid1, mid2, Color(0.8, 0.9, 1.0, _thunder_flash * 0.45), 1.8)
			draw_line(mid2, h_outer, Color(0.6, 0.8, 1.0, _thunder_flash * 0.35), 1.5)

	# === PROGRESSIVE ABILITY VISUAL EFFECTS ===
	# Ability 6: Creator's Sorrow stun flash
	if _sorrow_flash > 0.0:
		var sr = 30.0 + (1.0 - _sorrow_flash) * 60.0
		draw_arc(Vector2.ZERO, sr, 0, TAU, 24, Color(0.4, 0.5, 0.8, _sorrow_flash * 0.4), 3.0)

	# Ability 7: Promethean Fire flash — draw bolt toward actual target position
	if _promethean_flash > 0.0 and _promethean_had_target:
		var pf_end_local = _promethean_target_pos - global_position
		var pf_bolt_dir = pf_end_local.normalized()
		var bolt_len = pf_end_local.length()
		var prev_pt = Vector2.ZERO
		for bi in range(6):
			var next_pt = pf_bolt_dir * (bolt_len * float(bi + 1) / 6.0)
			next_pt += pf_bolt_dir.rotated(PI / 2.0) * sin(float(bi) * 2.3 + _time * 10.0) * 8.0
			draw_line(prev_pt, next_pt, Color(0.6, 0.8, 1.0, _promethean_flash * 0.6), 3.0)
			draw_line(prev_pt, next_pt, Color(0.9, 0.95, 1.0, _promethean_flash * 0.3), 1.5)
			prev_pt = next_pt
		draw_circle(prev_pt, 8.0, Color(0.5, 0.7, 1.0, _promethean_flash * 0.3))

	# Ability 9: Immortal Construct flash — concentric rings and sparks (capped to pulse range)
	if _immortal_flash > 0.0:
		var ic_max_r = attack_range * _range_mult() * 3.0
		for ri in range(3):
			var ring_r = minf(30.0 + float(ri) * 25.0 + (1.0 - _immortal_flash) * 40.0, ic_max_r)
			draw_arc(Vector2.ZERO, ring_r, 0, TAU, 32, Color(0.5, 0.7, 1.0, _immortal_flash * 0.35 / float(ri + 1)), 3.0 - float(ri) * 0.5)
		for si in range(8):
			var sa = TAU * float(si) / 8.0 + _immortal_flash * 3.0
			var sr = minf(50.0 + (1.0 - _immortal_flash) * 60.0, ic_max_r)
			var sp = Vector2.from_angle(sa) * sr
			draw_circle(sp, 2.0, Color(0.7, 0.85, 1.0, _immortal_flash * 0.5))

	# === 8. METAL SLAB PLATFORM with sparking wires ===
	var plat_y = 24.0
	# Platform shadow
	draw_circle(Vector2(0, plat_y + 5), 30.0, Color(0, 0, 0, 0.18))
	# Metal slab platform (drawn as squished circles)
	draw_set_transform(Vector2(0, plat_y), 0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 30.0, Color(0.22, 0.22, 0.24))
	draw_circle(Vector2.ZERO, 27.0, Color(0.32, 0.32, 0.35))
	draw_circle(Vector2.ZERO, 22.0, Color(0.38, 0.38, 0.42))
	# Metal rivets
	for si in range(8):
		var sa = TAU * float(si) / 8.0
		draw_circle(Vector2.from_angle(sa) * 20.0, 2.5, Color(0.45, 0.45, 0.50, 0.5))
		draw_circle(Vector2.from_angle(sa) * 20.0, 1.5, Color(0.55, 0.55, 0.60, 0.3))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# Platform top highlight
	draw_set_transform(Vector2(0, plat_y - 2), 0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 24.0, Color(0.44, 0.44, 0.48, 0.3))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	# Sparking wires on platform edges
	for wi in range(4):
		var wa = TAU * float(wi) / 4.0 + 0.3
		var w_base = Vector2(cos(wa) * 22.0, plat_y + sin(wa) * 8.0)
		var w_end = w_base + Vector2(sin(_time * 3.0 + float(wi) * 1.7) * 4.0, -3.0 + sin(_time * 2.5 + float(wi)) * 2.0)
		draw_line(w_base, w_end, Color(0.3, 0.3, 0.3), 1.5)
		# Periodic spark at wire end
		var spark_phase = fmod(_time * 2.0 + float(wi) * 1.3, 2.0)
		if spark_phase < 0.3:
			var spark_alpha = 1.0 - spark_phase / 0.3
			draw_circle(w_end, 2.5, Color(0.6, 0.8, 1.0, spark_alpha * 0.5))
			draw_circle(w_end, 1.2, Color(0.9, 0.95, 1.0, spark_alpha * 0.7))

	# === 9. TIER PIPS (electric/blue/silver theme) ===
	for i in range(upgrade_tier):
		var pip_angle = -PI / 2.0 + float(i) * (TAU / 4.0) - (float(upgrade_tier - 1) * TAU / 8.0)
		var pip_pos = Vector2(cos(pip_angle) * 24.0, plat_y + sin(pip_angle) * 8.0)
		var pip_col: Color
		match i:
			0: pip_col = Color(0.3, 0.6, 0.9)    # electric blue
			1: pip_col = Color(0.5, 0.75, 0.5)    # resilience green
			2: pip_col = Color(0.7, 0.8, 1.0)     # lightning white
			3: pip_col = Color(1.0, 0.85, 0.3)    # prometheus gold
		draw_circle(pip_pos, 4.0, pip_col)
		draw_circle(pip_pos, 5.5, Color(pip_col.r, pip_col.g, pip_col.b, 0.15))

	# === 10. TIER-SPECIFIC EFFECTS (drawn around body) ===

	# Tier 1+: Ground crack marks radiating from base
	if upgrade_tier >= 1:
		var crack_count = 4 + upgrade_tier * 2
		for ci in range(crack_count):
			var ca = TAU * float(ci) / float(crack_count) + 0.2
			var c_start = Vector2(cos(ca) * 8.0, plat_y + sin(ca) * 3.0)
			var c_len = 10.0 + fmod(float(ci) * 3.7, 8.0)
			var c_end = c_start + Vector2.from_angle(ca) * c_len
			var c_mid = c_start.lerp(c_end, 0.5) + Vector2(sin(float(ci) * 2.3) * 3.0, 0)
			draw_line(c_start, c_mid, Color(0.15, 0.15, 0.12, 0.35), 1.2)
			draw_line(c_mid, c_end, Color(0.15, 0.15, 0.12, 0.2), 0.8)

	# Tier 2+: Permanent faint lightning between neck bolts
	if upgrade_tier >= 2:
		var bolt_l = body_offset + Vector2(-14, -28.0)
		var bolt_r = body_offset + Vector2(14, -28.0)
		var arc_phase = fmod(_time * 4.0, 1.0)
		var arc_mid = bolt_l.lerp(bolt_r, 0.5) + Vector2(0, -4.0 + sin(_time * 6.0) * 3.0)
		var arc_alpha = 0.15 + sin(_time * 5.0) * 0.08
		draw_line(bolt_l, arc_mid, Color(0.5, 0.7, 1.0, arc_alpha), 1.0)
		draw_line(arc_mid, bolt_r, Color(0.5, 0.7, 1.0, arc_alpha), 1.0)

	# Tier 3+: Visible chain lightning arcs orbiting
	if upgrade_tier >= 3:
		for li in range(3):
			var la = _time * (1.0 + float(li) * 0.3) + float(li) * TAU / 3.0
			var lr = 30.0 + sin(_time * 2.0 + float(li)) * 8.0
			var lp = body_offset + Vector2(cos(la) * lr, sin(la) * lr * 0.5)
			var lp2 = body_offset + Vector2(cos(la + 0.8) * (lr - 5.0), sin(la + 0.8) * (lr - 5.0) * 0.5)
			draw_line(lp, lp2, Color(0.5, 0.7, 1.0, 0.25), 1.2)
			draw_circle(lp, 1.5, Color(0.7, 0.85, 1.0, 0.3))

	# Tier 4: Full electric storm aura with floating debris
	if upgrade_tier >= 4:
		# Constant sparking field
		for fi in range(12):
			var fa = _time * (0.7 + fmod(float(fi) * 1.37, 0.6)) + float(fi) * TAU / 12.0
			var fr = 25.0 + fmod(float(fi) * 4.3, 20.0)
			var fp = body_offset + Vector2(cos(fa) * fr, sin(fa) * fr * 0.6)
			var f_alpha = 0.2 + sin(_time * 3.0 + float(fi) * 1.5) * 0.12
			draw_circle(fp, 1.2, Color(0.5, 0.7, 1.0, f_alpha))
			# Mini lightning arc from spark to nearby point
			var fp2 = fp + Vector2(sin(_time * 8.0 + float(fi)) * 5.0, cos(_time * 7.0 + float(fi)) * 4.0)
			draw_line(fp, fp2, Color(0.6, 0.8, 1.0, f_alpha * 0.5), 0.8)
		# Floating debris (small rock chunks)
		for di in range(5):
			var da = _time * 0.4 + float(di) * TAU / 5.0
			var dr = 35.0 + sin(_time * 0.8 + float(di) * 2.0) * 5.0
			var dy = -10.0 + sin(_time * 1.2 + float(di)) * 6.0
			var dp = body_offset + Vector2(cos(da) * dr, dy)
			draw_circle(dp, 2.0 + sin(_time + float(di)) * 0.5, Color(0.35, 0.32, 0.28, 0.4))
			draw_circle(dp, 1.0, Color(0.45, 0.42, 0.38, 0.3))

	# === 11. CHARACTER BODY — BLOONS TD6 CARTOON STYLE ===
	var OL = Color(0.06, 0.06, 0.08)
	var breath = breathe * 0.5

	# Chibi positions (big head, stocky body)
	var feet_y = body_offset + Vector2(hip_shift * 1.0, 10.0)
	var leg_top = body_offset + Vector2(hip_shift * 0.6, 0.0)
	var torso_center = body_offset + Vector2(hip_shift * 0.3, -8.0 - breath * 0.5)
	var neck_base = body_offset + Vector2(hip_shift * 0.15, -14.0 - breath * 0.3)
	var head_center = body_offset + Vector2(hip_shift * 0.08, -26.0)

	# Skin colors — saturated sickly green
	var sk = Color(0.55, 0.70, 0.45)
	var sk_dark = Color(0.38, 0.52, 0.30)
	var sk_hi = Color(0.68, 0.82, 0.55)
	# Clothing — dark tattered
	var cloth = Color(0.14, 0.12, 0.10)
	var cloth_hi = Color(0.22, 0.19, 0.16)
	# Chain/bolt metal
	var metal = Color(0.58, 0.58, 0.63)
	var metal_hi = Color(0.76, 0.76, 0.82)
	var metal_dk = Color(0.38, 0.38, 0.42)
	# Boot color
	var boot_col = Color(0.18, 0.14, 0.10)
	var boot_hi = Color(0.28, 0.23, 0.18)

	# Smash extend toward target
	var smash_extend = dir * smash_offset

	# === BOOTS (heavy, chunky) ===
	var l_foot = feet_y + Vector2(-7, 0)
	var r_foot = feet_y + Vector2(7, 0)
	# Left boot outline + fill
	var lb_pts = PackedVector2Array([
		l_foot + Vector2(-8, 2), l_foot + Vector2(6, 2),
		l_foot + Vector2(6, -4), l_foot + Vector2(5, -9),
		l_foot + Vector2(-6, -9), l_foot + Vector2(-7, -4),
	])
	draw_colored_polygon(lb_pts, OL)
	var lb_inner = PackedVector2Array([
		l_foot + Vector2(-6.5, 0.5), l_foot + Vector2(4.5, 0.5),
		l_foot + Vector2(4.5, -3), l_foot + Vector2(3.5, -7.5),
		l_foot + Vector2(-4.5, -7.5), l_foot + Vector2(-5.5, -3),
	])
	draw_colored_polygon(lb_inner, boot_col)
	# Boot toe cap
	draw_circle(l_foot + Vector2(-6, -1), 4.0, OL)
	draw_circle(l_foot + Vector2(-6, -1), 2.5, boot_hi)
	# Boot sole highlight
	draw_line(l_foot + Vector2(-7, 1), l_foot + Vector2(5, 1), boot_hi, 1.5)
	# Boot cuff
	draw_line(l_foot + Vector2(-5.5, -8), l_foot + Vector2(4.5, -8), OL, 2.5)
	draw_line(l_foot + Vector2(-4.5, -8), l_foot + Vector2(3.5, -8), Color(0.32, 0.27, 0.22), 1.5)

	# Right boot outline + fill
	var rb_pts = PackedVector2Array([
		r_foot + Vector2(-6, 2), r_foot + Vector2(8, 2),
		r_foot + Vector2(7, -4), r_foot + Vector2(6, -9),
		r_foot + Vector2(-5, -9), r_foot + Vector2(-6, -4),
	])
	draw_colored_polygon(rb_pts, OL)
	var rb_inner = PackedVector2Array([
		r_foot + Vector2(-4.5, 0.5), r_foot + Vector2(6.5, 0.5),
		r_foot + Vector2(5.5, -3), r_foot + Vector2(4.5, -7.5),
		r_foot + Vector2(-3.5, -7.5), r_foot + Vector2(-4.5, -3),
	])
	draw_colored_polygon(rb_inner, boot_col)
	draw_circle(r_foot + Vector2(6, -1), 4.0, OL)
	draw_circle(r_foot + Vector2(6, -1), 2.5, boot_hi)
	draw_line(r_foot + Vector2(-5, 1), r_foot + Vector2(7, 1), boot_hi, 1.5)
	draw_line(r_foot + Vector2(-3.5, -8), r_foot + Vector2(5.5, -8), OL, 2.5)
	draw_line(r_foot + Vector2(-2.5, -8), r_foot + Vector2(4.5, -8), Color(0.32, 0.27, 0.22), 1.5)

	# === LEGS (short, thick — chibi proportions) ===
	var l_knee = l_foot.lerp(leg_top, 0.5) + Vector2(-1, 0)
	var r_knee = r_foot.lerp(leg_top, 0.5) + Vector2(1, 0)

	# Left leg — outline then fill (torn dark pants)
	draw_line(l_foot + Vector2(0, -7), l_knee, OL, 12.0)
	draw_line(l_foot + Vector2(0, -7), l_knee, cloth, 9.0)
	draw_line(l_knee, leg_top + Vector2(-5, 0), OL, 13.0)
	draw_line(l_knee, leg_top + Vector2(-5, 0), cloth, 10.0)
	# Left knee joint outline
	draw_circle(l_knee, 6.5, OL)
	draw_circle(l_knee, 4.8, cloth)

	# Right leg
	draw_line(r_foot + Vector2(0, -7), r_knee, OL, 12.0)
	draw_line(r_foot + Vector2(0, -7), r_knee, cloth, 9.0)
	draw_line(r_knee, leg_top + Vector2(5, 0), OL, 13.0)
	draw_line(r_knee, leg_top + Vector2(5, 0), cloth, 10.0)
	draw_circle(r_knee, 6.5, OL)
	draw_circle(r_knee, 4.8, cloth)

	# Torn fabric edges on pants (ragged hems)
	for ti in range(4):
		var t_x = -4.0 + float(ti) * 2.8
		var tl_base = l_knee + Vector2(t_x, 4.0)
		draw_line(tl_base, tl_base + Vector2(0, 2.5 + sin(float(ti) * 2.1) * 1.5), OL, 1.5)
		var tr_base = r_knee + Vector2(t_x, 4.0)
		draw_line(tr_base, tr_base + Vector2(0, 2.5 + sin(float(ti) * 1.7) * 1.5), OL, 1.5)

	# Skin visible between pants and boots (green shin)
	draw_line(l_knee + Vector2(0, 3), l_foot + Vector2(0, -8), OL, 9.0)
	draw_line(l_knee + Vector2(0, 3), l_foot + Vector2(0, -8), sk, 6.0)
	draw_line(r_knee + Vector2(0, 3), r_foot + Vector2(0, -8), OL, 9.0)
	draw_line(r_knee + Vector2(0, 3), r_foot + Vector2(0, -8), sk, 6.0)

	# === TORSO (broad, stocky, tattered dark shirt) ===
	var torso_pts_ol = PackedVector2Array([
		leg_top + Vector2(-11, 2), leg_top + Vector2(11, 2),
		torso_center + Vector2(16, 2), neck_base + Vector2(18, 2),
		neck_base + Vector2(18, -2), neck_base + Vector2(-18, -2),
		neck_base + Vector2(-18, 2), torso_center + Vector2(-16, 2),
	])
	draw_colored_polygon(torso_pts_ol, OL)
	var torso_pts = PackedVector2Array([
		leg_top + Vector2(-9, 0), leg_top + Vector2(9, 0),
		torso_center + Vector2(14, 0), neck_base + Vector2(16, 0),
		neck_base + Vector2(-16, 0), torso_center + Vector2(-14, 0),
	])
	draw_colored_polygon(torso_pts, cloth)
	# Chest highlight stripe
	draw_colored_polygon(PackedVector2Array([
		torso_center + Vector2(-8, -2), torso_center + Vector2(8, -2),
		neck_base + Vector2(10, 2), neck_base + Vector2(-10, 2),
	]), cloth_hi)

	# Torn shirt rip — green skin showing through
	var rip1 = torso_center + Vector2(-8, -1)
	draw_line(rip1, rip1 + Vector2(-4, 3), OL, 3.5)
	draw_line(rip1, rip1 + Vector2(-4, 3), sk, 2.0)
	var rip2 = neck_base + Vector2(7, 4)
	draw_line(rip2, rip2 + Vector2(3, 4), OL, 3.0)
	draw_line(rip2, rip2 + Vector2(3, 4), sk, 1.8)

	# Torso stitching (cross-stitch down center)
	var stitch_dark = Color(0.20, 0.18, 0.15, 0.8)
	draw_line(neck_base + Vector2(0, 3), torso_center + Vector2(0, 3), stitch_dark, 1.2)
	for sti in range(5):
		var st_y = neck_base.y + 3.0 + float(sti) * (torso_center.y - neck_base.y) / 5.0
		var st_x = neck_base.x + (torso_center.x - neck_base.x) * float(sti) / 5.0
		draw_line(Vector2(st_x - 2.5, st_y), Vector2(st_x + 2.5, st_y), stitch_dark, 0.9)

	# Belt/waist
	draw_line(leg_top + Vector2(-9, -1), leg_top + Vector2(9, -1), OL, 3.5)
	draw_line(leg_top + Vector2(-8, -1), leg_top + Vector2(8, -1), Color(0.30, 0.25, 0.20), 2.0)
	draw_circle(leg_top + Vector2(0, -1), 2.2, OL)
	draw_circle(leg_top + Vector2(0, -1), 1.5, Color(0.50, 0.48, 0.42))

	# === SHOULDERS (extra broad, chunky) ===
	var l_shoulder = neck_base + Vector2(-16, 1)
	var r_shoulder = neck_base + Vector2(16, 1)
	draw_circle(l_shoulder, 9.0, OL)
	draw_circle(l_shoulder, 7.0, sk_dark)
	draw_circle(l_shoulder + Vector2(-0.5, -1), 5.0, sk)
	draw_circle(r_shoulder, 9.0, OL)
	draw_circle(r_shoulder, 7.0, sk_dark)
	draw_circle(r_shoulder + Vector2(0.5, -1), 5.0, sk)
	draw_arc(l_shoulder, 7.5, PI * 0.2, PI * 0.8, 8, stitch_col, 1.2)
	draw_arc(r_shoulder, 7.5, PI * 0.2, PI * 0.8, 8, stitch_col, 1.2)

	# === LEFT ARM (smashing arm — extends on attack) ===
	var l_hand = l_shoulder + Vector2(-3, 16) + smash_extend
	var l_elbow = l_shoulder.lerp(l_hand, 0.45) + Vector2(-3, 0)
	draw_line(l_shoulder, l_elbow, OL, 13.0)
	draw_line(l_shoulder, l_elbow, sk_dark, 10.0)
	draw_line(l_shoulder + Vector2(0, 1), l_elbow + Vector2(0, 1), sk, 7.0)
	draw_circle(l_elbow, 6.5, OL)
	draw_circle(l_elbow, 5.0, sk_dark)
	draw_circle(l_elbow + Vector2(-0.5, -0.5), 3.5, sk)
	draw_line(l_elbow, l_hand, OL, 12.0)
	draw_line(l_elbow, l_hand, sk_dark, 9.0)
	draw_line(l_elbow + Vector2(0, 1), l_hand + Vector2(0, 1), sk, 6.0)

	# Left arm stitch
	var l_stitch_p = l_shoulder.lerp(l_elbow, 0.5)
	var la_d = (l_elbow - l_shoulder).normalized()
	var la_p = la_d.rotated(PI / 2.0)
	draw_line(l_stitch_p - la_p * 5.5, l_stitch_p + la_p * 5.5, stitch_col, 1.3)
	for lsi in range(4):
		var ls_pt = l_stitch_p + la_p * (-3.0 + float(lsi) * 2.0)
		draw_line(ls_pt + la_d * 1.5, ls_pt - la_d * 1.5, stitch_col, 0.9)

	# Broken chain on left wrist
	var l_wrist = l_elbow.lerp(l_hand, 0.82)
	draw_circle(l_wrist, 5.0, OL)
	draw_circle(l_wrist, 3.8, metal_dk)
	draw_circle(l_wrist + Vector2(-0.5, -0.5), 2.8, metal)
	for cli in range(3):
		var cl_pos = l_wrist + Vector2(-1, 3.5 + float(cli) * 4.0)
		draw_arc(cl_pos, 2.5, 0, PI, 6, OL, 2.5)
		draw_arc(cl_pos, 2.5, 0, PI, 6, metal, 1.5)
		draw_arc(cl_pos + Vector2(0, 2.5), 2.5, PI, TAU, 6, OL, 2.5)
		draw_arc(cl_pos + Vector2(0, 2.5), 2.5, PI, TAU, 6, metal_dk, 1.5)

	# Left FIST (massive, chunky)
	draw_circle(l_hand, 7.0, OL)
	draw_circle(l_hand, 5.5, sk_dark)
	draw_circle(l_hand + Vector2(-0.5, -0.5), 4.0, sk)
	for ki in range(4):
		var ka = float(ki - 1.5) * 0.3
		var kp = l_hand + Vector2.from_angle(aim_angle + ka) * 5.5
		draw_circle(kp, 2.5, OL)
		draw_circle(kp, 1.5, sk_hi)

	# Lightning crackling from left fist on attack
	if _attack_anim > 0.0:
		for fi in range(4):
			var f_angle = aim_angle + float(fi - 1.5) * 0.35
			var f_start = l_hand + Vector2.from_angle(f_angle) * 6.0
			var f_end = f_start + Vector2.from_angle(f_angle) * (7.0 + sin(_time * 15.0 + float(fi)) * 3.0)
			var f_mid = f_start.lerp(f_end, 0.5) + Vector2(sin(_time * 20.0 + float(fi) * 3.0) * 3.0, cos(_time * 18.0 + float(fi)) * 3.0)
			draw_line(f_start, f_mid, Color(0.5, 0.75, 1.0, _attack_anim * 0.7), 2.5)
			draw_line(f_mid, f_end, Color(0.8, 0.92, 1.0, _attack_anim * 0.6), 2.0)
			draw_circle(f_end, 2.0, Color(0.95, 0.97, 1.0, _attack_anim * 0.5))

	# === RIGHT ARM ===
	var r_hand = r_shoulder + Vector2(3, 14)
	var r_elbow = r_shoulder.lerp(r_hand, 0.45) + Vector2(3, 0)
	draw_line(r_shoulder, r_elbow, OL, 13.0)
	draw_line(r_shoulder, r_elbow, sk_dark, 10.0)
	draw_line(r_shoulder + Vector2(0, 1), r_elbow + Vector2(0, 1), sk, 7.0)
	draw_circle(r_elbow, 6.5, OL)
	draw_circle(r_elbow, 5.0, sk_dark)
	draw_circle(r_elbow + Vector2(0.5, -0.5), 3.5, sk)
	draw_line(r_elbow, r_hand, OL, 12.0)
	draw_line(r_elbow, r_hand, sk_dark, 9.0)
	draw_line(r_elbow + Vector2(0, 1), r_hand + Vector2(0, 1), sk, 6.0)

	# Right arm stitch
	var r_stitch_p = r_elbow.lerp(r_hand, 0.5)
	var ra_d = (r_hand - r_elbow).normalized()
	var ra_p = ra_d.rotated(PI / 2.0)
	draw_line(r_stitch_p - ra_p * 5.0, r_stitch_p + ra_p * 5.0, stitch_col, 1.3)
	for rsi in range(4):
		var rs_pt = r_stitch_p + ra_p * (-3.0 + float(rsi) * 2.0)
		draw_line(rs_pt + ra_d * 1.5, rs_pt - ra_d * 1.5, stitch_col, 0.9)

	# Broken chain on right wrist
	var r_wrist = r_elbow.lerp(r_hand, 0.82)
	draw_circle(r_wrist, 5.0, OL)
	draw_circle(r_wrist, 3.8, metal_dk)
	draw_circle(r_wrist + Vector2(0.5, -0.5), 2.8, metal)
	for cri in range(3):
		var cr_pos = r_wrist + Vector2(1, 3.5 + float(cri) * 4.0)
		draw_arc(cr_pos, 2.5, 0, PI, 6, OL, 2.5)
		draw_arc(cr_pos, 2.5, 0, PI, 6, metal, 1.5)
		draw_arc(cr_pos + Vector2(0, 2.5), 2.5, PI, TAU, 6, OL, 2.5)
		draw_arc(cr_pos + Vector2(0, 2.5), 2.5, PI, TAU, 6, metal_dk, 1.5)

	# Right FIST
	draw_circle(r_hand, 7.0, OL)
	draw_circle(r_hand, 5.5, sk_dark)
	draw_circle(r_hand + Vector2(0.5, -0.5), 4.0, sk)
	for ki in range(4):
		var ka = float(ki - 1.5) * 0.3
		var kp = r_hand + Vector2.from_angle(aim_angle + PI + ka) * 5.5
		draw_circle(kp, 2.5, OL)
		draw_circle(kp, 1.5, sk_hi)

	# Periodic lightning flicker from right fist
	var spark_phase = fmod(_time * 1.5, 3.0)
	if spark_phase < 0.5:
		var sp_alpha = 1.0 - spark_phase / 0.5
		for sfi in range(3):
			var sf_a = float(sfi - 1) * 0.4
			var sf_start = r_hand + Vector2.from_angle(aim_angle + PI + sf_a) * 6.0
			var sf_end = sf_start + Vector2(sin(_time * 12.0 + float(sfi)) * 5.0, cos(_time * 10.0 + float(sfi)) * 4.0)
			draw_line(sf_start, sf_end, Color(0.5, 0.75, 1.0, sp_alpha * 0.5), 1.8)
			draw_circle(sf_end, 1.5, Color(0.9, 0.95, 1.0, sp_alpha * 0.4))

	# === NECK (thick, powerful) ===
	var neck_top = head_center + Vector2(0, 10)
	draw_line(neck_base, neck_top, OL, 16.0)
	draw_line(neck_base, neck_top, sk_dark, 13.0)
	draw_line(neck_base + Vector2(0, 1), neck_top + Vector2(0, 1), sk, 9.0)

	# === NECK BOLTS (prominent metal cylinders!) ===
	var neck_mid = neck_base.lerp(neck_top, 0.45)
	var l_bolt = neck_mid + Vector2(-9, 0)
	var r_bolt = neck_mid + Vector2(9, 0)
	# Left bolt stem
	draw_line(l_bolt, l_bolt + Vector2(-8, 0), OL, 5.5)
	draw_line(l_bolt, l_bolt + Vector2(-8, 0), metal, 3.5)
	draw_line(l_bolt + Vector2(-1, -0.8), l_bolt + Vector2(-7, -0.8), metal_hi, 1.5)
	draw_circle(l_bolt + Vector2(-8, 0), 4.5, OL)
	draw_circle(l_bolt + Vector2(-8, 0), 3.2, metal)
	draw_circle(l_bolt + Vector2(-8.5, -0.8), 2.0, metal_hi)
	draw_line(l_bolt + Vector2(-10, 0), l_bolt + Vector2(-6, 0), metal_dk, 1.3)
	# Right bolt stem
	draw_line(r_bolt, r_bolt + Vector2(8, 0), OL, 5.5)
	draw_line(r_bolt, r_bolt + Vector2(8, 0), metal, 3.5)
	draw_line(r_bolt + Vector2(1, -0.8), r_bolt + Vector2(7, -0.8), metal_hi, 1.5)
	draw_circle(r_bolt + Vector2(8, 0), 4.5, OL)
	draw_circle(r_bolt + Vector2(8, 0), 3.2, metal)
	draw_circle(r_bolt + Vector2(8.5, -0.8), 2.0, metal_hi)
	draw_line(r_bolt + Vector2(6, 0), r_bolt + Vector2(10, 0), metal_dk, 1.3)

	# Bolt sparking
	var bolt_spark_t = fmod(_time * 1.8, 2.5)
	if bolt_spark_t < 0.4:
		var bspark_a = 1.0 - bolt_spark_t / 0.4
		draw_circle(l_bolt + Vector2(-8, 0), 4.0, Color(0.5, 0.7, 1.0, bspark_a * 0.4))
		draw_circle(l_bolt + Vector2(-8, 0), 2.0, Color(0.9, 0.95, 1.0, bspark_a * 0.6))
		draw_circle(r_bolt + Vector2(8, 0), 4.0, Color(0.5, 0.7, 1.0, bspark_a * 0.4))
		draw_circle(r_bolt + Vector2(8, 0), 2.0, Color(0.9, 0.95, 1.0, bspark_a * 0.6))
		for bsi in range(2):
			var bs_dir_v = Vector2.from_angle(fmod((_time * 7.3 + float(bsi) * 2.1) * 13.37, TAU))
			draw_line(l_bolt + Vector2(-8, 0), l_bolt + Vector2(-8, 0) + bs_dir_v * 5.0, Color(0.6, 0.8, 1.0, bspark_a * 0.5), 1.2)
			draw_line(r_bolt + Vector2(8, 0), r_bolt + Vector2(8, 0) + bs_dir_v * 5.0, Color(0.6, 0.8, 1.0, bspark_a * 0.5), 1.2)

	# === HEAD (FLAT-TOP! polygon, NOT circle) ===
	var hc = head_center
	var head_pts_ol = PackedVector2Array([
		hc + Vector2(-13, 4), hc + Vector2(-14, -1), hc + Vector2(-13, -6),
		hc + Vector2(-12, -11), hc + Vector2(-11, -15),
		hc + Vector2(-10, -17), hc + Vector2(10, -17),
		hc + Vector2(11, -15), hc + Vector2(12, -11),
		hc + Vector2(13, -6), hc + Vector2(14, -1), hc + Vector2(13, 4),
		hc + Vector2(10, 9), hc + Vector2(5, 11), hc + Vector2(0, 12),
		hc + Vector2(-5, 11), hc + Vector2(-10, 9),
	])
	draw_colored_polygon(head_pts_ol, OL)
	var head_pts = PackedVector2Array([
		hc + Vector2(-11, 3), hc + Vector2(-12, -1), hc + Vector2(-11, -5.5),
		hc + Vector2(-10, -10), hc + Vector2(-9, -13.5),
		hc + Vector2(-8.5, -15.5), hc + Vector2(8.5, -15.5),
		hc + Vector2(9, -13.5), hc + Vector2(10, -10),
		hc + Vector2(11, -5.5), hc + Vector2(12, -1), hc + Vector2(11, 3),
		hc + Vector2(8.5, 8), hc + Vector2(4, 9.5), hc + Vector2(0, 10.5),
		hc + Vector2(-4, 9.5), hc + Vector2(-8.5, 8),
	])
	draw_colored_polygon(head_pts, sk_dark)
	var head_hi_pts = PackedVector2Array([
		hc + Vector2(-8, -2), hc + Vector2(-9, -8), hc + Vector2(-7, -13),
		hc + Vector2(-4, -14.5), hc + Vector2(2, -14.5),
		hc + Vector2(5, -12), hc + Vector2(6, -6), hc + Vector2(5, 0),
		hc + Vector2(2, 5), hc + Vector2(-3, 6), hc + Vector2(-6, 3),
	])
	draw_colored_polygon(head_hi_pts, sk)
	draw_line(hc + Vector2(-8, -15.5), hc + Vector2(8, -15.5), sk_hi, 2.0)

	# === HEAVY BROW RIDGE ===
	draw_colored_polygon(PackedVector2Array([
		hc + Vector2(-11.5, -7), hc + Vector2(11.5, -7),
		hc + Vector2(10.5, -4), hc + Vector2(-10.5, -4),
	]), OL)
	draw_colored_polygon(PackedVector2Array([
		hc + Vector2(-10.5, -6.5), hc + Vector2(10.5, -6.5),
		hc + Vector2(9.5, -4.5), hc + Vector2(-9.5, -4.5),
	]), Color(0.32, 0.44, 0.26))

	# === FOREHEAD STITCHING ===
	draw_line(hc + Vector2(-9, -10), hc + Vector2(9, -10), OL, 1.8)
	for fsi in range(7):
		var fsx = -7.5 + float(fsi) * 2.5
		draw_line(Vector2(hc.x + fsx, hc.y - 11.5), Vector2(hc.x + fsx, hc.y - 8.5), OL, 1.2)

	# === EYES (smaller, sunken) ===
	var look_dir = dir * 1.0
	var l_eye = hc + Vector2(-5, -1.5)
	var r_eye = hc + Vector2(5, -1.5)
	draw_circle(l_eye, 5.5, Color(0.25, 0.32, 0.22, 0.5))
	draw_circle(r_eye, 5.5, Color(0.25, 0.32, 0.22, 0.5))
	draw_circle(l_eye, 4.5, OL)
	draw_circle(l_eye, 3.5, Color(0.88, 0.85, 0.78))
	draw_circle(r_eye, 4.5, OL)
	draw_circle(r_eye, 3.5, Color(0.88, 0.85, 0.78))
	var iris_col = Color(0.45, 0.55, 0.25)
	draw_circle(l_eye + look_dir * 0.5, 2.5, Color(0.35, 0.45, 0.18))
	draw_circle(l_eye + look_dir * 0.5, 1.8, iris_col)
	draw_circle(r_eye + look_dir * 0.5, 2.5, Color(0.35, 0.45, 0.18))
	draw_circle(r_eye + look_dir * 0.5, 1.8, iris_col)
	draw_circle(l_eye + look_dir * 0.6, 1.0, OL)
	draw_circle(r_eye + look_dir * 0.6, 1.0, OL)
	draw_circle(l_eye + Vector2(-0.8, -1.2), 1.0, Color(1.0, 1.0, 1.0, 0.85))
	draw_circle(r_eye + Vector2(-0.8, -1.2), 1.0, Color(1.0, 1.0, 1.0, 0.85))
	draw_circle(l_eye + Vector2(0.8, 0.5), 0.5, Color(1.0, 1.0, 1.0, 0.4))
	draw_circle(r_eye + Vector2(0.8, 0.5), 0.5, Color(1.0, 1.0, 1.0, 0.4))
	draw_arc(l_eye, 4.0, 0.3, PI - 0.3, 8, Color(0.30, 0.25, 0.22, 0.45), 2.0)
	draw_arc(r_eye, 4.0, 0.3, PI - 0.3, 8, Color(0.30, 0.25, 0.22, 0.45), 2.0)
	draw_arc(l_eye, 4.2, PI + 0.15, PI + 0.85, 8, OL, 2.2)
	draw_arc(r_eye, 4.2, TAU - 0.85, TAU - 0.15, 8, OL, 2.2)
	draw_line(l_eye + Vector2(-5, -4.5), l_eye + Vector2(2.5, -3.0), OL, 2.8)
	draw_line(r_eye + Vector2(-2.5, -3.0), r_eye + Vector2(5, -4.5), OL, 2.8)

	# === NOSE ===
	draw_line(hc + Vector2(-1, 0), hc + Vector2(-1.5, 4), OL, 2.5)
	draw_line(hc + Vector2(1, 0), hc + Vector2(1.5, 4), OL, 2.5)
	draw_line(hc + Vector2(-2.5, 4), hc + Vector2(2.5, 4), OL, 2.0)

	# === MOUTH ===
	draw_line(hc + Vector2(-5, 6.5), hc + Vector2(0, 5.5), OL, 2.5)
	draw_line(hc + Vector2(0, 5.5), hc + Vector2(5, 6.5), OL, 2.5)
	draw_line(hc + Vector2(-3.5, 7.0), hc + Vector2(3.5, 7.0), sk_hi, 1.2)

	# === JAW + FACE STITCHES ===
	draw_arc(hc + Vector2(0, 3), 11.5, 0.15, PI - 0.15, 12, OL, 2.0)
	draw_line(hc + Vector2(-7, -3), hc + Vector2(-6, 7), OL, 1.5)
	for fcsi in range(4):
		var fcs_y = -2.0 + float(fcsi) * 2.5
		draw_line(hc + Vector2(-8, fcs_y), hc + Vector2(-5, fcs_y), OL, 1.0)
	draw_line(hc + Vector2(5, -1), hc + Vector2(7, 5), OL, 1.3)
	for fcri in range(3):
		var fcr_y = 0.0 + float(fcri) * 2.0
		draw_line(hc + Vector2(4, fcr_y), hc + Vector2(7, fcr_y), OL, 0.9)

	# === EARS ===
	draw_circle(hc + Vector2(-12, 1), 3.5, OL)
	draw_circle(hc + Vector2(-12, 1), 2.2, sk_dark)
	draw_circle(hc + Vector2(12, 1), 3.5, OL)
	draw_circle(hc + Vector2(12, 1), 2.2, sk_dark)

	# === SMASH IMPACT EFFECT ===
	if _smash_anim > 0.0:
		var crack_alpha = _smash_anim * 0.6
		var crack_r = 20.0 + (1.0 - _smash_anim) * smash_radius * 0.6
		for ci in range(8):
			var ca = TAU * float(ci) / 8.0 + _smash_anim * 0.5
			var c_start_pt = Vector2.from_angle(ca) * 10.0 + l_hand
			var c_end_pt = Vector2.from_angle(ca) * crack_r + l_hand
			var c_mid_pt = c_start_pt.lerp(c_end_pt, 0.5) + Vector2(sin(float(ci) * 3.1) * 5.0, cos(float(ci) * 2.7) * 4.0)
			draw_line(c_start_pt, c_mid_pt, Color(0.5, 0.75, 1.0, crack_alpha), 2.5)
			draw_line(c_mid_pt, c_end_pt, Color(0.4, 0.65, 1.0, crack_alpha * 0.6), 2.0)
		draw_circle(l_hand, 10.0, Color(0.8, 0.9, 1.0, _smash_anim * 0.35))
		draw_circle(l_hand, 5.0, Color(1.0, 1.0, 1.0, _smash_anim * 0.55))

	# === 21. ELECTRIC AURA (T4 permanent) ===
	if _aura_active:
		var aura_pulse = (sin(_time * 2.0) + 1.0) * 0.5
		var aura_r = smash_radius * 1.2
		draw_arc(Vector2.ZERO, aura_r, 0, TAU, 48, Color(0.4, 0.6, 1.0, 0.08 + aura_pulse * 0.04), 1.5)
		draw_arc(Vector2.ZERO, aura_r * 0.8, 0, TAU, 36, Color(0.5, 0.7, 1.0, 0.06 + aura_pulse * 0.03), 1.0)
		# Orbiting electric motes
		for ai in range(6):
			var aa = _time * 0.8 + float(ai) * TAU / 6.0
			var ar = aura_r * (0.85 + sin(_time * 1.5 + float(ai) * 1.3) * 0.15)
			var ap = Vector2(cos(aa) * ar, sin(aa) * ar * 0.4)
			draw_circle(ap, 1.5, Color(0.6, 0.8, 1.0, 0.25 + aura_pulse * 0.1))

	# === 22. KILL STACK INDICATOR ===
	if kill_stack_bonus > 0.0:
		var stack_display = "%.0f%%" % (kill_stack_bonus * 100.0)
		var stack_alpha = minf(kill_stack_bonus * 2.0, 0.6)
		# Glow beneath feet indicating accumulated power
		draw_circle(Vector2(0, plat_y), 18.0 + kill_stack_bonus * 30.0, Color(0.4, 0.6, 1.0, stack_alpha * 0.1))

	# === 23. UPGRADE NAME FLASH ===
	if _upgrade_flash > 0.0 and _upgrade_name != "":
		# Name displayed above the tower briefly
		pass  # Text rendering handled by main.gd overlay
