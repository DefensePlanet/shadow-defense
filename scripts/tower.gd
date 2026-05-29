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

var bullet_scene = preload("res://scenes/bullet.tscn")
var _main_node: Node2D = null

func _ready() -> void:
	_main_node = get_tree().get_first_node_in_group("main")

func _process(delta: float) -> void:
	delta = minf(delta, 0.05)  # Cap at 50ms to prevent physics spikes
	fire_cooldown -= delta
	_recoil = max(_recoil - delta * 8.0, 0.0)
	_update_animation(delta)
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
