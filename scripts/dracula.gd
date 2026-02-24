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
var _game_font: Font

func _ready() -> void:
	var _ff := FontFile.new()
	_ff.data = FileAccess.get_file_as_bytes("res://fonts/Cinzel.ttf")
	_game_font = _ff
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

	# === 13. CHARACTER BODY — BTD6 CARTOON STYLE ===
	var OL = Color(0.06, 0.06, 0.08)
	var breath = breathe

	# Chibi positions
	var sway = hip_shift
	var feet_y = body_offset + Vector2(sway * 1.0, 10.0)
	var leg_top = body_offset + Vector2(sway * 0.6, 0.0)
	var torso_center = body_offset + Vector2(sway * 0.3, -8.0 - breath * 0.5)
	var neck_base = body_offset + Vector2(sway * 0.15, -14.0 - breath * 0.3)
	var head_center = body_offset + Vector2(sway * 0.08, -26.0)

	# Colors
	var skin = Color(0.92, 0.85, 0.82)
	var skin_hi = Color(0.97, 0.93, 0.91)
	var skin_dark = Color(0.78, 0.72, 0.70)
	var suit_black = Color(0.10, 0.08, 0.10)
	var suit_dark = Color(0.06, 0.04, 0.06)
	var cape_black = Color(0.08, 0.05, 0.07)
	var cape_red = Color(0.78, 0.08, 0.06)
	var cape_red_dark = Color(0.55, 0.04, 0.04)
	var cravat_red = Color(0.85, 0.10, 0.08)
	var hair_col = Color(0.06, 0.04, 0.05)
	var hair_hi = Color(0.16, 0.10, 0.14)

	# === 14. DRAMATIC CAPE (drawn BEHIND body) ===
	var cape_top_l = neck_base + Vector2(-11, -2)
	var cape_top_r = neck_base + Vector2(11, -2)
	var cape_mid_l = torso_center + Vector2(-20 + cape_wind * 0.5, 8.0)
	var cape_mid_r = torso_center + Vector2(20 + cape_wind * 0.4, 9.0)
	var cape_bot_l = feet_y + Vector2(-24 + cape_wind * 0.8, 12.0 + cape_flutter)
	var cape_bot_r = feet_y + Vector2(24 + cape_wind * 0.6, 13.0 + cape_flutter * 0.8)
	var cape_bot_c = feet_y + Vector2(cape_wind * 0.35, 16.0 + cape_flutter * 0.5)
	# Cape outline
	draw_colored_polygon(PackedVector2Array([
		cape_top_l + Vector2(-1.5, -1.5), cape_top_r + Vector2(1.5, -1.5),
		cape_mid_r + Vector2(1.5, 0), cape_bot_r + Vector2(1.5, 1.5),
		cape_bot_c + Vector2(0, 1.5), cape_bot_l + Vector2(-1.5, 1.5),
		cape_mid_l + Vector2(-1.5, 0),
	]), OL)
	# Cape fill (black outer)
	draw_colored_polygon(PackedVector2Array([
		cape_top_l, cape_top_r, cape_mid_r, cape_bot_r,
		cape_bot_c, cape_bot_l, cape_mid_l,
	]), cape_black)
	# Red lining — right edge exposed
	var lining_show = 0.35 + abs(cape_wind) * 0.025
	draw_colored_polygon(PackedVector2Array([
		cape_top_r + Vector2(-3, 1), cape_top_r,
		cape_mid_r, cape_mid_r + Vector2(-5, -2),
	]), Color(cape_red.r, cape_red.g, cape_red.b, lining_show))
	# Red lining — left edge
	draw_colored_polygon(PackedVector2Array([
		cape_top_l, cape_top_l + Vector2(3, 1),
		cape_mid_l + Vector2(5, -2), cape_mid_l,
	]), Color(cape_red.r, cape_red.g, cape_red.b, lining_show * 0.75))
	# Red lining — bottom peek
	draw_colored_polygon(PackedVector2Array([
		cape_mid_r + Vector2(-3, 0), cape_mid_r,
		cape_bot_r, cape_bot_r + Vector2(-4, -3),
	]), Color(cape_red_dark.r, cape_red_dark.g, cape_red_dark.b, lining_show * 0.6))
	draw_colored_polygon(PackedVector2Array([
		cape_mid_l, cape_mid_l + Vector2(3, 0),
		cape_bot_l + Vector2(4, -3), cape_bot_l,
	]), Color(cape_red_dark.r, cape_red_dark.g, cape_red_dark.b, lining_show * 0.45))
	# Cape fold lines (bold dark)
	draw_line(cape_top_l.lerp(cape_top_r, 0.3), cape_mid_l.lerp(cape_mid_r, 0.2), Color(0.02, 0.0, 0.02, 0.5), 1.2)
	draw_line(cape_top_l.lerp(cape_top_r, 0.6), cape_mid_l.lerp(cape_mid_r, 0.55), Color(0.02, 0.0, 0.02, 0.45), 1.2)
	draw_line(cape_top_l.lerp(cape_top_r, 0.85), cape_mid_l.lerp(cape_mid_r, 0.8), Color(0.02, 0.0, 0.02, 0.35), 1.0)
	# Bat-shaped cape clasps at shoulders
	for ci in range(2):
		var clasp_x = -10.0 if ci == 0 else 10.0
		var clasp_pos = neck_base + Vector2(clasp_x, -1)
		draw_circle(clasp_pos, 3.2, OL)
		draw_circle(clasp_pos, 2.2, Color(0.55, 0.45, 0.35))
		draw_line(clasp_pos + Vector2(-2.5, 0), clasp_pos + Vector2(-4, -2.5), OL, 1.5)
		draw_line(clasp_pos + Vector2(2.5, 0), clasp_pos + Vector2(4, -2.5), OL, 1.5)

	# === 15. CHUNKY CHIBI BODY ===

	# --- FEET (chunky rounded shoes) ---
	var l_foot = feet_y + Vector2(-5, 0)
	var r_foot = feet_y + Vector2(5, 0)
	draw_circle(l_foot, 5.5, OL)
	draw_circle(r_foot, 5.5, OL)
	draw_circle(l_foot, 4.2, suit_black)
	draw_circle(r_foot, 4.2, suit_black)
	# Shoe highlight
	draw_circle(l_foot + Vector2(-0.8, -1.2), 1.8, Color(0.22, 0.18, 0.20, 0.5))
	draw_circle(r_foot + Vector2(0.8, -1.2), 1.8, Color(0.22, 0.18, 0.20, 0.5))
	# Silver buckle
	draw_circle(l_foot + Vector2(0, -1), 1.5, OL)
	draw_circle(l_foot + Vector2(0, -1), 0.9, Color(0.72, 0.70, 0.65))
	draw_circle(r_foot + Vector2(0, -1), 1.5, OL)
	draw_circle(r_foot + Vector2(0, -1), 0.9, Color(0.72, 0.70, 0.65))

	# --- LEGS (short chunky, black trousers) ---
	var l_hip = leg_top + Vector2(-4, 0)
	var r_hip = leg_top + Vector2(4, 0)
	# Left leg
	draw_colored_polygon(PackedVector2Array([
		l_hip + Vector2(-4.5, 0), l_hip + Vector2(4.0, 0),
		l_foot + Vector2(3.5, -2), l_foot + Vector2(-3.5, -2),
	]), OL)
	draw_colored_polygon(PackedVector2Array([
		l_hip + Vector2(-3.2, 0.5), l_hip + Vector2(2.8, 0.5),
		l_foot + Vector2(2.2, -2.5), l_foot + Vector2(-2.2, -2.5),
	]), suit_dark)
	# Right leg
	draw_colored_polygon(PackedVector2Array([
		r_hip + Vector2(-4.0, 0), r_hip + Vector2(4.5, 0),
		r_foot + Vector2(3.5, -2), r_foot + Vector2(-3.5, -2),
	]), OL)
	draw_colored_polygon(PackedVector2Array([
		r_hip + Vector2(-2.8, 0.5), r_hip + Vector2(3.2, 0.5),
		r_foot + Vector2(2.2, -2.5), r_foot + Vector2(-2.2, -2.5),
	]), suit_dark)
	# Trouser crease
	draw_line(l_hip, l_foot + Vector2(0, -3), Color(0.02, 0.0, 0.02, 0.3), 0.8)
	draw_line(r_hip, r_foot + Vector2(0, -3), Color(0.02, 0.0, 0.02, 0.3), 0.8)

	# --- TORSO (formal black suit, chunky chibi) ---
	var torso_ol = PackedVector2Array([
		leg_top + Vector2(-9.5, 2),
		torso_center + Vector2(-13.5, -1),
		neck_base + Vector2(-14.5, 0),
		neck_base + Vector2(14.5, 0),
		torso_center + Vector2(13.5, -1),
		leg_top + Vector2(9.5, 2),
	])
	draw_colored_polygon(torso_ol, OL)
	var torso_fill = PackedVector2Array([
		leg_top + Vector2(-8, 1),
		torso_center + Vector2(-12, 0),
		neck_base + Vector2(-13, 1),
		neck_base + Vector2(13, 1),
		torso_center + Vector2(12, 0),
		leg_top + Vector2(8, 1),
	])
	draw_colored_polygon(torso_fill, suit_dark)

	# White shirt front V-shape
	draw_colored_polygon(PackedVector2Array([
		neck_base + Vector2(-4, 2),
		neck_base + Vector2(4, 2),
		torso_center + Vector2(2, 6),
		torso_center + Vector2(-2, 6),
	]), Color(0.92, 0.90, 0.88))
	draw_line(neck_base + Vector2(-4, 2), torso_center + Vector2(-2, 6), OL, 1.2)
	draw_line(neck_base + Vector2(4, 2), torso_center + Vector2(2, 6), OL, 1.2)

	# Suit lapels — bold dark V
	draw_colored_polygon(PackedVector2Array([
		neck_base + Vector2(-5, 1), neck_base + Vector2(-12, 2),
		torso_center + Vector2(-9, 3), torso_center + Vector2(-3, 5),
	]), suit_black)
	draw_colored_polygon(PackedVector2Array([
		neck_base + Vector2(5, 1), neck_base + Vector2(12, 2),
		torso_center + Vector2(9, 3), torso_center + Vector2(3, 5),
	]), suit_black)
	draw_line(neck_base + Vector2(-5, 1), torso_center + Vector2(-3, 5), OL, 2.0)
	draw_line(neck_base + Vector2(5, 1), torso_center + Vector2(3, 5), OL, 2.0)

	# Suit buttons (3 dark shiny)
	for bi in range(3):
		var by = torso_center.y - 1.0 + float(bi) * 3.5
		var btn_pos = Vector2(torso_center.x, by)
		draw_circle(btn_pos, 1.8, OL)
		draw_circle(btn_pos, 1.0, Color(0.25, 0.18, 0.22))

	# Red cravat at throat
	draw_colored_polygon(PackedVector2Array([
		neck_base + Vector2(-4, 1.5), neck_base + Vector2(4, 1.5),
		neck_base + Vector2(2.5, 7), neck_base + Vector2(0, 8.5),
		neck_base + Vector2(-2.5, 7),
	]), OL)
	draw_colored_polygon(PackedVector2Array([
		neck_base + Vector2(-3.2, 2.2), neck_base + Vector2(3.2, 2.2),
		neck_base + Vector2(1.8, 6.2), neck_base + Vector2(0, 7.5),
		neck_base + Vector2(-1.8, 6.2),
	]), cravat_red)
	# Cravat highlight
	draw_colored_polygon(PackedVector2Array([
		neck_base + Vector2(-1.5, 3), neck_base + Vector2(1.5, 3),
		neck_base + Vector2(0.8, 5.5), neck_base + Vector2(-0.8, 5.5),
	]), Color(0.95, 0.20, 0.15, 0.5))

	# Red gem brooch
	var brooch_pos = neck_base + Vector2(0, 2)
	draw_circle(brooch_pos, 3.5, OL)
	draw_circle(brooch_pos, 2.5, Color(0.75, 0.08, 0.06))
	draw_circle(brooch_pos, 1.6, Color(0.92, 0.18, 0.12))
	var gem_pulse = sin(_time * 3.0) * 0.15 + 0.85
	draw_circle(brooch_pos + Vector2(-0.5, -0.6), 0.7, Color(1.0, 0.5, 0.4, 0.5 * gem_pulse))

	# High collar — bold pointed upward
	# Left collar
	draw_colored_polygon(PackedVector2Array([
		neck_base + Vector2(-6, -1), neck_base + Vector2(-13, 0),
		neck_base + Vector2(-10, -10), neck_base + Vector2(-5, -8),
	]), OL)
	draw_colored_polygon(PackedVector2Array([
		neck_base + Vector2(-5.5, -0.5), neck_base + Vector2(-11.5, 0.5),
		neck_base + Vector2(-9, -8.5), neck_base + Vector2(-4.5, -7),
	]), suit_dark)
	draw_colored_polygon(PackedVector2Array([
		neck_base + Vector2(-5, -1.5), neck_base + Vector2(-9.5, -0.5),
		neck_base + Vector2(-8, -7), neck_base + Vector2(-4, -5.5),
	]), Color(cape_red_dark.r, cape_red_dark.g, cape_red_dark.b, 0.5))
	# Right collar
	draw_colored_polygon(PackedVector2Array([
		neck_base + Vector2(6, -1), neck_base + Vector2(13, 0),
		neck_base + Vector2(10, -10), neck_base + Vector2(5, -8),
	]), OL)
	draw_colored_polygon(PackedVector2Array([
		neck_base + Vector2(5.5, -0.5), neck_base + Vector2(11.5, 0.5),
		neck_base + Vector2(9, -8.5), neck_base + Vector2(4.5, -7),
	]), suit_dark)
	draw_colored_polygon(PackedVector2Array([
		neck_base + Vector2(5, -1.5), neck_base + Vector2(9.5, -0.5),
		neck_base + Vector2(8, -7), neck_base + Vector2(4, -5.5),
	]), Color(cape_red_dark.r, cape_red_dark.g, cape_red_dark.b, 0.5))

	# --- SHOULDERS (chunky round) ---
	var l_shoulder = neck_base + Vector2(-12, 1)
	var r_shoulder = neck_base + Vector2(12, 1)
	draw_circle(l_shoulder, 6.0, OL)
	draw_circle(l_shoulder, 4.5, suit_dark)
	draw_circle(l_shoulder + Vector2(-0.5, -1), 2.0, Color(suit_black.r, suit_black.g, suit_black.b, 0.4))
	draw_circle(r_shoulder, 6.0, OL)
	draw_circle(r_shoulder, 4.5, suit_dark)
	draw_circle(r_shoulder + Vector2(0.5, -1), 2.0, Color(suit_black.r, suit_black.g, suit_black.b, 0.4))

	# --- RIGHT ARM (casting arm — extends toward target) ---
	var cast_extend = _cast_anim * 12.0
	var cast_hand = r_shoulder + Vector2(0, 2) + dir * (10.0 + cast_extend)
	var cast_elbow = r_shoulder + (cast_hand - r_shoulder) * 0.45 + Vector2(0, 4)
	# Upper arm
	var ca_d = (cast_elbow - r_shoulder).normalized()
	var ca_p = ca_d.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		r_shoulder + ca_p * 5.0, r_shoulder - ca_p * 4.5,
		cast_elbow - ca_p * 4.0, cast_elbow + ca_p * 4.5,
	]), OL)
	draw_colored_polygon(PackedVector2Array([
		r_shoulder + ca_p * 3.5, r_shoulder - ca_p * 3.0,
		cast_elbow - ca_p * 2.8, cast_elbow + ca_p * 3.0,
	]), suit_dark)
	# Elbow joint
	draw_circle(cast_elbow, 4.2, OL)
	draw_circle(cast_elbow, 3.0, suit_dark)
	# Forearm
	var cf_d = (cast_hand - cast_elbow).normalized()
	var cf_p = cf_d.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		cast_elbow + cf_p * 4.2, cast_elbow - cf_p * 3.8,
		cast_hand - cf_p * 2.8, cast_hand + cf_p * 3.0,
	]), OL)
	draw_colored_polygon(PackedVector2Array([
		cast_elbow + cf_p * 2.8, cast_elbow - cf_p * 2.5,
		cast_hand - cf_p * 1.8, cast_hand + cf_p * 2.0,
	]), suit_dark)
	# White cuff at wrist
	var cuff_pos = cast_hand - cf_d * 3.0
	draw_line(cuff_pos - cf_p * 3.0, cuff_pos + cf_p * 3.0, OL, 3.0)
	draw_line(cuff_pos - cf_p * 2.2, cuff_pos + cf_p * 2.2, Color(0.92, 0.90, 0.88), 2.0)
	# Hand — pale with pointed nails
	draw_circle(cast_hand, 4.0, OL)
	draw_circle(cast_hand, 2.8, skin)
	# Fingers extended (casting pose)
	for fi in range(4):
		var fa = float(fi - 1.5) * 0.22
		var f_tip = cast_hand + dir.rotated(fa) * 5.5
		var f_base = cast_hand + dir.rotated(fa) * 1.5
		draw_line(f_base, f_tip, OL, 2.2)
		draw_line(f_base, f_tip, skin, 1.4)
		# Pointed nail
		var nail_tip = f_tip + dir.rotated(fa) * 2.0
		draw_line(f_tip, nail_tip, OL, 1.5)
		draw_line(f_tip, nail_tip, Color(0.50, 0.45, 0.42), 0.8)
	# Thumb
	draw_line(cast_hand, cast_hand + perp * 3.5 + dir * 1.0, OL, 2.2)
	draw_line(cast_hand, cast_hand + perp * 3.5 + dir * 1.0, skin, 1.4)
	# Cast energy at fingertips when attacking
	if _attack_anim > 0.2:
		var cast_alpha = _attack_anim * 0.6
		draw_circle(cast_hand + dir * 6.0, 5.0, Color(0.65, 0.05, 0.05, cast_alpha * 0.5))
		draw_circle(cast_hand + dir * 6.5, 3.5, Color(0.85, 0.10, 0.08, cast_alpha * 0.7))
		draw_circle(cast_hand + dir * 7.0, 2.0, Color(1.0, 0.25, 0.15, cast_alpha))

	# --- LEFT ARM (cape-holding arm, dramatic pose) ---
	var cape_hand = l_shoulder + Vector2(-7 + cape_wind * 0.2, 10)
	var cape_elbow = l_shoulder + (cape_hand - l_shoulder) * 0.45 + Vector2(-3, 3)
	# Upper arm
	var la_d = (cape_elbow - l_shoulder).normalized()
	var la_p = la_d.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		l_shoulder - la_p * 5.0, l_shoulder + la_p * 4.5,
		cape_elbow + la_p * 4.0, cape_elbow - la_p * 4.5,
	]), OL)
	draw_colored_polygon(PackedVector2Array([
		l_shoulder - la_p * 3.5, l_shoulder + la_p * 3.0,
		cape_elbow + la_p * 2.8, cape_elbow - la_p * 3.0,
	]), suit_dark)
	# Elbow joint
	draw_circle(cape_elbow, 4.2, OL)
	draw_circle(cape_elbow, 3.0, suit_dark)
	# Forearm
	var lf_d = (cape_hand - cape_elbow).normalized()
	var lf_p = lf_d.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		cape_elbow - lf_p * 4.2, cape_elbow + lf_p * 3.8,
		cape_hand + lf_p * 2.8, cape_hand - lf_p * 3.0,
	]), OL)
	draw_colored_polygon(PackedVector2Array([
		cape_elbow - lf_p * 2.8, cape_elbow + lf_p * 2.5,
		cape_hand + lf_p * 1.8, cape_hand - lf_p * 2.0,
	]), suit_dark)
	# White cuff
	var lcuff_pos = cape_hand - lf_d * 3.0
	draw_line(lcuff_pos - lf_p * 3.0, lcuff_pos + lf_p * 3.0, OL, 3.0)
	draw_line(lcuff_pos - lf_p * 2.2, lcuff_pos + lf_p * 2.2, Color(0.92, 0.90, 0.88), 2.0)
	# Cape-holding hand
	draw_circle(cape_hand, 4.0, OL)
	draw_circle(cape_hand, 2.8, skin)
	# Fingers gripping cape
	for fi in range(3):
		var fpos = cape_hand + Vector2(-2.0 + float(fi) * 2.0, 2.0)
		draw_circle(fpos, 1.4, OL)
		draw_circle(fpos, 0.8, skin)

	# === 16. BIG ROUND HEAD ===
	# Neck (short, chunky)
	draw_colored_polygon(PackedVector2Array([
		neck_base + Vector2(-5, 0), neck_base + Vector2(5, 0),
		head_center + Vector2(4, 9), head_center + Vector2(-4, 9),
	]), OL)
	draw_colored_polygon(PackedVector2Array([
		neck_base + Vector2(-3.5, 0.5), neck_base + Vector2(3.5, 0.5),
		head_center + Vector2(2.8, 9), head_center + Vector2(-2.8, 9),
	]), skin_dark)

	# Hair back layer (outline + fill)
	draw_circle(head_center, 14.0, OL)
	draw_circle(head_center, 12.5, hair_col)
	# Hair sheen
	draw_circle(head_center + Vector2(-2.5, -5), 4.5, Color(hair_hi.r, hair_hi.g, hair_hi.b, 0.35))
	# Slicked-back strands
	for si in range(7):
		var sa = PI + 0.25 + float(si) * (PI - 0.5) / 6.0
		var s_base = head_center + Vector2.from_angle(sa) * 11.0
		var s_tip = s_base + Vector2.from_angle(sa) * 4.5 + Vector2(0, -1)
		draw_line(s_base, s_tip, OL, 2.0)
		draw_line(s_base, s_tip, hair_hi, 1.0)

	# Face circle (outline + fill)
	draw_circle(head_center + Vector2(0, 1), 12.0, OL)
	draw_circle(head_center + Vector2(0, 1), 10.8, skin)
	# Pointed chin accent
	draw_colored_polygon(PackedVector2Array([
		head_center + Vector2(-5, 8), head_center + Vector2(5, 8),
		head_center + Vector2(0, 12.5),
	]), OL)
	draw_colored_polygon(PackedVector2Array([
		head_center + Vector2(-4, 8), head_center + Vector2(4, 8),
		head_center + Vector2(0, 11.5),
	]), skin)
	# Face highlight (top-left Bloons shine)
	draw_circle(head_center + Vector2(-3, -2), 4.5, Color(skin_hi.r, skin_hi.g, skin_hi.b, 0.3))

	# Widow's peak hairline (bold black)
	draw_colored_polygon(PackedVector2Array([
		head_center + Vector2(-10, -6), head_center + Vector2(0, -9.5),
		head_center + Vector2(10, -6), head_center + Vector2(7, -10),
		head_center + Vector2(0, -13), head_center + Vector2(-7, -10),
	]), OL)
	draw_colored_polygon(PackedVector2Array([
		head_center + Vector2(-9, -6), head_center + Vector2(0, -8.5),
		head_center + Vector2(9, -6), head_center + Vector2(6.5, -9.5),
		head_center + Vector2(0, -12), head_center + Vector2(-6.5, -9.5),
	]), hair_col)
	# Widow's peak downward point
	draw_colored_polygon(PackedVector2Array([
		head_center + Vector2(-4, -6), head_center + Vector2(4, -6),
		head_center + Vector2(0, -2.5),
	]), OL)
	draw_colored_polygon(PackedVector2Array([
		head_center + Vector2(-3, -6), head_center + Vector2(3, -6),
		head_center + Vector2(0, -3.5),
	]), hair_col)
	# Hairline sheen lines
	draw_line(head_center + Vector2(-6, -8.5), head_center + Vector2(0, -3.5), hair_hi, 0.8)
	draw_line(head_center + Vector2(6, -8.5), head_center + Vector2(0, -3.5), hair_hi, 0.8)

	# Ears (slightly pointed)
	var l_ear = head_center + Vector2(-10, -1)
	var r_ear = head_center + Vector2(10, -1)
	draw_colored_polygon(PackedVector2Array([
		l_ear + Vector2(1, -2), l_ear + Vector2(-2, -4), l_ear + Vector2(-1, 1),
	]), OL)
	draw_colored_polygon(PackedVector2Array([
		l_ear + Vector2(1.2, -1.5), l_ear + Vector2(-1, -3), l_ear + Vector2(-0.5, 0.5),
	]), skin)
	draw_colored_polygon(PackedVector2Array([
		r_ear + Vector2(-1, -2), r_ear + Vector2(2, -4), r_ear + Vector2(1, 1),
	]), OL)
	draw_colored_polygon(PackedVector2Array([
		r_ear + Vector2(-1.2, -1.5), r_ear + Vector2(1, -3), r_ear + Vector2(0.5, 0.5),
	]), skin)

	# === EYES — RED with slit pupils! ===
	var look_dir = dir * 1.2
	var l_eye = head_center + Vector2(-4.0, -1.0)
	var r_eye = head_center + Vector2(4.0, -1.0)
	# Eye socket shadow
	draw_circle(l_eye, 5.0, Color(0.40, 0.28, 0.32, 0.4))
	draw_circle(r_eye, 5.0, Color(0.40, 0.28, 0.32, 0.4))
	# Eye outline
	draw_circle(l_eye, 5.8, OL)
	draw_circle(r_eye, 5.8, OL)
	# Eye whites
	draw_circle(l_eye, 4.8, Color(0.94, 0.90, 0.90))
	draw_circle(r_eye, 4.8, Color(0.94, 0.90, 0.90))
	# Bloodshot veins (subtle)
	for vi in range(3):
		var va = TAU * float(vi) / 3.0 + 0.5
		draw_line(l_eye + Vector2.from_angle(va) * 3.0, l_eye + Vector2.from_angle(va) * 4.5, Color(0.7, 0.2, 0.15, 0.15), 0.5)
		draw_line(r_eye + Vector2.from_angle(va) * 3.0, r_eye + Vector2.from_angle(va) * 4.5, Color(0.7, 0.2, 0.15, 0.15), 0.5)
	# RED irises (vivid, glowing)
	var eye_glow = sin(_time * 2.5) * 0.1 + 0.9
	draw_circle(l_eye + look_dir, 3.0, Color(0.60, 0.04, 0.02))
	draw_circle(l_eye + look_dir, 2.4, Color(0.82, 0.08, 0.04))
	draw_circle(l_eye + look_dir, 1.6, Color(0.95, 0.15, 0.08))
	draw_circle(r_eye + look_dir, 3.0, Color(0.60, 0.04, 0.02))
	draw_circle(r_eye + look_dir, 2.4, Color(0.82, 0.08, 0.04))
	draw_circle(r_eye + look_dir, 1.6, Color(0.95, 0.15, 0.08))
	# Iris glow halo
	draw_circle(l_eye + look_dir, 4.0, Color(0.85, 0.1, 0.05, 0.10 * eye_glow))
	draw_circle(r_eye + look_dir, 4.0, Color(0.85, 0.1, 0.05, 0.10 * eye_glow))
	# VERTICAL SLIT PUPILS
	draw_line(l_eye + look_dir * 1.1 + Vector2(0, -1.8), l_eye + look_dir * 1.1 + Vector2(0, 1.8), Color(0.02, 0.01, 0.01), 1.6)
	draw_line(r_eye + look_dir * 1.1 + Vector2(0, -1.8), r_eye + look_dir * 1.1 + Vector2(0, 1.8), Color(0.02, 0.01, 0.01), 1.6)
	# Primary highlight (big round Bloons style)
	draw_circle(l_eye + Vector2(-1.2, -1.5), 1.6, Color(1.0, 0.7, 0.6, 0.8))
	draw_circle(r_eye + Vector2(-1.2, -1.5), 1.6, Color(1.0, 0.7, 0.6, 0.8))
	# Secondary highlight
	draw_circle(l_eye + Vector2(1.0, 0.8), 0.8, Color(1.0, 0.5, 0.4, 0.5))
	draw_circle(r_eye + Vector2(1.0, 0.8), 0.8, Color(1.0, 0.5, 0.4, 0.5))
	# Heavy sinister upper eyelids
	draw_arc(l_eye, 4.8, PI + 0.1, TAU - 0.1, 10, OL, 2.2)
	draw_arc(r_eye, 4.8, PI + 0.1, TAU - 0.1, 10, OL, 2.2)

	# Eyebrows — sharp angular, thick
	draw_line(l_eye + Vector2(-4.5, -5.5), l_eye + Vector2(1.0, -6.5), OL, 2.5)
	draw_line(l_eye + Vector2(1.0, -6.5), l_eye + Vector2(4.0, -5.0), OL, 1.5)
	draw_line(r_eye + Vector2(-4.0, -5.0), r_eye + Vector2(-1.0, -6.5), OL, 2.5)
	draw_line(r_eye + Vector2(-1.0, -6.5), r_eye + Vector2(4.5, -5.5), OL, 1.5)

	# Nose — small chibi bump
	draw_circle(head_center + Vector2(0, 3.5), 2.0, OL)
	draw_circle(head_center + Vector2(0, 3.5), 1.2, skin)
	draw_circle(head_center + Vector2(-0.3, 3.0), 0.5, Color(1.0, 0.95, 0.92, 0.5))

	# Mouth — thin smirk with visible FANGS
	draw_arc(head_center + Vector2(0, 6.0), 4.0, 0.15, PI - 0.15, 12, OL, 1.8)
	draw_line(head_center + Vector2(3.8, 5.7), head_center + Vector2(5.2, 4.5), OL, 1.5)
	# Teeth row
	for thi in range(5):
		var tooth_x = -2.2 + float(thi) * 1.1
		draw_circle(head_center + Vector2(tooth_x, 6.0), 0.6, Color(0.98, 0.96, 0.92))
	# FANGS — two prominent white triangles
	var fang_extend = 0.0
	if _attack_anim > 0.0:
		fang_extend = _attack_anim * 3.0
	else:
		fang_extend = 1.8 + sin(_time * 2.0) * 0.3
	# Left fang
	draw_colored_polygon(PackedVector2Array([
		head_center + Vector2(-3.2, 5.8), head_center + Vector2(-1.8, 5.8),
		head_center + Vector2(-2.5, 5.8 + fang_extend),
	]), OL)
	draw_colored_polygon(PackedVector2Array([
		head_center + Vector2(-3.0, 6.0), head_center + Vector2(-2.0, 6.0),
		head_center + Vector2(-2.5, 5.8 + fang_extend - 0.3),
	]), Color(0.98, 0.96, 0.92))
	# Right fang
	draw_colored_polygon(PackedVector2Array([
		head_center + Vector2(1.8, 5.8), head_center + Vector2(3.2, 5.8),
		head_center + Vector2(2.5, 5.8 + fang_extend),
	]), OL)
	draw_colored_polygon(PackedVector2Array([
		head_center + Vector2(2.0, 6.0), head_center + Vector2(3.0, 6.0),
		head_center + Vector2(2.5, 5.8 + fang_extend - 0.3),
	]), Color(0.98, 0.96, 0.92))
	# Fang tips glow red when attacking
	if _attack_anim > 0.3:
		draw_circle(head_center + Vector2(-2.5, 5.8 + fang_extend), 1.5, Color(0.75, 0.10, 0.05, _attack_anim * 0.4))
		draw_circle(head_center + Vector2(2.5, 5.8 + fang_extend), 1.5, Color(0.75, 0.10, 0.05, _attack_anim * 0.4))

	# Cheek blush (subtle purple-ish for vampire)
	draw_circle(head_center + Vector2(-6, 3), 2.5, Color(0.60, 0.35, 0.45, 0.12))
	draw_circle(head_center + Vector2(6, 3), 2.5, Color(0.60, 0.35, 0.45, 0.12))

	# === NOSFERATU FORM OVERLAY (Ability 8 active) ===
	if prog_abilities[7] and _nosferatu_active > 0.0:
		var nos_alpha = clampf(_nosferatu_active / 4.0, 0.0, 1.0) * 0.3
		draw_circle(body_offset, 42.0, Color(0.2, 0.0, 0.0, nos_alpha))
		draw_arc(body_offset, 40.0, 0, TAU, 24, Color(0.5, 0.05, 0.05, nos_alpha * 1.5), 2.5)
		draw_circle(head_center + Vector2(0, -2), 14.0, Color(0.15, 0.0, 0.0, nos_alpha * 0.4))

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
		var font3 = _game_font
		draw_string(font3, Vector2(-16, -80), "!", HORIZONTAL_ALIGNMENT_CENTER, 32, 30, Color(0.6, 0.1, 0.1, 0.7 + pulse * 0.3))

	# === DAMAGE COUNTER ===
	if damage_dealt > 0:
		var font = _game_font
		var dmg_text = str(int(damage_dealt)) + " DMG"
		if stat_upgrade_level > 0:
			dmg_text += " • Lv." + str(stat_upgrade_level)
		draw_string(font, Vector2(-36, 56), dmg_text, HORIZONTAL_ALIGNMENT_LEFT, 160, 12, Color(0.8, 0.15, 0.1, 0.5))

	# === UPGRADE NAME FLASH ===
	if _upgrade_flash > 0.0 and _upgrade_name != "":
		var font2 = _game_font
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
