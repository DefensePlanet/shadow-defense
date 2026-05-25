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
var _last_gold: int = 0
var _last_quills: int = 0
var _last_shards: int = 0
var _last_stars_currency: int = 0
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
# Bond pairs — characters that synergize when placed together
const BOND_PAIRS: Dictionary = {
	0: [6],      # Robin Hood ↔ Sherlock (both London)
	1: [2],      # Alice ↔ Wicked Witch (both fantasy realms)
	2: [1],      # Wicked Witch ↔ Alice
	3: [7],      # Peter Pan ↔ Tarzan (both wild/nature)
	4: [5],      # Phantom ↔ Scrooge (both haunted by ghosts)
	5: [4],      # Scrooge ↔ Phantom
	6: [0, 8],   # Sherlock ↔ Robin Hood, Dracula (detective vs villain)
	7: [3],      # Tarzan ↔ Peter Pan
	8: [6, 10],  # Dracula ↔ Sherlock, Frankenstein (classic monsters)
	9: [11],     # Merlin ↔ Shadow Author (both magic)
	10: [8],     # Frankenstein ↔ Dracula
	11: [9],     # Shadow Author ↔ Merlin
}

@onready var background: TextureRect = $Background
@onready var content_area: Control = $ContentArea
@onready var nav_buttons_container: HBoxContainer = $NavBar/NavButtons
@onready var top_bar: ColorRect = $TopBar
@onready var nav_bar: ColorRect = $NavBar
@onready var fade_rect: ColorRect = $FadeRect



# Phase 8: Ambient floating particles
var _particles: Array = []
const PARTICLE_COUNT: int = 25

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
	# First-time tutorial OR daily login reward
	get_tree().create_timer(1.5).timeout.connect(func():
		if _main:
			if _main.completed_levels.size() == 0:
				# First-time player tutorial
				_show_popup("Welcome, Reader!", "Welcome to Shadow Defense: Tales from the Pages!\n\nHeroes from classic novels fight to protect their stories from the Shadow Author.\n\nTap a level to begin your adventure!", "BEGIN")
			elif _main.completed_levels.size() == 3:
				# After 3 wins — rate prompt
				_show_popup("Enjoying the Adventure?", "You've completed 3 levels!\n\nIf you're enjoying Shadow Defense,\nplease rate us — it helps a lot!", "RATE US")
			else:
				# Returning player daily reward
				_show_popup("Welcome Back!", "Daily login bonus:\n+100 Gold  +10 Quills\n\nKeep playing to earn more!", "COLLECT"))
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
			"speed": randf_range(10, 30),
			"size": randf_range(2.0, 4.5),
			"alpha": randf_range(0.15, 0.45),
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
	# Parallax: offset background based on scroll
	for c in content_area.get_children():
		if c is ScrollContainer:
			var scroll_y = c.scroll_vertical
			background.position.y = -scroll_y * 0.05  # Subtle parallax
			break
	# Check for song change every 2 seconds
	_song_check_timer += delta
	if _song_check_timer >= 2.0:
		_song_check_timer = 0.0
		_update_song_display()
		# Check currency changes — flash the top bar
		if _main:
			var changed = false
			if _main.gold != _last_gold: changed = true; _last_gold = _main.gold
			if _main.player_quills != _last_quills: changed = true; _last_quills = _main.player_quills
			if _main.player_gear_shards != _last_shards: changed = true; _last_shards = _main.player_gear_shards
			if _main.player_storybook_stars != _last_stars_currency: changed = true; _last_stars_currency = _main.player_storybook_stars
			if changed:
				# Rebuild currency bar
				for c in top_bar.get_children(): c.queue_free()
				_build_currency_bar()
				_build_music_display()
				# Flash effect
				var flash = create_tween()
				flash.tween_property(top_bar, "modulate", Color(1.3, 1.2, 1.0), 0.15)
				flash.tween_property(top_bar, "modulate", Color.WHITE, 0.2)
	queue_redraw()

func _draw() -> void:
	# Floating particles with seasonal tint
	var month = Time.get_date_dict_from_system().get("month", 1)
	var particle_color = Color(0.85, 0.70, 0.40)  # Default gold
	if month == 12 or month == 1:  # Winter — snow white
		particle_color = Color(0.90, 0.92, 0.95)
	elif month == 10:  # Halloween — orange
		particle_color = Color(0.95, 0.60, 0.15)
	elif month >= 3 and month <= 5:  # Spring — pink/green
		particle_color = Color(0.85, 0.70, 0.75)
	for p in _particles:
		var flicker = p["alpha"] * (0.7 + sin(p["offset"] + p["y"] * 0.02) * 0.3)
		draw_circle(Vector2(p["x"], p["y"]), p["size"], Color(particle_color.r, particle_color.g, particle_color.b, flicker))
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
		top_bar.color = Color(0, 0, 0, 0)
	var h = HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override("separation", 8)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	top_bar.add_child(h)
	# Account level badge in styled panel
	var acct_lvl = _main.account_level if "account_level" in _main else 1
	var lvl_panel = _currency_chip("Lv.%d" % acct_lvl, Color(0.85, 0.75, 0.55))
	h.add_child(lvl_panel)
	# Each currency in its own styled chip
	for c in [["🪙", _main.gold, Color(1,0.85,0.2)], ["🪶", _main.player_quills, Color(0.7,0.5,0.9)], ["💎", _main.player_gear_shards, Color(0.3,0.75,0.9)], ["⭐", _main.player_storybook_stars, Color(1,0.9,0.3)]]:
		h.add_child(_currency_chip("%s %d" % [c[0], c[1]], c[2]))

func _currency_chip(text: String, color: Color) -> PanelContainer:
	var chip = PanelContainer.new()
	var cs = StyleBoxFlat.new()
	cs.bg_color = Color(0.05, 0.03, 0.10, 0.7)
	cs.set_corner_radius_all(12)
	cs.border_color = Color(color.r * 0.5, color.g * 0.5, color.b * 0.5, 0.4)
	cs.set_border_width_all(1)
	cs.content_margin_left = 10; cs.content_margin_right = 10
	cs.content_margin_top = 2; cs.content_margin_bottom = 2
	chip.add_theme_stylebox_override("panel", cs)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l = _lbl(text, 11, color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(l)
	return chip

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
	var tab_icons_text = ["📜", "⚔️", "🛒", "📖", "⚙️"]
	for i in range(5):
		var is_active = tabs[i] == current_view
		var btn = Button.new()
		btn.text = "%s\n%s" % [tab_icons_text[i], labels[i]]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 70)
		var s = StyleBoxFlat.new()
		if is_active:
			s.bg_color = Color(0.15, 0.10, 0.25, 0.8)
			s.border_color = Color(1.0, 0.80, 0.25, 0.9)
			s.border_width_top = 3
			s.border_width_left = 0; s.border_width_right = 0; s.border_width_bottom = 0
			s.shadow_color = Color(0.5, 0.35, 0.1, 0.2)
			s.shadow_size = 4
		else:
			s.bg_color = Color(0.06, 0.04, 0.10, 0.3)
			s.border_color = Color(0.25, 0.20, 0.15, 0.2)
			s.border_width_top = 1
			s.border_width_left = 0; s.border_width_right = 0; s.border_width_bottom = 0
		s.set_corner_radius_all(0)
		btn.add_theme_stylebox_override("normal", s)
		var sh = s.duplicate()
		sh.bg_color = Color(0.18, 0.12, 0.28, 0.6)
		sh.border_color = Color(0.80, 0.60, 0.20, 0.6)
		sh.border_width_top = 2
		btn.add_theme_stylebox_override("hover", sh)
		btn.add_theme_font_size_override("font_size", 12)
		btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.40) if is_active else Color(0.50, 0.45, 0.40))
		btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
		btn.add_theme_constant_override("shadow_offset_x", 1)
		btn.add_theme_constant_override("shadow_offset_y", 1)
		btn.pressed.connect(_on_tab.bind(tabs[i]))
		_add_press_feedback(btn)
		# Notification dot for tabs with unclaimed content
		var has_notification = false
		match tabs[i]:
			"emporium":
				if _main and "merchant_inventory" in _main and _main.merchant_inventory.size() > 0:
					has_notification = true
			"codex":
				# Check for unclaimed achievements
				if _main and "achievement_progress" in _main:
					for ak in _main.achievement_progress:
						var ap = _main.achievement_progress[ak]
						if ap is Dictionary and ap.get("completed", false) and not ap.get("claimed", true):
							has_notification = true
							break
		if has_notification:
			var dot = ColorRect.new()
			dot.custom_minimum_size = Vector2(8, 8)
			dot.color = Color(0.9, 0.15, 0.1)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			dot.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			dot.position = Vector2(-14, 6)
			btn.add_child(dot)
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
	# Page-turn transition: slide out left + fade, then rebuild + slide in right
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(content_area, "modulate:a", 0.0, 0.12)
	tw.tween_property(content_area, "position:x", -30.0, 0.12).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func():
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
		# Slide in from right + fade in
		content_area.position.x = 30.0
		var tw_in = create_tween()
		tw_in.set_parallel(true)
		tw_in.tween_property(content_area, "modulate:a", 1.0, 0.15)
		tw_in.tween_property(content_area, "position:x", 0.0, 0.15).set_ease(Tween.EASE_OUT))

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
	_add_scroll_hint(content_area)
	# Margin container for card breathing room
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 4)
	sc.add_child(margin)
	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 8)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vb)
	# Title in styled frame with entrance animation
	var title_panel = PanelContainer.new()
	var tps = StyleBoxFlat.new()
	tps.bg_color = Color(0.06, 0.04, 0.12, 0.7)
	tps.set_corner_radius_all(12)
	tps.border_color = Color(0.65, 0.50, 0.18, 0.5)
	tps.set_border_width_all(2)
	tps.shadow_color = Color(0.3, 0.2, 0.05, 0.2)
	tps.shadow_size = 5
	tps.content_margin_left = 40; tps.content_margin_right = 40
	tps.content_margin_top = 8; tps.content_margin_bottom = 8
	title_panel.add_theme_stylebox_override("panel", tps)
	title_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Art behind title
	if _art.has("scroll_header"):
		var ta = TextureRect.new()
		ta.texture = _art["scroll_header"]
		ta.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ta.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		ta.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ta.modulate.a = 0.3
		var mat = _make_black_key_mat(0.06, 0.04)
		if mat: ta.material = mat
		title_panel.add_child(ta)
	var title_vb = VBoxContainer.new()
	title_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	title_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_panel.add_child(title_vb)
	var main_title = _lbl("SHADOW DEFENSE", 26, Color(1.0, 0.92, 0.40))
	main_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_vb.add_child(main_title)
	var subtitle = _lbl("Tales from the Pages", 12, Color(0.70, 0.60, 0.48))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_vb.add_child(subtitle)
	# Entrance animation
	title_panel.modulate.a = 0.0
	title_panel.scale = Vector2(0.9, 0.9)
	title_panel.pivot_offset = Vector2(200, 25)
	var title_tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	title_tw.set_parallel(true)
	title_tw.tween_property(title_panel, "scale", Vector2(1.0, 1.0), 0.35)
	title_tw.tween_property(title_panel, "modulate:a", 1.0, 0.2)
	vb.add_child(title_panel)
	# Shadow Author rotating quote
	var sa_quotes = [
		"Heroes pulled from their stories. One Author controls them all.",
		"Every page I turn reveals another world to consume...",
		"They think they're the heroes. How charming.",
		"The ink is drying, and with it, their hope.",
		"I wrote their endings before they even began.",
		"Come, little characters. The final chapter awaits.",
		"The pen is mightier than the sword. I have both.",
	]
	var quote_text = sa_quotes[randi() % sa_quotes.size()]
	var tagline = _lbl('"%s"' % quote_text, 12, Color(0.65, 0.55, 0.45))
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tagline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(tagline)
	var sa_attr = _lbl("— The Shadow Author", 10, Color(0.50, 0.42, 0.38))
	sa_attr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sa_attr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(sa_attr)
	if not _main: return
	# "Previously on..." story recap for returning players
	if _main.completed_levels.size() > 0:
		var last_level = 0
		for cl in _main.completed_levels:
			if cl > last_level: last_level = cl
		var last_name = _main.levels[last_level].get("name", "") if last_level < _main.levels.size() else ""
		var recap_panel = PanelContainer.new()
		var rps = StyleBoxFlat.new()
		rps.bg_color = Color(0.04, 0.03, 0.08, 0.5)
		rps.set_corner_radius_all(8)
		rps.border_color = Color(0.55, 0.42, 0.18, 0.3)
		rps.set_border_width_all(1)
		rps.content_margin_left = 16; rps.content_margin_right = 16
		rps.content_margin_top = 6; rps.content_margin_bottom = 6
		recap_panel.add_theme_stylebox_override("panel", rps)
		recap_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var recap_vb = VBoxContainer.new()
		recap_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		recap_panel.add_child(recap_vb)
		var recap_title = _lbl("Previously on Shadow Defense...", 11, Color(0.65, 0.55, 0.45))
		recap_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		recap_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		recap_vb.add_child(recap_title)
		var recap_text = _lbl("You completed \"%s\" — %d levels cleared, %d characters rescued" % [last_name, _main.completed_levels.size(), 0], 10, Color(0.55, 0.48, 0.42))
		recap_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		recap_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		recap_vb.add_child(recap_text)
		# Count rescued
		var r_count = 0
		for st in _main.survivor_types:
			if _main._is_character_unlocked(st): r_count += 1
		recap_text.text = "You completed \"%s\" — %d levels cleared, %d characters rescued" % [last_name, _main.completed_levels.size(), r_count]
		vb.add_child(recap_panel)
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
	var star_text = _lbl("%d / %d Stars" % [total_stars, max_stars], 14, Color(1.0, 0.85, 0.25))
	star_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star_bar.add_child(star_text)
	# Completion bar
	var comp_pct = float(total_stars) / float(max_stars) if max_stars > 0 else 0.0
	var comp_bar = _stat_bar("Progress", total_stars, max_stars, Color(1.0, 0.85, 0.25))
	comp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(star_bar)
	vb.add_child(comp_bar)
	# Quest streak display
	if "quest_streak" in _main and _main.quest_streak > 0:
		var streak_row = HBoxContainer.new()
		streak_row.alignment = BoxContainer.ALIGNMENT_CENTER
		streak_row.add_theme_constant_override("separation", 6)
		streak_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		streak_row.add_child(_lbl("🔥 %d Day Streak" % _main.quest_streak, 12, Color(1.0, 0.6, 0.2)))
		vb.add_child(streak_row)
	# Comeback bonus display
	if "_comeback_bonus_active" in _main and _main._comeback_bonus_active:
		var comeback_lbl = _lbl("⚡ %.0fx Comeback Bonus Active!" % _main._comeback_multiplier, 12, Color(0.4, 0.9, 1.0))
		comeback_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		comeback_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(comeback_lbl)
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
			# Arc completion count
			var arc_total = 0
			var arc_done = 0
			for li in range(_main.levels.size()):
				var lsub = _main.levels[li].get("subtitle", "")
				var larc = lsub.split(" — ")[0] if " — " in lsub else "Prologue"
				if larc == "" : larc = "Prologue"
				if larc == arc:
					arc_total += 1
					if li in _main.completed_levels:
						arc_done += 1
			if arc_total > 0:
				var pct_lbl = _lbl("%d / %d completed" % [arc_done, arc_total], 10, Color(0.55, 0.48, 0.42))
				pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				pct_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				vb.add_child(pct_lbl)
		# Connecting path line between levels
		if card_idx > 0:
			var path_line = ColorRect.new()
			path_line.custom_minimum_size = Vector2(2, 12)
			path_line.color = Color(0.55, 0.42, 0.18, 0.4)
			path_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			path_line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			vb.add_child(path_line)
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
	var is_boss = (idx + 1) % 3 == 0 and idx > 0
	var p = PanelContainer.new()
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.04, 0.03, 0.10, 0.78) if unlocked else Color(0.03, 0.02, 0.06, 0.65)
	if complete:
		s.border_color = Color(0.35, 0.70, 0.30, 0.7)
		s.set_border_width_all(2)
	elif is_boss:
		s.border_color = Color(0.70, 0.25, 0.15, 0.6)
		s.set_border_width_all(2)
	else:
		s.border_color = Color(0.40, 0.30, 0.18, 0.35)
		s.set_border_width_all(1)
	s.set_corner_radius_all(10)
	s.shadow_color = Color(0, 0, 0, 0.15)
	s.shadow_size = 3
	s.content_margin_left = 12; s.content_margin_right = 12; s.content_margin_top = 8; s.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	# Tooltip — boss levels get villain taunts
	if is_boss:
		var taunts = [
			"Think you can survive MY chapter? Adorable.",
			"The ink runs red in this one...",
			"I wrote your defeat on page one.",
			"This is where heroes come to be erased.",
			"My finest creation awaits you here.",
		]
		p.tooltip_text = taunts[idx % taunts.size()]
	else:
		var story = lvl.get("story_hook", lvl.get("subtitle", ""))
		if story != "":
			p.tooltip_text = story
	# Hover feedback — subtle scale + brighten
	p.mouse_entered.connect(func():
		p.pivot_offset = p.size / 2.0
		var tw = p.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.set_parallel(true)
		tw.tween_property(p, "scale", Vector2(1.01, 1.01), 0.1)
		tw.tween_property(p, "modulate", Color(1.12, 1.10, 1.05), 0.1))
	p.mouse_exited.connect(func():
		var tw = p.create_tween().set_ease(Tween.EASE_OUT)
		tw.set_parallel(true)
		tw.tween_property(p, "scale", Vector2(1.0, 1.0), 0.08)
		tw.tween_property(p, "modulate", Color.WHITE, 0.08))
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	# Level number in styled circle
	var num_circle = PanelContainer.new()
	var ncs = StyleBoxFlat.new()
	ncs.set_corner_radius_all(20)
	ncs.content_margin_left = 4; ncs.content_margin_right = 4
	ncs.content_margin_top = 4; ncs.content_margin_bottom = 4
	if complete:
		ncs.bg_color = Color(0.15, 0.40, 0.15, 0.85)
		ncs.border_color = Color(0.3, 0.7, 0.3, 0.6)
	elif is_boss:
		ncs.bg_color = Color(0.40, 0.10, 0.08, 0.85)
		ncs.border_color = Color(0.8, 0.25, 0.15, 0.6)
	elif unlocked:
		ncs.bg_color = Color(0.12, 0.08, 0.20, 0.85)
		ncs.border_color = Color(0.65, 0.50, 0.20, 0.5)
	else:
		ncs.bg_color = Color(0.05, 0.04, 0.08, 0.6)
		ncs.border_color = Color(0.25, 0.20, 0.15, 0.3)
	ncs.set_border_width_all(2)
	num_circle.add_theme_stylebox_override("panel", ncs)
	num_circle.custom_minimum_size = Vector2(40, 40)
	num_circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var num_lbl = _lbl(str(idx+1), 16, Color(1.0, 0.92, 0.40) if unlocked else Color(0.35, 0.30, 0.25))
	num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	num_circle.add_child(num_lbl)
	row.add_child(num_circle)
	# Thumbnail
	# Thumbnail — larger with rounded clip panel
	var th_panel = PanelContainer.new()
	var ths = StyleBoxFlat.new()
	ths.bg_color = Color(0.02, 0.01, 0.05, 0.5)
	ths.set_corner_radius_all(8)
	ths.set_border_width_all(1)
	ths.border_color = Color(0.35, 0.25, 0.15, 0.3)
	th_panel.add_theme_stylebox_override("panel", ths)
	th_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th = TextureRect.new()
	th.custom_minimum_size = Vector2(120, 75)
	th.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	th.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	th.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _main._map_thumb_textures.has(idx): th.texture = _main._map_thumb_textures[idx]
	th_panel.add_child(th)
	row.add_child(th_panel)
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_row = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n = _lbl(lvl.get("name",""), 16, Color(1, 0.95, 0.85) if unlocked else Color(0.45, 0.40, 0.35))
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
		# Pulse the NEW badge
		var new_tw = create_tween().set_loops()
		new_tw.tween_property(new_badge, "modulate:a", 0.5, 0.5).set_ease(Tween.EASE_IN_OUT)
		new_tw.tween_property(new_badge, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_IN_OUT)
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
	var st = _lbl(lvl.get("subtitle",""), 11, Color(0.60, 0.52, 0.45))
	st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(st)
	# Stats row with wave/gold/lives
	var stats_row = HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 10)
	stats_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stats = _lbl("⚔ %d Waves  •  🪙 %d Gold  •  ❤ %d Lives" % [lvl.get("waves",20), lvl.get("gold",100), lvl.get("lives",20)], 10, Color(0.50, 0.45, 0.40))
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_row.add_child(stats)
	# Difficulty medals + best wave for completed levels
	if complete:
		var medal_colors = [Color(0.72, 0.45, 0.20), Color(0.70, 0.70, 0.75), Color(1.0, 0.85, 0.15)]
		var medals_row = HBoxContainer.new()
		medals_row.add_theme_constant_override("separation", 3)
		medals_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Real difficulty medals from game data
		var diff_medals = _main.level_difficulty_medals.get(idx, [false, false, false]) if "level_difficulty_medals" in _main else [false, false, false]
		for mi in range(3):
			var earned = diff_medals[mi] if mi < diff_medals.size() else false
			var medal = _lbl("●", 12, medal_colors[mi] if earned else Color(0.25, 0.22, 0.20, 0.4))
			medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
			medal.tooltip_text = ["Easy", "Medium", "Hard"][mi] + (" ✓" if earned else "")
			medals_row.add_child(medal)
		stats_row.add_child(medals_row)
	# Best wave record
	if "level_best_wave" in _main and _main.level_best_wave.has(idx):
		var bw = _main.level_best_wave[idx]
		stats_row.add_child(_lbl("Best: W%d" % bw, 9, Color(0.55, 0.48, 0.42)))
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
				star.custom_minimum_size = Vector2(20, 20)
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
	# Per-difficulty star counts
	if "level_difficulty_stars" in _main and _main.level_difficulty_stars.has(idx):
		var ds = _main.level_difficulty_stars[idx]
		var diff_names = ["E", "M", "H"]
		var diff_row = HBoxContainer.new()
		diff_row.add_theme_constant_override("separation", 6)
		diff_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for di in range(mini(ds.size(), 3)):
			if ds[di] > 0:
				diff_row.add_child(_lbl("%s:%d★" % [diff_names[di], ds[di]], 8, Color(0.55, 0.48, 0.42)))
		if diff_row.get_child_count() > 0:
			info.add_child(diff_row)
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
	var sub = _lbl("%d / %d Rescued" % [unlocked_ct, _main.survivor_types.size()], 13, Color(0.65, 0.58, 0.50))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(sub)
	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
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
	# Style based on unlock status + level-based rarity border
	var char_level = 1
	if is_unlocked and tt != null and _main.survivor_progress.has(tt):
		char_level = _main.survivor_progress[tt].get("level", 1)
	var rarity_border = Color(0.45, 0.35, 0.20, 0.5)  # Default brown
	if char_level >= 8: rarity_border = Color(1.0, 0.7, 0.1, 0.8)   # Gold
	elif char_level >= 5: rarity_border = Color(0.6, 0.3, 0.9, 0.7)  # Purple/Epic
	elif char_level >= 3: rarity_border = Color(0.2, 0.5, 0.9, 0.6)  # Blue/Rare
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.04, 0.12, 0.75) if is_unlocked else Color(0.03, 0.02, 0.06, 0.55)
	s.border_color = rarity_border if is_unlocked else Color(0.20, 0.18, 0.15, 0.3)
	s.set_border_width_all(2); s.set_corner_radius_all(10)
	s.shadow_color = Color(0, 0, 0, 0.2)
	s.shadow_size = 4
	s.content_margin_left = 6; s.content_margin_right = 6
	s.content_margin_top = 6; s.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", s)
	var sh = s.duplicate()
	sh.bg_color = Color(0.10, 0.07, 0.18, 0.85) if is_unlocked else Color(0.05, 0.03, 0.10, 0.65)
	sh.border_color = Color(0.80, 0.60, 0.25, 0.9) if is_unlocked else Color(0.35, 0.28, 0.18, 0.5)
	sh.shadow_size = 6
	btn.add_theme_stylebox_override("hover", sh)
	var sp = s.duplicate()
	sp.bg_color = Color(0.12, 0.08, 0.20, 0.9)
	sp.shadow_size = 2
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
		frame_art.modulate.a = 0.25  # Subtle frame overlay — don't obscure portrait
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
			port.modulate = Color(0.15, 0.12, 0.20)  # Visible dark silhouette
	vb.add_child(port)
	# Name — show "???" for locked
	var cname = _main.character_names[idx] if _main and idx < _main.character_names.size() else "?"
	var display_name = cname.to_upper() if is_unlocked else "???"
	var nl = _lbl(display_name, 13, Color(1, 0.92, 0.45) if is_unlocked else Color(0.35, 0.30, 0.25))
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(nl)
	# Locked indicator
	if not is_unlocked:
		var lock_lbl = _lbl("🔒 LOCKED", 11, Color(0.45, 0.38, 0.32))
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(lock_lbl)
	var ctitle = _main.character_titles[idx] if _main and idx < _main.character_titles.size() else ""
	var tl = _lbl(ctitle if is_unlocked else "", 9, Color(0.55, 0.48, 0.42))
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(tl)
	# Level badge with mastery title (only for unlocked)
	if is_unlocked and tt != null and _main.survivor_progress.has(tt):
		var lvl = _main.survivor_progress[tt].get("level", 1)
		var mastery = "Novice"
		if lvl >= 10: mastery = "Legend"
		elif lvl >= 8: mastery = "Master"
		elif lvl >= 6: mastery = "Expert"
		elif lvl >= 4: mastery = "Veteran"
		elif lvl >= 2: mastery = "Adept"
		var mastery_col = Color(0.55, 0.48, 0.42)
		if lvl >= 8: mastery_col = Color(1.0, 0.7, 0.1)
		elif lvl >= 6: mastery_col = Color(0.6, 0.3, 0.9)
		elif lvl >= 4: mastery_col = Color(0.2, 0.5, 0.9)
		var badge = _lbl("Lv.%d — %s" % [lvl, mastery], 10, mastery_col)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(badge)
	# Source novel (only for unlocked)
	if is_unlocked and _main and idx < _main.character_novels.size():
		var novel = _lbl(_main.character_novels[idx], 9, Color(0.48, 0.42, 0.38))
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
	# LEFT: Large portrait in styled frame
	var left = VBoxContainer.new()
	left.custom_minimum_size = Vector2(350, 0)
	left.add_theme_constant_override("separation", 8)
	main_hbox.add_child(left)
	var port_frame = PanelContainer.new()
	var pfs = StyleBoxFlat.new()
	pfs.bg_color = Color(0.04, 0.03, 0.08, 0.5)
	pfs.set_corner_radius_all(12)
	pfs.border_color = Color(0.55, 0.42, 0.18, 0.5)
	pfs.set_border_width_all(2)
	pfs.shadow_color = Color(0, 0, 0, 0.2)
	pfs.shadow_size = 5
	pfs.content_margin_left = 8; pfs.content_margin_right = 8
	pfs.content_margin_top = 8; pfs.content_margin_bottom = 8
	port_frame.add_theme_stylebox_override("panel", pfs)
	port_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var port = TextureRect.new()
	port.custom_minimum_size = Vector2(320, 350)
	port.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	port.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	port.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pkey = PORTRAIT_KEYS[idx]
	if _main and _main._portrait_textures.has(pkey): port.texture = _main._portrait_textures[pkey]
	port_frame.add_child(port)
	left.add_child(port_frame)
	# Idle breathing animation on portrait
	var breathe_tw = create_tween().set_loops()
	breathe_tw.tween_property(port, "position:y", -3.0, 1.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	breathe_tw.tween_property(port, "position:y", 0.0, 1.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	var name = _main.character_names[idx] if _main else "?"
	left.add_child(_lbl(name.to_upper(), 22, Color(1,0.92,0.45)))
	var title = _main.character_titles[idx] if _main and idx < _main.character_titles.size() else ""
	left.add_child(_lbl(title, 13, Color(0.65,0.55,0.45)))
	# Quote in styled speech bubble
	if _main and idx < _main.character_quotes.size():
		var bubble = PanelContainer.new()
		var bbs = StyleBoxFlat.new()
		bbs.bg_color = Color(0.06, 0.04, 0.12, 0.6)
		bbs.set_corner_radius_all(10)
		bbs.border_color = Color(0.45, 0.35, 0.20, 0.35)
		bbs.set_border_width_all(1)
		bbs.content_margin_left = 12; bbs.content_margin_right = 12
		bbs.content_margin_top = 8; bbs.content_margin_bottom = 8
		bubble.add_theme_stylebox_override("panel", bbs)
		bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var q = _lbl('"' + _main.character_quotes[idx] + '"', 11, Color(0.65, 0.58, 0.50))
		q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		q.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bubble.add_child(q)
		# Animate in
		bubble.modulate.a = 0.0
		left.add_child(bubble)
		var qtw = create_tween().set_ease(Tween.EASE_OUT)
		qtw.tween_property(bubble, "modulate:a", 1.0, 0.4).set_delay(0.3)
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
		tb.custom_minimum_size = Vector2(0, 32)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	right.add_child(_section_header("CHARACTER LEVEL"))
	if tt != null and _main.survivor_progress.has(tt):
		var prog = _main.survivor_progress[tt]
		var level = prog.get("level", 1)
		var xp = prog.get("xp", 0)
		var next_xp = _main.HERO_XP_TABLE[mini(level - 1, _main.HERO_XP_TABLE.size() - 1)] if level <= _main.MAX_SURVIVOR_LEVEL else 0
		# Level + prestige stars
		var star_count = clampi(level / 2, 0, 5)
		var level_row = HBoxContainer.new()
		level_row.add_theme_constant_override("separation", 6)
		level_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		level_row.add_child(_lbl("Level %d" % level, 18, Color(1.0, 0.92, 0.45)))
		# Prestige stars
		if star_count > 0:
			for _si in range(star_count):
				var star = _lbl("★", 14, Color(1.0, 0.85, 0.15))
				star.mouse_filter = Control.MOUSE_FILTER_IGNORE
				level_row.add_child(star)
		right.add_child(level_row)
		if next_xp > 0:
			right.add_child(_stat_bar("XP", xp, next_xp, Color(0.3, 0.8, 0.4)))
			right.add_child(_lbl("%d / %d XP to Level %d" % [xp, next_xp, level + 1], 9, Color(0.50, 0.45, 0.40)))
		elif level >= _main.MAX_SURVIVOR_LEVEL:
			right.add_child(_lbl("MAX LEVEL", 12, Color(1.0, 0.85, 0.15)))
		# Total damage dealt
		var total_dmg = prog.get("total_damage", 0.0)
		if total_dmg > 0:
			right.add_child(_lbl("Total Damage: %s" % _format_num(total_dmg), 10, Color(0.6, 0.5, 0.45)))
	else:
		right.add_child(_lbl("Level 1", 18, Color(1.0, 0.92, 0.45)))
	# === TAB 0: STATS ===
	if _detail_tab == 0:
		right.add_child(_section_header("COMBAT STATS"))
	if tt != null and _main.tower_info.has(tt):
		var info = _main.tower_info[tt]
		right.add_child(_stat_bar("Damage", info.get("damage", 0), 50, Color(0.9,0.3,0.2)))
		right.add_child(_stat_bar("Range", info.get("range", 0), 200, Color(0.3,0.7,0.9)))
		right.add_child(_stat_bar("Fire Rate", info.get("fire_rate", 0), 2.5, Color(0.9,0.7,0.2)))
		# DPS calculation
		var dmg = info.get("damage", 0)
		var rate = info.get("fire_rate", 1.0)
		var dps = dmg * rate if rate > 0 else 0
		right.add_child(_lbl("DPS: %.1f  |  Cost: %d Gold" % [dps, info.get("cost", 0)], 12, Color(0.85, 0.70, 0.20)))
	# === TAB 1: GEAR ===
	if _detail_tab == 0 or _detail_tab == 1:
		right.add_child(_section_header("EQUIPPED GEAR"))
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
		# Equip gear button
		if _detail_tab == 1:
			var equip_btn = _art_button("CHANGE GEAR", Color(0.12, 0.35, 0.15), Vector2(140, 34))
			equip_btn.pressed.connect(func(): _open_gear_picker(idx, tt))
			right.add_child(equip_btn)
	# === TAB 2: ALLIES ===
	if _detail_tab == 0 or _detail_tab == 2:
		# Bond pairs
		if BOND_PAIRS.has(idx):
			right.add_child(_section_header("BOND SYNERGIES"))
			var bond_row = HBoxContainer.new()
			bond_row.add_theme_constant_override("separation", 8)
			bond_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			for bi in BOND_PAIRS[idx]:
				if bi < _main.character_names.size():
					var bond_panel = PanelContainer.new()
					var bps = StyleBoxFlat.new()
					bps.bg_color = Color(0.06, 0.04, 0.12, 0.5)
					bps.set_corner_radius_all(6)
					bps.border_color = Color(0.8, 0.5, 0.2, 0.4)
					bps.set_border_width_all(1)
					bps.content_margin_left = 8; bps.content_margin_right = 8
					bps.content_margin_top = 4; bps.content_margin_bottom = 4
					bond_panel.add_theme_stylebox_override("panel", bps)
					bond_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
					var br = HBoxContainer.new()
					br.add_theme_constant_override("separation", 6)
					br.mouse_filter = Control.MOUSE_FILTER_IGNORE
					bond_panel.add_child(br)
					# Small portrait
					var bport = TextureRect.new()
					bport.custom_minimum_size = Vector2(28, 28)
					bport.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					bport.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					bport.mouse_filter = Control.MOUSE_FILTER_IGNORE
					var bpkey = PORTRAIT_KEYS[bi]
					if _main._portrait_textures.has(bpkey):
						bport.texture = _main._portrait_textures[bpkey]
					br.add_child(bport)
					br.add_child(_lbl(_main.character_names[bi], 10, Color(0.9, 0.75, 0.4)))
					bond_row.add_child(bond_panel)
			right.add_child(bond_row)
		right.add_child(_section_header("SIDEKICKS"))
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
		right.add_child(_section_header("ABILITIES"))
	# Get tower script to read ability names
	var tower_scenes_map = {0: "robin_hood", 1: "alice", 2: "wicked_witch", 3: "peter_pan", 4: "phantom", 5: "scrooge", 6: "sherlock", 7: "tarzan", 8: "dracula", 9: "merlin", 10: "frankenstein", 11: "shadow_author"}
	var tower_key = tower_scenes_map.get(idx, "")
	# Try to get ability names from the tower script constants
	var all_abilities = {
		"robin_hood": ["Sherwood Aim", "Lincoln Green", "Merry Men", "Friar Tuck's Blessing", "Little John's Staff", "The Outlaw's Snare", "Maid Marian's Arrow", "The Golden Arrow", "King of Sherwood"],
		"alice": ["Eat Me Cake", "Cheshire Cat", "Mad Tea Party", "Queen's Flamingo", "Looking Glass", "Wonderland Logic", "Vorpal Blade", "Jabberwock's Fury", "Queen of Wonderland"],
		"wicked_witch": ["Winged Monkeys", "Emerald Blast", "Poppy Field", "Flying Broom", "Crystal Ball", "Tornado Fury", "Ruby Slippers Curse", "Oz's Wrath", "Wicked Dominion"],
		"peter_pan": ["Fairy Dust", "Lost Boys Rally", "Tick-Tock Croc", "Shadow Strike", "Never Grow Up", "Tinker Bell's Light", "Captain's Hook", "Neverland Flight", "Eternal Youth"],
		"phantom": ["Organ Blast", "Masquerade", "Chandelier Drop", "Underground Lake", "Christine's Song", "Music of Night", "Mirror Shatter", "Phantom's Rage", "Opera Ghost"],
		"scrooge": ["Coin Toss", "Ghost of Past", "Ghost of Present", "Ghost of Future", "Bah Humbug", "Tiny Tim's Hope", "Chain Rattle", "Redemption", "Christmas Spirit"],
		"sherlock": ["Deduction", "Watson's Aid", "Pipe Smoke", "Magnifying Glass", "Baker Street Irregular", "The Game's Afoot", "Moriarty's Trap", "Final Problem", "Master Detective"],
		"tarzan": ["Jungle Call", "Vine Swing", "Ape Strength", "Elephant Stampede", "Jane's Courage", "Jungle Drums", "Sabor's Claw", "Tree Top Assault", "Lord of the Jungle"],
		"dracula": ["Blood Drain", "Bat Swarm", "Hypnotic Gaze", "Mist Form", "Castle Rampart", "Night Hunter", "Stake Reversal", "Coffin Surge", "Prince of Darkness"],
		"frankenstein": ["Lightning Bolt", "Monster's Rage", "Bride's Kiss", "Chain Break", "Fire Fear", "Igor's Help", "Galvanic Surge", "Undying Will", "Creator's Remorse"],
		"shadow_author": ["Ink Splash", "Page Turn", "Plot Twist", "Character Summon", "Story Rewrite", "Chapter End", "Bookmark Shield", "Narrative Control", "The Final Page"],
	}
	var ability_names = all_abilities.get(tower_key, [])
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

func _open_gear_picker(char_idx: int, tower_type) -> void:
	_clear()
	var sc = ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_area.add_child(sc)
	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 8)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sc.add_child(vb)
	var back = _art_button("< BACK", Color(0.12, 0.10, 0.22), Vector2(90, 30))
	back.pressed.connect(func(): _detail_idx = char_idx; _detail_tab = 1; _build_detail_view())
	vb.add_child(back)
	vb.add_child(_title("SELECT GEAR"))
	var cname = _main.character_names[char_idx] if _main and char_idx < _main.character_names.size() else "?"
	vb.add_child(_lbl("Equipping: %s" % cname, 12, Color(0.65, 0.58, 0.50)))
	# Current gear
	if tower_type != null and _main.survivor_gear.has(tower_type):
		var cur = _main.survivor_gear[tower_type]
		vb.add_child(_lbl("Currently Equipped: %s" % cur.get("name", "None"), 13, Color(1, 0.85, 0.3)))
	# Show all available gear as a grid
	vb.add_child(_lbl("AVAILABLE GEAR", 14, Color(0.85, 0.72, 0.40)))
	var grid = GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(grid)
	if not _main: return
	var keys = _main._gear_icon_textures.keys()
	keys.sort()
	for gk in keys:
		var card = Button.new()
		card.custom_minimum_size = Vector2(100, 110)
		card.text = ""
		var cs = StyleBoxFlat.new()
		cs.bg_color = Color(0.05, 0.03, 0.10, 0.6)
		cs.border_color = Color(0.45, 0.35, 0.20, 0.4)
		cs.set_border_width_all(1)
		cs.set_corner_radius_all(8)
		cs.content_margin_left = 4; cs.content_margin_right = 4
		cs.content_margin_top = 4; cs.content_margin_bottom = 4
		card.add_theme_stylebox_override("normal", cs)
		var csh = cs.duplicate()
		csh.bg_color = Color(0.10, 0.07, 0.18, 0.8)
		csh.border_color = Color(0.65, 0.50, 0.20, 0.7)
		card.add_theme_stylebox_override("hover", csh)
		_add_press_feedback(card)
		var cv = VBoxContainer.new()
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(cv)
		var icon = TextureRect.new()
		icon.texture = _main._gear_icon_textures[gk]
		icon.custom_minimum_size = Vector2(64, 64)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(icon)
		var name_lbl = _lbl(gk.replace("_", " ").capitalize(), 8, Color(0.65, 0.58, 0.50))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.clip_text = true
		name_lbl.custom_minimum_size.x = 90
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(name_lbl)
		grid.add_child(card)

func _show_popup(title: String, message: String, confirm_text: String = "OK", on_confirm: Callable = Callable()) -> void:
	# Dark overlay
	var overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	# Popup panel
	var popup = PanelContainer.new()
	popup.custom_minimum_size = Vector2(400, 200)
	popup.size = Vector2(400, 200)
	popup.position = Vector2(440, 260)
	var pps = StyleBoxFlat.new()
	pps.bg_color = Color(0.08, 0.06, 0.15, 0.95)
	pps.set_corner_radius_all(12)
	pps.border_color = Color(0.65, 0.50, 0.20, 0.6)
	pps.set_border_width_all(2)
	pps.shadow_color = Color(0, 0, 0, 0.4)
	pps.shadow_size = 8
	pps.content_margin_left = 24; pps.content_margin_right = 24
	pps.content_margin_top = 20; pps.content_margin_bottom = 20
	popup.add_theme_stylebox_override("panel", pps)
	# Art frame behind popup
	if _art.has("popup_frame"):
		var pa = TextureRect.new()
		pa.texture = _art["popup_frame"]
		pa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pa.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pa.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pa.modulate.a = 0.25
		var mat = _make_black_key_mat(0.06, 0.04)
		if mat: pa.material = mat
		popup.add_child(pa)
	var pvb = VBoxContainer.new()
	pvb.add_theme_constant_override("separation", 12)
	pvb.alignment = BoxContainer.ALIGNMENT_CENTER
	popup.add_child(pvb)
	pvb.add_child(_lbl(title, 18, Color(1, 0.92, 0.45)))
	var msg = _lbl(message, 12, Color(0.70, 0.65, 0.55))
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pvb.add_child(msg)
	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	pvb.add_child(btn_row)
	if on_confirm.is_valid():
		var yes = _art_button(confirm_text, Color(0.12, 0.40, 0.12), Vector2(120, 34))
		yes.pressed.connect(func(): overlay.queue_free(); on_confirm.call())
		btn_row.add_child(yes)
	var no = _art_button("CANCEL" if on_confirm.is_valid() else "OK", Color(0.35, 0.12, 0.12), Vector2(120, 34))
	no.pressed.connect(func(): overlay.queue_free())
	btn_row.add_child(no)
	overlay.add_child(popup)
	# Entrance animation
	popup.modulate.a = 0.0
	popup.scale = Vector2(0.9, 0.9)
	popup.pivot_offset = popup.custom_minimum_size / 2.0
	var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.set_parallel(true)
	tw.tween_property(popup, "scale", Vector2(1.0, 1.0), 0.2)
	tw.tween_property(popup, "modulate:a", 1.0, 0.15)

func _stat_bar(label: String, value: float, max_val: float, color: Color) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nl = _lbl(label, 12, Color(0.75, 0.68, 0.58))
	nl.custom_minimum_size.x = 90
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(nl)
	# Bar background with rounded corners
	var bar_panel = PanelContainer.new()
	bar_panel.custom_minimum_size = Vector2(200, 18)
	bar_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar_style = StyleBoxFlat.new()
	bar_style.bg_color = Color(0.04, 0.03, 0.08, 0.85)
	bar_style.set_corner_radius_all(6)
	bar_style.border_color = Color(0.28, 0.22, 0.15, 0.4)
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
	# Shop rotation timer
	var hours_left = 24 - (Time.get_ticks_msec() / 3600000) % 24
	var timer_lbl = _lbl("🕐 Shop refreshes in %dh" % hours_left, 10, Color(0.55, 0.48, 0.42))
	timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(timer_lbl)
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
		var deals_center = CenterContainer.new()
		deals_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		deals_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var deals_lbl = _lbl("✨ DAILY DEALS ✨", 16, Color(1, 0.85, 0.3))
		deals_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		deals_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		deals_center.add_child(deals_lbl)
		deals_panel.add_child(deals_center)
		# Pulsing glow animation on deals banner
		var deals_tw = create_tween().set_loops()
		deals_tw.tween_property(deals_panel, "modulate", Color(1.15, 1.1, 1.0), 1.0).set_ease(Tween.EASE_IN_OUT)
		deals_tw.tween_property(deals_panel, "modulate", Color(1.0, 1.0, 1.0), 1.0).set_ease(Tween.EASE_IN_OUT)
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
		# Styled card with accent color left stripe + shadow
		var s = StyleBoxFlat.new()
		s.bg_color = Color(0.05, 0.03, 0.10, 0.55)
		s.border_color = Color(accent.r * 0.5, accent.g * 0.5, accent.b * 0.5, 0.5)
		s.border_width_left = 4
		s.border_width_right = 1; s.border_width_top = 1; s.border_width_bottom = 1
		s.set_corner_radius_all(10)
		s.shadow_color = Color(0, 0, 0, 0.15)
		s.shadow_size = 3
		s.content_margin_left = 12; s.content_margin_right = 12
		s.content_margin_top = 10; s.content_margin_bottom = 10
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
			card_art.modulate.a = 0.2  # Very subtle — texture hint only
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
		var name_lbl = _lbl(cat.get("name",""), 14, accent)
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
		# Add item count hint
		var item_ct = _lbl("▸", 12, Color(0.45, 0.40, 0.35))
		item_ct.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(item_ct)
		# Glow animation for cards with badges
		var badge_val = cat.get("badge", "")
		if badge_val == "SALE!" or badge_val == "NEW!" or badge_val == "FREE!":
			var glow_tw = create_tween().set_loops()
			glow_tw.tween_property(btn, "modulate", Color(1.08, 1.06, 1.0), 1.0).set_ease(Tween.EASE_IN_OUT)
			glow_tw.tween_property(btn, "modulate", Color(1.0, 1.0, 1.0), 1.0).set_ease(Tween.EASE_IN_OUT)
		grid.add_child(btn)

func _open_emporium_category(cat_idx: int) -> void:
	_clear()
	var sc = ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_area.add_child(sc)
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 4)
	sc.add_child(margin)
	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 8)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vb)
	if not _main: return
	var cat = _main.emporium_categories[cat_idx]
	# Back button with art styling
	var back = _art_button("< BACK TO EMPORIUM", Color(0.12, 0.10, 0.22), Vector2(190, 32))
	back.pressed.connect(_build_emporium)
	vb.add_child(back)
	vb.add_child(_title(cat.get("name", "SHOP")))
	vb.add_child(_lbl(cat.get("desc", ""), 12, Color(0.60, 0.55, 0.48)))
	# Show player's current currencies
	var cur_row = HBoxContainer.new()
	cur_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cur_row.add_theme_constant_override("separation", 16)
	cur_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cur_row.add_child(_lbl("🪙 %d" % _main.gold, 11, Color(1, 0.85, 0.2)))
	cur_row.add_child(_lbl("🪶 %d" % _main.player_quills, 11, Color(0.7, 0.5, 0.9)))
	cur_row.add_child(_lbl("💎 %d" % _main.player_gear_shards, 11, Color(0.3, 0.75, 0.9)))
	vb.add_child(cur_row)
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
		["100 Gold", "5 Quills", 100, "quills", 5, Color(1,0.85,0.2), Color(0.7,0.5,0.9)],
		["250 Gold", "15 Shards", 250, "shards", 15, Color(1,0.85,0.2), Color(0.3,0.75,0.9)],
		["500 Gold", "3 Stars", 500, "stars", 3, Color(1,0.85,0.2), Color(1,0.9,0.3)],
	]
	for ex in exchange_data:
		var cost = ex[2]
		var can_afford = _main.gold >= cost
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
		row.add_child(_lbl(ex[0], 14, ex[5]))
		row.add_child(_lbl("→", 16, Color(0.65, 0.55, 0.45)))
		var recv = _lbl(ex[1], 14, ex[6])
		recv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		recv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(recv)
		if can_afford:
			var buy = _art_button("EXCHANGE", Color(0.12, 0.40, 0.12))
			var currency_key = ex[3]
			var amount = ex[4]
			var cost_val = cost
			buy.pressed.connect(func():
				_show_popup("Confirm Exchange", "Spend %d Gold for %d %s?" % [cost_val, amount, currency_key.capitalize()], "CONFIRM", func():
					_main.gold -= cost_val
					match currency_key:
						"quills": _main.player_quills += amount
						"shards": _main.player_gear_shards += amount
						"stars": _main.player_storybook_stars += amount
					_open_emporium_category(0)))
			row.add_child(buy)
		else:
			row.add_child(_lbl("NOT ENOUGH GOLD", 10, Color(0.8, 0.2, 0.15)))
		parent.add_child(card)

func _build_quill_shop(parent: VBoxContainer) -> void:
	parent.add_child(_lbl("Spend Quills on rare treasures", 12, Color(0.60, 0.55, 0.48)))
	if _main:
		parent.add_child(_lbl("🪶 %d Quills available" % _main.player_quills, 14, Color(0.7, 0.5, 0.9)))
	var items = [
		["Enchanted Bookmark", "Marks a level for bonus rewards", 25, Color(0.6, 0.4, 0.8)],
		["Story Fragment", "Unlocks a hidden lore passage", 40, Color(0.4, 0.6, 0.7)],
		["Author's Ink", "Boost one character's XP by 500", 60, Color(0.3, 0.3, 0.5)],
		["Plot Armor", "One free revive in your next battle", 100, Color(0.8, 0.7, 0.2)],
	]
	for item in items:
		var card = PanelContainer.new()
		var is2 = StyleBoxFlat.new()
		is2.bg_color = Color(0.05, 0.03, 0.10, 0.5)
		is2.set_corner_radius_all(8)
		is2.border_color = Color(item[3].r * 0.5, item[3].g * 0.5, item[3].b * 0.5, 0.4)
		is2.set_border_width_all(1)
		is2.content_margin_left = 12; is2.content_margin_right = 12
		is2.content_margin_top = 6; is2.content_margin_bottom = 6
		card.add_theme_stylebox_override("panel", is2)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(row)
		var nl = _lbl(item[0], 13, item[3])
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(nl)
		row.add_child(_lbl(item[1], 9, Color(0.50, 0.45, 0.40)))
		row.add_child(_lbl("🪶 %d" % item[2], 11, Color(0.7, 0.5, 0.9)))
		var buy = _art_button("BUY", Color(0.12, 0.40, 0.12), Vector2(70, 28))
		row.add_child(buy)
		parent.add_child(card)

func _build_gear_shard_shop(parent: VBoxContainer) -> void:
	parent.add_child(_lbl("Collect and forge Gear Shards", 12, Color(0.60, 0.55, 0.48)))
	if _main:
		parent.add_child(_lbl("You have: %d Gear Shards" % _main.player_gear_shards, 14, Color(0.3, 0.75, 0.9)))
	# Chest opening option
	if _art.has("reward_chest"):
		var chest_panel = PanelContainer.new()
		var cps = StyleBoxFlat.new()
		cps.bg_color = Color(0.06, 0.04, 0.12, 0.5)
		cps.set_corner_radius_all(10)
		cps.border_color = Color(0.7, 0.5, 0.15, 0.5)
		cps.set_border_width_all(2)
		cps.content_margin_left = 16; cps.content_margin_right = 16
		cps.content_margin_top = 12; cps.content_margin_bottom = 12
		chest_panel.add_theme_stylebox_override("panel", cps)
		var cv = VBoxContainer.new()
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		cv.add_theme_constant_override("separation", 8)
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chest_panel.add_child(cv)
		var chest_art = TextureRect.new()
		chest_art.texture = _art["reward_chest"]
		chest_art.custom_minimum_size = Vector2(80, 60)
		chest_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		chest_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		chest_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat = _make_black_key_mat(0.08, 0.05)
		if mat: chest_art.material = mat
		cv.add_child(chest_art)
		cv.add_child(_lbl("Gear Chest — 50 Shards", 13, Color(0.85, 0.70, 0.20)))
		cv.add_child(_lbl("Contains 1 random piece of Gear", 10, Color(0.55, 0.50, 0.45)))
		var open_btn = _art_button("OPEN CHEST", Color(0.5, 0.35, 0.10), Vector2(140, 34))
		if _main and _main.player_gear_shards >= 50:
			open_btn.pressed.connect(func():
				_show_popup("Chest Opened!", "You received a new piece of Gear!\n+1 Random Gear Item"))
		else:
			open_btn.disabled = true
		cv.add_child(open_btn)
		parent.add_child(chest_panel)
	_build_generic_shop(parent, {"name": "Gear Shards"})

func _build_survivor_packs(parent: VBoxContainer) -> void:
	parent.add_child(_lbl("Bundles of literary might — boost your Survivors!", 12, Color(0.60, 0.55, 0.48)))
	var packs = [
		["Starter Bundle", "XP Boost for 3 characters + 500 Gold", 50, "quills", Color(0.3, 0.7, 0.3)],
		["Hero's Journey", "Level up any character by 1 + Random Gear", 100, "quills", Color(0.2, 0.5, 0.9)],
		["Epic Collection", "3 Gear Chests + 1000 Gold + 50 Shards  (Save 30%!)", 200, "quills", Color(0.7, 0.3, 0.9)],
		["Legendary Tome", "Unlock next character + Full Gear Set  (Best Value!)", 500, "quills", Color(1.0, 0.7, 0.1)],
	]
	for pk in packs:
		var card = PanelContainer.new()
		var cs = StyleBoxFlat.new()
		cs.bg_color = Color(pk[4].r * 0.15, pk[4].g * 0.15, pk[4].b * 0.15, 0.6)
		cs.set_corner_radius_all(10)
		cs.border_color = Color(pk[4].r * 0.5, pk[4].g * 0.5, pk[4].b * 0.5, 0.5)
		cs.set_border_width_all(2)
		cs.shadow_color = Color(pk[4].r * 0.2, pk[4].g * 0.2, pk[4].b * 0.2, 0.15)
		cs.shadow_size = 3
		cs.content_margin_left = 14; cs.content_margin_right = 14
		cs.content_margin_top = 10; cs.content_margin_bottom = 10
		card.add_theme_stylebox_override("panel", cs)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(row)
		var info = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(info)
		info.add_child(_lbl(pk[0], 15, pk[4]))
		var desc = _lbl(pk[1], 10, Color(0.55, 0.50, 0.45))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_child(desc)
		info.add_child(_lbl("%d %s" % [pk[2], pk[3].capitalize()], 11, Color(0.7, 0.5, 0.9)))
		var buy = _art_button("BUY", Color(0.12, 0.40, 0.12), Vector2(80, 32))
		var cost = pk[2]
		buy.pressed.connect(func():
			_show_popup("Purchase Pack", "Buy %s for %d Quills?" % [pk[0], cost], "BUY", func():
				_show_popup("Pack Opened!", pk[1] + "\nRewards added to your collection!")))
		row.add_child(buy)
		parent.add_child(card)

func _build_trophy_store_items(parent: VBoxContainer) -> void:
	parent.add_child(_lbl("Spend Trophies on cosmetic upgrades", 12, Color(0.60, 0.55, 0.48)))
	if _main:
		parent.add_child(_lbl("⭐ %d Trophies available" % (_main.player_storybook_stars if "player_storybook_stars" in _main else 0), 14, Color(1, 0.85, 0.3)))
	var trophies = [
		["Golden Path Trail", "Your towers leave a glittering path", 5, Color(1.0, 0.85, 0.15)],
		["Ink Splash Effect", "Enemies burst into ink on defeat", 10, Color(0.3, 0.3, 0.5)],
		["Story Narrator Voice", "Unlock dramatic level introductions", 15, Color(0.7, 0.5, 0.2)],
		["Enchanted Aura", "Characters glow with literary magic", 20, Color(0.5, 0.3, 0.9)],
		["Shadow Crown", "Cosmetic crown for your favorite character", 30, Color(0.8, 0.6, 0.1)],
	]
	for tr in trophies:
		var card = PanelContainer.new()
		var trs = StyleBoxFlat.new()
		trs.bg_color = Color(0.05, 0.03, 0.10, 0.5)
		trs.set_corner_radius_all(8)
		trs.border_color = Color(tr[3].r * 0.5, tr[3].g * 0.5, tr[3].b * 0.5, 0.4)
		trs.set_border_width_all(1)
		trs.content_margin_left = 12; trs.content_margin_right = 12
		trs.content_margin_top = 8; trs.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", trs)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(row)
		var info = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(info)
		info.add_child(_lbl(tr[0], 13, tr[3]))
		info.add_child(_lbl(tr[1], 10, Color(0.55, 0.50, 0.45)))
		row.add_child(_lbl("⭐ %d" % tr[2], 12, Color(1, 0.85, 0.3)))
		var buy = _art_button("BUY", Color(0.12, 0.40, 0.12), Vector2(70, 28))
		row.add_child(buy)
		parent.add_child(card)

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
			var card = PanelContainer.new()
			var cs = StyleBoxFlat.new()
			cs.bg_color = Color(0.05, 0.03, 0.10, 0.5)
			cs.set_corner_radius_all(8)
			cs.border_color = Color(0.55, 0.42, 0.18, 0.4)
			cs.set_border_width_all(1)
			cs.content_margin_left = 12; cs.content_margin_right = 12
			cs.content_margin_top = 6; cs.content_margin_bottom = 6
			card.add_theme_stylebox_override("panel", cs)
			var row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(row)
			var name_lbl = _lbl(item.get("name","???"), 14, Color(0.90, 0.80, 0.50))
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(name_lbl)
			row.add_child(_lbl("%d %s" % [item.get("cost",0), item.get("cost_type","gold")], 12, Color(0.85, 0.70, 0.20)))
			var buy = _art_button("BUY", Color(0.12, 0.40, 0.12), Vector2(70, 28))
			row.add_child(buy)
			parent.add_child(card)
	else:
		parent.add_child(_lbl("The merchant will return soon...", 11, Color(0.50, 0.45, 0.40)))

func _build_generic_shop(parent: VBoxContainer, cat: Dictionary) -> void:
	parent.add_child(_lbl("Coming soon to %s..." % cat.get("name","Shop"), 13, Color(0.60, 0.55, 0.48)))
	# Show placeholder items with locked styling
	var placeholders = ["Mystery Item I", "Mystery Item II", "Mystery Item III"]
	for pi in range(3):
		var row_panel = PanelContainer.new()
		var rps = StyleBoxFlat.new()
		rps.bg_color = Color(0.04, 0.03, 0.08, 0.4)
		rps.set_corner_radius_all(6)
		rps.content_margin_left = 12; rps.content_margin_right = 12
		rps.content_margin_top = 6; rps.content_margin_bottom = 6
		row_panel.add_theme_stylebox_override("panel", rps)
		row_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_panel.add_child(row)
		row.add_child(_lbl("🔒", 16, Color(0.35, 0.30, 0.25)))
		var il = _lbl(placeholders[pi], 13, Color(0.40, 0.35, 0.30))
		il.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		il.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(il)
		row.add_child(_lbl("???", 12, Color(0.35, 0.30, 0.25)))
		parent.add_child(row_panel)

# ======================== CODEX ========================
var _codex_subtab: String = "gear"

func _build_codex() -> void:
	_clear()
	var codex_margin = MarginContainer.new()
	codex_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	codex_margin.add_theme_constant_override("margin_left", 16)
	codex_margin.add_theme_constant_override("margin_right", 16)
	codex_margin.add_theme_constant_override("margin_top", 4)
	content_area.add_child(codex_margin)
	var main_vb = VBoxContainer.new()
	main_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	codex_margin.add_child(main_vb)
	main_vb.add_child(_title("THE CODEX"))
	# Sub-tabs
	var tab_row = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	tab_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for tab in [["gear", "GEAR"], ["achievements", "ACHIEVE"], ["bestiary", "BESTIARY"], ["journal", "JOURNAL"], ["books", "BOOKS"], ["stats", "STATS"]]:
		var is_active_codex = _codex_subtab == tab[0]
		var tb = Button.new()
		tb.text = tab[1]
		tb.custom_minimum_size = Vector2(0, 30)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		"books": _build_book_collection(content)

func _codex_switch(tab: String) -> void:
	_codex_subtab = tab
	_build_codex()

func _build_gear_grid(parent: VBoxContainer) -> void:
	parent.add_child(_lbl("GEAR COMPENDIUM — %d Items" % _main._gear_icon_textures.size(), 14, Color(0.85, 0.72, 0.40)))
	parent.add_child(_lbl("Collect gear from battles and the Emporium", 11, Color(0.55, 0.50, 0.45)))
	# Filter row
	var filter_row = HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 6)
	filter_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	filter_row.add_child(_lbl("Filter:", 10, Color(0.55, 0.48, 0.42)))
	for fr in [["ALL", Color(0.55, 0.50, 0.45)], ["COMMON", Color(0.5, 0.5, 0.5)], ["RARE", Color(0.2, 0.5, 0.9)], ["EPIC", Color(0.7, 0.3, 0.9)], ["LEGEND", Color(1.0, 0.7, 0.1)]]:
		var fb = _art_button(fr[0], Color(0.08, 0.06, 0.14), Vector2(70, 22))
		fb.add_theme_font_size_override("font_size", 8)
		fb.add_theme_color_override("font_color", fr[1])
		filter_row.add_child(fb)
	parent.add_child(filter_row)
	var grid = GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		# Each gear item as a clickable button
		var card = Button.new()
		card.text = ""
		card.custom_minimum_size = Vector2(90, 100)
		var cs = StyleBoxFlat.new()
		cs.bg_color = Color(0.04, 0.03, 0.08, 0.6)
		cs.border_color = Color(rarity_col.r * 0.7, rarity_col.g * 0.7, rarity_col.b * 0.7, 0.5)
		cs.set_border_width_all(2)
		cs.set_corner_radius_all(8)
		cs.shadow_color = Color(rarity_col.r * 0.3, rarity_col.g * 0.3, rarity_col.b * 0.3, 0.2)
		cs.shadow_size = 3
		cs.content_margin_left = 4; cs.content_margin_right = 4
		cs.content_margin_top = 4; cs.content_margin_bottom = 4
		card.add_theme_stylebox_override("normal", cs)
		var csh = cs.duplicate()
		csh.bg_color = Color(0.08, 0.06, 0.15, 0.8)
		csh.border_color = Color(rarity_col.r, rarity_col.g, rarity_col.b, 0.8)
		card.add_theme_stylebox_override("hover", csh)
		var gear_name_display = gk.replace("_", " ").capitalize()
		card.tooltip_text = gear_name_display
		card.pressed.connect(func(): _show_popup(gear_name_display, "A piece of equipment from the literary worlds.\nRarity: %s" % ["Common", "Uncommon", "Rare", "Epic", "Legendary"][rarity_idx]))
		_add_press_feedback(card)
		var cv = VBoxContainer.new()
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(cv)
		var icon = TextureRect.new()
		icon.texture = _main._gear_icon_textures[gk]
		icon.custom_minimum_size = Vector2(64, 64)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(icon)
		var name_lbl = _lbl(gk.replace("_", " ").capitalize(), 9, Color(0.65, 0.58, 0.50))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_lbl.clip_text = true
		name_lbl.custom_minimum_size.x = 85
		cv.add_child(name_lbl)
		# Check if equipped by any character
		var equipped_by = ""
		for si in range(_main.survivor_types.size()):
			var stt = _main.survivor_types[si]
			if _main.survivor_gear.has(stt):
				var sg = _main.survivor_gear[stt]
				var sg_key = sg.get("name", "").to_lower().replace(" ", "_").replace("'", "")
				if sg_key == gk or gk in sg_key or sg_key in gk:
					equipped_by = _main.character_names[si] if si < _main.character_names.size() else ""
					break
		if equipped_by != "":
			var eq_lbl = _lbl(equipped_by, 8, Color(0.4, 0.8, 0.3))
			eq_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			eq_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			eq_lbl.clip_text = true
			eq_lbl.custom_minimum_size.x = 80
			cv.add_child(eq_lbl)
		grid.add_child(card)

func _build_achievements_list(parent: VBoxContainer) -> void:
	parent.add_child(_section_header("ACHIEVEMENTS"))
	# Show progress if available
	var earned = 0
	var total_ach = 0
	if _main and "achievement_definitions" in _main:
		total_ach = _main.achievement_definitions.size()
	if _main and "achievement_progress" in _main:
		for ak in _main.achievement_progress:
			var ap = _main.achievement_progress[ak]
			if ap is Dictionary and ap.get("completed", false):
				earned += 1
	if total_ach > 0:
		parent.add_child(_lbl("%d / %d Achievements Earned" % [earned, total_ach], 13, Color(0.85, 0.70, 0.20)))
		parent.add_child(_stat_bar("Completion", earned, total_ach, Color(0.85, 0.70, 0.20)))
	if not _main or not _main.has_method("_get_achievement_list"):
		# Show achievement icons from textures with styled cards
		if _main._achievement_icon_textures.size() > 0:
			parent.add_child(_lbl("%d Achievement Icons Available" % _main._achievement_icon_textures.size(), 12, Color(0.6, 0.55, 0.48)))
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
				var name_lbl = _lbl(ak.replace("_", " ").capitalize(), 8, Color(0.60, 0.55, 0.48))
				name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				name_lbl.clip_text = true
				name_lbl.custom_minimum_size.x = 80
				name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				cv.add_child(name_lbl)
				grid.add_child(card)
		else:
			parent.add_child(_lbl("No achievement icons loaded yet.", 12, Color(0.55, 0.50, 0.45)))
	# Show achievement definitions list with progress
	if _main and "achievement_definitions" in _main and _main.achievement_definitions.size() > 0:
		var cur_cat = ""
		for ad in _main.achievement_definitions:
			var cat = ad.get("category", "")
			if cat != cur_cat:
				cur_cat = cat
				parent.add_child(_section_header(cat.to_upper()))
			var ach_id = ad.get("id", "")
			var prog = 0
			var is_done = false
			if "achievement_progress" in _main and _main.achievement_progress.has(ach_id):
				var ap = _main.achievement_progress[ach_id]
				if ap is Dictionary:
					prog = ap.get("progress", 0)
					is_done = ap.get("completed", false)
				elif ap is int:
					prog = ap
					is_done = prog >= ad.get("target", 1)
			var ach_row = HBoxContainer.new()
			ach_row.add_theme_constant_override("separation", 8)
			ach_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var icon_txt = "✅" if is_done else "⬜"
			ach_row.add_child(_lbl(icon_txt, 10, Color.WHITE))
			var name_l = _lbl(ad.get("name", ""), 10, Color(0.85, 0.78, 0.60) if is_done else Color(0.50, 0.45, 0.40))
			name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ach_row.add_child(name_l)
			ach_row.add_child(_lbl("%d/%d" % [mini(prog, ad.get("target", 1)), ad.get("target", 1)], 9, Color(0.45, 0.40, 0.38)))
			var reward_text = "+%d %s" % [ad.get("reward_amount", 0), ad.get("reward_type", "").capitalize()]
			ach_row.add_child(_lbl(reward_text, 9, Color(0.4, 0.7, 0.3) if is_done else Color(0.35, 0.30, 0.25)))
			# CLAIM button for completed achievements
			if is_done:
				var claim = _art_button("CLAIM", Color(0.12, 0.40, 0.12), Vector2(60, 22))
				claim.add_theme_font_size_override("font_size", 9)
				var ach_name = ad.get("name", "")
				var ach_reward = reward_text
				claim.pressed.connect(func(): _show_popup("Reward Claimed!", "%s\n%s" % [ach_name, ach_reward]))
				ach_row.add_child(claim)
			parent.add_child(ach_row)
	return

func _build_stats_page(parent: VBoxContainer) -> void:
	parent.add_child(_section_header("GAMEPLAY STATISTICS"))
	if not _main: return
	var stats_data = [
		["Account Level", _main.account_level if "account_level" in _main else 1],
		["Levels Completed", _main.completed_levels.size() if "completed_levels" in _main else 0],
		["Total Stars", 0],
		["Total Enemies Killed", _main.total_enemies_killed if "total_enemies_killed" in _main else 0],
		["Total Towers Placed", _main.total_towers_placed if "total_towers_placed" in _main else 0],
		["Total Gold Earned", _main.total_gold_earned if "total_gold_earned" in _main else 0],
		["Total Gold Spent", _main.total_gold_spent if "total_gold_spent" in _main else 0],
		["Emporium Purchases", _main.total_emporium_purchases if "total_emporium_purchases" in _main else 0],
		["Chests Opened", _main.total_chests_opened if "total_chests_opened" in _main else 0],
		["Quests Completed", _main.total_quests_completed if "total_quests_completed" in _main else 0],
		["Characters Rescued", 0],
	]
	# Calculate total stars
	if "level_stars" in _main:
		for k in _main.level_stars:
			stats_data[2][1] += _main.level_stars[k]
	# Calculate characters rescued
	var rescued = 0
	for st in _main.survivor_types:
		if _main._is_character_unlocked(st): rescued += 1
	stats_data[10][1] = rescued
	# Add session time and FPS
	var session_secs = int(Time.get_ticks_msec() / 1000.0)
	var session_min = session_secs / 60
	var session_hr = session_min / 60
	var time_str = "%dh %dm" % [session_hr, session_min % 60] if session_hr > 0 else "%dm %ds" % [session_min, session_secs % 60]
	stats_data.append(["Session Time", time_str])
	stats_data.append(["Current FPS", Engine.get_frames_per_second()])
	# Trophy showcase
	if "showcase_achievements" in _main and _main.showcase_achievements.size() > 0:
		var trophy_text = ""
		for sa in _main.showcase_achievements:
			trophy_text += "🏆 %s  " % str(sa)
		stats_data.append(["Trophy Showcase", trophy_text.strip_edges()])
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
		var val_text = str(sd[1])
		if sd[1] is int and sd[1] > 999:
			val_text = _format_num(float(sd[1]))
		elif sd[1] is float:
			val_text = _format_num(sd[1])
		var vl = _lbl(val_text, 18, Color(1.0, 0.92, 0.45))
		vl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(vl)
		parent.add_child(row_panel)

func _build_bestiary(parent: VBoxContainer) -> void:
	parent.add_child(_section_header("BESTIARY"))
	parent.add_child(_lbl("Enemies encountered in your battles", 11, Color(0.55, 0.50, 0.45)))
	if not _main: return
	# Show enemy types from the game data
	var enemy_types = [
		["Ink Blot", "Basic unit. Slow and steady. The foot soldiers of every chapter.", "HP: Low  SPD: Slow", Color(0.3, 0.3, 0.3)],
		["Page Ripper", "Fast melee unit. Shreds tower defenses on contact.", "HP: Low  SPD: Fast", Color(0.7, 0.3, 0.3)],
		["Spine Crawler", "Heavily armored. Absorbs massive punishment.", "HP: High  SPD: Slow", Color(0.5, 0.5, 0.6)],
		["Plot Twist", "Teleports past tower range. Unpredictable pathing.", "HP: Med  SPD: Med", Color(0.6, 0.3, 0.7)],
		["Bookmark", "Healer. Restores HP to all nearby enemies.", "HP: Med  SPD: Med", Color(0.3, 0.7, 0.3)],
		["Red Herring", "Decoy. Splits into 2 smaller units on death.", "HP: Low  SPD: Fast", Color(0.8, 0.2, 0.2)],
		["Eraser", "Strips tower buffs and upgrades on contact.", "HP: Med  SPD: Med", Color(0.9, 0.9, 0.9)],
		["Margin Note", "Tiny, fast, comes in swarms of 10+.", "HP: Tiny  SPD: Very Fast", Color(0.6, 0.6, 0.4)],
		["Footnote", "Invisible until close. Bypasses early towers.", "HP: Low  SPD: Fast", Color(0.4, 0.4, 0.5)],
		["Cliffhanger", "Stops moving at 50% HP. Regenerates if not killed fast.", "HP: High  SPD: Med", Color(0.7, 0.5, 0.2)],
		["Chapter Boss", "Elite enemy. Massive HP pool with unique abilities.", "HP: BOSS  SPD: Slow", Color(0.8, 0.6, 0.2)],
		["The Author's Hand", "Final boss summon. Writes new enemies into existence.", "HP: BOSS  SPD: Varies", Color(0.9, 0.4, 0.8)],
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
		cs.border_color = Color(e[3].r * 0.5, e[3].g * 0.5, e[3].b * 0.5, 0.4)
		cs.set_border_width_all(1)
		cs.content_margin_left = 10; cs.content_margin_right = 10
		cs.content_margin_top = 8; cs.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", cs)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv = VBoxContainer.new()
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(cv)
		cv.add_child(_lbl(e[0], 14, e[3]))
		var desc = _lbl(e[1], 10, Color(0.55, 0.50, 0.45))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(desc)
		var stats_lbl = _lbl(e[2], 9, Color(0.50, 0.45, 0.40))
		stats_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(stats_lbl)
		grid.add_child(card)

func _build_journal(parent: VBoxContainer) -> void:
	parent.add_child(_section_header("CHARACTER JOURNALS"))
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
			# Source novel
			if i < _main.character_novels.size():
				text_col.add_child(_lbl("from \"%s\"" % _main.character_novels[i], 9, Color(0.50, 0.42, 0.38)))
			# Title
			if i < _main.character_titles.size():
				text_col.add_child(_lbl(_main.character_titles[i], 10, Color(0.60, 0.52, 0.44)))
			# Quote
			if i < _main.character_quotes.size():
				var quote = _lbl('"' + _main.character_quotes[i] + '"', 10, Color(0.55, 0.50, 0.45))
				quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				quote.mouse_filter = Control.MOUSE_FILTER_IGNORE
				text_col.add_child(quote)
		else:
			text_col.add_child(_lbl("???", 14, Color(0.35, 0.30, 0.25)))
			text_col.add_child(_lbl("Rescue this character to unlock their journal", 10, Color(0.35, 0.30, 0.25)))
		parent.add_child(entry)

func _build_book_collection(parent: VBoxContainer) -> void:
	parent.add_child(_section_header("BOOK COLLECTION"))
	parent.add_child(_lbl("The literary works that power your Survivors", 11, Color(0.55, 0.50, 0.45)))
	if not _main: return
	# Collect unique novels
	var novels = []
	for i in range(_main.character_novels.size()):
		var novel = _main.character_novels[i]
		if novel not in novels:
			novels.append(novel)
	parent.add_child(_lbl("%d / %d Books Collected" % [novels.size(), novels.size()], 13, Color(0.85, 0.70, 0.20)))
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(grid)
	for ni in range(novels.size()):
		var book_card = PanelContainer.new()
		var bcs = StyleBoxFlat.new()
		# Color based on genre
		var book_colors = [Color(0.3, 0.6, 0.2), Color(0.6, 0.3, 0.6), Color(0.2, 0.5, 0.7), Color(0.7, 0.4, 0.2), Color(0.5, 0.2, 0.3), Color(0.4, 0.5, 0.3)]
		var bc = book_colors[ni % book_colors.size()]
		bcs.bg_color = Color(bc.r * 0.3, bc.g * 0.3, bc.b * 0.3, 0.6)
		bcs.set_corner_radius_all(8)
		bcs.border_color = Color(bc.r * 0.6, bc.g * 0.6, bc.b * 0.6, 0.5)
		bcs.set_border_width_all(2)
		bcs.content_margin_left = 10; bcs.content_margin_right = 10
		bcs.content_margin_top = 8; bcs.content_margin_bottom = 8
		book_card.add_theme_stylebox_override("panel", bcs)
		book_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		book_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var bvb = VBoxContainer.new()
		bvb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		book_card.add_child(bvb)
		bvb.add_child(_lbl("📖", 20, Color.WHITE))
		var title_lbl = _lbl(novels[ni], 11, Color(0.85, 0.78, 0.65))
		title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bvb.add_child(title_lbl)
		# Find which character comes from this novel
		for ci in range(_main.character_novels.size()):
			if _main.character_novels[ci] == novels[ni] and ci < _main.character_names.size():
				bvb.add_child(_lbl(_main.character_names[ci], 9, Color(0.55, 0.48, 0.42)))
				break
		grid.add_child(book_card)

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
	vb.add_child(_section_header("AUDIO"))
	if _main:
		_add_setting_row(vb, "Music Volume", "%d%%" % int(GameSettings.music_volume * 100), func(): GameSettings.music_volume = fmod(GameSettings.music_volume + 0.25, 1.25); GameSettings.save_settings(); _play_ui_click(); _build_settings(), true, GameSettings.music_volume)
		_add_setting_row(vb, "SFX Volume", "%d%%" % int(GameSettings.sfx_volume * 100), func(): GameSettings.sfx_volume = fmod(GameSettings.sfx_volume + 0.25, 1.25); GameSettings.save_settings(); _play_ui_click(); _build_settings(), true, GameSettings.sfx_volume)
		_add_setting_row(vb, "Voice Volume", "%d%%" % int(GameSettings.voice_volume * 100), func(): GameSettings.voice_volume = fmod(GameSettings.voice_volume + 0.25, 1.25); GameSettings.save_settings(); _play_ui_click(); _build_settings(), true, GameSettings.voice_volume)
		_add_setting_row(vb, "Music Muted", "YES" if GameSettings.music_muted else "NO", func(): GameSettings.music_muted = not GameSettings.music_muted; GameSettings.save_settings(); _build_settings())
	# Graphics section
	vb.add_child(_section_header("GRAPHICS"))
	if _main:
		_add_setting_row(vb, "Quality", GameSettings.get_quality_name(), func(): GameSettings.cycle_quality(); _build_settings())
		var quality_hints = {"Low": "Best performance, reduced effects", "Medium": "Balanced quality and performance", "High": "Best visuals, may reduce FPS", "Auto": "Adjusts automatically based on FPS"}
		var qname = GameSettings.get_quality_name()
		if quality_hints.has(qname):
			var qh = _lbl("  ↳ %s  (%d FPS)" % [quality_hints[qname], Engine.get_frames_per_second()], 9, Color(0.50, 0.45, 0.40))
			qh.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vb.add_child(qh)
		_add_setting_row(vb, "Particle Effects", "ON" if GameSettings.particle_effects else "OFF", func(): GameSettings.particle_effects = not GameSettings.particle_effects; GameSettings.save_settings(); _build_settings())
		_add_setting_row(vb, "Screen Shake", "ON" if GameSettings.screen_shake else "OFF", func(): GameSettings.screen_shake = not GameSettings.screen_shake; GameSettings.save_settings(); _build_settings())
		_add_setting_row(vb, "Damage Numbers", "ON" if GameSettings.show_damage_numbers else "OFF", func(): GameSettings.show_damage_numbers = not GameSettings.show_damage_numbers; GameSettings.save_settings(); _build_settings())
	# Gameplay section
	vb.add_child(_section_header("GAMEPLAY"))
	if _main:
		var speed_names = ["1x", "2x", "3x"]
		_add_setting_row(vb, "Game Speed", speed_names[clampi(GameSettings.game_speed - 1, 0, 2)], func(): GameSettings.cycle_speed(); _build_settings())
		_add_setting_row(vb, "Auto Wave", "ON" if GameSettings.auto_wave else "OFF", func(): GameSettings.auto_wave = not GameSettings.auto_wave; GameSettings.save_settings(); _build_settings())
	# Accessibility section
	vb.add_child(_section_header("ACCESSIBILITY"))
	if _main:
		var text_sizes = ["1.0x", "1.25x", "1.5x"]
		var ts_idx = [1.0, 1.25, 1.5].find(GameSettings.font_scale)
		if ts_idx < 0: ts_idx = 0
		_add_setting_row(vb, "Text Size", text_sizes[ts_idx], func(): var sizes = [1.0, 1.25, 1.5]; var ci = sizes.find(GameSettings.font_scale); GameSettings.font_scale = sizes[(ci + 1) % 3]; GameSettings.save_settings(); _build_settings())
		var preview = _lbl("  ↳ Preview: This is how text will look", int(10 * GameSettings.font_scale), Color(0.55, 0.50, 0.45))
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(preview)
		var cb_names = ["Off", "Deuteranopia", "Protanopia", "Tritanopia"]
		_add_setting_row(vb, "Colorblind Mode", cb_names[clampi(GameSettings.colorblind_mode, 0, 3)], func(): GameSettings.colorblind_mode = (GameSettings.colorblind_mode + 1) % 4; GameSettings.save_settings(); _build_settings())
		if GameSettings.colorblind_mode > 0:
			var cb_desc = ["", "Red-green (most common)", "Red-green (protanopia)", "Blue-yellow (rare)"]
			var desc = _lbl("  ↳ %s" % cb_desc[clampi(GameSettings.colorblind_mode, 0, 3)], 9, Color(0.50, 0.45, 0.40))
			desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vb.add_child(desc)
		_add_setting_row(vb, "Reduced Motion", "ON" if GameSettings.reduced_motion else "OFF", func(): GameSettings.reduced_motion = not GameSettings.reduced_motion; GameSettings.save_settings(); _build_settings())
		_add_setting_row(vb, "Left-Handed", "ON" if GameSettings.left_handed else "OFF", func(): GameSettings.left_handed = not GameSettings.left_handed; GameSettings.save_settings(); _build_settings())
		_add_setting_row(vb, "Haptic Feedback", "ON" if GameSettings.haptic_feedback else "OFF", func(): GameSettings.haptic_feedback = not GameSettings.haptic_feedback; GameSettings.save_settings(); _build_settings())
		_add_setting_row(vb, "One-Handed Mode", "ON" if GameSettings.one_handed else "OFF", func(): GameSettings.one_handed = not GameSettings.one_handed; GameSettings.save_settings(); _build_settings())
	# Language
	vb.add_child(_section_header("LANGUAGE"))
	_add_setting_row(vb, "Language", "English", func(): pass)  # Placeholder
	# Reset to defaults
	var reset_btn = _art_button("RESET TO DEFAULTS", Color(0.5, 0.12, 0.12), Vector2(180, 34))
	reset_btn.pressed.connect(func():
		_show_popup("Reset Settings", "Reset all settings to defaults?", "RESET", func():
			GameSettings.music_volume = 1.0
			GameSettings.sfx_volume = 1.0
			GameSettings.voice_volume = 1.0
			GameSettings.music_muted = false
			GameSettings.particle_effects = true
			GameSettings.screen_shake = true
			GameSettings.show_damage_numbers = true
			GameSettings.game_speed = 1
			GameSettings.auto_wave = false
			GameSettings.font_scale = 1.0
			GameSettings.colorblind_mode = 0
			GameSettings.reduced_motion = false
			GameSettings.left_handed = false
			GameSettings.save_settings()
			_build_settings()))
	vb.add_child(reset_btn)
	# Credits / About section
	vb.add_child(_section_header("ABOUT"))
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
	# What's New / Patch Notes
	vb.add_child(_section_header("WHAT'S NEW"))
	var patch_panel = PanelContainer.new()
	var pns = StyleBoxFlat.new()
	pns.bg_color = Color(0.04, 0.03, 0.08, 0.5)
	pns.set_corner_radius_all(8)
	pns.content_margin_left = 12; pns.content_margin_right = 12
	pns.content_margin_top = 8; pns.content_margin_bottom = 8
	patch_panel.add_theme_stylebox_override("panel", pns)
	patch_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pnvb = VBoxContainer.new()
	pnvb.add_theme_constant_override("separation", 4)
	pnvb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	patch_panel.add_child(pnvb)
	pnvb.add_child(_lbl("v0.9.0 — Menu Overhaul Update", 12, Color(0.85, 0.78, 0.60)))
	var notes = ["• Complete menu redesign with art backgrounds", "• 12 character ability trees with 108 named abilities", "• Gear picker + equipment system", "• Achievement tracking with progress bars", "• Bestiary with 12 enemy types", "• Gold economy rebalance", "• Wave preview on start button", "• Boss entrance announcements", "• Keyboard shortcuts (1-9, Space, Esc)", "• Damage numbers scale with hit size"]
	for note in notes:
		var nl = _lbl(note, 9, Color(0.55, 0.50, 0.45))
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pnvb.add_child(nl)
	vb.add_child(patch_panel)
	# Coming Soon roadmap
	vb.add_child(_section_header("COMING SOON"))
	var roadmap_items = ["🗺️ New campaign: The Enchanted Library", "🗡️ Tower skins & cosmetics", "👥 Co-op multiplayer mode", "🏆 Ranked competitive seasons", "🎃 Seasonal events & limited-time content"]
	for ri in roadmap_items:
		var rl = _lbl(ri, 10, Color(0.55, 0.50, 0.45))
		rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(rl)
	vb.add_child(credits_panel)

func _add_setting_row(parent: VBoxContainer, label: String, value: String, callback: Callable, is_volume: bool = false, volume_pct: float = 0.0) -> void:
	# Setting row with styled panel
	var row_panel = PanelContainer.new()
	var rps = StyleBoxFlat.new()
	rps.bg_color = Color(0.05, 0.03, 0.10, 0.55)
	rps.set_corner_radius_all(8)
	rps.border_color = Color(0.30, 0.22, 0.15, 0.25)
	rps.set_border_width_all(1)
	rps.content_margin_left = 16; rps.content_margin_right = 16
	rps.content_margin_top = 8; rps.content_margin_bottom = 8
	row_panel.add_theme_stylebox_override("panel", rps)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_panel.add_child(row)
	var nl = _lbl(label, 13, Color(0.85, 0.78, 0.65))
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(nl)
	# Volume slider bar visualization
	if is_volume:
		var bar_panel = PanelContainer.new()
		bar_panel.custom_minimum_size = Vector2(160, 22)
		bar_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bps = StyleBoxFlat.new()
		bps.bg_color = Color(0.04, 0.03, 0.08, 0.8)
		bps.set_corner_radius_all(8)
		bps.border_color = Color(0.30, 0.22, 0.15, 0.4)
		bps.set_border_width_all(1)
		bar_panel.add_theme_stylebox_override("panel", bps)
		row.add_child(bar_panel)
		var bar_fill = ColorRect.new()
		bar_fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
		bar_fill.offset_left = 2; bar_fill.offset_top = 2; bar_fill.offset_bottom = -2
		bar_fill.offset_right = -160 + (156 * volume_pct)
		bar_fill.color = Color(0.3, 0.75, 0.45, 0.9)
		bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar_panel.add_child(bar_fill)
	var btn = Button.new()
	btn.text = value
	btn.custom_minimum_size = Vector2(110, 34)
	var bs = StyleBoxFlat.new()
	# Color code — green for active/enabled, neutral for values, red only for destructive
	if value == "ON" or value == "YES":
		bs.bg_color = Color(0.10, 0.30, 0.12, 0.85)
		bs.border_color = Color(0.2, 0.6, 0.25, 0.5)
	elif value == "OFF" or value == "NO":
		bs.bg_color = Color(0.15, 0.12, 0.25, 0.85)
		bs.border_color = Color(0.35, 0.28, 0.45, 0.5)
	elif value.ends_with("%") or value.ends_with("x"):
		bs.bg_color = Color(0.12, 0.25, 0.35, 0.85)
		bs.border_color = Color(0.25, 0.5, 0.7, 0.5)
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
	# Title with decorative frame panel
	var outer = PanelContainer.new()
	var os = StyleBoxFlat.new()
	os.bg_color = Color(0.06, 0.04, 0.12, 0.6)
	os.set_corner_radius_all(10)
	os.border_color = Color(0.65, 0.50, 0.18, 0.5)
	os.set_border_width_all(1)
	os.shadow_color = Color(0.3, 0.2, 0.05, 0.15)
	os.shadow_size = 4
	os.content_margin_left = 40; os.content_margin_right = 40
	os.content_margin_top = 8; os.content_margin_bottom = 8
	outer.add_theme_stylebox_override("panel", os)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Art background for title
	if _art.has("scroll_header"):
		var art_bg = TextureRect.new()
		art_bg.texture = _art["scroll_header"]
		art_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_bg.modulate.a = 0.35
		var mat = _make_black_key_mat(0.06, 0.04)
		if mat: art_bg.material = mat
		outer.add_child(art_bg)
	var l = _lbl(text, 24, Color(1.0, 0.92, 0.40))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(l)
	return outer

# Add press feedback + SFX to any button
func _add_press_feedback(btn: BaseButton) -> void:
	btn.button_down.connect(func():
		btn.pivot_offset = btn.size / 2.0
		var tw = btn.create_tween().set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.05)
		# Play UI click SFX
		if _main and "_sfx_ui_click" in _main and _main.has_method("_play_sfx"):
			_main._play_sfx(_main._sfx_ui_click))
	btn.button_up.connect(func():
		var tw = btn.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1))

func _lbl(text: String, size: int, color: Color) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("outline_size", 2)
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

func _section_header(text: String) -> Control:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line_l = ColorRect.new()
	line_l.custom_minimum_size = Vector2(30, 1)
	line_l.color = Color(0.55, 0.42, 0.18, 0.4)
	line_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(line_l)
	var lbl = _lbl(text, 15, Color(0.85, 0.72, 0.40))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)
	var line_r = ColorRect.new()
	line_r.custom_minimum_size = Vector2(0, 1)
	line_r.color = Color(0.55, 0.42, 0.18, 0.4)
	line_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(line_r)
	return row

func _play_ui_click() -> void:
	if _main and "_sfx_ui_click" in _main and _main.has_method("_play_sfx"):
		_main._play_sfx(_main._sfx_ui_click)

func _add_scroll_hint(parent_control: Control) -> void:
	# Pulsing down arrow at bottom center
	var hint = _lbl("▼  scroll  ▼", 10, Color(0.55, 0.45, 0.35))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -20
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent_control.add_child(hint)
	var htw = create_tween().set_loops()
	htw.tween_property(hint, "modulate:a", 0.3, 0.8).set_ease(Tween.EASE_IN_OUT)
	htw.tween_property(hint, "modulate:a", 0.8, 0.8).set_ease(Tween.EASE_IN_OUT)

func _format_num(val: float) -> String:
	if val >= 1000000: return "%.1fM" % (val / 1000000.0)
	if val >= 1000: return "%.1fK" % (val / 1000.0)
	return str(int(val))

func _fade_in() -> void:
	fade_rect.color = Color(0,0,0,1)
	var tw = create_tween()
	tw.tween_property(fade_rect, "color:a", 0.0, 0.3)
