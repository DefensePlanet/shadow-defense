func _draw() -> void:
	# Selection ring (before grow transform)
	if is_selected:
		var pulse = (sin(_time * 3.0) + 1.0) * 0.5
		var ring_alpha = 0.5 + pulse * 0.3
		draw_arc(Vector2.ZERO, 36.0, 0, TAU, 48, Color(1.0, 0.84, 0.0, ring_alpha), 2.5)
		draw_arc(Vector2.ZERO, 39.0, 0, TAU, 48, Color(1.0, 0.84, 0.0, ring_alpha * 0.4), 1.5)

	# Range indicator (gameplay element — NOT scaled)
	draw_arc(Vector2.ZERO, attack_range, 0, TAU, 64, Color(1, 1, 1, 0.06), 1.0)

	# Apply grow scale — everything below this scales with Alice's growth
	var total_scale = _grow_scale + _grow_burst
	draw_set_transform(Vector2.ZERO, 0, Vector2(total_scale, total_scale))

	# Growth burst sparkle effect
	if _grow_burst > 0.0:
		var burst_radius = 60.0 + _grow_burst * 80.0
		draw_circle(Vector2.ZERO, burst_radius, Color(0.9, 0.8, 1.0, _grow_burst * 0.3))
		for i in range(8):
			var spark_angle = TAU * float(i) / 8.0 + _time * 2.0
			var spark_pos = Vector2.from_angle(spark_angle) * burst_radius * 0.8
			draw_circle(spark_pos, 3.0, Color(1.0, 0.95, 0.6, _grow_burst * 0.6))

	var dir = Vector2.from_angle(aim_angle)
	var perp = dir.rotated(PI / 2.0)

	# Breathing / idle animation
	var breathe = sin(_time * 2.0) * 3.0
	var breathe_dir = Vector2(0, breathe)

	# Dress sway
	var dress_sway = sin(_time * 1.8) * 5.0

	# Directional shading factor: light comes from top-left conceptually
	var shade_angle = aim_angle - PI * 0.25
	var shade_dir = Vector2.from_angle(shade_angle)

	# === Tier 4: Red glow aura ===
	if upgrade_tier >= 4:
		var aura_pulse = sin(_time * 3.0) * 0.04 + 0.18
		draw_circle(Vector2.ZERO, 76.0, Color(0.9, 0.15, 0.15, aura_pulse))
		draw_circle(Vector2.ZERO, 68.0, Color(0.95, 0.2, 0.1, aura_pulse * 0.6))
		# Red card particles orbiting
		for i in range(4):
			var card_a = _time * 1.2 + float(i) * TAU / 4.0
			var card_r = 70.0 + sin(_time * 2.0 + float(i)) * 5.0
			var cp = Vector2.from_angle(card_a) * card_r
			var cd = Vector2.from_angle(card_a + PI * 0.5)
			var cpperp = cd.rotated(PI / 2.0)
			# Card suit symbols (hearts and spades)
			if i % 2 == 0:
				draw_circle(cp - cpperp * 1.5, 2.5, Color(0.95, 0.15, 0.15, 0.7))
				draw_circle(cp + cpperp * 1.5, 2.5, Color(0.95, 0.15, 0.15, 0.7))
				draw_line(cp, cp - cd * 3.5, Color(0.95, 0.15, 0.15, 0.7), 2.5)
			else:
				draw_circle(cp - cpperp * 1.5, 2.5, Color(0.15, 0.15, 0.2, 0.7))
				draw_circle(cp + cpperp * 1.5, 2.5, Color(0.15, 0.15, 0.2, 0.7))
				draw_line(cp, cp + cd * 3.5, Color(0.15, 0.15, 0.2, 0.7), 2.0)

	# === Upgrade glow ring ===
	if upgrade_tier > 0:
		var glow_alpha = 0.1 + 0.03 * upgrade_tier
		var glow_col: Color
		match upgrade_tier:
			1: glow_col = Color(0.4, 0.6, 0.9, glow_alpha)
			2: glow_col = Color(0.7, 0.4, 0.8, glow_alpha)
			3: glow_col = Color(0.9, 0.7, 0.3, glow_alpha)
			4: glow_col = Color(0.9, 0.2, 0.2, glow_alpha + 0.08)
		draw_circle(Vector2.ZERO, 72.0, glow_col)

	# Upgrade flash
	if _upgrade_flash > 0.0:
		draw_circle(Vector2.ZERO, 80.0 + _upgrade_flash * 20.0, Color(0.8, 0.7, 1.0, _upgrade_flash * 0.25))

	# Cheshire flash (purple grin expanding)
	if _cheshire_flash > 0.0:
		draw_arc(Vector2.ZERO, 40.0 + (1.0 - _cheshire_flash) * 50.0, 0.3, 2.8, 16, Color(0.7, 0.3, 0.8, _cheshire_flash * 0.6), 5.0)

	# Tea party flash (golden burst)
	if _tea_flash > 0.0:
		draw_circle(Vector2.ZERO, 52.0 + (1.0 - _tea_flash) * 60.0, Color(0.9, 0.75, 0.3, _tea_flash * 0.3))

	# === T1+: Shrinking sparkles around Alice ===
	if upgrade_tier >= 1:
		for i in range(6):
			var sp_a = _time * 0.8 + float(i) * TAU / 6.0
			var sp_r = 50.0 + sin(_time * 1.5 + float(i) * 1.3) * 8.0
			var sp_pos = Vector2.from_angle(sp_a) * sp_r
			var sp_size = 2.5 + sin(_time * 3.0 + float(i) * 2.0) * 1.5
			var sp_alpha = 0.3 + sin(_time * 2.0 + float(i)) * 0.15
			# Star sparkle: draw 4 tiny lines as a cross
			draw_line(sp_pos - Vector2(sp_size, 0), sp_pos + Vector2(sp_size, 0), Color(0.6, 0.8, 1.0, sp_alpha), 1.0)
			draw_line(sp_pos - Vector2(0, sp_size), sp_pos + Vector2(0, sp_size), Color(0.6, 0.8, 1.0, sp_alpha), 1.0)
			draw_line(sp_pos - Vector2(sp_size, sp_size) * 0.6, sp_pos + Vector2(sp_size, sp_size) * 0.6, Color(0.7, 0.85, 1.0, sp_alpha * 0.6), 0.8)
			draw_line(sp_pos - Vector2(-sp_size, sp_size) * 0.6, sp_pos + Vector2(-sp_size, sp_size) * 0.6, Color(0.7, 0.85, 1.0, sp_alpha * 0.6), 0.8)

	# === Base — checkered tile (Wonderland floor) ===
	draw_circle(Vector2.ZERO, 64.0, Color(0.15, 0.12, 0.18))
	draw_circle(Vector2.ZERO, 60.0, Color(0.85, 0.82, 0.75))
	# Checker pattern (alternating dark/light)
	for i in range(8):
		var a = TAU * i / 8.0
		var check_pos = Vector2.from_angle(a) * 44.0
		var check_col = Color(0.2, 0.18, 0.22, 0.3) if i % 2 == 0 else Color(0.15, 0.13, 0.18, 0.2)
		draw_rect(Rect2(check_pos.x - 10, check_pos.y - 10, 20, 20), check_col)
	# Inner ring detail on base
	draw_arc(Vector2.ZERO, 42.0, 0, TAU, 32, Color(0.7, 0.68, 0.62, 0.15), 1.0)
	draw_arc(Vector2.ZERO, 58.0, 0, TAU, 32, Color(0.65, 0.62, 0.55, 0.2), 1.5)

	# Tier pips (radius 56)
	for i in range(upgrade_tier):
		var pip_angle = -PI / 2.0 + float(i) * (TAU / 4.0) - (float(upgrade_tier - 1) * TAU / 8.0)
		var pip_pos = Vector2.from_angle(pip_angle) * 56.0
		var pip_col: Color
		match i:
			0: pip_col = Color(0.4, 0.6, 0.95)
			1: pip_col = Color(0.7, 0.4, 0.85)
			2: pip_col = Color(0.95, 0.75, 0.3)
			3: pip_col = Color(0.95, 0.2, 0.2)
		draw_circle(pip_pos, 6.0, pip_col)
		# Pip inner shine
		draw_circle(pip_pos + Vector2(-1, -1), 2.5, Color(1, 1, 1, 0.3))

	# === T1+: "Drink Me" bottle near base ===
	if upgrade_tier >= 1:
		var bottle_pos = -dir * 36.0 - perp * 28.0
		# Bottle body (blue glass)
		draw_rect(Rect2(bottle_pos.x - 6, bottle_pos.y - 12, 12, 20), Color(0.2, 0.35, 0.75, 0.85))
		# Glass highlight
		draw_rect(Rect2(bottle_pos.x - 4, bottle_pos.y - 10, 3, 16), Color(0.4, 0.55, 0.9, 0.3))
		# Bottle neck
		draw_rect(Rect2(bottle_pos.x - 3, bottle_pos.y - 20, 6, 8), Color(0.25, 0.4, 0.8, 0.85))
		# Cork
		draw_rect(Rect2(bottle_pos.x - 4, bottle_pos.y - 24, 8, 4), Color(0.6, 0.45, 0.25))
		draw_rect(Rect2(bottle_pos.x - 3, bottle_pos.y - 23, 6, 2), Color(0.7, 0.55, 0.35, 0.5))
		# Label (cream parchment)
		draw_rect(Rect2(bottle_pos.x - 5, bottle_pos.y - 8, 10, 10), Color(0.95, 0.92, 0.85))
		draw_rect(Rect2(bottle_pos.x - 5, bottle_pos.y - 8, 10, 10), Color(0.7, 0.65, 0.5, 0.3))
		# "DM" text hint on label
		draw_line(Vector2(bottle_pos.x - 3, bottle_pos.y - 4), Vector2(bottle_pos.x - 1, bottle_pos.y - 4), Color(0.2, 0.15, 0.1), 1.2)
		draw_line(Vector2(bottle_pos.x + 1, bottle_pos.y - 4), Vector2(bottle_pos.x + 3, bottle_pos.y - 4), Color(0.2, 0.15, 0.1), 1.2)
		# Liquid shine
		draw_line(Vector2(bottle_pos.x - 2, bottle_pos.y - 10), Vector2(bottle_pos.x - 2, bottle_pos.y + 4), Color(0.5, 0.65, 1.0, 0.4), 1.5)
		# Liquid bubbles inside
		var bub_t = fmod(_time * 0.7, 3.0)
		draw_circle(Vector2(bottle_pos.x + 1, bottle_pos.y + 4 - bub_t * 5.0), 1.2, Color(0.6, 0.75, 1.0, max(0.0, 0.4 - bub_t * 0.15)))
		draw_circle(Vector2(bottle_pos.x - 2, bottle_pos.y + 2 - fmod(bub_t + 1.0, 3.0) * 4.0), 0.9, Color(0.6, 0.75, 1.0, max(0.0, 0.3 - bub_t * 0.1)))

	# === Shadow under feet ===
	draw_circle(-dir * 36.0, 18.0, Color(0.1, 0.08, 0.12, 0.22))
	draw_circle(-dir * 36.0, 14.0, Color(0.1, 0.08, 0.12, 0.12))
	draw_circle(-dir * 36.0 + shade_dir * 3.0, 16.0, Color(0.1, 0.08, 0.12, 0.08))

	# === White stockings & Mary Jane shoes ===
	# Left leg
	var leg_l_top = -dir * 24.0 - perp * 12.0 + breathe_dir
	var leg_l_bot = -dir * 38.0 - perp * 12.0
	# Right leg
	var leg_r_top = -dir * 24.0 + perp * 12.0 + breathe_dir
	var leg_r_bot = -dir * 38.0 + perp * 12.0

	# Leg outlines (dark)
	draw_line(leg_l_top, leg_l_bot, Color(0.08, 0.08, 0.1), 7.0)
	draw_line(leg_r_top, leg_r_bot, Color(0.08, 0.08, 0.1), 7.0)
	# White stockings base
	draw_line(leg_l_top, leg_l_bot, Color(0.95, 0.95, 0.95), 5.5)
	draw_line(leg_r_top, leg_r_bot, Color(0.95, 0.95, 0.95), 5.5)
	# Stocking highlights (subtle white sheen)
	var stk_hl_l = leg_l_top.lerp(leg_l_bot, 0.3) + perp * 1.0
	var stk_hl_l2 = leg_l_top.lerp(leg_l_bot, 0.7) + perp * 1.0
	draw_line(stk_hl_l, stk_hl_l2, Color(1.0, 1.0, 1.0, 0.35), 1.5)
	var stk_hl_r = leg_r_top.lerp(leg_r_bot, 0.3) - perp * 1.0
	var stk_hl_r2 = leg_r_top.lerp(leg_r_bot, 0.7) - perp * 1.0
	draw_line(stk_hl_r, stk_hl_r2, Color(1.0, 1.0, 1.0, 0.35), 1.5)
	# Stocking top band (where stockings meet the dress)
	draw_line(leg_l_top - perp * 3.0, leg_l_top + perp * 3.0, Color(0.88, 0.88, 0.9), 2.0)
	draw_line(leg_r_top - perp * 3.0, leg_r_top + perp * 3.0, Color(0.88, 0.88, 0.9), 2.0)
	# Subtle knee shading
	var knee_l = leg_l_top.lerp(leg_l_bot, 0.45)
	var knee_r = leg_r_top.lerp(leg_r_bot, 0.45)
	draw_circle(knee_l, 3.5, Color(0.88, 0.88, 0.9, 0.2))
	draw_circle(knee_r, 3.5, Color(0.88, 0.88, 0.9, 0.2))

	# Mary Jane shoes
	var shoe_l = leg_l_bot
	var shoe_r = leg_r_bot
	# Shoe sole (slightly below)
	draw_circle(shoe_l - dir * 2.0, 7.5, Color(0.04, 0.04, 0.04))
	draw_circle(shoe_r - dir * 2.0, 7.5, Color(0.04, 0.04, 0.04))
	# Shoe body (patent leather black)
	draw_circle(shoe_l, 7.0, Color(0.1, 0.1, 0.1))
	draw_circle(shoe_r, 7.0, Color(0.1, 0.1, 0.1))
	# Shoe top curve (rounded toe shape)
	draw_arc(shoe_l, 7.0, aim_angle + PI * 0.6, aim_angle + PI * 1.4, 12, Color(0.15, 0.15, 0.18), 1.5)
	draw_arc(shoe_r, 7.0, aim_angle + PI * 0.6, aim_angle + PI * 1.4, 12, Color(0.15, 0.15, 0.18), 1.5)
	# Shoe shine highlight (patent leather gloss)
	draw_circle(shoe_l + dir * 2.5 + perp * 0.8, 2.5, Color(0.4, 0.4, 0.5, 0.5))
	draw_circle(shoe_l + dir * 1.0 + perp * 2.0, 1.2, Color(0.5, 0.5, 0.6, 0.3))
	draw_circle(shoe_r + dir * 2.5 - perp * 0.8, 2.5, Color(0.4, 0.4, 0.5, 0.5))
	draw_circle(shoe_r + dir * 1.0 - perp * 2.0, 1.2, Color(0.5, 0.5, 0.6, 0.3))
	# Shoe straps (Mary Jane style)
	draw_arc(shoe_l, 7.0, aim_angle + PI * 0.5, aim_angle + PI * 1.5, 10, Color(0.15, 0.15, 0.15), 2.0)
	draw_arc(shoe_r, 7.0, aim_angle + PI * 0.5, aim_angle + PI * 1.5, 10, Color(0.15, 0.15, 0.15), 2.0)
	# Strap highlight
	draw_arc(shoe_l, 6.5, aim_angle + PI * 0.7, aim_angle + PI * 1.3, 8, Color(0.25, 0.25, 0.28, 0.3), 1.0)
	draw_arc(shoe_r, 6.5, aim_angle + PI * 0.7, aim_angle + PI * 1.3, 8, Color(0.25, 0.25, 0.28, 0.3), 1.0)
	# Buckles (gold button on each strap)
	var buckle_l = shoe_l + dir * 5.0
	var buckle_r = shoe_r + dir * 5.0
	draw_circle(buckle_l, 2.0, Color(0.75, 0.65, 0.3))
	draw_circle(buckle_r, 2.0, Color(0.75, 0.65, 0.3))
	draw_circle(buckle_l + Vector2(-0.5, -0.5), 0.9, Color(0.95, 0.9, 0.6, 0.7))
	draw_circle(buckle_r + Vector2(-0.5, -0.5), 0.9, Color(0.95, 0.9, 0.6, 0.7))

	# === BLUE DRESS (Tenniel-accurate) — with sway ===
	# Dress shadow layer
	var dress_shadow_pts = PackedVector2Array([
		-dir * 25.0 - perp * 31.0 - perp * dress_sway,
		-dir * 25.0 + perp * 31.0 + perp * dress_sway,
		dir * 5.0 + perp * 25.0 + breathe_dir,
		dir * 5.0 - perp * 25.0 + breathe_dir,
	])
	draw_colored_polygon(dress_shadow_pts, Color(0.15, 0.3, 0.55, 0.5))
	# Main dress body (rich blue)
	var dress_pts = PackedVector2Array([
		-dir * 24.0 - perp * 30.0 - perp * dress_sway,
		-dir * 24.0 + perp * 30.0 + perp * dress_sway,
		dir * 6.0 + perp * 24.0 + breathe_dir,
		dir * 6.0 - perp * 24.0 + breathe_dir,
	])
	draw_colored_polygon(dress_pts, Color(0.3, 0.5, 0.82))
	# Dress lighter panel (center highlight for volume)
	var dress_hl_pts = PackedVector2Array([
		-dir * 22.0 - perp * 10.0 - perp * dress_sway * 0.3,
		-dir * 22.0 + perp * 10.0 + perp * dress_sway * 0.3,
		dir * 5.0 + perp * 8.0 + breathe_dir,
		dir * 5.0 - perp * 8.0 + breathe_dir,
	])
	draw_colored_polygon(dress_hl_pts, Color(0.38, 0.58, 0.88, 0.35))
	# Dress fabric folds
	for i in range(8):
		var t_val = float(i + 1) / 9.0
		var fold_top = (dir * 6.0 + breathe_dir).lerp(-dir * 24.0, t_val)
		var fold_spread = lerp(24.0, 30.0 + abs(dress_sway), t_val)
		var fold_alpha = 0.35 + 0.15 * sin(float(i) * 1.2)
		var fold_width = 1.2 + 0.4 * sin(float(i) * 0.8)
		# Left side fold
		var fl_start = fold_top - perp * (fold_spread * 0.2)
		var fl_mid = fold_top - perp * (fold_spread * 0.5) - dir * (1.5 * sin(float(i) * 0.9))
		var fl_end = fold_top - perp * (fold_spread * 0.75)
		draw_line(fl_start, fl_mid, Color(0.2, 0.38, 0.65, fold_alpha), fold_width)
		draw_line(fl_mid, fl_end, Color(0.2, 0.38, 0.65, fold_alpha * 0.8), fold_width)
		# Right side fold
		var fr_start = fold_top + perp * (fold_spread * 0.2)
		var fr_mid = fold_top + perp * (fold_spread * 0.5) - dir * (1.5 * sin(float(i) * 0.9 + 0.5))
		var fr_end = fold_top + perp * (fold_spread * 0.75)
		draw_line(fr_start, fr_mid, Color(0.2, 0.38, 0.65, fold_alpha), fold_width)
		draw_line(fr_mid, fr_end, Color(0.2, 0.38, 0.65, fold_alpha * 0.8), fold_width)
	# Dress highlight streaks
	for i in range(4):
		var t_val = float(i + 1) / 5.0
		var hl_pos = (dir * 6.0 + breathe_dir).lerp(-dir * 24.0, t_val)
		var hl_spread = lerp(24.0, 30.0, t_val)
		draw_line(hl_pos - perp * (hl_spread * 0.1), hl_pos - perp * (hl_spread * 0.3), Color(0.45, 0.65, 0.95, 0.2), 2.0)
		draw_line(hl_pos + perp * (hl_spread * 0.15), hl_pos + perp * (hl_spread * 0.35), Color(0.45, 0.65, 0.95, 0.15), 1.5)
	# Dress hem detail line
	draw_line(-dir * 24.0 - perp * 30.0 - perp * dress_sway, -dir * 24.0 + perp * 30.0 + perp * dress_sway, Color(0.18, 0.32, 0.58), 2.5)
	# Dress hem darker shadow edge
	draw_line(-dir * 24.5 - perp * 29.5 - perp * dress_sway, -dir * 24.5 + perp * 29.5 + perp * dress_sway, Color(0.12, 0.25, 0.45, 0.5), 1.5)
	# Dress hem scallop detail (decorative wavy edge)
	for i in range(10):
		var ht = float(i) / 10.0
		var hem_p = (-dir * 24.0 - perp * 30.0 - perp * dress_sway).lerp(-dir * 24.0 + perp * 30.0 + perp * dress_sway, ht)
		draw_circle(hem_p - dir * 1.5, 3.0, Color(0.25, 0.42, 0.72, 0.2))

	# === White pinafore over dress ===
	# Pinafore shadow
	var apron_shadow_pts = PackedVector2Array([
		-dir * 18.5 - perp * 18.5,
		-dir * 18.5 + perp * 18.5,
		dir * 2.5 + perp * 15.5 + breathe_dir,
		dir * 2.5 - perp * 15.5 + breathe_dir,
	])
	draw_colored_polygon(apron_shadow_pts, Color(0.82, 0.82, 0.78, 0.4))
	# Main pinafore (bright white)
	var apron_pts = PackedVector2Array([
		-dir * 18.0 - perp * 18.0,
		-dir * 18.0 + perp * 18.0,
		dir * 3.0 + perp * 15.0 + breathe_dir,
		dir * 3.0 - perp * 15.0 + breathe_dir,
	])
	draw_colored_polygon(apron_pts, Color(0.97, 0.97, 0.95))
	# Pinafore subtle center crease highlight
	draw_line(dir * 3.0 + breathe_dir, -dir * 16.0, Color(1.0, 1.0, 1.0, 0.25), 2.0)
	# Pinafore lace edge detail (zigzag along bottom hem)
	var lace_left = -dir * 18.0 - perp * 18.0
	var lace_right = -dir * 18.0 + perp * 18.0
	for li in range(14):
		var lt0 = float(li) / 14.0
		var lt1 = float(li + 0.5) / 14.0
		var lt2 = float(li + 1) / 14.0
		var lp0 = lace_left.lerp(lace_right, lt0)
		var lp_mid = lace_left.lerp(lace_right, lt1) - dir * 4.0
		var lp1 = lace_left.lerp(lace_right, lt2)
		draw_line(lp0, lp_mid, Color(0.92, 0.92, 0.9, 0.75), 1.3)
		draw_line(lp_mid, lp1, Color(0.92, 0.92, 0.9, 0.75), 1.3)
		# Tiny dot at each lace peak
		draw_circle(lp_mid, 1.0, Color(0.88, 0.88, 0.86, 0.5))
	# Side lace trim on pinafore (left and right edges)
	for side_sign in [-1.0, 1.0]:
		var side_top = dir * 3.0 + perp * 15.0 * side_sign + breathe_dir
		var side_bot = -dir * 18.0 + perp * 18.0 * side_sign
		for li2 in range(6):
			var st = float(li2) / 6.0
			var sp = side_top.lerp(side_bot, st)
			var sp2 = side_top.lerp(side_bot, st + 0.08)
			draw_line(sp, sp + perp * side_sign * 2.5, Color(0.9, 0.9, 0.88, 0.4), 0.8)
	# Apron straps (wider, more visible)
	draw_line(dir * 3.0 - perp * 15.0 + breathe_dir, dir * 15.0 - perp * 9.0 + breathe_dir, Color(0.94, 0.94, 0.92), 4.0)
	draw_line(dir * 3.0 + perp * 15.0 + breathe_dir, dir * 15.0 + perp * 9.0 + breathe_dir, Color(0.94, 0.94, 0.92), 4.0)
	# Strap edge detail
	draw_line(dir * 3.0 - perp * 15.0 + breathe_dir, dir * 15.0 - perp * 9.0 + breathe_dir, Color(0.82, 0.82, 0.78, 0.4), 1.0)
	draw_line(dir * 3.0 + perp * 15.0 + breathe_dir, dir * 15.0 + perp * 9.0 + breathe_dir, Color(0.82, 0.82, 0.78, 0.4), 1.0)
	# Button details on pinafore bib (two small buttons)
	var btn1 = dir * 0.0 + breathe_dir
	var btn2 = -dir * 6.0 + breathe_dir * 0.5
	draw_circle(btn1, 2.0, Color(0.85, 0.85, 0.82))
	draw_arc(btn1, 2.0, 0, TAU, 8, Color(0.75, 0.75, 0.72), 0.8)
	draw_circle(btn1 + Vector2(-0.5, -0.5), 0.7, Color(1.0, 1.0, 1.0, 0.4))
	draw_circle(btn2, 2.0, Color(0.85, 0.85, 0.82))
	draw_arc(btn2, 2.0, 0, TAU, 8, Color(0.75, 0.75, 0.72), 0.8)
	draw_circle(btn2 + Vector2(-0.5, -0.5), 0.7, Color(1.0, 1.0, 1.0, 0.4))
	# Button holes (tiny dots)
	draw_circle(btn1 - perp * 0.5, 0.5, Color(0.6, 0.6, 0.58))
	draw_circle(btn1 + perp * 0.5, 0.5, Color(0.6, 0.6, 0.58))
	draw_circle(btn2 - perp * 0.5, 0.5, Color(0.6, 0.6, 0.58))
	draw_circle(btn2 + perp * 0.5, 0.5, Color(0.6, 0.6, 0.58))
	# Pinafore wrinkle details
	draw_line(-dir * 3.0 - perp * 5.0 + breathe_dir, -dir * 12.0 - perp * 10.0, Color(0.88, 0.88, 0.85, 0.4), 1.2)
	draw_line(-dir * 3.0 + perp * 5.0 + breathe_dir, -dir * 12.0 + perp * 10.0, Color(0.88, 0.88, 0.85, 0.4), 1.2)
	draw_line(-dir * 6.0 - perp * 1.5 + breathe_dir, -dir * 15.0 - perp * 3.0, Color(0.88, 0.88, 0.85, 0.35), 1.0)
	draw_line(-dir * 6.0 + perp * 1.5 + breathe_dir, -dir * 15.0 + perp * 3.0, Color(0.88, 0.88, 0.85, 0.35), 1.0)
	draw_line(-dir * 9.0 - perp * 8.0 + breathe_dir, -dir * 16.0 - perp * 14.0, Color(0.88, 0.88, 0.85, 0.3), 1.0)
	draw_line(-dir * 9.0 + perp * 8.0 + breathe_dir, -dir * 16.0 + perp * 14.0, Color(0.88, 0.88, 0.85, 0.3), 1.0)
	# Apron bow at back — visible loops and tails
	var bow_center = -dir * 18.0
	# Left bow loop
	draw_arc(bow_center - perp * 12.0, 7.0, aim_angle + PI * 0.2, aim_angle + PI * 1.3, 12, Color(0.95, 0.95, 0.92), 3.0)
	draw_arc(bow_center - perp * 12.0, 7.0, aim_angle + PI * 0.2, aim_angle + PI * 1.3, 12, Color(0.85, 0.85, 0.82, 0.3), 1.0)
	# Right bow loop
	draw_arc(bow_center + perp * 12.0, 7.0, aim_angle - PI * 0.3, aim_angle + PI * 0.8, 12, Color(0.95, 0.95, 0.92), 3.0)
	draw_arc(bow_center + perp * 12.0, 7.0, aim_angle - PI * 0.3, aim_angle + PI * 0.8, 12, Color(0.85, 0.85, 0.82, 0.3), 1.0)
	# Bow knot center
	draw_circle(bow_center, 3.5, Color(0.93, 0.93, 0.9))
	draw_arc(bow_center, 3.5, 0, TAU, 8, Color(0.82, 0.82, 0.78), 1.0)
	# Bow wrinkle at center
	draw_line(bow_center - perp * 1.5, bow_center + perp * 1.5, Color(0.82, 0.82, 0.78, 0.5), 0.8)
	# Bow tails (dangling ribbons with slight curve)
	draw_line(bow_center - perp * 4.0, bow_center - dir * 10.0 - perp * 8.0, Color(0.94, 0.94, 0.92), 2.8)
	draw_line(bow_center + perp * 4.0, bow_center - dir * 10.0 + perp * 8.0, Color(0.94, 0.94, 0.92), 2.8)
	# Tail ends (pointed, with flutter)
	var tail_flutter = sin(_time * 2.5) * 2.0
	draw_line(bow_center - dir * 10.0 - perp * 8.0, bow_center - dir * 14.0 - perp * 6.0 + perp * tail_flutter, Color(0.92, 0.92, 0.9), 2.0)
	draw_line(bow_center - dir * 10.0 + perp * 8.0, bow_center - dir * 14.0 + perp * 6.0 + perp * tail_flutter, Color(0.92, 0.92, 0.9), 2.0)

	# === Collar / neckline detail (Peter Pan collar) ===
	var collar_center = dir * 8.0 + breathe_dir
	# Left collar flap
	draw_arc(collar_center - perp * 6.0, 9.0, aim_angle + PI * 0.25, aim_angle + PI * 0.95, 10, Color(0.97, 0.97, 0.95), 4.0)
	draw_arc(collar_center - perp * 6.0, 9.0, aim_angle + PI * 0.25, aim_angle + PI * 0.95, 10, Color(0.85, 0.85, 0.82, 0.4), 1.0)
	# Right collar flap
	draw_arc(collar_center + perp * 6.0, 9.0, aim_angle + PI * 0.05, aim_angle + PI * 0.75, 10, Color(0.97, 0.97, 0.95), 4.0)
	draw_arc(collar_center + perp * 6.0, 9.0, aim_angle + PI * 0.05, aim_angle + PI * 0.75, 10, Color(0.85, 0.85, 0.82, 0.4), 1.0)
	# Collar center point
	draw_circle(collar_center + dir * 3.0, 2.0, Color(0.97, 0.97, 0.95))

	# === Body / torso area (shoulder reference) ===
	var body_center = dir * 6.0 + breathe_dir
	var shoulder_left = -perp * 24.0 + breathe_dir
	var shoulder_right = perp * 24.0 + breathe_dir

	# Puffed sleeves (Tenniel-style blue, puffy and gathered)
	# Left sleeve shadow
	draw_circle(shoulder_left - shade_dir * 1.5, 13.0, Color(0.2, 0.35, 0.6, 0.4))
	# Left sleeve body
	draw_circle(shoulder_left, 12.0, Color(0.3, 0.5, 0.82))
	# Left sleeve highlight (puff)
	draw_circle(shoulder_left + shade_dir * 2.0, 8.0, Color(0.4, 0.6, 0.9, 0.4))
	draw_circle(shoulder_left + shade_dir * 3.0, 5.0, Color(0.5, 0.7, 0.95, 0.25))
	# Sleeve outline
	draw_arc(shoulder_left, 12.0, 0, TAU, 16, Color(0.2, 0.38, 0.65), 1.5)
	# Gathering lines on left sleeve
	for gi in range(5):
		var ga = aim_angle + PI * 0.2 + float(gi) * 0.4
		draw_arc(shoulder_left, 7.0 + float(gi) * 1.0, ga - 0.2, ga + 0.2, 6, Color(0.22, 0.4, 0.68, 0.45), 1.2)
	# Sleeve cuff band (white)
	draw_arc(shoulder_left, 12.5, aim_angle + PI * 0.8, aim_angle + PI * 1.2, 8, Color(0.95, 0.95, 0.93), 2.5)

	# Right sleeve shadow
	draw_circle(shoulder_right - shade_dir * 1.5, 13.0, Color(0.2, 0.35, 0.6, 0.4))
	# Right sleeve body
	draw_circle(shoulder_right, 12.0, Color(0.3, 0.5, 0.82))
	# Right sleeve highlight
	draw_circle(shoulder_right + shade_dir * 2.0, 8.0, Color(0.4, 0.6, 0.9, 0.4))
	draw_circle(shoulder_right + shade_dir * 3.0, 5.0, Color(0.5, 0.7, 0.95, 0.25))
	# Sleeve outline
	draw_arc(shoulder_right, 12.0, 0, TAU, 16, Color(0.2, 0.38, 0.65), 1.5)
	# Gathering lines on right sleeve
	for gi in range(5):
		var ga = aim_angle + PI * 0.2 + float(gi) * 0.4
		draw_arc(shoulder_right, 7.0 + float(gi) * 1.0, ga - 0.2, ga + 0.2, 6, Color(0.22, 0.4, 0.68, 0.45), 1.2)
	# Sleeve cuff band (white)
	draw_arc(shoulder_right, 12.5, aim_angle + PI * 0.8, aim_angle + PI * 1.2, 8, Color(0.95, 0.95, 0.93), 2.5)

	# === Arms and card hand ===
	var attack_extend = _attack_anim * 12.0
	# Attack pose: arm swings forward during card throw
	var arm_swing = _attack_anim * 0.3
	var card_hand = dir * (30.0 + attack_extend) + perp * 6.0 + breathe_dir
	# Right arm outline (dark edge)
	draw_line(shoulder_right + breathe_dir, card_hand, Color(0.72, 0.58, 0.42), 6.5)
	# Right arm skin
	draw_line(shoulder_right + breathe_dir, card_hand, Color(0.92, 0.8, 0.68), 5.0)
	# Arm shading (subtle)
	var arm_mid_r = (shoulder_right + breathe_dir + card_hand) * 0.5
	draw_circle(arm_mid_r, 3.5, Color(0.85, 0.72, 0.58, 0.2))
	# Left arm outline
	var left_hand = card_hand - perp * 12.0
	draw_line(shoulder_left + breathe_dir, left_hand, Color(0.72, 0.58, 0.42), 6.5)
	# Left arm skin
	draw_line(shoulder_left + breathe_dir, left_hand, Color(0.92, 0.8, 0.68), 5.0)
	# Left arm shading
	var arm_mid_l = (shoulder_left + breathe_dir + left_hand) * 0.5
	draw_circle(arm_mid_l, 3.5, Color(0.85, 0.72, 0.58, 0.2))
	# Wrist detail
	draw_circle(card_hand - dir * 4.0, 3.0, Color(0.9, 0.78, 0.65, 0.3))
	# Hand circle with outline
	draw_circle(card_hand, 6.0, Color(0.78, 0.65, 0.5))
	draw_circle(card_hand, 5.0, Color(0.94, 0.82, 0.7))
	# Hand highlight
	draw_circle(card_hand + shade_dir * 1.5, 3.0, Color(0.98, 0.88, 0.78, 0.3))
	# Finger bumps
	draw_arc(card_hand + dir * 3.0, 3.5, aim_angle - 0.7, aim_angle + 0.7, 8, Color(0.9, 0.78, 0.65), 1.5)
	# Fingernails (tiny lighter dots at fingertips)
	for fi in range(3):
		var fa = aim_angle + (float(fi) - 1.0) * 0.4
		var fpos = card_hand + Vector2.from_angle(fa) * 6.0
		draw_circle(fpos, 1.0, Color(0.95, 0.88, 0.82, 0.5))

	# === Fan of cards in hand ===
	var card_fan_oscillate = sin(_time * 2.5) * 0.08
	for i in range(5):
		var fan_angle = aim_angle + (float(i) - 2.0) * (0.18 + card_fan_oscillate)
		var fan_dir = Vector2.from_angle(fan_angle)
		var fan_perp = fan_dir.rotated(PI / 2.0)
		var card_start = card_hand
		var card_end = card_hand + fan_dir * 26.0
		# Card shadow
		draw_line(card_start + fan_perp * 1.0, card_end + fan_perp * 1.0, Color(0.3, 0.3, 0.25, 0.3), 8.0)
		# Card background (white with border)
		draw_line(card_start, card_end, Color(0.35, 0.35, 0.3), 9.0)
		draw_line(card_start, card_end, Color(0.98, 0.98, 0.95), 7.5)
		# Card corner decorative border
		draw_line(card_start + fan_dir * 3.0 - fan_perp * 3.0, card_start + fan_dir * 3.0 + fan_perp * 3.0, Color(0.8, 0.15, 0.15, 0.3), 0.8)
		draw_line(card_end - fan_dir * 3.0 - fan_perp * 3.0, card_end - fan_dir * 3.0 + fan_perp * 3.0, Color(0.8, 0.15, 0.15, 0.3), 0.8)
		# Card suit details
		var suit_pos = card_hand + fan_dir * 16.0
		if i % 4 == 0:
			# Heart
			draw_circle(suit_pos - fan_perp * 1.5, 2.2, Color(0.9, 0.15, 0.15))
			draw_circle(suit_pos + fan_perp * 1.5, 2.2, Color(0.9, 0.15, 0.15))
			draw_line(suit_pos, suit_pos - fan_dir * 3.5, Color(0.9, 0.15, 0.15), 3.0)
		elif i % 4 == 1:
			# Spade
			draw_circle(suit_pos - fan_perp * 1.5 + fan_dir * 1.0, 2.0, Color(0.12, 0.12, 0.15))
			draw_circle(suit_pos + fan_perp * 1.5 + fan_dir * 1.0, 2.0, Color(0.12, 0.12, 0.15))
			draw_line(suit_pos + fan_dir * 1.5, suit_pos + fan_dir * 4.0, Color(0.12, 0.12, 0.15), 2.5)
			draw_line(suit_pos, suit_pos - fan_dir * 2.0, Color(0.12, 0.12, 0.15), 1.5)
		elif i % 4 == 2:
			# Diamond (red)
			draw_line(suit_pos + fan_dir * 2.5, suit_pos + fan_perp * 2.0, Color(0.9, 0.15, 0.15), 2.0)
			draw_line(suit_pos + fan_perp * 2.0, suit_pos - fan_dir * 2.5, Color(0.9, 0.15, 0.15), 2.0)
			draw_line(suit_pos - fan_dir * 2.5, suit_pos - fan_perp * 2.0, Color(0.9, 0.15, 0.15), 2.0)
			draw_line(suit_pos - fan_perp * 2.0, suit_pos + fan_dir * 2.5, Color(0.9, 0.15, 0.15), 2.0)
		else:
			# Club (black)
			draw_circle(suit_pos + fan_dir * 1.5, 1.8, Color(0.12, 0.12, 0.15))
			draw_circle(suit_pos - fan_perp * 1.8, 1.8, Color(0.12, 0.12, 0.15))
			draw_circle(suit_pos + fan_perp * 1.8, 1.8, Color(0.12, 0.12, 0.15))
			draw_line(suit_pos, suit_pos - fan_dir * 3.0, Color(0.12, 0.12, 0.15), 1.5)
		# Card corner pip
		draw_circle(card_hand + fan_dir * 6.0, 1.0, Color(0.5, 0.5, 0.45, 0.5))

	# Thrown card effect during attack
	if _attack_anim > 0.3:
		var thrown_end = card_hand + dir * (40.0 * _attack_anim)
		# Spinning card (wider line that rotates)
		var spin = _time * 15.0
		var spin_perp = Vector2.from_angle(aim_angle + spin).rotated(PI / 2.0)
		draw_line(card_hand, thrown_end, Color(0.95, 0.95, 0.9, _attack_anim), 6.0)
		draw_line(card_hand, thrown_end, Color(0.85, 0.15, 0.15, _attack_anim), 3.0)
		# Card trail sparkle
		for ti in range(3):
			var trail_t = float(ti + 1) / 4.0
			var trail_pos = card_hand.lerp(thrown_end, trail_t)
			draw_circle(trail_pos, 2.0 - float(ti) * 0.5, Color(1.0, 0.95, 0.8, _attack_anim * (0.5 - float(ti) * 0.15)))

	# === Head — blonde hair with black headband ===
	var head_center = dir * 18.0 + breathe_dir

	# Hair underlying dark volume layer (gives depth)
	draw_circle(head_center - dir * 2.0, 20.0, Color(0.72, 0.6, 0.22))
	# Hair main volume (blonde)
	draw_circle(head_center, 18.5, Color(0.95, 0.85, 0.45))
	# Hair lighter top highlight
	draw_circle(head_center + dir * 4.0, 14.0, Color(0.98, 0.9, 0.55, 0.3))

	# Hair flowing behind with wave — rich flowing strands
	var hair_wave_1 = sin(_time * 1.5) * 4.0
	var hair_wave_2 = sin(_time * 1.5 + 1.0) * 4.0
	var hair_wave_3 = sin(_time * 1.5 + 2.0) * 3.0
	var hair_wave_4 = sin(_time * 1.5 + 0.5) * 3.5
	var hair_wave_5 = sin(_time * 1.5 + 1.5) * 3.0
	var hair_wave_6 = sin(_time * 1.5 + 2.5) * 3.5
	# Dark under-layer strands (volume/depth)
	draw_line(head_center - perp * 18.0, head_center - dir * 34.0 - perp * 18.0 + perp * hair_wave_1, Color(0.7, 0.58, 0.2), 8.0)
	draw_line(head_center + perp * 18.0, head_center - dir * 34.0 + perp * 18.0 + perp * hair_wave_2, Color(0.7, 0.58, 0.2), 8.0)
	draw_line(head_center, head_center - dir * 37.0 + perp * hair_wave_3, Color(0.72, 0.6, 0.22), 7.0)
	draw_line(head_center - perp * 12.0, head_center - dir * 30.0 - perp * 11.0 + perp * hair_wave_4, Color(0.72, 0.6, 0.22), 6.5)
	draw_line(head_center + perp * 12.0, head_center - dir * 30.0 + perp * 11.0 + perp * hair_wave_5, Color(0.72, 0.6, 0.22), 6.5)
	draw_line(head_center - perp * 6.0, head_center - dir * 32.0 - perp * 5.0 + perp * hair_wave_6, Color(0.72, 0.6, 0.22), 5.5)
	draw_line(head_center + perp * 6.0, head_center - dir * 32.0 + perp * 5.0 + perp * hair_wave_6, Color(0.72, 0.6, 0.22), 5.5)
	# Mid-layer strands
	draw_line(head_center - perp * 17.0, head_center - dir * 32.0 - perp * 16.0 + perp * hair_wave_1, Color(0.85, 0.75, 0.35), 6.0)
	draw_line(head_center + perp * 17.0, head_center - dir * 32.0 + perp * 16.0 + perp * hair_wave_2, Color(0.85, 0.75, 0.35), 6.0)
	# Bright top-layer strands
	draw_line(head_center - perp * 16.0, head_center - dir * 30.0 - perp * 14.0 + perp * hair_wave_1, Color(0.95, 0.85, 0.45), 5.0)
	draw_line(head_center + perp * 16.0, head_center - dir * 30.0 + perp * 14.0 + perp * hair_wave_2, Color(0.95, 0.85, 0.45), 5.0)
	draw_line(head_center - perp * 2.0, head_center - dir * 35.0 + perp * hair_wave_3 - perp * 2.0, Color(0.95, 0.85, 0.45), 4.5)
	draw_line(head_center + perp * 2.0, head_center - dir * 33.0 + perp * hair_wave_4 + perp * 2.0, Color(0.93, 0.83, 0.43), 4.0)
	draw_line(head_center - perp * 10.0, head_center - dir * 28.0 - perp * 8.0 + perp * hair_wave_2, Color(0.93, 0.83, 0.42), 4.0)
	draw_line(head_center + perp * 10.0, head_center - dir * 28.0 + perp * 8.0 + perp * hair_wave_1, Color(0.93, 0.83, 0.42), 4.0)
	# Curled hair ends (slight curve at tips)
	draw_arc(head_center - dir * 32.0 - perp * 15.0 + perp * hair_wave_1, 4.0, aim_angle + PI * 0.5, aim_angle + PI * 1.5, 8, Color(0.9, 0.8, 0.4, 0.6), 2.0)
	draw_arc(head_center - dir * 32.0 + perp * 15.0 + perp * hair_wave_2, 4.0, aim_angle - PI * 0.5, aim_angle + PI * 0.5, 8, Color(0.9, 0.8, 0.4, 0.6), 2.0)
	draw_arc(head_center - dir * 35.0 + perp * hair_wave_3, 3.5, aim_angle + PI * 0.3, aim_angle + PI * 1.3, 8, Color(0.9, 0.8, 0.4, 0.5), 1.8)
	# Thinner highlight strands on top
	draw_line(head_center - perp * 7.0, head_center - dir * 24.0 - perp * 5.0 + perp * hair_wave_5, Color(1.0, 0.92, 0.55, 0.6), 2.5)
	draw_line(head_center + perp * 7.0, head_center - dir * 24.0 + perp * 5.0 + perp * hair_wave_4, Color(1.0, 0.92, 0.55, 0.6), 2.5)
	draw_line(head_center - perp * 15.0, head_center - dir * 22.0 - perp * 14.0 + perp * hair_wave_3, Color(1.0, 0.92, 0.55, 0.5), 2.0)
	draw_line(head_center + perp * 15.0, head_center - dir * 22.0 + perp * 14.0 + perp * hair_wave_5, Color(1.0, 0.92, 0.55, 0.5), 2.0)
	# Hair highlight arc (prominent glossy shine)
	draw_arc(head_center + dir * 5.0, 15.0, aim_angle + PI * 0.55, aim_angle + PI * 1.05, 14, Color(1.0, 0.96, 0.65, 0.55), 3.5)
	draw_arc(head_center + dir * 5.0, 12.0, aim_angle + PI * 0.65, aim_angle + PI * 0.95, 10, Color(1.0, 0.98, 0.75, 0.35), 2.0)
	# Additional subtle highlight streaks
	draw_arc(head_center + dir * 3.0, 17.0, aim_angle + PI * 0.6, aim_angle + PI * 0.8, 6, Color(1.0, 0.95, 0.7, 0.2), 1.5)

	# === Ears peeking through hair ===
	var ear_left = head_center + dir * 4.0 - perp * 17.0
	var ear_right = head_center + dir * 4.0 + perp * 17.0
	# Ear base (skin tone)
	draw_circle(ear_left, 4.0, Color(0.92, 0.78, 0.65))
	draw_circle(ear_right, 4.0, Color(0.92, 0.78, 0.65))
	# Inner ear detail (pink)
	draw_circle(ear_left - perp * 0.5, 2.2, Color(0.95, 0.72, 0.68, 0.5))
	draw_circle(ear_right + perp * 0.5, 2.2, Color(0.95, 0.72, 0.68, 0.5))
	# Ear outline
	draw_arc(ear_left, 4.0, aim_angle + PI * 0.3, aim_angle + PI * 1.7, 8, Color(0.78, 0.65, 0.52, 0.5), 1.0)
	draw_arc(ear_right, 4.0, aim_angle - PI * 0.7, aim_angle + PI * 0.7, 8, Color(0.78, 0.65, 0.52, 0.5), 1.0)

	# === Face ===
	# Face shadow (subtle depth)
	draw_circle(head_center + dir * 2.5, 17.5, Color(0.82, 0.68, 0.55, 0.4))
	# Face circle
	draw_circle(head_center + dir * 3.0, 17.0, Color(0.95, 0.84, 0.73))
	# Subtle face shading (directional based on aim)
	draw_arc(head_center + dir * 3.0, 16.0, aim_angle - PI * 0.4, aim_angle + PI * 0.4, 12, Color(0.88, 0.75, 0.62, 0.2), 3.0)
	# Chin contour
	draw_arc(head_center + dir * 3.0, 16.5, aim_angle - PI * 0.25, aim_angle + PI * 0.25, 10, Color(0.85, 0.72, 0.6, 0.15), 2.0)
	# Forehead highlight
	draw_circle(head_center + dir * 8.0, 7.0, Color(0.98, 0.9, 0.8, 0.25))
	# Temple shading
	draw_circle(head_center + dir * 5.0 - perp * 13.0, 5.0, Color(0.88, 0.75, 0.62, 0.12))
	draw_circle(head_center + dir * 5.0 + perp * 13.0, 5.0, Color(0.88, 0.75, 0.62, 0.12))

	# BLACK headband (Tenniel-accurate) — sits in hair
	var hb_left = head_center - perp * 18.0
	var hb_right = head_center + perp * 18.0
	var hb_mid = head_center + dir * 1.5
	# Headband dark base
	draw_line(hb_left, hb_mid, Color(0.08, 0.08, 0.1), 6.0)
	draw_line(hb_mid, hb_right, Color(0.08, 0.08, 0.1), 6.0)
	# Headband main color (very dark / black)
	draw_line(hb_left, hb_mid, Color(0.12, 0.12, 0.14), 4.5)
	draw_line(hb_mid, hb_right, Color(0.12, 0.12, 0.14), 4.5)
	# Headband satin highlight (subtle sheen)
	draw_line(hb_left + dir * 1.0, hb_mid + dir * 1.0, Color(0.3, 0.3, 0.35, 0.35), 1.5)
	draw_line(hb_mid + dir * 1.0, hb_right + dir * 1.0, Color(0.3, 0.3, 0.35, 0.35), 1.5)
	# Headband edge highlight
	draw_line(hb_left + dir * 2.0, hb_mid + dir * 2.0, Color(0.25, 0.25, 0.3, 0.2), 0.8)
	# Headband bow (black ribbon bow on the side)
	var bow_hb = hb_left
	# Upper loop
	draw_arc(bow_hb - perp * 5.0 + dir * 3.0, 5.0, aim_angle + PI * 0.6, aim_angle + PI * 1.8, 8, Color(0.12, 0.12, 0.14), 2.5)
	# Lower loop
	draw_arc(bow_hb - perp * 5.0 - dir * 3.0, 5.0, aim_angle + PI * 0.2, aim_angle + PI * 1.4, 8, Color(0.12, 0.12, 0.14), 2.5)
	# Bow center knot
	draw_circle(bow_hb - perp * 2.0, 2.5, Color(0.1, 0.1, 0.12))
	# Bow highlight
	draw_circle(bow_hb - perp * 2.0 + Vector2(-0.5, -0.5), 1.0, Color(0.3, 0.3, 0.35, 0.3))
	# Bow tail ribbons
	draw_line(bow_hb - perp * 2.0, bow_hb - perp * 8.0 - dir * 6.0, Color(0.12, 0.12, 0.14), 2.0)
	draw_line(bow_hb - perp * 2.0, bow_hb - perp * 7.0 + dir * 2.0, Color(0.12, 0.12, 0.14), 2.0)
	# Ribbon tail tips
	draw_line(bow_hb - perp * 8.0 - dir * 6.0, bow_hb - perp * 10.0 - dir * 8.0, Color(0.12, 0.12, 0.14), 1.5)

	# Rosy cheeks — soft layered blush
	var cheek_l = head_center + dir * 1.5 - perp * 9.0
	var cheek_r = head_center + dir * 1.5 + perp * 9.0
	draw_circle(cheek_l, 7.0, Color(0.95, 0.6, 0.55, 0.1))
	draw_circle(cheek_l, 5.5, Color(0.95, 0.55, 0.52, 0.15))
	draw_circle(cheek_l, 4.0, Color(0.95, 0.5, 0.48, 0.2))
	draw_circle(cheek_l, 2.5, Color(0.95, 0.45, 0.45, 0.22))
	draw_circle(cheek_r, 7.0, Color(0.95, 0.6, 0.55, 0.1))
	draw_circle(cheek_r, 5.5, Color(0.95, 0.55, 0.52, 0.15))
	draw_circle(cheek_r, 4.0, Color(0.95, 0.5, 0.48, 0.2))
	draw_circle(cheek_r, 2.5, Color(0.95, 0.45, 0.45, 0.22))

	# === Eyes — detailed with lids, iris, pupil, highlights, lashes ===
	var eye_left = head_center + dir * 7.0 - perp * 6.5
	var eye_right = head_center + dir * 7.0 + perp * 6.5

	# Eye socket shadow
	draw_circle(eye_left, 6.0, Color(0.82, 0.72, 0.62, 0.2))
	draw_circle(eye_right, 6.0, Color(0.82, 0.72, 0.62, 0.2))

	# Eye whites (slightly blue-white for vibrancy)
	draw_circle(eye_left, 5.0, Color(0.97, 0.97, 1.0))
	draw_circle(eye_left + dir * 0.5, 4.8, Color(0.98, 0.98, 1.0))
	draw_circle(eye_right, 5.0, Color(0.97, 0.97, 1.0))
	draw_circle(eye_right + dir * 0.5, 4.8, Color(0.98, 0.98, 1.0))

	# Eye white edge shadow (inner corner)
	draw_arc(eye_left, 4.8, aim_angle + PI * 0.8, aim_angle + PI * 1.2, 6, Color(0.88, 0.85, 0.9, 0.15), 1.5)
	draw_arc(eye_right, 4.8, aim_angle + PI * 0.8, aim_angle + PI * 1.2, 6, Color(0.88, 0.85, 0.9, 0.15), 1.5)

	# Iris — rich blue with layered depth
	# Outer iris ring (dark blue)
	draw_circle(eye_left + dir * 1.0, 3.5, Color(0.12, 0.28, 0.55))
	draw_circle(eye_right + dir * 1.0, 3.5, Color(0.12, 0.28, 0.55))
	# Mid iris (medium blue)
	draw_circle(eye_left + dir * 1.0, 2.8, Color(0.25, 0.45, 0.78))
	draw_circle(eye_right + dir * 1.0, 2.8, Color(0.25, 0.45, 0.78))
	# Inner iris (lighter blue, curious wide-eyed look)
	draw_circle(eye_left + dir * 0.8, 2.0, Color(0.4, 0.6, 0.92))
	draw_circle(eye_right + dir * 0.8, 2.0, Color(0.4, 0.6, 0.92))
	# Iris radial lines (gives texture to the iris)
	for iri in range(8):
		var ir_a = TAU * float(iri) / 8.0
		var ir_s = eye_left + dir * 1.0 + Vector2.from_angle(ir_a) * 1.2
		var ir_e = eye_left + dir * 1.0 + Vector2.from_angle(ir_a) * 3.2
		draw_line(ir_s, ir_e, Color(0.18, 0.35, 0.65, 0.3), 0.6)
		ir_s = eye_right + dir * 1.0 + Vector2.from_angle(ir_a) * 1.2
		ir_e = eye_right + dir * 1.0 + Vector2.from_angle(ir_a) * 3.2
		draw_line(ir_s, ir_e, Color(0.18, 0.35, 0.65, 0.3), 0.6)

	# Pupil (large, curious — slightly dilated)
	draw_circle(eye_left + dir * 1.3, 1.7, Color(0.04, 0.04, 0.08))
	draw_circle(eye_right + dir * 1.3, 1.7, Color(0.04, 0.04, 0.08))

	# Eye highlight dots (sparkly, curious eyes — three per eye)
	draw_circle(eye_left + dir * 0.3 + perp * 1.3, 1.4, Color(1.0, 1.0, 1.0, 0.95))
	draw_circle(eye_left + dir * 2.0 - perp * 0.8, 0.7, Color(1.0, 1.0, 1.0, 0.7))
	draw_circle(eye_left + dir * 0.0 - perp * 1.0, 0.5, Color(1.0, 1.0, 1.0, 0.4))
	draw_circle(eye_right + dir * 0.3 + perp * 1.3, 1.4, Color(1.0, 1.0, 1.0, 0.95))
	draw_circle(eye_right + dir * 2.0 - perp * 0.8, 0.7, Color(1.0, 1.0, 1.0, 0.7))
	draw_circle(eye_right + dir * 0.0 - perp * 1.0, 0.5, Color(1.0, 1.0, 1.0, 0.4))

	# Upper eyelid line (bold, defining)
	draw_arc(eye_left, 5.0, aim_angle + PI * 0.5, aim_angle + PI * 1.5, 12, Color(0.25, 0.18, 0.12), 1.8)
	draw_arc(eye_right, 5.0, aim_angle + PI * 0.5, aim_angle + PI * 1.5, 12, Color(0.25, 0.18, 0.12), 1.8)

	# Upper eyelid crease (subtle fold above)
	draw_arc(eye_left + dir * 1.0, 6.5, aim_angle + PI * 0.6, aim_angle + PI * 1.4, 10, Color(0.75, 0.65, 0.55, 0.25), 1.0)
	draw_arc(eye_right + dir * 1.0, 6.5, aim_angle + PI * 0.6, aim_angle + PI * 1.4, 10, Color(0.75, 0.65, 0.55, 0.25), 1.0)

	# Lower eyelid line (softer)
	draw_arc(eye_left, 4.8, aim_angle - PI * 0.35, aim_angle + PI * 0.35, 8, Color(0.7, 0.6, 0.52, 0.35), 1.0)
	draw_arc(eye_right, 4.8, aim_angle - PI * 0.35, aim_angle + PI * 0.35, 8, Color(0.7, 0.6, 0.52, 0.35), 1.0)

	# Eyelashes — longer and more dramatic (Tenniel style)
	for li in range(5):
		var lash_a = aim_angle + PI * 0.58 + float(li) * 0.2
		var lash_len = 7.5 + sin(float(li) * 1.2) * 1.5
		# Left eye lashes
		var lash_start_l = eye_left + Vector2.from_angle(lash_a) * 5.0
		var lash_end_l = eye_left + Vector2.from_angle(lash_a + 0.12) * lash_len
		draw_line(lash_start_l, lash_end_l, Color(0.2, 0.15, 0.1), 1.2)
		# Right eye lashes
		var lash_start_r = eye_right + Vector2.from_angle(lash_a) * 5.0
		var lash_end_r = eye_right + Vector2.from_angle(lash_a + 0.12) * lash_len
		draw_line(lash_start_r, lash_end_r, Color(0.2, 0.15, 0.1), 1.2)
	# Lower lashes (fewer, shorter)
	for li in range(3):
		var lash_a = aim_angle - PI * 0.15 + float(li) * 0.15
		var lash_start_l = eye_left + Vector2.from_angle(lash_a) * 4.8
		var lash_end_l = eye_left + Vector2.from_angle(lash_a - 0.1) * 6.0
		draw_line(lash_start_l, lash_end_l, Color(0.3, 0.22, 0.15, 0.5), 0.8)
		var lash_start_r = eye_right + Vector2.from_angle(lash_a) * 4.8
		var lash_end_r = eye_right + Vector2.from_angle(lash_a - 0.1) * 6.0
		draw_line(lash_start_r, lash_end_r, Color(0.3, 0.22, 0.15, 0.5), 0.8)

	# Eyebrows — natural arch with more definition
	# Left eyebrow
	var brow_l_inner = eye_left - perp * 4.5 + dir * 5.0
	var brow_l_peak = eye_left + dir * 7.0
	var brow_l_outer = eye_left + perp * 4.5 + dir * 4.5
	draw_line(brow_l_inner, brow_l_peak, Color(0.6, 0.48, 0.2), 2.2)
	draw_line(brow_l_peak, brow_l_outer, Color(0.6, 0.48, 0.2, 0.6), 1.5)
	# Brow highlight underneath
	draw_line(brow_l_inner - dir * 0.5, brow_l_peak - dir * 0.5, Color(0.95, 0.85, 0.75, 0.15), 1.0)
	# Right eyebrow
	var brow_r_inner = eye_right + perp * 4.5 + dir * 5.0
	var brow_r_peak = eye_right + dir * 7.0
	var brow_r_outer = eye_right - perp * 4.5 + dir * 4.5
	draw_line(brow_r_inner, brow_r_peak, Color(0.6, 0.48, 0.2), 2.2)
	draw_line(brow_r_peak, brow_r_outer, Color(0.6, 0.48, 0.2, 0.6), 1.5)
	draw_line(brow_r_inner - dir * 0.5, brow_r_peak - dir * 0.5, Color(0.95, 0.85, 0.75, 0.15), 1.0)

	# === Nose — delicate button nose ===
	var nose_tip = head_center + dir * 6.0
	# Nose bridge (subtle line)
	draw_line(head_center + dir * 9.0, nose_tip + dir * 0.5, Color(0.88, 0.75, 0.62, 0.3), 1.2)
	# Nose tip (small round)
	draw_circle(nose_tip, 2.0, Color(0.92, 0.8, 0.68, 0.45))
	# Nose shadow underneath
	draw_arc(nose_tip, 2.2, aim_angle - 0.6, aim_angle + 0.6, 6, Color(0.82, 0.68, 0.55, 0.2), 1.0)
	# Nostril hints (two tiny dots)
	draw_circle(nose_tip - perp * 1.5 - dir * 0.5, 0.9, Color(0.78, 0.65, 0.52, 0.4))
	draw_circle(nose_tip + perp * 1.5 - dir * 0.5, 0.9, Color(0.78, 0.65, 0.52, 0.4))
	# Nose highlight
	draw_circle(nose_tip + dir * 0.8 + perp * 0.5, 1.0, Color(1.0, 0.95, 0.88, 0.4))

	# === Mouth — rosebud lips (Tenniel style, slightly open with wonder) ===
	var mouth_center = head_center + dir * 1.5
	# Upper lip shadow
	draw_arc(mouth_center + dir * 0.5, 4.0, aim_angle + PI * 0.15, aim_angle + PI * 0.85, 10, Color(0.82, 0.68, 0.58, 0.15), 1.5)
	# Upper lip (cupid's bow shape)
	draw_arc(mouth_center - perp * 2.5, 3.2, aim_angle + PI * 0.15, aim_angle + PI * 0.55, 8, Color(0.88, 0.42, 0.42), 1.8)
	draw_arc(mouth_center + perp * 2.5, 3.2, aim_angle + PI * 0.45, aim_angle + PI * 0.85, 8, Color(0.88, 0.42, 0.42), 1.8)
	# Lower lip (fuller, single arc)
	draw_arc(mouth_center, 4.8, aim_angle - 0.4, aim_angle + 0.4, 12, Color(0.92, 0.5, 0.48), 2.0)
	# Lower lip fullness (inner highlight)
	draw_arc(mouth_center - dir * 0.5, 3.5, aim_angle - 0.3, aim_angle + 0.3, 8, Color(0.95, 0.55, 0.52, 0.4), 1.5)
	# Lip highlight (shine on lower lip)
	draw_circle(mouth_center + perp * 0.3 - dir * 1.0, 1.2, Color(1.0, 0.75, 0.72, 0.45))
	# Lip line (parting between lips)
	draw_arc(mouth_center, 3.5, aim_angle - 0.35, aim_angle + 0.35, 8, Color(0.7, 0.28, 0.28, 0.5), 0.8)
	# Slight smile upturn at corners (curious/determined expression)
	draw_line(mouth_center - perp * 4.5, mouth_center - perp * 5.5 + dir * 0.8, Color(0.85, 0.45, 0.42, 0.3), 1.0)
	draw_line(mouth_center + perp * 4.5, mouth_center + perp * 5.5 + dir * 0.8, Color(0.85, 0.45, 0.42, 0.3), 1.0)
	# Chin dimple hint
	draw_circle(head_center - dir * 2.0, 1.5, Color(0.88, 0.75, 0.62, 0.12))

	# === T2+: Floating Cheshire Cat grin with teeth and fading body ===
	if upgrade_tier >= 2:
		var grin_float = sin(_time * 2.2) * 6.0
		var grin_bob = cos(_time * 1.7) * 4.0
		var grin_pos = -dir * 18.0 + perp * 42.0 + Vector2(grin_bob, grin_float)
		# Fading body outline (ghostly stripes)
		var body_alpha = 0.15 + sin(_time * 1.5) * 0.05
		draw_arc(grin_pos - dir * 2.0, 18.0, aim_angle + PI * 0.1, aim_angle + PI * 0.9, 12, Color(0.6, 0.3, 0.7, body_alpha), 2.0)
		# Ghostly stripe markings
		for si in range(3):
			var stripe_a = aim_angle + PI * 0.25 + float(si) * 0.25
			var s_start = grin_pos + Vector2.from_angle(stripe_a) * 14.0
			var s_end = grin_pos + Vector2.from_angle(stripe_a) * 20.0
			draw_line(s_start, s_end, Color(0.55, 0.25, 0.65, body_alpha * 0.7), 2.0)
		# Grin arc (wide purple smile)
		draw_arc(grin_pos, 14.0, aim_angle + 0.2, aim_angle + PI - 0.2, 18, Color(0.7, 0.3, 0.8, 0.75), 4.5)
		# Inner grin (pink interior)
		draw_arc(grin_pos, 12.0, aim_angle + 0.3, aim_angle + PI - 0.3, 14, Color(0.85, 0.4, 0.55, 0.3), 2.5)
		# Teeth (small rectangles along the grin)
		for i in range(8):
			var tooth_angle = aim_angle + 0.3 + float(i) * 0.32
			var tooth_start = grin_pos + Vector2.from_angle(tooth_angle) * 11.5
			var tooth_end = grin_pos + Vector2.from_angle(tooth_angle) * 16.0
			draw_line(tooth_start, tooth_end, Color(0.97, 0.97, 0.92, 0.65), 2.2)
			# Tooth gap lines
			draw_line(tooth_start, tooth_end, Color(0.6, 0.3, 0.7, 0.2), 0.5)
		# Cheshire eyes (glowing yellow-green)
		var eye_glow = 0.6 + sin(_time * 3.0) * 0.1
		draw_circle(grin_pos + perp * 8.0 + dir * 9.0, 4.5, Color(0.85, 0.8, 0.2, eye_glow))
		draw_circle(grin_pos - perp * 8.0 + dir * 9.0, 4.5, Color(0.85, 0.8, 0.2, eye_glow))
		# Cat eye inner glow
		draw_circle(grin_pos + perp * 8.0 + dir * 9.0, 3.0, Color(0.95, 0.9, 0.3, eye_glow * 0.6))
		draw_circle(grin_pos - perp * 8.0 + dir * 9.0, 3.0, Color(0.95, 0.9, 0.3, eye_glow * 0.6))
		# Cat eye slits (vertical)
		draw_line(grin_pos + perp * 8.0 + dir * 7.0, grin_pos + perp * 8.0 + dir * 11.0, Color(0.15, 0.08, 0.2, eye_glow), 1.8)
		draw_line(grin_pos - perp * 8.0 + dir * 7.0, grin_pos - perp * 8.0 + dir * 11.0, Color(0.15, 0.08, 0.2, eye_glow), 1.8)
		# Whisker hints
		draw_line(grin_pos + perp * 14.0, grin_pos + perp * 22.0 + dir * 2.0, Color(0.6, 0.3, 0.7, 0.2), 0.8)
		draw_line(grin_pos + perp * 14.0 - dir * 2.0, grin_pos + perp * 21.0 - dir * 1.0, Color(0.6, 0.3, 0.7, 0.2), 0.8)
		draw_line(grin_pos - perp * 14.0, grin_pos - perp * 22.0 + dir * 2.0, Color(0.6, 0.3, 0.7, 0.2), 0.8)
		draw_line(grin_pos - perp * 14.0 - dir * 2.0, grin_pos - perp * 21.0 - dir * 1.0, Color(0.6, 0.3, 0.7, 0.2), 0.8)

	# === T3+: Orbiting teacups with steam ===
	if upgrade_tier >= 3:
		for cup_i in range(3):
			var cup_angle = _time * 0.6 + float(cup_i) * TAU / 3.0
			var cup_r = 48.0 + sin(_time * 1.2 + float(cup_i)) * 5.0
			var cup_pos = Vector2.from_angle(cup_angle) * cup_r
			var cup_bob = sin(_time * 2.0 + float(cup_i) * 1.5) * 3.0
			cup_pos.y += cup_bob
			# Saucer
			draw_arc(cup_pos + Vector2(0, 4), 10.0, 0.2, PI - 0.2, 10, Color(0.88, 0.85, 0.78), 2.5)
			# Cup body
			draw_arc(cup_pos, 8.0, cup_angle + 0.4, cup_angle + PI - 0.4, 10, Color(0.92, 0.88, 0.78), 3.5)
			# Cup fill line
			draw_line(cup_pos + Vector2.from_angle(cup_angle + 0.5) * 8.0, cup_pos + Vector2.from_angle(cup_angle + PI - 0.5) * 8.0, Color(0.92, 0.88, 0.78), 2.0)
			# Tea inside
			draw_arc(cup_pos + Vector2(0, -1), 5.5, cup_angle + 0.6, cup_angle + PI - 0.6, 8, Color(0.6, 0.38, 0.18, 0.55), 2.5)
			# Cup handle
			draw_arc(cup_pos + Vector2.from_angle(cup_angle - PI * 0.5) * 9.0, 4.0, cup_angle - PI * 0.4, cup_angle + PI * 0.4, 8, Color(0.88, 0.85, 0.78), 2.0)
			# Gold rim
			draw_arc(cup_pos, 8.5, cup_angle + 0.35, cup_angle + PI - 0.35, 8, Color(0.85, 0.75, 0.3, 0.4), 1.0)
			# Steam wisps
			for si in range(2):
				var steam_off = sin(_time * 2.0 + float(cup_i) * 2.0 + float(si) * 1.5) * 3.0
				var steam_p = cup_pos + Vector2(steam_off, -12.0 - float(si) * 6.0)
				var steam_a = 0.3 - float(si) * 0.1
				draw_circle(steam_p, 3.0 - float(si) * 0.5, Color(0.92, 0.92, 0.95, steam_a))

	# === Tier 4: Crown of card suits floating above head ===
	if upgrade_tier >= 4:
		var crown_base = head_center + dir * 14.0 + breathe_dir * 0.5
		# Floating crown halo
		var crown_r = 16.0
		var crown_hover = sin(_time * 1.8) * 2.0
		var crown_center = crown_base + dir * (6.0 + crown_hover)
		# Golden band
		draw_arc(crown_center, crown_r, 0, TAU, 24, Color(0.95, 0.82, 0.2), 4.0)
		draw_arc(crown_center, crown_r + 1.5, 0, TAU, 24, Color(0.85, 0.72, 0.15, 0.4), 1.0)
		draw_arc(crown_center, crown_r - 1.5, 0, TAU, 24, Color(1.0, 0.92, 0.4, 0.3), 1.0)
		# Crown spikes with card suit gems
		for i in range(5):
			var ca = aim_angle + PI / 2.0 + (float(i) - 2.0) * 0.35
			var spike_base_pos = crown_center + Vector2.from_angle(ca) * (crown_r - 2.0)
			var spike_tip = crown_center + Vector2.from_angle(ca) * (crown_r + 12.0)
			# Spike body
			draw_line(spike_base_pos, spike_tip, Color(0.95, 0.82, 0.2), 3.5)
			draw_line(spike_base_pos + Vector2.from_angle(ca + PI * 0.5) * 3.0, spike_tip, Color(0.95, 0.82, 0.2), 1.5)
			draw_line(spike_base_pos - Vector2.from_angle(ca + PI * 0.5) * 3.0, spike_tip, Color(0.95, 0.82, 0.2), 1.5)
			# Card suit gem at tip (cycling suits)
			var suit_col = Color(0.95, 0.15, 0.15) if i % 2 == 0 else Color(0.1, 0.1, 0.12)
			draw_circle(spike_tip, 3.5, suit_col)
			# Gem shine
			draw_circle(spike_tip + Vector2(-1.0, -1.0), 1.3, Color(1.0, 0.7, 0.7, 0.5) if i % 2 == 0 else Color(0.5, 0.5, 0.55, 0.5))
		# Crown jewels on band
		for i in range(8):
			var ja = TAU * float(i) / 8.0
			var jp = crown_center + Vector2.from_angle(ja) * crown_r
			var jcol = Color(0.9, 0.15, 0.15, 0.6) if i % 2 == 0 else Color(0.2, 0.5, 0.9, 0.6)
			draw_circle(jp, 1.8, jcol)
		# Red velvet interior hint
		draw_arc(crown_center, crown_r * 0.7, aim_angle + PI * 0.3, aim_angle + PI * 1.7, 12, Color(0.7, 0.1, 0.15, 0.15), 3.0)

	# Reset transform for UI elements (text should stay readable)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	# === Awaiting ability choice indicator ===
	if awaiting_ability_choice:
		var pulse = (sin(_time * 4.0) + 1.0) * 0.5
		draw_circle(Vector2.ZERO, 76.0 + pulse * 8.0, Color(0.8, 0.7, 1.0, 0.1 + pulse * 0.1))
		draw_arc(Vector2.ZERO, 76.0 + pulse * 8.0, 0, TAU, 32, Color(0.8, 0.7, 1.0, 0.3 + pulse * 0.3), 3.0)
		var font3 = ThemeDB.fallback_font
		draw_string(font3, Vector2(-16, -88), "!", HORIZONTAL_ALIGNMENT_CENTER, 32, 36, Color(0.8, 0.7, 1.0, 0.7 + pulse * 0.3))

	# Damage dealt counter + level
	if damage_dealt > 0:
		var font = ThemeDB.fallback_font
		var dmg_text = str(int(damage_dealt)) + " DMG"
		if stat_upgrade_level > 0:
			dmg_text += " \u2022 Lv." + str(stat_upgrade_level)
		draw_string(font, Vector2(-36, 84), dmg_text, HORIZONTAL_ALIGNMENT_LEFT, 160, 14, Color(1.0, 0.84, 0.0, 0.6))

	# Upgrade name
	if _upgrade_flash > 0.0 and _upgrade_name != "":
		var font2 = ThemeDB.fallback_font
		draw_string(font2, Vector2(-80, -80), _upgrade_name, HORIZONTAL_ALIGNMENT_CENTER, 160, 16, Color(0.8, 0.7, 1.0, min(_upgrade_flash, 1.0)))
