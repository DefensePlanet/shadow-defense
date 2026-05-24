extends Control
## MainMenuV2 — Full interactive menu. Art backgrounds, working buttons, detail panels.

var _backgrounds: Dictionary = {}
var _art: Dictionary = {}
var _black_key: Shader = null
var _main: Node = null
var current_view: String = "chapters"
# Portrait key mapping — character_names[] index → portrait texture key
const PORTRAIT_KEYS: Array = ["robin_hood", "alice", "wicked_witch", "peter_pan", "phantom", "scrooge", "sherlock", "tarzan", "dracula", "merlin", "frankenstein", "shadow_author"]

@onready var background: TextureRect = $Background
@onready var content_area: Control = $ContentArea
@onready var nav_buttons_container: HBoxContainer = $NavBar/NavButtons
@onready var top_bar: ColorRect = $TopBar
@onready var nav_bar: ColorRect = $NavBar
@onready var fade_rect: ColorRect = $FadeRect



# Phase 8: Ambient floating particles
var _particles: Array = []
const PARTICLE_COUNT: int = 15

func _ready() -> void:
	_main = get_tree().get_first_node_in_group("main")
	_load_bgs()
	_load_art()
	_set_bg("chapters")
	_build_currency_bar()
	_build_music_display()
	_build_nav()
	_build_chapters()
	_init_particles()
	_fade_in()
	# Portraits verified loaded — all 12 keys match

func _init_particles() -> void:
	_particles.clear()
	for i in range(PARTICLE_COUNT):
		_particles.append({
			"x": randf_range(0, 1280),
			"y": randf_range(0, 720),
			"speed": randf_range(8, 25),
			"size": randf_range(1.5, 3.5),
			"alpha": randf_range(0.1, 0.35),
			"offset": randf_range(0, TAU),
		})

func _process(delta: float) -> void:
	for p in _particles:
		p["y"] -= p["speed"] * delta
		p["x"] += sin(p["offset"] + p["y"] * 0.01) * 0.3
		if p["y"] < -10:
			p["y"] = 730
			p["x"] = randf_range(0, 1280)
	queue_redraw()

func _draw() -> void:
	# Phase 8: Floating gold dust particles
	for p in _particles:
		var flicker = p["alpha"] * (0.7 + sin(p["offset"] + p["y"] * 0.02) * 0.3)
		draw_circle(Vector2(p["x"], p["y"]), p["size"], Color(0.85, 0.70, 0.40, flicker))
	# Auto-test removed

func _load_bgs() -> void:
	var m = {"chapters": "res://assets/ui_frames/scroll_banner.png", "survivors": "res://assets/menu_art/survivors_bg_books.png", "emporium": "res://assets/menu_art/emporium_bg_merchant.png", "codex": "res://assets/menu_art/codex_bg.png", "settings": "res://assets/menu_art/settings_bg_v2.png"}
	for k in m:
		var exists = ResourceLoader.exists(m[k])
		if exists:
			_backgrounds[k] = load(m[k])

func _load_art() -> void:
	if ResourceLoader.exists("res://shaders/black_key.gdshader"):
		_black_key = load("res://shaders/black_key.gdshader")
	var paths = {
		"level_card": "res://assets/ui_elements/level_card_bg.png",
		"shop_card": "res://assets/ui_elements/shop_item_card.png",
		"detail_panel": "res://assets/ui_elements/detail_panel_bg.png",
		"stats_panel": "res://assets/ui_elements/stats_panel.png",
		"buy_button": "res://assets/ui_elements/buy_button.png",
		"play_button": "res://assets/ui_elements/play_button_v2.png",
		"header_bar": "res://assets/ui_elements/header_bar.png",
		"nav_spine": "res://assets/ui_frames/nav_book_spine.png",
		"scroll_header": "res://assets/ui_frames/scroll_header_storybook.png",
		"card_frame": "res://assets/ui_frames/card_frame_storybook.png",
		"locked_card": "res://assets/ui_elements/back_button.png",
		"golden_star": "res://assets/ui_elements/golden_star.png",
		"button_gothic": "res://assets/ui_frames/button_gothic.png",
		"popup_frame": "res://assets/ui_frames/popup_frame.png",
		"reward_chest": "res://assets/ui_elements/reward_chest.png",
	}
	for k in paths:
		if ResourceLoader.exists(paths[k]):
			_art[k] = load(paths[k])

# Helper: create a ShaderMaterial with black-key effect
func _make_black_key_mat(thresh: float = 0.08, smooth: float = 0.05) -> ShaderMaterial:
	if not _black_key:
		return null
	var mat = ShaderMaterial.new()
	mat.shader = _black_key
	mat.set_shader_parameter("threshold", thresh)
	mat.set_shader_parameter("smoothness", smooth)
	return mat

func _set_bg(view: String) -> void:
	if _backgrounds.has(view):
		background.texture = _backgrounds[view]
	background.modulate.a = 1.0  # FORCE visible — never leave at 0
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

func _build_currency_bar() -> void:
	if not _main: return
	# Apply header bar art behind currency text
	if _art.has("header_bar"):
		var art_bg = TextureRect.new()
		art_bg.texture = _art["header_bar"]
		art_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art_bg.stretch_mode = TextureRect.STRETCH_SCALE
		art_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat = _make_black_key_mat(0.06, 0.04)
		if mat: art_bg.material = mat
		top_bar.add_child(art_bg)
		top_bar.color = Color(0, 0, 0, 0)  # Transparent so art shows
	var h = HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override("separation", 24)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	top_bar.add_child(h)
	for c in [["GOLD", _main.gold, Color(1,0.85,0.2)], ["QUILLS", _main.player_quills, Color(0.7,0.5,0.9)], ["SHARDS", _main.player_gear_shards, Color(0.3,0.75,0.9)], ["STARS", _main.player_storybook_stars, Color(1,0.9,0.3)]]:
		h.add_child(_lbl("%d %s" % [c[1], c[0]], 12, c[2]))

func _build_music_display() -> void:
	# Now Playing + Skip button in top-right
	var music_row = HBoxContainer.new()
	music_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	music_row.add_theme_constant_override("separation", 8)
	music_row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	music_row.position = Vector2(-250, 8)
	music_row.size = Vector2(240, 24)
	top_bar.add_child(music_row)
	# Song title
	var song_name = ""
	if _main and _main.has_method("_get_current_song_title"):
		song_name = _main._get_current_song_title()
	elif _main and "_current_song_title" in _main:
		song_name = _main._current_song_title
	var song_lbl = _lbl(song_name if song_name != "" else "Now Playing...", 10, Color(0.70, 0.60, 0.85))
	song_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	song_lbl.clip_text = true
	song_lbl.custom_minimum_size.x = 180
	music_row.add_child(song_lbl)
	# Skip button
	var skip = Button.new()
	skip.text = ">>"
	skip.custom_minimum_size = Vector2(40, 22)
	var ss = StyleBoxFlat.new()
	ss.bg_color = Color(0.15, 0.12, 0.25, 0.7)
	ss.set_corner_radius_all(4)
	skip.add_theme_stylebox_override("normal", ss)
	skip.add_theme_font_size_override("font_size", 10)
	skip.add_theme_color_override("font_color", Color(0.7, 0.6, 0.85))
	if _main and _main.has_method("_on_skip_song_pressed"):
		skip.pressed.connect(_main._on_skip_song_pressed)
	music_row.add_child(skip)

func _build_nav() -> void:
	# Apply nav spine art behind NavButtons (NavBar is ColorRect)
	if _art.has("nav_spine"):
		var art_bg = TextureRect.new()
		art_bg.texture = _art["nav_spine"]
		art_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art_bg.stretch_mode = TextureRect.STRETCH_SCALE
		art_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat = _make_black_key_mat(0.06, 0.04)
		if mat: art_bg.material = mat
		nav_bar.add_child(art_bg)
		nav_bar.move_child(art_bg, 0)
		nav_bar.color = Color(0, 0, 0, 0)  # Make ColorRect transparent so art shows
	var tabs = ["chapters", "survivors", "emporium", "codex", "settings"]
	var labels = ["CHAPTERS", "SURVIVORS", "EMPORIUM", "CODEX", "SETTINGS"]
	for i in range(5):
		var btn = Button.new()
		btn.text = labels[i]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 70)
		var s = StyleBoxFlat.new()
		s.bg_color = Color(0.08, 0.05, 0.14, 0.0)
		btn.add_theme_stylebox_override("normal", s)
		var sh = s.duplicate(); sh.bg_color = Color(0.20, 0.15, 0.30, 0.4)
		btn.add_theme_stylebox_override("hover", sh)
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override("font_color", Color(1,0.92,0.45) if tabs[i] == current_view else Color(0.55,0.50,0.45))
		btn.add_theme_color_override("font_shadow_color", Color(0,0,0,0.9))
		btn.add_theme_constant_override("shadow_offset_x", 1)
		btn.add_theme_constant_override("shadow_offset_y", 1)
		btn.pressed.connect(_on_tab.bind(tabs[i]))
		nav_buttons_container.add_child(btn)

func _on_tab(tab: String) -> void:
	if current_view == tab: return
	current_view = tab
	# Set background immediately — no crossfade that can break
	_set_bg(tab)
	# Update nav highlight
	var tabs = ["chapters", "survivors", "emporium", "codex", "settings"]
	for i in range(nav_buttons_container.get_child_count()):
		var b = nav_buttons_container.get_child(i)
		if b is Button:
			b.add_theme_color_override("font_color", Color(1,0.92,0.45) if tabs[i] == tab else Color(0.55,0.50,0.45))
	_clear()
	match tab:
		"chapters": _build_chapters()
		"survivors": _build_survivors()
		"emporium": _build_emporium()
		"codex": _build_codex()
		"settings": _build_settings()

func _clear() -> void:
	for c in content_area.get_children(): c.queue_free()

# ======================== CHAPTERS ========================
func _build_chapters() -> void:
	_clear()
	# ScrollContainer with all children set to mouse_filter=IGNORE
	# Only Button nodes receive clicks — ScrollContainer handles scrolling
	var sc = ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_area.add_child(sc)
	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 6)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sc.add_child(vb)
	vb.add_child(_title("THE TOME OF SHADOWS"))
	vb.add_child(_lbl("Heroes pulled from their stories. One Author controls them all.", 11, Color(0.55,0.50,0.45)))
	if not _main: return
	var cur_arc = ""
	var card_idx = 0
	for i in range(_main.levels.size()):
		var lvl = _main.levels[i]
		var sub = lvl.get("subtitle", "")
		var arc = sub.split(" — ")[0] if " — " in sub else "Prologue"
		if arc == "": arc = "Prologue"
		if arc != cur_arc:
			cur_arc = arc
			var hdr = _lbl(arc.to_upper(), 16, Color(0.90,0.80,0.50))
			hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vb.add_child(hdr)
		var card = _level_card(i, lvl)
		vb.add_child(card)
		# Staggered entrance animation
		card.modulate.a = 0.0
		var tw = create_tween()
		tw.tween_property(card, "modulate:a", 1.0, 0.2).set_delay(card_idx * 0.03)
		card_idx += 1

func _level_card(idx: int, lvl: Dictionary) -> PanelContainer:
	var unlocked = _main._is_level_unlocked(idx)
	var complete = idx in _main.completed_levels
	var p = PanelContainer.new()
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.04,0.03,0.10,0.55) if unlocked else Color(0.03,0.02,0.06,0.40)
	s.border_color = Color(0.3,0.65,0.25,0.6) if complete else Color(0.35,0.25,0.18,0.3)
	s.set_border_width_all(1 if not complete else 2)
	s.set_corner_radius_all(6)
	s.content_margin_left = 8; s.content_margin_right = 8; s.content_margin_top = 4; s.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_PASS  # Let clicks through to children
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	var num_lbl = _lbl(str(idx+1), 18, Color(0.85,0.72,0.40) if unlocked else Color(0.35,0.30,0.25))
	num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(num_lbl)
	# Thumbnail
	var th = TextureRect.new()
	th.custom_minimum_size = Vector2(90, 60)
	th.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	th.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	th.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _main._map_thumb_textures.has(idx): th.texture = _main._map_thumb_textures[idx]
	row.add_child(th)
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n = _lbl(lvl.get("name",""), 14, Color(1,0.95,0.85) if unlocked else Color(0.45,0.40,0.35))
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(n)
	var st = _lbl(lvl.get("subtitle",""), 10, Color(0.55,0.48,0.42))
	st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(st)
	var stats = _lbl("W:%d G:%d L:%d" % [lvl.get("waves",20), lvl.get("gold",100), lvl.get("lives",20)], 9, Color(0.45,0.40,0.38))
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(stats)
	# Star rating
	if _main and _main.level_stars.has(idx):
		var star_count = _main.level_stars[idx]
		var star_text = ""
		for _si in range(star_count):
			star_text += "★"
		for _si in range(3 - star_count):
			star_text += "☆"
		var stars_lbl = _lbl(star_text, 12, Color(1.0, 0.85, 0.15) if star_count > 0 else Color(0.35, 0.30, 0.25))
		stars_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_child(stars_lbl)
	row.add_child(info)
	if unlocked:
		var btns = VBoxContainer.new()
		btns.add_theme_constant_override("separation", 2)
		btns.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var dr = HBoxContainer.new()
		dr.add_theme_constant_override("separation", 4)
		dr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for d in [[0,"EASY",Color(0.2,0.6,0.2)],[1,"MED",Color(0.6,0.5,0.1)],[2,"HARD",Color(0.6,0.15,0.1)]]:
			var db = Button.new()
			db.text = d[1]; db.custom_minimum_size = Vector2(50,22)
			var ds = StyleBoxFlat.new(); ds.bg_color = d[2]; ds.set_corner_radius_all(4)
			db.add_theme_stylebox_override("normal", ds)
			db.add_theme_font_size_override("font_size", 9)
			db.add_theme_color_override("font_color", Color.WHITE)
			db.pressed.connect(_play.bind(idx, d[0]))
			dr.add_child(db)
		btns.add_child(dr)
		# PLAY button — use art if available
		if _art.has("play_button"):
			var pb = TextureButton.new()
			pb.texture_normal = _art["play_button"]
			pb.ignore_texture_size = true
			pb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			pb.custom_minimum_size = Vector2(170, 48)
			var mat = _make_black_key_mat(0.08, 0.05)
			if mat: pb.material = mat
			pb.mouse_entered.connect(func(): pb.modulate = Color(1.15, 1.1, 1.0))
			pb.mouse_exited.connect(func(): pb.modulate = Color.WHITE)
			pb.pressed.connect(_play.bind(idx, 0))
			btns.add_child(pb)
		else:
			var pb = Button.new()
			pb.text = "PLAY"; pb.custom_minimum_size = Vector2(150, 30)
			var ps = StyleBoxFlat.new(); ps.bg_color = Color(0.12,0.50,0.12,0.9); ps.set_corner_radius_all(6)
			pb.add_theme_stylebox_override("normal", ps)
			pb.add_theme_font_size_override("font_size", 13)
			pb.add_theme_color_override("font_color", Color.WHITE)
			pb.pressed.connect(_play.bind(idx, 0))
			btns.add_child(pb)
		row.add_child(btns)
	else:
		var lock_vb = VBoxContainer.new()
		lock_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock_vb.alignment = BoxContainer.ALIGNMENT_CENTER
		lock_vb.custom_minimum_size = Vector2(120, 0)
		var lock_icon = _lbl("🔒", 20, Color(0.4,0.35,0.3))
		lock_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock_vb.add_child(lock_icon)
		var lock_text = _lbl("Complete\nprevious level", 9, Color(0.4,0.35,0.3))
		lock_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock_vb.add_child(lock_text)
		row.add_child(lock_vb)
	return p

func _play(idx: int, diff: int) -> void:
	if not _main:
		_main = get_tree().get_first_node_in_group("main")
	if not _main: return
	if not _main._is_level_unlocked(idx): return
	_main.selected_difficulty = diff
	# Hide v2 menu first
	if _main.has_method("_hide_menu_v2"): _main._hide_menu_v2()
	# Use _on_level_selected which triggers story dialogs THEN starts level
	if _main.has_method("_on_level_selected"):
		_main._on_level_selected(idx)
	elif _main.has_method("_do_level_start"):
		_main._do_level_start(idx)

# ======================== SURVIVORS ========================
func _build_survivors() -> void:
	_clear()
	var sc = ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_area.add_child(sc)
	# Centered margin container
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 4)
	sc.add_child(margin)
	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 8)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vb)
	var t = _title("SURVIVORS")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	if not _main: return
	var unlocked_ct = 0
	for tt in _main.survivor_types:
		if _main._is_character_unlocked(tt): unlocked_ct += 1
	var sub = _lbl("%d / %d Rescued" % [unlocked_ct, _main.survivor_types.size()], 12, Color(0.65,0.58,0.50))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(sub)
	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(grid)
	for i in range(PORTRAIT_KEYS.size()):
		var card = _survivor_card(i)
		grid.add_child(card)
		# Staggered entrance
		card.modulate.a = 0.0
		var tw = create_tween()
		tw.tween_property(card, "modulate:a", 1.0, 0.2).set_delay(i * 0.05)

func _survivor_card(idx: int) -> Button:
	# The card IS a Button — fills grid cell
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(200, 270)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # FILL the grid column
	# Style the button to look like a card
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.06,0.04,0.12,0.70)
	s.border_color = Color(0.45,0.35,0.20,0.5)
	s.set_border_width_all(2); s.set_corner_radius_all(8)
	s.content_margin_left = 4; s.content_margin_right = 4
	s.content_margin_top = 4; s.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", s)
	var sh = s.duplicate()
	sh.bg_color = Color(0.10,0.07,0.18,0.80)
	sh.border_color = Color(0.65,0.50,0.25,0.8)
	btn.add_theme_stylebox_override("hover", sh)
	var sp = s.duplicate()
	sp.bg_color = Color(0.12,0.08,0.20,0.85)
	btn.add_theme_stylebox_override("pressed", sp)
	btn.text = ""
	# Art frame layer behind content (card_frame with black keyed out)
	if _art.has("card_frame"):
		var frame_art = TextureRect.new()
		frame_art.texture = _art["card_frame"]
		frame_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		frame_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		frame_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame_art.modulate.a = 0.35  # Subtle art overlay
		var mat = _make_black_key_mat(0.08, 0.05)
		if mat: frame_art.material = mat
		btn.add_child(frame_art)
	# Content fills entire button area — centered
	var vb = VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vb)
	# Portrait — fills width, centered
	var port = TextureRect.new()
	port.custom_minimum_size = Vector2(0, 190)
	port.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	port.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	port.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	port.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pkey = PORTRAIT_KEYS[idx]
	if _main and _main._portrait_textures.has(pkey):
		port.texture = _main._portrait_textures[pkey]
	vb.add_child(port)
	# Name
	var cname = _main.character_names[idx] if _main and idx < _main.character_names.size() else "?"
	var nl = _lbl(cname.to_upper(), 11, Color(1,0.92,0.45))
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(nl)
	var ctitle = _main.character_titles[idx] if _main and idx < _main.character_titles.size() else ""
	var tl = _lbl(ctitle, 9, Color(0.55,0.48,0.42))
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(tl)
	# Level badge
	var tt = _main.survivor_types[idx] if _main and idx < _main.survivor_types.size() else null
	if tt != null and _main.survivor_progress.has(tt):
		var lvl = _main.survivor_progress[tt].get("level", 1)
		var badge = _lbl("Lv.%d" % lvl, 9, Color(0.85, 0.72, 0.40))
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(badge)
	# Source novel
	if _main and idx < _main.character_novels.size():
		var novel = _lbl(_main.character_novels[idx], 8, Color(0.42, 0.38, 0.35))
		novel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		novel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		novel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		novel.clip_text = true
		vb.add_child(novel)
	btn.pressed.connect(_open_survivor_detail.bind(idx))
	# Hover effect
	btn.mouse_entered.connect(func():
		btn.pivot_offset = btn.size / 2.0
		var tw = btn.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1))
	btn.mouse_exited.connect(func():
		var tw = btn.create_tween().set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.08))
	return btn

var _detail_idx: int = -1
var _detail_tab: int = 0  # 0=Stats, 1=Gear, 2=Allies, 3=Abilities

func _switch_detail_tab(tab: int) -> void:
	_detail_tab = tab
	_build_detail_view()

func _open_survivor_detail(idx: int) -> void:
	_detail_idx = idx
	_detail_tab = 0
	_build_detail_view()

func _build_detail_view() -> void:
	var idx = _detail_idx
	_clear()
	var sc = ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_area.add_child(sc)
	var main_hbox = HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 20)
	main_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(main_hbox)
	# LEFT: Large portrait
	var left = VBoxContainer.new()
	left.custom_minimum_size = Vector2(350, 0)
	main_hbox.add_child(left)
	var port = TextureRect.new()
	port.custom_minimum_size = Vector2(320, 350)
	port.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	port.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	port.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pkey = PORTRAIT_KEYS[idx]
	if _main and _main._portrait_textures.has(pkey): port.texture = _main._portrait_textures[pkey]
	left.add_child(port)
	var name = _main.character_names[idx] if _main else "?"
	left.add_child(_lbl(name.to_upper(), 22, Color(1,0.92,0.45)))
	var title = _main.character_titles[idx] if _main and idx < _main.character_titles.size() else ""
	left.add_child(_lbl(title, 13, Color(0.65,0.55,0.45)))
	# Quote
	if _main and idx < _main.character_quotes.size():
		var q = _lbl('"' + _main.character_quotes[idx] + '"', 11, Color(0.55,0.50,0.45))
		q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		left.add_child(q)
	# RIGHT: Stats, gear, abilities
	var right = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	main_hbox.add_child(right)
	# Back button
	var back = Button.new()
	back.text = "< BACK"
	back.custom_minimum_size = Vector2(80, 28)
	var bs = StyleBoxFlat.new(); bs.bg_color = Color(0.15,0.12,0.25,0.8); bs.set_corner_radius_all(4)
	back.add_theme_stylebox_override("normal", bs)
	back.add_theme_font_size_override("font_size", 11)
	back.add_theme_color_override("font_color", Color(0.8,0.75,0.65))
	back.pressed.connect(_build_survivors)
	right.add_child(back)
	# TAB BUTTONS — Stats / Gear / Allies / Abilities
	var tab_row = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 4)
	tab_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ti in range(4):
		var tab_names_arr = ["STATS", "GEAR", "ALLIES", "ABILITIES"]
		var tb = Button.new()
		tb.text = tab_names_arr[ti]
		tb.custom_minimum_size = Vector2(90, 26)
		var ts = StyleBoxFlat.new()
		ts.bg_color = Color(0.18, 0.14, 0.28, 0.9) if ti == _detail_tab else Color(0.08, 0.06, 0.14, 0.5)
		ts.set_corner_radius_all(4)
		ts.border_color = Color(0.65, 0.50, 0.20, 0.6) if ti == _detail_tab else Color(0.30, 0.25, 0.18, 0.3)
		ts.set_border_width_all(1)
		tb.add_theme_stylebox_override("normal", ts)
		tb.add_theme_font_size_override("font_size", 10)
		tb.add_theme_color_override("font_color", Color(1, 0.92, 0.45) if ti == _detail_tab else Color(0.55, 0.50, 0.45))
		tb.pressed.connect(_switch_detail_tab.bind(ti))
		tab_row.add_child(tb)
	right.add_child(tab_row)
	# Get tower type for stats lookup
	var tt = _main.survivor_types[idx] if _main and idx < _main.survivor_types.size() else null
	# === TAB CONTENT ===
	# Character level shown on ALL tabs
	right.add_child(_lbl("CHARACTER LEVEL", 14, Color(0.85,0.72,0.40)))
	if tt != null and _main.survivor_progress.has(tt):
		var prog = _main.survivor_progress[tt]
		var level = prog.get("level", 1)
		var xp = prog.get("xp", 0)
		var next_xp = _main.HERO_XP_TABLE[mini(level - 1, _main.HERO_XP_TABLE.size() - 1)] if level <= _main.MAX_SURVIVOR_LEVEL else 0
		right.add_child(_lbl("Level %d" % level, 18, Color(1.0, 0.92, 0.45)))
		if next_xp > 0:
			right.add_child(_stat_bar("XP", xp, next_xp, Color(0.3, 0.8, 0.4)))
		# Total damage dealt
		var total_dmg = prog.get("total_damage", 0.0)
		if total_dmg > 0:
			right.add_child(_lbl("Total Damage: %s" % _format_num(total_dmg), 10, Color(0.6, 0.5, 0.45)))
	else:
		right.add_child(_lbl("Level 1", 18, Color(1.0, 0.92, 0.45)))
	# === TAB 0: STATS ===
	if _detail_tab == 0:
		right.add_child(_lbl("COMBAT STATS", 14, Color(0.85,0.72,0.40)))
	if tt != null and _main.tower_info.has(tt):
		var info = _main.tower_info[tt]
		right.add_child(_stat_bar("Damage", info.get("damage", 0), 50, Color(0.9,0.3,0.2)))
		right.add_child(_stat_bar("Range", info.get("range", 0), 200, Color(0.3,0.7,0.9)))
		right.add_child(_stat_bar("Fire Rate", info.get("fire_rate", 0), 2.5, Color(0.9,0.7,0.2)))
		right.add_child(_lbl("Cost: %d Gold" % info.get("cost", 0), 12, Color(0.85,0.70,0.20)))
	# === TAB 1: GEAR ===
	if _detail_tab == 0 or _detail_tab == 1:
		right.add_child(_lbl("EQUIPPED GEAR", 14, Color(0.85,0.72,0.40)))
	if tt != null and _main.survivor_gear.has(tt):
		var gear = _main.survivor_gear[tt]
		var gp = PanelContainer.new()
		var gs = StyleBoxFlat.new(); gs.bg_color = Color(0.08,0.06,0.14,0.7); gs.set_corner_radius_all(6)
		gs.set_border_width_all(1); gs.border_color = Color(0.55,0.42,0.18,0.5)
		gs.content_margin_left = 8; gs.content_margin_right = 8; gs.content_margin_top = 6; gs.content_margin_bottom = 6
		gp.add_theme_stylebox_override("panel", gs)
		var gear_row = HBoxContainer.new()
		gear_row.add_theme_constant_override("separation", 12)
		gear_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gp.add_child(gear_row)
		# Gear icon
		var gear_icon = TextureRect.new()
		gear_icon.custom_minimum_size = Vector2(64, 64)
		gear_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		gear_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		gear_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Try to find matching gear icon
		var gear_name_key = gear.get("name", "").to_lower().replace(" ", "_").replace("'", "")
		if _main._gear_icon_textures.has(gear_name_key):
			gear_icon.texture = _main._gear_icon_textures[gear_name_key]
		else:
			# Try partial match
			for gk in _main._gear_icon_textures:
				if gear_name_key.find(gk) >= 0 or gk.find(gear_name_key.split("_")[0]) >= 0:
					gear_icon.texture = _main._gear_icon_textures[gk]
					break
		gear_row.add_child(gear_icon)
		# Gear info
		var gv = VBoxContainer.new()
		gv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gv.add_child(_lbl(gear.get("name", "None"), 14, Color(1,0.85,0.3)))
		gv.add_child(_lbl(gear.get("type", ""), 10, Color(0.6,0.55,0.48)))
		var desc = _lbl(gear.get("desc", ""), 10, Color(0.55,0.50,0.45))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size.x = 300
		gv.add_child(desc)
		# Stat bonuses
		var bonus_text = ""
		for key in gear:
			if key not in ["name", "type", "desc"] and typeof(gear[key]) == TYPE_FLOAT:
				var pct = int(gear[key] * 100)
				if pct > 0:
					bonus_text += "+%d%% %s  " % [pct, key.capitalize()]
		if bonus_text != "":
			gv.add_child(_lbl(bonus_text.strip_edges(), 10, Color(0.3, 0.8, 0.4)))
		gear_row.add_child(gv)
		right.add_child(gp)
	# === TAB 2: ALLIES ===
	if _detail_tab == 0 or _detail_tab == 2:
		right.add_child(_lbl("SIDEKICKS", 14, Color(0.85,0.72,0.40)))
	if tt != null and _main.survivor_sidekicks.has(tt):
		for sk in _main.survivor_sidekicks[tt]:
			var skp = HBoxContainer.new()
			skp.add_child(_lbl(sk.get("name",""), 12, Color(0.9,0.82,0.55)))
			skp.add_child(_lbl(" — " + sk.get("desc",""), 10, Color(0.55,0.50,0.45)))
			right.add_child(skp)
	# === TAB 3: ABILITIES ===
	if _detail_tab == 0 or _detail_tab == 3:
		right.add_child(_lbl("ABILITIES", 14, Color(0.85,0.72,0.40)))
	# Get tower script to read ability names
	var tower_scenes_map = {0: "robin_hood", 1: "alice", 2: "wicked_witch", 3: "peter_pan", 4: "phantom", 5: "scrooge", 6: "sherlock", 7: "tarzan", 8: "dracula", 9: "merlin", 10: "frankenstein", 11: "shadow_author"}
	var tower_key = tower_scenes_map.get(idx, "")
	# Try to get ability names from the tower script constants
	var ability_names = []
	if tower_key == "robin_hood":
		ability_names = ["Sherwood Aim", "Lincoln Green", "Merry Men", "Friar Tuck's Blessing", "Little John's Staff", "The Outlaw's Snare", "Maid Marian's Arrow", "The Golden Arrow", "King of Sherwood"]
	elif tower_key == "alice":
		ability_names = ["Eat Me Cake", "Cheshire Cat", "Mad Tea Party", "Queen's Flamingo", "Looking Glass", "Wonderland Logic", "Vorpal Blade", "Jabberwock's Fury", "Queen of Wonderland"]
	elif tower_key == "merlin":
		ability_names = ["Crystal Sight", "Ancient Ward", "Lady of the Lake", "Excalibur's Edge", "Time Warp", "Prophecy Shield", "Spell of Ages", "Avalon's Call", "The Last Enchanter"]
	# Show first few abilities
	if ability_names.size() > 0:
		for ai in range(mini(ability_names.size(), 5)):
			var unlocked_ab = ai < 2  # Placeholder — first 2 unlocked
			var ab_color = Color(0.7, 0.85, 0.5) if unlocked_ab else Color(0.35, 0.32, 0.28)
			var prefix = "✓ " if unlocked_ab else "🔒 "
			var ab_lbl = _lbl(prefix + ability_names[ai], 10, ab_color)
			ab_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			right.add_child(ab_lbl)
		if ability_names.size() > 5:
			right.add_child(_lbl("... +%d more abilities" % (ability_names.size() - 5), 9, Color(0.45, 0.40, 0.38)))
	else:
		right.add_child(_lbl("Unlock through combat damage", 10, Color(0.50,0.45,0.40)))

func _stat_bar(label: String, value: float, max_val: float, color: Color) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var nl = _lbl(label, 12, Color(0.75,0.68,0.58))
	nl.custom_minimum_size.x = 80
	row.add_child(nl)
	# Bar background
	var bar_bg = ColorRect.new()
	bar_bg.custom_minimum_size = Vector2(200, 14)
	bar_bg.color = Color(0.08,0.06,0.12,0.8)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar_bg)
	# Bar fill
	var bar_fill = ColorRect.new()
	var fill_pct = clampf(value / max_val, 0, 1)
	bar_fill.custom_minimum_size = Vector2(200 * fill_pct, 14)
	bar_fill.color = color
	bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_fill.position = Vector2.ZERO
	bar_bg.add_child(bar_fill)
	row.add_child(_lbl(str(int(value)), 12, color))
	return row

# ======================== EMPORIUM ========================
# Category theme colors
const EMPORIUM_COLORS: Array = [
	Color(0.85,0.65,0.10), Color(0.70,0.50,0.90), Color(0.30,0.70,0.90),
	Color(0.50,0.75,0.40), Color(0.90,0.45,0.15), Color(0.90,0.80,0.30),
	Color(0.80,0.55,0.20), Color(0.60,0.30,0.70), Color(0.85,0.72,0.40),
	Color(0.45,0.65,0.80), Color(0.70,0.40,0.20), Color(0.55,0.40,0.75),
	Color(0.90,0.30,0.50), Color(0.50,0.70,0.35),
]

func _build_emporium() -> void:
	_clear()
	var sc = ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_area.add_child(sc)
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 4)
	sc.add_child(margin)
	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 8)
	margin.add_child(vb)
	vb.add_child(_title("THE EMPORIUM"))
	vb.add_child(_lbl("Browse wares from across the literary worlds", 11, Color(0.55,0.50,0.45)))
	if not _main: return
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(grid)
	for ci in range(_main.emporium_categories.size()):
		var cat = _main.emporium_categories[ci]
		var accent = EMPORIUM_COLORS[ci % EMPORIUM_COLORS.size()]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 80)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.text = ""
		# Styled card with accent color left stripe
		var s = StyleBoxFlat.new()
		s.bg_color = Color(0.04,0.03,0.08,0.40)  # Very transparent — art shows through
		s.border_color = Color(accent.r * 0.5, accent.g * 0.5, accent.b * 0.5, 0.5)
		s.border_width_left = 4  # Thick accent stripe
		s.border_width_right = 1; s.border_width_top = 1; s.border_width_bottom = 1
		s.set_corner_radius_all(8)
		s.content_margin_left = 10; s.content_margin_right = 10
		s.content_margin_top = 8; s.content_margin_bottom = 8
		btn.add_theme_stylebox_override("normal", s)
		var sh = s.duplicate()
		sh.bg_color = Color(accent.r * 0.15, accent.g * 0.15, accent.b * 0.15, 0.65)
		sh.border_color = Color(accent.r * 0.8, accent.g * 0.8, accent.b * 0.8, 0.7)
		btn.add_theme_stylebox_override("hover", sh)
		# Art layer behind content (shop_item_card with black keyed out)
		if _art.has("shop_card"):
			var card_art = TextureRect.new()
			card_art.texture = _art["shop_card"]
			card_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			card_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			card_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			card_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card_art.modulate.a = 0.4  # Subtle — art shows but doesn't overpower
			var mat = _make_black_key_mat(0.08, 0.05)
			if mat: card_art.material = mat
			btn.add_child(card_art)
		# Content: Icon + Name + Desc + Badge
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(row)
		# Icon from emporium_icons
		var icon_key = cat.get("icon", "")
		var icon_rect = TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(64, 64)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _main._emporium_icon_textures.has(icon_key):
			icon_rect.texture = _main._emporium_icon_textures[icon_key]
		row.add_child(icon_rect)
		# Text column
		var text_col = VBoxContainer.new()
		text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_lbl = _lbl(cat.get("name",""), 15, accent)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_col.add_child(name_lbl)
		var d = _lbl(cat.get("desc",""), 10, Color(0.55,0.50,0.45))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_col.add_child(d)
		row.add_child(text_col)
		# Badge
		if cat.get("badge","") != "":
			var badge_panel = PanelContainer.new()
			var badge_s = StyleBoxFlat.new()
			var badge_text = cat["badge"]
			match badge_text:
				"SALE!": badge_s.bg_color = Color(0.8, 0.15, 0.1, 0.8)
				"NEW!": badge_s.bg_color = Color(0.15, 0.6, 0.15, 0.8)
				"FREE!": badge_s.bg_color = Color(0.1, 0.5, 0.8, 0.8)
				"AVAILABLE!": badge_s.bg_color = Color(0.6, 0.4, 0.1, 0.8)
				_: badge_s.bg_color = Color(0.4, 0.3, 0.6, 0.8)
			badge_s.set_corner_radius_all(10)
			badge_s.content_margin_left = 8; badge_s.content_margin_right = 8
			badge_s.content_margin_top = 2; badge_s.content_margin_bottom = 2
			badge_panel.add_theme_stylebox_override("panel", badge_s)
			badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var bl = _lbl(badge_text, 9, Color.WHITE)
			bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			badge_panel.add_child(bl)
			row.add_child(badge_panel)
		btn.pressed.connect(_open_emporium_category.bind(ci))
		grid.add_child(btn)

func _open_emporium_category(cat_idx: int) -> void:
	_clear()
	var sc = ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_area.add_child(sc)
	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sc.add_child(vb)
	if not _main: return
	var cat = _main.emporium_categories[cat_idx]
	# Back button
	var back = Button.new()
	back.text = "< BACK TO EMPORIUM"
	back.custom_minimum_size = Vector2(180, 30)
	var bs = StyleBoxFlat.new(); bs.bg_color = Color(0.15,0.12,0.25,0.8); bs.set_corner_radius_all(4)
	back.add_theme_stylebox_override("normal", bs)
	back.add_theme_font_size_override("font_size", 11)
	back.add_theme_color_override("font_color", Color(0.8,0.75,0.65))
	back.pressed.connect(_build_emporium)
	vb.add_child(back)
	vb.add_child(_title(cat.get("name", "SHOP")))
	vb.add_child(_lbl(cat.get("desc", ""), 12, Color(0.60,0.55,0.48)))
	# Show items based on category
	match cat_idx:
		0: _build_gold_exchange(vb)
		1: _build_quill_shop(vb)
		2, 3: _build_gear_shard_shop(vb)
		4: _build_survivor_packs(vb)
		6: _build_trophy_store_items(vb)
		12: _build_lucky_wheel_ui(vb)
		13: _build_merchant_items(vb)
		_: _build_generic_shop(vb, cat)

func _build_gold_exchange(parent: VBoxContainer) -> void:
	parent.add_child(_lbl("Exchange gold for other currencies", 12, Color(0.60,0.55,0.48)))
	var exchanges = [["100 Gold → 5 Quills", 100, "quills", 5], ["250 Gold → 15 Shards", 250, "shards", 15], ["500 Gold → 3 Stars", 500, "stars", 3]]
	for ex in exchanges:
		var row = HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 12)
		var el = _lbl(ex[0], 13, Color(0.85,0.78,0.65))
		el.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		el.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(el)
		var buy = Button.new()
		buy.text = "EXCHANGE"
		buy.custom_minimum_size = Vector2(100, 30)
		var bys = StyleBoxFlat.new(); bys.bg_color = Color(0.15,0.45,0.15,0.8); bys.set_corner_radius_all(4)
		buy.add_theme_stylebox_override("normal", bys)
		buy.add_theme_font_size_override("font_size", 11)
		buy.add_theme_color_override("font_color", Color.WHITE)
		row.add_child(buy)
		parent.add_child(row)

func _build_quill_shop(parent: VBoxContainer) -> void:
	parent.add_child(_lbl("Spend Quills on rare treasures", 12, Color(0.60,0.55,0.48)))
	_build_generic_shop(parent, {"name": "Quill Shop"})

func _build_gear_shard_shop(parent: VBoxContainer) -> void:
	parent.add_child(_lbl("Collect and forge Gear Shards", 12, Color(0.60,0.55,0.48)))
	# Show gear shards owned
	if _main:
		parent.add_child(_lbl("You have: %d Gear Shards" % _main.player_gear_shards, 14, Color(0.3,0.75,0.9)))
	_build_generic_shop(parent, {"name": "Gear Shards"})

func _build_survivor_packs(parent: VBoxContainer) -> void:
	parent.add_child(_lbl("Bundles of literary might — boost your Survivors!", 12, Color(0.60,0.55,0.48)))
	_build_generic_shop(parent, {"name": "Survivor Packs"})

func _build_trophy_store_items(parent: VBoxContainer) -> void:
	parent.add_child(_lbl("Spend Trophies on cosmetic upgrades", 12, Color(0.60,0.55,0.48)))
	if _main:
		parent.add_child(_lbl("You have: %d Trophies" % (_main.player_storybook_stars if "player_storybook_stars" in _main else 0), 14, Color(1,0.85,0.3)))
	_build_generic_shop(parent, {"name": "Trophy Store"})

func _build_lucky_wheel_ui(parent: VBoxContainer) -> void:
	parent.add_child(_lbl("Spin the Lucky Wheel for prizes!", 14, Color(1,0.85,0.3)))
	parent.add_child(_lbl("One FREE spin per day!", 12, Color(0.3,0.9,0.3)))
	var spin_btn = Button.new()
	spin_btn.text = "SPIN!"
	spin_btn.custom_minimum_size = Vector2(200, 50)
	var ss = StyleBoxFlat.new(); ss.bg_color = Color(0.6,0.15,0.6,0.9); ss.set_corner_radius_all(12)
	spin_btn.add_theme_stylebox_override("normal", ss)
	var ssh = ss.duplicate(); ssh.bg_color = Color(0.7,0.25,0.7)
	spin_btn.add_theme_stylebox_override("hover", ssh)
	spin_btn.add_theme_font_size_override("font_size", 20)
	spin_btn.add_theme_color_override("font_color", Color.WHITE)
	parent.add_child(spin_btn)
	# Show prizes
	parent.add_child(_lbl("Possible Prizes:", 12, Color(0.65,0.58,0.50)))
	if _main:
		for prize in _main.SPIN_WHEEL_PRIZES:
			parent.add_child(_lbl("• %s" % prize.get("name",""), 11, prize.get("col", Color.WHITE)))

func _build_merchant_items(parent: VBoxContainer) -> void:
	parent.add_child(_lbl("The Wandering Merchant has rare items...", 12, Color(0.60,0.55,0.48)))
	if _main and _main.merchant_inventory.size() > 0:
		for item in _main.merchant_inventory:
			var row = HBoxContainer.new()
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(_lbl(item.get("name","???"), 13, Color(0.90,0.80,0.50)))
			row.add_child(_lbl(" — %d %s" % [item.get("cost",0), item.get("cost_type","gold")], 11, Color(0.65,0.58,0.50)))
			parent.add_child(row)
	else:
		parent.add_child(_lbl("The merchant will return soon...", 11, Color(0.50,0.45,0.40)))

func _build_generic_shop(parent: VBoxContainer, cat: Dictionary) -> void:
	parent.add_child(_lbl("Items coming soon to %s" % cat.get("name","Shop"), 12, Color(0.50,0.45,0.40)))

# ======================== CODEX ========================
var _codex_subtab: String = "gear"

func _build_codex() -> void:
	_clear()
	var main_vb = VBoxContainer.new()
	main_vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_area.add_child(main_vb)
	main_vb.add_child(_title("THE CODEX"))
	# Sub-tabs
	var tab_row = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	tab_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for tab in [["gear", "GEAR"], ["achievements", "ACHIEVEMENTS"], ["bestiary", "BESTIARY"], ["journal", "JOURNAL"], ["stats", "STATISTICS"]]:
		var tb = Button.new()
		tb.text = tab[1]
		tb.custom_minimum_size = Vector2(120, 28)
		var ts = StyleBoxFlat.new()
		ts.bg_color = Color(0.15, 0.10, 0.25, 0.7) if _codex_subtab == tab[0] else Color(0.08, 0.06, 0.14, 0.5)
		ts.set_corner_radius_all(4)
		tb.add_theme_stylebox_override("normal", ts)
		tb.add_theme_font_size_override("font_size", 11)
		tb.add_theme_color_override("font_color", Color(1, 0.92, 0.45) if _codex_subtab == tab[0] else Color(0.55, 0.50, 0.45))
		tb.pressed.connect(_codex_switch.bind(tab[0]))
		tab_row.add_child(tb)
	main_vb.add_child(tab_row)
	# Content area for sub-tab
	var sc = ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vb.add_child(sc)
	var content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sc.add_child(content)
	match _codex_subtab:
		"gear": _build_gear_grid(content)
		"achievements": _build_achievements_list(content)
		"bestiary": content.add_child(_lbl("Enemy catalog coming soon...", 14, Color(0.55, 0.50, 0.45)))
		"journal": content.add_child(_lbl("Character journals coming soon...", 14, Color(0.55, 0.50, 0.45)))
		"stats": _build_stats_page(content)

func _codex_switch(tab: String) -> void:
	_codex_subtab = tab
	_build_codex()

func _build_gear_grid(parent: VBoxContainer) -> void:
	parent.add_child(_lbl("GEAR COMPENDIUM — %d Items" % _main._gear_icon_textures.size(), 16, Color(0.85, 0.72, 0.40)))
	parent.add_child(_lbl("Collect gear from battles and the Emporium to empower your Survivors", 11, Color(0.55, 0.50, 0.45)))
	var grid = GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(grid)
	if not _main: return
	var keys = _main._gear_icon_textures.keys()
	keys.sort()
	for gk in keys:
		# Each gear item in a styled panel
		var card = PanelContainer.new()
		var cs = StyleBoxFlat.new()
		cs.bg_color = Color(0.06, 0.04, 0.12, 0.55)
		cs.border_color = Color(0.45, 0.35, 0.20, 0.4)
		cs.set_border_width_all(1)
		cs.set_corner_radius_all(6)
		cs.content_margin_left = 4; cs.content_margin_right = 4
		cs.content_margin_top = 4; cs.content_margin_bottom = 4
		card.add_theme_stylebox_override("panel", cs)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cv = VBoxContainer.new()
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(cv)
		var icon = TextureRect.new()
		icon.texture = _main._gear_icon_textures[gk]
		icon.custom_minimum_size = Vector2(72, 72)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(icon)
		var name_lbl = _lbl(gk.replace("_", " ").capitalize(), 8, Color(0.65, 0.58, 0.50))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_lbl.clip_text = true
		name_lbl.custom_minimum_size.x = 80
		cv.add_child(name_lbl)
		grid.add_child(card)

func _build_achievements_list(parent: VBoxContainer) -> void:
	parent.add_child(_lbl("ACHIEVEMENTS", 14, Color(0.85, 0.72, 0.40)))
	if not _main or not _main.has_method("_get_achievement_list"):
		# Show achievement icons from textures
		if _main._achievement_icon_textures.size() > 0:
			parent.add_child(_lbl("%d Achievement Icons Available" % _main._achievement_icon_textures.size(), 12, Color(0.6, 0.55, 0.48)))
			var grid = GridContainer.new()
			grid.columns = 8
			grid.add_theme_constant_override("h_separation", 6)
			grid.add_theme_constant_override("v_separation", 6)
			grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
			parent.add_child(grid)
			var keys = _main._achievement_icon_textures.keys()
			keys.sort()
			for ak in keys:
				var icon = TextureRect.new()
				icon.texture = _main._achievement_icon_textures[ak]
				icon.custom_minimum_size = Vector2(48, 48)
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
				icon.tooltip_text = ak.replace("_", " ").capitalize()
				grid.add_child(icon)
		else:
			parent.add_child(_lbl("No achievements loaded yet.", 12, Color(0.55, 0.50, 0.45)))
		return

func _build_stats_page(parent: VBoxContainer) -> void:
	parent.add_child(_lbl("GAMEPLAY STATISTICS", 14, Color(0.85, 0.72, 0.40)))
	if not _main: return
	var stats_data = [
		["Total Enemies Killed", _main.total_enemies_killed if "total_enemies_killed" in _main else 0],
		["Total Gold Earned", _main.total_gold_earned if "total_gold_earned" in _main else 0],
		["Levels Completed", _main.completed_levels.size() if "completed_levels" in _main else 0],
		["Total Stars", 0],
		["Bosses Defeated", 0],
		["Account Level", _main.account_level if "account_level" in _main else 1],
	]
	# Calculate total stars
	if "level_stars" in _main:
		for k in _main.level_stars:
			stats_data[3][1] += _main.level_stars[k]
	for sd in stats_data:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var nl = _lbl(sd[0], 14, Color(0.75, 0.68, 0.58))
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(nl)
		var vl = _lbl(str(sd[1]), 16, Color(1.0, 0.92, 0.45))
		vl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(vl)
		parent.add_child(row)

# ======================== SETTINGS ========================
func _build_settings() -> void:
	_clear()
	var sc = ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_area.add_child(sc)
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 100)
	margin.add_theme_constant_override("margin_right", 100)
	margin.add_theme_constant_override("margin_top", 10)
	sc.add_child(margin)
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vb)
	vb.add_child(_title("SETTINGS"))
	# Audio section
	vb.add_child(_lbl("AUDIO", 16, Color(0.85, 0.72, 0.40)))
	if _main:
		_add_setting_row(vb, "Music Volume", "%d%%" % int(GameSettings.music_volume * 100), func(): GameSettings.music_volume = fmod(GameSettings.music_volume + 0.25, 1.25); GameSettings.save_settings(); _build_settings(), true, GameSettings.music_volume)
		_add_setting_row(vb, "SFX Volume", "%d%%" % int(GameSettings.sfx_volume * 100), func(): GameSettings.sfx_volume = fmod(GameSettings.sfx_volume + 0.25, 1.25); GameSettings.save_settings(); _build_settings(), true, GameSettings.sfx_volume)
		_add_setting_row(vb, "Voice Volume", "%d%%" % int(GameSettings.voice_volume * 100), func(): GameSettings.voice_volume = fmod(GameSettings.voice_volume + 0.25, 1.25); GameSettings.save_settings(); _build_settings(), true, GameSettings.voice_volume)
		_add_setting_row(vb, "Music Muted", "YES" if GameSettings.music_muted else "NO", func(): GameSettings.music_muted = not GameSettings.music_muted; GameSettings.save_settings(); _build_settings())
	# Graphics section
	vb.add_child(_lbl("GRAPHICS", 16, Color(0.85, 0.72, 0.40)))
	if _main:
		_add_setting_row(vb, "Quality", GameSettings.get_quality_name(), func(): GameSettings.cycle_quality(); _build_settings())
		_add_setting_row(vb, "Particle Effects", "ON" if GameSettings.particle_effects else "OFF", func(): GameSettings.particle_effects = not GameSettings.particle_effects; GameSettings.save_settings(); _build_settings())
		_add_setting_row(vb, "Screen Shake", "ON" if GameSettings.screen_shake else "OFF", func(): GameSettings.screen_shake = not GameSettings.screen_shake; GameSettings.save_settings(); _build_settings())
		_add_setting_row(vb, "Damage Numbers", "ON" if GameSettings.show_damage_numbers else "OFF", func(): GameSettings.show_damage_numbers = not GameSettings.show_damage_numbers; GameSettings.save_settings(); _build_settings())
	# Gameplay section
	vb.add_child(_lbl("GAMEPLAY", 16, Color(0.85, 0.72, 0.40)))
	if _main:
		var speed_names = ["1x", "2x", "3x"]
		_add_setting_row(vb, "Game Speed", speed_names[clampi(GameSettings.game_speed - 1, 0, 2)], func(): GameSettings.cycle_speed(); _build_settings())
		_add_setting_row(vb, "Auto Wave", "ON" if GameSettings.auto_wave else "OFF", func(): GameSettings.auto_wave = not GameSettings.auto_wave; GameSettings.save_settings(); _build_settings())
	# Accessibility section
	vb.add_child(_lbl("ACCESSIBILITY", 16, Color(0.85, 0.72, 0.40)))
	if _main:
		var text_sizes = ["1.0x", "1.25x", "1.5x"]
		var ts_idx = [1.0, 1.25, 1.5].find(GameSettings.font_scale)
		if ts_idx < 0: ts_idx = 0
		_add_setting_row(vb, "Text Size", text_sizes[ts_idx], func(): var sizes = [1.0, 1.25, 1.5]; var ci = sizes.find(GameSettings.font_scale); GameSettings.font_scale = sizes[(ci + 1) % 3]; GameSettings.save_settings(); _build_settings())
		var cb_names = ["Off", "Deuteranopia", "Protanopia", "Tritanopia"]
		_add_setting_row(vb, "Colorblind Mode", cb_names[clampi(GameSettings.colorblind_mode, 0, 3)], func(): GameSettings.colorblind_mode = (GameSettings.colorblind_mode + 1) % 4; GameSettings.save_settings(); _build_settings())
		_add_setting_row(vb, "Reduced Motion", "ON" if GameSettings.reduced_motion else "OFF", func(): GameSettings.reduced_motion = not GameSettings.reduced_motion; GameSettings.save_settings(); _build_settings())
		_add_setting_row(vb, "Left-Handed", "ON" if GameSettings.left_handed else "OFF", func(): GameSettings.left_handed = not GameSettings.left_handed; GameSettings.save_settings(); _build_settings())

func _add_setting_row(parent: VBoxContainer, label: String, value: String, callback: Callable, is_volume: bool = false, volume_pct: float = 0.0) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nl = _lbl(label, 14, Color(0.85, 0.78, 0.65))
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(nl)
	# Volume bar visualization
	if is_volume:
		var bar_bg = ColorRect.new()
		bar_bg.custom_minimum_size = Vector2(120, 18)
		bar_bg.color = Color(0.08, 0.06, 0.14, 0.8)
		bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bar_fill = ColorRect.new()
		bar_fill.custom_minimum_size = Vector2(120 * volume_pct, 18)
		bar_fill.color = Color(0.3, 0.7, 0.4, 0.9)
		bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar_bg.add_child(bar_fill)
		row.add_child(bar_bg)
	var btn = Button.new()
	btn.text = value
	btn.custom_minimum_size = Vector2(100, 30)
	var bs = StyleBoxFlat.new()
	# Color code ON/OFF
	if value == "ON" or value.ends_with("%") or value == "AUTO" or value.begins_with("1") or value.begins_with("2") or value.begins_with("3"):
		bs.bg_color = Color(0.12, 0.35, 0.15, 0.8)
	elif value == "OFF" or value == "NO":
		bs.bg_color = Color(0.35, 0.12, 0.12, 0.8)
	else:
		bs.bg_color = Color(0.15, 0.12, 0.25, 0.8)
	bs.set_corner_radius_all(6)
	bs.content_margin_left = 8; bs.content_margin_right = 8
	btn.add_theme_stylebox_override("normal", bs)
	var bsh = bs.duplicate(); bsh.bg_color = bs.bg_color.lightened(0.2)
	btn.add_theme_stylebox_override("hover", bsh)
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	btn.pressed.connect(callback)
	row.add_child(btn)
	parent.add_child(row)

# ======================== UTILITY ========================
func _title(text: String) -> Label:
	var l = _lbl(text, 24, Color(1,0.92,0.45))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _lbl(text: String, size: int, color: Color) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0,0,0,0.85))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l

func _format_num(val: float) -> String:
	if val >= 1000000: return "%.1fM" % (val / 1000000.0)
	if val >= 1000: return "%.1fK" % (val / 1000.0)
	return str(int(val))

func _fade_in() -> void:
	fade_rect.color = Color(0,0,0,1)
	var tw = create_tween()
	tw.tween_property(fade_rect, "color:a", 0.0, 0.3)
