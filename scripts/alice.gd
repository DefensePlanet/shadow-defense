extends Node2D
## Alice — debuff/support tower. Throws playing cards that shrink and slow enemies.
## Based on Lewis Carroll's Alice's Adventures in Wonderland (1865) & Tenniel illustrations.
## Tier 1 (5000 DMG): "Drink Me" — stronger slow (40%), faster fire rate
## Tier 2 (10000 DMG): "Cheshire Cat" — periodically stuns a random enemy
## Tier 3 (15000 DMG): "Mad Tea Party" — teacup volley AoE every 15s
## Tier 4 (20000 DMG): "Off With Their Heads!" — instant kill enemies below 15% HP

var damage: float = 25.0
var fire_rate: float = 3.0
var attack_range: float = 160.0
var fire_cooldown: float = 0.0
var aim_angle: float = 0.0
var target: Node2D = null
var gold_bonus: int = 3

# Damage tracking and upgrades
var damage_dealt: float = 0.0
var upgrade_tier: int = 0
var _upgrade_flash: float = 0.0
var _upgrade_name: String = ""

# Slow debuff
var slow_amount: float = 0.7
var slow_duration: float = 1.5

# Tier 2: Cheshire Cat
var cheshire_timer: float = 0.0
var cheshire_cooldown: float = 12.0
var _cheshire_flash: float = 0.0

# Tier 3: Mad Tea Party
var tea_timer: float = 0.0
var tea_cooldown: float = 15.0
var _tea_flash: float = 0.0

# Tier 4: Off With Their Heads
var execute_threshold: float = 0.0

# Animation vars
var _time: float = 0.0
var _attack_anim: float = 0.0

# Grow ability — Alice grows as she levels up
var _grow_scale: float = 1.0
var _grow_burst: float = 0.0  # Temporary extra scale on level-up

# === PROGRESSIVE ABILITIES (9 tiers, unlocked via lifetime damage) ===
const PROG_ABILITY_NAMES = [
	"Curiouser and Curiouser", "Down the Rabbit Hole", "Cheshire Grin",
	"Eat Me Cake", "Painting the Roses Red", "The Caterpillar's Hookah",
	"Tweedledee & Tweedledum", "The Jabberwock", "Wonderland Madness"
]
const PROG_ABILITY_DESCS = [
	"+20% card damage, cards spin faster",
	"Every 20s, teleport enemy back 150 path units",
	"Every 10s, mark enemy for 2x damage for 5s",
	"Every 15s, Alice stomps for 4x AoE damage",
	"Each hit paints enemy, +5% damage per stack (max 10)",
	"Every 20s, smoke cloud slows enemies to 20% for 3s",
	"2 fighters patrol near Alice attacking every 2s",
	"Every 25s, Jabberwock swoops dealing 5x to all in path",
	"Cards split mid-flight (1 becomes 3)"
]
var prog_abilities: Array = [false, false, false, false, false, false, false, false, false]
var _rabbit_hole_timer: float = 20.0
var _cheshire_grin_timer: float = 10.0
var _eat_me_timer: float = 15.0
var _caterpillar_timer: float = 20.0
var _tweedle_timer: float = 2.0
var _jabberwock_timer: float = 25.0
var _eat_me_flash: float = 0.0
var _jabberwock_flash: float = 0.0
var _caterpillar_flash: float = 0.0

const STAT_UPGRADE_INTERVAL: float = 500.0
const ABILITY_THRESHOLD: float = 1500.0
var stat_upgrade_level: int = 0
var ability_chosen: bool = false
var awaiting_ability_choice: bool = false
const TIER_NAMES = [
	"Drink Me",
	"Cheshire Cat",
	"Mad Tea Party",
	"Off With Their Heads!"
]
const ABILITY_DESCRIPTIONS = [
	"Stronger slow (40%), faster attacks",
	"Periodically stuns a random enemy",
	"Teacup volley AoE every 15s",
	"Instant kill enemies below 15% HP"
]
const TIER_COSTS = [50, 100, 180, 320]
var is_selected: bool = false
var base_cost: int = 0

var card_scene = preload("res://scenes/card.tscn")

# Attack sound
var _attack_sound: AudioStreamWAV
var _attack_player: AudioStreamPlayer

# Ability sounds
var _cheshire_sound: AudioStreamWAV
var _cheshire_player: AudioStreamPlayer
var _tea_sound: AudioStreamWAV
var _tea_player: AudioStreamPlayer
var _upgrade_sound: AudioStreamWAV
var _upgrade_player: AudioStreamPlayer

func _ready() -> void:
	add_to_group("towers")
	_load_progressive_abilities()
	# Generate magical card flick sound
	var mix_rate := 22050
	var duration := 0.1
	var samples := PackedFloat32Array()
	samples.resize(int(mix_rate * duration))
	for i in samples.size():
		var t := float(i) / mix_rate
		# Quick ascending shimmer tones
		var freq := lerpf(1200.0, 1800.0, t / duration)
		var shimmer := sin(t * freq * TAU) * exp(-t * 20.0) * 0.5
		# Second harmonic sparkle
		var sparkle := sin(t * freq * 2.0 * TAU) * exp(-t * 25.0) * 0.3
		# Brief noise burst for the flick texture
		var flick := (randf() * 2.0 - 1.0) * exp(-t * 40.0) * 0.4
		samples[i] = clampf(shimmer + sparkle + flick, -1.0, 1.0)
	_attack_sound = _samples_to_wav(samples, mix_rate)
	_attack_player = AudioStreamPlayer.new()
	_attack_player.stream = _attack_sound
	_attack_player.volume_db = -8.0
	add_child(_attack_player)

	# Cheshire stun — eerie sliding giggle with pitch wobble
	var ch_rate := 22050
	var ch_dur := 0.4
	var ch_samples := PackedFloat32Array()
	ch_samples.resize(int(ch_rate * ch_dur))
	for i in ch_samples.size():
		var t := float(i) / ch_rate
		var freq := 600.0 + sin(TAU * 8.0 * t) * 200.0 + t * 300.0
		var am := 0.5 + 0.5 * sin(TAU * 12.0 * t)
		var env := (1.0 - t / ch_dur) * 0.4
		ch_samples[i] = clampf(sin(TAU * freq * t) * am * env, -1.0, 1.0)
	_cheshire_sound = _samples_to_wav(ch_samples, ch_rate)
	_cheshire_player = AudioStreamPlayer.new()
	_cheshire_player.stream = _cheshire_sound
	_cheshire_player.volume_db = -6.0
	add_child(_cheshire_player)

	# Tea party — 3 ceramic clinks + pouring
	var tea_rate := 22050
	var tea_dur := 0.5
	var tea_samples := PackedFloat32Array()
	tea_samples.resize(int(tea_rate * tea_dur))
	var clink_times := [0.0, 0.12, 0.24]
	for i in tea_samples.size():
		var t := float(i) / tea_rate
		var s := 0.0
		for ct in clink_times:
			var dt: float = t - ct
			if dt >= 0.0 and dt < 0.1:
				var cenv := exp(-dt * 40.0) * 0.4
				s += sin(TAU * 3800.0 * dt) * cenv + sin(TAU * 5600.0 * dt) * cenv * 0.3
		# Pouring sound (filtered noise from 0.3s onward)
		if t > 0.3:
			var pt := t - 0.3
			s += sin(TAU * 1200.0 * pt) * (randf() * 0.3) * exp(-pt * 8.0) * 0.3
		tea_samples[i] = clampf(s, -1.0, 1.0)
	_tea_sound = _samples_to_wav(tea_samples, tea_rate)
	_tea_player = AudioStreamPlayer.new()
	_tea_player.stream = _tea_sound
	_tea_player.volume_db = -6.0
	add_child(_tea_player)

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
	fire_cooldown -= delta
	_upgrade_flash = max(_upgrade_flash - delta * 0.5, 0.0)
	_cheshire_flash = max(_cheshire_flash - delta * 2.0, 0.0)
	_tea_flash = max(_tea_flash - delta * 2.0, 0.0)
	_attack_anim = max(_attack_anim - delta * 3.0, 0.0)
	_grow_burst = max(_grow_burst - delta * 0.5, 0.0)
	target = _find_nearest_enemy()

	if target:
		var desired = global_position.angle_to_point(target.global_position) + PI
		aim_angle = lerp_angle(aim_angle, desired, 12.0 * delta)
		if fire_cooldown <= 0.0:
			_shoot()
			fire_cooldown = 1.0 / fire_rate

	# Tier 2: Cheshire Cat stun
	if upgrade_tier >= 2:
		cheshire_timer -= delta
		if cheshire_timer <= 0.0 and _has_enemies_in_range():
			_cheshire_stun()
			cheshire_timer = cheshire_cooldown

	# Tier 3: Mad Tea Party volley
	if upgrade_tier >= 3:
		tea_timer -= delta
		if tea_timer <= 0.0 and _has_enemies_in_range():
			_tea_party()
			tea_timer = tea_cooldown

	_process_progressive_abilities(delta)
	queue_redraw()

func _has_enemies_in_range() -> bool:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(enemy.global_position) < attack_range:
			return true
	return false

func _find_nearest_enemy() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist: float = attack_range
	for enemy in enemies:
		var dist = global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest = enemy
			nearest_dist = dist
	return nearest

func _shoot() -> void:
	if not target:
		return
	if _attack_player:
		_attack_player.play()
	_attack_anim = 1.0
	_fire_card(target)

func _fire_card(t: Node2D) -> void:
	var card = card_scene.instantiate()
	card.global_position = global_position + Vector2.from_angle(aim_angle) * 14.0
	var dmg = damage
	if prog_abilities[0]:  # Curiouser: +20% damage
		dmg *= 1.2
	card.damage = dmg
	card.target = t
	card.gold_bonus = gold_bonus
	card.source_tower = self
	card.slow_amount = slow_amount
	card.slow_duration = slow_duration
	card.execute_threshold = execute_threshold
	if prog_abilities[4]:  # Painting the Roses Red
		card.apply_paint = true
	if prog_abilities[8]:  # Wonderland Madness - split
		card.split_count = 1
	get_tree().get_first_node_in_group("main").add_child(card)

func _fire_split_card(t: Node2D, hit_targets: Array, paint: bool) -> void:
	var card = card_scene.instantiate()
	card.global_position = global_position
	card.damage = damage * (1.2 if prog_abilities[0] else 1.0)
	card.target = t
	card.gold_bonus = gold_bonus
	card.source_tower = self
	card.slow_amount = slow_amount
	card.slow_duration = slow_duration
	card.execute_threshold = execute_threshold
	card.apply_paint = paint
	card._hit_targets = hit_targets
	get_tree().get_first_node_in_group("main").add_child(card)

func _cheshire_stun() -> void:
	if _cheshire_player: _cheshire_player.play()
	_cheshire_flash = 1.0
	var enemies = get_tree().get_nodes_in_group("enemies")
	var in_range: Array = []
	for enemy in enemies:
		if global_position.distance_to(enemy.global_position) < attack_range:
			in_range.append(enemy)
	if in_range.size() > 0:
		var picked = in_range[randi() % in_range.size()]
		if picked.has_method("apply_slow"):
			picked.apply_slow(0.0, 2.0)  # Full stop for 2 seconds

func _tea_party() -> void:
	if _tea_player: _tea_player.play()
	_tea_flash = 1.0
	var enemies = get_tree().get_nodes_in_group("enemies")
	var in_range: Array = []
	for enemy in enemies:
		if global_position.distance_to(enemy.global_position) < attack_range:
			in_range.append(enemy)
	in_range.shuffle()
	var count = mini(8, in_range.size())
	for i in range(count):
		_fire_card(in_range[i])

func register_damage(amount: float) -> void:
	damage_dealt += amount
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("register_tower_damage"):
		main.register_tower_damage(main.TowerType.ALICE, amount)

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
	attack_range += 6.0
	slow_amount = max(slow_amount - 0.03, 0.3)
	slow_duration += 0.15
	# Alice grows!
	_grow_scale += 0.06
	_grow_burst = 0.3

func choose_ability(index: int) -> void:
	ability_chosen = true
	awaiting_ability_choice = false
	upgrade_tier = index + 1
	_apply_upgrade(upgrade_tier)
	_upgrade_flash = 3.0
	_upgrade_name = TIER_NAMES[index]

func _apply_upgrade(tier: int) -> void:
	match tier:
		1: # Drink Me — stronger slow
			damage = 35.0
			slow_amount = 0.5
			slow_duration = 2.5
			fire_rate = 3.5
			attack_range = 175.0
		2: # Cheshire Cat — periodic stun
			damage = 45.0
			fire_rate = 4.0
			attack_range = 190.0
			cheshire_cooldown = 10.0
			gold_bonus = 5
		3: # Mad Tea Party — teacup volley
			damage = 55.0
			fire_rate = 4.5
			attack_range = 210.0
			tea_cooldown = 12.0
			slow_amount = 0.45
			gold_bonus = 7
		4: # Off With Their Heads!
			damage = 70.0
			execute_threshold = 0.20
			fire_rate = 5.0
			attack_range = 230.0
			gold_bonus = 10
			slow_amount = 0.4
			slow_duration = 3.0
			cheshire_cooldown = 7.0
			tea_cooldown = 9.0

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
	if _upgrade_player: _upgrade_player.play()
	return true

func get_tower_display_name() -> String:
	return "Alice"

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

func _load_progressive_abilities() -> void:
	var main = get_tree().get_first_node_in_group("main")
	if main and main.survivor_progress.has(main.TowerType.ALICE):
		var p = main.survivor_progress[main.TowerType.ALICE]
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

func _process_progressive_abilities(delta: float) -> void:
	_eat_me_flash = max(_eat_me_flash - delta * 2.0, 0.0)
	_jabberwock_flash = max(_jabberwock_flash - delta * 1.5, 0.0)
	_caterpillar_flash = max(_caterpillar_flash - delta * 2.0, 0.0)

	# Ability 2: Down the Rabbit Hole
	if prog_abilities[1]:
		_rabbit_hole_timer -= delta
		if _rabbit_hole_timer <= 0.0 and _has_enemies_in_range():
			_rabbit_hole()
			_rabbit_hole_timer = 20.0

	# Ability 3: Cheshire Grin — mark for 2x damage
	if prog_abilities[2]:
		_cheshire_grin_timer -= delta
		if _cheshire_grin_timer <= 0.0 and _has_enemies_in_range():
			_cheshire_grin()
			_cheshire_grin_timer = 10.0

	# Ability 4: Eat Me Cake — AoE stomp
	if prog_abilities[3]:
		_eat_me_timer -= delta
		if _eat_me_timer <= 0.0 and _has_enemies_in_range():
			_eat_me_stomp()
			_eat_me_timer = 15.0

	# Ability 6: Caterpillar's Hookah — smoke slow
	if prog_abilities[5]:
		_caterpillar_timer -= delta
		if _caterpillar_timer <= 0.0 and _has_enemies_in_range():
			_caterpillar_smoke()
			_caterpillar_timer = 20.0

	# Ability 7: Tweedledee & Tweedledum — auto-attack nearby
	if prog_abilities[6]:
		_tweedle_timer -= delta
		if _tweedle_timer <= 0.0:
			_tweedle_attack()
			_tweedle_timer = 2.0

	# Ability 8: The Jabberwock — swoop damage
	if prog_abilities[7]:
		_jabberwock_timer -= delta
		if _jabberwock_timer <= 0.0:
			_jabberwock_swoop()
			_jabberwock_timer = 25.0

func _rabbit_hole() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var in_range: Array = []
	for e in enemies:
		if global_position.distance_to(e.global_position) < attack_range:
			in_range.append(e)
	if in_range.size() > 0:
		var picked = in_range[randi() % in_range.size()]
		picked.progress = max(0.0, picked.progress - 150.0)

func _cheshire_grin() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var in_range: Array = []
	for e in enemies:
		if global_position.distance_to(e.global_position) < attack_range:
			in_range.append(e)
	if in_range.size() > 0:
		var picked = in_range[randi() % in_range.size()]
		if picked.has_method("apply_cheshire_mark"):
			picked.apply_cheshire_mark(5.0, 2.0)

func _eat_me_stomp() -> void:
	_eat_me_flash = 1.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) < attack_range:
			if e.has_method("take_damage"):
				var dmg = damage * 4.0
				e.take_damage(dmg)
				register_damage(dmg)

func _caterpillar_smoke() -> void:
	_caterpillar_flash = 1.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) < attack_range:
			if e.has_method("apply_slow"):
				e.apply_slow(0.2, 3.0)

func _tweedle_attack() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var in_range: Array = []
	for e in enemies:
		if global_position.distance_to(e.global_position) < attack_range * 0.6:
			in_range.append(e)
	in_range.shuffle()
	for i in range(mini(2, in_range.size())):
		if in_range[i].has_method("take_damage"):
			var dmg = damage * 0.8
			in_range[i].take_damage(dmg)
			register_damage(dmg)

func _jabberwock_swoop() -> void:
	_jabberwock_flash = 1.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("take_damage"):
			var dmg = damage * 5.0
			e.take_damage(dmg)
			register_damage(dmg)

func _draw() -> void:
	# Selection ring (before grow transform)
	if is_selected:
		var pulse = (sin(_time * 3.0) + 1.0) * 0.5
		var ring_alpha = 0.5 + pulse * 0.3
		draw_arc(Vector2.ZERO, 40.0, 0, TAU, 48, Color(1.0, 0.84, 0.0, ring_alpha), 2.5)
		draw_arc(Vector2.ZERO, 43.0, 0, TAU, 48, Color(1.0, 0.84, 0.0, ring_alpha * 0.4), 1.5)

	# Range indicator (NOT scaled)
	draw_arc(Vector2.ZERO, attack_range, 0, TAU, 64, Color(1, 1, 1, 0.06), 1.0)

	# === PROGRESSIVE ABILITY EFFECTS ===
	if _eat_me_flash > 0.0:
		var em_r = 30.0 + (1.0 - _eat_me_flash) * 60.0
		draw_arc(Vector2.ZERO, em_r, 0, TAU, 24, Color(0.9, 0.5, 0.8, _eat_me_flash * 0.4), 3.0)

	if _jabberwock_flash > 0.0:
		draw_line(Vector2(-80, -40), Vector2(80, 40), Color(0.4, 0.7, 0.3, _jabberwock_flash * 0.5), 4.0)
		draw_line(Vector2(-70, -35), Vector2(70, 35), Color(0.5, 0.3, 0.6, _jabberwock_flash * 0.3), 2.0)

	if _caterpillar_flash > 0.0:
		draw_circle(Vector2.ZERO, 40.0, Color(0.5, 0.3, 0.7, _caterpillar_flash * 0.2))
		draw_circle(Vector2(10, 5), 30.0, Color(0.4, 0.2, 0.6, _caterpillar_flash * 0.15))

	if prog_abilities[6]:  # Tweedledee & Tweedledum orbiting
		for ti in range(2):
			var ta = _time * 2.0 + float(ti) * PI
			var tpos = Vector2(cos(ta) * 25.0, sin(ta) * 15.0)
			draw_circle(tpos, 5.0, Color(0.8, 0.6, 0.4, 0.5))
			draw_circle(tpos, 3.5, Color(0.9, 0.7, 0.5, 0.6))

	# === STONE PLATFORM (Bloons-style, drawn before grow transform) ===
	var plat_y = 22.0
	# Platform shadow
	draw_circle(Vector2(0, plat_y + 4), 28.0, Color(0, 0, 0, 0.15))
	# Stone platform ellipse
	draw_set_transform(Vector2(0, plat_y), 0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 28.0, Color(0.18, 0.16, 0.14))
	draw_circle(Vector2.ZERO, 25.0, Color(0.28, 0.25, 0.22))
	draw_circle(Vector2.ZERO, 20.0, Color(0.35, 0.32, 0.28))
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
			0: pip_col = Color(0.4, 0.6, 0.95)
			1: pip_col = Color(0.7, 0.4, 0.85)
			2: pip_col = Color(0.95, 0.75, 0.3)
			3: pip_col = Color(0.95, 0.2, 0.2)
		draw_circle(pip_pos, 4.0, pip_col)
		draw_circle(pip_pos, 5.5, Color(pip_col.r, pip_col.g, pip_col.b, 0.15))

	# Apply grow scale — character scales with Alice's growth
	var total_scale = _grow_scale + _grow_burst
	draw_set_transform(Vector2.ZERO, 0, Vector2(total_scale, total_scale))

	# Growth burst sparkle effect
	if _grow_burst > 0.0:
		var burst_radius = 50.0 + _grow_burst * 60.0
		draw_circle(Vector2.ZERO, burst_radius, Color(0.9, 0.8, 1.0, _grow_burst * 0.25))
		for i in range(6):
			var spark_angle = TAU * float(i) / 6.0 + _time * 2.0
			var spark_pos = Vector2.from_angle(spark_angle) * burst_radius * 0.8
			draw_circle(spark_pos, 2.5, Color(1.0, 0.95, 0.6, _grow_burst * 0.5))

	var dir = Vector2.from_angle(aim_angle)
	var perp = dir.rotated(PI / 2.0)

	# Chibi idle animation with hip sway + breathing
	var bounce = abs(sin(_time * 2.5)) * 3.0
	var breathe = sin(_time * 2.0) * 1.5
	var dress_sway = sin(_time * 1.8) * 2.5
	var hip_sway = sin(_time * 1.8) * 2.5
	var chest_breathe = sin(_time * 2.0) * 1.0
	var body_offset = Vector2(sin(_time * 1.3) * 1.0, -bounce - breathe)
	# Hair physics — multi-frequency wind
	var hair_wind = sin(_time * 1.5) * 2.0 + sin(_time * 2.7) * 1.2 + sin(_time * 0.4) * 3.0 * clampf(sin(_time * 0.15), 0.0, 1.0)

	# Skin colors
	var skin_base = Color(0.95, 0.84, 0.73)
	var skin_shadow = Color(0.82, 0.70, 0.58)
	var skin_highlight = Color(0.98, 0.90, 0.80)

	# === Tier 4: Red glow aura ===
	if upgrade_tier >= 4:
		var aura_pulse = sin(_time * 3.0) * 0.04 + 0.15
		draw_circle(Vector2.ZERO, 60.0, Color(0.9, 0.15, 0.15, aura_pulse))
		draw_circle(Vector2.ZERO, 50.0, Color(0.95, 0.2, 0.1, aura_pulse * 0.5))
		# Red card particles orbiting
		for i in range(4):
			var card_a = _time * 1.2 + float(i) * TAU / 4.0
			var card_r = 55.0 + sin(_time * 2.0 + float(i)) * 4.0
			var cp = Vector2.from_angle(card_a) * card_r
			var cpd = Vector2.from_angle(card_a + PI * 0.5)
			var cpp = cpd.rotated(PI / 2.0)
			if i % 2 == 0:
				draw_circle(cp - cpp * 1.2, 2.0, Color(0.95, 0.15, 0.15, 0.6))
				draw_circle(cp + cpp * 1.2, 2.0, Color(0.95, 0.15, 0.15, 0.6))
				draw_line(cp, cp - cpd * 2.5, Color(0.95, 0.15, 0.15, 0.6), 2.0)
			else:
				draw_circle(cp, 2.5, Color(0.15, 0.15, 0.2, 0.6))
				draw_line(cp, cp + cpd * 2.5, Color(0.15, 0.15, 0.2, 0.5), 1.5)

	# Upgrade glow ring
	if upgrade_tier > 0:
		var glow_alpha = 0.1 + 0.03 * upgrade_tier
		var glow_col: Color
		match upgrade_tier:
			1: glow_col = Color(0.4, 0.6, 0.9, glow_alpha)
			2: glow_col = Color(0.7, 0.4, 0.8, glow_alpha)
			3: glow_col = Color(0.9, 0.7, 0.3, glow_alpha)
			4: glow_col = Color(0.9, 0.2, 0.2, glow_alpha + 0.06)
		draw_circle(Vector2.ZERO, 55.0, glow_col)

	# Upgrade flash
	if _upgrade_flash > 0.0:
		draw_circle(Vector2.ZERO, 65.0 + _upgrade_flash * 18.0, Color(0.8, 0.7, 1.0, _upgrade_flash * 0.2))

	# Cheshire flash (purple grin expanding)
	if _cheshire_flash > 0.0:
		draw_arc(Vector2.ZERO, 35.0 + (1.0 - _cheshire_flash) * 40.0, 0.3, 2.8, 14, Color(0.7, 0.3, 0.8, _cheshire_flash * 0.5), 4.0)

	# Tea party flash
	if _tea_flash > 0.0:
		draw_circle(Vector2.ZERO, 42.0 + (1.0 - _tea_flash) * 50.0, Color(0.9, 0.75, 0.3, _tea_flash * 0.25))

	# T1+: Shrinking sparkles
	if upgrade_tier >= 1:
		for i in range(5):
			var sp_a = _time * 0.8 + float(i) * TAU / 5.0
			var sp_r = 40.0 + sin(_time * 1.5 + float(i) * 1.3) * 6.0
			var sp_pos = Vector2.from_angle(sp_a) * sp_r
			var sp_size = 2.0 + sin(_time * 3.0 + float(i) * 2.0) * 1.2
			var sp_alpha = 0.3 + sin(_time * 2.0 + float(i)) * 0.12
			draw_line(sp_pos - Vector2(sp_size, 0), sp_pos + Vector2(sp_size, 0), Color(0.6, 0.8, 1.0, sp_alpha), 0.8)
			draw_line(sp_pos - Vector2(0, sp_size), sp_pos + Vector2(0, sp_size), Color(0.6, 0.8, 1.0, sp_alpha), 0.8)

	# === CHARACTER POSITIONS (tall anime proportions ~56px) ===
	var feet_y = body_offset + Vector2(hip_sway * 1.0, 14.0)
	var leg_top = body_offset + Vector2(hip_sway * 0.6, -2.0)
	var torso_center = body_offset + Vector2(hip_sway * 0.3, -10.0 - chest_breathe * 0.5)
	var neck_base = body_offset + Vector2(hip_sway * 0.15, -20.0 - chest_breathe * 0.3)
	var head_center = body_offset + Vector2(hip_sway * 0.08 + hair_wind * 0.1, -32.0)

	# === T1+: "Drink Me" bottle near platform ===
	if upgrade_tier >= 1:
		var bottle_pos = Vector2(-18, 8) + body_offset * 0.3
		# Bottle body (blue glass)
		draw_rect(Rect2(bottle_pos.x - 4, bottle_pos.y - 8, 8, 14), Color(0.2, 0.35, 0.75, 0.8))
		# Glass highlight
		draw_rect(Rect2(bottle_pos.x - 2, bottle_pos.y - 6, 2, 10), Color(0.4, 0.55, 0.9, 0.3))
		# Bottle neck
		draw_rect(Rect2(bottle_pos.x - 2, bottle_pos.y - 14, 4, 6), Color(0.25, 0.4, 0.8, 0.8))
		# Cork
		draw_rect(Rect2(bottle_pos.x - 3, bottle_pos.y - 17, 6, 3), Color(0.6, 0.45, 0.25))
		# Label
		draw_rect(Rect2(bottle_pos.x - 3, bottle_pos.y - 5, 6, 7), Color(0.95, 0.92, 0.85))
		# "DM" text hint
		draw_line(Vector2(bottle_pos.x - 2, bottle_pos.y - 2), Vector2(bottle_pos.x, bottle_pos.y - 2), Color(0.2, 0.15, 0.1), 1.0)
		draw_line(Vector2(bottle_pos.x + 1, bottle_pos.y - 2), Vector2(bottle_pos.x + 3, bottle_pos.y - 2), Color(0.2, 0.15, 0.1), 1.0)
		# Liquid bubbles
		var bub_t = fmod(_time * 0.7, 3.0)
		draw_circle(Vector2(bottle_pos.x + 1, bottle_pos.y + 2 - bub_t * 4.0), 1.0, Color(0.6, 0.75, 1.0, max(0.0, 0.35 - bub_t * 0.12)))

	# === Mary Jane shoes (black patent leather) ===
	var l_foot = feet_y + Vector2(-7, 0)
	var r_foot = feet_y + Vector2(7, 0)
	# Shoe base
	draw_circle(l_foot, 5.5, Color(0.06, 0.06, 0.06))
	draw_circle(l_foot, 4.2, Color(0.12, 0.12, 0.14))
	draw_circle(r_foot, 5.5, Color(0.06, 0.06, 0.06))
	draw_circle(r_foot, 4.2, Color(0.12, 0.12, 0.14))
	# Patent leather shine
	draw_circle(l_foot + Vector2(1, -1.5), 2.0, Color(0.35, 0.35, 0.4, 0.4))
	draw_circle(r_foot + Vector2(-1, -1.5), 2.0, Color(0.35, 0.35, 0.4, 0.4))
	# Strap across
	draw_line(l_foot + Vector2(-4, -2), l_foot + Vector2(4, -2), Color(0.1, 0.1, 0.1), 2.0)
	draw_line(r_foot + Vector2(-4, -2), r_foot + Vector2(4, -2), Color(0.1, 0.1, 0.1), 2.0)
	# Gold buckles
	draw_circle(l_foot + Vector2(0, -2), 1.5, Color(0.75, 0.65, 0.3))
	draw_circle(l_foot + Vector2(-0.3, -2.3), 0.7, Color(0.95, 0.9, 0.6, 0.6))
	draw_circle(r_foot + Vector2(0, -2), 1.5, Color(0.75, 0.65, 0.3))
	draw_circle(r_foot + Vector2(-0.3, -2.3), 0.7, Color(0.95, 0.9, 0.6, 0.6))

	# === SHAPELY LEGS (polygon-based curvy thighs and calves with white stockings) ===
	var l_hip = leg_top + Vector2(-8, 0)
	var r_hip = leg_top + Vector2(8, 0)
	var l_knee = body_offset + Vector2(-6, 6.0)
	var r_knee = body_offset + Vector2(6, 6.0)
	# LEFT THIGH — curvy feminine shape (wider at hip, tapered to knee)
	draw_colored_polygon(PackedVector2Array([
		l_hip + Vector2(3, 0), l_hip + Vector2(-4, 0),
		l_hip.lerp(l_knee, 0.3) + Vector2(-6, 0),  # outer thigh curve
		l_hip.lerp(l_knee, 0.6) + Vector2(-5.5, 0),
		l_knee + Vector2(-4, 0), l_knee + Vector2(3, 0),
		l_hip.lerp(l_knee, 0.5) + Vector2(4.5, 0),  # inner thigh
	]), Color(0.08, 0.08, 0.08))
	draw_colored_polygon(PackedVector2Array([
		l_hip + Vector2(2, 0), l_hip + Vector2(-3, 0),
		l_hip.lerp(l_knee, 0.3) + Vector2(-5, 0),
		l_knee + Vector2(-3, 0), l_knee + Vector2(2, 0),
	]), Color(0.94, 0.94, 0.94))
	# RIGHT THIGH
	draw_colored_polygon(PackedVector2Array([
		r_hip + Vector2(-3, 0), r_hip + Vector2(4, 0),
		r_hip.lerp(r_knee, 0.3) + Vector2(6, 0),
		r_hip.lerp(r_knee, 0.6) + Vector2(5.5, 0),
		r_knee + Vector2(4, 0), r_knee + Vector2(-3, 0),
		r_hip.lerp(r_knee, 0.5) + Vector2(-4.5, 0),
	]), Color(0.08, 0.08, 0.08))
	draw_colored_polygon(PackedVector2Array([
		r_hip + Vector2(-2, 0), r_hip + Vector2(3, 0),
		r_hip.lerp(r_knee, 0.3) + Vector2(5, 0),
		r_knee + Vector2(3, 0), r_knee + Vector2(-2, 0),
	]), Color(0.94, 0.94, 0.94))
	# Knee joints (rounded)
	draw_circle(l_knee, 4.5, Color(0.08, 0.08, 0.08))
	draw_circle(l_knee, 3.5, Color(0.94, 0.94, 0.94))
	draw_circle(r_knee, 4.5, Color(0.08, 0.08, 0.08))
	draw_circle(r_knee, 3.5, Color(0.94, 0.94, 0.94))
	# LEFT CALF — shapely curve (fuller at top, tapered to ankle)
	var l_calf_mid = body_offset + Vector2(-7.0, 10.0)
	draw_colored_polygon(PackedVector2Array([
		l_knee + Vector2(-4, 0), l_knee + Vector2(3, 0),
		l_calf_mid + Vector2(4, 0),
		l_foot + Vector2(2.5, -3), l_foot + Vector2(-2.5, -3),
		l_calf_mid + Vector2(-5.5, 0),  # calf curve
	]), Color(0.08, 0.08, 0.08))
	draw_colored_polygon(PackedVector2Array([
		l_knee + Vector2(-3, 0), l_knee + Vector2(2, 0),
		l_foot + Vector2(1.5, -3), l_foot + Vector2(-1.5, -3),
	]), Color(0.94, 0.94, 0.94))
	draw_circle(l_calf_mid + Vector2(-1, 0), 3.0, Color(1.0, 1.0, 1.0, 0.15))
	# RIGHT CALF
	var r_calf_mid = body_offset + Vector2(7.0, 10.0)
	draw_colored_polygon(PackedVector2Array([
		r_knee + Vector2(4, 0), r_knee + Vector2(-3, 0),
		r_calf_mid + Vector2(-4, 0),
		r_foot + Vector2(-2.5, -3), r_foot + Vector2(2.5, -3),
		r_calf_mid + Vector2(5.5, 0),
	]), Color(0.08, 0.08, 0.08))
	draw_colored_polygon(PackedVector2Array([
		r_knee + Vector2(3, 0), r_knee + Vector2(-2, 0),
		r_foot + Vector2(-1.5, -3), r_foot + Vector2(1.5, -3),
	]), Color(0.94, 0.94, 0.94))
	draw_circle(r_calf_mid + Vector2(1, 0), 3.0, Color(1.0, 1.0, 1.0, 0.15))
	# Stocking shine highlights
	draw_line(l_knee + Vector2(1, 0), l_calf_mid + Vector2(1, 0), Color(1.0, 1.0, 1.0, 0.35), 1.5)
	draw_line(r_knee + Vector2(-1, 0), r_calf_mid + Vector2(-1, 0), Color(1.0, 1.0, 1.0, 0.35), 1.5)
	# Lace stocking tops
	draw_arc(l_knee + Vector2(0, -2), 4.5, -0.2, PI + 0.2, 8, Color(0.92, 0.92, 0.90, 0.6), 1.5)
	draw_arc(r_knee + Vector2(0, -2), 4.5, -0.2, PI + 0.2, 8, Color(0.92, 0.92, 0.90, 0.6), 1.5)
	for li in range(5):
		var la = float(li) * PI / 4.0
		draw_circle(l_knee + Vector2(0, -2) + Vector2.from_angle(la) * 4.5, 0.8, Color(0.92, 0.92, 0.90, 0.4))
		draw_circle(r_knee + Vector2(0, -2) + Vector2.from_angle(la) * 4.5, 0.8, Color(0.92, 0.92, 0.90, 0.4))

	# === Blue dress (shorter, fitted hourglass, Victorian with lower neckline) ===
	# Dress: from neck_base area down to just above the knees (~y=4)
	var dress_hem_y = body_offset.y + 4.0  # Above-the-knee hemline
	# Hourglass silhouette: shoulders ±12, waist ±7, hips ±13
	var dress_pts = PackedVector2Array([
		# Left hem (flared at hips)
		Vector2(-13 + dress_sway * 0.5, dress_hem_y),
		# Left hip
		Vector2(-13, leg_top.y),
		# Left waist (cinched)
		Vector2(-7, torso_center.y + 2),
		# Left bust
		Vector2(-11, torso_center.y - 4),
		# Left shoulder
		Vector2(-12, neck_base.y + 2),
		# Neckline left (lower V)
		Vector2(-5, neck_base.y + 4),
		# Neckline center (lower)
		Vector2(0, neck_base.y + 6),
		# Neckline right
		Vector2(5, neck_base.y + 4),
		# Right shoulder
		Vector2(12, neck_base.y + 2),
		# Right bust
		Vector2(11, torso_center.y - 4),
		# Right waist (cinched)
		Vector2(7, torso_center.y + 2),
		# Right hip
		Vector2(13, leg_top.y),
		# Right hem
		Vector2(13 - dress_sway * 0.5, dress_hem_y),
	])
	draw_colored_polygon(dress_pts, Color(0.22, 0.40, 0.72))
	# Bust definition — two gentle curves with shadow
	draw_arc(Vector2(-5, torso_center.y - 5), 5.0, PI * 0.2, PI * 0.9, 8, Color(0.18, 0.35, 0.60, 0.4), 1.5)
	draw_arc(Vector2(5, torso_center.y - 5), 5.0, PI * 0.1, PI * 0.8, 8, Color(0.18, 0.35, 0.60, 0.4), 1.5)
	# Shadow line between (tasteful cleavage hint)
	draw_line(Vector2(0, neck_base.y + 6), Vector2(0, torso_center.y - 3), Color(0.15, 0.30, 0.55, 0.3), 1.0)
	# Dress lighter center panel
	var dress_hi = PackedVector2Array([
		Vector2(-5, dress_hem_y - 2),
		Vector2(-5, torso_center.y - 2),
		Vector2(5, torso_center.y - 2),
		Vector2(5, dress_hem_y - 2),
	])
	draw_colored_polygon(dress_hi, Color(0.30, 0.50, 0.82, 0.25))
	# Dress fold shadows
	draw_line(Vector2(-11, torso_center.y - 3), Vector2(-13, dress_hem_y), Color(0.15, 0.30, 0.55, 0.4), 1.2)
	draw_line(Vector2(11, torso_center.y - 3), Vector2(13, dress_hem_y), Color(0.15, 0.30, 0.55, 0.4), 1.2)
	# Waist cinch line / belt / sash
	draw_line(Vector2(-8, torso_center.y + 2), Vector2(8, torso_center.y + 2), Color(0.15, 0.30, 0.55), 2.5)
	draw_line(Vector2(-7, torso_center.y + 2), Vector2(7, torso_center.y + 2), Color(0.25, 0.42, 0.70), 1.5)
	# Sash bow at center waist
	draw_arc(Vector2(-4, torso_center.y + 2), 2.5, PI * 0.3, PI * 1.7, 6, Color(0.20, 0.38, 0.68), 1.5)
	draw_arc(Vector2(4, torso_center.y + 2), 2.5, -PI * 0.7, PI * 0.7, 6, Color(0.20, 0.38, 0.68), 1.5)
	draw_circle(Vector2(0, torso_center.y + 2), 1.5, Color(0.18, 0.35, 0.62))
	# Dress hem scallops (shorter dress, with flutter)
	for i in range(8):
		var hx = -12.0 + float(i) * 3.5
		var flutter = sin(_time * 3.0 + float(i) * 0.8) * 1.2
		var sway_off = dress_sway * (float(i) / 8.0 - 0.5) * 0.3 + flutter
		draw_circle(Vector2(hx, dress_hem_y + sway_off), 2.5, Color(0.18, 0.35, 0.65, 0.2))
	# Skirt flare lines
	draw_line(Vector2(-7, torso_center.y + 3), Vector2(-13, dress_hem_y), Color(0.18, 0.35, 0.60, 0.15), 1.0)
	draw_line(Vector2(7, torso_center.y + 3), Vector2(13, dress_hem_y), Color(0.18, 0.35, 0.60, 0.15), 1.0)
	draw_line(Vector2(0, torso_center.y + 3), Vector2(-2 + dress_sway * 0.3, dress_hem_y), Color(0.18, 0.35, 0.60, 0.1), 0.8)

	# === White pinafore/apron (cinched at waist, fitted) ===
	# Apron bib: from neckline to waist, then skirt flares to hem
	var apron_pts = PackedVector2Array([
		# Skirt bottom left
		Vector2(-10, dress_hem_y - 1),
		# Left hip
		Vector2(-11, leg_top.y),
		# Left waist (cinched with dress)
		Vector2(-6, torso_center.y + 2),
		# Left bib
		Vector2(-7, torso_center.y - 4),
		# Bib top left
		Vector2(-5, neck_base.y + 5),
		# Bib top right
		Vector2(5, neck_base.y + 5),
		# Right bib
		Vector2(7, torso_center.y - 4),
		# Right waist
		Vector2(6, torso_center.y + 2),
		# Right hip
		Vector2(11, leg_top.y),
		# Skirt bottom right
		Vector2(10, dress_hem_y - 1),
	])
	draw_colored_polygon(apron_pts, Color(0.96, 0.96, 0.93))
	# Apron center crease
	draw_line(Vector2(0, neck_base.y + 6), Vector2(0, dress_hem_y - 2), Color(0.90, 0.90, 0.88, 0.3), 1.0)
	# Lace edge on apron bottom
	for li in range(6):
		var lx = -8.0 + float(li) * 3.2
		var lace_tip = Vector2(lx, dress_hem_y + 1.0)
		draw_line(Vector2(lx - 1, dress_hem_y - 1), lace_tip, Color(0.92, 0.92, 0.90, 0.6), 1.0)
		draw_line(lace_tip, Vector2(lx + 1, dress_hem_y - 1), Color(0.92, 0.92, 0.90, 0.6), 1.0)
	# Gothic tatter marks on apron (subtle worn edges)
	draw_line(Vector2(-9, dress_hem_y - 3), Vector2(-11, dress_hem_y), Color(0.88, 0.86, 0.82, 0.3), 0.8)
	draw_line(Vector2(8, dress_hem_y - 4), Vector2(10, dress_hem_y - 1), Color(0.88, 0.86, 0.82, 0.3), 0.8)
	# Apron straps (over shoulders to neck_base area)
	draw_line(Vector2(-5, neck_base.y + 5), Vector2(-8, neck_base.y + 1), Color(0.94, 0.94, 0.92), 3.0)
	draw_line(Vector2(5, neck_base.y + 5), Vector2(8, neck_base.y + 1), Color(0.94, 0.94, 0.92), 3.0)
	# Buttons on bib
	draw_circle(Vector2(0, torso_center.y - 2), 1.5, Color(0.85, 0.85, 0.82))
	draw_circle(Vector2(-0.3, torso_center.y - 2.3), 0.6, Color(1.0, 1.0, 1.0, 0.4))
	draw_circle(Vector2(0, torso_center.y + 1), 1.5, Color(0.85, 0.85, 0.82))
	draw_circle(Vector2(-0.3, torso_center.y + 0.7), 0.6, Color(1.0, 1.0, 1.0, 0.4))
	# Cheshire grin pattern on apron (gothic corruption hint)
	if upgrade_tier >= 2:
		var grin_alpha = 0.06 + sin(_time * 1.5) * 0.03
		draw_arc(Vector2(0, leg_top.y - 2), 6.0, 0.2, PI - 0.2, 8, Color(0.6, 0.2, 0.7, grin_alpha), 1.0)

	# Apron bow at back (at waist level)
	var bow_pos = Vector2(0, torso_center.y + 2)
	draw_arc(bow_pos + Vector2(-8, 0), 4.0, PI * 0.3, PI * 1.7, 8, Color(0.94, 0.94, 0.92), 2.5)
	draw_arc(bow_pos + Vector2(8, 0), 4.0, -PI * 0.7, PI * 0.7, 8, Color(0.94, 0.94, 0.92), 2.5)
	draw_circle(bow_pos, 2.0, Color(0.93, 0.93, 0.90))
	# Bow tails (longer, more elegant)
	var tail_flutter = sin(_time * 2.5) * 1.5
	draw_line(bow_pos + Vector2(-3, 0), bow_pos + Vector2(-8, 10 + tail_flutter), Color(0.93, 0.93, 0.90), 2.0)
	draw_line(bow_pos + Vector2(3, 0), bow_pos + Vector2(8, 10 - tail_flutter), Color(0.93, 0.93, 0.90), 2.0)

	# === Puffed sleeves (blue, at shoulder height framing bare shoulders) ===
	var l_shoulder = Vector2(-12, neck_base.y + 2)
	var r_shoulder = Vector2(12, neck_base.y + 2)
	# Left puffed sleeve
	draw_circle(l_shoulder, 7.0, Color(0.18, 0.35, 0.60, 0.4))
	draw_circle(l_shoulder, 6.0, Color(0.25, 0.44, 0.76))
	draw_circle(l_shoulder + Vector2(0, 1), 4.0, Color(0.35, 0.55, 0.88, 0.3))
	draw_arc(l_shoulder, 6.0, 0, TAU, 10, Color(0.18, 0.35, 0.60), 1.0)
	# Sleeve cuff (white lace)
	draw_arc(l_shoulder, 6.5, PI * 0.6, PI * 1.4, 6, Color(0.95, 0.95, 0.93), 2.0)
	# Right puffed sleeve
	draw_circle(r_shoulder, 7.0, Color(0.18, 0.35, 0.60, 0.4))
	draw_circle(r_shoulder, 6.0, Color(0.25, 0.44, 0.76))
	draw_circle(r_shoulder + Vector2(0, 1), 4.0, Color(0.35, 0.55, 0.88, 0.3))
	draw_arc(r_shoulder, 6.0, 0, TAU, 10, Color(0.18, 0.35, 0.60), 1.0)
	draw_arc(r_shoulder, 6.5, PI * 0.6, PI * 1.4, 6, Color(0.95, 0.95, 0.93), 2.0)
	# Bare skin visible between sleeve and neckline (shoulders/collarbone)
	draw_line(l_shoulder + Vector2(5, -1), Vector2(-5, neck_base.y + 3), skin_base, 3.0)
	draw_line(r_shoulder + Vector2(-5, -1), Vector2(5, neck_base.y + 3), skin_base, 3.0)
	# Collarbone hint
	draw_line(Vector2(-8, neck_base.y + 3), Vector2(8, neck_base.y + 3), Color(0.88, 0.76, 0.64, 0.2), 0.8)

	# === Peter Pan collar (white, at neckline) ===
	draw_arc(Vector2(-5, neck_base.y + 3), 5.0, PI * 0.3, PI * 1.2, 8, Color(0.97, 0.97, 0.95), 3.0)
	draw_arc(Vector2(5, neck_base.y + 3), 5.0, -PI * 0.2, PI * 0.7, 8, Color(0.97, 0.97, 0.95), 3.0)

	# === Arms (slender feminine polygon shapes, starting from shoulders) ===
	# Card-throwing arm (right) — extends toward aim direction
	var attack_extend = _attack_anim * 10.0
	var r_elbow = r_shoulder + Vector2(4, 8)
	var card_hand: Vector2
	card_hand = r_shoulder + dir * (16.0 + attack_extend)
	# RIGHT UPPER ARM — slender feminine polygon
	var r_ua_dir = (r_elbow - r_shoulder).normalized()
	var r_ua_perp = r_ua_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		r_shoulder + r_ua_perp * 3.0, r_shoulder - r_ua_perp * 2.5,
		r_shoulder.lerp(r_elbow, 0.5) - r_ua_perp * 3.0,
		r_elbow - r_ua_perp * 2.2, r_elbow + r_ua_perp * 2.2,
		r_shoulder.lerp(r_elbow, 0.5) + r_ua_perp * 2.5,
	]), skin_shadow)
	draw_colored_polygon(PackedVector2Array([
		r_shoulder + r_ua_perp * 2.2, r_shoulder - r_ua_perp * 1.8,
		r_elbow - r_ua_perp * 1.5, r_elbow + r_ua_perp * 1.5,
	]), skin_base)
	# Arm highlight
	draw_line(r_shoulder.lerp(r_elbow, 0.2) + r_ua_perp * 1.5, r_shoulder.lerp(r_elbow, 0.7) + r_ua_perp * 1.5, skin_highlight, 1.0)
	# Elbow joint
	draw_circle(r_elbow, 3.0, skin_shadow)
	draw_circle(r_elbow, 2.2, skin_base)
	# RIGHT FOREARM — tapered to wrist
	var r_fa_dir = (card_hand - r_elbow).normalized()
	var r_fa_perp = r_fa_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		r_elbow + r_fa_perp * 2.2, r_elbow - r_fa_perp * 2.2,
		r_elbow.lerp(card_hand, 0.5) - r_fa_perp * 2.0,
		card_hand - r_fa_perp * 1.5, card_hand + r_fa_perp * 1.5,
		r_elbow.lerp(card_hand, 0.5) + r_fa_perp * 1.8,
	]), skin_shadow)
	draw_colored_polygon(PackedVector2Array([
		r_elbow + r_fa_perp * 1.5, r_elbow - r_fa_perp * 1.5,
		card_hand - r_fa_perp * 0.9, card_hand + r_fa_perp * 0.9,
	]), skin_base)
	# Wrist and hand
	draw_circle(card_hand, 3.5, skin_shadow)
	draw_circle(card_hand, 2.8, skin_base)
	# Dainty fingers
	for fi in range(3):
		var fa = float(fi - 1) * 0.35
		draw_circle(card_hand + dir.rotated(fa) * 3.5, 1.2, skin_highlight)

	# Left arm (by her side, holding dress, slender)
	var l_elbow = l_shoulder + Vector2(-4, 8)
	var off_hand = l_shoulder + Vector2(-6, 16)
	# LEFT UPPER ARM — slender feminine polygon
	var l_ua_dir = (l_elbow - l_shoulder).normalized()
	var l_ua_perp = l_ua_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		l_shoulder + l_ua_perp * 2.5, l_shoulder - l_ua_perp * 3.0,
		l_shoulder.lerp(l_elbow, 0.5) - l_ua_perp * 3.0,
		l_elbow - l_ua_perp * 2.2, l_elbow + l_ua_perp * 2.2,
		l_shoulder.lerp(l_elbow, 0.5) + l_ua_perp * 2.5,
	]), skin_shadow)
	draw_colored_polygon(PackedVector2Array([
		l_shoulder + l_ua_perp * 1.8, l_shoulder - l_ua_perp * 2.2,
		l_elbow - l_ua_perp * 1.5, l_elbow + l_ua_perp * 1.5,
	]), skin_base)
	draw_line(l_shoulder.lerp(l_elbow, 0.2) - l_ua_perp * 1.5, l_shoulder.lerp(l_elbow, 0.7) - l_ua_perp * 1.5, skin_highlight, 1.0)
	# Elbow joint
	draw_circle(l_elbow, 3.0, skin_shadow)
	draw_circle(l_elbow, 2.2, skin_base)
	# LEFT FOREARM — tapered
	var l_fa_dir = (off_hand - l_elbow).normalized()
	var l_fa_perp = l_fa_dir.rotated(PI / 2.0)
	draw_colored_polygon(PackedVector2Array([
		l_elbow + l_fa_perp * 2.2, l_elbow - l_fa_perp * 2.2,
		off_hand - l_fa_perp * 1.5, off_hand + l_fa_perp * 1.5,
	]), skin_shadow)
	draw_colored_polygon(PackedVector2Array([
		l_elbow + l_fa_perp * 1.5, l_elbow - l_fa_perp * 1.5,
		off_hand - l_fa_perp * 0.9, off_hand + l_fa_perp * 0.9,
	]), skin_base)
	# Hand
	draw_circle(off_hand, 3.0, skin_shadow)
	draw_circle(off_hand, 2.3, skin_base)

	# === Fan of cards in hand ===
	for i in range(4):
		var fan_angle = aim_angle + (float(i) - 1.5) * 0.2
		var fan_dir = Vector2.from_angle(fan_angle)
		var fan_perp = fan_dir.rotated(PI / 2.0)
		var card_end = card_hand + fan_dir * 20.0
		# Card shadow
		draw_line(card_hand + fan_perp * 0.5, card_end + fan_perp * 0.5, Color(0.3, 0.3, 0.25, 0.25), 6.0)
		# Card body
		draw_line(card_hand, card_end, Color(0.3, 0.3, 0.28), 7.0)
		draw_line(card_hand, card_end, Color(0.98, 0.98, 0.95), 5.5)
		# Suit symbol
		var suit_pos = card_hand + fan_dir * 12.0
		if i % 4 == 0:
			# Heart
			draw_circle(suit_pos - fan_perp * 1.0, 1.8, Color(0.9, 0.15, 0.15))
			draw_circle(suit_pos + fan_perp * 1.0, 1.8, Color(0.9, 0.15, 0.15))
			draw_line(suit_pos, suit_pos - fan_dir * 2.5, Color(0.9, 0.15, 0.15), 2.0)
		elif i % 4 == 1:
			# Spade
			draw_circle(suit_pos + fan_dir * 0.5, 2.0, Color(0.12, 0.12, 0.15))
			draw_line(suit_pos, suit_pos - fan_dir * 2.0, Color(0.12, 0.12, 0.15), 1.2)
		elif i % 4 == 2:
			# Diamond
			var dp = [suit_pos + fan_dir * 2.0, suit_pos + fan_perp * 1.5, suit_pos - fan_dir * 2.0, suit_pos - fan_perp * 1.5]
			draw_line(dp[0], dp[1], Color(0.9, 0.15, 0.15), 1.5)
			draw_line(dp[1], dp[2], Color(0.9, 0.15, 0.15), 1.5)
			draw_line(dp[2], dp[3], Color(0.9, 0.15, 0.15), 1.5)
			draw_line(dp[3], dp[0], Color(0.9, 0.15, 0.15), 1.5)
		else:
			# Club
			draw_circle(suit_pos + fan_dir * 1.0, 1.5, Color(0.12, 0.12, 0.15))
			draw_circle(suit_pos - fan_perp * 1.2, 1.5, Color(0.12, 0.12, 0.15))
			draw_circle(suit_pos + fan_perp * 1.2, 1.5, Color(0.12, 0.12, 0.15))

	# Thrown card flash
	if _attack_anim > 0.3:
		var thrown_end = card_hand + dir * (35.0 * _attack_anim)
		draw_line(card_hand, thrown_end, Color(0.95, 0.95, 0.9, _attack_anim), 5.0)
		draw_line(card_hand, thrown_end, Color(0.85, 0.15, 0.15, _attack_anim * 0.7), 2.5)
		for ti in range(2):
			var trail_t = float(ti + 1) / 3.0
			var trail_pos = card_hand.lerp(thrown_end, trail_t)
			draw_circle(trail_pos, 1.5, Color(1.0, 0.95, 0.8, _attack_anim * (0.4 - float(ti) * 0.15)))

	# === NECK (slender, feminine polygon neck with definition) ===
	var neck_top = head_center + Vector2(0, 7)
	var neck_dir = (neck_top - neck_base).normalized()
	var neck_perp = neck_dir.rotated(PI / 2.0)
	# Neck shadow/outline polygon (wider at base, slender at top)
	draw_colored_polygon(PackedVector2Array([
		neck_base + neck_perp * 5.0, neck_base - neck_perp * 5.0,
		neck_base.lerp(neck_top, 0.5) - neck_perp * 4.0,
		neck_top - neck_perp * 3.5, neck_top + neck_perp * 3.5,
		neck_base.lerp(neck_top, 0.5) + neck_perp * 4.0,
	]), skin_shadow)
	# Inner neck fill
	draw_colored_polygon(PackedVector2Array([
		neck_base + neck_perp * 4.0, neck_base - neck_perp * 4.0,
		neck_top - neck_perp * 2.8, neck_top + neck_perp * 2.8,
	]), skin_base)
	# Neck highlight (left side light)
	draw_line(neck_base.lerp(neck_top, 0.15) + neck_perp * 2.5, neck_base.lerp(neck_top, 0.85) + neck_perp * 2.0, skin_highlight, 1.5)
	# Subtle throat shadow
	draw_line(neck_base.lerp(neck_top, 0.2) - neck_perp * 0.5, neck_base.lerp(neck_top, 0.8) - neck_perp * 0.3, Color(0.78, 0.66, 0.54, 0.15), 1.0)

	# === HEAD (proportional anime head, radius ~10) ===
	# Blonde hair (back layer — behind face, with wind physics)
	var hair_wave = sin(_time * 1.5) * 3.0 + hair_wind
	var hair_base_col = Color(0.72, 0.60, 0.22)
	var hair_bright = Color(0.95, 0.85, 0.45)
	var hair_hi = Color(1.0, 0.92, 0.55)
	# Hair mass (scaled from 14.5 to ~10.3)
	draw_circle(head_center, 10.5, hair_base_col)
	draw_circle(head_center + Vector2(0, -0.7), 9.3, Color(0.85, 0.75, 0.35))
	# Top highlight
	draw_circle(head_center + Vector2(-1.4, -2.8), 5.7, Color(0.92, 0.82, 0.42, 0.3))
	# Flowing hair strands (longer — Alice's signature, scaled x positions by 0.71)
	var strand_data = [
		[-10.0, 22.0, 4.5, hair_base_col], [-7.0, 26.0, 3.8, hair_bright],
		[-3.0, 28.0, 3.2, hair_base_col], [3.0, 28.0, 3.2, hair_bright],
		[7.0, 26.0, 3.8, hair_base_col], [10.0, 22.0, 4.5, hair_bright],
	]
	for sd in strand_data:
		var sx: float = sd[0]
		var slen: float = sd[1]
		var swid: float = sd[2]
		var scol: Color = sd[3]
		var wave_off = hair_wave * (1.0 if sx > 0 else -1.0) * 0.4
		draw_line(head_center + Vector2(sx, 4), head_center + Vector2(sx + wave_off, slen), scol, swid)
		# Secondary thinner strand
		draw_line(head_center + Vector2(sx + 1.5, 3.5), head_center + Vector2(sx + 0.7 + wave_off * 0.6, slen - 3), Color(scol.r, scol.g, scol.b, 0.6), swid * 0.5)
	# Curled ends
	for ci in range(3):
		var cx = -7.0 + float(ci) * 7.0
		var cy = 24.0 + float(ci % 2) * 3.0
		draw_arc(head_center + Vector2(cx + hair_wave * 0.3, cy), 2.0, 0, PI, 6, Color(0.88, 0.78, 0.38, 0.5), 1.5)
	# Hair shine arc
	draw_arc(head_center + Vector2(0, -2), 8.5, PI * 0.55, PI * 1.0, 10, Color(1.0, 0.96, 0.65, 0.4), 2.0)

	# Face (clean oval with defined jawline)
	draw_circle(head_center + Vector2(0, 0.7), 8.2, skin_base)
	# Jawline definition — clean angular lines from ears to chin
	draw_line(head_center + Vector2(-7.5, 1.5), head_center + Vector2(-4, 7), Color(0.78, 0.66, 0.54, 0.3), 1.2)
	draw_line(head_center + Vector2(7.5, 1.5), head_center + Vector2(4, 7), Color(0.78, 0.66, 0.54, 0.3), 1.2)
	# Chin — small, feminine, defined
	draw_circle(head_center + Vector2(0, 7), 2.8, skin_base)
	draw_circle(head_center + Vector2(0, 7.2), 2.0, skin_highlight)
	draw_arc(head_center + Vector2(0, 5), 5.0, 0.15, PI - 0.15, 10, Color(0.78, 0.66, 0.54, 0.12), 0.8)
	# Rosy cheeks (Alice's signature blush)
	draw_circle(head_center + Vector2(-5, 2.1), 2.5, Color(0.95, 0.55, 0.50, 0.18))
	draw_circle(head_center + Vector2(-5, 2.1), 1.6, Color(0.95, 0.48, 0.45, 0.22))
	draw_circle(head_center + Vector2(5, 2.1), 2.5, Color(0.95, 0.55, 0.50, 0.18))
	draw_circle(head_center + Vector2(5, 2.1), 1.6, Color(0.95, 0.48, 0.45, 0.22))

	# Ears peeking through hair (scaled: 12 -> 8.5)
	draw_circle(head_center + Vector2(-8.5, 0), 2.2, skin_base)
	draw_circle(head_center + Vector2(-8.5, 0), 1.1, Color(0.95, 0.72, 0.68, 0.4))
	draw_circle(head_center + Vector2(8.5, 0), 2.2, skin_base)
	draw_circle(head_center + Vector2(8.5, 0), 1.1, Color(0.95, 0.72, 0.68, 0.4))

	# Black headband (Tenniel-accurate, scaled: 13->9.2, 5->3.5, 7->5)
	draw_line(head_center + Vector2(-9.2, -3.5), head_center + Vector2(0, -5), Color(0.08, 0.08, 0.10), 3.5)
	draw_line(head_center + Vector2(0, -5), head_center + Vector2(9.2, -3.5), Color(0.08, 0.08, 0.10), 3.5)
	draw_line(head_center + Vector2(-9.2, -3.5), head_center + Vector2(0, -5), Color(0.12, 0.12, 0.14), 2.2)
	draw_line(head_center + Vector2(0, -5), head_center + Vector2(9.2, -3.5), Color(0.12, 0.12, 0.14), 2.2)
	# Satin highlight
	draw_line(head_center + Vector2(-7, -3.9), head_center + Vector2(0, -5.3), Color(0.3, 0.3, 0.35, 0.3), 0.8)
	# Headband bow (left side, scaled: 14->10, 3->2.1, 7->5)
	draw_arc(head_center + Vector2(-10, -2.1), 2.5, PI * 0.3, PI * 1.7, 6, Color(0.12, 0.12, 0.14), 1.5)
	draw_arc(head_center + Vector2(-10, -5), 2.5, PI * 0.3, PI * 1.7, 6, Color(0.12, 0.12, 0.14), 1.5)
	draw_circle(head_center + Vector2(-9.2, -3.5), 1.3, Color(0.10, 0.10, 0.12))
	# Bow tails
	draw_line(head_center + Vector2(-10, -3.5), head_center + Vector2(-13, -0.7), Color(0.12, 0.12, 0.14), 1.2)
	draw_line(head_center + Vector2(-10, -3.5), head_center + Vector2(-12, -6.4), Color(0.12, 0.12, 0.14), 1.2)

	# Anime eyes (slightly smaller but still expressive, blue, curious)
	var look_dir = dir * 1.2
	var l_eye = head_center + Vector2(-3.5, -0.7)
	var r_eye = head_center + Vector2(3.5, -0.7)
	# Eye socket shadow
	draw_circle(l_eye, 4.0, Color(0.82, 0.72, 0.62, 0.2))
	draw_circle(r_eye, 4.0, Color(0.82, 0.72, 0.62, 0.2))
	# Eye whites
	draw_circle(l_eye, 3.6, Color(0.97, 0.97, 1.0))
	draw_circle(r_eye, 3.6, Color(0.97, 0.97, 1.0))
	# Blue irises (Alice's blue eyes)
	draw_circle(l_eye + look_dir, 2.3, Color(0.12, 0.28, 0.55))
	draw_circle(l_eye + look_dir, 1.8, Color(0.25, 0.45, 0.78))
	draw_circle(l_eye + look_dir, 1.3, Color(0.40, 0.60, 0.92))
	draw_circle(r_eye + look_dir, 2.3, Color(0.12, 0.28, 0.55))
	draw_circle(r_eye + look_dir, 1.8, Color(0.25, 0.45, 0.78))
	draw_circle(r_eye + look_dir, 1.3, Color(0.40, 0.60, 0.92))
	# Pupils
	draw_circle(l_eye + look_dir * 1.15, 1.1, Color(0.04, 0.04, 0.08))
	draw_circle(r_eye + look_dir * 1.15, 1.1, Color(0.04, 0.04, 0.08))
	# Primary highlight (sparkle)
	draw_circle(l_eye + Vector2(-0.85, -1.1), 1.1, Color(1.0, 1.0, 1.0, 0.95))
	draw_circle(r_eye + Vector2(-0.85, -1.1), 1.1, Color(1.0, 1.0, 1.0, 0.95))
	# Secondary highlight
	draw_circle(l_eye + Vector2(1.1, 0.35), 0.6, Color(1.0, 1.0, 1.0, 0.55))
	draw_circle(r_eye + Vector2(1.1, 0.35), 0.6, Color(1.0, 1.0, 1.0, 0.55))
	# Third tiny sparkle
	draw_circle(l_eye + Vector2(-0.35, 0.85), 0.3, Color(1.0, 1.0, 1.0, 0.35))
	draw_circle(r_eye + Vector2(-0.35, 0.85), 0.3, Color(1.0, 1.0, 1.0, 0.35))
	# Eyelid lines
	draw_arc(l_eye, 3.6, PI + 0.3, TAU - 0.3, 8, Color(0.25, 0.18, 0.12), 1.0)
	draw_arc(r_eye, 3.6, PI + 0.3, TAU - 0.3, 8, Color(0.25, 0.18, 0.12), 1.0)
	# Eyelashes (long, feminine)
	for el in range(3):
		var ela = PI + 0.35 + float(el) * 0.45
		var lash_len = 2.2 + sin(float(el) * 1.2) * 0.4
		draw_line(l_eye + Vector2.from_angle(ela) * 3.6, l_eye + Vector2.from_angle(ela + 0.1) * (3.6 + lash_len), Color(0.2, 0.15, 0.10), 0.8)
		draw_line(r_eye + Vector2.from_angle(ela) * 3.6, r_eye + Vector2.from_angle(ela + 0.1) * (3.6 + lash_len), Color(0.2, 0.15, 0.10), 0.8)
	# Lower lashes
	draw_arc(l_eye, 3.4, -PI * 0.3, PI * 0.3, 6, Color(0.3, 0.22, 0.15, 0.3), 0.6)
	draw_arc(r_eye, 3.4, -PI * 0.3, PI * 0.3, 6, Color(0.3, 0.22, 0.15, 0.3), 0.6)

	# Eyebrows (natural arch, blonde, scaled)
	draw_line(l_eye + Vector2(-2.5, -3.5), l_eye + Vector2(1.1, -4.3), Color(0.6, 0.48, 0.2), 1.4)
	draw_line(r_eye + Vector2(-1.1, -4.3), r_eye + Vector2(2.5, -3.5), Color(0.6, 0.48, 0.2), 1.4)

	# Button nose (scaled: 3.5->2.5, positions adjusted)
	draw_circle(head_center + Vector2(0, 2.5), 1.4, Color(0.92, 0.80, 0.68, 0.4))
	draw_circle(head_center + Vector2(0.2, 2.7), 1.0, Color(0.98, 0.88, 0.78, 0.5))

	# Full curvy lips (prominent, feminine, attractive)
	# Upper lip — defined cupid's bow shape
	draw_arc(head_center + Vector2(0, 4.5), 4.0, 0.1, PI - 0.1, 14, Color(0.85, 0.35, 0.38), 1.8)
	# Cupid's bow dip at center
	draw_line(head_center + Vector2(-1.5, 4.2), head_center + Vector2(0, 4.6), Color(0.82, 0.32, 0.35), 1.2)
	draw_line(head_center + Vector2(0, 4.6), head_center + Vector2(1.5, 4.2), Color(0.82, 0.32, 0.35), 1.2)
	# Lower lip — fuller, rounder, curvier
	draw_arc(head_center + Vector2(0, 5.2), 3.8, -0.2, PI + 0.2, 12, Color(0.90, 0.45, 0.42), 2.0)
	draw_arc(head_center + Vector2(0, 5.5), 3.0, -0.1, PI + 0.1, 10, Color(0.92, 0.52, 0.48, 0.5), 1.5)
	# Lip shine highlight (glossy center)
	draw_circle(head_center + Vector2(0.3, 5.5), 1.2, Color(1.0, 0.78, 0.75, 0.45))
	draw_circle(head_center + Vector2(-0.5, 4.3), 0.8, Color(1.0, 0.80, 0.78, 0.35))
	# Lip corners with slight smile upturn
	draw_line(head_center + Vector2(-3.5, 4.8), head_center + Vector2(-4.5, 4.0), Color(0.82, 0.40, 0.38, 0.35), 0.8)
	draw_line(head_center + Vector2(3.5, 4.8), head_center + Vector2(4.5, 4.0), Color(0.82, 0.40, 0.38, 0.35), 0.8)
	# Lip line between upper and lower
	draw_line(head_center + Vector2(-3.2, 4.8), head_center + Vector2(3.2, 4.8), Color(0.75, 0.30, 0.32, 0.3), 0.6)

	# === T2+: Floating Cheshire Cat grin ===
	if upgrade_tier >= 2:
		var grin_float = sin(_time * 2.2) * 5.0
		var grin_bob = cos(_time * 1.7) * 3.5
		var grin_pos = body_offset + Vector2(28.0 + grin_bob, -8.0 + grin_float)
		# Fading body outline (ghostly stripes)
		var gbody_alpha = 0.12 + sin(_time * 1.5) * 0.04
		draw_arc(grin_pos, 14.0, PI * 0.1, PI * 0.9, 10, Color(0.6, 0.3, 0.7, gbody_alpha), 1.5)
		for gsi in range(3):
			var gs_a = PI * 0.25 + float(gsi) * 0.25
			var gs_s = grin_pos + Vector2.from_angle(gs_a) * 10.0
			var gs_e = grin_pos + Vector2.from_angle(gs_a) * 16.0
			draw_line(gs_s, gs_e, Color(0.55, 0.25, 0.65, gbody_alpha * 0.6), 1.5)
		# Grin arc (wide purple smile)
		draw_arc(grin_pos, 10.0, 0.2, PI - 0.2, 14, Color(0.7, 0.3, 0.8, 0.7), 3.5)
		draw_arc(grin_pos, 8.0, 0.3, PI - 0.3, 10, Color(0.85, 0.4, 0.55, 0.25), 2.0)
		# Teeth
		for gti in range(6):
			var tooth_a = 0.3 + float(gti) * 0.4
			var tooth_s = grin_pos + Vector2.from_angle(tooth_a) * 7.5
			var tooth_e = grin_pos + Vector2.from_angle(tooth_a) * 12.0
			draw_line(tooth_s, tooth_e, Color(0.97, 0.97, 0.92, 0.55), 1.8)
		# Cheshire eyes (glowing yellow-green)
		var eye_glow = 0.5 + sin(_time * 3.0) * 0.1
		draw_circle(grin_pos + Vector2(-6, -7), 3.5, Color(0.85, 0.8, 0.2, eye_glow))
		draw_circle(grin_pos + Vector2(6, -7), 3.5, Color(0.85, 0.8, 0.2, eye_glow))
		draw_circle(grin_pos + Vector2(-6, -7), 2.0, Color(0.95, 0.9, 0.3, eye_glow * 0.5))
		draw_circle(grin_pos + Vector2(6, -7), 2.0, Color(0.95, 0.9, 0.3, eye_glow * 0.5))
		# Cat eye slits
		draw_line(grin_pos + Vector2(-6, -9), grin_pos + Vector2(-6, -5), Color(0.15, 0.08, 0.2, eye_glow), 1.5)
		draw_line(grin_pos + Vector2(6, -9), grin_pos + Vector2(6, -5), Color(0.15, 0.08, 0.2, eye_glow), 1.5)
		# Whiskers
		draw_line(grin_pos + Vector2(10, -4), grin_pos + Vector2(16, -2), Color(0.6, 0.3, 0.7, 0.15), 0.7)
		draw_line(grin_pos + Vector2(10, -6), grin_pos + Vector2(16, -7), Color(0.6, 0.3, 0.7, 0.15), 0.7)
		draw_line(grin_pos + Vector2(-10, -4), grin_pos + Vector2(-16, -2), Color(0.6, 0.3, 0.7, 0.15), 0.7)
		draw_line(grin_pos + Vector2(-10, -6), grin_pos + Vector2(-16, -7), Color(0.6, 0.3, 0.7, 0.15), 0.7)

	# === T3+: Orbiting teacups with steam ===
	if upgrade_tier >= 3:
		for cup_i in range(3):
			var cup_angle = _time * 0.6 + float(cup_i) * TAU / 3.0
			var cup_r = 38.0 + sin(_time * 1.2 + float(cup_i)) * 4.0
			var cup_pos = Vector2.from_angle(cup_angle) * cup_r
			var cup_bob = sin(_time * 2.0 + float(cup_i) * 1.5) * 2.5
			cup_pos.y += cup_bob
			# Saucer
			draw_arc(cup_pos + Vector2(0, 3), 8.0, 0.2, PI - 0.2, 8, Color(0.88, 0.85, 0.78), 2.0)
			# Cup body
			draw_arc(cup_pos, 6.0, 0.4, PI - 0.4, 8, Color(0.92, 0.88, 0.78), 3.0)
			draw_line(cup_pos + Vector2.from_angle(0.5) * 6.0, cup_pos + Vector2.from_angle(PI - 0.5) * 6.0, Color(0.92, 0.88, 0.78), 1.5)
			# Tea inside
			draw_arc(cup_pos + Vector2(0, -1), 4.0, 0.6, PI - 0.6, 6, Color(0.6, 0.38, 0.18, 0.5), 2.0)
			# Handle
			draw_arc(cup_pos + Vector2(7, 0), 3.0, -PI * 0.4, PI * 0.4, 6, Color(0.88, 0.85, 0.78), 1.5)
			# Gold rim
			draw_arc(cup_pos, 6.5, 0.35, PI - 0.35, 6, Color(0.85, 0.75, 0.3, 0.35), 0.8)
			# Steam wisps
			for stm in range(2):
				var steam_off = sin(_time * 2.0 + float(cup_i) * 2.0 + float(stm) * 1.5) * 2.5
				var steam_p = cup_pos + Vector2(steam_off, -10.0 - float(stm) * 5.0)
				draw_circle(steam_p, 2.5 - float(stm) * 0.4, Color(0.92, 0.92, 0.95, 0.25 - float(stm) * 0.08))

	# === Tier 4: Crown of card suits floating above head ===
	if upgrade_tier >= 4:
		var crown_hover = sin(_time * 1.8) * 1.5
		var crown_center = head_center + Vector2(0, -12 + crown_hover)
		var crown_r = 12.0
		# Golden band
		draw_arc(crown_center, crown_r, 0, TAU, 20, Color(0.95, 0.82, 0.2), 3.5)
		draw_arc(crown_center, crown_r + 1.2, 0, TAU, 20, Color(0.85, 0.72, 0.15, 0.35), 0.8)
		draw_arc(crown_center, crown_r - 1.2, 0, TAU, 20, Color(1.0, 0.92, 0.4, 0.25), 0.8)
		# Crown spikes with suit gems
		for csi in range(5):
			var ca = PI * 0.5 + (float(csi) - 2.0) * 0.35
			var spike_base_pos = crown_center + Vector2.from_angle(ca) * (crown_r - 1.5)
			var spike_tip = crown_center + Vector2.from_angle(ca) * (crown_r + 10.0)
			draw_line(spike_base_pos, spike_tip, Color(0.95, 0.82, 0.2), 3.0)
			draw_line(spike_base_pos + Vector2.from_angle(ca + PI * 0.5) * 2.5, spike_tip, Color(0.95, 0.82, 0.2), 1.2)
			draw_line(spike_base_pos - Vector2.from_angle(ca + PI * 0.5) * 2.5, spike_tip, Color(0.95, 0.82, 0.2), 1.2)
			var suit_col = Color(0.95, 0.15, 0.15) if csi % 2 == 0 else Color(0.1, 0.1, 0.12)
			draw_circle(spike_tip, 2.8, suit_col)
			draw_circle(spike_tip + Vector2(-0.5, -0.5), 1.0, Color(1.0, 0.8, 0.8, 0.4) if csi % 2 == 0 else Color(0.45, 0.45, 0.5, 0.4))
		# Band jewels
		for ji in range(6):
			var ja = TAU * float(ji) / 6.0
			var jp = crown_center + Vector2.from_angle(ja) * crown_r
			draw_circle(jp, 1.5, Color(0.9, 0.15, 0.15, 0.5) if ji % 2 == 0 else Color(0.2, 0.5, 0.9, 0.5))

	# Reset transform for UI text
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	# Awaiting ability choice indicator
	if awaiting_ability_choice:
		var pulse = (sin(_time * 4.0) + 1.0) * 0.5
		draw_circle(Vector2.ZERO, 60.0 + pulse * 6.0, Color(0.8, 0.7, 1.0, 0.1 + pulse * 0.1))
		draw_arc(Vector2.ZERO, 60.0 + pulse * 6.0, 0, TAU, 32, Color(0.8, 0.7, 1.0, 0.3 + pulse * 0.3), 2.5)
		var font3 = ThemeDB.fallback_font
		draw_string(font3, Vector2(-16, -68), "!", HORIZONTAL_ALIGNMENT_CENTER, 32, 30, Color(0.8, 0.7, 1.0, 0.7 + pulse * 0.3))

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
		draw_string(font2, Vector2(-80, -60), _upgrade_name, HORIZONTAL_ALIGNMENT_CENTER, 160, 16, Color(0.8, 0.7, 1.0, min(_upgrade_flash, 1.0)))
