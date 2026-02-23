extends Node2D
## Dracula — vampire lord tower. Drains life from enemies, summons bats, turns foes to minions.
## Tier 1 (5000 DMG): Vampiric Touch — life drain heals 10% of damage
## Tier 2 (10000 DMG): Bat Swarm — bats from ability also slow enemies 20%
## Tier 3 (15000 DMG): Thrall — killed enemies 15% chance to rise as friendly minion for 8s
## Tier 4 (20000 DMG): Lord of Darkness — 50% more damage, permanent bat cloud, 2% HP/sec drain

# Base stats
var damage: float = 28.0
var fire_rate: float = 1.6
var attack_range: float = 200.0
var fire_cooldown: float = 0.0
var aim_angle: float = 0.0
var target: Node2D = null
var _cast_anim: float = 0.0
var gold_bonus: int = 2

# Animation timers
var _time: float = 0.0
var _attack_anim: float = 0.0

# Damage tracking and upgrades
var damage_dealt: float = 0.0
var upgrade_tier: int = 0
var _upgrade_flash: float = 0.0
var _upgrade_name: String = ""

# Tier 1: Vampiric Touch — life drain percent
var life_drain_percent: float = 0.05

# Tier 2: Bat Swarm — bats slow enemies
var bat_slow_enabled: bool = false

# Tier 3: Thrall — killed enemies rise as minions
var thrall_chance: float = 0.0
var _active_thralls: Array = []

# Tier 4: Lord of Darkness
var lord_of_darkness: bool = false
var _darkness_aura_timer: float = 0.0

# Ability: Children of the Night — bat swarm
var ability_active: bool = false
var ability_timer: float = 0.0
var ability_cooldown: float = 20.0
var ability_ready: float = 0.0
var _bat_swarm_positions: Array = []
var _bat_swarm_flash: float = 0.0

# Kill tracking
var kill_count: int = 0

# === PROGRESSIVE ABILITIES (9 tiers, unlocked via lifetime damage) ===
const PROG_ABILITY_NAMES = [
	"Undead Fortitude", "Mist Form", "Wolf Companion", "Hypnotic Gaze",
	"Blood Moon", "Castle Defense", "Bride's Kiss", "Nosferatu Form",
	"Prince of Darkness"
]
const PROG_ABILITY_DESCS = [
	"Tower takes 30% less damage from enemy abilities, +15% damage",
	"Every 12s, become mist for 2s; bolts during deal 2x",
	"Every 18s, spectral wolf strikes weakest enemy for 4x",
	"Every 15s, confuse nearest enemy (walks backward) for 3s",
	"Every 25s, blood moon boosts all towers +20% damage for 5s",
	"Every 20s, bat sentinels block 2 enemies for 2s",
	"Every 22s, heal 1 life + drain strongest enemy for 6x",
	"Every 16s, transform — all attacks deal 3x for 4s",
	"Every 10s, dark wave hits ALL enemies on map for 2x"
]
var prog_abilities: Array = [false, false, false, false, false, false, false, false, false]
# Ability timers
var _mist_form_timer: float = 12.0
var _mist_form_active: float = 0.0
var _wolf_timer: float = 18.0
var _hypnotic_timer: float = 15.0
var _blood_moon_timer: float = 25.0
var _blood_moon_active: float = 0.0
var _castle_defense_timer: float = 20.0
var _brides_kiss_timer: float = 22.0
var _nosferatu_timer: float = 16.0
var _nosferatu_active: float = 0.0
var _prince_timer: float = 10.0
# Visual flash timers
var _wolf_flash: float = 0.0
var _blood_moon_flash: float = 0.0
var _castle_defense_flash: float = 0.0
var _prince_flash: float = 0.0

const STAT_UPGRADE_INTERVAL: float = 500.0
const ABILITY_THRESHOLD: float = 1500.0
var stat_upgrade_level: int = 0
var ability_chosen: bool = false
var awaiting_ability_choice: bool = false
const TIER_NAMES = [
	"Vampiric Touch",
	"Bat Swarm",
	"Thrall",
	"Lord of Darkness"
]
const ABILITY_DESCRIPTIONS = [
	"Life drain heals 10% of damage",
	"Bats from ability also slow enemies 20%",
	"Killed enemies 15% chance to rise as minion",
	"50% more damage, permanent bats, 2% HP/sec drain"
]
const TIER_COSTS = [80, 175, 300, 500]
var is_selected: bool = false
var base_cost: int = 0

var blood_bolt_scene = preload("res://scenes/blood_bolt.tscn")

# Attack sounds — dark swooshing whisper
var _attack_sounds: Array = []
var _attack_sounds_by_tier: Array = []
var _attack_player: AudioStreamPlayer

# Ability sounds
var _bat_screech_sound: AudioStreamWAV
var _bat_screech_player: AudioStreamPlayer
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

	# Bat screech swarm — layered high-pitched shrieks with flutter modulation
	var bat_rate := 22050
	var bat_dur := 0.8
	var bat_samples := PackedFloat32Array()
	bat_samples.resize(int(bat_rate * bat_dur))
	var bat_freqs := [2800.0, 3400.0, 4200.0, 3100.0]  # Multiple bat voices
	for i in bat_samples.size():
		var t := float(i) / bat_rate
		var s := 0.0
		for bi in range(bat_freqs.size()):
			var freq: float = bat_freqs[bi]
			var flutter := sin(TAU * (18.0 + float(bi) * 7.0) * t) * 0.5 + 0.5
			var env := exp(-t * 3.5) * flutter * 0.2
			var onset := minf(t * 40.0, 1.0)
			s += sin(TAU * freq * t + sin(TAU * 120.0 * t) * 3.0) * env * onset
		# Background flutter noise
		var noise_env := exp(-t * 4.0) * 0.08
		s += (randf() * 2.0 - 1.0) * noise_env
		bat_samples[i] = clampf(s, -1.0, 1.0)
	_bat_screech_sound = _samples_to_wav(bat_samples, bat_rate)
	_bat_screech_player = AudioStreamPlayer.new()
	_bat_screech_player.stream = _bat_screech_sound
	_bat_screech_player.volume_db = -8.0
	add_child(_bat_screech_player)

	# Upgrade chime — dark ascending minor arpeggio (C4→Eb4→G4)
	var up_rate := 22050
	var up_dur := 0.35
	var up_samples := PackedFloat32Array()
	up_samples.resize(int(up_rate * up_dur))
	var up_notes := [261.63, 311.13, 392.0]  # C4, Eb4, G4 (minor)
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
	_bat_swarm_flash = max(_bat_swarm_flash - delta * 2.0, 0.0)
	_attack_anim = max(_attack_anim - delta * 3.0, 0.0)
	target = _find_nearest_enemy()

	if target:
		var desired = global_position.angle_to_point(target.global_position) + PI
		aim_angle = lerp_angle(aim_angle, desired, 10.0 * delta)
		_cast_anim = min(_cast_anim + delta * 3.0, 1.0)
		if fire_cooldown <= 0.0:
			_shoot()
			fire_cooldown = 1.0 / (fire_rate * _speed_mult())
			_cast_anim = 0.0
			_attack_anim = 1.0
	else:
		_cast_anim = max(_cast_anim - delta * 2.0, 0.0)

	# Ability: Children of the Night — bat swarm
	if ability_active:
		ability_timer -= delta
		_process_bat_swarm(delta)
		if ability_timer <= 0.0:
			ability_active = false
			_bat_swarm_positions.clear()
	ability_ready = max(ability_ready - delta, 0.0)

	# Tier 4: Lord of Darkness — passive HP drain aura
	if lord_of_darkness:
		_darkness_aura_timer -= delta
		if _darkness_aura_timer <= 0.0:
			_darkness_aura_timer = 0.5  # Tick every 0.5s
			_apply_darkness_aura()

	# Progressive abilities
	_process_progressive_abilities(delta)

	# Manage thralls
	_update_thralls(delta)

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
	_fire_blood_bolt(target)

func _fire_blood_bolt(t: Node2D) -> void:
	var bolt = blood_bolt_scene.instantiate()
	bolt.global_position = global_position + Vector2.from_angle(aim_angle) * 18.0
	var dmg_mult = 1.0
	# Tier 4: Lord of Darkness — 50% more damage
	if lord_of_darkness:
		dmg_mult *= 1.5
	# Ability 1: Undead Fortitude — +15% damage
	if prog_abilities[0]:
		dmg_mult *= 1.15
	# Ability 2: Mist Form — 2x during mist
	if prog_abilities[1] and _mist_form_active > 0.0:
		dmg_mult *= 2.0
	# Ability 8: Nosferatu Form — 3x during transform
	if prog_abilities[7] and _nosferatu_active > 0.0:
		dmg_mult *= 3.0
	bolt.damage = damage * dmg_mult * _damage_mult()
	bolt.target = t
	bolt.gold_bonus = int(gold_bonus * _gold_mult())
	bolt.source_tower = self
	bolt.life_drain_percent = life_drain_percent
	# Ability 1: Undead Fortitude — faster bolts
	if prog_abilities[0]:
		bolt.speed *= 1.15
	get_tree().get_first_node_in_group("main").add_child(bolt)

func receive_life_drain(amount: float) -> void:
	# Heal nearby towers by the drain amount (represented as restoring HP to tower group)
	# In a tower defense, this manifests as a small heal indicator
	_upgrade_flash = max(_upgrade_flash, 0.3)
	# Could heal main lives in small amounts at higher tiers
	if upgrade_tier >= 1 and amount > 2.0:
		var main = get_tree().get_first_node_in_group("main")
		if main and main.has_method("restore_life") and randf() < 0.03:
			main.restore_life(1)

func activate_bat_swarm() -> void:
	if ability_ready > 0.0:
		return
	ability_active = true
	ability_timer = 5.0
	ability_ready = ability_cooldown
	_bat_swarm_flash = 1.0
	_bat_swarm_positions.clear()
	# Initialize bat positions in a ring
	for i in range(8):
		var a = TAU * float(i) / 8.0
		_bat_swarm_positions.append({
			"angle": a,
			"radius": attack_range * 0.6,
			"phase": randf() * TAU,
		})
	if _bat_screech_player and not _is_sfx_muted():
		_bat_screech_player.play()

func _process_bat_swarm(delta: float) -> void:
	# Bats orbit and damage enemies
	var tick_dmg = damage * 0.3 * delta  # Damage per second per bat
	for bat in _bat_swarm_positions:
		bat["angle"] += delta * 3.0
		var bat_pos = global_position + Vector2.from_angle(bat["angle"]) * bat["radius"]
		# Check for enemies near each bat
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if bat_pos.distance_to(enemy.global_position) < 25.0:
				if enemy.has_method("take_damage"):
					enemy.take_damage(tick_dmg * _damage_mult())
					register_damage(tick_dmg * _damage_mult())
				# Tier 2: Bats slow enemies
				if bat_slow_enabled and enemy.has_method("apply_slow"):
					enemy.apply_slow(0.8, 0.5)

func _apply_darkness_aura() -> void:
	# Enemies in range lose 2% HP per second (tick every 0.5s = 1% per tick)
	var eff_range = attack_range * _range_mult()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(enemy.global_position) < eff_range:
			if enemy.has_method("take_damage") and "health" in enemy and "max_health" in enemy:
				var drain = enemy.max_health * 0.01  # 1% per 0.5s tick = 2% per second
				enemy.take_damage(drain)
				register_damage(drain)

func _update_thralls(delta: float) -> void:
	var i = _active_thralls.size() - 1
	while i >= 0:
		_active_thralls[i]["life"] -= delta
		if _active_thralls[i]["life"] <= 0.0:
			_active_thralls.remove_at(i)
		i -= 1

func register_kill() -> void:
	kill_count += 1
	# Tier 3: Thrall chance
	if thrall_chance > 0.0 and randf() < thrall_chance:
		_active_thralls.append({
			"life": 8.0,
			"angle": randf() * TAU,
			"radius": 30.0 + randf() * 20.0,
		})
		_upgrade_flash = 1.0
		_upgrade_name = "Thrall Rises!"
	if kill_count % 10 == 0:
		var stolen = 3 + kill_count / 10
		var main = get_tree().get_first_node_in_group("main")
		if main:
			main.add_gold(stolen)
		_upgrade_flash = 1.0
		_upgrade_name = "Drained %d gold!" % stolen

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
		1: # Vampiric Touch — life drain heals 10%
			life_drain_percent = 0.10
			damage = 35.0
			fire_rate = 1.8
			attack_range = 220.0
		2: # Bat Swarm — bats slow enemies
			bat_slow_enabled = true
			damage = 45.0
			fire_rate = 2.0
			attack_range = 240.0
			gold_bonus = 3
		3: # Thrall — killed enemies rise as minions
			thrall_chance = 0.15
			damage = 55.0
			fire_rate = 2.2
			attack_range = 260.0
			gold_bonus = 4
		4: # Lord of Darkness — massive power spike
			lord_of_darkness = true
			damage = 70.0
			fire_rate = 2.5
			attack_range = 280.0
			gold_bonus = 6
			life_drain_percent = 0.15
			thrall_chance = 0.25

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
	return "Dracula"

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

func register_damage(amount: float) -> void:
	damage_dealt += amount
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("register_tower_damage"):
		main.register_tower_damage(main.TowerType.DRACULA, amount)

func _generate_tier_sounds() -> void:
	# Dark swooshing whisper — breathy noise + low sinusoidal sweep
	var dark_notes := [110.00, 130.81, 146.83, 174.61, 146.83, 130.81, 110.00, 146.83]  # A2, C3, D3, F3, D3, C3, A2, D3 (D minor dark arpeggio)
	var mix_rate := 44100
	_attack_sounds_by_tier = []

	# --- Tier 0: Simple dark whisper swoosh ---
	var t0 := []
	for note_idx in dark_notes.size():
		var freq: float = dark_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.18))
		for i in samples.size():
			var t := float(i) / mix_rate
			# Breathy whisper — filtered noise with tonal component
			var env := exp(-t * 15.0) * 0.3
			var onset := minf(t * 60.0, 1.0)
			var tone := sin(TAU * freq * t) * 0.4
			var sweep := sin(TAU * (freq * 2.0 + t * 800.0) * t) * 0.15 * exp(-t * 20.0)
			var breath := (randf() * 2.0 - 1.0) * exp(-t * 12.0) * 0.3
			samples[i] = clampf((tone + sweep + breath) * env * onset, -1.0, 1.0)
		t0.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t0)

	# --- Tier 1: Deeper vampiric swoosh with resonance ---
	var t1 := []
	for note_idx in dark_notes.size():
		var freq: float = dark_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.2))
		for i in samples.size():
			var t := float(i) / mix_rate
			var env := exp(-t * 12.0) * 0.35
			var onset := minf(t * 50.0, 1.0)
			var tone := sin(TAU * freq * t) * 0.45
			var h2 := sin(TAU * freq * 2.0 * t) * 0.15 * exp(-t * 18.0)
			var sweep := sin(TAU * (freq * 1.5 + t * 600.0) * t) * 0.12 * exp(-t * 16.0)
			var breath := (randf() * 2.0 - 1.0) * exp(-t * 10.0) * 0.25
			samples[i] = clampf((tone + h2 + sweep + breath) * env * onset, -1.0, 1.0)
		t1.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t1)

	# --- Tier 2: Menacing swoosh with bat flutter undertone ---
	var t2 := []
	for note_idx in dark_notes.size():
		var freq: float = dark_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.22))
		for i in samples.size():
			var t := float(i) / mix_rate
			var env := exp(-t * 10.0) * 0.35
			var onset := minf(t * 45.0, 1.0)
			var tone := sin(TAU * freq * t) * 0.4
			var h2 := sin(TAU * freq * 2.0 * t) * 0.18 * exp(-t * 14.0)
			# Bat wing flutter modulation
			var flutter := sin(TAU * 22.0 * t) * 0.3 + 0.7
			var sweep := sin(TAU * (freq * 3.0 + t * 500.0) * t) * 0.1 * exp(-t * 12.0)
			var breath := (randf() * 2.0 - 1.0) * exp(-t * 8.0) * 0.2
			samples[i] = clampf((tone + h2 + sweep) * env * onset * flutter + breath * env, -1.0, 1.0)
		t2.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t2)

	# --- Tier 3: Spectral swoosh with ghostly harmonics ---
	var t3 := []
	for note_idx in dark_notes.size():
		var freq: float = dark_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.24))
		for i in samples.size():
			var t := float(i) / mix_rate
			var env := exp(-t * 9.0) * 0.35
			var onset := minf(t * 40.0, 1.0)
			var tone := sin(TAU * freq * t) * 0.35
			var ghost := sin(TAU * freq * 3.0 * t + sin(TAU * 5.0 * t) * 2.0) * 0.12 * exp(-t * 12.0)
			var spectral := sin(TAU * freq * 5.0 * t) * 0.06 * exp(-t * 15.0)
			var flutter := sin(TAU * 18.0 * t) * 0.25 + 0.75
			var breath := (randf() * 2.0 - 1.0) * exp(-t * 7.0) * 0.18
			samples[i] = clampf((tone + ghost + spectral) * env * onset * flutter + breath * env, -1.0, 1.0)
		t3.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t3)

	# --- Tier 4: Lord of Darkness — deep reverberant dark power ---
	var t4 := []
	for note_idx in dark_notes.size():
		var freq: float = dark_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.28))
		for i in samples.size():
			var t := float(i) / mix_rate
			var env := exp(-t * 7.0) * 0.35
			var onset := minf(t * 35.0, 1.0)
			var tone := sin(TAU * freq * t) * 0.4
			var h2 := sin(TAU * freq * 2.0 * t) * 0.2
			var h3 := sin(TAU * freq * 3.0 * t) * 0.1 * exp(-t * 10.0)
			var sub := sin(TAU * freq * 0.5 * t) * 0.15 * exp(-t * 5.0)
			# Dark power shimmer
			var shimmer := sin(TAU * freq * 4.01 * t) * 0.06 * exp(-t * 8.0)
			shimmer += sin(TAU * freq * 3.99 * t) * 0.06 * exp(-t * 8.0)
			var flutter := sin(TAU * 15.0 * t) * 0.2 + 0.8
			var breath := (randf() * 2.0 - 1.0) * exp(-t * 6.0) * 0.15
			samples[i] = clampf((tone + h2 + h3 + sub + shimmer) * env * onset * flutter + breath * env, -1.0, 1.0)
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
	if main and main.survivor_progress.has(main.TowerType.DRACULA):
		var p = main.survivor_progress[main.TowerType.DRACULA]
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
	if prog_abilities[0]:  # Undead Fortitude: +15% damage applied in _fire_blood_bolt
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
	_wolf_flash = max(_wolf_flash - delta * 2.0, 0.0)
	_blood_moon_flash = max(_blood_moon_flash - delta * 1.5, 0.0)
	_castle_defense_flash = max(_castle_defense_flash - delta * 2.0, 0.0)
	_prince_flash = max(_prince_flash - delta * 2.0, 0.0)

	# Ability 2: Mist Form — invisibility cycle
	if prog_abilities[1]:
		if _mist_form_active > 0.0:
			_mist_form_active -= delta
		else:
			_mist_form_timer -= delta
			if _mist_form_timer <= 0.0:
				_mist_form_active = 2.0
				_mist_form_timer = 12.0

	# Ability 3: Wolf Companion — periodic strike
	if prog_abilities[2]:
		_wolf_timer -= delta
		if _wolf_timer <= 0.0 and _has_enemies_in_range():
			_wolf_strike()
			_wolf_timer = 18.0

	# Ability 4: Hypnotic Gaze — confuse nearest enemy
	if prog_abilities[3]:
		_hypnotic_timer -= delta
		if _hypnotic_timer <= 0.0 and _has_enemies_in_range():
			_hypnotic_gaze()
			_hypnotic_timer = 15.0

	# Ability 5: Blood Moon — boost all towers
	if prog_abilities[4]:
		if _blood_moon_active > 0.0:
			_blood_moon_active -= delta
		else:
			_blood_moon_timer -= delta
			if _blood_moon_timer <= 0.0:
				_blood_moon_activate()
				_blood_moon_timer = 25.0

	# Ability 6: Castle Defense — bat sentinels block enemies
	if prog_abilities[5]:
		_castle_defense_timer -= delta
		if _castle_defense_timer <= 0.0 and _has_enemies_in_range():
			_castle_defense()
			_castle_defense_timer = 20.0

	# Ability 7: Bride's Kiss — heal + drain strongest
	if prog_abilities[6]:
		_brides_kiss_timer -= delta
		if _brides_kiss_timer <= 0.0:
			_brides_kiss()
			_brides_kiss_timer = 22.0

	# Ability 8: Nosferatu Form — transform for 3x attacks
	if prog_abilities[7]:
		if _nosferatu_active > 0.0:
			_nosferatu_active -= delta
		else:
			_nosferatu_timer -= delta
			if _nosferatu_timer <= 0.0:
				_nosferatu_active = 4.0
				_nosferatu_timer = 16.0

	# Ability 9: Prince of Darkness — dark wave on all enemies
	if prog_abilities[8]:
		_prince_timer -= delta
		if _prince_timer <= 0.0:
			_prince_darkness_wave()
			_prince_timer = 10.0

func _wolf_strike() -> void:
	_wolf_flash = 1.0
	# Strike weakest enemy in range
	var weakest: Node2D = null
	var least_hp: float = 999999.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) < attack_range:
			if "health" in e and e.health < least_hp:
				least_hp = e.health
				weakest = e
	if weakest and weakest.has_method("take_damage"):
		var dmg = damage * 4.0
		weakest.take_damage(dmg)
		register_damage(dmg)

func _hypnotic_gaze() -> void:
	var nearest = _find_nearest_enemy()
	if nearest and nearest.has_method("apply_slow"):
		nearest.apply_slow(0.0, 3.0)  # Complete stop = confused/walking backward

func _blood_moon_activate() -> void:
	_blood_moon_flash = 1.0
	_blood_moon_active = 5.0
	# Boost all towers +20% damage for 5s
	for tower in get_tree().get_nodes_in_group("towers"):
		if tower.has_method("set_synergy_buff"):
			tower.set_synergy_buff({"damage": 0.20})

func _castle_defense() -> void:
	_castle_defense_flash = 1.0
	# Block 2 nearest enemies (stun them) for 2s
	var enemies = get_tree().get_nodes_in_group("enemies")
	var in_range: Array = []
	for e in enemies:
		if global_position.distance_to(e.global_position) < attack_range:
			in_range.append(e)
	in_range.sort_custom(func(a, b): return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position))
	for i in range(mini(2, in_range.size())):
		if in_range[i].has_method("apply_sleep"):
			in_range[i].apply_sleep(2.0)

func _brides_kiss() -> void:
	# Heal 1 life
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("restore_life"):
		main.restore_life(1)
	# Drain strongest enemy in range
	var strongest: Node2D = null
	var most_hp: float = 0.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) < attack_range:
			if "health" in e and e.health > most_hp:
				most_hp = e.health
				strongest = e
	if strongest and strongest.has_method("take_damage"):
		var dmg = damage * 6.0
		strongest.take_damage(dmg)
		register_damage(dmg)

func _prince_darkness_wave() -> void:
	_prince_flash = 1.0
	# Dark wave damages ALL enemies on map
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("take_damage"):
			var dmg = damage * 2.0
			e.take_damage(dmg)
			register_damage(dmg)

func _draw() -> void:
	# === 1. SELECTION RING ===
	if is_selected:
		var pulse = (sin(_time * 3.0) + 1.0) * 0.5
		var ring_alpha = 0.5 + pulse * 0.3
		draw_arc(Vector2.ZERO, 40.0, 0, TAU, 48, Color(0.8, 0.1, 0.1, ring_alpha), 2.5)
		draw_arc(Vector2.ZERO, 43.0, 0, TAU, 48, Color(0.8, 0.1, 0.1, ring_alpha * 0.4), 1.5)

	# === 2. RANGE ARC ===
	draw_arc(Vector2.ZERO, attack_range, 0, TAU, 64, Color(1, 1, 1, 0.06), 1.0)

	# === 3. AIM DIRECTION ===
	var dir = Vector2.from_angle(aim_angle)
	var perp = dir.rotated(PI / 2.0)

	# === 4. IDLE ANIMATION (ominous sway, slow and deliberate) ===
	var breathe = sin(_time * 1.5) * 2.0
	var weight_shift = sin(_time * 0.8) * 1.5  # Slow, predatory sway
	var bob = Vector2(weight_shift, -abs(sin(_time * 1.5)) * 2.0 - breathe)

	# Tier 4: Levitation (lord hovering)
	var fly_offset = Vector2.ZERO
	if upgrade_tier >= 4:
		fly_offset = Vector2(0, -12.0 + sin(_time * 1.2) * 4.0)

	var body_offset = bob + fly_offset

	# Per-joint differential offsets
	var hip_shift = sin(_time * 0.8) * 1.0
	var shoulder_counter = -sin(_time * 0.8) * 0.6

	# Cape physics
	var cape_wind = sin(_time * 1.5) * 4.0 + sin(_time * 2.3) * 2.0
	var cape_flutter = sin(_time * 3.5) * 1.5

	# === 5. SKIN COLORS (pale vampire) ===
	var skin_base = Color(0.88, 0.85, 0.82)
	var skin_shadow = Color(0.72, 0.68, 0.66)
	var skin_highlight = Color(0.95, 0.92, 0.90)

	# === 6. UPGRADE FLASH ===
	if _upgrade_flash > 0.0:
		draw_circle(Vector2.ZERO, 80.0 + _upgrade_flash * 24.0, Color(0.5, 0.05, 0.05, _upgrade_flash * 0.25))

	# === 7. BAT SWARM FLASH (ability) ===
	if _bat_swarm_flash > 0.0:
		var bat_ring_r = 36.0 + (1.0 - _bat_swarm_flash) * 70.0
		draw_circle(Vector2.ZERO, bat_ring_r, Color(0.3, 0.0, 0.0, _bat_swarm_flash * 0.15))
		draw_arc(Vector2.ZERO, bat_ring_r, 0, TAU, 32, Color(0.6, 0.1, 0.1, _bat_swarm_flash * 0.3), 2.5)
		for bi in range(8):
			var ba = TAU * float(bi) / 8.0 + _bat_swarm_flash * 3.0
			var b_inner = Vector2.from_angle(ba) * (bat_ring_r * 0.5)
			var b_outer = Vector2.from_angle(ba) * (bat_ring_r + 5.0)
			draw_line(b_inner, b_outer, Color(0.5, 0.05, 0.05, _bat_swarm_flash * 0.4), 1.5)

	# === PROGRESSIVE ABILITY VISUAL EFFECTS ===
	# Ability 2: Mist Form — translucent mist effect
	if prog_abilities[1] and _mist_form_active > 0.0:
		for mi in range(6):
			var ma = TAU * float(mi) / 6.0 + _time * 0.8
			var mpos = body_offset + Vector2.from_angle(ma) * 25.0
			draw_circle(mpos, 8.0, Color(0.6, 0.6, 0.7, 0.08))
		draw_circle(body_offset, 35.0, Color(0.5, 0.5, 0.6, 0.06))

	# Ability 3: Wolf flash
	if _wolf_flash > 0.0:
		var wolf_pos = body_offset + Vector2(25.0 * (1.0 - _wolf_flash), 5.0)
		# Wolf silhouette (simple shape)
		draw_circle(wolf_pos, 6.0, Color(0.3, 0.3, 0.3, _wolf_flash * 0.6))
		draw_circle(wolf_pos + Vector2(4, -2), 3.5, Color(0.25, 0.25, 0.25, _wolf_flash * 0.5))
		# Eyes
		draw_circle(wolf_pos + Vector2(5, -3), 0.8, Color(1.0, 0.3, 0.0, _wolf_flash * 0.8))
		draw_circle(wolf_pos + Vector2(5, -1.5), 0.8, Color(1.0, 0.3, 0.0, _wolf_flash * 0.8))

	# Ability 5: Blood Moon flash
	if _blood_moon_flash > 0.0:
		var moon_y = -80.0 + (1.0 - _blood_moon_flash) * 10.0
		draw_circle(Vector2(0, moon_y), 12.0, Color(0.7, 0.1, 0.05, _blood_moon_flash * 0.5))
		draw_circle(Vector2(0, moon_y), 9.0, Color(0.85, 0.15, 0.08, _blood_moon_flash * 0.6))
		draw_circle(Vector2(0, moon_y), 15.0, Color(0.5, 0.05, 0.02, _blood_moon_flash * 0.15))

	# Ability 6: Castle Defense flash
	if _castle_defense_flash > 0.0:
		for ci in range(4):
			var ca = TAU * float(ci) / 4.0 + _castle_defense_flash * 2.0
			var cpos = Vector2.from_angle(ca) * 30.0
			# Bat sentinel shape
			draw_line(cpos - Vector2(4, 0), cpos + Vector2(4, 0), Color(0.2, 0.0, 0.0, _castle_defense_flash * 0.5), 2.0)
			draw_line(cpos, cpos + Vector2(-3, -3), Color(0.2, 0.0, 0.0, _castle_defense_flash * 0.4), 1.5)
			draw_line(cpos, cpos + Vector2(3, -3), Color(0.2, 0.0, 0.0, _castle_defense_flash * 0.4), 1.5)

	# Ability 9: Prince of Darkness flash — dark wave expanding
	if _prince_flash > 0.0:
		var wave_r = 30.0 + (1.0 - _prince_flash) * 120.0
		draw_arc(Vector2.ZERO, wave_r, 0, TAU, 32, Color(0.3, 0.0, 0.0, _prince_flash * 0.4), 3.0)
		draw_arc(Vector2.ZERO, wave_r * 0.7, 0, TAU, 24, Color(0.4, 0.02, 0.02, _prince_flash * 0.25), 2.0)

	# === 8. DARK STONE PLATFORM with red mist ===
	var plat_y = 22.0
	# Platform shadow
	draw_circle(Vector2(0, plat_y + 4), 28.0, Color(0, 0, 0, 0.2))
	# Dark stone platform ellipse
	draw_set_transform(Vector2(0, plat_y), 0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 28.0, Color(0.10, 0.08, 0.08))
	draw_circle(Vector2.ZERO, 25.0, Color(0.16, 0.12, 0.12))
	draw_circle(Vector2.ZERO, 20.0, Color(0.22, 0.18, 0.18))
	# Stone texture
	for si in range(8):
		var sa = TAU * float(si) / 8.0
		draw_circle(Vector2.from_angle(sa) * 16.0, 3.0, Color(0.14, 0.10, 0.10, 0.4))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# Platform top highlight
	draw_set_transform(Vector2(0, plat_y - 2), 0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 22.0, Color(0.28, 0.22, 0.22, 0.3))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	# Red mist/fog at base
	for fi in range(7):
		var fa = TAU * float(fi) / 7.0 + _time * 0.4
		var fx = cos(fa) * 22.0 + sin(_time * 0.6 + float(fi)) * 4.0
		var fy = plat_y + sin(fa) * 6.0
		var fsize = 6.0 + sin(_time * 1.0 + float(fi) * 1.3) * 2.0
		var falpha = 0.06 + sin(_time * 0.8 + float(fi)) * 0.02
		# T1+ intensify red mist
		if upgrade_tier >= 1:
			falpha += 0.02 * float(upgrade_tier)
		draw_circle(Vector2(fx, fy), fsize, Color(0.5, 0.02, 0.02, falpha))
		draw_circle(Vector2(fx, fy + 2), fsize * 0.7, Color(0.35, 0.0, 0.0, falpha * 0.6))

	# === 9. SHADOW TENDRILS ===
	for ti in range(6):
		var ta = TAU * float(ti) / 6.0 + _time * 0.25
		var t_base = Vector2(cos(ta) * 24.0, plat_y + sin(ta) * 8.0)
		var t_end = t_base + Vector2(sin(_time * 0.7 + float(ti)) * 7.0, 8.0 + sin(_time * 1.0 + float(ti)) * 4.0)
		draw_line(t_base, t_end, Color(0.15, 0.0, 0.0, 0.2), 2.0)
		draw_line(t_end, t_end + Vector2(sin(_time + float(ti)) * 4.0, 5.0), Color(0.1, 0.0, 0.0, 0.12), 1.5)

	# === 10. TIER PIPS (blood red / dark crimson / bone white / black) ===
	for i in range(upgrade_tier):
		var pip_angle = -PI / 2.0 + float(i) * (TAU / 4.0) - (float(upgrade_tier - 1) * TAU / 8.0)
		var pip_pos = Vector2(cos(pip_angle) * 22.0, plat_y + sin(pip_angle) * 8.0)
		var pip_col: Color
		match i:
			0: pip_col = Color(0.7, 0.1, 0.1)    # blood red
			1: pip_col = Color(0.4, 0.0, 0.15)    # dark crimson
			2: pip_col = Color(0.85, 0.82, 0.78)   # bone white
			3: pip_col = Color(0.15, 0.0, 0.05)    # near-black
		draw_circle(pip_pos, 4.0, pip_col)
		draw_circle(pip_pos, 5.5, Color(pip_col.r, pip_col.g, pip_col.b, 0.15))

	# === 11. TIER-SPECIFIC EFFECTS (drawn BEFORE body) ===

	# Tier 1+: Red mist particles swirling
	if upgrade_tier >= 1:
		for li in range(5 + upgrade_tier * 2):
			var la = _time * (0.4 + fmod(float(li) * 1.37, 0.4)) + float(li) * TAU / float(5 + upgrade_tier * 2)
			var lr = 20.0 + fmod(float(li) * 3.7, 18.0)
			var mist_pos = body_offset + Vector2(cos(la) * lr, sin(la) * lr * 0.5 + 12.0)
			var mist_alpha = 0.12 + sin(_time * 1.5 + float(li)) * 0.04
			var mist_size = 2.0 + sin(_time * 1.0 + float(li) * 2.0) * 0.8
			draw_circle(mist_pos, mist_size, Color(0.5, 0.02, 0.02, mist_alpha))

	# Tier 2+: Small bats circling
	if upgrade_tier >= 2:
		var bat_count = 3 + upgrade_tier
		for bi in range(bat_count):
			var ba = _time * (1.5 + fmod(float(bi) * 0.7, 0.8)) + float(bi) * TAU / float(bat_count)
			var br = 35.0 + sin(_time * 2.0 + float(bi) * 1.5) * 8.0
			var bat_pos = body_offset + Vector2(cos(ba) * br, sin(ba) * br * 0.4 - 10.0)
			var bat_alpha = 0.35 + sin(_time * 3.0 + float(bi)) * 0.1
			# Wing flap animation
			var wing_flap = sin(_time * 12.0 + float(bi) * 2.0) * 3.0
			# Bat body
			draw_circle(bat_pos, 1.5, Color(0.12, 0.05, 0.05, bat_alpha))
			# Wings
			draw_line(bat_pos, bat_pos + Vector2(-3.5, wing_flap - 1.5), Color(0.15, 0.05, 0.05, bat_alpha * 0.8), 1.2)
			draw_line(bat_pos, bat_pos + Vector2(3.5, wing_flap - 1.5), Color(0.15, 0.05, 0.05, bat_alpha * 0.8), 1.2)
			# Wing membrane
			draw_line(bat_pos + Vector2(-3.5, wing_flap - 1.5), bat_pos + Vector2(-2, wing_flap), Color(0.18, 0.06, 0.06, bat_alpha * 0.5), 0.8)
			draw_line(bat_pos + Vector2(3.5, wing_flap - 1.5), bat_pos + Vector2(2, wing_flap), Color(0.18, 0.06, 0.06, bat_alpha * 0.5), 0.8)

	# Tier 3+: Spectral thrall outlines
	if upgrade_tier >= 3:
		for thr in _active_thralls:
			thr["angle"] += 0.01
			var thr_pos = body_offset + Vector2.from_angle(thr["angle"]) * thr["radius"]
			var thr_alpha = clampf(thr["life"] / 8.0, 0.0, 1.0) * 0.3
			# Ghost figure outline
			draw_circle(thr_pos + Vector2(0, -4), 3.5, Color(0.4, 0.6, 0.4, thr_alpha))
			draw_circle(thr_pos, 4.0, Color(0.3, 0.5, 0.3, thr_alpha * 0.7))
			draw_line(thr_pos + Vector2(0, 4), thr_pos + Vector2(0, 8), Color(0.3, 0.5, 0.3, thr_alpha * 0.5), 2.0)
			# Glowing eyes
			draw_circle(thr_pos + Vector2(-1.5, -5), 0.6, Color(0.8, 0.2, 0.1, thr_alpha * 2.0))
			draw_circle(thr_pos + Vector2(1.5, -5), 0.6, Color(0.8, 0.2, 0.1, thr_alpha * 2.0))

	# Tier 4: Full darkness aura + red moonlight
	if upgrade_tier >= 4:
		# Darkness aura — pulsing dark circle
		var dark_pulse = sin(_time * 2.0) * 6.0
		draw_circle(body_offset, 55.0 + dark_pulse, Color(0.08, 0.0, 0.02, 0.06))
		draw_circle(body_offset, 45.0 + dark_pulse * 0.6, Color(0.12, 0.0, 0.03, 0.08))
		draw_arc(body_offset, 52.0 + dark_pulse, 0, TAU, 32, Color(0.4, 0.05, 0.05, 0.12), 2.5)
		# Red moonlight overhead
		var moon_glow = sin(_time * 1.5) * 0.03 + 0.12
		draw_circle(body_offset + Vector2(0, -70), 10.0, Color(0.7, 0.1, 0.05, moon_glow))
		draw_circle(body_offset + Vector2(0, -70), 7.0, Color(0.85, 0.15, 0.08, moon_glow * 1.2))
		draw_circle(body_offset + Vector2(0, -70), 4.0, Color(0.95, 0.25, 0.15, moon_glow * 1.5))
		# Moonlight beam down to Dracula
		for beam_i in range(3):
			var bx = float(beam_i - 1) * 5.0
			draw_line(body_offset + Vector2(bx, -60), body_offset + Vector2(bx * 0.3, -20), Color(0.6, 0.08, 0.05, 0.04), 3.0)

	# === 12. ACTIVE BAT SWARM (ability visual) ===
	if ability_active:
		for bat in _bat_swarm_positions:
			var bpos = Vector2.from_angle(bat["angle"]) * bat["radius"]
			var wing_f = sin(_time * 14.0 + bat["phase"]) * 4.0
			# Bat body (larger than tier bats)
			draw_circle(bpos, 2.5, Color(0.15, 0.02, 0.02, 0.7))
			# Wings
			draw_line(bpos, bpos + Vector2(-6, wing_f - 2), Color(0.2, 0.02, 0.02, 0.6), 1.8)
			draw_line(bpos, bpos + Vector2(6, wing_f - 2), Color(0.2, 0.02, 0.02, 0.6), 1.8)
			# Wing tips
			draw_line(bpos + Vector2(-6, wing_f - 2), bpos + Vector2(-4, wing_f + 1), Color(0.18, 0.02, 0.02, 0.4), 1.2)
			draw_line(bpos + Vector2(6, wing_f - 2), bpos + Vector2(4, wing_f + 1), Color(0.18, 0.02, 0.02, 0.4), 1.2)
			# Red eyes
			draw_circle(bpos + Vector2(-1, -1), 0.5, Color(0.9, 0.15, 0.1, 0.8))
			draw_circle(bpos + Vector2(1, -1), 0.5, Color(0.9, 0.15, 0.1, 0.8))

	# === 13. CHARACTER POSITIONS (tall, thin vampire ~58px) ===
	var feet_y = body_offset + Vector2(hip_shift * 0.8, 14.0)
	var leg_top = body_offset + Vector2(hip_shift * 0.5, -2.0)
	var torso_center = body_offset + Vector2(shoulder_counter * 0.4, -12.0)
	var neck_base = body_offset + Vector2(shoulder_counter * 0.6, -22.0)
	var head_center = body_offset + Vector2(shoulder_counter * 0.3, -34.0)

	# === 14. LARGE DRAMATIC CAPE (drawn BEHIND body) ===
	# Cape with red lining — physics animation
	var cape_top_l = neck_base + Vector2(-10, -2)
	var cape_top_r = neck_base + Vector2(10, -2)
	var cape_mid_l = torso_center + Vector2(-18 + cape_wind * 0.4, 6.0)
	var cape_mid_r = torso_center + Vector2(18 + cape_wind * 0.3, 8.0)
	var cape_bot_l = feet_y + Vector2(-22 + cape_wind * 0.7, 10.0 + cape_flutter)
	var cape_bot_r = feet_y + Vector2(22 + cape_wind * 0.5, 12.0 + cape_flutter * 0.8)
	var cape_center_bot = feet_y + Vector2(cape_wind * 0.3, 14.0 + cape_flutter * 0.5)

	# Cape outer (black)
	draw_colored_polygon(PackedVector2Array([
		cape_top_l, cape_top_r, cape_mid_r, cape_bot_r,
		cape_center_bot, cape_bot_l, cape_mid_l,
	]), Color(0.06, 0.04, 0.06))
	# Cape darker folds
	draw_colored_polygon(PackedVector2Array([
		cape_top_l, cape_top_l.lerp(cape_top_r, 0.4),
		cape_mid_l.lerp(cape_mid_r, 0.3), cape_mid_l,
	]), Color(0.04, 0.02, 0.04, 0.6))
	# Cape red lining (visible at edges where cape billows)
	var lining_alpha = 0.3 + abs(cape_wind) * 0.02
	draw_colored_polygon(PackedVector2Array([
		cape_top_r + Vector2(-2, 1), cape_top_r,
		cape_mid_r, cape_mid_r + Vector2(-4, -2),
	]), Color(0.55, 0.05, 0.05, lining_alpha))
	draw_colored_polygon(PackedVector2Array([
		cape_top_l, cape_top_l + Vector2(2, 1),
		cape_mid_l + Vector2(4, -2), cape_mid_l,
	]), Color(0.55, 0.05, 0.05, lining_alpha * 0.8))
	# Cape bottom red lining peek
	draw_colored_polygon(PackedVector2Array([
		cape_mid_r + Vector2(-2, 0), cape_mid_r,
		cape_bot_r, cape_bot_r + Vector2(-3, -2),
	]), Color(0.5, 0.04, 0.04, lining_alpha * 0.6))
	# Cape fold lines
	draw_line(cape_top_l.lerp(cape_top_r, 0.3), cape_mid_l.lerp(cape_mid_r, 0.2), Color(0.02, 0.0, 0.02, 0.4), 0.8)
	draw_line(cape_top_l.lerp(cape_top_r, 0.6), cape_mid_l.lerp(cape_mid_r, 0.55), Color(0.02, 0.0, 0.02, 0.35), 0.8)
	draw_line(cape_top_l.lerp(cape_top_r, 0.8), cape_mid_l.lerp(cape_mid_r, 0.75), Color(0.02, 0.0, 0.02, 0.3), 0.7)
	# Cape edge highlight
	draw_line(cape_top_r, cape_mid_r, Color(0.15, 0.08, 0.12, 0.3), 1.0)
	draw_line(cape_top_l, cape_mid_l, Color(0.15, 0.08, 0.12, 0.25), 1.0)

	# Bat-shaped cape clasps at shoulders
	for ci in range(2):
		var clasp_x = -9.0 if ci == 0 else 9.0
		var clasp_pos = neck_base + Vector2(clasp_x, -1)
		# Bat silhouette clasp
		draw_circle(clasp_pos, 2.5, Color(0.25, 0.18, 0.18))
		draw_circle(clasp_pos, 1.8, Color(0.35, 0.25, 0.25))
		# Wings
		draw_line(clasp_pos, clasp_pos + Vector2(-2.5, -1.5), Color(0.3, 0.2, 0.2), 1.0)
		draw_line(clasp_pos, clasp_pos + Vector2(2.5, -1.5), Color(0.3, 0.2, 0.2), 1.0)

	# === 15. CHARACTER BODY ===

	# --- Formal pointed shoes (vampire elegance) ---
	var l_foot = feet_y + Vector2(-6, 0)
	var r_foot = feet_y + Vector2(6, 0)
	# Shoe base (polished black leather)
	draw_circle(l_foot, 5.0, Color(0.08, 0.05, 0.06))
	draw_circle(l_foot, 3.8, Color(0.12, 0.08, 0.10))
	draw_circle(r_foot, 5.0, Color(0.08, 0.05, 0.06))
	draw_circle(r_foot, 3.8, Color(0.12, 0.08, 0.10))
	# Pointed toe
	draw_line(l_foot + Vector2(-3, 0), l_foot + Vector2(-8, -2), Color(0.10, 0.06, 0.08), 3.5)
	draw_circle(l_foot + Vector2(-8, -2), 2.0, Color(0.08, 0.05, 0.06))
	draw_line(r_foot + Vector2(3, 0), r_foot + Vector2(8, -2), Color(0.10, 0.06, 0.08), 3.5)
	draw_circle(r_foot + Vector2(8, -2), 2.0, Color(0.08, 0.05, 0.06))
	# Shoe shine highlight
	draw_arc(l_foot, 3.0, PI + 0.4, TAU - 0.4, 6, Color(0.25, 0.2, 0.22, 0.3), 1.0)
	draw_arc(r_foot, 3.0, PI + 0.4, TAU - 0.4, 6, Color(0.25, 0.2, 0.22, 0.3), 1.0)
	# Silver buckle on shoes
	draw_circle(l_foot + Vector2(-1, -1), 1.2, Color(0.6, 0.58, 0.55))
	draw_circle(l_foot + Vector2(-1, -1), 0.7, Color(0.75, 0.72, 0.68))
	draw_circle(r_foot + Vector2(1, -1), 1.2, Color(0.6, 0.58, 0.55))
	draw_circle(r_foot + Vector2(1, -1), 0.7, Color(0.75, 0.72, 0.68))
	# Boot shaft (tall riding-style)
	var l_boot_shaft = PackedVector2Array([
		l_foot + Vector2(-4.0, -2), l_foot + Vector2(4.0, -2),
		l_foot + Vector2(3.5, -8), l_foot + Vector2(-3.5, -8),
	])
	draw_colored_polygon(l_boot_shaft, Color(0.10, 0.06, 0.08))
	var r_boot_shaft = PackedVector2Array([
		r_foot + Vector2(-4.0, -2), r_foot + Vector2(4.0, -2),
		r_foot + Vector2(3.5, -8), r_foot + Vector2(-3.5, -8),
	])
	draw_colored_polygon(r_boot_shaft, Color(0.10, 0.06, 0.08))
	# Boot top cuffs
	draw_line(l_foot + Vector2(-4.0, -7), l_foot + Vector2(4.0, -7), Color(0.15, 0.10, 0.12), 2.0)
	draw_line(r_foot + Vector2(-4.0, -7), r_foot + Vector2(4.0, -7), Color(0.15, 0.10, 0.12), 2.0)

	# --- THIN LEGS (formal trousers) ---
	var l_hip = leg_top + Vector2(-5, 0)
	var r_hip = leg_top + Vector2(5, 0)
	var l_knee = l_foot.lerp(l_hip, 0.45) + Vector2(-1, 0)
	var r_knee = r_foot.lerp(r_hip, 0.45) + Vector2(1, 0)
	# LEFT leg — slim black trousers
	var lt_dir = (l_knee - l_hip).normalized()
	var lt_perp = lt_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		l_hip + lt_perp * 4.0, l_hip - lt_perp * 3.5,
		l_knee - lt_perp * 3.0, l_knee + lt_perp * 3.5,
	]), Color(0.08, 0.05, 0.06))
	draw_colored_polygon(PackedVector2Array([
		l_hip + lt_perp * 2.5, l_hip - lt_perp * 2.0,
		l_knee - lt_perp * 2.0, l_knee + lt_perp * 2.0,
	]), Color(0.12, 0.08, 0.10, 0.5))
	# RIGHT leg
	var rt_dir = (r_knee - r_hip).normalized()
	var rt_perp = rt_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		r_hip - rt_perp * 4.0, r_hip + rt_perp * 3.5,
		r_knee + rt_perp * 3.0, r_knee - rt_perp * 3.5,
	]), Color(0.08, 0.05, 0.06))
	draw_colored_polygon(PackedVector2Array([
		r_hip - rt_perp * 2.5, r_hip + rt_perp * 2.0,
		r_knee + rt_perp * 2.0, r_knee - rt_perp * 2.0,
	]), Color(0.12, 0.08, 0.10, 0.5))
	# Knee joints
	draw_circle(l_knee, 3.5, Color(0.08, 0.05, 0.06))
	draw_circle(r_knee, 3.5, Color(0.08, 0.05, 0.06))
	# LEFT CALF
	var lc_dir = (l_foot + Vector2(0, -3) - l_knee).normalized()
	var lc_perp = lc_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		l_knee + lc_perp * 3.5, l_knee - lc_perp * 3.0,
		l_foot + Vector2(-3, -3), l_foot + Vector2(3, -3),
	]), Color(0.08, 0.05, 0.06))
	# RIGHT CALF
	var rc_dir = (r_foot + Vector2(0, -3) - r_knee).normalized()
	var rc_perp = rc_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		r_knee - rc_perp * 3.5, r_knee + rc_perp * 3.0,
		r_foot + Vector2(3, -3), r_foot + Vector2(-3, -3),
	]), Color(0.08, 0.05, 0.06))
	# Trouser crease lines
	draw_line(l_hip, l_knee, Color(0.04, 0.02, 0.04, 0.3), 0.6)
	draw_line(r_hip, r_knee, Color(0.04, 0.02, 0.04, 0.3), 0.6)

	# --- FORMAL BLACK SUIT WITH HIGH COLLAR ---
	# Torso — tall, thin, aristocratic V-taper
	var suit_pts = PackedVector2Array([
		leg_top + Vector2(-7, 0),         # waist left
		leg_top + Vector2(-8, -3),        # taper
		torso_center + Vector2(-12, 0),   # mid chest
		neck_base + Vector2(-14, 0),      # shoulder left
		neck_base + Vector2(14, 0),       # shoulder right
		torso_center + Vector2(12, 0),    # mid chest
		leg_top + Vector2(8, -3),         # taper
		leg_top + Vector2(7, 0),          # waist right
	])
	draw_colored_polygon(suit_pts, Color(0.06, 0.04, 0.06))

	# Suit jacket lapels
	var lapel_l = PackedVector2Array([
		neck_base + Vector2(-3, 0),
		neck_base + Vector2(-12, 1),
		torso_center + Vector2(-8, 2),
		torso_center + Vector2(-2, -2),
	])
	draw_colored_polygon(lapel_l, Color(0.08, 0.05, 0.07))
	var lapel_r = PackedVector2Array([
		neck_base + Vector2(3, 0),
		neck_base + Vector2(12, 1),
		torso_center + Vector2(8, 2),
		torso_center + Vector2(2, -2),
	])
	draw_colored_polygon(lapel_r, Color(0.08, 0.05, 0.07))
	# Lapel edges
	draw_line(neck_base + Vector2(-3, 0), torso_center + Vector2(-2, -2), Color(0.12, 0.08, 0.10, 0.5), 0.8)
	draw_line(neck_base + Vector2(3, 0), torso_center + Vector2(2, -2), Color(0.12, 0.08, 0.10, 0.5), 0.8)

	# Suit inner highlight (subtle fabric sheen)
	draw_colored_polygon(PackedVector2Array([
		torso_center + Vector2(-5, -5),
		torso_center + Vector2(5, -5),
		torso_center + Vector2(4, 3),
		torso_center + Vector2(-4, 3),
	]), Color(0.10, 0.06, 0.08, 0.3))

	# Suit buttons (3 dark buttons)
	for bi in range(3):
		var by = torso_center.y - 3.0 + float(bi) * 4.0
		var btn_pos = Vector2(body_offset.x + shoulder_counter * 0.4, by)
		draw_circle(btn_pos, 1.2, Color(0.15, 0.10, 0.12))
		draw_circle(btn_pos, 0.7, Color(0.22, 0.15, 0.18))

	# Red sash/cravat
	var cravat_pts = PackedVector2Array([
		neck_base + Vector2(-3, 1),
		neck_base + Vector2(3, 1),
		neck_base + Vector2(2, 8),
		neck_base + Vector2(0, 10),
		neck_base + Vector2(-2, 8),
	])
	draw_colored_polygon(cravat_pts, Color(0.6, 0.08, 0.06))
	draw_colored_polygon(PackedVector2Array([
		neck_base + Vector2(-2, 2),
		neck_base + Vector2(2, 2),
		neck_base + Vector2(1, 6),
		neck_base + Vector2(-1, 6),
	]), Color(0.7, 0.12, 0.08, 0.5))
	# Cravat fold shadows
	draw_line(neck_base + Vector2(-1, 3), neck_base + Vector2(-1, 7), Color(0.4, 0.04, 0.04, 0.3), 0.6)
	draw_line(neck_base + Vector2(1, 3), neck_base + Vector2(1, 7), Color(0.4, 0.04, 0.04, 0.3), 0.6)

	# Red gem brooch at throat
	var brooch_pos = neck_base + Vector2(0, 1)
	draw_circle(brooch_pos, 3.0, Color(0.25, 0.15, 0.15))
	draw_circle(brooch_pos, 2.2, Color(0.7, 0.08, 0.05))
	draw_circle(brooch_pos, 1.5, Color(0.85, 0.15, 0.1))
	draw_circle(brooch_pos, 0.8, Color(1.0, 0.3, 0.2, 0.7))
	# Gem sparkle
	var gem_pulse = sin(_time * 3.0) * 0.15 + 0.85
	draw_circle(brooch_pos + Vector2(-0.5, -0.5), 0.5, Color(1.0, 0.5, 0.4, 0.4 * gem_pulse))
	# Metal setting
	draw_arc(brooch_pos, 2.8, 0, TAU, 12, Color(0.6, 0.55, 0.45, 0.4), 0.7)

	# High collar
	var collar_l = PackedVector2Array([
		neck_base + Vector2(-6, -2),
		neck_base + Vector2(-12, -1),
		neck_base + Vector2(-10, -10),
		neck_base + Vector2(-5, -8),
	])
	draw_colored_polygon(collar_l, Color(0.06, 0.04, 0.06))
	draw_line(neck_base + Vector2(-6, -2), neck_base + Vector2(-10, -10), Color(0.12, 0.08, 0.10, 0.4), 0.8)
	var collar_r = PackedVector2Array([
		neck_base + Vector2(6, -2),
		neck_base + Vector2(12, -1),
		neck_base + Vector2(10, -10),
		neck_base + Vector2(5, -8),
	])
	draw_colored_polygon(collar_r, Color(0.06, 0.04, 0.06))
	draw_line(neck_base + Vector2(6, -2), neck_base + Vector2(10, -10), Color(0.12, 0.08, 0.10, 0.4), 0.8)
	# Collar inner red lining
	draw_colored_polygon(PackedVector2Array([
		neck_base + Vector2(-5, -3),
		neck_base + Vector2(-9, -2),
		neck_base + Vector2(-8, -8),
		neck_base + Vector2(-4, -6),
	]), Color(0.5, 0.04, 0.04, 0.4))
	draw_colored_polygon(PackedVector2Array([
		neck_base + Vector2(5, -3),
		neck_base + Vector2(9, -2),
		neck_base + Vector2(8, -8),
		neck_base + Vector2(4, -6),
	]), Color(0.5, 0.04, 0.04, 0.4))

	# Suit fold shadows
	draw_line(neck_base + Vector2(-12, 2), leg_top + Vector2(-6, -1), Color(0.04, 0.02, 0.04, 0.4), 1.0)
	draw_line(neck_base + Vector2(12, 2), leg_top + Vector2(6, -1), Color(0.04, 0.02, 0.04, 0.4), 1.0)

	# --- Shoulder pads (formal, squared) ---
	var l_shoulder = neck_base + Vector2(-13, 0)
	var r_shoulder = neck_base + Vector2(13, 0)
	draw_circle(l_shoulder, 5.5, Color(0.06, 0.04, 0.06))
	draw_circle(l_shoulder, 4.0, Color(0.10, 0.06, 0.08))
	draw_circle(r_shoulder, 5.5, Color(0.06, 0.04, 0.06))
	draw_circle(r_shoulder, 4.0, Color(0.10, 0.06, 0.08))

	# --- ARMS ---
	# CASTING ARM: right arm extended forward (casting blood bolt)
	var cast_extend = _cast_anim * 14.0
	var cast_hand = r_shoulder + Vector2(0, 2) + dir * (12.0 + cast_extend)
	var cast_elbow = r_shoulder + (cast_hand - r_shoulder) * 0.4 + Vector2(0, 3)
	var ca_dir = (cast_elbow - r_shoulder).normalized()
	var ca_perp = ca_dir.rotated(PI / 2.0)
	# Upper arm — thin formal sleeve
	draw_colored_polygon(PackedVector2Array([
		r_shoulder + ca_perp * 4.5, r_shoulder - ca_perp * 3.5,
		cast_elbow - ca_perp * 3.0, cast_elbow + ca_perp * 3.5,
	]), Color(0.06, 0.04, 0.06))
	draw_colored_polygon(PackedVector2Array([
		r_shoulder + ca_perp * 3.0, r_shoulder - ca_perp * 2.0,
		cast_elbow - ca_perp * 2.0, cast_elbow + ca_perp * 2.0,
	]), Color(0.10, 0.06, 0.08, 0.4))
	# Elbow
	draw_circle(cast_elbow, 3.5, Color(0.06, 0.04, 0.06))
	# Forearm
	var cf_dir = (cast_hand - cast_elbow).normalized()
	var cf_perp = cf_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		cast_elbow + cf_perp * 3.5, cast_elbow - cf_perp * 3.0,
		cast_hand - cf_perp * 2.0, cast_hand + cf_perp * 2.0,
	]), Color(0.06, 0.04, 0.06))
	# White shirt cuff peeking at wrist
	draw_line(cast_hand - cf_dir * 3.0 - cf_perp * 2.5, cast_hand - cf_dir * 3.0 + cf_perp * 2.5, Color(0.85, 0.82, 0.78), 2.0)
	# Pale hand — long thin fingers extended (casting pose)
	draw_circle(cast_hand, 3.5, skin_shadow)
	draw_circle(cast_hand, 2.8, skin_base)
	# Long elegant fingers
	for fi in range(4):
		var fa = float(fi - 1.5) * 0.25
		var finger_tip = cast_hand + dir.rotated(fa) * 6.0
		var finger_base = cast_hand + dir.rotated(fa) * 1.5
		draw_line(finger_base, finger_tip, skin_base, 1.4)
		draw_circle(finger_tip, 0.8, skin_highlight)
		# Sharp nails
		draw_line(finger_tip, finger_tip + dir.rotated(fa) * 1.5, Color(0.5, 0.45, 0.42), 0.8)
	# Thumb
	draw_line(cast_hand, cast_hand + perp * 3.5 + dir * 1.0, skin_base, 1.3)
	# Cast energy at fingertips when attacking
	if _attack_anim > 0.2:
		var cast_alpha = _attack_anim * 0.5
		draw_circle(cast_hand + dir * 6.0, 4.0, Color(0.6, 0.05, 0.05, cast_alpha))
		draw_circle(cast_hand + dir * 7.0, 2.5, Color(0.8, 0.1, 0.08, cast_alpha * 0.8))

	# CAPE ARM: left arm holding cape edge (dramatic pose)
	var cape_hand = l_shoulder + Vector2(-8 + cape_wind * 0.2, 10)
	var cape_elbow = l_shoulder + (cape_hand - l_shoulder) * 0.45 + Vector2(-3, 2)
	var la_dir = (cape_elbow - l_shoulder).normalized()
	var la_perp = la_dir.rotated(PI / 2.0)
	# Upper arm — formal sleeve
	draw_colored_polygon(PackedVector2Array([
		l_shoulder - la_perp * 4.5, l_shoulder + la_perp * 3.5,
		cape_elbow + la_perp * 3.0, cape_elbow - la_perp * 3.5,
	]), Color(0.06, 0.04, 0.06))
	draw_colored_polygon(PackedVector2Array([
		l_shoulder - la_perp * 3.0, l_shoulder + la_perp * 2.0,
		cape_elbow + la_perp * 2.0, cape_elbow - la_perp * 2.0,
	]), Color(0.10, 0.06, 0.08, 0.4))
	# Elbow
	draw_circle(cape_elbow, 3.5, Color(0.06, 0.04, 0.06))
	# Forearm
	var lf_dir = (cape_hand - cape_elbow).normalized()
	var lf_perp = lf_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		cape_elbow - lf_perp * 3.5, cape_elbow + lf_perp * 3.0,
		cape_hand + lf_perp * 2.0, cape_hand - lf_perp * 2.0,
	]), Color(0.06, 0.04, 0.06))
	# White cuff
	draw_line(cape_hand - lf_dir * 3.0 - lf_perp * 2.5, cape_hand - lf_dir * 3.0 + lf_perp * 2.5, Color(0.85, 0.82, 0.78), 2.0)
	# Cape-holding hand
	draw_circle(cape_hand, 3.5, skin_shadow)
	draw_circle(cape_hand, 2.8, skin_base)
	# Fingers gripping cape edge
	for fi in range(3):
		var finger_pos = cape_hand + Vector2(-2.0 + float(fi) * 2.0, 2.0)
		draw_circle(finger_pos, 0.9, skin_base)

	# === 16. HEAD ===
	# Neck
	var neck_top = head_center + Vector2(0, 9)
	var neck_n_dir = (neck_top - neck_base).normalized()
	var neck_perp = neck_n_dir.rotated(PI / 2.0)
	# Thin aristocratic neck
	draw_colored_polygon(PackedVector2Array([
		neck_base + neck_perp * 5.0, neck_base - neck_perp * 5.0,
		neck_top - neck_perp * 3.5, neck_top + neck_perp * 3.5,
	]), skin_shadow)
	draw_colored_polygon(PackedVector2Array([
		neck_base + neck_perp * 4.0, neck_base - neck_perp * 4.0,
		neck_top - neck_perp * 2.5, neck_top + neck_perp * 2.5,
	]), skin_base)
	# Neck highlight
	draw_line(neck_base.lerp(neck_top, 0.2) + neck_perp * 2.5, neck_base.lerp(neck_top, 0.8) + neck_perp * 2.0, skin_highlight, 1.2)

	# Slicked-back dark hair (back layer)
	var hair_col = Color(0.08, 0.05, 0.06)
	var hair_mid = Color(0.12, 0.08, 0.10)
	var hair_hi = Color(0.18, 0.12, 0.14)
	# Hair mass
	draw_circle(head_center, 11.0, hair_col)
	draw_circle(head_center + Vector2(0, -1.0), 9.5, hair_mid)
	# Slicked-back volume (swept toward back of head)
	draw_circle(head_center + Vector2(0, -3.0), 8.0, Color(0.10, 0.06, 0.08, 0.5))
	# Hair sheen
	draw_circle(head_center + Vector2(-2, -4), 4.0, Color(hair_hi.r, hair_hi.g, hair_hi.b, 0.3))
	# Slick strands (swept back)
	for si in range(6):
		var sa = PI + 0.3 + float(si) * (PI - 0.6) / 5.0
		var strand_base = head_center + Vector2.from_angle(sa) * 9.0
		var strand_tip = strand_base + Vector2.from_angle(sa) * 4.0 + Vector2(0, -1)
		draw_line(strand_base, strand_tip, hair_mid, 1.5)
		draw_line(strand_base, strand_base + Vector2.from_angle(sa) * 2.5, hair_hi, 0.8)

	# Face (sharp angular, pale)
	draw_circle(head_center + Vector2(0, 0.8), 9.0, skin_base)
	# Strong angular jawline
	draw_line(head_center + Vector2(-8.0, 0.5), head_center + Vector2(-4, 8.0), Color(0.60, 0.55, 0.52, 0.35), 1.5)
	draw_line(head_center + Vector2(8.0, 0.5), head_center + Vector2(4, 8.0), Color(0.60, 0.55, 0.52, 0.35), 1.5)
	# Hollow cheeks (gaunt vampire)
	draw_circle(head_center + Vector2(-5.5, 2.0), 3.0, Color(0.65, 0.60, 0.58, 0.15))
	draw_circle(head_center + Vector2(5.5, 2.0), 3.0, Color(0.65, 0.60, 0.58, 0.15))
	# Cheekbone highlight
	draw_arc(head_center + Vector2(-5.0, 0.2), 3.5, PI * 1.1, PI * 1.65, 8, Color(0.95, 0.90, 0.88, 0.2), 1.0)
	draw_arc(head_center + Vector2(5.0, 0.2), 3.5, PI * 1.35, PI * 1.9, 8, Color(0.95, 0.90, 0.88, 0.2), 1.0)
	# Pointed chin
	draw_circle(head_center + Vector2(0, 8.0), 2.5, skin_base)
	draw_circle(head_center + Vector2(0, 8.2), 1.8, skin_highlight)

	# Widow's peak hairline
	var peak_pts = PackedVector2Array([
		head_center + Vector2(-8.5, -5.5),
		head_center + Vector2(0, -3.0),
		head_center + Vector2(8.5, -5.5),
		head_center + Vector2(6.0, -8.0),
		head_center + Vector2(0, -9.5),
		head_center + Vector2(-6.0, -8.0),
	])
	draw_colored_polygon(peak_pts, hair_col)
	# Widow's peak point
	draw_colored_polygon(PackedVector2Array([
		head_center + Vector2(-3.5, -5.0),
		head_center + Vector2(3.5, -5.0),
		head_center + Vector2(0, -2.0),
	]), hair_col)
	# Hairline edge sheen
	draw_line(head_center + Vector2(-6, -7.5), head_center + Vector2(0, -3.0), hair_hi, 0.6)
	draw_line(head_center + Vector2(6, -7.5), head_center + Vector2(0, -3.0), hair_hi, 0.6)

	# Ears (pointed slightly — aristocratic)
	var r_ear = head_center + Vector2(8.5, -1.0)
	draw_circle(r_ear, 2.2, skin_base)
	draw_circle(r_ear + Vector2(0.3, 0), 1.4, Color(0.82, 0.78, 0.76, 0.5))
	var l_ear = head_center + Vector2(-8.5, -1.0)
	draw_circle(l_ear, 2.2, skin_base)
	draw_circle(l_ear + Vector2(-0.3, 0), 1.4, Color(0.82, 0.78, 0.76, 0.5))

	# RED GLOWING EYES — the signature feature
	var look_dir = dir * 1.2
	var l_eye = head_center + Vector2(-3.8, -1.0)
	var r_eye = head_center + Vector2(3.8, -1.0)
	# Eye socket shadow (deep-set vampire eyes)
	draw_circle(l_eye, 4.5, Color(0.35, 0.25, 0.30, 0.35))
	draw_circle(r_eye, 4.5, Color(0.35, 0.25, 0.30, 0.35))
	# Eye whites (slightly bloodshot)
	draw_circle(l_eye, 3.8, Color(0.92, 0.88, 0.88))
	draw_circle(r_eye, 3.8, Color(0.92, 0.88, 0.88))
	# Bloodshot veins
	for vi in range(3):
		var va = TAU * float(vi) / 3.0 + 0.5
		draw_line(l_eye + Vector2.from_angle(va) * 2.5, l_eye + Vector2.from_angle(va) * 3.5, Color(0.7, 0.2, 0.15, 0.2), 0.4)
		draw_line(r_eye + Vector2.from_angle(va) * 2.5, r_eye + Vector2.from_angle(va) * 3.5, Color(0.7, 0.2, 0.15, 0.2), 0.4)
	# RED irises (glowing, following aim)
	var eye_glow_pulse = sin(_time * 2.5) * 0.1 + 0.9
	draw_circle(l_eye + look_dir, 2.5, Color(0.55, 0.05, 0.02))
	draw_circle(l_eye + look_dir, 2.0, Color(0.75, 0.08, 0.04))
	draw_circle(l_eye + look_dir, 1.4, Color(0.9, 0.12, 0.06))
	draw_circle(r_eye + look_dir, 2.5, Color(0.55, 0.05, 0.02))
	draw_circle(r_eye + look_dir, 2.0, Color(0.75, 0.08, 0.04))
	draw_circle(r_eye + look_dir, 1.4, Color(0.9, 0.12, 0.06))
	# Iris glow halo
	draw_circle(l_eye + look_dir, 3.5, Color(0.8, 0.1, 0.05, 0.12 * eye_glow_pulse))
	draw_circle(r_eye + look_dir, 3.5, Color(0.8, 0.1, 0.05, 0.12 * eye_glow_pulse))
	# Iris radial detail
	for iri in range(8):
		var ir_a = TAU * float(iri) / 8.0
		var ir_v = Vector2.from_angle(ir_a)
		draw_line(l_eye + look_dir + ir_v * 0.5, l_eye + look_dir + ir_v * 1.5, Color(0.65, 0.06, 0.03, 0.3), 0.4)
		draw_line(r_eye + look_dir + ir_v * 0.5, r_eye + look_dir + ir_v * 1.5, Color(0.65, 0.06, 0.03, 0.3), 0.4)
	# Slit pupils
	draw_line(l_eye + look_dir * 1.1 + Vector2(0, -1.2), l_eye + look_dir * 1.1 + Vector2(0, 1.2), Color(0.05, 0.02, 0.02), 1.2)
	draw_line(r_eye + look_dir * 1.1 + Vector2(0, -1.2), r_eye + look_dir * 1.1 + Vector2(0, 1.2), Color(0.05, 0.02, 0.02), 1.2)
	# Primary highlight
	draw_circle(l_eye + Vector2(-0.8, -1.0), 1.1, Color(1.0, 0.6, 0.5, 0.7))
	draw_circle(r_eye + Vector2(-0.8, -1.0), 1.1, Color(1.0, 0.6, 0.5, 0.7))
	# Secondary highlight
	draw_circle(l_eye + Vector2(1.0, 0.3), 0.6, Color(1.0, 0.5, 0.4, 0.45))
	draw_circle(r_eye + Vector2(1.0, 0.3), 0.6, Color(1.0, 0.5, 0.4, 0.45))
	# Upper eyelids (heavy, sinister)
	draw_arc(l_eye, 3.8, PI + 0.15, TAU - 0.15, 8, Color(0.35, 0.25, 0.30), 1.5)
	draw_arc(r_eye, 3.8, PI + 0.15, TAU - 0.15, 8, Color(0.35, 0.25, 0.30), 1.5)
	# Lower eyelid
	draw_arc(l_eye, 3.5, 0.3, PI - 0.3, 8, Color(0.50, 0.40, 0.42, 0.3), 0.6)
	draw_arc(r_eye, 3.5, 0.3, PI - 0.3, 8, Color(0.50, 0.40, 0.42, 0.3), 0.6)

	# Eyebrows — sharp, angular, aristocratic
	draw_line(l_eye + Vector2(-3.5, -4.5), l_eye + Vector2(0.5, -5.0), Color(0.10, 0.06, 0.08), 1.6)
	draw_line(l_eye + Vector2(0.5, -5.0), l_eye + Vector2(3.0, -4.0), Color(0.10, 0.06, 0.08), 1.0)
	draw_line(r_eye + Vector2(-3.0, -4.0), r_eye + Vector2(-0.5, -5.0), Color(0.10, 0.06, 0.08), 1.6)
	draw_line(r_eye + Vector2(-0.5, -5.0), r_eye + Vector2(3.5, -4.5), Color(0.10, 0.06, 0.08), 1.0)

	# Nose — sharp, aquiline, prominent
	draw_line(head_center + Vector2(0, -1), head_center + Vector2(0.3, 2.8), Color(0.82, 0.78, 0.76, 0.4), 0.8)
	draw_circle(head_center + Vector2(0.2, 3.0), 1.4, skin_highlight)
	# Nostrils
	draw_circle(head_center + Vector2(-0.8, 3.4), 0.5, Color(0.55, 0.48, 0.45, 0.4))
	draw_circle(head_center + Vector2(0.8, 3.4), 0.5, Color(0.55, 0.48, 0.45, 0.4))
	# Nose bridge shadow
	draw_line(head_center + Vector2(-0.6, 0.5), head_center + Vector2(-0.7, 2.5), Color(0.62, 0.55, 0.52, 0.2), 0.6)

	# Mouth — thin cruel smile with pronounced canine teeth
	draw_arc(head_center + Vector2(0, 5.5), 4.5, 0.2, PI - 0.2, 12, Color(0.45, 0.15, 0.15), 1.4)
	# Teeth visible — fangs prominent
	# Upper teeth
	for thi in range(5):
		var tooth_x = -2.5 + float(thi) * 1.25
		var tooth_size = 0.5
		if thi == 0 or thi == 4:  # Canines are larger
			tooth_size = 0.7
		draw_circle(head_center + Vector2(tooth_x, 5.5), tooth_size, Color(0.96, 0.94, 0.90))
	# Pronounced canine fangs (when attacking or idle)
	var fang_extend = 0.0
	if _attack_anim > 0.0:
		fang_extend = _attack_anim * 2.5
	else:
		fang_extend = 1.5 + sin(_time * 2.0) * 0.3  # Always slightly visible
	# Left fang
	draw_line(head_center + Vector2(-2.5, 5.5), head_center + Vector2(-2.5, 5.5 + fang_extend), Color(0.96, 0.94, 0.90), 1.3)
	draw_circle(head_center + Vector2(-2.5, 5.5 + fang_extend), 0.5, Color(0.98, 0.96, 0.92))
	# Right fang
	draw_line(head_center + Vector2(2.5, 5.5), head_center + Vector2(2.5, 5.5 + fang_extend), Color(0.96, 0.94, 0.90), 1.3)
	draw_circle(head_center + Vector2(2.5, 5.5 + fang_extend), 0.5, Color(0.98, 0.96, 0.92))
	# Fang tips glow red when attacking
	if _attack_anim > 0.3:
		draw_circle(head_center + Vector2(-2.5, 5.5 + fang_extend), 1.0, Color(0.7, 0.1, 0.05, _attack_anim * 0.3))
		draw_circle(head_center + Vector2(2.5, 5.5 + fang_extend), 1.0, Color(0.7, 0.1, 0.05, _attack_anim * 0.3))
	# Lower lip
	draw_arc(head_center + Vector2(0, 5.8), 3.0, 0.4, PI - 0.4, 8, Color(0.55, 0.25, 0.22, 0.2), 0.7)
	# Smirk upturn
	draw_line(head_center + Vector2(3.5, 5.2), head_center + Vector2(4.8, 4.2), Color(0.45, 0.15, 0.15, 0.4), 0.8)

	# === NOSFERATU FORM OVERLAY (Ability 8 active) ===
	if prog_abilities[7] and _nosferatu_active > 0.0:
		var nos_alpha = clampf(_nosferatu_active / 4.0, 0.0, 1.0) * 0.3
		# Dark aura around body
		draw_circle(body_offset, 40.0, Color(0.2, 0.0, 0.0, nos_alpha))
		draw_arc(body_offset, 38.0, 0, TAU, 24, Color(0.5, 0.05, 0.05, nos_alpha * 1.5), 2.0)
		# Elongated shadow features
		draw_circle(head_center + Vector2(0, -2), 12.0, Color(0.15, 0.0, 0.0, nos_alpha * 0.4))

	# === Tier 4: Full darkness aura around whole character ===
	if upgrade_tier >= 4:
		var aura_pulse = sin(_time * 2.0) * 5.0
		draw_circle(body_offset, 62.0 + aura_pulse, Color(0.15, 0.0, 0.02, 0.05))
		draw_circle(body_offset, 50.0 + aura_pulse * 0.6, Color(0.2, 0.02, 0.03, 0.07))
		draw_circle(body_offset, 42.0 + aura_pulse * 0.3, Color(0.4, 0.05, 0.05, 0.06))
		draw_arc(body_offset, 56.0 + aura_pulse, 0, TAU, 32, Color(0.5, 0.05, 0.05, 0.12), 2.5)
		# Orbiting dark-red sparks
		for gs in range(6):
			var gs_a = _time * (0.5 + float(gs % 3) * 0.2) + float(gs) * TAU / 6.0
			var gs_r = 48.0 + aura_pulse + float(gs % 3) * 3.5
			var gs_p = body_offset + Vector2.from_angle(gs_a) * gs_r
			var gs_size = 1.2 + sin(_time * 3.0 + float(gs) * 1.5) * 0.5
			var gs_alpha = 0.25 + sin(_time * 3.0 + float(gs)) * 0.15
			draw_circle(gs_p, gs_size, Color(0.7, 0.1, 0.05, gs_alpha))

	# === AWAITING ABILITY CHOICE INDICATOR ===
	if awaiting_ability_choice:
		var pulse = (sin(_time * 4.0) + 1.0) * 0.5
		draw_circle(Vector2.ZERO, 68.0 + pulse * 6.0, Color(0.6, 0.1, 0.1, 0.1 + pulse * 0.1))
		draw_arc(Vector2.ZERO, 68.0 + pulse * 6.0, 0, TAU, 32, Color(0.6, 0.1, 0.1, 0.3 + pulse * 0.3), 2.5)
		var font3 = ThemeDB.fallback_font
		draw_string(font3, Vector2(-16, -80), "!", HORIZONTAL_ALIGNMENT_CENTER, 32, 30, Color(0.6, 0.1, 0.1, 0.7 + pulse * 0.3))

	# === DAMAGE COUNTER ===
	if damage_dealt > 0:
		var font = ThemeDB.fallback_font
		var dmg_text = str(int(damage_dealt)) + " DMG"
		if stat_upgrade_level > 0:
			dmg_text += " • Lv." + str(stat_upgrade_level)
		draw_string(font, Vector2(-36, 56), dmg_text, HORIZONTAL_ALIGNMENT_LEFT, 160, 12, Color(0.8, 0.15, 0.1, 0.5))

	# === UPGRADE NAME FLASH ===
	if _upgrade_flash > 0.0 and _upgrade_name != "":
		var font2 = ThemeDB.fallback_font
		draw_string(font2, Vector2(-80, -72), _upgrade_name, HORIZONTAL_ALIGNMENT_CENTER, 160, 16, Color(0.7, 0.1, 0.08, min(_upgrade_flash, 1.0)))

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
