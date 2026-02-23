extends Node2D
## The Phantom of the Opera — single-target control tower from Gaston Leroux (1910).
## Throws music notes (heavy damage). Upgrades by dealing damage.
## Tier 1 (5000 DMG): "Punjab Lasso" — periodically stuns closest enemy for 2.5s
## Tier 2 (10000 DMG): "Angel of Music" — passive slow aura on enemies in range
## Tier 3 (15000 DMG): "Chandelier" — periodic AoE burst (2x damage to all in range)
## Tier 4 (20000 DMG): "Phantom's Wrath" — notes apply DoT, all stats boosted

var damage: float = 35.0
var fire_rate: float = 0.5
var attack_range: float = 180.0
var fire_cooldown: float = 0.0
var aim_angle: float = 0.0
var target: Node2D = null
var gold_bonus: int = 2

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

# === PROGRESSIVE ABILITIES (9 tiers, unlocked via lifetime damage) ===
const PROG_ABILITY_NAMES = [
	"Music of the Night", "The Red Death", "Christine's Aria", "The Trap Door",
	"Box Five", "The Underground Lake", "Requiem Mass",
	"The Organ's Fury", "Beneath the Opera"
]
const PROG_ABILITY_DESCS = [
	"Notes glow brighter, +20% damage",
	"Every 15s, Red Death mask burst fears enemies — they walk backwards for 2s",
	"Every 18s, Christine sings, charming 3 enemies — stopped + 2x damage for 4s",
	"Every 20s, trapdoor on path — instant kill normal, 50% HP boss",
	"Every 15s, spectral opera box rains rose petals dealing AoE damage for 5s",
	"Every 18s, water rises, all enemies slowed to 40% for 3s",
	"Every 20s, ghostly choir stuns ALL enemies on screen for 2s",
	"Every 25s, great organ plays — 3x damage + 2s stun to EVERY enemy",
	"Notes seek enemies across entire map. All enemies permanently 30% slower"
]
var prog_abilities: Array = [false, false, false, false, false, false, false, false, false]
# Ability timers
var _red_death_timer: float = 15.0
var _christines_aria_timer: float = 18.0
var _trap_door_timer: float = 20.0
var _box_five_timer: float = 15.0
var _box_five_active: float = 0.0
var _underground_lake_timer: float = 18.0
var _requiem_mass_timer: float = 20.0
var _organs_fury_timer: float = 25.0
# Visual flash timers
var _red_death_flash: float = 0.0
var _christines_aria_flash: float = 0.0
var _trap_door_flash: float = 0.0
var _box_five_flash: float = 0.0
var _underground_lake_flash: float = 0.0
var _requiem_mass_flash: float = 0.0
var _organs_fury_flash: float = 0.0
var _beneath_opera_flash: float = 0.0

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
const TIER_COSTS = [85, 190, 325, 525]
var is_selected: bool = false
var base_cost: int = 0

var note_scene = preload("res://scenes/phantom_note.tscn")

# Attack sounds — organ melody evolving with upgrade tier
var _attack_sounds: Array = []
var _attack_sounds_by_tier: Array = []
var _attack_player: AudioStreamPlayer

# Ability sounds
var _lasso_sound: AudioStreamWAV
var _lasso_player: AudioStreamPlayer
var _chandelier_sound: AudioStreamWAV
var _chandelier_player: AudioStreamPlayer
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

	# Punjab lasso — rope swoosh + sharp crack
	var ls_rate := 22050
	var ls_dur := 0.25
	var ls_samples := PackedFloat32Array()
	ls_samples.resize(int(ls_rate * ls_dur))
	for i in ls_samples.size():
		var t := float(i) / ls_rate
		var s := 0.0
		# Swoosh (noise sweep 0-0.15s)
		if t < 0.15:
			var sweep := sin(TAU * lerpf(200.0, 800.0, t / 0.15) * t) * 0.3
			s += (sweep + (randf() * 2.0 - 1.0) * 0.15) * (1.0 - t / 0.15)
		# Sharp crack at 0.15s
		var crack_dt := t - 0.15
		if crack_dt >= 0.0 and crack_dt < 0.06:
			s += (randf() * 2.0 - 1.0) * exp(-crack_dt * 60.0) * 0.7
		ls_samples[i] = clampf(s, -1.0, 1.0)
	_lasso_sound = _samples_to_wav(ls_samples, ls_rate)
	_lasso_player = AudioStreamPlayer.new()
	_lasso_player.stream = _lasso_sound
	_lasso_player.volume_db = -6.0
	add_child(_lasso_player)

	# Chandelier — chain creak + glass shatter + metallic thud
	var cd_rate := 22050
	var cd_dur := 0.7
	var cd_samples := PackedFloat32Array()
	cd_samples.resize(int(cd_rate * cd_dur))
	for i in cd_samples.size():
		var t := float(i) / cd_rate
		var s := 0.0
		# Chain creak (0-0.2s) — metallic groan
		if t < 0.2:
			var creak_freq := 180.0 + sin(TAU * 3.0 * t) * 60.0
			s += sin(TAU * creak_freq * t) * 0.3 * (1.0 - t / 0.2)
		# Glass shatter (0.2-0.5s) — high noise burst
		var sh_dt := t - 0.2
		if sh_dt >= 0.0 and sh_dt < 0.3:
			var glass := (randf() * 2.0 - 1.0) * exp(-sh_dt * 8.0) * 0.5
			var tinkle := sin(TAU * 4500.0 * sh_dt) * exp(-sh_dt * 15.0) * 0.3
			s += glass + tinkle
		# Metallic thud (0.25s) — low impact
		var thud_dt := t - 0.25
		if thud_dt >= 0.0 and thud_dt < 0.15:
			s += sin(TAU * 80.0 * thud_dt) * exp(-thud_dt * 20.0) * 0.4
		cd_samples[i] = clampf(s, -1.0, 1.0)
	_chandelier_sound = _samples_to_wav(cd_samples, cd_rate)
	_chandelier_player = AudioStreamPlayer.new()
	_chandelier_player.stream = _chandelier_sound
	_chandelier_player.volume_db = -6.0
	add_child(_chandelier_player)

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
			fire_cooldown = 1.0 / (fire_rate * _speed_mult())

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

	# Progressive abilities
	_process_progressive_abilities(delta)

	queue_redraw()

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
	var search_range: float = attack_range * _range_mult()
	# Ability 9: Beneath the Opera — unlimited range
	if prog_abilities[8]:
		search_range = 999999.0
	var nearest_dist: float = search_range
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
	var note = note_scene.instantiate()
	note.global_position = global_position + Vector2.from_angle(aim_angle) * 32.0
	# Ability 1: Music of the Night — +20% damage
	var shoot_damage = damage * _damage_mult()
	if prog_abilities[0]:
		shoot_damage *= 1.2
	note.damage = shoot_damage
	note.target = target
	note.gold_bonus = int(gold_bonus * _gold_mult())
	note.source_tower = self
	note.dot_dps = note_dot_dps
	note.dot_duration = note_dot_duration
	get_tree().get_first_node_in_group("main").add_child(note)
	_attack_anim = 1.0

func _punjab_lasso() -> void:
	if _lasso_player and not _is_sfx_muted(): _lasso_player.play()
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
	if _chandelier_player and not _is_sfx_muted(): _chandelier_player.play()
	_chandelier_flash = 1.5
	var chandelier_dmg = damage * 2.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(enemy.global_position) < attack_range:
			if enemy.has_method("take_damage"):
				var will_kill = enemy.health - chandelier_dmg <= 0.0
				enemy.take_damage(chandelier_dmg, true)
				register_damage(chandelier_dmg)
				if will_kill:
					if gold_bonus > 0:
						var main = get_tree().get_first_node_in_group("main")
						if main:
							main.add_gold(gold_bonus)

func register_damage(amount: float) -> void:
	damage_dealt += amount
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("register_tower_damage"):
		main.register_tower_damage(main.TowerType.PHANTOM, amount)

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
	fire_rate *= 1.03
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
			damage = 45.0
			fire_rate = 0.6
			attack_range = 195.0
			lasso_cooldown = 8.0
		2: # Angel of Music — slow aura
			damage = 55.0
			fire_rate = 0.7
			attack_range = 210.0
			gold_bonus = 3
		3: # Chandelier — AoE burst
			damage = 70.0
			fire_rate = 0.8
			attack_range = 230.0
			chandelier_cooldown = 14.0
			gold_bonus = 4
			lasso_cooldown = 6.0
		4: # Phantom's Wrath — DoT + all enhanced
			damage = 90.0
			fire_rate = 1.0
			attack_range = 260.0
			note_dot_dps = 20.0
			note_dot_duration = 4.0
			gold_bonus = 6
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
	_refresh_tier_sounds()
	_upgrade_flash = 3.0
	_upgrade_name = TIER_NAMES[upgrade_tier - 1]
	if _upgrade_player and not _is_sfx_muted(): _upgrade_player.play()
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

func _generate_tier_sounds() -> void:
	# Gothic organ — D minor horror scale: D3, Eb3, G3, Bb3
	# Long, drawn-out, scary organ tones inspired by Bach's Toccata and Fugue in D minor
	var gothic_notes := [146.83, 155.56, 196.00, 233.08]  # D3, Eb3, G3, Bb3
	var mix_rate := 44100
	_attack_sounds_by_tier = []

	# --- Tier 0: Haunted Chapel (dark 8' principal, eerie tremulant) ---
	var t0 := []
	for note_idx in gothic_notes.size():
		var freq: float = gothic_notes[note_idx]
		var dur := 2.0  # Long drawn-out note
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * dur))
		for i in samples.size():
			var t := float(i) / mix_rate
			# Slow organ attack, long sustain, gradual release
			var att := clampf(t / 0.08, 0.0, 1.0)
			var rel := clampf((dur - t) / 0.4, 0.0, 1.0)
			var env := att * rel * 0.25
			# Dark principal pipe — heavy on odd harmonics for gothic character
			var pipe := sin(TAU * freq * t)
			pipe += sin(TAU * freq * 2.0 * t) * 0.35
			pipe += sin(TAU * freq * 3.0 * t) * 0.25
			pipe += sin(TAU * freq * 4.0 * t) * 0.12
			pipe += sin(TAU * freq * 5.0 * t) * 0.08
			# 16' Bourdon — deep sub-octave foundation
			var foundation := sin(TAU * freq * 0.5 * t) * 0.4
			# Eerie slow tremulant (slightly irregular for creepiness)
			var trem := 1.0 + sin(TAU * 3.5 * t) * 0.025 + sin(TAU * 5.1 * t) * 0.01
			samples[i] = clampf((pipe + foundation) * env * trem, -1.0, 1.0)
		t0.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t0)

	# --- Tier 1: Phantom's Lair (+ dissonant overtones, deeper foundation) ---
	var t1 := []
	for note_idx in gothic_notes.size():
		var freq: float = gothic_notes[note_idx]
		var dur := 2.2
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * dur))
		for i in samples.size():
			var t := float(i) / mix_rate
			var att := clampf(t / 0.07, 0.0, 1.0)
			var rel := clampf((dur - t) / 0.45, 0.0, 1.0)
			var env := att * rel * 0.24
			var pipe := sin(TAU * freq * t)
			pipe += sin(TAU * freq * 2.0 * t) * 0.38
			pipe += sin(TAU * freq * 3.0 * t) * 0.28
			pipe += sin(TAU * freq * 4.0 * t) * 0.14
			pipe += sin(TAU * freq * 5.0 * t) * 0.10
			pipe += sin(TAU * freq * 6.0 * t) * 0.04
			var foundation := sin(TAU * freq * 0.5 * t) * 0.42
			# Dissonant minor 2nd ghost tone (very quiet, unsettling)
			var ghost := sin(TAU * freq * 1.06 * t) * 0.06 * exp(-t * 0.5)
			var trem := 1.0 + sin(TAU * 3.2 * t) * 0.03 + sin(TAU * 5.3 * t) * 0.012
			samples[i] = clampf((pipe + foundation + ghost) * env * trem, -1.0, 1.0)
		t1.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t1)

	# --- Tier 2: Cathedral of Shadows (+ 32' pedal, reed stops) ---
	var t2 := []
	for note_idx in gothic_notes.size():
		var freq: float = gothic_notes[note_idx]
		var dur := 2.5
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * dur))
		for i in samples.size():
			var t := float(i) / mix_rate
			var att := clampf(t / 0.06, 0.0, 1.0)
			var rel := clampf((dur - t) / 0.5, 0.0, 1.0)
			var env := att * rel * 0.22
			var pipe := sin(TAU * freq * t)
			pipe += sin(TAU * freq * 2.0 * t) * 0.40
			pipe += sin(TAU * freq * 3.0 * t) * 0.30
			pipe += sin(TAU * freq * 4.0 * t) * 0.16
			pipe += sin(TAU * freq * 5.0 * t) * 0.10
			pipe += sin(TAU * freq * 6.0 * t) * 0.05
			var foundation := sin(TAU * freq * 0.5 * t) * 0.44
			# 32' Sub-bass pedal — bone-rattling depth
			var pedal := sin(TAU * freq * 0.25 * t) * 0.2
			# Dark reed stop (odd harmonics, nasal/menacing)
			var reed := sin(TAU * freq * t) * 0.1
			reed += sin(TAU * freq * 3.0 * t) * 0.08
			reed += sin(TAU * freq * 5.0 * t) * 0.05
			reed += sin(TAU * freq * 7.0 * t) * 0.03
			var ghost := sin(TAU * freq * 1.06 * t) * 0.05 * exp(-t * 0.4)
			var trem := 1.0 + sin(TAU * 3.0 * t) * 0.035 + sin(TAU * 5.5 * t) * 0.015
			samples[i] = clampf((pipe + foundation + pedal + reed + ghost) * env * trem, -1.0, 1.0)
		t2.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t2)

	# --- Tier 3: Phantom's Fury (+ full reed chorus, terrifying power) ---
	var t3 := []
	for note_idx in gothic_notes.size():
		var freq: float = gothic_notes[note_idx]
		var dur := 2.8
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * dur))
		for i in samples.size():
			var t := float(i) / mix_rate
			var att := clampf(t / 0.05, 0.0, 1.0)
			var rel := clampf((dur - t) / 0.55, 0.0, 1.0)
			var env := att * rel * 0.20
			var pipe := sin(TAU * freq * t)
			pipe += sin(TAU * freq * 2.0 * t) * 0.42
			pipe += sin(TAU * freq * 3.0 * t) * 0.32
			pipe += sin(TAU * freq * 4.0 * t) * 0.18
			pipe += sin(TAU * freq * 5.0 * t) * 0.12
			pipe += sin(TAU * freq * 6.0 * t) * 0.06
			var foundation := sin(TAU * freq * 0.5 * t) * 0.46
			var pedal := sin(TAU * freq * 0.25 * t) * 0.22
			# Full reed chorus — menacing brass-like growl
			var reed := sin(TAU * freq * t) * 0.14
			reed += sin(TAU * freq * 3.0 * t) * 0.12
			reed += sin(TAU * freq * 5.0 * t) * 0.08
			reed += sin(TAU * freq * 7.0 * t) * 0.05
			reed += sin(TAU * freq * 9.0 * t) * 0.02
			# Dissonant cluster (chromatic neighbor tones for horror)
			var ghost := sin(TAU * freq * 1.06 * t) * 0.04
			ghost += sin(TAU * freq * 0.94 * t) * 0.03
			var trem := 1.0 + sin(TAU * 2.8 * t) * 0.04 + sin(TAU * 5.7 * t) * 0.018
			samples[i] = clampf((pipe + foundation + pedal + reed + ghost) * env * trem, -1.0, 1.0)
		t3.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t3)

	# --- Tier 4: Requiem of the Damned (all stops, mixture, unholy power) ---
	var t4 := []
	for note_idx in gothic_notes.size():
		var freq: float = gothic_notes[note_idx]
		var dur := 3.0
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * dur))
		for i in samples.size():
			var t := float(i) / mix_rate
			var att := clampf(t / 0.04, 0.0, 1.0)
			var rel := clampf((dur - t) / 0.6, 0.0, 1.0)
			var env := att * rel * 0.18
			# Full principal chorus
			var pipe := sin(TAU * freq * t)
			pipe += sin(TAU * freq * 2.0 * t) * 0.45
			pipe += sin(TAU * freq * 3.0 * t) * 0.34
			pipe += sin(TAU * freq * 4.0 * t) * 0.20
			pipe += sin(TAU * freq * 5.0 * t) * 0.14
			pipe += sin(TAU * freq * 6.0 * t) * 0.08
			pipe += sin(TAU * freq * 7.0 * t) * 0.04
			# 16' + 32' foundation (earth-shaking)
			var foundation := sin(TAU * freq * 0.5 * t) * 0.48
			var pedal := sin(TAU * freq * 0.25 * t) * 0.25
			# Full reed tutti
			var reed := sin(TAU * freq * t) * 0.16
			reed += sin(TAU * freq * 3.0 * t) * 0.14
			reed += sin(TAU * freq * 5.0 * t) * 0.10
			reed += sin(TAU * freq * 7.0 * t) * 0.06
			reed += sin(TAU * freq * 9.0 * t) * 0.03
			# Mixture (high compound stops for brilliance)
			var mixture := sin(TAU * freq * 3.0 * t) * 0.05
			mixture += sin(TAU * freq * 4.0 * t) * 0.04
			mixture += sin(TAU * freq * 6.0 * t) * 0.03
			# Dissonant cluster — maximum horror
			var ghost := sin(TAU * freq * 1.06 * t) * 0.04
			ghost += sin(TAU * freq * 0.94 * t) * 0.03
			ghost += sin(TAU * freq * 1.5 * t) * 0.02  # Tritone ghost
			# Haunted tremulant
			var trem := 1.0 + sin(TAU * 2.5 * t) * 0.045 + sin(TAU * 6.0 * t) * 0.02
			samples[i] = clampf((pipe + foundation + pedal + reed + mixture + ghost) * env * trem, -1.0, 1.0)
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
	if main and main.survivor_progress.has(main.TowerType.PHANTOM):
		var p = main.survivor_progress[main.TowerType.PHANTOM]
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
	if prog_abilities[0]:  # Music of the Night: +20% damage (applied in _shoot)
		pass

func get_progressive_ability_name(index: int) -> String:
	if index >= 0 and index < PROG_ABILITY_NAMES.size():
		return PROG_ABILITY_NAMES[index]
	return ""

func get_progressive_ability_desc(index: int) -> String:
	if index >= 0 and index < PROG_ABILITY_DESCS.size():
		return PROG_ABILITY_DESCS[index]
	return ""

func get_spawn_debuffs() -> Dictionary:
	var debuffs := {}
	# Ability 9: Beneath the Opera — all enemies permanently 30% slower
	if prog_abilities[8]:
		debuffs["permanent_slow"] = 0.7
	return debuffs

func _process_progressive_abilities(delta: float) -> void:
	# Visual flash decay
	_red_death_flash = max(_red_death_flash - delta * 2.0, 0.0)
	_christines_aria_flash = max(_christines_aria_flash - delta * 2.0, 0.0)
	_trap_door_flash = max(_trap_door_flash - delta * 2.0, 0.0)
	_box_five_flash = max(_box_five_flash - delta * 1.5, 0.0)
	_underground_lake_flash = max(_underground_lake_flash - delta * 1.5, 0.0)
	_requiem_mass_flash = max(_requiem_mass_flash - delta * 1.5, 0.0)
	_organs_fury_flash = max(_organs_fury_flash - delta * 1.5, 0.0)
	_beneath_opera_flash = max(_beneath_opera_flash - delta * 1.5, 0.0)

	# Ability 2: The Red Death — fear burst every 15s
	if prog_abilities[1]:
		_red_death_timer -= delta
		if _red_death_timer <= 0.0 and _has_enemies_in_range():
			_red_death_burst()
			_red_death_timer = 15.0

	# Ability 3: Christine's Aria — charm 3 enemies every 18s
	if prog_abilities[2]:
		_christines_aria_timer -= delta
		if _christines_aria_timer <= 0.0 and _has_enemies_in_range():
			_christines_aria()
			_christines_aria_timer = 18.0

	# Ability 4: The Trap Door — instant kill every 20s
	if prog_abilities[3]:
		_trap_door_timer -= delta
		if _trap_door_timer <= 0.0 and _has_enemies_in_range():
			_trap_door()
			_trap_door_timer = 20.0

	# Ability 5: Box Five — AoE petal rain every 15s, lasts 5s
	if prog_abilities[4]:
		if _box_five_active > 0.0:
			_box_five_active -= delta
			# Deal damage * delta to all enemies in range each frame
			for e in get_tree().get_nodes_in_group("enemies"):
				if global_position.distance_to(e.global_position) < attack_range:
					if e.has_method("take_damage"):
						var dmg = damage * delta
						e.take_damage(dmg, true)
						register_damage(dmg)
		else:
			_box_five_timer -= delta
			if _box_five_timer <= 0.0 and _has_enemies_in_range():
				_box_five_activate()
				_box_five_timer = 15.0

	# Ability 6: The Underground Lake — slow all enemies every 18s
	if prog_abilities[5]:
		_underground_lake_timer -= delta
		if _underground_lake_timer <= 0.0:
			_underground_lake()
			_underground_lake_timer = 18.0

	# Ability 7: Requiem Mass — stun all enemies every 20s
	if prog_abilities[6]:
		_requiem_mass_timer -= delta
		if _requiem_mass_timer <= 0.0:
			_requiem_mass()
			_requiem_mass_timer = 20.0

	# Ability 8: The Organ's Fury — 3x damage + stun all every 25s
	if prog_abilities[7]:
		_organs_fury_timer -= delta
		if _organs_fury_timer <= 0.0:
			_organs_fury()
			_organs_fury_timer = 25.0

func _red_death_burst() -> void:
	_red_death_flash = 1.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) < attack_range:
			if e.has_method("apply_fear_reverse"):
				e.apply_fear_reverse(2.0)

func _christines_aria() -> void:
	_christines_aria_flash = 1.0
	var enemies = get_tree().get_nodes_in_group("enemies")
	var in_range: Array = []
	for e in enemies:
		if global_position.distance_to(e.global_position) < attack_range:
			in_range.append(e)
	in_range.shuffle()
	for i in range(mini(3, in_range.size())):
		if is_instance_valid(in_range[i]) and in_range[i].has_method("apply_charm"):
			in_range[i].apply_charm(4.0, 2.0)

func _trap_door() -> void:
	_trap_door_flash = 1.0
	# Find weakest enemy in range
	var weakest: Node2D = null
	var lowest_hp: float = INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) < attack_range:
			if e.health < lowest_hp:
				lowest_hp = e.health
				weakest = e
	if weakest and weakest.has_method("take_damage"):
		if weakest.max_health > 500:
			# Boss: deal 50% of current HP
			var dmg = weakest.health * 0.5
			weakest.take_damage(dmg, true)
			register_damage(dmg)
		else:
			# Normal: instant kill
			var dmg = weakest.health
			weakest.take_damage(dmg, true)
			register_damage(dmg)

func _box_five_activate() -> void:
	_box_five_flash = 1.0
	_box_five_active = 5.0

func _underground_lake() -> void:
	_underground_lake_flash = 1.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("apply_slow"):
			e.apply_slow(0.4, 3.0)

func _requiem_mass() -> void:
	_requiem_mass_flash = 1.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("apply_sleep"):
			e.apply_sleep(2.0)

func _organs_fury() -> void:
	_organs_fury_flash = 1.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("take_damage"):
			var dmg = damage * 3.0
			e.take_damage(dmg, true)
			register_damage(dmg)
		if e.has_method("apply_sleep"):
			e.apply_sleep(2.0)

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

	# === IDLE ANIMATION (dramatic theatrical presence) ===
	var bounce = abs(sin(_time * 2.0)) * 3.0  # Slower, more dramatic
	var breathe = sin(_time * 1.5) * 2.5  # Deep theatrical breathing
	var sway = sin(_time * 1.0) * 2.0  # Slow dramatic sway
	var cape_sweep = sin(_time * 0.8) * 3.5  # Slow sweeping cape motion
	var bob = Vector2(sway, -bounce - breathe)
	var fly_offset = Vector2.ZERO
	if upgrade_tier >= 4:
		fly_offset = Vector2(0, -8.0 + sin(_time * 1.5) * 3.0)
	var body_offset = bob + fly_offset

	# === SKIN COLORS (pale, dramatic — classic Phantom) ===
	var skin_base = Color(0.88, 0.82, 0.78)
	var skin_shadow = Color(0.72, 0.65, 0.60)
	var skin_highlight = Color(0.95, 0.90, 0.88)


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

	# === PROGRESSIVE ABILITY VISUAL EFFECTS ===

	# Ability 1: Music of the Night — glowing purple notes with echo trail
	if prog_abilities[0]:
		for ni in range(4):
			var mn_a = _time * 1.2 + float(ni) * TAU / 4.0
			var mn_r = 44.0 + sin(_time * 1.8 + float(ni) * 1.5) * 6.0
			var mn_pos = Vector2.from_angle(mn_a) * mn_r
			var mn_alpha = 0.35 + sin(_time * 2.0 + float(ni) * 1.1) * 0.1
			# Echo trail
			for ei in range(3):
				var trail_a = mn_a - float(ei + 1) * 0.15
				var trail_pos = Vector2.from_angle(trail_a) * mn_r
				draw_circle(trail_pos, 3.0 - float(ei) * 0.5, Color(0.6, 0.3, 0.9, mn_alpha * 0.2 / float(ei + 1)))
			# Glowing note head
			draw_circle(mn_pos, 5.0, Color(0.6, 0.3, 0.9, mn_alpha * 0.2))
			draw_circle(mn_pos, 3.5, Color(0.7, 0.4, 1.0, mn_alpha))
			# Note stem
			draw_line(mn_pos + Vector2(2.0, 0), mn_pos + Vector2(2.0, -10.0), Color(0.7, 0.4, 1.0, mn_alpha * 0.7), 1.5)
			# Note flag
			draw_line(mn_pos + Vector2(2.0, -10.0), mn_pos + Vector2(6.0, -7.0), Color(0.7, 0.4, 1.0, mn_alpha * 0.5), 1.3)

	# Ability 2: The Red Death flash — red skull/mask burst
	if _red_death_flash > 0.0:
		var rd_r = 40.0 + (1.0 - _red_death_flash) * 80.0
		draw_circle(Vector2.ZERO, rd_r, Color(0.8, 0.05, 0.05, _red_death_flash * 0.25))
		draw_arc(Vector2.ZERO, rd_r, 0, TAU, 32, Color(0.9, 0.1, 0.05, _red_death_flash * 0.5), 3.0)
		# Red skull mask shape
		draw_circle(Vector2(0, -8), 8.0, Color(0.9, 0.1, 0.05, _red_death_flash * 0.6))
		draw_circle(Vector2(-3, -10), 2.5, Color(0.0, 0.0, 0.0, _red_death_flash * 0.7))
		draw_circle(Vector2(3, -10), 2.5, Color(0.0, 0.0, 0.0, _red_death_flash * 0.7))
		draw_line(Vector2(-1, -5), Vector2(1, -5), Color(0.0, 0.0, 0.0, _red_death_flash * 0.5), 1.5)

	# Ability 3: Christine's Aria flash — music notes and hearts
	if _christines_aria_flash > 0.0:
		for ci in range(5):
			var ca = TAU * float(ci) / 5.0 + _christines_aria_flash * 4.0
			var cr = 30.0 + (1.0 - _christines_aria_flash) * 40.0
			var cpos = Vector2.from_angle(ca) * cr
			# Music note
			draw_circle(cpos, 3.0, Color(1.0, 0.6, 0.8, _christines_aria_flash * 0.6))
			draw_line(cpos + Vector2(2, 0), cpos + Vector2(2, -8), Color(1.0, 0.6, 0.8, _christines_aria_flash * 0.4), 1.2)
			# Heart above
			var hpos = cpos + Vector2(0, -14)
			draw_circle(hpos + Vector2(-2, 0), 2.0, Color(1.0, 0.3, 0.4, _christines_aria_flash * 0.5))
			draw_circle(hpos + Vector2(2, 0), 2.0, Color(1.0, 0.3, 0.4, _christines_aria_flash * 0.5))

	# Ability 4: The Trap Door flash — trapdoor opening
	if _trap_door_flash > 0.0:
		var td_y = 15.0
		var td_open = (1.0 - _trap_door_flash) * 20.0
		# Trapdoor outline
		draw_rect(Rect2(Vector2(-15, td_y - 5), Vector2(30, 10)), Color(0.3, 0.2, 0.1, _trap_door_flash * 0.6), false, 2.0)
		# Door halves opening
		draw_line(Vector2(-15, td_y), Vector2(-15, td_y - td_open), Color(0.4, 0.25, 0.1, _trap_door_flash * 0.5), 3.0)
		draw_line(Vector2(15, td_y), Vector2(15, td_y - td_open), Color(0.4, 0.25, 0.1, _trap_door_flash * 0.5), 3.0)
		# Dark void below
		draw_rect(Rect2(Vector2(-14, td_y - 4), Vector2(28, 8)), Color(0.0, 0.0, 0.0, _trap_door_flash * 0.4), true)

	# Ability 5: Box Five flash — ornate opera box with falling petals
	if _box_five_flash > 0.0 or _box_five_active > 0.0:
		var bf_alpha = maxf(_box_five_flash, _box_five_active / 5.0) * 0.4
		# Opera box outline overhead
		draw_rect(Rect2(Vector2(-20, -90), Vector2(40, 25)), Color(0.8, 0.6, 0.2, bf_alpha), false, 2.0)
		draw_rect(Rect2(Vector2(-18, -88), Vector2(36, 21)), Color(0.6, 0.1, 0.1, bf_alpha * 0.5), true)
		# Falling rose petals
		for pi in range(6):
			var px = -16.0 + float(pi) * 6.4
			var py = -65.0 + fmod(_time * 30.0 + float(pi) * 15.0, 80.0)
			var petal_sway = sin(_time * 3.0 + float(pi) * 2.0) * 4.0
			draw_circle(Vector2(px + petal_sway, py), 2.5, Color(0.9, 0.2, 0.2, bf_alpha * 1.5))
			draw_circle(Vector2(px + petal_sway + 1, py - 1), 1.5, Color(1.0, 0.4, 0.4, bf_alpha))

	# Ability 6: The Underground Lake flash — blue water ripple
	if _underground_lake_flash > 0.0:
		var ul_r = 50.0 + (1.0 - _underground_lake_flash) * 120.0
		draw_circle(Vector2.ZERO, ul_r, Color(0.1, 0.3, 0.7, _underground_lake_flash * 0.15))
		draw_arc(Vector2.ZERO, ul_r, 0, TAU, 48, Color(0.2, 0.5, 0.9, _underground_lake_flash * 0.4), 3.0)
		draw_arc(Vector2.ZERO, ul_r * 0.7, 0, TAU, 36, Color(0.15, 0.4, 0.85, _underground_lake_flash * 0.3), 2.0)
		draw_arc(Vector2.ZERO, ul_r * 0.4, 0, TAU, 24, Color(0.1, 0.35, 0.8, _underground_lake_flash * 0.2), 1.5)

	# Ability 7: Requiem Mass flash — ghostly choir and musical shockwave
	if _requiem_mass_flash > 0.0:
		var rm_r = 45.0 + (1.0 - _requiem_mass_flash) * 100.0
		# Musical shockwave rings
		draw_arc(Vector2.ZERO, rm_r, 0, TAU, 48, Color(0.7, 0.7, 0.9, _requiem_mass_flash * 0.4), 3.5)
		draw_arc(Vector2.ZERO, rm_r * 0.75, 0, TAU, 36, Color(0.6, 0.6, 0.85, _requiem_mass_flash * 0.3), 2.5)
		# Translucent choir silhouettes
		for si in range(5):
			var sa = TAU * float(si) / 5.0 + _requiem_mass_flash * 2.0
			var spos = Vector2.from_angle(sa) * 35.0
			# Ghost figure
			draw_circle(spos + Vector2(0, -6), 4.0, Color(0.8, 0.8, 1.0, _requiem_mass_flash * 0.35))
			draw_line(spos + Vector2(0, -2), spos + Vector2(0, 6), Color(0.8, 0.8, 1.0, _requiem_mass_flash * 0.25), 4.0)

	# Ability 8: The Organ's Fury flash — massive organ and shockwave
	if _organs_fury_flash > 0.0:
		var of_r = 60.0 + (1.0 - _organs_fury_flash) * 150.0
		# Devastating shockwave rings
		draw_arc(Vector2.ZERO, of_r, 0, TAU, 48, Color(0.9, 0.3, 0.1, _organs_fury_flash * 0.35), 4.0)
		draw_arc(Vector2.ZERO, of_r * 0.8, 0, TAU, 36, Color(0.8, 0.2, 0.05, _organs_fury_flash * 0.25), 3.0)
		draw_arc(Vector2.ZERO, of_r * 0.6, 0, TAU, 24, Color(0.7, 0.15, 0.05, _organs_fury_flash * 0.2), 2.0)
		# Pipe organ silhouette
		for pi in range(7):
			var pipe_x = -18.0 + float(pi) * 6.0
			var pipe_h = 20.0 + abs(float(pi) - 3.0) * 8.0
			draw_line(Vector2(pipe_x, -50), Vector2(pipe_x, -50 - pipe_h), Color(0.6, 0.5, 0.3, _organs_fury_flash * 0.5), 4.0)
			draw_circle(Vector2(pipe_x, -50 - pipe_h), 3.0, Color(0.7, 0.6, 0.35, _organs_fury_flash * 0.4))

	# Ability 9: Beneath the Opera — water shimmer overlay
	if prog_abilities[8]:
		var bo_alpha = 0.06 + sin(_time * 1.5) * 0.03
		draw_circle(Vector2.ZERO, attack_range * 0.95, Color(0.15, 0.25, 0.5, bo_alpha))
		# Drifting notes across the map
		for ni in range(6):
			var dn_a = _time * 0.5 + float(ni) * TAU / 6.0
			var dn_r = 60.0 + sin(_time * 0.8 + float(ni) * 1.3) * 30.0
			var dn_pos = Vector2.from_angle(dn_a) * dn_r
			var dn_alpha = 0.25 + sin(_time * 1.5 + float(ni) * 0.7) * 0.1
			draw_circle(dn_pos, 3.5, Color(0.5, 0.3, 0.8, dn_alpha))
			draw_line(dn_pos + Vector2(2, 0), dn_pos + Vector2(2, -9), Color(0.5, 0.3, 0.8, dn_alpha * 0.6), 1.2)

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

	# === CHARACTER POSITIONS (taller dramatic proportions ~62px — tallest character) ===
	var feet_y = body_offset + Vector2(cape_sweep * 0.3, 14.0)
	var leg_top = body_offset + Vector2(cape_sweep * 0.2, -4.0)
	var torso_center = body_offset + Vector2(-cape_sweep * 0.15, -14.0)
	var neck_base = body_offset + Vector2(-cape_sweep * 0.3, -26.0)
	var head_center = body_offset + Vector2(-cape_sweep * 0.15, -38.0)

	# === CAPE (red-lined black cape — behind the body, dramatic full-length) ===
	var cape_sway_val = sin(_time * 1.3) * 4.0 + cape_sweep * 1.5
	var cape_billow = 0.0
	if upgrade_tier >= 4:
		cape_billow = sin(_time * 0.7) * 6.0 + sin(_time * 1.9) * 3.0
	cape_sway_val += cape_billow

	# Outer cape (black) — wider, more dramatic sweep from shoulders past legs
	var cape_pts = PackedVector2Array([
		neck_base + Vector2(-22 - cape_sway_val * 0.3, 0),
		neck_base + Vector2(-26 - cape_sway_val * 0.5, 14),
		body_offset + Vector2(-24 - cape_sway_val * 0.7, 22),
		feet_y + Vector2(-16 - cape_sway_val * 0.4, 6),
		feet_y + Vector2(16 + cape_sway_val * 0.4, 6),
		body_offset + Vector2(24 + cape_sway_val * 0.7, 22),
		neck_base + Vector2(26 + cape_sway_val * 0.5, 14),
		neck_base + Vector2(22 + cape_sway_val * 0.3, 0),
	])
	draw_colored_polygon(cape_pts, Color(0.04, 0.02, 0.06))
	# Cape red lining (visible on left side — more visible)
	var lining_pts = PackedVector2Array([
		neck_base + Vector2(-21 - cape_sway_val * 0.3, 2),
		neck_base + Vector2(-24 - cape_sway_val * 0.5, 12),
		body_offset + Vector2(-22 - cape_sway_val * 0.6, 20),
		feet_y + Vector2(-15 - cape_sway_val * 0.35, 4),
		torso_center + Vector2(-8, 12),
		torso_center + Vector2(-10, 0),
		neck_base + Vector2(-12, 2),
	])
	draw_colored_polygon(lining_pts, Color(0.65, 0.06, 0.08, 0.8))
	# Satin sheen on lining (drawn as lines to avoid polygon triangulation issues)
	var sheen_col = Color(0.85, 0.15, 0.18, 0.3)
	for si in range(3):
		var st = float(si) / 2.0
		var sheen_top = neck_base + Vector2(-20 - cape_sway_val * 0.35 + st * 4, 4 + st * 5)
		var sheen_bot = torso_center + Vector2(-16 - cape_sway_val * 0.3 + st * 2, -2 + st * 5)
		draw_line(sheen_top, sheen_bot, sheen_col, 1.5)
	# Red lining right side (more visible)
	var lining_r_pts = PackedVector2Array([
		neck_base + Vector2(12, 2),
		torso_center + Vector2(10, 0),
		torso_center + Vector2(8, 12),
		feet_y + Vector2(15 + cape_sway_val * 0.35, 4),
		body_offset + Vector2(22 + cape_sway_val * 0.6, 20),
		neck_base + Vector2(24 + cape_sway_val * 0.5, 12),
		neck_base + Vector2(21 + cape_sway_val * 0.3, 2),
	])
	draw_colored_polygon(lining_r_pts, Color(0.55, 0.05, 0.07, 0.5))
	# Cape fold lines (6 instead of 4)
	for fold_i in range(6):
		var fold_t = float(fold_i) / 5.0
		var fold_x = -20.0 + fold_t * 40.0
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

	# === LONG ELEGANT LEGS (polygon tuxedo trousers, broad build) ===
	var l_knee = leg_top + Vector2(-5, 9)
	var r_knee = leg_top + Vector2(5, 9)
	var l_hip = leg_top + Vector2(-5, 0)
	var r_hip = leg_top + Vector2(5, 0)
	var l_ankle = l_foot + Vector2(0, -3)
	var r_ankle = r_foot + Vector2(0, -3)
	# LEFT THIGH — broad masculine shape
	draw_colored_polygon(PackedVector2Array([
		l_hip + Vector2(3, 0), l_hip + Vector2(-5, 0),
		l_hip.lerp(l_knee, 0.3) + Vector2(-6.5, 0),  # outer quad
		l_hip.lerp(l_knee, 0.6) + Vector2(-6.0, 0),
		l_knee + Vector2(-4.5, 0), l_knee + Vector2(3.5, 0),
		l_hip.lerp(l_knee, 0.5) + Vector2(4.5, 0),
	]), Color(0.04, 0.03, 0.06))
	draw_colored_polygon(PackedVector2Array([
		l_hip + Vector2(2, 0), l_hip + Vector2(-4, 0),
		l_hip.lerp(l_knee, 0.3) + Vector2(-5.5, 0),
		l_knee + Vector2(-3.5, 0), l_knee + Vector2(2.5, 0),
	]), Color(0.08, 0.06, 0.10))
	# RIGHT THIGH
	draw_colored_polygon(PackedVector2Array([
		r_hip + Vector2(-3, 0), r_hip + Vector2(5, 0),
		r_hip.lerp(r_knee, 0.3) + Vector2(6.5, 0),
		r_hip.lerp(r_knee, 0.6) + Vector2(6.0, 0),
		r_knee + Vector2(4.5, 0), r_knee + Vector2(-3.5, 0),
		r_hip.lerp(r_knee, 0.5) + Vector2(-4.5, 0),
	]), Color(0.04, 0.03, 0.06))
	draw_colored_polygon(PackedVector2Array([
		r_hip + Vector2(-2, 0), r_hip + Vector2(4, 0),
		r_hip.lerp(r_knee, 0.3) + Vector2(5.5, 0),
		r_knee + Vector2(3.5, 0), r_knee + Vector2(-2.5, 0),
	]), Color(0.08, 0.06, 0.10))
	# Knee joints
	draw_circle(l_knee, 5.0, Color(0.04, 0.03, 0.06))
	draw_circle(l_knee, 4.0, Color(0.08, 0.06, 0.10))
	draw_circle(r_knee, 5.0, Color(0.04, 0.03, 0.06))
	draw_circle(r_knee, 4.0, Color(0.08, 0.06, 0.10))
	# LEFT CALF — strong shape
	draw_colored_polygon(PackedVector2Array([
		l_knee + Vector2(-4.5, 0), l_knee + Vector2(3.5, 0),
		l_knee.lerp(l_ankle, 0.35) + Vector2(3.5, 0),
		l_ankle + Vector2(2.5, 0), l_ankle + Vector2(-2.5, 0),
		l_knee.lerp(l_ankle, 0.35) + Vector2(-5.5, 0),
	]), Color(0.04, 0.03, 0.06))
	draw_colored_polygon(PackedVector2Array([
		l_knee + Vector2(-3.5, 0), l_knee + Vector2(2.5, 0),
		l_ankle + Vector2(1.5, 0), l_ankle + Vector2(-1.5, 0),
	]), Color(0.08, 0.06, 0.10))
	# RIGHT CALF
	draw_colored_polygon(PackedVector2Array([
		r_knee + Vector2(4.5, 0), r_knee + Vector2(-3.5, 0),
		r_knee.lerp(r_ankle, 0.35) + Vector2(-3.5, 0),
		r_ankle + Vector2(-2.5, 0), r_ankle + Vector2(2.5, 0),
		r_knee.lerp(r_ankle, 0.35) + Vector2(5.5, 0),
	]), Color(0.04, 0.03, 0.06))
	draw_colored_polygon(PackedVector2Array([
		r_knee + Vector2(3.5, 0), r_knee + Vector2(-2.5, 0),
		r_ankle + Vector2(-1.5, 0), r_ankle + Vector2(1.5, 0),
	]), Color(0.08, 0.06, 0.10))
	# Satin side stripes (tuxedo detail)
	draw_line(l_ankle + Vector2(-2, 0), l_hip + Vector2(-3, 0), Color(0.18, 0.16, 0.20, 0.35), 1.0)
	draw_line(r_ankle + Vector2(2, 0), r_hip + Vector2(3, 0), Color(0.18, 0.16, 0.20, 0.35), 1.0)
	# Knee crease detail
	draw_line(l_knee + Vector2(-4, 0), l_knee + Vector2(3, 0), Color(0.03, 0.02, 0.05, 0.3), 1.0)
	draw_line(r_knee + Vector2(-3, 0), r_knee + Vector2(4, 0), Color(0.03, 0.02, 0.05, 0.3), 1.0)

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

	# === LEFT ARM — polygon tuxedo sleeve, holds cape (dramatic pose) ===
	var l_shoulder_pos = neck_base + Vector2(-17, 0)
	var l_elbow = neck_base + Vector2(-20, 12 + sin(_time * 1.5) * 1.0)
	var l_hand_pos = torso_center + Vector2(-20, 6 + sin(_time * 1.5) * 1.5)
	# LEFT UPPER ARM — broad tuxedo sleeve polygon
	var l_ua_dir = (l_elbow - l_shoulder_pos).normalized()
	var l_ua_perp = l_ua_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		l_shoulder_pos + l_ua_perp * 6.0, l_shoulder_pos - l_ua_perp * 5.5,
		l_shoulder_pos.lerp(l_elbow, 0.3) - l_ua_perp * 6.0,
		l_elbow - l_ua_perp * 4.0, l_elbow + l_ua_perp * 4.0,
		l_shoulder_pos.lerp(l_elbow, 0.5) + l_ua_perp * 5.0,
	]), Color(0.04, 0.03, 0.06))
	draw_colored_polygon(PackedVector2Array([
		l_shoulder_pos + l_ua_perp * 5.0, l_shoulder_pos - l_ua_perp * 4.5,
		l_elbow - l_ua_perp * 3.0, l_elbow + l_ua_perp * 3.0,
	]), Color(0.06, 0.04, 0.08))
	# Sleeve highlight
	draw_line(l_shoulder_pos.lerp(l_elbow, 0.15) + l_ua_perp * 3.0, l_shoulder_pos.lerp(l_elbow, 0.7) + l_ua_perp * 3.0, Color(0.12, 0.10, 0.15, 0.3), 1.0)
	# LEFT FOREARM — polygon tapered
	var l_fa_dir = (l_hand_pos - l_elbow).normalized()
	var l_fa_perp = l_fa_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		l_elbow + l_fa_perp * 4.0, l_elbow - l_fa_perp * 4.0,
		l_hand_pos - l_fa_perp * 3.0, l_hand_pos + l_fa_perp * 3.0,
	]), Color(0.04, 0.03, 0.06))
	draw_colored_polygon(PackedVector2Array([
		l_elbow + l_fa_perp * 3.0, l_elbow - l_fa_perp * 3.0,
		l_hand_pos - l_fa_perp * 2.0, l_hand_pos + l_fa_perp * 2.0,
	]), Color(0.06, 0.04, 0.08))
	# Elbow joint
	draw_circle(l_elbow, 4.5, Color(0.04, 0.03, 0.06))
	draw_circle(l_elbow, 3.5, Color(0.06, 0.04, 0.08))
	# White glove cuff
	draw_arc(l_hand_pos + Vector2(0, -2), 4.0, 0, TAU, 8, Color(0.95, 0.93, 0.91), 2.5)
	# White-gloved hand (gripping cape)
	draw_circle(l_hand_pos, 4.0, Color(0.90, 0.88, 0.86))
	draw_circle(l_hand_pos, 3.2, Color(0.95, 0.93, 0.91))
	# Fingers curled around cape
	for fi in range(3):
		var finger_angle = PI * 0.6 + float(fi) * 0.3
		draw_circle(l_hand_pos + Vector2.from_angle(finger_angle) * 3.5, 1.5, Color(0.97, 0.95, 0.93))

	# === RIGHT ARM — polygon tuxedo sleeve, conducting hand toward aim ===
	var attack_extend = _attack_anim * 12.0
	var r_shoulder_pos = neck_base + Vector2(17, 0)
	var r_elbow = neck_base + Vector2(19, 10)
	var r_hand_pos = r_shoulder_pos + dir * (18.0 + attack_extend)
	# RIGHT UPPER ARM — broad tuxedo sleeve polygon
	var r_ua_dir = (r_elbow - r_shoulder_pos).normalized()
	var r_ua_perp = r_ua_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		r_shoulder_pos + r_ua_perp * 5.5, r_shoulder_pos - r_ua_perp * 6.0,
		r_shoulder_pos.lerp(r_elbow, 0.3) - r_ua_perp * 6.0,
		r_elbow - r_ua_perp * 4.0, r_elbow + r_ua_perp * 4.0,
		r_shoulder_pos.lerp(r_elbow, 0.5) + r_ua_perp * 5.0,
	]), Color(0.04, 0.03, 0.06))
	draw_colored_polygon(PackedVector2Array([
		r_shoulder_pos + r_ua_perp * 4.5, r_shoulder_pos - r_ua_perp * 5.0,
		r_elbow - r_ua_perp * 3.0, r_elbow + r_ua_perp * 3.0,
	]), Color(0.06, 0.04, 0.08))
	draw_line(r_shoulder_pos.lerp(r_elbow, 0.15) - r_ua_perp * 3.0, r_shoulder_pos.lerp(r_elbow, 0.7) - r_ua_perp * 3.0, Color(0.12, 0.10, 0.15, 0.3), 1.0)
	# RIGHT FOREARM — polygon tapered toward aim
	var r_fa_dir = (r_hand_pos - r_elbow).normalized()
	var r_fa_perp = r_fa_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		r_elbow + r_fa_perp * 4.0, r_elbow - r_fa_perp * 4.0,
		r_elbow.lerp(r_hand_pos, 0.4) - r_fa_perp * 3.5,
		r_hand_pos - r_fa_perp * 2.5, r_hand_pos + r_fa_perp * 2.5,
		r_elbow.lerp(r_hand_pos, 0.4) + r_fa_perp * 3.5,
	]), Color(0.04, 0.03, 0.06))
	draw_colored_polygon(PackedVector2Array([
		r_elbow + r_fa_perp * 3.0, r_elbow - r_fa_perp * 3.0,
		r_hand_pos - r_fa_perp * 1.5, r_hand_pos + r_fa_perp * 1.5,
	]), Color(0.06, 0.04, 0.08))
	# Elbow joint
	draw_circle(r_elbow, 4.5, Color(0.04, 0.03, 0.06))
	draw_circle(r_elbow, 3.5, Color(0.06, 0.04, 0.08))
	# White glove cuff
	draw_arc(r_hand_pos + dir * (-4.0), 4.0, 0, TAU, 8, Color(0.95, 0.93, 0.91), 2.5)
	# White-gloved hand
	draw_circle(r_hand_pos, 4.0, Color(0.90, 0.88, 0.86))
	draw_circle(r_hand_pos, 3.2, Color(0.95, 0.93, 0.91))
	# Conducting fingers (extended elegantly)
	for fi in range(4):
		var fa = aim_angle + (float(fi) - 1.5) * 0.25
		draw_circle(r_hand_pos + Vector2.from_angle(fa) * 4.2, 1.5, Color(0.97, 0.95, 0.93))

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

	# === ELEGANT NECK (polygon-based, with white shirt collar) ===
	var neck_top = head_center + Vector2(0, 12)
	var neck_dir = (neck_top - neck_base).normalized()
	var neck_perp = neck_dir.rotated(PI / 2.0)
	# Dark outline
	draw_colored_polygon(PackedVector2Array([
		neck_base + neck_perp * 7.5, neck_base - neck_perp * 7.5,
		neck_base.lerp(neck_top, 0.5) - neck_perp * 6.5,
		neck_top - neck_perp * 5.5, neck_top + neck_perp * 5.5,
		neck_base.lerp(neck_top, 0.5) + neck_perp * 6.5,
	]), Color(0.04, 0.03, 0.06))
	# Skin shadow layer
	draw_colored_polygon(PackedVector2Array([
		neck_base + neck_perp * 6.5, neck_base - neck_perp * 6.5,
		neck_top - neck_perp * 4.5, neck_top + neck_perp * 4.5,
	]), skin_shadow)
	# Skin base layer
	draw_colored_polygon(PackedVector2Array([
		neck_base + neck_perp * 5.5, neck_base - neck_perp * 5.5,
		neck_top - neck_perp * 3.5, neck_top + neck_perp * 3.5,
	]), skin_base)
	# Neck highlight
	draw_line(neck_base.lerp(neck_top, 0.15) + neck_perp * 3.0, neck_base.lerp(neck_top, 0.85) + neck_perp * 2.5, skin_highlight, 2.0)
	# White shirt collar points (visible at neck base)
	var collar_l = PackedVector2Array([
		neck_base + Vector2(-8, 2),
		neck_base + Vector2(-4, -3),
		neck_base + Vector2(0, 2),
	])
	draw_colored_polygon(collar_l, Color(0.95, 0.93, 0.91))
	draw_line(neck_base + Vector2(-8, 2), neck_base + Vector2(-4, -3), Color(0.85, 0.83, 0.80, 0.4), 0.8)
	var collar_r = PackedVector2Array([
		neck_base + Vector2(0, 2),
		neck_base + Vector2(4, -3),
		neck_base + Vector2(8, 2),
	])
	draw_colored_polygon(collar_r, Color(0.95, 0.93, 0.91))
	draw_line(neck_base + Vector2(8, 2), neck_base + Vector2(4, -3), Color(0.85, 0.83, 0.80, 0.4), 0.8)

	# === HEAD (proportional anime head, smaller than chibi) ===
	var head_r = 12.0

	# Head base (pale skin)
	draw_circle(head_center, head_r + 1.0, Color(0.0, 0.0, 0.0, 0.15))
	draw_circle(head_center, head_r, skin_shadow)
	draw_circle(head_center, head_r - 1.0, skin_base)
	# Skin highlight (upper left)
	draw_circle(head_center + Vector2(-2, -3), head_r * 0.5, skin_highlight)

	# === DRAMATIC SWEPT-BACK HAIR (more flowing and romantic) ===
	# Hair covers top and left side of head with dramatic volume
	var hair_pts = PackedVector2Array([
		head_center + Vector2(-head_r + 1, 5),
		head_center + Vector2(-head_r, -3),
		head_center + Vector2(-head_r + 2, -8),
		head_center + Vector2(-4, -head_r - 4),    # More volume peak at crown
		head_center + Vector2(2, -head_r - 3),
		head_center + Vector2(6, -head_r - 1),
		head_center + Vector2(head_r - 1, -5),
		head_center + Vector2(head_r - 2, -1),
		head_center + Vector2(5, -1),
		head_center + Vector2(0, -3),
		head_center + Vector2(-3, -1),
		head_center + Vector2(-6, 0),
	])
	draw_colored_polygon(hair_pts, Color(0.06, 0.04, 0.06))
	# Hair highlight streaks (more contrast — alpha 0.35→0.50)
	draw_line(head_center + Vector2(-3, -head_r - 2), head_center + Vector2(-7, 2), Color(0.15, 0.12, 0.18, 0.50), 2.0)
	draw_line(head_center + Vector2(-1, -head_r - 3), head_center + Vector2(-4, -2), Color(0.18, 0.15, 0.22, 0.45), 1.5)
	draw_line(head_center + Vector2(2, -head_r - 1), head_center + Vector2(1, -4), Color(0.15, 0.12, 0.18, 0.40), 1.2)
	# Hair over right side (above mask)
	draw_line(head_center + Vector2(5, -head_r), head_center + Vector2(head_r - 2, -3), Color(0.06, 0.04, 0.06), 3.5)

	# Long strands cascading past jaw over left side (romantic drama)
	var hair_wave_ph = sin(_time * 1.5) * 2.0
	var long_strand_data = [
		[-head_r + 1, 5, 15, 2.5],     # leftmost strand
		[-head_r + 3, 3, 18, 2.0],     # second strand
		[-head_r + 5, 2, 16, 1.8],     # third strand
		[-5, 1, 13, 1.5],              # fourth — shorter
	]
	for lsd in long_strand_data:
		var lsx: float = lsd[0]
		var lsy: float = lsd[1]
		var ls_len: float = lsd[2]
		var ls_w: float = lsd[3]
		var wave_mod = sin(_time * 1.5 + lsx * 0.3) * 2.0
		# Draw as series of segments for wave motion
		var prev_pt = head_center + Vector2(lsx, lsy)
		for seg in range(5):
			var st = float(seg + 1) / 5.0
			var next_pt = head_center + Vector2(lsx + wave_mod * st + sin(_time * 1.5 + st * PI) * 1.5, lsy + ls_len * st)
			draw_line(prev_pt, next_pt, Color(0.06, 0.04, 0.06, 0.9 - st * 0.3), ls_w * (1.0 - st * 0.3))
			prev_pt = next_pt
	# 2-3 loose strands across mask edge (romantic drama)
	var mask_strand_wave = sin(_time * 2.0) * 1.5
	draw_line(head_center + Vector2(1, -head_r), head_center + Vector2(2 + mask_strand_wave, 4), Color(0.06, 0.04, 0.06, 0.5), 1.2)
	draw_line(head_center + Vector2(0, -head_r + 2), head_center + Vector2(1.5 + mask_strand_wave * 0.7, 2), Color(0.06, 0.04, 0.06, 0.4), 1.0)

	# === WHITE HALF-MASK (right side of face — refined with gold filigree) ===
	var mask_center = head_center + Vector2(4, -1)
	# Mask glow behind (faint glow even at T0)
	var mask_glow_alpha = 0.10 + sin(_time * 2.0) * 0.05
	draw_circle(mask_center, head_r * 0.7, Color(0.9, 0.9, 1.0, mask_glow_alpha))
	# Mask shape
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
	# Mask porcelain sheen (brighter)
	var mask_sheen_pts = PackedVector2Array([
		head_center + Vector2(2, -8),
		head_center + Vector2(6, -9),
		head_center + Vector2(8, -6),
		head_center + Vector2(7, -1),
		head_center + Vector2(4, -1),
		head_center + Vector2(2, -3),
	])
	draw_colored_polygon(mask_sheen_pts, Color(1.0, 1.0, 1.0, 0.40))
	# Brighter edge highlight
	draw_line(head_center + Vector2(1, -9), head_center + Vector2(1, 4), Color(0.80, 0.78, 0.76, 0.6), 1.4)
	# Secondary highlight line
	draw_line(head_center + Vector2(9, -6), head_center + Vector2(8, 3), Color(0.85, 0.83, 0.80, 0.3), 0.8)
	# Gold filigree decorative curls (2-3 arcs)
	draw_arc(head_center + Vector2(6, -6), 3.0, PI * 0.3, PI * 1.2, 8, Color(0.85, 0.72, 0.2, 0.25), 0.8)
	draw_arc(head_center + Vector2(8, 0), 2.5, PI * 0.5, PI * 1.5, 6, Color(0.85, 0.72, 0.2, 0.20), 0.8)
	draw_arc(head_center + Vector2(5, 3), 2.0, 0, PI, 6, Color(0.85, 0.72, 0.2, 0.18), 0.7)
	# Subtle tear track line (mystery)
	draw_line(head_center + Vector2(5, 0), head_center + Vector2(5.5, 5), Color(0.75, 0.73, 0.72, 0.15), 0.6)
	# Mask eye hole with faint glow
	var mask_eye_pos = head_center + Vector2(5, -2)
	draw_circle(mask_eye_pos, 3.2, Color(0.0, 0.0, 0.0, 0.35))
	draw_circle(mask_eye_pos, 2.2, Color(0.02, 0.02, 0.02, 0.25))
	# Faint glow around mask eye hole
	draw_circle(mask_eye_pos, 4.0, Color(0.6, 0.5, 0.8, 0.06 + sin(_time * 2.5) * 0.03))
	# Mask nostril hint
	draw_circle(head_center + Vector2(4, 2), 0.8, Color(0.85, 0.83, 0.80, 0.3))
	# Mask outline (slightly brighter)
	for mi in range(mask_pts.size()):
		var next_mi = (mi + 1) % mask_pts.size()
		draw_line(mask_pts[mi], mask_pts[next_mi], Color(0.82, 0.80, 0.78, 0.5), 0.9)

	# Tier 4: Mask eye glows bright red/orange
	if upgrade_tier >= 4:
		var eye_glow_alpha = 0.5 + sin(_time * 3.0) * 0.25
		draw_circle(mask_eye_pos, 3.8, Color(0.9, 0.2, 0.05, eye_glow_alpha * 0.3))
		draw_circle(mask_eye_pos, 2.5, Color(1.0, 0.35, 0.1, eye_glow_alpha * 0.5))
		draw_circle(mask_eye_pos, 1.2, Color(1.0, 0.6, 0.2, eye_glow_alpha * 0.7))

	# === LEFT SIDE VISIBLE FACE — dramatic single eye, more defined (handsome) ===
	var l_eye_pos = head_center + Vector2(-4, -2)
	# Eye socket shadow (deeper)
	draw_circle(l_eye_pos, 4.2, Color(0.55, 0.45, 0.42, 0.25))
	# Eye white (larger)
	draw_circle(l_eye_pos, 3.5, Color(0.96, 0.96, 0.96))
	# Iris (dark, intense — with ring detail)
	draw_circle(l_eye_pos + dir * 0.8, 2.4, Color(0.12, 0.08, 0.06))
	draw_circle(l_eye_pos + dir * 0.8, 1.8, Color(0.20, 0.15, 0.12))
	# Iris ring detail
	draw_arc(l_eye_pos + dir * 0.8, 2.2, 0, TAU, 10, Color(0.25, 0.18, 0.15, 0.3), 0.5)
	# Pupil
	draw_circle(l_eye_pos + dir * 1.0, 1.3, Color(0.02, 0.02, 0.02))
	# Primary catch light
	draw_circle(l_eye_pos + Vector2(-0.5, -1.0), 0.8, Color(1.0, 1.0, 1.0, 0.7))
	# Second catch light
	draw_circle(l_eye_pos + Vector2(0.8, 0.3), 0.4, Color(1.0, 1.0, 1.0, 0.4))
	# More dramatic eyebrow (wider, extended further)
	draw_line(head_center + Vector2(-8, -4.5), head_center + Vector2(-1.5, -6.5), Color(0.06, 0.04, 0.06), 2.2)
	# Under-eye shadow (more intense, tormented)
	draw_arc(l_eye_pos, 4.0, 0.3, PI - 0.3, 8, Color(0.50, 0.40, 0.45, 0.25), 1.2)
	# Eyelid (upper, intense)
	draw_arc(l_eye_pos, 3.5, PI + 0.3, TAU - 0.3, 8, Color(0.06, 0.04, 0.06), 1.5)

	# Right eyebrow (on mask, subtle sculpted line)
	draw_line(head_center + Vector2(2, -6), head_center + Vector2(8, -5), Color(0.80, 0.78, 0.76, 0.3), 1.3)

	# === CHEEKBONE AND JAW (more angular, more defined — handsome) ===
	# Cheekbone highlight arc on visible (left) side
	draw_arc(head_center + Vector2(-6, 1), 4.0, PI * 0.1, PI * 0.6, 8, Color(skin_highlight.r, skin_highlight.g, skin_highlight.b, 0.3), 1.2)
	# Jawline shadow under cheekbone
	draw_arc(head_center + Vector2(-6, 3), 3.5, PI * 0.2, PI * 0.8, 8, Color(0.55, 0.48, 0.44, 0.2), 1.0)
	# Strong angular jaw line (left side visible, right under mask)
	draw_line(head_center + Vector2(-10, 2), head_center + Vector2(-5, 9), Color(0.62, 0.55, 0.50, 0.45), 1.6)
	draw_line(head_center + Vector2(-5, 9), head_center + Vector2(1, 9), Color(0.62, 0.55, 0.50, 0.35), 1.3)
	# Stronger chin (larger, with subtle cleft)
	draw_circle(head_center + Vector2(-1, 9), 3.5, skin_shadow)
	draw_circle(head_center + Vector2(-1, 9), 2.8, skin_base)
	draw_circle(head_center + Vector2(-1.2, 9.3), 1.7, skin_highlight)
	# Subtle chin cleft
	draw_line(head_center + Vector2(-1, 8.5), head_center + Vector2(-1, 9.5), Color(0.65, 0.58, 0.52, 0.15), 0.6)
	# Fuller lip detail (upper and lower arcs with color)
	# Upper lip
	draw_line(head_center + Vector2(-5, 5), head_center + Vector2(0, 5.5), Color(0.65, 0.42, 0.38), 1.6)
	draw_arc(head_center + Vector2(-2.5, 5.2), 2.8, PI + 0.2, TAU - 0.2, 8, Color(0.70, 0.48, 0.42, 0.4), 0.8)
	# Lower lip (fuller)
	draw_arc(head_center + Vector2(-2.5, 5.8), 3.2, 0.2, PI - 0.2, 8, Color(0.72, 0.50, 0.46, 0.35), 1.0)
	# Lip corners
	draw_line(head_center + Vector2(-5, 5), head_center + Vector2(-6, 4.3), Color(0.60, 0.42, 0.38, 0.3), 0.7)
	draw_line(head_center + Vector2(0, 5.5), head_center + Vector2(1, 5.0), Color(0.60, 0.42, 0.38, 0.2), 0.6)
	# Elegant nose (left side visible, refined bridge)
	draw_line(head_center + Vector2(-1, -4), head_center + Vector2(-1.5, 1.5), Color(0.75, 0.68, 0.62, 0.4), 1.2)
	draw_line(head_center + Vector2(-1.5, 1.5), head_center + Vector2(-0.5, 2.8), Color(0.75, 0.68, 0.62, 0.3), 1.0)
	draw_circle(head_center + Vector2(-1, 2.8), 1.5, skin_highlight)

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
