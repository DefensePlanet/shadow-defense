extends Node2D

# Game state
var gold: int = 150
var lives: int = 20
var wave: int = 0
var is_wave_active: bool = false
var placing_tower: bool = false
var ghost_position: Vector2 = Vector2.ZERO

# Tower selection
enum TowerType { ROBIN_HOOD, ALICE, WICKED_WITCH, PETER_PAN, PHANTOM, SCROOGE }
var selected_tower: TowerType = TowerType.ROBIN_HOOD

# Purchase tracking — each tower can only be bought once
var purchased_towers: Dictionary = {}
var tower_buttons: Dictionary = {}

var tower_info = {
	TowerType.ROBIN_HOOD: {"name": "Robin Hood", "cost": 75, "range": 200.0},
	TowerType.ALICE: {"name": "Alice", "cost": 85, "range": 160.0},
	TowerType.WICKED_WITCH: {"name": "Wicked Witch", "cost": 100, "range": 220.0},
	TowerType.PETER_PAN: {"name": "Peter Pan", "cost": 90, "range": 170.0},
	TowerType.PHANTOM: {"name": "The Phantom", "cost": 95, "range": 180.0},
	TowerType.SCROOGE: {"name": "Scrooge", "cost": 60, "range": 140.0},
}

# Constants
var total_waves: int = 20
const MIN_PATH_DIST: float = 40.0
const MIN_TOWER_DIST: float = 48.0

# Preloads
var tower_scenes = {
	TowerType.ROBIN_HOOD: preload("res://scenes/robin_hood.tscn"),
	TowerType.ALICE: preload("res://scenes/alice.tscn"),
	TowerType.WICKED_WITCH: preload("res://scenes/wicked_witch.tscn"),
	TowerType.PETER_PAN: preload("res://scenes/peter_pan.tscn"),
	TowerType.PHANTOM: preload("res://scenes/phantom.tscn"),
	TowerType.SCROOGE: preload("res://scenes/scrooge.tscn"),
}
var enemy_scene = preload("res://scenes/enemy.tscn")

@onready var enemy_path: Path2D = $EnemyPath
@onready var towers_node: Node2D = $Towers

# UI references
var wave_label: Label
var gold_label: Label
var lives_label: Label
var start_button: Button
var game_over_label: Label
var info_label: Label
var top_bar: ColorRect
var bottom_panel: ColorRect

# Ability choice UI
var ability_panel: ColorRect
var ability_title: Label
var ability_buttons: Array = []
var _ability_tower: Node2D = null

# Tower upgrade selection
var selected_tower_node: Node2D = null
const TOWER_SELECT_RADIUS: float = 28.0
var upgrade_panel: ColorRect
var upgrade_name_label: Label
var upgrade_buttons: Array = []  # 4 upgrade tier buttons
var upgrade_cost_labels: Array = []  # 4 cost labels
var upgrade_status_rects: Array = []  # 4 background rects for status coloring
var sell_button: Button
var sell_value_label: Label

# Game state & levels
enum GameState { MENU, PLAYING, GAME_OVER_STATE }
var game_state: int = GameState.MENU
var current_level: int = -1

# Menu UI
var menu_overlay: ColorRect
var menu_title: Label
var menu_subtitle: Label
var level_cards: Array = []
var return_button: Button
var completed_levels: Array = []
var level_stars: Dictionary = {}

# Storybook menu - character page showcase
var menu_character_index: int = 0
var menu_level_name_label: Label
var menu_level_desc_label: Label
var menu_level_stats_label: Label
var menu_level_stars_label: Label
var menu_play_button: Button
var menu_left_arrow: Button
var menu_right_arrow: Button
var menu_showcase_panel: ColorRect
# Chapter card UI elements
var chapter_buttons: Array = []  # 3 PLAY buttons for chapters
var chapter_title_labels: Array = []  # 3 chapter title labels
var chapter_desc_labels: Array = []  # 3 chapter description labels
var chapter_star_labels: Array = []  # 3 star display labels
var chapter_stat_labels: Array = []  # 3 stat labels (waves/gold/lives)
var chapter_lock_labels: Array = []  # 3 lock/difficulty labels

# Gothic menu - bottom nav
var menu_nav_buttons: Array = []
var menu_nav_labels: Array = []
var menu_current_view: String = "chapters"
var menu_star_total_label: Label

# Heroes tab
var hero_preview_node: Node2D = null
var hero_preview_index: int = 0
var hero_types = [TowerType.ROBIN_HOOD, TowerType.ALICE, TowerType.WICKED_WITCH, TowerType.PETER_PAN, TowerType.PHANTOM, TowerType.SCROOGE]
var hero_descriptions = {
	TowerType.ROBIN_HOOD: "The legendary outlaw of Sherwood Forest.\nLong-range archer with piercing arrows and gold bonus.",
	TowerType.ALICE: "The curious girl from Wonderland.\nThrows playing cards that shrink and slow enemies.",
	TowerType.WICKED_WITCH: "The Wicked Witch of the West.\nSwoops to strike enemies, summons wolves and monkeys.",
	TowerType.PETER_PAN: "The boy who never grew up.\nFast dagger attacks with shadow and fairy dust.",
	TowerType.PHANTOM: "The masked genius beneath the Opera.\nHeavy music note attacks with stun and AoE.",
	TowerType.SCROOGE: "The miserly old man visited by ghosts.\nCoin attacks generate gold, ghosts mark enemies.",
}

# Storybook menu - animation (dust motes, warm glow)
var _dust_positions: Array = []
var _book_candle_positions: Array = []

var character_names: Array = ["Robin Hood", "Alice", "Wicked Witch", "Peter Pan", "The Phantom", "Scrooge"]
var character_novels: Array = ["The Merry Adventures of Robin Hood", "Alice's Adventures in Wonderland", "The Wonderful Wizard of Oz", "Peter and Wendy", "The Phantom of the Opera", "A Christmas Carol"]
var character_quotes: Array = [
	"Steal from the rich, defend the path!",
	"Curiouser and curiouser!",
	"I'll get you, my pretties!",
	"To live will be an awfully big adventure!",
	"The Music of the Night!",
	"Bah! Humbug!",
]

var levels = [
	# === ROBIN HOOD — The Merry Adventures of Robin Hood (Levels 0-2) ===
	{
		"name": "The Outlaw's Call", "subtitle": "Sherwood Forest — Chapter 1",
		"description": "Robin becomes an outlaw and builds his camp in Sherwood Forest. Defend the hideout from the Sheriff's tax collectors!",
		"character": 0, "chapter": 0,
		"waves": 12, "gold": 200, "lives": 25, "difficulty": 1.0,
		"sky_color": Color(0.02, 0.06, 0.10),
		"ground_color": Color(0.06, 0.16, 0.04),
	},
	{
		"name": "The Sheriff's Pursuit", "subtitle": "Sherwood Forest — Chapter 2",
		"description": "The Sheriff of Nottingham sends his soldiers to hunt Robin. Defend Little John's Bridge and the river crossing!",
		"character": 0, "chapter": 1,
		"waves": 15, "gold": 200, "lives": 22, "difficulty": 1.15,
		"sky_color": Color(0.02, 0.04, 0.08),
		"ground_color": Color(0.05, 0.14, 0.03),
	},
	{
		"name": "Siege of Nottingham", "subtitle": "Sherwood Forest — Chapter 3",
		"description": "Robin leads the attack on Nottingham Castle to free his captured men. Defeat the Sheriff at the castle gates!",
		"character": 0, "chapter": 2,
		"waves": 18, "gold": 225, "lives": 20, "difficulty": 1.3,
		"sky_color": Color(0.06, 0.04, 0.02),
		"ground_color": Color(0.08, 0.08, 0.06),
	},
	# === ALICE — Alice's Adventures in Wonderland (Levels 3-5) ===
	{
		"name": "Down the Rabbit Hole", "subtitle": "Wonderland — Chapter 1",
		"description": "Alice follows the White Rabbit into a curious garden of giant mushrooms, talking flowers, and nonsense.",
		"character": 1, "chapter": 0,
		"waves": 12, "gold": 200, "lives": 25, "difficulty": 1.0,
		"sky_color": Color(0.12, 0.04, 0.16),
		"ground_color": Color(0.08, 0.18, 0.06),
	},
	{
		"name": "The Mad Tea Party", "subtitle": "Wonderland — Chapter 2",
		"description": "Deeper into Wonderland — the Mad Hatter's tea party and the Queen of Hearts' card army advances, painting the roses red.",
		"character": 1, "chapter": 1,
		"waves": 15, "gold": 210, "lives": 22, "difficulty": 1.2,
		"sky_color": Color(0.10, 0.03, 0.14),
		"ground_color": Color(0.06, 0.14, 0.05),
	},
	{
		"name": "The Queen's Court", "subtitle": "Wonderland — Chapter 3",
		"description": "Alice reaches the Queen's palace. The rose garden runs red. Off with their heads!",
		"character": 1, "chapter": 2,
		"waves": 18, "gold": 225, "lives": 18, "difficulty": 1.4,
		"sky_color": Color(0.14, 0.02, 0.08),
		"ground_color": Color(0.10, 0.06, 0.06),
	},
	# === WICKED WITCH — The Wonderful Wizard of Oz (Levels 6-8) ===
	{
		"name": "The Yellow Brick Road", "subtitle": "Land of Oz — Chapter 1",
		"description": "Dorothy and companions follow the golden road through poppy fields toward the Emerald City.",
		"character": 2, "chapter": 0,
		"waves": 12, "gold": 210, "lives": 25, "difficulty": 1.05,
		"sky_color": Color(0.02, 0.10, 0.06),
		"ground_color": Color(0.14, 0.12, 0.02),
	},
	{
		"name": "The Witch's Domain", "subtitle": "Land of Oz — Chapter 2",
		"description": "The Wicked Witch of the West sends her flying monkeys. Dark western territory and dead forests loom ahead.",
		"character": 2, "chapter": 1,
		"waves": 16, "gold": 220, "lives": 22, "difficulty": 1.3,
		"sky_color": Color(0.04, 0.06, 0.02),
		"ground_color": Color(0.10, 0.08, 0.04),
	},
	{
		"name": "The Emerald Throne", "subtitle": "Land of Oz — Chapter 3",
		"description": "Inside the Emerald City, the Nome King rises to seize power. Green crystal walls crack as rock soldiers march.",
		"character": 2, "chapter": 2,
		"waves": 20, "gold": 240, "lives": 18, "difficulty": 1.5,
		"sky_color": Color(0.02, 0.08, 0.04),
		"ground_color": Color(0.06, 0.12, 0.06),
	},
	# === PETER PAN — Peter and Wendy (Levels 9-11) ===
	{
		"name": "Flight to Neverland", "subtitle": "Neverland — Chapter 1",
		"description": "Second star to the right and straight on till morning. Mermaid lagoon sparkles and pirate scouts appear.",
		"character": 3, "chapter": 0,
		"waves": 12, "gold": 215, "lives": 25, "difficulty": 1.1,
		"sky_color": Color(0.04, 0.06, 0.14),
		"ground_color": Color(0.08, 0.18, 0.06),
	},
	{
		"name": "The Lost Boys' Stand", "subtitle": "Neverland — Chapter 2",
		"description": "Captain Hook's pirate officers lead raiding parties through the dense jungle to attack the Lost Boys' hideout.",
		"character": 3, "chapter": 1,
		"waves": 17, "gold": 225, "lives": 20, "difficulty": 1.4,
		"sky_color": Color(0.03, 0.05, 0.10),
		"ground_color": Color(0.06, 0.15, 0.04),
	},
	{
		"name": "The Jolly Roger", "subtitle": "Neverland — Chapter 3",
		"description": "The final battle aboard Captain Hook's ship. Sword fights on deck, walking the plank over the ticking crocodile!",
		"character": 3, "chapter": 2,
		"waves": 20, "gold": 240, "lives": 18, "difficulty": 1.6,
		"sky_color": Color(0.08, 0.04, 0.02),
		"ground_color": Color(0.12, 0.08, 0.06),
	},
	# === PHANTOM — The Phantom of the Opera (Levels 12-14) ===
	{
		"name": "The Grand Stage", "subtitle": "Paris Opera — Chapter 1",
		"description": "The Paris Opera House, elegant and grand. Strange things happen during performances — a ghost in the wings.",
		"character": 4, "chapter": 0,
		"waves": 14, "gold": 220, "lives": 22, "difficulty": 1.2,
		"sky_color": Color(0.04, 0.02, 0.08),
		"ground_color": Color(0.10, 0.08, 0.10),
	},
	{
		"name": "The Labyrinth", "subtitle": "Paris Opera — Chapter 2",
		"description": "Descending beneath the opera into mirrors, candlelit tunnels, and traps. The Phantom reveals himself.",
		"character": 4, "chapter": 1,
		"waves": 18, "gold": 235, "lives": 20, "difficulty": 1.5,
		"sky_color": Color(0.03, 0.02, 0.06),
		"ground_color": Color(0.08, 0.06, 0.08),
	},
	{
		"name": "The Phantom's Lair", "subtitle": "Paris Opera — Chapter 3",
		"description": "The underground lake, the great organ, roses on black water. Defeat the Dark Phantom in his domain!",
		"character": 4, "chapter": 2,
		"waves": 22, "gold": 250, "lives": 16, "difficulty": 1.7,
		"sky_color": Color(0.02, 0.01, 0.04),
		"ground_color": Color(0.06, 0.04, 0.06),
	},
	# === SCROOGE — A Christmas Carol (Levels 15-17) ===
	{
		"name": "Christmas Eve", "subtitle": "Victorian London — Chapter 1",
		"description": "Victorian London on a cold Christmas Eve. Scrooge at his counting house, ignoring the carolers. Marley's ghost appears.",
		"character": 5, "chapter": 0,
		"waves": 14, "gold": 225, "lives": 22, "difficulty": 1.3,
		"sky_color": Color(0.08, 0.08, 0.12),
		"ground_color": Color(0.10, 0.10, 0.12),
	},
	{
		"name": "The Three Spirits", "subtitle": "Victorian London — Chapter 2",
		"description": "The Ghosts of Christmas Past, Present, and Future visit Scrooge. Spectral London, gravestones, chains rattling.",
		"character": 5, "chapter": 1,
		"waves": 18, "gold": 240, "lives": 18, "difficulty": 1.6,
		"sky_color": Color(0.06, 0.06, 0.10),
		"ground_color": Color(0.08, 0.08, 0.10),
	},
	{
		"name": "Redemption's Dawn", "subtitle": "Victorian London — Chapter 3",
		"description": "Christmas morning. The Ghost of Christmas Yet to Come leads an army of despair. Warm light fights to break through.",
		"character": 5, "chapter": 2,
		"waves": 25, "gold": 260, "lives": 15, "difficulty": 1.8,
		"sky_color": Color(0.10, 0.08, 0.06),
		"ground_color": Color(0.12, 0.10, 0.10),
	},
]

# Wave management
var enemies_to_spawn: int = 0
var enemies_alive: int = 0
var spawn_timer: float = 0.0
var spawn_interval: float = 0.75

# Fast-forward
var fast_forward: bool = false
var speed_button: Button
var wave_auto_timer: float = -1.0

# Free placement tracking
var placed_tower_positions: Array = []
var path_points: PackedVector2Array = PackedVector2Array()

# Level decoration data (regenerated per level)
var _decorations: Array = []
var _time: float = 0.0

# Audio — procedural hip hop beat
var beat_player: AudioStreamPlayer
var beat_playback: AudioStreamGeneratorPlayback
var beat_buffer: PackedVector2Array = PackedVector2Array()
var beat_buf_pos: int = 0
var beat_playing: bool = false

# Audio — character voice clips
var voice_player: AudioStreamPlayer
var voice_clips: Dictionary = {}
var tower_quotes: Dictionary = {}

func _ready() -> void:
	add_to_group("main")
	_cache_path_points()
	_generate_decorations_for_level(0)
	_create_ui()
	_setup_audio()
	_show_menu()

func _cache_path_points() -> void:
	var curve = enemy_path.curve
	if not curve:
		return
	var length = curve.get_baked_length()
	for i in range(0, int(length), 6):
		path_points.append(curve.sample_baked(float(i)))

func _generate_decorations_for_level(index: int) -> void:
	_decorations.clear()
	var rng = RandomNumberGenerator.new()
	rng.seed = 42 + index

	match index:
		0: # Sherwood Forest
			for i in range(30):
				var pos = Vector2(rng.randf_range(20, 1260), rng.randf_range(55, 620))
				if _dist_to_path(pos) > 60.0:
					_decorations.append({"pos": pos, "type": "oak_tree", "size": rng.randf_range(14, 32), "extra": rng.randf_range(-0.04, 0.04)})
			for i in range(6):
				var pos = Vector2(rng.randf_range(60, 1220), rng.randf_range(100, 580))
				if _dist_to_path(pos) > 70.0:
					_decorations.append({"pos": pos, "type": "target", "size": rng.randf_range(6, 10), "extra": 0.0})
			for i in range(8):
				var pos = Vector2(rng.randf_range(40, 1240), rng.randf_range(80, 600))
				if _dist_to_path(pos) > 55.0:
					_decorations.append({"pos": pos, "type": "bush", "size": rng.randf_range(8, 16), "extra": rng.randf_range(0.0, 1.0)})
			for i in range(4):
				var pos = Vector2(rng.randf_range(100, 1100), rng.randf_range(200, 550))
				if _dist_to_path(pos) > 80.0:
					_decorations.append({"pos": pos, "type": "deer", "size": rng.randf_range(10, 16), "extra": rng.randf_range(0, TAU)})
			for i in range(2):
				var pos = Vector2(rng.randf_range(200, 1000), rng.randf_range(150, 500))
				if _dist_to_path(pos) > 90.0:
					_decorations.append({"pos": pos, "type": "campfire", "size": 12.0, "extra": rng.randf_range(0, TAU)})
		1: # Wonderland
			for i in range(15):
				var pos = Vector2(rng.randf_range(20, 1260), rng.randf_range(55, 620))
				if _dist_to_path(pos) > 55.0:
					_decorations.append({"pos": pos, "type": "giant_mushroom", "size": rng.randf_range(10, 24), "extra": rng.randf_range(0.0, 1.0)})
			for i in range(10):
				var pos = Vector2(rng.randf_range(30, 1250), rng.randf_range(60, 300))
				_decorations.append({"pos": pos, "type": "floating_card", "size": rng.randf_range(6, 12), "extra": rng.randf_range(0, TAU)})
			for i in range(8):
				var pos = Vector2(rng.randf_range(40, 1240), rng.randf_range(100, 600))
				if _dist_to_path(pos) > 50.0:
					_decorations.append({"pos": pos, "type": "rose", "size": rng.randf_range(4, 8), "extra": rng.randf_range(0.0, 1.0)})
			for i in range(5):
				var pos = Vector2(rng.randf_range(50, 1230), rng.randf_range(80, 560))
				if _dist_to_path(pos) > 60.0:
					_decorations.append({"pos": pos, "type": "teacup", "size": rng.randf_range(6, 10), "extra": 0.0})
		2: # Oz
			for i in range(25):
				var pos = Vector2(rng.randf_range(20, 1260), rng.randf_range(100, 620))
				if _dist_to_path(pos) > 50.0:
					_decorations.append({"pos": pos, "type": "poppy", "size": rng.randf_range(3, 7), "extra": rng.randf_range(0, TAU)})
			for i in range(8):
				var pos = Vector2(rng.randf_range(40, 1240), rng.randf_range(80, 600))
				if _dist_to_path(pos) > 60.0:
					_decorations.append({"pos": pos, "type": "emerald_crystal", "size": rng.randf_range(5, 12), "extra": rng.randf_range(0, TAU)})
			for i in range(4):
				var pos = Vector2(rng.randf_range(100, 1100), rng.randf_range(150, 550))
				if _dist_to_path(pos) > 70.0:
					_decorations.append({"pos": pos, "type": "scarecrow", "size": rng.randf_range(12, 18), "extra": 0.0})
		3: # Neverland
			for i in range(35):
				var pos = Vector2(rng.randf_range(20, 1260), rng.randf_range(55, 620))
				if _dist_to_path(pos) > 60.0:
					_decorations.append({"pos": pos, "type": "jungle_tree", "size": rng.randf_range(14, 30), "extra": rng.randf_range(-0.04, 0.04)})
			for i in range(12):
				var pos = Vector2(rng.randf_range(40, 1240), rng.randf_range(80, 600))
				if _dist_to_path(pos) > 50.0:
					_decorations.append({"pos": pos, "type": "fairy", "size": 2.0, "extra": rng.randf_range(0, TAU)})
			for i in range(18):
				var pos = Vector2(rng.randf_range(20, 1260), rng.randf_range(60, 615))
				if _dist_to_path(pos) > 45.0:
					_decorations.append({"pos": pos, "type": "mushroom", "size": rng.randf_range(3, 7), "extra": rng.randf_range(0, 1)})
			for i in range(25):
				var pos = Vector2(rng.randf_range(10, 1270), rng.randf_range(52, 180))
				_decorations.append({"pos": pos, "type": "star", "size": rng.randf_range(0.3, 0.8), "extra": rng.randf_range(0, TAU)})
		4: # Paris Opera
			for i in range(10):
				var pos = Vector2(rng.randf_range(60, 1220), rng.randf_range(100, 580))
				if _dist_to_path(pos) > 55.0:
					_decorations.append({"pos": pos, "type": "candelabra", "size": rng.randf_range(8, 14), "extra": rng.randf_range(0, TAU)})
			for i in range(6):
				var pos = Vector2(rng.randf_range(80, 1200), rng.randf_range(120, 500))
				if _dist_to_path(pos) > 65.0:
					_decorations.append({"pos": pos, "type": "mirror", "size": rng.randf_range(10, 18), "extra": rng.randf_range(0, TAU)})
			for i in range(12):
				var pos = Vector2(rng.randf_range(30, 1250), rng.randf_range(80, 600))
				if _dist_to_path(pos) > 50.0:
					_decorations.append({"pos": pos, "type": "rose", "size": rng.randf_range(3, 6), "extra": rng.randf_range(0.0, 1.0)})
			for i in range(8):
				var pos = Vector2(rng.randf_range(40, 1240), rng.randf_range(60, 400))
				_decorations.append({"pos": pos, "type": "sheet_music", "size": rng.randf_range(4, 8), "extra": rng.randf_range(0, TAU)})
		5: # Victorian London
			for i in range(12):
				var pos = Vector2(rng.randf_range(60, 1220), rng.randf_range(100, 560))
				if _dist_to_path(pos) > 55.0:
					_decorations.append({"pos": pos, "type": "lamp_post", "size": rng.randf_range(20, 30), "extra": rng.randf_range(0, TAU)})
			for i in range(8):
				var pos = Vector2(rng.randf_range(40, 1240), rng.randf_range(80, 600))
				if _dist_to_path(pos) > 60.0:
					_decorations.append({"pos": pos, "type": "bare_tree", "size": rng.randf_range(14, 26), "extra": rng.randf_range(-0.04, 0.04)})
			for i in range(15):
				var pos = Vector2(rng.randf_range(20, 1260), rng.randf_range(100, 620))
				if _dist_to_path(pos) > 45.0:
					_decorations.append({"pos": pos, "type": "snow_pile", "size": rng.randf_range(5, 12), "extra": 0.0})
			for i in range(6):
				var pos = Vector2(rng.randf_range(100, 1180), rng.randf_range(150, 500))
				if _dist_to_path(pos) > 70.0:
					_decorations.append({"pos": pos, "type": "chimney", "size": rng.randf_range(8, 14), "extra": rng.randf_range(0, TAU)})

func _create_ui() -> void:
	var ui = $UI

	# Top bar (dark wood / pirate ship plank style)
	top_bar = ColorRect.new()
	top_bar.color = Color(0.12, 0.08, 0.05, 0.9)
	top_bar.position = Vector2(0, 0)
	top_bar.size = Vector2(1280, 50)
	ui.add_child(top_bar)

	wave_label = Label.new()
	wave_label.position = Vector2(20, 8)
	wave_label.add_theme_font_size_override("font_size", 24)
	top_bar.add_child(wave_label)

	gold_label = Label.new()
	gold_label.position = Vector2(280, 8)
	gold_label.add_theme_font_size_override("font_size", 24)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	top_bar.add_child(gold_label)

	lives_label = Label.new()
	lives_label.position = Vector2(520, 8)
	lives_label.add_theme_font_size_override("font_size", 24)
	lives_label.add_theme_color_override("font_color", Color(1.0, 0.39, 0.28))
	top_bar.add_child(lives_label)

	# Bottom panel
	bottom_panel = ColorRect.new()
	bottom_panel.color = Color(0.12, 0.08, 0.05, 0.9)
	bottom_panel.position = Vector2(0, 628)
	bottom_panel.size = Vector2(1280, 92)
	ui.add_child(bottom_panel)

	var btn_h = 36
	var row1_y = 6
	var row2_y = 48

	var robin_button = _make_button("Robin [75G]", Vector2(8, row1_y), Vector2(130, btn_h))
	robin_button.pressed.connect(_on_tower_pressed.bind(TowerType.ROBIN_HOOD, "Robin Hood — long range archer, gold bonus. Right-click to cancel."))
	bottom_panel.add_child(robin_button)
	tower_buttons[TowerType.ROBIN_HOOD] = robin_button

	var alice_button = _make_button("Alice [85G]", Vector2(144, row1_y), Vector2(130, btn_h))
	alice_button.pressed.connect(_on_tower_pressed.bind(TowerType.ALICE, "Alice — cards, slows enemies. Right-click to cancel."))
	bottom_panel.add_child(alice_button)
	tower_buttons[TowerType.ALICE] = alice_button

	var witch_button = _make_button("Witch [100G]", Vector2(280, row1_y), Vector2(130, btn_h))
	witch_button.pressed.connect(_on_tower_pressed.bind(TowerType.WICKED_WITCH, "Wicked Witch — eye blast, wolves. Right-click to cancel."))
	bottom_panel.add_child(witch_button)
	tower_buttons[TowerType.WICKED_WITCH] = witch_button

	var peter_button = _make_button("Peter [90G]", Vector2(8, row2_y), Vector2(130, btn_h))
	peter_button.pressed.connect(_on_tower_pressed.bind(TowerType.PETER_PAN, "Peter Pan — fast daggers, shadow. Right-click to cancel."))
	bottom_panel.add_child(peter_button)
	tower_buttons[TowerType.PETER_PAN] = peter_button

	var phantom_button = _make_button("Phantom [95G]", Vector2(144, row2_y), Vector2(130, btn_h))
	phantom_button.pressed.connect(_on_tower_pressed.bind(TowerType.PHANTOM, "Phantom — heavy hits, stun, chandelier. Right-click to cancel."))
	bottom_panel.add_child(phantom_button)
	tower_buttons[TowerType.PHANTOM] = phantom_button

	var scrooge_button = _make_button("Scrooge [60G]", Vector2(280, row2_y), Vector2(130, btn_h))
	scrooge_button.pressed.connect(_on_tower_pressed.bind(TowerType.SCROOGE, "Scrooge — coins, gold gen, ghost marks. Right-click to cancel."))
	bottom_panel.add_child(scrooge_button)
	tower_buttons[TowerType.SCROOGE] = scrooge_button

	info_label = Label.new()
	info_label.position = Vector2(490, 10)
	info_label.size = Vector2(540, 70)
	info_label.add_theme_font_size_override("font_size", 13)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.text = "Welcome to Neverland! Select a tower, then click to place it."
	bottom_panel.add_child(info_label)

	start_button = Button.new()
	start_button.text = "  Start Wave  "
	start_button.position = Vector2(1020, 25)
	start_button.custom_minimum_size = Vector2(160, 44)
	start_button.pressed.connect(_on_start_wave_pressed)
	bottom_panel.add_child(start_button)

	speed_button = Button.new()
	speed_button.text = "  >>  "
	speed_button.position = Vector2(1190, 25)
	speed_button.custom_minimum_size = Vector2(70, 44)
	speed_button.pressed.connect(_on_speed_pressed)
	bottom_panel.add_child(speed_button)

	game_over_label = Label.new()
	game_over_label.add_theme_font_size_override("font_size", 72)
	game_over_label.add_theme_color_override("font_color", Color.RED)
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.position = Vector2(240, 280)
	game_over_label.size = Vector2(800, 100)
	game_over_label.visible = false
	ui.add_child(game_over_label)

	# === Ability choice panel (centered, hidden by default) ===
	ability_panel = ColorRect.new()
	ability_panel.color = Color(0.08, 0.06, 0.12, 0.95)
	ability_panel.position = Vector2(290, 150)
	ability_panel.size = Vector2(700, 380)
	ability_panel.visible = false
	ui.add_child(ability_panel)

	# Panel border
	var border = ColorRect.new()
	border.color = Color(1.0, 0.85, 0.2, 0.6)
	border.position = Vector2(-2, -2)
	border.size = Vector2(704, 384)
	border.z_index = -1
	ability_panel.add_child(border)

	ability_title = Label.new()
	ability_title.text = "Choose an Ability"
	ability_title.position = Vector2(20, 12)
	ability_title.add_theme_font_size_override("font_size", 24)
	ability_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	ability_panel.add_child(ability_title)

	var subtitle = Label.new()
	subtitle.text = "Your tower reached 1500 damage! Pick a special ability:"
	subtitle.position = Vector2(20, 45)
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))
	ability_panel.add_child(subtitle)

	for i in range(4):
		var btn = Button.new()
		btn.position = Vector2(20, 75 + i * 72)
		btn.custom_minimum_size = Vector2(660, 60)
		btn.pressed.connect(_on_ability_chosen.bind(i))
		ability_panel.add_child(btn)
		ability_buttons.append(btn)

	# === Tower upgrade panel (right-side, hidden by default) ===
	upgrade_panel = ColorRect.new()
	upgrade_panel.color = Color(0.08, 0.05, 0.12, 0.95)
	upgrade_panel.position = Vector2(1080, 50)
	upgrade_panel.size = Vector2(200, 578)
	upgrade_panel.visible = false
	ui.add_child(upgrade_panel)

	# Gold border
	var upg_border = ColorRect.new()
	upg_border.color = Color(0.85, 0.65, 0.1, 0.5)
	upg_border.position = Vector2(-2, -2)
	upg_border.size = Vector2(204, 582)
	upg_border.z_index = -1
	upgrade_panel.add_child(upg_border)

	# Tower name label at top
	upgrade_name_label = Label.new()
	upgrade_name_label.position = Vector2(10, 10)
	upgrade_name_label.size = Vector2(180, 30)
	upgrade_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upgrade_name_label.add_theme_font_size_override("font_size", 18)
	upgrade_name_label.add_theme_color_override("font_color", Color(0.85, 0.65, 0.1))
	upgrade_panel.add_child(upgrade_name_label)

	# Separator line (drawn via a thin ColorRect)
	var sep = ColorRect.new()
	sep.color = Color(0.85, 0.65, 0.1, 0.3)
	sep.position = Vector2(10, 42)
	sep.size = Vector2(180, 1)
	upgrade_panel.add_child(sep)

	# Portrait area placeholder
	var portrait_bg = ColorRect.new()
	portrait_bg.color = Color(0.06, 0.03, 0.09, 0.8)
	portrait_bg.position = Vector2(50, 50)
	portrait_bg.size = Vector2(100, 80)
	upgrade_panel.add_child(portrait_bg)

	var portrait_border = ColorRect.new()
	portrait_border.color = Color(0.85, 0.65, 0.1, 0.3)
	portrait_border.position = Vector2(48, 48)
	portrait_border.size = Vector2(104, 84)
	portrait_border.z_index = -1
	upgrade_panel.add_child(portrait_border)

	# 4 upgrade slots stacked vertically
	for i in range(4):
		var slot_y = 145 + i * 80

		# Status background rect (changes color based on state)
		var status_rect = ColorRect.new()
		status_rect.position = Vector2(10, slot_y)
		status_rect.size = Vector2(180, 65)
		status_rect.color = Color(0.12, 0.08, 0.16, 0.8)
		upgrade_panel.add_child(status_rect)
		upgrade_status_rects.append(status_rect)

		# Slot border
		var slot_border = ColorRect.new()
		slot_border.color = Color(0.4, 0.3, 0.5, 0.4)
		slot_border.position = Vector2(-1, -1)
		slot_border.size = Vector2(182, 67)
		slot_border.z_index = -1
		status_rect.add_child(slot_border)

		# Tier number label
		var tier_label = Label.new()
		tier_label.text = str(i + 1)
		tier_label.position = Vector2(6, 4)
		tier_label.add_theme_font_size_override("font_size", 12)
		tier_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.7))
		status_rect.add_child(tier_label)

		# Upgrade button (clickable area)
		var upg_btn = Button.new()
		upg_btn.position = Vector2(4, 2)
		upg_btn.custom_minimum_size = Vector2(172, 61)
		upg_btn.flat = true
		upg_btn.pressed.connect(_on_upgrade_tier_pressed.bind(i))
		status_rect.add_child(upg_btn)
		upgrade_buttons.append(upg_btn)

		# Cost label (right side)
		var cost_label = Label.new()
		cost_label.position = Vector2(4, 42)
		cost_label.size = Vector2(172, 20)
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cost_label.add_theme_font_size_override("font_size", 13)
		cost_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
		status_rect.add_child(cost_label)
		upgrade_cost_labels.append(cost_label)

	# Sell button at bottom
	sell_button = Button.new()
	sell_button.text = "SELL"
	sell_button.position = Vector2(20, 480)
	sell_button.custom_minimum_size = Vector2(160, 44)
	sell_button.pressed.connect(_on_sell_pressed)
	upgrade_panel.add_child(sell_button)

	# Sell value label
	sell_value_label = Label.new()
	sell_value_label.position = Vector2(20, 528)
	sell_value_label.size = Vector2(160, 20)
	sell_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sell_value_label.add_theme_font_size_override("font_size", 12)
	sell_value_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))
	upgrade_panel.add_child(sell_value_label)

	# === MAIN MENU OVERLAY ===
	menu_overlay = ColorRect.new()
	menu_overlay.color = Color(0, 0, 0, 0)  # Transparent — we draw the background in _draw()
	menu_overlay.position = Vector2(0, 0)
	menu_overlay.size = Vector2(1280, 720)
	menu_overlay.visible = true
	ui.add_child(menu_overlay)

	# Generate storybook decoration positions
	var rng2 = RandomNumberGenerator.new()
	rng2.seed = 99
	for i in range(20):
		_dust_positions.append({"x": rng2.randf_range(50, 1230), "y": rng2.randf_range(50, 600), "speed": rng2.randf_range(0.2, 0.6), "size": rng2.randf_range(1.0, 2.5), "offset": rng2.randf_range(0, TAU)})
	for i in range(4):
		_book_candle_positions.append({"x": rng2.randf_range(60, 1220), "y": rng2.randf_range(500, 580), "offset": rng2.randf_range(0, TAU)})

	# Title — hidden by default (shown on book cover, drawn procedurally)
	menu_title = Label.new()
	menu_title.text = ""
	menu_title.position = Vector2(20, 22)
	menu_title.size = Vector2(600, 60)
	menu_title.visible = false
	menu_overlay.add_child(menu_title)

	# Subtitle — hidden (drawn on book cover)
	menu_subtitle = Label.new()
	menu_subtitle.text = ""
	menu_subtitle.position = Vector2(22, 72)
	menu_subtitle.size = Vector2(400, 30)
	menu_subtitle.visible = false
	menu_overlay.add_child(menu_subtitle)

	# Star total (top right, above book)
	menu_star_total_label = Label.new()
	menu_star_total_label.position = Vector2(1050, 8)
	menu_star_total_label.size = Vector2(220, 30)
	menu_star_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	menu_star_total_label.add_theme_font_size_override("font_size", 18)
	menu_star_total_label.add_theme_color_override("font_color", Color(0.85, 0.65, 0.1))
	menu_overlay.add_child(menu_star_total_label)

	# === OPEN BOOK PANEL (two-page spread) ===
	menu_showcase_panel = ColorRect.new()
	menu_showcase_panel.color = Color(0, 0, 0, 0)  # Transparent, we draw the book in _draw
	menu_showcase_panel.position = Vector2(60, 45)
	menu_showcase_panel.size = Vector2(1160, 560)
	menu_overlay.add_child(menu_showcase_panel)

	# --- LEFT PAGE: Character info ---
	# Character name (calligraphy gold)
	menu_level_name_label = Label.new()
	menu_level_name_label.position = Vector2(40, 30)
	menu_level_name_label.size = Vector2(500, 40)
	menu_level_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_level_name_label.add_theme_font_size_override("font_size", 30)
	menu_level_name_label.add_theme_color_override("font_color", Color(0.65, 0.45, 0.1))
	menu_showcase_panel.add_child(menu_level_name_label)

	# Novel title (italic)
	menu_level_desc_label = Label.new()
	menu_level_desc_label.position = Vector2(40, 75)
	menu_level_desc_label.size = Vector2(500, 25)
	menu_level_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_level_desc_label.add_theme_font_size_override("font_size", 14)
	menu_level_desc_label.add_theme_color_override("font_color", Color(0.5, 0.4, 0.3))
	menu_showcase_panel.add_child(menu_level_desc_label)

	# Character quote
	menu_level_stats_label = Label.new()
	menu_level_stats_label.position = Vector2(60, 380)
	menu_level_stats_label.size = Vector2(460, 60)
	menu_level_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_level_stats_label.add_theme_font_size_override("font_size", 13)
	menu_level_stats_label.add_theme_color_override("font_color", Color(0.45, 0.35, 0.25))
	menu_level_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_showcase_panel.add_child(menu_level_stats_label)

	# Stars display (unused in chapters view, used in heroes)
	menu_level_stars_label = Label.new()
	menu_level_stars_label.position = Vector2(40, 440)
	menu_level_stars_label.size = Vector2(500, 30)
	menu_level_stars_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_level_stars_label.add_theme_font_size_override("font_size", 20)
	menu_level_stars_label.add_theme_color_override("font_color", Color(0.85, 0.65, 0.1))
	menu_showcase_panel.add_child(menu_level_stars_label)

	# Left arrow (page turn)
	menu_left_arrow = Button.new()
	menu_left_arrow.text = "  <  "
	menu_left_arrow.position = Vector2(10, 490)
	menu_left_arrow.custom_minimum_size = Vector2(60, 40)
	menu_left_arrow.pressed.connect(_on_menu_left)
	menu_showcase_panel.add_child(menu_left_arrow)

	# Right arrow (page turn)
	menu_right_arrow = Button.new()
	menu_right_arrow.text = "  >  "
	menu_right_arrow.position = Vector2(1090, 490)
	menu_right_arrow.custom_minimum_size = Vector2(60, 40)
	menu_right_arrow.pressed.connect(_on_menu_right)
	menu_showcase_panel.add_child(menu_right_arrow)

	# PLAY button — hidden, replaced by chapter buttons
	menu_play_button = Button.new()
	menu_play_button.text = "  PLAY  "
	menu_play_button.position = Vector2(250, 250)
	menu_play_button.custom_minimum_size = Vector2(200, 60)
	menu_play_button.pressed.connect(_on_menu_play)
	menu_play_button.visible = false
	menu_showcase_panel.add_child(menu_play_button)

	# --- RIGHT PAGE: 3 Chapter cards ---
	for i in range(3):
		var card_y = 30 + i * 165
		var card_x = 585

		# Chapter title
		var ch_title = Label.new()
		ch_title.position = Vector2(card_x, card_y)
		ch_title.size = Vector2(540, 25)
		ch_title.add_theme_font_size_override("font_size", 18)
		ch_title.add_theme_color_override("font_color", Color(0.55, 0.35, 0.1))
		menu_showcase_panel.add_child(ch_title)
		chapter_title_labels.append(ch_title)

		# Chapter description
		var ch_desc = Label.new()
		ch_desc.position = Vector2(card_x, card_y + 28)
		ch_desc.size = Vector2(420, 50)
		ch_desc.add_theme_font_size_override("font_size", 12)
		ch_desc.add_theme_color_override("font_color", Color(0.4, 0.35, 0.28))
		ch_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		menu_showcase_panel.add_child(ch_desc)
		chapter_desc_labels.append(ch_desc)

		# Chapter stats (waves/gold/lives)
		var ch_stat = Label.new()
		ch_stat.position = Vector2(card_x, card_y + 82)
		ch_stat.size = Vector2(300, 20)
		ch_stat.add_theme_font_size_override("font_size", 11)
		ch_stat.add_theme_color_override("font_color", Color(0.4, 0.55, 0.35))
		menu_showcase_panel.add_child(ch_stat)
		chapter_stat_labels.append(ch_stat)

		# Chapter stars
		var ch_stars = Label.new()
		ch_stars.position = Vector2(card_x, card_y + 104)
		ch_stars.size = Vector2(200, 22)
		ch_stars.add_theme_font_size_override("font_size", 18)
		ch_stars.add_theme_color_override("font_color", Color(0.85, 0.65, 0.1))
		menu_showcase_panel.add_child(ch_stars)
		chapter_star_labels.append(ch_stars)

		# Difficulty / lock label
		var ch_lock = Label.new()
		ch_lock.position = Vector2(card_x + 220, card_y + 104)
		ch_lock.size = Vector2(120, 22)
		ch_lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		ch_lock.add_theme_font_size_override("font_size", 12)
		menu_showcase_panel.add_child(ch_lock)
		chapter_lock_labels.append(ch_lock)

		# Play button for this chapter
		var ch_btn = Button.new()
		ch_btn.text = "  PLAY  "
		ch_btn.position = Vector2(card_x + 370, card_y + 80)
		ch_btn.custom_minimum_size = Vector2(140, 44)
		ch_btn.pressed.connect(_on_chapter_play.bind(i))
		menu_showcase_panel.add_child(ch_btn)
		chapter_buttons.append(ch_btn)

	# === BOTTOM NAV BAR (bookmark ribbon style) ===
	var nav_bar = ColorRect.new()
	nav_bar.color = Color(0.12, 0.08, 0.04, 0.95)
	nav_bar.position = Vector2(0, 620)
	nav_bar.size = Vector2(1280, 100)
	menu_overlay.add_child(nav_bar)

	# Nav bar top border (gold ribbon)
	var nav_border = ColorRect.new()
	nav_border.color = Color(0.65, 0.45, 0.1, 0.5)
	nav_border.position = Vector2(0, 0)
	nav_border.size = Vector2(1280, 3)
	nav_bar.add_child(nav_border)

	var nav_names = ["HEROES", "RELICS", "CHAPTERS", "CHRONICLES", "EMPORIUM"]
	var nav_icons = ["♟", "◆", "📖", "📜", "🏪"]
	for i in range(5):
		var btn_x = 64 + i * 240
		var nav_btn = Button.new()
		nav_btn.text = nav_icons[i]
		nav_btn.position = Vector2(btn_x, 10)
		nav_btn.custom_minimum_size = Vector2(70, 50)
		nav_btn.pressed.connect(_on_nav_pressed.bind(nav_names[i].to_lower()))
		nav_bar.add_child(nav_btn)
		menu_nav_buttons.append(nav_btn)

		var nav_lbl = Label.new()
		nav_lbl.text = nav_names[i]
		nav_lbl.position = Vector2(btn_x - 15, 64)
		nav_lbl.size = Vector2(100, 20)
		nav_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nav_lbl.add_theme_font_size_override("font_size", 11)
		nav_lbl.add_theme_color_override("font_color", Color(0.7, 0.6, 0.45))
		nav_bar.add_child(nav_lbl)
		menu_nav_labels.append(nav_lbl)

	# Return to menu button (hidden during gameplay, shown on victory/game over)
	return_button = Button.new()
	return_button.text = "  Return to Menu  "
	return_button.position = Vector2(500, 380)
	return_button.custom_minimum_size = Vector2(280, 50)
	return_button.pressed.connect(_show_menu)
	return_button.visible = false
	ui.add_child(return_button)

func _make_button(text: String, pos: Vector2, min_size: Vector2) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.position = pos
	btn.custom_minimum_size = min_size
	return btn

# ============================================================
# MENU & LEVEL MANAGEMENT
# ============================================================

func _show_menu() -> void:
	game_state = GameState.MENU
	get_tree().paused = false
	Engine.time_scale = 1.0
	fast_forward = false
	if speed_button:
		speed_button.text = "  >>  "
	menu_overlay.visible = true
	return_button.visible = false
	game_over_label.visible = false
	if top_bar:
		top_bar.visible = false
	if bottom_panel:
		bottom_panel.visible = false
	if upgrade_panel:
		upgrade_panel.visible = false
	placing_tower = false
	_deselect_tower()
	_remove_hero_preview()
	menu_current_view = "chapters"
	menu_play_button.visible = false
	menu_left_arrow.visible = true
	menu_right_arrow.visible = true
	_update_menu_showcase()
	_start_beat()
	queue_redraw()

func _update_menu_showcase() -> void:
	var char_idx = menu_character_index
	# Left page: character info
	menu_level_name_label.text = character_names[char_idx]
	menu_level_desc_label.text = character_novels[char_idx]
	menu_level_stats_label.text = "\"%s\"" % character_quotes[char_idx]
	menu_level_stars_label.text = ""

	# Right page: 3 chapter cards
	for i in range(3):
		var level_idx = char_idx * 3 + i
		var level = levels[level_idx]
		var chap_num = ["I", "II", "III"]
		var diff_names = ["Easy", "Medium", "Hard"]
		var diff_colors = [Color(0.3, 0.8, 0.3), Color(0.8, 0.8, 0.2), Color(1.0, 0.4, 0.2)]

		chapter_title_labels[i].text = "Chapter %s — %s" % [chap_num[i], level["name"]]
		chapter_desc_labels[i].text = level["description"]
		chapter_stat_labels[i].text = "Waves: %d  |  Gold: %d  |  Lives: %d" % [level["waves"], level["gold"], level["lives"]]

		# Stars
		if level_idx in completed_levels and level_stars.has(level_idx):
			var sv = level_stars[level_idx]
			var ss = ""
			for s in range(sv):
				ss += "★"
			for s in range(3 - sv):
				ss += "☆"
			chapter_star_labels[i].text = ss
		else:
			chapter_star_labels[i].text = "☆☆☆"

		# Lock / difficulty
		var unlocked = _is_level_unlocked(level_idx)
		chapter_buttons[i].disabled = not unlocked
		chapter_buttons[i].text = "  PLAY  " if unlocked else "  LOCKED  "
		chapter_lock_labels[i].text = diff_names[i]
		chapter_lock_labels[i].add_theme_color_override("font_color", diff_colors[i] if unlocked else Color(0.4, 0.35, 0.3))

		# Visibility
		chapter_title_labels[i].visible = true
		chapter_desc_labels[i].visible = true
		chapter_stat_labels[i].visible = true
		chapter_star_labels[i].visible = true
		chapter_lock_labels[i].visible = true
		chapter_buttons[i].visible = true

	# Arrow state
	menu_left_arrow.disabled = char_idx <= 0
	menu_right_arrow.disabled = char_idx >= 5

	# Update star total
	var total_stars = 0
	for key in level_stars:
		total_stars += level_stars[key]
	menu_star_total_label.text = "★ %d / %d" % [total_stars, levels.size() * 3]

func _on_chapter_play(chapter: int) -> void:
	var level_idx = menu_character_index * 3 + chapter
	_on_level_selected(level_idx)

func _on_menu_left() -> void:
	if menu_current_view == "heroes":
		if hero_preview_index > 0:
			hero_preview_index -= 1
			_show_hero_preview(hero_preview_index)
	else:
		if menu_character_index > 0:
			menu_character_index -= 1
			_update_menu_showcase()

func _on_menu_right() -> void:
	if menu_current_view == "heroes":
		if hero_preview_index < hero_types.size() - 1:
			hero_preview_index += 1
			_show_hero_preview(hero_preview_index)
	else:
		if menu_character_index < 5:
			menu_character_index += 1
			_update_menu_showcase()

func _on_menu_play() -> void:
	pass  # Unused — chapter buttons handle play now

func _on_nav_pressed(nav_name: String) -> void:
	if menu_current_view == "heroes" and nav_name != "heroes":
		_remove_hero_preview()
	menu_current_view = nav_name
	if nav_name == "chapters":
		menu_showcase_panel.visible = true
		menu_play_button.visible = false
		menu_left_arrow.visible = true
		menu_right_arrow.visible = true
		# Show chapter UI
		for i in range(3):
			chapter_title_labels[i].visible = true
			chapter_desc_labels[i].visible = true
			chapter_stat_labels[i].visible = true
			chapter_star_labels[i].visible = true
			chapter_lock_labels[i].visible = true
			chapter_buttons[i].visible = true
		_update_menu_showcase()
	elif nav_name == "heroes":
		menu_showcase_panel.visible = true
		menu_play_button.visible = false
		menu_left_arrow.visible = true
		menu_right_arrow.visible = true
		# Hide chapter UI
		for i in range(3):
			chapter_title_labels[i].visible = false
			chapter_desc_labels[i].visible = false
			chapter_stat_labels[i].visible = false
			chapter_star_labels[i].visible = false
			chapter_lock_labels[i].visible = false
			chapter_buttons[i].visible = false
		_show_hero_preview(hero_preview_index)
	else:
		menu_showcase_panel.visible = true
		menu_level_name_label.text = nav_name.to_upper()
		menu_level_desc_label.text = "Coming Soon!"
		menu_level_stats_label.text = "This feature is being written into the pages..."
		menu_level_stars_label.text = ""
		menu_play_button.visible = false
		menu_left_arrow.visible = false
		menu_right_arrow.visible = false
		for i in range(3):
			chapter_title_labels[i].visible = false
			chapter_desc_labels[i].visible = false
			chapter_stat_labels[i].visible = false
			chapter_star_labels[i].visible = false
			chapter_lock_labels[i].visible = false
			chapter_buttons[i].visible = false

func _show_hero_preview(index: int) -> void:
	hero_preview_index = index
	_remove_hero_preview()
	var tower_type = hero_types[index]
	var info = tower_info[tower_type]

	hero_preview_node = tower_scenes[tower_type].instantiate()
	hero_preview_node.position = Vector2(350, 400)
	hero_preview_node.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(hero_preview_node)

	menu_level_name_label.text = info["name"]
	menu_level_desc_label.text = hero_descriptions.get(tower_type, "A legendary hero.")
	var cost = info["cost"]
	var rng_val = info["range"]
	menu_level_stats_label.text = "Cost: %d gold  |  Range: %d" % [cost, int(rng_val)]
	menu_level_stars_label.text = ""

	var tier_names = hero_preview_node.TIER_NAMES if hero_preview_node.get("TIER_NAMES") else []
	var tier_costs = hero_preview_node.TIER_COSTS if hero_preview_node.get("TIER_COSTS") else []
	var upgrade_text = ""
	for i in range(mini(tier_names.size(), tier_costs.size())):
		if i > 0:
			upgrade_text += "  |  "
		upgrade_text += "T%d: %s ($%d)" % [i + 1, tier_names[i], tier_costs[i]]

	menu_left_arrow.disabled = index <= 0
	menu_right_arrow.disabled = index >= hero_types.size() - 1

func _remove_hero_preview() -> void:
	if hero_preview_node and is_instance_valid(hero_preview_node):
		hero_preview_node.queue_free()
		hero_preview_node = null

func _is_level_unlocked(idx: int) -> bool:
	if idx == 0:
		return true
	var char_idx = levels[idx]["character"]
	var chap_idx = levels[idx]["chapter"]
	if chap_idx > 0:
		return (idx - 1) in completed_levels
	else:
		var prev_char_ch1 = (char_idx - 1) * 3
		return prev_char_ch1 in completed_levels

func _on_level_selected(index: int) -> void:
	if not _is_level_unlocked(index):
		return
	_remove_hero_preview()
	current_level = index
	_reset_game()
	var level = levels[index]
	gold = level["gold"]
	lives = level["lives"]
	total_waves = level["waves"]
	_setup_path_for_level(index)
	_generate_decorations_for_level(index)
	_stop_beat()
	menu_overlay.visible = false
	top_bar.visible = true
	bottom_panel.visible = true
	game_over_label.visible = false
	return_button.visible = false
	game_state = GameState.PLAYING
	start_button.text = "  Start Wave  "
	tower_buttons[TowerType.ROBIN_HOOD].text = "Robin [75G]"
	tower_buttons[TowerType.ROBIN_HOOD].disabled = false
	tower_buttons[TowerType.ALICE].text = "Alice [85G]"
	tower_buttons[TowerType.ALICE].disabled = false
	tower_buttons[TowerType.WICKED_WITCH].text = "Witch [100G]"
	tower_buttons[TowerType.WICKED_WITCH].disabled = false
	tower_buttons[TowerType.PETER_PAN].text = "Peter [90G]"
	tower_buttons[TowerType.PETER_PAN].disabled = false
	tower_buttons[TowerType.PHANTOM].text = "Phantom [95G]"
	tower_buttons[TowerType.PHANTOM].disabled = false
	tower_buttons[TowerType.SCROOGE].text = "Scrooge [60G]"
	tower_buttons[TowerType.SCROOGE].disabled = false
	start_button.disabled = false
	update_hud()
	info_label.text = level["name"] + " — Place your towers!"
	wave_auto_timer = -1.0

func _reset_game() -> void:
	for tower in get_tree().get_nodes_in_group("towers"):
		tower.queue_free()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	wave = 0
	is_wave_active = false
	placing_tower = false
	enemies_to_spawn = 0
	enemies_alive = 0
	spawn_timer = 0.0
	purchased_towers.clear()
	placed_tower_positions.clear()
	selected_tower_node = null
	wave_auto_timer = -1.0
	_hide_upgrade_panel()

func _setup_path_for_level(index: int) -> void:
	var curve = enemy_path.curve
	if not curve:
		return
	curve.clear_points()
	match index:
		0: # Robin Hood Ch1 — gentle S-curves through forest clearings
			curve.add_point(Vector2(-50, 300), Vector2.ZERO, Vector2(100, 0))
			curve.add_point(Vector2(200, 300), Vector2(-60, 0), Vector2(60, -100))
			curve.add_point(Vector2(320, 150), Vector2(0, 60), Vector2(100, 0))
			curve.add_point(Vector2(580, 200), Vector2(-80, 0), Vector2(80, 80))
			curve.add_point(Vector2(640, 420), Vector2(0, -80), Vector2(80, 0))
			curve.add_point(Vector2(880, 380), Vector2(-80, 0), Vector2(60, -80))
			curve.add_point(Vector2(960, 180), Vector2(0, 60), Vector2(100, 0))
			curve.add_point(Vector2(1330, 250))
		1: # Robin Hood Ch2 — deeper forest, river crossing
			curve.add_point(Vector2(-50, 200), Vector2.ZERO, Vector2(80, 0))
			curve.add_point(Vector2(140, 200), Vector2(-40, 0), Vector2(40, 60))
			curve.add_point(Vector2(200, 380), Vector2(0, -60), Vector2(60, 0))
			curve.add_point(Vector2(360, 380), Vector2(-40, 0), Vector2(40, -80))
			curve.add_point(Vector2(420, 160), Vector2(0, 60), Vector2(60, 0))
			curve.add_point(Vector2(560, 160), Vector2(-40, 0), Vector2(0, 80))
			curve.add_point(Vector2(560, 440), Vector2(0, -80), Vector2(60, 0))
			curve.add_point(Vector2(720, 440), Vector2(-60, 0), Vector2(60, -60))
			curve.add_point(Vector2(820, 260), Vector2(0, 60), Vector2(60, 0))
			curve.add_point(Vector2(960, 260), Vector2(-40, 0), Vector2(40, 80))
			curve.add_point(Vector2(1040, 480), Vector2(0, -60), Vector2(80, 0))
			curve.add_point(Vector2(1200, 480), Vector2(-60, 0), Vector2(60, -40))
			curve.add_point(Vector2(1330, 360))
		2: # Robin Hood Ch3 — castle siege approach
			curve.add_point(Vector2(-50, 500), Vector2.ZERO, Vector2(60, 0))
			curve.add_point(Vector2(100, 500), Vector2(-40, 0), Vector2(40, -60))
			curve.add_point(Vector2(140, 340), Vector2(0, 40), Vector2(60, 0))
			curve.add_point(Vector2(280, 340), Vector2(-40, 0), Vector2(0, -80))
			curve.add_point(Vector2(280, 140), Vector2(0, 60), Vector2(60, 0))
			curve.add_point(Vector2(420, 140), Vector2(-40, 0), Vector2(0, 80))
			curve.add_point(Vector2(420, 400), Vector2(0, -60), Vector2(40, 0))
			curve.add_point(Vector2(520, 400), Vector2(-30, 0), Vector2(30, 60))
			curve.add_point(Vector2(560, 560), Vector2(0, -40), Vector2(60, 0))
			curve.add_point(Vector2(700, 560), Vector2(-60, 0), Vector2(0, -80))
			curve.add_point(Vector2(700, 300), Vector2(0, 60), Vector2(0, -60))
			curve.add_point(Vector2(700, 120), Vector2(0, 40), Vector2(60, 0))
			curve.add_point(Vector2(840, 120), Vector2(-40, 0), Vector2(0, 60))
			curve.add_point(Vector2(840, 320), Vector2(0, -40), Vector2(60, 0))
			curve.add_point(Vector2(960, 320), Vector2(-40, 0), Vector2(0, 60))
			curve.add_point(Vector2(960, 520), Vector2(0, -40), Vector2(60, 0))
			curve.add_point(Vector2(1100, 520), Vector2(-40, 0), Vector2(0, -80))
			curve.add_point(Vector2(1100, 260), Vector2(0, 60), Vector2(80, 0))
			curve.add_point(Vector2(1330, 200))
		3: # Alice Ch1 — zigzag down like falling
			curve.add_point(Vector2(100, -50), Vector2.ZERO, Vector2(0, 80))
			curve.add_point(Vector2(200, 140), Vector2(-40, -40), Vector2(120, 0))
			curve.add_point(Vector2(500, 120), Vector2(-80, 0), Vector2(0, 100))
			curve.add_point(Vector2(400, 340), Vector2(40, -60), Vector2(-100, 0))
			curve.add_point(Vector2(160, 380), Vector2(80, 0), Vector2(0, 80))
			curve.add_point(Vector2(300, 520), Vector2(-60, 0), Vector2(120, 0))
			curve.add_point(Vector2(700, 480), Vector2(-100, 0), Vector2(100, 0))
			curve.add_point(Vector2(1000, 540), Vector2(-80, 0), Vector2(80, 0))
			curve.add_point(Vector2(1330, 580))
		4: # Alice Ch2 — mad tea party grounds, chess board
			curve.add_point(Vector2(640, -50), Vector2.ZERO, Vector2(0, 60))
			curve.add_point(Vector2(640, 120), Vector2(0, -40), Vector2(80, 0))
			curve.add_point(Vector2(900, 120), Vector2(-60, 0), Vector2(0, 80))
			curve.add_point(Vector2(900, 320), Vector2(0, -60), Vector2(-80, 0))
			curve.add_point(Vector2(640, 320), Vector2(60, 0), Vector2(-80, 0))
			curve.add_point(Vector2(380, 320), Vector2(60, 0), Vector2(0, -60))
			curve.add_point(Vector2(380, 140), Vector2(0, 60), Vector2(-80, 0))
			curve.add_point(Vector2(140, 140), Vector2(60, 0), Vector2(0, 80))
			curve.add_point(Vector2(140, 440), Vector2(0, -80), Vector2(80, 0))
			curve.add_point(Vector2(400, 440), Vector2(-60, 0), Vector2(60, 60))
			curve.add_point(Vector2(500, 580), Vector2(-40, 0), Vector2(80, 0))
			curve.add_point(Vector2(800, 540), Vector2(-80, 0), Vector2(80, 0))
			curve.add_point(Vector2(1100, 580), Vector2(-80, 0), Vector2(80, 0))
			curve.add_point(Vector2(1330, 540))
		5: # Alice Ch3 — queen's palace approach
			curve.add_point(Vector2(-50, 100), Vector2.ZERO, Vector2(60, 0))
			curve.add_point(Vector2(120, 100), Vector2(-40, 0), Vector2(0, 60))
			curve.add_point(Vector2(120, 260), Vector2(0, -40), Vector2(60, 0))
			curve.add_point(Vector2(280, 260), Vector2(-40, 0), Vector2(0, -60))
			curve.add_point(Vector2(280, 100), Vector2(0, 40), Vector2(60, 0))
			curve.add_point(Vector2(440, 100), Vector2(-40, 0), Vector2(0, 80))
			curve.add_point(Vector2(440, 360), Vector2(0, -60), Vector2(-60, 0))
			curve.add_point(Vector2(280, 360), Vector2(40, 0), Vector2(0, 60))
			curve.add_point(Vector2(280, 520), Vector2(0, -40), Vector2(60, 0))
			curve.add_point(Vector2(480, 520), Vector2(-60, 0), Vector2(60, 0))
			curve.add_point(Vector2(640, 520), Vector2(-40, 0), Vector2(0, -80))
			curve.add_point(Vector2(640, 280), Vector2(0, 60), Vector2(60, 0))
			curve.add_point(Vector2(800, 280), Vector2(-40, 0), Vector2(0, 80))
			curve.add_point(Vector2(800, 520), Vector2(0, -60), Vector2(60, 0))
			curve.add_point(Vector2(960, 520), Vector2(-40, 0), Vector2(0, -80))
			curve.add_point(Vector2(960, 180), Vector2(0, 60), Vector2(60, 0))
			curve.add_point(Vector2(1120, 180), Vector2(-40, 0), Vector2(0, 60))
			curve.add_point(Vector2(1120, 400), Vector2(0, -40), Vector2(60, 0))
			curve.add_point(Vector2(1330, 400))
		6: # Oz Ch1 — yellow brick road with angular turns
			curve.add_point(Vector2(-50, 400), Vector2.ZERO, Vector2(60, 0))
			curve.add_point(Vector2(150, 400), Vector2(-40, 0), Vector2(0, -80))
			curve.add_point(Vector2(150, 200), Vector2(0, 60), Vector2(80, 0))
			curve.add_point(Vector2(400, 200), Vector2(-60, 0), Vector2(0, 80))
			curve.add_point(Vector2(400, 480), Vector2(0, -60), Vector2(80, 0))
			curve.add_point(Vector2(700, 480), Vector2(-60, 0), Vector2(0, -80))
			curve.add_point(Vector2(700, 200), Vector2(0, 60), Vector2(80, 0))
			curve.add_point(Vector2(950, 200), Vector2(-60, 0), Vector2(60, 60))
			curve.add_point(Vector2(1050, 350), Vector2(0, -40), Vector2(80, 0))
			curve.add_point(Vector2(1330, 350))
		7: # Oz Ch2 — dark witch territory
			curve.add_point(Vector2(-50, 300), Vector2.ZERO, Vector2(60, 0))
			curve.add_point(Vector2(120, 300), Vector2(-40, 0), Vector2(0, -60))
			curve.add_point(Vector2(120, 140), Vector2(0, 40), Vector2(80, 0))
			curve.add_point(Vector2(320, 140), Vector2(-60, 0), Vector2(0, 80))
			curve.add_point(Vector2(320, 380), Vector2(0, -60), Vector2(0, 60))
			curve.add_point(Vector2(320, 560), Vector2(0, -40), Vector2(60, 0))
			curve.add_point(Vector2(520, 560), Vector2(-40, 0), Vector2(0, -80))
			curve.add_point(Vector2(520, 300), Vector2(0, 60), Vector2(0, -60))
			curve.add_point(Vector2(520, 140), Vector2(0, 40), Vector2(60, 0))
			curve.add_point(Vector2(720, 140), Vector2(-60, 0), Vector2(0, 80))
			curve.add_point(Vector2(720, 400), Vector2(0, -60), Vector2(80, 0))
			curve.add_point(Vector2(920, 400), Vector2(-60, 0), Vector2(0, -80))
			curve.add_point(Vector2(920, 180), Vector2(0, 60), Vector2(80, 0))
			curve.add_point(Vector2(1150, 180), Vector2(-60, 0), Vector2(60, 60))
			curve.add_point(Vector2(1330, 350))
		8: # Oz Ch3 — inside emerald city
			curve.add_point(Vector2(640, -50), Vector2.ZERO, Vector2(0, 60))
			curve.add_point(Vector2(640, 100), Vector2(0, -40), Vector2(-60, 0))
			curve.add_point(Vector2(460, 100), Vector2(40, 0), Vector2(0, 60))
			curve.add_point(Vector2(460, 240), Vector2(0, -40), Vector2(60, 0))
			curve.add_point(Vector2(820, 240), Vector2(-60, 0), Vector2(0, 60))
			curve.add_point(Vector2(820, 380), Vector2(0, -40), Vector2(-60, 0))
			curve.add_point(Vector2(640, 380), Vector2(40, 0), Vector2(-60, 0))
			curve.add_point(Vector2(460, 380), Vector2(40, 0), Vector2(0, 60))
			curve.add_point(Vector2(460, 520), Vector2(0, -40), Vector2(-80, 0))
			curve.add_point(Vector2(200, 520), Vector2(60, 0), Vector2(0, -60))
			curve.add_point(Vector2(200, 340), Vector2(0, 40), Vector2(-60, 0))
			curve.add_point(Vector2(80, 340), Vector2(40, 0), Vector2(0, 60))
			curve.add_point(Vector2(80, 560), Vector2(0, -40), Vector2(60, 0))
			curve.add_point(Vector2(300, 560), Vector2(-40, 0), Vector2(60, 0))
			curve.add_point(Vector2(640, 580), Vector2(-60, 0), Vector2(60, 0))
			curve.add_point(Vector2(1000, 560), Vector2(-80, 0), Vector2(60, 0))
			curve.add_point(Vector2(1180, 560), Vector2(-40, 0), Vector2(0, -60))
			curve.add_point(Vector2(1180, 380), Vector2(0, 40), Vector2(60, 0))
			curve.add_point(Vector2(1330, 380))
		9: # Peter Pan Ch1 — Neverland
			curve.add_point(Vector2(-50, 360), Vector2.ZERO, Vector2(80, 0))
			curve.add_point(Vector2(160, 360), Vector2(-40, 0), Vector2(40, -80))
			curve.add_point(Vector2(160, 140), Vector2(0, 80), Vector2(100, 0))
			curve.add_point(Vector2(480, 140), Vector2(-100, 0), Vector2(0, 100))
			curve.add_point(Vector2(480, 520), Vector2(0, -100), Vector2(100, 0))
			curve.add_point(Vector2(800, 520), Vector2(-100, 0), Vector2(0, -100))
			curve.add_point(Vector2(800, 200), Vector2(0, 100), Vector2(100, 0))
			curve.add_point(Vector2(1330, 200))
		10: # Peter Pan Ch2 — dense jungle, lost boys hideout
			curve.add_point(Vector2(-50, 500), Vector2.ZERO, Vector2(80, 0))
			curve.add_point(Vector2(140, 500), Vector2(-40, 0), Vector2(0, -60))
			curve.add_point(Vector2(140, 340), Vector2(0, 40), Vector2(60, 0))
			curve.add_point(Vector2(300, 340), Vector2(-40, 0), Vector2(0, -80))
			curve.add_point(Vector2(300, 140), Vector2(0, 60), Vector2(80, 0))
			curve.add_point(Vector2(520, 140), Vector2(-60, 0), Vector2(0, 80))
			curve.add_point(Vector2(520, 400), Vector2(0, -60), Vector2(-60, 0))
			curve.add_point(Vector2(340, 400), Vector2(40, 0), Vector2(0, 60))
			curve.add_point(Vector2(340, 560), Vector2(0, -40), Vector2(80, 0))
			curve.add_point(Vector2(660, 560), Vector2(-80, 0), Vector2(0, -60))
			curve.add_point(Vector2(660, 340), Vector2(0, 40), Vector2(60, 0))
			curve.add_point(Vector2(860, 340), Vector2(-60, 0), Vector2(0, -80))
			curve.add_point(Vector2(860, 140), Vector2(0, 60), Vector2(80, 0))
			curve.add_point(Vector2(1100, 140), Vector2(-60, 0), Vector2(60, 60))
			curve.add_point(Vector2(1200, 340), Vector2(0, -40), Vector2(60, 0))
			curve.add_point(Vector2(1330, 340))
		11: # Peter Pan Ch3 — pirate ship approach
			curve.add_point(Vector2(1330, 100), Vector2.ZERO, Vector2(-80, 0))
			curve.add_point(Vector2(1100, 100), Vector2(60, 0), Vector2(0, 60))
			curve.add_point(Vector2(1100, 260), Vector2(0, -40), Vector2(-60, 0))
			curve.add_point(Vector2(900, 260), Vector2(40, 0), Vector2(0, -60))
			curve.add_point(Vector2(900, 100), Vector2(0, 40), Vector2(-60, 0))
			curve.add_point(Vector2(700, 100), Vector2(40, 0), Vector2(0, 80))
			curve.add_point(Vector2(700, 360), Vector2(0, -60), Vector2(60, 0))
			curve.add_point(Vector2(900, 360), Vector2(-40, 0), Vector2(0, 60))
			curve.add_point(Vector2(900, 520), Vector2(0, -40), Vector2(-80, 0))
			curve.add_point(Vector2(600, 520), Vector2(60, 0), Vector2(-60, 0))
			curve.add_point(Vector2(400, 520), Vector2(40, 0), Vector2(0, -60))
			curve.add_point(Vector2(400, 340), Vector2(0, 40), Vector2(-60, 0))
			curve.add_point(Vector2(200, 340), Vector2(40, 0), Vector2(0, -80))
			curve.add_point(Vector2(200, 140), Vector2(0, 60), Vector2(-60, 0))
			curve.add_point(Vector2(80, 140), Vector2(40, 0), Vector2(0, 80))
			curve.add_point(Vector2(80, 420), Vector2(0, -60), Vector2(0, 60))
			curve.add_point(Vector2(80, 580), Vector2(0, -40), Vector2(60, 0))
			curve.add_point(Vector2(300, 580), Vector2(-60, 0), Vector2(60, 0))
			curve.add_point(Vector2(640, 600), Vector2(-80, 0), Vector2(80, 0))
			curve.add_point(Vector2(1330, 580))
		12: # Phantom Ch1 — descend in tight switchbacks
			curve.add_point(Vector2(640, -50), Vector2.ZERO, Vector2(0, 80))
			curve.add_point(Vector2(640, 160), Vector2(0, -40), Vector2(-120, 0))
			curve.add_point(Vector2(160, 160), Vector2(80, 0), Vector2(0, 80))
			curve.add_point(Vector2(160, 400), Vector2(0, -80), Vector2(120, 0))
			curve.add_point(Vector2(1100, 400), Vector2(-120, 0), Vector2(0, 60))
			curve.add_point(Vector2(1100, 560), Vector2(0, -40), Vector2(-120, 0))
			curve.add_point(Vector2(640, 670))
		13: # Phantom Ch2 — underground labyrinth
			curve.add_point(Vector2(-50, 160), Vector2.ZERO, Vector2(60, 0))
			curve.add_point(Vector2(140, 160), Vector2(-40, 0), Vector2(0, 60))
			curve.add_point(Vector2(140, 340), Vector2(0, -40), Vector2(60, 0))
			curve.add_point(Vector2(340, 340), Vector2(-40, 0), Vector2(0, -80))
			curve.add_point(Vector2(340, 140), Vector2(0, 60), Vector2(60, 0))
			curve.add_point(Vector2(560, 140), Vector2(-40, 0), Vector2(0, 80))
			curve.add_point(Vector2(560, 420), Vector2(0, -60), Vector2(60, 0))
			curve.add_point(Vector2(760, 420), Vector2(-60, 0), Vector2(0, -80))
			curve.add_point(Vector2(760, 200), Vector2(0, 60), Vector2(60, 0))
			curve.add_point(Vector2(960, 200), Vector2(-40, 0), Vector2(0, 80))
			curve.add_point(Vector2(960, 500), Vector2(0, -60), Vector2(-80, 0))
			curve.add_point(Vector2(700, 500), Vector2(60, 0), Vector2(0, 40))
			curve.add_point(Vector2(700, 580), Vector2(0, -30), Vector2(80, 0))
			curve.add_point(Vector2(1000, 580), Vector2(-60, 0), Vector2(80, 0))
			curve.add_point(Vector2(1330, 560))
		14: # Phantom Ch3 — deep underground lair
			curve.add_point(Vector2(1330, 100), Vector2.ZERO, Vector2(-80, 0))
			curve.add_point(Vector2(1100, 100), Vector2(60, 0), Vector2(-60, 0))
			curve.add_point(Vector2(880, 100), Vector2(40, 0), Vector2(0, 60))
			curve.add_point(Vector2(880, 240), Vector2(0, -40), Vector2(60, 0))
			curve.add_point(Vector2(1080, 240), Vector2(-40, 0), Vector2(0, 60))
			curve.add_point(Vector2(1080, 400), Vector2(0, -40), Vector2(-60, 0))
			curve.add_point(Vector2(880, 400), Vector2(40, 0), Vector2(-60, 0))
			curve.add_point(Vector2(680, 400), Vector2(40, 0), Vector2(0, -80))
			curve.add_point(Vector2(680, 200), Vector2(0, 60), Vector2(-60, 0))
			curve.add_point(Vector2(480, 200), Vector2(40, 0), Vector2(0, 60))
			curve.add_point(Vector2(480, 400), Vector2(0, -40), Vector2(-60, 0))
			curve.add_point(Vector2(280, 400), Vector2(40, 0), Vector2(0, -60))
			curve.add_point(Vector2(280, 200), Vector2(0, 40), Vector2(-60, 0))
			curve.add_point(Vector2(100, 200), Vector2(40, 0), Vector2(0, 80))
			curve.add_point(Vector2(100, 460), Vector2(0, -60), Vector2(60, 0))
			curve.add_point(Vector2(360, 460), Vector2(-40, 0), Vector2(0, 40))
			curve.add_point(Vector2(360, 580), Vector2(0, -30), Vector2(60, 0))
			curve.add_point(Vector2(640, 580), Vector2(-80, 0), Vector2(0, -40))
			curve.add_point(Vector2(640, 670))
		15: # Scrooge Ch1 — wind through city blocks
			curve.add_point(Vector2(1330, 180), Vector2.ZERO, Vector2(-80, 0))
			curve.add_point(Vector2(1050, 180), Vector2(60, 0), Vector2(0, 80))
			curve.add_point(Vector2(1050, 400), Vector2(0, -60), Vector2(-80, 0))
			curve.add_point(Vector2(750, 400), Vector2(60, 0), Vector2(0, -80))
			curve.add_point(Vector2(750, 200), Vector2(0, 60), Vector2(-80, 0))
			curve.add_point(Vector2(450, 200), Vector2(60, 0), Vector2(0, 80))
			curve.add_point(Vector2(450, 480), Vector2(0, -60), Vector2(-80, 0))
			curve.add_point(Vector2(200, 480), Vector2(60, 0), Vector2(0, -60))
			curve.add_point(Vector2(200, 300), Vector2(0, 40), Vector2(-80, 0))
			curve.add_point(Vector2(-50, 300))
		16: # Scrooge Ch2 — midnight graveyard
			curve.add_point(Vector2(-50, 140), Vector2.ZERO, Vector2(60, 0))
			curve.add_point(Vector2(120, 140), Vector2(-40, 0), Vector2(0, 80))
			curve.add_point(Vector2(120, 380), Vector2(0, -60), Vector2(60, 0))
			curve.add_point(Vector2(300, 380), Vector2(-40, 0), Vector2(0, -80))
			curve.add_point(Vector2(300, 160), Vector2(0, 60), Vector2(60, 0))
			curve.add_point(Vector2(500, 160), Vector2(-40, 0), Vector2(0, 80))
			curve.add_point(Vector2(500, 500), Vector2(0, -80), Vector2(60, 0))
			curve.add_point(Vector2(700, 500), Vector2(-60, 0), Vector2(0, -80))
			curve.add_point(Vector2(700, 240), Vector2(0, 60), Vector2(60, 0))
			curve.add_point(Vector2(900, 240), Vector2(-40, 0), Vector2(0, 80))
			curve.add_point(Vector2(900, 520), Vector2(0, -60), Vector2(60, 0))
			curve.add_point(Vector2(1100, 520), Vector2(-40, 0), Vector2(0, -80))
			curve.add_point(Vector2(1100, 300), Vector2(0, 40), Vector2(80, 0))
			curve.add_point(Vector2(1330, 300))
		17: # Scrooge Ch3 — christmas morning streets
			curve.add_point(Vector2(640, -50), Vector2.ZERO, Vector2(0, 60))
			curve.add_point(Vector2(640, 100), Vector2(0, -40), Vector2(80, 0))
			curve.add_point(Vector2(880, 100), Vector2(-40, 0), Vector2(0, 60))
			curve.add_point(Vector2(880, 260), Vector2(0, -40), Vector2(-60, 0))
			curve.add_point(Vector2(700, 260), Vector2(40, 0), Vector2(0, 60))
			curve.add_point(Vector2(700, 420), Vector2(0, -40), Vector2(60, 0))
			curve.add_point(Vector2(1060, 420), Vector2(-60, 0), Vector2(0, -60))
			curve.add_point(Vector2(1060, 240), Vector2(0, 40), Vector2(60, 0))
			curve.add_point(Vector2(1200, 240), Vector2(-40, 0), Vector2(0, 80))
			curve.add_point(Vector2(1200, 500), Vector2(0, -60), Vector2(-80, 0))
			curve.add_point(Vector2(880, 500), Vector2(60, 0), Vector2(0, 40))
			curve.add_point(Vector2(880, 580), Vector2(0, -30), Vector2(-80, 0))
			curve.add_point(Vector2(540, 580), Vector2(60, 0), Vector2(-60, 0))
			curve.add_point(Vector2(340, 580), Vector2(40, 0), Vector2(0, -60))
			curve.add_point(Vector2(340, 400), Vector2(0, 40), Vector2(-60, 0))
			curve.add_point(Vector2(140, 400), Vector2(40, 0), Vector2(0, -80))
			curve.add_point(Vector2(140, 200), Vector2(0, 60), Vector2(-60, 0))
			curve.add_point(Vector2(-50, 200))
	path_points.clear()
	var length = curve.get_baked_length()
	for i in range(0, int(length), 6):
		path_points.append(curve.sample_baked(float(i)))

# ============================================================
# AUDIO — Procedural hip hop beat + character voice clips
# ============================================================
func _setup_audio() -> void:
	# Beat player (continuous loop via AudioStreamGenerator)
	beat_player = AudioStreamPlayer.new()
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = 22050
	gen.buffer_length = 0.5
	beat_player.stream = gen
	beat_player.volume_db = -8.0
	add_child(beat_player)
	_generate_beat_buffer()

	# Voice player (one-shot clips via AudioStreamWAV)
	voice_player = AudioStreamPlayer.new()
	voice_player.volume_db = -2.0
	add_child(voice_player)
	_generate_voice_clips()
	_init_tower_quotes()

func _start_beat() -> void:
	if beat_buffer.size() == 0:
		return
	beat_player.play()
	beat_playback = beat_player.get_stream_playback()
	beat_buf_pos = 0
	beat_playing = true

func _stop_beat() -> void:
	beat_player.stop()
	beat_playing = false
	beat_playback = null

func _push_beat_audio() -> void:
	if not beat_playing or beat_playback == null:
		return
	var avail = beat_playback.get_frames_available()
	for i in range(avail):
		beat_playback.push_frame(beat_buffer[beat_buf_pos])
		beat_buf_pos = (beat_buf_pos + 1) % beat_buffer.size()

func _generate_beat_buffer() -> void:
	var mix_rate := 22050
	var bpm := 88.0
	var samples_per_beat := int(float(mix_rate) * 60.0 / bpm)
	var bar_samples := samples_per_beat * 4
	beat_buffer.resize(bar_samples)

	# Pre-generate noise table
	var rng := RandomNumberGenerator.new()
	rng.seed = 808
	var noise := PackedFloat32Array()
	noise.resize(bar_samples)
	for i in range(bar_samples):
		noise[i] = rng.randf_range(-1.0, 1.0)

	var step := samples_per_beat / 4  # 16th note
	var kick_steps := [0, 3, 6, 10]
	var snare_steps := [4, 12]
	var hat_open := [2, 6, 10, 14]

	for i in range(bar_samples):
		var s := 0.0

		# Kick — punchy sub with pitch drop
		for ks in kick_steps:
			var off: int = i - ks * step
			if off >= 0 and off < int(step * 1.5):
				var t := float(off) / float(mix_rate)
				var freq := 150.0 * exp(-t * 15.0) + 45.0
				s += sin(TAU * freq * t + sin(TAU * freq * 0.5 * t) * 1.5) * exp(-t * 10.0) * 0.45

		# Snare — noise burst + tone
		for ss in snare_steps:
			var off: int = i - ss * step
			if off >= 0 and off < step:
				var t := float(off) / float(mix_rate)
				var env := exp(-t * 14.0)
				s += (noise[off] * 0.28 + sin(TAU * 185.0 * t) * exp(-t * 25.0) * 0.18) * env

		# Hi-hats — closed and open
		for h in range(16):
			var off: int = i - h * step
			var is_open: bool = h in hat_open
			var hat_dur: int = step if is_open else int(step / 3)
			if off >= 0 and off < hat_dur:
				var t := float(off) / float(mix_rate)
				var decay := 10.0 if is_open else 35.0
				s += noise[abs((off + h * 1000) % bar_samples)] * exp(-t * decay) * 0.09

		# Sub bass — follows kick root
		for bs in [0, 10]:
			var off: int = i - bs * step
			if off >= 0 and off < step * 3:
				var t := float(off) / float(mix_rate)
				s += sin(TAU * 55.0 * t) * exp(-t * 2.5) * 0.30

		beat_buffer[i] = Vector2(clampf(s, -0.95, 0.95), clampf(s, -0.95, 0.95))

func _samples_to_wav(samples: PackedFloat32Array, rate: int = 22050) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		var val := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		data[i * 2] = val & 0xFF
		data[i * 2 + 1] = (val >> 8) & 0xFF
	wav.data = data
	return wav

func _generate_voice_clips() -> void:
	var rate := 22050

	# Robin Hood — arrow whoosh (descending sweep + air noise)
	var robin_len := int(rate * 0.35)
	var robin_samples := PackedFloat32Array()
	robin_samples.resize(robin_len)
	for i in range(robin_len):
		var t := float(i) / float(rate)
		var freq := 800.0 * exp(-t * 8.0) + 100.0
		var env := exp(-t * 5.0) * clampf(sin(t * 20.0), 0.0, 1.0)
		robin_samples[i] = (sin(TAU * freq * t) * 0.3 + sin(t * 3000.0) * 0.1) * env
	voice_clips[TowerType.ROBIN_HOOD] = _samples_to_wav(robin_samples, rate)

	# Alice — curious ascending chime (C5 → E5 → G5)
	var alice_len := int(rate * 0.45)
	var alice_samples := PackedFloat32Array()
	alice_samples.resize(alice_len)
	var alice_notes := [523.25, 659.25, 783.99]  # C5, E5, G5
	var note_dur := alice_len / 3
	for i in range(alice_len):
		var t := float(i) / float(rate)
		var ni := mini(i / note_dur, 2)
		var nt := float(i - ni * note_dur) / float(rate)
		var freq: float = alice_notes[ni]
		var env := exp(-nt * 6.0) * 0.4
		alice_samples[i] = sin(TAU * freq * t) * env + sin(TAU * freq * 2.0 * t) * env * 0.15
	voice_clips[TowerType.ALICE] = _samples_to_wav(alice_samples, rate)

	# Wicked Witch — evil cackle (tremolo + rising pitch)
	var witch_len := int(rate * 0.45)
	var witch_samples := PackedFloat32Array()
	witch_samples.resize(witch_len)
	for i in range(witch_len):
		var t := float(i) / float(rate)
		var freq := 300.0 + t * 400.0
		var trem: float = absf(sin(TAU * 18.0 * t))
		var env := (1.0 - t / 0.45) * 0.35
		witch_samples[i] = sin(TAU * freq * t) * trem * env
	voice_clips[TowerType.WICKED_WITCH] = _samples_to_wav(witch_samples, rate)

	# Peter Pan — fairy sparkle (ascending twinkle bursts)
	var peter_len := int(rate * 0.4)
	var peter_samples := PackedFloat32Array()
	peter_samples.resize(peter_len)
	for i in range(peter_len):
		var t := float(i) / float(rate)
		var burst := sin(TAU * 25.0 * t)
		var freq := 1200.0 + t * 800.0 + burst * 200.0
		var env := exp(-t * 4.0) * 0.3
		peter_samples[i] = sin(TAU * freq * t) * env * (0.5 + 0.5 * abs(sin(TAU * 12.0 * t)))
	voice_clips[TowerType.PETER_PAN] = _samples_to_wav(peter_samples, rate)

	# Phantom — deep organ chord (C3 + G3 + C4, rich harmonics)
	var phantom_len := int(rate * 0.55)
	var phantom_samples := PackedFloat32Array()
	phantom_samples.resize(phantom_len)
	for i in range(phantom_len):
		var t := float(i) / float(rate)
		var attack := minf(t * 8.0, 1.0)
		var env := attack * exp(-t * 2.0) * 0.25
		var s := sin(TAU * 130.81 * t) + sin(TAU * 196.0 * t) * 0.7
		s += sin(TAU * 261.63 * t) * 0.5 + sin(TAU * 392.0 * t) * 0.2
		phantom_samples[i] = s * env
	voice_clips[TowerType.PHANTOM] = _samples_to_wav(phantom_samples, rate)

	# Scrooge — coin clinks (3 metallic hits)
	var scrooge_len := int(rate * 0.4)
	var scrooge_samples := PackedFloat32Array()
	scrooge_samples.resize(scrooge_len)
	var clink_times := [0.0, 0.12, 0.22]
	for i in range(scrooge_len):
		var t := float(i) / float(rate)
		var s := 0.0
		for ct in clink_times:
			var dt: float = t - ct
			if dt >= 0.0 and dt < 0.12:
				var env := exp(-dt * 35.0) * 0.4
				s += sin(TAU * 2800.0 * dt) * env + sin(TAU * 4200.0 * dt) * env * 0.5
		scrooge_samples[i] = s
	voice_clips[TowerType.SCROOGE] = _samples_to_wav(scrooge_samples, rate)

func _play_tower_voice(tower_type: TowerType) -> void:
	if voice_clips.has(tower_type):
		voice_player.stream = voice_clips[tower_type]
		voice_player.play()

func _init_tower_quotes() -> void:
	tower_quotes = {
		TowerType.ROBIN_HOOD: [
			"Steal from the rich, defend the path!",
			"My arrows fly true!",
			"For Sherwood!",
			"Robin Hood, at your service.",
		],
		TowerType.ALICE: [
			"Curiouser and curiouser!",
			"We're all mad here, you know.",
			"Off with their... wait, wrong character.",
			"Down the rabbit hole we go!",
		],
		TowerType.WICKED_WITCH: [
			"I'll get you, my pretties!",
			"Fly, my pretties, fly!",
			"How about a little fire?",
			"Surrender, Dorothy!",
		],
		TowerType.PETER_PAN: [
			"To live will be an awfully big adventure!",
			"I do believe in fairies!",
			"Second star to the right!",
			"I'll never grow up!",
		],
		TowerType.PHANTOM: [
			"The Music of the Night!",
			"I am your Angel of Music.",
			"The Phantom is here...",
			"Sing for me!",
		],
		TowerType.SCROOGE: [
			"Bah! Humbug!",
			"Every penny counts!",
			"Are there no prisons? No workhouses?",
			"I will honour Christmas in my heart.",
		],
	}

func _get_tower_quote(tower_type: TowerType) -> String:
	if not tower_quotes.has(tower_type):
		return "Ready for battle!"
	var quotes: Array = tower_quotes[tower_type]
	return quotes[randi() % quotes.size()]

func _draw_menu_background() -> void:
	# === Dark wood table / desk background ===
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.06, 0.04, 0.02))
	for y in range(0, 720, 3):
		var t = float(y) / 720.0
		var grain = sin(float(y) * 0.8 + cos(float(y) * 0.3) * 4.0) * 0.01
		var col = Color(0.08 + grain, 0.05 + grain * 0.6, 0.03 + grain * 0.3)
		draw_line(Vector2(0, y), Vector2(1280, y), col, 3.0)
	# Wood grain lines
	for i in range(12):
		var gy = float(i) * 62.0 + sin(float(i) * 2.1) * 20.0
		for x in range(0, 1280, 3):
			var wobble = sin(float(x) * 0.01 + float(i) * 1.5) * 8.0
			draw_circle(Vector2(float(x), gy + wobble), 0.5, Color(0.04, 0.025, 0.01, 0.15))

	# === Warm ambient candle glow on desk ===
	for candle in _book_candle_positions:
		var cx_pos = candle["x"]
		var cy_pos = candle["y"]
		var flicker = sin(_time * 5.0 + candle["offset"]) * 0.3 + sin(_time * 8.0 + candle["offset"] * 2.0) * 0.15
		var glow_r = 80.0 + flicker * 15.0
		draw_circle(Vector2(cx_pos, cy_pos), glow_r, Color(0.85, 0.55, 0.1, 0.025 + flicker * 0.008))
		draw_circle(Vector2(cx_pos, cy_pos), glow_r * 0.5, Color(0.9, 0.6, 0.15, 0.03 + flicker * 0.01))
		# Candle body
		draw_rect(Rect2(cx_pos - 4, cy_pos + 10, 8, 22), Color(0.85, 0.82, 0.7, 0.5))
		var flame_h = 7.0 + flicker * 4.0
		draw_circle(Vector2(cx_pos, cy_pos + 6 - flame_h * 0.3), 3.5, Color(1.0, 0.7, 0.2, 0.6 + flicker * 0.2))
		draw_circle(Vector2(cx_pos, cy_pos + 4 - flame_h * 0.5), 2.0, Color(1.0, 0.9, 0.5, 0.7 + flicker * 0.15))

	# === Floating dust motes ===
	for dust in _dust_positions:
		var dx = dust["x"] + sin(_time * dust["speed"] + dust["offset"]) * 30.0
		var dy = dust["y"] + cos(_time * dust["speed"] * 0.6 + dust["offset"]) * 20.0
		var alpha = 0.15 + 0.15 * sin(_time * 1.5 + dust["offset"])
		draw_circle(Vector2(dx, dy), dust["size"], Color(0.85, 0.75, 0.5, alpha))

	if menu_current_view == "chapters" or menu_current_view == "heroes":
		_draw_open_book()
	else:
		_draw_closed_book()

func _draw_closed_book() -> void:
	# === Leather-bound book cover (centered) ===
	var bx = 340.0
	var by = 60.0
	var bw = 600.0
	var bh = 500.0

	# Book shadow
	draw_rect(Rect2(bx + 8, by + 8, bw, bh), Color(0.0, 0.0, 0.0, 0.3))

	# Leather cover (rich brown with gradient)
	for i in range(50):
		var t = float(i) / 49.0
		var col = Color(0.28, 0.14, 0.06).lerp(Color(0.22, 0.10, 0.04), t)
		var grain = sin(float(i) * 3.7 + cos(float(i) * 2.1) * 2.0) * 0.02
		col.r += grain
		col.g += grain * 0.5
		draw_rect(Rect2(bx, by + t * bh, bw, bh / 49.0 + 1), col)

	# Leather texture (subtle grain)
	for i in range(30):
		var tx = bx + fmod(float(i) * 47.3, bw - 20.0) + 10.0
		var ty = by + fmod(float(i) * 31.7, bh - 20.0) + 10.0
		draw_circle(Vector2(tx, ty), 1.0, Color(0.15, 0.07, 0.03, 0.12))

	# Spine (left edge)
	draw_rect(Rect2(bx - 15, by - 5, 18, bh + 10), Color(0.18, 0.09, 0.04))
	for i in range(6):
		var sy = by + 50.0 + float(i) * 75.0
		draw_line(Vector2(bx - 15, sy), Vector2(bx + 3, sy), Color(0.65, 0.45, 0.1, 0.5), 2.0)

	# Page edges (visible between cover)
	draw_rect(Rect2(bx + bw - 3, by + 8, 6, bh - 16), Color(0.9, 0.85, 0.75, 0.6))
	for i in range(8):
		var py = by + 12.0 + float(i) * (bh - 24.0) / 7.0
		draw_line(Vector2(bx + bw - 3, py), Vector2(bx + bw + 3, py), Color(0.7, 0.65, 0.55, 0.3), 0.5)

	# Gold corner clasps
	var corners = [Vector2(bx + 15, by + 15), Vector2(bx + bw - 15, by + 15), Vector2(bx + 15, by + bh - 15), Vector2(bx + bw - 15, by + bh - 15)]
	for c in corners:
		draw_circle(c, 12, Color(0.65, 0.45, 0.1, 0.5))
		draw_circle(c, 8, Color(0.75, 0.55, 0.15, 0.4))
		draw_arc(c, 10, 0, TAU, 16, Color(0.85, 0.65, 0.2, 0.3), 1.5)

	# Gold embossed title
	var title_y = by + 140.0
	# Title border frame
	draw_rect(Rect2(bx + 80, title_y - 10, bw - 160, 80), Color(0.65, 0.45, 0.1, 0.08))
	draw_line(Vector2(bx + 100, title_y - 10), Vector2(bx + bw - 100, title_y - 10), Color(0.65, 0.45, 0.1, 0.35), 2.0)
	draw_line(Vector2(bx + 100, title_y + 70), Vector2(bx + bw - 100, title_y + 70), Color(0.65, 0.45, 0.1, 0.35), 2.0)

	# Subtitle line
	draw_line(Vector2(bx + 150, title_y + 95), Vector2(bx + bw - 150, title_y + 95), Color(0.65, 0.45, 0.1, 0.2), 1.0)

	# Decorative clasp/buckle
	var clasp_y = by + bh * 0.72
	draw_rect(Rect2(bx + bw * 0.5 - 30, clasp_y, 60, 8), Color(0.55, 0.35, 0.08, 0.4))
	draw_circle(Vector2(bx + bw * 0.5, clasp_y + 4), 10, Color(0.65, 0.45, 0.1, 0.4))
	draw_circle(Vector2(bx + bw * 0.5, clasp_y + 4), 6, Color(0.75, 0.55, 0.15, 0.3))

func _draw_open_book() -> void:
	# === Open book (two-page spread) ===
	var bx = 60.0
	var by = 45.0
	var pw = 560.0  # page width
	var ph = 555.0  # page height
	var spine_x = bx + pw + 10  # spine center

	# Book shadow
	draw_rect(Rect2(bx - 5 + 6, by - 5 + 6, pw * 2 + 30, ph + 10), Color(0.0, 0.0, 0.0, 0.25))

	# Left page (aged cream paper)
	for i in range(55):
		var t = float(i) / 54.0
		var col = Color(0.88, 0.82, 0.70).lerp(Color(0.85, 0.78, 0.65), t)
		var grain = sin(float(i) * 2.3) * 0.01
		col.r += grain
		col.g += grain
		draw_rect(Rect2(bx, by + t * ph, pw, ph / 54.0 + 1), col)

	# Right page
	for i in range(55):
		var t = float(i) / 54.0
		var col = Color(0.86, 0.80, 0.68).lerp(Color(0.83, 0.76, 0.63), t)
		var grain = sin(float(i) * 2.7 + 1.0) * 0.01
		col.r += grain
		col.g += grain
		draw_rect(Rect2(spine_x + 10, by + t * ph, pw, ph / 54.0 + 1), col)

	# Spine (leather center)
	draw_rect(Rect2(spine_x - 5, by - 8, 20, ph + 16), Color(0.22, 0.10, 0.04))
	for i in range(5):
		var sy = by + 60.0 + float(i) * 100.0
		draw_line(Vector2(spine_x - 5, sy), Vector2(spine_x + 15, sy), Color(0.65, 0.45, 0.1, 0.3), 2.0)
	# Spine shadow gradient
	for i in range(15):
		var t = float(i) / 14.0
		draw_line(Vector2(spine_x + 15 + t * 8, by), Vector2(spine_x + 15 + t * 8, by + ph), Color(0.0, 0.0, 0.0, 0.06 * (1.0 - t)), 1.0)
		draw_line(Vector2(spine_x - 5 - t * 8, by), Vector2(spine_x - 5 - t * 8, by + ph), Color(0.0, 0.0, 0.0, 0.06 * (1.0 - t)), 1.0)

	# Page borders — decorative gold trim on left page
	var border_col = Color(0.65, 0.45, 0.1, 0.2)
	draw_rect(Rect2(bx + 10, by + 10, pw - 20, 2), border_col)
	draw_rect(Rect2(bx + 10, by + ph - 12, pw - 20, 2), border_col)
	draw_rect(Rect2(bx + 10, by + 10, 2, ph - 20), border_col)
	draw_rect(Rect2(bx + pw - 12, by + 10, 2, ph - 20), border_col)

	# Right page border
	var rx = spine_x + 10
	draw_rect(Rect2(rx + 10, by + 10, pw - 20, 2), border_col)
	draw_rect(Rect2(rx + 10, by + ph - 12, pw - 20, 2), border_col)
	draw_rect(Rect2(rx + 10, by + 10, 2, ph - 20), border_col)
	draw_rect(Rect2(rx + pw - 12, by + 10, 2, ph - 20), border_col)

	# Corner ornaments (left page)
	for corner in [Vector2(bx + 18, by + 18), Vector2(bx + pw - 18, by + 18), Vector2(bx + 18, by + ph - 18), Vector2(bx + pw - 18, by + ph - 18)]:
		draw_circle(corner, 4, Color(0.65, 0.45, 0.1, 0.2))
		# Filigree lines
		draw_line(corner + Vector2(-8, 0), corner + Vector2(8, 0), Color(0.65, 0.45, 0.1, 0.12), 0.5)
		draw_line(corner + Vector2(0, -8), corner + Vector2(0, 8), Color(0.65, 0.45, 0.1, 0.12), 0.5)

	# Corner ornaments (right page)
	for corner in [Vector2(rx + 18, by + 18), Vector2(rx + pw - 18, by + 18), Vector2(rx + 18, by + ph - 18), Vector2(rx + pw - 18, by + ph - 18)]:
		draw_circle(corner, 4, Color(0.65, 0.45, 0.1, 0.2))
		draw_line(corner + Vector2(-8, 0), corner + Vector2(8, 0), Color(0.65, 0.45, 0.1, 0.12), 0.5)
		draw_line(corner + Vector2(0, -8), corner + Vector2(0, 8), Color(0.65, 0.45, 0.1, 0.12), 0.5)

	# Ink blot decorations (right page corners)
	draw_circle(Vector2(rx + pw - 40, by + ph - 40), 6.0, Color(0.2, 0.15, 0.1, 0.06))
	draw_circle(Vector2(rx + pw - 35, by + ph - 45), 4.0, Color(0.2, 0.15, 0.1, 0.04))

	# Left page: character preview area (tower preview is placed by _show_hero_preview/menu system)
	if menu_current_view == "chapters":
		var char_idx = menu_character_index
		# Character-themed decorative motif on left page
		var motif_y = by + 160.0
		var motif_x = bx + pw * 0.5
		# Draw a simple emblem/crest area
		draw_circle(Vector2(motif_x, motif_y + 80), 60, Color(0.65, 0.45, 0.1, 0.04))
		draw_arc(Vector2(motif_x, motif_y + 80), 55, 0, TAU, 32, Color(0.65, 0.45, 0.1, 0.12), 1.5)
		draw_arc(Vector2(motif_x, motif_y + 80), 45, 0, TAU, 32, Color(0.65, 0.45, 0.1, 0.08), 1.0)

		# Character emblem icons (simple procedural)
		match char_idx:
			0:  # Robin Hood - bow and arrow
				draw_arc(Vector2(motif_x, motif_y + 80), 25, 1.0, 5.3, 16, Color(0.4, 0.25, 0.08, 0.35), 2.5)
				draw_line(Vector2(motif_x - 20, motif_y + 60), Vector2(motif_x + 20, motif_y + 100), Color(0.4, 0.25, 0.08, 0.3), 1.5)
				draw_colored_polygon(PackedVector2Array([Vector2(motif_x + 18, motif_y + 96), Vector2(motif_x + 24, motif_y + 100), Vector2(motif_x + 20, motif_y + 104)]), Color(0.4, 0.25, 0.08, 0.3))
			1:  # Alice - playing card (heart)
				draw_rect(Rect2(motif_x - 18, motif_y + 58, 36, 44), Color(0.9, 0.87, 0.8, 0.3))
				draw_rect(Rect2(motif_x - 16, motif_y + 60, 32, 40), Color(0.95, 0.92, 0.88, 0.2))
				# Heart shape
				draw_circle(Vector2(motif_x - 6, motif_y + 73), 6, Color(0.8, 0.15, 0.15, 0.3))
				draw_circle(Vector2(motif_x + 6, motif_y + 73), 6, Color(0.8, 0.15, 0.15, 0.3))
				draw_colored_polygon(PackedVector2Array([Vector2(motif_x - 11, motif_y + 76), Vector2(motif_x + 11, motif_y + 76), Vector2(motif_x, motif_y + 92)]), Color(0.8, 0.15, 0.15, 0.3))
			2:  # Oz - emerald
				draw_colored_polygon(PackedVector2Array([Vector2(motif_x, motif_y + 58), Vector2(motif_x + 18, motif_y + 72), Vector2(motif_x + 14, motif_y + 95), Vector2(motif_x - 14, motif_y + 95), Vector2(motif_x - 18, motif_y + 72)]), Color(0.15, 0.6, 0.2, 0.3))
				draw_circle(Vector2(motif_x, motif_y + 78), 8, Color(0.3, 0.8, 0.4, 0.15))
			3:  # Peter Pan - star
				for s in range(5):
					var a1 = -PI / 2.0 + float(s) * TAU / 5.0
					var a2 = -PI / 2.0 + (float(s) + 0.5) * TAU / 5.0
					draw_line(Vector2(motif_x, motif_y + 80) + Vector2.from_angle(a1) * 22, Vector2(motif_x, motif_y + 80) + Vector2.from_angle(a2) * 10, Color(0.65, 0.55, 0.1, 0.3), 2.0)
					draw_line(Vector2(motif_x, motif_y + 80) + Vector2.from_angle(a2) * 10, Vector2(motif_x, motif_y + 80) + Vector2.from_angle(a1 + TAU / 5.0) * 22, Color(0.65, 0.55, 0.1, 0.3), 2.0)
			4:  # Phantom - mask
				draw_arc(Vector2(motif_x, motif_y + 72), 18, PI + 0.3, TAU - 0.3, 16, Color(0.9, 0.88, 0.82, 0.35), 3.0)
				draw_circle(Vector2(motif_x - 7, motif_y + 70), 4, Color(0.1, 0.08, 0.06, 0.3))
				draw_circle(Vector2(motif_x + 7, motif_y + 70), 4, Color(0.1, 0.08, 0.06, 0.3))
				draw_line(Vector2(motif_x, motif_y + 55), Vector2(motif_x, motif_y + 62), Color(0.9, 0.88, 0.82, 0.25), 2.0)
			5:  # Scrooge - coin
				draw_circle(Vector2(motif_x, motif_y + 80), 18, Color(0.75, 0.6, 0.1, 0.3))
				draw_circle(Vector2(motif_x, motif_y + 80), 15, Color(0.85, 0.7, 0.15, 0.2))
				draw_circle(Vector2(motif_x, motif_y + 80), 6, Color(0.65, 0.45, 0.1, 0.15))

		# Decorative line under character quote
		draw_line(Vector2(bx + 80, by + ph - 100), Vector2(bx + pw - 80, by + ph - 100), Color(0.65, 0.45, 0.1, 0.1), 1.0)

	# Right page: chapter separator lines (between the 3 cards)
	if menu_current_view == "chapters":
		for i in range(2):
			var sep_y = by + 190.0 + float(i) * 165.0
			draw_line(Vector2(rx + 30, sep_y), Vector2(rx + pw - 30, sep_y), Color(0.5, 0.4, 0.25, 0.15), 1.0)
			# Decorative diamond at center of separator
			var sep_cx = rx + pw * 0.5
			draw_colored_polygon(PackedVector2Array([Vector2(sep_cx, sep_y - 4), Vector2(sep_cx + 4, sep_y), Vector2(sep_cx, sep_y + 4), Vector2(sep_cx - 4, sep_y)]), Color(0.65, 0.45, 0.1, 0.15))

	# Page tab bookmarks on right edge (character quick nav)
	var tab_colors = [Color(0.2, 0.5, 0.15), Color(0.5, 0.15, 0.5), Color(0.15, 0.5, 0.3), Color(0.2, 0.3, 0.6), Color(0.5, 0.15, 0.2), Color(0.5, 0.4, 0.15)]
	if menu_current_view == "chapters":
		for i in range(6):
			var tab_y = by + 30.0 + float(i) * 80.0
			var tab_x = rx + pw - 5
			var is_active = (i == menu_character_index)
			var tab_w = 18.0 if is_active else 10.0
			var tab_alpha = 0.6 if is_active else 0.25
			draw_rect(Rect2(tab_x, tab_y, tab_w, 50), Color(tab_colors[i].r, tab_colors[i].g, tab_colors[i].b, tab_alpha))

# ============================================================
# GAME LOOP
# ============================================================

func _process(delta: float) -> void:
	_time += delta
	_push_beat_audio()
	if game_state != GameState.PLAYING:
		queue_redraw()
		return
	ghost_position = get_global_mouse_position()
	if is_wave_active:
		_handle_spawning(delta)
		_check_wave_complete()
	elif wave_auto_timer > 0.0:
		wave_auto_timer -= delta
		if wave_auto_timer <= 0.0:
			wave_auto_timer = -1.0
			_start_next_wave()
	queue_redraw()

func _handle_spawning(delta: float) -> void:
	if enemies_to_spawn <= 0:
		return
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_enemy()
		spawn_timer = spawn_interval

func _spawn_enemy() -> void:
	var enemy = enemy_scene.instantiate()
	enemy.add_to_group("enemies")

	# Set enemy theme and tier (theme is character-based, not level-based)
	enemy.enemy_theme = levels[current_level]["character"] if current_level >= 0 and current_level < levels.size() else 0
	var wave_progress = float(wave) / float(max(1, total_waves))
	if wave_progress <= 0.25:
		enemy.enemy_tier = 0
	elif wave_progress <= 0.5:
		enemy.enemy_tier = 1
	elif wave_progress <= 0.75:
		enemy.enemy_tier = 2
	else:
		enemy.enemy_tier = 3

	# 20-wave difficulty scaling
	var w = wave
	if w <= 5:
		# Early: gentle ramp
		enemy.max_health = 60.0 + w * 20.0
		enemy.speed = 70.0 + w * 5.0
		enemy.gold_reward = 8 + w * 2
	elif w <= 10:
		# Mid: moderate scaling
		enemy.max_health = 120.0 + (w - 5) * 40.0
		enemy.speed = 85.0 + (w - 5) * 8.0
		enemy.gold_reward = 14 + (w - 5) * 3
	elif w <= 15:
		# Hard: enemies get tanky
		enemy.max_health = 280.0 + (w - 10) * 60.0
		enemy.speed = 110.0 + (w - 10) * 6.0
		enemy.gold_reward = 26 + (w - 10) * 4
	else:
		# Very hard: brutal
		enemy.max_health = 500.0 + (w - 15) * 100.0
		enemy.speed = 125.0 + (w - 15) * 8.0
		enemy.gold_reward = 40 + (w - 15) * 6

	# Special wave modifiers (relative to total waves)
	var quarter = max(1, int(total_waves * 0.25))
	var half_w = max(1, int(total_waves * 0.5))
	var three_q = max(1, int(total_waves * 0.75))
	if w == quarter:
		enemy.speed *= 1.6
		enemy.max_health *= 0.6
	elif w == half_w:
		enemy.max_health *= 2.0
		enemy.speed *= 0.7
		enemy.gold_reward += 10
	elif w == three_q:
		enemy.max_health *= 0.5
		enemy.speed *= 1.3
	elif w == total_waves:
		enemy.max_health *= 3.0
		enemy.speed *= 0.8
		enemy.gold_reward += 25

	# Level difficulty multiplier
	if current_level >= 0 and current_level < levels.size():
		var diff = levels[current_level]["difficulty"]
		enemy.max_health *= diff
		enemy.speed = enemy.speed * (1.0 + (diff - 1.0) * 0.3)

	enemy.health = enemy.max_health
	enemy_path.add_child(enemy)
	enemies_to_spawn -= 1
	enemies_alive += 1

func _get_wave_enemy_count(w: int) -> int:
	var q = max(1, int(total_waves * 0.25))
	var h = max(1, int(total_waves * 0.5))
	var tq = max(1, int(total_waves * 0.75))
	var base = 4 + w * 2
	if w == q: return base + 8
	if w == h: return base - 4
	if w == tq: return base + 12
	if w == total_waves: return base - 6
	return base

func _get_wave_spawn_interval(w: int) -> float:
	var progress = float(w) / float(max(1, total_waves))
	if progress <= 0.33:
		return 0.9 - progress * 0.3
	elif progress <= 0.6:
		return 0.78 - (progress - 0.33) * 0.5
	elif progress <= 0.8:
		return 0.6 - (progress - 0.6) * 0.5
	else:
		return max(0.25, 0.48 - (progress - 0.8) * 0.3)

func _get_wave_name(w: int) -> String:
	var q = max(1, int(total_waves * 0.25))
	var h = max(1, int(total_waves * 0.5))
	var tq = max(1, int(total_waves * 0.75))
	var char_idx = levels[current_level]["character"] if current_level >= 0 and current_level < levels.size() else 0
	var chap_idx = levels[current_level]["chapter"] if current_level >= 0 and current_level < levels.size() else 0

	match char_idx:
		0: # Robin Hood
			match chap_idx:
				0: # Ch1 — Tax collectors, early Sherwood
					if w == q: return "FAST RUSH — Swift tax riders!"
					if w == h: return "TANK WAVE — Armored revenue cart!"
					if w == tq: return "SWARM — Tax collector stampede!"
					if w == total_waves: return "BOSS — The Royal Tax Master!"
					var n = ["Tax collectors spotted!", "Revenue patrol incoming", "More tax men approach",
						"Sherwood road toll guards", "Tax wagon escort", "Sheriff's informants",
						"Tax assessor squad", "Coin purse snatchers", "Tithe enforcers march",
						"Ledger-bearing clerks", "Treasury scouts advance", "Royal tax decree!",
						"Debt warrant officers", "Gold cart guardsmen"]
					return n[(w - 1) % n.size()]
				1: # Ch2 — Sheriff's soldiers, escalation
					if w == q: return "FAST RUSH — Mounted sheriff's scouts!"
					if w == h: return "TANK WAVE — Armored knights ride forth!"
					if w == tq: return "SWARM — The Sheriff's full garrison!"
					if w == total_waves: return "BOSS — The Sheriff of Nottingham!"
					var n = ["Sheriff's patrol spotted!", "Soldiers from the castle", "Crossbow sentries advance",
						"Nottingham cavalry scouts", "Castle garrison deploys", "Sheriff's archers march",
						"Knight errant vanguard", "Pikemen hold the line", "Sheriff's war hounds",
						"Battering ram escort", "Armored lance brigade", "Castle wall defenders",
						"The Sheriff's elite guard", "Siege tower builders"]
					return n[(w - 1) % n.size()]
				2: # Ch3 — Siege of Nottingham, climax
					if w == q: return "FAST RUSH — Siege scouts sprint ahead!"
					if w == h: return "TANK WAVE — Castle siege engines!"
					if w == tq: return "SWARM — All of Nottingham marches!"
					if w == total_waves: return "BOSS — Prince John's Royal Army!"
					var n = ["Siege vanguard approaches!", "Trebuchet operators advance", "Battering ram crews",
						"Castle wall breakers", "Prince John's heralds", "Royal decree enforcers",
						"Flaming arrow brigade", "Fortress sappers tunnel in", "War elephant handlers",
						"Crown loyalist knights", "The Prince's iron guard", "Nottingham's last stand",
						"Throne room defenders", "The final siege wave"]
					return n[(w - 1) % n.size()]
		1: # Alice
			match chap_idx:
				0: # Ch1 — Card scouts, early Wonderland
					if w == q: return "FAST RUSH — Card scouts scramble!"
					if w == h: return "TANK WAVE — Armored ace of spades!"
					if w == tq: return "SWARM — Full deck deployed!"
					if w == total_waves: return "BOSS — The Knave of Hearts!"
					var n = ["Card soldiers spotted!", "Numbered cards march", "Spade patrol incoming",
						"Diamond sentries glitter", "Club enforcers stomp", "Two of hearts scouts",
						"Shuffled patrol advance", "Card painters approach", "Rose garden guards",
						"Croquet ground wardens", "Hedge maze sentries", "Deck reshuffled!",
						"Wild card scouts", "Joker's little helpers"]
					return n[(w - 1) % n.size()]
				1: # Ch2 — Mad tea party & chess pieces
					if w == q: return "FAST RUSH — March Hare's stampede!"
					if w == h: return "TANK WAVE — The Jabberwock stirs!"
					if w == tq: return "SWARM — Chess pieces flood the board!"
					if w == total_waves: return "BOSS — The Red Queen!"
					var n = ["Mad tea party crashers!", "Dormouse sleeper agents", "March Hare's militia",
						"Cheshire grin stalkers", "Looking glass scouts", "Chess pawn advance",
						"Rook towers roll forward", "Knight pieces gallop", "Bishop diagonal assault",
						"Tweedledee & Tweedledum", "Bandersnatch sighting!", "Mock turtle brigade",
						"Vorpal blade seekers", "Through the looking glass"]
					return n[(w - 1) % n.size()]
				2: # Ch3 — Queen's court, climax
					if w == q: return "FAST RUSH — Queen's swift executioners!"
					if w == h: return "TANK WAVE — Jabberwock unleashed!"
					if w == tq: return "SWARM — The entire court attacks!"
					if w == total_waves: return "BOSS — The Queen of Hearts!"
					var n = ["Royal court assembles!", "Queen's herald sounds", "Executioner's guard",
						"Flamingo cavalry charge", "The Queen's croquet army", "Painting roses red!",
						"Throne room champions", "Crown jewel defenders", "Off with their heads!",
						"Jabberwock's brood descends", "Royal flush assault", "The Queen's ultimatum",
						"Wonderland unravels!", "Final verdict approaches"]
					return n[(w - 1) % n.size()]
		2: # Wicked Witch / Oz
			match chap_idx:
				0: # Ch1 — Winkie guards, early Oz
					if w == q: return "FAST RUSH — Winkie scouts dash!"
					if w == h: return "TANK WAVE — Armored Winkie captain!"
					if w == tq: return "SWARM — Winkie regiment marches!"
					if w == total_waves: return "BOSS — The Winkie General!"
					var n = ["Winkie guards spotted!", "Yellow uniform patrol", "Western frontier scouts",
						"Poppy field lurkers", "Winkie spear carriers", "Emerald road blockers",
						"Yellow brick sentries", "Winkie drum corps", "Witch's errand runners",
						"Tin whistle scouts", "Scarecrow field watchers", "Winkie border patrol",
						"Golden cap seekers", "Oz perimeter guards"]
					return n[(w - 1) % n.size()]
				1: # Ch2 — Flying monkeys & the Witch rises
					if w == q: return "FAST RUSH — Flying monkeys swoop!"
					if w == h: return "TANK WAVE — Armored gorilla guard!"
					if w == tq: return "SWARM — Monkey horde darkens the sky!"
					if w == total_waves: return "BOSS — The Wicked Witch of the West!"
					var n = ["Flying monkeys approach!", "Monkey squadron descends", "Winged ambush party",
						"Witch's cauldron brew stirs", "Broom-riding scouts", "Monkey bombardiers",
						"Crystal ball spies", "Enchanted forest walkers", "Tornado debris creatures",
						"Silver shoe seekers", "Witch's shadow minions", "Dark spell weavers",
						"Monkey king's vanguard", "The Witch's cackle echoes"]
					return n[(w - 1) % n.size()]
				2: # Ch3 — Nome King & Emerald City siege
					if w == q: return "FAST RUSH — Nome tunnelers burst forth!"
					if w == h: return "TANK WAVE — Rock titan advances!"
					if w == tq: return "SWARM — Underground legion surfaces!"
					if w == total_waves: return "BOSS — The Nome King!"
					var n = ["Nome tunnelers emerge!", "Crystal cave raiders", "Rock soldiers march",
						"Underground sappers dig in", "Gemstone golem patrol", "Emerald City spies",
						"Nome King's heralds", "Quartz shard throwers", "Obsidian knight brigade",
						"Magma core dwellers", "The Nome King stirs!", "Jewel-encrusted sentinels",
						"Earthquake brigade", "The throne room trembles"]
					return n[(w - 1) % n.size()]
		3: # Peter Pan
			match chap_idx:
				0: # Ch1 — Pirate scouts, Neverland shores
					if w == q: return "FAST RUSH — Pirate scouts sprint!"
					if w == h: return "TANK WAVE — Powder keg haulers!"
					if w == tq: return "SWARM — Shore landing party!"
					if w == total_waves: return "BOSS — The Pirate Bosun!"
					var n = ["Pirate deckhands arrive!", "Swabbie patrol incoming", "Buccaneer scouts",
						"Cutlass-wielding mates", "Crow's nest lookouts", "Plank walkers march",
						"Powder monkey brigade", "Rum barrel rollers", "Anchor chain draggers",
						"Dinghy landing crew", "Treasure map hunters", "Skull Rock sentries",
						"Parrot messenger scouts", "Neverland shore patrol"]
					return n[(w - 1) % n.size()]
				1: # Ch2 — Pirate officers & jungle dangers
					if w == q: return "FAST RUSH — Jungle ambush runners!"
					if w == h: return "TANK WAVE — Pirate cannon crew!"
					if w == tq: return "SWARM — Lost Boys besieged!"
					if w == total_waves: return "BOSS — The Pirate First Mate!"
					var n = ["Pirate officers advance!", "Boarding party inbound", "Cannon crew approaches",
						"First mate's detachment", "Jungle vine swingers", "Mermaid Lagoon assault",
						"Crocodile handlers march", "Boatswain's brigade", "Musket-bearing pirates",
						"Jungle trap setters", "Tiger Lily's warning!", "Neverland fog creepers",
						"Pirate war drummers", "The jungle closes in"]
					return n[(w - 1) % n.size()]
				2: # Ch3 — Captain Hook & the Jolly Roger
					if w == q: return "FAST RUSH — Hook's fastest cutthroats!"
					if w == h: return "TANK WAVE — Ironclad pirate warship!"
					if w == tq: return "SWARM — The entire Jolly Roger crew!"
					if w == total_waves: return "BOSS — Captain Hook!"
					var n = ["Hook sends his vanguard!", "Jolly Roger's finest", "The Black Spot cometh",
						"Hook's elite swordsmen", "Cannonball barrage crew", "All hands on deck!",
						"Pirate armada sails forth", "Hook's personal guard", "Tick-Tock draws near!",
						"Gangplank executioners", "The captain's ultimatum", "Jolly Roger broadside!",
						"Hook's final gambit", "Neverland's darkest hour"]
					return n[(w - 1) % n.size()]
		4: # Phantom
			match chap_idx:
				0: # Ch1 — Stagehands & shadows, opera house
					if w == q: return "FAST RUSH — Shadow dancers dart!"
					if w == h: return "TANK WAVE — Heavy curtain golem!"
					if w == tq: return "SWARM — Backstage mob floods out!"
					if w == total_waves: return "BOSS — The Stage Manager!"
					var n = ["Stagehands scurry forth!", "The orchestra stirs", "Shadows in the wings",
						"Prop room escapees", "Spotlight chasers", "Rats from below the stage",
						"Costume rack lurkers", "Sandbag droppers above", "Makeup room horrors",
						"Backstage frenzy builds", "Rigging rope swingers", "Prompt box whisperers",
						"Curtain pullers advance", "The overture begins"]
					return n[(w - 1) % n.size()]
				1: # Ch2 — Labyrinth & mirrors, deeper opera
					if w == q: return "FAST RUSH — Mirror shards scatter!"
					if w == h: return "TANK WAVE — Gargoyle sentinels descend!"
					if w == tq: return "SWARM — Labyrinth spawns endlessly!"
					if w == total_waves: return "BOSS — The Mirror Phantom!"
					var n = ["The masquerade begins!", "Mirror maze madness", "Trapdoor ambush below",
						"Labyrinth of mirrors", "Candelabra ghosts flicker", "Phantom copycats emerge",
						"Gargoyle watchers stir", "Chandelier chain rattlers", "Opera ghost sightings",
						"Box Five awakens!", "Falling curtain shades", "Hall of echoes patrol",
						"Wax figure sentries", "The organ's fury builds"]
					return n[(w - 1) % n.size()]
				2: # Ch3 — Underground lair, climax
					if w == q: return "FAST RUSH — Lair bats swarm the exits!"
					if w == h: return "TANK WAVE — The organ colossus!"
					if w == tq: return "SWARM — Underground phantoms pour forth!"
					if w == total_waves: return "BOSS — The Phantom of the Opera!"
					var n = ["Underground lake patrol!", "Christine's nightmare stirs", "Lair entrance guardians",
						"Sewer tunnel crawlers", "Subterranean echo shades", "Candle-lit crypt walkers",
						"The Phantom's music swells", "Torture chamber sentinels", "Lasso-wielding shadows",
						"Pipe organ resonators", "Lake of fire boatmen", "Mask fragment seekers",
						"The final act begins!", "Beneath the opera forever"]
					return n[(w - 1) % n.size()]
		5: # Scrooge
			match chap_idx:
				0: # Ch1 — Street urchins & carolers, London streets
					if w == q: return "FAST RUSH — Pickpocket dash!"
					if w == h: return "TANK WAVE — Workhouse bruiser!"
					if w == tq: return "SWARM — Street mob riots!"
					if w == total_waves: return "BOSS — The Debt Collector General!"
					var n = ["Street urchins scuttle!", "Chimney sweepers march", "Pickpocket gang approaches",
						"Workhouse escapees shamble", "Carolers gone wrong", "Fog-born shadows creep",
						"Lamplighter scouts", "Cobblestone prowlers", "Penny-pincher patrol",
						"Beggar brigade advances", "Newspaper boy ambush", "Coal dust sneakers",
						"Frostbitten vagrants", "London's forgotten ones"]
					return n[(w - 1) % n.size()]
				1: # Ch2 — Spirits & ghosts, hauntings
					if w == q: return "FAST RUSH — Spirit wisps scatter!"
					if w == h: return "TANK WAVE — Ghosts of Christmas Past!"
					if w == tq: return "SWARM — Spectral procession floods in!"
					if w == total_waves: return "BOSS — Ghost of Christmas Present!"
					var n = ["Debt collectors approach!", "Chain rattlers march", "Marley's associates",
						"Counting house guards", "Ghostly apparitions drift", "Spirit wisps gather",
						"Ledger keepers advance", "Top hat enforcers", "Spectral procession forms",
						"Frost wraiths howl!", "Candle flame phantoms", "Clock tower bell shades",
						"Memory lane specters", "The spirits converge"]
					return n[(w - 1) % n.size()]
				2: # Ch3 — Army of despair, climax
					if w == q: return "FAST RUSH — Despair's swift heralds!"
					if w == h: return "TANK WAVE — Marley's iron chains!"
					if w == tq: return "SWARM — The army of despair marches!"
					if w == total_waves: return "BOSS — Ghost of Christmas Yet to Come!"
					var n = ["Blizzard brigade advances!", "Frozen specters shamble", "Winter wolves howl",
						"Grave diggers march forth", "Tombstone sentinels rise", "The chains grow heavier",
						"Midnight bell tolls!", "Shadow of the future looms", "Despair's vanguard",
						"Headstone inscription crawlers", "Unmarked grave keepers", "The final Christmas Eve",
						"Bells toll midnight!", "Dawn must break"]
					return n[(w - 1) % n.size()]
	return "Wave %d" % w

func _check_wave_complete() -> void:
	if enemies_to_spawn <= 0 and enemies_alive <= 0:
		is_wave_active = false
		start_button.disabled = false
		if wave >= total_waves:
			_victory()
		else:
			start_button.text = "  Start Wave  "
			# Bonus gold between waves
			var bonus = 10 + wave * 3
			gold += bonus
			update_hud()
			info_label.text = "Wave %d cleared! +%dG bonus. Next wave in 2s..." % [wave, bonus]
			wave_auto_timer = 2.0

func _unhandled_input(event: InputEvent) -> void:
	if game_state != GameState.PLAYING:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if placing_tower:
				_try_place_tower(event.position)
			else:
				var tower = _find_tower_at(event.position)
				if tower:
					_select_tower(tower)
				else:
					_deselect_tower()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if placing_tower:
				placing_tower = false
				info_label.text = "Placement cancelled."
			else:
				_deselect_tower()

func _dist_to_path(pos: Vector2) -> float:
	var min_dist: float = 99999.0
	for p in path_points:
		var d = pos.distance_to(p)
		if d < min_dist:
			min_dist = d
	return min_dist

func _is_valid_placement(pos: Vector2) -> bool:
	if pos.y < 55 or pos.y > 622:
		return false
	if pos.x < 5 or pos.x > 1275:
		return false
	if _dist_to_path(pos) < MIN_PATH_DIST:
		return false
	for tp in placed_tower_positions:
		if pos.distance_to(tp) < MIN_TOWER_DIST:
			return false
	return true

func _try_place_tower(pos: Vector2) -> void:
	if not _is_valid_placement(pos):
		info_label.text = "Can't place there!"
		return
	var cost = tower_info[selected_tower]["cost"]
	if not spend_gold(cost):
		info_label.text = "Not enough gold!"
		return

	var tower = tower_scenes[selected_tower].instantiate()
	tower.position = pos
	tower.base_cost = cost
	towers_node.add_child(tower)

	placed_tower_positions.append(pos)
	purchased_towers[selected_tower] = true
	var tname = tower_info[selected_tower]["name"]

	# Disable the button — one purchase per tower
	if tower_buttons.has(selected_tower):
		tower_buttons[selected_tower].text = "PLACED"
		tower_buttons[selected_tower].disabled = true

	placing_tower = false
	_play_tower_voice(selected_tower)
	var quote = _get_tower_quote(selected_tower)
	info_label.text = "%s: \"%s\"" % [tname, quote]

# ============================================================
# DRAW — Level-specific backgrounds
# ============================================================
func _draw() -> void:
	if game_state == GameState.MENU:
		_draw_menu_background()
		return

	var sky_color = Color(0.04, 0.06, 0.14)
	var ground_color = Color(0.08, 0.18, 0.06)
	if current_level >= 0 and current_level < levels.size():
		sky_color = levels[current_level]["sky_color"]
		ground_color = levels[current_level]["ground_color"]

	match current_level:
		0, 1, 2: _draw_robin_ch1(sky_color, ground_color)
		3, 4, 5: _draw_alice_ch1(sky_color, ground_color)
		6, 7, 8: _draw_oz_ch1(sky_color, ground_color)
		9, 10, 11: _draw_peter_ch1(sky_color, ground_color)
		12, 13, 14: _draw_phantom_ch1(sky_color, ground_color)
		15, 16, 17: _draw_scrooge_ch1(sky_color, ground_color)

	# === Ghost tower preview (shared) ===
	if placing_tower:
		var valid = _is_valid_placement(ghost_position)
		var color = Color(0.2, 0.8, 0.2, 0.35) if valid else Color(0.9, 0.2, 0.2, 0.35)
		draw_circle(ghost_position, 24.0, color)
		if valid:
			var preview_range = tower_info[selected_tower]["range"]
			draw_arc(ghost_position, preview_range, 0, TAU, 64, Color(1, 1, 1, 0.15), 1.5)

	# === Pulsing gold indicators on affordable-to-upgrade towers ===
	for tower in get_tree().get_nodes_in_group("towers"):
		if tower.upgrade_tier < 4 and tower.has_method("get_next_upgrade_info"):
			var info = tower.get_next_upgrade_info()
			if not info.is_empty() and gold >= info["cost"]:
				var pulse = (sin(_time * 4.0) + 1.0) * 0.5
				var dot_pos = tower.global_position + Vector2(0, -48)
				draw_circle(dot_pos, 4.0 + pulse * 2.0, Color(1.0, 0.84, 0.0, 0.5 + pulse * 0.4))
				draw_circle(dot_pos, 8.0 + pulse * 3.0, Color(1.0, 0.84, 0.0, 0.1 + pulse * 0.1))

func _draw_robin_ch1(sky_color: Color, ground_color: Color) -> void:
	# --- SKY GRADIENT ---
	var sky_top := Color(0.02, 0.06, 0.10)
	var sky_mid := Color(0.04, 0.12, 0.08)
	var sky_horizon := Color(0.12, 0.18, 0.06)
	var amber_haze := Color(0.25, 0.15, 0.04, 0.35)
	for i in range(60):
		var t: float = float(i) / 59.0
		var col: Color
		if t < 0.5:
			col = sky_top.lerp(sky_mid, t * 2.0)
		else:
			col = sky_mid.lerp(sky_horizon, (t - 0.5) * 2.0)
		var haze_strength: float = clampf(t - 0.5, 0.0, 0.5) * 2.0
		col = col.lerp(amber_haze, haze_strength * 0.4)
		var y0: float = 50.0 + float(i) * 9.6
		draw_rect(Rect2(0, y0, 1280, 10.6), col)

	# --- STARS ---
	var star_seeds: Array = [37, 71, 113, 157, 199, 241, 283, 311, 347, 389, 421, 463, 509, 557, 601, 643, 691, 733, 787, 823]
	for s in range(star_seeds.size()):
		var sd: int = star_seeds[s]
		var sx: float = fmod(float(sd) * 7.3, 1280.0)
		var sy: float = 55.0 + fmod(float(sd) * 3.7, 200.0)
		var twinkle: float = 0.4 + 0.6 * absf(sin(_time * 1.5 + float(sd)))
		draw_circle(Vector2(sx, sy), 1.0 + twinkle * 0.5, Color(0.8, 0.85, 0.95, twinkle * 0.7))

	# --- FULL MOON ---
	var moon_center := Vector2(900, 120)
	for g in range(5):
		draw_circle(moon_center, 42.0 + float(g) * 12.0, Color(0.7, 0.75, 0.9, 0.06 - float(g) * 0.01))
	draw_circle(moon_center, 42.0, Color(0.82, 0.85, 0.92))
	draw_circle(moon_center + Vector2(-8, -5), 40.0, Color(0.78, 0.80, 0.88))
	draw_circle(moon_center + Vector2(-10, 5), 6.0, Color(0.72, 0.74, 0.82, 0.4))
	draw_circle(moon_center + Vector2(12, -8), 4.0, Color(0.72, 0.74, 0.82, 0.3))
	draw_circle(moon_center + Vector2(5, 14), 3.5, Color(0.72, 0.74, 0.82, 0.35))

	# --- MOONBEAMS ---
	for mb in range(5):
		var beam_x: float = 850.0 + float(mb) * 30.0
		var sway: float = sin(_time * 0.4 + float(mb) * 1.2) * 15.0
		var beam_alpha: float = 0.03 + 0.015 * sin(_time * 0.6 + float(mb))
		draw_colored_polygon(PackedVector2Array([Vector2(beam_x - 5 + sway * 0.3, 160), Vector2(beam_x + 5 + sway * 0.3, 160), Vector2(beam_x + 40 + sway, 620), Vector2(beam_x - 40 + sway, 620)]), Color(0.7, 0.75, 0.9, beam_alpha))

	# --- NOTTINGHAM CASTLE SILHOUETTE ---
	var castle_col := Color(0.03, 0.04, 0.06)
	draw_colored_polygon(PackedVector2Array([Vector2(950, 280), Vector2(1000, 200), Vector2(1050, 180), Vector2(1120, 170), Vector2(1200, 185), Vector2(1280, 220), Vector2(1280, 280)]), castle_col)
	draw_rect(Rect2(1060, 100, 80, 80), castle_col)
	for bt in range(5):
		draw_rect(Rect2(1060 + bt * 18, 92, 10, 12), castle_col)
	draw_rect(Rect2(1020, 110, 30, 70), castle_col)
	draw_colored_polygon(PackedVector2Array([Vector2(1015, 110), Vector2(1035, 75), Vector2(1055, 110)]), castle_col)
	draw_rect(Rect2(1150, 105, 35, 75), castle_col)
	draw_colored_polygon(PackedVector2Array([Vector2(1145, 105), Vector2(1167, 68), Vector2(1190, 105)]), castle_col)
	draw_circle(Vector2(1100, 180), 15.0, Color(0.02, 0.02, 0.04))
	draw_rect(Rect2(1085, 180, 30, 20), Color(0.02, 0.02, 0.04))
	draw_rect(Rect2(1000, 170, 60, 10), castle_col)
	draw_rect(Rect2(1140, 165, 70, 10), castle_col)
	var tf1: float = 0.5 + 0.5 * sin(_time * 6.0 + 1.0)
	var tf2: float = 0.5 + 0.5 * sin(_time * 7.3 + 3.0)
	draw_circle(Vector2(1035, 130), 2.5, Color(0.9, 0.5, 0.1, 0.5 + tf1 * 0.5))
	draw_circle(Vector2(1035, 130), 5.0, Color(0.9, 0.4, 0.1, 0.15 + tf1 * 0.1))
	draw_circle(Vector2(1167, 125), 2.5, Color(0.9, 0.5, 0.1, 0.5 + tf2 * 0.5))
	draw_circle(Vector2(1167, 125), 5.0, Color(0.9, 0.4, 0.1, 0.15 + tf2 * 0.1))

	# --- DISTANT BACKGROUND TREES ---
	for dt in range(18):
		var dtx: float = float(dt) * 75.0 + 20.0
		var dty: float = 260.0 + sin(float(dt) * 2.3) * 30.0
		var dts: float = 50.0 + sin(float(dt) * 1.7) * 15.0
		draw_rect(Rect2(dtx - 3, dty, 6, 60), Color(0.02, 0.05, 0.08, 0.85))
		draw_circle(Vector2(dtx, dty - 10), dts * 0.5, Color(0.02, 0.05, 0.08, 0.85))
		draw_circle(Vector2(dtx - dts * 0.25, dty), dts * 0.4, Color(0.02, 0.05, 0.08, 0.85))

	# --- BROOK / STREAM ---
	var brook_pts: PackedVector2Array = PackedVector2Array()
	var brook_bottom: PackedVector2Array = PackedVector2Array()
	var bpx_arr: Array = [500, 530, 570, 620, 660, 680, 690, 700, 720, 750]
	var bpy_arr: Array = [380, 395, 415, 430, 445, 465, 485, 510, 540, 570]
	for bp in range(bpx_arr.size()):
		brook_pts.append(Vector2(float(bpx_arr[bp]) - 12, float(bpy_arr[bp])))
		brook_bottom.insert(0, Vector2(float(bpx_arr[bp]) + 12, float(bpy_arr[bp])))
	brook_pts.append_array(brook_bottom)
	draw_colored_polygon(brook_pts, Color(0.05, 0.1, 0.25, 0.8))
	for sh in range(8):
		var shx: float = float(bpx_arr[sh]) + sin(_time * 2.5 + float(sh)) * 4.0
		var shy: float = float(bpy_arr[sh]) + cos(_time * 1.8 + float(sh)) * 2.0
		draw_line(Vector2(shx - 5, shy), Vector2(shx + 5, shy), Color(0.2, 0.3, 0.6, 0.15 + 0.1 * sin(_time * 2.0)), 1.5)

	# --- LITTLE JOHN'S BRIDGE ---
	var bridge_x: float = 660.0
	var bridge_y: float = 440.0
	for pl in range(6):
		draw_rect(Rect2(bridge_x - 15 + float(pl) * 7, bridge_y - 3, 6, 28), Color(0.25, 0.15, 0.06))
	draw_line(Vector2(bridge_x - 18, bridge_y - 6), Vector2(bridge_x + 30, bridge_y - 6), Color(0.15, 0.08, 0.03), 2.5)
	draw_line(Vector2(bridge_x - 18, bridge_y + 28), Vector2(bridge_x + 30, bridge_y + 28), Color(0.15, 0.08, 0.03), 2.5)
	draw_rect(Rect2(bridge_x - 20, bridge_y - 10, 5, 42), Color(0.15, 0.08, 0.03))
	draw_rect(Rect2(bridge_x + 28, bridge_y - 10, 5, 42), Color(0.15, 0.08, 0.03))

	# --- GROUND LAYERS ---
	draw_rect(Rect2(0, 480, 1280, 240), Color(0.04, 0.12, 0.03))
	draw_rect(Rect2(0, 490, 1280, 130), Color(0.06, 0.14, 0.04))
	draw_rect(Rect2(0, 580, 1280, 48), Color(0.05, 0.10, 0.03))
	# moss rocks
	var rock_seeds: Array = [120, 340, 580, 800, 1050, 250, 700, 950]
	for r in range(rock_seeds.size()):
		var rx: float = float(rock_seeds[r])
		var ry: float = 530.0 + fmod(float(rock_seeds[r]) * 0.37, 60.0)
		var rs: float = 6.0 + fmod(float(rock_seeds[r]) * 0.13, 8.0)
		draw_circle(Vector2(rx, ry), rs, Color(0.15, 0.15, 0.12))
		draw_arc(Vector2(rx, ry - rs * 0.3), rs * 0.8, 2.8, 6.0, 8, Color(0.1, 0.3, 0.08, 0.7), 2.0)
	# ferns
	for f in range(15):
		var fx: float = fmod(float(f) * 97.0, 1280.0)
		var fy: float = 510.0 + fmod(float(f) * 43.0, 70.0)
		for frond in range(5):
			var angle: float = -0.8 + float(frond) * 0.4
			draw_line(Vector2(fx, fy), Vector2(fx + cos(angle) * 14.0, fy - sin(absf(angle) + 0.5) * 10.0), Color(0.06, 0.22, 0.05, 0.8), 1.5)
	# fallen leaves
	for lf in range(40):
		var lfx: float = fmod(float(lf) * 31.7, 1280.0)
		var lfy: float = 500.0 + fmod(float(lf) * 17.3, 100.0)
		var leaf_colors: Array = [Color(0.6, 0.35, 0.05, 0.6), Color(0.7, 0.2, 0.05, 0.5), Color(0.65, 0.5, 0.1, 0.55)]
		draw_circle(Vector2(lfx, lfy), 1.5 + fmod(float(lf) * 0.3, 1.5), leaf_colors[lf % 3])

	# --- PATH ---
	if enemy_path and enemy_path.curve:
		var pp: PackedVector2Array = enemy_path.curve.get_baked_points()
		if pp.size() > 1:
			for i in range(pp.size() - 1):
				draw_line(pp[i], pp[i + 1], Color(0.06, 0.18, 0.04, 0.5), 32.0)
			for i in range(pp.size() - 1):
				draw_line(pp[i], pp[i + 1], Color(0.08, 0.05, 0.02), 28.0)
			for i in range(pp.size() - 1):
				draw_line(pp[i], pp[i + 1], Color(0.18, 0.12, 0.05), 22.0)
			for i in range(pp.size() - 1):
				var p0: Vector2 = pp[i]
				var p1: Vector2 = pp[i + 1]
				var dir: Vector2 = (p1 - p0).normalized()
				var perp := Vector2(-dir.y, dir.x)
				draw_line(p0 + perp * 4.0, p1 + perp * 4.0, Color(0.22, 0.16, 0.08, 0.5), 1.5)
				draw_line(p0 - perp * 4.0, p1 - perp * 4.0, Color(0.22, 0.16, 0.08, 0.5), 1.5)
			for pb in range(20):
				var idx: int = (pb * 7) % pp.size()
				draw_circle(pp[idx] + Vector2(sin(float(pb) * 3.1) * 8.0, cos(float(pb) * 2.7) * 3.0), 1.5, Color(0.25, 0.2, 0.15, 0.6))

	# --- MIDGROUND TREES ---
	var mtx_arr: Array = [320, 480, 750, 920, 1100, 60, 1220]
	var mty_arr: Array = [340, 370, 320, 360, 340, 380, 350]
	for mt in range(mtx_arr.size()):
		var mtx: float = float(mtx_arr[mt])
		var mty: float = float(mty_arr[mt])
		draw_rect(Rect2(mtx - 5, mty, 10, 120), Color(0.12, 0.07, 0.03))
		draw_line(Vector2(mtx - 5, mty + 115), Vector2(mtx - 18, mty + 125), Color(0.12, 0.07, 0.03), 3.0)
		draw_line(Vector2(mtx + 5, mty + 115), Vector2(mtx + 16, mty + 125), Color(0.12, 0.07, 0.03), 3.0)
		draw_circle(Vector2(mtx, mty - 20), 35.0, Color(0.04, 0.14, 0.03, 0.9))
		draw_circle(Vector2(mtx - 25, mty - 5), 28.0, Color(0.04, 0.14, 0.03, 0.9))
		draw_circle(Vector2(mtx + 22, mty - 8), 30.0, Color(0.04, 0.14, 0.03, 0.9))

	# --- THE MAJOR OAK ---
	var oak_x: float = 150.0
	var oak_y: float = 300.0
	# massive trunk
	draw_colored_polygon(PackedVector2Array([Vector2(oak_x - 30, oak_y + 200), Vector2(oak_x - 35, oak_y + 150), Vector2(oak_x - 28, oak_y + 80), Vector2(oak_x - 22, oak_y + 20), Vector2(oak_x - 15, oak_y - 20), Vector2(oak_x + 15, oak_y - 20), Vector2(oak_x + 25, oak_y + 20), Vector2(oak_x + 30, oak_y + 80), Vector2(oak_x + 38, oak_y + 150), Vector2(oak_x + 32, oak_y + 200)]), Color(0.14, 0.08, 0.03))
	# bark texture
	for bl in range(8):
		var by: float = oak_y + 10.0 + float(bl) * 22.0
		draw_line(Vector2(oak_x - 18 + sin(float(bl) * 1.5) * 5.0, by), Vector2(oak_x - 12 + sin(float(bl) * 1.5) * 5.0, by + 18), Color(0.08, 0.04, 0.02), 1.5)
		draw_line(Vector2(oak_x + 8 - sin(float(bl) * 1.5) * 5.0, by + 5), Vector2(oak_x + 14 - sin(float(bl) * 1.5) * 5.0, by + 20), Color(0.08, 0.04, 0.02), 1.5)
	# massive branches
	draw_line(Vector2(oak_x - 15, oak_y), Vector2(oak_x - 80, oak_y - 60), Color(0.14, 0.08, 0.03), 10.0)
	draw_line(Vector2(oak_x + 15, oak_y), Vector2(oak_x + 90, oak_y - 50), Color(0.14, 0.08, 0.03), 9.0)
	draw_line(Vector2(oak_x - 10, oak_y - 10), Vector2(oak_x - 50, oak_y - 90), Color(0.14, 0.08, 0.03), 7.0)
	draw_line(Vector2(oak_x + 10, oak_y - 10), Vector2(oak_x + 40, oak_y - 80), Color(0.14, 0.08, 0.03), 7.0)
	draw_line(Vector2(oak_x, oak_y - 15), Vector2(oak_x + 10, oak_y - 100), Color(0.14, 0.08, 0.03), 6.0)
	draw_line(Vector2(oak_x - 80, oak_y - 60), Vector2(oak_x - 110, oak_y - 85), Color(0.08, 0.04, 0.02), 4.0)
	draw_line(Vector2(oak_x + 90, oak_y - 50), Vector2(oak_x + 130, oak_y - 70), Color(0.08, 0.04, 0.02), 4.0)
	# enormous canopy
	for cp_data in [[0, -80, 70], [-60, -50, 55], [65, -45, 55], [-30, -100, 45], [30, -95, 48], [-85, -70, 35], [95, -60, 38]]:
		draw_circle(Vector2(oak_x + cp_data[0], oak_y + cp_data[1]), float(cp_data[2]), Color(0.03, 0.12, 0.02, 0.95))
	draw_circle(Vector2(oak_x + 20, oak_y - 110), 20.0, Color(0.05, 0.18, 0.04, 0.85))
	# treehouse platform
	draw_rect(Rect2(oak_x - 25, oak_y - 30, 55, 5), Color(0.2, 0.12, 0.04))
	draw_rect(Rect2(oak_x - 25, oak_y - 48, 3, 18), Color(0.18, 0.1, 0.04))
	draw_rect(Rect2(oak_x + 27, oak_y - 48, 3, 18), Color(0.18, 0.1, 0.04))
	draw_line(Vector2(oak_x - 25, oak_y - 48), Vector2(oak_x + 30, oak_y - 48), Color(0.18, 0.1, 0.04), 2.0)
	# rope ladder
	draw_line(Vector2(oak_x + 5, oak_y - 25), Vector2(oak_x + 5, oak_y + 55), Color(0.35, 0.25, 0.1), 1.5)
	draw_line(Vector2(oak_x + 15, oak_y - 25), Vector2(oak_x + 15, oak_y + 55), Color(0.35, 0.25, 0.1), 1.5)
	for rung in range(6):
		draw_line(Vector2(oak_x + 5, oak_y - 15 + float(rung) * 11.0), Vector2(oak_x + 15, oak_y - 15 + float(rung) * 11.0), Color(0.35, 0.25, 0.1), 1.5)
	# hanging game
	draw_line(Vector2(oak_x + 90, oak_y - 50), Vector2(oak_x + 90, oak_y - 30), Color(0.35, 0.25, 0.1), 1.5)
	draw_circle(Vector2(oak_x + 90, oak_y - 24), 4.0, Color(0.2, 0.12, 0.06))
	draw_line(Vector2(oak_x + 90, oak_y - 20), Vector2(oak_x + 87, oak_y - 12), Color(0.18, 0.1, 0.05), 1.5)

	# --- ROBIN HOOD'S CAMP ---
	var camp_x: float = 160.0
	var camp_y: float = 510.0
	draw_colored_polygon(PackedVector2Array([Vector2(camp_x - 50, camp_y + 30), Vector2(camp_x - 25, camp_y - 10), Vector2(camp_x, camp_y + 30)]), Color(0.12, 0.2, 0.06))
	draw_colored_polygon(PackedVector2Array([Vector2(camp_x - 32, camp_y + 30), Vector2(camp_x - 25, camp_y + 8), Vector2(camp_x - 18, camp_y + 30)]), Color(0.04, 0.04, 0.03))
	draw_colored_polygon(PackedVector2Array([Vector2(camp_x + 30, camp_y + 25), Vector2(camp_x + 50, camp_y - 5), Vector2(camp_x + 70, camp_y + 25)]), Color(0.2, 0.14, 0.06))
	draw_colored_polygon(PackedVector2Array([Vector2(camp_x + 5, camp_y + 10), Vector2(camp_x + 18, camp_y - 12), Vector2(camp_x + 32, camp_y + 10)]), Color(0.08, 0.14, 0.04))
	draw_rect(Rect2(camp_x - 15, camp_y + 35, 30, 5), Color(0.2, 0.12, 0.04))
	draw_rect(Rect2(camp_x + 20, camp_y + 40, 25, 5), Color(0.2, 0.12, 0.04))
	# weapon rack
	draw_line(Vector2(camp_x + 85, camp_y + 5), Vector2(camp_x + 85, camp_y + 45), Color(0.2, 0.12, 0.05), 2.5)
	draw_line(Vector2(camp_x + 100, camp_y + 5), Vector2(camp_x + 100, camp_y + 45), Color(0.2, 0.12, 0.05), 2.5)
	draw_arc(Vector2(camp_x + 89, camp_y + 20), 8.0, 1.2, 5.1, 10, Color(0.3, 0.18, 0.06), 1.5)
	draw_arc(Vector2(camp_x + 95, camp_y + 25), 7.0, 1.2, 5.1, 10, Color(0.3, 0.18, 0.06), 1.5)
	# WANTED poster
	draw_rect(Rect2(oak_x + 35, oak_y + 60, 22, 28), Color(0.7, 0.6, 0.4, 0.8))
	draw_rect(Rect2(oak_x + 36, oak_y + 61, 20, 5), Color(0.3, 0.1, 0.05, 0.7))
	for tl in range(4):
		draw_line(Vector2(oak_x + 38, oak_y + 70 + float(tl) * 4.5), Vector2(oak_x + 54, oak_y + 70 + float(tl) * 4.5), Color(0.3, 0.2, 0.1, 0.5), 1.0)
	draw_circle(Vector2(oak_x + 46, oak_y + 59), 1.5, Color(0.3, 0.3, 0.3))

	# --- DECORATIONS ---
	for dec in _decorations:
		var dtype: String = dec["type"]
		var dpos: Vector2 = dec["pos"]
		var dsize: float = dec["size"]
		var dextra: float = dec["extra"]
		if dtype == "oak_tree":
			draw_rect(Rect2(dpos.x - dsize * 0.15, dpos.y - dsize * 0.2, dsize * 0.3, dsize * 0.8), Color(0.1, 0.06, 0.02))
			draw_circle(dpos + Vector2(0, -dsize * 0.4), dsize * 0.5, Color(0.03, 0.15, 0.03, 0.9))
			draw_circle(dpos + Vector2(-dsize * 0.3, -dsize * 0.2), dsize * 0.35, Color(0.03, 0.15, 0.03, 0.9))
		elif dtype == "target":
			draw_circle(dpos, 7.0, Color(0.8, 0.8, 0.7))
			draw_circle(dpos, 5.0, Color(0.7, 0.15, 0.1))
			draw_circle(dpos, 3.0, Color(0.8, 0.8, 0.7))
			draw_circle(dpos, 1.5, Color(0.7, 0.15, 0.1))
			draw_line(dpos + Vector2(-8, -4), dpos, Color(0.3, 0.2, 0.05), 1.5)
			draw_line(Vector2(dpos.x, dpos.y + 7), Vector2(dpos.x, dpos.y + 16), Color(0.2, 0.12, 0.04), 2.5)
		elif dtype == "bush":
			draw_circle(dpos, dsize * 0.5, Color(0.04, 0.16 + dextra * 0.05, 0.03, 0.9))
			draw_circle(dpos + Vector2(-dsize * 0.3, dsize * 0.1), dsize * 0.35, Color(0.04, 0.16, 0.03, 0.9))
			draw_circle(dpos + Vector2(dsize * 0.25, dsize * 0.08), dsize * 0.38, Color(0.04, 0.16, 0.03, 0.9))
			if dextra > 0.5:
				for b in range(3):
					draw_circle(dpos + Vector2(cos(float(b) * 2.1) * dsize * 0.25, sin(float(b) * 2.1) * dsize * 0.15 - dsize * 0.1), 2.0, Color(0.5, 0.05, 0.1))
		elif dtype == "deer":
			var deer_col := Color(0.15, 0.1, 0.05)
			var facing: float = -1.0 if dextra > 0.5 else 1.0
			var body_pts: PackedVector2Array = PackedVector2Array()
			for da in range(16):
				body_pts.append(dpos + Vector2(cos(float(da) * TAU / 16.0) * dsize * 0.4 * facing, sin(float(da) * TAU / 16.0) * dsize * 0.2))
			draw_colored_polygon(body_pts, deer_col)
			var head_pos: Vector2 = dpos + Vector2(dsize * 0.5 * facing, -dsize * 0.35)
			draw_line(dpos + Vector2(dsize * 0.3 * facing, -dsize * 0.1), head_pos, deer_col, dsize * 0.1)
			draw_circle(head_pos, dsize * 0.1, deer_col)
			var ab: Vector2 = head_pos + Vector2(0, -dsize * 0.1)
			draw_line(ab, ab + Vector2(-dsize * 0.12 * facing, -dsize * 0.2), deer_col, 1.5)
			draw_line(ab, ab + Vector2(dsize * 0.08 * facing, -dsize * 0.22), deer_col, 1.5)
			draw_line(ab + Vector2(-dsize * 0.12 * facing, -dsize * 0.2), ab + Vector2(-dsize * 0.2 * facing, -dsize * 0.25), deer_col, 1.0)
			for li in range(4):
				var loff: Array = [-0.2, -0.08, 0.08, 0.2]
				draw_line(Vector2(dpos.x + loff[li] * dsize * facing, dpos.y + dsize * 0.15), Vector2(dpos.x + loff[li] * dsize * facing + facing * 2.0, dpos.y + dsize * 0.45), deer_col, 2.0)
			draw_circle(head_pos + Vector2(dsize * 0.05 * facing, -dsize * 0.02), 1.0, Color(0.4, 0.3, 0.1))
		elif dtype == "campfire":
			var fi: float = 0.7 + 0.3 * sin(_time * 5.0 + dextra * 10.0)
			draw_circle(dpos, dsize * 3.0, Color(0.4, 0.15, 0.02, 0.08 * fi))
			draw_circle(dpos, dsize * 2.0, Color(0.5, 0.2, 0.03, 0.12 * fi))
			for fs in range(8):
				draw_circle(dpos + Vector2(cos(float(fs) * TAU / 8.0) * dsize * 0.7, sin(float(fs) * TAU / 8.0) * dsize * 0.35), 3.0, Color(0.2, 0.18, 0.15))
			draw_line(dpos + Vector2(-dsize * 0.5, dsize * 0.15), dpos + Vector2(dsize * 0.5, dsize * 0.15), Color(0.2, 0.1, 0.02), 4.0)
			for fl in range(6):
				var flame_x: float = dpos.x + sin(float(fl) * 1.7 + _time * 4.0) * dsize * 0.3
				var flame_h: float = dsize * (0.6 + 0.4 * sin(_time * 6.0 + float(fl) * 2.0)) * fi
				var fc: Color = Color(0.95, 0.85, 0.2, 0.9) if fl < 2 else (Color(0.95, 0.5, 0.05, 0.85) if fl < 4 else Color(0.8, 0.2, 0.02, 0.7))
				draw_line(Vector2(flame_x, dpos.y + dsize * 0.1), Vector2(flame_x + sin(_time * 3.0 + float(fl)) * 3.0, dpos.y - flame_h), fc, 3.5 - float(fl) * 0.3)
			draw_circle(dpos + Vector2(0, -dsize * 0.1), dsize * 0.2, Color(1.0, 0.9, 0.4, 0.4 * fi))
			# cooking spit and pot
			draw_line(Vector2(dpos.x - dsize * 1.2, dpos.y + dsize * 0.2), Vector2(dpos.x - dsize * 1.2, dpos.y - dsize * 0.6), Color(0.2, 0.12, 0.04), 2.5)
			draw_line(Vector2(dpos.x + dsize * 1.2, dpos.y + dsize * 0.2), Vector2(dpos.x + dsize * 1.2, dpos.y - dsize * 0.6), Color(0.2, 0.12, 0.04), 2.5)
			draw_line(Vector2(dpos.x - dsize * 1.2, dpos.y - dsize * 0.6), Vector2(dpos.x + dsize * 1.2, dpos.y - dsize * 0.6), Color(0.2, 0.12, 0.04), 2.0)
			draw_arc(Vector2(dpos.x, dpos.y - dsize * 0.3), dsize * 0.2, 0, PI, 10, Color(0.12, 0.12, 0.12), 3.0)
			# smoke
			for sm in range(4):
				var smoke_t: float = fmod(_time * 0.8 + float(sm) * 0.7, 3.0)
				draw_circle(Vector2(dpos.x + sin(smoke_t * 2.0 + float(sm)) * 10.0, dpos.y - dsize * 0.8 - smoke_t * 30.0), 4.0 + smoke_t * 5.0, Color(0.4, 0.4, 0.45, clampf(0.25 - smoke_t * 0.08, 0.0, 0.25)))
			# sparks
			for sp in range(6):
				var spark_t: float = fmod(_time * 1.5 + float(sp) * 0.5, 2.0)
				draw_circle(Vector2(dpos.x + sin(spark_t * 3.0 + float(sp) * 2.0) * 15.0, dpos.y - dsize * 0.3 - spark_t * 40.0), 1.0, Color(1.0, 0.7, 0.1, clampf(0.8 - spark_t * 0.4, 0.0, 0.8)))

	# --- FOREGROUND TREE FRAMING ---
	draw_rect(Rect2(-10, 200, 35, 500), Color(0.06, 0.03, 0.01))
	draw_circle(Vector2(12, 180), 60.0, Color(0.02, 0.08, 0.02, 0.95))
	draw_circle(Vector2(-15, 210), 45.0, Color(0.02, 0.08, 0.02, 0.95))
	draw_line(Vector2(25, 250), Vector2(120, 200), Color(0.06, 0.03, 0.01), 5.0)
	draw_rect(Rect2(1258, 280, 30, 440), Color(0.06, 0.03, 0.01))
	draw_circle(Vector2(1270, 260), 50.0, Color(0.02, 0.08, 0.02, 0.95))

	# --- FIREFLIES ---
	for ff in range(18):
		var ff_phase: float = _time * 0.6 + float(ff) * 1.1
		var ff_x: float = 100.0 + fmod(float(ff) * 73.0, 1080.0) + sin(ff_phase) * 20.0
		var ff_y: float = 300.0 + fmod(float(ff) * 47.0, 250.0) + cos(ff_phase * 0.7) * 15.0
		var ff_alpha: float = clampf(0.5 + 0.5 * sin(ff_phase * 2.5), 0.0, 1.0)
		draw_circle(Vector2(ff_x, ff_y), 4.0, Color(0.9, 0.8, 0.2, ff_alpha * 0.3))
		draw_circle(Vector2(ff_x, ff_y), 1.5, Color(1.0, 0.95, 0.4, ff_alpha))

	# --- FALLING LEAVES ---
	for fl in range(8):
		var leaf_phase: float = fmod(_time * 0.3 + float(fl) * 2.5, 6.0)
		var leaf_x: float = 100.0 + fmod(float(fl) * 157.0, 1080.0) + sin(leaf_phase * 1.5) * 30.0 + leaf_phase * 8.0
		var leaf_y: float = 100.0 + leaf_phase * 85.0
		if leaf_y < 620.0:
			var leaf_cols: Array = [Color(0.7, 0.4, 0.05, 0.6), Color(0.6, 0.15, 0.05, 0.6), Color(0.65, 0.5, 0.1, 0.6)]
			draw_circle(Vector2(leaf_x + cos(leaf_phase * 3.0) * 3.0, leaf_y + sin(leaf_phase * 3.0) * 1.5), 2.5, leaf_cols[fl % 3])

	# --- WARM GLOW OVERLAY ---
	for dec3 in _decorations:
		if dec3["type"] == "campfire":
			var gp: Vector2 = dec3["pos"]
			var gpulse: float = 0.8 + 0.2 * sin(_time * 3.0)
			for gr in range(4):
				draw_circle(gp, 60.0 + float(gr) * 40.0, Color(0.9, 0.5, 0.1, (0.04 - float(gr) * 0.008) * gpulse))

	# --- BRANCHES OVER MOON ---
	draw_line(Vector2(870, 100), Vector2(940, 130), Color(0.02, 0.06, 0.02), 3.5)
	draw_line(Vector2(920, 90), Vector2(960, 140), Color(0.02, 0.06, 0.02), 2.5)
	draw_circle(Vector2(935, 125), 10.0, Color(0.02, 0.07, 0.02, 0.85))
	draw_circle(Vector2(955, 120), 8.0, Color(0.02, 0.07, 0.02, 0.8))

func _draw_alice_ch1(sky_color: Color, ground_color: Color) -> void:
	draw_rect(Rect2(0, 0, 1280, 720), sky_color)
	for y in range(50, 620, 4):
		var t = float(y - 50) / 570.0
		var sky_col = sky_color.lerp(ground_color, t * t)
		draw_line(Vector2(0, y), Vector2(1280, y), Color(sky_col.r, sky_col.g, sky_col.b, 0.6), 4.0)
	# Oversized moon
	var moon_pos = Vector2(1000, 100)
	draw_circle(moon_pos, 55, Color(0.85, 0.7, 0.9, 0.3))
	draw_circle(moon_pos, 45, Color(0.9, 0.75, 0.95, 0.45))
	draw_circle(moon_pos, 35, Color(0.95, 0.82, 0.98, 0.55))
	draw_arc(moon_pos, 50.0 + sin(_time * 0.5) * 3.0, 0, TAU, 48, Color(0.9, 0.75, 0.95, 0.1), 2.0)
	# Cheshire Cat grin
	var grin_alpha = (sin(_time * 0.7) + 1.0) * 0.5
	if grin_alpha > 0.15:
		var gc = Vector2(950, 350) + Vector2(sin(_time * 0.3) * 5.0, cos(_time * 0.4) * 3.0)
		draw_arc(gc, 20.0, 0.1, PI - 0.1, 16, Color(0.9, 0.3, 0.8, grin_alpha * 0.6), 2.5)
		for i in range(7):
			var tooth_a = 0.2 + float(i) * 0.37
			draw_line(gc + Vector2.from_angle(tooth_a) * 18.0, gc + Vector2.from_angle(tooth_a) * 22.0, Color(0.95, 0.95, 0.9, grin_alpha * 0.5), 1.5)
		draw_circle(gc + Vector2(-12, -18), 5.0, Color(0.8, 0.9, 0.1, grin_alpha * 0.7))
		draw_circle(gc + Vector2(12, -18), 5.0, Color(0.8, 0.9, 0.1, grin_alpha * 0.7))
		draw_circle(gc + Vector2(-12, -18), 2.0, Color(0.1, 0.05, 0.2, grin_alpha * 0.7))
		draw_circle(gc + Vector2(12, -18), 2.0, Color(0.1, 0.05, 0.2, grin_alpha * 0.7))
	# Checkerboard patches
	for i in range(12):
		var cx = float(i) * 110.0 + 20.0
		for j in range(6):
			var cy = 380.0 + float(j) * 40.0
			var is_white = (i + j) % 2 == 0
			var tc = Color(0.85, 0.82, 0.78, 0.08) if is_white else Color(0.05, 0.04, 0.06, 0.1)
			draw_rect(Rect2(cx, cy, 40, 40), tc)
	# Decorations
	for dec in _decorations:
		match dec["type"]:
			"giant_mushroom":
				var mp = dec["pos"]
				var ms = dec["size"]
				var glow_pulse = (sin(_time * 1.5 + dec["extra"]) + 1.0) * 0.5
				draw_rect(Rect2(mp.x - ms * 0.8, mp.y - ms * 4.0, ms * 1.6, ms * 4.0), Color(0.85, 0.8, 0.7, 0.5))
				var cap_center = mp + Vector2(0, -ms * 4.5)
				draw_circle(cap_center, ms * 3.0 + 4.0, Color(0.7, 0.2, 0.8, 0.1 + glow_pulse * 0.08))
				draw_circle(cap_center, ms * 3.0, Color(0.8, 0.25, 0.4, 0.5))
				draw_circle(cap_center + Vector2(-ms, -ms * 0.5), ms * 0.5, Color(1, 0.95, 0.85, 0.4))
			"floating_card":
				var cp = dec["pos"]
				var drift_y = sin(_time * 0.8 + dec["extra"]) * 15.0
				var drift_x = cos(_time * 0.5 + dec["extra"]) * 8.0
				var card_pos = cp + Vector2(drift_x, drift_y)
				draw_rect(Rect2(card_pos.x - 4, card_pos.y - 6, 8, 12), Color(1.0, 0.98, 0.9, 0.25))
				var suit_col = Color(0.8, 0.15, 0.15, 0.35) if dec["extra"] > 3.0 else Color(0.1, 0.1, 0.1, 0.35)
				draw_circle(card_pos, 2.0, suit_col)
			"rose":
				var rp = dec["pos"]
				var sway = sin(_time * 1.2 + dec["extra"]) * 2.0
				draw_line(rp, rp + Vector2(sway, -12), Color(0.15, 0.4, 0.1, 0.45), 1.5)
				var bloom = rp + Vector2(sway, -12)
				var rc = Color(0.85, 0.1, 0.15, 0.5) if dec["extra"] < 0.5 else Color(0.95, 0.9, 0.85, 0.5)
				draw_circle(bloom, dec["size"], rc)
			"teacup":
				var tp = dec["pos"]
				draw_rect(Rect2(tp.x - 4, tp.y - 5, 8, 6), Color(0.8, 0.75, 0.6, 0.4))
				draw_arc(Vector2(tp.x + 5, tp.y - 2), 3, -PI * 0.5, PI * 0.5, 6, Color(0.8, 0.75, 0.6, 0.35), 1.0)
	# Path (mosaic tile road)
	var curve = enemy_path.curve
	if curve and curve.point_count > 1:
		var points = curve.get_baked_points()
		for i in range(points.size() - 1):
			draw_line(points[i], points[i + 1], Color(0.15, 0.08, 0.18), 52.0)
		for i in range(points.size() - 1):
			draw_line(points[i], points[i + 1], Color(0.55, 0.4, 0.6), 44.0)
		for i in range(0, points.size() - 1, 8):
			var tile_alt = (i / 8) % 2 == 0
			var tc = Color(0.7, 0.5, 0.75, 0.35) if tile_alt else Color(0.45, 0.3, 0.55, 0.35)
			draw_rect(Rect2(points[i].x - 4, points[i].y - 4, 8, 8), tc)
		for i in range(points.size() - 1):
			draw_line(points[i], points[i + 1], Color(0.7, 0.55, 0.75, 0.2), 12.0)
	# Foreground haze
	for i in range(6):
		draw_circle(Vector2(float(i) * 220.0 + sin(_time * 0.3 + float(i)) * 30.0, 580.0), 60.0, Color(0.6, 0.3, 0.7, 0.03))

func _draw_oz_ch1(sky_color: Color, ground_color: Color) -> void:
	draw_rect(Rect2(0, 0, 1280, 720), sky_color)
	for y in range(50, 620, 4):
		var t = float(y - 50) / 570.0
		var sky_col = sky_color.lerp(ground_color, t * t)
		draw_line(Vector2(0, y), Vector2(1280, y), Color(sky_col.r, sky_col.g, sky_col.b, 0.6), 4.0)
	# Tornado funnel in distance
	var tornado_x = 1100.0 + sin(_time * 0.3) * 15.0
	for i in range(20):
		var t = float(i) / 19.0
		var y_pos = lerp(400.0, 60.0, t)
		var width = lerp(50.0, 8.0, t)
		var sway = sin(_time * 2.0 + t * 4.0) * (10.0 * (1.0 - t))
		draw_line(Vector2(tornado_x + sway - width, y_pos), Vector2(tornado_x + sway + width, y_pos), Color(0.25, 0.28, 0.2, 0.08 + t * 0.06), 3.0)
	# Emerald City silhouette
	var city_x = 300.0
	var city_base_y = 180.0
	draw_rect(Rect2(city_x - 70, city_base_y, 140, 20), Color(0.1, 0.3, 0.12, 0.35))
	var towers_data = [{"x": -50.0, "h": 80.0, "w": 14.0}, {"x": -25.0, "h": 110.0, "w": 16.0}, {"x": 0.0, "h": 140.0, "w": 20.0}, {"x": 25.0, "h": 100.0, "w": 15.0}, {"x": 50.0, "h": 70.0, "w": 12.0}]
	for td in towers_data:
		var tx = city_x + td["x"]
		var tw = td["w"]
		var th = td["h"]
		draw_rect(Rect2(tx - tw * 0.5, city_base_y - th, tw, th), Color(0.12, 0.35, 0.15, 0.4))
		draw_colored_polygon(PackedVector2Array([Vector2(tx - tw * 0.5, city_base_y - th), Vector2(tx + tw * 0.5, city_base_y - th), Vector2(tx, city_base_y - th - 20)]), Color(0.1, 0.4, 0.15, 0.45))
	for i in range(8):
		var sparkle = (sin(_time * 3.0 + float(i) * 1.7) + 1.0) * 0.5
		if sparkle > 0.6:
			draw_circle(Vector2(city_x - 55.0 + float(i) * 15.0, city_base_y - 30.0 - float(i % 3) * 35.0), 1.5, Color(0.4, 1.0, 0.5, sparkle * 0.5))
	draw_circle(Vector2(city_x, city_base_y - 50), 80.0, Color(0.15, 0.5, 0.2, 0.04 + sin(_time) * 0.015))
	# Ground terrain
	draw_rect(Rect2(0, 440, 1280, 190), Color(0.12, 0.22, 0.06, 0.3))
	draw_rect(Rect2(0, 520, 1280, 110), Color(0.1, 0.18, 0.04, 0.25))
	# Decorations
	for dec in _decorations:
		match dec["type"]:
			"poppy":
				var pp = dec["pos"]
				var ps = dec["size"]
				var sway = sin(_time * 1.3 + dec["extra"]) * 2.0
				draw_line(pp, pp + Vector2(sway, -ps * 6.0), Color(0.15, 0.35, 0.1, 0.5), 1.0)
				draw_circle(pp + Vector2(sway, -ps * 6.0), ps * 2.5, Color(0.85, 0.12, 0.1, 0.55))
				draw_circle(pp + Vector2(sway, -ps * 6.0), ps * 0.7, Color(0.15, 0.1, 0.05, 0.5))
			"emerald_crystal":
				var ep = dec["pos"]
				var es = dec["size"]
				var sparkle = (sin(_time * 2.0 + dec["extra"]) + 1.0) * 0.5
				draw_colored_polygon(PackedVector2Array([ep + Vector2(0, -es * 2), ep + Vector2(es, 0), ep + Vector2(0, es), ep + Vector2(-es, 0)]), Color(0.2, 0.8, 0.3, 0.4 + sparkle * 0.15))
			"scarecrow":
				var sp = dec["pos"]
				var ss = dec["size"]
				draw_line(sp, sp + Vector2(0, -ss * 2), Color(0.4, 0.3, 0.15, 0.5), 2.0)
				draw_line(sp + Vector2(-ss, -ss * 1.5), sp + Vector2(ss, -ss * 1.5), Color(0.4, 0.3, 0.15, 0.5), 2.0)
				draw_circle(sp + Vector2(0, -ss * 2.2), ss * 0.5, Color(0.6, 0.5, 0.2, 0.45))
	# Path (yellow brick road)
	var curve = enemy_path.curve
	if curve and curve.point_count > 1:
		var points = curve.get_baked_points()
		for i in range(points.size() - 1):
			draw_line(points[i], points[i + 1], Color(0.2, 0.15, 0.05), 52.0)
		for i in range(points.size() - 1):
			draw_line(points[i], points[i + 1], Color(0.75, 0.6, 0.15), 44.0)
		for i in range(0, points.size() - 1, 10):
			var bright = Color(0.85, 0.72, 0.2, 0.4)
			var dark = Color(0.65, 0.5, 0.1, 0.35)
			if (i / 10) % 2 == 0:
				draw_rect(Rect2(points[i].x - 8, points[i].y - 10, 16, 9), bright)
				draw_rect(Rect2(points[i].x - 8, points[i].y + 1, 16, 9), dark)
			else:
				draw_rect(Rect2(points[i].x - 8, points[i].y - 10, 16, 9), dark)
				draw_rect(Rect2(points[i].x - 8, points[i].y + 1, 16, 9), bright)
		for i in range(0, points.size() - 1, 30):
			var shimmer = (sin(_time * 2.0 + float(i) * 0.5) + 1.0) * 0.5
			if shimmer > 0.7:
				draw_circle(points[i], 3.0, Color(1.0, 0.95, 0.5, shimmer * 0.2))

func _draw_peter_ch1(sky_color: Color, ground_color: Color) -> void:
	draw_rect(Rect2(0, 0, 1280, 720), sky_color)
	for y in range(50, 620, 4):
		var t = float(y - 50) / 570.0
		var sky_col = sky_color.lerp(ground_color, t * t)
		draw_line(Vector2(0, y), Vector2(1280, y), Color(sky_col.r, sky_col.g, sky_col.b, 0.6), 4.0)
	# Stars
	for dec in _decorations:
		if dec["type"] == "star":
			var twinkle = (sin(_time * 2.0 + dec["extra"]) + 1.0) * 0.5
			var alpha = dec["size"] * (0.4 + twinkle * 0.6)
			draw_circle(dec["pos"], 1.0 + twinkle * 0.8, Color(1.0, 0.97, 0.8, alpha))
	# Second star to the right
	var second_star = Vector2(980, 72)
	var ss_twinkle = (sin(_time * 1.5) + 1.0) * 0.5
	draw_circle(second_star, 3.0 + ss_twinkle, Color(1.0, 0.95, 0.6, 0.9))
	draw_circle(second_star, 6.0 + ss_twinkle * 2.0, Color(1.0, 0.95, 0.6, 0.15))
	for a in [0, PI / 2.0, PI / 4.0, -PI / 4.0]:
		var ray = Vector2.from_angle(a) * (5.0 + ss_twinkle * 3.0)
		draw_line(second_star - ray, second_star + ray, Color(1.0, 0.95, 0.7, 0.25), 1.0)
	# Moon
	draw_circle(Vector2(180, 90), 28, Color(0.9, 0.88, 0.7, 0.7))
	draw_circle(Vector2(190, 84), 24, Color(0.04, 0.06, 0.14))
	# Mermaid Lagoon
	var lagoon_center = Vector2(1050, 500)
	draw_circle(lagoon_center, 70, Color(0.1, 0.35, 0.45, 0.5))
	draw_circle(lagoon_center, 60, Color(0.15, 0.45, 0.55, 0.4))
	draw_circle(lagoon_center, 45, Color(0.2, 0.55, 0.65, 0.35))
	for i in range(3):
		draw_arc(lagoon_center, 30.0 + float(i) * 15.0 + sin(_time * 0.8 + float(i)) * 3.0, 0, TAU, 24, Color(0.4, 0.7, 0.8, 0.12), 1.0)
	# Skull Rock
	var skull_pos = Vector2(100, 480)
	draw_circle(skull_pos, 22, Color(0.3, 0.28, 0.25))
	draw_circle(skull_pos, 18, Color(0.38, 0.35, 0.3))
	draw_circle(skull_pos + Vector2(-5, -4), 4, Color(0.12, 0.1, 0.08))
	draw_circle(skull_pos + Vector2(5, -4), 4, Color(0.12, 0.1, 0.08))
	for i in range(5):
		draw_line(Vector2(skull_pos.x - 5.0 + float(i) * 2.5, skull_pos.y + 7), Vector2(skull_pos.x - 5.0 + float(i) * 2.5, skull_pos.y + 11), Color(0.35, 0.32, 0.28), 1.5)
	# Jolly Roger
	var ship_x = 850.0
	var ship_y = 110.0
	draw_colored_polygon(PackedVector2Array([Vector2(ship_x - 40, ship_y), Vector2(ship_x + 40, ship_y), Vector2(ship_x + 30, ship_y + 12), Vector2(ship_x - 30, ship_y + 12)]), Color(0.12, 0.08, 0.06, 0.5))
	draw_line(Vector2(ship_x, ship_y), Vector2(ship_x, ship_y - 35), Color(0.15, 0.1, 0.08, 0.5), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(ship_x, ship_y - 30), Vector2(ship_x + 20, ship_y - 20), Vector2(ship_x, ship_y - 8)]), Color(0.2, 0.15, 0.12, 0.35))
	# Ground cover
	draw_rect(Rect2(0, 400, 1280, 230), Color(0.08, 0.2, 0.06, 0.3))
	draw_rect(Rect2(0, 500, 1280, 130), Color(0.06, 0.16, 0.04, 0.2))
	# Decorations
	for dec in _decorations:
		match dec["type"]:
			"mushroom":
				var mp = dec["pos"]
				var ms = dec["size"]
				var mh = dec["extra"]
				draw_line(mp, mp + Vector2(0, -ms * 1.5), Color(0.85, 0.82, 0.7), ms * 0.4)
				var cap_col = Color(0.8, 0.2, 0.15, 0.7) if mh < 0.33 else (Color(0.7, 0.5, 0.15, 0.7) if mh < 0.66 else Color(0.6, 0.2, 0.6, 0.7))
				draw_circle(mp + Vector2(0, -ms * 1.5), ms, cap_col)
				draw_circle(mp + Vector2(-ms * 0.3, -ms * 1.7), ms * 0.2, Color(1, 1, 1, 0.5))
			"jungle_tree":
				var tp = dec["pos"]
				var cr = dec["size"]
				var sh = dec["extra"]
				var th = cr * 0.8
				draw_line(tp, tp + Vector2(0, -th), Color(0.3 + sh, 0.2 + sh, 0.08), 3.0 + cr * 0.1)
				draw_circle(tp + Vector2(0, -th), cr, Color(0.1 + sh, 0.35 + sh, 0.08 + sh * 0.5, 0.55))
				draw_circle(tp + Vector2(-cr * 0.4, -th + cr * 0.2), cr * 0.6, Color(0.12 + sh, 0.37 + sh, 0.1, 0.5))
				if cr > 20:
					draw_line(tp + Vector2(-cr * 0.3, -th + cr * 0.5), tp + Vector2(-cr * 0.4, -th + cr + 8), Color(0.15, 0.4, 0.1, 0.3), 1.0)
			"fairy":
				var fp = dec["pos"]
				var fo = dec["extra"]
				var drift = Vector2(sin(_time * 1.2 + fo) * 8.0, cos(_time * 0.9 + fo) * 5.0)
				var pulse = (sin(_time * 3.0 + fo) + 1.0) * 0.5
				draw_circle(fp + drift, 1.5 + pulse, Color(1.0, 0.92, 0.3, 0.5 + pulse * 0.3))
				draw_circle(fp + drift, 4.0 + pulse * 2.0, Color(1.0, 0.9, 0.3, 0.08 + pulse * 0.06))
	# Underground Home
	var tree_home = Vector2(1180, 350)
	draw_rect(Rect2(tree_home.x - 16, tree_home.y - 60, 32, 80), Color(0.3, 0.18, 0.08))
	draw_rect(Rect2(tree_home.x - 12, tree_home.y - 55, 24, 70), Color(0.38, 0.24, 0.1))
	draw_circle(tree_home + Vector2(0, 5), 7, Color(0.12, 0.08, 0.04))
	draw_circle(tree_home + Vector2(0, -65), 35, Color(0.12, 0.35, 0.08, 0.7))
	draw_circle(tree_home + Vector2(-18, -55), 22, Color(0.14, 0.38, 0.1, 0.6))
	draw_circle(tree_home + Vector2(18, -55), 22, Color(0.1, 0.32, 0.07, 0.6))
	# Path (jungle trail)
	var curve = enemy_path.curve
	if curve and curve.point_count > 1:
		var points = curve.get_baked_points()
		for i in range(points.size() - 1):
			draw_line(points[i], points[i + 1], Color(0.15, 0.1, 0.05), 52.0)
		for i in range(points.size() - 1):
			draw_line(points[i], points[i + 1], Color(0.35, 0.22, 0.1), 44.0)
		for i in range(points.size() - 1):
			draw_line(points[i], points[i + 1], Color(0.45, 0.32, 0.16, 0.5), 24.0)

func _draw_phantom_ch1(sky_color: Color, ground_color: Color) -> void:
	draw_rect(Rect2(0, 0, 1280, 720), sky_color)
	for y in range(50, 620, 4):
		var t = float(y - 50) / 570.0
		var sky_col = sky_color.lerp(ground_color, t * t)
		draw_line(Vector2(0, y), Vector2(1280, y), Color(sky_col.r, sky_col.g, sky_col.b, 0.6), 4.0)
	# Organ pipes silhouette
	var organ_x = 640.0
	var pipe_widths = [6, 8, 10, 12, 14, 14, 12, 10, 8, 6]
	var pipe_heights = [80, 100, 120, 145, 160, 155, 140, 115, 95, 75]
	var pipe_x = organ_x - 55.0
	for i in range(pipe_widths.size()):
		draw_rect(Rect2(pipe_x, 100.0 - pipe_heights[i], pipe_widths[i], pipe_heights[i]), Color(0.12, 0.06, 0.08, 0.5))
		draw_rect(Rect2(pipe_x - 1, 100.0 - pipe_heights[i] - 3, pipe_widths[i] + 2, 4), Color(0.25, 0.15, 0.1, 0.45))
		pipe_x += float(pipe_widths[i]) + 3.0
	# Red velvet curtains
	for i in range(8):
		var cx = 10.0 + float(i) * 8.0
		var fold = sin(float(i) * 1.2) * 4.0
		draw_line(Vector2(cx + fold, 50), Vector2(cx + fold * 0.5, 620), Color(0.35, 0.04, 0.06, 0.55 - float(i) * 0.05), 8.0)
	for i in range(8):
		var cx = 1270.0 - float(i) * 8.0
		var fold = sin(float(i) * 1.2) * 4.0
		draw_line(Vector2(cx - fold, 50), Vector2(cx - fold * 0.5, 620), Color(0.35, 0.04, 0.06, 0.55 - float(i) * 0.05), 8.0)
	draw_circle(Vector2(85, 200), 6, Color(0.85, 0.65, 0.1, 0.5))
	draw_circle(Vector2(1195, 200), 6, Color(0.85, 0.65, 0.1, 0.5))
	# Grand chandelier
	var chandelier_sway = sin(_time * 0.6) * 8.0
	var ch_center = Vector2(640 + chandelier_sway, 80)
	draw_line(Vector2(640, 50), ch_center, Color(0.7, 0.55, 0.15, 0.5), 2.0)
	draw_arc(ch_center, 35, 0, TAU, 24, Color(0.8, 0.65, 0.15, 0.5), 2.5)
	for i in range(8):
		var angle = float(i) * TAU / 8.0 + _time * 0.1
		var arm_end = ch_center + Vector2.from_angle(angle) * 35.0
		draw_line(ch_center + Vector2.from_angle(angle) * 28.0, arm_end, Color(0.8, 0.65, 0.15, 0.45), 1.5)
		var flicker = sin(_time * 5.0 + float(i) * 2.0) * 0.15
		draw_circle(arm_end + Vector2(0, -3), 2.5 + flicker, Color(1.0, 0.8, 0.2, 0.6 + flicker))
	for i in range(12):
		var angle = float(i) * TAU / 12.0
		var crystal_pos = ch_center + Vector2.from_angle(angle) * 22.0 + Vector2(0, 8)
		var sparkle = (sin(_time * 4.0 + float(i) * 1.5) + 1.0) * 0.5
		draw_line(crystal_pos, crystal_pos + Vector2(0, 6 + sparkle * 3), Color(0.9, 0.85, 1.0, 0.2 + sparkle * 0.2), 1.0)
	# Underground lake
	draw_rect(Rect2(0, 560, 1280, 68), Color(0.03, 0.02, 0.06, 0.7))
	for i in range(32):
		var wave_y = 560.0 + sin(_time * 1.2 + float(i) * 0.8) * 2.0
		draw_line(Vector2(float(i) * 42.0, wave_y), Vector2(float(i) * 42.0 + 42, wave_y + sin(_time * 1.2 + float(i + 1) * 0.8) * 2.0), Color(0.15, 0.1, 0.25, 0.3), 1.5)
	draw_circle(Vector2(640 + chandelier_sway, 585), 30, Color(0.3, 0.2, 0.05, 0.06))
	# Decorations
	for dec in _decorations:
		match dec["type"]:
			"candelabra":
				var cp = dec["pos"]
				var cs = dec["size"]
				draw_line(cp, cp + Vector2(0, -cs * 12.0), Color(0.6, 0.45, 0.1, 0.5), 2.5)
				draw_line(cp + Vector2(-cs * 3, 0), cp + Vector2(cs * 3, 0), Color(0.6, 0.45, 0.1, 0.45), 2.0)
				var arm_top = cp + Vector2(0, -cs * 12.0)
				draw_line(arm_top, arm_top + Vector2(-cs * 5, -cs * 3), Color(0.6, 0.45, 0.1, 0.45), 1.5)
				draw_line(arm_top, arm_top + Vector2(cs * 5, -cs * 3), Color(0.6, 0.45, 0.1, 0.45), 1.5)
				var flames = [arm_top + Vector2(0, -cs * 2), arm_top + Vector2(-cs * 5, -cs * 5), arm_top + Vector2(cs * 5, -cs * 5)]
				for fi in range(flames.size()):
					var flicker = sin(_time * 5.5 + dec["extra"] + float(fi) * 1.7) * 0.2
					draw_circle(flames[fi], 2.5 + flicker, Color(1.0, 0.75, 0.15, 0.6 + flicker))
					draw_circle(flames[fi], 18.0, Color(1.0, 0.6, 0.1, 0.02))
			"mirror":
				var mp = dec["pos"]
				var ms = dec["size"]
				draw_rect(Rect2(mp.x - ms * 8 - 3, mp.y - ms * 12 - 3, ms * 16 + 6, ms * 24 + 6), Color(0.8, 0.6, 0.1, 0.45))
				draw_rect(Rect2(mp.x - ms * 8, mp.y - ms * 12, ms * 16, ms * 24), Color(0.08, 0.05, 0.12, 0.7))
				var shimmer = (sin(_time * 1.5 + dec["extra"]) + 1.0) * 0.5
				draw_rect(Rect2(mp.x - ms * 5, mp.y - ms * 8, ms * 3, ms * 16), Color(0.4, 0.35, 0.5, shimmer * 0.1))
			"rose":
				var rp = dec["pos"]
				draw_circle(rp, dec["size"], Color(0.85, 0.1, 0.1, 0.5))
				draw_circle(rp, dec["size"] * 0.5, Color(0.95, 0.2, 0.15, 0.4))
	# Path (stone floor with red carpet)
	var curve = enemy_path.curve
	if curve and curve.point_count > 1:
		var points = curve.get_baked_points()
		for i in range(points.size() - 1):
			draw_line(points[i], points[i + 1], Color(0.15, 0.1, 0.08), 54.0)
		for i in range(points.size() - 1):
			draw_line(points[i], points[i + 1], Color(0.25, 0.2, 0.18), 46.0)
		for i in range(points.size() - 1):
			draw_line(points[i], points[i + 1], Color(0.5, 0.06, 0.08, 0.55), 24.0)
		for i in range(points.size() - 1):
			if i + 1 < points.size():
				var dir = (points[i + 1] - points[i]).normalized()
				var perp = Vector2(-dir.y, dir.x)
				draw_line(points[i] + perp * 12, points[i + 1] + perp * 12, Color(0.8, 0.6, 0.1, 0.18), 1.5)
				draw_line(points[i] - perp * 12, points[i + 1] - perp * 12, Color(0.8, 0.6, 0.1, 0.18), 1.5)
		for i in range(0, points.size() - 1, 24):
			draw_colored_polygon(PackedVector2Array([points[i] + Vector2(0, -5), points[i] + Vector2(4, 0), points[i] + Vector2(0, 5), points[i] + Vector2(-4, 0)]), Color(0.85, 0.65, 0.1, 0.2))

func _draw_scrooge_ch1(sky_color: Color, ground_color: Color) -> void:
	draw_rect(Rect2(0, 0, 1280, 720), sky_color)
	for y in range(50, 620, 4):
		var t = float(y - 50) / 570.0
		var sky_col = sky_color.lerp(ground_color, t * t)
		draw_line(Vector2(0, y), Vector2(1280, y), Color(sky_col.r, sky_col.g, sky_col.b, 0.6), 4.0)
	# Fog layers
	for i in range(6):
		var fog_y = 200.0 + float(i) * 70.0
		draw_rect(Rect2(-20 + sin(_time * 0.15 + float(i) * 1.5) * 40.0, fog_y, 1320, 30), Color(0.4, 0.42, 0.5, 0.04))
	# Victorian building silhouettes
	var bldg_data = [{"x": 50.0, "w": 100.0, "h": 150.0}, {"x": 155.0, "w": 80.0, "h": 130.0}, {"x": 240.0, "w": 110.0, "h": 170.0}, {"x": 360.0, "w": 90.0, "h": 140.0}, {"x": 460.0, "w": 70.0, "h": 120.0}, {"x": 750.0, "w": 100.0, "h": 155.0}, {"x": 860.0, "w": 85.0, "h": 135.0}, {"x": 950.0, "w": 110.0, "h": 165.0}, {"x": 1070.0, "w": 95.0, "h": 145.0}, {"x": 1170.0, "w": 80.0, "h": 125.0}]
	var bldg_base_y = 340.0
	for bd in bldg_data:
		var bx = bd["x"]
		var bw = bd["w"]
		var bh = bd["h"]
		draw_rect(Rect2(bx, bldg_base_y - bh, bw, bh), Color(0.06, 0.06, 0.08, 0.6))
		draw_colored_polygon(PackedVector2Array([Vector2(bx - 3, bldg_base_y - bh), Vector2(bx + bw + 3, bldg_base_y - bh), Vector2(bx + bw * 0.5, bldg_base_y - bh - 15)]), Color(0.07, 0.06, 0.09, 0.55))
		for wy in range(3):
			for wx_off in range(3):
				var win_x = bx + 10.0 + float(wx_off) * (bw - 20.0) / 2.0
				var win_y = bldg_base_y - bh + 20.0 + float(wy) * 35.0
				if win_y < bldg_base_y - 10:
					var lit = sin(float(int(bx) + wx_off * 7 + wy * 13) * 0.5) > 0
					draw_rect(Rect2(win_x, win_y, 8, 10), Color(0.7, 0.55, 0.2, 0.2) if lit else Color(0.04, 0.04, 0.06, 0.4))
		var ch_x = bx + bw * 0.3
		draw_rect(Rect2(ch_x, bldg_base_y - bh - 25, 8, 20), Color(0.08, 0.07, 0.09, 0.55))
		for sc in range(3):
			draw_circle(Vector2(ch_x + 4.0 + sin(_time * 0.5 + bd["x"] * 0.01 + float(sc)) * 5.0, bldg_base_y - bh - 28.0 - float(sc) * 12.0), 5.0 + float(sc) * 3.0, Color(0.4, 0.4, 0.45, 0.08 - float(sc) * 0.02))
	# Church steeple
	var church_x = 620.0
	draw_rect(Rect2(church_x - 18, bldg_base_y - 200, 36, 200), Color(0.07, 0.06, 0.09, 0.65))
	draw_colored_polygon(PackedVector2Array([Vector2(church_x - 20, bldg_base_y - 200), Vector2(church_x + 20, bldg_base_y - 200), Vector2(church_x, bldg_base_y - 260)]), Color(0.06, 0.05, 0.08, 0.6))
	draw_line(Vector2(church_x, bldg_base_y - 260), Vector2(church_x, bldg_base_y - 275), Color(0.3, 0.28, 0.25, 0.45), 2.0)
	draw_line(Vector2(church_x - 6, bldg_base_y - 268), Vector2(church_x + 6, bldg_base_y - 268), Color(0.3, 0.28, 0.25, 0.45), 2.0)
	# Clock face
	var clock_center = Vector2(church_x, bldg_base_y - 170)
	draw_circle(clock_center, 12, Color(0.75, 0.7, 0.6, 0.4))
	draw_circle(clock_center, 10, Color(0.15, 0.12, 0.1, 0.5))
	draw_line(clock_center, clock_center + Vector2(0, -8), Color(0.85, 0.8, 0.6, 0.5), 1.5)
	draw_line(clock_center, clock_center + Vector2(0, -9.5), Color(0.85, 0.8, 0.6, 0.4), 1.0)
	# Thames river
	var river_y = 555.0
	draw_rect(Rect2(0, river_y, 1280, 73), Color(0.04, 0.05, 0.08, 0.65))
	for i in range(24):
		var ry = river_y + 10.0 + sin(_time * 0.8 + float(i) * 0.6) * 2.0
		draw_line(Vector2(float(i) * 56.0, ry), Vector2(float(i) * 56.0 + 56, ry + sin(_time * 0.8 + float(i + 1) * 0.6) * 2.0), Color(0.15, 0.18, 0.25, 0.2), 1.0)
	# Ground
	draw_rect(Rect2(0, bldg_base_y, 1280, river_y - bldg_base_y), Color(ground_color.r, ground_color.g, ground_color.b, 0.35))
	for i in range(40):
		draw_circle(Vector2(float(i) * 33.0 + sin(float(i) * 2.3) * 10.0, bldg_base_y + 5.0), 12.0, Color(0.8, 0.82, 0.88, 0.06))
	# Snowflakes
	for i in range(30):
		var sx = fmod(float(i) * 43.7 + sin(_time * 0.6 + float(i)) * 20.0, 1280.0)
		var sy = fmod(_time * 15.0 * (0.5 + fmod(float(i) * 0.3, 1.0)) + float(i) * 50.0, 620.0) + 50.0
		draw_circle(Vector2(sx, sy), 1.5 + fmod(float(i) * 0.7, 1.0), Color(0.9, 0.92, 0.95, 0.3))
	# Decorations
	for dec in _decorations:
		match dec["type"]:
			"lamp_post":
				var lp = dec["pos"]
				var ls = dec["size"]
				draw_line(lp, lp + Vector2(0, -ls * 1.4), Color(0.15, 0.12, 0.1, 0.6), 3.0)
				var lamp_top = lp + Vector2(0, -ls * 1.4)
				draw_rect(Rect2(lamp_top.x - ls * 0.2, lamp_top.y - ls * 0.4, ls * 0.4, ls * 0.4), Color(0.18, 0.14, 0.1, 0.5))
				var flicker = sin(_time * 6.0 + dec["extra"]) * 0.15
				draw_circle(lamp_top + Vector2(0, -ls * 0.2), ls * 0.15 + flicker, Color(1.0, 0.75, 0.2, 0.55 + flicker))
				draw_circle(lamp_top + Vector2(0, -ls * 0.2), ls * 0.8, Color(1.0, 0.7, 0.2, 0.04))
			"bare_tree":
				var tp = dec["pos"]
				var ts = dec["size"]
				var sh = dec["extra"]
				draw_line(tp, tp + Vector2(0, -ts * 1.4), Color(0.12, 0.1, 0.08, 0.5), 3.0)
				var branch_base = tp + Vector2(0, -ts * 1.4)
				for b in range(4):
					var b_angle = -PI * 0.6 + float(b) * 0.4 + sin(float(int(sh * 100) + b)) * 0.2
					var b_len = ts * (0.6 + float(b) * 0.2)
					draw_line(branch_base + Vector2(0, float(b) * ts * 0.2), branch_base + Vector2(0, float(b) * ts * 0.2) + Vector2.from_angle(b_angle) * b_len, Color(0.12, 0.1, 0.08, 0.4), 1.5)
			"snow_pile":
				draw_circle(dec["pos"], dec["size"], Color(0.85, 0.87, 0.9, 0.15))
				draw_circle(dec["pos"] + Vector2(dec["size"] * 0.3, -dec["size"] * 0.2), dec["size"] * 0.7, Color(0.88, 0.9, 0.92, 0.12))
			"chimney":
				var cp = dec["pos"]
				var cs = dec["size"]
				draw_rect(Rect2(cp.x - cs * 0.4, cp.y - cs * 2, cs * 0.8, cs * 2), Color(0.15, 0.12, 0.1, 0.4))
				var cf = sin(_time * 0.5 + dec["extra"]) * 4.0
				draw_circle(Vector2(cp.x + cf, cp.y - cs * 2.2), 4.0, Color(0.4, 0.4, 0.45, 0.06))
	# Path (cobblestone)
	var curve = enemy_path.curve
	if curve and curve.point_count > 1:
		var points = curve.get_baked_points()
		for i in range(points.size() - 1):
			draw_line(points[i], points[i + 1], Color(0.08, 0.08, 0.1), 54.0)
		for i in range(points.size() - 1):
			draw_line(points[i], points[i + 1], Color(0.22, 0.2, 0.22), 46.0)
		for i in range(0, points.size() - 1, 8):
			if i + 1 < points.size():
				var dir = (points[i + 1] - points[i]).normalized()
				var perp = Vector2(-dir.y, dir.x)
				for j in range(-2, 3):
					var stone_x = points[i] + perp * float(j) * 9.0 + dir * float((i / 8) % 2) * 4.0
					var stone_shade = 0.18 + sin(float(i + j * 37) * 0.7) * 0.04
					draw_rect(Rect2(stone_x.x - 3.5, stone_x.y - 3.5, 7, 7), Color(stone_shade, stone_shade, stone_shade + 0.02, 0.4))
		for i in range(0, points.size() - 1, 20):
			draw_circle(points[i] + Vector2(6, -3), 4.0, Color(0.85, 0.87, 0.9, 0.12))
		for i in range(points.size() - 1):
			draw_line(points[i], points[i + 1], Color(0.28, 0.26, 0.28, 0.18), 16.0)

func _on_tower_pressed(tower_type: TowerType, desc: String) -> void:
	_deselect_tower()
	if purchased_towers.has(tower_type):
		info_label.text = "%s is already placed!" % tower_info[tower_type]["name"]
		return
	selected_tower = tower_type
	placing_tower = true
	info_label.text = desc

func _find_tower_at(pos: Vector2) -> Node2D:
	var closest: Node2D = null
	var closest_dist: float = TOWER_SELECT_RADIUS
	for tower in get_tree().get_nodes_in_group("towers"):
		var dist = pos.distance_to(tower.global_position)
		if dist < closest_dist:
			closest = tower
			closest_dist = dist
	return closest

func _select_tower(tower: Node2D) -> void:
	_deselect_tower()
	selected_tower_node = tower
	tower.is_selected = true
	_update_upgrade_panel()

func _deselect_tower() -> void:
	if selected_tower_node and is_instance_valid(selected_tower_node):
		selected_tower_node.is_selected = false
	selected_tower_node = null
	_hide_upgrade_panel()

func _update_upgrade_panel() -> void:
	if not selected_tower_node or not is_instance_valid(selected_tower_node):
		_hide_upgrade_panel()
		return
	var tower = selected_tower_node
	var display_name = tower.get_tower_display_name() if tower.has_method("get_tower_display_name") else "Tower"
	upgrade_name_label.text = display_name

	# Update all 4 upgrade slots
	for i in range(4):
		var btn = upgrade_buttons[i]
		var cost_lbl = upgrade_cost_labels[i]
		var status_rect = upgrade_status_rects[i]

		var tier_name = tower.TIER_NAMES[i] if i < tower.TIER_NAMES.size() else "?"
		var tier_cost = tower.TIER_COSTS[i] if i < tower.TIER_COSTS.size() else 0
		var tier_desc = tower.ABILITY_DESCRIPTIONS[i] if i < tower.ABILITY_DESCRIPTIONS.size() else ""

		if i < tower.upgrade_tier:
			# Already purchased — green
			btn.text = "%s  ✓" % tier_name
			btn.disabled = true
			cost_lbl.text = "OWNED"
			cost_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 0.3))
			status_rect.color = Color(0.08, 0.18, 0.06, 0.85)
			# Green border
			status_rect.get_child(0).color = Color(0.3, 0.7, 0.2, 0.5)
		elif i == tower.upgrade_tier:
			# Next available — check if affordable
			btn.text = tier_name
			var can_afford = gold >= tier_cost
			btn.disabled = not can_afford
			cost_lbl.text = "%dG" % tier_cost
			if can_afford:
				# Affordable — gold border
				cost_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
				status_rect.color = Color(0.14, 0.10, 0.06, 0.85)
				status_rect.get_child(0).color = Color(0.85, 0.65, 0.1, 0.6)
			else:
				# Too expensive — dark
				cost_lbl.add_theme_color_override("font_color", Color(0.6, 0.4, 0.3))
				status_rect.color = Color(0.10, 0.07, 0.12, 0.85)
				status_rect.get_child(0).color = Color(0.4, 0.3, 0.5, 0.3)
		else:
			# Locked — gray
			btn.text = tier_name
			btn.disabled = true
			cost_lbl.text = "%dG" % tier_cost
			cost_lbl.add_theme_color_override("font_color", Color(0.4, 0.35, 0.3))
			status_rect.color = Color(0.08, 0.06, 0.10, 0.7)
			status_rect.get_child(0).color = Color(0.25, 0.2, 0.3, 0.3)

	# Update sell button
	if tower.has_method("get_sell_value"):
		var sv = tower.get_sell_value()
		sell_value_label.text = "Refund: %dG" % sv
	else:
		sell_value_label.text = ""

	upgrade_panel.visible = true

func _hide_upgrade_panel() -> void:
	upgrade_panel.visible = false

func _on_upgrade_tier_pressed(tier_index: int) -> void:
	if not selected_tower_node or not is_instance_valid(selected_tower_node):
		return
	# Only allow purchasing the next tier in sequence
	if tier_index != selected_tower_node.upgrade_tier:
		return
	if selected_tower_node.has_method("purchase_upgrade"):
		if selected_tower_node.purchase_upgrade():
			_update_upgrade_panel()
			var tier_name = selected_tower_node.TIER_NAMES[selected_tower_node.upgrade_tier - 1]
			info_label.text = "Upgraded: %s!" % tier_name

func _on_sell_pressed() -> void:
	if not selected_tower_node or not is_instance_valid(selected_tower_node):
		return
	var tower = selected_tower_node
	var sell_value = 0
	if tower.has_method("get_sell_value"):
		sell_value = tower.get_sell_value()
	var tower_name = tower.get_tower_display_name() if tower.has_method("get_tower_display_name") else "Tower"

	# Refund gold
	gold += sell_value
	update_hud()

	# Remove tower position from placement tracking
	var tower_pos = tower.global_position
	for i in range(placed_tower_positions.size() - 1, -1, -1):
		if placed_tower_positions[i].distance_to(tower_pos) < 5.0:
			placed_tower_positions.remove_at(i)
			break

	# Re-enable the tower button for this type
	for tower_type in tower_info.keys():
		if tower_info[tower_type]["name"] == tower_name:
			purchased_towers.erase(tower_type)
			if tower_buttons.has(tower_type):
				tower_buttons[tower_type].text = "%s [%dG]" % [tower_name.split(" ")[0] if tower_name.length() > 8 else tower_name, tower_info[tower_type]["cost"]]
				tower_buttons[tower_type].disabled = false
			break

	# Deselect and destroy
	_deselect_tower()
	tower.queue_free()
	info_label.text = "%s sold for %dG!" % [tower_name, sell_value]

func _on_speed_pressed() -> void:
	fast_forward = not fast_forward
	if fast_forward:
		Engine.time_scale = 2.0
		speed_button.text = "  [>>]  "
	else:
		Engine.time_scale = 1.0
		speed_button.text = "  >>  "

func _on_start_wave_pressed() -> void:
	if is_wave_active:
		return
	wave_auto_timer = -1.0
	_start_next_wave()

func _start_next_wave() -> void:
	if is_wave_active or wave >= total_waves:
		return
	wave += 1
	is_wave_active = true
	enemies_to_spawn = _get_wave_enemy_count(wave)
	spawn_interval = _get_wave_spawn_interval(wave)
	spawn_timer = 0.0
	start_button.disabled = true
	start_button.text = "  Wave in progress...  "
	var wave_name = _get_wave_name(wave)
	info_label.text = "Wave %d — %s (%d enemies)" % [wave, wave_name, enemies_to_spawn]
	update_hud()

func update_hud() -> void:
	if wave_label:
		wave_label.text = "Wave: %d / %d" % [wave, total_waves]
	if gold_label:
		gold_label.text = "Gold: %d" % gold
	if lives_label:
		lives_label.text = "Lives: %d" % lives
	if selected_tower_node and is_instance_valid(selected_tower_node):
		_update_upgrade_panel()

func add_gold(amount: int) -> void:
	gold += amount
	update_hud()

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		update_hud()
		return true
	return false

func lose_life() -> void:
	lives -= 1
	update_hud()
	if lives <= 0:
		game_over()

func enemy_died() -> void:
	enemies_alive -= 1

func game_over() -> void:
	game_state = GameState.GAME_OVER_STATE
	Engine.time_scale = 1.0
	fast_forward = false
	speed_button.text = "  >>  "
	game_over_label.text = "GAME OVER"
	game_over_label.add_theme_color_override("font_color", Color.RED)
	game_over_label.visible = true
	return_button.visible = true
	start_button.disabled = true

func _victory() -> void:
	game_state = GameState.GAME_OVER_STATE
	Engine.time_scale = 1.0
	fast_forward = false
	speed_button.text = "  >>  "
	var level_name = levels[current_level]["name"] if current_level >= 0 else "Level"
	var max_lives = levels[current_level]["lives"] if current_level >= 0 else 20
	var stars = 1
	if lives >= max_lives:
		stars = 3
	elif lives >= int(max_lives * 0.5):
		stars = 2
	if current_level >= 0 and not current_level in completed_levels:
		completed_levels.append(current_level)
	level_stars[current_level] = max(level_stars.get(current_level, 0), stars)
	var star_str = ""
	for i in range(stars):
		star_str += "★"
	for i in range(3 - stars):
		star_str += "☆"
	game_over_label.text = "%s COMPLETE! %s" % [level_name, star_str]
	game_over_label.add_theme_color_override("font_color", Color.GOLD)
	game_over_label.visible = true
	return_button.visible = true
	start_button.disabled = true

func show_ability_choice(tower: Node2D) -> void:
	_ability_tower = tower
	ability_title.text = "Choose an Ability"
	for i in range(4):
		if i < tower.TIER_NAMES.size():
			var desc = ""
			if tower.has("ABILITY_DESCRIPTIONS") and i < tower.ABILITY_DESCRIPTIONS.size():
				desc = " — " + tower.ABILITY_DESCRIPTIONS[i]
			ability_buttons[i].text = tower.TIER_NAMES[i] + desc
			ability_buttons[i].visible = true
		else:
			ability_buttons[i].visible = false
	ability_panel.visible = true
	info_label.text = "Choose a special ability for your tower!"

func _on_ability_chosen(index: int) -> void:
	if _ability_tower and _ability_tower.has_method("choose_ability"):
		_ability_tower.choose_ability(index)
	ability_panel.visible = false
	var name = ""
	if _ability_tower and index < _ability_tower.TIER_NAMES.size():
		name = _ability_tower.TIER_NAMES[index]
	info_label.text = "Ability unlocked: %s!" % name
	_ability_tower = null
