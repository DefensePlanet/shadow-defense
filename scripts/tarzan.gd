extends Node2D
## Tarzan — bomb-style tower. Slow but devastating AoE attacks, vine swing smash, ape allies.
## Tier 1: Vine Swing — AoE ground pound smash (swing on vine, Donkey Kong double fist)
## Tier 2: Ape Strength — +6% damage boost
## Tier 3: Animal Call — call 1 ape ally for 15s every other wave
## Tier 4: King of the Apes — 3 more apes join, throw enemies back to start

# Base stats (bomb tower: slow but powerful)
var damage: float = 46.0
var fire_rate: float = 0.33
var attack_range: float = 120.0
var fire_cooldown: float = 0.0
var aim_angle: float = 0.0
var target: Node2D = null
var _draw_progress: float = 0.0
var gold_bonus: int = 1

# Targeting priority: 0=First, 1=Last, 2=Close, 3=Strong
var targeting_priority: int = 0

# Animation timers
var _time: float = 0.0
var _build_timer: float = 0.0
var _attack_anim: float = 0.0

# Damage tracking and upgrades
var damage_dealt: float = 0.0
var upgrade_tier: int = 0
var _upgrade_flash: float = 0.0
var _upgrade_name: String = ""

# Tier 1: Vine Swing — AoE ground pound
var _vine_swing_active: bool = false
var _vine_swing_phase: float = 0.0
var _vine_swing_start_angle: float = 0.0
var _smash_flash: float = 0.0

# Tier 3/4: Ape allies — summoned every other wave
var _ape_call_wave_count: int = 0
var _ape_call_timer: float = 0.0

# Tier 4: King of the Apes
var _king_apes_active: bool = false

# Kill tracking
var kill_count: int = 0

# Ability: Lord of the Jungle — stun + animal summon
var _ability_flash: float = 0.0
var _animal_allies: Array = []

# === PROGRESSIVE ABILITIES (9 tiers, unlocked via lifetime damage) ===
const PROG_ABILITY_NAMES = [
	"Jungle Instinct", "Ape Agility", "Vine Master", "Tantor's Charge",
	"Animal Brotherhood", "Predator Sense", "Mangani War Cry",
	"Lord of Opar", "Legend of the Jungle"
]
const PROG_ABILITY_DESCS = [
	"Melee hits 20% harder, +10% attack speed",
	"15% chance on attack to gain +30% attack speed for 5s",
	"Vine attacks pull enemies closer by 30px",
	"Every 15s, charge forward dealing 4x to nearest",
	"Animal allies deal 50% more and last 2s longer",
	"Reveals hidden enemies, +25% range",
	"Every 20s, war cry stuns nearby enemies for 1s",
	"Every 25s, golden vine strike hits all in range for 6x",
	"Permanent 3 animal allies, double passive aura damage"
]
var prog_abilities: Array = [false, false, false, false, false, false, false, false, false]
# Ability timers
var _tantor_charge_timer: float = 15.0
var _mangani_cry_timer: float = 20.0
var _opar_strike_timer: float = 25.0
# Ape Agility (prog ability 2) — attack speed buff
var _ape_agility_timer: float = 0.0
var _ape_agility_active: bool = false
# Predator Sense (prog ability 6) — camo reveal tracking
var _predator_sense_revealed: Array = []
# Tantor's Charge visual dash
var _tantor_dash_from: Vector2 = Vector2.ZERO
var _tantor_dash_to: Vector2 = Vector2.ZERO
var _tantor_dash_flash: float = 0.0
# Visual flash timers
var _tantor_flash: float = 0.0
var _mangani_flash: float = 0.0
var _opar_flash: float = 0.0
var _legend_allies: Array = []

const STAT_UPGRADE_INTERVAL: float = 8000.0
const ABILITY_THRESHOLD: float = 28000.0
var stat_upgrade_level: int = 0
var ability_chosen: bool = false
var awaiting_ability_choice: bool = false
const TIER_NAMES = [
	"Vine Swing",
	"Ape Strength",
	"Animal Call",
	"King of the Apes"
]
const ABILITY_DESCRIPTIONS = [
	"Vine swing AoE smash — powerful ground pound",
	"Ape strength — +6% damage boost",
	"Call an ape ally for 15s every other wave",
	"3 more apes join — throw enemies back to start"
]
const TIER_COSTS = [160, 350, 600, 1200]
var is_selected: bool = false
var base_cost: int = 0

# Attack sounds — primal impact thud + grunt
var _attack_sounds: Array = []
var _attack_sounds_by_tier: Array = []
var _attack_player: AudioStreamPlayer

# Ability sounds
var _yell_sound: AudioStreamWAV
var _yell_player: AudioStreamPlayer
var _vine_smash_sound: AudioStreamWAV
var _vine_smash_player: AudioStreamPlayer
var _upgrade_sound: AudioStreamWAV
var _upgrade_player: AudioStreamPlayer
var _game_font: Font
var _main_node: Node2D = null

func _ready() -> void:
	_main_node = get_tree().get_first_node_in_group("main")
	_game_font = load("res://fonts/Cinzel.ttf")
	add_to_group("towers")
	_load_progressive_abilities()
	_generate_tier_sounds()
	_attack_sounds = _attack_sounds_by_tier[0]
	_attack_player = AudioStreamPlayer.new()
	_attack_player.stream = _attack_sounds[0]
	_attack_player.volume_db = -14.0
	add_child(_attack_player)

	# Jungle yell — primal ascending howl (A2→E3→A3→E4)
	var yell_rate := 22050
	var yell_dur := 0.8
	var yell_samples := PackedFloat32Array()
	yell_samples.resize(int(yell_rate * yell_dur))
	var yell_notes := [110.0, 164.81, 220.0, 329.63]  # A2, E3, A3, E4
	var yell_note_len := int(yell_rate * yell_dur) / 4
	for i in yell_samples.size():
		var t := float(i) / yell_rate
		var ni := mini(i / yell_note_len, 3)
		var nt := float(i - ni * yell_note_len) / float(yell_rate)
		var freq: float = yell_notes[ni]
		var att := minf(nt * 40.0, 1.0)
		var dec := exp(-nt * 4.0)
		var env := att * dec * 0.5
		# Rough vocal quality — fundamental + odd harmonics + noise
		var s := sin(TAU * freq * t) * 0.6
		s += sin(TAU * freq * 2.0 * t) * 0.25
		s += sin(TAU * freq * 3.0 * t) * 0.15
		s += sin(TAU * freq * 5.0 * t) * 0.08
		# Vocal roughness — slight noise component
		s += (randf() * 2.0 - 1.0) * 0.12 * exp(-nt * 6.0)
		yell_samples[i] = clampf(s * env, -1.0, 1.0)
	_yell_sound = _samples_to_wav(yell_samples, yell_rate)
	_yell_player = AudioStreamPlayer.new()
	_yell_player.stream = _yell_sound
	_yell_player.volume_db = -12.0
	add_child(_yell_player)

	# Vine smash — deep D minor whoosh into heavy impact thud
	var vs_rate := 22050
	var vs_dur := 0.35
	var vs_samples := PackedFloat32Array()
	vs_samples.resize(int(vs_rate * vs_dur))
	for i in vs_samples.size():
		var t := float(i) / vs_rate
		# Whoosh — descending filtered noise sweep
		var whoosh_freq := 800.0 * exp(-t * 12.0) + 80.0
		var whoosh := sin(TAU * whoosh_freq * t) * 0.2 * exp(-t * 6.0)
		whoosh += (randf() * 2.0 - 1.0) * 0.15 * exp(-t * 8.0)
		# Heavy impact thud in D2 (73.42 Hz) — hits at t=0.08
		var imp_t := t - 0.08
		var thud := 0.0
		if imp_t > 0.0:
			var imp_env := exp(-imp_t * 18.0) * 0.5
			thud = sin(TAU * 73.42 * imp_t) * 0.7 * imp_env
			thud += sin(TAU * 73.42 * 2.0 * imp_t) * 0.15 * exp(-imp_t * 25.0)
			# Sub-bass punch
			thud += sin(TAU * 36.71 * imp_t) * 0.25 * exp(-imp_t * 10.0)
			# Woody crack transient
			thud += (randf() * 2.0 - 1.0) * exp(-imp_t * 80.0) * 0.2
		vs_samples[i] = clampf(whoosh + thud, -1.0, 1.0)
	_vine_smash_sound = _samples_to_wav(vs_samples, vs_rate)
	_vine_smash_player = AudioStreamPlayer.new()
	_vine_smash_player.stream = _vine_smash_sound
	_vine_smash_player.volume_db = -10.0
	add_child(_vine_smash_player)

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
	_upgrade_player.volume_db = -10.0
	add_child(_upgrade_player)

func _process(delta: float) -> void:
	_time += delta
	if _build_timer > 0.0: _build_timer -= delta
	fire_cooldown -= delta
	_upgrade_flash = max(_upgrade_flash - delta * 0.5, 0.0)
	_ability_flash = max(_ability_flash - delta * 2.0, 0.0)
	_attack_anim = max(_attack_anim - delta * 3.0, 0.0)
	_smash_flash = max(_smash_flash - delta * 2.0, 0.0)
	target = _find_nearest_enemy()

	if not _vine_swing_active:
		if target:
			var desired = global_position.angle_to_point(target.global_position) + PI
			aim_angle = lerp_angle(aim_angle, desired, 10.0 * delta)
			_draw_progress = min(_draw_progress + delta * 3.0, 1.0)
			if fire_cooldown <= 0.0:
				_attack()
				fire_cooldown = 1.0 / (fire_rate * _speed_mult())
				_draw_progress = 0.0
				_attack_anim = 1.0
		else:
			_draw_progress = max(_draw_progress - delta * 2.0, 0.0)

	# Vine swing animation update
	_update_vine_swing(delta)

	# Ape call timer (delay after wave start)
	if _ape_call_timer > 0.0:
		_ape_call_timer -= delta
		if _ape_call_timer <= 0.0:
			_spawn_ape_allies()

	# Process animal allies — move toward enemies, punch them
	var to_remove: Array = []
	var enemies = (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies"))
	for i in range(_animal_allies.size()):
		_animal_allies[i]["timer"] -= delta
		_animal_allies[i]["punch_anim"] = maxf(_animal_allies[i]["punch_anim"] - delta * 4.0, 0.0)
		if _animal_allies[i]["timer"] <= 0.0:
			to_remove.append(i)
		else:
			# Find nearest enemy to chase
			var ape_pos: Vector2 = _animal_allies[i]["pos"]
			var nearest_enemy: Node2D = null
			var nearest_dist: float = 999999.0
			for enemy in enemies:
				if is_instance_valid(enemy):
					if enemy.has_method("is_targetable") and not enemy.is_targetable():
						continue
					var d = ape_pos.distance_to(enemy.global_position)
					if d < nearest_dist:
						nearest_dist = d
						nearest_enemy = enemy
			# Move toward nearest enemy (or back to tower if none)
			if nearest_enemy and is_instance_valid(nearest_enemy):
				_animal_allies[i]["target_pos"] = nearest_enemy.global_position
				var dir = ape_pos.direction_to(nearest_enemy.global_position)
				_animal_allies[i]["facing"] = 1.0 if dir.x >= 0 else -1.0
				var move_speed = 120.0
				if nearest_dist > 18.0:
					_animal_allies[i]["pos"] = ape_pos + dir * move_speed * delta
			else:
				# Idle — drift back toward tower
				var home = global_position + Vector2.from_angle(_animal_allies[i]["angle"]) * 30.0
				_animal_allies[i]["pos"] = ape_pos.lerp(home, 2.0 * delta)
			# Attack when close enough
			_animal_allies[i]["attack_cd"] -= delta
			if _animal_allies[i]["attack_cd"] <= 0.0 and nearest_enemy and is_instance_valid(nearest_enemy) and nearest_dist < 25.0:
				if nearest_enemy.has_method("take_damage"):
					var ally_dmg = damage * 0.6 * _damage_mult()
					if prog_abilities[4]:
						ally_dmg *= 1.5
					nearest_enemy.take_damage(ally_dmg, "physical")
					register_damage(ally_dmg)
					# Punch animation
					_animal_allies[i]["punch_anim"] = 1.0
					_animal_allies[i]["punch_dir"] = ape_pos.angle_to_point(nearest_enemy.global_position) + PI
					# Tier 4 apes throw enemies back toward start
					if _animal_allies[i].get("throwback", false) and is_instance_valid(nearest_enemy) and "progress" in nearest_enemy:
						nearest_enemy.progress = maxf(0.0, nearest_enemy.progress - 50.0)
				_animal_allies[i]["attack_cd"] = 1.2
	to_remove.reverse()
	for idx in to_remove:
		_animal_allies.remove_at(idx)

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

	# Prog ability 2: Ape Agility — 15% chance to gain +30% attack speed for 5s
	if prog_abilities[1] and not _ape_agility_active and randf() < 0.15:
		_ape_agility_active = true
		_ape_agility_timer = 5.0

	# Tier 1+: Vine Swing AoE smash
	if upgrade_tier >= 1:
		_start_vine_swing()
		return

	# Tier 0: Basic melee hit
	var dist_to_target = global_position.distance_to(target.global_position)
	var base_melee_range = attack_range * _range_mult()
	if dist_to_target <= base_melee_range:
		_melee_hit(target)

func _melee_hit(t: Node2D) -> void:
	if not is_instance_valid(t) or not t.has_method("take_damage"):
		return
	var dmg = damage * _damage_mult()
	# Prog ability 1: Jungle Instinct — +20% damage
	if prog_abilities[0]:
		dmg *= 1.2

	var will_kill = t.health - dmg <= 0.0
	t.take_damage(dmg, "physical")
	register_damage(dmg)
	if will_kill:
		register_kill()
		if gold_bonus > 0:
			var main = get_tree().get_first_node_in_group("main")
			if main:
				main.add_gold(int(gold_bonus * _gold_mult()))

	# Prog ability 3: Vine Master — pull enemies closer
	if prog_abilities[2] and is_instance_valid(t):
		var pull_dir = t.global_position.direction_to(global_position)
		t.global_position += pull_dir * 30.0

# === VINE SWING AoE SYSTEM ===

func _start_vine_swing() -> void:
	_vine_swing_active = true
	_vine_swing_phase = 0.0
	if target:
		_vine_swing_start_angle = global_position.angle_to_point(target.global_position) + PI
	else:
		_vine_swing_start_angle = aim_angle

func _update_vine_swing(delta: float) -> void:
	if not _vine_swing_active:
		return
	# Total swing duration ~0.8 seconds
	_vine_swing_phase += delta * 1.25  # 0 to 1 over 0.8s
	if _vine_swing_phase >= 1.0:
		_vine_swing_phase = 1.0
		_vine_swing_active = false
		_vine_swing_smash()

func _vine_swing_smash() -> void:
	_smash_flash = 1.0
	_attack_anim = 1.0
	if _vine_smash_player and not _is_sfx_muted():
		_vine_smash_player.play()
	# AoE damage to ALL enemies in range
	var eff_range = attack_range * _range_mult()
	var dmg = damage * 1.5 * _damage_mult()
	# Prog ability 1: Jungle Instinct — +20% damage
	if prog_abilities[0]:
		dmg *= 1.2
	for enemy in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if global_position.distance_to(enemy.global_position) < eff_range:
			if enemy.has_method("take_damage"):
				var will_kill = enemy.health - dmg <= 0.0
				enemy.take_damage(dmg, "physical")
				register_damage(dmg)
				if will_kill:
					register_kill()
					if gold_bonus > 0:
						var main = get_tree().get_first_node_in_group("main")
						if main:
							main.add_gold(int(gold_bonus * _gold_mult()))
				# Prog ability 3: Vine Master — pull enemies closer
				if prog_abilities[2] and is_instance_valid(enemy):
					var pull_dir = enemy.global_position.direction_to(global_position)
					enemy.global_position += pull_dir * 30.0

# === APE ALLY WAVE SYSTEM ===

func on_wave_start(wave_num: int) -> void:
	if upgrade_tier < 3:
		return
	_ape_call_wave_count += 1
	# Every other wave (odd count)
	if _ape_call_wave_count % 2 == 1:
		_ape_call_timer = 3.0  # 3 second delay after wave starts

func _spawn_ape_allies() -> void:
	if _yell_player and not _is_sfx_muted():
		_yell_player.play()
	_ability_flash = 1.0
	var ally_duration = 15.0
	if prog_abilities[4]:
		ally_duration += 2.0
	# Tier 3: 1 ape ally
	var ape_count = 1
	var has_throwback = false
	# Tier 4: 3 more apes (4 total), with throwback
	if upgrade_tier >= 4 and _king_apes_active:
		ape_count = 4
		has_throwback = true
	for i in range(ape_count):
		var ally_angle = TAU * float(i) / float(ape_count)
		var spawn_offset = Vector2.from_angle(ally_angle) * 30.0
		_animal_allies.append({
			"angle": ally_angle,
			"timer": ally_duration,
			"attack_cd": 0.5,
			"type": 0,
			"throwback": has_throwback,
			"pos": global_position + spawn_offset,
			"target_pos": global_position + spawn_offset,
			"punch_anim": 0.0,
			"punch_dir": 0.0,
			"facing": 1.0,
		})

func use_ability() -> void:
	if not _has_enemies_in_range():
		return
	_ability_flash = 1.0

	if _yell_player and not _is_sfx_muted():
		_yell_player.play()

	# Stun all enemies in range for 2s
	var eff_range = attack_range * _range_mult()
	for enemy in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if global_position.distance_to(enemy.global_position) < eff_range:
			if enemy.has_method("apply_sleep"):
				enemy.apply_sleep(2.0)

func register_kill() -> void:
	kill_count += 1
	if kill_count % 8 == 0:
		var bonus = 3 + kill_count / 8
		var main = get_tree().get_first_node_in_group("main")
		if main:
			main.add_gold(bonus)
		_upgrade_flash = 1.0
		_upgrade_name = "Jungle bounty +%d!" % bonus

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
	fire_rate += 0.013
	attack_range += 3.0

func choose_ability(index: int) -> void:
	ability_chosen = true
	awaiting_ability_choice = false
	upgrade_tier = index + 1
	_apply_upgrade(upgrade_tier)
	_upgrade_flash = 3.0
	_upgrade_name = TIER_NAMES[index]

func _apply_upgrade(tier: int) -> void:
	match tier:
		1: # Vine Swing — AoE ground pound smash (slow but powerful)
			damage = 49.0
			fire_rate = 0.66
			attack_range = 130.0
		2: # Ape Strength — +6% damage boost
			damage = 52.0
			fire_rate = 0.66
			attack_range = 140.0
			gold_bonus = 2
		3: # Animal Call — 1 ape ally for 15s every other wave
			damage = 63.0
			fire_rate = 0.66
			attack_range = 150.0
			gold_bonus = 3
		4: # King of the Apes — 3 more apes, throw enemies back
			damage = 81.0
			fire_rate = 0.66
			attack_range = 160.0
			gold_bonus = 3
			_king_apes_active = true

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
	return "Tarzan"

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
	# Jungle drums in D minor — deep tonal percussion with warm harmonics
	# D minor walking bass: D2, F2, G2, A2, Bb2, C3, D3, A2
	var dm_notes := [73.42, 87.31, 98.00, 110.00, 116.54, 130.81, 146.83, 110.00]
	var mix_rate := 44100
	_attack_sounds_by_tier = []

	# --- Tier 0: Jungle Log Drum (warm tonal hit, wooden character) ---
	var t0 := []
	for note_idx in dm_notes.size():
		var freq: float = dm_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.18))
		for i in samples.size():
			var t := float(i) / mix_rate
			# Pitch drops slightly for woody character
			var f := freq * (1.0 + exp(-t * 40.0) * 0.15)
			var env := exp(-t * 14.0) * 0.5
			# Warm fundamental with soft overtones
			var drum := sin(t * f * TAU) * 0.6
			drum += sin(t * f * 2.0 * TAU) * 0.15 * exp(-t * 20.0)
			drum += sin(t * f * 3.0 * TAU) * 0.06 * exp(-t * 30.0)
			# Woody transient (short filtered click)
			var click := sin(t * f * 6.0 * TAU) * exp(-t * 200.0) * 0.2
			# Sub warmth
			var sub := sin(t * freq * 0.5 * TAU) * 0.12 * exp(-t * 10.0)
			samples[i] = clampf((drum + sub) * env + click, -1.0, 1.0)
		t0.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t0)

	# --- Tier 1: Djembe Slap (tighter attack, mid-frequency ring) ---
	var t1 := []
	for note_idx in dm_notes.size():
		var freq: float = dm_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.16))
		for i in samples.size():
			var t := float(i) / mix_rate
			var f := freq * 2.0  # One octave up for slap tone
			var env := exp(-t * 18.0) * 0.45
			# Tight slap tone
			var slap := sin(t * f * TAU) * 0.5
			slap += sin(t * f * 1.5 * TAU) * 0.2 * exp(-t * 25.0)  # Fifth harmonic color
			slap += sin(t * f * 2.0 * TAU) * 0.12 * exp(-t * 30.0)
			# Sharp transient
			var trans := sin(t * f * 4.0 * TAU) * exp(-t * 300.0) * 0.25
			# Low body underneath
			var body := sin(t * freq * TAU) * 0.2 * exp(-t * 12.0)
			samples[i] = clampf((slap * env) + trans + body * 0.4, -1.0, 1.0)
		t1.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t1)

	# --- Tier 2: War Drum (heavy hit, D minor fifth power, deep resonance) ---
	var t2 := []
	for note_idx in dm_notes.size():
		var freq: float = dm_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.22))
		for i in samples.size():
			var t := float(i) / mix_rate
			var f := freq * (1.0 + exp(-t * 50.0) * 0.1)
			var env := exp(-t * 10.0) * 0.5
			# Deep war drum with D power fifth (D + A)
			var drum := sin(t * f * TAU) * 0.55
			var fifth := sin(t * f * 1.5 * TAU) * 0.2 * exp(-t * 14.0)
			drum += sin(t * f * 2.0 * TAU) * 0.12 * exp(-t * 18.0)
			# Membrane vibration (slight pitch wobble)
			var wobble := sin(t * 6.0 * TAU) * 0.003
			drum += sin(t * f * (1.0 + wobble) * TAU) * 0.08
			# Sub boom
			var boom := sin(t * freq * 0.5 * TAU) * 0.18 * exp(-t * 7.0)
			# Impact transient
			var hit := sin(t * f * 5.0 * TAU) * exp(-t * 250.0) * 0.18
			samples[i] = clampf((drum + fifth) * env + boom * 0.4 + hit, -1.0, 1.0)
		t2.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t2)

	# --- Tier 3: Tribal Thunder Drum (double-strike, D minor chord, rich) ---
	var t3 := []
	for note_idx in dm_notes.size():
		var freq: float = dm_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.25))
		for i in samples.size():
			var t := float(i) / mix_rate
			# First strike — deep drum
			var f1 := freq * (1.0 + exp(-t * 45.0) * 0.12)
			var env1 := exp(-t * 12.0) * 0.45
			var s1 := sin(t * f1 * TAU) * 0.5
			s1 += sin(t * f1 * 2.0 * TAU) * 0.15 * exp(-t * 20.0)
			# Second strike (delayed, minor third up for Dm feel)
			var dt := t - 0.06
			var s2 := 0.0
			if dt > 0.0:
				var f2 := freq * 1.2  # Minor third interval
				s2 = sin(dt * f2 * TAU) * exp(-dt * 16.0) * 0.3
				s2 += sin(dt * f2 * 2.0 * TAU) * exp(-dt * 22.0) * 0.1
			# Sub layer
			var sub := sin(t * freq * 0.5 * TAU) * 0.15 * exp(-t * 6.0)
			# Crisp transient
			var trans := sin(t * freq * 7.0 * TAU) * exp(-t * 350.0) * 0.15
			samples[i] = clampf(s1 * env1 + s2 + sub * 0.4 + trans, -1.0, 1.0)
		t3.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t3)

	# --- Tier 4: King of the Jungle (massive Dm chord, reverberant, heroic) ---
	var t4 := []
	for note_idx in dm_notes.size():
		var freq: float = dm_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.32))
		for i in samples.size():
			var t := float(i) / mix_rate
			var f := freq * (1.0 + exp(-t * 55.0) * 0.08)
			var env := exp(-t * 7.0) * 0.45
			# Full D minor chord: root + minor third + fifth
			var root := sin(t * f * TAU) * 0.45
			var third := sin(t * f * 1.2 * TAU) * 0.2 * exp(-t * 9.0)  # Minor third
			var fifth := sin(t * f * 1.5 * TAU) * 0.18 * exp(-t * 10.0)  # Perfect fifth
			# Warm overtones
			root += sin(t * f * 2.0 * TAU) * 0.1 * exp(-t * 12.0)
			root += sin(t * f * 3.0 * TAU) * 0.05 * exp(-t * 16.0)
			# Deep sub-bass boom
			var boom := sin(t * freq * 0.5 * TAU) * 0.2 * exp(-t * 5.0)
			# Octave shimmer (heroic sparkle)
			var shim := sin(t * f * 4.0 * TAU) * 0.06 * exp(-t * 14.0)
			shim += sin(t * f * 4.005 * TAU) * 0.04 * exp(-t * 12.0)  # Chorus detune
			# Sharp attack transient
			var trans := sin(t * freq * 8.0 * TAU) * exp(-t * 300.0) * 0.15
			samples[i] = clampf((root + third + fifth + shim) * env + boom * 0.35 + trans, -1.0, 1.0)
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
	if main and main.survivor_progress.has(main.TowerType.TARZAN):
		var p = main.survivor_progress[main.TowerType.TARZAN]
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
	# Applied dynamically in _melee_hit, _speed_mult, _range_mult, and _process_progressive_abilities
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
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("register_tower_damage"):
		main.register_tower_damage(main.TowerType.TARZAN, amount)
	_check_upgrades()

func _process_progressive_abilities(delta: float) -> void:
	# Visual flash decay
	_tantor_flash = max(_tantor_flash - delta * 2.0, 0.0)
	_mangani_flash = max(_mangani_flash - delta * 2.0, 0.0)
	_opar_flash = max(_opar_flash - delta * 1.5, 0.0)
	_tantor_dash_flash = max(_tantor_dash_flash - delta * 2.0, 0.0)

	# Ability 2: Ape Agility — attack speed buff timer
	if _ape_agility_active:
		_ape_agility_timer -= delta
		if _ape_agility_timer <= 0.0:
			_ape_agility_active = false
			_ape_agility_timer = 0.0

	# Ability 6: Predator Sense — reveal shadow-infested enemies in range
	if prog_abilities[5]:
		var sense_range = attack_range * _range_mult()
		# Clean up enemies that left range or are no longer valid
		var still_revealed: Array = []
		for e in _predator_sense_revealed:
			if is_instance_valid(e) and global_position.distance_to(e.global_position) < sense_range:
				still_revealed.append(e)
			elif is_instance_valid(e):
				# Re-apply shadow infested when leaving range
				e.is_shadow_infested = true
		_predator_sense_revealed = still_revealed
		# Reveal new shadow-infested enemies entering range
		for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
			if is_instance_valid(e) and "is_shadow_infested" in e and e.is_shadow_infested:
				if global_position.distance_to(e.global_position) < sense_range:
					e.is_shadow_infested = false
					_predator_sense_revealed.append(e)

	# Ability 4: Tantor's Charge — periodic charge attack
	if prog_abilities[3]:
		_tantor_charge_timer -= delta
		if _tantor_charge_timer <= 0.0 and _has_enemies_in_range():
			_tantor_charge()
			_tantor_charge_timer = 15.0

	# Ability 6: Predator Sense — +25% range (applied as passive)
	# (Range boost applied in _range_mult)

	# Ability 7: Mangani War Cry — stun all on screen
	if prog_abilities[6]:
		_mangani_cry_timer -= delta
		if _mangani_cry_timer <= 0.0 and _has_enemies_in_range():
			_mangani_war_cry()
			_mangani_cry_timer = 20.0

	# Ability 8: Lord of Opar — golden vine strike all in range
	if prog_abilities[7]:
		_opar_strike_timer -= delta
		if _opar_strike_timer <= 0.0 and _has_enemies_in_range():
			_opar_strike()
			_opar_strike_timer = 25.0

	# Ability 9: Legend of the Jungle — permanent 3 animal allies
	if prog_abilities[8]:
		while _legend_allies.size() < 3:
			var ally_angle = TAU * float(_legend_allies.size()) / 3.0
			_legend_allies.append({
				"angle": ally_angle,
				"attack_cd": 0.8
			})
		# Permanent allies attack — aura damage doubled (2x) per description
		for ally in _legend_allies:
			ally["attack_cd"] -= delta
			ally["angle"] += delta * 1.0
			if ally["attack_cd"] <= 0.0:
				var nearest = _find_nearest_enemy()
				if nearest and nearest.has_method("take_damage"):
					var dmg = damage * 1.0 * _damage_mult()  # 0.5 base * 2.0 aura doubling
					nearest.take_damage(dmg, "physical")
					register_damage(dmg)
				ally["attack_cd"] = 1.0

func _tantor_charge() -> void:
	_tantor_flash = 1.0
	var nearest = _find_nearest_enemy()
	if nearest and nearest.has_method("take_damage"):
		# Store dash positions for visual trail
		_tantor_dash_from = Vector2.ZERO  # Local coords (tower center)
		_tantor_dash_to = nearest.global_position - global_position
		_tantor_dash_flash = 1.0
		var dmg = damage * 4.0 * _damage_mult()
		nearest.take_damage(dmg, "physical")
		register_damage(dmg)
		if nearest.has_method("apply_sleep"):
			nearest.apply_sleep(1.5)

func _mangani_war_cry() -> void:
	_mangani_flash = 1.0
	if _yell_player and not _is_sfx_muted():
		_yell_player.play()
	var cry_range = attack_range * _range_mult() * 2.5
	for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if global_position.distance_to(e.global_position) < cry_range:
			if e.has_method("apply_sleep"):
				e.apply_sleep(1.0)

func _opar_strike() -> void:
	_opar_flash = 1.0
	var eff_range = attack_range * _range_mult()
	for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if global_position.distance_to(e.global_position) < eff_range:
			if e.has_method("take_damage"):
				var dmg = damage * 6.0 * _damage_mult()
				e.take_damage(dmg, "physical")
				register_damage(dmg)

func _draw() -> void:
	# Build animation — elastic scale-in
	if _build_timer > 0.0:
		var bt = 1.0 - clampf(_build_timer / 0.5, 0.0, 1.0)
		var elastic = 1.0 + sin(bt * PI * 2.5) * 0.3 * (1.0 - bt)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(elastic, elastic))

	# === 1. SELECTION RING + RANGE ===
	var eff_range = attack_range * _range_mult()
	if is_selected:
		var pulse = (sin(_time * 3.0) + 1.0) * 0.5
		var ring_alpha = 0.5 + pulse * 0.3
		# Full range circle when selected
		draw_circle(Vector2.ZERO, eff_range, Color(1.0, 1.0, 1.0, 0.04))
		draw_arc(Vector2.ZERO, eff_range, 0, TAU, 64, Color(1.0, 0.84, 0.0, 0.25 + pulse * 0.15), 2.0)
		draw_arc(Vector2.ZERO, 40.0, 0, TAU, 48, Color(1.0, 0.84, 0.0, ring_alpha), 2.5)
		draw_arc(Vector2.ZERO, 43.0, 0, TAU, 48, Color(1.0, 0.84, 0.0, ring_alpha * 0.4), 1.5)
	else:
		# === 2. RANGE ARC (subtle) ===
		draw_arc(Vector2.ZERO, eff_range, 0, TAU, 64, Color(1, 1, 1, 0.06), 1.0)

	# === 3. AIM DIRECTION ===
	var dir = Vector2.from_angle(aim_angle)
	var perp = dir.rotated(PI / 2.0)

	# === 4. IDLE ANIMATION (primal weight shift) ===
	var bounce = abs(sin(_time * 2.5)) * 3.0
	var breathe = sin(_time * 1.8) * 2.5
	var weight_shift = sin(_time * 1.0) * 3.0  # Heavy primal weight shift
	var bob = Vector2(weight_shift, -bounce - breathe)

	# Tier 4: King of the Apes — slight hover from primal energy
	var fly_offset = Vector2.ZERO
	if upgrade_tier >= 4:
		fly_offset = Vector2(0, -4.0 + sin(_time * 1.3) * 1.5)

	var body_offset = bob + fly_offset

	# Per-joint differential offsets
	var hip_shift = sin(_time * 1.0) * 2.0
	var shoulder_counter = -sin(_time * 1.0) * 1.2  # Counter-sway shoulders

	# Fist punch anim
	var punch_extend = 0.0
	if _attack_anim > 0.3:
		punch_extend = sin(_attack_anim * 6.0) * 8.0 * _attack_anim

	# === 5. SKIN COLORS (Tarzan's tanned skin) ===
	var skin_base = Color(0.82, 0.62, 0.42)
	var skin_shadow = Color(0.68, 0.48, 0.32)
	var skin_highlight = Color(0.90, 0.72, 0.52)

	# === 6. UPGRADE FLASH ===
	if _upgrade_flash > 0.0:
		draw_circle(Vector2.ZERO, 80.0 + _upgrade_flash * 24.0, Color(0.2, 0.6, 0.1, _upgrade_flash * 0.25))

	# === 7. ABILITY FLASH (ape allies summoned) ===
	if _ability_flash > 0.0:
		var ring_r = 36.0 + (1.0 - _ability_flash) * 80.0
		draw_circle(Vector2.ZERO, ring_r, Color(0.3, 0.7, 0.1, _ability_flash * 0.15))
		draw_arc(Vector2.ZERO, ring_r, 0, TAU, 32, Color(0.4, 0.8, 0.2, _ability_flash * 0.3), 2.5)
		for hi in range(10):
			var ha = TAU * float(hi) / 10.0 + _ability_flash * 3.0
			var h_inner = Vector2.from_angle(ha) * (ring_r * 0.4)
			var h_outer = Vector2.from_angle(ha) * (ring_r + 5.0)
			draw_line(h_inner, h_outer, Color(0.3, 0.8, 0.15, _ability_flash * 0.4), 1.5)

	# === SMASH FLASH (vine swing ground pound impact) ===
	if _smash_flash > 0.0:
		# Expanding shockwave ring — 25% larger radius
		var sw_r = 25.0 + (1.0 - _smash_flash) * 100.0
		draw_arc(Vector2.ZERO, sw_r, 0, TAU, 48, Color(0.85, 0.65, 0.2, _smash_flash * 0.5), 4.0)
		draw_arc(Vector2.ZERO, sw_r * 0.7, 0, TAU, 32, Color(1.0, 0.85, 0.3, _smash_flash * 0.3), 2.5)
		draw_arc(Vector2.ZERO, sw_r * 0.4, 0, TAU, 24, Color(1.0, 0.9, 0.4, _smash_flash * 0.2), 1.5)
		# Radial crack lines — more detail with forking
		for ci in range(16):
			var ca = TAU * float(ci) / 16.0 + _smash_flash * 2.0
			var c_inner = Vector2.from_angle(ca) * 6.0
			var c_outer = Vector2.from_angle(ca) * (sw_r * 0.95)
			draw_line(c_inner, c_outer, Color(0.6, 0.4, 0.15, _smash_flash * 0.4), 2.5)
			# Fork branches on every other crack line
			if ci % 2 == 0:
				var fork_pt = Vector2.from_angle(ca) * (sw_r * 0.55)
				var fork_a1 = ca + 0.25
				var fork_a2 = ca - 0.25
				var fork_end1 = fork_pt + Vector2.from_angle(fork_a1) * (sw_r * 0.35)
				var fork_end2 = fork_pt + Vector2.from_angle(fork_a2) * (sw_r * 0.3)
				draw_line(fork_pt, fork_end1, Color(0.55, 0.35, 0.12, _smash_flash * 0.3), 1.5)
				draw_line(fork_pt, fork_end2, Color(0.55, 0.35, 0.12, _smash_flash * 0.25), 1.2)
		# Dust cloud particles
		for di in range(10):
			var da = TAU * float(di) / 10.0 + _time * 1.5
			var d_r = sw_r * (0.3 + sin(_time * 4.0 + float(di)) * 0.2)
			var dp = Vector2.from_angle(da) * d_r
			draw_circle(dp, 5.0 + _smash_flash * 4.0, Color(0.55, 0.42, 0.25, _smash_flash * 0.25))
		# Ground impact flash — larger
		draw_circle(Vector2.ZERO, 20.0 * _smash_flash, Color(1.0, 0.9, 0.5, _smash_flash * 0.35))

	# === VINE SWING ANIMATION (tier 1+) ===
	if _vine_swing_active and upgrade_tier >= 1:
		var swing_angle = _vine_swing_start_angle + _vine_swing_phase * TAU * 0.75  # Swing 270 degrees
		var swing_r = attack_range * 0.5
		var swing_height = 0.0
		if _vine_swing_phase < 0.6:
			# Swinging phase: arc around
			swing_height = -30.0 - sin(_vine_swing_phase / 0.6 * PI) * 20.0
		elif _vine_swing_phase < 0.8:
			# Rising up phase
			var rise_t = (_vine_swing_phase - 0.6) / 0.2
			swing_height = -50.0 - rise_t * 30.0
		else:
			# Smashing down phase
			var smash_t = (_vine_swing_phase - 0.8) / 0.2
			swing_height = -80.0 + smash_t * 80.0
		var swing_pos = Vector2.from_angle(swing_angle) * swing_r * minf(_vine_swing_phase * 3.0, 1.0)
		swing_pos.y += swing_height
		# Vine line from top of screen to Tarzan
		var vine_anchor = Vector2(swing_pos.x * 0.3, -200.0)
		draw_line(vine_anchor, swing_pos, Color(0.14, 0.50, 0.10, 0.7), 3.0)
		draw_line(vine_anchor, swing_pos, Color(0.22, 0.62, 0.18, 0.4), 1.5)
		# Tarzan silhouette at swing position (small circle with fists)
		draw_circle(swing_pos, 8.0, Color(0.78, 0.56, 0.36, 0.6))
		draw_circle(swing_pos + Vector2(0, -6), 6.0, Color(0.32, 0.18, 0.08, 0.5))
		# Double fists below if smashing down
		if _vine_swing_phase > 0.8:
			var fist_y = swing_pos + Vector2(0, 10.0)
			draw_circle(fist_y + Vector2(-4, 0), 4.0, Color(0.78, 0.56, 0.36, 0.7))
			draw_circle(fist_y + Vector2(4, 0), 4.0, Color(0.78, 0.56, 0.36, 0.7))

	# === PROGRESSIVE ABILITY VISUAL EFFECTS ===

	# Ability 2: Ape Agility active indicator (green speed lines)
	if _ape_agility_active:
		var agility_pulse = sin(_time * 6.0) * 0.15 + 0.35
		for ai in range(4):
			var aa = _time * 3.0 + float(ai) * TAU / 4.0
			var a_start = Vector2.from_angle(aa) * 18.0
			var a_end = Vector2.from_angle(aa) * 28.0
			draw_line(a_start, a_end, Color(0.2, 0.8, 0.3, agility_pulse), 2.0)

	# Ability 4: Tantor's Charge flash
	if _tantor_flash > 0.0:
		var tc_r = 25.0 + (1.0 - _tantor_flash) * 60.0
		draw_arc(Vector2.ZERO, tc_r, 0, TAU, 24, Color(0.5, 0.4, 0.3, _tantor_flash * 0.4), 3.5)
		draw_arc(Vector2.ZERO, tc_r * 0.6, 0, TAU, 16, Color(0.6, 0.5, 0.3, _tantor_flash * 0.3), 2.5)

	# Ability 4: Tantor's Charge — visual dash trail with dust clouds
	if _tantor_dash_flash > 0.0:
		var dash_alpha = _tantor_dash_flash * 0.5
		var dash_dir = (_tantor_dash_to - _tantor_dash_from)
		var dash_len = dash_dir.length()
		if dash_len > 1.0:
			var dash_norm = dash_dir / dash_len
			var dash_perp = dash_norm.rotated(PI / 2.0)
			# Main charge line (thick brown trail)
			draw_line(_tantor_dash_from, _tantor_dash_to, Color(0.6, 0.4, 0.2, dash_alpha), 4.0)
			draw_line(_tantor_dash_from, _tantor_dash_to, Color(0.8, 0.6, 0.3, dash_alpha * 0.6), 2.0)
			# Speed lines flanking the trail
			for si in range(3):
				var sl_t = 0.2 + float(si) * 0.3
				var sl_pos = _tantor_dash_from.lerp(_tantor_dash_to, sl_t)
				var sl_off = dash_perp * (8.0 + float(si) * 3.0)
				draw_line(sl_pos + sl_off, sl_pos + sl_off - dash_norm * 12.0, Color(0.7, 0.5, 0.25, dash_alpha * 0.4), 1.5)
				draw_line(sl_pos - sl_off, sl_pos - sl_off - dash_norm * 12.0, Color(0.7, 0.5, 0.25, dash_alpha * 0.4), 1.5)
			# Dust clouds along the trail
			for di in range(5):
				var dt = float(di) / 4.0
				var dp = _tantor_dash_from.lerp(_tantor_dash_to, dt)
				var dust_off_x = sin(_time * 4.0 + float(di) * 2.1) * 6.0
				var dust_off_y = cos(_time * 3.5 + float(di) * 1.7) * 4.0
				var dust_pos = dp + Vector2(dust_off_x, dust_off_y)
				var dust_size = 4.0 + (1.0 - _tantor_dash_flash) * 6.0
				draw_circle(dust_pos, dust_size, Color(0.55, 0.42, 0.25, dash_alpha * 0.35))
				draw_circle(dust_pos, dust_size * 0.6, Color(0.65, 0.52, 0.30, dash_alpha * 0.2))
			# Impact circle at target
			var impact_r = 12.0 + (1.0 - _tantor_dash_flash) * 20.0
			draw_arc(_tantor_dash_to, impact_r, 0, TAU, 16, Color(0.6, 0.4, 0.2, dash_alpha * 0.6), 3.0)

	# Ability 6: Predator Sense — subtle pulse showing detection range
	if prog_abilities[5]:
		var sense_pulse = sin(_time * 2.0) * 0.03 + 0.05
		var sense_r = attack_range * _range_mult()
		draw_arc(Vector2.ZERO, sense_r, 0, TAU, 32, Color(0.9, 0.3, 0.1, sense_pulse), 1.5)
		# Eye icons on revealed enemies direction
		for re in _predator_sense_revealed:
			if is_instance_valid(re):
				var re_dir = (re.global_position - global_position).normalized()
				var re_pos = re_dir * 20.0
				draw_circle(re_pos, 2.0, Color(0.9, 0.3, 0.1, 0.4 + sin(_time * 4.0) * 0.15))

	# Ability 7: Mangani War Cry flash
	if _mangani_flash > 0.0:
		var mc_r = 40.0 + (1.0 - _mangani_flash) * 100.0
		draw_arc(Vector2.ZERO, mc_r, 0, TAU, 32, Color(0.6, 0.3, 0.1, _mangani_flash * 0.3), 3.0)
		for mi in range(6):
			var ma = TAU * float(mi) / 6.0 + _mangani_flash * 4.0
			draw_line(Vector2.from_angle(ma) * 20.0, Vector2.from_angle(ma) * mc_r, Color(0.7, 0.4, 0.1, _mangani_flash * 0.25), 2.0)

	# Ability 8: Lord of Opar flash — golden vines
	if _opar_flash > 0.0:
		for oi in range(8):
			var oa = TAU * float(oi) / 8.0 + _time * 0.5
			var o_len = 60.0 + (1.0 - _opar_flash) * 40.0
			var o_start = Vector2.from_angle(oa) * 15.0
			var o_end = Vector2.from_angle(oa) * o_len
			draw_line(o_start, o_end, Color(0.85, 0.72, 0.2, _opar_flash * 0.4), 2.5)
			draw_line(o_start, o_end, Color(1.0, 0.9, 0.4, _opar_flash * 0.2), 1.2)

	# === 8. JUNGLE VINE PLATFORM ===
	var plat_y = 22.0
	# Platform shadow
	draw_circle(Vector2(0, plat_y + 4), 28.0, Color(0, 0, 0, 0.15))
	# Stone base (mossy)
	draw_set_transform(Vector2(0, plat_y), 0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 28.0, Color(0.22, 0.20, 0.16))
	draw_circle(Vector2.ZERO, 25.0, Color(0.30, 0.28, 0.22))
	draw_circle(Vector2.ZERO, 20.0, Color(0.35, 0.34, 0.28))
	# Moss patches
	for si in range(8):
		var sa = TAU * float(si) / 8.0
		draw_circle(Vector2.from_angle(sa) * 16.0, 3.5, Color(0.18, 0.38, 0.12, 0.5))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# Top highlight
	draw_set_transform(Vector2(0, plat_y - 2), 0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 22.0, Color(0.38, 0.36, 0.30, 0.3))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# Vines wrapping around the stone platform
	for vi in range(6):
		var va = TAU * float(vi) / 6.0 + _time * 0.1
		var v_base = Vector2(cos(va) * 24.0, plat_y + sin(va) * 8.0)
		var vine_wave = sin(_time * 0.6 + float(vi) * 1.2) * 3.0
		var v_end = v_base + Vector2(vine_wave, -8.0 - sin(_time * 0.8 + float(vi)) * 3.0)
		draw_line(v_base, v_end, Color(0.15, 0.42, 0.08), 2.5)
		draw_line(v_base, v_end, Color(0.22, 0.52, 0.14, 0.4), 1.5)
		# Tiny leaves on vines
		if vi % 2 == 0:
			var leaf_pt = v_base.lerp(v_end, 0.6)
			var ld = Vector2.from_angle(_time * 1.5 + float(vi))
			draw_line(leaf_pt, leaf_pt + ld * 3.0, Color(0.2, 0.5, 0.12, 0.6), 1.5)
			draw_line(leaf_pt, leaf_pt + ld.rotated(0.8) * 2.5, Color(0.25, 0.55, 0.15, 0.4), 1.0)

	# === 9. TIER PIPS (jungle/bone/gold) ===
	for i in range(upgrade_tier):
		var pip_angle = -PI / 2.0 + float(i) * (TAU / 4.0) - (float(upgrade_tier - 1) * TAU / 8.0)
		var pip_pos = Vector2(cos(pip_angle) * 22.0, plat_y + sin(pip_angle) * 8.0)
		var pip_col: Color
		match i:
			0: pip_col = Color(0.2, 0.55, 0.15)    # vine green
			1: pip_col = Color(0.78, 0.72, 0.58)    # bone white
			2: pip_col = Color(0.6, 0.45, 0.2)      # amber
			3: pip_col = Color(0.85, 0.72, 0.25)    # jungle gold
		draw_circle(pip_pos, 4.0, pip_col)
		draw_circle(pip_pos, 5.5, Color(pip_col.r, pip_col.g, pip_col.b, 0.15))

	# === 10. APE ALLIES (BUFF GORILLAS — massive muscular silverbacks) ===
	var OL = Color(0.06, 0.06, 0.08)
	for ally in _animal_allies:
		var ally_world: Vector2 = ally["pos"]
		var ally_pos = ally_world - global_position  # Convert to local coords
		var is_king_ape = ally.get("throwback", false)
		var facing: float = ally.get("facing", 1.0)
		var punch: float = ally.get("punch_anim", 0.0)
		var ape_scale = 1.6 if is_king_ape else 1.25
		# BUFF gorilla — massive wide frame
		var body_w = 13.0 * ape_scale
		var body_h = 15.0 * ape_scale
		var head_sz = 8.0 * ape_scale
		# Walking bob animation — heavy stomp
		var walk_cycle = sin(_time * 5.0 + ally["angle"] * 3.0)
		var bob_y = abs(walk_cycle) * 3.0
		var ap = ally_pos + Vector2(0, -bob_y)
		# Muscle flex animation
		var flex = sin(_time * 2.5 + ally["angle"]) * 0.15 + 0.85
		# Ground dust cloud when stomping
		if abs(walk_cycle) > 0.9:
			for dci in range(3):
				var dust_off = Vector2((randf() - 0.5) * 12.0 * ape_scale, body_h * 0.6 + 2.0)
				var dust_a = (abs(walk_cycle) - 0.9) * 5.0
				draw_circle(ap + dust_off, 3.0 * ape_scale, Color(0.5, 0.4, 0.25, dust_a * 0.2))
		# Golden glow for tier 4 throwback apes — more intense
		if is_king_ape:
			draw_circle(ap, body_w + 10.0, Color(0.85, 0.72, 0.25, 0.15 + sin(_time * 3.0) * 0.08))
			draw_circle(ap, body_w + 6.0, Color(1.0, 0.85, 0.3, 0.08 + sin(_time * 4.5) * 0.04))
		# Punch impact flash — bigger, with shockwave
		if punch > 0.5:
			var flash_dir = Vector2.from_angle(ally.get("punch_dir", 0.0))
			var flash_pos = ap + flash_dir * (body_w + 10.0)
			var flash_a = (punch - 0.5) * 2.0
			draw_circle(flash_pos, 14.0 * flash_a, Color(1.0, 0.85, 0.2, flash_a * 0.3))
			draw_circle(flash_pos, 8.0 * flash_a, Color(1.0, 0.9, 0.3, flash_a * 0.5))
			draw_circle(flash_pos, 4.0 * flash_a, Color(1.0, 1.0, 0.8, flash_a * 0.4))
			# Shockwave ring
			var ring_r = 12.0 + (1.0 - flash_a) * 20.0
			draw_arc(flash_pos, ring_r, 0, TAU, 16, Color(1.0, 0.9, 0.4, flash_a * 0.3), 2.0)
		# === Legs (thick, muscular, powerful) ===
		var leg_stride = walk_cycle * 5.0 * ape_scale
		var l_foot = ap + Vector2(-5.0 * facing, body_h * 0.55 + leg_stride)
		var r_foot = ap + Vector2(5.0 * facing, body_h * 0.55 - leg_stride)
		var l_hip = ap + Vector2(-4.0 * facing, body_h * 0.1)
		var r_hip = ap + Vector2(4.0 * facing, body_h * 0.1)
		var l_knee = l_hip.lerp(l_foot, 0.5) + Vector2(-2.0 * facing, -1.0)
		var r_knee = r_hip.lerp(r_foot, 0.5) + Vector2(2.0 * facing, -1.0)
		# Thick thighs
		draw_line(l_hip, l_knee, OL, 7.0 * ape_scale)
		draw_line(l_hip, l_knee, Color(0.30, 0.18, 0.08), 5.5 * ape_scale)
		draw_line(l_knee, l_foot, OL, 6.0 * ape_scale)
		draw_line(l_knee, l_foot, Color(0.28, 0.16, 0.07), 4.5 * ape_scale)
		draw_line(r_hip, r_knee, OL, 7.0 * ape_scale)
		draw_line(r_hip, r_knee, Color(0.30, 0.18, 0.08), 5.5 * ape_scale)
		draw_line(r_knee, r_foot, OL, 6.0 * ape_scale)
		draw_line(r_knee, r_foot, Color(0.28, 0.16, 0.07), 4.5 * ape_scale)
		# Quad muscle bulge
		draw_circle(l_hip.lerp(l_knee, 0.4) + Vector2(-1.0, 0), 3.5 * ape_scale, Color(0.34, 0.21, 0.10, 0.5))
		draw_circle(r_hip.lerp(r_knee, 0.4) + Vector2(1.0, 0), 3.5 * ape_scale, Color(0.34, 0.21, 0.10, 0.5))
		# Big feet — flat, wide, knuckle-walking
		draw_circle(l_foot, 3.5 * ape_scale, OL)
		draw_circle(l_foot, 2.5 * ape_scale, Color(0.22, 0.13, 0.05))
		draw_circle(r_foot, 3.5 * ape_scale, OL)
		draw_circle(r_foot, 2.5 * ape_scale, Color(0.22, 0.13, 0.05))
		# Toe knuckles
		for ti in range(3):
			var toe_off = Vector2((-1.0 + float(ti)) * 2.0 * ape_scale, 2.0 * ape_scale)
			draw_circle(l_foot + toe_off, 1.2 * ape_scale, Color(0.20, 0.12, 0.05))
			draw_circle(r_foot + toe_off, 1.2 * ape_scale, Color(0.20, 0.12, 0.05))
		# === Body (massive V-taper, wide shoulders tapering to waist) ===
		# Outline — wider at top
		var torso_top = ap + Vector2(0, -body_w * 0.35)
		var torso_bot = ap + Vector2(0, body_h * 0.1)
		# Wide back/lats shape (trapezoid)
		var back_pts = PackedVector2Array([
			ap + Vector2(-body_w * 1.1, -body_w * 0.4),
			ap + Vector2(body_w * 1.1, -body_w * 0.4),
			ap + Vector2(body_w * 0.7, body_h * 0.15),
			ap + Vector2(-body_w * 0.7, body_h * 0.15),
		])
		draw_colored_polygon(back_pts, OL)
		var back_inner = PackedVector2Array([
			ap + Vector2(-body_w * 0.95, -body_w * 0.35),
			ap + Vector2(body_w * 0.95, -body_w * 0.35),
			ap + Vector2(body_w * 0.6, body_h * 0.1),
			ap + Vector2(-body_w * 0.6, body_h * 0.1),
		])
		draw_colored_polygon(back_inner, Color(0.35, 0.22, 0.10))
		# Massive pectoral muscles
		var pec_size = body_w * 0.45 * flex
		draw_circle(ap + Vector2(-body_w * 0.25, -body_w * 0.1), pec_size + 1.0, OL)
		draw_circle(ap + Vector2(-body_w * 0.25, -body_w * 0.1), pec_size, Color(0.38, 0.24, 0.12))
		draw_circle(ap + Vector2(body_w * 0.25, -body_w * 0.1), pec_size + 1.0, OL)
		draw_circle(ap + Vector2(body_w * 0.25, -body_w * 0.1), pec_size, Color(0.38, 0.24, 0.12))
		# Center chest line
		draw_line(ap + Vector2(0, -body_w * 0.3), ap + Vector2(0, body_h * 0.05), Color(0.25, 0.14, 0.06, 0.6), 1.5)
		# Abs definition (6-pack lines)
		for abi in range(3):
			var ab_y = ap.y + float(abi) * 3.5 * ape_scale - 2.0
			draw_line(Vector2(ap.x - body_w * 0.25, ab_y), Vector2(ap.x + body_w * 0.25, ab_y), Color(0.28, 0.16, 0.07, 0.35), 1.0 * ape_scale)
		# Belly lighter area
		draw_circle(ap + Vector2(0, 2.0), body_w * 0.45, Color(0.42, 0.28, 0.14))
		# Massive silverback shoulder hump — THE defining feature
		var hump_w = body_w * 0.9
		var hump_h = body_w * 0.65
		draw_circle(ap + Vector2(0, -body_w * 0.5), hump_w + 1.5, OL)
		draw_circle(ap + Vector2(0, -body_w * 0.5), hump_w, Color(0.40, 0.26, 0.14))
		# Silver streak on back (silverback marking)
		if is_king_ape:
			draw_circle(ap + Vector2(0, -body_w * 0.45), hump_w * 0.7, Color(0.60, 0.55, 0.50, 0.35))
			draw_circle(ap + Vector2(0, -body_w * 0.55), hump_w * 0.5, Color(0.65, 0.60, 0.55, 0.25))
		# Trapezius muscles rising to neck
		draw_line(ap + Vector2(-body_w * 0.4, -body_w * 0.5), ap + Vector2(0, -body_w * 0.85), OL, 5.0 * ape_scale)
		draw_line(ap + Vector2(-body_w * 0.4, -body_w * 0.5), ap + Vector2(0, -body_w * 0.85), Color(0.36, 0.23, 0.11), 3.5 * ape_scale)
		draw_line(ap + Vector2(body_w * 0.4, -body_w * 0.5), ap + Vector2(0, -body_w * 0.85), OL, 5.0 * ape_scale)
		draw_line(ap + Vector2(body_w * 0.4, -body_w * 0.5), ap + Vector2(0, -body_w * 0.85), Color(0.36, 0.23, 0.11), 3.5 * ape_scale)
		# === Arms (MASSIVE, veiny, ground-dragging like a real gorilla) ===
		var arm_swing_idle = sin(_time * 3.0 + ally["angle"] * 2.0) * 6.0 * ape_scale
		var ape_punch_ext = punch * 16.0 * ape_scale
		var punch_angle: float = ally.get("punch_dir", 0.0)
		var punch_offset = Vector2.from_angle(punch_angle) * ape_punch_ext if punch > 0.0 else Vector2.ZERO
		# Left arm — upper arm (bicep)
		var l_shoulder = ap + Vector2(-body_w * 0.95, -body_w * 0.35)
		var l_elbow = ap + Vector2(-body_w * 1.2 * facing, body_h * 0.0 + arm_swing_idle * 0.5)
		var l_hand = ap + Vector2(-body_w * 1.5 * facing, body_h * 0.35 + arm_swing_idle)
		if punch > 0.0 and facing < 0:
			l_hand = l_shoulder + punch_offset
			l_elbow = l_shoulder.lerp(l_hand, 0.5) + Vector2(0, -5.0 * ape_scale)
		# Upper arm (thick bicep)
		draw_line(l_shoulder, l_elbow, OL, 8.0 * ape_scale)
		draw_line(l_shoulder, l_elbow, Color(0.35, 0.22, 0.10), 6.0 * ape_scale)
		# Bicep bulge
		var l_bicep = l_shoulder.lerp(l_elbow, 0.45) + Vector2(-1.5 * facing, -1.0)
		draw_circle(l_bicep, 4.5 * ape_scale * flex, Color(0.38, 0.25, 0.12))
		# Forearm
		draw_line(l_elbow, l_hand, OL, 7.0 * ape_scale)
		draw_line(l_elbow, l_hand, Color(0.32, 0.20, 0.09), 5.0 * ape_scale)
		# Forearm muscle
		draw_circle(l_elbow.lerp(l_hand, 0.3), 3.5 * ape_scale, Color(0.36, 0.23, 0.11, 0.6))
		# Vein on bicep
		var l_vein_a = l_shoulder.lerp(l_elbow, 0.2)
		var l_vein_b = l_shoulder.lerp(l_elbow, 0.7)
		draw_line(l_vein_a + Vector2(-1.0, -1.5), l_vein_b + Vector2(-0.5, 0), Color(0.28, 0.15, 0.08, 0.4), 1.0 * ape_scale)
		# Left fist — HUGE knuckles
		draw_circle(l_hand, 5.0 * ape_scale, OL)
		draw_circle(l_hand, 3.8 * ape_scale, Color(0.28, 0.16, 0.07))
		# Knuckle bumps
		for ki in range(3):
			var knuck = l_hand + Vector2((-1.0 + float(ki)) * 2.5, -2.0) * ape_scale
			draw_circle(knuck, 1.5 * ape_scale, Color(0.25, 0.14, 0.06))
		# Right arm
		var r_shoulder = ap + Vector2(body_w * 0.95, -body_w * 0.35)
		var r_elbow = ap + Vector2(body_w * 1.2 * facing, body_h * 0.0 - arm_swing_idle * 0.5)
		var r_hand = ap + Vector2(body_w * 1.5 * facing, body_h * 0.35 - arm_swing_idle)
		if punch > 0.0 and facing >= 0:
			r_hand = r_shoulder + punch_offset
			r_elbow = r_shoulder.lerp(r_hand, 0.5) + Vector2(0, -5.0 * ape_scale)
		# Upper arm
		draw_line(r_shoulder, r_elbow, OL, 8.0 * ape_scale)
		draw_line(r_shoulder, r_elbow, Color(0.35, 0.22, 0.10), 6.0 * ape_scale)
		# Bicep bulge
		var r_bicep = r_shoulder.lerp(r_elbow, 0.45) + Vector2(1.5 * facing, -1.0)
		draw_circle(r_bicep, 4.5 * ape_scale * flex, Color(0.38, 0.25, 0.12))
		# Forearm
		draw_line(r_elbow, r_hand, OL, 7.0 * ape_scale)
		draw_line(r_elbow, r_hand, Color(0.32, 0.20, 0.09), 5.0 * ape_scale)
		# Forearm muscle
		draw_circle(r_elbow.lerp(r_hand, 0.3), 3.5 * ape_scale, Color(0.36, 0.23, 0.11, 0.6))
		# Vein on bicep
		var r_vein_a = r_shoulder.lerp(r_elbow, 0.2)
		var r_vein_b = r_shoulder.lerp(r_elbow, 0.7)
		draw_line(r_vein_a + Vector2(1.0, -1.5), r_vein_b + Vector2(0.5, 0), Color(0.28, 0.15, 0.08, 0.4), 1.0 * ape_scale)
		# Right fist — HUGE knuckles
		draw_circle(r_hand, 5.0 * ape_scale, OL)
		draw_circle(r_hand, 3.8 * ape_scale, Color(0.28, 0.16, 0.07))
		for ki in range(3):
			var knuck = r_hand + Vector2((-1.0 + float(ki)) * 2.5, -2.0) * ape_scale
			draw_circle(knuck, 1.5 * ape_scale, Color(0.25, 0.14, 0.06))
		# === Head (forward-jutting, aggressive gorilla posture) ===
		var head_pos = ap + Vector2(4.0 * facing, -body_w * 0.9)
		# Thick neck connecting to traps
		draw_line(ap + Vector2(0, -body_w * 0.6), head_pos, OL, 7.0 * ape_scale)
		draw_line(ap + Vector2(0, -body_w * 0.6), head_pos, Color(0.36, 0.23, 0.11), 5.0 * ape_scale)
		draw_circle(head_pos, head_sz + 1.5, OL)
		draw_circle(head_pos, head_sz, Color(0.38, 0.24, 0.12))
		# Sagittal crest (ridge on top of skull — sign of massive jaw muscles)
		draw_line(head_pos + Vector2(-head_sz * 0.3, -head_sz * 0.8), head_pos + Vector2(head_sz * 0.3, -head_sz * 0.8), OL, 3.5 * ape_scale)
		draw_line(head_pos + Vector2(-head_sz * 0.25, -head_sz * 0.75), head_pos + Vector2(head_sz * 0.25, -head_sz * 0.75), Color(0.32, 0.20, 0.10), 2.5 * ape_scale)
		# Face plate (lighter, wider)
		draw_circle(head_pos + Vector2(2.0 * facing, 1.5), head_sz * 0.6, Color(0.50, 0.35, 0.20))
		# Heavy brow ridge — overhanging, menacing
		var brow_y = head_pos + Vector2(0, -head_sz * 0.25)
		draw_line(brow_y + Vector2(-head_sz * 0.7, 0), brow_y + Vector2(head_sz * 0.7, 0), OL, 3.5 * ape_scale)
		draw_line(brow_y + Vector2(-head_sz * 0.6, 0.3), brow_y + Vector2(head_sz * 0.6, 0.3), Color(0.30, 0.18, 0.08), 2.5 * ape_scale)
		# Eyes (deep-set under brow, fierce)
		var eye_col = Color(1.0, 0.2, 0.05) if punch > 0.3 else Color(0.92, 0.75, 0.15)
		var eye_l = head_pos + Vector2(-3.0 * facing, -0.5)
		var eye_r = head_pos + Vector2(3.0 * facing, -0.5)
		draw_circle(eye_l, 2.5 * ape_scale, Color(0.95, 0.90, 0.75))
		draw_circle(eye_r, 2.5 * ape_scale, Color(0.95, 0.90, 0.75))
		draw_circle(eye_l, 1.5 * ape_scale, eye_col)
		draw_circle(eye_r, 1.5 * ape_scale, eye_col)
		draw_circle(eye_l, 0.7 * ape_scale, OL)
		draw_circle(eye_r, 0.7 * ape_scale, OL)
		# Flared nostrils
		draw_circle(head_pos + Vector2(-1.5 * facing, 2.5), 1.5, OL)
		draw_circle(head_pos + Vector2(1.5 * facing, 2.5), 1.5, OL)
		draw_circle(head_pos + Vector2(-1.5 * facing, 2.5), 0.8, Color(0.20, 0.10, 0.05))
		draw_circle(head_pos + Vector2(1.5 * facing, 2.5), 0.8, Color(0.20, 0.10, 0.05))
		# Mouth — massive jaw, open during punch = terrifying roar
		if punch > 0.3:
			var mouth_ctr = head_pos + Vector2(2.0 * facing, 4.5)
			# Open roaring mouth — wide jaw
			var mouth_w = 4.5 * ape_scale
			var mouth_h = 3.5 * ape_scale * punch
			draw_circle(mouth_ctr, mouth_w + 0.5, OL)
			draw_circle(mouth_ctr, mouth_w, Color(0.45, 0.08, 0.05))
			# Fangs — large canines
			draw_line(mouth_ctr + Vector2(-mouth_w * 0.5, -mouth_h * 0.3), mouth_ctr + Vector2(-mouth_w * 0.3, mouth_h * 0.5), Color(0.95, 0.92, 0.80), 1.8 * ape_scale)
			draw_line(mouth_ctr + Vector2(mouth_w * 0.5, -mouth_h * 0.3), mouth_ctr + Vector2(mouth_w * 0.3, mouth_h * 0.5), Color(0.95, 0.92, 0.80), 1.8 * ape_scale)
			# Rage veins around head
			for vi in range(3):
				var vang = TAU * float(vi) / 3.0 + _time * 2.0
				var vp = head_pos + Vector2.from_angle(vang) * (head_sz + 3.0)
				draw_line(vp, vp + Vector2.from_angle(vang) * 3.0, Color(0.8, 0.2, 0.1, punch * 0.5), 1.5)
		else:
			# Closed mouth — stern grimace
			var mouth_l = head_pos + Vector2(-2.0 * facing, 4.0)
			var mouth_r = head_pos + Vector2(3.5 * facing, 3.5)
			draw_line(mouth_l, mouth_r, OL, 2.0 * ape_scale)
		# King ape crown — bigger, more regal
		if is_king_ape:
			var crown_base = head_pos + Vector2(0, -head_sz - 2.0)
			# Crown base band
			draw_line(crown_base + Vector2(-6.0, 3.0), crown_base + Vector2(6.0, 3.0), Color(0.85, 0.72, 0.25), 3.0)
			# Crown points (5 spikes)
			for ci in range(5):
				var cx_off = float(ci - 2) * 3.0
				var spike_h = 5.0 if ci == 2 else 3.5
				draw_line(crown_base + Vector2(cx_off, 2.5), crown_base + Vector2(cx_off, -spike_h), Color(0.85, 0.72, 0.25), 2.0)
				# Gem at top of center spike
				if ci == 2:
					draw_circle(crown_base + Vector2(0, -spike_h), 1.5, Color(0.9, 0.15, 0.1))
		# Chest-beating animation when idle (no target)
		if punch < 0.1 and fmod(_time + ally["angle"] * 2.0, 8.0) < 0.5:
			var beat_phase = fmod(_time + ally["angle"] * 2.0, 8.0) / 0.5
			var beat_flash = sin(beat_phase * TAU * 3.0) * 0.3
			draw_circle(ap + Vector2(0, -body_w * 0.15), body_w * 0.3, Color(1.0, 0.9, 0.7, absf(beat_flash)))

	# Permanent legend allies (prog ability 9) — ape silhouettes
	for ally in _legend_allies:
		var ally_r = 38.0
		var ally_pos = body_offset + Vector2.from_angle(ally["angle"]) * ally_r
		var ap_ol = Color(0.06, 0.06, 0.08, 0.7)
		# Golden glow
		draw_circle(ally_pos, 10.0, Color(0.85, 0.72, 0.25, 0.15 + sin(_time * 2.5 + ally["angle"]) * 0.06))
		# Body (hunched ape)
		draw_circle(ally_pos, 6.0, ap_ol)
		draw_circle(ally_pos, 5.0, Color(0.38, 0.24, 0.12, 0.8))
		# Shoulder hump
		draw_circle(ally_pos + Vector2(0, -4.0), 4.5, ap_ol)
		draw_circle(ally_pos + Vector2(0, -4.0), 3.5, Color(0.42, 0.28, 0.14, 0.8))
		# Head
		draw_circle(ally_pos + Vector2(2.0, -7.0), 3.5, ap_ol)
		draw_circle(ally_pos + Vector2(2.0, -7.0), 2.5, Color(0.40, 0.26, 0.14, 0.8))
		# Eyes (fierce golden)
		draw_circle(ally_pos + Vector2(1.0, -7.5), 1.0, Color(0.92, 0.75, 0.15, 0.8))
		draw_circle(ally_pos + Vector2(3.0, -7.5), 1.0, Color(0.92, 0.75, 0.15, 0.8))
		# Arms (draped to ground)
		draw_line(ally_pos + Vector2(-4.0, -2.0), ally_pos + Vector2(-6.0, 4.0), ap_ol, 3.0)
		draw_line(ally_pos + Vector2(-4.0, -2.0), ally_pos + Vector2(-6.0, 4.0), Color(0.35, 0.22, 0.10, 0.8), 2.0)
		draw_line(ally_pos + Vector2(4.0, -2.0), ally_pos + Vector2(6.0, 4.0), ap_ol, 3.0)
		draw_line(ally_pos + Vector2(4.0, -2.0), ally_pos + Vector2(6.0, 4.0), Color(0.35, 0.22, 0.10, 0.8), 2.0)
		# Legs
		draw_line(ally_pos + Vector2(-2.0, 4.0), ally_pos + Vector2(-3.0, 7.0), ap_ol, 2.5)
		draw_line(ally_pos + Vector2(-2.0, 4.0), ally_pos + Vector2(-3.0, 7.0), Color(0.30, 0.18, 0.08, 0.8), 1.8)
		draw_line(ally_pos + Vector2(2.0, 4.0), ally_pos + Vector2(3.0, 7.0), ap_ol, 2.5)
		draw_line(ally_pos + Vector2(2.0, 4.0), ally_pos + Vector2(3.0, 7.0), Color(0.30, 0.18, 0.08, 0.8), 1.8)

	# === 11. CHARACTER BODY — BLOONS TD6 CARTOON STYLE ===
	var breath = breathe
	var sway = weight_shift

	# Chibi positions (big head, chunky body)
	var feet_y = body_offset + Vector2(sway * 1.0, 10.0)
	var leg_top = body_offset + Vector2(sway * 0.6, 0.0)
	var torso_center = body_offset + Vector2(sway * 0.3, -8.0 - breath * 0.5)
	var neck_base = body_offset + Vector2(sway * 0.15, -14.0 - breath * 0.3)
	var head_center = body_offset + Vector2(sway * 0.08, -26.0)

	# Saturated Tarzan colors
	var skin = Color(0.78, 0.56, 0.36)
	var skin_dk = Color(0.62, 0.42, 0.26)
	var skin_lt = Color(0.90, 0.70, 0.48)
	var hair_col = Color(0.32, 0.18, 0.08)
	var hair_lt = Color(0.46, 0.30, 0.14)
	var loin_col = Color(0.50, 0.30, 0.12)
	var loin_dk = Color(0.36, 0.20, 0.08)
	var vine_col = Color(0.14, 0.50, 0.10)
	var vine_dk = Color(0.08, 0.34, 0.06)
	var leaf_col = Color(0.22, 0.62, 0.18)
	var leaf_dk = Color(0.14, 0.44, 0.10)

	# Spear thrust on attack
	var spear_ext = 0.0
	if _attack_anim > 0.3:
		spear_ext = sin(_attack_anim * 6.0) * 12.0 * _attack_anim

	# === TIER-SPECIFIC EFFECTS ===

	# Tier 1+: Vine tendrils swirling around body (swing vines)
	if upgrade_tier >= 1:
		for li in range(4 + upgrade_tier):
			var la = _time * (0.5 + fmod(float(li) * 1.37, 0.4)) + float(li) * TAU / float(4 + upgrade_tier)
			var lr = 18.0 + fmod(float(li) * 3.7, 12.0)
			var vp = body_offset + Vector2(cos(la) * lr, sin(la) * lr * 0.5 + 4.0)
			var va = 0.3 + sin(_time * 1.5 + float(li)) * 0.1
			draw_circle(vp, 2.8, Color(vine_dk.r, vine_dk.g, vine_dk.b, va))
			draw_circle(vp, 1.8, Color(leaf_col.r, leaf_col.g, leaf_col.b, va))

	# Tier 2+: Green strength aura glow (ape strength)
	if upgrade_tier >= 2:
		var str_pulse = (sin(_time * 2.5) + 1.0) * 0.5
		draw_circle(body_offset, 22.0 + str_pulse * 3.0, Color(0.2, 0.7, 0.1, 0.04 + str_pulse * 0.02))
		# Subtle muscle glow particles
		for mi in range(4):
			var ma = _time * 1.2 + float(mi) * TAU / 4.0
			var mp = body_offset + Vector2(cos(ma) * 14.0, sin(ma) * 8.0 - 5.0)
			draw_circle(mp, 2.0 + str_pulse, Color(0.3, 0.8, 0.2, 0.15 + str_pulse * 0.08))

	# Tier 3+: Waiting-for-apes indicator (when allies not active)
	if upgrade_tier >= 3 and _animal_allies.size() == 0:
		# Subtle ape silhouette ghosts showing readiness
		for ai in range(1 if upgrade_tier == 3 else 4):
			var aa = _time * 0.4 + float(ai) * TAU / (1.0 if upgrade_tier == 3 else 4.0)
			var apos = body_offset + Vector2(cos(aa) * 28.0, sin(aa) * 10.0 + 12.0)
			var ghost_a = 0.12 + sin(_time * 1.5 + float(ai)) * 0.05
			draw_circle(apos, 5.0, Color(0.35, 0.22, 0.10, ghost_a))
			draw_circle(apos + Vector2(0, -3), 3.5, Color(0.42, 0.28, 0.14, ghost_a))

	# Tier 4: King crown particles + golden glow
	if upgrade_tier >= 4:
		# Golden crown sparkles around Tarzan
		for fd in range(6):
			var fd_seed = float(fd) * 2.37
			var fd_angle = _time * (0.4 + fmod(fd_seed, 0.3)) + fd_seed
			var fd_radius = 24.0 + fmod(fd_seed * 3.7, 18.0)
			var fd_pos = body_offset + Vector2(cos(fd_angle) * fd_radius, sin(fd_angle) * fd_radius * 0.6 - 10.0)
			var fd_alpha = 0.3 + sin(_time * 3.0 + fd_seed * 2.0) * 0.15
			draw_circle(fd_pos, 2.0, Color(0.85, 0.72, 0.25, fd_alpha))
			draw_circle(fd_pos, 1.2, Color(1.0, 0.9, 0.5, fd_alpha * 0.6))

	# === CHARACTER BODY ===

	# --- BARE FEET (chunky round, no shoes) ---
	var l_foot = feet_y + Vector2(-6, 0)
	var r_foot = feet_y + Vector2(6, 0)
	# Left foot: OL then skin fill
	draw_circle(l_foot, 5.5, OL)
	draw_circle(l_foot, 4.2, skin)
	draw_circle(l_foot + Vector2(-1, -0.5), 2.5, skin_lt)
	# Right foot
	draw_circle(r_foot, 5.5, OL)
	draw_circle(r_foot, 4.2, skin)
	draw_circle(r_foot + Vector2(1, -0.5), 2.5, skin_lt)
	# Leaf ankle bands
	for ab_i in range(2):
		var ab_ft = l_foot if ab_i == 0 else r_foot
		var ab_s = -1.0 if ab_i == 0 else 1.0
		draw_arc(ab_ft + Vector2(0, -3), 5.0, PI + 0.4, TAU - 0.4, 8, OL, 3.5)
		draw_arc(ab_ft + Vector2(0, -3), 5.0, PI + 0.4, TAU - 0.4, 8, vine_col, 2.5)
		var lf_pt = ab_ft + Vector2(ab_s * 4.5, -4)
		draw_circle(lf_pt, 2.8, OL)
		draw_circle(lf_pt, 2.0, leaf_col)

	# --- CHUNKY LEGS (2-segment, bare skin with bold outlines) ---
	var l_hip = leg_top + Vector2(-5, 0)
	var r_hip = leg_top + Vector2(5, 0)
	var l_knee = l_foot.lerp(l_hip, 0.45) + Vector2(-2, 0)
	var r_knee = r_foot.lerp(r_hip, 0.45) + Vector2(2, 0)

	# Left upper leg
	draw_line(l_hip, l_knee, OL, 11.0)
	draw_line(l_hip, l_knee, skin, 8.0)
	draw_line(l_hip + Vector2(-1, 0), l_knee + Vector2(-1, 0), skin_lt, 3.0)
	# Left lower leg
	draw_line(l_knee, l_foot, OL, 10.0)
	draw_line(l_knee, l_foot, skin, 7.0)
	draw_line(l_knee + Vector2(-1, 0), l_foot + Vector2(-1, 0), skin_lt, 2.5)
	# Left knee joint
	draw_circle(l_knee, 6.0, OL)
	draw_circle(l_knee, 4.5, skin)
	draw_circle(l_knee + Vector2(-1, -0.5), 2.5, skin_lt)

	# Right upper leg
	draw_line(r_hip, r_knee, OL, 11.0)
	draw_line(r_hip, r_knee, skin, 8.0)
	draw_line(r_hip + Vector2(1, 0), r_knee + Vector2(1, 0), skin_lt, 3.0)
	# Right lower leg
	draw_line(r_knee, r_foot, OL, 10.0)
	draw_line(r_knee, r_foot, skin, 7.0)
	draw_line(r_knee + Vector2(1, 0), r_foot + Vector2(1, 0), skin_lt, 2.5)
	# Right knee joint
	draw_circle(r_knee, 6.0, OL)
	draw_circle(r_knee, 4.5, skin)
	draw_circle(r_knee + Vector2(1, -0.5), 2.5, skin_lt)

	# --- LOINCLOTH (animal skin wrap with bold outlines) ---
	var lc_w1 = sin(_time * 2.0) * 2.0
	var lc_w2 = sin(_time * 2.2 + 0.5) * 2.0
	# Front flap: OL polygon then fill polygon
	var loin_ol = PackedVector2Array([
		leg_top + Vector2(-10, -2),
		leg_top + Vector2(10, -2),
		leg_top + Vector2(7, 8),
		leg_top + Vector2(2, 12 + lc_w1),
		leg_top + Vector2(-2, 11 + lc_w2),
		leg_top + Vector2(-7, 8),
	])
	draw_colored_polygon(loin_ol, OL)
	var loin_fill = PackedVector2Array([
		leg_top + Vector2(-8.5, -1),
		leg_top + Vector2(8.5, -1),
		leg_top + Vector2(5.5, 7),
		leg_top + Vector2(1, 10.5 + lc_w1),
		leg_top + Vector2(-1, 9.5 + lc_w2),
		leg_top + Vector2(-5.5, 7),
	])
	draw_colored_polygon(loin_fill, loin_col)
	# Lighter center stripe
	var loin_ctr = PackedVector2Array([
		leg_top + Vector2(-3, 0),
		leg_top + Vector2(3, 0),
		leg_top + Vector2(2, 7),
		leg_top + Vector2(-2, 7),
	])
	draw_colored_polygon(loin_ctr, Color(0.60, 0.38, 0.18))
	# Frayed edges (bold scallops)
	for fi in range(5):
		var fx = -6.0 + float(fi) * 3.0
		var fray_y = 8.5 + sin(_time * 1.8 + float(fi) * 1.3) * 1.5
		draw_circle(leg_top + Vector2(fx, fray_y), 2.5, OL)
		draw_circle(leg_top + Vector2(fx, fray_y), 1.6, loin_dk)

	# --- VINE BELT (bold green with leaf accents) ---
	draw_line(leg_top + Vector2(-11, -2), leg_top + Vector2(11, -2), OL, 5.5)
	draw_line(leg_top + Vector2(-10, -2), leg_top + Vector2(10, -2), vine_col, 4.0)
	draw_line(leg_top + Vector2(-9, -2.5), leg_top + Vector2(9, -2.5), leaf_col, 1.8)
	# Leaves on belt
	for bli in range(4):
		var blx = -8.0 + float(bli) * 5.5
		var bl_sw = sin(_time * 1.5 + float(bli) * 1.2) * 1.0
		var bl_p = leg_top + Vector2(blx, -2)
		draw_circle(bl_p + Vector2(bl_sw, 2), 3.5, OL)
		draw_circle(bl_p + Vector2(bl_sw, 2), 2.5, leaf_col)
		draw_circle(bl_p + Vector2(bl_sw + 0.5, 1.5), 1.3, Color(0.30, 0.72, 0.24))

	# --- BARE CHEST TORSO (chunky, exposed skin, V-taper with bold OL) ---
	var torso_ol = PackedVector2Array([
		leg_top + Vector2(-9, 0),
		torso_center + Vector2(-14, 0),
		neck_base + Vector2(-15, 0),
		neck_base + Vector2(15, 0),
		torso_center + Vector2(14, 0),
		leg_top + Vector2(9, 0),
	])
	draw_colored_polygon(torso_ol, OL)
	var torso_fl = PackedVector2Array([
		leg_top + Vector2(-7.5, 0.5),
		torso_center + Vector2(-12.5, 0.5),
		neck_base + Vector2(-13.5, 0.5),
		neck_base + Vector2(13.5, 0.5),
		torso_center + Vector2(12.5, 0.5),
		leg_top + Vector2(7.5, 0.5),
	])
	draw_colored_polygon(torso_fl, skin)
	# Pec highlights (chunky cartoon pecs)
	draw_circle(neck_base + Vector2(-5, 5), 5.5, skin_lt)
	draw_circle(neck_base + Vector2(5, 5), 5.5, skin_lt)
	# Sternum line (bold cartoon divider)
	draw_line(neck_base + Vector2(0, 2), torso_center + Vector2(0, 1), OL, 1.5)
	# Belly area
	draw_circle(torso_center + Vector2(0, 2), 5.0, skin_dk)
	draw_circle(torso_center + Vector2(0, 1.5), 4.0, skin)

	# Chest scar (bold cartoon scar)
	draw_line(neck_base + Vector2(-8, 4), neck_base + Vector2(-2, 8), OL, 2.0)
	draw_line(neck_base + Vector2(-7.5, 4.3), neck_base + Vector2(-2.3, 7.7), Color(0.82, 0.58, 0.46), 1.0)

	# --- BONE NECKLACE (bold outlined teeth) ---
	var nkl_ctr = neck_base + Vector2(0, 3)
	draw_arc(nkl_ctr, 10.0, 0.15, PI - 0.15, 12, OL, 3.0)
	draw_arc(nkl_ctr, 10.0, 0.15, PI - 0.15, 12, Color(0.56, 0.42, 0.26), 1.8)
	for bi in range(5):
		var bone_a = 0.25 + float(bi) * 0.13 * PI
		var bone_p = nkl_ctr + Vector2.from_angle(bone_a) * 10.0
		draw_line(bone_p, bone_p + Vector2(0, 4.0), OL, 3.5)
		draw_line(bone_p, bone_p + Vector2(0, 4.0), Color(0.92, 0.86, 0.76), 2.2)
		draw_circle(bone_p + Vector2(0, 4.0), 1.5, OL)
		draw_circle(bone_p + Vector2(0, 4.0), 1.0, Color(0.88, 0.82, 0.70))

	# --- KNIFE AT BELT ---
	var kn_pos = leg_top + Vector2(9, 0)
	draw_line(kn_pos, kn_pos + Vector2(2, 10), OL, 5.5)
	draw_line(kn_pos, kn_pos + Vector2(2, 10), Color(0.42, 0.28, 0.14), 4.0)
	draw_line(kn_pos + Vector2(0, -1), kn_pos + Vector2(-1, -6), OL, 4.5)
	draw_line(kn_pos + Vector2(0, -1), kn_pos + Vector2(-1, -6), Color(0.56, 0.40, 0.22), 3.0)
	draw_circle(kn_pos + Vector2(-1, -6), 2.2, OL)
	draw_circle(kn_pos + Vector2(-1, -6), 1.5, Color(0.78, 0.60, 0.25))

	# --- SHOULDERS (chunky round cartoon joints) ---
	var l_shoulder = neck_base + Vector2(-14, 0)
	var r_shoulder = neck_base + Vector2(14, 0)
	draw_circle(l_shoulder, 8.5, OL)
	draw_circle(l_shoulder, 6.8, skin)
	draw_circle(l_shoulder + Vector2(-1, -1.5), 3.5, skin_lt)
	draw_circle(r_shoulder, 8.5, OL)
	draw_circle(r_shoulder, 6.8, skin)
	draw_circle(r_shoulder + Vector2(1, -1.5), 3.5, skin_lt)

	# --- LEFT ARM (raised, holding vine — 2-segment chunky) ---
	var vine_hand = l_shoulder + Vector2(-5, -18 + sin(_time * 1.2) * 3.0)
	var l_elbow = l_shoulder + (vine_hand - l_shoulder) * 0.48 + Vector2(-3, 0)
	# Upper arm: OL then fill then highlight
	draw_line(l_shoulder, l_elbow, OL, 11.0)
	draw_line(l_shoulder, l_elbow, skin, 8.0)
	draw_line(l_shoulder + Vector2(-1, 0), l_elbow + Vector2(-1, 0), skin_lt, 3.0)
	# Elbow joint
	draw_circle(l_elbow, 6.0, OL)
	draw_circle(l_elbow, 4.5, skin)
	draw_circle(l_elbow + Vector2(-1, -0.5), 2.5, skin_lt)
	# Forearm
	draw_line(l_elbow, vine_hand, OL, 10.0)
	draw_line(l_elbow, vine_hand, skin, 7.0)
	draw_line(l_elbow + Vector2(-1, 0), vine_hand + Vector2(-1, 0), skin_lt, 2.5)
	# Leaf wristband
	var lw_p = l_elbow.lerp(vine_hand, 0.8)
	draw_arc(lw_p, 4.5, 0, TAU, 10, OL, 3.5)
	draw_arc(lw_p, 4.5, 0, TAU, 10, vine_col, 2.5)
	draw_circle(lw_p + Vector2(-3, -1), 2.5, OL)
	draw_circle(lw_p + Vector2(-3, -1), 1.8, leaf_col)
	# Hand gripping vine
	draw_circle(vine_hand, 5.5, OL)
	draw_circle(vine_hand, 4.2, skin)
	draw_circle(vine_hand + Vector2(-0.5, -1), 2.2, skin_lt)

	# Vine going up from hand
	var vine_top = vine_hand + Vector2(-2, -22 + sin(_time * 0.8) * 2.0)
	draw_line(vine_hand, vine_top, OL, 5.0)
	draw_line(vine_hand, vine_top, vine_col, 3.5)
	draw_line(vine_hand, vine_top, leaf_col, 1.5)
	# Leaves on vine
	for vli in range(3):
		var vlt = 0.2 + float(vli) * 0.3
		var vlp = vine_hand.lerp(vine_top, vlt)
		var vl_sw = sin(_time * 2.0 + float(vli) * 1.5) * 2.0
		var vl_d = Vector2(3.5 + vl_sw, -1.0)
		draw_line(vlp, vlp + vl_d, OL, 3.5)
		draw_line(vlp, vlp + vl_d, leaf_col, 2.2)
		draw_line(vlp, vlp + vl_d.rotated(0.6) * 0.7, leaf_dk, 1.5)

	# --- RIGHT ARM (holding spear, thrusts toward target — 2-segment chunky) ---
	var spear_hand = r_shoulder + Vector2(6, 2) + dir * (16.0 + spear_ext)
	var r_elbow = r_shoulder + (spear_hand - r_shoulder) * 0.4 + Vector2(0, 2)
	# Upper arm
	draw_line(r_shoulder, r_elbow, OL, 11.0)
	draw_line(r_shoulder, r_elbow, skin, 8.0)
	draw_line(r_shoulder + Vector2(1, 0), r_elbow + Vector2(1, 0), skin_lt, 3.0)
	# Elbow
	draw_circle(r_elbow, 6.0, OL)
	draw_circle(r_elbow, 4.5, skin)
	draw_circle(r_elbow + Vector2(1, -0.5), 2.5, skin_lt)
	# Forearm
	var r_hand = r_elbow + (spear_hand - r_elbow).normalized() * (r_elbow.distance_to(spear_hand) * 0.7)
	draw_line(r_elbow, r_hand, OL, 10.0)
	draw_line(r_elbow, r_hand, skin, 7.0)
	draw_line(r_elbow + Vector2(1, 0), r_hand + Vector2(1, 0), skin_lt, 2.5)
	# Leaf wristband (right)
	var rw_p = r_elbow.lerp(r_hand, 0.8)
	draw_arc(rw_p, 4.5, 0, TAU, 10, OL, 3.5)
	draw_arc(rw_p, 4.5, 0, TAU, 10, vine_col, 2.5)
	draw_circle(rw_p + Vector2(3, -1), 2.5, OL)
	draw_circle(rw_p + Vector2(3, -1), 1.8, leaf_col)
	# Hand gripping spear
	draw_circle(r_hand, 5.5, OL)
	draw_circle(r_hand, 4.2, skin)
	draw_circle(r_hand + Vector2(0.5, -1), 2.2, skin_lt)

	# --- SPEAR (extends past the hand toward target) ---
	var sp_dir = (spear_hand - r_hand).normalized()
	var sp_butt = r_hand - sp_dir * 14.0
	var sp_tip = spear_hand + sp_dir * 4.0
	# Shaft: OL then wood fill then highlight
	draw_line(sp_butt, sp_tip, OL, 5.5)
	draw_line(sp_butt, sp_tip, Color(0.52, 0.34, 0.16), 4.0)
	draw_line(sp_butt, sp_tip, Color(0.64, 0.46, 0.26), 1.5)
	# Spear tip (stone/bone — triangle with bold outline)
	var tip_base = sp_tip - sp_dir * 6.0
	var tip_perp = sp_dir.rotated(PI / 2.0)
	var tip_ol = PackedVector2Array([
		sp_tip + sp_dir * 2.5,
		tip_base + tip_perp * 5.0,
		tip_base - tip_perp * 5.0,
	])
	draw_colored_polygon(tip_ol, OL)
	var tip_fl = PackedVector2Array([
		sp_tip + sp_dir * 1.0,
		tip_base + tip_perp * 3.5,
		tip_base - tip_perp * 3.5,
	])
	draw_colored_polygon(tip_fl, Color(0.72, 0.68, 0.60))
	draw_line(sp_tip + sp_dir * 0.5, tip_base, Color(0.88, 0.84, 0.76, 0.5), 1.5)
	# Vine binding wraps near tip
	var bind_p = tip_base - sp_dir * 2.0
	draw_line(bind_p + tip_perp * 3.5, bind_p - tip_perp * 3.5, OL, 3.5)
	draw_line(bind_p + tip_perp * 3.0, bind_p - tip_perp * 3.0, vine_col, 2.2)
	# Tier 2+ glowing spear tip
	if upgrade_tier >= 2:
		var gp = (sin(_time * 3.5) + 1.0) * 0.5
		draw_circle(sp_tip, 7.0 + gp * 2.5, Color(0.95, 0.65, 0.15, 0.06 + gp * 0.04))
		draw_circle(sp_tip, 4.0 + gp * 1.5, Color(1.0, 0.80, 0.30, 0.05))

	# Spear thrust attack flash
	if _attack_anim > 0.2:
		var thr_r = 15.0 + (1.0 - _attack_anim) * 30.0
		var thr_a = _attack_anim * 0.4
		draw_arc(r_hand + dir * 10.0, thr_r, 0, TAU, 24, Color(0.85, 0.70, 0.35, thr_a), 2.5)
		for si in range(4):
			var sp_a = TAU * float(si) / 4.0 + _time * 3.0
			var sp_r2 = thr_r * (0.5 + sin(_time * 5.0 + float(si)) * 0.2)
			var sp_p = r_hand + dir * 10.0 + Vector2.from_angle(sp_a) * sp_r2
			draw_circle(sp_p, 2.0, Color(0.95, 0.80, 0.40, thr_a * 0.6))

	# === HEAD ===

	# Neck (chunky, bold outlined)
	draw_line(neck_base, head_center + Vector2(0, 8), OL, 11.0)
	draw_line(neck_base, head_center + Vector2(0, 8), skin, 8.0)
	draw_line(neck_base + Vector2(-2, 0), head_center + Vector2(-2, 8), skin_lt, 2.5)

	# --- WILD HAIR (back layer — big messy mass, signature Tarzan) ---
	var hair_sway = sin(_time * 2.0) * 2.5
	# Large hair mass behind head (OL then fill)
	draw_circle(head_center, 16.0, OL)
	draw_circle(head_center, 14.0, hair_col)
	draw_circle(head_center + Vector2(0, -1), 12.0, hair_lt)

	# Wild spiky strands radiating outward (messy in all directions)
	var tuft_angles = [
		[-2.8, 11.0, 3.8], [-2.2, 10.0, 3.2], [-1.6, 12.0, 3.5], [-1.0, 10.5, 3.2],
		[-0.4, 11.5, 3.5], [0.2, 10.0, 3.8], [0.8, 12.5, 3.2], [1.4, 10.0, 3.5],
		[2.0, 11.0, 3.4], [2.6, 10.5, 3.2], [3.2, 12.0, 3.5],
	]
	for h in range(tuft_angles.size()):
		var ha: float = tuft_angles[h][0]
		var tlen: float = tuft_angles[h][1]
		var twid: float = tuft_angles[h][2]
		var tuft_root = head_center + Vector2.from_angle(ha) * 12.0
		var sway_d = 1.0 if h % 2 == 0 else -1.0
		var s_wave = sin(ha * 2.5 + _time * 1.8) * 2.0
		var tuft_end = tuft_root + Vector2.from_angle(ha) * tlen + Vector2(hair_sway * sway_d * 0.5 + s_wave, s_wave * 0.3)
		# Bold OL stroke then colored fill
		draw_line(tuft_root, tuft_end, OL, twid + 2.0)
		var tcol = hair_col if h % 3 == 0 else hair_lt if h % 3 == 1 else Color(0.40, 0.26, 0.12)
		draw_line(tuft_root, tuft_end, tcol, twid)

	# Forehead bangs (bold strands hanging down)
	for fri in range(5):
		var fr_x = -5.0 + float(fri) * 2.5
		var fr_base = head_center + Vector2(fr_x, -11)
		var fr_wave = sin(_time * 2.2 + float(fri) * 1.1) * 1.0
		var fr_tip = fr_base + Vector2(fr_wave, 8.0 + float(fri) * 0.3)
		draw_line(fr_base, fr_tip, OL, 3.5)
		draw_line(fr_base, fr_tip, hair_lt if fri % 2 == 0 else hair_col, 2.2)

	# --- FACE ---
	# Head circle: 14 OL -> 12.5 hair -> face 12 OL -> 10.8 skin
	draw_circle(head_center, 14.0, OL)
	draw_circle(head_center, 12.5, hair_col)
	# Face oval
	draw_circle(head_center + Vector2(0, 1.0), 12.0, OL)
	draw_circle(head_center + Vector2(0, 1.0), 10.8, skin)
	# Face highlight (top-left Bloons shine)
	draw_circle(head_center + Vector2(-2.5, -1.5), 6.0, skin_lt)

	# Ears (bold outlined circles)
	var l_ear = head_center + Vector2(-11.0, -0.5)
	var r_ear = head_center + Vector2(11.0, -0.5)
	draw_circle(l_ear, 3.8, OL)
	draw_circle(l_ear, 2.8, skin)
	draw_circle(l_ear + Vector2(-0.3, 0), 1.5, skin_lt)
	draw_circle(r_ear, 3.8, OL)
	draw_circle(r_ear, 2.8, skin)
	draw_circle(r_ear + Vector2(0.3, 0), 1.5, skin_lt)

	# --- EYES (BTD6 style: 5.8 OL, 4.8 white, iris, pupil, sparkle) ---
	var look_dir = dir * 1.5
	var l_eye = head_center + Vector2(-4.2, -1.0)
	var r_eye = head_center + Vector2(4.2, -1.0)
	# Eye outlines (bold black)
	draw_circle(l_eye, 5.8, OL)
	draw_circle(r_eye, 5.8, OL)
	# Eye whites
	draw_circle(l_eye, 4.8, Color(0.98, 0.98, 1.0))
	draw_circle(r_eye, 4.8, Color(0.98, 0.98, 1.0))
	# Green irises (intense saturated jungle green)
	draw_circle(l_eye + look_dir, 3.0, Color(0.06, 0.35, 0.08))
	draw_circle(l_eye + look_dir, 2.4, Color(0.10, 0.52, 0.14))
	draw_circle(r_eye + look_dir, 3.0, Color(0.06, 0.35, 0.08))
	draw_circle(r_eye + look_dir, 2.4, Color(0.10, 0.52, 0.14))
	# Pupils (solid black)
	draw_circle(l_eye + look_dir * 1.1, 1.4, OL)
	draw_circle(r_eye + look_dir * 1.1, 1.4, OL)
	# Primary sparkle (big, bright — key Bloons detail)
	draw_circle(l_eye + Vector2(-1.2, -1.5), 1.6, Color(1.0, 1.0, 1.0, 0.95))
	draw_circle(r_eye + Vector2(-1.2, -1.5), 1.6, Color(1.0, 1.0, 1.0, 0.95))
	# Secondary sparkle
	draw_circle(l_eye + Vector2(1.0, 0.8), 0.8, Color(1.0, 1.0, 1.0, 0.55))
	draw_circle(r_eye + Vector2(1.0, 0.8), 0.8, Color(1.0, 1.0, 1.0, 0.55))
	# Feral green glint (unique to Tarzan)
	var glint_t = sin(_time * 2.5) * 0.2
	draw_circle(l_eye + Vector2(0.5, -0.5), 0.6, Color(0.20, 0.85, 0.30, 0.3 + glint_t))
	draw_circle(r_eye + Vector2(0.5, -0.5), 0.6, Color(0.20, 0.85, 0.30, 0.3 + glint_t))

	# Bold eyebrows (thick, angular — primal fierce)
	draw_line(l_eye + Vector2(-4.5, -5.0), l_eye + Vector2(1.0, -6.0), OL, 4.0)
	draw_line(l_eye + Vector2(-4.0, -5.0), l_eye + Vector2(0.5, -5.8), hair_col, 2.8)
	draw_line(r_eye + Vector2(-1.0, -6.0), r_eye + Vector2(4.5, -5.0), OL, 4.0)
	draw_line(r_eye + Vector2(-0.5, -5.8), r_eye + Vector2(4.0, -5.0), hair_col, 2.8)

	# Nose (chunky cartoon nose with bold OL)
	draw_circle(head_center + Vector2(0, 3.5), 3.0, OL)
	draw_circle(head_center + Vector2(0, 3.5), 2.2, skin_lt)
	draw_circle(head_center + Vector2(0.3, 3.2), 1.3, Color(0.95, 0.78, 0.56))
	# Nostrils
	draw_circle(head_center + Vector2(-1.3, 4.2), 0.9, OL)
	draw_circle(head_center + Vector2(1.3, 4.2), 0.9, OL)

	# Mouth (determined grin, gritted teeth — cartoon fierce)
	draw_arc(head_center + Vector2(0, 6.0), 4.5, 0.15, PI - 0.15, 12, OL, 3.0)
	draw_arc(head_center + Vector2(0, 6.0), 4.5, 0.15, PI - 0.15, 12, Color(0.55, 0.25, 0.15), 1.8)
	# Gritted teeth (bold)
	for thi in range(4):
		var tooth_x = -2.2 + float(thi) * 1.5
		draw_circle(head_center + Vector2(tooth_x, 6.2), 1.2, OL)
		draw_circle(head_center + Vector2(tooth_x, 6.2), 0.8, Color(0.98, 0.96, 0.92))

	# Scars (bold outlined — jungle warrior)
	# Cheek scar
	draw_line(head_center + Vector2(-7.5, 0.0), head_center + Vector2(-3.5, 3.5), OL, 2.0)
	draw_line(head_center + Vector2(-7.0, 0.2), head_center + Vector2(-3.8, 3.3), Color(0.82, 0.58, 0.46), 1.2)
	# Chin scar
	draw_line(head_center + Vector2(2.0, 7.5), head_center + Vector2(3.5, 9.0), OL, 1.8)
	draw_line(head_center + Vector2(2.2, 7.7), head_center + Vector2(3.3, 8.8), Color(0.82, 0.58, 0.46), 1.0)

	# === Tier 4: King of the Apes — golden crown + primal aura ===
	if upgrade_tier >= 4:
		var aura_pulse = sin(_time * 2.0) * 4.0
		# Golden primal aura
		draw_circle(body_offset, 55.0 + aura_pulse, Color(0.85, 0.72, 0.25, 0.04))
		draw_circle(body_offset, 45.0 + aura_pulse * 0.6, Color(0.9, 0.78, 0.3, 0.05))
		draw_arc(body_offset, 50.0 + aura_pulse, 0, TAU, 32, Color(0.85, 0.72, 0.25, 0.12), 2.5)
		# Crown on head
		var crown_base = head_center + Vector2(0, -13)
		var crown_col = Color(0.85, 0.72, 0.25)
		var crown_bright = Color(1.0, 0.9, 0.4)
		# Crown base band
		draw_line(crown_base + Vector2(-8, 0), crown_base + Vector2(8, 0), OL, 4.0)
		draw_line(crown_base + Vector2(-7, 0), crown_base + Vector2(7, 0), crown_col, 2.8)
		# Crown points
		for ci in range(3):
			var cx = -5.0 + float(ci) * 5.0
			var cp_base = crown_base + Vector2(cx, 0)
			var cp_tip = crown_base + Vector2(cx, -6.0 - sin(_time * 2.0 + float(ci)) * 1.0)
			draw_line(cp_base, cp_tip, OL, 3.0)
			draw_line(cp_base, cp_tip, crown_col, 2.0)
			draw_circle(cp_tip, 1.5, crown_bright)
		# Orbiting golden sparkles
		for gs in range(6):
			var gs_a = _time * (0.6 + float(gs % 3) * 0.15) + float(gs) * TAU / 6.0
			var gs_r = 40.0 + aura_pulse + float(gs % 3) * 4.0
			var gs_p = body_offset + Vector2.from_angle(gs_a) * gs_r
			var gs_size = 1.8 + sin(_time * 3.0 + float(gs) * 1.5) * 0.6
			var gs_alpha = 0.35 + sin(_time * 2.5 + float(gs)) * 0.12
			draw_circle(gs_p, gs_size, Color(0.85, 0.72, 0.25, gs_alpha))

	# === AWAITING ABILITY CHOICE INDICATOR ===
	if awaiting_ability_choice:
		var pulse = (sin(_time * 4.0) + 1.0) * 0.5
		draw_circle(Vector2.ZERO, 68.0 + pulse * 6.0, Color(0.2, 0.6, 0.1, 0.1 + pulse * 0.1))
		draw_arc(Vector2.ZERO, 68.0 + pulse * 6.0, 0, TAU, 32, Color(0.2, 0.6, 0.1, 0.3 + pulse * 0.3), 2.5)
		var font3 = _game_font
		draw_string(font3, Vector2(-16, -80), "!", HORIZONTAL_ALIGNMENT_CENTER, 32, 30, Color(0.2, 0.6, 0.1, 0.7 + pulse * 0.3))

	# === VISUAL TIER EVOLUTION ===
	if upgrade_tier >= 1:
		var glow_pulse = (sin(_time * 2.0) + 1.0) * 0.5
		draw_arc(Vector2.ZERO, 28.0 + glow_pulse * 3.0, 0, TAU, 32, Color(0.5, 0.7, 0.15, 0.15 + glow_pulse * 0.1), 2.0)
	if upgrade_tier >= 2:
		for si in range(6):
			var sa = _time * 1.2 + float(si) * TAU / 6.0
			var sr = 34.0 + sin(_time * 2.5 + float(si)) * 3.0
			var sp = Vector2.from_angle(sa) * sr
			var s_alpha = 0.4 + sin(_time * 3.0 + float(si) * 1.1) * 0.2
			draw_circle(sp, 1.8, Color(0.5, 0.8, 0.15, s_alpha))
	if upgrade_tier >= 3:
		var crown_y = -58.0 + sin(_time * 1.5) * 2.0
		draw_line(Vector2(-8, crown_y), Vector2(8, crown_y), Color(1.0, 0.85, 0.2, 0.8), 2.0)
		for ci in range(3):
			var cx = -6.0 + float(ci) * 6.0
			draw_line(Vector2(cx, crown_y), Vector2(cx, crown_y - 5.0), Color(1.0, 0.85, 0.2, 0.7), 1.5)
			draw_circle(Vector2(cx, crown_y - 5.0), 1.5, Color(1.0, 0.95, 0.5, 0.6))
	if upgrade_tier >= 4:
		for bi in range(8):
			var ba = _time * 0.5 + float(bi) * TAU / 8.0
			var b_inner = Vector2.from_angle(ba) * 45.0
			var b_outer = Vector2.from_angle(ba) * 65.0
			var b_alpha = 0.15 + sin(_time * 2.0 + float(bi) * 0.8) * 0.08
			draw_line(b_inner, b_outer, Color(0.5, 0.7, 0.15, b_alpha), 1.5)

	# === DAMAGE COUNTER ===
	if damage_dealt > 0:
		var font = _game_font
		var dmg_text = str(int(damage_dealt)) + " DMG"
		if stat_upgrade_level > 0:
			dmg_text += " • Lv." + str(stat_upgrade_level)
		draw_string(font, Vector2(-36, 56), dmg_text, HORIZONTAL_ALIGNMENT_LEFT, 160, 12, Color(1.0, 0.84, 0.0, 0.5))

	# === UPGRADE NAME FLASH ===
	if _upgrade_flash > 0.0 and _upgrade_name != "":
		var font2 = _game_font
		draw_string(font2, Vector2(-80, -72), _upgrade_name, HORIZONTAL_ALIGNMENT_CENTER, 160, 16, Color(0.2, 0.6, 0.1, min(_upgrade_flash, 1.0)))

	# Idle ambient particles — vine wisps
	if target == null:
		for ip in range(3):
			var iy = sin(_time * 1.1 + float(ip) * 2.2) * 16.0
			var ix = cos(_time * 0.7 + float(ip) * 1.8) * 14.0
			draw_circle(Vector2(ix, iy), 2.0, Color(0.3, 0.65, 0.2, 0.3 + sin(_time * 2.0 + float(ip)) * 0.1))
			draw_line(Vector2(ix, iy), Vector2(ix + 3, iy - 3), Color(0.25, 0.55, 0.15, 0.2), 1.0)

	# Ability cooldown ring
	var cd_max = 1.0 / fire_rate
	var cd_fill = clampf(1.0 - fire_cooldown / cd_max, 0.0, 1.0)
	if cd_fill >= 1.0:
		var cd_pulse = 0.5 + sin(_time * 4.0) * 0.3
		draw_arc(Vector2.ZERO, 28.0, 0, TAU, 32, Color(0.3, 0.65, 0.2, cd_pulse * 0.4), 2.0)
	elif cd_fill > 0.0:
		draw_arc(Vector2.ZERO, 28.0, -PI / 2.0, -PI / 2.0 + TAU * cd_fill, 32, Color(0.3, 0.65, 0.2, 0.3), 2.0)

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

# === ACTIVE HERO ABILITY: Jungle Roar (AoE damage + slow, 30s CD) ===
var active_ability_ready: bool = true
var active_ability_cooldown: float = 0.0
var active_ability_max_cd: float = 30.0

func activate_hero_ability() -> void:
	if not active_ability_ready:
		return
	for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if global_position.distance_to(e.global_position) < attack_range * _range_mult():
			if is_instance_valid(e) and e.has_method("take_damage"):
				var dmg = damage * 3.0 * _damage_mult()
				e.take_damage(dmg, "physical")
				register_damage(dmg)
			if e.has_method("apply_slow"):
				e.apply_slow(0.4, 3.0)
	active_ability_ready = false
	active_ability_cooldown = active_ability_max_cd
	if is_instance_valid(_main_node):
		_main_node.spawn_floating_text(global_position + Vector2(0, -40), "JUNGLE ROAR!", Color(0.4, 0.7, 0.2), 16.0, 1.5)

func get_active_ability_name() -> String:
	return "Jungle Roar"

func get_active_ability_desc() -> String:
	return "AoE dmg + slow (30s CD)"

func _damage_mult() -> float:
	return (1.0 + _synergy_buffs.get("damage", 0.0) + _meta_buffs.get("damage", 0.0)) * power_damage_mult

func _range_mult() -> float:
	var base = 1.0 + _synergy_buffs.get("range", 0.0) + _meta_buffs.get("range", 0.0)
	# Prog ability 6: Predator Sense — +25% range
	if prog_abilities[5]:
		base *= 1.25
	return base

func _speed_mult() -> float:
	var base = 1.0 + _synergy_buffs.get("attack_speed", 0.0) + _meta_buffs.get("attack_speed", 0.0)
	# Prog ability 1: Jungle Instinct — +10% attack speed
	if prog_abilities[0]:
		base *= 1.1
	# Prog ability 2: Ape Agility — +30% attack speed when active
	if _ape_agility_active:
		base *= 1.3
	return base

func _gold_mult() -> float:
	return 1.0 + _synergy_buffs.get("gold_bonus", 0.0) + _meta_buffs.get("gold_bonus", 0.0)
