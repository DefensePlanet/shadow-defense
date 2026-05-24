extends Control
## MainMenuV2 — Full interactive menu with art backgrounds and real buttons.
## Connects to main.gd game logic for level starts, navigation, etc.

var _backgrounds: Dictionary = {}
var _ui_tex: Dictionary = {}
var _main: Node = null  # Reference to main.gd node
var current_view: String = "chapters"

@onready var background: TextureRect = $BackgroundLayer/Background
@onready var overlay: ColorRect = $BackgroundLayer/DarkOverlay
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
	_setup_top_bar()
	_setup_nav_bar()
	_build_chapters_view()
	_fade_in()

func _load_textures() -> void:
	var bgs = {
		"chapters": "res://assets/ui_frames/scroll_banner.png",
		"survivors": "res://assets/menu_art/survivors_bg_books.png",
		"emporium": "res://assets/menu_art/emporium_bg_merchant.png",
		"codex": "res://assets/menu_art/chronicles_bg.png",
		"settings": "res://assets/menu_art/settings_bg.png",
	}
	for k in bgs:
		if ResourceLoader.exists(bgs[k]):
			_backgrounds[k] = load(bgs[k])
	var ui = {
		"game_logo": "res://assets/ui_elements/play_button.png",
		"header_bar": "res://assets/ui_elements/header_bar.png",
		"go_button": "res://assets/ui_elements/go_button.png",
		"level_card": "res://assets/ui_elements/level_card_bg.png",
		"nav_spine": "res://assets/ui_frames/nav_book_spine.png",
		"menu_button": "res://assets/ui_elements/menu_button.png",
		"survivor_frame": "res://assets/ui_elements/survivor_card_frame.png",
		"back_button": "res://assets/ui_elements/back_button.png",
		"buy_button": "res://assets/ui_elements/buy_button.png",
		"settings_gear": "res://assets/ui_elements/settings_gear.png",
		"tab_chapters": "res://assets/ui_elements/tab_chapters.png",
		"tab_survivors": "res://assets/ui_elements/tab_survivors.png",
		"tab_emporium": "res://assets/ui_elements/tab_emporium.png",
		"tab_chronicles": "res://assets/ui_elements/tab_chronicles.png",
	}
	for k in ui:
		if ResourceLoader.exists(ui[k]):
			_ui_tex[k] = load(ui[k])

func _setup_background(view: String) -> void:
	if _backgrounds.has(view):
		background.texture = _backgrounds[view]
	elif _backgrounds.has("chapters"):
		background.texture = _backgrounds["chapters"]
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

func _setup_logo() -> void:
	if _ui_tex.has("game_logo"):
		game_logo.texture = _ui_tex["game_logo"]
		game_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	game_logo.modulate.a = 0.0
	game_logo.scale = Vector2(0.9, 0.9)
	game_logo.pivot_offset = game_logo.size / 2.0
	var tw = create_tween().set_parallel(true)
	tw.tween_property(game_logo, "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_property(game_logo, "scale", Vector2(1.0, 1.0), 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _setup_top_bar() -> void:
	if _ui_tex.has("header_bar"):
		top_bar.texture = _ui_tex["header_bar"]
		top_bar.stretch_mode = TextureRect.STRETCH_SCALE
	# Add currency labels on top
	var gold_lbl = Label.new()
	gold_lbl.text = "GOLD: %d" % (_main.gold if _main else 0)
	gold_lbl.add_theme_font_size_override("font_size", 14)
	gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	gold_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	gold_lbl.add_theme_constant_override("shadow_offset_x", 1)
	gold_lbl.add_theme_constant_override("shadow_offset_y", 1)
	gold_lbl.position = Vector2(20, 10)
	top_bar.add_child(gold_lbl)

func _setup_nav_bar() -> void:
	if _ui_tex.has("nav_spine"):
		nav_bar.texture = _ui_tex["nav_spine"]
		nav_bar.stretch_mode = TextureRect.STRETCH_SCALE
	var tabs = ["chapters", "survivors", "emporium", "codex", "settings"]
	var labels = ["CHAPTERS", "SURVIVORS", "EMPORIUM", "CODEX", "SETTINGS"]
	var icon_keys = ["tab_chapters", "tab_survivors", "tab_emporium", "tab_chronicles", "settings_gear"]
	for i in range(tabs.size()):
		var btn_container = VBoxContainer.new()
		btn_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
		var btn = TextureButton.new()
		btn.custom_minimum_size = Vector2(80, 60)
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.ignore_texture_size = true
		if _ui_tex.has(icon_keys[i]):
			btn.texture_normal = _ui_tex[icon_keys[i]]
		btn.pressed.connect(_on_tab_pressed.bind(tabs[i]))
		btn.mouse_entered.connect(func(): _hover_btn(btn))
		btn.mouse_exited.connect(func(): _unhover_btn(btn))
		btn_container.add_child(btn)
		var lbl = Label.new()
		lbl.text = labels[i]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.85, 0.72, 0.40))
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		lbl.add_theme_constant_override("shadow_offset_x", 1)
		lbl.add_theme_constant_override("shadow_offset_y", 1)
		btn_container.add_child(lbl)
		nav_buttons_container.add_child(btn_container)

func _hover_btn(btn: TextureButton) -> void:
	var tw = btn.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(btn, "scale", Vector2(1.15, 1.15), 0.1)
	btn.pivot_offset = btn.size / 2.0

func _unhover_btn(btn: TextureButton) -> void:
	var tw = btn.create_tween().set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.08)

func _on_tab_pressed(tab: String) -> void:
	if current_view == tab:
		return
	current_view = tab
	# Crossfade background
	var tw = create_tween()
	tw.tween_property(background, "modulate:a", 0.0, 0.15)
	await tw.finished
	_setup_background(tab)
	tw = create_tween()
	tw.tween_property(background, "modulate:a", 1.0, 0.15)
	# Rebuild content
	_clear_content()
	match tab:
		"chapters": _build_chapters_view()
		"survivors": _build_survivors_view()
		"emporium": _build_emporium_view()
		"codex": _build_codex_view()
		"settings": _build_settings_view()

func _clear_content() -> void:
	for child in content_area.get_children():
		child.queue_free()

# =====================================================
# CHAPTERS VIEW — Level select with PLAY buttons
# =====================================================
func _build_chapters_view() -> void:
	_clear_content()
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_area.add_child(scroll)
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox)
	# Title
	var title = Label.new()
	title.text = "THE TOME OF SHADOWS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(title)
	if not _main:
		return
	# Level cards
	for i in range(_main.levels.size()):
		var level = _main.levels[i]
		var card = _create_level_card(i, level)
		vbox.add_child(card)
		# Staggered entrance
		card.modulate.a = 0.0
		card.position.x += 300
		var tw = create_tween()
		tw.tween_property(card, "modulate:a", 1.0, 0.2).set_delay(i * 0.03)
		tw.parallel().tween_property(card, "position:x", 0, 0.25).set_delay(i * 0.03).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _create_level_card(index: int, level: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.05, 0.15, 0.65)
	style.border_color = Color(0.50, 0.38, 0.22, 0.7)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	panel.add_child(hbox)
	# Level number
	var num_lbl = Label.new()
	num_lbl.text = str(index + 1)
	num_lbl.custom_minimum_size = Vector2(40, 60)
	num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num_lbl.add_theme_font_size_override("font_size", 24)
	num_lbl.add_theme_color_override("font_color", Color(0.85, 0.72, 0.40))
	num_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	num_lbl.add_theme_constant_override("shadow_offset_x", 1)
	num_lbl.add_theme_constant_override("shadow_offset_y", 1)
	hbox.add_child(num_lbl)
	# Level info
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_lbl = Label.new()
	name_lbl.text = level.get("name", "Level %d" % (index + 1))
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	name_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	name_lbl.add_theme_constant_override("shadow_offset_x", 1)
	name_lbl.add_theme_constant_override("shadow_offset_y", 1)
	info_vbox.add_child(name_lbl)
	var sub_lbl = Label.new()
	sub_lbl.text = level.get("subtitle", "")
	sub_lbl.add_theme_font_size_override("font_size", 12)
	sub_lbl.add_theme_color_override("font_color", Color(0.7, 0.6, 0.5))
	info_vbox.add_child(sub_lbl)
	var stats_lbl = Label.new()
	stats_lbl.text = "Waves: %d | Gold: %d | Lives: %d" % [level.get("waves", 20), level.get("gold", 100), level.get("lives", 20)]
	stats_lbl.add_theme_font_size_override("font_size", 11)
	stats_lbl.add_theme_color_override("font_color", Color(0.55, 0.50, 0.45))
	info_vbox.add_child(stats_lbl)
	hbox.add_child(info_vbox)
	# PLAY button
	var play_btn = Button.new()
	play_btn.text = "PLAY"
	play_btn.custom_minimum_size = Vector2(100, 50)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.15, 0.55, 0.15, 0.9)
	btn_style.corner_radius_top_left = 8
	btn_style.corner_radius_top_right = 8
	btn_style.corner_radius_bottom_left = 8
	btn_style.corner_radius_bottom_right = 8
	play_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0.20, 0.70, 0.20, 0.95)
	play_btn.add_theme_stylebox_override("hover", btn_hover)
	var btn_press = btn_style.duplicate()
	btn_press.bg_color = Color(0.10, 0.40, 0.10, 0.95)
	play_btn.add_theme_stylebox_override("pressed", btn_press)
	play_btn.add_theme_font_size_override("font_size", 16)
	play_btn.add_theme_color_override("font_color", Color.WHITE)
	play_btn.pressed.connect(_on_level_play.bind(index))
	hbox.add_child(play_btn)
	return panel

func _on_level_play(index: int) -> void:
	if _main and _main.has_method("_do_level_start"):
		# Hide v2 menu
		_hide_menu_v2()
		_main._do_level_start(index)

func _hide_menu_v2() -> void:
	get_parent().visible = false

# =====================================================
# SURVIVORS VIEW
# =====================================================
func _build_survivors_view() -> void:
	_clear_content()
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_area.add_child(scroll)
	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	if not _main:
		return
	for i in range(_main.survivor_types.size()):
		var tt = _main.survivor_types[i]
		var card = _create_survivor_card(i, tt)
		grid.add_child(card)
		card.modulate.a = 0.0
		var tw = create_tween()
		tw.tween_property(card, "modulate:a", 1.0, 0.2).set_delay(i * 0.05)

func _create_survivor_card(index: int, tower_type) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 250)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.07, 0.18, 0.60)
	style.border_color = Color(0.50, 0.38, 0.22, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)
	# Portrait
	var portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(180, 160)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var char_name = _main.character_names[index] if _main and index < _main.character_names.size() else "?"
	var speaker = char_name.to_lower().replace(" ", "_").replace("'s", "s").replace("the_", "")
	if _main and _main._portrait_textures.has(char_name):
		portrait.texture = _main._portrait_textures[char_name]
	vbox.add_child(portrait)
	# Name
	var name_lbl = Label.new()
	name_lbl.text = char_name.to_upper()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
	name_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	name_lbl.add_theme_constant_override("shadow_offset_x", 1)
	name_lbl.add_theme_constant_override("shadow_offset_y", 1)
	vbox.add_child(name_lbl)
	# Title
	var title_lbl = Label.new()
	title_lbl.text = _main.character_titles[index] if _main and index < _main.character_titles.size() else ""
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 10)
	title_lbl.add_theme_color_override("font_color", Color(0.65, 0.55, 0.45))
	vbox.add_child(title_lbl)
	return panel

# =====================================================
# EMPORIUM VIEW
# =====================================================
func _build_emporium_view() -> void:
	_clear_content()
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_area.add_child(scroll)
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	if not _main:
		return
	for i in range(_main.emporium_categories.size()):
		var cat = _main.emporium_categories[i]
		var card = _create_shop_card(cat)
		grid.add_child(card)
		card.modulate.a = 0.0
		var tw = create_tween()
		tw.tween_property(card, "modulate:a", 1.0, 0.15).set_delay(i * 0.04)

func _create_shop_card(cat: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 100)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.07, 0.16, 0.65)
	style.border_color = Color(0.65, 0.50, 0.20, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)
	var name_lbl = Label.new()
	name_lbl.text = cat.get("name", "???")
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	name_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	name_lbl.add_theme_constant_override("shadow_offset_x", 1)
	name_lbl.add_theme_constant_override("shadow_offset_y", 1)
	vbox.add_child(name_lbl)
	var desc_lbl = Label.new()
	desc_lbl.text = cat.get("desc", "")
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.58, 0.50))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_lbl)
	if cat.get("badge", "") != "":
		var badge = Label.new()
		badge.text = cat["badge"]
		badge.add_theme_font_size_override("font_size", 10)
		badge.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3))
		vbox.add_child(badge)
	return panel

# =====================================================
# CODEX VIEW
# =====================================================
func _build_codex_view() -> void:
	_clear_content()
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_area.add_child(center)
	var lbl = Label.new()
	lbl.text = "CODEX\n\nAchievements, Chronicles, and Gear\ncoming to this view soon."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.7, 0.55))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	center.add_child(lbl)

# =====================================================
# SETTINGS VIEW
# =====================================================
func _build_settings_view() -> void:
	_clear_content()
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_area.add_child(center)
	var lbl = Label.new()
	lbl.text = "SETTINGS\n\nAudio, Graphics, Controls\ncoming to this view soon."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.7, 0.55))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	center.add_child(lbl)

# =====================================================
# TRANSITIONS
# =====================================================
func _fade_in() -> void:
	fade_rect.color = Color(0, 0, 0, 1)
	var tw = create_tween()
	tw.tween_property(fade_rect, "color:a", 0.0, 0.4).set_ease(Tween.EASE_OUT)
