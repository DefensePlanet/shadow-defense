extends Node2D
## Alice — support tower. Throws cake that slows and shrinks all nearby enemies.
## Based on Lewis Carroll's Alice's Adventures in Wonderland (1865) & Tenniel illustrations.
## Tier 1: "Eat Me Cake" — Cake 10% more sticky, slows enemies more
## Tier 2: "Cheshire Cat" — 10 second drum solo, slows all enemies in range 30%
## Tier 3: "Mad Tea Party" — Towers in range drink tea, +5% fire rate
## Tier 4: "Off With Their Heads!" — Paints ALL enemies red, low DoT as they walk

var damage: float = 3.0
var fire_rate: float = 1.0
var attack_range: float = 85.0
var fire_cooldown: float = 0.0
var aim_angle: float = 0.0
var target: Node2D = null
var gold_bonus: int = 1

# Damage tracking and upgrades
var damage_dealt: float = 0.0
var upgrade_tier: int = 0
var _upgrade_flash: float = 0.0
var _upgrade_name: String = ""

# Slow debuff
var slow_amount: float = 0.5
var slow_duration: float = 2.0

# Frosting DoT (unlocked by Tier 1 upgrade)
var frosting_dps: float = 0.0

# Tier 2: Cheshire Cat
var cheshire_cooldown: float = 12.0
var _cheshire_flash: float = 0.0

# Tier 3: Mad Tea Party
var _tea_flash: float = 0.0

# Tier 4: Off With Their Heads
var execute_threshold: float = 0.0
var _execute_flash: float = 0.0

# Animation vars
var _time: float = 0.0
var _attack_anim: float = 0.0

# Grow ability — Alice grows as she levels up
var _grow_scale: float = 1.0
var _grow_burst: float = 0.0  # Temporary extra scale on level-up

# === PROGRESSIVE ABILITIES (9 tiers, unlocked via lifetime damage) ===
const PROG_ABILITY_NAMES = [
	"Curiouser and Curiouser", "Down the Rabbit Hole", "Cheshire Grin",
	"Eat Me Cake", "Painting the Roses Red", "The Caterpillar's Hookah",
	"Tweedledee & Tweedledum", "The Jabberwock", "Wonderland Madness"
]
const PROG_ABILITY_DESCS = [
	"+20% cake damage, faster attack",
	"Every 20s, teleport enemy back 150 path units",
	"Every 10s, mark enemy for 2x damage for 5s",
	"Every 15s, Alice stomps for 4x AoE damage",
	"Each hit paints enemy, +5% damage per stack (max 10)",
	"Every 20s, smoke cloud slows enemies to 20% for 3s",
	"2 fighters patrol near Alice attacking every 2s",
	"Every 25s, Jabberwock swoops dealing 5x to all in path",
	"Cake splats bounce to nearby enemies"
]
var prog_abilities: Array = [false, false, false, false, false, false, false, false, false]
var _rabbit_hole_timer: float = 20.0
var _cheshire_grin_timer: float = 10.0
var _eat_me_timer: float = 15.0
var _caterpillar_timer: float = 20.0
var _tweedle_timer: float = 2.0
var _jabberwock_timer: float = 25.0
var _eat_me_flash: float = 0.0
var _jabberwock_flash: float = 0.0
var _caterpillar_flash: float = 0.0

const STAT_UPGRADE_INTERVAL: float = 2000.0
const ABILITY_THRESHOLD: float = 6000.0
var stat_upgrade_level: int = 0
var ability_chosen: bool = false
var awaiting_ability_choice: bool = false
const TIER_NAMES = [
	"Eat Me Cake",
	"Cheshire Cat",
	"Mad Tea Party",
	"Off With Their Heads!"
]
const ABILITY_DESCRIPTIONS = [
	"Cake 10% more sticky, slows enemies more, frosting DoT",
	"10 second drum solo, 30% slow aura on all enemies in range",
	"Towers in range drink tea, +5% fire rate",
	"Paints all enemies red, low DoT, 5% HP execute"
]
const TIER_COSTS = [70, 150, 275, 1000]
var is_selected: bool = false
var base_cost: int = 0

# Attack sounds — drums that evolve with each upgrade tier
var _attack_sounds: Array = []
var _attack_sounds_by_tier: Array = []
var _attack_player: AudioStreamPlayer
var _shot_count: int = 0

# Ability sounds
var _cheshire_sound: AudioStreamWAV
var _cheshire_player: AudioStreamPlayer
var _tea_sound: AudioStreamWAV
var _tea_player: AudioStreamPlayer
var _upgrade_sound: AudioStreamWAV
var _upgrade_player: AudioStreamPlayer
var _game_font: Font

func _ready() -> void:
	_game_font = load("res://fonts/Cinzel.ttf")
	add_to_group("towers")
	_load_progressive_abilities()
	_generate_tier_sounds()
	_attack_sounds = _attack_sounds_by_tier[0]
	_attack_player = AudioStreamPlayer.new()
	_attack_player.stream = _attack_sounds[0]
	_attack_player.volume_db = -4.0
	add_child(_attack_player)

	# Cheshire Cat — EPIC 10-second drum solo (4 phases building to crescendo)
	var ch_rate := 44100
	var ch_dur := 10.0
	var ch_samples := PackedFloat32Array()
	ch_samples.resize(int(ch_rate * ch_dur))
	var bpm := 130.0
	var beat_s := 60.0 / bpm  # ~0.46s per beat
	# Grid: 16th notes for precise drum hits
	var sixteenth := beat_s / 4.0
	var total_16ths := int(ch_dur / sixteenth)
	# Pre-compute which 16th notes have hits (kick/snare/hat/tom/crash)
	# Phase 1 (0-2.5s): Simple groove — kick+hat
	# Phase 2 (2.5-5s): Add snare, open hats
	# Phase 3 (5-7.5s): Double-time, toms, fills
	# Phase 4 (7.5-10s): Full blast, rolls, crash finale
	for i in ch_samples.size():
		var t := float(i) / ch_rate
		var s := 0.0
		var phase := 0
		if t >= 7.5: phase = 3
		elif t >= 5.0: phase = 2
		elif t >= 2.5: phase = 1
		var vol := 0.4 + float(phase) * 0.15  # Gets louder each phase

		# KICK DRUM
		var kick_grid := fmod(t, beat_s)
		var kick2_grid := fmod(t + beat_s * 0.5, beat_s)  # offbeat kick
		if kick_grid < 0.12:
			var kenv := exp(-kick_grid * 22.0) * 0.55 * vol
			var kf := 55.0 + exp(-kick_grid * 35.0) * 140.0
			s += sin(TAU * kf * kick_grid) * kenv
		# Double kick on phase 2+
		if phase >= 2 and kick2_grid < 0.12:
			var kenv2 := exp(-kick2_grid * 25.0) * 0.35 * vol
			var kf2 := 50.0 + exp(-kick2_grid * 40.0) * 120.0
			s += sin(TAU * kf2 * kick2_grid) * kenv2

		# SNARE (beats 2 and 4)
		if phase >= 1:
			var snare_grid := fmod(t + beat_s, beat_s * 2.0)
			if snare_grid < 0.08:
				var senv := exp(-snare_grid * 28.0) * 0.4 * vol
				s += sin(TAU * 185.0 * snare_grid) * senv * 0.5
				# Crackly noise
				var sn := sin(snare_grid * 14731.0) * cos(snare_grid * 8291.0)
				s += sn * senv * 0.6
		# Snare ROLLS in phase 3+ (every 16th on fills)
		if phase >= 2:
			var bar_pos := fmod(t, beat_s * 4.0)
			if bar_pos > beat_s * 3.0:  # Last beat of each bar = fill
				var roll_grid := fmod(bar_pos, sixteenth)
				if roll_grid < 0.04:
					var renv := exp(-roll_grid * 35.0) * 0.3 * vol
					var rn := sin(roll_grid * 18371.0) * cos(roll_grid * 9917.0)
					s += rn * renv * 0.5 + sin(TAU * 220.0 * roll_grid) * renv * 0.3
		# BUZZ ROLL in phase 4 last 2 seconds
		if phase >= 3 and t > 8.5:
			var buzz := fmod(t, sixteenth * 0.5)
			if buzz < 0.02:
				var benv := exp(-buzz * 50.0) * 0.25 * vol
				var bn := sin(buzz * 21000.0) * cos(buzz * 11000.0)
				s += bn * benv

		# HI-HAT — 8th notes in phase 0-1, 16ths in phase 2+
		var hh_interval := beat_s * 0.5 if phase < 2 else sixteenth
		var hh_grid := fmod(t, hh_interval)
		if hh_grid < 0.025:
			# Open hat on offbeats
			var hh_open := fmod(t, beat_s) > beat_s * 0.4
			var hh_decay := 60.0 if not hh_open else 12.0
			var hh_vol := 0.12 if not hh_open else 0.18
			var hhenv := exp(-hh_grid * hh_decay) * hh_vol * vol
			var hhn := sin(hh_grid * 29417.0) * cos(hh_grid * 15291.0)
			s += hhn * hhenv

		# TOMS — descending fills at bar boundaries
		if phase >= 1:
			var tom_bar := fmod(t, beat_s * 8.0)  # Every 2 bars
			if tom_bar > beat_s * 7.0:  # Last bar
				var tom_pos := tom_bar - beat_s * 7.0
				var tom_beat := int(tom_pos / (beat_s * 0.5))
				var tom_dt := fmod(tom_pos, beat_s * 0.5)
				if tom_dt < 0.1 and tom_beat < 8:
					var tf := 200.0 - float(tom_beat) * 18.0  # Descending pitch
					var tenv := exp(-tom_dt * 18.0) * 0.35 * vol
					s += sin(TAU * tf * tom_dt) * tenv

		# CRASH CYMBALS — phase transitions and finale
		var crash_times := [0.0, 2.5, 5.0, 7.5, 9.5]
		for ct in crash_times:
			var cdt: float = t - ct
			if cdt >= 0.0 and cdt < 0.8:
				var cenv := exp(-cdt * 3.5) * 0.25
				var cn := sin(cdt * 9731.0) * cos(cdt * 13917.0) * sin(cdt * 5391.0)
				s += cn * cenv

		# Master envelope
		var master := 1.0
		if t < 0.05: master = t / 0.05
		if t > 9.5: master = (ch_dur - t) / 0.5
		ch_samples[i] = clampf(s * master, -1.0, 1.0)
	_cheshire_sound = _samples_to_wav(ch_samples, ch_rate)
	_cheshire_player = AudioStreamPlayer.new()
	_cheshire_player.stream = _cheshire_sound
	_cheshire_player.volume_db = -2.0
	add_child(_cheshire_player)

	# Tea party — 3 ceramic clinks + pouring
	var tea_rate := 22050
	var tea_dur := 0.5
	var tea_samples := PackedFloat32Array()
	tea_samples.resize(int(tea_rate * tea_dur))
	var clink_times := [0.0, 0.12, 0.24]
	for i in tea_samples.size():
		var t := float(i) / tea_rate
		var s := 0.0
		for ct in clink_times:
			var dt: float = t - ct
			if dt >= 0.0 and dt < 0.1:
				var cenv := exp(-dt * 40.0) * 0.4
				s += sin(TAU * 3800.0 * dt) * cenv + sin(TAU * 5600.0 * dt) * cenv * 0.3
		# Pouring sound (filtered noise from 0.3s onward)
		if t > 0.3:
			var pt := t - 0.3
			s += sin(TAU * 1200.0 * pt) * (randf() * 0.3) * exp(-pt * 8.0) * 0.3
		tea_samples[i] = clampf(s, -1.0, 1.0)
	_tea_sound = _samples_to_wav(tea_samples, tea_rate)
	_tea_player = AudioStreamPlayer.new()
	_tea_player.stream = _tea_sound
	_tea_player.volume_db = -6.0
	add_child(_tea_player)

	# Upgrade chime
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
	_cheshire_flash = max(_cheshire_flash - delta * 2.0, 0.0)
	_tea_flash = max(_tea_flash - delta * 2.0, 0.0)
	_attack_anim = max(_attack_anim - delta * 3.0, 0.0)
	_execute_flash = max(_execute_flash - delta * 2.0, 0.0)
	_grow_burst = max(_grow_burst - delta * 0.5, 0.0)
	_roses_red_flash = max(_roses_red_flash - delta * 2.0, 0.0)
	_madness_flash = max(_madness_flash - delta * 1.5, 0.0)
	target = _find_nearest_enemy()

	if target:
		var desired = global_position.angle_to_point(target.global_position) + PI
		aim_angle = lerp_angle(aim_angle, desired, 12.0 * delta)
		if fire_cooldown <= 0.0:
			_shoot()
			fire_cooldown = 1.0 / (fire_rate * _speed_mult())

	# Tier 2: Cheshire Cat drum solo (10s duration, slows enemies in range)
	if _drum_solo_active:
		_drum_solo_timer -= delta
		_cheshire_flash = 0.8  # Keep grin visible during solo
		# Drum solo slows all enemies in range by 30%
		for e in get_tree().get_nodes_in_group("enemies"):
			if global_position.distance_to(e.global_position) < attack_range * _range_mult():
				if e.has_method("apply_slow"):
					e.apply_slow(0.3, 0.5)
		if _drum_solo_timer <= 0.0:
			_drum_solo_active = false

	# Bug 9: Recurring drum solo — cooldown ticks when solo is not active
	if upgrade_tier >= 2 and not _drum_solo_active:
		_drum_solo_cooldown_timer -= delta
		if _drum_solo_cooldown_timer <= 0.0 and _has_enemies_in_range():
			_start_drum_solo()
			_drum_solo_cooldown_timer = 20.0

	# Bug 10: Tea Party ongoing aura
	if _tea_aura_active:
		_apply_tea_party_aura()

	# Tier 4: Paint ALL enemies red — low DoT as they walk (Bug 6: cleaned up duplicate code)
	if _paint_red_active:
		_paint_red_timer -= delta
		if _paint_red_timer <= 0.0:
			_paint_red_timer = 1.0  # Tick every second
			var paint_dmg = damage * 0.15
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if enemy.has_method("take_damage"):
					enemy.take_damage(paint_dmg)
					register_damage(paint_dmg)
				if enemy.has_method("apply_paint"):
					enemy.apply_paint()
				if "painted_red" in enemy:
					enemy.painted_red = true

	_process_progressive_abilities(delta)
	queue_redraw()

func _has_enemies_in_range() -> bool:
	var eff_range = attack_range * _range_mult()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(enemy.global_position) < eff_range:
			return true
	return false

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

func _is_sfx_muted() -> bool:
	var main = get_tree().get_first_node_in_group("main")
	return main and main.get("sfx_muted") == true

func _shoot() -> void:
	if _attack_player and _attack_sounds.size() > 0 and not _is_sfx_muted():
		_attack_player.stream = _attack_sounds[_shot_count % _attack_sounds.size()]
		_attack_player.play()
	_shot_count += 1
	_attack_anim = 1.0
	# Cake splat — hits all enemies in range
	var dmg = damage * _damage_mult()
	if prog_abilities[0]:  # Curiouser: +20% damage
		dmg *= 1.2
	var eff_range = attack_range * _range_mult()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(enemy.global_position) <= eff_range:
			if enemy.has_method("apply_slow"):
				enemy.apply_slow(slow_amount, slow_duration)
			if enemy.has_method("take_damage"):
				enemy.take_damage(dmg, true)
				register_damage(dmg)
			# Tier 4: Execute enemies below threshold HP
			if execute_threshold > 0.0 and "health" in enemy and "max_health" in enemy:
				if enemy.health > 0.0 and enemy.health / enemy.max_health <= execute_threshold:
					var exec_dmg = enemy.health
					if enemy.has_method("take_damage"):
						enemy.take_damage(exec_dmg, true)
						register_damage(exec_dmg)
					_execute_flash = 1.0
			# Frosting DoT (Tier 1 upgrade)
			if frosting_dps > 0.0 and enemy.has_method("apply_dot"):
				enemy.apply_dot(frosting_dps, slow_duration)

func register_damage(amount: float) -> void:
	damage_dealt += amount
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("register_tower_damage"):
		main.register_tower_damage(main.TowerType.ALICE, amount)
	_check_upgrades()

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
	# Bug 2: Track boosts separately so tier upgrades can re-apply them
	var dmg_boost = 0.3
	var fr_boost = 0.05
	var range_boost = 4.0
	var slow_boost = min(slow_amount - 0.2, 0.02)  # How much we can reduce slow
	var dur_boost = 0.1
	var frost_boost = 0.12 if frosting_dps > 0.0 else 0.0
	var grow_boost = 0.06

	_progression_boosts["damage"] += dmg_boost
	_progression_boosts["fire_rate"] += fr_boost
	_progression_boosts["attack_range"] += range_boost
	_progression_boosts["slow_amount"] += slow_boost
	_progression_boosts["slow_duration"] += dur_boost
	_progression_boosts["frosting_dps"] += frost_boost
	_progression_boosts["grow_scale"] += grow_boost

	damage += dmg_boost
	fire_rate += fr_boost
	attack_range += range_boost
	slow_amount = max(slow_amount - 0.02, 0.2)
	slow_duration += dur_boost
	if frosting_dps > 0.0:
		frosting_dps += frost_boost
	# Alice grows! (capped at 2.0x to prevent screen overflow)
	_grow_scale = minf(_grow_scale + grow_boost, 2.0)
	_grow_burst = 0.3

func choose_ability(index: int) -> void:
	ability_chosen = true
	awaiting_ability_choice = false
	upgrade_tier = index + 1
	_apply_upgrade(upgrade_tier)
	_upgrade_flash = 3.0
	_upgrade_name = TIER_NAMES[index]

func _apply_upgrade(tier: int) -> void:
	match tier:
		1: # Eat Me Cake — stickier cake + frosting DoT
			slow_amount = 0.6  # Increased from 0.5
			slow_duration += 0.5
			frosting_dps = 1.5  # Frosting DoT unlocked
			attack_range = 85.0
			damage = 3.0
			fire_rate = 1.2
		2: # Cheshire Cat — 10 second drum solo
			damage = 4.0
			fire_rate = 1.4
			attack_range = 93.0
			cheshire_cooldown = 10.0
			gold_bonus = 2
			_start_drum_solo()
		3: # Mad Tea Party — nearby towers +3% fire rate
			damage = 5.0
			fire_rate = 1.6
			attack_range = 100.0
			gold_bonus = 3
			_tea_aura_active = true  # Bug 10: Enable ongoing aura instead of one-shot
		4: # Off With Their Heads! — paint enemies red, DoT, 5% execute
			damage = 7.0
			fire_rate = 1.8
			attack_range = 110.0
			gold_bonus = 4
			execute_threshold = 0.05  # Execute enemies below 5% HP
			_paint_red_active = true
	# Bug 2: Re-apply accumulated progression boosts after tier stat reset
	_reapply_progression_boosts()

var _paint_red_active: bool = false
var _paint_red_timer: float = 0.0
var _drum_solo_active: bool = false
var _drum_solo_timer: float = 0.0
var _drum_solo_cooldown_timer: float = 0.0  # Bug 9: recurring drum solo cooldown

# Bug 2: Track accumulated progression boosts separately so tier upgrades don't clobber them
var _progression_boosts: Dictionary = {
	"damage": 0.0,
	"fire_rate": 0.0,
	"attack_range": 0.0,
	"slow_amount": 0.0,
	"slow_duration": 0.0,
	"frosting_dps": 0.0,
	"grow_scale": 0.0,
}

# Bug 3: Painting the Roses Red timer (progressive ability 5)
var _roses_red_timer: float = 15.0
var _roses_red_flash: float = 0.0

# Bug 4: Wonderland Madness timer (progressive ability 9)
var _madness_timer: float = 18.0
var _madness_flash: float = 0.0

# Bug 10: Tea Party aura tracking
var _tea_aura_active: bool = false
var _tea_buffed_towers: Array = []

func _reapply_progression_boosts() -> void:
	damage += _progression_boosts["damage"]
	fire_rate += _progression_boosts["fire_rate"]
	attack_range += _progression_boosts["attack_range"]
	slow_amount = max(slow_amount - _progression_boosts["slow_amount"], 0.2)
	slow_duration += _progression_boosts["slow_duration"]
	if frosting_dps > 0.0:
		frosting_dps += _progression_boosts["frosting_dps"]
	# Reset grow_scale to base + accumulated boosts (don't double-apply)
	_grow_scale = 1.0 + _progression_boosts["grow_scale"]

func _start_drum_solo() -> void:
	_drum_solo_active = true
	_drum_solo_timer = 10.0
	_drum_solo_cooldown_timer = 20.0  # Bug 9: Reset cooldown for next recurrence
	_cheshire_flash = 1.0
	if _cheshire_player and not _is_sfx_muted():
		_cheshire_player.play()

func _apply_tea_party_aura() -> void:
	# Bug 10: Ongoing aura — buff towers in range, unbuff those that leave range
	var eff_range = attack_range * _range_mult()
	var currently_in_range: Array = []
	for tower in get_tree().get_nodes_in_group("towers"):
		if tower == self:
			continue
		if is_instance_valid(tower) and global_position.distance_to(tower.global_position) < eff_range:
			currently_in_range.append(tower)
			if not _tea_buffed_towers.has(tower):
				# New tower entered range — apply buff
				if "fire_rate" in tower:
					tower.fire_rate *= 1.05
				_tea_buffed_towers.append(tower)
	# Remove buff from towers that left range or were freed
	var still_buffed: Array = []
	for tower in _tea_buffed_towers:
		if is_instance_valid(tower) and currently_in_range.has(tower):
			still_buffed.append(tower)
		elif is_instance_valid(tower):
			# Tower left range — remove buff
			if "fire_rate" in tower:
				tower.fire_rate /= 1.05
	_tea_buffed_towers = still_buffed

func _cleanup_tea_party_aura() -> void:
	# Bug 10: Called when Alice is sold — remove all tea buffs
	for tower in _tea_buffed_towers:
		if is_instance_valid(tower) and "fire_rate" in tower:
			tower.fire_rate /= 1.05
	_tea_buffed_towers.clear()

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
	return "Alice"

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

func _exit_tree() -> void:
	# Bug 10: Clean up tea party aura buffs when Alice is removed/sold
	_cleanup_tea_party_aura()

func _generate_tier_sounds() -> void:
	var mix_rate := 44100
	_attack_sounds_by_tier = []

	# --- Tier 0: Acoustic Kick + Snare ---
	var t0 := []
	var samples := PackedFloat32Array()
	samples.resize(int(mix_rate * 0.15))
	for i in samples.size():
		var t := float(i) / mix_rate
		var freq := lerpf(146.83, 36.71, minf(t * 15.0, 1.0))  # D3 -> D1
		var env := exp(-t * 18.0)
		var click := exp(-t * 300.0) * 0.6
		samples[i] = clampf(sin(t * freq * TAU) * env * 0.8 + click, -1.0, 1.0)
	t0.append(_samples_to_wav(samples, mix_rate))
	samples = PackedFloat32Array()
	samples.resize(int(mix_rate * 0.12))
	for i in samples.size():
		var t := float(i) / mix_rate
		var body := sin(t * 146.83 * TAU) * exp(-t * 35.0) * 0.5  # D3
		var noise := (randf() * 2.0 - 1.0) * exp(-t * 20.0) * 0.55
		var snr_click := exp(-t * 400.0) * 0.3
		samples[i] = clampf(body + noise + snr_click, -1.0, 1.0)
	t0.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t0)

	# --- Tier 1: Tight Electronic Kick + Crisp Hi-Hat ---
	var t1 := []
	samples = PackedFloat32Array()
	samples.resize(int(mix_rate * 0.12))
	for i in samples.size():
		var t := float(i) / mix_rate
		var freq := lerpf(174.61, 36.71, minf(t * 25.0, 1.0))  # F3 -> D1
		var env := exp(-t * 25.0)
		var dist := clampf(sin(t * freq * TAU) * 1.5, -1.0, 1.0)
		var ek_click := exp(-t * 500.0) * 0.7
		samples[i] = clampf(dist * env * 0.7 + ek_click, -1.0, 1.0)
	t1.append(_samples_to_wav(samples, mix_rate))
	samples = PackedFloat32Array()
	samples.resize(int(mix_rate * 0.06))
	for i in samples.size():
		var t := float(i) / mix_rate
		var metal := sin(t * 6500.0 * TAU) * 0.3 + sin(t * 8300.0 * TAU) * 0.3
		metal += sin(t * 11500.0 * TAU) * 0.2
		var env := exp(-t * 60.0)
		var hh_noise := (randf() * 2.0 - 1.0) * 0.3 * exp(-t * 50.0)
		samples[i] = clampf((metal + hh_noise) * env, -1.0, 1.0)
	t1.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t1)

	# --- Tier 2: Deep Tom + Woodblock ---
	var t2 := []
	samples = PackedFloat32Array()
	samples.resize(int(mix_rate * 0.2))
	for i in samples.size():
		var t := float(i) / mix_rate
		var freq := lerpf(146.83, 73.42, minf(t * 10.0, 1.0))  # D3 -> D2
		var env := exp(-t * 12.0)
		var tom_body := sin(t * freq * TAU) * 0.7
		var overtone := sin(t * freq * 2.3 * TAU) * exp(-t * 20.0) * 0.3
		var head_slap := (randf() * 2.0 - 1.0) * exp(-t * 100.0) * 0.4
		samples[i] = clampf((tom_body + overtone) * env + head_slap, -1.0, 1.0)
	t2.append(_samples_to_wav(samples, mix_rate))
	samples = PackedFloat32Array()
	samples.resize(int(mix_rate * 0.08))
	for i in samples.size():
		var t := float(i) / mix_rate
		var fund := sin(t * 783.99 * TAU) * 0.5  # G5
		var h2 := sin(t * 783.99 * 2.7 * TAU) * 0.3
		var wb_env := exp(-t * 50.0)
		var wb_click := exp(-t * 300.0) * 0.5
		samples[i] = clampf((fund + h2) * wb_env + wb_click, -1.0, 1.0)
	t2.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t2)

	# --- Tier 3: 808 Kick + Handclap ---
	var t3 := []
	samples = PackedFloat32Array()
	samples.resize(int(mix_rate * 0.25))
	for i in samples.size():
		var t := float(i) / mix_rate
		var freq := lerpf(293.66, 36.71, minf(t * 30.0, 1.0))  # D4 -> D1
		var env := exp(-t * 8.0)
		var e_click := exp(-t * 200.0) * 0.6
		samples[i] = clampf(sin(t * freq * TAU) * env * 0.9 + e_click, -1.0, 1.0)
	t3.append(_samples_to_wav(samples, mix_rate))
	samples = PackedFloat32Array()
	samples.resize(int(mix_rate * 0.15))
	for i in samples.size():
		var t := float(i) / mix_rate
		var s := 0.0
		for c_off in [0.0, 0.008, 0.015]:
			var dt: float = t - c_off
			if dt >= 0.0:
				s += (randf() * 2.0 - 1.0) * exp(-dt * 40.0) * 0.4
		var clap_body := sin(t * 783.99 * TAU) * exp(-t * 30.0) * 0.2  # G5
		samples[i] = clampf(s + clap_body, -1.0, 1.0)
	t3.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t3)

	# --- Tier 4: Sub Boom + Electronic Crash Clap ---
	var t4 := []
	samples = PackedFloat32Array()
	samples.resize(int(mix_rate * 0.3))
	for i in samples.size():
		var t := float(i) / mix_rate
		var freq := lerpf(293.66, 36.71, minf(t * 20.0, 1.0))  # D4 -> D1
		var env := exp(-t * 5.0)
		var sub := sin(t * freq * TAU) * env * 0.8
		var harmonics := sin(t * freq * 2.0 * TAU) * exp(-t * 15.0) * 0.3
		var boom_click := exp(-t * 400.0) * 0.7
		var dist := clampf(sub * 1.8, -1.0, 1.0) * 0.6
		samples[i] = clampf(dist + harmonics * env + boom_click, -1.0, 1.0)
	t4.append(_samples_to_wav(samples, mix_rate))
	samples = PackedFloat32Array()
	samples.resize(int(mix_rate * 0.25))
	for i in samples.size():
		var t := float(i) / mix_rate
		var clap := 0.0
		for c_off in [0.0, 0.006, 0.012, 0.02]:
			var dt: float = t - c_off
			if dt >= 0.0:
				clap += (randf() * 2.0 - 1.0) * exp(-dt * 35.0) * 0.3
		var crash := sin(t * 5000.0 * TAU) * 0.15 + sin(t * 7200.0 * TAU) * 0.1
		crash += sin(t * 9800.0 * TAU) * 0.08
		var crash_env := exp(-t * 8.0)
		var cr_noise := (randf() * 2.0 - 1.0) * crash_env * 0.2
		samples[i] = clampf(clap + (crash + cr_noise) * crash_env, -1.0, 1.0)
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

func _load_progressive_abilities() -> void:
	var main = get_tree().get_first_node_in_group("main")
	if main and main.survivor_progress.has(main.TowerType.ALICE):
		var p = main.survivor_progress[main.TowerType.ALICE]
		var unlocked = p.get("abilities_unlocked", [])
		for i in range(mini(9, unlocked.size())):
			if unlocked[i]:
				activate_progressive_ability(i)

func activate_progressive_ability(index: int) -> void:
	if index < 0 or index >= 9:
		return
	prog_abilities[index] = true

func get_progressive_ability_name(index: int) -> String:
	if index >= 0 and index < PROG_ABILITY_NAMES.size():
		return PROG_ABILITY_NAMES[index]
	return ""

func get_progressive_ability_desc(index: int) -> String:
	if index >= 0 and index < PROG_ABILITY_DESCS.size():
		return PROG_ABILITY_DESCS[index]
	return ""

func _process_progressive_abilities(delta: float) -> void:
	_eat_me_flash = max(_eat_me_flash - delta * 2.0, 0.0)
	_jabberwock_flash = max(_jabberwock_flash - delta * 1.5, 0.0)
	_caterpillar_flash = max(_caterpillar_flash - delta * 2.0, 0.0)

	# Ability 2: Down the Rabbit Hole
	if prog_abilities[1]:
		_rabbit_hole_timer -= delta
		if _rabbit_hole_timer <= 0.0 and _has_enemies_in_range():
			_rabbit_hole()
			_rabbit_hole_timer = 20.0

	# Ability 3: Cheshire Grin — mark for 2x damage
	if prog_abilities[2]:
		_cheshire_grin_timer -= delta
		if _cheshire_grin_timer <= 0.0 and _has_enemies_in_range():
			_cheshire_grin()
			_cheshire_grin_timer = 10.0

	# Ability 4: Eat Me Cake — AoE stomp
	if prog_abilities[3]:
		_eat_me_timer -= delta
		if _eat_me_timer <= 0.0 and _has_enemies_in_range():
			_eat_me_stomp()
			_eat_me_timer = 15.0

	# Bug 3: Ability 5: Painting the Roses Red — paint enemies for +25% damage taken
	if prog_abilities[4]:
		_roses_red_timer -= delta
		if _roses_red_timer <= 0.0 and _has_enemies_in_range():
			_painting_roses_red()
			_roses_red_timer = 15.0

	# Ability 6: Caterpillar's Hookah — smoke slow
	if prog_abilities[5]:
		_caterpillar_timer -= delta
		if _caterpillar_timer <= 0.0 and _has_enemies_in_range():
			_caterpillar_smoke()
			_caterpillar_timer = 20.0

	# Ability 7: Tweedledee & Tweedledum — auto-attack nearby
	if prog_abilities[6]:
		_tweedle_timer -= delta
		if _tweedle_timer <= 0.0:
			_tweedle_attack()
			_tweedle_timer = 2.0

	# Ability 8: The Jabberwock — swoop damage (Bug 8: range-limited)
	if prog_abilities[7]:
		_jabberwock_timer -= delta
		if _jabberwock_timer <= 0.0 and _has_enemies_in_range():
			_jabberwock_swoop()
			_jabberwock_timer = 25.0

	# Bug 4: Ability 9: Wonderland Madness — confusion wave + damage
	if prog_abilities[8]:
		_madness_timer -= delta
		if _madness_timer <= 0.0 and _has_enemies_in_range():
			_wonderland_madness()
			_madness_timer = 18.0

func _rabbit_hole() -> void:
	var eff_range = attack_range * _range_mult()  # Bug 5: use _range_mult()
	var enemies = get_tree().get_nodes_in_group("enemies")
	var in_range: Array = []
	for e in enemies:
		if global_position.distance_to(e.global_position) < eff_range:
			in_range.append(e)
	if in_range.size() > 0:
		var picked = in_range[randi() % in_range.size()]
		picked.progress = max(0.0, picked.progress - 150.0)

func _cheshire_grin() -> void:
	var eff_range = attack_range * _range_mult()  # Bug 5: use _range_mult()
	var enemies = get_tree().get_nodes_in_group("enemies")
	var in_range: Array = []
	for e in enemies:
		if global_position.distance_to(e.global_position) < eff_range:
			in_range.append(e)
	if in_range.size() > 0:
		var picked = in_range[randi() % in_range.size()]
		if picked.has_method("apply_cheshire_mark"):
			picked.apply_cheshire_mark(5.0, 2.0)

func _eat_me_stomp() -> void:
	_eat_me_flash = 1.0
	var eff_range = attack_range * _range_mult()  # Bug 5: use _range_mult()
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) < eff_range:
			if e.has_method("take_damage"):
				var dmg = damage * 4.0
				e.take_damage(dmg, true)
				register_damage(dmg)

func _painting_roses_red() -> void:
	# Bug 3: Ability 5 implementation — paint nearby enemies red, +25% damage taken for 5s
	_roses_red_flash = 1.0
	var eff_range = attack_range * _range_mult()
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) < eff_range:
			# Apply 1.25x damage mark for 5 seconds (uses existing mark system)
			if e.has_method("apply_mark"):
				e.apply_mark(1.25, 5.0)
			# Paint them red visually
			if e.has_method("apply_paint"):
				e.apply_paint()
			if "painted_red" in e:
				e.painted_red = true

func _caterpillar_smoke() -> void:
	_caterpillar_flash = 1.0
	var eff_range = attack_range * _range_mult()  # Bug 5: use _range_mult()
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) < eff_range:
			if e.has_method("apply_slow"):
				e.apply_slow(0.2, 3.0)

func _tweedle_attack() -> void:
	var eff_range = attack_range * _range_mult() * 0.6  # Bug 5: use _range_mult()
	var enemies = get_tree().get_nodes_in_group("enemies")
	var in_range: Array = []
	for e in enemies:
		if global_position.distance_to(e.global_position) < eff_range:
			in_range.append(e)
	in_range.shuffle()
	for i in range(mini(2, in_range.size())):
		if in_range[i].has_method("take_damage"):
			var dmg = damage * 0.8
			in_range[i].take_damage(dmg, true)
			register_damage(dmg)

func _jabberwock_swoop() -> void:
	# Bug 8: Cap range to attack_range * _range_mult() * 3.0 instead of global nuke
	_jabberwock_flash = 1.0
	var eff_range = attack_range * _range_mult() * 3.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) < eff_range:
			if e.has_method("take_damage"):
				var dmg = damage * 5.0
				e.take_damage(dmg, true)
				register_damage(dmg)

func _wonderland_madness() -> void:
	# Bug 4: Ability 9 implementation — confusion wave + damage
	_madness_flash = 1.0
	var eff_range = attack_range * _range_mult() * 1.5
	var madness_dmg = attack_damage_for_madness() * 0.5
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) < eff_range:
			# Confusion: walk backwards for 3 seconds
			if e.has_method("apply_fear_reverse"):
				e.apply_fear_reverse(3.0)
			# Deal 50% of Alice's damage
			if e.has_method("take_damage"):
				e.take_damage(madness_dmg, true)
				register_damage(madness_dmg)

func attack_damage_for_madness() -> float:
	return damage * _damage_mult()

func _draw() -> void:
	# Selection ring (before grow transform)
	var eff_range = attack_range * _range_mult()
	if is_selected:
		var pulse = (sin(_time * 3.0) + 1.0) * 0.5
		var ring_alpha = 0.5 + pulse * 0.3
		draw_circle(Vector2.ZERO, eff_range, Color(1.0, 1.0, 1.0, 0.04))
		draw_arc(Vector2.ZERO, eff_range, 0, TAU, 64, Color(1.0, 0.84, 0.0, 0.25 + pulse * 0.15), 2.0)
		draw_arc(Vector2.ZERO, 40.0, 0, TAU, 48, Color(1.0, 0.84, 0.0, ring_alpha), 2.5)
		draw_arc(Vector2.ZERO, 43.0, 0, TAU, 48, Color(1.0, 0.84, 0.0, ring_alpha * 0.4), 1.5)
	else:
		draw_arc(Vector2.ZERO, eff_range, 0, TAU, 64, Color(1, 1, 1, 0.06), 1.0)

	# === PROGRESSIVE ABILITY EFFECTS ===
	if _eat_me_flash > 0.0:
		var em_r = 30.0 + (1.0 - _eat_me_flash) * 60.0
		draw_arc(Vector2.ZERO, em_r, 0, TAU, 24, Color(0.9, 0.5, 0.8, _eat_me_flash * 0.4), 3.0)

	if _jabberwock_flash > 0.0:
		draw_line(Vector2(-80, -40), Vector2(80, 40), Color(0.4, 0.7, 0.3, _jabberwock_flash * 0.5), 4.0)
		draw_line(Vector2(-70, -35), Vector2(70, 35), Color(0.5, 0.3, 0.6, _jabberwock_flash * 0.3), 2.0)

	if _caterpillar_flash > 0.0:
		draw_circle(Vector2.ZERO, 40.0, Color(0.5, 0.3, 0.7, _caterpillar_flash * 0.2))
		draw_circle(Vector2(10, 5), 30.0, Color(0.4, 0.2, 0.6, _caterpillar_flash * 0.15))

	# Bug 3: Painting the Roses Red flash effect
	if _roses_red_flash > 0.0:
		var rr_r = 25.0 + (1.0 - _roses_red_flash) * 50.0
		draw_arc(Vector2.ZERO, rr_r, 0, TAU, 24, Color(0.95, 0.15, 0.15, _roses_red_flash * 0.5), 3.5)
		draw_circle(Vector2.ZERO, rr_r * 0.5, Color(0.9, 0.1, 0.1, _roses_red_flash * 0.15))

	# Bug 4: Wonderland Madness flash effect
	if _madness_flash > 0.0:
		var md_r = 35.0 + (1.0 - _madness_flash) * 80.0
		draw_arc(Vector2.ZERO, md_r, 0, TAU, 32, Color(0.7, 0.2, 0.9, _madness_flash * 0.4), 4.0)
		draw_arc(Vector2.ZERO, md_r * 0.6, 0, TAU, 20, Color(0.5, 0.1, 0.8, _madness_flash * 0.2), 2.5)

	if prog_abilities[6]:  # Tweedledee & Tweedledum orbiting
		for ti in range(2):
			var ta = _time * 2.0 + float(ti) * PI
			var tpos = Vector2(cos(ta) * 25.0, sin(ta) * 15.0)
			draw_circle(tpos, 5.0, Color(0.8, 0.6, 0.4, 0.5))
			draw_circle(tpos, 3.5, Color(0.9, 0.7, 0.5, 0.6))

	# === STONE PLATFORM (Bloons-style, drawn before grow transform) ===
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
			0: pip_col = Color(0.4, 0.6, 0.95)
			1: pip_col = Color(0.7, 0.4, 0.85)
			2: pip_col = Color(0.95, 0.75, 0.3)
			3: pip_col = Color(0.95, 0.2, 0.2)
		draw_circle(pip_pos, 4.0, pip_col)
		draw_circle(pip_pos, 5.5, Color(pip_col.r, pip_col.g, pip_col.b, 0.15))

	# Apply grow scale — character scales with Alice's growth
	var total_scale = _grow_scale + _grow_burst
	draw_set_transform(Vector2.ZERO, 0, Vector2(total_scale, total_scale))

	# Growth burst sparkle effect
	if _grow_burst > 0.0:
		var burst_radius = 50.0 + _grow_burst * 60.0
		draw_circle(Vector2.ZERO, burst_radius, Color(0.9, 0.8, 1.0, _grow_burst * 0.25))
		for i in range(6):
			var spark_angle = TAU * float(i) / 6.0 + _time * 2.0
			var spark_pos = Vector2.from_angle(spark_angle) * burst_radius * 0.8
			draw_circle(spark_pos, 2.5, Color(1.0, 0.95, 0.6, _grow_burst * 0.5))

	var dir = Vector2.from_angle(aim_angle)
	var perp = dir.rotated(PI / 2.0)

	# Chibi idle animation with hip sway + breathing
	var bounce = abs(sin(_time * 2.5)) * 3.0
	var breathe = sin(_time * 2.0) * 1.5
	var dress_sway = sin(_time * 1.8) * 2.5
	var hip_sway = sin(_time * 1.8) * 2.5
	var chest_breathe = sin(_time * 2.0) * 1.0
	var body_offset = Vector2(sin(_time * 1.3) * 1.0, -bounce - breathe)
	# Hair physics — multi-frequency wind
	var hair_wind = sin(_time * 1.5) * 2.0 + sin(_time * 2.7) * 1.2 + sin(_time * 0.4) * 3.0 * clampf(sin(_time * 0.15), 0.0, 1.0)

	# Skin colors
	var skin_base = Color(0.95, 0.84, 0.73)
	var skin_shadow = Color(0.82, 0.70, 0.58)
	var skin_highlight = Color(0.98, 0.90, 0.80)

	# === Tier 4: Red glow aura ===
	if upgrade_tier >= 4:
		var aura_pulse = sin(_time * 3.0) * 0.04 + 0.15
		draw_circle(Vector2.ZERO, 60.0, Color(0.9, 0.15, 0.15, aura_pulse))
		draw_circle(Vector2.ZERO, 50.0, Color(0.95, 0.2, 0.1, aura_pulse * 0.5))
		# Red cake crumb particles orbiting
		for i in range(4):
			var crumb_a = _time * 1.2 + float(i) * TAU / 4.0
			var crumb_r = 55.0 + sin(_time * 2.0 + float(i)) * 4.0
			var cp = Vector2.from_angle(crumb_a) * crumb_r
			if i % 2 == 0:
				draw_circle(cp, 3.0, Color(0.95, 0.7, 0.75, 0.5))
				draw_circle(cp, 1.8, Color(1.0, 0.85, 0.88, 0.6))
			else:
				draw_circle(cp, 2.5, Color(0.85, 0.1, 0.15, 0.5))
				draw_circle(cp, 1.5, Color(0.95, 0.3, 0.35, 0.4))


	# Upgrade flash
	if _upgrade_flash > 0.0:
		draw_circle(Vector2.ZERO, 65.0 + _upgrade_flash * 18.0, Color(0.8, 0.7, 1.0, _upgrade_flash * 0.2))

	# Cheshire flash (purple grin expanding)
	if _cheshire_flash > 0.0:
		draw_arc(Vector2.ZERO, 35.0 + (1.0 - _cheshire_flash) * 40.0, 0.3, 2.8, 14, Color(0.7, 0.3, 0.8, _cheshire_flash * 0.5), 4.0)

	# Cheshire Cat grin during drum solo
	if _drum_solo_active:
		var grin_y = body_offset.y - 55.0 + sin(_time * 2.0) * 3.0
		var grin_x = body_offset.x + sin(_time * 1.5) * 5.0
		var grin_pos = Vector2(grin_x, grin_y)
		# Wide grin curve
		draw_arc(grin_pos, 10.0, 0.2, PI - 0.2, 12, Color(0.8, 0.2, 0.8, 0.7), 2.5)
		# Teeth
		for ti in range(5):
			var tx = grin_pos.x - 8.0 + float(ti) * 4.0
			draw_line(Vector2(tx, grin_pos.y + 2), Vector2(tx, grin_pos.y + 5), Color(1.0, 1.0, 1.0, 0.6), 1.5)
		# Eyes above grin
		draw_circle(grin_pos + Vector2(-6, -8), 2.5, Color(0.8, 0.2, 0.8, 0.5))
		draw_circle(grin_pos + Vector2(6, -8), 2.5, Color(0.8, 0.2, 0.8, 0.5))
		draw_circle(grin_pos + Vector2(-6, -8), 1.0, Color(1.0, 1.0, 0.0, 0.7))
		draw_circle(grin_pos + Vector2(6, -8), 1.0, Color(1.0, 1.0, 0.0, 0.7))

	# Tea party flash
	if _tea_flash > 0.0:
		draw_circle(Vector2.ZERO, 42.0 + (1.0 - _tea_flash) * 50.0, Color(0.9, 0.75, 0.3, _tea_flash * 0.25))

	if _tea_flash > 0.0:
		# Floating teacup
		var cup_pos = body_offset + Vector2(18, -15)
		var cup_alpha = _tea_flash * 0.6
		draw_arc(cup_pos, 5.0, PI, TAU, 8, Color(0.9, 0.85, 0.7, cup_alpha), 2.0)
		draw_line(cup_pos + Vector2(5, -2), cup_pos + Vector2(8, -5), Color(0.9, 0.85, 0.7, cup_alpha), 1.5)
		# Steam
		for si in range(3):
			var sy = cup_pos.y - 6.0 - float(si) * 4.0
			var sx = cup_pos.x + sin(_time * 3.0 + float(si)) * 2.0
			draw_circle(Vector2(sx, sy), 1.5 - float(si) * 0.3, Color(1.0, 1.0, 1.0, cup_alpha * (0.4 - float(si) * 0.1)))

	# T1+: Shrinking sparkles
	if upgrade_tier >= 1:
		for i in range(5):
			var sp_a = _time * 0.8 + float(i) * TAU / 5.0
			var sp_r = 40.0 + sin(_time * 1.5 + float(i) * 1.3) * 6.0
			var sp_pos = Vector2.from_angle(sp_a) * sp_r
			var sp_size = 2.0 + sin(_time * 3.0 + float(i) * 2.0) * 1.2
			var sp_alpha = 0.3 + sin(_time * 2.0 + float(i)) * 0.12
			draw_line(sp_pos - Vector2(sp_size, 0), sp_pos + Vector2(sp_size, 0), Color(0.6, 0.8, 1.0, sp_alpha), 0.8)
			draw_line(sp_pos - Vector2(0, sp_size), sp_pos + Vector2(0, sp_size), Color(0.6, 0.8, 1.0, sp_alpha), 0.8)

	# === CHARACTER POSITIONS (chibi proportions ~48px) ===
	var feet_y = body_offset + Vector2(hip_sway * 1.0, 10.0)
	var leg_top = body_offset + Vector2(hip_sway * 0.6, 0.0)
	var torso_center = body_offset + Vector2(hip_sway * 0.3, -8.0 - chest_breathe * 0.5)
	var neck_base = body_offset + Vector2(hip_sway * 0.15, -14.0 - chest_breathe * 0.3)
	var head_center = body_offset + Vector2(hip_sway * 0.08 + hair_wind * 0.1, -26.0)

	# === T1+: "Drink Me" bottle near platform ===
	if upgrade_tier >= 1:
		var bottle_pos = Vector2(-18, 6) + body_offset * 0.3
		draw_circle(bottle_pos + Vector2(0, -4), 5.0, Color(0.1, 0.2, 0.5))
		draw_circle(bottle_pos + Vector2(0, -4), 4.0, Color(0.25, 0.4, 0.8))
		draw_rect(Rect2(bottle_pos.x - 2, bottle_pos.y - 12, 4, 4), Color(0.6, 0.45, 0.25))
		draw_rect(Rect2(bottle_pos.x - 3, bottle_pos.y - 3, 6, 5), Color(0.95, 0.92, 0.85))

	# === CARTOON BODY WITH BOLD OUTLINES (Bloons-style) ===
	var OL = Color(0.06, 0.06, 0.08)  # True black outline color

	# --- Feet (cute ballet flats) ---
	var l_foot = feet_y + Vector2(-4, 0)
	var r_foot = feet_y + Vector2(4, 0)
	# Outline
	draw_circle(l_foot, 4.5, OL)
	draw_circle(r_foot, 4.5, OL)
	# Fill
	draw_circle(l_foot, 3.2, Color(0.78, 0.68, 0.92))
	draw_circle(r_foot, 3.2, Color(0.78, 0.68, 0.92))
	# Highlight dot
	draw_circle(l_foot + Vector2(-0.5, -0.8), 1.0, Color(0.92, 0.85, 1.0, 0.6))
	draw_circle(r_foot + Vector2(-0.5, -0.8), 1.0, Color(0.92, 0.85, 1.0, 0.6))

	# --- Legs (short stubby, mostly hidden by dress) ---
	draw_line(l_foot + Vector2(0, -2), Vector2(l_foot.x, leg_top.y + 2), OL, 5.0)
	draw_line(l_foot + Vector2(0, -2), Vector2(l_foot.x, leg_top.y + 2), skin_base, 3.5)
	draw_line(r_foot + Vector2(0, -2), Vector2(r_foot.x, leg_top.y + 2), OL, 5.0)
	draw_line(r_foot + Vector2(0, -2), Vector2(r_foot.x, leg_top.y + 2), skin_base, 3.5)

	# --- Alice's dress (Bloons-style bold cartoon) ---
	var dress_blue = Color(0.45, 0.72, 0.95)
	var dress_lav = Color(0.70, 0.55, 0.90)
	var dress_white = Color(0.92, 0.93, 0.98)
	# Dress outline (bold black border around entire dress shape)
	var dress_outline = PackedVector2Array([
		feet_y + Vector2(-15, 3), feet_y + Vector2(15 + dress_sway * 0.8, 1),
		Vector2(8, torso_center.y - 1), Vector2(8, neck_base.y + 3),
		Vector2(4, neck_base.y + 2), Vector2(0, neck_base.y + 3.5),
		Vector2(-4, neck_base.y + 2), Vector2(-8, neck_base.y + 3),
		Vector2(-8, torso_center.y - 1),
	])
	draw_colored_polygon(dress_outline, OL)
	# Dress fill — white base
	var dress_fill = PackedVector2Array([
		feet_y + Vector2(-13, 2), feet_y + Vector2(13 + dress_sway * 0.7, 0),
		Vector2(6.5, torso_center.y), Vector2(6.5, neck_base.y + 4.5),
		Vector2(3, neck_base.y + 3.5), Vector2(0, neck_base.y + 5),
		Vector2(-3, neck_base.y + 3.5), Vector2(-6.5, neck_base.y + 4.5),
		Vector2(-6.5, torso_center.y),
	])
	draw_colored_polygon(dress_fill, dress_white)
	# Blue apron/pinafore (Alice's signature look)
	var apron = PackedVector2Array([
		feet_y + Vector2(-10, 1), feet_y + Vector2(10 + dress_sway * 0.4, -1),
		Vector2(5.5, torso_center.y + 1), Vector2(5.5, neck_base.y + 6),
		Vector2(-5.5, neck_base.y + 6), Vector2(-5.5, torso_center.y + 1),
	])
	draw_colored_polygon(apron, dress_blue)
	# Apron pocket detail
	draw_arc(Vector2(0, torso_center.y + 5), 3.5, 0, PI, 6, Color(0.35, 0.60, 0.85), 1.5)
	# Waist sash (bold black line + white fill)
	draw_line(Vector2(-7, torso_center.y + 0.5), Vector2(7, torso_center.y + 0.5), OL, 4.0)
	draw_line(Vector2(-6.5, torso_center.y + 0.5), Vector2(6.5, torso_center.y + 0.5), Color(0.95, 0.95, 1.0), 2.5)
	# Sash bow at back (two circles + knot)
	draw_circle(Vector2(-7, torso_center.y + 1), 2.5, OL)
	draw_circle(Vector2(-7, torso_center.y + 1), 1.8, Color(0.95, 0.95, 1.0))
	# Hem scallops (cute wavy bottom edge)
	for i in range(7):
		var hx = -12.0 + float(i) * 4.0 + dress_sway * 0.15 * float(i) / 6.0
		var hy = feet_y.y + 2.0 + sin(_time * 2.0 + float(i) * 1.0) * 1.0
		draw_circle(Vector2(hx, hy), 2.5, OL)
		draw_circle(Vector2(hx, hy), 1.8, dress_white)
	# Cheshire grin pattern (T2+)
	if upgrade_tier >= 2:
		var grin_alpha = 0.1 + sin(_time * 1.5) * 0.04
		draw_arc(Vector2(0, torso_center.y + 6), 5.0, 0.3, PI - 0.3, 6, Color(0.6, 0.2, 0.7, grin_alpha), 1.5)

	# === Shoulders (round cartoon joints) ===
	var l_shoulder = Vector2(-8, neck_base.y + 2)
	var r_shoulder = Vector2(8, neck_base.y + 2)
	# Shoulder joints with outline
	draw_circle(l_shoulder, 4.5, OL)
	draw_circle(r_shoulder, 4.5, OL)
	draw_circle(l_shoulder, 3.2, skin_base)
	draw_circle(r_shoulder, 3.2, skin_base)
	# Puff sleeve hints (dress fabric on shoulders)
	draw_arc(l_shoulder, 4.0, PI * 0.5, PI * 1.5, 6, dress_blue, 2.0)
	draw_arc(r_shoulder, 4.0, PI * 1.5, PI * 2.5, 6, dress_blue, 2.0)

	# === Arms (chunky cartoon limbs with proper attack animation) ===
	var attack_extend = _attack_anim * 10.0
	# RIGHT ARM (cake-throwing) — swings toward target on attack
	var r_elbow = r_shoulder + dir * 6.0 + Vector2(3, 4)
	var r_hand = r_shoulder + dir * (14.0 + attack_extend)
	# Upper arm outline + fill
	draw_line(r_shoulder, r_elbow, OL, 6.5)
	draw_line(r_shoulder, r_elbow, skin_base, 4.5)
	# Forearm outline + fill
	draw_line(r_elbow, r_hand, OL, 6.0)
	draw_line(r_elbow, r_hand, skin_base, 4.0)
	# Elbow joint
	draw_circle(r_elbow, 3.5, OL)
	draw_circle(r_elbow, 2.5, skin_base)
	# Hand (round cartoon hand)
	draw_circle(r_hand, 3.5, OL)
	draw_circle(r_hand, 2.5, skin_base)
	draw_circle(r_hand + Vector2(-0.5, -0.5), 1.0, skin_highlight)

	# LEFT ARM (at side, slightly posed)
	var l_elbow = l_shoulder + Vector2(-5, 6)
	var l_hand = l_shoulder + Vector2(-7, 14)
	draw_line(l_shoulder, l_elbow, OL, 6.5)
	draw_line(l_shoulder, l_elbow, skin_base, 4.5)
	draw_line(l_elbow, l_hand, OL, 6.0)
	draw_line(l_elbow, l_hand, skin_base, 4.0)
	draw_circle(l_elbow, 3.5, OL)
	draw_circle(l_elbow, 2.5, skin_base)
	draw_circle(l_hand, 3.5, OL)
	draw_circle(l_hand, 2.5, skin_base)

	# === Cupcake in hand (bold, visible at any zoom) ===
	var cake_pos = r_hand + dir * 5.0
	var wrap_perp = dir.rotated(PI / 2.0)
	# Wrapper outline + fill (bright pink)
	draw_colored_polygon(PackedVector2Array([
		cake_pos - wrap_perp * 4.5 + dir * 2.0,
		cake_pos + wrap_perp * 4.5 + dir * 2.0,
		cake_pos + wrap_perp * 5.5 - dir * 2.0,
		cake_pos - wrap_perp * 5.5 - dir * 2.0,
	]), OL)
	draw_colored_polygon(PackedVector2Array([
		cake_pos - wrap_perp * 3.5 + dir * 1.5,
		cake_pos + wrap_perp * 3.5 + dir * 1.5,
		cake_pos + wrap_perp * 4.5 - dir * 1.5,
		cake_pos - wrap_perp * 4.5 - dir * 1.5,
	]), Color(1.0, 0.45, 0.60))
	# Frosted top — bold white dome
	var frost_center = cake_pos + dir * 3.0
	draw_circle(frost_center, 6.0, OL)
	draw_circle(frost_center, 4.8, Color(1.0, 0.92, 0.95))
	draw_circle(frost_center + dir * 0.5, 3.5, Color(1.0, 0.80, 0.85))
	# Cherry on top
	draw_circle(frost_center + dir * 4.0, 2.8, OL)
	draw_circle(frost_center + dir * 4.0, 2.0, Color(0.95, 0.12, 0.18))
	draw_circle(frost_center + dir * 4.0 + Vector2(-0.4, -0.5), 0.8, Color(1.0, 0.5, 0.5, 0.6))

	# Cake splat ring (AoE attack flash)
	if _attack_anim > 0.2:
		var splat_r = 20.0 + (1.0 - _attack_anim) * 40.0
		var splat_alpha = _attack_anim * 0.5
		draw_arc(Vector2.ZERO, splat_r, 0, TAU, 32, Color(0.95, 0.7, 0.75, splat_alpha), 3.0)
		draw_arc(Vector2.ZERO, splat_r * 0.7, 0, TAU, 24, Color(1.0, 0.9, 0.92, splat_alpha * 0.6), 2.0)
		for si in range(6):
			var sp_a = TAU * float(si) / 6.0 + _time * 2.0
			var sp_r2 = splat_r * (0.6 + sin(_time * 4.0 + float(si)) * 0.2)
			var sp_p = Vector2.from_angle(sp_a) * sp_r2
			draw_circle(sp_p, 2.5, Color(0.95, 0.8, 0.85, splat_alpha * 0.7))

	# === NECK (cartoon connector) ===
	var neck_top = head_center + Vector2(0, 9)
	draw_line(neck_base, neck_top, OL, 7.0)
	draw_line(neck_base, neck_top, skin_base, 5.0)

	# === HEAD — Big round cartoon head ===
	var hair_wave = sin(_time * 1.5) * 3.0 + hair_wind
	var hair_base = Color(0.85, 0.72, 0.28)
	var hair_light = Color(0.95, 0.85, 0.40)
	var hair_shine = Color(1.0, 0.95, 0.55)

	# --- Hair back (drawn behind face) ---
	# Back hair outline + fill
	draw_circle(head_center + Vector2(-10, 14), 6.0, OL)
	draw_circle(head_center + Vector2(-10, 14), 4.8, hair_base)
	draw_circle(head_center + Vector2(10, 14), 6.0, OL)
	draw_circle(head_center + Vector2(10, 14), 4.8, hair_base)
	draw_circle(head_center + Vector2(-9, 22), 5.0, OL)
	draw_circle(head_center + Vector2(-9, 22), 3.8, hair_light)
	draw_circle(head_center + Vector2(9, 22), 5.0, OL)
	draw_circle(head_center + Vector2(9, 22), 3.8, hair_light)

	# --- Main head shape (big circle) ---
	# Hair volume outline
	draw_circle(head_center, 14.0, OL)
	draw_circle(head_center, 12.5, hair_base)
	draw_circle(head_center + Vector2(0, -1), 11.5, hair_light)
	# Side hair volume
	draw_circle(head_center + Vector2(-12, 4), 6.5, OL)
	draw_circle(head_center + Vector2(-12, 4), 5.2, hair_base)
	draw_circle(head_center + Vector2(12, 4), 6.5, OL)
	draw_circle(head_center + Vector2(12, 4), 5.2, hair_base)
	# Crown shine
	draw_circle(head_center + Vector2(-2, -4), 5.5, Color(hair_shine.r, hair_shine.g, hair_shine.b, 0.4))
	# Hair shine arc
	draw_arc(head_center + Vector2(0, -2), 10.0, PI * 0.5, PI * 0.9, 8, Color(1.0, 0.96, 0.60, 0.45), 3.0)
	# Strand detail (just a few bold lines for texture)
	for si in range(4):
		var sx = -8.0 + float(si) * 5.5
		var wave_off = hair_wave * (1.0 if sx > 0 else -1.0) * 0.25
		var s_start = head_center + Vector2(sx, 4)
		var s_end = head_center + Vector2(sx + wave_off, 20.0 + float(si % 2) * 3.0)
		draw_line(s_start, s_end, hair_base, 2.0)

	# --- Face (big round cartoon face) ---
	draw_circle(head_center + Vector2(0, 1.5), 12.0, OL)
	draw_circle(head_center + Vector2(0, 1.5), 10.8, skin_base)
	# Face highlight (top-left shine like Bloons)
	draw_circle(head_center + Vector2(-3, -2), 5.0, Color(skin_highlight.r, skin_highlight.g, skin_highlight.b, 0.3))

	# Rosy cheeks (Alice's signature — bold pink)
	draw_circle(head_center + Vector2(-6.5, 4), 3.0, Color(1.0, 0.50, 0.50, 0.30))
	draw_circle(head_center + Vector2(6.5, 4), 3.0, Color(1.0, 0.50, 0.50, 0.30))

	# Ears (behind hair)
	draw_circle(head_center + Vector2(-10.5, 2), 2.8, OL)
	draw_circle(head_center + Vector2(-10.5, 2), 2.0, skin_base)
	draw_circle(head_center + Vector2(10.5, 2), 2.8, OL)
	draw_circle(head_center + Vector2(10.5, 2), 2.0, skin_base)

	# Flower behind ear (signature accessory)
	var flower_pos = head_center + Vector2(-11, -3)
	draw_circle(flower_pos, 4.0, OL)
	draw_circle(flower_pos, 3.2, Color(1.0, 0.65, 0.75))
	for petal_i in range(5):
		var pa = float(petal_i) * TAU / 5.0 + _time * 0.3
		draw_circle(flower_pos + Vector2.from_angle(pa) * 2.5, 1.8, Color(1.0, 0.55, 0.68))
	draw_circle(flower_pos, 1.5, Color(1.0, 0.92, 0.35))

	# === BIG CARTOON EYES (Bloons-style — large, expressive, clean) ===
	var look_dir = dir * 1.2
	var l_eye = head_center + Vector2(-4.5, 0.5)
	var r_eye = head_center + Vector2(4.5, 0.5)
	# Eye outlines (thick black border)
	draw_circle(l_eye, 5.8, OL)
	draw_circle(r_eye, 5.8, OL)
	# Eye whites
	draw_circle(l_eye, 4.8, Color(1.0, 1.0, 1.0))
	draw_circle(r_eye, 4.8, Color(1.0, 1.0, 1.0))
	# Blue irises (Alice's signature blue — bold saturated)
	draw_circle(l_eye + look_dir, 3.5, Color(0.12, 0.35, 0.70))
	draw_circle(l_eye + look_dir, 2.8, Color(0.25, 0.50, 0.90))
	draw_circle(r_eye + look_dir, 3.5, Color(0.12, 0.35, 0.70))
	draw_circle(r_eye + look_dir, 2.8, Color(0.25, 0.50, 0.90))
	# Pupils (solid black dots)
	draw_circle(l_eye + look_dir * 1.05, 1.6, Color(0.02, 0.02, 0.05))
	draw_circle(r_eye + look_dir * 1.05, 1.6, Color(0.02, 0.02, 0.05))
	# Big sparkle highlights (key Bloons detail — makes eyes feel alive)
	draw_circle(l_eye + Vector2(-1.3, -1.6), 1.8, Color(1.0, 1.0, 1.0, 0.95))
	draw_circle(r_eye + Vector2(-1.3, -1.6), 1.8, Color(1.0, 1.0, 1.0, 0.95))
	# Small secondary sparkle
	draw_circle(l_eye + Vector2(1.2, 1.0), 0.9, Color(1.0, 1.0, 1.0, 0.55))
	draw_circle(r_eye + Vector2(1.2, 1.0), 0.9, Color(1.0, 1.0, 1.0, 0.55))
	# Bold upper eyelid line
	draw_arc(l_eye, 5.2, PI + 0.15, TAU - 0.15, 10, OL, 1.8)
	draw_arc(r_eye, 5.2, PI + 0.15, TAU - 0.15, 10, OL, 1.8)
	# Eyelashes (3 bold lashes per eye)
	for el in range(3):
		var ela = PI + 0.25 + float(el) * 0.45
		draw_line(l_eye + Vector2.from_angle(ela) * 5.2, l_eye + Vector2.from_angle(ela + 0.12) * 8.0, OL, 1.5)
		draw_line(r_eye + Vector2.from_angle(ela) * 5.2, r_eye + Vector2.from_angle(ela + 0.12) * 8.0, OL, 1.5)

	# Eyebrows (bold, expressive arches)
	draw_line(l_eye + Vector2(-3.5, -5), l_eye + Vector2(2.5, -6.5), Color(0.60, 0.48, 0.15), 2.2)
	draw_line(r_eye + Vector2(-2.5, -6.5), r_eye + Vector2(3.5, -5), Color(0.60, 0.48, 0.15), 2.2)

	# Cute button nose
	draw_circle(head_center + Vector2(0, 4), 1.5, Color(0.92, 0.78, 0.66, 0.6))
	draw_circle(head_center + Vector2(0.3, 3.8), 0.7, skin_highlight)

	# Cheerful smile (simple arc — Bloons style)
	draw_arc(head_center + Vector2(0, 6), 4.0, 0.15, PI - 0.15, 10, OL, 1.8)
	draw_arc(head_center + Vector2(0, 6), 3.5, 0.2, PI - 0.2, 8, Color(0.90, 0.40, 0.40), 1.2)

	# === Alice's Headband (black with bow — signature look) ===
	draw_arc(head_center + Vector2(0, -2), 12.0, PI + 0.25, TAU - 0.25, 14, OL, 4.0)
	draw_arc(head_center + Vector2(0, -2), 12.0, PI + 0.25, TAU - 0.25, 14, Color(0.10, 0.10, 0.15), 2.5)
	# Headband bow (right side — bold)
	var bow_ctr = head_center + Vector2(7, -10)
	draw_circle(bow_ctr + Vector2(-2.5, 0), 2.8, OL)
	draw_circle(bow_ctr + Vector2(2.5, 0), 2.8, OL)
	draw_circle(bow_ctr + Vector2(-2.5, 0), 2.0, Color(0.10, 0.10, 0.15))
	draw_circle(bow_ctr + Vector2(2.5, 0), 2.0, Color(0.10, 0.10, 0.15))
	draw_circle(bow_ctr, 1.5, OL)
	draw_circle(bow_ctr, 1.0, Color(0.15, 0.15, 0.20))

	# === T2+: Floating Cheshire Cat grin ===
	if upgrade_tier >= 2:
		var grin_float = sin(_time * 2.2) * 5.0
		var grin_bob = cos(_time * 1.7) * 3.5
		var grin_pos = body_offset + Vector2(28.0 + grin_bob, -8.0 + grin_float)
		# Fading body outline (ghostly stripes)
		var gbody_alpha = 0.12 + sin(_time * 1.5) * 0.04
		draw_arc(grin_pos, 14.0, PI * 0.1, PI * 0.9, 10, Color(0.6, 0.3, 0.7, gbody_alpha), 1.5)
		for gsi in range(3):
			var gs_a = PI * 0.25 + float(gsi) * 0.25
			var gs_s = grin_pos + Vector2.from_angle(gs_a) * 10.0
			var gs_e = grin_pos + Vector2.from_angle(gs_a) * 16.0
			draw_line(gs_s, gs_e, Color(0.55, 0.25, 0.65, gbody_alpha * 0.6), 1.5)
		# Grin arc (wide purple smile)
		draw_arc(grin_pos, 10.0, 0.2, PI - 0.2, 14, Color(0.7, 0.3, 0.8, 0.7), 3.5)
		draw_arc(grin_pos, 8.0, 0.3, PI - 0.3, 10, Color(0.85, 0.4, 0.55, 0.25), 2.0)
		# Teeth
		for gti in range(6):
			var tooth_a = 0.3 + float(gti) * 0.4
			var tooth_s = grin_pos + Vector2.from_angle(tooth_a) * 7.5
			var tooth_e = grin_pos + Vector2.from_angle(tooth_a) * 12.0
			draw_line(tooth_s, tooth_e, Color(0.97, 0.97, 0.92, 0.55), 1.8)
		# Cheshire eyes (glowing yellow-green)
		var eye_glow = 0.5 + sin(_time * 3.0) * 0.1
		draw_circle(grin_pos + Vector2(-6, -7), 3.5, Color(0.85, 0.8, 0.2, eye_glow))
		draw_circle(grin_pos + Vector2(6, -7), 3.5, Color(0.85, 0.8, 0.2, eye_glow))
		draw_circle(grin_pos + Vector2(-6, -7), 2.0, Color(0.95, 0.9, 0.3, eye_glow * 0.5))
		draw_circle(grin_pos + Vector2(6, -7), 2.0, Color(0.95, 0.9, 0.3, eye_glow * 0.5))
		# Cat eye slits
		draw_line(grin_pos + Vector2(-6, -9), grin_pos + Vector2(-6, -5), Color(0.15, 0.08, 0.2, eye_glow), 1.5)
		draw_line(grin_pos + Vector2(6, -9), grin_pos + Vector2(6, -5), Color(0.15, 0.08, 0.2, eye_glow), 1.5)
		# Whiskers
		draw_line(grin_pos + Vector2(10, -4), grin_pos + Vector2(16, -2), Color(0.6, 0.3, 0.7, 0.15), 0.7)
		draw_line(grin_pos + Vector2(10, -6), grin_pos + Vector2(16, -7), Color(0.6, 0.3, 0.7, 0.15), 0.7)
		draw_line(grin_pos + Vector2(-10, -4), grin_pos + Vector2(-16, -2), Color(0.6, 0.3, 0.7, 0.15), 0.7)
		draw_line(grin_pos + Vector2(-10, -6), grin_pos + Vector2(-16, -7), Color(0.6, 0.3, 0.7, 0.15), 0.7)

	# === T3+: Orbiting teacups with steam ===
	if upgrade_tier >= 3:
		for cup_i in range(3):
			var cup_angle = _time * 0.6 + float(cup_i) * TAU / 3.0
			var cup_r = 38.0 + sin(_time * 1.2 + float(cup_i)) * 4.0
			var cup_pos = Vector2.from_angle(cup_angle) * cup_r
			var cup_bob = sin(_time * 2.0 + float(cup_i) * 1.5) * 2.5
			cup_pos.y += cup_bob
			# Saucer
			draw_arc(cup_pos + Vector2(0, 3), 8.0, 0.2, PI - 0.2, 8, Color(0.88, 0.85, 0.78), 2.0)
			# Cup body
			draw_arc(cup_pos, 6.0, 0.4, PI - 0.4, 8, Color(0.92, 0.88, 0.78), 3.0)
			draw_line(cup_pos + Vector2.from_angle(0.5) * 6.0, cup_pos + Vector2.from_angle(PI - 0.5) * 6.0, Color(0.92, 0.88, 0.78), 1.5)
			# Tea inside
			draw_arc(cup_pos + Vector2(0, -1), 4.0, 0.6, PI - 0.6, 6, Color(0.6, 0.38, 0.18, 0.5), 2.0)
			# Handle
			draw_arc(cup_pos + Vector2(7, 0), 3.0, -PI * 0.4, PI * 0.4, 6, Color(0.88, 0.85, 0.78), 1.5)
			# Gold rim
			draw_arc(cup_pos, 6.5, 0.35, PI - 0.35, 6, Color(0.85, 0.75, 0.3, 0.35), 0.8)
			# Steam wisps
			for stm in range(2):
				var steam_off = sin(_time * 2.0 + float(cup_i) * 2.0 + float(stm) * 1.5) * 2.5
				var steam_p = cup_pos + Vector2(steam_off, -10.0 - float(stm) * 5.0)
				draw_circle(steam_p, 2.5 - float(stm) * 0.4, Color(0.92, 0.92, 0.95, 0.25 - float(stm) * 0.08))

	# === Tier 4: Crown floating above head ===
	if upgrade_tier >= 4:
		var crown_hover = sin(_time * 1.8) * 1.5
		var crown_center = head_center + Vector2(0, -12 + crown_hover)
		var crown_r = 12.0
		# Golden band
		draw_arc(crown_center, crown_r, 0, TAU, 20, Color(0.95, 0.82, 0.2), 3.5)
		draw_arc(crown_center, crown_r + 1.2, 0, TAU, 20, Color(0.85, 0.72, 0.15, 0.35), 0.8)
		draw_arc(crown_center, crown_r - 1.2, 0, TAU, 20, Color(1.0, 0.92, 0.4, 0.25), 0.8)
		# Crown spikes with suit gems
		for csi in range(5):
			var ca = PI * 0.5 + (float(csi) - 2.0) * 0.35
			var spike_base_pos = crown_center + Vector2.from_angle(ca) * (crown_r - 1.5)
			var spike_tip = crown_center + Vector2.from_angle(ca) * (crown_r + 10.0)
			draw_line(spike_base_pos, spike_tip, Color(0.95, 0.82, 0.2), 3.0)
			draw_line(spike_base_pos + Vector2.from_angle(ca + PI * 0.5) * 2.5, spike_tip, Color(0.95, 0.82, 0.2), 1.2)
			draw_line(spike_base_pos - Vector2.from_angle(ca + PI * 0.5) * 2.5, spike_tip, Color(0.95, 0.82, 0.2), 1.2)
			var suit_col = Color(0.95, 0.15, 0.15) if csi % 2 == 0 else Color(0.1, 0.1, 0.12)
			draw_circle(spike_tip, 2.8, suit_col)
			draw_circle(spike_tip + Vector2(-0.5, -0.5), 1.0, Color(1.0, 0.8, 0.8, 0.4) if csi % 2 == 0 else Color(0.45, 0.45, 0.5, 0.4))
		# Band jewels
		for ji in range(6):
			var ja = TAU * float(ji) / 6.0
			var jp = crown_center + Vector2.from_angle(ja) * crown_r
			draw_circle(jp, 1.5, Color(0.9, 0.15, 0.15, 0.5) if ji % 2 == 0 else Color(0.2, 0.5, 0.9, 0.5))

	# Reset transform for UI text
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	# Awaiting ability choice indicator
	if awaiting_ability_choice:
		var pulse = (sin(_time * 4.0) + 1.0) * 0.5
		draw_circle(Vector2.ZERO, 60.0 + pulse * 6.0, Color(0.8, 0.7, 1.0, 0.1 + pulse * 0.1))
		draw_arc(Vector2.ZERO, 60.0 + pulse * 6.0, 0, TAU, 32, Color(0.8, 0.7, 1.0, 0.3 + pulse * 0.3), 2.5)
		var font3 = _game_font
		draw_string(font3, Vector2(-16, -68), "!", HORIZONTAL_ALIGNMENT_CENTER, 32, 30, Color(0.8, 0.7, 1.0, 0.7 + pulse * 0.3))

	# Damage dealt counter
	if damage_dealt > 0:
		var font = _game_font
		var dmg_text = str(int(damage_dealt)) + " DMG"
		if stat_upgrade_level > 0:
			dmg_text += " • Lv." + str(stat_upgrade_level)
		draw_string(font, Vector2(-36, 56), dmg_text, HORIZONTAL_ALIGNMENT_LEFT, 160, 12, Color(1.0, 0.84, 0.0, 0.5))

	# Upgrade name flash
	if _upgrade_flash > 0.0 and _upgrade_name != "":
		var font2 = _game_font
		draw_string(font2, Vector2(-80, -60), _upgrade_name, HORIZONTAL_ALIGNMENT_CENTER, 160, 16, Color(0.8, 0.7, 1.0, min(_upgrade_flash, 1.0)))

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

func has_synergy_buff() -> bool:
	return not _synergy_buffs.is_empty()

var power_damage_mult: float = 1.0

func _damage_mult() -> float:
	return (1.0 + _synergy_buffs.get("damage", 0.0) + _meta_buffs.get("damage", 0.0)) * power_damage_mult

func _range_mult() -> float:
	return 1.0 + _synergy_buffs.get("range", 0.0) + _meta_buffs.get("range", 0.0)

func _speed_mult() -> float:
	return 1.0 + _synergy_buffs.get("attack_speed", 0.0) + _meta_buffs.get("attack_speed", 0.0)

func _gold_mult() -> float:
	return 1.0 + _synergy_buffs.get("gold_bonus", 0.0) + _meta_buffs.get("gold_bonus", 0.0)
