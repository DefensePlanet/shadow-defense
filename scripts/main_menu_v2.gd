extends Control
## MainMenuV2 — Full interactive menu. Art backgrounds, working buttons, detail panels.

var _backgrounds: Dictionary = {}
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

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		print("[V2] Click: ", event.position)

func _ready() -> void:
	_main = get_tree().get_first_node_in_group("main")
	_load_bgs()
	_set_bg("chapters")
	_build_currency_bar()
	_build_nav()
	_build_chapters()
	_fade_in()

func _load_bgs() -> void:
	var m = {"chapters": "res://assets/ui_frames/scroll_banner.png", "survivors": "res://assets/menu_art/survivors_bg_books.png", "emporium": "res://assets/menu_art/emporium_bg_merchant.png", "codex": "res://assets/menu_art/codex_bg.png", "settings": "res://assets/menu_art/settings_bg_v2.png"}
	for k in m:
		if ResourceLoader.exists(m[k]):
			_backgrounds[k] = load(m[k])

func _set_bg(view: String) -> void:
	if _backgrounds.has(view):
		background.texture = _backgrounds[view]
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

func _build_currency_bar() -> void:
	if not _main: return
	var h = HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override("separation", 24)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	top_bar.add_child(h)
	for c in [["GOLD", _main.gold, Color(1,0.85,0.2)], ["QUILLS", _main.player_quills, Color(0.7,0.5,0.9)], ["SHARDS", _main.player_gear_shards, Color(0.3,0.75,0.9)], ["STARS", _main.player_storybook_stars, Color(1,0.9,0.3)]]:
		h.add_child(_lbl("%d %s" % [c[1], c[0]], 12, c[2]))

func _build_nav() -> void:
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
	print("[V2] Tab: ", tab)
	if current_view == tab: return
	current_view = tab
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
	# Use ScrollContainer but ensure it doesn't eat button clicks
	var sc = ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.follow_focus = true
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
	for i in range(_main.levels.size()):
		var lvl = _main.levels[i]
		var sub = lvl.get("subtitle", "")
		var arc = sub.split(" — ")[0] if " — " in sub else "Prologue"
		if arc == "": arc = "Prologue"
		if arc != cur_arc:
			cur_arc = arc
			var hdr = _lbl(arc.to_upper(), 16, Color(0.90,0.80,0.50))
			hdr.add_theme_constant_override("margin_top", 8)
			vb.add_child(hdr)
		vb.add_child(_level_card(i, lvl))

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
		var pb = Button.new()
		pb.text = "PLAY"; pb.custom_minimum_size = Vector2(150, 30)
		var ps = StyleBoxFlat.new(); ps.bg_color = Color(0.12,0.50,0.12,0.9); ps.set_corner_radius_all(6)
		pb.add_theme_stylebox_override("normal", ps)
		var psh = ps.duplicate(); psh.bg_color = Color(0.18,0.65,0.18)
		pb.add_theme_stylebox_override("hover", psh)
		pb.add_theme_font_size_override("font_size", 13)
		pb.add_theme_color_override("font_color", Color.WHITE)
		pb.pressed.connect(_play.bind(idx, 0))
		btns.add_child(pb)
		row.add_child(btns)
	else:
		row.add_child(_lbl("LOCKED", 11, Color(0.4,0.35,0.3)))
	return p

func _play(idx: int, diff: int) -> void:
	print("[V2] PLAY level ", idx, " diff ", diff)
	if not _main:
		# Try to find main again
		_main = get_tree().get_first_node_in_group("main")
		print("[V2] Re-acquired main: ", _main)
	if not _main:
		print("[V2] ERROR: Cannot find main node!")
		return
	if not _main._is_level_unlocked(idx): return
	_main.selected_difficulty = diff
	if _main.has_method("_hide_menu_v2"): _main._hide_menu_v2()
	if _main.has_method("_do_level_start"): _main._do_level_start(idx)

# ======================== SURVIVORS ========================
func _build_survivors() -> void:
	_clear()
	var sc = ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_area.add_child(sc)
	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(vb)
	vb.add_child(_title("SURVIVORS"))
	if not _main: return
	var unlocked_ct = 0
	for tt in _main.survivor_types:
		if _main._is_character_unlocked(tt): unlocked_ct += 1
	vb.add_child(_lbl("%d / %d Rescued" % [unlocked_ct, _main.survivor_types.size()], 12, Color(0.65,0.58,0.50)))
	var grid = GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	vb.add_child(grid)
	for i in range(PORTRAIT_KEYS.size()):
		grid.add_child(_survivor_card(i))

func _survivor_card(idx: int) -> Button:
	# The card IS a Button — no overlay needed, clicks just work
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(170, 230)
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
	btn.text = ""  # No text — we add children manually
	# Content inside the button
	var vb = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vb)
	# Portrait
	var port = TextureRect.new()
	port.custom_minimum_size = Vector2(150, 150)
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
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(nl)
	# Title
	var ctitle = _main.character_titles[idx] if _main and idx < _main.character_titles.size() else ""
	var tl = _lbl(ctitle, 9, Color(0.55,0.48,0.42))
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(tl)
	btn.pressed.connect(_open_survivor_detail.bind(idx))
	return btn

func _open_survivor_detail(idx: int) -> void:
	print("[V2] Open survivor detail: ", idx)
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
	# Stats section
	right.add_child(_lbl("COMBAT STATS", 14, Color(0.85,0.72,0.40)))
	var tt = _main.survivor_types[idx] if _main and idx < _main.survivor_types.size() else null
	if tt != null and _main.tower_info.has(tt):
		var info = _main.tower_info[tt]
		right.add_child(_stat_bar("Damage", info.get("damage", 0), 50, Color(0.9,0.3,0.2)))
		right.add_child(_stat_bar("Range", info.get("range", 0), 200, Color(0.3,0.7,0.9)))
		right.add_child(_stat_bar("Fire Rate", info.get("fire_rate", 0), 2.5, Color(0.9,0.7,0.2)))
		right.add_child(_lbl("Cost: %d Gold" % info.get("cost", 0), 12, Color(0.85,0.70,0.20)))
	# Gear section
	right.add_child(_lbl("EQUIPPED GEAR", 14, Color(0.85,0.72,0.40)))
	if tt != null and _main.survivor_gear.has(tt):
		var gear = _main.survivor_gear[tt]
		var gp = PanelContainer.new()
		var gs = StyleBoxFlat.new(); gs.bg_color = Color(0.08,0.06,0.14,0.7); gs.set_corner_radius_all(6)
		gs.set_border_width_all(1); gs.border_color = Color(0.55,0.42,0.18,0.5)
		gs.content_margin_left = 8; gs.content_margin_right = 8; gs.content_margin_top = 6; gs.content_margin_bottom = 6
		gp.add_theme_stylebox_override("panel", gs)
		var gv = VBoxContainer.new()
		gp.add_child(gv)
		gv.add_child(_lbl(gear.get("name", "None"), 14, Color(1,0.85,0.3)))
		gv.add_child(_lbl(gear.get("type", ""), 10, Color(0.6,0.55,0.48)))
		gv.add_child(_lbl(gear.get("desc", ""), 10, Color(0.55,0.50,0.45)))
		right.add_child(gp)
	# Sidekicks
	right.add_child(_lbl("SIDEKICKS", 14, Color(0.85,0.72,0.40)))
	if tt != null and _main.survivor_sidekicks.has(tt):
		for sk in _main.survivor_sidekicks[tt]:
			var skp = HBoxContainer.new()
			skp.add_child(_lbl(sk.get("name",""), 12, Color(0.9,0.82,0.55)))
			skp.add_child(_lbl(" — " + sk.get("desc",""), 10, Color(0.55,0.50,0.45)))
			right.add_child(skp)
	# Abilities
	right.add_child(_lbl("ABILITIES", 14, Color(0.85,0.72,0.40)))
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
func _build_emporium() -> void:
	_clear()
	var sc = ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_area.add_child(sc)
	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(vb)
	vb.add_child(_title("THE EMPORIUM"))
	if not _main: return
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	vb.add_child(grid)
	for cat in _main.emporium_categories:
		var p = PanelContainer.new()
		p.custom_minimum_size = Vector2(0, 75)
		var s = StyleBoxFlat.new()
		s.bg_color = Color(0.08,0.06,0.14,0.65)
		s.border_color = Color(0.55,0.42,0.18,0.4)
		s.set_border_width_all(1); s.set_corner_radius_all(6)
		s.content_margin_left = 10; s.content_margin_right = 10
		s.content_margin_top = 6; s.content_margin_bottom = 6
		p.add_theme_stylebox_override("panel", s)
		var cv = VBoxContainer.new()
		p.add_child(cv)
		cv.add_child(_lbl(cat.get("name",""), 14, Color(1,0.85,0.3)))
		var d = _lbl(cat.get("desc",""), 10, Color(0.55,0.50,0.45))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cv.add_child(d)
		if cat.get("badge","") != "":
			cv.add_child(_lbl(cat["badge"], 10, Color(0.3,0.9,0.3)))
		grid.add_child(p)

# ======================== CODEX ========================
func _build_codex() -> void:
	_clear()
	var sc = ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_area.add_child(sc)
	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(vb)
	vb.add_child(_title("THE CODEX"))
	vb.add_child(_lbl("Your archive of knowledge, achievements, and lore.", 12, Color(0.60,0.55,0.48)))
	# Sub-sections
	var sections = [["ACHIEVEMENTS", "Track your accomplishments"], ["BESTIARY", "Catalog of enemies encountered"], ["STORY JOURNAL", "Character journal entries and lore"], ["STATISTICS", "Your gameplay numbers"]]
	for sec in sections:
		var p = PanelContainer.new()
		var s = StyleBoxFlat.new()
		s.bg_color = Color(0.06,0.04,0.12,0.60)
		s.border_color = Color(0.45,0.35,0.20,0.4)
		s.set_border_width_all(1); s.set_corner_radius_all(6)
		s.content_margin_left = 16; s.content_margin_right = 16
		s.content_margin_top = 12; s.content_margin_bottom = 12
		p.add_theme_stylebox_override("panel", s)
		var sv = VBoxContainer.new()
		p.add_child(sv)
		sv.add_child(_lbl(sec[0], 18, Color(0.90,0.80,0.50)))
		sv.add_child(_lbl(sec[1], 11, Color(0.55,0.50,0.45)))
		vb.add_child(p)

# ======================== SETTINGS ========================
func _build_settings() -> void:
	_clear()
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 150)
	margin.add_theme_constant_override("margin_right", 150)
	margin.add_theme_constant_override("margin_top", 10)
	content_area.add_child(margin)
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	margin.add_child(vb)
	vb.add_child(_title("SETTINGS"))
	var settings = [["Music Volume","music"],["SFX Volume","sfx"],["Voice Volume","voice"],["Quality","quality"],["Text Size","text"],["Colorblind Mode","colorblind"],["Game Speed","speed"],["Screen Shake","shake"],["Damage Numbers","numbers"]]
	for s in settings:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		var nl = _lbl(s[0], 14, Color(0.85,0.78,0.65))
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nl)
		var btn = Button.new()
		btn.text = "Toggle"
		btn.custom_minimum_size = Vector2(90, 28)
		var bs = StyleBoxFlat.new(); bs.bg_color = Color(0.15,0.12,0.25,0.8); bs.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", bs)
		var bsh = bs.duplicate(); bsh.bg_color = Color(0.22,0.18,0.35,0.9)
		btn.add_theme_stylebox_override("hover", bsh)
		btn.add_theme_font_size_override("font_size", 11)
		btn.add_theme_color_override("font_color", Color(0.8,0.75,0.65))
		row.add_child(btn)
		vb.add_child(row)

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

func _fade_in() -> void:
	fade_rect.color = Color(0,0,0,1)
	var tw = create_tween()
	tw.tween_property(fade_rect, "color:a", 0.0, 0.3)
