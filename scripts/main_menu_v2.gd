extends Control
## MainMenuV2 — Clean, functional menu. Art backgrounds, simple UI, everything works.

var _backgrounds: Dictionary = {}
var _ui_tex: Dictionary = {}
var _main: Node = null
var current_view: String = "chapters"

@onready var background: TextureRect = $BackgroundLayer/Background
@onready var content_area: Control = $UILayer/UI/ContentArea
@onready var nav_buttons_container: HBoxContainer = $UILayer/UI/NavBar/NavButtons
@onready var top_bar: TextureRect = $UILayer/UI/TopBar
@onready var nav_bar: TextureRect = $UILayer/UI/NavBar
@onready var fade_rect: ColorRect = $TransitionLayer/FadeRect

func _ready() -> void:
	_main = get_tree().get_first_node_in_group("main")
	_load_textures()
	_setup_background("chapters")
	_setup_currency_bar()
	_setup_nav_bar()
	_build_chapters_view()
	_fade_in()

func _load_textures() -> void:
	var bgs = {"chapters": "res://assets/ui_frames/scroll_banner.png", "survivors": "res://assets/menu_art/survivors_bg_books.png", "emporium": "res://assets/menu_art/emporium_bg_merchant.png", "codex": "res://assets/menu_art/codex_bg.png", "settings": "res://assets/menu_art/settings_bg_v2.png"}
	for k in bgs:
		if ResourceLoader.exists(bgs[k]):
			_backgrounds[k] = load(bgs[k])

func _setup_background(view: String) -> void:
	if _backgrounds.has(view):
		background.texture = _backgrounds[view]
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

func _setup_currency_bar() -> void:
	if not _main:
		return
	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 24)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	top_bar.add_child(hbox)
	# Dark background for readability
	top_bar.modulate = Color(1, 1, 1, 0.9)
	var currencies = [
		[str(_main.gold) if "gold" in _main else "0", "GOLD", Color(1.0, 0.85, 0.2)],
		[str(_main.player_quills) if "player_quills" in _main else "0", "QUILLS", Color(0.7, 0.5, 0.9)],
		[str(_main.player_gear_shards) if "player_gear_shards" in _main else "0", "SHARDS", Color(0.3, 0.75, 0.9)],
		[str(_main.player_storybook_stars) if "player_storybook_stars" in _main else "0", "STARS", Color(1.0, 0.9, 0.3)],
	]
	for c in currencies:
		var lbl = _lbl(c[0] + " " + c[1], 13, c[2])
		hbox.add_child(lbl)

func _setup_nav_bar() -> void:
	# Solid dark bar for clear nav visibility
	nav_bar.modulate = Color(1, 1, 1, 1)
	# Add a dark background behind the nav
	# Dark background behind nav — MUST be mouse_filter IGNORE
	var nav_bg = ColorRect.new()
	nav_bg.color = Color(0.05, 0.03, 0.10, 0.92)
	nav_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	nav_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nav_bar.add_child(nav_bg)
	nav_bar.move_child(nav_bg, 0)
	# NavButtons container must pass clicks TO the buttons
	nav_buttons_container.mouse_filter = Control.MOUSE_FILTER_PASS
	var tabs = ["chapters", "survivors", "emporium", "codex", "settings"]
	var labels = ["CHAPTERS", "SURVIVORS", "EMPORIUM", "CODEX", "SETTINGS"]
	for i in range(tabs.size()):
		var btn = Button.new()
		btn.text = labels[i]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 70)
		# Style
		var s = StyleBoxFlat.new()
		s.bg_color = Color(0.12, 0.08, 0.20, 0.0)  # Transparent by default
		s.set_corner_radius_all(0)
		btn.add_theme_stylebox_override("normal", s)
		var sh = s.duplicate()
		sh.bg_color = Color(0.25, 0.18, 0.40, 0.5)
		btn.add_theme_stylebox_override("hover", sh)
		var sp = s.duplicate()
		sp.bg_color = Color(0.15, 0.10, 0.30, 0.7)
		btn.add_theme_stylebox_override("pressed", sp)
		btn.add_theme_font_size_override("font_size", 13)
		# Highlight current tab
		if tabs[i] == current_view:
			btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
		else:
			btn.add_theme_color_override("font_color", Color(0.6, 0.55, 0.50))
		btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		btn.add_theme_constant_override("shadow_offset_x", 1)
		btn.add_theme_constant_override("shadow_offset_y", 1)
		btn.flat = false
		btn.pressed.connect(_on_tab.bind(tabs[i]))
		nav_buttons_container.add_child(btn)

func _on_tab(tab: String) -> void:
	if current_view == tab:
		return
	current_view = tab
	_setup_background(tab)
	# Rebuild nav highlight
	var tabs = ["chapters", "survivors", "emporium", "codex", "settings"]
	for i in range(nav_buttons_container.get_child_count()):
		var btn = nav_buttons_container.get_child(i)
		if btn is Button:
			if tabs[i] == tab:
				btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
			else:
				btn.add_theme_color_override("font_color", Color(0.6, 0.55, 0.50))
	_clear()
	match tab:
		"chapters": _build_chapters_view()
		"survivors": _build_survivors_view()
		"emporium": _build_emporium_view()
		"codex": _build_codex_view()
		"settings": _build_settings_view()

func _clear() -> void:
	for c in content_area.get_children():
		c.queue_free()

# ==================== CHAPTERS ====================
func _build_chapters_view() -> void:
	_clear()
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_area.add_child(scroll)
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)
	var title = _lbl("THE TOME OF SHADOWS", 24, Color(1.0, 0.92, 0.45))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	# Once Upon a Time story hook
	var story_hook = _lbl("Heroes pulled from their stories. Villains rewritten as weapons. One Author controls them all.", 11, Color(0.60, 0.55, 0.48))
	story_hook.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story_hook.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(story_hook)
	if not _main:
		return
	# Group levels into story arcs with headers
	var current_arc = ""
	for i in range(_main.levels.size()):
		var lvl = _main.levels[i]
		var subtitle = lvl.get("subtitle", "")
		# Extract arc name from subtitle (e.g. "Sherlock Holmes — Chapter 1" → "Sherlock Holmes")
		var arc_name = subtitle.split(" — ")[0] if " — " in subtitle else subtitle.split(" —")[0] if " —" in subtitle else "Prologue"
		if arc_name == "":
			arc_name = "Prologue"
		if arc_name != current_arc:
			current_arc = arc_name
			# Arc header
			var header = PanelContainer.new()
			var hs = StyleBoxFlat.new()
			hs.bg_color = Color(0.10, 0.06, 0.18, 0.60)
			hs.set_corner_radius_all(4)
			hs.content_margin_left = 12
			hs.content_margin_top = 4
			hs.content_margin_bottom = 4
			header.add_theme_stylebox_override("panel", hs)
			var hl = _lbl(arc_name.to_upper(), 16, Color(0.90, 0.80, 0.50))
			header.add_child(hl)
			vbox.add_child(header)
		vbox.add_child(_level_card(i))

func _level_card(idx: int) -> PanelContainer:
	var lvl = _main.levels[idx]
	var unlocked = _main._is_level_unlocked(idx)
	var complete = idx in _main.completed_levels
	var p = PanelContainer.new()
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.04, 0.03, 0.10, 0.55) if unlocked else Color(0.03, 0.02, 0.06, 0.40)
	if complete:
		s.border_color = Color(0.3, 0.65, 0.25, 0.6)
		s.set_border_width_all(2)
	else:
		s.border_color = Color(0.35, 0.25, 0.18, 0.4)
		s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", s)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	p.add_child(row)
	# Number
	row.add_child(_lbl(str(idx + 1), 20, Color(0.85, 0.72, 0.40) if unlocked else Color(0.35, 0.30, 0.25)))
	# Thumbnail
	var thumb = TextureRect.new()
	thumb.custom_minimum_size = Vector2(100, 70)
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if _main._map_thumb_textures.has(idx):
		thumb.texture = _main._map_thumb_textures[idx]
	row.add_child(thumb)
	# Info column
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(_lbl(lvl.get("name", ""), 16, Color(1, 0.95, 0.85) if unlocked else Color(0.45, 0.40, 0.35)))
	info.add_child(_lbl(lvl.get("subtitle", ""), 11, Color(0.55, 0.48, 0.42)))
	info.add_child(_lbl("W:%d G:%d L:%d" % [lvl.get("waves", 20), lvl.get("gold", 100), lvl.get("lives", 20)], 10, Color(0.45, 0.40, 0.38)))
	# Story flavor text from the level description
	var desc_text = lvl.get("description", "")
	if desc_text != "" and unlocked:
		var flavor = _lbl(desc_text, 9, Color(0.50, 0.45, 0.40))
		flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		flavor.custom_minimum_size.x = 400
		info.add_child(flavor)
	row.add_child(info)
	# Difficulty + Play buttons
	if unlocked:
		var btns = VBoxContainer.new()
		btns.add_theme_constant_override("separation", 3)
		# Difficulty row — ornate gem buttons
		var drow = HBoxContainer.new()
		drow.add_theme_constant_override("separation", 4)
		var diff_tex = null
		if ResourceLoader.exists("res://assets/ui_elements/difficulty_buttons_v2.png"):
			diff_tex = load("res://assets/ui_elements/difficulty_buttons_v2.png")
		for di in range(3):
			var db = TextureButton.new()
			db.custom_minimum_size = Vector2(75, 60)
			db.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			db.ignore_texture_size = true
			if diff_tex:
				var atlas = AtlasTexture.new()
				atlas.atlas = diff_tex
				var gem_w = diff_tex.get_width() / 3.0
				atlas.region = Rect2(di * gem_w, 0, gem_w, diff_tex.get_height())
				db.texture_normal = atlas
			db.pressed.connect(_play.bind(idx, di))
			drow.add_child(db)
		btns.add_child(drow)
		# PLAY button — ornate emerald gemstone art
		var play = TextureButton.new()
		play.custom_minimum_size = Vector2(220, 65)
		play.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		play.ignore_texture_size = true
		if ResourceLoader.exists("res://assets/ui_elements/play_button_v2.png"):
			play.texture_normal = load("res://assets/ui_elements/play_button_v2.png")
		else:
			# Fallback — simple green button if art missing
			var fb = Button.new()
			fb.text = "PLAY"
			fb.custom_minimum_size = Vector2(150, 40)
			var fbs = StyleBoxFlat.new()
			fbs.bg_color = Color(0.15, 0.55, 0.15)
			fbs.set_corner_radius_all(6)
			fb.add_theme_stylebox_override("normal", fbs)
			fb.add_theme_font_size_override("font_size", 14)
			fb.add_theme_color_override("font_color", Color.WHITE)
			fb.pressed.connect(_play.bind(idx, 0))
			btns.add_child(fb)
			return p
		play.pressed.connect(_play.bind(idx, 0))
		btns.add_child(play)
		row.add_child(btns)
	else:
		var lock = _lbl("LOCKED", 12, Color(0.4, 0.35, 0.3))
		lock.custom_minimum_size = Vector2(100, 60)
		lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(lock)
	return p

func _play(idx: int, diff: int) -> void:
	if not _main:
		return
	if not _main._is_level_unlocked(idx):
		return
	_main.selected_difficulty = diff
	if _main.has_method("_hide_menu_v2"):
		_main._hide_menu_v2()
	if _main.has_method("_do_level_start"):
		_main._do_level_start(idx)

# ==================== SURVIVORS ====================
func _build_survivors_view() -> void:
	_clear()
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_area.add_child(scroll)
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)
	vbox.add_child(_lbl("SURVIVORS", 24, Color(1.0, 0.92, 0.45)))
	if not _main:
		return
	var grid = GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(grid)
	for i in range(_main.character_names.size()):
		var name = _main.character_names[i]
		var title = _main.character_titles[i] if i < _main.character_titles.size() else ""
		var p = PanelContainer.new()
		p.custom_minimum_size = Vector2(170, 210)
		var s = StyleBoxFlat.new()
		s.bg_color = Color(0.07, 0.05, 0.14, 0.70)
		s.border_color = Color(0.45, 0.35, 0.20, 0.5)
		s.set_border_width_all(2)
		s.set_corner_radius_all(8)
		s.content_margin_left = 6
		s.content_margin_right = 6
		s.content_margin_top = 6
		s.content_margin_bottom = 6
		p.add_theme_stylebox_override("panel", s)
		var vb = VBoxContainer.new()
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		p.add_child(vb)
		# Portrait
		var port = TextureRect.new()
		port.custom_minimum_size = Vector2(140, 140)
		port.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		port.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		if _main._portrait_textures.has(name):
			port.texture = _main._portrait_textures[name]
		vb.add_child(port)
		var nl = _lbl(name.to_upper(), 12, Color(1.0, 0.92, 0.45))
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(nl)
		var tl = _lbl(title, 9, Color(0.55, 0.48, 0.42))
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(tl)
		grid.add_child(p)

# ==================== EMPORIUM ====================
func _build_emporium_view() -> void:
	_clear()
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_area.add_child(scroll)
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)
	vbox.add_child(_lbl("THE EMPORIUM", 24, Color(1.0, 0.92, 0.45)))
	if not _main:
		return
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(grid)
	for cat in _main.emporium_categories:
		var p = PanelContainer.new()
		p.custom_minimum_size = Vector2(0, 75)
		var s = StyleBoxFlat.new()
		s.bg_color = Color(0.08, 0.06, 0.14, 0.70)
		s.border_color = Color(0.55, 0.42, 0.18, 0.4)
		s.set_border_width_all(1)
		s.set_corner_radius_all(6)
		s.content_margin_left = 10
		s.content_margin_right = 10
		s.content_margin_top = 6
		s.content_margin_bottom = 6
		p.add_theme_stylebox_override("panel", s)
		var vb = VBoxContainer.new()
		p.add_child(vb)
		vb.add_child(_lbl(cat.get("name", ""), 14, Color(1.0, 0.85, 0.3)))
		var d = _lbl(cat.get("desc", ""), 10, Color(0.55, 0.50, 0.45))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(d)
		if cat.get("badge", "") != "":
			vb.add_child(_lbl(cat["badge"], 10, Color(0.3, 0.9, 0.3)))
		grid.add_child(p)

# ==================== CODEX ====================
func _build_codex_view() -> void:
	_clear()
	var c = CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_area.add_child(c)
	var vb = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_child(vb)
	vb.add_child(_lbl("CODEX", 28, Color(1.0, 0.92, 0.45)))
	vb.add_child(_lbl("Achievements, Chronicles, Gear & Lore", 14, Color(0.65, 0.58, 0.50)))
	vb.add_child(_lbl("Coming soon to the Tome...", 12, Color(0.50, 0.45, 0.40)))

# ==================== SETTINGS ====================
func _build_settings_view() -> void:
	_clear()
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 200)
	margin.add_theme_constant_override("margin_right", 200)
	margin.add_theme_constant_override("margin_top", 20)
	content_area.add_child(margin)
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	margin.add_child(vb)
	vb.add_child(_lbl("SETTINGS", 24, Color(1.0, 0.92, 0.45)))
	var settings = [
		["Music Volume", "music"],
		["SFX Volume", "sfx"],
		["Voice Volume", "voice"],
		["Quality", "quality"],
		["Text Size", "text"],
		["Colorblind Mode", "colorblind"],
		["Game Speed", "speed"],
	]
	for s in settings:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		var name_lbl = _lbl(s[0], 15, Color(0.85, 0.78, 0.65))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)
		var btn = Button.new()
		btn.text = "Toggle"
		btn.custom_minimum_size = Vector2(100, 30)
		var bs = StyleBoxFlat.new()
		bs.bg_color = Color(0.18, 0.14, 0.28, 0.8)
		bs.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", bs)
		var bh = bs.duplicate()
		bh.bg_color = Color(0.25, 0.20, 0.38, 0.9)
		btn.add_theme_stylebox_override("hover", bh)
		btn.add_theme_font_size_override("font_size", 12)
		btn.add_theme_color_override("font_color", Color(0.8, 0.75, 0.65))
		row.add_child(btn)
		vb.add_child(row)

# ==================== UTILITY ====================
func _lbl(text: String, size: int, color: Color) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l

func _fade_in() -> void:
	fade_rect.color = Color(0, 0, 0, 1)
	var tw = create_tween()
	tw.tween_property(fade_rect, "color:a", 0.0, 0.3)
