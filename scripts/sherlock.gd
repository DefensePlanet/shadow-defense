extends Node2D
## Sherlock Holmes — precision/support tower. Magnifying glass focus beam that burns.
## Ability: "Deduction" — marks target enemy, all towers deal +30% to marked target for 8s.
## Tier 1 (5000 DMG): Faster Deduction — mark lasts 12s
## Tier 2 (10000 DMG): Piercing Insight — beam pierces through to 2nd enemy
## Tier 3 (15000 DMG): Multi-Mark — can mark 2 targets simultaneously
## Tier 4 (20000 DMG): The Game is Afoot — all enemies in range auto-marked, +50% personal damage

# Base stats
var damage: float = 23.0
var fire_rate: float = 1.8
var attack_range: float = 250.0
var fire_cooldown: float = 0.0
var aim_angle: float = 0.0
var target: Node2D = null
var gold_bonus: int = 2

# Animation timers
var _time: float = 0.0
var _attack_anim: float = 0.0

# Damage tracking and upgrades
var damage_dealt: float = 0.0
var upgrade_tier: int = 0
var _upgrade_flash: float = 0.0
var _upgrade_name: String = ""

# Tier 1: Faster Deduction — mark duration increases
var mark_duration: float = 8.0

# Tier 2: Piercing Insight — beam pierces
var pierce_count: int = 0

# Tier 3: Multi-Mark — simultaneous marks
var max_marks: int = 1
var _marked_enemies: Array = []
var _mark_timers: Array = []

# Tier 4: The Game is Afoot — auto-mark + damage boost
var auto_mark: bool = false
var personal_damage_bonus: float = 1.0

# Deduction mark flash
var _deduction_flash: float = 0.0

# Kill tracking
var kill_count: int = 0

# Splash (unlockable via progressive abilities)
var splash_radius: float = 0.0

# === PROGRESSIVE ABILITIES (9 tiers, unlocked via lifetime damage) ===
const PROG_ABILITY_NAMES = [
	"Baker Street Logic", "Observation", "The Science of Deduction", "Watson's Aid",
	"Disguise Master", "Violin Meditation", "Cocaine Clarity", "Reichenbach Gambit",
	"Consulting Detective"
]
const PROG_ABILITY_DESCS = [
	"Beam travels 25% faster, +10% damage",
	"Every 10s, reveal invisible/camouflaged enemies in range for 4s",
	"Every marked enemy takes additional 1% max HP/s as burn",
	"Every 25s, heal 1 life and boost nearest tower attack speed +20% for 5s",
	"Every 15s, become untargetable for 3s; attacks during deal 2x",
	"Every 20s, slow all enemies in range by 40% for 3s",
	"Every 12s, next shot deals 5x damage and marks on hit",
	"When health drops below 3, deal 10x damage to all enemies in range (once per wave)",
	"All towers on map gain +15% damage permanently while Sherlock is placed"
]
var prog_abilities: Array = [false, false, false, false, false, false, false, false, false]
# Ability timers
var _observation_timer: float = 10.0
var _watsons_aid_timer: float = 25.0
var _disguise_timer: float = 15.0
var _disguise_invis: float = 0.0
var _violin_timer: float = 20.0
var _cocaine_timer: float = 12.0
var _cocaine_ready: bool = false
var _reichenbach_used: bool = false
# Visual flash timers
var _observation_flash: float = 0.0
var _violin_flash: float = 0.0
var _cocaine_flash: float = 0.0
var _reichenbach_flash: float = 0.0

const STAT_UPGRADE_INTERVAL: float = 500.0
const ABILITY_THRESHOLD: float = 1500.0
var stat_upgrade_level: int = 0
var ability_chosen: bool = false
var awaiting_ability_choice: bool = false
const TIER_NAMES = [
	"Faster Deduction",
	"Piercing Insight",
	"Multi-Mark",
	"The Game is Afoot"
]
const ABILITY_DESCRIPTIONS = [
	"Mark lasts 12s instead of 8s",
	"Beam pierces through to 2nd enemy",
	"Can mark 2 targets simultaneously",
	"All enemies in range auto-marked, +50% personal damage"
]
const TIER_COSTS = [100, 200, 350, 550]
var is_selected: bool = false
var base_cost: int = 0

var focus_beam_scene = preload("res://scenes/focus_beam.tscn")

# Attack sounds — focused lens hum sounds evolving with upgrade tier
var _attack_sounds: Array = []
var _attack_sounds_by_tier: Array = []
var _attack_player: AudioStreamPlayer

# Ability sounds
var _deduction_sound: AudioStreamWAV
var _deduction_player: AudioStreamPlayer
var _upgrade_sound: AudioStreamWAV
var _upgrade_player: AudioStreamPlayer

func _ready() -> void:
	add_to_group("towers")
	_load_progressive_abilities()
	_generate_tier_sounds()
	_attack_sounds = _attack_sounds_by_tier[0]
	_attack_player = AudioStreamPlayer.new()
	_attack_player.stream = _attack_sounds[0]
	_attack_player.volume_db = -4.0
	add_child(_attack_player)

	# Deduction chime — crystalline bell with harmonic overtones (E5, G#5, B5)
	var ded_rate := 22050
	var ded_dur := 0.5
	var ded_samples := PackedFloat32Array()
	ded_samples.resize(int(ded_rate * ded_dur))
	var ded_notes := [659.25, 830.61, 987.77]  # E5, G#5, B5
	var ded_note_len := int(ded_rate * ded_dur) / 3
	for i in ded_samples.size():
		var t := float(i) / ded_rate
		var ni := mini(i / ded_note_len, 2)
		var nt := float(i - ni * ded_note_len) / float(ded_rate)
		var freq: float = ded_notes[ni]
		var att := minf(nt * 60.0, 1.0)
		var dec := exp(-nt * 6.0)
		var env := att * dec * 0.4
		var s := sin(TAU * freq * t) + sin(TAU * freq * 2.0 * t) * 0.25 + sin(TAU * freq * 3.0 * t) * 0.1
		# Add slight glass resonance shimmer
		s += sin(TAU * freq * 1.002 * t) * 0.15 * exp(-nt * 4.0)
		ded_samples[i] = clampf(s * env, -1.0, 1.0)
	_deduction_sound = _samples_to_wav(ded_samples, ded_rate)
	_deduction_player = AudioStreamPlayer.new()
	_deduction_player.stream = _deduction_sound
	_deduction_player.volume_db = -6.0
	add_child(_deduction_player)

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
	_deduction_flash = max(_deduction_flash - delta * 2.0, 0.0)
	_attack_anim = max(_attack_anim - delta * 3.0, 0.0)
	target = _find_nearest_enemy()

	if target:
		var desired = global_position.angle_to_point(target.global_position) + PI
		aim_angle = lerp_angle(aim_angle, desired, 10.0 * delta)
		if fire_cooldown <= 0.0:
			_shoot()
			fire_cooldown = 1.0 / (fire_rate * _speed_mult())
			_attack_anim = 1.0
	# Update mark timers
	_update_marks(delta)

	# Tier 4: Auto-mark all enemies in range
	if auto_mark:
		_auto_mark_enemies()

	# Progressive abilities
	_process_progressive_abilities(delta)

	queue_redraw()

func _update_marks(delta: float) -> void:
	var i = 0
	while i < _marked_enemies.size():
		_mark_timers[i] -= delta
		if _mark_timers[i] <= 0.0 or not is_instance_valid(_marked_enemies[i]):
			if is_instance_valid(_marked_enemies[i]) and "deduction_marked" in _marked_enemies[i]:
				_marked_enemies[i].deduction_marked = false
			_marked_enemies.remove_at(i)
			_mark_timers.remove_at(i)
		else:
			i += 1

func _auto_mark_enemies() -> void:
	var eff_range = attack_range * _range_mult()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(enemy.global_position) < eff_range:
			if not enemy in _marked_enemies:
				_apply_mark_to_enemy(enemy)

func _has_enemies_in_range() -> bool:
	var eff_range = attack_range * _range_mult()
	for enemy in get_tree().get_nodes_in_group("enemies"):
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
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist: float = attack_range * _range_mult()
	for enemy in enemies:
		var dist = global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest = enemy
			nearest_dist = dist
	return nearest

func _shoot() -> void:
	if not target:
		return
	if _attack_player and _attack_sounds.size() > 0 and not _is_sfx_muted():
		_attack_player.stream = _attack_sounds[_get_note_index() % _attack_sounds.size()]
		_attack_player.play()

	# Cocaine Clarity — next shot 5x damage + mark
	var cocaine_shot = prog_abilities[6] and _cocaine_ready
	if cocaine_shot:
		_cocaine_ready = false
		_cocaine_flash = 1.0

	_fire_beam(target, cocaine_shot)

func _fire_beam(t: Node2D, cocaine_shot: bool = false) -> void:
	var beam = focus_beam_scene.instantiate()
	beam.global_position = global_position + Vector2.from_angle(aim_angle) * 20.0
	var dmg_mult = personal_damage_bonus
	# Ability 1: Baker Street Logic — +10% damage
	if prog_abilities[0]:
		dmg_mult *= 1.10
	# Ability 5: Disguise Master — 2x during invisibility
	if prog_abilities[4] and _disguise_invis > 0.0:
		dmg_mult *= 2.0
	# Cocaine Clarity — 5x damage
	if cocaine_shot:
		dmg_mult *= 5.0
	beam.damage = damage * dmg_mult * _damage_mult()
	beam.target = t
	beam.gold_bonus = int(gold_bonus * _gold_mult())
	beam.source_tower = self
	beam.pierce_count = pierce_count
	beam.splash_radius = splash_radius
	beam.mark_on_hit = cocaine_shot  # Cocaine shots always mark
	# Ability 1: Baker Street Logic — 25% faster beams
	if prog_abilities[0]:
		beam.speed *= 1.25
	get_tree().get_first_node_in_group("main").add_child(beam)

func _mark_enemy(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return
	# Check if already marked
	if enemy in _marked_enemies:
		# Refresh the timer
		var idx = _marked_enemies.find(enemy)
		_mark_timers[idx] = mark_duration
		return
	# Remove oldest mark if at limit
	if _marked_enemies.size() >= max_marks:
		var oldest = _marked_enemies[0]
		if is_instance_valid(oldest) and "deduction_marked" in oldest:
			oldest.deduction_marked = false
		_marked_enemies.remove_at(0)
		_mark_timers.remove_at(0)
	_apply_mark_to_enemy(enemy)

func _apply_mark_to_enemy(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return
	if enemy in _marked_enemies:
		return
	if "deduction_marked" in enemy:
		enemy.deduction_marked = true
	_marked_enemies.append(enemy)
	_mark_timers.append(mark_duration)
	_deduction_flash = 1.0
	if _deduction_player and not _is_sfx_muted():
		_deduction_player.play()

func register_damage(amount: float) -> void:
	damage_dealt += amount
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("register_tower_damage"):
		main.register_tower_damage(main.TowerType.SHERLOCK, amount)

func register_kill() -> void:
	kill_count += 1
	if kill_count % 10 == 0:
		var bonus = 3 + kill_count / 10
		var main = get_tree().get_first_node_in_group("main")
		if main:
			main.add_gold(bonus)
		_upgrade_flash = 1.0
		_upgrade_name = "Deduced %d gold!" % bonus

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
	damage *= 1.10
	fire_rate *= 1.06
	attack_range += 6.0
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
		1: # Faster Deduction — mark lasts 12s
			mark_duration = 12.0
			damage = 30.0
			fire_rate = 2.0
			attack_range = 270.0
		2: # Piercing Insight — beam pierces to 2nd enemy
			pierce_count = 1
			damage = 38.0
			fire_rate = 2.2
			attack_range = 285.0
			gold_bonus = 3
		3: # Multi-Mark — can mark 2 simultaneously
			max_marks = 2
			damage = 45.0
			fire_rate = 2.5
			attack_range = 300.0
			gold_bonus = 4
			mark_duration = 14.0
		4: # The Game is Afoot — auto-mark + damage
			auto_mark = true
			personal_damage_bonus = 1.5
			damage = 58.0
			fire_rate = 3.0
			attack_range = 320.0
			gold_bonus = 5
			pierce_count = 2
			max_marks = 99
			mark_duration = 16.0

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
	if _upgrade_player and not _is_sfx_muted(): _upgrade_player.play()
	return true

func get_tower_display_name() -> String:
	return "Sherlock Holmes"

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
	# Focused lens hum — warm resonant harmonic with glass overtone
	var hum_notes := [293.66, 329.63, 349.23, 440.00, 349.23, 329.63, 293.66, 392.00]  # D4, E4, F4, A4, F4, E4, D4, G4 (D minor analytical stepwise)
	var mix_rate := 44100
	_attack_sounds_by_tier = []

	# --- Tier 0: Simple Lens Hum (warm sine + gentle glass ring) ---
	var t0 := []
	for note_idx in hum_notes.size():
		var freq: float = hum_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.15))
		for i in samples.size():
			var t := float(i) / mix_rate
			# Warm focused hum — smooth onset, moderate decay
			var env := minf(t * 40.0, 1.0) * exp(-t * 18.0) * 0.3
			var fund := sin(t * freq * TAU)
			var h2 := sin(t * freq * 2.0 * TAU) * 0.15 * exp(-t * 25.0)
			# Gentle glass ring (high overtone)
			var glass := sin(t * freq * 4.0 * TAU) * 0.06 * exp(-t * 40.0)
			samples[i] = clampf((fund + h2 + glass) * env, -1.0, 1.0)
		t0.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t0)

	# --- Tier 1: Focused Lens (sharper attack, brighter overtone) ---
	var t1 := []
	for note_idx in hum_notes.size():
		var freq: float = hum_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.16))
		for i in samples.size():
			var t := float(i) / mix_rate
			var env := minf(t * 50.0, 1.0) * exp(-t * 16.0) * 0.32
			var fund := sin(t * freq * TAU)
			var h2 := sin(t * freq * 2.0 * TAU) * 0.18 * exp(-t * 22.0)
			var h3 := sin(t * freq * 3.0 * TAU) * 0.08 * exp(-t * 30.0)
			# Brighter glass shimmer
			var glass := sin(t * freq * 5.0 * TAU) * 0.08 * exp(-t * 35.0)
			var detune := sin(t * freq * 1.003 * TAU) * 0.1 * exp(-t * 20.0)
			samples[i] = clampf((fund + h2 + h3 + glass + detune) * env, -1.0, 1.0)
		t1.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t1)

	# --- Tier 2: Piercing Beam (sharper, more resonant) ---
	var t2 := []
	for note_idx in hum_notes.size():
		var freq: float = hum_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.18))
		for i in samples.size():
			var t := float(i) / mix_rate
			var env := minf(t * 60.0, 1.0) * exp(-t * 14.0) * 0.32
			var fund := sin(t * freq * TAU)
			var h2 := sin(t * freq * 2.0 * TAU) * 0.2 * exp(-t * 20.0)
			var h3 := sin(t * freq * 3.0 * TAU) * 0.12 * exp(-t * 26.0)
			# Piercing glass resonance
			var glass := sin(t * freq * 6.0 * TAU) * 0.1 * exp(-t * 30.0)
			# Slight buzz from intensity
			var buzz := sin(t * freq * 1.5 * TAU) * 0.06 * exp(-t * 18.0)
			samples[i] = clampf((fund + h2 + h3 + glass + buzz) * env, -1.0, 1.0)
		t2.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t2)

	# --- Tier 3: Multi-Beam (doubled hum with detuned chorus) ---
	var t3 := []
	for note_idx in hum_notes.size():
		var freq: float = hum_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.2))
		for i in samples.size():
			var t := float(i) / mix_rate
			var env := minf(t * 55.0, 1.0) * exp(-t * 12.0) * 0.3
			# Primary beam
			var s1 := sin(t * freq * TAU) + sin(t * freq * 2.0 * TAU) * 0.18
			# Secondary detuned beam
			var s2 := sin(t * freq * 1.008 * TAU) * 0.4 + sin(t * freq * 2.016 * TAU) * 0.1
			# Glass harmonics
			var glass := sin(t * freq * 5.0 * TAU) * 0.08 * exp(-t * 28.0)
			samples[i] = clampf((s1 + s2 + glass) * env, -1.0, 1.0)
		t3.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t3)

	# --- Tier 4: Legendary Lens (rich harmonics + heroic shimmer) ---
	var t4 := []
	for note_idx in hum_notes.size():
		var freq: float = hum_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.22))
		for i in samples.size():
			var t := float(i) / mix_rate
			var env := minf(t * 50.0, 1.0) * exp(-t * 10.0) * 0.3
			var fund := sin(t * freq * TAU)
			var h2 := sin(t * freq * 2.0 * TAU) * 0.2
			var h3 := sin(t * freq * 3.0 * TAU) * 0.12 * exp(-t * 18.0)
			var h4 := sin(t * freq * 4.0 * TAU) * 0.06 * exp(-t * 22.0)
			# Heroic shimmer (detuned chorus)
			var shim := sin(t * freq * 2.005 * TAU) * 0.1 * exp(-t * 8.0)
			shim += sin(t * freq * 1.995 * TAU) * 0.1 * exp(-t * 8.0)
			# Bright glass ring
			var glass := sin(t * freq * 7.0 * TAU) * 0.05 * exp(-t * 25.0)
			samples[i] = clampf((fund + h2 + h3 + h4 + glass) * env + shim * env, -1.0, 1.0)
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
	if main and main.survivor_progress.has(main.TowerType.SHERLOCK):
		var p = main.survivor_progress[main.TowerType.SHERLOCK]
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
	if prog_abilities[0]:  # Baker Street Logic: applied in _fire_beam
		pass
	if prog_abilities[8]:  # Consulting Detective: global +15% damage buff
		for tower in get_tree().get_nodes_in_group("towers"):
			if tower != self and tower.has_method("set_synergy_buff"):
				tower.set_synergy_buff({"damage": 0.15})

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
	_observation_flash = max(_observation_flash - delta * 2.0, 0.0)
	_violin_flash = max(_violin_flash - delta * 2.0, 0.0)
	_cocaine_flash = max(_cocaine_flash - delta * 1.5, 0.0)
	_reichenbach_flash = max(_reichenbach_flash - delta * 2.0, 0.0)

	# Ability 2: Observation — reveal invisible enemies
	if prog_abilities[1]:
		_observation_timer -= delta
		if _observation_timer <= 0.0 and _has_enemies_in_range():
			_observation_reveal()
			_observation_timer = 10.0

	# Ability 3: The Science of Deduction — burn damage on marked enemies
	if prog_abilities[2]:
		for enemy in _marked_enemies:
			if is_instance_valid(enemy) and enemy.has_method("take_damage"):
				var burn = enemy.get("max_health") if "max_health" in enemy else 100.0
				var burn_dmg = burn * 0.01 * delta
				enemy.take_damage(burn_dmg)
				register_damage(burn_dmg)

	# Ability 4: Watson's Aid — heal + boost nearest tower
	if prog_abilities[3]:
		_watsons_aid_timer -= delta
		if _watsons_aid_timer <= 0.0:
			_watsons_aid()
			_watsons_aid_timer = 25.0

	# Ability 5: Disguise Master — invisibility cycle
	if prog_abilities[4]:
		if _disguise_invis > 0.0:
			_disguise_invis -= delta
		else:
			_disguise_timer -= delta
			if _disguise_timer <= 0.0:
				_disguise_invis = 3.0
				_disguise_timer = 15.0

	# Ability 6: Violin Meditation — slow enemies
	if prog_abilities[5]:
		_violin_timer -= delta
		if _violin_timer <= 0.0 and _has_enemies_in_range():
			_violin_slow()
			_violin_timer = 20.0

	# Ability 7: Cocaine Clarity — charged shot
	if prog_abilities[6]:
		if not _cocaine_ready:
			_cocaine_timer -= delta
			if _cocaine_timer <= 0.0:
				_cocaine_ready = true
				_cocaine_flash = 0.5
				_cocaine_timer = 12.0

	# Ability 8: Reichenbach Gambit — desperation nuke
	if prog_abilities[7] and not _reichenbach_used:
		var main = get_tree().get_first_node_in_group("main")
		if main and "lives" in main and main.lives <= 3:
			_reichenbach_strike()
			_reichenbach_used = true

func _observation_reveal() -> void:
	_observation_flash = 1.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) < attack_range * _range_mult():
			if e.has_method("reveal"):
				e.reveal(4.0)

func _watsons_aid() -> void:
	# Heal 1 life
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("restore_life"):
		main.restore_life(1)
	# Boost nearest tower attack speed
	var nearest_tower: Node2D = null
	var nearest_dist: float = 999999.0
	for tower in get_tree().get_nodes_in_group("towers"):
		if tower == self:
			continue
		var dist = global_position.distance_to(tower.global_position)
		if dist < nearest_dist:
			nearest_tower = tower
			nearest_dist = dist
	if nearest_tower and nearest_tower.has_method("set_synergy_buff"):
		nearest_tower.set_synergy_buff({"attack_speed": 0.20})

func _violin_slow() -> void:
	_violin_flash = 1.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) < attack_range * _range_mult():
			if e.has_method("apply_slow"):
				e.apply_slow(0.6, 3.0)

func _reichenbach_strike() -> void:
	_reichenbach_flash = 1.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) < attack_range * _range_mult():
			if e.has_method("take_damage"):
				var dmg = damage * 10.0
				e.take_damage(dmg)
				register_damage(dmg)

func _draw() -> void:
	# === 1. SELECTION RING ===
	if is_selected:
		var pulse = (sin(_time * 3.0) + 1.0) * 0.5
		var ring_alpha = 0.5 + pulse * 0.3
		draw_arc(Vector2.ZERO, 40.0, 0, TAU, 48, Color(0.85, 0.72, 0.25, ring_alpha), 2.5)
		draw_arc(Vector2.ZERO, 43.0, 0, TAU, 48, Color(0.85, 0.72, 0.25, ring_alpha * 0.4), 1.5)

	# === 2. RANGE ARC ===
	draw_arc(Vector2.ZERO, attack_range, 0, TAU, 64, Color(1, 1, 1, 0.06), 1.0)

	# === 3. AIM DIRECTION ===
	var dir = Vector2.from_angle(aim_angle)
	var perp = dir.rotated(PI / 2.0)

	# === 4. IDLE ANIMATION (analytical, observant stance) ===
	var breathe = sin(_time * 2.0) * 1.5
	var weight_shift = sin(_time * 1.0) * 1.5  # Slow subtle weight shift
	var thinking_bob = sin(_time * 1.5) * 1.0  # Slight head thinking bob
	var bob = Vector2(weight_shift, -breathe)

	# Tier 4: Elevated pose (legendary detective)
	var fly_offset = Vector2.ZERO
	if upgrade_tier >= 4:
		fly_offset = Vector2(0, -8.0 + sin(_time * 1.5) * 2.5)

	var body_offset = bob + fly_offset

	# Per-joint differential offsets
	var hip_shift = sin(_time * 1.0) * 1.0
	var shoulder_counter = -sin(_time * 1.0) * 0.6

	# === 5. SKIN COLORS ===
	var skin_base = Color(0.90, 0.78, 0.65)
	var skin_shadow = Color(0.76, 0.62, 0.50)
	var skin_highlight = Color(0.95, 0.85, 0.74)

	# === 6. UPGRADE FLASH ===
	if _upgrade_flash > 0.0:
		draw_circle(Vector2.ZERO, 80.0 + _upgrade_flash * 24.0, Color(0.85, 0.72, 0.25, _upgrade_flash * 0.25))

	# === 7. DEDUCTION FLASH ===
	if _deduction_flash > 0.0:
		var ded_ring_r = 30.0 + (1.0 - _deduction_flash) * 60.0
		draw_circle(Vector2.ZERO, ded_ring_r, Color(1.0, 0.92, 0.5, _deduction_flash * 0.12))
		draw_arc(Vector2.ZERO, ded_ring_r, 0, TAU, 32, Color(1.0, 0.88, 0.35, _deduction_flash * 0.3), 2.5)
		# Radiating golden insight rays
		for di in range(6):
			var da = TAU * float(di) / 6.0 + _deduction_flash * 3.0
			var d_inner = Vector2.from_angle(da) * (ded_ring_r * 0.4)
			var d_outer = Vector2.from_angle(da) * (ded_ring_r + 4.0)
			draw_line(d_inner, d_outer, Color(1.0, 0.90, 0.4, _deduction_flash * 0.35), 1.5)

	# === MARK INDICATORS (floating above marked enemies) ===
	for mi in range(_marked_enemies.size()):
		if is_instance_valid(_marked_enemies[mi]):
			var mark_pos = _marked_enemies[mi].global_position - global_position
			var mark_pulse = sin(_time * 4.0 + float(mi)) * 2.0
			# Magnifying glass icon over marked enemy
			draw_arc(mark_pos + Vector2(0, -20 + mark_pulse), 6.0, 0, TAU, 12, Color(1.0, 0.85, 0.3, 0.6), 1.5)
			draw_circle(mark_pos + Vector2(0, -20 + mark_pulse), 5.0, Color(1.0, 0.92, 0.5, 0.15))
			draw_line(mark_pos + Vector2(4, -16 + mark_pulse), mark_pos + Vector2(8, -12 + mark_pulse), Color(0.85, 0.72, 0.25, 0.5), 1.5)

	# === PROGRESSIVE ABILITY VISUAL EFFECTS ===
	# Ability 2: Observation flash
	if _observation_flash > 0.0:
		var obs_r = 25.0 + (1.0 - _observation_flash) * 80.0
		draw_arc(Vector2.ZERO, obs_r, 0, TAU, 24, Color(1.0, 1.0, 0.8, _observation_flash * 0.3), 2.0)
		# Eye symbol at center
		draw_arc(Vector2(0, -50), 5.0, PI * 0.2, PI * 0.8, 8, Color(1.0, 0.95, 0.6, _observation_flash * 0.5), 1.5)
		draw_arc(Vector2(0, -50), 5.0, PI * 1.2, PI * 1.8, 8, Color(1.0, 0.95, 0.6, _observation_flash * 0.5), 1.5)

	# Ability 5: Disguise Master invisibility
	if prog_abilities[4] and _disguise_invis > 0.0:
		draw_circle(Vector2.ZERO, 28.0, Color(0.4, 0.4, 0.5, 0.12))

	# Ability 6: Violin Meditation flash
	if _violin_flash > 0.0:
		for vi in range(5):
			var va = TAU * float(vi) / 5.0 + _violin_flash * 2.0
			var v_r = 20.0 + (1.0 - _violin_flash) * 40.0
			var vpos = Vector2.from_angle(va) * v_r
			# Musical note symbols
			draw_circle(vpos, 2.5, Color(0.6, 0.5, 0.3, _violin_flash * 0.4))
			draw_line(vpos + Vector2(2, 0), vpos + Vector2(2, -5), Color(0.6, 0.5, 0.3, _violin_flash * 0.3), 0.8)

	# Ability 7: Cocaine Clarity ready indicator
	if prog_abilities[6] and _cocaine_ready:
		var cc_pulse = sin(_time * 6.0) * 0.15
		draw_circle(body_offset + Vector2(0, -45), 4.0, Color(1.0, 1.0, 0.9, 0.3 + cc_pulse))
		draw_arc(body_offset + Vector2(0, -45), 5.0, 0, TAU, 10, Color(1.0, 0.95, 0.7, 0.4 + cc_pulse), 1.0)

	# Ability 8: Reichenbach flash
	if _reichenbach_flash > 0.0:
		draw_circle(Vector2.ZERO, 60.0 * (1.0 - _reichenbach_flash * 0.3), Color(1.0, 0.5, 0.2, _reichenbach_flash * 0.3))
		draw_arc(Vector2.ZERO, 50.0 + (1.0 - _reichenbach_flash) * 30.0, 0, TAU, 24, Color(1.0, 0.6, 0.1, _reichenbach_flash * 0.4), 3.0)

	# === 8. STONE PLATFORM ===
	var plat_y = 22.0
	# Platform shadow
	draw_circle(Vector2(0, plat_y + 4), 28.0, Color(0, 0, 0, 0.15))
	# Stone platform ellipse
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

	# Magnifying glass emblem on platform
	var emblem_y = plat_y + 1.0
	draw_set_transform(Vector2(0, emblem_y), 0, Vector2(1.0, 0.45))
	draw_arc(Vector2(-2, 0), 8.0, 0, TAU, 12, Color(0.85, 0.72, 0.25, 0.2), 1.2)
	draw_line(Vector2(4, 5), Vector2(9, 10), Color(0.85, 0.72, 0.25, 0.15), 1.5)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	# === 9. SHADOW TENDRILS ===
	for ti in range(5):
		var ta = TAU * float(ti) / 5.0 + _time * 0.3
		var t_base = Vector2(cos(ta) * 24.0, plat_y + sin(ta) * 8.0)
		var t_end = t_base + Vector2(sin(_time * 0.8 + float(ti)) * 6.0, 8.0 + sin(_time * 1.2 + float(ti)) * 4.0)
		draw_line(t_base, t_end, Color(0.04, 0.02, 0.06, 0.2), 2.0)
		draw_line(t_end, t_end + Vector2(sin(_time + float(ti)) * 3.0, 5.0), Color(0.04, 0.02, 0.06, 0.1), 1.5)

	# === 10. TIER PIPS (amber/gold theme) ===
	for i in range(upgrade_tier):
		var pip_angle = -PI / 2.0 + float(i) * (TAU / 4.0) - (float(upgrade_tier - 1) * TAU / 8.0)
		var pip_pos = Vector2(cos(pip_angle) * 22.0, plat_y + sin(pip_angle) * 8.0)
		var pip_col: Color
		match i:
			0: pip_col = Color(0.85, 0.72, 0.25)   # amber gold
			1: pip_col = Color(0.7, 0.75, 0.82)     # silver insight
			2: pip_col = Color(0.90, 0.80, 0.30)    # bright gold
			3: pip_col = Color(1.0, 0.90, 0.40)     # legendary gold
		draw_circle(pip_pos, 4.0, pip_col)
		draw_circle(pip_pos, 5.5, Color(pip_col.r, pip_col.g, pip_col.b, 0.15))

	# === 11. CHARACTER POSITIONS (tall proportions ~56px) ===
	var feet_y = body_offset + Vector2(hip_shift * 1.0, 14.0)
	var leg_top = body_offset + Vector2(hip_shift * 0.6, -2.0)
	var torso_center = body_offset + Vector2(shoulder_counter * 0.5, -10.0)
	var neck_base = body_offset + Vector2(shoulder_counter * 0.7, -20.0)
	var head_center = body_offset + Vector2(shoulder_counter * 0.3 + thinking_bob * 0.3, -32.0)

	# === 12. TIER-SPECIFIC EFFECTS (drawn BEFORE/AROUND body) ===

	# Tier 1+: Faint golden glow around magnifying glass area
	if upgrade_tier >= 1:
		for li in range(4 + upgrade_tier):
			var la = _time * (0.5 + fmod(float(li) * 1.37, 0.4)) + float(li) * TAU / float(4 + upgrade_tier)
			var lr = 18.0 + fmod(float(li) * 3.7, 12.0)
			var sparkle_pos = body_offset + Vector2(cos(la) * lr + 15.0, sin(la) * lr * 0.5 - 5.0)
			var sparkle_alpha = 0.15 + sin(_time * 2.0 + float(li)) * 0.08
			# Golden light mote
			draw_circle(sparkle_pos, 1.2, Color(1.0, 0.90, 0.45, sparkle_alpha))
			draw_circle(sparkle_pos, 0.6, Color(1.0, 0.95, 0.7, sparkle_alpha * 0.8))

	# Tier 2+: Visible beam line from lens when targeting
	if upgrade_tier >= 2 and target:
		var beam_alpha = 0.06 + sin(_time * 4.0) * 0.03
		var beam_end = (target.global_position - global_position).normalized() * 60.0
		draw_line(body_offset + Vector2(18, -8), beam_end, Color(1.0, 0.92, 0.5, beam_alpha), 1.5)
		draw_line(body_offset + Vector2(18, -8), beam_end, Color(1.0, 0.97, 0.8, beam_alpha * 0.5), 0.6)

	# Tier 3+: Dual mark indicators (floating deduction symbols)
	if upgrade_tier >= 3:
		for mi_vis in range(2):
			var ma_vis = _time * 0.8 + float(mi_vis) * PI
			var m_pos = body_offset + Vector2(cos(ma_vis) * 32.0, sin(ma_vis) * 12.0 - 5.0)
			var m_alpha = 0.15 + sin(_time * 2.5 + float(mi_vis) * 1.5) * 0.08
			# Magnifying glass icon
			draw_arc(m_pos, 3.5, 0, TAU, 8, Color(0.85, 0.72, 0.25, m_alpha), 0.8)
			draw_line(m_pos + Vector2(2.5, 2.5), m_pos + Vector2(5, 5), Color(0.85, 0.72, 0.25, m_alpha * 0.7), 0.6)

	# Tier 4: Full aura + floating evidence papers
	if upgrade_tier >= 4:
		# Evidence papers floating around
		for ep in range(6):
			var ep_seed = float(ep) * 2.37
			var ep_angle = _time * (0.4 + fmod(ep_seed, 0.3)) + ep_seed
			var ep_radius = 35.0 + fmod(ep_seed * 5.3, 20.0)
			var ep_pos = body_offset + Vector2(cos(ep_angle) * ep_radius, sin(ep_angle) * ep_radius * 0.6)
			var ep_alpha = 0.2 + sin(_time * 2.0 + ep_seed * 2.0) * 0.1
			var ep_rot = _time * 1.5 + ep_seed
			# Paper rectangle
			var p_dir = Vector2.from_angle(ep_rot)
			var p_perp = p_dir.rotated(PI / 2.0)
			var paper_pts = PackedVector2Array([
				ep_pos - p_dir * 3.0 - p_perp * 2.0,
				ep_pos + p_dir * 3.0 - p_perp * 2.0,
				ep_pos + p_dir * 3.0 + p_perp * 2.0,
				ep_pos - p_dir * 3.0 + p_perp * 2.0,
			])
			draw_colored_polygon(paper_pts, Color(0.95, 0.92, 0.85, ep_alpha))
			# Text lines on paper
			draw_line(ep_pos - p_dir * 2.0, ep_pos + p_dir * 1.5, Color(0.3, 0.3, 0.3, ep_alpha * 0.4), 0.4)
			draw_line(ep_pos - p_dir * 1.5 + p_perp * 0.8, ep_pos + p_dir * 1.0 + p_perp * 0.8, Color(0.3, 0.3, 0.3, ep_alpha * 0.3), 0.3)

	# === 13. CHARACTER BODY ===

	# --- Black polished shoes (Victorian gentleman) ---
	var l_foot = feet_y + Vector2(-7, 0)
	var r_foot = feet_y + Vector2(7, 0)
	# Shoe base
	draw_circle(l_foot, 5.5, Color(0.08, 0.06, 0.05))
	draw_circle(l_foot, 4.2, Color(0.14, 0.12, 0.10))
	draw_circle(r_foot, 5.5, Color(0.08, 0.06, 0.05))
	draw_circle(r_foot, 4.2, Color(0.14, 0.12, 0.10))
	# Shoe toe (pointed, elegant)
	draw_line(l_foot + Vector2(-3, 0), l_foot + Vector2(-7, -1), Color(0.12, 0.10, 0.08), 3.5)
	draw_circle(l_foot + Vector2(-7, -1), 2.2, Color(0.10, 0.08, 0.06))
	draw_line(r_foot + Vector2(3, 0), r_foot + Vector2(7, -1), Color(0.12, 0.10, 0.08), 3.5)
	draw_circle(r_foot + Vector2(7, -1), 2.2, Color(0.10, 0.08, 0.06))
	# Shoe shine highlight
	draw_arc(l_foot + Vector2(-4, -1), 2.0, PI * 1.2, PI * 1.8, 6, Color(0.4, 0.38, 0.35, 0.3), 1.0)
	draw_arc(r_foot + Vector2(4, -1), 2.0, PI * 1.2, PI * 1.8, 6, Color(0.4, 0.38, 0.35, 0.3), 1.0)
	# Shoe sole
	draw_arc(l_foot, 5.0, 0.3, PI - 0.3, 8, Color(0.04, 0.02, 0.02, 0.5), 1.5)
	draw_arc(r_foot, 5.0, 0.3, PI - 0.3, 8, Color(0.04, 0.02, 0.02, 0.5), 1.5)
	# Shoe shaft
	var l_shoe_shaft = PackedVector2Array([
		l_foot + Vector2(-4.5, -2), l_foot + Vector2(4.5, -2),
		l_foot + Vector2(4.0, -7), l_foot + Vector2(-4.0, -7),
	])
	draw_colored_polygon(l_shoe_shaft, Color(0.12, 0.10, 0.08))
	var r_shoe_shaft = PackedVector2Array([
		r_foot + Vector2(-4.5, -2), r_foot + Vector2(4.5, -2),
		r_foot + Vector2(4.0, -7), r_foot + Vector2(-4.0, -7),
	])
	draw_colored_polygon(r_shoe_shaft, Color(0.12, 0.10, 0.08))
	# Shoe top line
	draw_line(l_foot + Vector2(-4.5, -6), l_foot + Vector2(4.5, -6), Color(0.06, 0.04, 0.04), 2.0)
	draw_line(r_foot + Vector2(-4.5, -6), r_foot + Vector2(4.5, -6), Color(0.06, 0.04, 0.04), 2.0)

	# --- TROUSERS (dark grey Victorian) ---
	var l_hip = leg_top + Vector2(-6, 0)
	var r_hip = leg_top + Vector2(6, 0)
	var l_knee = l_foot.lerp(l_hip, 0.45) + Vector2(-1.5, 0)
	var r_knee = r_foot.lerp(r_hip, 0.45) + Vector2(1.5, 0)
	var trouser_dark = Color(0.18, 0.17, 0.16)
	var trouser_mid = Color(0.24, 0.23, 0.22)
	var trouser_light = Color(0.30, 0.29, 0.28)
	# LEFT THIGH
	var lt_dir = (l_knee - l_hip).normalized()
	var lt_perp = lt_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		l_hip + lt_perp * 5.0, l_hip - lt_perp * 4.0,
		l_hip.lerp(l_knee, 0.4) - lt_perp * 5.0,
		l_knee - lt_perp * 4.0, l_knee + lt_perp * 4.0,
		l_hip.lerp(l_knee, 0.4) + lt_perp * 5.5,
	]), trouser_dark)
	draw_colored_polygon(PackedVector2Array([
		l_hip + lt_perp * 3.0, l_hip - lt_perp * 2.0,
		l_knee - lt_perp * 2.5, l_knee + lt_perp * 2.5,
	]), trouser_mid)
	# Trouser crease (pressed)
	draw_line(l_hip, l_knee, Color(0.14, 0.13, 0.12, 0.3), 0.6)
	# RIGHT THIGH
	var rt_dir = (r_knee - r_hip).normalized()
	var rt_perp = rt_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		r_hip - rt_perp * 5.0, r_hip + rt_perp * 4.0,
		r_hip.lerp(r_knee, 0.4) + rt_perp * 5.0,
		r_knee + rt_perp * 4.0, r_knee - rt_perp * 4.0,
		r_hip.lerp(r_knee, 0.4) - rt_perp * 5.5,
	]), trouser_dark)
	draw_colored_polygon(PackedVector2Array([
		r_hip - rt_perp * 3.0, r_hip + rt_perp * 2.0,
		r_knee + rt_perp * 2.5, r_knee - rt_perp * 2.5,
	]), trouser_mid)
	draw_line(r_hip, r_knee, Color(0.14, 0.13, 0.12, 0.3), 0.6)
	# Knee joints
	draw_circle(l_knee, 4.5, trouser_dark)
	draw_circle(l_knee, 3.5, trouser_mid)
	draw_circle(r_knee, 4.5, trouser_dark)
	draw_circle(r_knee, 3.5, trouser_mid)
	# LEFT CALF
	var l_calf_mid = l_knee.lerp(l_foot + Vector2(0, -3), 0.4) + Vector2(-1.5, 0)
	draw_colored_polygon(PackedVector2Array([
		l_knee + lt_perp * 4.0, l_knee - lt_perp * 3.5,
		l_calf_mid - lt_perp * 4.5, l_calf_mid + lt_perp * 4.0,
	]), trouser_dark)
	draw_colored_polygon(PackedVector2Array([
		l_calf_mid + lt_perp * 4.0, l_calf_mid - lt_perp * 4.5,
		l_foot + Vector2(-3, -3), l_foot + Vector2(3, -3),
	]), trouser_dark)
	# RIGHT CALF
	var r_calf_mid = r_knee.lerp(r_foot + Vector2(0, -3), 0.4) + Vector2(1.5, 0)
	draw_colored_polygon(PackedVector2Array([
		r_knee - rt_perp * 4.0, r_knee + rt_perp * 3.5,
		r_calf_mid + rt_perp * 4.5, r_calf_mid - rt_perp * 4.0,
	]), trouser_dark)
	draw_colored_polygon(PackedVector2Array([
		r_calf_mid - rt_perp * 4.0, r_calf_mid + rt_perp * 4.5,
		r_foot + Vector2(3, -3), r_foot + Vector2(-3, -3),
	]), trouser_dark)

	# --- VICTORIAN SUIT JACKET (dark charcoal) ---
	var jacket_dark = Color(0.16, 0.15, 0.14)
	var jacket_mid = Color(0.22, 0.21, 0.20)
	var jacket_light = Color(0.28, 0.27, 0.26)
	# Main torso jacket shape (slightly narrower waist, broad shoulders)
	var jacket_pts = PackedVector2Array([
		leg_top + Vector2(-9, 0),         # waist left
		leg_top + Vector2(-10, -3),       # taper
		torso_center + Vector2(-14, 0),   # mid torso
		neck_base + Vector2(-16, 0),      # shoulder left
		neck_base + Vector2(16, 0),       # shoulder right
		torso_center + Vector2(14, 0),    # mid torso
		leg_top + Vector2(10, -3),        # taper
		leg_top + Vector2(9, 0),          # waist right
	])
	draw_colored_polygon(jacket_pts, jacket_dark)

	# --- BURGUNDY WAISTCOAT (visible under jacket) ---
	var vest_pts = PackedVector2Array([
		leg_top + Vector2(-6, -1),
		torso_center + Vector2(-8, 0),
		neck_base + Vector2(-7, 2),
		neck_base + Vector2(7, 2),
		torso_center + Vector2(8, 0),
		leg_top + Vector2(6, -1),
	])
	draw_colored_polygon(vest_pts, Color(0.45, 0.12, 0.15))
	# Waistcoat highlight
	draw_colored_polygon(PackedVector2Array([
		leg_top + Vector2(-4, -1),
		torso_center + Vector2(-5, 0),
		torso_center + Vector2(5, 0),
		leg_top + Vector2(4, -1),
	]), Color(0.55, 0.18, 0.20, 0.35))
	# Waistcoat buttons (4 brass)
	for bi in range(4):
		var bt = float(bi + 1) / 5.0
		var btn_pos = leg_top.lerp(neck_base, bt) + Vector2(0, 1)
		draw_circle(btn_pos, 1.2, Color(0.75, 0.60, 0.20))
		draw_circle(btn_pos, 0.7, Color(0.88, 0.75, 0.35, 0.5))
	# Waistcoat pocket (watch chain)
	var pocket_y = torso_center + Vector2(-5, 2)
	draw_line(pocket_y, pocket_y + Vector2(4, 0), Color(0.38, 0.08, 0.10), 1.5)
	# Gold watch chain (catenary curve)
	var chain_start = pocket_y + Vector2(0, 0)
	var chain_mid = pocket_y + Vector2(2, 3)
	var chain_end = torso_center + Vector2(0, 4)
	draw_line(chain_start, chain_mid, Color(0.80, 0.68, 0.25, 0.5), 0.8)
	draw_line(chain_mid, chain_end, Color(0.80, 0.68, 0.25, 0.5), 0.8)
	# Watch fob
	draw_circle(chain_mid, 1.0, Color(0.85, 0.72, 0.28))

	# --- WHITE SHIRT (visible at collar and below waistcoat) ---
	# Shirt collar V
	draw_colored_polygon(PackedVector2Array([
		neck_base + Vector2(-5, 1),
		neck_base + Vector2(5, 1),
		neck_base + Vector2(0, 6),
	]), Color(0.92, 0.90, 0.88))
	# Collar points (starched white)
	draw_line(neck_base + Vector2(-5, 1), neck_base + Vector2(-7, -1), Color(0.92, 0.90, 0.88), 2.0)
	draw_line(neck_base + Vector2(5, 1), neck_base + Vector2(7, -1), Color(0.92, 0.90, 0.88), 2.0)

	# Jacket lapels (darker overlay on sides)
	var l_lapel = PackedVector2Array([
		neck_base + Vector2(-16, 0),
		neck_base + Vector2(-7, 2),
		torso_center + Vector2(-7, -2),
		torso_center + Vector2(-14, -1),
	])
	draw_colored_polygon(l_lapel, jacket_mid)
	draw_line(neck_base + Vector2(-7, 2), torso_center + Vector2(-7, -2), Color(0.10, 0.09, 0.08, 0.5), 0.8)
	var r_lapel = PackedVector2Array([
		neck_base + Vector2(16, 0),
		neck_base + Vector2(7, 2),
		torso_center + Vector2(7, -2),
		torso_center + Vector2(14, -1),
	])
	draw_colored_polygon(r_lapel, jacket_mid)
	draw_line(neck_base + Vector2(7, 2), torso_center + Vector2(7, -2), Color(0.10, 0.09, 0.08, 0.5), 0.8)
	# Jacket fold shadows
	draw_line(neck_base + Vector2(-14, 2), leg_top + Vector2(-8, -1), Color(0.10, 0.09, 0.08, 0.35), 1.0)
	draw_line(neck_base + Vector2(14, 2), leg_top + Vector2(8, -1), Color(0.10, 0.09, 0.08, 0.35), 1.0)
	# Center front seam
	draw_line(neck_base + Vector2(0, 3), leg_top + Vector2(0, -1), Color(0.10, 0.09, 0.08, 0.25), 0.6)
	# Jacket hem (sharp, tailored)
	draw_line(leg_top + Vector2(-10, 0), leg_top + Vector2(10, 0), Color(0.12, 0.11, 0.10, 0.5), 1.2)
	# Jacket pocket flaps
	draw_line(torso_center + Vector2(-11, 2), torso_center + Vector2(-5, 2), Color(0.14, 0.13, 0.12), 1.5)
	draw_line(torso_center + Vector2(5, 2), torso_center + Vector2(11, 2), Color(0.14, 0.13, 0.12), 1.5)

	# Shoulder pads (structured Victorian jacket)
	var l_shoulder = neck_base + Vector2(-15, 0)
	var r_shoulder = neck_base + Vector2(15, 0)
	draw_circle(l_shoulder, 6.0, jacket_dark)
	draw_circle(l_shoulder, 4.5, jacket_mid)
	draw_circle(r_shoulder, 6.0, jacket_dark)
	draw_circle(r_shoulder, 4.5, jacket_mid)
	# Shoulder seam
	draw_arc(l_shoulder, 5.5, 0, TAU, 10, Color(0.10, 0.09, 0.08, 0.3), 0.6)
	draw_arc(r_shoulder, 5.5, 0, TAU, 10, Color(0.10, 0.09, 0.08, 0.3), 0.6)

	# --- LEFT ARM: Holds magnifying glass at slight angle ---
	var glass_angle = aim_angle + 0.3
	var glass_dir = Vector2.from_angle(glass_angle)
	var l_hand = l_shoulder + Vector2(0, 2) + glass_dir * 22.0
	var l_elbow = l_shoulder + (l_hand - l_shoulder) * 0.4 + Vector2(-3, 4)
	# Upper arm
	var la_dir = (l_elbow - l_shoulder).normalized()
	var la_perp = la_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		l_shoulder + la_perp * 5.0, l_shoulder - la_perp * 4.0,
		l_elbow - la_perp * 3.5, l_elbow + la_perp * 3.5,
	]), jacket_dark)
	draw_colored_polygon(PackedVector2Array([
		l_shoulder + la_perp * 3.0, l_shoulder - la_perp * 2.0,
		l_elbow - la_perp * 2.0, l_elbow + la_perp * 2.0,
	]), jacket_mid)
	# Elbow
	draw_circle(l_elbow, 3.5, jacket_dark)
	draw_circle(l_elbow, 2.5, jacket_mid)
	# Forearm (jacket sleeve)
	var lf_dir = (l_hand - l_elbow).normalized()
	var lf_perp = lf_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		l_elbow + lf_perp * 3.5, l_elbow - lf_perp * 3.0,
		l_hand - lf_perp * 2.5, l_hand + lf_perp * 2.5,
	]), jacket_dark)
	draw_colored_polygon(PackedVector2Array([
		l_elbow + lf_perp * 2.0, l_elbow - lf_perp * 1.5,
		l_hand - lf_perp * 1.5, l_hand + lf_perp * 1.5,
	]), jacket_mid)
	# Shirt cuff showing
	var cuff_pos = l_elbow.lerp(l_hand, 0.85)
	draw_line(cuff_pos - lf_perp * 3.0, cuff_pos + lf_perp * 3.0, Color(0.90, 0.88, 0.86), 2.0)
	# Hand
	draw_circle(l_hand, 3.5, skin_shadow)
	draw_circle(l_hand, 2.8, skin_base)
	# Fingers gripping magnifying glass handle
	for fi in range(3):
		var fa = float(fi - 1) * 0.3
		draw_circle(l_hand + glass_dir.rotated(fa) * 3.0, 1.2, skin_highlight)

	# === MAGNIFYING GLASS ===
	var glass_handle_start = l_hand + glass_dir * 2.0
	var glass_handle_end = l_hand + glass_dir * 14.0
	var glass_center = l_hand + glass_dir * 22.0

	# Handle (dark wood with brass fittings)
	draw_line(glass_handle_start, glass_handle_end, Color(0.30, 0.18, 0.08), 4.5)
	draw_line(glass_handle_start, glass_handle_end, Color(0.42, 0.28, 0.12), 3.0)
	draw_line(glass_handle_start, glass_handle_end, Color(0.50, 0.34, 0.16, 0.3), 1.5)
	# Handle grip ridges
	for gi in range(4):
		var gt = 0.15 + float(gi) * 0.2
		var g_pos = glass_handle_start.lerp(glass_handle_end, gt)
		var g_perp_dir = glass_dir.rotated(PI / 2.0)
		draw_line(g_pos - g_perp_dir * 2.0, g_pos + g_perp_dir * 2.0, Color(0.25, 0.14, 0.06, 0.4), 0.8)
	# Brass ferrule (where handle meets frame)
	var ferrule = glass_handle_end
	draw_circle(ferrule, 3.0, Color(0.75, 0.60, 0.20))
	draw_circle(ferrule, 2.2, Color(0.85, 0.72, 0.30, 0.5))

	# Lens frame (golden brass ring)
	var frame_radius = 9.0
	# Frame shadow
	draw_arc(glass_center + Vector2(0.5, 0.5), frame_radius + 1.5, 0, TAU, 24, Color(0, 0, 0, 0.1), 3.0)
	# Outer frame
	draw_arc(glass_center, frame_radius + 1.0, 0, TAU, 24, Color(0.60, 0.48, 0.15), 3.5)
	# Mid frame
	draw_arc(glass_center, frame_radius, 0, TAU, 24, Color(0.78, 0.62, 0.22), 2.5)
	# Inner frame highlight
	draw_arc(glass_center, frame_radius - 0.5, PI * 1.1, PI * 1.8, 12, Color(0.92, 0.80, 0.38, 0.5), 1.5)
	# Decorative engraving on frame
	for ei in range(8):
		var ea = TAU * float(ei) / 8.0
		var e_pos = glass_center + Vector2.from_angle(ea) * (frame_radius + 0.5)
		draw_circle(e_pos, 0.6, Color(0.85, 0.72, 0.28, 0.3))

	# Lens glass (with light refraction effect)
	# Base glass — very slight tint
	draw_circle(glass_center, frame_radius - 1.5, Color(0.85, 0.92, 0.98, 0.15))
	# Light refraction — bright spot
	var refract_offset = Vector2(sin(_time * 0.8) * 2.0, cos(_time * 0.6) * 1.5)
	draw_circle(glass_center + refract_offset, 4.0, Color(1.0, 0.98, 0.90, 0.12))
	draw_circle(glass_center + refract_offset * 0.5, 2.5, Color(1.0, 1.0, 0.95, 0.18))
	# Lens highlight (crescent reflection)
	draw_arc(glass_center + Vector2(-2, -2), 5.0, PI * 1.1, PI * 1.7, 8, Color(1.0, 1.0, 1.0, 0.35), 1.5)
	# Secondary highlight
	draw_circle(glass_center + Vector2(3, 3), 1.5, Color(1.0, 1.0, 1.0, 0.2))

	# Tier 1+: Faint glow around glass
	if upgrade_tier >= 1:
		var glow_pulse = (sin(_time * 3.0) + 1.0) * 0.5
		draw_circle(glass_center, frame_radius + 3.0, Color(1.0, 0.92, 0.5, 0.06 + glow_pulse * 0.04))
		draw_circle(glass_center, frame_radius + 6.0, Color(1.0, 0.88, 0.4, 0.03 + glow_pulse * 0.02))

	# Tier 2+: Active beam from lens toward target
	if upgrade_tier >= 2 and target and _attack_anim > 0.0:
		var beam_dir = (target.global_position - global_position).normalized()
		var beam_len = 35.0 * _attack_anim
		draw_line(glass_center, glass_center + beam_dir * beam_len, Color(1.0, 0.95, 0.6, 0.2 * _attack_anim), 3.0)
		draw_line(glass_center, glass_center + beam_dir * beam_len, Color(1.0, 0.98, 0.8, 0.3 * _attack_anim), 1.5)

	# --- RIGHT ARM: Holds pipe or rests at side ---
	var r_hand = r_shoulder + Vector2(6, 18)
	var r_elbow = r_shoulder + (r_hand - r_shoulder) * 0.4 + Vector2(4, 2)
	# Upper arm
	var ra_dir = (r_elbow - r_shoulder).normalized()
	var ra_perp = ra_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		r_shoulder - ra_perp * 5.0, r_shoulder + ra_perp * 4.0,
		r_elbow + ra_perp * 3.5, r_elbow - ra_perp * 3.5,
	]), jacket_dark)
	draw_colored_polygon(PackedVector2Array([
		r_shoulder - ra_perp * 3.0, r_shoulder + ra_perp * 2.0,
		r_elbow + ra_perp * 2.0, r_elbow - ra_perp * 2.0,
	]), jacket_mid)
	# Elbow
	draw_circle(r_elbow, 3.5, jacket_dark)
	draw_circle(r_elbow, 2.5, jacket_mid)
	# Forearm
	var rf_dir = (r_hand - r_elbow).normalized()
	var rf_perp = rf_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		r_elbow - rf_perp * 3.5, r_elbow + rf_perp * 3.0,
		r_hand + rf_perp * 2.5, r_hand - rf_perp * 2.5,
	]), jacket_dark)
	draw_colored_polygon(PackedVector2Array([
		r_elbow - rf_perp * 2.0, r_elbow + rf_perp * 1.5,
		r_hand + rf_perp * 1.5, r_hand - rf_perp * 1.5,
	]), jacket_mid)
	# Shirt cuff
	var r_cuff = r_elbow.lerp(r_hand, 0.85)
	draw_line(r_cuff - rf_perp * 3.0, r_cuff + rf_perp * 3.0, Color(0.90, 0.88, 0.86), 2.0)
	# Right hand
	draw_circle(r_hand, 3.5, skin_shadow)
	draw_circle(r_hand, 2.8, skin_base)

	# Pipe in right hand
	var pipe_bowl = r_hand + Vector2(2, -4)
	var pipe_stem_end = r_hand + Vector2(-3, 2)
	# Pipe stem (dark briar wood)
	draw_line(r_hand + Vector2(0, -1), pipe_bowl, Color(0.25, 0.14, 0.06), 2.5)
	draw_line(r_hand + Vector2(0, -1), pipe_bowl, Color(0.35, 0.20, 0.10), 1.5)
	# Pipe bowl
	draw_circle(pipe_bowl, 3.5, Color(0.28, 0.16, 0.06))
	draw_circle(pipe_bowl, 2.5, Color(0.38, 0.22, 0.10))
	# Bowl rim
	draw_arc(pipe_bowl, 3.0, 0, TAU, 10, Color(0.42, 0.28, 0.14, 0.5), 1.0)
	# Bowl opening (dark inside)
	draw_circle(pipe_bowl + Vector2(0, -1), 1.8, Color(0.08, 0.04, 0.02))
	# Smoke wisps
	var smoke_base = pipe_bowl + Vector2(0, -4)
	for si in range(3):
		var sx = sin(_time * 1.5 + float(si) * 2.0) * 3.0
		var sy = -float(si) * 4.0 - _time * 2.0
		var s_alpha = 0.15 - float(si) * 0.04
		if s_alpha > 0:
			var smoke_pos = smoke_base + Vector2(sx, fmod(sy, -15.0))
			draw_circle(smoke_pos, 2.0 + float(si) * 0.5, Color(0.7, 0.7, 0.72, s_alpha))

	# === HEAD ===
	# Neck
	var neck_top = head_center + Vector2(0, 9)
	var neck_dir_v = (neck_top - neck_base).normalized()
	var neck_perp = neck_dir_v.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		neck_base + neck_perp * 5.5, neck_base - neck_perp * 5.5,
		neck_base.lerp(neck_top, 0.5) - neck_perp * 4.5,
		neck_top - neck_perp * 4.0, neck_top + neck_perp * 4.0,
		neck_base.lerp(neck_top, 0.5) + neck_perp * 4.5,
	]), skin_shadow)
	draw_colored_polygon(PackedVector2Array([
		neck_base + neck_perp * 4.5, neck_base - neck_perp * 4.5,
		neck_top - neck_perp * 3.0, neck_top + neck_perp * 3.0,
	]), skin_base)
	# Shirt collar around neck
	draw_line(neck_base + Vector2(-6, 0), neck_base + Vector2(-4, -3), Color(0.92, 0.90, 0.88), 2.5)
	draw_line(neck_base + Vector2(6, 0), neck_base + Vector2(4, -3), Color(0.92, 0.90, 0.88), 2.5)

	# Dark curly hair (back layer)
	var hair_base_col = Color(0.12, 0.10, 0.08)
	var hair_mid_col = Color(0.18, 0.15, 0.12)
	var hair_hi_col = Color(0.25, 0.22, 0.18)
	# Hair mass
	draw_circle(head_center, 11.0, hair_base_col)
	draw_circle(head_center + Vector2(0, -0.8), 9.8, hair_mid_col)
	# Volume highlight
	draw_circle(head_center + Vector2(-1.5, -2.5), 5.0, Color(0.22, 0.18, 0.14, 0.3))

	# Curly tufts (dark, slightly unruly but refined)
	var hair_sway = sin(_time * 2.0) * 1.5
	var tuft_data = [
		[0.3, 4.8, 1.8], [0.9, 5.2, 1.6], [1.5, 4.5, 1.9], [2.1, 5.5, 1.5],
		[2.8, 4.8, 1.7], [3.5, 5.0, 1.6], [4.2, 4.6, 1.8], [4.9, 5.2, 1.5],
		[5.6, 4.8, 1.7], [0.6, 4.5, 1.5],
	]
	for h in range(tuft_data.size()):
		var ha: float = tuft_data[h][0]
		var tlen: float = tuft_data[h][1]
		var twid: float = tuft_data[h][2]
		var tuft_base_pos = head_center + Vector2.from_angle(ha) * 9.5
		var sway_d = 1.0 if h % 2 == 0 else -1.0
		# Curly wave modulation
		var curl_wave = sin(ha * 4.0 + _time * 1.2) * 1.5
		var tuft_tip_pos = tuft_base_pos + Vector2.from_angle(ha) * tlen + Vector2(hair_sway * sway_d * 0.3 + curl_wave, curl_wave * 0.4)
		var tcol = hair_mid_col if h % 3 == 0 else hair_hi_col if h % 3 == 1 else hair_base_col
		draw_line(tuft_base_pos, tuft_tip_pos, tcol, twid)
		# Secondary curly strand
		var ha2 = ha + (0.15 if h % 2 == 0 else -0.15)
		var t2_base = head_center + Vector2.from_angle(ha2) * 8.5
		var curl2 = sin(ha2 * 5.0 + _time * 1.0) * 1.0
		var t2_tip = t2_base + Vector2.from_angle(ha2) * (tlen * 0.55) + Vector2(curl2, curl2 * 0.3)
		draw_line(t2_base, t2_tip, hair_base_col, twid * 0.5)

	# Face (angular, sharp features)
	draw_circle(head_center + Vector2(0, 0.8), 9.0, skin_base)
	# Angular jawline (sharp, lean)
	draw_line(head_center + Vector2(-8.5, 0.5), head_center + Vector2(-4, 7.5), Color(0.62, 0.48, 0.38, 0.35), 1.2)
	draw_line(head_center + Vector2(8.5, 0.5), head_center + Vector2(4, 7.5), Color(0.62, 0.48, 0.38, 0.35), 1.2)
	# Sharp chin
	draw_line(head_center + Vector2(-4, 7.5), head_center + Vector2(4, 7.5), Color(0.62, 0.48, 0.38, 0.2), 1.0)
	draw_circle(head_center + Vector2(0, 7.5), 2.5, skin_base)
	draw_circle(head_center + Vector2(0, 7.8), 1.8, skin_highlight)
	# Under-cheekbone shadow (gaunt, intellectual)
	draw_arc(head_center + Vector2(-5.5, 1.5), 4.0, PI * 0.1, PI * 0.55, 8, Color(0.60, 0.44, 0.34, 0.25), 1.2)
	draw_arc(head_center + Vector2(5.5, 1.5), 4.0, PI * 0.45, PI * 0.9, 8, Color(0.60, 0.44, 0.34, 0.25), 1.2)
	# High cheekbones
	draw_arc(head_center + Vector2(-5.0, 0.3), 3.5, PI * 1.15, PI * 1.6, 8, Color(0.95, 0.84, 0.72, 0.2), 0.8)
	draw_arc(head_center + Vector2(5.0, 0.3), 3.5, PI * 1.4, PI * 1.85, 8, Color(0.95, 0.84, 0.72, 0.2), 0.8)

	# Ears
	var r_ear = head_center + Vector2(8.7, -0.5)
	draw_circle(r_ear, 2.3, skin_base)
	draw_circle(r_ear + Vector2(0.3, 0), 1.5, Color(0.88, 0.72, 0.60, 0.5))
	draw_arc(r_ear, 1.8, -0.5, 1.0, 6, skin_shadow, 0.7)
	var l_ear = head_center + Vector2(-8.7, -0.5)
	draw_circle(l_ear, 2.3, skin_base)
	draw_circle(l_ear + Vector2(-0.3, 0), 1.5, Color(0.88, 0.72, 0.60, 0.5))
	draw_arc(l_ear, 1.8, PI - 0.5, PI + 1.0, 6, skin_shadow, 0.7)

	# Deep-set eyes that track aim direction
	var look_dir = dir * 1.3
	var l_eye = head_center + Vector2(-3.8, -1.0)
	var r_eye_pos = head_center + Vector2(3.8, -1.0)
	# Deep eye socket shadow (deep-set, intense)
	draw_circle(l_eye, 4.5, Color(0.60, 0.48, 0.40, 0.35))
	draw_circle(r_eye_pos, 4.5, Color(0.60, 0.48, 0.40, 0.35))
	# Eye whites
	draw_circle(l_eye, 3.8, Color(0.95, 0.95, 0.97))
	draw_circle(r_eye_pos, 3.8, Color(0.95, 0.95, 0.97))
	# Steel grey irises (following aim)
	draw_circle(l_eye + look_dir, 2.5, Color(0.35, 0.40, 0.45))
	draw_circle(l_eye + look_dir, 2.0, Color(0.45, 0.50, 0.55))
	draw_circle(l_eye + look_dir, 1.3, Color(0.55, 0.60, 0.65))
	draw_circle(r_eye_pos + look_dir, 2.5, Color(0.35, 0.40, 0.45))
	draw_circle(r_eye_pos + look_dir, 2.0, Color(0.45, 0.50, 0.55))
	draw_circle(r_eye_pos + look_dir, 1.3, Color(0.55, 0.60, 0.65))
	# Limbal ring (dark)
	draw_arc(l_eye + look_dir, 2.4, 0, TAU, 10, Color(0.25, 0.28, 0.32, 0.3), 0.5)
	draw_arc(r_eye_pos + look_dir, 2.4, 0, TAU, 10, Color(0.25, 0.28, 0.32, 0.3), 0.5)
	# Iris radial detail
	for iri in range(8):
		var ir_a = TAU * float(iri) / 8.0
		var ir_v = Vector2.from_angle(ir_a)
		draw_line(l_eye + look_dir + ir_v * 0.5, l_eye + look_dir + ir_v * 1.4, Color(0.40, 0.45, 0.50, 0.2), 0.4)
		draw_line(r_eye_pos + look_dir + ir_v * 0.5, r_eye_pos + look_dir + ir_v * 1.4, Color(0.40, 0.45, 0.50, 0.2), 0.4)
	# Pupils (sharp, focused)
	draw_circle(l_eye + look_dir * 1.15, 1.2, Color(0.04, 0.04, 0.06))
	draw_circle(r_eye_pos + look_dir * 1.15, 1.2, Color(0.04, 0.04, 0.06))
	# Primary highlight
	draw_circle(l_eye + Vector2(-0.8, -1.2), 1.2, Color(1.0, 1.0, 1.0, 0.9))
	draw_circle(r_eye_pos + Vector2(-0.8, -1.2), 1.2, Color(1.0, 1.0, 1.0, 0.9))
	# Secondary highlight
	draw_circle(l_eye + Vector2(1.0, 0.5), 0.6, Color(1.0, 1.0, 1.0, 0.5))
	draw_circle(r_eye_pos + Vector2(1.0, 0.5), 0.6, Color(1.0, 1.0, 1.0, 0.5))
	# Analytical glint (keen intelligence)
	var glint_t = sin(_time * 2.5) * 0.2
	draw_circle(l_eye + Vector2(0.3, -0.5), 0.4, Color(0.7, 0.85, 1.0, 0.2 + glint_t))
	draw_circle(r_eye_pos + Vector2(0.3, -0.5), 0.4, Color(0.7, 0.85, 1.0, 0.2 + glint_t))
	# Upper eyelids (heavy, intense — slightly hooded)
	draw_arc(l_eye, 3.8, PI + 0.2, TAU - 0.2, 8, Color(0.12, 0.10, 0.08), 1.5)
	draw_arc(r_eye_pos, 3.8, PI + 0.2, TAU - 0.2, 8, Color(0.12, 0.10, 0.08), 1.5)
	# Lower eyelid line (subtle bags from late nights)
	draw_arc(l_eye, 3.5, 0.25, PI - 0.25, 8, Color(0.55, 0.42, 0.35, 0.3), 0.6)
	draw_arc(r_eye_pos, 3.5, 0.25, PI - 0.25, 8, Color(0.55, 0.42, 0.35, 0.3), 0.6)

	# Eyebrows — sharp, analytical arches
	draw_line(l_eye + Vector2(-3.0, -4.5), l_eye + Vector2(0, -5.2), Color(0.14, 0.12, 0.10), 1.8)
	draw_line(l_eye + Vector2(0, -5.2), l_eye + Vector2(3.0, -4.2), Color(0.14, 0.12, 0.10), 1.2)
	draw_line(r_eye_pos + Vector2(-3.0, -4.2), r_eye_pos + Vector2(0, -5.2), Color(0.14, 0.12, 0.10), 1.8)
	draw_line(r_eye_pos + Vector2(0, -5.2), r_eye_pos + Vector2(3.0, -4.5), Color(0.14, 0.12, 0.10), 1.2)

	# Sharp nose (aquiline, prominent)
	# Nose bridge (long, prominent)
	draw_line(head_center + Vector2(0, -1.0), head_center + Vector2(0.3, 3.2), Color(0.92, 0.78, 0.65, 0.35), 1.0)
	# Nose tip (sharp, slightly hooked)
	draw_circle(head_center + Vector2(0.3, 3.2), 1.8, skin_highlight)
	draw_circle(head_center + Vector2(0.5, 3.4), 1.3, Color(0.92, 0.80, 0.68))
	# Nose hook (aquiline profile hint)
	draw_arc(head_center + Vector2(0.3, 2.5), 2.0, PI * 1.3, PI * 1.8, 6, Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.2), 0.7)
	# Nostrils
	draw_circle(head_center + Vector2(-0.8, 3.5), 0.5, Color(0.52, 0.38, 0.30, 0.4))
	draw_circle(head_center + Vector2(1.0, 3.5), 0.5, Color(0.52, 0.38, 0.30, 0.4))
	# Nose shadow
	draw_line(head_center + Vector2(-0.8, 0.8), head_center + Vector2(-0.8, 3.0), Color(0.60, 0.44, 0.34, 0.25), 0.6)

	# Thin, pursed mouth (thoughtful expression)
	draw_arc(head_center + Vector2(0, 5.3), 3.5, 0.2, PI - 0.2, 10, Color(0.58, 0.32, 0.25), 1.3)
	# Upper lip defined
	draw_line(head_center + Vector2(-3.0, 5.0), head_center + Vector2(0, 4.6), Color(0.55, 0.30, 0.22, 0.4), 0.8)
	draw_line(head_center + Vector2(0, 4.6), head_center + Vector2(3.0, 5.0), Color(0.55, 0.30, 0.22, 0.4), 0.8)
	# Lower lip
	draw_arc(head_center + Vector2(0, 5.6), 2.5, 0.3, PI - 0.3, 8, Color(0.65, 0.40, 0.32, 0.15), 0.7)
	# Slight frown lines (concentration)
	draw_arc(head_center + Vector2(-3.5, 3.5), 2.5, PI * 0.4, PI * 0.7, 4, Color(0.60, 0.44, 0.34, 0.1), 0.5)
	draw_arc(head_center + Vector2(3.5, 3.5), 2.5, PI * 0.3, PI * 0.6, 4, Color(0.60, 0.44, 0.34, 0.1), 0.5)

	# === DEERSTALKER HAT (iconic twin-peaked cap) ===
	var hat_base_y = head_center + Vector2(0, -7)

	# Main crown of hat (rounded, slightly puffy)
	var hat_crown_pts = PackedVector2Array([
		hat_base_y + Vector2(-10, 2),
		hat_base_y + Vector2(-11, -2),
		hat_base_y + Vector2(-8, -7),
		hat_base_y + Vector2(-3, -9),
		hat_base_y + Vector2(3, -9),
		hat_base_y + Vector2(8, -7),
		hat_base_y + Vector2(11, -2),
		hat_base_y + Vector2(10, 2),
	])
	# Hat base color (brown/tan herringbone tweed)
	draw_colored_polygon(hat_crown_pts, Color(0.45, 0.35, 0.22))
	# Tweed highlight
	draw_colored_polygon(PackedVector2Array([
		hat_base_y + Vector2(-8, -1),
		hat_base_y + Vector2(-6, -6),
		hat_base_y + Vector2(6, -6),
		hat_base_y + Vector2(8, -1),
	]), Color(0.52, 0.42, 0.28, 0.4))
	# Herringbone tweed texture (small V-pattern lines)
	for hi in range(6):
		var hx = -6.0 + float(hi) * 2.4
		var hy = -5.0 + sin(float(hi) * 1.5) * 1.0
		var h_pos = hat_base_y + Vector2(hx, hy)
		draw_line(h_pos, h_pos + Vector2(-0.8, -1.2), Color(0.38, 0.28, 0.18, 0.3), 0.5)
		draw_line(h_pos, h_pos + Vector2(0.8, -1.2), Color(0.38, 0.28, 0.18, 0.3), 0.5)
	for hi2 in range(5):
		var hx2 = -5.0 + float(hi2) * 2.5
		var h_pos2 = hat_base_y + Vector2(hx2, -2.5)
		draw_line(h_pos2, h_pos2 + Vector2(-0.6, -1.0), Color(0.40, 0.30, 0.20, 0.2), 0.4)
		draw_line(h_pos2, h_pos2 + Vector2(0.6, -1.0), Color(0.40, 0.30, 0.20, 0.2), 0.4)

	# Front peak/brim (extending forward)
	var front_brim = PackedVector2Array([
		hat_base_y + Vector2(-10, 2),
		hat_base_y + Vector2(10, 2),
		hat_base_y + Vector2(8, 5),
		hat_base_y + Vector2(-8, 5),
	])
	draw_colored_polygon(front_brim, Color(0.40, 0.30, 0.18))
	# Brim shadow
	draw_line(hat_base_y + Vector2(-9, 3), hat_base_y + Vector2(9, 3), Color(0.32, 0.22, 0.12), 2.0)
	# Brim edge highlight
	draw_line(hat_base_y + Vector2(-8, 5), hat_base_y + Vector2(8, 5), Color(0.50, 0.40, 0.28, 0.4), 1.0)

	# Rear peak/brim (extending backward — visible from side)
	var rear_brim = PackedVector2Array([
		hat_base_y + Vector2(-10, 2),
		hat_base_y + Vector2(-8, 5),
		hat_base_y + Vector2(-12, 4),
	])
	draw_colored_polygon(rear_brim, Color(0.38, 0.28, 0.16))

	# Ear flaps (tied up on top — iconic deerstalker look)
	# Left ear flap (folded up)
	var l_flap = PackedVector2Array([
		hat_base_y + Vector2(-11, 0),
		hat_base_y + Vector2(-10, 2),
		hat_base_y + Vector2(-8, 3),
		hat_base_y + Vector2(-7, -2),
		hat_base_y + Vector2(-9, -3),
	])
	draw_colored_polygon(l_flap, Color(0.42, 0.32, 0.20))
	draw_line(hat_base_y + Vector2(-10, 0), hat_base_y + Vector2(-8, -1), Color(0.48, 0.38, 0.26, 0.5), 0.8)
	# Right ear flap (folded up)
	var r_flap = PackedVector2Array([
		hat_base_y + Vector2(11, 0),
		hat_base_y + Vector2(10, 2),
		hat_base_y + Vector2(8, 3),
		hat_base_y + Vector2(7, -2),
		hat_base_y + Vector2(9, -3),
	])
	draw_colored_polygon(r_flap, Color(0.42, 0.32, 0.20))
	draw_line(hat_base_y + Vector2(10, 0), hat_base_y + Vector2(8, -1), Color(0.48, 0.38, 0.26, 0.5), 0.8)

	# Tied-up ribbon/button at crown (holding ear flaps)
	draw_circle(hat_base_y + Vector2(0, -8), 2.0, Color(0.35, 0.25, 0.15))
	draw_circle(hat_base_y + Vector2(0, -8), 1.2, Color(0.45, 0.35, 0.22))
	# Button holes
	draw_circle(hat_base_y + Vector2(-0.4, -8.2), 0.3, Color(0.25, 0.16, 0.08, 0.5))
	draw_circle(hat_base_y + Vector2(0.4, -7.8), 0.3, Color(0.25, 0.16, 0.08, 0.5))

	# Hat band (dark ribbon around base of crown)
	draw_line(hat_base_y + Vector2(-10.5, 1), hat_base_y + Vector2(10.5, 1), Color(0.15, 0.12, 0.08), 2.5)
	draw_line(hat_base_y + Vector2(-10, 0.5), hat_base_y + Vector2(10, 0.5), Color(0.22, 0.18, 0.12, 0.5), 1.2)

	# Crown center seam
	draw_line(hat_base_y + Vector2(0, -9), hat_base_y + Vector2(0, 1), Color(0.38, 0.28, 0.18, 0.3), 0.6)

	# Tier 4: Hat glow
	if upgrade_tier >= 4:
		draw_circle(hat_base_y + Vector2(0, -4), 14.0, Color(1.0, 0.90, 0.45, 0.04 + sin(_time * 2.0) * 0.02))

	# === Tier 4: Golden-amber aura around whole character ===
	if upgrade_tier >= 4:
		var aura_pulse = sin(_time * 2.5) * 5.0
		draw_circle(body_offset, 60.0 + aura_pulse, Color(0.85, 0.72, 0.25, 0.04))
		draw_circle(body_offset, 50.0 + aura_pulse * 0.6, Color(0.90, 0.78, 0.30, 0.06))
		draw_circle(body_offset, 42.0 + aura_pulse * 0.3, Color(1.0, 0.90, 0.45, 0.06))
		draw_arc(body_offset, 56.0 + aura_pulse, 0, TAU, 32, Color(0.85, 0.72, 0.25, 0.15), 2.5)
		draw_arc(body_offset, 46.0 + aura_pulse * 0.5, 0, TAU, 24, Color(1.0, 0.90, 0.45, 0.08), 1.8)
		# Orbiting golden sparkles
		for gs in range(6):
			var gs_a = _time * (0.6 + float(gs % 3) * 0.2) + float(gs) * TAU / 6.0
			var gs_r = 46.0 + aura_pulse + float(gs % 3) * 3.5
			var gs_p = body_offset + Vector2.from_angle(gs_a) * gs_r
			var gs_size = 1.2 + sin(_time * 3.0 + float(gs) * 1.5) * 0.5
			var gs_alpha = 0.25 + sin(_time * 3.0 + float(gs)) * 0.15
			draw_circle(gs_p, gs_size, Color(1.0, 0.90, 0.45, gs_alpha))

	# === AWAITING ABILITY CHOICE INDICATOR ===
	if awaiting_ability_choice:
		var pulse = (sin(_time * 4.0) + 1.0) * 0.5
		draw_circle(Vector2.ZERO, 68.0 + pulse * 6.0, Color(0.85, 0.72, 0.25, 0.1 + pulse * 0.1))
		draw_arc(Vector2.ZERO, 68.0 + pulse * 6.0, 0, TAU, 32, Color(0.85, 0.72, 0.25, 0.3 + pulse * 0.3), 2.5)
		var font3 = ThemeDB.fallback_font
		draw_string(font3, Vector2(-16, -80), "!", HORIZONTAL_ALIGNMENT_CENTER, 32, 30, Color(0.85, 0.72, 0.25, 0.7 + pulse * 0.3))

	# === DAMAGE COUNTER ===
	if damage_dealt > 0:
		var font = ThemeDB.fallback_font
		var dmg_text = str(int(damage_dealt)) + " DMG"
		if stat_upgrade_level > 0:
			dmg_text += " " + str(stat_upgrade_level) + " Lv."
		draw_string(font, Vector2(-36, 56), dmg_text, HORIZONTAL_ALIGNMENT_LEFT, 160, 12, Color(0.85, 0.72, 0.25, 0.5))

	# === UPGRADE NAME FLASH ===
	if _upgrade_flash > 0.0 and _upgrade_name != "":
		var font2 = ThemeDB.fallback_font
		draw_string(font2, Vector2(-80, -72), _upgrade_name, HORIZONTAL_ALIGNMENT_CENTER, 160, 16, Color(0.85, 0.72, 0.25, min(_upgrade_flash, 1.0)))

# === SYNERGY BUFFS ===
var _synergy_buffs: Dictionary = {}
var _meta_buffs: Dictionary = {}

func set_synergy_buff(buffs: Dictionary) -> void:
	for key in buffs:
		_synergy_buffs[key] = _synergy_buffs.get(key, 0.0) + buffs[key]

func clear_synergy_buff() -> void:
	_synergy_buffs.clear()

func set_meta_buffs(buffs: Dictionary) -> void:
	_meta_buffs = buffs

# Synergy multipliers (match robin_hood.gd pattern exactly)

var power_damage_mult: float = 1.0

func _damage_mult() -> float:
	return (1.0 + _synergy_buffs.get("damage", 0.0) + _meta_buffs.get("damage", 0.0)) * power_damage_mult

func _range_mult() -> float:
	return 1.0 + _synergy_buffs.get("range", 0.0) + _meta_buffs.get("range", 0.0)

func _speed_mult() -> float:
	return 1.0 + _synergy_buffs.get("attack_speed", 0.0) + _meta_buffs.get("attack_speed", 0.0)

func _gold_mult() -> float:
	return 1.0 + _synergy_buffs.get("gold_bonus", 0.0) + _meta_buffs.get("gold_bonus", 0.0)
