extends PathFollow2D
## Enemy — walks along the path, takes damage, rewards gold on death.
## Supports slow and damage-over-time debuffs.
## Themed visuals based on enemy_theme (level) and enemy_tier (wave progress).

var speed: float = 100.0
var max_health: float = 100.0
var health: float = 100.0
var gold_reward: int = 10
var _hit_flash: float = 0.0

# Debuffs
var slow_factor: float = 1.0
var slow_timer: float = 0.0
var dot_dps: float = 0.0
var dot_timer: float = 0.0
var is_shrunk: bool = false

# Mark (damage multiplier from Scrooge's ghosts)
var damage_mult: float = 1.0
var mark_timer: float = 0.0
var fear_slow: bool = false

# Ability status effects
var sleep_timer: float = 0.0
var charm_timer: float = 0.0
var charm_damage_mult: float = 1.0
var paint_stacks: int = 0
var painted_red: bool = false
var fear_reverse_timer: float = 0.0
var permanent_slow_mult: float = 1.0
var chain_group: Array = []
var chain_timer: float = 0.0
var chain_share: float = 0.0
var cheshire_mark_timer: float = 0.0
var cheshire_mark_mult: float = 1.0
var melt_timer: float = 0.0
var melt_rate: float = 0.0

# Themed visuals
var enemy_theme: int = 0
var enemy_tier: int = 0
var shrink_scale: float = 1.0
var boss_scale: float = 1.0  # >1.0 for boss enemies (drawn bigger)

# Wound state visuals
var _wound_drip_offsets: Array = []
var _wound_crack_lines: Array = []
var _wound_time: float = 0.0

# Modifiers (Cursed Passages)
var modifiers: Array = []
var bound_shield: float = 0.0
var _hex_regen_accum: float = 0.0
var _game_font: Font

func _ready() -> void:
	var _ff := FontFile.new()
	_ff.data = FileAccess.get_file_as_bytes("res://fonts/Cinzel.ttf")
	_game_font = _ff
	health = max_health
	rotates = false
	# Generate random wound positions using instance id as seed
	var seed_val = get_instance_id()
	for i in range(5):
		_wound_drip_offsets.append(Vector2(
			fmod(float(seed_val * (i + 1) * 7), 16.0) - 8.0,
			8.0 + fmod(float(seed_val * (i + 1) * 13), 8.0)
		))
	for i in range(4):
		_wound_crack_lines.append({
			"from": Vector2(fmod(float(seed_val * (i + 1) * 11), 20.0) - 10.0, fmod(float(seed_val * (i + 1) * 3), 20.0) - 10.0),
			"to": Vector2(fmod(float(seed_val * (i + 2) * 17), 20.0) - 10.0, fmod(float(seed_val * (i + 2) * 5), 20.0) - 10.0)
		})

func _process(delta: float) -> void:
	_wound_time += delta
	# Sleep — completely frozen
	if sleep_timer > 0.0:
		sleep_timer -= delta
		if _hit_flash > 0.0:
			_hit_flash -= delta
		queue_redraw()
		return

	# Charm — frozen + takes extra damage
	if charm_timer > 0.0:
		charm_timer -= delta
		if charm_timer <= 0.0:
			charm_damage_mult = 1.0
		if _hit_flash > 0.0:
			_hit_flash -= delta
		queue_redraw()
		return

	# Melt effect — lose HP over time
	if melt_timer > 0.0:
		melt_timer -= delta
		health -= melt_rate * delta
		_hit_flash = 0.05
		if health <= 0.0:
			_die()
			return

	# Hexed modifier — regen 2% max HP per second
	if "hexed" in modifiers:
		_hex_regen_accum += delta
		if _hex_regen_accum >= 0.5:
			health = min(health + max_health * 0.01, max_health)
			_hex_regen_accum -= 0.5

	# Cheshire mark timer
	if cheshire_mark_timer > 0.0:
		cheshire_mark_timer -= delta
		if cheshire_mark_timer <= 0.0:
			cheshire_mark_mult = 1.0

	# Chain timer
	if chain_timer > 0.0:
		chain_timer -= delta
		if chain_timer <= 0.0:
			chain_group.clear()
			chain_share = 0.0

	# Fear reverse — walk backwards
	if fear_reverse_timer > 0.0:
		fear_reverse_timer -= delta
		progress -= speed * 0.5 * permanent_slow_mult * delta
		progress = max(0.0, progress)
	# Normal movement with slow
	elif slow_timer > 0.0:
		slow_timer -= delta
		progress += speed * slow_factor * permanent_slow_mult * delta
		is_shrunk = true
	else:
		slow_factor = 1.0
		is_shrunk = false
		progress += speed * permanent_slow_mult * delta

	# Mark timer
	if mark_timer > 0.0:
		mark_timer -= delta
		if mark_timer <= 0.0:
			damage_mult = 1.0
			fear_slow = false

	# Fear slow (Ghost of Christmas Yet to Come)
	if fear_slow and slow_timer <= 0.0:
		slow_factor = 0.7
		slow_timer = 0.5

	# Damage over time
	if dot_timer > 0.0:
		dot_timer -= delta
		health -= dot_dps * delta
		_hit_flash = 0.05
		if health <= 0.0:
			_die()
			return

	if _hit_flash > 0.0:
		_hit_flash -= delta

	if progress_ratio >= 1.0:
		var main = get_tree().get_first_node_in_group("main")
		if main:
			main.lose_life()
			main.enemy_died()
		queue_free()
		return

	shrink_scale = 0.7 if is_shrunk else 1.0
	queue_redraw()

func take_damage(amount: float, is_magic: bool = false) -> void:
	var mult = damage_mult * cheshire_mark_mult * charm_damage_mult
	var paint_mult = 1.0 + paint_stacks * 0.05
	var final_dmg = amount * mult * paint_mult
	# Spectral: physical attacks deal 50% damage
	if "spectral" in modifiers and not is_magic:
		final_dmg *= 0.5
	# Bound: shield absorbs damage first
	if bound_shield > 0.0:
		if final_dmg <= bound_shield:
			bound_shield -= final_dmg
			_hit_flash = 0.12
			return
		else:
			final_dmg -= bound_shield
			bound_shield = 0.0
	health -= final_dmg
	_hit_flash = 0.12
	# Floating damage number
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("spawn_damage_number"):
		main.spawn_damage_number(global_position, final_dmg, boss_scale > 1.0)
	# Chain damage sharing
	if chain_timer > 0.0 and chain_share > 0.0 and chain_group.size() > 0:
		var shared = final_dmg * chain_share
		for linked in chain_group:
			if is_instance_valid(linked) and linked != self:
				linked.take_chain_damage(shared)
	if health <= 0.0:
		_die()

func take_chain_damage(amount: float) -> void:
	health -= amount
	_hit_flash = 0.08
	if health <= 0.0:
		_die()

func apply_slow(factor: float, duration: float) -> void:
	if factor < slow_factor:
		slow_factor = factor
	slow_timer = max(slow_timer, duration)

func apply_dot(dps: float, duration: float) -> void:
	dot_dps = max(dot_dps, dps)
	dot_timer = max(dot_timer, duration)

func apply_mark(mult: float, duration: float, with_fear: bool = false) -> void:
	damage_mult = max(damage_mult, mult)
	mark_timer = max(mark_timer, duration)
	if with_fear:
		fear_slow = true

func apply_sleep(duration: float) -> void:
	sleep_timer = max(sleep_timer, duration)

func apply_charm(duration: float, dmg_mult: float = 2.0) -> void:
	charm_timer = max(charm_timer, duration)
	charm_damage_mult = max(charm_damage_mult, dmg_mult)

func apply_paint() -> void:
	paint_stacks = mini(paint_stacks + 1, 10)

func apply_fear_reverse(duration: float) -> void:
	fear_reverse_timer = max(fear_reverse_timer, duration)

func apply_cheshire_mark(duration: float, mult: float = 2.0) -> void:
	cheshire_mark_timer = max(cheshire_mark_timer, duration)
	cheshire_mark_mult = max(cheshire_mark_mult, mult)

func apply_chain(targets: Array, share_pct: float, duration: float) -> void:
	chain_group = targets
	chain_share = share_pct
	chain_timer = max(chain_timer, duration)

func apply_melt(rate: float, duration: float) -> void:
	melt_rate = rate
	melt_timer = max(melt_timer, duration)

func apply_permanent_slow(mult: float) -> void:
	permanent_slow_mult = min(permanent_slow_mult, mult)

func _die() -> void:
	var main = get_tree().get_first_node_in_group("main")
	if main:
		main.add_gold(gold_reward)
		main.enemy_died()
		if main.has_method("spawn_gold_text"):
			main.spawn_gold_text(global_position, gold_reward)
		if main.has_method("report_enemy_death"):
			main.report_enemy_death(global_position, boss_scale > 1.0, boss_scale)
	queue_free()

func _draw() -> void:
	var s: float = shrink_scale * boss_scale

	var tint: Color = Color.WHITE
	if _hit_flash > 0.0:
		tint = Color(1.0, 1.0, 1.0, 1.0)
	elif painted_red or paint_stacks > 0:
		var ri = clampf(0.3 + float(paint_stacks) * 0.07, 0.3, 0.9)
		tint = Color(1.0, 1.0 - ri, 1.0 - ri, 1.0)  # Painted red!
	elif mark_timer > 0.0:
		tint = Color(0.85, 0.85, 0.95, 0.7)
	elif dot_timer > 0.0:
		tint = Color(0.6, 1.0, 0.6, 1.0)
	elif is_shrunk:
		tint = Color(0.7, 0.7, 1.0, 1.0)

	# Wound alpha fade when critically low HP
	var hp_ratio = health / max_health if max_health > 0.0 else 1.0
	if hp_ratio < 0.25:
		var wound_alpha = 0.4 + hp_ratio * 2.4  # 0.4 at 0%, 1.0 at 25%
		tint.a = min(tint.a, wound_alpha)
	# Spectral modifier — translucent
	if "spectral" in modifiers:
		tint.a *= 0.5

	match enemy_theme:
		0: _draw_sherwood(s, tint)
		1: _draw_wonderland(s, tint)
		2: _draw_oz(s, tint)
		3: _draw_neverland(s, tint)
		4: _draw_opera(s, tint)
		5: _draw_victorian(s, tint)
		6: _draw_shadow_entities(s, tint)
		7: _draw_sherlock(s, tint)
		8: _draw_merlin(s, tint)
		9: _draw_tarzan(s, tint)
		10: _draw_dracula(s, tint)
		11: _draw_frankenstein(s, tint)
		12: _draw_shadow_author(s, tint)

	# Wound effects (bleeding ink)
	_draw_wound_effects(s)
	# Modifier effects (cursed passages)
	_draw_modifier_effects(s)

	# Status effect visuals
	if sleep_timer > 0.0:
		# Zzz floating above
		draw_string(_game_font, Vector2(-8, -32 * s), "ZZZ", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.6, 0.6, 1.0, 0.8))
	if charm_timer > 0.0:
		# Hearts above
		draw_circle(Vector2(-6, -30 * s), 3.0, Color(1.0, 0.3, 0.5, 0.7))
		draw_circle(Vector2(6, -32 * s), 2.5, Color(1.0, 0.4, 0.6, 0.6))
	if paint_stacks > 0:
		# Progressive red tint overlay
		var red_alpha = float(paint_stacks) * 0.04
		draw_circle(Vector2.ZERO, 14.0 * s, Color(0.9, 0.1, 0.1, red_alpha))
	if fear_reverse_timer > 0.0:
		# Reverse arrows
		draw_line(Vector2(-8, -28 * s), Vector2(-12, -28 * s), Color(1.0, 0.3, 0.3, 0.7), 2.0)
		draw_line(Vector2(-12, -28 * s), Vector2(-10, -30 * s), Color(1.0, 0.3, 0.3, 0.7), 2.0)
		draw_line(Vector2(-12, -28 * s), Vector2(-10, -26 * s), Color(1.0, 0.3, 0.3, 0.7), 2.0)
	if cheshire_mark_timer > 0.0:
		# Floating grin
		draw_arc(Vector2(0, -28 * s), 6.0, 0.3, PI - 0.3, 8, Color(0.7, 0.3, 0.9, 0.7), 1.5)
	if chain_timer > 0.0:
		# Chain link indicator
		draw_arc(Vector2.ZERO, 16.0 * s, 0, TAU, 12, Color(0.5, 0.5, 0.6, 0.4), 1.5)
	if melt_timer > 0.0:
		# Green drip
		draw_circle(Vector2(-4, 12 * s), 2.0, Color(0.2, 0.8, 0.1, 0.5))
		draw_circle(Vector2(3, 14 * s), 1.5, Color(0.2, 0.8, 0.1, 0.4))

	# Health bar
	var bar_w: float = 28.0 * boss_scale
	var bar_h: float = 4.0 + (boss_scale - 1.0) * 2.0
	var bar_y: float = -26.0 * s - 4.0
	draw_rect(Rect2(-bar_w / 2, bar_y, bar_w, bar_h), Color(0.15, 0.15, 0.15))
	var ratio = clamp(health / max_health, 0.0, 1.0)
	var bar_color: Color
	if ratio > 0.55:
		bar_color = Color(0.2, 0.85, 0.2)
	elif ratio > 0.25:
		bar_color = Color(0.95, 0.85, 0.15)
	else:
		bar_color = Color(0.95, 0.2, 0.15)
	draw_rect(Rect2(-bar_w / 2, bar_y, bar_w * ratio, bar_h), bar_color)


func _apply_tint(base: Color, tint: Color) -> Color:
	if tint == Color.WHITE:
		return base
	if tint.a < 1.0:
		return Color(base.r * 0.4 + tint.r * 0.6, base.g * 0.4 + tint.g * 0.6, base.b * 0.4 + tint.b * 0.6, tint.a)
	return Color(base.r * 0.5 + tint.r * 0.5, base.g * 0.5 + tint.g * 0.5, base.b * 0.5 + tint.b * 0.5, base.a)


func _draw_heart_symbol(pos: Vector2, size: float, color: Color) -> void:
	draw_circle(pos + Vector2(-size * 0.3, -size * 0.2), size * 0.4, color)
	draw_circle(pos + Vector2(size * 0.3, -size * 0.2), size * 0.4, color)
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(0, size * 0.5),
		pos + Vector2(-size * 0.55, -size * 0.1),
		pos + Vector2(size * 0.55, -size * 0.1)
	]), color)


# =============================================================================
# WOUND & MODIFIER EFFECTS
# =============================================================================

func _draw_wound_effects(s: float) -> void:
	var hp_ratio = health / max_health if max_health > 0.0 else 1.0
	if hp_ratio >= 0.75:
		return
	var bs = boss_scale
	# 75% HP: ink drips below enemy
	if hp_ratio < 0.75:
		for i in range(2):
			var off = _wound_drip_offsets[i] * bs
			var drip_y = off.y + sin(_wound_time * 2.0 + float(i)) * 3.0
			draw_circle(Vector2(off.x * s, drip_y * s), (2.0 + float(i)) * bs, Color(0.08, 0.06, 0.12, 0.6))
	# 50% HP: dark crack lines across sprite
	if hp_ratio < 0.5:
		var crack_count = 2 if hp_ratio > 0.3 else 4
		for i in range(crack_count):
			if i < _wound_crack_lines.size():
				var cl = _wound_crack_lines[i]
				draw_line(cl["from"] * s * bs, cl["to"] * s * bs, Color(0.05, 0.03, 0.08, 0.7), 1.5 * bs)
	# 25% HP: ink splatter orbiting + more drips
	if hp_ratio < 0.25:
		for i in range(5):
			var angle = _wound_time * 1.5 + float(i) * TAU / 5.0
			var orbit_r = 14.0 * s * bs
			var px = cos(angle) * orbit_r
			var py = sin(angle) * orbit_r
			draw_circle(Vector2(px, py), 1.5 * bs, Color(0.06, 0.04, 0.1, 0.5))

func _draw_modifier_effects(s: float) -> void:
	if modifiers.is_empty():
		return
	var bs = boss_scale
	# Spectral: shimmer circle
	if "spectral" in modifiers:
		var shimmer_a = 0.15 + sin(_wound_time * 3.0) * 0.1
		draw_arc(Vector2.ZERO, 16.0 * s, 0, TAU, 16, Color(0.6, 0.7, 1.0, shimmer_a), 1.5 * bs)
	# Ironbound: metallic ring + rivets
	if "ironbound" in modifiers:
		draw_arc(Vector2.ZERO, 18.0 * s, PI * 0.2, PI * 1.8, 12, Color(0.6, 0.6, 0.65, 0.5), 2.0 * bs)
		for i in range(4):
			var a = _wound_time * 0.5 + float(i) * TAU / 4.0
			var rx = cos(a) * 18.0 * s
			var ry = sin(a) * 18.0 * s
			draw_circle(Vector2(rx, ry), 1.5 * bs, Color(0.7, 0.7, 0.75, 0.6))
	# Hexed: purple hex symbol above
	if "hexed" in modifiers:
		var hex_y = -30.0 * s
		var hex_float = sin(_wound_time * 2.0) * 2.0
		var hex_pos = Vector2(0, hex_y + hex_float)
		for i in range(6):
			var a1 = float(i) * TAU / 6.0 - PI / 2.0
			var a2 = float(i + 1) * TAU / 6.0 - PI / 2.0
			draw_line(hex_pos + Vector2(cos(a1), sin(a1)) * 4.0 * bs, hex_pos + Vector2(cos(a2), sin(a2)) * 4.0 * bs, Color(0.6, 0.2, 0.8, 0.7), 1.0)
	# Bound: pulsing cyan barrier
	if "bound" in modifiers and bound_shield > 0.0:
		var shield_a = 0.3 + sin(_wound_time * 4.0) * 0.15
		draw_arc(Vector2.ZERO, 20.0 * s, -PI * 0.4, PI * 0.4, 10, Color(0.2, 0.8, 0.9, shield_a), 2.5 * bs)
		draw_arc(Vector2.ZERO, 20.0 * s, PI * 0.6, PI * 1.4, 10, Color(0.2, 0.8, 0.9, shield_a), 2.5 * bs)


# =============================================================================
# LEVEL 0 — SHERWOOD FOREST
# =============================================================================

func _draw_sherwood(s: float, tint: Color) -> void:
	match enemy_tier:
		0: _draw_tax_collector(s, tint)
		1: _draw_sheriff_soldier(s, tint)
		2: _draw_sheriff_knight(s, tint)
		3: _draw_sheriff_boss(s, tint)

func _draw_tax_collector(s: float, tint: Color) -> void:
	var robe_color := _apply_tint(Color(0.55, 0.55, 0.5), tint)
	var skin_color := _apply_tint(Color(0.85, 0.72, 0.6), tint)
	var purse_color := _apply_tint(Color(0.6, 0.5, 0.2), tint)
	var coin_color := _apply_tint(Color(0.9, 0.8, 0.2), tint)
	draw_rect(Rect2(-7 * s, -8 * s, 14 * s, 20 * s), robe_color)
	draw_rect(Rect2(-9 * s, 6 * s, 18 * s, 6 * s), robe_color)
	draw_circle(Vector2(0, -14 * s), 7 * s, skin_color)
	draw_circle(Vector2(-2.5 * s, -15 * s), 1.2 * s, Color(0.15, 0.15, 0.15))
	draw_circle(Vector2(2.5 * s, -15 * s), 1.2 * s, Color(0.15, 0.15, 0.15))
	draw_rect(Rect2(6 * s, -4 * s, 6 * s, 8 * s), purse_color)
	draw_circle(Vector2(9 * s, -5 * s), 2 * s, coin_color)
	draw_circle(Vector2(11 * s, -3 * s), 1.5 * s, coin_color)
	draw_rect(Rect2(-7 * s, 12 * s, 5 * s, 3 * s), Color(0.3, 0.25, 0.2))
	draw_rect(Rect2(2 * s, 12 * s, 5 * s, 3 * s), Color(0.3, 0.25, 0.2))

func _draw_sheriff_soldier(s: float, tint: Color) -> void:
	var mail_color := _apply_tint(Color(0.6, 0.6, 0.65), tint)
	var skin_color := _apply_tint(Color(0.82, 0.7, 0.58), tint)
	var sword_color := _apply_tint(Color(0.78, 0.78, 0.82), tint)
	var helmet_color := _apply_tint(Color(0.5, 0.5, 0.55), tint)
	draw_rect(Rect2(-8 * s, -8 * s, 16 * s, 20 * s), mail_color)
	for row in range(4):
		for col in range(4):
			draw_circle(Vector2(-6 * s + col * 4 * s, -6 * s + row * 5 * s), 0.8 * s, _apply_tint(Color(0.5, 0.5, 0.55), tint))
	draw_circle(Vector2(0, -14 * s), 7 * s, skin_color)
	draw_arc(Vector2(0, -14 * s), 7.5 * s, PI, 0, 16, helmet_color, 2.0 * s)
	draw_line(Vector2(0, -18 * s), Vector2(0, -13 * s), helmet_color, 1.5 * s)
	draw_circle(Vector2(-2.5 * s, -14.5 * s), 1.0 * s, Color(0.15, 0.15, 0.15))
	draw_circle(Vector2(2.5 * s, -14.5 * s), 1.0 * s, Color(0.15, 0.15, 0.15))
	draw_line(Vector2(10 * s, -10 * s), Vector2(10 * s, 8 * s), sword_color, 1.5 * s)
	draw_line(Vector2(7 * s, -4 * s), Vector2(13 * s, -4 * s), _apply_tint(Color(0.45, 0.3, 0.15), tint), 2.0 * s)
	draw_rect(Rect2(-6 * s, 12 * s, 5 * s, 4 * s), mail_color)
	draw_rect(Rect2(1 * s, 12 * s, 5 * s, 4 * s), mail_color)

func _draw_sheriff_knight(s: float, tint: Color) -> void:
	var plate_color := _apply_tint(Color(0.55, 0.55, 0.6), tint)
	var plate_light := _apply_tint(Color(0.7, 0.7, 0.75), tint)
	var shield_color := _apply_tint(Color(0.6, 0.15, 0.15), tint)
	var visor_color := _apply_tint(Color(0.35, 0.35, 0.4), tint)
	draw_rect(Rect2(-10 * s, -10 * s, 20 * s, 22 * s), plate_color)
	draw_rect(Rect2(-6 * s, -8 * s, 12 * s, 18 * s), plate_light)
	draw_circle(Vector2(-10 * s, -8 * s), 4 * s, plate_color)
	draw_circle(Vector2(10 * s, -8 * s), 4 * s, plate_color)
	draw_circle(Vector2(0, -16 * s), 8 * s, plate_color)
	draw_line(Vector2(-4 * s, -16 * s), Vector2(4 * s, -16 * s), visor_color, 2.0 * s)
	draw_line(Vector2(0, -18 * s), Vector2(0, -14 * s), visor_color, 1.0 * s)
	draw_rect(Rect2(-15 * s, -6 * s, 8 * s, 12 * s), shield_color)
	draw_rect(Rect2(-14 * s, -5 * s, 6 * s, 10 * s), _apply_tint(Color(0.7, 0.2, 0.2), tint))
	draw_line(Vector2(-11 * s, -5 * s), Vector2(-11 * s, 4 * s), _apply_tint(Color(0.9, 0.85, 0.3), tint), 1.5 * s)
	draw_line(Vector2(-14 * s, 0), Vector2(-8 * s, 0), _apply_tint(Color(0.9, 0.85, 0.3), tint), 1.5 * s)
	draw_rect(Rect2(-7 * s, 12 * s, 6 * s, 5 * s), plate_color)
	draw_rect(Rect2(1 * s, 12 * s, 6 * s, 5 * s), plate_color)

func _draw_sheriff_boss(s: float, tint: Color) -> void:
	var bs: float = s * 1.4
	var armor_color := _apply_tint(Color(0.75, 0.65, 0.2), tint)
	var armor_dark := _apply_tint(Color(0.6, 0.5, 0.15), tint)
	var cape_color := _apply_tint(Color(0.7, 0.1, 0.1), tint)
	var skin_color := _apply_tint(Color(0.82, 0.7, 0.58), tint)
	var crown_color := _apply_tint(Color(0.95, 0.85, 0.15), tint)
	draw_colored_polygon(PackedVector2Array([Vector2(-8 * bs, -10 * bs), Vector2(8 * bs, -10 * bs), Vector2(12 * bs, 16 * bs), Vector2(-12 * bs, 16 * bs)]), cape_color)
	draw_rect(Rect2(-9 * bs, -8 * bs, 18 * bs, 20 * bs), armor_color)
	draw_line(Vector2(-5 * bs, -6 * bs), Vector2(-5 * bs, 10 * bs), armor_dark, 1.0 * bs)
	draw_line(Vector2(5 * bs, -6 * bs), Vector2(5 * bs, 10 * bs), armor_dark, 1.0 * bs)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -6 * bs), Vector2(4 * bs, -1 * bs), Vector2(0, 4 * bs), Vector2(-4 * bs, -1 * bs)]), _apply_tint(Color(0.85, 0.75, 0.15), tint))
	draw_circle(Vector2(0, -15 * bs), 8 * bs, skin_color)
	draw_circle(Vector2(-3 * bs, -16 * bs), 1.2 * bs, Color(0.15, 0.15, 0.15))
	draw_circle(Vector2(3 * bs, -16 * bs), 1.2 * bs, Color(0.15, 0.15, 0.15))
	draw_line(Vector2(-5 * bs, -18 * bs), Vector2(-1.5 * bs, -17.5 * bs), Color(0.15, 0.15, 0.15), 1.0 * bs)
	draw_line(Vector2(5 * bs, -18 * bs), Vector2(1.5 * bs, -17.5 * bs), Color(0.15, 0.15, 0.15), 1.0 * bs)
	draw_rect(Rect2(-6 * bs, -23 * bs, 12 * bs, 4 * bs), crown_color)
	draw_colored_polygon(PackedVector2Array([Vector2(-6 * bs, -23 * bs), Vector2(-4 * bs, -27 * bs), Vector2(-2 * bs, -23 * bs)]), crown_color)
	draw_colored_polygon(PackedVector2Array([Vector2(-2 * bs, -23 * bs), Vector2(0, -28 * bs), Vector2(2 * bs, -23 * bs)]), crown_color)
	draw_colored_polygon(PackedVector2Array([Vector2(2 * bs, -23 * bs), Vector2(4 * bs, -27 * bs), Vector2(6 * bs, -23 * bs)]), crown_color)
	draw_circle(Vector2(-3 * bs, -22 * bs), 1.0 * bs, _apply_tint(Color(0.9, 0.15, 0.15), tint))
	draw_circle(Vector2(0, -22 * bs), 1.0 * bs, _apply_tint(Color(0.2, 0.2, 0.9), tint))
	draw_circle(Vector2(3 * bs, -22 * bs), 1.0 * bs, _apply_tint(Color(0.15, 0.85, 0.15), tint))
	draw_rect(Rect2(-6 * bs, 12 * bs, 5 * bs, 5 * bs), _apply_tint(Color(0.3, 0.3, 0.3), tint))
	draw_rect(Rect2(1 * bs, 12 * bs, 5 * bs, 5 * bs), _apply_tint(Color(0.3, 0.3, 0.3), tint))


# =============================================================================
# LEVEL 1 — WONDERLAND
# =============================================================================

func _draw_wonderland(s: float, tint: Color) -> void:
	match enemy_tier:
		0: _draw_card_soldier(s, tint)
		1: _draw_face_card_guard(s, tint)
		2: _draw_jabberwock(s, tint)
		3: _draw_queen_of_hearts(s, tint)

func _draw_card_soldier(s: float, tint: Color) -> void:
	var card_color := _apply_tint(Color(0.95, 0.93, 0.88), tint)
	var border_color := _apply_tint(Color(0.2, 0.2, 0.2), tint)
	var suit_color := _apply_tint(Color(0.85, 0.1, 0.1), tint)
	draw_rect(Rect2(-8 * s, -18 * s, 16 * s, 32 * s), card_color)
	draw_rect(Rect2(-8 * s, -18 * s, 16 * s, 32 * s), border_color, false, 1.0 * s)
	draw_colored_polygon(PackedVector2Array([Vector2(0, 4 * s), Vector2(-3 * s, 0), Vector2(0, -2 * s), Vector2(3 * s, 0)]), suit_color)
	draw_circle(Vector2(-1.5 * s, -1 * s), 2 * s, suit_color)
	draw_circle(Vector2(1.5 * s, -1 * s), 2 * s, suit_color)
	draw_circle(Vector2(-3 * s, -2 * s), 1.0 * s, Color(0.15, 0.15, 0.15))
	draw_circle(Vector2(3 * s, -2 * s), 1.0 * s, Color(0.15, 0.15, 0.15))
	draw_rect(Rect2(-5 * s, 14 * s, 4 * s, 3 * s), _apply_tint(Color(0.7, 0.1, 0.1), tint))
	draw_rect(Rect2(1 * s, 14 * s, 4 * s, 3 * s), _apply_tint(Color(0.7, 0.1, 0.1), tint))

func _draw_face_card_guard(s: float, tint: Color) -> void:
	var card_color := _apply_tint(Color(0.95, 0.9, 0.8), tint)
	var border_color := _apply_tint(Color(0.15, 0.15, 0.15), tint)
	var royal_color := _apply_tint(Color(0.85, 0.15, 0.15), tint)
	var gold_color := _apply_tint(Color(0.9, 0.8, 0.2), tint)
	draw_rect(Rect2(-9 * s, -19 * s, 18 * s, 34 * s), card_color)
	draw_rect(Rect2(-9 * s, -19 * s, 18 * s, 34 * s), border_color, false, 1.2 * s)
	draw_circle(Vector2(0, -8 * s), 5 * s, _apply_tint(Color(0.85, 0.72, 0.6), tint))
	draw_colored_polygon(PackedVector2Array([Vector2(-4 * s, -14 * s), Vector2(-3 * s, -17 * s), Vector2(-1 * s, -15 * s), Vector2(0, -18 * s), Vector2(1 * s, -15 * s), Vector2(3 * s, -17 * s), Vector2(4 * s, -14 * s)]), gold_color)
	draw_circle(Vector2(-2 * s, -9 * s), 1.0 * s, Color(0.15, 0.15, 0.15))
	draw_circle(Vector2(2 * s, -9 * s), 1.0 * s, Color(0.15, 0.15, 0.15))
	draw_line(Vector2(10 * s, -16 * s), Vector2(10 * s, 12 * s), _apply_tint(Color(0.5, 0.35, 0.2), tint), 1.5 * s)
	draw_colored_polygon(PackedVector2Array([Vector2(10 * s, -20 * s), Vector2(8 * s, -16 * s), Vector2(12 * s, -16 * s)]), _apply_tint(Color(0.7, 0.7, 0.75), tint))
	draw_rect(Rect2(-5 * s, 15 * s, 4 * s, 3 * s), royal_color)
	draw_rect(Rect2(1 * s, 15 * s, 4 * s, 3 * s), royal_color)

func _draw_jabberwock(s: float, tint: Color) -> void:
	var body_color := _apply_tint(Color(0.35, 0.55, 0.25), tint)
	var belly_color := _apply_tint(Color(0.55, 0.7, 0.35), tint)
	var wing_color := _apply_tint(Color(0.5, 0.25, 0.6), tint)
	var eye_color := _apply_tint(Color(0.95, 0.8, 0.1), tint)
	draw_line(Vector2(-10 * s, 8 * s), Vector2(-15 * s, 2 * s), body_color, 2.5 * s)
	draw_line(Vector2(-15 * s, 2 * s), Vector2(-18 * s, 5 * s), body_color, 1.5 * s)
	draw_rect(Rect2(-10 * s, -6 * s, 20 * s, 18 * s), body_color)
	draw_rect(Rect2(-6 * s, -2 * s, 12 * s, 12 * s), belly_color)
	draw_circle(Vector2(0, -12 * s), 7 * s, body_color)
	draw_rect(Rect2(-2 * s, -16 * s, 8 * s, 6 * s), body_color)
	draw_circle(Vector2(5 * s, -14 * s), 3 * s, _apply_tint(Color(0.3, 0.5, 0.2), tint))
	draw_circle(Vector2(-2 * s, -13 * s), 2.0 * s, eye_color)
	draw_circle(Vector2(2 * s, -13 * s), 2.0 * s, eye_color)
	draw_circle(Vector2(-2 * s, -13 * s), 1.0 * s, Color(0.15, 0.15, 0.15))
	draw_circle(Vector2(2 * s, -13 * s), 1.0 * s, Color(0.15, 0.15, 0.15))
	draw_colored_polygon(PackedVector2Array([Vector2(-8 * s, -4 * s), Vector2(-18 * s, -14 * s), Vector2(-14 * s, -2 * s)]), wing_color)
	draw_colored_polygon(PackedVector2Array([Vector2(8 * s, -4 * s), Vector2(18 * s, -14 * s), Vector2(14 * s, -2 * s)]), wing_color)
	draw_line(Vector2(-5 * s, 12 * s), Vector2(-8 * s, 16 * s), body_color, 1.5 * s)
	draw_line(Vector2(5 * s, 12 * s), Vector2(8 * s, 16 * s), body_color, 1.5 * s)

func _draw_queen_of_hearts(s: float, tint: Color) -> void:
	var bs: float = s * 1.4
	var dress_color := _apply_tint(Color(0.85, 0.1, 0.1), tint)
	var dress_dark := _apply_tint(Color(0.65, 0.05, 0.05), tint)
	var skin_color := _apply_tint(Color(0.9, 0.78, 0.68), tint)
	var crown_color := _apply_tint(Color(0.95, 0.85, 0.15), tint)
	var heart_color := _apply_tint(Color(0.95, 0.15, 0.2), tint)
	draw_colored_polygon(PackedVector2Array([Vector2(-6 * bs, -6 * bs), Vector2(6 * bs, -6 * bs), Vector2(14 * bs, 14 * bs), Vector2(-14 * bs, 14 * bs)]), dress_color)
	draw_line(Vector2(-14 * bs, 14 * bs), Vector2(14 * bs, 14 * bs), dress_dark, 2.0 * bs)
	_draw_heart_symbol(Vector2(0, 4 * bs), 3.0 * bs, heart_color)
	draw_rect(Rect2(-7 * bs, -8 * bs, 14 * bs, 4 * bs), _apply_tint(Color(0.95, 0.92, 0.85), tint))
	draw_circle(Vector2(0, -15 * bs), 8 * bs, skin_color)
	draw_arc(Vector2(0, -12 * bs), 2.5 * bs, 0, PI, 8, heart_color, 1.5 * bs)
	draw_circle(Vector2(-3 * bs, -16 * bs), 1.3 * bs, Color(0.15, 0.15, 0.15))
	draw_circle(Vector2(3 * bs, -16 * bs), 1.3 * bs, Color(0.15, 0.15, 0.15))
	draw_line(Vector2(-5 * bs, -19 * bs), Vector2(-1.5 * bs, -18 * bs), Color(0.15, 0.15, 0.15), 1.2 * bs)
	draw_line(Vector2(5 * bs, -19 * bs), Vector2(1.5 * bs, -18 * bs), Color(0.15, 0.15, 0.15), 1.2 * bs)
	draw_rect(Rect2(-6 * bs, -23 * bs, 12 * bs, 4 * bs), crown_color)
	draw_colored_polygon(PackedVector2Array([Vector2(-6 * bs, -23 * bs), Vector2(-4 * bs, -27 * bs), Vector2(-2 * bs, -23 * bs)]), crown_color)
	draw_colored_polygon(PackedVector2Array([Vector2(-1 * bs, -23 * bs), Vector2(0, -28 * bs), Vector2(1 * bs, -23 * bs)]), crown_color)
	draw_colored_polygon(PackedVector2Array([Vector2(2 * bs, -23 * bs), Vector2(4 * bs, -27 * bs), Vector2(6 * bs, -23 * bs)]), crown_color)
	draw_line(Vector2(10 * bs, -12 * bs), Vector2(10 * bs, 8 * bs), crown_color, 1.5 * bs)
	_draw_heart_symbol(Vector2(10 * bs, -14 * bs), 2.5 * bs, heart_color)


# =============================================================================
# LEVEL 2 — LAND OF OZ
# =============================================================================

func _draw_oz(s: float, tint: Color) -> void:
	match enemy_tier:
		0: _draw_winkie_guard(s, tint)
		1: _draw_flying_monkey(s, tint)
		2: _draw_nome_soldier(s, tint)
		3: _draw_nome_king(s, tint)

func _draw_winkie_guard(s: float, tint: Color) -> void:
	var uniform_color := _apply_tint(Color(0.9, 0.8, 0.2), tint)
	var uniform_dark := _apply_tint(Color(0.75, 0.65, 0.15), tint)
	var skin_color := _apply_tint(Color(0.82, 0.7, 0.58), tint)
	draw_rect(Rect2(-7 * s, -8 * s, 14 * s, 20 * s), uniform_color)
	draw_rect(Rect2(-8 * s, 2 * s, 16 * s, 3 * s), uniform_dark)
	draw_circle(Vector2(0, -4 * s), 1.0 * s, uniform_dark)
	draw_circle(Vector2(0, 0), 1.0 * s, uniform_dark)
	draw_circle(Vector2(0, -14 * s), 7 * s, skin_color)
	draw_rect(Rect2(-6 * s, -21 * s, 12 * s, 5 * s), uniform_color)
	draw_rect(Rect2(-8 * s, -17 * s, 16 * s, 2 * s), uniform_dark)
	draw_circle(Vector2(-2.5 * s, -14.5 * s), 1.2 * s, Color(0.15, 0.15, 0.15))
	draw_circle(Vector2(2.5 * s, -14.5 * s), 1.2 * s, Color(0.15, 0.15, 0.15))
	draw_line(Vector2(10 * s, -18 * s), Vector2(10 * s, 14 * s), _apply_tint(Color(0.5, 0.35, 0.2), tint), 1.5 * s)
	draw_colored_polygon(PackedVector2Array([Vector2(10 * s, -22 * s), Vector2(8 * s, -18 * s), Vector2(12 * s, -18 * s)]), _apply_tint(Color(0.7, 0.7, 0.75), tint))
	draw_rect(Rect2(-6 * s, 12 * s, 5 * s, 4 * s), uniform_dark)
	draw_rect(Rect2(1 * s, 12 * s, 5 * s, 4 * s), uniform_dark)

func _draw_flying_monkey(s: float, tint: Color) -> void:
	var body_color := _apply_tint(Color(0.55, 0.35, 0.2), tint)
	var belly_color := _apply_tint(Color(0.72, 0.55, 0.35), tint)
	var wing_color := _apply_tint(Color(0.45, 0.3, 0.18), tint)
	var face_color := _apply_tint(Color(0.75, 0.55, 0.4), tint)
	draw_arc(Vector2(-8 * s, 4 * s), 8 * s, PI * 0.5, PI * 1.5, 12, body_color, 2.0 * s)
	draw_colored_polygon(PackedVector2Array([Vector2(-7 * s, -6 * s), Vector2(-18 * s, -16 * s), Vector2(-12 * s, 0)]), wing_color)
	draw_colored_polygon(PackedVector2Array([Vector2(7 * s, -6 * s), Vector2(18 * s, -16 * s), Vector2(12 * s, 0)]), wing_color)
	draw_rect(Rect2(-7 * s, -6 * s, 14 * s, 16 * s), body_color)
	draw_circle(Vector2(0, 2 * s), 5 * s, belly_color)
	draw_circle(Vector2(0, -12 * s), 7 * s, body_color)
	draw_circle(Vector2(0, -10 * s), 4.5 * s, face_color)
	draw_circle(Vector2(-2.5 * s, -13 * s), 1.5 * s, Color(0.95, 0.95, 0.85))
	draw_circle(Vector2(2.5 * s, -13 * s), 1.5 * s, Color(0.95, 0.95, 0.85))
	draw_circle(Vector2(-2.5 * s, -13 * s), 0.8 * s, Color(0.15, 0.15, 0.15))
	draw_circle(Vector2(2.5 * s, -13 * s), 0.8 * s, Color(0.15, 0.15, 0.15))
	draw_circle(Vector2(-6 * s, -14 * s), 3 * s, body_color)
	draw_circle(Vector2(6 * s, -14 * s), 3 * s, body_color)
	draw_circle(Vector2(0, -18 * s), 3 * s, _apply_tint(Color(0.7, 0.1, 0.1), tint))
	draw_rect(Rect2(-6 * s, 10 * s, 4 * s, 4 * s), body_color)
	draw_rect(Rect2(2 * s, 10 * s, 4 * s, 4 * s), body_color)

func _draw_nome_soldier(s: float, tint: Color) -> void:
	var stone_color := _apply_tint(Color(0.5, 0.48, 0.45), tint)
	var stone_dark := _apply_tint(Color(0.38, 0.36, 0.33), tint)
	var stone_light := _apply_tint(Color(0.62, 0.6, 0.56), tint)
	draw_colored_polygon(PackedVector2Array([Vector2(-8 * s, -8 * s), Vector2(8 * s, -10 * s), Vector2(10 * s, 8 * s), Vector2(6 * s, 12 * s), Vector2(-6 * s, 12 * s), Vector2(-10 * s, 6 * s)]), stone_color)
	draw_circle(Vector2(-3 * s, -2 * s), 3 * s, stone_dark)
	draw_circle(Vector2(4 * s, 2 * s), 2.5 * s, stone_dark)
	draw_circle(Vector2(-1 * s, 6 * s), 2 * s, stone_light)
	draw_colored_polygon(PackedVector2Array([Vector2(-6 * s, -14 * s), Vector2(0, -20 * s), Vector2(6 * s, -14 * s), Vector2(5 * s, -8 * s), Vector2(-5 * s, -8 * s)]), stone_color)
	draw_circle(Vector2(-2.5 * s, -13 * s), 1.5 * s, _apply_tint(Color(0.9, 0.6, 0.1), tint))
	draw_circle(Vector2(2.5 * s, -13 * s), 1.5 * s, _apply_tint(Color(0.9, 0.6, 0.1), tint))
	draw_line(Vector2(9 * s, -8 * s), Vector2(12 * s, 6 * s), stone_dark, 2.5 * s)
	draw_circle(Vector2(12 * s, 6 * s), 3 * s, stone_dark)
	draw_rect(Rect2(-6 * s, 12 * s, 5 * s, 4 * s), stone_dark)
	draw_rect(Rect2(1 * s, 12 * s, 5 * s, 4 * s), stone_dark)

func _draw_nome_king(s: float, tint: Color) -> void:
	var bs: float = s * 1.4
	var stone_color := _apply_tint(Color(0.45, 0.42, 0.38), tint)
	var stone_dark := _apply_tint(Color(0.32, 0.3, 0.28), tint)
	var crystal_color := _apply_tint(Color(0.6, 0.85, 0.9), tint)
	var crown_color := _apply_tint(Color(0.85, 0.75, 0.2), tint)
	draw_colored_polygon(PackedVector2Array([Vector2(-10 * bs, -8 * bs), Vector2(10 * bs, -10 * bs), Vector2(12 * bs, 6 * bs), Vector2(8 * bs, 14 * bs), Vector2(-8 * bs, 14 * bs), Vector2(-12 * bs, 4 * bs)]), stone_color)
	draw_circle(Vector2(-4 * bs, 0), 3.5 * bs, stone_dark)
	draw_circle(Vector2(5 * bs, 3 * bs), 3 * bs, stone_dark)
	draw_colored_polygon(PackedVector2Array([Vector2(-6 * bs, -4 * bs), Vector2(-4 * bs, -8 * bs), Vector2(-2 * bs, -4 * bs)]), crystal_color)
	draw_colored_polygon(PackedVector2Array([Vector2(4 * bs, 2 * bs), Vector2(6 * bs, -2 * bs), Vector2(8 * bs, 2 * bs)]), crystal_color)
	draw_colored_polygon(PackedVector2Array([Vector2(-8 * bs, -14 * bs), Vector2(0, -22 * bs), Vector2(8 * bs, -14 * bs), Vector2(6 * bs, -8 * bs), Vector2(-6 * bs, -8 * bs)]), stone_color)
	draw_circle(Vector2(-3 * bs, -14 * bs), 2.0 * bs, _apply_tint(Color(0.95, 0.5, 0.1), tint))
	draw_circle(Vector2(3 * bs, -14 * bs), 2.0 * bs, _apply_tint(Color(0.95, 0.5, 0.1), tint))
	draw_rect(Rect2(-7 * bs, -24 * bs, 14 * bs, 4 * bs), crown_color)
	draw_colored_polygon(PackedVector2Array([Vector2(-7 * bs, -24 * bs), Vector2(-5 * bs, -28 * bs), Vector2(-3 * bs, -24 * bs)]), crown_color)
	draw_colored_polygon(PackedVector2Array([Vector2(-1 * bs, -24 * bs), Vector2(0, -29 * bs), Vector2(1 * bs, -24 * bs)]), crown_color)
	draw_colored_polygon(PackedVector2Array([Vector2(3 * bs, -24 * bs), Vector2(5 * bs, -28 * bs), Vector2(7 * bs, -24 * bs)]), crown_color)
	draw_circle(Vector2(-4 * bs, -23 * bs), 1.3 * bs, _apply_tint(Color(0.9, 0.15, 0.15), tint))
	draw_circle(Vector2(0, -23 * bs), 1.3 * bs, _apply_tint(Color(0.15, 0.9, 0.15), tint))
	draw_circle(Vector2(4 * bs, -23 * bs), 1.3 * bs, _apply_tint(Color(0.15, 0.15, 0.9), tint))
	draw_rect(Rect2(-6 * bs, 14 * bs, 5 * bs, 4 * bs), stone_dark)
	draw_rect(Rect2(1 * bs, 14 * bs, 5 * bs, 4 * bs), stone_dark)


# =============================================================================
# LEVEL 3 — NEVERLAND
# =============================================================================

func _draw_neverland(s: float, tint: Color) -> void:
	match enemy_tier:
		0: _draw_pirate_deckhand(s, tint)
		1: _draw_pirate_officer(s, tint)
		2: _draw_pirate_gunner(s, tint)
		3: _draw_captain_hook(s, tint)

func _draw_pirate_deckhand(s: float, tint: Color) -> void:
	var stripe1 := _apply_tint(Color(0.9, 0.9, 0.85), tint)
	var stripe2 := _apply_tint(Color(0.75, 0.15, 0.15), tint)
	var skin_color := _apply_tint(Color(0.85, 0.7, 0.55), tint)
	var pants_color := _apply_tint(Color(0.35, 0.3, 0.2), tint)
	var bandana_color := _apply_tint(Color(0.8, 0.2, 0.15), tint)
	draw_rect(Rect2(-7 * s, -6 * s, 14 * s, 16 * s), stripe1)
	for i in range(4):
		draw_rect(Rect2(-7 * s, -4 * s + i * 4 * s, 14 * s, 2 * s), stripe2)
	draw_rect(Rect2(-7 * s, 10 * s, 6 * s, 6 * s), pants_color)
	draw_rect(Rect2(1 * s, 10 * s, 6 * s, 6 * s), pants_color)
	draw_circle(Vector2(0, -12 * s), 7 * s, skin_color)
	draw_arc(Vector2(0, -12 * s), 7.2 * s, PI, 2 * PI, 12, bandana_color, 3.0 * s)
	draw_line(Vector2(6 * s, -12 * s), Vector2(10 * s, -9 * s), bandana_color, 1.5 * s)
	draw_circle(Vector2(-2.5 * s, -12.5 * s), 1.2 * s, Color(0.15, 0.15, 0.15))
	draw_circle(Vector2(2.5 * s, -12.5 * s), 1.2 * s, Color(0.15, 0.15, 0.15))
	draw_rect(Rect2(-8 * s, 14 * s, 6 * s, 3 * s), Color(0.25, 0.2, 0.15))
	draw_rect(Rect2(2 * s, 14 * s, 6 * s, 3 * s), Color(0.25, 0.2, 0.15))

func _draw_pirate_officer(s: float, tint: Color) -> void:
	var coat_color := _apply_tint(Color(0.2, 0.2, 0.5), tint)
	var skin_color := _apply_tint(Color(0.85, 0.7, 0.55), tint)
	var hat_color := _apply_tint(Color(0.15, 0.15, 0.15), tint)
	var gold_color := _apply_tint(Color(0.9, 0.8, 0.2), tint)
	var sword_color := _apply_tint(Color(0.75, 0.75, 0.8), tint)
	draw_rect(Rect2(-8 * s, -8 * s, 16 * s, 20 * s), coat_color)
	draw_circle(Vector2(0, -4 * s), 1.0 * s, gold_color)
	draw_circle(Vector2(0, 0), 1.0 * s, gold_color)
	draw_circle(Vector2(0, 4 * s), 1.0 * s, gold_color)
	draw_rect(Rect2(-9 * s, 6 * s, 18 * s, 2 * s), _apply_tint(Color(0.4, 0.3, 0.15), tint))
	draw_rect(Rect2(-2 * s, 5 * s, 4 * s, 4 * s), gold_color)
	draw_circle(Vector2(0, -14 * s), 7 * s, skin_color)
	draw_colored_polygon(PackedVector2Array([Vector2(-10 * s, -17 * s), Vector2(0, -28 * s), Vector2(10 * s, -17 * s)]), hat_color)
	draw_line(Vector2(-10 * s, -17 * s), Vector2(10 * s, -17 * s), hat_color, 2.0 * s)
	draw_line(Vector2(-8 * s, -17.5 * s), Vector2(8 * s, -17.5 * s), gold_color, 1.0 * s)
	draw_circle(Vector2(-2.5 * s, -14 * s), 1.2 * s, Color(0.15, 0.15, 0.15))
	draw_circle(Vector2(2.5 * s, -14 * s), 1.2 * s, Color(0.15, 0.15, 0.15))
	draw_line(Vector2(10 * s, -6 * s), Vector2(14 * s, 6 * s), sword_color, 1.5 * s)
	draw_line(Vector2(8 * s, -5 * s), Vector2(12 * s, -7 * s), gold_color, 2.0 * s)
	draw_rect(Rect2(-6 * s, 12 * s, 5 * s, 5 * s), _apply_tint(Color(0.3, 0.25, 0.15), tint))
	draw_rect(Rect2(1 * s, 12 * s, 5 * s, 5 * s), _apply_tint(Color(0.3, 0.25, 0.15), tint))

func _draw_pirate_gunner(s: float, tint: Color) -> void:
	var coat_color := _apply_tint(Color(0.35, 0.25, 0.2), tint)
	var skin_color := _apply_tint(Color(0.82, 0.68, 0.52), tint)
	var metal_color := _apply_tint(Color(0.35, 0.35, 0.38), tint)
	draw_rect(Rect2(-10 * s, -8 * s, 20 * s, 22 * s), coat_color)
	draw_rect(Rect2(-6 * s, -6 * s, 12 * s, 8 * s), _apply_tint(Color(0.6, 0.55, 0.45), tint))
	draw_rect(Rect2(-11 * s, 4 * s, 22 * s, 3 * s), _apply_tint(Color(0.3, 0.25, 0.15), tint))
	draw_circle(Vector2(0, -14 * s), 7.5 * s, skin_color)
	draw_rect(Rect2(-7 * s, -20 * s, 14 * s, 4 * s), _apply_tint(Color(0.15, 0.15, 0.15), tint))
	draw_circle(Vector2(-3 * s, -14 * s), 2.5 * s, Color(0.1, 0.1, 0.1))
	draw_circle(Vector2(3 * s, -14 * s), 1.3 * s, Color(0.15, 0.15, 0.15))
	draw_rect(Rect2(10 * s, -8 * s, 5 * s, 18 * s), metal_color)
	draw_rect(Rect2(9 * s, -10 * s, 7 * s, 3 * s), metal_color)
	draw_circle(Vector2(12.5 * s, -10 * s), 3 * s, _apply_tint(Color(0.25, 0.25, 0.28), tint))
	draw_circle(Vector2(12.5 * s, -10 * s), 2 * s, Color(0.08, 0.08, 0.08))
	draw_rect(Rect2(-8 * s, 14 * s, 7 * s, 4 * s), Color(0.2, 0.15, 0.1))
	draw_rect(Rect2(1 * s, 14 * s, 7 * s, 4 * s), Color(0.2, 0.15, 0.1))

func _draw_captain_hook(s: float, tint: Color) -> void:
	var bs: float = s * 1.4
	var coat_color := _apply_tint(Color(0.75, 0.12, 0.12), tint)
	var coat_dark := _apply_tint(Color(0.55, 0.08, 0.08), tint)
	var skin_color := _apply_tint(Color(0.88, 0.75, 0.62), tint)
	var hat_color := _apply_tint(Color(0.2, 0.12, 0.12), tint)
	var gold_color := _apply_tint(Color(0.92, 0.82, 0.2), tint)
	var hook_color := _apply_tint(Color(0.8, 0.8, 0.85), tint)
	draw_colored_polygon(PackedVector2Array([Vector2(-6 * bs, -8 * bs), Vector2(6 * bs, -8 * bs), Vector2(10 * bs, 16 * bs), Vector2(-10 * bs, 16 * bs)]), coat_dark)
	draw_rect(Rect2(-8 * bs, -8 * bs, 16 * bs, 22 * bs), coat_color)
	draw_circle(Vector2(0, -4 * bs), 1.2 * bs, gold_color)
	draw_circle(Vector2(0, 0), 1.2 * bs, gold_color)
	draw_circle(Vector2(0, 4 * bs), 1.2 * bs, gold_color)
	draw_circle(Vector2(-9 * bs, -7 * bs), 3 * bs, gold_color)
	draw_circle(Vector2(9 * bs, -7 * bs), 3 * bs, gold_color)
	draw_circle(Vector2(0, -15 * bs), 8 * bs, skin_color)
	draw_circle(Vector2(-6 * bs, -10 * bs), 3 * bs, Color(0.15, 0.1, 0.1))
	draw_circle(Vector2(6 * bs, -10 * bs), 3 * bs, Color(0.15, 0.1, 0.1))
	draw_circle(Vector2(-3 * bs, -16 * bs), 1.3 * bs, Color(0.15, 0.15, 0.15))
	draw_circle(Vector2(3 * bs, -16 * bs), 1.3 * bs, Color(0.15, 0.15, 0.15))
	draw_line(Vector2(-5 * bs, -12 * bs), Vector2(-1 * bs, -11 * bs), Color(0.15, 0.1, 0.1), 0.8 * bs)
	draw_line(Vector2(5 * bs, -12 * bs), Vector2(1 * bs, -11 * bs), Color(0.15, 0.1, 0.1), 0.8 * bs)
	draw_colored_polygon(PackedVector2Array([Vector2(-10 * bs, -19 * bs), Vector2(0, -30 * bs), Vector2(10 * bs, -19 * bs)]), hat_color)
	draw_line(Vector2(-10 * bs, -19 * bs), Vector2(10 * bs, -19 * bs), hat_color, 2.5 * bs)
	draw_line(Vector2(-9 * bs, -19.5 * bs), Vector2(9 * bs, -19.5 * bs), gold_color, 1.0 * bs)
	draw_line(Vector2(4 * bs, -26 * bs), Vector2(12 * bs, -30 * bs), _apply_tint(Color(0.9, 0.85, 0.8), tint), 1.5 * bs)
	draw_line(Vector2(-10 * bs, -2 * bs), Vector2(-14 * bs, 4 * bs), hook_color, 2.0 * bs)
	draw_arc(Vector2(-14 * bs, 6 * bs), 3 * bs, -PI * 0.8, PI * 0.3, 8, hook_color, 2.0 * bs)
	draw_circle(Vector2(10 * bs, 2 * bs), 2.5 * bs, skin_color)
	draw_rect(Rect2(-6 * bs, 14 * bs, 5 * bs, 5 * bs), _apply_tint(Color(0.25, 0.2, 0.15), tint))
	draw_rect(Rect2(1 * bs, 14 * bs, 5 * bs, 5 * bs), _apply_tint(Color(0.25, 0.2, 0.15), tint))


# =============================================================================
# LEVEL 4 — PARIS OPERA
# =============================================================================

func _draw_opera(s: float, tint: Color) -> void:
	match enemy_tier:
		0: _draw_stagehand(s, tint)
		1: _draw_opera_phantom(s, tint)
		2: _draw_gargoyle(s, tint)
		3: _draw_dark_phantom(s, tint)

func _draw_stagehand(s: float, tint: Color) -> void:
	var body_color := _apply_tint(Color(0.15, 0.15, 0.18), tint)
	var skin_color := _apply_tint(Color(0.82, 0.7, 0.58), tint)
	var prop_color := _apply_tint(Color(0.55, 0.4, 0.25), tint)
	draw_rect(Rect2(-7 * s, -6 * s, 14 * s, 18 * s), body_color)
	draw_circle(Vector2(0, -12 * s), 7 * s, skin_color)
	draw_arc(Vector2(0, -12 * s), 7.2 * s, PI, 2 * PI, 12, body_color, 3.0 * s)
	draw_circle(Vector2(-2.5 * s, -12 * s), 1.2 * s, Color(0.15, 0.15, 0.15))
	draw_circle(Vector2(2.5 * s, -12 * s), 1.2 * s, Color(0.15, 0.15, 0.15))
	draw_rect(Rect2(6 * s, -6 * s, 8 * s, 8 * s), prop_color)
	draw_line(Vector2(6 * s, -2 * s), Vector2(14 * s, -2 * s), _apply_tint(Color(0.4, 0.3, 0.15), tint), 1.0 * s)
	draw_rect(Rect2(-6 * s, 12 * s, 5 * s, 4 * s), body_color)
	draw_rect(Rect2(1 * s, 12 * s, 5 * s, 4 * s), body_color)

func _draw_opera_phantom(s: float, tint: Color) -> void:
	var cape_color := _apply_tint(Color(0.12, 0.1, 0.15), tint)
	var suit_color := _apply_tint(Color(0.08, 0.08, 0.1), tint)
	var skin_color := _apply_tint(Color(0.82, 0.7, 0.58), tint)
	var mask_color := _apply_tint(Color(0.95, 0.93, 0.9), tint)
	draw_colored_polygon(PackedVector2Array([Vector2(-4 * s, -10 * s), Vector2(4 * s, -10 * s), Vector2(12 * s, 14 * s), Vector2(-12 * s, 14 * s)]), cape_color)
	draw_rect(Rect2(-7 * s, -6 * s, 14 * s, 18 * s), suit_color)
	draw_rect(Rect2(-2 * s, -6 * s, 4 * s, 12 * s), _apply_tint(Color(0.9, 0.88, 0.85), tint))
	draw_circle(Vector2(0, -12 * s), 7 * s, skin_color)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -19 * s), Vector2(7 * s, -12 * s), Vector2(0, -5 * s)]), mask_color)
	draw_circle(Vector2(-2.5 * s, -13 * s), 1.3 * s, Color(0.15, 0.15, 0.15))
	draw_line(Vector2(1.5 * s, -13 * s), Vector2(4 * s, -13 * s), Color(0.08, 0.08, 0.08), 1.5 * s)
	draw_arc(Vector2(0, -12 * s), 7.5 * s, PI, 2 * PI, 12, Color(0.12, 0.1, 0.1), 2.0 * s)
	draw_rect(Rect2(-5 * s, 12 * s, 4 * s, 4 * s), suit_color)
	draw_rect(Rect2(1 * s, 12 * s, 4 * s, 4 * s), suit_color)

func _draw_gargoyle(s: float, tint: Color) -> void:
	var stone_color := _apply_tint(Color(0.5, 0.5, 0.52), tint)
	var stone_dark := _apply_tint(Color(0.35, 0.35, 0.37), tint)
	var stone_light := _apply_tint(Color(0.62, 0.62, 0.64), tint)
	var eye_color := _apply_tint(Color(0.9, 0.5, 0.1), tint)
	draw_colored_polygon(PackedVector2Array([Vector2(-8 * s, -6 * s), Vector2(-16 * s, -12 * s), Vector2(-14 * s, 0), Vector2(-8 * s, 2 * s)]), stone_dark)
	draw_colored_polygon(PackedVector2Array([Vector2(8 * s, -6 * s), Vector2(16 * s, -12 * s), Vector2(14 * s, 0), Vector2(8 * s, 2 * s)]), stone_dark)
	draw_colored_polygon(PackedVector2Array([Vector2(-8 * s, -8 * s), Vector2(8 * s, -8 * s), Vector2(10 * s, 4 * s), Vector2(7 * s, 12 * s), Vector2(-7 * s, 12 * s), Vector2(-10 * s, 4 * s)]), stone_color)
	draw_colored_polygon(PackedVector2Array([Vector2(-6 * s, -12 * s), Vector2(-3 * s, -22 * s), Vector2(3 * s, -22 * s), Vector2(6 * s, -12 * s), Vector2(4 * s, -8 * s), Vector2(-4 * s, -8 * s)]), stone_color)
	draw_colored_polygon(PackedVector2Array([Vector2(-5 * s, -18 * s), Vector2(-8 * s, -24 * s), Vector2(-3 * s, -20 * s)]), stone_dark)
	draw_colored_polygon(PackedVector2Array([Vector2(5 * s, -18 * s), Vector2(8 * s, -24 * s), Vector2(3 * s, -20 * s)]), stone_dark)
	draw_circle(Vector2(-2.5 * s, -15 * s), 2.0 * s, eye_color)
	draw_circle(Vector2(2.5 * s, -15 * s), 2.0 * s, eye_color)
	draw_circle(Vector2(-2.5 * s, -15 * s), 1.0 * s, _apply_tint(Color(1.0, 0.9, 0.3), tint))
	draw_circle(Vector2(2.5 * s, -15 * s), 1.0 * s, _apply_tint(Color(1.0, 0.9, 0.3), tint))
	draw_line(Vector2(-3 * s, -11 * s), Vector2(3 * s, -11 * s), stone_dark, 1.0 * s)
	draw_line(Vector2(-2 * s, -11 * s), Vector2(-2 * s, -9 * s), stone_light, 1.0 * s)
	draw_line(Vector2(2 * s, -11 * s), Vector2(2 * s, -9 * s), stone_light, 1.0 * s)
	draw_colored_polygon(PackedVector2Array([Vector2(-7 * s, 12 * s), Vector2(-9 * s, 16 * s), Vector2(-5 * s, 16 * s), Vector2(-3 * s, 12 * s)]), stone_dark)
	draw_colored_polygon(PackedVector2Array([Vector2(3 * s, 12 * s), Vector2(5 * s, 16 * s), Vector2(9 * s, 16 * s), Vector2(7 * s, 12 * s)]), stone_dark)

func _draw_dark_phantom(s: float, tint: Color) -> void:
	var bs: float = s * 1.4
	var cape_color := _apply_tint(Color(0.08, 0.06, 0.12), tint)
	var suit_color := _apply_tint(Color(0.05, 0.05, 0.08), tint)
	var mask_color := _apply_tint(Color(0.97, 0.95, 0.93), tint)
	var aura_color := _apply_tint(Color(0.7, 0.6, 0.9, 0.5), tint)
	draw_circle(Vector2(-14 * bs, -12 * bs), 2.0 * bs, aura_color)
	draw_circle(Vector2(14 * bs, -8 * bs), 2.0 * bs, aura_color)
	draw_circle(Vector2(-12 * bs, 4 * bs), 1.8 * bs, aura_color)
	draw_circle(Vector2(12 * bs, 2 * bs), 1.8 * bs, aura_color)
	draw_line(Vector2(-14 * bs, -12 * bs), Vector2(-14 * bs, -18 * bs), aura_color, 0.8 * bs)
	draw_line(Vector2(14 * bs, -8 * bs), Vector2(14 * bs, -14 * bs), aura_color, 0.8 * bs)
	draw_colored_polygon(PackedVector2Array([Vector2(-6 * bs, -12 * bs), Vector2(6 * bs, -12 * bs), Vector2(14 * bs, 16 * bs), Vector2(8 * bs, 18 * bs), Vector2(0, 15 * bs), Vector2(-8 * bs, 18 * bs), Vector2(-14 * bs, 16 * bs)]), cape_color)
	draw_rect(Rect2(-8 * bs, -8 * bs, 16 * bs, 22 * bs), suit_color)
	draw_rect(Rect2(-3 * bs, -8 * bs, 6 * bs, 16 * bs), _apply_tint(Color(0.88, 0.86, 0.83), tint))
	draw_circle(Vector2(-5 * bs, -5 * bs), 2 * bs, _apply_tint(Color(0.85, 0.1, 0.1), tint))
	draw_circle(Vector2(0, -16 * bs), 8 * bs, _apply_tint(Color(0.15, 0.12, 0.12), tint))
	draw_circle(Vector2(0, -16 * bs), 7.5 * bs, mask_color)
	draw_circle(Vector2(-3 * bs, -17 * bs), 1.8 * bs, Color(0.05, 0.05, 0.05))
	draw_circle(Vector2(3 * bs, -17 * bs), 1.8 * bs, Color(0.05, 0.05, 0.05))
	draw_circle(Vector2(-3 * bs, -17 * bs), 0.6 * bs, _apply_tint(Color(0.9, 0.3, 0.3), tint))
	draw_circle(Vector2(3 * bs, -17 * bs), 0.6 * bs, _apply_tint(Color(0.9, 0.3, 0.3), tint))
	draw_rect(Rect2(-5 * bs, -28 * bs, 10 * bs, 10 * bs), Color(0.05, 0.05, 0.05))
	draw_rect(Rect2(-7 * bs, -20 * bs, 14 * bs, 2 * bs), Color(0.05, 0.05, 0.05))
	draw_rect(Rect2(-5 * bs, -22 * bs, 10 * bs, 2 * bs), _apply_tint(Color(0.6, 0.1, 0.1), tint))
	draw_circle(Vector2(-10 * bs, 4 * bs), 2.5 * bs, _apply_tint(Color(0.9, 0.88, 0.85), tint))
	draw_circle(Vector2(10 * bs, 4 * bs), 2.5 * bs, _apply_tint(Color(0.9, 0.88, 0.85), tint))
	draw_rect(Rect2(-5 * bs, 14 * bs, 4 * bs, 4 * bs), suit_color)
	draw_rect(Rect2(1 * bs, 14 * bs, 4 * bs, 4 * bs), suit_color)


# =============================================================================
# LEVEL 5 — VICTORIAN LONDON
# =============================================================================

func _draw_victorian(s: float, tint: Color) -> void:
	match enemy_tier:
		0: _draw_street_urchin(s, tint)
		1: _draw_debt_collector(s, tint)
		2: _draw_ghost(s, tint)
		3: _draw_ghost_christmas(s, tint)

func _draw_street_urchin(s: float, tint: Color) -> void:
	var rag_color := _apply_tint(Color(0.5, 0.4, 0.3), tint)
	var rag_dark := _apply_tint(Color(0.38, 0.32, 0.25), tint)
	var skin_color := _apply_tint(Color(0.78, 0.65, 0.52), tint)
	var hair_color := _apply_tint(Color(0.4, 0.3, 0.2), tint)
	draw_colored_polygon(PackedVector2Array([Vector2(-6 * s, -5 * s), Vector2(6 * s, -5 * s), Vector2(7 * s, 6 * s), Vector2(5 * s, 8 * s), Vector2(3 * s, 7 * s), Vector2(1 * s, 9 * s), Vector2(-1 * s, 7 * s), Vector2(-3 * s, 8 * s), Vector2(-5 * s, 7 * s), Vector2(-7 * s, 6 * s)]), rag_color)
	draw_rect(Rect2(-4 * s, -2 * s, 4 * s, 4 * s), rag_dark)
	draw_circle(Vector2(0, -11 * s), 6 * s, skin_color)
	draw_circle(Vector2(-3 * s, -16 * s), 3 * s, hair_color)
	draw_circle(Vector2(2 * s, -17 * s), 3 * s, hair_color)
	draw_circle(Vector2(0, -16 * s), 3.5 * s, hair_color)
	draw_circle(Vector2(-2 * s, -11 * s), 1.8 * s, Color(0.95, 0.95, 0.9))
	draw_circle(Vector2(2 * s, -11 * s), 1.8 * s, Color(0.95, 0.95, 0.9))
	draw_circle(Vector2(-2 * s, -11 * s), 1.0 * s, Color(0.25, 0.2, 0.15))
	draw_circle(Vector2(2 * s, -11 * s), 1.0 * s, Color(0.25, 0.2, 0.15))
	draw_rect(Rect2(-5 * s, 8 * s, 4 * s, 5 * s), rag_dark)
	draw_rect(Rect2(1 * s, 8 * s, 4 * s, 5 * s), rag_dark)
	draw_circle(Vector2(-3 * s, 14 * s), 2 * s, skin_color)
	draw_circle(Vector2(3 * s, 14 * s), 2 * s, skin_color)

func _draw_debt_collector(s: float, tint: Color) -> void:
	var suit_color := _apply_tint(Color(0.2, 0.2, 0.22), tint)
	var skin_color := _apply_tint(Color(0.78, 0.68, 0.58), tint)
	var hat_color := _apply_tint(Color(0.12, 0.12, 0.14), tint)
	var chain_color := _apply_tint(Color(0.6, 0.58, 0.52), tint)
	var vest_color := _apply_tint(Color(0.35, 0.25, 0.2), tint)
	draw_rect(Rect2(-8 * s, -8 * s, 16 * s, 22 * s), suit_color)
	draw_rect(Rect2(-5 * s, -6 * s, 10 * s, 14 * s), vest_color)
	draw_line(Vector2(-4 * s, -2 * s), Vector2(4 * s, 2 * s), _apply_tint(Color(0.85, 0.75, 0.2), tint), 1.0 * s)
	draw_circle(Vector2(0, -14 * s), 7 * s, skin_color)
	draw_rect(Rect2(-5 * s, -28 * s, 10 * s, 12 * s), hat_color)
	draw_rect(Rect2(-7 * s, -18 * s, 14 * s, 3 * s), hat_color)
	draw_circle(Vector2(-2.5 * s, -14 * s), 1.2 * s, Color(0.15, 0.15, 0.15))
	draw_circle(Vector2(2.5 * s, -14 * s), 1.2 * s, Color(0.15, 0.15, 0.15))
	draw_arc(Vector2(-2.5 * s, -14 * s), 2.5 * s, 0, TAU, 12, _apply_tint(Color(0.7, 0.65, 0.4), tint), 0.6 * s)
	draw_arc(Vector2(2.5 * s, -14 * s), 2.5 * s, 0, TAU, 12, _apply_tint(Color(0.7, 0.65, 0.4), tint), 0.6 * s)
	for i in range(4):
		var cy = -2 * s + i * 3 * s
		draw_circle(Vector2(-12 * s, cy), 1.5 * s, chain_color)
		draw_circle(Vector2(12 * s, cy), 1.5 * s, chain_color)
	draw_line(Vector2(-12 * s, -2 * s), Vector2(-12 * s, 8 * s), chain_color, 0.8 * s)
	draw_line(Vector2(12 * s, -2 * s), Vector2(12 * s, 8 * s), chain_color, 0.8 * s)
	draw_rect(Rect2(-6 * s, 14 * s, 5 * s, 4 * s), suit_color)
	draw_rect(Rect2(1 * s, 14 * s, 5 * s, 4 * s), suit_color)

func _draw_ghost(s: float, tint: Color) -> void:
	var ghost_tint: Color
	if tint == Color.WHITE:
		ghost_tint = Color(1.0, 1.0, 1.0, 0.55)
	else:
		ghost_tint = Color(tint.r, tint.g, tint.b, tint.a * 0.55)
	var body_color := _apply_tint(Color(0.75, 0.85, 0.8), ghost_tint)
	var glow_color := _apply_tint(Color(0.4, 0.7, 0.6, 0.25), ghost_tint)
	draw_circle(Vector2(0, -4 * s), 16 * s, glow_color)
	draw_colored_polygon(PackedVector2Array([Vector2(-8 * s, -14 * s), Vector2(8 * s, -14 * s), Vector2(9 * s, 4 * s), Vector2(7 * s, 8 * s), Vector2(5 * s, 5 * s), Vector2(3 * s, 9 * s), Vector2(1 * s, 5 * s), Vector2(-1 * s, 9 * s), Vector2(-3 * s, 5 * s), Vector2(-5 * s, 9 * s), Vector2(-7 * s, 5 * s), Vector2(-9 * s, 4 * s)]), body_color)
	draw_circle(Vector2(0, -14 * s), 9 * s, body_color)
	draw_circle(Vector2(-3 * s, -14 * s), 2.5 * s, Color(0.15, 0.5, 0.4, 0.8))
	draw_circle(Vector2(3 * s, -14 * s), 2.5 * s, Color(0.15, 0.5, 0.4, 0.8))
	draw_circle(Vector2(-3 * s, -14 * s), 1.2 * s, Color(0.05, 0.3, 0.25, 0.9))
	draw_circle(Vector2(3 * s, -14 * s), 1.2 * s, Color(0.05, 0.3, 0.25, 0.9))
	draw_circle(Vector2(0, -9 * s), 2 * s, Color(0.1, 0.35, 0.3, 0.7))
	draw_line(Vector2(-8 * s, -6 * s), Vector2(-14 * s, -2 * s), body_color, 2.0 * s)
	draw_line(Vector2(8 * s, -6 * s), Vector2(14 * s, -2 * s), body_color, 2.0 * s)

func _draw_ghost_christmas(s: float, tint: Color) -> void:
	var bs: float = s * 1.5
	var robe_color := _apply_tint(Color(0.06, 0.05, 0.08), tint)
	var robe_dark := _apply_tint(Color(0.03, 0.02, 0.05), tint)
	var eye_glow := _apply_tint(Color(0.95, 0.85, 0.4), tint)
	var bone_color := _apply_tint(Color(0.85, 0.82, 0.75), tint)
	draw_colored_polygon(PackedVector2Array([Vector2(-10 * bs, 14 * bs), Vector2(10 * bs, 14 * bs), Vector2(12 * bs, 16 * bs), Vector2(-12 * bs, 16 * bs)]), Color(0.0, 0.0, 0.0, 0.3))
	draw_colored_polygon(PackedVector2Array([Vector2(-6 * bs, -12 * bs), Vector2(6 * bs, -12 * bs), Vector2(10 * bs, 14 * bs), Vector2(-10 * bs, 14 * bs)]), robe_color)
	draw_line(Vector2(-2 * bs, -8 * bs), Vector2(-4 * bs, 14 * bs), robe_dark, 1.0 * bs)
	draw_line(Vector2(2 * bs, -8 * bs), Vector2(4 * bs, 14 * bs), robe_dark, 1.0 * bs)
	draw_colored_polygon(PackedVector2Array([Vector2(-8 * bs, -12 * bs), Vector2(0, -28 * bs), Vector2(8 * bs, -12 * bs), Vector2(6 * bs, -6 * bs), Vector2(-6 * bs, -6 * bs)]), robe_color)
	draw_colored_polygon(PackedVector2Array([Vector2(-5 * bs, -10 * bs), Vector2(0, -18 * bs), Vector2(5 * bs, -10 * bs), Vector2(4 * bs, -6 * bs), Vector2(-4 * bs, -6 * bs)]), robe_dark)
	draw_circle(Vector2(-2 * bs, -10 * bs), 1.8 * bs, eye_glow)
	draw_circle(Vector2(2 * bs, -10 * bs), 1.8 * bs, eye_glow)
	draw_circle(Vector2(-2 * bs, -10 * bs), 1.0 * bs, _apply_tint(Color(1.0, 1.0, 0.8), tint))
	draw_circle(Vector2(2 * bs, -10 * bs), 1.0 * bs, _apply_tint(Color(1.0, 1.0, 0.8), tint))
	draw_line(Vector2(6 * bs, -2 * bs), Vector2(14 * bs, -4 * bs), bone_color, 1.5 * bs)
	draw_circle(Vector2(14 * bs, -4 * bs), 2 * bs, bone_color)
	draw_line(Vector2(14 * bs, -4 * bs), Vector2(18 * bs, -8 * bs), bone_color, 1.0 * bs)
	draw_line(Vector2(14 * bs, -4 * bs), Vector2(19 * bs, -5 * bs), bone_color, 1.0 * bs)
	draw_line(Vector2(14 * bs, -4 * bs), Vector2(18 * bs, -2 * bs), bone_color, 1.0 * bs)
	draw_line(Vector2(14 * bs, -4 * bs), Vector2(17 * bs, 0), bone_color, 1.0 * bs)
	draw_arc(Vector2(-6 * bs, 14 * bs), 3 * bs, PI, 2 * PI, 8, Color(0.2, 0.2, 0.3, 0.3), 1.0 * bs)
	draw_arc(Vector2(0, 15 * bs), 3 * bs, PI, 2 * PI, 8, Color(0.2, 0.2, 0.3, 0.25), 1.0 * bs)
	draw_arc(Vector2(6 * bs, 14 * bs), 3 * bs, PI, 2 * PI, 8, Color(0.2, 0.2, 0.3, 0.3), 1.0 * bs)


# =============================================================================
# THEME 6 — SHADOW ENTITIES (PROLOGUE)
# =============================================================================

func _draw_shadow_entities(s: float, tint: Color) -> void:
	match enemy_tier:
		0: _draw_ink_wisp(s, tint)
		1: _draw_shadow_soldier(s, tint)
		2: _draw_ink_beast(s, tint)
		3: _draw_shadow_lord(s, tint)

func _draw_ink_wisp(s: float, tint: Color) -> void:
	var ink_color := _apply_tint(Color(0.08, 0.06, 0.12), tint)
	var ink_mid := _apply_tint(Color(0.15, 0.1, 0.2), tint)
	var eye_color := _apply_tint(Color(0.85, 0.4, 0.9), tint)
	var glow_color := _apply_tint(Color(0.6, 0.2, 0.8, 0.3), tint)
	# Aura glow
	draw_circle(Vector2(0, -2 * s), 14 * s, glow_color)
	# Blobby body
	draw_circle(Vector2(0, 0), 8 * s, ink_color)
	draw_circle(Vector2(-4 * s, -3 * s), 5 * s, ink_mid)
	draw_circle(Vector2(4 * s, -2 * s), 5 * s, ink_mid)
	draw_circle(Vector2(0, 4 * s), 6 * s, ink_color)
	# Drip tendrils
	draw_line(Vector2(-5 * s, 6 * s), Vector2(-6 * s, 12 * s), ink_color, 2.0 * s)
	draw_line(Vector2(0, 7 * s), Vector2(0, 13 * s), ink_color, 2.5 * s)
	draw_line(Vector2(5 * s, 6 * s), Vector2(6 * s, 12 * s), ink_color, 2.0 * s)
	# Glowing eyes
	draw_circle(Vector2(-3 * s, -3 * s), 2.0 * s, eye_color)
	draw_circle(Vector2(3 * s, -3 * s), 2.0 * s, eye_color)
	draw_circle(Vector2(-3 * s, -3 * s), 1.0 * s, Color(1.0, 0.85, 1.0))
	draw_circle(Vector2(3 * s, -3 * s), 1.0 * s, Color(1.0, 0.85, 1.0))

func _draw_shadow_soldier(s: float, tint: Color) -> void:
	var shadow_color := _apply_tint(Color(0.1, 0.08, 0.15), tint)
	var shadow_mid := _apply_tint(Color(0.18, 0.14, 0.25), tint)
	var eye_color := _apply_tint(Color(0.9, 0.3, 0.4), tint)
	var sword_color := _apply_tint(Color(0.4, 0.3, 0.5), tint)
	# Body silhouette
	draw_rect(Rect2(-7 * s, -8 * s, 14 * s, 22 * s), shadow_color)
	draw_rect(Rect2(-5 * s, -6 * s, 10 * s, 18 * s), shadow_mid)
	# Head
	draw_circle(Vector2(0, -14 * s), 7 * s, shadow_color)
	# Glowing slit eyes
	draw_line(Vector2(-4 * s, -15 * s), Vector2(-1 * s, -14 * s), eye_color, 1.5 * s)
	draw_line(Vector2(1 * s, -14 * s), Vector2(4 * s, -15 * s), eye_color, 1.5 * s)
	# Sword silhouette
	draw_line(Vector2(9 * s, -14 * s), Vector2(9 * s, 10 * s), sword_color, 2.0 * s)
	draw_line(Vector2(6 * s, -6 * s), Vector2(12 * s, -6 * s), sword_color, 1.5 * s)
	# Legs
	draw_rect(Rect2(-6 * s, 14 * s, 5 * s, 4 * s), shadow_color)
	draw_rect(Rect2(1 * s, 14 * s, 5 * s, 4 * s), shadow_color)
	# Wispy edges
	draw_line(Vector2(-7 * s, 4 * s), Vector2(-11 * s, 8 * s), shadow_mid, 1.5 * s)
	draw_line(Vector2(7 * s, 4 * s), Vector2(11 * s, 8 * s), shadow_mid, 1.5 * s)

func _draw_ink_beast(s: float, tint: Color) -> void:
	var ink_color := _apply_tint(Color(0.06, 0.04, 0.1), tint)
	var ink_light := _apply_tint(Color(0.15, 0.1, 0.22), tint)
	var eye_color := _apply_tint(Color(0.95, 0.6, 0.1), tint)
	var drip_color := _apply_tint(Color(0.1, 0.06, 0.15, 0.7), tint)
	# Four-legged body
	draw_rect(Rect2(-12 * s, -6 * s, 24 * s, 12 * s), ink_color)
	draw_circle(Vector2(-8 * s, 0), 5 * s, ink_light)
	draw_circle(Vector2(8 * s, 0), 5 * s, ink_light)
	# Head
	draw_circle(Vector2(0, -12 * s), 8 * s, ink_color)
	draw_circle(Vector2(0, -8 * s), 5 * s, ink_light)
	# Glowing eyes
	draw_circle(Vector2(-3 * s, -13 * s), 2.0 * s, eye_color)
	draw_circle(Vector2(3 * s, -13 * s), 2.0 * s, eye_color)
	draw_circle(Vector2(-3 * s, -13 * s), 1.0 * s, Color(1.0, 0.95, 0.8))
	draw_circle(Vector2(3 * s, -13 * s), 1.0 * s, Color(1.0, 0.95, 0.8))
	# Mouth
	draw_line(Vector2(-3 * s, -8 * s), Vector2(3 * s, -8 * s), eye_color, 1.0 * s)
	# Four legs
	draw_rect(Rect2(-13 * s, 6 * s, 4 * s, 8 * s), ink_color)
	draw_rect(Rect2(-5 * s, 6 * s, 4 * s, 8 * s), ink_color)
	draw_rect(Rect2(1 * s, 6 * s, 4 * s, 8 * s), ink_color)
	draw_rect(Rect2(9 * s, 6 * s, 4 * s, 8 * s), ink_color)
	# Ink drips
	draw_line(Vector2(-10 * s, 6 * s), Vector2(-12 * s, 10 * s), drip_color, 1.5 * s)
	draw_line(Vector2(10 * s, 6 * s), Vector2(12 * s, 10 * s), drip_color, 1.5 * s)
	draw_line(Vector2(0, 6 * s), Vector2(0, 11 * s), drip_color, 2.0 * s)

func _draw_shadow_lord(s: float, tint: Color) -> void:
	var bs: float = s * 1.4
	var cloak_color := _apply_tint(Color(0.05, 0.03, 0.1), tint)
	var cloak_mid := _apply_tint(Color(0.12, 0.08, 0.2), tint)
	var eye_color := _apply_tint(Color(1.0, 0.3, 0.5), tint)
	var crown_color := _apply_tint(Color(0.5, 0.15, 0.6), tint)
	var aura_color := _apply_tint(Color(0.4, 0.1, 0.5, 0.25), tint)
	# Dark aura
	draw_circle(Vector2(0, -4 * bs), 22 * bs, aura_color)
	# Tall cloak
	draw_colored_polygon(PackedVector2Array([Vector2(-8 * bs, -14 * bs), Vector2(8 * bs, -14 * bs), Vector2(14 * bs, 16 * bs), Vector2(-14 * bs, 16 * bs)]), cloak_color)
	draw_colored_polygon(PackedVector2Array([Vector2(-6 * bs, -12 * bs), Vector2(6 * bs, -12 * bs), Vector2(10 * bs, 14 * bs), Vector2(-10 * bs, 14 * bs)]), cloak_mid)
	# Hood / head
	draw_circle(Vector2(0, -18 * bs), 9 * bs, cloak_color)
	draw_circle(Vector2(0, -16 * bs), 6 * bs, cloak_mid)
	# Glowing eyes
	draw_circle(Vector2(-3 * bs, -17 * bs), 2.0 * bs, eye_color)
	draw_circle(Vector2(3 * bs, -17 * bs), 2.0 * bs, eye_color)
	draw_circle(Vector2(-3 * bs, -17 * bs), 1.0 * bs, Color(1.0, 0.8, 0.9))
	draw_circle(Vector2(3 * bs, -17 * bs), 1.0 * bs, Color(1.0, 0.8, 0.9))
	# Shadow crown
	draw_rect(Rect2(-6 * bs, -27 * bs, 12 * bs, 4 * bs), crown_color)
	draw_colored_polygon(PackedVector2Array([Vector2(-6 * bs, -27 * bs), Vector2(-4 * bs, -31 * bs), Vector2(-2 * bs, -27 * bs)]), crown_color)
	draw_colored_polygon(PackedVector2Array([Vector2(-1 * bs, -27 * bs), Vector2(0, -32 * bs), Vector2(1 * bs, -27 * bs)]), crown_color)
	draw_colored_polygon(PackedVector2Array([Vector2(2 * bs, -27 * bs), Vector2(4 * bs, -31 * bs), Vector2(6 * bs, -27 * bs)]), crown_color)
	# Wispy arms
	draw_line(Vector2(-8 * bs, -4 * bs), Vector2(-16 * bs, -8 * bs), cloak_color, 2.5 * bs)
	draw_line(Vector2(8 * bs, -4 * bs), Vector2(16 * bs, -8 * bs), cloak_color, 2.5 * bs)
	# Base wisps
	draw_line(Vector2(-10 * bs, 16 * bs), Vector2(-12 * bs, 20 * bs), cloak_mid, 2.0 * bs)
	draw_line(Vector2(0, 16 * bs), Vector2(0, 20 * bs), cloak_mid, 2.0 * bs)
	draw_line(Vector2(10 * bs, 16 * bs), Vector2(12 * bs, 20 * bs), cloak_mid, 2.0 * bs)


# =============================================================================
# THEME 7 — SHERLOCK CRIMINALS
# =============================================================================

func _draw_sherlock(s: float, tint: Color) -> void:
	match enemy_tier:
		0: _draw_street_thug(s, tint)
		1: _draw_assassin(s, tint)
		2: _draw_moriarty_agent(s, tint)
		3: _draw_moriarty(s, tint)

func _draw_street_thug(s: float, tint: Color) -> void:
	var shirt_color := _apply_tint(Color(0.45, 0.4, 0.35), tint)
	var skin_color := _apply_tint(Color(0.82, 0.7, 0.58), tint)
	var cap_color := _apply_tint(Color(0.3, 0.28, 0.25), tint)
	var pants_color := _apply_tint(Color(0.35, 0.3, 0.25), tint)
	# Body
	draw_rect(Rect2(-7 * s, -6 * s, 14 * s, 18 * s), shirt_color)
	draw_rect(Rect2(-8 * s, 4 * s, 16 * s, 2 * s), _apply_tint(Color(0.4, 0.3, 0.2), tint))
	# Head
	draw_circle(Vector2(0, -12 * s), 7 * s, skin_color)
	# Flat cap
	draw_arc(Vector2(0, -12 * s), 7.5 * s, PI, 2 * PI, 12, cap_color, 3.0 * s)
	draw_rect(Rect2(-8 * s, -16 * s, 16 * s, 3 * s), cap_color)
	draw_line(Vector2(-8 * s, -13 * s), Vector2(-10 * s, -14 * s), cap_color, 2.0 * s)
	# Eyes - mean squint
	draw_line(Vector2(-4 * s, -13 * s), Vector2(-1 * s, -12 * s), Color(0.15, 0.15, 0.15), 1.5 * s)
	draw_line(Vector2(1 * s, -12 * s), Vector2(4 * s, -13 * s), Color(0.15, 0.15, 0.15), 1.5 * s)
	# Fists
	draw_circle(Vector2(-10 * s, 2 * s), 3 * s, skin_color)
	draw_circle(Vector2(10 * s, 2 * s), 3 * s, skin_color)
	# Legs
	draw_rect(Rect2(-6 * s, 12 * s, 5 * s, 4 * s), pants_color)
	draw_rect(Rect2(1 * s, 12 * s, 5 * s, 4 * s), pants_color)
	# Boots
	draw_rect(Rect2(-7 * s, 16 * s, 6 * s, 2 * s), Color(0.2, 0.18, 0.15))
	draw_rect(Rect2(1 * s, 16 * s, 6 * s, 2 * s), Color(0.2, 0.18, 0.15))

func _draw_assassin(s: float, tint: Color) -> void:
	var coat_color := _apply_tint(Color(0.12, 0.1, 0.12), tint)
	var skin_color := _apply_tint(Color(0.78, 0.68, 0.58), tint)
	var knife_color := _apply_tint(Color(0.75, 0.75, 0.8), tint)
	var scarf_color := _apply_tint(Color(0.35, 0.1, 0.1), tint)
	# Long coat
	draw_colored_polygon(PackedVector2Array([Vector2(-7 * s, -8 * s), Vector2(7 * s, -8 * s), Vector2(9 * s, 14 * s), Vector2(-9 * s, 14 * s)]), coat_color)
	draw_rect(Rect2(-8 * s, -8 * s, 16 * s, 20 * s), coat_color)
	# Scarf
	draw_line(Vector2(-4 * s, -7 * s), Vector2(4 * s, -7 * s), scarf_color, 2.5 * s)
	draw_line(Vector2(2 * s, -7 * s), Vector2(4 * s, -2 * s), scarf_color, 2.0 * s)
	# Head
	draw_circle(Vector2(0, -14 * s), 7 * s, skin_color)
	# Shadowed eyes
	draw_circle(Vector2(-2.5 * s, -14 * s), 1.5 * s, Color(0.1, 0.1, 0.1))
	draw_circle(Vector2(2.5 * s, -14 * s), 1.5 * s, Color(0.1, 0.1, 0.1))
	draw_circle(Vector2(-2.5 * s, -14 * s), 0.7 * s, Color(0.4, 0.35, 0.3))
	draw_circle(Vector2(2.5 * s, -14 * s), 0.7 * s, Color(0.4, 0.35, 0.3))
	# Knife
	draw_line(Vector2(-10 * s, -4 * s), Vector2(-10 * s, 6 * s), knife_color, 1.5 * s)
	draw_colored_polygon(PackedVector2Array([Vector2(-10 * s, -4 * s), Vector2(-11.5 * s, -6 * s), Vector2(-8.5 * s, -6 * s)]), knife_color)
	# Legs
	draw_rect(Rect2(-6 * s, 12 * s, 5 * s, 4 * s), coat_color)
	draw_rect(Rect2(1 * s, 12 * s, 5 * s, 4 * s), coat_color)

func _draw_moriarty_agent(s: float, tint: Color) -> void:
	var suit_color := _apply_tint(Color(0.15, 0.15, 0.18), tint)
	var vest_color := _apply_tint(Color(0.35, 0.15, 0.15), tint)
	var skin_color := _apply_tint(Color(0.82, 0.72, 0.62), tint)
	var hat_color := _apply_tint(Color(0.1, 0.1, 0.12), tint)
	var gun_color := _apply_tint(Color(0.3, 0.3, 0.32), tint)
	# Body
	draw_rect(Rect2(-8 * s, -8 * s, 16 * s, 22 * s), suit_color)
	draw_rect(Rect2(-5 * s, -6 * s, 10 * s, 16 * s), vest_color)
	# Buttons
	draw_circle(Vector2(0, -3 * s), 0.8 * s, _apply_tint(Color(0.85, 0.75, 0.2), tint))
	draw_circle(Vector2(0, 1 * s), 0.8 * s, _apply_tint(Color(0.85, 0.75, 0.2), tint))
	draw_circle(Vector2(0, 5 * s), 0.8 * s, _apply_tint(Color(0.85, 0.75, 0.2), tint))
	# Head
	draw_circle(Vector2(0, -14 * s), 7 * s, skin_color)
	# Top hat
	draw_rect(Rect2(-4 * s, -26 * s, 8 * s, 10 * s), hat_color)
	draw_rect(Rect2(-6 * s, -17 * s, 12 * s, 2 * s), hat_color)
	# Eyes
	draw_circle(Vector2(-2.5 * s, -14 * s), 1.2 * s, Color(0.15, 0.15, 0.15))
	draw_circle(Vector2(2.5 * s, -14 * s), 1.2 * s, Color(0.15, 0.15, 0.15))
	# Pistol
	draw_rect(Rect2(10 * s, -4 * s, 8 * s, 3 * s), gun_color)
	draw_rect(Rect2(10 * s, -1 * s, 3 * s, 5 * s), gun_color)
	# Legs
	draw_rect(Rect2(-6 * s, 14 * s, 5 * s, 4 * s), suit_color)
	draw_rect(Rect2(1 * s, 14 * s, 5 * s, 4 * s), suit_color)

func _draw_moriarty(s: float, tint: Color) -> void:
	var bs: float = s * 1.4
	var suit_color := _apply_tint(Color(0.1, 0.1, 0.12), tint)
	var vest_color := _apply_tint(Color(0.25, 0.12, 0.12), tint)
	var skin_color := _apply_tint(Color(0.82, 0.72, 0.62), tint)
	var hat_color := _apply_tint(Color(0.08, 0.08, 0.1), tint)
	var gold_color := _apply_tint(Color(0.9, 0.8, 0.2), tint)
	# Cape / coat tails
	draw_colored_polygon(PackedVector2Array([Vector2(-6 * bs, -8 * bs), Vector2(6 * bs, -8 * bs), Vector2(12 * bs, 16 * bs), Vector2(-12 * bs, 16 * bs)]), suit_color)
	# Body
	draw_rect(Rect2(-8 * bs, -8 * bs, 16 * bs, 22 * bs), suit_color)
	draw_rect(Rect2(-5 * bs, -6 * bs, 10 * bs, 16 * bs), vest_color)
	# Watch chain
	draw_arc(Vector2(0, 2 * bs), 4 * bs, -0.5, PI + 0.5, 8, gold_color, 0.8 * bs)
	# Head
	draw_circle(Vector2(0, -15 * bs), 8 * bs, skin_color)
	# Receding hairline
	draw_arc(Vector2(0, -15 * bs), 8.5 * bs, PI + 0.4, 2 * PI - 0.4, 12, _apply_tint(Color(0.3, 0.3, 0.3), tint), 2.0 * bs)
	# Sinister eyes
	draw_circle(Vector2(-3 * bs, -16 * bs), 1.5 * bs, Color(0.15, 0.15, 0.15))
	draw_circle(Vector2(3 * bs, -16 * bs), 1.5 * bs, Color(0.15, 0.15, 0.15))
	draw_circle(Vector2(-3 * bs, -16 * bs), 0.6 * bs, Color(0.5, 0.4, 0.3))
	draw_circle(Vector2(3 * bs, -16 * bs), 0.6 * bs, Color(0.5, 0.4, 0.3))
	# Thin smile
	draw_arc(Vector2(0, -12 * bs), 3 * bs, 0.2, PI - 0.2, 8, Color(0.15, 0.15, 0.15), 0.8 * bs)
	# Top hat
	draw_rect(Rect2(-5 * bs, -28 * bs, 10 * bs, 12 * bs), hat_color)
	draw_rect(Rect2(-7 * bs, -18 * bs, 14 * bs, 2 * bs), hat_color)
	# Legs
	draw_rect(Rect2(-5 * bs, 14 * bs, 4 * bs, 5 * bs), suit_color)
	draw_rect(Rect2(1 * bs, 14 * bs, 4 * bs, 5 * bs), suit_color)


# =============================================================================
# THEME 8 — MERLIN DARK SORCERY
# =============================================================================

func _draw_merlin(s: float, tint: Color) -> void:
	match enemy_tier:
		0: _draw_dark_squire(s, tint)
		1: _draw_cursed_knight(s, tint)
		2: _draw_warlock(s, tint)
		3: _draw_morgan_le_fay(s, tint)

func _draw_dark_squire(s: float, tint: Color) -> void:
	var armor_color := _apply_tint(Color(0.45, 0.38, 0.3), tint)
	var rust_color := _apply_tint(Color(0.55, 0.35, 0.2), tint)
	var skin_color := _apply_tint(Color(0.82, 0.7, 0.58), tint)
	var shield_color := _apply_tint(Color(0.4, 0.35, 0.3), tint)
	# Body - rusted armor
	draw_rect(Rect2(-7 * s, -8 * s, 14 * s, 20 * s), armor_color)
	draw_circle(Vector2(-3 * s, -2 * s), 2.5 * s, rust_color)
	draw_circle(Vector2(4 * s, 4 * s), 2.0 * s, rust_color)
	draw_circle(Vector2(1 * s, 8 * s), 1.5 * s, rust_color)
	# Head
	draw_circle(Vector2(0, -14 * s), 7 * s, skin_color)
	# Simple helmet
	draw_arc(Vector2(0, -14 * s), 7.5 * s, PI, 2 * PI, 12, armor_color, 2.5 * s)
	draw_line(Vector2(0, -21 * s), Vector2(0, -14 * s), armor_color, 1.5 * s)
	# Eyes
	draw_circle(Vector2(-2.5 * s, -14.5 * s), 1.2 * s, Color(0.15, 0.15, 0.15))
	draw_circle(Vector2(2.5 * s, -14.5 * s), 1.2 * s, Color(0.15, 0.15, 0.15))
	# Small shield
	draw_rect(Rect2(-14 * s, -6 * s, 6 * s, 8 * s), shield_color)
	draw_line(Vector2(-11 * s, -6 * s), Vector2(-11 * s, 2 * s), rust_color, 1.0 * s)
	# Legs
	draw_rect(Rect2(-6 * s, 12 * s, 5 * s, 4 * s), armor_color)
	draw_rect(Rect2(1 * s, 12 * s, 5 * s, 4 * s), armor_color)

func _draw_cursed_knight(s: float, tint: Color) -> void:
	var armor_color := _apply_tint(Color(0.1, 0.1, 0.12), tint)
	var armor_light := _apply_tint(Color(0.18, 0.18, 0.22), tint)
	var visor_color := _apply_tint(Color(0.6, 0.15, 0.8), tint)
	var glow_color := _apply_tint(Color(0.5, 0.1, 0.7, 0.3), tint)
	# Dark armor body
	draw_rect(Rect2(-9 * s, -8 * s, 18 * s, 22 * s), armor_color)
	draw_rect(Rect2(-6 * s, -6 * s, 12 * s, 16 * s), armor_light)
	# Pauldrons
	draw_circle(Vector2(-10 * s, -6 * s), 4 * s, armor_color)
	draw_circle(Vector2(10 * s, -6 * s), 4 * s, armor_color)
	# Helmet
	draw_circle(Vector2(0, -14 * s), 8 * s, armor_color)
	draw_rect(Rect2(-6 * s, -16 * s, 12 * s, 4 * s), armor_light)
	# Glowing visor slit
	draw_line(Vector2(-4 * s, -14 * s), Vector2(4 * s, -14 * s), visor_color, 2.0 * s)
	draw_circle(Vector2(0, -14 * s), 10 * s, glow_color)
	# Dark plume
	draw_line(Vector2(0, -22 * s), Vector2(3 * s, -28 * s), _apply_tint(Color(0.3, 0.05, 0.05), tint), 2.5 * s)
	# Sword
	draw_line(Vector2(12 * s, -10 * s), Vector2(12 * s, 8 * s), _apply_tint(Color(0.25, 0.25, 0.28), tint), 2.0 * s)
	draw_line(Vector2(9 * s, -4 * s), Vector2(15 * s, -4 * s), armor_light, 1.5 * s)
	# Legs
	draw_rect(Rect2(-7 * s, 14 * s, 6 * s, 4 * s), armor_color)
	draw_rect(Rect2(1 * s, 14 * s, 6 * s, 4 * s), armor_color)

func _draw_warlock(s: float, tint: Color) -> void:
	var robe_color := _apply_tint(Color(0.15, 0.08, 0.2), tint)
	var robe_mid := _apply_tint(Color(0.25, 0.12, 0.35), tint)
	var skin_color := _apply_tint(Color(0.65, 0.6, 0.55), tint)
	var staff_color := _apply_tint(Color(0.3, 0.2, 0.1), tint)
	var orb_color := _apply_tint(Color(0.4, 0.9, 0.3), tint)
	# Robes
	draw_colored_polygon(PackedVector2Array([Vector2(-6 * s, -8 * s), Vector2(6 * s, -8 * s), Vector2(12 * s, 14 * s), Vector2(-12 * s, 14 * s)]), robe_color)
	draw_rect(Rect2(-7 * s, -8 * s, 14 * s, 18 * s), robe_color)
	draw_rect(Rect2(-4 * s, -6 * s, 8 * s, 14 * s), robe_mid)
	# Rune symbols on robe
	draw_circle(Vector2(0, 0), 1.5 * s, orb_color)
	draw_circle(Vector2(-3 * s, 4 * s), 1.0 * s, orb_color)
	draw_circle(Vector2(3 * s, 4 * s), 1.0 * s, orb_color)
	# Hood / head
	draw_colored_polygon(PackedVector2Array([Vector2(-6 * s, -12 * s), Vector2(0, -22 * s), Vector2(6 * s, -12 * s)]), robe_color)
	draw_circle(Vector2(0, -14 * s), 6 * s, skin_color)
	# Sinister eyes
	draw_circle(Vector2(-2 * s, -14 * s), 1.5 * s, _apply_tint(Color(0.9, 0.3, 0.1), tint))
	draw_circle(Vector2(2 * s, -14 * s), 1.5 * s, _apply_tint(Color(0.9, 0.3, 0.1), tint))
	# Staff
	draw_line(Vector2(10 * s, -20 * s), Vector2(10 * s, 14 * s), staff_color, 2.0 * s)
	draw_circle(Vector2(10 * s, -22 * s), 3 * s, orb_color)
	draw_circle(Vector2(10 * s, -22 * s), 1.5 * s, Color(0.8, 1.0, 0.7))
	# Feet peeking from robes
	draw_rect(Rect2(-5 * s, 14 * s, 4 * s, 2 * s), _apply_tint(Color(0.2, 0.15, 0.1), tint))
	draw_rect(Rect2(1 * s, 14 * s, 4 * s, 2 * s), _apply_tint(Color(0.2, 0.15, 0.1), tint))

func _draw_morgan_le_fay(s: float, tint: Color) -> void:
	var bs: float = s * 1.4
	var gown_color := _apply_tint(Color(0.2, 0.05, 0.3), tint)
	var gown_light := _apply_tint(Color(0.35, 0.1, 0.45), tint)
	var skin_color := _apply_tint(Color(0.75, 0.68, 0.6), tint)
	var crown_color := _apply_tint(Color(0.7, 0.2, 0.8), tint)
	var magic_color := _apply_tint(Color(0.5, 0.9, 0.4), tint)
	# Flowing gown
	draw_colored_polygon(PackedVector2Array([Vector2(-6 * bs, -8 * bs), Vector2(6 * bs, -8 * bs), Vector2(14 * bs, 16 * bs), Vector2(-14 * bs, 16 * bs)]), gown_color)
	draw_rect(Rect2(-7 * bs, -8 * bs, 14 * bs, 18 * bs), gown_color)
	draw_rect(Rect2(-4 * bs, -6 * bs, 8 * bs, 14 * bs), gown_light)
	# Magical runes on gown
	draw_arc(Vector2(0, 2 * bs), 3 * bs, 0, TAU, 8, magic_color, 0.8 * bs)
	draw_circle(Vector2(-4 * bs, 6 * bs), 1.0 * bs, magic_color)
	draw_circle(Vector2(4 * bs, 6 * bs), 1.0 * bs, magic_color)
	# Head
	draw_circle(Vector2(0, -15 * bs), 8 * bs, skin_color)
	# Dark hair
	draw_arc(Vector2(0, -15 * bs), 8.5 * bs, PI + 0.3, 2 * PI - 0.3, 12, Color(0.08, 0.05, 0.1), 3.0 * bs)
	draw_line(Vector2(-7 * bs, -12 * bs), Vector2(-9 * bs, -2 * bs), Color(0.08, 0.05, 0.1), 2.5 * bs)
	draw_line(Vector2(7 * bs, -12 * bs), Vector2(9 * bs, -2 * bs), Color(0.08, 0.05, 0.1), 2.5 * bs)
	# Eyes
	draw_circle(Vector2(-3 * bs, -16 * bs), 1.5 * bs, _apply_tint(Color(0.4, 0.9, 0.3), tint))
	draw_circle(Vector2(3 * bs, -16 * bs), 1.5 * bs, _apply_tint(Color(0.4, 0.9, 0.3), tint))
	# Sorceress crown
	draw_rect(Rect2(-6 * bs, -24 * bs, 12 * bs, 3 * bs), crown_color)
	draw_colored_polygon(PackedVector2Array([Vector2(-5 * bs, -24 * bs), Vector2(-3 * bs, -28 * bs), Vector2(-1 * bs, -24 * bs)]), crown_color)
	draw_colored_polygon(PackedVector2Array([Vector2(1 * bs, -24 * bs), Vector2(3 * bs, -28 * bs), Vector2(5 * bs, -24 * bs)]), crown_color)
	draw_circle(Vector2(0, -24 * bs), 1.5 * bs, magic_color)
	# Magical hands
	draw_circle(Vector2(-12 * bs, -2 * bs), 3 * bs, magic_color)
	draw_circle(Vector2(12 * bs, -2 * bs), 3 * bs, magic_color)
	draw_circle(Vector2(-12 * bs, -2 * bs), 1.5 * bs, Color(0.8, 1.0, 0.7))
	draw_circle(Vector2(12 * bs, -2 * bs), 1.5 * bs, Color(0.8, 1.0, 0.7))


# =============================================================================
# THEME 9 — TARZAN HUNTERS
# =============================================================================

func _draw_tarzan(s: float, tint: Color) -> void:
	match enemy_tier:
		0: _draw_poacher(s, tint)
		1: _draw_big_game_hunter(s, tint)
		2: _draw_mercenary(s, tint)
		3: _draw_clayton(s, tint)

func _draw_poacher(s: float, tint: Color) -> void:
	var shirt_color := _apply_tint(Color(0.55, 0.5, 0.35), tint)
	var skin_color := _apply_tint(Color(0.85, 0.72, 0.6), tint)
	var helmet_color := _apply_tint(Color(0.8, 0.75, 0.6), tint)
	var net_color := _apply_tint(Color(0.5, 0.45, 0.3), tint)
	# Body
	draw_rect(Rect2(-7 * s, -6 * s, 14 * s, 18 * s), shirt_color)
	draw_rect(Rect2(-8 * s, 4 * s, 16 * s, 2 * s), _apply_tint(Color(0.45, 0.35, 0.2), tint))
	# Head
	draw_circle(Vector2(0, -12 * s), 7 * s, skin_color)
	# Pith helmet
	draw_arc(Vector2(0, -12 * s), 8 * s, PI, 2 * PI, 12, helmet_color, 3.0 * s)
	draw_rect(Rect2(-4 * s, -20 * s, 8 * s, 5 * s), helmet_color)
	draw_rect(Rect2(-9 * s, -14 * s, 18 * s, 2 * s), helmet_color)
	# Eyes
	draw_circle(Vector2(-2.5 * s, -12 * s), 1.2 * s, Color(0.15, 0.15, 0.15))
	draw_circle(Vector2(2.5 * s, -12 * s), 1.2 * s, Color(0.15, 0.15, 0.15))
	# Net over shoulder
	for i in range(5):
		draw_line(Vector2(-12 * s + i * 3 * s, -4 * s), Vector2(-12 * s + i * 3 * s, 8 * s), net_color, 0.8 * s)
	for i in range(4):
		draw_line(Vector2(-12 * s, -4 * s + i * 3 * s), Vector2(0, -4 * s + i * 3 * s), net_color, 0.8 * s)
	# Legs
	draw_rect(Rect2(-6 * s, 12 * s, 5 * s, 4 * s), _apply_tint(Color(0.5, 0.45, 0.3), tint))
	draw_rect(Rect2(1 * s, 12 * s, 5 * s, 4 * s), _apply_tint(Color(0.5, 0.45, 0.3), tint))

func _draw_big_game_hunter(s: float, tint: Color) -> void:
	var khaki_color := _apply_tint(Color(0.65, 0.58, 0.4), tint)
	var khaki_dark := _apply_tint(Color(0.5, 0.45, 0.3), tint)
	var skin_color := _apply_tint(Color(0.82, 0.7, 0.58), tint)
	var rifle_color := _apply_tint(Color(0.4, 0.3, 0.2), tint)
	var metal_color := _apply_tint(Color(0.5, 0.5, 0.52), tint)
	# Body - khaki outfit
	draw_rect(Rect2(-8 * s, -8 * s, 16 * s, 22 * s), khaki_color)
	draw_rect(Rect2(-9 * s, 4 * s, 18 * s, 2 * s), khaki_dark)
	# Pockets
	draw_rect(Rect2(-6 * s, -2 * s, 4 * s, 4 * s), khaki_dark)
	draw_rect(Rect2(2 * s, -2 * s, 4 * s, 4 * s), khaki_dark)
	# Head
	draw_circle(Vector2(0, -14 * s), 7 * s, skin_color)
	# Safari hat
	draw_rect(Rect2(-9 * s, -17 * s, 18 * s, 2 * s), khaki_dark)
	draw_rect(Rect2(-5 * s, -22 * s, 10 * s, 6 * s), khaki_dark)
	# Eyes
	draw_circle(Vector2(-2.5 * s, -14 * s), 1.2 * s, Color(0.15, 0.15, 0.15))
	draw_circle(Vector2(2.5 * s, -14 * s), 1.2 * s, Color(0.15, 0.15, 0.15))
	# Mustache
	draw_line(Vector2(-3 * s, -11 * s), Vector2(3 * s, -11 * s), Color(0.3, 0.25, 0.15), 1.5 * s)
	# Rifle on back
	draw_line(Vector2(-6 * s, -18 * s), Vector2(8 * s, 10 * s), rifle_color, 2.0 * s)
	draw_line(Vector2(-6 * s, -18 * s), Vector2(-4 * s, -20 * s), metal_color, 1.5 * s)
	# Legs
	draw_rect(Rect2(-6 * s, 14 * s, 5 * s, 4 * s), khaki_dark)
	draw_rect(Rect2(1 * s, 14 * s, 5 * s, 4 * s), khaki_dark)
	# Boots
	draw_rect(Rect2(-7 * s, 18 * s, 6 * s, 2 * s), Color(0.3, 0.2, 0.15))
	draw_rect(Rect2(1 * s, 18 * s, 6 * s, 2 * s), Color(0.3, 0.2, 0.15))

func _draw_mercenary(s: float, tint: Color) -> void:
	var gear_color := _apply_tint(Color(0.25, 0.3, 0.2), tint)
	var gear_dark := _apply_tint(Color(0.15, 0.2, 0.12), tint)
	var skin_color := _apply_tint(Color(0.78, 0.65, 0.52), tint)
	var blade_color := _apply_tint(Color(0.7, 0.7, 0.75), tint)
	var strap_color := _apply_tint(Color(0.35, 0.25, 0.15), tint)
	# Combat vest
	draw_rect(Rect2(-9 * s, -8 * s, 18 * s, 22 * s), gear_color)
	draw_rect(Rect2(-7 * s, -6 * s, 14 * s, 18 * s), gear_dark)
	# Straps
	draw_line(Vector2(-6 * s, -8 * s), Vector2(4 * s, 6 * s), strap_color, 2.0 * s)
	draw_line(Vector2(6 * s, -8 * s), Vector2(-4 * s, 6 * s), strap_color, 2.0 * s)
	# Head
	draw_circle(Vector2(0, -14 * s), 7 * s, skin_color)
	# Bandana
	draw_rect(Rect2(-7 * s, -18 * s, 14 * s, 4 * s), _apply_tint(Color(0.15, 0.15, 0.12), tint))
	# Eyes - intense
	draw_line(Vector2(-4 * s, -14.5 * s), Vector2(-1 * s, -14 * s), Color(0.15, 0.15, 0.15), 1.5 * s)
	draw_line(Vector2(1 * s, -14 * s), Vector2(4 * s, -14.5 * s), Color(0.15, 0.15, 0.15), 1.5 * s)
	# Scar
	draw_line(Vector2(-4 * s, -16 * s), Vector2(-2 * s, -11 * s), Color(0.65, 0.4, 0.4), 0.8 * s)
	# Machete
	draw_line(Vector2(10 * s, -8 * s), Vector2(14 * s, 8 * s), blade_color, 2.5 * s)
	draw_rect(Rect2(9 * s, -10 * s, 3 * s, 4 * s), strap_color)
	# Legs
	draw_rect(Rect2(-7 * s, 14 * s, 6 * s, 4 * s), gear_color)
	draw_rect(Rect2(1 * s, 14 * s, 6 * s, 4 * s), gear_color)

func _draw_clayton(s: float, tint: Color) -> void:
	var bs: float = s * 1.4
	var suit_color := _apply_tint(Color(0.6, 0.55, 0.4), tint)
	var suit_dark := _apply_tint(Color(0.45, 0.4, 0.28), tint)
	var skin_color := _apply_tint(Color(0.85, 0.72, 0.6), tint)
	var hat_color := _apply_tint(Color(0.7, 0.65, 0.5), tint)
	var gun_color := _apply_tint(Color(0.35, 0.35, 0.38), tint)
	var wood_color := _apply_tint(Color(0.45, 0.3, 0.18), tint)
	# Safari suit
	draw_rect(Rect2(-9 * bs, -8 * bs, 18 * bs, 22 * bs), suit_color)
	draw_rect(Rect2(-6 * bs, -6 * bs, 12 * bs, 18 * bs), suit_dark)
	# Belt with ammo
	draw_rect(Rect2(-10 * bs, 4 * bs, 20 * bs, 3 * bs), _apply_tint(Color(0.4, 0.3, 0.15), tint))
	for i in range(5):
		draw_rect(Rect2(-8 * bs + i * 4 * bs, 4 * bs, 2 * bs, 3 * bs), _apply_tint(Color(0.7, 0.6, 0.2), tint))
	# Head
	draw_circle(Vector2(0, -15 * bs), 8 * bs, skin_color)
	# Thick jaw
	draw_rect(Rect2(-5 * bs, -12 * bs, 10 * bs, 4 * bs), skin_color)
	# Pith helmet
	draw_rect(Rect2(-10 * bs, -18 * bs, 20 * bs, 2 * bs), hat_color)
	draw_rect(Rect2(-6 * bs, -24 * bs, 12 * bs, 7 * bs), hat_color)
	# Sinister eyes
	draw_circle(Vector2(-3 * bs, -16 * bs), 1.5 * bs, Color(0.15, 0.15, 0.15))
	draw_circle(Vector2(3 * bs, -16 * bs), 1.5 * bs, Color(0.15, 0.15, 0.15))
	# Smirk
	draw_arc(Vector2(1 * bs, -12 * bs), 3 * bs, 0.3, PI - 0.5, 8, Color(0.15, 0.15, 0.15), 1.0 * bs)
	# Shotgun
	draw_rect(Rect2(10 * bs, -10 * bs, 8 * bs, 3 * bs), gun_color)
	draw_rect(Rect2(10 * bs, -7 * bs, 8 * bs, 4 * bs), wood_color)
	draw_circle(Vector2(18 * bs, -8.5 * bs), 2 * bs, Color(0.15, 0.15, 0.15))
	# Legs
	draw_rect(Rect2(-6 * bs, 14 * bs, 5 * bs, 5 * bs), suit_dark)
	draw_rect(Rect2(1 * bs, 14 * bs, 5 * bs, 5 * bs), suit_dark)
	# Boots
	draw_rect(Rect2(-7 * bs, 19 * bs, 6 * bs, 2 * bs), Color(0.25, 0.18, 0.12))
	draw_rect(Rect2(1 * bs, 19 * bs, 6 * bs, 2 * bs), Color(0.25, 0.18, 0.12))


# =============================================================================
# THEME 10 — DRACULA UNDEAD
# =============================================================================

func _draw_dracula(s: float, tint: Color) -> void:
	match enemy_tier:
		0: _draw_thrall(s, tint)
		1: _draw_dire_wolf(s, tint)
		2: _draw_vampire_bride(s, tint)
		3: _draw_count_dracula(s, tint)

func _draw_thrall(s: float, tint: Color) -> void:
	var rag_color := _apply_tint(Color(0.4, 0.38, 0.35), tint)
	var skin_color := _apply_tint(Color(0.7, 0.72, 0.68), tint)
	var eye_color := _apply_tint(Color(0.85, 0.2, 0.2), tint)
	# Tattered clothes
	draw_colored_polygon(PackedVector2Array([Vector2(-6 * s, -5 * s), Vector2(6 * s, -5 * s), Vector2(7 * s, 8 * s), Vector2(5 * s, 10 * s), Vector2(3 * s, 8 * s), Vector2(1 * s, 11 * s), Vector2(-2 * s, 8 * s), Vector2(-4 * s, 10 * s), Vector2(-7 * s, 7 * s)]), rag_color)
	# Arms - reaching forward
	draw_line(Vector2(-7 * s, -2 * s), Vector2(-12 * s, -6 * s), skin_color, 2.0 * s)
	draw_line(Vector2(7 * s, -2 * s), Vector2(12 * s, -6 * s), skin_color, 2.0 * s)
	# Pale head
	draw_circle(Vector2(0, -11 * s), 7 * s, skin_color)
	# Dark circles under eyes
	draw_circle(Vector2(-2.5 * s, -10.5 * s), 2.0 * s, _apply_tint(Color(0.4, 0.35, 0.4), tint))
	draw_circle(Vector2(2.5 * s, -10.5 * s), 2.0 * s, _apply_tint(Color(0.4, 0.35, 0.4), tint))
	# Glowing red eyes
	draw_circle(Vector2(-2.5 * s, -11 * s), 1.5 * s, eye_color)
	draw_circle(Vector2(2.5 * s, -11 * s), 1.5 * s, eye_color)
	draw_circle(Vector2(-2.5 * s, -11 * s), 0.7 * s, Color(1.0, 0.6, 0.6))
	draw_circle(Vector2(2.5 * s, -11 * s), 0.7 * s, Color(1.0, 0.6, 0.6))
	# Messy hair
	draw_circle(Vector2(-3 * s, -17 * s), 3 * s, _apply_tint(Color(0.3, 0.25, 0.2), tint))
	draw_circle(Vector2(2 * s, -17 * s), 3 * s, _apply_tint(Color(0.3, 0.25, 0.2), tint))
	# Legs
	draw_rect(Rect2(-5 * s, 10 * s, 4 * s, 5 * s), rag_color)
	draw_rect(Rect2(1 * s, 10 * s, 4 * s, 5 * s), rag_color)

func _draw_dire_wolf(s: float, tint: Color) -> void:
	var fur_color := _apply_tint(Color(0.3, 0.28, 0.25), tint)
	var fur_light := _apply_tint(Color(0.45, 0.42, 0.38), tint)
	var eye_color := _apply_tint(Color(0.9, 0.15, 0.1), tint)
	var fang_color := _apply_tint(Color(0.9, 0.88, 0.85), tint)
	# Body - large wolf
	draw_rect(Rect2(-12 * s, -4 * s, 24 * s, 10 * s), fur_color)
	draw_rect(Rect2(-8 * s, -2 * s, 16 * s, 6 * s), fur_light)
	# Tail
	draw_line(Vector2(-12 * s, -2 * s), Vector2(-18 * s, -8 * s), fur_color, 3.0 * s)
	# Head
	draw_circle(Vector2(8 * s, -10 * s), 7 * s, fur_color)
	draw_colored_polygon(PackedVector2Array([Vector2(8 * s, -10 * s), Vector2(14 * s, -8 * s), Vector2(12 * s, -4 * s)]), fur_light)
	# Ears
	draw_colored_polygon(PackedVector2Array([Vector2(4 * s, -14 * s), Vector2(6 * s, -20 * s), Vector2(8 * s, -14 * s)]), fur_color)
	draw_colored_polygon(PackedVector2Array([Vector2(10 * s, -14 * s), Vector2(12 * s, -20 * s), Vector2(14 * s, -14 * s)]), fur_color)
	# Red eyes
	draw_circle(Vector2(6 * s, -11 * s), 1.8 * s, eye_color)
	draw_circle(Vector2(10 * s, -11 * s), 1.8 * s, eye_color)
	draw_circle(Vector2(6 * s, -11 * s), 0.8 * s, Color(1.0, 0.5, 0.5))
	draw_circle(Vector2(10 * s, -11 * s), 0.8 * s, Color(1.0, 0.5, 0.5))
	# Fangs
	draw_line(Vector2(10 * s, -5 * s), Vector2(10 * s, -2 * s), fang_color, 1.0 * s)
	draw_line(Vector2(13 * s, -5 * s), Vector2(13 * s, -2 * s), fang_color, 1.0 * s)
	# Four legs
	draw_rect(Rect2(-11 * s, 6 * s, 4 * s, 7 * s), fur_color)
	draw_rect(Rect2(-5 * s, 6 * s, 4 * s, 7 * s), fur_color)
	draw_rect(Rect2(3 * s, 6 * s, 4 * s, 7 * s), fur_color)
	draw_rect(Rect2(9 * s, 6 * s, 4 * s, 7 * s), fur_color)

func _draw_vampire_bride(s: float, tint: Color) -> void:
	var dress_color := _apply_tint(Color(0.45, 0.08, 0.12), tint)
	var dress_light := _apply_tint(Color(0.6, 0.15, 0.2), tint)
	var skin_color := _apply_tint(Color(0.85, 0.85, 0.82), tint)
	var hair_color := _apply_tint(Color(0.1, 0.08, 0.08), tint)
	var fang_color := _apply_tint(Color(0.95, 0.92, 0.9), tint)
	# Flowing dress
	draw_colored_polygon(PackedVector2Array([Vector2(-6 * s, -6 * s), Vector2(6 * s, -6 * s), Vector2(12 * s, 14 * s), Vector2(-12 * s, 14 * s)]), dress_color)
	draw_rect(Rect2(-7 * s, -8 * s, 14 * s, 14 * s), dress_color)
	draw_rect(Rect2(-4 * s, -6 * s, 8 * s, 10 * s), dress_light)
	# Head
	draw_circle(Vector2(0, -14 * s), 7 * s, skin_color)
	# Long dark hair
	draw_line(Vector2(-6 * s, -14 * s), Vector2(-8 * s, 0), hair_color, 3.0 * s)
	draw_line(Vector2(6 * s, -14 * s), Vector2(8 * s, 0), hair_color, 3.0 * s)
	draw_arc(Vector2(0, -14 * s), 7.5 * s, PI + 0.3, 2 * PI - 0.3, 12, hair_color, 2.5 * s)
	# Red eyes
	draw_circle(Vector2(-2.5 * s, -14.5 * s), 1.5 * s, _apply_tint(Color(0.85, 0.15, 0.15), tint))
	draw_circle(Vector2(2.5 * s, -14.5 * s), 1.5 * s, _apply_tint(Color(0.85, 0.15, 0.15), tint))
	# Fangs
	draw_line(Vector2(-2 * s, -10 * s), Vector2(-2 * s, -7.5 * s), fang_color, 1.0 * s)
	draw_line(Vector2(2 * s, -10 * s), Vector2(2 * s, -7.5 * s), fang_color, 1.0 * s)
	# Blood drip on lip
	draw_circle(Vector2(0, -9 * s), 1.0 * s, _apply_tint(Color(0.7, 0.05, 0.05), tint))
	# Arms outstretched
	draw_line(Vector2(-7 * s, -4 * s), Vector2(-14 * s, -8 * s), skin_color, 2.0 * s)
	draw_line(Vector2(7 * s, -4 * s), Vector2(14 * s, -8 * s), skin_color, 2.0 * s)
	# Feet
	draw_rect(Rect2(-5 * s, 14 * s, 4 * s, 2 * s), dress_color)
	draw_rect(Rect2(1 * s, 14 * s, 4 * s, 2 * s), dress_color)

func _draw_count_dracula(s: float, tint: Color) -> void:
	var bs: float = s * 1.4
	var cape_color := _apply_tint(Color(0.08, 0.05, 0.1), tint)
	var cape_inner := _apply_tint(Color(0.55, 0.08, 0.1), tint)
	var suit_color := _apply_tint(Color(0.1, 0.1, 0.12), tint)
	var skin_color := _apply_tint(Color(0.85, 0.85, 0.8), tint)
	var eye_color := _apply_tint(Color(0.9, 0.15, 0.1), tint)
	var fang_color := _apply_tint(Color(0.95, 0.93, 0.9), tint)
	# Cape - outer
	draw_colored_polygon(PackedVector2Array([Vector2(-8 * bs, -12 * bs), Vector2(8 * bs, -12 * bs), Vector2(14 * bs, 18 * bs), Vector2(-14 * bs, 18 * bs)]), cape_color)
	# Cape - inner red lining
	draw_colored_polygon(PackedVector2Array([Vector2(-6 * bs, -10 * bs), Vector2(6 * bs, -10 * bs), Vector2(12 * bs, 16 * bs), Vector2(-12 * bs, 16 * bs)]), cape_inner)
	# Body
	draw_rect(Rect2(-7 * bs, -8 * bs, 14 * bs, 22 * bs), suit_color)
	draw_rect(Rect2(-4 * bs, -6 * bs, 8 * bs, 16 * bs), _apply_tint(Color(0.9, 0.88, 0.85), tint))
	# Medallion
	draw_circle(Vector2(0, -3 * bs), 2 * bs, _apply_tint(Color(0.85, 0.75, 0.15), tint))
	# Head
	draw_circle(Vector2(0, -15 * bs), 8 * bs, skin_color)
	# Widow's peak hair
	draw_colored_polygon(PackedVector2Array([Vector2(-7 * bs, -19 * bs), Vector2(0, -16 * bs), Vector2(7 * bs, -19 * bs), Vector2(7 * bs, -22 * bs), Vector2(-7 * bs, -22 * bs)]), Color(0.08, 0.06, 0.08))
	# Red eyes
	draw_circle(Vector2(-3 * bs, -16 * bs), 2.0 * bs, eye_color)
	draw_circle(Vector2(3 * bs, -16 * bs), 2.0 * bs, eye_color)
	draw_circle(Vector2(-3 * bs, -16 * bs), 1.0 * bs, Color(1.0, 0.5, 0.5))
	draw_circle(Vector2(3 * bs, -16 * bs), 1.0 * bs, Color(1.0, 0.5, 0.5))
	# Arched brows
	draw_line(Vector2(-5 * bs, -19 * bs), Vector2(-1.5 * bs, -18 * bs), Color(0.08, 0.06, 0.08), 1.0 * bs)
	draw_line(Vector2(5 * bs, -19 * bs), Vector2(1.5 * bs, -18 * bs), Color(0.08, 0.06, 0.08), 1.0 * bs)
	# Fangs
	draw_line(Vector2(-2 * bs, -11 * bs), Vector2(-2 * bs, -8 * bs), fang_color, 1.2 * bs)
	draw_line(Vector2(2 * bs, -11 * bs), Vector2(2 * bs, -8 * bs), fang_color, 1.2 * bs)
	# Sinister smile
	draw_arc(Vector2(0, -12 * bs), 3 * bs, 0.2, PI - 0.2, 8, _apply_tint(Color(0.5, 0.05, 0.05), tint), 0.8 * bs)
	# Cape collar - high
	draw_colored_polygon(PackedVector2Array([Vector2(-8 * bs, -12 * bs), Vector2(-10 * bs, -18 * bs), Vector2(-6 * bs, -10 * bs)]), cape_color)
	draw_colored_polygon(PackedVector2Array([Vector2(8 * bs, -12 * bs), Vector2(10 * bs, -18 * bs), Vector2(6 * bs, -10 * bs)]), cape_color)
	# Legs
	draw_rect(Rect2(-5 * bs, 14 * bs, 4 * bs, 5 * bs), suit_color)
	draw_rect(Rect2(1 * bs, 14 * bs, 4 * bs, 5 * bs), suit_color)


# =============================================================================
# THEME 11 — FRANKENSTEIN EXPERIMENTS
# =============================================================================

func _draw_frankenstein(s: float, tint: Color) -> void:
	match enemy_tier:
		0: _draw_lab_rat(s, tint)
		1: _draw_homunculus(s, tint)
		2: _draw_failed_experiment(s, tint)
		3: _draw_igor(s, tint)

func _draw_lab_rat(s: float, tint: Color) -> void:
	var fur_color := _apply_tint(Color(0.55, 0.5, 0.45), tint)
	var fur_light := _apply_tint(Color(0.7, 0.65, 0.6), tint)
	var eye_color := _apply_tint(Color(0.85, 0.2, 0.3), tint)
	var stitch_color := _apply_tint(Color(0.3, 0.25, 0.2), tint)
	# Oversized rat body
	draw_rect(Rect2(-10 * s, -4 * s, 20 * s, 12 * s), fur_color)
	draw_rect(Rect2(-6 * s, -2 * s, 12 * s, 8 * s), fur_light)
	# Head
	draw_circle(Vector2(6 * s, -10 * s), 7 * s, fur_color)
	draw_colored_polygon(PackedVector2Array([Vector2(6 * s, -10 * s), Vector2(14 * s, -8 * s), Vector2(11 * s, -5 * s)]), fur_light)
	# Ears
	draw_circle(Vector2(3 * s, -16 * s), 3 * s, _apply_tint(Color(0.7, 0.5, 0.5), tint))
	draw_circle(Vector2(10 * s, -16 * s), 3 * s, _apply_tint(Color(0.7, 0.5, 0.5), tint))
	# Eyes
	draw_circle(Vector2(4 * s, -11 * s), 1.8 * s, eye_color)
	draw_circle(Vector2(8 * s, -11 * s), 1.8 * s, eye_color)
	draw_circle(Vector2(4 * s, -11 * s), 0.8 * s, Color(0.15, 0.15, 0.15))
	draw_circle(Vector2(8 * s, -11 * s), 0.8 * s, Color(0.15, 0.15, 0.15))
	# Stitches across body
	draw_line(Vector2(-4 * s, -4 * s), Vector2(-4 * s, 6 * s), stitch_color, 1.0 * s)
	for i in range(4):
		draw_line(Vector2(-6 * s, -2 * s + i * 2 * s), Vector2(-2 * s, -2 * s + i * 2 * s), stitch_color, 0.8 * s)
	# Tail
	draw_arc(Vector2(-12 * s, -2 * s), 5 * s, PI * 0.5, PI * 1.5, 8, _apply_tint(Color(0.65, 0.5, 0.5), tint), 1.5 * s)
	# Legs
	draw_rect(Rect2(-9 * s, 8 * s, 4 * s, 5 * s), fur_color)
	draw_rect(Rect2(-3 * s, 8 * s, 4 * s, 5 * s), fur_color)
	draw_rect(Rect2(3 * s, 8 * s, 4 * s, 5 * s), fur_color)
	draw_rect(Rect2(9 * s, 8 * s, 4 * s, 5 * s), fur_color)

func _draw_homunculus(s: float, tint: Color) -> void:
	var body_color := _apply_tint(Color(0.5, 0.55, 0.45), tint)
	var body_dark := _apply_tint(Color(0.35, 0.4, 0.3), tint)
	var eye_color := _apply_tint(Color(0.9, 0.8, 0.2), tint)
	var stitch_color := _apply_tint(Color(0.25, 0.2, 0.15), tint)
	# Misshapen body — asymmetric
	draw_colored_polygon(PackedVector2Array([Vector2(-8 * s, -6 * s), Vector2(6 * s, -8 * s), Vector2(9 * s, 4 * s), Vector2(7 * s, 10 * s), Vector2(-5 * s, 12 * s), Vector2(-10 * s, 6 * s)]), body_color)
	draw_circle(Vector2(-4 * s, 0), 4 * s, body_dark)
	draw_circle(Vector2(3 * s, 2 * s), 3 * s, body_dark)
	# Lumpy head
	draw_circle(Vector2(-1 * s, -12 * s), 6 * s, body_color)
	draw_circle(Vector2(3 * s, -14 * s), 3 * s, body_color)
	# Mismatched eyes
	draw_circle(Vector2(-3 * s, -13 * s), 2.0 * s, eye_color)
	draw_circle(Vector2(2 * s, -12 * s), 1.2 * s, eye_color)
	draw_circle(Vector2(-3 * s, -13 * s), 1.0 * s, Color(0.15, 0.15, 0.15))
	draw_circle(Vector2(2 * s, -12 * s), 0.6 * s, Color(0.15, 0.15, 0.15))
	# Stitches
	draw_line(Vector2(-1 * s, -16 * s), Vector2(-1 * s, -8 * s), stitch_color, 1.0 * s)
	for i in range(3):
		draw_line(Vector2(-3 * s, -15 * s + i * 3 * s), Vector2(1 * s, -15 * s + i * 3 * s), stitch_color, 0.8 * s)
	# Arms — different lengths
	draw_line(Vector2(-8 * s, -2 * s), Vector2(-14 * s, 4 * s), body_color, 2.5 * s)
	draw_line(Vector2(6 * s, -4 * s), Vector2(10 * s, -2 * s), body_color, 2.0 * s)
	# Stumpy legs
	draw_rect(Rect2(-6 * s, 10 * s, 5 * s, 5 * s), body_dark)
	draw_rect(Rect2(2 * s, 10 * s, 4 * s, 5 * s), body_dark)

func _draw_failed_experiment(s: float, tint: Color) -> void:
	var body_color := _apply_tint(Color(0.4, 0.5, 0.38), tint)
	var body_dark := _apply_tint(Color(0.3, 0.38, 0.25), tint)
	var bolt_color := _apply_tint(Color(0.6, 0.6, 0.62), tint)
	var stitch_color := _apply_tint(Color(0.2, 0.18, 0.15), tint)
	var eye_color := _apply_tint(Color(0.9, 0.85, 0.3), tint)
	# Hulking asymmetric body
	draw_colored_polygon(PackedVector2Array([Vector2(-12 * s, -10 * s), Vector2(10 * s, -8 * s), Vector2(14 * s, 6 * s), Vector2(10 * s, 14 * s), Vector2(-8 * s, 14 * s), Vector2(-14 * s, 4 * s)]), body_color)
	# One shoulder bigger
	draw_circle(Vector2(-12 * s, -8 * s), 6 * s, body_dark)
	draw_circle(Vector2(10 * s, -6 * s), 4 * s, body_dark)
	# Chest patches
	draw_rect(Rect2(-6 * s, -4 * s, 8 * s, 6 * s), body_dark)
	draw_rect(Rect2(2 * s, 2 * s, 6 * s, 5 * s), body_dark)
	# Head — flat top
	draw_rect(Rect2(-6 * s, -20 * s, 14 * s, 12 * s), body_color)
	draw_rect(Rect2(-6 * s, -22 * s, 14 * s, 3 * s), body_dark)
	# Neck bolts
	draw_circle(Vector2(-7 * s, -12 * s), 2.0 * s, bolt_color)
	draw_circle(Vector2(9 * s, -12 * s), 2.0 * s, bolt_color)
	# Eyes — one droopy
	draw_circle(Vector2(-2 * s, -16 * s), 2.0 * s, eye_color)
	draw_circle(Vector2(4 * s, -15 * s), 1.5 * s, eye_color)
	draw_circle(Vector2(-2 * s, -16 * s), 1.0 * s, Color(0.15, 0.15, 0.15))
	draw_circle(Vector2(4 * s, -15 * s), 0.7 * s, Color(0.15, 0.15, 0.15))
	# Major stitch line
	draw_line(Vector2(1 * s, -22 * s), Vector2(1 * s, 14 * s), stitch_color, 1.5 * s)
	for i in range(8):
		draw_line(Vector2(-2 * s, -18 * s + i * 4 * s), Vector2(4 * s, -18 * s + i * 4 * s), stitch_color, 1.0 * s)
	# Arms — different sizes
	draw_line(Vector2(-14 * s, -4 * s), Vector2(-18 * s, 6 * s), body_color, 4.0 * s)
	draw_circle(Vector2(-18 * s, 6 * s), 3 * s, body_dark)
	draw_line(Vector2(12 * s, -2 * s), Vector2(14 * s, 4 * s), body_color, 3.0 * s)
	# Legs
	draw_rect(Rect2(-8 * s, 14 * s, 7 * s, 5 * s), body_dark)
	draw_rect(Rect2(2 * s, 14 * s, 6 * s, 5 * s), body_dark)

func _draw_igor(s: float, tint: Color) -> void:
	var bs: float = s * 1.4
	var coat_color := _apply_tint(Color(0.3, 0.28, 0.25), tint)
	var coat_dark := _apply_tint(Color(0.2, 0.18, 0.15), tint)
	var skin_color := _apply_tint(Color(0.72, 0.68, 0.6), tint)
	var tool_color := _apply_tint(Color(0.6, 0.6, 0.65), tint)
	var eye_color := _apply_tint(Color(0.9, 0.85, 0.3), tint)
	# Hunchback body — one side higher
	draw_colored_polygon(PackedVector2Array([Vector2(-8 * bs, -6 * bs), Vector2(6 * bs, -10 * bs), Vector2(10 * bs, 4 * bs), Vector2(8 * bs, 14 * bs), Vector2(-6 * bs, 14 * bs), Vector2(-10 * bs, 6 * bs)]), coat_color)
	# Hump
	draw_circle(Vector2(4 * bs, -12 * bs), 6 * bs, coat_dark)
	# Apron
	draw_rect(Rect2(-5 * bs, 0, 10 * bs, 14 * bs), _apply_tint(Color(0.5, 0.48, 0.45), tint))
	# Head — tilted
	draw_circle(Vector2(-2 * bs, -16 * bs), 7 * bs, skin_color)
	# Wild hair
	draw_circle(Vector2(-5 * bs, -21 * bs), 3 * bs, Color(0.2, 0.18, 0.15))
	draw_circle(Vector2(0, -22 * bs), 3 * bs, Color(0.2, 0.18, 0.15))
	draw_circle(Vector2(-3 * bs, -23 * bs), 2.5 * bs, Color(0.2, 0.18, 0.15))
	# Asymmetric eyes
	draw_circle(Vector2(-4 * bs, -17 * bs), 2.0 * bs, eye_color)
	draw_circle(Vector2(1 * bs, -16 * bs), 1.5 * bs, eye_color)
	draw_circle(Vector2(-4 * bs, -17 * bs), 1.0 * bs, Color(0.15, 0.15, 0.15))
	draw_circle(Vector2(1 * bs, -16 * bs), 0.7 * bs, Color(0.15, 0.15, 0.15))
	# Crooked grin
	draw_arc(Vector2(-2 * bs, -12 * bs), 3 * bs, 0.1, PI - 0.3, 8, Color(0.15, 0.15, 0.15), 0.8 * bs)
	# Tools in hand — wrench
	draw_line(Vector2(-10 * bs, -2 * bs), Vector2(-16 * bs, -6 * bs), tool_color, 2.0 * bs)
	draw_circle(Vector2(-16 * bs, -6 * bs), 2.5 * bs, tool_color)
	draw_circle(Vector2(-16 * bs, -6 * bs), 1.2 * bs, coat_dark)
	# Pliers in other hand
	draw_line(Vector2(8 * bs, 2 * bs), Vector2(14 * bs, -2 * bs), tool_color, 1.5 * bs)
	draw_line(Vector2(14 * bs, -2 * bs), Vector2(16 * bs, -5 * bs), tool_color, 1.5 * bs)
	draw_line(Vector2(14 * bs, -2 * bs), Vector2(17 * bs, -3 * bs), tool_color, 1.5 * bs)
	# Legs — one shorter
	draw_rect(Rect2(-6 * bs, 14 * bs, 5 * bs, 6 * bs), coat_dark)
	draw_rect(Rect2(2 * bs, 14 * bs, 5 * bs, 4 * bs), coat_dark)
	# Boot on short leg is thicker
	draw_rect(Rect2(1 * bs, 18 * bs, 7 * bs, 3 * bs), Color(0.15, 0.12, 0.1))


# =============================================================================
# THEME 12 — SHADOW AUTHOR
# =============================================================================

func _draw_shadow_author(s: float, tint: Color) -> void:
	match enemy_tier:
		0: _draw_ink_soldier(s, tint)
		1: _draw_corrupted_character(s, tint)
		2: _draw_shadow_beast(s, tint)
		3: _draw_the_author(s, tint)

func _draw_ink_soldier(s: float, tint: Color) -> void:
	var ink_color := _apply_tint(Color(0.08, 0.06, 0.1), tint)
	var ink_mid := _apply_tint(Color(0.15, 0.12, 0.18), tint)
	var drip_color := _apply_tint(Color(0.1, 0.08, 0.14, 0.6), tint)
	var eye_color := _apply_tint(Color(0.9, 0.85, 0.7), tint)
	# Soldier-shaped ink body
	draw_rect(Rect2(-7 * s, -8 * s, 14 * s, 22 * s), ink_color)
	draw_rect(Rect2(-5 * s, -6 * s, 10 * s, 18 * s), ink_mid)
	# Ink drips from body
	draw_line(Vector2(-6 * s, 10 * s), Vector2(-8 * s, 16 * s), drip_color, 2.0 * s)
	draw_line(Vector2(0, 12 * s), Vector2(1 * s, 18 * s), drip_color, 2.5 * s)
	draw_line(Vector2(5 * s, 10 * s), Vector2(7 * s, 16 * s), drip_color, 2.0 * s)
	# Head
	draw_circle(Vector2(0, -14 * s), 7 * s, ink_color)
	draw_circle(Vector2(0, -12 * s), 4 * s, ink_mid)
	# Glowing eyes
	draw_circle(Vector2(-2.5 * s, -14 * s), 1.5 * s, eye_color)
	draw_circle(Vector2(2.5 * s, -14 * s), 1.5 * s, eye_color)
	# Helmet outline in ink
	draw_arc(Vector2(0, -14 * s), 7.5 * s, PI, 2 * PI, 12, ink_mid, 2.0 * s)
	# Ink sword
	draw_line(Vector2(9 * s, -12 * s), Vector2(9 * s, 8 * s), ink_color, 2.5 * s)
	draw_line(Vector2(6 * s, -4 * s), Vector2(12 * s, -4 * s), ink_mid, 2.0 * s)
	# Dripping from sword
	draw_line(Vector2(9 * s, 8 * s), Vector2(10 * s, 13 * s), drip_color, 1.5 * s)
	# Legs
	draw_rect(Rect2(-6 * s, 14 * s, 5 * s, 3 * s), ink_color)
	draw_rect(Rect2(1 * s, 14 * s, 5 * s, 3 * s), ink_color)

func _draw_corrupted_character(s: float, tint: Color) -> void:
	var body_color := _apply_tint(Color(0.12, 0.08, 0.18), tint)
	var distort_color := _apply_tint(Color(0.3, 0.15, 0.4), tint)
	var glitch_color := _apply_tint(Color(0.6, 0.2, 0.7), tint)
	var eye_color := _apply_tint(Color(0.95, 0.9, 0.3), tint)
	# Distorted humanoid body
	draw_colored_polygon(PackedVector2Array([Vector2(-8 * s, -10 * s), Vector2(6 * s, -8 * s), Vector2(10 * s, 4 * s), Vector2(8 * s, 12 * s), Vector2(-6 * s, 14 * s), Vector2(-10 * s, 6 * s)]), body_color)
	# Glitch fragments floating off
	draw_rect(Rect2(-14 * s, -6 * s, 4 * s, 3 * s), distort_color)
	draw_rect(Rect2(10 * s, -4 * s, 3 * s, 4 * s), distort_color)
	draw_rect(Rect2(-12 * s, 4 * s, 3 * s, 3 * s), glitch_color)
	draw_rect(Rect2(12 * s, 2 * s, 2 * s, 3 * s), glitch_color)
	# Head — partially distorted
	draw_circle(Vector2(0, -14 * s), 7 * s, body_color)
	draw_rect(Rect2(2 * s, -18 * s, 5 * s, 4 * s), distort_color)
	# One normal eye, one glitching
	draw_circle(Vector2(-2.5 * s, -14 * s), 1.5 * s, eye_color)
	draw_rect(Rect2(1 * s, -16 * s, 4 * s, 2 * s), glitch_color)
	# Mouth — jagged
	draw_line(Vector2(-3 * s, -10 * s), Vector2(-1 * s, -9 * s), glitch_color, 1.0 * s)
	draw_line(Vector2(-1 * s, -9 * s), Vector2(1 * s, -11 * s), glitch_color, 1.0 * s)
	draw_line(Vector2(1 * s, -11 * s), Vector2(3 * s, -9 * s), glitch_color, 1.0 * s)
	# Static noise lines
	draw_line(Vector2(-6 * s, -2 * s), Vector2(6 * s, -2 * s), glitch_color, 0.8 * s)
	draw_line(Vector2(-4 * s, 4 * s), Vector2(8 * s, 4 * s), glitch_color, 0.8 * s)
	# Legs — one normal, one dissolving
	draw_rect(Rect2(-6 * s, 12 * s, 5 * s, 4 * s), body_color)
	draw_line(Vector2(2 * s, 12 * s), Vector2(3 * s, 16 * s), distort_color, 2.5 * s)
	draw_rect(Rect2(4 * s, 14 * s, 2 * s, 2 * s), distort_color)

func _draw_shadow_beast(s: float, tint: Color) -> void:
	var ink_color := _apply_tint(Color(0.05, 0.03, 0.08), tint)
	var ink_mid := _apply_tint(Color(0.12, 0.08, 0.18), tint)
	var eye_color := _apply_tint(Color(1.0, 0.4, 0.2), tint)
	var mouth_color := _apply_tint(Color(0.8, 0.15, 0.1), tint)
	var aura_color := _apply_tint(Color(0.3, 0.1, 0.4, 0.2), tint)
	# Massive dark aura
	draw_circle(Vector2(0, -2 * s), 22 * s, aura_color)
	# Hulking body
	draw_colored_polygon(PackedVector2Array([Vector2(-14 * s, -8 * s), Vector2(14 * s, -8 * s), Vector2(16 * s, 4 * s), Vector2(12 * s, 14 * s), Vector2(-12 * s, 14 * s), Vector2(-16 * s, 4 * s)]), ink_color)
	draw_circle(Vector2(-10 * s, -2 * s), 6 * s, ink_mid)
	draw_circle(Vector2(10 * s, -2 * s), 6 * s, ink_mid)
	draw_circle(Vector2(0, 4 * s), 7 * s, ink_mid)
	# Head
	draw_circle(Vector2(0, -14 * s), 9 * s, ink_color)
	# Multiple glowing eyes
	draw_circle(Vector2(-4 * s, -16 * s), 2.0 * s, eye_color)
	draw_circle(Vector2(4 * s, -16 * s), 2.0 * s, eye_color)
	draw_circle(Vector2(-2 * s, -12 * s), 1.5 * s, eye_color)
	draw_circle(Vector2(2 * s, -12 * s), 1.5 * s, eye_color)
	draw_circle(Vector2(0, -18 * s), 1.2 * s, eye_color)
	# Gaping maw
	draw_arc(Vector2(0, -10 * s), 4 * s, 0.2, PI - 0.2, 8, mouth_color, 2.0 * s)
	draw_line(Vector2(-3 * s, -9 * s), Vector2(-2 * s, -6 * s), Color(0.9, 0.9, 0.85), 1.0 * s)
	draw_line(Vector2(3 * s, -9 * s), Vector2(2 * s, -6 * s), Color(0.9, 0.9, 0.85), 1.0 * s)
	# Ink tentacle arms
	draw_line(Vector2(-14 * s, -4 * s), Vector2(-20 * s, -10 * s), ink_color, 3.0 * s)
	draw_line(Vector2(-20 * s, -10 * s), Vector2(-18 * s, -14 * s), ink_mid, 2.0 * s)
	draw_line(Vector2(14 * s, -4 * s), Vector2(20 * s, -10 * s), ink_color, 3.0 * s)
	draw_line(Vector2(20 * s, -10 * s), Vector2(18 * s, -14 * s), ink_mid, 2.0 * s)
	# Legs — thick pillars
	draw_rect(Rect2(-10 * s, 14 * s, 7 * s, 5 * s), ink_color)
	draw_rect(Rect2(3 * s, 14 * s, 7 * s, 5 * s), ink_color)

func _draw_the_author(s: float, tint: Color) -> void:
	var bs: float = s * 1.5
	var robe_color := _apply_tint(Color(0.06, 0.04, 0.1), tint)
	var robe_mid := _apply_tint(Color(0.15, 0.1, 0.25), tint)
	var skin_color := _apply_tint(Color(0.6, 0.58, 0.55), tint)
	var eye_color := _apply_tint(Color(1.0, 0.8, 0.2), tint)
	var quill_color := _apply_tint(Color(0.85, 0.8, 0.7), tint)
	var ink_glow := _apply_tint(Color(0.4, 0.15, 0.6, 0.3), tint)
	# Dark aura
	draw_circle(Vector2(0, -4 * bs), 26 * bs, ink_glow)
	# Flowing dark robes
	draw_colored_polygon(PackedVector2Array([Vector2(-8 * bs, -14 * bs), Vector2(8 * bs, -14 * bs), Vector2(16 * bs, 18 * bs), Vector2(8 * bs, 20 * bs), Vector2(0, 17 * bs), Vector2(-8 * bs, 20 * bs), Vector2(-16 * bs, 18 * bs)]), robe_color)
	draw_rect(Rect2(-9 * bs, -10 * bs, 18 * bs, 22 * bs), robe_color)
	draw_rect(Rect2(-6 * bs, -8 * bs, 12 * bs, 18 * bs), robe_mid)
	# Ink symbols on robe
	draw_arc(Vector2(0, 0), 4 * bs, 0, TAU, 10, _apply_tint(Color(0.4, 0.2, 0.6), tint), 0.8 * bs)
	draw_circle(Vector2(-4 * bs, 6 * bs), 1.5 * bs, _apply_tint(Color(0.4, 0.2, 0.6), tint))
	draw_circle(Vector2(4 * bs, 6 * bs), 1.5 * bs, _apply_tint(Color(0.4, 0.2, 0.6), tint))
	# Hood / head
	draw_colored_polygon(PackedVector2Array([Vector2(-8 * bs, -16 * bs), Vector2(0, -28 * bs), Vector2(8 * bs, -16 * bs), Vector2(6 * bs, -10 * bs), Vector2(-6 * bs, -10 * bs)]), robe_color)
	draw_circle(Vector2(0, -18 * bs), 7 * bs, skin_color)
	# Intense glowing eyes
	draw_circle(Vector2(-3 * bs, -19 * bs), 2.5 * bs, eye_color)
	draw_circle(Vector2(3 * bs, -19 * bs), 2.5 * bs, eye_color)
	draw_circle(Vector2(-3 * bs, -19 * bs), 1.2 * bs, Color(1.0, 1.0, 0.9))
	draw_circle(Vector2(3 * bs, -19 * bs), 1.2 * bs, Color(1.0, 1.0, 0.9))
	# Thin sinister mouth
	draw_arc(Vector2(0, -14 * bs), 3 * bs, 0.2, PI - 0.2, 8, Color(0.15, 0.1, 0.15), 1.0 * bs)
	# Giant quill in right hand
	draw_line(Vector2(10 * bs, -6 * bs), Vector2(18 * bs, -28 * bs), quill_color, 2.5 * bs)
	# Quill feather
	draw_colored_polygon(PackedVector2Array([Vector2(18 * bs, -28 * bs), Vector2(16 * bs, -34 * bs), Vector2(20 * bs, -32 * bs)]), quill_color)
	draw_colored_polygon(PackedVector2Array([Vector2(18 * bs, -28 * bs), Vector2(14 * bs, -32 * bs), Vector2(17 * bs, -34 * bs)]), _apply_tint(Color(0.7, 0.65, 0.55), tint))
	# Quill tip dripping ink
	draw_line(Vector2(10 * bs, -6 * bs), Vector2(9 * bs, 0), _apply_tint(Color(0.1, 0.06, 0.15), tint), 2.0 * bs)
	draw_circle(Vector2(9 * bs, 2 * bs), 2 * bs, _apply_tint(Color(0.1, 0.06, 0.15, 0.7), tint))
	# Left hand — open, commanding
	draw_circle(Vector2(-12 * bs, -4 * bs), 3 * bs, skin_color)
	draw_line(Vector2(-12 * bs, -4 * bs), Vector2(-16 * bs, -8 * bs), skin_color, 1.0 * bs)
	draw_line(Vector2(-12 * bs, -4 * bs), Vector2(-15 * bs, -6 * bs), skin_color, 1.0 * bs)
	draw_line(Vector2(-12 * bs, -4 * bs), Vector2(-15 * bs, -3 * bs), skin_color, 1.0 * bs)
	# Floating ink orbs around
	draw_circle(Vector2(-14 * bs, -14 * bs), 2.0 * bs, _apply_tint(Color(0.15, 0.08, 0.25, 0.6), tint))
	draw_circle(Vector2(14 * bs, -12 * bs), 1.5 * bs, _apply_tint(Color(0.15, 0.08, 0.25, 0.5), tint))
	draw_circle(Vector2(-10 * bs, 10 * bs), 1.8 * bs, _apply_tint(Color(0.15, 0.08, 0.25, 0.5), tint))
	# Base wisps
	draw_line(Vector2(-12 * bs, 18 * bs), Vector2(-14 * bs, 22 * bs), robe_mid, 2.0 * bs)
	draw_line(Vector2(0, 17 * bs), Vector2(0, 22 * bs), robe_mid, 2.5 * bs)
	draw_line(Vector2(12 * bs, 18 * bs), Vector2(14 * bs, 22 * bs), robe_mid, 2.0 * bs)
