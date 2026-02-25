extends Node2D
## Robin Hood — long-range archer tower. Upgrades by dealing damage ("Rob the Rich").
## Tier 1 (5000 DMG): Splitting the Wand — fire 2 arrows per attack
## Tier 2 (10000 DMG): The Silver Arrow — every 10th shot deals 3x damage
## Tier 3 (15000 DMG): Three Blasts of the Horn — 3 sky arrows every other wave, insta-kill
## Tier 4 (20000 DMG): The Final Arrow — splash damage (40px), +50% gold, double pierce

# Base stats
var damage: float = 25.0
var fire_rate: float = 0.52
var attack_range: float = 160.0
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
var silver_interval: int = 10

# Tier 2: Silver arrow screen flash
var _silver_flash: float = 0.0

# Tier 3: Three Blasts of the Horn — sky arrows
var _horn_flash: float = 0.0

# Tier 4: Gold arrow flash
var _gold_flash: float = 0.0

# Kill tracking — steal coins every 10th kill
var kill_count: int = 0

# Tier 3: Sky arrows — every 10 waves
var _sky_arrows_active: Array = []
var _sky_arrow_spawn_timer: float = 0.0
var _sky_arrows_last_trigger_wave: int = -1
var _sky_arrow_flash: float = 0.0

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
	"Every 15s, arrows rain on enemies within 2.5x range"
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
var _king_sherwood_timer: float = 15.0
# Visual flash timers
var _merry_men_flash: float = 0.0
var _little_john_flash: float = 0.0
var _golden_arrow_flash: float = 0.0
var _king_sherwood_flash: float = 0.0
var _friar_tuck_flash: float = 0.0
var _maid_marian_flash: float = 0.0
var _outlaw_snare_flash: float = 0.0
var _outlaw_snare_pos: Vector2 = Vector2.ZERO

const STAT_UPGRADE_INTERVAL: float = 4000.0
const ABILITY_THRESHOLD: float = 12000.0
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
	"Fire 2 arrows per attack",
	"Every 10th arrow is silver — pierces 5 enemies",
	"3 sky arrows every other round — insta-kill on landing",
	"Silver becomes gold — pierces 10 enemies, splash damage"
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
	_silver_flash = max(_silver_flash - delta * 3.0, 0.0)
	_gold_flash = max(_gold_flash - delta * 3.0, 0.0)
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

	# Sky arrow spawn timer
	if _sky_arrow_spawn_timer > 0.0:
		_sky_arrow_spawn_timer -= delta
		if _sky_arrow_spawn_timer <= 0.0:
			_spawn_sky_arrows()

	# Update sky arrows
	_update_sky_arrows(delta)

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

func _find_second_target(exclude: Node2D) -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist: float = attack_range * _range_mult()
	for enemy in enemies:
		if enemy == exclude:
			continue
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
	var gold = upgrade_tier >= 4 and silver
	_fire_arrow(target, silver, gold)
	# Tier 1+: Dual shot — fire second arrow at next nearest enemy
	if upgrade_tier >= 1:
		var second = _find_second_target(target)
		if not second:
			second = target
		shot_count += 1
		var silver2 = upgrade_tier >= 2 and shot_count % silver_interval == 0
		var gold2 = upgrade_tier >= 4 and silver2
		_fire_arrow(second, silver2, gold2)

func _fire_arrow(t: Node2D, silver: bool = false, gold: bool = false) -> void:
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
	if gold:
		arrow.pierce_count = 10
		arrow.is_gold = true
		arrow.is_silver = false
		_gold_flash = 1.0
	elif silver:
		arrow.pierce_count = 5
		arrow.is_silver = true
		_silver_flash = 0.8
	else:
		arrow.pierce_count = 0
		arrow.is_silver = false
	arrow.splash_radius = 40.0 if upgrade_tier >= 4 else 0.0
	# Ability 1: Sherwood Aim — 30% faster arrows
	if prog_abilities[0]:
		arrow.speed *= 1.3
	var main_node = get_tree().get_first_node_in_group("main")
	if main_node:
		main_node.add_child(arrow)

func register_kill() -> void:
	kill_count += 1
	if kill_count % 10 == 0:
		var stolen = int((5 + kill_count / 10) * _gold_mult())
		var main = get_tree().get_first_node_in_group("main")
		if main:
			main.add_gold(stolen)
		_upgrade_flash = 1.0
		_upgrade_name = "Robbed %d gold!" % stolen

func on_wave_start(wave_num: int) -> void:
	# Sky arrows: every other wave
	if upgrade_tier >= 3 and wave_num % 2 == 0 and wave_num != _sky_arrows_last_trigger_wave:
		_sky_arrows_last_trigger_wave = wave_num
		_sky_arrow_spawn_timer = 2.0  # 2s delay so enemies are on field

func _spawn_sky_arrows() -> void:
	if _horn_player and not _is_sfx_muted(): _horn_player.play()
	_sky_arrow_flash = 1.0
	_horn_flash = 1.0
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.size() == 0:
		return
	var shuffled = enemies.duplicate()
	shuffled.shuffle()
	var count = mini(3, shuffled.size())
	for i in range(count):
		if not is_instance_valid(shuffled[i]):
			continue
		_sky_arrows_active.append({
			"phase": 0,  # 0=ascending, 1=descending
			"timer": 0.0,
			"ascend_time": 0.8,
			"descend_time": 0.6,
			"start_pos": global_position + Vector2(float(i - 1) * 15.0, 0),
			"peak_pos": global_position + Vector2(float(i - 1) * 15.0, -150.0),
			"target": shuffled[i],
			"pos": global_position + Vector2(float(i - 1) * 15.0, 0),
			"trail": []
		})

func _update_sky_arrows(delta: float) -> void:
	_sky_arrow_flash = max(_sky_arrow_flash - delta * 1.5, 0.0)
	var to_remove: Array = []
	for si in range(_sky_arrows_active.size()):
		var arrow = _sky_arrows_active[si]
		arrow["timer"] += delta
		if arrow["phase"] == 0:
			# Ascending
			var t_norm = arrow["timer"] / arrow["ascend_time"]
			arrow["pos"] = arrow["start_pos"].lerp(arrow["peak_pos"], clampf(t_norm, 0.0, 1.0))
			# Add trail point
			arrow["trail"].append(arrow["pos"])
			if arrow["trail"].size() > 10:
				arrow["trail"].pop_front()
			if t_norm >= 1.0:
				arrow["phase"] = 1
				arrow["timer"] = 0.0
		elif arrow["phase"] == 1:
			# Descending toward target
			var t_norm = arrow["timer"] / arrow["descend_time"]
			if is_instance_valid(arrow["target"]):
				var target_pos = arrow["target"].global_position
				arrow["pos"] = arrow["peak_pos"].lerp(target_pos, clampf(t_norm, 0.0, 1.0))
				arrow["trail"].append(arrow["pos"])
				if arrow["trail"].size() > 10:
					arrow["trail"].pop_front()
				if t_norm >= 1.0:
					# Impact — insta-kill
					if arrow["target"].has_method("take_damage"):
						var dmg = arrow["target"].health + 1.0
						arrow["target"].take_damage(dmg, true)
						register_damage(dmg)
					if is_instance_valid(arrow["target"]):
						register_kill()
					to_remove.append(si)
			else:
				to_remove.append(si)
	for ri in range(to_remove.size() - 1, -1, -1):
		_sky_arrows_active.remove_at(to_remove[ri])

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
	damage += 3.0
	fire_rate += 0.04
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
		1: # Splitting the Wand — dual shot
			damage = 33.0
			fire_rate = 0.65
			attack_range = 176.0
		2: # The Silver Arrow — every 10th arrow, pierces 5
			damage = 43.0
			fire_rate = 0.78
			attack_range = 192.0
			gold_bonus = 3
		3: # Three Blasts of the Horn — sky arrows every other wave
			damage = 50.0
			fire_rate = 0.91
			attack_range = 216.0
			gold_bonus = 4
		4: # The Final Arrow — gold arrow, pierces 10, splash 40px
			damage = 65.0
			fire_rate = 1.04
			attack_range = 240.0
			gold_bonus = 6

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
	_check_upgrades()

func _process_progressive_abilities(delta: float) -> void:
	# Visual flash decay
	_merry_men_flash = max(_merry_men_flash - delta * 2.0, 0.0)
	_little_john_flash = max(_little_john_flash - delta * 2.0, 0.0)
	_golden_arrow_flash = max(_golden_arrow_flash - delta * 1.5, 0.0)
	_king_sherwood_flash = max(_king_sherwood_flash - delta * 2.0, 0.0)
	_friar_tuck_flash = max(_friar_tuck_flash - delta * 1.5, 0.0)
	_maid_marian_flash = max(_maid_marian_flash - delta * 1.5, 0.0)
	_outlaw_snare_flash = max(_outlaw_snare_flash - delta * 1.0, 0.0)

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
			_friar_tuck_flash = 1.0
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

	# Ability 9: King of Sherwood — rain arrows on enemies in 2.5x range
	if prog_abilities[8]:
		_king_sherwood_timer -= delta
		if _king_sherwood_timer <= 0.0:
			_king_sherwood_rain()
			_king_sherwood_timer = 15.0

func _merry_men_attack() -> void:
	_merry_men_flash = 1.0
	var enemies = get_tree().get_nodes_in_group("enemies")
	var in_range: Array = []
	for e in enemies:
		if global_position.distance_to(e.global_position) < attack_range * _range_mult():
			in_range.append(e)
	in_range.shuffle()
	for i in range(mini(3, in_range.size())):
		if is_instance_valid(in_range[i]) and in_range[i].has_method("take_damage"):
			var dmg = damage * 3.0 * _damage_mult()
			in_range[i].take_damage(dmg)
			register_damage(dmg)

func _little_john_stun() -> void:
	_little_john_flash = 1.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) < attack_range * _range_mult():
			if e.has_method("apply_sleep"):
				e.apply_sleep(1.5)

func _outlaw_snare() -> void:
	# Root nearest enemy for 3s
	var nearest = _find_nearest_enemy()
	if nearest and nearest.has_method("apply_slow"):
		nearest.apply_slow(0.0, 3.0)  # factor 0 = complete stop
		_outlaw_snare_flash = 1.0
		_outlaw_snare_pos = nearest.global_position - global_position

func _maid_marian_strike() -> void:
	# Heal 1 life
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("restore_life"):
		main.restore_life(1)
	_maid_marian_flash = 1.0
	# Strike strongest enemy in range
	var strongest: Node2D = null
	var most_hp: float = 0.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) < attack_range * _range_mult():
			if e.health > most_hp:
				most_hp = e.health
				strongest = e
	if strongest and strongest.has_method("take_damage"):
		var dmg = damage * 5.0 * _damage_mult()
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
					var dmg = damage * 10.0 * _damage_mult()
					e.take_damage(dmg)
					register_damage(dmg)

func _king_sherwood_rain() -> void:
	_king_sherwood_flash = 1.0
	var rain_range = attack_range * _range_mult() * 2.5
	# Deal 1.5x damage to enemies within 2.5x range
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) < rain_range and e.has_method("take_damage"):
			var dmg = damage * 1.5 * _damage_mult()
			e.take_damage(dmg)
			register_damage(dmg)

func _draw() -> void:
	# === 1. SELECTION RING ===
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


	# === SILVER ARROW FLASH (T2) ===
	if _silver_flash > 0.0:
		var sr_r = 30.0 + (1.0 - _silver_flash) * 60.0
		draw_arc(Vector2.ZERO, sr_r, 0, TAU, 32, Color(0.85, 0.88, 0.95, _silver_flash * 0.4), 3.0)
		draw_arc(Vector2.ZERO, sr_r * 0.6, 0, TAU, 24, Color(0.9, 0.92, 1.0, _silver_flash * 0.25), 2.0)
		draw_circle(Vector2.ZERO, sr_r * 0.3, Color(0.85, 0.88, 0.95, _silver_flash * 0.1))

	# === GOLD ARROW FLASH (T4) ===
	if _gold_flash > 0.0:
		for gi in range(3):
			var gr = 20.0 + (1.0 - _gold_flash) * (50.0 + float(gi) * 30.0)
			var ga = _gold_flash * (0.5 - float(gi) * 0.12)
			draw_arc(Vector2.ZERO, gr, 0, TAU, 32, Color(1.0, 0.85, 0.3, ga), 2.5)
		draw_circle(Vector2.ZERO, 15.0 * _gold_flash, Color(1.0, 0.95, 0.5, _gold_flash * 0.15))

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

	# === HORN VOLLEY READY GLOW (T3) ===
	if upgrade_tier >= 3 and _horn_flash <= 0.0 and _sky_arrows_active.size() == 0:
		var ready_pulse = (sin(_time * 2.5) + 1.0) * 0.5
		draw_arc(Vector2.ZERO, 38.0 + ready_pulse * 4.0, 0, TAU, 32, Color(0.2, 0.8, 0.2, 0.08 + ready_pulse * 0.06), 2.0)
		draw_circle(Vector2.ZERO, 34.0, Color(0.2, 0.8, 0.2, 0.03 + ready_pulse * 0.02))

	# === SKY ARROWS VISUAL ===
	for sky_arrow in _sky_arrows_active:
		var sa_pos = sky_arrow["pos"] - global_position
		var sa_trail = sky_arrow["trail"]
		# Trail
		for ti in range(sa_trail.size() - 1):
			var tp1 = sa_trail[ti] - global_position
			var tp2 = sa_trail[ti + 1] - global_position
			var ta = float(ti) / float(sa_trail.size())
			draw_line(tp1, tp2, Color(1.0, 0.85, 0.3, ta * 0.4), 2.0)
		# Arrow head
		draw_circle(sa_pos, 5.0, Color(1.0, 0.9, 0.3, 0.8))
		draw_circle(sa_pos, 3.0, Color(1.0, 1.0, 0.6, 0.6))
		# Fire glow when descending
		if sky_arrow["phase"] == 1:
			draw_circle(sa_pos, 8.0, Color(1.0, 0.5, 0.1, 0.3))
			draw_circle(sa_pos, 12.0, Color(1.0, 0.3, 0.05, 0.15))

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

	# Ability 4: Friar Tuck's Blessing — green healing glow
	if _friar_tuck_flash > 0.0:
		var ft_pulse = clampf(sin(_time * 6.0) * 0.5 + 0.5, 0.0, 1.0)
		var ft_r = 25.0 + (1.0 - _friar_tuck_flash) * 30.0
		draw_circle(Vector2.ZERO, ft_r, Color(0.2, 0.9, 0.3, _friar_tuck_flash * 0.12))
		draw_arc(Vector2.ZERO, ft_r, 0, TAU, 24, Color(0.2, 0.9, 0.3, _friar_tuck_flash * (0.3 + ft_pulse * 0.15)), 2.5)
		draw_arc(Vector2.ZERO, ft_r * 0.6, 0, TAU, 16, Color(0.3, 1.0, 0.4, _friar_tuck_flash * 0.2), 1.5)

	# Ability 5: Little John's Staff flash
	if _little_john_flash > 0.0:
		var lj_r = 30.0 + (1.0 - _little_john_flash) * 50.0
		draw_arc(Vector2.ZERO, lj_r, 0, TAU, 24, Color(0.6, 0.4, 0.2, _little_john_flash * 0.4), 3.0)
		draw_arc(Vector2.ZERO, lj_r * 0.6, 0, TAU, 16, Color(0.5, 0.35, 0.15, _little_john_flash * 0.3), 2.0)

	# Ability 6: Outlaw's Snare — brown rope trap on the ground
	if _outlaw_snare_flash > 0.0:
		var sn_a = _outlaw_snare_flash * 0.8
		var sn_pos = _outlaw_snare_pos
		draw_circle(sn_pos, 12.0, Color(0.45, 0.30, 0.12, sn_a * 0.25))
		draw_arc(sn_pos, 12.0, 0, TAU, 16, Color(0.55, 0.35, 0.15, sn_a * 0.6), 2.0)
		# Cross-hatched rope net
		for ni in range(4):
			var na = TAU * float(ni) / 4.0
			var np1 = sn_pos + Vector2.from_angle(na) * 10.0
			var np2 = sn_pos + Vector2.from_angle(na + PI) * 10.0
			draw_line(np1, np2, Color(0.50, 0.32, 0.14, sn_a * 0.5), 1.5)
		# Outer ring knots
		for ki in range(6):
			var ka = TAU * float(ki) / 6.0
			var kp = sn_pos + Vector2.from_angle(ka) * 11.0
			draw_circle(kp, 2.0, Color(0.50, 0.32, 0.14, sn_a * 0.5))

	# Ability 7: Maid Marian's Arrow — green healing glow
	if _maid_marian_flash > 0.0:
		var mm_pulse = clampf(sin(_time * 5.0) * 0.5 + 0.5, 0.0, 1.0)
		var mm_r = 20.0 + (1.0 - _maid_marian_flash) * 25.0
		draw_circle(Vector2.ZERO, mm_r, Color(0.3, 0.95, 0.4, _maid_marian_flash * 0.1))
		draw_arc(Vector2.ZERO, mm_r, 0, TAU, 24, Color(0.3, 0.95, 0.4, _maid_marian_flash * (0.25 + mm_pulse * 0.15)), 2.0)
		# Small cross/plus for healing indicator
		var cx = Vector2.ZERO
		draw_line(cx + Vector2(-5, 0), cx + Vector2(5, 0), Color(0.3, 1.0, 0.4, _maid_marian_flash * 0.5), 2.0)
		draw_line(cx + Vector2(0, -5), cx + Vector2(0, 5), Color(0.3, 1.0, 0.4, _maid_marian_flash * 0.5), 2.0)

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

	# === 12. CHARACTER POSITIONS (chibi Bloons TD proportions ~48px) ===
	var feet_y = body_offset + Vector2(hip_shift * 1.0, 10.0)
	var leg_top = body_offset + Vector2(hip_shift * 0.6, 0.0)
	var torso_center = body_offset + Vector2(shoulder_counter * 0.5, -8.0)
	var neck_base = body_offset + Vector2(shoulder_counter * 0.7, -14.0)
	var head_center = body_offset + Vector2(shoulder_counter * 0.3, -26.0)
	var OL = Color(0.06, 0.06, 0.08)

	# === 13. TIER-SPECIFIC EFFECTS (drawn BEFORE/AROUND body) ===

	# Tier 1+: Green leaf particles swirling around feet
	if upgrade_tier >= 1:
		for li in range(5 + upgrade_tier):
			var la = _time * (0.6 + fmod(float(li) * 1.37, 0.5)) + float(li) * TAU / float(5 + upgrade_tier)
			var lr = 20.0 + fmod(float(li) * 3.7, 12.0)
			var leaf_pos = body_offset + Vector2(cos(la) * lr, sin(la) * lr * 0.5 + 8.0)
			var leaf_alpha = 0.25 + sin(_time * 2.0 + float(li)) * 0.1
			var leaf_size = 1.8 + sin(_time * 1.5 + float(li) * 2.0) * 0.5
			draw_circle(leaf_pos, leaf_size, Color(0.2, 0.6, 0.15, leaf_alpha))

	# Tier 2+: Silver shimmer on bow area
	if upgrade_tier >= 2:
		var silver_pulse = (sin(_time * 2.8) + 1.0) * 0.5
		for spi in range(4):
			var sp_seed = float(spi) * 2.13
			var sp_a = _time * 1.2 + sp_seed
			var sp_r = 14.0 + sin(_time * 1.5 + sp_seed) * 4.0
			var sp_pos = body_offset + Vector2(10.0 + cos(sp_a) * sp_r, sin(sp_a) * sp_r * 0.4)
			var sp_alpha = 0.18 + silver_pulse * 0.12
			draw_circle(sp_pos, 1.5, Color(0.85, 0.88, 0.95, sp_alpha))

	# Tier 4: Fiery arrow particles floating around
	if upgrade_tier >= 4:
		for fd in range(6):
			var fd_seed = float(fd) * 2.37
			var fd_angle = _time * (0.5 + fmod(fd_seed, 0.5)) + fd_seed
			var fd_radius = 26.0 + fmod(fd_seed * 5.3, 20.0)
			var fd_pos = body_offset + Vector2(cos(fd_angle) * fd_radius, sin(fd_angle) * fd_radius * 0.6)
			var fd_alpha = 0.3 + sin(_time * 3.0 + fd_seed * 2.0) * 0.15
			var fd_size = 2.0 + sin(_time * 2.5 + fd_seed) * 0.6
			var fire_t = fmod(fd_seed * 1.7, 1.0)
			draw_circle(fd_pos, fd_size, Color(1.0, 0.5 + fire_t * 0.4, 0.1, fd_alpha))
			draw_circle(fd_pos, fd_size * 0.5, Color(1.0, 0.9, 0.4, fd_alpha * 0.6))

	# === 14. CHARACTER BODY (Bloons TD cartoon style) ===

	# --- Colors ---
	var tunic_green = Color(0.15, 0.55, 0.12)
	var tunic_dark = Color(0.10, 0.40, 0.08)
	var boot_brown = Color(0.45, 0.28, 0.12)
	var belt_brown = Color(0.40, 0.24, 0.10)
	var hair_auburn = Color(0.50, 0.28, 0.12)
	var hair_dark = Color(0.38, 0.20, 0.08)

	# --- BOOTS ---
	var l_foot = feet_y + Vector2(-5, 0)
	var r_foot = feet_y + Vector2(5, 0)
	draw_circle(l_foot, 5.0, OL)
	draw_circle(l_foot, 3.8, boot_brown)
	draw_circle(r_foot, 5.0, OL)
	draw_circle(r_foot, 3.8, boot_brown)
	# Boot highlights
	draw_circle(l_foot + Vector2(0, -1), 2.0, Color(0.55, 0.36, 0.18, 0.4))
	draw_circle(r_foot + Vector2(0, -1), 2.0, Color(0.55, 0.36, 0.18, 0.4))
	# Boot cuffs
	draw_line(l_foot + Vector2(-4, -3), l_foot + Vector2(4, -3), OL, 3.5)
	draw_line(l_foot + Vector2(-3.5, -3), l_foot + Vector2(3.5, -3), Color(0.55, 0.36, 0.18), 2.0)
	draw_line(r_foot + Vector2(-4, -3), r_foot + Vector2(4, -3), OL, 3.5)
	draw_line(r_foot + Vector2(-3.5, -3), r_foot + Vector2(3.5, -3), Color(0.55, 0.36, 0.18), 2.0)

	# --- LEGS (short thick lines) ---
	var l_hip = leg_top + Vector2(-4, 0)
	var r_hip = leg_top + Vector2(4, 0)
	draw_line(l_foot + Vector2(0, -3), l_hip, OL, 7.0)
	draw_line(l_foot + Vector2(0, -3), l_hip, tunic_green, 5.0)
	draw_line(r_foot + Vector2(0, -3), r_hip, OL, 7.0)
	draw_line(r_foot + Vector2(0, -3), r_hip, tunic_green, 5.0)
	# Knee joints
	var l_knee = l_foot.lerp(l_hip, 0.5)
	var r_knee = r_foot.lerp(r_hip, 0.5)
	draw_circle(l_knee, 3.5, OL)
	draw_circle(l_knee, 2.5, tunic_green)
	draw_circle(r_knee, 3.5, OL)
	draw_circle(r_knee, 2.5, tunic_green)

	# --- CAPE (behind body) ---
	var cape_wind = sin(_time * 1.8) * 2.5
	draw_colored_polygon(PackedVector2Array([
		neck_base + Vector2(-7, -1), neck_base + Vector2(7, -1),
		torso_center + Vector2(10 + cape_wind * 0.3, 10),
		torso_center + Vector2(-10 + cape_wind * 0.5, 8),
	]), OL)
	draw_colored_polygon(PackedVector2Array([
		neck_base + Vector2(-5.5, 0), neck_base + Vector2(5.5, 0),
		torso_center + Vector2(8.5 + cape_wind * 0.3, 9),
		torso_center + Vector2(-8.5 + cape_wind * 0.5, 7),
	]), tunic_dark)

	# --- QUIVER on back ---
	var quiver_pos = neck_base + Vector2(-6, 3)
	draw_colored_polygon(PackedVector2Array([
		quiver_pos + Vector2(-4, 5), quiver_pos + Vector2(4, 5),
		quiver_pos + Vector2(3, -12), quiver_pos + Vector2(-3, -12),
	]), OL)
	draw_colored_polygon(PackedVector2Array([
		quiver_pos + Vector2(-2.8, 3.8), quiver_pos + Vector2(2.8, 3.8),
		quiver_pos + Vector2(2, -10.8), quiver_pos + Vector2(-2, -10.8),
	]), Color(0.48, 0.30, 0.14))
	# Quiver rim
	draw_line(quiver_pos + Vector2(-3.5, -12), quiver_pos + Vector2(3.5, -12), OL, 3.0)
	draw_line(quiver_pos + Vector2(-3, -12), quiver_pos + Vector2(3, -12), Color(0.55, 0.38, 0.18), 1.8)
	# Strap across chest
	draw_line(quiver_pos + Vector2(2, -6), torso_center + Vector2(6, 1), OL, 3.5)
	draw_line(quiver_pos + Vector2(2, -6), torso_center + Vector2(6, 1), belt_brown, 2.0)
	# Arrows sticking out
	var arrow_count = 3 + upgrade_tier
	for ai in range(arrow_count):
		var ax = -1.5 + float(ai) * (3.0 / float(max(arrow_count - 1, 1)))
		var arrow_top = quiver_pos + Vector2(ax, -14.0 - float(ai % 2) * 2.0)
		var shaft_col = Color(0.58, 0.45, 0.25)
		if upgrade_tier >= 2 and ai == 0:
			shaft_col = Color(0.80, 0.78, 0.65)
		if upgrade_tier >= 4 and ai <= 1:
			shaft_col = Color(0.88, 0.72, 0.28)
		draw_line(quiver_pos + Vector2(ax, -11), arrow_top, OL, 2.2)
		draw_line(quiver_pos + Vector2(ax, -11), arrow_top, shaft_col, 1.2)
		var fletch_col = Color(0.75, 0.15, 0.1) if ai % 2 == 0 else Color(0.9, 0.85, 0.75)
		draw_line(arrow_top, arrow_top + Vector2(-1.5, -2), fletch_col, 1.2)
		draw_line(arrow_top, arrow_top + Vector2(1.5, -2), fletch_col, 1.2)

	# --- GREEN TUNIC BODY ---
	var tunic_pts_ol = PackedVector2Array([
		leg_top + Vector2(-8, 1), leg_top + Vector2(8, 1),
		neck_base + Vector2(11, 0), neck_base + Vector2(-11, 0),
	])
	draw_colored_polygon(tunic_pts_ol, OL)
	var tunic_pts_fill = PackedVector2Array([
		leg_top + Vector2(-6.5, 0), leg_top + Vector2(6.5, 0),
		neck_base + Vector2(9.5, 0.8), neck_base + Vector2(-9.5, 0.8),
	])
	draw_colored_polygon(tunic_pts_fill, tunic_green)
	# Tunic highlight
	draw_circle(torso_center + Vector2(-2, -2), 4.0, Color(0.22, 0.62, 0.18, 0.3))
	# V-neckline
	draw_line(neck_base + Vector2(-3, 1), neck_base + Vector2(0, 4), OL, 1.5)
	draw_line(neck_base + Vector2(3, 1), neck_base + Vector2(0, 4), OL, 1.5)
	draw_colored_polygon(PackedVector2Array([
		neck_base + Vector2(-2.5, 1), neck_base + Vector2(2.5, 1), neck_base + Vector2(0, 3.5),
	]), Color(0.78, 0.68, 0.52))
	# Scalloped hem
	for hi in range(4):
		var hx = -5.0 + float(hi) * 3.5
		var h_depth = 2.0 + sin(float(hi) * 2.1 + _time * 1.2) * 1.0
		draw_colored_polygon(PackedVector2Array([
			leg_top + Vector2(hx - 1.5, 1), leg_top + Vector2(hx + 1.5, 1),
			leg_top + Vector2(hx, 1 + h_depth),
		]), OL)
		draw_colored_polygon(PackedVector2Array([
			leg_top + Vector2(hx - 1.0, 1), leg_top + Vector2(hx + 1.0, 1),
			leg_top + Vector2(hx, 1.0 + h_depth * 0.8),
		]), tunic_green)

	# --- BELT with brass buckle ---
	draw_line(leg_top + Vector2(-8, 0), leg_top + Vector2(8, 0), OL, 5.0)
	draw_line(leg_top + Vector2(-7, 0), leg_top + Vector2(7, 0), belt_brown, 3.5)
	draw_line(leg_top + Vector2(-6, -1.2), leg_top + Vector2(6, -1.2), Color(0.52, 0.34, 0.16, 0.4), 1.0)
	# Brass buckle
	var buckle_c = leg_top
	draw_circle(buckle_c, 3.8, OL)
	draw_circle(buckle_c, 2.8, Color(0.85, 0.72, 0.28))
	draw_circle(buckle_c, 1.5, Color(0.95, 0.85, 0.40))
	draw_circle(buckle_c + Vector2(-0.5, -0.8), 0.8, Color(1.0, 1.0, 0.9, 0.5))

	# --- Tier 3+: Hunting horn on belt ---
	if upgrade_tier >= 3:
		var horn_base = leg_top + Vector2(6, 2)
		var horn_bell = horn_base + Vector2(8, 7)
		draw_line(horn_base, horn_bell, OL, 4.5)
		draw_line(horn_base, horn_bell, Color(0.80, 0.65, 0.25), 3.0)
		draw_circle(horn_bell, 3.5, OL)
		draw_circle(horn_bell, 2.5, Color(0.85, 0.70, 0.28))
		draw_circle(horn_base, 2.0, OL)
		draw_circle(horn_base, 1.2, Color(0.90, 0.78, 0.35))
		if upgrade_tier >= 4:
			draw_circle(horn_bell, 5.0, Color(1.0, 0.85, 0.3, 0.12 + sin(_time * 3.0) * 0.06))

	# --- SHOULDERS (round joints) ---
	var l_shoulder = neck_base + Vector2(-10, 0)
	var r_shoulder = neck_base + Vector2(10, 0)
	draw_circle(l_shoulder, 5.0, OL)
	draw_circle(l_shoulder, 3.8, tunic_green)
	draw_circle(r_shoulder, 5.0, OL)
	draw_circle(r_shoulder, 3.8, tunic_green)

	# --- BOW ARM (right) — extends toward aim direction ---
	var bow_hand = r_shoulder + dir * 18.0
	var bow_elbow = r_shoulder + (bow_hand - r_shoulder) * 0.45
	# Upper arm: outline then fill
	draw_line(r_shoulder, bow_elbow, OL, 6.5)
	draw_line(r_shoulder, bow_elbow, tunic_green, 4.5)
	# Elbow joint
	draw_circle(bow_elbow, 3.5, OL)
	draw_circle(bow_elbow, 2.5, tunic_green)
	# Forearm: outline then fill
	draw_line(bow_elbow, bow_hand, OL, 6.5)
	draw_line(bow_elbow, bow_hand, skin_base, 4.5)
	# Bow hand
	draw_circle(bow_hand, 3.8, OL)
	draw_circle(bow_hand, 2.8, skin_base)
	draw_circle(bow_hand + Vector2(0, -0.5), 1.5, skin_highlight)

	# --- DRAW ARM (left) — pulls bowstring back ---
	var string_pull_vec = dir * (-10.0 * _draw_progress)
	var draw_hand = l_shoulder + dir * 8.0 + string_pull_vec
	var draw_elbow = l_shoulder + (draw_hand - l_shoulder) * 0.45
	# Upper arm
	draw_line(l_shoulder, draw_elbow, OL, 6.5)
	draw_line(l_shoulder, draw_elbow, tunic_green, 4.5)
	# Elbow joint
	draw_circle(draw_elbow, 3.5, OL)
	draw_circle(draw_elbow, 2.5, tunic_green)
	# Forearm
	draw_line(draw_elbow, draw_hand, OL, 6.5)
	draw_line(draw_elbow, draw_hand, skin_base, 4.5)
	# Draw hand
	draw_circle(draw_hand, 3.8, OL)
	draw_circle(draw_hand, 2.8, skin_base)
	# Fingers on string
	draw_line(draw_hand, draw_hand + dir * 2.5 + perp * 1.5, OL, 2.5)
	draw_line(draw_hand, draw_hand + dir * 2.5 + perp * 1.5, skin_base, 1.5)
	draw_line(draw_hand, draw_hand + dir * 3.0, OL, 2.5)
	draw_line(draw_hand, draw_hand + dir * 3.0, skin_base, 1.5)
	draw_line(draw_hand, draw_hand + dir * 2.5 - perp * 1.5, OL, 2.5)
	draw_line(draw_hand, draw_hand + dir * 2.5 - perp * 1.5, skin_base, 1.5)

	# === 15. WEAPON — LONGBOW ===
	var bow_center = bow_hand + dir * 2.0
	var bow_top = bow_center + Vector2(0, -18.0)
	var bow_bottom = bow_center + Vector2(0, 18.0)
	var bow_curve_pt = bow_center + dir * 6.0

	# Bow limb colors (silver at tier 2+)
	var bow_wood = Color(0.48, 0.28, 0.10) if upgrade_tier < 2 else Color(0.55, 0.55, 0.58)
	var bow_light = Color(0.60, 0.38, 0.16) if upgrade_tier < 2 else Color(0.70, 0.72, 0.78)

	# Tier 2+: Silver glow along bow
	if upgrade_tier >= 2:
		var silver_p = (sin(_time * 2.8) + 1.0) * 0.5
		draw_circle(bow_curve_pt, 6.0, Color(0.8, 0.85, 0.95, 0.08 + silver_p * 0.06))

	# Bow limbs — outline then fill
	draw_line(bow_top, bow_curve_pt, OL, 5.5)
	draw_line(bow_top, bow_curve_pt, bow_light, 3.5)
	draw_line(bow_curve_pt, bow_bottom, OL, 5.5)
	draw_line(bow_curve_pt, bow_bottom, bow_light, 3.5)
	# Nock tips
	draw_circle(bow_top, 2.5, OL)
	draw_circle(bow_top, 1.5, Color(0.90, 0.88, 0.80))
	draw_circle(bow_bottom, 2.5, OL)
	draw_circle(bow_bottom, 1.5, Color(0.90, 0.88, 0.80))
	# Grip wrap
	draw_line(bow_curve_pt + Vector2(0, -3), bow_curve_pt + Vector2(0, 3), OL, 6.0)
	draw_line(bow_curve_pt + Vector2(0, -2.5), bow_curve_pt + Vector2(0, 2.5), belt_brown, 4.5)

	# Bowstring
	var string_pull_offset = dir * (-8.0 * _draw_progress)
	var vib_offset = perp * string_vib
	var string_nock_pt = bow_center + string_pull_offset + vib_offset
	draw_line(bow_top, string_nock_pt, OL, 2.0)
	draw_line(bow_bottom, string_nock_pt, OL, 2.0)
	draw_line(bow_top, string_nock_pt, Color(0.82, 0.76, 0.60), 1.0)
	draw_line(bow_bottom, string_nock_pt, Color(0.82, 0.76, 0.60), 1.0)

	# Arrow nocked on string (visible when drawing)
	if _draw_progress > 0.15:
		var arrow_nock = bow_center + string_pull_offset
		var arrow_tip = bow_center + dir * 24.0
		# Silver arrow detection
		var next_is_silver = upgrade_tier >= 2 and (shot_count + 1) % silver_interval == 0
		var next_is_gold = upgrade_tier >= 4 and next_is_silver
		var shaft_col = Color(0.58, 0.46, 0.28)
		var head_col = Color(0.50, 0.50, 0.55)
		if next_is_gold:
			shaft_col = Color(0.95, 0.85, 0.30)
			head_col = Color(1.0, 0.88, 0.25)
		elif next_is_silver:
			shaft_col = Color(0.82, 0.78, 0.55)
			head_col = Color(0.88, 0.80, 0.35)
		# Arrow shaft — outline then fill
		draw_line(arrow_nock, arrow_tip, OL, 2.5)
		draw_line(arrow_nock, arrow_tip, shaft_col, 1.5)
		# Broadhead
		var head_base = arrow_tip - dir * 3.0
		draw_colored_polygon(PackedVector2Array([
			arrow_tip, head_base + perp * 3.0, head_base - perp * 3.0,
		]), OL)
		draw_colored_polygon(PackedVector2Array([
			arrow_tip - dir * 0.5, head_base + perp * 2.0, head_base - perp * 2.0,
		]), head_col)
		# Fletching
		var fletch_start = arrow_nock + dir * 1.0
		draw_line(fletch_start + perp * 2.0, fletch_start + dir * 4.0 + perp * 1.0, Color(0.85, 0.18, 0.10), 1.5)
		draw_line(fletch_start - perp * 2.0, fletch_start + dir * 4.0 - perp * 1.0, Color(0.85, 0.85, 0.80), 1.5)
		# Silver/Gold glow
		if next_is_gold:
			var gglow = (sin(_time * 4.0) + 1.0) * 0.5
			draw_circle(arrow_tip, 5.0 + gglow * 2.0, Color(1.0, 0.90, 0.3, 0.28))
			draw_circle(arrow_tip, 3.0 + gglow, Color(1.0, 0.95, 0.5, 0.15))
		elif next_is_silver:
			var sglow = (sin(_time * 4.0) + 1.0) * 0.5
			draw_circle(arrow_tip, 4.0 + sglow * 2.0, Color(0.88, 0.90, 1.0, 0.22))
		# Tier 4: Fiery arrow tip
		if upgrade_tier >= 4:
			var ff1 = sin(_time * 8.0) * 0.5 + 0.5
			draw_circle(arrow_tip, 4.0 + ff1 * 1.5, Color(1.0, 0.4, 0.05, 0.2 + ff1 * 0.08))
			draw_circle(arrow_tip, 2.0 + ff1 * 0.5, Color(1.0, 0.7, 0.1, 0.3))
			draw_circle(arrow_tip, 1.0, Color(1.0, 0.95, 0.5, 0.35))

	# === NECK (thick cartoon connector) ===
	draw_line(neck_base, head_center + Vector2(0, 10), OL, 7.0)
	draw_line(neck_base, head_center + Vector2(0, 10), skin_base, 5.0)

	# === HEAD (big Bloons TD round head ~45% of height) ===

	# --- Auburn hair mass (back layer, behind face) ---
	var hair_sway = sin(_time * 2.5) * 1.5
	draw_circle(head_center, 14.5, OL)
	draw_circle(head_center, 13.0, hair_dark)
	draw_circle(head_center + Vector2(0, -1), 12.0, hair_auburn)
	# Messy hair tufts sticking out
	for ti in range(6):
		var ta = 0.4 + float(ti) * 0.8 + sin(_time * 1.5 + float(ti)) * 0.1
		var tuft_p = head_center + Vector2.from_angle(ta) * 12.5
		var tuft_tip = tuft_p + Vector2.from_angle(ta) * (4.0 + sin(_time * 2.0 + float(ti) * 1.5) * 1.0) + Vector2(hair_sway * 0.3, 0)
		draw_line(tuft_p, tuft_tip, OL, 3.5)
		draw_line(tuft_p, tuft_tip, hair_auburn, 2.0)
	# Side tufts at ears
	draw_circle(head_center + Vector2(-11, 3), 4.0, OL)
	draw_circle(head_center + Vector2(-11, 3), 3.0, hair_auburn)
	draw_circle(head_center + Vector2(11, 3), 4.0, OL)
	draw_circle(head_center + Vector2(11, 3), 3.0, hair_auburn)

	# --- Face (big round) ---
	draw_circle(head_center + Vector2(0, 1), 11.5, OL)
	draw_circle(head_center + Vector2(0, 1), 10.2, skin_base)
	# Face highlight
	draw_circle(head_center + Vector2(-1.5, -1), 5.0, skin_highlight)

	# --- Ears ---
	draw_circle(head_center + Vector2(-10, 0), 3.0, OL)
	draw_circle(head_center + Vector2(-10, 0), 2.0, skin_base)
	draw_circle(head_center + Vector2(10, 0), 3.0, OL)
	draw_circle(head_center + Vector2(10, 0), 2.0, skin_base)

	# --- Big cartoon eyes ---
	var look_dir = dir * 1.5
	var l_eye = head_center + Vector2(-4.0, -1.0)
	var r_eye = head_center + Vector2(4.0, -1.0)
	# Eye outlines (big Bloons size)
	draw_circle(l_eye, 5.5, OL)
	draw_circle(r_eye, 5.5, OL)
	# Eye whites
	draw_circle(l_eye, 4.5, Color(0.98, 0.98, 1.0))
	draw_circle(r_eye, 4.5, Color(0.98, 0.98, 1.0))
	# Green irises (following aim)
	draw_circle(l_eye + look_dir, 3.0, Color(0.10, 0.45, 0.15))
	draw_circle(l_eye + look_dir, 2.2, Color(0.18, 0.60, 0.22))
	draw_circle(r_eye + look_dir, 3.0, Color(0.10, 0.45, 0.15))
	draw_circle(r_eye + look_dir, 2.2, Color(0.18, 0.60, 0.22))
	# Black pupils
	draw_circle(l_eye + look_dir * 1.1, 1.4, Color(0.04, 0.04, 0.06))
	draw_circle(r_eye + look_dir * 1.1, 1.4, Color(0.04, 0.04, 0.06))
	# Big white sparkle highlights
	draw_circle(l_eye + Vector2(-1.2, -1.5), 1.5, Color(1.0, 1.0, 1.0, 0.95))
	draw_circle(r_eye + Vector2(-1.2, -1.5), 1.5, Color(1.0, 1.0, 1.0, 0.95))
	# Small secondary sparkle
	draw_circle(l_eye + Vector2(1.5, 0.8), 0.7, Color(1.0, 1.0, 1.0, 0.6))
	draw_circle(r_eye + Vector2(1.5, 0.8), 0.7, Color(1.0, 1.0, 1.0, 0.6))

	# --- Brown eyebrows (bold, one cocked for confidence) ---
	# Left brow (raised higher — cocky)
	draw_line(l_eye + Vector2(-3.5, -5.5), l_eye + Vector2(2.5, -5.0), OL, 2.8)
	draw_line(l_eye + Vector2(-3.0, -5.5), l_eye + Vector2(2.0, -5.0), hair_auburn, 1.8)
	# Right brow (slightly lower — asymmetric for character)
	draw_line(r_eye + Vector2(-2.5, -4.8), r_eye + Vector2(3.5, -4.5), OL, 2.8)
	draw_line(r_eye + Vector2(-2.0, -4.8), r_eye + Vector2(3.0, -4.5), hair_auburn, 1.8)

	# --- Nose (simple cartoon bump) ---
	draw_circle(head_center + Vector2(0, 3.0), 2.0, OL)
	draw_circle(head_center + Vector2(0, 3.0), 1.3, skin_highlight)

	# --- Confident smirk ---
	draw_arc(head_center + Vector2(0.5, 6.0), 4.0, 0.15, PI - 0.3, 10, OL, 2.0)
	draw_arc(head_center + Vector2(0.5, 6.0), 4.0, 0.2, PI - 0.35, 10, Color(0.65, 0.25, 0.18), 1.2)
	# Smirk upturn on right side
	draw_line(head_center + Vector2(4.0, 5.5), head_center + Vector2(5.2, 4.2), OL, 1.8)
	draw_line(head_center + Vector2(4.0, 5.5), head_center + Vector2(5.0, 4.4), Color(0.65, 0.25, 0.18), 1.0)
	# Flash of teeth behind smirk
	draw_arc(head_center + Vector2(0.5, 6.2), 3.0, 0.3, PI - 0.5, 8, Color(0.98, 0.96, 0.92), 1.5)

	# === FEATHERED CAP (iconic pointed hat) ===
	var hat_base = head_center + Vector2(0, -8)
	var hat_tip = hat_base + Vector2(10, -14)
	# Hat outline polygon
	draw_colored_polygon(PackedVector2Array([
		hat_base + Vector2(-11, 3), hat_base + Vector2(11, 3), hat_tip,
	]), OL)
	# Hat fill
	draw_colored_polygon(PackedVector2Array([
		hat_base + Vector2(-9.5, 2), hat_base + Vector2(9.5, 2),
		hat_tip + Vector2(-0.5, 0.8),
	]), tunic_green)
	# Hat highlight
	draw_colored_polygon(PackedVector2Array([
		hat_base + Vector2(3, 2), hat_base + Vector2(9, 2),
		hat_tip + Vector2(0, 1),
	]), Color(0.22, 0.62, 0.18, 0.35))
	# Hat brim line
	draw_line(hat_base + Vector2(-11, 3), hat_base + Vector2(11, 3), OL, 3.5)
	draw_line(hat_base + Vector2(-10, 3), hat_base + Vector2(10, 3), Color(0.12, 0.42, 0.08), 2.0)
	# Hat band
	draw_line(hat_base + Vector2(-9.5, 1), hat_base + Vector2(9.5, 1), OL, 2.5)
	draw_line(hat_base + Vector2(-9, 1), hat_base + Vector2(9, 1), tunic_dark, 1.5)
	# Tip circle
	draw_circle(hat_tip, 2.2, OL)
	draw_circle(hat_tip, 1.4, tunic_green)

	# --- Red feather on hat ---
	var feather_bob = sin(_time * 3.0) * 1.5
	var feather_base = hat_base + Vector2(5, 0)
	var feather_tip = feather_base + Vector2(16, -11 + feather_bob)
	# Feather quill: outline then fill
	draw_line(feather_base, feather_tip, OL, 3.5)
	draw_line(feather_base, feather_tip, Color(0.88, 0.16, 0.08), 2.0)
	# Feather body (wider red plume)
	draw_line(feather_base.lerp(feather_tip, 0.1), feather_tip, OL, 6.5)
	draw_line(feather_base.lerp(feather_tip, 0.12), feather_tip - (feather_tip - feather_base).normalized() * 0.5, Color(0.90, 0.18, 0.10), 4.5)
	# Feather barbs
	var f_d = (feather_tip - feather_base).normalized()
	var f_p = f_d.rotated(PI / 2.0)
	for fbi in range(6):
		var bt = 0.1 + float(fbi) * 0.14
		var barb_o = feather_base + (feather_tip - feather_base) * bt
		var blen = 3.5 - abs(float(fbi) - 2.5) * 0.4
		draw_line(barb_o, barb_o + f_p * blen, Color(0.85, 0.14, 0.06, 0.7), 1.0)
		draw_line(barb_o, barb_o - f_p * blen, Color(0.85, 0.14, 0.06, 0.7), 1.0)
	# Quill base
	draw_circle(feather_base, 1.5, OL)
	draw_circle(feather_base, 0.8, Color(0.92, 0.88, 0.78))

	# Tier 4: Golden feather overlay
	if upgrade_tier >= 4:
		var gold_tip = feather_base + Vector2(16, -12 + feather_bob)
		draw_line(feather_base, gold_tip, Color(1.0, 0.85, 0.2), 2.5)
		draw_line(feather_base, gold_tip, Color(1.0, 0.95, 0.5, 0.4), 1.2)
		draw_circle(feather_base.lerp(gold_tip, 0.5), 4.0, Color(1.0, 0.9, 0.3, 0.1 + sin(_time * 3.0) * 0.05))

	# === Tier 4: Golden-green aura around whole character ===
	if upgrade_tier >= 4:
		var aura_pulse = sin(_time * 2.5) * 4.0
		draw_circle(body_offset, 52.0 + aura_pulse, Color(0.4, 0.8, 0.3, 0.05))
		draw_circle(body_offset, 44.0 + aura_pulse * 0.6, Color(0.5, 0.85, 0.35, 0.07))
		draw_arc(body_offset, 48.0 + aura_pulse, 0, TAU, 32, Color(0.4, 0.8, 0.35, 0.15), 2.5)
		draw_arc(body_offset, 40.0 + aura_pulse * 0.5, 0, TAU, 24, Color(1.0, 0.90, 0.4, 0.08), 1.8)
		for gs in range(5):
			var gs_a = _time * (0.7 + float(gs % 3) * 0.25) + float(gs) * TAU / 5.0
			var gs_r = 40.0 + aura_pulse + float(gs % 3) * 3.0
			var gs_p = body_offset + Vector2.from_angle(gs_a) * gs_r
			var gs_size = 1.5 + sin(_time * 3.0 + float(gs) * 1.5) * 0.6
			var gs_alpha = 0.3 + sin(_time * 3.0 + float(gs)) * 0.18
			draw_circle(gs_p, gs_size, Color(0.5, 0.9, 0.4, gs_alpha))

	# === 21. AWAITING ABILITY CHOICE INDICATOR ===
	if awaiting_ability_choice:
		var pulse = (sin(_time * 4.0) + 1.0) * 0.5
		draw_circle(Vector2.ZERO, 68.0 + pulse * 6.0, Color(0.3, 0.7, 0.2, 0.1 + pulse * 0.1))
		draw_arc(Vector2.ZERO, 68.0 + pulse * 6.0, 0, TAU, 32, Color(0.3, 0.7, 0.2, 0.3 + pulse * 0.3), 2.5)
		var font3 = _game_font
		draw_string(font3, Vector2(-16, -80), "!", HORIZONTAL_ALIGNMENT_CENTER, 32, 30, Color(0.3, 0.7, 0.2, 0.7 + pulse * 0.3))

	# === 22. DAMAGE COUNTER ===
	if damage_dealt > 0:
		var font = _game_font
		var dmg_text = str(int(damage_dealt)) + " DMG"
		if stat_upgrade_level > 0:
			dmg_text += " • Lv." + str(stat_upgrade_level)
		draw_string(font, Vector2(-36, 56), dmg_text, HORIZONTAL_ALIGNMENT_LEFT, 160, 12, Color(1.0, 0.84, 0.0, 0.5))

	# === 23. UPGRADE NAME FLASH ===
	if _upgrade_flash > 0.0 and _upgrade_name != "":
		var font2 = _game_font
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
