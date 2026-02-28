extends Node2D
## Sherlock Holmes — pure support/buff tower. Does NOT attack enemies.
## Buffs all towers in range with damage, speed, and range bonuses every 3 seconds.
## Ability: "Deduction" — auto-marks enemies in range, all towers deal +30% to marked targets.
## Tier 1: Elementary — stronger buffs, mark lasts 12s
## Tier 2: Piercing Insight — even stronger buffs + range buff to allies
## Tier 3: Multi-Mark — marks 2+ targets, powerful aura
## Tier 4: The Game is Afoot — legendary aura, all enemies auto-marked

# Base stats
var damage: float = 0.0  # Sherlock doesn't deal direct damage
var fire_rate: float = 0.0  # No direct attacks
var attack_range: float = 188.0
var fire_cooldown: float = 0.0
var aim_angle: float = 0.0
var target: Node2D = null
var gold_bonus: int = 1

# Targeting priority: 0=First, 1=Last, 2=Close, 3=Strong
var targeting_priority: int = 0

# Buff aura system — buffs towers in range every 3 seconds
var _buff_timer: float = 3.0
var _buff_cooldown: float = 3.0
var _buffed_tower_ids: Dictionary = {}  # instance_id -> tier_when_buffed
var _buff_flash: float = 0.0

# Animation timers
var _time: float = 0.0
var _attack_anim: float = 0.0

# Damage tracking and upgrades
var damage_dealt: float = 0.0
var upgrade_tier: int = 0
var _upgrade_flash: float = 0.0
var _upgrade_name: String = ""

# Tier 1: Faster Deduction — mark duration increases
var mark_duration: float = 8.0

# Tier 2: Piercing Insight — beam pierces
var pierce_count: int = 0

# Tier 3: Multi-Mark — simultaneous marks
var max_marks: int = 1
var _marked_enemies: Array = []
var _mark_timers: Array = []

# Tier 4: The Game is Afoot — auto-mark + damage boost
var auto_mark: bool = false
var personal_damage_bonus: float = 1.0
var _auto_mark_cooldown: float = 0.0  # Cooldown to prevent self-sustaining damage loop
const AUTO_MARK_COOLDOWN: float = 2.0  # Minimum seconds between auto-mark passes
const AUTO_MARK_BONUS_CAP: float = 2.0  # Cap the deduction bonus multiplier at 2x

# Deduction mark flash
var _deduction_flash: float = 0.0

# Kill tracking
var kill_count: int = 0

# Splash (unlockable via progressive abilities)
var splash_radius: float = 0.0

# Tier 1: A Study in Scarlet — marked enemies bleed (DoT)
var _bleed_dps: float = 0.0  # DPS applied to marked enemies

# Tier 2: The Hound of the Baskervilles — spectral hound attack
var _hound_timer: float = 12.0
var _hound_cooldown: float = 12.0
var _hound_flash: float = 0.0
var _hound_lunge_pos: Vector2 = Vector2.ZERO
var _hound_lunge_timer: float = 0.0

# Tier 3: The Speckled Band — venomous strike on strongest
var _venom_timer: float = 15.0
var _venom_cooldown: float = 15.0
var _venom_flash: float = 0.0

# Tier 4: The Final Problem — Reichenbach cascade AoE
var _cascade_timer: float = 20.0
var _cascade_cooldown: float = 20.0
var _cascade_flash: float = 0.0

# === PROGRESSIVE ABILITIES (9 tiers, unlocked via lifetime damage) ===
const PROG_ABILITY_NAMES = [
	"Baker Street Logic", "Observation", "The Science of Deduction", "Watson's Aid",
	"Disguise Master", "Violin Meditation", "Cocaine Clarity", "Reichenbach Gambit",
	"Consulting Detective"
]
const PROG_ABILITY_DESCS = [
	"Beam travels 25% faster, +10% damage",
	"Every 10s, reveal invisible/camouflaged enemies in range for 4s",
	"Every marked enemy takes additional 1% max HP/s as burn",
	"Every 25s, heal 1 life and boost nearest tower attack speed +20% for 5s",
	"Every 15s, become untargetable for 3s; attacks during deal 2x",
	"Every 20s, slow all enemies in range by 40% for 3s",
	"Every 12s, next shot deals 5x damage and marks on hit",
	"When health drops below 3, deal 10x damage to all enemies in range (once per wave)",
	"All towers on map gain +15% damage permanently while Sherlock is placed"
]
var prog_abilities: Array = [false, false, false, false, false, false, false, false, false]
# Ability timers
var _observation_timer: float = 10.0
var _watsons_aid_timer: float = 25.0
var _disguise_timer: float = 15.0
var _disguise_invis: float = 0.0
var _violin_timer: float = 20.0
var _cocaine_timer: float = 12.0
var _cocaine_ready: bool = false
var _reichenbach_used: bool = false
# Baker Street Logic (ability 0) — marks nearest enemy for bonus damage
var _baker_street_timer: float = 8.0
var _baker_street_cooldown: float = 8.0
var _baker_street_flash: float = 0.0
# Watson's Aid buff tracking — prevent infinite stacking
var _watson_buffed_tower_id: int = -1  # instance_id of currently watson-buffed tower
var _watson_buff_timer: float = 0.0  # Time remaining on Watson buff
# Consulting Detective tracking — prevent stacking
var _consulting_buffed_ids: Dictionary = {}  # instance_id -> true for towers we've buffed
# Disguise Master — evasion chance
var _disguise_evasion: bool = false  # True while disguise is active
# Visual flash timers
var _observation_flash: float = 0.0
var _violin_flash: float = 0.0
var _cocaine_flash: float = 0.0
var _reichenbach_flash: float = 0.0

const STAT_UPGRADE_INTERVAL: float = 1000.0
const ABILITY_THRESHOLD: float = 3500.0
var stat_upgrade_level: int = 0
var ability_chosen: bool = false
var awaiting_ability_choice: bool = false
const TIER_NAMES = [
	"A Study in Scarlet",
	"The Hound of the Baskervilles",
	"The Speckled Band",
	"The Final Problem"
]
const ABILITY_DESCRIPTIONS = [
	"Marked enemies bleed. Watson assists with +15% SPD aura",
	"Spectral hound lunges every 12s — 3x damage + fear",
	"Venomous strike every 15s — 5% max HP/s poison for 4s",
	"Reichenbach cascade every 20s — 5x AoE + 2s stun"
]
const TIER_COSTS = [170, 340, 600, 950]
var is_selected: bool = false
var base_cost: int = 0

# Sherlock doesn't use projectiles — pure support tower

# Violin pizzicato — plays every 3 seconds as buff pulse (Sherlock plays violin!)
var _violin_pizz_sound: AudioStreamWAV
var _violin_pizz_player: AudioStreamPlayer

# Ability sounds
var _deduction_sound: AudioStreamWAV
var _deduction_player: AudioStreamPlayer
var _hound_sound: AudioStreamWAV
var _hound_player: AudioStreamPlayer
var _venom_sound: AudioStreamWAV
var _venom_player: AudioStreamPlayer
var _cascade_sound: AudioStreamWAV
var _cascade_player: AudioStreamPlayer
var _upgrade_sound: AudioStreamWAV
var _upgrade_player: AudioStreamPlayer
# Progressive ability sounds
var _baker_logic_sound: AudioStreamWAV
var _baker_logic_player: AudioStreamPlayer
var _reichenbach_gambit_sound: AudioStreamWAV
var _reichenbach_gambit_player: AudioStreamPlayer
var _watson_aid_sound: AudioStreamWAV
var _watson_aid_player: AudioStreamPlayer
var _game_font: Font
var _main_node: Node2D = null

func _ready() -> void:
	_main_node = get_tree().get_first_node_in_group("main")
	_game_font = load("res://fonts/Cinzel.ttf")
	add_to_group("towers")
	_load_progressive_abilities()

	# Violin pizzicato — short plucked string (Sherlock plays violin in the novels!)
	# Rich, warm plucked tone on A4 (440 Hz) with body resonance
	var vp_rate := 44100
	var vp_dur := 0.35
	var vp_samples := PackedFloat32Array()
	vp_samples.resize(int(vp_rate * vp_dur))
	for i in vp_samples.size():
		var t := float(i) / vp_rate
		# Plucked string: sharp attack, warm decay with body resonance
		var pluck_env := exp(-t * 12.0) * 0.4
		var attack_snap := exp(-t * 200.0) * 0.15  # Initial snap of the pluck
		var freq := 440.0  # A4
		# Rich string harmonics (violin timbre)
		var fund := sin(TAU * freq * t)
		var h2 := sin(TAU * freq * 2.0 * t) * 0.45 * exp(-t * 15.0)
		var h3 := sin(TAU * freq * 3.0 * t) * 0.25 * exp(-t * 18.0)
		var h4 := sin(TAU * freq * 4.0 * t) * 0.12 * exp(-t * 22.0)
		var h5 := sin(TAU * freq * 5.0 * t) * 0.06 * exp(-t * 28.0)
		# Body resonance (warm low overtone)
		var body := sin(TAU * freq * 0.5 * t) * 0.08 * exp(-t * 8.0)
		# String noise on attack
		var snap_noise := sin(t * 8800.0) * attack_snap
		var s := (fund + h2 + h3 + h4 + h5 + body) * pluck_env + snap_noise
		vp_samples[i] = clampf(s, -1.0, 1.0)
	_violin_pizz_sound = _samples_to_wav(vp_samples, vp_rate)
	_violin_pizz_player = AudioStreamPlayer.new()
	_violin_pizz_player.stream = _violin_pizz_sound
	_violin_pizz_player.volume_db = -6.0
	add_child(_violin_pizz_player)

	# Deduction "a-ha!" chime — dramatic rising investigation reveal
	# Two-note motif: D5→A5 with magnifying glass lens flare shimmer
	var ded_rate := 44100
	var ded_dur := 0.6
	var ded_samples := PackedFloat32Array()
	ded_samples.resize(int(ded_rate * ded_dur))
	var ded_notes := [587.33, 880.0]  # D5, A5 — perfect fifth leap (revelation!)
	for i in ded_samples.size():
		var t := float(i) / ded_rate
		var freq: float
		var nt: float
		if t < 0.15:
			freq = ded_notes[0]
			nt = t
		else:
			freq = ded_notes[1]
			nt = t - 0.15
		var att := minf(nt * 80.0, 1.0)
		var dec := exp(-nt * 4.0)
		var env := att * dec * 0.35
		# Clear bell-like investigation tone
		var s := sin(TAU * freq * t) * 0.5
		s += sin(TAU * freq * 2.0 * t) * 0.3 * exp(-nt * 8.0)
		s += sin(TAU * freq * 3.0 * t) * 0.15 * exp(-nt * 12.0)
		# Glass lens shimmer (very high overtone, quick)
		s += sin(TAU * freq * 5.01 * t) * 0.06 * exp(-t * 15.0)
		# Sub-bass "weight" of discovery
		s += sin(TAU * freq * 0.5 * t) * 0.1 * exp(-nt * 6.0)
		ded_samples[i] = clampf(s * env, -1.0, 1.0)
	_deduction_sound = _samples_to_wav(ded_samples, ded_rate)
	_deduction_player = AudioStreamPlayer.new()
	_deduction_player.stream = _deduction_sound
	_deduction_player.volume_db = -5.0
	add_child(_deduction_player)

	# Hound howl — eerie low howl for the spectral hound lunge
	var hw_rate := 22050
	var hw_dur := 0.5
	var hw_samples := PackedFloat32Array()
	hw_samples.resize(int(hw_rate * hw_dur))
	for i in hw_samples.size():
		var t := float(i) / hw_rate
		var howl_freq := 180.0 + sin(t * 4.0) * 30.0  # Low wavering howl
		var att := minf(t * 12.0, 1.0)
		var dec := exp(-(t - 0.1) * 5.0) if t > 0.1 else 1.0
		var env := att * dec * 0.4
		var s := sin(TAU * howl_freq * t) * 0.5
		s += sin(TAU * howl_freq * 1.5 * t) * 0.2  # Fifth harmonic
		s += sin(TAU * howl_freq * 2.0 * t) * 0.1
		s += (randf() * 2.0 - 1.0) * 0.04  # Breath noise
		hw_samples[i] = clampf(s * env, -1.0, 1.0)
	_hound_sound = _samples_to_wav(hw_samples, hw_rate)
	_hound_player = AudioStreamPlayer.new()
	_hound_player.stream = _hound_sound
	_hound_player.volume_db = -5.0
	add_child(_hound_player)

	# Venom strike — sinister hiss with wet impact
	var vs_rate := 22050
	var vs_dur := 0.3
	var vs_samples := PackedFloat32Array()
	vs_samples.resize(int(vs_rate * vs_dur))
	for i in vs_samples.size():
		var t := float(i) / vs_rate
		# Hissing snake: filtered noise descending
		var hiss_env := exp(-t * 8.0) * 0.35
		var hiss := sin(t * 6400.0 + sin(t * 120.0) * 3.0) * 0.3
		hiss += (randf() * 2.0 - 1.0) * 0.4
		# Wet impact thud
		var thud := sin(TAU * 90.0 * t) * exp(-t * 40.0) * 0.3
		vs_samples[i] = clampf(hiss * hiss_env + thud, -1.0, 1.0)
	_venom_sound = _samples_to_wav(vs_samples, vs_rate)
	_venom_player = AudioStreamPlayer.new()
	_venom_player.stream = _venom_sound
	_venom_player.volume_db = -5.0
	add_child(_venom_player)

	# Reichenbach cascade — rushing waterfall + dramatic impact
	var rc_rate := 44100
	var rc_dur := 0.8
	var rc_samples := PackedFloat32Array()
	rc_samples.resize(int(rc_rate * rc_dur))
	for i in rc_samples.size():
		var t := float(i) / rc_rate
		# Rushing water (filtered noise with frequency sweep)
		var water_env := minf(t * 6.0, 1.0) * exp(-t * 2.5) * 0.3
		var water := sin(t * 3200.0 + sin(t * 80.0) * 8.0) * 0.3
		water += sin(t * 5100.0 + sin(t * 60.0) * 5.0) * 0.2
		water += (randf() * 2.0 - 1.0) * 0.35
		# Deep impact at 0.2s (waterfall hits)
		var impact_t := maxf(t - 0.2, 0.0)
		var impact := sin(TAU * 55.0 * impact_t) * exp(-impact_t * 8.0) * 0.4
		impact += sin(TAU * 110.0 * impact_t) * exp(-impact_t * 12.0) * 0.2
		# Dramatic orchestral swell
		var swell := sin(TAU * 220.0 * t) * exp(-t * 3.0) * 0.15
		swell += sin(TAU * 330.0 * t) * exp(-t * 4.0) * 0.08
		rc_samples[i] = clampf(water * water_env + impact + swell, -1.0, 1.0)
	_cascade_sound = _samples_to_wav(rc_samples, rc_rate)
	_cascade_player = AudioStreamPlayer.new()
	_cascade_player.stream = _cascade_sound
	_cascade_player.volume_db = -4.0
	add_child(_cascade_player)

	# Upgrade chime — bright ascending arpeggio (C5, E5, G5)
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

	# Baker Street Logic — deduction chime: bright bell-like "ding" with analytical shimmer
	var bl_rate := 44100
	var bl_dur := 0.45
	var bl_samples := PackedFloat32Array()
	bl_samples.resize(int(bl_rate * bl_dur))
	for i in bl_samples.size():
		var t := float(i) / bl_rate
		var env := minf(t * 120.0, 1.0) * exp(-t * 6.0) * 0.35
		# Clear bell tone on E5 (659 Hz) — "eureka" moment
		var freq := 659.25
		var s := sin(TAU * freq * t) * 0.5
		s += sin(TAU * freq * 2.0 * t) * 0.25 * exp(-t * 10.0)
		s += sin(TAU * freq * 3.0 * t) * 0.12 * exp(-t * 14.0)
		# Analytical sparkle (high shimmer)
		s += sin(TAU * freq * 5.0 * t) * 0.04 * exp(-t * 18.0)
		# Sub warmth
		s += sin(TAU * freq * 0.5 * t) * 0.08 * exp(-t * 5.0)
		bl_samples[i] = clampf(s * env, -1.0, 1.0)
	_baker_logic_sound = _samples_to_wav(bl_samples, bl_rate)
	_baker_logic_player = AudioStreamPlayer.new()
	_baker_logic_player.stream = _baker_logic_sound
	_baker_logic_player.volume_db = -5.0
	add_child(_baker_logic_player)

	# Reichenbach Gambit — dramatic crash: low orchestral hit + descending rumble
	var rg_rate := 44100
	var rg_dur := 0.7
	var rg_samples := PackedFloat32Array()
	rg_samples.resize(int(rg_rate * rg_dur))
	for i in rg_samples.size():
		var t := float(i) / rg_rate
		# Heavy orchestral impact
		var impact_env := exp(-t * 4.0) * 0.45
		var s := sin(TAU * 65.0 * t) * 0.5  # Deep bass
		s += sin(TAU * 130.0 * t) * 0.3 * exp(-t * 6.0)  # Octave
		s += sin(TAU * 195.0 * t) * 0.15 * exp(-t * 8.0)  # Fifth
		# Descending sweep (falling from Reichenbach)
		var sweep_freq := 400.0 * exp(-t * 3.0)
		s += sin(TAU * sweep_freq * t) * 0.2 * exp(-t * 5.0)
		# Crash noise
		s += (randf() * 2.0 - 1.0) * 0.25 * exp(-t * 6.0)
		rg_samples[i] = clampf(s * impact_env, -1.0, 1.0)
	_reichenbach_gambit_sound = _samples_to_wav(rg_samples, rg_rate)
	_reichenbach_gambit_player = AudioStreamPlayer.new()
	_reichenbach_gambit_player.stream = _reichenbach_gambit_sound
	_reichenbach_gambit_player.volume_db = -4.0
	add_child(_reichenbach_gambit_player)

	# Watson's Aid — friendly whistle: short ascending two-note whistle
	var wa_rate := 44100
	var wa_dur := 0.4
	var wa_samples := PackedFloat32Array()
	wa_samples.resize(int(wa_rate * wa_dur))
	for i in wa_samples.size():
		var t := float(i) / wa_rate
		# Two-note ascending whistle: G5 -> C6
		var freq_w: float
		if t < 0.18:
			freq_w = 783.99  # G5
		else:
			freq_w = 1046.5  # C6
		var nt_w := t if t < 0.18 else t - 0.18
		var env_w := minf(nt_w * 60.0, 1.0) * exp(-nt_w * 8.0) * 0.3
		# Pure whistle tone
		var s := sin(TAU * freq_w * t) * 0.6
		s += sin(TAU * freq_w * 2.0 * t) * 0.15 * exp(-nt_w * 12.0)
		# Breath noise
		s += (randf() * 2.0 - 1.0) * 0.03
		wa_samples[i] = clampf(s * env_w, -1.0, 1.0)
	_watson_aid_sound = _samples_to_wav(wa_samples, wa_rate)
	_watson_aid_player = AudioStreamPlayer.new()
	_watson_aid_player.stream = _watson_aid_sound
	_watson_aid_player.volume_db = -5.0
	add_child(_watson_aid_player)

func _process(delta: float) -> void:
	_time += delta
	_upgrade_flash = max(_upgrade_flash - delta * 0.5, 0.0)
	_deduction_flash = max(_deduction_flash - delta * 2.0, 0.0)
	_buff_flash = max(_buff_flash - delta * 2.0, 0.0)
	_attack_anim = max(_attack_anim - delta * 3.0, 0.0)

	# Track nearest enemy for beam visuals
	target = _find_nearest_enemy()
	if target:
		var desired = global_position.angle_to_point(target.global_position) + PI
		aim_angle = lerp_angle(aim_angle, desired, 5.0 * delta)

	# Buff aura — every 3 seconds, buff towers in range and mark enemies
	_buff_timer -= delta
	if _buff_timer <= 0.0:
		_buff_timer = _buff_cooldown
		_apply_buff_aura()
		_auto_mark_enemies()
		# Play maraca sound
		if _violin_pizz_player and not _is_sfx_muted():
			_violin_pizz_player.play()
		_buff_flash = 1.0
		_attack_anim = 1.0

	# Update mark timers
	_update_marks(delta)

	# Tier 4: Auto-mark with cooldown to prevent self-sustaining damage loop
	if auto_mark:
		_auto_mark_cooldown -= delta
		if _auto_mark_cooldown <= 0.0:
			_auto_mark_enemies()
			_auto_mark_cooldown = AUTO_MARK_COOLDOWN

	# Tier 1+: A Study in Scarlet — marked enemies bleed
	if _bleed_dps > 0.0:
		for enemy in _marked_enemies:
			if is_instance_valid(enemy) and enemy.has_method("take_damage"):
				var bleed_dmg := _bleed_dps * delta
				enemy.take_damage(bleed_dmg)
				register_damage(bleed_dmg)

	# Tier 2+: The Hound of the Baskervilles — spectral hound lunge
	if upgrade_tier >= 2:
		_hound_flash = maxf(_hound_flash - delta * 2.0, 0.0)
		_hound_lunge_timer = maxf(_hound_lunge_timer - delta * 3.0, 0.0)
		_hound_timer -= delta
		if _hound_timer <= 0.0 and _has_enemies_in_range():
			_hound_attack()
			_hound_timer = _hound_cooldown

	# Tier 3+: The Speckled Band — venomous strike
	if upgrade_tier >= 3:
		_venom_flash = maxf(_venom_flash - delta * 2.0, 0.0)
		_venom_timer -= delta
		if _venom_timer <= 0.0 and _has_enemies_in_range():
			_venom_strike()
			_venom_timer = _venom_cooldown

	# Tier 4: The Final Problem — Reichenbach cascade
	if upgrade_tier >= 4:
		_cascade_flash = maxf(_cascade_flash - delta * 1.5, 0.0)
		_cascade_timer -= delta
		if _cascade_timer <= 0.0 and _has_enemies_in_range():
			_reichenbach_cascade()
			_cascade_timer = _cascade_cooldown

	# Watson's Aid buff duration tracking (Bug #7)
	if _watson_buff_timer > 0.0:
		_watson_buff_timer -= delta
		if _watson_buff_timer <= 0.0:
			_remove_watson_buff()

	# Progressive abilities
	_process_progressive_abilities(delta)

	queue_redraw()

func _get_buff_values() -> Dictionary:
	# Returns buff percentages based on upgrade tier
	match upgrade_tier:
		0: return {"damage": 0.15, "attack_speed": 0.10}
		1: return {"damage": 0.20, "attack_speed": 0.15}
		2: return {"damage": 0.25, "attack_speed": 0.15, "range": 0.10}
		3: return {"damage": 0.30, "attack_speed": 0.20, "range": 0.15}
		4: return {"damage": 0.40, "attack_speed": 0.25, "range": 0.20}
	return {"damage": 0.15, "attack_speed": 0.10}

func _apply_buff_aura() -> void:
	var eff_range = attack_range * _range_mult()
	var buff_vals = _get_buff_values()
	var current_tier = upgrade_tier
	for tower in get_tree().get_nodes_in_group("towers"):
		if tower == self:
			continue
		if global_position.distance_to(tower.global_position) > eff_range:
			# Tower out of range — skip
			continue
		var tid = tower.get_instance_id()
		if _buffed_tower_ids.has(tid) and _buffed_tower_ids[tid] == current_tier:
			# Already buffed at this tier
			continue
		if _buffed_tower_ids.has(tid):
			# Tier changed — apply difference
			var old_buffs = _get_buff_for_tier(_buffed_tower_ids[tid])
			var diff = {}
			for key in buff_vals:
				diff[key] = buff_vals.get(key, 0.0) - old_buffs.get(key, 0.0)
			if tower.has_method("set_synergy_buff"):
				tower.set_synergy_buff(diff)
		else:
			# New tower in range — apply full buff
			if tower.has_method("set_synergy_buff"):
				tower.set_synergy_buff(buff_vals)
		_buffed_tower_ids[tid] = current_tier
	# Clean up invalid tower references
	var to_remove := []
	for tid in _buffed_tower_ids:
		if not is_instance_id_valid(tid):
			to_remove.append(tid)
	for tid in to_remove:
		_buffed_tower_ids.erase(tid)

func _get_buff_for_tier(tier: int) -> Dictionary:
	match tier:
		0: return {"damage": 0.15, "attack_speed": 0.10}
		1: return {"damage": 0.20, "attack_speed": 0.15}
		2: return {"damage": 0.25, "attack_speed": 0.15, "range": 0.10}
		3: return {"damage": 0.30, "attack_speed": 0.20, "range": 0.15}
		4: return {"damage": 0.40, "attack_speed": 0.25, "range": 0.20}
	return {"damage": 0.15, "attack_speed": 0.10}

func _update_marks(delta: float) -> void:
	var i = 0
	while i < _marked_enemies.size():
		_mark_timers[i] -= delta
		if _mark_timers[i] <= 0.0 or not is_instance_valid(_marked_enemies[i]):
			if is_instance_valid(_marked_enemies[i]) and "deduction_marked" in _marked_enemies[i]:
				_marked_enemies[i].deduction_marked = false
			_marked_enemies.remove_at(i)
			_mark_timers.remove_at(i)
		else:
			i += 1

func _auto_mark_enemies() -> void:
	var eff_range = attack_range * _range_mult()
	for enemy in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if enemy.has_method("is_targetable") and not enemy.is_targetable():
			continue
		if global_position.distance_to(enemy.global_position) < eff_range:
			if not enemy in _marked_enemies:
				_apply_mark_to_enemy(enemy)

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

func _find_strongest_enemy() -> Node2D:
	var enemies = (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies"))
	var strongest: Node2D = null
	var most_hp: float = 0.0
	var eff_range_val = attack_range * _range_mult()
	for enemy in enemies:
		if enemy.has_method("is_targetable") and not enemy.is_targetable():
			continue
		if global_position.distance_to(enemy.global_position) < eff_range_val:
			if enemy.health > most_hp:
				most_hp = enemy.health
				strongest = enemy
	return strongest

func _mark_enemy(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return
	# Check if already marked
	if enemy in _marked_enemies:
		# Refresh the timer
		var idx = _marked_enemies.find(enemy)
		_mark_timers[idx] = mark_duration
		return
	# Remove oldest mark if at limit
	if _marked_enemies.size() >= max_marks:
		var oldest = _marked_enemies[0]
		if is_instance_valid(oldest) and "deduction_marked" in oldest:
			oldest.deduction_marked = false
		_marked_enemies.remove_at(0)
		_mark_timers.remove_at(0)
	_apply_mark_to_enemy(enemy)

func _apply_mark_to_enemy(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return
	if enemy in _marked_enemies:
		return
	if "deduction_marked" in enemy:
		enemy.deduction_marked = true
	_marked_enemies.append(enemy)
	_mark_timers.append(mark_duration)
	_deduction_flash = 1.0
	if _deduction_player and not _is_sfx_muted():
		_deduction_player.play()

func register_damage(amount: float) -> void:
	damage_dealt += amount
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("register_tower_damage"):
		main.register_tower_damage(main.TowerType.SHERLOCK, amount)
	_check_upgrades()

func register_kill() -> void:
	kill_count += 1
	if kill_count % 10 == 0:
		var bonus = 3 + kill_count / 10
		var main = get_tree().get_first_node_in_group("main")
		if main:
			main.add_gold(bonus)
		_upgrade_flash = 1.0
		_upgrade_name = "Deduced %d gold!" % bonus

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
	attack_range += 4.5

func choose_ability(index: int) -> void:
	ability_chosen = true
	awaiting_ability_choice = false
	upgrade_tier = index + 1
	_apply_upgrade(upgrade_tier)
	_upgrade_flash = 3.0
	_upgrade_name = TIER_NAMES[index]

func _apply_upgrade(tier: int) -> void:
	match tier:
		1: # A Study in Scarlet — marked enemies bleed, Watson assists
			mark_duration = 12.0
			attack_range = 203.0
			gold_bonus = 2
			_bleed_dps = 3.0  # Marked enemies take 3 DPS bleed
		2: # The Hound of the Baskervilles — spectral hound lunges
			attack_range = 214.0
			gold_bonus = 2
			mark_duration = 14.0
			_hound_cooldown = 12.0
		3: # The Speckled Band — venomous strike on strongest
			max_marks = 2
			attack_range = 225.0
			gold_bonus = 3
			mark_duration = 16.0
			_venom_cooldown = 15.0
		4: # The Final Problem — Reichenbach cascade
			auto_mark = true
			attack_range = 240.0
			gold_bonus = 3
			max_marks = 99
			mark_duration = 20.0
			_cascade_cooldown = 20.0
	# Re-buff all towers at new tier
	_rebuff_all_towers()

func _rebuff_all_towers() -> void:
	# When Sherlock upgrades, re-apply buff differences to all tracked towers
	var new_buffs = _get_buff_values()
	for tid in _buffed_tower_ids:
		if not is_instance_id_valid(tid):
			continue
		var tower = instance_from_id(tid)
		if tower and tower.has_method("set_synergy_buff"):
			var old_tier = _buffed_tower_ids[tid]
			var old_buffs = _get_buff_for_tier(old_tier)
			var diff = {}
			for key in new_buffs:
				diff[key] = new_buffs.get(key, 0.0) - old_buffs.get(key, 0.0)
			tower.set_synergy_buff(diff)
			_buffed_tower_ids[tid] = upgrade_tier

func purchase_upgrade() -> bool:
	if upgrade_tier >= 4:
		return false
	var cost = TIER_COSTS[upgrade_tier]
	var main_node = get_tree().get_first_node_in_group("main")
	if not main_node or not main_node.spend_gold(cost):
		return false
	upgrade_tier += 1
	_apply_upgrade(upgrade_tier)
	_upgrade_flash = 3.0
	_upgrade_name = TIER_NAMES[upgrade_tier - 1]
	if _upgrade_player and not _is_sfx_muted(): _upgrade_player.play()
	return true

func get_tower_display_name() -> String:
	return "Sherlock Holmes"

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
	if main and main.survivor_progress.has(main.TowerType.SHERLOCK):
		var p = main.survivor_progress[main.TowerType.SHERLOCK]
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
	if prog_abilities[0]:  # Baker Street Logic: timer-based mark in _process_progressive_abilities
		pass
	if prog_abilities[8]:  # Consulting Detective: global +15% damage buff (no stacking)
		for tower in get_tree().get_nodes_in_group("towers"):
			if tower != self and tower.has_method("set_synergy_buff"):
				var tid = tower.get_instance_id()
				if not _consulting_buffed_ids.has(tid):
					tower.set_synergy_buff({"damage": 0.15})
					_consulting_buffed_ids[tid] = true

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
	_observation_flash = max(_observation_flash - delta * 2.0, 0.0)
	_violin_flash = max(_violin_flash - delta * 2.0, 0.0)
	_cocaine_flash = max(_cocaine_flash - delta * 1.5, 0.0)
	_reichenbach_flash = max(_reichenbach_flash - delta * 2.0, 0.0)
	_baker_street_flash = max(_baker_street_flash - delta * 2.0, 0.0)

	# Ability 1: Baker Street Logic — mark nearest enemy for bonus damage (Bug #1)
	if prog_abilities[0]:
		_baker_street_timer -= delta
		if _baker_street_timer <= 0.0 and _has_enemies_in_range():
			_baker_street_deduce()
			_baker_street_timer = _baker_street_cooldown

	# Ability 2: Observation — reveal invisible enemies
	if prog_abilities[1]:
		_observation_timer -= delta
		if _observation_timer <= 0.0 and _has_enemies_in_range():
			_observation_reveal()
			_observation_timer = 10.0

	# Ability 3: The Science of Deduction — burn damage on marked enemies
	if prog_abilities[2]:
		for enemy in _marked_enemies:
			if is_instance_valid(enemy) and enemy.has_method("take_damage"):
				var burn = enemy.get("max_health") if "max_health" in enemy else 100.0
				var burn_dmg = burn * 0.01 * delta
				enemy.take_damage(burn_dmg)
				register_damage(burn_dmg)

	# Ability 4: Watson's Aid — heal + boost nearest tower
	if prog_abilities[3]:
		_watsons_aid_timer -= delta
		if _watsons_aid_timer <= 0.0:
			_watsons_aid()
			_watsons_aid_timer = 25.0

	# Ability 5: Disguise Master — evasion cycle (Bug #4: now provides gameplay effect)
	if prog_abilities[4]:
		if _disguise_invis > 0.0:
			_disguise_invis -= delta
			_disguise_evasion = true  # Active evasion while disguised
			if _disguise_invis <= 0.0:
				_disguise_evasion = false
		else:
			_disguise_timer -= delta
			if _disguise_timer <= 0.0:
				_disguise_invis = 5.0  # 5 seconds of evasion
				_disguise_evasion = true
				_disguise_timer = 15.0

	# Ability 6: Violin Meditation — slow enemies
	if prog_abilities[5]:
		_violin_timer -= delta
		if _violin_timer <= 0.0 and _has_enemies_in_range():
			_violin_slow()
			_violin_timer = 20.0

	# Ability 7: Cocaine Clarity — charged shot (Bug #3: actually fire when ready)
	if prog_abilities[6]:
		if not _cocaine_ready:
			_cocaine_timer -= delta
			if _cocaine_timer <= 0.0:
				_cocaine_ready = true
				_cocaine_flash = 0.5
				_cocaine_timer = 12.0
		else:
			# Fire the charged shot at nearest enemy when ready
			if _has_enemies_in_range():
				_cocaine_strike()

	# Ability 8: Reichenbach Gambit — desperation nuke
	if prog_abilities[7] and not _reichenbach_used:
		var main = get_tree().get_first_node_in_group("main")
		if main and "lives" in main and main.lives <= 3:
			_reichenbach_strike()
			_reichenbach_used = true

func _observation_reveal() -> void:
	_observation_flash = 1.0
	for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if global_position.distance_to(e.global_position) < attack_range * _range_mult():
			if e.has_method("reveal"):
				e.reveal(4.0)

func _watsons_aid() -> void:
	# Play Watson whistle sound (Bug #10)
	if _watson_aid_player and not _is_sfx_muted():
		_watson_aid_player.play()
	# Heal 1 life
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("restore_life"):
		main.restore_life(1)
	# Remove previous Watson buff if still active (Bug #6: prevent infinite stacking)
	_remove_watson_buff()
	# Boost nearest tower attack speed
	var nearest_tower: Node2D = null
	var nearest_dist: float = 999999.0
	for tower in get_tree().get_nodes_in_group("towers"):
		if tower == self:
			continue
		var dist = global_position.distance_to(tower.global_position)
		if dist < nearest_dist:
			nearest_tower = tower
			nearest_dist = dist
	if nearest_tower and nearest_tower.has_method("set_synergy_buff"):
		nearest_tower.set_synergy_buff({"attack_speed": 0.20})
		_watson_buffed_tower_id = nearest_tower.get_instance_id()
		_watson_buff_timer = 5.0  # Bug #7: buff lasts 5 seconds

func _remove_watson_buff() -> void:
	# Remove the Watson attack speed buff from the previously buffed tower
	if _watson_buffed_tower_id >= 0 and is_instance_id_valid(_watson_buffed_tower_id):
		var old_tower = instance_from_id(_watson_buffed_tower_id)
		if old_tower and old_tower.has_method("set_synergy_buff"):
			old_tower.set_synergy_buff({"attack_speed": -0.20})
	_watson_buffed_tower_id = -1
	_watson_buff_timer = 0.0

func _violin_slow() -> void:
	_violin_flash = 1.0
	for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if global_position.distance_to(e.global_position) < attack_range * _range_mult():
			if e.has_method("apply_slow"):
				e.apply_slow(0.6, 3.0)

func _reichenbach_strike() -> void:
	_reichenbach_flash = 1.0
	# Play dramatic crash sound (Bug #10)
	if _reichenbach_gambit_player and not _is_sfx_muted():
		_reichenbach_gambit_player.play()
	for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if global_position.distance_to(e.global_position) < attack_range * _range_mult():
			if e.has_method("take_damage"):
				# Bug #2: damage was 0 because base damage is 0.0. Use flat 50 base * 10 * mult
				var dmg = 50.0 * _damage_mult() * 10.0
				e.take_damage(dmg)
				register_damage(dmg)

# Baker Street Logic — mark nearest enemy for 1.5x bonus damage from all towers (Bug #1)
func _baker_street_deduce() -> void:
	_baker_street_flash = 1.0
	# Play deduction chime (Bug #10)
	if _baker_logic_player and not _is_sfx_muted():
		_baker_logic_player.play()
	var nearest = _find_nearest_enemy()
	if nearest:
		# Mark the enemy with Sherlock's standard mark system
		_mark_enemy(nearest)
		# Also set the deduction_marked flag for bonus damage from all towers
		# This flag is checked by focus_beam.gd and other attack scripts for 1.3x bonus
		if "deduction_marked" in nearest:
			nearest.deduction_marked = true
		else:
			nearest.set("deduction_marked", true)
		# Apply damage multiplier mark (1.5x) for 5 seconds via enemy's mark system
		if nearest.has_method("apply_mark"):
			nearest.apply_mark(1.5, 5.0)

# Cocaine Clarity — charged 5x damage shot that marks on hit (Bug #3)
func _cocaine_strike() -> void:
	_cocaine_ready = false
	_cocaine_flash = 1.0
	var nearest = _find_nearest_enemy()
	if nearest and nearest.has_method("take_damage"):
		# 5x damage based on flat 50 base (Sherlock has 0 base damage)
		var dmg = 50.0 * _damage_mult() * 5.0
		nearest.take_damage(dmg)
		register_damage(dmg)
		# Mark on hit
		_mark_enemy(nearest)

# Disguise Master — evasion check (Bug #4: provides gameplay effect)
func has_evasion() -> bool:
	return _disguise_evasion

# === TIER ABILITY FUNCTIONS ===

func _hound_attack() -> void:
	if _hound_player and not _is_sfx_muted(): _hound_player.play()
	_hound_flash = 1.0
	# Spectral hound lunges at nearest enemy for 3x mark-boosted damage + fear
	var nearest = _find_nearest_enemy()
	if nearest and nearest.has_method("take_damage"):
		_hound_lunge_pos = nearest.global_position - global_position
		_hound_lunge_timer = 1.0
		var dmg = 45.0 * _damage_mult()  # Hound deals flat 45 × 3 = 135 effective
		nearest.take_damage(dmg * 3.0, true)
		register_damage(dmg * 3.0)
		# Fear: enemies near the target walk backwards for 2s
		for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
			if nearest.global_position.distance_to(e.global_position) < 60.0:
				if e.has_method("apply_slow"):
					e.apply_slow(-0.5, 2.0)  # Negative slow = walk backward

func _venom_strike() -> void:
	if _venom_player and not _is_sfx_muted(): _venom_player.play()
	_venom_flash = 1.0
	# Venomous strike on strongest enemy — 5% max HP/s poison for 4s
	var strongest = _find_strongest_enemy()
	if strongest:
		if strongest.has_method("apply_dot"):
			var hp = strongest.get("max_health") if "max_health" in strongest else 500.0
			var dps = hp * 0.05
			strongest.apply_dot(dps, 4.0)  # 5% max HP per second for 4s
			# Bug #5: Register the total expected DoT damage so it counts in damage_dealt
			register_damage(dps * 4.0)
		elif strongest.has_method("take_damage"):
			# Fallback: deal flat damage if no DoT method
			var hp = strongest.get("max_health") if "max_health" in strongest else 500.0
			strongest.take_damage(hp * 0.2)
			register_damage(hp * 0.2)

func _reichenbach_cascade() -> void:
	if _cascade_player and not _is_sfx_muted(): _cascade_player.play()
	_cascade_flash = 1.0
	# Reichenbach Falls cascade — 5x damage to all in range + 2s stun
	var eff_range_val = attack_range * _range_mult()
	for e in (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")):
		if global_position.distance_to(e.global_position) < eff_range_val:
			if e.has_method("take_damage"):
				var dmg = 50.0 * 5.0 * _damage_mult()  # Base 50 × 5 = 250
				e.take_damage(dmg, true)
				register_damage(dmg)
			if e.has_method("apply_sleep"):
				e.apply_sleep(2.0)

func _draw() -> void:
	# === 1. SELECTION RING ===
	var eff_range = attack_range * _range_mult()
	if is_selected:
		var pulse = (sin(_time * 3.0) + 1.0) * 0.5
		var ring_alpha = 0.5 + pulse * 0.3
		draw_circle(Vector2.ZERO, eff_range, Color(1.0, 1.0, 1.0, 0.04))
		draw_arc(Vector2.ZERO, eff_range, 0, TAU, 64, Color(0.85, 0.72, 0.25, 0.25 + pulse * 0.15), 2.0)
		draw_arc(Vector2.ZERO, 40.0, 0, TAU, 48, Color(0.85, 0.72, 0.25, ring_alpha), 2.5)
		draw_arc(Vector2.ZERO, 43.0, 0, TAU, 48, Color(0.85, 0.72, 0.25, ring_alpha * 0.4), 1.5)
	else:
		var aura_pulse = (sin(_time * 2.0) + 1.0) * 0.5
		draw_arc(Vector2.ZERO, eff_range, 0, TAU, 64, Color(0.85, 0.72, 0.25, 0.04 + aura_pulse * 0.04), 1.5)
	# Buff pulse ring expanding outward
	if _buff_flash > 0.0:
		var pulse_r = eff_range * (1.0 - _buff_flash * 0.3)
		draw_arc(Vector2.ZERO, pulse_r, 0, TAU, 48, Color(0.85, 0.72, 0.25, _buff_flash * 0.2), 2.5)
		draw_circle(Vector2.ZERO, pulse_r, Color(0.85, 0.72, 0.25, _buff_flash * 0.03))

	# === 3. FACING (support stance — faces center of buffed area) ===
	var dir = Vector2.from_angle(aim_angle)
	var perp = dir.rotated(PI / 2.0)

	# === 4. IDLE ANIMATION (analytical, observant stance) ===
	var breathe = sin(_time * 2.0) * 1.5
	var weight_shift = sin(_time * 1.0) * 1.5  # Slow subtle weight shift
	var thinking_bob = sin(_time * 1.5) * 1.0  # Slight head thinking bob
	var bob = Vector2(weight_shift, -breathe)

	# Tier 4: Elevated pose (legendary detective)
	var fly_offset = Vector2.ZERO
	if upgrade_tier >= 4:
		fly_offset = Vector2(0, -8.0 + sin(_time * 1.5) * 2.5)

	var body_offset = bob + fly_offset

	# Per-joint differential offsets
	var hip_shift = sin(_time * 1.0) * 1.0
	var shoulder_counter = -sin(_time * 1.0) * 0.6

	# === 5. SKIN COLORS ===
	var skin_base = Color(0.90, 0.78, 0.65)
	var skin_shadow = Color(0.76, 0.62, 0.50)
	var skin_highlight = Color(0.95, 0.85, 0.74)

	# === 6. UPGRADE FLASH ===
	if _upgrade_flash > 0.0:
		draw_circle(Vector2.ZERO, 80.0 + _upgrade_flash * 24.0, Color(0.85, 0.72, 0.25, _upgrade_flash * 0.25))

	# === 7. DEDUCTION FLASH ===
	if _deduction_flash > 0.0:
		var ded_ring_r = 30.0 + (1.0 - _deduction_flash) * 60.0
		draw_circle(Vector2.ZERO, ded_ring_r, Color(1.0, 0.92, 0.5, _deduction_flash * 0.12))
		draw_arc(Vector2.ZERO, ded_ring_r, 0, TAU, 32, Color(1.0, 0.88, 0.35, _deduction_flash * 0.3), 2.5)
		# Radiating golden insight rays
		for di in range(6):
			var da = TAU * float(di) / 6.0 + _deduction_flash * 3.0
			var d_inner = Vector2.from_angle(da) * (ded_ring_r * 0.4)
			var d_outer = Vector2.from_angle(da) * (ded_ring_r + 4.0)
			draw_line(d_inner, d_outer, Color(1.0, 0.90, 0.4, _deduction_flash * 0.35), 1.5)

	# === TIER ABILITY VISUALS ===
	# Hound lunge trail (Tier 2+)
	if _hound_lunge_timer > 0.0:
		var hound_alpha := _hound_lunge_timer
		# Spectral hound silhouette lunging toward target
		var lunge_dir := _hound_lunge_pos.normalized()
		var lunge_dist := _hound_lunge_pos.length() * (1.0 - _hound_lunge_timer)
		var hound_pos := lunge_dir * lunge_dist
		# Ghost hound body (green-blue spectral)
		draw_circle(hound_pos, 8.0, Color(0.2, 0.8, 0.4, hound_alpha * 0.4))
		draw_circle(hound_pos + lunge_dir * 6.0, 5.0, Color(0.3, 0.9, 0.5, hound_alpha * 0.5))  # Head
		# Glowing eyes
		var eye_perp := lunge_dir.rotated(PI / 2.0) * 2.0
		draw_circle(hound_pos + lunge_dir * 9.0 + eye_perp, 1.5, Color(1.0, 0.3, 0.1, hound_alpha * 0.8))
		draw_circle(hound_pos + lunge_dir * 9.0 - eye_perp, 1.5, Color(1.0, 0.3, 0.1, hound_alpha * 0.8))
		# Trail wisps
		for hi in range(4):
			var trail_pos := lunge_dir * (lunge_dist - float(hi) * 12.0)
			draw_circle(trail_pos, 3.0 - float(hi) * 0.5, Color(0.2, 0.7, 0.4, hound_alpha * 0.15))

	# Hound passive indicator (Tier 2+)
	if upgrade_tier >= 2 and _hound_lunge_timer <= 0.0:
		var h_pulse := (sin(_time * 2.0) + 1.0) * 0.5
		# Small spectral hound sitting beside tower
		draw_circle(Vector2(22, 10), 4.0, Color(0.2, 0.7, 0.4, 0.15 + h_pulse * 0.1))
		draw_circle(Vector2(25, 7), 3.0, Color(0.3, 0.8, 0.5, 0.2 + h_pulse * 0.1))
		# Eyes
		draw_circle(Vector2(27, 6), 1.0, Color(1.0, 0.3, 0.1, 0.3 + h_pulse * 0.2))

	# Venom flash (Tier 3+)
	if _venom_flash > 0.0:
		# Green poison expanding ring with snake-like trail
		var venom_r := 20.0 + (1.0 - _venom_flash) * 50.0
		draw_arc(Vector2.ZERO, venom_r, 0, TAU, 24, Color(0.1, 0.7, 0.2, _venom_flash * 0.35), 2.0)
		# Snake body segments spiraling outward
		for si in range(6):
			var sa := _venom_flash * 4.0 + float(si) * 1.0
			var sr := 10.0 + float(si) * 8.0
			var spos := Vector2.from_angle(sa) * sr
			draw_circle(spos, 2.5 - float(si) * 0.3, Color(0.15, 0.6, 0.15, _venom_flash * 0.4))

	# Cascade flash (Tier 4)
	if _cascade_flash > 0.0:
		# Reichenbach Falls waterfall cascading downward
		var cascade_alpha := _cascade_flash
		# Blue water rings expanding
		var c_r1 := 30.0 + (1.0 - cascade_alpha) * 80.0
		var c_r2 := 20.0 + (1.0 - cascade_alpha) * 60.0
		draw_arc(Vector2.ZERO, c_r1, 0, TAU, 32, Color(0.3, 0.5, 0.9, cascade_alpha * 0.3), 3.0)
		draw_arc(Vector2.ZERO, c_r2, 0, TAU, 32, Color(0.4, 0.6, 1.0, cascade_alpha * 0.2), 2.0)
		# Water spray droplets
		for wi in range(8):
			var wa := TAU * float(wi) / 8.0 + cascade_alpha * 2.0
			var wr := c_r1 * 0.7
			var wpos := Vector2.from_angle(wa) * wr
			draw_circle(wpos, 2.0, Color(0.5, 0.7, 1.0, cascade_alpha * 0.4))
		# Mist at base
		draw_circle(Vector2(0, 15), 25.0 * (1.0 - cascade_alpha * 0.5), Color(0.6, 0.75, 1.0, cascade_alpha * 0.1))

	# === MARK INDICATORS (floating above marked enemies) ===
	for mi in range(_marked_enemies.size()):
		if is_instance_valid(_marked_enemies[mi]):
			var mark_pos = _marked_enemies[mi].global_position - global_position
			var mark_pulse = sin(_time * 4.0 + float(mi)) * 2.0
			# Magnifying glass icon over marked enemy
			draw_arc(mark_pos + Vector2(0, -20 + mark_pulse), 6.0, 0, TAU, 12, Color(1.0, 0.85, 0.3, 0.6), 1.5)
			draw_circle(mark_pos + Vector2(0, -20 + mark_pulse), 5.0, Color(1.0, 0.92, 0.5, 0.15))
			draw_line(mark_pos + Vector2(4, -16 + mark_pulse), mark_pos + Vector2(8, -12 + mark_pulse), Color(0.85, 0.72, 0.25, 0.5), 1.5)

	# === PROGRESSIVE ABILITY VISUAL EFFECTS ===
	# Ability 2: Observation flash
	if _observation_flash > 0.0:
		var obs_r = 25.0 + (1.0 - _observation_flash) * 80.0
		draw_arc(Vector2.ZERO, obs_r, 0, TAU, 24, Color(1.0, 1.0, 0.8, _observation_flash * 0.3), 2.0)
		# Eye symbol at center
		draw_arc(Vector2(0, -50), 5.0, PI * 0.2, PI * 0.8, 8, Color(1.0, 0.95, 0.6, _observation_flash * 0.5), 1.5)
		draw_arc(Vector2(0, -50), 5.0, PI * 1.2, PI * 1.8, 8, Color(1.0, 0.95, 0.6, _observation_flash * 0.5), 1.5)

	# Ability 5: Disguise Master invisibility
	if prog_abilities[4] and _disguise_invis > 0.0:
		draw_circle(Vector2.ZERO, 28.0, Color(0.4, 0.4, 0.5, 0.12))

	# Ability 6: Violin Meditation flash
	if _violin_flash > 0.0:
		for vi in range(5):
			var va = TAU * float(vi) / 5.0 + _violin_flash * 2.0
			var v_r = 20.0 + (1.0 - _violin_flash) * 40.0
			var vpos = Vector2.from_angle(va) * v_r
			# Musical note symbols
			draw_circle(vpos, 2.5, Color(0.6, 0.5, 0.3, _violin_flash * 0.4))
			draw_line(vpos + Vector2(2, 0), vpos + Vector2(2, -5), Color(0.6, 0.5, 0.3, _violin_flash * 0.3), 0.8)

	# Ability 7: Cocaine Clarity ready indicator
	if prog_abilities[6] and _cocaine_ready:
		var cc_pulse = sin(_time * 6.0) * 0.15
		draw_circle(body_offset + Vector2(0, -45), 4.0, Color(1.0, 1.0, 0.9, 0.3 + cc_pulse))
		draw_arc(body_offset + Vector2(0, -45), 5.0, 0, TAU, 10, Color(1.0, 0.95, 0.7, 0.4 + cc_pulse), 1.0)

	# Ability 1: Baker Street Logic flash
	if _baker_street_flash > 0.0:
		var bs_r = 15.0 + (1.0 - _baker_street_flash) * 45.0
		draw_arc(Vector2.ZERO, bs_r, 0, TAU, 20, Color(1.0, 0.95, 0.5, _baker_street_flash * 0.35), 2.0)
		# Magnifying glass burst rays
		for bsi in range(4):
			var bsa = TAU * float(bsi) / 4.0 + _baker_street_flash * 2.0
			var bs_inner = Vector2.from_angle(bsa) * (bs_r * 0.5)
			var bs_outer = Vector2.from_angle(bsa) * (bs_r + 3.0)
			draw_line(bs_inner, bs_outer, Color(1.0, 0.90, 0.4, _baker_street_flash * 0.4), 1.5)

	# Ability 8: Reichenbach flash
	if _reichenbach_flash > 0.0:
		draw_circle(Vector2.ZERO, 60.0 * (1.0 - _reichenbach_flash * 0.3), Color(1.0, 0.5, 0.2, _reichenbach_flash * 0.3))
		draw_arc(Vector2.ZERO, 50.0 + (1.0 - _reichenbach_flash) * 30.0, 0, TAU, 24, Color(1.0, 0.6, 0.1, _reichenbach_flash * 0.4), 3.0)

	# === 8. STONE PLATFORM ===
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

	# Magnifying glass emblem on platform
	var emblem_y = plat_y + 1.0
	draw_set_transform(Vector2(0, emblem_y), 0, Vector2(1.0, 0.45))
	draw_arc(Vector2(-2, 0), 8.0, 0, TAU, 12, Color(0.85, 0.72, 0.25, 0.2), 1.2)
	draw_line(Vector2(4, 5), Vector2(9, 10), Color(0.85, 0.72, 0.25, 0.15), 1.5)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	# === 9. SHADOW TENDRILS ===
	for ti in range(5):
		var ta = TAU * float(ti) / 5.0 + _time * 0.3
		var t_base = Vector2(cos(ta) * 24.0, plat_y + sin(ta) * 8.0)
		var t_end = t_base + Vector2(sin(_time * 0.8 + float(ti)) * 6.0, 8.0 + sin(_time * 1.2 + float(ti)) * 4.0)
		draw_line(t_base, t_end, Color(0.04, 0.02, 0.06, 0.2), 2.0)
		draw_line(t_end, t_end + Vector2(sin(_time + float(ti)) * 3.0, 5.0), Color(0.04, 0.02, 0.06, 0.1), 1.5)

	# === 10. TIER PIPS (amber/gold theme) ===
	for i in range(upgrade_tier):
		var pip_angle = -PI / 2.0 + float(i) * (TAU / 4.0) - (float(upgrade_tier - 1) * TAU / 8.0)
		var pip_pos = Vector2(cos(pip_angle) * 22.0, plat_y + sin(pip_angle) * 8.0)
		var pip_col: Color
		match i:
			0: pip_col = Color(0.85, 0.72, 0.25)   # amber gold
			1: pip_col = Color(0.7, 0.75, 0.82)     # silver insight
			2: pip_col = Color(0.90, 0.80, 0.30)    # bright gold
			3: pip_col = Color(1.0, 0.90, 0.40)     # legendary gold
		draw_circle(pip_pos, 4.0, pip_col)
		draw_circle(pip_pos, 5.5, Color(pip_col.r, pip_col.g, pip_col.b, 0.15))

	# === 11. CHARACTER POSITIONS (BTD6 chibi proportions) ===
	var OL = Color(0.06, 0.06, 0.08)
	var hip_sway = hip_shift
	var chest_breathe = breathe
	var feet_y = body_offset + Vector2(hip_sway * 1.0, 10.0)
	var leg_top = body_offset + Vector2(hip_sway * 0.6, 0.0)
	var torso_center = body_offset + Vector2(hip_sway * 0.3, -8.0 - chest_breathe * 0.5)
	var neck_base = body_offset + Vector2(hip_sway * 0.15, -14.0 - chest_breathe * 0.3)
	var head_center = body_offset + Vector2(hip_sway * 0.08, -26.0)

	# Saturated color palette
	var tweed_dark = Color(0.38, 0.26, 0.12)
	var tweed_mid = Color(0.52, 0.38, 0.18)
	var tweed_light = Color(0.62, 0.48, 0.26)
	var trouser_col = Color(0.40, 0.32, 0.18)
	var trouser_hi = Color(0.50, 0.40, 0.24)
	var shirt_col = Color(0.94, 0.92, 0.88)
	var shoe_col = Color(0.22, 0.14, 0.08)
	var shoe_hi = Color(0.34, 0.22, 0.12)
	var brass_col = Color(0.85, 0.68, 0.18)
	var brass_hi = Color(1.0, 0.88, 0.35)

	# === 12. TIER-SPECIFIC EFFECTS (drawn BEFORE/AROUND body) ===

	# Tier 1+: Faint golden motes around magnifying glass area
	if upgrade_tier >= 1:
		for li in range(4 + upgrade_tier):
			var la = _time * (0.5 + fmod(float(li) * 1.37, 0.4)) + float(li) * TAU / float(4 + upgrade_tier)
			var lr = 18.0 + fmod(float(li) * 3.7, 12.0)
			var sparkle_pos = body_offset + Vector2(cos(la) * lr + 15.0, sin(la) * lr * 0.5 - 5.0)
			var sparkle_alpha = 0.18 + sin(_time * 2.0 + float(li)) * 0.1
			draw_circle(sparkle_pos, 1.5, Color(1.0, 0.90, 0.40, sparkle_alpha))
			draw_circle(sparkle_pos, 0.7, Color(1.0, 0.95, 0.7, sparkle_alpha * 0.8))

	# Tier 2+: Visible beam line from lens when targeting
	if upgrade_tier >= 2 and target:
		var beam_alpha = 0.08 + sin(_time * 4.0) * 0.04
		var beam_end_t = (target.global_position - global_position).normalized() * 60.0
		draw_line(body_offset + Vector2(18, -8), beam_end_t, Color(1.0, 0.92, 0.5, beam_alpha), 2.0)
		draw_line(body_offset + Vector2(18, -8), beam_end_t, Color(1.0, 0.97, 0.8, beam_alpha * 0.5), 1.0)

	# Tier 3+: Dual orbiting magnifying glass icons
	if upgrade_tier >= 3:
		for mi_vis in range(2):
			var ma_vis = _time * 0.8 + float(mi_vis) * PI
			var m_pos = body_offset + Vector2(cos(ma_vis) * 32.0, sin(ma_vis) * 12.0 - 5.0)
			var m_alpha = 0.18 + sin(_time * 2.5 + float(mi_vis) * 1.5) * 0.1
			draw_arc(m_pos, 4.0, 0, TAU, 10, Color(0.85, 0.72, 0.25, m_alpha), 1.2)
			draw_line(m_pos + Vector2(3, 3), m_pos + Vector2(6, 6), Color(0.85, 0.72, 0.25, m_alpha * 0.7), 1.0)

	# Tier 4: Floating evidence papers
	if upgrade_tier >= 4:
		for ep in range(6):
			var ep_seed = float(ep) * 2.37
			var ep_angle = _time * (0.4 + fmod(ep_seed, 0.3)) + ep_seed
			var ep_radius = 35.0 + fmod(ep_seed * 5.3, 20.0)
			var ep_pos = body_offset + Vector2(cos(ep_angle) * ep_radius, sin(ep_angle) * ep_radius * 0.6)
			var ep_alpha = 0.25 + sin(_time * 2.0 + ep_seed * 2.0) * 0.12
			var ep_rot = _time * 1.5 + ep_seed
			var p_dir_e = Vector2.from_angle(ep_rot)
			var p_perp_e = p_dir_e.rotated(PI / 2.0)
			var paper_pts = PackedVector2Array([
				ep_pos - p_dir_e * 3.5 - p_perp_e * 2.5,
				ep_pos + p_dir_e * 3.5 - p_perp_e * 2.5,
				ep_pos + p_dir_e * 3.5 + p_perp_e * 2.5,
				ep_pos - p_dir_e * 3.5 + p_perp_e * 2.5,
			])
			draw_colored_polygon(paper_pts, Color(0.95, 0.92, 0.85, ep_alpha))
			draw_line(ep_pos - p_dir_e * 2.0, ep_pos + p_dir_e * 1.5, Color(0.3, 0.3, 0.3, ep_alpha * 0.5), 0.6)

	# === 13. CHARACTER BODY (BTD6 Cartoon Style) ===

	# --- CHUNKY SHOES (brown leather) ---
	var l_foot = feet_y + Vector2(-5, 0)
	var r_foot = feet_y + Vector2(5, 0)
	# Left shoe: outline then fill
	draw_circle(l_foot, 6.0, OL)
	draw_circle(l_foot, 4.5, shoe_col)
	draw_circle(l_foot + Vector2(-3, 0), 4.5, OL)
	draw_circle(l_foot + Vector2(-3, 0), 3.2, shoe_hi)
	# Right shoe: outline then fill
	draw_circle(r_foot, 6.0, OL)
	draw_circle(r_foot, 4.5, shoe_col)
	draw_circle(r_foot + Vector2(3, 0), 4.5, OL)
	draw_circle(r_foot + Vector2(3, 0), 3.2, shoe_hi)
	# Shoe soles (bold dark line)
	draw_line(l_foot + Vector2(-6, 2), l_foot + Vector2(3, 2), OL, 2.5)
	draw_line(r_foot + Vector2(-3, 2), r_foot + Vector2(6, 2), OL, 2.5)
	# Shoe shine
	draw_circle(l_foot + Vector2(-2, -1), 1.2, Color(0.45, 0.32, 0.18, 0.4))
	draw_circle(r_foot + Vector2(2, -1), 1.2, Color(0.45, 0.32, 0.18, 0.4))

	# --- CHUNKY LEGS (tan trousers) ---
	var l_hip = leg_top + Vector2(-4, 0)
	var r_hip = leg_top + Vector2(4, 0)
	var l_knee = l_foot.lerp(l_hip, 0.45) + Vector2(-1, 0)
	var r_knee = r_foot.lerp(r_hip, 0.45) + Vector2(1, 0)
	# Left leg: outline then fill
	draw_line(l_hip, l_knee, OL, 10.0)
	draw_line(l_knee, l_foot + Vector2(0, -2), OL, 9.0)
	draw_line(l_hip, l_knee, trouser_col, 7.5)
	draw_line(l_knee, l_foot + Vector2(0, -2), trouser_col, 6.5)
	draw_line(l_hip + Vector2(-1, 0), l_knee + Vector2(-1, 0), trouser_hi, 2.0)
	# Left knee
	draw_circle(l_knee, 5.0, OL)
	draw_circle(l_knee, 3.8, trouser_col)
	# Right leg: outline then fill
	draw_line(r_hip, r_knee, OL, 10.0)
	draw_line(r_knee, r_foot + Vector2(0, -2), OL, 9.0)
	draw_line(r_hip, r_knee, trouser_col, 7.5)
	draw_line(r_knee, r_foot + Vector2(0, -2), trouser_col, 6.5)
	draw_line(r_hip + Vector2(1, 0), r_knee + Vector2(1, 0), trouser_hi, 2.0)
	# Right knee
	draw_circle(r_knee, 5.0, OL)
	draw_circle(r_knee, 3.8, trouser_col)

	# --- TORSO (tweed coat — rich brown) ---
	# Coat body outline
	var coat_pts_ol = PackedVector2Array([
		leg_top + Vector2(-10, 2),
		torso_center + Vector2(-14, 0),
		neck_base + Vector2(-14, 0),
		neck_base + Vector2(14, 0),
		torso_center + Vector2(14, 0),
		leg_top + Vector2(10, 2),
	])
	draw_colored_polygon(coat_pts_ol, OL)
	# Coat fill
	var coat_pts = PackedVector2Array([
		leg_top + Vector2(-8.5, 1),
		torso_center + Vector2(-12.5, 0),
		neck_base + Vector2(-12.5, 0),
		neck_base + Vector2(12.5, 0),
		torso_center + Vector2(12.5, 0),
		leg_top + Vector2(8.5, 1),
	])
	draw_colored_polygon(coat_pts, tweed_dark)
	# Coat highlight panel
	var coat_hi_pts = PackedVector2Array([
		torso_center + Vector2(-6, -1),
		neck_base + Vector2(-6, 1),
		neck_base + Vector2(6, 1),
		torso_center + Vector2(6, -1),
	])
	draw_colored_polygon(coat_hi_pts, tweed_mid)
	# Tweed check pattern on coat
	for ci in range(5):
		var cx = -8.0 + float(ci) * 4.0
		var c_top = neck_base + Vector2(cx, 1)
		var c_bot = torso_center + Vector2(cx, -1)
		draw_line(c_top, c_bot, Color(tweed_light.r, tweed_light.g, tweed_light.b, 0.25), 0.8)
	for ci2 in range(3):
		var cy2 = 0.25 + float(ci2) * 0.35
		var c_l = neck_base.lerp(torso_center, cy2) + Vector2(-11, 0)
		var c_r = neck_base.lerp(torso_center, cy2) + Vector2(11, 0)
		draw_line(c_l, c_r, Color(tweed_light.r, tweed_light.g, tweed_light.b, 0.2), 0.6)
	# White shirt V at collar
	draw_colored_polygon(PackedVector2Array([
		neck_base + Vector2(-4, 1),
		neck_base + Vector2(4, 1),
		neck_base + Vector2(0, 6),
	]), OL)
	draw_colored_polygon(PackedVector2Array([
		neck_base + Vector2(-3, 1.5),
		neck_base + Vector2(3, 1.5),
		neck_base + Vector2(0, 5),
	]), shirt_col)
	# Coat lapels (darker brown overlapping collar)
	var lapel_l = PackedVector2Array([
		neck_base + Vector2(-12.5, 0),
		neck_base + Vector2(-4, 2),
		torso_center + Vector2(-5, -1),
		torso_center + Vector2(-12, 0),
	])
	draw_colored_polygon(lapel_l, tweed_mid)
	draw_line(neck_base + Vector2(-4, 2), torso_center + Vector2(-5, -1), OL, 1.5)
	var lapel_r = PackedVector2Array([
		neck_base + Vector2(12.5, 0),
		neck_base + Vector2(4, 2),
		torso_center + Vector2(5, -1),
		torso_center + Vector2(12, 0),
	])
	draw_colored_polygon(lapel_r, tweed_mid)
	draw_line(neck_base + Vector2(4, 2), torso_center + Vector2(5, -1), OL, 1.5)
	# Coat buttons (2 bold brass)
	for bi in range(2):
		var bt = 0.35 + float(bi) * 0.3
		var btn_pos = leg_top.lerp(neck_base, bt)
		draw_circle(btn_pos, 2.2, OL)
		draw_circle(btn_pos, 1.6, brass_col)
		draw_circle(btn_pos + Vector2(-0.3, -0.3), 0.7, brass_hi)
	# Coat hem outline
	draw_line(leg_top + Vector2(-10, 2), leg_top + Vector2(10, 2), OL, 2.0)
	# Darker collar fold
	draw_line(neck_base + Vector2(-12, 0), neck_base + Vector2(12, 0), OL, 2.0)

	# --- SHOULDERS (chunky round) ---
	var l_shoulder = neck_base + Vector2(-12, 0)
	var r_shoulder = neck_base + Vector2(12, 0)
	draw_circle(l_shoulder, 7.0, OL)
	draw_circle(l_shoulder, 5.5, tweed_dark)
	draw_circle(l_shoulder + Vector2(-0.5, -0.5), 3.0, tweed_mid)
	draw_circle(r_shoulder, 7.0, OL)
	draw_circle(r_shoulder, 5.5, tweed_dark)
	draw_circle(r_shoulder + Vector2(0.5, -0.5), 3.0, tweed_mid)

	# --- LEFT ARM (holds magnifying glass — extends on attack) ---
	var glass_angle = aim_angle + 0.3
	var glass_dir = Vector2.from_angle(glass_angle)
	var arm_extend = _attack_anim * 6.0
	var l_hand = l_shoulder + Vector2(-2, 8) + glass_dir * (14.0 + arm_extend)
	var l_elbow = l_shoulder + (l_hand - l_shoulder) * 0.45 + Vector2(-3, 3)
	# Upper arm: outline then fill
	draw_line(l_shoulder, l_elbow, OL, 10.0)
	draw_line(l_shoulder, l_elbow, tweed_dark, 7.5)
	draw_line(l_shoulder + Vector2(-1, 0), l_elbow + Vector2(-1, 0), tweed_mid, 2.5)
	# Elbow joint
	draw_circle(l_elbow, 5.5, OL)
	draw_circle(l_elbow, 4.0, tweed_dark)
	# Forearm: outline then fill
	draw_line(l_elbow, l_hand, OL, 9.0)
	draw_line(l_elbow, l_hand, tweed_dark, 6.5)
	# Cuff (shirt peeking out)
	var l_cuff_p = l_elbow.lerp(l_hand, 0.82)
	var lf_dir = (l_hand - l_elbow).normalized()
	var lf_perp = lf_dir.rotated(PI / 2.0)
	draw_line(l_cuff_p - lf_perp * 4.5, l_cuff_p + lf_perp * 4.5, OL, 3.0)
	draw_line(l_cuff_p - lf_perp * 3.5, l_cuff_p + lf_perp * 3.5, shirt_col, 2.0)
	# Hand
	draw_circle(l_hand, 4.5, OL)
	draw_circle(l_hand, 3.5, skin_base)
	draw_circle(l_hand + Vector2(-0.5, -0.5), 1.8, skin_highlight)
	# Gripping fingers
	for fi in range(3):
		var fang = float(fi - 1) * 0.35
		var fpos = l_hand + glass_dir.rotated(fang) * 3.5
		draw_circle(fpos, 2.0, OL)
		draw_circle(fpos, 1.3, skin_base)

	# === MAGNIFYING GLASS (signature weapon!) ===
	var glass_handle_start = l_hand + glass_dir * 3.0
	var glass_handle_end = l_hand + glass_dir * 13.0
	var glass_center = l_hand + glass_dir * (20.0 + arm_extend * 0.5)
	# Handle: outline then fill
	draw_line(glass_handle_start, glass_handle_end, OL, 6.0)
	draw_line(glass_handle_start, glass_handle_end, Color(0.36, 0.22, 0.08), 4.0)
	draw_line(glass_handle_start, glass_handle_end, Color(0.48, 0.32, 0.14), 2.5)
	# Handle grip ridges
	for gi in range(3):
		var gt = 0.2 + float(gi) * 0.3
		var g_pos = glass_handle_start.lerp(glass_handle_end, gt)
		var g_perp_dir = glass_dir.rotated(PI / 2.0)
		draw_line(g_pos - g_perp_dir * 2.5, g_pos + g_perp_dir * 2.5, Color(0.28, 0.16, 0.06, 0.5), 1.0)
	# Brass ferrule
	var ferrule = glass_handle_end
	draw_circle(ferrule, 4.0, OL)
	draw_circle(ferrule, 3.0, brass_col)
	draw_circle(ferrule + Vector2(-0.5, -0.5), 1.5, brass_hi)
	# Lens frame (bold brass ring)
	var frame_radius = 10.0
	draw_arc(glass_center, frame_radius + 2.0, 0, TAU, 24, OL, 4.5)
	draw_arc(glass_center, frame_radius, 0, TAU, 24, brass_col, 3.5)
	draw_arc(glass_center, frame_radius - 0.5, PI * 1.1, PI * 1.8, 12, brass_hi, 1.8)
	# Lens glass (light blue tint)
	draw_circle(glass_center, frame_radius - 2.0, Color(0.80, 0.90, 1.0, 0.18))
	# Lens light refraction
	var refract_offset = Vector2(sin(_time * 0.8) * 2.5, cos(_time * 0.6) * 2.0)
	draw_circle(glass_center + refract_offset, 4.5, Color(1.0, 0.98, 0.90, 0.15))
	draw_circle(glass_center + refract_offset * 0.5, 3.0, Color(1.0, 1.0, 0.95, 0.22))
	# Crescent highlight on lens
	draw_arc(glass_center + Vector2(-2.5, -2.5), 5.5, PI * 1.1, PI * 1.7, 8, Color(1.0, 1.0, 1.0, 0.45), 2.0)
	draw_circle(glass_center + Vector2(3.5, 3.5), 1.8, Color(1.0, 1.0, 1.0, 0.25))
	# Attack flash on lens
	if _attack_anim > 0.0:
		var flash_r = frame_radius + 4.0 + _attack_anim * 6.0
		draw_circle(glass_center, flash_r, Color(1.0, 0.95, 0.6, _attack_anim * 0.15))
		draw_arc(glass_center, flash_r, 0, TAU, 16, Color(1.0, 0.90, 0.4, _attack_anim * 0.3), 2.0)
	# Tier 1+: Faint glow around glass
	if upgrade_tier >= 1:
		var glow_pulse = (sin(_time * 3.0) + 1.0) * 0.5
		draw_circle(glass_center, frame_radius + 4.0, Color(1.0, 0.92, 0.5, 0.06 + glow_pulse * 0.04))
	# Tier 2+: Active beam from lens toward target
	if upgrade_tier >= 2 and target and _attack_anim > 0.0:
		var beam_dir_t = (target.global_position - global_position).normalized()
		var beam_len = 40.0 * _attack_anim
		draw_line(glass_center, glass_center + beam_dir_t * beam_len, Color(1.0, 0.95, 0.6, 0.25 * _attack_anim), 3.5)
		draw_line(glass_center, glass_center + beam_dir_t * beam_len, Color(1.0, 0.98, 0.8, 0.35 * _attack_anim), 1.8)
	# Buff pulse ring
	if _attack_anim > 0.2:
		var pulse_r2 = 20.0 + (1.0 - _attack_anim) * 40.0
		var pulse_alpha = _attack_anim * 0.4
		draw_arc(Vector2.ZERO, pulse_r2, 0, TAU, 32, Color(0.85, 0.72, 0.25, pulse_alpha), 2.5)

	# --- RIGHT ARM (rests at side / pipe hand) ---
	var r_hand = r_shoulder + Vector2(5, 16)
	var r_elbow = r_shoulder + (r_hand - r_shoulder) * 0.45 + Vector2(3, 2)
	# Upper arm: outline then fill
	draw_line(r_shoulder, r_elbow, OL, 10.0)
	draw_line(r_shoulder, r_elbow, tweed_dark, 7.5)
	draw_line(r_shoulder + Vector2(1, 0), r_elbow + Vector2(1, 0), tweed_mid, 2.5)
	# Elbow
	draw_circle(r_elbow, 5.5, OL)
	draw_circle(r_elbow, 4.0, tweed_dark)
	# Forearm
	draw_line(r_elbow, r_hand, OL, 9.0)
	draw_line(r_elbow, r_hand, tweed_dark, 6.5)
	# Cuff
	var r_cuff_p = r_elbow.lerp(r_hand, 0.82)
	var rf_dir = (r_hand - r_elbow).normalized()
	var rf_perp = rf_dir.rotated(PI / 2.0)
	draw_line(r_cuff_p - rf_perp * 4.5, r_cuff_p + rf_perp * 4.5, OL, 3.0)
	draw_line(r_cuff_p - rf_perp * 3.5, r_cuff_p + rf_perp * 3.5, shirt_col, 2.0)
	# Hand
	draw_circle(r_hand, 4.5, OL)
	draw_circle(r_hand, 3.5, skin_base)
	draw_circle(r_hand + Vector2(0.5, -0.5), 1.8, skin_highlight)

	# --- PIPE (in right hand, angled up) ---
	var pipe_bowl = r_hand + Vector2(2, -5)
	# Stem: outline then fill
	draw_line(r_hand + Vector2(0, -1), pipe_bowl, OL, 4.0)
	draw_line(r_hand + Vector2(0, -1), pipe_bowl, Color(0.30, 0.18, 0.08), 2.5)
	# Bowl: outline then fill
	draw_circle(pipe_bowl, 4.5, OL)
	draw_circle(pipe_bowl, 3.3, Color(0.35, 0.20, 0.08))
	draw_circle(pipe_bowl + Vector2(-0.5, -0.5), 1.8, Color(0.45, 0.28, 0.12))
	# Bowl opening
	draw_circle(pipe_bowl + Vector2(0, -2), 2.2, OL)
	draw_circle(pipe_bowl + Vector2(0, -2), 1.5, Color(0.10, 0.05, 0.02))
	# Animated smoke wisps (curling upward)
	var smoke_base_pos = pipe_bowl + Vector2(0, -5)
	for si in range(4):
		var sx = sin(_time * 1.2 + float(si) * 1.8) * (3.0 + float(si) * 1.5)
		var sy_raw = -float(si) * 5.0 - fmod(_time * 8.0, 25.0)
		var sy = fmod(sy_raw, -22.0)
		var s_alpha = 0.22 - float(si) * 0.05
		if s_alpha > 0.0:
			var smoke_pos = smoke_base_pos + Vector2(sx, sy)
			var smoke_r = 2.0 + float(si) * 1.0
			draw_circle(smoke_pos, smoke_r + 1.0, Color(0.75, 0.75, 0.78, s_alpha * 0.4))
			draw_circle(smoke_pos, smoke_r, Color(0.82, 0.82, 0.85, s_alpha))

	# === HEAD (big chibi head) ===
	# Neck: outline then fill
	draw_line(neck_base, head_center + Vector2(0, 8), OL, 9.0)
	draw_line(neck_base, head_center + Vector2(0, 8), skin_shadow, 6.5)
	draw_line(neck_base, head_center + Vector2(0, 8), skin_base, 5.0)
	# Shirt collar at neck
	draw_line(neck_base + Vector2(-5, 0), neck_base + Vector2(-3, -3), OL, 3.5)
	draw_line(neck_base + Vector2(5, 0), neck_base + Vector2(3, -3), OL, 3.5)
	draw_line(neck_base + Vector2(-4.5, 0), neck_base + Vector2(-2.5, -2.5), shirt_col, 2.5)
	draw_line(neck_base + Vector2(4.5, 0), neck_base + Vector2(2.5, -2.5), shirt_col, 2.5)

	# Hair back layer (dark brown, visible behind head)
	var hair_col = Color(0.18, 0.12, 0.06)
	var hair_hi = Color(0.30, 0.22, 0.14)
	# Head outline + hair base
	draw_circle(head_center, 14.0, OL)
	draw_circle(head_center, 12.5, hair_col)
	draw_circle(head_center + Vector2(0, -1), 11.0, Color(0.24, 0.16, 0.08))

	# Face circle: outline + skin fill
	draw_circle(head_center + Vector2(0, 1.0), 12.0, OL)
	draw_circle(head_center + Vector2(0, 1.0), 10.8, skin_base)
	# Cheek warmth (subtle cartoon blush)
	draw_circle(head_center + Vector2(-6, 3), 3.0, Color(0.95, 0.78, 0.65, 0.2))
	draw_circle(head_center + Vector2(6, 3), 3.0, Color(0.95, 0.78, 0.65, 0.2))
	# Strong chin hint
	draw_arc(head_center + Vector2(0, 8), 4.0, 0.3, PI - 0.3, 8, Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.25), 1.2)

	# Ears (peek out from sides)
	var l_ear = head_center + Vector2(-10, 0)
	var r_ear = head_center + Vector2(10, 0)
	draw_circle(l_ear, 3.5, OL)
	draw_circle(l_ear, 2.5, skin_base)
	draw_circle(l_ear + Vector2(-0.3, 0), 1.2, Color(0.90, 0.72, 0.58, 0.5))
	draw_circle(r_ear, 3.5, OL)
	draw_circle(r_ear, 2.5, skin_base)
	draw_circle(r_ear + Vector2(0.3, 0), 1.2, Color(0.90, 0.72, 0.58, 0.5))

	# === EYES (BTD6 style: big, round, 5-layer) ===
	var look_dir = dir * 1.5
	var l_eye = head_center + Vector2(-4.0, -1.0)
	var r_eye_pos = head_center + Vector2(4.0, -1.0)
	# Eye outlines (bold black border)
	draw_circle(l_eye, 5.8, OL)
	draw_circle(r_eye_pos, 5.8, OL)
	# Eye whites
	draw_circle(l_eye, 4.8, Color(0.97, 0.97, 0.99))
	draw_circle(r_eye_pos, 4.8, Color(0.97, 0.97, 0.99))
	# Dark brown irises (keen, intelligent)
	var iris_col = Color(0.30, 0.22, 0.12)
	var iris_mid = Color(0.42, 0.32, 0.18)
	draw_circle(l_eye + look_dir, 3.2, iris_col)
	draw_circle(l_eye + look_dir, 2.5, iris_mid)
	draw_circle(r_eye_pos + look_dir, 3.2, iris_col)
	draw_circle(r_eye_pos + look_dir, 2.5, iris_mid)
	# Pupils (sharp, focused)
	draw_circle(l_eye + look_dir * 1.1, 1.6, Color(0.04, 0.04, 0.06))
	draw_circle(r_eye_pos + look_dir * 1.1, 1.6, Color(0.04, 0.04, 0.06))
	# Primary sparkle highlight
	draw_circle(l_eye + Vector2(-1.0, -1.5), 1.5, Color(1.0, 1.0, 1.0, 0.95))
	draw_circle(r_eye_pos + Vector2(-1.0, -1.5), 1.5, Color(1.0, 1.0, 1.0, 0.95))
	# Secondary sparkle
	draw_circle(l_eye + Vector2(1.2, 0.8), 0.8, Color(1.0, 1.0, 1.0, 0.55))
	draw_circle(r_eye_pos + Vector2(1.2, 0.8), 0.8, Color(1.0, 1.0, 1.0, 0.55))
	# Analytical glint (keen intelligence shimmer)
	var glint_t = sin(_time * 2.5) * 0.25
	draw_circle(l_eye + Vector2(0.5, -0.5), 0.6, Color(0.7, 0.85, 1.0, 0.3 + glint_t))
	draw_circle(r_eye_pos + Vector2(0.5, -0.5), 0.6, Color(0.7, 0.85, 1.0, 0.3 + glint_t))
	# Bold upper eyelids (confident, slightly narrowed)
	draw_arc(l_eye, 5.0, PI + 0.15, TAU - 0.15, 10, OL, 2.2)
	draw_arc(r_eye_pos, 5.0, PI + 0.15, TAU - 0.15, 10, OL, 2.2)
	# Lower eyelid (subtle)
	draw_arc(l_eye, 4.5, 0.3, PI - 0.3, 8, Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.25), 0.8)
	draw_arc(r_eye_pos, 4.5, 0.3, PI - 0.3, 8, Color(skin_shadow.r, skin_shadow.g, skin_shadow.b, 0.25), 0.8)

	# --- EYEBROWS (bold, sharp, analytical arches) ---
	draw_line(l_eye + Vector2(-4.5, -5.5), l_eye + Vector2(0.5, -6.5), OL, 2.8)
	draw_line(l_eye + Vector2(0.5, -6.5), l_eye + Vector2(4.0, -5.0), OL, 2.0)
	draw_line(r_eye_pos + Vector2(-4.0, -5.0), r_eye_pos + Vector2(-0.5, -6.5), OL, 2.0)
	draw_line(r_eye_pos + Vector2(-0.5, -6.5), r_eye_pos + Vector2(4.5, -5.5), OL, 2.8)

	# --- NOSE (small chibi button with character) ---
	draw_circle(head_center + Vector2(0, 3.5), 2.2, OL)
	draw_circle(head_center + Vector2(0, 3.5), 1.6, skin_highlight)
	draw_circle(head_center + Vector2(-0.3, 3.2), 0.8, Color(1.0, 0.95, 0.88, 0.4))

	# --- MOUTH (confident half-smile) ---
	draw_arc(head_center + Vector2(0, 6.0), 3.5, 0.15, PI * 0.7, 8, OL, 2.0)
	draw_arc(head_center + Vector2(0, 6.0), 3.5, 0.2, PI * 0.65, 8, Color(0.60, 0.32, 0.22), 1.2)
	# Smirk corner upturn
	draw_line(head_center + Vector2(3.2, 5.8), head_center + Vector2(4.0, 5.2), OL, 1.5)

	# === DEERSTALKER HAT (big, prominent, signature!) ===
	var hat_base_y = head_center + Vector2(0, -8)

	# Main crown outline (oversized for chibi)
	var hat_crown_ol = PackedVector2Array([
		hat_base_y + Vector2(-13, 3),
		hat_base_y + Vector2(-14, -2),
		hat_base_y + Vector2(-10, -9),
		hat_base_y + Vector2(-4, -12),
		hat_base_y + Vector2(4, -12),
		hat_base_y + Vector2(10, -9),
		hat_base_y + Vector2(14, -2),
		hat_base_y + Vector2(13, 3),
	])
	draw_colored_polygon(hat_crown_ol, OL)
	# Crown fill
	var hat_crown_pts = PackedVector2Array([
		hat_base_y + Vector2(-11.5, 2),
		hat_base_y + Vector2(-12.5, -2),
		hat_base_y + Vector2(-9, -8),
		hat_base_y + Vector2(-3.5, -10.5),
		hat_base_y + Vector2(3.5, -10.5),
		hat_base_y + Vector2(9, -8),
		hat_base_y + Vector2(12.5, -2),
		hat_base_y + Vector2(11.5, 2),
	])
	draw_colored_polygon(hat_crown_pts, tweed_dark)
	# Crown highlight
	draw_colored_polygon(PackedVector2Array([
		hat_base_y + Vector2(-9, -1),
		hat_base_y + Vector2(-7, -7),
		hat_base_y + Vector2(7, -7),
		hat_base_y + Vector2(9, -1),
	]), tweed_mid)
	# Checkered tweed pattern (bold, visible)
	for hi in range(4):
		for hj in range(3):
			var check_x = -7.0 + float(hi) * 4.5
			var check_y = -8.0 + float(hj) * 3.5
			var check_pos = hat_base_y + Vector2(check_x, check_y)
			if (hi + hj) % 2 == 0:
				draw_colored_polygon(PackedVector2Array([
					check_pos, check_pos + Vector2(3.5, 0),
					check_pos + Vector2(3.5, 2.8), check_pos + Vector2(0, 2.8),
				]), Color(tweed_light.r, tweed_light.g, tweed_light.b, 0.3))

	# Front brim (bold, extends forward)
	var front_brim_ol = PackedVector2Array([
		hat_base_y + Vector2(-13, 3),
		hat_base_y + Vector2(13, 3),
		hat_base_y + Vector2(10, 7),
		hat_base_y + Vector2(-10, 7),
	])
	draw_colored_polygon(front_brim_ol, OL)
	var front_brim_fill = PackedVector2Array([
		hat_base_y + Vector2(-11.5, 3.5),
		hat_base_y + Vector2(11.5, 3.5),
		hat_base_y + Vector2(9, 6),
		hat_base_y + Vector2(-9, 6),
	])
	draw_colored_polygon(front_brim_fill, Color(0.42, 0.30, 0.15))
	# Brim highlight
	draw_line(hat_base_y + Vector2(-9, 6), hat_base_y + Vector2(9, 6), Color(0.55, 0.42, 0.25, 0.5), 1.2)

	# Ear flaps (tied up on top -- iconic!)
	# Left flap outline + fill
	var l_flap_ol = PackedVector2Array([
		hat_base_y + Vector2(-14, 0),
		hat_base_y + Vector2(-13, 3),
		hat_base_y + Vector2(-10, 4),
		hat_base_y + Vector2(-9, -3),
		hat_base_y + Vector2(-12, -4),
	])
	draw_colored_polygon(l_flap_ol, OL)
	var l_flap_fill = PackedVector2Array([
		hat_base_y + Vector2(-12.5, -0.5),
		hat_base_y + Vector2(-11.5, 2.5),
		hat_base_y + Vector2(-10, 3),
		hat_base_y + Vector2(-9.5, -2.5),
		hat_base_y + Vector2(-11, -3),
	])
	draw_colored_polygon(l_flap_fill, Color(0.46, 0.34, 0.20))
	# Right flap outline + fill
	var r_flap_ol = PackedVector2Array([
		hat_base_y + Vector2(14, 0),
		hat_base_y + Vector2(13, 3),
		hat_base_y + Vector2(10, 4),
		hat_base_y + Vector2(9, -3),
		hat_base_y + Vector2(12, -4),
	])
	draw_colored_polygon(r_flap_ol, OL)
	var r_flap_fill = PackedVector2Array([
		hat_base_y + Vector2(12.5, -0.5),
		hat_base_y + Vector2(11.5, 2.5),
		hat_base_y + Vector2(10, 3),
		hat_base_y + Vector2(9.5, -2.5),
		hat_base_y + Vector2(11, -3),
	])
	draw_colored_polygon(r_flap_fill, Color(0.46, 0.34, 0.20))

	# Tied-up button at crown (holding ear flaps up)
	draw_circle(hat_base_y + Vector2(0, -10), 3.0, OL)
	draw_circle(hat_base_y + Vector2(0, -10), 2.0, Color(0.48, 0.36, 0.20))
	draw_circle(hat_base_y + Vector2(-0.3, -10.3), 0.8, Color(0.58, 0.45, 0.28))

	# Hat band (dark bold ribbon)
	draw_line(hat_base_y + Vector2(-13, 2), hat_base_y + Vector2(13, 2), OL, 3.5)
	draw_line(hat_base_y + Vector2(-12, 1.5), hat_base_y + Vector2(12, 1.5), Color(0.18, 0.14, 0.08), 2.5)

	# Crown center seam
	draw_line(hat_base_y + Vector2(0, -10.5), hat_base_y + Vector2(0, 2), Color(0.32, 0.22, 0.12, 0.4), 1.0)

	# Tier 4: Hat glow
	if upgrade_tier >= 4:
		draw_circle(hat_base_y + Vector2(0, -5), 18.0, Color(1.0, 0.90, 0.45, 0.05 + sin(_time * 2.0) * 0.03))

	# === Tier 4: Golden-amber aura around whole character ===
	if upgrade_tier >= 4:
		var t4_aura_pulse = sin(_time * 2.5) * 5.0
		draw_circle(body_offset, 60.0 + t4_aura_pulse, Color(0.85, 0.72, 0.25, 0.04))
		draw_circle(body_offset, 50.0 + t4_aura_pulse * 0.6, Color(0.90, 0.78, 0.30, 0.06))
		draw_circle(body_offset, 42.0 + t4_aura_pulse * 0.3, Color(1.0, 0.90, 0.45, 0.06))
		draw_arc(body_offset, 56.0 + t4_aura_pulse, 0, TAU, 32, Color(0.85, 0.72, 0.25, 0.15), 2.5)
		draw_arc(body_offset, 46.0 + t4_aura_pulse * 0.5, 0, TAU, 24, Color(1.0, 0.90, 0.45, 0.08), 1.8)
		# Orbiting golden sparkles
		for gs in range(6):
			var gs_a = _time * (0.6 + float(gs % 3) * 0.2) + float(gs) * TAU / 6.0
			var gs_r = 46.0 + t4_aura_pulse + float(gs % 3) * 3.5
			var gs_p = body_offset + Vector2.from_angle(gs_a) * gs_r
			var gs_size = 1.2 + sin(_time * 3.0 + float(gs) * 1.5) * 0.5
			var gs_alpha = 0.25 + sin(_time * 3.0 + float(gs)) * 0.15
			draw_circle(gs_p, gs_size, Color(1.0, 0.90, 0.45, gs_alpha))

	# === AWAITING ABILITY CHOICE INDICATOR ===
	if awaiting_ability_choice:
		var pulse = (sin(_time * 4.0) + 1.0) * 0.5
		draw_circle(Vector2.ZERO, 68.0 + pulse * 6.0, Color(0.85, 0.72, 0.25, 0.1 + pulse * 0.1))
		draw_arc(Vector2.ZERO, 68.0 + pulse * 6.0, 0, TAU, 32, Color(0.85, 0.72, 0.25, 0.3 + pulse * 0.3), 2.5)
		var font3 = _game_font
		draw_string(font3, Vector2(-16, -80), "!", HORIZONTAL_ALIGNMENT_CENTER, 32, 30, Color(0.85, 0.72, 0.25, 0.7 + pulse * 0.3))

	# === DAMAGE COUNTER ===
	if damage_dealt > 0:
		var font = _game_font
		var dmg_text = str(int(damage_dealt)) + " DMG"
		if stat_upgrade_level > 0:
			dmg_text += " " + str(stat_upgrade_level) + " Lv."
		draw_string(font, Vector2(-36, 56), dmg_text, HORIZONTAL_ALIGNMENT_LEFT, 160, 12, Color(0.85, 0.72, 0.25, 0.5))

	# === UPGRADE NAME FLASH ===
	if _upgrade_flash > 0.0 and _upgrade_name != "":
		var font2 = _game_font
		draw_string(font2, Vector2(-80, -72), _upgrade_name, HORIZONTAL_ALIGNMENT_CENTER, 160, 16, Color(0.85, 0.72, 0.25, min(_upgrade_flash, 1.0)))

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

# Synergy multipliers (match robin_hood.gd pattern exactly)

var power_damage_mult: float = 1.0

func _damage_mult() -> float:
	return (1.0 + _synergy_buffs.get("damage", 0.0) + _meta_buffs.get("damage", 0.0)) * power_damage_mult

func _range_mult() -> float:
	return 1.0 + _synergy_buffs.get("range", 0.0) + _meta_buffs.get("range", 0.0)

func _speed_mult() -> float:
	return 1.0 + _synergy_buffs.get("attack_speed", 0.0) + _meta_buffs.get("attack_speed", 0.0)

func _gold_mult() -> float:
	return 1.0 + _synergy_buffs.get("gold_bonus", 0.0) + _meta_buffs.get("gold_bonus", 0.0)
