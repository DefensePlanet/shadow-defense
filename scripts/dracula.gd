extends Node2D
## Dracula — vampire lord tower. Drains life from enemies, summons bats, turns foes to minions.
## Tier 1: Vampiric Touch — every 5th kill, dash and bite for major damage
## Tier 2: Bat Swarm — each wave, transform into bats, devour 3-5 enemies
## Tier 3: Thrall — every 15th kill, drain life to restore 1 lost player life
## Tier 4: Lord of Darkness — glow red, dash and feast on enemies at will

# Base stats
var damage: float = 25.0
var fire_rate: float = 0.91
var attack_range: float = 190.0
var fire_cooldown: float = 0.0
var aim_angle: float = 0.0
var target: Node2D = null
var _cast_anim: float = 0.0
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

# Tier 1: Vampiric Touch — bite every 5 kills
var life_drain_percent: float = 0.05  # kept for bolt compatibility
var _home_position: Vector2 = Vector2.ZERO
var _bite_target: Node2D = null
var _bite_dash_timer: float = 0.0
var _bite_returning: bool = false
var _bite_flash: float = 0.0

# Tier 2: Bat Swarm — devour enemies each wave
var _bat_devour_active: bool = false
var _bat_devour_timer: float = 0.0
var _bat_devour_targets: Array = []
var _bat_devour_phase: float = 0.0
var _bat_devour_flash: float = 0.0

# Tier 3: Thrall — restore life every 15 kills
var _thrall_kill_counter: int = 0
var _thrall_flash: float = 0.0
var _active_thralls: Array = []  # kept for visual indicator

# Tier 4: Lord of Darkness — constant feast
var _lord_active: bool = false
var _lord_glow: float = 0.0
var _lord_feast_timer: float = 0.0
var _lord_feast_cooldown: float = 1.5
var _lord_feast_target: Node2D = null
var _lord_feast_dash_timer: float = 0.0
var _lord_feast_returning: bool = false

# Kill tracking
var kill_count: int = 0

# === PROGRESSIVE ABILITIES (9 tiers, unlocked via lifetime damage) ===
const PROG_ABILITY_NAMES = [
	"Undead Fortitude", "Mist Form", "Wolf Companion", "Hypnotic Gaze",
	"Blood Moon", "Castle Defense", "Bride's Kiss", "Nosferatu Form",
	"Prince of Darkness"
]
const PROG_ABILITY_DESCS = [
	"Tower takes 30% less damage, +15% damage, nearby towers take 15% less damage",
	"Every 12s, become mist for 2s; bolts during deal 2x",
	"Every 18s, spectral wolf strikes weakest enemy for 4x",
	"Every 15s, confuse nearest enemy (walks backward) for 2s",
	"Every 25s, blood moon boosts all towers +20% damage for 15s",
	"Every 20s, bat sentinels block 2 enemies for 2s",
	"Every 22s, heal 1 life + drain strongest enemy for 6x",
	"Every 16s, transform — all attacks deal 3x for 4s",
	"Every 10s, dark wave hits enemies in 3x range for 2x"
]
var prog_abilities: Array = [false, false, false, false, false, false, false, false, false]
# Ability timers
var _mist_form_timer: float = 12.0
var _mist_form_active: float = 0.0
var _wolf_timer: float = 18.0
var _hypnotic_timer: float = 15.0
var _blood_moon_timer: float = 25.0
var _blood_moon_active: float = 0.0
var _blood_moon_buff_applied: bool = false
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
var _brides_kiss_flash: float = 0.0
var _hypnotic_flash: float = 0.0

const STAT_UPGRADE_INTERVAL: float = 8000.0
const ABILITY_THRESHOLD: float = 28000.0
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
	"Every 5th kill — dash and bite for major damage",
	"Each wave — transform into bats, devour 3-5 enemies",
	"Every 15th kill — drain life to restore 1 lost life",
	"Glow red — dash and feast on enemies at will"
]
const TIER_COSTS = [150, 350, 650, 1200]
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
var _brides_kiss_sound: AudioStreamWAV
var _brides_kiss_player: AudioStreamPlayer
var _hypnotic_gaze_sound: AudioStreamWAV
var _hypnotic_gaze_player: AudioStreamPlayer
var _game_font: Font
var _main_node: Node2D = null

func _ready() -> void:
	_main_node = get_tree().get_first_node_in_group("main")
	_game_font = load("res://fonts/Cinzel.ttf")
	add_to_group("towers")
	_home_position = global_position
	_load_progressive_abilities()
	_generate_tier_sounds()
	_attack_sounds = _attack_sounds_by_tier[0]
	_attack_player = AudioStreamPlayer.new()
	_attack_player.stream = _attack_sounds[0]
	_attack_player.volume_db = -14.0
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
	_bat_screech_player.volume_db = -14.0
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
	_upgrade_player.volume_db = -10.0
	add_child(_upgrade_player)

	# Bride's Kiss — breathy charm/kiss sound with shimmering harmonic
	var kiss_rate := 22050
	var kiss_dur := 0.6
	var kiss_samples := PackedFloat32Array()
	kiss_samples.resize(int(kiss_rate * kiss_dur))
	for i in kiss_samples.size():
		var t := float(i) / kiss_rate
		var s := 0.0
		# Breathy "mwah" onset — noise burst shaped by vowel formant
		var breath_env := exp(-t * 8.0) * 0.25
		var onset := clampf(t * 80.0, 0.0, 1.0)
		s += (randf() * 2.0 - 1.0) * breath_env * onset
		# Charm shimmer — rising tonal sparkle
		var charm_freq := 880.0 + t * 400.0
		var charm_env := sin(clampf(t * 5.0, 0.0, PI)) * 0.3
		s += sin(TAU * charm_freq * t) * charm_env
		s += sin(TAU * charm_freq * 1.5 * t) * charm_env * 0.15
		# Soft bell-like ping
		var bell_env := exp(-t * 6.0) * 0.2
		s += sin(TAU * 1200.0 * t) * bell_env * clampf(t * 30.0, 0.0, 1.0)
		kiss_samples[i] = clampf(s, -1.0, 1.0)
	_brides_kiss_sound = _samples_to_wav(kiss_samples, kiss_rate)
	_brides_kiss_player = AudioStreamPlayer.new()
	_brides_kiss_player.stream = _brides_kiss_sound
	_brides_kiss_player.volume_db = -12.0
	add_child(_brides_kiss_player)

	# Hypnotic Gaze — deep droning hum with wobbling overtones
	var hyp_rate := 22050
	var hyp_dur := 0.9
	var hyp_samples := PackedFloat32Array()
	hyp_samples.resize(int(hyp_rate * hyp_dur))
	for i in hyp_samples.size():
		var t := float(i) / hyp_rate
		var s := 0.0
		var env := sin(clampf(t * 3.0, 0.0, PI)) * 0.35
		# Deep droning base
		s += sin(TAU * 110.0 * t) * env * 0.5
		# Wobbling overtone — creates hypnotic pulsing effect
		var wobble := sin(TAU * 4.0 * t) * 0.4 + 0.6
		s += sin(TAU * 220.0 * t + sin(TAU * 3.0 * t) * 2.0) * env * 0.3 * wobble
		# Higher eerie harmonic
		s += sin(TAU * 330.0 * t + sin(TAU * 5.0 * t) * 1.5) * env * 0.15
		# Subtle swirl noise
		s += (randf() * 2.0 - 1.0) * env * 0.05
		hyp_samples[i] = clampf(s, -1.0, 1.0)
	_hypnotic_gaze_sound = _samples_to_wav(hyp_samples, hyp_rate)
	_hypnotic_gaze_player = AudioStreamPlayer.new()
	_hypnotic_gaze_player.stream = _hypnotic_gaze_sound
	_hypnotic_gaze_player.volume_db = -12.0
	add_child(_hypnotic_gaze_player)

func _process(delta: float) -> void:
	_time += delta
	if _build_timer > 0.0: _build_timer -= delta
	fire_cooldown -= delta
	_upgrade_flash = max(_upgrade_flash - delta * 0.5, 0.0)
	_bite_flash = max(_bite_flash - delta * 2.0, 0.0)
	_bat_devour_flash = max(_bat_devour_flash - delta * 2.0, 0.0)
	_thrall_flash = max(_thrall_flash - delta * 1.5, 0.0)
	_attack_anim = max(_attack_anim - delta * 3.0, 0.0)
	_brides_kiss_flash = max(_brides_kiss_flash - delta * 1.5, 0.0)
	_hypnotic_flash = max(_hypnotic_flash - delta * 2.0, 0.0)

	# Store home position if not set (deferred from _ready for global_position accuracy)
	if _home_position == Vector2.ZERO and global_position != Vector2.ZERO:
		_home_position = global_position

	target = _find_nearest_enemy()

	# Don't shoot while dashing
	var is_dashing = _bite_dash_timer > 0.0 or _lord_feast_dash_timer > 0.0 or _bat_devour_active
	if target and not is_dashing:
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

	# Tier 1+: Bite dash update
	_update_bite_dash(delta)

	# Tier 2+: Bat devour update
	_update_bat_devour(delta)

	# Tier 4: Lord of Darkness feast update
	_update_lord_feast(delta)

	# Tier 4: Lord glow pulse
	if _lord_active:
		_lord_glow = fmod(_lord_glow + delta * 2.0, TAU)

	# Progressive abilities
	_process_progressive_abilities(delta)

	# Manage thrall visuals
	_update_thralls(delta)

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
	# Visual feedback for life drain on blood bolts
	_upgrade_flash = max(_upgrade_flash, 0.3)

# === NEW TIER ABILITY FUNCTIONS ===

func on_wave_start(wave_num: int) -> void:
	# Tier 2+: Bat Devour — delay 2s then devour random enemies
	if upgrade_tier >= 2 and not _bat_devour_active:
		_bat_devour_timer = 2.0

func _trigger_bite(bite_target: Node2D) -> void:
	if not is_instance_valid(bite_target):
		return
	_bite_target = bite_target
	_bite_dash_timer = 0.001  # Start dash
	_bite_returning = false
	_bite_flash = 1.0

func _update_bite_dash(delta: float) -> void:
	if _bite_dash_timer <= 0.0:
		return
	_bite_dash_timer += delta
	var dash_dur := 0.3
	var return_dur := 0.3
	var total_dur := dash_dur + return_dur

	if not _bite_returning:
		# Dashing toward target
		if _bite_dash_timer >= dash_dur:
			# Arrived at target — deal damage
			if is_instance_valid(_bite_target) and _bite_target.has_method("take_damage"):
				var bite_dmg = damage * 4.0 * _damage_mult()
				_bite_target.take_damage(bite_dmg, "magic")
				register_damage(bite_dmg)
				_bite_flash = 1.0
			_bite_returning = true
		else:
			# Interpolate position toward target
			if is_instance_valid(_bite_target):
				var t_val = _bite_dash_timer / dash_dur
				global_position = _home_position.lerp(_bite_target.global_position, t_val)
	else:
		# Returning to home
		var return_progress = (_bite_dash_timer - dash_dur) / return_dur
		if return_progress >= 1.0:
			# Done — reset
			global_position = _home_position
			_bite_dash_timer = 0.0
			_bite_returning = false
			_bite_target = null
		else:
			if is_instance_valid(_bite_target):
				global_position = _bite_target.global_position.lerp(_home_position, return_progress)
			else:
				global_position = global_position.lerp(_home_position, return_progress)

func _trigger_bat_devour() -> void:
	var all_enemies = (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies"))
	var enemies: Array = []
	for enemy in all_enemies:
		if enemy.has_method("is_targetable") and not enemy.is_targetable():
			continue
		enemies.append(enemy)
	if enemies.is_empty():
		return
	var count = randi_range(3, 5)
	_bat_devour_targets.clear()
	# Shuffle and pick random enemies
	var shuffled = enemies.duplicate()
	shuffled.shuffle()
	for i in range(mini(count, shuffled.size())):
		_bat_devour_targets.append(shuffled[i])
	if _bat_devour_targets.is_empty():
		return
	_bat_devour_active = true
	_bat_devour_phase = 0.0
	_bat_devour_flash = 1.0
	if _bat_screech_player and not _is_sfx_muted():
		_bat_screech_player.play()

func _update_bat_devour(delta: float) -> void:
	# Delayed trigger
	if _bat_devour_timer > 0.0 and not _bat_devour_active:
		_bat_devour_timer -= delta
		if _bat_devour_timer <= 0.0:
			_trigger_bat_devour()
		return

	if not _bat_devour_active:
		return

	_bat_devour_phase += delta
	var swirl_dur := 1.0
	if _bat_devour_phase >= swirl_dur:
		# Kill all targets
		for enemy in _bat_devour_targets:
			if is_instance_valid(enemy) and enemy.has_method("take_damage"):
				if "health" in enemy:
					var kill_dmg = enemy.health + 10.0
					enemy.take_damage(kill_dmg, "magic")
					register_damage(kill_dmg)
		_bat_devour_active = false
		_bat_devour_targets.clear()
		_bat_devour_phase = 0.0

func _update_lord_feast(delta: float) -> void:
	if not _lord_active:
		return
	# Auto-feast on cooldown
	if _lord_feast_dash_timer > 0.0:
		# Currently dashing for feast
		_lord_feast_dash_timer += delta
		var dash_dur := 0.25
		var return_dur := 0.25
		if not _lord_feast_returning:
			if _lord_feast_dash_timer >= dash_dur:
				# Arrived — deal feast damage
				if is_instance_valid(_lord_feast_target) and _lord_feast_target.has_method("take_damage"):
					var feast_dmg = damage * 2.0 * _damage_mult()
					_lord_feast_target.take_damage(feast_dmg, "magic")
					register_damage(feast_dmg)
					_bite_flash = 0.8
				_lord_feast_returning = true
			else:
				if is_instance_valid(_lord_feast_target):
					var t_val = _lord_feast_dash_timer / dash_dur
					global_position = _home_position.lerp(_lord_feast_target.global_position, t_val)
		else:
			var return_progress = (_lord_feast_dash_timer - dash_dur) / return_dur
			if return_progress >= 1.0:
				global_position = _home_position
				_lord_feast_dash_timer = 0.0
				_lord_feast_returning = false
				_lord_feast_target = null
			else:
				if is_instance_valid(_lord_feast_target):
					global_position = _lord_feast_target.global_position.lerp(_home_position, return_progress)
				else:
					global_position = global_position.lerp(_home_position, return_progress)
	else:
		_lord_feast_timer += delta
		if _lord_feast_timer >= _lord_feast_cooldown:
			_lord_feast_timer = 0.0
			# Find nearest enemy and start feast dash
			var nearest = _find_nearest_enemy()
			if nearest:
				_lord_feast_target = nearest
				_lord_feast_dash_timer = 0.001
				_lord_feast_returning = false

func _update_thralls(delta: float) -> void:
	# Visual-only thrall indicators
	var i = _active_thralls.size() - 1
	while i >= 0:
		_active_thralls[i]["life"] -= delta
		if _active_thralls[i]["life"] <= 0.0:
			_active_thralls.remove_at(i)
		i -= 1

func register_kill() -> void:
	kill_count += 1

	# Tier 1+: Vampiric Touch — bite every 5 kills
	if upgrade_tier >= 1 and kill_count % 5 == 0 and _bite_dash_timer <= 0.0 and _lord_feast_dash_timer <= 0.0:
		var nearest = _find_nearest_enemy()
		if nearest:
			_trigger_bite(nearest)

	# Tier 3+: Thrall — restore 1 life every 15 kills
	if upgrade_tier >= 3:
		_thrall_kill_counter += 1
		if _thrall_kill_counter % 15 == 0:
			var main = get_tree().get_first_node_in_group("main")
			if main and main.has_method("restore_life"):
				main.restore_life(1)
			_thrall_flash = 1.0
			_upgrade_flash = 1.5
			_upgrade_name = "Life Restored!"
			# Visual thrall rising indicator
			_active_thralls.append({
				"life": 2.0,
				"angle": randf() * TAU,
				"radius": 25.0 + randf() * 15.0,
			})

	# Gold bonus on kills
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
	damage += 2.0
	fire_rate += 0.03
	attack_range += 4.0

func choose_ability(index: int) -> void:
	ability_chosen = true
	awaiting_ability_choice = false
	upgrade_tier = index + 1
	_apply_upgrade(upgrade_tier)
	_upgrade_flash = 3.0
	_upgrade_name = TIER_NAMES[index]

func _apply_upgrade(tier: int) -> void:
	# Base stats for each tier (each strictly higher than previous)
	var tier_base_damage := [30.0, 36.0, 44.0, 52.0]
	var tier_base_fire_rate := [1.30, 1.56, 1.82, 2.20]
	var tier_base_range := [205.0, 220.0, 240.0, 260.0]
	var tier_idx := tier - 1
	# Preserve accumulated boosts from stat upgrades above the tier base
	var dmg_bonus := maxf(damage - tier_base_damage[maxi(tier_idx - 1, 0)], 0.0) if tier_idx > 0 else 0.0
	var fr_bonus := maxf(fire_rate - tier_base_fire_rate[maxi(tier_idx - 1, 0)], 0.0) if tier_idx > 0 else 0.0
	var range_bonus := maxf(attack_range - tier_base_range[maxi(tier_idx - 1, 0)], 0.0) if tier_idx > 0 else 0.0
	match tier:
		1: # Vampiric Touch — bite every 5 kills
			damage = tier_base_damage[0] + dmg_bonus
			fire_rate = tier_base_fire_rate[0] + fr_bonus
			attack_range = tier_base_range[0] + range_bonus
			life_drain_percent = 0.10
		2: # Bat Swarm — devour enemies each wave
			damage = tier_base_damage[1] + dmg_bonus
			fire_rate = tier_base_fire_rate[1] + fr_bonus
			attack_range = tier_base_range[1] + range_bonus
			gold_bonus = 2
		3: # Thrall — life restore every 15 kills
			damage = tier_base_damage[2] + dmg_bonus
			fire_rate = tier_base_fire_rate[2] + fr_bonus
			attack_range = tier_base_range[2] + range_bonus
			gold_bonus = 2
		4: # Lord of Darkness — constant feast
			_lord_active = true
			damage = tier_base_damage[3] + dmg_bonus
			fire_rate = tier_base_fire_rate[3] + fr_bonus
			attack_range = tier_base_range[3] + range_bonus
			gold_bonus = 3

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
	_check_upgrades()

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

## Undead Fortitude — 15% damage reduction for nearby towers
func get_undead_fortitude_reduction() -> float:
	if prog_abilities[0]:
		return 0.15  # 15% damage reduction
	return 0.0

func is_in_undead_fortitude_range(tower_pos: Vector2) -> bool:
	if not prog_abilities[0]:
		return false
	return global_position.distance_to(tower_pos) < attack_range * _range_mult()

func get_damage_reduction() -> float:
	## Check if any Dracula tower nearby has Undead Fortitude active
	var reduction := 0.0
	for tower in get_tree().get_nodes_in_group("towers"):
		if tower == self:
			continue
		if tower.has_method("is_in_undead_fortitude_range"):
			if tower.is_in_undead_fortitude_range(global_position):
				reduction = maxf(reduction, tower.get_undead_fortitude_reduction())
	return reduction

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
			if _blood_moon_active <= 0.0:
				_blood_moon_expire()
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

	# Ability 7: Bride's Kiss — heal + drain strongest (only if enemies in range)
	if prog_abilities[6]:
		_brides_kiss_timer -= delta
		if _brides_kiss_timer <= 0.0:
			if _has_enemies_in_range():
				_brides_kiss()
				_brides_kiss_timer = 22.0
			else:
				_brides_kiss_timer = 2.0  # Retry soon

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
	var eff_range := attack_range * _range_mult()
	for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if global_position.distance_to(e.global_position) < eff_range:
			if "health" in e and e.health < least_hp:
				least_hp = e.health
				weakest = e
	if weakest and weakest.has_method("take_damage"):
		var dmg = damage * 4.0 * _damage_mult()
		weakest.take_damage(dmg, "magic")
		register_damage(dmg)

func _hypnotic_gaze() -> void:
	_hypnotic_flash = 1.0
	var nearest = _find_nearest_enemy()
	if nearest and nearest.has_method("apply_fear_reverse"):
		nearest.apply_fear_reverse(2.0)  # Confused — walks backward along path for 2s
	elif nearest and nearest.has_method("apply_slow"):
		nearest.apply_slow(0.0, 2.0)  # Fallback: freeze if no reverse method
	if _hypnotic_gaze_player and not _is_sfx_muted():
		_hypnotic_gaze_player.play()

func _blood_moon_activate() -> void:
	_blood_moon_flash = 1.0
	_blood_moon_active = 15.0
	# Boost all towers +20% damage for 15s — only apply if not already active
	if not _blood_moon_buff_applied:
		_blood_moon_buff_applied = true
		for tower in get_tree().get_nodes_in_group("towers"):
			if tower.has_method("set_synergy_buff"):
				tower.set_synergy_buff({"damage": 0.20})

func _blood_moon_expire() -> void:
	# Remove the +20% damage buff from all towers when blood moon ends
	if _blood_moon_buff_applied:
		_blood_moon_buff_applied = false
		for tower in get_tree().get_nodes_in_group("towers"):
			if tower.has_method("set_synergy_buff"):
				tower.set_synergy_buff({"damage": -0.20})

func _castle_defense() -> void:
	_castle_defense_flash = 1.0
	# Block 2 nearest enemies (stun them) for 2s
	var enemies = (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies"))
	var eff_range := attack_range * _range_mult()
	var in_range: Array = []
	for e in enemies:
		if global_position.distance_to(e.global_position) < eff_range:
			in_range.append(e)
	in_range.sort_custom(func(a, b): return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position))
	for i in range(mini(2, in_range.size())):
		if in_range[i].has_method("apply_sleep"):
			in_range[i].apply_sleep(2.0)

func _brides_kiss() -> void:
	_brides_kiss_flash = 1.0
	var eff_range := attack_range * _range_mult()
	# Heal 1 life
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("restore_life"):
		main.restore_life(1)
	# Drain strongest enemy in range
	var strongest: Node2D = null
	var most_hp: float = 0.0
	for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if global_position.distance_to(e.global_position) < eff_range:
			if "health" in e and e.health > most_hp:
				most_hp = e.health
				strongest = e
	if strongest and strongest.has_method("take_damage"):
		var dmg = damage * 6.0 * _damage_mult()
		strongest.take_damage(dmg, "magic")
		register_damage(dmg)
		if strongest.has_method("apply_slow"):
			strongest.apply_slow(0.3, 3.0)
	if _brides_kiss_player and not _is_sfx_muted():
		_brides_kiss_player.play()

func _prince_darkness_wave() -> void:
	_prince_flash = 1.0
	# Dark wave damages enemies within 3x effective range
	var prince_range := attack_range * _range_mult() * 3.0
	for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if e.has_method("take_damage") and global_position.distance_to(e.global_position) < prince_range:
			var dmg = damage * 2.0 * _damage_mult()
			e.take_damage(dmg, "magic")
			register_damage(dmg)

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
		draw_circle(Vector2.ZERO, eff_range, Color(1.0, 1.0, 1.0, 0.04))
		draw_arc(Vector2.ZERO, eff_range, 0, TAU, 64, Color(0.8, 0.1, 0.1, 0.25 + pulse * 0.15), 2.0)
		draw_arc(Vector2.ZERO, 40.0, 0, TAU, 48, Color(0.8, 0.1, 0.1, ring_alpha), 2.5)
		draw_arc(Vector2.ZERO, 43.0, 0, TAU, 48, Color(0.8, 0.1, 0.1, ring_alpha * 0.4), 1.5)
	else:
		draw_arc(Vector2.ZERO, eff_range, 0, TAU, 64, Color(1, 1, 1, 0.06), 1.0)

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

	# === 7. BAT DEVOUR FLASH (tier 2 ability) ===
	if _bat_devour_flash > 0.0:
		var bat_ring_r = 36.0 + (1.0 - _bat_devour_flash) * 70.0
		draw_circle(Vector2.ZERO, bat_ring_r, Color(0.3, 0.0, 0.0, _bat_devour_flash * 0.15))
		draw_arc(Vector2.ZERO, bat_ring_r, 0, TAU, 32, Color(0.6, 0.1, 0.1, _bat_devour_flash * 0.3), 2.5)
		for bi in range(8):
			var ba = TAU * float(bi) / 8.0 + _bat_devour_flash * 3.0
			var b_inner = Vector2.from_angle(ba) * (bat_ring_r * 0.5)
			var b_outer = Vector2.from_angle(ba) * (bat_ring_r + 5.0)
			draw_line(b_inner, b_outer, Color(0.5, 0.05, 0.05, _bat_devour_flash * 0.4), 1.5)

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

	# Ability 4: Hypnotic Gaze flash — swirling purple spirals
	if _hypnotic_flash > 0.0:
		var hyp_r = 20.0 + (1.0 - _hypnotic_flash) * 15.0
		for hi in range(6):
			var ha = _time * 4.0 + TAU * float(hi) / 6.0
			var hpos = body_offset + Vector2.from_angle(ha) * hyp_r
			draw_circle(hpos, 2.5, Color(0.5, 0.1, 0.6, _hypnotic_flash * 0.5))
		draw_arc(body_offset, hyp_r, 0, TAU, 24, Color(0.6, 0.15, 0.7, _hypnotic_flash * 0.3), 2.0)
		draw_circle(body_offset, hyp_r * 0.4, Color(0.4, 0.05, 0.5, _hypnotic_flash * 0.12))

	# Ability 5: Blood Moon flash
	if _blood_moon_flash > 0.0:
		var moon_y = -80.0 + (1.0 - _blood_moon_flash) * 10.0
		draw_circle(Vector2(0, moon_y), 16.0, Color(0.7, 0.1, 0.05, _blood_moon_flash * 0.5))
		draw_circle(Vector2(0, moon_y), 12.0, Color(0.85, 0.15, 0.08, _blood_moon_flash * 0.6))
		draw_circle(Vector2(0, moon_y), 20.0, Color(0.5, 0.05, 0.02, _blood_moon_flash * 0.15))
		# Red rays from blood moon
		for ri in range(8):
			var ray_a = TAU * float(ri) / 8.0
			var ray_start = Vector2(0, moon_y) + Vector2.from_angle(ray_a) * 16.0
			var ray_end = Vector2(0, moon_y) + Vector2.from_angle(ray_a) * 35.0
			draw_line(ray_start, ray_end, Color(0.7, 0.1, 0.05, _blood_moon_flash * 0.3), 1.5)

	# Ability 6: Castle Defense flash
	if _castle_defense_flash > 0.0:
		for ci in range(4):
			var ca = TAU * float(ci) / 4.0 + _castle_defense_flash * 2.0
			var cpos = Vector2.from_angle(ca) * 30.0
			# Bat sentinel shape
			draw_line(cpos - Vector2(4, 0), cpos + Vector2(4, 0), Color(0.2, 0.0, 0.0, _castle_defense_flash * 0.5), 2.0)
			draw_line(cpos, cpos + Vector2(-3, -3), Color(0.2, 0.0, 0.0, _castle_defense_flash * 0.4), 1.5)
			draw_line(cpos, cpos + Vector2(3, -3), Color(0.2, 0.0, 0.0, _castle_defense_flash * 0.4), 1.5)

	# Ability 7: Bride's Kiss flash — pink/red hearts and healing glow
	if _brides_kiss_flash > 0.0:
		var kiss_r = 18.0 + (1.0 - _brides_kiss_flash) * 20.0
		# Pink healing glow
		draw_circle(body_offset, kiss_r, Color(0.9, 0.3, 0.4, _brides_kiss_flash * 0.12))
		draw_arc(body_offset, kiss_r, 0, TAU, 24, Color(0.95, 0.2, 0.35, _brides_kiss_flash * 0.35), 2.0)
		# Rising heart particles
		for ki in range(5):
			var ky = body_offset.y - 30.0 - (1.0 - _brides_kiss_flash) * 25.0 - float(ki) * 8.0
			var kx = body_offset.x + sin(_time * 3.0 + float(ki) * 1.5) * 8.0
			var ka = clampf(_brides_kiss_flash - float(ki) * 0.1, 0.0, 1.0) * 0.6
			draw_circle(Vector2(kx, ky), 2.0 + _brides_kiss_flash * 1.0, Color(0.95, 0.2, 0.3, ka))

	# Ability 9: Prince of Darkness flash — dark wave expanding
	if _prince_flash > 0.0:
		var wave_r = 30.0 + (1.0 - _prince_flash) * 120.0
		draw_arc(Vector2.ZERO, wave_r, 0, TAU, 32, Color(0.3, 0.0, 0.0, _prince_flash * 0.4), 3.0)
		draw_arc(Vector2.ZERO, wave_r * 0.7, 0, TAU, 24, Color(0.4, 0.02, 0.02, _prince_flash * 0.25), 2.0)
		for pi in range(8):
			var pa = TAU * float(pi) / 8.0 + _prince_flash * 2.0
			var pr = wave_r * 0.8
			var pp = Vector2.from_angle(pa) * pr
			draw_circle(pp, 2.0, Color(0.5, 0.02, 0.02, _prince_flash * 0.5))

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

	# Tier 3+: Thrall life restore pulse
	if upgrade_tier >= 3:
		# Life drain visual indicators (green/red pulse when life restored)
		for thr in _active_thralls:
			thr["angle"] += 0.02
			var thr_pos = body_offset + Vector2.from_angle(thr["angle"]) * thr["radius"]
			var thr_alpha = clampf(thr["life"] / 2.0, 0.0, 1.0) * 0.5
			# Rising green life orb
			var rise_y = (2.0 - thr["life"]) * 12.0
			var orb_pos = thr_pos + Vector2(0, -rise_y)
			draw_circle(orb_pos, 4.0, Color(0.2, 0.7, 0.2, thr_alpha * 0.6))
			draw_circle(orb_pos, 2.5, Color(0.3, 0.9, 0.3, thr_alpha * 0.8))
			draw_circle(orb_pos, 1.2, Color(0.5, 1.0, 0.5, thr_alpha))
			# Red drain trail below orb
			draw_line(orb_pos, orb_pos + Vector2(0, rise_y * 0.5), Color(0.7, 0.1, 0.05, thr_alpha * 0.3), 1.5)
		# Thrall flash — green/red glow when life restored
		if _thrall_flash > 0.0:
			var tf_alpha = clampf(_thrall_flash, 0.0, 1.0)
			draw_circle(body_offset, 38.0 + _thrall_flash * 8.0, Color(0.2, 0.6, 0.15, tf_alpha * 0.12))
			draw_arc(body_offset, 36.0 + _thrall_flash * 6.0, 0, TAU, 24, Color(0.3, 0.8, 0.2, tf_alpha * 0.25), 2.5)
			# Cross/heart symbol for life restore
			var cross_y = body_offset.y - 45.0 - _thrall_flash * 10.0
			draw_line(Vector2(body_offset.x, cross_y - 4), Vector2(body_offset.x, cross_y + 4), Color(0.3, 0.85, 0.2, tf_alpha * 0.7), 2.5)
			draw_line(Vector2(body_offset.x - 4, cross_y), Vector2(body_offset.x + 4, cross_y), Color(0.3, 0.85, 0.2, tf_alpha * 0.7), 2.5)

	# Tier 4: Lord of Darkness — red pulsing glow aura
	if upgrade_tier >= 4:
		var lord_pulse = sin(_lord_glow) * 0.5 + 0.5
		# Inner red glow
		draw_circle(body_offset, 48.0 + lord_pulse * 8.0, Color(0.6, 0.02, 0.02, 0.06 + lord_pulse * 0.04))
		draw_circle(body_offset, 38.0 + lord_pulse * 5.0, Color(0.7, 0.05, 0.03, 0.08 + lord_pulse * 0.05))
		# Outer pulsing ring
		draw_arc(body_offset, 50.0 + lord_pulse * 8.0, 0, TAU, 32, Color(0.85, 0.08, 0.05, 0.10 + lord_pulse * 0.12), 2.5)
		draw_arc(body_offset, 44.0 + lord_pulse * 5.0, 0, TAU, 24, Color(0.7, 0.05, 0.03, 0.08 + lord_pulse * 0.08), 1.5)
		# Dark red particles rising
		for dp in range(8):
			var dp_a = _time * (0.6 + fmod(float(dp) * 0.3, 0.5)) + float(dp) * TAU / 8.0
			var dp_r = 30.0 + lord_pulse * 6.0 + fmod(float(dp) * 5.3, 12.0)
			var dp_pos = body_offset + Vector2(cos(dp_a) * dp_r, sin(dp_a) * dp_r * 0.5 - fmod(_time * 15.0 + float(dp) * 7.0, 30.0))
			var dp_size = 1.5 + sin(_time * 2.5 + float(dp)) * 0.6
			var dp_alpha = 0.15 + lord_pulse * 0.1
			draw_circle(dp_pos, dp_size, Color(0.8, 0.05, 0.03, dp_alpha))

	# === 12. ACTIVE BAT DEVOUR (tier 2 ability visual) ===
	if _bat_devour_active:
		# Hide normal Dracula during devour — dark cloud at tower position
		draw_circle(body_offset, 18.0, Color(0.08, 0.0, 0.02, 0.4))
		# Swirling bat cloud around each target
		for tgt_i in range(_bat_devour_targets.size()):
			var tgt = _bat_devour_targets[tgt_i]
			if not is_instance_valid(tgt):
				continue
			var tgt_pos = tgt.global_position - global_position
			var devour_progress = clampf(_bat_devour_phase / 1.0, 0.0, 1.0)
			# 8-12 bats per target
			var bat_count_per = 8 + tgt_i * 2
			for bi in range(bat_count_per):
				var ba = _time * (8.0 + float(bi) * 1.3) + float(bi) * TAU / float(bat_count_per) + float(tgt_i) * 1.5
				var br = 20.0 - devour_progress * 12.0 + sin(_time * 5.0 + float(bi)) * 4.0
				var bpos = tgt_pos + Vector2(cos(ba) * br, sin(ba) * br * 0.6)
				var wing_f = sin(_time * 14.0 + float(bi) * 2.5) * 3.5
				# Bat body
				draw_circle(bpos, 2.0, Color(0.12, 0.02, 0.02, 0.7))
				# Wings
				draw_line(bpos, bpos + Vector2(-5, wing_f - 1.5), Color(0.18, 0.02, 0.02, 0.6), 1.5)
				draw_line(bpos, bpos + Vector2(5, wing_f - 1.5), Color(0.18, 0.02, 0.02, 0.6), 1.5)
				# Wing membrane
				draw_line(bpos + Vector2(-5, wing_f - 1.5), bpos + Vector2(-3, wing_f + 0.5), Color(0.15, 0.02, 0.02, 0.4), 1.0)
				draw_line(bpos + Vector2(5, wing_f - 1.5), bpos + Vector2(3, wing_f + 0.5), Color(0.15, 0.02, 0.02, 0.4), 1.0)
				# Red eyes
				draw_circle(bpos + Vector2(-0.8, -0.8), 0.5, Color(0.9, 0.12, 0.08, 0.8))
				draw_circle(bpos + Vector2(0.8, -0.8), 0.5, Color(0.9, 0.12, 0.08, 0.8))
			# Blood mist around target
			var mist_alpha = devour_progress * 0.25
			draw_circle(tgt_pos, 14.0, Color(0.5, 0.02, 0.02, mist_alpha))
			draw_circle(tgt_pos, 8.0, Color(0.7, 0.05, 0.03, mist_alpha * 1.5))

	# === 12b. BITE DASH TRAIL (tier 1 / tier 4 feast) ===
	if _bite_dash_timer > 0.0 or _lord_feast_dash_timer > 0.0:
		var is_lord_feast = _lord_feast_dash_timer > 0.0
		var trail_color = Color(0.85, 0.06, 0.04, 0.3) if is_lord_feast else Color(0.5, 0.02, 0.02, 0.25)
		# Cape trail behind movement direction
		var move_dir = Vector2.ZERO
		if _bite_dash_timer > 0.0 and is_instance_valid(_bite_target):
			move_dir = (_bite_target.global_position - _home_position).normalized()
		elif _lord_feast_dash_timer > 0.0 and is_instance_valid(_lord_feast_target):
			move_dir = (_lord_feast_target.global_position - _home_position).normalized()
		if move_dir.length() > 0.1:
			var trail_perp = move_dir.rotated(PI / 2.0)
			for ti in range(5):
				var trail_offset_val = -move_dir * float(ti) * 8.0
				var trail_alpha = (1.0 - float(ti) / 5.0) * 0.2
				var trail_pos = body_offset + trail_offset_val
				draw_circle(trail_pos, 6.0 - float(ti) * 0.8, Color(trail_color.r, trail_color.g, trail_color.b, trail_alpha))
				# Cape wisps
				var wisp_y = sin(_time * 8.0 + float(ti) * 1.5) * 3.0
				draw_line(trail_pos + trail_perp * 4.0, trail_pos + trail_perp * 4.0 + Vector2(wisp_y, 3.0), Color(trail_color.r, trail_color.g, trail_color.b, trail_alpha * 0.6), 1.5)
				draw_line(trail_pos - trail_perp * 4.0, trail_pos - trail_perp * 4.0 + Vector2(-wisp_y, 3.0), Color(trail_color.r, trail_color.g, trail_color.b, trail_alpha * 0.6), 1.5)
	# Blood splash on bite impact
	if _bite_flash > 0.5:
		var splash_alpha = (_bite_flash - 0.5) * 2.0
		for si in range(6):
			var sa = TAU * float(si) / 6.0 + _bite_flash * 4.0
			var sr = 8.0 + (1.0 - splash_alpha) * 15.0
			var splash_pos = body_offset + Vector2.from_angle(sa) * sr
			draw_circle(splash_pos, 2.0 + splash_alpha * 1.5, Color(0.7, 0.02, 0.02, splash_alpha * 0.4))
		draw_circle(body_offset, 6.0 + (1.0 - splash_alpha) * 10.0, Color(0.8, 0.05, 0.03, splash_alpha * 0.15))

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

	# === Tier 4: Lord of Darkness — glowing red eyes + crimson overlay ===
	if upgrade_tier >= 4:
		var lord_p = sin(_lord_glow) * 0.5 + 0.5
		# Glowing red eyes overlay (intensified on top of normal eyes)
		var glow_eyes_l = head_center + Vector2(-4.0, -1.0)
		var glow_eyes_r = head_center + Vector2(4.0, -1.0)
		var eye_glow_a = 0.3 + lord_p * 0.4
		draw_circle(glow_eyes_l, 6.0, Color(0.9, 0.05, 0.02, eye_glow_a * 0.2))
		draw_circle(glow_eyes_r, 6.0, Color(0.9, 0.05, 0.02, eye_glow_a * 0.2))
		draw_circle(glow_eyes_l, 3.5, Color(1.0, 0.1, 0.05, eye_glow_a * 0.35))
		draw_circle(glow_eyes_r, 3.5, Color(1.0, 0.1, 0.05, eye_glow_a * 0.35))
		# Crimson body outline shimmer
		draw_arc(body_offset, 32.0, 0, TAU, 24, Color(0.85, 0.06, 0.04, 0.06 + lord_p * 0.06), 1.5)
		# Dark red particle trails rising from feet
		for pt in range(5):
			var pt_x = body_offset.x + sin(_time * 1.2 + float(pt) * 1.7) * 12.0
			var pt_y = body_offset.y + 12.0 - fmod(_time * 20.0 + float(pt) * 8.0, 35.0)
			var pt_alpha = 0.12 + lord_p * 0.08
			draw_circle(Vector2(pt_x, pt_y), 1.0 + lord_p * 0.5, Color(0.7, 0.03, 0.02, pt_alpha))

	# === AWAITING ABILITY CHOICE INDICATOR ===
	if awaiting_ability_choice:
		var pulse = (sin(_time * 4.0) + 1.0) * 0.5
		draw_circle(Vector2.ZERO, 68.0 + pulse * 6.0, Color(0.6, 0.1, 0.1, 0.1 + pulse * 0.1))
		draw_arc(Vector2.ZERO, 68.0 + pulse * 6.0, 0, TAU, 32, Color(0.6, 0.1, 0.1, 0.3 + pulse * 0.3), 2.5)
		var font3 = _game_font
		draw_string(font3, Vector2(-16, -80), "!", HORIZONTAL_ALIGNMENT_CENTER, 32, 30, Color(0.6, 0.1, 0.1, 0.7 + pulse * 0.3))

	# === VISUAL TIER EVOLUTION ===
	if upgrade_tier >= 1:
		var glow_pulse = (sin(_time * 2.0) + 1.0) * 0.5
		draw_arc(Vector2.ZERO, 28.0 + glow_pulse * 3.0, 0, TAU, 32, Color(0.7, 0.05, 0.1, 0.15 + glow_pulse * 0.1), 2.0)
	if upgrade_tier >= 2:
		for si in range(6):
			var sa = _time * 1.2 + float(si) * TAU / 6.0
			var sr = 34.0 + sin(_time * 2.5 + float(si)) * 3.0
			var sp = Vector2.from_angle(sa) * sr
			var s_alpha = 0.4 + sin(_time * 3.0 + float(si) * 1.1) * 0.2
			draw_circle(sp, 1.8, Color(0.8, 0.1, 0.1, s_alpha))
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
			draw_line(b_inner, b_outer, Color(0.7, 0.05, 0.1, b_alpha), 1.5)

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

	# Idle ambient particles — crimson mist
	if target == null:
		for ip in range(3):
			var ia = _time * 1.0 + float(ip) * TAU / 3.0
			var ir = 20.0 + sin(_time * 0.6 + float(ip)) * 6.0
			var ipos = Vector2(cos(ia), sin(ia)) * ir
			draw_circle(ipos, 2.5, Color(0.6, 0.05, 0.05, 0.25 + sin(_time * 1.5 + float(ip)) * 0.1))
			draw_circle(ipos, 4.0, Color(0.4, 0.02, 0.02, 0.1))

	# Ability cooldown ring
	var cd_max = 1.0 / fire_rate
	var cd_fill = clampf(1.0 - fire_cooldown / cd_max, 0.0, 1.0)
	if cd_fill >= 1.0:
		var cd_pulse = 0.5 + sin(_time * 4.0) * 0.3
		draw_arc(Vector2.ZERO, 28.0, 0, TAU, 32, Color(0.6, 0.05, 0.05, cd_pulse * 0.4), 2.0)
	elif cd_fill > 0.0:
		draw_arc(Vector2.ZERO, 28.0, -PI / 2.0, -PI / 2.0 + TAU * cd_fill, 32, Color(0.6, 0.05, 0.05, 0.3), 2.0)

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

# === ACTIVE HERO ABILITY: Blood Moon (lifesteal burst, 35s CD) ===
var active_ability_ready: bool = true
var active_ability_cooldown: float = 0.0
var active_ability_max_cd: float = 35.0

func activate_hero_ability() -> void:
	if not active_ability_ready:
		return
	var total_dmg = 0.0
	for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if global_position.distance_to(e.global_position) < attack_range * _range_mult():
			if is_instance_valid(e) and e.has_method("take_damage"):
				var dmg = damage * 4.0 * _damage_mult()
				e.take_damage(dmg, "magic")
				total_dmg += dmg
				register_damage(dmg)
	if total_dmg > 0 and is_instance_valid(_main_node) and _main_node.has_method("restore_life"):
		_main_node.restore_life(1)
	active_ability_ready = false
	active_ability_cooldown = active_ability_max_cd
	if is_instance_valid(_main_node):
		_main_node.spawn_floating_text(global_position + Vector2(0, -40), "BLOOD MOON!", Color(0.8, 0.1, 0.15), 16.0, 1.5)

func get_active_ability_name() -> String:
	return "Blood Moon"

func get_active_ability_desc() -> String:
	return "AoE + lifesteal (35s CD)"

func _damage_mult() -> float:
	return (1.0 + _synergy_buffs.get("damage", 0.0) + _meta_buffs.get("damage", 0.0)) * power_damage_mult

func _range_mult() -> float:
	return 1.0 + _synergy_buffs.get("range", 0.0) + _meta_buffs.get("range", 0.0)

func _speed_mult() -> float:
	return 1.0 + _synergy_buffs.get("attack_speed", 0.0) + _meta_buffs.get("attack_speed", 0.0)

func _gold_mult() -> float:
	return 1.0 + _synergy_buffs.get("gold_bonus", 0.0) + _meta_buffs.get("gold_bonus", 0.0)
