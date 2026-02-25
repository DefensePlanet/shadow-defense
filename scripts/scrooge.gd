extends Node2D
## Ebenezer Scrooge — support tower from Dickens' A Christmas Carol (1843).
## Rings bell for AoE knockback and gold generation. Upgrades by dealing damage.
## Tier 1: "Bah, Humbug!" — Blast knockback +15% stronger
## Tier 2: "Ghost of Christmas Past" — Ghost rescues 5 enemies from path end, sends them back to start
## Tier 3: "Ghost of Christmas Present" — Gives the team 25 gold twice per round
## Tier 4: "Ghost of Yet to Come" — Every other wave, massive coin blast damages all enemies

var damage: float = 1.5
var fire_rate: float = 0.667
var attack_range: float = 65.0
var fire_cooldown: float = 0.0
var aim_angle: float = 0.0
var target: Node2D = null
var gold_bonus: int = 1

# Knockback and gold generation
var knockback_amount: float = 30.0
var gold_per_ring: int = 1
var bonus_gold_per_enemy: int = 0

# Damage tracking and upgrades
var damage_dealt: float = 0.0
var upgrade_tier: int = 0
var _upgrade_flash: float = 0.0
var _upgrade_name: String = ""

# Accumulated stat boosts from _apply_stat_boost() (preserved across tier upgrades)
var _accumulated_damage_boost: float = 0.0
var _accumulated_fire_rate_boost: float = 0.0
var _accumulated_range_boost: float = 0.0
var _accumulated_knockback_boost: float = 0.0
var _accumulated_gold_per_ring_boost: int = 0

# Animation vars
var _time: float = 0.0
var _attack_anim: float = 0.0

# Tier 2: Ghost of Christmas Past — rescue enemies from path end
var _ghost_past_active: bool = false
var _ghost_past_targets: Array = []
var _ghost_past_phase: float = 0.0
var _ghost_past_ready: float = 0.0
var _ghost_past_cooldown: float = 20.0
var _ghost_flash: float = 0.0

# Tier 3: Ghost of Christmas Present — give 25 gold twice per round
var _present_gold_given: int = 0
var _present_gold_timer: float = 0.0
var _present_flash: float = 0.0

# Tier 4: Ghost of Yet to Come — coin blast every other wave
var _coin_blast_wave_count: int = 0
var _coin_blast_timer: float = 0.0
var _coin_blast_active: bool = false
var _coin_blast_phase: float = 0.0
var _coin_blast_flash: float = 0.0

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
	"Blast knockback +15% stronger",
	"Ghost rescues 5 enemies from path end — sends them back to start",
	"Gives the team 25 gold twice per round",
	"Every other wave — massive coin blast damages all enemies"
]
const TIER_COSTS = [55, 120, 225, 1000]
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
var _cha_ching_sound: AudioStreamWAV
var _cha_ching_player: AudioStreamPlayer
var _upgrade_sound: AudioStreamWAV
var _upgrade_player: AudioStreamPlayer
var _game_font: Font

func _ready() -> void:
	_game_font = load("res://fonts/Cinzel.ttf")
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

	# Cha-ching sound — metallic bell hit + coin cascade (Tier 4 coin blast)
	var ching_rate := 22050
	var ching_dur := 0.5
	var ching_samples := PackedFloat32Array()
	ching_samples.resize(int(ching_rate * ching_dur))
	for i in ching_samples.size():
		var t := float(i) / ching_rate
		# "Ka" — sharp metallic strike
		var ka := sin(TAU * 2200.0 * t) * exp(-t * 40.0) * 0.4
		ka += sin(TAU * 3300.0 * t) * exp(-t * 50.0) * 0.25
		# "Ching" — bright bell ring with shimmer (delayed 0.1s)
		var dt := t - 0.1
		var ching := 0.0
		if dt > 0.0:
			ching = sin(TAU * 4400.0 * dt) * exp(-dt * 12.0) * 0.35
			ching += sin(TAU * 5500.0 * dt) * exp(-dt * 15.0) * 0.15
			# Coin cascade flutter
			ching += sin(TAU * 6600.0 * dt + sin(TAU * 30.0 * dt) * 3.0) * exp(-dt * 20.0) * 0.1
		ching_samples[i] = clampf(ka + ching, -1.0, 1.0)
	_cha_ching_sound = _samples_to_wav(ching_samples, ching_rate)
	_cha_ching_player = AudioStreamPlayer.new()
	_cha_ching_player.stream = _cha_ching_sound
	_cha_ching_player.volume_db = -4.0
	add_child(_cha_ching_player)

func _process(delta: float) -> void:
	_time += delta
	_attack_anim = max(_attack_anim - delta * 3.0, 0.0)
	fire_cooldown -= delta
	_upgrade_flash = max(_upgrade_flash - delta * 0.5, 0.0)
	_ghost_flash = max(_ghost_flash - delta * 1.5, 0.0)
	_present_flash = maxf(_present_flash - delta * 2.0, 0.0)
	_coin_blast_flash = maxf(_coin_blast_flash - delta * 1.5, 0.0)
	target = _find_nearest_enemy()

	if target:
		var desired = global_position.angle_to_point(target.global_position) + PI
		aim_angle = lerp_angle(aim_angle, desired, 8.0 * delta)
		if fire_cooldown <= 0.0:
			_shoot()
			fire_cooldown = 1.0 / (fire_rate * _speed_mult())

	# Tier 2: Ghost of Christmas Past — rescue enemies near end of path
	if upgrade_tier >= 2:
		if _ghost_past_active:
			_update_ghost_past(delta)
		else:
			_ghost_past_ready -= delta
			if _ghost_past_ready <= 0.0:
				# Check if any enemies are near the end of the path (progress > 0.8)
				var enemies = get_tree().get_nodes_in_group("enemies")
				for enemy in enemies:
					if is_instance_valid(enemy) and "progress" in enemy and enemy.progress > 0.8:
						_trigger_ghost_past()
						break

	# Tier 3: Ghost of Christmas Present — give 25 gold twice per round
	if upgrade_tier >= 3:
		if _present_gold_timer > 0.0:
			_present_gold_timer -= delta
			if _present_gold_timer <= 0.0 and _present_gold_given < 2:
				var main = get_tree().get_first_node_in_group("main")
				if main and main.has_method("add_gold"):
					main.add_gold(25)
				_present_gold_given += 1
				_present_flash = 1.5
				_ghost_flash = 1.2
				if _ghost_present_player and not _is_sfx_muted():
					_ghost_present_player.play()
				if _present_gold_given < 2:
					_present_gold_timer = 15.0

	# Tier 4: Ghost of Yet to Come — coin blast every other wave
	if upgrade_tier >= 4:
		if _coin_blast_timer > 0.0:
			_coin_blast_timer -= delta
			if _coin_blast_timer <= 0.0:
				_trigger_coin_blast()
		if _coin_blast_active:
			_update_coin_blast(delta)

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
			enemies_hit += 1
	# Earn gold per bell ring (more enemies = more gold, scaled by gold_bonus)
	if main and enemies_hit > 0:
		main.add_gold(int((gold_per_ring * gold_bonus + (enemies_hit - 1) * bonus_gold_per_enemy) * _gold_mult()))

func on_wave_start(_wave_num: int) -> void:
	# Tier 3: Reset gold giving for this round
	if upgrade_tier >= 3:
		_present_gold_given = 0
		_present_gold_timer = 3.0
	# Tier 4: Coin blast every other wave
	if upgrade_tier >= 4:
		_coin_blast_wave_count += 1
		if _coin_blast_wave_count % 2 == 1:
			_coin_blast_timer = 3.0

func _trigger_ghost_past() -> void:
	_ghost_flash = 1.0
	# Find up to 5 enemies with the highest progress values (nearest to end)
	var enemies = get_tree().get_nodes_in_group("enemies")
	var candidates: Array = []
	for enemy in enemies:
		if is_instance_valid(enemy) and "progress" in enemy:
			candidates.append(enemy)
	# Sort by progress descending (nearest to end first)
	candidates.sort_custom(func(a, b): return a.progress > b.progress)
	_ghost_past_targets.clear()
	for i in range(mini(5, candidates.size())):
		_ghost_past_targets.append(candidates[i])
	if _ghost_past_targets.size() > 0:
		_ghost_past_active = true
		_ghost_past_phase = 0.0
		_ghost_flash = 1.0
		if _ghost_past_player and not _is_sfx_muted():
			_ghost_past_player.play()

func _update_ghost_past(delta: float) -> void:
	_ghost_past_phase += delta / 3.0  # 3 seconds total animation
	if _ghost_past_phase >= 1.0:
		# Animation complete — send enemies back to start
		for enemy in _ghost_past_targets:
			if is_instance_valid(enemy) and "progress" in enemy:
				enemy.progress = 0.0
		_ghost_past_targets.clear()
		_ghost_past_active = false
		_ghost_past_ready = _ghost_past_cooldown
		return
	# Keep ghost flash active during animation
	_ghost_flash = maxf(_ghost_flash, 0.5)

func _trigger_coin_blast() -> void:
	if _cha_ching_player and not _is_sfx_muted():
		_cha_ching_player.play()
	_coin_blast_active = true
	_coin_blast_phase = 0.0
	_coin_blast_flash = 2.0
	# Massive AoE damage to ALL enemies on screen
	var dmg = damage * 25.0 * _damage_mult()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			enemy.take_damage(dmg)
			register_damage(dmg)

func _update_coin_blast(delta: float) -> void:
	_coin_blast_phase += delta / 1.5  # 1.5 second animation
	if _coin_blast_phase >= 1.0:
		_coin_blast_active = false

func register_damage(amount: float) -> void:
	damage_dealt += amount
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("register_tower_damage"):
		main.register_tower_damage(main.TowerType.SCROOGE, amount)
	_check_upgrades()

func register_kill() -> void:
	pass

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
	var dmg_boost = damage * 0.10
	var rate_boost = fire_rate * 0.05
	_accumulated_damage_boost += dmg_boost
	_accumulated_fire_rate_boost += rate_boost
	_accumulated_range_boost += 4.0
	_accumulated_knockback_boost += 3.0
	_accumulated_gold_per_ring_boost += 1
	damage += dmg_boost
	fire_rate += rate_boost
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
	_refresh_tier_sounds()
	_upgrade_flash = 3.0
	_upgrade_name = TIER_NAMES[index]

func _apply_upgrade(tier: int) -> void:
	match tier:
		1: # Bah, Humbug! — blast knockback +15% stronger
			knockback_amount *= 1.15
			attack_range *= 1.15
			gold_per_ring = 3
			bonus_gold_per_enemy = 1
			fire_rate = 0.8
			damage = 2.0
		2: # Ghost of Christmas Past — ghost rescues 5 enemies from path end
			knockback_amount = 55.0
			damage = 3.0
			fire_rate = 0.9
			attack_range = 80.0
			gold_bonus = 3
		3: # Ghost of Christmas Present — gives 25 gold twice per round
			damage = 4.0
			fire_rate = 1.0
			attack_range = 90.0
			knockback_amount = 65.0
			gold_bonus = 4
		4: # Ghost of Yet to Come — coin blast every other wave
			damage = 5.0
			fire_rate = 1.1
			attack_range = 100.0
			knockback_amount = 80.0
			gold_bonus = 6
	# Re-apply accumulated stat boosts from damage milestones
	damage += _accumulated_damage_boost
	fire_rate += _accumulated_fire_rate_boost
	attack_range += _accumulated_range_boost
	knockback_amount += _accumulated_knockback_boost
	gold_per_ring += _accumulated_gold_per_ring_boost

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

func _exit_tree() -> void:
	# Clean up Fezziwig aura buff from all affected towers
	if prog_abilities[5]:
		_remove_fezziwig_aura()

func _generate_tier_sounds() -> void:
	# Spectral bell tones — deep, warm, ghostly tolls in D minor
	# D3, F3, A3, D4, A3, F3, D3, D4 — D minor triad arpeggiated (haunted bell melody)
	var bell_notes := [146.83, 174.61, 220.00, 293.66, 220.00, 174.61, 146.83, 293.66]
	var mix_rate := 44100
	_attack_sounds_by_tier = []

	# --- Tier 0: Muffled Hand Bell (soft, short, muted strike) ---
	var t0 := []
	for note_idx in bell_notes.size():
		var freq: float = bell_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.25))
		for i in samples.size():
			var t := float(i) / mix_rate
			var strike := exp(-t * 80.0) * 0.08
			var env := exp(-t * 12.0) * 0.2
			var fund := sin(t * freq * TAU)
			# Bell partials (slightly inharmonic — gives bell character)
			var p2 := sin(t * freq * 2.76 * TAU) * 0.12 * exp(-t * 18.0)
			var p3 := sin(t * freq * 5.4 * TAU) * 0.04 * exp(-t * 30.0)
			samples[i] = clampf((fund + p2 + p3) * env + (randf() * 2.0 - 1.0) * strike, -1.0, 1.0)
		t0.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t0)

	# --- Tier 1: Church Bell (clearer ring, longer sustain) ---
	var t1 := []
	for note_idx in bell_notes.size():
		var freq: float = bell_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.35))
		for i in samples.size():
			var t := float(i) / mix_rate
			var strike := exp(-t * 100.0) * 0.06
			var env := exp(-t * 7.0) * 0.22
			var fund := sin(t * freq * TAU)
			var p2 := sin(t * freq * 2.76 * TAU) * 0.15 * exp(-t * 12.0)
			var p3 := sin(t * freq * 5.4 * TAU) * 0.06 * exp(-t * 22.0)
			var sub := sin(t * freq * 0.5 * TAU) * 0.08 * exp(-t * 5.0)
			samples[i] = clampf((fund + p2 + p3 + sub) * env + (randf() * 2.0 - 1.0) * strike, -1.0, 1.0)
		t1.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t1)

	# --- Tier 2: Grandfather Clock Chime (warm, resonant, with beating) ---
	var t2 := []
	for note_idx in bell_notes.size():
		var freq: float = bell_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.4))
		for i in samples.size():
			var t := float(i) / mix_rate
			var strike := exp(-t * 120.0) * 0.05
			var env := exp(-t * 5.5) * 0.22
			var fund := sin(t * freq * TAU)
			# Beating from slightly detuned pair (warm wobble)
			var beat := sin(t * freq * 1.003 * TAU) * 0.2
			var p2 := sin(t * freq * 2.76 * TAU) * 0.12 * exp(-t * 10.0)
			var p3 := sin(t * freq * 5.4 * TAU) * 0.05 * exp(-t * 18.0)
			var sub := sin(t * freq * 0.5 * TAU) * 0.1 * exp(-t * 4.0)
			samples[i] = clampf((fund + beat + p2 + p3 + sub) * env + (randf() * 2.0 - 1.0) * strike, -1.0, 1.0)
		t2.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t2)

	# --- Tier 3: Spectral Toll (ghostly, ethereal with slow vibrato) ---
	var t3 := []
	for note_idx in bell_notes.size():
		var freq: float = bell_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.5))
		for i in samples.size():
			var t := float(i) / mix_rate
			var strike := exp(-t * 100.0) * 0.05
			var env := exp(-t * 4.0) * 0.22
			# Slow vibrato gives ghostly wavering quality
			var vib := sin(TAU * 4.5 * t) * 3.0
			var fund := sin(t * (freq + vib) * TAU)
			var beat := sin(t * (freq * 1.004 + vib) * TAU) * 0.18
			var p2 := sin(t * freq * 2.76 * TAU) * 0.1 * exp(-t * 9.0)
			var p3 := sin(t * freq * 5.4 * TAU) * 0.04 * exp(-t * 16.0)
			var sub := sin(t * freq * 0.5 * TAU) * 0.12 * exp(-t * 3.5)
			# Faint breathy whisper (ghost breath)
			var breath := (randf() * 2.0 - 1.0) * 0.02 * exp(-t * 2.0)
			samples[i] = clampf((fund + beat + p2 + p3 + sub) * env + breath + (randf() * 2.0 - 1.0) * strike, -1.0, 1.0)
		t3.append(_samples_to_wav(samples, mix_rate))
	_attack_sounds_by_tier.append(t3)

	# --- Tier 4: Phantom Cathedral Bell (rich, deep, haunted resonance) ---
	var t4 := []
	for note_idx in bell_notes.size():
		var freq: float = bell_notes[note_idx]
		var samples := PackedFloat32Array()
		samples.resize(int(mix_rate * 0.6))
		for i in samples.size():
			var t := float(i) / mix_rate
			var strike := exp(-t * 90.0) * 0.05
			var env := exp(-t * 3.2) * 0.2
			var vib := sin(TAU * 3.8 * t) * 2.5
			var fund := sin(t * (freq + vib) * TAU)
			# Chorus — three detuned layers for cathedral depth
			var ch1 := sin(t * (freq * 1.003 + vib) * TAU) * 0.2
			var ch2 := sin(t * (freq * 0.997 + vib) * TAU) * 0.2
			# Bell partials
			var p2 := sin(t * freq * 2.76 * TAU) * 0.1 * exp(-t * 8.0)
			var p3 := sin(t * freq * 5.4 * TAU) * 0.04 * exp(-t * 14.0)
			# Deep sub-octave for weight
			var sub := sin(t * freq * 0.5 * TAU) * 0.14 * exp(-t * 3.0)
			# Spectral shimmer (very high faint partial)
			var shimmer := sin(t * freq * 8.2 * TAU) * 0.015 * exp(-t * 20.0)
			var breath := (randf() * 2.0 - 1.0) * 0.015 * exp(-t * 1.5)
			samples[i] = clampf((fund + ch1 + ch2 + p2 + p3 + sub + shimmer) * env + breath + (randf() * 2.0 - 1.0) * strike, -1.0, 1.0)
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
	# Ability 3: Cratchit's Loyalty — double passive gold (applied through gold_bonus)
	if prog_abilities[2]:
		gold_bonus = max(gold_bonus, 2)

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
	var eff_range = attack_range * _range_mult()
	var enemies = get_tree().get_nodes_in_group("enemies")
	var in_range: Array = []
	for e in enemies:
		if global_position.distance_to(e.global_position) < eff_range:
			in_range.append(e)
	in_range.shuffle()
	for i in range(mini(3, in_range.size())):
		if is_instance_valid(in_range[i]) and in_range[i].has_method("apply_slow"):
			in_range[i].apply_slow(0.0, 2.0)

func _marleys_chains_link() -> void:
	_ghost_flash = 1.0
	var eff_range = attack_range * _range_mult()
	var enemies = get_tree().get_nodes_in_group("enemies")
	var in_range: Array = []
	for e in enemies:
		if global_position.distance_to(e.global_position) < eff_range:
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
				var current_tier = tower.upgrade_tier if "upgrade_tier" in tower else 0
				if not tower.has_meta("fezziwig_base_rate"):
					tower.set_meta("fezziwig_base_rate", tower.fire_rate)
					tower.set_meta("fezziwig_upgrade_tier", current_tier)
				elif tower.has_meta("fezziwig_upgrade_tier") and tower.get_meta("fezziwig_upgrade_tier") != current_tier:
					# Tower upgraded since last snapshot — re-snapshot the current rate
					# First remove old boost to get real current rate
					var old_base = tower.get_meta("fezziwig_base_rate")
					var was_boosted = absf(tower.fire_rate - old_base * 1.25) < 0.001
					if was_boosted:
						# Tower rate is still our boosted value, so current unboosted = fire_rate / 1.25
						tower.set_meta("fezziwig_base_rate", tower.fire_rate / 1.25)
					else:
						# Tower rate changed independently (upgrade applied), use current rate as new base
						tower.set_meta("fezziwig_base_rate", tower.fire_rate)
					tower.set_meta("fezziwig_upgrade_tier", current_tier)
				var base_rate = tower.get_meta("fezziwig_base_rate")
				tower.fire_rate = base_rate * 1.25

func _remove_fezziwig_aura() -> void:
	for tower in get_tree().get_nodes_in_group("towers"):
		if tower == self:
			continue
		if tower.has_meta("fezziwig_base_rate"):
			tower.fire_rate = tower.get_meta("fezziwig_base_rate")
			tower.remove_meta("fezziwig_base_rate")
			if tower.has_meta("fezziwig_upgrade_tier"):
				tower.remove_meta("fezziwig_upgrade_tier")

func _knocker_reverse() -> void:
	_knocker_flash = 1.0
	var eff_range = attack_range * _range_mult()
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) < eff_range:
			if e.has_method("apply_fear_reverse"):
				e.apply_fear_reverse(3.0)

func _christmas_turkey() -> void:
	_turkey_flash = 1.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("take_damage"):
			var dmg = damage * 2.0 * _damage_mult()
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

	# === GHOST OF CHRISTMAS PAST RESCUE ANIMATION (tier 2+) ===
	if _ghost_past_active and _ghost_past_targets.size() > 0:
		# Compute ghost position along its flight path
		var gp_alpha := clampf(_ghost_past_phase, 0.0, 1.0)
		var ghost_pos := global_position
		# Phase 0-0.33: fly from tower toward end of map
		# Phase 0.33-0.66: hover at enemies, grabbing
		# Phase 0.66-1.0: carry enemies back to start
		var target_pos := Vector2.ZERO
		if _ghost_past_targets.size() > 0 and is_instance_valid(_ghost_past_targets[0]):
			target_pos = _ghost_past_targets[0].global_position
		var local_ghost := Vector2.ZERO
		if gp_alpha < 0.33:
			var t_phase := gp_alpha / 0.33
			local_ghost = Vector2.ZERO.lerp(to_local(target_pos), t_phase) if target_pos != Vector2.ZERO else Vector2(0, -100.0 * t_phase)
		elif gp_alpha < 0.66:
			local_ghost = to_local(target_pos) if target_pos != Vector2.ZERO else Vector2(0, -100.0)
			# Shake/grab effect
			local_ghost += Vector2(sin(_time * 20.0) * 3.0, cos(_time * 15.0) * 2.0)
		else:
			var t_phase := (gp_alpha - 0.66) / 0.34
			var from_pos := to_local(target_pos) if target_pos != Vector2.ZERO else Vector2(0, -100.0)
			local_ghost = from_pos.lerp(Vector2.ZERO, t_phase)
		# Draw the ghost — translucent blue-white figure with old-fashioned clothing
		var gp_bob := sin(_time * 5.0) * 2.0
		var g_center := local_ghost + Vector2(0, gp_bob)
		# Ghostly aura
		draw_circle(g_center, 22.0, Color(0.4, 0.5, 0.9, 0.08))
		# Flowing robe body
		var gp_robe := PackedVector2Array([
			g_center + Vector2(-12, 18), g_center + Vector2(12, 18),
			g_center + Vector2(10, 2), g_center + Vector2(8, -10),
			g_center + Vector2(-8, -10), g_center + Vector2(-10, 2),
		])
		draw_colored_polygon(gp_robe, Color(0.5, 0.6, 0.95, 0.25))
		# Inner lighter shimmer
		var gp_inner := PackedVector2Array([
			g_center + Vector2(-8, 15), g_center + Vector2(8, 15),
			g_center + Vector2(6, 0), g_center + Vector2(-6, 0),
		])
		draw_colored_polygon(gp_inner, Color(0.65, 0.75, 1.0, 0.15))
		# Head with top hat silhouette
		var gp_head := g_center + Vector2(0, -14)
		draw_circle(gp_head, 8.0, Color(0.55, 0.65, 0.95, 0.25))
		# Top hat outline
		draw_colored_polygon(PackedVector2Array([
			gp_head + Vector2(-6, -3), gp_head + Vector2(-6, -16),
			gp_head + Vector2(6, -16), gp_head + Vector2(6, -3),
		]), Color(0.4, 0.5, 0.85, 0.2))
		# Hat brim
		draw_line(gp_head + Vector2(-9, -3), gp_head + Vector2(9, -3), Color(0.45, 0.55, 0.9, 0.25), 2.5)
		# Gentle eyes
		draw_circle(gp_head + Vector2(-3, 0), 1.2, Color(0.7, 0.8, 1.0, 0.4))
		draw_circle(gp_head + Vector2(3, 0), 1.2, Color(0.7, 0.8, 1.0, 0.4))
		# Trailing wisps
		for ti in range(4):
			var tw_base := g_center + Vector2(-6.0 + float(ti) * 4.0, 18)
			var tw_end := tw_base + Vector2(sin(_time * 3.0 + float(ti)) * 4.0, 8.0 + sin(_time * 2.0 + float(ti)) * 3.0)
			draw_line(tw_base, tw_end, Color(0.5, 0.6, 0.95, 0.15), 2.0)
		# Draw carried enemy silhouettes (during grab and return phases)
		if gp_alpha > 0.33:
			for ei in range(_ghost_past_targets.size()):
				var e_off := Vector2(-12.0 + float(ei) * 6.0, 22.0 + sin(_time * 4.0 + float(ei) * 1.5) * 3.0)
				var sil_pos := g_center + e_off
				# Dark enemy silhouette
				draw_circle(sil_pos, 5.0, Color(0.2, 0.15, 0.1, 0.3))
				draw_circle(sil_pos + Vector2(0, -5), 3.5, Color(0.2, 0.15, 0.1, 0.25))
				# Chain link from ghost to silhouette
				draw_line(g_center + Vector2(0, 16), sil_pos + Vector2(0, -3), Color(0.5, 0.6, 0.9, 0.15), 1.0)

	# === GHOST OF CHRISTMAS PRESENT GOLD GIFT (tier 3) ===
	if _present_flash > 0.0:
		var pf := _present_flash
		# Golden gift box at center
		var gift_y := -20.0 + sin(_time * 4.0) * 3.0
		draw_rect(Rect2(Vector2(-8, gift_y - 6), Vector2(16, 12)), Color(0.85, 0.15, 0.1, pf * 0.4), true)
		draw_rect(Rect2(Vector2(-8, gift_y - 6), Vector2(16, 12)), Color(1.0, 0.85, 0.2, pf * 0.5), false, 1.5)
		# Ribbon cross
		draw_line(Vector2(0, gift_y - 6), Vector2(0, gift_y + 6), Color(1.0, 0.85, 0.2, pf * 0.5), 2.0)
		draw_line(Vector2(-8, gift_y), Vector2(8, gift_y), Color(1.0, 0.85, 0.2, pf * 0.5), 2.0)
		# Bow on top
		draw_circle(Vector2(0, gift_y - 6), 3.0, Color(1.0, 0.85, 0.2, pf * 0.4))
		# Raining gold coins
		for ci in range(8):
			var coin_angle := TAU * float(ci) / 8.0 + _time * 2.5
			var coin_r_v := 30.0 + (1.0 - pf) * 40.0
			var coin_pos := Vector2.from_angle(coin_angle) * coin_r_v
			var coin_sz := 3.0 * pf
			draw_circle(coin_pos, coin_sz + 0.8, Color(0.06, 0.06, 0.08))
			draw_circle(coin_pos, coin_sz, Color(0.92, 0.78, 0.15, pf * 0.6))
			draw_circle(coin_pos + Vector2(-0.3, -0.3), coin_sz * 0.35, Color(1.0, 0.95, 0.5, pf * 0.4))
		# Green ghost shimmer
		draw_circle(Vector2.ZERO, 35.0 + (1.0 - pf) * 20.0, Color(0.3, 0.65, 0.25, pf * 0.06))
		# "+25 Gold!" text flash
		if _game_font and pf > 0.3:
			draw_string(_game_font, Vector2(-40, -50), "Gift: +25 Gold!", HORIZONTAL_ALIGNMENT_CENTER, 80, 14, Color(1.0, 0.9, 0.3, clampf(pf, 0.0, 1.0)))

	# === COIN BLAST EXPLOSION (tier 4) ===
	if _coin_blast_flash > 0.0:
		var cf := clampf(_coin_blast_flash, 0.0, 1.0)
		var blast_r := 80.0 + (1.0 - cf) * 180.0
		# Massive gold shockwave ring
		draw_circle(Vector2.ZERO, blast_r * 0.5, Color(1.0, 0.85, 0.2, cf * 0.15))
		draw_arc(Vector2.ZERO, blast_r, 0, TAU, 48, Color(1.0, 0.9, 0.3, cf * 0.5), 5.0)
		draw_arc(Vector2.ZERO, blast_r * 0.7, 0, TAU, 36, Color(1.0, 0.85, 0.2, cf * 0.35), 3.0)
		draw_arc(Vector2.ZERO, blast_r * 0.4, 0, TAU, 24, Color(1.0, 0.95, 0.5, cf * 0.2), 2.0)
		# Explosion of golden coins radiating outward
		for ci in range(16):
			var c_angle := TAU * float(ci) / 16.0 + _time * 1.5
			var c_r := blast_r * (0.3 + float(ci % 4) * 0.15)
			var c_pos := Vector2.from_angle(c_angle) * c_r
			var c_sz := 4.5 * cf
			# Spinning coin — alternate between face and edge based on time
			var spin_val := sin(_time * 8.0 + float(ci) * 1.2)
			var stretch := absf(spin_val)
			draw_set_transform(c_pos, 0, Vector2(maxf(stretch, 0.3), 1.0))
			draw_circle(Vector2.ZERO, c_sz + 1.0, Color(0.06, 0.06, 0.08))
			draw_circle(Vector2.ZERO, c_sz, Color(0.92, 0.78, 0.15, cf * 0.7))
			draw_circle(Vector2(-0.3, -0.3), c_sz * 0.3, Color(1.0, 0.95, 0.5, cf * 0.5))
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		# Small golden coins orbiting outward
		for oi in range(10):
			var o_angle := TAU * float(oi) / 10.0 - _time * 3.0
			var o_r := blast_r * 0.6 + (1.0 - cf) * 50.0 + float(oi % 3) * 15.0
			var o_pos := Vector2.from_angle(o_angle) * o_r
			draw_circle(o_pos, 3.0 * cf, Color(1.0, 0.9, 0.2, cf * 0.6))
			draw_circle(o_pos, 1.5 * cf, Color(1.0, 0.95, 0.5, cf * 0.4))
		# Gold spark rays
		for ri in range(12):
			var r_a := TAU * float(ri) / 12.0 + cf * 3.0
			var r_inner := Vector2.from_angle(r_a) * (blast_r * 0.3)
			var r_outer := Vector2.from_angle(r_a) * (blast_r + 10.0)
			draw_line(r_inner, r_outer, Color(1.0, 0.95, 0.4, cf * 0.3), 2.0)
		# "CHA-CHING!" text
		if _game_font and cf > 0.4:
			draw_string(_game_font, Vector2(-50, -70), "CHA-CHING!", HORIZONTAL_ALIGNMENT_CENTER, 100, 18, Color(1.0, 0.9, 0.2, cf))

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
		var turkey_r = 20.0 + (1.0 - _turkey_flash) * 60.0
		draw_circle(Vector2.from_angle(_turkey_flash * 8.0) * turkey_r, 4.0, Color(0.6, 0.35, 0.15, _turkey_flash * 0.6))
		draw_circle(Vector2.from_angle(_turkey_flash * 8.0) * turkey_r, 2.0, Color(0.8, 0.5, 0.2, _turkey_flash * 0.4))

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

	# === CHARACTER POSITIONS (Bloons chibi proportions) ===
	var OL = Color(0.06, 0.06, 0.08)
	var feet_y = body_offset + Vector2(sway * 1.0, 10.0)
	var leg_top = body_offset + Vector2(sway * 0.6, 0.0)
	var torso_center = body_offset + Vector2(sway * 0.3 + hunch_rock * 0.4, -8.0 - breathe * 0.5)
	var neck_base = body_offset + Vector2(sway * 0.15 + hunch_rock * 0.6, -14.0 - breathe * 0.3)
	var head_center = body_offset + Vector2(sway * 0.08 + hunch_rock * 0.8, -26.0 + hunch_rock * 0.5)

	# === PALETTE ===
	var coat_col = Color(0.10, 0.08, 0.12)
	var coat_hi = Color(0.18, 0.15, 0.22)
	var coat_dark = Color(0.05, 0.04, 0.06)
	var vest_col = Color(0.55, 0.18, 0.14)
	var vest_hi = Color(0.70, 0.28, 0.20)
	var shirt_col = Color(0.96, 0.94, 0.92)
	var gold_col = Color(0.92, 0.78, 0.15)
	var gold_hi = Color(1.0, 0.92, 0.45)
	var gold_dk = Color(0.65, 0.52, 0.08)
	var shoe_col = Color(0.08, 0.06, 0.06)
	var shoe_hi = Color(0.24, 0.22, 0.25)
	var hair_col = Color(0.90, 0.88, 0.84)

	# === COAT TAILS (behind legs — drawn first) ===
	var tail_sway_v = sin(_time * 1.5) * 2.0
	# Left tail OL -> fill
	draw_colored_polygon(PackedVector2Array([
		torso_center + Vector2(-8, 3), torso_center + Vector2(-3, 3),
		leg_top + Vector2(-2, 14 + tail_sway_v), leg_top + Vector2(-9, 15 + tail_sway_v * 0.7),
	]), OL)
	draw_colored_polygon(PackedVector2Array([
		torso_center + Vector2(-6.5, 4), torso_center + Vector2(-4, 4),
		leg_top + Vector2(-3, 13 + tail_sway_v), leg_top + Vector2(-7.5, 14 + tail_sway_v * 0.7),
	]), coat_col)
	# Right tail OL -> fill
	draw_colored_polygon(PackedVector2Array([
		torso_center + Vector2(3, 3), torso_center + Vector2(8, 3),
		leg_top + Vector2(9, 15 - tail_sway_v * 0.7), leg_top + Vector2(2, 14 - tail_sway_v),
	]), OL)
	draw_colored_polygon(PackedVector2Array([
		torso_center + Vector2(4, 4), torso_center + Vector2(6.5, 4),
		leg_top + Vector2(7.5, 14 - tail_sway_v * 0.7), leg_top + Vector2(3, 13 - tail_sway_v),
	]), coat_col)

	# === FEET (polished black Victorian shoes) ===
	var walk_cycle = sin(_time * 3.0) * 1.0
	var l_foot = feet_y + Vector2(-5, walk_cycle * 0.4)
	var r_foot = feet_y + Vector2(5, -walk_cycle * 0.4)
	# Left shoe OL -> fill -> shine
	draw_circle(l_foot, 5.5, OL)
	draw_circle(l_foot, 4.0, shoe_col)
	draw_circle(l_foot + Vector2(-1, -1.2), 2.0, shoe_hi)
	draw_circle(l_foot + Vector2(-1.5, -1.8), 0.8, Color(0.40, 0.38, 0.42, 0.45))
	# Right shoe OL -> fill -> shine
	draw_circle(r_foot, 5.5, OL)
	draw_circle(r_foot, 4.0, shoe_col)
	draw_circle(r_foot + Vector2(1, -1.2), 2.0, shoe_hi)
	draw_circle(r_foot + Vector2(1.5, -1.8), 0.8, Color(0.40, 0.38, 0.42, 0.45))

	# === LEGS (2-segment with knees — dark charcoal trousers) ===
	var l_hip = leg_top + Vector2(-4, 0)
	var r_hip = leg_top + Vector2(4, 0)
	var l_knee = l_hip.lerp(l_foot, 0.55) + Vector2(-1.5, 0)
	var r_knee = r_hip.lerp(r_foot, 0.55) + Vector2(1.5, 0)
	# Left thigh OL -> fill
	var ltd = (l_knee - l_hip).normalized()
	var ltp = ltd.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		l_hip + ltp * 4.5, l_hip - ltp * 4.0,
		l_knee - ltp * 3.5, l_knee + ltp * 4.0,
	]), OL)
	draw_colored_polygon(PackedVector2Array([
		l_hip + ltp * 3.0, l_hip - ltp * 2.5,
		l_knee - ltp * 2.0, l_knee + ltp * 2.5,
	]), coat_dark)
	# Left knee
	draw_circle(l_knee, 4.0, OL)
	draw_circle(l_knee, 2.8, coat_dark)
	# Left calf OL -> fill
	var lcd = (l_foot - l_knee).normalized()
	var lcp = lcd.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		l_knee + lcp * 3.8, l_knee - lcp * 3.5,
		l_foot - lcp * 2.5, l_foot + lcp * 2.8,
	]), OL)
	draw_colored_polygon(PackedVector2Array([
		l_knee + lcp * 2.3, l_knee - lcp * 2.0,
		l_foot - lcp * 1.2, l_foot + lcp * 1.5,
	]), coat_dark)
	# Right thigh OL -> fill
	var rtd = (r_knee - r_hip).normalized()
	var rtp = rtd.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		r_hip + rtp * 4.0, r_hip - rtp * 4.5,
		r_knee - rtp * 4.0, r_knee + rtp * 3.5,
	]), OL)
	draw_colored_polygon(PackedVector2Array([
		r_hip + rtp * 2.5, r_hip - rtp * 3.0,
		r_knee - rtp * 2.5, r_knee + rtp * 2.0,
	]), coat_dark)
	# Right knee
	draw_circle(r_knee, 4.0, OL)
	draw_circle(r_knee, 2.8, coat_dark)
	# Right calf OL -> fill
	var rcd = (r_foot - r_knee).normalized()
	var rcp = rcd.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		r_knee + rcp * 3.5, r_knee - rcp * 3.8,
		r_foot - rcp * 2.8, r_foot + rcp * 2.5,
	]), OL)
	draw_colored_polygon(PackedVector2Array([
		r_knee + rcp * 2.0, r_knee - rcp * 2.3,
		r_foot - rcp * 1.5, r_foot + rcp * 1.2,
	]), coat_dark)
	# Trouser crease highlights
	draw_line(l_hip, l_foot + Vector2(0, -2), Color(0.18, 0.15, 0.22, 0.2), 1.0)
	draw_line(r_hip, r_foot + Vector2(0, -2), Color(0.18, 0.15, 0.22, 0.2), 1.0)

	# === TORSO (Victorian tailcoat + waistcoat + shirt) ===
	# Coat body OL -> fill
	var coat_out = PackedVector2Array([
		torso_center + Vector2(-11, 5), torso_center + Vector2(-12, -1),
		neck_base + Vector2(-13, 1), neck_base + Vector2(13, 1),
		torso_center + Vector2(12, -1), torso_center + Vector2(11, 5),
	])
	draw_colored_polygon(coat_out, OL)
	var coat_fill = PackedVector2Array([
		torso_center + Vector2(-9.5, 4), torso_center + Vector2(-10.5, -0.5),
		neck_base + Vector2(-11.5, 1.5), neck_base + Vector2(11.5, 1.5),
		torso_center + Vector2(10.5, -0.5), torso_center + Vector2(9.5, 4),
	])
	draw_colored_polygon(coat_fill, coat_col)
	# Left side shadow
	draw_colored_polygon(PackedVector2Array([
		torso_center + Vector2(-9.5, 4), torso_center + Vector2(-10.5, -0.5),
		neck_base + Vector2(-11.5, 1.5), neck_base + Vector2(-7, 1.5),
		torso_center + Vector2(-6, 3),
	]), coat_dark)

	# White dress shirt strip OL -> fill
	draw_colored_polygon(PackedVector2Array([
		neck_base + Vector2(-4.5, 2.5), neck_base + Vector2(4.5, 2.5),
		torso_center + Vector2(4.5, 3.5), torso_center + Vector2(-4.5, 3.5),
	]), OL)
	draw_colored_polygon(PackedVector2Array([
		neck_base + Vector2(-3.5, 3), neck_base + Vector2(3.5, 3),
		torso_center + Vector2(3.5, 3), torso_center + Vector2(-3.5, 3),
	]), shirt_col)

	# Burgundy waistcoat OL -> fill
	draw_colored_polygon(PackedVector2Array([
		neck_base + Vector2(-6, 3), neck_base + Vector2(6, 3),
		torso_center + Vector2(7, 4), torso_center + Vector2(-7, 4),
	]), OL)
	draw_colored_polygon(PackedVector2Array([
		neck_base + Vector2(-5, 3.5), neck_base + Vector2(5, 3.5),
		torso_center + Vector2(6, 3.5), torso_center + Vector2(-6, 3.5),
	]), vest_col)
	# Waistcoat highlight
	draw_colored_polygon(PackedVector2Array([
		neck_base + Vector2(-2.5, 4), neck_base + Vector2(2.5, 4),
		torso_center + Vector2(3, 3.2), torso_center + Vector2(-3, 3.2),
	]), Color(vest_hi.r, vest_hi.g, vest_hi.b, 0.3))

	# Gold buttons OL -> fill -> sparkle
	for bi in range(3):
		var by = neck_base.y + 5.5 + float(bi) * 3.5
		var bx = torso_center.x
		draw_circle(Vector2(bx, by), 2.0, OL)
		draw_circle(Vector2(bx, by), 1.3, gold_col)
		draw_circle(Vector2(bx - 0.3, by - 0.4), 0.6, gold_hi)

	# Gold pocket watch chain OL -> fill
	var ch_s = Vector2(torso_center.x - 4, neck_base.y + 10)
	var ch_m = Vector2(torso_center.x, neck_base.y + 13)
	var ch_e = Vector2(torso_center.x + 4, neck_base.y + 10)
	draw_line(ch_s, ch_m, OL, 2.5)
	draw_line(ch_m, ch_e, OL, 2.5)
	draw_line(ch_s, ch_m, gold_col, 1.5)
	draw_line(ch_m, ch_e, gold_col, 1.5)
	# Watch fob OL -> fill -> sparkle
	draw_circle(ch_m, 2.5, OL)
	draw_circle(ch_m, 1.8, gold_col)
	draw_circle(ch_m + Vector2(-0.3, -0.3), 0.8, gold_hi)

	# Peaked lapels OL -> fill
	draw_colored_polygon(PackedVector2Array([
		neck_base + Vector2(-12, 0.5), neck_base + Vector2(-5, 3),
		torso_center + Vector2(-5, 0), torso_center + Vector2(-8, 0),
		neck_base + Vector2(-13, 3.5),
	]), OL)
	draw_colored_polygon(PackedVector2Array([
		neck_base + Vector2(-10.5, 1), neck_base + Vector2(-6, 3),
		torso_center + Vector2(-6, 0.5), torso_center + Vector2(-7.5, 0.5),
	]), coat_hi)
	draw_colored_polygon(PackedVector2Array([
		neck_base + Vector2(5, 3), neck_base + Vector2(12, 0.5),
		neck_base + Vector2(13, 3.5), torso_center + Vector2(8, 0),
		torso_center + Vector2(5, 0),
	]), OL)
	draw_colored_polygon(PackedVector2Array([
		neck_base + Vector2(6, 3), neck_base + Vector2(10.5, 1),
		torso_center + Vector2(7.5, 0.5), torso_center + Vector2(6, 0.5),
	]), coat_hi)

	# Dark cravat at neck OL -> fill
	draw_colored_polygon(PackedVector2Array([
		neck_base + Vector2(-3, 1.5), neck_base + Vector2(3, 1.5),
		neck_base + Vector2(2, 5.5), neck_base + Vector2(0, 6.5),
		neck_base + Vector2(-2, 5.5),
	]), OL)
	draw_colored_polygon(PackedVector2Array([
		neck_base + Vector2(-2, 2), neck_base + Vector2(2, 2),
		neck_base + Vector2(1.5, 5), neck_base + Vector2(0, 5.8),
		neck_base + Vector2(-1.5, 5),
	]), Color(0.20, 0.14, 0.25))
	# Cravat gold pin OL -> fill
	draw_circle(neck_base + Vector2(0, 3.5), 2.0, OL)
	draw_circle(neck_base + Vector2(0, 3.5), 1.3, gold_col)
	draw_circle(neck_base + Vector2(-0.3, 3.2), 0.5, gold_hi)
	# Starched collar points
	draw_line(neck_base + Vector2(-6, 1), neck_base + Vector2(-4, -1.5), OL, 3.0)
	draw_line(neck_base + Vector2(6, 1), neck_base + Vector2(4, -1.5), OL, 3.0)
	draw_line(neck_base + Vector2(-6, 1), neck_base + Vector2(-4, -1.5), shirt_col, 2.0)
	draw_line(neck_base + Vector2(6, 1), neck_base + Vector2(4, -1.5), shirt_col, 2.0)

	# === LEFT ARM (off-hand — holds walking cane, 2-segment with elbow) ===
	var l_shoulder = neck_base + Vector2(-13, 1)
	var l_elbow = torso_center + Vector2(-17, 4)
	var l_hand = torso_center + Vector2(-11, 10)
	# Shoulder cap OL -> fill
	draw_circle(l_shoulder, 5.0, OL)
	draw_circle(l_shoulder, 3.5, coat_col)
	# Upper arm OL -> fill
	var lua_d = (l_elbow - l_shoulder).normalized()
	var lua_p = lua_d.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		l_shoulder + lua_p * 5.0, l_shoulder - lua_p * 4.5,
		l_elbow - lua_p * 4.0, l_elbow + lua_p * 4.5,
	]), OL)
	draw_colored_polygon(PackedVector2Array([
		l_shoulder + lua_p * 3.5, l_shoulder - lua_p * 3.0,
		l_elbow - lua_p * 2.5, l_elbow + lua_p * 3.0,
	]), coat_col)
	# Elbow joint OL -> fill
	draw_circle(l_elbow, 4.5, OL)
	draw_circle(l_elbow, 3.2, coat_col)
	# Forearm OL -> fill
	var lfa_d = (l_hand - l_elbow).normalized()
	var lfa_p = lfa_d.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		l_elbow + lfa_p * 4.2, l_elbow - lfa_p * 4.0,
		l_hand - lfa_p * 3.0, l_hand + lfa_p * 3.2,
	]), OL)
	draw_colored_polygon(PackedVector2Array([
		l_elbow + lfa_p * 2.8, l_elbow - lfa_p * 2.5,
		l_hand - lfa_p * 1.8, l_hand + lfa_p * 2.0,
	]), coat_col)
	# White cuff OL -> fill
	draw_circle(l_hand + Vector2(0, -2), 3.8, OL)
	draw_circle(l_hand + Vector2(0, -2), 2.8, shirt_col)
	# Hand (round chibi) OL -> skin -> highlight
	draw_circle(l_hand, 4.2, OL)
	draw_circle(l_hand, 3.2, skin_base)
	draw_circle(l_hand + Vector2(-0.8, -0.8), 1.5, skin_highlight)
	# Fingers gripping cane
	draw_line(l_hand + Vector2(-1, 2), l_hand + Vector2(-2, 4.5), OL, 3.0)
	draw_line(l_hand + Vector2(1, 2), l_hand + Vector2(0, 5), OL, 3.0)
	draw_line(l_hand + Vector2(-1, 2), l_hand + Vector2(-2, 4.5), skin_base, 1.8)
	draw_line(l_hand + Vector2(1, 2), l_hand + Vector2(0, 5), skin_base, 1.8)

	# === WALKING CANE (left hand to ground) ===
	var cane_top = l_hand + Vector2(0, 2)
	var cane_bottom = Vector2(l_hand.x - 2, feet_y.y + 2)
	# Ebony shaft OL -> fill -> highlight
	draw_line(cane_top, cane_bottom, OL, 4.5)
	draw_line(cane_top, cane_bottom, Color(0.14, 0.10, 0.08), 2.8)
	draw_line(cane_top + Vector2(1, 0), cane_bottom + Vector2(1, 0), Color(0.25, 0.20, 0.18, 0.35), 1.0)
	# Gold crook handle OL -> fill -> sparkle
	draw_arc(cane_top + Vector2(3, -2), 5.0, PI * 0.5, PI * 1.5, 12, OL, 4.5)
	draw_arc(cane_top + Vector2(3, -2), 5.0, PI * 0.5, PI * 1.5, 12, gold_col, 2.8)
	draw_arc(cane_top + Vector2(3, -2), 4.0, PI * 0.6, PI * 1.3, 8, gold_hi, 1.2)
	# Metal ferrule OL -> fill
	draw_circle(cane_bottom, 2.8, OL)
	draw_circle(cane_bottom, 2.0, Color(0.55, 0.52, 0.48))
	draw_circle(cane_bottom + Vector2(-0.3, -0.4), 0.9, Color(0.75, 0.72, 0.68, 0.5))

	# === RIGHT ARM (weapon arm — swings bell toward target, 2-segment) ===
	var r_shoulder = neck_base + Vector2(13, 1)
	var attack_recoil = _attack_anim * 5.0
	var weapon_extend = dir * (14.0 + attack_recoil) + body_offset
	var r_elbow = r_shoulder + (weapon_extend - r_shoulder) * 0.5 + Vector2(0, 3)
	var r_hand = r_shoulder + (weapon_extend - r_shoulder) * 0.85
	# Shoulder cap OL -> fill
	draw_circle(r_shoulder, 5.0, OL)
	draw_circle(r_shoulder, 3.5, coat_col)
	# Upper arm OL -> fill
	var rua_d = (r_elbow - r_shoulder).normalized()
	var rua_p = rua_d.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		r_shoulder + rua_p * 4.5, r_shoulder - rua_p * 5.0,
		r_elbow - rua_p * 4.5, r_elbow + rua_p * 4.0,
	]), OL)
	draw_colored_polygon(PackedVector2Array([
		r_shoulder + rua_p * 3.0, r_shoulder - rua_p * 3.5,
		r_elbow - rua_p * 3.0, r_elbow + rua_p * 2.5,
	]), coat_col)
	# Elbow joint OL -> fill
	draw_circle(r_elbow, 4.5, OL)
	draw_circle(r_elbow, 3.2, coat_col)
	# Forearm OL -> fill
	var rfa_d = (r_hand - r_elbow).normalized()
	var rfa_p = rfa_d.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		r_elbow + rfa_p * 4.0, r_elbow - rfa_p * 4.2,
		r_hand - rfa_p * 3.2, r_hand + rfa_p * 3.0,
	]), OL)
	draw_colored_polygon(PackedVector2Array([
		r_elbow + rfa_p * 2.5, r_elbow - rfa_p * 2.8,
		r_hand - rfa_p * 2.0, r_hand + rfa_p * 1.8,
	]), coat_col)
	# White cuff OL -> fill
	draw_circle(r_hand + Vector2(0, -2), 3.8, OL)
	draw_circle(r_hand + Vector2(0, -2), 2.8, shirt_col)
	# Hand OL -> skin -> highlight
	draw_circle(r_hand, 4.2, OL)
	draw_circle(r_hand, 3.2, skin_base)
	draw_circle(r_hand + Vector2(-0.8, -0.8), 1.5, skin_highlight)

	# === BELL (weapon — held in right hand) ===
	var bell_base = r_hand + dir * 5.0
	var bell_perp_v = dir.rotated(PI / 2.0)
	# Bell body OL -> fill (trapezoid wider at mouth)
	draw_colored_polygon(PackedVector2Array([
		bell_base - bell_perp_v * 7.5 + dir * 1.0,
		bell_base + bell_perp_v * 7.5 + dir * 1.0,
		bell_base + bell_perp_v * 4.5 - dir * 11.0,
		bell_base - bell_perp_v * 4.5 - dir * 11.0,
	]), OL)
	draw_colored_polygon(PackedVector2Array([
		bell_base - bell_perp_v * 5.8 + dir * 0.5,
		bell_base + bell_perp_v * 5.8 + dir * 0.5,
		bell_base + bell_perp_v * 3.2 - dir * 9.5,
		bell_base - bell_perp_v * 3.2 - dir * 9.5,
	]), gold_col)
	# Inner highlight wedge
	draw_colored_polygon(PackedVector2Array([
		bell_base - bell_perp_v * 4.0,
		bell_base + bell_perp_v * 1.5,
		bell_base + bell_perp_v * 2.0 - dir * 8.0,
		bell_base - bell_perp_v * 2.5 - dir * 8.0,
	]), Color(gold_hi.r, gold_hi.g, gold_hi.b, 0.4))
	# Bold rim at mouth OL -> fill
	draw_line(bell_base - bell_perp_v * 7.0 + dir * 0.8, bell_base + bell_perp_v * 7.0 + dir * 0.8, OL, 4.0)
	draw_line(bell_base - bell_perp_v * 5.8 + dir * 0.8, bell_base + bell_perp_v * 5.8 + dir * 0.8, gold_dk, 2.5)
	# Handle on top (bold loop) OL -> fill
	var bell_top = bell_base - dir * 11.0
	draw_arc(bell_top, 4.0, 0, PI, 12, OL, 4.0)
	draw_arc(bell_top, 4.0, 0, PI, 12, gold_col, 2.5)
	# Clapper (swings on attack)
	var clapper_swing = sin(_time * 5.0 + _attack_anim * 8.0) * 2.5
	var clapper_pos = bell_base + bell_perp_v * clapper_swing
	draw_line(bell_base - dir * 5.0, clapper_pos, OL, 2.5)
	draw_line(bell_base - dir * 5.0, clapper_pos, gold_dk, 1.5)
	draw_circle(clapper_pos, 3.0, OL)
	draw_circle(clapper_pos, 2.2, gold_col)
	draw_circle(clapper_pos + Vector2(-0.3, -0.3), 1.0, gold_hi)

	# === ATTACK FLASH — bell ring shockwave + flying coins ===
	if _attack_anim > 0.2:
		var ring_alpha = _attack_anim * 0.6
		var ring_r = 15.0 + (1.0 - _attack_anim) * 50.0
		# Expanding golden shockwave rings
		draw_arc(Vector2.ZERO, ring_r, 0, TAU, 32, Color(0.92, 0.78, 0.15, ring_alpha), 3.5)
		draw_arc(Vector2.ZERO, ring_r * 0.7, 0, TAU, 24, Color(1.0, 0.9, 0.4, ring_alpha * 0.5), 2.5)
		draw_arc(Vector2.ZERO, ring_r * 0.45, 0, TAU, 16, Color(1.0, 0.95, 0.6, ring_alpha * 0.3), 1.5)
		# Flying gold coins (radiating outward)
		for ci in range(5):
			var coin_a = TAU * float(ci) / 5.0 + _time * 2.0
			var coin_r = ring_r * (0.5 + float(ci) * 0.1)
			var coin_p = Vector2.from_angle(coin_a) * coin_r
			var coin_sz = 3.5 - _attack_anim * 1.0
			draw_circle(coin_p, coin_sz + 1.2, OL)
			draw_circle(coin_p, coin_sz, gold_col)
			draw_circle(coin_p + Vector2(-0.4, -0.4), coin_sz * 0.35, gold_hi)
		# Sound wave arcs
		for i in range(4):
			var wave_a = TAU * float(i) / 4.0 + _time * 3.0
			var wave_r = ring_r * 0.85
			draw_arc(Vector2.from_angle(wave_a) * wave_r * 0.15, wave_r * 0.25, wave_a - 0.3, wave_a + 0.3, 6, Color(0.9, 0.8, 0.3, ring_alpha * 0.4), 2.0)

	# === NECK (thin elderly chibi connector with OL) ===
	var neck_top = head_center + Vector2(0, 10)
	var nk_d = (neck_top - neck_base).normalized()
	var nk_p = nk_d.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		neck_base + nk_p * 5.5, neck_base - nk_p * 5.5,
		neck_top - nk_p * 4.5, neck_top + nk_p * 4.5,
	]), OL)
	draw_colored_polygon(PackedVector2Array([
		neck_base + nk_p * 4.0, neck_base - nk_p * 4.0,
		neck_top - nk_p * 3.2, neck_top + nk_p * 3.2,
	]), skin_base)
	# Neck highlight
	draw_line(neck_base.lerp(neck_top, 0.2) + nk_p * 2.0, neck_base.lerp(neck_top, 0.8) + nk_p * 1.5, skin_highlight, 1.5)
	# Adam's apple bump
	var adams_pos = neck_base.lerp(neck_top, 0.4) + nk_p * 2.5
	draw_circle(adams_pos, 2.0, skin_shadow)
	draw_circle(adams_pos, 1.2, skin_base)

	# === HEAD (big round Bloons chibi head) ===
	# Head OL (14px) -> fill (12.5) -> face OL (12) -> skin (10.8)
	draw_circle(head_center, 14.0, OL)
	draw_circle(head_center, 12.5, skin_shadow)
	draw_circle(head_center, 12.0, OL)
	draw_circle(head_center, 10.8, skin_base)
	# Forehead highlight (Bloons top-left shine)
	draw_circle(head_center + Vector2(-2, -3.5), 5.0, Color(skin_highlight.r, skin_highlight.g, skin_highlight.b, 0.4))

	# === EARS (chibi round, bold outline) ===
	draw_circle(head_center + Vector2(-12, 1), 4.0, OL)
	draw_circle(head_center + Vector2(-12, 1), 3.0, skin_base)
	draw_circle(head_center + Vector2(-12, 1), 1.5, skin_shadow)
	draw_circle(head_center + Vector2(12, 1), 4.0, OL)
	draw_circle(head_center + Vector2(12, 1), 3.0, skin_base)
	draw_circle(head_center + Vector2(12, 1), 1.5, skin_shadow)

	# === BALDING HEAD WITH WHITE HAIR WISPS ===
	# Bald dome shine
	draw_circle(head_center + Vector2(-1.5, -6), 4.0, Color(0.94, 0.90, 0.85, 0.35))
	draw_circle(head_center + Vector2(-2, -7.5), 2.0, Color(1.0, 0.98, 0.94, 0.45))
	# Left side wisps (OL -> hair)
	for i in range(4):
		var ws = head_center + Vector2(-11, -4 + float(i) * 2.5)
		var we = ws + Vector2(-3.5 + sin(_time * 1.5 + float(i)) * 1.5, 2.5 + float(i) * 0.3)
		draw_line(ws, we, OL, 2.8)
		draw_line(ws, we, hair_col, 1.6)
	# Right side wisps
	for i in range(4):
		var ws = head_center + Vector2(11, -4 + float(i) * 2.5)
		var we = ws + Vector2(3.5 + sin(_time * 1.5 + float(i) + 1.0) * 1.5, 2.5 + float(i) * 0.3)
		draw_line(ws, we, OL, 2.8)
		draw_line(ws, we, hair_col, 1.6)
	# Back tuft wisps
	for i in range(3):
		var ts = head_center + Vector2(-2.5 + float(i) * 2.5, -11)
		var te = ts + Vector2(sin(_time * 1.0 + float(i)) * 2.0, -4.0)
		draw_line(ts, te, OL, 2.8)
		draw_line(ts, te, hair_col, 1.6)

	# === VICTORIAN TOP HAT (large, prominent — signature element!) ===
	var hat_base_y = head_center.y - 9
	var hat_cx = head_center.x
	# Wide brim (ellipse) OL -> fill
	draw_set_transform(Vector2(hat_cx, hat_base_y), 0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, 17.0, OL)
	draw_circle(Vector2.ZERO, 15.0, coat_col)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# Brim highlight
	draw_set_transform(Vector2(hat_cx, hat_base_y + 1), 0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, 14.0, Color(coat_hi.r, coat_hi.g, coat_hi.b, 0.3))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# Tall crown OL -> fill (~24px high — big and imposing!)
	var cr_bot = hat_base_y
	var cr_top = hat_base_y - 24
	draw_colored_polygon(PackedVector2Array([
		Vector2(hat_cx - 9, cr_bot), Vector2(hat_cx - 9, cr_top + 3),
		Vector2(hat_cx - 8, cr_top), Vector2(hat_cx + 8, cr_top),
		Vector2(hat_cx + 9, cr_top + 3), Vector2(hat_cx + 9, cr_bot),
	]), OL)
	draw_colored_polygon(PackedVector2Array([
		Vector2(hat_cx - 7, cr_bot - 0.5), Vector2(hat_cx - 7, cr_top + 2.5),
		Vector2(hat_cx - 6, cr_top + 1), Vector2(hat_cx + 6, cr_top + 1),
		Vector2(hat_cx + 7, cr_top + 2.5), Vector2(hat_cx + 7, cr_bot - 0.5),
	]), coat_col)
	# Crown left-side highlight
	draw_colored_polygon(PackedVector2Array([
		Vector2(hat_cx - 5.5, cr_bot - 1), Vector2(hat_cx - 5.5, cr_top + 2),
		Vector2(hat_cx + 1, cr_top + 2), Vector2(hat_cx + 1, cr_bot - 1),
	]), Color(coat_hi.r, coat_hi.g, coat_hi.b, 0.25))
	# Hat band OL -> fill
	draw_line(Vector2(hat_cx - 9, cr_bot - 1), Vector2(hat_cx + 9, cr_bot - 1), OL, 4.0)
	draw_line(Vector2(hat_cx - 8, cr_bot - 1), Vector2(hat_cx + 8, cr_bot - 1), Color(0.22, 0.18, 0.25), 2.5)
	# Gold buckle on band OL -> fill -> sparkle
	draw_rect(Rect2(Vector2(hat_cx - 3, cr_bot - 3.5), Vector2(6, 5)), OL, false, 1.5)
	draw_rect(Rect2(Vector2(hat_cx - 2, cr_bot - 3), Vector2(4, 4)), gold_col, true)
	draw_rect(Rect2(Vector2(hat_cx - 1, cr_bot - 2.5), Vector2(2, 3)), gold_hi, true)
	# Silk sheen diagonal
	draw_line(Vector2(hat_cx - 4.5, cr_top + 5), Vector2(hat_cx + 2, cr_bot - 3), Color(0.25, 0.22, 0.30, 0.2), 1.5)
	# Crown top ellipse OL -> fill
	draw_set_transform(Vector2(hat_cx, cr_top), 0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, 9.0, OL)
	draw_circle(Vector2.ZERO, 7.0, coat_col)
	draw_circle(Vector2.ZERO, 4.5, Color(coat_hi.r, coat_hi.g, coat_hi.b, 0.3))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	# === ROUND SPECTACLES (bold Bloons outlines on face) ===
	var l_lens = head_center + Vector2(-4.5, 1)
	var r_lens = head_center + Vector2(4.5, 1)
	# Frame OL -> wire
	draw_arc(l_lens, 5.5, 0, TAU, 16, OL, 2.5)
	draw_arc(r_lens, 5.5, 0, TAU, 16, OL, 2.5)
	draw_arc(l_lens, 5.5, 0, TAU, 16, Color(0.35, 0.30, 0.28), 1.5)
	draw_arc(r_lens, 5.5, 0, TAU, 16, Color(0.35, 0.30, 0.28), 1.5)
	# Bridge OL -> wire
	draw_line(l_lens + Vector2(4.5, -1), r_lens + Vector2(-4.5, -1), OL, 2.5)
	draw_line(l_lens + Vector2(4.5, -1), r_lens + Vector2(-4.5, -1), Color(0.35, 0.30, 0.28), 1.5)
	# Temple arms to ears OL -> wire
	draw_line(l_lens + Vector2(-5.5, 0), head_center + Vector2(-12, 0.5), OL, 2.0)
	draw_line(r_lens + Vector2(5.5, 0), head_center + Vector2(12, 0.5), OL, 2.0)
	draw_line(l_lens + Vector2(-5.5, 0), head_center + Vector2(-12, 0.5), Color(0.35, 0.30, 0.28), 1.2)
	draw_line(r_lens + Vector2(5.5, 0), head_center + Vector2(12, 0.5), Color(0.35, 0.30, 0.28), 1.2)
	# Lens fill (subtle blue glass tint)
	draw_circle(l_lens, 4.5, Color(0.72, 0.76, 0.88, 0.12))
	draw_circle(r_lens, 4.5, Color(0.72, 0.76, 0.88, 0.12))
	# Lens glare sparkle
	draw_circle(l_lens + Vector2(-1.5, -1.5), 1.5, Color(1.0, 1.0, 1.0, 0.35))
	draw_circle(r_lens + Vector2(-1.5, -1.5), 1.5, Color(1.0, 1.0, 1.0, 0.35))
	draw_circle(l_lens + Vector2(-2.0, -2.0), 0.7, Color(1.0, 1.0, 1.0, 0.55))
	draw_circle(r_lens + Vector2(-2.0, -2.0), 0.7, Color(1.0, 1.0, 1.0, 0.55))

	# === BIG BLOONS EYES (behind spectacles) ===
	var look_dir = dir * 1.2
	var l_eye = l_lens + Vector2(0, 0.5)
	var r_eye = r_lens + Vector2(0, 0.5)
	# Eye whites OL -> fill
	draw_circle(l_eye, 4.8, OL)
	draw_circle(l_eye, 4.0, Color(1.0, 1.0, 1.0))
	draw_circle(r_eye, 4.8, OL)
	draw_circle(r_eye, 4.0, Color(1.0, 1.0, 1.0))
	if is_kind:
		# Kind warm brown irises (transformed Scrooge)
		draw_circle(l_eye + look_dir, 2.8, Color(0.35, 0.22, 0.08))
		draw_circle(l_eye + look_dir, 2.2, Color(0.52, 0.38, 0.18))
		draw_circle(r_eye + look_dir, 2.8, Color(0.35, 0.22, 0.08))
		draw_circle(r_eye + look_dir, 2.2, Color(0.52, 0.38, 0.18))
		# Pupils
		draw_circle(l_eye + look_dir * 1.05, 1.2, Color(0.05, 0.04, 0.03))
		draw_circle(r_eye + look_dir * 1.05, 1.2, Color(0.05, 0.04, 0.03))
		# Big Bloons sparkle highlight (primary + secondary)
		draw_circle(l_eye + Vector2(-1.0, -1.2), 1.5, Color(1.0, 1.0, 1.0, 0.95))
		draw_circle(r_eye + Vector2(-1.0, -1.2), 1.5, Color(1.0, 1.0, 1.0, 0.95))
		draw_circle(l_eye + Vector2(1.0, 0.8), 0.7, Color(1.0, 1.0, 1.0, 0.5))
		draw_circle(r_eye + Vector2(1.0, 0.8), 0.7, Color(1.0, 1.0, 1.0, 0.5))
		# Gentle upper eyelid
		draw_arc(l_eye, 4.2, PI + 0.2, TAU - 0.2, 10, OL, 1.5)
		draw_arc(r_eye, 4.2, PI + 0.2, TAU - 0.2, 10, OL, 1.5)
		# Kind crinkle lines at corners
		draw_line(l_eye + Vector2(-3.5, -1.5), l_eye + Vector2(-5, -3), OL, 1.2)
		draw_line(r_eye + Vector2(3.5, -1.5), r_eye + Vector2(5, -3), OL, 1.2)
	else:
		# Stern cold grey-blue irises (suspicious squint)
		draw_circle(l_eye + look_dir, 2.8, Color(0.30, 0.32, 0.48))
		draw_circle(l_eye + look_dir, 2.2, Color(0.44, 0.46, 0.60))
		draw_circle(r_eye + look_dir, 2.8, Color(0.30, 0.32, 0.48))
		draw_circle(r_eye + look_dir, 2.2, Color(0.44, 0.46, 0.60))
		# Small suspicious pupils
		draw_circle(l_eye + look_dir * 1.05, 1.0, Color(0.05, 0.05, 0.08))
		draw_circle(r_eye + look_dir * 1.05, 1.0, Color(0.05, 0.05, 0.08))
		# Cold sparkle
		draw_circle(l_eye + Vector2(-1.0, -1.2), 1.4, Color(1.0, 1.0, 1.0, 0.9))
		draw_circle(r_eye + Vector2(-1.0, -1.2), 1.4, Color(1.0, 1.0, 1.0, 0.9))
		draw_circle(l_eye + Vector2(1.0, 0.8), 0.7, Color(1.0, 1.0, 1.0, 0.4))
		draw_circle(r_eye + Vector2(1.0, 0.8), 0.7, Color(1.0, 1.0, 1.0, 0.4))
		# Heavy squinting upper eyelid (angry)
		draw_arc(l_eye, 4.2, PI + 0.1, TAU - 0.1, 10, OL, 2.2)
		draw_arc(r_eye, 4.2, PI + 0.1, TAU - 0.1, 10, OL, 2.2)
		# Furrowed angry brow lines (bold)
		draw_line(l_eye + Vector2(-2.5, -4), l_eye + Vector2(2, -5.5), OL, 2.0)
		draw_line(r_eye + Vector2(-2, -5.5), r_eye + Vector2(2.5, -4), OL, 2.0)

	# === EYEBROWS (bold expressive — grumpy or kind) ===
	if is_kind:
		draw_line(l_eye + Vector2(-3, -5), l_eye + Vector2(2.5, -5.5), OL, 2.5)
		draw_line(r_eye + Vector2(-2.5, -5.5), r_eye + Vector2(3, -5), OL, 2.5)
		draw_line(l_eye + Vector2(-3, -5), l_eye + Vector2(2.5, -5.5), hair_col, 1.8)
		draw_line(r_eye + Vector2(-2.5, -5.5), r_eye + Vector2(3, -5), hair_col, 1.8)
	else:
		draw_line(l_eye + Vector2(-3.5, -4.5), l_eye + Vector2(2.5, -6), OL, 2.8)
		draw_line(r_eye + Vector2(-2.5, -6), r_eye + Vector2(3.5, -4.5), OL, 2.8)
		draw_line(l_eye + Vector2(-3.5, -4.5), l_eye + Vector2(2.5, -6), Color(0.72, 0.68, 0.62), 2.0)
		draw_line(r_eye + Vector2(-2.5, -6), r_eye + Vector2(3.5, -4.5), Color(0.72, 0.68, 0.62), 2.0)

	# === NOSE (prominent bulbous Bloons beak) ===
	var nose_pos = head_center + Vector2(0, 4)
	draw_circle(nose_pos, 3.2, OL)
	draw_circle(nose_pos, 2.3, skin_base)
	draw_circle(nose_pos + Vector2(-0.5, -0.5), 1.3, skin_highlight)
	# Nose bridge OL -> skin
	draw_line(head_center + Vector2(0, 0.5), nose_pos + Vector2(0, -1.5), OL, 2.5)
	draw_line(head_center + Vector2(0, 0.5), nose_pos + Vector2(0, -1.5), skin_shadow, 1.5)

	# === MOUTH / EXPRESSION ===
	var mouth_pos = head_center + Vector2(0, 7.5)
	if is_kind:
		# Warm gentle smile (transformed Scrooge)
		draw_arc(mouth_pos, 3.5, 0.25, PI - 0.25, 12, OL, 2.5)
		draw_arc(mouth_pos, 3.5, 0.25, PI - 0.25, 12, Color(0.65, 0.38, 0.30), 1.5)
		# Rosy warm cheeks
		draw_circle(head_center + Vector2(-7, 3.5), 3.0, Color(0.95, 0.52, 0.42, 0.25))
		draw_circle(head_center + Vector2(7, 3.5), 3.0, Color(0.95, 0.52, 0.42, 0.25))
	else:
		# Grumpy frown (bold Bloons style)
		draw_arc(mouth_pos, 3.2, PI + 0.3, TAU - 0.3, 10, OL, 2.5)
		draw_arc(mouth_pos, 3.2, PI + 0.3, TAU - 0.3, 10, Color(0.55, 0.30, 0.25), 1.5)
		# Thin pressed lip line
		draw_line(mouth_pos + Vector2(-4, 0), mouth_pos + Vector2(4, 0), OL, 2.0)
		draw_line(mouth_pos + Vector2(-3.5, 0), mouth_pos + Vector2(3.5, 0), Color(0.60, 0.38, 0.32), 1.2)
		# Grimace corner lines
		draw_line(mouth_pos + Vector2(-4, 0), mouth_pos + Vector2(-5, 2), OL, 1.5)
		draw_line(mouth_pos + Vector2(4, 0), mouth_pos + Vector2(5, 2), OL, 1.5)

	# === WRINKLE DETAILS (bold cartoon — fewer but bolder) ===
	# Forehead wrinkle
	draw_line(head_center + Vector2(-5, -6), head_center + Vector2(5, -6), Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.3), 1.2)
	# Nasolabial folds
	draw_line(nose_pos + Vector2(-2, 1.5), mouth_pos + Vector2(-4.5, -1), Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.22), 1.0)
	draw_line(nose_pos + Vector2(2, 1.5), mouth_pos + Vector2(4.5, -1), Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.22), 1.0)
	# Crow's feet
	draw_line(head_center + Vector2(-10, -1), head_center + Vector2(-12.5, -3), Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.25), 1.0)
	draw_line(head_center + Vector2(10, -1), head_center + Vector2(12.5, -3), Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.25), 1.0)

	# === BELL GLEAM on face (proximity lighting from held bell) ===
	var bell_light_pos = r_hand + dir * 5.0 + Vector2(0, -8)
	var face_dist = bell_light_pos.distance_to(head_center)
	var light_strength = clamp(1.0 - face_dist / 60.0, 0.0, 0.3)
	if light_strength > 0.05:
		draw_circle(head_center, 14.0, Color(0.92, 0.78, 0.25, light_strength * 0.12))
		draw_circle(torso_center, 16.0, Color(0.85, 0.70, 0.20, light_strength * 0.06))


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

	# === AWAITING ABILITY CHOICE INDICATOR ===
	if awaiting_ability_choice:
		var pulse = (sin(_time * 4.0) + 1.0) * 0.5
		draw_circle(Vector2.ZERO, 60.0 + pulse * 6.0, Color(0.85, 0.75, 0.3, 0.1 + pulse * 0.1))
		draw_arc(Vector2.ZERO, 60.0 + pulse * 6.0, 0, TAU, 32, Color(0.85, 0.75, 0.3, 0.3 + pulse * 0.3), 2.5)
		var font3 = _game_font
		draw_string(font3, Vector2(-16, -78), "!", HORIZONTAL_ALIGNMENT_CENTER, 32, 30, Color(0.85, 0.75, 0.3, 0.7 + pulse * 0.3))

	# === DAMAGE DEALT COUNTER ===
	if damage_dealt > 0:
		var font = _game_font
		var dmg_text = str(int(damage_dealt)) + " DMG"
		if stat_upgrade_level > 0:
			dmg_text += " • Lv." + str(stat_upgrade_level)
		draw_string(font, Vector2(-36, 56), dmg_text, HORIZONTAL_ALIGNMENT_LEFT, 160, 12, Color(1.0, 0.84, 0.0, 0.5))

	# === UPGRADE NAME FLASH ===
	if _upgrade_flash > 0.0 and _upgrade_name != "":
		var font2 = _game_font
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
