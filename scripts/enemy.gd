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

func _ready() -> void:
	health = max_health
	rotates = false

func _process(delta: float) -> void:
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

func take_damage(amount: float) -> void:
	var mult = damage_mult * cheshire_mark_mult * charm_damage_mult
	var paint_mult = 1.0 + paint_stacks * 0.05
	var final_dmg = amount * mult * paint_mult
	health -= final_dmg
	_hit_flash = 0.12
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
	queue_free()

func _draw() -> void:
	var s: float = shrink_scale * boss_scale

	var tint: Color = Color.WHITE
	if _hit_flash > 0.0:
		tint = Color(1.0, 1.0, 1.0, 1.0)
	elif mark_timer > 0.0:
		tint = Color(0.85, 0.85, 0.95, 0.7)
	elif dot_timer > 0.0:
		tint = Color(0.6, 1.0, 0.6, 1.0)
	elif is_shrunk:
		tint = Color(0.7, 0.7, 1.0, 1.0)

	match enemy_theme:
		0: _draw_sherwood(s, tint)
		1: _draw_wonderland(s, tint)
		2: _draw_oz(s, tint)
		3: _draw_neverland(s, tint)
		4: _draw_opera(s, tint)
		5: _draw_victorian(s, tint)

	# Status effect visuals
	if sleep_timer > 0.0:
		# Zzz floating above
		draw_string(ThemeDB.fallback_font, Vector2(-8, -32 * s), "Zzz", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.6, 0.6, 1.0, 0.8))
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
