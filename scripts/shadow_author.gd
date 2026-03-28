extends Node2D
## Shadow Author — Premium late-game tower unlocked by completing levels 34-36.
## Black smoke chain attack hits multiple enemies. Upgrades increase chain count.
## Tier 1 (5000 DMG): Ink Torrent — chain +1, attacks apply ink DoT
## Tier 2 (10000 DMG): Plot Twist — chain +1, reverses enemies backward on path
## Tier 3 (15000 DMG): Ghostwriter — chain +1, summons spectral ink copies
## Tier 4 (20000 DMG): The Final Chapter — chain +2, %maxHP + execute low HP

# Base stats
var damage: float = 30.0
var fire_rate: float = 0.72
var attack_range: float = 170.0
var fire_cooldown: float = 0.0
var aim_angle: float = 0.0
var sprite_texture: Texture2D = null
var target: Node2D = null
var gold_bonus: int = 1
# Targeting priority: 0=First, 1=Last, 2=Close, 3=Strong
var targeting_priority: int = 0

# Tier 5: THE END — enemies below 30% erased, rest take 50% max HP
var _the_end_active: bool = false
var _the_end_timer: float = 40.0
var _the_end_flash: float = 0.0
var _the_end_ink_tendrils: Array = []  # [{angle, length, target_length, speed}]
var _the_end_erase_marks: Array = []  # [{pos, timer, max_timer}]

# Chain smoke attack
var _chain_count: int = 3  # Base: hits 3 enemies
var _chain_targets: Array = []  # Stores last chain hit positions for visual
var _chain_flash: float = 0.0  # Visual timer for smoke trail
const CHAIN_DAMAGE_FALLOFF: float = 0.85  # 85% damage per hop
const CHAIN_SEARCH_RANGE: float = 160.0  # Max distance to chain to next enemy

# Animation timers
var _time: float = 0.0
var _build_timer: float = 0.0
var _attack_anim: float = 0.0
var _quill_flash: float = 0.0

# Damage tracking and upgrades
var damage_dealt: float = 0.0
var upgrade_tier: int = 0
var _upgrade_flash: float = 0.0
var _upgrade_name: String = ""

# Ink Torrent ability (Tier 1) — chain attacks apply ink DoT
var _ink_dot_dps: float = 0.0  # Set on upgrade
var _ink_dot_duration: float = 3.0

# Plot Twist ability (Tier 2) — reverses enemies backward on path
var _plot_twist_timer: float = 10.0
var _plot_twist_cooldown: float = 10.0
var _plot_twist_flash: float = 0.0
var _plot_twist_count: int = 5  # How many enemies to reverse

# Ghostwriter ability (Tier 3) — summons spectral ink copies
var _ghostwriter_timer: float = 15.0
var _ghostwriter_cooldown: float = 15.0
var _ghosts: Array = []  # {pos, life, angle, attack_timer, target_pos}

# The Final Chapter ability (Tier 4) — %maxHP + execute
var _final_chapter_timer: float = 20.0
var _final_chapter_cooldown: float = 20.0
var _final_chapter_flash: float = 0.0
var _final_chapter_book_open: float = 0.0  # Animation for opening book

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

const MAX_STAT_LEVEL: int = 10  # Cap stat scaling to prevent infinite power creep
const STAT_UPGRADE_INTERVAL: float = 8000.0
const ABILITY_THRESHOLD: float = 28000.0
var stat_upgrade_level: int = 0
var ability_chosen: bool = false
var awaiting_ability_choice: bool = false
const TIER_NAMES = [
	"Ink Torrent",
	"Plot Twist",
	"Ghostwriter",
	"The Final Chapter",
	"THE END"
]
const ABILITY_DESCRIPTIONS = [
	"Chain +1, attacks apply ink DoT to all targets",
	"Chain +1, every 10s reverse 5 enemies backward",
	"Chain +1, summon 3 spectral ink warriors",
	"Chain +2, %maxHP blast + execute enemies below 15%",
	"Enemies below 30% HP erased instantly, rest take 50% max HP"
]
const TIER_COSTS = [400, 900, 1700, 3000, 4000]
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
var _main_node: Node2D = null

func _ready() -> void:
	_main_node = get_tree().get_first_node_in_group("main")
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
	if _build_timer > 0.0: _build_timer -= delta
	fire_cooldown -= delta
	_upgrade_flash = max(_upgrade_flash - delta * 0.5, 0.0)
	_attack_anim = max(_attack_anim - delta * 3.0, 0.0)
	_quill_flash = max(_quill_flash - delta * 4.0, 0.0)
	_chain_flash = max(_chain_flash - delta * 2.5, 0.0)
	_plot_twist_flash = max(_plot_twist_flash - delta * 2.0, 0.0)
	_final_chapter_flash = max(_final_chapter_flash - delta * 1.5, 0.0)
	_final_chapter_book_open = max(_final_chapter_book_open - delta * 1.0, 0.0)
	_ink_storm_flash = max(_ink_storm_flash - delta * 2.0, 0.0)
	_rewrite_reality_flash = max(_rewrite_reality_flash - delta * 2.0, 0.0)
	_the_end_flash = max(_the_end_flash - delta * 0.7, 0.0)
	target = _find_nearest_enemy()

	if target:
		var desired = global_position.angle_to_point(target.global_position) + PI
		aim_angle = lerp_angle(aim_angle, desired, 6.0 * delta)
		if fire_cooldown <= 0.0:
			_attack()
			var speed_mult_val = _speed_mult()
			if _clone_active:
				speed_mult_val *= 2.0
			fire_cooldown = maxf(1.0 / (fire_rate * speed_mult_val), 0.667)  # Cap: 1 beat at 90 BPM
			_attack_anim = 1.0
			_quill_flash = 1.0

	# Plot Twist (Tier 2+) — reverse enemies on the path
	if upgrade_tier >= 2:
		_plot_twist_timer -= delta
		if _plot_twist_timer <= 0.0 and _has_enemies_in_range():
			_plot_twist()
			_plot_twist_timer = _plot_twist_cooldown

	# Ghostwriter (Tier 3+) — spectral ink copies
	if upgrade_tier >= 3:
		_ghostwriter_timer -= delta
		if _ghostwriter_timer <= 0.0 and _has_enemies_in_range():
			_summon_ghosts()
			_ghostwriter_timer = _ghostwriter_cooldown
		_update_ghosts(delta)

	# The Final Chapter (Tier 4) — %maxHP + execute
	if upgrade_tier >= 4:
		_final_chapter_timer -= delta
		if _final_chapter_timer <= 0.0 and _has_enemies_in_range():
			_the_final_chapter()
			_final_chapter_timer = _final_chapter_cooldown

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

	# Tier 5: THE END — erase + massive damage
	if _the_end_active:
		_the_end_timer -= delta
		if _the_end_timer <= 0.0:
			_the_end_timer = 40.0
			_the_end_flash = 1.0
			_the_end_ink_tendrils.clear()
			if is_instance_valid(_main_node):
				_main_node.trigger_screen_dark(2.5, Color(0.0, 0.0, 0.0))
				_main_node.trigger_camera_shake(15.0, 1.2)
				pass  #_main_node.trigger_shockwave(global_position, 350.0, 250.0, Color(0.15, 0.05, 0.2, 0.7))
				# Dark ink lightning
				for i in range(8):
					var angle = TAU * float(i) / 8.0
					var end = global_position + Vector2(cos(angle), sin(angle)) * 180.0
					_main_node.trigger_lightning(global_position, end, Color(0.2, 0.0, 0.3), 1.5)
			# Apply THE END to all enemies
			var enemies = _main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")
			for enemy in enemies:
				if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
					continue
				var hp = enemy.health if "health" in enemy else 100.0
				var max_hp = enemy.max_health if "max_health" in enemy else 100.0
				var epos = enemy.global_position - global_position
				if hp < max_hp * 0.3:
					# Below 30% — ERASED (instakill)
					enemy.take_damage(hp + 100.0)
					_the_end_erase_marks.append({"pos": epos, "timer": 1.0, "max_timer": 1.0})
				else:
					# Above 30% — take 50% max HP damage
					enemy.take_damage(max_hp * 0.5)
					_the_end_erase_marks.append({"pos": epos, "timer": 0.6, "max_timer": 0.6})
			# Spawn ink tendrils radiating outward
			for i in range(12):
				_the_end_ink_tendrils.append({
					"angle": TAU * float(i) / 12.0 + randf_range(-0.2, 0.2),
					"length": 0.0,
					"target_length": randf_range(100.0, 200.0),
					"speed": randf_range(200.0, 350.0)
				})
		# Update ink tendrils
		for tendril in _the_end_ink_tendrils:
			tendril.length = minf(tendril.length + tendril.speed * delta, tendril.target_length)
		if _the_end_ink_tendrils.size() > 0 and _the_end_ink_tendrils[0].length >= _the_end_ink_tendrils[0].target_length:
			# All fully extended — fade after a beat
			var all_done = true
			for t in _the_end_ink_tendrils:
				if t.length < t.target_length:
					all_done = false
					break
			if all_done:
				_the_end_ink_tendrils.clear()
		# Update erase marks
		var marks_alive: Array = []
		for mark in _the_end_erase_marks:
			mark.timer -= delta
			if mark.timer > 0.0:
				marks_alive.append(mark)
		_the_end_erase_marks = marks_alive

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

# === BLACK SMOKE CHAIN ATTACK ===

func _attack() -> void:
	if not target:
		return
	if _attack_player and _attack_sounds.size() > 0 and not _is_sfx_muted():
		_attack_player.stream = _attack_sounds[_get_note_index() % _attack_sounds.size()]
		_attack_player.play()

	var eff_damage = damage * _damage_mult()
	_attack_count += 1
	_chain_targets.clear()

	# Build list of chain targets: primary + nearby enemies chaining from each hit
	var hit_enemies: Array = [target]
	_chain_targets.append(target.global_position)
	var current_dmg = eff_damage

	# Hit primary target
	if target.has_method("take_damage"):
		target.take_damage(current_dmg, "magic")
		register_damage(current_dmg)
		_apply_chain_effects(target, current_dmg)

	# Chain to additional enemies
	var last_pos = target.global_position
	for _chain_i in range(_chain_count - 1):
		current_dmg *= CHAIN_DAMAGE_FALLOFF
		var next_target = _find_chain_target(last_pos, hit_enemies)
		if next_target == null:
			break
		hit_enemies.append(next_target)
		_chain_targets.append(next_target.global_position)
		if next_target.has_method("take_damage"):
			next_target.take_damage(current_dmg, "magic")
			register_damage(current_dmg)
			_apply_chain_effects(next_target, current_dmg)
		last_pos = next_target.global_position

	_chain_flash = 1.0

	# Ability 3: Page Tear — AoE every 5th attack
	if prog_abilities[3] and _attack_count % 5 == 0:
		var aoe_range = 60.0
		for enemy in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
			if not enemy in hit_enemies and global_position.distance_to(enemy.global_position) < aoe_range + attack_range * _range_mult():
				if enemy.has_method("take_damage"):
					var aoe_dmg = eff_damage * 0.5
					enemy.take_damage(aoe_dmg, "magic")
					register_damage(aoe_dmg)

	# Gold bonus
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("add_gold"):
		var gb = int(gold_bonus * _gold_mult())
		if gb > 0 and randf() < 0.15:
			main.add_gold(gb)

func _apply_chain_effects(enemy: Node2D, dmg: float) -> void:
	# Tier 1: Ink Torrent — apply ink DoT to all chained targets
	if upgrade_tier >= 1 and is_instance_valid(enemy):
		if "dot_dps" in enemy and "dot_timer" in enemy:
			enemy.dot_dps = max(enemy.dot_dps, dmg * 0.25)
			enemy.dot_timer = max(enemy.dot_timer, _ink_dot_duration)
	# Ability 2: Corrupting Touch — 3s DoT
	if prog_abilities[2] and is_instance_valid(enemy):
		if "dot_dps" in enemy and "dot_timer" in enemy:
			enemy.dot_dps = max(enemy.dot_dps, dmg * 0.2)
			enemy.dot_timer = max(enemy.dot_timer, 3.0)
	# Ability 4: Mind Control — 5% charm
	if prog_abilities[4] and randf() < 0.05:
		if enemy.has_method("apply_charm"):
			enemy.apply_charm(3.0, 1.5)

func _find_chain_target(from_pos: Vector2, exclude: Array) -> Node2D:
	var best: Node2D = null
	var best_dist: float = CHAIN_SEARCH_RANGE
	for enemy in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if enemy in exclude:
			continue
		if enemy.has_method("is_targetable") and not enemy.is_targetable():
			continue
		var dist = from_pos.distance_to(enemy.global_position)
		if dist < best_dist:
			best = enemy
			best_dist = dist
	return best

# === TIER ABILITIES ===

# T2: Plot Twist — reverse enemies backward on the path
func _plot_twist() -> void:
	_plot_twist_flash = 1.0
	var enemies = (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies"))
	var in_range: Array = []
	var eff_range = attack_range * _range_mult() * 1.2
	for enemy in enemies:
		if is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) < eff_range:
			in_range.append(enemy)
	# Sort by progress (furthest first — most dangerous)
	in_range.sort_custom(func(a, b): return a.progress_ratio > b.progress_ratio)
	var count = mini(_plot_twist_count, in_range.size())
	for i in range(count):
		var enemy = in_range[i]
		if is_instance_valid(enemy) and "progress" in enemy:
			var rewrite_amount = enemy.progress * 0.25  # Send back 25%
			enemy.progress -= rewrite_amount
			enemy.progress = max(0.0, enemy.progress)
		if is_instance_valid(enemy) and enemy.has_method("apply_slow"):
			enemy.apply_slow(0.4, 2.0)  # Also slow them after reversal
	if not _is_sfx_muted():
		_ability_player.play()
	if is_instance_valid(_main_node):
		_main_node.spawn_floating_text(global_position + Vector2(0, -50), "PLOT TWIST!", Color(0.7, 0.3, 0.9), 14.0, 1.5)

# T3: Ghostwriter — summon 3 spectral ink warrior copies
func _summon_ghosts() -> void:
	_ghosts.clear()
	for i in range(3):
		var angle = TAU * float(i) / 3.0 + randf() * 0.5
		_ghosts.append({
			"pos": global_position + Vector2(cos(angle), sin(angle)) * 50.0,
			"life": 10.0,
			"angle": angle,
			"attack_timer": 0.0,
			"target_pos": Vector2.ZERO,
			"attacking": false,
		})
	if not _is_sfx_muted():
		_ability_player.play()
	if is_instance_valid(_main_node):
		_main_node.spawn_floating_text(global_position + Vector2(0, -50), "GHOSTWRITER!", Color(0.5, 0.8, 1.0), 14.0, 1.5)

func _update_ghosts(delta: float) -> void:
	var to_remove: Array = []
	for i in range(_ghosts.size()):
		var g = _ghosts[i]
		g["life"] -= delta
		if g["life"] <= 0.0:
			to_remove.append(i)
			continue
		g["attack_timer"] -= delta
		if g["attack_timer"] <= 0.0:
			# Find and attack nearest enemy
			var nearest: Node2D = null
			var nearest_dist: float = 150.0
			for enemy in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
				if enemy.has_method("is_targetable") and not enemy.is_targetable():
					continue
				var dist = Vector2(g["pos"]).distance_to(enemy.global_position)
				if dist < nearest_dist:
					nearest = enemy
					nearest_dist = dist
			if nearest and nearest.has_method("take_damage"):
				var ghost_dmg = damage * 0.5 * _damage_mult()
				nearest.take_damage(ghost_dmg, "magic")
				register_damage(ghost_dmg)
				g["target_pos"] = nearest.global_position
				g["attacking"] = true
				g["angle"] = Vector2(g["pos"]).angle_to_point(nearest.global_position) + PI
				# Ghosts also apply ink DoT
				if "dot_dps" in nearest and "dot_timer" in nearest:
					nearest.dot_dps = max(nearest.dot_dps, ghost_dmg * 0.15)
					nearest.dot_timer = max(nearest.dot_timer, 2.0)
			else:
				g["attacking"] = false
			g["attack_timer"] = 0.8  # Fast attack rate
		# Orbit around tower when not attacking
		g["angle"] += delta * 2.0
		var orbit_r = 55.0 + sin(_time * 1.5 + float(i) * 2.0) * 10.0
		g["pos"] = global_position + Vector2(cos(g["angle"]), sin(g["angle"])) * orbit_r
	for idx in range(to_remove.size() - 1, -1, -1):
		_ghosts.remove_at(to_remove[idx])

# T4: The Final Chapter — %maxHP blast + execute low HP enemies
func _the_final_chapter() -> void:
	_final_chapter_flash = 1.0
	_final_chapter_book_open = 1.5
	var eff_range = attack_range * _range_mult() * 1.8
	for enemy in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) < eff_range:
			if enemy.has_method("take_damage"):
				# Deal 12% of max HP as true damage
				var max_hp = enemy.max_health if "max_health" in enemy else 100.0
				var pct_dmg = max_hp * 0.12
				# Plus base damage multiplied
				var base_dmg = damage * 3.0 * _damage_mult()
				enemy.take_damage(pct_dmg + base_dmg, "true")
				register_damage(pct_dmg + base_dmg)
				# Execute enemies below 15% HP
				var hp_ratio = enemy.health / max_hp if max_hp > 0.0 else 1.0
				if hp_ratio < 0.15 and hp_ratio > 0.0:
					enemy.take_damage(enemy.health + 1.0, "true")
					register_damage(enemy.health)
	if not _is_sfx_muted():
		_ability_player.play()
	if is_instance_valid(_main_node):
		_main_node.spawn_floating_text(global_position + Vector2(0, -55), "THE FINAL CHAPTER!", Color(0.9, 0.2, 0.1), 16.0, 2.0)

# === PROGRESSIVE ABILITIES ===

func _shadow_step() -> void:
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
	for enemy in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if global_position.distance_to(enemy.global_position) < eff_range:
			if enemy.has_method("take_damage"):
				enemy.take_damage(storm_dmg, "magic")
				register_damage(storm_dmg)
	if not _is_sfx_muted():
		_ability_player.play()

func _rewrite_reality() -> void:
	_rewrite_reality_flash = 1.0
	var effect = randi() % 4
	match effect:
		0:  # Mass slow
			for enemy in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
				if enemy.has_method("apply_slow"):
					enemy.apply_slow(0.3, 5.0)
		1:  # Mass damage
			var burst_dmg = damage * 3.0 * _damage_mult()
			for enemy in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
				if enemy.has_method("take_damage"):
					enemy.take_damage(burst_dmg, "magic")
					register_damage(burst_dmg)
		2:  # Gold bonus
			var main = get_tree().get_first_node_in_group("main")
			if main and main.has_method("add_gold"):
				main.add_gold(50)
		3:  # Execute low HP enemies
			for enemy in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
				if enemy.health / enemy.max_health < 0.2:
					if enemy.has_method("take_damage"):
						enemy.take_damage(enemy.health + 1.0, "true")
	if not _is_sfx_muted():
		_ability_player.play()

func register_kill() -> void:
	_upgrade_flash = 0.5
	_upgrade_name = "Kill!"

func register_damage(amount: float) -> void:
	damage_dealt += amount
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("register_tower_damage"):
		main.register_tower_damage(main.TowerType.SHADOW_AUTHOR, amount)
	# Stat upgrades
	var new_level = int(damage_dealt / STAT_UPGRADE_INTERVAL)
	if new_level > stat_upgrade_level and stat_upgrade_level < MAX_STAT_LEVEL:
		stat_upgrade_level = new_level
		damage += 2.0
		fire_rate += 0.01
		attack_range += 1.5
	# Tier upgrades — each tier adds chain count
	if upgrade_tier < 4:
		var thresholds = [5000.0, 10000.0, 15000.0, 20000.0]
		if damage_dealt >= thresholds[upgrade_tier]:
			upgrade_tier += 1
			_upgrade_flash = 1.0
			_upgrade_name = TIER_NAMES[upgrade_tier - 1]
			_attack_sounds = _attack_sounds_by_tier[mini(upgrade_tier, _attack_sounds_by_tier.size() - 1)]
			# Increase chain count per tier
			match upgrade_tier:
				1: _chain_count = 4   # Ink Torrent: +1
				2: _chain_count = 5   # Plot Twist: +1
				3: _chain_count = 6   # Ghostwriter: +1
				4: _chain_count = 8   # The Final Chapter: +2
			if not _is_sfx_muted():
				_upgrade_player.play()

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

func get_tower_display_name() -> String:
	return "Shadow Author"

func purchase_upgrade() -> bool:
	if upgrade_tier >= TIER_COSTS.size():
		return false
	var cost = TIER_COSTS[upgrade_tier]
	var main_node = get_tree().get_first_node_in_group("main")
	if not main_node or not main_node.spend_gold(cost):
		return false
	upgrade_tier += 1
	_apply_upgrade(upgrade_tier)
	_upgrade_flash = 3.0
	_upgrade_name = TIER_NAMES[upgrade_tier - 1]
	_attack_sounds = _attack_sounds_by_tier[mini(upgrade_tier, _attack_sounds_by_tier.size() - 1)]
	if _upgrade_player and not _is_sfx_muted(): _upgrade_player.play()
	return true

func _apply_upgrade(tier: int) -> void:
	match tier:
		1:  # Ink Torrent — chain +1, ink DoT
			_chain_count = 4
			_ink_dot_dps = damage * 0.25
			damage = 32.0
			fire_rate = 0.72
			attack_range = 174.0
		2:  # Plot Twist — chain +1, reverse enemies
			_chain_count = 5
			damage = 34.0
			fire_rate = 0.72
			attack_range = 178.0
			gold_bonus = 2
		3:  # Ghostwriter — chain +1, spectral copies
			_chain_count = 6
			damage = 34.0
			fire_rate = 0.72
			attack_range = 178.0
			gold_bonus = 2
		4:  # The Final Chapter — chain +2, %maxHP + execute
			_chain_count = 8
			damage = 36.0
			fire_rate = 0.72
			attack_range = 182.0
			gold_bonus = 3
		5:  # THE END — enemies below 30% erased, rest take 50% max HP
			_the_end_active = true
			# No stat boost — the ultimate ability IS the reward

func _generate_tier_sounds() -> void:
	var mix_rate := 44100
	var melody := [146.83, 146.83, 220.00, 220.00, 174.61, 174.61, 196.00, 196.00]
	# D3 D3 A3 A3 F3 F3 G3 G3 -- monastic chant in intervals
	_attack_sounds_by_tier = []
	# Vowel formants: [F1, F2, F3] Hz (approximate)
	var vowels := [[730.0, 1090.0, 2440.0], [570.0, 840.0, 2410.0], [300.0, 870.0, 2240.0]]
	for tier in range(5):
		var tier_sounds: Array = []
		var dur := 0.55 + tier * 0.06
		var vol := 0.20 + tier * 0.015
		for note_idx in melody.size():
			var freq: float = melody[note_idx]
			var total := int(mix_rate * dur)
			var samples := PackedFloat32Array()
			samples.resize(total)
			# Pick vowel based on note position
			var vowel = vowels[note_idx % vowels.size()]
			for i in total:
				var t := float(i) / float(mix_rate)
				var env := minf(t * 6.0, 1.0) * (1.0 - maxf(t - dur * 0.65, 0.0) / (dur * 0.35))
				env = maxf(env, 0.0)
				# Glottal source: rich harmonics (sawtooth-ish)
				var s := 0.0
				for h in range(1, 10):
					var amp := 1.0 / float(h)
					s += sin(t * freq * float(h) * TAU) * amp
				s *= 0.08
				# Formant emphasis: boost harmonics near formant frequencies
				var formant_boost := 0.0
				for f_idx in vowel.size():
					var formant_f: float = vowel[f_idx]
					# Find nearest harmonic to formant
					var h_near := roundf(formant_f / freq)
					if h_near >= 1.0 and h_near <= 12.0:
						formant_boost += sin(t * freq * h_near * TAU) * 0.03 / float(f_idx + 1)
				s += formant_boost
				# Slight vibrato
				s *= 1.0 + sin(t * 5.0 * TAU) * 0.03
				samples[i] = clampf(s * env * vol, -1.0, 1.0)
			var att_len := mini(int(0.03 * mix_rate), total)
			for i in att_len:
				samples[i] *= float(i) / float(att_len)
			var rel_start := maxi(total - int(0.04 * mix_rate), 0)
			for i in range(rel_start, total):
				samples[i] *= 1.0 - float(i - rel_start) / float(total - rel_start)
			tier_sounds.append(_samples_to_wav(samples, mix_rate))
		_attack_sounds_by_tier.append(tier_sounds)
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

# === ACTIVE HERO ABILITY: Narrative Collapse ===
# 10x damage to ALL enemies + mass slow + mass reverse + screen flash
var active_ability_ready: bool = true
var active_ability_cooldown: float = 0.0
var active_ability_max_cd: float = 45.0
var _narrative_collapse_flash: float = 0.0

func activate_hero_ability() -> void:
	if not active_ability_ready:
		return
	_narrative_collapse_flash = 1.5
	var total_hero_dmg: float = 0.0
	for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if is_instance_valid(e) and e.has_method("take_damage"):
			var dmg = damage * 10.0 * _damage_mult()
			e.take_damage(dmg, "magic")
			register_damage(dmg)
			total_hero_dmg += dmg
			# Mass slow
			if e.has_method("apply_slow"):
				e.apply_slow(0.3, 4.0)
			# Mass reverse — push back 20% on path
			if is_instance_valid(e) and "progress" in e:
				e.progress = max(0.0, e.progress - e.progress * 0.2)
	active_ability_ready = false
	active_ability_cooldown = active_ability_max_cd
	if is_instance_valid(_main_node):
		_main_node.spawn_floating_text(global_position + Vector2(0, -40), "NARRATIVE COLLAPSE!", Color(0.9, 0.1, 0.15), 18.0, 2.0)
		_main_node.spawn_floating_text(global_position + Vector2(0, -60), "\"THE END\"", Color(0.6, 0.1, 0.8), 22.0, 2.5)

func get_active_ability_name() -> String:
	return "Narrative Collapse"

func get_active_ability_desc() -> String:
	return "10x DMG ALL + slow + reverse (45s CD)"

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
	# Build animation — elastic scale-in
	if _build_timer > 0.0:
		var bt = 1.0 - clampf(_build_timer / 0.5, 0.0, 1.0)
		var elastic = 1.0 + sin(bt * PI * 2.5) * 0.3 * (1.0 - bt)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(elastic, elastic))

	# === 1. SELECTION RING ===
	if is_selected:
		var pulse = (sin(_time * 3.0) + 1.0) * 0.5
		var ring_alpha = 0.5 + pulse * 0.3
		draw_arc(Vector2.ZERO, 40.0, 0, TAU, 28, Color(0.5, 0.2, 0.8, ring_alpha), 2.5)
		draw_arc(Vector2.ZERO, 43.0, 0, TAU, 28, Color(0.5, 0.2, 0.8, ring_alpha * 0.4), 1.5)

	# === 2. RANGE ARC ===
	pass  #draw_arc(Vector2.ZERO, attack_range, 0, TAU, 36, Color(1, 1, 1, 0.06), 1.0)

	# === 3. AIM DIRECTION ===
	var dir = Vector2.from_angle(aim_angle)

	# === 4. IDLE ANIMATION ===
	var float_bob = sin(_time * 1.5) * 3.0
	var sway = sin(_time * 0.9) * 2.5
	var breathe = sin(_time * 1.2) * 2.0
	var body_offset = Vector2(sway, -float_bob - breathe)

	# === 5. UPGRADE FLASH ===
	if _upgrade_flash > 0.0:
		pass  #draw_arc(Vector2.ZERO, 60.0 + _upgrade_flash * 20.0, 0, TAU, 24, Color(0.4, 0.15, 0.6, _upgrade_flash * 0.25), 6.0)

	# === 6. NARRATIVE COLLAPSE FLASH ===
	if _narrative_collapse_flash > 0.0:
		var nc_r = 80.0 + (1.5 - _narrative_collapse_flash) * 200.0
		var nc_a = _narrative_collapse_flash / 1.5
		pass  #draw_arc(Vector2.ZERO, nc_r, 0, TAU, 28, Color(0.8, 0.1, 0.2, nc_a * 0.6), 5.0)
		# Radiating dark tendrils
		for ni in range(8):
			var na = TAU * float(ni) / 12.0 + _time * 0.5
			var n_inner = Vector2.from_angle(na) * 30.0
			var n_outer = Vector2.from_angle(na) * nc_r
			draw_line(n_inner, n_outer, Color(0.05, 0.0, 0.08, nc_a * 0.4), 2.0)
		_narrative_collapse_flash = max(_narrative_collapse_flash - 0.016 * 1.0, 0.0)

	# === 7. FINAL CHAPTER FLASH ===
	if _final_chapter_flash > 0.0:
		var fc_r = 60.0 + (1.0 - _final_chapter_flash) * 150.0
		pass  #draw_circle(Vector2.ZERO, fc_r, Color(0.15, 0.02, 0.02, _final_chapter_flash * 0.15))
		pass  #draw_arc(Vector2.ZERO, fc_r, 0, TAU, 32, Color(0.9, 0.15, 0.1, _final_chapter_flash * 0.4), 2.5)
	# Animated open book visual
	if _final_chapter_book_open > 0.0:
		var book_a = clampf(_final_chapter_book_open / 1.5, 0.0, 1.0)
		var book_y = body_offset.y - 65.0
		var book_w = 30.0 * book_a
		# Left page
		draw_rect(Rect2(-book_w + body_offset.x, book_y, book_w, 20.0), Color(0.12, 0.06, 0.02, book_a * 0.9))
		# Right page
		draw_rect(Rect2(body_offset.x, book_y, book_w, 20.0), Color(0.14, 0.07, 0.02, book_a * 0.9))
		# Pages — cream colored
		draw_rect(Rect2(-book_w + 2 + body_offset.x, book_y + 2, book_w - 4, 16.0), Color(0.9, 0.85, 0.7, book_a * 0.8))
		draw_rect(Rect2(body_offset.x + 2, book_y + 2, book_w - 4, 16.0), Color(0.9, 0.85, 0.7, book_a * 0.8))
		# Spine
		draw_line(Vector2(body_offset.x, book_y), Vector2(body_offset.x, book_y + 20.0), Color(0.08, 0.04, 0.01, book_a), 2.0)
		# Red glow from pages
		draw_circle(Vector2(body_offset.x, book_y + 10.0), 15.0 * book_a, Color(0.8, 0.1, 0.05, book_a * 0.2))
		# Ink text lines on pages
		for li in range(3):
			var ly = book_y + 4.0 + float(li) * 5.0
			draw_line(Vector2(-book_w + 5 + body_offset.x, ly), Vector2(-3 + body_offset.x, ly), Color(0.2, 0.1, 0.05, book_a * 0.5), 1.0)
			draw_line(Vector2(body_offset.x + 4, ly), Vector2(body_offset.x + book_w - 4, ly), Color(0.2, 0.1, 0.05, book_a * 0.5), 1.0)

	# === 8. PLOT TWIST FLASH ===
	if _plot_twist_flash > 0.0:
		pass  #draw_circle(body_offset, 40.0, Color(0.5, 0.2, 0.8, _plot_twist_flash * 0.15))
		# Swirling reverse arrows
		for i in range(5):
			var pa = TAU * float(i) / 5.0 + _time * -4.0  # Counter-clockwise = reverse
			var pd = 25.0 + (1.0 - _plot_twist_flash) * 30.0
			var arrow_pos = body_offset + Vector2(cos(pa) * pd, sin(pa) * pd * 0.6)
			var arrow_dir = Vector2(-sin(pa), cos(pa) * 0.6).normalized()
			draw_line(arrow_pos, arrow_pos + arrow_dir * 6.0, Color(0.8, 0.4, 1.0, _plot_twist_flash * 0.7), 2.0)
			draw_line(arrow_pos + arrow_dir * 6.0, arrow_pos + arrow_dir * 4.0 + Vector2(2, -2), Color(0.8, 0.4, 1.0, _plot_twist_flash * 0.5), 1.5)

	# === 9. INK STORM FLASH ===
	if _ink_storm_flash > 0.0:
		for i in range(8):
			var angle = TAU * float(i) / 8.0 + _time * 2.0
			var dist = 30.0 + (1.0 - _ink_storm_flash) * 60.0
			draw_circle(Vector2(cos(angle) * dist, sin(angle) * dist) + body_offset, 4.0, Color(0.1, 0.05, 0.15, _ink_storm_flash * 0.5))

	# === 10. REWRITE REALITY FLASH ===
	if _rewrite_reality_flash > 0.0:
		pass  #draw_circle(body_offset, 50.0, Color(0.6, 0.3, 0.9, _rewrite_reality_flash * 0.15))
		for i in range(6):
			var angle = TAU * float(i) / 6.0 + _time * 3.0
			var rune_pos = body_offset + Vector2(cos(angle), sin(angle)) * 35.0
			draw_circle(rune_pos, 3.0, Color(0.8, 0.5, 1.0, _rewrite_reality_flash * 0.6))

	# === 11. DARK AURA BASE ===
	_fill_ellipse(body_offset + Vector2(0, 22), Vector2(18, 6), Color(0.05, 0.02, 0.1, 0.5))
	for i in range(6):
		var ta = TAU * float(i) / 6.0 + _time * 1.2
		var td = 12.0 + sin(_time * 3.0 + float(i)) * 4.0
		var tx = cos(ta) * td
		var ty = 18.0 + sin(ta) * 5.0
		draw_circle(body_offset + Vector2(tx, ty), 2.5, Color(0.1, 0.03, 0.15, 0.35))

	# === SPRITE RENDERING (animated — dark & ethereal) ===
	if sprite_texture:
		var _ss = Vector2(sprite_texture.get_width(), sprite_texture.get_height())
		var _sf = 96.0 / _ss.y
		var _sd = _ss * _sf
		var breathe_scl = 1.0 + sin(_time * 1.8) * 0.022
		var sway_rot = sin(_time * 1.0) * 0.028
		var s_aim_lean = sin(aim_angle) * 0.045
		var recoil_off = Vector2.ZERO
		var atk_scl = Vector2.ONE
		if _attack_anim > 0.0:
			var tier_r = 1.0 + float(upgrade_tier) * 0.15
			var rt = _attack_anim * _attack_anim
			recoil_off = -Vector2.from_angle(aim_angle) * rt * 3.5 * tier_r
			var sq = clampf(_attack_anim * 2.5, 0.0, 1.0)
			atk_scl = Vector2(1.0 + sq * (0.10 + float(upgrade_tier) * 0.02), 1.0 - sq * (0.07 + float(upgrade_tier) * 0.015))
		var total_rot = sway_rot + s_aim_lean
		var total_scl = Vector2(breathe_scl, breathe_scl) * atk_scl
		var _fl = cos(aim_angle) < 0.0
		if _fl:
			total_scl.x *= -1.0
			total_rot *= -1.0
		var anchor = body_offset + Vector2(0, 10.0) + recoil_off
		draw_set_transform(anchor, total_rot, total_scl)
		draw_texture_rect(sprite_texture, Rect2(-_sd.x / 2.0, -_sd.y, _sd.x, _sd.y), false)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	if not sprite_texture:
		# === 12. CLOAK/ROBE BODY ===
		var cloak_pts = PackedVector2Array()
		cloak_pts.append(body_offset + Vector2(-10, -28))
		cloak_pts.append(body_offset + Vector2(-13, -10))
		cloak_pts.append(body_offset + Vector2(-15, 8))
		cloak_pts.append(body_offset + Vector2(-12, 20 + sin(_time * 2.0) * 2.0))
		cloak_pts.append(body_offset + Vector2(-5, 22 + sin(_time * 2.5 + 1.0) * 1.5))
		cloak_pts.append(body_offset + Vector2(0, 21 + sin(_time * 3.0) * 1.0))
		cloak_pts.append(body_offset + Vector2(5, 22 + sin(_time * 2.5 + 2.0) * 1.5))
		cloak_pts.append(body_offset + Vector2(12, 20 + sin(_time * 2.0 + 1.5) * 2.0))
		cloak_pts.append(body_offset + Vector2(15, 8))
		cloak_pts.append(body_offset + Vector2(13, -10))
		cloak_pts.append(body_offset + Vector2(10, -28))
		var cloak_color = Color(0.06, 0.02, 0.1, 0.9)
		if upgrade_tier >= 4:
			cloak_color = Color(0.08, 0.03, 0.14, 0.95)
		draw_colored_polygon(cloak_pts, cloak_color)
		for i in range(cloak_pts.size() - 1):
			draw_line(cloak_pts[i], cloak_pts[i + 1], Color(0.25, 0.1, 0.35, 0.4), 1.0)

		# === 13. HOOD ===
		var hood_pts = PackedVector2Array()
		hood_pts.append(body_offset + Vector2(-12, -27))
		hood_pts.append(body_offset + Vector2(0, -42))
		hood_pts.append(body_offset + Vector2(12, -27))
		hood_pts.append(body_offset + Vector2(7, -22))
		hood_pts.append(body_offset + Vector2(-7, -22))
		draw_colored_polygon(hood_pts, Color(0.04, 0.01, 0.08, 0.95))
		draw_line(hood_pts[0], hood_pts[1], Color(0.3, 0.12, 0.4, 0.5), 1.0)
		draw_line(hood_pts[1], hood_pts[2], Color(0.3, 0.12, 0.4, 0.5), 1.0)

		# === 14. HOOD INTERIOR — pure darkness, no face ===
		draw_colored_polygon(PackedVector2Array([
			body_offset + Vector2(-7, -22), body_offset + Vector2(0, -38),
			body_offset + Vector2(7, -22)
		]), Color(0.0, 0.0, 0.0))
		var red_pulse = 0.6 + sin(_time * 2.5) * 0.4
		draw_circle(body_offset + Vector2(0, -28), 1.2, Color(0.9, 0.08, 0.02, red_pulse))
		draw_circle(body_offset + Vector2(0, -28), 3.0, Color(0.7, 0.04, 0.01, red_pulse * 0.25))

		# === 15. GLOWING RED WAND (tier-scaling attack burst) ===
		var wand_base = body_offset + Vector2(13, -8)
		var wand_top = body_offset + Vector2(18, -38)
		if _attack_anim > 0.0:
			var tier_scale = 1.0 + float(upgrade_tier) * 0.25
			wand_top += Vector2(sin(_attack_anim * PI * 2.0) * 5.0 * tier_scale, 0)
			# Dark energy at wand tip — small glow + tendrils
			var burst_alpha = _attack_anim * 0.6
			# Small wand tip glow
			draw_circle(wand_top, 4.0 * tier_scale, Color(0.95, 0.15, 0.08, burst_alpha * 0.35))
			draw_circle(wand_top, 6.0 * tier_scale, Color(0.15, 0.02, 0.08, burst_alpha * 0.15))
			# Dark tendrils shooting toward target from wand tip
			var tendril_ct = 2 + upgrade_tier
			for ti in range(tendril_ct):
				var t_spread = (float(ti) - float(tendril_ct) / 2.0) * 0.25
				var t_dir = Vector2.from_angle(aim_angle + t_spread)
				var t_len = (8.0 + sin(_time * 10.0 + float(ti) * 2.5) * 3.0) * tier_scale
				var t_end = wand_top + t_dir * t_len
				draw_line(wand_top, t_end, Color(0.6, 0.03, 0.02, burst_alpha * 0.5), 1.8)
				draw_circle(t_end, 1.5, Color(0.95, 0.15, 0.08, burst_alpha * 0.4))
		draw_line(wand_base, wand_top, Color(0.7, 0.06, 0.03, red_pulse), 2.0)
		draw_line(wand_base, wand_top, Color(0.9, 0.12, 0.05, red_pulse * 0.4), 3.5)
		var wand_dir_v = (wand_top - wand_base).normalized()
		var wand_perp = Vector2(-wand_dir_v.y, wand_dir_v.x)
		for zi in range(5):
			var zt = 0.15 + float(zi) * 0.16
			var zp = wand_base.lerp(wand_top, zt)
			var zag_offset = (3.0 if zi % 2 == 0 else -3.0)
			var zp2 = wand_base.lerp(wand_top, zt + 0.08)
			draw_line(zp + wand_perp * zag_offset, zp2 + wand_perp * (-zag_offset), Color(0.95, 0.2, 0.08, red_pulse * 0.7), 1.2)
		for gi in range(3):
			var gt = 0.2 + float(gi) * 0.3
			var gp = wand_base.lerp(wand_top, gt)
			draw_circle(gp, 4.0 + sin(_time * 2.5 + float(gi)) * 1.5, Color(0.7, 0.04, 0.0, 0.06 * red_pulse))
		draw_circle(wand_top, 2.5, Color(0.95, 0.12, 0.02, red_pulse))
		draw_circle(wand_top, 5.0, Color(0.8, 0.06, 0.01, red_pulse * 0.3))
		draw_circle(wand_top, 8.0, Color(0.6, 0.03, 0.0, red_pulse * 0.1))
		if _quill_flash > 0.0:
			var drip_pos = wand_top + Vector2(0, -2 + (1.0 - _quill_flash) * -8.0)
			draw_circle(drip_pos, 2.0 * _quill_flash, Color(0.08, 0.02, 0.12, _quill_flash * 0.7))

		# === 16. SLEEVE VOIDS ===
		var lh = body_offset + Vector2(-12 + sin(_time * 1.8) * 2.0, -12)
		draw_circle(lh, 3.0, Color(0.01, 0.005, 0.015, 0.8))

		# === 17. BLACK SMOKE CHAIN VISUAL ===
		if _chain_flash > 0.0 and _chain_targets.size() >= 2:
			var smoke_alpha = _chain_flash * 0.7
			# Draw smoke tendrils between chained enemies
			var wand_tip_global = global_position + wand_top
			var prev_pos = _chain_targets[0] - global_position  # First target in local coords
			# Smoke from wand to first target
			_draw_smoke_tendril(wand_top, prev_pos, smoke_alpha, 3.0)
			# Chain between targets
			for ci in range(1, _chain_targets.size()):
				var next_pos = _chain_targets[ci] - global_position
				var chain_alpha = smoke_alpha * pow(0.85, float(ci))
				_draw_smoke_tendril(prev_pos, next_pos, chain_alpha, 2.5 - float(ci) * 0.2)
				# Impact burst at each chain point
				draw_circle(next_pos, 6.0 * _chain_flash, Color(0.08, 0.02, 0.12, chain_alpha * 0.5))
				draw_circle(next_pos, 3.0 * _chain_flash, Color(0.2, 0.05, 0.25, chain_alpha * 0.8))
				prev_pos = next_pos
			# Impact on first target
			var first_local = _chain_targets[0] - global_position
			draw_circle(first_local, 8.0 * _chain_flash, Color(0.1, 0.02, 0.15, smoke_alpha * 0.4))
			draw_circle(first_local, 4.0 * _chain_flash, Color(0.3, 0.08, 0.35, smoke_alpha * 0.7))
		elif _chain_flash > 0.0 and _chain_targets.size() == 1:
			# Single target hit visual
			var hit_local = _chain_targets[0] - global_position
			_draw_smoke_tendril(wand_top, hit_local, _chain_flash * 0.7, 3.0)
			draw_circle(hit_local, 8.0 * _chain_flash, Color(0.1, 0.02, 0.15, _chain_flash * 0.5))

		# === 18. GHOSTWRITER COPIES ===
		for g in _ghosts:
			var gp = Vector2(g["pos"]) - global_position
			var ghost_alpha = clampf(g["life"] / 2.0, 0.0, 1.0)
			# Spectral ink warrior — translucent hooded figure with blue-purple glow
			# Body
			draw_circle(gp + Vector2(0, 2), 6.0, Color(0.08, 0.04, 0.15, ghost_alpha * 0.5))
			# Mini cloak
			var gc_pts = PackedVector2Array()
			gc_pts.append(gp + Vector2(-5, -6))
			gc_pts.append(gp + Vector2(-6, 2))
			gc_pts.append(gp + Vector2(-4, 8))
			gc_pts.append(gp + Vector2(0, 9))
			gc_pts.append(gp + Vector2(4, 8))
			gc_pts.append(gp + Vector2(6, 2))
			gc_pts.append(gp + Vector2(5, -6))
			draw_colored_polygon(gc_pts, Color(0.05, 0.02, 0.1, ghost_alpha * 0.6))
			# Hood
			var gh_pts = PackedVector2Array()
			gh_pts.append(gp + Vector2(-5, -5))
			gh_pts.append(gp + Vector2(0, -14))
			gh_pts.append(gp + Vector2(5, -5))
			draw_colored_polygon(gh_pts, Color(0.04, 0.01, 0.08, ghost_alpha * 0.7))
			# Glowing eyes — cyan/blue for ghosts
			draw_circle(gp + Vector2(-1.5, -7), 1.0, Color(0.3, 0.6, 1.0, ghost_alpha * 0.9))
			draw_circle(gp + Vector2(1.5, -7), 1.0, Color(0.3, 0.6, 1.0, ghost_alpha * 0.9))
			# Spectral glow aura
			draw_circle(gp, 10.0, Color(0.2, 0.3, 0.7, ghost_alpha * 0.1))
			# Attack beam to target
			if g["attacking"] and g["target_pos"] != Vector2.ZERO:
				var tgt_local = Vector2(g["target_pos"]) - global_position
				draw_line(gp, tgt_local, Color(0.3, 0.5, 0.9, ghost_alpha * 0.3), 1.5)

	# === 19. SHIELD INDICATOR ===
	if _shield_active:
		var shield_pulse = (sin(_time * 5.0) + 1.0) * 0.5
		pass  #draw_arc(body_offset, 20.0 + shield_pulse * 3.0, 0, TAU, 24, Color(0.4, 0.2, 0.7, 0.3 + shield_pulse * 0.2), 2.0)

	# === 20. CLONE INDICATOR ===
	if _clone_active:
		var ghost_offset1 = body_offset + Vector2(-8, 0)
		var ghost_offset2 = body_offset + Vector2(8, 0)
		draw_circle(ghost_offset1, 8.0, Color(0.15, 0.05, 0.2, 0.2))
		draw_circle(ghost_offset2, 8.0, Color(0.15, 0.05, 0.2, 0.2))

	pass # Tier evolution effects removed

	# === 21. CHAIN COUNT INDICATOR ===
	if upgrade_tier > 0:
		# Show chain count as connected dots
		var chain_start_x = -float(_chain_count - 1) * 2.0
		for i in range(_chain_count):
			var dot_x = chain_start_x + float(i) * 4.0
			var dot_color = Color(0.6, 0.3, 0.9, 0.7) if i < 3 else Color(0.9, 0.4, 0.2, 0.7)
			draw_circle(body_offset + Vector2(dot_x, 26), 1.2, dot_color)
			if i > 0:
				draw_line(body_offset + Vector2(dot_x - 4.0, 26), body_offset + Vector2(dot_x, 26), Color(0.4, 0.15, 0.5, 0.3), 0.5)

	# === UPGRADE NAME ===
	if _upgrade_flash > 0.0 and _upgrade_name != "":
		var font = ThemeDB.fallback_font
		draw_string(font, body_offset + Vector2(-30, -50), _upgrade_name, HORIZONTAL_ALIGNMENT_CENTER, 60, 10, Color(0.8, 0.6, 1.0, _upgrade_flash))

	# Idle ambient particles — ink drips
	if target == null:
		for ip in range(3):
			var ix = -8.0 + float(ip) * 8.0
			var iy = fmod(_time * 20.0 + float(ip) * 15.0, 40.0) - 20.0
			var drip_alpha = 0.35 * (1.0 - abs(iy) / 20.0)
			draw_circle(Vector2(ix, iy), 1.5, Color(0.1, 0.05, 0.15, drip_alpha))
			draw_line(Vector2(ix, iy), Vector2(ix, iy + 3), Color(0.1, 0.05, 0.15, drip_alpha * 0.6), 1.0)

	# Ability cooldown ring
	var cd_max = 1.0 / fire_rate
	var cd_fill = clampf(1.0 - fire_cooldown / cd_max, 0.0, 1.0)
	if cd_fill >= 1.0:
		var cd_pulse = 0.5 + sin(_time * 4.0) * 0.3
		pass  #draw_arc(Vector2.ZERO, 28.0, 0, TAU, 32, Color(0.3, 0.15, 0.5, cd_pulse * 0.4), 2.0)
	elif cd_fill > 0.0:
		draw_arc(Vector2.ZERO, 28.0, -PI / 2.0, -PI / 2.0 + TAU * cd_fill, 32, Color(0.3, 0.15, 0.5, 0.3), 2.0)

	# === TIER 5: THE END VFX ===
	if _the_end_active:
		# Ink tendrils radiating from tower
		for tendril in _the_end_ink_tendrils:
			if tendril.length > 0.0:
				var t_end = Vector2(cos(tendril.angle), sin(tendril.angle)) * tendril.length
				# Dark ink main line
				draw_line(Vector2.ZERO, t_end, Color(0.05, 0.0, 0.1, 0.6), 3.0)
				# Wispy edges
				var mid = t_end * 0.5
				var perp = Vector2(-sin(tendril.angle), cos(tendril.angle))
				var wisp = sin(_time * 5.0 + tendril.angle * 3.0) * 6.0
				draw_line(mid + perp * wisp, mid - perp * wisp, Color(0.1, 0.0, 0.15, 0.3), 1.5)
				# Tip drip
				draw_circle(t_end, 3.0 + sin(_time * 8.0 + tendril.angle) * 1.5, Color(0.08, 0.0, 0.12, 0.5))
		# Erase marks — crossed-out circles at enemy positions
		for mark in _the_end_erase_marks:
			var m_alpha = clampf(mark.timer / mark.max_timer, 0.0, 1.0)
			var mpos = mark.pos
			var m_size = 10.0 + (1.0 - m_alpha) * 15.0
			if mark.max_timer > 0.8:
				# Full erase (instakill) — big red X with dissolve
				draw_line(mpos + Vector2(-m_size, -m_size), mpos + Vector2(m_size, m_size), Color(0.8, 0.05, 0.1, m_alpha * 0.7), 3.0)
				draw_line(mpos + Vector2(m_size, -m_size), mpos + Vector2(-m_size, m_size), Color(0.8, 0.05, 0.1, m_alpha * 0.7), 3.0)
				# Dissolving ink particles
				for pi in range(6):
					var p_angle = _time * 4.0 + float(pi) * TAU / 6.0
					var p_r = m_size * (1.0 - m_alpha) * 2.0
					var ppos = mpos + Vector2(cos(p_angle) * p_r, sin(p_angle) * p_r)
					draw_circle(ppos, 1.5, Color(0.1, 0.0, 0.15, m_alpha * 0.4))
			else:
				# Damage mark — ink slash
				draw_line(mpos + Vector2(-m_size * 0.7, 0), mpos + Vector2(m_size * 0.7, 0), Color(0.2, 0.0, 0.3, m_alpha * 0.5), 2.5)
		# Trigger flash — dark void burst
		if _the_end_flash > 0.0:
			var ef = _the_end_flash
			# Expanding void circle
			pass  #draw_circle(Vector2.ZERO, 20.0 + (1.0 - ef) * 100.0, Color(0.05, 0.0, 0.08, ef * 0.25))
			# "THE END" ink splatter — radiating lines
			for ri in range(16):
				var ra = TAU * float(ri) / 16.0 + sin(float(ri) * 0.7) * 0.2
				var rlen = 30.0 + (1.0 - ef) * 120.0
				draw_line(Vector2.ZERO, Vector2(cos(ra) * rlen, sin(ra) * rlen), Color(0.15, 0.0, 0.2, ef * 0.4), 2.0)
				# Drips at tendril tips
				var tip = Vector2(cos(ra) * rlen, sin(ra) * rlen)
				draw_line(tip, tip + Vector2(0, rlen * 0.15), Color(0.1, 0.0, 0.15, ef * 0.3), 1.5)
		# Ready pulse — dark ink swirl
		elif _the_end_timer < 5.0:
			var rp = sin(_time * 6.0) * 0.5 + 0.5
			pass  #draw_arc(Vector2.ZERO, 35.0 + rp * 5.0, 0, TAU, 24, Color(0.2, 0.0, 0.3, 0.12 + rp * 0.08), 2.0)
			# Ink drops circling
			for di in range(4):
				var d_angle = _time * 3.0 + float(di) * TAU / 4.0
				var dpos = Vector2(cos(d_angle) * 38.0, sin(d_angle) * 38.0)
				draw_circle(dpos, 2.0, Color(0.1, 0.0, 0.15, 0.15 + rp * 0.1))

# === HELPER: Draw smoke tendril between two points ===
func _draw_smoke_tendril(from: Vector2, to: Vector2, alpha: float, width: float) -> void:
	var smoke_color = Color(0.06, 0.02, 0.1, alpha)
	var glow_color = Color(0.15, 0.05, 0.2, alpha * 0.4)
	# Main dark smoke line
	draw_line(from, to, smoke_color, width)
	# Outer glow
	draw_line(from, to, glow_color, width + 3.0)
	# Wispy particles along the chain
	var seg_len = from.distance_to(to)
	var seg_count = maxi(int(seg_len / 20.0), 2)
	for si in range(seg_count):
		var st = float(si) / float(seg_count)
		var sp = from.lerp(to, st)
		var perp = (to - from).normalized().orthogonal()
		var wobble = sin(_time * 6.0 + st * 10.0) * 4.0
		sp += perp * wobble
		var particle_size = 2.5 * (1.0 - st * 0.5) * alpha
		draw_circle(sp, particle_size, Color(0.1, 0.03, 0.18, alpha * 0.6))

func _fill_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var pts = PackedVector2Array()
	for i in range(24):
		var angle = TAU * float(i) / 24.0
		pts.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(pts, color)
