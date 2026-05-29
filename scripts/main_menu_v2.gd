extends Control
## MainMenuV2 — Full interactive menu. Art backgrounds, working buttons, detail panels.

# === DESIGN TOKENS — Standardized palette (see docs/MENU_DESIGN_REFERENCE.md) ===
const C_GOLD := Color(1.0, 0.90, 0.35)          # Primary gold — titles, active tabs, CTAs
const C_GOLD_DIM := Color(0.85, 0.70, 0.30)      # Secondary gold — borders, accents
const C_GOLD_STAR := Color(1.0, 0.85, 0.15)      # Star rating gold
const C_TEXT_PRIMARY := Color(1.0, 0.97, 0.85)    # Bright text on dark backgrounds
const C_TEXT_SECONDARY := Color(0.75, 0.68, 0.55) # Body text, descriptions
const C_TEXT_TERTIARY := Color(0.55, 0.48, 0.40)  # Dim text, captions, inactive
const C_TEXT_LOCKED := Color(0.48, 0.42, 0.35)    # Locked/disabled text
const C_BG_DARK := Color(0.04, 0.02, 0.08)        # Card/panel backgrounds
const C_BG_PANEL := Color(0.06, 0.04, 0.12)       # Slightly lighter panels
const C_BG_SURFACE := Color(0.08, 0.05, 0.14)     # Surface elements (chips, pills)
const C_BORDER_SUBTLE := Color(0.25, 0.20, 0.15, 0.4)  # Subtle borders
const C_BORDER_GOLD := Color(0.65, 0.50, 0.18, 0.5)    # Gold accent borders
const C_GREEN := Color(0.45, 0.85, 0.35)          # Complete/success
const C_GREEN_BTN := Color(0.15, 0.50, 0.15)      # Play button background
const C_RED := Color(0.85, 0.25, 0.15)             # Error/limited
const C_SHADOW := Color(0, 0, 0, 0.8)             # Text shadow color
const CORNER_CARD := 16   # Card corner radius
const CORNER_BTN := 12    # Button corner radius
const CORNER_PILL := 20   # Pill/chip corner radius
const SHADOW_CARD := 6    # Card shadow size
const SHADOW_BTN := 4     # Button shadow size

var _backgrounds: Dictionary = {}
var _art: Dictionary = {}
var _black_key: Shader = null
var _main: Node = null
var current_view: String = "chapters"
var _portal_view: String = ""  # "" = hub, "sherlock" = arc detail
# Realm definitions: arc_prefix, display name, icon key, character portrait, color accent
# REALM ORDER: Prologue → rescue Peter/Witch/Phantom → rescue Sherlock/Merlin/Tarzan/Dracula/Frank
# → starter heroes face their own stories → Shadow Author finale
# Level indices still point to the original levels[] array positions
const REALMS: Array = [
	# === ACT 1: INTO THE PAGES — Prologue + 8 rescue arcs ===
	{"arc": "Prologue", "name": "The Tome Opens", "icon": "realm_prologue", "portrait": "robin_hood", "color": [0.7, 0.6, 0.4], "levels": [0], "act": 1},
	# First 3 rescues: Peter Pan, Wicked Witch, Phantom (unlock as playable)
	{"arc": "Neverland", "name": "The Endless Story", "icon": "realm_neverland", "portrait": "peter_pan", "color": [0.3, 0.6, 0.8], "levels": [25, 64, 26, 65, 27], "act": 1, "rescues": "peter_pan"},
	{"arc": "Land of Oz", "name": "The Emerald Verse", "icon": "realm_oz", "portrait": "wicked_witch", "color": [0.2, 0.7, 0.3], "levels": [22, 66, 23, 67, 24], "act": 1, "rescues": "wicked_witch"},
	{"arc": "Paris Opera", "name": "The Phantom's Score", "icon": "realm_opera", "portrait": "phantom", "color": [0.7, 0.5, 0.3], "levels": [28, 68, 29, 69, 30], "act": 1, "rescues": "phantom"},
	# Next 5 rescues: Sherlock, Merlin, Tarzan, Dracula, Frankenstein
	{"arc": "Sherlock Holmes", "name": "Shadow London", "icon": "realm_london", "portrait": "sherlock", "color": [0.5, 0.5, 0.7], "levels": [1, 70, 2, 71, 3], "act": 1, "rescues": "sherlock"},
	{"arc": "Merlin", "name": "The Enchanted Pages", "icon": "realm_camelot", "portrait": "merlin", "color": [0.3, 0.5, 0.85], "levels": [4, 72, 5, 73, 6], "act": 1, "rescues": "merlin"},
	{"arc": "Tarzan", "name": "The Wild Chapters", "icon": "realm_jungle", "portrait": "tarzan", "color": [0.3, 0.6, 0.3], "levels": [7, 74, 8, 75, 9], "act": 1, "rescues": "tarzan"},
	{"arc": "Dracula", "name": "The Blood Script", "icon": "realm_transylvania", "portrait": "dracula", "color": [0.7, 0.2, 0.2], "levels": [10, 76, 11, 77, 12], "act": 1, "rescues": "dracula"},
	{"arc": "Frankenstein", "name": "The Stitched Pages", "icon": "realm_laboratory", "portrait": "frankenstein", "color": [0.4, 0.7, 0.3], "levels": [13, 78, 14, 79, 15], "act": 1, "rescues": "frankenstein"},
	# === ACT 2: THE SHADOW STORIES — Starter heroes face their own tales (5 levels each) ===
	{"arc": "Sherwood Forest", "name": "The Outlaw's Tale", "icon": "realm_sherwood", "portrait": "robin_hood", "color": [0.3, 0.55, 0.2], "levels": [16, 80, 17, 81, 18], "act": 2},
	{"arc": "Wonderland", "name": "The Mad Manuscript", "icon": "realm_wonderland", "portrait": "alice", "color": [0.6, 0.3, 0.7], "levels": [19, 82, 20, 83, 21], "act": 2},
	{"arc": "Victorian London", "name": "The Ghost's Ledger", "icon": "realm_christmas", "portrait": "scrooge", "color": [0.5, 0.6, 0.8], "levels": [31, 84, 32, 85, 33], "act": 2},
	# === ACT 3: THE FINAL CHAPTER (5 levels) ===
	{"arc": "Shadow Author", "name": "The Final Chapter", "icon": "realm_shadow", "portrait": "shadow_author", "color": [0.5, 0.2, 0.6], "levels": [34, 86, 35, 87, 36], "act": 3},
	# === ACT 4: THE NARRATOR'S REALM — Starter hero trials + 5 new rescues + finale ===
	{"arc": "Alice's Trial", "name": "The Vorpal Challenge", "icon": "realm_wonderland", "portrait": "alice", "color": [0.6, 0.3, 0.7], "levels": [37, 38, 39], "act": 4},
	{"arc": "Robin's Trial", "name": "The Legendary Hunt", "icon": "realm_sherwood", "portrait": "robin_hood", "color": [0.3, 0.55, 0.2], "levels": [40, 41, 42], "act": 4},
	{"arc": "Scrooge's Trial", "name": "The Eternal Debt", "icon": "realm_christmas", "portrait": "scrooge", "color": [0.5, 0.6, 0.8], "levels": [43, 44, 45], "act": 4},
	{"arc": "Headless Horseman", "name": "Sleepy Hollow", "icon": "realm_prologue", "portrait": "shadow_author", "color": [0.5, 0.35, 0.15], "levels": [46, 47, 48], "act": 4, "rescues": "headless_horseman"},
	{"arc": "Medusa", "name": "The Gorgon's Prison", "icon": "realm_prologue", "portrait": "wicked_witch", "color": [0.3, 0.55, 0.3], "levels": [49, 50, 51], "act": 4, "rescues": "medusa"},
	{"arc": "Loki", "name": "The Trickster's Cage", "icon": "realm_prologue", "portrait": "peter_pan", "color": [0.4, 0.55, 0.2], "levels": [52, 53, 54], "act": 4, "rescues": "loki"},
	{"arc": "Anubis", "name": "The Weighing Hall", "icon": "realm_prologue", "portrait": "dracula", "color": [0.6, 0.5, 0.15], "levels": [55, 56, 57], "act": 4, "rescues": "anubis"},
	# Captain Ahab removed — Hook covers ocean/pirate archetype
	{"arc": "The Narrator", "name": "The Voice Unbound", "icon": "realm_shadow", "portrait": "shadow_author", "color": [0.8, 0.5, 0.2], "levels": [61, 62, 63], "act": 4},
]
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
const PARTICLE_COUNT: int = 40

func _ready() -> void:
	_main = get_tree().get_first_node_in_group("main")
	# Bleed-through blocked by main.gd draw_rect+return AND hiding old menu nodes
	# DarkOverlay at 15% for subtle dim on background art
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
	# Auto-popup disabled — was blocking input. TODO: fix dialog input handling
	# Tutorial/daily reward popups can be triggered from a menu button instead
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
			"speed": randf_range(8, 40),
			"size": randf_range(2.0, 8.0),
			"alpha": randf_range(0.20, 0.55),
			"offset": randf_range(0, TAU),
			"drift": randf_range(-0.8, 0.8),  # Horizontal drift
		})

var _song_check_timer: float = 0.0

func _process(delta: float) -> void:
	for p in _particles:
		p["y"] -= p["speed"] * delta
		p["x"] += sin(p["offset"] + p["y"] * 0.01) * 0.3 + p["drift"] * delta
		if p["y"] < -10:
			p["y"] = 730
			p["x"] = randf_range(0, 1280)
		if p["x"] < -10: p["x"] = 1290
		if p["x"] > 1290: p["x"] = -10
	# Parallax: offset background based on scroll
	for c in content_area.get_children():
		if c is ScrollContainer:
			var scroll_y = c.scroll_vertical
			background.position.y = -scroll_y * 0.12  # Noticeable parallax
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
			if _main.player_pages != _last_shards: changed = true; _last_shards = _main.player_pages
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
	if DisplayServer.get_name() == "headless":
		return
	var m = {"chapters": "res://assets/ui_frames/scroll_banner.png", "emporium": "res://assets/menu_art/emporium_bg_gothic.png", "codex": "res://assets/menu_art/codex_bg_gothic.png", "settings": "res://assets/menu_art/settings_bg_v2.png"}
	for k in m:
		if ResourceLoader.exists(m[k]):
			_backgrounds[k] = load(m[k])
	# Survivors bg: load from disk directly (bypasses broken import system)
	var surv_path = ProjectSettings.globalize_path("res://assets/menu_art/survivors_bg_gothic.png")
	if FileAccess.file_exists(surv_path):
		var img = Image.new()
		var err = img.load(surv_path)
		if err == OK:
			_backgrounds["survivors"] = ImageTexture.create_from_image(img)

func _load_art() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if ResourceLoader.exists("res://shaders/black_key.gdshader"):
		_black_key = load("res://shaders/black_key.gdshader")
	var paths = {
		"level_card": "res://assets/ui_elements/level_card_bg.png",
		"shop_card": "res://assets/ui_elements/shop_item_card.png",
		"detail_panel": "res://assets/ui_elements/detail_panel_bg.png",
		"stats_panel": "res://assets/ui_elements/stats_panel.png",
		# buy_button and play_button removed — had baked text/white areas
		# header_bar removed — had colored gems that looked like tie-dye
		"nav_spine": "res://assets/ui_frames/nav_book_spine.png",
		"scroll_header": "res://assets/ui_frames/scroll_header_storybook.png",
		"card_frame": "res://assets/ui_frames/card_frame_storybook.png",
		# locked_card (back_button.png) removed — not used
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
		# daily_deals removed — had baked text/seal that clashed
		# claim_button removed — not used (replaced with _art_button)
		"coin_burst": "res://assets/ui_elements/coin_burst.png",
		"currency_exchange": "res://assets/ui_elements/currency_exchange.png",
		"achievement_badges": "res://assets/ui_elements/achievement_badges.png",
		"achievement_card": "res://assets/ui_elements/achievement_progress_card.png",
		"character_info_card": "res://assets/ui_elements/character_info_card.png",
		# go_button removed — was white rectangle with shader artifacts
		"three_stars": "res://assets/ui_elements/three_stars.png",
		"empty_star": "res://assets/ui_elements/empty_star.png",
		"upgrade_arrow": "res://assets/ui_elements/upgrade_arrow.png",
		"side_panel_buttons": "res://assets/ui_elements/side_panel_buttons.png",
		"panel_gothic": "res://assets/ui_elements/panel_card_gothic.png",
		"button_gothic_art": "res://assets/ui_elements/button_panel_gothic.png",
		"section_banner_art": "res://assets/ui_elements/section_banner_gothic.png",
		"nav_bar_art": "res://assets/ui_elements/nav_bar_gothic.png",
		"weapons_set": "res://assets/ui_elements/weapons_set_1.png",
		"jewelry_set": "res://assets/ui_elements/jewelry_set_1.png",
		"weapons_set_2": "res://assets/ui_elements/weapons_set_2.png",
		"currency_bar_art": "res://assets/ui_elements/currency_bar_gothic.png",
		"level_card_art": "res://assets/ui_elements/level_card_gothic.png",
		"char_card_art": "res://assets/ui_elements/char_card_gothic.png",
		"settings_bg_art": "res://assets/ui_elements/settings_panel_gothic.png",
		"game_logo_gothic": "res://assets/menu_art/game_logo_gothic.png",
		"weapon_longbow": "res://assets/gear_icons/weapon_longbow.png",
		"weapon_crystal_wand": "res://assets/gear_icons/weapon_crystal_wand.png",
		"weapon_vorpal_sword": "res://assets/gear_icons/weapon_vorpal_sword.png",
		"weapon_shadow_dagger": "res://assets/gear_icons/weapon_shadow_dagger.png",
		"weapon_blood_chalice": "res://assets/gear_icons/weapon_blood_chalice.png",
		"weapon_lightning_rod": "res://assets/gear_icons/weapon_lightning_rod.png",
		"weapon_magnifying_glass": "res://assets/gear_icons/weapon_magnifying_glass.png",
		"weapon_jungle_whip": "res://assets/gear_icons/weapon_jungle_whip.png",
		"weapon_broomstick": "res://assets/gear_icons/weapon_broomstick.png",
		"weapon_shadow_blade": "res://assets/gear_icons/weapon_shadow_blade.png",
		"weapon_pipe_organ": "res://assets/gear_icons/weapon_pipe_organ.png",
		"weapon_counting_ledger": "res://assets/gear_icons/weapon_counting_ledger.png",
		"gear_crown": "res://assets/gear_icons/gear_crown_golden.png",
		"gear_amulet": "res://assets/gear_icons/gear_amulet_crystal.png",
		"gear_bracelet": "res://assets/gear_icons/gear_bracelet_rune.png",
		"gear_ring": "res://assets/gear_icons/gear_ring_amethyst.png",
		"tooltip_frame": "res://assets/ui_elements/tooltip_frame.png",
		"wooden_sign": "res://assets/ui_elements/wooden_sign.png",
		"card_frame_epic": "res://assets/ui_frames/card_frame_epic.png",
		"wanted_poster": "res://assets/ui_frames/wanted_poster.png",
		# Portal Hub assets
		"ink_portal": "res://assets/ui_elements/ink_portal.png",
		"tome_of_shadows": "res://assets/ui_elements/tome_of_shadows.png",
		"realm_prologue": "res://assets/realm_icons/realm_prologue.png",
		"realm_london": "res://assets/realm_icons/realm_london.png",
		"realm_camelot": "res://assets/realm_icons/realm_camelot.png",
		"realm_jungle": "res://assets/realm_icons/realm_jungle.png",
		"realm_transylvania": "res://assets/realm_icons/realm_transylvania.png",
		"realm_laboratory": "res://assets/realm_icons/realm_laboratory.png",
		"realm_sherwood": "res://assets/realm_icons/realm_sherwood.png",
		"realm_wonderland": "res://assets/realm_icons/realm_wonderland.png",
		"realm_oz": "res://assets/realm_icons/realm_oz.png",
		"realm_neverland": "res://assets/realm_icons/realm_neverland.png",
		"realm_opera": "res://assets/realm_icons/realm_opera.png",
		"realm_christmas": "res://assets/realm_icons/realm_christmas.png",
		"realm_shadow": "res://assets/realm_icons/realm_shadow.png",
		"page_tear_border": "res://assets/ui_elements/page_tear_border.png",
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

var _bg_zoom_tween: Tween = null

func _set_bg(view: String) -> void:
	var dark = get_node_or_null("DarkOverlay")
	if _backgrounds.has(view):
		background.texture = _backgrounds[view]
		background.modulate = Color(1.4, 1.3, 1.2, 1.0)  # Brighten dark art
		if dark: dark.color = Color(0.02, 0.01, 0.04, 0.08)  # Almost no dim
	else:
		background.texture = null
		background.modulate = Color.WHITE
		# No art — DarkOverlay becomes the solid background
		if dark: dark.color = Color(0.06, 0.04, 0.12, 1.0)  # Solid dark purple
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.position = Vector2.ZERO
	# Slow zoom animation — gives life to static background
	background.pivot_offset = Vector2(640, 360)  # Center of 1280x720
	background.scale = Vector2(1.0, 1.0)
	if _bg_zoom_tween and _bg_zoom_tween.is_valid():
		_bg_zoom_tween.kill()
	_bg_zoom_tween = create_tween().set_loops()
	_bg_zoom_tween.tween_property(background, "scale", Vector2(1.06, 1.06), 25.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_bg_zoom_tween.tween_property(background, "scale", Vector2(1.0, 1.0), 25.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _build_currency_bar() -> void:
	if not _main: return
	# Clean top bar — no art texture (both header_bar and currency_bar_gothic looked bad)
	top_bar.color = Color(0.05, 0.03, 0.10, 1.0)  # Fully opaque (#41)
	# Bottom gold accent line on top bar
	var top_accent = ColorRect.new()
	top_accent.color = Color(0.65, 0.50, 0.18, 0.5)
	top_accent.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	top_accent.offset_top = -2
	top_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(top_accent)
	var h = HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override("separation", 6)
	# Left padding so Journey doesn't clip window edge
	var h_margin = MarginContainer.new()
	h_margin.add_theme_constant_override("margin_left", 10)
	h_margin.add_theme_constant_override("margin_right", 0)
	h_margin.add_theme_constant_override("margin_top", 0)
	h_margin.add_theme_constant_override("margin_bottom", 0)
	h_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h_margin.add_child(h)
	top_bar.add_child(h_margin)
	# LEFT: Journey progress — compact chip with mini bar
	var completed_ct = _main.completed_levels.size() if "completed_levels" in _main else 0
	var total_ct = _main.levels.size() if "levels" in _main else 90
	var pct = int(float(completed_ct) / maxf(float(total_ct), 1.0) * 100.0)
	var journey_chip = PanelContainer.new()
	var jcs = StyleBoxFlat.new()
	jcs.bg_color = Color(0.08, 0.05, 0.14, 0.9)
	jcs.set_corner_radius_all(12)
	jcs.border_color = Color(0.65, 0.50, 0.18, 0.4)
	jcs.set_border_width_all(1)
	jcs.content_margin_left = 10; jcs.content_margin_right = 10
	jcs.content_margin_top = 3; jcs.content_margin_bottom = 3
	journey_chip.add_theme_stylebox_override("panel", jcs)
	journey_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var journey_box = VBoxContainer.new()
	journey_box.add_theme_constant_override("separation", 2)
	journey_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	journey_chip.add_child(journey_box)
	var journey_lbl = _lbl("%d%% Journey" % pct, 11, Color(0.80, 0.70, 0.50))
	journey_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	journey_box.add_child(journey_lbl)
	# Mini progress bar inside chip
	var bar_bg = PanelContainer.new()
	var bar_bg_s = StyleBoxFlat.new()
	bar_bg_s.bg_color = Color(0.12, 0.08, 0.18, 0.8)
	bar_bg_s.set_corner_radius_all(3)
	bar_bg.add_theme_stylebox_override("panel", bar_bg_s)
	bar_bg.custom_minimum_size = Vector2(100, 5)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar_fill = ColorRect.new()
	var fill_pct = clampf(float(completed_ct) / maxf(float(total_ct), 1.0), 0.0, 1.0)
	bar_fill.custom_minimum_size = Vector2(100.0 * fill_pct, 5)
	bar_fill.color = Color(0.85, 0.65, 0.15, 0.9)
	bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bg.add_child(bar_fill)
	journey_box.add_child(bar_bg)
	h.add_child(journey_chip)
	# Spacer to push currencies to center
	var spacer_l = Control.new()
	spacer_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(spacer_l)
	# CENTER: Currencies
	var acct_lvl = _main.account_level if "account_level" in _main else 1
	h.add_child(_currency_chip("Lv.%d" % acct_lvl, Color(0.85, 0.75, 0.55)))
	for c in [["🪙", _main.gold, Color(1,0.85,0.2)], ["🪶", _main.player_quills, Color(0.7,0.5,0.9)], ["📄", _main.player_pages, Color(0.3,0.75,0.9)], ["⭐", _main.player_storybook_stars, Color(1,0.9,0.3)]]:
		h.add_child(_currency_chip("%s %d" % [c[0], c[1]], c[2]))
	# Spacer to push music to right
	var spacer_r = Control.new()
	spacer_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(spacer_r)

func _currency_chip(text: String, color: Color) -> PanelContainer:
	var chip = PanelContainer.new()
	var cs = StyleBoxFlat.new()
	cs.bg_color = C_BG_SURFACE
	cs.set_corner_radius_all(CORNER_BTN)
	cs.border_color = Color(color.r * 0.7, color.g * 0.7, color.b * 0.7, 0.6)
	cs.set_border_width_all(1)
	cs.shadow_color = Color(0, 0, 0, 0.2)
	cs.shadow_size = 2
	cs.content_margin_left = 10; cs.content_margin_right = 10
	cs.content_margin_top = 4; cs.content_margin_bottom = 4
	chip.add_theme_stylebox_override("panel", cs)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l = _lbl(text, 13, color)
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
	var icon = _lbl("♫", 13, Color(0.65, 0.55, 0.80))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	music_row.add_child(icon)
	# Song title — stored for live updates
	var song_name = _get_song_name()
	_song_label = _lbl(song_name if song_name != "" else "Now Playing...", 12, Color(0.72, 0.62, 0.88))
	_song_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_song_label.clip_text = true
	_song_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_song_label.custom_minimum_size.x = 180
	_last_song = song_name
	music_row.add_child(_song_label)
	# Skip button with art styling
	var skip = _art_button(">>", Color(0.12, 0.10, 0.22), Vector2(38, 24))
	skip.add_theme_font_size_override("font_size", 12)
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
	# Solid opaque nav bar — clean, no art texture
	nav_bar.color = Color(0.04, 0.02, 0.08, 1.0)
	_build_nav_buttons()

func _build_nav_buttons() -> void:
	var tabs = ["chapters", "survivors", "emporium", "codex", "settings"]
	var labels = ["CHAPTERS", "HEROES", "SHOP", "CODEX", "SETTINGS"]
	var icons = ["📖", "⚔", "🛒", "📚", "⚙"]
	# Solid opaque nav bar with top accent line
	nav_bar.color = C_BG_DARK
	# Gold accent line at top of nav bar
	var nav_accent = ColorRect.new()
	nav_accent.set_anchors_preset(Control.PRESET_TOP_WIDE)
	nav_accent.offset_bottom = 2
	nav_accent.color = Color(0.50, 0.38, 0.12, 0.4)
	nav_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nav_bar.add_child(nav_accent)
	for i in range(5):
		var is_active = tabs[i] == current_view
		var btn = Button.new()
		btn.text = ""  # We'll use custom content
		btn.clip_text = false
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 60)
		var s = StyleBoxFlat.new()
		if is_active:
			s.bg_color = Color(0.14, 0.08, 0.22, 1.0)
			s.border_color = Color(1.0, 0.82, 0.20, 1.0)
			s.border_width_top = 3
			s.border_width_left = 0; s.border_width_right = 0; s.border_width_bottom = 0
		else:
			s.bg_color = Color(0.05, 0.03, 0.09, 1.0)
			s.border_color = Color(0.15, 0.12, 0.08, 0.3)
			s.border_width_top = 1
			s.border_width_left = 0; s.border_width_right = 0; s.border_width_bottom = 0
		s.set_corner_radius_all(0)
		btn.add_theme_stylebox_override("normal", s)
		var sh = s.duplicate()
		sh.bg_color = Color(0.18, 0.12, 0.28, 1.0)
		btn.add_theme_stylebox_override("hover", sh)
		var sp = s.duplicate()
		sp.bg_color = Color(0.22, 0.14, 0.32, 1.0)
		btn.add_theme_stylebox_override("pressed", sp)
		# Icon + text layout inside button
		var nav_content = VBoxContainer.new()
		nav_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		nav_content.alignment = BoxContainer.ALIGNMENT_CENTER
		nav_content.add_theme_constant_override("separation", 2)
		nav_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(nav_content)
		# Icon
		var icon_col = C_GOLD if is_active else C_TEXT_TERTIARY
		var icon_lbl = _lbl(icons[i], 18, icon_col)
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nav_content.add_child(icon_lbl)
		# Label
		var text_col = C_GOLD if is_active else C_TEXT_LOCKED
		var text_lbl = _lbl(labels[i], 11, text_col)
		text_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nav_content.add_child(text_lbl)
		btn.pressed.connect(_on_tab.bind(tabs[i]))
		_add_press_feedback(btn)
		nav_buttons_container.add_child(btn)

func _on_tab(tab: String) -> void:
	if current_view == tab: return
	_play_ui_click()
	_save_scroll_position()
	current_view = tab
	_set_bg(tab)
	# Rebuild nav
	for c in nav_buttons_container.get_children():
		nav_buttons_container.remove_child(c)
		c.queue_free()
	_build_nav_buttons()
	# Rebuild content
	_clear()
	content_area.position.x = 0
	content_area.modulate.a = 1.0
	match tab:
		"chapters": _build_chapters()
		"survivors": _build_survivors()
		"emporium": _build_emporium()
		"codex": _build_codex()
		"settings": _build_settings()
	_restore_scroll_position()

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
	for c in content_area.get_children():
		content_area.remove_child(c)
		c.queue_free()

# ======================== CHAPTERS ========================
func _build_chapters() -> void:
	_clear()
	if _portal_view != "":
		_build_arc_levels()
		return
	_build_portal_hub()

var _shown_play_next: bool = false

func _build_portal_hub() -> void:
	_shown_play_next = false
	# Play main theme when viewing portal hub
	if MusicManager:
		MusicManager.play_main_theme()
	var sc = ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_area.add_child(sc)
	_style_scrollbar(sc)
	_add_scroll_hint(content_area)
	# Bottom fade where cards meet nav bar (#11)
	var bottom_fade = ColorRect.new()
	bottom_fade.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_fade.offset_top = -35
	bottom_fade.color = Color(0.02, 0.01, 0.04, 0.5)
	bottom_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_area.add_child(bottom_fade)
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 4)
	sc.add_child(margin)
	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 10)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vb)
	# CONTINUE button — jump straight to next level (#15)
	if _main:
		var next_lvl = -1
		var next_name = ""
		for li in range(_main.levels.size()):
			if _main._is_level_unlocked(li) and li not in _main.completed_levels:
				next_lvl = li
				next_name = _main.levels[li].get("name", "Level %d" % li)
				break
		if next_lvl >= 0:
			var cont_btn = Button.new()
			cont_btn.text = "▶  CONTINUE — %s" % next_name
			cont_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cont_btn.custom_minimum_size = Vector2(0, 56)
			var cbs = StyleBoxFlat.new()
			cbs.bg_color = Color(0.14, 0.42, 0.14, 0.92)
			cbs.border_color = Color(0.40, 0.85, 0.30, 0.8)
			cbs.set_border_width_all(2)
			cbs.set_corner_radius_all(14)
			cbs.shadow_color = Color(0.15, 0.40, 0.10, 0.3)
			cbs.shadow_size = 6
			cont_btn.add_theme_stylebox_override("normal", cbs)
			var cbsh = cbs.duplicate()
			cbsh.bg_color = Color(0.18, 0.52, 0.18, 0.95)
			cbsh.border_color = Color(0.50, 0.95, 0.35, 0.9)
			cbsh.shadow_size = 8
			cont_btn.add_theme_stylebox_override("hover", cbsh)
			var cbsp = cbs.duplicate()
			cbsp.bg_color = Color(0.10, 0.35, 0.10, 0.95)
			cbsp.shadow_size = 3
			cont_btn.add_theme_stylebox_override("pressed", cbsp)
			cont_btn.add_theme_font_size_override("font_size", 18)
			cont_btn.add_theme_color_override("font_color", Color(1.0, 1.0, 0.95))
			cont_btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
			cont_btn.add_theme_constant_override("shadow_offset_x", 1)
			cont_btn.add_theme_constant_override("shadow_offset_y", 1)
			_add_press_feedback(cont_btn)
			# Idle pulse on continue button — draws attention
			var cont_pulse = create_tween().set_loops()
			cont_pulse.tween_property(cont_btn, "modulate", Color(1.06, 1.08, 1.04), 1.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
			cont_pulse.tween_property(cont_btn, "modulate", Color(1.0, 1.0, 1.0), 1.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
			var _next = next_lvl
			cont_btn.pressed.connect(func():
				if _main:
					_main._on_level_selected(_next))
			vb.add_child(cont_btn)
	# Portal grid — one grid per act with act headers between them
	var grid: GridContainer = null
	var _last_act = 0
	# Count realms per act for header display (#13)
	var act_realm_counts: Dictionary = {}
	for r in REALMS:
		var a = r.get("act", 1)
		act_realm_counts[a] = act_realm_counts.get(a, 0) + 1
	for ri in range(REALMS.size()):
		var realm = REALMS[ri]
		var act_num = realm.get("act", 1)
		# Act divider + new grid when act changes
		if act_num != _last_act:
			_last_act = act_num
			var act_names = {1: "ACT I — INTO THE PAGES", 2: "ACT II — THE SHADOW STORIES", 3: "ACT III — THE FINAL CHAPTER", 4: "ACT IV — THE NARRATOR'S REALM"}
			var realm_ct = act_realm_counts.get(act_num, 0)
			vb.add_child(_section_header("%s (%d Realms)" % [act_names.get(act_num, "ACT %d" % act_num), realm_ct]))
			grid = GridContainer.new()
			grid.columns = 3
			grid.add_theme_constant_override("h_separation", 14)
			grid.add_theme_constant_override("v_separation", 14)
			grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			vb.add_child(grid)
		var arc_complete = _is_realm_complete(realm)
		var arc_unlocked = _is_realm_unlocked(ri)
		var is_next_realm = arc_unlocked and not arc_complete  # First unlocked incomplete
		var rc = Color(realm["color"][0], realm["color"][1], realm["color"][2])
		# === REALM CARD (items 1-30 rebuild) ===
		var card = Button.new()
		card.text = ""
		card.custom_minimum_size = Vector2(380, 175)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		var cs = StyleBoxFlat.new()
		if arc_complete:
			cs.bg_color = Color(0.03, 0.02, 0.06, 1.0)
			cs.border_color = Color(1.0, 0.85, 0.15, 0.8)
			cs.set_border_width_all(3)
		elif arc_unlocked:
			cs.bg_color = Color(0.03, 0.02, 0.06, 1.0)
			cs.border_color = Color(rc.r * 0.7, rc.g * 0.7, rc.b * 0.7, 0.7)
			cs.set_border_width_all(2)
		else:
			cs.bg_color = Color(0.03, 0.02, 0.06, 1.0)
			cs.border_color = Color(0.35, 0.28, 0.20, 0.50)
			cs.set_border_width_all(2)
		cs.set_corner_radius_all(14)
		cs.shadow_color = Color(0, 0, 0, 0.35)
		cs.shadow_size = 6
		card.add_theme_stylebox_override("normal", cs)
		# Hover: brighten border
		var csh = cs.duplicate()
		if arc_unlocked:
			csh.bg_color = Color(rc.r * 0.22, rc.g * 0.22, rc.b * 0.22, 0.92)
			csh.border_color = Color(rc.r * 0.9, rc.g * 0.9, rc.b * 0.9, 0.9)
		card.add_theme_stylebox_override("hover", csh)
		# Pressed: darken
		var csp = cs.duplicate()
		csp.bg_color = Color(rc.r * 0.10, rc.g * 0.10, rc.b * 0.10, 0.95)
		card.add_theme_stylebox_override("pressed", csp)
		# --- REALM ART (fills entire card, no ink portal overlay) ---
		var realm_icon_key = realm["icon"]
		if _art.has(realm_icon_key):
			var realm_art = TextureRect.new()
			realm_art.texture = _art[realm_icon_key]
			realm_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			realm_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			realm_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			realm_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if arc_unlocked:
				realm_art.modulate = Color(1.0, 1.0, 1.0, 1.0)  # Crystal clear, full brightness
			else:
				realm_art.modulate = Color(0.6, 0.6, 0.6, 0.9)  # Visible but desaturated
			card.add_child(realm_art)
			# Gradient overlay for text readability — shader-based
			var realm_grad = ColorRect.new()
			realm_grad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			realm_grad.color = Color.WHITE
			realm_grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if ResourceLoader.exists("res://shaders/card_gradient.gdshader"):
				var rg_shader = load("res://shaders/card_gradient.gdshader")
				var rg_mat = ShaderMaterial.new()
				rg_mat.shader = rg_shader
				rg_mat.set_shader_parameter("gradient_start", 0.25)
				rg_mat.set_shader_parameter("gradient_strength", 0.65)
				rg_mat.set_shader_parameter("tint_color", Color(0.02, 0.01, 0.04, 1.0))
				realm_grad.material = rg_mat
			else:
				realm_grad.color = Color(0.02, 0.01, 0.04, 0.35)
			card.add_child(realm_grad)
			# Locked: dark overlay OVER the art covering entire card
			if not arc_unlocked:
				var lock_shade = ColorRect.new()
				lock_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				lock_shade.color = Color(0.02, 0.02, 0.05, 0.45)
				lock_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
				card.add_child(lock_shade)
		# --- CONTENT: Name, arc, status (items 5,6,7,8,26,27) ---
		var content = VBoxContainer.new()
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.add_theme_constant_override("separation", 2)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var content_margin = MarginContainer.new()
		content_margin.add_theme_constant_override("margin_left", 14)
		content_margin.add_theme_constant_override("margin_right", 14)
		content_margin.add_theme_constant_override("margin_top", 10)
		content_margin.add_theme_constant_override("margin_bottom", 10)
		content_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content_margin.add_child(content)
		card.add_child(content_margin)
		# Realm name — LARGE with shadow (#5)
		var name_lbl = _lbl(realm["name"], 18, Color(1.0, 0.95, 0.50) if arc_unlocked else Color(0.50, 0.45, 0.38))
		name_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		name_lbl.add_theme_constant_override("shadow_offset_x", 2)
		name_lbl.add_theme_constant_override("shadow_offset_y", 2)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(name_lbl)
		# Arc subtitle — in realm accent color (#26)
		var arc_col = Color(rc.r * 0.7 + 0.3, rc.g * 0.7 + 0.3, rc.b * 0.7 + 0.3) if arc_unlocked else Color(0.40, 0.35, 0.30)
		var arc_lbl = _lbl(realm["arc"], 12, arc_col)
		arc_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		arc_lbl.add_theme_constant_override("shadow_offset_x", 1)
		arc_lbl.add_theme_constant_override("shadow_offset_y", 1)
		arc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(arc_lbl)
		# Spacer
		var spacer_ctrl = Control.new()
		spacer_ctrl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		spacer_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(spacer_ctrl)
		# Bottom row: status + stars (#7, #8, #27)
		var level_count = realm["levels"].size()
		var levels_done = 0
		var total_stars = 0
		var max_stars = level_count * 3
		if _main and "completed_levels" in _main:
			for li in realm["levels"]:
				if li in _main.completed_levels:
					levels_done += 1
				if _main.level_stars.has(li):
					total_stars += _main.level_stars[li]
		var bottom_row = HBoxContainer.new()
		bottom_row.add_theme_constant_override("separation", 8)
		bottom_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(bottom_row)
		# Status text
		var status_text: String
		var status_col: Color
		if arc_complete:
			status_text = "COMPLETE"
			status_col = Color(0.45, 0.85, 0.35)
		elif arc_unlocked:
			status_text = "%d / %d Levels" % [levels_done, level_count]
			status_col = Color(0.75, 0.68, 0.55)
		else:
			status_text = "LOCKED"
			status_col = Color(0.60, 0.55, 0.48)
		var status = _lbl(status_text, 12, status_col)
		status.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		status.add_theme_constant_override("shadow_offset_x", 1)
		status.add_theme_constant_override("shadow_offset_y", 1)
		status.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bottom_row.add_child(status)
		# Star count (#7)
		if arc_unlocked:
			var star_lbl = _lbl("⭐ %d/%d" % [total_stars, max_stars], 11, Color(1.0, 0.85, 0.15))
			star_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bottom_row.add_child(star_lbl)
		# --- LOCKED OVERLAY: centered lock icon (#14, #15) ---
		if not arc_unlocked:
			var lock_lbl = _lbl("🔒", 36, Color(0.6, 0.6, 0.65, 0.7))
			lock_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
			lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lock_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(lock_lbl)
		# --- COMPLETE: gold checkmark + shimmer pulse (#4, #20) ---
		if arc_complete:
			var check_lbl = _lbl("✅", 18, Color(0.4, 0.85, 0.3))
			check_lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
			check_lbl.position = Vector2(8, 6)
			check_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(check_lbl)
			# Gold shimmer pulse on completed cards (#4)
			var shimmer_tw = create_tween().set_loops()
			shimmer_tw.tween_property(card, "modulate", Color(1.06, 1.04, 0.98), 1.2).set_ease(Tween.EASE_IN_OUT)
			shimmer_tw.tween_property(card, "modulate", Color(1.0, 1.0, 1.0), 1.2).set_ease(Tween.EASE_IN_OUT)
		# --- LOCKED: hero silhouette hint (#6) ---
		if not arc_unlocked:
			var pkey2 = realm["portrait"]
			if _main and _main._portrait_textures.has(pkey2):
				var silhouette = TextureRect.new()
				silhouette.texture = _main._portrait_textures[pkey2]
				silhouette.custom_minimum_size = Vector2(40, 40)
				silhouette.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				silhouette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				silhouette.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
				silhouette.position = Vector2(10, -50)
				silhouette.modulate = Color(0.2, 0.2, 0.25, 0.35)
				silhouette.mouse_filter = Control.MOUSE_FILTER_IGNORE
				card.add_child(silhouette)
		# --- "PLAY NEXT" pill badge (#2, #23) ---
		if is_next_realm and not _shown_play_next:
			_shown_play_next = true
			var pill = PanelContainer.new()
			var pill_s = StyleBoxFlat.new()
			pill_s.bg_color = Color(0.12, 0.08, 0.04, 0.85)
			pill_s.set_corner_radius_all(10)
			pill_s.border_color = Color(1.0, 0.85, 0.15, 0.6)
			pill_s.set_border_width_all(1)
			pill_s.content_margin_left = 8; pill_s.content_margin_right = 8
			pill_s.content_margin_top = 3; pill_s.content_margin_bottom = 3
			pill.add_theme_stylebox_override("panel", pill_s)
			pill.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			pill.position = Vector2(-110, 6)
			pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var banner = _lbl("▶ PLAY NEXT", 11, Color(1.0, 0.95, 0.40))
			banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pill.add_child(banner)
			card.add_child(pill)
		# --- Themed realm icon top-right (#20) ---
		var realm_icons = {"Prologue": "📖", "Neverland": "⚓", "Land of Oz": "💎", "Paris Opera": "🎭",
			"Sherlock Holmes": "🔍", "Merlin": "🔮", "Tarzan": "🌿", "Dracula": "🦇",
			"Frankenstein": "⚡", "Sherwood Forest": "🏹", "Wonderland": "🎩", "Victorian London": "👻",
			"Shadow Author": "🖋", "Alice's Trial": "♠", "Robin's Trial": "🏹", "Scrooge's Trial": "💰",
			"Headless Horseman": "🎃", "Medusa": "🐍", "Loki": "🗡", "Anubis": "☥", "The Narrator": "🔥"}
		var theme_icon = realm_icons.get(realm["arc"], "")
		if theme_icon != "":
			# Dark circle behind icon for visibility
			var icon_bg = PanelContainer.new()
			var ibs = StyleBoxFlat.new()
			ibs.bg_color = Color(0.04, 0.02, 0.08, 0.7)
			ibs.set_corner_radius_all(16)
			ibs.content_margin_left = 5; ibs.content_margin_right = 5
			ibs.content_margin_top = 3; ibs.content_margin_bottom = 3
			icon_bg.add_theme_stylebox_override("panel", ibs)
			icon_bg.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			icon_bg.position = Vector2(-38, -36)
			icon_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var icon_lbl = _lbl(theme_icon, 18, Color(1, 1, 1, 0.8) if arc_unlocked else Color(0.6, 0.6, 0.6, 0.5))
			icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon_bg.add_child(icon_lbl)
			card.add_child(icon_bg)
		# --- Pulsing glow border on next playable realm (#5) ---
		if is_next_realm and not arc_complete:
			var glow_tw = create_tween().set_loops()
			glow_tw.tween_property(card, "modulate", Color(1.08, 1.06, 1.02), 0.8).set_ease(Tween.EASE_IN_OUT)
			glow_tw.tween_property(card, "modulate", Color(1.0, 1.0, 1.0), 0.8).set_ease(Tween.EASE_IN_OUT)
		# Click to enter realm
		if arc_unlocked:
			var arc_name = realm["arc"]
			card.pressed.connect(func(): _enter_realm(arc_name))
		# Hover: brighten, no scale (#19)
		card.mouse_entered.connect(func():
			card.modulate = Color(1.12, 1.10, 1.05))
		card.mouse_exited.connect(func():
			card.modulate = Color.WHITE)
		_add_press_feedback(card)
		# Staggered entrance — fade only (position.y breaks GridContainer layout)
		grid.add_child(card)
		card.modulate.a = 0.0
		var etw = create_tween().set_ease(Tween.EASE_OUT)
		etw.tween_property(card, "modulate:a", 1.0, 0.25).set_delay(ri * 0.06)

func _enter_realm(arc_name: String) -> void:
	# Play realm-specific music + portal stinger
	if MusicManager:
		MusicManager.play_portal_stinger()
		MusicManager.play_realm_music(arc_name)
	# Check for arc intro cinematic (first time entering this realm)
	var intro_key_map = {
		"Neverland": "arc_intro_neverland", "Land of Oz": "arc_intro_oz",
		"Paris Opera": "arc_intro_opera", "Sherlock Holmes": "arc_intro_sherlock",
		"Merlin": "arc_intro_merlin", "Tarzan": "arc_intro_tarzan",
		"Dracula": "arc_intro_dracula", "Frankenstein": "arc_intro_frankenstein",
		"Sherwood Forest": "arc_intro_sherwood", "Wonderland": "arc_intro_wonderland",
		"Victorian London": "arc_intro_christmas", "Shadow Author": "arc_intro_shadow",
	}
	if intro_key_map.has(arc_name) and _main:
		var intro_key = intro_key_map[arc_name]
		if _main.story_dialogs.has(intro_key) and not intro_key in _main.story_seen:
			# Play arc intro cinematic first, then enter realm
			_portal_view = arc_name
			_main._start_story_dialog(intro_key)
			# After the dialog ends, the player returns to menu — they'll see the arc view
			return
	_portal_view = arc_name
	_build_chapters()

func _is_realm_complete(realm: Dictionary) -> bool:
	if not _main or not "completed_levels" in _main: return false
	for li in realm["levels"]:
		if li not in _main.completed_levels: return false
	return true

func _is_realm_unlocked(realm_idx: int) -> bool:
	if realm_idx == 0: return true  # Prologue always unlocked
	if not _main: return false
	# Unlock if previous realm is complete OR any level in this realm is unlocked
	var prev_realm = REALMS[realm_idx - 1]
	for li in prev_realm["levels"]:
		if li not in _main.completed_levels: return false
	return true

func _build_arc_levels() -> void:
	# Find realm for this arc
	var arc_realm = null
	for r in REALMS:
		if r["arc"] == _portal_view:
			arc_realm = r
			break
	if arc_realm == null:
		_portal_view = ""
		_build_portal_hub()
		return
	if not _main: return
	var rc = Color(arc_realm["color"][0], arc_realm["color"][1], arc_realm["color"][2])
	var arc_levels = arc_realm["levels"]
	# === REALM BACKGROUND ART — fills entire content area at 40% ===
	var realm_icon_key = arc_realm["icon"]
	if _art.has(realm_icon_key):
		var realm_bg = TextureRect.new()
		realm_bg.texture = _art[realm_icon_key]
		realm_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		realm_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		realm_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		realm_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		realm_bg.modulate.a = 0.40
		content_area.add_child(realm_bg)
		# Dark gradient overlay top-to-bottom for readability
		var bg_grad = ColorRect.new()
		bg_grad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg_grad.color = Color(0.03, 0.02, 0.06, 0.55)
		bg_grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content_area.add_child(bg_grad)
	var sc = ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_area.add_child(sc)
	_style_scrollbar(sc)
	# Bottom fade gradient where cards meet nav bar
	var bot_fade = ColorRect.new()
	bot_fade.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bot_fade.offset_top = -40
	bot_fade.color = Color(0.02, 0.01, 0.04, 0.6)
	bot_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_area.add_child(bot_fade)
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 12)
	sc.add_child(margin)
	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 12)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vb)
	# === TOP ROW: Back pill (left) + Star count (right) ===
	var top_row = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(top_row)
	# Compact back pill button — NOT full width
	var back_btn = Button.new()
	back_btn.text = "◀  REALMS"
	back_btn.custom_minimum_size = Vector2(130, 38)
	var bbs = StyleBoxFlat.new()
	bbs.bg_color = Color(0.06, 0.04, 0.10, 0.88)
	bbs.border_color = Color(0.55, 0.45, 0.20, 0.5)
	bbs.set_border_width_all(1)
	bbs.set_corner_radius_all(19)
	bbs.shadow_color = Color(0, 0, 0, 0.25)
	bbs.shadow_size = 3
	back_btn.add_theme_stylebox_override("normal", bbs)
	var bbsh = bbs.duplicate()
	bbsh.bg_color = Color(0.10, 0.07, 0.18, 0.92)
	bbsh.border_color = Color(0.70, 0.55, 0.25, 0.7)
	back_btn.add_theme_stylebox_override("hover", bbsh)
	var bbsp = bbs.duplicate()
	bbsp.bg_color = Color(0.04, 0.02, 0.08, 0.95)
	back_btn.add_theme_stylebox_override("pressed", bbsp)
	back_btn.add_theme_font_size_override("font_size", 13)
	back_btn.add_theme_color_override("font_color", Color(0.85, 0.75, 0.50))
	back_btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	back_btn.add_theme_constant_override("shadow_offset_x", 1)
	back_btn.add_theme_constant_override("shadow_offset_y", 1)
	back_btn.pressed.connect(func(): _portal_view = ""; _build_chapters())
	_add_press_feedback(back_btn)
	top_row.add_child(back_btn)
	# Spacer
	var top_spacer = Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(top_spacer)
	# Star count pill — right side to balance back button
	var arc_stars = 0
	var arc_max_stars = arc_levels.size() * 3
	for jli in arc_levels:
		if _main.level_stars.has(jli):
			arc_stars += _main.level_stars[jli]
	var star_pill = PanelContainer.new()
	var sps = StyleBoxFlat.new()
	sps.bg_color = Color(0.06, 0.04, 0.10, 0.85)
	sps.set_corner_radius_all(16)
	sps.border_color = Color(0.85, 0.65, 0.15, 0.4)
	sps.set_border_width_all(1)
	sps.content_margin_left = 14; sps.content_margin_right = 14
	sps.content_margin_top = 6; sps.content_margin_bottom = 6
	star_pill.add_theme_stylebox_override("panel", sps)
	star_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var arc_star_lbl = _lbl("⭐ %d / %d" % [arc_stars, arc_max_stars], 14, Color(1.0, 0.85, 0.15))
	arc_star_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star_pill.add_child(arc_star_lbl)
	top_row.add_child(star_pill)
	# === REALM TITLE — large, centered, with realm color accent ===
	var realm_title = _lbl(arc_realm["name"].to_upper(), 28, Color(1.0, 0.95, 0.50))
	realm_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	realm_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	realm_title.add_theme_constant_override("shadow_offset_x", 3)
	realm_title.add_theme_constant_override("shadow_offset_y", 3)
	realm_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(realm_title)
	# Arc subtitle centered
	var arc_sub = _lbl(arc_realm["arc"], 14, Color(rc.r * 0.7 + 0.3, rc.g * 0.7 + 0.3, rc.b * 0.7 + 0.3))
	arc_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arc_sub.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	arc_sub.add_theme_constant_override("shadow_offset_x", 1)
	arc_sub.add_theme_constant_override("shadow_offset_y", 1)
	arc_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(arc_sub)
	# === LEVEL CARDS — massive art-backed cards with gradient overlay ===
	var card_idx2 = 0
	var is_first_playable = true
	for li_idx in range(arc_levels.size()):
		var li = arc_levels[li_idx]
		if li >= _main.levels.size(): continue
		var lvl = _main.levels[li]
		var is_complete = li in _main.completed_levels
		var is_unlocked = _main._is_level_unlocked(li)
		var stars = _main.level_stars.get(li, 0)
		var is_next = is_unlocked and not is_complete and is_first_playable
		if is_next: is_first_playable = false
		# === CARD CONTAINER — 200px tall, full width ===
		var card = Button.new()
		card.text = ""
		card.custom_minimum_size = Vector2(0, 200)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		var cs2 = StyleBoxFlat.new()
		cs2.bg_color = Color(0.04, 0.02, 0.08, 1.0)
		if is_complete:
			cs2.border_color = Color(1.0, 0.85, 0.15, 0.8)
			cs2.set_border_width_all(3)
		elif is_next:
			cs2.border_color = Color(rc.r * 0.9, rc.g * 0.9, rc.b * 0.9, 0.85)
			cs2.set_border_width_all(3)
		elif is_unlocked:
			cs2.border_color = Color(rc.r * 0.6, rc.g * 0.6, rc.b * 0.6, 0.6)
			cs2.set_border_width_all(2)
		else:
			cs2.border_color = Color(0.25, 0.20, 0.15, 0.35)
			cs2.set_border_width_all(1)
		cs2.set_corner_radius_all(16)
		cs2.shadow_color = Color(0, 0, 0, 0.4)
		cs2.shadow_size = 8
		card.add_theme_stylebox_override("normal", cs2)
		var cs2h = cs2.duplicate()
		cs2h.bg_color = Color(0.06, 0.04, 0.12, 1.0)
		cs2h.border_color = Color(rc.r * 0.9, rc.g * 0.9, rc.b * 0.9, 0.9)
		card.add_theme_stylebox_override("hover", cs2h)
		var cs2p = cs2.duplicate()
		cs2p.bg_color = Color(0.02, 0.01, 0.04, 1.0)
		card.add_theme_stylebox_override("pressed", cs2p)
		# === MAP ART — full bleed background ===
		if _main._map_thumb_textures.has(li):
			var level_art = TextureRect.new()
			level_art.texture = _main._map_thumb_textures[li]
			level_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			level_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			level_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			level_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if is_unlocked:
				level_art.modulate = Color(1.0, 1.0, 1.0, 0.90)
			else:
				level_art.modulate = Color(0.45, 0.45, 0.50, 0.45)
			card.add_child(level_art)
		# === GRADIENT OVERLAY — shader-based bottom-to-top for text readability ===
		var grad_overlay = ColorRect.new()
		grad_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		grad_overlay.color = Color.WHITE  # Shader handles the visual
		grad_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if ResourceLoader.exists("res://shaders/card_gradient.gdshader"):
			var grad_shader = load("res://shaders/card_gradient.gdshader")
			var grad_mat = ShaderMaterial.new()
			grad_mat.shader = grad_shader
			grad_mat.set_shader_parameter("gradient_start", 0.2)
			grad_mat.set_shader_parameter("gradient_strength", 0.75)
			grad_mat.set_shader_parameter("tint_color", Color(0.02, 0.01, 0.04, 1.0))
			grad_overlay.material = grad_mat
		else:
			grad_overlay.color = Color(0.02, 0.01, 0.04, 0.45)
		card.add_child(grad_overlay)
		# === LOCKED OVERLAY ===
		if not is_unlocked:
			var lock_shade = ColorRect.new()
			lock_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			lock_shade.color = Color(0.02, 0.01, 0.04, 0.55)
			lock_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(lock_shade)
		# === CONTENT — positioned over gradient ===
		var cm2 = MarginContainer.new()
		cm2.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cm2.add_theme_constant_override("margin_left", 20)
		cm2.add_theme_constant_override("margin_right", 20)
		cm2.add_theme_constant_override("margin_top", 16)
		cm2.add_theme_constant_override("margin_bottom", 16)
		cm2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(cm2)
		var content2 = VBoxContainer.new()
		content2.add_theme_constant_override("separation", 4)
		content2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cm2.add_child(content2)
		# === TOP: Level number + name row ===
		var name_row = HBoxContainer.new()
		name_row.add_theme_constant_override("separation", 10)
		name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content2.add_child(name_row)
		# Level number badge (circle)
		var num_badge = PanelContainer.new()
		var nbs = StyleBoxFlat.new()
		nbs.set_corner_radius_all(22)
		nbs.content_margin_left = 4; nbs.content_margin_right = 4
		nbs.content_margin_top = 2; nbs.content_margin_bottom = 2
		if is_complete:
			nbs.bg_color = Color(0.15, 0.40, 0.15, 0.9)
			nbs.border_color = Color(0.40, 0.80, 0.30, 0.7)
		elif is_unlocked:
			nbs.bg_color = Color(rc.r * 0.25, rc.g * 0.25, rc.b * 0.25, 0.9)
			nbs.border_color = Color(rc.r * 0.7, rc.g * 0.7, rc.b * 0.7, 0.6)
		else:
			nbs.bg_color = Color(0.06, 0.04, 0.10, 0.75)
			nbs.border_color = Color(0.25, 0.20, 0.15, 0.4)
		nbs.set_border_width_all(2)
		num_badge.add_theme_stylebox_override("panel", nbs)
		num_badge.custom_minimum_size = Vector2(44, 44)
		num_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var num_lbl = _lbl(str(li_idx + 1), 18, Color(1.0, 0.92, 0.40) if is_unlocked else Color(0.45, 0.38, 0.32))
		num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		num_badge.add_child(num_lbl)
		name_row.add_child(num_badge)
		# Level name column
		var name_col = VBoxContainer.new()
		name_col.add_theme_constant_override("separation", 2)
		name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_row.add_child(name_col)
		var name_color = Color(1.0, 0.97, 0.85) if is_unlocked else Color(0.50, 0.45, 0.38)
		var name_lbl2 = _lbl(lvl.get("name", "Level %d" % (li + 1)), 26, name_color)
		name_lbl2.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
		name_lbl2.add_theme_constant_override("shadow_offset_x", 2)
		name_lbl2.add_theme_constant_override("shadow_offset_y", 2)
		name_lbl2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_col.add_child(name_lbl2)
		# Subtitle with wave count + difficulty info
		var wave_ct = _main.difficulty_waves[0] if "difficulty_waves" in _main else 20
		var sub_parts = []
		var sub_raw = lvl.get("subtitle", "")
		if sub_raw != "": sub_parts.append(sub_raw)
		sub_parts.append("%d Waves" % wave_ct)
		var sub_lbl2 = _lbl(" · ".join(sub_parts), 13, Color(rc.r * 0.65 + 0.35, rc.g * 0.65 + 0.35, rc.b * 0.65 + 0.35) if is_unlocked else Color(0.42, 0.38, 0.32))
		sub_lbl2.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		sub_lbl2.add_theme_constant_override("shadow_offset_x", 1)
		sub_lbl2.add_theme_constant_override("shadow_offset_y", 1)
		sub_lbl2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_col.add_child(sub_lbl2)
		# === BADGES — top right corner ===
		if is_next:
			var next_pill = PanelContainer.new()
			var nxs = StyleBoxFlat.new()
			nxs.bg_color = Color(0.85, 0.60, 0.08, 0.9)
			nxs.set_corner_radius_all(10)
			nxs.content_margin_left = 10; nxs.content_margin_right = 10
			nxs.content_margin_top = 4; nxs.content_margin_bottom = 4
			next_pill.add_theme_stylebox_override("panel", nxs)
			next_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var next_lbl = _lbl("▶ PLAY NEXT", 12, Color.WHITE)
			next_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			next_pill.add_child(next_lbl)
			name_row.add_child(next_pill)
		elif is_complete:
			var done_pill = PanelContainer.new()
			var dps = StyleBoxFlat.new()
			dps.bg_color = Color(0.12, 0.40, 0.12, 0.85)
			dps.set_corner_radius_all(10)
			dps.content_margin_left = 10; dps.content_margin_right = 10
			dps.content_margin_top = 4; dps.content_margin_bottom = 4
			done_pill.add_theme_stylebox_override("panel", dps)
			done_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var done_lbl = _lbl("✓ COMPLETE", 12, Color(0.50, 0.95, 0.40))
			done_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			done_pill.add_child(done_lbl)
			name_row.add_child(done_pill)
		# === SPACER ===
		var sp2 = Control.new()
		sp2.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sp2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content2.add_child(sp2)
		# === BOTTOM ROW: Stars (left) + Play button (right) ===
		var bot_row = HBoxContainer.new()
		bot_row.add_theme_constant_override("separation", 10)
		bot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content2.add_child(bot_row)
		# 3 big stars with glow background
		var star_box = HBoxContainer.new()
		star_box.add_theme_constant_override("separation", 6)
		star_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for si in range(3):
			var earned = si < stars
			var s_col2 = Color(1.0, 0.85, 0.15) if earned else Color(0.35, 0.30, 0.22, 0.6)
			var s_lbl2 = _lbl("★", 30, s_col2)
			s_lbl2.add_theme_color_override("font_shadow_color", Color(0.5, 0.35, 0.0, 0.5) if earned else Color(0, 0, 0, 0.5))
			s_lbl2.add_theme_constant_override("shadow_offset_x", 0)
			s_lbl2.add_theme_constant_override("shadow_offset_y", 2)
			s_lbl2.mouse_filter = Control.MOUSE_FILTER_IGNORE
			star_box.add_child(s_lbl2)
		bot_row.add_child(star_box)
		# Difficulty medals (if completed on different difficulties)
		if is_complete and "level_difficulty_medals" in _main and _main.level_difficulty_medals.has(li):
			var medals = _main.level_difficulty_medals[li]
			var medal_names = ["E", "M", "H"]
			var medal_colors = [Color(0.72, 0.45, 0.20), Color(0.85, 0.85, 0.92), Color(1.0, 0.85, 0.15)]
			var medal_box = HBoxContainer.new()
			medal_box.add_theme_constant_override("separation", 4)
			medal_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			for mi in range(mini(medals.size(), 3)):
				var m_earned = medals[mi] if mi < medals.size() else false
				var m_lbl = _lbl(medal_names[mi], 12, medal_colors[mi] if m_earned else Color(0.30, 0.25, 0.20, 0.4))
				m_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				medal_box.add_child(m_lbl)
			bot_row.add_child(medal_box)
		# Spacer to push play button right
		var bot_spacer = Control.new()
		bot_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bot_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bot_row.add_child(bot_spacer)
		# PLAY button or LOCKED indicator — in the layout flow, NOT absolute positioned
		if is_unlocked:
			var play_btn2 = Button.new()
			play_btn2.text = "▶  PLAY"
			play_btn2.custom_minimum_size = Vector2(120, 44)
			var pbs2 = StyleBoxFlat.new()
			pbs2.bg_color = Color(0.15, 0.50, 0.15, 0.92)
			pbs2.border_color = Color(0.40, 0.85, 0.30, 0.8)
			pbs2.set_border_width_all(2)
			pbs2.set_corner_radius_all(12)
			pbs2.shadow_color = Color(0.2, 0.5, 0.1, 0.25)
			pbs2.shadow_size = 4
			play_btn2.add_theme_stylebox_override("normal", pbs2)
			var pbs2h = pbs2.duplicate()
			pbs2h.bg_color = Color(0.20, 0.60, 0.20, 0.95)
			pbs2h.shadow_size = 6
			play_btn2.add_theme_stylebox_override("hover", pbs2h)
			var pbs2p = pbs2.duplicate()
			pbs2p.bg_color = Color(0.10, 0.40, 0.10, 0.95)
			pbs2p.shadow_size = 2
			play_btn2.add_theme_stylebox_override("pressed", pbs2p)
			play_btn2.add_theme_font_size_override("font_size", 16)
			play_btn2.add_theme_color_override("font_color", Color(1.0, 1.0, 0.95))
			play_btn2.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
			play_btn2.add_theme_constant_override("shadow_offset_x", 1)
			play_btn2.add_theme_constant_override("shadow_offset_y", 1)
			var _li2 = li
			play_btn2.pressed.connect(func():
				if _main: _main._on_level_selected(_li2))
			_add_press_feedback(play_btn2)
			bot_row.add_child(play_btn2)
		else:
			var lock_pill = PanelContainer.new()
			var lps = StyleBoxFlat.new()
			lps.bg_color = Color(0.06, 0.04, 0.10, 0.7)
			lps.set_corner_radius_all(12)
			lps.border_color = Color(0.35, 0.28, 0.18, 0.4)
			lps.set_border_width_all(1)
			lps.content_margin_left = 16; lps.content_margin_right = 16
			lps.content_margin_top = 8; lps.content_margin_bottom = 8
			lock_pill.add_theme_stylebox_override("panel", lps)
			lock_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var lock_row = HBoxContainer.new()
			lock_row.add_theme_constant_override("separation", 6)
			lock_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lock_pill.add_child(lock_row)
			lock_row.add_child(_lbl("🔒", 18, Color(0.55, 0.50, 0.42)))
			lock_row.add_child(_lbl("Complete previous", 12, Color(0.50, 0.45, 0.38)))
			bot_row.add_child(lock_pill)
		# === CLICK HANDLERS ===
		if is_unlocked:
			var _li3 = li
			card.pressed.connect(func():
				if _main: _main._on_level_selected(_li3))
		# === HOVER + PRESS EFFECTS ===
		card.mouse_entered.connect(func():
			card.modulate = Color(1.12, 1.10, 1.05))
		card.mouse_exited.connect(func():
			card.modulate = Color.WHITE)
		_add_press_feedback(card)
		# === NEXT LEVEL PULSE ===
		if is_next:
			var pulse_tw = create_tween().set_loops()
			pulse_tw.tween_property(card, "modulate", Color(1.08, 1.06, 1.02), 0.8).set_ease(Tween.EASE_IN_OUT)
			pulse_tw.tween_property(card, "modulate", Color(1.0, 1.0, 1.0), 0.8).set_ease(Tween.EASE_IN_OUT)
		# === STAGGERED ENTRANCE — slide up + fade ===
		vb.add_child(card)
		card.modulate.a = 0.0
		card.position.y += 30
		var etw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		etw.set_parallel(true)
		etw.tween_property(card, "modulate:a", 1.0, 0.3).set_delay(card_idx2 * 0.08)
		etw.tween_property(card, "position:y", 0.0, 0.35).set_delay(card_idx2 * 0.08)
		card_idx2 += 1
	# === SCROLL DOWN HINT (if more than 2 levels) ===
	if arc_levels.size() > 2:
		var hint = _lbl("▼  Scroll for more levels  ▼", 12, Color(0.55, 0.48, 0.40, 0.6))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(hint)
		# Fade out hint after 3 seconds
		var htw = create_tween()
		htw.tween_property(hint, "modulate:a", 0.0, 0.5).set_delay(3.0)

	# Old chapters view removed — 647 lines of dead code deleted (commit f6467ae)
	# Was: linear level list, _level_card(), Shadow Author quotes, arc headers
	# Replaced by: portal hub + realm detail card system (above)
	pass

# (dead code deleted — see docs/MENU_AUDIT_1000.md items 751-760)
# Old: linear chapter view, _level_card(), Shadow Author quotes,
# arc headers, progress bars, tips — all replaced by portal hub system

# ======================== SURVIVORS ========================
func _build_survivors() -> void:
	_clear()
	if not _main: return
	var unlocked_ct = 0
	for tt in _main.survivor_types:
		if _main._is_character_unlocked(tt): unlocked_ct += 1
	# Add rescued count to top bar (purple chip, right of journey)
	var rescued_chip = _currency_chip("🛡 %d/%d" % [unlocked_ct, _main.survivor_types.size()], Color(0.6, 0.4, 0.85))
	# Insert into top bar's HBox if possible
	for c in top_bar.get_children():
		if c is MarginContainer:
			for cc in c.get_children():
				if cc is HBoxContainer:
					# Add before the right spacer
					var child_count = cc.get_child_count()
					if child_count > 1:
						cc.add_child(rescued_chip)
						cc.move_child(rescued_chip, child_count - 1)  # Before last spacer
					break
			break
	var sc = ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_area.add_child(sc)
	_style_scrollbar(sc)
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 4)
	sc.add_child(margin)
	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 12)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vb)
	# Title only — no scholar badge, no team power, no tips
	vb.add_child(_section_header("SURVIVORS"))
	# Character grid immediately
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
		# Staggered entrance — fade only (position.y breaks GridContainer)
		card.modulate.a = 0.0
		var tw = create_tween().set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "modulate:a", 1.0, 0.2).set_delay(i * 0.04)

func _survivor_card(idx: int) -> Button:
	# Check if character is unlocked
	var is_unlocked = false
	var tt = _main.survivor_types[idx] if _main and idx < _main.survivor_types.size() else null
	if tt != null and _main:
		is_unlocked = _main._is_character_unlocked(tt)
	# The card IS a Button — fills grid cell
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(260, 280)
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
	sh.bg_color = Color(0.10, 0.07, 0.18, 0.85) if is_unlocked else Color(0.07, 0.05, 0.12, 0.65)
	sh.border_color = Color(0.80, 0.60, 0.25, 0.9) if is_unlocked else Color(0.35, 0.28, 0.18, 0.5)
	sh.shadow_size = 6
	btn.add_theme_stylebox_override("hover", sh)
	var sp = s.duplicate()
	sp.bg_color = Color(0.12, 0.08, 0.20, 0.9)
	sp.shadow_size = 3
	btn.add_theme_stylebox_override("pressed", sp)
	btn.text = ""
	# Art frame — use gothic char card if available
	var frame_key = "char_card_art" if _art.has("char_card_art") else ("survivor_card_frame" if _art.has("survivor_card_frame") else "card_frame")
	if _art.has(frame_key):
		var frame_art = TextureRect.new()
		frame_art.texture = _art[frame_key]
		frame_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		frame_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		frame_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame_art.modulate.a = 0.25  # Subtle frame — portrait is primary visual
		var mat = _make_black_key_mat(0.06, 0.04)
		if mat: frame_art.material = mat
		btn.add_child(frame_art)
	# Gradient overlay — dark at bottom for text readability
	var surv_grad = ColorRect.new()
	surv_grad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surv_grad.color = Color.WHITE
	surv_grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists("res://shaders/card_gradient.gdshader"):
		var sg_shader = load("res://shaders/card_gradient.gdshader")
		var sg_mat = ShaderMaterial.new()
		sg_mat.shader = sg_shader
		sg_mat.set_shader_parameter("gradient_start", 0.5)
		sg_mat.set_shader_parameter("gradient_strength", 0.55)
		sg_mat.set_shader_parameter("tint_color", Color(0.03, 0.02, 0.06, 1.0))
		surv_grad.material = sg_mat
	else:
		surv_grad.color = Color(0.03, 0.02, 0.06, 0.0)  # Invisible fallback
	btn.add_child(surv_grad)
	# Content fills entire button area — centered
	var vb = VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vb)
	# Portrait — fills width, centered. Silhouette if locked.
	var port = TextureRect.new()
	port.custom_minimum_size = Vector2(0, 200)
	port.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	port.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	port.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	port.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pkey = PORTRAIT_KEYS[idx]
	if _main and _main._portrait_textures.has(pkey):
		port.texture = _main._portrait_textures[pkey]
		if not is_unlocked:
			port.modulate = Color(0.22, 0.18, 0.28)  # Visible hint of character
	vb.add_child(port)
	# Name — show "???" for locked
	var cname = _main.character_names[idx] if _main and idx < _main.character_names.size() else "?"
	var display_name = cname.to_upper() if is_unlocked else "???"
	var nl = _lbl(display_name, 13, Color(1, 0.92, 0.45) if is_unlocked else Color(0.45, 0.38, 0.32))
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
	var tl = _lbl(ctitle if is_unlocked else "", 11, Color(0.65, 0.58, 0.50))
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
		var mastery_col = Color(0.65, 0.58, 0.50)
		if lvl >= 8: mastery_col = Color(1.0, 0.7, 0.1)
		elif lvl >= 6: mastery_col = Color(0.6, 0.3, 0.9)
		elif lvl >= 4: mastery_col = Color(0.2, 0.5, 0.9)
		var badge = _lbl("Lv.%d — %s" % [lvl, mastery], 10, mastery_col)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(badge)
	# Novel, bond, gear — shown in detail view only (too cramped on card)
	btn.pressed.connect(_open_survivor_detail.bind(idx))
	# Hover effect
	btn.mouse_entered.connect(func():
		btn.pivot_offset = btn.size / 2.0
		var tw = btn.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1))
	btn.mouse_exited.connect(func():
		var tw = btn.create_tween().set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.08))
	# Shimmer glow on high-level characters (level 5+)
	if is_unlocked and char_level >= 5:
		var shimmer = create_tween().set_loops()
		shimmer.tween_property(btn, "modulate", Color(1.08, 1.06, 1.02), 1.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		shimmer.tween_property(btn, "modulate", Color(1.0, 1.0, 1.0), 1.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
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
		detail_bg.modulate.a = 0.25  # Subtle art — content is primary
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
	pfs.bg_color = Color(0.06, 0.04, 0.10, 0.5)
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
	tab_row.add_theme_constant_override("separation", 6)
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
		ts.set_corner_radius_all(8)
		ts.border_color = Color(0.85, 0.65, 0.20, 0.7) if is_active_tab else Color(0.25, 0.20, 0.15, 0.3)
		ts.set_border_width_all(2 if is_active_tab else 1)
		if is_active_tab:
			ts.shadow_color = Color(0, 0, 0, 0.25)
			ts.shadow_size = 3
		tb.add_theme_stylebox_override("normal", ts)
		var tsh = ts.duplicate()
		tsh.bg_color = Color(0.20, 0.14, 0.32, 0.9)
		tsh.border_color = Color(0.70, 0.55, 0.20, 0.6)
		tb.add_theme_stylebox_override("hover", tsh)
		tb.add_theme_font_size_override("font_size", 11)
		tb.add_theme_color_override("font_color", Color(1, 0.92, 0.45) if is_active_tab else Color(0.70, 0.62, 0.52))
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
			right.add_child(_lbl("%d / %d XP to Level %d" % [xp, next_xp, level + 1], 10, Color(0.60, 0.55, 0.48)))
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
		# DPS calculation + cost
		var dmg = info.get("damage", 0)
		var rate = info.get("fire_rate", 1.0)
		var dps = dmg * rate if rate > 0 else 0
		var cost_row = HBoxContainer.new()
		cost_row.add_theme_constant_override("separation", 16)
		cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost_row.add_child(_lbl("⚔ DPS: %.1f" % dps, 12, Color(0.9, 0.3, 0.2)))
		cost_row.add_child(_lbl("🪙 Cost: %d" % info.get("cost", 0), 12, Color(0.85, 0.70, 0.20)))
		cost_row.add_child(_lbl("📏 Range: %d" % int(info.get("range", 0)), 12, Color(0.3, 0.7, 0.9)))
		right.add_child(cost_row)
	# === TAB 1: GEAR ===
	if _detail_tab == 0 or _detail_tab == 1:
		right.add_child(_section_header("GEAR SLOTS"))
		# Show 5 gear slots
		if "GEAR_SLOTS" in _main:
			var slots_grid = GridContainer.new()
			slots_grid.columns = 5
			slots_grid.add_theme_constant_override("h_separation", 6)
			slots_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
			for slot in _main.GEAR_SLOTS:
				var slot_panel = PanelContainer.new()
				var sps = StyleBoxFlat.new()
				var has_gear = false
				if "character_gear_slots" in _main and _main.character_gear_slots.has(tt):
					has_gear = _main.character_gear_slots[tt].has(slot) and _main.character_gear_slots[tt][slot] != ""
				sps.bg_color = Color(0.08, 0.06, 0.14, 0.6) if has_gear else Color(0.06, 0.04, 0.10, 0.4)
				sps.set_corner_radius_all(8)
				sps.border_color = Color(0.65, 0.50, 0.20, 0.5) if has_gear else Color(0.25, 0.20, 0.15, 0.3)
				sps.set_border_width_all(1)
				sps.content_margin_left = 8; sps.content_margin_right = 8
				sps.content_margin_top = 6; sps.content_margin_bottom = 6
				slot_panel.add_theme_stylebox_override("panel", sps)
				slot_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
				slot_panel.custom_minimum_size = Vector2(60, 50)
				var sv = VBoxContainer.new()
				sv.alignment = BoxContainer.ALIGNMENT_CENTER
				sv.mouse_filter = Control.MOUSE_FILTER_IGNORE
				slot_panel.add_child(sv)
				var slot_name = _main.GEAR_SLOT_NAMES.get(slot, slot) if "GEAR_SLOT_NAMES" in _main else slot
				# Show gear art icon if available
				var gear_icon_key = "gear_" + slot
				if _art.has(gear_icon_key):
					var gi = TextureRect.new()
					gi.texture = _art[gear_icon_key]
					gi.custom_minimum_size = Vector2(32, 32)
					gi.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					gi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					gi.mouse_filter = Control.MOUSE_FILTER_IGNORE
					if not has_gear:
						gi.modulate = Color(0.3, 0.25, 0.2, 0.4)
					var mat = _make_black_key_mat(0.08, 0.05)
					if mat: gi.material = mat
					sv.add_child(gi)
				else:
					sv.add_child(_lbl(slot_name, 10, Color(0.65, 0.55, 0.45)))
				if has_gear:
					sv.add_child(_lbl("✓", 10, Color(0.4, 0.8, 0.3)))
				else:
					sv.add_child(_lbl(slot.capitalize(), 10, Color(0.40, 0.35, 0.30)))
				# Make slot clickable to equip gear
				var slot_btn = Button.new()
				slot_btn.text = ""
				slot_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				slot_btn.flat = true
				var _slot_name = slot
				slot_btn.pressed.connect(func(): _open_slot_picker(idx, tt, _slot_name))
				_add_press_feedback(slot_btn)
				slot_panel.add_child(slot_btn)
				slots_grid.add_child(slot_panel)
			right.add_child(slots_grid)
		right.add_child(_section_header("EQUIPPED GEAR"))
	if tt != null and _main.survivor_gear.has(tt):
		var gear = _main.survivor_gear[tt]
		var gp = PanelContainer.new()
		var gs = StyleBoxFlat.new()
		gs.bg_color = Color(0.07, 0.05, 0.12, 0.5)
		gs.set_corner_radius_all(8)
		gs.set_border_width_all(2)
		gs.border_color = Color(0.65, 0.50, 0.20, 0.6)
		gs.shadow_color = Color(0, 0, 0, 0.2)
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
			gear_art.modulate.a = 0.20  # Subtle art — gear info is primary
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
			var gear_action_row = HBoxContainer.new()
			gear_action_row.add_theme_constant_override("separation", 8)
			gear_action_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var equip_btn = _art_button("CHANGE GEAR", Color(0.12, 0.35, 0.15), Vector2(130, 34))
			equip_btn.pressed.connect(func(): _open_gear_picker(idx, tt))
			gear_action_row.add_child(equip_btn)
			var skin_btn = _art_button("👕 SKINS", Color(0.35, 0.15, 0.45), Vector2(100, 34))
			skin_btn.pressed.connect(func(): _open_skin_shop(idx))
			gear_action_row.add_child(skin_btn)
			right.add_child(gear_action_row)
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
					bps.set_corner_radius_all(8)
					bps.border_color = Color(0.8, 0.5, 0.2, 0.4)
					bps.set_border_width_all(1)
					bps.content_margin_left = 8; bps.content_margin_right = 8
					bps.content_margin_top = 6; bps.content_margin_bottom = 6
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
			sks.bg_color = Color(0.07, 0.05, 0.12, 0.45)
			sks.set_corner_radius_all(8)
			sks.content_margin_left = 8; sks.content_margin_right = 8
			sks.content_margin_top = 6; sks.content_margin_bottom = 6
			skp.add_theme_stylebox_override("panel", sks)
			skp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var sk_row = HBoxContainer.new()
			sk_row.add_theme_constant_override("separation", 8)
			sk_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			skp.add_child(sk_row)
			sk_row.add_child(_lbl(sk.get("name",""), 12, Color(0.9, 0.82, 0.55)))
			var sk_desc = _lbl(sk.get("desc",""), 11, Color(0.70, 0.62, 0.52))
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
			abs.set_corner_radius_all(8)
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
			var icon_color = Color(0.4, 0.8, 0.3) if unlocked_ab else Color(0.45, 0.38, 0.32)
			ab_row.add_child(_lbl(icon_text, 12, icon_color))
			var ab_name = _lbl(ability_names[ai], 11, Color(0.8, 0.9, 0.6) if unlocked_ab else Color(0.4, 0.35, 0.30))
			ab_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ab_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ab_row.add_child(ab_name)
			var tier_lbl = _lbl("Tier %d" % (ai + 1), 11, Color(0.65, 0.58, 0.50))
			tier_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ab_row.add_child(tier_lbl)
			right.add_child(ab_panel)
	else:
		right.add_child(_lbl("Unlock abilities through combat damage", 10, Color(0.60, 0.55, 0.48)))

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
		cs.bg_color = Color(0.07, 0.05, 0.12, 0.6)
		cs.border_color = Color(0.45, 0.35, 0.20, 0.4)
		cs.set_border_width_all(1)
		cs.set_corner_radius_all(8)
		cs.content_margin_left = 8; cs.content_margin_right = 8
		cs.content_margin_top = 6; cs.content_margin_bottom = 6
		card.add_theme_stylebox_override("normal", cs)
		var csh = cs.duplicate()
		csh.bg_color = Color(0.10, 0.07, 0.18, 0.8)
		csh.border_color = Color(0.65, 0.50, 0.20, 0.7)
		card.add_theme_stylebox_override("hover", csh)
		_add_press_feedback(card)
		card.mouse_entered.connect(func():
			card.pivot_offset = card.size / 2.0
			var tw = card.create_tween().set_ease(Tween.EASE_OUT)
			tw.tween_property(card, "scale", Vector2(1.05, 1.05), 0.08))
		card.mouse_exited.connect(func():
			var tw = card.create_tween().set_ease(Tween.EASE_OUT)
			tw.tween_property(card, "scale", Vector2(1.0, 1.0), 0.06))
		var cv = VBoxContainer.new()
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(cv)
		var icon_bg2 = PanelContainer.new()
		icon_bg2.custom_minimum_size = Vector2(68, 68)
		icon_bg2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ibg_sb2 = StyleBoxFlat.new()
		ibg_sb2.bg_color = Color(0.04, 0.02, 0.08, 0.95)
		ibg_sb2.set_corner_radius_all(6)
		ibg_sb2.content_margin_left = 2; ibg_sb2.content_margin_right = 2
		ibg_sb2.content_margin_top = 2; ibg_sb2.content_margin_bottom = 2
		icon_bg2.add_theme_stylebox_override("panel", ibg_sb2)
		var icon = TextureRect.new()
		icon.texture = _main._gear_icon_textures[gk]
		icon.custom_minimum_size = Vector2(64, 64)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shader_res2 = load("res://shaders/white_key.gdshader")
		if shader_res2:
			var mat2 = ShaderMaterial.new()
			mat2.shader = shader_res2
			mat2.set_shader_parameter("threshold", 0.75)
			icon.material = mat2
		icon_bg2.add_child(icon)
		cv.add_child(icon_bg2)
		var name_lbl = _lbl(gk.replace("_", " ").capitalize(), 11, Color(0.65, 0.58, 0.50))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.clip_text = true
		name_lbl.custom_minimum_size.x = 90
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(name_lbl)
		grid.add_child(card)

func _show_popup(title: String, message: String, confirm_text: String = "OK", on_confirm: Callable = Callable()) -> void:
	# Use Godot's AcceptDialog for reliable button handling
	var dialog = AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	dialog.ok_button_text = confirm_text if on_confirm.is_valid() else "OK"
	dialog.min_size = Vector2(400, 150)
	# Style the dialog
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.06, 0.15, 0.98)
	panel_style.set_corner_radius_all(10)
	panel_style.border_color = Color(0.65, 0.50, 0.20, 0.6)
	panel_style.set_border_width_all(2)
	dialog.add_theme_stylebox_override("panel", panel_style)
	dialog.add_theme_color_override("font_color", Color(0.85, 0.78, 0.60))
	if on_confirm.is_valid():
		dialog.confirmed.connect(func(): on_confirm.call(); dialog.queue_free())
		# Add cancel button
		dialog.add_cancel_button("CANCEL")
	dialog.canceled.connect(func(): dialog.queue_free())
	# Must be in tree to show
	add_child(dialog)
	dialog.popup_centered()

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
	bar_style.bg_color = Color(0.06, 0.04, 0.10, 0.85)
	bar_style.set_corner_radius_all(8)
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
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	sc.add_child(margin)
	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 10)
	margin.add_child(vb)
	vb.add_child(_title("THE EMPORIUM"))
	var shop_desc = _lbl("Browse wares from across the literary worlds", 12, Color(0.60, 0.55, 0.48))
	shop_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(shop_desc)
	if not _main: return
	# Shop rotation timer — bigger, centered
	var time_dict = Time.get_time_dict_from_system()
	var hours_left = 24 - time_dict.get("hour", 0)
	var timer_panel = PanelContainer.new()
	var tps = StyleBoxFlat.new()
	tps.bg_color = Color(0.06, 0.04, 0.10, 0.5)
	tps.set_corner_radius_all(8)
	tps.content_margin_left = 12; tps.content_margin_right = 12
	tps.content_margin_top = 6; tps.content_margin_bottom = 6
	timer_panel.add_theme_stylebox_override("panel", tps)
	timer_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var timer_lbl = _lbl("🕐 Shop refreshes in %dh  •  🪙 %d Gold  •  🪶 %d Quills  •  📄 %d Pages" % [hours_left, _main.gold, _main.player_quills, _main.player_pages], 11, Color(0.65, 0.58, 0.50))
	timer_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_panel.add_child(timer_lbl)
	vb.add_child(timer_panel)
	# Limited time offer banner — BIG and dramatic
	var lto_panel = PanelContainer.new()
	var ltos = StyleBoxFlat.new()
	ltos.bg_color = Color(0.15, 0.04, 0.04, 0.7)
	ltos.set_corner_radius_all(12)
	ltos.border_color = Color(1.0, 0.30, 0.15, 0.7)
	ltos.set_border_width_all(2)
	ltos.shadow_color = Color(0.5, 0.1, 0.05, 0.2)
	ltos.shadow_size = 4
	ltos.content_margin_left = 16; ltos.content_margin_right = 16
	ltos.content_margin_top = 10; ltos.content_margin_bottom = 10
	lto_panel.add_theme_stylebox_override("panel", ltos)
	lto_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lto_row = HBoxContainer.new()
	lto_row.add_theme_constant_override("separation", 10)
	lto_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lto_panel.add_child(lto_row)
	lto_row.add_child(_lbl("🔥 LIMITED OFFER", 13, Color(1.0, 0.4, 0.2)))
	var offers = ["Starter Pack: 500 Gold + 50 Pages", "Hero Bundle: 3 Gear Chests + XP Boost", "Shadow Bundle: 1000 Gold + 100 Quills"]
	var lto_desc = _lbl(offers[randi() % offers.size()], 11, Color(0.85, 0.78, 0.65))
	lto_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lto_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lto_row.add_child(lto_desc)
	var time_d = Time.get_time_dict_from_system()
	lto_row.add_child(_lbl("⏰ %dh left" % (24 - time_d.get("hour", 0)), 10, Color(0.9, 0.3, 0.2)))
	vb.add_child(lto_panel)
	# Pulse the offer
	var lto_tw = create_tween().set_loops()
	lto_tw.tween_property(lto_panel, "modulate", Color(1.2, 1.1, 1.0), 0.8).set_ease(Tween.EASE_IN_OUT)
	lto_tw.tween_property(lto_panel, "modulate", Color(1.0, 1.0, 1.0), 0.8).set_ease(Tween.EASE_IN_OUT)
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
		deals_panel.custom_minimum_size = Vector2(0, 60)
		deals_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# No art overlay — daily_deals_banner.png had baked-in text that clashed
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
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(grid)
	for ci in range(_main.emporium_categories.size()):
		var cat = _main.emporium_categories[ci]
		var accent = EMPORIUM_COLORS[ci % EMPORIUM_COLORS.size()]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 90)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.text = ""
		# Card panel — mostly transparent so art frame shows
		var s = StyleBoxFlat.new()
		s.bg_color = Color(0.07, 0.05, 0.12, 0.25)
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
		# Art layer behind content — use gothic panel if available
		var card_art_key = "panel_gothic" if _art.has("panel_gothic") else "shop_card"
		if _art.has(card_art_key):
			var card_art = TextureRect.new()
			card_art.texture = _art[card_art_key]
			card_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			card_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			card_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			card_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card_art.modulate.a = 0.45  # Visible but doesn't compete with text
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
		var icon_frame = PanelContainer.new()
		icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ifs = StyleBoxFlat.new()
		ifs.bg_color = Color(0.04, 0.02, 0.08, 0.8)
		ifs.set_corner_radius_all(8)
		ifs.content_margin_left = 4; ifs.content_margin_right = 4
		ifs.content_margin_top = 4; ifs.content_margin_bottom = 4
		icon_frame.add_theme_stylebox_override("panel", ifs)
		var icon_rect = TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(80, 80)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _main._emporium_icon_textures.has(icon_key):
			icon_rect.texture = _main._emporium_icon_textures[icon_key]
			var wk = load("res://shaders/white_key.gdshader")
			if wk:
				var wkm = ShaderMaterial.new()
				wkm.shader = wk
				wkm.set_shader_parameter("threshold", 0.75)
				icon_rect.material = wkm
		icon_frame.add_child(icon_rect)
		row.add_child(icon_frame)
		# Text column
		var text_col = VBoxContainer.new()
		text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_lbl = _lbl(cat.get("name",""), 14, accent)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_col.add_child(name_lbl)
		var d = _lbl(cat.get("desc",""), 11, Color(0.70, 0.62, 0.52))
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
			var bl = _lbl(badge_text, 11, Color.WHITE)
			bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			badge_panel.add_child(bl)
			row.add_child(badge_panel)
		btn.pressed.connect(_open_emporium_category.bind(ci))
		_add_press_feedback(btn)
		# Add item count hint with arrow
		var item_ct = _lbl("▸", 14, Color(0.55, 0.45, 0.30))
		item_ct.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(item_ct)
		# Hover feedback on ALL emporium cards
		btn.mouse_entered.connect(func():
			btn.pivot_offset = btn.size / 2.0
			var tw = btn.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			tw.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.1))
		btn.mouse_exited.connect(func():
			var tw = btn.create_tween().set_ease(Tween.EASE_OUT)
			tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.08))
		# Extra glow for badged cards
		var badge_val = cat.get("badge", "")
		if badge_val == "SALE!" or badge_val == "NEW!" or badge_val == "FREE!":
			var glow_tw = create_tween().set_loops()
			glow_tw.tween_property(btn, "modulate", Color(1.08, 1.06, 1.0), 1.0).set_ease(Tween.EASE_IN_OUT)
			glow_tw.tween_property(btn, "modulate", Color(1.0, 1.0, 1.0), 1.0).set_ease(Tween.EASE_IN_OUT)
		grid.add_child(btn)
		# Staggered entrance — fade only (position.y breaks GridContainer)
		btn.modulate.a = 0.0
		var etw_emp = create_tween().set_ease(Tween.EASE_OUT)
		etw_emp.tween_property(btn, "modulate:a", 1.0, 0.2).set_delay(ci * 0.05)

func _open_emporium_category(cat_idx: int) -> void:
	_clear()
	var sc = ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_area.add_child(sc)
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
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
	cur_row.add_theme_constant_override("separation", 8)
	cur_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cur_row.add_child(_currency_chip("🪙 %d" % _main.gold, Color(1, 0.85, 0.2)))
	cur_row.add_child(_currency_chip("🪶 %d" % _main.player_quills, Color(0.7, 0.5, 0.9)))
	cur_row.add_child(_currency_chip("📄 %d" % _main.player_pages, Color(0.3, 0.75, 0.9)))
	vb.add_child(cur_row)
	# Show items based on category
	match cat_idx:
		0: _build_gold_exchange(vb)
		1: _build_quill_shop(vb)
		2: _build_gear_shard_shop(vb)
		3: _build_gear_crafting(vb)
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
		["250 Gold", "15 Pages", 250, "pages", 15, Color(1,0.85,0.2), Color(0.3,0.75,0.9)],
		["500 Gold", "3 Stars", 500, "stars", 3, Color(1,0.85,0.2), Color(1,0.9,0.3)],
	]
	for ex in exchange_data:
		var cost = ex[2]
		var can_afford = _main.gold >= cost
		var card = PanelContainer.new()
		var cs = StyleBoxFlat.new()
		cs.bg_color = Color(0.07, 0.05, 0.12, 0.5)
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
						"pages": _main.player_pages += amount
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
		is2.bg_color = Color(0.07, 0.05, 0.12, 0.5)
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
		row.add_child(_lbl(item[1], 10, Color(0.60, 0.55, 0.48)))
		row.add_child(_lbl("🪶 %d" % item[2], 11, Color(0.7, 0.5, 0.9)))
		var buy = _art_button("BUY", Color(0.12, 0.40, 0.12), Vector2(80, 30))
		row.add_child(buy)
		parent.add_child(card)

func _build_gear_crafting(parent: VBoxContainer) -> void:
	parent.add_child(_section_header("GEAR CRAFTING"))
	parent.add_child(_lbl("Combine 3 gear of the same rarity to forge a higher rarity item", 11, Color(0.70, 0.62, 0.52)))
	var crafting_tiers = [
		["3 Common → 1 Uncommon", "common", "uncommon", 50, Color(0.5, 0.5, 0.5)],
		["3 Uncommon → 1 Rare", "uncommon", "rare", 150, Color(0.3, 0.7, 0.3)],
		["3 Rare → 1 Epic", "rare", "epic", 500, Color(0.2, 0.5, 0.9)],
		["3 Epic → 1 Legendary", "epic", "legendary", 2000, Color(0.7, 0.3, 0.9)],
	]
	for ct in crafting_tiers:
		var card = PanelContainer.new()
		var cs = StyleBoxFlat.new()
		cs.bg_color = Color(0.07, 0.05, 0.12, 0.5)
		cs.set_corner_radius_all(8)
		cs.border_color = Color(ct[4].r * 0.5, ct[4].g * 0.5, ct[4].b * 0.5, 0.4)
		cs.set_border_width_all(1)
		cs.content_margin_left = 12; cs.content_margin_right = 12
		cs.content_margin_top = 6; cs.content_margin_bottom = 6
		card.add_theme_stylebox_override("panel", cs)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(row)
		row.add_child(_lbl("🔨", 16, ct[4]))
		var desc = _lbl(ct[0], 12, ct[4])
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(desc)
		row.add_child(_lbl("%d📄" % ct[3], 10, Color(0.3, 0.75, 0.9)))
		var craft = _art_button("CRAFT", Color(0.35, 0.20, 0.10), Vector2(80, 30))
		row.add_child(craft)
		parent.add_child(card)

func _build_gear_shard_shop(parent: VBoxContainer) -> void:
	parent.add_child(_lbl("Collect and forge Pages", 12, Color(0.60, 0.55, 0.48)))
	if _main:
		parent.add_child(_lbl("You have: %d Pages" % _main.player_pages, 14, Color(0.3, 0.75, 0.9)))
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
		cv.add_child(_lbl("Gear Chest — 50 Pages", 13, Color(0.85, 0.70, 0.20)))
		cv.add_child(_lbl("Contains 1 random piece of Gear", 11, Color(0.70, 0.62, 0.52)))
		var open_btn = _art_button("OPEN CHEST", Color(0.5, 0.35, 0.10), Vector2(140, 34))
		if _main and _main.player_pages >= 50:
			open_btn.pressed.connect(func():
				_show_popup("Chest Opened!", "You received a new piece of Gear!\n+1 Random Gear Item"))
		else:
			open_btn.disabled = true
		cv.add_child(open_btn)
		parent.add_child(chest_panel)
	_build_generic_shop(parent, {"name": "Pages"})

func _build_survivor_packs(parent: VBoxContainer) -> void:
	parent.add_child(_lbl("Bundles of literary might — boost your Survivors!", 12, Color(0.60, 0.55, 0.48)))
	var packs = [
		["Starter Bundle", "XP Boost for 3 characters + 500 Gold", 50, "quills", Color(0.3, 0.7, 0.3)],
		["Hero's Journey", "Level up any character by 1 + Random Gear", 100, "quills", Color(0.2, 0.5, 0.9)],
		["Epic Collection", "3 Gear Chests + 1000 Gold + 50 Pages  (Save 30%!)", 200, "quills", Color(0.7, 0.3, 0.9)],
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
		var desc = _lbl(pk[1], 11, Color(0.70, 0.62, 0.52))
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
		trs.bg_color = Color(0.07, 0.05, 0.12, 0.5)
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
		info.add_child(_lbl(tr[1], 11, Color(0.70, 0.62, 0.52)))
		row.add_child(_lbl("⭐ %d" % tr[2], 12, Color(1, 0.85, 0.3)))
		var buy = _art_button("BUY", Color(0.12, 0.40, 0.12), Vector2(80, 30))
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
			pps.bg_color = Color(0.06, 0.04, 0.10, 0.4)
			pps.set_corner_radius_all(8)
			pps.content_margin_left = 8; pps.content_margin_right = 8
			pps.content_margin_top = 6; pps.content_margin_bottom = 6
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
			cs.bg_color = Color(0.07, 0.05, 0.12, 0.5)
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
			var buy = _art_button("BUY", Color(0.12, 0.40, 0.12), Vector2(80, 30))
			row.add_child(buy)
			parent.add_child(card)
	else:
		parent.add_child(_lbl("The merchant will return soon...", 11, Color(0.60, 0.55, 0.48)))

func _build_generic_shop(parent: VBoxContainer, cat: Dictionary) -> void:
	parent.add_child(_lbl("Coming soon to %s..." % cat.get("name","Shop"), 13, Color(0.60, 0.55, 0.48)))
	# Show placeholder items with locked styling
	var placeholders = ["Mystery Item I", "Mystery Item II", "Mystery Item III"]
	for pi in range(3):
		var row_panel = PanelContainer.new()
		var rps = StyleBoxFlat.new()
		rps.bg_color = Color(0.06, 0.04, 0.10, 0.4)
		rps.set_corner_radius_all(8)
		rps.content_margin_left = 12; rps.content_margin_right = 12
		rps.content_margin_top = 6; rps.content_margin_bottom = 6
		row_panel.add_theme_stylebox_override("panel", rps)
		row_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_panel.add_child(row)
		row.add_child(_lbl("🔒", 16, Color(0.45, 0.38, 0.32)))
		var il = _lbl(placeholders[pi], 13, Color(0.40, 0.35, 0.30))
		il.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		il.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(il)
		row.add_child(_lbl("???", 12, Color(0.45, 0.38, 0.32)))
		parent.add_child(row_panel)

# ======================== CODEX ========================
var _codex_subtab: String = "gear"
var _gear_filter: String = "ALL"

func _build_codex() -> void:
	_clear()
	var codex_margin = MarginContainer.new()
	codex_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	codex_margin.add_theme_constant_override("margin_left", 12)
	codex_margin.add_theme_constant_override("margin_right", 12)
	codex_margin.add_theme_constant_override("margin_top", 8)
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
	for tab in [["gear", "GEAR"], ["achievements", "ACHIEVE"], ["bestiary", "BESTIARY"], ["journal", "JOURNAL"], ["books", "BOOKS"], ["glossary", "GUIDE"], ["stats", "STATS"], ["calendar", "EVENTS"]]:
		var is_active_codex = _codex_subtab == tab[0]
		var tb = Button.new()
		tb.text = tab[1]
		tb.custom_minimum_size = Vector2(0, 30)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ts = StyleBoxFlat.new()
		ts.bg_color = Color(0.15, 0.10, 0.25, 0.85) if is_active_codex else Color(0.06, 0.04, 0.12, 0.4)
		ts.set_corner_radius_all(8)
		ts.border_color = Color(0.85, 0.65, 0.20, 0.7) if is_active_codex else Color(0.25, 0.20, 0.15, 0.3)
		ts.set_border_width_all(2 if is_active_codex else 1)
		if is_active_codex:
			ts.shadow_color = Color(0, 0, 0, 0.25)
			ts.shadow_size = 3
		tb.add_theme_stylebox_override("normal", ts)
		var tsh = ts.duplicate()
		tsh.bg_color = Color(0.20, 0.14, 0.32, 0.9)
		tsh.border_color = Color(0.70, 0.55, 0.20, 0.6)
		tb.add_theme_stylebox_override("hover", tsh)
		tb.add_theme_font_size_override("font_size", 10)
		tb.add_theme_color_override("font_color", Color(1, 0.92, 0.45) if is_active_codex else Color(0.70, 0.62, 0.52))
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
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vb.add_child(sc)
	var content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_stretch_ratio = 1.0
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sc.add_child(content)
	match _codex_subtab:
		"gear": _build_gear_grid(content)
		"achievements": _build_achievements_list(content)
		"bestiary": _build_bestiary(content)
		"journal": _build_journal(content)
		"stats": _build_stats_page(content)
		"books": _build_book_collection(content)
		"glossary": _build_glossary(content)
		"calendar": _build_event_calendar(content)

func _codex_switch(tab: String) -> void:
	_codex_subtab = tab
	_build_codex()

func _build_gear_grid(parent: VBoxContainer) -> void:
	parent.add_child(_lbl("GEAR COMPENDIUM — %d Items" % _main._gear_icon_textures.size(), 14, Color(0.85, 0.72, 0.40)))
	parent.add_child(_lbl("Collect gear from battles and the Emporium", 11, Color(0.70, 0.62, 0.52)))
	# Filter row
	var filter_row = HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 6)
	filter_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	filter_row.add_child(_lbl("Filter:", 11, Color(0.65, 0.58, 0.50)))
	for fr in [["ALL", Color(0.55, 0.50, 0.45)], ["COMMON", Color(0.5, 0.5, 0.5)], ["RARE", Color(0.2, 0.5, 0.9)], ["EPIC", Color(0.7, 0.3, 0.9)], ["LEGEND", Color(1.0, 0.7, 0.1)]]:
		var is_active_filter = _gear_filter == fr[0]
		var fb = _art_button(fr[0], Color(0.15, 0.10, 0.25) if is_active_filter else Color(0.08, 0.06, 0.14), Vector2(85, 28))
		fb.add_theme_font_size_override("font_size", 11)
		fb.add_theme_color_override("font_color", fr[1])
		var filter_name = fr[0]
		fb.pressed.connect(func(): _gear_filter = filter_name; _build_codex())
		filter_row.add_child(fb)
	parent.add_child(filter_row)
	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_stretch_ratio = 1.0
	parent.add_child(grid)
	if not _main: return
	var keys = _main._gear_icon_textures.keys()
	keys.sort()
	var gear_idx = 0
	var rarity_names = ["COMMON", "COMMON", "COMMON", "RARE", "RARE", "EPIC", "LEGEND"]
	for gk in keys:
		# Rarity based on name hash for consistent assignment
		var rarity_colors = [Color(0.5, 0.5, 0.5), Color(0.3, 0.7, 0.3), Color(0.2, 0.5, 0.9), Color(0.7, 0.3, 0.9), Color(1.0, 0.7, 0.1)]
		var rarity_idx = clampi(gk.hash() % 5, 0, 4)
		var rarity_col = rarity_colors[rarity_idx]
		var rarity_name = ["COMMON", "COMMON", "RARE", "EPIC", "LEGEND"][rarity_idx]
		# Apply filter
		if _gear_filter != "ALL" and _gear_filter != rarity_name:
			gear_idx += 1
			continue
		gear_idx += 1
		# Each gear item as a clickable button
		var card = Button.new()
		card.text = ""
		card.custom_minimum_size = Vector2(280, 150)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cs = StyleBoxFlat.new()
		cs.bg_color = Color(0.08, 0.06, 0.14, 0.75)  # Darker to hide icon bg
		cs.border_color = Color(rarity_col.r * 0.7, rarity_col.g * 0.7, rarity_col.b * 0.7, 0.5)
		cs.set_border_width_all(2)
		cs.set_corner_radius_all(8)
		cs.shadow_color = Color(rarity_col.r * 0.3, rarity_col.g * 0.3, rarity_col.b * 0.3, 0.2)
		cs.shadow_size = 3
		cs.content_margin_left = 8; cs.content_margin_right = 8
		cs.content_margin_top = 6; cs.content_margin_bottom = 6
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
		# Dark backdrop to hide white/light icon backgrounds
		var icon_bg = PanelContainer.new()
		icon_bg.custom_minimum_size = Vector2(80, 80)
		icon_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ibg_sb = StyleBoxFlat.new()
		ibg_sb.bg_color = Color(0.04, 0.02, 0.08, 0.95)
		ibg_sb.set_corner_radius_all(6)
		ibg_sb.content_margin_left = 2; ibg_sb.content_margin_right = 2
		ibg_sb.content_margin_top = 2; ibg_sb.content_margin_bottom = 2
		icon_bg.add_theme_stylebox_override("panel", ibg_sb)
		var icon = TextureRect.new()
		icon.texture = _main._gear_icon_textures[gk]
		icon.custom_minimum_size = Vector2(76, 76)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shader_res = load("res://shaders/white_key.gdshader")
		if shader_res:
			var mat = ShaderMaterial.new()
			mat.shader = shader_res
			mat.set_shader_parameter("threshold", 0.75)
			icon.material = mat
		icon_bg.add_child(icon)
		cv.add_child(icon_bg)
		var name_lbl = _lbl(gk.replace("_", " ").capitalize(), 11, Color(0.80, 0.72, 0.58))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_lbl.clip_text = true
		name_lbl.custom_minimum_size.x = 120
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
			var eq_lbl = _lbl("⚔ " + equipped_by, 10, Color(0.4, 0.8, 0.3))
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
			grid.columns = 5
			grid.add_theme_constant_override("h_separation", 8)
			grid.add_theme_constant_override("v_separation", 8)
			grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			parent.add_child(grid)
			var keys = _main._achievement_icon_textures.keys()
			keys.sort()
			for ak in keys:
				# Achievement card with art border
				var card = PanelContainer.new()
				var cs = StyleBoxFlat.new()
				cs.bg_color = Color(0.07, 0.05, 0.12, 0.6)
				cs.border_color = Color(0.65, 0.50, 0.20, 0.4)
				cs.set_border_width_all(1)
				cs.set_corner_radius_all(8)
				cs.content_margin_left = 8; cs.content_margin_right = 8
				cs.content_margin_top = 6; cs.content_margin_bottom = 6
				card.add_theme_stylebox_override("panel", cs)
				card.mouse_filter = Control.MOUSE_FILTER_IGNORE
				card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				card.custom_minimum_size = Vector2(220, 0)
				card.tooltip_text = ak.replace("_", " ").capitalize()
				var cv = VBoxContainer.new()
				cv.alignment = BoxContainer.ALIGNMENT_CENTER
				cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
				card.add_child(cv)
				var icon_panel = PanelContainer.new()
				icon_panel.custom_minimum_size = Vector2(60, 60)
				icon_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var ips = StyleBoxFlat.new()
				ips.bg_color = Color(0.04, 0.02, 0.08, 0.95)
				ips.set_corner_radius_all(6)
				ips.content_margin_left = 2; ips.content_margin_right = 2
				ips.content_margin_top = 2; ips.content_margin_bottom = 2
				icon_panel.add_theme_stylebox_override("panel", ips)
				var icon = TextureRect.new()
				icon.texture = _main._achievement_icon_textures[ak]
				icon.custom_minimum_size = Vector2(56, 56)
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var wk_shader = load("res://shaders/white_key.gdshader")
				if wk_shader:
					var wk_mat = ShaderMaterial.new()
					wk_mat.shader = wk_shader
					wk_mat.set_shader_parameter("threshold", 0.75)
					icon.material = wk_mat
				icon_panel.add_child(icon)
				cv.add_child(icon_panel)
				var name_lbl = _lbl(ak.replace("_", " ").capitalize(), 10, Color(0.60, 0.55, 0.48))
				name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				name_lbl.clip_text = true
				name_lbl.custom_minimum_size.x = 80
				name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				cv.add_child(name_lbl)
				grid.add_child(card)
		else:
			parent.add_child(_lbl("No achievement icons loaded yet.", 12, Color(0.70, 0.62, 0.52)))
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
			var ach_panel = PanelContainer.new()
			var ach_s = StyleBoxFlat.new()
			ach_s.bg_color = Color(0.08, 0.06, 0.14, 0.5) if is_done else Color(0.05, 0.04, 0.10, 0.3)
			ach_s.set_corner_radius_all(6)
			ach_s.border_color = Color(0.55, 0.42, 0.18, 0.4) if is_done else Color(0.25, 0.20, 0.15, 0.2)
			ach_s.set_border_width_all(1)
			ach_s.content_margin_left = 8; ach_s.content_margin_right = 8
			ach_s.content_margin_top = 4; ach_s.content_margin_bottom = 4
			ach_panel.add_theme_stylebox_override("panel", ach_s)
			ach_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var ach_row = HBoxContainer.new()
			ach_row.add_theme_constant_override("separation", 8)
			ach_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ach_panel.add_child(ach_row)
			var icon_txt = "✅" if is_done else "⬜"
			ach_row.add_child(_lbl(icon_txt, 12, Color.WHITE))
			var name_l = _lbl(ad.get("name", ""), 11, Color(0.90, 0.82, 0.55) if is_done else Color(0.60, 0.55, 0.48))
			name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ach_row.add_child(name_l)
			ach_row.add_child(_lbl("%d/%d" % [mini(prog, ad.get("target", 1)), ad.get("target", 1)], 10, Color(0.55, 0.50, 0.45)))
			var reward_text = "+%d %s" % [ad.get("reward_amount", 0), ad.get("reward_type", "").capitalize()]
			ach_row.add_child(_lbl(reward_text, 10, Color(0.4, 0.7, 0.3) if is_done else Color(0.45, 0.38, 0.32)))
			var target_val = ad.get("target", 1)
			var tier_text = "🥉" if target_val < 100 else ("🥈" if target_val < 1000 else "🥇")
			ach_row.add_child(_lbl(tier_text, 11, Color.WHITE))
			if is_done:
				var claim = _art_button("CLAIM", Color(0.12, 0.40, 0.12), Vector2(75, 28))
				claim.add_theme_font_size_override("font_size", 10)
				var ach_name = ad.get("name", "")
				var ach_reward = reward_text
				claim.pressed.connect(func(): _show_popup("Reward Claimed!", "%s\n%s" % [ach_name, ach_reward]))
				ach_row.add_child(claim)
			parent.add_child(ach_panel)
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
	# Endless mode best
	if "endless_top_runs" in _main and _main.endless_top_runs.size() > 0:
		var best_wave = 0
		for run in _main.endless_top_runs:
			if run.get("wave", 0) > best_wave:
				best_wave = run["wave"]
		stats_data.append(["Endless Best Wave", best_wave])
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
		rps.bg_color = Color(0.06, 0.04, 0.10, 0.5) if si % 2 == 0 else Color(0.06, 0.04, 0.10, 0.4)
		rps.set_corner_radius_all(8)
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
	parent.add_child(_lbl("Enemies encountered in your battles", 11, Color(0.70, 0.62, 0.52)))
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
		cs.bg_color = Color(0.07, 0.05, 0.12, 0.5)
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
		var desc = _lbl(e[1], 11, Color(0.70, 0.62, 0.52))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(desc)
		var stats_row = HBoxContainer.new()
		stats_row.add_theme_constant_override("separation", 6)
		stats_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var stat_parts = e[2].split("  ")
		for sp in stat_parts:
			var stat_chip = PanelContainer.new()
			var scs = StyleBoxFlat.new()
			scs.bg_color = Color(e[3].r * 0.2, e[3].g * 0.2, e[3].b * 0.2, 0.5)
			scs.set_corner_radius_all(6)
			scs.content_margin_left = 6; scs.content_margin_right = 6
			scs.content_margin_top = 1; scs.content_margin_bottom = 1
			stat_chip.add_theme_stylebox_override("panel", scs)
			stat_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var sl = _lbl(sp.strip_edges(), 9, Color(0.70, 0.62, 0.52))
			sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stat_chip.add_child(sl)
			stats_row.add_child(stat_chip)
		cv.add_child(stats_row)
		# Kill count from game data
		if _main and "enemy_kill_counts" in _main:
			var kill_key = e[0].to_lower().replace(" ", "_")
			var kills = _main.enemy_kill_counts.get(kill_key, 0)
			if kills > 0:
				cv.add_child(_lbl("☠ %d killed" % kills, 10, Color(0.55, 0.45, 0.38)))
		grid.add_child(card)

func _build_journal(parent: VBoxContainer) -> void:
	parent.add_child(_section_header("CHARACTER JOURNALS"))
	parent.add_child(_lbl("Unlock journal entries by rescuing characters and completing levels", 11, Color(0.70, 0.62, 0.52)))
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
		es.bg_color = Color(0.07, 0.05, 0.12, 0.5) if unlocked else Color(0.03, 0.02, 0.06, 0.3)
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
			if i < _main.character_novels.size():
				text_col.add_child(_lbl("from \"%s\"" % _main.character_novels[i], 10, Color(0.50, 0.42, 0.38)))
			if i < _main.character_titles.size():
				text_col.add_child(_lbl(_main.character_titles[i], 10, Color(0.60, 0.52, 0.44)))
			if i < _main.character_quotes.size():
				var quote = _lbl('"' + _main.character_quotes[i] + '"', 11, Color(0.70, 0.62, 0.52))
				quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				quote.mouse_filter = Control.MOUSE_FILTER_IGNORE
				text_col.add_child(quote)
			# Lore journal entries — unlock based on kills/level
			if _main.character_lore.has(pkey):
				var lore_entries = _main.character_lore[pkey]
				var tt = _main.survivor_types[i] if i < _main.survivor_types.size() else null
				var kills = _main.survivor_progress.get(tt, {}).get("total_kills", 0) if tt else 0
				var char_lvl = _main.survivor_progress.get(tt, {}).get("level", 1) if tt else 1
				var unlocked_count = 0
				for li in range(lore_entries.size()):
					var threshold = _main.JOURNAL_UNLOCK_THRESHOLDS[li] if li < _main.JOURNAL_UNLOCK_THRESHOLDS.size() else 999
					var is_lore_unlocked = false
					if threshold == 0: is_lore_unlocked = true  # First entry = rescue
					elif threshold == -1: is_lore_unlocked = char_lvl >= 5  # Level gate
					else: is_lore_unlocked = kills >= threshold
					if is_lore_unlocked: unlocked_count += 1
				text_col.add_child(_lbl("📖 %d / %d Lore Entries" % [unlocked_count, lore_entries.size()], 10, Color(0.65, 0.55, 0.45)))
		else:
			text_col.add_child(_lbl("???", 14, Color(0.45, 0.38, 0.32)))
			text_col.add_child(_lbl("Rescue this character to unlock their journal", 10, Color(0.45, 0.38, 0.32)))
		parent.add_child(entry)
		# Expandable lore entries below the card (for unlocked characters)
		if unlocked and _main.character_lore.has(pkey):
			var lore_entries2 = _main.character_lore[pkey]
			var tt2 = _main.survivor_types[i] if i < _main.survivor_types.size() else null
			var kills2 = _main.survivor_progress.get(tt2, {}).get("total_kills", 0) if tt2 else 0
			var char_lvl2 = _main.survivor_progress.get(tt2, {}).get("level", 1) if tt2 else 1
			for li2 in range(lore_entries2.size()):
				var threshold2 = _main.JOURNAL_UNLOCK_THRESHOLDS[li2] if li2 < _main.JOURNAL_UNLOCK_THRESHOLDS.size() else 999
				var is_unlocked2 = false
				if threshold2 == 0: is_unlocked2 = true
				elif threshold2 == -1: is_unlocked2 = char_lvl2 >= 5
				else: is_unlocked2 = kills2 >= threshold2
				var lore_panel = PanelContainer.new()
				var lps = StyleBoxFlat.new()
				lps.bg_color = Color(0.05, 0.03, 0.10, 0.4) if is_unlocked2 else Color(0.03, 0.02, 0.06, 0.25)
				lps.set_corner_radius_all(6)
				lps.content_margin_left = 14; lps.content_margin_right = 14
				lps.content_margin_top = 6; lps.content_margin_bottom = 6
				lore_panel.add_theme_stylebox_override("panel", lps)
				lore_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var lore_vb = VBoxContainer.new()
				lore_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
				lore_panel.add_child(lore_vb)
				var entry_title = "Entry %d" % (li2 + 1)
				if not is_unlocked2:
					if threshold2 == -1:
						entry_title += " — 🔒 Reach Level 5"
					else:
						entry_title += " — 🔒 %d kills needed" % threshold2
				lore_vb.add_child(_lbl(entry_title, 10, Color(0.75, 0.65, 0.45) if is_unlocked2 else Color(0.40, 0.35, 0.30)))
				if is_unlocked2:
					var lore_text = _lbl(lore_entries2[li2], 11, Color(0.70, 0.62, 0.52))
					lore_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					lore_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
					lore_vb.add_child(lore_text)
				parent.add_child(lore_panel)

func _build_event_calendar(parent: VBoxContainer) -> void:
	parent.add_child(_section_header("EVENT CALENDAR"))
	parent.add_child(_lbl("Stay on top of resets and upcoming events", 11, Color(0.70, 0.62, 0.52)))
	var time_dict = Time.get_time_dict_from_system()
	var hours_left = 24 - time_dict.get("hour", 0)
	var day_of_week = Time.get_date_dict_from_system().get("weekday", 0)
	var days_to_weekly = 7 - day_of_week if day_of_week > 0 else 7
	var events = [
		["🕐 Daily Deals Reset", "%dh remaining" % hours_left, Color(0.85, 0.65, 0.10)],
		["🕐 Daily Quests Reset", "%dh remaining" % hours_left, Color(0.3, 0.7, 0.4)],
		["🕐 Lucky Wheel Free Spin", "%dh remaining" % hours_left, Color(0.7, 0.3, 0.8)],
		["📅 Weekly Quests Reset", "%d days remaining" % days_to_weekly, Color(0.3, 0.6, 0.9)],
		["📅 Merchant Rotation", "%dh remaining" % hours_left, Color(0.8, 0.5, 0.2)],
		["🎃 Seasonal Event", "🔜 Coming Soon", Color(0.65, 0.50, 0.35)],
		["🏆 Ranked Season", "🔜 Coming Soon", Color(0.65, 0.50, 0.35)],
	]
	for ev in events:
		var ev_panel = PanelContainer.new()
		var evs = StyleBoxFlat.new()
		evs.bg_color = Color(0.07, 0.05, 0.12, 0.5)
		evs.set_corner_radius_all(8)
		evs.border_color = Color(ev[2].r * 0.4, ev[2].g * 0.4, ev[2].b * 0.4, 0.4)
		evs.set_border_width_all(1)
		evs.content_margin_left = 12; evs.content_margin_right = 12
		evs.content_margin_top = 6; evs.content_margin_bottom = 6
		ev_panel.add_theme_stylebox_override("panel", evs)
		ev_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ev_row = HBoxContainer.new()
		ev_row.add_theme_constant_override("separation", 12)
		ev_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ev_panel.add_child(ev_row)
		var ev_name = _lbl(ev[0], 12, ev[2])
		ev_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ev_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ev_row.add_child(ev_name)
		ev_row.add_child(_lbl(ev[1], 12, Color(0.70, 0.62, 0.52)))
		parent.add_child(ev_panel)

func _build_glossary(parent: VBoxContainer) -> void:
	parent.add_child(_section_header("GLOSSARY"))
	parent.add_child(_lbl("Game terms and mechanics explained", 11, Color(0.70, 0.62, 0.52)))
	var terms = [
		["Synergy", "Bonus when bonded characters placed near each other. Check Allies tab for bonds."],
		["Pages", "Currency dropped from battles. Spend at the Emporium's Gear Chest shop."],
		["Quills", "Premium currency earned from quests and achievements. Buy rare items."],
		["Storybook Stars", "Earned by completing levels. Used for progression and rewards."],
		["Prestige", "Reset a max-level character for permanent stat bonuses."],
		["Targeting Priority", "Tap a placed tower to cycle: First → Last → Close → Strong."],
		["Active Ability", "Unlocked at Tier 3 upgrade. Cooldown-based special power."],
		["Boss Phase", "Bosses change behavior at 66% and 33% HP. Watch for new attacks."],
		["Combo", "Kill enemies quickly in succession for gold bonuses (x2 and up)."],
		["Perfect Wave", "Complete a wave without losing any lives for bonus gold."],
		["Adaptive Difficulty", "Game adjusts enemy HP based on your remaining lives."],
		["Wave Rush", "Start the next wave while enemies are alive for a gold bonus."],
	]
	for term in terms:
		var term_panel = PanelContainer.new()
		var tms = StyleBoxFlat.new()
		tms.bg_color = Color(0.06, 0.04, 0.10, 0.45)
		tms.set_corner_radius_all(8)
		tms.content_margin_left = 10; tms.content_margin_right = 10
		tms.content_margin_top = 6; tms.content_margin_bottom = 6
		term_panel.add_theme_stylebox_override("panel", tms)
		term_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tv = VBoxContainer.new()
		tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		term_panel.add_child(tv)
		tv.add_child(_lbl(term[0], 13, Color(0.90, 0.82, 0.60)))
		var def_lbl = _lbl(term[1], 11, Color(0.70, 0.62, 0.52))
		def_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		def_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tv.add_child(def_lbl)
		parent.add_child(term_panel)
	# === TOME LORE — World-building rules of the Tome of Shadows ===
	parent.add_child(_section_header("THE RULES OF THE TOME"))
	parent.add_child(_lbl("The Tome of Shadows operates by narrative laws — rules that even the Shadow Author must follow.", 11, Color(0.70, 0.62, 0.52)))
	var tome_rules = [
		["The Ink Law", "Nothing in the Tome is truly created. Every shadow creature was once a real character from a real story who surrendered to despair. The Author can reshape them, but not create from nothing."],
		["The Narrative Constraint", "Every story the Author writes MUST have an ending. He cannot create an infinite loop or a story without resolution. This is his greatest weakness — heroes who refuse to follow the script break his control."],
		["The Memory Rule", "Characters inside the Tome retain their original memories but slowly forget details over time. The longer they're trapped, the more they become the version the Author wrote. Fighting preserves identity."],
		["The Ink Economy", "Shadow ink is finite. When enemies are destroyed, their ink returns to the Tome's reserves. The Author must spend ink to create new threats — which is why later waves get harder but also fewer in number."],
		["The Portal Principle", "Portals between realms within the Tome can only be opened at chapter boundaries. This is why each realm has exactly 3 chapters — the Author designed it as a narrative prison with locked doors between acts."],
		["The Rescue Paradox", "A freed character becomes immune to the Author's direct control. However, their STORY can still be corrupted — which is why ACT 2 forces heroes to face twisted versions of their own tales."],
		["Time Dilation", "One second inside the Tome equals approximately one year in the outside world. The heroes don't age inside, but their original stories have been retold thousands of times. The versions readers know NOW may differ from the originals trapped here."],
		["The Author's Pulse", "The Tome has a heartbeat — the Shadow Author's own pulse. If you listen during the silence between waves, you can hear it. The book is alive because he is alive. Destroying him would destroy the Tome and free everyone... or trap them in a collapsing world."],
		["The Three-Word Gap", "The Shadow Author's original story stopped three words from its ending. Those three unwritten words are the most powerful force in the Tome — they represent pure POTENTIAL. An ending that was never decided. The Author fears those words more than anything."],
		["The Narrator's Realm", "Beyond the Tome exists another realm — the Realm of Legends, where the Narrator dwells. Unlike the Tome (which traps characters in ink), the Narrator's Realm preserves characters in fire and light. Both are prisons. Both claim to be sanctuaries."],
	]
	for rule in tome_rules:
		var rule_panel = PanelContainer.new()
		var rs = StyleBoxFlat.new()
		rs.bg_color = Color(0.06, 0.03, 0.12, 0.5)
		rs.set_corner_radius_all(8)
		rs.border_color = Color(0.45, 0.25, 0.55, 0.3)
		rs.set_border_width_all(1)
		rs.content_margin_left = 12; rs.content_margin_right = 12
		rs.content_margin_top = 8; rs.content_margin_bottom = 8
		rule_panel.add_theme_stylebox_override("panel", rs)
		rule_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rv = VBoxContainer.new()
		rv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rule_panel.add_child(rv)
		rv.add_child(_lbl("📜 " + rule[0], 13, Color(0.85, 0.65, 0.90)))
		var rule_desc = _lbl(rule[1], 11, Color(0.70, 0.62, 0.52))
		rule_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rule_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rv.add_child(rule_desc)
		parent.add_child(rule_panel)

func _build_book_collection(parent: VBoxContainer) -> void:
	parent.add_child(_section_header("BOOK COLLECTION"))
	parent.add_child(_lbl("The literary works that power your Survivors", 11, Color(0.70, 0.62, 0.52)))
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
		bvb.add_child(_lbl("📖", 24, Color(0.85, 0.78, 0.65)))
		var title_lbl = _lbl(novels[ni], 11, Color(0.85, 0.78, 0.65))
		title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bvb.add_child(title_lbl)
		# Find which character comes from this novel
		for ci in range(_main.character_novels.size()):
			if _main.character_novels[ci] == novels[ni] and ci < _main.character_names.size():
				bvb.add_child(_lbl(_main.character_names[ci], 11, Color(0.65, 0.58, 0.50)))
				break
		grid.add_child(book_card)

# ======================== SETTINGS ========================
func _build_settings() -> void:
	_clear()
	# Settings art background (candle, book, gears)
	if _art.has("settings_bg_art"):
		var sbg = TextureRect.new()
		sbg.texture = _art["settings_bg_art"]
		sbg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sbg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		sbg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sbg.modulate.a = 0.55  # More visible settings background
		var mat = _make_black_key_mat(0.06, 0.04)
		if mat: sbg.material = mat
		content_area.add_child(sbg)
	var sc = ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_area.add_child(sc)
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 8)
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
			var qh = _lbl("  ↳ %s  (%d FPS)" % [quality_hints[qname], Engine.get_frames_per_second()], 10, Color(0.60, 0.55, 0.48))
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
		var preview = _lbl("  ↳ Preview: This is how text will look", int(10 * GameSettings.font_scale), Color(0.70, 0.62, 0.52))
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(preview)
		var cb_names = ["Off", "Deuteranopia", "Protanopia", "Tritanopia"]
		_add_setting_row(vb, "Colorblind Mode", cb_names[clampi(GameSettings.colorblind_mode, 0, 3)], func(): GameSettings.colorblind_mode = (GameSettings.colorblind_mode + 1) % 4; GameSettings.save_settings(); _build_settings())
		if GameSettings.colorblind_mode > 0:
			var cb_desc = ["", "Red-green (most common)", "Red-green (protanopia)", "Blue-yellow (rare)"]
			var desc = _lbl("  ↳ %s" % cb_desc[clampi(GameSettings.colorblind_mode, 0, 3)], 10, Color(0.60, 0.55, 0.48))
			desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vb.add_child(desc)
			# Color preview swatches
			var swatch_row = HBoxContainer.new()
			swatch_row.add_theme_constant_override("separation", 6)
			swatch_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			swatch_row.add_child(_lbl("  ↳ Preview:", 10, Color(0.55, 0.50, 0.45)))
			var preview_colors = [Color(0.9, 0.2, 0.2), Color(0.2, 0.8, 0.2), Color(0.2, 0.2, 0.9), Color(1.0, 0.8, 0.0)]
			for pc in preview_colors:
				var swatch_p = PanelContainer.new()
				var sws = StyleBoxFlat.new()
				sws.bg_color = pc
				sws.set_corner_radius_all(4)
				sws.border_color = Color(1, 1, 1, 0.3)
				sws.set_border_width_all(1)
				swatch_p.add_theme_stylebox_override("panel", sws)
				swatch_p.custom_minimum_size = Vector2(24, 16)
				swatch_p.mouse_filter = Control.MOUSE_FILTER_IGNORE
				swatch_row.add_child(swatch_p)
			vb.add_child(swatch_row)
		_add_setting_row(vb, "Reduced Motion", "ON" if GameSettings.reduced_motion else "OFF", func(): GameSettings.reduced_motion = not GameSettings.reduced_motion; GameSettings.save_settings(); _build_settings())
		_add_setting_row(vb, "Left-Handed", "ON" if GameSettings.left_handed else "OFF", func(): GameSettings.left_handed = not GameSettings.left_handed; GameSettings.save_settings(); _build_settings())
		_add_setting_row(vb, "Haptic Feedback", "ON" if GameSettings.haptic_feedback else "OFF", func(): GameSettings.haptic_feedback = not GameSettings.haptic_feedback; GameSettings.save_settings(); _build_settings())
		if GameSettings.haptic_feedback:
			var haptic_hint = _lbl("  ↳ Vibration on tower placement, boss kills, and life loss", 10, Color(0.60, 0.55, 0.48))
			haptic_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vb.add_child(haptic_hint)
		_add_setting_row(vb, "One-Handed Mode", "ON" if GameSettings.one_handed else "OFF", func(): GameSettings.one_handed = not GameSettings.one_handed; GameSettings.save_settings(); _build_settings())
	# Language
	vb.add_child(_section_header("LANGUAGE"))
	_add_setting_row(vb, "Language", "ENGLISH", func(): pass)  # Only language available
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
	cps.bg_color = Color(0.06, 0.04, 0.10, 0.5)
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
	var spacer = Control.new(); spacer.custom_minimum_size = Vector2(0, 6); spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE; credits_vb.add_child(spacer)  # Spacer
	credits_vb.add_child(_lbl("Created by Defense Planet", 12, Color(0.75, 0.68, 0.58)))
	credits_vb.add_child(_lbl("Art generated with nano-banana + Gemini", 11, Color(0.70, 0.62, 0.52)))
	credits_vb.add_child(_lbl("Built with Godot Engine 4.6", 11, Color(0.70, 0.62, 0.52)))
	credits_vb.add_child(_lbl("Inspired by BTD6, Arknights, Kingdom Rush", 11, Color(0.60, 0.55, 0.48)))
	var spacer2 = Control.new(); spacer2.custom_minimum_size = Vector2(0, 6); spacer2.mouse_filter = Control.MOUSE_FILTER_IGNORE; credits_vb.add_child(spacer2)
	credits_vb.add_child(_lbl("Version 0.9.0", 11, Color(0.65, 0.58, 0.50)))
	# What's New / Patch Notes
	vb.add_child(_section_header("WHAT'S NEW"))
	var patch_panel = PanelContainer.new()
	var pns = StyleBoxFlat.new()
	pns.bg_color = Color(0.06, 0.04, 0.10, 0.5)
	pns.set_corner_radius_all(8)
	pns.content_margin_left = 12; pns.content_margin_right = 12
	pns.content_margin_top = 8; pns.content_margin_bottom = 8
	patch_panel.add_theme_stylebox_override("panel", pns)
	patch_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pnvb = VBoxContainer.new()
	pnvb.add_theme_constant_override("separation", 6)
	pnvb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	patch_panel.add_child(pnvb)
	pnvb.add_child(_lbl("v0.9.0 — Menu Overhaul Update", 12, Color(0.85, 0.78, 0.60)))
	var notes = ["• Complete menu redesign with art backgrounds", "• 12 character ability trees with 108 named abilities", "• Gear picker + equipment system", "• Achievement tracking with progress bars", "• Bestiary with 12 enemy types", "• Gold economy rebalance", "• Wave preview on start button", "• Boss entrance announcements", "• Keyboard shortcuts (1-9, Space, Esc)", "• Damage numbers scale with hit size"]
	for note in notes:
		var nl = _lbl(note, 11, Color(0.70, 0.62, 0.52))
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pnvb.add_child(nl)
	vb.add_child(patch_panel)
	# FAQ / Help
	vb.add_child(_section_header("FAQ"))
	var faqs = [
		["How do synergies work?", "Place related characters near each other for bonus damage."],
		["What are Pages?", "Currency from battles. Spend at the Emporium to forge gear."],
		["How do I unlock characters?", "Rescue them by completing their story chapter."],
		["What does difficulty affect?", "Enemy HP, gold income, and star rewards scale with difficulty."],
		["How does prestige work?", "After max level, prestige for permanent stat bonuses."],
	]
	for faq in faqs:
		var faq_panel = PanelContainer.new()
		var fqs = StyleBoxFlat.new()
		fqs.bg_color = Color(0.06, 0.04, 0.10, 0.4)
		fqs.set_corner_radius_all(8)
		fqs.content_margin_left = 10; fqs.content_margin_right = 10
		fqs.content_margin_top = 6; fqs.content_margin_bottom = 6
		faq_panel.add_theme_stylebox_override("panel", fqs)
		faq_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fvb = VBoxContainer.new()
		fvb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		faq_panel.add_child(fvb)
		fvb.add_child(_lbl(faq[0], 13, Color(0.90, 0.82, 0.60)))
		var ans = _lbl(faq[1], 11, Color(0.70, 0.62, 0.52))
		ans.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ans.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fvb.add_child(ans)
		vb.add_child(faq_panel)
	# Coming Soon roadmap
	vb.add_child(_section_header("COMING SOON"))
	var roadmap_items = ["🗺️ New campaign: The Enchanted Library", "🗡️ Tower skins & cosmetics", "👥 Co-op multiplayer mode", "🏆 Ranked competitive seasons", "🎃 Seasonal events & limited-time content"]
	for ri in roadmap_items:
		var rm_panel = PanelContainer.new()
		var rms = StyleBoxFlat.new()
		rms.bg_color = Color(0.06, 0.04, 0.10, 0.35)
		rms.set_corner_radius_all(6)
		rms.content_margin_left = 10; rms.content_margin_right = 10
		rms.content_margin_top = 4; rms.content_margin_bottom = 4
		rm_panel.add_theme_stylebox_override("panel", rms)
		rm_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rl = _lbl(ri, 11, Color(0.70, 0.62, 0.52))
		rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rm_panel.add_child(rl)
		vb.add_child(rm_panel)
	vb.add_child(credits_panel)

func _add_setting_row(parent: VBoxContainer, label: String, value: String, callback: Callable, is_volume: bool = false, volume_pct: float = 0.0) -> void:
	# Setting row with styled panel
	var row_panel = PanelContainer.new()
	var rps = StyleBoxFlat.new()
	rps.bg_color = Color(0.07, 0.05, 0.12, 0.55)
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
		bps.bg_color = Color(0.06, 0.04, 0.10, 0.8)
		bps.set_corner_radius_all(8)
		bps.border_color = Color(0.30, 0.22, 0.15, 0.4)
		bps.set_border_width_all(1)
		bar_panel.add_theme_stylebox_override("panel", bps)
		row.add_child(bar_panel)
		var bar_fill = PanelContainer.new()
		bar_fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
		bar_fill.offset_left = 2; bar_fill.offset_top = 2; bar_fill.offset_bottom = -2
		bar_fill.offset_right = -160 + (156 * volume_pct)
		var bfs = StyleBoxFlat.new()
		bfs.bg_color = Color(0.55, 0.42, 0.18, 0.85)
		bfs.set_corner_radius_all(6)
		bar_fill.add_theme_stylebox_override("panel", bfs)
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
	bs.shadow_size = 3
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
	os.bg_color = Color(0.06, 0.04, 0.10, 0.3)  # Near-transparent so art frame shows
	os.set_corner_radius_all(12)
	os.border_color = Color(0.65, 0.50, 0.18, 0.3)
	os.set_border_width_all(0)  # Art provides the border
	os.shadow_color = Color(0, 0, 0, 0.2)
	os.shadow_size = 4
	os.content_margin_left = 40; os.content_margin_right = 40
	os.content_margin_top = 8; os.content_margin_bottom = 8
	outer.add_theme_stylebox_override("panel", os)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Art background for title — use section banner if available
	var title_art_key = "section_banner_art" if _art.has("section_banner_art") else "scroll_header"
	if _art.has(title_art_key):
		var art_bg = TextureRect.new()
		art_bg.texture = _art[title_art_key]
		art_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_bg.modulate.a = 0.75  # Prominent — art frame visible
		var mat = _make_black_key_mat(0.06, 0.04)
		if mat: art_bg.material = mat
		outer.add_child(art_bg)
	var l = _lbl(text, 24, Color(1.0, 0.92, 0.40))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(l)
	# Subtle glow pulse on title
	var tw = outer.create_tween().set_loops()
	tw.tween_property(outer, "modulate", Color(1.06, 1.04, 1.0), 2.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(outer, "modulate", Color(1.0, 1.0, 1.0), 2.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
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

func _style_scrollbar(sc: ScrollContainer) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.25, 0.20, 0.15, 0.4)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 2; sb.content_margin_right = 2
	sc.add_theme_stylebox_override("scroll", sb)
	var grabber = StyleBoxFlat.new()
	grabber.bg_color = Color(0.55, 0.42, 0.18, 0.5)
	grabber.set_corner_radius_all(4)
	sc.get_v_scroll_bar().add_theme_stylebox_override("grabber", grabber)
	var grabber_hl = grabber.duplicate()
	grabber_hl.bg_color = Color(0.65, 0.50, 0.20, 0.7)
	sc.get_v_scroll_bar().add_theme_stylebox_override("grabber_highlight", grabber_hl)

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
	s.shadow_size = 3
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
	# Dark panel behind the header for visual weight (#34)
	var panel = PanelContainer.new()
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.05, 0.03, 0.10, 0.75)
	ps.set_corner_radius_all(6)
	ps.content_margin_left = 0; ps.content_margin_right = 0
	ps.content_margin_top = 6; ps.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", ps)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Left gold line — extends to fill (#33)
	var line_l = ColorRect.new()
	line_l.custom_minimum_size = Vector2(0, 2)
	line_l.color = C_BORDER_GOLD
	line_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(line_l)
	# Left diamond
	var dot_l = _lbl("◆", 12, Color(C_GOLD_STAR.r, C_GOLD_STAR.g, C_GOLD_STAR.b, 0.7))
	dot_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(dot_l)
	# Act text — display font, large, bright gold (#31, #32)
	var lbl = _lbl(text, 20, C_GOLD)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)
	# Right diamond
	var dot_r = _lbl("◆", 12, Color(C_GOLD_STAR.r, C_GOLD_STAR.g, C_GOLD_STAR.b, 0.7))
	dot_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(dot_r)
	# Right gold line — extends to fill (#33)
	var line_r = ColorRect.new()
	line_r.custom_minimum_size = Vector2(0, 2)
	line_r.color = C_BORDER_GOLD
	line_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(line_r)
	panel.add_child(row)
	return panel

func _open_slot_picker(char_idx: int, tower_type, slot_name: String) -> void:
	_clear()
	var sc = ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_area.add_child(sc)
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 4)
	sc.add_child(margin)
	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 8)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vb)
	var back = _art_button("< BACK", Color(0.12, 0.10, 0.22), Vector2(90, 30))
	back.pressed.connect(func(): _detail_idx = char_idx; _detail_tab = 1; _build_detail_view())
	vb.add_child(back)
	var slot_display = _main.GEAR_SLOT_NAMES.get(slot_name, slot_name) if "GEAR_SLOT_NAMES" in _main else slot_name
	vb.add_child(_title("EQUIP %s" % slot_display.to_upper()))
	# Show available items for this slot
	if "GEAR_BY_SLOT" in _main and _main.GEAR_BY_SLOT.has(slot_name):
		var items = _main.GEAR_BY_SLOT[slot_name]
		var tier_colors = {"common": Color(0.5, 0.5, 0.5), "uncommon": Color(0.3, 0.7, 0.3), "rare": Color(0.2, 0.5, 0.9), "epic": Color(0.7, 0.3, 0.9), "legendary": Color(1.0, 0.7, 0.1)}
		for item in items:
			var item_col = tier_colors.get(item.get("tier", "common"), Color.WHITE)
			var card = PanelContainer.new()
			var cs = StyleBoxFlat.new()
			cs.bg_color = Color(item_col.r * 0.15, item_col.g * 0.15, item_col.b * 0.15, 0.6)
			cs.set_corner_radius_all(10)
			cs.border_color = Color(item_col.r * 0.5, item_col.g * 0.5, item_col.b * 0.5, 0.5)
			cs.set_border_width_all(2)
			cs.shadow_color = Color(item_col.r * 0.2, item_col.g * 0.2, item_col.b * 0.2, 0.15)
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
			info.add_child(_lbl(item.get("name", ""), 14, item_col))
			info.add_child(_lbl(item.get("desc", ""), 11, Color(0.70, 0.62, 0.52)))
			var tier_text = item.get("tier", "common").to_upper()
			info.add_child(_lbl(tier_text, 9, item_col.darkened(0.2)))
			var equip = _art_button("EQUIP", Color(0.12, 0.40, 0.12), Vector2(80, 30))
			var item_name = item.get("name", "Gear")
			equip.pressed.connect(func(): _show_popup("Equipped!", "%s has been equipped to the %s slot." % [item_name, slot_display]))
			row.add_child(equip)
			vb.add_child(card)
	else:
		vb.add_child(_lbl("No items available for this slot", 12, Color(0.60, 0.55, 0.48)))

func _open_skin_shop(char_idx: int) -> void:
	_clear()
	var sc = ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_area.add_child(sc)
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 4)
	sc.add_child(margin)
	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 8)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vb)
	var back = _art_button("< BACK", Color(0.12, 0.10, 0.22), Vector2(90, 30))
	back.pressed.connect(func(): _detail_idx = char_idx; _detail_tab = 1; _build_detail_view())
	vb.add_child(back)
	var cname = _main.character_names[char_idx] if _main and char_idx < _main.character_names.size() else "?"
	vb.add_child(_title("SKINS: %s" % cname))
	vb.add_child(_lbl("Customize your character's appearance", 11, Color(0.70, 0.62, 0.52)))
	# Get skins for this character
	var tt = _main.survivor_types[char_idx] if _main and char_idx < _main.survivor_types.size() else null
	if tt != null and _main.SURVIVOR_SKINS.has(tt):
		var skins = _main.SURVIVOR_SKINS[tt]
		for skin in skins:
			var is_owned = skin["id"] == "default" or ("owned_skins" in _main and _main.owned_skins.has(tt) and skin["id"] in _main.owned_skins[tt])
			var is_active = ("active_skins" in _main and _main.active_skins.has(tt) and _main.active_skins[tt] == skin["id"]) or (skin["id"] == "default" and (not _main.active_skins.has(tt)))
			var card = PanelContainer.new()
			var cs = StyleBoxFlat.new()
			cs.bg_color = Color(skin["color"].r * 0.2, skin["color"].g * 0.2, skin["color"].b * 0.2, 0.6)
			cs.set_corner_radius_all(10)
			cs.border_color = Color(skin["color"].r * 0.6, skin["color"].g * 0.6, skin["color"].b * 0.6, 0.5) if is_owned else Color(0.25, 0.20, 0.15, 0.3)
			cs.set_border_width_all(2 if is_active else 1)
			cs.shadow_color = Color(skin["color"].r * 0.15, skin["color"].g * 0.15, skin["color"].b * 0.15, 0.15)
			cs.shadow_size = 3
			cs.content_margin_left = 14; cs.content_margin_right = 14
			cs.content_margin_top = 10; cs.content_margin_bottom = 10
			card.add_theme_stylebox_override("panel", cs)
			var row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(row)
			# Color swatch preview
			var swatch = ColorRect.new()
			swatch.custom_minimum_size = Vector2(40, 40)
			swatch.color = skin["color"]
			swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(swatch)
			# Info
			var info = VBoxContainer.new()
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(info)
			info.add_child(_lbl(skin["name"], 14, skin["color"].lightened(0.4)))
			if is_active:
				info.add_child(_lbl("✅ EQUIPPED", 10, Color(0.3, 0.9, 0.3)))
			elif is_owned:
				info.add_child(_lbl("OWNED", 11, Color(0.70, 0.62, 0.52)))
			else:
				info.add_child(_lbl("🪶 %d Quills" % skin["cost"], 10, Color(0.7, 0.5, 0.9)))
			# Button
			if is_active:
				row.add_child(_lbl("ACTIVE", 11, Color(0.3, 0.8, 0.3)))
			elif is_owned:
				var equip = _art_button("EQUIP", Color(0.12, 0.35, 0.15), Vector2(80, 30))
				row.add_child(equip)
			else:
				var buy = _art_button("BUY", Color(0.35, 0.15, 0.45), Vector2(70, 30))
				var skin_cost = skin["cost"]
				var skin_name = skin["name"]
				buy.pressed.connect(func():
					_show_popup("Purchase Skin", "Buy %s for %d Quills?" % [skin_name, skin_cost], "BUY", func():
						_show_popup("Skin Unlocked!", "%s is now available!" % skin_name)))
				row.add_child(buy)
			vb.add_child(card)
	else:
		vb.add_child(_lbl("No skins available for this character yet", 12, Color(0.60, 0.55, 0.48)))

func _play_ui_click() -> void:
	if _main and "_sfx_ui_click" in _main and _main.has_method("_play_sfx"):
		_main._play_sfx(_main._sfx_ui_click)

func _add_scroll_hint(parent_control: Control) -> void:
	# Subtle animated scroll-down arrow at bottom of content area
	var hint = _lbl("▼", 20, Color(0.65, 0.55, 0.35, 0.5))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -30
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent_control.add_child(hint)
	# Bounce animation
	var htw = create_tween().set_loops()
	htw.tween_property(hint, "position:y", hint.position.y - 6, 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	htw.tween_property(hint, "position:y", hint.position.y, 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	# Fade out after 4 seconds
	var fade_tw = create_tween()
	fade_tw.tween_property(hint, "modulate:a", 0.0, 0.5).set_delay(4.0)

func _format_num(val: float) -> String:
	if val >= 1000000: return "%.1fM" % (val / 1000000.0)
	if val >= 1000: return "%.1fK" % (val / 1000.0)
	return str(int(val))

func _fade_in() -> void:
	fade_rect.color = Color(0,0,0,1)
	var tw = create_tween()
	tw.tween_property(fade_rect, "color:a", 0.0, 0.3)
