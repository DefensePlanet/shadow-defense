extends Node2D
## Wicked Witch of the West — orbiting caster from Baum's Wizard of Oz (1900).
## Flies in circles on her broom, casting green spells in all directions.
## Tier 1 (5000 DMG): "Pack of Wolves" — periodic wolf projectile burst
## Tier 2 (10000 DMG): "Murder of Crows" — enemies hit take poison DoT
## Tier 3 (15000 DMG): "Swarm of Bees" — DoT spreads, increased damage
## Tier 4 (20000 DMG): "The Golden Cap" — Winged Monkey AoE burst every 20s

var damage: float = 21.0
var fire_rate: float = 1.5
var attack_range: float = 154.0
var fire_cooldown: float = 0.0
var aim_angle: float = 0.0
var target: Node2D = null
var gold_bonus: int = 2

# Damage tracking and upgrades
var damage_dealt: float = 0.0
var upgrade_tier: int = 0
var _upgrade_flash: float = 0.0
var _upgrade_name: String = ""

# Animation variables
var _time: float = 0.0
var _attack_anim: float = 0.0

# Orbiting caster — flies in a circle, casts green spells outward
var _home_position: Vector2 = Vector2.ZERO
var _orbit_angle: float = 0.0
var _orbit_radius: float = 60.0
var _orbit_speed: float = 1.8  # radians per second

# DoT applied by projectiles
var dot_dps: float = 0.0
var dot_duration: float = 0.0

# Tier 1: Pack of Wolves
var wolf_timer: float = 0.0
var wolf_cooldown: float = 10.0
var _wolf_flash: float = 0.0

# Tier 4: Golden Cap (Winged Monkeys)
var monkey_timer: float = 0.0
var monkey_cooldown: float = 20.0
var _monkey_flash: float = 0.0

# === PROGRESSIVE ABILITIES (9 tiers, unlocked via lifetime damage) ===
const PROG_ABILITY_NAMES = [
	"Witch's Cackle", "Winged Monkey Scout", "Poppy Field",
	"The Tornado", "Ruby Slippers", "Crystal Ball",
	"The Winkies' March", "Melting Curse", "Surrender Dorothy"
]
const PROG_ABILITY_DESCS = [
	"Bolts fly 25% faster, +15% damage",
	"Monkey marks 1 enemy every 8s for +25% damage taken 5s",
	"Every 20s, poppies put enemies to sleep 2s",
	"Every 15s, tornado pushes all enemies in range backwards",
	"Every 12s, hurl a 5x damage bolt at the furthest enemy",
	"Crystal ball: all enemies spawn with 15% less HP",
	"Every 18s, 4 Winkies march and strike enemies for 3x",
	"Every 20s, strongest enemy melts losing 20% HP over 3s",
	"Green skywriting deals 15 DPS to ALL enemies permanently"
]
var prog_abilities: Array = [false, false, false, false, false, false, false, false, false]
# Ability timers
var _monkey_scout_timer: float = 8.0
var _poppy_field_timer: float = 20.0
var _tornado_timer: float = 15.0
var _ruby_slippers_timer: float = 12.0
var _ruby_slipper_teleporting: bool = false
var _ruby_slipper_saved_pos: Vector2 = Vector2.ZERO
var _ruby_slipper_strike_timer: float = 0.0
var _winkies_march_timer: float = 18.0
var _melting_curse_timer: float = 20.0
# Visual flash timers
var _cackle_flash: float = 0.0
var _monkey_scout_flash: float = 0.0
var _poppy_flash: float = 0.0
var _tornado_flash: float = 0.0
var _ruby_flash: float = 0.0
var _winkies_flash: float = 0.0
var _melting_flash: float = 0.0
var _surrender_flash: float = 0.0

const STAT_UPGRADE_INTERVAL: float = 500.0
const ABILITY_THRESHOLD: float = 1500.0
var stat_upgrade_level: int = 0
var ability_chosen: bool = false
var awaiting_ability_choice: bool = false
const TIER_NAMES = [
	"Pack of Wolves",
	"Murder of Crows",
	"Swarm of Bees",
	"The Golden Cap"
]
const ABILITY_DESCRIPTIONS = [
	"Periodic wolf projectile burst",
	"Enemies hit take poison DoT",
	"DoT spreads, increased damage",
	"Winged Monkey AoE burst every 20s"
]
const TIER_COSTS = [90, 200, 350, 550]
var is_selected: bool = false
var base_cost: int = 0

var bolt_scene = preload("res://scenes/witch_bolt.tscn")

# Attack sounds — magical melody evolving with upgrade tier
var _attack_sounds: Array = []
var _attack_sounds_by_tier: Array = []
var _attack_player: AudioStreamPlayer

# Ability sounds
var _wolf_sound: AudioStreamWAV
var _wolf_player: AudioStreamPlayer
var _monkey_sound: AudioStreamWAV
var _monkey_player: AudioStreamPlayer
var _upgrade_sound: AudioStreamWAV
var _upgrade_player: AudioStreamPlayer
var _game_font: Font

func _ready() -> void:
	var _ff := FontFile.new()
	_ff.data = FileAccess.get_file_as_bytes("res://fonts/Cinzel.ttf")
	_game_font = _ff
	_home_position = global_position
	add_to_group("towers")
	_load_progressive_abilities()
	_generate_tier_sounds()
	_attack_sounds = _attack_sounds_by_tier[0]
	_attack_player = AudioStreamPlayer.new()
	_attack_player.stream = _attack_sounds[0]
	_attack_player.volume_db = -6.0
	add_child(_attack_player)

	# Wolf pack — rising wolf howl with vibrato
	var wf_rate := 22050
	var wf_dur := 0.55
	var wf_samples := PackedFloat32Array()
	wf_samples.resize(int(wf_rate * wf_dur))
	for i in wf_samples.size():
		var t := float(i) / wf_rate
		var freq := 250.0 + t * 500.0 + sin(TAU * 6.0 * t) * 30.0
		var att := minf(t * 10.0, 1.0)
		var dec := exp(-(t - 0.3) * 5.0) if t > 0.3 else 1.0
		var env := att * dec * 0.4
		wf_samples[i] = clampf((sin(TAU * freq * t) + sin(TAU * freq * 1.5 * t) * 0.3) * env, -1.0, 1.0)
	_wolf_sound = _samples_to_wav(wf_samples, wf_rate)
	_wolf_player = AudioStreamPlayer.new()
	_wolf_player.stream = _wolf_sound
	_wolf_player.volume_db = -6.0
	add_child(_wolf_player)

	# Winged monkeys — harsh ascending screech + wing flutter
	var mk_rate := 22050
	var mk_dur := 0.4
	var mk_samples := PackedFloat32Array()
	mk_samples.resize(int(mk_rate * mk_dur))
	for i in mk_samples.size():
		var t := float(i) / mk_rate
		var screech_freq := 800.0 + t * 1500.0
		var flutter := 0.5 + 0.5 * sin(TAU * 25.0 * t)
		var env := (1.0 - t / mk_dur) * 0.4
		var s := sin(TAU * screech_freq * t) * 0.5 + (randf() * 2.0 - 1.0) * 0.2
		mk_samples[i] = clampf(s * flutter * env, -1.0, 1.0)
	_monkey_sound = _samples_to_wav(mk_samples, mk_rate)
	_monkey_player = AudioStreamPlayer.new()
	_monkey_player.stream = _monkey_sound
	_monkey_player.volume_db = -6.0
	add_child(_monkey_player)

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
	_attack_anim = max(_attack_anim - delta * 3.0, 0.0)
	_upgrade_flash = max(_upgrade_flash - delta * 0.5, 0.0)
	_wolf_flash = max(_wolf_flash - delta * 2.0, 0.0)
	_monkey_flash = max(_monkey_flash - delta * 1.5, 0.0)

	# Orbit around home position on broom
	_orbit_angle += _orbit_speed * delta
	if _orbit_angle > TAU:
		_orbit_angle -= TAU
	global_position = _home_position + Vector2(cos(_orbit_angle), sin(_orbit_angle)) * _orbit_radius
	aim_angle = _orbit_angle + PI * 0.5  # Face forward along orbit

	# Cast green spells at enemies
	fire_cooldown -= delta
	target = _find_nearest_enemy()
	if target and fire_cooldown <= 0.0:
		_strike_target(target)
		fire_cooldown = 1.0 / (fire_rate * _speed_mult())

	# Tier 1+: Wolf pack burst (always checks from home position)
	if upgrade_tier >= 1:
		wolf_timer -= delta
		if wolf_timer <= 0.0 and _has_enemies_in_range():
			_wolf_pack()
			wolf_timer = wolf_cooldown

	# Tier 4: Golden Cap — Winged Monkeys
	if upgrade_tier >= 4:
		monkey_timer -= delta
		if monkey_timer <= 0.0 and _has_enemies_in_range():
			_winged_monkeys()
			monkey_timer = monkey_cooldown

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
	_fire_bolt(t)

func _fire_bolt(t: Node2D) -> void:
	var bolt = bolt_scene.instantiate()
	bolt.global_position = global_position + Vector2.from_angle(aim_angle) * 16.0
	var bolt_dmg = damage * _damage_mult()
	if prog_abilities[0]:  # Witch's Cackle: +15% damage, 25% faster bolts
		bolt_dmg *= 1.15
		_cackle_flash = 0.5
	bolt.damage = bolt_dmg
	bolt.target = t
	bolt.gold_bonus = int(gold_bonus * _gold_mult())
	bolt.source_tower = self
	bolt.dot_dps = dot_dps
	bolt.dot_duration = dot_duration
	if prog_abilities[0] and "speed" in bolt:
		bolt.speed *= 1.25
	get_tree().get_first_node_in_group("main").add_child(bolt)

func _wolf_pack() -> void:
	if _wolf_player and not _is_sfx_muted(): _wolf_player.play()
	_wolf_flash = 1.0
	var enemies = get_tree().get_nodes_in_group("enemies")
	var in_range: Array = []
	for enemy in enemies:
		if _home_position.distance_to(enemy.global_position) < attack_range:
			in_range.append(enemy)
	in_range.shuffle()
	var count = mini(3, in_range.size())
	for i in range(count):
		var bolt = bolt_scene.instantiate()
		bolt.global_position = _home_position + Vector2.from_angle(aim_angle + (float(i) - 1.0) * 0.5) * 16.0
		bolt.damage = damage * 0.8
		bolt.target = in_range[i]
		bolt.gold_bonus = gold_bonus
		bolt.source_tower = self
		bolt.is_wolf = true
		bolt.dot_dps = dot_dps
		bolt.dot_duration = dot_duration
		get_tree().get_first_node_in_group("main").add_child(bolt)

func _winged_monkeys() -> void:
	if _monkey_player and not _is_sfx_muted(): _monkey_player.play()
	_monkey_flash = 1.5
	# Massive AoE damage to all enemies in range
	var monkey_dmg = damage * 2.5
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if _home_position.distance_to(enemy.global_position) < attack_range:
			if enemy.has_method("take_damage"):
				var will_kill = enemy.health - monkey_dmg <= 0.0
				enemy.take_damage(monkey_dmg, true)
				register_damage(monkey_dmg)
				if will_kill:
					if gold_bonus > 0:
						var main = get_tree().get_first_node_in_group("main")
						if main:
							main.add_gold(gold_bonus)

func register_damage(amount: float) -> void:
	damage_dealt += amount
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("register_tower_damage"):
		main.register_tower_damage(main.TowerType.WICKED_WITCH, amount)

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
	attack_range += 5.6
	dot_dps += 1.0
	dot_duration += 0.2

func choose_ability(index: int) -> void:
	ability_chosen = true
	awaiting_ability_choice = false
	upgrade_tier = index + 1
	_apply_upgrade(upgrade_tier)
	_upgrade_flash = 3.0
	_upgrade_name = TIER_NAMES[index]

func _apply_upgrade(tier: int) -> void:
	match tier:
		1: # Pack of Wolves
			damage = 28.0
			fire_rate = 1.8
			attack_range = 165.0
			wolf_cooldown = 8.0
		2: # Murder of Crows — add DoT
			damage = 33.0
			dot_dps = 8.0
			dot_duration = 4.0
			fire_rate = 2.0
			attack_range = 175.0
			gold_bonus = 3
		3: # Swarm of Bees — stronger DoT
			damage = 40.0
			dot_dps = 15.0
			dot_duration = 5.0
			fire_rate = 2.2
			attack_range = 189.0
			wolf_cooldown = 6.0
			gold_bonus = 4
		4: # The Golden Cap — Winged Monkey AoE
			damage = 50.0
			fire_rate = 2.5
			attack_range = 210.0
			gold_bonus = 5
			wolf_cooldown = 5.0
			monkey_cooldown = 15.0
			dot_dps = 20.0
			dot_duration = 5.0

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
	return "Wicked Witch"

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
	# Classic horror/cartoon magic zap — clean, punchy, satisfying
	var zap_notes := [440.0, 523.25, 349.23, 466.16, 392.00, 523.25, 349.23, 440.0]  # A4, C5, F4, Bb4, G4, C5, F4, A4 (ominous but musical)
	var mix_rate := 44100
	_attack_sounds_by_tier = []

	# --- Tier 0: Hex Bolt (clean descending zap, sharp onset) ---
	var t0 := []
	for note_idx in zap_notes.size():
		var freq: float = zap_notes[note_idx]
		var dur := 0.18
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * dur))
		for i in samples.size():
			var t := float(i) / mix_rate
			# Fast exponential decay like Robin Hood
			var env := exp(-t * 22.0) * 0.4
			# Pitch glide: starts 80% higher, drops to target in ~25ms
			var glide := freq * (1.0 + 0.8 * exp(-t * 120.0))
			# Clean body with slight edge (3rd harmonic for character)
			var body := sin(TAU * glide * t)
			body += sin(TAU * glide * 3.0 * t) * 0.25 * exp(-t * 30.0)
			# Sharp percussive click on onset
			var click := (randf() * 2.0 - 1.0) * exp(-t * 800.0) * 0.2
			# Brief metallic ring
			var ring := sin(TAU * freq * 2.5 * t) * 0.1 * exp(-t * 35.0)
			samples[i] = clampf((body + ring) * env + click, -1.0, 1.0)
		t0.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t0)

	# --- Tier 1: Curse Shot (+ sub thump on onset, more bite) ---
	var t1 := []
	for note_idx in zap_notes.size():
		var freq: float = zap_notes[note_idx]
		var dur := 0.2
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * dur))
		for i in samples.size():
			var t := float(i) / mix_rate
			var env := exp(-t * 20.0) * 0.38
			# Pitch glide
			var glide := freq * (1.0 + 0.9 * exp(-t * 110.0))
			# Body with more harmonics
			var body := sin(TAU * glide * t)
			body += sin(TAU * glide * 3.0 * t) * 0.28 * exp(-t * 28.0)
			body += sin(TAU * glide * 5.0 * t) * 0.1 * exp(-t * 45.0)
			# Sub thump on impact
			var thump := sin(TAU * freq * 0.5 * t) * 0.2 * exp(-t * 50.0)
			# Sharp click
			var click := (randf() * 2.0 - 1.0) * exp(-t * 700.0) * 0.18
			# Metallic ring
			var ring := sin(TAU * freq * 2.5 * t) * 0.12 * exp(-t * 30.0)
			samples[i] = clampf((body + thump + ring) * env + click, -1.0, 1.0)
		t1.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t1)

	# --- Tier 2: Cauldron Blast (+ sizzle tail, richer harmonics) ---
	var t2 := []
	for note_idx in zap_notes.size():
		var freq: float = zap_notes[note_idx]
		var dur := 0.22
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * dur))
		for i in samples.size():
			var t := float(i) / mix_rate
			var env := exp(-t * 18.0) * 0.36
			# Steeper pitch glide for more dramatic sweep
			var glide := freq * (1.0 + 1.0 * exp(-t * 100.0))
			# Body — richer
			var body := sin(TAU * glide * t)
			body += sin(TAU * glide * 3.0 * t) * 0.3 * exp(-t * 26.0)
			body += sin(TAU * glide * 5.0 * t) * 0.12 * exp(-t * 40.0)
			# Sub thump
			var thump := sin(TAU * freq * 0.5 * t) * 0.22 * exp(-t * 45.0)
			# Sizzle tail (high-frequency filtered noise)
			var sizzle := (randf() * 2.0 - 1.0) * 0.08 * exp(-t * 25.0)
			sizzle *= sin(TAU * freq * 4.0 * t) * 0.5 + 0.5
			# Sharp click
			var click := (randf() * 2.0 - 1.0) * exp(-t * 700.0) * 0.18
			# Ring
			var ring := sin(TAU * freq * 2.5 * t) * 0.12 * exp(-t * 25.0)
			samples[i] = clampf((body + thump + ring) * env + sizzle + click, -1.0, 1.0)
		t2.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t2)

	# --- Tier 3: Banshee Bolt (+ horror minor-2nd interval sting) ---
	var t3 := []
	for note_idx in zap_notes.size():
		var freq: float = zap_notes[note_idx]
		var dur := 0.24
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * dur))
		for i in samples.size():
			var t := float(i) / mix_rate
			var env := exp(-t * 16.0) * 0.34
			# Pitch glide
			var glide := freq * (1.0 + 1.0 * exp(-t * 100.0))
			# Body
			var body := sin(TAU * glide * t)
			body += sin(TAU * glide * 3.0 * t) * 0.3 * exp(-t * 24.0)
			body += sin(TAU * glide * 5.0 * t) * 0.14 * exp(-t * 35.0)
			# Minor 2nd sting — half step above, quick decay (classic horror interval)
			var sting_freq := freq * 1.0595  # semitone up
			var sting := sin(TAU * sting_freq * t) * 0.2 * exp(-t * 28.0)
			# Sub thump
			var thump := sin(TAU * freq * 0.5 * t) * 0.22 * exp(-t * 42.0)
			# Sizzle
			var sizzle := (randf() * 2.0 - 1.0) * 0.07 * exp(-t * 22.0)
			sizzle *= sin(TAU * freq * 4.0 * t) * 0.5 + 0.5
			# Click
			var click := (randf() * 2.0 - 1.0) * exp(-t * 700.0) * 0.16
			# Ring
			var ring := sin(TAU * freq * 2.5 * t) * 0.1 * exp(-t * 22.0)
			samples[i] = clampf((body + sting + thump + ring) * env + sizzle + click, -1.0, 1.0)
		t3.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t3)

	# --- Tier 4: Dark Spell (full zap + shimmer tail, most powerful) ---
	var t4 := []
	for note_idx in zap_notes.size():
		var freq: float = zap_notes[note_idx]
		var dur := 0.26
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * dur))
		for i in samples.size():
			var t := float(i) / mix_rate
			var env := exp(-t * 15.0) * 0.32
			# Dramatic pitch glide
			var glide := freq * (1.0 + 1.2 * exp(-t * 95.0))
			# Rich body
			var body := sin(TAU * glide * t)
			body += sin(TAU * glide * 3.0 * t) * 0.32 * exp(-t * 22.0)
			body += sin(TAU * glide * 5.0 * t) * 0.15 * exp(-t * 32.0)
			body += sin(TAU * glide * 7.0 * t) * 0.06 * exp(-t * 45.0)
			# Horror sting (minor 2nd)
			var sting_freq := freq * 1.0595
			var sting := sin(TAU * sting_freq * t) * 0.18 * exp(-t * 25.0)
			# Sub thump
			var thump := sin(TAU * freq * 0.5 * t) * 0.24 * exp(-t * 40.0)
			# Shimmer tail (octave + fifth ring out)
			var shimmer := sin(TAU * freq * 3.0 * t) * 0.08 * exp(-t * 12.0)
			shimmer += sin(TAU * freq * 2.0 * t) * 0.06 * exp(-t * 10.0)
			# Sizzle
			var sizzle := (randf() * 2.0 - 1.0) * 0.06 * exp(-t * 20.0)
			sizzle *= sin(TAU * freq * 4.0 * t) * 0.5 + 0.5
			# Click
			var click := (randf() * 2.0 - 1.0) * exp(-t * 700.0) * 0.16
			samples[i] = clampf((body + sting + thump + shimmer) * env + sizzle + click, -1.0, 1.0)
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
	if main and main.survivor_progress.has(main.TowerType.WICKED_WITCH):
		var p = main.survivor_progress[main.TowerType.WICKED_WITCH]
		var unlocked = p.get("abilities_unlocked", [])
		for i in range(mini(9, unlocked.size())):
			if unlocked[i]:
				activate_progressive_ability(i)

func activate_progressive_ability(index: int) -> void:
	if index < 0 or index >= 9:
		return
	prog_abilities[index] = true

func get_progressive_ability_name(index: int) -> String:
	if index >= 0 and index < PROG_ABILITY_NAMES.size():
		return PROG_ABILITY_NAMES[index]
	return ""

func get_progressive_ability_desc(index: int) -> String:
	if index >= 0 and index < PROG_ABILITY_DESCS.size():
		return PROG_ABILITY_DESCS[index]
	return ""

func get_spawn_debuffs() -> Dictionary:
	if prog_abilities[5]:  # Crystal Ball
		return {"hp_reduction": 0.15}
	return {}

func _process_progressive_abilities(delta: float) -> void:
	# Visual flash decay
	_cackle_flash = max(_cackle_flash - delta * 2.0, 0.0)
	_monkey_scout_flash = max(_monkey_scout_flash - delta * 2.0, 0.0)
	_poppy_flash = max(_poppy_flash - delta * 1.5, 0.0)
	_tornado_flash = max(_tornado_flash - delta * 1.5, 0.0)
	_ruby_flash = max(_ruby_flash - delta * 2.0, 0.0)
	_winkies_flash = max(_winkies_flash - delta * 2.0, 0.0)
	_melting_flash = max(_melting_flash - delta * 1.5, 0.0)
	_surrender_flash = max(_surrender_flash - delta * 0.5, 0.0)

	# Ability 2: Winged Monkey Scout — mark 1 enemy every 8s
	if prog_abilities[1]:
		_monkey_scout_timer -= delta
		if _monkey_scout_timer <= 0.0 and _has_enemies_in_range():
			_monkey_scout_mark()
			_monkey_scout_timer = 8.0

	# Ability 3: Poppy Field — sleep enemies every 20s
	if prog_abilities[2]:
		_poppy_field_timer -= delta
		if _poppy_field_timer <= 0.0 and _has_enemies_in_range():
			_poppy_field_attack()
			_poppy_field_timer = 20.0

	# Ability 4: The Tornado — push enemies back every 15s
	if prog_abilities[3]:
		_tornado_timer -= delta
		if _tornado_timer <= 0.0 and _has_enemies_in_range():
			_tornado_attack()
			_tornado_timer = 15.0

	# Ability 5: Ruby Slippers — hurl 5x bolt at furthest enemy every 12s
	if prog_abilities[4]:
		_ruby_slippers_timer -= delta
		if _ruby_slippers_timer <= 0.0 and _has_enemies_in_range():
			_ruby_slippers_strike()
			_ruby_slippers_timer = 12.0

	# Ability 7: The Winkies' March — 4 soldiers every 18s
	if prog_abilities[6]:
		_winkies_march_timer -= delta
		if _winkies_march_timer <= 0.0 and _has_enemies_in_range():
			_winkies_march_attack()
			_winkies_march_timer = 18.0

	# Ability 8: Melting Curse — melt strongest enemy every 20s
	if prog_abilities[7]:
		_melting_curse_timer -= delta
		if _melting_curse_timer <= 0.0 and _has_enemies_in_range():
			_melting_curse_attack()
			_melting_curse_timer = 20.0

	# Ability 9: Surrender Dorothy — 15 DPS to ALL enemies every frame
	if prog_abilities[8]:
		var dps_amount = 15.0 * delta
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e) and e.has_method("take_damage"):
				e.take_damage(dps_amount, true)
				register_damage(dps_amount)

func _monkey_scout_mark() -> void:
	_monkey_scout_flash = 1.0
	# Find a random enemy in range and mark for +25% damage taken
	var enemies = get_tree().get_nodes_in_group("enemies")
	var in_range: Array = []
	for e in enemies:
		if _home_position.distance_to(e.global_position) < attack_range:
			in_range.append(e)
	if in_range.size() > 0:
		var target_e = in_range[randi() % in_range.size()]
		if is_instance_valid(target_e) and target_e.has_method("apply_cheshire_mark"):
			target_e.apply_cheshire_mark(5.0, 1.25)

func _poppy_field_attack() -> void:
	_poppy_flash = 1.5
	# Put enemies in range to sleep for 2s
	for e in get_tree().get_nodes_in_group("enemies"):
		if _home_position.distance_to(e.global_position) < attack_range:
			if is_instance_valid(e) and e.has_method("apply_sleep"):
				e.apply_sleep(2.0)

func _tornado_attack() -> void:
	_tornado_flash = 1.5
	# Push all enemies in range backwards using fear_reverse
	for e in get_tree().get_nodes_in_group("enemies"):
		if _home_position.distance_to(e.global_position) < attack_range:
			if is_instance_valid(e) and e.has_method("apply_fear_reverse"):
				e.apply_fear_reverse(2.0)

func _ruby_slippers_strike() -> void:
	_ruby_flash = 1.0
	# Find furthest enemy in range and hurl a 5x bolt
	var furthest: Node2D = null
	var furthest_dist: float = 0.0
	for e in get_tree().get_nodes_in_group("enemies"):
		var dist = _home_position.distance_to(e.global_position)
		if dist < attack_range and dist > furthest_dist:
			furthest_dist = dist
			furthest = e
	if furthest and is_instance_valid(furthest) and furthest.has_method("take_damage"):
		var bolt = bolt_scene.instantiate()
		bolt.global_position = global_position
		bolt.damage = damage * 5.0
		bolt.target = furthest
		bolt.gold_bonus = gold_bonus
		bolt.source_tower = self
		bolt.dot_dps = dot_dps
		bolt.dot_duration = dot_duration
		get_tree().get_first_node_in_group("main").add_child(bolt)

func _winkies_march_attack() -> void:
	_winkies_flash = 1.5
	# 4 Winkie soldiers each strike one enemy for 3x damage
	var enemies = get_tree().get_nodes_in_group("enemies")
	var in_range: Array = []
	for e in enemies:
		if _home_position.distance_to(e.global_position) < attack_range:
			in_range.append(e)
	in_range.shuffle()
	for i in range(mini(4, in_range.size())):
		if is_instance_valid(in_range[i]) and in_range[i].has_method("take_damage"):
			var dmg = damage * 3.0
			var will_kill = in_range[i].health - dmg <= 0.0
			in_range[i].take_damage(dmg, true)
			register_damage(dmg)
			if will_kill and gold_bonus > 0:
				var main = get_tree().get_first_node_in_group("main")
				if main:
					main.add_gold(gold_bonus)

func _melting_curse_attack() -> void:
	_melting_flash = 1.5
	# Find strongest enemy in range and apply melt
	var strongest: Node2D = null
	var most_hp: float = 0.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if _home_position.distance_to(e.global_position) < attack_range:
			if is_instance_valid(e) and e.health > most_hp:
				most_hp = e.health
				strongest = e
	if strongest and is_instance_valid(strongest) and strongest.has_method("apply_melt"):
		var melt_rate = strongest.health * 0.2 / 3.0
		strongest.apply_melt(melt_rate, 3.0)

func _draw() -> void:
	var orbit_center = _home_position - global_position

	# === 1. SELECTION RING (at home position) ===
	if is_selected:
		var pulse = (sin(_time * 3.0) + 1.0) * 0.5
		var ring_alpha = 0.5 + pulse * 0.3
		draw_arc(orbit_center, 40.0, 0, TAU, 48, Color(1.0, 0.84, 0.0, ring_alpha), 2.5)
		draw_arc(orbit_center, 43.0, 0, TAU, 48, Color(1.0, 0.84, 0.0, ring_alpha * 0.4), 1.5)

	# === 2. RANGE ARC (centered on home) ===
	draw_arc(orbit_center, attack_range, 0, TAU, 64, Color(1, 1, 1, 0.06), 1.0)
	# Orbit path — faint green circle showing flight path
	draw_arc(orbit_center, _orbit_radius, 0, TAU, 48, Color(0.3, 0.85, 0.2, 0.08), 1.0)

	# === 3. AIM DIRECTION ===
	var dir = Vector2.from_angle(aim_angle)
	var perp = dir.rotated(PI / 2.0)

	# === 4. IDLE ANIMATION (hip sway + robe billow) ===
	var bounce = abs(sin(_time * 3.0)) * 4.0
	var breathe = sin(_time * 2.0) * 2.0
	var sway = sin(_time * 1.5) * 1.5
	var hip_sway = sin(_time * 1.8) * 2.5
	var chest_breathe = sin(_time * 2.0) * 1.0
	var robe_billow = sin(_time * 1.3) * 2.0 + sin(_time * 2.1) * 1.0
	var bob = Vector2(sway, -bounce - breathe)
	var fly_offset = Vector2.ZERO
	if upgrade_tier >= 4:
		fly_offset = Vector2(0, -10.0 + sin(_time * 1.5) * 3.0)
	var body_offset = bob + fly_offset

	# Forward tilt while orbiting (always flying)
	body_offset += Vector2(dir.x * 4.0, -3.0 + dir.y * 2.0)

	# === 5. SKIN COLORS (GREEN for witch!) ===
	var skin_base = Color(0.38, 0.55, 0.28)
	var skin_shadow = Color(0.28, 0.42, 0.20)
	var skin_highlight = Color(0.48, 0.65, 0.35)


	# === 7. FLASH EFFECTS ===
	if _upgrade_flash > 0.0:
		draw_circle(Vector2.ZERO, 80.0 + _upgrade_flash * 24.0, Color(0.4, 0.9, 0.2, _upgrade_flash * 0.25))

	# Wolf flash (grey expanding ring)
	if _wolf_flash > 0.0:
		draw_circle(Vector2.ZERO, 64.0 + (1.0 - _wolf_flash) * 48.0, Color(0.5, 0.5, 0.5, _wolf_flash * 0.3))
		for i in range(3):
			var wr = 50.0 + (1.0 - _wolf_flash) * (30.0 + float(i) * 20.0)
			draw_arc(Vector2.ZERO, wr, 0, TAU, 32, Color(0.4, 0.4, 0.4, _wolf_flash * 0.15), 2.0)

	# Monkey flash (golden explosion)
	if _monkey_flash > 0.0:
		draw_circle(Vector2.ZERO, 72.0 + (1.0 - _monkey_flash) * 120.0, Color(0.9, 0.75, 0.2, _monkey_flash * 0.35))
		draw_circle(Vector2.ZERO, 40.0 * _monkey_flash, Color(1.0, 0.95, 0.5, _monkey_flash * 0.3))
		for i in range(8):
			var ma = TAU * float(i) / 8.0 + _monkey_flash * 3.0
			var mp = Vector2.from_angle(ma) * (72.0 + (1.0 - _monkey_flash) * 120.0)
			draw_circle(mp, 8.0, Color(0.6, 0.4, 0.15, _monkey_flash * 0.5))

	# Orbit trail effect — green sparkles behind her as she flies
	var trail_dir = Vector2.from_angle(_orbit_angle + PI)
	var trail_perp = trail_dir.rotated(PI / 2.0)
	for i in range(5):
		var trail_pos = trail_dir * (float(i + 1) * 8.0)
		var trail_alpha = 0.2 - float(i) * 0.035
		var trail_size = 6.0 - float(i) * 0.8
		draw_circle(trail_pos, trail_size, Color(0.3, 0.85, 0.2, trail_alpha))
		var wisp_off = trail_perp * sin(_time * 8.0 + float(i) * 0.9) * (2.0 + float(i))
		draw_circle(trail_pos + wisp_off, trail_size * 0.4, Color(0.4, 0.15, 0.5, trail_alpha * 0.5))

	# === PROGRESSIVE ABILITY VISUAL EFFECTS ===

	# Witch's Cackle flash (green streak)
	if _cackle_flash > 0.0:
		var cdir = Vector2.from_angle(aim_angle)
		draw_line(cdir * 10.0, cdir * 50.0, Color(0.3, 0.9, 0.1, _cackle_flash * 0.4), 3.0)
		draw_line(cdir * 15.0, cdir * 45.0, Color(0.5, 1.0, 0.3, _cackle_flash * 0.3), 1.5)

	# Winged Monkey Scout flash (swooping monkey silhouette)
	if _monkey_scout_flash > 0.0:
		var ms_angle = _time * 2.0
		var ms_r = 60.0 + (1.0 - _monkey_scout_flash) * 30.0
		var ms_pos = Vector2(cos(ms_angle) * ms_r, sin(ms_angle) * ms_r * 0.5 - 40.0)
		draw_circle(ms_pos, 6.0, Color(0.35, 0.25, 0.15, _monkey_scout_flash * 0.5))
		draw_circle(ms_pos + Vector2(0, -6), 4.0, Color(0.35, 0.25, 0.15, _monkey_scout_flash * 0.5))
		# Wings
		var msw = sin(_time * 8.0) * 4.0
		draw_line(ms_pos + Vector2(-4, -2), ms_pos + Vector2(-15, -8 + msw), Color(0.3, 0.2, 0.1, _monkey_scout_flash * 0.4), 2.0)
		draw_line(ms_pos + Vector2(4, -2), ms_pos + Vector2(15, -8 + msw), Color(0.3, 0.2, 0.1, _monkey_scout_flash * 0.4), 2.0)

	# Poppy Field flash (red flowers blooming)
	if _poppy_flash > 0.0:
		for pi in range(8):
			var pa = TAU * float(pi) / 8.0 + _poppy_flash * 0.5
			var pr = 30.0 + float(pi % 3) * 15.0
			var ppos = Vector2(cos(pa) * pr, sin(pa) * pr * 0.4 + 15.0)
			# Poppy flower
			draw_circle(ppos, 4.0 * _poppy_flash, Color(0.9, 0.15, 0.1, _poppy_flash * 0.5))
			draw_circle(ppos, 2.5 * _poppy_flash, Color(1.0, 0.3, 0.2, _poppy_flash * 0.4))
			draw_circle(ppos, 1.0, Color(0.1, 0.1, 0.0, _poppy_flash * 0.6))
			# Stem
			draw_line(ppos, ppos + Vector2(0, 5), Color(0.2, 0.5, 0.1, _poppy_flash * 0.3), 1.0)

	# Tornado flash (gray spinning funnel)
	if _tornado_flash > 0.0:
		var t_center = Vector2(0, 5)
		for ti in range(6):
			var ta = _time * 8.0 + float(ti) * TAU / 6.0
			var tr = 20.0 + (1.0 - _tornado_flash) * 40.0 + float(ti) * 3.0
			var tp = t_center + Vector2(cos(ta) * tr, sin(ta) * tr * 0.3)
			draw_circle(tp, 5.0 - float(ti) * 0.5, Color(0.5, 0.5, 0.55, _tornado_flash * 0.25))
		# Funnel shape
		draw_arc(t_center, 15.0 + (1.0 - _tornado_flash) * 25.0, 0, TAU, 24, Color(0.45, 0.45, 0.50, _tornado_flash * 0.3), 3.0)
		draw_arc(t_center, 25.0 + (1.0 - _tornado_flash) * 35.0, 0, TAU, 24, Color(0.4, 0.4, 0.45, _tornado_flash * 0.2), 2.0)

	# Ruby Slippers flash (ruby sparkle poof)
	if _ruby_flash > 0.0:
		for ri in range(10):
			var ra = TAU * float(ri) / 10.0 + _ruby_flash * 5.0
			var rr = 15.0 + (1.0 - _ruby_flash) * 30.0
			var rpos = Vector2(cos(ra) * rr, sin(ra) * rr)
			draw_circle(rpos, 3.0 * _ruby_flash, Color(0.9, 0.1, 0.15, _ruby_flash * 0.6))
			draw_circle(rpos, 1.5 * _ruby_flash, Color(1.0, 0.4, 0.4, _ruby_flash * 0.4))
		draw_circle(Vector2.ZERO, 20.0 * _ruby_flash, Color(0.8, 0.1, 0.1, _ruby_flash * 0.15))

	# Crystal Ball (floating above witch) — permanent visual when active
	if prog_abilities[5]:
		var cb_pos = Vector2(0, -65 + sin(_time * 1.5) * 3.0)
		var cb_glow = 0.3 + sin(_time * 2.5) * 0.1
		draw_circle(cb_pos, 10.0, Color(0.5, 0.3, 0.7, cb_glow))
		draw_circle(cb_pos, 8.0, Color(0.6, 0.4, 0.8, cb_glow + 0.1))
		draw_circle(cb_pos, 5.0, Color(0.7, 0.5, 0.9, cb_glow + 0.15))
		draw_circle(cb_pos + Vector2(-2, -2), 2.5, Color(0.9, 0.8, 1.0, 0.4))
		# Orbiting sparkles
		for ci in range(3):
			var ca = _time * 2.0 + float(ci) * TAU / 3.0
			var cpos = cb_pos + Vector2(cos(ca) * 12.0, sin(ca) * 12.0 * 0.5)
			draw_circle(cpos, 1.5, Color(0.7, 0.5, 0.9, 0.4 + sin(_time * 3.0 + float(ci)) * 0.2))

	# Winkies March flash (yellow armored figures)
	if _winkies_flash > 0.0:
		for wi in range(4):
			var wa = TAU * float(wi) / 4.0 + (1.0 - _winkies_flash) * 3.0
			var wr = 35.0 + (1.0 - _winkies_flash) * 25.0
			var wpos = Vector2(cos(wa) * wr, sin(wa) * wr * 0.4 + 10.0)
			# Winkie body (yellow)
			draw_circle(wpos, 5.0, Color(0.8, 0.7, 0.2, _winkies_flash * 0.5))
			draw_circle(wpos + Vector2(0, -5), 3.5, Color(0.7, 0.6, 0.15, _winkies_flash * 0.5))
			# Helmet
			draw_circle(wpos + Vector2(0, -8), 3.0, Color(0.5, 0.5, 0.5, _winkies_flash * 0.4))
			# Spear
			draw_line(wpos + Vector2(3, 3), wpos + Vector2(3, -12), Color(0.4, 0.35, 0.2, _winkies_flash * 0.4), 1.5)

	# Melting Curse flash (green dripping effect)
	if _melting_flash > 0.0:
		for mi in range(6):
			var mx = -20.0 + float(mi) * 8.0
			var drip_y = 10.0 + (1.0 - _melting_flash) * 30.0
			draw_line(Vector2(mx, -5), Vector2(mx + sin(_time * 3.0 + float(mi)) * 2.0, drip_y), Color(0.3, 0.8, 0.1, _melting_flash * 0.4), 2.0)
			draw_circle(Vector2(mx, drip_y), 3.0, Color(0.2, 0.7, 0.05, _melting_flash * 0.35))

	# Surrender Dorothy (green skywriting + particles) — permanent visual
	if prog_abilities[8]:
		_surrender_flash = 1.0  # Keep it active
		# Green smoke letters floating above
		var sky_y = -90.0 + sin(_time * 0.5) * 3.0
		var font_s = _game_font
		draw_string(font_s, Vector2(-50, sky_y), "SURRENDER", HORIZONTAL_ALIGNMENT_CENTER, 100, 11, Color(0.3, 0.8, 0.1, 0.4 + sin(_time * 1.5) * 0.15))
		# Green particles raining down
		for si in range(8):
			var sx = -40.0 + float(si) * 11.0
			var sy_offset = fmod(_time * 30.0 + float(si) * 17.0, 80.0)
			var sp = Vector2(sx + sin(_time + float(si)) * 5.0, sky_y + 10.0 + sy_offset)
			draw_circle(sp, 1.5, Color(0.3, 0.8, 0.1, 0.25 - sy_offset * 0.003))

	# === 8. STONE PLATFORM (always at local origin) ===
	var plat_y = 22.0
	draw_circle(Vector2(0, plat_y + 4), 28.0, Color(0, 0, 0, 0.15))
	draw_set_transform(Vector2(0, plat_y), 0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 28.0, Color(0.18, 0.16, 0.14))
	draw_circle(Vector2.ZERO, 25.0, Color(0.28, 0.25, 0.22))
	draw_circle(Vector2.ZERO, 20.0, Color(0.35, 0.32, 0.28))
	for si in range(8):
		var sa = TAU * float(si) / 8.0
		draw_circle(Vector2.from_angle(sa) * 16.0, 3.0, Color(0.25, 0.22, 0.20, 0.4))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	draw_set_transform(Vector2(0, plat_y - 2), 0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 22.0, Color(0.40, 0.36, 0.32, 0.3))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	# === 9. SHADOW TENDRILS (gothic detail) ===
	for ti in range(5):
		var ta = TAU * float(ti) / 5.0 + _time * 0.3
		var t_base = Vector2(cos(ta) * 24.0, plat_y + sin(ta) * 8.0)
		var t_end = t_base + Vector2(sin(_time * 0.8 + float(ti)) * 6.0, 8.0 + sin(_time * 1.2 + float(ti)) * 4.0)
		draw_line(t_base, t_end, Color(0.08, 0.04, 0.12, 0.15 + sin(_time + float(ti)) * 0.05), 1.5)

	# === 10. TIER PIPS on platform ===
	for i in range(upgrade_tier):
		var pip_angle = -PI / 2.0 + float(i) * (TAU / 4.0) - (float(upgrade_tier - 1) * TAU / 8.0)
		var pip_pos = Vector2(cos(pip_angle) * 22.0, plat_y + sin(pip_angle) * 8.0)
		var pip_col: Color
		match i:
			0: pip_col = Color(0.6, 0.6, 0.6)
			1: pip_col = Color(0.3, 0.3, 0.3)
			2: pip_col = Color(0.85, 0.7, 0.15)
			_: pip_col = Color(1.0, 0.85, 0.2)
		draw_circle(pip_pos, 5.0, pip_col)
		draw_circle(pip_pos + Vector2(-0.8, -0.8), 2.0, Color(min(pip_col.r + 0.2, 1.0), min(pip_col.g + 0.2, 1.0), min(pip_col.b + 0.2, 1.0), 0.5))

	# === T1+: WOLF SHADOW SILHOUETTES circling platform ===
	if upgrade_tier >= 1:
		for wi in range(2 + mini(upgrade_tier - 1, 1)):
			var wolf_orbit_angle = _time * (0.5 + float(wi) * 0.3) + float(wi) * PI
			var wolf_orbit_r = 36.0 + float(wi) * 10.0
			var wolf_base = Vector2(cos(wolf_orbit_angle) * wolf_orbit_r, sin(wolf_orbit_angle) * wolf_orbit_r * 0.4 + plat_y + 6.0)
			var wolf_dir = Vector2(-sin(wolf_orbit_angle), cos(wolf_orbit_angle) * 0.4).normalized()
			var wolf_perp_v = wolf_dir.rotated(PI / 2.0)
			var wc = Color(0.08, 0.08, 0.08, 0.3 - float(wi) * 0.06)
			# Wolf body
			draw_circle(wolf_base, 8.0, wc)
			draw_circle(wolf_base + wolf_dir * 8.0, 6.0, wc)
			# Wolf head
			var wolf_head = wolf_base + wolf_dir * 14.0
			draw_circle(wolf_head, 5.0, Color(wc.r, wc.g, wc.b, wc.a + 0.04))
			# Wolf ears
			var we1 = PackedVector2Array([wolf_head + wolf_perp_v * 2.5, wolf_head + wolf_dir * 3.5 + wolf_perp_v * 5.0, wolf_head + wolf_dir * 1.5])
			draw_colored_polygon(we1, wc)
			var we2 = PackedVector2Array([wolf_head - wolf_perp_v * 2.5, wolf_head + wolf_dir * 3.5 - wolf_perp_v * 5.0, wolf_head + wolf_dir * 1.5])
			draw_colored_polygon(we2, wc)
			# Wolf snout
			draw_line(wolf_head, wolf_head + wolf_dir * 7.0, Color(wc.r, wc.g, wc.b, wc.a - 0.05), 2.5)
			# Wolf tail
			var tail_sway = sin(_time * 3.0 + float(wi) * 2.0) * 3.5
			draw_line(wolf_base - wolf_dir * 6.0, wolf_base - wolf_dir * 14.0 + wolf_perp_v * tail_sway, wc, 2.0)
			# Wolf legs (running)
			var leg_phase = _time * 5.0 + float(wi) * PI
			for li in range(4):
				var leg_off = wolf_dir * (-3.0 + float(li) * 3.0)
				var leg_kick = sin(leg_phase + float(li) * PI * 0.5) * 3.0
				draw_line(wolf_base + leg_off, wolf_base + leg_off + Vector2(0, 8.0 + leg_kick), Color(wc.r, wc.g, wc.b, wc.a - 0.08), 1.5)
			# Glowing wolf eyes
			draw_circle(wolf_head + wolf_dir * 2.5 + wolf_perp_v * 1.5, 1.0, Color(0.6, 0.2, 0.0, 0.5))
			draw_circle(wolf_head + wolf_dir * 2.5 - wolf_perp_v * 1.5, 1.0, Color(0.6, 0.2, 0.0, 0.5))

	# === 11. CHARACTER POSITIONS (chibi proportions ~48px) ===
	var feet_y = body_offset + Vector2(hip_sway * 1.0, 10.0)
	var leg_top = body_offset + Vector2(hip_sway * 0.6, 0.0)
	var torso_center = body_offset + Vector2(hip_sway * 0.3, -8.0 - chest_breathe * 0.5)
	var neck_base = body_offset + Vector2(hip_sway * 0.15, -14.0 - chest_breathe * 0.3)
	var head_center = body_offset + Vector2(hip_sway * 0.08, -26.0)

	# Character shadow on platform
	draw_set_transform(Vector2(0, plat_y - 1), 0, Vector2(1.0, 0.3))
	draw_circle(Vector2(body_offset.x * 0.5, 0), 18.0, Color(0, 0, 0, 0.18))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	# === CARTOON BODY WITH BOLD OUTLINES (Bloons-style) ===
	var OL = Color(0.06, 0.05, 0.08)  # True black outline color

	# --- Feet (pointy witch boots — chibi style) ---
	var l_foot = feet_y + Vector2(-4, 0)
	var r_foot = feet_y + Vector2(4, 0)
	# Boot base outline + fill
	draw_circle(l_foot, 4.5, OL)
	draw_circle(r_foot, 4.5, OL)
	draw_circle(l_foot, 3.2, Color(0.10, 0.08, 0.12))
	draw_circle(r_foot, 3.2, Color(0.10, 0.08, 0.12))
	# Pointed toes curling up (witch boots)
	var l_toe_tip = l_foot + Vector2(-5, -4)
	var l_toe_pts = PackedVector2Array([l_foot + Vector2(-2, -1), l_foot + Vector2(-2, 2), l_toe_tip])
	draw_colored_polygon(l_toe_pts, OL)
	var l_toe_inner = PackedVector2Array([l_foot + Vector2(-1.5, -0.5), l_foot + Vector2(-1.5, 1.5), l_toe_tip + Vector2(0.5, 0.5)])
	draw_colored_polygon(l_toe_inner, Color(0.10, 0.08, 0.12))
	var r_toe_tip = r_foot + Vector2(5, -4)
	var r_toe_pts = PackedVector2Array([r_foot + Vector2(2, -1), r_foot + Vector2(2, 2), r_toe_tip])
	draw_colored_polygon(r_toe_pts, OL)
	var r_toe_inner = PackedVector2Array([r_foot + Vector2(1.5, -0.5), r_foot + Vector2(1.5, 1.5), r_toe_tip + Vector2(-0.5, 0.5)])
	draw_colored_polygon(r_toe_inner, Color(0.10, 0.08, 0.12))
	# Boot buckles (silver)
	draw_circle(l_foot + Vector2(0, -1), 1.8, OL)
	draw_circle(l_foot + Vector2(0, -1), 1.2, Color(0.70, 0.65, 0.60))
	draw_circle(r_foot + Vector2(0, -1), 1.8, OL)
	draw_circle(r_foot + Vector2(0, -1), 1.2, Color(0.70, 0.65, 0.60))
	# Boot highlight
	draw_circle(l_foot + Vector2(-0.5, -0.8), 1.0, Color(0.20, 0.18, 0.22, 0.4))
	draw_circle(r_foot + Vector2(-0.5, -0.8), 1.0, Color(0.20, 0.18, 0.22, 0.4))

	# --- Legs (short stubby, dark stockings) ---
	draw_line(l_foot + Vector2(0, -2), Vector2(l_foot.x, leg_top.y + 2), OL, 5.0)
	draw_line(l_foot + Vector2(0, -2), Vector2(l_foot.x, leg_top.y + 2), Color(0.10, 0.08, 0.12), 3.5)
	draw_line(r_foot + Vector2(0, -2), Vector2(r_foot.x, leg_top.y + 2), OL, 5.0)
	draw_line(r_foot + Vector2(0, -2), Vector2(r_foot.x, leg_top.y + 2), Color(0.10, 0.08, 0.12), 3.5)

	# --- Witch's dress (black with jagged hem, Bloons-style bold cartoon) ---
	var dress_black = Color(0.08, 0.06, 0.10)
	var dress_purple = Color(0.15, 0.08, 0.20)
	# Dress outline (bold black border around entire dress shape)
	var dress_outline = PackedVector2Array([
		feet_y + Vector2(-14, 3), feet_y + Vector2(14 + robe_billow * 0.5, 1),
		Vector2(8, torso_center.y - 1), Vector2(8, neck_base.y + 3),
		Vector2(4, neck_base.y + 2), Vector2(0, neck_base.y + 1),
		Vector2(-4, neck_base.y + 2), Vector2(-8, neck_base.y + 3),
		Vector2(-8, torso_center.y - 1),
	])
	draw_colored_polygon(dress_outline, OL)
	# Dress fill — dark black
	var dress_fill = PackedVector2Array([
		feet_y + Vector2(-12, 2), feet_y + Vector2(12 + robe_billow * 0.4, 0),
		Vector2(6.5, torso_center.y), Vector2(6.5, neck_base.y + 4.5),
		Vector2(3, neck_base.y + 3.5), Vector2(0, neck_base.y + 2.5),
		Vector2(-3, neck_base.y + 3.5), Vector2(-6.5, neck_base.y + 4.5),
		Vector2(-6.5, torso_center.y),
	])
	draw_colored_polygon(dress_fill, dress_black)
	# Purple sheen overlay on bodice area
	var bodice = PackedVector2Array([
		Vector2(-5.5, neck_base.y + 5), Vector2(5.5, neck_base.y + 5),
		Vector2(5.5, torso_center.y + 1), Vector2(-5.5, torso_center.y + 1),
	])
	draw_colored_polygon(bodice, dress_purple)
	# V-neck showing green skin
	var vneck_pts = PackedVector2Array([
		Vector2(-3.5, neck_base.y + 3.5), Vector2(0, neck_base.y + 2),
		Vector2(3.5, neck_base.y + 3.5), Vector2(0, torso_center.y - 1),
	])
	draw_colored_polygon(vneck_pts, skin_base)
	# V-neck green skin highlight
	draw_circle(Vector2(0, neck_base.y + 4), 1.5, skin_highlight)

	# Waist belt (brown corset belt)
	draw_line(Vector2(-7, torso_center.y + 0.5), Vector2(7, torso_center.y + 0.5), OL, 4.0)
	draw_line(Vector2(-6.5, torso_center.y + 0.5), Vector2(6.5, torso_center.y + 0.5), Color(0.45, 0.32, 0.15), 2.5)
	# Belt buckle (gold)
	draw_circle(Vector2(0, torso_center.y + 0.5), 2.5, OL)
	draw_circle(Vector2(0, torso_center.y + 0.5), 1.8, Color(0.65, 0.55, 0.18))
	draw_circle(Vector2(0, torso_center.y + 0.5), 0.8, Color(0.30, 0.25, 0.10))

	# Jagged hem (tattered witch-style ragged bottom edge)
	for i in range(8):
		var hx = -12.0 + float(i) * 3.2 + robe_billow * 0.1 * float(i) / 7.0
		var hy = feet_y.y + 1.5
		var jag_len = 4.0 + sin(float(i) * 1.7) * 2.0
		var jag_sway = sin(_time * 1.8 + float(i) * 0.9) * 1.5
		var jag_pts = PackedVector2Array([
			Vector2(hx - 2.0, hy), Vector2(hx + 2.0, hy),
			Vector2(hx + jag_sway, hy + jag_len),
		])
		draw_colored_polygon(jag_pts, OL)
		var jag_inner = PackedVector2Array([
			Vector2(hx - 1.2, hy), Vector2(hx + 1.2, hy),
			Vector2(hx + jag_sway, hy + jag_len - 1.0),
		])
		var jag_col = dress_black if i % 2 == 0 else dress_purple
		draw_colored_polygon(jag_inner, jag_col)

	# Star/moon embroidery on dress (subtle)
	var moon_pos = torso_center + Vector2(-4, 2)
	draw_arc(moon_pos, 1.8, PI * 0.3, PI * 1.7, 6, Color(0.30, 0.20, 0.45, 0.25), 0.8)
	var star_pos = torso_center + Vector2(4, 3)
	for si in range(4):
		var sa = float(si) * TAU / 4.0 + PI / 4.0
		draw_line(star_pos, star_pos + Vector2.from_angle(sa) * 1.5, Color(0.30, 0.20, 0.45, 0.25), 0.6)

	# === Shoulders (round cartoon joints with dark fabric) ===
	var l_shoulder = Vector2(-8, neck_base.y + 2)
	var r_shoulder = Vector2(8, neck_base.y + 2)
	# Shoulder joints with outline
	draw_circle(l_shoulder, 4.5, OL)
	draw_circle(r_shoulder, 4.5, OL)
	draw_circle(l_shoulder, 3.2, dress_black)
	draw_circle(r_shoulder, 3.2, dress_black)
	# Pointed shoulder tips (witch style)
	var l_sp_tip = PackedVector2Array([l_shoulder + Vector2(-1, -1), l_shoulder + Vector2(-6, -3), l_shoulder + Vector2(-1, 1)])
	draw_colored_polygon(l_sp_tip, OL)
	var l_sp_inner = PackedVector2Array([l_shoulder + Vector2(-1.5, -0.5), l_shoulder + Vector2(-5, -2.5), l_shoulder + Vector2(-1.5, 0.5)])
	draw_colored_polygon(l_sp_inner, dress_black)
	var r_sp_tip = PackedVector2Array([r_shoulder + Vector2(1, -1), r_shoulder + Vector2(6, -3), r_shoulder + Vector2(1, 1)])
	draw_colored_polygon(r_sp_tip, OL)
	var r_sp_inner = PackedVector2Array([r_shoulder + Vector2(1.5, -0.5), r_shoulder + Vector2(5, -2.5), r_shoulder + Vector2(1.5, 0.5)])
	draw_colored_polygon(r_sp_inner, dress_black)

	# === Arms (chunky cartoon limbs with green skin + proper attack animation) ===
	var arm_extend = _attack_anim * 8.0

	# === LEFT ARM (holds broomstick) — thick Bloons tube arm ===
	var broom_tilt = 0.3
	var broom_target = l_shoulder + Vector2(-5, 6) + dir * 6.0
	var l_elbow = l_shoulder + (broom_target - l_shoulder) * 0.45 + Vector2(0, 3)
	var l_hand = broom_target
	# Upper arm outline + fill
	draw_line(l_shoulder, l_elbow, OL, 7.0)
	draw_line(l_shoulder, l_elbow, skin_base, 5.0)
	# Forearm outline + fill
	draw_line(l_elbow, l_hand, OL, 6.5)
	draw_line(l_elbow, l_hand, skin_base, 4.5)
	# Elbow joint
	draw_circle(l_elbow, 3.5, OL)
	draw_circle(l_elbow, 2.5, skin_base)
	# Hand (round cartoon hand — green skin)
	draw_circle(l_hand, 4.0, OL)
	draw_circle(l_hand, 3.0, skin_base)
	draw_circle(l_hand + Vector2(-0.5, -0.5), 1.0, skin_highlight)

	# === BROOMSTICK (held by left hand) ===
	var broom_angle = aim_angle + broom_tilt
	var broom_dir = Vector2.from_angle(broom_angle)
	var broom_perp_n = broom_dir.rotated(PI / 2.0)
	var broom_base = l_hand - broom_dir * 18.0
	var broom_tip = l_hand + broom_dir * 24.0
	# Handle outline + wood
	draw_line(broom_base, broom_tip, OL, 5.5)
	draw_line(broom_base, broom_tip, Color(0.45, 0.30, 0.15), 3.5)
	# Lighter inner
	draw_line(broom_base.lerp(broom_tip, 0.1), broom_base.lerp(broom_tip, 0.85), Color(0.52, 0.36, 0.20), 2.0)
	# Wood grain
	for gi in range(4):
		var gt = 0.2 + float(gi) * 0.18
		var g_start = broom_base.lerp(broom_tip, gt) + broom_perp_n * 1.0
		var g_end = broom_base.lerp(broom_tip, gt + 0.06) + broom_perp_n * 0.3
		draw_line(g_start, g_end, Color(0.35, 0.22, 0.10, 0.4), 0.8)
	# Knot in wood
	draw_circle(broom_base.lerp(broom_tip, 0.5), 1.8, Color(0.30, 0.18, 0.08, 0.5))

	# Binding where bristles meet handle
	for bi in range(3):
		var bnd_off = float(bi) * 2.5
		var bnd_p = broom_base + broom_dir * bnd_off
		draw_line(bnd_p + broom_perp_n * 3.5, bnd_p - broom_perp_n * 3.5, OL, 2.5)
		draw_line(bnd_p + broom_perp_n * 2.5, bnd_p - broom_perp_n * 2.5, Color(0.55, 0.40, 0.20), 1.5)

	# Bristles (straw at back end)
	var bristle_sway_val = sin(_time * 3.0) * 2.0
	for bi in range(8):
		var b_off = (float(bi) - 3.5) * 2.0
		var b_sway = broom_perp_n * (bristle_sway_val + sin(_time * 3.0 + float(bi) * 0.7) * 1.5)
		var b_len = 12.0 + sin(float(bi) * 1.7) * 3.0
		var b_end = broom_base - broom_dir * b_len + broom_perp_n * b_off + b_sway
		draw_line(broom_base, b_end, OL, 2.5)
		draw_line(broom_base, b_end, Color(0.55, 0.40, 0.20), 1.5)

	# Broom magic glow (always flying)
	draw_circle(broom_base, 5.0, Color(0.2, 0.6, 0.1, 0.12))
	draw_circle(broom_tip, 4.0, Color(0.2, 0.6, 0.1, 0.08))

	# === RIGHT ARM (pointing/attacking arm) — extends toward target on attack ===
	var r_elbow = r_shoulder + Vector2(3, 4) + dir * 3.0
	var r_hand = r_shoulder + dir * (14.0 + arm_extend)
	# Upper arm outline + fill
	draw_line(r_shoulder, r_elbow, OL, 7.0)
	draw_line(r_shoulder, r_elbow, skin_base, 5.0)
	# Forearm outline + fill
	draw_line(r_elbow, r_hand, OL, 6.5)
	draw_line(r_elbow, r_hand, skin_base, 4.5)
	# Elbow joint
	draw_circle(r_elbow, 3.5, OL)
	draw_circle(r_elbow, 2.5, skin_base)
	# Hand (round cartoon hand — green skin)
	draw_circle(r_hand, 4.0, OL)
	draw_circle(r_hand, 3.0, skin_base)
	draw_circle(r_hand + Vector2(-0.5, -0.5), 1.0, skin_highlight)

	# Gnarled claw fingers on pointing hand (4 stubby fingers + claw nails)
	for fi in range(4):
		var f_spread = (float(fi) - 1.5) * 0.2
		var f_dir = dir.rotated(f_spread)
		var f_len = 4.5 + float(fi % 2) * 1.0
		var f_tip = r_hand + f_dir * f_len + perp * (float(fi) - 1.5) * 1.5
		draw_line(r_hand, f_tip, OL, 2.2)
		draw_line(r_hand, f_tip, skin_shadow, 1.5)
		# Claw nail
		var nail_tip = f_tip + f_dir * 2.5
		draw_line(f_tip, nail_tip, OL, 1.8)
		draw_line(f_tip, nail_tip, Color(0.15, 0.12, 0.05), 1.0)
	# Thumb
	var thumb_tip = r_hand + dir.rotated(-0.5) * 3.5
	draw_line(r_hand, thumb_tip, OL, 2.0)
	draw_line(r_hand, thumb_tip, skin_shadow, 1.3)

	# Attack green glow from pointing hand
	if _attack_anim > 0.0:
		draw_circle(r_hand, 7.0 + _attack_anim * 5.0, Color(0.3, 0.8, 0.15, _attack_anim * 0.2))
		draw_circle(r_hand, 4.0 + _attack_anim * 2.5, Color(0.4, 0.9, 0.2, _attack_anim * 0.3))
		# Green bolt streaks
		for si in range(3):
			var s_angle = aim_angle + (float(si) - 1.0) * 0.3
			var s_dir = Vector2.from_angle(s_angle)
			draw_line(r_hand + s_dir * 5.0, r_hand + s_dir * (15.0 + _attack_anim * 10.0), Color(0.3, 0.9, 0.1, _attack_anim * 0.3), 2.0)

	# === T2+: CROW perched on shoulder ===
	if upgrade_tier >= 2:
		var crow_base = r_shoulder + Vector2(3, -6)
		var crow_head_pos = crow_base + Vector2(3, -4)
		# Crow body outline + fill
		draw_circle(crow_base, 4.5, OL)
		draw_circle(crow_base, 3.2, Color(0.08, 0.08, 0.12))
		# Crow head outline + fill
		draw_circle(crow_head_pos, 3.0, OL)
		draw_circle(crow_head_pos, 2.2, Color(0.08, 0.08, 0.12))
		# Beak
		var beak_tip_pos = crow_head_pos + Vector2(4, 0.5)
		var beak_pts_top = PackedVector2Array([crow_head_pos + Vector2(1.5, -1), beak_tip_pos, crow_head_pos + Vector2(1.5, 0.5)])
		draw_colored_polygon(beak_pts_top, Color(0.15, 0.12, 0.05))
		# Wing (folded)
		var wing_bob = sin(_time * 4.0) * 1.5
		var cwl_pts = PackedVector2Array([crow_base + Vector2(-1, -1), crow_base + Vector2(-5, -4 + wing_bob), crow_base + Vector2(-3, -1.5 + wing_bob * 0.5), crow_base + Vector2(-1, 2)])
		draw_colored_polygon(cwl_pts, OL)
		# Beady eye (Bloons style)
		draw_circle(crow_head_pos + Vector2(1.2, -0.8), 1.5, OL)
		draw_circle(crow_head_pos + Vector2(1.2, -0.8), 1.0, Color(0.95, 0.30, 0.05))
		draw_circle(crow_head_pos + Vector2(1.5, -1.0), 0.4, Color(1.0, 1.0, 0.9, 0.7))
		# Tail feathers
		for tfi in range(2):
			var tf_end = crow_base + Vector2(-5 - float(tfi), 1 + float(tfi) * 0.5)
			draw_line(crow_base + Vector2(-1.5, 0), tf_end, OL, 1.8)

	# === NECK (cartoon connector — green skin) ===
	var neck_top = head_center + Vector2(0, 9)
	draw_line(neck_base, neck_top, OL, 7.0)
	draw_line(neck_base, neck_top, skin_base, 5.0)

	# === HEAD — Big round cartoon head with GREEN SKIN ===
	var hair_wave = sin(_time * 1.5) * 2.0
	var hair_col = Color(0.08, 0.08, 0.06)

	# --- Hair back (stringy dark hair behind face) ---
	# Back hair strands (drawn behind head)
	for hi in range(6):
		var hair_angle_l = PI * 0.3 + float(hi) * PI * 0.06
		var hair_base_pos = head_center + Vector2.from_angle(hair_angle_l) * 10.0
		var hair_sway_val = sin(_time * 1.5 + float(hi) * 0.8) * 1.5
		var hair_len = 18.0 + sin(float(hi) * 1.3) * 4.0
		var hair_mid = hair_base_pos + Vector2(hair_sway_val, hair_len * 0.5)
		var hair_tip_pt = hair_base_pos + Vector2(hair_sway_val * 1.2, hair_len)
		draw_line(hair_base_pos, hair_mid, OL, 3.0)
		draw_line(hair_base_pos, hair_mid, hair_col, 2.0)
		draw_line(hair_mid, hair_tip_pt, OL, 2.5)
		draw_line(hair_mid, hair_tip_pt, hair_col, 1.5)
	for hi in range(5):
		var hair_angle_r = -PI * 0.32 - float(hi) * PI * 0.055
		var hb2 = head_center + Vector2.from_angle(hair_angle_r) * 10.0
		var hsway2 = sin(_time * 1.5 + float(hi) * 1.1 + PI) * 1.5
		var hlen2 = 16.0 + sin(float(hi) * 1.7) * 4.0
		var hmid2 = hb2 + Vector2(hsway2, hlen2 * 0.5)
		var htip2 = hb2 + Vector2(hsway2 * 1.2, hlen2)
		draw_line(hb2, hmid2, OL, 3.0)
		draw_line(hb2, hmid2, hair_col, 2.0)
		draw_line(hmid2, htip2, OL, 2.5)
		draw_line(hmid2, htip2, hair_col, 1.5)

	# --- Main head shape (big circle — green skin) ---
	# Hair volume behind face
	draw_circle(head_center, 14.0, OL)
	draw_circle(head_center, 12.5, hair_col)
	# Side hair volume
	draw_circle(head_center + Vector2(-12, 3), 5.5, OL)
	draw_circle(head_center + Vector2(-12, 3), 4.2, hair_col)
	draw_circle(head_center + Vector2(12, 3), 5.5, OL)
	draw_circle(head_center + Vector2(12, 3), 4.2, hair_col)

	# --- Face (big round cartoon green face) ---
	draw_circle(head_center + Vector2(0, 1.5), 12.0, OL)
	draw_circle(head_center + Vector2(0, 1.5), 10.8, skin_base)
	# Face highlight (top-left shine like Bloons)
	draw_circle(head_center + Vector2(-3, -2), 5.0, Color(skin_highlight.r, skin_highlight.g, skin_highlight.b, 0.25))

	# --- Pointed chin (witch feature) ---
	var chin_tip = head_center + Vector2(0, 11.0)
	var chin_pts = PackedVector2Array([head_center + Vector2(-5, 6), chin_tip, head_center + Vector2(5, 6)])
	draw_colored_polygon(chin_pts, OL)
	var chin_inner = PackedVector2Array([head_center + Vector2(-4, 6.5), chin_tip + Vector2(0, -0.8), head_center + Vector2(4, 6.5)])
	draw_colored_polygon(chin_inner, skin_base)
	# Chin highlight
	draw_circle(chin_tip + Vector2(0, -2), 1.0, skin_highlight)

	# --- Hooked nose (witch feature — bold outlined) ---
	var nose_bridge = head_center + Vector2(0, 0)
	var nose_tip = head_center + Vector2(1.5, 4.5)
	# Nose outline
	draw_line(nose_bridge, nose_tip, OL, 3.0)
	draw_line(nose_bridge, nose_tip, skin_base, 2.0)
	# Hooked nose bump
	draw_circle(nose_tip, 2.5, OL)
	draw_circle(nose_tip, 1.8, skin_base)
	draw_circle(nose_tip + Vector2(-0.3, -0.3), 0.8, skin_highlight)
	# Nostrils
	draw_circle(nose_tip + Vector2(-1.0, 0.8), 0.8, skin_shadow)
	draw_circle(nose_tip + Vector2(1.5, 0.5), 0.8, skin_shadow)

	# --- Wart on nose (classic witch detail) ---
	var wart_pos = nose_tip + Vector2(-1.5, -1.0)
	draw_circle(wart_pos, 1.5, OL)
	draw_circle(wart_pos, 1.0, Color(0.32, 0.48, 0.22))
	draw_circle(wart_pos + Vector2(-0.2, -0.2), 0.4, skin_highlight)

	# --- Sunken cheek hollows ---
	draw_circle(head_center + Vector2(-5, 3), 2.5, Color(0.25, 0.38, 0.15, 0.25))
	draw_circle(head_center + Vector2(5, 3), 2.5, Color(0.25, 0.38, 0.15, 0.25))

	# === BIG CARTOON EYES (Bloons-style — sinister witch eyes with yellow-green irises) ===
	var look_dir = dir * 1.2
	var l_eye = head_center + Vector2(-4.5, -0.5)
	var r_eye = head_center + Vector2(4.5, -0.5)
	# Eye outlines (thick black border)
	draw_circle(l_eye, 5.8, OL)
	draw_circle(r_eye, 5.8, OL)
	# Eye whites (slightly yellowish tint for witchy look)
	draw_circle(l_eye, 4.8, Color(0.95, 0.92, 0.40))
	draw_circle(r_eye, 4.8, Color(0.95, 0.92, 0.40))
	# Green-gold irises (witch's sinister eyes)
	var iris_col = Color(0.35, 0.65, 0.10)
	draw_circle(l_eye + look_dir, 3.5, Color(0.20, 0.45, 0.05))
	draw_circle(l_eye + look_dir, 2.8, iris_col)
	draw_circle(r_eye + look_dir, 3.5, Color(0.20, 0.45, 0.05))
	draw_circle(r_eye + look_dir, 2.8, iris_col)
	# Slit pupils (vertical, cat-like — classic witch)
	var pupil_w = 1.4 + _attack_anim * 0.5
	draw_line(l_eye + look_dir + Vector2(0, -2.0), l_eye + look_dir + Vector2(0, 2.0), Color(0.02, 0.02, 0.05), pupil_w)
	draw_line(r_eye + look_dir + Vector2(0, -2.0), r_eye + look_dir + Vector2(0, 2.0), Color(0.02, 0.02, 0.05), pupil_w)
	# Eerie green glow around pupils
	draw_circle(l_eye + look_dir, 1.0, Color(0.30, 0.80, 0.10, 0.3))
	draw_circle(r_eye + look_dir, 1.0, Color(0.30, 0.80, 0.10, 0.3))
	# Big sparkle highlights (key Bloons detail)
	draw_circle(l_eye + Vector2(-1.3, -1.6), 1.8, Color(1.0, 1.0, 1.0, 0.90))
	draw_circle(r_eye + Vector2(-1.3, -1.6), 1.8, Color(1.0, 1.0, 1.0, 0.90))
	# Small secondary sparkle
	draw_circle(l_eye + Vector2(1.2, 1.0), 0.9, Color(1.0, 1.0, 1.0, 0.50))
	draw_circle(r_eye + Vector2(1.2, 1.0), 0.9, Color(1.0, 1.0, 1.0, 0.50))
	# Bold upper eyelid line
	draw_arc(l_eye, 5.2, PI + 0.15, TAU - 0.15, 10, OL, 1.8)
	draw_arc(r_eye, 5.2, PI + 0.15, TAU - 0.15, 10, OL, 1.8)
	# Eyelashes (3 bold lashes per eye — dramatic witch lashes)
	for el in range(3):
		var ela = PI + 0.2 + float(el) * 0.5
		draw_line(l_eye + Vector2.from_angle(ela) * 5.2, l_eye + Vector2.from_angle(ela + 0.15) * 8.5, OL, 1.8)
		draw_line(r_eye + Vector2.from_angle(ela) * 5.2, r_eye + Vector2.from_angle(ela + 0.15) * 8.5, OL, 1.8)
	# Eye glow (eerie green)
	var eye_glow_pulse = 0.12 + sin(_time * 2.5) * 0.05
	draw_circle(l_eye, 6.5, Color(0.20, 0.60, 0.10, eye_glow_pulse))
	draw_circle(r_eye, 6.5, Color(0.20, 0.60, 0.10, eye_glow_pulse))

	# Sinister arched eyebrows (high dramatic arches)
	draw_line(l_eye + Vector2(-4, -5), l_eye + Vector2(1, -7), OL, 2.5)
	draw_line(l_eye + Vector2(1, -7), l_eye + Vector2(4, -4.5), OL, 1.5)
	draw_line(r_eye + Vector2(-4, -4.5), r_eye + Vector2(-1, -7), OL, 1.5)
	draw_line(r_eye + Vector2(-1, -7), r_eye + Vector2(4, -5), OL, 2.5)

	# === CACKLING MOUTH (open grin showing teeth — sinister smile) ===
	var mouth_center = head_center + Vector2(0, 7.5)
	# Mouth outline (big open grin)
	draw_arc(mouth_center, 5.5, 0.15, PI - 0.15, 12, OL, 2.5)
	# Mouth interior (dark)
	draw_arc(mouth_center, 4.5, 0.2, PI - 0.2, 12, Color(0.15, 0.05, 0.08), 3.5)
	# Teeth (upper row — jagged)
	for ti in range(5):
		var tx = -3.5 + float(ti) * 1.8
		var tooth_top = mouth_center + Vector2(tx, -0.5)
		var tooth_bot = mouth_center + Vector2(tx, 1.2)
		draw_line(tooth_top, tooth_bot, Color(0.92, 0.88, 0.75), 1.3)
	# Dark lip color (corners curled up sinisterly)
	draw_line(mouth_center + Vector2(-5.0, 0.5), mouth_center + Vector2(-6.5, -1.5), OL, 1.5)
	draw_line(mouth_center + Vector2(5.0, 0.5), mouth_center + Vector2(6.5, -1.5), OL, 1.5)

	# --- Wispy forehead hair strands across face ---
	for wi in range(3):
		var w_x = -3.0 + float(wi) * 2.5
		var w_base = head_center + Vector2(w_x, -8)
		var w_sway = sin(_time * 1.8 + float(wi) * 1.5) * 1.0
		var w_tip = w_base + Vector2(w_sway, 7.0 + float(wi) * 0.8)
		draw_line(w_base, w_tip, Color(hair_col.r, hair_col.g, hair_col.b, 0.55), 1.2)

	# === TALL POINTED BLACK HAT (Bloons-style with bold outlines) ===
	var hat_base_pos = head_center + Vector2(0, -8)
	var hat_tip_pos = hat_base_pos + Vector2(3, -38)
	# Hat wobble when flying
	hat_tip_pos += Vector2(sin(_time * 3.5) * 2.0, 0)

	# Hat brim (wide, bold outline)
	var brim_l = hat_base_pos + Vector2(-16, 0)
	var brim_r = hat_base_pos + Vector2(16, 0)
	# Brim outline
	draw_line(brim_l + Vector2(0, 2), brim_r + Vector2(0, 2), OL, 6.0)
	draw_line(brim_l, brim_r, OL, 5.0)
	# Brim fill
	draw_line(brim_l + Vector2(1, 0.5), brim_r - Vector2(1, -0.5), Color(0.08, 0.06, 0.10), 3.5)
	# Brim highlight
	draw_line(brim_l + Vector2(2, -0.5), brim_r - Vector2(2, 0.5), Color(0.14, 0.12, 0.16, 0.35), 1.2)

	# Hat cone (outline then fill)
	var hat_pts_out = PackedVector2Array([brim_l + Vector2(5, 0), brim_r - Vector2(5, 0), hat_tip_pos])
	draw_colored_polygon(hat_pts_out, OL)
	var hat_pts = PackedVector2Array([brim_l + Vector2(6.5, -1), brim_r - Vector2(6.5, -1), hat_tip_pos + Vector2(0, 1)])
	draw_colored_polygon(hat_pts, Color(0.08, 0.06, 0.10))

	# Hat bend/droop near tip (classic floppy witch hat top)
	var hat_mid = hat_base_pos + Vector2(0, -8)
	var hat_bend = hat_mid + (hat_tip_pos - hat_mid) * 0.6 + Vector2(5, 0)
	var hat_bent_pts = PackedVector2Array([hat_mid + Vector2(3, 0), hat_bend, hat_tip_pos])
	draw_colored_polygon(hat_bent_pts, Color(0.10, 0.08, 0.12))

	# Hat wrinkle details
	var w1_s = hat_base_pos.lerp(hat_tip_pos, 0.2) + Vector2(2, 0)
	var w1_e = hat_base_pos.lerp(hat_tip_pos, 0.38) - Vector2(2, 0)
	draw_line(w1_s, w1_e, Color(0.14, 0.10, 0.16, 0.4), 1.0)

	# Hat band with buckle
	draw_line(hat_base_pos + Vector2(-12, -2), hat_base_pos + Vector2(12, -2), OL, 4.5)
	draw_line(hat_base_pos + Vector2(-11, -2), hat_base_pos + Vector2(11, -2), Color(0.30, 0.25, 0.10), 3.0)
	# Buckle on hat band (gold)
	var buckle_c = hat_base_pos + Vector2(0, -2)
	draw_rect(Rect2(buckle_c.x - 3.5, buckle_c.y - 3, 7, 6), OL)
	draw_rect(Rect2(buckle_c.x - 2.5, buckle_c.y - 2, 5, 4), Color(0.65, 0.55, 0.18))
	draw_rect(Rect2(buckle_c.x - 1.5, buckle_c.y - 1, 3, 2), Color(0.30, 0.25, 0.10))
	# Buckle prong
	draw_line(buckle_c + Vector2(0, -2), buckle_c + Vector2(0, 2), Color(0.50, 0.40, 0.15), 1.0)
	# Buckle shine
	draw_circle(buckle_c + Vector2(1, -1), 0.8, Color(0.85, 0.75, 0.35, 0.5))
	# Green gem in buckle
	draw_circle(buckle_c, 1.2, Color(0.20, 0.65, 0.15))
	draw_circle(buckle_c + Vector2(-0.2, -0.2), 0.5, Color(0.35, 0.85, 0.25, 0.5))

	# === T3+: GOLDEN CAP overlay on hat ===
	if upgrade_tier >= 3:
		draw_colored_polygon(hat_pts, Color(0.85, 0.70, 0.15, 0.3))
		# Jeweled brim
		draw_line(brim_l, brim_r, Color(0.90, 0.85, 0.60), 3.0)
		draw_line(brim_l, brim_r, Color(1.0, 0.95, 0.70, 0.35), 1.2)
		# Gems on band
		draw_circle(hat_base_pos + Vector2(-7, -2), 2.0, Color(0.85, 0.12, 0.15))
		draw_circle(hat_base_pos + Vector2(-7, -2), 1.0, Color(0.95, 0.30, 0.30, 0.5))
		draw_circle(hat_base_pos + Vector2(7, -2), 2.0, Color(0.10, 0.70, 0.20))
		draw_circle(hat_base_pos + Vector2(7, -2), 1.0, Color(0.30, 0.85, 0.40, 0.5))
		# Golden trim on hat edges
		draw_line(hat_base_pos + Vector2(-12, -1), hat_tip_pos, Color(0.80, 0.65, 0.15, 0.2), 1.2)
		draw_line(hat_base_pos + Vector2(12, -1), hat_tip_pos, Color(0.80, 0.65, 0.15, 0.2), 1.2)

	# === T4: GOLDEN CAP SHIMMER + WINGED MONKEY SILHOUETTES ===
	if upgrade_tier >= 4:
		# Pulsing golden shimmer on hat
		var shimmer_a = 0.15 + sin(_time * 4.0) * 0.08
		draw_colored_polygon(hat_pts, Color(1.0, 0.92, 0.40, shimmer_a))
		# Sparkle dots
		for i in range(4):
			var sp_t = 0.15 + float(i) * 0.2
			var sp_pos = hat_base_pos.lerp(hat_tip_pos, sp_t) + Vector2(sin(_time * 3.0 + float(i)) * 3.0, 0)
			var sp_alpha = 0.5 + sin(_time * 5.0 + float(i) * 2.0) * 0.3
			draw_circle(sp_pos, 1.8, Color(1.0, 0.95, 0.50, sp_alpha))
			# Starburst
			for sbi in range(4):
				var star_a2 = float(sbi) * TAU / 4.0 + _time * 2.0
				draw_line(sp_pos, sp_pos + Vector2.from_angle(star_a2) * 2.5, Color(1.0, 0.95, 0.50, sp_alpha * 0.4), 0.6)

		# Dark purple aura
		var aura_pulse = sin(_time * 1.5) * 0.03
		draw_circle(Vector2.ZERO, 90.0, Color(0.15, 0.05, 0.20, 0.05 + aura_pulse))
		draw_circle(Vector2.ZERO, 75.0, Color(0.20, 0.08, 0.25, 0.06 + aura_pulse))
		# Dark energy tendrils
		for i in range(5):
			var t_angle2 = _time * 0.6 + float(i) * TAU / 5.0
			var t_r2 = 65.0 + sin(_time * 1.2 + float(i) * 1.5) * 10.0
			var t_pos2 = Vector2.from_angle(t_angle2) * t_r2
			var t_end2 = Vector2.from_angle(t_angle2 + 0.3) * (t_r2 + 15.0)
			draw_line(t_pos2, t_end2, Color(0.30, 0.10, 0.40, 0.10 + sin(_time * 2.0 + float(i)) * 0.04), 2.0)

		# Winged monkey silhouettes orbiting (2 monkeys)
		for mi in range(2):
			var m_orbit_a = _time * (0.7 + float(mi) * 0.3) + float(mi) * PI
			var m_orbit_r = 55.0 + float(mi) * 12.0
			var monkey_pos = Vector2(cos(m_orbit_a) * m_orbit_r, sin(m_orbit_a) * m_orbit_r * 0.5 - 30.0)
			var mc = Color(0.12, 0.08, 0.06, 0.45 - float(mi) * 0.08)
			# Monkey body outline + fill
			draw_circle(monkey_pos, 7.5, OL)
			draw_circle(monkey_pos, 6.0, mc)
			# Monkey head
			var mhead = monkey_pos + Vector2(0, -7)
			draw_circle(mhead, 5.5, OL)
			draw_circle(mhead, 4.2, mc)
			# Monkey face
			draw_circle(mhead + Vector2(0, 1), 2.2, Color(0.18, 0.14, 0.10, 0.35))
			# Eyes (glowing red)
			draw_circle(mhead + Vector2(-1.5, -0.5), 1.0, Color(0.80, 0.20, 0.05, 0.5))
			draw_circle(mhead + Vector2(1.5, -0.5), 1.0, Color(0.80, 0.20, 0.05, 0.5))
			# Ears
			draw_circle(mhead + Vector2(-4, -2), 2.0, Color(mc.r, mc.g, mc.b, mc.a - 0.08))
			draw_circle(mhead + Vector2(4, -2), 2.0, Color(mc.r, mc.g, mc.b, mc.a - 0.08))
			# Bat-like wings
			var wf = sin(_time * 6.0 + float(mi) * PI) * 6.0
			var lw_pts = PackedVector2Array([monkey_pos + Vector2(-4, -2), monkey_pos + Vector2(-20, -10 + wf), monkey_pos + Vector2(-22, -4 + wf), monkey_pos + Vector2(-6, 3)])
			draw_colored_polygon(lw_pts, Color(mc.r, mc.g, mc.b, mc.a * 0.6))
			draw_line(monkey_pos + Vector2(-4, -2), monkey_pos + Vector2(-20, -10 + wf), mc, 2.0)
			var rw_pts = PackedVector2Array([monkey_pos + Vector2(4, -2), monkey_pos + Vector2(20, -10 + wf), monkey_pos + Vector2(22, -4 + wf), monkey_pos + Vector2(6, 3)])
			draw_colored_polygon(rw_pts, Color(mc.r, mc.g, mc.b, mc.a * 0.6))
			draw_line(monkey_pos + Vector2(4, -2), monkey_pos + Vector2(20, -10 + wf), mc, 2.0)
			# Tail
			var tc = sin(_time * 2.0 + float(mi) * 1.5) * 4.0
			draw_line(monkey_pos + Vector2(0, 7), monkey_pos + Vector2(3 + tc, 14), Color(mc.r, mc.g, mc.b, mc.a - 0.05), 2.0)
			# Fez/cap
			draw_circle(mhead + Vector2(0, -4), 2.5, Color(0.60, 0.15, 0.10, 0.4))

	# === T3+: BEE SWARM PARTICLES ===
	if upgrade_tier >= 3:
		var bee_count = 5 + (upgrade_tier - 3) * 3
		for i in range(bee_count):
			var bee_phase = float(i) * TAU / float(bee_count)
			var bee_speed = 2.5 + float(i) * 0.4
			var bee_radius = 28.0 + float(i % 4) * 7.0
			var bx = cos(_time * bee_speed + bee_phase) * bee_radius
			var by = sin(_time * bee_speed * 1.3 + bee_phase) * bee_radius * 0.6 + sin(_time * 5.0 + bee_phase) * 4.0
			var bee_pos = Vector2(bx, by)
			# Bee body (yellow-black)
			draw_circle(bee_pos, 2.5, Color(0.95, 0.85, 0.10, 0.7))
			# Bee head
			var bee_dir = Vector2(-sin(_time * bee_speed + bee_phase), cos(_time * bee_speed * 1.3 + bee_phase) * 0.6).normalized()
			draw_circle(bee_pos + bee_dir * 2.0, 1.5, Color(0.20, 0.15, 0.0, 0.5))
			# Black stripe
			var bee_wing_perp = bee_dir.rotated(PI / 2.0)
			draw_line(bee_pos - bee_dir * 0.5 + bee_wing_perp * 2.0, bee_pos - bee_dir * 0.5 - bee_wing_perp * 2.0, Color(0.15, 0.10, 0.0, 0.45), 1.0)
			# Wings (flutter)
			var wing_f2 = sin(_time * 20.0 + bee_phase) * 2.5
			draw_line(bee_pos, bee_pos + bee_wing_perp * (3.0 + wing_f2), Color(0.80, 0.85, 0.95, 0.3), 1.2)
			draw_line(bee_pos, bee_pos - bee_wing_perp * (3.0 - wing_f2), Color(0.80, 0.85, 0.95, 0.3), 1.2)
			# Buzz trail
			draw_line(bee_pos, bee_pos - bee_dir * 6.0, Color(0.90, 0.80, 0.10, 0.12), 0.8)

	# === GREEN MAGIC PARTICLES floating around ===
	var particle_count = 4 + upgrade_tier * 2
	for i in range(particle_count):
		var phase = float(i) * TAU / float(particle_count)
		var p_orbit_speed = 1.2 + float(i) * 0.25
		var p_orbit_radius = 42.0 + float(i % 4) * 7.0
		var px = cos(_time * p_orbit_speed + phase) * p_orbit_radius
		var py = sin(_time * p_orbit_speed + phase) * p_orbit_radius * 0.6 + sin(_time * 2.5 + phase) * 5.0
		var p_alpha = 0.25 + sin(_time * 3.0 + phase) * 0.12
		var p_size = 3.0 + sin(_time * 2.0 + phase) * 0.8
		var use_purple = (i % 3 == 0) and (upgrade_tier >= 2)
		var p_col = Color(0.50, 0.20, 0.70, p_alpha * 0.7) if use_purple else Color(0.30, 0.85, 0.20, p_alpha)
		# Glow halo
		draw_circle(Vector2(px, py), p_size + 3.0, Color(p_col.r, p_col.g, p_col.b, p_alpha * 0.2))
		# Core particle
		draw_circle(Vector2(px, py), p_size, p_col)
		# Bright center
		draw_circle(Vector2(px, py), p_size * 0.35, Color(min(p_col.r + 0.3, 1.0), min(p_col.g + 0.15, 1.0), min(p_col.b + 0.3, 1.0), p_alpha * 0.7))

	# === Silver whistle on chain around neck ===
	var whistle_anchor = neck_base + Vector2(0, 2)
	var whistle_droop = whistle_anchor + Vector2(0, 5 + sin(_time * 1.5) * 0.8)
	# Chain
	draw_line(whistle_anchor + Vector2(-4, 0), whistle_droop, Color(0.60, 0.60, 0.65, 0.5), 1.0)
	draw_line(whistle_anchor + Vector2(4, 0), whistle_droop, Color(0.60, 0.60, 0.65, 0.5), 1.0)
	# Whistle body
	var w_dir = Vector2(1, 0.3).normalized()
	var w_end = whistle_droop + w_dir * 6.0
	draw_line(whistle_droop - w_dir * 1.0, w_end, OL, 4.5)
	draw_line(whistle_droop, w_end, Color(0.70, 0.70, 0.75), 3.0)
	draw_line(whistle_droop + w_dir * 0.3, w_end - w_dir * 0.3, Color(0.85, 0.85, 0.90), 1.2)
	# Mouthpiece
	draw_circle(whistle_droop - w_dir * 1.0, 2.0, Color(0.60, 0.60, 0.65))
	# Sound hole
	draw_circle(w_end, 1.5, Color(0.55, 0.55, 0.60))
	draw_circle(w_end, 0.8, Color(0.20, 0.20, 0.25))
	# Shine
	draw_circle(whistle_droop + w_dir * 2.0 + Vector2(0, -0.8), 0.6, Color(0.95, 0.95, 1.0, 0.5))


	# === AWAITING ABILITY CHOICE INDICATOR ===
	if awaiting_ability_choice:
		var pulse = (sin(_time * 4.0) + 1.0) * 0.5
		draw_circle(Vector2.ZERO, 76.0 + pulse * 8.0, Color(0.4, 0.9, 0.2, 0.1 + pulse * 0.1))
		draw_arc(Vector2.ZERO, 76.0 + pulse * 8.0, 0, TAU, 32, Color(0.4, 0.9, 0.2, 0.3 + pulse * 0.3), 3.5)
		draw_arc(Vector2.ZERO, 72.0 + pulse * 6.0, 0, TAU, 32, Color(0.3, 0.7, 0.15, 0.15 + pulse * 0.15), 2.0)
		var font3 = _game_font
		draw_string(font3, Vector2(-16, -88), "!", HORIZONTAL_ALIGNMENT_CENTER, 32, 36, Color(0.4, 0.9, 0.2, 0.7 + pulse * 0.3))

	# === DAMAGE DEALT COUNTER ===
	if damage_dealt > 0:
		var font = _game_font
		var dmg_text = str(int(damage_dealt)) + " DMG"
		if stat_upgrade_level > 0:
			dmg_text += " • Lv." + str(stat_upgrade_level)
		draw_string(font, Vector2(-36, 84), dmg_text, HORIZONTAL_ALIGNMENT_LEFT, 160, 14, Color(1.0, 0.84, 0.0, 0.6))

	# === UPGRADE NAME FLASH ===
	if _upgrade_flash > 0.0 and _upgrade_name != "":
		var font2 = _game_font
		draw_string(font2, Vector2(-80, -80), _upgrade_name, HORIZONTAL_ALIGNMENT_CENTER, 160, 16, Color(0.4, 0.9, 0.2, min(_upgrade_flash, 1.0)))

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
