extends Node2D
## The Phantom of the Opera — single-target control tower from Gaston Leroux (1910).
## Throws music notes (heavy damage). Upgrades by dealing damage.
## Tier 1 (5000 DMG): "Punjab Lasso" — periodically stuns closest enemy for 2.5s
## Tier 2 (10000 DMG): "Angel of Music" — passive slow aura on enemies in range
## Tier 3 (15000 DMG): "Chandelier" — periodic AoE burst (2x damage to all in range)
## Tier 4 (20000 DMG): "Phantom's Wrath" — notes apply DoT, all stats boosted

var damage: float = 35.0
var fire_rate: float = 0.33
var attack_range: float = 180.0
var fire_cooldown: float = 0.0
var aim_angle: float = 0.0
var target: Node2D = null
var gold_bonus: int = 1

# Targeting priority: 0=First, 1=Last, 2=Close, 3=Strong
var targeting_priority: int = 0

# Damage tracking and upgrades
var damage_dealt: float = 0.0
var upgrade_tier: int = 0
var _upgrade_flash: float = 0.0
var _upgrade_name: String = ""

# Animation vars
var _time: float = 0.0
var _attack_anim: float = 0.0
var _build_timer: float = 0.0

# Tier 1: Punjab Lasso — kill-count based insta-kill
var _lasso_kill_counter: int = 0
var _lasso_target: Node2D = null
var _lasso_pull_timer: float = 0.0
var _lasso_pulling: bool = false
var _lasso_flash: float = 0.0

# Tier 2: Angel of Music — extended range (no special vars needed)

# Tier 3: Chandelier — kill-count based drop
var _chandelier_kill_counter: int = 0
var _chandelier_flash: float = 0.0

# Tier 4: Phantom's Wrath — melee rush replacing notes
var _has_sword: bool = false
var _sword_flash: float = 0.0
var _sword_angle: float = 0.0
var _melee_state: String = "idle"  # idle, dashing, slashing, returning
var _melee_target: Node2D = null
var _melee_timer: float = 0.0
var _melee_cooldown: float = 0.6  # fast attacks — ballistic
var _melee_pos: Vector2 = Vector2.ZERO  # offset from home for drawing
var _melee_home: Vector2 = Vector2.ZERO
var _melee_slash_count: int = 0  # hits multiple enemies per dash

# === PROGRESSIVE ABILITIES (9 tiers, unlocked via lifetime damage) ===
const PROG_ABILITY_NAMES = [
	"Music of the Night", "The Red Death", "Christine's Aria", "The Trap Door",
	"Box Five", "The Underground Lake", "Requiem Mass",
	"The Organ's Fury", "Beneath the Opera"
]
const PROG_ABILITY_DESCS = [
	"Notes glow brighter, +20% damage",
	"Every 15s, Red Death mask burst fears enemies — they walk backwards for 2s",
	"Every 18s, Christine sings, charming 3 enemies — stopped + 2x damage for 4s",
	"Every 20s, trapdoor on path — instant kill normal, 50% HP boss",
	"Every 15s, spectral opera box rains rose petals dealing AoE damage for 5s",
	"Every 18s, water rises, all enemies slowed to 40% for 3s",
	"Every 20s, ghostly choir stuns ALL enemies on screen for 2s",
	"Every 25s, great organ plays — 3x damage + 2s stun to EVERY enemy",
	"Notes seek enemies across entire map. All enemies permanently 30% slower"
]
var prog_abilities: Array = [false, false, false, false, false, false, false, false, false]
# Ability timers
var _red_death_timer: float = 15.0
var _christines_aria_timer: float = 18.0
var _trap_door_timer: float = 20.0
var _box_five_timer: float = 15.0
var _box_five_active: float = 0.0
var _underground_lake_timer: float = 18.0
var _requiem_mass_timer: float = 20.0
var _organs_fury_timer: float = 25.0
# Visual flash timers
var _red_death_flash: float = 0.0
var _christines_aria_flash: float = 0.0
var _trap_door_flash: float = 0.0
var _box_five_flash: float = 0.0
var _underground_lake_flash: float = 0.0
var _requiem_mass_flash: float = 0.0
var _organs_fury_flash: float = 0.0
var _beneath_opera_flash: float = 0.0

const STAT_UPGRADE_INTERVAL: float = 8000.0
const ABILITY_THRESHOLD: float = 28000.0
var stat_upgrade_level: int = 0
var ability_chosen: bool = false
var awaiting_ability_choice: bool = false
const TIER_NAMES = [
	"Punjab Lasso",
	"Angel of Music",
	"Chandelier",
	"Phantom's Wrath"
]
const ABILITY_DESCRIPTIONS = [
	"Every 8th kill, lasso pulls enemy for insta-kill",
	"Music notes travel further — extended range",
	"Every 15th kill, chandelier drops on enemies",
	"Phantom goes ballistic — melee rush replaces notes"
]
const TIER_COSTS = [155, 365, 675, 1200]
var is_selected: bool = false
var base_cost: int = 0

var note_scene = preload("res://scenes/phantom_note.tscn")

# Attack sounds — organ melody evolving with upgrade tier
var _attack_sounds: Array = []
var _attack_sounds_by_tier: Array = []
var _attack_player: AudioStreamPlayer

# Ability sounds
var _lasso_sound: AudioStreamWAV
var _lasso_player: AudioStreamPlayer
var _chandelier_sound: AudioStreamWAV
var _chandelier_player: AudioStreamPlayer
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
	_attack_player.volume_db = -4.0
	add_child(_attack_player)

	# Punjab lasso — rope swoosh + sharp crack
	var ls_rate := 22050
	var ls_dur := 0.25
	var ls_samples := PackedFloat32Array()
	ls_samples.resize(int(ls_rate * ls_dur))
	for i in ls_samples.size():
		var t := float(i) / ls_rate
		var s := 0.0
		# Swoosh (noise sweep 0-0.15s)
		if t < 0.15:
			var sweep := sin(TAU * lerpf(200.0, 800.0, t / 0.15) * t) * 0.3
			s += (sweep + (randf() * 2.0 - 1.0) * 0.15) * (1.0 - t / 0.15)
		# Sharp crack at 0.15s
		var crack_dt := t - 0.15
		if crack_dt >= 0.0 and crack_dt < 0.06:
			s += (randf() * 2.0 - 1.0) * exp(-crack_dt * 60.0) * 0.7
		ls_samples[i] = clampf(s, -1.0, 1.0)
	_lasso_sound = _samples_to_wav(ls_samples, ls_rate)
	_lasso_player = AudioStreamPlayer.new()
	_lasso_player.stream = _lasso_sound
	_lasso_player.volume_db = -6.0
	add_child(_lasso_player)

	# Chandelier — chain creak + glass shatter + metallic thud
	var cd_rate := 22050
	var cd_dur := 0.7
	var cd_samples := PackedFloat32Array()
	cd_samples.resize(int(cd_rate * cd_dur))
	for i in cd_samples.size():
		var t := float(i) / cd_rate
		var s := 0.0
		# Chain creak (0-0.2s) — metallic groan
		if t < 0.2:
			var creak_freq := 180.0 + sin(TAU * 3.0 * t) * 60.0
			s += sin(TAU * creak_freq * t) * 0.3 * (1.0 - t / 0.2)
		# Glass shatter (0.2-0.5s) — high noise burst
		var sh_dt := t - 0.2
		if sh_dt >= 0.0 and sh_dt < 0.3:
			var glass := (randf() * 2.0 - 1.0) * exp(-sh_dt * 8.0) * 0.5
			var tinkle := sin(TAU * 4500.0 * sh_dt) * exp(-sh_dt * 15.0) * 0.3
			s += glass + tinkle
		# Metallic thud (0.25s) — low impact
		var thud_dt := t - 0.25
		if thud_dt >= 0.0 and thud_dt < 0.15:
			s += sin(TAU * 80.0 * thud_dt) * exp(-thud_dt * 20.0) * 0.4
		cd_samples[i] = clampf(s, -1.0, 1.0)
	_chandelier_sound = _samples_to_wav(cd_samples, cd_rate)
	_chandelier_player = AudioStreamPlayer.new()
	_chandelier_player.stream = _chandelier_sound
	_chandelier_player.volume_db = -6.0
	add_child(_chandelier_player)

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
	if _build_timer > 0.0: _build_timer -= delta
	_attack_anim = max(_attack_anim - delta * 3.0, 0.0)
	fire_cooldown -= delta
	_upgrade_flash = max(_upgrade_flash - delta * 0.5, 0.0)
	_lasso_flash = max(_lasso_flash - delta * 2.0, 0.0)
	_chandelier_flash = max(_chandelier_flash - delta * 1.5, 0.0)
	target = _find_nearest_enemy()

	if _has_sword:
		# Phantom's Wrath — melee rush mode, no notes
		if target:
			aim_angle = lerp_angle(aim_angle, global_position.angle_to_point(target.global_position) + PI, 8.0 * delta)
		_update_melee_rush(delta)
	else:
		if target:
			var desired = global_position.angle_to_point(target.global_position) + PI
			aim_angle = lerp_angle(aim_angle, desired, 8.0 * delta)
			if fire_cooldown <= 0.0:
				_shoot()
				fire_cooldown = 1.0 / (fire_rate * _speed_mult())

	# Update lasso pull animation
	_update_lasso_pull(delta)

	# Flash decays
	_sword_flash = max(_sword_flash - delta * 3.0, 0.0)

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
	var max_range: float = attack_range * _range_mult()
	# Ability 9: Beneath the Opera — unlimited range
	if prog_abilities[8]:
		max_range = 999999.0
	var best: Node2D = null
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
	if _main_node and _main_node.has_method("_pulse_tower_layer"):
		_main_node._pulse_tower_layer(4)  # PHANTOM
	var note = note_scene.instantiate()
	note.global_position = global_position + Vector2.from_angle(aim_angle) * 32.0
	# Ability 1: Music of the Night — +20% damage
	var shoot_damage = damage * _damage_mult()
	if prog_abilities[0]:
		shoot_damage *= 1.2
	note.damage = shoot_damage
	note.target = target
	note.gold_bonus = int(gold_bonus * _gold_mult())
	note.source_tower = self
	# Tier 4: Phantom's Wrath — notes apply DoT
	if upgrade_tier >= 4:
		note.dot_dps = damage * 0.3 * _damage_mult()
		note.dot_duration = 3.0
	else:
		note.dot_dps = 0.0
		note.dot_duration = 0.0
	get_tree().get_first_node_in_group("main").add_child(note)
	_attack_anim = 1.0

func _trigger_lasso() -> void:
	if _lasso_pulling:
		return
	var closest: Node2D = null
	var closest_dist: float = attack_range * _range_mult()
	for enemy in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if enemy.has_method("is_targetable") and not enemy.is_targetable():
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest = enemy
			closest_dist = dist
	if closest and is_instance_valid(closest):
		if _lasso_player and not _is_sfx_muted(): _lasso_player.play()
		_lasso_flash = 1.0
		_lasso_target = closest
		_lasso_pull_timer = 0.5
		_lasso_pulling = true
		# Freeze the target during pull
		if closest.has_method("apply_slow"):
			closest.apply_slow(0.0, 1.0)

func _chandelier_drop() -> void:
	if _chandelier_player and not _is_sfx_muted(): _chandelier_player.play()
	_chandelier_flash = 1.5
	var chandelier_dmg = damage * 2.0 * _damage_mult()
	var eff_range = attack_range * _range_mult()
	for enemy in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if global_position.distance_to(enemy.global_position) < eff_range:
			if enemy.has_method("take_damage"):
				var will_kill = enemy.health - chandelier_dmg <= 0.0
				enemy.take_damage(chandelier_dmg, "magic")
				register_damage(chandelier_dmg)
				if will_kill:
					register_kill()
					if gold_bonus > 0:
						var main = get_tree().get_first_node_in_group("main")
						if main:
							main.add_gold(gold_bonus)

func _update_lasso_pull(delta: float) -> void:
	if not _lasso_pulling:
		return
	_lasso_pull_timer -= delta
	if is_instance_valid(_lasso_target):
		# Pull target toward Phantom
		var pull_dir = global_position - _lasso_target.global_position
		var pull_speed = pull_dir.length() / maxf(_lasso_pull_timer, 0.05)
		_lasso_target.global_position += pull_dir.normalized() * minf(pull_speed * delta, pull_dir.length())
		if _lasso_pull_timer <= 0.0:
			# Insta-kill on arrival (bosses take 50% current HP instead)
			_lasso_flash = 1.5
			if _lasso_target.has_method("take_damage"):
				var dmg: float
				if _lasso_target.max_health > 500:
					# Boss: deal 50% of current HP instead of instakill
					dmg = _lasso_target.health * 0.5
				else:
					dmg = _lasso_target.health + 1.0
				var will_kill = _lasso_target.health - dmg <= 0.0
				_lasso_target.take_damage(dmg, "magic")
				register_damage(dmg)
				if will_kill:
					register_kill()
				if gold_bonus > 0:
					var main = get_tree().get_first_node_in_group("main")
					if main:
						main.add_gold(int(gold_bonus * _gold_mult()))
			_lasso_pulling = false
			_lasso_target = null
	else:
		_lasso_pulling = false
		_lasso_target = null

func _update_melee_rush(delta: float) -> void:
	if not _has_sword:
		return
	if _melee_home == Vector2.ZERO:
		_melee_home = global_position
	var dash_speed = 450.0  # very fast dash
	match _melee_state:
		"idle":
			# Smoothly return to home position
			_melee_pos = _melee_pos.lerp(Vector2.ZERO, 6.0 * delta)
			_melee_timer -= delta
			if _melee_timer <= 0.0:
				# Find nearest enemy in range to rush
				var rush_target = _find_nearest_enemy()
				if rush_target and is_instance_valid(rush_target):
					_melee_target = rush_target
					_melee_state = "dashing"
					_sword_angle = global_position.angle_to_point(rush_target.global_position) + PI
		"dashing":
			if not is_instance_valid(_melee_target):
				_melee_state = "returning"
				return
			var target_offset = _melee_target.global_position - _melee_home
			var dir = (target_offset - _melee_pos)
			if dir.length() < 15.0:
				# Arrived — SLASH!
				_melee_state = "slashing"
				_melee_timer = 0.15  # brief slash pause
				_sword_flash = 1.0
				_sword_angle = _melee_pos.angle()
				_melee_slash_count = 0
				# Deal damage to all enemies nearby
				var sword_dmg = damage * 3.0 * _damage_mult()
				for enemy in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
					if is_instance_valid(enemy) and enemy.has_method("take_damage"):
						if (_melee_home + _melee_pos).distance_to(enemy.global_position) < 55.0:
							var will_kill = enemy.health - sword_dmg <= 0.0
							enemy.take_damage(sword_dmg, "magic")
							register_damage(sword_dmg)
							_melee_slash_count += 1
							if will_kill:
								register_kill()
								if gold_bonus > 0:
									var main = get_tree().get_first_node_in_group("main")
									if main:
										main.add_gold(int(gold_bonus * _gold_mult()))
				# Play attack sound on slash
				if _attack_player and _attack_sounds.size() > 0 and not _is_sfx_muted():
					_attack_player.stream = _attack_sounds[_get_note_index() % _attack_sounds.size()]
					_attack_player.play()
			else:
				_melee_pos += dir.normalized() * dash_speed * delta
				_sword_angle = dir.angle()
		"slashing":
			_melee_timer -= delta
			if _melee_timer <= 0.0:
				_melee_state = "returning"
		"returning":
			var return_dir = -_melee_pos
			if return_dir.length() < 10.0:
				_melee_pos = Vector2.ZERO
				_melee_state = "idle"
				_melee_timer = _melee_cooldown  # brief pause before next rush
				_melee_target = null
			else:
				_melee_pos += return_dir.normalized() * dash_speed * delta

func register_damage(amount: float) -> void:
	damage_dealt += amount
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("register_tower_damage"):
		main.register_tower_damage(main.TowerType.PHANTOM, amount)
	_check_upgrades()

func register_kill() -> void:
	# Tier 1: Punjab Lasso — every 8th kill
	if upgrade_tier >= 1:
		_lasso_kill_counter += 1
		if _lasso_kill_counter >= 8:
			_lasso_kill_counter = 0
			_trigger_lasso()
	# Tier 3: Chandelier — every 15th kill
	if upgrade_tier >= 3:
		_chandelier_kill_counter += 1
		if _chandelier_kill_counter >= 15:
			_chandelier_kill_counter = 0
			_chandelier_drop()

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
	damage += 2.4
	fire_rate += 0.007
	attack_range += 3.5

func choose_ability(index: int) -> void:
	ability_chosen = true
	awaiting_ability_choice = false
	upgrade_tier = index + 1
	_apply_upgrade(upgrade_tier)
	_refresh_tier_sounds()
	_upgrade_flash = 3.0
	_upgrade_name = TIER_NAMES[index]

func _apply_upgrade(tier: int) -> void:
	match tier:
		1: # Punjab Lasso — kill-count insta-kill
			damage = 45.0
			fire_rate = 0.78
			attack_range = 195.0
		2: # Angel of Music — extended range
			damage = 55.0
			fire_rate = 0.92
			attack_range = 240.0
			gold_bonus = 2
		3: # Chandelier — kill-count drop
			damage = 70.0
			fire_rate = 1.04
			attack_range = 250.0
			gold_bonus = 2
		4: # Don Juan Sword
			damage = 90.0
			fire_rate = 1.30
			attack_range = 260.0
			gold_bonus = 3
			_has_sword = true

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
	return "The Phantom"

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
	# Gothic organ — D minor horror scale: D3, Eb3, G3, Bb3
	# Long, drawn-out, scary organ tones inspired by Bach's Toccata and Fugue in D minor
	var gothic_notes := [146.83, 155.56, 196.00, 233.08]  # D3, Eb3, G3, Bb3
	var mix_rate := 44100
	_attack_sounds_by_tier = []

	# --- Tier 0: Haunted Chapel (dark 8' principal, eerie tremulant) ---
	var t0 := []
	for note_idx in gothic_notes.size():
		var freq: float = gothic_notes[note_idx]
		var dur := 2.0  # Long drawn-out note
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * dur))
		for i in samples.size():
			var t := float(i) / mix_rate
			# Slow organ attack, long sustain, gradual release
			var att := clampf(t / 0.08, 0.0, 1.0)
			var rel := clampf((dur - t) / 0.4, 0.0, 1.0)
			var env := att * rel * 0.25
			# Dark principal pipe — heavy on odd harmonics for gothic character
			var pipe := sin(TAU * freq * t)
			pipe += sin(TAU * freq * 2.0 * t) * 0.35
			pipe += sin(TAU * freq * 3.0 * t) * 0.25
			pipe += sin(TAU * freq * 4.0 * t) * 0.12
			pipe += sin(TAU * freq * 5.0 * t) * 0.08
			# 16' Bourdon — deep sub-octave foundation
			var foundation := sin(TAU * freq * 0.5 * t) * 0.4
			# Eerie slow tremulant (slightly irregular for creepiness)
			var trem := 1.0 + sin(TAU * 3.5 * t) * 0.025 + sin(TAU * 5.1 * t) * 0.01
			samples[i] = clampf((pipe + foundation) * env * trem, -1.0, 1.0)
		t0.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t0)

	# --- Tier 1: Phantom's Lair (+ dissonant overtones, deeper foundation) ---
	var t1 := []
	for note_idx in gothic_notes.size():
		var freq: float = gothic_notes[note_idx]
		var dur := 2.2
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * dur))
		for i in samples.size():
			var t := float(i) / mix_rate
			var att := clampf(t / 0.07, 0.0, 1.0)
			var rel := clampf((dur - t) / 0.45, 0.0, 1.0)
			var env := att * rel * 0.24
			var pipe := sin(TAU * freq * t)
			pipe += sin(TAU * freq * 2.0 * t) * 0.38
			pipe += sin(TAU * freq * 3.0 * t) * 0.28
			pipe += sin(TAU * freq * 4.0 * t) * 0.14
			pipe += sin(TAU * freq * 5.0 * t) * 0.10
			pipe += sin(TAU * freq * 6.0 * t) * 0.04
			var foundation := sin(TAU * freq * 0.5 * t) * 0.42
			# Dissonant minor 2nd ghost tone (very quiet, unsettling)
			var ghost := sin(TAU * freq * 1.06 * t) * 0.06 * exp(-t * 0.5)
			var trem := 1.0 + sin(TAU * 3.2 * t) * 0.03 + sin(TAU * 5.3 * t) * 0.012
			samples[i] = clampf((pipe + foundation + ghost) * env * trem, -1.0, 1.0)
		t1.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t1)

	# --- Tier 2: Cathedral of Shadows (+ 32' pedal, reed stops) ---
	var t2 := []
	for note_idx in gothic_notes.size():
		var freq: float = gothic_notes[note_idx]
		var dur := 2.5
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * dur))
		for i in samples.size():
			var t := float(i) / mix_rate
			var att := clampf(t / 0.06, 0.0, 1.0)
			var rel := clampf((dur - t) / 0.5, 0.0, 1.0)
			var env := att * rel * 0.22
			var pipe := sin(TAU * freq * t)
			pipe += sin(TAU * freq * 2.0 * t) * 0.40
			pipe += sin(TAU * freq * 3.0 * t) * 0.30
			pipe += sin(TAU * freq * 4.0 * t) * 0.16
			pipe += sin(TAU * freq * 5.0 * t) * 0.10
			pipe += sin(TAU * freq * 6.0 * t) * 0.05
			var foundation := sin(TAU * freq * 0.5 * t) * 0.44
			# 32' Sub-bass pedal — bone-rattling depth
			var pedal := sin(TAU * freq * 0.25 * t) * 0.2
			# Dark reed stop (odd harmonics, nasal/menacing)
			var reed := sin(TAU * freq * t) * 0.1
			reed += sin(TAU * freq * 3.0 * t) * 0.08
			reed += sin(TAU * freq * 5.0 * t) * 0.05
			reed += sin(TAU * freq * 7.0 * t) * 0.03
			var ghost := sin(TAU * freq * 1.06 * t) * 0.05 * exp(-t * 0.4)
			var trem := 1.0 + sin(TAU * 3.0 * t) * 0.035 + sin(TAU * 5.5 * t) * 0.015
			samples[i] = clampf((pipe + foundation + pedal + reed + ghost) * env * trem, -1.0, 1.0)
		t2.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t2)

	# --- Tier 3: Phantom's Fury (+ full reed chorus, terrifying power) ---
	var t3 := []
	for note_idx in gothic_notes.size():
		var freq: float = gothic_notes[note_idx]
		var dur := 2.8
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * dur))
		for i in samples.size():
			var t := float(i) / mix_rate
			var att := clampf(t / 0.05, 0.0, 1.0)
			var rel := clampf((dur - t) / 0.55, 0.0, 1.0)
			var env := att * rel * 0.20
			var pipe := sin(TAU * freq * t)
			pipe += sin(TAU * freq * 2.0 * t) * 0.42
			pipe += sin(TAU * freq * 3.0 * t) * 0.32
			pipe += sin(TAU * freq * 4.0 * t) * 0.18
			pipe += sin(TAU * freq * 5.0 * t) * 0.12
			pipe += sin(TAU * freq * 6.0 * t) * 0.06
			var foundation := sin(TAU * freq * 0.5 * t) * 0.46
			var pedal := sin(TAU * freq * 0.25 * t) * 0.22
			# Full reed chorus — menacing brass-like growl
			var reed := sin(TAU * freq * t) * 0.14
			reed += sin(TAU * freq * 3.0 * t) * 0.12
			reed += sin(TAU * freq * 5.0 * t) * 0.08
			reed += sin(TAU * freq * 7.0 * t) * 0.05
			reed += sin(TAU * freq * 9.0 * t) * 0.02
			# Dissonant cluster (chromatic neighbor tones for horror)
			var ghost := sin(TAU * freq * 1.06 * t) * 0.04
			ghost += sin(TAU * freq * 0.94 * t) * 0.03
			var trem := 1.0 + sin(TAU * 2.8 * t) * 0.04 + sin(TAU * 5.7 * t) * 0.018
			samples[i] = clampf((pipe + foundation + pedal + reed + ghost) * env * trem, -1.0, 1.0)
		t3.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t3)

	# --- Tier 4: Requiem of the Damned (all stops, mixture, unholy power) ---
	var t4 := []
	for note_idx in gothic_notes.size():
		var freq: float = gothic_notes[note_idx]
		var dur := 3.0
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * dur))
		for i in samples.size():
			var t := float(i) / mix_rate
			var att := clampf(t / 0.04, 0.0, 1.0)
			var rel := clampf((dur - t) / 0.6, 0.0, 1.0)
			var env := att * rel * 0.18
			# Full principal chorus
			var pipe := sin(TAU * freq * t)
			pipe += sin(TAU * freq * 2.0 * t) * 0.45
			pipe += sin(TAU * freq * 3.0 * t) * 0.34
			pipe += sin(TAU * freq * 4.0 * t) * 0.20
			pipe += sin(TAU * freq * 5.0 * t) * 0.14
			pipe += sin(TAU * freq * 6.0 * t) * 0.08
			pipe += sin(TAU * freq * 7.0 * t) * 0.04
			# 16' + 32' foundation (earth-shaking)
			var foundation := sin(TAU * freq * 0.5 * t) * 0.48
			var pedal := sin(TAU * freq * 0.25 * t) * 0.25
			# Full reed tutti
			var reed := sin(TAU * freq * t) * 0.16
			reed += sin(TAU * freq * 3.0 * t) * 0.14
			reed += sin(TAU * freq * 5.0 * t) * 0.10
			reed += sin(TAU * freq * 7.0 * t) * 0.06
			reed += sin(TAU * freq * 9.0 * t) * 0.03
			# Mixture (high compound stops for brilliance)
			var mixture := sin(TAU * freq * 3.0 * t) * 0.05
			mixture += sin(TAU * freq * 4.0 * t) * 0.04
			mixture += sin(TAU * freq * 6.0 * t) * 0.03
			# Dissonant cluster — maximum horror
			var ghost := sin(TAU * freq * 1.06 * t) * 0.04
			ghost += sin(TAU * freq * 0.94 * t) * 0.03
			ghost += sin(TAU * freq * 1.5 * t) * 0.02  # Tritone ghost
			# Haunted tremulant
			var trem := 1.0 + sin(TAU * 2.5 * t) * 0.045 + sin(TAU * 6.0 * t) * 0.02
			samples[i] = clampf((pipe + foundation + pedal + reed + mixture + ghost) * env * trem, -1.0, 1.0)
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
	if main and main.survivor_progress.has(main.TowerType.PHANTOM):
		var p = main.survivor_progress[main.TowerType.PHANTOM]
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
	if prog_abilities[0]:  # Music of the Night: +20% damage (applied in _shoot)
		pass

func get_progressive_ability_name(index: int) -> String:
	if index >= 0 and index < PROG_ABILITY_NAMES.size():
		return PROG_ABILITY_NAMES[index]
	return ""

func get_progressive_ability_desc(index: int) -> String:
	if index >= 0 and index < PROG_ABILITY_DESCS.size():
		return PROG_ABILITY_DESCS[index]
	return ""

func get_spawn_debuffs() -> Dictionary:
	var debuffs := {}
	# Ability 9: Beneath the Opera — all enemies permanently 30% slower
	if prog_abilities[8]:
		debuffs["permanent_slow"] = 0.7
	return debuffs

func _process_progressive_abilities(delta: float) -> void:
	# Visual flash decay
	_red_death_flash = max(_red_death_flash - delta * 2.0, 0.0)
	_christines_aria_flash = max(_christines_aria_flash - delta * 2.0, 0.0)
	_trap_door_flash = max(_trap_door_flash - delta * 2.0, 0.0)
	_box_five_flash = max(_box_five_flash - delta * 1.5, 0.0)
	_underground_lake_flash = max(_underground_lake_flash - delta * 1.5, 0.0)
	_requiem_mass_flash = max(_requiem_mass_flash - delta * 1.5, 0.0)
	_organs_fury_flash = max(_organs_fury_flash - delta * 1.5, 0.0)
	_beneath_opera_flash = max(_beneath_opera_flash - delta * 1.5, 0.0)

	# Ability 2: The Red Death — fear burst every 15s
	if prog_abilities[1]:
		_red_death_timer -= delta
		if _red_death_timer <= 0.0 and _has_enemies_in_range():
			_red_death_burst()
			_red_death_timer = 15.0

	# Ability 3: Christine's Aria — charm 3 enemies every 18s
	if prog_abilities[2]:
		_christines_aria_timer -= delta
		if _christines_aria_timer <= 0.0 and _has_enemies_in_range():
			_christines_aria()
			_christines_aria_timer = 18.0

	# Ability 4: The Trap Door — instant kill every 20s
	if prog_abilities[3]:
		_trap_door_timer -= delta
		if _trap_door_timer <= 0.0 and _has_enemies_in_range():
			_trap_door()
			_trap_door_timer = 20.0

	# Ability 5: Box Five — AoE petal rain every 15s, lasts 5s
	if prog_abilities[4]:
		if _box_five_active > 0.0:
			_box_five_active -= delta
			# Deal damage * delta to all enemies in range each frame (framerate-independent)
			var eff_range_b5 = attack_range * _range_mult()
			for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
				if global_position.distance_to(e.global_position) < eff_range_b5:
					if e.has_method("take_damage"):
						var dmg = damage * _damage_mult() * delta
						e.take_damage(dmg, "magic")
						register_damage(dmg)
		else:
			_box_five_timer -= delta
			if _box_five_timer <= 0.0 and _has_enemies_in_range():
				_box_five_activate()
				_box_five_timer = 15.0

	# Ability 6: The Underground Lake — slow all enemies every 18s
	if prog_abilities[5]:
		_underground_lake_timer -= delta
		if _underground_lake_timer <= 0.0 and _has_enemies_in_range():
			_underground_lake()
			_underground_lake_timer = 18.0

	# Ability 7: Requiem Mass — stun all enemies every 20s
	if prog_abilities[6]:
		_requiem_mass_timer -= delta
		if _requiem_mass_timer <= 0.0:
			_requiem_mass()
			_requiem_mass_timer = 20.0

	# Ability 8: The Organ's Fury — 3x damage + stun all every 25s
	if prog_abilities[7]:
		_organs_fury_timer -= delta
		if _organs_fury_timer <= 0.0 and _has_enemies_in_range():
			_organs_fury()
			_organs_fury_timer = 25.0

func _red_death_burst() -> void:
	_red_death_flash = 1.0
	var eff_range = attack_range * _range_mult()
	for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if global_position.distance_to(e.global_position) < eff_range:
			if e.has_method("apply_fear_reverse"):
				e.apply_fear_reverse(2.0)

func _christines_aria() -> void:
	_christines_aria_flash = 1.0
	var eff_range = attack_range * _range_mult()
	var enemies = (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies"))
	var in_range: Array = []
	for e in enemies:
		if global_position.distance_to(e.global_position) < eff_range:
			in_range.append(e)
	in_range.shuffle()
	for i in range(mini(3, in_range.size())):
		if is_instance_valid(in_range[i]) and in_range[i].has_method("apply_charm"):
			in_range[i].apply_charm(4.0, 2.0)

func _trap_door() -> void:
	_trap_door_flash = 1.0
	var eff_range = attack_range * _range_mult()
	# Find weakest enemy in range
	var weakest: Node2D = null
	var lowest_hp: float = INF
	for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if global_position.distance_to(e.global_position) < eff_range:
			if e.health < lowest_hp:
				lowest_hp = e.health
				weakest = e
	if weakest and weakest.has_method("take_damage"):
		if weakest.max_health > 500:
			# Boss: deal 50% of current HP
			var dmg = weakest.health * 0.5
			weakest.take_damage(dmg, "magic")
			register_damage(dmg)
		else:
			# Normal: instant kill
			var dmg = weakest.health
			weakest.take_damage(dmg, "magic")
			register_damage(dmg)
			register_kill()

func _box_five_activate() -> void:
	_box_five_flash = 1.0
	_box_five_active = 5.0

func _underground_lake() -> void:
	_underground_lake_flash = 1.0
	for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if e.has_method("apply_slow"):
			e.apply_slow(0.4, 3.0)

func _requiem_mass() -> void:
	_requiem_mass_flash = 1.0
	for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if e.has_method("apply_sleep"):
			e.apply_sleep(2.0)

func _organs_fury() -> void:
	_organs_fury_flash = 1.0
	for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if e.has_method("take_damage"):
			var dmg = damage * 3.0 * _damage_mult()
			e.take_damage(dmg, "magic")
			register_damage(dmg)
		if e.has_method("apply_sleep"):
			e.apply_sleep(2.0)

func _draw_tower_aura() -> void:
	if upgrade_tier < 3:
		return
	var aura_col = Color(0.8, 0.15, 0.15)
	var pulse = sin(_time * 2.5) * 0.1 + 0.3
	draw_arc(Vector2.ZERO, 22.0, 0, TAU, 24, Color(aura_col.r, aura_col.g, aura_col.b, pulse * 0.4), 1.5)
	if upgrade_tier >= 4:
		var outer_pulse = sin(_time * 1.8) * 0.15 + 0.35
		draw_arc(Vector2.ZERO, 28.0, 0, TAU, 28, Color(aura_col.r, aura_col.g, aura_col.b, outer_pulse * 0.3), 2.0)
		for i in range(4):
			var na = _time * 0.8 + float(i) * TAU / 4.0
			var nx = cos(na) * 20.0
			var ny = sin(na) * 20.0 * 0.7
			draw_circle(Vector2(nx, ny), 2.5, Color(0.7, 0.2, 0.5, 0.3))
			draw_line(Vector2(nx, ny), Vector2(nx, ny - 6), Color(0.7, 0.2, 0.5, 0.25), 1.0)
	if _main_node and _main_node.has_method("_is_awakened"):
		var tower_type_enum = get_meta("tower_type_enum") if has_meta("tower_type_enum") else -1
		if tower_type_enum >= 0 and _main_node._is_awakened(tower_type_enum):
			for i in range(5):
				var sy = -5.0 - fmod(_time * 20.0 + float(i) * 12.0, 35.0)
				var sx = sin(_time * 1.8 + float(i)) * 8.0
				draw_circle(Vector2(sx, sy), 2.0, Color(0.9, 0.15, 0.1, 0.5))
				draw_line(Vector2(sx, sy), Vector2(sx, sy - 5), Color(0.9, 0.15, 0.1, 0.3), 1.0)
			for i in range(8):
				var ta = _time * 2.0 + float(i) * TAU / 8.0
				var tr = 22.0 + sin(_time * 3.0 + float(i)) * 4.0
				draw_line(Vector2.ZERO, Vector2(cos(ta) * tr, sin(ta) * tr * 0.7), Color(0.9, 0.1, 0.1, 0.2), 1.5)

func _draw() -> void:
	# Build animation — elastic scale-in
	if _build_timer > 0.0:
		var bt = 1.0 - clampf(_build_timer / 0.5, 0.0, 1.0)
		var elastic = 1.0 + sin(bt * PI * 2.5) * 0.3 * (1.0 - bt)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(elastic, elastic))

	# === SELECTION RING ===
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

	# === AIM DIRECTION ===
	var dir = Vector2.from_angle(aim_angle)
	var perp = dir.rotated(PI / 2.0)

	# === IDLE ANIMATION (dramatic theatrical presence) ===
	var bounce = abs(sin(_time * 2.0)) * 3.0  # Slower, more dramatic
	var breathe = sin(_time * 1.5) * 2.5  # Deep theatrical breathing
	var sway = sin(_time * 1.0) * 2.0  # Slow dramatic sway
	var cape_sweep = sin(_time * 0.8) * 3.5  # Slow sweeping cape motion
	var bob = Vector2(sway, -bounce - breathe)
	var fly_offset = Vector2.ZERO
	if upgrade_tier >= 4:
		fly_offset = Vector2(0, -8.0 + sin(_time * 1.5) * 3.0)
	var body_offset = bob + fly_offset + _melee_pos

	# === SKIN COLORS (pale, dramatic — classic Phantom) ===
	var skin_base = Color(0.88, 0.82, 0.78)
	var skin_shadow = Color(0.72, 0.65, 0.60)
	var skin_highlight = Color(0.95, 0.90, 0.88)


	# === UPGRADE FLASH ===
	if _upgrade_flash > 0.0:
		draw_circle(Vector2.ZERO, 80.0 + _upgrade_flash * 24.0, Color(0.6, 0.3, 0.8, _upgrade_flash * 0.25))
		for i in range(10):
			var ray_a = TAU * float(i) / 10.0 + _time * 0.5
			var ray_s = Vector2.from_angle(ray_a) * (50.0 + _upgrade_flash * 8.0)
			var ray_e = Vector2.from_angle(ray_a) * (85.0 + _upgrade_flash * 22.0)
			draw_line(ray_s, ray_e, Color(0.7, 0.4, 0.9, _upgrade_flash * 0.15), 1.5)

	# === MELEE RUSH TRAIL ===
	if _melee_state == "dashing" or _melee_state == "returning":
		# Speed lines / afterimage trail
		var trail_dir = _melee_pos.normalized()
		for ti in range(7):
			var trail_alpha = 0.3 - float(ti) * 0.05
			var trail_offset = -trail_dir * float(ti + 1) * 12.0
			draw_circle(body_offset + trail_offset, 8.0 - float(ti) * 0.9, Color(0.7, 0.2, 0.9, trail_alpha * 1.3))
	if _sword_flash > 0.0:
		# Dramatic slash arc at impact point
		var sf_r = 45.0 + (1.0 - _sword_flash) * 30.0
		draw_arc(body_offset, sf_r, _sword_angle - 1.0, _sword_angle + 1.0, 20, Color(0.85, 0.85, 0.9, _sword_flash * 0.4), 3.5)
		draw_arc(body_offset, sf_r * 0.7, _sword_angle - 0.7, _sword_angle + 0.7, 16, Color(0.95, 0.85, 0.95, _sword_flash * 0.2), 2.0)
		# Slash sparks
		for si in range(6):
			var spark_a = _sword_angle - 0.8 + randf() * 1.6
			var spark_r = sf_r * (0.5 + randf() * 0.5)
			draw_circle(body_offset + Vector2.from_angle(spark_a) * spark_r, 2.0, Color(1.0, 0.9, 0.7, _sword_flash * 0.5))

	# === LASSO FLASH + PULL ANIMATION ===
	if _lasso_flash > 0.0:
		var lf_r = 56.0 + (1.0 - _lasso_flash) * 50.0
		draw_arc(Vector2.ZERO, lf_r, 0, TAU, 32, Color(0.8, 0.65, 0.2, _lasso_flash * 0.5), 4.0)
		draw_arc(Vector2.ZERO, lf_r - 3.0, 0, TAU, 32, Color(0.9, 0.75, 0.3, _lasso_flash * 0.25), 2.0)
	# Draw lasso rope to target being pulled
	if _lasso_pulling and is_instance_valid(_lasso_target):
		var target_local = _lasso_target.global_position - global_position
		# Golden rope line
		draw_line(Vector2.ZERO, target_local, Color(0.85, 0.70, 0.25, 0.8), 3.0)
		draw_line(Vector2.ZERO, target_local, Color(0.95, 0.82, 0.35, 0.4), 1.5)
		# Rope knots along the line
		for ki in range(4):
			var kt = float(ki + 1) / 5.0
			var knot_pos = target_local * kt
			draw_circle(knot_pos, 2.0, Color(0.85, 0.70, 0.25, 0.6))
		# Glow around target
		draw_circle(target_local, 10.0, Color(0.9, 0.75, 0.3, 0.2))
		draw_arc(target_local, 12.0, 0, TAU, 16, Color(0.9, 0.75, 0.3, 0.3), 2.0)

	# === CHANDELIER FLASH (golden burst with crystal shards) ===
	if _chandelier_flash > 0.0:
		var cf_r = 70.0 + (1.0 - _chandelier_flash) * 140.0
		draw_circle(Vector2.ZERO, cf_r, Color(0.95, 0.85, 0.3, _chandelier_flash * 0.3))
		draw_circle(Vector2.ZERO, cf_r * 0.4, Color(1.0, 0.95, 0.7, _chandelier_flash * 0.2))
		for i in range(16):
			var ca = TAU * float(i) / 16.0 + _chandelier_flash * 2.0
			var cp = Vector2.from_angle(ca) * cf_r
			draw_circle(cp, 6.0 + sin(float(i) * 1.3) * 2.0, Color(1.0, 0.95, 0.7, _chandelier_flash * 0.6))
			draw_line(Vector2.from_angle(ca) * 10.0, cp, Color(1.0, 0.92, 0.5, _chandelier_flash * 0.15), 2.0)
		for i in range(8):
			var sa = TAU * float(i) / 8.0 + _chandelier_flash * 3.5
			var sr = cf_r * (0.5 + fmod(float(i) * 0.37, 0.5))
			var sp = Vector2.from_angle(sa) * sr
			draw_circle(sp, 2.0, Color(1.0, 1.0, 1.0, _chandelier_flash * 0.5))

	# === TIER 4: Dark red opera aura with phantom energy wisps ===
	if upgrade_tier >= 4:
		for aura_i in range(5):
			var aura_r = 78.0 + float(aura_i) * 14.0 + sin(_time * 0.9 + float(aura_i) * 0.7) * 4.0
			var aura_a = 0.12 - float(aura_i) * 0.02
			draw_arc(Vector2.ZERO, aura_r, 0, TAU, 48, Color(0.6, 0.05, 0.1, aura_a), 4.0 + float(aura_i) * 1.5)
		for wi in range(6):
			var w_angle = _time * 0.4 + TAU * float(wi) / 6.0
			var w_r = 70.0 + sin(_time * 1.3 + float(wi) * 2.0) * 15.0
			var w_pos = Vector2.from_angle(w_angle) * w_r
			var w_alpha = 0.08 + sin(_time * 2.0 + float(wi)) * 0.04
			draw_circle(w_pos, 6.0 + sin(_time * 1.7 + float(wi)) * 2.0, Color(0.6, 0.05, 0.1, w_alpha))
			var w_tail = Vector2.from_angle(w_angle - 0.3) * (w_r - 12.0)
			draw_line(w_pos, w_tail, Color(0.5, 0.03, 0.12, w_alpha * 0.6), 2.0)

	# === PROGRESSIVE ABILITY VISUAL EFFECTS ===

	# Ability 1: Music of the Night — glowing purple notes with echo trail
	if prog_abilities[0]:
		for ni in range(4):
			var mn_a = _time * 1.2 + float(ni) * TAU / 4.0
			var mn_r = 44.0 + sin(_time * 1.8 + float(ni) * 1.5) * 6.0
			var mn_pos = Vector2.from_angle(mn_a) * mn_r
			var mn_alpha = 0.35 + sin(_time * 2.0 + float(ni) * 1.1) * 0.1
			# Echo trail
			for ei in range(3):
				var trail_a = mn_a - float(ei + 1) * 0.15
				var trail_pos = Vector2.from_angle(trail_a) * mn_r
				draw_circle(trail_pos, 3.0 - float(ei) * 0.5, Color(0.6, 0.3, 0.9, mn_alpha * 0.2 / float(ei + 1)))
			# Glowing note head
			draw_circle(mn_pos, 5.0, Color(0.6, 0.3, 0.9, mn_alpha * 0.2))
			draw_circle(mn_pos, 3.5, Color(0.7, 0.4, 1.0, mn_alpha))
			# Note stem
			draw_line(mn_pos + Vector2(2.0, 0), mn_pos + Vector2(2.0, -10.0), Color(0.7, 0.4, 1.0, mn_alpha * 0.7), 1.5)
			# Note flag
			draw_line(mn_pos + Vector2(2.0, -10.0), mn_pos + Vector2(6.0, -7.0), Color(0.7, 0.4, 1.0, mn_alpha * 0.5), 1.3)

	# Ability 2: The Red Death flash — red skull/mask burst
	if _red_death_flash > 0.0:
		var rd_r = 40.0 + (1.0 - _red_death_flash) * 80.0
		draw_circle(Vector2.ZERO, rd_r, Color(0.8, 0.05, 0.05, _red_death_flash * 0.25))
		draw_arc(Vector2.ZERO, rd_r, 0, TAU, 32, Color(0.9, 0.1, 0.05, _red_death_flash * 0.5), 3.0)
		# Red skull mask shape
		draw_circle(Vector2(0, -8), 8.0, Color(0.9, 0.1, 0.05, _red_death_flash * 0.6))
		draw_circle(Vector2(-3, -10), 2.5, Color(0.0, 0.0, 0.0, _red_death_flash * 0.7))
		draw_circle(Vector2(3, -10), 2.5, Color(0.0, 0.0, 0.0, _red_death_flash * 0.7))
		draw_line(Vector2(-1, -5), Vector2(1, -5), Color(0.0, 0.0, 0.0, _red_death_flash * 0.5), 1.5)
		# Fear ripple rings
		for ri in range(3):
			var rr = rd_r * (0.3 + float(ri) * 0.25)
			draw_arc(Vector2.ZERO, rr, 0, TAU, 24, Color(0.7, 0.05, 0.05, _red_death_flash * 0.2 / float(ri + 1)), 2.0)

	# Ability 3: Christine's Aria flash — music notes and hearts
	if _christines_aria_flash > 0.0:
		for ci in range(5):
			var ca = TAU * float(ci) / 5.0 + _christines_aria_flash * 4.0
			var cr = 30.0 + (1.0 - _christines_aria_flash) * 40.0
			var cpos = Vector2.from_angle(ca) * cr
			# Music note
			draw_circle(cpos, 3.0, Color(1.0, 0.6, 0.8, _christines_aria_flash * 0.6))
			draw_line(cpos + Vector2(2, 0), cpos + Vector2(2, -8), Color(1.0, 0.6, 0.8, _christines_aria_flash * 0.4), 1.2)
			# Heart above
			var hpos = cpos + Vector2(0, -14)
			draw_circle(hpos + Vector2(-2, 0), 3.0, Color(1.0, 0.3, 0.4, _christines_aria_flash * 0.5))
			draw_circle(hpos + Vector2(2, 0), 3.0, Color(1.0, 0.3, 0.4, _christines_aria_flash * 0.5))

	# Ability 4: The Trap Door flash — trapdoor opening
	if _trap_door_flash > 0.0:
		var td_y = 15.0
		var td_open = (1.0 - _trap_door_flash) * 20.0
		# Trapdoor outline
		draw_rect(Rect2(Vector2(-15, td_y - 5), Vector2(30, 10)), Color(0.3, 0.2, 0.1, _trap_door_flash * 0.6), false, 2.0)
		# Door halves opening
		draw_line(Vector2(-15, td_y), Vector2(-15, td_y - td_open), Color(0.4, 0.25, 0.1, _trap_door_flash * 0.5), 3.0)
		draw_line(Vector2(15, td_y), Vector2(15, td_y - td_open), Color(0.4, 0.25, 0.1, _trap_door_flash * 0.5), 3.0)
		# Dark void below
		draw_rect(Rect2(Vector2(-14, td_y - 4), Vector2(28, 8)), Color(0.0, 0.0, 0.0, _trap_door_flash * 0.4), true)

	# Ability 5: Box Five flash — ornate opera box with falling petals
	if _box_five_flash > 0.0 or _box_five_active > 0.0:
		var bf_alpha = maxf(_box_five_flash, _box_five_active / 5.0) * 0.4
		# Opera box outline overhead
		draw_rect(Rect2(Vector2(-20, -90), Vector2(40, 25)), Color(0.8, 0.6, 0.2, bf_alpha), false, 2.0)
		draw_rect(Rect2(Vector2(-18, -88), Vector2(36, 21)), Color(0.6, 0.1, 0.1, bf_alpha * 0.5), true)
		# Falling rose petals
		for pi in range(6):
			var px = -16.0 + float(pi) * 6.4
			var py = -65.0 + fmod(_time * 30.0 + float(pi) * 15.0, 80.0)
			var petal_sway = sin(_time * 3.0 + float(pi) * 2.0) * 4.0
			draw_circle(Vector2(px + petal_sway, py), 2.5, Color(0.9, 0.2, 0.2, bf_alpha * 1.5))
			draw_circle(Vector2(px + petal_sway + 1, py - 1), 1.5, Color(1.0, 0.4, 0.4, bf_alpha))

	# Ability 6: The Underground Lake flash — blue water ripple
	if _underground_lake_flash > 0.0:
		var ul_r = 50.0 + (1.0 - _underground_lake_flash) * 120.0
		draw_circle(Vector2.ZERO, ul_r, Color(0.1, 0.3, 0.7, _underground_lake_flash * 0.15))
		draw_arc(Vector2.ZERO, ul_r, 0, TAU, 48, Color(0.2, 0.5, 0.9, _underground_lake_flash * 0.4), 3.0)
		draw_arc(Vector2.ZERO, ul_r * 0.7, 0, TAU, 36, Color(0.15, 0.4, 0.85, _underground_lake_flash * 0.3), 2.0)
		draw_arc(Vector2.ZERO, ul_r * 0.4, 0, TAU, 24, Color(0.1, 0.35, 0.8, _underground_lake_flash * 0.2), 1.5)

	# Ability 7: Requiem Mass flash — ghostly choir and musical shockwave
	if _requiem_mass_flash > 0.0:
		var rm_r = 45.0 + (1.0 - _requiem_mass_flash) * 100.0
		# Musical shockwave rings
		draw_arc(Vector2.ZERO, rm_r, 0, TAU, 48, Color(0.7, 0.7, 0.9, _requiem_mass_flash * 0.4), 3.5)
		draw_arc(Vector2.ZERO, rm_r * 0.75, 0, TAU, 36, Color(0.6, 0.6, 0.85, _requiem_mass_flash * 0.3), 2.5)
		# Translucent choir silhouettes
		for si in range(5):
			var sa = TAU * float(si) / 5.0 + _requiem_mass_flash * 2.0
			var spos = Vector2.from_angle(sa) * 35.0
			# Ghost figure
			draw_circle(spos + Vector2(0, -6), 4.0, Color(0.8, 0.8, 1.0, _requiem_mass_flash * 0.35))
			draw_line(spos + Vector2(0, -2), spos + Vector2(0, 6), Color(0.8, 0.8, 1.0, _requiem_mass_flash * 0.25), 4.0)

	# Ability 8: The Organ's Fury flash — massive organ and shockwave
	if _organs_fury_flash > 0.0:
		var of_r = 60.0 + (1.0 - _organs_fury_flash) * 150.0
		# Devastating shockwave rings
		draw_arc(Vector2.ZERO, of_r, 0, TAU, 48, Color(0.9, 0.3, 0.1, _organs_fury_flash * 0.35), 4.0)
		draw_arc(Vector2.ZERO, of_r * 0.8, 0, TAU, 36, Color(0.8, 0.2, 0.05, _organs_fury_flash * 0.25), 3.0)
		draw_arc(Vector2.ZERO, of_r * 0.6, 0, TAU, 24, Color(0.7, 0.15, 0.05, _organs_fury_flash * 0.2), 2.0)
		# Pipe organ silhouette
		for pi in range(7):
			var pipe_x = -18.0 + float(pi) * 6.0
			var pipe_h = 20.0 + abs(float(pi) - 3.0) * 8.0
			draw_line(Vector2(pipe_x, -50), Vector2(pipe_x, -50 - pipe_h), Color(0.6, 0.5, 0.3, _organs_fury_flash * 0.5), 4.0)
			draw_circle(Vector2(pipe_x, -50 - pipe_h), 3.0, Color(0.7, 0.6, 0.35, _organs_fury_flash * 0.4))

	# Ability 9: Beneath the Opera — water shimmer overlay
	if prog_abilities[8]:
		var bo_alpha = 0.06 + sin(_time * 1.5) * 0.03
		draw_circle(Vector2.ZERO, attack_range * 0.95, Color(0.15, 0.25, 0.5, bo_alpha))
		# Drifting notes across the map
		for ni in range(6):
			var dn_a = _time * 0.5 + float(ni) * TAU / 6.0
			var dn_r = 60.0 + sin(_time * 0.8 + float(ni) * 1.3) * 30.0
			var dn_pos = Vector2.from_angle(dn_a) * dn_r
			var dn_alpha = 0.25 + sin(_time * 1.5 + float(ni) * 0.7) * 0.1
			draw_circle(dn_pos, 3.5, Color(0.5, 0.3, 0.8, dn_alpha))
			draw_line(dn_pos + Vector2(2, 0), dn_pos + Vector2(2, -9), Color(0.5, 0.3, 0.8, dn_alpha * 0.6), 1.2)

	# === STONE PLATFORM ===
	var plat_y = 22.0
	# Platform shadow
	draw_circle(Vector2(0, plat_y + 4), 28.0, Color(0, 0, 0, 0.15))
	# Stone platform ellipse
	draw_set_transform(Vector2(0, plat_y), 0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 28.0, Color(0.18, 0.16, 0.14))
	draw_circle(Vector2.ZERO, 25.0, Color(0.28, 0.25, 0.22))
	draw_circle(Vector2.ZERO, 20.0, Color(0.35, 0.32, 0.28))
	for si in range(8):
		var sa = TAU * float(si) / 8.0
		draw_circle(Vector2.from_angle(sa) * 16.0, 3.0, Color(0.25, 0.22, 0.20, 0.4))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# Platform top highlight
	draw_set_transform(Vector2(0, plat_y - 2), 0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 22.0, Color(0.40, 0.36, 0.32, 0.3))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	# === SHADOW TENDRILS from platform edges ===
	for ti in range(5):
		var ta = TAU * float(ti) / 5.0 + _time * 0.3
		var t_base = Vector2(cos(ta) * 24.0, plat_y + sin(ta) * 8.0)
		var t_end = t_base + Vector2(sin(_time * 0.8 + float(ti)) * 6.0, 8.0 + sin(_time * 1.2 + float(ti)) * 4.0)
		draw_line(t_base, t_end, Color(0.04, 0.02, 0.06, 0.2), 2.0)
		draw_line(t_end, t_end + Vector2(sin(_time + float(ti)) * 3.0, 5.0), Color(0.04, 0.02, 0.06, 0.1), 1.5)

	# === TIER PIPS on platform edge ===
	for i in range(upgrade_tier):
		var pip_angle = -PI / 2.0 + float(i) * (TAU / 4.0) - (float(upgrade_tier - 1) * TAU / 8.0)
		var pip_pos = Vector2(cos(pip_angle) * 22.0, plat_y + sin(pip_angle) * 8.0)
		var pip_col: Color
		match i:
			0: pip_col = Color(0.5, 0.4, 0.3)    # rope brown
			1: pip_col = Color(0.5, 0.3, 0.65)    # music purple
			2: pip_col = Color(0.85, 0.75, 0.25)  # chandelier gold
			3: pip_col = Color(0.85, 0.15, 0.15)  # dark red
		draw_circle(pip_pos, 5.5, Color(pip_col.r, pip_col.g, pip_col.b, 0.15))
		draw_circle(pip_pos, 4.0, pip_col)
		draw_circle(pip_pos + Vector2(-0.5, -0.5), 1.5, Color(1.0, 1.0, 1.0, 0.3))

	# === T1+: Punjab Lasso rope coils around base of platform ===
	if upgrade_tier >= 1:
		var lasso_glow = _lasso_flash if _lasso_flash > 0.0 else 0.0
		# Main rope coil (left of platform)
		var rope_center = Vector2(-20, plat_y + 2) + body_offset * 0.15
		for i in range(14):
			var rope_a1 = float(i) * TAU / 6.0
			var rope_a2 = float(i + 1) * TAU / 6.0
			var rope_r = 8.0 + float(i) * 0.5
			var rp1 = rope_center + Vector2(cos(rope_a1) * rope_r, sin(rope_a1) * rope_r * 0.45)
			var rp2 = rope_center + Vector2(cos(rope_a2) * rope_r, sin(rope_a2) * rope_r * 0.45)
			var rope_col = Color(0.7 + lasso_glow * 0.3, 0.55 + lasso_glow * 0.3, 0.3 + lasso_glow * 0.1, 0.65)
			draw_line(rp1, rp2, rope_col, 2.5)
			if i % 3 == 0:
				draw_line(rp1, rp2, Color(0.8, 0.65, 0.35, 0.2), 1.0)
		# Glow when lasso activates
		if lasso_glow > 0.0:
			draw_circle(rope_center, 16.0, Color(0.9, 0.75, 0.3, lasso_glow * 0.2))
		# Second small coil (right side)
		var rope2_center = Vector2(18, plat_y + 3) + body_offset * 0.1
		for i in range(10):
			var rope_a1 = float(i) * TAU / 4.0 + 0.5
			var rope_a2 = float(i + 1) * TAU / 4.0 + 0.5
			var rope_r = 6.0 + float(i) * 0.45
			var rp1 = rope2_center + Vector2(cos(rope_a1) * rope_r, sin(rope_a1) * rope_r * 0.45)
			var rp2 = rope2_center + Vector2(cos(rope_a2) * rope_r, sin(rope_a2) * rope_r * 0.45)
			draw_line(rp1, rp2, Color(0.65 + lasso_glow * 0.25, 0.5 + lasso_glow * 0.2, 0.28, 0.55), 2.5)

	# === T2+: Organ pipe silhouettes behind/above character ===
	if upgrade_tier >= 2:
		for i in range(9):
			var pipe_x = body_offset.x - 40.0 + float(i) * 10.0
			var pipe_h = 30.0 + abs(float(i) - 4.0) * 12.0
			var pipe_base_y = body_offset.y - 56.0
			# Pipe shadow
			draw_line(Vector2(pipe_x + 2.0, pipe_base_y), Vector2(pipe_x + 2.0, pipe_base_y - pipe_h), Color(0.15, 0.12, 0.10, 0.25), 6.0)
			# Pipe body (bronze)
			draw_line(Vector2(pipe_x, pipe_base_y), Vector2(pipe_x, pipe_base_y - pipe_h), Color(0.45, 0.40, 0.30, 0.45), 6.0)
			# Pipe highlight
			draw_line(Vector2(pipe_x - 1.5, pipe_base_y), Vector2(pipe_x - 1.5, pipe_base_y - pipe_h), Color(0.60, 0.55, 0.45, 0.3), 2.0)
			# Pipe cap
			draw_circle(Vector2(pipe_x, pipe_base_y - pipe_h), 5.0, Color(0.50, 0.45, 0.35, 0.4))
			draw_circle(Vector2(pipe_x, pipe_base_y - pipe_h), 3.0, Color(0.60, 0.55, 0.45, 0.3))
		# Organ base bar
		draw_line(Vector2(body_offset.x - 42, body_offset.y - 56), Vector2(body_offset.x + 42, body_offset.y - 56), Color(0.30, 0.24, 0.18, 0.4), 2.5)

	# === T2+: Floating music notes orbiting character ===
	if upgrade_tier >= 2:
		for ni in range(3):
			var note_a = _time * 0.8 + float(ni) * TAU / 3.0
			var note_r = 32.0 + sin(_time * 1.5 + float(ni) * 1.2) * 5.0
			var note_bob = sin(_time * 2.0 + float(ni) * 2.0) * 3.0
			var note_pos = body_offset + Vector2(cos(note_a) * note_r, sin(note_a) * note_r * 0.5 + note_bob - 10.0)
			var n_alpha = 0.4 + sin(_time * 1.5 + float(ni) * 0.9) * 0.12
			# Note glow
			draw_circle(note_pos, 7.0, Color(0.5, 0.35, 0.8, n_alpha * 0.15))
			# Note head (oval)
			draw_circle(note_pos, 3.5, Color(0.55, 0.4, 0.85, n_alpha))
			draw_circle(note_pos, 2.2, Color(0.65, 0.5, 0.95, n_alpha * 0.6))
			# Note stem
			draw_line(note_pos + Vector2(2.5, 0), note_pos + Vector2(2.5, -12.0), Color(0.55, 0.4, 0.85, n_alpha * 0.8), 1.5)
			# Note flag
			draw_line(note_pos + Vector2(2.5, -12.0), note_pos + Vector2(7.0, -8.0), Color(0.55, 0.4, 0.85, n_alpha * 0.6), 1.5)
			draw_line(note_pos + Vector2(2.5, -9.0), note_pos + Vector2(6.0, -6.0), Color(0.55, 0.4, 0.85, n_alpha * 0.4), 1.2)

	# === T3+: Chandelier hovering above head ===
	if upgrade_tier >= 3:
		var chand_center = body_offset + Vector2(0, -66.0)
		var chand_sway = sin(_time * 0.8) * 2.0
		chand_center.x += chand_sway
		# Chain links
		for ci in range(4):
			var cy = chand_center.y + 18.0 - float(ci) * 5.0
			var cx_off = chand_sway * float(ci) * 0.12
			draw_arc(Vector2(chand_center.x + cx_off, cy), 2.5, 0, TAU, 8, Color(0.75, 0.65, 0.25, 0.4), 1.5)
		# Main chandelier frame
		draw_arc(chand_center, 18.0, 0, PI, 14, Color(0.82, 0.72, 0.3, 0.65), 3.0)
		draw_arc(chand_center, 15.0, 0, PI, 12, Color(0.70, 0.60, 0.2, 0.3), 2.0)
		# Cross bar
		draw_line(chand_center + Vector2(-18, 0), chand_center + Vector2(18, 0), Color(0.82, 0.72, 0.3, 0.55), 2.5)
		# Center gem
		draw_circle(chand_center, 5.0, Color(0.95, 0.85, 0.3, 0.75))
		draw_circle(chand_center, 3.0, Color(1.0, 0.95, 0.6, 0.5))
		draw_circle(chand_center, 1.5, Color(1.0, 1.0, 0.85, 0.7))
		# Dangling crystals
		for i in range(7):
			var cx = chand_center.x - 18.0 + float(i) * 6.0
			var crystal_swing = sin(_time * 2.0 + float(i) * 1.3) * 2.5 + chand_sway * 0.5
			var crystal_base = Vector2(cx + crystal_swing, chand_center.y)
			var c_len = 8.0 + float(i % 3) * 4.0
			var crystal_end = crystal_base + Vector2(0, c_len)
			# Thread
			draw_line(crystal_base, crystal_end, Color(0.85, 0.8, 0.6, 0.4), 0.8)
			# Diamond shape
			var c_mid = crystal_base + Vector2(0, c_len * 0.5)
			draw_line(c_mid - Vector2(2.5, 0), crystal_end, Color(0.9, 0.88, 0.75, 0.5), 1.2)
			draw_line(c_mid + Vector2(2.5, 0), crystal_end, Color(0.9, 0.88, 0.75, 0.5), 1.2)
			draw_line(c_mid - Vector2(2.5, 0), crystal_base + Vector2(0, c_len * 0.3), Color(0.9, 0.88, 0.75, 0.5), 1.2)
			draw_line(c_mid + Vector2(2.5, 0), crystal_base + Vector2(0, c_len * 0.3), Color(0.9, 0.88, 0.75, 0.5), 1.2)
			# Crystal drop glow
			draw_circle(crystal_end, 3.0, Color(1.0, 0.95, 0.8, 0.5))
			draw_circle(crystal_end, 1.5, Color(1.0, 1.0, 0.9, 0.35))
			# Prismatic sparkle
			var sparkle_phase = sin(_time * 3.5 + float(i) * 1.7)
			if sparkle_phase > 0.3:
				var prism_alpha = (sparkle_phase - 0.3) * 0.6
				var prism_hue = fmod(float(i) * 0.14 + _time * 0.3, 1.0)
				var r_c = 0.5 + sin(prism_hue * TAU) * 0.5
				var g_c = 0.5 + sin(prism_hue * TAU + TAU / 3.0) * 0.5
				var b_c = 0.5 + sin(prism_hue * TAU + 2.0 * TAU / 3.0) * 0.5
				draw_circle(crystal_end + Vector2(0, 1.5), 1.5, Color(r_c, g_c, b_c, prism_alpha * 0.35))
		# Candle flames on chandelier
		for i in range(5):
			var flame_x = chand_center.x - 12.0 + float(i) * 6.0
			var flicker = sin(_time * 6.0 + float(i) * 2.3) * 1.5
			var flicker2 = cos(_time * 4.5 + float(i) * 1.7) * 0.8
			# Outer glow
			draw_circle(Vector2(flame_x, chand_center.y - 3.0 + flicker), 5.0, Color(1.0, 0.7, 0.15, 0.18))
			# Main flame
			draw_circle(Vector2(flame_x, chand_center.y - 4.0 + flicker), 3.5, Color(1.0, 0.82, 0.25, 0.7))
			# Inner flame
			draw_circle(Vector2(flame_x + flicker2 * 0.3, chand_center.y - 5.5 + flicker), 2.0, Color(1.0, 1.0, 0.65, 0.55))
			# Tip
			draw_circle(Vector2(flame_x, chand_center.y - 7.0 + flicker * 1.2), 0.8, Color(1.0, 1.0, 0.9, 0.35))

	# === CHARACTER POSITIONS (Bloons-style chibi ~50px — tallest character, still chunky) ===
	var feet_y = body_offset + Vector2(sway * 1.0, 12.0)
	var leg_top = body_offset + Vector2(sway * 0.6, 2.0)
	var torso_center = body_offset + Vector2(sway * 0.3, -8.0 - breathe * 0.5)
	var neck_base = body_offset + Vector2(sway * 0.15, -16.0 - breathe * 0.3)
	var head_center = body_offset + Vector2(sway * 0.08, -30.0)

	# === CHARACTER BODY (Bloons BTD6 style — bold outlines, chunky, saturated) ===
	var OL = Color(0.06, 0.06, 0.08)

	# --- Character color palette ---
	var suit_fill = Color(0.10, 0.08, 0.12)
	var suit_dark = Color(0.05, 0.03, 0.07)
	var shirt_white = Color(0.97, 0.95, 0.93)
	var cape_outer = Color(0.06, 0.03, 0.08)
	var cape_lining = Color(0.85, 0.08, 0.12)
	var glove_col = Color(0.97, 0.95, 0.93)
	var rose_red = Color(0.94, 0.08, 0.14)
	var rose_dark = Color(0.68, 0.04, 0.08)
	var mask_col = Color(0.98, 0.97, 0.96)
	var hair_col = Color(0.07, 0.05, 0.07)
	var gold_col = Color(0.90, 0.74, 0.24)

	# === CAPE (drawn behind body — dramatic sweep with red lining) ===
	var cape_sway_val = sin(_time * 1.3) * 3.5 + cape_sweep * 1.2
	if upgrade_tier >= 4:
		cape_sway_val += sin(_time * 0.7) * 5.0 + sin(_time * 1.9) * 2.5

	# Cape OL outline polygon
	var cape_ol = PackedVector2Array([
		neck_base + Vector2(-17 - cape_sway_val * 0.3, -2),
		neck_base + Vector2(-21 - cape_sway_val * 0.5, 12),
		body_offset + Vector2(-19 - cape_sway_val * 0.6, 26),
		feet_y + Vector2(-13 - cape_sway_val * 0.3, 8),
		feet_y + Vector2(13 + cape_sway_val * 0.3, 8),
		body_offset + Vector2(19 + cape_sway_val * 0.6, 26),
		neck_base + Vector2(21 + cape_sway_val * 0.5, 12),
		neck_base + Vector2(17 + cape_sway_val * 0.3, -2),
	])
	draw_colored_polygon(cape_ol, OL)
	# Cape black fill
	var cape_fill = PackedVector2Array([
		neck_base + Vector2(-15 - cape_sway_val * 0.3, -1),
		neck_base + Vector2(-19 - cape_sway_val * 0.5, 11),
		body_offset + Vector2(-17 - cape_sway_val * 0.6, 25),
		feet_y + Vector2(-11 - cape_sway_val * 0.3, 7),
		feet_y + Vector2(11 + cape_sway_val * 0.3, 7),
		body_offset + Vector2(17 + cape_sway_val * 0.6, 25),
		neck_base + Vector2(19 + cape_sway_val * 0.5, 11),
		neck_base + Vector2(15 + cape_sway_val * 0.3, -1),
	])
	draw_colored_polygon(cape_fill, cape_outer)
	# Cape red lining (left side visible — vivid red)
	var lining_pts = PackedVector2Array([
		neck_base + Vector2(-14 - cape_sway_val * 0.3, 0),
		neck_base + Vector2(-18 - cape_sway_val * 0.5, 10),
		body_offset + Vector2(-16 - cape_sway_val * 0.5, 24),
		feet_y + Vector2(-10 - cape_sway_val * 0.25, 6),
		torso_center + Vector2(-7, 12),
		torso_center + Vector2(-9, 0),
		neck_base + Vector2(-9, 0),
	])
	draw_colored_polygon(lining_pts, cape_lining)
	# Right lining (subtle)
	var lining_r = PackedVector2Array([
		neck_base + Vector2(9, 0),
		torso_center + Vector2(9, 0),
		torso_center + Vector2(7, 12),
		feet_y + Vector2(10 + cape_sway_val * 0.25, 6),
		body_offset + Vector2(16 + cape_sway_val * 0.5, 24),
		neck_base + Vector2(18 + cape_sway_val * 0.5, 10),
		neck_base + Vector2(14 + cape_sway_val * 0.3, 0),
	])
	draw_colored_polygon(lining_r, Color(0.65, 0.06, 0.09, 0.5))
	# Cape fold creases
	for fold_i in range(5):
		var fold_t = float(fold_i) / 4.0
		var fold_x = -14.0 + fold_t * 28.0
		draw_line(neck_base + Vector2(fold_x, 0), feet_y + Vector2(fold_x + cape_sway_val * (fold_t - 0.5) * 0.3, 6), Color(0.03, 0.02, 0.05, 0.2), 1.0)

	# --- Polished black shoes (OL + fill) ---
	var l_foot = feet_y + Vector2(-6, 0)
	var r_foot = feet_y + Vector2(6, 0)
	draw_circle(l_foot, 5.5, OL)
	draw_circle(r_foot, 5.5, OL)
	draw_circle(l_foot, 4.2, suit_dark)
	draw_circle(r_foot, 4.2, suit_dark)
	# Patent leather shine
	draw_circle(l_foot + Vector2(-0.5, -1.0), 1.5, Color(0.28, 0.25, 0.30, 0.5))
	draw_circle(r_foot + Vector2(-0.5, -1.0), 1.5, Color(0.28, 0.25, 0.30, 0.5))
	# Shoe cuffs
	draw_line(l_foot + Vector2(-4.5, -3), l_foot + Vector2(4.5, -3), OL, 3.5)
	draw_line(l_foot + Vector2(-3.5, -3), l_foot + Vector2(3.5, -3), suit_fill, 2.0)
	draw_line(r_foot + Vector2(-4.5, -3), r_foot + Vector2(4.5, -3), OL, 3.5)
	draw_line(r_foot + Vector2(-3.5, -3), r_foot + Vector2(3.5, -3), suit_fill, 2.0)

	# --- Chunky tuxedo legs (OL + fill) ---
	draw_line(l_foot + Vector2(0, -4), leg_top + Vector2(-4, 0), OL, 9.0)
	draw_line(l_foot + Vector2(0, -4), leg_top + Vector2(-4, 0), suit_fill, 7.0)
	draw_line(r_foot + Vector2(0, -4), leg_top + Vector2(4, 0), OL, 9.0)
	draw_line(r_foot + Vector2(0, -4), leg_top + Vector2(4, 0), suit_fill, 7.0)
	# Satin side stripes
	draw_line(l_foot + Vector2(-2.5, -4), leg_top + Vector2(-6, 0), Color(0.20, 0.18, 0.24, 0.3), 1.0)
	draw_line(r_foot + Vector2(2.5, -4), leg_top + Vector2(6, 0), Color(0.20, 0.18, 0.24, 0.3), 1.0)

	# --- Tuxedo torso (broad shoulders, V-taper waist) ---
	# OL outline
	var torso_ol = PackedVector2Array([
		torso_center + Vector2(-11, 11),
		torso_center + Vector2(-13, 2),
		neck_base + Vector2(-16, 0),
		neck_base + Vector2(16, 0),
		torso_center + Vector2(13, 2),
		torso_center + Vector2(11, 11),
	])
	draw_colored_polygon(torso_ol, OL)
	# Suit fill
	var torso_inner = PackedVector2Array([
		torso_center + Vector2(-10, 10),
		torso_center + Vector2(-12, 2),
		neck_base + Vector2(-15, 1),
		neck_base + Vector2(15, 1),
		torso_center + Vector2(12, 2),
		torso_center + Vector2(10, 10),
	])
	draw_colored_polygon(torso_inner, suit_fill)

	# White dress shirt front (V between lapels)
	var shirt_pts = PackedVector2Array([
		neck_base + Vector2(-5, 3),
		neck_base + Vector2(5, 3),
		torso_center + Vector2(5, 8),
		torso_center + Vector2(-5, 8),
	])
	draw_colored_polygon(shirt_pts, shirt_white)
	# Shirt buttons (OL circles + fill)
	for bi in range(3):
		var btn_pos = torso_center + Vector2(0, -3.0 + float(bi) * 4.0)
		draw_circle(btn_pos, 1.8, OL)
		draw_circle(btn_pos, 1.2, Color(0.90, 0.88, 0.86))
		draw_circle(btn_pos + Vector2(-0.3, -0.3), 0.5, Color(1.0, 1.0, 1.0, 0.5))

	# Peaked lapels (bold OL outlines)
	# Left lapel OL + fill
	var lapel_l = PackedVector2Array([
		neck_base + Vector2(-15, 1),
		neck_base + Vector2(-5, 3),
		torso_center + Vector2(-4, 1),
		torso_center + Vector2(-8, 0),
		neck_base + Vector2(-16, 5),
	])
	draw_colored_polygon(lapel_l, OL)
	var lapel_l_fill = PackedVector2Array([
		neck_base + Vector2(-14, 2),
		neck_base + Vector2(-5, 3.5),
		torso_center + Vector2(-4, 2),
		torso_center + Vector2(-8, 1),
		neck_base + Vector2(-15, 5),
	])
	draw_colored_polygon(lapel_l_fill, suit_dark)
	# Peaked tip
	draw_line(neck_base + Vector2(-15, 1), neck_base + Vector2(-18, -1), OL, 2.5)
	# Right lapel OL + fill
	var lapel_r = PackedVector2Array([
		neck_base + Vector2(5, 3),
		neck_base + Vector2(15, 1),
		neck_base + Vector2(16, 5),
		torso_center + Vector2(8, 0),
		torso_center + Vector2(4, 1),
	])
	draw_colored_polygon(lapel_r, OL)
	var lapel_r_fill = PackedVector2Array([
		neck_base + Vector2(5, 3.5),
		neck_base + Vector2(14, 2),
		neck_base + Vector2(15, 5),
		torso_center + Vector2(8, 1),
		torso_center + Vector2(4, 2),
	])
	draw_colored_polygon(lapel_r_fill, suit_dark)
	draw_line(neck_base + Vector2(15, 1), neck_base + Vector2(18, -1), OL, 2.5)

	# Black bow tie (chunky Bloons circles)
	var tie_pos = neck_base + Vector2(0, 4)
	draw_circle(tie_pos + Vector2(-4.5, 0), 4.0, OL)
	draw_circle(tie_pos + Vector2(-4.5, 0), 3.0, suit_dark)
	draw_circle(tie_pos + Vector2(4.5, 0), 4.0, OL)
	draw_circle(tie_pos + Vector2(4.5, 0), 3.0, suit_dark)
	draw_circle(tie_pos, 2.8, OL)
	draw_circle(tie_pos, 2.0, suit_fill)
	draw_circle(tie_pos + Vector2(-0.3, -0.3), 0.8, Color(0.18, 0.14, 0.20, 0.4))

	# --- Chunky round shoulders (OL + fill) ---
	draw_circle(neck_base + Vector2(-15, 1), 8.0, OL)
	draw_circle(neck_base + Vector2(-15, 1), 6.5, suit_fill)
	draw_circle(neck_base + Vector2(-15, 0), 3.2, Color(0.16, 0.13, 0.18, 0.3))
	draw_circle(neck_base + Vector2(15, 1), 8.0, OL)
	draw_circle(neck_base + Vector2(15, 1), 6.5, suit_fill)
	draw_circle(neck_base + Vector2(15, 0), 3.2, Color(0.16, 0.13, 0.18, 0.3))

	# --- Cape clasps (golden brooches at collar) ---
	var clasp_l = neck_base + Vector2(-13, 1)
	draw_circle(clasp_l, 3.8, OL)
	draw_circle(clasp_l, 2.8, gold_col)
	draw_circle(clasp_l + Vector2(-0.3, -0.5), 1.2, Color(1.0, 0.94, 0.55, 0.6))
	var clasp_r = neck_base + Vector2(13, 1)
	draw_circle(clasp_r, 3.8, OL)
	draw_circle(clasp_r, 2.8, gold_col)
	draw_circle(clasp_r + Vector2(-0.3, -0.5), 1.2, Color(1.0, 0.94, 0.55, 0.6))

	# === LEFT ARM (holds red rose, dramatic cape pose) ===
	var l_shoulder_pos = neck_base + Vector2(-15, 1)
	var l_elbow = l_shoulder_pos + Vector2(-6, 10 + sin(_time * 1.5) * 1.0)
	var l_hand_pos = l_elbow + Vector2(-3, 9 + sin(_time * 1.5) * 1.5)
	# Upper arm: OL + fill
	draw_line(l_shoulder_pos, l_elbow, OL, 9.5)
	draw_line(l_shoulder_pos, l_elbow, suit_fill, 7.0)
	# Forearm: OL + fill
	draw_line(l_elbow, l_hand_pos, OL, 8.5)
	draw_line(l_elbow, l_hand_pos, suit_fill, 6.0)
	# Elbow joint (OL + fill)
	draw_circle(l_elbow, 5.5, OL)
	draw_circle(l_elbow, 4.2, suit_fill)
	# White glove cuff
	draw_line(l_hand_pos + Vector2(-5, -3), l_hand_pos + Vector2(5, -3), OL, 4.5)
	draw_line(l_hand_pos + Vector2(-4, -3), l_hand_pos + Vector2(4, -3), glove_col, 3.0)
	# White-gloved hand (OL + fill)
	draw_circle(l_hand_pos, 5.5, OL)
	draw_circle(l_hand_pos, 4.2, glove_col)
	draw_circle(l_hand_pos + Vector2(-0.8, -1.2), 2.0, Color(1.0, 1.0, 1.0, 0.3))
	# Fingers curled
	for fi in range(3):
		var finger_a = PI * 0.5 + float(fi) * 0.35
		var fp = l_hand_pos + Vector2.from_angle(finger_a) * 4.5
		draw_circle(fp, 2.2, OL)
		draw_circle(fp, 1.5, glove_col)

	# --- RED ROSE in left hand (Phantom's signature) ---
	var rose_pos = l_hand_pos + Vector2(-2, -7)
	# Stem (OL + green fill)
	draw_line(l_hand_pos + Vector2(0, -3), rose_pos + Vector2(0, 5), OL, 3.0)
	draw_line(l_hand_pos + Vector2(0, -3), rose_pos + Vector2(0, 5), Color(0.18, 0.55, 0.14), 1.8)
	# Rose leaf
	var leaf_p = l_hand_pos + Vector2(-3, -5)
	draw_circle(leaf_p, 3.0, OL)
	draw_circle(leaf_p, 2.2, Color(0.20, 0.58, 0.16))
	draw_circle(leaf_p + Vector2(-0.3, -0.3), 1.0, Color(0.30, 0.68, 0.25, 0.4))
	# Rose bloom (layered petals with bold OL)
	draw_circle(rose_pos, 6.0, OL)
	draw_circle(rose_pos, 4.8, rose_red)
	draw_circle(rose_pos + Vector2(-1.5, -1.2), 3.2, Color(1.0, 0.18, 0.22))
	draw_circle(rose_pos + Vector2(1.5, -0.5), 3.0, Color(0.88, 0.08, 0.12))
	draw_circle(rose_pos + Vector2(0, 1.8), 2.6, rose_dark)
	# Rose center spiral
	draw_circle(rose_pos, 2.0, Color(0.72, 0.04, 0.08))
	draw_circle(rose_pos + Vector2(-0.4, -0.4), 1.0, Color(1.0, 0.35, 0.35, 0.5))

	# === RIGHT ARM (conducting hand extending toward aim on attack) ===
	var attack_extend = _attack_anim * 10.0
	var r_shoulder_pos = neck_base + Vector2(15, 1)
	var r_elbow = r_shoulder_pos + Vector2(5, 9)
	var r_hand_pos = r_shoulder_pos + dir * (17.0 + attack_extend)
	# Upper arm: OL + fill
	draw_line(r_shoulder_pos, r_elbow, OL, 9.5)
	draw_line(r_shoulder_pos, r_elbow, suit_fill, 7.0)
	# Forearm: OL + fill
	draw_line(r_elbow, r_hand_pos, OL, 8.5)
	draw_line(r_elbow, r_hand_pos, suit_fill, 6.0)
	# Elbow joint (OL + fill)
	draw_circle(r_elbow, 5.5, OL)
	draw_circle(r_elbow, 4.2, suit_fill)
	# White glove cuff
	var cuff_pos = r_hand_pos - dir * 4.5
	draw_line(cuff_pos + perp * 5.0, cuff_pos - perp * 5.0, OL, 4.5)
	draw_line(cuff_pos + perp * 4.0, cuff_pos - perp * 4.0, glove_col, 3.0)
	# White-gloved hand (OL + fill)
	draw_circle(r_hand_pos, 5.5, OL)
	draw_circle(r_hand_pos, 4.2, glove_col)
	draw_circle(r_hand_pos + Vector2(-0.8, -1.2), 2.0, Color(1.0, 1.0, 1.0, 0.3))
	# Conducting fingers (extended toward aim)
	for fi in range(4):
		var fa = aim_angle + (float(fi) - 1.5) * 0.25
		var fp = r_hand_pos + Vector2.from_angle(fa) * 5.0
		draw_circle(fp, 2.2, OL)
		draw_circle(fp, 1.5, glove_col)

	# --- Sword (Tier 4: Don Juan) ---
	if _has_sword:
		var sword_dir = Vector2.from_angle(_sword_angle if _sword_flash > 0.0 else aim_angle)
		var sword_perp = sword_dir.rotated(PI / 2.0)
		var sword_base = r_hand_pos
		var sword_tip = sword_base + sword_dir * 25.0
		# Blade
		draw_line(sword_base, sword_tip, Color(0.06, 0.06, 0.08), 4.0)
		draw_line(sword_base, sword_tip, Color(0.82, 0.82, 0.88), 2.5)
		# Blade highlight
		draw_line(sword_base + sword_perp * 0.5, sword_tip + sword_perp * 0.5, Color(0.95, 0.95, 1.0, 0.4), 1.0)
		# Gold crossguard
		draw_line(sword_base + sword_perp * 6.0, sword_base - sword_perp * 6.0, Color(0.06, 0.06, 0.08), 4.0)
		draw_line(sword_base + sword_perp * 5.0, sword_base - sword_perp * 5.0, Color(0.90, 0.74, 0.24), 2.5)
		# Pommel
		draw_circle(sword_base - sword_dir * 3.0, 2.5, Color(0.06, 0.06, 0.08))
		draw_circle(sword_base - sword_dir * 3.0, 1.8, Color(0.90, 0.74, 0.24))
		# Swing arc trail when attacking
		if _sword_flash > 0.0:
			var arc_start = _sword_angle - 0.8
			var arc_end = _sword_angle + 0.8
			for ai in range(8):
				var at = arc_start + (arc_end - arc_start) * float(ai) / 7.0
				var arc_tip = sword_base + Vector2.from_angle(at) * 25.0
				draw_line(sword_base, arc_tip, Color(0.82, 0.82, 0.88, _sword_flash * 0.15), 1.5)
			draw_arc(sword_base, 25.0, arc_start, arc_end, 16, Color(0.85, 0.85, 0.9, _sword_flash * 0.3), 2.0)

	# --- Music notes near conducting hand (weapon) ---
	var note_base = r_hand_pos + dir * 9.0
	for ni in range(2):
		var note_off = dir.rotated(PI * 0.3 * float(ni) - PI * 0.15) * (6.0 + float(ni) * 4.0)
		var note_pos = note_base + note_off
		var n_bob_y = sin(_time * 4.0 + float(ni) * 2.5) * 2.0
		note_pos.y += n_bob_y
		# Note head OL + fill
		draw_circle(note_pos, 4.0, OL)
		draw_circle(note_pos, 2.8, Color(0.62, 0.38, 0.92))
		# Note stem
		draw_line(note_pos + Vector2(2, 0), note_pos + Vector2(2, -10.0), OL, 2.8)
		draw_line(note_pos + Vector2(2, 0), note_pos + Vector2(2, -10.0), Color(0.62, 0.38, 0.92), 1.5)
		# Note flag
		draw_line(note_pos + Vector2(2, -10.0), note_pos + Vector2(6.5, -6.5), OL, 2.8)
		draw_line(note_pos + Vector2(2, -10.0), note_pos + Vector2(6.5, -6.5), Color(0.62, 0.38, 0.92), 1.5)

	# Attack flash — music notes shooting toward aim
	if _attack_anim > 0.3:
		var flash_alpha = (_attack_anim - 0.3) * 1.4
		for ai in range(3):
			var a_dist = 12.0 + float(ai) * 10.0 + (1.0 - _attack_anim) * 20.0
			var a_spread = float(ai - 1) * 0.2
			var a_pos = r_hand_pos + dir.rotated(a_spread) * a_dist
			draw_circle(a_pos, 4.2 - float(ai) * 0.5, OL)
			draw_circle(a_pos, 3.2 - float(ai) * 0.5, Color(0.68, 0.38, 0.96, flash_alpha * (0.8 - float(ai) * 0.15)))
			draw_circle(a_pos - dir * 4.0, 2.0, Color(0.78, 0.58, 1.0, flash_alpha * 0.35))

	# === NECK (short chunky, with shirt collar) ===
	draw_line(neck_base + Vector2(0, 0), head_center + Vector2(0, 13), OL, 10.0)
	draw_line(neck_base + Vector2(0, 0), head_center + Vector2(0, 13), skin_base, 7.0)
	draw_line(neck_base + Vector2(1.5, 0), head_center + Vector2(1.5, 12), skin_highlight, 2.0)
	# White shirt collar points
	var collar_l_ol = PackedVector2Array([
		neck_base + Vector2(-8, 4), neck_base + Vector2(-4, -2), neck_base + Vector2(0, 4),
	])
	draw_colored_polygon(collar_l_ol, OL)
	var collar_l_fill = PackedVector2Array([
		neck_base + Vector2(-7, 4), neck_base + Vector2(-4, -1), neck_base + Vector2(0, 4),
	])
	draw_colored_polygon(collar_l_fill, shirt_white)
	var collar_r_ol = PackedVector2Array([
		neck_base + Vector2(0, 4), neck_base + Vector2(4, -2), neck_base + Vector2(8, 4),
	])
	draw_colored_polygon(collar_r_ol, OL)
	var collar_r_fill = PackedVector2Array([
		neck_base + Vector2(0, 4), neck_base + Vector2(4, -1), neck_base + Vector2(7, 4),
	])
	draw_colored_polygon(collar_r_fill, shirt_white)

	# === HEAD (big round Bloons head — oversized for chibi) ===
	var head_r = 14.0

	# Head OL (outermost circle)
	draw_circle(head_center, head_r + 1.5, OL)
	# Hair base layer (covers entire head first)
	draw_circle(head_center, head_r, hair_col)

	# Face skin (offset slightly down to show hair on top)
	draw_circle(head_center + Vector2(-1, 2), 12.5, OL)
	draw_circle(head_center + Vector2(-1, 2), 11.0, skin_base)
	# Face highlight (top-left Bloons shine)
	draw_circle(head_center + Vector2(-3, -1), 5.5, skin_highlight)

	# --- Dramatic slicked-back dark hair ---
	# Main hair volume polygon (OL + fill)
	var hair_ol = PackedVector2Array([
		head_center + Vector2(-head_r + 1, 5),
		head_center + Vector2(-head_r - 1, -2),
		head_center + Vector2(-head_r + 1, -9),
		head_center + Vector2(-3, -head_r - 4),
		head_center + Vector2(3, -head_r - 3),
		head_center + Vector2(8, -head_r - 1),
		head_center + Vector2(head_r, -5),
		head_center + Vector2(head_r - 1, 0),
		head_center + Vector2(5, 0),
		head_center + Vector2(0, -2),
		head_center + Vector2(-4, 0),
		head_center + Vector2(-8, 1),
	])
	draw_colored_polygon(hair_ol, OL)
	var hair_fill = PackedVector2Array([
		head_center + Vector2(-head_r + 2, 4),
		head_center + Vector2(-head_r, -2),
		head_center + Vector2(-head_r + 2, -8),
		head_center + Vector2(-3, -head_r - 3),
		head_center + Vector2(3, -head_r - 2),
		head_center + Vector2(8, -head_r),
		head_center + Vector2(head_r - 1, -5),
		head_center + Vector2(head_r - 2, 0),
		head_center + Vector2(5, 0),
		head_center + Vector2(0, -2),
		head_center + Vector2(-4, 0),
		head_center + Vector2(-7, 1),
	])
	draw_colored_polygon(hair_fill, hair_col)
	# Hair shine streaks (glossy slicked-back look)
	draw_line(head_center + Vector2(-2, -head_r - 2), head_center + Vector2(-7, 2), Color(0.20, 0.16, 0.24, 0.5), 2.2)
	draw_line(head_center + Vector2(1, -head_r - 1), head_center + Vector2(-3, -1), Color(0.22, 0.18, 0.26, 0.4), 1.8)
	draw_line(head_center + Vector2(5, -head_r), head_center + Vector2(3, -3), Color(0.20, 0.16, 0.24, 0.35), 1.4)
	# Hair shine arc
	draw_arc(head_center + Vector2(0, -4), 10.0, PI * 0.55, PI * 0.85, 8, Color(0.28, 0.22, 0.32, 0.35), 2.5)
	# Loose strand over mask edge
	var strand_wave = sin(_time * 2.0) * 1.5
	draw_line(head_center + Vector2(1, -head_r + 1), head_center + Vector2(2 + strand_wave, 4), hair_col, 1.8)
	draw_line(head_center + Vector2(0, -head_r + 3), head_center + Vector2(1.5 + strand_wave * 0.7, 2), Color(hair_col.r, hair_col.g, hair_col.b, 0.6), 1.2)
	# Long strands cascading past jaw on left side
	for si in range(3):
		var sx = -12.0 + float(si) * 2.5
		var wave_mod = sin(_time * 1.5 + float(si) * 0.5) * 1.5
		var s_start = head_center + Vector2(sx, 5)
		var s_end = head_center + Vector2(sx + wave_mod, 18.0 + float(si % 2) * 3.0)
		draw_line(s_start, s_end, OL, 2.8)
		draw_line(s_start, s_end, hair_col, 1.8)

	# === WHITE HALF-MASK (right side of face — THE iconic feature!) ===
	var mask_center = head_center + Vector2(5, 0)
	# Subtle mask glow behind
	var mask_glow_alpha = 0.08 + sin(_time * 2.0) * 0.04
	draw_circle(mask_center, head_r * 0.65, Color(0.96, 0.96, 1.0, mask_glow_alpha))
	# Mask shape OL
	var mask_pts = PackedVector2Array([
		head_center + Vector2(1, -11),
		head_center + Vector2(6, -13),
		head_center + Vector2(11, -9),
		head_center + Vector2(13, -3),
		head_center + Vector2(13, 3),
		head_center + Vector2(10, 8),
		head_center + Vector2(6, 10),
		head_center + Vector2(1, 6),
		head_center + Vector2(1, -2),
	])
	draw_colored_polygon(mask_pts, OL)
	# Mask porcelain fill
	var mask_fill_pts = PackedVector2Array([
		head_center + Vector2(2, -10),
		head_center + Vector2(6, -12),
		head_center + Vector2(10, -8),
		head_center + Vector2(12, -2),
		head_center + Vector2(12, 3),
		head_center + Vector2(9, 7),
		head_center + Vector2(6, 9),
		head_center + Vector2(2, 5),
		head_center + Vector2(2, -2),
	])
	draw_colored_polygon(mask_fill_pts, mask_col)
	# Porcelain sheen highlight
	var mask_sheen = PackedVector2Array([
		head_center + Vector2(3, -9),
		head_center + Vector2(7, -11),
		head_center + Vector2(10, -7),
		head_center + Vector2(9, -1),
		head_center + Vector2(6, -1),
		head_center + Vector2(3, -3),
	])
	draw_colored_polygon(mask_sheen, Color(1.0, 1.0, 1.0, 0.4))
	# Gold filigree accents
	draw_arc(head_center + Vector2(7, -7), 3.5, PI * 0.3, PI * 1.2, 8, Color(gold_col.r, gold_col.g, gold_col.b, 0.35), 1.2)
	draw_arc(head_center + Vector2(10, 0), 2.8, PI * 0.5, PI * 1.5, 6, Color(gold_col.r, gold_col.g, gold_col.b, 0.3), 1.0)
	draw_arc(head_center + Vector2(7, 5), 2.2, 0, PI, 6, Color(gold_col.r, gold_col.g, gold_col.b, 0.25), 0.9)
	# Mask eye hole (dark void, mysterious)
	var mask_eye_pos = head_center + Vector2(7, -1)
	draw_circle(mask_eye_pos, 4.5, OL)
	draw_circle(mask_eye_pos, 3.5, Color(0.03, 0.02, 0.05))
	# Faint eerie glow in mask eye
	draw_circle(mask_eye_pos, 5.0, Color(0.6, 0.5, 0.8, 0.06 + sin(_time * 2.5) * 0.03))
	# Mask nostril hint
	draw_circle(head_center + Vector2(5, 4), 1.2, Color(0.90, 0.88, 0.86, 0.3))

	# Tier 4: Mask eye glows bright red/orange
	if upgrade_tier >= 4:
		var eye_glow_alpha = 0.5 + sin(_time * 3.0) * 0.25
		draw_circle(mask_eye_pos, 5.0, Color(0.9, 0.2, 0.05, eye_glow_alpha * 0.3))
		draw_circle(mask_eye_pos, 3.5, Color(1.0, 0.35, 0.1, eye_glow_alpha * 0.5))
		draw_circle(mask_eye_pos, 1.8, Color(1.0, 0.6, 0.2, eye_glow_alpha * 0.7))

	# === BIG CARTOON EYE — left (visible) side — full Bloons 5-layer ===
	var l_eye_pos = head_center + Vector2(-4, -1)
	# Eye OL (outermost)
	draw_circle(l_eye_pos, 5.8, OL)
	# Eye white
	draw_circle(l_eye_pos, 4.8, Color(0.99, 0.99, 0.99))
	# Iris (dark intense brown)
	draw_circle(l_eye_pos + dir * 0.8, 3.5, Color(0.14, 0.10, 0.08))
	# Lighter iris inner ring
	draw_circle(l_eye_pos + dir * 0.8, 2.8, Color(0.24, 0.17, 0.14))
	# Pupil (solid black)
	draw_circle(l_eye_pos + dir * 1.0, 1.6, Color(0.02, 0.02, 0.02))
	# Primary sparkle (big bright Bloons catch-light)
	draw_circle(l_eye_pos + Vector2(-1.2, -1.6), 1.4, Color(1.0, 1.0, 1.0, 0.95))
	# Secondary sparkle
	draw_circle(l_eye_pos + Vector2(1.0, 0.6), 0.7, Color(1.0, 1.0, 1.0, 0.55))
	# Bold upper eyelid
	draw_arc(l_eye_pos, 5.2, PI + 0.3, TAU - 0.3, 10, OL, 2.2)
	# Dramatic eyebrow (thick bold arc)
	draw_line(head_center + Vector2(-9, -5), head_center + Vector2(-1, -7.5), OL, 3.2)
	draw_line(head_center + Vector2(-8.5, -5), head_center + Vector2(-1, -7.5), hair_col, 2.0)
	# Right eyebrow (sculpted on mask surface)
	draw_line(head_center + Vector2(3, -8), head_center + Vector2(10, -6.5), Color(0.88, 0.86, 0.84, 0.4), 1.8)

	# Small ear (visible behind hair on left)
	draw_circle(head_center + Vector2(-11, 3), 3.0, OL)
	draw_circle(head_center + Vector2(-11, 3), 2.2, skin_base)
	draw_circle(head_center + Vector2(-11.3, 2.5), 1.0, skin_highlight)

	# Mouth (small dramatic smirk on visible side)
	draw_line(head_center + Vector2(-5, 7), head_center + Vector2(0, 7.5), OL, 2.2)
	draw_line(head_center + Vector2(-4.5, 7), head_center + Vector2(0, 7.5), Color(0.68, 0.45, 0.42), 1.2)
	# Smirk upturn
	draw_line(head_center + Vector2(-5, 7), head_center + Vector2(-6, 6), Color(0.60, 0.40, 0.38, 0.5), 1.0)

	# Nose (small cute Bloons bump)
	draw_circle(head_center + Vector2(-1, 3), 2.2, OL)
	draw_circle(head_center + Vector2(-1, 3), 1.5, skin_base)
	draw_circle(head_center + Vector2(-1.5, 2.5), 0.7, skin_highlight)

	# Chin (rounded Bloons style)
	draw_circle(head_center + Vector2(-1, 11), 3.8, OL)
	draw_circle(head_center + Vector2(-1, 11), 2.8, skin_base)
	draw_circle(head_center + Vector2(-1.3, 10.5), 1.2, skin_highlight)

	# === TIER 4: DARK RED OPERA AURA on character ===
	if upgrade_tier >= 4:
		draw_circle(torso_center, 28.0, Color(0.6, 0.08, 0.08, 0.06 + sin(_time * 2.0) * 0.03))
		draw_circle(head_center, 20.0, Color(0.6, 0.08, 0.08, 0.05 + sin(_time * 2.5) * 0.02))

	# (Aura ring removed — Angel of Music is now range-based)

	# === T4: Crown of dark flame above head ===
	if upgrade_tier >= 4:
		var crown_hover = sin(_time * 1.8) * 1.5
		var crown_center = head_center + Vector2(0, -14 + crown_hover)
		for fi in range(5):
			var flame_x = crown_center.x - 8.0 + float(fi) * 4.0
			var flame_h = 8.0 + sin(_time * 5.0 + float(fi) * 2.0) * 3.0
			var flame_sway2 = sin(_time * 3.0 + float(fi) * 1.5) * 2.0
			var flame_base2 = Vector2(flame_x + flame_sway2, crown_center.y)
			var flame_tip2 = flame_base2 + Vector2(0, -flame_h)
			draw_line(flame_base2, flame_tip2, Color(0.5, 0.05, 0.05, 0.4), 3.0)
			draw_line(flame_base2 + Vector2(0, -1), flame_tip2 + Vector2(0, 2), Color(0.9, 0.25, 0.1, 0.3), 1.5)
		draw_circle(crown_center, 12.0, Color(0.7, 0.1, 0.05, 0.08))


	# === AWAITING ABILITY CHOICE INDICATOR ===
	if awaiting_ability_choice:
		var pulse = (sin(_time * 4.0) + 1.0) * 0.5
		draw_circle(Vector2.ZERO, 60.0 + pulse * 6.0, Color(0.6, 0.3, 0.8, 0.1 + pulse * 0.1))
		draw_arc(Vector2.ZERO, 60.0 + pulse * 6.0, 0, TAU, 32, Color(0.6, 0.3, 0.8, 0.3 + pulse * 0.3), 2.5)
		var font3 = _game_font
		draw_string(font3, Vector2(-16, -82), "!", HORIZONTAL_ALIGNMENT_CENTER, 32, 30, Color(0.6, 0.3, 0.8, 0.7 + pulse * 0.3))

	# === VISUAL TIER EVOLUTION ===
	if upgrade_tier >= 1:
		var glow_pulse = (sin(_time * 2.0) + 1.0) * 0.5
		draw_arc(Vector2.ZERO, 28.0 + glow_pulse * 3.0, 0, TAU, 32, Color(0.9, 0.15, 0.15, 0.15 + glow_pulse * 0.1), 2.0)
	if upgrade_tier >= 2:
		for si in range(6):
			var sa = _time * 1.2 + float(si) * TAU / 6.0
			var sr = 34.0 + sin(_time * 2.5 + float(si)) * 3.0
			var sp = Vector2.from_angle(sa) * sr
			var s_alpha = 0.4 + sin(_time * 3.0 + float(si) * 1.1) * 0.2
			draw_circle(sp, 1.8, Color(1.0, 0.2, 0.2, s_alpha))
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
			draw_line(b_inner, b_outer, Color(0.9, 0.15, 0.15, b_alpha), 1.5)

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
		draw_string(font2, Vector2(-80, -74), _upgrade_name, HORIZONTAL_ALIGNMENT_CENTER, 160, 16, Color(0.6, 0.3, 0.8, min(_upgrade_flash, 1.0)))

	# Idle ambient particles — music notes
	if target == null:
		for ip in range(3):
			var iy = -20.0 + sin(_time * 1.3 + float(ip) * 2.1) * 15.0
			var ix = cos(_time * 0.8 + float(ip) * 2.5) * 12.0
			var ipos = Vector2(ix, iy)
			draw_circle(ipos, 2.0, Color(0.5, 0.2, 0.7, 0.3 + sin(_time * 2.0 + float(ip)) * 0.1))
			draw_line(ipos + Vector2(2, 0), ipos + Vector2(2, -6), Color(0.5, 0.2, 0.7, 0.25), 1.0)

	# Ability cooldown ring
	var cd_max = 1.0 / fire_rate
	var cd_fill = clampf(1.0 - fire_cooldown / cd_max, 0.0, 1.0)
	if cd_fill >= 1.0:
		var cd_pulse = 0.5 + sin(_time * 4.0) * 0.3
		draw_arc(Vector2.ZERO, 28.0, 0, TAU, 32, Color(0.5, 0.2, 0.7, cd_pulse * 0.4), 2.0)
	elif cd_fill > 0.0:
		draw_arc(Vector2.ZERO, 28.0, -PI / 2.0, -PI / 2.0 + TAU * cd_fill, 32, Color(0.5, 0.2, 0.7, 0.3), 2.0)
	_draw_tower_aura()

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

# === ACTIVE HERO ABILITY: Requiem Mass (stun ALL enemies 2s, 40s CD) ===
var active_ability_ready: bool = true
var active_ability_cooldown: float = 0.0
var active_ability_max_cd: float = 40.0

func activate_hero_ability() -> void:
	if not active_ability_ready:
		return
	for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if is_instance_valid(e) and e.has_method("apply_sleep"):
			e.apply_sleep(2.0)
	active_ability_ready = false
	active_ability_cooldown = active_ability_max_cd
	if is_instance_valid(_main_node):
		_main_node.spawn_floating_text(global_position + Vector2(0, -40), "REQUIEM MASS!", Color(0.9, 0.2, 0.2), 16.0, 1.5)

func get_active_ability_name() -> String:
	return "Requiem Mass"

func get_active_ability_desc() -> String:
	return "Stun ALL enemies 2s (40s CD)"

func _damage_mult() -> float:
	return (1.0 + _synergy_buffs.get("damage", 0.0) + _meta_buffs.get("damage", 0.0)) * power_damage_mult

func _range_mult() -> float:
	return 1.0 + _synergy_buffs.get("range", 0.0) + _meta_buffs.get("range", 0.0)

func _speed_mult() -> float:
	return 1.0 + _synergy_buffs.get("attack_speed", 0.0) + _meta_buffs.get("attack_speed", 0.0)

func _gold_mult() -> float:
	return 1.0 + _synergy_buffs.get("gold_bonus", 0.0) + _meta_buffs.get("gold_bonus", 0.0)
