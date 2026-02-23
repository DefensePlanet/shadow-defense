extends Node2D
## Peter Pan — stationary striker from JM Barrie's Peter and Wendy (1911).
## Hovers in place, throwing daggers rapidly at nearby enemies.
## Tier 1 (5000 DMG): "Shadow" — fires a shadow dagger at a 2nd target each shot
## Tier 2 (10000 DMG): "Fairy Dust" — periodic sparkle AoE (damage + slow)
## Tier 3 (15000 DMG): "Tick-Tock Croc" — periodically chomps strongest enemy for 3x damage
## Tier 4 (20000 DMG): "Never Land" — daggers pierce, all stats boosted, gold bonus doubled

var damage: float = 38.0
var fire_rate: float = 2.5
var attack_range: float = 170.0
var fire_cooldown: float = 0.0
var aim_angle: float = 0.0
var target: Node2D = null
var gold_bonus: int = 2

# Stationary striker — stays in place, attacks from position
var _home_position: Vector2 = Vector2.ZERO

# Damage tracking and upgrades
var damage_dealt: float = 0.0
var upgrade_tier: int = 0
var _upgrade_flash: float = 0.0
var _upgrade_name: String = ""

# Animation variables
var _time: float = 0.0
var _attack_anim: float = 0.0

# Tier 1: Shadow — second dagger
var shadow_enabled: bool = false

# Tier 2: Fairy Dust — AoE burst
var fairy_timer: float = 0.0
var fairy_cooldown: float = 12.0
var _fairy_flash: float = 0.0

# Tier 3: Tick-Tock Croc — chomp strongest
var croc_timer: float = 0.0
var croc_cooldown: float = 15.0
var _croc_flash: float = 0.0

# Tier 4: Never Land
var pierce_count: int = 0

const STAT_UPGRADE_INTERVAL: float = 500.0
const ABILITY_THRESHOLD: float = 1500.0
var stat_upgrade_level: int = 0
var ability_chosen: bool = false
var awaiting_ability_choice: bool = false
const TIER_NAMES = [
	"Shadow",
	"Fairy Dust",
	"Tick-Tock Croc",
	"Never Land"
]
const ABILITY_DESCRIPTIONS = [
	"Shadow dagger at a 2nd target each shot",
	"Periodic sparkle AoE (damage + slow)",
	"Chomps strongest enemy for 3x damage",
	"Daggers pierce, all stats boosted"
]
const TIER_COSTS = [75, 165, 280, 480]
var is_selected: bool = false
var base_cost: int = 0

var dagger_scene = preload("res://scenes/peter_dagger.tscn")

# Attack sounds — flute melody evolving with upgrade tier
var _attack_sounds: Array = []
var _attack_sounds_by_tier: Array = []
var _attack_player: AudioStreamPlayer

# Ability sounds
var _fairy_sound: AudioStreamWAV
var _fairy_player: AudioStreamPlayer
var _croc_sound: AudioStreamWAV
var _croc_player: AudioStreamPlayer
var _upgrade_sound: AudioStreamWAV
var _upgrade_player: AudioStreamPlayer

# === PROGRESSIVE ABILITIES (9 tiers, unlocked via lifetime damage) ===
const PROG_ABILITY_NAMES = [
	"Flying Strikes", "The Lost Boys", "Fairy Dust Trail", "Mermaid's Song",
	"Walk the Plank", "Tick-Tock the Crocodile", "Tinker Bell's Light",
	"Neverland Flight", "Pan's Shadow"
]
const PROG_ABILITY_DESCS = [
	"Strike 30% faster, +15% dagger damage",
	"2 lost boys orbit Peter, auto-attacking nearby enemies every 2s",
	"Every 12s, Tinker Bell flies across range leaving dust that slows enemies 50% for 2s",
	"Every 18s, a mermaid charms 3 enemies — frozen + 2x damage for 3s",
	"Every 20s, a plank appears under the weakest enemy — instant kill",
	"Every 10th kill, the crocodile devours the strongest enemy on map",
	"Tinker Bell boosts nearby tower fire rates by 25% every 5s",
	"Every 15s, Peter throws daggers at 8 random enemies across the map for 2x damage",
	"Peter's shadow detaches and roams the map, striking enemies for 2x damage every 1s"
]
var prog_abilities: Array = [false, false, false, false, false, false, false, false, false]
# Ability timers
var _lost_boys_timer: float = 2.0
var _fairy_dust_trail_timer: float = 12.0
var _mermaid_song_timer: float = 18.0
var _walk_the_plank_timer: float = 20.0
var _prog_kill_count: int = 0
var _tinker_light_timer: float = 5.0
var _neverland_flight_timer: float = 15.0
var _pan_shadow_node: Node2D = null
# Visual flash timers
var _lost_boys_flash: float = 0.0
var _fairy_dust_trail_flash: float = 0.0
var _mermaid_song_flash: float = 0.0
var _walk_plank_flash: float = 0.0
var _croc_devour_flash: float = 0.0
var _tinker_light_flash: float = 0.0
var _neverland_flight_flash: float = 0.0

func _ready() -> void:
	add_to_group("towers")
	_generate_tier_sounds()
	_attack_sounds = _attack_sounds_by_tier[0]
	_attack_player = AudioStreamPlayer.new()
	_attack_player.stream = _attack_sounds[0]
	_attack_player.volume_db = -4.0
	add_child(_attack_player)

	# Fairy dust — cascading descending sparkle chimes (C7→C6)
	var fd_rate := 22050
	var fd_dur := 0.5
	var fd_samples := PackedFloat32Array()
	fd_samples.resize(int(fd_rate * fd_dur))
	for i in fd_samples.size():
		var t := float(i) / fd_rate
		var freq := lerpf(2093.0, 1046.5, t / fd_dur)  # C7 to C6
		var sparkle := sin(TAU * freq * t) * 0.3 + sin(TAU * freq * 1.5 * t) * 0.15
		var shimmer := sin(TAU * freq * 3.0 * t) * 0.08
		var pulse := 0.5 + 0.5 * sin(TAU * 14.0 * t)
		var env := (1.0 - t / fd_dur) * 0.5
		fd_samples[i] = clampf((sparkle + shimmer) * pulse * env, -1.0, 1.0)
	_fairy_sound = _samples_to_wav(fd_samples, fd_rate)
	_fairy_player = AudioStreamPlayer.new()
	_fairy_player.stream = _fairy_sound
	_fairy_player.volume_db = -6.0
	add_child(_fairy_player)

	# Croc chomp — tick-tick-SNAP
	var cr_rate := 22050
	var cr_dur := 0.35
	var cr_samples := PackedFloat32Array()
	cr_samples.resize(int(cr_rate * cr_dur))
	var tick_times := [0.0, 0.1]
	for i in cr_samples.size():
		var t := float(i) / cr_rate
		var s := 0.0
		# Two ticks
		for tt in tick_times:
			var dt: float = t - tt
			if dt >= 0.0 and dt < 0.04:
				s += sin(TAU * 1800.0 * dt) * exp(-dt * 80.0) * 0.4
		# Heavy jaw snap at 0.2s
		var snap_dt := t - 0.2
		if snap_dt >= 0.0 and snap_dt < 0.12:
			var snap_env := exp(-snap_dt * 25.0) * 0.6
			s += (sin(TAU * 200.0 * snap_dt) + (randf() * 2.0 - 1.0) * 0.4) * snap_env
		cr_samples[i] = clampf(s, -1.0, 1.0)
	_croc_sound = _samples_to_wav(cr_samples, cr_rate)
	_croc_player = AudioStreamPlayer.new()
	_croc_player.stream = _croc_sound
	_croc_player.volume_db = -6.0
	add_child(_croc_player)

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
	_home_position = global_position
	_load_progressive_abilities()

func _process(delta: float) -> void:
	_time += delta
	_attack_anim = max(_attack_anim - delta * 3.0, 0.0)
	_upgrade_flash = max(_upgrade_flash - delta * 0.5, 0.0)
	_fairy_flash = max(_fairy_flash - delta * 2.0, 0.0)
	_croc_flash = max(_croc_flash - delta * 2.0, 0.0)

	# Stationary attack — stays in place, strikes enemies in range
	fire_cooldown -= delta
	target = _find_nearest_enemy()
	if target:
		var desired = _home_position.angle_to_point(target.global_position) + PI
		aim_angle = lerp_angle(aim_angle, desired, 12.0 * delta)
		if fire_cooldown <= 0.0:
			_strike_target(target)
			fire_cooldown = 1.0 / (fire_rate * _speed_mult())

	# Tier 2: Fairy Dust AoE
	if upgrade_tier >= 2:
		fairy_timer -= delta
		if fairy_timer <= 0.0 and _has_enemies_in_range():
			_fairy_dust()
			fairy_timer = fairy_cooldown

	# Tier 3: Tick-Tock Croc
	if upgrade_tier >= 3:
		croc_timer -= delta
		if croc_timer <= 0.0 and _has_enemies_in_range():
			_croc_chomp()
			croc_timer = croc_cooldown

	# Progressive abilities
	_process_progressive_abilities(delta)

	queue_redraw()

func _has_enemies_in_range() -> bool:
	var eff_range = attack_range * _range_mult()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if _home_position.distance_to(enemy.global_position) < eff_range:
			return true
	return false

func _find_nearest_enemy() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist: float = attack_range * _range_mult()
	for enemy in enemies:
		var dist = _home_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest = enemy
			nearest_dist = dist
	return nearest

func _find_second_target(exclude: Node2D) -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist: float = attack_range
	for enemy in enemies:
		if enemy == exclude:
			continue
		var dist = _home_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest = enemy
			nearest_dist = dist
	return nearest

func _find_strongest_enemy() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var strongest: Node2D = null
	var most_hp: float = 0.0
	for enemy in enemies:
		if _home_position.distance_to(enemy.global_position) < attack_range:
			if enemy.health > most_hp:
				strongest = enemy
				most_hp = enemy.health
	return strongest

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
	_attack_anim = 1.0
	var dmg = damage * _damage_mult()
	if prog_abilities[0]:  # Flying Strikes: +15% damage
		dmg *= 1.15
	var will_kill = t.health - dmg <= 0.0
	t.take_damage(dmg)
	register_damage(dmg)
	var eff_gold = int(gold_bonus * _gold_mult())
	if will_kill and eff_gold > 0:
		var main = get_tree().get_first_node_in_group("main")
		if main:
			main.add_gold(eff_gold)
	# Shadow strike on second target (Tier 1)
	if shadow_enabled:
		var second = _find_second_target(t)
		if second and second.has_method("take_damage"):
			var sdmg = dmg * 0.6
			var swill = second.health - sdmg <= 0.0
			second.take_damage(sdmg)
			register_damage(sdmg)
			if swill and gold_bonus > 0:
				var main2 = get_tree().get_first_node_in_group("main")
				if main2:
					main2.add_gold(gold_bonus)

func _fairy_dust() -> void:
	if _fairy_player and not _is_sfx_muted(): _fairy_player.play()
	_fairy_flash = 1.0
	var fairy_dmg = damage * 0.5
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if _home_position.distance_to(enemy.global_position) < attack_range * 0.7:
			if enemy.has_method("take_damage"):
				var will_kill = enemy.health - fairy_dmg <= 0.0
				enemy.take_damage(fairy_dmg)
				register_damage(fairy_dmg)
				if is_instance_valid(enemy) and enemy.has_method("apply_slow"):
					enemy.apply_slow(0.65, 1.5)
				if will_kill:
					if gold_bonus > 0:
						var main = get_tree().get_first_node_in_group("main")
						if main:
							main.add_gold(gold_bonus)

func _croc_chomp() -> void:
	if _croc_player and not _is_sfx_muted(): _croc_player.play()
	_croc_flash = 1.0
	var strongest = _find_strongest_enemy()
	if strongest and strongest.has_method("take_damage"):
		var chomp_dmg = damage * 3.0
		var will_kill = strongest.health - chomp_dmg <= 0.0
		strongest.take_damage(chomp_dmg)
		register_damage(chomp_dmg)
		if will_kill:
			if gold_bonus > 0:
				var main = get_tree().get_first_node_in_group("main")
				if main:
					main.add_gold(gold_bonus)

func register_damage(amount: float) -> void:
	damage_dealt += amount
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("register_tower_damage"):
		main.register_tower_damage(main.TowerType.PETER_PAN, amount)

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
	fire_rate *= 1.10
	attack_range += 6.0

func choose_ability(index: int) -> void:
	ability_chosen = true
	awaiting_ability_choice = false
	upgrade_tier = index + 1
	_apply_upgrade(upgrade_tier)
	_upgrade_flash = 3.0
	_upgrade_name = TIER_NAMES[index]

func _apply_upgrade(tier: int) -> void:
	match tier:
		1: # Shadow — double daggers
			shadow_enabled = true
			damage = 50.0
			fire_rate = 3.0
			attack_range = 185.0
		2: # Fairy Dust — AoE slow burst
			damage = 60.0
			fire_rate = 3.5
			attack_range = 200.0
			fairy_cooldown = 10.0
			gold_bonus = 3
		3: # Tick-Tock Croc — chomp strongest
			damage = 75.0
			fire_rate = 4.0
			attack_range = 220.0
			croc_cooldown = 10.0
			fairy_cooldown = 8.0
			gold_bonus = 4
		4: # Never Land — everything enhanced
			damage = 95.0
			fire_rate = 5.0
			pierce_count = 2
			attack_range = 250.0
			gold_bonus = 5
			fairy_cooldown = 6.0
			croc_cooldown = 7.0

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
	return "Peter Pan"

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
	# Dagger blade swish — sharp, quick, metallic shing with fairy sparkle
	var ring_freqs := [587.33, 698.46, 880.00, 1174.66, 880.00, 698.46, 587.33, 783.99]  # D5, F5, A5, D6, A5, F5, D5, G5 (D minor fairy bell arpeggio)
	var mix_rate := 44100
	_attack_sounds_by_tier = []

	# --- Tier 0: Quick Blade Swish (sharp metallic shing) ---
	var t0 := []
	for note_idx in ring_freqs.size():
		var rf: float = ring_freqs[note_idx]
		var dur := 0.12
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * dur))
		for i in samples.size():
			var t := float(i) / mix_rate
			var tn := t / dur
			# Air displacement whoosh
			var whoosh_env := exp(-t * 28.0)
			var whoosh := (randf() * 2.0 - 1.0) * 0.25 * whoosh_env
			# Swept resonance gives the whoosh direction
			var sweep_f := lerpf(3500.0, 1000.0, tn)
			whoosh += sin(TAU * sweep_f * t) * 0.12 * whoosh_env
			# Sharp metallic ring — the blade shing
			var ring := sin(TAU * rf * t) * exp(-t * 45.0) * 0.3
			# Inharmonic overtone for metallic quality
			ring += sin(TAU * rf * 2.37 * t) * exp(-t * 60.0) * 0.12
			samples[i] = clampf(whoosh + ring, -1.0, 1.0)
		t0.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t0)

	# --- Tier 1: Sharpened Blade (brighter ring + fairy sparkle) ---
	var t1 := []
	for note_idx in ring_freqs.size():
		var rf: float = ring_freqs[note_idx]
		var dur := 0.14
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * dur))
		for i in samples.size():
			var t := float(i) / mix_rate
			var tn := t / dur
			var whoosh_env := exp(-t * 32.0)
			var whoosh := (randf() * 2.0 - 1.0) * 0.22 * whoosh_env
			var sweep_f := lerpf(4000.0, 1200.0, tn)
			whoosh += sin(TAU * sweep_f * t) * 0.14 * whoosh_env
			# Brighter ring
			var ring := sin(TAU * rf * t) * exp(-t * 40.0) * 0.32
			ring += sin(TAU * rf * 2.37 * t) * exp(-t * 55.0) * 0.14
			# Fairy sparkle — high-pitched tinkle
			var sparkle := sin(TAU * rf * 3.0 * t) * exp(-t * 70.0) * 0.08
			sparkle += sin(TAU * rf * 4.2 * t) * exp(-t * 80.0) * 0.05
			samples[i] = clampf(whoosh + ring + sparkle, -1.0, 1.0)
		t1.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t1)

	# --- Tier 2: Shadow Blade (darker tone, faint echo) ---
	var t2 := []
	for note_idx in ring_freqs.size():
		var rf: float = ring_freqs[note_idx]
		var dur := 0.18
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * dur))
		for i in samples.size():
			var t := float(i) / mix_rate
			var tn := t / dur
			var whoosh_env := exp(-t * 22.0)
			var whoosh := (randf() * 2.0 - 1.0) * 0.28 * whoosh_env
			var sweep_f := lerpf(3000.0, 600.0, tn)
			whoosh += sin(TAU * sweep_f * t) * 0.16 * whoosh_env
			# Darker metallic ring
			var ring := sin(TAU * rf * t) * exp(-t * 30.0) * 0.3
			ring += sin(TAU * rf * 1.5 * t) * exp(-t * 35.0) * 0.18
			ring += sin(TAU * rf * 2.37 * t) * exp(-t * 45.0) * 0.1
			# Shadow echo — delayed quiet ring
			var echo_t := maxf(t - 0.06, 0.0)
			var echo := sin(TAU * rf * 0.75 * echo_t) * exp(-echo_t * 25.0) * 0.12
			samples[i] = clampf(whoosh + ring + echo, -1.0, 1.0)
		t2.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t2)

	# --- Tier 3: Enchanted Blade (rich ring + fairy tinkle shower) ---
	var t3 := []
	for note_idx in ring_freqs.size():
		var rf: float = ring_freqs[note_idx]
		var dur := 0.2
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * dur))
		for i in samples.size():
			var t := float(i) / mix_rate
			var tn := t / dur
			var whoosh_env := exp(-t * 26.0)
			var whoosh := (randf() * 2.0 - 1.0) * 0.24 * whoosh_env
			var sweep_f := lerpf(4500.0, 1000.0, tn)
			whoosh += sin(TAU * sweep_f * t) * 0.15 * whoosh_env
			# Rich metallic ring with harmonics
			var ring := sin(TAU * rf * t) * exp(-t * 28.0) * 0.3
			ring += sin(TAU * rf * 1.5 * t) * exp(-t * 32.0) * 0.15
			ring += sin(TAU * rf * 2.0 * t) * exp(-t * 38.0) * 0.12
			ring += sin(TAU * rf * 2.37 * t) * exp(-t * 50.0) * 0.08
			# Fairy sparkle shower — multiple high-freq tinkles
			var sparkle := sin(TAU * rf * 3.5 * t) * exp(-t * 40.0) * 0.1
			sparkle += sin(TAU * rf * 4.7 * t) * exp(-t * 50.0) * 0.07
			sparkle += sin(TAU * rf * 5.3 * t) * exp(-t * 60.0) * 0.05
			samples[i] = clampf(whoosh + ring + sparkle, -1.0, 1.0)
		t3.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t3)

	# --- Tier 4: Master's Blade (full crystalline ring + fairy cascade) ---
	var t4 := []
	for note_idx in ring_freqs.size():
		var rf: float = ring_freqs[note_idx]
		var dur := 0.22
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * dur))
		for i in samples.size():
			var t := float(i) / mix_rate
			var tn := t / dur
			var whoosh_env := exp(-t * 24.0)
			var whoosh := (randf() * 2.0 - 1.0) * 0.26 * whoosh_env
			var sweep_f := lerpf(5000.0, 1200.0, tn)
			whoosh += sin(TAU * sweep_f * t) * 0.16 * whoosh_env
			# Full metallic ring — rich harmonics
			var ring := sin(TAU * rf * t) * exp(-t * 22.0) * 0.28
			ring += sin(TAU * rf * 1.5 * t) * exp(-t * 26.0) * 0.16
			ring += sin(TAU * rf * 2.0 * t) * exp(-t * 30.0) * 0.12
			ring += sin(TAU * rf * 2.37 * t) * exp(-t * 40.0) * 0.08
			ring += sin(TAU * rf * 3.0 * t) * exp(-t * 45.0) * 0.06
			# Fairy dust cascade — staggered sparkles
			var s1 := sin(TAU * rf * 4.0 * t) * exp(-t * 35.0) * 0.1
			var et2 := maxf(t - 0.03, 0.0)
			var s2 := sin(TAU * rf * 5.0 * et2) * exp(-et2 * 40.0) * 0.07
			var et3 := maxf(t - 0.06, 0.0)
			var s3 := sin(TAU * rf * 6.0 * et3) * exp(-et3 * 50.0) * 0.05
			samples[i] = clampf(whoosh + ring + s1 + s2 + s3, -1.0, 1.0)
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
	if main and main.survivor_progress.has(main.TowerType.PETER_PAN):
		var p = main.survivor_progress[main.TowerType.PETER_PAN]
		var unlocked = p.get("abilities_unlocked", [])
		for i in range(mini(9, unlocked.size())):
			if unlocked[i]:
				activate_progressive_ability(i)

func activate_progressive_ability(index: int) -> void:
	if index < 0 or index >= 9:
		return
	prog_abilities[index] = true
	# Ability 1: Flying Strikes — 30% faster attacks
	if index == 0:
		fire_rate *= 1.3
	# Ability 9: Pan's Shadow — spawn shadow node
	if index == 8 and _pan_shadow_node == null:
		var shadow_script = preload("res://scripts/pan_shadow.gd")
		var shadow_node = Node2D.new()
		shadow_node.set_script(shadow_script)
		shadow_node.source_tower = self
		shadow_node.global_position = global_position
		var main_node = get_tree().get_first_node_in_group("main")
		if main_node:
			main_node.add_child(shadow_node)
			_pan_shadow_node = shadow_node

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
	_lost_boys_flash = max(_lost_boys_flash - delta * 2.0, 0.0)
	_fairy_dust_trail_flash = max(_fairy_dust_trail_flash - delta * 1.5, 0.0)
	_mermaid_song_flash = max(_mermaid_song_flash - delta * 1.5, 0.0)
	_walk_plank_flash = max(_walk_plank_flash - delta * 1.5, 0.0)
	_croc_devour_flash = max(_croc_devour_flash - delta * 1.5, 0.0)
	_tinker_light_flash = max(_tinker_light_flash - delta * 2.0, 0.0)
	_neverland_flight_flash = max(_neverland_flight_flash - delta * 1.5, 0.0)

	# Ability 2: The Lost Boys — auto-attack nearby enemies every 2s
	if prog_abilities[1]:
		_lost_boys_timer -= delta
		if _lost_boys_timer <= 0.0 and _has_enemies_in_range():
			_lost_boys_attack()
			_lost_boys_timer = 2.0

	# Ability 3: Fairy Dust Trail — Tinker Bell flies across leaving slow dust every 12s
	if prog_abilities[2]:
		_fairy_dust_trail_timer -= delta
		if _fairy_dust_trail_timer <= 0.0 and _has_enemies_in_range():
			_fairy_dust_trail()
			_fairy_dust_trail_timer = 12.0

	# Ability 4: Mermaid's Song — charm 3 enemies every 18s
	if prog_abilities[3]:
		_mermaid_song_timer -= delta
		if _mermaid_song_timer <= 0.0 and _has_enemies_in_range():
			_mermaid_song()
			_mermaid_song_timer = 18.0

	# Ability 5: Walk the Plank — instant kill weakest enemy every 20s
	if prog_abilities[4]:
		_walk_the_plank_timer -= delta
		if _walk_the_plank_timer <= 0.0 and _has_enemies_in_range():
			_walk_the_plank()
			_walk_the_plank_timer = 20.0

	# Ability 7: Tinker Bell's Light — boost nearby tower fire rates every 5s
	if prog_abilities[6]:
		_tinker_light_timer -= delta
		if _tinker_light_timer <= 0.0:
			_tinker_bell_light()
			_tinker_light_timer = 5.0

	# Ability 8: Neverland Flight — throw 8 daggers at random enemies on map every 15s
	if prog_abilities[7]:
		_neverland_flight_timer -= delta
		if _neverland_flight_timer <= 0.0:
			_neverland_flight()
			_neverland_flight_timer = 15.0

func register_kill_progressive() -> void:
	# Ability 6: Tick-Tock the Crocodile — every 10th kill, devour strongest
	if prog_abilities[5]:
		_prog_kill_count += 1
		if _prog_kill_count >= 10:
			_prog_kill_count = 0
			_croc_devour()

func _lost_boys_attack() -> void:
	_lost_boys_flash = 1.0
	var enemies = get_tree().get_nodes_in_group("enemies")
	var in_range: Array = []
	for e in enemies:
		if _home_position.distance_to(e.global_position) < attack_range:
			in_range.append(e)
	# Sort by distance (nearest first)
	in_range.sort_custom(func(a, b): return _home_position.distance_to(a.global_position) < _home_position.distance_to(b.global_position))
	for i in range(mini(2, in_range.size())):
		if is_instance_valid(in_range[i]) and in_range[i].has_method("take_damage"):
			var dmg = damage * 1.0
			in_range[i].take_damage(dmg)
			register_damage(dmg)

func _fairy_dust_trail() -> void:
	_fairy_dust_trail_flash = 1.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if _home_position.distance_to(e.global_position) < attack_range:
			if e.has_method("apply_slow"):
				e.apply_slow(0.5, 2.0)

func _mermaid_song() -> void:
	_mermaid_song_flash = 1.0
	var enemies = get_tree().get_nodes_in_group("enemies")
	var in_range: Array = []
	for e in enemies:
		if _home_position.distance_to(e.global_position) < attack_range:
			in_range.append(e)
	in_range.shuffle()
	for i in range(mini(3, in_range.size())):
		if is_instance_valid(in_range[i]) and in_range[i].has_method("apply_charm"):
			in_range[i].apply_charm(3.0, 2.0)

func _walk_the_plank() -> void:
	_walk_plank_flash = 1.0
	# Find weakest enemy in range
	var weakest: Node2D = null
	var least_hp: float = 999999.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if _home_position.distance_to(e.global_position) < attack_range:
			if e.health < least_hp:
				weakest = e
				least_hp = e.health
	if weakest and weakest.has_method("take_damage"):
		var kill_dmg = weakest.health
		weakest.take_damage(kill_dmg)
		register_damage(kill_dmg)

func _croc_devour() -> void:
	_croc_devour_flash = 1.0
	# Find strongest enemy on entire map
	var strongest: Node2D = null
	var most_hp: float = 0.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.health > most_hp:
			strongest = e
			most_hp = e.health
	if strongest and strongest.has_method("take_damage"):
		var kill_dmg = strongest.health
		strongest.take_damage(kill_dmg)
		register_damage(kill_dmg)

func _tinker_bell_light() -> void:
	_tinker_light_flash = 1.0
	# Boost fire_rate of nearby towers by 25% (apply 1.25x multiplier temporarily)
	for tower in get_tree().get_nodes_in_group("towers"):
		if tower == self:
			continue
		if _home_position.distance_to(tower.global_position) < attack_range:
			if "fire_rate" in tower:
				tower.fire_rate *= 1.05  # Small cumulative boost each 5s tick

func _neverland_flight() -> void:
	_neverland_flight_flash = 1.0
	# Peter swoops to 8 random enemies across the map, dealing 2x damage each (direct strikes)
	var enemies = get_tree().get_nodes_in_group("enemies")
	var targets: Array = enemies.duplicate()
	targets.shuffle()
	var count = mini(8, targets.size())
	for i in range(count):
		if is_instance_valid(targets[i]) and targets[i].has_method("take_damage"):
			var dmg = damage * 2.0
			var will_kill = targets[i].health - dmg <= 0.0
			targets[i].take_damage(dmg)
			register_damage(dmg)
			if will_kill and gold_bonus > 0:
				var main = get_tree().get_first_node_in_group("main")
				if main:
					main.add_gold(gold_bonus)

func _draw() -> void:
	# Selection ring
	if is_selected:
		var pulse = (sin(_time * 3.0) + 1.0) * 0.5
		var ring_alpha = 0.5 + pulse * 0.3
		draw_arc(Vector2.ZERO, 40.0, 0, TAU, 48, Color(1.0, 0.84, 0.0, ring_alpha), 2.5)
		draw_arc(Vector2.ZERO, 43.0, 0, TAU, 48, Color(1.0, 0.84, 0.0, ring_alpha * 0.4), 1.5)

	# Attack range arc
	draw_arc(Vector2.ZERO, attack_range, 0, TAU, 64, Color(1, 1, 1, 0.06), 1.0)

	var dir = Vector2.from_angle(aim_angle)
	var perp = dir.rotated(PI / 2.0)

	# Idle animation (playful energetic bounce)
	var playful_bounce = absf(sin(_time * 4.0)) * 2.0  # Energetic quick bounce
	var bounce = abs(sin(_time * 3.0)) * 4.0 + playful_bounce
	var breathe = sin(_time * 2.0) * 2.0
	var sway = sin(_time * 2.2) * 2.0  # Faster playful sway
	var bob = Vector2(sway, -bounce - breathe)

	# Tier 4: Flying pose
	var fly_offset = Vector2.ZERO
	if upgrade_tier >= 4:
		fly_offset = Vector2(0, -10.0 + sin(_time * 1.5) * 3.0)

	var body_offset = bob + fly_offset

	# Slight lean toward target direction
	body_offset += Vector2(dir.x * 2.0, dir.y * 1.0)

	# Playful differential motion
	var lean = sin(_time * 2.5) * 1.5  # Quick playful lean

	# Skin colors
	var skin_base = Color(0.91, 0.74, 0.58)
	var skin_shadow = Color(0.78, 0.60, 0.45)
	var skin_highlight = Color(0.96, 0.82, 0.68)


	if _upgrade_flash > 0.0:
		draw_circle(Vector2.ZERO, 80.0 + _upgrade_flash * 24.0, Color(0.5, 1.0, 0.6, _upgrade_flash * 0.25))

	# Fairy dust flash
	if _fairy_flash > 0.0:
		for i in range(12):
			var sa = TAU * float(i) / 12.0 + _fairy_flash * 4.0
			var sp = Vector2.from_angle(sa) * (50.0 + (1.0 - _fairy_flash) * 100.0)
			var spark_size = 5.0 + _fairy_flash * 5.0
			draw_circle(sp, spark_size, Color(1.0, 0.9, 0.3, _fairy_flash * 0.6))
			draw_line(sp - Vector2(spark_size, 0), sp + Vector2(spark_size, 0), Color(1.0, 1.0, 0.7, _fairy_flash * 0.4), 1.0)
			draw_line(sp - Vector2(0, spark_size), sp + Vector2(0, spark_size), Color(1.0, 1.0, 0.7, _fairy_flash * 0.4), 1.0)
		draw_circle(Vector2.ZERO, 36.0 + (1.0 - _fairy_flash) * 70.0, Color(0.9, 0.85, 0.3, _fairy_flash * 0.15))
		draw_arc(Vector2.ZERO, 30.0 + (1.0 - _fairy_flash) * 50.0, 0, TAU, 32, Color(1.0, 0.85, 0.2, _fairy_flash * 0.3), 2.5)

	# Croc flash
	if _croc_flash > 0.0:
		var croc_r = 48.0 + (1.0 - _croc_flash) * 60.0
		draw_circle(Vector2.ZERO, croc_r, Color(0.2, 0.6, 0.15, _croc_flash * 0.3))
		for ci in range(8):
			var ca = TAU * float(ci) / 8.0
			var c_inner = Vector2.from_angle(ca) * (croc_r - 15.0)
			var c_outer = Vector2.from_angle(ca) * (croc_r + 5.0)
			draw_line(c_inner, c_outer, Color(0.95, 0.95, 0.8, _croc_flash * 0.5), 2.0)

	# Attack flash — dagger strike effect
	if _attack_anim > 0.0:
		var flash_dir = Vector2.from_angle(aim_angle)
		var flash_dist = 25.0 + (1.0 - _attack_anim) * 15.0
		draw_circle(flash_dir * flash_dist, 6.0 * _attack_anim, Color(0.5, 1.0, 0.5, 0.35 * _attack_anim))
		draw_line(flash_dir * 15.0, flash_dir * (flash_dist + 10.0), Color(0.4, 1.0, 0.3, _attack_anim * 0.5), 2.0)

	# === PROGRESSIVE ABILITY VISUAL EFFECTS ===

	# Ability 2: Lost Boys flash — two small hooded figures
	if _lost_boys_flash > 0.0:
		for lbi in range(2):
			var lb_a = TAU * float(lbi) / 2.0 + _lost_boys_flash * 4.0
			var lb_pos = Vector2.from_angle(lb_a) * 30.0
			draw_circle(lb_pos, 4.0, Color(0.2, 0.5, 0.15, _lost_boys_flash * 0.6))
			draw_circle(lb_pos + Vector2(0, -5), 3.0, Color(0.25, 0.55, 0.18, _lost_boys_flash * 0.5))
			# Dagger line
			var lb_dir = Vector2.from_angle(lb_a + PI) * 8.0
			draw_line(lb_pos, lb_pos + lb_dir, Color(0.7, 0.75, 0.8, _lost_boys_flash * 0.6), 1.5)

	# Ability 3: Fairy Dust Trail flash — sparkle sweep across range
	if _fairy_dust_trail_flash > 0.0:
		var sweep_a = (1.0 - _fairy_dust_trail_flash) * TAU
		for fdi in range(8):
			var fd_a = sweep_a + float(fdi) * 0.3
			var fd_r = attack_range * 0.3 + float(fdi) * attack_range * 0.08
			var fd_pos = Vector2.from_angle(fd_a) * fd_r
			var fd_alpha = _fairy_dust_trail_flash * 0.5 * (1.0 - float(fdi) * 0.1)
			draw_circle(fd_pos, 3.0, Color(1.0, 0.92, 0.4, fd_alpha))
			draw_circle(fd_pos, 1.5, Color(1.0, 1.0, 0.8, fd_alpha * 0.8))

	# Ability 4: Mermaid's Song flash — water splash and hearts
	if _mermaid_song_flash > 0.0:
		var ms_r = 30.0 + (1.0 - _mermaid_song_flash) * 40.0
		draw_arc(Vector2.ZERO, ms_r, 0, TAU, 24, Color(0.3, 0.6, 0.9, _mermaid_song_flash * 0.4), 2.5)
		draw_arc(Vector2.ZERO, ms_r * 0.7, 0, TAU, 16, Color(0.4, 0.7, 1.0, _mermaid_song_flash * 0.3), 2.0)
		# Hearts above
		for hi in range(3):
			var hx = -15.0 + float(hi) * 15.0
			var hy = -50.0 - (1.0 - _mermaid_song_flash) * 20.0
			draw_circle(Vector2(hx - 2, hy), 2.5, Color(1.0, 0.3, 0.5, _mermaid_song_flash * 0.6))
			draw_circle(Vector2(hx + 2, hy), 2.5, Color(1.0, 0.3, 0.5, _mermaid_song_flash * 0.6))

	# Ability 5: Walk the Plank flash — wooden plank extending
	if _walk_plank_flash > 0.0:
		var plank_len = 40.0 * (1.0 - _walk_plank_flash) + 10.0
		draw_line(Vector2(20, 10), Vector2(20 + plank_len, 10), Color(0.55, 0.38, 0.18, _walk_plank_flash * 0.7), 4.0)
		draw_line(Vector2(20, 11), Vector2(20 + plank_len, 11), Color(0.45, 0.30, 0.12, _walk_plank_flash * 0.5), 2.0)
		# Splash at end
		if _walk_plank_flash < 0.5:
			var splash_a = _walk_plank_flash * 2.0
			draw_circle(Vector2(20 + plank_len, 18), 6.0 * (1.0 - splash_a), Color(0.3, 0.6, 0.9, splash_a * 0.5))

	# Ability 6: Croc Devour flash — crocodile charging
	if _croc_devour_flash > 0.0:
		var cd_x = -60.0 + (1.0 - _croc_devour_flash) * 120.0
		draw_circle(Vector2(cd_x, 0), 8.0, Color(0.22, 0.48, 0.18, _croc_devour_flash * 0.7))
		# Jaws
		draw_line(Vector2(cd_x + 8, -3), Vector2(cd_x + 16, 0), Color(0.22, 0.48, 0.18, _croc_devour_flash * 0.6), 2.5)
		draw_line(Vector2(cd_x + 8, 3), Vector2(cd_x + 16, 0), Color(0.22, 0.48, 0.18, _croc_devour_flash * 0.6), 2.5)

	# Ability 7: Tinker Bell's Light flash — sparkle connections to towers
	if _tinker_light_flash > 0.0:
		draw_circle(Vector2.ZERO, 20.0, Color(1.0, 0.95, 0.5, _tinker_light_flash * 0.2))
		for tli in range(6):
			var tl_a = TAU * float(tli) / 6.0 + _tinker_light_flash * 3.0
			var tl_end = Vector2.from_angle(tl_a) * (attack_range * 0.6)
			draw_line(Vector2.ZERO, tl_end, Color(1.0, 0.92, 0.4, _tinker_light_flash * 0.25), 1.0)
			draw_circle(tl_end, 2.0, Color(1.0, 0.95, 0.5, _tinker_light_flash * 0.4))

	# Ability 8: Neverland Flight flash — daggers spraying outward
	if _neverland_flight_flash > 0.0:
		for nfi in range(8):
			var nf_a = TAU * float(nfi) / 8.0
			var nf_r = 20.0 + (1.0 - _neverland_flight_flash) * 80.0
			var nf_pos = Vector2.from_angle(nf_a) * nf_r
			draw_line(nf_pos, nf_pos + Vector2.from_angle(nf_a) * 10.0, Color(0.7, 0.75, 0.85, _neverland_flight_flash * 0.6), 2.0)
			draw_circle(nf_pos, 2.0, Color(0.5, 1.0, 0.6, _neverland_flight_flash * 0.5))
		# Peter rising effect
		draw_circle(Vector2(0, -20.0 * (1.0 - _neverland_flight_flash)), 6.0, Color(0.5, 1.0, 0.6, _neverland_flight_flash * 0.3))

	# Ability 2: Lost Boys orbiting (persistent when active)
	if prog_abilities[1]:
		for lbi in range(2):
			var lb_a = _time * 1.5 + float(lbi) * PI
			var lb_pos = Vector2.from_angle(lb_a) * 32.0
			# Hooded figure body
			draw_circle(lb_pos + Vector2(0, -3), 3.5, Color(0.18, 0.42, 0.10, 0.6))
			draw_circle(lb_pos + Vector2(0, 2), 4.0, Color(0.16, 0.38, 0.08, 0.5))
			# Hood
			var hood_pts = PackedVector2Array([
				lb_pos + Vector2(-3, -4), lb_pos + Vector2(3, -4),
				lb_pos + Vector2(0, -9),
			])
			draw_colored_polygon(hood_pts, Color(0.14, 0.36, 0.06, 0.6))
			# Tiny dagger
			var lb_dir = Vector2.from_angle(lb_a + PI / 2.0)
			draw_line(lb_pos + lb_dir * 3.0, lb_pos + lb_dir * 9.0, Color(0.7, 0.75, 0.82, 0.5), 1.2)

	# === STONE PLATFORM (Bloons-style placed tower base) ===
	var plat_y = 22.0
	# Platform shadow
	draw_circle(Vector2(0, plat_y + 4), 28.0, Color(0, 0, 0, 0.15))
	# Stone platform ellipse (drawn as squished circles)
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
			0: pip_col = Color(0.4, 0.4, 0.5)
			1: pip_col = Color(0.6, 0.85, 0.3)
			2: pip_col = Color(0.3, 0.75, 0.4)
			3: pip_col = Color(0.4, 1.0, 0.5)
		draw_circle(pip_pos, 4.0, pip_col)
		draw_circle(pip_pos, 5.5, Color(pip_col.r, pip_col.g, pip_col.b, 0.15))

	# === CHARACTER POSITIONS (tall anime proportions ~56px) ===
	var feet_y = body_offset + Vector2(lean * 0.8, 14.0 - playful_bounce * 0.5)
	var leg_top = body_offset + Vector2(lean * 0.5, -2.0)
	var torso_center = body_offset + Vector2(lean * 0.3, -10.0)
	var neck_base = body_offset + Vector2(-lean * 0.2, -20.0)
	var head_center = body_offset + Vector2(-lean * 0.4, -32.0 - playful_bounce * 0.3)

	# === Tier 4: Fairy dust particles floating around ===
	if upgrade_tier >= 4:
		for fd in range(10):
			var fd_seed = float(fd) * 2.37
			var fd_angle = _time * (0.4 + fmod(fd_seed, 0.6)) + fd_seed
			var fd_radius = 28.0 + fmod(fd_seed * 7.3, 35.0)
			var fd_pos = body_offset + Vector2(cos(fd_angle) * fd_radius, sin(fd_angle) * fd_radius * 0.6)
			var fd_alpha = 0.3 + sin(_time * 3.0 + fd_seed * 2.0) * 0.2
			var fd_size = 1.5 + sin(_time * 2.5 + fd_seed) * 0.6
			draw_circle(fd_pos, fd_size, Color(1.0, 0.92, 0.4, fd_alpha))
			draw_line(fd_pos - Vector2(fd_size + 0.5, 0), fd_pos + Vector2(fd_size + 0.5, 0), Color(1.0, 1.0, 0.8, fd_alpha * 0.4), 0.5)
			draw_line(fd_pos - Vector2(0, fd_size + 0.5), fd_pos + Vector2(0, fd_size + 0.5), Color(1.0, 1.0, 0.8, fd_alpha * 0.4), 0.5)

	# === Tier 3+: Crocodile lurking beside platform ===
	if upgrade_tier >= 3:
		var croc_base = Vector2(body_offset.x + 24.0, plat_y + 4.0)
		var jaw_open = sin(_time * 2.0) * 0.35
		# Body
		draw_circle(croc_base, 10.0, Color(0.22, 0.42, 0.15))
		draw_circle(croc_base, 7.5, Color(0.28, 0.48, 0.20))
		# Belly
		draw_circle(croc_base + Vector2(2, 2), 5.0, Color(0.45, 0.58, 0.32))
		# Scale bumps on back
		for sb in range(4):
			var sbp = croc_base + Vector2(-6.0 + float(sb) * 3.5, -5.0)
			draw_circle(sbp, 2.0, Color(0.20, 0.38, 0.13))
		# Snout
		draw_line(croc_base + Vector2(8, 0), croc_base + Vector2(22, 0), Color(0.26, 0.48, 0.18), 6.0)
		draw_line(croc_base + Vector2(8, 0), croc_base + Vector2(22, 0), Color(0.30, 0.52, 0.22), 4.0)
		# Nostrils
		draw_circle(croc_base + Vector2(21, -1.5), 0.8, Color(0.12, 0.20, 0.08))
		draw_circle(croc_base + Vector2(21, 1.5), 0.8, Color(0.12, 0.20, 0.08))
		# Upper jaw
		draw_line(croc_base + Vector2(22, 0), croc_base + Vector2(16, -5.0 - jaw_open * 7.0), Color(0.22, 0.42, 0.16), 3.0)
		draw_line(croc_base + Vector2(22, 0), croc_base + Vector2(10, -4.0 - jaw_open * 5.0), Color(0.22, 0.42, 0.16), 2.5)
		# Lower jaw
		draw_line(croc_base + Vector2(22, 0), croc_base + Vector2(16, 5.0 + jaw_open * 7.0), Color(0.20, 0.38, 0.14), 2.5)
		draw_line(croc_base + Vector2(22, 0), croc_base + Vector2(10, 4.0 + jaw_open * 5.0), Color(0.20, 0.38, 0.14), 2.0)
		# Teeth
		for t in range(4):
			var tx = 19.0 - float(t) * 2.2
			draw_line(croc_base + Vector2(tx, -3.0 - jaw_open * 5.0), croc_base + Vector2(tx, -5.5 - jaw_open * 5.0), Color(0.98, 0.96, 0.88), 1.2)
			draw_line(croc_base + Vector2(tx, 3.0 + jaw_open * 5.0), croc_base + Vector2(tx, 5.5 + jaw_open * 5.0), Color(0.94, 0.94, 0.84), 1.0)
		# Eye with slit pupil
		draw_circle(croc_base + Vector2(4, -6), 3.5, Color(0.92, 0.82, 0.08))
		draw_circle(croc_base + Vector2(4, -6), 2.2, Color(0.85, 0.75, 0.05))
		draw_line(croc_base + Vector2(4, -8), croc_base + Vector2(4, -4), Color(0.08, 0.08, 0.04), 1.2)
		# Tail
		var tail_sway = sin(_time * 1.8) * 5.0
		draw_line(croc_base + Vector2(-8, 0), croc_base + Vector2(-20, tail_sway), Color(0.25, 0.45, 0.18), 4.5)
		draw_line(croc_base + Vector2(-20, tail_sway), croc_base + Vector2(-28, -tail_sway * 0.5), Color(0.23, 0.42, 0.16), 3.0)
		draw_line(croc_base + Vector2(-28, -tail_sway * 0.5), croc_base + Vector2(-33, tail_sway * 0.3), Color(0.20, 0.38, 0.14), 2.0)
		# Tick-tock clock on belly
		var clock_pos = croc_base + Vector2(-1, 1)
		draw_arc(clock_pos, 4.0, 0, TAU, 10, Color(0.70, 0.60, 0.20, 0.5), 0.7)
		var ch = _time * 0.5
		draw_line(clock_pos, clock_pos + Vector2.from_angle(ch) * 2.5, Color(0.70, 0.60, 0.20, 0.6), 0.6)
		draw_line(clock_pos, clock_pos + Vector2.from_angle(ch * 3.0) * 3.0, Color(0.70, 0.60, 0.20, 0.6), 0.5)

	# === Tier 1+: Peter's detached shadow ===
	if upgrade_tier >= 1:
		var shadow_off = body_offset + Vector2(14.0 + sin(_time * 1.5) * 5.0, 3.0 + cos(_time * 0.9) * 3.0)
		var shadow_alpha: float = 0.2 + 0.08 * float(min(upgrade_tier, 4))
		var sc = Color(0.04, 0.04, 0.08, shadow_alpha)
		var sc_light = Color(0.04, 0.04, 0.08, shadow_alpha * 0.7)
		# Shadow head (smaller, taller body)
		draw_circle(shadow_off + Vector2(0, -30.0), 7.0, sc)
		# Shadow hat
		var s_hat = PackedVector2Array([
			shadow_off + Vector2(-6, -34),
			shadow_off + Vector2(6, -34),
			shadow_off + Vector2(8, -46),
		])
		draw_colored_polygon(s_hat, sc_light)
		# Shadow torso (taller)
		var s_body = PackedVector2Array([
			shadow_off + Vector2(-9, -22),
			shadow_off + Vector2(9, -22),
			shadow_off + Vector2(10, -2),
			shadow_off + Vector2(-10, -2),
		])
		draw_colored_polygon(s_body, sc)
		# Shadow legs (longer)
		draw_line(shadow_off + Vector2(-5, -2), shadow_off + Vector2(-7, 14), sc, 2.5)
		draw_line(shadow_off + Vector2(5, -2), shadow_off + Vector2(7, 14), sc, 2.5)
		# Shadow arms (wispy, misaligned)
		var wave = sin(_time * 3.0) * 3.0
		draw_line(shadow_off + Vector2(-9, -16), shadow_off + Vector2(-20 - wave, -10), sc, 2.0)
		draw_line(shadow_off + Vector2(9, -16), shadow_off + Vector2(20 + wave, -18), sc, 2.0)
		# Shadow reaching out (mischievous)
		var reach = sin(_time * 0.7) * 4.0
		draw_line(shadow_off + Vector2(20 + wave, -18), shadow_off + Vector2(24 + reach, -20 + wave * 0.5), sc_light, 1.5)
		# Wispy tendrils at shadow edges
		for wi in range(4):
			var w_base = shadow_off + Vector2(sin(float(wi) * 1.5) * 10.0, -2.0 + float(wi) * 2.5)
			var w_tip = w_base + Vector2(sin(_time * 2.0 + float(wi)) * 4.0, 5.0)
			draw_line(w_base, w_tip, Color(0.04, 0.04, 0.08, shadow_alpha * 0.4), 1.5)

	# === TALL ANIME CHARACTER BODY ===

	# Pointed elf boots (taller, curled-up toes)
	var l_foot = feet_y + Vector2(-7, 0)
	var r_foot = feet_y + Vector2(7, 0)
	var l_knee = leg_top + Vector2(-6, 6)
	var r_knee = leg_top + Vector2(6, 6)
	# Boot base
	draw_circle(l_foot, 5.0, Color(0.32, 0.22, 0.08))
	draw_circle(l_foot, 3.8, Color(0.40, 0.28, 0.12))
	draw_circle(r_foot, 5.0, Color(0.32, 0.22, 0.08))
	draw_circle(r_foot, 3.8, Color(0.40, 0.28, 0.12))
	# Boot shafts (taller elf boots extending up the calf)
	draw_line(l_foot + Vector2(0, -3), l_foot + Vector2(0, -10), Color(0.32, 0.22, 0.08), 6.0)
	draw_line(l_foot + Vector2(0, -3), l_foot + Vector2(0, -10), Color(0.40, 0.28, 0.12), 4.5)
	draw_line(r_foot + Vector2(0, -3), r_foot + Vector2(0, -10), Color(0.32, 0.22, 0.08), 6.0)
	draw_line(r_foot + Vector2(0, -3), r_foot + Vector2(0, -10), Color(0.40, 0.28, 0.12), 4.5)
	# Boot top cuff
	draw_line(l_foot + Vector2(-3.5, -10), l_foot + Vector2(3.5, -10), Color(0.36, 0.25, 0.10), 2.0)
	draw_line(r_foot + Vector2(-3.5, -10), r_foot + Vector2(3.5, -10), Color(0.36, 0.25, 0.10), 2.0)
	# Curled pointed toes (more dramatic curl)
	draw_line(l_foot + Vector2(-3, -1), l_foot + Vector2(-11, -6), Color(0.40, 0.28, 0.12), 3.5)
	draw_circle(l_foot + Vector2(-11, -6), 2.0, Color(0.42, 0.30, 0.14))
	draw_line(r_foot + Vector2(3, -1), r_foot + Vector2(11, -6), Color(0.40, 0.28, 0.12), 3.5)
	draw_circle(r_foot + Vector2(11, -6), 2.0, Color(0.42, 0.30, 0.14))
	# Bells on toe tips (slightly larger)
	draw_circle(l_foot + Vector2(-11, -6), 1.6, Color(0.85, 0.75, 0.2))
	draw_circle(l_foot + Vector2(-11, -6.5), 0.8, Color(1.0, 0.92, 0.4, 0.65))
	draw_circle(l_foot + Vector2(-11, -5.2), 0.4, Color(1.0, 0.95, 0.5, 0.4))
	draw_circle(r_foot + Vector2(11, -6), 1.6, Color(0.85, 0.75, 0.2))
	draw_circle(r_foot + Vector2(11, -6.5), 0.8, Color(1.0, 0.92, 0.4, 0.65))
	draw_circle(r_foot + Vector2(11, -5.2), 0.4, Color(1.0, 0.95, 0.5, 0.4))
	# Leaf wrapping on boots
	for bi in range(2):
		var boot = l_foot if bi == 0 else r_foot
		for bl in range(3):
			var ba = PI * 0.5 + float(bl) * 0.7 - 0.5
			var leaf_c = boot + Vector2.from_angle(ba) * 3.5 + Vector2(0, -float(bl) * 3.0)
			draw_line(leaf_c - Vector2(2.5, 0), leaf_c + Vector2(2.5, 0), Color(0.18, 0.44, 0.12, 0.6), 1.5)

	# Long dancer's legs with green tights — polygon athletic shapes
	var l_hip = leg_top + Vector2(-6, 0)
	var r_hip = leg_top + Vector2(6, 0)
	var l_boot_top = l_foot + Vector2(0, -10)
	var r_boot_top = r_foot + Vector2(0, -10)
	# LEFT THIGH — athletic quad with outer muscle bulge
	draw_colored_polygon(PackedVector2Array([
		l_hip + Vector2(3, 0), l_hip + Vector2(-4, 0),
		l_hip.lerp(l_knee, 0.3) + Vector2(-6, 0),  # outer quad bulge
		l_hip.lerp(l_knee, 0.6) + Vector2(-5.5, 0),
		l_knee + Vector2(-4, 0), l_knee + Vector2(3, 0),
		l_hip.lerp(l_knee, 0.5) + Vector2(4, 0),  # inner thigh
	]), Color(0.14, 0.40, 0.08))
	draw_colored_polygon(PackedVector2Array([
		l_hip + Vector2(2, 0), l_hip + Vector2(-3, 0),
		l_hip.lerp(l_knee, 0.3) + Vector2(-5, 0),
		l_knee + Vector2(-3, 0), l_knee + Vector2(2, 0),
	]), Color(0.18, 0.48, 0.12))
	# Quad definition highlight
	draw_line(l_hip.lerp(l_knee, 0.15) + Vector2(-2, 0), l_hip.lerp(l_knee, 0.65) + Vector2(-2, 0), Color(0.22, 0.55, 0.16, 0.3), 1.0)
	# RIGHT THIGH
	draw_colored_polygon(PackedVector2Array([
		r_hip + Vector2(-3, 0), r_hip + Vector2(4, 0),
		r_hip.lerp(r_knee, 0.3) + Vector2(6, 0),
		r_hip.lerp(r_knee, 0.6) + Vector2(5.5, 0),
		r_knee + Vector2(4, 0), r_knee + Vector2(-3, 0),
		r_hip.lerp(r_knee, 0.5) + Vector2(-4, 0),
	]), Color(0.14, 0.40, 0.08))
	draw_colored_polygon(PackedVector2Array([
		r_hip + Vector2(-2, 0), r_hip + Vector2(3, 0),
		r_hip.lerp(r_knee, 0.3) + Vector2(5, 0),
		r_knee + Vector2(3, 0), r_knee + Vector2(-2, 0),
	]), Color(0.18, 0.48, 0.12))
	draw_line(r_hip.lerp(r_knee, 0.15) + Vector2(2, 0), r_hip.lerp(r_knee, 0.65) + Vector2(2, 0), Color(0.22, 0.55, 0.16, 0.3), 1.0)
	# Knee joints
	draw_circle(l_knee, 4.5, Color(0.14, 0.40, 0.08))
	draw_circle(l_knee, 3.5, Color(0.18, 0.48, 0.12))
	draw_circle(r_knee, 4.5, Color(0.14, 0.40, 0.08))
	draw_circle(r_knee, 3.5, Color(0.18, 0.48, 0.12))
	# LEFT CALF — defined athletic shape
	var l_calf_mid = l_knee.lerp(l_boot_top, 0.35) + Vector2(-2, 0)
	draw_colored_polygon(PackedVector2Array([
		l_knee + Vector2(-4, 0), l_knee + Vector2(3, 0),
		l_calf_mid + Vector2(3.5, 0),
		l_boot_top + Vector2(2, 0), l_boot_top + Vector2(-2, 0),
		l_calf_mid + Vector2(-5, 0),  # calf muscle bulge
	]), Color(0.14, 0.40, 0.08))
	draw_colored_polygon(PackedVector2Array([
		l_knee + Vector2(-3, 0), l_knee + Vector2(2, 0),
		l_boot_top + Vector2(1.5, 0), l_boot_top + Vector2(-1.5, 0),
	]), Color(0.18, 0.48, 0.12))
	draw_circle(l_calf_mid + Vector2(-1, 0), 2.5, Color(0.22, 0.55, 0.16, 0.2))
	# RIGHT CALF
	var r_calf_mid = r_knee.lerp(r_boot_top, 0.35) + Vector2(2, 0)
	draw_colored_polygon(PackedVector2Array([
		r_knee + Vector2(4, 0), r_knee + Vector2(-3, 0),
		r_calf_mid + Vector2(-3.5, 0),
		r_boot_top + Vector2(-2, 0), r_boot_top + Vector2(2, 0),
		r_calf_mid + Vector2(5, 0),
	]), Color(0.14, 0.40, 0.08))
	draw_colored_polygon(PackedVector2Array([
		r_knee + Vector2(3, 0), r_knee + Vector2(-2, 0),
		r_boot_top + Vector2(-1.5, 0), r_boot_top + Vector2(1.5, 0),
	]), Color(0.18, 0.48, 0.12))
	draw_circle(r_calf_mid + Vector2(1, 0), 2.5, Color(0.22, 0.55, 0.16, 0.2))

	# Green sleeveless leaf tunic (dark forest green, lean V-taper)
	# Shoulders ±14, waist ±9, extends from neck_base down to leg_top area
	var tunic_pts = PackedVector2Array([
		leg_top + Vector2(-9, 0),         # bottom-left (waist width)
		torso_center + Vector2(-11, 0),   # mid waist
		neck_base + Vector2(-14, 0),      # left shoulder
		neck_base + Vector2(-6, -2),      # left neckline
		neck_base + Vector2(6, -2),       # right neckline
		neck_base + Vector2(14, 0),       # right shoulder
		torso_center + Vector2(11, 0),    # mid waist
		leg_top + Vector2(9, 0),          # bottom-right
	])
	draw_colored_polygon(tunic_pts, Color(0.14, 0.40, 0.08))
	# Lighter inner tunic panel
	var tunic_hi = PackedVector2Array([
		leg_top + Vector2(-5, -1),
		torso_center + Vector2(-6, -1),
		torso_center + Vector2(6, -1),
		leg_top + Vector2(5, -1),
	])
	draw_colored_polygon(tunic_hi, Color(0.20, 0.52, 0.14, 0.45))
	# V-neckline detail
	draw_line(neck_base + Vector2(-6, -2), neck_base + Vector2(0, 4), Color(0.10, 0.32, 0.06, 0.6), 1.2)
	draw_line(neck_base + Vector2(6, -2), neck_base + Vector2(0, 4), Color(0.10, 0.32, 0.06, 0.6), 1.2)
	# Slight chest definition (male, lean)
	draw_arc(torso_center + Vector2(-4, -4), 5.0, -0.3, 1.2, 6, Color(0.12, 0.36, 0.06, 0.3), 0.8)
	draw_arc(torso_center + Vector2(4, -4), 5.0, PI - 1.2, PI + 0.3, 6, Color(0.12, 0.36, 0.06, 0.3), 0.8)
	# Jagged leaf bottom edge (more teeth, varied sizes)
	for ji in range(7):
		var jx = -9.0 + float(ji) * 3.0
		var jag = 3.0 + sin(float(ji) * 2.3 + _time * 1.5) * 2.0 + float(ji % 2) * 1.5
		var jw = 1.2 + float(ji % 3) * 0.4
		var jag_pts = PackedVector2Array([
			leg_top + Vector2(jx - jw, 0),
			leg_top + Vector2(jx + jw, 0),
			leg_top + Vector2(jx, jag),
		])
		draw_colored_polygon(jag_pts, Color(0.12, 0.38, 0.06))
	# Leaf texture overlay on tunic
	for li in range(6):
		var lx = -6.0 + float(li % 2) * 6.0
		var ly = -8.0 + float(li / 2) * 5.0
		var leaf_pos = torso_center + Vector2(lx, ly)
		var leaf_a = float(li) * 0.7 + 0.3
		var ld = Vector2.from_angle(leaf_a)
		var lp_dir = ld.rotated(PI / 2.0)
		var leaf_pts = PackedVector2Array([
			leaf_pos - ld * 4.0,
			leaf_pos + lp_dir * 2.0,
			leaf_pos + ld * 4.0,
			leaf_pos - lp_dir * 2.0,
		])
		draw_colored_polygon(leaf_pts, Color(0.16, 0.44, 0.10, 0.5))
		draw_line(leaf_pos - ld * 3.0, leaf_pos + ld * 3.0, Color(0.12, 0.34, 0.06, 0.4), 0.6)
	# Fold shadows (longer torso)
	draw_line(torso_center + Vector2(-9, -6), torso_center + Vector2(-8, 6), Color(0.10, 0.32, 0.06, 0.4), 1.2)
	draw_line(torso_center + Vector2(9, -6), torso_center + Vector2(8, 6), Color(0.10, 0.32, 0.06, 0.4), 1.2)
	# Cobweb thread across tunic (gothic detail — slightly more visible)
	draw_line(torso_center + Vector2(-10, -6), torso_center + Vector2(8, 4), Color(0.85, 0.88, 0.92, 0.10), 0.5)
	# Small leaf patches/stitches on tunic (sewn-leaf look)
	for pi in range(3):
		var px = -5.0 + float(pi) * 5.0
		var py = -3.0 + float(pi % 2) * 6.0
		var patch_pos = torso_center + Vector2(px, py)
		var pa = float(pi) * 0.8 + 0.5
		var pd = Vector2.from_angle(pa)
		draw_line(patch_pos - pd * 2.0, patch_pos + pd * 2.0, Color(0.18, 0.48, 0.12, 0.35), 1.0)
		draw_line(patch_pos - pd.rotated(PI / 2.0) * 1.0, patch_pos + pd.rotated(PI / 2.0) * 1.0, Color(0.18, 0.48, 0.12, 0.25), 0.6)
		# Tiny stitch marks around patch
		draw_line(patch_pos + pd * 2.2, patch_pos + pd * 2.6, Color(0.14, 0.38, 0.08, 0.3), 0.4)
		draw_line(patch_pos - pd * 2.2, patch_pos - pd * 2.6, Color(0.14, 0.38, 0.08, 0.3), 0.4)

	# Vine belt with leaf buckle (at waist between torso and legs)
	var belt_y = torso_center + Vector2(0, 6)
	draw_line(belt_y + Vector2(-11, 0), belt_y + Vector2(11, 0), Color(0.20, 0.36, 0.08), 4.0)
	draw_line(belt_y + Vector2(-11, 0), belt_y + Vector2(11, 0), Color(0.28, 0.46, 0.14), 2.5)
	# Vine twists with flower/berry detail
	for vi in range(5):
		var vp = belt_y + Vector2(-8.0 + float(vi) * 4.0, sin(float(vi) * PI + _time * 2.0) * 1.0)
		draw_circle(vp, 2.2, Color(0.24, 0.42, 0.10))
	# Small flower/berry detail on belt vine
	draw_circle(belt_y + Vector2(-6, -1.5), 1.2, Color(0.90, 0.25, 0.20, 0.5))
	draw_circle(belt_y + Vector2(-6, -1.5), 0.6, Color(0.95, 0.40, 0.35, 0.4))
	draw_circle(belt_y + Vector2(4, -1.8), 1.0, Color(0.85, 0.20, 0.25, 0.45))
	draw_circle(belt_y + Vector2(8, 1.2), 1.1, Color(1.0, 0.85, 0.15, 0.5))
	# Leaf buckle
	var buckle = belt_y
	var buckle_pts = PackedVector2Array([
		buckle + Vector2(-3.5, 0),
		buckle + Vector2(0, -4.5),
		buckle + Vector2(3.5, 0),
		buckle + Vector2(0, 4.5),
	])
	draw_colored_polygon(buckle_pts, Color(0.32, 0.58, 0.18))
	draw_colored_polygon(buckle_pts, Color(0.38, 0.64, 0.22, 0.5))
	draw_line(buckle + Vector2(-2.5, 0), buckle + Vector2(2.5, 0), Color(0.22, 0.44, 0.12), 0.6)
	draw_line(buckle + Vector2(0, -3), buckle + Vector2(0, 3), Color(0.22, 0.44, 0.12), 0.6)
	# Fairy dust pouch on belt
	if upgrade_tier >= 2:
		var pouch = belt_y + Vector2(10, 0)
		draw_circle(pouch, 3.5, Color(0.42, 0.30, 0.12))
		draw_circle(pouch + Vector2(0, -1), 2.8, Color(0.48, 0.34, 0.16))
		# Golden specks spilling
		for sp in range(2):
			var spp = pouch + Vector2(float(sp) * 2.0 - 1.0, 4.0 + float(sp) * 2.0 + sin(_time * 3.0 + float(sp)) * 1.5)
			draw_circle(spp, 0.8, Color(1.0, 0.9, 0.3, 0.4))

	# === Shoulder leaf pauldrons (at shoulder/neck_base level) ===
	draw_circle(neck_base + Vector2(-14, 0), 6.0, Color(0.14, 0.40, 0.10))
	draw_circle(neck_base + Vector2(-14, 0), 4.5, Color(0.20, 0.50, 0.14))
	draw_line(neck_base + Vector2(-17, 0), neck_base + Vector2(-11, 0), Color(0.12, 0.34, 0.08, 0.5), 0.6)
	draw_circle(neck_base + Vector2(14, 0), 6.0, Color(0.14, 0.40, 0.10))
	draw_circle(neck_base + Vector2(14, 0), 4.5, Color(0.20, 0.50, 0.14))
	draw_line(neck_base + Vector2(11, 0), neck_base + Vector2(17, 0), Color(0.12, 0.34, 0.08, 0.5), 0.6)

	# === Arms (athletic muscular polygon shapes, sleeveless — skin visible) ===
	var r_shoulder = neck_base + Vector2(14, 0)
	var l_shoulder = neck_base + Vector2(-14, 0)
	# Dagger arm (right) — swipes toward aim direction
	var dagger_hand: Vector2
	if _attack_anim > 0.0:
		var swipe = dir.rotated(-_attack_anim * PI * 0.5 + PI * 0.3)
		dagger_hand = r_shoulder + swipe * 22.0
	else:
		dagger_hand = r_shoulder + dir * 22.0
	# RIGHT UPPER ARM — athletic polygon with deltoid and bicep
	var r_elbow = r_shoulder + (dagger_hand - r_shoulder) * 0.45
	var r_ua_dir = (r_elbow - r_shoulder).normalized()
	var r_ua_perp = r_ua_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		r_shoulder + r_ua_perp * 5.0, r_shoulder - r_ua_perp * 4.5,
		r_shoulder.lerp(r_elbow, 0.3) - r_ua_perp * 5.5,  # deltoid bulge
		r_shoulder.lerp(r_elbow, 0.6) - r_ua_perp * 5.0,  # bicep
		r_elbow - r_ua_perp * 3.5, r_elbow + r_ua_perp * 3.5,
		r_shoulder.lerp(r_elbow, 0.5) + r_ua_perp * 4.0,
	]), skin_shadow)
	draw_colored_polygon(PackedVector2Array([
		r_shoulder + r_ua_perp * 4.0, r_shoulder - r_ua_perp * 3.5,
		r_shoulder.lerp(r_elbow, 0.35) - r_ua_perp * 4.5,
		r_elbow - r_ua_perp * 2.5, r_elbow + r_ua_perp * 2.5,
	]), skin_base)
	# Bicep definition highlight
	var r_mid_arm = r_shoulder.lerp(r_elbow, 0.4)
	draw_circle(r_mid_arm - r_ua_perp * 2.0, 3.5, Color(skin_highlight.r, skin_highlight.g, skin_highlight.b, 0.4))
	# Elbow joint
	draw_circle(r_elbow, 4.0, skin_shadow)
	draw_circle(r_elbow, 3.0, skin_base)
	# RIGHT FOREARM — tapered athletic polygon
	var r_fa_dir = (dagger_hand - r_elbow).normalized()
	var r_fa_perp = r_fa_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		r_elbow + r_fa_perp * 3.5, r_elbow - r_fa_perp * 3.5,
		r_elbow.lerp(dagger_hand, 0.4) - r_fa_perp * 3.8,  # forearm muscle
		dagger_hand - r_fa_perp * 2.0, dagger_hand + r_fa_perp * 2.0,
		r_elbow.lerp(dagger_hand, 0.4) + r_fa_perp * 3.2,
	]), skin_shadow)
	draw_colored_polygon(PackedVector2Array([
		r_elbow + r_fa_perp * 2.5, r_elbow - r_fa_perp * 2.5,
		dagger_hand - r_fa_perp * 1.2, dagger_hand + r_fa_perp * 1.2,
	]), skin_base)
	# Hand
	draw_circle(dagger_hand, 4.0, skin_shadow)
	draw_circle(dagger_hand, 3.0, skin_base)
	# Fingers gripping
	var grip_dir = dir if _attack_anim <= 0.0 else dir.rotated(-_attack_anim * PI * 0.5 + PI * 0.3)
	for fi in range(3):
		var fa = float(fi - 1) * 0.4
		draw_circle(dagger_hand + grip_dir.rotated(fa) * 3.5, 1.5, skin_highlight)

	# Off-hand (on hip, cocky pose)
	var off_hand = torso_center + Vector2(-11, 6)
	# LEFT UPPER ARM — athletic polygon
	var l_elbow = l_shoulder + (off_hand - l_shoulder) * 0.45
	var l_ua_dir = (l_elbow - l_shoulder).normalized()
	var l_ua_perp = l_ua_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		l_shoulder + l_ua_perp * 4.5, l_shoulder - l_ua_perp * 5.0,
		l_shoulder.lerp(l_elbow, 0.3) - l_ua_perp * 5.5,
		l_elbow - l_ua_perp * 3.5, l_elbow + l_ua_perp * 3.5,
		l_shoulder.lerp(l_elbow, 0.5) + l_ua_perp * 4.0,
	]), skin_shadow)
	draw_colored_polygon(PackedVector2Array([
		l_shoulder + l_ua_perp * 3.5, l_shoulder - l_ua_perp * 4.0,
		l_elbow - l_ua_perp * 2.5, l_elbow + l_ua_perp * 2.5,
	]), skin_base)
	var l_mid_arm = l_shoulder.lerp(l_elbow, 0.4)
	draw_circle(l_mid_arm - l_ua_perp * 2.0, 3.0, Color(skin_highlight.r, skin_highlight.g, skin_highlight.b, 0.35))
	# Elbow joint
	draw_circle(l_elbow, 4.0, skin_shadow)
	draw_circle(l_elbow, 3.0, skin_base)
	# LEFT FOREARM — polygon tapered
	var l_fa_dir = (off_hand - l_elbow).normalized()
	var l_fa_perp = l_fa_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		l_elbow + l_fa_perp * 3.5, l_elbow - l_fa_perp * 3.5,
		off_hand - l_fa_perp * 2.0, off_hand + l_fa_perp * 2.0,
	]), skin_shadow)
	draw_colored_polygon(PackedVector2Array([
		l_elbow + l_fa_perp * 2.5, l_elbow - l_fa_perp * 2.5,
		off_hand - l_fa_perp * 1.2, off_hand + l_fa_perp * 1.2,
	]), skin_base)
	draw_circle(off_hand, 3.5, skin_shadow)
	draw_circle(off_hand, 2.8, skin_base)

	# === Ornate dagger ===
	var dagger_dir: Vector2
	if _attack_anim > 0.0:
		dagger_dir = dir.rotated(-_attack_anim * PI * 0.5 + PI * 0.3)
	else:
		dagger_dir = dir
	var dagger_perp = dagger_dir.rotated(PI / 2.0)
	# Handle (leather wrapped)
	draw_line(dagger_hand, dagger_hand + dagger_dir * 8.0, Color(0.38, 0.26, 0.12), 3.5)
	draw_line(dagger_hand, dagger_hand + dagger_dir * 8.0, Color(0.44, 0.32, 0.16), 2.0)
	# Leather wrapping marks
	for wi in range(3):
		var wp = dagger_hand + dagger_dir * (2.0 + float(wi) * 2.5)
		draw_line(wp - dagger_perp * 2.0, wp + dagger_perp * 2.0, Color(0.50, 0.38, 0.18), 0.7)
	# Pommel (acorn)
	draw_circle(dagger_hand - dagger_dir * 1.0, 2.5, Color(0.48, 0.36, 0.16))
	draw_circle(dagger_hand - dagger_dir * 1.0, 1.5, Color(0.56, 0.42, 0.20))
	# Cross-guard (ornate leaf shape)
	var guard_c = dagger_hand + dagger_dir * 8.0
	draw_line(guard_c + dagger_perp * 6.5, guard_c - dagger_perp * 6.5, Color(0.52, 0.42, 0.16), 3.5)
	draw_line(guard_c + dagger_perp * 6.5, guard_c - dagger_perp * 6.5, Color(0.60, 0.50, 0.20), 2.0)
	# Guard gem (emerald)
	draw_circle(guard_c, 1.5, Color(0.15, 0.55, 0.25))
	draw_circle(guard_c + dagger_dir * 0.2, 0.8, Color(0.3, 0.75, 0.4, 0.6))
	# Blade (bright steel, slightly curved)
	var blade_tip = dagger_hand + dagger_dir * 28.0
	var blade_mid = guard_c + (blade_tip - guard_c) * 0.5 + dagger_perp * 1.0
	draw_line(guard_c, blade_mid, Color(0.72, 0.74, 0.80), 2.8)
	draw_line(blade_mid, blade_tip, Color(0.72, 0.74, 0.80), 1.8)
	# Blade fill
	draw_line(guard_c, blade_tip, Color(0.80, 0.82, 0.88), 2.0)
	# Edge highlight
	draw_line(guard_c + dagger_perp * 0.8, blade_tip, Color(0.90, 0.92, 0.96, 0.5), 0.8)
	# Blade shine
	draw_line(dagger_hand + dagger_dir * 12.0, dagger_hand + dagger_dir * 22.0, Color(0.95, 0.96, 1.0, 0.5), 1.0)
	# Attack glint
	if _attack_anim > 0.5:
		var glint_a = (_attack_anim - 0.5) * 2.0
		draw_circle(blade_tip, 3.5 + glint_a * 2.5, Color(1.0, 1.0, 0.95, glint_a * 0.6))
		draw_line(blade_tip - dagger_perp * (5.0 * glint_a), blade_tip + dagger_perp * (5.0 * glint_a), Color(1.0, 1.0, 0.9, glint_a * 0.4), 0.8)

	# === HEAD (proportional anime head ~22px diameter) ===
	# Polygon neck (athletic, defined)
	var neck_top = head_center + Vector2(0, 8)
	var neck_dir = (neck_top - neck_base).normalized()
	var neck_perp = neck_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		neck_base + neck_perp * 6.0, neck_base - neck_perp * 6.0,
		neck_base.lerp(neck_top, 0.5) - neck_perp * 5.0,
		neck_top - neck_perp * 4.0, neck_top + neck_perp * 4.0,
		neck_base.lerp(neck_top, 0.5) + neck_perp * 5.0,
	]), skin_shadow)
	draw_colored_polygon(PackedVector2Array([
		neck_base + neck_perp * 5.0, neck_base - neck_perp * 5.0,
		neck_top - neck_perp * 3.0, neck_top + neck_perp * 3.0,
	]), skin_base)
	# Neck highlight
	draw_line(neck_base.lerp(neck_top, 0.15) + neck_perp * 2.8, neck_base.lerp(neck_top, 0.85) + neck_perp * 2.2, skin_highlight, 1.5)
	# Muscle definition
	draw_line(neck_base + neck_perp * 3.5, neck_top - neck_perp * 0.5, Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.12), 0.8)
	draw_line(neck_base - neck_perp * 3.5, neck_top + neck_perp * 0.5, Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.12), 0.8)
	# Leaf collar at neckline
	for nc in range(5):
		var ncx = -6.0 + float(nc) * 3.0
		draw_line(neck_base + Vector2(ncx, -1), neck_base + Vector2(ncx, -4), Color(0.16, 0.42, 0.10, 0.6), 2.0)

	# Auburn messy hair (back layer — drawn before face)
	var hair_sway = sin(_time * 2.5) * 2.5
	var hair_base_col = Color(0.48, 0.24, 0.10)
	var hair_mid_col = Color(0.55, 0.28, 0.12)
	var hair_hi_col = Color(0.62, 0.34, 0.15)
	# Hair mass (smaller radius 11)
	draw_circle(head_center, 11.5, hair_base_col)
	draw_circle(head_center + Vector2(0, -1), 10.0, hair_mid_col)
	# Volume highlight
	draw_circle(head_center + Vector2(-2, -3), 6.0, Color(0.52, 0.26, 0.12, 0.35))
	# Messy tufts (10 wild windswept strands — extended 20%, more dramatic sway)
	var tuft_data = [
		[0.2, 6.6, 2.2], [0.8, 7.8, 2.0], [1.5, 6.0, 2.5], [2.2, 7.2, 1.8],
		[3.5, 8.4, 2.0], [4.2, 6.6, 2.5], [5.0, 6.6, 2.2], [5.6, 7.8, 1.8],
		[0.5, 6.0, 1.9], [4.6, 7.0, 2.0],  # Extra tufts for fullness
	]
	for h in range(tuft_data.size()):
		var ha: float = tuft_data[h][0]
		var tlen: float = tuft_data[h][1]
		var twid: float = tuft_data[h][2]
		var tuft_base_pos = head_center + Vector2.from_angle(ha) * 9.5
		var sway_d = 1.0 if h % 2 == 0 else -1.0
		# More dramatic sway amplitude
		var tuft_tip_pos = tuft_base_pos + Vector2.from_angle(ha) * tlen + Vector2(hair_sway * sway_d * 0.7, 0)
		var tcol = hair_mid_col if h % 3 == 0 else hair_hi_col if h % 3 == 1 else hair_base_col
		draw_line(tuft_base_pos, tuft_tip_pos, tcol, twid)
		# Wispy secondary strand
		var ha2 = ha + (0.12 if h % 2 == 0 else -0.12)
		var t2_base = head_center + Vector2.from_angle(ha2) * 8.5
		var t2_tip = t2_base + Vector2.from_angle(ha2) * (tlen * 0.6) + Vector2(hair_sway * sway_d * 0.4, 0)
		draw_line(t2_base, t2_tip, hair_base_col, twid * 0.5)
		# Tertiary wisp between main tufts
		if h % 3 == 0:
			var ha3 = ha + 0.18
			var t3_base = head_center + Vector2.from_angle(ha3) * 8.8
			var t3_tip = t3_base + Vector2.from_angle(ha3) * (tlen * 0.35) + Vector2(hair_sway * 0.2, 0)
			draw_line(t3_base, t3_tip, Color(hair_hi_col.r, hair_hi_col.g, hair_hi_col.b, 0.5), twid * 0.35)
	# Short spiky tufts sticking up at crown (bed-head/wild boy look)
	for ci in range(4):
		var ca = PI * 1.3 + float(ci) * 0.25
		var c_base = head_center + Vector2.from_angle(ca) * 9.0
		var c_sway = sin(_time * 3.0 + float(ci) * 1.2) * 1.0
		var c_tip = c_base + Vector2.from_angle(ca) * (3.5 + float(ci % 2) * 1.5) + Vector2(c_sway, 0)
		draw_line(c_base, c_tip, hair_mid_col, 1.5 + float(ci % 2) * 0.5)

	# Face (lean, youthful, defined)
	draw_circle(head_center + Vector2(0, 1), 9.0, skin_base)
	# Strong jawline — angular lines from ears to chin
	draw_line(head_center + Vector2(-8.5, 1), head_center + Vector2(-4, 7.5), Color(0.68, 0.52, 0.38, 0.3), 1.3)
	draw_line(head_center + Vector2(8.5, 1), head_center + Vector2(4, 7.5), Color(0.68, 0.52, 0.38, 0.3), 1.3)
	# Chin — youthful, defined
	draw_circle(head_center + Vector2(0, 7.5), 2.8, skin_base)
	draw_circle(head_center + Vector2(0, 7.8), 2.0, skin_highlight)
	# Cheek blush (warm youthful glow)
	draw_circle(head_center + Vector2(-5.5, 2.5), 3.0, Color(0.95, 0.58, 0.50, 0.22))
	draw_circle(head_center + Vector2(5.5, 2.5), 3.0, Color(0.95, 0.58, 0.50, 0.22))
	draw_circle(head_center + Vector2(-5.0, 2.0), 1.8, Color(0.98, 0.65, 0.55, 0.12))
	draw_circle(head_center + Vector2(5.0, 2.0), 1.8, Color(0.98, 0.65, 0.55, 0.12))

	# Pointed elf ears (more prominent, pointier)
	# Right ear — extended further outward
	var r_ear_tip = head_center + Vector2(18, -4)
	var r_ear_pts = PackedVector2Array([
		head_center + Vector2(8, -4.5),
		head_center + Vector2(8, 2.0),
		r_ear_tip,
	])
	draw_colored_polygon(r_ear_pts, skin_base)
	draw_line(head_center + Vector2(8, -4.5), r_ear_tip, skin_shadow, 1.5)
	draw_line(r_ear_tip, head_center + Vector2(8, 2.0), Color(0.80, 0.64, 0.50), 1.0)
	# Inner ear (larger, warmer color)
	draw_circle(head_center + Vector2(12, -1.5), 2.5, Color(0.94, 0.72, 0.62, 0.55))
	draw_circle(head_center + Vector2(11.5, -1.0), 1.5, Color(0.92, 0.68, 0.58, 0.35))
	# Left ear
	var l_ear_tip = head_center + Vector2(-18, -4)
	var l_ear_pts = PackedVector2Array([
		head_center + Vector2(-8, -4.5),
		head_center + Vector2(-8, 2.0),
		l_ear_tip,
	])
	draw_colored_polygon(l_ear_pts, skin_base)
	draw_line(head_center + Vector2(-8, -4.5), l_ear_tip, skin_shadow, 1.5)
	draw_line(l_ear_tip, head_center + Vector2(-8, 2.0), Color(0.80, 0.64, 0.50), 1.0)
	draw_circle(head_center + Vector2(-12, -1.5), 2.5, Color(0.94, 0.72, 0.62, 0.55))
	draw_circle(head_center + Vector2(-11.5, -1.0), 1.5, Color(0.92, 0.68, 0.58, 0.35))
	# Ear tip glow (faint green at all tiers, brighter at T4)
	var ear_glow_base = 0.08 + float(mini(upgrade_tier, 4)) * 0.04
	var ear_glow = ear_glow_base + sin(_time * 3.0) * 0.06
	draw_circle(r_ear_tip, 2.5, Color(0.5, 1.0, 0.5, ear_glow))
	draw_circle(l_ear_tip, 2.5, Color(0.5, 1.0, 0.5, ear_glow))
	if upgrade_tier >= 4:
		draw_circle(r_ear_tip, 4.0, Color(1.0, 0.9, 0.4, 0.2 + sin(_time * 3.0) * 0.1))
		draw_circle(l_ear_tip, 4.0, Color(1.0, 0.9, 0.4, 0.2 + sin(_time * 3.0) * 0.1))

	# Anime-style eyes (expressive but proportional)
	var look_dir = dir * 1.2
	var l_eye = head_center + Vector2(-4, -1)
	var r_eye = head_center + Vector2(4, -1)
	# Eye socket shadow
	draw_circle(l_eye, 4.2, Color(0.72, 0.56, 0.44, 0.25))
	draw_circle(r_eye, 4.2, Color(0.72, 0.56, 0.44, 0.25))
	# Eye whites (slightly larger)
	draw_circle(l_eye, 4.2, Color(0.96, 0.96, 0.98))
	draw_circle(r_eye, 4.2, Color(0.96, 0.96, 0.98))
	# Green irises (brighter)
	draw_circle(l_eye + look_dir, 2.5, Color(0.08, 0.50, 0.20))
	draw_circle(l_eye + look_dir, 2.0, Color(0.14, 0.65, 0.28))
	draw_circle(l_eye + look_dir, 1.4, Color(0.20, 0.75, 0.35))
	draw_circle(r_eye + look_dir, 2.5, Color(0.08, 0.50, 0.20))
	draw_circle(r_eye + look_dir, 2.0, Color(0.14, 0.65, 0.28))
	draw_circle(r_eye + look_dir, 1.4, Color(0.20, 0.75, 0.35))
	# Gold limbal ring
	draw_arc(l_eye + look_dir, 2.3, 0, TAU, 10, Color(0.65, 0.55, 0.15, 0.25), 0.5)
	draw_arc(r_eye + look_dir, 2.3, 0, TAU, 10, Color(0.65, 0.55, 0.15, 0.25), 0.5)
	# Pupils
	draw_circle(l_eye + look_dir * 1.15, 1.2, Color(0.05, 0.05, 0.07))
	draw_circle(r_eye + look_dir * 1.15, 1.2, Color(0.05, 0.05, 0.07))
	# Primary highlight (sparkle)
	draw_circle(l_eye + Vector2(-1.0, -1.2), 1.1, Color(1.0, 1.0, 1.0, 0.9))
	draw_circle(r_eye + Vector2(-1.0, -1.2), 1.1, Color(1.0, 1.0, 1.0, 0.9))
	# Secondary highlight
	draw_circle(l_eye + Vector2(1.2, 0.4), 0.5, Color(1.0, 1.0, 1.0, 0.5))
	draw_circle(r_eye + Vector2(1.2, 0.4), 0.5, Color(1.0, 1.0, 1.0, 0.5))
	# Mischievous green glint
	var glint_t = sin(_time * 2.0) * 0.25
	draw_circle(l_eye + Vector2(0.4, -0.4), 0.4, Color(0.4, 0.9, 0.5, 0.25 + glint_t))
	draw_circle(r_eye + Vector2(0.4, -0.4), 0.4, Color(0.4, 0.9, 0.5, 0.25 + glint_t))
	# Eyelid lines
	draw_arc(l_eye, 3.8, PI + 0.3, TAU - 0.3, 8, Color(0.40, 0.22, 0.12), 1.0)
	draw_arc(r_eye, 3.8, PI + 0.3, TAU - 0.3, 8, Color(0.40, 0.22, 0.12), 1.0)
	# Eyelashes (2 tiny lashes per eye)
	for el in range(2):
		var ela = PI + 0.5 + float(el) * 0.6
		draw_line(l_eye + Vector2.from_angle(ela) * 3.8, l_eye + Vector2.from_angle(ela) * 5.5, Color(0.38, 0.20, 0.10, 0.5), 0.7)
		draw_line(r_eye + Vector2.from_angle(ela) * 3.8, r_eye + Vector2.from_angle(ela) * 5.5, Color(0.38, 0.20, 0.10, 0.5), 0.7)

	# Mischievous asymmetric eyebrows (one raised much higher)
	draw_line(l_eye + Vector2(-3.0, -3.2), l_eye + Vector2(1.5, -4.0), Color(0.45, 0.24, 0.10), 1.5)
	# Right brow raised dramatically higher (peak of mischief)
	draw_line(r_eye + Vector2(-1.5, -5.2), r_eye + Vector2(3.0, -3.0), Color(0.45, 0.24, 0.10), 1.5)

	# Slim upturned button nose
	draw_line(head_center + Vector2(0, 0.5), head_center + Vector2(0, 2.5), Color(0.82, 0.66, 0.52, 0.3), 0.8)
	draw_circle(head_center + Vector2(0, 2.8), 1.6, skin_highlight)
	draw_circle(head_center + Vector2(0.2, 2.6), 1.2, Color(0.93, 0.78, 0.65))
	# Nose tip upturn accent
	draw_arc(head_center + Vector2(0, 2.5), 1.3, PI * 0.2, PI * 0.8, 6, Color(0.94, 0.80, 0.66, 0.3), 0.6)
	# Nostrils
	draw_circle(head_center + Vector2(-0.9, 3.5), 0.5, Color(0.55, 0.40, 0.32, 0.4))
	draw_circle(head_center + Vector2(0.9, 3.5), 0.5, Color(0.55, 0.40, 0.32, 0.4))

	# Cocky Peter Pan grin (wider, more boyish)
	draw_arc(head_center + Vector2(0.5, 5.3), 4.8, 0.1, PI - 0.1, 14, Color(0.62, 0.28, 0.22), 1.7)
	# Teeth showing (gap-toothed boyish grin)
	for ti in range(5):
		var tooth_x = -2.4 + float(ti) * 1.2
		# Gap between center teeth
		if ti == 2:
			continue
		draw_circle(head_center + Vector2(tooth_x, 5.6), 0.7, Color(0.98, 0.96, 0.92))
	# Smirk line (right side curves up more)
	draw_line(head_center + Vector2(4.0, 4.8), head_center + Vector2(5.5, 3.8), Color(0.62, 0.28, 0.22, 0.55), 0.9)
	# Dimples (deeper, more prominent)
	draw_circle(head_center + Vector2(-5.2, 4.8), 1.3, Color(0.78, 0.56, 0.46, 0.45))
	draw_circle(head_center + Vector2(5.2, 4.8), 1.3, Color(0.78, 0.56, 0.46, 0.45))

	# Freckles (more visible, more per cheek)
	var frk = Color(0.62, 0.42, 0.28, 0.65)
	draw_circle(head_center + Vector2(-4.2, 2.0), 0.65, frk)
	draw_circle(head_center + Vector2(-5.0, 3.2), 0.55, frk)
	draw_circle(head_center + Vector2(-3.5, 2.8), 0.55, frk)
	draw_circle(head_center + Vector2(-5.5, 2.2), 0.5, frk)
	draw_circle(head_center + Vector2(-3.8, 3.6), 0.45, frk)
	draw_circle(head_center + Vector2(4.2, 2.0), 0.65, frk)
	draw_circle(head_center + Vector2(5.0, 3.2), 0.55, frk)
	draw_circle(head_center + Vector2(3.5, 2.8), 0.55, frk)
	draw_circle(head_center + Vector2(5.5, 2.2), 0.5, frk)
	draw_circle(head_center + Vector2(3.8, 3.6), 0.45, frk)

	# === Peter Pan hat with leaf texture (scaled to smaller head) ===
	var hat_base_pos = head_center + Vector2(0, -7)
	var hat_tip_pos = hat_base_pos + Vector2(14, -26)
	var hat_pts = PackedVector2Array([
		hat_base_pos + Vector2(-10, 2),
	])
	# Curved brim
	for hbi in range(5):
		var ht = float(hbi) / 4.0
		var brim_pos = hat_base_pos + Vector2(-10.0 + ht * 20.0, 2.0 + sin(ht * PI) * 2.0)
		hat_pts.append(brim_pos)
	hat_pts.append(hat_tip_pos)
	draw_colored_polygon(hat_pts, Color(0.14, 0.42, 0.08))
	# Hat depth shading
	var hat_shade = PackedVector2Array([
		hat_base_pos + Vector2(-9, 1),
		hat_base_pos + Vector2(4, 1),
		hat_tip_pos + Vector2(-2, 1),
	])
	draw_colored_polygon(hat_shade, Color(0.10, 0.34, 0.06, 0.4))
	# Hat brim line
	draw_line(hat_base_pos + Vector2(-11, 2), hat_base_pos + Vector2(11, 2), Color(0.12, 0.36, 0.06), 3.0)
	draw_line(hat_base_pos + Vector2(-11, 2.5), hat_base_pos + Vector2(11, 2.5), Color(0.22, 0.50, 0.14), 1.8)
	# Leaf veins on hat (more detailed)
	var hat_vein = Color(0.10, 0.32, 0.06, 0.5)
	draw_line(hat_base_pos + Vector2(2, 0), hat_tip_pos + Vector2(-1, 1), hat_vein, 0.8)
	var vm1 = hat_base_pos + (hat_tip_pos - hat_base_pos) * 0.25
	var vm2 = hat_base_pos + (hat_tip_pos - hat_base_pos) * 0.45
	var vm3 = hat_base_pos + (hat_tip_pos - hat_base_pos) * 0.65
	var vm4 = hat_base_pos + (hat_tip_pos - hat_base_pos) * 0.8
	draw_line(vm1, vm1 + Vector2(-5, -1.5), hat_vein, 0.6)
	draw_line(vm1, vm1 + Vector2(2.5, 1.5), hat_vein, 0.6)
	draw_line(vm2, vm2 + Vector2(-4.5, -1.2), hat_vein, 0.5)
	draw_line(vm2, vm2 + Vector2(2.0, 1.0), hat_vein, 0.5)
	draw_line(vm3, vm3 + Vector2(-3.5, -1.0), hat_vein, 0.5)
	draw_line(vm4, vm4 + Vector2(-2.5, -0.8), Color(hat_vein.r, hat_vein.g, hat_vein.b, 0.35), 0.4)

	# Red feather with barbs (extended 15%, brighter, more barbs)
	var feather_base = hat_base_pos + Vector2(7, -1)
	var feather_tip = feather_base + Vector2(20.5, -13.8)
	var feather_mid = feather_base + (feather_tip - feather_base) * 0.5
	# Quill
	draw_line(feather_base, feather_tip, Color(0.75, 0.10, 0.06), 1.8)
	# Feather body (brighter red)
	draw_line(feather_base + (feather_tip - feather_base) * 0.1, feather_tip - (feather_tip - feather_base) * 0.05, Color(0.92, 0.18, 0.08), 4.0)
	draw_line(feather_mid, feather_tip, Color(0.96, 0.24, 0.12), 2.8)
	# Feather barbs (9 barbs, longer)
	var f_d = (feather_tip - feather_base).normalized()
	var f_p = f_d.rotated(PI / 2.0)
	for fbi in range(9):
		var bt = 0.08 + float(fbi) * 0.10
		var barb_o = feather_base + (feather_tip - feather_base) * bt
		var blen = 3.5 - abs(float(fbi) - 4.0) * 0.3
		draw_line(barb_o, barb_o + f_p * blen + f_d * 1.0, Color(0.88, 0.16, 0.06, 0.8), 0.8)
		draw_line(barb_o, barb_o - f_p * blen + f_d * 1.0, Color(0.88, 0.16, 0.06, 0.8), 0.8)
	# Feather shine
	draw_line(feather_mid + f_p * 0.3, feather_mid + f_d * 5.0, Color(0.98, 0.42, 0.32, 0.4), 0.9)
	# Feather sway
	var f_sway = sin(_time * 3.0) * 2.0
	draw_line(feather_tip, feather_tip + f_p * f_sway + f_d * 3.0, Color(0.90, 0.20, 0.10, 0.5), 1.0)

	# === Tier 2+: Tinker Bell orbiting with sparkle trail ===
	if upgrade_tier >= 2:
		var tink_angle = _time * 1.8
		var tink_radius = 38.0
		var tink_bob_val = sin(_time * 4.0) * 3.5
		var tink_pos = body_offset + Vector2(cos(tink_angle) * tink_radius, sin(tink_angle) * tink_radius * 0.6 + tink_bob_val)
		# Sparkle trail
		for trail_i in range(5):
			var trail_a = tink_angle - float(trail_i + 1) * 0.3
			var trail_b = sin((_time - float(trail_i) * 0.15) * 4.0) * 3.5
			var trail_p = body_offset + Vector2(cos(trail_a) * tink_radius, sin(trail_a) * tink_radius * 0.6 + trail_b)
			var trail_alpha = 0.4 - float(trail_i) * 0.07
			var trail_size = 3.5 - float(trail_i) * 0.5
			draw_circle(trail_p, trail_size, Color(1.0, 0.92, 0.4, trail_alpha))
			if trail_i < 2:
				draw_line(trail_p - Vector2(trail_size, 0), trail_p + Vector2(trail_size, 0), Color(1.0, 1.0, 0.8, trail_alpha * 0.4), 0.5)
				draw_line(trail_p - Vector2(0, trail_size), trail_p + Vector2(0, trail_size), Color(1.0, 1.0, 0.8, trail_alpha * 0.4), 0.5)
		# Outer glow
		draw_circle(tink_pos, 10.0, Color(1.0, 0.9, 0.3, 0.12))
		draw_circle(tink_pos, 7.0, Color(1.0, 0.92, 0.35, 0.2))
		# Tinker Bell body
		draw_circle(tink_pos, 4.0, Color(1.0, 0.95, 0.4, 0.85))
		draw_circle(tink_pos, 2.5, Color(1.0, 1.0, 0.7, 0.95))
		# Head
		var tink_head = tink_pos + Vector2.from_angle(tink_angle) * 3.5
		draw_circle(tink_head, 2.0, Color(1.0, 0.95, 0.5, 0.9))
		draw_circle(tink_head, 1.3, Color(1.0, 1.0, 0.8))
		# Hair bun
		draw_circle(tink_head + Vector2.from_angle(tink_angle) * 1.3, 1.0, Color(1.0, 0.85, 0.3))
		# Dress
		var tink_body_dir = Vector2.from_angle(tink_angle + PI)
		var tink_perp_dir = tink_body_dir.rotated(PI / 2.0)
		var dress_pts = PackedVector2Array([
			tink_pos - tink_body_dir * 1.0 + tink_perp_dir * 1.5,
			tink_pos - tink_body_dir * 1.0 - tink_perp_dir * 1.5,
			tink_pos + tink_body_dir * 3.5 - tink_perp_dir * 3.0,
			tink_pos + tink_body_dir * 3.5 + tink_perp_dir * 3.0,
		])
		draw_colored_polygon(dress_pts, Color(0.5, 0.95, 0.4, 0.55))
		# Wings (rapid flutter)
		var wing_flutter = sin(_time * 14.0) * 3.0
		draw_line(tink_pos + tink_perp_dir * 2.0, tink_pos + tink_perp_dir * (9.0 + wing_flutter) + Vector2(0, -2.0), Color(0.9, 0.95, 1.0, 0.5), 2.0)
		draw_line(tink_pos - tink_perp_dir * 2.0, tink_pos - tink_perp_dir * (9.0 - wing_flutter) + Vector2(0, -2.0), Color(0.9, 0.95, 1.0, 0.5), 2.0)
		# Lower wings
		draw_line(tink_pos + tink_perp_dir * 1.5, tink_pos + tink_perp_dir * (6.0 + wing_flutter * 0.6) + Vector2(0, 1.5), Color(0.85, 0.92, 1.0, 0.35), 1.5)
		draw_line(tink_pos - tink_perp_dir * 1.5, tink_pos - tink_perp_dir * (6.0 - wing_flutter * 0.6) + Vector2(0, 1.5), Color(0.85, 0.92, 1.0, 0.35), 1.5)
		# Wing tip sparkle
		var wing_r_tip = tink_pos + tink_perp_dir * (9.0 + wing_flutter) + Vector2(0, -2.0)
		var wing_l_tip = tink_pos - tink_perp_dir * (9.0 - wing_flutter) + Vector2(0, -2.0)
		draw_circle(wing_r_tip, 1.2, Color(1.0, 1.0, 0.9, 0.35 + sin(_time * 6.0) * 0.15))
		draw_circle(wing_l_tip, 1.2, Color(1.0, 1.0, 0.9, 0.35 + cos(_time * 6.0) * 0.15))

	# === Tier 4: Golden fairy-dust aura ===
	if upgrade_tier >= 4:
		var aura_pulse = sin(_time * 2.5) * 5.0
		draw_circle(body_offset, 52.0 + aura_pulse, Color(1.0, 0.85, 0.3, 0.04))
		draw_circle(body_offset, 42.0 + aura_pulse * 0.6, Color(1.0, 0.88, 0.35, 0.06))
		draw_circle(body_offset, 34.0 + aura_pulse * 0.3, Color(1.0, 0.90, 0.4, 0.08))
		draw_arc(body_offset, 48.0 + aura_pulse, 0, TAU, 32, Color(1.0, 0.85, 0.35, 0.18), 2.5)
		draw_arc(body_offset, 38.0 + aura_pulse * 0.5, 0, TAU, 24, Color(1.0, 0.90, 0.4, 0.1), 1.8)
		# Orbiting golden sparkles
		for gs in range(8):
			var gs_a = _time * (0.8 + float(gs % 3) * 0.3) + float(gs) * TAU / 8.0
			var gs_r = 40.0 + aura_pulse + float(gs % 3) * 4.0
			var gs_p = body_offset + Vector2.from_angle(gs_a) * gs_r
			var gs_size = 1.5 + sin(_time * 3.0 + float(gs) * 1.5) * 0.8
			var gs_alpha = 0.35 + sin(_time * 3.0 + float(gs)) * 0.2
			draw_circle(gs_p, gs_size, Color(1.0, 0.9, 0.4, gs_alpha))
		# Rising fairy dust motes
		for rm in range(4):
			var rm_seed = float(rm) * 3.14
			var rm_x = sin(_time * 0.8 + rm_seed) * 25.0
			var rm_y = -fmod(_time * 18.0 + rm_seed * 10.0, 70.0) + 35.0
			var rm_alpha = 0.25 * (1.0 - abs(rm_y) / 35.0)
			if rm_alpha > 0.0:
				draw_circle(body_offset + Vector2(rm_x, rm_y), 1.2, Color(1.0, 0.92, 0.5, rm_alpha))

	# === Awaiting ability choice indicator ===
	if awaiting_ability_choice:
		var pulse = (sin(_time * 4.0) + 1.0) * 0.5
		draw_circle(Vector2.ZERO, 60.0 + pulse * 6.0, Color(0.5, 1.0, 0.6, 0.1 + pulse * 0.1))
		draw_arc(Vector2.ZERO, 60.0 + pulse * 6.0, 0, TAU, 32, Color(0.5, 1.0, 0.6, 0.3 + pulse * 0.3), 2.5)
		var font3 = ThemeDB.fallback_font
		draw_string(font3, Vector2(-16, -68), "!", HORIZONTAL_ALIGNMENT_CENTER, 32, 30, Color(0.5, 1.0, 0.6, 0.7 + pulse * 0.3))

	# Damage dealt counter
	if damage_dealt > 0:
		var font = ThemeDB.fallback_font
		var dmg_text = str(int(damage_dealt)) + " DMG"
		if stat_upgrade_level > 0:
			dmg_text += " • Lv." + str(stat_upgrade_level)
		draw_string(font, Vector2(-36, 56), dmg_text, HORIZONTAL_ALIGNMENT_LEFT, 160, 12, Color(1.0, 0.84, 0.0, 0.5))

	# Upgrade name flash
	if _upgrade_flash > 0.0 and _upgrade_name != "":
		var font2 = ThemeDB.fallback_font
		draw_string(font2, Vector2(-80, -60), _upgrade_name, HORIZONTAL_ALIGNMENT_CENTER, 160, 16, Color(0.5, 1.0, 0.6, min(_upgrade_flash, 1.0)))

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

func _damage_mult() -> float:
	return (1.0 + _synergy_buffs.get("damage", 0.0) + _meta_buffs.get("damage", 0.0)) * power_damage_mult

func _range_mult() -> float:
	return 1.0 + _synergy_buffs.get("range", 0.0) + _meta_buffs.get("range", 0.0)

func _speed_mult() -> float:
	return 1.0 + _synergy_buffs.get("attack_speed", 0.0) + _meta_buffs.get("attack_speed", 0.0)

func _gold_mult() -> float:
	return 1.0 + _synergy_buffs.get("gold_bonus", 0.0) + _meta_buffs.get("gold_bonus", 0.0)
