extends Node2D
## Anubis -- god of death tower from Egyptian Mythology (Book of the Dead).
## Soul judgment, scarab swarms, sandstorms.
## Path A "Scales of Judgment": Scales of Ma'at, Embalmer's Touch, Ammit the Devourer
## Path B "Lord of the Dead": Canopic Guardian, Ankh of Life, Lord of Sacred Land
## Path C "Desert Wrath": Desert Scarabs, Duat Gateway, Sandstorm Apocalypse

# Base stats
var damage: float = 24.0
var fire_rate: float = 0.85
var attack_range: float = 155.0
var fire_cooldown: float = 0.0
var aim_angle: float = 0.0
var sprite_texture: Texture2D = null
# Flair animation (idle poses -- randomized every 8s)
var flair_textures: Array = []  # Injected by main.gd
var _sprite_attack: Texture2D = null  # Attack pose, injected by main.gd
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

# Animation timers
var _time: float = 0.0
var _attack_anim: float = 0.0
var _build_timer: float = 0.0

var _home_position: Vector2 = Vector2.ZERO

# === PATH UPGRADE STATE ===
# Path A: Scales of Judgment
var _hp_reveal_active: bool = false
var _embalmer_active: bool = false
var _embalmer_timer: float = 15.0
var _embalmer_cooldown: float = 15.0
var _embalmer_flash: float = 0.0
var _ammit_active: bool = false
var _ammit_kill_counter: int = 0
var _ammit_flash: float = 0.0

# Path B: Lord of the Dead
var _canopic_active: bool = false
var _canopic_shield: float = 0.0
var _canopic_max_shield: float = 60.0
var _canopic_timer: float = 15.0
var _canopic_cooldown: float = 15.0
var _canopic_flash: float = 0.0
var _ankh_active: bool = false
var _ankh_timer: float = 25.0
var _ankh_cooldown: float = 25.0
var _ankh_flash: float = 0.0
var _sacred_land_active: bool = false
var _sacred_land_resurrect: bool = false
var _sacred_land_flash: float = 0.0

# Path C: Desert Wrath
var _scarab_dot_active: bool = false
var _duat_active: bool = false
var _duat_timer: float = 20.0
var _duat_cooldown: float = 20.0
var _duat_flash: float = 0.0
var _sandstorm_active: bool = false
var _sandstorm_timer: float = 18.0
var _sandstorm_cooldown: float = 18.0
var _sandstorm_flash: float = 0.0

# === PROGRESSIVE ABILITIES (9 tiers, unlocked via lifetime damage) ===
const PROG_ABILITY_NAMES = [
	"Scales of Ma'at", "Canopic Guardian", "Desert Scarabs", "Embalmer's Touch",
	"Duat Gateway", "Ammit's Hunger", "Ankh of Life", "Sandstorm Wrath",
	"Lord of the Sacred Land"
]
const PROG_ABILITY_DESCS = [
	"+20% dmg, attacks reveal true enemy HP",
	"Shield absorbs 60 dmg/15s",
	"Attacks spawn scarabs, 2s DoT",
	"Every 15s, strongest enemy slowed 50% + DoT 4s",
	"Every 20s, portal pulls 3 enemies back 200px",
	"Every 10th kill, devour strongest (instakill)",
	"Every 25s, restore 1 life",
	"Every 18s, sandstorm hits all in 2x range for 4x",
	"Permanent aura: enemies lose 2% HP/s, all towers +10%"
]
var prog_abilities: Array = [false, false, false, false, false, false, false, false, false]

# Progressive ability timers
var _prog_embalmer_timer: float = 15.0
var _prog_duat_timer: float = 20.0
var _prog_ammit_kill_counter: int = 0
var _prog_ankh_timer: float = 25.0
var _prog_sandstorm_timer: float = 18.0
# Visual flash timers for progressive
var _prog_scales_flash: float = 0.0
var _prog_canopic_flash: float = 0.0
var _prog_scarab_flash: float = 0.0
var _prog_embalmer_flash: float = 0.0
var _prog_duat_flash: float = 0.0
var _prog_ammit_flash: float = 0.0
var _prog_ankh_flash: float = 0.0
var _prog_sandstorm_flash: float = 0.0
var _prog_sacred_flash: float = 0.0
# Progressive canopic shield
var _prog_canopic_shield: float = 0.0
var _prog_canopic_timer: float = 15.0

const TIER_COSTS = [140, 325, 600, 1100, 1800]
const TIER_NAMES = [
	"Scales of Ma'at",
	"Canopic Guardian",
	"Desert Scarabs",
	"Ammit the Devourer",
	"Lord of Sacred Land"
]
const ABILITY_DESCRIPTIONS = [
	"+20% dmg, attacks reveal true enemy HP",
	"Shield absorbs 60 dmg/15s",
	"Attacks spawn scarabs, 2s DoT",
	"Every 10th kill, devour strongest enemy (instakill)",
	"Permanent drain aura + self-resurrect"
]

const MAX_STAT_LEVEL: int = 10
const STAT_UPGRADE_INTERVAL: float = 8000.0
const ABILITY_THRESHOLD: float = 28000.0
var stat_upgrade_level: int = 0
var ability_chosen: bool = false
var awaiting_ability_choice: bool = false
var is_selected: bool = false
var base_cost: int = 0

# Accumulated stat boosts from leveling (to restore after tier upgrade)
var _accumulated_stat_boosts: Dictionary = {
	"damage": 0.0,
	"fire_rate": 0.0,
	"attack_range": 0.0,
	"gold_bonus": 0,
}

# Attack sounds -- deep resonant death toll
var _attack_sounds: Array = []
var _attack_sounds_by_tier: Array = []
var _attack_player: AudioStreamPlayer

# Ability sounds
var _judgment_sound: AudioStreamWAV
var _judgment_player: AudioStreamPlayer
var _scarab_sound: AudioStreamWAV
var _scarab_player: AudioStreamPlayer
var _upgrade_sound: AudioStreamWAV
var _upgrade_player: AudioStreamPlayer
var _game_font: Font
var _main_node: Node2D = null

# Synergy buffs
var _synergy_buffs: Dictionary = {}
var _meta_buffs: Dictionary = {}
var power_damage_mult: float = 1.0

# Active hero ability: Judgment Circle (30s CD)
var active_ability_ready: bool = true
var active_ability_cooldown: float = 0.0
var active_ability_max_cd: float = 30.0

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

	# Judgment sound -- deep gong/bell toll with ethereal reverb
	var jg_rate := 22050
	var jg_dur := 1.0
	var jg_samples := PackedFloat32Array()
	jg_samples.resize(int(jg_rate * jg_dur))
	for i in jg_samples.size():
		var t := float(i) / jg_rate
		var s := 0.0
		# Deep gong strike
		var gong_env := exp(-t * 2.5) * 0.4
		var onset := minf(t * 60.0, 1.0)
		s += sin(TAU * 110.0 * t) * gong_env * onset
		s += sin(TAU * 165.0 * t) * gong_env * 0.3 * onset
		# Ethereal shimmer
		var shimmer_env := sin(clampf(t * 3.0, 0.0, PI)) * 0.15
		s += sin(TAU * 880.0 * t + sin(TAU * 3.0 * t) * 2.0) * shimmer_env
		# Sub bass
		s += sin(TAU * 55.0 * t) * exp(-t * 3.0) * 0.2
		jg_samples[i] = clampf(s, -1.0, 1.0)
	_judgment_sound = _samples_to_wav(jg_samples, jg_rate)
	_judgment_player = AudioStreamPlayer.new()
	_judgment_player.stream = _judgment_sound
	_judgment_player.volume_db = -12.0
	add_child(_judgment_player)

	# Scarab sound -- chittering insect swarm buzz
	var sc_rate := 22050
	var sc_dur := 0.5
	var sc_samples := PackedFloat32Array()
	sc_samples.resize(int(sc_rate * sc_dur))
	for i in sc_samples.size():
		var t := float(i) / sc_rate
		var s := 0.0
		var buzz_env := exp(-t * 4.0) * 0.25
		# Multiple buzzing frequencies
		s += sin(TAU * 220.0 * t + sin(TAU * 80.0 * t) * 4.0) * buzz_env
		s += sin(TAU * 340.0 * t + sin(TAU * 60.0 * t) * 3.0) * buzz_env * 0.6
		# Chittering noise
		s += (randf() * 2.0 - 1.0) * buzz_env * 0.3
		sc_samples[i] = clampf(s, -1.0, 1.0)
	_scarab_sound = _samples_to_wav(sc_samples, sc_rate)
	_scarab_player = AudioStreamPlayer.new()
	_scarab_player.stream = _scarab_sound
	_scarab_player.volume_db = -14.0
	add_child(_scarab_player)

	# Upgrade chime -- dark ascending minor (A3, C4, E4)
	var up_rate := 22050
	var up_dur := 0.35
	var up_samples := PackedFloat32Array()
	up_samples.resize(int(up_rate * up_dur))
	var up_notes := [220.0, 261.63, 329.63]
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
	# Path upgrade flash decay
	_embalmer_flash = max(_embalmer_flash - delta * 2.0, 0.0)
	_ammit_flash = max(_ammit_flash - delta * 2.0, 0.0)
	_canopic_flash = max(_canopic_flash - delta * 2.0, 0.0)
	_ankh_flash = max(_ankh_flash - delta * 2.0, 0.0)
	_sacred_land_flash = max(_sacred_land_flash - delta * 2.0, 0.0)
	_duat_flash = max(_duat_flash - delta * 2.0, 0.0)
	_sandstorm_flash = max(_sandstorm_flash - delta * 2.0, 0.0)

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
		aim_angle = lerp_angle(aim_angle, desired, 6.0 * delta)
		if fire_cooldown <= 0.0:
			_attack()
			fire_cooldown = maxf(1.0 / (fire_rate * _speed_mult()), 0.15)
			_attack_anim = 1.0

	# Path A/2: Embalmer's Touch -- slow strongest every 15s
	if _embalmer_active:
		_embalmer_timer -= delta
		if _embalmer_timer <= 0.0 and _has_enemies_in_range():
			_embalmer_touch()
			_embalmer_timer = _embalmer_cooldown

	# Path B/1: Canopic Guardian -- recharge shield
	if _canopic_active:
		_canopic_timer -= delta
		if _canopic_timer <= 0.0 and _canopic_shield <= 0.0:
			_canopic_shield = _canopic_max_shield
			_canopic_timer = _canopic_cooldown
			_canopic_flash = 1.0

	# Path B/2: Ankh of Life -- heal 1 life every 25s
	if _ankh_active:
		_ankh_timer -= delta
		if _ankh_timer <= 0.0:
			_ankh_heal()
			_ankh_timer = _ankh_cooldown

	# Path B/3: Sacred Land aura -- drain enemies 2% HP/s
	if _sacred_land_active:
		_process_sacred_land_aura(delta)

	# Path C/2: Duat Gateway -- pull enemies back every 20s
	if _duat_active:
		_duat_timer -= delta
		if _duat_timer <= 0.0 and _has_enemies_in_range():
			_duat_gateway()
			_duat_timer = _duat_cooldown

	# Path C/3: Sandstorm -- massive AoE every 18s
	if _sandstorm_active:
		_sandstorm_timer -= delta
		if _sandstorm_timer <= 0.0 and _has_enemies_in_range():
			_sandstorm_strike()
			_sandstorm_timer = _sandstorm_cooldown

	# Progressive abilities
	_process_progressive_abilities(delta)

	# Active ability cooldown
	if not active_ability_ready:
		active_ability_cooldown -= delta
		if active_ability_cooldown <= 0.0:
			active_ability_ready = true
			active_ability_cooldown = 0.0

	queue_redraw()

func _draw() -> void:
	# Build animation -- elastic scale-in
	if _build_timer > 0.0:
		var bt = 1.0 - clampf(_build_timer / 0.5, 0.0, 1.0)
		var elastic = 1.0 + sin(bt * PI * 2.5) * 0.3 * (1.0 - bt)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(elastic, elastic))

	# === 1. SELECTION RING ===
	var eff_range = attack_range * _range_mult()
	if is_selected:
		var pulse = (sin(_time * 3.0) + 1.0) * 0.5
		var ring_alpha = 0.5 + pulse * 0.3
		draw_arc(Vector2.ZERO, eff_range, 0, TAU, 36, Color(0.85, 0.75, 0.3, 0.25 + pulse * 0.15), 2.0)
		draw_arc(Vector2.ZERO, 40.0, 0, TAU, 28, Color(0.85, 0.75, 0.3, ring_alpha), 2.5)
		draw_arc(Vector2.ZERO, 43.0, 0, TAU, 28, Color(0.85, 0.75, 0.3, ring_alpha * 0.4), 1.5)

	# === 2. AIM DIRECTION ===
	var dir = Vector2.from_angle(aim_angle)

	# === 3. IDLE ANIMATION (regal, slow sway) ===
	var bounce = abs(sin(_time * 2.0)) * 2.0
	var breathe = sin(_time * 1.8) * 2.5
	var sway = sin(_time * 1.0) * 2.0
	var bob = Vector2(sway, -bounce - breathe)
	var body_offset = bob

	# === 4. UPGRADE FLASH ===
	if _upgrade_flash > 0.0 and _upgrade_name != "":
		var font2 = _game_font if _game_font else ThemeDB.fallback_font
		draw_string(font2, Vector2(-80, -72), _upgrade_name, HORIZONTAL_ALIGNMENT_CENTER, 160, 16, Color(0.85, 0.75, 0.3, min(_upgrade_flash, 1.0)))

	# === PATH ABILITY VISUAL EFFECTS ===
	# Canopic shield indicator
	if _canopic_active and _canopic_shield > 0.0:
		var shield_alpha = 0.15 + sin(_time * 2.0) * 0.05
		draw_arc(Vector2.ZERO, 35.0, 0, TAU, 24, Color(0.3, 0.7, 0.85, shield_alpha), 3.0)

	# Sacred Land drain aura
	if _sacred_land_active:
		var aura_alpha = 0.08 + sin(_time * 1.5) * 0.04
		draw_arc(Vector2.ZERO, eff_range * 0.8, 0, TAU, 36, Color(0.2, 0.8, 0.3, aura_alpha), 2.0)
		# Orbiting ankh symbols (small crosses)
		for ai in range(4):
			var aa = _time * 0.6 + float(ai) * TAU / 4.0
			var ar = eff_range * 0.5
			var ap = Vector2(cos(aa) * ar, sin(aa) * ar * 0.4)
			draw_line(ap + Vector2(0, -3), ap + Vector2(0, 3), Color(0.2, 0.8, 0.3, 0.3), 1.5)
			draw_line(ap + Vector2(-2, -1), ap + Vector2(2, -1), Color(0.2, 0.8, 0.3, 0.3), 1.5)

	# Embalmer's Touch flash
	if _embalmer_flash > 0.0:
		var ef_r = 30.0 + (1.0 - _embalmer_flash) * 50.0
		draw_arc(Vector2.ZERO, ef_r, 0, TAU, 24, Color(0.6, 0.4, 0.8, _embalmer_flash * 0.3), 3.0)

	# Ammit devour flash
	if _ammit_flash > 0.0:
		var af_r = 25.0 + (1.0 - _ammit_flash) * 60.0
		for ji in range(6):
			var ja = TAU * float(ji) / 6.0 + _ammit_flash * 2.0
			var jp = Vector2.from_angle(ja) * af_r
			draw_circle(jp, 3.0, Color(0.9, 0.2, 0.1, _ammit_flash * 0.5))

	# Duat Gateway flash
	if _duat_flash > 0.0:
		var df_r = 20.0 + (1.0 - _duat_flash) * 40.0
		draw_arc(Vector2.ZERO, df_r, 0, TAU, 32, Color(0.5, 0.1, 0.7, _duat_flash * 0.4), 4.0)
		draw_arc(Vector2.ZERO, df_r * 0.6, 0, TAU, 24, Color(0.6, 0.2, 0.8, _duat_flash * 0.3), 2.0)

	# Sandstorm flash
	if _sandstorm_flash > 0.0:
		var sf_range = eff_range * 2.0
		for si in range(16):
			var sa = TAU * float(si) / 16.0 + _sandstorm_flash * 4.0
			var sr = sf_range * (0.3 + randf() * 0.7) * (1.0 - _sandstorm_flash * 0.3)
			var sp = Vector2.from_angle(sa) * sr
			draw_circle(sp, 2.0 + randf() * 2.0, Color(0.8, 0.7, 0.4, _sandstorm_flash * 0.3))

	# Ankh heal flash
	if _ankh_flash > 0.0:
		draw_circle(Vector2.ZERO, 15.0 + (1.0 - _ankh_flash) * 20.0, Color(0.2, 0.9, 0.4, _ankh_flash * 0.25))

	# === PROGRESSIVE ABILITY VISUAL EFFECTS ===
	if _prog_canopic_flash > 0.0:
		draw_arc(Vector2.ZERO, 30.0, 0, TAU, 24, Color(0.3, 0.7, 0.85, _prog_canopic_flash * 0.3), 3.0)
	if _prog_scarab_flash > 0.0:
		for si in range(5):
			var sa = TAU * float(si) / 5.0 + _time * 3.0
			var sp = Vector2.from_angle(sa) * (20.0 + (1.0 - _prog_scarab_flash) * 15.0)
			draw_circle(sp, 2.0, Color(0.3, 0.5, 0.1, _prog_scarab_flash * 0.5))
	if _prog_duat_flash > 0.0:
		draw_arc(Vector2.ZERO, 25.0, 0, TAU, 24, Color(0.5, 0.1, 0.7, _prog_duat_flash * 0.4), 3.0)
	if _prog_ammit_flash > 0.0:
		draw_circle(Vector2.ZERO, 20.0 + (1.0 - _prog_ammit_flash) * 30.0, Color(0.9, 0.15, 0.1, _prog_ammit_flash * 0.3))
	if _prog_ankh_flash > 0.0:
		draw_circle(Vector2.ZERO, 18.0, Color(0.2, 0.9, 0.4, _prog_ankh_flash * 0.3))
	if _prog_sandstorm_flash > 0.0:
		for si in range(10):
			var sa = TAU * float(si) / 10.0 + _prog_sandstorm_flash * 3.0
			var sr = eff_range * 1.5 * (1.0 - _prog_sandstorm_flash * 0.2)
			draw_circle(Vector2.from_angle(sa) * sr, 2.5, Color(0.8, 0.7, 0.4, _prog_sandstorm_flash * 0.3))
	if _prog_sacred_flash > 0.0:
		draw_arc(Vector2.ZERO, eff_range * 0.6, 0, TAU, 32, Color(0.2, 0.8, 0.3, _prog_sacred_flash * 0.25), 2.5)

	# === 5. SAND PLATFORM ===
	var plat_y = 24.0
	draw_circle(Vector2(0, plat_y + 5), 30.0, Color(0, 0, 0, 0.18))
	draw_set_transform(Vector2(0, plat_y), 0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 27.0, Color(0.72, 0.62, 0.40))
	draw_circle(Vector2.ZERO, 22.0, Color(0.80, 0.70, 0.48))
	# Sand swirl details
	for si in range(6):
		var sa = TAU * float(si) / 6.0 + _time * 0.3
		draw_circle(Vector2.from_angle(sa) * 18.0, 2.0, Color(0.65, 0.55, 0.35, 0.4))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	# === 6. TIER PIPS (gold/teal Egyptian theme) ===
	for i in range(upgrade_tier):
		var pip_angle = -PI / 2.0 + float(i) * (TAU / 5.0) - (float(upgrade_tier - 1) * TAU / 10.0)
		var pip_pos = Vector2(cos(pip_angle) * 24.0, plat_y + sin(pip_angle) * 8.0)
		var pip_col: Color
		match i:
			0: pip_col = Color(0.85, 0.75, 0.3)   # gold (Scales)
			1: pip_col = Color(0.3, 0.7, 0.85)     # teal (Canopic)
			2: pip_col = Color(0.5, 0.65, 0.2)     # scarab green
			3: pip_col = Color(0.9, 0.3, 0.15)     # ammit red
			4: pip_col = Color(0.2, 0.8, 0.4)      # sacred green
			_: pip_col = Color(0.85, 0.75, 0.3)
		draw_circle(pip_pos, 4.0, pip_col)
		draw_circle(pip_pos, 5.5, Color(pip_col.r, pip_col.g, pip_col.b, 0.15))

	# === SPRITE RENDERING ===
	if sprite_texture:
		var _active_tex = sprite_texture
		if _attack_anim > 0.15 and _sprite_attack:
			_active_tex = _sprite_attack
		elif _flair_active > 0.0 and _flair_current:
			_active_tex = _flair_current
		var _ss = Vector2(sprite_texture.get_width(), sprite_texture.get_height())
		var _sf = 160.0 / _ss.y
		var _sd = _ss * _sf
		var breathe_scl = 1.0 + sin(_time * 1.2) * 0.010
		var sway_rot = sin(_time * 0.6) * 0.015
		var s_aim_lean = sin(aim_angle) * 0.030
		var recoil_off = Vector2.ZERO
		var atk_scl = Vector2.ONE
		if _attack_anim > 0.0:
			var tier_r = 1.0 + float(upgrade_tier) * 0.15
			var rt = _attack_anim * _attack_anim
			recoil_off = Vector2.from_angle(aim_angle) * rt * 4.0 * tier_r
			var sq = clampf(_attack_anim * 2.5, 0.0, 1.0)
			atk_scl = Vector2(1.0 + sq * (0.12 + float(upgrade_tier) * 0.02), 1.0 - sq * (0.08 + float(upgrade_tier) * 0.015))
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
		# === PROCEDURAL CHARACTER -- Anubis (jackal-headed god) ===
		var OL = Color(0.06, 0.06, 0.08)
		var breath = breathe * 0.5

		# Chibi positions
		var feet_y = body_offset + Vector2(sway * 1.0, 10.0)
		var leg_top = body_offset + Vector2(sway * 0.6, 0.0)
		var torso_center = body_offset + Vector2(sway * 0.3, -8.0 - breath * 0.5)
		var neck_base = body_offset + Vector2(sway * 0.15, -14.0 - breath * 0.3)
		var head_center = body_offset + Vector2(sway * 0.08, -26.0)

		# Colors -- dark jackal fur + gold accents
		var fur = Color(0.15, 0.12, 0.10)
		var fur_hi = Color(0.25, 0.20, 0.16)
		var gold = Color(0.85, 0.75, 0.3)
		var gold_dk = Color(0.65, 0.55, 0.2)
		var cloth_white = Color(0.90, 0.88, 0.82)
		var cloth_dk = Color(0.70, 0.68, 0.62)
		var teal = Color(0.15, 0.55, 0.65)

		# === LEGS (wrapped in white linen) ===
		var l_foot = feet_y + Vector2(-6, 0)
		var r_foot = feet_y + Vector2(6, 0)
		# Sandals
		draw_circle(l_foot, 5.0, OL)
		draw_circle(l_foot, 3.5, Color(0.55, 0.42, 0.25))
		draw_circle(r_foot, 5.0, OL)
		draw_circle(r_foot, 3.5, Color(0.55, 0.42, 0.25))
		# Legs -- white wraps
		draw_line(l_foot + Vector2(0, -4), leg_top + Vector2(-4, 0), OL, 10.0)
		draw_line(l_foot + Vector2(0, -4), leg_top + Vector2(-4, 0), cloth_white, 7.0)
		draw_line(r_foot + Vector2(0, -4), leg_top + Vector2(4, 0), OL, 10.0)
		draw_line(r_foot + Vector2(0, -4), leg_top + Vector2(4, 0), cloth_white, 7.0)
		# Wrap lines
		for wi in range(3):
			var wt = 0.25 + float(wi) * 0.25
			var wl = l_foot.lerp(leg_top + Vector2(-4, 0), wt)
			var wr = r_foot.lerp(leg_top + Vector2(4, 0), wt)
			draw_line(wl + Vector2(-3, 0), wl + Vector2(3, 0), cloth_dk, 1.0)
			draw_line(wr + Vector2(-3, 0), wr + Vector2(3, 0), cloth_dk, 1.0)

		# === TORSO (white linen robe with gold collar) ===
		var torso_pts = PackedVector2Array([
			leg_top + Vector2(-8, 0), leg_top + Vector2(8, 0),
			torso_center + Vector2(10, 2), torso_center + Vector2(10, -6),
			neck_base + Vector2(6, 0), neck_base + Vector2(-6, 0),
			torso_center + Vector2(-10, -6), torso_center + Vector2(-10, 2),
		])
		draw_colored_polygon(torso_pts, OL)
		var torso_inner = PackedVector2Array([
			leg_top + Vector2(-6.5, 1), leg_top + Vector2(6.5, 1),
			torso_center + Vector2(8.5, 2), torso_center + Vector2(8.5, -5),
			neck_base + Vector2(4.5, 1), neck_base + Vector2(-4.5, 1),
			torso_center + Vector2(-8.5, -5), torso_center + Vector2(-8.5, 2),
		])
		draw_colored_polygon(torso_inner, cloth_white)
		# Gold collar/usekh
		draw_line(neck_base + Vector2(-7, 0), neck_base + Vector2(7, 0), OL, 5.0)
		draw_line(neck_base + Vector2(-6, 0), neck_base + Vector2(6, 0), gold, 3.0)
		draw_line(neck_base + Vector2(-5, 1), neck_base + Vector2(5, 1), gold_dk, 2.0)
		# Teal gem at center of collar
		draw_circle(neck_base + Vector2(0, 0), 2.5, teal)

		# === ARMS (dark fur, gold bracers) ===
		var l_shoulder = torso_center + Vector2(-10, -4)
		var r_shoulder = torso_center + Vector2(10, -4)
		var l_hand = l_shoulder + Vector2(-6, 12) + dir * 3.0
		var r_hand = r_shoulder + Vector2(6, 12) + dir * 3.0
		# Left arm
		draw_line(l_shoulder, l_hand, OL, 8.0)
		draw_line(l_shoulder, l_hand, fur, 5.0)
		# Right arm (holding ankh/staff)
		draw_line(r_shoulder, r_hand, OL, 8.0)
		draw_line(r_shoulder, r_hand, fur, 5.0)
		# Gold bracers
		draw_line(l_shoulder + Vector2(-1, 6), l_shoulder + Vector2(-5, 8), gold, 3.0)
		draw_line(r_shoulder + Vector2(1, 6), r_shoulder + Vector2(5, 8), gold, 3.0)
		# Ankh in right hand
		var ankh_pos = r_hand + Vector2(2, -2)
		draw_line(ankh_pos + Vector2(0, -4), ankh_pos + Vector2(0, 6), gold, 2.5)
		draw_line(ankh_pos + Vector2(-3, 0), ankh_pos + Vector2(3, 0), gold, 2.0)
		draw_arc(ankh_pos + Vector2(0, -6), 3.0, 0, TAU, 12, gold, 2.0)

		# === HEAD (jackal with pointed ears) ===
		# Jackal snout
		var snout_tip = head_center + dir * 10.0
		var snout_pts = PackedVector2Array([
			head_center + Vector2(-6, -2), head_center + Vector2(6, -2),
			snout_tip + Vector2(2, 0), snout_tip,
			snout_tip + Vector2(-2, 0),
		])
		draw_colored_polygon(snout_pts, OL)
		var snout_inner = PackedVector2Array([
			head_center + Vector2(-5, -1.5), head_center + Vector2(5, -1.5),
			snout_tip + Vector2(1, 0.5), snout_tip + Vector2(0, 0.5),
			snout_tip + Vector2(-1, 0.5),
		])
		draw_colored_polygon(snout_inner, fur)
		# Main head (round, large chibi)
		draw_circle(head_center, 12.0, OL)
		draw_circle(head_center, 10.0, fur)
		draw_circle(head_center + Vector2(0, 1), 8.0, fur_hi)
		# Eyes -- glowing gold
		var eye_glow = 0.7 + sin(_time * 3.0) * 0.3
		draw_circle(head_center + Vector2(-4, -2), 2.5, Color(0.85, 0.75, 0.2, eye_glow))
		draw_circle(head_center + Vector2(4, -2), 2.5, Color(0.85, 0.75, 0.2, eye_glow))
		draw_circle(head_center + Vector2(-4, -2), 1.2, Color(0.1, 0.08, 0.05))
		draw_circle(head_center + Vector2(4, -2), 1.2, Color(0.1, 0.08, 0.05))
		# Pointed jackal ears
		var l_ear = PackedVector2Array([
			head_center + Vector2(-8, -8), head_center + Vector2(-5, -18),
			head_center + Vector2(-2, -8),
		])
		draw_colored_polygon(l_ear, OL)
		var l_ear_inner = PackedVector2Array([
			head_center + Vector2(-7, -9), head_center + Vector2(-5, -16),
			head_center + Vector2(-3, -9),
		])
		draw_colored_polygon(l_ear_inner, fur)
		var r_ear = PackedVector2Array([
			head_center + Vector2(8, -8), head_center + Vector2(5, -18),
			head_center + Vector2(2, -8),
		])
		draw_colored_polygon(r_ear, OL)
		var r_ear_inner = PackedVector2Array([
			head_center + Vector2(7, -9), head_center + Vector2(5, -16),
			head_center + Vector2(3, -9),
		])
		draw_colored_polygon(r_ear_inner, fur)
		# Nemes headdress gold stripes
		draw_line(head_center + Vector2(-8, -4), head_center + Vector2(-10, 4), gold, 2.5)
		draw_line(head_center + Vector2(8, -4), head_center + Vector2(10, 4), gold, 2.5)
		draw_line(head_center + Vector2(-9, -1), head_center + Vector2(-11, 6), gold_dk, 1.5)
		draw_line(head_center + Vector2(9, -1), head_center + Vector2(11, 6), gold_dk, 1.5)

	# Reset transform
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

# === PATH UPGRADE SYSTEM ===

func apply_path_upgrade(path: String, tier: int) -> void:
	match path:
		"A":
			match tier:
				1: # Scales of Ma'at -- +20% dmg, reveal HP
					damage *= 1.2
					_hp_reveal_active = true
				2: # Embalmer's Touch -- slow strongest every 15s
					_embalmer_active = true
					_embalmer_timer = _embalmer_cooldown
				3: # Ammit the Devourer -- instakill every 10th kill
					_ammit_active = true
					_ammit_kill_counter = 0
		"B":
			match tier:
				1: # Canopic Guardian -- shield absorbs 60 dmg/15s
					_canopic_active = true
					_canopic_shield = _canopic_max_shield
					_canopic_timer = _canopic_cooldown
				2: # Ankh of Life -- heal 1 life every 25s
					_ankh_active = true
					_ankh_timer = _ankh_cooldown
				3: # Lord of Sacred Land -- drain aura + self-resurrect
					_sacred_land_active = true
					_sacred_land_resurrect = true
		"C":
			match tier:
				1: # Desert Scarabs -- DoT on attacks
					_scarab_dot_active = true
				2: # Duat Gateway -- pull enemies back every 20s
					_duat_active = true
					_duat_timer = _duat_cooldown
				3: # Sandstorm Apocalypse -- massive AoE every 18s
					_sandstorm_active = true
					_sandstorm_timer = _sandstorm_cooldown
	# Re-apply accumulated stat boosts
	damage += _accumulated_stat_boosts["damage"]
	fire_rate += _accumulated_stat_boosts["fire_rate"]
	attack_range += _accumulated_stat_boosts["attack_range"]
	gold_bonus += _accumulated_stat_boosts["gold_bonus"]

func purchase_upgrade() -> bool:
	if upgrade_tier >= TIER_COSTS.size():
		return false
	var cost = TIER_COSTS[upgrade_tier]
	var main_node = get_tree().get_first_node_in_group("main")
	if not main_node or not main_node.spend_gold(cost):
		return false
	upgrade_tier += 1
	_refresh_tier_sounds()
	_upgrade_flash = 3.0
	_upgrade_name = TIER_NAMES[upgrade_tier - 1]
	if _upgrade_player and not _is_sfx_muted():
		_upgrade_player.play()
	return true

func get_next_upgrade_info() -> Dictionary:
	if upgrade_tier >= TIER_COSTS.size():
		return {}
	return {
		"name": TIER_NAMES[upgrade_tier],
		"description": ABILITY_DESCRIPTIONS[upgrade_tier],
		"cost": TIER_COSTS[upgrade_tier]
	}

func get_tower_display_name() -> String:
	return "Anubis"

func get_sell_value() -> int:
	var total = base_cost
	for i in range(upgrade_tier):
		total += TIER_COSTS[i]
	return int(total * 0.6)

# === COMBAT METHODS ===

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
			0:  # First -- furthest along path
				if enemy.progress_ratio > best_val:
					best = enemy
					best_val = enemy.progress_ratio
			1:  # Last -- earliest on path
				if enemy.progress_ratio < best_val:
					best = enemy
					best_val = enemy.progress_ratio
			2:  # Close -- nearest to tower
				if best == null or dist < best_val:
					best = enemy
					best_val = dist
			3:  # Strong -- highest HP
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

	# HP reveal (Path A/1 or Prog 0)
	if _hp_reveal_active or prog_abilities[0]:
		if is_instance_valid(target) and "hp_revealed" in target:
			target.hp_revealed = true

	# Apply damage
	if is_instance_valid(target) and target.has_method("take_damage"):
		var hp_before = target.health if "health" in target else 0.0
		target.take_damage(eff_damage, "magic")
		register_damage(eff_damage)
		if hp_before > 0.0 and (not is_instance_valid(target) or target.health <= 0.0):
			register_kill()

	# Scarab DoT (Path C/1 or Prog 2)
	if (_scarab_dot_active or prog_abilities[2]) and is_instance_valid(target):
		if target.has_method("apply_dot"):
			target.apply_dot(eff_damage * 0.3, 2.0, "scarab")
			if _scarab_player and not _is_sfx_muted():
				_scarab_player.play()

func _embalmer_touch() -> void:
	# Slow strongest enemy in range for 4s + DoT
	var enemies = (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies"))
	var strongest: Node2D = null
	var highest_hp: float = 0.0
	var eff_range = attack_range * _range_mult()
	for enemy in enemies:
		if enemy.has_method("is_targetable") and not enemy.is_targetable():
			continue
		if global_position.distance_to(enemy.global_position) > eff_range:
			continue
		var hp = enemy.health if "health" in enemy else 0.0
		if hp > highest_hp:
			highest_hp = hp
			strongest = enemy
	if strongest:
		if strongest.has_method("apply_slow"):
			strongest.apply_slow(0.5, 4.0)
		if strongest.has_method("apply_dot"):
			strongest.apply_dot(damage * 0.5, 4.0, "embalm")
		_embalmer_flash = 1.0
		if _judgment_player and not _is_sfx_muted():
			_judgment_player.play()

func _ankh_heal() -> void:
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("restore_life"):
		main.restore_life(1)
		_ankh_flash = 1.0
		if is_instance_valid(_main_node):
			_main_node.spawn_floating_text(global_position + Vector2(0, -40), "+1 LIFE", Color(0.2, 0.9, 0.4), 16.0, 1.5)

func _process_sacred_land_aura(delta: float) -> void:
	# Drain 2% HP/s from enemies in range, buff all towers +10%
	var eff_range = attack_range * _range_mult()
	var enemies = (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies"))
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) > eff_range:
			continue
		if enemy.has_method("take_damage"):
			var max_hp = enemy.max_health if "max_health" in enemy else 100.0
			var drain = max_hp * 0.02 * delta
			enemy.take_damage(drain, "magic")
			register_damage(drain)

func _duat_gateway() -> void:
	# Pull 3 enemies back 200px
	var enemies = (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies"))
	var in_range: Array = []
	var eff_range = attack_range * _range_mult()
	for enemy in enemies:
		if enemy.has_method("is_targetable") and not enemy.is_targetable():
			continue
		if global_position.distance_to(enemy.global_position) < eff_range:
			in_range.append(enemy)
	in_range.shuffle()
	var count = mini(3, in_range.size())
	for i in range(count):
		if is_instance_valid(in_range[i]) and in_range[i].has_method("push_back"):
			in_range[i].push_back(200.0)
	_duat_flash = 1.0
	if _judgment_player and not _is_sfx_muted():
		_judgment_player.play()
	if is_instance_valid(_main_node):
		_main_node.spawn_floating_text(global_position + Vector2(0, -40), "DUAT GATEWAY", Color(0.5, 0.1, 0.7), 14.0, 1.2)

func _sandstorm_strike() -> void:
	# Hit all enemies in 2x range for 4x damage
	var storm_range = attack_range * _range_mult() * 2.0
	var storm_dmg = damage * 4.0 * _damage_mult()
	var enemies = (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies"))
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) > storm_range:
			continue
		if enemy.has_method("take_damage"):
			var hp_before = enemy.health if "health" in enemy else 0.0
			enemy.take_damage(storm_dmg, "magic")
			register_damage(storm_dmg)
			if hp_before > 0.0 and (not is_instance_valid(enemy) or enemy.health <= 0.0):
				register_kill()
		# Blind effect
		if enemy.has_method("apply_blind"):
			enemy.apply_blind(3.0)
	_sandstorm_flash = 1.0
	if is_instance_valid(_main_node):
		_main_node.spawn_floating_text(global_position + Vector2(0, -40), "SANDSTORM!", Color(0.8, 0.7, 0.4), 16.0, 1.5)
		_main_node.trigger_camera_shake(8.0, 0.8)

# === KILL AND DAMAGE TRACKING ===

func register_kill() -> void:
	kill_count += 1
	_upgrade_flash = 0.5

	# Path A/3: Ammit the Devourer -- instakill every 10th kill
	if _ammit_active:
		_ammit_kill_counter += 1
		if _ammit_kill_counter >= 10:
			_ammit_kill_counter = 0
			_ammit_devour()

	# Progressive ability 5: Ammit's Hunger
	if prog_abilities[5]:
		_prog_ammit_kill_counter += 1
		if _prog_ammit_kill_counter >= 10:
			_prog_ammit_kill_counter = 0
			_ammit_devour()

func _ammit_devour() -> void:
	# Instakill strongest enemy in range
	var enemies = (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies"))
	var strongest: Node2D = null
	var highest_hp: float = 0.0
	var eff_range = attack_range * _range_mult()
	for enemy in enemies:
		if enemy.has_method("is_targetable") and not enemy.is_targetable():
			continue
		if global_position.distance_to(enemy.global_position) > eff_range:
			continue
		var hp = enemy.health if "health" in enemy else 0.0
		if hp > highest_hp:
			highest_hp = hp
			strongest = enemy
	if strongest and is_instance_valid(strongest) and strongest.has_method("take_damage"):
		var lethal = strongest.health if "health" in strongest else 9999.0
		strongest.take_damage(lethal + 1.0, "devour")
		register_damage(lethal)
		_ammit_flash = 1.0
		if is_instance_valid(_main_node):
			_main_node.spawn_floating_text(global_position + Vector2(0, -40), "DEVOURED!", Color(0.9, 0.2, 0.1), 16.0, 1.5)

func register_damage(amount: float) -> void:
	damage_dealt += amount
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("register_tower_damage"):
		main.register_tower_damage(main.TowerType.ANUBIS, amount)
	_check_upgrades()

func absorb_damage(incoming: float) -> float:
	# Canopic shield absorption
	if _canopic_active and _canopic_shield > 0.0:
		var absorbed = minf(incoming, _canopic_shield)
		_canopic_shield -= absorbed
		return incoming - absorbed
	# Progressive canopic shield
	if prog_abilities[1] and _prog_canopic_shield > 0.0:
		var absorbed = minf(incoming, _prog_canopic_shield)
		_prog_canopic_shield -= absorbed
		return incoming - absorbed
	return incoming

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
	var dmg_boost = 2.0
	var rate_boost = 0.02
	var range_boost = 4.0
	var gold_boost_val = 0
	damage += dmg_boost
	fire_rate += rate_boost
	attack_range += range_boost
	gold_bonus += gold_boost_val
	_accumulated_stat_boosts["damage"] += dmg_boost
	_accumulated_stat_boosts["fire_rate"] += rate_boost
	_accumulated_stat_boosts["attack_range"] += range_boost
	_accumulated_stat_boosts["gold_bonus"] += gold_boost_val

func choose_ability(index: int) -> void:
	ability_chosen = true
	awaiting_ability_choice = false
	upgrade_tier = index + 1
	_upgrade_flash = 3.0
	_upgrade_name = TIER_NAMES[index]

# === SOUND GENERATION ===

func _generate_tier_sounds() -> void:
	var mix_rate := 44100
	# Egyptian pentatonic scale: D4, F4, G4, A4, C5, D5 -- minor/mysterious
	var melody := [293.66, 349.23, 392.00, 440.00, 523.25, 587.33, 440.00, 349.23]
	_attack_sounds_by_tier = []
	for tier in range(5):
		var tier_sounds: Array = []
		var dur := 0.4 + tier * 0.05
		var vol := 0.22 + tier * 0.015
		for note_idx in melody.size():
			var freq: float = melody[note_idx]
			var total := int(mix_rate * dur)
			var samples := PackedFloat32Array()
			samples.resize(total)
			for i in total:
				var t := float(i) / float(mix_rate)
				var env := minf(t * 20.0, 1.0) * exp(-t * 3.5)
				# Dark resonant tone with vibrato
				var vib := sin(t * 5.0 * TAU) * 6.0
				var s := sin(t * (freq + vib) * TAU) * 0.7
				# Fifth harmonic for hollow tone
				s += sin(t * (freq * 1.5 + vib) * TAU) * 0.2
				# Sub octave
				s += sin(t * (freq * 0.5) * TAU) * 0.15
				samples[i] = clampf(s * env * vol * 0.45, -1.0, 1.0)
			var att_len := mini(int(0.012 * mix_rate), total)
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
	if main and main.survivor_progress.has(main.TowerType.ANUBIS):
		var p = main.survivor_progress[main.TowerType.ANUBIS]
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
	# Ability 0: Scales of Ma'at -- +20% damage applied in _damage_mult
	# Ability 1: Canopic Guardian -- shield handled in _process_progressive_abilities
	# Others are timer-based, applied in _process_progressive_abilities
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
	_prog_scales_flash = max(_prog_scales_flash - delta * 2.0, 0.0)
	_prog_canopic_flash = max(_prog_canopic_flash - delta * 2.0, 0.0)
	_prog_scarab_flash = max(_prog_scarab_flash - delta * 2.0, 0.0)
	_prog_embalmer_flash = max(_prog_embalmer_flash - delta * 2.0, 0.0)
	_prog_duat_flash = max(_prog_duat_flash - delta * 2.0, 0.0)
	_prog_ammit_flash = max(_prog_ammit_flash - delta * 2.0, 0.0)
	_prog_ankh_flash = max(_prog_ankh_flash - delta * 2.0, 0.0)
	_prog_sandstorm_flash = max(_prog_sandstorm_flash - delta * 2.0, 0.0)
	_prog_sacred_flash = max(_prog_sacred_flash - delta * 2.0, 0.0)

	# Ability 1: Canopic Guardian -- recharge shield every 15s
	if prog_abilities[1]:
		_prog_canopic_timer -= delta
		if _prog_canopic_timer <= 0.0 and _prog_canopic_shield <= 0.0:
			_prog_canopic_shield = 60.0
			_prog_canopic_timer = 15.0
			_prog_canopic_flash = 1.0

	# Ability 3: Embalmer's Touch -- slow strongest every 15s
	if prog_abilities[3]:
		_prog_embalmer_timer -= delta
		if _prog_embalmer_timer <= 0.0 and _has_enemies_in_range():
			_embalmer_touch()
			_prog_embalmer_timer = 15.0
			_prog_embalmer_flash = 1.0

	# Ability 4: Duat Gateway -- pull enemies every 20s
	if prog_abilities[4]:
		_prog_duat_timer -= delta
		if _prog_duat_timer <= 0.0 and _has_enemies_in_range():
			_duat_gateway()
			_prog_duat_timer = 20.0
			_prog_duat_flash = 1.0

	# Ability 6: Ankh of Life -- heal 1 life every 25s
	if prog_abilities[6]:
		_prog_ankh_timer -= delta
		if _prog_ankh_timer <= 0.0:
			_ankh_heal()
			_prog_ankh_timer = 25.0
			_prog_ankh_flash = 1.0

	# Ability 7: Sandstorm Wrath -- sandstorm every 18s in 2x range for 4x
	if prog_abilities[7]:
		_prog_sandstorm_timer -= delta
		if _prog_sandstorm_timer <= 0.0 and _has_enemies_in_range():
			_sandstorm_strike()
			_prog_sandstorm_timer = 18.0
			_prog_sandstorm_flash = 1.0

	# Ability 8: Lord of the Sacred Land -- permanent aura (drain + tower buff)
	if prog_abilities[8]:
		_process_sacred_land_aura(delta)

# === SYNERGY BUFFS ===

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

# === ACTIVE HERO ABILITY: Judgment Circle (instakill below 20% HP, 30s CD) ===

func activate_hero_ability() -> void:
	if not active_ability_ready:
		return
	var enemies = (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies"))
	for e in enemies:
		if global_position.distance_to(e.global_position) < attack_range * _range_mult() * 1.5:
			if is_instance_valid(e) and e.has_method("take_damage"):
				var max_hp = e.max_health if "max_health" in e else 100.0
				var hp = e.health if "health" in e else 0.0
				if hp <= max_hp * 0.2:
					e.take_damage(hp + 1.0, "judgment")
					register_damage(hp)
					register_kill()
	active_ability_ready = false
	active_ability_cooldown = active_ability_max_cd
	if is_instance_valid(_main_node):
		_main_node.spawn_floating_text(global_position + Vector2(0, -40), "JUDGMENT!", Color(0.85, 0.75, 0.3), 16.0, 1.5)

func get_active_ability_name() -> String:
	return "Judgment Circle"

func get_active_ability_desc() -> String:
	return "Instakill enemies below 20% HP (30s CD)"

# === STAT MULTIPLIERS ===

func _damage_mult() -> float:
	var mult: float = (1.0 + _synergy_buffs.get("damage", 0.0) + _meta_buffs.get("damage", 0.0)) * power_damage_mult
	# Prog ability 0: Scales of Ma'at -- +20% damage
	if prog_abilities[0]:
		mult *= 1.2
	# Sacred Land tower buff +10%
	if _sacred_land_active or prog_abilities[8]:
		mult *= 1.1
	return mult

func _range_mult() -> float:
	return 1.0 + _synergy_buffs.get("range", 0.0) + _meta_buffs.get("range", 0.0)

func _speed_mult() -> float:
	return 1.0 + _synergy_buffs.get("attack_speed", 0.0) + _meta_buffs.get("attack_speed", 0.0)

func _gold_mult() -> float:
	return 1.0 + _synergy_buffs.get("gold_bonus", 0.0) + _meta_buffs.get("gold_bonus", 0.0)
