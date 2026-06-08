extends Node2D
## Captain Hook — villainous pirate captain from JM Barrie's Peter and Wendy (1911).
## Stands ground with cutlass strikes and cannon volleys.
## 3-Path Upgrade System (TowerType 12):
## Path A "The Iron Hook": Good Form -> Hook Combo -> The Last Villain
## Path B "Pirate Captain": Cannon Broadside -> The Jolly Roger -> Pirate Armada
## Path C "Fear of the Clock": Poison Hook -> Tick-Tock Terror -> Crocodile's Return

var damage: float = 18.0
var fire_rate: float = 0.95
var attack_range: float = 155.0
var fire_cooldown: float = 0.0
var aim_angle: float = 0.0
var sprite_texture: Texture2D = null
# Flair animation (idle poses — randomized every 8s)
var flair_textures: Array = []  # Injected by main.gd
var _sprite_attack: Texture2D = null  # Attack pose (cutlass swing), injected by main.gd
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

# Gear visual slots (set by main.gd when gear equipped)
var gear_crown: Dictionary = {}
var gear_amulet: Dictionary = {}
var gear_bracelet: Dictionary = {}
var gear_weapon: Dictionary = {}
var gear_ring: Dictionary = {}
var skin_id: String = "default"

# Damage tracking and upgrades
var damage_dealt: float = 0.0
var kill_count: int = 0
var upgrade_tier: int = 0
var _upgrade_flash: float = 0.0
var _upgrade_name: String = ""

# Animation variables
var _time: float = 0.0
var _attack_anim: float = 0.0
var _build_timer: float = 0.0

# Stationary striker — stays in place, attacks from position
var _home_position: Vector2 = Vector2.ZERO

# === PATH A: "The Iron Hook" ===
# T1: Good Form — +20% cutlass dmg, +15% speed (applied as stat changes)
# T2: Hook Combo — every 8s, AoE cutlass spin hitting all in range for 2x
var hook_combo_enabled: bool = false
var _hook_combo_timer: float = 8.0
var _hook_combo_flash: float = 0.0
# T3: The Last Villain — every 45s, invulnerable 5s and attack all on screen 3x
var last_villain_enabled: bool = false
var _last_villain_timer: float = 45.0
var _last_villain_flash: float = 0.0
var _last_villain_active: bool = false
var _last_villain_duration: float = 0.0

# === PATH B: "Pirate Captain" ===
# T1: Cannon Broadside — every 15s, 4 cannonballs hit random enemies 3x
var cannon_broadside_enabled: bool = false
var _cannon_timer: float = 15.0
var _cannon_flash: float = 0.0
# T2: The Jolly Roger — every 20s, pirate crew fires at 5 enemies 4x
var jolly_roger_enabled: bool = false
var _jolly_roger_timer: float = 20.0
var _jolly_roger_flash: float = 0.0
# T3: Pirate Armada — +50% gold from kills, cannon broadside hits 8 enemies
var pirate_armada_enabled: bool = false
var _pirate_armada_flash: float = 0.0

# === PATH C: "Fear of the Clock" ===
# T1: Poison Hook — attacks apply 3s poison DoT
var poison_hook_enabled: bool = false
var _poison_flash: float = 0.0
# T2: Tick-Tock Terror — every 12s, fear 3 enemies backwards 2s
var tick_tock_enabled: bool = false
var _tick_tock_timer: float = 12.0
var _tick_tock_flash: float = 0.0
# T3: Crocodile's Return — every 18s, all in range burn 5s (AoE fire)
var crocodile_return_enabled: bool = false
var _crocodile_timer: float = 18.0
var _crocodile_flash: float = 0.0

const MAX_STAT_LEVEL: int = 10
const STAT_UPGRADE_INTERVAL: float = 8000.0
const ABILITY_THRESHOLD: float = 28000.0
var stat_upgrade_level: int = 0
var ability_chosen: bool = false
var awaiting_ability_choice: bool = false
const TIER_NAMES = [
	"Good Form",
	"Cannon Broadside",
	"Tick-Tock Terror",
	"Pirate Armada",
	"The Last Villain"
]
const ABILITY_DESCRIPTIONS = [
	"+20% cutlass damage, +15% attack speed",
	"Every 15s, 4 cannonballs hit random enemies for 3x damage",
	"Every 12s, fear 3 enemies backwards for 2 seconds",
	"Every 20s, pirate crew fires at 5 enemies for 4x damage",
	"Invulnerable 5s, attacks all enemies on screen for 3x damage"
]
const TIER_COSTS = [140, 325, 600, 1100, 1800]
var is_selected: bool = false
var base_cost: int = 0

# Attack sounds
var _attack_sounds: Array = []
var _attack_sounds_by_tier: Array = []
var _attack_player: AudioStreamPlayer

# Ability sounds
var _cannon_sound: AudioStreamWAV
var _cannon_player: AudioStreamPlayer
var _upgrade_sound: AudioStreamWAV
var _upgrade_player: AudioStreamPlayer

# === PROGRESSIVE ABILITIES (9 tiers, unlocked via lifetime damage) ===
const PROG_ABILITY_NAMES = [
	"Good Form", "Poison Hook", "Smee's Devotion", "Cannon Broadside",
	"Tick-Tock Terror", "Pirate's Plunder", "The Jolly Roger",
	"Blackbeard's Legacy", "The Last Villain"
]
const PROG_ABILITY_DESCS = [
	"+20% cutlass dmg, +15% speed",
	"Attacks apply 3s poison DoT",
	"Every 20s, Smee heals Hook (shield 40 dmg)",
	"Every 15s, 4 cannonballs hit random enemies 3x",
	"Every 12s, fear 3 enemies backwards 2s",
	"+50% gold from kills in range",
	"Every 20s, pirate crew fires 5 enemies 4x",
	"Every 18s, all in range burn 5s (AoE fire)",
	"Invulnerable 5s, attacks all on screen 3x"
]
var prog_abilities: Array = [false, false, false, false, false, false, false, false, false]
# Progressive ability timers
var _smee_timer: float = 20.0
var _prog_cannon_timer: float = 15.0
var _prog_fear_timer: float = 12.0
var _prog_kill_count: int = 0
var _prog_crew_timer: float = 20.0
var _prog_burn_timer: float = 18.0
var _smee_shield: float = 0.0
# Progressive ability visual flash timers
var _good_form_flash: float = 0.0
var _poison_prog_flash: float = 0.0
var _smee_flash: float = 0.0
var _prog_cannon_flash: float = 0.0
var _prog_fear_flash: float = 0.0
var _plunder_flash: float = 0.0
var _prog_crew_flash: float = 0.0
var _prog_burn_flash: float = 0.0
var _last_villain_prog_flash: float = 0.0
var _game_font: Font
var _main_node: Node2D = null

# === SYNERGY BUFFS ===
var _synergy_buffs: Dictionary = {}
var _meta_buffs: Dictionary = {}
var power_damage_mult: float = 1.0

# === ACTIVE HERO ABILITY: Cannon Broadside (4 cannonballs, 30s CD) ===
var active_ability_ready: bool = true
var active_ability_cooldown: float = 0.0
var active_ability_max_cd: float = 30.0

func _ready() -> void:
	_main_node = get_tree().get_first_node_in_group("main")
	_game_font = preload("res://fonts/Cinzel.ttf")
	add_to_group("towers")
	_generate_tier_sounds()
	_attack_sounds = _attack_sounds_by_tier[0]
	_attack_player = AudioStreamPlayer.new()
	_attack_player.stream = _attack_sounds[0]
	_attack_player.volume_db = -14.0
	add_child(_attack_player)

	# Cannon boom — deep thud with metallic ring
	var cn_rate := 22050
	var cn_dur := 0.4
	var cn_samples := PackedFloat32Array()
	cn_samples.resize(int(cn_rate * cn_dur))
	for i in cn_samples.size():
		var t := float(i) / cn_rate
		var boom := sin(TAU * 80.0 * t) * exp(-t * 12.0) * 0.5
		var ring := sin(TAU * 600.0 * t) * exp(-t * 20.0) * 0.2
		var noise := (randf() * 2.0 - 1.0) * exp(-t * 8.0) * 0.15
		cn_samples[i] = clampf(boom + ring + noise, -1.0, 1.0)
	_cannon_sound = _samples_to_wav(cn_samples, cn_rate)
	_cannon_player = AudioStreamPlayer.new()
	_cannon_player.stream = _cannon_sound
	_cannon_player.volume_db = -10.0
	add_child(_cannon_player)

	# Upgrade chime
	var up_rate := 22050
	var up_dur := 0.35
	var up_samples := PackedFloat32Array()
	up_samples.resize(int(up_rate * up_dur))
	var up_notes := [392.00, 493.88, 587.33]  # G4 B4 D5 — pirate jig
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
	_home_position = global_position
	_load_progressive_abilities()

func _process(delta: float) -> void:
	delta = minf(delta, 0.05)  # Cap to prevent physics spikes
	_time += delta
	if _build_timer > 0.0: _build_timer -= delta
	_attack_anim = max(_attack_anim - delta * 0.9, 0.0)
	_upgrade_flash = max(_upgrade_flash - delta * 0.5, 0.0)

	# Path ability flash decay
	_hook_combo_flash = max(_hook_combo_flash - delta * 2.0, 0.0)
	_last_villain_flash = max(_last_villain_flash - delta * 1.5, 0.0)
	_cannon_flash = max(_cannon_flash - delta * 2.0, 0.0)
	_jolly_roger_flash = max(_jolly_roger_flash - delta * 1.5, 0.0)
	_pirate_armada_flash = max(_pirate_armada_flash - delta * 1.5, 0.0)
	_poison_flash = max(_poison_flash - delta * 2.0, 0.0)
	_tick_tock_flash = max(_tick_tock_flash - delta * 2.0, 0.0)
	_crocodile_flash = max(_crocodile_flash - delta * 1.5, 0.0)

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

	# Stationary attack — stays in place, strikes enemies in range
	fire_cooldown -= delta
	target = _find_nearest_enemy()
	if target:
		var desired = _home_position.angle_to_point(target.global_position) + PI
		aim_angle = lerp_angle(aim_angle, desired, 12.0 * delta)
		if fire_cooldown <= 0.0:
			_strike_target(target)
			fire_cooldown = maxf(1.0 / (fire_rate * _speed_mult()), 0.15)

	# === PATH A ABILITIES ===
	# T2: Hook Combo — AoE cutlass spin every 8s
	if hook_combo_enabled:
		_hook_combo_timer -= delta
		if _hook_combo_timer <= 0.0 and _has_enemies_in_range():
			_hook_combo_attack()
			_hook_combo_timer = 8.0

	# T3: The Last Villain — invulnerable ultimate every 45s
	if last_villain_enabled:
		if _last_villain_active:
			_last_villain_duration -= delta
			if _last_villain_duration <= 0.0:
				_last_villain_active = false
		else:
			_last_villain_timer -= delta
			if _last_villain_timer <= 0.0:
				_activate_last_villain()
				_last_villain_timer = 45.0

	# === PATH B ABILITIES ===
	# T1: Cannon Broadside — 4 cannonballs every 15s
	if cannon_broadside_enabled:
		_cannon_timer -= delta
		if _cannon_timer <= 0.0 and _has_enemies_in_range():
			_fire_cannon_broadside()
			_cannon_timer = 15.0

	# T2: The Jolly Roger — pirate crew fires at 5 enemies every 20s
	if jolly_roger_enabled:
		_jolly_roger_timer -= delta
		if _jolly_roger_timer <= 0.0 and _has_enemies_in_range():
			_fire_jolly_roger()
			_jolly_roger_timer = 20.0

	# === PATH C ABILITIES ===
	# T2: Tick-Tock Terror — fear 3 enemies backwards every 12s
	if tick_tock_enabled:
		_tick_tock_timer -= delta
		if _tick_tock_timer <= 0.0 and _has_enemies_in_range():
			_tick_tock_fear()
			_tick_tock_timer = 12.0

	# T3: Crocodile's Return — AoE fire burn every 18s
	if crocodile_return_enabled:
		_crocodile_timer -= delta
		if _crocodile_timer <= 0.0 and _has_enemies_in_range():
			_crocodile_burn()
			_crocodile_timer = 18.0

	# Progressive abilities
	_process_progressive_abilities(delta)

	# Active ability cooldown
	if not active_ability_ready:
		active_ability_cooldown -= delta
		if active_ability_cooldown <= 0.0:
			active_ability_ready = true
			active_ability_cooldown = 0.0

	queue_redraw()

# === TARGET FINDING ===

func _has_enemies_in_range() -> bool:
	var eff_range = attack_range * _range_mult()
	for enemy in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if enemy.has_method("is_targetable") and not enemy.is_targetable():
			continue
		if global_position.distance_to(enemy.global_position) < eff_range:
			return true
	return false

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

# === COMBAT ===

func _get_note_index() -> int:
	var main = get_tree().get_first_node_in_group("main")
	if main and "music_beat_index" in main:
		return main.music_beat_index
	return 0

func _is_sfx_muted() -> bool:
	var main = get_tree().get_first_node_in_group("main")
	return main and main.get("sfx_muted") == true

func _strike_target(t: Node2D) -> void:
	if not is_instance_valid(t) or not t.has_method("take_damage"):
		return
	if _attack_player and _attack_sounds.size() > 0 and not _is_sfx_muted():
		_attack_player.stream = _attack_sounds[_get_note_index() % _attack_sounds.size()]
		_attack_player.play()
	if _main_node and _main_node.has_method("_pulse_tower_layer"):
		_main_node._pulse_tower_layer(12)  # CAPTAIN_HOOK
	_attack_anim = 1.0
	var dmg = damage * _damage_mult()
	if prog_abilities[0]:  # Good Form: +20% cutlass dmg
		dmg *= 1.2
	var will_kill = t.health - dmg <= 0.0
	t.take_damage(dmg, "physical")
	register_damage(dmg)
	# Smee shield absorb (progressive ability 2)
	if _smee_shield > 0.0:
		_smee_shield -= 0.0  # Shield doesn't decay from attacking, only from _process

	# Path C T1: Poison Hook — apply DoT
	if poison_hook_enabled and t.has_method("apply_dot"):
		t.apply_dot(damage * 0.3, 3.0, "poison")
	elif poison_hook_enabled and t.has_method("apply_slow"):
		# Fallback: slow + damage over time approximation
		t.apply_slow(0.7, 3.0)

	# Progressive ability 1: Poison Hook DoT
	if prog_abilities[1] and t.has_method("apply_dot"):
		t.apply_dot(damage * 0.25, 3.0, "poison")

	var eff_gold = int(gold_bonus * _gold_mult())
	if will_kill:
		kill_count += 1
		register_kill_progressive()
		if eff_gold > 0:
			var main = get_tree().get_first_node_in_group("main")
			if main:
				var gold_amount = eff_gold
				if pirate_armada_enabled or prog_abilities[5]:
					gold_amount = int(gold_amount * 1.5)
				main.add_gold(gold_amount)

# === PATH UPGRADE ABILITIES ===

func _hook_combo_attack() -> void:
	_hook_combo_flash = 1.0
	var eff_range = attack_range * _range_mult()
	for enemy in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if global_position.distance_to(enemy.global_position) < eff_range:
			if enemy.has_method("take_damage"):
				var dmg = damage * _damage_mult() * 2.0
				enemy.take_damage(dmg, "physical")
				register_damage(dmg)
	if is_instance_valid(_main_node):
		_main_node.trigger_camera_shake(4.0, 0.2)

func _activate_last_villain() -> void:
	_last_villain_flash = 2.0
	_last_villain_active = true
	_last_villain_duration = 5.0
	# Attack ALL enemies on screen 3x
	for _hit in range(3):
		for enemy in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
			if enemy.has_method("take_damage"):
				var dmg = damage * _damage_mult() * 3.0
				enemy.take_damage(dmg, "physical")
				register_damage(dmg)
	if is_instance_valid(_main_node):
		_main_node.trigger_camera_shake(10.0, 0.4)
		_main_node.trigger_explosion(global_position, 20, Color(0.8, 0.1, 0.1))
		_main_node.spawn_floating_text(global_position + Vector2(0, -40), "THE LAST VILLAIN!", Color(0.9, 0.15, 0.15), 18.0, 2.0)

func _fire_cannon_broadside() -> void:
	_cannon_flash = 1.0
	if _cannon_player and not _is_sfx_muted():
		_cannon_player.play()
	var enemies = (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies"))
	var targets: Array = enemies.duplicate()
	targets.shuffle()
	var hit_count = 4
	if pirate_armada_enabled:
		hit_count = 8
	var count = mini(hit_count, targets.size())
	for i in range(count):
		if is_instance_valid(targets[i]) and targets[i].has_method("take_damage"):
			var dmg = damage * _damage_mult() * 3.0
			var will_kill = targets[i].health - dmg <= 0.0
			targets[i].take_damage(dmg, "physical")
			register_damage(dmg)
			if will_kill:
				kill_count += 1
				register_kill_progressive()
				if gold_bonus > 0:
					var main = get_tree().get_first_node_in_group("main")
					if main:
						main.add_gold(gold_bonus)
	if is_instance_valid(_main_node):
		_main_node.trigger_camera_shake(6.0, 0.3)

func _fire_jolly_roger() -> void:
	_jolly_roger_flash = 1.0
	var enemies = (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies"))
	var targets: Array = enemies.duplicate()
	targets.shuffle()
	var count = mini(5, targets.size())
	for i in range(count):
		if is_instance_valid(targets[i]) and targets[i].has_method("take_damage"):
			var dmg = damage * _damage_mult() * 4.0
			var will_kill = targets[i].health - dmg <= 0.0
			targets[i].take_damage(dmg, "physical")
			register_damage(dmg)
			if will_kill:
				kill_count += 1
				register_kill_progressive()
	if is_instance_valid(_main_node):
		_main_node.spawn_floating_text(global_position + Vector2(0, -35), "JOLLY ROGER!", Color(0.2, 0.2, 0.2), 14.0, 1.5)

func _tick_tock_fear() -> void:
	_tick_tock_flash = 1.0
	var enemies = (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies"))
	var in_range: Array = []
	for e in enemies:
		if global_position.distance_to(e.global_position) < attack_range * _range_mult():
			in_range.append(e)
	in_range.shuffle()
	for i in range(mini(3, in_range.size())):
		if is_instance_valid(in_range[i]):
			if in_range[i].has_method("apply_fear"):
				in_range[i].apply_fear(2.0)
			elif in_range[i].has_method("apply_slow"):
				in_range[i].apply_slow(0.0, 2.0)  # Freeze as fear fallback

func _crocodile_burn() -> void:
	_crocodile_flash = 1.0
	var eff_range = attack_range * _range_mult()
	for enemy in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if global_position.distance_to(enemy.global_position) < eff_range:
			if enemy.has_method("apply_dot"):
				enemy.apply_dot(damage * 0.4, 5.0, "fire")
			elif enemy.has_method("take_damage"):
				# Fallback: instant burst if no DoT system
				enemy.take_damage(damage * _damage_mult() * 2.0, "fire")
				register_damage(damage * _damage_mult() * 2.0)
	if is_instance_valid(_main_node):
		_main_node.trigger_explosion(global_position, 12, Color(1.0, 0.4, 0.1))

# === 3-PATH UPGRADE SYSTEM ===

func apply_path_upgrade(path: String, tier: int) -> void:
	match path:
		"A":
			match tier:
				1:  # Good Form — +20% cutlass damage, +15% speed
					damage *= 1.2
					fire_rate *= 1.15
					_upgrade_flash = 3.0
					_upgrade_name = "Good Form"
				2:  # Hook Combo — timer-based AoE cutlass spin
					hook_combo_enabled = true
					_upgrade_flash = 3.0
					_upgrade_name = "Hook Combo"
				3:  # The Last Villain — invulnerable ultimate
					last_villain_enabled = true
					_upgrade_flash = 3.0
					_upgrade_name = "The Last Villain"
		"B":
			match tier:
				1:  # Cannon Broadside — periodic cannon volley
					cannon_broadside_enabled = true
					_upgrade_flash = 3.0
					_upgrade_name = "Cannon Broadside"
				2:  # The Jolly Roger — pirate crew fires at 5 enemies
					jolly_roger_enabled = true
					_upgrade_flash = 3.0
					_upgrade_name = "The Jolly Roger"
				3:  # Pirate Armada — enhanced broadside + gold bonus
					pirate_armada_enabled = true
					_upgrade_flash = 3.0
					_upgrade_name = "Pirate Armada"
		"C":
			match tier:
				1:  # Poison Hook — DoT on attacks
					poison_hook_enabled = true
					_upgrade_flash = 3.0
					_upgrade_name = "Poison Hook"
				2:  # Tick-Tock Terror — fear enemies
					tick_tock_enabled = true
					_upgrade_flash = 3.0
					_upgrade_name = "Tick-Tock Terror"
				3:  # Crocodile's Return — AoE fire burn
					crocodile_return_enabled = true
					_upgrade_flash = 3.0
					_upgrade_name = "Crocodile's Return"
	if _upgrade_player and not _is_sfx_muted():
		_upgrade_player.play()

# === DAMAGE TRACKING ===

func register_damage(amount: float) -> void:
	damage_dealt += amount
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("register_tower_damage"):
		main.register_tower_damage(main.TowerType.CAPTAIN_HOOK, amount)
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
	fire_rate += 0.01
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
		1:  # Good Form
			damage = 22.0
			fire_rate = 1.1
			attack_range = 160.0
		2:  # Cannon Broadside
			cannon_broadside_enabled = true
			damage = 26.0
			fire_rate = 1.2
			attack_range = 165.0
			gold_bonus = 2
		3:  # Tick-Tock Terror
			tick_tock_enabled = true
			damage = 30.0
			fire_rate = 1.3
			attack_range = 170.0
			gold_bonus = 2
		4:  # Pirate Armada
			jolly_roger_enabled = true
			damage = 36.0
			fire_rate = 1.4
			attack_range = 175.0
			gold_bonus = 3
		5:  # The Last Villain
			last_villain_enabled = true

# === LEGACY UPGRADE PURCHASE ===

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
	if _upgrade_player and not _is_sfx_muted(): _upgrade_player.play()
	return true

func get_tower_display_name() -> String:
	return "Captain Hook"

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

# === SOUND GENERATION ===

func _generate_tier_sounds() -> void:
	var mix_rate := 44100
	# D4 E4 F#4 A4 G4 F#4 E4 D4 — swashbuckling minor melody
	var melody := [293.66, 329.63, 369.99, 440.00, 392.00, 369.99, 329.63, 293.66]
	_attack_sounds_by_tier = []
	for tier in range(5):
		var tier_sounds: Array = []
		var dur := 0.35 + tier * 0.03
		var vol := 0.32 + tier * 0.015
		for note_idx in melody.size():
			var freq: float = melody[note_idx]
			var total := int(mix_rate * dur)
			var samples := PackedFloat32Array()
			samples.resize(total)
			var rng := RandomNumberGenerator.new()
			rng.seed = note_idx * 4000 + tier * 400
			for i in total:
				var t := float(i) / float(mix_rate)
				var env := minf(t * 40.0, 1.0) * exp(-t * 4.0)
				# Metallic cutlass tone — sharper harmonics
				var s := sin(t * freq * TAU) * 0.45
				s += sin(t * freq * 2.0 * TAU) * 0.18
				s += sin(t * freq * 3.0 * TAU) * 0.08
				# Gritty noise
				var noise := rng.randf_range(-1.0, 1.0)
				s += noise * 0.05 * env
				samples[i] = clampf(s * env * vol, -1.0, 1.0)
			# Soft attack
			var att_len := mini(int(0.006 * mix_rate), total)
			for i in att_len:
				samples[i] *= float(i) / float(att_len)
			var rel_start := maxi(total - int(0.012 * mix_rate), 0)
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
	if main and main.survivor_progress.has(main.TowerType.CAPTAIN_HOOK):
		var p = main.survivor_progress[main.TowerType.CAPTAIN_HOOK]
		var unlocked = p.get("abilities_unlocked", [])
		for i in range(mini(9, unlocked.size())):
			if unlocked[i]:
				activate_progressive_ability(i)

func activate_progressive_ability(index: int) -> void:
	if index < 0 or index >= 9:
		return
	prog_abilities[index] = true
	match index:
		0:  # Good Form: +20% cutlass dmg, +15% speed
			damage *= 1.2
			fire_rate *= 1.15
		5:  # Pirate's Plunder: +50% gold (handled in _strike_target)
			pass

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
	_good_form_flash = max(_good_form_flash - delta * 2.0, 0.0)
	_poison_prog_flash = max(_poison_prog_flash - delta * 2.0, 0.0)
	_smee_flash = max(_smee_flash - delta * 1.5, 0.0)
	_prog_cannon_flash = max(_prog_cannon_flash - delta * 1.5, 0.0)
	_prog_fear_flash = max(_prog_fear_flash - delta * 1.5, 0.0)
	_plunder_flash = max(_plunder_flash - delta * 2.0, 0.0)
	_prog_crew_flash = max(_prog_crew_flash - delta * 1.5, 0.0)
	_prog_burn_flash = max(_prog_burn_flash - delta * 1.5, 0.0)
	_last_villain_prog_flash = max(_last_villain_prog_flash - delta * 1.5, 0.0)

	# Ability 3: Smee's Devotion — every 20s, shield Hook for 40 dmg
	if prog_abilities[2]:
		_smee_timer -= delta
		if _smee_timer <= 0.0:
			_smee_shield = 40.0
			_smee_flash = 1.0
			_smee_timer = 20.0

	# Ability 4: Cannon Broadside — 4 cannonballs every 15s
	if prog_abilities[3]:
		_prog_cannon_timer -= delta
		if _prog_cannon_timer <= 0.0 and _has_enemies_in_range():
			_prog_cannon_broadside()
			_prog_cannon_timer = 15.0

	# Ability 5: Tick-Tock Terror — fear 3 enemies every 12s
	if prog_abilities[4]:
		_prog_fear_timer -= delta
		if _prog_fear_timer <= 0.0 and _has_enemies_in_range():
			_prog_tick_tock_fear()
			_prog_fear_timer = 12.0

	# Ability 7: The Jolly Roger — pirate crew fires at 5 enemies every 20s
	if prog_abilities[6]:
		_prog_crew_timer -= delta
		if _prog_crew_timer <= 0.0 and _has_enemies_in_range():
			_prog_jolly_roger()
			_prog_crew_timer = 20.0

	# Ability 8: Blackbeard's Legacy — all in range burn every 18s
	if prog_abilities[7]:
		_prog_burn_timer -= delta
		if _prog_burn_timer <= 0.0 and _has_enemies_in_range():
			_prog_blackbeard_burn()
			_prog_burn_timer = 18.0

func register_kill_progressive() -> void:
	# Ability 6: Tick-Tock the Crocodile (via Pirate's Plunder gold handled in _strike_target)
	_prog_kill_count += 1

func _prog_cannon_broadside() -> void:
	_prog_cannon_flash = 1.0
	if _cannon_player and not _is_sfx_muted():
		_cannon_player.play()
	var enemies = (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies"))
	var targets: Array = enemies.duplicate()
	targets.shuffle()
	var count = mini(4, targets.size())
	for i in range(count):
		if is_instance_valid(targets[i]) and targets[i].has_method("take_damage"):
			var dmg = damage * _damage_mult() * 3.0
			targets[i].take_damage(dmg, "physical")
			register_damage(dmg)

func _prog_tick_tock_fear() -> void:
	_prog_fear_flash = 1.0
	var enemies = (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies"))
	var in_range: Array = []
	for e in enemies:
		if global_position.distance_to(e.global_position) < attack_range * _range_mult():
			in_range.append(e)
	in_range.shuffle()
	for i in range(mini(3, in_range.size())):
		if is_instance_valid(in_range[i]):
			if in_range[i].has_method("apply_fear"):
				in_range[i].apply_fear(2.0)
			elif in_range[i].has_method("apply_slow"):
				in_range[i].apply_slow(0.0, 2.0)

func _prog_jolly_roger() -> void:
	_prog_crew_flash = 1.0
	var enemies = (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies"))
	var targets: Array = enemies.duplicate()
	targets.shuffle()
	var count = mini(5, targets.size())
	for i in range(count):
		if is_instance_valid(targets[i]) and targets[i].has_method("take_damage"):
			var dmg = damage * _damage_mult() * 4.0
			targets[i].take_damage(dmg, "physical")
			register_damage(dmg)

func _prog_blackbeard_burn() -> void:
	_prog_burn_flash = 1.0
	var eff_range = attack_range * _range_mult()
	for enemy in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if global_position.distance_to(enemy.global_position) < eff_range:
			if enemy.has_method("apply_dot"):
				enemy.apply_dot(damage * 0.35, 5.0, "fire")
			elif enemy.has_method("take_damage"):
				enemy.take_damage(damage * _damage_mult() * 1.5, "fire")
				register_damage(damage * _damage_mult() * 1.5)

# === ACTIVE HERO ABILITY: Cannon Broadside (4 cannonballs, 30s CD) ===

func activate_hero_ability() -> void:
	if not active_ability_ready:
		return
	if _cannon_player and not _is_sfx_muted():
		_cannon_player.play()
	var enemies = (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies"))
	var targets: Array = enemies.duplicate()
	targets.shuffle()
	var count = mini(4, targets.size())
	for i in range(count):
		if is_instance_valid(targets[i]) and targets[i].has_method("take_damage"):
			var dmg = damage * _damage_mult() * 3.0
			targets[i].take_damage(dmg, "physical")
			register_damage(dmg)
	active_ability_ready = false
	active_ability_cooldown = active_ability_max_cd
	if is_instance_valid(_main_node):
		_main_node.spawn_floating_text(global_position + Vector2(0, -40), "BROADSIDE!", Color(0.3, 0.3, 0.3), 16.0, 1.5)
		_main_node.trigger_camera_shake(8.0, 0.3)

func get_active_ability_name() -> String:
	return "Cannon Broadside"

func get_active_ability_desc() -> String:
	return "Fire 4 cannonballs (30s CD)"

# === DRAWING ===

func _draw_tower_aura() -> void:
	if upgrade_tier < 3:
		return
	var aura_col = Color(0.6, 0.1, 0.1)  # Dark red pirate aura
	var pulse = sin(_time * 2.5) * 0.1 + 0.3
	if upgrade_tier >= 4:
		for i in range(6):
			var a1 = _time * 0.5 + float(i) * TAU / 6.0
			var a2 = a1 + TAU / 12.0
			draw_arc(Vector2.ZERO, 18.0, a1, a2, 4, Color(aura_col.r, aura_col.g, aura_col.b, 0.2), 1.0)
	if _main_node and _main_node.has_method("_is_awakened"):
		var tower_type_enum = get_meta("tower_type_enum") if has_meta("tower_type_enum") else -1
		if tower_type_enum >= 0 and _main_node._is_awakened(tower_type_enum):
			for i in range(6):
				var sy = -8.0 - fmod(_time * 25.0 + float(i) * 12.0, 35.0)
				var sx = sin(_time * 1.5 + float(i) * 1.0) * 10.0
				var sparkle_size = 1.0 + sin(_time * 6.0 + float(i) * 2.0) * 0.5
				draw_circle(Vector2(sx, sy), sparkle_size, Color(0.8, 0.2, 0.2, 0.6))
				draw_circle(Vector2(sx + 1, sy - 1), sparkle_size * 0.5, Color(1.0, 0.5, 0.5, 0.4))
			for i in range(8):
				var ta = _time * 2.0 + float(i) * TAU / 8.0
				var tr = 20.0 + sin(_time * 3.0 + float(i)) * 5.0
				var tend = Vector2(cos(ta) * tr, sin(ta) * tr * 0.7)
				draw_line(Vector2.ZERO, tend, Color(0.8, 0.15, 0.1, 0.2), 1.2)

func _draw() -> void:
	# Build animation — elastic scale-in
	if _build_timer > 0.0:
		var bt = 1.0 - clampf(_build_timer / 0.5, 0.0, 1.0)
		var elastic = 1.0 + sin(bt * PI * 2.5) * 0.3 * (1.0 - bt)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(elastic, elastic))

	# Selection ring + range display
	if is_selected:
		var pulse = (sin(_time * 3.0) + 1.0) * 0.5
		var ring_alpha = 0.5 + pulse * 0.3
		var eff_range = attack_range * _range_mult()
		draw_arc(Vector2.ZERO, eff_range, 0, TAU, 36, Color(0.8, 0.15, 0.1, 0.25 + pulse * 0.15), 2.0)
		draw_arc(Vector2.ZERO, 40.0, 0, TAU, 28, Color(0.8, 0.15, 0.1, ring_alpha), 2.5)
		draw_arc(Vector2.ZERO, 43.0, 0, TAU, 28, Color(0.8, 0.15, 0.1, ring_alpha * 0.4), 1.5)

	var dir = Vector2.from_angle(aim_angle)
	var perp = dir.rotated(PI / 2.0)

	# Idle animation (menacing sway)
	var menace_sway = sin(_time * 1.8) * 1.5  # Slow threatening sway
	var bounce = abs(sin(_time * 2.0)) * 2.0
	var breathe = sin(_time * 1.5) * 2.0
	var bob = Vector2(menace_sway, -bounce - breathe)
	var body_offset = bob
	body_offset += Vector2(dir.x * 2.0, dir.y * 1.0)
	var lean = sin(_time * 1.2) * 1.0

	if _upgrade_flash > 0.0:
		pass  # Upgrade flash handled by sprite glow

	# Hook Combo flash — cutlass spin arc
	if _hook_combo_flash > 0.0:
		var spin_r = 30.0 + (1.0 - _hook_combo_flash) * 40.0
		draw_arc(Vector2.ZERO, spin_r, 0, TAU, 32, Color(0.7, 0.7, 0.8, _hook_combo_flash * 0.5), 3.0)
		for i in range(6):
			var sa = TAU * float(i) / 6.0 + _hook_combo_flash * 8.0
			var sp = Vector2.from_angle(sa) * spin_r
			draw_line(sp * 0.6, sp, Color(0.8, 0.8, 0.9, _hook_combo_flash * 0.6), 2.0)

	# Last Villain flash — red screen flash
	if _last_villain_flash > 0.0:
		for i in range(12):
			var lv_a = TAU * float(i) / 12.0 + _last_villain_flash * 3.0
			var lv_r = 50.0 + (1.0 - _last_villain_flash) * 100.0
			var lv_pos = Vector2.from_angle(lv_a) * lv_r
			draw_circle(lv_pos, 4.0, Color(0.9, 0.1, 0.1, _last_villain_flash * 0.5))
		if _last_villain_active:
			var inv_pulse = 0.3 + sin(_time * 6.0) * 0.2
			draw_arc(Vector2.ZERO, 35.0, 0, TAU, 32, Color(0.9, 0.2, 0.1, inv_pulse), 3.0)

	# Cannon flash — explosion burst
	if _cannon_flash > 0.0:
		var cn_r = 20.0 + (1.0 - _cannon_flash) * 50.0
		for i in range(4):
			var cn_a = TAU * float(i) / 4.0 + _cannon_flash * 2.0
			var cn_pos = Vector2.from_angle(cn_a) * cn_r
			draw_circle(cn_pos, 6.0, Color(1.0, 0.6, 0.1, _cannon_flash * 0.5))
			draw_circle(cn_pos, 3.0, Color(1.0, 0.9, 0.3, _cannon_flash * 0.7))

	# Jolly Roger flash — skull and crossbones burst
	if _jolly_roger_flash > 0.0:
		var jr_r = 30.0 + (1.0 - _jolly_roger_flash) * 60.0
		for i in range(5):
			var jr_a = TAU * float(i) / 5.0
			var jr_pos = Vector2.from_angle(jr_a) * jr_r
			draw_circle(jr_pos, 5.0, Color(0.15, 0.15, 0.15, _jolly_roger_flash * 0.6))
			# Crossbones lines
			draw_line(jr_pos + Vector2(-4, -4), jr_pos + Vector2(4, 4), Color(0.9, 0.9, 0.85, _jolly_roger_flash * 0.5), 1.5)
			draw_line(jr_pos + Vector2(4, -4), jr_pos + Vector2(-4, 4), Color(0.9, 0.9, 0.85, _jolly_roger_flash * 0.5), 1.5)

	# Tick-Tock flash — clock hands spinning
	if _tick_tock_flash > 0.0:
		var clock_r = 25.0
		draw_arc(Vector2.ZERO, clock_r, 0, TAU, 24, Color(0.8, 0.7, 0.2, _tick_tock_flash * 0.4), 2.0)
		var hand_a = _tick_tock_flash * TAU * 3.0  # Spinning clock hand
		draw_line(Vector2.ZERO, Vector2.from_angle(hand_a) * clock_r * 0.8, Color(0.2, 0.2, 0.2, _tick_tock_flash * 0.7), 2.0)
		draw_line(Vector2.ZERO, Vector2.from_angle(hand_a + PI / 2.0) * clock_r * 0.5, Color(0.2, 0.2, 0.2, _tick_tock_flash * 0.5), 1.5)

	# Poison flash — green drip
	if _poison_flash > 0.0:
		for i in range(5):
			var px = -10.0 + float(i) * 5.0
			var py = 10.0 + (1.0 - _poison_flash) * 15.0
			draw_circle(Vector2(px, py), 2.5, Color(0.3, 0.8, 0.15, _poison_flash * 0.6))

	# Crocodile flash — fiery ring
	if _crocodile_flash > 0.0:
		var cr_r = 30.0 + (1.0 - _crocodile_flash) * 50.0
		draw_arc(Vector2.ZERO, cr_r, 0, TAU, 32, Color(1.0, 0.35, 0.05, _crocodile_flash * 0.4), 3.0)
		for i in range(8):
			var f_a = TAU * float(i) / 8.0 + _crocodile_flash * 4.0
			var f_pos = Vector2.from_angle(f_a) * cr_r
			draw_circle(f_pos, 4.0, Color(1.0, 0.5, 0.1, _crocodile_flash * 0.5))

	# Attack flash — cutlass slash effect
	if _attack_anim > 0.0:
		var tier_scale = 1.0 + float(upgrade_tier) * 0.25
		var flash_dir = Vector2.from_angle(aim_angle)
		var flash_dist = (25.0 + (1.0 - _attack_anim) * 20.0) * tier_scale
		# Red slash arc — Hook's cutlass swipe
		var slash_start_a = aim_angle - 0.6 * _attack_anim
		var slash_end_a = aim_angle + 0.6 * _attack_anim
		var slash_r = (18.0 + (1.0 - _attack_anim) * 25.0) * tier_scale
		draw_arc(Vector2.ZERO, slash_r, slash_start_a, slash_end_a, 16, Color(0.8, 0.2, 0.15, _attack_anim * 0.6), 4.0 * tier_scale)
		draw_arc(Vector2.ZERO, slash_r * 0.75, slash_start_a + 0.1, slash_end_a - 0.1, 12, Color(0.9, 0.3, 0.2, _attack_anim * 0.35), 2.5 * tier_scale)
		# Cutlass trail — steel streak
		draw_line(flash_dir * 12.0, flash_dir * (flash_dist + 15.0), Color(0.85, 0.88, 0.95, _attack_anim * 0.7), 3.0 * tier_scale)
		draw_line(flash_dir * 14.0, flash_dir * (flash_dist + 12.0), Color(1.0, 1.0, 1.0, _attack_anim * 0.5), 1.5)
		# Impact sparkles
		var spark_count = 3 + upgrade_tier
		for si in range(spark_count):
			var s_a = aim_angle + (float(si) - float(spark_count) / 2.0) * 0.35
			var s_dist = flash_dist + sin(_time * 20.0 + float(si) * 2.5) * 6.0
			var s_pos = Vector2.from_angle(s_a) * s_dist
			draw_circle(s_pos, (2.5 + sin(_time * 15.0 + float(si)) * 1.0) * tier_scale, Color(0.9, 0.3, 0.2, _attack_anim * 0.55))

	# === PROGRESSIVE ABILITY VISUAL EFFECTS ===

	# Smee flash — healing shield
	if _smee_flash > 0.0:
		draw_arc(Vector2.ZERO, 22.0, 0, TAU, 24, Color(0.3, 0.8, 0.3, _smee_flash * 0.4), 2.5)
		draw_circle(Vector2(15, -10), 4.0, Color(0.6, 0.4, 0.3, _smee_flash * 0.6))

	# Progressive cannon flash
	if _prog_cannon_flash > 0.0:
		for i in range(4):
			var pc_a = TAU * float(i) / 4.0 + _prog_cannon_flash * 3.0
			var pc_r = 25.0 + (1.0 - _prog_cannon_flash) * 40.0
			var pc_pos = Vector2.from_angle(pc_a) * pc_r
			draw_circle(pc_pos, 5.0, Color(1.0, 0.5, 0.1, _prog_cannon_flash * 0.5))

	# Progressive fear flash
	if _prog_fear_flash > 0.0:
		var pf_r = 20.0 + (1.0 - _prog_fear_flash) * 30.0
		draw_arc(Vector2.ZERO, pf_r, 0, TAU, 24, Color(0.5, 0.1, 0.6, _prog_fear_flash * 0.4), 2.0)

	# Progressive crew flash
	if _prog_crew_flash > 0.0:
		for i in range(5):
			var cc_a = TAU * float(i) / 5.0
			var cc_pos = Vector2.from_angle(cc_a) * 35.0
			draw_circle(cc_pos, 3.5, Color(0.2, 0.2, 0.2, _prog_crew_flash * 0.5))
			draw_line(cc_pos, cc_pos + Vector2.from_angle(cc_a) * 8.0, Color(0.7, 0.7, 0.75, _prog_crew_flash * 0.4), 1.5)

	# Progressive burn flash
	if _prog_burn_flash > 0.0:
		var pb_r = 25.0 + (1.0 - _prog_burn_flash) * 45.0
		draw_arc(Vector2.ZERO, pb_r, 0, TAU, 32, Color(1.0, 0.3, 0.05, _prog_burn_flash * 0.3), 2.5)
		for i in range(6):
			var fb_a = TAU * float(i) / 6.0 + _prog_burn_flash * 5.0
			var fb_pos = Vector2.from_angle(fb_a) * pb_r
			draw_circle(fb_pos, 3.0, Color(1.0, 0.6, 0.1, _prog_burn_flash * 0.5))

	# Smee shield indicator (persistent when active)
	if _smee_shield > 0.0:
		var shield_alpha = 0.15 + sin(_time * 3.0) * 0.05
		draw_arc(Vector2.ZERO, 26.0, 0, TAU, 24, Color(0.3, 0.9, 0.3, shield_alpha), 2.0)

	# === STONE PLATFORM (Bloons-style placed tower base) ===
	var plat_y = 22.0
	# Platform shadow
	draw_circle(Vector2(0, plat_y + 4), 28.0, Color(0, 0, 0, 0.15))
	# Stone platform ellipse
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

	# Shadow tendrils from platform edges (gothic)
	for ti in range(5):
		var ta = TAU * float(ti) / 5.0 + _time * 0.3
		var t_base = Vector2(cos(ta) * 24.0, plat_y + sin(ta) * 8.0)
		var t_end = t_base + Vector2(sin(_time * 0.8 + float(ti)) * 6.0, 8.0 + sin(_time * 1.2 + float(ti)) * 4.0)
		draw_line(t_base, t_end, Color(0.04, 0.02, 0.06, 0.2), 2.0)
		draw_line(t_end, t_end + Vector2(sin(_time + float(ti)) * 3.0, 5.0), Color(0.04, 0.02, 0.06, 0.1), 1.5)

	# Tier pips on platform edge
	for i in range(upgrade_tier):
		var pip_angle = -PI / 2.0 + float(i) * (TAU / 4.0) - (float(upgrade_tier - 1) * TAU / 8.0)
		var pip_pos = Vector2(cos(pip_angle) * 22.0, plat_y + sin(pip_angle) * 8.0)
		var pip_col: Color
		match i:
			0: pip_col = Color(0.5, 0.15, 0.15)
			1: pip_col = Color(0.7, 0.2, 0.1)
			2: pip_col = Color(0.85, 0.25, 0.1)
			3: pip_col = Color(0.9, 0.3, 0.15)
			_: pip_col = Color(0.6, 0.2, 0.2)
		draw_circle(pip_pos, 4.0, pip_col)
		draw_circle(pip_pos, 5.5, Color(pip_col.r, pip_col.g, pip_col.b, 0.15))

	# === SPRITE RENDERING (animated — menacing & imposing) ===
	if sprite_texture:
		var _active_tex = sprite_texture
		if _attack_anim > 0.5 and _sprite_attack:
			_active_tex = _sprite_attack
		elif _attack_anim > 0.15 and _sprite_shoot:
			_active_tex = _sprite_shoot
		elif _flair_active > 0.0 and _flair_current:
			_active_tex = _flair_current
		var _ss = Vector2(sprite_texture.get_width(), sprite_texture.get_height())
		var _sf = 120.0 / _ss.y
		var _sd = _ss * _sf
		var breathe_scl = 1.0 + sin(_time * 1.5) * 0.008
		var sway_rot = sin(_time * 1.0) * 0.010
		var s_aim_lean = sin(aim_angle) * 0.012
		var recoil_off = Vector2.ZERO
		var atk_scl = Vector2.ONE
		if _attack_anim > 0.0:
			var swing_t = clampf(_attack_anim * 2.0, 0.0, 1.0)
			sway_rot += sin(swing_t * PI) * 0.05
			recoil_off = Vector2(0, -swing_t * 0.5)
		var total_rot = sway_rot + s_aim_lean
		var total_scl = Vector2(breathe_scl, breathe_scl) * atk_scl
		var _fl = cos(aim_angle) < 0.0
		if _fl:
			total_scl.x *= -1.0
			total_rot *= -1.0
		var anchor = body_offset + Vector2(0, 10.0) + recoil_off
		draw_set_transform(anchor, total_rot, total_scl)
		draw_texture_rect(_active_tex, Rect2(-_sd.x / 2.0, -_sd.y, _sd.x, _sd.y), false)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	if not sprite_texture:
		# === FALLBACK PROCEDURAL CHARACTER (chibi Bloons TD proportions ~48px) ===
		var feet_y = body_offset + Vector2(lean * 0.8, 10.0)
		var leg_top = body_offset + Vector2(lean * 0.5, 0.0)
		var torso_center = body_offset + Vector2(lean * 0.3, -8.0)
		var neck_base = body_offset + Vector2(-lean * 0.2, -14.0)
		var head_center = body_offset + Vector2(-lean * 0.4, -26.0)
		var OL = Color(0.06, 0.06, 0.08)

		# Skin colors
		var skin_base = Color(0.91, 0.74, 0.58)
		var skin_shadow = Color(0.78, 0.60, 0.45)

		# Costume colors — crimson pirate coat
		var coat_dark = Color(0.50, 0.08, 0.08)
		var coat_mid = Color(0.65, 0.12, 0.10)
		var coat_light = Color(0.75, 0.18, 0.14)
		var boot_color = Color(0.15, 0.12, 0.10)
		var gold_trim = Color(0.85, 0.70, 0.15)

		# --- Tall boots ---
		var l_foot = feet_y + Vector2(-5, 0)
		var r_foot = feet_y + Vector2(5, 0)
		draw_circle(l_foot, 5.0, OL)
		draw_circle(l_foot, 3.5, boot_color)
		draw_circle(r_foot, 5.0, OL)
		draw_circle(r_foot, 3.5, boot_color)
		# Boot tops (gold buckle)
		draw_circle(l_foot + Vector2(0, -4), 2.0, gold_trim)
		draw_circle(r_foot + Vector2(0, -4), 2.0, gold_trim)

		# --- Legs ---
		var l_hip = leg_top + Vector2(-4, 0)
		var r_hip = leg_top + Vector2(4, 0)
		draw_line(l_hip, l_foot, OL, 6.5)
		draw_line(r_hip, r_foot, OL, 6.5)
		draw_line(l_hip, l_foot, coat_dark, 4.5)
		draw_line(r_hip, r_foot, coat_dark, 4.5)

		# --- Crimson coat body ---
		var tunic_top_l = neck_base + Vector2(-11, 0)
		var tunic_top_r = neck_base + Vector2(11, 0)
		var tunic_bot_l = leg_top + Vector2(-9, 2)
		var tunic_bot_r = leg_top + Vector2(9, 2)
		var tunic_ol = PackedVector2Array([
			tunic_top_l + Vector2(-1.5, -1), tunic_top_r + Vector2(1.5, -1),
			tunic_bot_r + Vector2(1.5, 1), tunic_bot_l + Vector2(-1.5, 1),
		])
		draw_colored_polygon(tunic_ol, OL)
		var tunic_pts = PackedVector2Array([
			tunic_top_l, tunic_top_r, tunic_bot_r, tunic_bot_l,
		])
		draw_colored_polygon(tunic_pts, coat_mid)
		# Gold buttons down center
		for bi in range(3):
			var btn_y = torso_center.y - 3.0 + float(bi) * 4.0
			draw_circle(Vector2(torso_center.x, btn_y), 1.5, OL)
			draw_circle(Vector2(torso_center.x, btn_y), 1.0, gold_trim)
		# Gold trim on coat edges
		draw_line(tunic_top_l, tunic_bot_l, gold_trim, 1.0)
		draw_line(tunic_top_r, tunic_bot_r, gold_trim, 1.0)

		# --- Epaulettes (shoulder pads) ---
		draw_circle(neck_base + Vector2(-12, 1), 4.0, OL)
		draw_circle(neck_base + Vector2(-12, 1), 3.0, gold_trim)
		draw_circle(neck_base + Vector2(12, 1), 4.0, OL)
		draw_circle(neck_base + Vector2(12, 1), 3.0, gold_trim)

		# --- Arms ---
		# Left arm (normal hand)
		var l_shoulder = neck_base + Vector2(-10, 2)
		var l_hand = torso_center + Vector2(-16, 6)
		draw_line(l_shoulder, l_hand, OL, 5.0)
		draw_line(l_shoulder, l_hand, coat_mid, 3.5)
		# Hand
		draw_circle(l_hand, 3.5, OL)
		draw_circle(l_hand, 2.5, skin_base)
		# Cutlass in left hand
		var cutlass_end = l_hand + Vector2.from_angle(aim_angle) * 14.0
		draw_line(l_hand, cutlass_end, OL, 3.5)
		draw_line(l_hand, cutlass_end, Color(0.75, 0.78, 0.82), 2.0)
		# Cutlass guard
		var guard_perp = Vector2.from_angle(aim_angle + PI / 2.0) * 4.0
		draw_line(l_hand - guard_perp, l_hand + guard_perp, gold_trim, 2.0)

		# Right arm (THE HOOK)
		var r_shoulder = neck_base + Vector2(10, 2)
		var r_wrist = torso_center + Vector2(16, 6)
		draw_line(r_shoulder, r_wrist, OL, 5.0)
		draw_line(r_shoulder, r_wrist, coat_mid, 3.5)
		# Iron hook
		draw_circle(r_wrist, 3.5, OL)
		draw_circle(r_wrist, 2.5, Color(0.5, 0.5, 0.55))
		var hook_tip = r_wrist + Vector2(4, 8)
		var hook_curve = r_wrist + Vector2(8, 4)
		draw_line(r_wrist, hook_tip, Color(0.6, 0.6, 0.65), 2.5)
		draw_line(hook_tip, hook_curve, Color(0.6, 0.6, 0.65), 2.5)
		draw_line(hook_curve, hook_curve + Vector2(-2, -4), Color(0.6, 0.6, 0.65), 2.5)

		# --- Head ---
		# Neck
		draw_line(neck_base, head_center + Vector2(0, 8), OL, 4.5)
		draw_line(neck_base, head_center + Vector2(0, 8), skin_shadow, 3.0)
		# Head circle
		draw_circle(head_center, 12.0, OL)
		draw_circle(head_center, 10.5, skin_base)
		# Eyes — menacing
		draw_circle(head_center + Vector2(-4, -2), 2.5, Color(1, 1, 1))
		draw_circle(head_center + Vector2(4, -2), 2.5, Color(1, 1, 1))
		draw_circle(head_center + Vector2(-4, -2), 1.2, Color(0.2, 0.1, 0.1))
		draw_circle(head_center + Vector2(4, -2), 1.2, Color(0.2, 0.1, 0.1))
		# Eyebrows — angry slant
		draw_line(head_center + Vector2(-7, -5), head_center + Vector2(-2, -4), OL, 1.5)
		draw_line(head_center + Vector2(7, -5), head_center + Vector2(2, -4), OL, 1.5)
		# Thin mustache
		draw_line(head_center + Vector2(-3, 2), head_center + Vector2(-8, 0), OL, 1.2)
		draw_line(head_center + Vector2(3, 2), head_center + Vector2(8, 0), OL, 1.2)
		# Goatee
		draw_line(head_center + Vector2(0, 4), head_center + Vector2(0, 9), OL, 1.5)

		# --- Captain's Hat (large feathered tricorn) ---
		var hat_base = head_center + Vector2(0, -8)
		var hat_pts = PackedVector2Array([
			hat_base + Vector2(-14, 2), hat_base + Vector2(-8, -6),
			hat_base + Vector2(0, -8), hat_base + Vector2(8, -6),
			hat_base + Vector2(14, 2), hat_base + Vector2(0, 4),
		])
		draw_colored_polygon(hat_pts, OL)
		var hat_inner = PackedVector2Array([
			hat_base + Vector2(-12, 1), hat_base + Vector2(-7, -5),
			hat_base + Vector2(0, -6), hat_base + Vector2(7, -5),
			hat_base + Vector2(12, 1), hat_base + Vector2(0, 3),
		])
		draw_colored_polygon(hat_inner, coat_dark)
		# Gold hat band
		draw_line(hat_base + Vector2(-12, 1), hat_base + Vector2(12, 1), gold_trim, 1.5)
		# Skull emblem on hat
		draw_circle(hat_base + Vector2(0, -2), 2.5, Color(0.9, 0.9, 0.85))
		draw_circle(hat_base + Vector2(-1, -2.5), 0.7, OL)
		draw_circle(hat_base + Vector2(1, -2.5), 0.7, OL)
		# Red feather plume
		var feather_base = hat_base + Vector2(8, -5)
		draw_line(feather_base, feather_base + Vector2(6, -12), coat_light, 3.0)
		draw_line(feather_base + Vector2(6, -12), feather_base + Vector2(10, -8), coat_light, 2.0)

	# Active ability cooldown indicator
	var cd_fill = 0.0
	if not active_ability_ready:
		cd_fill = active_ability_cooldown / active_ability_max_cd
	if active_ability_ready:
		var cd_pulse = 0.5 + sin(_time * 4.0) * 0.3
		pass
	elif cd_fill > 0.0:
		draw_arc(Vector2.ZERO, 28.0, -PI / 2.0, -PI / 2.0 + TAU * cd_fill, 32, Color(0.8, 0.2, 0.1, 0.3), 2.0)
	_draw_tower_aura()

# === SYNERGY BUFF INTERFACE ===

func set_synergy_buff(buffs: Dictionary) -> void:
	for key in buffs:
		_synergy_buffs[key] = _synergy_buffs.get(key, 0.0) + buffs[key]

func clear_synergy_buff() -> void:
	_synergy_buffs.clear()

func set_meta_buffs(buffs: Dictionary) -> void:
	_meta_buffs = buffs

func has_synergy_buff() -> bool:
	return not _synergy_buffs.is_empty()

func _damage_mult() -> float:
	return (1.0 + _synergy_buffs.get("damage", 0.0) + _meta_buffs.get("damage", 0.0)) * power_damage_mult

func _range_mult() -> float:
	return 1.0 + _synergy_buffs.get("range", 0.0) + _meta_buffs.get("range", 0.0)

func _speed_mult() -> float:
	return 1.0 + _synergy_buffs.get("attack_speed", 0.0) + _meta_buffs.get("attack_speed", 0.0)

func _gold_mult() -> float:
	return 1.0 + _synergy_buffs.get("gold_bonus", 0.0) + _meta_buffs.get("gold_bonus", 0.0)
