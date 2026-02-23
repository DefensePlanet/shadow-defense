extends Node2D
## Robin Hood — long-range archer tower. Upgrades by dealing damage ("Rob the Rich").
## Tier 1 (5000 DMG): Splitting the Wand — arrows pierce to a 2nd enemy
## Tier 2 (10000 DMG): The Silver Arrow — every 5th shot deals 3x damage
## Tier 3 (15000 DMG): Three Blasts of the Horn — volley of 5 arrows every 18s
## Tier 4 (20000 DMG): The Final Arrow — splash damage, doubled gold, double pierce

# Base stats
var damage: float = 25.0
var fire_rate: float = 2.0
var attack_range: float = 200.0
var fire_cooldown: float = 0.0
var bow_angle: float = 0.0
var target: Node2D = null
var _draw_progress: float = 0.0
var gold_bonus: int = 2

# Animation timers
var _time: float = 0.0
var _attack_anim: float = 0.0

# Damage tracking and upgrades
var damage_dealt: float = 0.0
var upgrade_tier: int = 0
var _upgrade_flash: float = 0.0
var _upgrade_name: String = ""

# Tier 1: Splitting the Wand — pierce
var pierce_count: int = 0

# Tier 2: The Silver Arrow — every Nth shot is silver (3x damage)
var shot_count: int = 0
var silver_interval: int = 5

# Tier 3: Three Blasts of the Horn — periodic volley
var horn_timer: float = 0.0
var horn_cooldown: float = 18.0
var _horn_flash: float = 0.0

# Tier 4: The Final Arrow — splash
var splash_radius: float = 0.0

# Kill tracking — steal coins every 10th kill
var kill_count: int = 0

# === PROGRESSIVE ABILITIES (9 tiers, unlocked via lifetime damage) ===
const PROG_ABILITY_NAMES = [
	"Sherwood Aim", "Lincoln Green", "Merry Men", "Friar Tuck's Blessing",
	"Little John's Staff", "The Outlaw's Snare", "Maid Marian's Arrow",
	"The Golden Arrow", "King of Sherwood"
]
const PROG_ABILITY_DESCS = [
	"Arrows fly 30% faster, +15% damage",
	"Invisible 2s every 10s; arrows during deal 2x",
	"Every 20s, 3 hooded figures strike enemies for 3x",
	"Restores 1 life every 30s",
	"Every 12s, AoE stun all in range for 1.5s",
	"Every 15s, rope trap roots next enemy 3s",
	"Every 18s, heal 1 life + strike strongest for 5x",
	"Every 20s, golden arrow pierces ALL in line for 10x",
	"Every 8s, arrows rain on EVERY enemy on map"
]
var prog_abilities: Array = [false, false, false, false, false, false, false, false, false]
# Ability timers
var _lincoln_green_timer: float = 10.0
var _lincoln_green_invis: float = 0.0
var _merry_men_timer: float = 20.0
var _friar_tuck_timer: float = 30.0
var _little_john_timer: float = 12.0
var _outlaw_snare_timer: float = 15.0
var _maid_marian_timer: float = 18.0
var _golden_arrow_timer: float = 20.0
var _king_sherwood_timer: float = 8.0
# Visual flash timers
var _merry_men_flash: float = 0.0
var _little_john_flash: float = 0.0
var _golden_arrow_flash: float = 0.0
var _king_sherwood_flash: float = 0.0

const STAT_UPGRADE_INTERVAL: float = 500.0
const ABILITY_THRESHOLD: float = 1500.0
var stat_upgrade_level: int = 0
var ability_chosen: bool = false
var awaiting_ability_choice: bool = false
const TIER_NAMES = [
	"Splitting the Wand",
	"The Silver Arrow",
	"Three Blasts of the Horn",
	"The Final Arrow"
]
const ABILITY_DESCRIPTIONS = [
	"Arrows pierce to a 2nd enemy",
	"Every 5th shot deals 3x damage",
	"Volley of 5 arrows every 18s",
	"Splash damage, double gold, double pierce"
]
const TIER_COSTS = [80, 175, 300, 500]
var is_selected: bool = false
var base_cost: int = 0

var arrow_scene = preload("res://scenes/arrow.tscn")

# Attack sounds — arrow sounds evolving with upgrade tier
var _attack_sounds: Array = []
var _attack_sounds_by_tier: Array = []
var _attack_player: AudioStreamPlayer

# Ability sounds
var _horn_sound: AudioStreamWAV
var _horn_player: AudioStreamPlayer
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

	# Horn volley — 3 ascending brass blasts (A3→C#4→E4)
	var horn_rate := 22050
	var horn_dur := 0.6
	var horn_samples := PackedFloat32Array()
	horn_samples.resize(int(horn_rate * horn_dur))
	var horn_notes := [220.0, 277.18, 329.63]  # A3, C#4, E4
	var horn_note_len := int(horn_rate * horn_dur) / 3
	for i in horn_samples.size():
		var t := float(i) / horn_rate
		var ni := mini(i / horn_note_len, 2)
		var nt := float(i - ni * horn_note_len) / float(horn_rate)
		var freq: float = horn_notes[ni]
		var att := minf(nt * 30.0, 1.0)
		var dec := exp(-nt * 8.0)
		var env := att * dec * 0.45
		var s := sin(TAU * freq * t) + sin(TAU * freq * 2.0 * t) * 0.4 + sin(TAU * freq * 3.0 * t) * 0.15
		horn_samples[i] = clampf(s * env, -1.0, 1.0)
	_horn_sound = _samples_to_wav(horn_samples, horn_rate)
	_horn_player = AudioStreamPlayer.new()
	_horn_player.stream = _horn_sound
	_horn_player.volume_db = -6.0
	add_child(_horn_player)

	# Upgrade chime — bright ascending arpeggio (C5→E5→G5)
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
	_horn_flash = max(_horn_flash - delta * 2.0, 0.0)
	_attack_anim = max(_attack_anim - delta * 3.0, 0.0)
	target = _find_nearest_enemy()

	if target:
		var desired = global_position.angle_to_point(target.global_position) + PI
		bow_angle = lerp_angle(bow_angle, desired, 10.0 * delta)
		_draw_progress = min(_draw_progress + delta * 3.0, 1.0)
		if fire_cooldown <= 0.0:
			_shoot()
			fire_cooldown = 1.0 / (fire_rate * _speed_mult())
			_draw_progress = 0.0
			_attack_anim = 1.0
	else:
		_draw_progress = max(_draw_progress - delta * 2.0, 0.0)

	# Tier 3+: Horn volley
	if upgrade_tier >= 3:
		horn_timer -= delta
		if horn_timer <= 0.0 and _has_enemies_in_range():
			_horn_volley()
			horn_timer = horn_cooldown

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

func _shoot() -> void:
	if not target:
		return
	if _attack_player and _attack_sounds.size() > 0 and not _is_sfx_muted():
		_attack_player.stream = _attack_sounds[_get_note_index() % _attack_sounds.size()]
		_attack_player.play()
	shot_count += 1
	var silver = upgrade_tier >= 2 and shot_count % silver_interval == 0
	_fire_arrow(target, silver)

func _fire_arrow(t: Node2D, silver: bool = false) -> void:
	var arrow = arrow_scene.instantiate()
	arrow.global_position = global_position + Vector2.from_angle(bow_angle) * 18.0
	var dmg_mult = 3.0 if silver else 1.0
	# Ability 1: Sherwood Aim — +15% damage
	if prog_abilities[0]:
		dmg_mult *= 1.15
	# Ability 2: Lincoln Green — 2x during invisibility
	if prog_abilities[1] and _lincoln_green_invis > 0.0:
		dmg_mult *= 2.0
	arrow.damage = damage * dmg_mult * _damage_mult()
	arrow.target = t
	arrow.gold_bonus = int(gold_bonus * _gold_mult())
	arrow.source_tower = self
	arrow.pierce_count = pierce_count
	arrow.is_silver = silver
	arrow.splash_radius = splash_radius
	# Ability 1: Sherwood Aim — 30% faster arrows
	if prog_abilities[0]:
		arrow.speed *= 1.3
	get_tree().get_first_node_in_group("main").add_child(arrow)

func _horn_volley() -> void:
	if _horn_player and not _is_sfx_muted(): _horn_player.play()
	_horn_flash = 1.0
	var enemies = get_tree().get_nodes_in_group("enemies")
	var in_range: Array = []
	for enemy in enemies:
		if global_position.distance_to(enemy.global_position) < attack_range:
			in_range.append(enemy)
	in_range.shuffle()
	var count = mini(5, in_range.size())
	for i in range(count):
		_fire_arrow(in_range[i], false)

func register_kill() -> void:
	kill_count += 1
	if kill_count % 10 == 0:
		var stolen = 5 + kill_count / 10
		var main = get_tree().get_first_node_in_group("main")
		if main:
			main.add_gold(stolen)
		_upgrade_flash = 1.0
		_upgrade_name = "Robbed %d gold!" % stolen

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
		1: # Splitting the Wand — arrows pierce one extra enemy
			pierce_count = 1
			damage = 33.0
			fire_rate = 2.5
			attack_range = 220.0
		2: # The Silver Arrow — every 5th shot triple damage
			damage = 43.0
			fire_rate = 3.0
			attack_range = 240.0
			gold_bonus = 3
		3: # Three Blasts of the Horn — volley + range boost
			damage = 50.0
			fire_rate = 3.5
			attack_range = 270.0
			horn_cooldown = 14.0
			gold_bonus = 4
		4: # The Final Arrow — splash, double pierce, double gold
			damage = 65.0
			fire_rate = 4.0
			attack_range = 300.0
			gold_bonus = 6
			splash_radius = 80.0
			pierce_count = 3
			horn_cooldown = 10.0

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
	return "Robin Hood"

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
	# Bowstring twang frequencies — plucked string fundamentals
	var string_notes := [293.66, 349.23, 392.00, 440.00, 392.00, 349.23, 293.66, 440.00]  # D4, F4, G4, A4, G4, F4, D4, A4 (D minor heroic melody)
	var mix_rate := 44100
	_attack_sounds_by_tier = []

	# --- Tier 0: Simple Bowstring Twang (plucked string + soft thwack) ---
	var t0 := []
	for note_idx in string_notes.size():
		var freq: float = string_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.12))
		for i in samples.size():
			var t := float(i) / mix_rate
			# Plucked bowstring — fast decay, odd harmonics
			var env := exp(-t * 30.0) * 0.35
			var fund := sin(t * freq * TAU)
			var h3 := sin(t * freq * 3.0 * TAU) * 0.2 * exp(-t * 45.0)
			var h5 := sin(t * freq * 5.0 * TAU) * 0.08 * exp(-t * 60.0)
			# Soft release thwack (very brief)
			var thwack := (randf() * 2.0 - 1.0) * exp(-t * 600.0) * 0.2
			samples[i] = clampf((fund + h3 + h5) * env + thwack, -1.0, 1.0)
		t0.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t0)

	# --- Tier 1: Longbow Twang (deeper resonance, slight string buzz) ---
	var t1 := []
	for note_idx in string_notes.size():
		var freq: float = string_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.15))
		for i in samples.size():
			var t := float(i) / mix_rate
			var env := exp(-t * 22.0) * 0.35
			var fund := sin(t * freq * TAU)
			var h2 := sin(t * freq * 2.0 * TAU) * 0.15 * exp(-t * 30.0)
			var h3 := sin(t * freq * 3.0 * TAU) * 0.12 * exp(-t * 40.0)
			# String buzz — slight detuned double
			var buzz := sin(t * freq * 1.01 * TAU) * 0.15 * exp(-t * 25.0)
			var thwack := (randf() * 2.0 - 1.0) * exp(-t * 500.0) * 0.18
			samples[i] = clampf((fund + h2 + h3 + buzz) * env + thwack, -1.0, 1.0)
		t1.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t1)

	# --- Tier 2: Heavy Bow (weighty thump, low string resonance) ---
	var t2 := []
	for note_idx in string_notes.size():
		var freq: float = string_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.16))
		for i in samples.size():
			var t := float(i) / mix_rate
			# Meaty low-end twang
			var env := exp(-t * 20.0) * 0.35
			var fund := sin(t * freq * TAU)
			var h2 := sin(t * freq * 2.0 * TAU) * 0.2 * exp(-t * 28.0)
			var h3 := sin(t * freq * 3.0 * TAU) * 0.1 * exp(-t * 35.0)
			# Wood thump from bow body
			var thump := sin(t * 80.0 * TAU) * exp(-t * 100.0) * 0.2
			var click := (randf() * 2.0 - 1.0) * exp(-t * 700.0) * 0.15
			samples[i] = clampf((fund + h2 + h3) * env + thump + click, -1.0, 1.0)
		t2.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t2)

	# --- Tier 3: Rapid Volley (staggered twangs, 2 quick shots) ---
	var t3 := []
	for note_idx in string_notes.size():
		var freq: float = string_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.18))
		for i in samples.size():
			var t := float(i) / mix_rate
			# First twang
			var env1 := exp(-t * 35.0) * 0.3
			var s1 := sin(t * freq * TAU) * env1
			s1 += sin(t * freq * 3.0 * TAU) * 0.15 * exp(-t * 50.0) * env1
			# Second twang (slightly higher, delayed)
			var dt := t - 0.035
			var s2 := 0.0
			if dt > 0.0:
				var env2 := exp(-dt * 40.0) * 0.25
				s2 = sin(dt * freq * 1.12 * TAU) * env2
				s2 += sin(dt * freq * 3.36 * TAU) * 0.12 * exp(-dt * 55.0) * env2
			var click := (randf() * 2.0 - 1.0) * exp(-t * 600.0) * 0.15
			samples[i] = clampf(s1 + s2 + click, -1.0, 1.0)
		t3.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t3)

	# --- Tier 4: Legendary Bow (rich harmonics + brief heroic ring) ---
	var t4 := []
	for note_idx in string_notes.size():
		var freq: float = string_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.2))
		for i in samples.size():
			var t := float(i) / mix_rate
			# Powerful pluck with rich harmonics
			var env := exp(-t * 18.0) * 0.3
			var fund := sin(t * freq * TAU)
			var h2 := sin(t * freq * 2.0 * TAU) * 0.2
			var h3 := sin(t * freq * 3.0 * TAU) * 0.12 * exp(-t * 25.0)
			var h4 := sin(t * freq * 4.0 * TAU) * 0.06 * exp(-t * 30.0)
			# Brief heroic shimmer (detuned chorus, subtle)
			var shim := sin(t * freq * 2.005 * TAU) * 0.08 * exp(-t * 12.0)
			shim += sin(t * freq * 1.995 * TAU) * 0.08 * exp(-t * 12.0)
			var snap := (randf() * 2.0 - 1.0) * exp(-t * 500.0) * 0.15
			samples[i] = clampf((fund + h2 + h3 + h4) * env + shim * env + snap, -1.0, 1.0)
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
	if main and main.survivor_progress.has(main.TowerType.ROBIN_HOOD):
		var p = main.survivor_progress[main.TowerType.ROBIN_HOOD]
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
	if prog_abilities[0]:  # Sherwood Aim: +15% damage (applied as base multiplier)
		pass  # Applied in _fire_arrow via speed boost and register_damage

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
		main.register_tower_damage(main.TowerType.ROBIN_HOOD, amount)

func _process_progressive_abilities(delta: float) -> void:
	# Visual flash decay
	_merry_men_flash = max(_merry_men_flash - delta * 2.0, 0.0)
	_little_john_flash = max(_little_john_flash - delta * 2.0, 0.0)
	_golden_arrow_flash = max(_golden_arrow_flash - delta * 1.5, 0.0)
	_king_sherwood_flash = max(_king_sherwood_flash - delta * 2.0, 0.0)

	# Ability 2: Lincoln Green — invisibility cycle
	if prog_abilities[1]:
		if _lincoln_green_invis > 0.0:
			_lincoln_green_invis -= delta
		else:
			_lincoln_green_timer -= delta
			if _lincoln_green_timer <= 0.0:
				_lincoln_green_invis = 2.0
				_lincoln_green_timer = 10.0

	# Ability 3: Merry Men — periodic path strike
	if prog_abilities[2]:
		_merry_men_timer -= delta
		if _merry_men_timer <= 0.0 and _has_enemies_in_range():
			_merry_men_attack()
			_merry_men_timer = 20.0

	# Ability 4: Friar Tuck's Blessing — restore life
	if prog_abilities[3]:
		_friar_tuck_timer -= delta
		if _friar_tuck_timer <= 0.0:
			var main = get_tree().get_first_node_in_group("main")
			if main and main.has_method("restore_life"):
				main.restore_life(1)
			_friar_tuck_timer = 30.0

	# Ability 5: Little John's Staff — AoE stun
	if prog_abilities[4]:
		_little_john_timer -= delta
		if _little_john_timer <= 0.0 and _has_enemies_in_range():
			_little_john_stun()
			_little_john_timer = 12.0

	# Ability 6: The Outlaw's Snare — root trap
	if prog_abilities[5]:
		_outlaw_snare_timer -= delta
		if _outlaw_snare_timer <= 0.0 and _has_enemies_in_range():
			_outlaw_snare()
			_outlaw_snare_timer = 15.0

	# Ability 7: Maid Marian's Arrow — heal + strike strongest
	if prog_abilities[6]:
		_maid_marian_timer -= delta
		if _maid_marian_timer <= 0.0:
			_maid_marian_strike()
			_maid_marian_timer = 18.0

	# Ability 8: The Golden Arrow — pierce all in line
	if prog_abilities[7]:
		_golden_arrow_timer -= delta
		if _golden_arrow_timer <= 0.0 and _has_enemies_in_range():
			_golden_arrow_strike()
			_golden_arrow_timer = 20.0

	# Ability 9: King of Sherwood — rain arrows on all enemies
	if prog_abilities[8]:
		_king_sherwood_timer -= delta
		if _king_sherwood_timer <= 0.0:
			_king_sherwood_rain()
			_king_sherwood_timer = 8.0

func _merry_men_attack() -> void:
	_merry_men_flash = 1.0
	var enemies = get_tree().get_nodes_in_group("enemies")
	var in_range: Array = []
	for e in enemies:
		if global_position.distance_to(e.global_position) < attack_range:
			in_range.append(e)
	in_range.shuffle()
	for i in range(mini(3, in_range.size())):
		if is_instance_valid(in_range[i]) and in_range[i].has_method("take_damage"):
			var dmg = damage * 3.0
			in_range[i].take_damage(dmg)
			register_damage(dmg)

func _little_john_stun() -> void:
	_little_john_flash = 1.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) < attack_range:
			if e.has_method("apply_sleep"):
				e.apply_sleep(1.5)

func _outlaw_snare() -> void:
	# Root nearest enemy for 3s
	var nearest = _find_nearest_enemy()
	if nearest and nearest.has_method("apply_slow"):
		nearest.apply_slow(0.0, 3.0)  # factor 0 = complete stop

func _maid_marian_strike() -> void:
	# Heal 1 life
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("restore_life"):
		main.restore_life(1)
	# Strike strongest enemy in range
	var strongest: Node2D = null
	var most_hp: float = 0.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) < attack_range:
			if e.health > most_hp:
				most_hp = e.health
				strongest = e
	if strongest and strongest.has_method("take_damage"):
		var dmg = damage * 5.0
		strongest.take_damage(dmg)
		register_damage(dmg)

func _golden_arrow_strike() -> void:
	_golden_arrow_flash = 1.0
	# Pierce ALL enemies in a line from tower toward target direction
	var dir = Vector2.from_angle(bow_angle)
	for e in get_tree().get_nodes_in_group("enemies"):
		# Check if enemy is roughly in the line (within 40px perpendicular distance)
		var to_enemy = e.global_position - global_position
		var proj = to_enemy.dot(dir)
		if proj > 0:  # In front of tower
			var perp_dist = abs(to_enemy.cross(dir))
			if perp_dist < 40.0:
				if e.has_method("take_damage"):
					var dmg = damage * 10.0
					e.take_damage(dmg)
					register_damage(dmg)

func _king_sherwood_rain() -> void:
	_king_sherwood_flash = 1.0
	# Deal 1.5x damage to EVERY enemy on map
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("take_damage"):
			var dmg = damage * 1.5
			e.take_damage(dmg)
			register_damage(dmg)

func _draw() -> void:
	# === 1. SELECTION RING ===
	if is_selected:
		var pulse = (sin(_time * 3.0) + 1.0) * 0.5
		var ring_alpha = 0.5 + pulse * 0.3
		draw_arc(Vector2.ZERO, 40.0, 0, TAU, 48, Color(1.0, 0.84, 0.0, ring_alpha), 2.5)
		draw_arc(Vector2.ZERO, 43.0, 0, TAU, 48, Color(1.0, 0.84, 0.0, ring_alpha * 0.4), 1.5)

	# === 2. RANGE ARC ===
	draw_arc(Vector2.ZERO, attack_range, 0, TAU, 64, Color(1, 1, 1, 0.06), 1.0)

	# === 3. AIM DIRECTION ===
	var dir = Vector2.from_angle(bow_angle)
	var perp = dir.rotated(PI / 2.0)

	# === 4. IDLE ANIMATION (confident weight shift) ===
	var bounce = abs(sin(_time * 3.0)) * 4.0
	var breathe = sin(_time * 2.0) * 2.0
	var weight_shift = sin(_time * 1.2) * 2.5  # Slow confident weight shift
	var bob = Vector2(weight_shift, -bounce - breathe)

	# Tier 4: Floating pose (legendary archer levitating)
	var fly_offset = Vector2.ZERO
	if upgrade_tier >= 4:
		fly_offset = Vector2(0, -10.0 + sin(_time * 1.5) * 3.0)

	var body_offset = bob + fly_offset

	# Per-joint differential offsets
	var hip_shift = sin(_time * 1.2) * 1.5  # Weight shift at hips
	var shoulder_counter = -sin(_time * 1.2) * 0.8  # Counter-sway shoulders

	# String vibration after shot
	var string_vib = 0.0
	if _attack_anim > 0.3:
		string_vib = sin(_attack_anim * 40.0) * 2.0 * _attack_anim

	# === 5. SKIN COLORS ===
	var skin_base = Color(0.91, 0.74, 0.58)
	var skin_shadow = Color(0.78, 0.60, 0.45)
	var skin_highlight = Color(0.96, 0.82, 0.68)


	# === 7. UPGRADE FLASH ===
	if _upgrade_flash > 0.0:
		draw_circle(Vector2.ZERO, 80.0 + _upgrade_flash * 24.0, Color(0.3, 0.7, 0.2, _upgrade_flash * 0.25))

	# === 8. HORN FLASH (T3 ability) ===
	if _horn_flash > 0.0:
		var horn_ring_r = 36.0 + (1.0 - _horn_flash) * 70.0
		draw_circle(Vector2.ZERO, horn_ring_r, Color(1.0, 0.85, 0.3, _horn_flash * 0.15))
		draw_arc(Vector2.ZERO, horn_ring_r, 0, TAU, 32, Color(1.0, 0.9, 0.4, _horn_flash * 0.3), 2.5)
		# Inner ripple rings
		draw_arc(Vector2.ZERO, horn_ring_r * 0.7, 0, TAU, 24, Color(1.0, 0.85, 0.3, _horn_flash * 0.2), 2.0)
		draw_arc(Vector2.ZERO, horn_ring_r * 0.4, 0, TAU, 16, Color(1.0, 0.9, 0.5, _horn_flash * 0.15), 1.5)
		# Radiating golden sparkle bursts
		for hi in range(8):
			var ha = TAU * float(hi) / 8.0 + _horn_flash * 2.0
			var h_inner = Vector2.from_angle(ha) * (horn_ring_r * 0.5)
			var h_outer = Vector2.from_angle(ha) * (horn_ring_r + 5.0)
			draw_line(h_inner, h_outer, Color(1.0, 0.92, 0.4, _horn_flash * 0.4), 1.5)

	# === PROGRESSIVE ABILITY VISUAL EFFECTS ===
	# Ability 2: Lincoln Green — invisibility effect
	if prog_abilities[1] and _lincoln_green_invis > 0.0:
		draw_circle(Vector2.ZERO, 30.0, Color(0.2, 0.6, 0.15, 0.15))

	# Ability 3: Merry Men flash
	if _merry_men_flash > 0.0:
		for mi in range(3):
			var ma = TAU * float(mi) / 3.0 + _merry_men_flash * 3.0
			var mpos = Vector2.from_angle(ma) * 35.0
			draw_circle(mpos, 5.0, Color(0.2, 0.5, 0.15, _merry_men_flash * 0.5))
			draw_circle(mpos, 3.0, Color(0.3, 0.6, 0.2, _merry_men_flash * 0.7))

	# Ability 5: Little John's Staff flash
	if _little_john_flash > 0.0:
		var lj_r = 30.0 + (1.0 - _little_john_flash) * 50.0
		draw_arc(Vector2.ZERO, lj_r, 0, TAU, 24, Color(0.6, 0.4, 0.2, _little_john_flash * 0.4), 3.0)
		draw_arc(Vector2.ZERO, lj_r * 0.6, 0, TAU, 16, Color(0.5, 0.35, 0.15, _little_john_flash * 0.3), 2.0)

	# Ability 8: Golden Arrow flash
	if _golden_arrow_flash > 0.0:
		var ga_dir = Vector2.from_angle(bow_angle)
		draw_line(-ga_dir * 20.0, ga_dir * 200.0, Color(1.0, 0.85, 0.3, _golden_arrow_flash * 0.5), 4.0)
		draw_line(-ga_dir * 15.0, ga_dir * 180.0, Color(1.0, 0.95, 0.5, _golden_arrow_flash * 0.3), 2.0)

	# Ability 9: King of Sherwood flash — arrows from sky
	if _king_sherwood_flash > 0.0:
		for ri in range(8):
			var rx = -80.0 + float(ri) * 20.0
			var ry = -100.0 + (1.0 - _king_sherwood_flash) * 60.0
			draw_line(Vector2(rx, ry), Vector2(rx + 3, ry + 15), Color(0.3, 0.6, 0.15, _king_sherwood_flash * 0.5), 1.5)

	# === 9. STONE PLATFORM ===
	var plat_y = 22.0
	# Platform shadow
	draw_circle(Vector2(0, plat_y + 4), 28.0, Color(0, 0, 0, 0.15))
	# Stone platform ellipse (drawn as squished circles)
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

	# === 10. SHADOW TENDRILS ===
	for ti in range(5):
		var ta = TAU * float(ti) / 5.0 + _time * 0.3
		var t_base = Vector2(cos(ta) * 24.0, plat_y + sin(ta) * 8.0)
		var t_end = t_base + Vector2(sin(_time * 0.8 + float(ti)) * 6.0, 8.0 + sin(_time * 1.2 + float(ti)) * 4.0)
		draw_line(t_base, t_end, Color(0.04, 0.02, 0.06, 0.2), 2.0)
		draw_line(t_end, t_end + Vector2(sin(_time + float(ti)) * 3.0, 5.0), Color(0.04, 0.02, 0.06, 0.1), 1.5)

	# === 11. TIER PIPS (forest/silver/gold) ===
	for i in range(upgrade_tier):
		var pip_angle = -PI / 2.0 + float(i) * (TAU / 4.0) - (float(upgrade_tier - 1) * TAU / 8.0)
		var pip_pos = Vector2(cos(pip_angle) * 22.0, plat_y + sin(pip_angle) * 8.0)
		var pip_col: Color
		match i:
			0: pip_col = Color(0.2, 0.6, 0.15)   # forest green
			1: pip_col = Color(0.7, 0.75, 0.82)   # silver
			2: pip_col = Color(0.85, 0.72, 0.25)   # gold
			3: pip_col = Color(0.4, 0.85, 0.35)   # golden-green
		draw_circle(pip_pos, 4.0, pip_col)
		draw_circle(pip_pos, 5.5, Color(pip_col.r, pip_col.g, pip_col.b, 0.15))

	# === 12. CHARACTER POSITIONS (tall anime proportions ~56px) ===
	var feet_y = body_offset + Vector2(hip_shift * 1.0, 14.0)
	var leg_top = body_offset + Vector2(hip_shift * 0.6, -2.0)
	var torso_center = body_offset + Vector2(shoulder_counter * 0.5, -10.0)
	var neck_base = body_offset + Vector2(shoulder_counter * 0.7, -20.0)
	var head_center = body_offset + Vector2(shoulder_counter * 0.3, -32.0)

	# === 13. TIER-SPECIFIC EFFECTS (drawn BEFORE/AROUND body) ===

	# Tier 1+: Green leaf particles swirling around feet
	if upgrade_tier >= 1:
		for li in range(5 + upgrade_tier):
			var la = _time * (0.6 + fmod(float(li) * 1.37, 0.5)) + float(li) * TAU / float(5 + upgrade_tier)
			var lr = 22.0 + fmod(float(li) * 3.7, 15.0)
			var leaf_pos = body_offset + Vector2(cos(la) * lr, sin(la) * lr * 0.5 + 10.0)
			var leaf_alpha = 0.2 + sin(_time * 2.0 + float(li)) * 0.1
			var leaf_size = 1.5 + sin(_time * 1.5 + float(li) * 2.0) * 0.5
			# Leaf shape (tiny diamond)
			var leaf_rot = _time * 2.0 + float(li) * 1.5
			var ld = Vector2.from_angle(leaf_rot)
			var lp = ld.rotated(PI / 2.0)
			draw_line(leaf_pos - ld * leaf_size, leaf_pos + ld * leaf_size, Color(0.25, 0.6, 0.15, leaf_alpha), 1.2)
			draw_line(leaf_pos - lp * leaf_size * 0.5, leaf_pos + lp * leaf_size * 0.5, Color(0.3, 0.65, 0.2, leaf_alpha * 0.7), 0.8)

	# Tier 2+: Silver shimmer on bow area
	if upgrade_tier >= 2:
		var silver_pulse = (sin(_time * 2.8) + 1.0) * 0.5
		for spi in range(4):
			var sp_seed = float(spi) * 2.13
			var sp_a = _time * 1.2 + sp_seed
			var sp_r = 16.0 + sin(_time * 1.5 + sp_seed) * 4.0
			var sp_pos = body_offset + Vector2(12.0 + cos(sp_a) * sp_r, sin(sp_a) * sp_r * 0.4)
			var sp_alpha = 0.15 + silver_pulse * 0.12
			draw_circle(sp_pos, 1.2, Color(0.85, 0.88, 0.95, sp_alpha))

	# Tier 4: Fiery arrow particles floating around
	if upgrade_tier >= 4:
		for fd in range(8):
			var fd_seed = float(fd) * 2.37
			var fd_angle = _time * (0.5 + fmod(fd_seed, 0.5)) + fd_seed
			var fd_radius = 30.0 + fmod(fd_seed * 5.3, 25.0)
			var fd_pos = body_offset + Vector2(cos(fd_angle) * fd_radius, sin(fd_angle) * fd_radius * 0.6)
			var fd_alpha = 0.25 + sin(_time * 3.0 + fd_seed * 2.0) * 0.15
			var fd_size = 1.8 + sin(_time * 2.5 + fd_seed) * 0.6
			# Fire colors
			var fire_t = fmod(fd_seed * 1.7, 1.0)
			var fire_col = Color(1.0, 0.5 + fire_t * 0.4, 0.1, fd_alpha)
			draw_circle(fd_pos, fd_size, fire_col)
			draw_circle(fd_pos, fd_size * 0.5, Color(1.0, 0.9, 0.4, fd_alpha * 0.6))
			# Tiny sparkle cross
			draw_line(fd_pos - Vector2(fd_size, 0), fd_pos + Vector2(fd_size, 0), Color(1.0, 1.0, 0.8, fd_alpha * 0.3), 0.5)
			draw_line(fd_pos - Vector2(0, fd_size), fd_pos + Vector2(0, fd_size), Color(1.0, 1.0, 0.8, fd_alpha * 0.3), 0.5)

	# === 14. CHARACTER BODY (tall anime proportions) ===

	# --- Brown leather boots (practical, not curled) ---
	var l_foot = feet_y + Vector2(-7, 0)
	var r_foot = feet_y + Vector2(7, 0)
	# Boot base (dark brown leather)
	draw_circle(l_foot, 5.5, Color(0.30, 0.18, 0.08))
	draw_circle(l_foot, 4.2, Color(0.38, 0.24, 0.10))
	draw_circle(r_foot, 5.5, Color(0.30, 0.18, 0.08))
	draw_circle(r_foot, 4.2, Color(0.38, 0.24, 0.10))
	# Boot toe (rounded, practical — not curled like Peter Pan)
	draw_line(l_foot + Vector2(-3, 0), l_foot + Vector2(-7, -1), Color(0.38, 0.24, 0.10), 4.0)
	draw_circle(l_foot + Vector2(-7, -1), 2.5, Color(0.36, 0.22, 0.09))
	draw_line(r_foot + Vector2(3, 0), r_foot + Vector2(7, -1), Color(0.38, 0.24, 0.10), 4.0)
	draw_circle(r_foot + Vector2(7, -1), 2.5, Color(0.36, 0.22, 0.09))
	# Boot highlight (top)
	draw_arc(l_foot, 3.5, PI + 0.3, TAU - 0.3, 6, Color(0.48, 0.32, 0.16, 0.35), 1.5)
	draw_arc(r_foot, 3.5, PI + 0.3, TAU - 0.3, 6, Color(0.48, 0.32, 0.16, 0.35), 1.5)
	# Boot sole (dark line at bottom)
	draw_arc(l_foot, 5.0, 0.3, PI - 0.3, 8, Color(0.15, 0.08, 0.03, 0.5), 1.5)
	draw_arc(r_foot, 5.0, 0.3, PI - 0.3, 8, Color(0.15, 0.08, 0.03, 0.5), 1.5)
	# Boot shaft (taller boots for longer legs)
	draw_line(l_foot + Vector2(-3.5, -2), l_foot + Vector2(-3.5, -7), Color(0.32, 0.19, 0.08), 3.0)
	draw_line(l_foot + Vector2(3.5, -2), l_foot + Vector2(3.5, -7), Color(0.32, 0.19, 0.08), 3.0)
	draw_line(r_foot + Vector2(-3.5, -2), r_foot + Vector2(-3.5, -7), Color(0.32, 0.19, 0.08), 3.0)
	draw_line(r_foot + Vector2(3.5, -2), r_foot + Vector2(3.5, -7), Color(0.32, 0.19, 0.08), 3.0)
	# Boot fill (cover the shaft area)
	var l_boot_shaft = PackedVector2Array([
		l_foot + Vector2(-4.5, -2), l_foot + Vector2(4.5, -2),
		l_foot + Vector2(4.0, -7), l_foot + Vector2(-4.0, -7),
	])
	draw_colored_polygon(l_boot_shaft, Color(0.36, 0.22, 0.09))
	var r_boot_shaft = PackedVector2Array([
		r_foot + Vector2(-4.5, -2), r_foot + Vector2(4.5, -2),
		r_foot + Vector2(4.0, -7), r_foot + Vector2(-4.0, -7),
	])
	draw_colored_polygon(r_boot_shaft, Color(0.36, 0.22, 0.09))
	# Boot top cuffs (folded-over leather — higher up)
	draw_line(l_foot + Vector2(-4.5, -6), l_foot + Vector2(4.5, -6), Color(0.42, 0.28, 0.12), 2.5)
	draw_line(l_foot + Vector2(-4.0, -6.5), l_foot + Vector2(4.0, -6.5), Color(0.50, 0.34, 0.18, 0.5), 1.2)
	draw_line(r_foot + Vector2(-4.5, -6), r_foot + Vector2(4.5, -6), Color(0.42, 0.28, 0.12), 2.5)
	draw_line(r_foot + Vector2(-4.0, -6.5), r_foot + Vector2(4.0, -6.5), Color(0.50, 0.34, 0.18, 0.5), 1.2)
	# Boot laces (criss-cross — more laces for taller boot)
	for bi in range(2):
		var boot = l_foot if bi == 0 else r_foot
		for bl in range(3):
			var by = -1.0 - float(bl) * 2.0
			draw_line(boot + Vector2(-2, by), boot + Vector2(2, by - 1.0), Color(0.28, 0.16, 0.06, 0.5), 0.7)
			draw_line(boot + Vector2(2, by), boot + Vector2(-2, by - 1.0), Color(0.28, 0.16, 0.06, 0.5), 0.7)

	# --- MUSCULAR LEGS (polygon-based thighs and calves) ---
	var l_hip = leg_top + Vector2(-6, 0)
	var r_hip = leg_top + Vector2(6, 0)
	var l_knee = l_foot.lerp(l_hip, 0.45) + Vector2(-1.5, 0)
	var r_knee = r_foot.lerp(r_hip, 0.45) + Vector2(1.5, 0)
	# LEFT THIGH — muscular polygon
	var lt_dir = (l_knee - l_hip).normalized()
	var lt_perp = lt_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		l_hip + lt_perp * 5.0, l_hip - lt_perp * 4.0,
		l_hip.lerp(l_knee, 0.4) - lt_perp * 5.5,  # inner thigh bulge
		l_knee - lt_perp * 4.0, l_knee + lt_perp * 4.0,
		l_hip.lerp(l_knee, 0.4) + lt_perp * 6.0,   # outer quad bulge
	]), Color(0.14, 0.40, 0.08))
	draw_colored_polygon(PackedVector2Array([
		l_hip + lt_perp * 3.0, l_hip - lt_perp * 2.0,
		l_knee - lt_perp * 2.5, l_knee + lt_perp * 2.5,
	]), Color(0.20, 0.50, 0.14, 0.4))
	# RIGHT THIGH — muscular polygon
	var rt_dir = (r_knee - r_hip).normalized()
	var rt_perp = rt_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		r_hip - rt_perp * 5.0, r_hip + rt_perp * 4.0,
		r_hip.lerp(r_knee, 0.4) + rt_perp * 5.5,
		r_knee + rt_perp * 4.0, r_knee - rt_perp * 4.0,
		r_hip.lerp(r_knee, 0.4) - rt_perp * 6.0,
	]), Color(0.14, 0.40, 0.08))
	draw_colored_polygon(PackedVector2Array([
		r_hip - rt_perp * 3.0, r_hip + rt_perp * 2.0,
		r_knee + rt_perp * 2.5, r_knee - rt_perp * 2.5,
	]), Color(0.20, 0.50, 0.14, 0.4))
	# Knee joints
	draw_circle(l_knee, 4.5, Color(0.14, 0.40, 0.08))
	draw_circle(l_knee, 3.5, Color(0.22, 0.52, 0.14))
	draw_circle(r_knee, 4.5, Color(0.14, 0.40, 0.08))
	draw_circle(r_knee, 3.5, Color(0.22, 0.52, 0.14))
	# LEFT CALF — polygon with muscle bulge
	var l_calf_mid = l_knee.lerp(l_foot + Vector2(0, -3), 0.4) + Vector2(-2.0, 0)
	var lc_dir = (l_foot + Vector2(0, -3) - l_knee).normalized()
	var lc_perp = lc_dir.rotated(PI / 2.0)
	# Upper left calf (knee to mid) — split into two quads to avoid self-intersection
	draw_colored_polygon(PackedVector2Array([
		l_knee + lc_perp * 4.0, l_knee - lc_perp * 3.5,
		l_calf_mid - lc_perp * 5.0, l_calf_mid + lc_perp * 4.5,
	]), Color(0.14, 0.40, 0.08))
	# Lower left calf (mid to foot)
	draw_colored_polygon(PackedVector2Array([
		l_calf_mid + lc_perp * 4.5, l_calf_mid - lc_perp * 5.0,
		l_foot + Vector2(-3, -3), l_foot + Vector2(3, -3),
	]), Color(0.14, 0.40, 0.08))
	draw_circle(l_calf_mid, 3.0, Color(0.22, 0.52, 0.14, 0.3))
	# RIGHT CALF
	var r_calf_mid = r_knee.lerp(r_foot + Vector2(0, -3), 0.4) + Vector2(2.0, 0)
	var rc_dir = (r_foot + Vector2(0, -3) - r_knee).normalized()
	var rc_perp = rc_dir.rotated(PI / 2.0)
	# Upper right calf (knee to mid)
	draw_colored_polygon(PackedVector2Array([
		r_knee - rc_perp * 4.0, r_knee + rc_perp * 3.5,
		r_calf_mid + rc_perp * 5.0, r_calf_mid - rc_perp * 4.5,
	]), Color(0.14, 0.40, 0.08))
	# Lower right calf (mid to foot)
	draw_colored_polygon(PackedVector2Array([
		r_calf_mid - rc_perp * 4.5, r_calf_mid + rc_perp * 5.0,
		r_foot + Vector2(3, -3), r_foot + Vector2(-3, -3),
	]), Color(0.14, 0.40, 0.08))
	draw_circle(r_calf_mid, 3.0, Color(0.22, 0.52, 0.14, 0.3))

	# --- SHORT LINCOLN GREEN CAPE (behind torso) ---
	var cape_wind = sin(_time * 1.8) * 3.0 + sin(_time * 2.7) * 1.5
	var cape_top_l = neck_base + Vector2(-8, 0)
	var cape_top_r = neck_base + Vector2(8, 0)
	var cape_bot_l = torso_center + Vector2(-12 + cape_wind * 0.5, 8.0)
	var cape_bot_r = torso_center + Vector2(12 + cape_wind * 0.3, 10.0)
	draw_colored_polygon(PackedVector2Array([cape_top_l, cape_top_r, cape_bot_r, cape_bot_l]), Color(0.15, 0.40, 0.08, 0.7))
	draw_colored_polygon(PackedVector2Array([cape_top_l, cape_top_r, cape_bot_r, cape_bot_l]), Color(0.20, 0.50, 0.12, 0.3))

	# --- 16. QUIVER on back (drawn behind torso) ---
	var quiver_pos = neck_base + Vector2(-8, 4)
	# Quiver body (brown leather, tall rectangle)
	var q_pts = PackedVector2Array([
		quiver_pos + Vector2(-4, 6),
		quiver_pos + Vector2(4, 6),
		quiver_pos + Vector2(3, -14),
		quiver_pos + Vector2(-3, -14),
	])
	draw_colored_polygon(q_pts, Color(0.42, 0.26, 0.10))
	# Quiver inner leather
	var q_inner = PackedVector2Array([
		quiver_pos + Vector2(-2.5, 4),
		quiver_pos + Vector2(2.5, 4),
		quiver_pos + Vector2(2, -12),
		quiver_pos + Vector2(-2, -12),
	])
	draw_colored_polygon(q_inner, Color(0.48, 0.30, 0.14, 0.5))
	# Quiver stitching
	for qi in range(4):
		var qy = 3.0 - float(qi) * 4.5
		draw_line(quiver_pos + Vector2(-3.5, qy), quiver_pos + Vector2(3.5, qy), Color(0.35, 0.20, 0.08, 0.4), 0.7)
	# Quiver rim (top opening)
	draw_line(quiver_pos + Vector2(-3.5, -14), quiver_pos + Vector2(3.5, -14), Color(0.50, 0.34, 0.16), 2.5)
	draw_line(quiver_pos + Vector2(-3, -14.5), quiver_pos + Vector2(3, -14.5), Color(0.56, 0.38, 0.20), 1.5)
	# Quiver strap (crosses chest)
	draw_line(quiver_pos + Vector2(2, -8), torso_center + Vector2(8, 2), Color(0.38, 0.22, 0.08), 2.5)
	draw_line(quiver_pos + Vector2(2, -8), torso_center + Vector2(8, 2), Color(0.44, 0.28, 0.12), 1.5)
	# Strap brass fittings (rivets along strap)
	var strap_mid = quiver_pos.lerp(torso_center + Vector2(5, 2), 0.5)
	draw_circle(strap_mid, 1.5, Color(0.70, 0.55, 0.20))
	draw_circle(strap_mid, 0.8, Color(0.85, 0.70, 0.30, 0.5))
	# Brass rivets along strap
	for rvi in range(3):
		var rv_t = 0.2 + float(rvi) * 0.25
		var rv_pos = quiver_pos.lerp(torso_center + Vector2(8, 2), rv_t)
		draw_circle(rv_pos, 1.0, Color(0.72, 0.58, 0.22))
		draw_circle(rv_pos, 0.5, Color(0.88, 0.74, 0.35, 0.5))
	# Arrows in quiver (feathers sticking out at top)
	var arrow_count = 3 + upgrade_tier
	for ai in range(arrow_count):
		var ax = -2.0 + float(ai) * (4.0 / float(max(arrow_count - 1, 1)))
		var arrow_top = quiver_pos + Vector2(ax, -16.0 - float(ai % 2) * 2.0)
		var shaft_col = Color(0.58, 0.45, 0.25)
		if upgrade_tier >= 2 and ai == 0:
			shaft_col = Color(0.80, 0.78, 0.65)  # Silver arrow
		if upgrade_tier >= 4 and ai <= 1:
			shaft_col = Color(0.88, 0.72, 0.28)  # Golden arrows
		# Arrow shaft
		draw_line(quiver_pos + Vector2(ax, -13), arrow_top, shaft_col, 1.2)
		# Fletching (3 feathers per arrow, colored)
		var fletch_col = Color(0.75, 0.75, 0.7, 0.7) if ai % 3 == 0 else Color(0.72, 0.18, 0.12, 0.7) if ai % 3 == 1 else Color(0.2, 0.5, 0.2, 0.7)
		draw_line(arrow_top, arrow_top + Vector2(-1.5, -2.5), fletch_col, 1.0)
		draw_line(arrow_top, arrow_top + Vector2(1.5, -2.5), fletch_col.darkened(0.15), 1.0)
		draw_line(arrow_top, arrow_top + Vector2(0, -3.0), fletch_col.lightened(0.1), 0.8)
		# Tier 4: fiery tips
		if upgrade_tier >= 4 and ai < 2:
			var fire_pos = quiver_pos + Vector2(ax, -13)
			draw_circle(fire_pos, 1.5, Color(1.0, 0.6, 0.1, 0.35 + sin(_time * 5.0 + float(ai)) * 0.15))
			draw_circle(fire_pos, 0.8, Color(1.0, 0.9, 0.4, 0.25))

	# --- Lincoln green tunic (MUSCULAR V-taper build) ---
	# Broad shoulders (±18px), narrow waist (±8px) — heroic V-taper
	var tunic_pts = PackedVector2Array([
		leg_top + Vector2(-8, 0),         # waist left
		leg_top + Vector2(-9, -3),        # oblique taper
		torso_center + Vector2(-14, 0),   # lats flare
		neck_base + Vector2(-18, 0),      # broad shoulder left
		neck_base + Vector2(18, 0),       # broad shoulder right
		torso_center + Vector2(14, 0),    # lats flare
		leg_top + Vector2(9, -3),         # oblique taper
		leg_top + Vector2(8, 0),          # waist right
	])
	draw_colored_polygon(tunic_pts, Color(0.16, 0.44, 0.10))
	# Lighter inner tunic (pec area)
	var tunic_hi = PackedVector2Array([
		leg_top + Vector2(-5, -1),
		torso_center + Vector2(-8, 0),
		torso_center + Vector2(8, 0),
		leg_top + Vector2(5, -1),
	])
	draw_colored_polygon(tunic_hi, Color(0.22, 0.54, 0.16, 0.4))
	# PECTORAL definition — visible chest muscles under tunic
	draw_arc(neck_base + Vector2(-6, 6), 6.5, PI * 0.2, PI * 0.9, 10, Color(0.12, 0.36, 0.08, 0.4), 1.5)
	draw_arc(neck_base + Vector2(6, 6), 6.5, PI * 0.1, PI * 0.8, 10, Color(0.12, 0.36, 0.08, 0.4), 1.5)
	# Pec shadow fills
	draw_circle(neck_base + Vector2(-5, 8), 4.5, Color(0.12, 0.36, 0.08, 0.15))
	draw_circle(neck_base + Vector2(5, 8), 4.5, Color(0.12, 0.36, 0.08, 0.15))
	# Center chest line (sternum)
	draw_line(neck_base + Vector2(0, 3), torso_center + Vector2(0, 2), Color(0.10, 0.30, 0.06, 0.3), 1.0)
	# Ab definition lines
	draw_line(torso_center + Vector2(-4, -2), torso_center + Vector2(-4, 5), Color(0.10, 0.30, 0.06, 0.15), 0.8)
	draw_line(torso_center + Vector2(4, -2), torso_center + Vector2(4, 5), Color(0.10, 0.30, 0.06, 0.15), 0.8)
	draw_line(torso_center + Vector2(-6, 1), torso_center + Vector2(6, 1), Color(0.10, 0.30, 0.06, 0.1), 0.6)
	# V-neckline
	draw_line(neck_base + Vector2(-4, 0), neck_base + Vector2(0, 5), Color(0.12, 0.34, 0.08, 0.6), 1.2)
	draw_line(neck_base + Vector2(4, 0), neck_base + Vector2(0, 5), Color(0.12, 0.34, 0.08, 0.6), 1.2)
	# Undershirt visible at V-neck
	var vneck_pts = PackedVector2Array([
		neck_base + Vector2(-3.5, 0),
		neck_base + Vector2(3.5, 0),
		neck_base + Vector2(0, 4),
	])
	draw_colored_polygon(vneck_pts, Color(0.72, 0.66, 0.52, 0.4))
	# Tunic fold shadows
	draw_line(neck_base + Vector2(-14, 2), leg_top + Vector2(-7, -1), Color(0.10, 0.32, 0.06, 0.4), 1.2)
	draw_line(neck_base + Vector2(14, 2), leg_top + Vector2(7, -1), Color(0.10, 0.32, 0.06, 0.4), 1.2)
	draw_line(torso_center + Vector2(-3, -6), leg_top + Vector2(-2, 0), Color(0.12, 0.36, 0.08, 0.25), 0.8)
	draw_line(torso_center + Vector2(3, -6), leg_top + Vector2(2, 0), Color(0.12, 0.36, 0.08, 0.25), 0.8)
	# Tunic hem (slightly scalloped — Lincoln green style)
	for hi in range(5):
		var hx = -7.0 + float(hi) * 3.5
		var h_depth = 2.5 + sin(float(hi) * 2.1 + _time * 1.2) * 1.5
		var h_pts = PackedVector2Array([
			leg_top + Vector2(hx - 1.5, 0),
			leg_top + Vector2(hx + 1.5, 0),
			leg_top + Vector2(hx, h_depth),
		])
		draw_colored_polygon(h_pts, Color(0.14, 0.40, 0.08))
	# Cobweb thread (gothic detail)
	draw_line(torso_center + Vector2(-11, -5), torso_center + Vector2(8, 5), Color(0.85, 0.88, 0.92, 0.06), 0.5)
	# Stitch detail along tunic seams (short perpendicular lines)
	for sti in range(5):
		var st_t = float(sti + 1) / 6.0
		var st_l = neck_base.lerp(leg_top, st_t) + Vector2(-13 + st_t * 5.0, 0)
		var st_r = neck_base.lerp(leg_top, st_t) + Vector2(13 - st_t * 5.0, 0)
		draw_line(st_l + Vector2(-1.5, -1), st_l + Vector2(-1.5, 1.5), Color(0.10, 0.30, 0.06, 0.3), 0.6)
		draw_line(st_r + Vector2(1.5, -1), st_r + Vector2(1.5, 1.5), Color(0.10, 0.30, 0.06, 0.3), 0.6)

	# --- Brown leather belt with brass buckle ---
	draw_line(leg_top + Vector2(-10, -1), leg_top + Vector2(10, -1), Color(0.32, 0.18, 0.06), 4.0)
	draw_line(leg_top + Vector2(-9, -1), leg_top + Vector2(9, -1), Color(0.40, 0.24, 0.10), 2.5)
	# Belt highlight (top edge)
	draw_line(leg_top + Vector2(-9, -2.5), leg_top + Vector2(9, -2.5), Color(0.48, 0.30, 0.14, 0.35), 0.8)
	# Belt stitch marks
	for bsi in range(4):
		var bsx = -6.0 + float(bsi) * 4.0
		draw_line(leg_top + Vector2(bsx, -2.2), leg_top + Vector2(bsx, 0.2), Color(0.45, 0.28, 0.12, 0.4), 0.6)
	# Tooled leather texture (small decorative arcs along belt)
	for tli in range(6):
		var tl_x = -7.0 + float(tli) * 2.8
		var tl_pos = leg_top + Vector2(tl_x, -1)
		draw_arc(tl_pos, 1.0, PI * 0.2, PI * 0.8, 4, Color(0.48, 0.30, 0.14, 0.25), 0.5)
	# Brass buckle (center)
	var buckle_c = leg_top + Vector2(0, -1)
	draw_circle(buckle_c, 3.5, Color(0.75, 0.60, 0.18))
	draw_circle(buckle_c, 2.5, Color(0.85, 0.72, 0.28))
	draw_circle(buckle_c, 1.5, Color(0.35, 0.20, 0.08))
	# Buckle highlight
	draw_arc(buckle_c, 2.8, PI + 0.5, TAU - 0.5, 6, Color(1.0, 0.92, 0.50, 0.4), 0.8)
	draw_arc(buckle_c, 3.5, 0, TAU, 8, Color(0.60, 0.48, 0.14, 0.3), 0.6)
	# Coin pouch on belt (left side)
	var pouch_pos = leg_top + Vector2(-7, 1)
	draw_circle(pouch_pos, 3.2, Color(0.38, 0.22, 0.08))
	draw_circle(pouch_pos + Vector2(0, -0.5), 2.5, Color(0.44, 0.28, 0.12))
	# Pouch drawstring
	draw_line(pouch_pos + Vector2(-1, -2.5), pouch_pos + Vector2(1, -2.5), Color(0.32, 0.18, 0.06, 0.5), 0.6)
	# Coins peeking out
	draw_circle(pouch_pos + Vector2(0.5, -3.0), 0.8, Color(0.85, 0.72, 0.22, 0.5))

	# --- Tier 3+: Golden hunting horn hanging from belt ---
	if upgrade_tier >= 3:
		var horn_base = leg_top + Vector2(7, 2)
		var horn_curve = horn_base + Vector2(6, 5)
		var horn_bell = horn_base + Vector2(10, 9)
		# Horn shadow
		draw_line(horn_base + Vector2(0.5, 0.5), horn_curve + Vector2(0.5, 0.5), Color(0, 0, 0, 0.1), 3.5)
		draw_line(horn_curve + Vector2(0.5, 0.5), horn_bell + Vector2(0.5, 0.5), Color(0, 0, 0, 0.1), 4.0)
		# Horn body (tapered brass)
		draw_line(horn_base, horn_curve, Color(0.70, 0.55, 0.18), 3.0)
		draw_line(horn_curve, horn_bell, Color(0.75, 0.60, 0.22), 3.5)
		# Horn golden highlight
		draw_line(horn_base, horn_curve, Color(0.88, 0.75, 0.35, 0.4), 1.5)
		draw_line(horn_curve, horn_bell, Color(0.92, 0.80, 0.40, 0.35), 1.8)
		# Decorative bands
		var hb1 = horn_base.lerp(horn_curve, 0.4)
		var hb2 = horn_curve.lerp(horn_bell, 0.5)
		draw_line(hb1 + Vector2(-1.5, 0), hb1 + Vector2(1.5, 0), Color(0.85, 0.70, 0.28), 1.2)
		draw_line(hb2 + Vector2(-2.0, 0), hb2 + Vector2(2.0, 0), Color(0.85, 0.70, 0.28), 1.2)
		# Horn bell (flared end)
		draw_circle(horn_bell, 3.5, Color(0.78, 0.62, 0.22))
		draw_circle(horn_bell, 2.0, Color(0.52, 0.38, 0.14))
		draw_arc(horn_bell, 3.0, PI + 0.4, TAU - 0.4, 6, Color(0.95, 0.82, 0.42, 0.5), 1.0)
		# Mouthpiece
		draw_circle(horn_base, 1.5, Color(0.85, 0.72, 0.32))
		# Leather cord from belt
		draw_line(horn_base, leg_top + Vector2(6, -1), Color(0.42, 0.26, 0.10), 1.5)
		# Tier 4: horn glow
		if upgrade_tier >= 4:
			draw_circle(horn_bell, 5.5, Color(1.0, 0.85, 0.3, 0.1 + sin(_time * 3.0) * 0.05))

	# --- Shoulder pads (broad athletic build) ---
	var l_shoulder = neck_base + Vector2(-16, 0)
	var r_shoulder = neck_base + Vector2(16, 0)
	draw_circle(l_shoulder, 6.5, Color(0.14, 0.38, 0.08))
	draw_circle(l_shoulder, 5.0, Color(0.20, 0.48, 0.12))
	draw_line(l_shoulder + Vector2(-3, 0), l_shoulder + Vector2(3, 0), Color(0.10, 0.30, 0.06, 0.5), 0.7)
	draw_circle(r_shoulder, 6.5, Color(0.14, 0.38, 0.08))
	draw_circle(r_shoulder, 5.0, Color(0.20, 0.48, 0.12))
	draw_line(r_shoulder + Vector2(-3, 0), r_shoulder + Vector2(3, 0), Color(0.10, 0.30, 0.06, 0.5), 0.7)
	# Shoulder seam stitching
	draw_arc(l_shoulder, 5.5, 0, TAU, 10, Color(0.10, 0.30, 0.06, 0.35), 0.7)
	draw_arc(r_shoulder, 5.5, 0, TAU, 10, Color(0.10, 0.30, 0.06, 0.35), 0.7)

	# --- MUSCULAR ARMS (polygon-based biceps and forearms) ---
	# BOW ARM: reaches toward aim with bow
	var bow_hand = r_shoulder + Vector2(0, 2) + dir * 20.0
	var bow_elbow = r_shoulder + (bow_hand - r_shoulder) * 0.4
	var ba_dir = (bow_elbow - r_shoulder).normalized()
	var ba_perp = ba_dir.rotated(PI / 2.0)
	# Upper arm — muscular bicep polygon
	draw_colored_polygon(PackedVector2Array([
		r_shoulder + ba_perp * 5.0, r_shoulder - ba_perp * 4.0,
		r_shoulder.lerp(bow_elbow, 0.35) - ba_perp * 5.5,  # bicep peak
		bow_elbow - ba_perp * 4.0, bow_elbow + ba_perp * 3.5,
		r_shoulder.lerp(bow_elbow, 0.45) + ba_perp * 6.0,   # outer deltoid
	]), skin_shadow)
	draw_colored_polygon(PackedVector2Array([
		r_shoulder + ba_perp * 3.5, r_shoulder - ba_perp * 2.5,
		bow_elbow - ba_perp * 2.5, bow_elbow + ba_perp * 2.0,
	]), skin_base)
	# Bicep highlight
	var bow_bicep = r_shoulder.lerp(bow_elbow, 0.35) + ba_perp * 2.0
	draw_circle(bow_bicep, 3.0, skin_highlight)
	# Sleeve over upper arm
	draw_colored_polygon(PackedVector2Array([
		r_shoulder + ba_perp * 5.5, r_shoulder - ba_perp * 4.5,
		bow_elbow - ba_perp * 4.5, bow_elbow + ba_perp * 4.0,
	]), Color(0.18, 0.46, 0.10))
	draw_colored_polygon(PackedVector2Array([
		r_shoulder + ba_perp * 3.5, r_shoulder - ba_perp * 2.5,
		bow_elbow - ba_perp * 2.5, bow_elbow + ba_perp * 2.0,
	]), Color(0.22, 0.52, 0.14, 0.5))
	# Elbow joint
	draw_circle(bow_elbow, 4.0, skin_shadow)
	draw_circle(bow_elbow, 3.0, skin_base)
	# Forearm — tapered polygon
	var bf_dir = (bow_hand - bow_elbow).normalized()
	var bf_perp = bf_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		bow_elbow + bf_perp * 4.0, bow_elbow - bf_perp * 3.5,
		bow_hand - bf_perp * 2.5, bow_hand + bf_perp * 2.5,
	]), skin_shadow)
	draw_colored_polygon(PackedVector2Array([
		bow_elbow + bf_perp * 2.5, bow_elbow - bf_perp * 2.0,
		bow_hand - bf_perp * 1.5, bow_hand + bf_perp * 1.5,
	]), skin_base)
	# Forearm muscle definition
	draw_circle(bow_elbow.lerp(bow_hand, 0.3) + bf_perp * 1.5, 2.0, skin_highlight)
	# Leather bracer on bow arm
	var bracer_start = bow_elbow.lerp(bow_hand, 0.4)
	var bracer_end = bow_elbow.lerp(bow_hand, 0.85)
	draw_colored_polygon(PackedVector2Array([
		bracer_start + bf_perp * 3.5, bracer_start - bf_perp * 3.0,
		bracer_end - bf_perp * 2.5, bracer_end + bf_perp * 2.5,
	]), Color(0.38, 0.22, 0.08))
	draw_colored_polygon(PackedVector2Array([
		bracer_start + bf_perp * 2.0, bracer_start - bf_perp * 1.5,
		bracer_end - bf_perp * 1.5, bracer_end + bf_perp * 1.5,
	]), Color(0.46, 0.30, 0.12))
	for bri in range(3):
		var brt = float(bri + 1) / 4.0
		var br_pos = bracer_start.lerp(bracer_end, brt)
		draw_line(br_pos - bf_perp * 3.0, br_pos + bf_perp * 3.0, Color(0.32, 0.18, 0.06, 0.5), 0.8)
	# Leather lacing X-pattern on bracer
	for lci in range(2):
		var lc_t1 = 0.2 + float(lci) * 0.35
		var lc_t2 = lc_t1 + 0.15
		var lc_p1 = bracer_start.lerp(bracer_end, lc_t1)
		var lc_p2 = bracer_start.lerp(bracer_end, lc_t2)
		draw_line(lc_p1 - bf_perp * 1.8, lc_p2 + bf_perp * 1.8, Color(0.28, 0.16, 0.06, 0.4), 0.6)
		draw_line(lc_p1 + bf_perp * 1.8, lc_p2 - bf_perp * 1.8, Color(0.28, 0.16, 0.06, 0.4), 0.6)
	# Bow hand
	draw_circle(bow_hand, 4.0, skin_shadow)
	draw_circle(bow_hand, 3.2, skin_base)
	for fi in range(3):
		var fa = float(fi - 1) * 0.35
		draw_circle(bow_hand + dir.rotated(fa) * 3.5, 1.3, skin_highlight)

	# DRAW ARM: string-pulling arm (draws arrow back)
	var string_pull_vec = dir * (-12.0 * _draw_progress)
	var draw_hand = l_shoulder + Vector2(6, 4) + dir * 6.0 + string_pull_vec
	var draw_elbow = l_shoulder + (draw_hand - l_shoulder) * 0.4
	var da_dir = (draw_elbow - l_shoulder).normalized()
	var da_perp = da_dir.rotated(PI / 2.0)
	# Upper arm — flexed bicep polygon (pulling string = flexed)
	var bicep_flex = 1.0 + _draw_progress * 0.5  # bigger when drawn
	draw_colored_polygon(PackedVector2Array([
		l_shoulder - da_perp * 5.0, l_shoulder + da_perp * 4.0,
		l_shoulder.lerp(draw_elbow, 0.35) + da_perp * (5.5 * bicep_flex),
		draw_elbow + da_perp * 4.0, draw_elbow - da_perp * 3.5,
		l_shoulder.lerp(draw_elbow, 0.45) - da_perp * 6.0,
	]), skin_shadow)
	draw_colored_polygon(PackedVector2Array([
		l_shoulder - da_perp * 3.5, l_shoulder + da_perp * 2.5,
		draw_elbow + da_perp * 2.5, draw_elbow - da_perp * 2.0,
	]), skin_base)
	# Bicep peak highlight (more visible when flexed)
	var draw_bicep = l_shoulder.lerp(draw_elbow, 0.35) - da_perp * 2.0
	draw_circle(draw_bicep, 3.0 * bicep_flex, skin_highlight)
	# Sleeve
	draw_colored_polygon(PackedVector2Array([
		l_shoulder - da_perp * 5.5, l_shoulder + da_perp * 4.5,
		draw_elbow + da_perp * 4.5, draw_elbow - da_perp * 4.0,
	]), Color(0.18, 0.46, 0.10))
	# Elbow joint
	draw_circle(draw_elbow, 4.0, skin_shadow)
	draw_circle(draw_elbow, 3.0, skin_base)
	# Forearm polygon
	var df_dir = (draw_hand - draw_elbow).normalized()
	var df_perp = df_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		draw_elbow - df_perp * 4.0, draw_elbow + df_perp * 3.5,
		draw_hand + df_perp * 2.5, draw_hand - df_perp * 2.5,
	]), skin_shadow)
	draw_colored_polygon(PackedVector2Array([
		draw_elbow - df_perp * 2.5, draw_elbow + df_perp * 2.0,
		draw_hand + df_perp * 1.5, draw_hand - df_perp * 1.5,
	]), skin_base)
	# Draw hand with leather tab
	draw_circle(draw_hand, 4.0, Color(0.40, 0.24, 0.10))
	draw_circle(draw_hand, 3.0, skin_base)
	# Three fingers on string
	draw_line(draw_hand, draw_hand + dir * 3.0 + perp * 1.5, skin_base, 1.8)
	draw_line(draw_hand, draw_hand + dir * 3.5, skin_base, 1.8)
	draw_line(draw_hand, draw_hand + dir * 3.0 - perp * 1.5, skin_base, 1.8)
	draw_circle(draw_hand + dir * 3.0 + perp * 1.5, 0.8, skin_highlight)
	draw_circle(draw_hand + dir * 3.5, 0.8, skin_highlight)
	draw_circle(draw_hand + dir * 3.0 - perp * 1.5, 0.8, skin_highlight)

	# === 15. WEAPON — LONGBOW ===
	var bow_center = bow_hand + dir * 2.0
	var bow_top = bow_center + Vector2(0, -22.0)
	var bow_bottom = bow_center + Vector2(0, 22.0)
	var bow_curve_pt = bow_center + dir * 8.0

	# Bow limb colors (yew wood, silver-tinted at tier 2+)
	var bow_dark = Color(0.48, 0.28, 0.10) if upgrade_tier < 2 else Color(0.50, 0.45, 0.40).lerp(Color(0.65, 0.68, 0.72), 0.3)
	var bow_light = Color(0.60, 0.38, 0.16) if upgrade_tier < 2 else Color(0.60, 0.56, 0.50).lerp(Color(0.75, 0.78, 0.82), 0.3)

	# Tier 2+: Silver glow along bow
	if upgrade_tier >= 2:
		var silver_p = (sin(_time * 2.8) + 1.0) * 0.5
		var silver_a = 0.06 + silver_p * 0.04
		for sgi in range(5):
			var sgt = float(sgi) / 4.0
			draw_circle(bow_top.lerp(bow_curve_pt, sgt), 4.0, Color(0.8, 0.85, 0.95, silver_a))
			draw_circle(bow_curve_pt.lerp(bow_bottom, sgt), 4.0, Color(0.8, 0.85, 0.95, silver_a))

	# Bow upper limb
	draw_line(bow_top, bow_curve_pt, bow_dark, 4.5)
	draw_line(bow_top, bow_curve_pt, bow_light, 2.5)
	# Bow lower limb
	draw_line(bow_curve_pt, bow_bottom, bow_dark, 4.5)
	draw_line(bow_curve_pt, bow_bottom, bow_light, 2.5)
	# Wood grain lines
	draw_line(bow_top.lerp(bow_curve_pt, 0.1) + perp * 0.5, bow_top.lerp(bow_curve_pt, 0.75) + perp * 0.5, Color(bow_light.r + 0.05, bow_light.g + 0.02, bow_light.b, 0.3), 0.6)
	draw_line(bow_curve_pt.lerp(bow_bottom, 0.15) - perp * 0.4, bow_curve_pt.lerp(bow_bottom, 0.8) - perp * 0.4, Color(bow_dark.r - 0.05, bow_dark.g - 0.02, bow_dark.b, 0.25), 0.5)
	# Wood knot
	draw_circle(bow_top.lerp(bow_curve_pt, 0.35), 0.8, Color(bow_dark.r - 0.1, bow_dark.g - 0.05, bow_dark.b, 0.4))
	# Horn nocks at tips
	draw_circle(bow_top, 2.0, Color(0.88, 0.85, 0.78))
	draw_circle(bow_top, 1.3, Color(0.92, 0.90, 0.84))
	draw_circle(bow_bottom, 2.0, Color(0.88, 0.85, 0.78))
	draw_circle(bow_bottom, 1.3, Color(0.92, 0.90, 0.84))
	# Nock grooves
	draw_line(bow_top + Vector2(-0.5, 0), bow_top + Vector2(0.5, 0), Color(0.60, 0.55, 0.45, 0.5), 0.5)
	draw_line(bow_bottom + Vector2(-0.5, 0), bow_bottom + Vector2(0.5, 0), Color(0.60, 0.55, 0.45, 0.5), 0.5)
	# Leather grip wrap
	draw_line(bow_curve_pt + Vector2(0, -3.5), bow_curve_pt + Vector2(0, 3.5), Color(0.35, 0.20, 0.08), 5.5)
	draw_line(bow_curve_pt + Vector2(0, -2.5), bow_curve_pt + Vector2(0, 2.5), Color(0.42, 0.26, 0.10), 4.0)
	draw_line(bow_curve_pt + Vector2(0, -1.5), bow_curve_pt + Vector2(0, 1.5), Color(0.48, 0.30, 0.14), 2.5)
	# Grip cross-hatch wrapping
	for gi in range(4):
		var gy = -2.5 + float(gi) * 1.5
		var gp = bow_curve_pt + Vector2(0, gy)
		draw_line(gp + Vector2(-2.0, -0.5), gp + Vector2(2.0, 0.5), Color(0.32, 0.18, 0.06, 0.4), 0.6)

	# Bowstring
	var string_pull_offset = dir * (-10.0 * _draw_progress)
	var vib_offset = perp * string_vib
	var string_nock_pt = bow_center + string_pull_offset + vib_offset
	# String shadow
	draw_line(bow_top, string_nock_pt, Color(0.4, 0.35, 0.25, 0.12), 1.5)
	draw_line(bow_bottom, string_nock_pt, Color(0.4, 0.35, 0.25, 0.12), 1.5)
	# Main bowstring
	draw_line(bow_top, string_nock_pt, Color(0.78, 0.72, 0.58), 1.2)
	draw_line(bow_bottom, string_nock_pt, Color(0.78, 0.72, 0.58), 1.2)
	# String sheen
	draw_line(bow_top, string_nock_pt, Color(0.90, 0.85, 0.72, 0.25), 0.5)
	draw_line(bow_bottom, string_nock_pt, Color(0.90, 0.85, 0.72, 0.25), 0.5)
	# Serving (thicker wrap where arrow nocks)
	var serving_c = bow_center + string_pull_offset * 0.5 + vib_offset * 0.5
	draw_line(serving_c + Vector2(0, -2.0), serving_c + Vector2(0, 2.0), Color(0.70, 0.65, 0.50, 0.3), 2.0)

	# Arrow nocked on string (visible when drawing)
	if _draw_progress > 0.15:
		var arrow_nock = bow_center + string_pull_offset
		var arrow_tip = bow_center + dir * 28.0

		# Silver arrow detection
		var next_is_silver = upgrade_tier >= 2 and (shot_count + 1) % silver_interval == 0
		var shaft_col = Color(0.82, 0.78, 0.55) if next_is_silver else Color(0.58, 0.46, 0.28)
		var head_col = Color(0.88, 0.80, 0.35) if next_is_silver else Color(0.50, 0.50, 0.55)

		# Arrow shaft shadow
		draw_line(arrow_nock + perp * 0.3, arrow_tip + perp * 0.3, Color(0.3, 0.2, 0.1, 0.12), 2.0)
		# Arrow shaft
		draw_line(arrow_nock, arrow_tip, shaft_col, 1.5)
		# Wood grain highlight
		draw_line(arrow_nock, arrow_tip, Color(shaft_col.r + 0.08, shaft_col.g + 0.08, shaft_col.b + 0.04, 0.25), 0.5)

		# Broadhead
		var head_base = arrow_tip - dir * 4.0
		var head_pts = PackedVector2Array([
			arrow_tip,
			head_base + perp * 3.5,
			head_base - dir * 1.0,
			head_base - perp * 3.5,
		])
		draw_colored_polygon(head_pts, head_col)
		# Broadhead edge
		draw_line(arrow_tip, head_base + perp * 3.5, Color(head_col.r + 0.1, head_col.g + 0.1, head_col.b + 0.05, 0.5), 0.6)
		draw_line(arrow_tip, head_base - perp * 3.5, Color(head_col.r - 0.05, head_col.g - 0.05, head_col.b, 0.4), 0.6)
		# Center blade line
		draw_line(arrow_tip, head_base - dir * 1.0, Color(0.72, 0.72, 0.78, 0.5), 0.8)

		# Fletching (3 feathers)
		var fletch_start = arrow_nock + dir * 1.5
		var fletch_end = arrow_nock + dir * 6.0
		draw_line(fletch_start + perp * 2.2, fletch_end + perp * 1.2, Color(0.82, 0.82, 0.78), 1.5)
		draw_line(fletch_start - perp * 2.2, fletch_end - perp * 1.2, Color(0.82, 0.82, 0.78), 1.5)
		draw_line(fletch_start + dir * 0.3, fletch_end + dir * 0.3, Color(0.75, 0.18, 0.12), 1.5)
		# Feather barb lines
		for fli in range(4):
			var flt = float(fli + 1) / 5.0
			var fl_top = fletch_start.lerp(fletch_end, flt)
			draw_line(fl_top, fl_top + perp * (2.0 - flt * 0.8) * 0.3, Color(0.78, 0.78, 0.72, 0.35), 0.4)
			draw_line(fl_top, fl_top - perp * (2.0 - flt * 0.8) * 0.3, Color(0.78, 0.78, 0.72, 0.35), 0.4)
		# Nock point
		draw_circle(arrow_nock, 1.0, Color(0.88, 0.84, 0.74))

		# Silver glow on arrow
		if next_is_silver:
			var sglow = (sin(_time * 4.0) + 1.0) * 0.5
			draw_circle(arrow_tip, 5.0 + sglow * 2.0, Color(0.88, 0.90, 1.0, 0.2))
			draw_circle(arrow_tip, 2.5 + sglow, Color(1.0, 0.95, 0.72, 0.25))

		# Tier 4: Fiery arrow tip
		if upgrade_tier >= 4:
			var ff1 = sin(_time * 8.0) * 0.5 + 0.5
			var ff2 = sin(_time * 11.0 + 1.5) * 0.5 + 0.5
			draw_circle(arrow_tip, 4.5 + ff1 * 2.0, Color(1.0, 0.4, 0.05, 0.18 + ff1 * 0.08))
			draw_circle(arrow_tip, 2.5 + ff2 * 1.0, Color(1.0, 0.7, 0.1, 0.25))
			draw_circle(arrow_tip, 1.2 + ff1 * 0.5, Color(1.0, 0.95, 0.5, 0.3))
			# Flame tongues
			draw_line(arrow_tip, arrow_tip + dir * (3.5 + ff1 * 1.5) + perp * sin(_time * 6.0) * 1.2, Color(1.0, 0.5, 0.1, 0.25), 1.2)
			draw_line(arrow_tip, arrow_tip + dir * (2.5 + ff2 * 1.0) - perp * sin(_time * 7.0) * 0.8, Color(1.0, 0.6, 0.15, 0.2), 1.0)
			# Ember particles
			for ei in range(3):
				var ea = _time * 5.0 + float(ei) * TAU / 3.0
				var er = 2.0 + sin(_time * 3.0 + float(ei)) * 1.2
				var epos = arrow_tip + Vector2(cos(ea) * er, sin(ea) * er * 0.5) + dir * 1.5
				draw_circle(epos, 0.5, Color(1.0, 0.65 + sin(_time * 4.0 + float(ei)) * 0.2, 0.2, 0.35))

	# === HEAD (proportional anime head) ===
	# Neck (visible, athletic — from neck_base up to bottom of head)
	var neck_top = head_center + Vector2(0, 9)
	var neck_dir = (neck_top - neck_base).normalized()
	var neck_perp = neck_dir.rotated(PI / 2.0)
	# Masculine neck polygon (wider, strong)
	draw_colored_polygon(PackedVector2Array([
		neck_base + neck_perp * 6.5, neck_base - neck_perp * 6.5,
		neck_base.lerp(neck_top, 0.5) - neck_perp * 5.5,
		neck_top - neck_perp * 4.5, neck_top + neck_perp * 4.5,
		neck_base.lerp(neck_top, 0.5) + neck_perp * 5.5,
	]), skin_shadow)
	# Inner neck fill
	draw_colored_polygon(PackedVector2Array([
		neck_base + neck_perp * 5.5, neck_base - neck_perp * 5.5,
		neck_top - neck_perp * 3.5, neck_top + neck_perp * 3.5,
	]), skin_base)
	# Neck highlight
	draw_line(neck_base.lerp(neck_top, 0.15) + neck_perp * 3.0, neck_base.lerp(neck_top, 0.85) + neck_perp * 2.5, skin_highlight, 1.8)
	# Sternocleidomastoid muscle definition
	draw_line(neck_base + neck_perp * 4.0, neck_top - neck_perp * 1.0, Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.15), 1.0)
	draw_line(neck_base - neck_perp * 4.0, neck_top + neck_perp * 1.0, Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.15), 1.0)
	# Adam's apple subtle
	var adams_y = neck_base.lerp(neck_top, 0.4)
	draw_circle(adams_y + neck_perp * 0.5, 1.5, Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.2))

	# Auburn/brown messy hair (back layer, drawn before face)
	var hair_sway = sin(_time * 2.5) * 2.0
	var hair_base_col = Color(0.42, 0.22, 0.10)
	var hair_mid_col = Color(0.50, 0.28, 0.12)
	var hair_hi_col = Color(0.58, 0.34, 0.16)
	# Hair mass (scaled to radius 11)
	draw_circle(head_center, 11.0, hair_base_col)
	draw_circle(head_center + Vector2(0, -0.8), 9.8, hair_mid_col)
	# Volume highlight
	draw_circle(head_center + Vector2(-1.6, -2.4), 5.5, Color(0.52, 0.30, 0.14, 0.3))
	# Messy tufts (windswept, dramatic — extended 25%)
	var tuft_data = [
		[0.3, 5.4, 2.0], [1.0, 5.9, 1.7], [1.7, 4.9, 2.2], [2.4, 6.4, 1.6],
		[3.2, 5.4, 2.0], [4.0, 5.9, 1.8], [4.8, 5.4, 2.1], [5.5, 5.9, 1.6],
		[0.65, 5.0, 1.8], [3.6, 5.2, 1.7],  # Extra tufts for fullness
	]
	for h in range(tuft_data.size()):
		var ha: float = tuft_data[h][0]
		var tlen: float = tuft_data[h][1]
		var twid: float = tuft_data[h][2]
		var tuft_base_pos = head_center + Vector2.from_angle(ha) * 9.5
		var sway_d = 1.0 if h % 2 == 0 else -1.0
		# S-curve wave modulation along strand length
		var s_wave = sin(ha * 3.0 + _time * 1.5) * 1.2
		var tuft_tip_pos = tuft_base_pos + Vector2.from_angle(ha) * tlen + Vector2(hair_sway * sway_d * 0.4 + s_wave, s_wave * 0.3)
		var tcol = hair_mid_col if h % 3 == 0 else hair_hi_col if h % 3 == 1 else hair_base_col
		draw_line(tuft_base_pos, tuft_tip_pos, tcol, twid)
		# Secondary wispy strand
		var ha2 = ha + (0.12 if h % 2 == 0 else -0.12)
		var t2_base = head_center + Vector2.from_angle(ha2) * 8.7
		var t2_tip = t2_base + Vector2.from_angle(ha2) * (tlen * 0.6) + Vector2(hair_sway * sway_d * 0.2 + s_wave * 0.5, 0)
		draw_line(t2_base, t2_tip, hair_base_col, twid * 0.5)
		# Tertiary wisp between main tufts
		if h % 2 == 0:
			var ha3 = ha + 0.2
			var t3_base = head_center + Vector2.from_angle(ha3) * 9.0
			var t3_tip = t3_base + Vector2.from_angle(ha3) * (tlen * 0.35) + Vector2(hair_sway * 0.15, 0)
			draw_line(t3_base, t3_tip, Color(hair_hi_col.r, hair_hi_col.g, hair_hi_col.b, 0.5), twid * 0.35)
	# Rakish fringe — strands falling across forehead
	for fri in range(3):
		var fr_x = -3.0 + float(fri) * 2.5
		var fr_base = head_center + Vector2(fr_x, -8.5)
		var fr_wave = sin(_time * 2.0 + float(fri) * 1.3) * 0.8
		var fr_tip = fr_base + Vector2(fr_wave, 6.0 + float(fri) * 0.8)
		draw_line(fr_base, fr_tip, hair_mid_col, 1.4 - float(fri) * 0.15)
		# Fringe highlight
		draw_line(fr_base, fr_base.lerp(fr_tip, 0.6), hair_hi_col, 0.7)

	# Face (strong masculine shape)
	draw_circle(head_center + Vector2(0, 0.8), 9.1, skin_base)
	# Strong jawline — defined angular lines from ears to squared chin
	draw_line(head_center + Vector2(-8.5, 1), head_center + Vector2(-5, 7.5), Color(0.65, 0.48, 0.35, 0.35), 1.5)
	draw_line(head_center + Vector2(8.5, 1), head_center + Vector2(5, 7.5), Color(0.65, 0.48, 0.35, 0.35), 1.5)
	# Under-cheekbone shadow arcs (angular definition)
	draw_arc(head_center + Vector2(-5.5, 1.8), 4.0, PI * 0.1, PI * 0.55, 8, Color(0.62, 0.44, 0.32, 0.2), 1.2)
	draw_arc(head_center + Vector2(5.5, 1.8), 4.0, PI * 0.45, PI * 0.9, 8, Color(0.62, 0.44, 0.32, 0.2), 1.2)
	# Cheekbone highlight arcs
	draw_arc(head_center + Vector2(-5.0, 0.6), 3.5, PI * 1.15, PI * 1.6, 8, Color(0.96, 0.82, 0.68, 0.25), 1.0)
	draw_arc(head_center + Vector2(5.0, 0.6), 3.5, PI * 1.4, PI * 1.85, 8, Color(0.96, 0.82, 0.68, 0.25), 1.0)
	# Chin — squared, masculine with cleft
	draw_line(head_center + Vector2(-5, 7.5), head_center + Vector2(5, 7.5), Color(0.65, 0.48, 0.35, 0.25), 1.2)
	draw_circle(head_center + Vector2(0, 7.5), 3.0, skin_base)
	draw_circle(head_center + Vector2(0, 7.8), 2.2, skin_highlight)
	# Chin cleft
	draw_line(head_center + Vector2(0, 7.0), head_center + Vector2(0, 8.2), Color(0.65, 0.48, 0.35, 0.2), 0.8)
	draw_circle(head_center + Vector2(0, 7.5), 0.6, Color(0.72, 0.54, 0.42, 0.15))
	# Slight weathering (outdoor skin)
	draw_arc(head_center + Vector2(0, 0), 7.1, PI * 0.7, PI * 1.3, 10, Color(0.82, 0.66, 0.50, 0.15), 2.0)

	# Ears (partially visible under hair/cap)
	# Right ear
	var r_ear = head_center + Vector2(8.7, -0.8)
	draw_circle(r_ear, 2.4, skin_base)
	draw_circle(r_ear + Vector2(0.4, 0), 1.6, Color(0.88, 0.68, 0.55, 0.5))
	draw_arc(r_ear, 2.0, -0.5, 1.0, 6, skin_shadow, 0.8)
	# Left ear
	var l_ear = head_center + Vector2(-8.7, -0.8)
	draw_circle(l_ear, 2.4, skin_base)
	draw_circle(l_ear + Vector2(-0.4, 0), 1.6, Color(0.88, 0.68, 0.55, 0.5))
	draw_arc(l_ear, 2.0, PI - 0.5, PI + 1.0, 6, skin_shadow, 0.8)

	# Short stubbly beard / 5 o'clock shadow on jawline
	var stubble_c = head_center + Vector2(0, 4.7)
	draw_arc(stubble_c, 4.7, 0.3, PI - 0.3, 10, Color(0.40, 0.26, 0.16, 0.2), 2.0)
	# Individual stubble dots — dense coverage across jaw area
	for sti in range(12):
		var st_a = 0.35 + float(sti) * (PI - 0.7) / 11.0
		var st_r = 3.6 + sin(float(sti) * 2.1) * 0.9
		var st_pos = stubble_c + Vector2.from_angle(st_a) * st_r
		draw_circle(st_pos, 0.4, Color(0.38, 0.24, 0.14, 0.25))
	for sti in range(9):
		var st_a = 0.45 + float(sti) * (PI - 0.9) / 8.0
		var st_r = 2.8 + cos(float(sti) * 1.8) * 0.6
		var st_pos = stubble_c + Vector2.from_angle(st_a) * st_r
		draw_circle(st_pos, 0.3, Color(0.36, 0.22, 0.12, 0.2))
	# Extra stubble along jawline edges
	for sti in range(6):
		var jx = -5.0 + float(sti) * 2.0
		var jy = 6.5 + sin(float(sti) * 1.5) * 0.5
		draw_circle(head_center + Vector2(jx, jy), 0.35, Color(0.38, 0.24, 0.14, 0.18))
	# Chin stubble (thicker patch)
	draw_arc(head_center + Vector2(0, 7.1), 2.4, 0.5, PI - 0.5, 6, Color(0.38, 0.24, 0.14, 0.22), 1.5)
	# Extra chin dots
	for ci in range(4):
		var cx = -1.0 + float(ci) * 0.7
		draw_circle(head_center + Vector2(cx, 7.6 + sin(float(ci)) * 0.4), 0.3, Color(0.36, 0.22, 0.12, 0.2))

	# Green eyes that track aim direction (scaled for smaller head)
	var look_dir = dir * 1.2
	var l_eye = head_center + Vector2(-3.9, -0.8)
	var r_eye = head_center + Vector2(3.9, -0.8)
	# Eye socket shadow
	draw_circle(l_eye, 4.3, Color(0.72, 0.56, 0.44, 0.25))
	draw_circle(r_eye, 4.3, Color(0.72, 0.56, 0.44, 0.25))
	# Eye whites
	draw_circle(l_eye, 3.9, Color(0.96, 0.96, 0.98))
	draw_circle(r_eye, 3.9, Color(0.96, 0.96, 0.98))
	# Green irises (following aim)
	draw_circle(l_eye + look_dir, 2.5, Color(0.10, 0.42, 0.15))
	draw_circle(l_eye + look_dir, 2.0, Color(0.16, 0.58, 0.22))
	draw_circle(l_eye + look_dir, 1.4, Color(0.22, 0.65, 0.28))
	draw_circle(r_eye + look_dir, 2.5, Color(0.10, 0.42, 0.15))
	draw_circle(r_eye + look_dir, 2.0, Color(0.16, 0.58, 0.22))
	draw_circle(r_eye + look_dir, 1.4, Color(0.22, 0.65, 0.28))
	# Limbal ring (gold-green)
	draw_arc(l_eye + look_dir, 2.4, 0, TAU, 10, Color(0.55, 0.48, 0.12, 0.25), 0.5)
	draw_arc(r_eye + look_dir, 2.4, 0, TAU, 10, Color(0.55, 0.48, 0.12, 0.25), 0.5)
	# Iris radial detail (Phantom-style ring detail)
	for iri in range(8):
		var ir_a = TAU * float(iri) / 8.0
		var ir_v = Vector2.from_angle(ir_a)
		draw_line(l_eye + look_dir + ir_v * 0.5, l_eye + look_dir + ir_v * 1.5, Color(0.14, 0.48, 0.18, 0.25), 0.4)
		draw_line(r_eye + look_dir + ir_v * 0.5, r_eye + look_dir + ir_v * 1.5, Color(0.14, 0.48, 0.18, 0.25), 0.4)
	# Inner iris ring (bright green)
	draw_arc(l_eye + look_dir, 1.0, 0, TAU, 10, Color(0.30, 0.70, 0.35, 0.3), 0.4)
	draw_arc(r_eye + look_dir, 1.0, 0, TAU, 10, Color(0.30, 0.70, 0.35, 0.3), 0.4)
	# Pupils
	draw_circle(l_eye + look_dir * 1.15, 1.2, Color(0.05, 0.05, 0.07))
	draw_circle(r_eye + look_dir * 1.15, 1.2, Color(0.05, 0.05, 0.07))
	# Primary highlight (big sparkle — boosted)
	draw_circle(l_eye + Vector2(-0.9, -1.2), 1.3, Color(1.0, 1.0, 1.0, 0.92))
	draw_circle(r_eye + Vector2(-0.9, -1.2), 1.3, Color(1.0, 1.0, 1.0, 0.92))
	# Secondary highlight (boosted)
	draw_circle(l_eye + Vector2(1.2, 0.4), 0.7, Color(1.0, 1.0, 1.0, 0.55))
	draw_circle(r_eye + Vector2(1.2, 0.4), 0.7, Color(1.0, 1.0, 1.0, 0.55))
	# Tertiary green glint highlight
	draw_circle(l_eye + Vector2(0.5, -1.5), 0.35, Color(0.6, 1.0, 0.7, 0.3))
	draw_circle(r_eye + Vector2(0.5, -1.5), 0.35, Color(0.6, 1.0, 0.7, 0.3))
	# Keen archer glint (focused green)
	var glint_t = sin(_time * 2.0) * 0.2
	draw_circle(l_eye + Vector2(0.4, -0.4), 0.4, Color(0.3, 0.8, 0.4, 0.2 + glint_t))
	draw_circle(r_eye + Vector2(0.4, -0.4), 0.4, Color(0.3, 0.8, 0.4, 0.2 + glint_t))
	# Upper eyelids (slightly narrowed — focused look)
	draw_arc(l_eye, 3.9, PI + 0.25, TAU - 0.25, 8, Color(0.38, 0.22, 0.10), 1.3)
	draw_arc(r_eye, 3.9, PI + 0.25, TAU - 0.25, 8, Color(0.38, 0.22, 0.10), 1.3)
	# Eyelashes (subtle — masculine but defined)
	for el in range(2):
		var ela = PI + 0.45 + float(el) * 0.65
		draw_line(l_eye + Vector2.from_angle(ela) * 3.9, l_eye + Vector2.from_angle(ela) * 5.1, Color(0.35, 0.20, 0.10, 0.4), 0.6)
		draw_line(r_eye + Vector2.from_angle(ela) * 3.9, r_eye + Vector2.from_angle(ela) * 5.1, Color(0.35, 0.20, 0.10, 0.4), 0.6)
	# Lower eyelid line
	draw_arc(l_eye, 3.6, 0.3, PI - 0.3, 8, Color(0.50, 0.38, 0.28, 0.25), 0.5)
	draw_arc(r_eye, 3.6, 0.3, PI - 0.3, 8, Color(0.50, 0.38, 0.28, 0.25), 0.5)

	# Eyebrows — bold, one slightly cocked (roguish confidence)
	# Left brow (arched higher — cocky raised brow)
	draw_line(l_eye + Vector2(-3.2, -4.3), l_eye + Vector2(0, -5.1), Color(0.40, 0.24, 0.12), 1.8)
	draw_line(l_eye + Vector2(0, -5.1), l_eye + Vector2(2.8, -3.9), Color(0.40, 0.24, 0.12), 1.3)
	# Right brow (slightly lower — asymmetric for character)
	draw_line(r_eye + Vector2(-2.8, -3.9), r_eye + Vector2(0, -4.7), Color(0.40, 0.24, 0.12), 1.8)
	draw_line(r_eye + Vector2(0, -4.7), r_eye + Vector2(3.2, -3.6), Color(0.40, 0.24, 0.12), 1.3)
	# Brow hair texture
	for bhi in range(3):
		var bht = float(bhi) / 2.0
		var bh_l = (l_eye + Vector2(-2.8, -4.3)).lerp(l_eye + Vector2(2.4, -4.3), bht)
		draw_line(bh_l, bh_l + Vector2(0.4, -0.6), Color(0.42, 0.28, 0.14, 0.35), 0.5)
		var bh_r = (r_eye + Vector2(-2.4, -3.9)).lerp(r_eye + Vector2(2.8, -3.9), bht)
		draw_line(bh_r, bh_r + Vector2(-0.4, -0.6), Color(0.42, 0.28, 0.14, 0.35), 0.5)

	# Nose (strong, slightly aquiline — handsome rogue)
	draw_circle(head_center + Vector2(0, 2.8), 1.6, skin_highlight)
	draw_circle(head_center + Vector2(0.2, 3.0), 1.2, Color(0.92, 0.76, 0.62))
	# Nose bridge highlight
	draw_line(head_center + Vector2(0, 0), head_center + Vector2(0, 2.4), Color(0.94, 0.80, 0.66, 0.3), 0.7)
	# Nostrils
	draw_circle(head_center + Vector2(-0.9, 3.3), 0.5, Color(0.55, 0.40, 0.30, 0.4))
	draw_circle(head_center + Vector2(0.9, 3.3), 0.5, Color(0.55, 0.40, 0.30, 0.4))
	# Nose shadow (side)
	draw_line(head_center + Vector2(-0.8, 1.2), head_center + Vector2(-0.9, 2.8), Color(0.62, 0.45, 0.32, 0.25), 0.6)

	# Cheek blush (weathered outdoorsman)
	draw_circle(head_center + Vector2(-5.5, 2.4), 2.8, Color(0.90, 0.55, 0.45, 0.15))
	draw_circle(head_center + Vector2(5.5, 2.4), 2.8, Color(0.90, 0.55, 0.45, 0.15))

	# Confident cocky smirk (wider, more dashing)
	draw_arc(head_center + Vector2(0.6, 5.4), 4.8, 0.15, PI - 0.35, 14, Color(0.58, 0.28, 0.20), 1.6)
	# Teeth showing (flash of white behind smirk)
	for thi in range(4):
		var tooth_x = -1.5 + float(thi) * 1.1
		draw_circle(head_center + Vector2(tooth_x, 5.6), 0.6, Color(0.98, 0.96, 0.92))
	# Asymmetric smirk upturn (right side curves up more — deeply cocky)
	draw_line(head_center + Vector2(4.0, 4.8), head_center + Vector2(5.8, 3.4), Color(0.58, 0.28, 0.20, 0.55), 1.2)
	# Lower lip subtle definition
	draw_arc(head_center + Vector2(0.4, 5.8), 3.2, 0.3, PI - 0.5, 8, Color(0.72, 0.42, 0.32, 0.15), 0.8)
	# Dimple at smirk corner (deeper)
	draw_circle(head_center + Vector2(5.6, 3.8), 0.9, Color(0.78, 0.56, 0.44, 0.4))
	draw_circle(head_center + Vector2(-4.5, 5.0), 0.9, Color(0.78, 0.56, 0.44, 0.28))
	# Laugh lines (slight, adds character to weathered face)
	draw_arc(head_center + Vector2(-3.9, 2.0), 3.2, PI * 0.5, PI * 0.85, 4, Color(0.65, 0.48, 0.35, 0.1), 0.5)
	draw_arc(head_center + Vector2(3.9, 2.0), 3.2, PI * 0.15, PI * 0.5, 4, Color(0.65, 0.48, 0.35, 0.1), 0.5)

	# === Robin Hood feathered cap/hood ===
	var hat_base = head_center + Vector2(0, -7)
	var hat_tip = hat_base + Vector2(12, -16)
	# Hat shape (pointed like classic Robin Hood cap, slightly structured)
	var hat_pts = PackedVector2Array([
		hat_base + Vector2(-9.5, 2),
	])
	# Curved brim
	for hbi in range(5):
		var ht = float(hbi) / 4.0
		var brim_pos = hat_base + Vector2(-9.5 + ht * 19.0, 2.0 + sin(ht * PI) * 2.4)
		hat_pts.append(brim_pos)
	hat_pts.append(hat_tip)
	draw_colored_polygon(hat_pts, Color(0.16, 0.44, 0.10))
	# Hat depth shading (darker left side)
	var hat_shade = PackedVector2Array([
		hat_base + Vector2(-8, 1),
		hat_base + Vector2(3, 1),
		hat_tip + Vector2(-2, 1),
	])
	draw_colored_polygon(hat_shade, Color(0.12, 0.36, 0.06, 0.4))
	# Hat highlight (right side catches light)
	var hat_hl = PackedVector2Array([
		hat_base + Vector2(3, 1),
		hat_base + Vector2(9.5, 1),
		hat_tip + Vector2(1, -1),
	])
	draw_colored_polygon(hat_hl, Color(0.22, 0.54, 0.16, 0.2))
	# Hat brim line
	draw_line(hat_base + Vector2(-10, 2), hat_base + Vector2(10, 2), Color(0.12, 0.36, 0.06), 3.0)
	draw_line(hat_base + Vector2(-10, 2.5), hat_base + Vector2(10, 2.5), Color(0.22, 0.48, 0.14), 1.8)
	# Hat band (thin darker band above brim)
	draw_line(hat_base + Vector2(-9.5, 0), hat_base + Vector2(9.5, 0), Color(0.10, 0.30, 0.06), 2.0)
	draw_line(hat_base + Vector2(-9, -0.5), hat_base + Vector2(9, -0.5), Color(0.14, 0.36, 0.08, 0.5), 1.0)
	# Hat fold/crease lines
	draw_line(hat_base + Vector2(2, 0), hat_tip + Vector2(-1, 1), Color(0.10, 0.30, 0.06, 0.45), 0.8)
	draw_line(hat_base + Vector2(-3, 0), hat_tip + Vector2(-3, 3), Color(0.10, 0.30, 0.06, 0.3), 0.7)
	# Hat outline
	draw_line(hat_base + Vector2(-9.5, 2), hat_tip, Color(0.10, 0.28, 0.05, 0.45), 0.8)
	draw_line(hat_base + Vector2(9.5, 2), hat_tip, Color(0.10, 0.28, 0.05, 0.45), 0.8)
	# Tip of hat (droops slightly)
	draw_circle(hat_tip, 1.8, Color(0.14, 0.40, 0.08))
	draw_circle(hat_tip, 1.1, Color(0.18, 0.46, 0.12))

	# Red feather on hat (classic Robin Hood detail — extended 15%)
	var feather_bob = sin(_time * 3.0) * 1.5
	var feather_base = hat_base + Vector2(6, -1)
	var feather_tip = feather_base + Vector2(18.5, -12.5 + feather_bob)
	var feather_mid = feather_base + (feather_tip - feather_base) * 0.5
	# Quill (rachis)
	draw_line(feather_base, feather_tip, Color(0.72, 0.10, 0.06), 2.0)
	# Feather body (red plume — wider)
	draw_line(feather_base + (feather_tip - feather_base) * 0.1, feather_tip - (feather_tip - feather_base) * 0.05, Color(0.88, 0.16, 0.08), 5.0)
	draw_line(feather_mid, feather_tip, Color(0.92, 0.22, 0.12), 3.5)
	# Feather barbs (diagonal lines off spine — 9 barbs)
	var f_d = (feather_tip - feather_base).normalized()
	var f_p = f_d.rotated(PI / 2.0)
	for fbi in range(9):
		var bt = 0.08 + float(fbi) * 0.10
		var barb_o = feather_base + (feather_tip - feather_base) * bt
		var blen = 4.0 - abs(float(fbi) - 4.0) * 0.35
		draw_line(barb_o, barb_o + f_p * blen + f_d * 1.2, Color(0.85, 0.14, 0.06, 0.8), 0.9)
		draw_line(barb_o, barb_o - f_p * blen + f_d * 1.2, Color(0.85, 0.14, 0.06, 0.8), 0.9)
	# Feather shine
	draw_line(feather_mid + f_p * 0.3, feather_mid + f_d * 5.0, Color(0.95, 0.40, 0.30, 0.35), 1.0)
	# Feather tip sway
	draw_line(feather_tip, feather_tip + f_p * sin(_time * 3.0) * 2.0 + f_d * 2.5, Color(0.85, 0.18, 0.10, 0.4), 1.0)
	# Quill base (white)
	draw_circle(feather_base, 1.0, Color(0.92, 0.88, 0.78))

	# Tier 4: Golden feather overlaid
	if upgrade_tier >= 4:
		var gold_tip = feather_base + Vector2(18, -13 + feather_bob)
		draw_line(feather_base, gold_tip, Color(1.0, 0.85, 0.2), 2.5)
		draw_line(feather_base, gold_tip, Color(1.0, 0.95, 0.5, 0.35), 1.0)
		var gf_d = (gold_tip - feather_base).normalized()
		var gf_p = gf_d.rotated(PI / 2.0)
		for gbi in range(6):
			var gbt = 0.1 + float(gbi) * 0.14
			var gb_o = feather_base + (gold_tip - feather_base) * gbt
			var gb_scale = 1.0 - gbt * 0.25
			draw_line(gb_o, gb_o + gf_p * 3.0 * gb_scale + gf_d * 1.0, Color(1.0, 0.9, 0.35, 0.7), 1.2 * gb_scale)
			draw_line(gb_o, gb_o - gf_p * 2.5 * gb_scale + gf_d * 0.8, Color(0.9, 0.75, 0.2, 0.5), 0.8 * gb_scale)
		# Gold feather glow
		var gf_glow = 0.1 + sin(_time * 3.0) * 0.05
		draw_circle(feather_base.lerp(gold_tip, 0.5), 5.0, Color(1.0, 0.9, 0.3, gf_glow))

	# === Tier 4: Golden-green aura around whole character ===
	if upgrade_tier >= 4:
		var aura_pulse = sin(_time * 2.5) * 5.0
		draw_circle(body_offset, 60.0 + aura_pulse, Color(0.4, 0.8, 0.3, 0.04))
		draw_circle(body_offset, 50.0 + aura_pulse * 0.6, Color(0.5, 0.85, 0.35, 0.06))
		draw_circle(body_offset, 42.0 + aura_pulse * 0.3, Color(1.0, 0.90, 0.4, 0.06))
		draw_arc(body_offset, 56.0 + aura_pulse, 0, TAU, 32, Color(0.4, 0.8, 0.35, 0.15), 2.5)
		draw_arc(body_offset, 46.0 + aura_pulse * 0.5, 0, TAU, 24, Color(1.0, 0.90, 0.4, 0.08), 1.8)
		# Orbiting golden-green sparkles
		for gs in range(6):
			var gs_a = _time * (0.7 + float(gs % 3) * 0.25) + float(gs) * TAU / 6.0
			var gs_r = 46.0 + aura_pulse + float(gs % 3) * 3.5
			var gs_p = body_offset + Vector2.from_angle(gs_a) * gs_r
			var gs_size = 1.3 + sin(_time * 3.0 + float(gs) * 1.5) * 0.6
			var gs_alpha = 0.3 + sin(_time * 3.0 + float(gs)) * 0.18
			draw_circle(gs_p, gs_size, Color(0.5, 0.9, 0.4, gs_alpha))

	# === 21. AWAITING ABILITY CHOICE INDICATOR ===
	if awaiting_ability_choice:
		var pulse = (sin(_time * 4.0) + 1.0) * 0.5
		draw_circle(Vector2.ZERO, 68.0 + pulse * 6.0, Color(0.3, 0.7, 0.2, 0.1 + pulse * 0.1))
		draw_arc(Vector2.ZERO, 68.0 + pulse * 6.0, 0, TAU, 32, Color(0.3, 0.7, 0.2, 0.3 + pulse * 0.3), 2.5)
		var font3 = ThemeDB.fallback_font
		draw_string(font3, Vector2(-16, -80), "!", HORIZONTAL_ALIGNMENT_CENTER, 32, 30, Color(0.3, 0.7, 0.2, 0.7 + pulse * 0.3))

	# === 22. DAMAGE COUNTER ===
	if damage_dealt > 0:
		var font = ThemeDB.fallback_font
		var dmg_text = str(int(damage_dealt)) + " DMG"
		if stat_upgrade_level > 0:
			dmg_text += " • Lv." + str(stat_upgrade_level)
		draw_string(font, Vector2(-36, 56), dmg_text, HORIZONTAL_ALIGNMENT_LEFT, 160, 12, Color(1.0, 0.84, 0.0, 0.5))

	# === 23. UPGRADE NAME FLASH ===
	if _upgrade_flash > 0.0 and _upgrade_name != "":
		var font2 = ThemeDB.fallback_font
		draw_string(font2, Vector2(-80, -72), _upgrade_name, HORIZONTAL_ALIGNMENT_CENTER, 160, 16, Color(0.3, 0.7, 0.2, min(_upgrade_flash, 1.0)))

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
