extends Node2D
## Tarzan — melee/beast tower. Devastating melee attacks, vine swings, animal allies.
## Tier 1 (5000 DMG): Vine Swing — attacks reach +40% further
## Tier 2 (10000 DMG): Ape Strength — 15% chance to throw enemy back
## Tier 3 (15000 DMG): Animal Call — yell summons 3 temporary animal attackers
## Tier 4 (20000 DMG): King of the Apes — permanent companion, double damage, passive melee aura

# Base stats
var damage: float = 70.0
var fire_rate: float = 1.5
var attack_range: float = 120.0
var fire_cooldown: float = 0.0
var aim_angle: float = 0.0
var target: Node2D = null
var _draw_progress: float = 0.0
var gold_bonus: int = 3

# Animation timers
var _time: float = 0.0
var _attack_anim: float = 0.0

# Damage tracking and upgrades
var damage_dealt: float = 0.0
var upgrade_tier: int = 0
var _upgrade_flash: float = 0.0
var _upgrade_name: String = ""

# Tier 1: Vine Swing — extended melee range via projectile
var vine_range_mult: float = 1.0

# Tier 2: Ape Strength — knockback chance
var knockback_chance: float = 0.0

# Tier 3: Animal Call — summon temporary attackers on ability
var animal_call_count: int = 0

# Tier 4: King of the Apes — passive aura damage
var passive_aura_damage: float = 0.0
var companion_active: bool = false
var _companion_angle: float = 0.0

# Kill tracking
var kill_count: int = 0

# Ability: Lord of the Jungle — stun + animal summon
var ability_cooldown: float = 0.0
var ability_max_cooldown: float = 25.0
var _ability_flash: float = 0.0
var _ability_active: float = 0.0
var _animal_allies: Array = []

# === PROGRESSIVE ABILITIES (9 tiers, unlocked via lifetime damage) ===
const PROG_ABILITY_NAMES = [
	"Jungle Instinct", "Ape Agility", "Vine Master", "Tantor's Charge",
	"Animal Brotherhood", "Predator Sense", "Mangani War Cry",
	"Lord of Opar", "Legend of the Jungle"
]
const PROG_ABILITY_DESCS = [
	"Melee hits 20% harder, +10% attack speed",
	"15% chance to dodge incoming damage",
	"Vine attacks pull enemies closer by 30px",
	"Every 15s, charge forward dealing 4x to nearest",
	"Animal allies deal 50% more and last 2s longer",
	"Reveals hidden enemies, +25% range",
	"Every 20s, war cry stuns all enemies on screen for 1s",
	"Every 25s, golden vine strike hits all in range for 6x",
	"Permanent 3 animal allies, double passive aura damage"
]
var prog_abilities: Array = [false, false, false, false, false, false, false, false, false]
# Ability timers
var _tantor_charge_timer: float = 15.0
var _mangani_cry_timer: float = 20.0
var _opar_strike_timer: float = 25.0
# Visual flash timers
var _tantor_flash: float = 0.0
var _mangani_flash: float = 0.0
var _opar_flash: float = 0.0
var _legend_allies: Array = []

const STAT_UPGRADE_INTERVAL: float = 500.0
const ABILITY_THRESHOLD: float = 1500.0
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
	"Attacks reach +40% further",
	"15% chance to throw enemy back",
	"Yell summons 3 temporary animal attackers",
	"Permanent companion, double damage, passive aura"
]
const TIER_COSTS = [80, 175, 300, 500]
var is_selected: bool = false
var base_cost: int = 0

var vine_swing_scene = preload("res://scenes/vine_swing.tscn")

# Attack sounds — primal impact thud + grunt
var _attack_sounds: Array = []
var _attack_sounds_by_tier: Array = []
var _attack_player: AudioStreamPlayer

# Ability sounds
var _yell_sound: AudioStreamWAV
var _yell_player: AudioStreamPlayer
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
	_yell_player.volume_db = -5.0
	add_child(_yell_player)

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
	_ability_flash = max(_ability_flash - delta * 2.0, 0.0)
	_attack_anim = max(_attack_anim - delta * 3.0, 0.0)
	_ability_active = max(_ability_active - delta, 0.0)
	target = _find_nearest_enemy()

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

	# Ability: Lord of the Jungle
	if ability_cooldown > 0.0:
		ability_cooldown -= delta
	if ability_cooldown <= 0.0 and _has_enemies_in_range() and upgrade_tier >= 0:
		# Auto-activate ability when available and enemies present
		pass  # Manual activation via _use_ability or auto at tier 3+

	# Tier 4: Passive aura damage
	if passive_aura_damage > 0.0:
		var aura_dmg = passive_aura_damage * delta
		var aura_mult = 2.0 if prog_abilities[8] else 1.0
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if global_position.distance_to(enemy.global_position) < attack_range * _range_mult() * 0.8:
				if enemy.has_method("take_damage"):
					enemy.take_damage(aura_dmg * aura_mult * _damage_mult())
					register_damage(aura_dmg * aura_mult)

	# Tier 4: Companion orbit
	if companion_active:
		_companion_angle += delta * 1.5

	# Process animal allies
	var to_remove: Array = []
	for i in range(_animal_allies.size()):
		_animal_allies[i]["timer"] -= delta
		if _animal_allies[i]["timer"] <= 0.0:
			to_remove.append(i)
		else:
			# Animal ally attacks nearest enemy
			_animal_allies[i]["attack_cd"] -= delta
			if _animal_allies[i]["attack_cd"] <= 0.0:
				var nearest = _find_nearest_enemy()
				if nearest and nearest.has_method("take_damage"):
					var ally_dmg = damage * 0.4 * _damage_mult()
					if prog_abilities[4]:
						ally_dmg *= 1.5
					nearest.take_damage(ally_dmg)
					register_damage(ally_dmg)
				_animal_allies[i]["attack_cd"] = 1.2
	to_remove.reverse()
	for idx in to_remove:
		_animal_allies.remove_at(idx)

	# Progressive abilities
	_process_progressive_abilities(delta)

	queue_redraw()

func _has_enemies_in_range() -> bool:
	var eff_range = attack_range * _range_mult() * vine_range_mult
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
	var eff_range = attack_range * _range_mult() * vine_range_mult
	var nearest_dist: float = eff_range
	for enemy in enemies:
		var dist = global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest = enemy
			nearest_dist = dist
	return nearest

func _attack() -> void:
	if not target:
		return
	if _attack_player and _attack_sounds.size() > 0 and not _is_sfx_muted():
		_attack_player.stream = _attack_sounds[_get_note_index() % _attack_sounds.size()]
		_attack_player.play()

	var dist_to_target = global_position.distance_to(target.global_position)
	var base_melee_range = attack_range * _range_mult()

	# If target is within base melee range, do direct hit
	if dist_to_target <= base_melee_range:
		_melee_hit(target)
	else:
		# Extended range via vine swing projectile
		_fire_vine_swing(target)

func _melee_hit(t: Node2D) -> void:
	if not is_instance_valid(t) or not t.has_method("take_damage"):
		return
	var dmg = damage * _damage_mult()
	# Prog ability 1: Jungle Instinct — +20% damage
	if prog_abilities[0]:
		dmg *= 1.2
	# Tier 4: double damage
	if upgrade_tier >= 4:
		dmg *= 2.0

	var will_kill = t.health - dmg <= 0.0
	t.take_damage(dmg)
	register_damage(dmg)
	if will_kill:
		register_kill()
		if gold_bonus > 0:
			var main = get_tree().get_first_node_in_group("main")
			if main:
				main.add_gold(int(gold_bonus * _gold_mult()))

	# Tier 2+: Knockback chance
	if knockback_chance > 0.0 and randf() < knockback_chance:
		if is_instance_valid(t) and t.has_method("apply_knockback"):
			var kb_dir = global_position.direction_to(t.global_position)
			t.apply_knockback(kb_dir * 40.0)
		elif is_instance_valid(t):
			# Fallback — push position directly
			t.global_position += global_position.direction_to(t.global_position) * 30.0

	# Prog ability 3: Vine Master — pull enemies closer
	if prog_abilities[2] and is_instance_valid(t):
		var pull_dir = t.global_position.direction_to(global_position)
		t.global_position += pull_dir * 30.0

func _fire_vine_swing(t: Node2D) -> void:
	var vine = vine_swing_scene.instantiate()
	vine.global_position = global_position + Vector2.from_angle(aim_angle) * 16.0
	vine.damage = damage * _damage_mult()
	if prog_abilities[0]:
		vine.damage *= 1.2
	if upgrade_tier >= 4:
		vine.damage *= 2.0
	vine.target = t
	vine.gold_bonus = int(gold_bonus * _gold_mult())
	vine.source_tower = self
	vine.knockback = knockback_chance > 0.0 and randf() < knockback_chance
	vine.pull_closer = prog_abilities[2]
	get_tree().get_first_node_in_group("main").add_child(vine)

func use_ability() -> void:
	if ability_cooldown > 0.0:
		return
	if not _has_enemies_in_range():
		return
	ability_cooldown = ability_max_cooldown
	_ability_flash = 1.0
	_ability_active = 6.0  # Animal allies duration

	if _yell_player and not _is_sfx_muted():
		_yell_player.play()

	# Stun all enemies in range for 2s
	var eff_range = attack_range * _range_mult() * vine_range_mult
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(enemy.global_position) < eff_range:
			if enemy.has_method("apply_sleep"):
				enemy.apply_sleep(2.0)

	# Summon animal allies
	var ally_count = 2
	if upgrade_tier >= 3:
		ally_count = 3 + animal_call_count
	var ally_duration = 6.0
	if prog_abilities[4]:
		ally_duration += 2.0
	for i in range(ally_count):
		var ally_angle = TAU * float(i) / float(ally_count)
		_animal_allies.append({
			"angle": ally_angle,
			"timer": ally_duration,
			"attack_cd": 0.5,
			"type": i % 3  # 0=ape, 1=leopard, 2=elephant
		})

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
	damage *= 1.12
	fire_rate *= 1.08
	attack_range += 6.0
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
		1: # Vine Swing — +40% range via projectile
			vine_range_mult = 1.4
			damage = 85.0
			fire_rate = 1.7
			attack_range = 130.0
		2: # Ape Strength — 15% knockback
			knockback_chance = 0.15
			damage = 105.0
			fire_rate = 1.9
			attack_range = 140.0
			gold_bonus = 4
		3: # Animal Call — summon allies on ability
			animal_call_count = 3
			damage = 130.0
			fire_rate = 2.1
			attack_range = 150.0
			ability_max_cooldown = 20.0
			gold_bonus = 5
		4: # King of the Apes — permanent companion, double damage, passive aura
			damage = 160.0
			fire_rate = 2.4
			attack_range = 160.0
			gold_bonus = 7
			passive_aura_damage = 15.0
			companion_active = true
			ability_max_cooldown = 16.0
			knockback_chance = 0.25
			vine_range_mult = 1.6

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
	# Primal impact thuds — fist/vine hitting flesh + grunt
	var impact_notes := [73.42, 87.31, 98.00, 110.00, 98.00, 87.31, 73.42, 110.00]  # D2, F2, G2, A2, G2, F2, D2, A2 (D minor walking bass)
	var mix_rate := 44100
	_attack_sounds_by_tier = []

	# --- Tier 0: Basic Fist Impact (low thud + grunt) ---
	var t0 := []
	for note_idx in impact_notes.size():
		var freq: float = impact_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.15))
		for i in samples.size():
			var t := float(i) / mix_rate
			# Heavy low thud
			var env := exp(-t * 25.0) * 0.4
			var thud := sin(t * freq * TAU) * 0.6
			thud += sin(t * freq * 0.5 * TAU) * 0.3 * exp(-t * 30.0)
			# Fleshy slap noise
			var slap := (randf() * 2.0 - 1.0) * exp(-t * 200.0) * 0.35
			# Brief grunt (vocal formant ~150Hz)
			var grunt := sin(t * 150.0 * TAU) * 0.15 * exp(-t * 20.0)
			grunt += sin(t * 300.0 * TAU) * 0.08 * exp(-t * 30.0)
			samples[i] = clampf((thud + grunt) * env + slap, -1.0, 1.0)
		t0.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t0)

	# --- Tier 1: Vine Lash (whip crack + thud) ---
	var t1 := []
	for note_idx in impact_notes.size():
		var freq: float = impact_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.18))
		for i in samples.size():
			var t := float(i) / mix_rate
			# Whip crack — high frequency burst
			var crack := (randf() * 2.0 - 1.0) * exp(-t * 400.0) * 0.4
			crack += sin(t * 2000.0 * TAU) * exp(-t * 600.0) * 0.2
			# Follow-through thud
			var dt := t - 0.02
			var thud := 0.0
			if dt > 0.0:
				thud = sin(dt * freq * TAU) * exp(-dt * 22.0) * 0.35
				thud += sin(dt * freq * 0.5 * TAU) * exp(-dt * 28.0) * 0.2
			# Grunt
			var grunt := sin(t * 160.0 * TAU) * 0.1 * exp(-t * 18.0)
			samples[i] = clampf(crack + thud + grunt, -1.0, 1.0)
		t1.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t1)

	# --- Tier 2: Ape Smash (heavy impact + bone thump) ---
	var t2 := []
	for note_idx in impact_notes.size():
		var freq: float = impact_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.2))
		for i in samples.size():
			var t := float(i) / mix_rate
			# Massive low impact
			var env := exp(-t * 18.0) * 0.45
			var thud := sin(t * freq * TAU) * 0.7
			thud += sin(t * freq * 2.0 * TAU) * 0.2 * exp(-t * 25.0)
			# Bone crunch noise
			var crunch := (randf() * 2.0 - 1.0) * exp(-t * 150.0) * 0.3
			# Deep grunt
			var grunt := sin(t * 120.0 * TAU) * 0.2 * exp(-t * 15.0)
			grunt += sin(t * 240.0 * TAU) * 0.1 * exp(-t * 20.0)
			samples[i] = clampf((thud + grunt) * env + crunch, -1.0, 1.0)
		t2.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t2)

	# --- Tier 3: Beast Strike (double impact + animal snarl) ---
	var t3 := []
	for note_idx in impact_notes.size():
		var freq: float = impact_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.22))
		for i in samples.size():
			var t := float(i) / mix_rate
			# First hit
			var env1 := exp(-t * 30.0) * 0.35
			var s1 := sin(t * freq * TAU) * env1
			# Second hit (delayed)
			var dt := t - 0.04
			var s2 := 0.0
			if dt > 0.0:
				s2 = sin(dt * freq * 1.15 * TAU) * exp(-dt * 35.0) * 0.3
			# Animal snarl (noise + low freq)
			var snarl := sin(t * 90.0 * TAU) * 0.12 * exp(-t * 10.0)
			snarl += (randf() * 2.0 - 1.0) * 0.1 * exp(-t * 12.0)
			var slap := (randf() * 2.0 - 1.0) * exp(-t * 300.0) * 0.25
			samples[i] = clampf(s1 + s2 + snarl + slap, -1.0, 1.0)
		t3.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t3)

	# --- Tier 4: Primal King (massive reverberant impact + roar) ---
	var t4 := []
	for note_idx in impact_notes.size():
		var freq: float = impact_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.28))
		for i in samples.size():
			var t := float(i) / mix_rate
			# Massive impact with reverb tail
			var env := exp(-t * 12.0) * 0.4
			var hit := sin(t * freq * TAU) * 0.6
			hit += sin(t * freq * 2.0 * TAU) * 0.2
			hit += sin(t * freq * 3.0 * TAU) * 0.1 * exp(-t * 20.0)
			# Sub-bass rumble
			var rumble := sin(t * freq * 0.5 * TAU) * 0.15 * exp(-t * 8.0)
			# Brief roar
			var roar := sin(t * 130.0 * TAU) * 0.15 * exp(-t * 8.0)
			roar += sin(t * 260.0 * TAU) * 0.08 * exp(-t * 10.0)
			roar += (randf() * 2.0 - 1.0) * 0.12 * exp(-t * 10.0)
			# Heroic shimmer
			var shim := sin(t * freq * 2.005 * TAU) * 0.06 * exp(-t * 8.0)
			var snap := (randf() * 2.0 - 1.0) * exp(-t * 350.0) * 0.2
			samples[i] = clampf((hit + rumble) * env + roar * env + shim * env + snap, -1.0, 1.0)
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
	# Applied dynamically in _melee_hit and _fire_vine_swing
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

func _process_progressive_abilities(delta: float) -> void:
	# Visual flash decay
	_tantor_flash = max(_tantor_flash - delta * 2.0, 0.0)
	_mangani_flash = max(_mangani_flash - delta * 2.0, 0.0)
	_opar_flash = max(_opar_flash - delta * 1.5, 0.0)

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
		# Permanent allies attack
		for ally in _legend_allies:
			ally["attack_cd"] -= delta
			ally["angle"] += delta * 1.0
			if ally["attack_cd"] <= 0.0:
				var nearest = _find_nearest_enemy()
				if nearest and nearest.has_method("take_damage"):
					var dmg = damage * 0.5 * _damage_mult()
					nearest.take_damage(dmg)
					register_damage(dmg)
				ally["attack_cd"] = 1.0

func _tantor_charge() -> void:
	_tantor_flash = 1.0
	var nearest = _find_nearest_enemy()
	if nearest and nearest.has_method("take_damage"):
		var dmg = damage * 4.0 * _damage_mult()
		nearest.take_damage(dmg)
		register_damage(dmg)

func _mangani_war_cry() -> void:
	_mangani_flash = 1.0
	if _yell_player and not _is_sfx_muted():
		_yell_player.play()
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("apply_sleep"):
			e.apply_sleep(1.0)

func _opar_strike() -> void:
	_opar_flash = 1.0
	var eff_range = attack_range * _range_mult() * vine_range_mult
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) < eff_range:
			if e.has_method("take_damage"):
				var dmg = damage * 6.0 * _damage_mult()
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
	draw_arc(Vector2.ZERO, attack_range * vine_range_mult, 0, TAU, 64, Color(1, 1, 1, 0.06), 1.0)

	# === 3. AIM DIRECTION ===
	var dir = Vector2.from_angle(aim_angle)
	var perp = dir.rotated(PI / 2.0)

	# === 4. IDLE ANIMATION (primal weight shift) ===
	var bounce = abs(sin(_time * 2.5)) * 3.0
	var breathe = sin(_time * 1.8) * 2.5
	var weight_shift = sin(_time * 1.0) * 3.0  # Heavy primal weight shift
	var bob = Vector2(weight_shift, -bounce - breathe)

	# Tier 4: Slight hover from jungle energy
	var fly_offset = Vector2.ZERO
	if upgrade_tier >= 4:
		fly_offset = Vector2(0, -6.0 + sin(_time * 1.3) * 2.0)

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

	# === 7. ABILITY FLASH (Lord of the Jungle) ===
	if _ability_flash > 0.0:
		var ring_r = 36.0 + (1.0 - _ability_flash) * 80.0
		draw_circle(Vector2.ZERO, ring_r, Color(0.3, 0.7, 0.1, _ability_flash * 0.15))
		draw_arc(Vector2.ZERO, ring_r, 0, TAU, 32, Color(0.4, 0.8, 0.2, _ability_flash * 0.3), 2.5)
		# Radiating jungle energy lines
		for hi in range(10):
			var ha = TAU * float(hi) / 10.0 + _ability_flash * 3.0
			var h_inner = Vector2.from_angle(ha) * (ring_r * 0.4)
			var h_outer = Vector2.from_angle(ha) * (ring_r + 5.0)
			draw_line(h_inner, h_outer, Color(0.3, 0.8, 0.15, _ability_flash * 0.4), 1.5)

	# === PROGRESSIVE ABILITY VISUAL EFFECTS ===
	# Ability 4: Tantor's Charge flash
	if _tantor_flash > 0.0:
		var tc_r = 25.0 + (1.0 - _tantor_flash) * 60.0
		draw_arc(Vector2.ZERO, tc_r, 0, TAU, 24, Color(0.5, 0.4, 0.3, _tantor_flash * 0.4), 3.5)
		draw_arc(Vector2.ZERO, tc_r * 0.6, 0, TAU, 16, Color(0.6, 0.5, 0.3, _tantor_flash * 0.3), 2.5)

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

	# === 10. ANIMAL ALLIES (drawn around base) ===
	for ally in _animal_allies:
		var ally_r = 30.0 + sin(_time * 2.0 + ally["angle"]) * 5.0
		ally["angle"] += 0.02
		var ally_pos = body_offset + Vector2.from_angle(ally["angle"]) * ally_r
		match ally["type"]:
			0: # Ape — dark brown circle with arms
				draw_circle(ally_pos, 5.0, Color(0.35, 0.22, 0.10))
				draw_circle(ally_pos, 3.5, Color(0.42, 0.28, 0.14))
				draw_circle(ally_pos + Vector2(0, -3), 3.0, Color(0.38, 0.24, 0.12))
				# Ape arms
				draw_line(ally_pos + Vector2(-4, 0), ally_pos + Vector2(-7, 3), Color(0.35, 0.22, 0.10), 2.0)
				draw_line(ally_pos + Vector2(4, 0), ally_pos + Vector2(7, 3), Color(0.35, 0.22, 0.10), 2.0)
			1: # Leopard — spotted yellow
				draw_circle(ally_pos, 4.0, Color(0.82, 0.68, 0.28))
				draw_circle(ally_pos + Vector2(0, -2.5), 2.5, Color(0.85, 0.72, 0.32))
				# Spots
				draw_circle(ally_pos + Vector2(-1.5, 0.5), 1.0, Color(0.45, 0.30, 0.10, 0.5))
				draw_circle(ally_pos + Vector2(1.5, -0.5), 0.8, Color(0.45, 0.30, 0.10, 0.5))
				# Tail
				draw_line(ally_pos + Vector2(3, 2), ally_pos + Vector2(8, 0), Color(0.82, 0.68, 0.28), 1.5)
			2: # Elephant — gray with trunk
				draw_circle(ally_pos, 6.0, Color(0.55, 0.52, 0.50))
				draw_circle(ally_pos + Vector2(0, -3), 4.0, Color(0.58, 0.55, 0.52))
				# Trunk
				draw_line(ally_pos + Vector2(0, -1), ally_pos + Vector2(4, 3), Color(0.52, 0.50, 0.48), 2.5)
				# Ears
				draw_circle(ally_pos + Vector2(-5, -2), 3.0, Color(0.50, 0.48, 0.46, 0.6))
				draw_circle(ally_pos + Vector2(5, -2), 3.0, Color(0.50, 0.48, 0.46, 0.6))

	# Permanent legend allies (prog ability 9)
	for ally in _legend_allies:
		var ally_r = 38.0
		var ally_pos = body_offset + Vector2.from_angle(ally["angle"]) * ally_r
		draw_circle(ally_pos, 4.5, Color(0.85, 0.72, 0.25, 0.6))
		draw_circle(ally_pos, 3.0, Color(1.0, 0.9, 0.4, 0.4))

	# === 11. CHARACTER POSITIONS (tall proportions ~56px) ===
	var feet_y = body_offset + Vector2(hip_shift * 1.0, 14.0)
	var leg_top = body_offset + Vector2(hip_shift * 0.6, -2.0)
	var torso_center = body_offset + Vector2(shoulder_counter * 0.5, -10.0)
	var neck_base = body_offset + Vector2(shoulder_counter * 0.7, -20.0)
	var head_center = body_offset + Vector2(shoulder_counter * 0.3, -32.0)

	# === 12. TIER-SPECIFIC EFFECTS ===

	# Tier 1+: Vine tendrils swirling around body
	if upgrade_tier >= 1:
		for li in range(4 + upgrade_tier):
			var la = _time * (0.5 + fmod(float(li) * 1.37, 0.4)) + float(li) * TAU / float(4 + upgrade_tier)
			var lr = 18.0 + fmod(float(li) * 3.7, 12.0)
			var vine_pos = body_offset + Vector2(cos(la) * lr, sin(la) * lr * 0.5 + 8.0)
			var vine_alpha = 0.25 + sin(_time * 1.5 + float(li)) * 0.1
			draw_circle(vine_pos, 1.8, Color(0.18, 0.48, 0.10, vine_alpha))
			# Tiny leaf
			var leaf_r = _time * 2.0 + float(li) * 1.5
			var ldir = Vector2.from_angle(leaf_r)
			draw_line(vine_pos, vine_pos + ldir * 2.5, Color(0.22, 0.55, 0.12, vine_alpha * 0.8), 1.0)

	# Tier 2+: Glowing fist
	if upgrade_tier >= 2:
		var fist_pos = neck_base + Vector2(18 + shoulder_counter, 4) + dir * (punch_extend * 0.3)
		var glow_pulse = (sin(_time * 3.0) + 1.0) * 0.5
		draw_circle(fist_pos, 8.0 + glow_pulse * 2.0, Color(0.9, 0.65, 0.2, 0.1 + glow_pulse * 0.05))
		draw_circle(fist_pos, 5.0 + glow_pulse, Color(1.0, 0.8, 0.3, 0.08))

	# Tier 3+: Small animals around base
	if upgrade_tier >= 3 and _animal_allies.size() == 0:
		for ai in range(3):
			var aa = _time * 0.8 + float(ai) * TAU / 3.0
			var apos = body_offset + Vector2(cos(aa) * 25.0, sin(aa) * 10.0 + 12.0)
			draw_circle(apos, 3.0, Color(0.42, 0.30, 0.14, 0.4))
			draw_circle(apos, 2.0, Color(0.50, 0.36, 0.18, 0.3))

	# Tier 4: Full jungle aura with floating leaves
	if upgrade_tier >= 4:
		for fd in range(10):
			var fd_seed = float(fd) * 2.37
			var fd_angle = _time * (0.3 + fmod(fd_seed, 0.4)) + fd_seed
			var fd_radius = 28.0 + fmod(fd_seed * 5.3, 30.0)
			var fd_pos = body_offset + Vector2(cos(fd_angle) * fd_radius, sin(fd_angle) * fd_radius * 0.6)
			var fd_alpha = 0.2 + sin(_time * 2.5 + fd_seed * 2.0) * 0.1
			# Leaf shape
			var leaf_angle = _time * 1.5 + fd_seed
			var ldv = Vector2.from_angle(leaf_angle)
			var lpv = ldv.rotated(PI / 2.0)
			var leaf_sz = 2.5 + sin(_time * 2.0 + fd_seed) * 0.8
			draw_line(fd_pos - ldv * leaf_sz, fd_pos + ldv * leaf_sz, Color(0.20, 0.55, 0.12, fd_alpha), 1.5)
			draw_line(fd_pos - lpv * leaf_sz * 0.4, fd_pos + lpv * leaf_sz * 0.4, Color(0.25, 0.60, 0.15, fd_alpha * 0.6), 1.0)

		# Companion ape silhouette (orbiting)
		if companion_active:
			var comp_pos = body_offset + Vector2.from_angle(_companion_angle) * 35.0
			# Ape body
			draw_circle(comp_pos, 8.0, Color(0.30, 0.18, 0.08, 0.5))
			draw_circle(comp_pos, 6.0, Color(0.38, 0.24, 0.12, 0.4))
			# Ape head
			draw_circle(comp_pos + Vector2(0, -6), 5.0, Color(0.32, 0.20, 0.10, 0.5))
			draw_circle(comp_pos + Vector2(0, -6), 3.5, Color(0.40, 0.26, 0.14, 0.4))
			# Arms
			draw_line(comp_pos + Vector2(-6, 0), comp_pos + Vector2(-10, 5), Color(0.30, 0.18, 0.08, 0.45), 3.0)
			draw_line(comp_pos + Vector2(6, 0), comp_pos + Vector2(10, 5), Color(0.30, 0.18, 0.08, 0.45), 3.0)
			# Eyes (glowing)
			draw_circle(comp_pos + Vector2(-2, -7), 1.0, Color(0.9, 0.7, 0.2, 0.6))
			draw_circle(comp_pos + Vector2(2, -7), 1.0, Color(0.9, 0.7, 0.2, 0.6))

	# === 13. CHARACTER BODY ===

	# --- Bare feet (Tarzan doesn't wear shoes) ---
	var l_foot = feet_y + Vector2(-7, 0)
	var r_foot = feet_y + Vector2(7, 0)
	# Bare foot soles
	draw_circle(l_foot, 5.0, skin_shadow)
	draw_circle(l_foot, 3.8, skin_base)
	draw_circle(r_foot, 5.0, skin_shadow)
	draw_circle(r_foot, 3.8, skin_base)
	# Toes
	for ti in range(4):
		var tx = -3.0 + float(ti) * 2.0
		draw_circle(l_foot + Vector2(tx - 2, -1.5), 1.0, skin_highlight)
		draw_circle(r_foot + Vector2(tx + 2, -1.5), 1.0, skin_highlight)
	# Foot arch highlight
	draw_arc(l_foot, 3.2, PI + 0.3, TAU - 0.3, 6, skin_highlight, 0.8)
	draw_arc(r_foot, 3.2, PI + 0.3, TAU - 0.3, 6, skin_highlight, 0.8)
	# Dirty/calloused soles
	draw_arc(l_foot, 4.5, 0.3, PI - 0.3, 8, Color(0.55, 0.40, 0.28, 0.3), 1.0)
	draw_arc(r_foot, 4.5, 0.3, PI - 0.3, 8, Color(0.55, 0.40, 0.28, 0.3), 1.0)

	# --- MUSCULAR LEGS (powerful, bare) ---
	var l_hip = leg_top + Vector2(-6, 0)
	var r_hip = leg_top + Vector2(6, 0)
	var l_knee = l_foot.lerp(l_hip, 0.45) + Vector2(-1.5, 0)
	var r_knee = r_foot.lerp(r_hip, 0.45) + Vector2(1.5, 0)
	# LEFT THIGH — very muscular
	var lt_dir = (l_knee - l_hip).normalized()
	var lt_perp = lt_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		l_hip + lt_perp * 5.5, l_hip - lt_perp * 4.5,
		l_hip.lerp(l_knee, 0.4) - lt_perp * 6.0,
		l_knee - lt_perp * 4.5, l_knee + lt_perp * 4.5,
		l_hip.lerp(l_knee, 0.4) + lt_perp * 6.5,
	]), skin_shadow)
	draw_colored_polygon(PackedVector2Array([
		l_hip + lt_perp * 3.5, l_hip - lt_perp * 2.5,
		l_knee - lt_perp * 3.0, l_knee + lt_perp * 3.0,
	]), skin_base)
	# Quad muscle highlight
	draw_circle(l_hip.lerp(l_knee, 0.35) + lt_perp * 2.0, 3.0, skin_highlight)
	# RIGHT THIGH
	var rt_dir = (r_knee - r_hip).normalized()
	var rt_perp = rt_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		r_hip - rt_perp * 5.5, r_hip + rt_perp * 4.5,
		r_hip.lerp(r_knee, 0.4) + rt_perp * 6.0,
		r_knee + rt_perp * 4.5, r_knee - rt_perp * 4.5,
		r_hip.lerp(r_knee, 0.4) - rt_perp * 6.5,
	]), skin_shadow)
	draw_colored_polygon(PackedVector2Array([
		r_hip - rt_perp * 3.5, r_hip + rt_perp * 2.5,
		r_knee + rt_perp * 3.0, r_knee - rt_perp * 3.0,
	]), skin_base)
	draw_circle(r_hip.lerp(r_knee, 0.35) - rt_perp * 2.0, 3.0, skin_highlight)
	# Knee joints
	draw_circle(l_knee, 4.5, skin_shadow)
	draw_circle(l_knee, 3.5, skin_base)
	draw_circle(r_knee, 4.5, skin_shadow)
	draw_circle(r_knee, 3.5, skin_base)
	# LEFT CALF
	var l_calf_mid = l_knee.lerp(l_foot + Vector2(0, -3), 0.4) + Vector2(-2.0, 0)
	var lc_dir = (l_foot + Vector2(0, -3) - l_knee).normalized()
	var lc_perp = lc_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		l_knee + lc_perp * 4.5, l_knee - lc_perp * 4.0,
		l_calf_mid - lc_perp * 5.5, l_calf_mid + lc_perp * 5.0,
	]), skin_shadow)
	draw_colored_polygon(PackedVector2Array([
		l_calf_mid + lc_perp * 5.0, l_calf_mid - lc_perp * 5.5,
		l_foot + Vector2(-3, -3), l_foot + Vector2(3, -3),
	]), skin_shadow)
	draw_circle(l_calf_mid, 3.5, skin_highlight)
	# RIGHT CALF
	var r_calf_mid = r_knee.lerp(r_foot + Vector2(0, -3), 0.4) + Vector2(2.0, 0)
	var rc_dir = (r_foot + Vector2(0, -3) - r_knee).normalized()
	var rc_perp = rc_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		r_knee - rc_perp * 4.5, r_knee + rc_perp * 4.0,
		r_calf_mid + rc_perp * 5.5, r_calf_mid - rc_perp * 5.0,
	]), skin_shadow)
	draw_colored_polygon(PackedVector2Array([
		r_calf_mid - rc_perp * 5.0, r_calf_mid + rc_perp * 5.5,
		r_foot + Vector2(3, -3), r_foot + Vector2(-3, -3),
	]), skin_shadow)
	draw_circle(r_calf_mid, 3.5, skin_highlight)

	# --- LOINCLOTH (brown leather) ---
	var loincloth_pts = PackedVector2Array([
		leg_top + Vector2(-8, -1),
		leg_top + Vector2(8, -1),
		leg_top + Vector2(6, 8),
		leg_top + Vector2(2, 12 + sin(_time * 2.0) * 2.0),
		leg_top + Vector2(-2, 11 + sin(_time * 2.2 + 0.5) * 2.0),
		leg_top + Vector2(-6, 8),
	])
	draw_colored_polygon(loincloth_pts, Color(0.42, 0.26, 0.12))
	# Lighter center panel
	var loincloth_inner = PackedVector2Array([
		leg_top + Vector2(-4, 0),
		leg_top + Vector2(4, 0),
		leg_top + Vector2(3, 7),
		leg_top + Vector2(-3, 7),
	])
	draw_colored_polygon(loincloth_inner, Color(0.50, 0.32, 0.16, 0.5))
	# Frayed edges
	for fi in range(4):
		var fx = -5.0 + float(fi) * 3.5
		var fray_len = 2.0 + sin(_time * 1.8 + float(fi) * 1.3) * 1.0
		draw_line(leg_top + Vector2(fx, 9), leg_top + Vector2(fx + 0.5, 9 + fray_len), Color(0.38, 0.22, 0.10, 0.5), 0.8)
	# Belt/waistband
	draw_line(leg_top + Vector2(-9, -1), leg_top + Vector2(9, -1), Color(0.35, 0.20, 0.08), 3.0)
	draw_line(leg_top + Vector2(-8, -1), leg_top + Vector2(8, -1), Color(0.44, 0.28, 0.12), 1.8)

	# --- MUSCULAR TORSO (bare chest, V-taper) ---
	# Very broad shoulders (±20px), very narrow waist (±8px) — extreme V-taper
	var torso_pts = PackedVector2Array([
		leg_top + Vector2(-8, 0),
		leg_top + Vector2(-9, -3),
		torso_center + Vector2(-16, 0),
		neck_base + Vector2(-20, 0),
		neck_base + Vector2(20, 0),
		torso_center + Vector2(16, 0),
		leg_top + Vector2(9, -3),
		leg_top + Vector2(8, 0),
	])
	draw_colored_polygon(torso_pts, skin_shadow)
	# Inner torso highlight
	var torso_hi = PackedVector2Array([
		leg_top + Vector2(-6, -1),
		torso_center + Vector2(-10, 0),
		torso_center + Vector2(10, 0),
		leg_top + Vector2(6, -1),
	])
	draw_colored_polygon(torso_hi, skin_base)
	# PECTORAL definition — massive pecs
	draw_arc(neck_base + Vector2(-7, 6), 7.5, PI * 0.15, PI * 0.92, 12, Color(skin_shadow.r - 0.08, skin_shadow.g - 0.06, skin_shadow.b - 0.04, 0.4), 1.8)
	draw_arc(neck_base + Vector2(7, 6), 7.5, PI * 0.08, PI * 0.85, 12, Color(skin_shadow.r - 0.08, skin_shadow.g - 0.06, skin_shadow.b - 0.04, 0.4), 1.8)
	# Pec fills
	draw_circle(neck_base + Vector2(-6, 8), 5.0, Color(skin_base.r + 0.02, skin_base.g + 0.01, skin_base.b, 0.2))
	draw_circle(neck_base + Vector2(6, 8), 5.0, Color(skin_base.r + 0.02, skin_base.g + 0.01, skin_base.b, 0.2))
	# Sternum line
	draw_line(neck_base + Vector2(0, 3), torso_center + Vector2(0, 2), Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.3), 1.2)
	# ABS — 6-pack definition
	for ab_row in range(3):
		var aby = torso_center.y - 4.0 + float(ab_row) * 4.5
		draw_line(body_offset + Vector2(-5, aby), body_offset + Vector2(5, aby), Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.15), 0.8)
	# Oblique lines
	draw_line(torso_center + Vector2(-12, -5), leg_top + Vector2(-8, 0), Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.2), 1.0)
	draw_line(torso_center + Vector2(12, -5), leg_top + Vector2(8, 0), Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.2), 1.0)
	# Center abs line
	draw_line(torso_center + Vector2(0, -6), leg_top + Vector2(0, 0), Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.2), 0.8)

	# --- Vine wrapped around torso (diagonal) ---
	var vine_sway = sin(_time * 1.5) * 2.0
	for vsi in range(7):
		var vt = float(vsi) / 6.0
		var vx = lerp(-12.0, 10.0, vt) + vine_sway * (0.5 - vt)
		var vy = lerp(neck_base.y + 2, leg_top.y, vt)
		var vine_pt = body_offset + Vector2(vx + shoulder_counter * (1.0 - vt), vy - body_offset.y)
		if vsi > 0:
			var prev_vt = float(vsi - 1) / 6.0
			var pvx = lerp(-12.0, 10.0, prev_vt) + vine_sway * (0.5 - prev_vt)
			var pvy = lerp(neck_base.y + 2, leg_top.y, prev_vt)
			var prev_pt = body_offset + Vector2(pvx + shoulder_counter * (1.0 - prev_vt), pvy - body_offset.y)
			draw_line(prev_pt, vine_pt, Color(0.15, 0.42, 0.08), 2.5)
			draw_line(prev_pt, vine_pt, Color(0.22, 0.52, 0.14, 0.4), 1.2)
		# Leaf at some vine points
		if vsi % 3 == 1:
			var lf_dir = Vector2.from_angle(_time + float(vsi))
			draw_line(vine_pt, vine_pt + lf_dir * 3.5, Color(0.2, 0.5, 0.12, 0.5), 1.5)

	# --- Bone necklace ---
	var necklace_center = neck_base + Vector2(0, 4)
	# String
	draw_arc(necklace_center, 10.0, 0.2, PI - 0.2, 12, Color(0.50, 0.38, 0.22, 0.5), 1.0)
	# Bones/teeth
	for bi in range(5):
		var bone_t = 0.3 + float(bi) * 0.1
		var bone_a = bone_t * PI
		var bone_pos = necklace_center + Vector2.from_angle(bone_a) * 10.0
		# Tooth/bone shape
		draw_line(bone_pos, bone_pos + Vector2(0, 3.5), Color(0.88, 0.82, 0.72), 2.0)
		draw_line(bone_pos, bone_pos + Vector2(0, 3.5), Color(0.95, 0.90, 0.80, 0.4), 1.0)
		draw_circle(bone_pos + Vector2(0, 3.5), 0.8, Color(0.85, 0.80, 0.68))
		# Joint on string
		draw_circle(bone_pos, 1.0, Color(0.72, 0.60, 0.40, 0.5))

	# --- Father's hunting knife at belt ---
	var knife_pos = leg_top + Vector2(8, 1)
	# Sheath
	draw_line(knife_pos, knife_pos + Vector2(2, 10), Color(0.35, 0.22, 0.10), 4.0)
	draw_line(knife_pos, knife_pos + Vector2(2, 10), Color(0.42, 0.28, 0.14, 0.5), 2.5)
	# Handle sticking out
	draw_line(knife_pos + Vector2(0, -1), knife_pos + Vector2(-1, -6), Color(0.50, 0.35, 0.18), 3.0)
	draw_line(knife_pos + Vector2(0, -1), knife_pos + Vector2(-1, -6), Color(0.58, 0.42, 0.22, 0.5), 1.5)
	# Pommel
	draw_circle(knife_pos + Vector2(-1, -6), 1.5, Color(0.72, 0.55, 0.20))
	# Guard
	draw_line(knife_pos + Vector2(-2.5, -1), knife_pos + Vector2(2.5, -1), Color(0.65, 0.50, 0.18), 1.5)

	# --- Shoulder muscles (massive, bare) ---
	var l_shoulder = neck_base + Vector2(-18, 0)
	var r_shoulder = neck_base + Vector2(18, 0)
	# Left deltoid
	draw_circle(l_shoulder, 7.5, skin_shadow)
	draw_circle(l_shoulder, 5.5, skin_base)
	draw_circle(l_shoulder + Vector2(-1, -1), 3.5, skin_highlight)
	# Deltoid striations
	draw_line(l_shoulder + Vector2(-3, -4), l_shoulder + Vector2(-1, 4), Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.2), 0.8)
	draw_line(l_shoulder + Vector2(0, -5), l_shoulder + Vector2(1, 3), Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.15), 0.6)
	# Right deltoid
	draw_circle(r_shoulder, 7.5, skin_shadow)
	draw_circle(r_shoulder, 5.5, skin_base)
	draw_circle(r_shoulder + Vector2(1, -1), 3.5, skin_highlight)
	draw_line(r_shoulder + Vector2(3, -4), r_shoulder + Vector2(1, 4), Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.2), 0.8)
	draw_line(r_shoulder + Vector2(0, -5), r_shoulder + Vector2(-1, 3), Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.15), 0.6)

	# --- LEFT ARM (raised, holding vine) ---
	var vine_hand = l_shoulder + Vector2(-6, -20 + sin(_time * 1.2) * 3.0)
	var l_elbow = l_shoulder + (vine_hand - l_shoulder) * 0.45 + Vector2(-4, 0)
	var la_dir = (l_elbow - l_shoulder).normalized()
	var la_perp = la_dir.rotated(PI / 2.0)
	# Upper arm — massive bicep
	draw_colored_polygon(PackedVector2Array([
		l_shoulder - la_perp * 5.5, l_shoulder + la_perp * 5.0,
		l_shoulder.lerp(l_elbow, 0.35) + la_perp * 6.5,
		l_elbow + la_perp * 4.5, l_elbow - la_perp * 4.0,
		l_shoulder.lerp(l_elbow, 0.45) - la_perp * 6.5,
	]), skin_shadow)
	draw_colored_polygon(PackedVector2Array([
		l_shoulder - la_perp * 3.5, l_shoulder + la_perp * 3.0,
		l_elbow + la_perp * 2.5, l_elbow - la_perp * 2.5,
	]), skin_base)
	# Bicep peak
	draw_circle(l_shoulder.lerp(l_elbow, 0.35) + la_perp * 2.5, 3.5, skin_highlight)
	# Elbow
	draw_circle(l_elbow, 4.0, skin_shadow)
	draw_circle(l_elbow, 3.0, skin_base)
	# Forearm
	var lf_dir = (vine_hand - l_elbow).normalized()
	var lf_perp = lf_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		l_elbow + lf_perp * 4.5, l_elbow - lf_perp * 4.0,
		vine_hand - lf_perp * 2.5, vine_hand + lf_perp * 2.5,
	]), skin_shadow)
	draw_colored_polygon(PackedVector2Array([
		l_elbow + lf_perp * 2.5, l_elbow - lf_perp * 2.0,
		vine_hand - lf_perp * 1.5, vine_hand + lf_perp * 1.5,
	]), skin_base)
	# Forearm muscle definition
	draw_circle(l_elbow.lerp(vine_hand, 0.3) + lf_perp * 1.5, 2.5, skin_highlight)
	# Hand gripping vine
	draw_circle(vine_hand, 4.0, skin_shadow)
	draw_circle(vine_hand, 3.0, skin_base)
	# Fingers curled around vine
	for fi in range(3):
		var fa = float(fi - 1) * 0.4
		draw_circle(vine_hand + Vector2.from_angle(fa + PI * 0.5) * 3.5, 1.2, skin_base)
	# Vine going up from hand
	var vine_top = vine_hand + Vector2(-2, -25 + sin(_time * 0.8) * 2.0)
	draw_line(vine_hand, vine_top, Color(0.15, 0.42, 0.08), 3.0)
	draw_line(vine_hand, vine_top, Color(0.22, 0.52, 0.14, 0.4), 1.5)
	# Leaves on vine
	for vli in range(3):
		var vlt = 0.2 + float(vli) * 0.3
		var vlp = vine_hand.lerp(vine_top, vlt)
		var vl_sway = sin(_time * 2.0 + float(vli) * 1.5) * 2.0
		var vl_d = Vector2(3.0 + vl_sway, -1.0)
		draw_line(vlp, vlp + vl_d, Color(0.2, 0.5, 0.12), 2.0)
		draw_line(vlp, vlp + vl_d.rotated(0.6) * 0.7, Color(0.25, 0.55, 0.15, 0.6), 1.5)

	# --- RIGHT ARM (large fist, punching direction) ---
	var fist_target = r_shoulder + Vector2(6, 4) + dir * (14.0 + punch_extend)
	var r_elbow = r_shoulder + (fist_target - r_shoulder) * 0.4
	var ra_dir = (r_elbow - r_shoulder).normalized()
	var ra_perp = ra_dir.rotated(PI / 2.0)
	# Upper arm — massive
	draw_colored_polygon(PackedVector2Array([
		r_shoulder + ra_perp * 5.5, r_shoulder - ra_perp * 5.0,
		r_shoulder.lerp(r_elbow, 0.35) - ra_perp * 6.5,
		r_elbow - ra_perp * 4.5, r_elbow + ra_perp * 4.0,
		r_shoulder.lerp(r_elbow, 0.45) + ra_perp * 6.5,
	]), skin_shadow)
	draw_colored_polygon(PackedVector2Array([
		r_shoulder + ra_perp * 3.5, r_shoulder - ra_perp * 3.0,
		r_elbow - ra_perp * 2.5, r_elbow + ra_perp * 2.5,
	]), skin_base)
	# Bicep peak
	draw_circle(r_shoulder.lerp(r_elbow, 0.35) - ra_perp * 2.5, 3.5, skin_highlight)
	# Elbow
	draw_circle(r_elbow, 4.5, skin_shadow)
	draw_circle(r_elbow, 3.5, skin_base)
	# Forearm
	var rf_dir = (fist_target - r_elbow).normalized()
	var rf_perp = rf_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		r_elbow - rf_perp * 5.0, r_elbow + rf_perp * 4.5,
		fist_target + rf_perp * 3.5, fist_target - rf_perp * 3.5,
	]), skin_shadow)
	draw_colored_polygon(PackedVector2Array([
		r_elbow - rf_perp * 3.0, r_elbow + rf_perp * 2.5,
		fist_target + rf_perp * 2.0, fist_target - rf_perp * 2.0,
	]), skin_base)
	# Forearm muscle
	draw_circle(r_elbow.lerp(fist_target, 0.3) - rf_perp * 1.5, 3.0, skin_highlight)
	# FIST — large, clenched
	draw_circle(fist_target, 6.0, skin_shadow)
	draw_circle(fist_target, 4.5, skin_base)
	# Knuckles
	for ki in range(4):
		var ka = float(ki - 1.5) * 0.35
		var knuckle_pos = fist_target + rf_dir.rotated(ka) * 4.0
		draw_circle(knuckle_pos, 1.5, skin_highlight)
	# Knuckle line
	draw_arc(fist_target, 4.5, rf_dir.angle() - 0.8, rf_dir.angle() + 0.8, 8, Color(skin_shadow.r - 0.05, skin_shadow.g - 0.05, skin_shadow.b - 0.05, 0.3), 1.2)
	# Tier 2+ glowing fist effect
	if upgrade_tier >= 2:
		var gp = (sin(_time * 3.5) + 1.0) * 0.5
		draw_circle(fist_target, 8.0 + gp * 3.0, Color(0.9, 0.6, 0.15, 0.08 + gp * 0.04))
		draw_circle(fist_target, 5.0 + gp * 1.5, Color(1.0, 0.75, 0.25, 0.06))

	# === HEAD ===
	# Neck — thick, muscular
	var neck_top = head_center + Vector2(0, 9)
	var neck_dir = (neck_top - neck_base).normalized()
	var neck_perp = neck_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		neck_base + neck_perp * 7.0, neck_base - neck_perp * 7.0,
		neck_base.lerp(neck_top, 0.5) - neck_perp * 6.0,
		neck_top - neck_perp * 5.0, neck_top + neck_perp * 5.0,
		neck_base.lerp(neck_top, 0.5) + neck_perp * 6.0,
	]), skin_shadow)
	draw_colored_polygon(PackedVector2Array([
		neck_base + neck_perp * 5.5, neck_base - neck_perp * 5.5,
		neck_top - neck_perp * 4.0, neck_top + neck_perp * 4.0,
	]), skin_base)
	# Neck highlight
	draw_line(neck_base.lerp(neck_top, 0.15) + neck_perp * 3.5, neck_base.lerp(neck_top, 0.85) + neck_perp * 3.0, skin_highlight, 2.0)
	# Sternocleidomastoid muscles (very defined)
	draw_line(neck_base + neck_perp * 5.0, neck_top - neck_perp * 1.5, Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.2), 1.2)
	draw_line(neck_base - neck_perp * 5.0, neck_top + neck_perp * 1.5, Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.2), 1.2)
	# Trapezius connection
	draw_line(neck_base + neck_perp * 6.5, l_shoulder + Vector2(4, -3), Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.15), 1.5)
	draw_line(neck_base - neck_perp * 6.5, r_shoulder + Vector2(-4, -3), Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.15), 1.5)

	# Wild dark brown hair — back layer
	var hair_sway = sin(_time * 2.0) * 2.5
	var hair_base_col = Color(0.28, 0.16, 0.06)
	var hair_mid_col = Color(0.36, 0.22, 0.10)
	var hair_hi_col = Color(0.44, 0.28, 0.14)
	# Large hair mass
	draw_circle(head_center, 12.0, hair_base_col)
	draw_circle(head_center + Vector2(0, -1), 10.5, hair_mid_col)
	# Wild spiky strands radiating in all directions
	var tuft_data = [
		[0.0, 8.0, 2.5], [0.5, 7.5, 2.2], [1.0, 9.0, 2.0], [1.5, 7.0, 2.3],
		[2.0, 8.5, 2.1], [2.5, 7.5, 2.4], [3.0, 9.5, 2.0], [3.5, 7.0, 2.5],
		[4.0, 8.0, 2.2], [4.5, 7.5, 2.0], [5.0, 9.0, 2.3], [5.5, 8.0, 2.1],
		[6.0, 7.5, 2.4], [0.3, 6.5, 1.8], [2.8, 6.5, 1.9],
	]
	for h in range(tuft_data.size()):
		var ha: float = tuft_data[h][0]
		var tlen: float = tuft_data[h][1]
		var twid: float = tuft_data[h][2]
		var tuft_base_pos = head_center + Vector2.from_angle(ha) * 10.0
		var sway_d = 1.0 if h % 2 == 0 else -1.0
		# Wild wavy motion
		var s_wave = sin(ha * 2.5 + _time * 1.8) * 1.8
		var tuft_tip = tuft_base_pos + Vector2.from_angle(ha) * tlen + Vector2(hair_sway * sway_d * 0.5 + s_wave, s_wave * 0.4)
		var tcol = hair_mid_col if h % 3 == 0 else hair_hi_col if h % 3 == 1 else hair_base_col
		draw_line(tuft_base_pos, tuft_tip, tcol, twid)
		# Secondary wispy strand
		var ha2 = ha + (0.15 if h % 2 == 0 else -0.15)
		var t2_base = head_center + Vector2.from_angle(ha2) * 9.0
		var t2_tip = t2_base + Vector2.from_angle(ha2) * (tlen * 0.65) + Vector2(hair_sway * sway_d * 0.3 + s_wave * 0.5, 0)
		draw_line(t2_base, t2_tip, hair_base_col, twid * 0.5)
		# Extra wild wisp
		if h % 2 == 0:
			var ha3 = ha + 0.25
			var t3_base = head_center + Vector2.from_angle(ha3) * 9.5
			var t3_tip = t3_base + Vector2.from_angle(ha3) * (tlen * 0.4) + Vector2(hair_sway * 0.2, 0)
			draw_line(t3_base, t3_tip, Color(hair_hi_col.r, hair_hi_col.g, hair_hi_col.b, 0.5), twid * 0.4)
	# Hair falling over forehead
	for fri in range(4):
		var fr_x = -4.0 + float(fri) * 2.5
		var fr_base = head_center + Vector2(fr_x, -9.5)
		var fr_wave = sin(_time * 2.2 + float(fri) * 1.1) * 1.0
		var fr_tip = fr_base + Vector2(fr_wave, 7.0 + float(fri) * 0.5)
		draw_line(fr_base, fr_tip, hair_mid_col, 1.6 - float(fri) * 0.1)
		draw_line(fr_base, fr_base.lerp(fr_tip, 0.5), hair_hi_col, 0.8)

	# Face — strong, angular, tanned
	draw_circle(head_center + Vector2(0, 0.8), 9.5, skin_base)
	# Strong jawline
	draw_line(head_center + Vector2(-9.0, 1), head_center + Vector2(-5.5, 8.0), Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.35), 1.5)
	draw_line(head_center + Vector2(9.0, 1), head_center + Vector2(5.5, 8.0), Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.35), 1.5)
	# Squared chin
	draw_line(head_center + Vector2(-5.5, 8.0), head_center + Vector2(5.5, 8.0), Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.25), 1.2)
	draw_circle(head_center + Vector2(0, 8.0), 3.2, skin_base)
	draw_circle(head_center + Vector2(0, 8.2), 2.5, skin_highlight)
	# Chin cleft
	draw_line(head_center + Vector2(0, 7.2), head_center + Vector2(0, 8.5), Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.2), 0.8)
	# Cheekbone highlights
	draw_arc(head_center + Vector2(-5.5, 0.6), 3.8, PI * 1.15, PI * 1.6, 8, Color(skin_highlight.r, skin_highlight.g, skin_highlight.b, 0.25), 1.0)
	draw_arc(head_center + Vector2(5.5, 0.6), 3.8, PI * 1.4, PI * 1.85, 8, Color(skin_highlight.r, skin_highlight.g, skin_highlight.b, 0.25), 1.0)
	# Under-cheekbone shadow
	draw_arc(head_center + Vector2(-5.5, 2.0), 4.0, PI * 0.1, PI * 0.55, 8, Color(skin_shadow.r - 0.05, skin_shadow.g - 0.05, skin_shadow.b - 0.05, 0.2), 1.2)
	draw_arc(head_center + Vector2(5.5, 2.0), 4.0, PI * 0.45, PI * 0.9, 8, Color(skin_shadow.r - 0.05, skin_shadow.g - 0.05, skin_shadow.b - 0.05, 0.2), 1.2)
	# Weathered outdoor skin
	draw_arc(head_center, 7.5, PI * 0.7, PI * 1.3, 10, Color(0.72, 0.55, 0.40, 0.15), 2.0)

	# Ears
	var r_ear = head_center + Vector2(9.2, -0.8)
	draw_circle(r_ear, 2.6, skin_base)
	draw_circle(r_ear + Vector2(0.4, 0), 1.8, Color(skin_highlight.r, skin_highlight.g, skin_highlight.b, 0.5))
	draw_arc(r_ear, 2.2, -0.5, 1.0, 6, skin_shadow, 0.8)
	var l_ear = head_center + Vector2(-9.2, -0.8)
	draw_circle(l_ear, 2.6, skin_base)
	draw_circle(l_ear + Vector2(-0.4, 0), 1.8, Color(skin_highlight.r, skin_highlight.g, skin_highlight.b, 0.5))
	draw_arc(l_ear, 2.2, PI - 0.5, PI + 1.0, 6, skin_shadow, 0.8)

	# Intense GREEN EYES that track aim direction
	var look_dir = dir * 1.3
	var l_eye = head_center + Vector2(-4.0, -1.0)
	var r_eye = head_center + Vector2(4.0, -1.0)
	# Eye socket shadow (deep set, intense)
	draw_circle(l_eye, 4.5, Color(skin_shadow.r - 0.08, skin_shadow.g - 0.06, skin_shadow.b - 0.04, 0.3))
	draw_circle(r_eye, 4.5, Color(skin_shadow.r - 0.08, skin_shadow.g - 0.06, skin_shadow.b - 0.04, 0.3))
	# Eye whites
	draw_circle(l_eye, 4.0, Color(0.96, 0.96, 0.97))
	draw_circle(r_eye, 4.0, Color(0.96, 0.96, 0.97))
	# Green irises — intense jungle green
	draw_circle(l_eye + look_dir, 2.6, Color(0.08, 0.38, 0.10))
	draw_circle(l_eye + look_dir, 2.1, Color(0.12, 0.52, 0.16))
	draw_circle(l_eye + look_dir, 1.5, Color(0.18, 0.62, 0.22))
	draw_circle(r_eye + look_dir, 2.6, Color(0.08, 0.38, 0.10))
	draw_circle(r_eye + look_dir, 2.1, Color(0.12, 0.52, 0.16))
	draw_circle(r_eye + look_dir, 1.5, Color(0.18, 0.62, 0.22))
	# Limbal ring
	draw_arc(l_eye + look_dir, 2.5, 0, TAU, 10, Color(0.45, 0.42, 0.10, 0.25), 0.5)
	draw_arc(r_eye + look_dir, 2.5, 0, TAU, 10, Color(0.45, 0.42, 0.10, 0.25), 0.5)
	# Iris radial detail
	for iri in range(8):
		var ir_a = TAU * float(iri) / 8.0
		var ir_v = Vector2.from_angle(ir_a)
		draw_line(l_eye + look_dir + ir_v * 0.5, l_eye + look_dir + ir_v * 1.6, Color(0.10, 0.45, 0.14, 0.25), 0.4)
		draw_line(r_eye + look_dir + ir_v * 0.5, r_eye + look_dir + ir_v * 1.6, Color(0.10, 0.45, 0.14, 0.25), 0.4)
	# Inner iris ring
	draw_arc(l_eye + look_dir, 1.0, 0, TAU, 10, Color(0.25, 0.65, 0.30, 0.3), 0.4)
	draw_arc(r_eye + look_dir, 1.0, 0, TAU, 10, Color(0.25, 0.65, 0.30, 0.3), 0.4)
	# Pupils — intense, slightly slit-like (feral)
	draw_circle(l_eye + look_dir * 1.15, 1.3, Color(0.05, 0.05, 0.07))
	draw_circle(r_eye + look_dir * 1.15, 1.3, Color(0.05, 0.05, 0.07))
	# Primary highlight
	draw_circle(l_eye + Vector2(-1.0, -1.3), 1.3, Color(1.0, 1.0, 1.0, 0.92))
	draw_circle(r_eye + Vector2(-1.0, -1.3), 1.3, Color(1.0, 1.0, 1.0, 0.92))
	# Secondary highlight
	draw_circle(l_eye + Vector2(1.2, 0.5), 0.7, Color(1.0, 1.0, 1.0, 0.55))
	draw_circle(r_eye + Vector2(1.2, 0.5), 0.7, Color(1.0, 1.0, 1.0, 0.55))
	# Feral green glint
	var glint_t = sin(_time * 2.5) * 0.2
	draw_circle(l_eye + Vector2(0.4, -0.5), 0.5, Color(0.2, 0.8, 0.3, 0.25 + glint_t))
	draw_circle(r_eye + Vector2(0.4, -0.5), 0.5, Color(0.2, 0.8, 0.3, 0.25 + glint_t))
	# Upper eyelids — slightly narrowed, intense
	draw_arc(l_eye, 4.0, PI + 0.2, TAU - 0.2, 8, Color(hair_base_col.r, hair_base_col.g, hair_base_col.b, 0.8), 1.4)
	draw_arc(r_eye, 4.0, PI + 0.2, TAU - 0.2, 8, Color(hair_base_col.r, hair_base_col.g, hair_base_col.b, 0.8), 1.4)
	# Brow ridge shadow (deep set ape-man)
	draw_line(l_eye + Vector2(-4.0, -3.0), l_eye + Vector2(4.0, -3.0), Color(skin_shadow.r - 0.05, skin_shadow.g - 0.05, skin_shadow.b - 0.05, 0.2), 1.5)
	draw_line(r_eye + Vector2(-4.0, -3.0), r_eye + Vector2(4.0, -3.0), Color(skin_shadow.r - 0.05, skin_shadow.g - 0.05, skin_shadow.b - 0.05, 0.2), 1.5)
	# Lower eyelid
	draw_arc(l_eye, 3.7, 0.3, PI - 0.3, 8, Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.25), 0.5)
	draw_arc(r_eye, 3.7, 0.3, PI - 0.3, 8, Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.25), 0.5)

	# Eyebrows — thick, primal, intense
	draw_line(l_eye + Vector2(-3.5, -4.5), l_eye + Vector2(0.5, -5.2), Color(hair_base_col.r, hair_base_col.g, hair_base_col.b, 0.9), 2.2)
	draw_line(l_eye + Vector2(0.5, -5.2), l_eye + Vector2(3.5, -4.2), Color(hair_base_col.r, hair_base_col.g, hair_base_col.b, 0.7), 1.6)
	draw_line(r_eye + Vector2(-3.5, -4.2), r_eye + Vector2(-0.5, -5.2), Color(hair_base_col.r, hair_base_col.g, hair_base_col.b, 0.9), 2.2)
	draw_line(r_eye + Vector2(-0.5, -5.2), r_eye + Vector2(3.5, -4.5), Color(hair_base_col.r, hair_base_col.g, hair_base_col.b, 0.7), 1.6)
	# Brow hair texture
	for bhi in range(4):
		var bht = float(bhi) / 3.0
		var bh_l = (l_eye + Vector2(-3.0, -4.5)).lerp(l_eye + Vector2(3.0, -4.5), bht)
		draw_line(bh_l, bh_l + Vector2(0.3, -0.8), Color(hair_mid_col.r, hair_mid_col.g, hair_mid_col.b, 0.4), 0.6)
		var bh_r = (r_eye + Vector2(-3.0, -4.5)).lerp(r_eye + Vector2(3.0, -4.5), bht)
		draw_line(bh_r, bh_r + Vector2(-0.3, -0.8), Color(hair_mid_col.r, hair_mid_col.g, hair_mid_col.b, 0.4), 0.6)

	# Nose — strong, slightly broad
	draw_circle(head_center + Vector2(0, 3.0), 1.8, skin_highlight)
	draw_circle(head_center + Vector2(0.2, 3.2), 1.3, skin_base)
	# Nose bridge
	draw_line(head_center + Vector2(0, 0), head_center + Vector2(0, 2.6), Color(skin_highlight.r, skin_highlight.g, skin_highlight.b, 0.3), 0.8)
	# Nostrils — slightly flared
	draw_circle(head_center + Vector2(-1.2, 3.5), 0.6, Color(skin_shadow.r - 0.1, skin_shadow.g - 0.1, skin_shadow.b - 0.1, 0.4))
	draw_circle(head_center + Vector2(1.2, 3.5), 0.6, Color(skin_shadow.r - 0.1, skin_shadow.g - 0.1, skin_shadow.b - 0.1, 0.4))

	# Weathered cheeks
	draw_circle(head_center + Vector2(-5.8, 2.5), 2.8, Color(0.82, 0.50, 0.38, 0.12))
	draw_circle(head_center + Vector2(5.8, 2.5), 2.8, Color(0.82, 0.50, 0.38, 0.12))

	# Mouth — determined set jaw, slightly open showing teeth
	draw_arc(head_center + Vector2(0, 5.6), 4.2, 0.2, PI - 0.2, 12, Color(0.52, 0.28, 0.18), 1.6)
	# Teeth (gritted)
	for thi in range(4):
		var tooth_x = -2.0 + float(thi) * 1.3
		draw_circle(head_center + Vector2(tooth_x, 5.8), 0.7, Color(0.96, 0.94, 0.90))
	# Lower lip
	draw_arc(head_center + Vector2(0, 6.0), 3.0, 0.3, PI - 0.4, 8, Color(skin_shadow.r + 0.05, skin_shadow.g - 0.05, skin_shadow.b - 0.08, 0.2), 0.8)

	# Scars — battle scars across face/chest (jungle warrior)
	# Scar across left cheek
	draw_line(head_center + Vector2(-7.0, 0.5), head_center + Vector2(-3.5, 3.5), Color(0.75, 0.55, 0.45, 0.3), 0.8)
	# Small scar on chin
	draw_line(head_center + Vector2(1.5, 7.0), head_center + Vector2(3.0, 8.5), Color(0.75, 0.55, 0.45, 0.2), 0.7)

	# === Tier 4: Jungle aura around whole character ===
	if upgrade_tier >= 4:
		var aura_pulse = sin(_time * 2.0) * 5.0
		draw_circle(body_offset, 60.0 + aura_pulse, Color(0.2, 0.6, 0.1, 0.04))
		draw_circle(body_offset, 50.0 + aura_pulse * 0.6, Color(0.3, 0.7, 0.15, 0.06))
		draw_circle(body_offset, 42.0 + aura_pulse * 0.3, Color(0.85, 0.72, 0.25, 0.05))
		draw_arc(body_offset, 56.0 + aura_pulse, 0, TAU, 32, Color(0.2, 0.65, 0.1, 0.15), 2.5)
		draw_arc(body_offset, 46.0 + aura_pulse * 0.5, 0, TAU, 24, Color(0.85, 0.72, 0.25, 0.08), 1.8)
		# Orbiting leaf sparkles
		for gs in range(8):
			var gs_a = _time * (0.5 + float(gs % 4) * 0.2) + float(gs) * TAU / 8.0
			var gs_r = 46.0 + aura_pulse + float(gs % 3) * 3.5
			var gs_p = body_offset + Vector2.from_angle(gs_a) * gs_r
			var gs_size = 1.5 + sin(_time * 2.5 + float(gs) * 1.5) * 0.6
			var gs_alpha = 0.3 + sin(_time * 2.5 + float(gs)) * 0.15
			draw_circle(gs_p, gs_size, Color(0.25, 0.7, 0.2, gs_alpha))

	# === AWAITING ABILITY CHOICE INDICATOR ===
	if awaiting_ability_choice:
		var pulse = (sin(_time * 4.0) + 1.0) * 0.5
		draw_circle(Vector2.ZERO, 68.0 + pulse * 6.0, Color(0.2, 0.6, 0.1, 0.1 + pulse * 0.1))
		draw_arc(Vector2.ZERO, 68.0 + pulse * 6.0, 0, TAU, 32, Color(0.2, 0.6, 0.1, 0.3 + pulse * 0.3), 2.5)
		var font3 = ThemeDB.fallback_font
		draw_string(font3, Vector2(-16, -80), "!", HORIZONTAL_ALIGNMENT_CENTER, 32, 30, Color(0.2, 0.6, 0.1, 0.7 + pulse * 0.3))

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
		draw_string(font2, Vector2(-80, -72), _upgrade_name, HORIZONTAL_ALIGNMENT_CENTER, 160, 16, Color(0.2, 0.6, 0.1, min(_upgrade_flash, 1.0)))

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
	var base = 1.0 + _synergy_buffs.get("range", 0.0)
	# Prog ability 6: Predator Sense — +25% range
	if prog_abilities[5]:
		base *= 1.25
	return base

func _speed_mult() -> float:
	var base = 1.0 + _synergy_buffs.get("attack_speed", 0.0)
	# Prog ability 1: Jungle Instinct — +10% attack speed
	if prog_abilities[0]:
		base *= 1.1
	return base

func _gold_mult() -> float:
	return 1.0 + _synergy_buffs.get("gold_bonus", 0.0)
