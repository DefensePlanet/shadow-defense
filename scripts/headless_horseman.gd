extends Node2D
## Headless Horseman — spectral rider from Washington Irving's Legend of Sleepy Hollow (1820).
## Path A "Hessian Warlord": Hessian Fury, Midnight Ride, Headless Charge
## Path B "Hellfire Rider": Flaming Pumpkin, Pumpkin Bombs, Hellfire Eruption
## Path C "The Legend": Spectral Armor, Sleepy Hollow Fog, The Legend Lives

# Base stats
var damage: float = 28.0
var fire_rate: float = 0.80
var attack_range: float = 160.0
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

# Path A: Hessian Warlord
var _midnight_ride_timer: float = 15.0
var _midnight_ride_flash: float = 0.0
var _headless_charge_timer: float = 15.0
var _headless_charge_flash: float = 0.0

# Path B: Hellfire Rider
var _fire_trail_active: bool = false
var _pumpkin_bombs_timer: float = 18.0
var _pumpkin_bombs_flash: float = 0.0
var _hellfire_eruption_active: bool = false
var _burn_aura_active: bool = false

# Path C: The Legend
var _spectral_shield: float = 0.0
var _spectral_shield_timer: float = 15.0
var _spectral_shield_flash: float = 0.0
var _fog_timer: float = 18.0
var _fog_flash: float = 0.0
var _legend_lives_active: bool = false
var _flee_on_hit: bool = false
var _has_resurrected: bool = false
var _bridge_trap_timer: float = 20.0
var _bridge_trap_flash: float = 0.0

# Heal life timer (Old Dutch Church prog ability)
var _heal_life_timer: float = 25.0

# === PROGRESSIVE ABILITIES (9 tiers, unlocked via lifetime damage) ===
const PROG_ABILITY_NAMES = [
	"Hessian Fury", "Spectral Armor", "Flaming Pumpkin", "Midnight Ride",
	"The Old Dutch Church", "Sleepy Hollow Fog", "Daredevil's Bridge",
	"Headless Charge", "The Legend Lives"
]
const PROG_ABILITY_DESCS = [
	"+25% sword dmg, +15% speed",
	"Shield absorbs 50 dmg/15s",
	"Attacks leave fire trail, 2s DoT",
	"Every 15s, gallop through enemies 4x",
	"Heal 1 life every 25s",
	"Every 18s, fog slows all 50% for 3s",
	"Every 20s, bridge trap enemies take 6x",
	"Every 15s, charge across map 3x all enemies",
	"Permanent: 25% flee on hit + resurrect once"
]
var prog_abilities: Array = [false, false, false, false, false, false, false, false, false]
# Ability timers
var _prog_midnight_timer: float = 15.0
var _prog_church_timer: float = 25.0
var _prog_fog_timer: float = 18.0
var _prog_bridge_timer: float = 20.0
var _prog_charge_timer: float = 15.0
# Visual flash timers
var _prog_midnight_flash: float = 0.0
var _prog_fog_flash: float = 0.0
var _prog_bridge_flash: float = 0.0
var _prog_charge_flash: float = 0.0

const MAX_STAT_LEVEL: int = 10  # Cap stat scaling to prevent infinite power creep
const STAT_UPGRADE_INTERVAL: float = 8000.0
const ABILITY_THRESHOLD: float = 28000.0
var stat_upgrade_level: int = 0
var ability_chosen: bool = false
var awaiting_ability_choice: bool = false
const TIER_NAMES = [
	"Hessian Fury",
	"Flaming Pumpkin",
	"Sleepy Hollow Fog",
	"Midnight Ride",
	"The Legend Lives"
]
const ABILITY_DESCRIPTIONS = [
	"+25% sword damage, +15% attack speed",
	"Attacks leave fire trail, dealing 2s DoT",
	"Every 18s, fog slows all enemies 50% for 3s",
	"Every 15s, gallop through enemies dealing 4x",
	"25% flee on hit + resurrect once per game"
]
const TIER_COSTS = [140, 325, 600, 1100, 1800]
var is_selected: bool = false
var base_cost: int = 0

# Attack sounds — spectral sword slash with ghostly whinny
var _attack_sounds: Array = []
var _attack_sounds_by_tier: Array = []
var _attack_player: AudioStreamPlayer

# Ability sounds
var _upgrade_sound: AudioStreamWAV
var _upgrade_player: AudioStreamPlayer
var _gallop_sound: AudioStreamWAV
var _gallop_player: AudioStreamPlayer
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

	# Gallop — rhythmic hoofbeats with spectral echo
	var gal_rate := 44100
	var gal_dur := 0.8
	var gal_samples := PackedFloat32Array()
	gal_samples.resize(int(gal_rate * gal_dur))
	for i in gal_samples.size():
		var t := float(i) / gal_rate
		var s := 0.0
		# Four hoofbeat impacts
		for hoof in range(4):
			var ht = t - float(hoof) * 0.18
			if ht >= 0.0 and ht < 0.15:
				var impact := exp(-ht * 30.0) * 0.3
				s += sin(TAU * 120.0 * ht) * impact
				s += (randf() * 2.0 - 1.0) * exp(-ht * 50.0) * 0.15
		# Spectral whinny overtone
		var ghost_env := sin(clampf(t * 3.0, 0.0, PI)) * 0.1
		s += sin(TAU * 800.0 * t + sin(TAU * 6.0 * t) * 3.0) * ghost_env
		gal_samples[i] = clampf(s, -1.0, 1.0)
	_gallop_sound = _samples_to_wav(gal_samples, gal_rate)
	_gallop_player = AudioStreamPlayer.new()
	_gallop_player.stream = _gallop_sound
	_gallop_player.volume_db = -12.0
	add_child(_gallop_player)

	# Upgrade chime — ominous descending minor with bell toll
	var up_rate := 22050
	var up_dur := 0.4
	var up_samples := PackedFloat32Array()
	up_samples.resize(int(up_rate * up_dur))
	var up_notes := [392.0, 349.23, 293.66]  # G4, F4, D4 (descending minor)
	var up_note_len := int(up_rate * up_dur) / 3
	for i in up_samples.size():
		var t := float(i) / up_rate
		var ni := mini(i / up_note_len, 2)
		var nt := float(i - ni * up_note_len) / float(up_rate)
		var freq: float = up_notes[ni]
		var env := minf(nt * 50.0, 1.0) * exp(-nt * 8.0) * 0.4
		up_samples[i] = clampf((sin(TAU * freq * t) + sin(TAU * freq * 0.5 * t) * 0.3) * env, -1.0, 1.0)
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
	_midnight_ride_flash = max(_midnight_ride_flash - delta * 1.5, 0.0)
	_headless_charge_flash = max(_headless_charge_flash - delta * 1.5, 0.0)
	_pumpkin_bombs_flash = max(_pumpkin_bombs_flash - delta * 1.5, 0.0)
	_fog_flash = max(_fog_flash - delta * 1.5, 0.0)
	_spectral_shield_flash = max(_spectral_shield_flash - delta * 2.0, 0.0)
	_bridge_trap_flash = max(_bridge_trap_flash - delta * 1.5, 0.0)

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

	# Spectral Armor — recharge shield
	if prog_abilities[1] or upgrade_tier >= 1:
		if _spectral_shield <= 0.0:
			_spectral_shield_timer -= delta
			if _spectral_shield_timer <= 0.0:
				_spectral_shield = 50.0
				_spectral_shield_timer = 15.0
				_spectral_shield_flash = 1.0

	# Midnight Ride — gallop through enemies
	if upgrade_tier >= 4:
		_midnight_ride_timer -= delta
		if _midnight_ride_timer <= 0.0 and _has_enemies_in_range():
			_midnight_ride()
			_midnight_ride_timer = 15.0

	# Pumpkin Bombs
	if upgrade_tier >= 3:
		_pumpkin_bombs_timer -= delta
		if _pumpkin_bombs_timer <= 0.0 and _has_enemies_in_range():
			_pumpkin_bomb_scatter()
			_pumpkin_bombs_timer = 18.0

	# Fog
	if upgrade_tier >= 3:
		_fog_timer -= delta
		if _fog_timer <= 0.0 and _has_enemies_in_range():
			_sleepy_hollow_fog()
			_fog_timer = 18.0

	# Headless Charge (tier 5)
	if upgrade_tier >= 5:
		_headless_charge_timer -= delta
		if _headless_charge_timer <= 0.0 and _has_enemies_in_range():
			_headless_charge()
			_headless_charge_timer = 15.0

	# Bridge trap
	if _legend_lives_active:
		_bridge_trap_timer -= delta
		if _bridge_trap_timer <= 0.0 and _has_enemies_in_range():
			_daredevils_bridge()
			_bridge_trap_timer = 20.0

	# Burn aura — continuous fire DoT to nearby enemies
	if _burn_aura_active:
		var eff_range = attack_range * _range_mult() * 2.0
		for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
			if global_position.distance_to(e.global_position) < eff_range:
				if e.has_method("take_damage"):
					e.take_damage(damage * 0.1 * delta * _damage_mult())

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

	if target.has_method("take_damage"):
		target.take_damage(eff_damage)
		register_damage(eff_damage)
		var hp_before = target.health if "health" in target else 0.0
		if hp_before <= eff_damage:
			register_kill()

	# Flaming Pumpkin — fire trail DoT
	if _fire_trail_active or prog_abilities[2]:
		if target and is_instance_valid(target) and target.has_method("apply_dot"):
			target.apply_dot(damage * 0.3 * _damage_mult(), 2.0)

	# Flee on hit (The Legend Lives)
	if _flee_on_hit or prog_abilities[8]:
		if target and is_instance_valid(target) and randf() < 0.25:
			if target.has_method("apply_slow"):
				target.apply_slow(0.80, 1.5)  # Heavy slow as flee approximation

func _midnight_ride() -> void:
	_midnight_ride_flash = 1.0
	if _gallop_player and not _is_sfx_muted():
		_gallop_player.play()
	var eff_range = attack_range * _range_mult()
	var eff_damage = damage * 4.0 * _damage_mult()
	for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if global_position.distance_to(e.global_position) < eff_range:
			if e.has_method("take_damage"):
				e.take_damage(eff_damage)
				register_damage(eff_damage)

func _headless_charge() -> void:
	_headless_charge_flash = 1.0
	if _gallop_player and not _is_sfx_muted():
		_gallop_player.play()
	# Hit ALL enemies on the map
	var eff_damage = damage * 3.0 * _damage_mult()
	for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if e.has_method("take_damage"):
			e.take_damage(eff_damage)
			register_damage(eff_damage)
	if is_instance_valid(_main_node):
		_main_node.spawn_floating_text(global_position + Vector2(0, -40), "HEADLESS CHARGE!", Color(0.7, 0.4, 0.1), 16.0, 1.5)
		_main_node.trigger_camera_shake(10.0, 0.8)

func _pumpkin_bomb_scatter() -> void:
	_pumpkin_bombs_flash = 1.0
	var eff_damage = damage * 3.0 * _damage_mult()
	var enemies_in_range: Array = []
	for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if global_position.distance_to(e.global_position) < attack_range * _range_mult():
			enemies_in_range.append(e)
	enemies_in_range.shuffle()
	for i in range(mini(5, enemies_in_range.size())):
		var e = enemies_in_range[i]
		if is_instance_valid(e) and e.has_method("take_damage"):
			e.take_damage(eff_damage)
			register_damage(eff_damage)
	if is_instance_valid(_main_node):
		_main_node.trigger_camera_shake(6.0, 0.4)

func _sleepy_hollow_fog() -> void:
	_fog_flash = 1.0
	var eff_range = attack_range * _range_mult()
	for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if global_position.distance_to(e.global_position) < eff_range:
			if e.has_method("apply_slow"):
				e.apply_slow(0.50, 3.0)

func _daredevils_bridge() -> void:
	_bridge_trap_flash = 1.0
	var eff_damage = damage * 6.0 * _damage_mult()
	var nearest = _find_nearest_enemy()
	if nearest and nearest.has_method("take_damage"):
		nearest.take_damage(eff_damage)
		register_damage(eff_damage)

func register_kill() -> void:
	kill_count += 1
	_upgrade_flash = 0.3

func register_damage(amount: float) -> void:
	damage_dealt += amount
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("register_tower_damage"):
		main.register_tower_damage(main.TowerType.HEADLESS_HORSEMAN, amount)
	_check_upgrades()

func absorb_damage(incoming: float) -> float:
	if _spectral_shield > 0.0:
		var absorbed = minf(incoming, _spectral_shield)
		_spectral_shield -= absorbed
		return incoming - absorbed
	return incoming

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
	damage += 2.0
	fire_rate += 0.015
	attack_range += 4.5

func choose_ability(index: int) -> void:
	ability_chosen = true
	awaiting_ability_choice = false
	upgrade_tier = index + 1
	_apply_upgrade(upgrade_tier)
	_upgrade_flash = 3.0
	_upgrade_name = TIER_NAMES[index]

func _apply_upgrade(tier: int) -> void:
	match tier:
		1: # Hessian Fury — +25% sword dmg, +15% speed
			damage = 35.0
			fire_rate = 0.92
			attack_range = 165.0
		2: # Flaming Pumpkin — fire trail DoT
			_fire_trail_active = true
			damage = 40.0
			fire_rate = 0.98
			attack_range = 170.0
			gold_bonus = 2
		3: # Sleepy Hollow Fog — slow all 50%
			damage = 46.0
			fire_rate = 1.05
			attack_range = 175.0
			gold_bonus = 2
		4: # Midnight Ride — gallop 4x
			damage = 54.0
			fire_rate = 1.12
			attack_range = 180.0
			gold_bonus = 3
		5: # The Legend Lives — flee + resurrect
			_legend_lives_active = true
			_flee_on_hit = true
			damage = 62.0
			fire_rate = 1.20
			attack_range = 185.0
			gold_bonus = 3

func apply_path_upgrade(path: String, tier: int) -> void:
	match path:
		"A":
			match tier:
				1: # Hessian Fury — +25% sword dmg + 15% speed
					damage *= 1.25
					fire_rate *= 1.15
				2: # Midnight Ride — gallop 4x/15s
					pass  # Timer handled in _process
				3: # Headless Charge — entire map 3x + cleave/15s
					pass  # Timer handled in _process
		"B":
			match tier:
				1: # Flaming Pumpkin — fire trail DoT
					_fire_trail_active = true
				2: # Pumpkin Bombs — 5 scatter + explode 3x/18s
					pass  # Timer handled in _process
				3: # Hellfire Eruption — 6x 2x range + burn aura
					_hellfire_eruption_active = true
					_burn_aura_active = true
					attack_range *= 2.0
		"C":
			match tier:
				1: # Spectral Armor — shield 50/15s
					pass  # Shield recharge handled in _process
				2: # Sleepy Hollow Fog — slow 50% 3s/18s
					pass  # Timer handled in _process
				3: # The Legend Lives — 25% flee + bridge trap 6x + resurrect
					_legend_lives_active = true
					_flee_on_hit = true
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
	return "Headless Horseman"

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
	var melody := [293.66, 261.63, 293.66, 349.23, 329.63, 293.66, 261.63, 246.94]
	# D4 C4 D4 F4 E4 D4 C4 B3 — ominous dark melody
	_attack_sounds_by_tier = []
	for tier in range(5):
		var tier_sounds: Array = []
		var dur := 0.42 + tier * 0.05
		var vol := 0.28 + tier * 0.02
		for note_idx in melody.size():
			var freq: float = melody[note_idx]
			var total := int(mix_rate * dur)
			var samples := PackedFloat32Array()
			samples.resize(total)
			var rng := RandomNumberGenerator.new()
			rng.seed = note_idx * 2800 + tier * 450
			for i in total:
				var t := float(i) / float(mix_rate)
				var env := minf(t * 20.0, 1.0) * exp(-t * 2.8)
				# Dark slashing tone — sawtooth-ish with ghostly overtone
				var s := sin(t * freq * TAU) * 0.35
				s += sin(t * freq * 2.0 * TAU) * 0.12
				# Ghost whisper noise
				var ghost := rng.randf_range(-1.0, 1.0) * 0.05 * exp(-t * 3.0)
				s += ghost
				# Low sub-bass rumble
				s += sin(t * freq * 0.5 * TAU) * 0.08 * exp(-t * 4.0)
				samples[i] = clampf(s * env * vol, -1.0, 1.0)
			var att_len := mini(int(0.008 * mix_rate), total)
			for i in att_len:
				samples[i] *= float(i) / float(att_len)
			var rel_start := maxi(total - int(0.025 * mix_rate), 0)
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
	if main and main.survivor_progress.has(main.TowerType.HEADLESS_HORSEMAN):
		var p = main.survivor_progress[main.TowerType.HEADLESS_HORSEMAN]
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
	if prog_abilities[0]:  # Hessian Fury: +25% dmg, +15% speed applied in multipliers
		pass
	if prog_abilities[2]:  # Flaming Pumpkin: fire trail
		_fire_trail_active = true
	if prog_abilities[8]:  # The Legend Lives: flee + resurrect
		_flee_on_hit = true

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
	_prog_midnight_flash = max(_prog_midnight_flash - delta * 1.5, 0.0)
	_prog_fog_flash = max(_prog_fog_flash - delta * 1.5, 0.0)
	_prog_bridge_flash = max(_prog_bridge_flash - delta * 1.5, 0.0)
	_prog_charge_flash = max(_prog_charge_flash - delta * 1.5, 0.0)

	# Ability 4: Midnight Ride — gallop through enemies 4x every 15s
	if prog_abilities[3]:
		_prog_midnight_timer -= delta
		if _prog_midnight_timer <= 0.0 and _has_enemies_in_range():
			_prog_midnight_flash = 1.0
			if _gallop_player and not _is_sfx_muted():
				_gallop_player.play()
			var eff_damage = damage * 4.0 * _damage_mult()
			for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
				if global_position.distance_to(e.global_position) < attack_range * _range_mult():
					if e.has_method("take_damage"):
						e.take_damage(eff_damage)
						register_damage(eff_damage)
			_prog_midnight_timer = 15.0

	# Ability 5: The Old Dutch Church — heal 1 life every 25s
	if prog_abilities[4]:
		_prog_church_timer -= delta
		if _prog_church_timer <= 0.0:
			var main = get_tree().get_first_node_in_group("main")
			if main and main.has_method("restore_life"):
				main.restore_life(1)
			_prog_church_timer = 25.0

	# Ability 6: Sleepy Hollow Fog — slow all 50% for 3s every 18s
	if prog_abilities[5]:
		_prog_fog_timer -= delta
		if _prog_fog_timer <= 0.0 and _has_enemies_in_range():
			_prog_fog_flash = 1.0
			for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
				if global_position.distance_to(e.global_position) < attack_range * _range_mult():
					if e.has_method("apply_slow"):
						e.apply_slow(0.50, 3.0)
			_prog_fog_timer = 18.0

	# Ability 7: Daredevil's Bridge — bridge trap enemies take 6x every 20s
	if prog_abilities[6]:
		_prog_bridge_timer -= delta
		if _prog_bridge_timer <= 0.0 and _has_enemies_in_range():
			_prog_bridge_flash = 1.0
			var eff_damage = damage * 6.0 * _damage_mult()
			var nearest = _find_nearest_enemy()
			if nearest and nearest.has_method("take_damage"):
				nearest.take_damage(eff_damage)
				register_damage(eff_damage)
			_prog_bridge_timer = 20.0

	# Ability 8: Headless Charge — charge across map 3x all enemies every 15s
	if prog_abilities[7]:
		_prog_charge_timer -= delta
		if _prog_charge_timer <= 0.0 and _has_enemies_in_range():
			_prog_charge_flash = 1.0
			if _gallop_player and not _is_sfx_muted():
				_gallop_player.play()
			var eff_damage = damage * 3.0 * _damage_mult()
			for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
				if e.has_method("take_damage"):
					e.take_damage(eff_damage)
					register_damage(eff_damage)
			if is_instance_valid(_main_node):
				_main_node.spawn_floating_text(global_position + Vector2(0, -40), "HEADLESS CHARGE!", Color(0.7, 0.4, 0.1), 14.0, 1.2)
				_main_node.trigger_camera_shake(8.0, 0.6)
			_prog_charge_timer = 15.0

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

# === ACTIVE HERO ABILITY: Dread Gallop (AoE charge + fear, 30s CD) ===
var active_ability_ready: bool = true
var active_ability_cooldown: float = 0.0
var active_ability_max_cd: float = 30.0

func activate_hero_ability() -> void:
	if not active_ability_ready:
		return
	var enemies = (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies"))
	for e in enemies:
		if global_position.distance_to(e.global_position) < attack_range * _range_mult() * 2.0:
			if is_instance_valid(e) and e.has_method("take_damage"):
				var dmg = damage * 5.0 * _damage_mult()
				e.take_damage(dmg)
				register_damage(dmg)
			if e.has_method("apply_slow"):
				e.apply_slow(0.60, 3.0)
	active_ability_ready = false
	active_ability_cooldown = active_ability_max_cd
	if is_instance_valid(_main_node):
		_main_node.spawn_floating_text(global_position + Vector2(0, -40), "DREAD GALLOP!", Color(0.7, 0.4, 0.1), 16.0, 1.5)
		_main_node.trigger_camera_shake(12.0, 0.8)
		_main_node.trigger_screen_dark(1.0, Color(0.1, 0.05, 0.0))

func get_active_ability_name() -> String:
	return "Dread Gallop"

func get_active_ability_desc() -> String:
	return "AoE charge + fear (30s CD)"

func _damage_mult() -> float:
	var mult: float = (1.0 + _synergy_buffs.get("damage", 0.0) + _meta_buffs.get("damage", 0.0)) * power_damage_mult
	if prog_abilities[0]:  # Hessian Fury: +25% sword damage
		mult *= 1.25
	return mult

func _range_mult() -> float:
	return 1.0 + _synergy_buffs.get("range", 0.0) + _meta_buffs.get("range", 0.0)

func _speed_mult() -> float:
	var mult: float = 1.0 + _synergy_buffs.get("attack_speed", 0.0) + _meta_buffs.get("attack_speed", 0.0)
	if prog_abilities[0]:  # Hessian Fury: +15% speed
		mult *= 1.15
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
		draw_arc(Vector2.ZERO, eff_range, 0, TAU, 36, Color(0.7, 0.4, 0.1, 0.25 + pulse * 0.15), 2.0)
		draw_arc(Vector2.ZERO, 40.0, 0, TAU, 28, Color(0.7, 0.4, 0.1, ring_alpha), 2.5)
		draw_arc(Vector2.ZERO, 43.0, 0, TAU, 28, Color(0.7, 0.4, 0.1, ring_alpha * 0.4), 1.5)

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
	# Midnight ride flash — orange gallop trail
	if _midnight_ride_flash > 0.0:
		for gi in range(6):
			var ga = TAU * float(gi) / 6.0 + _midnight_ride_flash * 5.0
			var gp = Vector2.from_angle(ga) * (30.0 + (1.0 - _midnight_ride_flash) * 50.0)
			draw_circle(gp, 4.0, Color(0.8, 0.5, 0.1, _midnight_ride_flash * 0.4))

	# Headless charge flash — wide dark shockwave
	if _headless_charge_flash > 0.0:
		var cr = 50.0 + (1.0 - _headless_charge_flash) * 100.0
		draw_arc(Vector2.ZERO, cr, 0, TAU, 32, Color(0.4, 0.2, 0.05, _headless_charge_flash * 0.35), 3.0)

	# Pumpkin bombs flash — scattered orange dots
	if _pumpkin_bombs_flash > 0.0:
		for pi in range(5):
			var pa = TAU * float(pi) / 5.0 + _pumpkin_bombs_flash * 3.0
			var pp = Vector2.from_angle(pa) * (25.0 + (1.0 - _pumpkin_bombs_flash) * 40.0)
			draw_circle(pp, 5.0, Color(0.9, 0.5, 0.05, _pumpkin_bombs_flash * 0.5))
			draw_circle(pp, 3.0, Color(1.0, 0.7, 0.1, _pumpkin_bombs_flash * 0.6))

	# Fog flash — grey expanding mist
	if _fog_flash > 0.0:
		var fr = 40.0 + (1.0 - _fog_flash) * 60.0
		draw_arc(Vector2.ZERO, fr, 0, TAU, 24, Color(0.5, 0.5, 0.5, _fog_flash * 0.25), 4.0)

	# Spectral shield indicator
	if _spectral_shield > 0.0:
		var shield_alpha = _spectral_shield / 50.0 * 0.3
		draw_arc(Vector2.ZERO, 35.0, 0, TAU, 24, Color(0.4, 0.6, 0.8, shield_alpha), 2.0)

	# Bridge trap flash — brown spike
	if _bridge_trap_flash > 0.0:
		draw_circle(Vector2.ZERO, 12.0 * _bridge_trap_flash, Color(0.5, 0.3, 0.1, _bridge_trap_flash * 0.5))

	# Fire trail aura
	if _fire_trail_active or prog_abilities[2]:
		var fire_pulse = sin(_time * 3.0) * 0.05 + 0.1
		draw_arc(Vector2.ZERO, 30.0, 0, TAU, 24, Color(0.9, 0.4, 0.05, fire_pulse), 1.5)

	# Burn aura
	if _burn_aura_active:
		var burn_pulse = sin(_time * 2.0) * 0.08 + 0.15
		draw_arc(Vector2.ZERO, eff_range * 0.6, 0, TAU, 32, Color(0.9, 0.3, 0.0, burn_pulse), 2.0)

	# === 5. TIER PIPS (halloween/fire theme) ===
	var plat_y = 24.0
	for i in range(upgrade_tier):
		var pip_angle = -PI / 2.0 + float(i) * (TAU / 5.0) - (float(upgrade_tier - 1) * TAU / 10.0)
		var pip_pos = Vector2(cos(pip_angle) * 24.0, plat_y + sin(pip_angle) * 8.0)
		var pip_col: Color
		match i:
			0: pip_col = Color(0.7, 0.4, 0.1)    # hessian amber
			1: pip_col = Color(0.9, 0.5, 0.05)    # pumpkin orange
			2: pip_col = Color(0.5, 0.5, 0.6)     # fog grey
			3: pip_col = Color(0.3, 0.2, 0.4)     # midnight purple
			_: pip_col = Color(0.2, 0.15, 0.1)    # darkness
		draw_circle(pip_pos, 4.0, pip_col)
		draw_circle(pip_pos, 5.5, Color(pip_col.r, pip_col.g, pip_col.b, 0.15))

	# === 6. ACTIVE ABILITY COOLDOWN ARC ===
	if not active_ability_ready:
		var cd_fill = 1.0 - (active_ability_cooldown / active_ability_max_cd)
		draw_arc(Vector2.ZERO, 28.0, -PI / 2.0, -PI / 2.0 + TAU * cd_fill, 32, Color(0.7, 0.4, 0.1, 0.3), 2.0)

	_draw_tower_aura()

func _draw_tower_aura() -> void:
	if upgrade_tier < 3:
		return
	var aura_col = Color(0.7, 0.4, 0.1)
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
			draw_arc(Vector2.ZERO, 32.0, 0, TAU, 32, Color(0.9, 0.5, 0.1, glow_pulse), 2.5)
