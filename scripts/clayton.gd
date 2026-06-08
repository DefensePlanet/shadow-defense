extends Node2D
## Clayton — big game hunter from Edgar Rice Burroughs' Tarzan of the Apes (1912).
## Path A "Big Game Hunter": Safari Precision, Trophy Hunter, Elephant Gun
## Path B "Safari Arsenal": Steel Trap, Dynamite Bundle, Minefield
## Path C "Expedition Leader": Pith Helmet, Expedition Force, Heart of Darkness

# Base stats
var damage: float = 22.0
var fire_rate: float = 0.70
var attack_range: float = 180.0
var fire_cooldown: float = 0.0
var aim_angle: float = 0.0
var sprite_texture: Texture2D = null
# Flair animation (idle poses — randomized every 8s)
var flair_textures: Array = []  # Injected by main.gd
var _sprite_attack: Texture2D = null  # Attack pose, injected by main.gd
var _sprite_shoot: Texture2D = null   # Post-attack pose (follow-through), injected by main.gd
var _flair_timer: float = 0.0
var _flair_active: float = 0.0  # > 0 = showing flair
var _flair_current: Texture2D = null
const _FLAIR_INTERVAL: float = 8.0
const _FLAIR_DURATION: float = 1.5
var target: Node2D = null
var gold_bonus: int = 1

# Targeting priority: 0=First, 1=Last, 2=Close, 3=Strong
var targeting_priority: int = 0

# Animation timers
var _time: float = 0.0
var _build_timer: float = 0.0
var _attack_anim: float = 0.0

# Damage tracking and upgrades
# Gear visual slots (set by main.gd when gear equipped)
var gear_crown: Dictionary = {}
var gear_amulet: Dictionary = {}
var gear_bracelet: Dictionary = {}
var gear_weapon: Dictionary = {}
var gear_ring: Dictionary = {}
var skin_id: String = "default"
var damage_dealt: float = 0.0
var upgrade_tier: int = 0
var _upgrade_flash: float = 0.0
var _upgrade_name: String = ""

var _home_position: Vector2 = Vector2.ZERO

# Kill tracking
var kill_count: int = 0

# Path A: Big Game Hunter
var _crit_chance: float = 0.0
var _trophy_gold_mult: float = 1.0
var _elephant_gun_timer: float = 15.0
var _elephant_gun_flash: float = 0.0

# Path B: Safari Arsenal
var _steel_trap_timer: float = 15.0
var _steel_trap_flash: float = 0.0
var _dynamite_timer: float = 18.0
var _dynamite_flash: float = 0.0
var _minefield_active: bool = false
var _mine_positions: Array = []

# Path C: Expedition Leader
var _damage_reduction: float = 0.0
var _expedition_timer: float = 20.0
var _expedition_flash: float = 0.0
var _fear_aura_active: bool = false

# Net Snare (prog ability)
var _net_snare_timer: float = 12.0
var _net_snare_flash: float = 0.0

# === PROGRESSIVE ABILITIES (9 tiers, unlocked via lifetime damage) ===
const PROG_ABILITY_NAMES = [
	"Safari Precision", "Pith Helmet", "Steel Trap", "Net Snare",
	"Dynamite Bundle", "Trophy Hunter", "Expedition Force",
	"Elephant Gun", "Heart of Darkness"
]
const PROG_ABILITY_DESCS = [
	"+25% rifle dmg, +10% speed",
	"20% less damage taken",
	"Every 15s, trap roots next enemy 3s",
	"Every 12s, net traps 2 enemies 2s",
	"Every 18s, explosion hits all in range 3x",
	"Bonus 2x gold from boss kills",
	"Every 20s, 3 porters march and strike 3x",
	"Every 15s, massive shot deals 8x to strongest",
	"Permanent fear aura: all enemies in range 50% slower"
]
var prog_abilities: Array = [false, false, false, false, false, false, false, false, false]
# Ability timers
var _prog_trap_timer: float = 15.0
var _prog_net_timer: float = 12.0
var _prog_dynamite_timer: float = 18.0
var _prog_expedition_timer: float = 20.0
var _prog_elephant_timer: float = 15.0
# Visual flash timers
var _prog_trap_flash: float = 0.0
var _prog_net_flash: float = 0.0
var _prog_dynamite_flash: float = 0.0
var _prog_expedition_flash: float = 0.0
var _prog_elephant_flash: float = 0.0

const MAX_STAT_LEVEL: int = 10  # Cap stat scaling to prevent infinite power creep
const STAT_UPGRADE_INTERVAL: float = 8000.0
const ABILITY_THRESHOLD: float = 28000.0
var stat_upgrade_level: int = 0
var ability_chosen: bool = false
var awaiting_ability_choice: bool = false
const TIER_NAMES = [
	"Safari Precision",
	"Steel Trap",
	"Dynamite Bundle",
	"Trophy Hunter",
	"Heart of Darkness"
]
const ABILITY_DESCRIPTIONS = [
	"+25% rifle damage, +10% attack speed",
	"Every 15s, trap roots the next enemy for 3s",
	"Every 18s, explosion hits all enemies in range for 3x",
	"Bonus 2x gold from boss kills, marked enemies +20% dmg",
	"Permanent fear aura: all enemies in range 50% slower"
]
const TIER_COSTS = [140, 325, 600, 1100, 1800]
var is_selected: bool = false
var base_cost: int = 0

# Attack sounds — sharp rifle crack
var _attack_sounds: Array = []
var _attack_sounds_by_tier: Array = []
var _attack_player: AudioStreamPlayer

# Ability sounds
var _upgrade_sound: AudioStreamWAV
var _upgrade_player: AudioStreamPlayer
var _rifle_crack_sound: AudioStreamWAV
var _rifle_crack_player: AudioStreamPlayer
var _game_font: Font
var _main_node: Node2D = null

func _ready() -> void:
	_main_node = get_tree().get_first_node_in_group("main")
	_game_font = preload("res://fonts/Cinzel.ttf")
	add_to_group("towers")
	_home_position = global_position
	_load_progressive_abilities()
	_generate_tier_sounds()
	_attack_sounds = _attack_sounds_by_tier[0]
	_attack_player = AudioStreamPlayer.new()
	_attack_player.stream = _attack_sounds[0]
	_attack_player.volume_db = -14.0
	add_child(_attack_player)

	# Heavy rifle crack — sharp gunshot with echo
	var rc_rate := 44100
	var rc_dur := 0.6
	var rc_samples := PackedFloat32Array()
	rc_samples.resize(int(rc_rate * rc_dur))
	for i in rc_samples.size():
		var t := float(i) / rc_rate
		var s := 0.0
		# Sharp crack onset
		var crack := exp(-t * 80.0) * 0.5
		s += (randf() * 2.0 - 1.0) * crack
		# Low boom body
		var boom := sin(TAU * 80.0 * t) * exp(-t * 8.0) * 0.3
		s += boom
		# Tail echo/reverb
		var echo := sin(TAU * 120.0 * t) * exp(-t * 4.0) * 0.15
		s += echo
		rc_samples[i] = clampf(s, -1.0, 1.0)
	_rifle_crack_sound = _samples_to_wav(rc_samples, rc_rate)
	_rifle_crack_player = AudioStreamPlayer.new()
	_rifle_crack_player.stream = _rifle_crack_sound
	_rifle_crack_player.volume_db = -12.0
	add_child(_rifle_crack_player)

	# Upgrade chime — military snare roll into brass note
	var up_rate := 22050
	var up_dur := 0.35
	var up_samples := PackedFloat32Array()
	up_samples.resize(int(up_rate * up_dur))
	var up_notes := [392.0, 493.88, 587.33]  # G4, B4, D5 (major)
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
	_upgrade_player.volume_db = -10.0
	add_child(_upgrade_player)

func _process(delta: float) -> void:
	delta = minf(delta, 0.05)  # Cap to prevent physics spikes
	_time += delta
	if _build_timer > 0.0: _build_timer -= delta
	fire_cooldown -= delta
	_upgrade_flash = max(_upgrade_flash - delta * 0.5, 0.0)
	_attack_anim = max(_attack_anim - delta * 3.0, 0.0)
	_elephant_gun_flash = max(_elephant_gun_flash - delta * 2.0, 0.0)
	_steel_trap_flash = max(_steel_trap_flash - delta * 2.0, 0.0)
	_dynamite_flash = max(_dynamite_flash - delta * 1.5, 0.0)
	_expedition_flash = max(_expedition_flash - delta * 1.5, 0.0)
	_net_snare_flash = max(_net_snare_flash - delta * 2.0, 0.0)

	# Store home position if not set
	if _home_position == Vector2.ZERO and global_position != Vector2.ZERO:
		_home_position = global_position

	# Flair animation: random idle pose every 8s when no enemies
	if _flair_active > 0.0:
		_flair_active -= delta
	elif flair_textures.size() > 0 and not target:
		_flair_timer += delta
		if _flair_timer >= _FLAIR_INTERVAL:
			_flair_timer = 0.0
			_flair_current = flair_textures[randi() % flair_textures.size()]
			_flair_active = _FLAIR_DURATION
	if target:
		_flair_timer = 0.0
		_flair_active = 0.0
	target = _find_nearest_enemy()

	if target:
		var desired = global_position.angle_to_point(target.global_position) + PI
		aim_angle = lerp_angle(aim_angle, desired, 8.0 * delta)
		if fire_cooldown <= 0.0:
			_attack()
			fire_cooldown = maxf(1.0 / (fire_rate * _speed_mult()), 0.15)
			_attack_anim = 1.0

	# Path B: Steel Trap
	if upgrade_tier >= 2:
		_steel_trap_timer -= delta
		if _steel_trap_timer <= 0.0 and _has_enemies_in_range():
			_steel_trap_root()
			_steel_trap_timer = 15.0

	# Path B: Dynamite Bundle
	if upgrade_tier >= 3:
		_dynamite_timer -= delta
		if _dynamite_timer <= 0.0 and _has_enemies_in_range():
			_dynamite_explosion()
			_dynamite_timer = 18.0

	# Path A: Elephant Gun
	if upgrade_tier >= 5:
		_elephant_gun_timer -= delta
		if _elephant_gun_timer <= 0.0 and _has_enemies_in_range():
			_elephant_gun_shot()
			_elephant_gun_timer = 15.0

	# Path C: Expedition Force
	if upgrade_tier >= 4:
		_expedition_timer -= delta
		if _expedition_timer <= 0.0 and _has_enemies_in_range():
			_expedition_force_strike()
			_expedition_timer = 20.0

	# Fear aura — continuous slow
	if _fear_aura_active:
		var eff_range = attack_range * _range_mult()
		for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
			if global_position.distance_to(e.global_position) < eff_range:
				if e.has_method("apply_slow"):
					e.apply_slow(0.50, 0.5)

	# Progressive abilities
	_process_progressive_abilities(delta)

	# Active ability cooldown
	if not active_ability_ready:
		active_ability_cooldown -= delta
		if active_ability_cooldown <= 0.0:
			active_ability_ready = true
			active_ability_cooldown = 0.0

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

	var eff_damage = damage * _damage_mult()

	# Crit chance (Path A)
	if _crit_chance > 0.0 and randf() < _crit_chance:
		eff_damage *= 2.0

	if target.has_method("take_damage"):
		target.take_damage(eff_damage)
		register_damage(eff_damage)
		var hp_before = target.health if "health" in target else 0.0
		if hp_before <= eff_damage:
			register_kill()

func _steel_trap_root() -> void:
	_steel_trap_flash = 1.0
	# Root the nearest enemy for 3s
	var nearest = _find_nearest_enemy()
	if nearest and nearest.has_method("apply_sleep"):
		nearest.apply_sleep(3.0)

func _dynamite_explosion() -> void:
	_dynamite_flash = 1.0
	if _rifle_crack_player and not _is_sfx_muted():
		_rifle_crack_player.play()
	var eff_range = attack_range * _range_mult()
	var eff_damage = damage * 3.0 * _damage_mult()
	for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if global_position.distance_to(e.global_position) < eff_range:
			if e.has_method("take_damage"):
				e.take_damage(eff_damage)
				register_damage(eff_damage)
	if is_instance_valid(_main_node):
		_main_node.trigger_camera_shake(6.0, 0.3)

func _elephant_gun_shot() -> void:
	_elephant_gun_flash = 1.0
	if _rifle_crack_player and not _is_sfx_muted():
		_rifle_crack_player.play()
	# Find strongest enemy
	var strongest: Node2D = null
	var most_hp: float = 0.0
	for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if global_position.distance_to(e.global_position) < attack_range * _range_mult():
			var hp = e.health if "health" in e else 0.0
			if hp > most_hp:
				most_hp = hp
				strongest = e
	if strongest and strongest.has_method("take_damage"):
		var eff_damage = damage * 8.0 * _damage_mult()
		strongest.take_damage(eff_damage)
		register_damage(eff_damage)
		# Pierce through 3 enemies in a line
		var dir = (strongest.global_position - global_position).normalized()
		var pierce_count = 0
		for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
			if e == strongest:
				continue
			if pierce_count >= 3:
				break
			# Check if enemy is roughly in the shot line
			var to_e = e.global_position - global_position
			var proj = to_e.dot(dir)
			if proj > 0 and to_e.length() < attack_range * _range_mult():
				var perp_dist = absf(to_e.cross(dir))
				if perp_dist < 40.0:
					e.take_damage(eff_damage * 0.5)
					register_damage(eff_damage * 0.5)
					pierce_count += 1
	if is_instance_valid(_main_node):
		_main_node.spawn_floating_text(global_position + Vector2(0, -40), "ELEPHANT GUN!", Color(0.7, 0.5, 0.2), 16.0, 1.5)

func _expedition_force_strike() -> void:
	_expedition_flash = 1.0
	var eff_damage = damage * 3.0 * _damage_mult()
	var enemies_in_range: Array = []
	for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if global_position.distance_to(e.global_position) < attack_range * _range_mult():
			enemies_in_range.append(e)
	enemies_in_range.shuffle()
	# 3 porters each strike one enemy
	for i in range(mini(3, enemies_in_range.size())):
		var e = enemies_in_range[i]
		if is_instance_valid(e) and e.has_method("take_damage"):
			e.take_damage(eff_damage)
			register_damage(eff_damage)

func register_kill() -> void:
	kill_count += 1
	_upgrade_flash = 0.3

func register_damage(amount: float) -> void:
	damage_dealt += amount
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("register_tower_damage"):
		main.register_tower_damage(main.TowerType.CLAYTON, amount)
	_check_upgrades()

func _check_upgrades() -> void:
	var new_level = int(damage_dealt / STAT_UPGRADE_INTERVAL)
	while stat_upgrade_level < new_level and stat_upgrade_level < MAX_STAT_LEVEL:
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
	damage += 1.8
	fire_rate += 0.012
	attack_range += 5.0

func choose_ability(index: int) -> void:
	ability_chosen = true
	awaiting_ability_choice = false
	upgrade_tier = index + 1
	_apply_upgrade(upgrade_tier)
	_upgrade_flash = 3.0
	_upgrade_name = TIER_NAMES[index]

func _apply_upgrade(tier: int) -> void:
	match tier:
		1: # Safari Precision — +25% rifle dmg, +10% speed
			damage = 27.5
			fire_rate = 0.77
			attack_range = 185.0
		2: # Steel Trap — root enemies
			damage = 32.0
			fire_rate = 0.82
			attack_range = 190.0
			gold_bonus = 2
		3: # Dynamite Bundle — AoE explosion
			damage = 38.0
			fire_rate = 0.88
			attack_range = 195.0
			gold_bonus = 2
		4: # Trophy Hunter — boss gold + marked damage
			_trophy_gold_mult = 2.0
			_crit_chance = 0.20
			damage = 45.0
			fire_rate = 0.95
			attack_range = 200.0
			gold_bonus = 3
		5: # Heart of Darkness — permanent fear aura
			_fear_aura_active = true
			damage = 52.0
			fire_rate = 1.0
			attack_range = 210.0
			gold_bonus = 3

func apply_path_upgrade(path: String, tier: int) -> void:
	match path:
		"A":
			match tier:
				1: # Safari Precision — +25% rifle dmg, +10% speed
					damage *= 1.25
					fire_rate *= 1.10
				2: # Trophy Hunter — 2x gold bosses + marked +20%
					_trophy_gold_mult = 2.0
					_crit_chance = 0.20
				3: # Elephant Gun — 8x shot pierces 3 + 20% crit/15s
					pass  # Timer handled in _process
		"B":
			match tier:
				1: # Steel Trap — root 3s/15s
					pass  # Timer handled in _process
				2: # Dynamite Bundle — AoE 3x/18s
					pass  # Timer handled in _process
				3: # Minefield — 5 mines 4x each + traps chain
					_minefield_active = true
		"C":
			match tier:
				1: # Pith Helmet — 20% less dmg
					_damage_reduction = 0.20
				2: # Expedition Force — 3 porters 3x/20s
					pass  # Timer handled in _process
				3: # Heart of Darkness — fear aura: 50% slower permanently
					_fear_aura_active = true
	_upgrade_flash = 3.0

func purchase_upgrade() -> bool:
	if upgrade_tier >= TIER_COSTS.size():
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
	return "Clayton"

func get_next_upgrade_info() -> Dictionary:
	if upgrade_tier >= TIER_COSTS.size():
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
	var mix_rate := 44100
	var melody := [293.66, 329.63, 349.23, 392.00, 349.23, 329.63, 293.66, 261.63]
	# D4 E4 F4 G4 F4 E4 D4 C4 — military march-like melody
	_attack_sounds_by_tier = []
	for tier in range(5):
		var tier_sounds: Array = []
		var dur := 0.35 + tier * 0.04
		var vol := 0.30 + tier * 0.02
		for note_idx in melody.size():
			var freq: float = melody[note_idx]
			var total := int(mix_rate * dur)
			var samples := PackedFloat32Array()
			samples.resize(total)
			var rng := RandomNumberGenerator.new()
			rng.seed = note_idx * 3200 + tier * 500
			for i in total:
				var t := float(i) / float(mix_rate)
				var env := minf(t * 35.0, 1.0) * exp(-t * 3.5)
				# Sharp percussive attack + sustained tone
				var crack := exp(-t * 50.0) * 0.2
				var s := sin(t * freq * TAU) * 0.35
				s += sin(t * freq * 2.0 * TAU) * 0.1
				s += rng.randf_range(-1.0, 1.0) * crack
				samples[i] = clampf(s * env * vol, -1.0, 1.0)
			var att_len := mini(int(0.005 * mix_rate), total)
			for i in att_len:
				samples[i] *= float(i) / float(att_len)
			var rel_start := maxi(total - int(0.02 * mix_rate), 0)
			for i in range(rel_start, total):
				samples[i] *= 1.0 - float(i - rel_start) / float(total - rel_start)
			tier_sounds.append(_samples_to_wav(samples, mix_rate))
		_attack_sounds_by_tier.append(tier_sounds)

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
	if main and main.survivor_progress.has(main.TowerType.CLAYTON):
		var p = main.survivor_progress[main.TowerType.CLAYTON]
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
	if prog_abilities[0]:  # Safari Precision: +25% damage, +10% speed applied in _damage_mult/_speed_mult
		pass
	if prog_abilities[1]:  # Pith Helmet: 20% less damage taken
		_damage_reduction = 0.20
	if prog_abilities[8]:  # Heart of Darkness: fear aura
		_fear_aura_active = true

func get_progressive_ability_name(index: int) -> String:
	if index >= 0 and index < PROG_ABILITY_NAMES.size():
		return PROG_ABILITY_NAMES[index]
	return ""

func get_progressive_ability_desc(index: int) -> String:
	if index >= 0 and index < PROG_ABILITY_DESCS.size():
		return PROG_ABILITY_DESCS[index]
	return ""

func absorb_damage(incoming: float) -> float:
	if _damage_reduction > 0.0:
		return incoming * (1.0 - _damage_reduction)
	return incoming

func _process_progressive_abilities(delta: float) -> void:
	# Visual flash decay
	_prog_trap_flash = max(_prog_trap_flash - delta * 2.0, 0.0)
	_prog_net_flash = max(_prog_net_flash - delta * 2.0, 0.0)
	_prog_dynamite_flash = max(_prog_dynamite_flash - delta * 1.5, 0.0)
	_prog_expedition_flash = max(_prog_expedition_flash - delta * 1.5, 0.0)
	_prog_elephant_flash = max(_prog_elephant_flash - delta * 2.0, 0.0)

	# Ability 3: Steel Trap — root next enemy 3s every 15s
	if prog_abilities[2]:
		_prog_trap_timer -= delta
		if _prog_trap_timer <= 0.0 and _has_enemies_in_range():
			_prog_trap_flash = 1.0
			var nearest = _find_nearest_enemy()
			if nearest and nearest.has_method("apply_sleep"):
				nearest.apply_sleep(3.0)
			_prog_trap_timer = 15.0

	# Ability 4: Net Snare — trap 2 enemies 2s every 12s
	if prog_abilities[3]:
		_prog_net_timer -= delta
		if _prog_net_timer <= 0.0 and _has_enemies_in_range():
			_prog_net_flash = 1.0
			var enemies_in_range: Array = []
			for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
				if global_position.distance_to(e.global_position) < attack_range * _range_mult():
					enemies_in_range.append(e)
			enemies_in_range.shuffle()
			for i in range(mini(2, enemies_in_range.size())):
				if is_instance_valid(enemies_in_range[i]) and enemies_in_range[i].has_method("apply_sleep"):
					enemies_in_range[i].apply_sleep(2.0)
			_prog_net_timer = 12.0

	# Ability 5: Dynamite Bundle — explosion hits all in range 3x every 18s
	if prog_abilities[4]:
		_prog_dynamite_timer -= delta
		if _prog_dynamite_timer <= 0.0 and _has_enemies_in_range():
			_prog_dynamite_flash = 1.0
			var eff_damage = damage * 3.0 * _damage_mult()
			for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
				if global_position.distance_to(e.global_position) < attack_range * _range_mult():
					if e.has_method("take_damage"):
						e.take_damage(eff_damage)
						register_damage(eff_damage)
			if is_instance_valid(_main_node):
				_main_node.trigger_camera_shake(5.0, 0.3)
			_prog_dynamite_timer = 18.0

	# Ability 7: Expedition Force — 3 porters march and strike 3x every 20s
	if prog_abilities[6]:
		_prog_expedition_timer -= delta
		if _prog_expedition_timer <= 0.0 and _has_enemies_in_range():
			_prog_expedition_flash = 1.0
			var eff_damage = damage * 3.0 * _damage_mult()
			var enemies_in_range: Array = []
			for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
				if global_position.distance_to(e.global_position) < attack_range * _range_mult():
					enemies_in_range.append(e)
			enemies_in_range.shuffle()
			for i in range(mini(3, enemies_in_range.size())):
				if is_instance_valid(enemies_in_range[i]) and enemies_in_range[i].has_method("take_damage"):
					enemies_in_range[i].take_damage(eff_damage)
					register_damage(eff_damage)
			_prog_expedition_timer = 20.0

	# Ability 8: Elephant Gun — massive shot deals 8x to strongest every 15s
	if prog_abilities[7]:
		_prog_elephant_timer -= delta
		if _prog_elephant_timer <= 0.0 and _has_enemies_in_range():
			_prog_elephant_flash = 1.0
			var strongest: Node2D = null
			var most_hp: float = 0.0
			for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
				if global_position.distance_to(e.global_position) < attack_range * _range_mult():
					var hp = e.health if "health" in e else 0.0
					if hp > most_hp:
						most_hp = hp
						strongest = e
			if strongest and strongest.has_method("take_damage"):
				var eff_damage = damage * 8.0 * _damage_mult()
				strongest.take_damage(eff_damage)
				register_damage(eff_damage)
			if is_instance_valid(_main_node):
				_main_node.spawn_floating_text(global_position + Vector2(0, -40), "ELEPHANT GUN!", Color(0.7, 0.5, 0.2), 14.0, 1.2)
			_prog_elephant_timer = 15.0

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

func has_synergy_buff() -> bool:
	return not _synergy_buffs.is_empty()

var power_damage_mult: float = 1.0

# === ACTIVE HERO ABILITY: Big Game Shot (massive single-target, 30s CD) ===
var active_ability_ready: bool = true
var active_ability_cooldown: float = 0.0
var active_ability_max_cd: float = 30.0

func activate_hero_ability() -> void:
	if not active_ability_ready:
		return
	var strongest: Node2D = null
	var most_hp: float = 0.0
	for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if global_position.distance_to(e.global_position) < attack_range * _range_mult() * 1.5:
			var hp = e.health if "health" in e else 0.0
			if hp > most_hp:
				most_hp = hp
				strongest = e
	if strongest and strongest.has_method("take_damage"):
		var dmg = damage * 10.0 * _damage_mult()
		strongest.take_damage(dmg)
		register_damage(dmg)
	active_ability_ready = false
	active_ability_cooldown = active_ability_max_cd
	if is_instance_valid(_main_node):
		_main_node.spawn_floating_text(global_position + Vector2(0, -40), "BIG GAME SHOT!", Color(0.7, 0.5, 0.2), 16.0, 1.5)
		_main_node.trigger_camera_shake(8.0, 0.5)

func get_active_ability_name() -> String:
	return "Big Game Shot"

func get_active_ability_desc() -> String:
	return "10x dmg to strongest (30s CD)"

func _damage_mult() -> float:
	var mult: float = (1.0 + _synergy_buffs.get("damage", 0.0) + _meta_buffs.get("damage", 0.0)) * power_damage_mult
	if prog_abilities[0]:  # Safari Precision: +25% rifle damage
		mult *= 1.25
	return mult

func _range_mult() -> float:
	return 1.0 + _synergy_buffs.get("range", 0.0) + _meta_buffs.get("range", 0.0)

func _speed_mult() -> float:
	var mult: float = 1.0 + _synergy_buffs.get("attack_speed", 0.0) + _meta_buffs.get("attack_speed", 0.0)
	if prog_abilities[0]:  # Safari Precision: +10% speed
		mult *= 1.10
	return mult

func _gold_mult() -> float:
	return 1.0 + _synergy_buffs.get("gold_bonus", 0.0) + _meta_buffs.get("gold_bonus", 0.0)

# === DRAW ===

func _draw() -> void:
	# Build animation — elastic scale-in
	if _build_timer > 0.0:
		var bt = 1.0 - clampf(_build_timer / 0.5, 0.0, 1.0)
		var elastic = 1.0 + sin(bt * PI * 2.5) * 0.3 * (1.0 - bt)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(elastic, elastic))

	# === 1. SELECTION RING ===
	var eff_range = attack_range * _range_mult()
	if is_selected:
		var pulse = (sin(_time * 3.0) + 1.0) * 0.5
		var ring_alpha = 0.5 + pulse * 0.3
		draw_arc(Vector2.ZERO, eff_range, 0, TAU, 36, Color(0.4, 0.35, 0.2, 0.25 + pulse * 0.15), 2.0)
		draw_arc(Vector2.ZERO, 40.0, 0, TAU, 28, Color(0.4, 0.35, 0.2, ring_alpha), 2.5)
		draw_arc(Vector2.ZERO, 43.0, 0, TAU, 28, Color(0.4, 0.35, 0.2, ring_alpha * 0.4), 1.5)

	# === 2. SPRITE RENDERING ===
	var _active_tex: Texture2D = sprite_texture
	if _attack_anim > 0.5 and _sprite_attack:
		_active_tex = _sprite_attack
	elif _attack_anim > 0.15 and _sprite_shoot:
		_active_tex = _sprite_shoot
	elif _flair_active > 0.0 and _flair_current:
		_active_tex = _flair_current

	if _active_tex:
		var tex_size = _active_tex.get_size()
		var scale_factor = 120.0 / tex_size.y if tex_size.y > 0 else 1.0
		var draw_size = tex_size * scale_factor
		draw_texture_rect(_active_tex, Rect2(-draw_size / 2.0 + Vector2(0, -draw_size.y * 0.25), draw_size), false)

	# === 3. UPGRADE FLASH ===
	if _upgrade_flash > 0.0:
		if _upgrade_name != "" and _game_font:
			draw_string(_game_font, Vector2(-40, -70), _upgrade_name, HORIZONTAL_ALIGNMENT_CENTER, 80, 11, Color(1, 0.85, 0.2, _upgrade_flash))

	# === 4. ABILITY FLASH EFFECTS ===
	# Steel trap flash — brown root ring
	if _steel_trap_flash > 0.0:
		draw_circle(Vector2.ZERO, 20.0 * _steel_trap_flash, Color(0.5, 0.35, 0.15, _steel_trap_flash * 0.5))

	# Dynamite flash — orange expanding explosion
	if _dynamite_flash > 0.0:
		var dr = 30.0 + (1.0 - _dynamite_flash) * 70.0
		draw_arc(Vector2.ZERO, dr, 0, TAU, 24, Color(0.9, 0.5, 0.1, _dynamite_flash * 0.4), 3.0)
		for si in range(8):
			var sa = TAU * float(si) / 8.0 + _dynamite_flash * 3.0
			var sp = Vector2.from_angle(sa) * dr
			draw_circle(sp, 3.0, Color(1.0, 0.6, 0.1, _dynamite_flash * 0.5))

	# Elephant gun flash — muzzle flash line
	if _elephant_gun_flash > 0.0:
		var dir = Vector2.from_angle(aim_angle)
		draw_line(Vector2.ZERO, dir * (60.0 + (1.0 - _elephant_gun_flash) * 40.0), Color(1.0, 0.9, 0.3, _elephant_gun_flash * 0.6), 3.0)

	# Expedition flash — marching dots
	if _expedition_flash > 0.0:
		for pi in range(3):
			var pa = TAU * float(pi) / 3.0 + _expedition_flash * 4.0
			var pp = Vector2.from_angle(pa) * 35.0
			draw_circle(pp, 4.0, Color(0.6, 0.45, 0.25, _expedition_flash * 0.5))

	# Fear aura — constant dark ring
	if _fear_aura_active:
		var fear_pulse = sin(_time * 2.0) * 0.05 + 0.15
		draw_arc(Vector2.ZERO, eff_range * 0.8, 0, TAU, 32, Color(0.2, 0.1, 0.05, fear_pulse), 2.0)

	# === 5. TIER PIPS (safari/earth theme) ===
	var plat_y = 24.0
	for i in range(upgrade_tier):
		var pip_angle = -PI / 2.0 + float(i) * (TAU / 5.0) - (float(upgrade_tier - 1) * TAU / 10.0)
		var pip_pos = Vector2(cos(pip_angle) * 24.0, plat_y + sin(pip_angle) * 8.0)
		var pip_col: Color
		match i:
			0: pip_col = Color(0.5, 0.4, 0.2)    # safari brown
			1: pip_col = Color(0.6, 0.4, 0.15)    # trap bronze
			2: pip_col = Color(0.9, 0.5, 0.1)     # dynamite orange
			3: pip_col = Color(0.8, 0.7, 0.2)     # trophy gold
			_: pip_col = Color(0.3, 0.2, 0.1)     # darkness
		draw_circle(pip_pos, 4.0, pip_col)
		draw_circle(pip_pos, 5.5, Color(pip_col.r, pip_col.g, pip_col.b, 0.15))

	# === 6. ACTIVE ABILITY COOLDOWN ARC ===
	if not active_ability_ready:
		var cd_fill = 1.0 - (active_ability_cooldown / active_ability_max_cd)
		draw_arc(Vector2.ZERO, 28.0, -PI / 2.0, -PI / 2.0 + TAU * cd_fill, 32, Color(0.7, 0.5, 0.2, 0.3), 2.0)

	_draw_tower_aura()

func _draw_tower_aura() -> void:
	if upgrade_tier < 3:
		return
	var aura_col = Color(0.6, 0.45, 0.2)
	var pulse = sin(_time * 2.5) * 0.1 + 0.3
	if upgrade_tier >= 4:
		var outer_pulse = sin(_time * 1.8) * 0.15 + 0.35
		for i in range(6):
			var a1 = _time * 0.5 + float(i) * TAU / 6.0
			var a2 = a1 + TAU / 12.0
			draw_arc(Vector2.ZERO, 18.0, a1, a2, 4, Color(aura_col.r, aura_col.g, aura_col.b, 0.2), 1.0)
	if _main_node and _main_node.has_method("_is_awakened"):
		var tower_type_enum = get_meta("tower_type_enum") if has_meta("tower_type_enum") else -1
		if tower_type_enum >= 0 and _main_node._is_awakened(tower_type_enum):
			var glow_pulse = sin(_time * 1.5) * 0.1 + 0.25
			draw_arc(Vector2.ZERO, 32.0, 0, TAU, 32, Color(0.8, 0.6, 0.2, glow_pulse), 2.5)
