extends Node2D
## Sherlock Holmes — pure support/buff tower. Does NOT attack enemies.
## Buffs all towers in range with damage, speed, and range bonuses every 3 seconds.
## Ability: "Deduction" — auto-marks enemies in range, all towers deal +30% to marked targets.
## Tier 1: Elementary — stronger buffs, mark lasts 12s
## Tier 2: Piercing Insight — even stronger buffs + range buff to allies
## Tier 3: Multi-Mark — marks 2+ targets, powerful aura
## Tier 4: The Game is Afoot — legendary aura, all enemies auto-marked

# Base stats
var damage: float = 0.0  # Sherlock doesn't deal direct damage
var fire_rate: float = 0.0  # No direct attacks
var attack_range: float = 188.0
var fire_cooldown: float = 0.0
var aim_angle: float = 0.0
var target: Node2D = null
var gold_bonus: int = 2

# Buff aura system — buffs towers in range every 3 seconds
var _buff_timer: float = 3.0
var _buff_cooldown: float = 3.0
var _buffed_tower_ids: Dictionary = {}  # instance_id -> tier_when_buffed
var _buff_flash: float = 0.0

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
	"Elementary",
	"Piercing Insight",
	"Multi-Mark",
	"The Game is Afoot"
]
const ABILITY_DESCRIPTIONS = [
	"+20% DMG, +15% SPD aura, mark lasts 12s",
	"+25% DMG, +10% RNG aura to nearby towers",
	"Marks 2 targets, +30% DMG aura",
	"Legendary aura, all enemies auto-marked"
]
const TIER_COSTS = [100, 200, 350, 550]
var is_selected: bool = false
var base_cost: int = 0

# Sherlock doesn't use projectiles — pure support tower

# Maraca sound — plays every 3 seconds as buff pulse
var _maraca_sound: AudioStreamWAV
var _maraca_player: AudioStreamPlayer

# Ability sounds
var _deduction_sound: AudioStreamWAV
var _deduction_player: AudioStreamPlayer
var _upgrade_sound: AudioStreamWAV
var _upgrade_player: AudioStreamPlayer
var _game_font: Font

func _ready() -> void:
	_game_font = load("res://fonts/Cinzel.ttf")
	add_to_group("towers")
	_load_progressive_abilities()

	# Maraca shake — gentle short rattle, just filtered noise
	var mar_rate := 22050
	var mar_dur := 0.12
	var mar_samples := PackedFloat32Array()
	mar_samples.resize(int(mar_rate * mar_dur))
	var prev_s := 0.0
	for i in mar_samples.size():
		var t := float(i) / mar_rate
		# Quick attack, fast decay — one tiny shake
		var env := minf(t * 80.0, 1.0) * exp(-t * 35.0) * 0.3
		# Pure noise through heavy lowpass for soft bead rattle
		var noise := randf() * 2.0 - 1.0
		var s := prev_s * 0.6 + noise * 0.4
		prev_s = s
		mar_samples[i] = clampf(s * env, -1.0, 1.0)
	_maraca_sound = _samples_to_wav(mar_samples, mar_rate)
	_maraca_player = AudioStreamPlayer.new()
	_maraca_player.stream = _maraca_sound
	_maraca_player.volume_db = -10.0
	add_child(_maraca_player)

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
	_upgrade_flash = max(_upgrade_flash - delta * 0.5, 0.0)
	_deduction_flash = max(_deduction_flash - delta * 2.0, 0.0)
	_buff_flash = max(_buff_flash - delta * 2.0, 0.0)
	_attack_anim = max(_attack_anim - delta * 3.0, 0.0)

	# Buff aura — every 3 seconds, buff towers in range and mark enemies
	_buff_timer -= delta
	if _buff_timer <= 0.0:
		_buff_timer = _buff_cooldown
		_apply_buff_aura()
		_auto_mark_enemies()
		# Play maraca sound
		if _maraca_player and not _is_sfx_muted():
			_maraca_player.play()
		_buff_flash = 1.0
		_attack_anim = 1.0

	# Update mark timers
	_update_marks(delta)

	# Tier 4: Auto-mark also runs every frame for immediate marking
	if auto_mark:
		_auto_mark_enemies()

	# Progressive abilities
	_process_progressive_abilities(delta)

	queue_redraw()

func _get_buff_values() -> Dictionary:
	# Returns buff percentages based on upgrade tier
	match upgrade_tier:
		0: return {"damage": 0.15, "attack_speed": 0.10}
		1: return {"damage": 0.20, "attack_speed": 0.15}
		2: return {"damage": 0.25, "attack_speed": 0.15, "range": 0.10}
		3: return {"damage": 0.30, "attack_speed": 0.20, "range": 0.15}
		4: return {"damage": 0.40, "attack_speed": 0.25, "range": 0.20}
	return {"damage": 0.15, "attack_speed": 0.10}

func _apply_buff_aura() -> void:
	var eff_range = attack_range * _range_mult()
	var buff_vals = _get_buff_values()
	var current_tier = upgrade_tier
	for tower in get_tree().get_nodes_in_group("towers"):
		if tower == self:
			continue
		if global_position.distance_to(tower.global_position) > eff_range:
			# Tower out of range — skip
			continue
		var tid = tower.get_instance_id()
		if _buffed_tower_ids.has(tid) and _buffed_tower_ids[tid] == current_tier:
			# Already buffed at this tier
			continue
		if _buffed_tower_ids.has(tid):
			# Tier changed — apply difference
			var old_buffs = _get_buff_for_tier(_buffed_tower_ids[tid])
			var diff = {}
			for key in buff_vals:
				diff[key] = buff_vals.get(key, 0.0) - old_buffs.get(key, 0.0)
			if tower.has_method("set_synergy_buff"):
				tower.set_synergy_buff(diff)
		else:
			# New tower in range — apply full buff
			if tower.has_method("set_synergy_buff"):
				tower.set_synergy_buff(buff_vals)
		_buffed_tower_ids[tid] = current_tier
	# Clean up invalid tower references
	var to_remove := []
	for tid in _buffed_tower_ids:
		if not is_instance_id_valid(tid):
			to_remove.append(tid)
	for tid in to_remove:
		_buffed_tower_ids.erase(tid)

func _get_buff_for_tier(tier: int) -> Dictionary:
	match tier:
		0: return {"damage": 0.15, "attack_speed": 0.10}
		1: return {"damage": 0.20, "attack_speed": 0.15}
		2: return {"damage": 0.25, "attack_speed": 0.15, "range": 0.10}
		3: return {"damage": 0.30, "attack_speed": 0.20, "range": 0.15}
		4: return {"damage": 0.40, "attack_speed": 0.25, "range": 0.20}
	return {"damage": 0.15, "attack_speed": 0.10}

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

# Sherlock doesn't shoot — he's a pure support character
# The maraca sound is played in _process buff tick above

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
	attack_range += 4.5
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
		1: # Elementary — stronger buffs, longer marks
			mark_duration = 12.0
			attack_range = 203.0
			gold_bonus = 3
		2: # Piercing Insight — range buff to allies
			attack_range = 214.0
			gold_bonus = 4
			mark_duration = 14.0
		3: # Multi-Mark — marks 2 targets, powerful aura
			max_marks = 2
			attack_range = 225.0
			gold_bonus = 5
			mark_duration = 16.0
		4: # The Game is Afoot — legendary aura, all auto-marked
			auto_mark = true
			attack_range = 240.0
			gold_bonus = 6
			max_marks = 99
			mark_duration = 20.0
	# Re-buff all towers at new tier
	_rebuff_all_towers()

func _rebuff_all_towers() -> void:
	# When Sherlock upgrades, re-apply buff differences to all tracked towers
	var new_buffs = _get_buff_values()
	for tid in _buffed_tower_ids:
		if not is_instance_id_valid(tid):
			continue
		var tower = instance_from_id(tid)
		if tower and tower.has_method("set_synergy_buff"):
			var old_tier = _buffed_tower_ids[tid]
			var old_buffs = _get_buff_for_tier(old_tier)
			var diff = {}
			for key in new_buffs:
				diff[key] = new_buffs.get(key, 0.0) - old_buffs.get(key, 0.0)
			tower.set_synergy_buff(diff)
			_buffed_tower_ids[tid] = upgrade_tier

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

	# === 2. RANGE ARC (buff aura indicator) ===
	var aura_pulse = (sin(_time * 2.0) + 1.0) * 0.5
	draw_arc(Vector2.ZERO, attack_range, 0, TAU, 64, Color(0.85, 0.72, 0.25, 0.04 + aura_pulse * 0.04), 1.5)
	# Buff pulse ring expanding outward
	if _buff_flash > 0.0:
		var pulse_r = attack_range * (1.0 - _buff_flash * 0.3)
		draw_arc(Vector2.ZERO, pulse_r, 0, TAU, 48, Color(0.85, 0.72, 0.25, _buff_flash * 0.2), 2.5)
		draw_circle(Vector2.ZERO, pulse_r, Color(0.85, 0.72, 0.25, _buff_flash * 0.03))

	# === 3. FACING (support stance — faces center of buffed area) ===
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

	# === 11. CHARACTER POSITIONS (BTD6 chibi proportions) ===
	var OL = Color(0.06, 0.06, 0.08)
	var hip_sway = hip_shift
	var chest_breathe = breathe
	var feet_y = body_offset + Vector2(hip_sway * 1.0, 10.0)
	var leg_top = body_offset + Vector2(hip_sway * 0.6, 0.0)
	var torso_center = body_offset + Vector2(hip_sway * 0.3, -8.0 - chest_breathe * 0.5)
	var neck_base = body_offset + Vector2(hip_sway * 0.15, -14.0 - chest_breathe * 0.3)
	var head_center = body_offset + Vector2(hip_sway * 0.08, -26.0)

	# Saturated color palette
	var tweed_dark = Color(0.38, 0.26, 0.12)
	var tweed_mid = Color(0.52, 0.38, 0.18)
	var tweed_light = Color(0.62, 0.48, 0.26)
	var trouser_col = Color(0.40, 0.32, 0.18)
	var trouser_hi = Color(0.50, 0.40, 0.24)
	var shirt_col = Color(0.94, 0.92, 0.88)
	var shoe_col = Color(0.22, 0.14, 0.08)
	var shoe_hi = Color(0.34, 0.22, 0.12)
	var brass_col = Color(0.85, 0.68, 0.18)
	var brass_hi = Color(1.0, 0.88, 0.35)

	# === 12. TIER-SPECIFIC EFFECTS (drawn BEFORE/AROUND body) ===

	# Tier 1+: Faint golden motes around magnifying glass area
	if upgrade_tier >= 1:
		for li in range(4 + upgrade_tier):
			var la = _time * (0.5 + fmod(float(li) * 1.37, 0.4)) + float(li) * TAU / float(4 + upgrade_tier)
			var lr = 18.0 + fmod(float(li) * 3.7, 12.0)
			var sparkle_pos = body_offset + Vector2(cos(la) * lr + 15.0, sin(la) * lr * 0.5 - 5.0)
			var sparkle_alpha = 0.18 + sin(_time * 2.0 + float(li)) * 0.1
			draw_circle(sparkle_pos, 1.5, Color(1.0, 0.90, 0.40, sparkle_alpha))
			draw_circle(sparkle_pos, 0.7, Color(1.0, 0.95, 0.7, sparkle_alpha * 0.8))

	# Tier 2+: Visible beam line from lens when targeting
	if upgrade_tier >= 2 and target:
		var beam_alpha = 0.08 + sin(_time * 4.0) * 0.04
		var beam_end_t = (target.global_position - global_position).normalized() * 60.0
		draw_line(body_offset + Vector2(18, -8), beam_end_t, Color(1.0, 0.92, 0.5, beam_alpha), 2.0)
		draw_line(body_offset + Vector2(18, -8), beam_end_t, Color(1.0, 0.97, 0.8, beam_alpha * 0.5), 1.0)

	# Tier 3+: Dual orbiting magnifying glass icons
	if upgrade_tier >= 3:
		for mi_vis in range(2):
			var ma_vis = _time * 0.8 + float(mi_vis) * PI
			var m_pos = body_offset + Vector2(cos(ma_vis) * 32.0, sin(ma_vis) * 12.0 - 5.0)
			var m_alpha = 0.18 + sin(_time * 2.5 + float(mi_vis) * 1.5) * 0.1
			draw_arc(m_pos, 4.0, 0, TAU, 10, Color(0.85, 0.72, 0.25, m_alpha), 1.2)
			draw_line(m_pos + Vector2(3, 3), m_pos + Vector2(6, 6), Color(0.85, 0.72, 0.25, m_alpha * 0.7), 1.0)

	# Tier 4: Floating evidence papers
	if upgrade_tier >= 4:
		for ep in range(6):
			var ep_seed = float(ep) * 2.37
			var ep_angle = _time * (0.4 + fmod(ep_seed, 0.3)) + ep_seed
			var ep_radius = 35.0 + fmod(ep_seed * 5.3, 20.0)
			var ep_pos = body_offset + Vector2(cos(ep_angle) * ep_radius, sin(ep_angle) * ep_radius * 0.6)
			var ep_alpha = 0.25 + sin(_time * 2.0 + ep_seed * 2.0) * 0.12
			var ep_rot = _time * 1.5 + ep_seed
			var p_dir_e = Vector2.from_angle(ep_rot)
			var p_perp_e = p_dir_e.rotated(PI / 2.0)
			var paper_pts = PackedVector2Array([
				ep_pos - p_dir_e * 3.5 - p_perp_e * 2.5,
				ep_pos + p_dir_e * 3.5 - p_perp_e * 2.5,
				ep_pos + p_dir_e * 3.5 + p_perp_e * 2.5,
				ep_pos - p_dir_e * 3.5 + p_perp_e * 2.5,
			])
			draw_colored_polygon(paper_pts, Color(0.95, 0.92, 0.85, ep_alpha))
			draw_line(ep_pos - p_dir_e * 2.0, ep_pos + p_dir_e * 1.5, Color(0.3, 0.3, 0.3, ep_alpha * 0.5), 0.6)

	# === 13. CHARACTER BODY (BTD6 Cartoon Style) ===

	# --- CHUNKY SHOES (brown leather) ---
	var l_foot = feet_y + Vector2(-5, 0)
	var r_foot = feet_y + Vector2(5, 0)
	# Left shoe: outline then fill
	draw_circle(l_foot, 6.0, OL)
	draw_circle(l_foot, 4.5, shoe_col)
	draw_circle(l_foot + Vector2(-3, 0), 4.5, OL)
	draw_circle(l_foot + Vector2(-3, 0), 3.2, shoe_hi)
	# Right shoe: outline then fill
	draw_circle(r_foot, 6.0, OL)
	draw_circle(r_foot, 4.5, shoe_col)
	draw_circle(r_foot + Vector2(3, 0), 4.5, OL)
	draw_circle(r_foot + Vector2(3, 0), 3.2, shoe_hi)
	# Shoe soles (bold dark line)
	draw_line(l_foot + Vector2(-6, 2), l_foot + Vector2(3, 2), OL, 2.5)
	draw_line(r_foot + Vector2(-3, 2), r_foot + Vector2(6, 2), OL, 2.5)
	# Shoe shine
	draw_circle(l_foot + Vector2(-2, -1), 1.2, Color(0.45, 0.32, 0.18, 0.4))
	draw_circle(r_foot + Vector2(2, -1), 1.2, Color(0.45, 0.32, 0.18, 0.4))

	# --- CHUNKY LEGS (tan trousers) ---
	var l_hip = leg_top + Vector2(-4, 0)
	var r_hip = leg_top + Vector2(4, 0)
	var l_knee = l_foot.lerp(l_hip, 0.45) + Vector2(-1, 0)
	var r_knee = r_foot.lerp(r_hip, 0.45) + Vector2(1, 0)
	# Left leg: outline then fill
	draw_line(l_hip, l_knee, OL, 10.0)
	draw_line(l_knee, l_foot + Vector2(0, -2), OL, 9.0)
	draw_line(l_hip, l_knee, trouser_col, 7.5)
	draw_line(l_knee, l_foot + Vector2(0, -2), trouser_col, 6.5)
	draw_line(l_hip + Vector2(-1, 0), l_knee + Vector2(-1, 0), trouser_hi, 2.0)
	# Left knee
	draw_circle(l_knee, 5.0, OL)
	draw_circle(l_knee, 3.8, trouser_col)
	# Right leg: outline then fill
	draw_line(r_hip, r_knee, OL, 10.0)
	draw_line(r_knee, r_foot + Vector2(0, -2), OL, 9.0)
	draw_line(r_hip, r_knee, trouser_col, 7.5)
	draw_line(r_knee, r_foot + Vector2(0, -2), trouser_col, 6.5)
	draw_line(r_hip + Vector2(1, 0), r_knee + Vector2(1, 0), trouser_hi, 2.0)
	# Right knee
	draw_circle(r_knee, 5.0, OL)
	draw_circle(r_knee, 3.8, trouser_col)

	# --- TORSO (tweed coat — rich brown) ---
	# Coat body outline
	var coat_pts_ol = PackedVector2Array([
		leg_top + Vector2(-10, 2),
		torso_center + Vector2(-14, 0),
		neck_base + Vector2(-14, 0),
		neck_base + Vector2(14, 0),
		torso_center + Vector2(14, 0),
		leg_top + Vector2(10, 2),
	])
	draw_colored_polygon(coat_pts_ol, OL)
	# Coat fill
	var coat_pts = PackedVector2Array([
		leg_top + Vector2(-8.5, 1),
		torso_center + Vector2(-12.5, 0),
		neck_base + Vector2(-12.5, 0),
		neck_base + Vector2(12.5, 0),
		torso_center + Vector2(12.5, 0),
		leg_top + Vector2(8.5, 1),
	])
	draw_colored_polygon(coat_pts, tweed_dark)
	# Coat highlight panel
	var coat_hi_pts = PackedVector2Array([
		torso_center + Vector2(-6, -1),
		neck_base + Vector2(-6, 1),
		neck_base + Vector2(6, 1),
		torso_center + Vector2(6, -1),
	])
	draw_colored_polygon(coat_hi_pts, tweed_mid)
	# Tweed check pattern on coat
	for ci in range(5):
		var cx = -8.0 + float(ci) * 4.0
		var c_top = neck_base + Vector2(cx, 1)
		var c_bot = torso_center + Vector2(cx, -1)
		draw_line(c_top, c_bot, Color(tweed_light.r, tweed_light.g, tweed_light.b, 0.25), 0.8)
	for ci2 in range(3):
		var cy2 = 0.25 + float(ci2) * 0.35
		var c_l = neck_base.lerp(torso_center, cy2) + Vector2(-11, 0)
		var c_r = neck_base.lerp(torso_center, cy2) + Vector2(11, 0)
		draw_line(c_l, c_r, Color(tweed_light.r, tweed_light.g, tweed_light.b, 0.2), 0.6)
	# White shirt V at collar
	draw_colored_polygon(PackedVector2Array([
		neck_base + Vector2(-4, 1),
		neck_base + Vector2(4, 1),
		neck_base + Vector2(0, 6),
	]), OL)
	draw_colored_polygon(PackedVector2Array([
		neck_base + Vector2(-3, 1.5),
		neck_base + Vector2(3, 1.5),
		neck_base + Vector2(0, 5),
	]), shirt_col)
	# Coat lapels (darker brown overlapping collar)
	var lapel_l = PackedVector2Array([
		neck_base + Vector2(-12.5, 0),
		neck_base + Vector2(-4, 2),
		torso_center + Vector2(-5, -1),
		torso_center + Vector2(-12, 0),
	])
	draw_colored_polygon(lapel_l, tweed_mid)
	draw_line(neck_base + Vector2(-4, 2), torso_center + Vector2(-5, -1), OL, 1.5)
	var lapel_r = PackedVector2Array([
		neck_base + Vector2(12.5, 0),
		neck_base + Vector2(4, 2),
		torso_center + Vector2(5, -1),
		torso_center + Vector2(12, 0),
	])
	draw_colored_polygon(lapel_r, tweed_mid)
	draw_line(neck_base + Vector2(4, 2), torso_center + Vector2(5, -1), OL, 1.5)
	# Coat buttons (2 bold brass)
	for bi in range(2):
		var bt = 0.35 + float(bi) * 0.3
		var btn_pos = leg_top.lerp(neck_base, bt)
		draw_circle(btn_pos, 2.2, OL)
		draw_circle(btn_pos, 1.6, brass_col)
		draw_circle(btn_pos + Vector2(-0.3, -0.3), 0.7, brass_hi)
	# Coat hem outline
	draw_line(leg_top + Vector2(-10, 2), leg_top + Vector2(10, 2), OL, 2.0)
	# Darker collar fold
	draw_line(neck_base + Vector2(-12, 0), neck_base + Vector2(12, 0), OL, 2.0)

	# --- SHOULDERS (chunky round) ---
	var l_shoulder = neck_base + Vector2(-12, 0)
	var r_shoulder = neck_base + Vector2(12, 0)
	draw_circle(l_shoulder, 7.0, OL)
	draw_circle(l_shoulder, 5.5, tweed_dark)
	draw_circle(l_shoulder + Vector2(-0.5, -0.5), 3.0, tweed_mid)
	draw_circle(r_shoulder, 7.0, OL)
	draw_circle(r_shoulder, 5.5, tweed_dark)
	draw_circle(r_shoulder + Vector2(0.5, -0.5), 3.0, tweed_mid)

	# --- LEFT ARM (holds magnifying glass — extends on attack) ---
	var glass_angle = aim_angle + 0.3
	var glass_dir = Vector2.from_angle(glass_angle)
	var arm_extend = _attack_anim * 6.0
	var l_hand = l_shoulder + Vector2(-2, 8) + glass_dir * (14.0 + arm_extend)
	var l_elbow = l_shoulder + (l_hand - l_shoulder) * 0.45 + Vector2(-3, 3)
	# Upper arm: outline then fill
	draw_line(l_shoulder, l_elbow, OL, 10.0)
	draw_line(l_shoulder, l_elbow, tweed_dark, 7.5)
	draw_line(l_shoulder + Vector2(-1, 0), l_elbow + Vector2(-1, 0), tweed_mid, 2.5)
	# Elbow joint
	draw_circle(l_elbow, 5.5, OL)
	draw_circle(l_elbow, 4.0, tweed_dark)
	# Forearm: outline then fill
	draw_line(l_elbow, l_hand, OL, 9.0)
	draw_line(l_elbow, l_hand, tweed_dark, 6.5)
	# Cuff (shirt peeking out)
	var l_cuff_p = l_elbow.lerp(l_hand, 0.82)
	var lf_dir = (l_hand - l_elbow).normalized()
	var lf_perp = lf_dir.rotated(PI / 2.0)
	draw_line(l_cuff_p - lf_perp * 4.5, l_cuff_p + lf_perp * 4.5, OL, 3.0)
	draw_line(l_cuff_p - lf_perp * 3.5, l_cuff_p + lf_perp * 3.5, shirt_col, 2.0)
	# Hand
	draw_circle(l_hand, 4.5, OL)
	draw_circle(l_hand, 3.5, skin_base)
	draw_circle(l_hand + Vector2(-0.5, -0.5), 1.8, skin_highlight)
	# Gripping fingers
	for fi in range(3):
		var fang = float(fi - 1) * 0.35
		var fpos = l_hand + glass_dir.rotated(fang) * 3.5
		draw_circle(fpos, 2.0, OL)
		draw_circle(fpos, 1.3, skin_base)

	# === MAGNIFYING GLASS (signature weapon!) ===
	var glass_handle_start = l_hand + glass_dir * 3.0
	var glass_handle_end = l_hand + glass_dir * 13.0
	var glass_center = l_hand + glass_dir * (20.0 + arm_extend * 0.5)
	# Handle: outline then fill
	draw_line(glass_handle_start, glass_handle_end, OL, 6.0)
	draw_line(glass_handle_start, glass_handle_end, Color(0.36, 0.22, 0.08), 4.0)
	draw_line(glass_handle_start, glass_handle_end, Color(0.48, 0.32, 0.14), 2.5)
	# Handle grip ridges
	for gi in range(3):
		var gt = 0.2 + float(gi) * 0.3
		var g_pos = glass_handle_start.lerp(glass_handle_end, gt)
		var g_perp_dir = glass_dir.rotated(PI / 2.0)
		draw_line(g_pos - g_perp_dir * 2.5, g_pos + g_perp_dir * 2.5, Color(0.28, 0.16, 0.06, 0.5), 1.0)
	# Brass ferrule
	var ferrule = glass_handle_end
	draw_circle(ferrule, 4.0, OL)
	draw_circle(ferrule, 3.0, brass_col)
	draw_circle(ferrule + Vector2(-0.5, -0.5), 1.5, brass_hi)
	# Lens frame (bold brass ring)
	var frame_radius = 10.0
	draw_arc(glass_center, frame_radius + 2.0, 0, TAU, 24, OL, 4.5)
	draw_arc(glass_center, frame_radius, 0, TAU, 24, brass_col, 3.5)
	draw_arc(glass_center, frame_radius - 0.5, PI * 1.1, PI * 1.8, 12, brass_hi, 1.8)
	# Lens glass (light blue tint)
	draw_circle(glass_center, frame_radius - 2.0, Color(0.80, 0.90, 1.0, 0.18))
	# Lens light refraction
	var refract_offset = Vector2(sin(_time * 0.8) * 2.5, cos(_time * 0.6) * 2.0)
	draw_circle(glass_center + refract_offset, 4.5, Color(1.0, 0.98, 0.90, 0.15))
	draw_circle(glass_center + refract_offset * 0.5, 3.0, Color(1.0, 1.0, 0.95, 0.22))
	# Crescent highlight on lens
	draw_arc(glass_center + Vector2(-2.5, -2.5), 5.5, PI * 1.1, PI * 1.7, 8, Color(1.0, 1.0, 1.0, 0.45), 2.0)
	draw_circle(glass_center + Vector2(3.5, 3.5), 1.8, Color(1.0, 1.0, 1.0, 0.25))
	# Attack flash on lens
	if _attack_anim > 0.0:
		var flash_r = frame_radius + 4.0 + _attack_anim * 6.0
		draw_circle(glass_center, flash_r, Color(1.0, 0.95, 0.6, _attack_anim * 0.15))
		draw_arc(glass_center, flash_r, 0, TAU, 16, Color(1.0, 0.90, 0.4, _attack_anim * 0.3), 2.0)
	# Tier 1+: Faint glow around glass
	if upgrade_tier >= 1:
		var glow_pulse = (sin(_time * 3.0) + 1.0) * 0.5
		draw_circle(glass_center, frame_radius + 4.0, Color(1.0, 0.92, 0.5, 0.06 + glow_pulse * 0.04))
	# Tier 2+: Active beam from lens toward target
	if upgrade_tier >= 2 and target and _attack_anim > 0.0:
		var beam_dir_t = (target.global_position - global_position).normalized()
		var beam_len = 40.0 * _attack_anim
		draw_line(glass_center, glass_center + beam_dir_t * beam_len, Color(1.0, 0.95, 0.6, 0.25 * _attack_anim), 3.5)
		draw_line(glass_center, glass_center + beam_dir_t * beam_len, Color(1.0, 0.98, 0.8, 0.35 * _attack_anim), 1.8)
	# Buff pulse ring
	if _attack_anim > 0.2:
		var pulse_r2 = 20.0 + (1.0 - _attack_anim) * 40.0
		var pulse_alpha = _attack_anim * 0.4
		draw_arc(Vector2.ZERO, pulse_r2, 0, TAU, 32, Color(0.85, 0.72, 0.25, pulse_alpha), 2.5)

	# --- RIGHT ARM (rests at side / pipe hand) ---
	var r_hand = r_shoulder + Vector2(5, 16)
	var r_elbow = r_shoulder + (r_hand - r_shoulder) * 0.45 + Vector2(3, 2)
	# Upper arm: outline then fill
	draw_line(r_shoulder, r_elbow, OL, 10.0)
	draw_line(r_shoulder, r_elbow, tweed_dark, 7.5)
	draw_line(r_shoulder + Vector2(1, 0), r_elbow + Vector2(1, 0), tweed_mid, 2.5)
	# Elbow
	draw_circle(r_elbow, 5.5, OL)
	draw_circle(r_elbow, 4.0, tweed_dark)
	# Forearm
	draw_line(r_elbow, r_hand, OL, 9.0)
	draw_line(r_elbow, r_hand, tweed_dark, 6.5)
	# Cuff
	var r_cuff_p = r_elbow.lerp(r_hand, 0.82)
	var rf_dir = (r_hand - r_elbow).normalized()
	var rf_perp = rf_dir.rotated(PI / 2.0)
	draw_line(r_cuff_p - rf_perp * 4.5, r_cuff_p + rf_perp * 4.5, OL, 3.0)
	draw_line(r_cuff_p - rf_perp * 3.5, r_cuff_p + rf_perp * 3.5, shirt_col, 2.0)
	# Hand
	draw_circle(r_hand, 4.5, OL)
	draw_circle(r_hand, 3.5, skin_base)
	draw_circle(r_hand + Vector2(0.5, -0.5), 1.8, skin_highlight)

	# --- PIPE (in right hand, angled up) ---
	var pipe_bowl = r_hand + Vector2(2, -5)
	# Stem: outline then fill
	draw_line(r_hand + Vector2(0, -1), pipe_bowl, OL, 4.0)
	draw_line(r_hand + Vector2(0, -1), pipe_bowl, Color(0.30, 0.18, 0.08), 2.5)
	# Bowl: outline then fill
	draw_circle(pipe_bowl, 4.5, OL)
	draw_circle(pipe_bowl, 3.3, Color(0.35, 0.20, 0.08))
	draw_circle(pipe_bowl + Vector2(-0.5, -0.5), 1.8, Color(0.45, 0.28, 0.12))
	# Bowl opening
	draw_circle(pipe_bowl + Vector2(0, -2), 2.2, OL)
	draw_circle(pipe_bowl + Vector2(0, -2), 1.5, Color(0.10, 0.05, 0.02))
	# Animated smoke wisps (curling upward)
	var smoke_base_pos = pipe_bowl + Vector2(0, -5)
	for si in range(4):
		var sx = sin(_time * 1.2 + float(si) * 1.8) * (3.0 + float(si) * 1.5)
		var sy_raw = -float(si) * 5.0 - fmod(_time * 8.0, 25.0)
		var sy = fmod(sy_raw, -22.0)
		var s_alpha = 0.22 - float(si) * 0.05
		if s_alpha > 0.0:
			var smoke_pos = smoke_base_pos + Vector2(sx, sy)
			var smoke_r = 2.0 + float(si) * 1.0
			draw_circle(smoke_pos, smoke_r + 1.0, Color(0.75, 0.75, 0.78, s_alpha * 0.4))
			draw_circle(smoke_pos, smoke_r, Color(0.82, 0.82, 0.85, s_alpha))

	# === HEAD (big chibi head) ===
	# Neck: outline then fill
	draw_line(neck_base, head_center + Vector2(0, 8), OL, 9.0)
	draw_line(neck_base, head_center + Vector2(0, 8), skin_shadow, 6.5)
	draw_line(neck_base, head_center + Vector2(0, 8), skin_base, 5.0)
	# Shirt collar at neck
	draw_line(neck_base + Vector2(-5, 0), neck_base + Vector2(-3, -3), OL, 3.5)
	draw_line(neck_base + Vector2(5, 0), neck_base + Vector2(3, -3), OL, 3.5)
	draw_line(neck_base + Vector2(-4.5, 0), neck_base + Vector2(-2.5, -2.5), shirt_col, 2.5)
	draw_line(neck_base + Vector2(4.5, 0), neck_base + Vector2(2.5, -2.5), shirt_col, 2.5)

	# Hair back layer (dark brown, visible behind head)
	var hair_col = Color(0.18, 0.12, 0.06)
	var hair_hi = Color(0.30, 0.22, 0.14)
	# Head outline + hair base
	draw_circle(head_center, 14.0, OL)
	draw_circle(head_center, 12.5, hair_col)
	draw_circle(head_center + Vector2(0, -1), 11.0, Color(0.24, 0.16, 0.08))

	# Face circle: outline + skin fill
	draw_circle(head_center + Vector2(0, 1.0), 12.0, OL)
	draw_circle(head_center + Vector2(0, 1.0), 10.8, skin_base)
	# Cheek warmth (subtle cartoon blush)
	draw_circle(head_center + Vector2(-6, 3), 3.0, Color(0.95, 0.78, 0.65, 0.2))
	draw_circle(head_center + Vector2(6, 3), 3.0, Color(0.95, 0.78, 0.65, 0.2))
	# Strong chin hint
	draw_arc(head_center + Vector2(0, 8), 4.0, 0.3, PI - 0.3, 8, Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.25), 1.2)

	# Ears (peek out from sides)
	var l_ear = head_center + Vector2(-10, 0)
	var r_ear = head_center + Vector2(10, 0)
	draw_circle(l_ear, 3.5, OL)
	draw_circle(l_ear, 2.5, skin_base)
	draw_circle(l_ear + Vector2(-0.3, 0), 1.2, Color(0.90, 0.72, 0.58, 0.5))
	draw_circle(r_ear, 3.5, OL)
	draw_circle(r_ear, 2.5, skin_base)
	draw_circle(r_ear + Vector2(0.3, 0), 1.2, Color(0.90, 0.72, 0.58, 0.5))

	# === EYES (BTD6 style: big, round, 5-layer) ===
	var look_dir = dir * 1.5
	var l_eye = head_center + Vector2(-4.0, -1.0)
	var r_eye_pos = head_center + Vector2(4.0, -1.0)
	# Eye outlines (bold black border)
	draw_circle(l_eye, 5.8, OL)
	draw_circle(r_eye_pos, 5.8, OL)
	# Eye whites
	draw_circle(l_eye, 4.8, Color(0.97, 0.97, 0.99))
	draw_circle(r_eye_pos, 4.8, Color(0.97, 0.97, 0.99))
	# Dark brown irises (keen, intelligent)
	var iris_col = Color(0.30, 0.22, 0.12)
	var iris_mid = Color(0.42, 0.32, 0.18)
	draw_circle(l_eye + look_dir, 3.2, iris_col)
	draw_circle(l_eye + look_dir, 2.5, iris_mid)
	draw_circle(r_eye_pos + look_dir, 3.2, iris_col)
	draw_circle(r_eye_pos + look_dir, 2.5, iris_mid)
	# Pupils (sharp, focused)
	draw_circle(l_eye + look_dir * 1.1, 1.6, Color(0.04, 0.04, 0.06))
	draw_circle(r_eye_pos + look_dir * 1.1, 1.6, Color(0.04, 0.04, 0.06))
	# Primary sparkle highlight
	draw_circle(l_eye + Vector2(-1.0, -1.5), 1.5, Color(1.0, 1.0, 1.0, 0.95))
	draw_circle(r_eye_pos + Vector2(-1.0, -1.5), 1.5, Color(1.0, 1.0, 1.0, 0.95))
	# Secondary sparkle
	draw_circle(l_eye + Vector2(1.2, 0.8), 0.8, Color(1.0, 1.0, 1.0, 0.55))
	draw_circle(r_eye_pos + Vector2(1.2, 0.8), 0.8, Color(1.0, 1.0, 1.0, 0.55))
	# Analytical glint (keen intelligence shimmer)
	var glint_t = sin(_time * 2.5) * 0.25
	draw_circle(l_eye + Vector2(0.5, -0.5), 0.6, Color(0.7, 0.85, 1.0, 0.3 + glint_t))
	draw_circle(r_eye_pos + Vector2(0.5, -0.5), 0.6, Color(0.7, 0.85, 1.0, 0.3 + glint_t))
	# Bold upper eyelids (confident, slightly narrowed)
	draw_arc(l_eye, 5.0, PI + 0.15, TAU - 0.15, 10, OL, 2.2)
	draw_arc(r_eye_pos, 5.0, PI + 0.15, TAU - 0.15, 10, OL, 2.2)
	# Lower eyelid (subtle)
	draw_arc(l_eye, 4.5, 0.3, PI - 0.3, 8, Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.25), 0.8)
	draw_arc(r_eye_pos, 4.5, 0.3, PI - 0.3, 8, Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.25), 0.8)

	# --- EYEBROWS (bold, sharp, analytical arches) ---
	draw_line(l_eye + Vector2(-4.5, -5.5), l_eye + Vector2(0.5, -6.5), OL, 2.8)
	draw_line(l_eye + Vector2(0.5, -6.5), l_eye + Vector2(4.0, -5.0), OL, 2.0)
	draw_line(r_eye_pos + Vector2(-4.0, -5.0), r_eye_pos + Vector2(-0.5, -6.5), OL, 2.0)
	draw_line(r_eye_pos + Vector2(-0.5, -6.5), r_eye_pos + Vector2(4.5, -5.5), OL, 2.8)

	# --- NOSE (small chibi button with character) ---
	draw_circle(head_center + Vector2(0, 3.5), 2.2, OL)
	draw_circle(head_center + Vector2(0, 3.5), 1.6, skin_highlight)
	draw_circle(head_center + Vector2(-0.3, 3.2), 0.8, Color(1.0, 0.95, 0.88, 0.4))

	# --- MOUTH (confident half-smile) ---
	draw_arc(head_center + Vector2(0, 6.0), 3.5, 0.15, PI * 0.7, 8, OL, 2.0)
	draw_arc(head_center + Vector2(0, 6.0), 3.5, 0.2, PI * 0.65, 8, Color(0.60, 0.32, 0.22), 1.2)
	# Smirk corner upturn
	draw_line(head_center + Vector2(3.2, 5.8), head_center + Vector2(4.0, 5.2), OL, 1.5)

	# === DEERSTALKER HAT (big, prominent, signature!) ===
	var hat_base_y = head_center + Vector2(0, -8)

	# Main crown outline (oversized for chibi)
	var hat_crown_ol = PackedVector2Array([
		hat_base_y + Vector2(-13, 3),
		hat_base_y + Vector2(-14, -2),
		hat_base_y + Vector2(-10, -9),
		hat_base_y + Vector2(-4, -12),
		hat_base_y + Vector2(4, -12),
		hat_base_y + Vector2(10, -9),
		hat_base_y + Vector2(14, -2),
		hat_base_y + Vector2(13, 3),
	])
	draw_colored_polygon(hat_crown_ol, OL)
	# Crown fill
	var hat_crown_pts = PackedVector2Array([
		hat_base_y + Vector2(-11.5, 2),
		hat_base_y + Vector2(-12.5, -2),
		hat_base_y + Vector2(-9, -8),
		hat_base_y + Vector2(-3.5, -10.5),
		hat_base_y + Vector2(3.5, -10.5),
		hat_base_y + Vector2(9, -8),
		hat_base_y + Vector2(12.5, -2),
		hat_base_y + Vector2(11.5, 2),
	])
	draw_colored_polygon(hat_crown_pts, tweed_dark)
	# Crown highlight
	draw_colored_polygon(PackedVector2Array([
		hat_base_y + Vector2(-9, -1),
		hat_base_y + Vector2(-7, -7),
		hat_base_y + Vector2(7, -7),
		hat_base_y + Vector2(9, -1),
	]), tweed_mid)
	# Checkered tweed pattern (bold, visible)
	for hi in range(4):
		for hj in range(3):
			var check_x = -7.0 + float(hi) * 4.5
			var check_y = -8.0 + float(hj) * 3.5
			var check_pos = hat_base_y + Vector2(check_x, check_y)
			if (hi + hj) % 2 == 0:
				draw_colored_polygon(PackedVector2Array([
					check_pos, check_pos + Vector2(3.5, 0),
					check_pos + Vector2(3.5, 2.8), check_pos + Vector2(0, 2.8),
				]), Color(tweed_light.r, tweed_light.g, tweed_light.b, 0.3))

	# Front brim (bold, extends forward)
	var front_brim_ol = PackedVector2Array([
		hat_base_y + Vector2(-13, 3),
		hat_base_y + Vector2(13, 3),
		hat_base_y + Vector2(10, 7),
		hat_base_y + Vector2(-10, 7),
	])
	draw_colored_polygon(front_brim_ol, OL)
	var front_brim_fill = PackedVector2Array([
		hat_base_y + Vector2(-11.5, 3.5),
		hat_base_y + Vector2(11.5, 3.5),
		hat_base_y + Vector2(9, 6),
		hat_base_y + Vector2(-9, 6),
	])
	draw_colored_polygon(front_brim_fill, Color(0.42, 0.30, 0.15))
	# Brim highlight
	draw_line(hat_base_y + Vector2(-9, 6), hat_base_y + Vector2(9, 6), Color(0.55, 0.42, 0.25, 0.5), 1.2)

	# Ear flaps (tied up on top -- iconic!)
	# Left flap outline + fill
	var l_flap_ol = PackedVector2Array([
		hat_base_y + Vector2(-14, 0),
		hat_base_y + Vector2(-13, 3),
		hat_base_y + Vector2(-10, 4),
		hat_base_y + Vector2(-9, -3),
		hat_base_y + Vector2(-12, -4),
	])
	draw_colored_polygon(l_flap_ol, OL)
	var l_flap_fill = PackedVector2Array([
		hat_base_y + Vector2(-12.5, -0.5),
		hat_base_y + Vector2(-11.5, 2.5),
		hat_base_y + Vector2(-10, 3),
		hat_base_y + Vector2(-9.5, -2.5),
		hat_base_y + Vector2(-11, -3),
	])
	draw_colored_polygon(l_flap_fill, Color(0.46, 0.34, 0.20))
	# Right flap outline + fill
	var r_flap_ol = PackedVector2Array([
		hat_base_y + Vector2(14, 0),
		hat_base_y + Vector2(13, 3),
		hat_base_y + Vector2(10, 4),
		hat_base_y + Vector2(9, -3),
		hat_base_y + Vector2(12, -4),
	])
	draw_colored_polygon(r_flap_ol, OL)
	var r_flap_fill = PackedVector2Array([
		hat_base_y + Vector2(12.5, -0.5),
		hat_base_y + Vector2(11.5, 2.5),
		hat_base_y + Vector2(10, 3),
		hat_base_y + Vector2(9.5, -2.5),
		hat_base_y + Vector2(11, -3),
	])
	draw_colored_polygon(r_flap_fill, Color(0.46, 0.34, 0.20))

	# Tied-up button at crown (holding ear flaps up)
	draw_circle(hat_base_y + Vector2(0, -10), 3.0, OL)
	draw_circle(hat_base_y + Vector2(0, -10), 2.0, Color(0.48, 0.36, 0.20))
	draw_circle(hat_base_y + Vector2(-0.3, -10.3), 0.8, Color(0.58, 0.45, 0.28))

	# Hat band (dark bold ribbon)
	draw_line(hat_base_y + Vector2(-13, 2), hat_base_y + Vector2(13, 2), OL, 3.5)
	draw_line(hat_base_y + Vector2(-12, 1.5), hat_base_y + Vector2(12, 1.5), Color(0.18, 0.14, 0.08), 2.5)

	# Crown center seam
	draw_line(hat_base_y + Vector2(0, -10.5), hat_base_y + Vector2(0, 2), Color(0.32, 0.22, 0.12, 0.4), 1.0)

	# Tier 4: Hat glow
	if upgrade_tier >= 4:
		draw_circle(hat_base_y + Vector2(0, -5), 18.0, Color(1.0, 0.90, 0.45, 0.05 + sin(_time * 2.0) * 0.03))

	# === Tier 4: Golden-amber aura around whole character ===
	if upgrade_tier >= 4:
		var t4_aura_pulse = sin(_time * 2.5) * 5.0
		draw_circle(body_offset, 60.0 + t4_aura_pulse, Color(0.85, 0.72, 0.25, 0.04))
		draw_circle(body_offset, 50.0 + t4_aura_pulse * 0.6, Color(0.90, 0.78, 0.30, 0.06))
		draw_circle(body_offset, 42.0 + t4_aura_pulse * 0.3, Color(1.0, 0.90, 0.45, 0.06))
		draw_arc(body_offset, 56.0 + t4_aura_pulse, 0, TAU, 32, Color(0.85, 0.72, 0.25, 0.15), 2.5)
		draw_arc(body_offset, 46.0 + t4_aura_pulse * 0.5, 0, TAU, 24, Color(1.0, 0.90, 0.45, 0.08), 1.8)
		# Orbiting golden sparkles
		for gs in range(6):
			var gs_a = _time * (0.6 + float(gs % 3) * 0.2) + float(gs) * TAU / 6.0
			var gs_r = 46.0 + t4_aura_pulse + float(gs % 3) * 3.5
			var gs_p = body_offset + Vector2.from_angle(gs_a) * gs_r
			var gs_size = 1.2 + sin(_time * 3.0 + float(gs) * 1.5) * 0.5
			var gs_alpha = 0.25 + sin(_time * 3.0 + float(gs)) * 0.15
			draw_circle(gs_p, gs_size, Color(1.0, 0.90, 0.45, gs_alpha))

	# === AWAITING ABILITY CHOICE INDICATOR ===
	if awaiting_ability_choice:
		var pulse = (sin(_time * 4.0) + 1.0) * 0.5
		draw_circle(Vector2.ZERO, 68.0 + pulse * 6.0, Color(0.85, 0.72, 0.25, 0.1 + pulse * 0.1))
		draw_arc(Vector2.ZERO, 68.0 + pulse * 6.0, 0, TAU, 32, Color(0.85, 0.72, 0.25, 0.3 + pulse * 0.3), 2.5)
		var font3 = _game_font
		draw_string(font3, Vector2(-16, -80), "!", HORIZONTAL_ALIGNMENT_CENTER, 32, 30, Color(0.85, 0.72, 0.25, 0.7 + pulse * 0.3))

	# === DAMAGE COUNTER ===
	if damage_dealt > 0:
		var font = _game_font
		var dmg_text = str(int(damage_dealt)) + " DMG"
		if stat_upgrade_level > 0:
			dmg_text += " " + str(stat_upgrade_level) + " Lv."
		draw_string(font, Vector2(-36, 56), dmg_text, HORIZONTAL_ALIGNMENT_LEFT, 160, 12, Color(0.85, 0.72, 0.25, 0.5))

	# === UPGRADE NAME FLASH ===
	if _upgrade_flash > 0.0 and _upgrade_name != "":
		var font2 = _game_font
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
