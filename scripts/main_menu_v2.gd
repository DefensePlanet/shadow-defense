extends Control
## MainMenuV2 — Scene-based menu using TextureRect/TextureButton/NinePatchRect
## NO _draw() calls. Art-first architecture. Professional mobile game standard.
## Replaces the old 35K-line procedural menu rendering.

# === TEXTURES (loaded on ready) ===
var _backgrounds: Dictionary = {}
var _ui_textures: Dictionary = {}
var _tab_icons: Dictionary = {}

# === STATE ===
var current_view: String = "chapters"
var _nav_buttons: Array = []

# === NODE REFERENCES ===
@onready var background: TextureRect = $BackgroundLayer/Background
@onready var dark_overlay: ColorRect = $BackgroundLayer/DarkOverlay
@onready var top_bar: TextureRect = $UILayer/UI/TopBar
@onready var game_logo: TextureRect = $UILayer/UI/GameLogo
@onready var nav_bar: TextureRect = $UILayer/UI/NavBar
@onready var nav_buttons_container: HBoxContainer = $UILayer/UI/NavBar/NavButtons
@onready var content_area: Control = $UILayer/UI/ContentArea
@onready var fade_rect: ColorRect = $TransitionLayer/FadeRect

func _ready() -> void:
	_load_all_textures()
	_setup_background("chapters")
	_setup_top_bar()
	_setup_logo()
	_setup_nav_bar()
	_fade_in()

# =====================================================
# TEXTURE LOADING — One-time on startup
# =====================================================
func _load_all_textures() -> void:
	# Backgrounds per view
	var bg_map = {
		"chapters": "res://assets/ui_frames/scroll_banner.png",
		"survivors": "res://assets/menu_art/survivors_bg_books.png",
		"emporium": "res://assets/menu_art/emporium_bg_merchant.png",
		"codex": "res://assets/menu_art/chronicles_bg.png",
		"settings": "res://assets/menu_art/settings_bg.png",
	}
	for key in bg_map:
		if ResourceLoader.exists(bg_map[key]):
			_backgrounds[key] = load(bg_map[key])

	# UI element textures
	var ui_map = {
		"game_logo": "res://assets/ui_elements/play_button.png",
		"header_bar": "res://assets/ui_elements/header_bar.png",
		"nav_bar": "res://assets/ui_elements/nav_bar_bg.png",
		"play_button": "res://assets/ui_elements/go_button.png",
		"menu_button": "res://assets/ui_elements/menu_button.png",
		"level_card": "res://assets/ui_elements/level_card_bg.png",
		"parchment_panel": "res://assets/ui_elements/parchment_panel.png",
		"survivor_frame": "res://assets/ui_elements/survivor_card_frame.png",
		"scroll_header": "res://assets/ui_frames/scroll_header_storybook.png",
		"wooden_panel": "res://assets/ui_frames/wooden_panel.png",
		"golden_frame": "res://assets/ui_frames/golden_frame.png",
		"book_spine_nav": "res://assets/ui_frames/nav_book_spine.png",
	}
	for key in ui_map:
		if ResourceLoader.exists(ui_map[key]):
			_ui_textures[key] = load(ui_map[key])

	# Tab icons
	var tab_map = {
		"chapters": "res://assets/ui_elements/tab_chapters.png",
		"survivors": "res://assets/ui_elements/tab_survivors.png",
		"emporium": "res://assets/ui_elements/tab_emporium.png",
		"codex": "res://assets/ui_elements/tab_chronicles.png",
		"settings": "res://assets/ui_elements/settings_gear.png",
	}
	for key in tab_map:
		if ResourceLoader.exists(tab_map[key]):
			_tab_icons[key] = load(tab_map[key])

# =====================================================
# BACKGROUND — Full-bleed art, per-view
# =====================================================
func _setup_background(view: String) -> void:
	if _backgrounds.has(view):
		background.texture = _backgrounds[view]
	elif _backgrounds.has("chapters"):
		background.texture = _backgrounds["chapters"]
	# Stretch to cover entire screen — KEEP_ASPECT_COVERED
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

func _switch_background(new_view: String) -> void:
	# Crossfade to new background
	var tween = create_tween()
	tween.tween_property(background, "modulate:a", 0.0, 0.2)
	await tween.finished
	_setup_background(new_view)
	var tween2 = create_tween()
	tween2.tween_property(background, "modulate:a", 1.0, 0.2)

# =====================================================
# TOP BAR — Currency display using texture
# =====================================================
func _setup_top_bar() -> void:
	if _ui_textures.has("header_bar"):
		top_bar.texture = _ui_textures["header_bar"]
		top_bar.stretch_mode = TextureRect.STRETCH_SCALE
	else:
		# Fallback: just a dark strip
		top_bar.visible = false

# =====================================================
# LOGO — Illustrated game title
# =====================================================
func _setup_logo() -> void:
	if _ui_textures.has("game_logo"):
		game_logo.texture = _ui_textures["game_logo"]
		game_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Entrance animation — fade + scale in
	game_logo.modulate.a = 0.0
	game_logo.scale = Vector2(0.9, 0.9)
	game_logo.pivot_offset = game_logo.size / 2.0
	var tween = create_tween().set_parallel(true)
	tween.tween_property(game_logo, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_property(game_logo, "scale", Vector2(1.0, 1.0), 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

# =====================================================
# NAV BAR — Book spine with tab buttons
# =====================================================
func _setup_nav_bar() -> void:
	if _ui_textures.has("book_spine_nav"):
		nav_bar.texture = _ui_textures["book_spine_nav"]
		nav_bar.stretch_mode = TextureRect.STRETCH_SCALE
	elif _ui_textures.has("nav_bar"):
		nav_bar.texture = _ui_textures["nav_bar"]
		nav_bar.stretch_mode = TextureRect.STRETCH_SCALE

	# Create 5 tab buttons
	var tabs = ["chapters", "survivors", "emporium", "codex", "settings"]
	var tab_labels = ["CHAPTERS", "SURVIVORS", "EMPORIUM", "CODEX", "SETTINGS"]

	for i in range(tabs.size()):
		var btn = TextureButton.new()
		btn.name = tabs[i] + "_tab"
		btn.custom_minimum_size = Vector2(1280.0 / 5.0, 100)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED

		# Set tab icon as the button texture
		if _tab_icons.has(tabs[i]):
			btn.texture_normal = _tab_icons[tabs[i]]

		btn.pressed.connect(_on_tab_pressed.bind(tabs[i]))
		nav_buttons_container.add_child(btn)
		_nav_buttons.append(btn)

		# Label under the icon
		var lbl = Label.new()
		lbl.text = tab_labels[i]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.85, 0.72, 0.40))
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		lbl.add_theme_constant_override("shadow_offset_x", 1)
		lbl.add_theme_constant_override("shadow_offset_y", 1)
		lbl.anchors_preset = Control.PRESET_BOTTOM_WIDE
		btn.add_child(lbl)

func _on_tab_pressed(tab_name: String) -> void:
	if current_view == tab_name:
		return
	current_view = tab_name
	_switch_background(tab_name)
	_update_nav_highlight()
	# TODO: Switch content area to show the selected view

func _update_nav_highlight() -> void:
	var tabs = ["chapters", "survivors", "emporium", "codex", "settings"]
	for i in range(_nav_buttons.size()):
		if tabs[i] == current_view:
			_nav_buttons[i].modulate = Color(1.2, 1.1, 0.9)  # Bright = active
			# Scale pop
			var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			tween.tween_property(_nav_buttons[i], "scale", Vector2(1.1, 1.1), 0.15)
		else:
			_nav_buttons[i].modulate = Color(0.6, 0.55, 0.5)  # Dim = inactive
			_nav_buttons[i].scale = Vector2(1.0, 1.0)

# =====================================================
# TRANSITIONS
# =====================================================
func _fade_in() -> void:
	fade_rect.color = Color(0, 0, 0, 1)
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, 0.5).set_ease(Tween.EASE_OUT)

func _fade_out_and_do(callable: Callable) -> void:
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, 0.3)
	await tween.finished
	callable.call()
	_fade_in()
