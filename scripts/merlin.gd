extends Node2D
## Merlin — wizard support tower. Buffs allies, curses enemies, summons Excalibur strikes.
## Tier 1 (5000 DMG): Arcane Mastery — spells bounce to 1 additional enemy
## Tier 2 (10000 DMG): Enchanted Aura — nearby towers gain +15% attack speed
## Tier 3 (15000 DMG): Curse of Ages — hit enemies take +20% damage from all sources for 5s
## Tier 4 (20000 DMG): Archmage — permanent aura, Excalibur every 15s, spells chain to 3

# Base stats
var damage: float = 40.0
var fire_rate: float = 1.4
var attack_range: float = 220.0
var fire_cooldown: float = 0.0
var staff_angle: float = 0.0
var target: Node2D = null
var gold_bonus: int = 2

# Animation timers
var _time: float = 0.0
var _attack_anim: float = 0.0
var _cast_hand_glow: float = 0.0

# Damage tracking and upgrades
var damage_dealt: float = 0.0
var upgrade_tier: int = 0
var _upgrade_flash: float = 0.0
var _upgrade_name: String = ""

# Tier 1: Arcane Mastery — spell bounce
var bounce_count: int = 0

# Tier 2: Enchanted Aura — attack speed buff to nearby towers
var aura_active: bool = false
var _aura_refresh_timer: float = 0.0
var _aura_refresh_interval: float = 2.0

# Tier 3: Curse of Ages — enemies take +20% damage
var curse_on_hit: bool = false

# Tier 4: Archmage — auto Excalibur
var excalibur_timer: float = 15.0
var excalibur_cooldown: float = 15.0
var _excalibur_flash: float = 0.0

# Kill tracking
var kill_count: int = 0

# === PROGRESSIVE ABILITIES (9 tiers, unlocked via lifetime damage) ===
const PROG_ABILITY_NAMES = [
	"Druidic Knowledge", "Crystal Scrying", "Nimue's Blessing", "Stone Circle",
	"Camelot's Shield", "Time Warp", "Dragon Breath", "Holy Grail", "Avatar of Magic"
]
const PROG_ABILITY_DESCS = [
	"Spells fly 30% faster, +15% damage",
	"Reveal camo enemies in range every 10s",
	"Restore 1 life every 25s",
	"Every 14s, AoE stun all in range for 1.5s",
	"Every 18s, shield nearest tower (block next 3 hits)",
	"Every 16s, slow all enemies in range by 40% for 3s",
	"Every 20s, fire breath arc deals 4x damage in cone",
	"Every 25s, heal 2 lives + strike strongest for 6x",
	"Every 10s, arcane storm hits EVERY enemy on map for 2x"
]
var prog_abilities: Array = [false, false, false, false, false, false, false, false, false]
# Ability timers
var _crystal_scrying_timer: float = 10.0
var _nimue_blessing_timer: float = 25.0
var _stone_circle_timer: float = 14.0
var _camelot_shield_timer: float = 18.0
var _time_warp_timer: float = 16.0
var _dragon_breath_timer: float = 20.0
var _holy_grail_timer: float = 25.0
var _avatar_magic_timer: float = 10.0
# Visual flash timers
var _stone_circle_flash: float = 0.0
var _dragon_breath_flash: float = 0.0
var _avatar_magic_flash: float = 0.0

const STAT_UPGRADE_INTERVAL: float = 500.0
const ABILITY_THRESHOLD: float = 1500.0
var stat_upgrade_level: int = 0
var ability_chosen: bool = false
var awaiting_ability_choice: bool = false
const TIER_NAMES = [
	"Arcane Mastery",
	"Enchanted Aura",
	"Curse of Ages",
	"Archmage"
]
const ABILITY_DESCRIPTIONS = [
	"Spells bounce to 1 additional enemy",
	"Nearby towers gain +15% attack speed",
	"Hit enemies take +20% damage for 5s",
	"Permanent aura, Excalibur every 15s, chain 3"
]
const TIER_COSTS = [90, 200, 340, 550]
var is_selected: bool = false
var base_cost: int = 0

var spell_bolt_scene = preload("res://scenes/spell_bolt.tscn")

# Attack sounds — mystical chime/sparkle evolving with tier
var _attack_sounds: Array = []
var _attack_sounds_by_tier: Array = []
var _attack_player: AudioStreamPlayer

# Ability sounds
var _excalibur_sound: AudioStreamWAV
var _excalibur_player: AudioStreamPlayer
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

	# Excalibur strike — dramatic descending sword chime (E5→B4→G4 + metallic ring)
	var exc_rate := 22050
	var exc_dur := 0.7
	var exc_samples := PackedFloat32Array()
	exc_samples.resize(int(exc_rate * exc_dur))
	var exc_notes := [659.25, 493.88, 392.0]  # E5, B4, G4
	var exc_note_len := int(exc_rate * exc_dur) / 3
	for i in exc_samples.size():
		var t := float(i) / exc_rate
		var ni := mini(i / exc_note_len, 2)
		var nt := float(i - ni * exc_note_len) / float(exc_rate)
		var freq: float = exc_notes[ni]
		var att := minf(nt * 40.0, 1.0)
		var dec := exp(-nt * 6.0)
		var env := att * dec * 0.4
		# Metallic bell tone (fundamental + octave + fifth + high shimmer)
		var s := sin(TAU * freq * t) + sin(TAU * freq * 2.0 * t) * 0.3 + sin(TAU * freq * 1.5 * t) * 0.2
		# Metallic shimmer (high detuned harmonics)
		s += sin(TAU * freq * 3.01 * t) * 0.08 * exp(-t * 8.0)
		s += sin(TAU * freq * 4.02 * t) * 0.05 * exp(-t * 10.0)
		# Impact thud at start of each note
		var thud := sin(TAU * 60.0 * t) * exp(-nt * 200.0) * 0.15
		exc_samples[i] = clampf(s * env + thud, -1.0, 1.0)
	_excalibur_sound = _samples_to_wav(exc_samples, exc_rate)
	_excalibur_player = AudioStreamPlayer.new()
	_excalibur_player.stream = _excalibur_sound
	_excalibur_player.volume_db = -5.0
	add_child(_excalibur_player)

	# Upgrade chime — ascending magical arpeggio (C5→E5→G5→C6)
	var up_rate := 22050
	var up_dur := 0.4
	var up_samples := PackedFloat32Array()
	up_samples.resize(int(up_rate * up_dur))
	var up_notes := [523.25, 659.25, 783.99, 1046.50]
	var up_note_len := int(up_rate * up_dur) / 4
	for i in up_samples.size():
		var t := float(i) / up_rate
		var ni := mini(i / up_note_len, 3)
		var nt := float(i - ni * up_note_len) / float(up_rate)
		var freq: float = up_notes[ni]
		var env := minf(nt * 50.0, 1.0) * exp(-nt * 10.0) * 0.35
		var s := sin(TAU * freq * t) + sin(TAU * freq * 2.0 * t) * 0.25 + sin(TAU * freq * 3.0 * t) * 0.1
		up_samples[i] = clampf(s * env, -1.0, 1.0)
	_upgrade_sound = _samples_to_wav(up_samples, up_rate)
	_upgrade_player = AudioStreamPlayer.new()
	_upgrade_player.stream = _upgrade_sound
	_upgrade_player.volume_db = -4.0
	add_child(_upgrade_player)

func _process(delta: float) -> void:
	_time += delta
	fire_cooldown -= delta
	_upgrade_flash = max(_upgrade_flash - delta * 0.5, 0.0)
	_excalibur_flash = max(_excalibur_flash - delta * 1.5, 0.0)
	_attack_anim = max(_attack_anim - delta * 3.0, 0.0)
	_cast_hand_glow = max(_cast_hand_glow - delta * 4.0, 0.0)
	target = _find_nearest_enemy()

	if target:
		var desired = global_position.angle_to_point(target.global_position) + PI
		staff_angle = lerp_angle(staff_angle, desired, 8.0 * delta)
		if fire_cooldown <= 0.0:
			_shoot()
			fire_cooldown = 1.0 / (fire_rate * _speed_mult())
			_attack_anim = 1.0
			_cast_hand_glow = 1.0

	# Tier 2+: Enchanted Aura buff application
	if upgrade_tier >= 2:
		aura_active = true
		_aura_refresh_timer -= delta
		if _aura_refresh_timer <= 0.0:
			_apply_aura_buff()
			_aura_refresh_timer = _aura_refresh_interval

	# Tier 4: Auto Excalibur strike
	if upgrade_tier >= 4:
		excalibur_timer -= delta
		if excalibur_timer <= 0.0 and _has_enemies_in_range():
			_excalibur_strike()
			excalibur_timer = excalibur_cooldown

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
	var nearest_dist: float = attack_range * _range_mult()
	for enemy in enemies:
		var dist = global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest = enemy
			nearest_dist = dist
	return nearest

func _find_strongest_enemy() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var strongest: Node2D = null
	var most_hp: float = 0.0
	var eff_range = attack_range * _range_mult()
	for enemy in enemies:
		if global_position.distance_to(enemy.global_position) < eff_range:
			if enemy.health > most_hp:
				most_hp = enemy.health
				strongest = enemy
	return strongest

func _shoot() -> void:
	if not target:
		return
	if _attack_player and _attack_sounds.size() > 0 and not _is_sfx_muted():
		_attack_player.stream = _attack_sounds[_get_note_index() % _attack_sounds.size()]
		_attack_player.play()
	_fire_spell(target)

func _fire_spell(t: Node2D) -> void:
	var bolt = spell_bolt_scene.instantiate()
	bolt.global_position = global_position + Vector2.from_angle(staff_angle) * 18.0
	var dmg_mult = 1.0
	# Ability 1: Druidic Knowledge — +15% damage
	if prog_abilities[0]:
		dmg_mult *= 1.15
	bolt.damage = damage * dmg_mult * _damage_mult()
	bolt.target = t
	bolt.gold_bonus = int(gold_bonus * _gold_mult())
	bolt.source_tower = self
	bolt.bounce_count = bounce_count
	bolt.curse_on_hit = curse_on_hit
	if curse_on_hit:
		bolt.curse_mult = 1.2
		bolt.curse_duration = 5.0
	# Ability 1: Druidic Knowledge — 30% faster bolts
	if prog_abilities[0]:
		bolt.speed *= 1.3
	get_tree().get_first_node_in_group("main").add_child(bolt)

func _excalibur_strike() -> void:
	if _excalibur_player and not _is_sfx_muted(): _excalibur_player.play()
	_excalibur_flash = 1.0
	var strongest = _find_strongest_enemy()
	if strongest and strongest.has_method("take_damage"):
		var dmg = damage * 5.0 * _damage_mult()
		strongest.take_damage(dmg)
		register_damage(dmg)
		# Stun for 3s
		if strongest.has_method("apply_sleep"):
			strongest.apply_sleep(3.0)

func _apply_aura_buff() -> void:
	var buff_range = attack_range * _range_mult() * 0.8
	for tower in get_tree().get_nodes_in_group("towers"):
		if tower == self:
			continue
		if global_position.distance_to(tower.global_position) < buff_range:
			if tower.has_method("set_synergy_buff"):
				tower.clear_synergy_buff()
				var speed_bonus = 0.15
				if upgrade_tier >= 4:
					speed_bonus = 0.25
				tower.set_synergy_buff({"attack_speed": speed_bonus})

func register_kill() -> void:
	kill_count += 1
	if kill_count % 12 == 0:
		var bonus = 4 + kill_count / 12
		var main = get_tree().get_first_node_in_group("main")
		if main:
			main.add_gold(bonus)
		_upgrade_flash = 1.0
		_upgrade_name = "Arcane Harvest %d gold!" % bonus

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
		1: # Arcane Mastery — spells bounce to 1 extra enemy
			bounce_count = 1
			damage = 52.0
			fire_rate = 1.7
			attack_range = 240.0
		2: # Enchanted Aura — nearby towers +15% speed
			damage = 68.0
			fire_rate = 2.0
			attack_range = 260.0
			aura_active = true
			gold_bonus = 3
		3: # Curse of Ages — hit enemies take +20% damage
			damage = 85.0
			fire_rate = 2.3
			attack_range = 280.0
			curse_on_hit = true
			gold_bonus = 4
		4: # Archmage — full power
			damage = 110.0
			fire_rate = 2.8
			attack_range = 310.0
			gold_bonus = 6
			bounce_count = 3
			excalibur_cooldown = 15.0

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
	return "Merlin"

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
	# Mystical chime frequencies — crystalline bell tones
	var chime_notes := [587.33, 698.46, 783.99, 880.00, 783.99, 698.46, 587.33, 880.00]  # D5, F5, G5, A5, G5, F5, D5, A5 (D minor crystal arpeggio)
	var mix_rate := 44100
	_attack_sounds_by_tier = []

	# --- Tier 0: Simple Crystal Chime (pure bell + sparkle) ---
	var t0 := []
	for note_idx in chime_notes.size():
		var freq: float = chime_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.15))
		for i in samples.size():
			var t := float(i) / mix_rate
			# Crystal bell — bright decay, even harmonics
			var env := exp(-t * 20.0) * 0.3
			var fund := sin(t * freq * TAU)
			var h2 := sin(t * freq * 2.0 * TAU) * 0.25 * exp(-t * 30.0)
			var h3 := sin(t * freq * 3.0 * TAU) * 0.12 * exp(-t * 40.0)
			# High sparkle shimmer
			var sparkle := sin(t * freq * 5.0 * TAU) * 0.06 * exp(-t * 50.0)
			samples[i] = clampf((fund + h2 + h3 + sparkle) * env, -1.0, 1.0)
		t0.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t0)

	# --- Tier 1: Arcane Chime (deeper resonance + mystical warble) ---
	var t1 := []
	for note_idx in chime_notes.size():
		var freq: float = chime_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.18))
		for i in samples.size():
			var t := float(i) / mix_rate
			var env := exp(-t * 16.0) * 0.3
			var fund := sin(t * freq * TAU)
			var h2 := sin(t * freq * 2.0 * TAU) * 0.2 * exp(-t * 22.0)
			var h3 := sin(t * freq * 3.0 * TAU) * 0.15 * exp(-t * 30.0)
			# Warble (slight vibrato)
			var warble := sin(t * freq * 1.005 * TAU) * 0.12 * exp(-t * 18.0)
			var sparkle := sin(t * freq * 4.0 * TAU) * 0.06 * exp(-t * 45.0)
			samples[i] = clampf((fund + h2 + h3 + warble + sparkle) * env, -1.0, 1.0)
		t1.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t1)

	# --- Tier 2: Enchanted Bell (rich chorus, aura hum undertone) ---
	var t2 := []
	for note_idx in chime_notes.size():
		var freq: float = chime_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.2))
		for i in samples.size():
			var t := float(i) / mix_rate
			var env := exp(-t * 14.0) * 0.28
			var fund := sin(t * freq * TAU)
			var h2 := sin(t * freq * 2.0 * TAU) * 0.22 * exp(-t * 20.0)
			var h3 := sin(t * freq * 3.0 * TAU) * 0.12 * exp(-t * 28.0)
			# Chorus (detuned copies)
			var chorus := sin(t * freq * 1.003 * TAU) * 0.1 + sin(t * freq * 0.997 * TAU) * 0.1
			# Aura hum (low octave pad)
			var hum := sin(t * freq * 0.5 * TAU) * 0.08 * exp(-t * 10.0)
			samples[i] = clampf((fund + h2 + h3 + chorus + hum) * env, -1.0, 1.0)
		t2.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t2)

	# --- Tier 3: Cursed Chime (dark undertone, dissonant minor second) ---
	var t3 := []
	for note_idx in chime_notes.size():
		var freq: float = chime_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.2))
		for i in samples.size():
			var t := float(i) / mix_rate
			var env := exp(-t * 13.0) * 0.28
			var fund := sin(t * freq * TAU)
			var h2 := sin(t * freq * 2.0 * TAU) * 0.18 * exp(-t * 20.0)
			# Dissonant minor second overtone (cursed sound)
			var curse := sin(t * freq * 1.059 * TAU) * 0.12 * exp(-t * 16.0)
			var h3 := sin(t * freq * 3.0 * TAU) * 0.1 * exp(-t * 25.0)
			# Dark sub-bass thrum
			var dark := sin(t * freq * 0.25 * TAU) * 0.06 * exp(-t * 8.0)
			var sparkle := sin(t * freq * 5.0 * TAU) * 0.04 * exp(-t * 40.0)
			samples[i] = clampf((fund + h2 + h3 + curse + dark + sparkle) * env, -1.0, 1.0)
		t3.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t3)

	# --- Tier 4: Archmage Bell (full ethereal choir + cosmic shimmer) ---
	var t4 := []
	for note_idx in chime_notes.size():
		var freq: float = chime_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.25))
		for i in samples.size():
			var t := float(i) / mix_rate
			var env := exp(-t * 10.0) * 0.25
			var fund := sin(t * freq * TAU)
			var h2 := sin(t * freq * 2.0 * TAU) * 0.2
			var h3 := sin(t * freq * 3.0 * TAU) * 0.12 * exp(-t * 18.0)
			var h4 := sin(t * freq * 4.0 * TAU) * 0.06 * exp(-t * 22.0)
			# Ethereal chorus (wide detuning)
			var choir := sin(t * freq * 1.005 * TAU) * 0.08 + sin(t * freq * 0.995 * TAU) * 0.08
			choir += sin(t * freq * 2.003 * TAU) * 0.05 + sin(t * freq * 1.998 * TAU) * 0.05
			# Cosmic shimmer (very high harmonics, slow fade)
			var cosmic := sin(t * freq * 6.0 * TAU) * 0.03 * exp(-t * 8.0)
			cosmic += sin(t * freq * 8.0 * TAU) * 0.02 * exp(-t * 10.0)
			# Sub-bass power (Archmage presence)
			var power := sin(t * freq * 0.5 * TAU) * 0.06 * exp(-t * 6.0)
			samples[i] = clampf((fund + h2 + h3 + h4 + choir + cosmic + power) * env, -1.0, 1.0)
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
	if main and main.survivor_progress.has(main.TowerType.MERLIN):
		var p = main.survivor_progress[main.TowerType.MERLIN]
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
	if prog_abilities[0]:  # Druidic Knowledge: +15% damage (applied in _fire_spell)
		pass

func get_progressive_ability_name(index: int) -> String:
	if index >= 0 and index < PROG_ABILITY_NAMES.size():
		return PROG_ABILITY_NAMES[index]
	return ""

func get_progressive_ability_desc(index: int) -> String:
	if index >= 0 and index < PROG_ABILITY_DESCS.size():
		return PROG_ABILITY_DESCS[index]
	return ""

func register_damage(amount: float) -> void:
	damage_dealt += amount
	# Register with main for progressive ability tracking
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("register_tower_damage"):
		main.register_tower_damage(main.TowerType.MERLIN, amount)

func _process_progressive_abilities(delta: float) -> void:
	# Visual flash decay
	_stone_circle_flash = max(_stone_circle_flash - delta * 2.0, 0.0)
	_dragon_breath_flash = max(_dragon_breath_flash - delta * 2.0, 0.0)
	_avatar_magic_flash = max(_avatar_magic_flash - delta * 1.5, 0.0)

	# Ability 2: Crystal Scrying — reveal camo
	if prog_abilities[1]:
		_crystal_scrying_timer -= delta
		if _crystal_scrying_timer <= 0.0:
			_crystal_scrying_reveal()
			_crystal_scrying_timer = 10.0

	# Ability 3: Nimue's Blessing — restore life
	if prog_abilities[2]:
		_nimue_blessing_timer -= delta
		if _nimue_blessing_timer <= 0.0:
			var main = get_tree().get_first_node_in_group("main")
			if main and main.has_method("restore_life"):
				main.restore_life(1)
			_nimue_blessing_timer = 25.0

	# Ability 4: Stone Circle — AoE stun
	if prog_abilities[3]:
		_stone_circle_timer -= delta
		if _stone_circle_timer <= 0.0 and _has_enemies_in_range():
			_stone_circle_stun()
			_stone_circle_timer = 14.0

	# Ability 5: Camelot's Shield — block hits for nearest tower
	if prog_abilities[4]:
		_camelot_shield_timer -= delta
		if _camelot_shield_timer <= 0.0:
			_camelot_shield()
			_camelot_shield_timer = 18.0

	# Ability 6: Time Warp — slow all enemies in range
	if prog_abilities[5]:
		_time_warp_timer -= delta
		if _time_warp_timer <= 0.0 and _has_enemies_in_range():
			_time_warp_slow()
			_time_warp_timer = 16.0

	# Ability 7: Dragon Breath — cone damage
	if prog_abilities[6]:
		_dragon_breath_timer -= delta
		if _dragon_breath_timer <= 0.0 and _has_enemies_in_range():
			_dragon_breath_attack()
			_dragon_breath_timer = 20.0

	# Ability 8: Holy Grail — heal + strike strongest
	if prog_abilities[7]:
		_holy_grail_timer -= delta
		if _holy_grail_timer <= 0.0:
			_holy_grail_strike()
			_holy_grail_timer = 25.0

	# Ability 9: Avatar of Magic — arcane storm on all enemies
	if prog_abilities[8]:
		_avatar_magic_timer -= delta
		if _avatar_magic_timer <= 0.0:
			_avatar_magic_storm()
			_avatar_magic_timer = 10.0

func _crystal_scrying_reveal() -> void:
	# Reveal camo enemies in range
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) < attack_range:
			if "is_camo" in e:
				e.is_camo = false

func _stone_circle_stun() -> void:
	_stone_circle_flash = 1.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) < attack_range:
			if e.has_method("apply_sleep"):
				e.apply_sleep(1.5)

func _camelot_shield() -> void:
	# Find nearest allied tower and boost it
	var nearest_tower: Node2D = null
	var nearest_dist: float = attack_range
	for tower in get_tree().get_nodes_in_group("towers"):
		if tower == self:
			continue
		var dist = global_position.distance_to(tower.global_position)
		if dist < nearest_dist:
			nearest_tower = tower
			nearest_dist = dist
	if nearest_tower and nearest_tower.has_method("set_synergy_buff"):
		nearest_tower.set_synergy_buff({"damage": 0.20})

func _time_warp_slow() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) < attack_range:
			if e.has_method("apply_slow"):
				e.apply_slow(0.6, 3.0)

func _dragon_breath_attack() -> void:
	_dragon_breath_flash = 1.0
	# Cone attack in aim direction
	var aim_dir = Vector2.from_angle(staff_angle)
	for e in get_tree().get_nodes_in_group("enemies"):
		var to_enemy = (e.global_position - global_position)
		var dist = to_enemy.length()
		if dist < attack_range:
			var angle_to = aim_dir.angle_to(to_enemy.normalized())
			if abs(angle_to) < PI / 3.0:  # 60 degree cone
				if e.has_method("take_damage"):
					var dmg = damage * 4.0 * _damage_mult()
					e.take_damage(dmg)
					register_damage(dmg)

func _holy_grail_strike() -> void:
	# Heal 2 lives
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("restore_life"):
		main.restore_life(2)
	# Strike strongest enemy in range
	var strongest = _find_strongest_enemy()
	if strongest and strongest.has_method("take_damage"):
		var dmg = damage * 6.0 * _damage_mult()
		strongest.take_damage(dmg)
		register_damage(dmg)

func _avatar_magic_storm() -> void:
	_avatar_magic_flash = 1.0
	# Deal 2x damage to EVERY enemy on map
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("take_damage"):
			var dmg = damage * 2.0 * _damage_mult()
			e.take_damage(dmg)
			register_damage(dmg)

# === DRAW ===

func _draw() -> void:
	# === 1. SELECTION RING ===
	if is_selected:
		var pulse = (sin(_time * 3.0) + 1.0) * 0.5
		var ring_alpha = 0.5 + pulse * 0.3
		draw_arc(Vector2.ZERO, 40.0, 0, TAU, 48, Color(0.4, 0.3, 0.9, ring_alpha), 2.5)
		draw_arc(Vector2.ZERO, 43.0, 0, TAU, 48, Color(0.5, 0.4, 1.0, ring_alpha * 0.4), 1.5)

	# === 2. RANGE ARC ===
	draw_arc(Vector2.ZERO, attack_range, 0, TAU, 64, Color(0.4, 0.3, 0.8, 0.06), 1.0)

	# === 3. AIM DIRECTION ===
	var dir = Vector2.from_angle(staff_angle)
	var perp = dir.rotated(PI / 2.0)

	# === 4. IDLE ANIMATION (wise, gentle sway) ===
	var bounce = abs(sin(_time * 2.0)) * 2.5
	var breathe = sin(_time * 1.5) * 1.5
	var weight_shift = sin(_time * 0.8) * 2.0  # Slow gentle sway
	var bob = Vector2(weight_shift, -bounce - breathe)

	# Tier 4: Floating pose (Archmage levitating)
	var fly_offset = Vector2.ZERO
	if upgrade_tier >= 4:
		fly_offset = Vector2(0, -12.0 + sin(_time * 1.2) * 4.0)

	var body_offset = bob + fly_offset

	# Per-joint differential offsets
	var hip_shift = sin(_time * 0.8) * 1.0
	var shoulder_counter = -sin(_time * 0.8) * 0.6

	# Cast animation pulse
	var cast_pulse = 0.0
	if _attack_anim > 0.3:
		cast_pulse = sin(_attack_anim * 20.0) * _attack_anim

	# === 5. SKIN COLORS (elderly, wise) ===
	var skin_base = Color(0.88, 0.76, 0.64)
	var skin_shadow = Color(0.75, 0.62, 0.50)
	var skin_highlight = Color(0.94, 0.84, 0.72)

	# === 6. UPGRADE FLASH ===
	if _upgrade_flash > 0.0:
		draw_circle(Vector2.ZERO, 80.0 + _upgrade_flash * 24.0, Color(0.3, 0.2, 0.7, _upgrade_flash * 0.25))

	# === 7. EXCALIBUR FLASH ===
	if _excalibur_flash > 0.0:
		# Descending spectral sword from sky
		var sword_y = -120.0 + (1.0 - _excalibur_flash) * 80.0
		var sword_alpha = _excalibur_flash * 0.6
		# Blade
		draw_line(Vector2(0, sword_y), Vector2(0, sword_y + 50), Color(0.85, 0.9, 1.0, sword_alpha), 4.0)
		draw_line(Vector2(0, sword_y), Vector2(0, sword_y + 50), Color(1.0, 1.0, 1.0, sword_alpha * 0.5), 2.0)
		# Crossguard
		draw_line(Vector2(-10, sword_y + 42), Vector2(10, sword_y + 42), Color(0.85, 0.75, 0.3, sword_alpha), 3.0)
		# Impact ring
		var impact_r = 25.0 + (1.0 - _excalibur_flash) * 60.0
		draw_arc(Vector2.ZERO, impact_r, 0, TAU, 32, Color(0.85, 0.9, 1.0, _excalibur_flash * 0.3), 2.5)
		draw_arc(Vector2.ZERO, impact_r * 0.7, 0, TAU, 24, Color(1.0, 0.95, 0.7, _excalibur_flash * 0.2), 1.8)
		# Golden light rays
		for ri in range(8):
			var ra = TAU * float(ri) / 8.0 + _excalibur_flash * 2.0
			var r_inner = Vector2.from_angle(ra) * (impact_r * 0.4)
			var r_outer = Vector2.from_angle(ra) * (impact_r + 5.0)
			draw_line(r_inner, r_outer, Color(0.9, 0.85, 0.5, _excalibur_flash * 0.35), 1.5)

	# === PROGRESSIVE ABILITY VISUAL EFFECTS ===
	# Ability 2: Crystal Scrying — floating crystal ball pulse
	if prog_abilities[1]:
		var scry_pulse = (sin(_time * 2.0) + 1.0) * 0.5
		draw_circle(body_offset + Vector2(0, -55), 3.0, Color(0.5, 0.6, 1.0, 0.1 + scry_pulse * 0.1))

	# Ability 4: Stone Circle flash
	if _stone_circle_flash > 0.0:
		var sc_r = 30.0 + (1.0 - _stone_circle_flash) * 50.0
		draw_arc(Vector2.ZERO, sc_r, 0, TAU, 24, Color(0.5, 0.45, 0.3, _stone_circle_flash * 0.4), 3.0)
		# Rune symbols around circle
		for sci in range(6):
			var sc_a = TAU * float(sci) / 6.0 + _stone_circle_flash * 1.5
			var sc_pos = Vector2.from_angle(sc_a) * sc_r
			draw_circle(sc_pos, 2.5, Color(0.6, 0.5, 0.3, _stone_circle_flash * 0.5))

	# Ability 7: Dragon Breath flash — fire cone
	if _dragon_breath_flash > 0.0:
		var db_dir = Vector2.from_angle(staff_angle)
		for dbi in range(8):
			var db_spread = (float(dbi) - 3.5) * 0.1
			var db_end = db_dir.rotated(db_spread) * (80.0 + (1.0 - _dragon_breath_flash) * 40.0)
			var fire_t = float(dbi) / 7.0
			var fire_col = Color(1.0, 0.4 + fire_t * 0.4, 0.1, _dragon_breath_flash * 0.3)
			draw_line(Vector2.ZERO, db_end, fire_col, 3.0 - float(dbi) * 0.2)

	# Ability 9: Avatar of Magic flash — arcane storm
	if _avatar_magic_flash > 0.0:
		for ami in range(10):
			var am_x = -100.0 + float(ami) * 20.0
			var am_y = -110.0 + (1.0 - _avatar_magic_flash) * 50.0
			draw_line(Vector2(am_x, am_y), Vector2(am_x + sin(float(ami)) * 5.0, am_y + 20), Color(0.4, 0.3, 0.9, _avatar_magic_flash * 0.4), 2.0)
			draw_circle(Vector2(am_x, am_y + 20), 2.0, Color(0.5, 0.4, 1.0, _avatar_magic_flash * 0.3))

	# === 8. STONE PLATFORM with ancient runes ===
	var plat_y = 22.0
	# Platform shadow
	draw_circle(Vector2(0, plat_y + 4), 28.0, Color(0, 0, 0, 0.15))
	# Stone platform ellipse
	draw_set_transform(Vector2(0, plat_y), 0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 28.0, Color(0.22, 0.20, 0.25))
	draw_circle(Vector2.ZERO, 25.0, Color(0.30, 0.28, 0.34))
	draw_circle(Vector2.ZERO, 20.0, Color(0.38, 0.35, 0.42))
	# Stone texture dots
	for si in range(8):
		var sa = TAU * float(si) / 8.0
		draw_circle(Vector2.from_angle(sa) * 16.0, 3.0, Color(0.28, 0.25, 0.32, 0.4))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# Platform top highlight
	draw_set_transform(Vector2(0, plat_y - 2), 0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 22.0, Color(0.44, 0.40, 0.48, 0.3))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	# Ancient runes carved into platform (faint blue glow)
	var rune_glow = 0.15 + sin(_time * 1.5) * 0.08
	for ri in range(6):
		var ra = TAU * float(ri) / 6.0 + _time * 0.2
		var rune_pos = Vector2(cos(ra) * 18.0, plat_y + sin(ra) * 7.0)
		# Rune glyph (cross + arc)
		var rune_col = Color(0.3, 0.4, 0.9, rune_glow)
		draw_line(rune_pos + Vector2(-2, 0), rune_pos + Vector2(2, 0), rune_col, 0.8)
		draw_line(rune_pos + Vector2(0, -2), rune_pos + Vector2(0, 2), rune_col, 0.8)
		draw_arc(rune_pos, 1.5, 0, PI, 4, Color(0.35, 0.45, 0.95, rune_glow * 0.7), 0.5)

	# Tier 2+: Aura ring around base
	if upgrade_tier >= 2:
		var aura_pulse = sin(_time * 2.0) * 3.0
		var aura_alpha = 0.08 + sin(_time * 2.5) * 0.04
		draw_arc(Vector2(0, plat_y), 35.0 + aura_pulse, 0, TAU, 32, Color(0.4, 0.3, 0.9, aura_alpha + 0.05), 2.0)
		draw_arc(Vector2(0, plat_y), 30.0 + aura_pulse * 0.6, 0, TAU, 24, Color(0.5, 0.4, 1.0, aura_alpha), 1.5)

	# === 9. SHADOW WISPS (arcane mist) ===
	for ti in range(5):
		var ta = TAU * float(ti) / 5.0 + _time * 0.4
		var t_base = Vector2(cos(ta) * 24.0, plat_y + sin(ta) * 8.0)
		var t_end = t_base + Vector2(sin(_time * 0.9 + float(ti)) * 5.0, 6.0 + sin(_time * 1.3 + float(ti)) * 3.0)
		draw_line(t_base, t_end, Color(0.15, 0.10, 0.30, 0.18), 2.0)
		draw_line(t_end, t_end + Vector2(sin(_time + float(ti)) * 3.0, 4.0), Color(0.12, 0.08, 0.25, 0.10), 1.5)

	# === 10. TIER PIPS (arcane/crystal colors) ===
	for i in range(upgrade_tier):
		var pip_angle = -PI / 2.0 + float(i) * (TAU / 4.0) - (float(upgrade_tier - 1) * TAU / 8.0)
		var pip_pos = Vector2(cos(pip_angle) * 22.0, plat_y + sin(pip_angle) * 8.0)
		var pip_col: Color
		match i:
			0: pip_col = Color(0.3, 0.25, 0.8)    # arcane blue
			1: pip_col = Color(0.5, 0.4, 0.9)      # enchanted purple
			2: pip_col = Color(0.6, 0.2, 0.5)      # curse magenta
			3: pip_col = Color(0.8, 0.7, 1.0)      # archmage white
		draw_circle(pip_pos, 4.0, pip_col)
		draw_circle(pip_pos, 5.5, Color(pip_col.r, pip_col.g, pip_col.b, 0.15))

	# === 11. CHARACTER POSITIONS (tall proportions ~56px) ===
	var feet_y = body_offset + Vector2(hip_shift * 1.0, 14.0)
	var leg_top = body_offset + Vector2(hip_shift * 0.6, -2.0)
	var torso_center = body_offset + Vector2(shoulder_counter * 0.5, -10.0)
	var neck_base = body_offset + Vector2(shoulder_counter * 0.7, -20.0)
	var head_center = body_offset + Vector2(shoulder_counter * 0.3, -32.0)

	# === 12. TIER-SPECIFIC EFFECTS (drawn BEFORE/AROUND body) ===

	# Tier 1+: Arcane sparkle particles around staff area
	if upgrade_tier >= 1:
		for li in range(5 + upgrade_tier):
			var la = _time * (0.5 + fmod(float(li) * 1.37, 0.4)) + float(li) * TAU / float(5 + upgrade_tier)
			var lr = 20.0 + fmod(float(li) * 3.7, 14.0)
			var spark_pos = body_offset + Vector2(cos(la) * lr, sin(la) * lr * 0.5 + 5.0)
			var spark_alpha = 0.2 + sin(_time * 2.0 + float(li)) * 0.1
			var spark_size = 1.2 + sin(_time * 1.5 + float(li) * 2.0) * 0.4
			# Star sparkle (4-point)
			draw_line(spark_pos + Vector2(-spark_size, 0), spark_pos + Vector2(spark_size, 0), Color(0.5, 0.4, 1.0, spark_alpha), 0.8)
			draw_line(spark_pos + Vector2(0, -spark_size), spark_pos + Vector2(0, spark_size), Color(0.5, 0.4, 1.0, spark_alpha), 0.8)
			draw_circle(spark_pos, spark_size * 0.4, Color(0.7, 0.6, 1.0, spark_alpha * 0.7))

	# Tier 3+: Curse symbols floating around
	if upgrade_tier >= 3:
		for ci in range(4):
			var c_seed = float(ci) * 2.37
			var c_a = _time * (0.4 + fmod(c_seed, 0.3)) + c_seed
			var c_r = 25.0 + fmod(c_seed * 3.1, 15.0)
			var c_pos = body_offset + Vector2(cos(c_a) * c_r, sin(c_a) * c_r * 0.5)
			var c_alpha = 0.2 + sin(_time * 2.0 + c_seed) * 0.08
			# Curse rune (small circle with cross)
			draw_arc(c_pos, 2.5, 0, TAU, 6, Color(0.6, 0.2, 0.5, c_alpha), 0.6)
			draw_line(c_pos + Vector2(-1.5, 0), c_pos + Vector2(1.5, 0), Color(0.6, 0.2, 0.5, c_alpha * 0.8), 0.5)
			draw_line(c_pos + Vector2(0, -1.5), c_pos + Vector2(0, 1.5), Color(0.6, 0.2, 0.5, c_alpha * 0.8), 0.5)

	# Tier 4: Full cosmic aura, floating rune circles, Excalibur ghost above
	if upgrade_tier >= 4:
		# Cosmic particles
		for fd in range(8):
			var fd_seed = float(fd) * 2.37
			var fd_angle = _time * (0.4 + fmod(fd_seed, 0.4)) + fd_seed
			var fd_radius = 30.0 + fmod(fd_seed * 5.3, 25.0)
			var fd_pos = body_offset + Vector2(cos(fd_angle) * fd_radius, sin(fd_angle) * fd_radius * 0.6)
			var fd_alpha = 0.2 + sin(_time * 2.5 + fd_seed * 2.0) * 0.12
			var fd_size = 1.5 + sin(_time * 2.0 + fd_seed) * 0.5
			# Cosmic blue-purple colors
			var cosmic_t = fmod(fd_seed * 1.7, 1.0)
			var cosmic_col = Color(0.3 + cosmic_t * 0.3, 0.2 + cosmic_t * 0.2, 0.8 + cosmic_t * 0.2, fd_alpha)
			draw_circle(fd_pos, fd_size, cosmic_col)
			draw_circle(fd_pos, fd_size * 0.5, Color(0.7, 0.6, 1.0, fd_alpha * 0.6))

		# Floating rune circles (two orbiting rings)
		for rci in range(2):
			var rc_a = _time * (0.6 + float(rci) * 0.3)
			var rc_r = 42.0 + float(rci) * 8.0
			var rc_pos = body_offset + Vector2(cos(rc_a) * rc_r, sin(rc_a) * rc_r * 0.3)
			draw_arc(rc_pos, 5.0, 0, TAU, 8, Color(0.5, 0.4, 0.9, 0.2), 0.8)
			# Rune inside
			draw_line(rc_pos + Vector2(-3, 0), rc_pos + Vector2(3, 0), Color(0.6, 0.5, 1.0, 0.15), 0.5)
			draw_line(rc_pos + Vector2(0, -3), rc_pos + Vector2(0, 3), Color(0.6, 0.5, 1.0, 0.15), 0.5)

		# Ghost Excalibur above head
		var exc_bob = sin(_time * 1.8) * 3.0
		var exc_top = body_offset + Vector2(0, -62 + exc_bob)
		var exc_bot = body_offset + Vector2(0, -42 + exc_bob)
		# Sword blade
		draw_line(exc_top, exc_bot, Color(0.8, 0.85, 1.0, 0.25), 2.5)
		draw_line(exc_top, exc_bot, Color(1.0, 1.0, 1.0, 0.12), 1.0)
		# Crossguard
		var exc_guard_y = exc_bot.y - 4
		draw_line(Vector2(exc_bot.x - 6, exc_guard_y), Vector2(exc_bot.x + 6, exc_guard_y), Color(0.85, 0.75, 0.3, 0.2), 2.0)
		# Pommel
		draw_circle(exc_bot + Vector2(0, 2), 1.5, Color(0.85, 0.75, 0.3, 0.2))
		# Sword glow
		draw_circle(exc_top.lerp(exc_bot, 0.5), 4.0, Color(0.7, 0.75, 1.0, 0.06 + sin(_time * 2.5) * 0.03))

	# === 13. CHARACTER BODY ===

	# --- Wizard robe (long, flowing, blue-purple) ---
	# Robe base color
	var robe_dark = Color(0.18, 0.12, 0.42)
	var robe_mid = Color(0.25, 0.18, 0.55)
	var robe_light = Color(0.32, 0.24, 0.62)

	# --- FEET (hidden under robe hem, just tips of pointed shoes) ---
	var l_foot = feet_y + Vector2(-6, 2)
	var r_foot = feet_y + Vector2(6, 2)
	# Pointed wizard shoes peeking out
	draw_circle(l_foot, 3.5, Color(0.20, 0.14, 0.35))
	draw_line(l_foot + Vector2(-2, 0), l_foot + Vector2(-6, -2), Color(0.22, 0.16, 0.38), 2.5)
	draw_circle(l_foot + Vector2(-6, -2), 1.5, Color(0.25, 0.18, 0.40))
	draw_circle(r_foot, 3.5, Color(0.20, 0.14, 0.35))
	draw_line(r_foot + Vector2(2, 0), r_foot + Vector2(6, -2), Color(0.22, 0.16, 0.38), 2.5)
	draw_circle(r_foot + Vector2(6, -2), 1.5, Color(0.25, 0.18, 0.40))

	# --- LONG FLOWING ROBE (covers legs entirely) ---
	var robe_wind = sin(_time * 1.5) * 2.0 + sin(_time * 2.2) * 1.0
	# Main robe body — wide A-line silhouette
	var robe_pts = PackedVector2Array([
		feet_y + Vector2(-14 + robe_wind * 0.3, 4),    # hem left
		feet_y + Vector2(-16 + robe_wind * 0.5, 0),    # hem left flare
		leg_top + Vector2(-10, 0),                       # waist left
		torso_center + Vector2(-12, 0),                  # mid left
		neck_base + Vector2(-14, 0),                     # shoulder left
		neck_base + Vector2(14, 0),                      # shoulder right
		torso_center + Vector2(12, 0),                   # mid right
		leg_top + Vector2(10, 0),                        # waist right
		feet_y + Vector2(16 + robe_wind * 0.3, 0),     # hem right flare
		feet_y + Vector2(14 + robe_wind * 0.5, 4),     # hem right
	])
	draw_colored_polygon(robe_pts, robe_dark)

	# Robe lighter inner panel
	var robe_inner = PackedVector2Array([
		feet_y + Vector2(-8, 2),
		leg_top + Vector2(-6, 0),
		torso_center + Vector2(-6, 0),
		neck_base + Vector2(-6, 0),
		neck_base + Vector2(6, 0),
		torso_center + Vector2(6, 0),
		leg_top + Vector2(6, 0),
		feet_y + Vector2(8, 2),
	])
	draw_colored_polygon(robe_inner, Color(robe_mid.r, robe_mid.g, robe_mid.b, 0.5))

	# Robe fold lines (vertical creases)
	draw_line(neck_base + Vector2(-10, 2), feet_y + Vector2(-12, 2), Color(robe_dark.r - 0.04, robe_dark.g - 0.03, robe_dark.b - 0.05, 0.4), 1.0)
	draw_line(neck_base + Vector2(10, 2), feet_y + Vector2(12, 2), Color(robe_dark.r - 0.04, robe_dark.g - 0.03, robe_dark.b - 0.05, 0.4), 1.0)
	draw_line(torso_center + Vector2(-3, -5), feet_y + Vector2(-4, 1), Color(robe_dark.r - 0.03, robe_dark.g - 0.02, robe_dark.b - 0.04, 0.3), 0.7)
	draw_line(torso_center + Vector2(3, -5), feet_y + Vector2(4, 1), Color(robe_dark.r - 0.03, robe_dark.g - 0.02, robe_dark.b - 0.04, 0.3), 0.7)

	# Silver star and moon embroidery on robe
	for ei in range(7):
		var e_seed = float(ei) * 3.17
		var ex = -8.0 + fmod(e_seed * 2.3, 16.0)
		var ey_t = fmod(e_seed * 1.7, 1.0)
		var e_pos = neck_base.lerp(feet_y, ey_t) + Vector2(ex, 0)
		var star_alpha = 0.25 + sin(_time * 1.5 + e_seed) * 0.08
		if ei % 3 == 0:
			# Star pattern (4-point)
			var ss = 1.5
			draw_line(e_pos + Vector2(-ss, 0), e_pos + Vector2(ss, 0), Color(0.7, 0.72, 0.85, star_alpha), 0.6)
			draw_line(e_pos + Vector2(0, -ss), e_pos + Vector2(0, ss), Color(0.7, 0.72, 0.85, star_alpha), 0.6)
			draw_line(e_pos + Vector2(-ss * 0.6, -ss * 0.6), e_pos + Vector2(ss * 0.6, ss * 0.6), Color(0.75, 0.78, 0.9, star_alpha * 0.6), 0.4)
			draw_line(e_pos + Vector2(ss * 0.6, -ss * 0.6), e_pos + Vector2(-ss * 0.6, ss * 0.6), Color(0.75, 0.78, 0.9, star_alpha * 0.6), 0.4)
		elif ei % 3 == 1:
			# Moon crescent
			draw_arc(e_pos, 1.8, PI * 0.3, PI * 1.7, 6, Color(0.72, 0.75, 0.88, star_alpha), 0.6)
			draw_circle(e_pos + Vector2(0.5, -0.3), 1.2, Color(robe_dark.r, robe_dark.g, robe_dark.b, star_alpha))
		else:
			# Tiny diamond
			draw_circle(e_pos, 0.8, Color(0.75, 0.78, 0.92, star_alpha))

	# Robe hem scallops (flowing edge)
	for hi in range(7):
		var hx = -13.0 + float(hi) * 4.0 + robe_wind * 0.2
		var h_depth = 2.0 + sin(float(hi) * 1.8 + _time * 1.0) * 1.2
		var h_pts = PackedVector2Array([
			feet_y + Vector2(hx - 2.0, 2),
			feet_y + Vector2(hx + 2.0, 2),
			feet_y + Vector2(hx, 2 + h_depth),
		])
		draw_colored_polygon(h_pts, robe_dark)

	# --- Belt of spell components (leather with pouches) ---
	var belt_y = leg_top + Vector2(0, -1)
	draw_line(belt_y + Vector2(-11, 0), belt_y + Vector2(11, 0), Color(0.35, 0.22, 0.10), 4.0)
	draw_line(belt_y + Vector2(-10, 0), belt_y + Vector2(10, 0), Color(0.42, 0.28, 0.14), 2.5)
	# Belt highlight
	draw_line(belt_y + Vector2(-10, -1.5), belt_y + Vector2(10, -1.5), Color(0.50, 0.34, 0.18, 0.3), 0.8)
	# Brass buckle (center) with arcane symbol
	var buckle_c = belt_y
	draw_circle(buckle_c, 3.5, Color(0.70, 0.55, 0.18))
	draw_circle(buckle_c, 2.5, Color(0.82, 0.68, 0.28))
	# Arcane star in buckle
	for bi in range(5):
		var ba = TAU * float(bi) / 5.0 - PI / 2.0
		var bp = buckle_c + Vector2.from_angle(ba) * 1.5
		var bp2 = buckle_c + Vector2.from_angle(ba + TAU * 2.0 / 5.0) * 1.5
		draw_line(bp, bp2, Color(0.3, 0.2, 0.5, 0.5), 0.4)
	# Spell component pouches (3 small pouches on belt)
	for pi in range(3):
		var px = -7.0 + float(pi) * 7.0
		var p_pos = belt_y + Vector2(px, 2)
		draw_circle(p_pos, 2.8, Color(0.36, 0.22, 0.10))
		draw_circle(p_pos + Vector2(0, -0.3), 2.0, Color(0.42, 0.28, 0.14))
		# Pouch drawstring
		draw_line(p_pos + Vector2(-1, -2), p_pos + Vector2(1, -2), Color(0.30, 0.18, 0.08, 0.5), 0.5)
		# Pouch glow (magical contents)
		var pouch_col = [Color(0.4, 0.3, 0.8), Color(0.3, 0.7, 0.4), Color(0.8, 0.6, 0.2)][pi]
		draw_circle(p_pos + Vector2(0, -1), 0.8, Color(pouch_col.r, pouch_col.g, pouch_col.b, 0.3 + sin(_time * 2.0 + float(pi)) * 0.1))

	# Crystal pendant at chest
	var pendant_pos = neck_base + Vector2(0, 4)
	# Chain
	draw_line(neck_base + Vector2(-3, 0), pendant_pos, Color(0.65, 0.60, 0.50, 0.4), 0.7)
	draw_line(neck_base + Vector2(3, 0), pendant_pos, Color(0.65, 0.60, 0.50, 0.4), 0.7)
	# Crystal (blue diamond shape)
	var crystal_pts = PackedVector2Array([
		pendant_pos + Vector2(0, -3),
		pendant_pos + Vector2(2, 0),
		pendant_pos + Vector2(0, 3),
		pendant_pos + Vector2(-2, 0),
	])
	draw_colored_polygon(crystal_pts, Color(0.3, 0.5, 0.9, 0.8))
	draw_colored_polygon(crystal_pts, Color(0.5, 0.7, 1.0, 0.3))
	# Crystal glow
	var crystal_glow = 0.15 + sin(_time * 3.0) * 0.08
	draw_circle(pendant_pos, 4.0, Color(0.4, 0.5, 0.9, crystal_glow))

	# --- Shoulder area (broad robe shoulders) ---
	var l_shoulder = neck_base + Vector2(-14, 0)
	var r_shoulder = neck_base + Vector2(14, 0)
	draw_circle(l_shoulder, 6.0, robe_dark)
	draw_circle(l_shoulder, 4.5, robe_mid)
	draw_circle(r_shoulder, 6.0, robe_dark)
	draw_circle(r_shoulder, 4.5, robe_mid)
	# Shoulder seam
	draw_arc(l_shoulder, 5.0, 0, TAU, 10, Color(robe_dark.r - 0.03, robe_dark.g - 0.02, robe_dark.b - 0.04, 0.3), 0.7)
	draw_arc(r_shoulder, 5.0, 0, TAU, 10, Color(robe_dark.r - 0.03, robe_dark.g - 0.02, robe_dark.b - 0.04, 0.3), 0.7)

	# --- RIGHT ARM: holds staff (robe sleeve) ---
	var staff_hand = r_shoulder + Vector2(4, 2) + dir * 14.0
	var staff_elbow = r_shoulder + (staff_hand - r_shoulder) * 0.45
	# Robe sleeve (covers arm mostly)
	var ra_dir = (staff_elbow - r_shoulder).normalized()
	var ra_perp = ra_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		r_shoulder + ra_perp * 5.5, r_shoulder - ra_perp * 5.0,
		staff_elbow - ra_perp * 4.5, staff_elbow + ra_perp * 5.0,
	]), robe_dark)
	draw_colored_polygon(PackedVector2Array([
		r_shoulder + ra_perp * 3.5, r_shoulder - ra_perp * 3.0,
		staff_elbow - ra_perp * 3.0, staff_elbow + ra_perp * 3.0,
	]), Color(robe_mid.r, robe_mid.g, robe_mid.b, 0.5))
	# Forearm sleeve
	var rf_dir = (staff_hand - staff_elbow).normalized()
	var rf_perp = rf_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		staff_elbow + rf_perp * 5.0, staff_elbow - rf_perp * 4.5,
		staff_hand - rf_perp * 3.0, staff_hand + rf_perp * 3.5,
	]), robe_dark)
	# Sleeve cuff (slightly flared)
	var cuff_pos = staff_elbow.lerp(staff_hand, 0.8)
	draw_line(cuff_pos - rf_perp * 3.5, cuff_pos + rf_perp * 4.0, Color(0.45, 0.38, 0.60), 2.0)
	# Hand visible at cuff — elderly skin
	draw_circle(staff_hand, 3.5, skin_shadow)
	draw_circle(staff_hand, 2.8, skin_base)
	# Fingers gripping staff
	for fi in range(3):
		var fa = float(fi - 1) * 0.3
		var finger_pos = staff_hand + Vector2.from_angle(staff_angle + fa) * 3.0
		draw_circle(finger_pos, 1.0, skin_base)
		draw_circle(finger_pos, 0.5, skin_highlight)

	# --- LEFT ARM: extended with arcane energy (casting hand) ---
	var cast_dir = dir
	var cast_hand = l_shoulder + Vector2(-2, 4) + cast_dir * 18.0
	var cast_elbow = l_shoulder + (cast_hand - l_shoulder) * 0.45
	# Robe sleeve
	var la_dir = (cast_elbow - l_shoulder).normalized()
	var la_perp = la_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		l_shoulder - la_perp * 5.5, l_shoulder + la_perp * 5.0,
		cast_elbow + la_perp * 4.5, cast_elbow - la_perp * 5.0,
	]), robe_dark)
	draw_colored_polygon(PackedVector2Array([
		l_shoulder - la_perp * 3.5, l_shoulder + la_perp * 3.0,
		cast_elbow + la_perp * 3.0, cast_elbow - la_perp * 3.0,
	]), Color(robe_mid.r, robe_mid.g, robe_mid.b, 0.5))
	# Forearm sleeve
	var lf_dir = (cast_hand - cast_elbow).normalized()
	var lf_perp = lf_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		cast_elbow - lf_perp * 5.0, cast_elbow + lf_perp * 4.5,
		cast_hand + lf_perp * 3.5, cast_hand - lf_perp * 3.5,
	]), robe_dark)
	# Sleeve cuff
	var l_cuff = cast_elbow.lerp(cast_hand, 0.75)
	draw_line(l_cuff - lf_perp * 4.0, l_cuff + lf_perp * 4.0, Color(0.45, 0.38, 0.60), 2.0)
	# Cast hand — open, palm forward with magical energy
	draw_circle(cast_hand, 3.8, skin_shadow)
	draw_circle(cast_hand, 3.0, skin_base)
	# Extended fingers (spread for casting)
	for fi in range(5):
		var fa = float(fi - 2) * 0.25
		var finger_dir = cast_dir.rotated(fa)
		var finger_tip = cast_hand + finger_dir * (4.5 - abs(float(fi) - 2.0) * 0.5)
		draw_line(cast_hand, finger_tip, skin_base, 1.5)
		draw_circle(finger_tip, 0.7, skin_highlight)
	# Arcane energy swirling around cast hand
	var hand_glow_alpha = 0.15 + _cast_hand_glow * 0.3
	draw_circle(cast_hand, 7.0, Color(0.3, 0.25, 0.8, hand_glow_alpha * 0.4))
	draw_circle(cast_hand, 5.0, Color(0.4, 0.3, 0.9, hand_glow_alpha * 0.6))
	for si in range(5):
		var sa = _time * 5.0 + float(si) * TAU / 5.0
		var sr = 5.0 + sin(_time * 3.0 + float(si)) * 1.5
		var s_pos = cast_hand + Vector2(cos(sa) * sr, sin(sa) * sr * 0.6)
		draw_circle(s_pos, 0.8 + _cast_hand_glow * 0.4, Color(0.5, 0.4, 1.0, hand_glow_alpha * 0.8))

	# === 14. STAFF — tall wooden staff with crystal orb ===
	var staff_base_pos = staff_hand
	var staff_top_pos = staff_base_pos + Vector2(0, -40)
	var staff_bottom_pos = staff_base_pos + Vector2(0, 16)
	# Staff shadow
	draw_line(staff_bottom_pos + Vector2(1, 1), staff_top_pos + Vector2(1, 1), Color(0, 0, 0, 0.08), 4.0)
	# Main wooden shaft (gnarled old wood)
	var staff_wood_dark = Color(0.38, 0.24, 0.12)
	var staff_wood_mid = Color(0.48, 0.32, 0.16)
	var staff_wood_light = Color(0.56, 0.40, 0.22)
	draw_line(staff_bottom_pos, staff_top_pos, staff_wood_dark, 4.0)
	draw_line(staff_bottom_pos, staff_top_pos, staff_wood_mid, 2.5)
	# Wood grain highlights
	draw_line(staff_bottom_pos.lerp(staff_top_pos, 0.1) + Vector2(0.5, 0), staff_bottom_pos.lerp(staff_top_pos, 0.8) + Vector2(0.5, 0), Color(staff_wood_light.r, staff_wood_light.g, staff_wood_light.b, 0.3), 0.6)
	# Wood knots
	draw_circle(staff_bottom_pos.lerp(staff_top_pos, 0.3), 1.2, Color(staff_wood_dark.r - 0.08, staff_wood_dark.g - 0.05, staff_wood_dark.b, 0.4))
	draw_circle(staff_bottom_pos.lerp(staff_top_pos, 0.6), 0.8, Color(staff_wood_dark.r - 0.05, staff_wood_dark.g - 0.03, staff_wood_dark.b, 0.3))
	# Twisted vine wrapping along staff
	for vi in range(8):
		var vt = float(vi) / 7.0
		var v_pos = staff_bottom_pos.lerp(staff_top_pos, vt)
		var vx = sin(vt * 8.0 + _time * 0.3) * 2.5
		draw_circle(v_pos + Vector2(vx, 0), 0.6, Color(0.22, 0.35, 0.15, 0.3))

	# Crystal orb at top of staff
	var orb_pos = staff_top_pos + Vector2(0, -3)
	# Orb setting (metal prongs holding crystal)
	for pi in range(3):
		var pa = TAU * float(pi) / 3.0 - PI / 2.0
		var prong_end = orb_pos + Vector2.from_angle(pa) * 4.5
		var prong_base = staff_top_pos + Vector2.from_angle(pa) * 1.5
		draw_line(prong_base, prong_end, Color(0.55, 0.48, 0.28), 1.5)
		draw_line(prong_base, prong_end, Color(0.65, 0.58, 0.35, 0.4), 0.7)
	# Crystal orb outer glow — pulses with tier
	var orb_glow_base = 0.12 + float(upgrade_tier) * 0.04
	var orb_glow = orb_glow_base + sin(_time * 2.5) * 0.06
	draw_circle(orb_pos, 8.0, Color(0.3, 0.4, 0.9, orb_glow))
	draw_circle(orb_pos, 6.5, Color(0.35, 0.45, 0.95, orb_glow + 0.05))
	# Crystal orb body
	draw_circle(orb_pos, 4.5, Color(0.25, 0.35, 0.80, 0.85))
	draw_circle(orb_pos, 3.5, Color(0.35, 0.50, 0.90, 0.9))
	# Inner light
	draw_circle(orb_pos + Vector2(-0.5, -0.8), 2.0, Color(0.55, 0.65, 1.0))
	# Specular highlight
	draw_circle(orb_pos + Vector2(-1.2, -1.5), 1.0, Color(1.0, 1.0, 1.0, 0.7))
	draw_circle(orb_pos + Vector2(0.8, 0.5), 0.5, Color(1.0, 1.0, 1.0, 0.35))
	# Subtle swirling energy inside orb
	for oi in range(3):
		var oa = _time * 2.0 + float(oi) * TAU / 3.0
		var ore = 2.0 + sin(_time * 3.0 + float(oi)) * 0.5
		var o_pos = orb_pos + Vector2(cos(oa) * ore, sin(oa) * ore * 0.7)
		draw_circle(o_pos, 0.6, Color(0.6, 0.7, 1.0, 0.4))

	# Tier 1+: Staff glow brighter
	if upgrade_tier >= 1:
		var extra_glow = 0.04 * float(upgrade_tier)
		draw_circle(orb_pos, 10.0 + float(upgrade_tier) * 2.0, Color(0.35, 0.45, 0.95, extra_glow + sin(_time * 2.0) * 0.02))

	# === HEAD AREA ===
	# Neck (elderly, slightly thinner)
	var neck_top = head_center + Vector2(0, 9)
	var neck_dir_v = (neck_top - neck_base).normalized()
	var neck_perp = neck_dir_v.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		neck_base + neck_perp * 5.0, neck_base - neck_perp * 5.0,
		neck_base.lerp(neck_top, 0.5) - neck_perp * 4.5,
		neck_top - neck_perp * 4.0, neck_top + neck_perp * 4.0,
		neck_base.lerp(neck_top, 0.5) + neck_perp * 4.5,
	]), skin_shadow)
	draw_colored_polygon(PackedVector2Array([
		neck_base + neck_perp * 4.0, neck_base - neck_perp * 4.0,
		neck_top - neck_perp * 3.0, neck_top + neck_perp * 3.0,
	]), skin_base)

	# --- Long white/silver beard (flows down from chin) ---
	var beard_base_col = Color(0.88, 0.88, 0.90)
	var beard_mid_col = Color(0.80, 0.80, 0.84)
	var beard_shadow_col = Color(0.70, 0.70, 0.76)
	var beard_sway = sin(_time * 1.8) * 1.5 + sin(_time * 2.5) * 0.8

	# Beard mass (large shape covering chin to chest)
	var beard_top = head_center + Vector2(0, 4)
	var beard_bottom = torso_center + Vector2(beard_sway * 0.5, 8)
	# Main beard polygon
	var beard_pts = PackedVector2Array([
		beard_top + Vector2(-7, 0),
		beard_top + Vector2(-8, 3),
		beard_bottom + Vector2(-5 + beard_sway * 0.3, 0),
		beard_bottom + Vector2(0 + beard_sway * 0.2, 3),
		beard_bottom + Vector2(5 + beard_sway * 0.4, 0),
		beard_top + Vector2(8, 3),
		beard_top + Vector2(7, 0),
	])
	draw_colored_polygon(beard_pts, beard_mid_col)
	# Beard highlight (lighter center)
	var beard_hi = PackedVector2Array([
		beard_top + Vector2(-4, 1),
		beard_bottom + Vector2(-2 + beard_sway * 0.2, 1),
		beard_bottom + Vector2(2 + beard_sway * 0.3, 1),
		beard_top + Vector2(4, 1),
	])
	draw_colored_polygon(beard_hi, Color(beard_base_col.r, beard_base_col.g, beard_base_col.b, 0.5))

	# Beard strand detail lines
	for bsi in range(7):
		var bx = -5.0 + float(bsi) * 1.7
		var b_top = beard_top + Vector2(bx, 2)
		var b_wave = sin(_time * 1.5 + float(bsi) * 0.9) * 1.0
		var b_bot = beard_bottom + Vector2(bx * 0.7 + beard_sway * 0.3 + b_wave, -1)
		draw_line(b_top, b_bot, Color(beard_shadow_col.r, beard_shadow_col.g, beard_shadow_col.b, 0.35), 0.7)
	# Beard tip wisps (flowing ends)
	for bti in range(3):
		var btx = -3.0 + float(bti) * 3.0
		var bt_base = beard_bottom + Vector2(btx + beard_sway * 0.3, 0)
		var bt_wave = sin(_time * 2.0 + float(bti) * 1.5) * 1.5
		var bt_tip = bt_base + Vector2(bt_wave, 4.0 + sin(_time * 1.2 + float(bti)) * 1.0)
		draw_line(bt_base, bt_tip, beard_base_col, 1.2)
		draw_line(bt_base, bt_tip.lerp(bt_base, 0.4), Color(1.0, 1.0, 1.0, 0.2), 0.6)

	# === FACE ===
	# Hair back layer (white/silver — visible around edges before face)
	var hair_sway = sin(_time * 2.0) * 1.5
	var hair_col = Color(0.85, 0.85, 0.88)
	var hair_dark = Color(0.72, 0.72, 0.78)
	# Hair mass
	draw_circle(head_center, 10.5, hair_dark)
	draw_circle(head_center + Vector2(0, -0.5), 9.5, hair_col)

	# Face (wise elderly shape, somewhat rounded)
	draw_circle(head_center + Vector2(0, 0.5), 8.8, skin_base)
	# Cheek definition (softer, aged)
	draw_arc(head_center + Vector2(-5.0, 1.5), 3.5, PI * 0.15, PI * 0.6, 8, Color(0.68, 0.52, 0.42, 0.15), 1.0)
	draw_arc(head_center + Vector2(5.0, 1.5), 3.5, PI * 0.4, PI * 0.85, 8, Color(0.68, 0.52, 0.42, 0.15), 1.0)
	# Gentle smile lines
	draw_arc(head_center + Vector2(-3.5, 2.5), 3.0, PI * 0.4, PI * 0.8, 5, Color(0.68, 0.52, 0.42, 0.12), 0.6)
	draw_arc(head_center + Vector2(3.5, 2.5), 3.0, PI * 0.2, PI * 0.6, 5, Color(0.68, 0.52, 0.42, 0.12), 0.6)
	# Forehead wrinkles (wisdom lines)
	for wri in range(3):
		var wy = -5.0 - float(wri) * 1.5
		var ww = 4.0 - float(wri) * 0.5
		draw_line(head_center + Vector2(-ww, wy), head_center + Vector2(ww, wy), Color(0.68, 0.52, 0.42, 0.12), 0.5)

	# Ears (aged, slightly larger)
	var r_ear = head_center + Vector2(8.2, -0.5)
	draw_circle(r_ear, 2.5, skin_base)
	draw_circle(r_ear + Vector2(0.3, 0), 1.7, Color(0.86, 0.70, 0.58, 0.5))
	draw_arc(r_ear, 2.0, -0.5, 1.0, 6, skin_shadow, 0.7)
	var l_ear = head_center + Vector2(-8.2, -0.5)
	draw_circle(l_ear, 2.5, skin_base)
	draw_circle(l_ear + Vector2(-0.3, 0), 1.7, Color(0.86, 0.70, 0.58, 0.5))
	draw_arc(l_ear, 2.0, PI - 0.5, PI + 1.0, 6, skin_shadow, 0.7)

	# Kind blue eyes
	var look_dir = dir * 1.0
	var l_eye = head_center + Vector2(-3.5, -1.0)
	var r_eye = head_center + Vector2(3.5, -1.0)
	# Eye socket shadow (deeper set, wise)
	draw_circle(l_eye, 3.8, Color(0.70, 0.56, 0.46, 0.25))
	draw_circle(r_eye, 3.8, Color(0.70, 0.56, 0.46, 0.25))
	# Eye whites
	draw_circle(l_eye, 3.4, Color(0.95, 0.95, 0.97))
	draw_circle(r_eye, 3.4, Color(0.95, 0.95, 0.97))
	# Blue irises (kind, deep blue)
	draw_circle(l_eye + look_dir, 2.2, Color(0.12, 0.30, 0.65))
	draw_circle(l_eye + look_dir, 1.7, Color(0.18, 0.42, 0.78))
	draw_circle(l_eye + look_dir, 1.2, Color(0.25, 0.52, 0.88))
	draw_circle(r_eye + look_dir, 2.2, Color(0.12, 0.30, 0.65))
	draw_circle(r_eye + look_dir, 1.7, Color(0.18, 0.42, 0.78))
	draw_circle(r_eye + look_dir, 1.2, Color(0.25, 0.52, 0.88))
	# Limbal ring
	draw_arc(l_eye + look_dir, 2.1, 0, TAU, 10, Color(0.10, 0.25, 0.55, 0.3), 0.4)
	draw_arc(r_eye + look_dir, 2.1, 0, TAU, 10, Color(0.10, 0.25, 0.55, 0.3), 0.4)
	# Iris radial detail
	for iri in range(8):
		var ir_a = TAU * float(iri) / 8.0
		var ir_v = Vector2.from_angle(ir_a)
		draw_line(l_eye + look_dir + ir_v * 0.4, l_eye + look_dir + ir_v * 1.3, Color(0.15, 0.35, 0.70, 0.2), 0.3)
		draw_line(r_eye + look_dir + ir_v * 0.4, r_eye + look_dir + ir_v * 1.3, Color(0.15, 0.35, 0.70, 0.2), 0.3)
	# Pupils
	draw_circle(l_eye + look_dir * 1.1, 1.0, Color(0.05, 0.05, 0.08))
	draw_circle(r_eye + look_dir * 1.1, 1.0, Color(0.05, 0.05, 0.08))
	# Primary highlight (sparkle of wisdom)
	draw_circle(l_eye + Vector2(-0.8, -1.0), 1.1, Color(1.0, 1.0, 1.0, 0.9))
	draw_circle(r_eye + Vector2(-0.8, -1.0), 1.1, Color(1.0, 1.0, 1.0, 0.9))
	# Secondary highlight
	draw_circle(l_eye + Vector2(1.0, 0.3), 0.6, Color(1.0, 1.0, 1.0, 0.5))
	draw_circle(r_eye + Vector2(1.0, 0.3), 0.6, Color(1.0, 1.0, 1.0, 0.5))
	# Blue magic glint
	var glint_t = sin(_time * 1.8) * 0.15
	draw_circle(l_eye + Vector2(0.3, -0.3), 0.35, Color(0.3, 0.5, 1.0, 0.25 + glint_t))
	draw_circle(r_eye + Vector2(0.3, -0.3), 0.35, Color(0.3, 0.5, 1.0, 0.25 + glint_t))
	# Upper eyelids (slightly drooping — aged but alert)
	draw_arc(l_eye, 3.4, PI + 0.2, TAU - 0.2, 8, Color(0.68, 0.52, 0.42), 1.2)
	draw_arc(r_eye, 3.4, PI + 0.2, TAU - 0.2, 8, Color(0.68, 0.52, 0.42), 1.2)
	# Lower eyelid
	draw_arc(l_eye, 3.2, 0.3, PI - 0.3, 8, Color(0.58, 0.44, 0.34, 0.2), 0.5)
	draw_arc(r_eye, 3.2, 0.3, PI - 0.3, 8, Color(0.58, 0.44, 0.34, 0.2), 0.5)

	# Bushy eyebrows (thick, white/silver, expressive)
	# Left brow (raised slightly — wise look)
	draw_line(l_eye + Vector2(-3.5, -3.8), l_eye + Vector2(0, -4.5), Color(0.82, 0.82, 0.86), 2.2)
	draw_line(l_eye + Vector2(0, -4.5), l_eye + Vector2(3.0, -3.5), Color(0.82, 0.82, 0.86), 1.8)
	# Brow hair wisps
	for bwi in range(4):
		var bwt = float(bwi) / 3.0
		var bw_pos = (l_eye + Vector2(-3.0, -3.8)).lerp(l_eye + Vector2(2.5, -3.8), bwt)
		draw_line(bw_pos, bw_pos + Vector2(sin(float(bwi) * 1.5) * 1.0, -1.5), Color(0.85, 0.85, 0.90, 0.5), 0.7)
	# Right brow
	draw_line(r_eye + Vector2(-3.0, -3.5), r_eye + Vector2(0, -4.2), Color(0.82, 0.82, 0.86), 2.2)
	draw_line(r_eye + Vector2(0, -4.2), r_eye + Vector2(3.5, -3.5), Color(0.82, 0.82, 0.86), 1.8)
	for bwi in range(4):
		var bwt = float(bwi) / 3.0
		var bw_pos = (r_eye + Vector2(-2.5, -3.5)).lerp(r_eye + Vector2(3.0, -3.5), bwt)
		draw_line(bw_pos, bw_pos + Vector2(-sin(float(bwi) * 1.5) * 1.0, -1.5), Color(0.85, 0.85, 0.90, 0.5), 0.7)

	# Nose (prominent, aged but noble)
	draw_circle(head_center + Vector2(0, 2.5), 1.8, skin_highlight)
	draw_circle(head_center + Vector2(0.2, 2.7), 1.3, Color(0.90, 0.76, 0.64))
	# Nose bridge
	draw_line(head_center + Vector2(0, -0.5), head_center + Vector2(0, 2.2), Color(0.92, 0.80, 0.68, 0.3), 0.7)
	# Nostrils
	draw_circle(head_center + Vector2(-0.8, 3.0), 0.5, Color(0.55, 0.42, 0.34, 0.35))
	draw_circle(head_center + Vector2(0.8, 3.0), 0.5, Color(0.55, 0.42, 0.34, 0.35))

	# Gentle wise smile (warm, kind)
	draw_arc(head_center + Vector2(0, 4.5), 3.5, 0.2, PI - 0.2, 10, Color(0.60, 0.35, 0.28), 1.3)
	# Upper lip
	draw_arc(head_center + Vector2(0, 4.2), 2.8, PI + 0.4, TAU - 0.4, 8, Color(0.65, 0.40, 0.32, 0.3), 0.6)
	# Smile lines at corners
	draw_arc(head_center + Vector2(-3.5, 3.8), 1.5, PI * 0.3, PI * 0.7, 4, Color(0.65, 0.48, 0.38, 0.2), 0.5)
	draw_arc(head_center + Vector2(3.5, 3.8), 1.5, PI * 0.3, PI * 0.7, 4, Color(0.65, 0.48, 0.38, 0.2), 0.5)

	# Hair wisps on sides (white, long, flowing from under hat)
	for hsi in range(4):
		var hs_side = -1.0 if hsi < 2 else 1.0
		var hs_idx = hsi % 2
		var hs_base = head_center + Vector2(hs_side * 8.0, -2.0 + float(hs_idx) * 3.0)
		var hs_wave = sin(_time * 1.5 + float(hsi) * 1.2) * 1.5
		var hs_tip = hs_base + Vector2(hs_side * (3.0 + float(hs_idx) * 2.0) + hs_wave, 10.0 + float(hs_idx) * 5.0)
		draw_line(hs_base, hs_tip, hair_col, 1.3)
		draw_line(hs_base, hs_tip.lerp(hs_base, 0.5), Color(1.0, 1.0, 1.0, 0.15), 0.6)

	# === WIZARD HAT (tall, pointed, blue-purple with silver stars) ===
	var hat_base_y = head_center + Vector2(0, -7)
	var hat_tip_pos = hat_base_y + Vector2(sin(_time * 0.8) * 3.0, -32)  # Slightly tilted, sways
	# Hat shape (tall cone)
	var hat_pts = PackedVector2Array([
		hat_base_y + Vector2(-11, 2),   # brim left
	])
	# Curved brim
	for hbi in range(6):
		var ht = float(hbi) / 5.0
		var brim_pos = hat_base_y + Vector2(-11 + ht * 22.0, 2.0 + sin(ht * PI) * 2.0)
		hat_pts.append(brim_pos)
	hat_pts.append(hat_tip_pos)
	draw_colored_polygon(hat_pts, Color(0.20, 0.14, 0.48))

	# Hat depth shading (darker left side)
	var hat_shade_pts = PackedVector2Array([
		hat_base_y + Vector2(-9, 1),
		hat_base_y + Vector2(2, 1),
		hat_tip_pos + Vector2(-2, 2),
	])
	draw_colored_polygon(hat_shade_pts, Color(0.15, 0.10, 0.38, 0.4))
	# Hat highlight (right side)
	var hat_hl_pts = PackedVector2Array([
		hat_base_y + Vector2(2, 1),
		hat_base_y + Vector2(11, 1),
		hat_tip_pos + Vector2(1, -1),
	])
	draw_colored_polygon(hat_hl_pts, Color(0.28, 0.20, 0.56, 0.2))

	# Hat brim
	draw_line(hat_base_y + Vector2(-12, 2), hat_base_y + Vector2(12, 2), Color(0.16, 0.10, 0.38), 3.5)
	draw_line(hat_base_y + Vector2(-12, 2.5), hat_base_y + Vector2(12, 2.5), Color(0.24, 0.18, 0.50), 2.0)
	# Hat band (gold trim)
	draw_line(hat_base_y + Vector2(-11, 0), hat_base_y + Vector2(11, 0), Color(0.70, 0.58, 0.22), 2.5)
	draw_line(hat_base_y + Vector2(-10, -0.5), hat_base_y + Vector2(10, -0.5), Color(0.82, 0.70, 0.32, 0.4), 1.2)

	# Silver stars embroidered on hat
	for sti in range(5):
		var st_t = 0.15 + float(sti) * 0.15
		var st_pos = hat_base_y.lerp(hat_tip_pos, st_t)
		var st_x_off = sin(float(sti) * 2.3) * 4.0
		st_pos.x += st_x_off
		var st_alpha = 0.35 + sin(_time * 1.8 + float(sti) * 1.5) * 0.12
		var st_size = 1.5 + sin(_time * 1.2 + float(sti)) * 0.3
		if sti % 2 == 0:
			# Star
			draw_line(st_pos + Vector2(-st_size, 0), st_pos + Vector2(st_size, 0), Color(0.72, 0.75, 0.90, st_alpha), 0.7)
			draw_line(st_pos + Vector2(0, -st_size), st_pos + Vector2(0, st_size), Color(0.72, 0.75, 0.90, st_alpha), 0.7)
			var ds = st_size * 0.65
			draw_line(st_pos + Vector2(-ds, -ds), st_pos + Vector2(ds, ds), Color(0.78, 0.80, 0.95, st_alpha * 0.6), 0.5)
			draw_line(st_pos + Vector2(ds, -ds), st_pos + Vector2(-ds, ds), Color(0.78, 0.80, 0.95, st_alpha * 0.6), 0.5)
		else:
			# Moon crescent
			draw_arc(st_pos, 1.5, PI * 0.3, PI * 1.7, 6, Color(0.72, 0.75, 0.90, st_alpha), 0.6)
			draw_circle(st_pos + Vector2(0.4, -0.3), 1.0, Color(0.20, 0.14, 0.48, st_alpha))

	# Hat fold crease
	draw_line(hat_base_y + Vector2(1, 0), hat_tip_pos + Vector2(-1, 2), Color(0.14, 0.10, 0.36, 0.35), 0.7)
	# Hat outline
	draw_line(hat_base_y + Vector2(-11, 2), hat_tip_pos, Color(0.12, 0.08, 0.32, 0.4), 0.8)
	draw_line(hat_base_y + Vector2(11, 2), hat_tip_pos, Color(0.12, 0.08, 0.32, 0.4), 0.8)
	# Hat tip (droops slightly to side)
	draw_circle(hat_tip_pos, 2.0, Color(0.22, 0.16, 0.50))
	draw_circle(hat_tip_pos, 1.2, Color(0.28, 0.22, 0.56))
	# Tiny star at tip
	draw_circle(hat_tip_pos, 0.8, Color(0.8, 0.8, 1.0, 0.4 + sin(_time * 3.0) * 0.2))

	# === Tier 4: Cosmic aura around whole character ===
	if upgrade_tier >= 4:
		var aura_pulse = sin(_time * 2.0) * 5.0
		draw_circle(body_offset, 60.0 + aura_pulse, Color(0.3, 0.2, 0.7, 0.04))
		draw_circle(body_offset, 50.0 + aura_pulse * 0.6, Color(0.4, 0.3, 0.85, 0.06))
		draw_circle(body_offset, 42.0 + aura_pulse * 0.3, Color(0.6, 0.5, 1.0, 0.06))
		draw_arc(body_offset, 56.0 + aura_pulse, 0, TAU, 32, Color(0.4, 0.3, 0.9, 0.12), 2.5)
		draw_arc(body_offset, 46.0 + aura_pulse * 0.5, 0, TAU, 24, Color(0.6, 0.5, 1.0, 0.08), 1.8)
		# Orbiting cosmic sparkles
		for gs in range(6):
			var gs_a = _time * (0.6 + float(gs % 3) * 0.2) + float(gs) * TAU / 6.0
			var gs_r = 46.0 + aura_pulse + float(gs % 3) * 3.0
			var gs_p = body_offset + Vector2.from_angle(gs_a) * gs_r
			var gs_size = 1.2 + sin(_time * 2.5 + float(gs) * 1.5) * 0.5
			var gs_alpha = 0.25 + sin(_time * 2.5 + float(gs)) * 0.15
			draw_circle(gs_p, gs_size, Color(0.5, 0.4, 1.0, gs_alpha))

	# === 15. AWAITING ABILITY CHOICE INDICATOR ===
	if awaiting_ability_choice:
		var pulse = (sin(_time * 4.0) + 1.0) * 0.5
		draw_circle(Vector2.ZERO, 68.0 + pulse * 6.0, Color(0.3, 0.2, 0.7, 0.1 + pulse * 0.1))
		draw_arc(Vector2.ZERO, 68.0 + pulse * 6.0, 0, TAU, 32, Color(0.4, 0.3, 0.9, 0.3 + pulse * 0.3), 2.5)
		var font3 = ThemeDB.fallback_font
		draw_string(font3, Vector2(-16, -80), "!", HORIZONTAL_ALIGNMENT_CENTER, 32, 30, Color(0.4, 0.3, 0.9, 0.7 + pulse * 0.3))

	# === 16. DAMAGE COUNTER ===
	if damage_dealt > 0:
		var font = ThemeDB.fallback_font
		var dmg_text = str(int(damage_dealt)) + " DMG"
		if stat_upgrade_level > 0:
			dmg_text += " * Lv." + str(stat_upgrade_level)
		draw_string(font, Vector2(-36, 56), dmg_text, HORIZONTAL_ALIGNMENT_LEFT, 160, 12, Color(0.5, 0.4, 1.0, 0.5))

	# === 17. UPGRADE NAME FLASH ===
	if _upgrade_flash > 0.0 and _upgrade_name != "":
		var font2 = ThemeDB.fallback_font
		draw_string(font2, Vector2(-80, -72), _upgrade_name, HORIZONTAL_ALIGNMENT_CENTER, 160, 16, Color(0.4, 0.3, 0.9, min(_upgrade_flash, 1.0)))

# === SYNERGY BUFFS ===
var _synergy_buffs: Dictionary = {}

func set_synergy_buff(buffs: Dictionary) -> void:
	for key in buffs:
		_synergy_buffs[key] = _synergy_buffs.get(key, 0.0) + buffs[key]

func clear_synergy_buff() -> void:
	_synergy_buffs.clear()

func has_synergy_buff() -> bool:
	return not _synergy_buffs.is_empty()

var power_damage_mult: float = 1.0

func _damage_mult() -> float:
	return (1.0 + _synergy_buffs.get("damage", 0.0)) * power_damage_mult

func _range_mult() -> float:
	return 1.0 + _synergy_buffs.get("range", 0.0)

func _speed_mult() -> float:
	return 1.0 + _synergy_buffs.get("attack_speed", 0.0)

func _gold_mult() -> float:
	return 1.0 + _synergy_buffs.get("gold_bonus", 0.0)
