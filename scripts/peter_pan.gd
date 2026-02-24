extends Node2D
## Peter Pan — stationary striker from JM Barrie's Peter and Wendy (1911).
## Hovers in place, throwing daggers rapidly at nearby enemies.
## Tier 1: "Shadow" — shadow flies around range circle doing low damage
## Tier 2: "Fairy Dust" — aura gives +3% range/damage to Peter and nearby towers
## Tier 3: "Tick-Tock Croc" — crocodile eats every 30th enemy (instakill)
## Tier 4: "Never Land" — costs 1000 gold, glows gold, +20% damage

var damage: float = 19.0
var fire_rate: float = 1.25
var attack_range: float = 85.0
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

# Tier 1: Shadow — orbiting shadow that damages enemies
var shadow_enabled: bool = false
var _shadow_angle: float = 0.0
var _shadow_damage_timer: float = 0.0

# Tier 2: Fairy Dust — aura buff for Peter and nearby towers
var fairy_dust_active: bool = false
var _fairy_flash: float = 0.0

# Tier 3: Tick-Tock Croc — eats every 30th enemy
var croc_enabled: bool = false
var _croc_kill_count: int = 0
var _croc_flash: float = 0.0
var _croc_eating: bool = false
var _croc_eat_timer: float = 0.0
var _croc_drag_progress: float = 0.0
var _croc_drag_start: Vector2 = Vector2.ZERO
var _croc_drag_start: Vector2 = Vector2.ZERO
var _croc_drag_progress: float = 0.0

# Tier 4: Never Land — golden glow, +20% damage
var neverland_active: bool = false

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
	"Shadow flies around range doing low damage",
	"Aura gives +3% range & damage to nearby towers",
	"Crocodile eats every 30th enemy (instakill)",
	"Glow gold, +20% damage boost"
]
const TIER_COSTS = [75, 165, 280, 1000]
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
var _game_font: Font

func _ready() -> void:
	var _ff := FontFile.new()
	_ff.data = FileAccess.get_file_as_bytes("res://fonts/Cinzel.ttf")
	_game_font = _ff
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

	# Tier 1: Shadow orbits range circle, damages enemies it passes
	if shadow_enabled:
		_shadow_angle += delta * 1.8  # orbits every ~3.5 seconds
		_shadow_damage_timer -= delta
		if _shadow_damage_timer <= 0.0:
			_shadow_damage_timer = 0.5  # hits twice per second
			var eff_range = attack_range * _range_mult()
			var shadow_pos = _home_position + Vector2(cos(_shadow_angle), sin(_shadow_angle)) * eff_range * 0.75
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if shadow_pos.distance_to(enemy.global_position) < 25.0 and enemy.has_method("take_damage"):
					var sdmg = damage * 0.15  # low damage
					enemy.take_damage(sdmg)
					register_damage(sdmg)

	# Tier 2: Fairy Dust — persistent aura buff to Peter and nearby towers
	if fairy_dust_active:
		_fairy_flash = 0.5  # keep sparkle visible
		# Buff is applied in _apply_upgrade and persists — visual only here

	# Tier 3: Tick-Tock Croc — drag animation
	if _croc_eating:
		_croc_eat_timer -= delta
		_croc_drag_progress = clampf(1.0 - (_croc_eat_timer / 1.5), 0.0, 1.0)
		if _croc_eat_timer <= 0.0:
			_croc_eating = false
			_croc_drag_progress = 0.0

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
		# Tier 3: Croc eats every 30th kill
		_croc_try_eat(t)

func _croc_try_eat(killed_enemy: Node2D) -> void:
	# Called when an enemy is killed — check if it's the 30th kill
	if not croc_enabled:
		return
	_croc_kill_count += 1
	if _croc_kill_count >= 30:
		_croc_kill_count = 0
		# Find closest living enemy and instakill it
		var closest: Node2D = null
		var closest_dist: float = attack_range * _range_mult()
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy) or enemy == killed_enemy:
				continue
			var dist = _home_position.distance_to(enemy.global_position)
			if dist < closest_dist and enemy.has_method("take_damage"):
				closest = enemy
				closest_dist = dist
		if closest:
			if _croc_player and not _is_sfx_muted(): _croc_player.play()
			_croc_flash = 1.0
			_croc_eating = true
			_croc_eat_timer = 1.5
			_croc_drag_progress = 0.0
			_croc_drag_start = closest.global_position - global_position  # relative pos
			var kill_dmg = closest.health + 10.0
			closest.take_damage(kill_dmg)
			register_damage(kill_dmg)
			if gold_bonus > 0:
				var main = get_tree().get_first_node_in_group("main")
				if main:
					main.add_gold(gold_bonus * 3)

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
		1: # Shadow — orbiting shadow entity
			shadow_enabled = true
			damage = 25.0
			fire_rate = 1.5
			attack_range = 93.0
		2: # Fairy Dust — +3% range/damage aura to self + nearby towers
			fairy_dust_active = true
			damage = 30.0
			fire_rate = 1.75
			attack_range = 100.0
			gold_bonus = 3
			_apply_fairy_dust_buffs()
		3: # Tick-Tock Croc — eats every 30th kill
			croc_enabled = true
			damage = 38.0
			fire_rate = 2.0
			attack_range = 110.0
			gold_bonus = 4
		4: # Never Land — glow gold, +20% damage
			neverland_active = true
			damage *= 1.20
			fire_rate = 2.5
			attack_range = 125.0
			gold_bonus = 5

func _apply_fairy_dust_buffs() -> void:
	# Buff nearby towers with +3% range and damage
	var main = get_tree().get_first_node_in_group("main")
	if not main:
		return
	for tower in get_tree().get_nodes_in_group("towers"):
		if tower == self:
			continue
		if _home_position.distance_to(tower.global_position) < attack_range * _range_mult():
			if "damage" in tower:
				tower.damage *= 1.03
			if "attack_range" in tower:
				tower.attack_range *= 1.03

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
	# Peter Pan dagger throw — light, quick air whoosh with subtle blade zip
	# Musical notes for variation across throws
	var note_freqs := [392.0, 440.0, 493.88, 523.25, 587.33, 659.25, 739.99, 783.99]  # G4-G5 major scale
	var mix_rate := 44100
	_attack_sounds_by_tier = []

	# --- Tier 0: Dagger Toss (quick airy whoosh + soft blade zip) ---
	var t0 := []
	for note_idx in note_freqs.size():
		var nf: float = note_freqs[note_idx]
		var dur := 0.09
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * dur))
		for i in samples.size():
			var t := float(i) / mix_rate
			var tn := t / dur
			# Quick air whoosh — bandpass noise sweep
			var env := (1.0 - tn) * (1.0 - tn) * exp(-t * 35.0)
			var noise := (randf() * 2.0 - 1.0) * 0.18 * env
			# Swept bandpass gives directional feel
			var sweep := sin(TAU * lerpf(2200.0, 800.0, tn) * t) * 0.08 * env
			# Soft blade zip — brief, clean tone
			var blade := sin(TAU * nf * 2.0 * t) * exp(-t * 55.0) * 0.12
			samples[i] = clampf(noise + sweep + blade, -1.0, 1.0)
		t0.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t0)

	# --- Tier 1: Sharpened Dagger (crisper whoosh + light sparkle tail) ---
	var t1 := []
	for note_idx in note_freqs.size():
		var nf: float = note_freqs[note_idx]
		var dur := 0.11
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * dur))
		for i in samples.size():
			var t := float(i) / mix_rate
			var tn := t / dur
			var env := (1.0 - tn) * exp(-t * 30.0)
			var noise := (randf() * 2.0 - 1.0) * 0.16 * env
			var sweep := sin(TAU * lerpf(2800.0, 900.0, tn) * t) * 0.10 * env
			# Slightly brighter blade
			var blade := sin(TAU * nf * 2.0 * t) * exp(-t * 50.0) * 0.14
			# Gentle fairy sparkle — quiet high tinkle
			var sparkle := sin(TAU * nf * 5.0 * t) * exp(-t * 80.0) * 0.04
			samples[i] = clampf(noise + sweep + blade + sparkle, -1.0, 1.0)
		t1.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t1)

	# --- Tier 2: Shadow Dagger (deeper whoosh + mystical undertone) ---
	var t2 := []
	for note_idx in note_freqs.size():
		var nf: float = note_freqs[note_idx]
		var dur := 0.12
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * dur))
		for i in samples.size():
			var t := float(i) / mix_rate
			var tn := t / dur
			var env := (1.0 - tn) * exp(-t * 25.0)
			var noise := (randf() * 2.0 - 1.0) * 0.20 * env
			# Lower sweep for darker feel
			var sweep := sin(TAU * lerpf(1800.0, 500.0, tn) * t) * 0.12 * env
			# Blade with sub-octave body
			var blade := sin(TAU * nf * t) * exp(-t * 40.0) * 0.10
			blade += sin(TAU * nf * 2.0 * t) * exp(-t * 48.0) * 0.12
			# Mystical hum — soft low undertone
			var hum := sin(TAU * nf * 0.5 * t) * exp(-t * 20.0) * 0.06
			samples[i] = clampf(noise + sweep + blade + hum, -1.0, 1.0)
		t2.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t2)

	# --- Tier 3: Enchanted Dagger (airy throw + pixie dust shimmer) ---
	var t3 := []
	for note_idx in note_freqs.size():
		var nf: float = note_freqs[note_idx]
		var dur := 0.14
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * dur))
		for i in samples.size():
			var t := float(i) / mix_rate
			var tn := t / dur
			var env := (1.0 - tn) * exp(-t * 22.0)
			var noise := (randf() * 2.0 - 1.0) * 0.15 * env
			var sweep := sin(TAU * lerpf(2500.0, 700.0, tn) * t) * 0.10 * env
			# Clean blade with harmonic body
			var blade := sin(TAU * nf * 2.0 * t) * exp(-t * 38.0) * 0.14
			blade += sin(TAU * nf * 3.0 * t) * exp(-t * 50.0) * 0.06
			# Pixie shimmer — gentle delayed sparkles
			var sp_t := maxf(t - 0.02, 0.0)
			var shimmer := sin(TAU * nf * 6.0 * sp_t) * exp(-sp_t * 60.0) * 0.05
			shimmer += sin(TAU * nf * 8.0 * sp_t) * exp(-sp_t * 70.0) * 0.03
			# Soft chime tail
			var chime := sin(TAU * nf * 4.0 * t) * exp(-t * 45.0) * 0.04
			samples[i] = clampf(noise + sweep + blade + shimmer + chime, -1.0, 1.0)
		t3.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t3)

	# --- Tier 4: Neverland Dagger (full fairy-infused throw + dust cascade) ---
	var t4 := []
	for note_idx in note_freqs.size():
		var nf: float = note_freqs[note_idx]
		var dur := 0.16
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * dur))
		for i in samples.size():
			var t := float(i) / mix_rate
			var tn := t / dur
			var env := (1.0 - tn) * exp(-t * 20.0)
			var noise := (randf() * 2.0 - 1.0) * 0.14 * env
			var sweep := sin(TAU * lerpf(3000.0, 800.0, tn) * t) * 0.10 * env
			# Rich blade with warm harmonics
			var blade := sin(TAU * nf * 2.0 * t) * exp(-t * 32.0) * 0.13
			blade += sin(TAU * nf * 3.0 * t) * exp(-t * 40.0) * 0.07
			blade += sin(TAU * nf * 4.0 * t) * exp(-t * 48.0) * 0.04
			# Fairy dust cascade — staggered gentle sparkles
			var sp1 := sin(TAU * nf * 6.0 * t) * exp(-t * 45.0) * 0.05
			var sp_t2 := maxf(t - 0.025, 0.0)
			var sp2 := sin(TAU * nf * 7.5 * sp_t2) * exp(-sp_t2 * 55.0) * 0.04
			var sp_t3 := maxf(t - 0.05, 0.0)
			var sp3 := sin(TAU * nf * 9.0 * sp_t3) * exp(-sp_t3 * 65.0) * 0.03
			# Warm fairy chime undertone
			var chime := sin(TAU * nf * 1.5 * t) * exp(-t * 18.0) * 0.05
			samples[i] = clampf(noise + sweep + blade + sp1 + sp2 + sp3 + chime, -1.0, 1.0)
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

	# === CHARACTER POSITIONS (chibi Bloons TD proportions ~48px) ===
	var feet_y = body_offset + Vector2(lean * 0.8, 10.0 - playful_bounce * 0.5)
	var leg_top = body_offset + Vector2(lean * 0.5, 0.0)
	var torso_center = body_offset + Vector2(lean * 0.3, -8.0)
	var neck_base = body_offset + Vector2(-lean * 0.2, -14.0)
	var head_center = body_offset + Vector2(-lean * 0.4, -26.0 - playful_bounce * 0.3)
	var OL = Color(0.06, 0.06, 0.08)

	# === Tier 4: Fairy dust particles floating around ===
	if upgrade_tier >= 4:
		for fd in range(8):
			var fd_seed = float(fd) * 2.37
			var fd_angle = _time * (0.4 + fmod(fd_seed, 0.6)) + fd_seed
			var fd_radius = 24.0 + fmod(fd_seed * 7.3, 30.0)
			var fd_pos = body_offset + Vector2(cos(fd_angle) * fd_radius, sin(fd_angle) * fd_radius * 0.6)
			var fd_alpha = 0.35 + sin(_time * 3.0 + fd_seed * 2.0) * 0.2
			var fd_size = 1.5 + sin(_time * 2.5 + fd_seed) * 0.5
			draw_circle(fd_pos, fd_size + 0.5, Color(1.0, 0.85, 0.2, fd_alpha * 0.5))
			draw_circle(fd_pos, fd_size, Color(1.0, 0.95, 0.5, fd_alpha))

	# === Tier 3+: Crocodile lurking beside platform ===
	if upgrade_tier >= 3:
		var croc_home = Vector2(body_offset.x + 22.0, plat_y + 2.0)
		# Croc moves toward enemy during drag, then returns
		var croc_base = croc_home
		if _croc_eating and _croc_drag_progress < 0.4:
			# Croc lunges toward enemy position
			var lunge_target = _croc_drag_start + Vector2(0, -5)
			croc_base = croc_home.lerp(lunge_target, _croc_drag_progress * 2.5)
		elif _croc_eating:
			# Croc dragging back to base
			var return_progress = (_croc_drag_progress - 0.4) / 0.6
			croc_base = (_croc_drag_start + Vector2(0, -5)).lerp(croc_home, return_progress)
		# Jaws open wider when eating
		var jaw_open = sin(_time * 2.0) * 0.35
		if _croc_eating:
			jaw_open = 0.8 + sin(_time * 8.0) * 0.2  # Big chomp animation
			# Draw the dragged enemy body being pulled toward Peter's feet
			var drag_pos = _croc_drag_start.lerp(Vector2(0, 12), _croc_drag_progress)
			var drag_alpha = 1.0 - _croc_drag_progress * 0.6
			# Enemy silhouette being dragged
			draw_circle(drag_pos + Vector2(0, -8), 6.0, Color(0.3, 0.1, 0.1, drag_alpha * 0.7))
			draw_circle(drag_pos, 5.0, Color(0.3, 0.1, 0.1, drag_alpha * 0.6))
			draw_line(drag_pos + Vector2(-3, 4), drag_pos + Vector2(-4, 12), Color(0.3, 0.1, 0.1, drag_alpha * 0.5), 2.0)
			draw_line(drag_pos + Vector2(3, 4), drag_pos + Vector2(4, 12), Color(0.3, 0.1, 0.1, drag_alpha * 0.5), 2.0)
			# Splash/water ripples at Peter's feet
			if _croc_drag_progress > 0.5:
				var ripple = sin(_time * 10.0) * 3.0
				draw_arc(Vector2(0, 14), 8.0 + ripple, 0, PI, 12, Color(0.2, 0.5, 0.3, 0.3 * (1.0 - _croc_drag_progress)), 1.5)
				draw_arc(Vector2(0, 14), 12.0 + ripple * 0.5, 0, PI, 12, Color(0.2, 0.5, 0.3, 0.15 * (1.0 - _croc_drag_progress)), 1.0)
			# Blood splash near croc mouth
			for be in range(4):
				var be_a = _time * 6.0 + float(be) * TAU / 4.0
				var be_r = 6.0 + sin(_time * 10.0 + float(be)) * 3.0
				draw_circle(croc_base + Vector2(16.0 + cos(be_a) * be_r, sin(be_a) * be_r), 1.5, Color(0.8, 0.2, 0.1, 0.4))
		var tail_sway = sin(_time * 1.8) * 4.0
		# Tail (outline then fill)
		draw_line(croc_base + Vector2(-7, 0), croc_base + Vector2(-18, tail_sway), OL, 5.5)
		draw_line(croc_base + Vector2(-18, tail_sway), croc_base + Vector2(-25, -tail_sway * 0.5), OL, 4.0)
		draw_line(croc_base + Vector2(-7, 0), croc_base + Vector2(-18, tail_sway), Color(0.22, 0.52, 0.18), 3.5)
		draw_line(croc_base + Vector2(-18, tail_sway), croc_base + Vector2(-25, -tail_sway * 0.5), Color(0.20, 0.48, 0.16), 2.5)
		# Body (outline then fill)
		draw_circle(croc_base, 9.0, OL)
		draw_circle(croc_base, 7.0, Color(0.25, 0.55, 0.20))
		# Belly
		draw_circle(croc_base + Vector2(1, 2), 4.5, Color(0.50, 0.65, 0.35))
		# Snout (outline then fill)
		draw_line(croc_base + Vector2(6, 0), croc_base + Vector2(18, 0), OL, 7.0)
		draw_line(croc_base + Vector2(6, 0), croc_base + Vector2(18, 0), Color(0.28, 0.55, 0.22), 5.0)
		# Jaws open
		draw_line(croc_base + Vector2(18, 0), croc_base + Vector2(14, -4.0 - jaw_open * 6.0), OL, 3.5)
		draw_line(croc_base + Vector2(18, 0), croc_base + Vector2(14, 4.0 + jaw_open * 6.0), OL, 3.0)
		draw_line(croc_base + Vector2(18, 0), croc_base + Vector2(14, -4.0 - jaw_open * 6.0), Color(0.25, 0.52, 0.20), 2.0)
		draw_line(croc_base + Vector2(18, 0), croc_base + Vector2(14, 4.0 + jaw_open * 6.0), Color(0.22, 0.48, 0.18), 1.5)
		# Teeth
		for t in range(3):
			var tx = 17.0 - float(t) * 2.0
			draw_line(croc_base + Vector2(tx, -2.5 - jaw_open * 4.0), croc_base + Vector2(tx, -4.5 - jaw_open * 4.0), Color(0.98, 0.97, 0.90), 1.2)
			draw_line(croc_base + Vector2(tx, 2.5 + jaw_open * 4.0), croc_base + Vector2(tx, 4.5 + jaw_open * 4.0), Color(0.95, 0.95, 0.85), 1.0)
		# Eye (outline, yellow, slit pupil)
		draw_circle(croc_base + Vector2(3, -5), 3.5, OL)
		draw_circle(croc_base + Vector2(3, -5), 2.5, Color(0.95, 0.85, 0.10))
		draw_line(croc_base + Vector2(3, -7), croc_base + Vector2(3, -3), Color(0.08, 0.08, 0.04), 1.2)
		# Scale bumps
		for sb in range(3):
			var sbp = croc_base + Vector2(-4.0 + float(sb) * 3.0, -5.0)
			draw_circle(sbp, 1.8, Color(0.18, 0.42, 0.14))

	# === Tier 1+: Peter's shadow orbiting range circle ===
	if shadow_enabled:
		var eff_range = attack_range * _range_mult()
		var shadow_off = body_offset + Vector2(cos(_shadow_angle), sin(_shadow_angle)) * eff_range * 0.75
		var shadow_alpha: float = 0.35 + sin(_time * 4.0) * 0.1
		var sc = Color(0.04, 0.04, 0.08, shadow_alpha)
		# Shadow trail (3 fading afterimages)
		for tr in range(3):
			var trail_angle = _shadow_angle - float(tr + 1) * 0.3
			var trail_pos = body_offset + Vector2(cos(trail_angle), sin(trail_angle)) * eff_range * 0.75
			var ta = shadow_alpha * (0.4 - float(tr) * 0.12)
			draw_circle(trail_pos + Vector2(0, -12.0), 5.0 - float(tr), Color(0.04, 0.04, 0.08, ta))
		# Shadow head
		draw_circle(shadow_off + Vector2(0, -18.0), 7.0, sc)
		# Shadow hat
		var s_hat = PackedVector2Array([
			shadow_off + Vector2(-5, -22), shadow_off + Vector2(5, -22),
			shadow_off + Vector2(4, -32),
		])
		draw_colored_polygon(s_hat, Color(0.04, 0.04, 0.08, shadow_alpha * 0.8))
		# Shadow body
		var s_body = PackedVector2Array([
			shadow_off + Vector2(-6, -12), shadow_off + Vector2(6, -12),
			shadow_off + Vector2(7, 4), shadow_off + Vector2(-7, 4),
		])
		draw_colored_polygon(s_body, sc)
		# Shadow arms (wispy, reaching out)
		var wave = sin(_time * 3.0) * 4.0
		draw_line(shadow_off + Vector2(-6, -8), shadow_off + Vector2(-14 - wave, -4), sc, 2.5)
		draw_line(shadow_off + Vector2(6, -8), shadow_off + Vector2(14 + wave, -10), sc, 2.5)

	# === BLOONS TD CARTOON CHARACTER BODY ===
	var green_dark = Color(0.14, 0.48, 0.10)
	var green_mid = Color(0.18, 0.58, 0.15)
	var green_light = Color(0.25, 0.68, 0.20)
	var brown_boot = Color(0.42, 0.28, 0.12)

	# --- Pointed elf boots with curled toes ---
	var l_foot = feet_y + Vector2(-5, 0)
	var r_foot = feet_y + Vector2(5, 0)
	# Boot circles (outline then fill)
	draw_circle(l_foot, 5.0, OL)
	draw_circle(l_foot, 3.5, brown_boot)
	draw_circle(r_foot, 5.0, OL)
	draw_circle(r_foot, 3.5, brown_boot)
	# Curled toe tips (left curls left, right curls right)
	draw_line(l_foot + Vector2(-3, -1), l_foot + Vector2(-9, -5), OL, 4.0)
	draw_line(l_foot + Vector2(-9, -5), l_foot + Vector2(-8, -8), OL, 3.5)
	draw_line(l_foot + Vector2(-3, -1), l_foot + Vector2(-9, -5), brown_boot, 2.5)
	draw_line(l_foot + Vector2(-9, -5), l_foot + Vector2(-8, -8), brown_boot, 2.0)
	draw_line(r_foot + Vector2(3, -1), r_foot + Vector2(9, -5), OL, 4.0)
	draw_line(r_foot + Vector2(9, -5), r_foot + Vector2(8, -8), OL, 3.5)
	draw_line(r_foot + Vector2(3, -1), r_foot + Vector2(9, -5), brown_boot, 2.5)
	draw_line(r_foot + Vector2(9, -5), r_foot + Vector2(8, -8), brown_boot, 2.0)
	# Bells on toe tips
	draw_circle(l_foot + Vector2(-8, -8), 2.5, OL)
	draw_circle(l_foot + Vector2(-8, -8), 1.8, Color(0.90, 0.80, 0.15))
	draw_circle(l_foot + Vector2(-8, -8.5), 0.8, Color(1.0, 0.95, 0.4))
	draw_circle(r_foot + Vector2(8, -8), 2.5, OL)
	draw_circle(r_foot + Vector2(8, -8), 1.8, Color(0.90, 0.80, 0.15))
	draw_circle(r_foot + Vector2(8, -8.5), 0.8, Color(1.0, 0.95, 0.4))

	# --- Short cartoon legs (thick outlined lines) ---
	var l_hip = leg_top + Vector2(-4, 0)
	var r_hip = leg_top + Vector2(4, 0)
	# Outline legs
	draw_line(l_hip, l_foot, OL, 6.5)
	draw_line(r_hip, r_foot, OL, 6.5)
	# Fill legs (green tights)
	draw_line(l_hip, l_foot, green_dark, 4.5)
	draw_line(r_hip, r_foot, green_dark, 4.5)
	# Knee joints
	var l_knee = l_hip.lerp(l_foot, 0.5)
	var r_knee = r_hip.lerp(r_foot, 0.5)
	draw_circle(l_knee, 3.5, OL)
	draw_circle(l_knee, 2.5, green_mid)
	draw_circle(r_knee, 3.5, OL)
	draw_circle(r_knee, 2.5, green_mid)

	# --- Green leaf tunic (polygon body with jagged hem) ---
	var tunic_top_l = neck_base + Vector2(-10, 0)
	var tunic_top_r = neck_base + Vector2(10, 0)
	var tunic_bot_l = leg_top + Vector2(-8, 2)
	var tunic_bot_r = leg_top + Vector2(8, 2)
	# Outline polygon
	var tunic_ol = PackedVector2Array([
		tunic_top_l + Vector2(-1.5, -1), tunic_top_r + Vector2(1.5, -1),
		tunic_bot_r + Vector2(1.5, 1), tunic_bot_l + Vector2(-1.5, 1),
	])
	draw_colored_polygon(tunic_ol, OL)
	# Fill polygon
	var tunic_pts = PackedVector2Array([
		tunic_top_l, tunic_top_r, tunic_bot_r, tunic_bot_l,
	])
	draw_colored_polygon(tunic_pts, green_mid)
	# Lighter center panel
	var panel_pts = PackedVector2Array([
		torso_center + Vector2(-4, -5), torso_center + Vector2(4, -5),
		torso_center + Vector2(4, 7), torso_center + Vector2(-4, 7),
	])
	draw_colored_polygon(panel_pts, green_light)
	# V-neckline
	draw_line(neck_base + Vector2(-5, 0), neck_base + Vector2(0, 4), OL, 1.5)
	draw_line(neck_base + Vector2(5, 0), neck_base + Vector2(0, 4), OL, 1.5)
	# Jagged leaf hem at bottom
	for ji in range(6):
		var jx = -7.0 + float(ji) * 3.0
		var jag = 3.0 + sin(float(ji) * 2.3 + _time * 1.5) * 1.5 + float(ji % 2) * 1.5
		var jag_pts = PackedVector2Array([
			leg_top + Vector2(jx - 1.5, 1), leg_top + Vector2(jx + 1.5, 1),
			leg_top + Vector2(jx, 1.0 + jag),
		])
		draw_colored_polygon(jag_pts, green_dark)
		# Leaf outline on jags
		draw_line(leg_top + Vector2(jx - 1.5, 1), leg_top + Vector2(jx, 1.0 + jag), OL, 1.0)
		draw_line(leg_top + Vector2(jx + 1.5, 1), leg_top + Vector2(jx, 1.0 + jag), OL, 1.0)

	# --- Vine belt with leaf buckle ---
	var belt_y = torso_center + Vector2(0, 5)
	draw_line(belt_y + Vector2(-9, 0), belt_y + Vector2(9, 0), OL, 4.5)
	draw_line(belt_y + Vector2(-9, 0), belt_y + Vector2(9, 0), Color(0.35, 0.25, 0.10), 3.0)
	# Vine twist bumps
	for vi in range(4):
		var vp = belt_y + Vector2(-6.0 + float(vi) * 4.0, sin(float(vi) * PI + _time * 2.0) * 0.8)
		draw_circle(vp, 2.0, OL)
		draw_circle(vp, 1.3, Color(0.28, 0.48, 0.14))
	# Leaf buckle (diamond shape)
	var buckle = belt_y
	var buckle_pts = PackedVector2Array([
		buckle + Vector2(-3.5, 0), buckle + Vector2(0, -4),
		buckle + Vector2(3.5, 0), buckle + Vector2(0, 4),
	])
	draw_colored_polygon(buckle_pts, OL)
	var buckle_inner = PackedVector2Array([
		buckle + Vector2(-2.5, 0), buckle + Vector2(0, -3),
		buckle + Vector2(2.5, 0), buckle + Vector2(0, 3),
	])
	draw_colored_polygon(buckle_inner, green_light)
	# Leaf vein on buckle
	draw_line(buckle + Vector2(0, -2), buckle + Vector2(0, 2), green_dark, 0.8)

	# --- Shoulders (round cartoon joints) ---
	var l_shoulder = neck_base + Vector2(-10, 0)
	var r_shoulder = neck_base + Vector2(10, 0)
	draw_circle(l_shoulder, 4.5, OL)
	draw_circle(l_shoulder, 3.0, green_mid)
	draw_circle(r_shoulder, 4.5, OL)
	draw_circle(r_shoulder, 3.0, green_mid)

	# --- RIGHT ARM (dagger arm) — swipes toward target ---
	var dagger_hand: Vector2
	if _attack_anim > 0.0:
		var swipe = dir.rotated(-_attack_anim * PI * 0.5 + PI * 0.3)
		dagger_hand = r_shoulder + swipe * 16.0
	else:
		dagger_hand = r_shoulder + dir * 16.0
	# Outline then fill
	draw_line(r_shoulder, dagger_hand, OL, 6.5)
	draw_line(r_shoulder, dagger_hand, skin_base, 4.5)
	# Elbow joint
	var r_elbow = r_shoulder.lerp(dagger_hand, 0.5)
	draw_circle(r_elbow, 3.5, OL)
	draw_circle(r_elbow, 2.5, skin_base)
	# Hand
	draw_circle(dagger_hand, 3.5, OL)
	draw_circle(dagger_hand, 2.5, skin_base)

	# --- LEFT ARM (on hip, cocky pose) ---
	var off_hand = torso_center + Vector2(-9, 5)
	draw_line(l_shoulder, off_hand, OL, 6.5)
	draw_line(l_shoulder, off_hand, skin_base, 4.5)
	# Elbow joint
	var l_elbow = l_shoulder.lerp(off_hand, 0.5)
	draw_circle(l_elbow, 3.5, OL)
	draw_circle(l_elbow, 2.5, skin_base)
	# Hand on hip
	draw_circle(off_hand, 3.5, OL)
	draw_circle(off_hand, 2.5, skin_base)

	# --- Dagger ---
	var dagger_dir: Vector2
	if _attack_anim > 0.0:
		dagger_dir = dir.rotated(-_attack_anim * PI * 0.5 + PI * 0.3)
	else:
		dagger_dir = dir
	var dagger_perp = dagger_dir.rotated(PI / 2.0)
	# Handle (outline then fill)
	draw_line(dagger_hand - dagger_dir * 1.0, dagger_hand + dagger_dir * 7.0, OL, 4.5)
	draw_line(dagger_hand - dagger_dir * 1.0, dagger_hand + dagger_dir * 7.0, Color(0.48, 0.34, 0.16), 3.0)
	# Cross-guard (outline then fill)
	var guard_c = dagger_hand + dagger_dir * 7.0
	draw_line(guard_c + dagger_perp * 5.0, guard_c - dagger_perp * 5.0, OL, 4.0)
	draw_line(guard_c + dagger_perp * 5.0, guard_c - dagger_perp * 5.0, Color(0.60, 0.50, 0.20), 2.5)
	# Blade (outline then fill — bright steel)
	var blade_tip = dagger_hand + dagger_dir * 22.0
	draw_line(guard_c, blade_tip, OL, 3.5)
	draw_line(guard_c, blade_tip, Color(0.82, 0.84, 0.90), 2.0)
	# Blade shine
	draw_line(guard_c + dagger_dir * 3.0, blade_tip - dagger_dir * 2.0, Color(0.95, 0.96, 1.0, 0.5), 1.0)
	# Attack glint
	if _attack_anim > 0.5:
		var glint_a = (_attack_anim - 0.5) * 2.0
		draw_circle(blade_tip, 3.0 + glint_a * 2.0, Color(1.0, 1.0, 0.95, glint_a * 0.6))

	# --- Neck (thick cartoon connector) ---
	draw_line(neck_base, head_center + Vector2(0, 10), OL, 6.0)
	draw_line(neck_base, head_center + Vector2(0, 10), skin_base, 4.0)

	# --- HEAD (big round Bloons-style head) ---
	var hair_sway = sin(_time * 2.5) * 1.5
	var hair_col = Color(0.55, 0.26, 0.10)
	var hair_hi = Color(0.65, 0.32, 0.14)

	# Hair back layer (drawn behind face)
	draw_circle(head_center, 14.0, OL)
	draw_circle(head_center, 12.0, hair_col)
	# Messy hair tufts (wild, Bloons-bold strokes)
	for h in range(7):
		var ha = float(h) * 0.9 + 0.3
		var tuft_base_pos = head_center + Vector2.from_angle(ha) * 10.0
		var sway_d = 1.0 if h % 2 == 0 else -1.0
		var tuft_tip = tuft_base_pos + Vector2.from_angle(ha) * (5.0 + float(h % 3) * 2.0) + Vector2(hair_sway * sway_d, 0)
		draw_line(tuft_base_pos, tuft_tip, OL, 3.5)
		draw_line(tuft_base_pos, tuft_tip, hair_hi if h % 2 == 0 else hair_col, 2.0)

	# Face circle (outline then fill)
	draw_circle(head_center + Vector2(0, 1), 11.0, OL)
	draw_circle(head_center + Vector2(0, 1), 9.5, skin_base)

	# Pointed ear tips peeking through hair
	# Right ear
	var r_ear_pts = PackedVector2Array([
		head_center + Vector2(9, -3), head_center + Vector2(9, 2),
		head_center + Vector2(16, -2),
	])
	draw_colored_polygon(r_ear_pts, OL)
	var r_ear_inner = PackedVector2Array([
		head_center + Vector2(9.5, -2), head_center + Vector2(9.5, 1),
		head_center + Vector2(14.5, -1.5),
	])
	draw_colored_polygon(r_ear_inner, skin_base)
	draw_circle(head_center + Vector2(12, -0.5), 1.2, Color(0.95, 0.72, 0.60))
	# Left ear
	var l_ear_pts = PackedVector2Array([
		head_center + Vector2(-9, -3), head_center + Vector2(-9, 2),
		head_center + Vector2(-16, -2),
	])
	draw_colored_polygon(l_ear_pts, OL)
	var l_ear_inner = PackedVector2Array([
		head_center + Vector2(-9.5, -2), head_center + Vector2(-9.5, 1),
		head_center + Vector2(-14.5, -1.5),
	])
	draw_colored_polygon(l_ear_inner, skin_base)
	draw_circle(head_center + Vector2(-12, -0.5), 1.2, Color(0.95, 0.72, 0.60))

	# Big cartoon eyes (Bloons style — big whites, bold outlines)
	var look_dir = dir * 1.0
	var l_eye = head_center + Vector2(-4, -1)
	var r_eye = head_center + Vector2(4, -1)
	# Eye outlines (OL)
	draw_circle(l_eye, 5.5, OL)
	draw_circle(r_eye, 5.5, OL)
	# Eye whites
	draw_circle(l_eye, 4.5, Color(0.98, 0.98, 1.0))
	draw_circle(r_eye, 4.5, Color(0.98, 0.98, 1.0))
	# Green-brown irises
	draw_circle(l_eye + look_dir, 2.8, Color(0.12, 0.52, 0.22))
	draw_circle(l_eye + look_dir, 2.0, Color(0.18, 0.65, 0.30))
	draw_circle(r_eye + look_dir, 2.8, Color(0.12, 0.52, 0.22))
	draw_circle(r_eye + look_dir, 2.0, Color(0.18, 0.65, 0.30))
	# Black pupils
	draw_circle(l_eye + look_dir * 1.1, 1.2, OL)
	draw_circle(r_eye + look_dir * 1.1, 1.2, OL)
	# White sparkle highlights
	draw_circle(l_eye + Vector2(-1.2, -1.5), 1.3, Color(1.0, 1.0, 1.0, 0.95))
	draw_circle(r_eye + Vector2(-1.2, -1.5), 1.3, Color(1.0, 1.0, 1.0, 0.95))
	draw_circle(l_eye + Vector2(1.0, 0.5), 0.6, Color(1.0, 1.0, 1.0, 0.6))
	draw_circle(r_eye + Vector2(1.0, 0.5), 0.6, Color(1.0, 1.0, 1.0, 0.6))

	# Mischievous eyebrows (one raised — bold strokes)
	draw_line(l_eye + Vector2(-3.5, -4.5), l_eye + Vector2(2.0, -5.0), OL, 2.5)
	draw_line(l_eye + Vector2(-3.0, -4.5), l_eye + Vector2(1.5, -5.0), hair_col, 1.5)
	draw_line(r_eye + Vector2(-2.0, -6.5), r_eye + Vector2(3.5, -4.5), OL, 2.5)
	draw_line(r_eye + Vector2(-1.5, -6.5), r_eye + Vector2(3.0, -4.5), hair_col, 1.5)

	# Small button nose
	draw_circle(head_center + Vector2(0, 3), 1.8, OL)
	draw_circle(head_center + Vector2(0, 3), 1.2, skin_highlight)

	# Big mischievous grin
	draw_arc(head_center + Vector2(0, 5), 5.5, 0.15, PI - 0.15, 12, OL, 2.5)
	draw_arc(head_center + Vector2(0, 5), 5.5, 0.15, PI - 0.15, 12, Color(0.70, 0.20, 0.15), 1.5)
	# Teeth showing in grin
	for ti in range(4):
		var tooth_x = -2.5 + float(ti) * 1.7
		draw_circle(head_center + Vector2(tooth_x, 5.8), 0.9, Color(0.98, 0.97, 0.92))
	# Smirk line (right side up)
	draw_line(head_center + Vector2(4.5, 4.5), head_center + Vector2(6.0, 3.5), OL, 1.5)

	# Cheek blush
	draw_circle(head_center + Vector2(-5.5, 3.5), 2.2, Color(0.95, 0.55, 0.50, 0.25))
	draw_circle(head_center + Vector2(5.5, 3.5), 2.2, Color(0.95, 0.55, 0.50, 0.25))

	# Freckles
	var frk = Color(0.60, 0.40, 0.25, 0.6)
	draw_circle(head_center + Vector2(-4.5, 2.5), 0.6, frk)
	draw_circle(head_center + Vector2(-3.5, 3.5), 0.5, frk)
	draw_circle(head_center + Vector2(-5.5, 3.0), 0.5, frk)
	draw_circle(head_center + Vector2(4.5, 2.5), 0.6, frk)
	draw_circle(head_center + Vector2(3.5, 3.5), 0.5, frk)
	draw_circle(head_center + Vector2(5.5, 3.0), 0.5, frk)

	# --- Pointed green hat with red feather ---
	var hat_base_pos = head_center + Vector2(0, -8)
	var hat_tip_pos = hat_base_pos + Vector2(12, -20)
	# Hat outline polygon
	var hat_ol_pts = PackedVector2Array([
		hat_base_pos + Vector2(-12, 3), hat_base_pos + Vector2(12, 3), hat_tip_pos,
	])
	draw_colored_polygon(hat_ol_pts, OL)
	# Hat fill
	var hat_fill_pts = PackedVector2Array([
		hat_base_pos + Vector2(-10, 2), hat_base_pos + Vector2(10, 2), hat_tip_pos + Vector2(-1, 1),
	])
	draw_colored_polygon(hat_fill_pts, green_mid)
	# Hat shadow panel
	var hat_shade = PackedVector2Array([
		hat_base_pos + Vector2(-8, 1), hat_base_pos + Vector2(3, 1), hat_tip_pos + Vector2(-2, 1),
	])
	draw_colored_polygon(hat_shade, green_dark)
	# Hat brim line (bold outline)
	draw_line(hat_base_pos + Vector2(-12, 3), hat_base_pos + Vector2(12, 3), OL, 3.5)
	draw_line(hat_base_pos + Vector2(-11, 3), hat_base_pos + Vector2(11, 3), green_dark, 2.0)
	# Leaf vein on hat
	draw_line(hat_base_pos + Vector2(1, 0), hat_tip_pos + Vector2(-1, 1), Color(0.12, 0.40, 0.08, 0.5), 0.8)

	# Red feather (bold Bloons style)
	var feather_base = hat_base_pos + Vector2(6, 0)
	var feather_tip = feather_base + Vector2(16, -12)
	# Feather outline
	draw_line(feather_base, feather_tip, OL, 4.5)
	# Feather fill (bright red)
	draw_line(feather_base, feather_tip, Color(0.92, 0.18, 0.10), 3.0)
	# Feather highlight
	draw_line(feather_base + (feather_tip - feather_base) * 0.3, feather_tip, Color(1.0, 0.30, 0.15), 2.0)
	# Feather barbs
	var f_d = (feather_tip - feather_base).normalized()
	var f_p = f_d.rotated(PI / 2.0)
	for fbi in range(5):
		var bt = 0.15 + float(fbi) * 0.16
		var barb_o = feather_base + (feather_tip - feather_base) * bt
		var blen = 3.0 - abs(float(fbi) - 2.0) * 0.5
		draw_line(barb_o, barb_o + f_p * blen, Color(0.85, 0.15, 0.08, 0.7), 1.0)
		draw_line(barb_o, barb_o - f_p * blen, Color(0.85, 0.15, 0.08, 0.7), 1.0)

	# === Tier 2+: Tinker Bell orbiting with sparkle trail ===
	if upgrade_tier >= 2:
		var tink_angle = _time * 1.8
		var tink_radius = 34.0
		var tink_bob_val = sin(_time * 4.0) * 3.0
		var tink_pos = body_offset + Vector2(cos(tink_angle) * tink_radius, sin(tink_angle) * tink_radius * 0.6 + tink_bob_val)
		# Sparkle trail
		for trail_i in range(4):
			var trail_a = tink_angle - float(trail_i + 1) * 0.3
			var trail_b = sin((_time - float(trail_i) * 0.15) * 4.0) * 3.0
			var trail_p = body_offset + Vector2(cos(trail_a) * tink_radius, sin(trail_a) * tink_radius * 0.6 + trail_b)
			var trail_alpha = 0.4 - float(trail_i) * 0.08
			var trail_size = 3.0 - float(trail_i) * 0.5
			draw_circle(trail_p, trail_size, Color(1.0, 0.92, 0.4, trail_alpha))
		# Glow
		draw_circle(tink_pos, 8.0, Color(1.0, 0.9, 0.3, 0.15))
		# Tinker Bell body (outline then fill)
		draw_circle(tink_pos, 4.0, OL)
		draw_circle(tink_pos, 2.8, Color(1.0, 0.95, 0.4))
		# Head
		var tink_head = tink_pos + Vector2.from_angle(tink_angle) * 3.0
		draw_circle(tink_head, 2.2, OL)
		draw_circle(tink_head, 1.5, Color(1.0, 1.0, 0.8))
		# Wings (flutter)
		var wing_flutter = sin(_time * 14.0) * 2.5
		var tink_perp_dir = Vector2.from_angle(tink_angle).rotated(PI / 2.0)
		draw_line(tink_pos + tink_perp_dir * 1.5, tink_pos + tink_perp_dir * (7.0 + wing_flutter) + Vector2(0, -1.5), Color(0.9, 0.95, 1.0, 0.5), 2.0)
		draw_line(tink_pos - tink_perp_dir * 1.5, tink_pos - tink_perp_dir * (7.0 - wing_flutter) + Vector2(0, -1.5), Color(0.9, 0.95, 1.0, 0.5), 2.0)

	# === Tier 2+: Fairy Dust aura (buff visual) ===
	if fairy_dust_active:
		var fd_pulse = sin(_time * 3.0) * 3.0
		draw_arc(body_offset, attack_range * 0.4 + fd_pulse, 0, TAU, 32, Color(0.6, 0.95, 0.3, 0.12), 1.5)
		# Floating sparkle dust particles
		for sp in range(5):
			var sp_a = _time * 0.6 + float(sp) * TAU / 5.0
			var sp_r = 20.0 + fd_pulse + float(sp % 3) * 5.0
			var sp_p = body_offset + Vector2.from_angle(sp_a) * sp_r
			var sp_alpha = 0.3 + sin(_time * 2.5 + float(sp)) * 0.15
			draw_circle(sp_p, 1.5, Color(0.4, 1.0, 0.5, sp_alpha))
			draw_circle(sp_p, 0.8, Color(0.8, 1.0, 0.6, sp_alpha * 1.5))

	# === Tier 4: Never Land golden glow ===
	if neverland_active:
		var aura_pulse = sin(_time * 2.5) * 4.0
		# Strong golden body glow
		draw_circle(body_offset, 20.0 + aura_pulse, Color(1.0, 0.85, 0.2, 0.15))
		draw_circle(body_offset, 35.0 + aura_pulse, Color(1.0, 0.85, 0.3, 0.06))
		draw_circle(body_offset, 48.0 + aura_pulse, Color(1.0, 0.85, 0.3, 0.03))
		draw_arc(body_offset, 44.0 + aura_pulse, 0, TAU, 32, Color(1.0, 0.85, 0.35, 0.25), 3.0)
		# Orbiting golden sparkles
		for gs in range(8):
			var gs_a = _time * (0.8 + float(gs % 3) * 0.3) + float(gs) * TAU / 8.0
			var gs_r = 30.0 + aura_pulse + float(gs % 3) * 4.0
			var gs_p = body_offset + Vector2.from_angle(gs_a) * gs_r
			var gs_size = 2.0 + sin(_time * 3.0 + float(gs) * 1.5) * 0.8
			draw_circle(gs_p, gs_size + 1.0, Color(1.0, 0.85, 0.2, 0.15))
			draw_circle(gs_p, gs_size, Color(1.0, 0.9, 0.4, 0.45))

	# === Awaiting ability choice indicator ===
	if awaiting_ability_choice:
		var pulse = (sin(_time * 4.0) + 1.0) * 0.5
		draw_circle(Vector2.ZERO, 60.0 + pulse * 6.0, Color(0.5, 1.0, 0.6, 0.1 + pulse * 0.1))
		draw_arc(Vector2.ZERO, 60.0 + pulse * 6.0, 0, TAU, 32, Color(0.5, 1.0, 0.6, 0.3 + pulse * 0.3), 2.5)
		var font3 = _game_font
		draw_string(font3, Vector2(-16, -68), "!", HORIZONTAL_ALIGNMENT_CENTER, 32, 30, Color(0.5, 1.0, 0.6, 0.7 + pulse * 0.3))

	# Damage dealt counter
	if damage_dealt > 0:
		var font = _game_font
		var dmg_text = str(int(damage_dealt)) + " DMG"
		if stat_upgrade_level > 0:
			dmg_text += " • Lv." + str(stat_upgrade_level)
		draw_string(font, Vector2(-36, 56), dmg_text, HORIZONTAL_ALIGNMENT_LEFT, 160, 12, Color(1.0, 0.84, 0.0, 0.5))

	# Upgrade name flash
	if _upgrade_flash > 0.0 and _upgrade_name != "":
		var font2 = _game_font
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
