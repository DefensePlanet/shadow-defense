extends Control
## MainMenuV2 — Full interactive menu. Art backgrounds, working buttons, detail panels.

var _backgrounds: Dictionary = {}
var _art: Dictionary = {}
var _black_key: Shader = null
var _main: Node = null
var current_view: String = "chapters"
var _song_label: Label = null
var _last_song: String = ""
var _scroll_positions: Dictionary = {}  # View name → scroll position
# Portrait key mapping — character_names[] index → portrait texture key
const PORTRAIT_KEYS: Array = ["robin_hood", "alice", "wicked_witch", "peter_pan", "phantom", "scrooge", "sherlock", "tarzan", "dracula", "merlin", "frankenstein", "shadow_author"]
# Map arc name prefixes to portrait keys for arc header icons
const ARC_PORTRAITS: Dictionary = {
	"Prologue": "robin_hood", "Robin Hood": "robin_hood", "Sherwood": "robin_hood",
	"Alice": "alice", "Wonderland": "alice",
	"Wicked Witch": "wicked_witch", "Oz": "wicked_witch",
	"Peter Pan": "peter_pan", "Neverland": "peter_pan",
	"Phantom": "phantom", "Opera": "phantom",
	"Scrooge": "scrooge", "Christmas": "scrooge",
	"Sherlock": "sherlock", "Baker": "sherlock",
	"Tarzan": "tarzan", "Jungle": "tarzan",
	"Dracula": "dracula", "Transylvania": "dracula",
	"Merlin": "merlin", "Camelot": "merlin",
	"Frankenstein": "frankenstein", "Monster": "frankenstein",
	"Shadow Author": "shadow_author", "Final": "shadow_author",
}

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
	_add_vignette()
	_fade_in()
	# Portraits verified loaded — all 12 keys match

func _add_vignette() -> void:
	var vig = ColorRect.new()
	vig.color = Color(0, 0, 0, 0)  # Transparent — shader handles the visual
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vig.z_index = 0  # Above background, below content
	if ResourceLoader.exists("res://shaders/vignette.gdshader"):
		var shader = load("res://shaders/vignette.gdshader")
		var mat = ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("intensity", 0.35)
		mat.set_shader_parameter("softness", 0.55)
		vig.material = mat
		# Insert above DarkOverlay but below TopBar
		add_child(vig)
		move_child(vig, 2)  # After Background and DarkOverlay

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

var _song_check_timer: float = 0.0

func _process(delta: float) -> void:
	for p in _particles:
		p["y"] -= p["speed"] * delta
		p["x"] += sin(p["offset"] + p["y"] * 0.01) * 0.3
		if p["y"] < -10:
			p["y"] = 730
			p["x"] = randf_range(0, 1280)
	# Check for song change every 2 seconds
	_song_check_timer += delta
	if _song_check_timer >= 2.0:
		_song_check_timer = 0.0
		_update_song_display()
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
		# Additional art assets
		"survivor_card_frame": "res://assets/ui_elements/survivor_card_frame.png",
		"difficulty_gems": "res://assets/ui_elements/difficulty_gems.png",
		"chapter_divider": "res://assets/ui_elements/chapter_divider.png",
		"section_header": "res://assets/ui_frames/section_header_banner.png",
		"golden_frame": "res://assets/ui_frames/golden_frame.png",
		"wooden_panel": "res://assets/ui_frames/wooden_panel.png",
		"nav_bar_bg": "res://assets/ui_frames/nav_bar_bg.png",
		"xp_bar": "res://assets/ui_elements/xp_bar.png",
		"gear_slots": "res://assets/ui_elements/gear_slots.png",
		"daily_deals": "res://assets/ui_elements/daily_deals_banner.png",
		"claim_button": "res://assets/ui_elements/claim_button.png",
		"coin_burst": "res://assets/ui_elements/coin_burst.png",
		"currency_exchange": "res://assets/ui_elements/currency_exchange.png",
		"achievement_badges": "res://assets/ui_elements/achievement_badges.png",
		"achievement_card": "res://assets/ui_elements/achievement_progress_card.png",
		"character_info_card": "res://assets/ui_elements/character_info_card.png",
		"go_button": "res://assets/ui_elements/go_button.png",
		"three_stars": "res://assets/ui_elements/three_stars.png",
		"empty_star": "res://assets/ui_elements/empty_star.png",
		"upgrade_arrow": "res://assets/ui_elements/upgrade_arrow.png",
		"side_panel_buttons": "res://assets/ui_elements/side_panel_buttons.png",
		"tooltip_frame": "res://assets/ui_elements/tooltip_frame.png",
		"wooden_sign": "res://assets/ui_elements/wooden_sign.png",
		"card_frame_epic": "res://assets/ui_frames/card_frame_epic.png",
		"wanted_poster": "res://assets/ui_frames/wanted_poster.png",
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
	music_row.add_theme_constant_override("separation", 6)
	music_row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	music_row.position = Vector2(-260, 6)
	music_row.size = Vector2(250, 26)
	top_bar.add_child(music_row)
	# Music icon
	var icon = _lbl("♫", 12, Color(0.65, 0.55, 0.80))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	music_row.add_child(icon)
	# Song title — stored for live updates
	var song_name = _get_song_name()
	_song_label = _lbl(song_name if song_name != "" else "Now Playing...", 10, Color(0.70, 0.60, 0.85))
	_song_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_song_label.clip_text = true
	_song_label.custom_minimum_size.x = 180
	_last_song = song_name
	music_row.add_child(_song_label)
	# Skip button with art styling
	var skip = _art_button(">>", Color(0.12, 0.10, 0.22), Vector2(36, 22))
	skip.add_theme_font_size_override("font_size", 10)
	if _main and _main.has_method("_on_skip_song_pressed"):
		skip.pressed.connect(func():
			if _main.has_method("_on_skip_song_pressed"):
				_main._on_skip_song_pressed()
			# Flash the song label briefly
			if _song_label:
				_song_label.text = "..."
				get_tree().create_timer(0.3).timeout.connect(func(): _update_song_display()))
	music_row.add_child(skip)

func _get_song_name() -> String:
	if _main and _main.has_method("_get_current_song_title"):
		return _main._get_current_song_title()
	elif _main and "_current_song_title" in _main:
		return _main._current_song_title
	return ""

func _update_song_display() -> void:
	if not _song_label: return
	var current = _get_song_name()
	if current != _last_song and current != "":
		_last_song = current
		# Fade out, change text, fade in
		var tw = create_tween()
		tw.tween_property(_song_label, "modulate:a", 0.0, 0.15)
		tw.tween_callback(func(): _song_label.text = current)
		tw.tween_property(_song_label, "modulate:a", 1.0, 0.15)

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
	_build_nav_buttons()

func _build_nav_buttons() -> void:
	var tabs = ["chapters", "survivors", "emporium", "codex", "settings"]
	var labels = ["CHAPTERS", "SURVIVORS", "EMPORIUM", "CODEX", "SETTINGS"]
	for i in range(5):
		var is_active = tabs[i] == current_view
		var btn = Button.new()
		btn.text = labels[i]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 70)
		var s = StyleBoxFlat.new()
		s.bg_color = Color(0.12, 0.08, 0.20, 0.5) if is_active else Color(0.05, 0.03, 0.10, 0.0)
		s.border_color = Color(0.85, 0.70, 0.30, 0.7) if is_active else Color(0, 0, 0, 0)
		s.border_width_top = 3 if is_active else 0
		s.set_corner_radius_all(0)
		btn.add_theme_stylebox_override("normal", s)
		var sh = s.duplicate()
		sh.bg_color = Color(0.15, 0.10, 0.25, 0.4)
		sh.border_color = Color(0.70, 0.55, 0.25, 0.5)
		sh.border_width_top = 2
		btn.add_theme_stylebox_override("hover", sh)
		btn.add_theme_font_size_override("font_size", 11)
		btn.add_theme_color_override("font_color", Color(1, 0.92, 0.45) if is_active else Color(0.55, 0.50, 0.45))
		btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		btn.add_theme_constant_override("shadow_offset_x", 1)
		btn.add_theme_constant_override("shadow_offset_y", 1)
		btn.pressed.connect(_on_tab.bind(tabs[i]))
		_add_press_feedback(btn)
		# Hover feedback on nav tabs
		btn.mouse_entered.connect(func():
			btn.pivot_offset = btn.size / 2.0
			var tw = btn.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1))
		btn.mouse_exited.connect(func():
			var tw = btn.create_tween().set_ease(Tween.EASE_OUT)
			tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.08))
		nav_buttons_container.add_child(btn)

func _on_tab(tab: String) -> void:
	if current_view == tab: return
	# Save scroll position of current view
	_save_scroll_position()
	# Fade out content, then switch
	var tw = create_tween()
	tw.tween_property(content_area, "modulate:a", 0.0, 0.1)
	tw.tween_callback(func():
		current_view = tab
		_set_bg(tab)
		# Rebuild nav with updated active state
		for c in nav_buttons_container.get_children(): c.queue_free()
		_build_nav_buttons()
		_clear()
		match tab:
			"chapters": _build_chapters()
			"survivors": _build_survivors()
			"emporium": _build_emporium()
			"codex": _build_codex()
			"settings": _build_settings()
		# Restore scroll position
		_restore_scroll_position()
		# Fade in new content
		var tw_in = create_tween()
		tw_in.tween_property(content_area, "modulate:a", 1.0, 0.15))

func _save_scroll_position() -> void:
	for c in content_area.get_children():
		if c is ScrollContainer:
			_scroll_positions[current_view] = c.scroll_vertical
			break

func _restore_scroll_position() -> void:
	if not _scroll_positions.has(current_view): return
	var target = _scroll_positions[current_view]
	# Defer to next frame so layout is done
	get_tree().create_timer(0.05).timeout.connect(func():
		for c in content_area.get_children():
			if c is ScrollContainer:
				c.scroll_vertical = target
				break)

func _clear() -> void:
	for c in content_area.get_children(): c.queue_free()

# ======================== CHAPTERS ========================
func _build_chapters() -> void:
	_clear()
	var sc = ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_area.add_child(sc)
	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 6)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sc.add_child(vb)
	# Title with entrance animation
	var title_container = CenterContainer.new()
	title_container.custom_minimum_size = Vector2(0, 50)
	title_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title_vb = VBoxContainer.new()
	title_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	title_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_container.add_child(title_vb)
	var main_title = _lbl("SHADOW DEFENSE", 28, Color(1.0, 0.90, 0.40))
	main_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_vb.add_child(main_title)
	var subtitle = _lbl("Tales from the Pages", 14, Color(0.70, 0.60, 0.48))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_vb.add_child(subtitle)
	# Entrance animation
	title_container.modulate.a = 0.0
	title_container.scale = Vector2(0.85, 0.85)
	title_container.pivot_offset = Vector2(640, 25)
	var title_tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	title_tw.set_parallel(true)
	title_tw.tween_property(title_container, "scale", Vector2(1.0, 1.0), 0.4)
	title_tw.tween_property(title_container, "modulate:a", 1.0, 0.25)
	vb.add_child(title_container)
	# Story tagline with storybook styling
	var tagline = _lbl("Heroes pulled from their stories. One Author controls them all.", 12, Color(0.65, 0.55, 0.45))
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_font_size_override("font_size", 12)
	tagline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(tagline)
	if not _main: return
	# Total star counter
	var total_stars = 0
	var max_stars = _main.levels.size() * 3
	if "level_stars" in _main:
		for k in _main.level_stars:
			total_stars += _main.level_stars[k]
	var star_bar = HBoxContainer.new()
	star_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	star_bar.add_theme_constant_override("separation", 6)
	star_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _art.has("golden_star"):
		var star_icon = TextureRect.new()
		star_icon.texture = _art["golden_star"]
		star_icon.custom_minimum_size = Vector2(20, 20)
		star_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat = _make_black_key_mat(0.1, 0.05)
		if mat: star_icon.material = mat
		star_bar.add_child(star_icon)
	star_bar.add_child(_lbl("%d / %d Stars" % [total_stars, max_stars], 13, Color(1.0, 0.85, 0.25)))
	# Completion bar
	var comp_pct = float(total_stars) / float(max_stars) if max_stars > 0 else 0.0
	var comp_bar = _stat_bar("Progress", total_stars, max_stars, Color(1.0, 0.85, 0.25))
	comp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(star_bar)
	vb.add_child(comp_bar)
	var cur_arc = ""
	var card_idx = 0
	for i in range(_main.levels.size()):
		var lvl = _main.levels[i]
		var sub = lvl.get("subtitle", "")
		var arc = sub.split(" — ")[0] if " — " in sub else "Prologue"
		if arc == "": arc = "Prologue"
		if arc != cur_arc:
			cur_arc = arc
			# Arc header with portrait + art divider
			var hdr_container = HBoxContainer.new()
			hdr_container.add_theme_constant_override("separation", 8)
			hdr_container.alignment = BoxContainer.ALIGNMENT_CENTER
			hdr_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
			# Character portrait for this arc
			var arc_portrait_key = ""
			for apk in ARC_PORTRAITS:
				if arc.begins_with(apk) or apk in arc:
					arc_portrait_key = ARC_PORTRAITS[apk]
					break
			if arc_portrait_key != "" and _main and _main._portrait_textures.has(arc_portrait_key):
				var arc_port = TextureRect.new()
				arc_port.texture = _main._portrait_textures[arc_portrait_key]
				arc_port.custom_minimum_size = Vector2(32, 32)
				arc_port.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				arc_port.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				arc_port.mouse_filter = Control.MOUSE_FILTER_IGNORE
				hdr_container.add_child(arc_port)
			if _art.has("chapter_divider"):
				var div_left = TextureRect.new()
				div_left.texture = _art["chapter_divider"]
				div_left.custom_minimum_size = Vector2(50, 20)
				div_left.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				div_left.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				div_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var mat = _make_black_key_mat(0.06, 0.04)
				if mat: div_left.material = mat
				hdr_container.add_child(div_left)
			var hdr = _lbl(arc.to_upper(), 18, Color(0.95, 0.85, 0.45))
			hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hdr_container.add_child(hdr)
			if _art.has("chapter_divider"):
				var div_right = TextureRect.new()
				div_right.texture = _art["chapter_divider"]
				div_right.custom_minimum_size = Vector2(50, 20)
				div_right.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				div_right.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				div_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
				div_right.flip_h = true
				var mat = _make_black_key_mat(0.06, 0.04)
				if mat: div_right.material = mat
				hdr_container.add_child(div_right)
			vb.add_child(hdr_container)
		var card = _level_card(i, lvl)
		vb.add_child(card)
		# Staggered entrance animation
		card.modulate.a = 0.0
		var tw = create_tween()
		tw.tween_property(card, "modulate:a", 1.0, 0.2).set_delay(card_idx * 0.03)
		card_idx += 1
		# Pulsing "NEXT" indicator on first uncompleted unlocked level
		var is_unlocked = _main._is_level_unlocked(i)
		var is_complete = i in _main.completed_levels
		if is_unlocked and not is_complete:
			# Only pulse the FIRST one
			var already_pulsing = false
			for prev_idx in range(i):
				if _main._is_level_unlocked(prev_idx) and prev_idx not in _main.completed_levels:
					already_pulsing = true
					break
			if not already_pulsing:
				# Add pulsing gold border glow
				var pulse_tw = create_tween().set_loops()
				pulse_tw.tween_property(card, "modulate", Color(1.2, 1.15, 1.0), 0.6).set_ease(Tween.EASE_IN_OUT)
				pulse_tw.tween_property(card, "modulate", Color(1.0, 1.0, 1.0), 0.6).set_ease(Tween.EASE_IN_OUT)

func _level_card(idx: int, lvl: Dictionary) -> PanelContainer:
	var unlocked = _main._is_level_unlocked(idx)
	var complete = idx in _main.completed_levels
	var p = PanelContainer.new()
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.04, 0.03, 0.10, 0.55) if unlocked else Color(0.03, 0.02, 0.06, 0.40)
	s.border_color = Color(0.3, 0.65, 0.25, 0.6) if complete else Color(0.35, 0.25, 0.18, 0.3)
	s.set_border_width_all(1 if not complete else 2)
	s.set_corner_radius_all(6)
	s.content_margin_left = 8; s.content_margin_right = 8; s.content_margin_top = 4; s.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	# Hover feedback on level card
	p.mouse_entered.connect(func():
		var tw = p.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(p, "modulate", Color(1.15, 1.12, 1.05), 0.12))
	p.mouse_exited.connect(func():
		var base = Color.WHITE if not complete else Color(0.92, 1.0, 0.92)
		var tw = p.create_tween().set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate", base, 0.1))
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	# Level number with boss skull for every 3rd level
	var is_boss = (idx + 1) % 3 == 0 and idx > 0
	var num_col = VBoxContainer.new()
	num_col.alignment = BoxContainer.ALIGNMENT_CENTER
	num_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var num_lbl = _lbl(str(idx+1), 18, Color(0.85, 0.72, 0.40) if unlocked else Color(0.35, 0.30, 0.25))
	num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	num_col.add_child(num_lbl)
	if is_boss:
		var skull = _lbl("💀", 14, Color(0.8, 0.2, 0.15))
		skull.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		skull.mouse_filter = Control.MOUSE_FILTER_IGNORE
		num_col.add_child(skull)
	row.add_child(num_col)
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
	var name_row = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n = _lbl(lvl.get("name",""), 14, Color(1, 0.95, 0.85) if unlocked else Color(0.45, 0.40, 0.35))
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(n)
	# NEW badge — unlocked but not completed
	if unlocked and not complete:
		var new_badge = PanelContainer.new()
		var nbs = StyleBoxFlat.new()
		nbs.bg_color = Color(0.15, 0.6, 0.15, 0.85)
		nbs.set_corner_radius_all(8)
		nbs.content_margin_left = 6; nbs.content_margin_right = 6
		nbs.content_margin_top = 1; nbs.content_margin_bottom = 1
		new_badge.add_theme_stylebox_override("panel", nbs)
		new_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var badge_lbl = _lbl("NEW", 8, Color.WHITE)
		badge_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		new_badge.add_child(badge_lbl)
		name_row.add_child(new_badge)
	# Boss level badge
	if is_boss and unlocked:
		var boss_badge = PanelContainer.new()
		var bbs = StyleBoxFlat.new()
		bbs.bg_color = Color(0.6, 0.12, 0.1, 0.85)
		bbs.set_corner_radius_all(8)
		bbs.content_margin_left = 6; bbs.content_margin_right = 6
		bbs.content_margin_top = 1; bbs.content_margin_bottom = 1
		boss_badge.add_theme_stylebox_override("panel", bbs)
		boss_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var boss_lbl = _lbl("BOSS", 8, Color.WHITE)
		boss_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boss_badge.add_child(boss_lbl)
		name_row.add_child(boss_badge)
	info.add_child(name_row)
	var st = _lbl(lvl.get("subtitle",""), 10, Color(0.55,0.48,0.42))
	st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(st)
	# Stats row with wave/gold/lives
	var stats_row = HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 8)
	stats_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stats = _lbl("W:%d  G:%d  L:%d" % [lvl.get("waves",20), lvl.get("gold",100), lvl.get("lives",20)], 9, Color(0.45, 0.40, 0.38))
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_row.add_child(stats)
	# Difficulty medals for completed levels (bronze=Easy, silver=Med, gold=Hard)
	if complete:
		var medal_colors = [
			["E", Color(0.72, 0.45, 0.20)],  # Bronze — Easy
			["M", Color(0.70, 0.70, 0.75)],   # Silver — Med
			["H", Color(1.0, 0.85, 0.15)],    # Gold — Hard
		]
		var medals_row = HBoxContainer.new()
		medals_row.add_theme_constant_override("separation", 2)
		medals_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Check which difficulties are completed
		var completed_diffs = _main.level_difficulty_completions.get(idx, []) if "level_difficulty_completions" in _main else []
		for mi in range(3):
			var earned = mi in completed_diffs if completed_diffs is Array else (mi == 0)
			var medal = _lbl("●", 10, medal_colors[mi][1] if earned else Color(0.25, 0.22, 0.20, 0.4))
			medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
			medal.tooltip_text = ["Easy", "Medium", "Hard"][mi]
			medals_row.add_child(medal)
		stats_row.add_child(medals_row)
	info.add_child(stats_row)
	# Star rating — use golden_star art if available
	if _main and _main.level_stars.has(idx):
		var star_count = _main.level_stars[idx]
		if _art.has("golden_star"):
			var star_row = HBoxContainer.new()
			star_row.add_theme_constant_override("separation", 2)
			star_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			for _si in range(3):
				var star = TextureRect.new()
				star.texture = _art["golden_star"]
				star.custom_minimum_size = Vector2(16, 16)
				star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				star.mouse_filter = Control.MOUSE_FILTER_IGNORE
				if _si >= star_count:
					star.modulate = Color(0.3, 0.25, 0.2, 0.4)  # Dim unearned
				var mat = _make_black_key_mat(0.1, 0.05)
				if mat: star.material = mat
				star_row.add_child(star)
			info.add_child(star_row)
		else:
			var star_text = ""
			for _si in range(star_count): star_text += "★"
			for _si in range(3 - star_count): star_text += "☆"
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
		# Difficulty buttons — gem-style with glow
		for d in [[0,"EASY",Color(0.15,0.55,0.15)],[1,"MED",Color(0.60,0.45,0.05)],[2,"HARD",Color(0.60,0.10,0.08)]]:
			var db = Button.new()
			db.text = d[1]; db.custom_minimum_size = Vector2(58, 28)
			var ds = StyleBoxFlat.new()
			ds.bg_color = Color(d[2].r * 0.4, d[2].g * 0.4, d[2].b * 0.4, 0.85)
			ds.set_corner_radius_all(8)
			ds.border_color = Color(d[2].r * 1.8, d[2].g * 1.8, d[2].b * 1.8, 0.7)
			ds.set_border_width_all(2)
			ds.shadow_color = Color(d[2].r, d[2].g, d[2].b, 0.3)
			ds.shadow_size = 3
			db.add_theme_stylebox_override("normal", ds)
			var dsh = ds.duplicate()
			dsh.bg_color = Color(d[2].r * 0.6, d[2].g * 0.6, d[2].b * 0.6, 0.9)
			dsh.border_color = Color(d[2].r * 2.0, d[2].g * 2.0, d[2].b * 2.0, 0.85)
			dsh.shadow_size = 5
			db.add_theme_stylebox_override("hover", dsh)
			var dsp = ds.duplicate()
			dsp.bg_color = d[2].darkened(0.15)
			dsp.shadow_size = 1
			db.add_theme_stylebox_override("pressed", dsp)
			db.add_theme_font_size_override("font_size", 10)
			db.add_theme_color_override("font_color", Color.WHITE)
			db.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
			db.add_theme_constant_override("shadow_offset_x", 1)
			db.add_theme_constant_override("shadow_offset_y", 1)
			db.pressed.connect(_play.bind(idx, d[0]))
			_add_press_feedback(db)
			dr.add_child(db)
		btns.add_child(dr)
		# PLAY button — use go_button or play_button art
		var play_art_key = "go_button" if _art.has("go_button") else ("play_button" if _art.has("play_button") else "")
		if play_art_key != "":
			var pb = TextureButton.new()
			pb.texture_normal = _art[play_art_key]
			pb.ignore_texture_size = true
			pb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			pb.custom_minimum_size = Vector2(170, 48)
			var mat = _make_black_key_mat(0.08, 0.05)
			if mat: pb.material = mat
			pb.mouse_entered.connect(func():
				var tw = pb.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
				tw.tween_property(pb, "modulate", Color(1.2, 1.15, 1.0), 0.1))
			pb.mouse_exited.connect(func():
				var tw = pb.create_tween().set_ease(Tween.EASE_OUT)
				tw.tween_property(pb, "modulate", Color.WHITE, 0.08))
			pb.pressed.connect(_play.bind(idx, 0))
			_add_press_feedback(pb)
			btns.add_child(pb)
		else:
			var pb = Button.new()
			pb.text = "PLAY"; pb.custom_minimum_size = Vector2(150, 30)
			var ps = StyleBoxFlat.new(); ps.bg_color = Color(0.12,0.50,0.12,0.9); ps.set_corner_radius_all(6)
			pb.add_theme_stylebox_override("normal", ps)
			pb.add_theme_font_size_override("font_size", 13)
			pb.add_theme_color_override("font_color", Color.WHITE)
			pb.pressed.connect(_play.bind(idx, 0))
			_add_press_feedback(pb)
			btns.add_child(pb)
		row.add_child(btns)
	else:
		var lock_vb = VBoxContainer.new()
		lock_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock_vb.alignment = BoxContainer.ALIGNMENT_CENTER
		lock_vb.custom_minimum_size = Vector2(120, 0)
		# Lock icon panel with glow
		var lock_panel = PanelContainer.new()
		var lps = StyleBoxFlat.new()
		lps.bg_color = Color(0.06, 0.04, 0.10, 0.6)
		lps.set_corner_radius_all(8)
		lps.border_color = Color(0.4, 0.3, 0.2, 0.4)
		lps.set_border_width_all(1)
		lps.content_margin_left = 8; lps.content_margin_right = 8
		lps.content_margin_top = 6; lps.content_margin_bottom = 6
		lock_panel.add_theme_stylebox_override("panel", lps)
		lock_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lock_content = VBoxContainer.new()
		lock_content.alignment = BoxContainer.ALIGNMENT_CENTER
		lock_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock_panel.add_child(lock_content)
		var lock_icon = _lbl("🔒", 24, Color(0.5, 0.4, 0.3))
		lock_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock_content.add_child(lock_icon)
		var lock_text = _lbl("LOCKED", 10, Color(0.45, 0.38, 0.30))
		lock_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock_content.add_child(lock_text)
		var lock_req = _lbl("Complete previous", 8, Color(0.35, 0.30, 0.25))
		lock_req.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_req.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock_content.add_child(lock_req)
		lock_vb.add_child(lock_panel)
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
	vb.add_child(_title("SURVIVORS"))
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
	# Check if character is unlocked
	var is_unlocked = false
	var tt = _main.survivor_types[idx] if _main and idx < _main.survivor_types.size() else null
	if tt != null and _main:
		is_unlocked = _main._is_character_unlocked(tt)
	# The card IS a Button — fills grid cell
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(200, 270)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Style based on unlock status
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.04, 0.12, 0.70) if is_unlocked else Color(0.03, 0.02, 0.06, 0.50)
	s.border_color = Color(0.45, 0.35, 0.20, 0.5) if is_unlocked else Color(0.20, 0.18, 0.15, 0.3)
	s.set_border_width_all(2); s.set_corner_radius_all(8)
	s.content_margin_left = 4; s.content_margin_right = 4
	s.content_margin_top = 4; s.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", s)
	var sh = s.duplicate()
	sh.bg_color = Color(0.10, 0.07, 0.18, 0.80) if is_unlocked else Color(0.05, 0.03, 0.10, 0.6)
	sh.border_color = Color(0.65, 0.50, 0.25, 0.8) if is_unlocked else Color(0.30, 0.25, 0.18, 0.4)
	btn.add_theme_stylebox_override("hover", sh)
	var sp = s.duplicate()
	sp.bg_color = Color(0.12, 0.08, 0.20, 0.85)
	btn.add_theme_stylebox_override("pressed", sp)
	btn.text = ""
	# Art frame layer behind content (survivor_card_frame or card_frame with black keyed out)
	var frame_key = "survivor_card_frame" if _art.has("survivor_card_frame") else "card_frame"
	if _art.has(frame_key):
		var frame_art = TextureRect.new()
		frame_art.texture = _art[frame_key]
		frame_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		frame_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		frame_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame_art.modulate.a = 0.45  # Visible art overlay
		var mat = _make_black_key_mat(0.06, 0.04)
		if mat: frame_art.material = mat
		btn.add_child(frame_art)
	# Content fills entire button area — centered
	var vb = VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vb)
	# Portrait — fills width, centered. Silhouette if locked.
	var port = TextureRect.new()
	port.custom_minimum_size = Vector2(0, 190)
	port.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	port.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	port.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	port.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pkey = PORTRAIT_KEYS[idx]
	if _main and _main._portrait_textures.has(pkey):
		port.texture = _main._portrait_textures[pkey]
		if not is_unlocked:
			port.modulate = Color(0.08, 0.06, 0.12)  # Dark silhouette
	vb.add_child(port)
	# Name — show "???" for locked
	var cname = _main.character_names[idx] if _main and idx < _main.character_names.size() else "?"
	var display_name = cname.to_upper() if is_unlocked else "???"
	var nl = _lbl(display_name, 11, Color(1, 0.92, 0.45) if is_unlocked else Color(0.35, 0.30, 0.25))
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(nl)
	# Locked indicator
	if not is_unlocked:
		var lock_lbl = _lbl("🔒 LOCKED", 10, Color(0.40, 0.35, 0.30))
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(lock_lbl)
	var ctitle = _main.character_titles[idx] if _main and idx < _main.character_titles.size() else ""
	var tl = _lbl(ctitle if is_unlocked else "", 9, Color(0.55, 0.48, 0.42))
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(tl)
	# Level badge (only for unlocked)
	if is_unlocked and tt != null and _main.survivor_progress.has(tt):
		var lvl = _main.survivor_progress[tt].get("level", 1)
		var badge = _lbl("Lv.%d" % lvl, 9, Color(0.85, 0.72, 0.40))
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(badge)
	# Source novel (only for unlocked)
	if is_unlocked and _main and idx < _main.character_novels.size():
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
	# Detail panel art background — character_info_card
	var detail_art_key = "character_info_card" if _art.has("character_info_card") else "detail_panel"
	if _art.has(detail_art_key):
		var detail_bg = TextureRect.new()
		detail_bg.texture = _art[detail_art_key]
		detail_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		detail_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		detail_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		detail_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		detail_bg.modulate.a = 0.35
		var mat = _make_black_key_mat(0.06, 0.04)
		if mat: detail_bg.material = mat
		content_area.add_child(detail_bg)
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
	# Back button with art styling
	var back = _art_button("< BACK", Color(0.12, 0.10, 0.22), Vector2(90, 30))
	back.pressed.connect(_build_survivors)
	right.add_child(back)
	# TAB BUTTONS — Stats / Gear / Allies / Abilities (styled with glow)
	var tab_row = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 4)
	tab_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ti in range(4):
		var tab_names_arr = ["STATS", "GEAR", "ALLIES", "ABILITIES"]
		var is_active_tab = ti == _detail_tab
		var tb = Button.new()
		tb.text = tab_names_arr[ti]
		tb.custom_minimum_size = Vector2(100, 30)
		var ts = StyleBoxFlat.new()
		ts.bg_color = Color(0.15, 0.10, 0.25, 0.85) if is_active_tab else Color(0.06, 0.04, 0.12, 0.4)
		ts.set_corner_radius_all(6)
		ts.border_color = Color(0.85, 0.65, 0.20, 0.7) if is_active_tab else Color(0.25, 0.20, 0.15, 0.3)
		ts.set_border_width_all(2 if is_active_tab else 1)
		if is_active_tab:
			ts.shadow_color = Color(0.5, 0.35, 0.1, 0.2)
			ts.shadow_size = 3
		tb.add_theme_stylebox_override("normal", ts)
		var tsh = ts.duplicate()
		tsh.bg_color = Color(0.20, 0.14, 0.32, 0.9)
		tsh.border_color = Color(0.70, 0.55, 0.20, 0.6)
		tb.add_theme_stylebox_override("hover", tsh)
		tb.add_theme_font_size_override("font_size", 11)
		tb.add_theme_color_override("font_color", Color(1, 0.92, 0.45) if is_active_tab else Color(0.55, 0.50, 0.45))
		tb.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		tb.add_theme_constant_override("shadow_offset_x", 1)
		tb.add_theme_constant_override("shadow_offset_y", 1)
		tb.pressed.connect(_switch_detail_tab.bind(ti))
		_add_press_feedback(tb)
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
		var gs = StyleBoxFlat.new()
		gs.bg_color = Color(0.05, 0.03, 0.10, 0.5)
		gs.set_corner_radius_all(8)
		gs.set_border_width_all(2)
		gs.border_color = Color(0.65, 0.50, 0.20, 0.6)
		gs.shadow_color = Color(0.4, 0.3, 0.1, 0.15)
		gs.shadow_size = 4
		gs.content_margin_left = 10; gs.content_margin_right = 10; gs.content_margin_top = 8; gs.content_margin_bottom = 8
		gp.add_theme_stylebox_override("panel", gs)
		# Art behind gear panel
		if _art.has("gear_slots"):
			var gear_art = TextureRect.new()
			gear_art.texture = _art["gear_slots"]
			gear_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			gear_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			gear_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			gear_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			gear_art.modulate.a = 0.25
			var mat = _make_black_key_mat(0.06, 0.04)
			if mat: gear_art.material = mat
			gp.add_child(gear_art)
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
			var skp = PanelContainer.new()
			var sks = StyleBoxFlat.new()
			sks.bg_color = Color(0.05, 0.03, 0.10, 0.45)
			sks.set_corner_radius_all(6)
			sks.content_margin_left = 8; sks.content_margin_right = 8
			sks.content_margin_top = 4; sks.content_margin_bottom = 4
			skp.add_theme_stylebox_override("panel", sks)
			skp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var sk_row = HBoxContainer.new()
			sk_row.add_theme_constant_override("separation", 8)
			sk_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			skp.add_child(sk_row)
			sk_row.add_child(_lbl(sk.get("name",""), 12, Color(0.9, 0.82, 0.55)))
			var sk_desc = _lbl(sk.get("desc",""), 10, Color(0.55, 0.50, 0.45))
			sk_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			sk_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sk_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sk_row.add_child(sk_desc)
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
	# Show abilities with styled cards
	if ability_names.size() > 0:
		for ai in range(ability_names.size()):
			var unlocked_ab = ai < 2  # Placeholder — first 2 unlocked
			var ab_panel = PanelContainer.new()
			var abs = StyleBoxFlat.new()
			abs.bg_color = Color(0.06, 0.04, 0.12, 0.5) if unlocked_ab else Color(0.03, 0.02, 0.06, 0.3)
			abs.set_corner_radius_all(6)
			abs.border_color = Color(0.4, 0.65, 0.25, 0.5) if unlocked_ab else Color(0.2, 0.18, 0.15, 0.3)
			abs.set_border_width_all(1)
			abs.content_margin_left = 8; abs.content_margin_right = 8
			abs.content_margin_top = 3; abs.content_margin_bottom = 3
			ab_panel.add_theme_stylebox_override("panel", abs)
			ab_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var ab_row = HBoxContainer.new()
			ab_row.add_theme_constant_override("separation", 8)
			ab_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ab_panel.add_child(ab_row)
			var icon_text = "✓" if unlocked_ab else "🔒"
			var icon_color = Color(0.4, 0.8, 0.3) if unlocked_ab else Color(0.35, 0.30, 0.25)
			ab_row.add_child(_lbl(icon_text, 12, icon_color))
			var ab_name = _lbl(ability_names[ai], 11, Color(0.8, 0.9, 0.6) if unlocked_ab else Color(0.4, 0.35, 0.30))
			ab_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ab_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ab_row.add_child(ab_name)
			var tier_lbl = _lbl("Tier %d" % (ai + 1), 9, Color(0.55, 0.48, 0.42))
			tier_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ab_row.add_child(tier_lbl)
			right.add_child(ab_panel)
	else:
		right.add_child(_lbl("Unlock abilities through combat damage", 10, Color(0.50, 0.45, 0.40)))

func _stat_bar(label: String, value: float, max_val: float, color: Color) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nl = _lbl(label, 12, Color(0.75,0.68,0.58))
	nl.custom_minimum_size.x = 80
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(nl)
	# Bar background with rounded corners
	var bar_panel = PanelContainer.new()
	bar_panel.custom_minimum_size = Vector2(200, 16)
	bar_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar_style = StyleBoxFlat.new()
	bar_style.bg_color = Color(0.06, 0.04, 0.10, 0.8)
	bar_style.set_corner_radius_all(4)
	bar_style.border_color = Color(0.25, 0.20, 0.15, 0.4)
	bar_style.set_border_width_all(1)
	bar_panel.add_theme_stylebox_override("panel", bar_style)
	row.add_child(bar_panel)
	# Bar fill — animate width
	var fill_pct = clampf(value / max_val, 0, 1)
	var bar_fill = ColorRect.new()
	bar_fill.custom_minimum_size = Vector2(0, 12)  # Start at 0 for animation
	bar_fill.color = color
	bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	bar_fill.offset_left = 2; bar_fill.offset_top = 2; bar_fill.offset_bottom = -2
	bar_panel.add_child(bar_fill)
	# Animate fill width
	var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(bar_fill, "offset_right", -200 + (196 * fill_pct), 0.4)
	# Value text
	var val_lbl = _lbl(str(int(value)), 12, color)
	val_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(val_lbl)
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
	# Featured daily deals banner
	if _art.has("daily_deals"):
		var deals_panel = PanelContainer.new()
		var dps = StyleBoxFlat.new()
		dps.bg_color = Color(0.08, 0.04, 0.15, 0.5)
		dps.set_corner_radius_all(10)
		dps.border_color = Color(0.85, 0.65, 0.10, 0.5)
		dps.set_border_width_all(2)
		dps.shadow_color = Color(0.4, 0.3, 0.05, 0.15)
		dps.shadow_size = 4
		dps.content_margin_left = 8; dps.content_margin_right = 8
		dps.content_margin_top = 6; dps.content_margin_bottom = 6
		deals_panel.add_theme_stylebox_override("panel", dps)
		deals_panel.custom_minimum_size = Vector2(0, 80)
		deals_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var deals_art = TextureRect.new()
		deals_art.texture = _art["daily_deals"]
		deals_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		deals_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		deals_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		deals_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		deals_art.modulate.a = 0.5
		var mat = _make_black_key_mat(0.06, 0.04)
		if mat: deals_art.material = mat
		deals_panel.add_child(deals_art)
		var deals_lbl = _lbl("DAILY DEALS — New offers every day!", 14, Color(1, 0.85, 0.3))
		deals_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		deals_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		deals_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		deals_panel.add_child(deals_lbl)
		vb.add_child(deals_panel)
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
		_add_press_feedback(btn)
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
	# Back button with art styling
	var back = _art_button("< BACK TO EMPORIUM", Color(0.12, 0.10, 0.22), Vector2(190, 32))
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
	# Currency exchange art
	if _art.has("currency_exchange"):
		var ex_art = TextureRect.new()
		ex_art.texture = _art["currency_exchange"]
		ex_art.custom_minimum_size = Vector2(0, 60)
		ex_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ex_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ex_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ex_art.modulate.a = 0.5
		var mat = _make_black_key_mat(0.06, 0.04)
		if mat: ex_art.material = mat
		parent.add_child(ex_art)
	var exchange_data = [
		["100 Gold", "5 Quills", 100, Color(1,0.85,0.2), Color(0.7,0.5,0.9)],
		["250 Gold", "15 Shards", 250, Color(1,0.85,0.2), Color(0.3,0.75,0.9)],
		["500 Gold", "3 Stars", 500, Color(1,0.85,0.2), Color(1,0.9,0.3)],
	]
	for ex in exchange_data:
		var card = PanelContainer.new()
		var cs = StyleBoxFlat.new()
		cs.bg_color = Color(0.05, 0.03, 0.10, 0.5)
		cs.set_corner_radius_all(8)
		cs.border_color = Color(0.55, 0.42, 0.18, 0.4)
		cs.set_border_width_all(1)
		cs.content_margin_left = 12; cs.content_margin_right = 12
		cs.content_margin_top = 8; cs.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", cs)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(row)
		row.add_child(_lbl(ex[0], 14, ex[3]))
		row.add_child(_lbl("→", 16, Color(0.65, 0.55, 0.45)))
		var recv = _lbl(ex[1], 14, ex[4])
		recv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		recv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(recv)
		var buy = _art_button("EXCHANGE", Color(0.12, 0.40, 0.12))
		row.add_child(buy)
		parent.add_child(card)

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
	# Wheel header with art
	var wheel_panel = PanelContainer.new()
	var wps = StyleBoxFlat.new()
	wps.bg_color = Color(0.08, 0.04, 0.15, 0.5)
	wps.set_corner_radius_all(12)
	wps.border_color = Color(0.7, 0.5, 0.1, 0.5)
	wps.set_border_width_all(2)
	wps.shadow_color = Color(0.4, 0.2, 0.6, 0.15)
	wps.shadow_size = 6
	wps.content_margin_left = 20; wps.content_margin_right = 20
	wps.content_margin_top = 16; wps.content_margin_bottom = 16
	wheel_panel.add_theme_stylebox_override("panel", wps)
	var wv = VBoxContainer.new()
	wv.add_theme_constant_override("separation", 10)
	wv.alignment = BoxContainer.ALIGNMENT_CENTER
	wv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wheel_panel.add_child(wv)
	wv.add_child(_lbl("LUCKY WHEEL", 20, Color(1, 0.85, 0.3)))
	wv.add_child(_lbl("One FREE spin per day!", 13, Color(0.3, 0.9, 0.3)))
	var spin_btn = _art_button("SPIN!", Color(0.5, 0.12, 0.5), Vector2(200, 50))
	spin_btn.add_theme_font_size_override("font_size", 20)
	_add_press_feedback(spin_btn)
	wv.add_child(spin_btn)
	parent.add_child(wheel_panel)
	# Prize list
	parent.add_child(_lbl("Possible Prizes:", 13, Color(0.65, 0.58, 0.50)))
	if _main:
		var prize_grid = GridContainer.new()
		prize_grid.columns = 2
		prize_grid.add_theme_constant_override("h_separation", 8)
		prize_grid.add_theme_constant_override("v_separation", 6)
		prize_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		prize_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		parent.add_child(prize_grid)
		for prize in _main.SPIN_WHEEL_PRIZES:
			var pp = PanelContainer.new()
			var pps = StyleBoxFlat.new()
			pps.bg_color = Color(0.04, 0.03, 0.08, 0.4)
			pps.set_corner_radius_all(6)
			pps.content_margin_left = 8; pps.content_margin_right = 8
			pps.content_margin_top = 4; pps.content_margin_bottom = 4
			pp.add_theme_stylebox_override("panel", pps)
			pp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var pl = _lbl(prize.get("name",""), 11, prize.get("col", Color.WHITE))
			pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pp.add_child(pl)
			prize_grid.add_child(pp)

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
		var is_active_codex = _codex_subtab == tab[0]
		var tb = Button.new()
		tb.text = tab[1]
		tb.custom_minimum_size = Vector2(120, 30)
		var ts = StyleBoxFlat.new()
		ts.bg_color = Color(0.15, 0.10, 0.25, 0.85) if is_active_codex else Color(0.06, 0.04, 0.12, 0.4)
		ts.set_corner_radius_all(6)
		ts.border_color = Color(0.85, 0.65, 0.20, 0.7) if is_active_codex else Color(0.25, 0.20, 0.15, 0.3)
		ts.set_border_width_all(2 if is_active_codex else 1)
		if is_active_codex:
			ts.shadow_color = Color(0.5, 0.35, 0.1, 0.2)
			ts.shadow_size = 3
		tb.add_theme_stylebox_override("normal", ts)
		var tsh = ts.duplicate()
		tsh.bg_color = Color(0.20, 0.14, 0.32, 0.9)
		tsh.border_color = Color(0.70, 0.55, 0.20, 0.6)
		tb.add_theme_stylebox_override("hover", tsh)
		tb.add_theme_font_size_override("font_size", 11)
		tb.add_theme_color_override("font_color", Color(1, 0.92, 0.45) if is_active_codex else Color(0.55, 0.50, 0.45))
		tb.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		tb.add_theme_constant_override("shadow_offset_x", 1)
		tb.add_theme_constant_override("shadow_offset_y", 1)
		tb.pressed.connect(_codex_switch.bind(tab[0]))
		_add_press_feedback(tb)
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
		"bestiary": _build_bestiary(content)
		"journal": _build_journal(content)
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
	var gear_idx = 0
	for gk in keys:
		# Rarity color based on position (simulate rarity distribution)
		var rarity_colors = [Color(0.5, 0.5, 0.5), Color(0.3, 0.7, 0.3), Color(0.2, 0.5, 0.9), Color(0.7, 0.3, 0.9), Color(1.0, 0.7, 0.1)]
		var rarity_idx = clampi(gear_idx % 5, 0, 4)
		var rarity_col = rarity_colors[rarity_idx]
		gear_idx += 1
		# Each gear item in a styled panel
		var card = PanelContainer.new()
		var cs = StyleBoxFlat.new()
		cs.bg_color = Color(0.04, 0.03, 0.08, 0.6)
		cs.border_color = Color(rarity_col.r * 0.7, rarity_col.g * 0.7, rarity_col.b * 0.7, 0.5)
		cs.set_border_width_all(2)
		cs.set_corner_radius_all(8)
		cs.shadow_color = Color(rarity_col.r * 0.3, rarity_col.g * 0.3, rarity_col.b * 0.3, 0.2)
		cs.shadow_size = 3
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
		# Show achievement icons from textures with styled cards
		if _main._achievement_icon_textures.size() > 0:
			parent.add_child(_lbl("%d Achievements Discovered" % _main._achievement_icon_textures.size(), 12, Color(0.6, 0.55, 0.48)))
			var grid = GridContainer.new()
			grid.columns = 6
			grid.add_theme_constant_override("h_separation", 8)
			grid.add_theme_constant_override("v_separation", 8)
			grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
			parent.add_child(grid)
			var keys = _main._achievement_icon_textures.keys()
			keys.sort()
			for ak in keys:
				# Achievement card with art border
				var card = PanelContainer.new()
				var cs = StyleBoxFlat.new()
				cs.bg_color = Color(0.05, 0.03, 0.10, 0.6)
				cs.border_color = Color(0.65, 0.50, 0.20, 0.4)
				cs.set_border_width_all(1)
				cs.set_corner_radius_all(6)
				cs.content_margin_left = 4; cs.content_margin_right = 4
				cs.content_margin_top = 4; cs.content_margin_bottom = 4
				card.add_theme_stylebox_override("panel", cs)
				card.mouse_filter = Control.MOUSE_FILTER_IGNORE
				card.tooltip_text = ak.replace("_", " ").capitalize()
				var cv = VBoxContainer.new()
				cv.alignment = BoxContainer.ALIGNMENT_CENTER
				cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
				card.add_child(cv)
				var icon = TextureRect.new()
				icon.texture = _main._achievement_icon_textures[ak]
				icon.custom_minimum_size = Vector2(56, 56)
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
				cv.add_child(icon)
				var name_lbl = _lbl(ak.replace("_", " ").capitalize(), 7, Color(0.60, 0.55, 0.48))
				name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				name_lbl.clip_text = true
				name_lbl.custom_minimum_size.x = 72
				name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				cv.add_child(name_lbl)
				grid.add_child(card)
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
	for si in range(stats_data.size()):
		var sd = stats_data[si]
		# Styled stat row with alternating backgrounds
		var row_panel = PanelContainer.new()
		var rps = StyleBoxFlat.new()
		rps.bg_color = Color(0.04, 0.03, 0.08, 0.5) if si % 2 == 0 else Color(0.06, 0.04, 0.10, 0.4)
		rps.set_corner_radius_all(6)
		rps.content_margin_left = 16; rps.content_margin_right = 16
		rps.content_margin_top = 8; rps.content_margin_bottom = 8
		row_panel.add_theme_stylebox_override("panel", rps)
		row_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_panel.add_child(row)
		var nl = _lbl(sd[0], 14, Color(0.75, 0.68, 0.58))
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(nl)
		var vl = _lbl(_format_num(float(sd[1])) if sd[1] is float or sd[1] > 999 else str(sd[1]), 18, Color(1.0, 0.92, 0.45))
		vl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(vl)
		parent.add_child(row_panel)

func _build_bestiary(parent: VBoxContainer) -> void:
	parent.add_child(_lbl("BESTIARY", 14, Color(0.85, 0.72, 0.40)))
	parent.add_child(_lbl("Enemies encountered in your battles", 11, Color(0.55, 0.50, 0.45)))
	if not _main: return
	# Show enemy types from the game data
	var enemy_types = [
		["Ink Blot", "Basic ranged unit. Slow but steady.", Color(0.3, 0.3, 0.3)],
		["Page Ripper", "Fast melee unit. Shreds defenses.", Color(0.7, 0.3, 0.3)],
		["Spine Crawler", "Armored. Takes extra hits.", Color(0.5, 0.5, 0.6)],
		["Plot Twist", "Teleports past towers.", Color(0.6, 0.3, 0.7)],
		["Chapter Boss", "Elite enemy. Massive HP.", Color(0.8, 0.6, 0.2)],
		["Eraser", "Removes tower buffs on contact.", Color(0.9, 0.9, 0.9)],
		["Bookmark", "Heals nearby enemies.", Color(0.3, 0.7, 0.3)],
		["Red Herring", "Decoy that splits on death.", Color(0.8, 0.2, 0.2)],
	]
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(grid)
	for e in enemy_types:
		var card = PanelContainer.new()
		var cs = StyleBoxFlat.new()
		cs.bg_color = Color(0.05, 0.03, 0.10, 0.5)
		cs.set_corner_radius_all(8)
		cs.border_color = Color(e[2].r * 0.5, e[2].g * 0.5, e[2].b * 0.5, 0.4)
		cs.set_border_width_all(1)
		cs.content_margin_left = 10; cs.content_margin_right = 10
		cs.content_margin_top = 8; cs.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", cs)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv = VBoxContainer.new()
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(cv)
		cv.add_child(_lbl(e[0], 14, e[2]))
		var desc = _lbl(e[1], 10, Color(0.55, 0.50, 0.45))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(desc)
		grid.add_child(card)

func _build_journal(parent: VBoxContainer) -> void:
	parent.add_child(_lbl("CHARACTER JOURNALS", 14, Color(0.85, 0.72, 0.40)))
	parent.add_child(_lbl("Unlock journal entries by rescuing characters and completing levels", 11, Color(0.55, 0.50, 0.45)))
	if not _main: return
	# Show unlocked character journal entries
	for i in range(PORTRAIT_KEYS.size()):
		var pkey = PORTRAIT_KEYS[i]
		var cname = _main.character_names[i] if i < _main.character_names.size() else "?"
		var unlocked = false
		if i < _main.survivor_types.size():
			unlocked = _main._is_character_unlocked(_main.survivor_types[i])
		var entry = PanelContainer.new()
		var es = StyleBoxFlat.new()
		es.bg_color = Color(0.05, 0.03, 0.10, 0.5) if unlocked else Color(0.03, 0.02, 0.06, 0.3)
		es.set_corner_radius_all(8)
		es.border_color = Color(0.55, 0.42, 0.18, 0.4) if unlocked else Color(0.2, 0.18, 0.15, 0.3)
		es.set_border_width_all(1)
		es.content_margin_left = 10; es.content_margin_right = 10
		es.content_margin_top = 8; es.content_margin_bottom = 8
		entry.add_theme_stylebox_override("panel", es)
		entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.add_child(row)
		# Small portrait
		var port = TextureRect.new()
		port.custom_minimum_size = Vector2(48, 48)
		port.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		port.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		port.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _main._portrait_textures.has(pkey):
			port.texture = _main._portrait_textures[pkey]
			if not unlocked:
				port.modulate = Color(0.2, 0.2, 0.2)  # Silhouette
		row.add_child(port)
		# Text
		var text_col = VBoxContainer.new()
		text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(text_col)
		if unlocked:
			text_col.add_child(_lbl(cname, 14, Color(1, 0.92, 0.45)))
			if i < _main.character_quotes.size():
				var quote = _lbl('"' + _main.character_quotes[i] + '"', 10, Color(0.55, 0.50, 0.45))
				quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				quote.mouse_filter = Control.MOUSE_FILTER_IGNORE
				text_col.add_child(quote)
		else:
			text_col.add_child(_lbl("???", 14, Color(0.35, 0.30, 0.25)))
			text_col.add_child(_lbl("Rescue this character to unlock their journal", 10, Color(0.35, 0.30, 0.25)))
		parent.add_child(entry)

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
	# Credits / About section
	vb.add_child(_lbl("ABOUT", 16, Color(0.85, 0.72, 0.40)))
	var credits_panel = PanelContainer.new()
	var cps = StyleBoxFlat.new()
	cps.bg_color = Color(0.04, 0.03, 0.08, 0.5)
	cps.set_corner_radius_all(8)
	cps.content_margin_left = 16; cps.content_margin_right = 16
	cps.content_margin_top = 12; cps.content_margin_bottom = 12
	credits_panel.add_theme_stylebox_override("panel", cps)
	credits_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var credits_vb = VBoxContainer.new()
	credits_vb.add_theme_constant_override("separation", 6)
	credits_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	credits_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	credits_panel.add_child(credits_vb)
	credits_vb.add_child(_lbl("SHADOW DEFENSE: TALES FROM THE PAGES", 14, Color(1, 0.92, 0.45)))
	credits_vb.add_child(_lbl("A Literary Tower Defense Adventure", 11, Color(0.65, 0.55, 0.45)))
	credits_vb.add_child(_lbl("", 6, Color(0, 0, 0, 0)))  # Spacer
	credits_vb.add_child(_lbl("Created by Defense Planet", 12, Color(0.75, 0.68, 0.58)))
	credits_vb.add_child(_lbl("Art generated with nano-banana + Gemini", 10, Color(0.55, 0.50, 0.45)))
	credits_vb.add_child(_lbl("Built with Godot Engine 4.6", 10, Color(0.55, 0.50, 0.45)))
	credits_vb.add_child(_lbl("", 6, Color(0, 0, 0, 0)))  # Spacer
	credits_vb.add_child(_lbl("Version 0.9.0", 11, Color(0.65, 0.58, 0.50)))
	vb.add_child(credits_panel)

func _add_setting_row(parent: VBoxContainer, label: String, value: String, callback: Callable, is_volume: bool = false, volume_pct: float = 0.0) -> void:
	# Setting row with art-styled panel
	var row_panel = PanelContainer.new()
	var rps = StyleBoxFlat.new()
	rps.bg_color = Color(0.04, 0.03, 0.08, 0.4)
	rps.set_corner_radius_all(6)
	rps.content_margin_left = 12; rps.content_margin_right = 12
	rps.content_margin_top = 6; rps.content_margin_bottom = 6
	row_panel.add_theme_stylebox_override("panel", rps)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_panel.add_child(row)
	var nl = _lbl(label, 14, Color(0.85, 0.78, 0.65))
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(nl)
	# Volume slider bar visualization
	if is_volume:
		var bar_panel = PanelContainer.new()
		bar_panel.custom_minimum_size = Vector2(140, 20)
		bar_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bps = StyleBoxFlat.new()
		bps.bg_color = Color(0.06, 0.04, 0.10, 0.8)
		bps.set_corner_radius_all(4)
		bps.border_color = Color(0.25, 0.20, 0.15, 0.4)
		bps.set_border_width_all(1)
		bar_panel.add_theme_stylebox_override("panel", bps)
		row.add_child(bar_panel)
		var bar_fill = ColorRect.new()
		bar_fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
		bar_fill.offset_left = 2; bar_fill.offset_top = 2; bar_fill.offset_bottom = -2
		bar_fill.offset_right = -140 + (136 * volume_pct)
		bar_fill.color = Color(0.3, 0.75, 0.45, 0.9)
		bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar_panel.add_child(bar_fill)
	var btn = Button.new()
	btn.text = value
	btn.custom_minimum_size = Vector2(100, 32)
	var bs = StyleBoxFlat.new()
	# Color code ON/OFF with glow
	if value == "ON" or value.ends_with("%") or value == "AUTO" or value.begins_with("1") or value.begins_with("2") or value.begins_with("3"):
		bs.bg_color = Color(0.10, 0.30, 0.12, 0.85)
		bs.border_color = Color(0.2, 0.6, 0.25, 0.5)
	elif value == "OFF" or value == "NO" or value == "YES":
		bs.bg_color = Color(0.30, 0.10, 0.10, 0.85)
		bs.border_color = Color(0.6, 0.2, 0.2, 0.5)
	else:
		bs.bg_color = Color(0.12, 0.10, 0.22, 0.85)
		bs.border_color = Color(0.35, 0.28, 0.45, 0.5)
	bs.set_corner_radius_all(8)
	bs.set_border_width_all(1)
	bs.shadow_color = Color(0.1, 0.1, 0.1, 0.2)
	bs.shadow_size = 2
	bs.content_margin_left = 8; bs.content_margin_right = 8
	btn.add_theme_stylebox_override("normal", bs)
	var bsh = bs.duplicate(); bsh.bg_color = bs.bg_color.lightened(0.2)
	bsh.border_color = bs.border_color.lightened(0.2)
	btn.add_theme_stylebox_override("hover", bsh)
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	btn.add_theme_constant_override("shadow_offset_x", 1)
	btn.add_theme_constant_override("shadow_offset_y", 1)
	btn.pressed.connect(callback)
	_add_press_feedback(btn)
	row.add_child(btn)
	parent.add_child(row_panel)

# ======================== UTILITY ========================
func _title(text: String) -> Control:
	# Title with art header behind it
	var container = CenterContainer.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.custom_minimum_size = Vector2(0, 48)
	# Art background for title
	if _art.has("scroll_header"):
		var art_bg = TextureRect.new()
		art_bg.texture = _art["scroll_header"]
		art_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_bg.modulate.a = 0.6
		var mat = _make_black_key_mat(0.06, 0.04)
		if mat: art_bg.material = mat
		container.add_child(art_bg)
	var l = _lbl(text, 26, Color(1, 0.92, 0.45))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(l)
	return container

# Add press feedback to any button
func _add_press_feedback(btn: BaseButton) -> void:
	btn.button_down.connect(func():
		btn.pivot_offset = btn.size / 2.0
		var tw = btn.create_tween().set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.05))
	btn.button_up.connect(func():
		var tw = btn.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1))

func _lbl(text: String, size: int, color: Color) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0,0,0,0.85))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l

func _art_button(text: String, color: Color, min_size: Vector2 = Vector2(110, 32)) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(8)
	s.border_color = Color(color.r * 1.8, color.g * 1.8, color.b * 1.8, 0.6)
	s.set_border_width_all(1)
	s.shadow_color = Color(0, 0, 0, 0.2)
	s.shadow_size = 2
	s.content_margin_left = 8; s.content_margin_right = 8
	btn.add_theme_stylebox_override("normal", s)
	var sh = s.duplicate()
	sh.bg_color = color.lightened(0.2)
	sh.border_color = Color(color.r * 2.0, color.g * 2.0, color.b * 2.0, 0.7)
	btn.add_theme_stylebox_override("hover", sh)
	var sp = s.duplicate()
	sp.bg_color = color.darkened(0.15)
	sp.shadow_size = 0
	btn.add_theme_stylebox_override("pressed", sp)
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	btn.add_theme_constant_override("shadow_offset_x", 1)
	btn.add_theme_constant_override("shadow_offset_y", 1)
	_add_press_feedback(btn)
	return btn

func _format_num(val: float) -> String:
	if val >= 1000000: return "%.1fM" % (val / 1000000.0)
	if val >= 1000: return "%.1fK" % (val / 1000.0)
	return str(int(val))

func _fade_in() -> void:
	fade_rect.color = Color(0,0,0,1)
	var tw = create_tween()
	tw.tween_property(fade_rect, "color:a", 0.0, 0.3)
