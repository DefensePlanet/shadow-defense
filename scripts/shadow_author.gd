extends Node2D
## Shadow Author — Premium late-game tower unlocked by completing levels 34-36.
## Ink-based attacks with shadow/rewrite abilities.
## Tier 1 (5000 DMG): Ink Cloud — AoE slow + DoT in area
## Tier 2 (10000 DMG): Rewrite — teleports target enemy backward on path
## Tier 3 (15000 DMG): Shadow Servants — summons 2 shadow minions
## Tier 4 (20000 DMG): The Final Word — periodic massive AoE burst

# Base stats
var damage: float = 35.0
var fire_rate: float = 0.9
var attack_range: float = 170.0
var fire_cooldown: float = 0.0
var aim_angle: float = 0.0
var target: Node2D = null
var gold_bonus: int = 3

# Animation timers
var _time: float = 0.0
var _attack_anim: float = 0.0
var _quill_flash: float = 0.0

# Damage tracking and upgrades
var damage_dealt: float = 0.0
var upgrade_tier: int = 0
var _upgrade_flash: float = 0.0
var _upgrade_name: String = ""

# Ink Cloud ability (Tier 1)
var _ink_cloud_timer: float = 8.0
var _ink_cloud_cooldown: float = 8.0
var _ink_cloud_active: bool = false
var _ink_cloud_pos: Vector2 = Vector2.ZERO
var _ink_cloud_life: float = 0.0

# Rewrite ability (Tier 2)
var _rewrite_timer: float = 12.0
var _rewrite_cooldown: float = 12.0
var _rewrite_flash: float = 0.0

# Shadow Servants (Tier 3)
var _servant_timer: float = 20.0
var _servant_cooldown: float = 20.0
var _servants: Array = []  # {pos, target, life, angle}

# The Final Word (Tier 4)
var _final_word_timer: float = 30.0
var _final_word_cooldown: float = 30.0
var _final_word_flash: float = 0.0

# Progressive abilities (9 tiers, unlocked via lifetime damage)
const PROG_ABILITY_NAMES = [
	"Dark Quill", "Ink Resistance", "Corrupting Touch", "Page Tear",
	"Mind Control", "Shadow Step", "Ink Storm",
	"Shadow Clones", "Rewrite Reality"
]
const PROG_ABILITY_DESCS = [
	"Attack damage +15%",
	"Every 10s, absorb 1 hit (shield)",
	"Attacks apply 3s DoT",
	"AoE on every 5th attack",
	"5% chance to charm enemy for 3s",
	"Teleport to random valid spot every 45s",
	"Periodic rain of damage in range every 15s",
	"Attack speed doubled for 5s every 20s",
	"Every 60s: random effect (mass slow, damage, gold, or execute)"
]
var prog_abilities: Array = [false, false, false, false, false, false, false, false, false]

# Ability timers
var _shield_timer: float = 10.0
var _shield_active: bool = false
var _attack_count: int = 0
var _shadow_step_timer: float = 45.0
var _ink_storm_timer: float = 15.0
var _ink_storm_flash: float = 0.0
var _clone_timer: float = 20.0
var _clone_active: bool = false
var _clone_duration: float = 0.0
var _rewrite_reality_timer: float = 60.0
var _rewrite_reality_flash: float = 0.0

const STAT_UPGRADE_INTERVAL: float = 500.0
const ABILITY_THRESHOLD: float = 1500.0
var stat_upgrade_level: int = 0
var ability_chosen: bool = false
var awaiting_ability_choice: bool = false
const TIER_NAMES = [
	"Ink Cloud",
	"Rewrite",
	"Shadow Servants",
	"The Final Word"
]
const ABILITY_DESCRIPTIONS = [
	"AoE slow + DoT cloud in area",
	"Teleport target backward on path",
	"Summon 2 shadow minions that attack",
	"Massive AoE burst every 30s"
]
const TIER_COSTS = [120, 250, 400, 600]
var is_selected: bool = false
var base_cost: int = 0

# Attack sounds — dark ethereal whoosh with ink splatter
var _attack_sounds: Array = []
var _attack_sounds_by_tier: Array = []
var _attack_player: AudioStreamPlayer

# Ability sounds
var _ability_sound: AudioStreamWAV
var _ability_player: AudioStreamPlayer
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

	# Ability sound — deep rumbling shadow pulse
	var ab_rate := 44100
	var ab_dur := 0.6
	var ab_samples := PackedFloat32Array()
	ab_samples.resize(int(ab_rate * ab_dur))
	for i in ab_samples.size():
		var t := float(i) / ab_rate
		var rumble := sin(TAU * 60.0 * t) * 0.3 * exp(-t * 4.0)
		var shadow := sin(TAU * 120.0 * t + sin(TAU * 15.0 * t) * 3.0) * 0.2 * exp(-t * 5.0)
		var whisper := (randf() * 2.0 - 1.0) * 0.1 * exp(-t * 8.0)
		var sub := sin(TAU * 35.0 * t) * 0.2 * exp(-t * 3.0)
		ab_samples[i] = clampf(rumble + shadow + whisper + sub, -1.0, 1.0)
	_ability_sound = _samples_to_wav(ab_samples, ab_rate)
	_ability_player = AudioStreamPlayer.new()
	_ability_player.stream = _ability_sound
	_ability_player.volume_db = -5.0
	add_child(_ability_player)

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
	fire_cooldown -= delta
	_upgrade_flash = max(_upgrade_flash - delta * 0.5, 0.0)
	_attack_anim = max(_attack_anim - delta * 3.0, 0.0)
	_quill_flash = max(_quill_flash - delta * 4.0, 0.0)
	_final_word_flash = max(_final_word_flash - delta * 2.0, 0.0)
	_rewrite_flash = max(_rewrite_flash - delta * 3.0, 0.0)
	_ink_storm_flash = max(_ink_storm_flash - delta * 2.0, 0.0)
	_rewrite_reality_flash = max(_rewrite_reality_flash - delta * 2.0, 0.0)
	target = _find_nearest_enemy()

	if target:
		var desired = global_position.angle_to_point(target.global_position) + PI
		aim_angle = lerp_angle(aim_angle, desired, 6.0 * delta)
		if fire_cooldown <= 0.0:
			_attack()
			var speed_mult_val = _speed_mult()
			if _clone_active:
				speed_mult_val *= 2.0
			fire_cooldown = 1.0 / (fire_rate * speed_mult_val)
			_attack_anim = 1.0
			_quill_flash = 1.0

	# Ink Cloud (Tier 1+)
	if upgrade_tier >= 1:
		if _ink_cloud_active:
			_ink_cloud_life -= delta
			if _ink_cloud_life <= 0.0:
				_ink_cloud_active = false
			else:
				_ink_cloud_damage(delta)
		else:
			_ink_cloud_timer -= delta
			if _ink_cloud_timer <= 0.0 and _has_enemies_in_range():
				_deploy_ink_cloud()
				_ink_cloud_timer = _ink_cloud_cooldown

	# Rewrite (Tier 2+)
	if upgrade_tier >= 2:
		_rewrite_timer -= delta
		if _rewrite_timer <= 0.0 and target:
			_rewrite_enemy(target)
			_rewrite_timer = _rewrite_cooldown

	# Shadow Servants (Tier 3+)
	if upgrade_tier >= 3:
		_servant_timer -= delta
		if _servant_timer <= 0.0 and _has_enemies_in_range():
			_summon_servants()
			_servant_timer = _servant_cooldown
		_update_servants(delta)

	# The Final Word (Tier 4)
	if upgrade_tier >= 4:
		_final_word_timer -= delta
		if _final_word_timer <= 0.0 and _has_enemies_in_range():
			_the_final_word()
			_final_word_timer = _final_word_cooldown

	# Progressive abilities
	# Shield (ability 1)
	if prog_abilities[1]:
		_shield_timer -= delta
		if _shield_timer <= 0.0:
			_shield_active = true
			_shield_timer = 10.0

	# Shadow Step (ability 5)
	if prog_abilities[5]:
		_shadow_step_timer -= delta
		if _shadow_step_timer <= 0.0:
			_shadow_step()
			_shadow_step_timer = 45.0

	# Ink Storm (ability 6)
	if prog_abilities[6]:
		_ink_storm_timer -= delta
		if _ink_storm_timer <= 0.0 and _has_enemies_in_range():
			_ink_storm()
			_ink_storm_timer = 15.0

	# Shadow Clones (ability 7)
	if prog_abilities[7]:
		_clone_timer -= delta
		if _clone_active:
			_clone_duration -= delta
			if _clone_duration <= 0.0:
				_clone_active = false
		elif _clone_timer <= 0.0:
			_clone_active = true
			_clone_duration = 5.0
			_clone_timer = 20.0

	# Rewrite Reality (ability 8)
	if prog_abilities[8]:
		_rewrite_reality_timer -= delta
		if _rewrite_reality_timer <= 0.0 and _has_enemies_in_range():
			_rewrite_reality()
			_rewrite_reality_timer = 60.0

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

func _attack() -> void:
	if not target:
		return
	if _attack_player and _attack_sounds.size() > 0 and not _is_sfx_muted():
		_attack_player.stream = _attack_sounds[_get_note_index() % _attack_sounds.size()]
		_attack_player.play()

	var eff_damage = damage * _damage_mult()
	_attack_count += 1

	# Apply damage to target
	if target.has_method("take_damage"):
		target.take_damage(eff_damage, true)  # is_magic = true (ink attack)
		register_damage(eff_damage)

	# Ability 2: Corrupting Touch — 3s DoT
	if prog_abilities[2] and target.has_method("take_damage"):
		target.dot_dps = max(target.dot_dps, eff_damage * 0.2)
		target.dot_timer = max(target.dot_timer, 3.0)

	# Ability 3: Page Tear — AoE every 5th attack
	if prog_abilities[3] and _attack_count % 5 == 0:
		var aoe_range = 60.0
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy != target and global_position.distance_to(enemy.global_position) < aoe_range + attack_range * _range_mult():
				if enemy.has_method("take_damage"):
					var aoe_dmg = eff_damage * 0.5
					enemy.take_damage(aoe_dmg, true)
					register_damage(aoe_dmg)

	# Ability 4: Mind Control — 5% charm
	if prog_abilities[4] and randf() < 0.05:
		target.charm_timer = 3.0
		target.charm_damage_mult = 1.5

	# Gold bonus
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("add_gold"):
		var gb = int(gold_bonus * _gold_mult())
		if gb > 0 and randf() < 0.15:
			main.add_gold(gb)

func _deploy_ink_cloud() -> void:
	if not target:
		return
	_ink_cloud_active = true
	_ink_cloud_pos = target.global_position
	_ink_cloud_life = 4.0
	if not _is_sfx_muted():
		_ability_player.play()

func _ink_cloud_damage(delta: float) -> void:
	var cloud_range = 80.0
	var cloud_dmg = damage * 0.3 * _damage_mult() * delta
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if _ink_cloud_pos.distance_to(enemy.global_position) < cloud_range:
			if enemy.has_method("take_damage"):
				enemy.take_damage(cloud_dmg, true)
				register_damage(cloud_dmg)
			# Slow enemies in cloud
			enemy.slow_factor = 0.5
			enemy.slow_timer = max(enemy.slow_timer, 0.5)

func _rewrite_enemy(enemy: Node2D) -> void:
	# Teleport enemy backward on path
	if enemy and is_instance_valid(enemy) and "progress" in enemy:
		var rewrite_amount = enemy.progress * 0.3  # Send back 30%
		enemy.progress -= rewrite_amount
		enemy.progress = max(0.0, enemy.progress)
		_rewrite_flash = 1.0
		if not _is_sfx_muted():
			_ability_player.play()

func _summon_servants() -> void:
	_servants.clear()
	for i in range(2):
		var angle = randf() * TAU
		_servants.append({
			"pos": global_position + Vector2(cos(angle), sin(angle)) * 40.0,
			"life": 8.0,
			"angle": angle,
			"attack_timer": 0.0,
		})
	if not _is_sfx_muted():
		_ability_player.play()

func _update_servants(delta: float) -> void:
	var to_remove: Array = []
	for i in range(_servants.size()):
		var s = _servants[i]
		s["life"] -= delta
		if s["life"] <= 0.0:
			to_remove.append(i)
			continue
		# Find and attack nearest enemy
		s["attack_timer"] -= delta
		if s["attack_timer"] <= 0.0:
			var nearest: Node2D = null
			var nearest_dist: float = 120.0
			for enemy in get_tree().get_nodes_in_group("enemies"):
				var dist = Vector2(s["pos"]).distance_to(enemy.global_position)
				if dist < nearest_dist:
					nearest = enemy
					nearest_dist = dist
			if nearest and nearest.has_method("take_damage"):
				var servant_dmg = damage * 0.4 * _damage_mult()
				nearest.take_damage(servant_dmg, true)
				register_damage(servant_dmg)
				s["angle"] = Vector2(s["pos"]).angle_to_point(nearest.global_position) + PI
			s["attack_timer"] = 1.2
		# Orbit around tower
		s["angle"] += delta * 1.5
		s["pos"] = global_position + Vector2(cos(s["angle"]), sin(s["angle"])) * 45.0
	# Remove dead servants (reverse order)
	for i in range(to_remove.size() - 1, -1, -1):
		_servants.remove_at(to_remove[i])

func _the_final_word() -> void:
	_final_word_flash = 1.0
	var burst_dmg = damage * 8.0 * _damage_mult()
	var eff_range = attack_range * _range_mult() * 1.5
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(enemy.global_position) < eff_range:
			if enemy.has_method("take_damage"):
				enemy.take_damage(burst_dmg, true)
				register_damage(burst_dmg)
	if not _is_sfx_muted():
		_ability_player.play()

func _shadow_step() -> void:
	# Teleport to random valid position
	var main = get_tree().get_first_node_in_group("main")
	if not main:
		return
	for _attempt in range(10):
		var new_pos = Vector2(randf_range(60, 1220), randf_range(60, 600))
		if main.has_method("_is_valid_placement") and main._is_valid_placement(new_pos):
			position = new_pos
			break

func _ink_storm() -> void:
	_ink_storm_flash = 1.0
	var storm_dmg = damage * 1.5 * _damage_mult()
	var eff_range = attack_range * _range_mult()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(enemy.global_position) < eff_range:
			if enemy.has_method("take_damage"):
				enemy.take_damage(storm_dmg, true)
				register_damage(storm_dmg)
	if not _is_sfx_muted():
		_ability_player.play()

func _rewrite_reality() -> void:
	_rewrite_reality_flash = 1.0
	var effect = randi() % 4
	match effect:
		0:  # Mass slow
			for enemy in get_tree().get_nodes_in_group("enemies"):
				enemy.slow_factor = 0.3
				enemy.slow_timer = max(enemy.slow_timer, 5.0)
		1:  # Mass damage
			var burst_dmg = damage * 5.0 * _damage_mult()
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if enemy.has_method("take_damage"):
					enemy.take_damage(burst_dmg, true)
					register_damage(burst_dmg)
		2:  # Gold bonus
			var main = get_tree().get_first_node_in_group("main")
			if main and main.has_method("add_gold"):
				main.add_gold(50)
		3:  # Execute low HP enemies
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if enemy.health / enemy.max_health < 0.2:
					if enemy.has_method("take_damage"):
						enemy.take_damage(enemy.health + 1.0, true)
	if not _is_sfx_muted():
		_ability_player.play()

func register_kill() -> void:
	_upgrade_flash = 0.5
	_upgrade_name = "Kill!"

func register_damage(amount: float) -> void:
	damage_dealt += amount
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("report_tower_damage"):
		main.report_tower_damage(self, amount)
	# Stat upgrades
	var new_level = int(damage_dealt / STAT_UPGRADE_INTERVAL)
	if new_level > stat_upgrade_level:
		stat_upgrade_level = new_level
		damage += 2.0
		fire_rate += 0.02
		attack_range += 1.5
	# Tier upgrades
	if upgrade_tier < 4:
		var thresholds = [5000.0, 10000.0, 15000.0, 20000.0]
		if damage_dealt >= thresholds[upgrade_tier]:
			upgrade_tier += 1
			_upgrade_flash = 1.0
			_upgrade_name = TIER_NAMES[upgrade_tier - 1]
			_attack_sounds = _attack_sounds_by_tier[mini(upgrade_tier, _attack_sounds_by_tier.size() - 1)]
			if not _is_sfx_muted():
				_upgrade_player.play()

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
	_attack_sounds_by_tier = []
	# 5 tiers of sounds (base + 4 upgrades)
	for tier in range(5):
		var sounds: Array = []
		for note_i in range(4):
			var rate := 22050
			var dur := 0.2 + tier * 0.05
			var samples := PackedFloat32Array()
			samples.resize(int(rate * dur))
			# Base frequency — dark ethereal whoosh
			var base_freq := 180.0 + note_i * 40.0 + tier * 30.0
			for i in samples.size():
				var t := float(i) / rate
				var env := minf(t * 80.0, 1.0) * exp(-t * (12.0 - tier * 1.5)) * 0.4
				# Dark whoosh
				var whoosh := sin(TAU * base_freq * t + sin(TAU * 8.0 * t) * 2.0) * env
				# Ink splatter noise
				var splat := (randf() * 2.0 - 1.0) * exp(-t * 25.0) * 0.15
				# Sub bass
				var sub := sin(TAU * 50.0 * t) * 0.1 * exp(-t * 8.0)
				samples[i] = clampf(whoosh + splat + sub, -1.0, 1.0)
			sounds.append(_samples_to_wav(samples, rate))
		_attack_sounds_by_tier.append(sounds)

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
	if main and main.survivor_progress.has(main.TowerType.SHADOW_AUTHOR):
		var p = main.survivor_progress[main.TowerType.SHADOW_AUTHOR]
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
	# Ability 0: Dark Quill — +15% damage (handled in _damage_mult)
	pass

# === SYNERGY BUFFS ===
var _synergy_buffs: Dictionary = {}
var _meta_buffs: Dictionary = {}

func set_synergy_buff(buffs: Dictionary) -> void:
	for key in buffs:
		_synergy_buffs[key] = _synergy_buffs.get(key, 0.0) + buffs[key]

func clear_synergy_buff() -> void:
	_synergy_buffs.clear()

func has_synergy_buff() -> bool:
	return not _synergy_buffs.is_empty()

func set_meta_buffs(buffs: Dictionary) -> void:
	_meta_buffs = buffs

var power_damage_mult: float = 1.0

func _damage_mult() -> float:
	var mult: float = (1.0 + _synergy_buffs.get("damage", 0.0) + _meta_buffs.get("damage", 0.0)) * power_damage_mult
	if prog_abilities[0]:
		mult *= 1.15
	return mult

func _range_mult() -> float:
	return 1.0 + _synergy_buffs.get("range", 0.0) + _meta_buffs.get("range", 0.0)

func _speed_mult() -> float:
	return 1.0 + _synergy_buffs.get("attack_speed", 0.0) + _meta_buffs.get("attack_speed", 0.0)

func _gold_mult() -> float:
	return 1.0 + _synergy_buffs.get("gold_bonus", 0.0) + _meta_buffs.get("gold_bonus", 0.0)

# === DRAW ===

func _draw() -> void:
	# === 1. SELECTION RING ===
	if is_selected:
		var pulse = (sin(_time * 3.0) + 1.0) * 0.5
		var ring_alpha = 0.5 + pulse * 0.3
		draw_arc(Vector2.ZERO, 40.0, 0, TAU, 48, Color(0.5, 0.2, 0.8, ring_alpha), 2.5)
		draw_arc(Vector2.ZERO, 43.0, 0, TAU, 48, Color(0.5, 0.2, 0.8, ring_alpha * 0.4), 1.5)

	# === 2. RANGE ARC ===
	draw_arc(Vector2.ZERO, attack_range, 0, TAU, 64, Color(1, 1, 1, 0.06), 1.0)

	# === 3. AIM DIRECTION ===
	var dir = Vector2.from_angle(aim_angle)

	# === 4. IDLE ANIMATION ===
	var float_bob = sin(_time * 1.5) * 3.0
	var sway = sin(_time * 0.9) * 2.5
	var breathe = sin(_time * 1.2) * 2.0
	var body_offset = Vector2(sway, -float_bob - breathe)

	# === 5. UPGRADE FLASH ===
	if _upgrade_flash > 0.0:
		draw_circle(Vector2.ZERO, 60.0 + _upgrade_flash * 20.0, Color(0.4, 0.15, 0.6, _upgrade_flash * 0.25))

	# === 6. FINAL WORD FLASH ===
	if _final_word_flash > 0.0:
		var flash_r = 60.0 + (1.0 - _final_word_flash) * 120.0
		draw_circle(Vector2.ZERO, flash_r, Color(0.2, 0.05, 0.3, _final_word_flash * 0.2))
		draw_arc(Vector2.ZERO, flash_r, 0, TAU, 32, Color(0.5, 0.2, 0.8, _final_word_flash * 0.4), 2.5)

	# === 7. INK STORM FLASH ===
	if _ink_storm_flash > 0.0:
		for i in range(8):
			var angle = TAU * float(i) / 8.0 + _time * 2.0
			var dist = 30.0 + (1.0 - _ink_storm_flash) * 60.0
			draw_circle(Vector2(cos(angle) * dist, sin(angle) * dist) + body_offset, 4.0, Color(0.1, 0.05, 0.15, _ink_storm_flash * 0.5))

	# === 8. REWRITE REALITY FLASH ===
	if _rewrite_reality_flash > 0.0:
		draw_circle(body_offset, 50.0, Color(0.6, 0.3, 0.9, _rewrite_reality_flash * 0.15))
		# Spinning runes
		for i in range(6):
			var angle = TAU * float(i) / 6.0 + _time * 3.0
			var rune_pos = body_offset + Vector2(cos(angle), sin(angle)) * 35.0
			draw_circle(rune_pos, 3.0, Color(0.8, 0.5, 1.0, _rewrite_reality_flash * 0.6))

	# === 9. DARK AURA BASE ===
	# Ground shadow
	draw_ellipse(body_offset + Vector2(0, 22), Vector2(18, 6), Color(0.05, 0.02, 0.1, 0.5))
	# Wispy tendrils at base
	for i in range(6):
		var ta = TAU * float(i) / 6.0 + _time * 1.2
		var td = 12.0 + sin(_time * 3.0 + float(i)) * 4.0
		var tx = cos(ta) * td
		var ty = 18.0 + sin(ta) * 5.0
		draw_circle(body_offset + Vector2(tx, ty), 2.5, Color(0.1, 0.03, 0.15, 0.35))

	# === 10. CLOAK/ROBE BODY ===
	var cloak_pts = PackedVector2Array()
	cloak_pts.append(body_offset + Vector2(-10, -28))  # Left shoulder
	cloak_pts.append(body_offset + Vector2(-13, -10))  # Left mid
	cloak_pts.append(body_offset + Vector2(-15, 8))    # Left lower
	cloak_pts.append(body_offset + Vector2(-12, 20 + sin(_time * 2.0) * 2.0))  # Left tendril
	cloak_pts.append(body_offset + Vector2(-5, 22 + sin(_time * 2.5 + 1.0) * 1.5))
	cloak_pts.append(body_offset + Vector2(0, 21 + sin(_time * 3.0) * 1.0))
	cloak_pts.append(body_offset + Vector2(5, 22 + sin(_time * 2.5 + 2.0) * 1.5))
	cloak_pts.append(body_offset + Vector2(12, 20 + sin(_time * 2.0 + 1.5) * 2.0))
	cloak_pts.append(body_offset + Vector2(15, 8))    # Right lower
	cloak_pts.append(body_offset + Vector2(13, -10))  # Right mid
	cloak_pts.append(body_offset + Vector2(10, -28))  # Right shoulder
	var cloak_color = Color(0.06, 0.02, 0.1, 0.9)
	if upgrade_tier >= 4:
		cloak_color = Color(0.08, 0.03, 0.14, 0.95)
	draw_colored_polygon(cloak_pts, cloak_color)
	# Cloak edge highlight
	for i in range(cloak_pts.size() - 1):
		draw_line(cloak_pts[i], cloak_pts[i + 1], Color(0.25, 0.1, 0.35, 0.4), 1.0)

	# === 11. HOOD ===
	var hood_pts = PackedVector2Array()
	hood_pts.append(body_offset + Vector2(-12, -27))
	hood_pts.append(body_offset + Vector2(0, -42))  # Hood peak
	hood_pts.append(body_offset + Vector2(12, -27))
	hood_pts.append(body_offset + Vector2(7, -22))
	hood_pts.append(body_offset + Vector2(-7, -22))
	draw_colored_polygon(hood_pts, Color(0.04, 0.01, 0.08, 0.95))
	draw_line(hood_pts[0], hood_pts[1], Color(0.3, 0.12, 0.4, 0.5), 1.0)
	draw_line(hood_pts[1], hood_pts[2], Color(0.3, 0.12, 0.4, 0.5), 1.0)

	# === 12. REVEALED FACE — pale white, hollow eyes, sharp-tooth grin ===
	# Hood inner void background
	draw_colored_polygon(PackedVector2Array([
		body_offset + Vector2(-7, -22), body_offset + Vector2(0, -38),
		body_offset + Vector2(7, -22)
	]), Color(0.01, 0.005, 0.015))
	# Pale face
	var fc = body_offset + Vector2(0, -28)
	draw_colored_polygon(PackedVector2Array([
		fc + Vector2(0, -8), fc + Vector2(-6, -4), fc + Vector2(-6, 4),
		fc + Vector2(-4, 7), fc + Vector2(4, 7), fc + Vector2(6, 4),
		fc + Vector2(6, -4)
	]), Color(0.88, 0.86, 0.84))
	# Hollow dark eye sockets
	draw_circle(fc + Vector2(-3, -2), 2.0, Color(0.06, 0.03, 0.05))
	draw_circle(fc + Vector2(3, -2), 2.0, Color(0.06, 0.03, 0.05))
	# Red pinprick pupils
	var pp = 0.5 + sin(_time * 3.0) * 0.2
	draw_circle(fc + Vector2(-3, -2), 0.7, Color(0.9, 0.15, 0.1, pp))
	draw_circle(fc + Vector2(3, -2), 0.7, Color(0.9, 0.15, 0.1, pp))
	# Massive sharp-tooth grin
	var grin_y = fc.y + 4
	draw_rect(Rect2(fc.x - 5, grin_y, 10, 3), Color(0.03, 0.01, 0.02))
	# Upper teeth
	for ti in range(5):
		var tx = fc.x - 4.5 + float(ti) * 2.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(tx, grin_y), Vector2(tx + 1.0, grin_y + 1.8), Vector2(tx + 2.0, grin_y)
		]), Color(0.92, 0.9, 0.85))
	# Lower teeth
	for ti in range(5):
		var tx = fc.x - 4.5 + float(ti) * 2.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(tx, grin_y + 3), Vector2(tx + 1.0, grin_y + 1.5), Vector2(tx + 2.0, grin_y + 3)
		]), Color(0.88, 0.86, 0.82))

	# === 13. QUILL (held in right hand) ===
	var hand_offset = body_offset + Vector2(12, -12)
	var quill_angle = aim_angle + sin(_time * 2.0) * 0.1
	if _attack_anim > 0.0:
		quill_angle += sin(_attack_anim * PI * 2.0) * 0.4
	var quill_tip = hand_offset + Vector2(cos(quill_angle), sin(quill_angle)) * 18.0
	var quill_end = hand_offset + Vector2(cos(quill_angle + PI), sin(quill_angle + PI)) * 8.0
	# Feather part
	draw_line(quill_end, hand_offset, Color(0.6, 0.55, 0.5, 0.8), 2.5)
	# Quill nib
	draw_line(hand_offset, quill_tip, Color(0.15, 0.1, 0.08, 0.9), 1.5)
	# Ink drip from tip
	if _quill_flash > 0.0:
		var drip_pos = quill_tip + Vector2(0, 2 + (1.0 - _quill_flash) * 8.0)
		draw_circle(drip_pos, 2.0 * _quill_flash, Color(0.08, 0.02, 0.12, _quill_flash * 0.7))
	# Glow on quill when upgraded
	if upgrade_tier >= 2:
		var glow_pulse = (sin(_time * 3.0) + 1.0) * 0.5
		draw_circle(quill_tip, 4.0, Color(0.5, 0.2, 0.8, 0.1 + glow_pulse * 0.08))

	# === 14. LEFT HAND (skeletal pale) ===
	var lh = body_offset + Vector2(-12 + sin(_time * 1.8) * 2.0, -12)
	draw_circle(lh, 2.0, Color(0.75, 0.7, 0.6, 0.7))
	for f in range(3):
		var fa = -0.6 + float(f) * 0.3
		draw_line(lh, lh + Vector2(cos(fa) * 5.0, sin(fa) * 5.0), Color(0.7, 0.65, 0.55, 0.6), 0.8)

	# === 15. INK CLOUD VISUAL ===
	if _ink_cloud_active and _ink_cloud_life > 0.0:
		var cloud_alpha = clampf(_ink_cloud_life / 4.0, 0.0, 1.0) * 0.4
		var cloud_local = _ink_cloud_pos - global_position
		for i in range(8):
			var ca = TAU * float(i) / 8.0 + _time * 1.5
			var cd = 25.0 + sin(_time * 2.0 + float(i)) * 15.0
			draw_circle(cloud_local + Vector2(cos(ca) * cd, sin(ca) * cd * 0.7), 12.0 + sin(_time * 3.0 + float(i)) * 4.0, Color(0.08, 0.03, 0.12, cloud_alpha))
		# Cloud center
		draw_circle(cloud_local, 20.0, Color(0.06, 0.02, 0.1, cloud_alpha * 0.6))

	# === 16. SHADOW SERVANTS ===
	for s in _servants:
		var sp = Vector2(s["pos"]) - global_position
		var servant_alpha = clampf(s["life"] / 2.0, 0.0, 1.0)
		# Small hooded figure
		draw_circle(sp + Vector2(0, 2), 5.0, Color(0.05, 0.02, 0.08, servant_alpha * 0.7))
		# Hood
		var sh_pts = PackedVector2Array()
		sh_pts.append(sp + Vector2(-4, -2))
		sh_pts.append(sp + Vector2(0, -10))
		sh_pts.append(sp + Vector2(4, -2))
		draw_colored_polygon(sh_pts, Color(0.04, 0.01, 0.06, servant_alpha * 0.8))
		# Eyes
		draw_circle(sp + Vector2(-1.5, -4), 0.8, Color(0.8, 0.2, 0.4, servant_alpha))
		draw_circle(sp + Vector2(1.5, -4), 0.8, Color(0.8, 0.2, 0.4, servant_alpha))

	# === 17. REWRITE FLASH ===
	if _rewrite_flash > 0.0:
		draw_circle(body_offset, 25.0, Color(0.4, 0.2, 0.7, _rewrite_flash * 0.2))
		# Swirling pages
		for i in range(4):
			var pa = TAU * float(i) / 4.0 + _time * 5.0
			var pd = 15.0 + (1.0 - _rewrite_flash) * 20.0
			var pp = body_offset + Vector2(cos(pa) * pd, sin(pa) * pd * 0.5)
			draw_rect(Rect2(pp.x - 3, pp.y - 2, 6, 4), Color(0.9, 0.85, 0.7, _rewrite_flash * 0.6))

	# === 18. SHIELD INDICATOR ===
	if _shield_active:
		var shield_pulse = (sin(_time * 5.0) + 1.0) * 0.5
		draw_arc(body_offset, 20.0 + shield_pulse * 3.0, 0, TAU, 24, Color(0.4, 0.2, 0.7, 0.3 + shield_pulse * 0.2), 2.0)

	# === 19. CLONE INDICATOR ===
	if _clone_active:
		# Ghost duplicates
		var ghost_offset1 = body_offset + Vector2(-8, 0)
		var ghost_offset2 = body_offset + Vector2(8, 0)
		draw_circle(ghost_offset1, 8.0, Color(0.15, 0.05, 0.2, 0.2))
		draw_circle(ghost_offset2, 8.0, Color(0.15, 0.05, 0.2, 0.2))

	# === 20. UPGRADE NAME ===
	if _upgrade_flash > 0.0 and _upgrade_name != "":
		var font = ThemeDB.fallback_font
		draw_string(font, body_offset + Vector2(-30, -50), _upgrade_name, HORIZONTAL_ALIGNMENT_CENTER, 60, 10, Color(0.8, 0.6, 1.0, _upgrade_flash))

	# === 21. TIER INDICATOR ===
	if upgrade_tier > 0:
		for i in range(upgrade_tier):
			var dot_x = -6.0 + float(i) * 4.0
			draw_circle(body_offset + Vector2(dot_x, 26), 1.5, Color(0.6, 0.3, 0.9, 0.7))

func draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var pts = PackedVector2Array()
	for i in range(24):
		var angle = TAU * float(i) / 24.0
		pts.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(pts, color)
