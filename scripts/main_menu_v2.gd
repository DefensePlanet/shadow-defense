extends Control
## MainMenuV2 — Full menu with currency bar, difficulty select, all views.

var _backgrounds: Dictionary = {}
var _ui_tex: Dictionary = {}
var _main: Node = null
var current_view: String = "chapters"

@onready var background: TextureRect = $BackgroundLayer/Background
@onready var content_area: Control = $UILayer/UI/ContentArea
@onready var nav_buttons_container: HBoxContainer = $UILayer/UI/NavBar/NavButtons
@onready var game_logo: TextureRect = $UILayer/UI/GameLogo
@onready var top_bar: TextureRect = $UILayer/UI/TopBar
@onready var nav_bar: TextureRect = $UILayer/UI/NavBar
@onready var fade_rect: ColorRect = $TransitionLayer/FadeRect

func _ready() -> void:
	_main = get_tree().get_first_node_in_group("main")
	_load_textures()
	_setup_background("chapters")
	_setup_logo()
	_setup_currency_bar()
	_setup_nav_bar()
	_build_chapters_view()
	_fade_in()

func _load_textures() -> void:
	var bgs = {"chapters": "res://assets/ui_frames/scroll_banner.png", "survivors": "res://assets/menu_art/survivors_bg_books.png", "emporium": "res://assets/menu_art/emporium_bg_merchant.png", "codex": "res://assets/menu_art/chronicles_bg.png", "settings": "res://assets/menu_art/settings_bg.png"}
	for k in bgs:
		if ResourceLoader.exists(bgs[k]):
			_backgrounds[k] = load(bgs[k])
	var ui = {"game_logo": "res://assets/ui_elements/play_button.png", "header_bar": "res://assets/ui_elements/header_bar.png", "nav_spine": "res://assets/ui_frames/nav_book_spine.png", "tab_chapters": "res://assets/ui_elements/tab_chapters.png", "tab_survivors": "res://assets/ui_elements/tab_survivors.png", "tab_emporium": "res://assets/ui_elements/tab_emporium.png", "tab_chronicles": "res://assets/ui_elements/tab_chronicles.png", "settings_gear": "res://assets/ui_elements/settings_gear.png"}
	for k in ui:
		if ResourceLoader.exists(ui[k]):
			_ui_tex[k] = load(ui[k])

func _setup_background(view: String) -> void:
	if _backgrounds.has(view):
		background.texture = _backgrounds[view]
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

func _setup_logo() -> void:
	if _ui_tex.has("game_logo"):
		game_logo.texture = _ui_tex["game_logo"]
		game_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func _setup_currency_bar() -> void:
	if not _main:
		return
	# Build currency display on the top bar
	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 20)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	top_bar.add_child(hbox)
	var currencies = [
		["GOLD", _main.gold if "gold" in _main else 0, Color(1.0, 0.85, 0.2)],
		["QUILLS", _main.player_quills if "player_quills" in _main else 0, Color(0.7, 0.5, 0.9)],
		["SHARDS", _main.player_gear_shards if "player_gear_shards" in _main else 0, Color(0.3, 0.7, 0.9)],
		["STARS", _main.player_storybook_stars if "player_storybook_stars" in _main else 0, Color(1.0, 0.9, 0.3)],
		["INK", _main.player_ink if "player_ink" in _main else 0, Color(0.5, 0.3, 0.8)],
	]
	for c in currencies:
		var lbl = Label.new()
		lbl.text = "%d %s" % [c[1], c[0]]
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", c[2])
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		lbl.add_theme_constant_override("shadow_offset_x", 1)
		lbl.add_theme_constant_override("shadow_offset_y", 1)
		hbox.add_child(lbl)

func _setup_nav_bar() -> void:
	if _ui_tex.has("nav_spine"):
		nav_bar.texture = _ui_tex["nav_spine"]
		nav_bar.stretch_mode = TextureRect.STRETCH_SCALE
	var tabs = ["chapters", "survivors", "emporium", "codex", "settings"]
	var labels = ["CHAPTERS", "SURVIVORS", "EMPORIUM", "CODEX", "SETTINGS"]
	var icons = ["tab_chapters", "tab_survivors", "tab_emporium", "tab_chronicles", "settings_gear"]
	for i in range(tabs.size()):
		var cont = VBoxContainer.new()
		cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cont.alignment = BoxContainer.ALIGNMENT_CENTER
		var btn = TextureButton.new()
		btn.custom_minimum_size = Vector2(60, 45)
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.ignore_texture_size = true
		if _ui_tex.has(icons[i]):
			btn.texture_normal = _ui_tex[icons[i]]
		btn.pressed.connect(_on_tab.bind(tabs[i]))
		cont.add_child(btn)
		var lbl = Label.new()
		lbl.text = labels[i]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", Color(0.85, 0.72, 0.40))
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		lbl.add_theme_constant_override("shadow_offset_x", 1)
		lbl.add_theme_constant_override("shadow_offset_y", 1)
		cont.add_child(lbl)
		nav_buttons_container.add_child(cont)

func _on_tab(tab: String) -> void:
	if current_view == tab:
		return
	current_view = tab
	var tw = create_tween()
	tw.tween_property(background, "modulate:a", 0.0, 0.1)
	await tw.finished
	_setup_background(tab)
	tw = create_tween()
	tw.tween_property(background, "modulate:a", 1.0, 0.1)
	_clear_content()
	match tab:
		"chapters": _build_chapters_view()
		"survivors": _build_survivors_view()
		"emporium": _build_emporium_view()
		"codex": _build_codex_view()
		"settings": _build_settings_view()

func _clear_content() -> void:
	for c in content_area.get_children():
		c.queue_free()

# ===================== CHAPTERS =====================
func _build_chapters_view() -> void:
	_clear_content()
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_area.add_child(scroll)
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)
	# Title
	var t = _make_label("THE TOME OF SHADOWS", 22, Color(1.0, 0.92, 0.45))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(t)
	if not _main:
		return
	for i in range(_main.levels.size()):
		var lvl = _main.levels[i]
		var is_unlocked = _main._is_level_unlocked(i) if _main.has_method("_is_level_unlocked") else true
		var is_complete = i in _main.completed_levels if "completed_levels" in _main else false
		var card = _make_level_card(i, lvl, is_unlocked, is_complete)
		vbox.add_child(card)

func _make_level_card(idx: int, lvl: Dictionary, unlocked: bool, complete: bool) -> PanelContainer:
	var p = PanelContainer.new()
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.05, 0.14, 0.70) if unlocked else Color(0.06, 0.04, 0.10, 0.50)
	s.border_color = Color(0.45, 0.35, 0.20, 0.6) if unlocked else Color(0.25, 0.20, 0.18, 0.3)
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	if complete:
		s.border_color = Color(0.3, 0.7, 0.3, 0.7)
	p.add_theme_stylebox_override("panel", s)
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	p.add_child(hbox)
	# Level number
	var num = _make_label(str(idx + 1), 18, Color(0.85, 0.72, 0.40) if unlocked else Color(0.4, 0.35, 0.3))
	num.custom_minimum_size = Vector2(30, 0)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(num)
	# Thumbnail from map_thumbnails if available
	var thumb = TextureRect.new()
	thumb.custom_minimum_size = Vector2(80, 55)
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if _main and _main._map_thumb_textures.has(idx):
		thumb.texture = _main._map_thumb_textures[idx]
	hbox.add_child(thumb)
	# Info
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(_make_label(lvl.get("name", "Level"), 14, Color(1.0, 0.95, 0.85) if unlocked else Color(0.5, 0.45, 0.4)))
	info.add_child(_make_label(lvl.get("subtitle", ""), 10, Color(0.6, 0.5, 0.45)))
	info.add_child(_make_label("Waves: %d | Gold: %d | Lives: %d" % [lvl.get("waves", 20), lvl.get("gold", 100), lvl.get("lives", 20)], 9, Color(0.5, 0.45, 0.4)))
	# Difficulty row
	var diff_row = HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 6)
	for d in ["Easy", "Med", "Hard"]:
		var db = Button.new()
		db.text = d.to_upper()
		db.custom_minimum_size = Vector2(55, 22)
		var ds = StyleBoxFlat.new()
		match d:
			"Easy": ds.bg_color = Color(0.15, 0.45, 0.15, 0.8)
			"Med": ds.bg_color = Color(0.45, 0.35, 0.10, 0.8)
			"Hard": ds.bg_color = Color(0.50, 0.12, 0.10, 0.8)
		ds.set_corner_radius_all(4)
		db.add_theme_stylebox_override("normal", ds)
		var dh = ds.duplicate()
		dh.bg_color = dh.bg_color.lightened(0.2)
		db.add_theme_stylebox_override("hover", dh)
		db.add_theme_font_size_override("font_size", 9)
		db.add_theme_color_override("font_color", Color.WHITE)
		var diff_idx = ["Easy", "Med", "Hard"].find(d)
		db.pressed.connect(_on_play_level.bind(idx, diff_idx))
		if not unlocked:
			db.disabled = true
		diff_row.add_child(db)
	info.add_child(diff_row)
	hbox.add_child(info)
	# Play button (big green)
	if unlocked:
		var play = Button.new()
		play.text = "PLAY"
		play.custom_minimum_size = Vector2(70, 55)
		var ps = StyleBoxFlat.new()
		ps.bg_color = Color(0.12, 0.50, 0.12, 0.9)
		ps.set_corner_radius_all(8)
		play.add_theme_stylebox_override("normal", ps)
		var ph = ps.duplicate()
		ph.bg_color = Color(0.18, 0.65, 0.18, 0.95)
		play.add_theme_stylebox_override("hover", ph)
		var pp = ps.duplicate()
		pp.bg_color = Color(0.08, 0.35, 0.08, 0.95)
		play.add_theme_stylebox_override("pressed", pp)
		play.add_theme_font_size_override("font_size", 14)
		play.add_theme_color_override("font_color", Color.WHITE)
		play.pressed.connect(_on_play_level.bind(idx, 0))
		hbox.add_child(play)
	else:
		var lock = _make_label("LOCKED", 11, Color(0.4, 0.35, 0.3))
		lock.custom_minimum_size = Vector2(70, 55)
		lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(lock)
	return p

func _on_play_level(idx: int, difficulty: int) -> void:
	if _main:
		_main.selected_difficulty = difficulty
		get_parent().visible = false
		if _main.has_method("_do_level_start"):
			_main._do_level_start(idx)

# ===================== SURVIVORS =====================
func _build_survivors_view() -> void:
	_clear_content()
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_area.add_child(scroll)
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)
	var t = _make_label("SURVIVORS", 22, Color(1.0, 0.92, 0.45))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(t)
	var grid = GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(grid)
	if not _main:
		return
	for i in range(_main.survivor_types.size()):
		var card = _make_survivor_card(i)
		grid.add_child(card)

func _make_survivor_card(idx: int) -> PanelContainer:
	var p = PanelContainer.new()
	p.custom_minimum_size = Vector2(160, 200)
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.05, 0.14, 0.65)
	s.border_color = Color(0.50, 0.38, 0.22, 0.5)
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	p.add_theme_stylebox_override("panel", s)
	var vb = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(vb)
	var portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(140, 130)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var name = _main.character_names[idx] if _main and idx < _main.character_names.size() else "?"
	if _main and _main._portrait_textures.has(name):
		portrait.texture = _main._portrait_textures[name]
	vb.add_child(portrait)
	vb.add_child(_make_label(name.to_upper(), 12, Color(1.0, 0.92, 0.45)))
	var title = _main.character_titles[idx] if _main and idx < _main.character_titles.size() else ""
	var tl = _make_label(title, 9, Color(0.6, 0.5, 0.45))
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(tl)
	return p

# ===================== EMPORIUM =====================
func _build_emporium_view() -> void:
	_clear_content()
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_area.add_child(scroll)
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)
	var t = _make_label("THE EMPORIUM", 22, Color(1.0, 0.92, 0.45))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(t)
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(grid)
	if not _main:
		return
	for i in range(_main.emporium_categories.size()):
		var cat = _main.emporium_categories[i]
		var card = _make_shop_card(cat)
		grid.add_child(card)

func _make_shop_card(cat: Dictionary) -> PanelContainer:
	var p = PanelContainer.new()
	p.custom_minimum_size = Vector2(0, 80)
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.10, 0.07, 0.16, 0.65)
	s.border_color = Color(0.65, 0.50, 0.20, 0.4)
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	p.add_theme_stylebox_override("panel", s)
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	p.add_child(vb)
	vb.add_child(_make_label(cat.get("name", ""), 14, Color(1.0, 0.85, 0.3)))
	var d = _make_label(cat.get("desc", ""), 10, Color(0.6, 0.55, 0.48))
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(d)
	if cat.get("badge", "") != "":
		vb.add_child(_make_label(cat["badge"], 9, Color(0.2, 0.9, 0.3)))
	return p

# ===================== CODEX =====================
func _build_codex_view() -> void:
	_clear_content()
	var c = CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_area.add_child(c)
	var l = _make_label("CODEX\n\nAchievements, Chronicles, and Gear\nComing soon.", 18, Color(0.8, 0.7, 0.55))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(l)

# ===================== SETTINGS =====================
func _build_settings_view() -> void:
	_clear_content()
	var c = CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_area.add_child(c)
	var vb = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 12)
	c.add_child(vb)
	vb.add_child(_make_label("SETTINGS", 22, Color(1.0, 0.92, 0.45)))
	# Actual setting buttons
	for setting in ["Music Volume", "SFX Volume", "Voice Volume", "Quality", "Text Size", "Colorblind Mode"]:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		row.add_child(_make_label(setting, 14, Color(0.85, 0.78, 0.65)))
		var btn = Button.new()
		btn.text = "Toggle"
		btn.custom_minimum_size = Vector2(80, 30)
		var bs = StyleBoxFlat.new()
		bs.bg_color = Color(0.15, 0.12, 0.25, 0.7)
		bs.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", bs)
		btn.add_theme_font_size_override("font_size", 11)
		btn.add_theme_color_override("font_color", Color.WHITE)
		row.add_child(btn)
		vb.add_child(row)

# ===================== UTILITY =====================
func _make_label(text: String, size: int, color: Color) -> Label:
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
