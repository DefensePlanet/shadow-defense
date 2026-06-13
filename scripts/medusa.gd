extends Node2D
## Medusa — gorgon tower from Greek Mythology (Ovid's Metamorphoses).
## Petrifies enemies, snake hair venom, serpent tail attacks.
## Path A "Gorgon's Gaze": Petrification and stone statues
## Path B "Serpent Queen": Venom DoT and snake allies
## Path C "Athena's Curse": Damage reduction, curses, and reflect

# Base stats
var damage: float = 20.0
var fire_rate: float = 0.90
var attack_range: float = 150.0
var fire_cooldown: float = 0.0
var aim_angle: float = 0.0
var sprite_texture: Texture2D = null
# Flair animation (idle poses — randomized every 8s)
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

# Animation
var _time: float = 0.0
var _attack_anim: float = 0.0
var _build_timer: float = 0.0

var _home_position: Vector2 = Vector2.ZERO

# === PATH UPGRADE STATE ===
# Path A: Gorgon's Gaze
var _slow_on_attack: bool = false
var _slow_percent: float = 0.15
var _stone_gaze_active: bool = false
var _stone_gaze_timer: float = 12.0
var _stone_gaze_cooldown: float = 12.0
var _stone_gaze_duration: float = 3.0
var _stone_gaze_flash: float = 0.0
var _garden_of_stone_active: bool = false
var _petrify_count: int = 1  # How many enemies petrified at once (3 at tier 3)

# Path B: Serpent Queen
var _venom_dot_active: bool = false
var _venom_dot_duration: float = 3.0
var _venom_max_stacks: int = 5
var _serpent_swarm_active: bool = false
var _serpent_swarm_timer: float = 18.0
var _serpent_swarm_cooldown: float = 18.0
var _serpent_swarm_flash: float = 0.0
var _serpent_allies_active: bool = false
var _serpent_allies_timer: float = 15.0
var _serpent_allies_cooldown: float = 15.0
var _serpent_allies_flash: float = 0.0
var _active_serpents: Array = []

# Path C: Athena's Curse
var _damage_reduction: float = 0.0
var _athenas_curse_active: bool = false
var _athenas_curse_timer: float = 15.0
var _athenas_curse_cooldown: float = 15.0
var _athenas_curse_count: int = 3
var _athenas_curse_flash: float = 0.0
var _mirror_reflect_active: bool = false
var _mirror_reflect_flash: float = 0.0

# === PROGRESSIVE ABILITIES (9 tiers, unlocked via lifetime damage) ===
const PROG_ABILITY_NAMES = [
	"Gorgon's Wrath", "Serpent Scales", "Venom Fangs", "Stone Gaze",
	"Athena's Curse", "Serpent Swarm", "Perseus's Bane",
	"Blood of the Gorgon", "Garden of Stone"
]
const PROG_ABILITY_DESCS = [
	"+20% dmg, attacks slow 15%",
	"25% less damage taken",
	"Attacks apply poison DoT 3s, stacking",
	"Every 12s, petrify nearest enemy 3s (frozen + 2x dmg)",
	"Every 15s, curse 3 enemies: slowed 60% + 30% more dmg 5s",
	"Every 18s, all snake hair strikes in range for 3x",
	"Every 20s, reflect damage — attackers take 5x",
	"Every 15s, Medusa's blood creates 2 snake allies",
	"Permanent aura: enemies in range 30% slower + 1%HP/s + killed become stone statues"
]
var prog_abilities: Array = [false, false, false, false, false, false, false, false, false]

# Progressive ability timers
var _prog_stone_gaze_timer: float = 12.0
var _prog_athenas_curse_timer: float = 15.0
var _prog_serpent_swarm_timer: float = 18.0
var _prog_perseus_bane_timer: float = 20.0
var _prog_blood_gorgon_timer: float = 15.0
# Visual flash timers for progressive abilities
var _prog_stone_gaze_flash: float = 0.0
var _prog_athenas_curse_flash: float = 0.0
var _prog_serpent_swarm_flash: float = 0.0
var _prog_perseus_bane_flash: float = 0.0
var _prog_blood_gorgon_flash: float = 0.0
var _prog_garden_flash: float = 0.0

const MAX_STAT_LEVEL: int = 10
const STAT_UPGRADE_INTERVAL: float = 8000.0
const ABILITY_THRESHOLD: float = 28000.0
var stat_upgrade_level: int = 0
var ability_chosen: bool = false
var awaiting_ability_choice: bool = false

const TIER_COSTS = [140, 325, 600, 1100, 1800]
const TIER_NAMES = [
	"Gorgon's Wrath",
	"Venom Fangs",
	"Stone Gaze",
	"Serpent Swarm",
	"Garden of Stone"
]
const ABILITY_DESCRIPTIONS = [
	"+20% damage, attacks slow enemies 15%",
	"Attacks apply stacking venom DoT for 3s",
	"Every 12s, petrify nearest enemy for 3s",
	"Every 18s, all snake hair strikes enemies in range for 3x damage",
	"Enemies killed become blocking stone statues + permanent petrify aura"
]

var is_selected: bool = false
var base_cost: int = 0

var spell_bolt_scene = preload("res://scenes/spell_bolt.tscn")

# Attack sounds — hissing serpentine strikes
var _attack_sounds: Array = []
var _attack_sounds_by_tier: Array = []
var _attack_player: AudioStreamPlayer

# Ability sounds
var _petrify_sound: AudioStreamWAV
var _petrify_player: AudioStreamPlayer
var _upgrade_sound: AudioStreamWAV
var _upgrade_player: AudioStreamPlayer
var _hiss_sound: AudioStreamWAV
var _hiss_player: AudioStreamPlayer
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

	# Petrify sound — deep grinding stone + crystalline shatter
	var pet_rate := 22050
	var pet_dur := 0.7
	var pet_samples := PackedFloat32Array()
	pet_samples.resize(int(pet_rate * pet_dur))
	for i in pet_samples.size():
		var t := float(i) / pet_rate
		var s := 0.0
		# Deep grinding stone rumble
		var grind_env := exp(-t * 3.0) * 0.3
		var onset := minf(t * 30.0, 1.0)
		s += sin(TAU * 80.0 * t + sin(TAU * 15.0 * t) * 4.0) * grind_env * onset
		# Crystalline crack overtones
		var crack_env := exp(-t * 5.0) * 0.2
		s += sin(TAU * 1400.0 * t) * crack_env * onset
		s += sin(TAU * 2100.0 * t) * crack_env * 0.3
		# Gritty noise layer
		var noise_env := exp(-t * 4.0) * 0.08
		s += (randf() * 2.0 - 1.0) * noise_env
		pet_samples[i] = clampf(s, -1.0, 1.0)
	_petrify_sound = _samples_to_wav(pet_samples, pet_rate)
	_petrify_player = AudioStreamPlayer.new()
	_petrify_player.stream = _petrify_sound
	_petrify_player.volume_db = -12.0
	add_child(_petrify_player)

	# Upgrade chime — ascending serpentine minor arpeggio (E4→G4→B4)
	var up_rate := 22050
	var up_dur := 0.35
	var up_samples := PackedFloat32Array()
	up_samples.resize(int(up_rate * up_dur))
	var up_notes := [329.63, 392.0, 493.88]  # E4, G4, B4 (minor)
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

	# Snake hiss — breathy sibilant with warbling overtones
	var hiss_rate := 22050
	var hiss_dur := 0.5
	var hiss_samples := PackedFloat32Array()
	hiss_samples.resize(int(hiss_rate * hiss_dur))
	for i in hiss_samples.size():
		var t := float(i) / hiss_rate
		var s := 0.0
		var env := sin(clampf(t * 6.0, 0.0, PI)) * 0.3
		# Sibilant noise — filtered white noise
		s += (randf() * 2.0 - 1.0) * env * 0.6
		# Warbling hiss tone
		var wobble := sin(TAU * 6.0 * t) * 0.3 + 0.7
		s += sin(TAU * 3200.0 * t) * env * 0.15 * wobble
		s += sin(TAU * 4800.0 * t) * env * 0.08 * wobble
		hiss_samples[i] = clampf(s, -1.0, 1.0)
	_hiss_sound = _samples_to_wav(hiss_samples, hiss_rate)
	_hiss_player = AudioStreamPlayer.new()
	_hiss_player.stream = _hiss_sound
	_hiss_player.volume_db = -14.0
	add_child(_hiss_player)

func _process(delta: float) -> void:
	delta = minf(delta, 0.05)  # Cap to prevent physics spikes
	_time += delta
	if _build_timer > 0.0: _build_timer -= delta
	fire_cooldown -= delta
	_upgrade_flash = max(_upgrade_flash - delta * 0.5, 0.0)
	_attack_anim = max(_attack_anim - delta * 3.0, 0.0)
	_stone_gaze_flash = max(_stone_gaze_flash - delta * 2.0, 0.0)
	_serpent_swarm_flash = max(_serpent_swarm_flash - delta * 2.0, 0.0)
	_serpent_allies_flash = max(_serpent_allies_flash - delta * 1.5, 0.0)
	_athenas_curse_flash = max(_athenas_curse_flash - delta * 2.0, 0.0)
	_mirror_reflect_flash = max(_mirror_reflect_flash - delta * 2.0, 0.0)

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
		aim_angle = lerp_angle(aim_angle, desired, 10.0 * delta)
		if fire_cooldown <= 0.0:
			_shoot()
			fire_cooldown = maxf(1.0 / (fire_rate * _speed_mult()), 0.15)
			_attack_anim = 1.0

	# Path A: Stone Gaze timer
	if _stone_gaze_active:
		_stone_gaze_timer -= delta
		if _stone_gaze_timer <= 0.0 and _has_enemies_in_range():
			_trigger_stone_gaze()
			_stone_gaze_timer = _stone_gaze_cooldown

	# Path B: Serpent Swarm timer
	if _serpent_swarm_active:
		_serpent_swarm_timer -= delta
		if _serpent_swarm_timer <= 0.0 and _has_enemies_in_range():
			_trigger_serpent_swarm()
			_serpent_swarm_timer = _serpent_swarm_cooldown

	# Path B: Serpent Allies timer
	if _serpent_allies_active:
		_serpent_allies_timer -= delta
		if _serpent_allies_timer <= 0.0:
			_spawn_serpent_allies()
			_serpent_allies_timer = _serpent_allies_cooldown

	# Path C: Athena's Curse timer
	if _athenas_curse_active:
		_athenas_curse_timer -= delta
		if _athenas_curse_timer <= 0.0 and _has_enemies_in_range():
			_trigger_athenas_curse()
			_athenas_curse_timer = _athenas_curse_cooldown

	# Progressive abilities
	_process_progressive_abilities(delta)

	# Update serpent allies
	_update_serpent_allies(delta)

	# Active ability cooldown
	if not active_ability_ready:
		active_ability_cooldown -= delta
		if active_ability_cooldown <= 0.0:
			active_ability_ready = true
			active_ability_cooldown = 0.0

	queue_redraw()

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
		draw_arc(Vector2.ZERO, eff_range, 0, TAU, 36, Color(0.3, 0.6, 0.2, 0.25 + pulse * 0.15), 2.0)
		draw_arc(Vector2.ZERO, 40.0, 0, TAU, 28, Color(0.3, 0.6, 0.2, ring_alpha), 2.5)
		draw_arc(Vector2.ZERO, 43.0, 0, TAU, 28, Color(0.3, 0.6, 0.2, ring_alpha * 0.4), 1.5)

	# === 2. AIM DIRECTION ===
	var dir = Vector2.from_angle(aim_angle)

	# === 3. IDLE ANIMATION (serpentine sway) ===
	var breathe = sin(_time * 1.2) * 2.0
	var sway = sin(_time * 0.7) * 2.5  # Slow serpentine sway
	var bob = Vector2(sway, -abs(sin(_time * 1.2)) * 2.0 - breathe)
	var body_offset = bob

	# === PROGRESSIVE ABILITY VISUAL EFFECTS ===
	# Ability 1: Gorgon's Wrath — green power glow
	if prog_abilities[0]:
		var glow_alpha = 0.04 + sin(_time * 2.0) * 0.02
		draw_circle(body_offset, 35.0, Color(0.3, 0.6, 0.1, glow_alpha))

	# Ability 4: Stone Gaze flash — grey expanding ring
	if _prog_stone_gaze_flash > 0.0:
		var gaze_r = 20.0 + (1.0 - _prog_stone_gaze_flash) * 40.0
		for gi in range(6):
			var ga = _time * 3.0 + TAU * float(gi) / 6.0
			var gpos = body_offset + Vector2.from_angle(ga) * gaze_r
			draw_circle(gpos, 2.5, Color(0.5, 0.5, 0.4, _prog_stone_gaze_flash * 0.5))
		draw_circle(body_offset, gaze_r * 0.4, Color(0.5, 0.5, 0.4, _prog_stone_gaze_flash * 0.12))

	# Ability 5: Athena's Curse flash — purple cursed spirals
	if _prog_athenas_curse_flash > 0.0:
		var curse_r = 18.0 + (1.0 - _prog_athenas_curse_flash) * 25.0
		for ci in range(5):
			var ca = _time * 4.0 + TAU * float(ci) / 5.0
			var cpos = body_offset + Vector2.from_angle(ca) * curse_r
			draw_circle(cpos, 2.0, Color(0.6, 0.2, 0.7, _prog_athenas_curse_flash * 0.5))

	# Ability 6: Serpent Swarm flash — green snake strike lines
	if _prog_serpent_swarm_flash > 0.0:
		for si in range(8):
			var sa = TAU * float(si) / 8.0 + _prog_serpent_swarm_flash * 3.0
			var s_inner = body_offset + Vector2.from_angle(sa) * 15.0
			var s_outer = body_offset + Vector2.from_angle(sa) * (30.0 + (1.0 - _prog_serpent_swarm_flash) * 20.0)
			draw_line(s_inner, s_outer, Color(0.2, 0.6, 0.1, _prog_serpent_swarm_flash * 0.5), 2.0)

	# Ability 7: Perseus's Bane flash — mirror reflect shimmer
	if _prog_perseus_bane_flash > 0.0:
		var ref_r = 25.0 + (1.0 - _prog_perseus_bane_flash) * 15.0
		draw_arc(body_offset, ref_r, 0, TAU, 24, Color(0.8, 0.8, 0.9, _prog_perseus_bane_flash * 0.3), 2.0)
		for ri in range(6):
			var ra = TAU * float(ri) / 6.0 + _time * 2.0
			var rpos = body_offset + Vector2.from_angle(ra) * ref_r
			draw_circle(rpos, 1.5, Color(0.9, 0.9, 1.0, _prog_perseus_bane_flash * 0.6))

	# Ability 8: Blood of the Gorgon flash — dark green serpent spawn
	if _prog_blood_gorgon_flash > 0.0:
		for bi in range(4):
			var ba = TAU * float(bi) / 4.0 + _prog_blood_gorgon_flash * 2.0
			var bpos = body_offset + Vector2.from_angle(ba) * 20.0
			draw_circle(bpos, 3.0, Color(0.1, 0.4, 0.1, _prog_blood_gorgon_flash * 0.5))
			draw_line(bpos, bpos + Vector2.from_angle(ba) * 8.0, Color(0.2, 0.5, 0.1, _prog_blood_gorgon_flash * 0.4), 1.5)

	# Ability 9: Garden of Stone flash — expanding stone aura
	if _prog_garden_flash > 0.0:
		var garden_r = 30.0 + (1.0 - _prog_garden_flash) * 80.0
		for pi in range(8):
			var pa = TAU * float(pi) / 8.0 + _prog_garden_flash * 1.5
			var pp = Vector2.from_angle(pa) * garden_r * 0.8
			draw_circle(pp, 3.0, Color(0.4, 0.4, 0.35, _prog_garden_flash * 0.4))

	# === PATH UPGRADE VISUAL EFFECTS ===
	# Stone Gaze flash
	if _stone_gaze_flash > 0.0:
		var gaze_ring_r = 30.0 + (1.0 - _stone_gaze_flash) * 50.0
		for gi in range(8):
			var ga = TAU * float(gi) / 8.0 + _stone_gaze_flash * 2.0
			var gpos = Vector2.from_angle(ga) * gaze_ring_r
			draw_circle(gpos, 3.0, Color(0.5, 0.5, 0.4, _stone_gaze_flash * 0.4))

	# Serpent Swarm flash
	if _serpent_swarm_flash > 0.0:
		for si in range(6):
			var sa = TAU * float(si) / 6.0 + _time * 5.0
			var s_start = body_offset + Vector2.from_angle(sa) * 10.0
			var s_end = body_offset + Vector2.from_angle(sa) * (25.0 + (1.0 - _serpent_swarm_flash) * 30.0)
			draw_line(s_start, s_end, Color(0.2, 0.5, 0.1, _serpent_swarm_flash * 0.5), 2.5)

	# Athena's Curse flash
	if _athenas_curse_flash > 0.0:
		var curse_r = 20.0 + (1.0 - _athenas_curse_flash) * 30.0
		for ci in range(3):
			var ca = TAU * float(ci) / 3.0 + _athenas_curse_flash * 3.0
			var cpos = Vector2.from_angle(ca) * curse_r
			draw_circle(cpos, 4.0, Color(0.5, 0.15, 0.6, _athenas_curse_flash * 0.4))

	# Mirror reflect flash
	if _mirror_reflect_flash > 0.0:
		var mir_r = 35.0
		draw_arc(body_offset, mir_r, 0, TAU, 24, Color(0.7, 0.8, 0.9, _mirror_reflect_flash * 0.3), 2.5)

	# === 4. MOSSY STONE PLATFORM ===
	var plat_y = 22.0
	# Platform shadow
	draw_circle(Vector2(0, plat_y + 4), 28.0, Color(0, 0, 0, 0.2))
	# Dark stone platform ellipse
	draw_set_transform(Vector2(0, plat_y), 0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 28.0, Color(0.12, 0.14, 0.10))
	draw_circle(Vector2.ZERO, 25.0, Color(0.18, 0.20, 0.14))
	draw_circle(Vector2.ZERO, 20.0, Color(0.24, 0.26, 0.20))
	# Stone texture cracks
	for si in range(8):
		var sa = TAU * float(si) / 8.0
		draw_circle(Vector2.from_angle(sa) * 16.0, 3.0, Color(0.16, 0.18, 0.12, 0.4))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# Platform top highlight
	draw_set_transform(Vector2(0, plat_y - 2), 0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 22.0, Color(0.30, 0.32, 0.26, 0.3))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	# Green venom mist at base
	for fi in range(7):
		var fa = TAU * float(fi) / 7.0 + _time * 0.3
		var fx = cos(fa) * 22.0 + sin(_time * 0.5 + float(fi)) * 4.0
		var fy = plat_y + sin(fa) * 6.0
		var fsize = 5.0 + sin(_time * 0.8 + float(fi) * 1.3) * 2.0
		var falpha = 0.05 + sin(_time * 0.7 + float(fi)) * 0.02
		if upgrade_tier >= 1:
			falpha += 0.015 * float(upgrade_tier)
		draw_circle(Vector2(fx, fy), fsize, Color(0.15, 0.4, 0.08, falpha))
		draw_circle(Vector2(fx, fy + 2), fsize * 0.7, Color(0.1, 0.3, 0.05, falpha * 0.6))

	# === 5. SNAKE TENDRILS (hair snakes at base) ===
	for ti in range(6):
		var ta = TAU * float(ti) / 6.0 + _time * 0.2
		var t_base = Vector2(cos(ta) * 20.0, plat_y + sin(ta) * 6.0)
		var t_end = t_base + Vector2(sin(_time * 0.6 + float(ti)) * 6.0, 6.0 + sin(_time * 0.9 + float(ti)) * 3.0)
		draw_line(t_base, t_end, Color(0.15, 0.35, 0.08, 0.2), 2.0)
		draw_line(t_end, t_end + Vector2(sin(_time + float(ti)) * 3.0, 4.0), Color(0.1, 0.25, 0.05, 0.12), 1.5)

	# === 6. TIER PIPS (serpentine green / stone grey / venom / dark green) ===
	for i in range(upgrade_tier):
		var pip_angle = -PI / 2.0 + float(i) * (TAU / 5.0) - (float(upgrade_tier - 1) * TAU / 10.0)
		var pip_pos = Vector2(cos(pip_angle) * 22.0, plat_y + sin(pip_angle) * 8.0)
		var pip_col: Color
		match i:
			0: pip_col = Color(0.3, 0.6, 0.15)    # serpentine green
			1: pip_col = Color(0.4, 0.5, 0.2)     # venom yellow-green
			2: pip_col = Color(0.5, 0.5, 0.45)     # stone grey
			3: pip_col = Color(0.15, 0.35, 0.08)   # dark green
			_: pip_col = Color(0.2, 0.4, 0.1)
		draw_circle(pip_pos, 4.0, pip_col)
		draw_circle(pip_pos, 5.5, Color(pip_col.r, pip_col.g, pip_col.b, 0.15))

	# === 7. SPRITE RENDERING ===
	var render_texture = sprite_texture
	if _attack_anim > 0.3 and _sprite_attack:
		render_texture = _sprite_attack
	elif _flair_active > 0.0 and _flair_current:
		render_texture = _flair_current

	if render_texture:
		var tex_size = render_texture.get_size()
		var scale_factor = 160.0 / tex_size.y if tex_size.y > 0 else 1.0
		var draw_size = tex_size * scale_factor
		var draw_pos = body_offset - draw_size / 2.0 + Vector2(0, -draw_size.y * 0.15)
		draw_texture_rect(render_texture, Rect2(draw_pos, draw_size), false)

	# === 8. SERPENT ALLIES VISUAL ===
	for serpent in _active_serpents:
		if serpent.get("alive", false):
			var sp = serpent.get("pos", Vector2.ZERO)
			var sa = _time * 3.0 + serpent.get("offset", 0.0)
			# Snake body
			draw_circle(sp, 4.0, Color(0.2, 0.5, 0.15, 0.7))
			draw_circle(sp + Vector2(cos(sa) * 2.0, sin(sa) * 1.5), 3.0, Color(0.25, 0.55, 0.2, 0.6))
			# Eyes
			draw_circle(sp + Vector2(2, -2), 0.8, Color(0.9, 0.8, 0.1, 0.8))

	# === 9. UPGRADE NAME FLASH ===
	if _upgrade_flash > 0.0 and _game_font:
		var alpha = clampf(_upgrade_flash, 0.0, 1.0) * 0.8
		var y_off = -60.0 - (3.0 - _upgrade_flash) * 8.0
		draw_string(_game_font, body_offset + Vector2(-30, y_off), _upgrade_name, HORIZONTAL_ALIGNMENT_CENTER, 60, 10, Color(0.3, 0.6, 0.15, alpha))

	# === 10. DAMAGE STATS (when selected) ===
	if is_selected and damage_dealt > 0 and _game_font:
		var dmg_text = str(int(damage_dealt))
		draw_string(_game_font, body_offset + Vector2(-20, 45), dmg_text, HORIZONTAL_ALIGNMENT_CENTER, 40, 8, Color(0.8, 0.8, 0.8, 0.5))

	# === 11. GEAR VISUAL OVERLAYS ===
	var _g_neck = body_offset + Vector2(0, -15)
	# Crown
	if gear_crown.size() > 0:
		var gc = body_offset + Vector2(0, -45)
		draw_line(gc + Vector2(-6, 0), gc + Vector2(6, 0), Color(0.3, 0.5, 0.15, 0.6), 2.0)
		for cx in [-4, 0, 4]:
			draw_circle(gc + Vector2(cx, -4), 1.5, Color(0.3, 0.6, 0.15))
	# Amulet
	if gear_amulet.size() > 0:
		var ga = _g_neck + Vector2(0, 3)
		var gpa = (sin(_time * 3.0) + 1.0) * 0.5
		draw_circle(ga, 4.0, Color(0.2, 0.5, 0.15, 0.5 + gpa * 0.3))
		draw_circle(ga, 2.5, Color(0.3, 0.6, 0.2, 0.8))

# === TARGETING ===

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

func _get_note_index() -> int:
	var main = get_tree().get_first_node_in_group("main")
	if main and "music_beat_index" in main:
		return main.music_beat_index
	return 0

func _is_sfx_muted() -> bool:
	var main = get_tree().get_first_node_in_group("main")
	return main and main.get("sfx_muted") == true

# === COMBAT ===

func _shoot() -> void:
	if not target:
		return
	if _attack_player and _attack_sounds.size() > 0 and not _is_sfx_muted():
		_attack_player.stream = _attack_sounds[_get_note_index() % _attack_sounds.size()]
		_attack_player.play()
	_fire_venom_bolt(target)

func _fire_venom_bolt(t: Node2D) -> void:
	var bolt = spell_bolt_scene.instantiate()
	bolt.global_position = global_position + Vector2.from_angle(aim_angle) * 18.0
	var dmg_mult = 1.0
	# Prog ability 1: Gorgon's Wrath — +20% damage
	if prog_abilities[0]:
		dmg_mult *= 1.20
	# Prog ability 6: Serpent Swarm — 3x during active
	if prog_abilities[5] and _prog_serpent_swarm_flash > 0.0:
		dmg_mult *= 3.0
	bolt.damage = damage * dmg_mult * _damage_mult()
	bolt.target = t
	bolt.gold_bonus = int(gold_bonus * _gold_mult())
	bolt.source_tower = self
	# Apply slow on attack (Path A tier 1 or prog ability 1)
	if _slow_on_attack and is_instance_valid(t) and t.has_method("apply_slow"):
		t.apply_slow(_slow_percent, 2.0)
	# Apply venom DoT (Path B tier 1 or prog ability 3)
	if _venom_dot_active and is_instance_valid(t) and t.has_method("apply_poison"):
		t.apply_poison(damage * 0.15 * _damage_mult(), _venom_dot_duration, _venom_max_stacks)
	var _main = get_tree().get_first_node_in_group("main")
	if _main:
		_main.add_child(bolt)
	else:
		bolt.queue_free()

# === PATH ABILITY TRIGGERS ===

func _trigger_stone_gaze() -> void:
	_stone_gaze_flash = 1.0
	if _petrify_player and not _is_sfx_muted(): _petrify_player.play()
	var enemies = _main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")
	var in_range: Array = []
	var max_r = attack_range * _range_mult()
	for e in enemies:
		if is_instance_valid(e) and e.has_method("is_targetable") and e.is_targetable():
			if global_position.distance_to(e.global_position) < max_r:
				in_range.append(e)
	# Sort by distance (nearest first)
	in_range.sort_custom(func(a, b): return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position))
	var count = mini(_petrify_count, in_range.size())
	for i in range(count):
		var e = in_range[i]
		if e.has_method("apply_stun"):
			e.apply_stun(_stone_gaze_duration)
		if is_instance_valid(_main_node):
			_main_node.spawn_floating_text(e.global_position + Vector2(0, -20), "PETRIFIED!", Color(0.5, 0.5, 0.4), 12.0, 1.0)

func _trigger_serpent_swarm() -> void:
	_serpent_swarm_flash = 1.0
	if _hiss_player and not _is_sfx_muted(): _hiss_player.play()
	var enemies = _main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")
	var max_r = attack_range * _range_mult()
	var dmg = damage * 3.0 * _damage_mult()
	for e in enemies:
		if is_instance_valid(e) and e.has_method("take_damage"):
			if global_position.distance_to(e.global_position) < max_r:
				e.take_damage(dmg, "magic")
				register_damage(dmg)
	if is_instance_valid(_main_node):
		_main_node.spawn_floating_text(global_position + Vector2(0, -40), "SERPENT SWARM!", Color(0.2, 0.6, 0.15), 14.0, 1.2)

func _spawn_serpent_allies() -> void:
	_serpent_allies_flash = 1.0
	if _hiss_player and not _is_sfx_muted(): _hiss_player.play()
	# Create 2 snake allies that orbit and attack nearby enemies
	for i in range(2):
		var angle = TAU * float(i) / 2.0 + _time
		var pos = global_position + Vector2.from_angle(angle) * 40.0
		_active_serpents.append({
			"pos": pos,
			"angle": angle,
			"offset": float(i) * PI,
			"alive": true,
			"lifetime": 12.0,
			"attack_timer": 2.0
		})
	if is_instance_valid(_main_node):
		_main_node.spawn_floating_text(global_position + Vector2(0, -40), "SERPENT ALLIES!", Color(0.15, 0.5, 0.1), 12.0, 1.0)

func _update_serpent_allies(delta: float) -> void:
	var alive: Array = []
	for serpent in _active_serpents:
		if not serpent.get("alive", false):
			continue
		serpent.lifetime -= delta
		if serpent.lifetime <= 0.0:
			continue
		# Orbit around tower
		serpent.angle += delta * 1.5
		serpent.pos = global_position + Vector2.from_angle(serpent.angle) * 40.0
		# Attack nearby enemies
		serpent.attack_timer -= delta
		if serpent.attack_timer <= 0.0:
			serpent.attack_timer = 2.0
			var enemies = _main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")
			for e in enemies:
				if is_instance_valid(e) and e.has_method("take_damage"):
					if serpent.pos.distance_to(e.global_position) < 50.0:
						var dmg = damage * 0.5 * _damage_mult()
						e.take_damage(dmg, "magic")
						register_damage(dmg)
						if _venom_dot_active and e.has_method("apply_poison"):
							e.apply_poison(damage * 0.1 * _damage_mult(), _venom_dot_duration, _venom_max_stacks)
						break
		alive.append(serpent)
	_active_serpents = alive

func _trigger_athenas_curse() -> void:
	_athenas_curse_flash = 1.0
	var enemies = _main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")
	var in_range: Array = []
	var max_r = attack_range * _range_mult()
	for e in enemies:
		if is_instance_valid(e) and e.has_method("is_targetable") and e.is_targetable():
			if global_position.distance_to(e.global_position) < max_r:
				in_range.append(e)
	var count = mini(_athenas_curse_count, in_range.size())
	for i in range(count):
		var e = in_range[i]
		if e.has_method("apply_slow"):
			e.apply_slow(0.60, 5.0)
		if e.has_method("apply_vulnerability"):
			e.apply_vulnerability(0.30, 5.0)
		if is_instance_valid(_main_node):
			_main_node.spawn_floating_text(e.global_position + Vector2(0, -20), "CURSED!", Color(0.5, 0.15, 0.6), 12.0, 1.0)

# === UPGRADE SYSTEM ===

func apply_path_upgrade(path: String, tier: int) -> void:
	match path:
		"A":
			match tier:
				1:  # Gorgon's Wrath: +20% dmg + slow on attack
					damage *= 1.2
					_slow_on_attack = true
				2:  # Stone Gaze: petrify nearest every 12s
					_stone_gaze_active = true
					_stone_gaze_timer = _stone_gaze_cooldown
				3:  # Garden of Stone: kills become blocking statues + petrify 3
					_garden_of_stone_active = true
					_petrify_count = 3
		"B":
			match tier:
				1:  # Venom Fangs: poison DoT stacking
					_venom_dot_active = true
				2:  # Serpent Swarm: AoE snake strike every 18s
					_serpent_swarm_active = true
					_serpent_swarm_timer = _serpent_swarm_cooldown
				3:  # Blood of Gorgon: 2 permanent snake allies + venom stacks to 10
					_serpent_allies_active = true
					_serpent_allies_timer = _serpent_allies_cooldown
					_venom_max_stacks = 10
		"C":
			match tier:
				1:  # Serpent Scales: 25% less damage taken
					_damage_reduction = 0.25
				2:  # Athena's Curse: curse 3 enemies every 15s
					_athenas_curse_active = true
					_athenas_curse_timer = _athenas_curse_cooldown
				3:  # Perseus's Mirror: reflect damage back
					_mirror_reflect_active = true

func _apply_upgrade(tier: int) -> void:
	var tier_base_damage := [30.0, 38.0, 45.0, 55.0, 65.0]
	var tier_base_fire_rate := [1.0, 1.1, 1.2, 1.35, 1.5]
	var tier_base_range := [155.0, 160.0, 165.0, 175.0, 185.0]
	var tier_idx := tier - 1
	var dmg_bonus := maxf(damage - tier_base_damage[maxi(tier_idx - 1, 0)], 0.0) if tier_idx > 0 else 0.0
	var fr_bonus := maxf(fire_rate - tier_base_fire_rate[maxi(tier_idx - 1, 0)], 0.0) if tier_idx > 0 else 0.0
	var range_bonus := maxf(attack_range - tier_base_range[maxi(tier_idx - 1, 0)], 0.0) if tier_idx > 0 else 0.0
	match tier:
		1:  # Gorgon's Wrath
			damage = tier_base_damage[0] + dmg_bonus
			fire_rate = tier_base_fire_rate[0] + fr_bonus
			attack_range = tier_base_range[0] + range_bonus
			_slow_on_attack = true
		2:  # Venom Fangs
			damage = tier_base_damage[1] + dmg_bonus
			fire_rate = tier_base_fire_rate[1] + fr_bonus
			attack_range = tier_base_range[1] + range_bonus
			_venom_dot_active = true
		3:  # Stone Gaze
			damage = tier_base_damage[2] + dmg_bonus
			fire_rate = tier_base_fire_rate[2] + fr_bonus
			attack_range = tier_base_range[2] + range_bonus
			_stone_gaze_active = true
			gold_bonus = 2
		4:  # Serpent Swarm
			damage = tier_base_damage[3] + dmg_bonus
			fire_rate = tier_base_fire_rate[3] + fr_bonus
			attack_range = tier_base_range[3] + range_bonus
			_serpent_swarm_active = true
			gold_bonus = 2
		5:  # Garden of Stone
			_garden_of_stone_active = true
			_petrify_count = 3
			_serpent_allies_active = true
			gold_bonus = 3

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
	return "Medusa"

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

func register_damage(amount: float) -> void:
	damage_dealt += amount
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("register_tower_damage"):
		main.register_tower_damage(main.TowerType.MEDUSA, amount)
	_check_upgrades()

func register_kill() -> void:
	kill_count += 1
	# Garden of Stone: killed enemies become blocking stone statues
	if _garden_of_stone_active and is_instance_valid(_main_node) and _main_node.has_method("spawn_stone_statue"):
		if target and is_instance_valid(target):
			_main_node.spawn_stone_statue(target.global_position)

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
	damage += 1.0
	fire_rate += 0.01

# === SOUND GENERATION ===

func _generate_tier_sounds() -> void:
	var mix_rate := 44100
	# Serpentine melody: E3 F#3 G3 A3 B3 C4 D4 E4 — minor/phrygian snake-charmer feel
	var melody := [164.81, 185.0, 196.0, 220.0, 246.94, 261.63, 293.66, 329.63]
	_attack_sounds_by_tier = []
	for tier in range(5):
		var tier_sounds: Array = []
		var dur := 0.35 + tier * 0.04
		var vol := 0.20 + tier * 0.012
		var num_harmonics := 5 + tier
		for note_idx in melody.size():
			var freq: float = melody[note_idx]
			var total := int(mix_rate * dur)
			var samples := PackedFloat32Array()
			samples.resize(total)
			for i in total:
				var t := float(i) / float(mix_rate)
				# Plucked hiss attack: fast onset, hissy decay
				var env := minf(t * 25.0, 1.0) * exp(-t * 6.0)
				# Vibrato: snake sway
				var vib_depth := 3.0 * minf(t * 4.0, 1.0)
				var vib := sin(t * 5.5 * TAU) * vib_depth
				# Resonant metallic harmonics (serpentine)
				var s := 0.0
				for h in range(1, num_harmonics + 1):
					var amp := 1.0 / float(h)
					if h % 3 == 0:
						amp *= 1.3  # Emphasize every 3rd harmonic for exotic sound
					s += sin(t * (freq + vib) * float(h) * TAU) * amp
				s *= 0.10
				# Sibilant noise layer (snake hiss)
				var hiss_env := exp(-t * 8.0) * 0.04
				s += (randf() * 2.0 - 1.0) * hiss_env
				samples[i] = clampf(s * env * vol, -1.0, 1.0)
			# Gradual attack
			var att_len := mini(int(0.015 * mix_rate), total)
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
	if main and main.survivor_progress.has(main.TowerType.MEDUSA):
		var p = main.survivor_progress[main.TowerType.MEDUSA]
		var unlocked = p.get("abilities_unlocked", [])
		for i in range(mini(9, unlocked.size())):
			if unlocked[i]:
				activate_progressive_ability(i)

func get_progressive_ability_name(index: int) -> String:
	if index >= 0 and index < PROG_ABILITY_NAMES.size():
		return PROG_ABILITY_NAMES[index]
	return ""

func get_progressive_ability_desc(index: int) -> String:
	if index >= 0 and index < PROG_ABILITY_DESCS.size():
		return PROG_ABILITY_DESCS[index]
	return ""

func activate_progressive_ability(index: int) -> void:
	if index < 0 or index >= 9:
		return
	prog_abilities[index] = true
	_apply_progressive_stats()

func _apply_progressive_stats() -> void:
	# Ability 1: Gorgon's Wrath — +20% damage + slow (applied in _fire_venom_bolt)
	if prog_abilities[0]:
		_slow_on_attack = true
	# Ability 2: Serpent Scales — 25% less damage taken
	if prog_abilities[1]:
		_damage_reduction = 0.25
	# Ability 3: Venom Fangs — poison DoT
	if prog_abilities[2]:
		_venom_dot_active = true

func _process_progressive_abilities(delta: float) -> void:
	# Visual flash decay
	_prog_stone_gaze_flash = max(_prog_stone_gaze_flash - delta * 2.0, 0.0)
	_prog_athenas_curse_flash = max(_prog_athenas_curse_flash - delta * 2.0, 0.0)
	_prog_serpent_swarm_flash = max(_prog_serpent_swarm_flash - delta * 2.0, 0.0)
	_prog_perseus_bane_flash = max(_prog_perseus_bane_flash - delta * 2.0, 0.0)
	_prog_blood_gorgon_flash = max(_prog_blood_gorgon_flash - delta * 1.5, 0.0)
	_prog_garden_flash = max(_prog_garden_flash - delta * 1.5, 0.0)

	# Ability 4: Stone Gaze — petrify nearest every 12s
	if prog_abilities[3]:
		_prog_stone_gaze_timer -= delta
		if _prog_stone_gaze_timer <= 0.0 and _has_enemies_in_range():
			_prog_stone_gaze()
			_prog_stone_gaze_timer = 12.0

	# Ability 5: Athena's Curse — curse 3 enemies every 15s
	if prog_abilities[4]:
		_prog_athenas_curse_timer -= delta
		if _prog_athenas_curse_timer <= 0.0 and _has_enemies_in_range():
			_prog_athenas_curse()
			_prog_athenas_curse_timer = 15.0

	# Ability 6: Serpent Swarm — all snake hair strikes in range for 3x
	if prog_abilities[5]:
		_prog_serpent_swarm_timer -= delta
		if _prog_serpent_swarm_timer <= 0.0 and _has_enemies_in_range():
			_prog_serpent_swarm()
			_prog_serpent_swarm_timer = 18.0

	# Ability 7: Perseus's Bane — reflect damage every 20s
	if prog_abilities[6]:
		_prog_perseus_bane_timer -= delta
		if _prog_perseus_bane_timer <= 0.0 and _has_enemies_in_range():
			_prog_perseus_bane()
			_prog_perseus_bane_timer = 20.0

	# Ability 8: Blood of the Gorgon — spawn 2 snake allies every 15s
	if prog_abilities[7]:
		_prog_blood_gorgon_timer -= delta
		if _prog_blood_gorgon_timer <= 0.0:
			_prog_blood_gorgon()
			_prog_blood_gorgon_timer = 15.0

	# Ability 9: Garden of Stone — permanent aura (30% slow + 1%HP/s + stone statues)
	if prog_abilities[8]:
		var enemies = _main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")
		var max_r = attack_range * _range_mult()
		for e in enemies:
			if is_instance_valid(e) and global_position.distance_to(e.global_position) < max_r:
				if e.has_method("apply_slow"):
					e.apply_slow(0.30, 0.5)  # Reapply each frame effectively
				if e.has_method("take_damage"):
					var max_hp = e.max_health if "max_health" in e else 100.0
					e.take_damage(max_hp * 0.01 * delta, "magic")

func _prog_stone_gaze() -> void:
	_prog_stone_gaze_flash = 1.0
	if _petrify_player and not _is_sfx_muted(): _petrify_player.play()
	var enemies = _main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist := 999999.0
	var max_r = attack_range * _range_mult()
	for e in enemies:
		if is_instance_valid(e) and e.has_method("is_targetable") and e.is_targetable():
			var d = global_position.distance_to(e.global_position)
			if d < max_r and d < nearest_dist:
				nearest = e
				nearest_dist = d
	if nearest and nearest.has_method("apply_stun"):
		nearest.apply_stun(3.0)
		if is_instance_valid(_main_node):
			_main_node.spawn_floating_text(nearest.global_position + Vector2(0, -20), "PETRIFIED!", Color(0.5, 0.5, 0.4), 12.0, 1.0)

func _prog_athenas_curse() -> void:
	_prog_athenas_curse_flash = 1.0
	var enemies = _main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")
	var in_range: Array = []
	var max_r = attack_range * _range_mult()
	for e in enemies:
		if is_instance_valid(e) and e.has_method("is_targetable") and e.is_targetable():
			if global_position.distance_to(e.global_position) < max_r:
				in_range.append(e)
	var count = mini(3, in_range.size())
	for i in range(count):
		var e = in_range[i]
		if e.has_method("apply_slow"):
			e.apply_slow(0.60, 5.0)
		if e.has_method("apply_vulnerability"):
			e.apply_vulnerability(0.30, 5.0)
		if is_instance_valid(_main_node):
			_main_node.spawn_floating_text(e.global_position + Vector2(0, -20), "CURSED!", Color(0.5, 0.15, 0.6), 10.0, 0.8)

func _prog_serpent_swarm() -> void:
	_prog_serpent_swarm_flash = 1.0
	if _hiss_player and not _is_sfx_muted(): _hiss_player.play()
	var enemies = _main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")
	var max_r = attack_range * _range_mult()
	var dmg = damage * 3.0 * _damage_mult()
	for e in enemies:
		if is_instance_valid(e) and e.has_method("take_damage"):
			if global_position.distance_to(e.global_position) < max_r:
				e.take_damage(dmg, "magic")
				register_damage(dmg)

func _prog_perseus_bane() -> void:
	_prog_perseus_bane_flash = 1.0
	# Reflect: all enemies in range take 5x their own attack damage
	var enemies = _main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")
	var max_r = attack_range * _range_mult()
	for e in enemies:
		if is_instance_valid(e) and e.has_method("take_damage"):
			if global_position.distance_to(e.global_position) < max_r:
				var enemy_dmg = e.attack_damage if "attack_damage" in e else 10.0
				e.take_damage(enemy_dmg * 5.0, "magic")
				register_damage(enemy_dmg * 5.0)
	if is_instance_valid(_main_node):
		_main_node.spawn_floating_text(global_position + Vector2(0, -40), "REFLECT!", Color(0.8, 0.8, 0.9), 14.0, 1.2)

func _prog_blood_gorgon() -> void:
	_prog_blood_gorgon_flash = 1.0
	if _hiss_player and not _is_sfx_muted(): _hiss_player.play()
	for i in range(2):
		var angle = TAU * float(i) / 2.0 + _time
		var pos = global_position + Vector2.from_angle(angle) * 40.0
		_active_serpents.append({
			"pos": pos,
			"angle": angle,
			"offset": float(i) * PI,
			"alive": true,
			"lifetime": 12.0,
			"attack_timer": 2.0
		})

# === DAMAGE REDUCTION (Path C / Prog Ability 2) ===

func take_damage(amount: float) -> void:
	if _damage_reduction > 0.0:
		amount *= (1.0 - _damage_reduction)
	# Mirror reflect: attackers take damage back
	if _mirror_reflect_active:
		_mirror_reflect_flash = 1.0
		# Reflected damage handled in enemy attack logic

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

# === ACTIVE HERO ABILITY: Petrify Zone (AoE stun, 25s CD) ===
var active_ability_ready: bool = true
var active_ability_cooldown: float = 0.0
var active_ability_max_cd: float = 25.0

func activate_hero_ability() -> void:
	if not active_ability_ready:
		return
	if _petrify_player and not _is_sfx_muted(): _petrify_player.play()
	var enemies = _main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies")
	var max_r = attack_range * _range_mult()
	for e in enemies:
		if is_instance_valid(e) and e.has_method("apply_stun"):
			if global_position.distance_to(e.global_position) < max_r:
				e.apply_stun(4.0)
				var dmg = damage * 2.0 * _damage_mult()
				if e.has_method("take_damage"):
					e.take_damage(dmg, "magic")
				register_damage(dmg)
	active_ability_ready = false
	active_ability_cooldown = active_ability_max_cd
	if is_instance_valid(_main_node):
		_main_node.spawn_floating_text(global_position + Vector2(0, -40), "PETRIFY ZONE!", Color(0.5, 0.5, 0.4), 16.0, 1.5)

func get_active_ability_name() -> String:
	return "Petrify Zone"

func get_active_ability_desc() -> String:
	return "AoE stun + damage (25s CD)"

func _damage_mult() -> float:
	return (1.0 + _synergy_buffs.get("damage", 0.0) + _meta_buffs.get("damage", 0.0)) * power_damage_mult

func _range_mult() -> float:
	return 1.0 + _synergy_buffs.get("range", 0.0) + _meta_buffs.get("range", 0.0)

func _speed_mult() -> float:
	return 1.0 + _synergy_buffs.get("attack_speed", 0.0) + _meta_buffs.get("attack_speed", 0.0)

func _gold_mult() -> float:
	return 1.0 + _synergy_buffs.get("gold_bonus", 0.0) + _meta_buffs.get("gold_bonus", 0.0)
