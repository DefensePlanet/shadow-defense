extends Node2D
## Queen of Hearts — card army commander from Lewis Carroll's Alice's Adventures in Wonderland (1865).
## Path A "Royal Fury": Royal Decree, Croquet Mallet, Off With ALL Heads
## Path B "Card Army": Card Soldiers, The Trial, Royal Guard
## Path C "Wonderland Tyrant": Painting Roses, Hedge Maze, Tea Party Madness

# Base stats
var damage: float = 20.0
var fire_rate: float = 0.85
var attack_range: float = 140.0
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

# Path A: Royal Fury
var _knockback_enabled: bool = false
var _croquet_timer: float = 15.0
var _croquet_flash: float = 0.0
var _off_with_heads_timer: float = 15.0
var _off_with_heads_flash: float = 0.0

# Path B: Card Army
var _card_soldiers_active: bool = false
var _card_soldier_count: int = 0
var _trial_timer: float = 20.0
var _trial_flash: float = 0.0
var _executioner_timer: float = 12.0
var _executioner_flash: float = 0.0
var _executioner_active: bool = false

# Path C: Wonderland Tyrant
var _paint_marks: Dictionary = {}  # enemy_id -> stack count
var _hedge_maze_timer: float = 18.0
var _hedge_maze_flash: float = 0.0
var _tea_party_timer: float = 20.0
var _tea_party_flash: float = 0.0

# === PROGRESSIVE ABILITIES (9 tiers, unlocked via lifetime damage) ===
const PROG_ABILITY_NAMES = [
	"Royal Decree", "Card Soldiers", "Painting the Roses", "Croquet Mallet",
	"The Trial", "Hedge Maze", "Executioner's Axe", "Tea Party Madness",
	"Off With ALL Their Heads"
]
const PROG_ABILITY_DESCS = [
	"+20% dmg, attacks knockback",
	"2 card guards patrol and attack",
	"Marks enemies: +10% dmg per stack (max 5)",
	"Every 15s, flamingo mallet 4x AoE",
	"Every 20s, sentence strongest (50% HP kill)",
	"Every 18s, thorns slow all 40% for 3s",
	"Every 12s, execute weakest (instakill)",
	"Every 20s, all towers +30% speed 8s",
	"Every 15s, all in range 5x + 2s stun"
]
var prog_abilities: Array = [false, false, false, false, false, false, false, false, false]
# Ability timers
var _prog_croquet_timer: float = 15.0
var _prog_trial_timer: float = 20.0
var _prog_hedge_timer: float = 18.0
var _prog_executioner_timer: float = 12.0
var _prog_tea_party_timer: float = 20.0
var _prog_off_heads_timer: float = 15.0
# Visual flash timers
var _prog_croquet_flash: float = 0.0
var _prog_trial_flash: float = 0.0
var _prog_hedge_flash: float = 0.0
var _prog_executioner_flash: float = 0.0
var _prog_tea_party_flash: float = 0.0
var _prog_off_heads_flash: float = 0.0

const MAX_STAT_LEVEL: int = 10  # Cap stat scaling to prevent infinite power creep
const STAT_UPGRADE_INTERVAL: float = 8000.0
const ABILITY_THRESHOLD: float = 28000.0
var stat_upgrade_level: int = 0
var ability_chosen: bool = false
var awaiting_ability_choice: bool = false
const TIER_NAMES = [
	"Royal Decree",
	"Card Soldiers",
	"Hedge Maze",
	"The Trial",
	"Off With Their Heads"
]
const ABILITY_DESCRIPTIONS = [
	"+20% dmg, attacks knockback enemies",
	"2 card guards patrol and attack nearby enemies",
	"Thorn maze slows all enemies in range 40% for 3s",
	"Every 20s, sentence strongest enemy to 50% HP",
	"Every 15s, all enemies in range take 5x + 2s stun"
]
const TIER_COSTS = [140, 325, 600, 1100, 1800]
var is_selected: bool = false
var base_cost: int = 0

# Attack sounds — sharp commanding slash
var _attack_sounds: Array = []
var _attack_sounds_by_tier: Array = []
var _attack_player: AudioStreamPlayer

# Ability sounds
var _upgrade_sound: AudioStreamWAV
var _upgrade_player: AudioStreamPlayer
var _decree_sound: AudioStreamWAV
var _decree_player: AudioStreamPlayer
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

	# Royal decree — imperious brass fanfare with commanding crack
	var dec_rate := 44100
	var dec_dur := 0.5
	var dec_samples := PackedFloat32Array()
	dec_samples.resize(int(dec_rate * dec_dur))
	for i in dec_samples.size():
		var t := float(i) / dec_rate
		var s := 0.0
		# Commanding brass tone — trumpet-like
		var env := minf(t * 40.0, 1.0) * exp(-t * 4.0) * 0.35
		s += sin(TAU * 523.25 * t) * env  # C5
		s += sin(TAU * 659.25 * t) * env * 0.4  # E5
		s += sin(TAU * 783.99 * t) * env * 0.2  # G5
		# Sharp crack onset
		var crack := exp(-t * 60.0) * 0.2
		s += (randf() * 2.0 - 1.0) * crack
		dec_samples[i] = clampf(s, -1.0, 1.0)
	_decree_sound = _samples_to_wav(dec_samples, dec_rate)
	_decree_player = AudioStreamPlayer.new()
	_decree_player.stream = _decree_sound
	_decree_player.volume_db = -12.0
	add_child(_decree_player)

	# Upgrade chime — regal ascending major arpeggio (C5→E5→G5)
	var up_rate := 22050
	var up_dur := 0.35
	var up_samples := PackedFloat32Array()
	up_samples.resize(int(up_rate * up_dur))
	var up_notes := [523.25, 659.25, 783.99]  # C5, E5, G5 (major)
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
	_croquet_flash = max(_croquet_flash - delta * 2.0, 0.0)
	_off_with_heads_flash = max(_off_with_heads_flash - delta * 1.5, 0.0)
	_trial_flash = max(_trial_flash - delta * 2.0, 0.0)
	_executioner_flash = max(_executioner_flash - delta * 2.0, 0.0)
	_hedge_maze_flash = max(_hedge_maze_flash - delta * 1.5, 0.0)
	_tea_party_flash = max(_tea_party_flash - delta * 1.5, 0.0)

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

	# Path A tier 2: Croquet Mallet — flamingo AoE
	if upgrade_tier >= 2 and _croquet_timer > 0.0:
		_croquet_timer -= delta
		if _croquet_timer <= 0.0 and _has_enemies_in_range():
			_croquet_mallet_strike()
			_croquet_timer = 15.0

	# Path A tier 3: Off With ALL Their Heads
	if upgrade_tier >= 5:
		_off_with_heads_timer -= delta
		if _off_with_heads_timer <= 0.0 and _has_enemies_in_range():
			_off_with_all_heads()
			_off_with_heads_timer = 15.0

	# Path B tier 2: The Trial
	if upgrade_tier >= 4 and _trial_timer > 0.0:
		_trial_timer -= delta
		if _trial_timer <= 0.0 and _has_enemies_in_range():
			_the_trial()
			_trial_timer = 20.0

	# Path B tier 3: Executioner
	if _executioner_active:
		_executioner_timer -= delta
		if _executioner_timer <= 0.0 and _has_enemies_in_range():
			_executioner_strike()
			_executioner_timer = 12.0

	# Path C tier 2: Hedge Maze
	if upgrade_tier >= 3:
		_hedge_maze_timer -= delta
		if _hedge_maze_timer <= 0.0 and _has_enemies_in_range():
			_hedge_maze_thorns()
			_hedge_maze_timer = 18.0

	# Path C tier 3: Tea Party Madness
	if upgrade_tier >= 5:
		_tea_party_timer -= delta
		if _tea_party_timer <= 0.0:
			_tea_party_madness()
			_tea_party_timer = 20.0

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

	# Paint marks — bonus damage per stack
	if prog_abilities[2] or _paint_marks.size() > 0:
		var eid = target.get_instance_id()
		var stacks = _paint_marks.get(eid, 0)
		if stacks > 0:
			eff_damage *= (1.0 + 0.10 * stacks)

	if target.has_method("take_damage"):
		target.take_damage(eff_damage)
		register_damage(eff_damage)
		var hp_before = target.health if "health" in target else 0.0
		if hp_before <= eff_damage:
			register_kill()

	# Knockback (Path A tier 1 or prog ability 0)
	if _knockback_enabled or prog_abilities[0]:
		if target and is_instance_valid(target) and target.has_method("apply_knockback"):
			var kb_dir = (target.global_position - global_position).normalized()
			target.apply_knockback(kb_dir * 20.0)

	# Paint marks — apply mark on hit
	if prog_abilities[2]:
		if target and is_instance_valid(target):
			var eid = target.get_instance_id()
			_paint_marks[eid] = mini(_paint_marks.get(eid, 0) + 1, 5)

func _croquet_mallet_strike() -> void:
	_croquet_flash = 1.0
	if _decree_player and not _is_sfx_muted():
		_decree_player.play()
	var eff_range = attack_range * _range_mult()
	var eff_damage = damage * 4.0 * _damage_mult()
	for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if global_position.distance_to(e.global_position) < eff_range:
			if e.has_method("take_damage"):
				e.take_damage(eff_damage)
				register_damage(eff_damage)

func _off_with_all_heads() -> void:
	_off_with_heads_flash = 1.0
	var eff_range = attack_range * _range_mult()
	var eff_damage = damage * 5.0 * _damage_mult()
	for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if global_position.distance_to(e.global_position) < eff_range:
			if e.has_method("take_damage"):
				e.take_damage(eff_damage)
				register_damage(eff_damage)
			if e.has_method("apply_sleep"):
				e.apply_sleep(2.0)
	if is_instance_valid(_main_node):
		_main_node.spawn_floating_text(global_position + Vector2(0, -40), "OFF WITH THEIR HEADS!", Color(0.9, 0.1, 0.2), 16.0, 1.5)

func _the_trial() -> void:
	_trial_flash = 1.0
	var strongest: Node2D = null
	var most_hp: float = 0.0
	for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if global_position.distance_to(e.global_position) < attack_range * _range_mult():
			var hp = e.health if "health" in e else 0.0
			if hp > most_hp:
				most_hp = hp
				strongest = e
	if strongest and strongest.has_method("take_damage"):
		var max_hp = strongest.max_health if "max_health" in strongest else most_hp
		var sentence_dmg = max_hp * 0.50
		strongest.take_damage(sentence_dmg)
		register_damage(sentence_dmg)

func _executioner_strike() -> void:
	_executioner_flash = 1.0
	var weakest: Node2D = null
	var least_hp: float = 999999.0
	for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if global_position.distance_to(e.global_position) < attack_range * _range_mult():
			var hp = e.health if "health" in e else 999999.0
			if hp < least_hp:
				least_hp = hp
				weakest = e
	if weakest and weakest.has_method("take_damage"):
		var max_hp = weakest.max_health if "max_health" in weakest else 100.0
		weakest.take_damage(max_hp * 10.0)  # instakill
		register_damage(max_hp * 10.0)
		register_kill()

func _hedge_maze_thorns() -> void:
	_hedge_maze_flash = 1.0
	var eff_range = attack_range * _range_mult()
	for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if global_position.distance_to(e.global_position) < eff_range:
			if e.has_method("apply_slow"):
				e.apply_slow(0.40, 3.0)

func _tea_party_madness() -> void:
	_tea_party_flash = 1.0
	# Buff all towers +30% speed for 8s
	for tower in get_tree().get_nodes_in_group("towers"):
		if is_instance_valid(tower) and "fire_rate" in tower:
			tower.fire_rate *= 1.3
	# Schedule debuff removal (approximate via timer)
	if is_instance_valid(_main_node):
		_main_node.spawn_floating_text(global_position + Vector2(0, -40), "TEA PARTY!", Color(0.8, 0.3, 0.6), 16.0, 1.5)

func register_kill() -> void:
	kill_count += 1
	_upgrade_flash = 0.3

func register_damage(amount: float) -> void:
	damage_dealt += amount
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("register_tower_damage"):
		main.register_tower_damage(main.TowerType.QUEEN_OF_HEARTS, amount)
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
	damage += 1.5
	fire_rate += 0.015
	attack_range += 4.0

func choose_ability(index: int) -> void:
	ability_chosen = true
	awaiting_ability_choice = false
	upgrade_tier = index + 1
	_apply_upgrade(upgrade_tier)
	_upgrade_flash = 3.0
	_upgrade_name = TIER_NAMES[index]

func _apply_upgrade(tier: int) -> void:
	match tier:
		1: # Royal Decree — +20% dmg, knockback
			_knockback_enabled = true
			damage = 24.0
			fire_rate = 0.90
			attack_range = 145.0
		2: # Card Soldiers — 2 card guards
			_card_soldiers_active = true
			_card_soldier_count = 2
			damage = 28.0
			fire_rate = 0.95
			attack_range = 148.0
			gold_bonus = 2
		3: # Hedge Maze — thorn slow zone
			damage = 33.0
			fire_rate = 1.0
			attack_range = 152.0
			gold_bonus = 2
		4: # The Trial — sentence strongest
			damage = 40.0
			fire_rate = 1.1
			attack_range = 158.0
			gold_bonus = 3
		5: # Off With Their Heads — ultimate AoE + stun
			damage = 48.0
			fire_rate = 1.2
			attack_range = 165.0
			gold_bonus = 3

func apply_path_upgrade(path: String, tier: int) -> void:
	match path:
		"A":
			match tier:
				1: # Royal Decree — +20% dmg + knockback
					_knockback_enabled = true
					damage *= 1.20
				2: # Croquet Mallet — flamingo 4x AoE/15s
					pass  # Timer handled in _process
				3: # Off With ALL Heads — 5x + stun + cleave
					pass  # Timer handled in _process
		"B":
			match tier:
				1: # Card Soldiers — 2 guards patrol
					_card_soldiers_active = true
					_card_soldier_count = 2
				2: # The Trial — sentence strongest 50% HP/20s
					pass  # Timer handled in _process
				3: # Royal Guard — 4 cards + Executioner instakill/15s
					_card_soldier_count = 4
					_executioner_active = true
		"C":
			match tier:
				1: # Painting Roses — mark +10%/stack max 5
					pass  # Handled in _attack
				2: # Hedge Maze — thorns slow 40%/18s
					pass  # Timer handled in _process
				3: # Tea Party Madness — towers +30% 8s + paint spreads
					pass  # Timer handled in _process
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
	return "Queen of Hearts"

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
	var melody := [523.25, 587.33, 659.25, 783.99, 659.25, 587.33, 523.25, 493.88]
	# C5 D5 E5 G5 E5 D5 C5 B4 — regal commanding melody
	_attack_sounds_by_tier = []
	for tier in range(5):
		var tier_sounds: Array = []
		var dur := 0.40 + tier * 0.04
		var vol := 0.28 + tier * 0.015
		for note_idx in melody.size():
			var freq: float = melody[note_idx]
			var total := int(mix_rate * dur)
			var samples := PackedFloat32Array()
			samples.resize(total)
			var rng := RandomNumberGenerator.new()
			rng.seed = note_idx * 2500 + tier * 400
			for i in total:
				var t := float(i) / float(mix_rate)
				var env := minf(t * 25.0, 1.0) * exp(-t * 3.2)
				# Brass-like tone with harmonics
				var s := sin(t * freq * TAU) * 0.4
				s += sin(t * freq * 2.0 * TAU) * 0.15
				s += sin(t * freq * 3.0 * TAU) * 0.08
				# Slight noise breath
				var noise := rng.randf_range(-1.0, 1.0)
				s += noise * 0.04 * env
				samples[i] = clampf(s * env * vol, -1.0, 1.0)
			var att_len := mini(int(0.008 * mix_rate), total)
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
	if main and main.survivor_progress.has(main.TowerType.QUEEN_OF_HEARTS):
		var p = main.survivor_progress[main.TowerType.QUEEN_OF_HEARTS]
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
	if prog_abilities[0]:  # Royal Decree: +20% damage, knockback
		_knockback_enabled = true

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
	_prog_croquet_flash = max(_prog_croquet_flash - delta * 2.0, 0.0)
	_prog_trial_flash = max(_prog_trial_flash - delta * 2.0, 0.0)
	_prog_hedge_flash = max(_prog_hedge_flash - delta * 1.5, 0.0)
	_prog_executioner_flash = max(_prog_executioner_flash - delta * 2.0, 0.0)
	_prog_tea_party_flash = max(_prog_tea_party_flash - delta * 1.5, 0.0)
	_prog_off_heads_flash = max(_prog_off_heads_flash - delta * 1.5, 0.0)

	# Ability 4: Croquet Mallet — flamingo mallet 4x AoE every 15s
	if prog_abilities[3]:
		_prog_croquet_timer -= delta
		if _prog_croquet_timer <= 0.0 and _has_enemies_in_range():
			_prog_croquet_flash = 1.0
			var eff_damage = damage * 4.0 * _damage_mult()
			for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
				if global_position.distance_to(e.global_position) < attack_range * _range_mult():
					if e.has_method("take_damage"):
						e.take_damage(eff_damage)
						register_damage(eff_damage)
			_prog_croquet_timer = 15.0

	# Ability 5: The Trial — sentence strongest 50% HP every 20s
	if prog_abilities[4]:
		_prog_trial_timer -= delta
		if _prog_trial_timer <= 0.0 and _has_enemies_in_range():
			_prog_trial_flash = 1.0
			var strongest: Node2D = null
			var most_hp: float = 0.0
			for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
				if global_position.distance_to(e.global_position) < attack_range * _range_mult():
					var hp = e.health if "health" in e else 0.0
					if hp > most_hp:
						most_hp = hp
						strongest = e
			if strongest and strongest.has_method("take_damage"):
				var max_hp = strongest.max_health if "max_health" in strongest else most_hp
				strongest.take_damage(max_hp * 0.50)
				register_damage(max_hp * 0.50)
			_prog_trial_timer = 20.0

	# Ability 6: Hedge Maze — thorns slow all 40% for 3s every 18s
	if prog_abilities[5]:
		_prog_hedge_timer -= delta
		if _prog_hedge_timer <= 0.0 and _has_enemies_in_range():
			_prog_hedge_flash = 1.0
			for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
				if global_position.distance_to(e.global_position) < attack_range * _range_mult():
					if e.has_method("apply_slow"):
						e.apply_slow(0.40, 3.0)
			_prog_hedge_timer = 18.0

	# Ability 7: Executioner's Axe — execute weakest (instakill) every 12s
	if prog_abilities[6]:
		_prog_executioner_timer -= delta
		if _prog_executioner_timer <= 0.0 and _has_enemies_in_range():
			_prog_executioner_flash = 1.0
			var weakest: Node2D = null
			var least_hp: float = 999999.0
			for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
				if global_position.distance_to(e.global_position) < attack_range * _range_mult():
					var hp = e.health if "health" in e else 999999.0
					if hp < least_hp:
						least_hp = hp
						weakest = e
			if weakest and weakest.has_method("take_damage"):
				var max_hp = weakest.max_health if "max_health" in weakest else 100.0
				weakest.take_damage(max_hp * 10.0)
				register_damage(max_hp * 10.0)
				register_kill()
			_prog_executioner_timer = 12.0

	# Ability 8: Tea Party Madness — all towers +30% speed 8s every 20s
	if prog_abilities[7]:
		_prog_tea_party_timer -= delta
		if _prog_tea_party_timer <= 0.0:
			_prog_tea_party_flash = 1.0
			for tower in get_tree().get_nodes_in_group("towers"):
				if is_instance_valid(tower) and "fire_rate" in tower:
					tower.fire_rate *= 1.3
			if is_instance_valid(_main_node):
				_main_node.spawn_floating_text(global_position + Vector2(0, -40), "TEA PARTY!", Color(0.8, 0.3, 0.6), 14.0, 1.2)
			_prog_tea_party_timer = 20.0

	# Ability 9: Off With ALL Their Heads — 5x + 2s stun every 15s
	if prog_abilities[8]:
		_prog_off_heads_timer -= delta
		if _prog_off_heads_timer <= 0.0 and _has_enemies_in_range():
			_prog_off_heads_flash = 1.0
			var eff_damage = damage * 5.0 * _damage_mult()
			for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
				if global_position.distance_to(e.global_position) < attack_range * _range_mult():
					if e.has_method("take_damage"):
						e.take_damage(eff_damage)
						register_damage(eff_damage)
					if e.has_method("apply_sleep"):
						e.apply_sleep(2.0)
			if is_instance_valid(_main_node):
				_main_node.spawn_floating_text(global_position + Vector2(0, -40), "OFF WITH THEIR HEADS!", Color(0.9, 0.1, 0.2), 16.0, 1.5)
			_prog_off_heads_timer = 15.0

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

# === ACTIVE HERO ABILITY: Royal Decree (AoE knockback + damage, 30s CD) ===
var active_ability_ready: bool = true
var active_ability_cooldown: float = 0.0
var active_ability_max_cd: float = 30.0

func activate_hero_ability() -> void:
	if not active_ability_ready:
		return
	var enemies = (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies"))
	for e in enemies:
		if global_position.distance_to(e.global_position) < attack_range * _range_mult() * 1.5:
			if is_instance_valid(e) and e.has_method("take_damage"):
				var dmg = damage * 4.0 * _damage_mult()
				e.take_damage(dmg)
				register_damage(dmg)
			if e.has_method("apply_knockback"):
				var kb_dir = (e.global_position - global_position).normalized()
				e.apply_knockback(kb_dir * 30.0)
	active_ability_ready = false
	active_ability_cooldown = active_ability_max_cd
	if is_instance_valid(_main_node):
		_main_node.spawn_floating_text(global_position + Vector2(0, -40), "OFF WITH THEIR HEADS!", Color(0.9, 0.1, 0.2), 16.0, 1.5)

func get_active_ability_name() -> String:
	return "Royal Decree"

func get_active_ability_desc() -> String:
	return "AoE knockback + 4x dmg (30s CD)"

func _damage_mult() -> float:
	var mult: float = (1.0 + _synergy_buffs.get("damage", 0.0) + _meta_buffs.get("damage", 0.0)) * power_damage_mult
	if prog_abilities[0]:  # Royal Decree: +20% damage
		mult *= 1.20
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
	var eff_range = attack_range * _range_mult()
	if is_selected:
		var pulse = (sin(_time * 3.0) + 1.0) * 0.5
		var ring_alpha = 0.5 + pulse * 0.3
		draw_arc(Vector2.ZERO, eff_range, 0, TAU, 36, Color(0.9, 0.15, 0.2, 0.25 + pulse * 0.15), 2.0)
		draw_arc(Vector2.ZERO, 40.0, 0, TAU, 28, Color(0.9, 0.15, 0.2, ring_alpha), 2.5)
		draw_arc(Vector2.ZERO, 43.0, 0, TAU, 28, Color(0.9, 0.15, 0.2, ring_alpha * 0.4), 1.5)

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
		var scale_factor = 160.0 / tex_size.y if tex_size.y > 0 else 1.0
		var draw_size = tex_size * scale_factor
		draw_texture_rect(_active_tex, Rect2(-draw_size / 2.0 + Vector2(0, -draw_size.y * 0.25), draw_size), false)

	# === 3. UPGRADE FLASH ===
	if _upgrade_flash > 0.0:
		if _upgrade_name != "" and _game_font:
			draw_string(_game_font, Vector2(-40, -70), _upgrade_name, HORIZONTAL_ALIGNMENT_CENTER, 80, 11, Color(1, 0.85, 0.2, _upgrade_flash))

	# === 4. ABILITY FLASH EFFECTS ===
	# Croquet mallet flash — red shockwave
	if _croquet_flash > 0.0:
		var cr = 30.0 + (1.0 - _croquet_flash) * 60.0
		for ri in range(2):
			draw_arc(Vector2.ZERO, cr + float(ri) * 15.0, 0, TAU, 24, Color(0.9, 0.2, 0.3, _croquet_flash * 0.3), 2.5)

	# Off With Heads flash — crimson expanding ring
	if _off_with_heads_flash > 0.0:
		var hr = 40.0 + (1.0 - _off_with_heads_flash) * 80.0
		draw_arc(Vector2.ZERO, hr, 0, TAU, 32, Color(0.9, 0.1, 0.1, _off_with_heads_flash * 0.4), 3.0)

	# Trial flash — golden gavel strike
	if _trial_flash > 0.0:
		draw_circle(Vector2.ZERO, 15.0 * _trial_flash, Color(0.9, 0.8, 0.2, _trial_flash * 0.5))

	# Hedge maze flash — green thorn ring
	if _hedge_maze_flash > 0.0:
		var mr = 35.0 + (1.0 - _hedge_maze_flash) * 50.0
		draw_arc(Vector2.ZERO, mr, 0, TAU, 24, Color(0.2, 0.7, 0.3, _hedge_maze_flash * 0.3), 2.0)

	# Tea party flash — pink sparkles
	if _tea_party_flash > 0.0:
		for si in range(6):
			var sa = TAU * float(si) / 6.0 + _tea_party_flash * 2.0
			var sp = Vector2.from_angle(sa) * (30.0 + (1.0 - _tea_party_flash) * 40.0)
			draw_circle(sp, 3.0, Color(0.8, 0.3, 0.6, _tea_party_flash * 0.5))

	# === 5. TIER PIPS (red/gold theme) ===
	var plat_y = 24.0
	for i in range(upgrade_tier):
		var pip_angle = -PI / 2.0 + float(i) * (TAU / 5.0) - (float(upgrade_tier - 1) * TAU / 10.0)
		var pip_pos = Vector2(cos(pip_angle) * 24.0, plat_y + sin(pip_angle) * 8.0)
		var pip_col: Color
		match i:
			0: pip_col = Color(0.9, 0.15, 0.2)   # crimson
			1: pip_col = Color(0.9, 0.8, 0.2)     # gold
			2: pip_col = Color(0.2, 0.7, 0.3)     # hedge green
			3: pip_col = Color(0.7, 0.2, 0.5)     # royal purple
			_: pip_col = Color(0.9, 0.1, 0.1)     # blood red
		draw_circle(pip_pos, 4.0, pip_col)
		draw_circle(pip_pos, 5.5, Color(pip_col.r, pip_col.g, pip_col.b, 0.15))

	# === 6. ACTIVE ABILITY COOLDOWN ARC ===
	if not active_ability_ready:
		var cd_fill = 1.0 - (active_ability_cooldown / active_ability_max_cd)
		draw_arc(Vector2.ZERO, 28.0, -PI / 2.0, -PI / 2.0 + TAU * cd_fill, 32, Color(0.9, 0.2, 0.3, 0.3), 2.0)

	_draw_tower_aura()

func _draw_tower_aura() -> void:
	if upgrade_tier < 3:
		return
	var aura_col = Color(0.9, 0.15, 0.2)
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
			draw_arc(Vector2.ZERO, 32.0, 0, TAU, 32, Color(1.0, 0.85, 0.3, glow_pulse), 2.5)
