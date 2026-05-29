extends Node2D
## Pistol Tower — auto-targets nearest enemy in range and fires bullets.

var damage: float = 30.0
var fire_rate: float = 2.34   # shots per second
var attack_range: float = 150.0
var fire_cooldown: float = 0.0
var gun_angle: float = 0.0
var target: Node2D = null
# Targeting priority: 0=First, 1=Last, 2=Close, 3=Strong
var targeting_priority: int = 0
var _recoil: float = 0.0
var sprite_texture: Texture2D = null  # AI character sprite, set by main.gd
var is_selected: bool = false  # Show range circle when selected
var damage_type: String = "physical"  # physical, magic, fire, ice, dark, holy

# Gear visual system — Diablo/Apex-style visible equipment
# Gear SLOTS (jewelry/accessories that show on character)
var gear_crown: Dictionary = {}      # Crown/helm — drawn on head
var gear_amulet: Dictionary = {}     # Amulet/necklace — glow around neck
var gear_bracelet: Dictionary = {}   # Bracelet/gauntlet — drawn on arm
var gear_weapon: Dictionary = {}     # Weapon — replaces default weapon visual
var gear_ring: Dictionary = {}       # Ring — particle effect on attacks
# Skin system — full outfit changes (Apex Legends style)
var skin_id: String = "default"
var skin_color_override: Color = Color.WHITE  # Tint applied to base outfit

# === ANIMATION STATE MACHINE — makes characters feel ALIVE ===
# States: "idle", "attack_windup", "attack_release", "attack_cooldown",
#         "ability_cast", "celebrate", "hurt", "placed"
var anim_state: String = "idle"
var anim_timer: float = 0.0
var anim_frame: int = 0
# Body part offsets — modified by animations for limb movement
var body_offset: Vector2 = Vector2.ZERO  # Whole body shift
var arm_right_angle: float = 0.0  # Right arm rotation (weapon hand)
var arm_left_angle: float = 0.0   # Left arm rotation (shield/off-hand)
var head_tilt: float = 0.0        # Head rotation
var body_lean: float = 0.0        # Torso lean (left/right)
var leg_phase: float = 0.0        # Walk/idle leg animation phase
var weapon_swing_angle: float = 0.0  # Weapon rotation during attack
var weapon_trail_alpha: float = 0.0  # Trail effect behind weapon
var _idle_timer: float = 0.0      # Fidget/boredom timer
var _idle_variant: int = 0        # Which idle animation to play
var _celebrate_timer: float = 0.0 # Victory dance timer
var _kill_flash: float = 0.0      # Flash on kill
var _attack_count: int = 0        # Attacks since last idle variant change
# Weapon visual state
var weapon_visible: bool = true
var weapon_glow_color: Color = Color(1, 1, 1, 0)  # Upgrade glow
var weapon_scale: float = 1.0     # Bigger with upgrades

func _update_animation(delta: float) -> void:
	anim_timer += delta
	_idle_timer += delta
	_kill_flash = maxf(_kill_flash - delta * 3.0, 0.0)
	_celebrate_timer = maxf(_celebrate_timer - delta, 0.0)
	# Leg idle sway
	leg_phase += delta * 2.0
	match anim_state:
		"idle":
			# Gentle breathing + occasional fidgets
			body_offset.y = sin(anim_timer * 1.8) * 1.5
			head_tilt = sin(anim_timer * 0.7) * 0.03
			arm_right_angle = sin(anim_timer * 1.2) * 0.05
			arm_left_angle = sin(anim_timer * 1.0 + 0.5) * 0.04
			body_lean = sin(anim_timer * 0.5) * 0.02
			weapon_swing_angle = sin(anim_timer * 0.8) * 0.08
			weapon_trail_alpha = 0.0
			# Boredom fidgets every 5-10 seconds
			if _idle_timer > 5.0 + randf() * 5.0:
				_idle_timer = 0.0
				_idle_variant = (_idle_variant + 1) % 4
			match _idle_variant:
				1:  # Look around
					head_tilt += sin(anim_timer * 2.0) * 0.08
				2:  # Shift weight
					body_lean += sin(anim_timer * 1.5) * 0.05
				3:  # Weapon fidget
					weapon_swing_angle += sin(anim_timer * 3.0) * 0.15
		"attack_windup":
			# Pull back weapon/arm
			var windup_progress = minf(anim_timer / 0.15, 1.0)
			arm_right_angle = -0.8 * windup_progress  # Pull back
			body_lean = -0.1 * windup_progress  # Lean back
			weapon_swing_angle = -1.2 * windup_progress  # Weapon winds back
			head_tilt = 0.05 * windup_progress  # Eyes on target
			if windup_progress >= 1.0:
				anim_state = "attack_release"
				anim_timer = 0.0
		"attack_release":
			# Swing forward — the satisfying part
			var release_progress = minf(anim_timer / 0.12, 1.0)
			arm_right_angle = -0.8 + 1.8 * release_progress  # Swing through
			body_lean = -0.1 + 0.25 * release_progress  # Lean forward
			weapon_swing_angle = -1.2 + 3.0 * release_progress  # Full swing arc
			weapon_trail_alpha = 0.5 * (1.0 - release_progress)  # Trail fades
			head_tilt = 0.05 - 0.1 * release_progress  # Follow through
			body_offset.x = 3.0 * sin(release_progress * PI)  # Lunge forward
			if release_progress >= 1.0:
				anim_state = "attack_cooldown"
				anim_timer = 0.0
				_attack_count += 1
				if _attack_count > 8:
					_attack_count = 0
					_idle_variant = randi() % 4
		"attack_cooldown":
			# Return to idle smoothly
			var cooldown_progress = minf(anim_timer / 0.2, 1.0)
			arm_right_angle = 1.0 * (1.0 - cooldown_progress)
			body_lean = 0.15 * (1.0 - cooldown_progress)
			weapon_swing_angle = 1.8 * (1.0 - cooldown_progress)
			body_offset.x = 0.0
			weapon_trail_alpha = 0.0
			if cooldown_progress >= 1.0:
				anim_state = "idle"
				anim_timer = 0.0
		"ability_cast":
			# Both arms up, body lifts, glow intensifies
			var cast_progress = minf(anim_timer / 0.4, 1.0)
			arm_right_angle = -1.5 * cast_progress  # Arms up
			arm_left_angle = -1.5 * cast_progress
			body_offset.y = -5.0 * cast_progress  # Rise up
			weapon_glow_color.a = cast_progress * 0.6  # Glow
			if cast_progress >= 1.0:
				anim_state = "idle"
				anim_timer = 0.0
				weapon_glow_color.a = 0.0
		"celebrate":
			# Victory dance — bounce + arms pump
			var bounce = abs(sin(anim_timer * 6.0)) * 4.0
			body_offset.y = -bounce
			arm_right_angle = sin(anim_timer * 4.0) * 0.8
			arm_left_angle = -sin(anim_timer * 4.0) * 0.8
			head_tilt = sin(anim_timer * 5.0) * 0.1
			body_lean = sin(anim_timer * 3.0) * 0.08
			if _celebrate_timer <= 0:
				anim_state = "idle"
				anim_timer = 0.0
		"placed":
			# Landing animation when first placed
			var place_progress = minf(anim_timer / 0.3, 1.0)
			body_offset.y = -20.0 * (1.0 - place_progress)  # Drop in from above
			var squash = 1.0 + sin(place_progress * PI) * 0.15  # Squash on land
			scale = Vector2(1.0 / squash, squash) if place_progress < 0.8 else Vector2(1, 1)
			if place_progress >= 1.0:
				anim_state = "idle"
				anim_timer = 0.0
				scale = Vector2(1, 1)

# === CHARACTER-SPECIFIC IDLE BEHAVIORS ===
# Each character has unique fidgets that play during idle state.
# These replace the generic idle variants with personality.
var idle_personality: String = "default"  # Set by character script
var _personality_timer: float = 0.0
var _personality_phase: int = 0

const IDLE_PERSONALITIES: Dictionary = {
	"archer": {  # Robin Hood, Clayton
		"fidgets": ["aim_practice", "flex_bow", "scan_horizon", "adjust_quiver"],
		"interval": 4.0,
	},
	"curious": {  # Alice
		"fidgets": ["look_around", "tilt_head", "count_fingers", "tap_foot"],
		"interval": 3.5,
	},
	"menacing": {  # Wicked Witch, Dracula, Medusa, Headless Horseman
		"fidgets": ["clench_fist", "evil_grin", "dark_pulse", "brood"],
		"interval": 5.0,
	},
	"playful": {  # Peter Pan, Loki
		"fidgets": ["hop_in_place", "spin_weapon", "wave", "cartwheel_fake"],
		"interval": 3.0,
	},
	"musical": {  # Phantom
		"fidgets": ["conduct", "hum_sway", "finger_piano", "bow_practice"],
		"interval": 4.5,
	},
	"grumpy": {  # Scrooge, Captain Ahab
		"fidgets": ["tap_cane", "mutter", "check_pocket_watch", "scowl"],
		"interval": 5.0,
	},
	"detective": {  # Sherlock
		"fidgets": ["examine_ground", "stroke_chin", "pipe_puff", "magnify"],
		"interval": 4.0,
	},
	"wild": {  # Tarzan
		"fidgets": ["beat_chest", "sniff_air", "scratch", "vine_reach"],
		"interval": 3.5,
	},
	"gentle_giant": {  # Frankenstein
		"fidgets": ["look_at_hands", "confused_tilt", "stomp_ground", "reach_for_butterfly"],
		"interval": 5.0,
	},
	"mystic": {  # Merlin, Anubis
		"fidgets": ["float_orb", "meditate", "gesture_runes", "crystal_gaze"],
		"interval": 4.5,
	},
	"writer": {  # Shadow Author
		"fidgets": ["scribble_air", "read_invisible_page", "ink_drip", "quill_twirl"],
		"interval": 4.0,
	},
	"royal": {  # Queen of Hearts, Captain Hook
		"fidgets": ["adjust_crown", "inspect_nails", "imperial_wave", "snap_fingers"],
		"interval": 4.5,
	},
}

func _update_idle_personality(delta: float) -> void:
	if anim_state != "idle":
		_personality_timer = 0.0
		return
	var personality = IDLE_PERSONALITIES.get(idle_personality, IDLE_PERSONALITIES.get("default", {}))
	var interval = personality.get("interval", 4.0)
	_personality_timer += delta
	if _personality_timer >= interval:
		_personality_timer = 0.0
		var fidgets = personality.get("fidgets", [])
		if fidgets.size() > 0:
			_personality_phase = randi() % fidgets.size()
			_apply_personality_fidget(fidgets[_personality_phase])

func _apply_personality_fidget(fidget_name: String) -> void:
	# Apply body part adjustments for the fidget animation
	match fidget_name:
		"aim_practice":
			arm_right_angle = -0.6  # Pull back bow
			head_tilt = -0.05  # Aim carefully
		"flex_bow":
			arm_right_angle = 0.4; arm_left_angle = -0.3  # Stretch
		"scan_horizon":
			head_tilt = 0.15  # Look far right
		"look_around":
			head_tilt = sin(_personality_timer * 3.0) * 0.12
		"tilt_head":
			head_tilt = 0.15; body_lean = 0.05
		"tap_foot":
			leg_phase += 2.0  # Fast leg movement
		"clench_fist":
			arm_right_angle = -0.3  # Tighten fist
		"evil_grin":
			head_tilt = -0.05  # Chin down, menacing
		"dark_pulse":
			weapon_glow_color.a = 0.3  # Brief glow
		"brood":
			body_lean = -0.04; head_tilt = 0.08  # Look away, brooding
		"hop_in_place":
			body_offset.y = -8.0  # Quick hop
		"spin_weapon":
			weapon_swing_angle += TAU * 0.5  # Half spin
		"conduct":
			arm_right_angle = -0.8; arm_left_angle = -0.6  # Conductor pose
		"hum_sway":
			body_lean = sin(_personality_timer * 2.0) * 0.06
		"tap_cane":
			arm_right_angle = 0.1  # Tap motion
		"check_pocket_watch":
			arm_left_angle = -0.5; head_tilt = -0.1  # Look at wrist
		"examine_ground":
			head_tilt = 0.2; body_lean = 0.06  # Look down
		"stroke_chin":
			arm_right_angle = -0.3  # Hand to chin
		"beat_chest":
			arm_right_angle = 0.5; arm_left_angle = 0.5  # Wide arms
			body_offset.y = -3.0  # Slight rise
		"sniff_air":
			head_tilt = -0.15  # Head up, sniffing
		"look_at_hands":
			arm_right_angle = -0.4; arm_left_angle = -0.4
			head_tilt = 0.15  # Looking down at hands
		"confused_tilt":
			head_tilt = 0.2; body_lean = 0.04
		"reach_for_butterfly":
			arm_right_angle = -0.7  # Reaching up gently
			head_tilt = -0.1  # Looking up
		"float_orb":
			arm_right_angle = -0.5
			weapon_glow_color.a = 0.4  # Magic glow
		"meditate":
			body_offset.y = -3.0  # Slight float
			arm_right_angle = -0.3; arm_left_angle = -0.3  # Palms up
		"scribble_air":
			arm_right_angle = -0.2
			weapon_swing_angle = sin(_personality_timer * 5.0) * 0.3  # Writing motion
		"adjust_crown":
			arm_right_angle = -0.6  # Hand to head
			head_tilt = 0.05  # Regal posture
		"imperial_wave":
			arm_right_angle = -0.4  # Royal wave
		_:
			pass  # Unknown fidget — do nothing

func trigger_attack_anim() -> void:
	anim_state = "attack_windup"
	anim_timer = 0.0
	_idle_timer = 0.0

func trigger_ability_anim() -> void:
	anim_state = "ability_cast"
	anim_timer = 0.0

func trigger_celebrate(duration: float = 2.0) -> void:
	anim_state = "celebrate"
	anim_timer = 0.0
	_celebrate_timer = duration

func trigger_kill_flash() -> void:
	_kill_flash = 1.0

func trigger_placed_anim() -> void:
	anim_state = "placed"
	anim_timer = 0.0

# === WEAPON & GEAR COMPATIBILITY — BATTD-style character-specific equipment ===
# Each character has a weapon_class that determines which weapons they can equip.
# Gear slots are universal but some gear has character restrictions.
var weapon_class: String = "melee"  # "bow", "melee", "magic", "ranged", "instrument", "special"
# Weapon classes determine compatible weapon types:
# bow: Robin Hood, Clayton, Headless Horseman
# melee: Peter Pan, Tarzan, Captain Hook, Frankenstein, Captain Ahab
# magic: Wicked Witch, Merlin, Medusa, Anubis, Loki, Shadow Author
# ranged: Alice, Sherlock, Scrooge, Queen of Hearts
# special: Phantom (music), Captain Nemo (tech) — unique weapon pool

const WEAPON_CLASS_COMPATIBLE: Dictionary = {
	"bow": ["longbow", "crossbow", "enchanted_bow", "golden_bow", "shadow_bow", "vorpal_bow"],
	"melee": ["sword", "dagger", "axe", "hammer", "harpoon", "cutlass", "claws", "fists"],
	"magic": ["wand", "staff", "orb", "tome", "crystal", "quill", "ankh", "rune_stone"],
	"ranged": ["pistol", "cards", "coins", "teacup", "scepter", "bells"],
	"instrument": ["organ", "violin", "flute", "harp", "drums"],
	"special": ["submarine", "lightning_rod", "pumpkin", "snake_hair", "chaos_dice"],
}

func can_equip_weapon(weapon_type: String) -> bool:
	if weapon_class == "": return true  # No restriction
	var compatible = WEAPON_CLASS_COMPATIBLE.get(weapon_class, [])
	return weapon_type in compatible or weapon_type == "universal"

# Visual gear display — what the player SEES on the character
var equipped_weapon_visual: Dictionary = {}  # {name, type, color, glow, tier}
var equipped_gear_visuals: Array = []  # [{slot, name, color, effect}]

# === SIDEKICK VISUAL SYSTEM — companion figures orbiting the tower ===
var active_sidekicks: Array = []  # [{name, desc, orbit_angle, orbit_speed, color, attack_timer}]

func setup_sidekicks(sidekick_data: Array, unlocked: Array) -> void:
	active_sidekicks.clear()
	for i in range(sidekick_data.size()):
		if i < unlocked.size() and unlocked[i]:
			var sk = sidekick_data[i]
			active_sidekicks.append({
				"name": sk["name"],
				"desc": sk["desc"],
				"orbit_angle": float(i) * TAU / 3.0,
				"orbit_speed": 1.0 + float(i) * 0.3,
				"orbit_radius": 35.0 + float(i) * 5.0,
				"color": [Color(0.3, 0.7, 0.9), Color(0.9, 0.7, 0.3), Color(0.7, 0.3, 0.9)][i % 3],
				"attack_timer": 0.0,
				"attack_flash": 0.0,
			})

func _update_sidekicks(delta: float) -> void:
	for sk in active_sidekicks:
		sk["orbit_angle"] += sk["orbit_speed"] * delta
		sk["attack_timer"] += delta
		sk["attack_flash"] = maxf(sk["attack_flash"] - delta * 3.0, 0.0)
		# Sidekick attacks every 3 seconds if enemies nearby
		if sk["attack_timer"] >= 3.0 and target != null:
			sk["attack_timer"] = 0.0
			sk["attack_flash"] = 1.0
			# Sidekick does 15% of tower damage
			if target.has_method("take_damage"):
				target.take_damage(damage * 0.15, damage_type)

func _draw_sidekicks() -> void:
	var time = 0.0
	if "_time" in self: time = _time
	for sk in active_sidekicks:
		var angle = sk["orbit_angle"]
		var r = sk["orbit_radius"]
		var sx = cos(angle) * r
		var sy = sin(angle) * r * 0.5  # Flattened ellipse for perspective
		var pos = Vector2(sx, sy - 5)  # Slight upward offset
		var col = sk["color"]
		var flash = sk["attack_flash"]
		# Body — small circle
		draw_circle(pos, 5.0, Color(col.r, col.g, col.b, 0.6 + flash * 0.3))
		# Head — smaller circle above
		draw_circle(pos + Vector2(0, -6), 3.0, Color(col.r * 1.2, col.g * 1.2, col.b * 1.2, 0.7 + flash * 0.3))
		# Attack flash — bright ring
		if flash > 0.0:
			draw_arc(pos, 8.0, 0, TAU, 8, Color(1, 1, 1, flash * 0.5), 1.5)
		# Bobbing motion
		var bob = sin(time * 2.0 + angle) * 2.0
		# Name label on hover (would need hover detection — skip for now)
		# Tiny shadow underneath
		draw_circle(Vector2(sx, sy + 3), 3.0, Color(0, 0, 0, 0.1))

func get_visible_equipment_summary() -> String:
	var parts = []
	if equipped_weapon_visual.has("name"):
		parts.append("⚔ %s" % equipped_weapon_visual["name"])
	for g in equipped_gear_visuals:
		parts.append("%s %s" % [g.get("slot", "?"), g.get("name", "?")])
	if parts.size() == 0: return "No equipment"
	return " | ".join(parts)

# === CHARACTER EVOLUTION — visual changes at level milestones ===
# Characters visually evolve at levels 5, 10, 15, 20 with:
# new aura effects, size growth, glow intensity, visual complexity
var evolution_tier: int = 0  # 0=base, 1=lv5, 2=lv10, 3=lv15, 4=lv20 (Awakened)
var evolution_aura_color: Color = Color(1, 1, 1, 0)
var evolution_aura_radius: float = 0.0
var evolution_scale_bonus: float = 0.0  # Added to base scale
var evolution_glow_intensity: float = 0.0
var evolution_particle_count: int = 0
var _evolution_particles: Array = []

const EVOLUTION_TIERS: Array = [
	{"level": 1, "name": "Novice", "aura": Color(0, 0, 0, 0), "aura_radius": 0, "scale": 0.0, "glow": 0.0, "particles": 0},
	{"level": 5, "name": "Adept", "aura": Color(0.3, 0.6, 0.9, 0.08), "aura_radius": 30, "scale": 0.05, "glow": 0.1, "particles": 3},
	{"level": 10, "name": "Expert", "aura": Color(0.6, 0.3, 0.9, 0.12), "aura_radius": 35, "scale": 0.08, "glow": 0.2, "particles": 5},
	{"level": 15, "name": "Master", "aura": Color(0.9, 0.7, 0.1, 0.15), "aura_radius": 40, "scale": 0.10, "glow": 0.3, "particles": 8},
	{"level": 20, "name": "AWAKENED", "aura": Color(1.0, 0.85, 0.2, 0.20), "aura_radius": 50, "scale": 0.12, "glow": 0.5, "particles": 12},
]

func update_evolution(char_level: int) -> void:
	evolution_tier = 0
	for i in range(EVOLUTION_TIERS.size() - 1, -1, -1):
		if char_level >= EVOLUTION_TIERS[i]["level"]:
			evolution_tier = i
			break
	var tier = EVOLUTION_TIERS[evolution_tier]
	evolution_aura_color = tier["aura"]
	evolution_aura_radius = tier["aura_radius"]
	evolution_scale_bonus = tier["scale"]
	evolution_glow_intensity = tier["glow"]
	evolution_particle_count = tier["particles"]
	# Generate evolution particles
	_evolution_particles.clear()
	for _i in range(evolution_particle_count):
		_evolution_particles.append({
			"angle": randf() * TAU,
			"speed": randf_range(0.5, 1.5),
			"dist": randf_range(15, 35),
			"size": randf_range(1.0, 2.5),
		})

func _draw_evolution_effects() -> void:
	if evolution_tier <= 0: return
	var time = _time if "_time" in self else 0.0
	# Aura ring
	if evolution_aura_radius > 0:
		var pulse = sin(time * 2.0) * 0.3 + 0.7
		for gi in range(3):
			var gr = evolution_aura_radius + float(gi) * 5.0
			draw_circle(Vector2.ZERO, gr, Color(evolution_aura_color.r, evolution_aura_color.g, evolution_aura_color.b, evolution_aura_color.a * pulse * (1.0 - float(gi) * 0.25)))
	# Orbiting particles
	for p in _evolution_particles:
		p["angle"] += p["speed"] * 0.02
		var px = cos(p["angle"]) * p["dist"]
		var py = sin(p["angle"]) * p["dist"] * 0.5  # Flattened orbit
		var pa = evolution_glow_intensity * 0.5
		draw_circle(Vector2(px, py), p["size"], Color(evolution_aura_color.r, evolution_aura_color.g, evolution_aura_color.b, pa))
	# Level tier badge below character
	if evolution_tier >= 2:
		var tier_name = EVOLUTION_TIERS[evolution_tier]["name"]
		var badge_col = evolution_aura_color
		badge_col.a = 0.6
		# Small text badge
		if has_method("_udraw"):
			pass  # Would need font ref — skip for now
	# Awakened special effect (level 20) — golden halo
	if evolution_tier >= 4:
		var halo_pulse = (sin(time * 1.5) + 1.0) * 0.5
		draw_arc(Vector2(0, -25), 18.0 + halo_pulse * 3.0, 0, TAU, 20, Color(1.0, 0.85, 0.2, 0.15 + halo_pulse * 0.1), 2.0)
		# Crown-like spikes
		for si in range(5):
			var sa = float(si) / 5.0 * PI + PI
			var spike_h = 6.0 + halo_pulse * 2.0
			draw_line(Vector2(cos(sa) * 16, -25 + sin(sa) * 8), Vector2(cos(sa) * 16, -25 + sin(sa) * 8 - spike_h), Color(1.0, 0.85, 0.2, 0.2), 1.5)

var bullet_scene = preload("res://scenes/bullet.tscn")
var _main_node: Node2D = null

func _ready() -> void:
	_main_node = get_tree().get_first_node_in_group("main")

func _process(delta: float) -> void:
	delta = minf(delta, 0.05)  # Cap at 50ms to prevent physics spikes
	fire_cooldown -= delta
	_recoil = max(_recoil - delta * 8.0, 0.0)
	_update_animation(delta)
	_update_idle_personality(delta)
	_update_sidekicks(delta)
	target = _find_nearest_enemy()

	if target:
		var desired = global_position.angle_to_point(target.global_position) + PI
		gun_angle = lerp_angle(gun_angle, desired, 12.0 * delta)
		if fire_cooldown <= 0.0:
			_shoot()
			fire_cooldown = 1.0 / fire_rate
			_recoil = 1.0
			trigger_attack_anim()

	queue_redraw()

func _find_nearest_enemy() -> Node2D:
	var enemies = (_main_node.get_cached_enemies() if is_instance_valid(_main_node) else get_tree().get_nodes_in_group("enemies"))
	var best: Node2D = null
	var max_range: float = attack_range
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

func _shoot() -> void:
	if not target:
		return
	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position + Vector2.from_angle(gun_angle) * 20.0
	bullet.damage = damage * randf_range(0.85, 1.15)  # ±15% damage variance
	bullet.target = target
	var _main = get_tree().get_first_node_in_group("main")
	if _main:
		_main.add_child(bullet)
	else:
		bullet.queue_free()

func _draw() -> void:
	# AI sprite rendering — use the character sprite if assigned by main.gd
	if sprite_texture != null:
		var tex_size = sprite_texture.get_size()
		var fit = 48.0  # Tower visual diameter
		var scl = fit / maxf(tex_size.x, tex_size.y)
		var w = tex_size.x * scl
		var h = tex_size.y * scl
		# Subtle base shadow
		draw_circle(Vector2(0, 4), 22.0, Color(0.0, 0.0, 0.0, 0.25))
		# Draw character sprite
		draw_texture_rect(sprite_texture, Rect2(-w * 0.5, -h * 0.5, w, h), false)
		# Muzzle flash (on recoil) — small directional indicator
		if _recoil > 0.5:
			var dir = Vector2.from_angle(gun_angle)
			draw_circle(dir * 28.0, 4.0, Color(1.0, 0.9, 0.3, _recoil * 0.6))
		# Evolution effects (aura, particles, halo)
		_draw_evolution_effects()
		# Sidekick companions orbiting
		_draw_sidekicks()
		return

	# Procedural fallback — gray circles + pistol
	# Base platform
	draw_circle(Vector2.ZERO, 24.0, Color(0.3, 0.3, 0.3))
	draw_circle(Vector2.ZERO, 20.0, Color(0.52, 0.52, 0.52))
	draw_circle(Vector2.ZERO, 16.0, Color(0.44, 0.44, 0.44))

	# Gun direction
	var dir = Vector2.from_angle(gun_angle)
	var perp = dir.rotated(PI / 2.0)
	var recoil_offset = dir * (-3.0 * _recoil)

	# Pistol grip (brown)
	var grip_base = recoil_offset + dir * 2.0
	draw_line(grip_base, grip_base - perp * 12.0, Color(0.45, 0.28, 0.12), 6.0)

	# Slide / body
	var slide_start = recoil_offset + dir * 2.0
	var slide_end = recoil_offset + dir * 22.0
	draw_line(slide_start, slide_end, Color(0.22, 0.22, 0.22), 7.0)

	# Barrel
	var barrel_end = recoil_offset + dir * 28.0
	draw_line(slide_end, barrel_end, Color(0.16, 0.16, 0.16), 4.5)

	# Muzzle flash (on recoil)
	if _recoil > 0.5:
		draw_circle(barrel_end + dir * 4.0, 5.0, Color(1.0, 0.9, 0.3, _recoil * 0.8))

func _draw_selection() -> void:
	# Range circle when selected
	if is_selected:
		# Range circle
		draw_arc(Vector2.ZERO, attack_range, 0, TAU, 64, Color(0.3, 0.8, 0.4, 0.25), 2.0)
		# Filled range area (very subtle)
		for r in range(int(attack_range), 0, -4):
			draw_arc(Vector2.ZERO, float(r), 0, TAU, 48, Color(0.3, 0.8, 0.4, 0.008), 4.0)
		# Selection ring around tower
		draw_arc(Vector2.ZERO, 26.0, 0, TAU, 32, Color(1.0, 0.9, 0.3, 0.7), 2.5)
		# Targeting mode label above tower
		var tgt_label = get_targeting_label()
		var font = ThemeDB.fallback_font
		if font:
			var tgt_color = Color(0.3, 0.9, 0.4) if targeting_priority == 0 else Color(0.9, 0.7, 0.2) if targeting_priority == 3 else Color(0.5, 0.7, 0.9)
			draw_string(font, Vector2(-20, -32), tgt_label, HORIZONTAL_ALIGNMENT_CENTER, 40, 9, tgt_color)
