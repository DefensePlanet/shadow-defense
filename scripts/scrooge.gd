extends Node2D
## Ebenezer Scrooge — support tower from Dickens' A Christmas Carol (1843).
## Rings bell for AoE knockback and gold generation. Upgrades by dealing damage.
## Tier 1: "Bah, Humbug!" — Stronger knockback (50 units), gold +3, faster bell
## Tier 2: "Ghost of Christmas Past" — periodically mark random enemy (+25% dmg)
## Tier 3: "Ghost of Christmas Present" — Enhanced blast radius (180), passive gold gen, mark all
## Tier 4: "Ghost of Yet to Come" — Maximum knockback (80), fear-slow on knocked enemies

var damage: float = 5.0
var fire_rate: float = 0.667
var attack_range: float = 130.0
var fire_cooldown: float = 0.0
var aim_angle: float = 0.0
var target: Node2D = null
var gold_bonus: int = 1

# Knockback and gold generation
var knockback_amount: float = 30.0
var gold_per_ring: int = 2
var bonus_gold_per_enemy: int = 1

# Damage tracking and upgrades
var damage_dealt: float = 0.0
var upgrade_tier: int = 0
var _upgrade_flash: float = 0.0
var _upgrade_name: String = ""

# Animation vars
var _time: float = 0.0
var _attack_anim: float = 0.0

# Tier 2: Ghost of Christmas Past — mark one enemy
var ghost_past_timer: float = 0.0
var ghost_past_cooldown: float = 12.0
var _ghost_flash: float = 0.0

# Tier 3: Ghost of Christmas Present — mark all + passive gold
var ghost_present_timer: float = 0.0
var ghost_present_cooldown: float = 10.0
var passive_gold_timer: float = 0.0
var passive_gold_interval: float = 5.0
var passive_gold_amount: int = 1

# Tier 4: Ghost of Yet to Come — fear slow on marks
var fear_enabled: bool = false

# === PROGRESSIVE ABILITIES (9 tiers, unlocked via lifetime damage) ===
const PROG_ABILITY_NAMES = [
	"A Miser's Bell", "Marley's Warning", "Cratchit's Loyalty", "Tiny Tim's Blessing",
	"Marley's Chains", "Fezziwig's Ball", "The Knocker", "The Christmas Turkey",
	"Scrooge's Redemption"
]
const PROG_ABILITY_DESCS = [
	"+20% knockback, +20% damage",
	"Every 15s, chains root 3 enemies for 2s",
	"Passive gold generation doubles",
	"Every 25s, heals 1 life",
	"Every 15s, chains link 3 enemies sharing 30% damage for 8s",
	"All towers within 300 units attack 25% faster (aura)",
	"Every 20s, enemies walk backwards 3s",
	"Every 20s, turkey bounces hitting every enemy for 2x",
	"Every 10s, gold explosion dealing 5% current gold to all enemies"
]
var prog_abilities: Array = [false, false, false, false, false, false, false, false, false]
var _marleys_warning_timer: float = 15.0
var _tiny_tim_timer: float = 25.0
var _marleys_chains_timer: float = 15.0
var _fezziwig_aura_timer: float = 2.0
var _knocker_timer: float = 20.0
var _turkey_timer: float = 20.0
var _redemption_timer: float = 10.0
var _turkey_flash: float = 0.0
var _redemption_flash: float = 0.0
var _knocker_flash: float = 0.0

const STAT_UPGRADE_INTERVAL: float = 500.0
const ABILITY_THRESHOLD: float = 1500.0
var stat_upgrade_level: int = 0
var ability_chosen: bool = false
var awaiting_ability_choice: bool = false
const TIER_NAMES = [
	"Bah, Humbug!",
	"Ghost of Christmas Past",
	"Ghost of Christmas Present",
	"Ghost of Yet to Come"
]
const ABILITY_DESCRIPTIONS = [
	"Stronger knockback, +3 gold, faster bell",
	"Periodically mark enemy (+25% dmg taken)",
	"Blast radius 180, passive gold, mark all",
	"Max knockback, fear-slow on knocked enemies"
]
const TIER_COSTS = [55, 120, 225, 400]
var is_selected: bool = false
var base_cost: int = 0

# Attack sounds — bell melody evolving with upgrade tier
var _attack_sounds: Array = []
var _attack_sounds_by_tier: Array = []
var _attack_player: AudioStreamPlayer

# Ability sounds
var _ghost_past_sound: AudioStreamWAV
var _ghost_past_player: AudioStreamPlayer
var _ghost_present_sound: AudioStreamWAV
var _ghost_present_player: AudioStreamPlayer
var _upgrade_sound: AudioStreamWAV
var _upgrade_player: AudioStreamPlayer

func _ready() -> void:
	add_to_group("towers")
	_load_progressive_abilities()
	_generate_tier_sounds()
	_attack_sounds = _attack_sounds_by_tier[0]
	_attack_player = AudioStreamPlayer.new()
	_attack_player.stream = _attack_sounds[0]
	_attack_player.volume_db = -6.0
	add_child(_attack_player)

	# Ghost of Past — wavering ghostly moan (mid-pitch, breathy)
	var gp_rate := 22050
	var gp_dur := 0.6
	var gp_samples := PackedFloat32Array()
	gp_samples.resize(int(gp_rate * gp_dur))
	for i in gp_samples.size():
		var t := float(i) / gp_rate
		var freq := 350.0 + sin(TAU * 4.0 * t) * 40.0
		var att := minf(t * 8.0, 1.0)
		var dec := exp(-(t - 0.15) * 4.0) if t > 0.15 else 1.0
		var env := att * dec * 0.35
		var breath := (randf() * 2.0 - 1.0) * 0.15
		gp_samples[i] = clampf((sin(TAU * freq * t) * 0.5 + sin(TAU * freq * 1.5 * t) * 0.2 + breath) * env, -1.0, 1.0)
	_ghost_past_sound = _samples_to_wav(gp_samples, gp_rate)
	_ghost_past_player = AudioStreamPlayer.new()
	_ghost_past_player.stream = _ghost_past_sound
	_ghost_past_player.volume_db = -6.0
	add_child(_ghost_past_player)

	# Ghost of Present — deeper richer ghostly moan with reverb tail
	var gpr_rate := 22050
	var gpr_dur := 0.7
	var gpr_samples := PackedFloat32Array()
	gpr_samples.resize(int(gpr_rate * gpr_dur))
	for i in gpr_samples.size():
		var t := float(i) / gpr_rate
		var freq := 200.0 + sin(TAU * 3.0 * t) * 30.0
		var att := minf(t * 6.0, 1.0)
		var dec := exp(-t * 3.0)
		var env := att * dec * 0.4
		var s := sin(TAU * freq * t) * 0.5 + sin(TAU * freq * 2.0 * t) * 0.25
		s += sin(TAU * freq * 3.0 * t) * 0.1 + (randf() * 2.0 - 1.0) * 0.1
		gpr_samples[i] = clampf(s * env, -1.0, 1.0)
	_ghost_present_sound = _samples_to_wav(gpr_samples, gpr_rate)
	_ghost_present_player = AudioStreamPlayer.new()
	_ghost_present_player.stream = _ghost_present_sound
	_ghost_present_player.volume_db = -6.0
	add_child(_ghost_present_player)

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
	fire_cooldown -= delta
	_upgrade_flash = max(_upgrade_flash - delta * 0.5, 0.0)
	_ghost_flash = max(_ghost_flash - delta * 1.5, 0.0)
	target = _find_nearest_enemy()

	if target:
		var desired = global_position.angle_to_point(target.global_position) + PI
		aim_angle = lerp_angle(aim_angle, desired, 8.0 * delta)
		if fire_cooldown <= 0.0:
			_shoot()
			fire_cooldown = 1.0 / (fire_rate * _speed_mult())

	# Tier 2: Ghost of Christmas Past — mark single enemy
	if upgrade_tier == 2:
		ghost_past_timer -= delta
		if ghost_past_timer <= 0.0 and _has_enemies_in_range():
			_ghost_of_past()
			ghost_past_timer = ghost_past_cooldown

	# Tier 3+: Ghost of Christmas Present — mark all in range
	if upgrade_tier >= 3:
		ghost_present_timer -= delta
		if ghost_present_timer <= 0.0 and _has_enemies_in_range():
			_ghost_of_present()
			ghost_present_timer = ghost_present_cooldown

		# Passive gold generation
		passive_gold_timer -= delta
		if passive_gold_timer <= 0.0:
			passive_gold_timer = passive_gold_interval
			var main = get_tree().get_first_node_in_group("main")
			if main:
				main.add_gold(passive_gold_amount)

	# Progressive abilities
	_process_progressive_abilities(delta)

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

func _shoot() -> void:
	if _attack_player and _attack_sounds.size() > 0 and not _is_sfx_muted():
		_attack_player.stream = _attack_sounds[_get_note_index() % _attack_sounds.size()]
		_attack_player.play()
	_attack_anim = 1.0
	var main = get_tree().get_first_node_in_group("main")
	var dmg_mult = _damage_mult()
	var kb = knockback_amount
	# Ability 1: A Miser's Bell — +20% damage, +20% knockback
	if prog_abilities[0]:
		dmg_mult *= 1.2
		kb *= 1.2
	var eff_range = attack_range * _range_mult()
	var enemies_hit = 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(enemy.global_position) <= eff_range:
			# Knockback — push enemies back on path
			enemy.progress = max(0.0, enemy.progress - kb)
			# Small damage
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage * dmg_mult)
				register_damage(damage * dmg_mult)
			# Tier 4: fear-slow on knocked enemies
			if fear_enabled and enemy.has_method("apply_slow"):
				enemy.apply_slow(0.5, 1.5)
			enemies_hit += 1
	# Earn gold per bell ring (more enemies = more gold)
	if main and enemies_hit > 0:
		main.add_gold(int((gold_per_ring + (enemies_hit - 1) * bonus_gold_per_enemy) * _gold_mult()))

func _ghost_of_past() -> void:
	if _ghost_past_player and not _is_sfx_muted(): _ghost_past_player.play()
	_ghost_flash = 1.0
	var enemies = get_tree().get_nodes_in_group("enemies")
	var in_range: Array = []
	for enemy in enemies:
		if global_position.distance_to(enemy.global_position) < attack_range:
			in_range.append(enemy)
	if in_range.size() > 0:
		var picked = in_range[randi() % in_range.size()]
		if picked.has_method("apply_mark"):
			picked.apply_mark(1.25, 5.0, fear_enabled)

func _ghost_of_present() -> void:
	if _ghost_present_player and not _is_sfx_muted(): _ghost_present_player.play()
	_ghost_flash = 1.2
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(enemy.global_position) < attack_range:
			if enemy.has_method("apply_mark"):
				enemy.apply_mark(1.25, 5.0, fear_enabled)

func register_damage(amount: float) -> void:
	damage_dealt += amount
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("register_tower_damage"):
		main.register_tower_damage(main.TowerType.SCROOGE, amount)

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
	damage *= 1.10
	fire_rate *= 1.05
	attack_range += 4.0
	knockback_amount += 3.0
	gold_per_ring += 1
	# Cash bundle every 500 damage milestone
	var main = get_tree().get_first_node_in_group("main")
	if main:
		main.add_gold(5 + stat_upgrade_level * 2)

func choose_ability(index: int) -> void:
	ability_chosen = true
	awaiting_ability_choice = false
	upgrade_tier = index + 1
	_apply_upgrade(upgrade_tier)
	_upgrade_flash = 3.0
	_upgrade_name = TIER_NAMES[index]

func _apply_upgrade(tier: int) -> void:
	match tier:
		1: # Bah, Humbug! — stronger knockback, more gold, faster bell
			knockback_amount = 50.0
			gold_per_ring = 5
			bonus_gold_per_enemy = 2
			fire_rate = 0.8
			damage = 8.0
			attack_range = 145.0
		2: # Ghost of Christmas Past — mark enemies
			knockback_amount = 55.0
			damage = 12.0
			fire_rate = 0.9
			attack_range = 160.0
			gold_per_ring = 6
			ghost_past_cooldown = 10.0
		3: # Ghost of Christmas Present — enhanced blast, passive gold, mark all
			attack_range = 180.0
			knockback_amount = 65.0
			damage = 16.0
			fire_rate = 1.0
			gold_per_ring = 8
			passive_gold_amount = 2
			passive_gold_interval = 5.0
			ghost_present_cooldown = 8.0
		4: # Ghost of Yet to Come — max knockback, fear-slow
			knockback_amount = 80.0
			fear_enabled = true
			damage = 20.0
			fire_rate = 1.1
			gold_per_ring = 10
			attack_range = 200.0
			passive_gold_amount = 3
			passive_gold_interval = 3.5
			ghost_present_cooldown = 6.0

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
	return "Scrooge"

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
	# Coin-chime notes — bright, high, pleasant like tossed coins
	var coin_notes := [880.00, 1046.50, 1174.66, 1396.91, 1174.66, 1046.50, 880.00, 1396.91]  # A5, C6, D6, F6, D6, C6, A5, F6 (D minor coin chime melody)
	var mix_rate := 44100
	_attack_sounds_by_tier = []

	# --- Tier 0: Coin Toss (short metallic clink) ---
	var t0 := []
	for note_idx in coin_notes.size():
		var freq: float = coin_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.12))
		for i in samples.size():
			var t := float(i) / mix_rate
			var env := exp(-t * 25.0) * 0.25
			var fund := sin(t * freq * TAU)
			var h2 := sin(t * freq * 2.3 * TAU) * 0.3 * exp(-t * 35.0)
			var clink := sin(t * freq * 3.7 * TAU) * 0.15 * exp(-t * 50.0)
			var tap := (randf() * 2.0 - 1.0) * exp(-t * 400.0) * 0.15
			samples[i] = clampf((fund + h2 + clink) * env + tap, -1.0, 1.0)
		t0.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t0)

	# --- Tier 1: Silver Coin (brighter ring, slight shimmer) ---
	var t1 := []
	for note_idx in coin_notes.size():
		var freq: float = coin_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.15))
		for i in samples.size():
			var t := float(i) / mix_rate
			var env := exp(-t * 20.0) * 0.25
			var fund := sin(t * freq * TAU)
			var h2 := sin(t * freq * 2.0 * TAU) * 0.2 * exp(-t * 30.0)
			var shimmer := sin(t * freq * 1.005 * TAU) * 0.15 * exp(-t * 18.0)
			var tap := (randf() * 2.0 - 1.0) * exp(-t * 500.0) * 0.12
			samples[i] = clampf((fund + h2 + shimmer) * env + tap, -1.0, 1.0)
		t1.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t1)

	# --- Tier 2: Gold Coin (warmer, richer harmonics) ---
	var t2 := []
	for note_idx in coin_notes.size():
		var freq: float = coin_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.18))
		for i in samples.size():
			var t := float(i) / mix_rate
			var env := exp(-t * 16.0) * 0.25
			var fund := sin(t * freq * TAU)
			var h2 := sin(t * freq * 2.0 * TAU) * 0.18
			var h3 := sin(t * freq * 3.0 * TAU) * 0.08 * exp(-t * 25.0)
			var ring := sin(t * freq * 1.5 * TAU) * 0.1 * exp(-t * 20.0)
			var tap := (randf() * 2.0 - 1.0) * exp(-t * 350.0) * 0.1
			samples[i] = clampf((fund + h2 + h3 + ring) * env + tap, -1.0, 1.0)
		t2.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t2)

	# --- Tier 3: Coin Cascade (double-hit, like coins bouncing) ---
	var t3 := []
	for note_idx in coin_notes.size():
		var freq: float = coin_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.2))
		for i in samples.size():
			var t := float(i) / mix_rate
			# First coin hit
			var env1 := exp(-t * 30.0) * 0.2
			var c1 := sin(t * freq * TAU) * env1
			# Second coin hit (delayed)
			var dt := t - 0.04
			var c2 := 0.0
			if dt > 0.0:
				var env2 := exp(-dt * 35.0) * 0.18
				c2 = sin(dt * freq * 1.25 * TAU) * env2
			var h := sin(t * freq * 2.3 * TAU) * exp(-t * 40.0) * 0.1
			var tap := (randf() * 2.0 - 1.0) * exp(-t * 500.0) * 0.1
			samples[i] = clampf(c1 + c2 + h + tap, -1.0, 1.0)
		t3.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t3)

	# --- Tier 4: Treasure Chime (rich multi-note sparkle) ---
	var t4 := []
	for note_idx in coin_notes.size():
		var freq: float = coin_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.25))
		for i in samples.size():
			var t := float(i) / mix_rate
			var env := exp(-t * 14.0) * 0.2
			var fund := sin(t * freq * TAU)
			# Sparkle chorus (slightly detuned layers)
			var sp1 := sin(t * freq * 1.003 * TAU) * 0.3
			var sp2 := sin(t * freq * 0.997 * TAU) * 0.3
			var h2 := sin(t * freq * 2.0 * TAU) * 0.12 * exp(-t * 20.0)
			var twinkle := sin(t * freq * 3.0 * TAU) * exp(-t * 30.0) * 0.08
			var tap := (randf() * 2.0 - 1.0) * exp(-t * 400.0) * 0.08
			samples[i] = clampf((fund + sp1 + sp2 + h2 + twinkle) * env + tap, -1.0, 1.0)
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
	if main and main.survivor_progress.has(main.TowerType.SCROOGE):
		var p = main.survivor_progress[main.TowerType.SCROOGE]
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
	# Ability 3: Cratchit's Loyalty — double passive gold
	if prog_abilities[2]:
		passive_gold_amount = max(passive_gold_amount, 2)

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
	_turkey_flash = max(_turkey_flash - delta * 2.0, 0.0)
	_redemption_flash = max(_redemption_flash - delta * 2.0, 0.0)
	_knocker_flash = max(_knocker_flash - delta * 2.0, 0.0)

	# Ability 2: Marley's Warning — chains root 3 enemies
	if prog_abilities[1]:
		_marleys_warning_timer -= delta
		if _marleys_warning_timer <= 0.0 and _has_enemies_in_range():
			_marleys_warning()
			_marleys_warning_timer = 15.0

	# Ability 4: Tiny Tim's Blessing — restore 1 life
	if prog_abilities[3]:
		_tiny_tim_timer -= delta
		if _tiny_tim_timer <= 0.0:
			var main = get_tree().get_first_node_in_group("main")
			if main and main.has_method("restore_life"):
				main.restore_life(1)
			_tiny_tim_timer = 25.0

	# Ability 5: Marley's Chains — link 3 enemies sharing damage
	if prog_abilities[4]:
		_marleys_chains_timer -= delta
		if _marleys_chains_timer <= 0.0 and _has_enemies_in_range():
			_marleys_chains_link()
			_marleys_chains_timer = 15.0

	# Ability 6: Fezziwig's Ball — aura boost nearby towers
	if prog_abilities[5]:
		_fezziwig_aura_timer -= delta
		if _fezziwig_aura_timer <= 0.0:
			_fezziwig_aura()
			_fezziwig_aura_timer = 2.0

	# Ability 7: The Knocker — enemies walk backwards
	if prog_abilities[6]:
		_knocker_timer -= delta
		if _knocker_timer <= 0.0 and _has_enemies_in_range():
			_knocker_reverse()
			_knocker_timer = 20.0

	# Ability 8: The Christmas Turkey — bounce hitting all enemies
	if prog_abilities[7]:
		_turkey_timer -= delta
		if _turkey_timer <= 0.0:
			_christmas_turkey()
			_turkey_timer = 20.0

	# Ability 9: Scrooge's Redemption — gold explosion
	if prog_abilities[8]:
		_redemption_timer -= delta
		if _redemption_timer <= 0.0:
			_scrooges_redemption()
			_redemption_timer = 10.0

func _marleys_warning() -> void:
	_ghost_flash = 1.0
	var enemies = get_tree().get_nodes_in_group("enemies")
	var in_range: Array = []
	for e in enemies:
		if global_position.distance_to(e.global_position) < attack_range:
			in_range.append(e)
	in_range.shuffle()
	for i in range(mini(3, in_range.size())):
		if is_instance_valid(in_range[i]) and in_range[i].has_method("apply_slow"):
			in_range[i].apply_slow(0.0, 2.0)

func _marleys_chains_link() -> void:
	_ghost_flash = 1.0
	var enemies = get_tree().get_nodes_in_group("enemies")
	var in_range: Array = []
	for e in enemies:
		if global_position.distance_to(e.global_position) < attack_range:
			in_range.append(e)
	in_range.shuffle()
	var chained: Array = []
	for i in range(mini(3, in_range.size())):
		if is_instance_valid(in_range[i]):
			chained.append(in_range[i])
	for e in chained:
		if e.has_method("apply_chain"):
			e.apply_chain(chained, 0.3, 8.0)

func _fezziwig_aura() -> void:
	for tower in get_tree().get_nodes_in_group("towers"):
		if tower == self:
			continue
		if global_position.distance_to(tower.global_position) < 300.0:
			if "fire_rate" in tower:
				# Apply a brief 25% fire rate boost (re-applied every 2s)
				if not tower.has_meta("fezziwig_base_rate"):
					tower.set_meta("fezziwig_base_rate", tower.fire_rate)
				var base_rate = tower.get_meta("fezziwig_base_rate")
				tower.fire_rate = base_rate * 1.25

func _knocker_reverse() -> void:
	_knocker_flash = 1.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) < attack_range:
			if e.has_method("apply_fear_reverse"):
				e.apply_fear_reverse(3.0)

func _christmas_turkey() -> void:
	_turkey_flash = 1.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("take_damage"):
			var dmg = damage * 2.0
			e.take_damage(dmg)
			register_damage(dmg)

func _scrooges_redemption() -> void:
	_redemption_flash = 1.0
	var main = get_tree().get_first_node_in_group("main")
	if not main:
		return
	var gold = main.gold if "gold" in main else 0
	var dmg = gold * 0.05
	if dmg <= 0:
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("take_damage"):
			e.take_damage(dmg)
			register_damage(dmg)

func _draw() -> void:
	var is_kind = upgrade_tier >= 3

	# === SELECTION RING ===
	if is_selected:
		var pulse = (sin(_time * 3.0) + 1.0) * 0.5
		var ring_alpha = 0.5 + pulse * 0.3
		draw_arc(Vector2.ZERO, 40.0, 0, TAU, 48, Color(1.0, 0.84, 0.0, ring_alpha), 2.5)
		draw_arc(Vector2.ZERO, 43.0, 0, TAU, 48, Color(1.0, 0.84, 0.0, ring_alpha * 0.4), 1.5)

	# === RANGE ARC ===
	draw_arc(Vector2.ZERO, attack_range, 0, TAU, 64, Color(1, 1, 1, 0.06), 1.0)

	# === AIM DIRECTION ===
	var dir = Vector2.from_angle(aim_angle)
	var perp = dir.rotated(PI / 2.0)

	# === IDLE ANIMATION (hunched forward rocking) ===
	var bounce = abs(sin(_time * 2.5)) * 3.0
	var breathe = sin(_time * 1.8) * 1.5
	var sway = sin(_time * 1.2) * 1.0
	var hunch_rock = sin(_time * 1.5) * 1.5  # Forward-back rocking
	var bob = Vector2(sway, -bounce - breathe)
	var fly_offset = Vector2.ZERO
	if upgrade_tier >= 4:
		fly_offset = Vector2(0, -6.0 + sin(_time * 1.5) * 2.0)
	var body_offset = bob + fly_offset

	# === SKIN COLORS (pale, elderly) ===
	var skin_base = Color(0.85, 0.78, 0.72)
	var skin_shadow = Color(0.70, 0.62, 0.55)
	var skin_highlight = Color(0.92, 0.86, 0.80)


	# === UPGRADE FLASH ===
	if _upgrade_flash > 0.0:
		draw_circle(Vector2.ZERO, 80.0 + _upgrade_flash * 24.0, Color(0.9, 0.85, 0.4, _upgrade_flash * 0.25))
		for i in range(10):
			var ray_a = TAU * float(i) / 10.0 + _time * 0.5
			var ray_inner = 60.0 + _upgrade_flash * 8.0
			var ray_outer = 90.0 + _upgrade_flash * 25.0
			draw_line(Vector2.from_angle(ray_a) * ray_inner, Vector2.from_angle(ray_a) * ray_outer, Color(1.0, 0.95, 0.5, _upgrade_flash * 0.15), 2.0)

	# === GHOST FLASH (spectral expanding ring) ===
	if _ghost_flash > 0.0:
		var ghost_col: Color
		if upgrade_tier >= 4:
			ghost_col = Color(0.15, 0.1, 0.2, _ghost_flash * 0.4)
		elif upgrade_tier >= 3:
			ghost_col = Color(0.3, 0.6, 0.2, _ghost_flash * 0.3)
		else:
			ghost_col = Color(0.5, 0.6, 0.8, _ghost_flash * 0.3)
		var ripple_r = 40.0 + (1.0 - _ghost_flash) * 100.0
		draw_circle(Vector2.ZERO, ripple_r * 0.8, ghost_col)
		draw_arc(Vector2.ZERO, ripple_r, 0, TAU, 48, Color(ghost_col.r, ghost_col.g, ghost_col.b, _ghost_flash * 0.5), 2.5)
		draw_arc(Vector2.ZERO, ripple_r * 0.6, 0, TAU, 36, Color(ghost_col.r, ghost_col.g, ghost_col.b, _ghost_flash * 0.25), 1.5)
		for i in range(6):
			var wisp_a = TAU * float(i) / 6.0 + _time * 0.8
			var wisp_r2 = ripple_r * (0.5 + sin(_time * 3.0 + float(i)) * 0.2)
			var wisp_p = Vector2.from_angle(wisp_a) * wisp_r2
			draw_circle(wisp_p, 3.0, Color(ghost_col.r, ghost_col.g, ghost_col.b, _ghost_flash * 0.3))

	# === PROGRESSIVE ABILITY VISUAL EFFECTS ===
	# Ability 6: Fezziwig's Ball — warm aura ring
	if prog_abilities[5]:
		var fez_pulse = (sin(_time * 2.0) + 1.0) * 0.5
		draw_arc(Vector2.ZERO, 300.0, 0, TAU, 48, Color(1.0, 0.85, 0.3, 0.06 + fez_pulse * 0.04), 2.0)
		draw_circle(Vector2.ZERO, 28.0, Color(1.0, 0.85, 0.3, 0.04 + fez_pulse * 0.03))

	# Ability 7: The Knocker flash — eerie green shockwave
	if _knocker_flash > 0.0:
		var kn_r = 30.0 + (1.0 - _knocker_flash) * 60.0
		draw_arc(Vector2.ZERO, kn_r, 0, TAU, 24, Color(0.2, 0.8, 0.3, _knocker_flash * 0.4), 3.0)
		draw_arc(Vector2.ZERO, kn_r * 0.6, 0, TAU, 16, Color(0.15, 0.6, 0.2, _knocker_flash * 0.3), 2.0)

	# Ability 8: Christmas Turkey flash — golden bounce rings
	if _turkey_flash > 0.0:
		for ti in range(5):
			var tr = 40.0 + float(ti) * 25.0 + (1.0 - _turkey_flash) * 40.0
			draw_arc(Vector2.ZERO, tr, 0, TAU, 24, Color(1.0, 0.8, 0.2, _turkey_flash * 0.2 * (1.0 - float(ti) * 0.15)), 2.0)

	# Ability 9: Scrooge's Redemption flash — gold explosion
	if _redemption_flash > 0.0:
		var red_r = 50.0 + (1.0 - _redemption_flash) * 100.0
		draw_circle(Vector2.ZERO, red_r * 0.5, Color(1.0, 0.85, 0.2, _redemption_flash * 0.15))
		draw_arc(Vector2.ZERO, red_r, 0, TAU, 32, Color(1.0, 0.9, 0.3, _redemption_flash * 0.4), 3.0)
		for ri in range(8):
			var ra = TAU * float(ri) / 8.0 + _redemption_flash * 2.0
			var r_inner = Vector2.from_angle(ra) * (red_r * 0.4)
			var r_outer = Vector2.from_angle(ra) * (red_r + 5.0)
			draw_line(r_inner, r_outer, Color(1.0, 0.95, 0.4, _redemption_flash * 0.35), 2.0)

	# === STONE PLATFORM ===
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
			0: pip_col = Color(0.85, 0.75, 0.2)
			1: pip_col = Color(0.4, 0.55, 0.85)
			2: pip_col = Color(0.3, 0.65, 0.3)
			3: pip_col = Color(0.25, 0.15, 0.3)
		draw_circle(pip_pos, 4.0, pip_col)
		draw_circle(pip_pos, 5.5, Color(pip_col.r, pip_col.g, pip_col.b, 0.15))

	# === T1+: GOLD COIN PILE at base of platform ===
	if upgrade_tier >= 1:
		var coin_base = Vector2(16, plat_y - 2) + body_offset * 0.15
		# Stack of gold coins
		for ci in range(5):
			var cx = coin_base.x - 6.0 + float(ci) * 3.0
			var cy = coin_base.y - float(ci) * 1.5
			draw_circle(Vector2(cx, cy), 3.5, Color(0.75, 0.6, 0.1))
			draw_circle(Vector2(cx, cy), 2.8, Color(0.9, 0.78, 0.2))
			# Coin highlight glint
			draw_circle(Vector2(cx - 0.5, cy - 0.8), 1.0, Color(1.0, 0.95, 0.5, 0.6))
		# Extra coins scattered
		draw_circle(Vector2(coin_base.x + 5, coin_base.y + 1), 2.5, Color(0.8, 0.65, 0.15))
		draw_circle(Vector2(coin_base.x - 8, coin_base.y + 2), 2.2, Color(0.85, 0.7, 0.18))
		# Animated glint on top coin
		var glint_alpha = (sin(_time * 4.0) + 1.0) * 0.3
		draw_circle(Vector2(coin_base.x, coin_base.y - 7), 2.0, Color(1.0, 1.0, 0.8, glint_alpha))

	# === T4: GHOST OF YET TO COME — dark hooded figure looming behind ===
	if upgrade_tier >= 4:
		var hood_bob = sin(_time * 1.2) * 3.0
		var dark_center = -dir * 38.0 + Vector2(0, -24.0 + hood_bob)
		# Ominous dark mist at base
		for i in range(6):
			var mist_a = _time * 0.4 + float(i) * TAU / 6.0
			var mist_r = 50.0 + sin(_time * 1.5 + float(i) * 2.0) * 10.0
			var mist_p = Vector2.from_angle(mist_a) * mist_r
			var mist_s = 12.0 + sin(_time * 2.0 + float(i)) * 4.0
			draw_circle(mist_p, mist_s, Color(0.02, 0.01, 0.04, 0.1 + sin(_time * 1.8 + float(i)) * 0.03))
		# Tall dark robe body — looming behind Scrooge
		var dark_robe = PackedVector2Array([
			dark_center + Vector2(-18, 30 + hood_bob),
			dark_center + Vector2(18, 30 + hood_bob),
			dark_center + Vector2(14, 5),
			dark_center + Vector2(10, -15),
			dark_center + Vector2(-10, -15),
			dark_center + Vector2(-14, 5),
		])
		draw_colored_polygon(dark_robe, Color(0.03, 0.02, 0.05, 0.5))
		# Inner darker shadow on robe
		var dark_inner = PackedVector2Array([
			dark_center + Vector2(-12, 26 + hood_bob),
			dark_center + Vector2(12, 26 + hood_bob),
			dark_center + Vector2(8, 2),
			dark_center + Vector2(-8, 2),
		])
		draw_colored_polygon(dark_inner, Color(0.01, 0.01, 0.02, 0.3))
		# Tattered hem wisps
		for i in range(5):
			var rag_x = -12.0 + float(i) * 6.0
			var rag_base = dark_center + Vector2(rag_x, 30 + hood_bob)
			var rag_end = rag_base + Vector2(sin(_time * 2.0 + float(i) * 1.3) * 4.0, 8.0 + sin(_time * 1.5 + float(i)) * 3.0)
			draw_line(rag_base, rag_end, Color(0.04, 0.03, 0.06, 0.3), 1.5)
		# Hood
		var hood_center = dark_center + Vector2(0, -18)
		draw_circle(hood_center, 14.0, Color(0.04, 0.02, 0.07, 0.55))
		draw_circle(hood_center + Vector2(0, 2), 11.0, Color(0.05, 0.03, 0.08, 0.5))
		# Void face
		draw_circle(hood_center + Vector2(0, 4), 8.0, Color(0.0, 0.0, 0.0, 0.7))
		# Faint red eyes
		var eye_flicker_t4 = 0.3 + sin(_time * 3.0) * 0.2
		draw_circle(hood_center + Vector2(-3, 3), 1.5, Color(0.8, 0.1, 0.05, eye_flicker_t4))
		draw_circle(hood_center + Vector2(3, 3), 1.5, Color(0.8, 0.1, 0.05, eye_flicker_t4))
		# Eye glow halo
		draw_circle(hood_center + Vector2(-3, 3), 3.5, Color(0.6, 0.05, 0.02, eye_flicker_t4 * 0.2))
		draw_circle(hood_center + Vector2(3, 3), 3.5, Color(0.6, 0.05, 0.02, eye_flicker_t4 * 0.2))
		# Bony skeletal hand pointing outward
		var point_hand = dark_center + Vector2(16, 0)
		draw_line(dark_center + Vector2(10, -4), point_hand, Color(0.5, 0.48, 0.42, 0.35), 2.0)
		draw_line(point_hand, point_hand + Vector2(6, -2), Color(0.55, 0.5, 0.45, 0.3), 1.5)
		draw_line(point_hand, point_hand + Vector2(7, 0), Color(0.55, 0.5, 0.45, 0.3), 1.2)
		draw_line(point_hand, point_hand + Vector2(5, 2), Color(0.55, 0.5, 0.45, 0.25), 1.0)
		# Chains (Marley's chains) floating around
		for i in range(6):
			var chain_a = TAU * float(i) / 6.0 + sin(_time * 2.5 + float(i)) * 0.3
			var chain_r = 62.0 + sin(_time * 3.0 + float(i) * 1.5) * 5.0
			var chain_p = Vector2.from_angle(chain_a) * chain_r
			draw_arc(chain_p, 5.0, 0, TAU, 8, Color(0.4, 0.4, 0.45, 0.35), 2.0)
			var link2 = chain_p + Vector2.from_angle(chain_a + 0.5) * 6.0
			draw_arc(link2, 3.5, 0, TAU, 6, Color(0.45, 0.45, 0.5, 0.3), 1.5)

	# === T3+: GHOST OF CHRISTMAS PRESENT — green jolly spirit (right side) ===
	if upgrade_tier >= 3:
		var green_bob = sin(_time * 1.8 + 2.0) * 5.0
		var green_center = perp * 32.0 + Vector2(0, -16 + green_bob)
		# Warm green aura
		draw_circle(green_center, 20.0, Color(0.25, 0.6, 0.15, 0.08))
		# Large flowing green robe body — chibi ghost shape
		var green_body = PackedVector2Array([
			green_center + Vector2(-12, 14),
			green_center + Vector2(12, 14),
			green_center + Vector2(10, 2),
			green_center + Vector2(8, -8),
			green_center + Vector2(-8, -8),
			green_center + Vector2(-10, 2),
		])
		draw_colored_polygon(green_body, Color(0.2, 0.55, 0.15, 0.22))
		# Inner lighter green
		var green_inner = PackedVector2Array([
			green_center + Vector2(-8, 12),
			green_center + Vector2(8, 12),
			green_center + Vector2(6, 0),
			green_center + Vector2(-6, 0),
		])
		draw_colored_polygon(green_inner, Color(0.3, 0.65, 0.25, 0.15))
		# Fur-trimmed edges
		for i in range(5):
			var fur_x = -10.0 + float(i) * 5.0
			var fur_p = green_center + Vector2(fur_x, 14)
			draw_circle(fur_p, 2.5, Color(0.65, 0.6, 0.5, 0.2))
		# Jovial round head
		var gh_head = green_center + Vector2(0, -12)
		draw_circle(gh_head, 9.0, Color(0.35, 0.7, 0.3, 0.25))
		draw_circle(gh_head, 7.0, Color(0.4, 0.75, 0.35, 0.2))
		# Holly wreath crown
		draw_arc(gh_head, 10.0, 0, TAU, 14, Color(0.2, 0.5, 0.15, 0.22), 2.0)
		# Holly berries
		for i in range(4):
			var berry_a = TAU * float(i) / 4.0 + 0.3
			var berry_p = gh_head + Vector2.from_angle(berry_a) * 10.0
			draw_circle(berry_p, 1.5, Color(0.8, 0.15, 0.1, 0.3))
		# Cheerful face dots
		draw_circle(gh_head + Vector2(-3, -1), 1.2, Color(0.1, 0.3, 0.05, 0.3))
		draw_circle(gh_head + Vector2(3, -1), 1.2, Color(0.1, 0.3, 0.05, 0.3))
		# Jovial grin
		draw_arc(gh_head + Vector2(0, 2), 3.5, 0.2, PI - 0.2, 8, Color(0.15, 0.35, 0.1, 0.25), 1.5)
		# Gold abundance sparkles
		for i in range(6):
			var spark_a = _time * 1.5 + float(i) * TAU / 6.0
			var spark_r = 22.0 + sin(_time * 3.0 + float(i)) * 6.0
			var spark_pos = green_center + Vector2.from_angle(spark_a) * spark_r
			var spark_alpha = 0.3 + sin(_time * 5.0 + float(i) * 2.0) * 0.2
			draw_circle(spark_pos, 2.0 + sin(_time * 4.0 + float(i)) * 1.0, Color(1.0, 0.85, 0.2, spark_alpha))

	# === T2+: GHOST OF CHRISTMAS PAST — blue-white ethereal spirit (left side) ===
	if upgrade_tier >= 2:
		var blue_bob = sin(_time * 1.5) * 4.0
		var blue_center = -perp * 30.0 + Vector2(0, -18 + blue_bob)
		# Ethereal blue-white aura
		draw_circle(blue_center, 18.0, Color(0.35, 0.45, 0.85, 0.07))
		draw_circle(blue_center, 12.0, Color(0.5, 0.6, 0.95, 0.05))
		# Translucent wispy body — chibi ghost shape
		var blue_body = PackedVector2Array([
			blue_center + Vector2(-9, 12),
			blue_center + Vector2(9, 12),
			blue_center + Vector2(7, 0),
			blue_center + Vector2(6, -8),
			blue_center + Vector2(-6, -8),
			blue_center + Vector2(-7, 0),
		])
		draw_colored_polygon(blue_body, Color(0.5, 0.6, 0.9, 0.15))
		# Inner shimmer
		var blue_inner = PackedVector2Array([
			blue_center + Vector2(-6, 10),
			blue_center + Vector2(6, 10),
			blue_center + Vector2(4, -2),
			blue_center + Vector2(-4, -2),
		])
		draw_colored_polygon(blue_inner, Color(0.6, 0.7, 1.0, 0.1))
		# Wispy tail at bottom (ghostly dissipation)
		for i in range(3):
			var wisp_x = -5.0 + float(i) * 5.0
			var wisp_base = blue_center + Vector2(wisp_x, 12)
			var wisp_end = wisp_base + Vector2(sin(_time * 2.5 + float(i)) * 3.0, 6.0 + sin(_time * 1.8 + float(i)) * 2.0)
			draw_line(wisp_base, wisp_end, Color(0.5, 0.6, 0.9, 0.12), 2.0)
		# Small round head
		var bh_head = blue_center + Vector2(0, -11)
		draw_circle(bh_head, 7.0, Color(0.55, 0.65, 0.95, 0.2))
		draw_circle(bh_head, 5.5, Color(0.65, 0.75, 1.0, 0.15))
		# Gentle eyes
		draw_circle(bh_head + Vector2(-2.5, -1), 1.0, Color(0.3, 0.4, 0.8, 0.3))
		draw_circle(bh_head + Vector2(2.5, -1), 1.0, Color(0.3, 0.4, 0.8, 0.3))
		# Candle-like glow on top of head (spirit's flame)
		var flame_bob = sin(_time * 6.0) * 1.5
		draw_circle(bh_head + Vector2(0, -8 + flame_bob), 3.0, Color(0.7, 0.8, 1.0, 0.2))
		draw_circle(bh_head + Vector2(0, -9 + flame_bob), 2.0, Color(0.85, 0.9, 1.0, 0.3))
		# Ethereal light rays from spirit
		for i in range(4):
			var ray_a = TAU * float(i) / 4.0 + _time * 0.5
			var ray_start = blue_center + Vector2.from_angle(ray_a) * 8.0
			var ray_end = blue_center + Vector2.from_angle(ray_a) * 16.0
			draw_line(ray_start, ray_end, Color(0.5, 0.6, 0.95, 0.1), 1.0)

	# === CHARACTER POSITIONS (taller anime proportions ~56px) ===
	var feet_y = body_offset + Vector2(0, 14.0)
	var leg_top = body_offset + Vector2(hunch_rock * 0.3, -2.0)
	var torso_center = body_offset + Vector2(hunch_rock * 0.6, -10.0 + hunch_rock * 0.3)
	var neck_base = body_offset + Vector2(hunch_rock * 0.8, -20.0 + hunch_rock * 0.5)
	var head_center = body_offset + Vector2(hunch_rock * 1.0, -32.0 + hunch_rock * 0.7)

	# === POLISHED OXFORDS (black patent leather) ===
	var l_foot = feet_y + Vector2(-7, 0)
	var r_foot = feet_y + Vector2(7, 0)
	# Shoe soles
	draw_circle(l_foot + Vector2(0, 1.5), 5.0, Color(0.02, 0.02, 0.02))
	draw_circle(r_foot + Vector2(0, 1.5), 5.0, Color(0.02, 0.02, 0.02))
	# Shoe base (polished black)
	draw_circle(l_foot, 5.0, Color(0.04, 0.04, 0.04))
	draw_circle(l_foot, 3.8, Color(0.10, 0.10, 0.10))
	draw_circle(r_foot, 5.0, Color(0.04, 0.04, 0.04))
	draw_circle(r_foot, 3.8, Color(0.10, 0.10, 0.10))
	# Patent leather shine
	draw_circle(l_foot + Vector2(1, -1.5), 2.0, Color(0.30, 0.30, 0.35, 0.5))
	draw_circle(r_foot + Vector2(-1, -1.5), 2.0, Color(0.30, 0.30, 0.35, 0.5))
	# Pointed toe detail
	draw_circle(l_foot + Vector2(2, 0.5), 1.2, Color(0.25, 0.25, 0.30, 0.35))
	draw_circle(r_foot + Vector2(-2, 0.5), 1.2, Color(0.25, 0.25, 0.30, 0.35))
	# Heel detail
	draw_line(l_foot + Vector2(-2, 1), l_foot + Vector2(-2, 3), Color(0.06, 0.06, 0.06), 2.0)
	draw_line(r_foot + Vector2(2, 1), r_foot + Vector2(2, 3), Color(0.06, 0.06, 0.06), 2.0)

	# === VICTORIAN TROUSERS (dark charcoal, slightly wider than bony legs) ===
	var l_knee = feet_y + Vector2(-5, -8)
	var r_knee = feet_y + Vector2(5, -8)
	var l_hip = leg_top + Vector2(-6, 0)
	var r_hip = leg_top + Vector2(6, 0)
	var l_ankle = l_foot + Vector2(0, -3)
	var r_ankle = r_foot + Vector2(0, -3)
	var trouser_col = Color(0.08, 0.06, 0.10)
	var trouser_hi = Color(0.12, 0.10, 0.14)
	# LEFT THIGH — charcoal trouser
	draw_colored_polygon(PackedVector2Array([
		l_hip + Vector2(3, 0), l_hip + Vector2(-4, 0),
		l_hip.lerp(l_knee, 0.5) + Vector2(-4.5, 0),
		l_knee + Vector2(-4, 0), l_knee + Vector2(3, 0),
		l_hip.lerp(l_knee, 0.5) + Vector2(3.5, 0),
	]), Color(0.05, 0.04, 0.07))
	draw_colored_polygon(PackedVector2Array([
		l_hip + Vector2(2, 0), l_hip + Vector2(-3, 0),
		l_knee + Vector2(-3, 0), l_knee + Vector2(2, 0),
	]), trouser_col)
	# RIGHT THIGH
	draw_colored_polygon(PackedVector2Array([
		r_hip + Vector2(-3, 0), r_hip + Vector2(4, 0),
		r_hip.lerp(r_knee, 0.5) + Vector2(4.5, 0),
		r_knee + Vector2(4, 0), r_knee + Vector2(-3, 0),
		r_hip.lerp(r_knee, 0.5) + Vector2(-3.5, 0),
	]), Color(0.05, 0.04, 0.07))
	draw_colored_polygon(PackedVector2Array([
		r_hip + Vector2(-2, 0), r_hip + Vector2(3, 0),
		r_knee + Vector2(3, 0), r_knee + Vector2(-2, 0),
	]), trouser_col)
	# Knee joints
	draw_circle(l_knee, 4.5, Color(0.05, 0.04, 0.07))
	draw_circle(l_knee, 3.5, trouser_col)
	draw_circle(r_knee, 4.5, Color(0.05, 0.04, 0.07))
	draw_circle(r_knee, 3.5, trouser_col)
	# LEFT CALF — trouser leg
	draw_colored_polygon(PackedVector2Array([
		l_knee + Vector2(-4, 0), l_knee + Vector2(3, 0),
		l_ankle + Vector2(2, 0), l_ankle + Vector2(-2, 0),
		l_knee.lerp(l_ankle, 0.4) + Vector2(-4.5, 0),
	]), Color(0.05, 0.04, 0.07))
	draw_colored_polygon(PackedVector2Array([
		l_knee + Vector2(-3, 0), l_knee + Vector2(2, 0),
		l_ankle + Vector2(1.2, 0), l_ankle + Vector2(-1.2, 0),
	]), trouser_col)
	# Sharp crease line (pressed trousers)
	draw_line(l_hip + Vector2(0, 0), l_ankle + Vector2(0, 0), Color(0.15, 0.12, 0.18, 0.25), 0.8)
	# RIGHT CALF
	draw_colored_polygon(PackedVector2Array([
		r_knee + Vector2(4, 0), r_knee + Vector2(-3, 0),
		r_ankle + Vector2(-2, 0), r_ankle + Vector2(2, 0),
		r_knee.lerp(r_ankle, 0.4) + Vector2(4.5, 0),
	]), Color(0.05, 0.04, 0.07))
	draw_colored_polygon(PackedVector2Array([
		r_knee + Vector2(3, 0), r_knee + Vector2(-2, 0),
		r_ankle + Vector2(-1.2, 0), r_ankle + Vector2(1.2, 0),
	]), trouser_col)
	# Sharp crease line (pressed trousers)
	draw_line(r_hip + Vector2(0, 0), r_ankle + Vector2(0, 0), Color(0.15, 0.12, 0.18, 0.25), 0.8)

	# === DARK CHARCOAL TAILCOAT ENSEMBLE (Victorian businessman) ===
	var coat_col = Color(0.08, 0.06, 0.10)
	var coat_hi = Color(0.12, 0.10, 0.14)
	var waistcoat_col = Color(0.45, 0.15, 0.12)
	var waistcoat_hi = Color(0.55, 0.22, 0.18)

	# --- COAT TAILS (two long tails from waist toward feet, behind legs) ---
	var tail_sway = sin(_time * 1.5) * 2.0
	# Left tail
	var l_tail = PackedVector2Array([
		torso_center + Vector2(-8, 4),
		torso_center + Vector2(-4, 4),
		leg_top + Vector2(-3, 16 + tail_sway),
		leg_top + Vector2(-10, 18 + tail_sway * 0.7),
	])
	draw_colored_polygon(l_tail, coat_col)
	draw_line(torso_center + Vector2(-6, 5), leg_top + Vector2(-6, 16 + tail_sway * 0.8), Color(0.14, 0.11, 0.18, 0.3), 1.0)
	# Right tail
	var r_tail = PackedVector2Array([
		torso_center + Vector2(4, 4),
		torso_center + Vector2(8, 4),
		leg_top + Vector2(10, 18 - tail_sway * 0.7),
		leg_top + Vector2(3, 16 - tail_sway),
	])
	draw_colored_polygon(r_tail, coat_col)
	draw_line(torso_center + Vector2(6, 5), leg_top + Vector2(6, 16 - tail_sway * 0.8), Color(0.14, 0.11, 0.18, 0.3), 1.0)

	# --- TAILCOAT BODY (shoulders to waist) ---
	var coat_pts = PackedVector2Array([
		torso_center + Vector2(-9, 6),     # waist left
		torso_center + Vector2(-10, 0),
		neck_base + Vector2(-13, 2),       # shoulder left
		neck_base + Vector2(13, 2),        # shoulder right
		torso_center + Vector2(10, 0),
		torso_center + Vector2(9, 6),      # waist right
	])
	draw_colored_polygon(coat_pts, coat_col)
	# Coat side shadow
	var coat_shadow_l = PackedVector2Array([
		torso_center + Vector2(-9, 6),
		torso_center + Vector2(-10, 0),
		neck_base + Vector2(-13, 2),
		neck_base + Vector2(-8, 2),
		torso_center + Vector2(-6, 4),
	])
	draw_colored_polygon(coat_shadow_l, Color(0.04, 0.03, 0.06, 0.3))

	# --- WHITE DRESS SHIRT (visible strip at chest) ---
	var shirt_pts = PackedVector2Array([
		neck_base + Vector2(-5, 3),
		neck_base + Vector2(5, 3),
		torso_center + Vector2(5, 4),
		torso_center + Vector2(-5, 4),
	])
	draw_colored_polygon(shirt_pts, Color(0.95, 0.93, 0.91))
	# Shirt pleat lines
	draw_line(neck_base + Vector2(-2, 3), torso_center + Vector2(-2, 3), Color(0.88, 0.86, 0.84, 0.3), 0.7)
	draw_line(neck_base + Vector2(2, 3), torso_center + Vector2(2, 3), Color(0.88, 0.86, 0.84, 0.3), 0.7)

	# --- BURGUNDY WAISTCOAT (over shirt, under coat) ---
	var vest_pts = PackedVector2Array([
		neck_base + Vector2(-6, 3),
		neck_base + Vector2(6, 3),
		torso_center + Vector2(7, 5),
		torso_center + Vector2(-7, 5),
	])
	draw_colored_polygon(vest_pts, waistcoat_col)
	# Waistcoat highlight
	draw_colored_polygon(PackedVector2Array([
		neck_base + Vector2(-3, 4),
		neck_base + Vector2(3, 4),
		torso_center + Vector2(4, 4),
		torso_center + Vector2(-4, 4),
	]), Color(waistcoat_hi.r, waistcoat_hi.g, waistcoat_hi.b, 0.3))
	# Gold buttons on waistcoat
	for bi in range(4):
		var by = neck_base.y + 5.0 + float(bi) * 4.0
		draw_circle(Vector2(torso_center.x, by), 1.2, Color(0.85, 0.72, 0.2))
		draw_circle(Vector2(torso_center.x - 0.3, by - 0.3), 0.5, Color(1.0, 0.9, 0.5, 0.5))
	# Gold pocket watch chain (draped across waistcoat)
	var chain_start = Vector2(torso_center.x - 4, neck_base.y + 10)
	var chain_mid = Vector2(torso_center.x, neck_base.y + 13)
	var chain_end = Vector2(torso_center.x + 4, neck_base.y + 10)
	draw_line(chain_start, chain_mid, Color(0.85, 0.72, 0.2, 0.6), 1.0)
	draw_line(chain_mid, chain_end, Color(0.85, 0.72, 0.2, 0.6), 1.0)
	# Watch fob at lowest point
	draw_circle(chain_mid, 1.5, Color(0.85, 0.72, 0.2, 0.5))

	# --- PEAKED LAPELS (coat collar) ---
	# Left lapel
	var lapel_l = PackedVector2Array([
		neck_base + Vector2(-12, 1),
		neck_base + Vector2(-5, 3),
		torso_center + Vector2(-5, -1),
		torso_center + Vector2(-8, -1),
		neck_base + Vector2(-13, 4),
	])
	draw_colored_polygon(lapel_l, Color(0.10, 0.08, 0.12))
	draw_line(neck_base + Vector2(-12, 1), neck_base + Vector2(-14, -1), Color(0.14, 0.11, 0.18, 0.4), 1.0)
	# Right lapel
	var lapel_r = PackedVector2Array([
		neck_base + Vector2(5, 3),
		neck_base + Vector2(12, 1),
		neck_base + Vector2(13, 4),
		torso_center + Vector2(8, -1),
		torso_center + Vector2(5, -1),
	])
	draw_colored_polygon(lapel_r, Color(0.10, 0.08, 0.12))
	draw_line(neck_base + Vector2(12, 1), neck_base + Vector2(14, -1), Color(0.14, 0.11, 0.18, 0.4), 1.0)

	# --- DARK CRAVAT/ASCOT at neck ---
	var cravat_pos = neck_base + Vector2(0, 3)
	draw_colored_polygon(PackedVector2Array([
		cravat_pos + Vector2(-3, -1),
		cravat_pos + Vector2(3, -1),
		cravat_pos + Vector2(2, 4),
		cravat_pos + Vector2(0, 5),
		cravat_pos + Vector2(-2, 4),
	]), Color(0.15, 0.12, 0.18))
	# Cravat folds
	draw_line(cravat_pos + Vector2(-1, 0), cravat_pos + Vector2(-1, 3), Color(0.22, 0.18, 0.25, 0.4), 0.8)
	draw_line(cravat_pos + Vector2(1, 0), cravat_pos + Vector2(1, 3), Color(0.22, 0.18, 0.25, 0.4), 0.8)
	# Gold cravat pin
	draw_circle(cravat_pos + Vector2(0, 1), 1.2, Color(0.85, 0.72, 0.2))
	draw_circle(cravat_pos + Vector2(-0.3, 0.7), 0.5, Color(1.0, 0.9, 0.5, 0.5))
	# High starched collar points
	draw_line(neck_base + Vector2(-6, 1), neck_base + Vector2(-4, -2), Color(0.92, 0.90, 0.88), 2.0)
	draw_line(neck_base + Vector2(6, 1), neck_base + Vector2(4, -2), Color(0.92, 0.90, 0.88), 2.0)

	# === NON-WEAPON ARM (left side — tailcoat sleeve, holds cane) ===
	var off_arm_shoulder = neck_base + Vector2(-13, 2)
	var off_arm_elbow = torso_center + Vector2(-17, 4)
	var off_arm_hand = torso_center + Vector2(-11, 10)
	# LEFT UPPER ARM — dark charcoal tailcoat sleeve
	var l_ua_dir = (off_arm_elbow - off_arm_shoulder).normalized()
	var l_ua_perp = l_ua_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		off_arm_shoulder + l_ua_perp * 4.0, off_arm_shoulder - l_ua_perp * 3.5,
		off_arm_shoulder.lerp(off_arm_elbow, 0.5) - l_ua_perp * 3.8,
		off_arm_elbow - l_ua_perp * 3.0, off_arm_elbow + l_ua_perp * 3.0,
		off_arm_shoulder.lerp(off_arm_elbow, 0.5) + l_ua_perp * 3.5,
	]), Color(0.06, 0.04, 0.08))
	draw_colored_polygon(PackedVector2Array([
		off_arm_shoulder + l_ua_perp * 3.0, off_arm_shoulder - l_ua_perp * 2.5,
		off_arm_elbow - l_ua_perp * 2.0, off_arm_elbow + l_ua_perp * 2.0,
	]), coat_col)
	# LEFT FOREARM — tailcoat sleeve
	var l_fa_dir = (off_arm_hand - off_arm_elbow).normalized()
	var l_fa_perp = l_fa_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		off_arm_elbow + l_fa_perp * 3.0, off_arm_elbow - l_fa_perp * 3.0,
		off_arm_hand - l_fa_perp * 2.0, off_arm_hand + l_fa_perp * 2.0,
	]), Color(0.06, 0.04, 0.08))
	draw_colored_polygon(PackedVector2Array([
		off_arm_elbow + l_fa_perp * 2.0, off_arm_elbow - l_fa_perp * 2.0,
		off_arm_hand - l_fa_perp * 1.2, off_arm_hand + l_fa_perp * 1.2,
	]), coat_col)
	# Elbow joint
	draw_circle(off_arm_elbow, 3.5, Color(0.06, 0.04, 0.08))
	draw_circle(off_arm_elbow, 2.5, coat_col)
	# White shirt cuff at wrist
	draw_arc(off_arm_hand + Vector2(0, -2), 3.0, 0, TAU, 8, Color(0.95, 0.93, 0.91), 2.0)
	# Bony elderly hand (kept — fits character)
	draw_circle(off_arm_hand, 3.5, skin_base)
	draw_circle(off_arm_hand, 2.5, skin_highlight)
	# Thin bony fingers gripping cane
	draw_line(off_arm_hand, off_arm_hand + Vector2(-2, 3), skin_shadow, 1.5)
	draw_line(off_arm_hand, off_arm_hand + Vector2(0, 4), skin_shadow, 1.5)
	draw_line(off_arm_hand, off_arm_hand + Vector2(2, 3), skin_shadow, 1.2)
	# Knuckle detail
	draw_circle(off_arm_hand + Vector2(-1, 1), 1.0, skin_shadow)
	draw_circle(off_arm_hand + Vector2(1, 1), 1.0, skin_shadow)

	# === WALKING CANE (from left hand to ground) ===
	var cane_top = off_arm_hand + Vector2(0, 2)
	var cane_bottom = Vector2(off_arm_hand.x - 2, feet_y.y + 2)
	# Dark ebony shaft
	draw_line(cane_top, cane_bottom, Color(0.08, 0.06, 0.04), 2.5)
	draw_line(cane_top + Vector2(0.5, 0), cane_bottom + Vector2(0.5, 0), Color(0.15, 0.12, 0.10, 0.4), 1.0)
	# Gold crook handle at top
	draw_arc(cane_top + Vector2(3, -2), 4.0, PI * 0.5, PI * 1.5, 8, Color(0.85, 0.72, 0.2), 2.5)
	draw_arc(cane_top + Vector2(3, -2), 3.0, PI * 0.5, PI * 1.5, 8, Color(0.95, 0.82, 0.3, 0.5), 1.5)
	# Metal ferrule at tip
	draw_circle(cane_bottom, 1.5, Color(0.5, 0.48, 0.45))
	draw_circle(cane_bottom + Vector2(-0.3, -0.3), 0.7, Color(0.7, 0.68, 0.65, 0.4))

	# === WEAPON ARM (right side — tailcoat sleeve, holds bell) ===
	var weapon_shoulder = neck_base + Vector2(13, 2)
	var attack_recoil = _attack_anim * 4.0
	var weapon_extend = dir * (16.0 + attack_recoil) + body_offset
	var weapon_elbow = weapon_shoulder + (weapon_extend - weapon_shoulder) * 0.5 + Vector2(0, 3)
	var weapon_hand = weapon_shoulder + (weapon_extend - weapon_shoulder) * 0.85
	# RIGHT UPPER ARM — dark charcoal tailcoat sleeve
	var r_ua_dir = (weapon_elbow - weapon_shoulder).normalized()
	var r_ua_perp = r_ua_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		weapon_shoulder + r_ua_perp * 4.0, weapon_shoulder - r_ua_perp * 3.5,
		weapon_shoulder.lerp(weapon_elbow, 0.5) - r_ua_perp * 3.8,
		weapon_elbow - r_ua_perp * 3.0, weapon_elbow + r_ua_perp * 3.0,
		weapon_shoulder.lerp(weapon_elbow, 0.5) + r_ua_perp * 3.5,
	]), Color(0.06, 0.04, 0.08))
	draw_colored_polygon(PackedVector2Array([
		weapon_shoulder + r_ua_perp * 3.0, weapon_shoulder - r_ua_perp * 2.5,
		weapon_elbow - r_ua_perp * 2.0, weapon_elbow + r_ua_perp * 2.0,
	]), coat_col)
	# RIGHT FOREARM — tailcoat sleeve
	var r_fa_dir = (weapon_hand - weapon_elbow).normalized()
	var r_fa_perp = r_fa_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		weapon_elbow + r_fa_perp * 3.0, weapon_elbow - r_fa_perp * 3.0,
		weapon_hand - r_fa_perp * 2.0, weapon_hand + r_fa_perp * 2.0,
	]), Color(0.06, 0.04, 0.08))
	draw_colored_polygon(PackedVector2Array([
		weapon_elbow + r_fa_perp * 2.0, weapon_elbow - r_fa_perp * 2.0,
		weapon_hand - r_fa_perp * 1.2, weapon_hand + r_fa_perp * 1.2,
	]), coat_col)
	# Elbow joint
	draw_circle(weapon_elbow, 3.5, Color(0.06, 0.04, 0.08))
	draw_circle(weapon_elbow, 2.5, coat_col)
	# White shirt cuff at wrist
	draw_arc(weapon_hand + Vector2(0, -2), 3.0, 0, TAU, 8, Color(0.95, 0.93, 0.91), 2.0)
	# Bony hand (kept — fits elderly character)
	draw_circle(weapon_hand, 3.5, skin_base)
	draw_circle(weapon_hand, 2.5, skin_highlight)

	# === BELL (weapon) ===
	var bell_base = weapon_hand + dir * 4.0
	var bell_top = bell_base + Vector2(0, -20)
	# Bell body — brass bell shape (wider at bottom, narrow at top)
	var bell_perp_v = dir.rotated(PI / 2.0)
	# Bell dome (arc shape)
	draw_arc(bell_base + Vector2(0, -8), 8.0, PI * 0.15, PI * 0.85, 16, Color(0.65, 0.5, 0.15), 2.5)
	draw_arc(bell_base + Vector2(0, -8), 7.0, PI * 0.1, PI * 0.9, 16, Color(0.85, 0.7, 0.25), 2.0)
	# Bell body (trapezoid — wider at bottom rim, narrow at top)
	draw_colored_polygon(PackedVector2Array([
		bell_base + Vector2(-8, -2),   # bottom left (wide rim)
		bell_base + Vector2(8, -2),    # bottom right
		bell_base + Vector2(5, -14),   # top right (narrower)
		bell_base + Vector2(-5, -14),  # top left
	]), Color(0.75, 0.6, 0.2))
	# Inner bell fill (lighter)
	draw_colored_polygon(PackedVector2Array([
		bell_base + Vector2(-6, -3),
		bell_base + Vector2(6, -3),
		bell_base + Vector2(4, -12),
		bell_base + Vector2(-4, -12),
	]), Color(0.85, 0.72, 0.3))
	# Bell rim (thick bottom edge)
	draw_line(bell_base + Vector2(-8, -2), bell_base + Vector2(8, -2), Color(0.65, 0.5, 0.15), 3.0)
	draw_line(bell_base + Vector2(-7, -2), bell_base + Vector2(7, -2), Color(0.9, 0.78, 0.3), 2.0)
	# Bell highlight
	draw_line(bell_base + Vector2(-3, -12), bell_base + Vector2(-2, -4), Color(0.95, 0.85, 0.4, 0.5), 1.5)
	# Handle on top (small loop)
	draw_arc(bell_top + Vector2(0, 2), 3.5, PI, TAU, 10, Color(0.65, 0.5, 0.15), 2.5)
	draw_arc(bell_top + Vector2(0, 2), 2.5, PI, TAU, 8, Color(0.85, 0.7, 0.25), 1.5)
	# Clapper (hanging inside bell)
	var clapper_swing = sin(_time * 5.0 + _attack_anim * 8.0) * 3.0
	var clapper_pos = bell_base + Vector2(clapper_swing, -1)
	draw_line(bell_base + Vector2(0, -8), clapper_pos, Color(0.5, 0.4, 0.15), 1.5)
	draw_circle(clapper_pos, 2.5, Color(0.6, 0.48, 0.18))
	draw_circle(clapper_pos, 1.8, Color(0.75, 0.6, 0.25))

	# === ATTACK FLASH — bell ring shockwave ===
	if _attack_anim > 0.2:
		var ring_alpha = _attack_anim * 0.5
		var ring_r = 15.0 + (1.0 - _attack_anim) * 50.0
		# Expanding shockwave ring (golden sound wave)
		draw_arc(Vector2.ZERO, ring_r, 0, TAU, 32, Color(0.9, 0.78, 0.2, ring_alpha), 3.0)
		draw_arc(Vector2.ZERO, ring_r * 0.75, 0, TAU, 24, Color(1.0, 0.9, 0.4, ring_alpha * 0.5), 2.0)
		draw_arc(Vector2.ZERO, ring_r * 0.5, 0, TAU, 16, Color(1.0, 0.95, 0.6, ring_alpha * 0.3), 1.5)
		# Sound wave arc lines radiating out
		for i in range(6):
			var wave_a = TAU * float(i) / 6.0 + _time * 3.0
			var wave_inner = ring_r * 0.8
			var wave_outer = ring_r * 1.1
			draw_arc(Vector2.from_angle(wave_a) * wave_inner * 0.15, wave_inner * 0.3, wave_a - 0.3, wave_a + 0.3, 6, Color(0.9, 0.8, 0.3, ring_alpha * 0.4), 1.5)

	# === THIN NECK (elderly polygon neck with Adam's apple) ===
	var neck_top = head_center + Vector2(0, 8)
	var neck_dir_v = (neck_top - neck_base).normalized()
	var neck_perp_v = neck_dir_v.rotated(PI / 2.0)
	# Thin neck polygon (narrower than young characters)
	draw_colored_polygon(PackedVector2Array([
		neck_base + neck_perp_v * 4.5, neck_base - neck_perp_v * 4.5,
		neck_base.lerp(neck_top, 0.5) - neck_perp_v * 3.5,
		neck_top - neck_perp_v * 3.0, neck_top + neck_perp_v * 3.0,
		neck_base.lerp(neck_top, 0.5) + neck_perp_v * 3.5,
	]), skin_shadow)
	draw_colored_polygon(PackedVector2Array([
		neck_base + neck_perp_v * 3.5, neck_base - neck_perp_v * 3.5,
		neck_top - neck_perp_v * 2.2, neck_top + neck_perp_v * 2.2,
	]), skin_base)
	# Neck highlight
	draw_line(neck_base.lerp(neck_top, 0.15) + neck_perp_v * 2.0, neck_base.lerp(neck_top, 0.85) + neck_perp_v * 1.5, skin_highlight, 1.2)
	# Adam's apple — prominent on thin neck
	var adams_y = neck_base.lerp(neck_top, 0.4)
	draw_circle(adams_y + neck_perp_v * 1.5, 2.0, skin_shadow)
	draw_circle(adams_y + neck_perp_v * 1.5, 1.2, skin_base)
	# Neck tendon lines (visible on elderly thin neck)
	draw_line(neck_base + neck_perp_v * 2.5, neck_top - neck_perp_v * 0.5, Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.15), 0.8)
	draw_line(neck_base - neck_perp_v * 2.5, neck_top + neck_perp_v * 0.5, Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.15), 0.8)

	# === HEAD (angular elderly, defined jawline) ===
	# Head shape — slightly elongated, angular
	draw_circle(head_center, 12.0, Color(0.06, 0.05, 0.04))  # Outline
	draw_circle(head_center, 11.0, skin_shadow)
	draw_circle(head_center, 10.0, skin_base)
	# Highlight on forehead
	draw_circle(head_center + Vector2(-1.5, -3), 4.5, Color(skin_highlight.r, skin_highlight.g, skin_highlight.b, 0.4))
	# Strong jawline — angular, gaunt
	draw_line(head_center + Vector2(-9, 2), head_center + Vector2(-4, 10), Color(0.60, 0.52, 0.45, 0.35), 1.3)
	draw_line(head_center + Vector2(9, 2), head_center + Vector2(4, 10), Color(0.60, 0.52, 0.45, 0.35), 1.3)
	# Prominent chin (angular, pointed)
	var chin_tip = head_center + Vector2(0, 10)
	draw_circle(chin_tip, 3.0, skin_base)
	draw_circle(chin_tip + Vector2(0, 0.5), 2.2, skin_shadow)
	draw_circle(chin_tip + Vector2(-0.5, -0.5), 1.5, skin_highlight)
	# Chin bottom line
	draw_line(head_center + Vector2(-4, 10), head_center + Vector2(4, 10), Color(0.60, 0.52, 0.45, 0.2), 1.0)

	# === BALDING HEAD WITH WISPS OF WHITE HAIR ===
	# Bald dome on top — slightly shinier skin tone
	draw_circle(head_center + Vector2(0, -4), 6.0, Color(0.88, 0.82, 0.76, 0.5))
	# Shine on bald head
	draw_circle(head_center + Vector2(-1.5, -6), 3.0, Color(1.0, 0.96, 0.90, 0.3))
	draw_circle(head_center + Vector2(-2, -7), 1.5, Color(1.0, 0.98, 0.95, 0.4))
	# Thin white hair wisps on sides
	# Left side wisps
	for i in range(3):
		var wisp_start = head_center + Vector2(-10, -3 + float(i) * 2.5)
		var wisp_end = wisp_start + Vector2(-3.0 + sin(_time * 1.5 + float(i)) * 1.2, 2.5 + float(i) * 0.5)
		draw_line(wisp_start, wisp_end, Color(0.92, 0.90, 0.88, 0.6), 1.2)
	# Right side wisps
	for i in range(3):
		var wisp_start = head_center + Vector2(10, -3 + float(i) * 2.5)
		var wisp_end = wisp_start + Vector2(3.0 + sin(_time * 1.5 + float(i) + 1.0) * 1.2, 2.5 + float(i) * 0.5)
		draw_line(wisp_start, wisp_end, Color(0.92, 0.90, 0.88, 0.6), 1.2)
	# Tuft at back
	for i in range(3):
		var tuft_start = head_center + Vector2(-2.5 + float(i) * 2.5, -10)
		var tuft_end = tuft_start + Vector2(sin(_time * 1.0 + float(i)) * 1.5, -3.0)
		draw_line(tuft_start, tuft_end, Color(0.92, 0.90, 0.88, 0.4), 1.0)

	# === VICTORIAN TOP HAT (tall, dark, dignified) ===
	var hat_base_y = head_center.y - 8
	var hat_center_x = head_center.x
	# Wide dark brim (~22px wide)
	draw_set_transform(Vector2(hat_center_x, hat_base_y), 0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, 14.0, Color(0.04, 0.03, 0.05))
	draw_circle(Vector2.ZERO, 12.0, Color(0.08, 0.06, 0.10))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# Brim highlight
	draw_set_transform(Vector2(hat_center_x, hat_base_y + 1), 0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, 11.0, Color(0.12, 0.10, 0.14, 0.3))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# Tall crown (~20px high, ~14px wide)
	var crown_bottom = hat_base_y
	var crown_top = hat_base_y - 20
	draw_colored_polygon(PackedVector2Array([
		Vector2(hat_center_x - 7, crown_bottom),
		Vector2(hat_center_x - 7, crown_top + 3),
		Vector2(hat_center_x - 6, crown_top),
		Vector2(hat_center_x + 6, crown_top),
		Vector2(hat_center_x + 7, crown_top + 3),
		Vector2(hat_center_x + 7, crown_bottom),
	]), Color(0.06, 0.04, 0.08))
	# Crown inner highlight
	draw_colored_polygon(PackedVector2Array([
		Vector2(hat_center_x - 5, crown_bottom - 1),
		Vector2(hat_center_x - 5, crown_top + 2),
		Vector2(hat_center_x + 2, crown_top + 2),
		Vector2(hat_center_x + 2, crown_bottom - 1),
	]), Color(0.10, 0.08, 0.12, 0.3))
	# Hat band
	draw_line(Vector2(hat_center_x - 7, crown_bottom - 1), Vector2(hat_center_x + 7, crown_bottom - 1), Color(0.15, 0.12, 0.18), 2.5)
	draw_line(Vector2(hat_center_x - 6, crown_bottom - 1), Vector2(hat_center_x + 6, crown_bottom - 1), Color(0.20, 0.16, 0.22), 1.5)
	# Subtle buckle on hat band
	draw_rect(Rect2(Vector2(hat_center_x - 2, crown_bottom - 2.5), Vector2(4, 3)), Color(0.75, 0.62, 0.18, 0.5), false, 1.0)
	draw_rect(Rect2(Vector2(hat_center_x - 1, crown_bottom - 2), Vector2(2, 2)), Color(0.85, 0.72, 0.2, 0.3), true)
	# Silk sheen highlight (diagonal across crown)
	draw_line(Vector2(hat_center_x - 4, crown_top + 4), Vector2(hat_center_x + 2, crown_bottom - 3), Color(0.18, 0.15, 0.22, 0.25), 1.5)
	draw_line(Vector2(hat_center_x - 3, crown_top + 3), Vector2(hat_center_x + 1, crown_top + 8), Color(0.22, 0.18, 0.26, 0.2), 1.0)
	# Crown top (flat ellipse)
	draw_set_transform(Vector2(hat_center_x, crown_top), 0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, 7.0, Color(0.08, 0.06, 0.10))
	draw_circle(Vector2.ZERO, 5.0, Color(0.10, 0.08, 0.12, 0.5))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	# === ROUND SPECTACLES (scaled for smaller head) ===
	var glasses_y = head_center.y + 1
	var glasses_bridge = head_center.x
	var l_lens_center = Vector2(glasses_bridge - 4, glasses_y)
	var r_lens_center = Vector2(glasses_bridge + 4, glasses_y)
	# Wire frames (dark thin metal)
	draw_arc(l_lens_center, 4.0, 0, TAU, 14, Color(0.3, 0.28, 0.25), 1.3)
	draw_arc(r_lens_center, 4.0, 0, TAU, 14, Color(0.3, 0.28, 0.25), 1.3)
	# Bridge connecting lenses
	draw_line(l_lens_center + Vector2(3, -1), r_lens_center + Vector2(-3, -1), Color(0.3, 0.28, 0.25), 1.0)
	# Temple arms going to ears
	draw_line(l_lens_center + Vector2(-4, 0), head_center + Vector2(-10, 0), Color(0.3, 0.28, 0.25, 0.6), 1.0)
	draw_line(r_lens_center + Vector2(4, 0), head_center + Vector2(10, 0), Color(0.3, 0.28, 0.25, 0.6), 1.0)
	# Glass lens fill (very slight blue tint)
	draw_circle(l_lens_center, 3.5, Color(0.7, 0.75, 0.85, 0.12))
	draw_circle(r_lens_center, 3.5, Color(0.7, 0.75, 0.85, 0.12))
	# Lens glare / shine
	draw_circle(l_lens_center + Vector2(-1, -1), 1.2, Color(1.0, 1.0, 1.0, 0.25))
	draw_circle(r_lens_center + Vector2(-1, -1), 1.2, Color(1.0, 1.0, 1.0, 0.25))

	# === SMALL SQUINTING EYES BEHIND GLASSES ===
	var l_eye_pos = l_lens_center + Vector2(0, 0.5)
	var r_eye_pos = r_lens_center + Vector2(0, 0.5)
	# Eye whites (small, squinty)
	draw_circle(l_eye_pos, 2.0, Color(0.95, 0.93, 0.90))
	draw_circle(r_eye_pos, 2.0, Color(0.95, 0.93, 0.90))
	if is_kind:
		# Kind eyes — warmer, more open, slight upward curve
		# Irises (warm brown)
		draw_circle(l_eye_pos, 1.5, Color(0.45, 0.35, 0.2))
		draw_circle(r_eye_pos, 1.5, Color(0.45, 0.35, 0.2))
		# Pupils
		draw_circle(l_eye_pos, 0.8, Color(0.1, 0.08, 0.05))
		draw_circle(r_eye_pos, 0.8, Color(0.1, 0.08, 0.05))
		# Warm eye shine
		draw_circle(l_eye_pos + Vector2(-0.4, -0.4), 0.5, Color(1.0, 0.95, 0.8, 0.7))
		draw_circle(r_eye_pos + Vector2(-0.4, -0.4), 0.5, Color(1.0, 0.95, 0.8, 0.7))
		# Kind crinkle lines (smile lines at corners)
		draw_line(l_eye_pos + Vector2(-2.5, -1), l_eye_pos + Vector2(-3.5, -2), skin_shadow, 0.8)
		draw_line(r_eye_pos + Vector2(2.5, -1), r_eye_pos + Vector2(3.5, -2), skin_shadow, 0.8)
	else:
		# Stern/suspicious squinting eyes
		# Irises (cold grey-blue)
		draw_circle(l_eye_pos, 1.2, Color(0.4, 0.42, 0.5))
		draw_circle(r_eye_pos, 1.2, Color(0.4, 0.42, 0.5))
		# Pupils (tiny, suspicious)
		draw_circle(l_eye_pos, 0.6, Color(0.08, 0.08, 0.1))
		draw_circle(r_eye_pos, 0.6, Color(0.08, 0.08, 0.1))
		# Cold eye shine
		draw_circle(l_eye_pos + Vector2(-0.3, -0.3), 0.4, Color(0.9, 0.9, 1.0, 0.5))
		draw_circle(r_eye_pos + Vector2(-0.3, -0.3), 0.4, Color(0.9, 0.9, 1.0, 0.5))
		# Squint lines (heavy lids pressing down)
		draw_line(l_eye_pos + Vector2(-2.5, -1.2), l_eye_pos + Vector2(2.5, -1.2), skin_shadow, 1.3)
		draw_line(r_eye_pos + Vector2(-2.5, -1.2), r_eye_pos + Vector2(2.5, -1.2), skin_shadow, 1.3)
		# Furrowed brow wrinkle
		draw_line(l_eye_pos + Vector2(-1.5, -3), l_eye_pos + Vector2(1.5, -2.5), skin_shadow, 0.8)
		draw_line(r_eye_pos + Vector2(-1.5, -2.5), r_eye_pos + Vector2(1.5, -3), skin_shadow, 0.8)

	# === NOSE (prominent, pointed — scaled for smaller head) ===
	var nose_pos = head_center + Vector2(0, 3)
	draw_circle(nose_pos, 2.0, skin_base)
	draw_circle(nose_pos + Vector2(0, 1), 1.5, skin_shadow)
	# Nose bridge
	draw_line(head_center + Vector2(0, 0), nose_pos, skin_shadow, 1.2)
	# Nose highlight
	draw_circle(nose_pos + Vector2(-0.4, -0.4), 0.8, skin_highlight)

	# === MOUTH / EXPRESSION (scaled for smaller head) ===
	var mouth_pos = head_center + Vector2(0, 6)
	if is_kind:
		# Warm, gentle smile (transformed Scrooge)
		draw_arc(mouth_pos, 3.0, 0.3, PI - 0.3, 10, Color(0.6, 0.35, 0.3), 1.3)
		# Slight open warmth to the smile
		draw_arc(mouth_pos + Vector2(0, 0.4), 2.2, 0.4, PI - 0.4, 8, Color(0.5, 0.25, 0.2, 0.5), 0.8)
		# Rosy cheeks (warm kind glow)
		draw_circle(head_center + Vector2(-6, 2.5), 2.5, Color(0.9, 0.55, 0.45, 0.2))
		draw_circle(head_center + Vector2(6, 2.5), 2.5, Color(0.9, 0.55, 0.45, 0.2))
	else:
		# Stern, mean, suspicious frown
		draw_arc(mouth_pos, 2.8, PI + 0.4, TAU - 0.4, 10, Color(0.5, 0.3, 0.25), 1.3)
		# Thin pressed lips
		draw_line(mouth_pos + Vector2(-3, 0), mouth_pos + Vector2(3, 0), Color(0.6, 0.4, 0.35), 1.0)
		# Grimace lines at corners of mouth
		draw_line(mouth_pos + Vector2(-3, 0), mouth_pos + Vector2(-4, 1.5), skin_shadow, 0.7)
		draw_line(mouth_pos + Vector2(3, 0), mouth_pos + Vector2(4, 1.5), skin_shadow, 0.7)

	# === WRINKLES AND AGE DETAILS (scaled for smaller head) ===
	# Forehead wrinkles
	draw_line(head_center + Vector2(-5, -6), head_center + Vector2(5, -6), Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.25), 0.7)
	draw_line(head_center + Vector2(-4, -5), head_center + Vector2(4, -5), Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.2), 0.6)
	# Crow's feet at eye corners
	draw_line(head_center + Vector2(-9, -1), head_center + Vector2(-11, -2.5), Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.2), 0.6)
	draw_line(head_center + Vector2(-9, 0), head_center + Vector2(-11, 0), Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.15), 0.5)
	draw_line(head_center + Vector2(9, -1), head_center + Vector2(11, -2.5), Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.2), 0.6)
	draw_line(head_center + Vector2(9, 0), head_center + Vector2(11, 0), Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.15), 0.5)
	# Nasolabial folds (nose to mouth creases)
	draw_line(nose_pos + Vector2(-1.5, 1.5), mouth_pos + Vector2(-4, -1), Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.15), 0.6)
	draw_line(nose_pos + Vector2(1.5, 1.5), mouth_pos + Vector2(4, -1), Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.15), 0.6)
	# Under-eye bags
	draw_arc(l_eye_pos + Vector2(0, 2.5), 2.0, 0.3, PI - 0.3, 6, Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.15), 0.6)
	draw_arc(r_eye_pos + Vector2(0, 2.5), 2.0, 0.3, PI - 0.3, 6, Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.15), 0.6)

	# === EARS (large, elderly — scaled for smaller head) ===
	draw_circle(head_center + Vector2(-11, 1), 3.0, skin_base)
	draw_circle(head_center + Vector2(-11, 1), 2.0, skin_shadow)
	draw_circle(head_center + Vector2(-11, 1), 1.2, Color(0.75, 0.65, 0.58, 0.4))
	draw_circle(head_center + Vector2(11, 1), 3.0, skin_base)
	draw_circle(head_center + Vector2(11, 1), 2.0, skin_shadow)
	draw_circle(head_center + Vector2(11, 1), 1.2, Color(0.75, 0.65, 0.58, 0.4))

	# === T4: EERIE DARK AURA around Scrooge himself ===
	if upgrade_tier >= 4:
		var aura_pulse = sin(_time * 2.0) * 0.03
		draw_circle(body_offset + Vector2(0, -10), 48.0, Color(0.1, 0.05, 0.15, 0.06 + aura_pulse))
		draw_arc(body_offset + Vector2(0, -10), 50.0, 0, TAU, 32, Color(0.15, 0.08, 0.2, 0.08 + aura_pulse), 1.5)
		# Dark energy wisps around body
		for i in range(4):
			var w_a = _time * 0.6 + float(i) * TAU / 4.0
			var w_r = 42.0 + sin(_time * 1.5 + float(i) * 2.0) * 5.0
			var w_pos = body_offset + Vector2(0, -10) + Vector2.from_angle(w_a) * w_r
			draw_circle(w_pos, 3.0, Color(0.1, 0.05, 0.15, 0.1))
			var w_tail = body_offset + Vector2(0, -10) + Vector2.from_angle(w_a - 0.4) * (w_r - 8.0)
			draw_line(w_pos, w_tail, Color(0.1, 0.05, 0.15, 0.06), 1.5)

	# === BELL GLEAM on face (proximity lighting from held bell) ===
	var bell_light_pos = weapon_hand + dir * 4.0 + Vector2(0, -10)
	var face_dist = bell_light_pos.distance_to(head_center)
	var light_strength = clamp(1.0 - face_dist / 60.0, 0.0, 0.3)
	if light_strength > 0.05:
		draw_circle(head_center, 13.0, Color(0.9, 0.78, 0.3, light_strength * 0.12))
		draw_circle(torso_center, 16.0, Color(0.85, 0.7, 0.25, light_strength * 0.06))

	# === AWAITING ABILITY CHOICE INDICATOR ===
	if awaiting_ability_choice:
		var pulse = (sin(_time * 4.0) + 1.0) * 0.5
		draw_circle(Vector2.ZERO, 60.0 + pulse * 6.0, Color(0.85, 0.75, 0.3, 0.1 + pulse * 0.1))
		draw_arc(Vector2.ZERO, 60.0 + pulse * 6.0, 0, TAU, 32, Color(0.85, 0.75, 0.3, 0.3 + pulse * 0.3), 2.5)
		var font3 = ThemeDB.fallback_font
		draw_string(font3, Vector2(-16, -78), "!", HORIZONTAL_ALIGNMENT_CENTER, 32, 30, Color(0.85, 0.75, 0.3, 0.7 + pulse * 0.3))

	# === DAMAGE DEALT COUNTER ===
	if damage_dealt > 0:
		var font = ThemeDB.fallback_font
		var dmg_text = str(int(damage_dealt)) + " DMG"
		if stat_upgrade_level > 0:
			dmg_text += " • Lv." + str(stat_upgrade_level)
		draw_string(font, Vector2(-36, 56), dmg_text, HORIZONTAL_ALIGNMENT_LEFT, 160, 12, Color(1.0, 0.84, 0.0, 0.5))

	# === UPGRADE NAME FLASH ===
	if _upgrade_flash > 0.0 and _upgrade_name != "":
		var font2 = ThemeDB.fallback_font
		draw_string(font2, Vector2(-80, -70), _upgrade_name, HORIZONTAL_ALIGNMENT_CENTER, 160, 16, Color(0.9, 0.85, 0.4, min(_upgrade_flash, 1.0)))

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
