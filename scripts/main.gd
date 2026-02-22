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

# Purchase tracking â€” each tower can only be bought once
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
var cancel_button: Button

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

# Survivors tab
var survivor_types = [TowerType.ROBIN_HOOD, TowerType.ALICE, TowerType.WICKED_WITCH, TowerType.PETER_PAN, TowerType.PHANTOM, TowerType.SCROOGE]
var survivor_descriptions = {
	TowerType.ROBIN_HOOD: "The legendary outlaw of Sherwood Forest.\nLong-range archer with piercing arrows and gold bonus.",
	TowerType.ALICE: "The curious girl from Wonderland.\nThrows playing cards that shrink and slow enemies.",
	TowerType.WICKED_WITCH: "The Wicked Witch of the West.\nSwoops to strike enemies, summons wolves and monkeys.",
	TowerType.PETER_PAN: "The boy who never grew up.\nFast dagger attacks with shadow and fairy dust.",
	TowerType.PHANTOM: "The masked genius beneath the Opera.\nHeavy music note attacks with stun and AoE.",
	TowerType.SCROOGE: "The miserly old man visited by ghosts.\nCoin attacks generate gold, ghosts mark enemies.",
}
# Survivor grid UI
var survivor_grid_cards: Array = []  # Array of Button nodes for each character
var survivor_grid_container: Control = null  # Container for the grid
var survivor_grid_previews: Array = []  # Tower preview nodes for each card
var survivor_selected_index: int = -1  # Currently selected survivor (-1 = none)
var survivor_preview_node: Node2D = null  # Preview of selected survivor

# Character detail page
var survivor_detail_open: bool = false
var survivor_detail_index: int = -1
var survivor_detail_container: Control = null
var survivor_detail_back_btn: Button = null
var survivor_detail_preview: Node2D = null

# Character progression — levels, gear, sidekicks, relics
var survivor_progress: Dictionary = {}  # TowerType -> {level, xp, gear, sidekicks, relics}
var session_damage: Dictionary = {}  # TowerType -> float, damage dealt this game session

# Gear definitions per character
var survivor_gear = {
	TowerType.ROBIN_HOOD: {"name": "Longbow", "desc": "Increases arrow range and pierce"},
	TowerType.ALICE: {"name": "Looking Glass", "desc": "Cards pass through more enemies"},
	TowerType.WICKED_WITCH: {"name": "Broomstick", "desc": "Faster swoop attacks"},
	TowerType.PETER_PAN: {"name": "Shadow Blade", "desc": "Shadow clone deals more damage"},
	TowerType.PHANTOM: {"name": "Pipe Organ", "desc": "Music notes stun longer"},
	TowerType.SCROOGE: {"name": "Counting Ledger", "desc": "Coins generate bonus gold"},
}

# Sidekick definitions (3 per character)
var survivor_sidekicks = {
	TowerType.ROBIN_HOOD: [{"name": "Little John", "desc": "Slows nearby enemies"}, {"name": "Friar Tuck", "desc": "Heals nearby towers"}, {"name": "Maid Marian", "desc": "Bonus gold on kill"}],
	TowerType.ALICE: [{"name": "Cheshire Cat", "desc": "Reveals hidden enemies"}, {"name": "White Rabbit", "desc": "Speeds up attack rate"}, {"name": "Mad Hatter", "desc": "Random debuffs on hit"}],
	TowerType.WICKED_WITCH: [{"name": "Winged Monkey", "desc": "Flies to attack distant foes"}, {"name": "Toto", "desc": "Detects hidden enemies"}, {"name": "Tin Woodman", "desc": "Blocks enemies briefly"}],
	TowerType.PETER_PAN: [{"name": "Tinker Bell", "desc": "AoE fairy dust heal"}, {"name": "Lost Boys", "desc": "Extra dagger throws"}, {"name": "Tiger Lily", "desc": "Poisons enemies on hit"}],
	TowerType.PHANTOM: [{"name": "Christine", "desc": "Sings to slow enemies"}, {"name": "Madame Giry", "desc": "Reveals enemy paths"}, {"name": "Raoul", "desc": "Blocks strongest enemy"}],
	TowerType.SCROOGE: [{"name": "Bob Cratchit", "desc": "Collects extra gold"}, {"name": "Tiny Tim", "desc": "Inspires nearby towers"}, {"name": "Ghost of Marley", "desc": "Chains slow enemies"}],
}

# Character-specific relic definitions (6 per character, 36 total)
var survivor_relics = {
	TowerType.ROBIN_HOOD: [
		{"name": "Lincoln Green Cloak", "desc": "Blend with Sherwood — enemies sometimes miss", "effect": "dodge", "value": 0.12, "cost": 0, "icon": "green_cloak"},
		{"name": "Silver Arrow", "desc": "Legendary arrow that pierces the toughest armor", "effect": "pierce_damage", "value": 0.20, "cost": 100, "icon": "silver_arrow"},
		{"name": "Sherwood Longbow", "desc": "Yew bow carved from the oldest oak in Sherwood", "effect": "range", "value": 0.15, "cost": 0, "icon": "longbow"},
		{"name": "Friar Tuck's Flask", "desc": "A sip of mead restores the weariest fighter", "effect": "heal_nearby", "value": 2.0, "cost": 250, "icon": "flask"},
		{"name": "Merry Men's Horn", "desc": "The call to arms rallies all who hear it", "effect": "atk_speed_aura", "value": 0.10, "cost": 0, "icon": "horn"},
		{"name": "Prince John's Crown", "desc": "Stolen from the tyrant — riches for the poor", "effect": "bonus_gold", "value": 0.25, "cost": 500, "icon": "gold_crown"},
	],
	TowerType.ALICE: [
		{"name": "Drink Me Potion", "desc": "One sip and everything changes size", "effect": "slow", "value": 0.15, "cost": 0, "icon": "drink_me"},
		{"name": "Eat Me Cake", "desc": "Grow larger than life itself", "effect": "aoe_radius", "value": 0.20, "cost": 100, "icon": "eat_me_cake"},
		{"name": "Vorpal Sword", "desc": "One, two! One, two! And through and through!", "effect": "crit_chance", "value": 0.10, "cost": 0, "icon": "vorpal_sword"},
		{"name": "Queen's Scepter", "desc": "Off with their heads!", "effect": "instant_kill", "value": 0.08, "cost": 250, "icon": "heart_scepter"},
		{"name": "White Rabbit's Watch", "desc": "I'm late! I'm late! No time to waste!", "effect": "cooldown", "value": 0.15, "cost": 0, "icon": "pocket_watch"},
		{"name": "Cheshire Grin", "desc": "We're all mad here", "effect": "confuse", "value": 0.12, "cost": 500, "icon": "cheshire_grin"},
	],
	TowerType.WICKED_WITCH: [
		{"name": "Ruby Slippers", "desc": "There's no place like home", "effect": "reposition", "value": 1.0, "cost": 0, "icon": "ruby_slippers"},
		{"name": "Crystal Ball", "desc": "I see everything, my pretty", "effect": "reveal_camo", "value": 1.0, "cost": 100, "icon": "crystal_ball"},
		{"name": "Winged Monkey Fez", "desc": "Fly! Fly! Bring them to me!", "effect": "extra_projectile", "value": 1.0, "cost": 0, "icon": "monkey_fez"},
		{"name": "Poppy Dust", "desc": "Poppies will put them to sleep", "effect": "aoe_sleep", "value": 0.10, "cost": 250, "icon": "poppy_dust"},
		{"name": "Golden Cap", "desc": "The enchanted cap commands dark magic", "effect": "spell_damage", "value": 0.18, "cost": 0, "icon": "golden_cap"},
		{"name": "Hourglass of Doom", "desc": "Your time is running out, my dear", "effect": "hp_drain", "value": 0.03, "cost": 500, "icon": "hourglass"},
	],
	TowerType.PETER_PAN: [
		{"name": "Fairy Dust Vial", "desc": "Think happy thoughts and you can fly", "effect": "atk_speed_aura", "value": 0.12, "cost": 0, "icon": "fairy_vial"},
		{"name": "Captain Hook's Hook", "desc": "The hook gleams with cruel promise", "effect": "bleed", "value": 0.02, "cost": 100, "icon": "iron_hook"},
		{"name": "Neverland Star Map", "desc": "Second star to the right, straight on til morning", "effect": "range", "value": 0.15, "cost": 0, "icon": "star_map"},
		{"name": "Crocodile's Tooth", "desc": "Tick-tock, tick-tock — the croc comes calling", "effect": "fear", "value": 0.08, "cost": 250, "icon": "croc_tooth"},
		{"name": "Wendy's Thimble", "desc": "A thimble kiss to mend your wounds", "effect": "heal_self", "value": 3.0, "cost": 0, "icon": "thimble"},
		{"name": "Shadow Thread", "desc": "His shadow has a mind of its own", "effect": "clone_attack", "value": 5.0, "cost": 500, "icon": "shadow_thread"},
	],
	TowerType.PHANTOM: [
		{"name": "Red Rose", "desc": "A token of dark devotion", "effect": "charm", "value": 0.10, "cost": 0, "icon": "red_rose"},
		{"name": "Punjab Lasso", "desc": "The noose tightens from the shadows", "effect": "snare", "value": 2.0, "cost": 100, "icon": "punjab_lasso"},
		{"name": "Opera Score", "desc": "The music of the night is devastating", "effect": "aoe_damage", "value": 0.15, "cost": 0, "icon": "opera_score"},
		{"name": "Chandelier Chain", "desc": "When the chandelier falls, all tremble", "effect": "stun", "value": 0.12, "cost": 250, "icon": "chandelier_chain"},
		{"name": "Lake Gondola Key", "desc": "The key to the lair beneath the opera", "effect": "boss_damage", "value": 0.30, "cost": 0, "icon": "gondola_key"},
		{"name": "Christine's Mirror", "desc": "The mirror reveals what lies behind the mask", "effect": "reflect", "value": 0.08, "cost": 500, "icon": "hand_mirror"},
	],
	TowerType.SCROOGE: [
		{"name": "Marley's Chains", "desc": "Forged in life, link by link, yard by yard", "effect": "slow_aura", "value": 0.20, "cost": 0, "icon": "heavy_chains"},
		{"name": "Ghost Lantern", "desc": "The spirits illuminate all hidden truths", "effect": "reveal_weaken", "value": 0.10, "cost": 100, "icon": "ghost_lantern"},
		{"name": "Counting House Key", "desc": "Every penny pinched is a penny earned", "effect": "gold_gen", "value": 0.15, "cost": 0, "icon": "brass_key"},
		{"name": "Christmas Pudding", "desc": "God bless us, every one!", "effect": "heal_nearby", "value": 2.0, "cost": 250, "icon": "xmas_pudding"},
		{"name": "Fezziwig's Fiddle", "desc": "The old fiddle sets every foot to dancing", "effect": "atk_speed_aura", "value": 0.10, "cost": 0, "icon": "fiddle"},
		{"name": "Redemption Bell", "desc": "The bell tolls for a changed heart", "effect": "wave_start_buff", "value": 0.08, "cost": 500, "icon": "church_bell"},
	],
}
# Track which relic slot is hovered/selected for tooltip
var relic_hover_index: int = -1
var relic_tooltip_visible: bool = false

# Emporium (in-game store)
var emporium_categories = [
	{"name": "Gold Sovereigns", "desc": "Fill your coffers to build and upgrade", "icon": "emp_gold", "badge": ""},
	{"name": "Enchanted Quills", "desc": "Trade Quills for rare treasures", "icon": "emp_quills", "badge": ""},
	{"name": "Relic Shards", "desc": "Collect Shards to forge powerful Relics", "icon": "emp_shards", "badge": ""},
	{"name": "Relic Chests", "desc": "Chests contain powerful Relics!", "icon": "emp_chests", "badge": "AVAILABLE!"},
	{"name": "Survivor Packs", "desc": "Bundles of literary might", "icon": "emp_packs", "badge": "SALE!"},
	{"name": "Storybook Stars", "desc": "Empower and level up your Survivors", "icon": "emp_stars", "badge": ""},
]
var emporium_hover_index: int = -1

# Menu color palette (deep navy + gold — matches website)
var menu_bg_dark = Color(0.04, 0.04, 0.10)
var menu_bg_section = Color(0.055, 0.055, 0.14)
var menu_bg_card = Color(0.08, 0.08, 0.20)
var menu_bg_card_hover = Color(0.10, 0.10, 0.25)
var menu_gold = Color(0.79, 0.66, 0.30)
var menu_gold_light = Color(0.91, 0.83, 0.55)
var menu_gold_dim = Color(0.54, 0.45, 0.20)
var menu_text = Color(0.77, 0.73, 0.66)
var menu_text_muted = Color(0.54, 0.51, 0.47)

# Storybook menu - animation (dust motes, warm glow)
var _dust_positions: Array = []
var _book_candle_positions: Array = []

# World map data
var world_map_hover_index: int = -1
var world_map_zone_centers: Array = [
	Vector2(200, 310), Vector2(500, 260), Vector2(1060, 300),
	Vector2(200, 490), Vector2(640, 460), Vector2(1060, 490)
]
var _world_map_stars: Array = []
var _world_map_clouds: Array = []
var _world_map_smoke: Array = []

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
	# === ROBIN HOOD â€” The Merry Adventures of Robin Hood (Levels 0-2) ===
	{
		"name": "The Outlaw's Call", "subtitle": "Sherwood Forest â€” Chapter 1",
		"description": "Robin becomes an outlaw and builds his camp in Sherwood Forest. Defend the hideout from the Sheriff's tax collectors!",
		"character": 0, "chapter": 0,
		"waves": 12, "gold": 100, "lives": 25, "difficulty": 1.0,
		"sky_color": Color(0.02, 0.06, 0.10),
		"ground_color": Color(0.06, 0.16, 0.04),
	},
	{
		"name": "The Sheriff's Pursuit", "subtitle": "Sherwood Forest â€" Chapter 2",
		"description": "The Sheriff of Nottingham sends his soldiers to hunt Robin. Defend Little John's Bridge and the river crossing!",
		"character": 0, "chapter": 1,
		"waves": 15, "gold": 100, "lives": 22, "difficulty": 1.15,
		"sky_color": Color(0.02, 0.04, 0.08),
		"ground_color": Color(0.05, 0.14, 0.03),
	},
	{
		"name": "Siege of Nottingham", "subtitle": "Sherwood Forest â€” Chapter 3",
		"description": "Robin leads the attack on Nottingham Castle to free his captured men. Defeat the Sheriff at the castle gates!",
		"character": 0, "chapter": 2,
		"waves": 18, "gold": 115, "lives": 20, "difficulty": 1.3,
		"sky_color": Color(0.06, 0.04, 0.02),
		"ground_color": Color(0.08, 0.08, 0.06),
	},
	# === ALICE â€” Alice's Adventures in Wonderland (Levels 3-5) ===
	{
		"name": "Down the Rabbit Hole", "subtitle": "Wonderland â€” Chapter 1",
		"description": "Alice follows the White Rabbit into a curious garden of giant mushrooms, talking flowers, and nonsense.",
		"character": 1, "chapter": 0,
		"waves": 12, "gold": 100, "lives": 25, "difficulty": 1.0,
		"sky_color": Color(0.12, 0.04, 0.16),
		"ground_color": Color(0.08, 0.18, 0.06),
	},
	{
		"name": "The Mad Tea Party", "subtitle": "Wonderland â€” Chapter 2",
		"description": "Deeper into Wonderland â€” the Mad Hatter's tea party and the Queen of Hearts' card army advances, painting the roses red.",
		"character": 1, "chapter": 1,
		"waves": 15, "gold": 105, "lives": 22, "difficulty": 1.2,
		"sky_color": Color(0.10, 0.03, 0.14),
		"ground_color": Color(0.06, 0.14, 0.05),
	},
	{
		"name": "The Queen's Court", "subtitle": "Wonderland â€” Chapter 3",
		"description": "Alice reaches the Queen's palace. The rose garden runs red. Off with their heads!",
		"character": 1, "chapter": 2,
		"waves": 18, "gold": 115, "lives": 18, "difficulty": 1.4,
		"sky_color": Color(0.14, 0.02, 0.08),
		"ground_color": Color(0.10, 0.06, 0.06),
	},
	# === WICKED WITCH â€” The Wonderful Wizard of Oz (Levels 6-8) ===
	{
		"name": "The Yellow Brick Road", "subtitle": "Land of Oz â€” Chapter 1",
		"description": "Dorothy and companions follow the golden road through poppy fields toward the Emerald City.",
		"character": 2, "chapter": 0,
		"waves": 12, "gold": 105, "lives": 25, "difficulty": 1.05,
		"sky_color": Color(0.02, 0.10, 0.06),
		"ground_color": Color(0.14, 0.12, 0.02),
	},
	{
		"name": "The Witch's Domain", "subtitle": "Land of Oz â€” Chapter 2",
		"description": "The Wicked Witch of the West sends her flying monkeys. Dark western territory and dead forests loom ahead.",
		"character": 2, "chapter": 1,
		"waves": 16, "gold": 110, "lives": 22, "difficulty": 1.3,
		"sky_color": Color(0.04, 0.06, 0.02),
		"ground_color": Color(0.10, 0.08, 0.04),
	},
	{
		"name": "The Emerald Throne", "subtitle": "Land of Oz â€” Chapter 3",
		"description": "Inside the Emerald City, the Nome King rises to seize power. Green crystal walls crack as rock soldiers march.",
		"character": 2, "chapter": 2,
		"waves": 20, "gold": 125, "lives": 18, "difficulty": 1.5,
		"sky_color": Color(0.02, 0.08, 0.04),
		"ground_color": Color(0.06, 0.12, 0.06),
	},
	# === PETER PAN â€” Peter and Wendy (Levels 9-11) ===
	{
		"name": "Flight to Neverland", "subtitle": "Neverland â€” Chapter 1",
		"description": "Second star to the right and straight on till morning. Mermaid lagoon sparkles and pirate scouts appear.",
		"character": 3, "chapter": 0,
		"waves": 12, "gold": 110, "lives": 25, "difficulty": 1.1,
		"sky_color": Color(0.04, 0.06, 0.14),
		"ground_color": Color(0.08, 0.18, 0.06),
	},
	{
		"name": "The Lost Boys' Stand", "subtitle": "Neverland â€” Chapter 2",
		"description": "Captain Hook's pirate officers lead raiding parties through the dense jungle to attack the Lost Boys' hideout.",
		"character": 3, "chapter": 1,
		"waves": 17, "gold": 115, "lives": 20, "difficulty": 1.4,
		"sky_color": Color(0.03, 0.05, 0.10),
		"ground_color": Color(0.06, 0.15, 0.04),
	},
	{
		"name": "The Jolly Roger", "subtitle": "Neverland â€” Chapter 3",
		"description": "The final battle aboard Captain Hook's ship. Sword fights on deck, walking the plank over the ticking crocodile!",
		"character": 3, "chapter": 2,
		"waves": 20, "gold": 125, "lives": 18, "difficulty": 1.6,
		"sky_color": Color(0.08, 0.04, 0.02),
		"ground_color": Color(0.12, 0.08, 0.06),
	},
	# === PHANTOM â€” The Phantom of the Opera (Levels 12-14) ===
	{
		"name": "The Grand Stage", "subtitle": "Paris Opera â€” Chapter 1",
		"description": "The Paris Opera House, elegant and grand. Strange things happen during performances â€” a ghost in the wings.",
		"character": 4, "chapter": 0,
		"waves": 14, "gold": 110, "lives": 22, "difficulty": 1.2,
		"sky_color": Color(0.04, 0.02, 0.08),
		"ground_color": Color(0.10, 0.08, 0.10),
	},
	{
		"name": "The Labyrinth", "subtitle": "Paris Opera â€” Chapter 2",
		"description": "Descending beneath the opera into mirrors, candlelit tunnels, and traps. The Phantom reveals himself.",
		"character": 4, "chapter": 1,
		"waves": 18, "gold": 120, "lives": 20, "difficulty": 1.5,
		"sky_color": Color(0.03, 0.02, 0.06),
		"ground_color": Color(0.08, 0.06, 0.08),
	},
	{
		"name": "The Phantom's Lair", "subtitle": "Paris Opera â€” Chapter 3",
		"description": "The underground lake, the great organ, roses on black water. Defeat the Dark Phantom in his domain!",
		"character": 4, "chapter": 2,
		"waves": 22, "gold": 130, "lives": 16, "difficulty": 1.7,
		"sky_color": Color(0.02, 0.01, 0.04),
		"ground_color": Color(0.06, 0.04, 0.06),
	},
	# === SCROOGE â€” A Christmas Carol (Levels 15-17) ===
	{
		"name": "Christmas Eve", "subtitle": "Victorian London â€” Chapter 1",
		"description": "Victorian London on a cold Christmas Eve. Scrooge at his counting house, ignoring the carolers. Marley's ghost appears.",
		"character": 5, "chapter": 0,
		"waves": 14, "gold": 115, "lives": 22, "difficulty": 1.3,
		"sky_color": Color(0.08, 0.08, 0.12),
		"ground_color": Color(0.10, 0.10, 0.12),
	},
	{
		"name": "The Three Spirits", "subtitle": "Victorian London â€” Chapter 2",
		"description": "The Ghosts of Christmas Past, Present, and Future visit Scrooge. Spectral London, gravestones, chains rattling.",
		"character": 5, "chapter": 1,
		"waves": 18, "gold": 125, "lives": 18, "difficulty": 1.6,
		"sky_color": Color(0.06, 0.06, 0.10),
		"ground_color": Color(0.08, 0.08, 0.10),
	},
	{
		"name": "Redemption's Dawn", "subtitle": "Victorian London â€” Chapter 3",
		"description": "Christmas morning. The Ghost of Christmas Yet to Come leads an army of despair. Warm light fights to break through.",
		"character": 5, "chapter": 2,
		"waves": 25, "gold": 135, "lives": 15, "difficulty": 1.8,
		"sky_color": Color(0.10, 0.08, 0.06),
		"ground_color": Color(0.12, 0.10, 0.10),
	},
]

# Difficulty selection (0=Easy, 1=Medium, 2=Hard)
var selected_difficulty: int = 0
var difficulty_waves: Array = [20, 30, 40]
var difficulty_gold_bonus: Array = [25, 0, -15]
var difficulty_lives_bonus: Array = [5, 0, -5]
var chapter_diff_buttons: Array = []  # Array of 3 arrays, each with 3 buttons

# Player inventory (persistent across sessions)
var player_quills: int = 0
var player_relic_shards: int = 0
var player_storybook_stars: int = 0

# Treasure chest state
var chest_loot: Array = []  # Array of {"type": String, "amount": int, "name": String}
var chest_open: bool = false
var chest_timer: float = 0.0

# Relics tab hover state
var relics_tab_hover_tier: int = -1
var relics_tab_hover_row: int = -1
var relics_tab_hover_col: int = -1

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

# Audio â€” procedural hip hop beat
var music_player: AudioStreamPlayer
var music_tracks: Array = []
var music_index: int = 0
var music_playing: bool = false

# Audio â€" character voice clips
var voice_player: AudioStreamPlayer
var voice_clips: Dictionary = {}
var tower_quotes: Dictionary = {}

# Voice-over catchphrase system (MP3 files from edge-tts)
var catchphrase_player: AudioStreamPlayer
var placement_voice_clips: Dictionary = {}  # TowerType → Array[AudioStreamMP3]
var fighting_voice_clips: Dictionary = {}   # TowerType → Array[AudioStreamMP3]
var placement_quotes: Dictionary = {}       # TowerType → Array[String]
var fighting_quotes: Dictionary = {}        # TowerType → Array[String]
var _fighting_quote_timer: float = 25.0

func _ready() -> void:
	add_to_group("main")
	_init_survivor_progress()
	_cache_path_points()
	_generate_decorations_for_level(0)
	_create_ui()
	_setup_audio()
	_show_menu()

# Ability unlock popup state
var _ability_popup_timer: float = 0.0
var _ability_popup_tower_type: int = -1
var _ability_popup_index: int = -1
var _ability_popup_name: String = ""
var _ability_popup_desc: String = ""
var _ability_popup_freeze: float = 0.0

# Ability thresholds (same for all characters)
const PROGRESSIVE_ABILITY_THRESHOLDS = [5000, 25000, 100000, 350000, 1000000, 3000000, 10000000, 35000000, 100000000]

# Spawn debuff flags (set by Crystal Ball / Beneath the Opera)
var spawn_hp_reduction: float = 0.0   # Crystal Ball: 0.15 = 15% less HP
var spawn_permanent_slow: float = 1.0 # Beneath the Opera: 0.7 = 30% slower

func _init_survivor_progress() -> void:
	for t in survivor_types:
		survivor_progress[t] = {
			"level": 1,
			"xp": 0.0,
			"xp_next": 500.0,
			"gear_unlocked": false,
			"sidekicks_unlocked": [false, false, false],
			"relics_unlocked": [false, false, false, false, false, false],
			"total_damage": 0.0,
			"abilities_unlocked": [false, false, false, false, false, false, false, false, false],
		}
		session_damage[t] = 0.0

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
		0: # Robin Hood Ch1 â€” Sherwood Forest
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
		1: # Robin Hood Ch2 â€” Sheriff's Pursuit
			for i in range(35):
				var pos = Vector2(rng.randf_range(20, 1260), rng.randf_range(55, 620))
				if _dist_to_path(pos) > 60.0:
					var r = rng.randf()
					if r < 0.3:
						_decorations.append({"pos": pos, "type": "oak_tree", "size": rng.randf_range(16, 34), "extra": rng.randf_range(-0.04, 0.04)})
					elif r < 0.5:
						_decorations.append({"pos": pos, "type": "target", "size": rng.randf_range(7, 11), "extra": 0.0})
					elif r < 0.7:
						_decorations.append({"pos": pos, "type": "bush", "size": rng.randf_range(9, 18), "extra": rng.randf_range(0.0, 1.0)})
					elif r < 0.85:
						_decorations.append({"pos": pos, "type": "deer", "size": rng.randf_range(10, 17), "extra": rng.randf_range(0, TAU)})
					else:
						_decorations.append({"pos": pos, "type": "campfire", "size": rng.randf_range(11, 14), "extra": rng.randf_range(0, TAU)})
		2: # Robin Hood Ch3 â€” Siege of Nottingham
			for i in range(45):
				var pos = Vector2(rng.randf_range(15, 1265), rng.randf_range(55, 620))
				if _dist_to_path(pos) > 55.0:
					var r = rng.randf()
					if r < 0.28:
						_decorations.append({"pos": pos, "type": "oak_tree", "size": rng.randf_range(18, 38), "extra": rng.randf_range(-0.04, 0.04)})
					elif r < 0.46:
						_decorations.append({"pos": pos, "type": "target", "size": rng.randf_range(7, 12), "extra": 0.0})
					elif r < 0.64:
						_decorations.append({"pos": pos, "type": "bush", "size": rng.randf_range(10, 20), "extra": rng.randf_range(0.0, 1.0)})
					elif r < 0.8:
						_decorations.append({"pos": pos, "type": "deer", "size": rng.randf_range(10, 18), "extra": rng.randf_range(0, TAU)})
					else:
						_decorations.append({"pos": pos, "type": "campfire", "size": rng.randf_range(12, 16), "extra": rng.randf_range(0, TAU)})
		3: # Alice Ch1 â€” Down the Rabbit Hole
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
		4: # Alice Ch2 â€” Mad Tea Party
			for i in range(30):
				var pos = Vector2(rng.randf_range(20, 1260), rng.randf_range(55, 620))
				if _dist_to_path(pos) > 60.0:
					var r = rng.randf()
					if r < 0.3:
						_decorations.append({"pos": pos, "type": "giant_mushroom", "size": rng.randf_range(12, 26), "extra": rng.randf_range(0.0, 1.0)})
					elif r < 0.55:
						_decorations.append({"pos": pos, "type": "floating_card", "size": rng.randf_range(7, 13), "extra": rng.randf_range(0, TAU)})
					elif r < 0.8:
						_decorations.append({"pos": pos, "type": "rose", "size": rng.randf_range(4, 9), "extra": rng.randf_range(0.0, 1.0)})
					else:
						_decorations.append({"pos": pos, "type": "teacup", "size": rng.randf_range(6, 11), "extra": 0.0})
		5: # Alice Ch3 â€” Queen's Court
			for i in range(40):
				var pos = Vector2(rng.randf_range(15, 1265), rng.randf_range(55, 620))
				if _dist_to_path(pos) > 55.0:
					var r = rng.randf()
					if r < 0.3:
						_decorations.append({"pos": pos, "type": "giant_mushroom", "size": rng.randf_range(14, 30), "extra": rng.randf_range(0.0, 1.0)})
					elif r < 0.55:
						_decorations.append({"pos": pos, "type": "floating_card", "size": rng.randf_range(7, 14), "extra": rng.randf_range(0, TAU)})
					elif r < 0.78:
						_decorations.append({"pos": pos, "type": "rose", "size": rng.randf_range(5, 10), "extra": rng.randf_range(0.0, 1.0)})
					else:
						_decorations.append({"pos": pos, "type": "teacup", "size": rng.randf_range(7, 12), "extra": 0.0})
		6: # Oz Ch1 â€” Yellow Brick Road
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
		7: # Oz Ch2 â€” Witch's Domain
			for i in range(35):
				var pos = Vector2(rng.randf_range(20, 1260), rng.randf_range(55, 620))
				if _dist_to_path(pos) > 60.0:
					var r = rng.randf()
					if r < 0.4:
						_decorations.append({"pos": pos, "type": "poppy", "size": rng.randf_range(4, 8), "extra": rng.randf_range(0, TAU)})
					elif r < 0.7:
						_decorations.append({"pos": pos, "type": "emerald_crystal", "size": rng.randf_range(6, 14), "extra": rng.randf_range(0, TAU)})
					else:
						_decorations.append({"pos": pos, "type": "scarecrow", "size": rng.randf_range(13, 19), "extra": 0.0})
		8: # Oz Ch3 â€” Emerald Throne
			for i in range(48):
				var pos = Vector2(rng.randf_range(15, 1265), rng.randf_range(55, 620))
				if _dist_to_path(pos) > 55.0:
					var r = rng.randf()
					if r < 0.38:
						_decorations.append({"pos": pos, "type": "poppy", "size": rng.randf_range(4, 9), "extra": rng.randf_range(0, TAU)})
					elif r < 0.72:
						_decorations.append({"pos": pos, "type": "emerald_crystal", "size": rng.randf_range(6, 16), "extra": rng.randf_range(0, TAU)})
					else:
						_decorations.append({"pos": pos, "type": "scarecrow", "size": rng.randf_range(12, 20), "extra": 0.0})
		9: # Peter Pan Ch1 â€” Flight to Neverland
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
		10: # Peter Pan Ch2 â€” Lost Boys' Stand
			for i in range(35):
				var pos = Vector2(rng.randf_range(20, 1260), rng.randf_range(55, 620))
				if _dist_to_path(pos) > 60.0:
					var r = rng.randf()
					if r < 0.3:
						_decorations.append({"pos": pos, "type": "jungle_tree", "size": rng.randf_range(15, 32), "extra": rng.randf_range(-0.04, 0.04)})
					elif r < 0.5:
						_decorations.append({"pos": pos, "type": "fairy", "size": 2.0, "extra": rng.randf_range(0, TAU)})
					elif r < 0.75:
						_decorations.append({"pos": pos, "type": "mushroom", "size": rng.randf_range(3, 8), "extra": rng.randf_range(0, 1)})
					else:
						_decorations.append({"pos": pos, "type": "star", "size": rng.randf_range(0.3, 0.9), "extra": rng.randf_range(0, TAU)})
		11: # Peter Pan Ch3 â€” The Jolly Roger
			for i in range(46):
				var pos = Vector2(rng.randf_range(15, 1265), rng.randf_range(55, 620))
				if _dist_to_path(pos) > 55.0:
					var r = rng.randf()
					if r < 0.28:
						_decorations.append({"pos": pos, "type": "jungle_tree", "size": rng.randf_range(16, 36), "extra": rng.randf_range(-0.04, 0.04)})
					elif r < 0.5:
						_decorations.append({"pos": pos, "type": "fairy", "size": 2.0, "extra": rng.randf_range(0, TAU)})
					elif r < 0.75:
						_decorations.append({"pos": pos, "type": "mushroom", "size": rng.randf_range(4, 9), "extra": rng.randf_range(0, 1)})
					else:
						_decorations.append({"pos": pos, "type": "star", "size": rng.randf_range(0.4, 1.0), "extra": rng.randf_range(0, TAU)})
		12: # Phantom Ch1 â€” Grand Stage
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
		13: # Phantom Ch2 â€” Labyrinth
			for i in range(32):
				var pos = Vector2(rng.randf_range(20, 1260), rng.randf_range(55, 620))
				if _dist_to_path(pos) > 60.0:
					var r = rng.randf()
					if r < 0.3:
						_decorations.append({"pos": pos, "type": "candelabra", "size": rng.randf_range(9, 16), "extra": rng.randf_range(0, TAU)})
					elif r < 0.55:
						_decorations.append({"pos": pos, "type": "mirror", "size": rng.randf_range(11, 20), "extra": rng.randf_range(0, TAU)})
					elif r < 0.78:
						_decorations.append({"pos": pos, "type": "rose", "size": rng.randf_range(4, 7), "extra": rng.randf_range(0.0, 1.0)})
					else:
						_decorations.append({"pos": pos, "type": "sheet_music", "size": rng.randf_range(5, 9), "extra": rng.randf_range(0, TAU)})
		14: # Phantom Ch3 â€” Phantom's Lair
			for i in range(42):
				var pos = Vector2(rng.randf_range(15, 1265), rng.randf_range(55, 620))
				if _dist_to_path(pos) > 55.0:
					var r = rng.randf()
					if r < 0.3:
						_decorations.append({"pos": pos, "type": "candelabra", "size": rng.randf_range(10, 18), "extra": rng.randf_range(0, TAU)})
					elif r < 0.55:
						_decorations.append({"pos": pos, "type": "mirror", "size": rng.randf_range(12, 22), "extra": rng.randf_range(0, TAU)})
					elif r < 0.78:
						_decorations.append({"pos": pos, "type": "rose", "size": rng.randf_range(4, 8), "extra": rng.randf_range(0.0, 1.0)})
					else:
						_decorations.append({"pos": pos, "type": "sheet_music", "size": rng.randf_range(5, 10), "extra": rng.randf_range(0, TAU)})
		15: # Scrooge Ch1 â€” Christmas Eve
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
		16: # Scrooge Ch2 â€” Three Spirits
			for i in range(33):
				var pos = Vector2(rng.randf_range(20, 1260), rng.randf_range(55, 620))
				if _dist_to_path(pos) > 60.0:
					var r = rng.randf()
					if r < 0.28:
						_decorations.append({"pos": pos, "type": "lamp_post", "size": rng.randf_range(21, 32), "extra": rng.randf_range(0, TAU)})
					elif r < 0.52:
						_decorations.append({"pos": pos, "type": "bare_tree", "size": rng.randf_range(15, 28), "extra": rng.randf_range(-0.04, 0.04)})
					elif r < 0.76:
						_decorations.append({"pos": pos, "type": "snow_pile", "size": rng.randf_range(6, 14), "extra": 0.0})
					else:
						_decorations.append({"pos": pos, "type": "chimney", "size": rng.randf_range(9, 15), "extra": rng.randf_range(0, TAU)})
		17: # Scrooge Ch3 â€” Redemption's Dawn
			for i in range(44):
				var pos = Vector2(rng.randf_range(15, 1265), rng.randf_range(55, 620))
				if _dist_to_path(pos) > 55.0:
					var r = rng.randf()
					if r < 0.27:
						_decorations.append({"pos": pos, "type": "lamp_post", "size": rng.randf_range(22, 35), "extra": rng.randf_range(0, TAU)})
					elif r < 0.52:
						_decorations.append({"pos": pos, "type": "bare_tree", "size": rng.randf_range(16, 32), "extra": rng.randf_range(-0.04, 0.04)})
					elif r < 0.76:
						_decorations.append({"pos": pos, "type": "snow_pile", "size": rng.randf_range(7, 16), "extra": 0.0})
					else:
						_decorations.append({"pos": pos, "type": "chimney", "size": rng.randf_range(9, 17), "extra": rng.randf_range(0, TAU)})

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
	robin_button.pressed.connect(_on_tower_pressed.bind(TowerType.ROBIN_HOOD, "Robin Hood â€” long range archer, gold bonus. Cancel to abort."))
	bottom_panel.add_child(robin_button)
	tower_buttons[TowerType.ROBIN_HOOD] = robin_button

	var alice_button = _make_button("Alice [85G]", Vector2(144, row1_y), Vector2(130, btn_h))
	alice_button.pressed.connect(_on_tower_pressed.bind(TowerType.ALICE, "Alice â€” cards, slows enemies. Cancel to abort."))
	bottom_panel.add_child(alice_button)
	tower_buttons[TowerType.ALICE] = alice_button

	var witch_button = _make_button("Witch [100G]", Vector2(280, row1_y), Vector2(130, btn_h))
	witch_button.pressed.connect(_on_tower_pressed.bind(TowerType.WICKED_WITCH, "Wicked Witch â€” eye blast, wolves. Cancel to abort."))
	bottom_panel.add_child(witch_button)
	tower_buttons[TowerType.WICKED_WITCH] = witch_button

	var peter_button = _make_button("Peter [90G]", Vector2(8, row2_y), Vector2(130, btn_h))
	peter_button.pressed.connect(_on_tower_pressed.bind(TowerType.PETER_PAN, "Peter Pan â€” fast daggers, shadow. Cancel to abort."))
	bottom_panel.add_child(peter_button)
	tower_buttons[TowerType.PETER_PAN] = peter_button

	var phantom_button = _make_button("Phantom [95G]", Vector2(144, row2_y), Vector2(130, btn_h))
	phantom_button.pressed.connect(_on_tower_pressed.bind(TowerType.PHANTOM, "Phantom â€” heavy hits, stun, chandelier. Cancel to abort."))
	bottom_panel.add_child(phantom_button)
	tower_buttons[TowerType.PHANTOM] = phantom_button

	var scrooge_button = _make_button("Scrooge [60G]", Vector2(280, row2_y), Vector2(130, btn_h))
	scrooge_button.pressed.connect(_on_tower_pressed.bind(TowerType.SCROOGE, "Scrooge â€” coins, gold gen, ghost marks. Cancel to abort."))
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

	cancel_button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.position = Vector2(416, row1_y)
	cancel_button.custom_minimum_size = Vector2(66, btn_h)
	cancel_button.visible = false
	cancel_button.pressed.connect(_on_cancel_placement)
	bottom_panel.add_child(cancel_button)

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
	menu_overlay.color = Color(0, 0, 0, 0)  # Transparent â€” we draw the background in _draw()
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

	# World map data
	var rng3 = RandomNumberGenerator.new()
	rng3.seed = 200
	for i in range(40):
		_world_map_stars.append({"x": rng3.randf_range(10, 1270), "y": rng3.randf_range(5, 200), "size": rng3.randf_range(0.5, 2.0), "speed": rng3.randf_range(1.0, 3.0), "offset": rng3.randf_range(0, TAU)})
	for i in range(3):
		_world_map_clouds.append({"x": rng3.randf_range(100, 1100), "y": rng3.randf_range(50, 160), "width": rng3.randf_range(40, 80), "speed": rng3.randf_range(0.15, 0.4)})
	for i in range(5):
		_world_map_smoke.append({"y": rng3.randf_range(-5, -35), "speed": rng3.randf_range(0.3, 0.8), "size": rng3.randf_range(2.0, 5.0), "offset": rng3.randf_range(0, TAU)})

	# Title â€” hidden by default (shown on book cover, drawn procedurally)
	menu_title = Label.new()
	menu_title.text = ""
	menu_title.position = Vector2(20, 22)
	menu_title.size = Vector2(600, 60)
	menu_title.visible = false
	menu_overlay.add_child(menu_title)

	# Subtitle â€” hidden (drawn on book cover)
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
	menu_showcase_panel.position = Vector2(70, 45)
	menu_showcase_panel.size = Vector2(1140, 560)
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

	# Stars display (unused in chapters view, used in survivors)
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
	menu_right_arrow.position = Vector2(1060, 490)
	menu_right_arrow.custom_minimum_size = Vector2(60, 40)
	menu_right_arrow.pressed.connect(_on_menu_right)
	menu_showcase_panel.add_child(menu_right_arrow)

	# PLAY button â€” hidden, replaced by chapter buttons
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
		ch_desc.size = Vector2(340, 50)
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

		# Difficulty buttons for this chapter (Easy / Med / Hard)
		var diff_labels = ["EASY", "MED", "HARD"]
		var diff_colors_bg = [Color(0.15, 0.45, 0.2), Color(0.45, 0.40, 0.1), Color(0.55, 0.15, 0.1)]
		var ch_diff_btns: Array = []
		for d in range(3):
			var diff_btn = Button.new()
			diff_btn.text = diff_labels[d]
			diff_btn.position = Vector2(card_x + 290 + d * 72, card_y + 76)
			diff_btn.custom_minimum_size = Vector2(66, 44)
			diff_btn.add_theme_font_size_override("font_size", 12)
			diff_btn.pressed.connect(_on_chapter_play.bind(i, d))
			menu_showcase_panel.add_child(diff_btn)
			ch_diff_btns.append(diff_btn)
		chapter_diff_buttons.append(ch_diff_btns)
		# Keep a reference in chapter_buttons for the first button (for lock/unlock logic)
		chapter_buttons.append(ch_diff_btns[0])

	# === BOTTOM NAV BAR (bookmark ribbon style) ===
	var nav_bar = ColorRect.new()
	nav_bar.color = Color(0.04, 0.04, 0.10, 0.97)
	nav_bar.position = Vector2(0, 620)
	nav_bar.size = Vector2(1280, 100)
	menu_overlay.add_child(nav_bar)

	# Nav bar top border — gold line (3px) + gold accent (1px)
	var nav_border = ColorRect.new()
	nav_border.color = Color(0.79, 0.66, 0.30, 0.4)
	nav_border.position = Vector2(0, 0)
	nav_border.size = Vector2(1280, 3)
	nav_bar.add_child(nav_border)

	var nav_gold_accent = ColorRect.new()
	nav_gold_accent.color = Color(0.65, 0.45, 0.1, 0.35)
	nav_gold_accent.position = Vector2(0, 3)
	nav_gold_accent.size = Vector2(1280, 1)
	nav_bar.add_child(nav_gold_accent)

	var nav_names = ["SURVIVORS", "RELICS", "CHAPTERS", "CHRONICLES", "EMPORIUM"]
	var nav_icons = ["â™Ÿ", "â—†", "ðŸ“–", "ðŸ“œ", "ðŸª"]
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
		nav_lbl.add_theme_font_size_override("font_size", 12)
		nav_lbl.add_theme_color_override("font_color", Color(0.7, 0.6, 0.45))
		nav_bar.add_child(nav_lbl)
		menu_nav_labels.append(nav_lbl)

		# Vertical divider between buttons (gold line)
		if i < 4:
			var div_x_pos = btn_x + 155
			var div_line = ColorRect.new()
			div_line.color = Color(0.65, 0.45, 0.1, 0.2)
			div_line.position = Vector2(div_x_pos, 12)
			div_line.size = Vector2(1, 65)
			nav_bar.add_child(div_line)

	# === SURVIVOR GRID (Bloons-style character roster) ===
	survivor_grid_container = Control.new()
	survivor_grid_container.position = Vector2(70, 45)
	survivor_grid_container.size = Vector2(1140, 560)
	survivor_grid_container.visible = false
	menu_overlay.add_child(survivor_grid_container)

	# "SURVIVORS" title header
	var surv_title = Label.new()
	surv_title.text = "SURVIVORS"
	surv_title.position = Vector2(0, 8)
	surv_title.size = Vector2(1160, 50)
	surv_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	surv_title.add_theme_font_size_override("font_size", 32)
	surv_title.add_theme_color_override("font_color", Color(0.85, 0.65, 0.1))
	survivor_grid_container.add_child(surv_title)

	# Create 6 character cards in a 3x2 grid
	survivor_grid_cards.clear()
	var card_w = 310.0
	var card_h = 210.0
	var grid_margin_x = 65.0
	var grid_margin_y = 65.0
	var gap_x = 40.0
	var gap_y = 30.0
	for i in range(6):
		var col_i = i % 3
		var row_i = i / 3
		var cx = grid_margin_x + float(col_i) * (card_w + gap_x)
		var cy = grid_margin_y + float(row_i) * (card_h + gap_y)

		var card_btn = Button.new()
		card_btn.position = Vector2(cx, cy)
		card_btn.custom_minimum_size = Vector2(card_w, card_h)
		card_btn.flat = true
		card_btn.pressed.connect(_on_survivor_card_pressed.bind(i))
		card_btn.mouse_entered.connect(func(): queue_redraw())
		card_btn.mouse_exited.connect(func(): queue_redraw())
		survivor_grid_container.add_child(card_btn)
		survivor_grid_cards.append(card_btn)

		# Character name label
		var tower_type_i = survivor_types[i]
		var info_i = tower_info[tower_type_i]
		var name_lbl = Label.new()
		name_lbl.text = info_i["name"]
		name_lbl.position = Vector2(140, 20)
		name_lbl.size = Vector2(160, 30)
		name_lbl.add_theme_font_size_override("font_size", 20)
		name_lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 0.55))
		card_btn.add_child(name_lbl)

		# Novel title label
		var novel_lbl = Label.new()
		novel_lbl.text = character_novels[i]
		novel_lbl.position = Vector2(140, 50)
		novel_lbl.size = Vector2(160, 20)
		novel_lbl.add_theme_font_size_override("font_size", 10)
		novel_lbl.add_theme_color_override("font_color", Color(0.5, 0.4, 0.3))
		card_btn.add_child(novel_lbl)

		# Description label
		var desc_lbl = Label.new()
		desc_lbl.text = survivor_descriptions.get(tower_type_i, "")
		desc_lbl.position = Vector2(140, 75)
		desc_lbl.size = Vector2(160, 80)
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.add_theme_color_override("font_color", Color(0.6, 0.5, 0.4))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_btn.add_child(desc_lbl)

		# Cost label (bottom right)
		var cost_lbl = Label.new()
		cost_lbl.text = "%d gold" % info_i["cost"]
		cost_lbl.position = Vector2(card_w - 85, card_h - 38)
		cost_lbl.size = Vector2(70, 25)
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_lbl.add_theme_font_size_override("font_size", 12)
		cost_lbl.add_theme_color_override("font_color", Color(0.85, 0.65, 0.1))
		card_btn.add_child(cost_lbl)

	# === SURVIVOR DETAIL PAGE (opened when clicking a card) ===
	survivor_detail_container = Control.new()
	survivor_detail_container.position = Vector2(60, 45)
	survivor_detail_container.size = Vector2(1160, 560)
	survivor_detail_container.visible = false
	menu_overlay.add_child(survivor_detail_container)

	# Back button
	survivor_detail_back_btn = Button.new()
	survivor_detail_back_btn.text = "  < BACK  "
	survivor_detail_back_btn.position = Vector2(15, 12)
	survivor_detail_back_btn.custom_minimum_size = Vector2(100, 36)
	survivor_detail_back_btn.pressed.connect(_on_detail_back)
	survivor_detail_container.add_child(survivor_detail_back_btn)

	# Character name (large, top center-left)
	var det_name = Label.new()
	det_name.name = "DetailName"
	det_name.position = Vector2(150, 8)
	det_name.size = Vector2(300, 40)
	det_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	det_name.add_theme_font_size_override("font_size", 28)
	det_name.add_theme_color_override("font_color", Color(0.85, 0.65, 0.1))
	survivor_detail_container.add_child(det_name)

	# Level label (overlays on the badge drawn in _draw)
	var det_level = Label.new()
	det_level.name = "DetailLevel"
	det_level.position = Vector2(42, 82)
	det_level.size = Vector2(50, 30)
	det_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	det_level.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	det_level.add_theme_font_size_override("font_size", 18)
	det_level.add_theme_color_override("font_color", Color(0.85, 0.75, 0.55))
	survivor_detail_container.add_child(det_level)

	# XP text (below portrait)
	var det_xp = Label.new()
	det_xp.name = "DetailXP"
	det_xp.position = Vector2(80, 425)
	det_xp.size = Vector2(300, 20)
	det_xp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	det_xp.add_theme_font_size_override("font_size", 11)
	det_xp.add_theme_color_override("font_color", Color(0.6, 0.5, 0.35))
	survivor_detail_container.add_child(det_xp)

	# Novel subtitle
	var det_novel = Label.new()
	det_novel.name = "DetailNovel"
	det_novel.position = Vector2(80, 450)
	det_novel.size = Vector2(300, 20)
	det_novel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	det_novel.add_theme_font_size_override("font_size", 11)
	det_novel.add_theme_color_override("font_color", Color(0.5, 0.4, 0.3))
	survivor_detail_container.add_child(det_novel)

	# Description
	var det_desc = Label.new()
	det_desc.name = "DetailDesc"
	det_desc.position = Vector2(80, 470)
	det_desc.size = Vector2(300, 60)
	det_desc.add_theme_font_size_override("font_size", 11)
	det_desc.add_theme_color_override("font_color", Color(0.55, 0.45, 0.35))
	det_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	survivor_detail_container.add_child(det_desc)

	# --- Right side labels ---
	# GEAR header
	var gear_hdr = Label.new()
	gear_hdr.name = "GearHeader"
	gear_hdr.text = "GEAR"
	gear_hdr.position = Vector2(510, 15)
	gear_hdr.size = Vector2(200, 30)
	gear_hdr.add_theme_font_size_override("font_size", 18)
	gear_hdr.add_theme_color_override("font_color", Color(0.75, 0.6, 0.35))
	survivor_detail_container.add_child(gear_hdr)

	# Gear name
	var gear_name = Label.new()
	gear_name.name = "GearName"
	gear_name.position = Vector2(590, 50)
	gear_name.size = Vector2(250, 25)
	gear_name.add_theme_font_size_override("font_size", 14)
	gear_name.add_theme_color_override("font_color", Color(0.7, 0.6, 0.45))
	survivor_detail_container.add_child(gear_name)

	# Gear desc
	var gear_desc = Label.new()
	gear_desc.name = "GearDesc"
	gear_desc.position = Vector2(590, 72)
	gear_desc.size = Vector2(250, 20)
	gear_desc.add_theme_font_size_override("font_size", 11)
	gear_desc.add_theme_color_override("font_color", Color(0.5, 0.4, 0.3))
	survivor_detail_container.add_child(gear_desc)

	# SIDEKICKS header
	var sk_hdr = Label.new()
	sk_hdr.name = "SidekicksHeader"
	sk_hdr.text = "SIDEKICKS (0/3)"
	sk_hdr.position = Vector2(510, 135)
	sk_hdr.size = Vector2(300, 30)
	sk_hdr.add_theme_font_size_override("font_size", 18)
	sk_hdr.add_theme_color_override("font_color", Color(0.75, 0.6, 0.35))
	survivor_detail_container.add_child(sk_hdr)

	# RELICS header
	var rel_hdr = Label.new()
	rel_hdr.name = "RelicsHeader"
	rel_hdr.text = "RELICS (0/6)"
	rel_hdr.position = Vector2(510, 255)
	rel_hdr.size = Vector2(300, 30)
	rel_hdr.add_theme_font_size_override("font_size", 18)
	rel_hdr.add_theme_color_override("font_color", Color(0.75, 0.6, 0.35))
	survivor_detail_container.add_child(rel_hdr)

	# Relic tooltip name
	var relic_tt_name = Label.new()
	relic_tt_name.name = "RelicTooltipName"
	relic_tt_name.position = Vector2(520, 350)
	relic_tt_name.size = Vector2(380, 22)
	relic_tt_name.add_theme_font_size_override("font_size", 13)
	relic_tt_name.add_theme_color_override("font_color", Color(0.85, 0.7, 0.4))
	relic_tt_name.visible = false
	survivor_detail_container.add_child(relic_tt_name)

	# Relic tooltip desc
	var relic_tt_desc = Label.new()
	relic_tt_desc.name = "RelicTooltipDesc"
	relic_tt_desc.position = Vector2(520, 368)
	relic_tt_desc.size = Vector2(380, 20)
	relic_tt_desc.add_theme_font_size_override("font_size", 11)
	relic_tt_desc.add_theme_color_override("font_color", Color(0.6, 0.5, 0.35))
	relic_tt_desc.visible = false
	survivor_detail_container.add_child(relic_tt_desc)

	# ABILITIES header
	var abil_hdr = Label.new()
	abil_hdr.name = "AbilitiesHeader"
	abil_hdr.text = "ABILITIES"
	abil_hdr.position = Vector2(510, 380)
	abil_hdr.size = Vector2(300, 30)
	abil_hdr.add_theme_font_size_override("font_size", 18)
	abil_hdr.add_theme_color_override("font_color", Color(0.75, 0.6, 0.35))
	survivor_detail_container.add_child(abil_hdr)

	# Abilities description
	var abil_desc = Label.new()
	abil_desc.name = "AbilitiesDesc"
	abil_desc.position = Vector2(510, 410)
	abil_desc.size = Vector2(600, 80)
	abil_desc.add_theme_font_size_override("font_size", 11)
	abil_desc.add_theme_color_override("font_color", Color(0.55, 0.45, 0.35))
	abil_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	survivor_detail_container.add_child(abil_desc)

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
	if cancel_button:
		cancel_button.visible = false
	if upgrade_panel:
		upgrade_panel.visible = false
	placing_tower = false
	chest_open = false
	chest_loot.clear()
	_deselect_tower()
	_remove_survivor_preview()
	_remove_detail_preview()
	_clear_grid_previews()
	survivor_grid_container.visible = false
	survivor_detail_container.visible = false
	survivor_detail_open = false
	survivor_selected_index = -1
	survivor_detail_index = -1
	menu_current_view = "chapters"
	menu_play_button.visible = false
	menu_left_arrow.visible = true
	menu_right_arrow.visible = true
	_update_menu_showcase()
	_start_music()
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

		chapter_title_labels[i].text = "Chapter %s â€” %s" % [chap_num[i], level["name"]]
		chapter_desc_labels[i].text = level["description"]
		chapter_stat_labels[i].text = "Gold: %d  |  Lives: %d" % [level["gold"], level["lives"]]

		# Stars
		if level_idx in completed_levels and level_stars.has(level_idx):
			var sv = level_stars[level_idx]
			var ss = ""
			for s in range(sv):
				ss += "â˜…"
			for s in range(3 - sv):
				ss += "â˜†"
			chapter_star_labels[i].text = ss
		else:
			chapter_star_labels[i].text = "â˜†â˜†â˜†"

		# Lock / difficulty buttons
		var unlocked = _is_level_unlocked(level_idx)
		if i < chapter_diff_buttons.size():
			for d in range(3):
				chapter_diff_buttons[i][d].disabled = not unlocked
				chapter_diff_buttons[i][d].visible = true
		chapter_lock_labels[i].text = diff_names[i]
		chapter_lock_labels[i].add_theme_color_override("font_color", diff_colors[i] if unlocked else Color(0.4, 0.35, 0.3))

		# Visibility
		chapter_title_labels[i].visible = true
		chapter_desc_labels[i].visible = true
		chapter_stat_labels[i].visible = true
		chapter_star_labels[i].visible = true
		chapter_lock_labels[i].visible = true
		if i < chapter_diff_buttons.size():
			for d in range(3):
				chapter_diff_buttons[i][d].visible = true

	# Arrow state
	menu_left_arrow.disabled = char_idx <= 0
	menu_right_arrow.disabled = char_idx >= 5

	# Update star total
	var total_stars = 0
	for key in level_stars:
		total_stars += level_stars[key]
	menu_star_total_label.text = "â˜… %d / %d" % [total_stars, levels.size() * 3]

func _hide_chapter_diff_buttons(chapter_idx: int) -> void:
	if chapter_idx < chapter_diff_buttons.size():
		for d in range(3):
			chapter_diff_buttons[chapter_idx][d].visible = false

func _on_chapter_play(chapter: int, difficulty: int = 0) -> void:
	selected_difficulty = difficulty
	var level_idx = menu_character_index * 3 + chapter
	_on_level_selected(level_idx)

func _on_menu_left() -> void:
	if menu_current_view == "survivors":
		return  # Grid doesn't use arrows
	else:
		if menu_character_index > 0:
			menu_character_index -= 1
			_update_menu_showcase()

func _on_menu_right() -> void:
	if menu_current_view == "survivors":
		return  # Grid doesn't use arrows
	else:
		if menu_character_index < 5:
			menu_character_index += 1
			_update_menu_showcase()

func _on_menu_play() -> void:
	pass  # Unused â€” chapter buttons handle play now

func _on_nav_pressed(nav_name: String) -> void:
	if menu_current_view == "survivors" and nav_name != "survivors":
		_remove_survivor_preview()
		_clear_grid_previews()
		_remove_detail_preview()
		survivor_grid_container.visible = false
		survivor_detail_container.visible = false
		survivor_detail_open = false
	menu_current_view = nav_name
	if nav_name == "chapters":
		menu_showcase_panel.visible = true
		survivor_grid_container.visible = false
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
			if i < chapter_diff_buttons.size():
				for d in range(3):
					chapter_diff_buttons[i][d].visible = true
		_update_menu_showcase()
	elif nav_name == "survivors":
		menu_showcase_panel.visible = false
		survivor_grid_container.visible = false
		survivor_detail_container.visible = false
		survivor_detail_open = false
		menu_play_button.visible = false
		menu_left_arrow.visible = false
		menu_right_arrow.visible = false
		# Hide chapter UI
		for i in range(3):
			chapter_title_labels[i].visible = false
			chapter_desc_labels[i].visible = false
			chapter_stat_labels[i].visible = false
			chapter_star_labels[i].visible = false
			chapter_lock_labels[i].visible = false
			_hide_chapter_diff_buttons(i)
		queue_redraw()
	elif nav_name == "relics":
		menu_showcase_panel.visible = false
		survivor_grid_container.visible = false
		menu_play_button.visible = false
		menu_left_arrow.visible = false
		menu_right_arrow.visible = false
		for i in range(3):
			chapter_title_labels[i].visible = false
			chapter_desc_labels[i].visible = false
			chapter_stat_labels[i].visible = false
			chapter_star_labels[i].visible = false
			chapter_lock_labels[i].visible = false
			_hide_chapter_diff_buttons(i)
		relics_tab_hover_tier = -1
		relics_tab_hover_row = -1
		relics_tab_hover_col = -1
		queue_redraw()
	elif nav_name == "emporium":
		menu_showcase_panel.visible = false
		survivor_grid_container.visible = false
		menu_play_button.visible = false
		menu_left_arrow.visible = false
		menu_right_arrow.visible = false
		for i in range(3):
			chapter_title_labels[i].visible = false
			chapter_desc_labels[i].visible = false
			chapter_stat_labels[i].visible = false
			chapter_star_labels[i].visible = false
			chapter_lock_labels[i].visible = false
			_hide_chapter_diff_buttons(i)
		emporium_hover_index = -1
		queue_redraw()
	else:
		menu_showcase_panel.visible = true
		survivor_grid_container.visible = false
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
			_hide_chapter_diff_buttons(i)

func _on_survivor_card_pressed(index: int) -> void:
	survivor_selected_index = index
	_open_survivor_detail(index)
	queue_redraw()

func _open_survivor_detail(index: int) -> void:
	survivor_detail_index = index
	survivor_detail_open = true
	survivor_grid_container.visible = false
	survivor_detail_container.visible = true
	_clear_grid_previews()

	# Create a preview of the tower for display
	_remove_detail_preview()
	var tower_type = survivor_types[index]
	survivor_detail_preview = tower_scenes[tower_type].instantiate()
	survivor_detail_preview.position = Vector2(280, 380)
	survivor_detail_preview.scale = Vector2(2.5, 2.5)
	survivor_detail_preview.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(survivor_detail_preview)

	# Populate labels
	var info = tower_info[tower_type]
	var progress = survivor_progress.get(tower_type, {"level": 1, "xp": 0.0, "xp_next": 500.0})
	var det_name_lbl = survivor_detail_container.get_node("DetailName")
	if det_name_lbl:
		det_name_lbl.text = info["name"]
	var det_level_lbl = survivor_detail_container.get_node("DetailLevel")
	if det_level_lbl:
		det_level_lbl.text = str(progress["level"])
	var det_xp_lbl = survivor_detail_container.get_node("DetailXP")
	if det_xp_lbl:
		det_xp_lbl.text = "Damage dealt to gain levels  %d / %d" % [int(progress["xp"]), int(progress["xp_next"])]
	var det_novel_lbl = survivor_detail_container.get_node("DetailNovel")
	if det_novel_lbl:
		det_novel_lbl.text = character_novels[index]
	var det_desc_lbl = survivor_detail_container.get_node("DetailDesc")
	if det_desc_lbl:
		det_desc_lbl.text = survivor_descriptions.get(tower_type, "")

	# Gear
	var gear_data = survivor_gear.get(tower_type, {"name": "Unknown", "desc": ""})
	var gear_name_lbl = survivor_detail_container.get_node("GearName")
	if gear_name_lbl:
		gear_name_lbl.text = gear_data["name"]
	var gear_desc_lbl = survivor_detail_container.get_node("GearDesc")
	if gear_desc_lbl:
		gear_desc_lbl.text = gear_data["desc"]

	# Sidekicks count
	var sk_count = 0
	for u in progress.get("sidekicks_unlocked", [false, false, false]):
		if u:
			sk_count += 1
	var sk_hdr = survivor_detail_container.get_node("SidekicksHeader")
	if sk_hdr:
		sk_hdr.text = "SIDEKICKS (%d/3)" % sk_count

	# Relics count
	var rel_count = 0
	for u in progress.get("relics_unlocked", [false, false, false, false, false, false]):
		if u:
			rel_count += 1
	var rel_hdr = survivor_detail_container.get_node("RelicsHeader")
	if rel_hdr:
		rel_hdr.text = "RELICS (%d/6)" % rel_count
	# Reset relic hover state
	relic_hover_index = -1
	relic_tooltip_visible = false
	var relic_tt_name_lbl = survivor_detail_container.get_node("RelicTooltipName")
	if relic_tt_name_lbl:
		relic_tt_name_lbl.visible = false
	var relic_tt_desc_lbl = survivor_detail_container.get_node("RelicTooltipDesc")
	if relic_tt_desc_lbl:
		relic_tt_desc_lbl.visible = false

	# Abilities
	var abil_desc_lbl = survivor_detail_container.get_node("AbilitiesDesc")
	if abil_desc_lbl and survivor_detail_preview:
		var tier_names = survivor_detail_preview.TIER_NAMES if survivor_detail_preview.get("TIER_NAMES") else []
		var tier_costs = survivor_detail_preview.TIER_COSTS if survivor_detail_preview.get("TIER_COSTS") else []
		var abil_text = ""
		for i in range(mini(tier_names.size(), tier_costs.size())):
			if i > 0:
				abil_text += "\n"
			abil_text += "Tier %d: %s (Cost: %d gold)" % [i + 1, tier_names[i], tier_costs[i]]
		abil_desc_lbl.text = abil_text

	queue_redraw()

func _on_detail_back() -> void:
	survivor_detail_open = false
	survivor_detail_container.visible = false
	survivor_grid_container.visible = false
	relic_hover_index = -1
	relic_tooltip_visible = false
	_remove_detail_preview()
	queue_redraw()

func _update_emporium_hover() -> void:
	var mouse_pos = get_viewport().get_mouse_position()
	var panel_x = 70.0
	var panel_y = 45.0
	var panel_w = 1140.0
	var tile_w = 340.0
	var tile_h = 220.0
	var gap_x = 30.0
	var gap_y = 24.0
	var grid_w = 3.0 * tile_w + 2.0 * gap_x
	var grid_start_x = panel_x + (panel_w - grid_w) * 0.5
	var grid_start_y = panel_y + 58.0
	emporium_hover_index = -1
	for i in range(6):
		var col_idx = i % 3
		var row = i / 3
		var tx = grid_start_x + float(col_idx) * (tile_w + gap_x)
		var ty = grid_start_y + float(row) * (tile_h + gap_y)
		if mouse_pos.x >= tx and mouse_pos.x <= tx + tile_w and mouse_pos.y >= ty and mouse_pos.y <= ty + tile_h:
			emporium_hover_index = i
			break

func _on_emporium_tile_clicked(index: int) -> void:
	if index < 0 or index >= emporium_categories.size():
		return
	var cat = emporium_categories[index]
	print("Emporium tile clicked: ", cat["name"])

func _update_relics_tab_hover() -> void:
	var mouse_pos = get_viewport().get_mouse_position()
	var grid_left = 88.0
	var section_y_base = 45.0 + 44.0  # panel_y + title offset
	var card_w = 176.0
	var card_h = 65.0
	var card_gap_x = 8.0
	var card_gap_y = 6.0
	relics_tab_hover_tier = -1
	relics_tab_hover_row = -1
	relics_tab_hover_col = -1
	for tier in range(3):
		var sec_y = section_y_base + float(tier) * 168.0
		var row_y = sec_y + 24.0
		for row in range(2):
			for col in range(6):
				var cx = grid_left + float(col) * (card_w + card_gap_x)
				var cy = row_y + float(row) * (card_h + card_gap_y)
				if mouse_pos.x >= cx and mouse_pos.x <= cx + card_w and mouse_pos.y >= cy and mouse_pos.y <= cy + card_h:
					relics_tab_hover_tier = tier
					relics_tab_hover_row = row
					relics_tab_hover_col = col
					return

func _update_relic_hover() -> void:
	if survivor_detail_index < 0 or survivor_detail_index >= survivor_types.size():
		return
	var mouse_pos = get_viewport().get_mouse_position()
	var panel_x = 70.0
	var panel_y = 45.0
	var left_w = 420.0
	var right_x = panel_x + left_w + 50.0
	var right_y = panel_y + 60.0
	var gear_y = right_y
	var sk_y = gear_y + 120.0
	var rel_y = sk_y + 120.0
	var slot_size = 64.0
	var relic_size = 56.0
	var tower_type = survivor_types[survivor_detail_index]
	var char_relics = survivor_relics.get(tower_type, [])
	var old_hover = relic_hover_index
	relic_hover_index = -1
	for ri in range(6):
		var rx = right_x + 10.0 + float(ri) * (relic_size + 10.0)
		var ry = rel_y + 30.0
		if mouse_pos.x >= rx and mouse_pos.x <= rx + relic_size and mouse_pos.y >= ry and mouse_pos.y <= ry + relic_size:
			relic_hover_index = ri
			break
	# Update tooltip labels
	if relic_hover_index != old_hover:
		var relic_tt_name_lbl = survivor_detail_container.get_node("RelicTooltipName")
		var relic_tt_desc_lbl = survivor_detail_container.get_node("RelicTooltipDesc")
		if relic_hover_index >= 0 and relic_hover_index < char_relics.size():
			var relic_data = char_relics[relic_hover_index]
			var progress = survivor_progress.get(tower_type, {})
			var rel_unlocked = progress.get("relics_unlocked", [false, false, false, false, false, false])
			var is_unlocked = rel_unlocked[relic_hover_index] if relic_hover_index < rel_unlocked.size() else false
			var relic_purchasable = [false, true, false, true, false, true]
			var relic_costs = [0, 100, 0, 250, 0, 500]
			var relic_earn_levels = [2, 4, 6, 8, 10, 12]
			var char_level = progress.get("level", 1)
			var name_text = relic_data["name"]
			if is_unlocked:
				name_text += "  [OWNED]"
			elif relic_purchasable[relic_hover_index] and char_level >= relic_earn_levels[relic_hover_index]:
				name_text += "  [BUY: %d gold]" % relic_costs[relic_hover_index]
			elif char_level < relic_earn_levels[relic_hover_index]:
				name_text += "  [Lv.%d]" % relic_earn_levels[relic_hover_index]
			if relic_tt_name_lbl:
				relic_tt_name_lbl.text = name_text
				relic_tt_name_lbl.visible = true
			if relic_tt_desc_lbl:
				relic_tt_desc_lbl.text = relic_data["desc"]
				relic_tt_desc_lbl.visible = true
			relic_tooltip_visible = true
		else:
			if relic_tt_name_lbl:
				relic_tt_name_lbl.visible = false
			if relic_tt_desc_lbl:
				relic_tt_desc_lbl.visible = false
			relic_tooltip_visible = false

func _on_relic_clicked(relic_index: int) -> void:
	if survivor_detail_index < 0 or survivor_detail_index >= survivor_types.size():
		return
	var tower_type = survivor_types[survivor_detail_index]
	var progress = survivor_progress.get(tower_type, {})
	var rel_unlocked = progress.get("relics_unlocked", [false, false, false, false, false, false])
	if relic_index < 0 or relic_index >= rel_unlocked.size():
		return
	if rel_unlocked[relic_index]:
		return  # Already unlocked
	var relic_purchasable = [false, true, false, true, false, true]
	var relic_costs = [0, 100, 0, 250, 0, 500]
	var relic_earn_levels = [2, 4, 6, 8, 10, 12]
	var char_level = progress.get("level", 1)
	if not relic_purchasable[relic_index]:
		return  # Not purchasable, only earned by level
	if char_level < relic_earn_levels[relic_index]:
		return  # Level too low
	var cost = relic_costs[relic_index]
	if gold < cost:
		return  # Can't afford
	gold -= cost
	progress["relics_unlocked"][relic_index] = true
	# Refresh the detail page
	_open_survivor_detail(survivor_detail_index)

func _remove_detail_preview() -> void:
	if survivor_detail_preview and is_instance_valid(survivor_detail_preview):
		survivor_detail_preview.queue_free()
		survivor_detail_preview = null

func _remove_survivor_preview() -> void:
	_remove_detail_preview()
	_clear_grid_previews()
	if survivor_preview_node and is_instance_valid(survivor_preview_node):
		survivor_preview_node.queue_free()
		survivor_preview_node = null

func _spawn_grid_previews() -> void:
	_clear_grid_previews()
	var card_w = 310.0
	var card_h = 210.0
	var grid_margin_x = 65.0
	var grid_margin_y = 65.0
	var gap_x = 40.0
	var gap_y = 30.0
	var panel_x = 70.0
	var panel_y = 45.0
	for i in range(6):
		var col_i = i % 3
		var row_i = i / 3
		var cx = panel_x + grid_margin_x + float(col_i) * (card_w + gap_x)
		var cy = panel_y + grid_margin_y + float(row_i) * (card_h + gap_y)
		var tower_type = survivor_types[i]
		var preview = tower_scenes[tower_type].instantiate()
		preview.position = Vector2(cx + 70, cy + 115)
		preview.scale = Vector2(1.8, 1.8)
		preview.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(preview)
		survivor_grid_previews.append(preview)

func _clear_grid_previews() -> void:
	for p in survivor_grid_previews:
		if is_instance_valid(p):
			p.queue_free()
	survivor_grid_previews.clear()

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
	_remove_survivor_preview()
	current_level = index
	_reset_game()
	var level = levels[index]
	gold = level["gold"] + difficulty_gold_bonus[selected_difficulty]
	lives = max(10, level["lives"] + difficulty_lives_bonus[selected_difficulty])
	total_waves = difficulty_waves[selected_difficulty]
	_setup_path_for_level(index)
	_generate_decorations_for_level(index)
	_stop_music()
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
	var diff_name = ["Easy", "Medium", "Hard"][selected_difficulty]
	info_label.text = level["name"] + " (%s) - Place your towers!" % diff_name
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
	# Reset session damage tracking
	for t in survivor_types:
		session_damage[t] = 0.0

func _setup_path_for_level(index: int) -> void:
	var curve = enemy_path.curve
	if not curve:
		return
	curve.clear_points()
	match index:
		0: # Robin Hood Ch1 â€” gentle S-curves through forest clearings
			curve.add_point(Vector2(-50, 300), Vector2.ZERO, Vector2(100, 0))
			curve.add_point(Vector2(200, 300), Vector2(-60, 0), Vector2(60, -100))
			curve.add_point(Vector2(320, 150), Vector2(0, 60), Vector2(100, 0))
			curve.add_point(Vector2(580, 200), Vector2(-80, 0), Vector2(80, 80))
			curve.add_point(Vector2(640, 420), Vector2(0, -80), Vector2(80, 0))
			curve.add_point(Vector2(880, 380), Vector2(-80, 0), Vector2(60, -80))
			curve.add_point(Vector2(960, 180), Vector2(0, 60), Vector2(100, 0))
			curve.add_point(Vector2(1330, 250))
		1: # Robin Hood Ch2 â€” deeper forest, river crossing
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
		2: # Robin Hood Ch3 â€” castle siege approach
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
		3: # Alice Ch1 â€” zigzag down like falling
			curve.add_point(Vector2(100, -50), Vector2.ZERO, Vector2(0, 80))
			curve.add_point(Vector2(200, 140), Vector2(-40, -40), Vector2(120, 0))
			curve.add_point(Vector2(500, 120), Vector2(-80, 0), Vector2(0, 100))
			curve.add_point(Vector2(400, 340), Vector2(40, -60), Vector2(-100, 0))
			curve.add_point(Vector2(160, 380), Vector2(80, 0), Vector2(0, 80))
			curve.add_point(Vector2(300, 520), Vector2(-60, 0), Vector2(120, 0))
			curve.add_point(Vector2(700, 480), Vector2(-100, 0), Vector2(100, 0))
			curve.add_point(Vector2(1000, 540), Vector2(-80, 0), Vector2(80, 0))
			curve.add_point(Vector2(1330, 580))
		4: # Alice Ch2 â€” mad tea party grounds, chess board
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
		5: # Alice Ch3 â€” queen's palace approach
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
		6: # Oz Ch1 â€” yellow brick road with angular turns
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
		7: # Oz Ch2 â€” dark witch territory
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
		8: # Oz Ch3 â€” inside emerald city
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
		9: # Peter Pan Ch1 â€” Neverland
			curve.add_point(Vector2(-50, 360), Vector2.ZERO, Vector2(80, 0))
			curve.add_point(Vector2(160, 360), Vector2(-40, 0), Vector2(40, -80))
			curve.add_point(Vector2(160, 140), Vector2(0, 80), Vector2(100, 0))
			curve.add_point(Vector2(480, 140), Vector2(-100, 0), Vector2(0, 100))
			curve.add_point(Vector2(480, 520), Vector2(0, -100), Vector2(100, 0))
			curve.add_point(Vector2(800, 520), Vector2(-100, 0), Vector2(0, -100))
			curve.add_point(Vector2(800, 200), Vector2(0, 100), Vector2(100, 0))
			curve.add_point(Vector2(1330, 200))
		10: # Peter Pan Ch2 â€” dense jungle, lost boys hideout
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
		11: # Peter Pan Ch3 â€” pirate ship approach
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
		12: # Phantom Ch1 â€” descend in tight switchbacks
			curve.add_point(Vector2(640, -50), Vector2.ZERO, Vector2(0, 80))
			curve.add_point(Vector2(640, 160), Vector2(0, -40), Vector2(-120, 0))
			curve.add_point(Vector2(160, 160), Vector2(80, 0), Vector2(0, 80))
			curve.add_point(Vector2(160, 400), Vector2(0, -80), Vector2(120, 0))
			curve.add_point(Vector2(1100, 400), Vector2(-120, 0), Vector2(0, 60))
			curve.add_point(Vector2(1100, 560), Vector2(0, -40), Vector2(-120, 0))
			curve.add_point(Vector2(640, 670))
		13: # Phantom Ch2 â€” underground labyrinth
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
		14: # Phantom Ch3 â€” deep underground lair
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
		15: # Scrooge Ch1 â€” wind through city blocks
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
		16: # Scrooge Ch2 â€” midnight graveyard
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
		17: # Scrooge Ch3 â€” christmas morning streets
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
# AUDIO â€” Procedural hip hop beat + character voice clips
# ============================================================
func _setup_audio() -> void:
	# Menu music player (shuffle playlist of gothic piano tracks)
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -6.0
	add_child(music_player)
	music_player.finished.connect(_on_music_finished)
	_load_music_tracks()

	# Voice player (one-shot clips via AudioStreamWAV — formant "character flavor")
	voice_player = AudioStreamPlayer.new()
	voice_player.volume_db = -2.0
	add_child(voice_player)
	_generate_voice_clips()
	_init_tower_quotes()

	# Catchphrase voice player (MP3 voice-over clips)
	catchphrase_player = AudioStreamPlayer.new()
	catchphrase_player.volume_db = -2.0
	add_child(catchphrase_player)
	_load_voice_clips()
	_init_catchphrase_quotes()

func _load_music_tracks() -> void:
	var track_paths = [
		"res://audio/music/vampires_piano.mp3",
		"res://audio/music/haunting_piano.mp3",
		"res://audio/music/haunted_track_minor.mp3",
		"res://audio/music/cold_silence.ogg",
		"res://audio/music/dark_rooms.mp3",
	]
	for path in track_paths:
		if ResourceLoader.exists(path):
			var track = load(path)
			if track:
				music_tracks.append(track)
	# Shuffle on load
	music_tracks.shuffle()

func _start_music() -> void:
	if music_tracks.size() == 0:
		return
	music_playing = true
	_play_next_track()

func _stop_music() -> void:
	music_player.stop()
	music_playing = false

func _play_next_track() -> void:
	if music_tracks.size() == 0:
		return
	music_player.stream = music_tracks[music_index]
	music_player.play()
	music_index = (music_index + 1) % music_tracks.size()
	# Reshuffle when we've cycled through all tracks
	if music_index == 0:
		music_tracks.shuffle()

func _on_music_finished() -> void:
	if music_playing:
		_play_next_track()

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

func _generate_formant_voice(fundamental: float, formants: Array, syllable_count: int,
		duration: float, breathiness: float, vibrato_rate: float, vibrato_depth: float) -> AudioStreamWAV:
	var rate := 22050
	var num_samples := int(rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(num_samples)
	var syllable_len := num_samples / syllable_count
	var gap_samples := int(rate * 0.02)  # 20ms inter-syllable gap

	for i in range(num_samples):
		var t := float(i) / float(rate)
		var syl_idx := mini(i / syllable_len, syllable_count - 1)
		var syl_offset := i - syl_idx * syllable_len
		var syl_t := float(syl_offset) / float(syllable_len)

		# Inter-syllable gap
		if syl_offset >= syllable_len - gap_samples:
			samples[i] = 0.0
			continue

		# Per-syllable amplitude envelope (attack-sustain-decay)
		var syl_dur := float(syllable_len - gap_samples) / float(rate)
		var syl_time := float(syl_offset) / float(rate)
		var env := 1.0
		var attack_t := 0.015
		if syl_time < attack_t:
			env = syl_time / attack_t
		elif syl_time > syl_dur * 0.6:
			env = clampf(1.0 - (syl_time - syl_dur * 0.6) / (syl_dur * 0.4), 0.0, 1.0)

		# F0 with vibrato
		var f0 := fundamental + sin(TAU * vibrato_rate * t) * vibrato_depth
		# Slight pitch variation per syllable for naturalness
		f0 *= 1.0 + sin(float(syl_idx) * 2.7) * 0.04

		# Glottal pulse train (fundamental + harmonics 2-5)
		var glottal := sin(TAU * f0 * t)
		glottal += sin(TAU * f0 * 2.0 * t) * 0.6
		glottal += sin(TAU * f0 * 3.0 * t) * 0.35
		glottal += sin(TAU * f0 * 4.0 * t) * 0.2
		glottal += sin(TAU * f0 * 5.0 * t) * 0.1

		# Breathiness noise component
		var noise := (randf() * 2.0 - 1.0) * breathiness

		# Pick formant vowel for this syllable (cycle through provided formants)
		var vowel: Array = formants[syl_idx % formants.size()]
		# Formant resonance (sinusoids at F1/F2/F3)
		var formant_signal := sin(TAU * vowel[0] * t) * 0.5
		formant_signal += sin(TAU * vowel[1] * t) * 0.35
		formant_signal += sin(TAU * vowel[2] * t) * 0.15

		# Mix glottal source with formant coloring
		var s := (glottal * 0.4 + formant_signal * 0.4 + noise * 0.2) * env

		# Overall fade in/out
		var fade_in := clampf(t / 0.03, 0.0, 1.0)
		var fade_out := clampf((duration - t) / 0.05, 0.0, 1.0)
		samples[i] = clampf(s * fade_in * fade_out * 0.55, -1.0, 1.0)

	return _samples_to_wav(samples, rate)

func _generate_voice_clips() -> void:
	# Robin Hood — confident baritone (F0=145Hz)
	# Vowels: ah=[730,1090,2440], oh=[570,840,2410], eh=[530,1840,2480]
	voice_clips[TowerType.ROBIN_HOOD] = _generate_formant_voice(
		145.0, [[730,1090,2440], [570,840,2410], [530,1840,2480]],
		5, 0.7, 0.10, 5.5, 4.0)

	# Alice — bright curious girl (F0=280Hz)
	# Vowels: ee=[270,2290,3010], eh=[530,1840,2480], ah=[730,1090,2440]
	voice_clips[TowerType.ALICE] = _generate_formant_voice(
		280.0, [[270,2290,3010], [530,1840,2480], [730,1090,2440], [270,2290,3010]],
		6, 0.65, 0.25, 6.0, 6.0)

	# Wicked Witch — raspy nasal cackle (F0=240Hz)
	# Vowels: ae=[660,1720,2410], oo=[300,870,2240], eh=[530,1840,2480]
	voice_clips[TowerType.WICKED_WITCH] = _generate_formant_voice(
		240.0, [[660,1720,2410], [300,870,2240], [530,1840,2480], [660,1720,2410]],
		5, 0.7, 0.35, 4.0, 8.0)

	# Peter Pan — energetic boy (F0=220Hz)
	# Vowels: ee=[270,2290,3010], ah=[730,1090,2440], ih=[390,1990,2550]
	voice_clips[TowerType.PETER_PAN] = _generate_formant_voice(
		220.0, [[270,2290,3010], [730,1090,2440], [390,1990,2550]],
		7, 0.55, 0.15, 7.0, 5.0)

	# Phantom — deep operatic bass (F0=120Hz)
	# Vowels: ah=[730,1090,2440], oh=[570,840,2410], oo=[300,870,2240]
	voice_clips[TowerType.PHANTOM] = _generate_formant_voice(
		120.0, [[730,1090,2440], [570,840,2410], [300,870,2240]],
		4, 0.8, 0.08, 4.5, 3.0)

	# Scrooge — thin reedy warble (F0=165Hz)
	# Vowels: ah=[730,1090,2440], eh=[530,1840,2480], uh=[640,1190,2390]
	voice_clips[TowerType.SCROOGE] = _generate_formant_voice(
		165.0, [[730,1090,2440], [530,1840,2480], [640,1190,2390], [730,1090,2440]],
		5, 0.6, 0.40, 3.5, 7.0)

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

func _load_voice_clips() -> void:
	var character_dirs = {
		TowerType.ROBIN_HOOD: "robin_hood",
		TowerType.ALICE: "alice",
		TowerType.WICKED_WITCH: "wicked_witch",
		TowerType.PETER_PAN: "peter_pan",
		TowerType.PHANTOM: "phantom",
		TowerType.SCROOGE: "scrooge",
	}
	for tower_type in character_dirs:
		var dir_name: String = character_dirs[tower_type]
		var place_clips: Array = []
		var fight_clips: Array = []
		for i in range(4):
			var place_path = "res://audio/voices/" + dir_name + "/place_" + str(i) + ".mp3"
			if ResourceLoader.exists(place_path):
				place_clips.append(load(place_path))
			var fight_path = "res://audio/voices/" + dir_name + "/fight_" + str(i) + ".mp3"
			if ResourceLoader.exists(fight_path):
				fight_clips.append(load(fight_path))
		if place_clips.size() > 0:
			placement_voice_clips[tower_type] = place_clips
		if fight_clips.size() > 0:
			fighting_voice_clips[tower_type] = fight_clips

func _init_catchphrase_quotes() -> void:
	placement_quotes = {
		TowerType.ROBIN_HOOD: [
			"Rob the rich to feed the poor!",
			"I am Robin Hood!",
			"Come, come, my merry men all!",
			"Robin Hood, at your service.",
		],
		TowerType.ALICE: [
			"Curiouser and curiouser!",
			"Who in the world am I? Ah, that's the great puzzle.",
			"Down the rabbit hole we go!",
			"We're all mad here, you know.",
		],
		TowerType.WICKED_WITCH: [
			"I'll get you, my pretty, and your little dog too!",
			"Surrender, Dorothy!",
			"Fly, my pretties, fly!",
			"Now I shall have those silver shoes!",
		],
		TowerType.PETER_PAN: [
			"I'm youth, I'm joy, I'm a little bird that has broken out of the egg!",
			"I don't want ever to be a man!",
			"To die will be an awfully big adventure!",
			"I'll never grow up!",
		],
		TowerType.PHANTOM: [
			"I am your Angel of Music.",
			"The Music of the Night!",
			"The Opera Ghost is here.",
			"If I am the Phantom, it is because man's hatred has made me so.",
		],
		TowerType.SCROOGE: [
			"Bah! Humbug!",
			"Are there no prisons? No workhouses?",
			"I wish to be left alone.",
			"Every penny counts!",
		],
	}
	fighting_quotes = {
		TowerType.ROBIN_HOOD: [
			"For Sherwood!",
			"My arrows fly true!",
			"Steal from the rich, defend the path!",
			"Another shot for the poor!",
		],
		TowerType.ALICE: [
			"Off with their heads!",
			"How puzzling all these changes are!",
			"I could tell you my adventures, beginning from this morning.",
			"It would be so nice if something made sense for a change.",
		],
		TowerType.WICKED_WITCH: [
			"How about a little fire?",
			"I'll use the Golden Cap!",
			"You cursed brat!",
			"My beautiful wickedness!",
		],
		TowerType.PETER_PAN: [
			"I do believe in fairies!",
			"Second star to the right!",
			"Wendy, one girl is more use than twenty boys!",
			"Oh, the cleverness of me!",
		],
		TowerType.PHANTOM: [
			"Sing for me!",
			"I am dying of love!",
			"The chandelier! Beware the chandelier!",
			"Your most obedient servant, the Opera Ghost.",
		],
		TowerType.SCROOGE: [
			"Humbug!",
			"I will honour Christmas in my heart!",
			"Every idiot who goes about with Merry Christmas on his lips!",
			"God bless us, every one!",
		],
	}

func _play_placement_catchphrase(tower_type: TowerType) -> String:
	# Play MP3 voice clip if available
	if placement_voice_clips.has(tower_type):
		var clips: Array = placement_voice_clips[tower_type]
		catchphrase_player.stream = clips[randi() % clips.size()]
		catchphrase_player.play()
	# Return text quote for display
	if placement_quotes.has(tower_type):
		var quotes: Array = placement_quotes[tower_type]
		return quotes[randi() % quotes.size()]
	return _get_tower_quote(tower_type)

func _play_random_fighting_quote() -> void:
	# Pick a random placed tower type that has fighting clips
	var placed_types: Array = []
	for tower_type in fighting_voice_clips:
		if purchased_towers.has(tower_type):
			placed_types.append(tower_type)
	if placed_types.size() == 0:
		return
	var chosen_type = placed_types[randi() % placed_types.size()]
	var clips: Array = fighting_voice_clips[chosen_type]
	catchphrase_player.stream = clips[randi() % clips.size()]
	catchphrase_player.play()
	# Also display quote text
	if fighting_quotes.has(chosen_type):
		var quotes: Array = fighting_quotes[chosen_type]
		var tname = tower_info[chosen_type]["name"]
		var quote = quotes[randi() % quotes.size()]
		info_label.text = "%s: \"%s\"" % [tname, quote]

func _draw_menu_background() -> void:
	if menu_current_view != "survivors" or survivor_detail_open:
		# === Deep navy background ===
		draw_rect(Rect2(0, 0, 1280, 720), menu_bg_dark)
		# Subtle navy/indigo striations
		for y in range(0, 720, 3):
			var t = float(y) / 720.0
			var grain = sin(float(y) * 0.8 + cos(float(y) * 0.3) * 4.0) * 0.008
			var col = Color(0.05 + grain, 0.05 + grain * 0.8, 0.12 + grain * 1.5)
			draw_line(Vector2(0, y), Vector2(1280, y), col, 3.0)

		# === Subtle gold vignette glow at corners ===
		draw_circle(Vector2(0, 0), 350.0, Color(menu_gold_dim.r, menu_gold_dim.g, menu_gold_dim.b, 0.04))
		draw_circle(Vector2(1280, 0), 350.0, Color(menu_gold_dim.r, menu_gold_dim.g, menu_gold_dim.b, 0.04))
		draw_circle(Vector2(0, 720), 350.0, Color(menu_gold_dim.r, menu_gold_dim.g, menu_gold_dim.b, 0.04))
		draw_circle(Vector2(1280, 720), 350.0, Color(menu_gold_dim.r, menu_gold_dim.g, menu_gold_dim.b, 0.04))

		# === Warm ambient candle glow (softer, no crimson) ===
		for candle in _book_candle_positions:
			var cx_pos = candle["x"]
			var cy_pos = candle["y"]
			var flicker = sin(_time * 5.0 + candle["offset"]) * 0.3 + sin(_time * 8.0 + candle["offset"] * 2.0) * 0.15
			var glow_r = 80.0 + flicker * 15.0
			draw_circle(Vector2(cx_pos, cy_pos), glow_r, Color(0.85, 0.55, 0.1, 0.015 + flicker * 0.005))
			draw_circle(Vector2(cx_pos, cy_pos), glow_r * 0.5, Color(0.9, 0.6, 0.15, 0.02 + flicker * 0.007))
			# Candle body
			draw_rect(Rect2(cx_pos - 4, cy_pos + 10, 8, 22), Color(0.85, 0.82, 0.7, 0.5))
			var flame_h = 7.0 + flicker * 4.0
			draw_circle(Vector2(cx_pos, cy_pos + 6 - flame_h * 0.3), 3.5, Color(1.0, 0.7, 0.2, 0.6 + flicker * 0.2))
			draw_circle(Vector2(cx_pos, cy_pos + 4 - flame_h * 0.5), 2.0, Color(1.0, 0.9, 0.5, 0.7 + flicker * 0.15))

		# === Floating dust motes (gold) ===
		for dust in _dust_positions:
			var dx = dust["x"] + sin(_time * dust["speed"] + dust["offset"]) * 30.0
			var dy = dust["y"] + cos(_time * dust["speed"] * 0.6 + dust["offset"]) * 20.0
			var alpha = 0.15 + 0.15 * sin(_time * 1.5 + dust["offset"])
			draw_circle(Vector2(dx, dy), dust["size"], Color(menu_gold.r, menu_gold.g, menu_gold.b, alpha))

	# === Bottom nav bar drawn enhancements ===
	var nav_draw_y = 620.0
	# Active tab gold glowing underline
	var nav_tab_names = ["survivors", "relics", "chapters", "chronicles", "emporium"]
	for ni in range(5):
		var nav_bx = 64.0 + float(ni) * 240.0
		if menu_current_view == nav_tab_names[ni]:
			var glow_a = 0.4 + sin(_time * 2.5) * 0.15
			draw_rect(Rect2(nav_bx - 5, nav_draw_y + 88, 80, 3), Color(menu_gold.r, menu_gold.g, menu_gold.b, glow_a))
			draw_rect(Rect2(nav_bx - 2, nav_draw_y + 91, 74, 1), Color(menu_gold_light.r, menu_gold_light.g, menu_gold_light.b, glow_a * 0.5))
		# Diamond at center of divider lines
		if ni < 4:
			var ddx = nav_bx + 155.0
			var ddy = nav_draw_y + 44.0
			draw_colored_polygon(PackedVector2Array([Vector2(ddx, ddy - 3), Vector2(ddx + 3, ddy), Vector2(ddx, ddy + 3), Vector2(ddx - 3, ddy)]), Color(0.65, 0.45, 0.1, 0.25))

	if menu_current_view == "chapters":
		_draw_open_book()
	elif menu_current_view == "survivors":
		if survivor_detail_open:
			_draw_survivor_detail()
		else:
			_draw_world_map()
	elif menu_current_view == "relics":
		_draw_relics_tab()
	elif menu_current_view == "emporium":
		_draw_emporium()
	else:
		_draw_closed_book()

func _draw_relics_tab() -> void:
	var panel_x = 70.0
	var panel_y = 45.0
	var panel_w = 1140.0
	var panel_h = 560.0
	var font = ThemeDB.fallback_font

	# Navy background gradient
	for i in range(56):
		var t = float(i) / 55.0
		var col = menu_bg_section.lerp(menu_bg_dark, t)
		draw_rect(Rect2(panel_x, panel_y + float(i) * 10.0, panel_w, 10.0), col)

	# Gold border
	draw_rect(Rect2(panel_x, panel_y, panel_w, 2), Color(menu_gold_dim.r, menu_gold_dim.g, menu_gold_dim.b, 0.4))
	draw_rect(Rect2(panel_x, panel_y + panel_h - 2, panel_w, 2), Color(menu_gold_dim.r, menu_gold_dim.g, menu_gold_dim.b, 0.4))
	draw_rect(Rect2(panel_x, panel_y, 2, panel_h), Color(menu_gold_dim.r, menu_gold_dim.g, menu_gold_dim.b, 0.4))
	draw_rect(Rect2(panel_x + panel_w - 2, panel_y, 2, panel_h), Color(menu_gold_dim.r, menu_gold_dim.g, menu_gold_dim.b, 0.4))

	# Title
	draw_string(font, Vector2(panel_x + panel_w * 0.5 - 80, panel_y + 28), "RELICS COMPENDIUM", HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(menu_gold_light.r, menu_gold_light.g, menu_gold_light.b, 0.9))
	# Title underline
	draw_rect(Rect2(panel_x + panel_w * 0.5 - 100, panel_y + 34, 200, 1), Color(menu_gold.r, menu_gold.g, menu_gold.b, 0.4))

	var char_names = ["Robin Hood", "Alice", "Wicked Witch", "Peter Pan", "Phantom", "Scrooge"]
	var char_accents = [
		Color(0.29, 0.55, 0.25),  # Robin - forest green
		Color(0.44, 0.66, 0.86),  # Alice - sky blue
		Color(0.48, 0.25, 0.63),  # Witch - purple
		Color(0.90, 0.49, 0.13),  # Peter - orange
		Color(0.75, 0.22, 0.17),  # Phantom - crimson
		Color(0.79, 0.66, 0.30),  # Scrooge - gold
	]

	# Tier definitions: indices into each character's 6-relic array
	# Tier 1 (blue):  relics 0,1 — basic abilities
	# Tier 2 (purple): relics 2,3 — intermediate
	# Tier 3 (gold):  relics 4,5 — most powerful
	var tier_indices = [[0, 1], [2, 3], [4, 5]]
	var tier_names = ["TIER I — Common", "TIER II — Rare", "TIER III — Legendary"]
	var tier_colors = [
		Color(0.3, 0.5, 0.85),   # Blue
		Color(0.6, 0.3, 0.8),    # Purple
		Color(0.85, 0.7, 0.2),   # Gold
	]
	var tier_bg_tints = [
		Color(0.08, 0.12, 0.25), # Blue tint
		Color(0.14, 0.08, 0.22), # Purple tint
		Color(0.18, 0.15, 0.08), # Gold tint
	]

	var card_w = 176.0
	var card_h = 65.0
	var card_gap_x = 8.0
	var card_gap_y = 6.0
	var grid_left = panel_x + 18.0
	var section_y = panel_y + 44.0  # Start below title

	for tier in range(3):
		var tc = tier_colors[tier]
		var sec_y = section_y + float(tier) * 168.0

		# Tier header bar
		draw_rect(Rect2(grid_left, sec_y, panel_w - 36, 20), Color(tc.r, tc.g, tc.b, 0.12))
		draw_rect(Rect2(grid_left, sec_y, panel_w - 36, 1), Color(tc.r, tc.g, tc.b, 0.4))
		draw_string(font, Vector2(grid_left + 10, sec_y + 14), tier_names[tier], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(tc.r, tc.g, tc.b, 0.9))

		# Tier gem icon (small diamond)
		var gem_x = grid_left + panel_w - 56
		var gem_y = sec_y + 10
		draw_colored_polygon(PackedVector2Array([Vector2(gem_x, gem_y - 5), Vector2(gem_x + 5, gem_y), Vector2(gem_x, gem_y + 5), Vector2(gem_x - 5, gem_y)]), Color(tc.r, tc.g, tc.b, 0.7))

		var row_y = sec_y + 24.0
		var relic_pair = tier_indices[tier]  # e.g. [0,1], [2,3], [4,5]

		for row in range(2):
			for col in range(6):
				var tower_type = survivor_types[col]
				var relic_idx = relic_pair[row]
				var char_relics = survivor_relics.get(tower_type, [])
				if relic_idx >= char_relics.size():
					continue
				var relic = char_relics[relic_idx]
				var progress = survivor_progress.get(tower_type, {})
				var relics_unlocked = progress.get("relics_unlocked", [false, false, false, false, false, false])
				var is_unlocked = relics_unlocked[relic_idx] if relic_idx < relics_unlocked.size() else false

				var cx = grid_left + float(col) * (card_w + card_gap_x)
				var cy = row_y + float(row) * (card_h + card_gap_y)
				var is_hovered = relics_tab_hover_tier == tier and relics_tab_hover_row == row and relics_tab_hover_col == col

				# Card background
				var bg_col = tier_bg_tints[tier] if is_unlocked else Color(0.05, 0.05, 0.10)
				if is_hovered:
					bg_col = bg_col.lightened(0.15)
				draw_rect(Rect2(cx, cy, card_w, card_h), bg_col)

				# Card border — tier color if unlocked, dim if locked, brighter on hover
				var b_alpha = 0.5 if is_unlocked else 0.15
				if is_hovered:
					b_alpha = 0.8
				var border_col = Color(tc.r, tc.g, tc.b, b_alpha)
				draw_rect(Rect2(cx, cy, card_w, 1), border_col)
				draw_rect(Rect2(cx, cy + card_h - 1, card_w, 1), border_col)
				draw_rect(Rect2(cx, cy, 1, card_h), border_col)
				draw_rect(Rect2(cx + card_w - 1, cy, 1, card_h), border_col)

				# Character accent stripe on left edge
				var accent = char_accents[col]
				draw_rect(Rect2(cx, cy, 3, card_h), Color(accent.r, accent.g, accent.b, 0.7 if is_unlocked else 0.2))

				# Relic icon area (50x50 centered in left portion)
				var icon_cx = cx + 30.0
				var icon_cy = cy + card_h * 0.5
				if is_unlocked:
					_draw_relic_icon(Vector2(icon_cx, icon_cy), relic["icon"], 40.0, accent)
				else:
					# Locked: draw a lock silhouette
					draw_rect(Rect2(icon_cx - 8, icon_cy - 4, 16, 14), Color(0.3, 0.3, 0.35, 0.4))
					draw_arc(Vector2(icon_cx, icon_cy - 4), 7, PI, TAU, 12, Color(0.3, 0.3, 0.35, 0.4), 2.0)

				# Text area
				var tx = cx + 56.0
				var max_text_w = int(card_w - 60)

				# Relic name
				var name_alpha = 0.9 if is_unlocked else 0.35
				draw_string(font, Vector2(tx, cy + 16), relic["name"], HORIZONTAL_ALIGNMENT_LEFT, max_text_w, 10, Color(tc.r, tc.g, tc.b, name_alpha))

				# Effect description
				var desc_alpha = 0.65 if is_unlocked else 0.25
				var desc_text = relic["desc"]
				if desc_text.length() > 28:
					desc_text = desc_text.substr(0, 26) + ".."
				draw_string(font, Vector2(tx, cy + 30), desc_text, HORIZONTAL_ALIGNMENT_LEFT, max_text_w, 8, Color(menu_text.r, menu_text.g, menu_text.b, desc_alpha))

				# Character name (small, bottom)
				var char_alpha = 0.5 if is_unlocked else 0.2
				draw_string(font, Vector2(tx, cy + 44), char_names[col], HORIZONTAL_ALIGNMENT_LEFT, max_text_w, 8, Color(accent.r, accent.g, accent.b, char_alpha))

				# Effect value badge (bottom-right)
				if is_unlocked:
					var effect_text = relic["effect"].replace("_", " ")
					draw_string(font, Vector2(cx + card_w - 58, cy + 58), effect_text, HORIZONTAL_ALIGNMENT_RIGHT, 54, 7, Color(tc.r, tc.g, tc.b, 0.4))

	# Hover tooltip (drawn on top)
	if relics_tab_hover_tier >= 0 and relics_tab_hover_col >= 0:
		var h_tier = relics_tab_hover_tier
		var h_row = relics_tab_hover_row
		var h_col = relics_tab_hover_col
		var h_tower = survivor_types[h_col]
		var h_relic_idx = tier_indices[h_tier][h_row]
		var h_relics = survivor_relics.get(h_tower, [])
		if h_relic_idx < h_relics.size():
			var h_relic = h_relics[h_relic_idx]
			var h_progress = survivor_progress.get(h_tower, {})
			var h_unlocked_arr = h_progress.get("relics_unlocked", [false, false, false, false, false, false])
			var h_unlocked = h_unlocked_arr[h_relic_idx] if h_relic_idx < h_unlocked_arr.size() else false
			var h_tc = tier_colors[h_tier]
			var mouse_pos = get_viewport().get_mouse_position()
			var tt_w = 260.0
			var tt_h = 80.0
			var tt_x = clampf(mouse_pos.x + 12, panel_x, panel_x + panel_w - tt_w)
			var tt_y = clampf(mouse_pos.y - tt_h - 8, panel_y, panel_y + panel_h - tt_h)
			# Shadow
			draw_rect(Rect2(tt_x + 2, tt_y + 2, tt_w, tt_h), Color(0, 0, 0, 0.5))
			# Background
			draw_rect(Rect2(tt_x, tt_y, tt_w, tt_h), Color(0.03, 0.03, 0.08, 0.95))
			# Border
			draw_rect(Rect2(tt_x, tt_y, tt_w, 1), Color(h_tc.r, h_tc.g, h_tc.b, 0.6))
			draw_rect(Rect2(tt_x, tt_y + tt_h - 1, tt_w, 1), Color(h_tc.r, h_tc.g, h_tc.b, 0.6))
			draw_rect(Rect2(tt_x, tt_y, 1, tt_h), Color(h_tc.r, h_tc.g, h_tc.b, 0.6))
			draw_rect(Rect2(tt_x + tt_w - 1, tt_y, 1, tt_h), Color(h_tc.r, h_tc.g, h_tc.b, 0.6))
			# Relic name
			draw_string(font, Vector2(tt_x + 8, tt_y + 16), h_relic["name"], HORIZONTAL_ALIGNMENT_LEFT, int(tt_w - 16), 12, Color(h_tc.r, h_tc.g, h_tc.b, 0.95))
			# Full description
			draw_string(font, Vector2(tt_x + 8, tt_y + 34), h_relic["desc"], HORIZONTAL_ALIGNMENT_LEFT, int(tt_w - 16), 9, Color(menu_text.r, menu_text.g, menu_text.b, 0.85))
			# Effect + character
			var h_accent = char_accents[h_col]
			var effect_label = "Effect: " + h_relic["effect"].replace("_", " ")
			draw_string(font, Vector2(tt_x + 8, tt_y + 52), effect_label, HORIZONTAL_ALIGNMENT_LEFT, int(tt_w - 16), 9, Color(h_tc.r, h_tc.g, h_tc.b, 0.6))
			draw_string(font, Vector2(tt_x + 8, tt_y + 68), char_names[h_col], HORIZONTAL_ALIGNMENT_LEFT, int(tt_w - 16), 9, Color(h_accent.r, h_accent.g, h_accent.b, 0.7))
			# Lock status
			if not h_unlocked:
				draw_string(font, Vector2(tt_x + tt_w - 60, tt_y + 68), "LOCKED", HORIZONTAL_ALIGNMENT_RIGHT, 52, 9, Color(0.6, 0.3, 0.3, 0.7))

	# Footer: relic shard count
	var footer_y = panel_y + panel_h - 18
	draw_string(font, Vector2(grid_left + 10, footer_y), "Relic Shards: %d" % player_relic_shards, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(menu_gold.r, menu_gold.g, menu_gold.b, 0.6))
	draw_string(font, Vector2(grid_left + 200, footer_y), "Quills: %d" % player_quills, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(menu_gold.r, menu_gold.g, menu_gold.b, 0.6))
	draw_string(font, Vector2(grid_left + 340, footer_y), "Storybook Stars: %d" % player_storybook_stars, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(menu_gold.r, menu_gold.g, menu_gold.b, 0.6))

func _draw_emporium() -> void:
	# === Navy background (same dimensions as survivor grid) ===
	var panel_x = 70.0
	var panel_y = 45.0
	var panel_w = 1140.0
	var panel_h = 560.0

	# Navy gradient background
	for i in range(56):
		var t = float(i) / 55.0
		var col = menu_bg_section.lerp(menu_bg_dark, t)
		var grain = sin(float(i) * 2.3) * 0.005
		col.r += grain
		col.b += grain * 1.5
		draw_rect(Rect2(panel_x, panel_y + t * panel_h, panel_w, panel_h / 55.0 + 1), col)

	# Ornate border — gold double frame
	var emp_outer = Color(menu_gold_dim.r, menu_gold_dim.g, menu_gold_dim.b, 0.35)
	var emp_gold = Color(0.65, 0.45, 0.1, 0.2)
	# Outer gold border (3px)
	draw_rect(Rect2(panel_x, panel_y, panel_w, 3), emp_outer)
	draw_rect(Rect2(panel_x, panel_y + panel_h - 3, panel_w, 3), emp_outer)
	draw_rect(Rect2(panel_x, panel_y, 3, panel_h), emp_outer)
	draw_rect(Rect2(panel_x + panel_w - 3, panel_y, 3, panel_h), emp_outer)
	# Inner gold border (1px)
	draw_rect(Rect2(panel_x + 6, panel_y + 6, panel_w - 12, 1), emp_gold)
	draw_rect(Rect2(panel_x + 6, panel_y + panel_h - 7, panel_w - 12, 1), emp_gold)
	draw_rect(Rect2(panel_x + 6, panel_y + 6, 1, panel_h - 12), emp_gold)
	draw_rect(Rect2(panel_x + panel_w - 7, panel_y + 6, 1, panel_h - 12), emp_gold)

	# Corner filigree ornaments (gold only)
	for corner in [Vector2(panel_x + 14, panel_y + 14), Vector2(panel_x + panel_w - 14, panel_y + 14), Vector2(panel_x + 14, panel_y + panel_h - 14), Vector2(panel_x + panel_w - 14, panel_y + panel_h - 14)]:
		draw_circle(corner, 7, Color(0.65, 0.45, 0.1, 0.2))
		draw_circle(corner, 5, Color(0.65, 0.45, 0.1, 0.3))
		draw_circle(corner, 3, Color(0.65, 0.45, 0.1, 0.25))
		draw_arc(corner, 8, 0, TAU, 24, Color(0.65, 0.45, 0.1, 0.15), 1.0)

	# === Title: THE EMPORIUM ===
	var font = ThemeDB.fallback_font
	var title_text = "THE EMPORIUM"
	var title_size = 28
	var title_width = font.get_string_size(title_text, HORIZONTAL_ALIGNMENT_CENTER, -1, title_size).x
	var title_x = panel_x + (panel_w - title_width) * 0.5
	var title_y = panel_y + 38.0
	# Title glow
	draw_string(font, Vector2(title_x, title_y), title_text, HORIZONTAL_ALIGNMENT_CENTER, -1, title_size, Color(0.85, 0.65, 0.1, 0.3))
	draw_string(font, Vector2(title_x - 1, title_y - 1), title_text, HORIZONTAL_ALIGNMENT_CENTER, -1, title_size, Color(0.95, 0.75, 0.2, 0.9))
	# Decorative stars flanking title
	var star_lx = title_x - 25.0
	var star_rx = title_x + title_width + 10.0
	var star_y = title_y - 10.0
	for dx in [-2.0, 0.0, 2.0]:
		draw_circle(Vector2(star_lx + dx, star_y + dx * 0.5), 2.0, Color(0.85, 0.65, 0.1, 0.4))
		draw_circle(Vector2(star_rx + dx, star_y + dx * 0.5), 2.0, Color(0.85, 0.65, 0.1, 0.4))
	# Underline — gold double line
	var line_cx = panel_x + panel_w * 0.5
	draw_line(Vector2(line_cx - 180, title_y + 8), Vector2(line_cx + 180, title_y + 8), Color(menu_gold.r, menu_gold.g, menu_gold.b, 0.3), 1.5)
	draw_line(Vector2(line_cx - 140, title_y + 12), Vector2(line_cx + 140, title_y + 12), Color(0.65, 0.45, 0.1, 0.15), 1.0)

	# === 3x2 Grid of Emporium Tiles ===
	var tile_w = 340.0
	var tile_h = 220.0
	var gap_x = 30.0
	var gap_y = 24.0
	var grid_w = 3.0 * tile_w + 2.0 * gap_x
	var grid_start_x = panel_x + (panel_w - grid_w) * 0.5
	var grid_start_y = panel_y + 58.0

	for i in range(6):
		var cat = emporium_categories[i]
		var col_idx = i % 3
		var row = i / 3
		var tx = grid_start_x + float(col_idx) * (tile_w + gap_x)
		var ty = grid_start_y + float(row) * (tile_h + gap_y)
		var is_hovered = (i == emporium_hover_index)

		# Tile shadow (6px offset)
		draw_rect(Rect2(tx + 6, ty + 6, tile_w, tile_h), Color(0.0, 0.0, 0.0, 0.35))

		# Tile background (navy card)
		var bg = menu_bg_card
		if is_hovered:
			bg = menu_bg_card_hover
		draw_rect(Rect2(tx, ty, tile_w, tile_h), bg)

		# Warm amber accent gradient at top
		for g in range(6):
			var gt = float(g) / 5.0
			draw_rect(Rect2(tx, ty + float(g), tile_w, 1), Color(0.65, 0.45, 0.1, 0.12 * (1.0 - gt)))

		# Tile border
		var tile_border = Color(0.55, 0.38, 0.08, 0.35)
		if is_hovered:
			tile_border = Color(0.85, 0.65, 0.15, 0.7)
		draw_rect(Rect2(tx, ty, tile_w, 2), tile_border)
		draw_rect(Rect2(tx, ty + tile_h - 2, tile_w, 2), tile_border)
		draw_rect(Rect2(tx, ty, 2, tile_h), tile_border)
		draw_rect(Rect2(tx + tile_w - 2, ty, 2, tile_h), tile_border)

		# Hover glow (gold tint)
		if is_hovered:
			var glow_a = 0.06 + sin(_time * 3.5) * 0.03
			draw_rect(Rect2(tx - 2, ty - 2, tile_w + 4, tile_h + 4), Color(menu_gold.r, menu_gold.g, menu_gold.b, glow_a))

		# Corner flourishes (gold only)
		var fl = Color(0.65, 0.45, 0.1, 0.15)
		draw_line(Vector2(tx + 6, ty + 6), Vector2(tx + 26, ty + 6), fl, 1.0)
		draw_line(Vector2(tx + 6, ty + 6), Vector2(tx + 6, ty + 26), fl, 1.0)
		draw_line(Vector2(tx + tile_w - 6, ty + 6), Vector2(tx + tile_w - 26, ty + 6), fl, 1.0)
		draw_line(Vector2(tx + tile_w - 6, ty + 6), Vector2(tx + tile_w - 6, ty + 26), fl, 1.0)
		draw_line(Vector2(tx + 6, ty + tile_h - 6), Vector2(tx + 26, ty + tile_h - 6), fl, 1.0)
		draw_line(Vector2(tx + 6, ty + tile_h - 6), Vector2(tx + 6, ty + tile_h - 26), fl, 1.0)
		draw_line(Vector2(tx + tile_w - 6, ty + tile_h - 6), Vector2(tx + tile_w - 26, ty + tile_h - 6), fl, 1.0)
		draw_line(Vector2(tx + tile_w - 6, ty + tile_h - 6), Vector2(tx + tile_w - 6, ty + tile_h - 26), fl, 1.0)

		# === Title text (top) ===
		var name_size = 16
		var name_text = cat["name"]
		var name_w = font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x
		var name_x = tx + (tile_w - name_w) * 0.5
		var name_y_pos = ty + 28.0
		draw_string(font, Vector2(name_x, name_y_pos), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, Color(0.9, 0.72, 0.2, 0.95))

		# === Procedural icon (center) ===
		var icon_cx = tx + tile_w * 0.5
		var icon_cy = ty + tile_h * 0.48
		_draw_emporium_icon(Vector2(icon_cx, icon_cy), cat["icon"], 70.0)

		# === Description text (bottom) ===
		var desc_size = 12
		var desc_text = cat["desc"]
		var desc_w = font.get_string_size(desc_text, HORIZONTAL_ALIGNMENT_LEFT, -1, desc_size).x
		var desc_x = tx + (tile_w - desc_w) * 0.5
		var desc_y = ty + tile_h - 18.0
		draw_string(font, Vector2(desc_x, desc_y), desc_text, HORIZONTAL_ALIGNMENT_LEFT, -1, desc_size, Color(0.65, 0.55, 0.4, 0.8))

		# === Badge ribbon (top-left) ===
		if cat["badge"] != "":
			var badge_text = cat["badge"]
			var badge_font_size = 10
			var badge_w = font.get_string_size(badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, badge_font_size).x + 16.0
			var badge_h = 20.0
			var badge_x = tx + 8.0
			var badge_y_top = ty + 8.0
			# Badge color: red for SALE!, green for AVAILABLE!
			var badge_col = Color(0.7, 0.15, 0.1, 0.9)
			if badge_text == "AVAILABLE!":
				badge_col = Color(0.15, 0.55, 0.2, 0.9)
			# Ribbon background
			draw_rect(Rect2(badge_x, badge_y_top, badge_w, badge_h), badge_col)
			# Ribbon notch (small triangle cut on right side)
			draw_colored_polygon(PackedVector2Array([
				Vector2(badge_x + badge_w, badge_y_top),
				Vector2(badge_x + badge_w + 6, badge_y_top + badge_h * 0.5),
				Vector2(badge_x + badge_w, badge_y_top + badge_h),
			]), badge_col)
			# Badge border highlight
			draw_rect(Rect2(badge_x, badge_y_top, badge_w, 1), Color(1, 1, 1, 0.2))
			# Badge text
			draw_string(font, Vector2(badge_x + 8.0, badge_y_top + 15.0), badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, badge_font_size, Color(1, 1, 1, 0.95))

	# === "RESTORE PURCHASES" text (bottom-right corner) ===
	var restore_size = 11
	var restore_text = "RESTORE PURCHASES"
	var restore_w = font.get_string_size(restore_text, HORIZONTAL_ALIGNMENT_LEFT, -1, restore_size).x
	var restore_x = panel_x + panel_w - restore_w - 20.0
	var restore_y = panel_y + panel_h - 12.0
	draw_string(font, Vector2(restore_x, restore_y), restore_text, HORIZONTAL_ALIGNMENT_LEFT, -1, restore_size, Color(0.55, 0.42, 0.25, 0.5))

func _draw_emporium_icon(center: Vector2, icon_key: String, sz: float) -> void:
	var cx = center.x
	var cy = center.y
	var s = sz * 0.5
	match icon_key:
		"emp_gold":
			# Stack of 3 gold coins
			for ci in range(3):
				var off_y = float(ci) * -10.0
				var coin_col = Color(0.85, 0.65, 0.1, 0.85 - float(ci) * 0.08)
				var coin_hi = Color(0.95, 0.78, 0.2, 0.7 - float(ci) * 0.08)
				# Coin ellipse (top face)
				draw_circle(Vector2(cx, cy + off_y), s * 0.42, coin_col)
				# Coin rim (side edge)
				draw_rect(Rect2(cx - s * 0.42, cy + off_y, s * 0.84, s * 0.12), Color(0.7, 0.5, 0.08, 0.7))
				# Highlight arc
				draw_arc(Vector2(cx, cy + off_y), s * 0.3, -PI * 0.8, -PI * 0.2, 8, coin_hi, 2.0)
				# Inner circle detail
				draw_arc(Vector2(cx, cy + off_y), s * 0.18, 0, TAU, 10, Color(0.75, 0.55, 0.1, 0.4), 1.0)
			# Top coin $ symbol
			draw_line(Vector2(cx - s * 0.08, cy - 24), Vector2(cx - s * 0.08, cy - 12), Color(0.95, 0.8, 0.3, 0.5), 2.0)
			draw_line(Vector2(cx + s * 0.08, cy - 24), Vector2(cx + s * 0.08, cy - 12), Color(0.95, 0.8, 0.3, 0.5), 2.0)
		"emp_quills":
			# Purple feather quill
			var quill_col = Color(0.55, 0.2, 0.7, 0.85)
			var quill_hi = Color(0.7, 0.35, 0.85, 0.6)
			# Feather body (main vane) - slightly curved
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx - s * 0.05, cy + s * 0.6),
				Vector2(cx + s * 0.35, cy - s * 0.5),
				Vector2(cx + s * 0.15, cy - s * 0.65),
				Vector2(cx - s * 0.25, cy + s * 0.4),
			]), quill_col)
			# Feather highlight
			draw_line(Vector2(cx - s * 0.12, cy + s * 0.5), Vector2(cx + s * 0.25, cy - s * 0.55), quill_hi, 1.5)
			# Quill shaft
			draw_line(Vector2(cx - s * 0.15, cy + s * 0.55), Vector2(cx - s * 0.45, cy + s * 0.75), Color(0.8, 0.75, 0.65, 0.8), 2.0)
			# Nib tip
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx - s * 0.45, cy + s * 0.75),
				Vector2(cx - s * 0.52, cy + s * 0.85),
				Vector2(cx - s * 0.42, cy + s * 0.82),
			]), Color(0.3, 0.2, 0.1, 0.9))
			# Ink drops
			draw_circle(Vector2(cx - s * 0.55, cy + s * 0.9), 3.0, Color(0.15, 0.05, 0.3, 0.7))
			draw_circle(Vector2(cx - s * 0.42, cy + s * 0.95), 2.0, Color(0.15, 0.05, 0.3, 0.5))
			# Barb lines on feather
			for bi in range(5):
				var bt = float(bi) / 4.0
				var bx = lerp(cx - s * 0.1, cx + s * 0.3, bt)
				var by_pos = lerp(cy + s * 0.45, cy - s * 0.45, bt)
				draw_line(Vector2(bx, by_pos), Vector2(bx - s * 0.15, by_pos + s * 0.08), Color(0.45, 0.15, 0.6, 0.3), 1.0)
		"emp_shards":
			# Glowing crystal fragment cluster
			var shard_col = Color(0.3, 0.7, 0.85, 0.8)
			var shard_glow = Color(0.4, 0.8, 0.95, 0.15)
			# Central glow
			draw_circle(Vector2(cx, cy), s * 0.55, shard_glow)
			draw_circle(Vector2(cx, cy), s * 0.35, Color(0.5, 0.85, 1.0, 0.1))
			# Main shard (tall, center)
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx - s * 0.1, cy + s * 0.4),
				Vector2(cx - s * 0.15, cy - s * 0.15),
				Vector2(cx, cy - s * 0.6),
				Vector2(cx + s * 0.12, cy - s * 0.1),
				Vector2(cx + s * 0.08, cy + s * 0.4),
			]), shard_col)
			# Highlight facet
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx - s * 0.12, cy - s * 0.1),
				Vector2(cx, cy - s * 0.55),
				Vector2(cx + s * 0.05, cy - s * 0.05),
			]), Color(0.5, 0.85, 0.95, 0.5))
			# Left shard (smaller, angled)
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx - s * 0.35, cy + s * 0.35),
				Vector2(cx - s * 0.4, cy + s * 0.0),
				Vector2(cx - s * 0.2, cy - s * 0.35),
				Vector2(cx - s * 0.12, cy + s * 0.05),
				Vector2(cx - s * 0.18, cy + s * 0.35),
			]), Color(0.25, 0.6, 0.75, 0.7))
			# Right shard (small)
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx + s * 0.2, cy + s * 0.3),
				Vector2(cx + s * 0.18, cy - s * 0.1),
				Vector2(cx + s * 0.32, cy - s * 0.25),
				Vector2(cx + s * 0.38, cy + s * 0.05),
				Vector2(cx + s * 0.3, cy + s * 0.3),
			]), Color(0.35, 0.65, 0.8, 0.65))
			# Sparkle points
			for sp in [Vector2(cx + s * 0.05, cy - s * 0.5), Vector2(cx - s * 0.3, cy - s * 0.2), Vector2(cx + s * 0.35, cy - s * 0.15)]:
				draw_line(sp + Vector2(-4, 0), sp + Vector2(4, 0), Color(1, 1, 1, 0.5), 1.0)
				draw_line(sp + Vector2(0, -4), sp + Vector2(0, 4), Color(1, 1, 1, 0.5), 1.0)
		"emp_chests":
			# Ornate treasure chest
			var wood_col = Color(0.5, 0.3, 0.12, 0.85)
			var wood_dark = Color(0.35, 0.2, 0.08, 0.85)
			var gold_col = Color(0.85, 0.65, 0.1, 0.9)
			# Chest body (bottom box)
			draw_rect(Rect2(cx - s * 0.5, cy - s * 0.05, s * 1.0, s * 0.55), wood_col)
			# Planks
			draw_line(Vector2(cx - s * 0.5, cy + s * 0.2), Vector2(cx + s * 0.5, cy + s * 0.2), wood_dark, 1.0)
			# Lid (rounded top)
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx - s * 0.5, cy - s * 0.05),
				Vector2(cx - s * 0.48, cy - s * 0.3),
				Vector2(cx - s * 0.3, cy - s * 0.48),
				Vector2(cx, cy - s * 0.55),
				Vector2(cx + s * 0.3, cy - s * 0.48),
				Vector2(cx + s * 0.48, cy - s * 0.3),
				Vector2(cx + s * 0.5, cy - s * 0.05),
			]), wood_dark)
			# Gold bands
			draw_line(Vector2(cx - s * 0.5, cy - s * 0.05), Vector2(cx + s * 0.5, cy - s * 0.05), gold_col, 2.5)
			draw_line(Vector2(cx - s * 0.5, cy + s * 0.5), Vector2(cx + s * 0.5, cy + s * 0.5), gold_col, 2.0)
			# Gold latch (center)
			draw_rect(Rect2(cx - s * 0.08, cy - s * 0.12, s * 0.16, s * 0.2), gold_col)
			draw_circle(Vector2(cx, cy + s * 0.02), s * 0.06, Color(0.95, 0.75, 0.2))
			# Glow from opening
			draw_circle(Vector2(cx, cy - s * 0.15), s * 0.3, Color(1.0, 0.85, 0.3, 0.08 + sin(_time * 2.5) * 0.04))
			# Corner reinforcements
			for ccx in [cx - s * 0.48, cx + s * 0.42]:
				draw_rect(Rect2(ccx, cy - s * 0.03, s * 0.06, s * 0.52), gold_col.darkened(0.3))
		"emp_packs":
			# Silhouette of character group / book bundle
			var sil_col = Color(0.55, 0.35, 0.15, 0.7)
			var sil_hi = Color(0.7, 0.5, 0.2, 0.5)
			# Three book shapes (stacked at angle)
			# Book 1 (left, leaning)
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx - s * 0.4, cy + s * 0.45),
				Vector2(cx - s * 0.5, cy - s * 0.25),
				Vector2(cx - s * 0.3, cy - s * 0.3),
				Vector2(cx - s * 0.2, cy + s * 0.4),
			]), sil_col)
			draw_line(Vector2(cx - s * 0.48, cy - s * 0.2), Vector2(cx - s * 0.22, cy + s * 0.38), Color(0.85, 0.65, 0.1, 0.3), 1.0)
			# Book 2 (center, upright)
			draw_rect(Rect2(cx - s * 0.15, cy - s * 0.4, s * 0.3, s * 0.85), Color(0.45, 0.25, 0.1, 0.75))
			draw_rect(Rect2(cx - s * 0.12, cy - s * 0.35, s * 0.24, s * 0.08), Color(0.85, 0.65, 0.1, 0.4))
			# Book 3 (right, leaning opposite)
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx + s * 0.2, cy + s * 0.45),
				Vector2(cx + s * 0.3, cy - s * 0.3),
				Vector2(cx + s * 0.5, cy - s * 0.25),
				Vector2(cx + s * 0.4, cy + s * 0.45),
			]), Color(0.5, 0.28, 0.12, 0.7))
			draw_line(Vector2(cx + s * 0.32, cy - s * 0.25), Vector2(cx + s * 0.42, cy + s * 0.4), Color(0.85, 0.65, 0.1, 0.3), 1.0)
			# Character silhouettes peeking above books
			draw_circle(Vector2(cx - s * 0.1, cy - s * 0.52), s * 0.12, Color(0.3, 0.2, 0.1, 0.5))
			draw_circle(Vector2(cx + s * 0.15, cy - s * 0.48), s * 0.1, Color(0.3, 0.2, 0.1, 0.45))
			# Ribbon bookmark
			draw_line(Vector2(cx, cy - s * 0.4), Vector2(cx - s * 0.05, cy + s * 0.55), Color(0.7, 0.15, 0.15, 0.5), 2.0)
		"emp_stars":
			# Cluster of stars with sparkle
			var star_col = Color(0.95, 0.8, 0.2, 0.85)
			var star_glow = Color(1.0, 0.9, 0.4, 0.12)
			# Central glow
			draw_circle(Vector2(cx, cy), s * 0.5, star_glow)
			# Draw 5 stars of varying sizes
			var star_positions = [
				{"pos": Vector2(cx, cy - s * 0.2), "r": s * 0.28},
				{"pos": Vector2(cx - s * 0.35, cy + s * 0.15), "r": s * 0.18},
				{"pos": Vector2(cx + s * 0.35, cy + s * 0.1), "r": s * 0.2},
				{"pos": Vector2(cx - s * 0.15, cy + s * 0.4), "r": s * 0.14},
				{"pos": Vector2(cx + s * 0.2, cy + s * 0.38), "r": s * 0.12},
			]
			for sd in star_positions:
				var sp_center = sd["pos"]
				var sr = sd["r"]
				# 5-point star
				for si in range(5):
					var a1 = -PI / 2.0 + float(si) * TAU / 5.0
					var a2 = -PI / 2.0 + (float(si) + 0.5) * TAU / 5.0
					var p1 = sp_center + Vector2.from_angle(a1) * sr
					var p2 = sp_center + Vector2.from_angle(a2) * sr * 0.4
					var p3 = sp_center + Vector2.from_angle(a1 + TAU / 5.0) * sr
					draw_colored_polygon(PackedVector2Array([sp_center, p1, p2]), star_col)
					draw_colored_polygon(PackedVector2Array([sp_center, p2, p3]), star_col)
			# Cross sparkles on the largest star
			var main_star = star_positions[0]["pos"]
			draw_line(main_star + Vector2(-s * 0.35, 0), main_star + Vector2(s * 0.35, 0), Color(1, 1, 1, 0.3), 1.0)
			draw_line(main_star + Vector2(0, -s * 0.35), main_star + Vector2(0, s * 0.35), Color(1, 1, 1, 0.3), 1.0)

func _draw_closed_book() -> void:
	# === Leather-bound book cover (centered) ===
	var bx = 340.0
	var by = 60.0
	var bw = 600.0
	var bh = 500.0

	# Book shadow
	draw_rect(Rect2(bx + 8, by + 8, bw, bh), Color(0.0, 0.0, 0.0, 0.3))

	# Leather cover (deep indigo with gradient)
	for i in range(50):
		var t = float(i) / 49.0
		var col = Color(0.10, 0.08, 0.20).lerp(Color(0.07, 0.05, 0.16), t)
		var grain = sin(float(i) * 3.7 + cos(float(i) * 2.1) * 2.0) * 0.015
		col.r += grain * 0.5
		col.b += grain
		draw_rect(Rect2(bx, by + t * bh, bw, bh / 49.0 + 1), col)

	# Leather texture (subtle indigo grain)
	for i in range(30):
		var tx = bx + fmod(float(i) * 47.3, bw - 20.0) + 10.0
		var ty = by + fmod(float(i) * 31.7, bh - 20.0) + 10.0
		draw_circle(Vector2(tx, ty), 1.0, Color(0.06, 0.04, 0.12, 0.12))

	# Spine (left edge)
	draw_rect(Rect2(bx - 15, by - 5, 18, bh + 10), Color(0.07, 0.05, 0.14))
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

func _draw_world_map() -> void:
	var font = ThemeDB.fallback_font

	# === SKY LAYER (y=0 to y=220) ===
	for y in range(0, 220, 2):
		var t = float(y) / 220.0
		var sky_col = Color(0.08, 0.02, 0.14).lerp(Color(0.04, 0.04, 0.12), t)
		draw_line(Vector2(0, y), Vector2(1280, y), sky_col, 2.0)

	# Stars
	for star in _world_map_stars:
		var sa = 0.3 + 0.3 * sin(_time * star["speed"] + star["offset"])
		draw_circle(Vector2(star["x"], star["y"]), star["size"], Color(1.0, 1.0, 0.95, sa))

	# Moon (upper right)
	var moon_glow_r = 50.0 + 3.0 * sin(_time * 0.8)
	draw_circle(Vector2(1050, 80), moon_glow_r, Color(0.9, 0.85, 0.7, 0.04))
	draw_circle(Vector2(1050, 80), 45, Color(0.92, 0.88, 0.75, 0.15))
	draw_circle(Vector2(1050, 80), 40, Color(0.95, 0.92, 0.82, 0.25))
	draw_circle(Vector2(1050, 80), 35, Color(0.97, 0.95, 0.88, 0.4))

	# Wispy clouds
	for cloud in _world_map_clouds:
		var cloud_x = cloud["x"] + sin(_time * cloud["speed"]) * 20.0
		var cloud_y = cloud["y"]
		var cloud_w = cloud["width"]
		for ci in range(3):
			var cx_off = float(ci - 1) * cloud_w * 0.3
			draw_circle(Vector2(cloud_x + cx_off, cloud_y), cloud_w * 0.2, Color(0.4, 0.35, 0.5, 0.06))

	# === MOUNTAIN SILHOUETTES (y=140 to y=300) ===
	# Back layer
	var back_peaks = [
		PackedVector2Array([Vector2(0, 300), Vector2(100, 160), Vector2(250, 300)]),
		PackedVector2Array([Vector2(200, 300), Vector2(350, 140), Vector2(500, 300)]),
		PackedVector2Array([Vector2(450, 300), Vector2(640, 170), Vector2(830, 300)]),
		PackedVector2Array([Vector2(780, 300), Vector2(950, 150), Vector2(1100, 300)]),
		PackedVector2Array([Vector2(1050, 300), Vector2(1180, 165), Vector2(1280, 300)]),
	]
	for peak in back_peaks:
		draw_colored_polygon(peak, Color(0.03, 0.02, 0.08, 0.6))

	# Front layer
	var front_peaks = [
		PackedVector2Array([Vector2(0, 300), Vector2(150, 200), Vector2(320, 300)]),
		PackedVector2Array([Vector2(280, 300), Vector2(460, 210), Vector2(620, 300)]),
		PackedVector2Array([Vector2(700, 300), Vector2(880, 190), Vector2(1050, 300)]),
		PackedVector2Array([Vector2(1000, 300), Vector2(1150, 215), Vector2(1280, 300)]),
	]
	for peak in front_peaks:
		draw_colored_polygon(peak, Color(0.05, 0.04, 0.10, 0.8))

	# Mountain base mist
	for y in range(270, 310, 2):
		var mt = float(y - 270) / 40.0
		draw_line(Vector2(0, y), Vector2(1280, y), Color(0.06, 0.06, 0.12, 0.3 * (1.0 - mt)), 2.0)

	# === GROUND TERRAIN (y=200 to y=620) ===
	for y in range(200, 620, 3):
		var gt = float(y - 200) / 420.0
		var ground_col = Color(0.04 + gt * 0.02, 0.08 + gt * 0.03, 0.04 + gt * 0.01)
		var grain = sin(float(y) * 1.7) * 0.008
		ground_col.r += grain
		ground_col.g += grain * 1.3
		draw_line(Vector2(0, y), Vector2(1280, y), ground_col, 3.0)

	# Sparse grass tufts
	var rng_grass = RandomNumberGenerator.new()
	rng_grass.seed = 777
	for i in range(60):
		var gx = rng_grass.randf_range(10, 1270)
		var gy = rng_grass.randf_range(250, 600)
		var gh = rng_grass.randf_range(4, 10)
		var grass_sway = sin(_time * 1.5 + gx * 0.01) * 2.0
		draw_line(Vector2(gx, gy), Vector2(gx + grass_sway, gy - gh), Color(0.12, 0.22, 0.08, 0.4), 1.0)

	# === GOLDEN WINDING PATHS ===
	var path_glow_a = 0.15 + 0.05 * sin(_time * 2.0)
	var path_col = Color(0.6, 0.45, 0.15, path_glow_a)
	var path_col_core = Color(0.7, 0.55, 0.2, path_glow_a + 0.1)
	# Robin -> Alice
	_draw_winding_path(Vector2(200, 310), Vector2(500, 260), path_col, path_col_core)
	# Alice -> Witch
	_draw_winding_path(Vector2(500, 260), Vector2(1060, 300), path_col, path_col_core)
	# Robin -> Peter
	_draw_winding_path(Vector2(200, 310), Vector2(200, 490), path_col, path_col_core)
	# Peter -> Phantom
	_draw_winding_path(Vector2(200, 490), Vector2(640, 460), path_col, path_col_core)
	# Phantom -> Scrooge
	_draw_winding_path(Vector2(640, 460), Vector2(1060, 490), path_col, path_col_core)
	# Witch -> Scrooge
	_draw_winding_path(Vector2(1060, 300), Vector2(1060, 490), path_col, path_col_core)

	# === WATER (y=570 to y=615) ===
	for y in range(570, 616, 2):
		var wt = float(y - 570) / 45.0
		var wave_offset = sin(_time * 1.5 + float(y) * 0.08) * 3.0
		var water_col = Color(0.03, 0.08, 0.12).lerp(Color(0.02, 0.06, 0.10), wt)
		water_col.a = 0.7 + wt * 0.3
		draw_line(Vector2(wave_offset, y), Vector2(1280 + wave_offset, y), water_col, 2.0)
	# Water surface highlights
	for ri in range(8):
		var rx = 100.0 + float(ri) * 150.0 + sin(_time * 2.0 + float(ri)) * 15.0
		var ry = 575.0 + sin(_time * 1.2 + float(ri) * 0.5) * 5.0
		draw_circle(Vector2(rx, ry), 2.0, Color(0.3, 0.5, 0.6, 0.15 + 0.1 * sin(_time * 2.5 + float(ri))))

	# === CHARACTER ZONES ===
	var zone_colors = [
		Color(0.29, 0.55, 0.25),  # Robin Hood
		Color(0.44, 0.66, 0.86),  # Alice
		Color(0.48, 0.25, 0.63),  # Wicked Witch
		Color(0.90, 0.49, 0.13),  # Peter Pan
		Color(0.75, 0.22, 0.17),  # Phantom
		Color(0.79, 0.66, 0.30),  # Scrooge
	]

	for i in range(6):
		var zc = world_map_zone_centers[i]
		var zcol = zone_colors[i]
		var is_hovered = (world_map_hover_index == i)
		var is_selected = (survivor_selected_index == i)

		# Zone background glow circle
		var bg_alpha = 0.08
		if is_hovered:
			bg_alpha = 0.15
		if is_selected:
			bg_alpha = 0.18
		draw_circle(zc, 80, Color(zcol.r, zcol.g, zcol.b, bg_alpha))

		# Themed environment
		_draw_zone_environment(i, zc, zcol)

		# Character figure
		var char_pulse = 0.0
		if is_hovered:
			char_pulse = sin(_time * 3.0) * 3.0
		_draw_zone_character(i, zc, zcol, char_pulse)

		# Name banner below character
		var tower_type = survivor_types[i]
		var info = tower_info[tower_type]
		var name_str: String = info["name"]
		var name_w = font.get_string_size(name_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 14).x
		var banner_x = zc.x - name_w * 0.5 - 10
		var banner_y = zc.y + 45
		draw_rect(Rect2(banner_x, banner_y, name_w + 20, 22), Color(0.0, 0.0, 0.0, 0.6))
		draw_rect(Rect2(banner_x, banner_y, name_w + 20, 1), Color(menu_gold.r, menu_gold.g, menu_gold.b, 0.4))
		draw_string(font, Vector2(zc.x - name_w * 0.5, banner_y + 16), name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.85, 0.75, 0.55))

		# Chapter progress dots (3 dots below banner)
		for ch in range(3):
			var dot_x = zc.x - 12.0 + float(ch) * 12.0
			var dot_y = banner_y + 30.0
			var level_idx = i * 3 + ch
			var completed = level_idx in completed_levels
			if completed:
				draw_circle(Vector2(dot_x, dot_y), 4.0, Color(menu_gold.r, menu_gold.g, menu_gold.b, 0.8))
			else:
				draw_circle(Vector2(dot_x, dot_y), 4.0, Color(0.3, 0.3, 0.3, 0.4))
				draw_arc(Vector2(dot_x, dot_y), 4.0, 0, TAU, 16, Color(0.5, 0.5, 0.5, 0.3), 1.0)

		# Selected golden ring
		if is_selected:
			var ring_a = 0.5 + 0.2 * sin(_time * 3.0)
			draw_arc(zc, 82, 0, TAU, 48, Color(menu_gold.r, menu_gold.g, menu_gold.b, ring_a), 2.5)
			draw_arc(zc, 85, 0, TAU, 48, Color(menu_gold.r, menu_gold.g, menu_gold.b, ring_a * 0.4), 1.5)

		# Hover glow ring
		if is_hovered and not is_selected:
			var hov_a = 0.3 + 0.1 * sin(_time * 2.5)
			draw_arc(zc, 80, 0, TAU, 48, Color(zcol.r, zcol.g, zcol.b, hov_a), 2.0)

func _draw_winding_path(from: Vector2, to: Vector2, col: Color, core_col: Color) -> void:
	var steps = 12
	var prev = from
	var perp = (to - from).normalized().rotated(PI / 2.0)
	for s in range(1, steps + 1):
		var t = float(s) / float(steps)
		var pt = from.lerp(to, t)
		pt += perp * sin(t * PI * 2.0) * 15.0
		draw_line(prev, pt, col, 6.0)
		draw_line(prev, pt, core_col, 2.0)
		prev = pt

func _draw_zone_environment(idx: int, center: Vector2, col: Color) -> void:
	var cx = center.x
	var cy = center.y
	match idx:
		0:  # Robin Hood - Forest
			for ti in range(5):
				var tx = cx - 60 + ti * 30
				var ty = cy - 25 + (ti % 2) * 15
				var tree_h = 35.0 + float(ti % 3) * 10.0
				draw_colored_polygon(PackedVector2Array([Vector2(tx, ty), Vector2(tx - 12, ty + tree_h), Vector2(tx + 12, ty + tree_h)]), Color(0.12, 0.35, 0.08, 0.6))
				draw_rect(Rect2(tx - 2, ty + tree_h, 4, 8), Color(0.3, 0.2, 0.1, 0.5))
			# Target on a tree
			draw_circle(Vector2(cx + 35, cy - 5), 8, Color(0.8, 0.2, 0.1, 0.4))
			draw_circle(Vector2(cx + 35, cy - 5), 5, Color(0.9, 0.85, 0.7, 0.4))
			draw_circle(Vector2(cx + 35, cy - 5), 2, Color(0.8, 0.2, 0.1, 0.5))
		1:  # Alice - Wonderland
			for mi in range(3):
				var mx = cx - 40 + mi * 40
				var my = cy + 10 - mi * 8
				var ms = 12.0 + float(mi) * 4.0
				draw_rect(Rect2(mx - 3, my, 6, ms), Color(0.85, 0.82, 0.7, 0.5))
				draw_circle(Vector2(mx, my), ms * 0.8, Color(0.75, 0.15, 0.15, 0.5))
				draw_circle(Vector2(mx - 4, my - 3), 2.5, Color(0.95, 0.9, 0.8, 0.4))
				draw_circle(Vector2(mx + 3, my + 1), 2.0, Color(0.95, 0.9, 0.8, 0.4))
			for fi in range(4):
				var fx = cx - 50 + fi * 30
				var fy = cy + 30
				draw_circle(Vector2(fx, fy), 3, Color(0.9, 0.4, 0.6, 0.4))
				draw_circle(Vector2(fx, fy), 1.5, Color(1.0, 0.9, 0.3, 0.5))
		2:  # Wicked Witch - Oz
			for bi in range(6):
				var bx = cx - 50 + bi * 18
				var by = cy + 15 + sin(float(bi) * 0.5) * 5
				draw_rect(Rect2(bx, by, 14, 8), Color(0.85, 0.75, 0.2, 0.4))
				draw_rect(Rect2(bx, by, 14, 1), Color(0.7, 0.6, 0.15, 0.3))
			var em_pulse = 0.3 + 0.1 * sin(_time * 2.0)
			draw_circle(Vector2(cx, cy - 20), 15, Color(0.1, 0.8, 0.2, em_pulse * 0.3))
			draw_circle(Vector2(cx, cy - 20), 8, Color(0.2, 0.9, 0.3, em_pulse * 0.5))
			for mi in range(3):
				var ma = _time * 1.5 + float(mi) * TAU / 3.0
				var mmx = cx + cos(ma) * 50.0
				var mmy = cy - 30 + sin(ma) * 15.0
				draw_circle(Vector2(mmx, mmy), 3, Color(0.4, 0.3, 0.2, 0.4))
				draw_line(Vector2(mmx - 4, mmy - 1), Vector2(mmx, mmy + 2), Color(0.5, 0.4, 0.3, 0.3), 1.0)
				draw_line(Vector2(mmx + 4, mmy - 1), Vector2(mmx, mmy + 2), Color(0.5, 0.4, 0.3, 0.3), 1.0)
		3:  # Peter Pan - Neverland
			draw_colored_polygon(PackedVector2Array([Vector2(cx - 50, cy + 20), Vector2(cx - 40, cy - 10), Vector2(cx - 10, cy - 20), Vector2(cx + 30, cy - 15), Vector2(cx + 50, cy + 5), Vector2(cx + 45, cy + 20)]), Color(0.15, 0.12, 0.1, 0.5))
			draw_rect(Rect2(cx - 2, cy - 35, 4, 25), Color(0.4, 0.3, 0.15, 0.6))
			draw_colored_polygon(PackedVector2Array([Vector2(cx, cy - 35), Vector2(cx - 20, cy - 25), Vector2(cx - 5, cy - 30)]), Color(0.15, 0.45, 0.1, 0.5))
			draw_colored_polygon(PackedVector2Array([Vector2(cx, cy - 35), Vector2(cx + 18, cy - 28), Vector2(cx + 5, cy - 30)]), Color(0.15, 0.45, 0.1, 0.5))
			var ship_x = cx - 30
			var ship_y = cy + 10
			draw_colored_polygon(PackedVector2Array([Vector2(ship_x - 12, ship_y), Vector2(ship_x + 12, ship_y), Vector2(ship_x + 8, ship_y + 8), Vector2(ship_x - 8, ship_y + 8)]), Color(0.4, 0.25, 0.1, 0.5))
			draw_rect(Rect2(ship_x - 1, ship_y - 15, 2, 15), Color(0.35, 0.2, 0.1, 0.5))
			draw_rect(Rect2(ship_x + 1, ship_y - 13, 8, 6), Color(0.9, 0.85, 0.7, 0.4))
			for wi in range(4):
				var wy = cy + 22 + wi * 3
				var wave_off = sin(_time * 1.5 + float(wi) * 0.5) * 8.0
				draw_line(Vector2(cx - 55 + wave_off, wy), Vector2(cx + 55 + wave_off, wy), Color(0.1, 0.3, 0.5, 0.2 - float(wi) * 0.04), 2.0)
		4:  # Phantom - Opera House
			draw_rect(Rect2(cx - 45, cy - 25, 90, 55), Color(0.12, 0.08, 0.1, 0.5))
			for ci in range(4):
				var col_x = cx - 35 + ci * 23
				draw_rect(Rect2(col_x, cy - 20, 5, 45), Color(0.2, 0.15, 0.18, 0.5))
			draw_arc(Vector2(cx, cy - 25), 45, PI, TAU, 24, Color(0.25, 0.18, 0.2, 0.5), 2.0)
			for cdi in range(2):
				var cdx = cx - 55 + cdi * 110
				var cdy = cy + 5
				draw_rect(Rect2(cdx - 1, cdy, 2, 15), Color(0.7, 0.55, 0.1, 0.4))
				var flame_flicker = sin(_time * 5.0 + float(cdi) * 2.0) * 0.15
				draw_circle(Vector2(cdx, cdy - 3), 3, Color(1.0, 0.7, 0.2, 0.4 + flame_flicker))
			draw_arc(Vector2(cx, cy - 5), 12, PI + 0.3, TAU - 0.3, 16, Color(0.9, 0.88, 0.8, 0.4), 2.0)
		5:  # Scrooge - Victorian London
			for ri in range(3):
				var rx = cx - 50 + ri * 38
				var ry = cy - 10 + (ri % 2) * 12
				var rw = 30.0
				var rh = 25.0
				draw_rect(Rect2(rx, ry, rw, rh), Color(0.15, 0.12, 0.1, 0.5))
				draw_rect(Rect2(rx - 2, ry - 3, rw + 4, 5), Color(0.85, 0.88, 0.9, 0.5))
				draw_rect(Rect2(rx + rw * 0.3, ry + rh * 0.3, 8, 8), Color(0.8, 0.65, 0.2, 0.3))
			draw_rect(Rect2(cx + 20, cy - 25, 8, 15), Color(0.2, 0.15, 0.12, 0.5))
			for smoke in _world_map_smoke:
				var sy = smoke["y"] - fmod(_time * smoke["speed"] * 10.0, 40.0)
				var sx = cx + 24 + sin(_time * 0.8 + smoke["offset"]) * 5.0
				var smoke_a = 0.15 - abs(sy) * 0.004
				if smoke_a > 0:
					draw_circle(Vector2(sx, cy - 25 + sy), smoke["size"], Color(0.5, 0.5, 0.5, smoke_a))
			draw_rect(Rect2(cx - 45, cy - 15, 3, 40), Color(0.2, 0.18, 0.15, 0.5))
			draw_circle(Vector2(cx - 43.5, cy - 18), 5, Color(1.0, 0.85, 0.4, 0.25 + 0.1 * sin(_time * 3.0)))

func _draw_zone_character(idx: int, center: Vector2, col: Color, pulse: float) -> void:
	var cx = center.x
	var cy = center.y + pulse
	var head_y = cy - 20
	var body_y = cy - 8

	# Head
	draw_circle(Vector2(cx, head_y), 8, Color(0.85, 0.72, 0.55, 0.8))
	# Eyes
	draw_circle(Vector2(cx - 3, head_y - 1), 1.5, Color(0.1, 0.1, 0.1, 0.7))
	draw_circle(Vector2(cx + 3, head_y - 1), 1.5, Color(0.1, 0.1, 0.1, 0.7))
	# Body (trapezoid)
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 8, body_y), Vector2(cx + 8, body_y), Vector2(cx + 12, body_y + 22), Vector2(cx - 12, body_y + 22)]), Color(col.r, col.g, col.b, 0.7))

	match idx:
		0:  # Robin Hood - hat + bow
			draw_colored_polygon(PackedVector2Array([Vector2(cx, head_y - 16), Vector2(cx - 10, head_y - 6), Vector2(cx + 6, head_y - 6)]), Color(0.2, 0.4, 0.1, 0.7))
			draw_line(Vector2(cx + 2, head_y - 14), Vector2(cx + 8, head_y - 20), Color(0.8, 0.2, 0.1, 0.5), 1.5)
			draw_arc(Vector2(cx + 20, cy + pulse), 10, -PI * 0.4, PI * 0.4, 12, Color(0.5, 0.35, 0.15, 0.6), 2.0)
		1:  # Alice - hair + cards
			draw_rect(Rect2(cx - 9, head_y - 6, 18, 4), Color(0.9, 0.8, 0.4, 0.6))
			draw_rect(Rect2(cx - 10, head_y - 2, 3, 16), Color(0.9, 0.8, 0.4, 0.5))
			draw_rect(Rect2(cx + 7, head_y - 2, 3, 16), Color(0.9, 0.8, 0.4, 0.5))
			draw_rect(Rect2(cx - 9, head_y - 7, 18, 2), Color(0.3, 0.5, 0.8, 0.6))
			draw_rect(Rect2(cx + 14, body_y + 2, 8, 12), Color(0.9, 0.87, 0.8, 0.5))
			draw_circle(Vector2(cx + 18, body_y + 8), 2, Color(0.8, 0.15, 0.2, 0.5))
		2:  # Wicked Witch - pointy hat + broom
			draw_colored_polygon(PackedVector2Array([Vector2(cx, head_y - 22), Vector2(cx - 10, head_y - 6), Vector2(cx + 10, head_y - 6)]), Color(0.1, 0.1, 0.1, 0.7))
			draw_rect(Rect2(cx - 12, head_y - 7, 24, 3), Color(0.1, 0.1, 0.1, 0.6))
			draw_line(Vector2(cx - 15, body_y + 5), Vector2(cx - 25, body_y + 25), Color(0.5, 0.35, 0.15, 0.6), 2.0)
			draw_colored_polygon(PackedVector2Array([Vector2(cx - 28, body_y + 22), Vector2(cx - 22, body_y + 22), Vector2(cx - 25, body_y + 32)]), Color(0.4, 0.3, 0.1, 0.5))
			draw_circle(Vector2(cx, head_y), 8, Color(0.3, 0.6, 0.2, 0.15))
		3:  # Peter Pan - cap + dagger
			draw_colored_polygon(PackedVector2Array([Vector2(cx - 8, head_y - 6), Vector2(cx + 8, head_y - 6), Vector2(cx + 12, head_y - 12)]), Color(0.2, 0.5, 0.15, 0.7))
			draw_line(Vector2(cx + 10, head_y - 12), Vector2(cx + 16, head_y - 20), Color(0.9, 0.3, 0.1, 0.5), 1.5)
			draw_line(Vector2(cx + 14, body_y + 4), Vector2(cx + 22, body_y - 2), Color(0.7, 0.72, 0.75, 0.6), 2.0)
			draw_line(Vector2(cx + 13, body_y + 5), Vector2(cx + 16, body_y + 3), Color(0.5, 0.35, 0.15, 0.6), 2.0)
		4:  # Phantom - cape + mask
			draw_colored_polygon(PackedVector2Array([Vector2(cx - 10, body_y - 2), Vector2(cx + 10, body_y - 2), Vector2(cx + 18, body_y + 25), Vector2(cx - 18, body_y + 25)]), Color(0.1, 0.08, 0.08, 0.6))
			draw_arc(Vector2(cx, head_y), 8, PI + 0.2, TAU - 0.2, 12, Color(0.9, 0.88, 0.82, 0.6), 2.5)
			draw_colored_polygon(PackedVector2Array([Vector2(cx - 8, body_y), Vector2(cx + 8, body_y), Vector2(cx + 10, body_y + 20), Vector2(cx - 10, body_y + 20)]), Color(col.r, col.g, col.b, 0.7))
		5:  # Scrooge - top hat + cane
			draw_rect(Rect2(cx - 8, head_y - 18, 16, 14), Color(0.1, 0.1, 0.1, 0.7))
			draw_rect(Rect2(cx - 11, head_y - 5, 22, 3), Color(0.1, 0.1, 0.1, 0.6))
			draw_line(Vector2(cx + 14, body_y + 2), Vector2(cx + 14, body_y + 24), Color(0.4, 0.3, 0.15, 0.6), 2.0)
			draw_arc(Vector2(cx + 14, body_y + 2), 4, PI, TAU, 8, Color(0.4, 0.3, 0.15, 0.6), 2.0)

func _update_world_map_hover() -> void:
	var mouse_pos = get_viewport().get_mouse_position()
	world_map_hover_index = -1
	for i in range(6):
		if mouse_pos.distance_to(world_map_zone_centers[i]) < 80.0:
			world_map_hover_index = i
			break

func _draw_relic_icon(center: Vector2, icon_key: String, sz: float, accent: Color) -> void:
	var cx = center.x
	var cy = center.y
	var s = sz * 0.5
	match icon_key:
		"green_cloak":
			# Cloak shape - triangular drape
			var cloak_col = Color(0.2, 0.55, 0.15, 0.8)
			draw_colored_polygon(PackedVector2Array([Vector2(cx, cy - s * 0.8), Vector2(cx + s * 0.7, cy + s * 0.8), Vector2(cx - s * 0.7, cy + s * 0.8)]), cloak_col)
			draw_colored_polygon(PackedVector2Array([Vector2(cx - s * 0.3, cy - s * 0.6), Vector2(cx + s * 0.3, cy - s * 0.6), Vector2(cx + s * 0.15, cy - s * 0.35), Vector2(cx - s * 0.15, cy - s * 0.35)]), Color(0.15, 0.45, 0.1, 0.9))
			# Clasp
			draw_circle(Vector2(cx, cy - s * 0.45), s * 0.12, Color(0.85, 0.65, 0.1))
		"silver_arrow":
			# Arrow pointing right
			var arr_col = Color(0.8, 0.82, 0.85, 0.9)
			draw_line(Vector2(cx - s * 0.8, cy), Vector2(cx + s * 0.5, cy), arr_col, 2.0)
			# Arrowhead
			draw_colored_polygon(PackedVector2Array([Vector2(cx + s * 0.8, cy), Vector2(cx + s * 0.4, cy - s * 0.25), Vector2(cx + s * 0.4, cy + s * 0.25)]), arr_col)
			# Fletching
			draw_line(Vector2(cx - s * 0.8, cy), Vector2(cx - s * 0.6, cy - s * 0.2), Color(0.6, 0.5, 0.4), 1.5)
			draw_line(Vector2(cx - s * 0.8, cy), Vector2(cx - s * 0.6, cy + s * 0.2), Color(0.6, 0.5, 0.4), 1.5)
		"longbow":
			# Curved bow
			var bow_col = Color(0.55, 0.35, 0.15, 0.9)
			draw_arc(Vector2(cx + s * 0.3, cy), s * 0.75, PI * 0.6, PI * 1.4, 12, bow_col, 2.5)
			# String
			draw_line(Vector2(cx + s * 0.3 - s * 0.75 * cos(PI * 0.6), cy - s * 0.75 * sin(PI * 0.6)), Vector2(cx + s * 0.3 - s * 0.75 * cos(PI * 1.4), cy - s * 0.75 * sin(PI * 1.4)), Color(0.7, 0.65, 0.55), 1.0)
		"flask":
			# Bottle shape
			var flask_col = Color(0.5, 0.35, 0.15, 0.7)
			# Neck
			draw_rect(Rect2(cx - s * 0.12, cy - s * 0.7, s * 0.24, s * 0.35), flask_col)
			# Body
			draw_colored_polygon(PackedVector2Array([Vector2(cx - s * 0.12, cy - s * 0.35), Vector2(cx + s * 0.12, cy - s * 0.35), Vector2(cx + s * 0.35, cy - s * 0.05), Vector2(cx + s * 0.35, cy + s * 0.65), Vector2(cx - s * 0.35, cy + s * 0.65), Vector2(cx - s * 0.35, cy - s * 0.05)]), flask_col)
			# Liquid
			draw_rect(Rect2(cx - s * 0.3, cy + s * 0.15, s * 0.6, s * 0.45), Color(0.8, 0.6, 0.1, 0.6))
			# Cork
			draw_rect(Rect2(cx - s * 0.15, cy - s * 0.75, s * 0.3, s * 0.1), Color(0.6, 0.45, 0.2))
		"horn":
			# Curved horn
			var horn_col = Color(0.7, 0.55, 0.25, 0.85)
			draw_arc(Vector2(cx, cy + s * 0.3), s * 0.7, PI * 1.2, PI * 1.9, 10, horn_col, 3.5)
			# Bell end
			draw_circle(Vector2(cx + s * 0.55, cy - s * 0.15), s * 0.2, horn_col)
			draw_circle(Vector2(cx + s * 0.55, cy - s * 0.15), s * 0.12, Color(0.3, 0.2, 0.1, 0.5))
			# Mouthpiece
			draw_circle(Vector2(cx - s * 0.45, cy + s * 0.35), s * 0.08, horn_col)
		"gold_crown":
			# Crown
			var crown_col = Color(0.9, 0.7, 0.1, 0.9)
			# Base band
			draw_rect(Rect2(cx - s * 0.55, cy + s * 0.1, s * 1.1, s * 0.35), crown_col)
			# Three points
			draw_colored_polygon(PackedVector2Array([Vector2(cx - s * 0.55, cy + s * 0.1), Vector2(cx - s * 0.35, cy - s * 0.5), Vector2(cx - s * 0.15, cy + s * 0.1)]), crown_col)
			draw_colored_polygon(PackedVector2Array([Vector2(cx - s * 0.2, cy + s * 0.1), Vector2(cx, cy - s * 0.65), Vector2(cx + s * 0.2, cy + s * 0.1)]), crown_col)
			draw_colored_polygon(PackedVector2Array([Vector2(cx + s * 0.15, cy + s * 0.1), Vector2(cx + s * 0.35, cy - s * 0.5), Vector2(cx + s * 0.55, cy + s * 0.1)]), crown_col)
			# Gems
			draw_circle(Vector2(cx, cy + s * 0.25), s * 0.1, Color(0.8, 0.1, 0.1, 0.8))
			draw_circle(Vector2(cx - s * 0.3, cy + s * 0.25), s * 0.07, Color(0.1, 0.4, 0.8, 0.8))
			draw_circle(Vector2(cx + s * 0.3, cy + s * 0.25), s * 0.07, Color(0.1, 0.8, 0.3, 0.8))
		"drink_me":
			# Small bottle with label
			var bottle_col = Color(0.3, 0.5, 0.8, 0.7)
			draw_rect(Rect2(cx - s * 0.1, cy - s * 0.65, s * 0.2, s * 0.3), bottle_col)
			draw_colored_polygon(PackedVector2Array([Vector2(cx - s * 0.1, cy - s * 0.35), Vector2(cx + s * 0.1, cy - s * 0.35), Vector2(cx + s * 0.3, cy - s * 0.1), Vector2(cx + s * 0.3, cy + s * 0.65), Vector2(cx - s * 0.3, cy + s * 0.65), Vector2(cx - s * 0.3, cy - s * 0.1)]), bottle_col)
			# Liquid shimmer
			draw_rect(Rect2(cx - s * 0.25, cy + s * 0.2, s * 0.5, s * 0.4), Color(0.4, 0.2, 0.7, 0.5))
			# Label tag
			draw_rect(Rect2(cx - s * 0.18, cy - s * 0.05, s * 0.36, s * 0.18), Color(0.9, 0.85, 0.7, 0.8))
			# Cork
			draw_rect(Rect2(cx - s * 0.12, cy - s * 0.72, s * 0.24, s * 0.1), Color(0.6, 0.45, 0.2))
		"eat_me_cake":
			# Frosted cake
			var cake_col = Color(0.75, 0.55, 0.3, 0.85)
			# Base
			draw_rect(Rect2(cx - s * 0.45, cy + s * 0.1, s * 0.9, s * 0.45), cake_col)
			# Frosting top
			draw_colored_polygon(PackedVector2Array([Vector2(cx - s * 0.5, cy + s * 0.1), Vector2(cx + s * 0.5, cy + s * 0.1), Vector2(cx + s * 0.45, cy - s * 0.15), Vector2(cx - s * 0.45, cy - s * 0.15)]), Color(0.95, 0.85, 0.9, 0.9))
			# Cherry on top
			draw_circle(Vector2(cx, cy - s * 0.3), s * 0.12, Color(0.9, 0.15, 0.15, 0.9))
			# Drip frosting
			draw_rect(Rect2(cx - s * 0.15, cy + s * 0.1, s * 0.08, s * 0.15), Color(0.95, 0.85, 0.9, 0.7))
			draw_rect(Rect2(cx + s * 0.12, cy + s * 0.1, s * 0.08, s * 0.2), Color(0.95, 0.85, 0.9, 0.7))
		"vorpal_sword":
			# Jagged blade
			var blade_col = Color(0.75, 0.8, 0.85, 0.9)
			# Blade
			draw_colored_polygon(PackedVector2Array([Vector2(cx - s * 0.05, cy + s * 0.5), Vector2(cx + s * 0.05, cy + s * 0.5), Vector2(cx + s * 0.08, cy - s * 0.1), Vector2(cx + s * 0.15, cy - s * 0.25), Vector2(cx + s * 0.05, cy - s * 0.4), Vector2(cx + s * 0.1, cy - s * 0.6), Vector2(cx, cy - s * 0.8), Vector2(cx - s * 0.1, cy - s * 0.6), Vector2(cx - s * 0.05, cy - s * 0.4), Vector2(cx - s * 0.15, cy - s * 0.25), Vector2(cx - s * 0.08, cy - s * 0.1)]), blade_col)
			# Guard
			draw_rect(Rect2(cx - s * 0.25, cy + s * 0.45, s * 0.5, s * 0.08), Color(0.85, 0.65, 0.1, 0.8))
			# Handle
			draw_rect(Rect2(cx - s * 0.06, cy + s * 0.53, s * 0.12, s * 0.25), Color(0.5, 0.3, 0.15, 0.9))
		"heart_scepter":
			# Scepter with heart top
			var scepter_col = Color(0.85, 0.65, 0.1, 0.9)
			# Shaft
			draw_rect(Rect2(cx - s * 0.06, cy - s * 0.15, s * 0.12, s * 0.85), scepter_col)
			# Heart
			var hx = cx
			var hy = cy - s * 0.4
			draw_circle(Vector2(hx - s * 0.12, hy - s * 0.06), s * 0.15, Color(0.9, 0.1, 0.2, 0.9))
			draw_circle(Vector2(hx + s * 0.12, hy - s * 0.06), s * 0.15, Color(0.9, 0.1, 0.2, 0.9))
			draw_colored_polygon(PackedVector2Array([Vector2(hx - s * 0.26, hy), Vector2(hx, hy + s * 0.3), Vector2(hx + s * 0.26, hy)]), Color(0.9, 0.1, 0.2, 0.9))
		"pocket_watch":
			# Pocket watch
			var watch_col = Color(0.85, 0.7, 0.3, 0.85)
			draw_circle(Vector2(cx, cy + s * 0.05), s * 0.55, watch_col)
			draw_circle(Vector2(cx, cy + s * 0.05), s * 0.45, Color(0.95, 0.92, 0.85, 0.9))
			# Clock hands
			draw_line(Vector2(cx, cy + s * 0.05), Vector2(cx, cy - s * 0.2), Color(0.2, 0.15, 0.1), 1.5)
			draw_line(Vector2(cx, cy + s * 0.05), Vector2(cx + s * 0.15, cy + s * 0.15), Color(0.2, 0.15, 0.1), 1.5)
			# Ring at top
			draw_arc(Vector2(cx, cy - s * 0.55), s * 0.12, 0, TAU, 8, watch_col, 2.0)
			# Chain hint
			draw_line(Vector2(cx, cy - s * 0.67), Vector2(cx + s * 0.3, cy - s * 0.75), watch_col, 1.5)
		"cheshire_grin":
			# Floating grin
			var grin_col = Color(0.9, 0.4, 0.8, 0.8)
			draw_arc(Vector2(cx, cy), s * 0.5, 0.15, PI - 0.15, 12, grin_col, 2.5)
			# Teeth
			for ti in range(5):
				var tx = cx - s * 0.35 + float(ti) * s * 0.175
				draw_rect(Rect2(tx, cy - s * 0.04, s * 0.12, s * 0.12), Color(0.95, 0.95, 0.9, 0.8))
			# Eyes (floating above)
			draw_circle(Vector2(cx - s * 0.25, cy - s * 0.35), s * 0.1, grin_col)
			draw_circle(Vector2(cx + s * 0.25, cy - s * 0.35), s * 0.1, grin_col)
			draw_circle(Vector2(cx - s * 0.25, cy - s * 0.35), s * 0.04, Color(0.1, 0.1, 0.1))
			draw_circle(Vector2(cx + s * 0.25, cy - s * 0.35), s * 0.04, Color(0.1, 0.1, 0.1))
		"ruby_slippers":
			# Red shoes
			var shoe_col = Color(0.85, 0.1, 0.15, 0.9)
			# Left shoe
			draw_colored_polygon(PackedVector2Array([Vector2(cx - s * 0.6, cy + s * 0.1), Vector2(cx - s * 0.1, cy + s * 0.1), Vector2(cx - s * 0.1, cy + s * 0.4), Vector2(cx - s * 0.7, cy + s * 0.4), Vector2(cx - s * 0.75, cy + s * 0.25)]), shoe_col)
			# Right shoe
			draw_colored_polygon(PackedVector2Array([Vector2(cx + s * 0.1, cy + s * 0.1), Vector2(cx + s * 0.6, cy + s * 0.1), Vector2(cx + s * 0.75, cy + s * 0.25), Vector2(cx + s * 0.7, cy + s * 0.4), Vector2(cx + s * 0.1, cy + s * 0.4)]), shoe_col)
			# Sparkles
			draw_circle(Vector2(cx - s * 0.4, cy + s * 0.2), s * 0.05, Color(1.0, 0.8, 0.8, 0.9))
			draw_circle(Vector2(cx + s * 0.4, cy + s * 0.2), s * 0.05, Color(1.0, 0.8, 0.8, 0.9))
			draw_circle(Vector2(cx - s * 0.25, cy + s * 0.15), s * 0.03, Color(1.0, 1.0, 0.9, 0.7))
			draw_circle(Vector2(cx + s * 0.5, cy + s * 0.3), s * 0.03, Color(1.0, 1.0, 0.9, 0.7))
			# Heels
			draw_rect(Rect2(cx - s * 0.15, cy + s * 0.4, s * 0.08, s * 0.2), shoe_col)
			draw_rect(Rect2(cx + s * 0.55, cy + s * 0.4, s * 0.08, s * 0.2), shoe_col)
		"crystal_ball":
			# Glass orb on stand
			var orb_col = Color(0.6, 0.7, 0.9, 0.5)
			draw_circle(Vector2(cx, cy - s * 0.1), s * 0.45, orb_col)
			draw_arc(Vector2(cx, cy - s * 0.1), s * 0.45, 0, TAU, 16, Color(0.7, 0.8, 1.0, 0.6), 1.5)
			# Inner glow
			draw_circle(Vector2(cx - s * 0.1, cy - s * 0.2), s * 0.12, Color(0.8, 0.9, 1.0, 0.4))
			# Stand
			draw_colored_polygon(PackedVector2Array([Vector2(cx - s * 0.2, cy + s * 0.3), Vector2(cx + s * 0.2, cy + s * 0.3), Vector2(cx + s * 0.35, cy + s * 0.6), Vector2(cx - s * 0.35, cy + s * 0.6)]), Color(0.5, 0.4, 0.2, 0.8))
		"monkey_fez":
			# Red fez hat
			var fez_col = Color(0.8, 0.15, 0.1, 0.9)
			# Main body
			draw_colored_polygon(PackedVector2Array([Vector2(cx - s * 0.35, cy + s * 0.3), Vector2(cx + s * 0.35, cy + s * 0.3), Vector2(cx + s * 0.25, cy - s * 0.35), Vector2(cx - s * 0.25, cy - s * 0.35)]), fez_col)
			# Flat top
			draw_rect(Rect2(cx - s * 0.28, cy - s * 0.4, s * 0.56, s * 0.08), fez_col)
			# Tassel
			draw_line(Vector2(cx + s * 0.15, cy - s * 0.4), Vector2(cx + s * 0.45, cy - s * 0.15), Color(0.85, 0.7, 0.1), 1.5)
			draw_circle(Vector2(cx + s * 0.45, cy - s * 0.15), s * 0.06, Color(0.85, 0.7, 0.1))
			# Brim
			draw_rect(Rect2(cx - s * 0.4, cy + s * 0.28, s * 0.8, s * 0.06), Color(0.6, 0.1, 0.08, 0.9))
		"poppy_dust":
			# Red flowers
			var poppy_col = Color(0.9, 0.15, 0.1, 0.8)
			# Three poppies
			for pi in range(3):
				var px = cx - s * 0.35 + float(pi) * s * 0.35
				var py = cy - s * 0.1 + sin(float(pi) * 1.5) * s * 0.15
				for petal in range(5):
					var angle = float(petal) * TAU / 5.0
					var ppx = px + cos(angle) * s * 0.15
					var ppy = py + sin(angle) * s * 0.15
					draw_circle(Vector2(ppx, ppy), s * 0.1, poppy_col)
				draw_circle(Vector2(px, py), s * 0.06, Color(0.15, 0.1, 0.05))
			# Dust particles
			draw_circle(Vector2(cx + s * 0.3, cy - s * 0.4), s * 0.04, Color(1.0, 0.8, 0.3, 0.5))
			draw_circle(Vector2(cx - s * 0.2, cy - s * 0.5), s * 0.03, Color(1.0, 0.8, 0.3, 0.4))
		"golden_cap":
			# Gold cap
			var cap_col = Color(0.9, 0.75, 0.15, 0.9)
			# Dome
			draw_arc(Vector2(cx, cy + s * 0.1), s * 0.45, PI, TAU, 12, cap_col, 2.0)
			draw_colored_polygon(PackedVector2Array([Vector2(cx - s * 0.45, cy + s * 0.1), Vector2(cx + s * 0.45, cy + s * 0.1), Vector2(cx + s * 0.3, cy - s * 0.3), Vector2(cx, cy - s * 0.45), Vector2(cx - s * 0.3, cy - s * 0.3)]), cap_col)
			# Brim
			draw_rect(Rect2(cx - s * 0.55, cy + s * 0.08, s * 1.1, s * 0.1), Color(0.85, 0.65, 0.1, 0.9))
			# Center jewel
			draw_circle(Vector2(cx, cy - s * 0.1), s * 0.1, Color(0.6, 0.1, 0.5, 0.9))
			# Rune marks
			draw_line(Vector2(cx - s * 0.2, cy + s * 0.0), Vector2(cx - s * 0.1, cy - s * 0.15), Color(0.5, 0.1, 0.4, 0.5), 1.0)
			draw_line(Vector2(cx + s * 0.1, cy - s * 0.15), Vector2(cx + s * 0.2, cy + s * 0.0), Color(0.5, 0.1, 0.4, 0.5), 1.0)
		"hourglass":
			# Hourglass
			var glass_col = Color(0.7, 0.6, 0.4, 0.8)
			# Top triangle
			draw_colored_polygon(PackedVector2Array([Vector2(cx - s * 0.4, cy - s * 0.7), Vector2(cx + s * 0.4, cy - s * 0.7), Vector2(cx, cy)]), Color(0.85, 0.75, 0.55, 0.5))
			# Bottom triangle
			draw_colored_polygon(PackedVector2Array([Vector2(cx, cy), Vector2(cx + s * 0.4, cy + s * 0.7), Vector2(cx - s * 0.4, cy + s * 0.7)]), Color(0.85, 0.75, 0.55, 0.5))
			# Sand (bottom fill)
			draw_colored_polygon(PackedVector2Array([Vector2(cx, cy + s * 0.2), Vector2(cx + s * 0.3, cy + s * 0.7), Vector2(cx - s * 0.3, cy + s * 0.7)]), Color(0.9, 0.75, 0.3, 0.7))
			# Frame bars
			draw_rect(Rect2(cx - s * 0.45, cy - s * 0.75, s * 0.9, s * 0.08), glass_col)
			draw_rect(Rect2(cx - s * 0.45, cy + s * 0.67, s * 0.9, s * 0.08), glass_col)
		"fairy_vial":
			# Glowing vial
			var vial_col = Color(0.4, 0.8, 0.5, 0.6)
			# Bottle body
			draw_rect(Rect2(cx - s * 0.08, cy - s * 0.6, s * 0.16, s * 0.25), Color(0.6, 0.7, 0.65, 0.6))
			draw_colored_polygon(PackedVector2Array([Vector2(cx - s * 0.08, cy - s * 0.35), Vector2(cx + s * 0.08, cy - s * 0.35), Vector2(cx + s * 0.25, cy - s * 0.1), Vector2(cx + s * 0.25, cy + s * 0.6), Vector2(cx - s * 0.25, cy + s * 0.6), Vector2(cx - s * 0.25, cy - s * 0.1)]), vial_col)
			# Glow
			draw_circle(Vector2(cx, cy + s * 0.1), s * 0.3, Color(0.5, 1.0, 0.6, 0.2))
			# Sparkles
			draw_circle(Vector2(cx - s * 0.08, cy), s * 0.04, Color(1.0, 1.0, 0.7, 0.8))
			draw_circle(Vector2(cx + s * 0.1, cy + s * 0.25), s * 0.03, Color(1.0, 1.0, 0.7, 0.7))
			draw_circle(Vector2(cx, cy + s * 0.4), s * 0.035, Color(1.0, 1.0, 0.7, 0.6))
		"iron_hook":
			# Captain Hook's hook
			var hook_col = Color(0.6, 0.62, 0.65, 0.9)
			# Shaft
			draw_rect(Rect2(cx - s * 0.07, cy - s * 0.7, s * 0.14, s * 0.6), hook_col)
			# Curved hook
			draw_arc(Vector2(cx, cy + s * 0.1), s * 0.3, PI * 0.0, PI * 1.3, 10, hook_col, 3.0)
			# Point
			var hook_end_x = cx + s * 0.3 * cos(PI * 1.3)
			var hook_end_y = cy + s * 0.1 + s * 0.3 * sin(PI * 1.3)
			draw_circle(Vector2(hook_end_x, hook_end_y), s * 0.05, hook_col)
			# Guard ring
			draw_arc(Vector2(cx, cy - s * 0.15), s * 0.15, 0, TAU, 8, Color(0.85, 0.65, 0.1, 0.6), 2.0)
		"star_map":
			# Star map / scroll with stars
			var map_col = Color(0.75, 0.7, 0.55, 0.8)
			# Scroll body
			draw_rect(Rect2(cx - s * 0.5, cy - s * 0.45, s * 1.0, s * 0.9), Color(0.15, 0.1, 0.25, 0.8))
			# Scroll rolls
			draw_circle(Vector2(cx - s * 0.5, cy - s * 0.45), s * 0.08, map_col)
			draw_circle(Vector2(cx + s * 0.5, cy - s * 0.45), s * 0.08, map_col)
			draw_circle(Vector2(cx - s * 0.5, cy + s * 0.45), s * 0.08, map_col)
			draw_circle(Vector2(cx + s * 0.5, cy + s * 0.45), s * 0.08, map_col)
			# Stars on map
			var star_positions = [Vector2(-0.2, -0.2), Vector2(0.25, -0.1), Vector2(0.0, 0.15), Vector2(-0.3, 0.1), Vector2(0.3, 0.25)]
			for sp in star_positions:
				draw_circle(Vector2(cx + sp.x * s, cy + sp.y * s), s * 0.06, Color(1.0, 0.9, 0.4, 0.8))
			# Constellation lines
			draw_line(Vector2(cx - s * 0.2, cy - s * 0.2), Vector2(cx + s * 0.25, cy - s * 0.1), Color(0.7, 0.7, 0.9, 0.3), 1.0)
			draw_line(Vector2(cx + s * 0.25, cy - s * 0.1), Vector2(cx, cy + s * 0.15), Color(0.7, 0.7, 0.9, 0.3), 1.0)
		"croc_tooth":
			# Large fang
			var tooth_col = Color(0.9, 0.88, 0.8, 0.9)
			draw_colored_polygon(PackedVector2Array([Vector2(cx - s * 0.2, cy - s * 0.65), Vector2(cx + s * 0.2, cy - s * 0.65), Vector2(cx + s * 0.12, cy + s * 0.15), Vector2(cx, cy + s * 0.7), Vector2(cx - s * 0.12, cy + s * 0.15)]), tooth_col)
			# Root ridges
			draw_line(Vector2(cx - s * 0.12, cy - s * 0.5), Vector2(cx - s * 0.06, cy - s * 0.1), Color(0.7, 0.65, 0.55, 0.4), 1.0)
			draw_line(Vector2(cx + s * 0.12, cy - s * 0.5), Vector2(cx + s * 0.06, cy - s * 0.1), Color(0.7, 0.65, 0.55, 0.4), 1.0)
			# Blood hint
			draw_circle(Vector2(cx, cy + s * 0.55), s * 0.06, Color(0.7, 0.1, 0.1, 0.4))
		"thimble":
			# Silver thimble
			var thimble_col = Color(0.75, 0.78, 0.82, 0.85)
			# Dome top
			draw_arc(Vector2(cx, cy - s * 0.15), s * 0.3, PI, TAU, 10, thimble_col, 2.0)
			draw_colored_polygon(PackedVector2Array([Vector2(cx - s * 0.3, cy - s * 0.15), Vector2(cx + s * 0.3, cy - s * 0.15), Vector2(cx + s * 0.15, cy - s * 0.4), Vector2(cx, cy - s * 0.48), Vector2(cx - s * 0.15, cy - s * 0.4)]), thimble_col)
			# Cylinder body
			draw_rect(Rect2(cx - s * 0.3, cy - s * 0.15, s * 0.6, s * 0.65), thimble_col)
			# Dimple dots
			for row in range(3):
				for col in range(4):
					var dx = cx - s * 0.2 + float(col) * s * 0.13
					var dy = cy - s * 0.35 + float(row) * s * 0.12
					draw_circle(Vector2(dx, dy), s * 0.03, Color(0.6, 0.62, 0.65, 0.6))
			# Bottom rim
			draw_rect(Rect2(cx - s * 0.33, cy + s * 0.45, s * 0.66, s * 0.06), Color(0.65, 0.68, 0.72, 0.9))
		"shadow_thread":
			# Dark thread / wispy shadow
			var thread_col = Color(0.2, 0.15, 0.3, 0.8)
			# Wavy thread lines
			for ti in range(5):
				var ty_off = -s * 0.6 + float(ti) * s * 0.3
				var pts: Array[Vector2] = []
				for seg in range(8):
					var tx_seg = cx - s * 0.5 + float(seg) * s * 0.14
					var ty_seg = cy + ty_off + sin(float(seg) * 1.2 + float(ti)) * s * 0.1
					pts.append(Vector2(tx_seg, ty_seg))
				for seg in range(pts.size() - 1):
					draw_line(pts[seg], pts[seg + 1], thread_col, 1.5 + float(ti) * 0.3)
			# Needle
			draw_line(Vector2(cx + s * 0.3, cy - s * 0.7), Vector2(cx + s * 0.5, cy - s * 0.3), Color(0.7, 0.7, 0.75, 0.7), 1.5)
			draw_circle(Vector2(cx + s * 0.5, cy - s * 0.3), s * 0.04, Color(0.7, 0.7, 0.75, 0.7))
		"red_rose":
			# Red rose
			var rose_col = Color(0.85, 0.1, 0.15, 0.9)
			# Petals (overlapping circles)
			draw_circle(Vector2(cx, cy - s * 0.25), s * 0.2, rose_col)
			draw_circle(Vector2(cx - s * 0.15, cy - s * 0.1), s * 0.18, rose_col)
			draw_circle(Vector2(cx + s * 0.15, cy - s * 0.1), s * 0.18, rose_col)
			draw_circle(Vector2(cx - s * 0.08, cy + s * 0.05), s * 0.15, rose_col)
			draw_circle(Vector2(cx + s * 0.08, cy + s * 0.05), s * 0.15, rose_col)
			# Center
			draw_circle(Vector2(cx, cy - s * 0.08), s * 0.08, Color(0.6, 0.05, 0.1))
			# Stem
			draw_line(Vector2(cx, cy + s * 0.12), Vector2(cx - s * 0.05, cy + s * 0.7), Color(0.2, 0.5, 0.15), 2.0)
			# Leaf
			draw_colored_polygon(PackedVector2Array([Vector2(cx - s * 0.05, cy + s * 0.4), Vector2(cx - s * 0.3, cy + s * 0.3), Vector2(cx - s * 0.05, cy + s * 0.5)]), Color(0.2, 0.5, 0.15, 0.8))
		"punjab_lasso":
			# Coiled rope / lasso
			var rope_col = Color(0.6, 0.5, 0.3, 0.85)
			# Coils
			draw_arc(Vector2(cx, cy - s * 0.1), s * 0.4, 0, TAU, 12, rope_col, 2.5)
			draw_arc(Vector2(cx, cy - s * 0.1), s * 0.28, 0.3, TAU + 0.3, 10, rope_col, 2.0)
			draw_arc(Vector2(cx, cy - s * 0.1), s * 0.16, 0.6, TAU + 0.6, 8, rope_col, 1.5)
			# Hanging end
			draw_line(Vector2(cx + s * 0.4, cy - s * 0.1), Vector2(cx + s * 0.3, cy + s * 0.5), rope_col, 2.0)
			# Knot
			draw_circle(Vector2(cx + s * 0.3, cy + s * 0.5), s * 0.08, rope_col)
		"opera_score":
			# Sheet music
			var paper_col = Color(0.9, 0.85, 0.7, 0.85)
			# Paper
			draw_rect(Rect2(cx - s * 0.45, cy - s * 0.6, s * 0.9, s * 1.2), paper_col)
			# Staff lines
			for li in range(5):
				var ly = cy - s * 0.35 + float(li) * s * 0.15
				draw_line(Vector2(cx - s * 0.38, ly), Vector2(cx + s * 0.38, ly), Color(0.3, 0.25, 0.2, 0.5), 1.0)
			# Music notes
			draw_circle(Vector2(cx - s * 0.2, cy - s * 0.2), s * 0.06, Color(0.2, 0.15, 0.1, 0.8))
			draw_line(Vector2(cx - s * 0.14, cy - s * 0.2), Vector2(cx - s * 0.14, cy - s * 0.5), Color(0.2, 0.15, 0.1, 0.8), 1.0)
			draw_circle(Vector2(cx + s * 0.05, cy - s * 0.05), s * 0.06, Color(0.2, 0.15, 0.1, 0.8))
			draw_line(Vector2(cx + s * 0.11, cy - s * 0.05), Vector2(cx + s * 0.11, cy - s * 0.4), Color(0.2, 0.15, 0.1, 0.8), 1.0)
			draw_circle(Vector2(cx + s * 0.25, cy + s * 0.1), s * 0.06, Color(0.2, 0.15, 0.1, 0.8))
			draw_line(Vector2(cx + s * 0.31, cy + s * 0.1), Vector2(cx + s * 0.31, cy - s * 0.2), Color(0.2, 0.15, 0.1, 0.8), 1.0)
		"chandelier_chain":
			# Chain links
			var chain_col = Color(0.7, 0.65, 0.5, 0.85)
			# Vertical chain of oval links
			for li in range(4):
				var ly = cy - s * 0.55 + float(li) * s * 0.3
				draw_arc(Vector2(cx, ly), s * 0.12, 0, TAU, 8, chain_col, 2.0)
			# Horizontal connector at bottom
			draw_line(Vector2(cx - s * 0.35, cy + s * 0.45), Vector2(cx + s * 0.35, cy + s * 0.45), chain_col, 2.0)
			# Small chandelier shape at bottom
			draw_line(Vector2(cx - s * 0.35, cy + s * 0.45), Vector2(cx - s * 0.25, cy + s * 0.65), chain_col, 1.5)
			draw_line(Vector2(cx + s * 0.35, cy + s * 0.45), Vector2(cx + s * 0.25, cy + s * 0.65), chain_col, 1.5)
			draw_line(Vector2(cx, cy + s * 0.45), Vector2(cx, cy + s * 0.7), chain_col, 1.5)
			# Candle flames
			draw_circle(Vector2(cx - s * 0.25, cy + s * 0.6), s * 0.05, Color(1.0, 0.8, 0.2, 0.7))
			draw_circle(Vector2(cx + s * 0.25, cy + s * 0.6), s * 0.05, Color(1.0, 0.8, 0.2, 0.7))
		"gondola_key":
			# Ornate key
			var key_col = Color(0.75, 0.6, 0.25, 0.9)
			# Bow (circular top)
			draw_arc(Vector2(cx - s * 0.15, cy - s * 0.35), s * 0.25, 0, TAU, 10, key_col, 2.5)
			draw_circle(Vector2(cx - s * 0.15, cy - s * 0.35), s * 0.15, Color(0.08, 0.05, 0.03))
			# Shaft
			draw_rect(Rect2(cx - s * 0.05, cy - s * 0.15, s * 0.1, s * 0.8), key_col)
			# Bit (teeth at bottom)
			draw_rect(Rect2(cx + s * 0.05, cy + s * 0.45, s * 0.2, s * 0.06), key_col)
			draw_rect(Rect2(cx + s * 0.05, cy + s * 0.55, s * 0.15, s * 0.06), key_col)
		"hand_mirror":
			# Hand mirror
			var mirror_col = Color(0.75, 0.6, 0.25, 0.9)
			# Mirror face (oval)
			draw_circle(Vector2(cx, cy - s * 0.2), s * 0.38, mirror_col)
			draw_circle(Vector2(cx, cy - s * 0.2), s * 0.3, Color(0.75, 0.82, 0.9, 0.7))
			# Reflection shine
			draw_circle(Vector2(cx - s * 0.1, cy - s * 0.3), s * 0.08, Color(1.0, 1.0, 1.0, 0.3))
			# Handle
			draw_rect(Rect2(cx - s * 0.08, cy + s * 0.15, s * 0.16, s * 0.55), mirror_col)
			# Handle end
			draw_circle(Vector2(cx, cy + s * 0.7), s * 0.1, mirror_col)
		"heavy_chains":
			# Heavy chains
			var chains_col = Color(0.55, 0.5, 0.45, 0.85)
			# Multiple chain links in a pile
			for ci in range(3):
				var chain_cx = cx - s * 0.25 + float(ci) * s * 0.25
				for li in range(3):
					var chain_cy = cy - s * 0.3 + float(li) * s * 0.25
					draw_arc(Vector2(chain_cx, chain_cy), s * 0.1, 0, TAU, 6, chains_col, 2.5)
			# Padlock at center
			draw_rect(Rect2(cx - s * 0.12, cy + s * 0.2, s * 0.24, s * 0.25), Color(0.5, 0.45, 0.35, 0.9))
			draw_arc(Vector2(cx, cy + s * 0.2), s * 0.1, PI, TAU, 6, chains_col, 2.0)
		"ghost_lantern":
			# Glowing lantern
			var lantern_col = Color(0.6, 0.55, 0.35, 0.85)
			# Handle
			draw_arc(Vector2(cx, cy - s * 0.45), s * 0.15, PI, TAU, 8, lantern_col, 2.0)
			# Body frame
			draw_rect(Rect2(cx - s * 0.25, cy - s * 0.35, s * 0.5, s * 0.7), Color(0.0, 0.0, 0.0, 0.3))
			draw_rect(Rect2(cx - s * 0.25, cy - s * 0.35, s * 0.5, 2), lantern_col)
			draw_rect(Rect2(cx - s * 0.25, cy + s * 0.35 - 2, s * 0.5, 2), lantern_col)
			draw_rect(Rect2(cx - s * 0.25, cy - s * 0.35, 2, s * 0.7), lantern_col)
			draw_rect(Rect2(cx + s * 0.25 - 2, cy - s * 0.35, 2, s * 0.7), lantern_col)
			# Glow inside
			draw_circle(Vector2(cx, cy), s * 0.18, Color(0.5, 0.9, 0.6, 0.3))
			draw_circle(Vector2(cx, cy), s * 0.1, Color(0.6, 1.0, 0.7, 0.4))
			# Base
			draw_rect(Rect2(cx - s * 0.3, cy + s * 0.35, s * 0.6, s * 0.12), lantern_col)
		"brass_key":
			# Brass key (simpler than gondola key)
			var bkey_col = Color(0.8, 0.65, 0.2, 0.9)
			# Bow (diamond shape)
			draw_colored_polygon(PackedVector2Array([Vector2(cx, cy - s * 0.6), Vector2(cx + s * 0.2, cy - s * 0.35), Vector2(cx, cy - s * 0.1), Vector2(cx - s * 0.2, cy - s * 0.35)]), bkey_col)
			draw_colored_polygon(PackedVector2Array([Vector2(cx, cy - s * 0.5), Vector2(cx + s * 0.1, cy - s * 0.35), Vector2(cx, cy - s * 0.2), Vector2(cx - s * 0.1, cy - s * 0.35)]), Color(0.08, 0.05, 0.03))
			# Shaft
			draw_rect(Rect2(cx - s * 0.05, cy - s * 0.15, s * 0.1, s * 0.75), bkey_col)
			# Teeth
			draw_rect(Rect2(cx + s * 0.05, cy + s * 0.35, s * 0.15, s * 0.06), bkey_col)
			draw_rect(Rect2(cx + s * 0.05, cy + s * 0.48, s * 0.12, s * 0.06), bkey_col)
		"xmas_pudding":
			# Steaming pudding
			var pudding_col = Color(0.45, 0.25, 0.1, 0.9)
			# Bowl
			draw_colored_polygon(PackedVector2Array([Vector2(cx - s * 0.45, cy - s * 0.05), Vector2(cx + s * 0.45, cy - s * 0.05), Vector2(cx + s * 0.35, cy + s * 0.55), Vector2(cx - s * 0.35, cy + s * 0.55)]), pudding_col)
			# Pudding dome
			draw_arc(Vector2(cx, cy - s * 0.05), s * 0.45, PI, TAU, 10, pudding_col, 2.0)
			draw_colored_polygon(PackedVector2Array([Vector2(cx - s * 0.45, cy - s * 0.05), Vector2(cx + s * 0.45, cy - s * 0.05), Vector2(cx + s * 0.3, cy - s * 0.35), Vector2(cx, cy - s * 0.45), Vector2(cx - s * 0.3, cy - s * 0.35)]), pudding_col)
			# White sauce drip
			draw_colored_polygon(PackedVector2Array([Vector2(cx - s * 0.35, cy - s * 0.25), Vector2(cx + s * 0.35, cy - s * 0.25), Vector2(cx + s * 0.3, cy - s * 0.05), Vector2(cx + s * 0.15, cy + s * 0.1), Vector2(cx, cy - s * 0.05), Vector2(cx - s * 0.2, cy + s * 0.15), Vector2(cx - s * 0.3, cy - s * 0.05)]), Color(0.95, 0.92, 0.85, 0.8))
			# Holly on top
			draw_circle(Vector2(cx - s * 0.05, cy - s * 0.35), s * 0.06, Color(0.85, 0.1, 0.1, 0.9))
			draw_circle(Vector2(cx + s * 0.08, cy - s * 0.38), s * 0.06, Color(0.85, 0.1, 0.1, 0.9))
			# Steam wisps
			draw_arc(Vector2(cx - s * 0.15, cy - s * 0.55), s * 0.1, PI * 0.8, PI * 1.8, 6, Color(0.8, 0.8, 0.8, 0.3), 1.0)
			draw_arc(Vector2(cx + s * 0.1, cy - s * 0.6), s * 0.08, PI * 0.7, PI * 1.7, 6, Color(0.8, 0.8, 0.8, 0.25), 1.0)
		"fiddle":
			# Violin/fiddle
			var fiddle_col = Color(0.6, 0.35, 0.12, 0.9)
			# Body (figure-8)
			draw_circle(Vector2(cx, cy + s * 0.15), s * 0.3, fiddle_col)
			draw_circle(Vector2(cx, cy - s * 0.2), s * 0.22, fiddle_col)
			# Waist
			draw_rect(Rect2(cx - s * 0.12, cy - s * 0.1, s * 0.24, s * 0.15), Color(0.08, 0.05, 0.03))
			draw_rect(Rect2(cx - s * 0.15, cy - s * 0.05, s * 0.3, s * 0.08), fiddle_col)
			# Neck
			draw_rect(Rect2(cx - s * 0.05, cy - s * 0.55, s * 0.1, s * 0.35), fiddle_col)
			# Scroll
			draw_arc(Vector2(cx, cy - s * 0.58), s * 0.08, PI * 0.5, PI * 2.0, 6, fiddle_col, 2.0)
			# Strings
			for si_str in range(4):
				var sx_str = cx - s * 0.09 + float(si_str) * s * 0.06
				draw_line(Vector2(sx_str, cy - s * 0.4), Vector2(sx_str, cy + s * 0.35), Color(0.8, 0.75, 0.6, 0.5), 0.8)
			# F-holes
			draw_line(Vector2(cx - s * 0.1, cy + s * 0.0), Vector2(cx - s * 0.1, cy + s * 0.2), Color(0.08, 0.05, 0.03, 0.6), 1.0)
			draw_line(Vector2(cx + s * 0.1, cy + s * 0.0), Vector2(cx + s * 0.1, cy + s * 0.2), Color(0.08, 0.05, 0.03, 0.6), 1.0)
			# Bow (diagonal)
			draw_line(Vector2(cx + s * 0.4, cy - s * 0.6), Vector2(cx - s * 0.3, cy + s * 0.5), Color(0.55, 0.35, 0.15, 0.5), 1.0)
		"church_bell":
			# Church bell
			var bell_col = Color(0.8, 0.65, 0.2, 0.85)
			# Bell body
			draw_colored_polygon(PackedVector2Array([Vector2(cx - s * 0.15, cy - s * 0.55), Vector2(cx + s * 0.15, cy - s * 0.55), Vector2(cx + s * 0.2, cy - s * 0.3), Vector2(cx + s * 0.15, cy + s * 0.1), Vector2(cx + s * 0.4, cy + s * 0.35), Vector2(cx + s * 0.45, cy + s * 0.45), Vector2(cx - s * 0.45, cy + s * 0.45), Vector2(cx - s * 0.4, cy + s * 0.35), Vector2(cx - s * 0.15, cy + s * 0.1), Vector2(cx - s * 0.2, cy - s * 0.3)]), bell_col)
			# Clapper
			draw_line(Vector2(cx, cy - s * 0.2), Vector2(cx, cy + s * 0.3), Color(0.5, 0.4, 0.15), 1.5)
			draw_circle(Vector2(cx, cy + s * 0.32), s * 0.07, Color(0.5, 0.4, 0.15))
			# Top mount
			draw_rect(Rect2(cx - s * 0.1, cy - s * 0.65, s * 0.2, s * 0.12), Color(0.5, 0.4, 0.2))
			draw_arc(Vector2(cx, cy - s * 0.65), s * 0.12, PI, TAU, 6, Color(0.5, 0.4, 0.2), 2.0)
		_:
			# Fallback: diamond icon
			draw_colored_polygon(PackedVector2Array([Vector2(cx, cy - s * 0.5), Vector2(cx + s * 0.35, cy), Vector2(cx, cy + s * 0.5), Vector2(cx - s * 0.35, cy)]), Color(accent.r, accent.g, accent.b, 0.4))

func _draw_survivor_detail() -> void:
	if survivor_detail_index < 0 or survivor_detail_index >= survivor_types.size():
		return

	var panel_x = 70.0
	var panel_y = 45.0
	var panel_w = 1140.0
	var panel_h = 560.0
	var tower_type = survivor_types[survivor_detail_index]
	var info = tower_info[tower_type]
	var progress = survivor_progress.get(tower_type, {"level": 1, "xp": 0.0, "xp_next": 500.0, "gear_unlocked": false, "sidekicks_unlocked": [false, false, false], "relics_unlocked": [false, false, false, false, false, false]})

	var card_colors = [
		Color(0.29, 0.55, 0.25),  # Robin Hood
		Color(0.44, 0.66, 0.86),  # Alice
		Color(0.48, 0.25, 0.63),  # Wicked Witch
		Color(0.90, 0.49, 0.13),  # Peter Pan
		Color(0.75, 0.22, 0.17),  # Phantom
		Color(0.79, 0.66, 0.30),  # Scrooge
	]
	var accent = card_colors[survivor_detail_index]

	# Navy background
	for i in range(56):
		var t = float(i) / 55.0
		var col = menu_bg_section.lerp(menu_bg_dark, t)
		draw_rect(Rect2(panel_x, panel_y + t * panel_h, panel_w, panel_h / 55.0 + 1), col)

	# Ornate outer border — gold double frame
	var sd_outer = Color(menu_gold_dim.r, menu_gold_dim.g, menu_gold_dim.b, 0.35)
	var sd_gold = Color(0.65, 0.45, 0.1, 0.2)
	draw_rect(Rect2(panel_x, panel_y, panel_w, 3), sd_outer)
	draw_rect(Rect2(panel_x, panel_y + panel_h - 3, panel_w, 3), sd_outer)
	draw_rect(Rect2(panel_x, panel_y, 3, panel_h), sd_outer)
	draw_rect(Rect2(panel_x + panel_w - 3, panel_y, 3, panel_h), sd_outer)
	draw_rect(Rect2(panel_x + 6, panel_y + 6, panel_w - 12, 1), sd_gold)
	draw_rect(Rect2(panel_x + 6, panel_y + panel_h - 7, panel_w - 12, 1), sd_gold)
	draw_rect(Rect2(panel_x + 6, panel_y + 6, 1, panel_h - 12), sd_gold)
	draw_rect(Rect2(panel_x + panel_w - 7, panel_y + 6, 1, panel_h - 12), sd_gold)

	# === LEFT SIDE: Character portrait area ===
	var left_x = panel_x + 30.0
	var left_w = 420.0

	# Portrait frame (dark recessed area)
	var portrait_x = left_x + 30.0
	var portrait_y = panel_y + 70.0
	var portrait_w = 360.0
	var portrait_h = 320.0
	draw_rect(Rect2(portrait_x, portrait_y, portrait_w, portrait_h), Color(0.03, 0.03, 0.08))
	# Portrait border
	draw_rect(Rect2(portrait_x, portrait_y, portrait_w, 2), Color(accent.r, accent.g, accent.b, 0.4))
	draw_rect(Rect2(portrait_x, portrait_y + portrait_h - 2, portrait_w, 2), Color(accent.r, accent.g, accent.b, 0.4))
	draw_rect(Rect2(portrait_x, portrait_y, 2, portrait_h), Color(accent.r, accent.g, accent.b, 0.4))
	draw_rect(Rect2(portrait_x + portrait_w - 2, portrait_y, 2, portrait_h), Color(accent.r, accent.g, accent.b, 0.4))

	# Accent color glow behind character
	draw_circle(Vector2(portrait_x + portrait_w * 0.5, portrait_y + portrait_h * 0.55), 80.0, Color(accent.r, accent.g, accent.b, 0.06))
	draw_circle(Vector2(portrait_x + portrait_w * 0.5, portrait_y + portrait_h * 0.55), 50.0, Color(accent.r, accent.g, accent.b, 0.04))

	# Level badge (top-left of portrait)
	var badge_cx = portrait_x + 30.0
	var badge_cy = portrait_y + 30.0
	draw_circle(Vector2(badge_cx, badge_cy), 22, Color(0.05, 0.05, 0.12))
	draw_circle(Vector2(badge_cx, badge_cy), 20, Color(accent.r, accent.g, accent.b, 0.7))
	draw_circle(Vector2(badge_cx, badge_cy), 16, Color(0.04, 0.04, 0.10))
	draw_arc(Vector2(badge_cx, badge_cy), 20, 0, TAU, 16, Color(0.85, 0.65, 0.1, 0.4), 1.5)

	# XP progress bar (below portrait)
	var xp_x = portrait_x + 20.0
	var xp_y = portrait_y + portrait_h + 15.0
	var xp_w = portrait_w - 40.0
	var xp_h = 14.0
	var xp_ratio = clamp(progress["xp"] / max(progress["xp_next"], 1.0), 0.0, 1.0)
	# Bar background
	draw_rect(Rect2(xp_x, xp_y, xp_w, xp_h), Color(0.04, 0.04, 0.10))
	draw_rect(Rect2(xp_x, xp_y, xp_w, 1), Color(0.65, 0.45, 0.1, 0.2))
	draw_rect(Rect2(xp_x, xp_y + xp_h - 1, xp_w, 1), Color(0.65, 0.45, 0.1, 0.2))
	# Bar fill
	if xp_ratio > 0:
		draw_rect(Rect2(xp_x + 1, xp_y + 1, (xp_w - 2) * xp_ratio, xp_h - 2), Color(accent.r, accent.g, accent.b, 0.7))
		# Shine
		draw_rect(Rect2(xp_x + 1, xp_y + 1, (xp_w - 2) * xp_ratio, 3), Color(1.0, 1.0, 1.0, 0.08))

	# === RIGHT SIDE: Gear, Sidekicks, Relics ===
	var right_x = panel_x + left_w + 50.0
	var right_y = panel_y + 60.0

	# --- GEAR section ---
	var gear_y = right_y
	# Gear slot (single large slot)
	var gear_data = survivor_gear.get(tower_type, {"name": "Unknown", "desc": ""})
	var gear_slot_x = right_x + 10.0
	var gear_slot_y = gear_y + 30.0
	var slot_size = 64.0
	# Slot frame
	draw_rect(Rect2(gear_slot_x, gear_slot_y, slot_size, slot_size), Color(0.04, 0.04, 0.10))
	var gear_border = Color(0.85, 0.65, 0.1, 0.4) if progress["gear_unlocked"] else Color(0.4, 0.3, 0.2, 0.3)
	draw_rect(Rect2(gear_slot_x, gear_slot_y, slot_size, 2), gear_border)
	draw_rect(Rect2(gear_slot_x, gear_slot_y + slot_size - 2, slot_size, 2), gear_border)
	draw_rect(Rect2(gear_slot_x, gear_slot_y, 2, slot_size), gear_border)
	draw_rect(Rect2(gear_slot_x + slot_size - 2, gear_slot_y, 2, slot_size), gear_border)
	if progress["gear_unlocked"]:
		# Draw gear icon
		draw_circle(Vector2(gear_slot_x + slot_size * 0.5, gear_slot_y + slot_size * 0.5), 18, Color(accent.r, accent.g, accent.b, 0.3))
		draw_arc(Vector2(gear_slot_x + slot_size * 0.5, gear_slot_y + slot_size * 0.5), 14, 0, TAU, 12, Color(0.85, 0.65, 0.1, 0.4), 2.0)
	else:
		# Lock icon
		draw_rect(Rect2(gear_slot_x + 22, gear_slot_y + 30, 20, 16), Color(0.4, 0.3, 0.2, 0.4))
		draw_arc(Vector2(gear_slot_x + 32, gear_slot_y + 30), 8, PI, TAU, 8, Color(0.4, 0.3, 0.2, 0.4), 2.0)

	# --- SIDEKICKS section ---
	var sk_y = gear_y + 120.0
	var sk_data = survivor_sidekicks.get(tower_type, [])
	for si in range(3):
		var sx = right_x + 10.0 + float(si) * (slot_size + 16.0)
		var sy = sk_y + 30.0
		draw_rect(Rect2(sx, sy, slot_size, slot_size), Color(0.04, 0.04, 0.10))
		var sk_unlocked = progress["sidekicks_unlocked"][si] if si < progress["sidekicks_unlocked"].size() else false
		var sk_border = Color(0.85, 0.65, 0.1, 0.4) if sk_unlocked else Color(0.4, 0.3, 0.2, 0.3)
		draw_rect(Rect2(sx, sy, slot_size, 2), sk_border)
		draw_rect(Rect2(sx, sy + slot_size - 2, slot_size, 2), sk_border)
		draw_rect(Rect2(sx, sy, 2, slot_size), sk_border)
		draw_rect(Rect2(sx + slot_size - 2, sy, 2, slot_size), sk_border)
		if sk_unlocked and si < sk_data.size():
			draw_circle(Vector2(sx + slot_size * 0.5, sy + slot_size * 0.5), 16, Color(accent.r, accent.g, accent.b, 0.25))
			# Silhouette
			draw_circle(Vector2(sx + slot_size * 0.5, sy + slot_size * 0.35), 10, Color(0.7, 0.6, 0.45, 0.3))
			draw_rect(Rect2(sx + slot_size * 0.3, sy + slot_size * 0.5, slot_size * 0.4, slot_size * 0.3), Color(0.7, 0.6, 0.45, 0.2))
		else:
			# Plus icon
			draw_rect(Rect2(sx + 28, sy + 20, 8, 24), Color(0.35, 0.25, 0.18, 0.4))
			draw_rect(Rect2(sx + 20, sy + 28, 24, 8), Color(0.35, 0.25, 0.18, 0.4))

	# --- RELICS section ---
	var rel_y = sk_y + 120.0
	var char_relics = survivor_relics.get(tower_type, [])
	var relic_size = 56.0
	var relic_earn_levels = [2, 4, 6, 8, 10, 12]  # Levels at which relics become available
	var relic_purchasable = [false, true, false, true, false, true]  # Even indices earned, odd purchasable
	var relic_costs = [0, 100, 0, 250, 0, 500]
	var char_level = progress.get("level", 1)
	for ri in range(6):
		var rx = right_x + 10.0 + float(ri) * (relic_size + 10.0)
		var ry = rel_y + 30.0
		draw_rect(Rect2(rx, ry, relic_size, relic_size), Color(0.04, 0.04, 0.10))
		var rel_unlocked = progress["relics_unlocked"][ri] if ri < progress["relics_unlocked"].size() else false
		var is_available = char_level >= relic_earn_levels[ri]
		var is_purchasable_slot = relic_purchasable[ri]
		var rel_border = Color(0.85, 0.65, 0.1, 0.4) if rel_unlocked else (Color(0.6, 0.5, 0.2, 0.4) if is_available and is_purchasable_slot else Color(0.4, 0.3, 0.2, 0.3))
		draw_rect(Rect2(rx, ry, relic_size, 2), rel_border)
		draw_rect(Rect2(rx, ry + relic_size - 2, relic_size, 2), rel_border)
		draw_rect(Rect2(rx, ry, 2, relic_size), rel_border)
		draw_rect(Rect2(rx + relic_size - 2, ry, 2, relic_size), rel_border)
		if rel_unlocked and ri < char_relics.size():
			# Draw unique relic icon
			var rcx = rx + relic_size * 0.5
			var rcy = ry + relic_size * 0.5
			_draw_relic_icon(Vector2(rcx, rcy), char_relics[ri]["icon"], relic_size * 0.7, accent)
		elif is_available and is_purchasable_slot and not rel_unlocked and ri < char_relics.size():
			# Purchasable but not yet bought - show gold cost
			var rcx = rx + relic_size * 0.5
			var rcy = ry + relic_size * 0.5
			# Gold coin icon
			draw_circle(Vector2(rcx, rcy - 4), 10, Color(0.85, 0.65, 0.1, 0.4))
			draw_circle(Vector2(rcx, rcy - 4), 7, Color(0.9, 0.7, 0.15, 0.3))
		else:
			# Lock icon (padlock)
			var lock_col = Color(0.45, 0.35, 0.25, 0.6)
			draw_rect(Rect2(rx + 20, ry + 28, 16, 14), lock_col)
			draw_arc(Vector2(rx + 28, ry + 28), 7, PI, TAU, 8, lock_col, 2.0)
			draw_circle(Vector2(rx + 28, ry + 34), 2, Color(0.2, 0.15, 0.1, 0.8))

	# Relic tooltip (when hovering over a relic slot)
	if relic_hover_index >= 0 and relic_hover_index < char_relics.size():
		var relic_data = char_relics[relic_hover_index]
		var tooltip_x = right_x + 10.0
		var tooltip_y = rel_y + 30.0 + relic_size + 8.0
		var tooltip_w = relic_size * 6.0 + 10.0 * 5.0
		var tooltip_h = 48.0
		# Tooltip background
		draw_rect(Rect2(tooltip_x, tooltip_y, tooltip_w, tooltip_h), Color(0.12, 0.08, 0.04, 0.95))
		draw_rect(Rect2(tooltip_x, tooltip_y, tooltip_w, 1), Color(0.85, 0.65, 0.1, 0.4))
		draw_rect(Rect2(tooltip_x, tooltip_y + tooltip_h - 1, tooltip_w, 1), Color(0.85, 0.65, 0.1, 0.4))
		draw_rect(Rect2(tooltip_x, tooltip_y, 1, tooltip_h), Color(0.85, 0.65, 0.1, 0.4))
		draw_rect(Rect2(tooltip_x + tooltip_w - 1, tooltip_y, 1, tooltip_h), Color(0.85, 0.65, 0.1, 0.4))

	# Decorative separator line
	draw_line(Vector2(right_x, right_y + panel_h - 90), Vector2(right_x + 640, right_y + panel_h - 90), Color(0.65, 0.45, 0.1, 0.1), 1.0)

func _draw_open_book() -> void:
	# === Open book (two-page spread) ===
	var bx = 70.0
	var by = 45.0
	var pw = 560.0  # page width
	var ph = 555.0  # page height
	var spine_x = bx + pw + 10  # spine center

	# Book shadow
	draw_rect(Rect2(bx - 5 + 8, by - 5 + 8, pw * 2 + 30, ph + 10), Color(0.02, 0.02, 0.06, 0.35))

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

	# Spine (leather center with gold bands)
	draw_rect(Rect2(spine_x - 5, by - 8, 20, ph + 16), Color(0.22, 0.10, 0.04))
	for i in range(5):
		var sy = by + 60.0 + float(i) * 100.0
		# All gold bands
		draw_line(Vector2(spine_x - 5, sy), Vector2(spine_x + 15, sy), Color(0.65, 0.45, 0.1, 0.35), 2.0)
		# Embossed diamond shapes on spine
		var diamond_cx = spine_x + 5.0
		var diamond_cy = sy + 50.0
		draw_colored_polygon(PackedVector2Array([Vector2(diamond_cx, diamond_cy - 6), Vector2(diamond_cx + 4, diamond_cy), Vector2(diamond_cx, diamond_cy + 6), Vector2(diamond_cx - 4, diamond_cy)]), Color(0.65, 0.45, 0.1, 0.2))
	# Spine shadow gradient
	for i in range(15):
		var t = float(i) / 14.0
		draw_line(Vector2(spine_x + 15 + t * 8, by), Vector2(spine_x + 15 + t * 8, by + ph), Color(0.0, 0.0, 0.0, 0.06 * (1.0 - t)), 1.0)
		draw_line(Vector2(spine_x - 5 - t * 8, by), Vector2(spine_x - 5 - t * 8, by + ph), Color(0.0, 0.0, 0.0, 0.06 * (1.0 - t)), 1.0)

	# Page borders — gold outer frame (3px) + gold inner frame (1px) — left page
	var outer_border = Color(menu_gold_dim.r, menu_gold_dim.g, menu_gold_dim.b, 0.3)
	var gold_border = Color(0.65, 0.45, 0.1, 0.2)
	# Left page outer gold border (3px)
	draw_rect(Rect2(bx + 8, by + 8, pw - 16, 3), outer_border)
	draw_rect(Rect2(bx + 8, by + ph - 11, pw - 16, 3), outer_border)
	draw_rect(Rect2(bx + 8, by + 8, 3, ph - 16), outer_border)
	draw_rect(Rect2(bx + pw - 11, by + 8, 3, ph - 16), outer_border)
	# Left page inner gold border (1px)
	draw_rect(Rect2(bx + 14, by + 14, pw - 28, 1), gold_border)
	draw_rect(Rect2(bx + 14, by + ph - 15, pw - 28, 1), gold_border)
	draw_rect(Rect2(bx + 14, by + 14, 1, ph - 28), gold_border)
	draw_rect(Rect2(bx + pw - 15, by + 14, 1, ph - 28), gold_border)

	# Right page double border
	var rx = spine_x + 10
	draw_rect(Rect2(rx + 8, by + 8, pw - 16, 3), outer_border)
	draw_rect(Rect2(rx + 8, by + ph - 11, pw - 16, 3), outer_border)
	draw_rect(Rect2(rx + 8, by + 8, 3, ph - 16), outer_border)
	draw_rect(Rect2(rx + pw - 11, by + 8, 3, ph - 16), outer_border)
	draw_rect(Rect2(rx + 14, by + 14, pw - 28, 1), gold_border)
	draw_rect(Rect2(rx + 14, by + ph - 15, pw - 28, 1), gold_border)
	draw_rect(Rect2(rx + 14, by + 14, 1, ph - 28), gold_border)
	draw_rect(Rect2(rx + pw - 15, by + 14, 1, ph - 28), gold_border)

	# Page edge glow — subtle gold line along outer page edges
	draw_rect(Rect2(bx, by, pw, 1), Color(menu_gold_dim.r, menu_gold_dim.g, menu_gold_dim.b, 0.08))
	draw_rect(Rect2(bx, by + ph - 1, pw, 1), Color(menu_gold_dim.r, menu_gold_dim.g, menu_gold_dim.b, 0.08))
	draw_rect(Rect2(bx, by, 1, ph), Color(menu_gold_dim.r, menu_gold_dim.g, menu_gold_dim.b, 0.08))
	draw_rect(Rect2(rx + pw - 1, by, 1, ph), Color(menu_gold_dim.r, menu_gold_dim.g, menu_gold_dim.b, 0.08))

	# L-bracket corner ornaments (left page — gold only)
	for corner in [Vector2(bx + 18, by + 18), Vector2(bx + pw - 18, by + 18), Vector2(bx + 18, by + ph - 18), Vector2(bx + pw - 18, by + ph - 18)]:
		var dx_sign = 1.0 if corner.x < bx + pw * 0.5 else -1.0
		var dy_sign = 1.0 if corner.y < by + ph * 0.5 else -1.0
		draw_line(corner, corner + Vector2(12 * dx_sign, 0), Color(0.65, 0.45, 0.1, 0.25), 1.0)
		draw_line(corner, corner + Vector2(0, 12 * dy_sign), Color(0.65, 0.45, 0.1, 0.25), 1.0)
		draw_line(corner + Vector2(12 * dx_sign, 0), corner + Vector2(12 * dx_sign, 4 * dy_sign), Color(0.65, 0.45, 0.1, 0.2), 1.0)
		draw_line(corner + Vector2(0, 12 * dy_sign), corner + Vector2(4 * dx_sign, 12 * dy_sign), Color(0.65, 0.45, 0.1, 0.2), 1.0)
		draw_circle(corner, 5, Color(0.65, 0.45, 0.1, 0.2))
		draw_circle(corner, 3.5, Color(0.65, 0.45, 0.1, 0.15))
		draw_circle(corner, 2, Color(0.65, 0.45, 0.1, 0.25))

	# L-bracket corner ornaments (right page — gold only)
	for corner in [Vector2(rx + 18, by + 18), Vector2(rx + pw - 18, by + 18), Vector2(rx + 18, by + ph - 18), Vector2(rx + pw - 18, by + ph - 18)]:
		var dx_sign2 = 1.0 if corner.x < rx + pw * 0.5 else -1.0
		var dy_sign2 = 1.0 if corner.y < by + ph * 0.5 else -1.0
		draw_line(corner, corner + Vector2(12 * dx_sign2, 0), Color(0.65, 0.45, 0.1, 0.25), 1.0)
		draw_line(corner, corner + Vector2(0, 12 * dy_sign2), Color(0.65, 0.45, 0.1, 0.25), 1.0)
		draw_line(corner + Vector2(12 * dx_sign2, 0), corner + Vector2(12 * dx_sign2, 4 * dy_sign2), Color(0.65, 0.45, 0.1, 0.2), 1.0)
		draw_line(corner + Vector2(0, 12 * dy_sign2), corner + Vector2(4 * dx_sign2, 12 * dy_sign2), Color(0.65, 0.45, 0.1, 0.2), 1.0)
		draw_circle(corner, 5, Color(0.65, 0.45, 0.1, 0.2))
		draw_circle(corner, 3.5, Color(0.65, 0.45, 0.1, 0.15))
		draw_circle(corner, 2, Color(0.65, 0.45, 0.1, 0.25))

	# Ink blot decorations (right page corners)
	draw_circle(Vector2(rx + pw - 40, by + ph - 40), 6.0, Color(0.2, 0.15, 0.1, 0.06))
	draw_circle(Vector2(rx + pw - 35, by + ph - 45), 4.0, Color(0.2, 0.15, 0.1, 0.04))

	# Left page: character preview area (tower preview is placed by menu system)
	if menu_current_view == "chapters":
		var char_idx = menu_character_index
		# Character-themed decorative motif on left page
		var motif_y = by + 160.0
		var motif_x = bx + pw * 0.5
		# Draw a simple emblem/crest area
		draw_circle(Vector2(motif_x, motif_y + 80), 60, Color(0.65, 0.45, 0.1, 0.04))
		draw_arc(Vector2(motif_x, motif_y + 80), 55, 0, TAU, 48, Color(0.65, 0.45, 0.1, 0.12), 1.5)
		draw_arc(Vector2(motif_x, motif_y + 80), 45, 0, TAU, 48, Color(0.65, 0.45, 0.1, 0.08), 1.0)

		# Character emblem icons (simple procedural)
		match char_idx:
			0:  # Robin Hood - bow and arrow
				draw_arc(Vector2(motif_x, motif_y + 80), 25, 1.0, 5.3, 32, Color(0.4, 0.25, 0.08, 0.35), 2.5)
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
				draw_arc(Vector2(motif_x, motif_y + 72), 18, PI + 0.3, TAU - 0.3, 32, Color(0.9, 0.88, 0.82, 0.35), 3.0)
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
			# Small gold dots at ends of separator
			draw_circle(Vector2(rx + 30, sep_y), 2.0, Color(menu_gold_dim.r, menu_gold_dim.g, menu_gold_dim.b, 0.2))
			draw_circle(Vector2(rx + pw - 30, sep_y), 2.0, Color(menu_gold_dim.r, menu_gold_dim.g, menu_gold_dim.b, 0.2))

	# Page tab bookmarks on right edge (character quick nav) — enhanced gothic
	var tab_colors = [Color(0.29, 0.55, 0.25), Color(0.44, 0.66, 0.86), Color(0.48, 0.25, 0.63), Color(0.90, 0.49, 0.13), Color(0.75, 0.22, 0.17), Color(0.79, 0.66, 0.30)]
	if menu_current_view == "chapters":
		for i in range(6):
			var tab_y = by + 30.0 + float(i) * 80.0
			var tab_x = rx + pw - 5
			var is_active = (i == menu_character_index)
			var tab_w = 24.0 if is_active else 16.0
			var tab_alpha = (0.7 + sin(_time * 2.0) * 0.15) if is_active else 0.25
			var tab_h = 50.0
			var tc = Color(tab_colors[i].r, tab_colors[i].g, tab_colors[i].b, tab_alpha)
			# Glow effect behind active tab
			if is_active:
				draw_circle(Vector2(tab_x + tab_w * 0.5, tab_y + tab_h * 0.5), 30.0, Color(tab_colors[i].r, tab_colors[i].g, tab_colors[i].b, 0.08))
			# Tab rectangle
			draw_rect(Rect2(tab_x, tab_y, tab_w, tab_h), tc)
			# Gothic pointed bottom edge (triangle)
			draw_colored_polygon(PackedVector2Array([Vector2(tab_x, tab_y + tab_h), Vector2(tab_x + tab_w, tab_y + tab_h), Vector2(tab_x + tab_w * 0.5, tab_y + tab_h + 8)]), tc)
			# Thin gold border on inner edge
			draw_line(Vector2(tab_x, tab_y), Vector2(tab_x, tab_y + tab_h), Color(0.65, 0.45, 0.1, 0.3), 1.0)

# ============================================================
# GAME LOOP
# ============================================================

func _process(delta: float) -> void:
	_time += delta
	# Ability popup freeze
	if _ability_popup_freeze > 0.0:
		_ability_popup_freeze -= delta
		_ability_popup_timer -= delta
		if _ability_popup_timer <= 0.0:
			_ability_popup_timer = 0.0
		queue_redraw()
		return
	if _ability_popup_timer > 0.0:
		_ability_popup_timer -= delta
	if game_state != GameState.PLAYING:
		if survivor_detail_open:
			_update_relic_hover()
		elif menu_current_view == "survivors":
			_update_world_map_hover()
		elif menu_current_view == "relics":
			_update_relics_tab_hover()
		elif menu_current_view == "emporium":
			_update_emporium_hover()
		queue_redraw()
		return
	ghost_position = get_global_mouse_position()
	_update_spawn_debuffs()
	if is_wave_active:
		_handle_spawning(delta)
		_check_wave_complete()
	elif wave_auto_timer > 0.0:
		wave_auto_timer -= delta
		if wave_auto_timer <= 0.0:
			wave_auto_timer = -1.0
			_start_next_wave()
	# Fighting voice-over catchphrases (every 20-30s during combat)
	if placed_tower_positions.size() > 0:
		_fighting_quote_timer -= delta
		if _fighting_quote_timer <= 0.0 and not catchphrase_player.playing:
			_play_random_fighting_quote()
			_fighting_quote_timer = randf_range(20.0, 30.0)
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

	# Progressive difficulty scaling (supports 20-40 waves)
	var w = wave
	if w <= 5:
		# Phase 1: Gentle introduction
		enemy.max_health = 60.0 + w * 18.0
		enemy.speed = 65.0 + w * 4.0
		enemy.gold_reward = 8 + w * 2
	elif w <= 10:
		# Phase 2: Building pressure
		enemy.max_health = 140.0 + (w - 5) * 35.0
		enemy.speed = 80.0 + (w - 5) * 5.0
		enemy.gold_reward = 16 + (w - 5) * 3
	elif w <= 16:
		# Phase 3: Challenging
		enemy.max_health = 300.0 + (w - 10) * 50.0
		enemy.speed = 100.0 + (w - 10) * 4.0
		enemy.gold_reward = 28 + (w - 10) * 4
	elif w <= 24:
		# Phase 4: Hard
		enemy.max_health = 580.0 + (w - 16) * 70.0
		enemy.speed = 115.0 + (w - 16) * 4.0
		enemy.gold_reward = 48 + (w - 16) * 5
	elif w <= 32:
		# Phase 5: Very hard
		enemy.max_health = 1100.0 + (w - 24) * 100.0
		enemy.speed = 130.0 + (w - 24) * 3.0
		enemy.gold_reward = 85 + (w - 24) * 7
	else:
		# Phase 6: Brutal (waves 33-40)
		enemy.max_health = 1800.0 + (w - 32) * 150.0
		enemy.speed = 145.0 + (w - 32) * 3.0
		enemy.gold_reward = 135 + (w - 32) * 10

	# === Boss wave modifiers ===
	# Milestone bosses at waves 20, 25, 30, 35 — bigger, tougher, slower
	var is_boss_wave = w in [20, 25, 30, 35]
	var is_final_villain = w >= 39 and selected_difficulty == 2  # Hard mode waves 39-40
	var is_last_wave = w == total_waves

	if is_final_villain:
		# Final villain — extremely strong, very large
		enemy.max_health *= 8.0
		enemy.speed *= 0.55
		enemy.gold_reward += 100
		enemy.enemy_tier = 3
		enemy.boss_scale = 2.5
	elif is_boss_wave:
		# Milestone boss — much stronger, larger
		var boss_mult = 1.0 + float(w) / 20.0  # 2.0x at w20, 2.25x at w25, etc.
		enemy.max_health *= 3.5 * boss_mult
		enemy.speed *= 0.65
		enemy.gold_reward += 40 + w
		enemy.boss_scale = 1.8
	elif is_last_wave:
		# Final wave of the difficulty — strong boss
		enemy.max_health *= 4.0
		enemy.speed *= 0.7
		enemy.gold_reward += 50
		enemy.boss_scale = 2.0

	# Variety waves (fast rushes and swarms between bosses)
	if not is_boss_wave and not is_final_villain and not is_last_wave:
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

	# Difficulty mode multiplier (Easy=0.85, Medium=1.0, Hard=1.2)
	var diff_mult = [0.85, 1.0, 1.2][selected_difficulty]
	enemy.max_health *= diff_mult
	enemy.speed *= (0.9 + selected_difficulty * 0.05)

	# Level difficulty multiplier
	if current_level >= 0 and current_level < levels.size():
		var diff = levels[current_level]["difficulty"]
		enemy.max_health *= diff
		enemy.speed = enemy.speed * (1.0 + (diff - 1.0) * 0.3)

	# Apply spawn debuffs from progressive abilities
	if spawn_hp_reduction > 0.0:
		enemy.max_health *= (1.0 - spawn_hp_reduction)
	enemy.health = enemy.max_health
	if spawn_permanent_slow < 1.0:
		enemy.apply_permanent_slow(spawn_permanent_slow)
	enemy_path.add_child(enemy)
	enemies_to_spawn -= 1
	enemies_alive += 1

func _get_wave_enemy_count(w: int) -> int:
	var base = 4 + w * 2
	# Boss waves: fewer but much stronger enemies
	if w in [20, 25, 30, 35]:
		return max(3, base / 3)
	# Final villain waves (Hard 39-40): very few, very strong
	if w >= 39 and selected_difficulty == 2:
		return 2 if w == 40 else 3
	# Last wave of any difficulty: boss encounter
	if w == total_waves:
		return max(3, base / 3)
	# Variety waves
	var q = max(1, int(total_waves * 0.25))
	var h = max(1, int(total_waves * 0.5))
	var tq = max(1, int(total_waves * 0.75))
	if w == q: return base + 8   # Fast rush — lots of enemies
	if w == h: return base - 4   # Tank wave — fewer enemies
	if w == tq: return base + 12 # Swarm
	return base

func _get_wave_spawn_interval(w: int) -> float:
	# Boss waves spawn slower (dramatic pacing)
	if w in [20, 25, 30, 35] or w == total_waves:
		return 2.0
	if w >= 39 and selected_difficulty == 2:
		return 3.0  # Final villains — very slow, dramatic
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

	# === Boss milestone wave names (override regular names) ===
	var boss_names = {
		0: {  # Robin Hood
			20: "BOSS — The Sheriff's Champion!",
			25: "BOSS — The Black Knight!",
			30: "BOSS — Sir Guy of Gisbourne!",
			35: "BOSS — Prince John's Warlord!",
			39: "FINAL VILLAIN — Prince John Arrives!",
			40: "FINAL VILLAIN — The Crown's Vengeance!",
		},
		1: {  # Alice
			20: "BOSS — The Jabberwock Awakens!",
			25: "BOSS — The Red Queen's Champion!",
			30: "BOSS — The Bandersnatch!",
			35: "BOSS — The Vorpal Beast!",
			39: "FINAL VILLAIN — The Queen of Hearts!",
			40: "FINAL VILLAIN — Off With ALL Their Heads!",
		},
		2: {  # Wicked Witch
			20: "BOSS — The Winkie Warlord!",
			25: "BOSS — The King of the Flying Monkeys!",
			30: "BOSS — The Great and Terrible Oz!",
			35: "BOSS — The Nome King's General!",
			39: "FINAL VILLAIN — The Nome King Rises!",
			40: "FINAL VILLAIN — The Throne of Stone!",
		},
		3: {  # Peter Pan
			20: "BOSS — The Pirate Quartermaster!",
			25: "BOSS — The Crocodile Hunter!",
			30: "BOSS — Blackbeard's Ghost!",
			35: "BOSS — Hook's Right Hand!",
			39: "FINAL VILLAIN — Captain Hook!",
			40: "FINAL VILLAIN — The Jolly Roger's Last Stand!",
		},
		4: {  # Phantom
			20: "BOSS — The Grand Chandelier Falls!",
			25: "BOSS — The Mirror Shade!",
			30: "BOSS — The Opera Gargoyle!",
			35: "BOSS — The Masked Maestro!",
			39: "FINAL VILLAIN — The Phantom Unmasked!",
			40: "FINAL VILLAIN — The Phantom's Requiem!",
		},
		5: {  # Scrooge
			20: "BOSS — Marley's Ghost!",
			25: "BOSS — The Ghost of Christmas Past!",
			30: "BOSS — The Ghost of Christmas Present!",
			35: "BOSS — The Ghost of Christmas Future!",
			39: "FINAL VILLAIN — Death's Shadow!",
			40: "FINAL VILLAIN — Scrooge's Final Reckoning!",
		},
	}
	# Check for boss/final villain waves
	if char_idx in boss_names and w in boss_names[char_idx]:
		if w >= 39 and selected_difficulty < 2:
			pass  # Only show final villain names on Hard
		elif w > total_waves:
			pass  # Don't show boss names beyond the wave count
		else:
			return boss_names[char_idx][w]

	match char_idx:
		0: # Robin Hood
			match chap_idx:
				0: # Ch1 â€” Tax collectors, early Sherwood
					if w == q: return "FAST RUSH â€” Swift tax riders!"
					if w == h: return "TANK WAVE â€” Armored revenue cart!"
					if w == tq: return "SWARM â€” Tax collector stampede!"
					if w == total_waves: return "BOSS â€” The Royal Tax Master!"
					var n = ["Tax collectors spotted!", "Revenue patrol incoming", "More tax men approach",
						"Sherwood road toll guards", "Tax wagon escort", "Sheriff's informants",
						"Tax assessor squad", "Coin purse snatchers", "Tithe enforcers march",
						"Ledger-bearing clerks", "Treasury scouts advance", "Royal tax decree!",
						"Debt warrant officers", "Gold cart guardsmen"]
					return n[(w - 1) % n.size()]
				1: # Ch2 â€” Sheriff's soldiers, escalation
					if w == q: return "FAST RUSH â€” Mounted sheriff's scouts!"
					if w == h: return "TANK WAVE â€” Armored knights ride forth!"
					if w == tq: return "SWARM â€” The Sheriff's full garrison!"
					if w == total_waves: return "BOSS â€” The Sheriff of Nottingham!"
					var n = ["Sheriff's patrol spotted!", "Soldiers from the castle", "Crossbow sentries advance",
						"Nottingham cavalry scouts", "Castle garrison deploys", "Sheriff's archers march",
						"Knight errant vanguard", "Pikemen hold the line", "Sheriff's war hounds",
						"Battering ram escort", "Armored lance brigade", "Castle wall defenders",
						"The Sheriff's elite guard", "Siege tower builders"]
					return n[(w - 1) % n.size()]
				2: # Ch3 â€” Siege of Nottingham, climax
					if w == q: return "FAST RUSH â€” Siege scouts sprint ahead!"
					if w == h: return "TANK WAVE â€” Castle siege engines!"
					if w == tq: return "SWARM â€” All of Nottingham marches!"
					if w == total_waves: return "BOSS â€” Prince John's Royal Army!"
					var n = ["Siege vanguard approaches!", "Trebuchet operators advance", "Battering ram crews",
						"Castle wall breakers", "Prince John's heralds", "Royal decree enforcers",
						"Flaming arrow brigade", "Fortress sappers tunnel in", "War elephant handlers",
						"Crown loyalist knights", "The Prince's iron guard", "Nottingham's last stand",
						"Throne room defenders", "The final siege wave"]
					return n[(w - 1) % n.size()]
		1: # Alice
			match chap_idx:
				0: # Ch1 â€” Card scouts, early Wonderland
					if w == q: return "FAST RUSH â€” Card scouts scramble!"
					if w == h: return "TANK WAVE â€” Armored ace of spades!"
					if w == tq: return "SWARM â€” Full deck deployed!"
					if w == total_waves: return "BOSS â€” The Knave of Hearts!"
					var n = ["Card soldiers spotted!", "Numbered cards march", "Spade patrol incoming",
						"Diamond sentries glitter", "Club enforcers stomp", "Two of hearts scouts",
						"Shuffled patrol advance", "Card painters approach", "Rose garden guards",
						"Croquet ground wardens", "Hedge maze sentries", "Deck reshuffled!",
						"Wild card scouts", "Joker's little helpers"]
					return n[(w - 1) % n.size()]
				1: # Ch2 â€” Mad tea party & chess pieces
					if w == q: return "FAST RUSH â€” March Hare's stampede!"
					if w == h: return "TANK WAVE â€” The Jabberwock stirs!"
					if w == tq: return "SWARM â€” Chess pieces flood the board!"
					if w == total_waves: return "BOSS â€” The Red Queen!"
					var n = ["Mad tea party crashers!", "Dormouse sleeper agents", "March Hare's militia",
						"Cheshire grin stalkers", "Looking glass scouts", "Chess pawn advance",
						"Rook towers roll forward", "Knight pieces gallop", "Bishop diagonal assault",
						"Tweedledee & Tweedledum", "Bandersnatch sighting!", "Mock turtle brigade",
						"Vorpal blade seekers", "Through the looking glass"]
					return n[(w - 1) % n.size()]
				2: # Ch3 â€” Queen's court, climax
					if w == q: return "FAST RUSH â€” Queen's swift executioners!"
					if w == h: return "TANK WAVE â€” Jabberwock unleashed!"
					if w == tq: return "SWARM â€” The entire court attacks!"
					if w == total_waves: return "BOSS â€” The Queen of Hearts!"
					var n = ["Royal court assembles!", "Queen's herald sounds", "Executioner's guard",
						"Flamingo cavalry charge", "The Queen's croquet army", "Painting roses red!",
						"Throne room champions", "Crown jewel defenders", "Off with their heads!",
						"Jabberwock's brood descends", "Royal flush assault", "The Queen's ultimatum",
						"Wonderland unravels!", "Final verdict approaches"]
					return n[(w - 1) % n.size()]
		2: # Wicked Witch / Oz
			match chap_idx:
				0: # Ch1 â€” Winkie guards, early Oz
					if w == q: return "FAST RUSH â€” Winkie scouts dash!"
					if w == h: return "TANK WAVE â€” Armored Winkie captain!"
					if w == tq: return "SWARM â€” Winkie regiment marches!"
					if w == total_waves: return "BOSS â€” The Winkie General!"
					var n = ["Winkie guards spotted!", "Yellow uniform patrol", "Western frontier scouts",
						"Poppy field lurkers", "Winkie spear carriers", "Emerald road blockers",
						"Yellow brick sentries", "Winkie drum corps", "Witch's errand runners",
						"Tin whistle scouts", "Scarecrow field watchers", "Winkie border patrol",
						"Golden cap seekers", "Oz perimeter guards"]
					return n[(w - 1) % n.size()]
				1: # Ch2 â€” Flying monkeys & the Witch rises
					if w == q: return "FAST RUSH â€” Flying monkeys swoop!"
					if w == h: return "TANK WAVE â€” Armored gorilla guard!"
					if w == tq: return "SWARM â€” Monkey horde darkens the sky!"
					if w == total_waves: return "BOSS â€” The Wicked Witch of the West!"
					var n = ["Flying monkeys approach!", "Monkey squadron descends", "Winged ambush party",
						"Witch's cauldron brew stirs", "Broom-riding scouts", "Monkey bombardiers",
						"Crystal ball spies", "Enchanted forest walkers", "Tornado debris creatures",
						"Silver shoe seekers", "Witch's shadow minions", "Dark spell weavers",
						"Monkey king's vanguard", "The Witch's cackle echoes"]
					return n[(w - 1) % n.size()]
				2: # Ch3 â€” Nome King & Emerald City siege
					if w == q: return "FAST RUSH â€” Nome tunnelers burst forth!"
					if w == h: return "TANK WAVE â€” Rock titan advances!"
					if w == tq: return "SWARM â€” Underground legion surfaces!"
					if w == total_waves: return "BOSS â€” The Nome King!"
					var n = ["Nome tunnelers emerge!", "Crystal cave raiders", "Rock soldiers march",
						"Underground sappers dig in", "Gemstone golem patrol", "Emerald City spies",
						"Nome King's heralds", "Quartz shard throwers", "Obsidian knight brigade",
						"Magma core dwellers", "The Nome King stirs!", "Jewel-encrusted sentinels",
						"Earthquake brigade", "The throne room trembles"]
					return n[(w - 1) % n.size()]
		3: # Peter Pan
			match chap_idx:
				0: # Ch1 â€” Pirate scouts, Neverland shores
					if w == q: return "FAST RUSH â€” Pirate scouts sprint!"
					if w == h: return "TANK WAVE â€” Powder keg haulers!"
					if w == tq: return "SWARM â€” Shore landing party!"
					if w == total_waves: return "BOSS â€” The Pirate Bosun!"
					var n = ["Pirate deckhands arrive!", "Swabbie patrol incoming", "Buccaneer scouts",
						"Cutlass-wielding mates", "Crow's nest lookouts", "Plank walkers march",
						"Powder monkey brigade", "Rum barrel rollers", "Anchor chain draggers",
						"Dinghy landing crew", "Treasure map hunters", "Skull Rock sentries",
						"Parrot messenger scouts", "Neverland shore patrol"]
					return n[(w - 1) % n.size()]
				1: # Ch2 â€” Pirate officers & jungle dangers
					if w == q: return "FAST RUSH â€” Jungle ambush runners!"
					if w == h: return "TANK WAVE â€” Pirate cannon crew!"
					if w == tq: return "SWARM â€” Lost Boys besieged!"
					if w == total_waves: return "BOSS â€” The Pirate First Mate!"
					var n = ["Pirate officers advance!", "Boarding party inbound", "Cannon crew approaches",
						"First mate's detachment", "Jungle vine swingers", "Mermaid Lagoon assault",
						"Crocodile handlers march", "Boatswain's brigade", "Musket-bearing pirates",
						"Jungle trap setters", "Tiger Lily's warning!", "Neverland fog creepers",
						"Pirate war drummers", "The jungle closes in"]
					return n[(w - 1) % n.size()]
				2: # Ch3 â€” Captain Hook & the Jolly Roger
					if w == q: return "FAST RUSH â€” Hook's fastest cutthroats!"
					if w == h: return "TANK WAVE â€” Ironclad pirate warship!"
					if w == tq: return "SWARM â€” The entire Jolly Roger crew!"
					if w == total_waves: return "BOSS â€” Captain Hook!"
					var n = ["Hook sends his vanguard!", "Jolly Roger's finest", "The Black Spot cometh",
						"Hook's elite swordsmen", "Cannonball barrage crew", "All hands on deck!",
						"Pirate armada sails forth", "Hook's personal guard", "Tick-Tock draws near!",
						"Gangplank executioners", "The captain's ultimatum", "Jolly Roger broadside!",
						"Hook's final gambit", "Neverland's darkest hour"]
					return n[(w - 1) % n.size()]
		4: # Phantom
			match chap_idx:
				0: # Ch1 â€” Stagehands & shadows, opera house
					if w == q: return "FAST RUSH â€” Shadow dancers dart!"
					if w == h: return "TANK WAVE â€” Heavy curtain golem!"
					if w == tq: return "SWARM â€” Backstage mob floods out!"
					if w == total_waves: return "BOSS â€” The Stage Manager!"
					var n = ["Stagehands scurry forth!", "The orchestra stirs", "Shadows in the wings",
						"Prop room escapees", "Spotlight chasers", "Rats from below the stage",
						"Costume rack lurkers", "Sandbag droppers above", "Makeup room horrors",
						"Backstage frenzy builds", "Rigging rope swingers", "Prompt box whisperers",
						"Curtain pullers advance", "The overture begins"]
					return n[(w - 1) % n.size()]
				1: # Ch2 â€” Labyrinth & mirrors, deeper opera
					if w == q: return "FAST RUSH â€” Mirror shards scatter!"
					if w == h: return "TANK WAVE â€” Gargoyle sentinels descend!"
					if w == tq: return "SWARM â€” Labyrinth spawns endlessly!"
					if w == total_waves: return "BOSS â€” The Mirror Phantom!"
					var n = ["The masquerade begins!", "Mirror maze madness", "Trapdoor ambush below",
						"Labyrinth of mirrors", "Candelabra ghosts flicker", "Phantom copycats emerge",
						"Gargoyle watchers stir", "Chandelier chain rattlers", "Opera ghost sightings",
						"Box Five awakens!", "Falling curtain shades", "Hall of echoes patrol",
						"Wax figure sentries", "The organ's fury builds"]
					return n[(w - 1) % n.size()]
				2: # Ch3 â€” Underground lair, climax
					if w == q: return "FAST RUSH â€” Lair bats swarm the exits!"
					if w == h: return "TANK WAVE â€” The organ colossus!"
					if w == tq: return "SWARM â€” Underground phantoms pour forth!"
					if w == total_waves: return "BOSS â€” The Phantom of the Opera!"
					var n = ["Underground lake patrol!", "Christine's nightmare stirs", "Lair entrance guardians",
						"Sewer tunnel crawlers", "Subterranean echo shades", "Candle-lit crypt walkers",
						"The Phantom's music swells", "Torture chamber sentinels", "Lasso-wielding shadows",
						"Pipe organ resonators", "Lake of fire boatmen", "Mask fragment seekers",
						"The final act begins!", "Beneath the opera forever"]
					return n[(w - 1) % n.size()]
		5: # Scrooge
			match chap_idx:
				0: # Ch1 â€” Street urchins & carolers, London streets
					if w == q: return "FAST RUSH â€” Pickpocket dash!"
					if w == h: return "TANK WAVE â€” Workhouse bruiser!"
					if w == tq: return "SWARM â€” Street mob riots!"
					if w == total_waves: return "BOSS â€” The Debt Collector General!"
					var n = ["Street urchins scuttle!", "Chimney sweepers march", "Pickpocket gang approaches",
						"Workhouse escapees shamble", "Carolers gone wrong", "Fog-born shadows creep",
						"Lamplighter scouts", "Cobblestone prowlers", "Penny-pincher patrol",
						"Beggar brigade advances", "Newspaper boy ambush", "Coal dust sneakers",
						"Frostbitten vagrants", "London's forgotten ones"]
					return n[(w - 1) % n.size()]
				1: # Ch2 â€” Spirits & ghosts, hauntings
					if w == q: return "FAST RUSH â€” Spirit wisps scatter!"
					if w == h: return "TANK WAVE â€” Ghosts of Christmas Past!"
					if w == tq: return "SWARM â€” Spectral procession floods in!"
					if w == total_waves: return "BOSS â€” Ghost of Christmas Present!"
					var n = ["Debt collectors approach!", "Chain rattlers march", "Marley's associates",
						"Counting house guards", "Ghostly apparitions drift", "Spirit wisps gather",
						"Ledger keepers advance", "Top hat enforcers", "Spectral procession forms",
						"Frost wraiths howl!", "Candle flame phantoms", "Clock tower bell shades",
						"Memory lane specters", "The spirits converge"]
					return n[(w - 1) % n.size()]
				2: # Ch3 â€” Army of despair, climax
					if w == q: return "FAST RUSH â€” Despair's swift heralds!"
					if w == h: return "TANK WAVE â€” Marley's iron chains!"
					if w == tq: return "SWARM â€” The army of despair marches!"
					if w == total_waves: return "BOSS â€” Ghost of Christmas Yet to Come!"
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
			var bonus = 5 + wave * 2
			gold += bonus
			update_hud()
			info_label.text = "Wave %d cleared! +%dG bonus. Next wave in 2s..." % [wave, bonus]
			wave_auto_timer = 2.0

func _unhandled_input(event: InputEvent) -> void:
	if game_state != GameState.PLAYING:
		# Handle relic clicks in menu survivor detail view
		if game_state == GameState.MENU and survivor_detail_open:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				if relic_hover_index >= 0:
					_on_relic_clicked(relic_hover_index)
		# Handle world map zone clicks
		elif game_state == GameState.MENU and menu_current_view == "survivors" and not survivor_detail_open:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				if world_map_hover_index >= 0:
					_on_survivor_card_pressed(world_map_hover_index)
		# Handle emporium tile clicks
		elif game_state == GameState.MENU and menu_current_view == "emporium":
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				if emporium_hover_index >= 0:
					_on_emporium_tile_clicked(emporium_hover_index)
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
				cancel_button.visible = false
				info_label.text = "Placement cancelled."
			else:
				_deselect_tower()
	elif event is InputEventScreenTouch and event.pressed:
		if placing_tower:
			_try_place_tower(event.position)
		else:
			var tower = _find_tower_at(event.position)
			if tower:
				_select_tower(tower)
			else:
				_deselect_tower()
	elif event is InputEventScreenDrag:
		ghost_position = event.position

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

	# Disable the button â€” one purchase per tower
	if tower_buttons.has(selected_tower):
		tower_buttons[selected_tower].text = "PLACED"
		tower_buttons[selected_tower].disabled = true

	placing_tower = false
	cancel_button.visible = false
	var quote = _play_placement_catchphrase(selected_tower)
	info_label.text = "%s: \"%s\"" % [tname, quote]

# ============================================================
# DRAW â€” Level-specific backgrounds
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
		0: _draw_robin_ch1(sky_color, ground_color)
		1: _draw_robin_ch2(sky_color, ground_color)
		2: _draw_robin_ch3(sky_color, ground_color)
		3: _draw_alice_ch1(sky_color, ground_color)
		4: _draw_alice_ch2(sky_color, ground_color)
		5: _draw_alice_ch3(sky_color, ground_color)
		6: _draw_oz_ch1(sky_color, ground_color)
		7: _draw_oz_ch2(sky_color, ground_color)
		8: _draw_oz_ch3(sky_color, ground_color)
		9: _draw_peter_ch1(sky_color, ground_color)
		10: _draw_peter_ch2(sky_color, ground_color)
		11: _draw_peter_ch3(sky_color, ground_color)
		12: _draw_phantom_ch1(sky_color, ground_color)
		13: _draw_phantom_ch2(sky_color, ground_color)
		14: _draw_phantom_ch3(sky_color, ground_color)
		15: _draw_scrooge_ch1(sky_color, ground_color)
		16: _draw_scrooge_ch2(sky_color, ground_color)
		17: _draw_scrooge_ch3(sky_color, ground_color)

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

	# === ABILITY UNLOCK POPUP ===
	if _ability_popup_timer > 0.0:
		_draw_ability_popup()

func _draw_ability_popup() -> void:
	var alpha = clampf(_ability_popup_timer, 0.0, 1.0)
	var cx = 640.0
	var cy = 360.0
	var pw = 500.0
	var ph = 120.0
	# Dark translucent background
	draw_rect(Rect2(cx - pw / 2, cy - ph / 2, pw, ph), Color(0.05, 0.03, 0.08, 0.85 * alpha))
	# Gold ornate border
	draw_rect(Rect2(cx - pw / 2, cy - ph / 2, pw, ph), Color(0.85, 0.7, 0.2, 0.9 * alpha), false, 3.0)
	draw_rect(Rect2(cx - pw / 2 + 4, cy - ph / 2 + 4, pw - 8, ph - 8), Color(0.7, 0.55, 0.15, 0.4 * alpha), false, 1.0)
	# Title
	draw_string(ThemeDB.fallback_font, Vector2(cx - 120, cy - 25), "NEW ABILITY UNLOCKED!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.85, 0.3, alpha))
	# Character name + ability name
	var char_name = character_names[_ability_popup_tower_type] if _ability_popup_tower_type >= 0 and _ability_popup_tower_type < character_names.size() else ""
	draw_string(ThemeDB.fallback_font, Vector2(cx - 140, cy + 5), char_name + " — " + _ability_popup_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 1.0, 0.9, alpha))
	# Description
	if _ability_popup_desc != "":
		draw_string(ThemeDB.fallback_font, Vector2(cx - 140, cy + 28), _ability_popup_desc, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.8, 0.75, alpha * 0.8))
	# Glow effect
	var glow_pulse = (sin(_time * 5.0) + 1.0) * 0.5
	draw_circle(Vector2(cx - pw / 2 + 40, cy), 15.0 + glow_pulse * 5.0, Color(1.0, 0.85, 0.3, 0.1 * alpha))

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
			"sheet_music":
				var smp = dec["pos"]
				var sms = dec["size"]
				var drift = sin(_time * 0.6 + dec["extra"]) * 5.0
				draw_rect(Rect2(smp.x - sms + drift, smp.y - sms * 1.5, sms * 2, sms * 3), Color(0.85, 0.82, 0.7, 0.2))
				for line_idx in range(5):
					draw_line(Vector2(smp.x - sms + drift, smp.y - sms + float(line_idx) * sms * 0.4), Vector2(smp.x + sms + drift, smp.y - sms + float(line_idx) * sms * 0.4), Color(0.2, 0.15, 0.1, 0.15), 0.5)
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


func _draw_robin_ch2(sky_color: Color, ground_color: Color) -> void:
	# --- Sky gradient: dark blue-green night sky ---
	for sy in range(0, 50):
		var t: float = float(sy) / 50.0
		var band_color := Color(
			sky_color.r * 0.3 + 0.02 * t,
			sky_color.g * 0.35 + 0.04 * t,
			sky_color.b * 0.5 + 0.06 * t
		)
		draw_line(Vector2(0, float(sy)), Vector2(1280, float(sy)), band_color, 1.5)

	# --- Stars twinkling in night sky ---
	for si in range(45):
		var sx: float = fmod(float(si) * 173.7 + 51.3, 1280.0)
		var star_y: float = fmod(float(si) * 97.1 + 13.7, 45.0) + 5.0
		var twinkle: float = 0.4 + 0.6 * clampf(sin(_time * (1.5 + float(si) * 0.2) + float(si) * 3.7), 0.0, 1.0)
		var star_size: float = 1.0 + fmod(float(si) * 0.7, 1.5)
		draw_circle(Vector2(sx, star_y), star_size, Color(0.85, 0.9, 1.0, twinkle * 0.8))

	# --- Crescent moon ---
	var moon_x: float = 1050.0 + sin(_time * 0.05) * 5.0
	draw_circle(Vector2(moon_x, 25.0), 18.0, Color(0.9, 0.92, 0.8, 0.85))
	draw_circle(Vector2(moon_x + 7.0, 22.0), 15.0, Color(sky_color.r * 0.3, sky_color.g * 0.35, sky_color.b * 0.5))

	# --- Deep sky to forest canopy transition ---
	for sy2 in range(50, 160):
		var t2: float = float(sy2 - 50) / 110.0
		var canopy_col := Color(
			lerp(sky_color.r * 0.3, 0.01, t2),
			lerp(sky_color.g * 0.35, 0.06, t2),
			lerp(sky_color.b * 0.5, 0.03, t2)
		)
		draw_line(Vector2(0, float(sy2)), Vector2(1280, float(sy2)), canopy_col, 1.5)

	# --- Dense forest canopy silhouettes (background layer) ---
	for ct in range(30):
		var cx: float = fmod(float(ct) * 97.3 + 22.0, 1400.0) - 60.0
		var cy: float = 100.0 + fmod(float(ct) * 31.7, 70.0)
		var crad: float = 40.0 + fmod(float(ct) * 17.3, 35.0)
		var sway: float = sin(_time * 0.4 + float(ct) * 0.8) * 3.0
		var canopy_dark := Color(0.01, 0.04 + fmod(float(ct) * 0.003, 0.02), 0.01, 0.92)
		draw_circle(Vector2(cx + sway, cy), crad, canopy_dark)
		draw_circle(Vector2(cx + sway - crad * 0.5, cy + 10.0), crad * 0.7, canopy_dark)

	# --- Sheriff's torches visible through distant trees ---
	for ti in range(5):
		var torch_x: float = 180.0 + float(ti) * 220.0 + sin(_time * 0.3 + float(ti)) * 15.0
		var torch_y: float = 140.0 + fmod(float(ti) * 23.0, 40.0)
		var torch_flicker: float = 0.6 + 0.4 * sin(_time * 7.0 + float(ti) * 4.3)
		# Distant glow halo
		draw_circle(Vector2(torch_x, torch_y), 25.0, Color(0.6, 0.25, 0.02, 0.06 * torch_flicker))
		draw_circle(Vector2(torch_x, torch_y), 14.0, Color(0.7, 0.35, 0.05, 0.1 * torch_flicker))
		# Torch flame
		draw_circle(Vector2(torch_x, torch_y), 4.5, Color(0.95, 0.7, 0.1, 0.7 * torch_flicker))
		draw_circle(Vector2(torch_x, torch_y - 3.0), 2.5, Color(1.0, 0.9, 0.4, 0.8 * torch_flicker))

	# --- Owl silhouettes perched on branches ---
	for oi in range(3):
		var owl_x: float = 200.0 + float(oi) * 400.0 + sin(_time * 0.15 + float(oi) * 2.0) * 8.0
		var owl_y: float = 115.0 + float(oi) * 18.0
		var owl_col := Color(0.02, 0.02, 0.02, 0.9)
		# Body
		draw_circle(Vector2(owl_x, owl_y), 8.0, owl_col)
		# Head
		draw_circle(Vector2(owl_x, owl_y - 9.0), 5.5, owl_col)
		# Ear tufts
		draw_line(Vector2(owl_x - 4.0, owl_y - 13.0), Vector2(owl_x - 6.0, owl_y - 18.0), owl_col, 2.0)
		draw_line(Vector2(owl_x + 4.0, owl_y - 13.0), Vector2(owl_x + 6.0, owl_y - 18.0), owl_col, 2.0)
		# Eyes glow
		var blink: float = 1.0 if fmod(_time + float(oi) * 3.0, 5.0) > 0.3 else 0.0
		draw_circle(Vector2(owl_x - 2.5, owl_y - 9.5), 1.8, Color(0.9, 0.7, 0.1, 0.7 * blink))
		draw_circle(Vector2(owl_x + 2.5, owl_y - 9.5), 1.8, Color(0.9, 0.7, 0.1, 0.7 * blink))
		# Branch underneath
		draw_line(Vector2(owl_x - 30.0, owl_y + 8.0), Vector2(owl_x + 30.0, owl_y + 6.0), Color(0.06, 0.03, 0.01), 3.0)

	# --- Ground layers: forest floor with leaves ---
	for gy in range(280, 628):
		var gt: float = float(gy - 280) / 348.0
		var gx_wave: float = sin(float(gy) * 0.03 + _time * 0.15) * 0.02
		var floor_col := Color(
			lerp(0.04, ground_color.r * 0.6, gt) + gx_wave,
			lerp(0.08, ground_color.g * 0.5, gt),
			lerp(0.02, ground_color.b * 0.3, gt)
		)
		draw_line(Vector2(0, float(gy)), Vector2(1280, float(gy)), floor_col, 1.5)

	# --- Rushing river with rapids (horizontal, mid-ground) ---
	var river_y: float = 400.0
	for ry in range(30):
		var ry_f: float = float(ry)
		var river_t: float = ry_f / 30.0
		var river_wave: float = sin(ry_f * 0.5 + _time * 2.5) * 3.0
		var depth_col := Color(
			0.05 + 0.08 * river_t,
			0.12 + 0.15 * river_t + 0.03 * sin(_time * 1.5 + ry_f * 0.3),
			0.25 + 0.2 * river_t,
			0.85
		)
		draw_line(Vector2(0, river_y + ry_f + river_wave), Vector2(1280, river_y + ry_f + river_wave), depth_col, 1.5)
	# Rapids / white water foam
	for ri in range(20):
		var rapid_x: float = fmod(float(ri) * 127.3 + _time * 60.0, 1400.0) - 60.0
		var rapid_y: float = river_y + 5.0 + fmod(float(ri) * 11.3, 22.0)
		var foam_alpha: float = 0.3 + 0.4 * sin(_time * 4.0 + float(ri) * 2.7)
		draw_circle(Vector2(rapid_x, rapid_y), 3.0 + sin(_time * 3.0 + float(ri)) * 1.5, Color(0.85, 0.9, 0.95, clampf(foam_alpha, 0.0, 1.0)))

	# --- Little John's stone bridge (centerpiece) ---
	var bridge_cx: float = 640.0
	var bridge_top: float = river_y - 10.0
	# Stone arch
	var arch_pts: PackedVector2Array = PackedVector2Array()
	for ai in range(21):
		var angle: float = PI * float(ai) / 20.0
		arch_pts.append(Vector2(bridge_cx + cos(angle) * 80.0, bridge_top + 30.0 - sin(angle) * 35.0))
	for ai2 in range(20, -1, -1):
		var angle2: float = PI * float(ai2) / 20.0
		arch_pts.append(Vector2(bridge_cx + cos(angle2) * 70.0, bridge_top + 30.0 - sin(angle2) * 28.0))
	draw_colored_polygon(arch_pts, Color(0.25, 0.22, 0.18))
	# Bridge deck
	draw_rect(Rect2(bridge_cx - 85.0, bridge_top - 8.0, 170.0, 14.0), Color(0.3, 0.27, 0.2))
	# Stone texture lines on bridge
	for sl in range(8):
		var slx: float = bridge_cx - 75.0 + float(sl) * 20.0
		draw_line(Vector2(slx, bridge_top - 8.0), Vector2(slx, bridge_top + 5.0), Color(0.2, 0.17, 0.12, 0.5), 1.0)
	# Railings
	for rail in range(9):
		var rx: float = bridge_cx - 80.0 + float(rail) * 20.0
		draw_line(Vector2(rx, bridge_top - 8.0), Vector2(rx, bridge_top - 22.0), Color(0.2, 0.17, 0.12), 2.5)
	draw_line(Vector2(bridge_cx - 80.0, bridge_top - 22.0), Vector2(bridge_cx + 80.0, bridge_top - 22.0), Color(0.22, 0.19, 0.14), 3.0)

	# --- Wanted posters on trees ---
	for wp in range(4):
		var poster_x: float = 90.0 + float(wp) * 310.0
		var poster_y: float = 260.0 + fmod(float(wp) * 37.0, 40.0)
		# Parchment
		draw_rect(Rect2(poster_x - 12.0, poster_y - 16.0, 24.0, 30.0), Color(0.85, 0.78, 0.6, 0.85))
		draw_rect(Rect2(poster_x - 11.0, poster_y - 15.0, 22.0, 28.0), Color(0.0, 0.0, 0.0, 1.0), false, 1.0)
		# "WANTED" text line
		draw_line(Vector2(poster_x - 7.0, poster_y - 10.0), Vector2(poster_x + 7.0, poster_y - 10.0), Color(0.15, 0.05, 0.02), 1.5)
		# Face circle
		draw_circle(Vector2(poster_x, poster_y + 2.0), 5.0, Color(0.7, 0.6, 0.45, 0.6))
		# Nail
		draw_circle(Vector2(poster_x, poster_y - 16.0), 1.5, Color(0.4, 0.4, 0.4))

	# --- Decorations loop ---
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
		elif dtype == "campfire":
			var fi: float = 0.7 + 0.3 * sin(_time * 5.0 + dextra * 10.0)
			draw_circle(dpos, dsize * 3.0, Color(0.4, 0.15, 0.02, 0.08 * fi))
			draw_circle(dpos, dsize * 2.0, Color(0.5, 0.2, 0.03, 0.12 * fi))
			for fs in range(8):
				draw_circle(dpos + Vector2(cos(float(fs) * TAU / 8.0) * dsize * 0.7, sin(float(fs) * TAU / 8.0) * dsize * 0.35), 3.0, Color(0.2, 0.18, 0.15))
			for fl2 in range(6):
				var flame_x: float = dpos.x + sin(float(fl2) * 1.7 + _time * 4.0) * dsize * 0.3
				var flame_h: float = dsize * (0.6 + 0.4 * sin(_time * 6.0 + float(fl2) * 2.0)) * fi
				var fc: Color = Color(0.95, 0.85, 0.2, 0.9) if fl2 < 2 else (Color(0.95, 0.5, 0.05, 0.85) if fl2 < 4 else Color(0.8, 0.2, 0.02, 0.7))
				draw_line(Vector2(flame_x, dpos.y + dsize * 0.1), Vector2(flame_x + sin(_time * 3.0 + float(fl2)) * 3.0, dpos.y - flame_h), fc, 3.5 - float(fl2) * 0.3)

	# --- Path rendering: dark forest dirt trail ---
	if enemy_path and enemy_path.curve:
		var curve: Curve2D = enemy_path.curve
		var path_len: float = curve.get_baked_length()
		var prev_pt: Vector2 = curve.sample_baked(0.0)
		for pi in range(1, 101):
			var pt: Vector2 = curve.sample_baked(float(pi) / 100.0 * path_len)
			# Main trail
			draw_line(prev_pt, pt, Color(0.12, 0.08, 0.04), 26.0)
			# Darker edges
			var perp: Vector2 = (pt - prev_pt).normalized().rotated(PI * 0.5)
			draw_line(prev_pt + perp * 12.0, pt + perp * 12.0, Color(0.06, 0.04, 0.02, 0.6), 4.0)
			draw_line(prev_pt - perp * 12.0, pt - perp * 12.0, Color(0.06, 0.04, 0.02, 0.6), 4.0)
			prev_pt = pt
		# Footprints / muddy patches
		for mi in range(15):
			var mud_offset: float = (float(mi) + 0.5) / 15.0
			var mud_pt: Vector2 = curve.sample_baked(mud_offset * path_len)
			var mud_side: float = -5.0 if mi % 2 == 0 else 5.0
			draw_circle(mud_pt + Vector2(mud_side, 0), 2.5, Color(0.08, 0.05, 0.02, 0.5))

	# --- Rolling fog (foreground effect) ---
	for fi2 in range(12):
		var fog_x: float = fmod(float(fi2) * 160.0 - _time * 18.0, 1500.0) - 100.0
		var fog_y: float = 350.0 + fmod(float(fi2) * 47.0, 200.0)
		var fog_pulse: float = 0.03 + 0.025 * sin(_time * 0.6 + float(fi2) * 1.3)
		var fog_rad: float = 60.0 + 20.0 * sin(_time * 0.4 + float(fi2) * 0.9)
		draw_circle(Vector2(fog_x, fog_y), fog_rad, Color(0.5, 0.55, 0.6, fog_pulse))
		draw_circle(Vector2(fog_x + 40.0, fog_y + 10.0), fog_rad * 0.7, Color(0.5, 0.55, 0.6, fog_pulse * 0.7))

	# --- Fireflies (animated foreground sparkles) ---
	for ff in range(18):
		var ff_x: float = fmod(float(ff) * 151.0 + sin(_time * 0.8 + float(ff) * 2.1) * 40.0, 1280.0)
		var ff_y: float = 200.0 + fmod(float(ff) * 67.0, 350.0) + sin(_time * 1.2 + float(ff) * 1.7) * 15.0
		var ff_alpha: float = clampf(0.5 + 0.5 * sin(_time * 3.0 + float(ff) * 4.1), 0.0, 1.0)
		draw_circle(Vector2(ff_x, ff_y), 2.0, Color(0.7, 0.9, 0.3, ff_alpha * 0.7))
		draw_circle(Vector2(ff_x, ff_y), 5.0, Color(0.7, 0.9, 0.3, ff_alpha * 0.15))


## Robin Hood Chapter 3: "Siege of Nottingham"
## Nottingham Castle walls, siege ladders, moat with drawbridge, castle towers with
## archer windows, burning arrows arcing across sky, dawn breaking golden, Robin's flag.

func _draw_robin_ch3(sky_color: Color, ground_color: Color) -> void:
	# --- Sky gradient: warm dawn breaking ---
	for sy in range(0, 50):
		var t: float = float(sy) / 50.0
		var dawn_col := Color(
			lerp(sky_color.r * 0.4, sky_color.r * 0.9, t),
			lerp(sky_color.g * 0.2, sky_color.g * 0.6, t),
			lerp(sky_color.b * 0.3, sky_color.b * 0.5, t)
		)
		draw_line(Vector2(0, float(sy)), Vector2(1280, float(sy)), dawn_col, 1.5)

	# --- Golden horizon glow ---
	for hg in range(20):
		var hg_t: float = float(hg) / 20.0
		var glow_alpha: float = 0.12 * (1.0 - hg_t) * (0.8 + 0.2 * sin(_time * 0.5))
		draw_line(Vector2(0, 50.0 - float(hg)), Vector2(1280, 50.0 - float(hg)), Color(1.0, 0.75, 0.2, glow_alpha), 1.5)

	# --- Fading stars at dawn ---
	for si in range(20):
		var sx: float = fmod(float(si) * 173.7 + 51.3, 1280.0)
		var star_y: float = fmod(float(si) * 97.1 + 5.0, 40.0) + 3.0
		var fade: float = clampf(0.3 + 0.2 * sin(_time * 1.0 + float(si) * 2.3), 0.0, 1.0)
		draw_circle(Vector2(sx, star_y), 1.0, Color(0.9, 0.85, 0.7, fade * 0.4))

	# --- Burning arrows arcing across sky (animated) ---
	for ba in range(6):
		var arrow_phase: float = fmod(_time * 0.7 + float(ba) * 1.8, 4.0)
		var arrow_t: float = arrow_phase / 4.0
		var arrow_start_x: float = -40.0 + float(ba) * 50.0
		var arrow_end_x: float = 400.0 + float(ba) * 150.0
		var arrow_x: float = lerp(arrow_start_x, arrow_end_x, arrow_t)
		var arrow_arc: float = -120.0 * sin(arrow_t * PI)
		var arrow_y: float = 45.0 + arrow_arc + float(ba) * 3.0
		if arrow_t > 0.02 and arrow_t < 0.98 and arrow_x > 0.0 and arrow_x < 1280.0:
			# Arrow body
			var arrow_dir: float = atan2(arrow_arc * 0.1, 5.0)
			var ax2: float = arrow_x - cos(arrow_dir) * 12.0
			var ay2: float = arrow_y - sin(arrow_dir) * 12.0
			draw_line(Vector2(ax2, ay2), Vector2(arrow_x, arrow_y), Color(0.3, 0.2, 0.05), 1.5)
			# Flame on tip
			var flame_fl: float = 0.7 + 0.3 * sin(_time * 8.0 + float(ba) * 3.0)
			draw_circle(Vector2(arrow_x, arrow_y), 4.0, Color(0.95, 0.6, 0.05, 0.6 * flame_fl))
			draw_circle(Vector2(arrow_x, arrow_y), 2.5, Color(1.0, 0.9, 0.3, 0.8 * flame_fl))
			# Smoke trail
			for st in range(4):
				var trail_x: float = ax2 - float(st) * 6.0
				var trail_y: float = ay2 + float(st) * 2.0
				draw_circle(Vector2(trail_x, trail_y), 2.0 + float(st) * 0.5, Color(0.3, 0.3, 0.3, 0.15 - float(st) * 0.03))

	# --- Sky to ground transition ---
	for sy2 in range(50, 180):
		var t2: float = float(sy2 - 50) / 130.0
		var mid_col := Color(
			lerp(sky_color.r * 0.9, 0.35, t2),
			lerp(sky_color.g * 0.6, 0.3, t2),
			lerp(sky_color.b * 0.5, 0.25, t2)
		)
		draw_line(Vector2(0, float(sy2)), Vector2(1280, float(sy2)), mid_col, 1.5)

	# --- Nottingham Castle (dominating background) ---
	var castle_base_y: float = 180.0
	# Main wall
	draw_rect(Rect2(200.0, castle_base_y, 880.0, 200.0), Color(0.3, 0.28, 0.24))
	# Battlements (crenellations)
	for cr in range(22):
		var cr_x: float = 200.0 + float(cr) * 40.0
		if cr % 2 == 0:
			draw_rect(Rect2(cr_x, castle_base_y - 20.0, 30.0, 20.0), Color(0.32, 0.3, 0.26))

	# Left tower
	draw_rect(Rect2(140.0, castle_base_y - 100.0, 80.0, 300.0), Color(0.28, 0.26, 0.22))
	# Left tower roof (conical shape)
	var ltower_pts: PackedVector2Array = PackedVector2Array([
		Vector2(180.0, castle_base_y - 140.0),
		Vector2(135.0, castle_base_y - 100.0),
		Vector2(225.0, castle_base_y - 100.0)
	])
	draw_colored_polygon(ltower_pts, Color(0.2, 0.08, 0.08))
	# Left tower archer windows
	for aw in range(3):
		var aw_y: float = castle_base_y - 70.0 + float(aw) * 55.0
		draw_rect(Rect2(172.0, aw_y, 6.0, 16.0), Color(0.05, 0.05, 0.08))
		draw_rect(Rect2(169.0, aw_y + 5.0, 12.0, 4.0), Color(0.05, 0.05, 0.08))
		# Arrow slit glow (interior light)
		var glow_f: float = 0.3 + 0.2 * sin(_time * 2.0 + float(aw) * 1.5)
		draw_circle(Vector2(175.0, aw_y + 8.0), 4.0, Color(0.8, 0.5, 0.1, glow_f * 0.3))

	# Right tower
	draw_rect(Rect2(1060.0, castle_base_y - 80.0, 80.0, 280.0), Color(0.28, 0.26, 0.22))
	var rtower_pts: PackedVector2Array = PackedVector2Array([
		Vector2(1100.0, castle_base_y - 120.0),
		Vector2(1055.0, castle_base_y - 80.0),
		Vector2(1145.0, castle_base_y - 80.0)
	])
	draw_colored_polygon(rtower_pts, Color(0.2, 0.08, 0.08))
	for aw2 in range(3):
		var aw2_y: float = castle_base_y - 50.0 + float(aw2) * 50.0
		draw_rect(Rect2(1092.0, aw2_y, 6.0, 16.0), Color(0.05, 0.05, 0.08))
		draw_rect(Rect2(1089.0, aw2_y + 5.0, 12.0, 4.0), Color(0.05, 0.05, 0.08))

	# Central keep (taller)
	draw_rect(Rect2(540.0, castle_base_y - 70.0, 200.0, 270.0), Color(0.33, 0.3, 0.27))
	# Keep battlements
	for kb in range(5):
		var kb_x: float = 540.0 + float(kb) * 40.0
		if kb % 2 == 0:
			draw_rect(Rect2(kb_x, castle_base_y - 88.0, 28.0, 18.0), Color(0.35, 0.32, 0.28))
	# Keep gate (large arched entrance)
	var gate_pts: PackedVector2Array = PackedVector2Array()
	for gi in range(21):
		var g_angle: float = PI * float(gi) / 20.0
		gate_pts.append(Vector2(640.0 + cos(g_angle) * 28.0, castle_base_y + 100.0 - sin(g_angle) * 35.0))
	gate_pts.append(Vector2(668.0, castle_base_y + 200.0))
	gate_pts.append(Vector2(612.0, castle_base_y + 200.0))
	draw_colored_polygon(gate_pts, Color(0.06, 0.04, 0.04))
	# Portcullis lines
	for pc in range(5):
		var pcx: float = 618.0 + float(pc) * 11.0
		draw_line(Vector2(pcx, castle_base_y + 68.0), Vector2(pcx, castle_base_y + 200.0), Color(0.2, 0.18, 0.15), 2.0)
	for pcr in range(6):
		var pcry: float = castle_base_y + 80.0 + float(pcr) * 20.0
		draw_line(Vector2(614.0, pcry), Vector2(666.0, pcry), Color(0.2, 0.18, 0.15), 1.5)

	# --- Robin's flag on left tower ---
	var flag_x: float = 180.0
	var flag_y: float = castle_base_y - 140.0
	# Pole
	draw_line(Vector2(flag_x, flag_y), Vector2(flag_x, flag_y - 40.0), Color(0.4, 0.35, 0.2), 2.0)
	# Flag waving
	var flag_wave: float = sin(_time * 3.0) * 5.0
	var flag_pts: PackedVector2Array = PackedVector2Array([
		Vector2(flag_x, flag_y - 40.0),
		Vector2(flag_x + 28.0, flag_y - 37.0 + flag_wave),
		Vector2(flag_x + 25.0, flag_y - 25.0 + flag_wave * 0.6),
		Vector2(flag_x, flag_y - 22.0)
	])
	draw_colored_polygon(flag_pts, Color(0.15, 0.5, 0.15))
	# Arrow emblem on flag
	draw_line(Vector2(flag_x + 8.0, flag_y - 33.0 + flag_wave * 0.4), Vector2(flag_x + 20.0, flag_y - 30.0 + flag_wave * 0.7), Color(0.9, 0.85, 0.3), 1.5)

	# --- Moat (water around castle base) ---
	var moat_y: float = castle_base_y + 200.0
	for my in range(25):
		var my_f: float = float(my)
		var moat_wave: float = sin(my_f * 0.6 + _time * 1.5) * 2.0
		var moat_col := Color(
			0.06 + 0.04 * sin(_time * 0.8 + my_f * 0.2),
			0.15 + 0.08 * (my_f / 25.0),
			0.3 + 0.1 * (my_f / 25.0),
			0.9
		)
		draw_line(Vector2(0, moat_y + my_f + moat_wave), Vector2(1280, moat_y + my_f + moat_wave), moat_col, 1.5)
	# Water reflections
	for wr in range(10):
		var wr_x: float = fmod(float(wr) * 137.0 + _time * 12.0, 1280.0)
		var wr_y: float = moat_y + 5.0 + fmod(float(wr) * 7.3, 18.0)
		var wr_alpha: float = 0.15 + 0.1 * sin(_time * 2.0 + float(wr) * 1.9)
		draw_line(Vector2(wr_x - 8.0, wr_y), Vector2(wr_x + 8.0, wr_y), Color(0.6, 0.7, 0.8, wr_alpha), 1.0)

	# --- Drawbridge ---
	var db_x: float = 640.0
	var db_angle: float = 0.1 * sin(_time * 0.3)
	draw_rect(Rect2(db_x - 30.0, moat_y - 4.0, 60.0, 8.0), Color(0.25, 0.15, 0.06))
	# Planks
	for pl in range(6):
		var plx: float = db_x - 28.0 + float(pl) * 10.0
		draw_line(Vector2(plx, moat_y - 4.0), Vector2(plx, moat_y + 4.0), Color(0.18, 0.1, 0.04, 0.6), 1.0)
	# Chains
	draw_line(Vector2(db_x - 25.0, moat_y - 4.0), Vector2(db_x - 20.0, castle_base_y + 195.0), Color(0.35, 0.33, 0.3), 2.0)
	draw_line(Vector2(db_x + 25.0, moat_y - 4.0), Vector2(db_x + 20.0, castle_base_y + 195.0), Color(0.35, 0.33, 0.3), 2.0)

	# --- Siege ladders leaning against walls ---
	for li in range(3):
		var ladder_x: float = 280.0 + float(li) * 260.0
		var ladder_bot: float = moat_y - 2.0
		var ladder_top: float = castle_base_y + 10.0
		var ladder_lean: float = 20.0 + sin(_time * 0.4 + float(li) * 2.0) * 3.0
		# Side rails
		draw_line(Vector2(ladder_x - 6.0, ladder_bot), Vector2(ladder_x - 6.0 + ladder_lean, ladder_top), Color(0.3, 0.2, 0.08), 3.0)
		draw_line(Vector2(ladder_x + 6.0, ladder_bot), Vector2(ladder_x + 6.0 + ladder_lean, ladder_top), Color(0.3, 0.2, 0.08), 3.0)
		# Rungs
		var rungs: int = 8
		for ru in range(rungs):
			var rung_t: float = float(ru + 1) / float(rungs + 1)
			var rx1: float = lerp(ladder_x - 6.0, ladder_x - 6.0 + ladder_lean, rung_t)
			var rx2: float = lerp(ladder_x + 6.0, ladder_x + 6.0 + ladder_lean, rung_t)
			var rung_y: float = lerp(ladder_bot, ladder_top, rung_t)
			draw_line(Vector2(rx1, rung_y), Vector2(rx2, rung_y), Color(0.28, 0.18, 0.06), 2.0)

	# --- Ground layers: battlefield/earth ---
	for gy in range(int(moat_y) + 25, 628):
		var gt: float = float(gy - int(moat_y) - 25) / float(628 - int(moat_y) - 25)
		var ground_col := Color(
			lerp(0.2, ground_color.r * 0.7, gt),
			lerp(0.18, ground_color.g * 0.6, gt),
			lerp(0.12, ground_color.b * 0.4, gt)
		)
		draw_line(Vector2(0, float(gy)), Vector2(1280, float(gy)), ground_col, 1.5)

	# --- Stone wall texture on castle ---
	for sr in range(12):
		for sc in range(24):
			var stone_x: float = 200.0 + float(sc) * 37.0 + fmod(float(sr) * 17.0, 18.0)
			var stone_y: float = castle_base_y + float(sr) * 16.5
			if stone_x < 1080.0 and stone_y < castle_base_y + 195.0:
				draw_rect(Rect2(stone_x, stone_y, 34.0, 14.0), Color(0.25, 0.23, 0.19, 0.25), false, 0.5)

	# --- Decorations loop ---
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
		elif dtype == "campfire":
			var fi: float = 0.7 + 0.3 * sin(_time * 5.0 + dextra * 10.0)
			draw_circle(dpos, dsize * 3.0, Color(0.4, 0.15, 0.02, 0.08 * fi))
			draw_circle(dpos, dsize * 2.0, Color(0.5, 0.2, 0.03, 0.12 * fi))
			for fs in range(8):
				draw_circle(dpos + Vector2(cos(float(fs) * TAU / 8.0) * dsize * 0.7, sin(float(fs) * TAU / 8.0) * dsize * 0.35), 3.0, Color(0.2, 0.18, 0.15))
			for fl2 in range(6):
				var flame_x: float = dpos.x + sin(float(fl2) * 1.7 + _time * 4.0) * dsize * 0.3
				var flame_h: float = dsize * (0.6 + 0.4 * sin(_time * 6.0 + float(fl2) * 2.0)) * fi
				var fc: Color = Color(0.95, 0.85, 0.2, 0.9) if fl2 < 2 else (Color(0.95, 0.5, 0.05, 0.85) if fl2 < 4 else Color(0.8, 0.2, 0.02, 0.7))
				draw_line(Vector2(flame_x, dpos.y + dsize * 0.1), Vector2(flame_x + sin(_time * 3.0 + float(fl2)) * 3.0, dpos.y - flame_h), fc, 3.5 - float(fl2) * 0.3)

	# --- Path rendering: castle cobblestone (gray) ---
	if enemy_path and enemy_path.curve:
		var curve: Curve2D = enemy_path.curve
		var path_len: float = curve.get_baked_length()
		var prev_pt: Vector2 = curve.sample_baked(0.0)
		for pi in range(1, 101):
			var pt: Vector2 = curve.sample_baked(float(pi) / 100.0 * path_len)
			# Main cobblestone path
			draw_line(prev_pt, pt, Color(0.35, 0.33, 0.3), 28.0)
			# Lighter center
			draw_line(prev_pt, pt, Color(0.42, 0.4, 0.36), 18.0)
			# Edge stones
			var perp: Vector2 = (pt - prev_pt).normalized().rotated(PI * 0.5)
			draw_line(prev_pt + perp * 13.0, pt + perp * 13.0, Color(0.28, 0.26, 0.22, 0.7), 3.0)
			draw_line(prev_pt - perp * 13.0, pt - perp * 13.0, Color(0.28, 0.26, 0.22, 0.7), 3.0)
			prev_pt = pt
		# Cobblestone texture marks
		for ci in range(25):
			var cb_offset: float = (float(ci) + 0.3) / 25.0
			var cb_pt: Vector2 = curve.sample_baked(cb_offset * path_len)
			for cj in range(3):
				var cx_off: float = -7.0 + float(cj) * 7.0
				var cy_off: float = sin(float(ci) * 2.3 + float(cj) * 1.1) * 3.0
				draw_rect(Rect2(cb_pt.x + cx_off - 3.0, cb_pt.y + cy_off - 2.0, 6.0, 4.0), Color(0.3, 0.28, 0.25, 0.35), false, 0.8)

	# --- Smoke rising from castle (foreground effect) ---
	for sm in range(8):
		var smoke_base_x: float = 500.0 + float(sm) * 40.0
		var smoke_phase: float = fmod(_time * 0.5 + float(sm) * 1.2, 6.0)
		var smoke_y: float = castle_base_y - 20.0 - smoke_phase * 25.0
		var smoke_alpha: float = clampf(0.15 * (1.0 - smoke_phase / 6.0), 0.0, 0.15)
		var smoke_rad: float = 8.0 + smoke_phase * 6.0
		var smoke_drift: float = sin(_time * 0.8 + float(sm) * 0.7) * smoke_phase * 4.0
		draw_circle(Vector2(smoke_base_x + smoke_drift, smoke_y), smoke_rad, Color(0.3, 0.3, 0.3, smoke_alpha))

	# --- Dawn light rays (foreground atmospheric) ---
	for dr in range(5):
		var ray_x: float = 100.0 + float(dr) * 280.0
		var ray_alpha: float = 0.03 + 0.02 * sin(_time * 0.4 + float(dr) * 1.5)
		var ray_pts: PackedVector2Array = PackedVector2Array([
			Vector2(ray_x, 0.0),
			Vector2(ray_x - 40.0, 628.0),
			Vector2(ray_x + 60.0, 628.0),
			Vector2(ray_x + 15.0, 0.0)
		])
		draw_colored_polygon(ray_pts, Color(1.0, 0.85, 0.4, ray_alpha))

	# --- Embers / sparks floating up (animated) ---
	for em in range(15):
		var ember_phase: float = fmod(_time * 1.2 + float(em) * 0.9, 3.5)
		var ember_x: float = fmod(float(em) * 107.0 + sin(_time * 0.5 + float(em) * 1.3) * 30.0, 1280.0)
		var ember_y: float = 500.0 - ember_phase * 120.0 + sin(_time * 2.0 + float(em) * 2.7) * 10.0
		var ember_alpha: float = clampf(0.8 * (1.0 - ember_phase / 3.5), 0.0, 0.8)
		if ember_y > 50.0:
			draw_circle(Vector2(ember_x, ember_y), 1.5, Color(1.0, 0.6, 0.1, ember_alpha))
			draw_circle(Vector2(ember_x, ember_y), 3.5, Color(1.0, 0.5, 0.05, ember_alpha * 0.2))

func _draw_alice_ch2(sky_color: Color, ground_color: Color) -> void:
	# === SKY GRADIENT â€” deep purple twilight ===
	var sky_steps := 24
	for i in range(sky_steps):
		var t := float(i) / float(sky_steps)
		var y_start := 50.0 + t * 290.0
		var band_h := 290.0 / float(sky_steps) + 1.0
		var band_col := sky_color.lerp(Color(0.15, 0.08, 0.25), t)
		# Subtle purple haze pulsing
		var haze := clampf(sin(_time * 0.3 + t * 2.0), 0.0, 1.0) * 0.06
		band_col = band_col.lerp(Color(0.5, 0.2, 0.6), haze)
		draw_rect(Rect2(0, y_start, 1280, band_h), band_col)

	# === ATMOSPHERE â€” swirling tea steam and madness particles ===
	for i in range(18):
		var sx := fmod(float(i) * 173.7 + _time * 8.0, 1280.0)
		var sy := 80.0 + sin(_time * 0.6 + float(i) * 0.9) * 60.0 + float(i) * 14.0
		var steam_alpha := clampf(sin(_time * 0.7 + float(i) * 1.3), 0.0, 1.0) * 0.12
		draw_circle(Vector2(sx, sy), 6.0 + sin(_time + float(i)) * 3.0, Color(0.8, 0.7, 0.9, steam_alpha))

	# Floating question marks / madness sparkles
	for i in range(10):
		var qx := fmod(float(i) * 127.3, 1280.0)
		var qy := 100.0 + sin(_time * 0.4 + float(i) * 2.1) * 40.0 + float(i) * 20.0
		var q_alpha := clampf(sin(_time * 1.1 + float(i) * 0.7), 0.0, 1.0) * 0.15
		draw_circle(Vector2(qx, qy), 2.0, Color(1.0, 0.9, 0.3, q_alpha))

	# === CHESHIRE CAT GRIN â€” fading in and out ===
	var cat_x := 200.0 + sin(_time * 0.15) * 30.0
	var cat_y := 140.0 + cos(_time * 0.2) * 15.0
	var grin_alpha := clampf(sin(_time * 0.5), 0.0, 1.0) * 0.7
	if grin_alpha > 0.05:
		# Wide crescent grin
		var grin_w := 60.0
		var grin_pts := 16
		for i in range(grin_pts - 1):
			var t1 := float(i) / float(grin_pts - 1)
			var t2 := float(i + 1) / float(grin_pts - 1)
			var x1 := cat_x - grin_w * 0.5 + t1 * grin_w
			var x2 := cat_x - grin_w * 0.5 + t2 * grin_w
			var curve1 := sin(t1 * PI) * 12.0
			var curve2 := sin(t2 * PI) * 12.0
			draw_line(Vector2(x1, cat_y + curve1), Vector2(x2, cat_y + curve2), Color(0.9, 0.5, 0.9, grin_alpha), 2.5)
		# Teeth lines
		for i in range(6):
			var tx := cat_x - 20.0 + float(i) * 8.0
			var tt := (tx - (cat_x - grin_w * 0.5)) / grin_w
			var ty := cat_y + sin(tt * PI) * 12.0
			draw_line(Vector2(tx, ty - 2.0), Vector2(tx, ty + 3.0), Color(1.0, 1.0, 1.0, grin_alpha * 0.6), 1.0)
		# Eyes above grin (floating, glowing)
		var eye_alpha := grin_alpha * 0.8
		draw_circle(Vector2(cat_x - 18.0, cat_y - 20.0), 5.0, Color(0.6, 0.9, 0.2, eye_alpha))
		draw_circle(Vector2(cat_x + 18.0, cat_y - 20.0), 5.0, Color(0.6, 0.9, 0.2, eye_alpha))
		draw_circle(Vector2(cat_x - 18.0, cat_y - 20.0), 2.0, Color(0.1, 0.05, 0.2, eye_alpha))
		draw_circle(Vector2(cat_x + 18.0, cat_y - 20.0), 2.0, Color(0.1, 0.05, 0.2, eye_alpha))

	# === LANDMARKS ===
	# --- Massive tea table (center) ---
	var table_y := 360.0
	var table_x := 640.0
	# Table legs
	draw_rect(Rect2(table_x - 200.0, table_y, 16.0, 80.0), Color(0.35, 0.2, 0.1, 0.7))
	draw_rect(Rect2(table_x + 184.0, table_y, 16.0, 80.0), Color(0.35, 0.2, 0.1, 0.7))
	# Table top
	draw_rect(Rect2(table_x - 220.0, table_y - 8.0, 440.0, 16.0), Color(0.45, 0.28, 0.15, 0.75))
	# Table cloth drape
	for i in range(10):
		var drape_x := table_x - 210.0 + float(i) * 46.0
		var drape_sag := sin(float(i) * 0.8 + 1.0) * 8.0
		draw_line(Vector2(drape_x, table_y - 6.0), Vector2(drape_x + 23.0, table_y + drape_sag), Color(0.85, 0.8, 0.95, 0.35), 1.5)

	# --- Oversized teapot (on table, center) ---
	var pot_x := table_x
	var pot_y := table_y - 50.0
	# Body
	draw_circle(Vector2(pot_x, pot_y), 30.0, Color(0.6, 0.45, 0.7, 0.55))
	draw_circle(Vector2(pot_x, pot_y), 26.0, Color(0.7, 0.55, 0.8, 0.45))
	# Lid
	draw_rect(Rect2(pot_x - 18.0, pot_y - 34.0, 36.0, 6.0), Color(0.6, 0.45, 0.7, 0.6))
	draw_circle(Vector2(pot_x, pot_y - 38.0), 5.0, Color(0.65, 0.5, 0.75, 0.6))
	# Spout
	draw_line(Vector2(pot_x + 28.0, pot_y - 10.0), Vector2(pot_x + 55.0, pot_y - 30.0), Color(0.6, 0.45, 0.7, 0.5), 4.0)
	# Steam from spout
	for i in range(5):
		var st_y := pot_y - 35.0 - float(i) * 10.0
		var st_x := pot_x + 55.0 + sin(_time * 1.2 + float(i) * 0.8) * 8.0
		var st_a := 0.2 - float(i) * 0.035
		draw_circle(Vector2(st_x, st_y), 4.0 + float(i) * 1.5, Color(0.9, 0.85, 1.0, clampf(st_a, 0.0, 1.0)))
	# Handle
	draw_arc(Vector2(pot_x - 30.0, pot_y - 5.0), 14.0, PI * 0.5, PI * 1.5, 10, Color(0.6, 0.45, 0.7, 0.5), 3.0)

	# --- Oversized teacups on table ---
	for i in range(4):
		var cx := table_x - 150.0 + float(i) * 100.0
		if absf(cx - pot_x) < 40.0:
			cx += 60.0
		var cy := table_y - 20.0
		var cup_col := Color(0.75, 0.6 + float(i) * 0.05, 0.85, 0.5)
		draw_rect(Rect2(cx - 12.0, cy - 16.0, 24.0, 18.0), cup_col)
		draw_arc(Vector2(cx + 14.0, cy - 8.0), 7.0, -PI * 0.5, PI * 0.5, 8, cup_col, 2.0)
		# Liquid inside
		draw_rect(Rect2(cx - 10.0, cy - 12.0, 20.0, 4.0), Color(0.6, 0.4, 0.15, 0.35))

	# --- Broken pocket watches ---
	for i in range(5):
		var wx := 80.0 + float(i) * 260.0
		var wy := 300.0 + sin(float(i) * 1.7) * 40.0
		var watch_r := 14.0
		# Watch face
		draw_circle(Vector2(wx, wy), watch_r, Color(0.85, 0.78, 0.55, 0.35))
		draw_arc(Vector2(wx, wy), watch_r, 0.0, TAU, 12, Color(0.6, 0.5, 0.3, 0.4), 1.5)
		# Hands (spinning erratically)
		var hand_angle := _time * (1.5 + float(i) * 0.7)
		var hx := cos(hand_angle) * watch_r * 0.7
		var hy := sin(hand_angle) * watch_r * 0.7
		draw_line(Vector2(wx, wy), Vector2(wx + hx, wy + hy), Color(0.2, 0.15, 0.1, 0.5), 1.5)
		# Crack line
		draw_line(Vector2(wx - 4.0, wy - 6.0), Vector2(wx + 6.0, wy + 8.0), Color(0.3, 0.25, 0.2, 0.3), 1.0)

	# --- Croquet mallets (flamingo-shaped) ---
	for i in range(3):
		var mx := 950.0 + float(i) * 100.0
		var my := 380.0 + float(i) * 30.0
		var lean := sin(_time * 0.6 + float(i)) * 0.15
		# Shaft
		var shaft_top := Vector2(mx + sin(lean) * 50.0, my - 50.0)
		draw_line(Vector2(mx, my), shaft_top, Color(0.95, 0.55, 0.65, 0.4), 3.0)
		# Flamingo head
		draw_circle(shaft_top, 6.0, Color(0.95, 0.6, 0.7, 0.45))
		draw_circle(shaft_top + Vector2(4.0, -2.0), 2.0, Color(0.2, 0.15, 0.1, 0.4))
		# Beak
		draw_line(shaft_top + Vector2(5.0, 0.0), shaft_top + Vector2(11.0, 1.0), Color(0.9, 0.7, 0.2, 0.4), 1.5)

	# === GROUND â€” chess board tiles ===
	var ground_y := 440.0
	draw_rect(Rect2(0, ground_y, 1280, 628.0 - ground_y), ground_color)
	var tile_size := 40.0
	var cols := int(1280.0 / tile_size) + 1
	var rows := int((628.0 - ground_y) / tile_size) + 1
	for row in range(rows):
		for col in range(cols):
			var is_dark := (row + col) % 2 == 0
			var tile_col: Color
			if is_dark:
				tile_col = Color(0.2, 0.12, 0.25, 0.25)
			else:
				tile_col = Color(0.85, 0.78, 0.9, 0.15)
			draw_rect(Rect2(float(col) * tile_size, ground_y + float(row) * tile_size, tile_size, tile_size), tile_col)

	# === DECORATIONS ===
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
				var tp2 = dec["pos"]
				draw_rect(Rect2(tp2.x - 4, tp2.y - 5, 8, 6), Color(0.8, 0.75, 0.6, 0.4))
				draw_arc(Vector2(tp2.x + 5, tp2.y - 2), 3, -PI * 0.5, PI * 0.5, 6, Color(0.8, 0.75, 0.6, 0.35), 1.0)

	# === PATH â€” mosaic tiles (purple/pink) ===
	if enemy_path:
		var path_curve: Curve2D = enemy_path.curve
		if path_curve and path_curve.point_count > 1:
			var path_len := path_curve.get_baked_length()
			var tile_step := 18.0
			var num_tiles := int(path_len / tile_step)
			for i in range(num_tiles):
				var offset_dist := float(i) * tile_step
				var pt := path_curve.sample_baked(offset_dist)
				var is_purple := (i % 2 == 0)
				var mosaic_col: Color
				if is_purple:
					mosaic_col = Color(0.55, 0.2, 0.65, 0.5)
				else:
					mosaic_col = Color(0.85, 0.45, 0.65, 0.45)
				# Slight offset for mosaic irregularity
				var jitter_x := sin(float(i) * 2.3) * 2.0
				var jitter_y := cos(float(i) * 1.7) * 2.0
				draw_rect(Rect2(pt.x - 7.0 + jitter_x, pt.y - 7.0 + jitter_y, 14.0, 14.0), mosaic_col)
				# Grout line
				draw_rect(Rect2(pt.x - 8.0 + jitter_x, pt.y - 8.0 + jitter_y, 16.0, 16.0), Color(0.3, 0.2, 0.35, 0.15))

			# Path edge glow
			for i in range(0, num_tiles, 3):
				var offset_dist := float(i) * tile_step
				var pt := path_curve.sample_baked(offset_dist)
				var glow_a := clampf(sin(_time * 0.8 + float(i) * 0.3), 0.0, 1.0) * 0.1
				draw_circle(pt, 12.0, Color(0.7, 0.3, 0.8, glow_a))

	# === FOREGROUND ===
	# Floating teaspoons drifting across bottom
	for i in range(6):
		var sp_x := fmod(float(i) * 213.0 + _time * 12.0, 1400.0) - 60.0
		var sp_y := 560.0 + sin(_time * 0.5 + float(i) * 1.1) * 20.0
		var sp_alpha := 0.2 + sin(_time * 0.8 + float(i)) * 0.08
		# Spoon handle
		draw_line(Vector2(sp_x, sp_y), Vector2(sp_x + 18.0, sp_y - 2.0), Color(0.75, 0.7, 0.5, clampf(sp_alpha, 0.0, 1.0)), 1.5)
		# Spoon bowl
		draw_circle(Vector2(sp_x - 4.0, sp_y + 1.0), 4.0, Color(0.75, 0.7, 0.5, clampf(sp_alpha, 0.0, 1.0)))

	# Sugar cubes tumbling
	for i in range(4):
		var sc_x := 100.0 + float(i) * 300.0
		var sc_y := 590.0 + sin(_time * 0.9 + float(i) * 2.0) * 8.0
		var rot := _time * 0.4 + float(i) * 1.5
		var sz := 6.0
		draw_rect(Rect2(sc_x - sz * 0.5, sc_y - sz * 0.5, sz, sz), Color(0.95, 0.93, 0.88, 0.2 + sin(rot) * 0.05))

	# Bottom haze â€” purple mist
	for i in range(8):
		var hz_t := float(i) / 8.0
		var hz_y := 600.0 + hz_t * 28.0
		draw_rect(Rect2(0, hz_y, 1280, 4.0), Color(0.25, 0.12, 0.35, 0.08 + hz_t * 0.06))


func _draw_alice_ch3(sky_color: Color, ground_color: Color) -> void:
	# === SKY GRADIENT â€” dark crimson royal sky ===
	var sky_steps := 24
	for i in range(sky_steps):
		var t := float(i) / float(sky_steps)
		var y_start := 50.0 + t * 290.0
		var band_h := 290.0 / float(sky_steps) + 1.0
		var band_col := sky_color.lerp(Color(0.3, 0.05, 0.08), t)
		# Pulsing red atmosphere
		var throb := clampf(sin(_time * 0.4 + t * 1.5), 0.0, 1.0) * 0.05
		band_col = band_col.lerp(Color(0.6, 0.05, 0.1), throb)
		draw_rect(Rect2(0, y_start, 1280, band_h), band_col)

	# === ATMOSPHERE â€” drifting red particles, paint droplets ===
	for i in range(14):
		var px := fmod(float(i) * 197.3 + _time * 5.0, 1280.0)
		var py := 80.0 + sin(_time * 0.5 + float(i) * 1.4) * 50.0 + float(i) * 15.0
		var p_alpha := clampf(sin(_time * 0.9 + float(i) * 0.8), 0.0, 1.0) * 0.12
		draw_circle(Vector2(px, py), 3.0 + sin(_time * 0.6 + float(i)) * 1.5, Color(0.8, 0.1, 0.15, p_alpha))

	# Falling paint droplets (red paint dripping from sky)
	for i in range(8):
		var dx := fmod(float(i) * 163.7, 1280.0)
		var fall_cycle := fmod(_time * 0.3 + float(i) * 1.2, 4.0)
		var dy := 60.0 + fall_cycle * 100.0
		var drop_alpha := clampf(0.25 - fall_cycle * 0.05, 0.0, 0.25)
		draw_circle(Vector2(dx, dy), 2.5, Color(0.85, 0.08, 0.12, drop_alpha))
		# Paint trail
		if fall_cycle > 0.5:
			draw_line(Vector2(dx, dy - 15.0), Vector2(dx, dy), Color(0.85, 0.08, 0.12, drop_alpha * 0.5), 1.0)

	# === LANDMARKS ===
	# --- Red palace walls (background, spanning width) ---
	var palace_y := 160.0
	var palace_h := 220.0
	# Main wall
	draw_rect(Rect2(80.0, palace_y, 1120.0, palace_h), Color(0.5, 0.08, 0.1, 0.3))
	# Crenellations along top
	for i in range(28):
		var cx := 80.0 + float(i) * 40.0
		if cx > 1200.0:
			break
		draw_rect(Rect2(cx, palace_y - 18.0, 28.0, 18.0), Color(0.5, 0.08, 0.1, 0.3))

	# Heart-shaped windows
	for i in range(6):
		var wx := 180.0 + float(i) * 170.0
		var wy := palace_y + 60.0 + sin(float(i) * 1.3) * 20.0
		# Heart shape from two circles + triangle
		var hr := 10.0
		draw_circle(Vector2(wx - hr * 0.55, wy - hr * 0.3), hr, Color(0.15, 0.02, 0.04, 0.5))
		draw_circle(Vector2(wx + hr * 0.55, wy - hr * 0.3), hr, Color(0.15, 0.02, 0.04, 0.5))
		# Bottom of heart (triangle approx with rect)
		draw_rect(Rect2(wx - hr, wy - hr * 0.3, hr * 2.0, hr * 1.2), Color(0.15, 0.02, 0.04, 0.5))
		# Inner glow
		var win_glow := clampf(sin(_time * 0.7 + float(i) * 1.1), 0.0, 1.0) * 0.15
		draw_circle(Vector2(wx, wy), hr * 0.6, Color(1.0, 0.8, 0.3, win_glow))

	# --- Palace towers at edges ---
	for side in range(2):
		var tx := 60.0 if side == 0 else 1180.0
		draw_rect(Rect2(tx, palace_y - 60.0, 50.0, palace_h + 60.0), Color(0.55, 0.1, 0.12, 0.35))
		# Tower top (pointed)
		draw_line(Vector2(tx, palace_y - 60.0), Vector2(tx + 25.0, palace_y - 100.0), Color(0.55, 0.1, 0.12, 0.35), 3.0)
		draw_line(Vector2(tx + 50.0, palace_y - 60.0), Vector2(tx + 25.0, palace_y - 100.0), Color(0.55, 0.1, 0.12, 0.35), 3.0)
		# Heart flag
		draw_line(Vector2(tx + 25.0, palace_y - 100.0), Vector2(tx + 25.0, palace_y - 125.0), Color(0.3, 0.05, 0.08, 0.4), 1.5)
		var flag_sway := sin(_time * 1.5 + float(side) * PI) * 4.0
		draw_circle(Vector2(tx + 25.0 + flag_sway, palace_y - 130.0), 6.0, Color(0.85, 0.1, 0.15, 0.4))

	# --- Queen's throne silhouette (center background) ---
	var throne_x := 640.0
	var throne_y := 200.0
	# Throne back (tall arch)
	draw_rect(Rect2(throne_x - 25.0, throne_y - 80.0, 50.0, 100.0), Color(0.2, 0.02, 0.05, 0.35))
	# Throne ornate top (crown-like)
	for i in range(5):
		var spike_x := throne_x - 20.0 + float(i) * 10.0
		var spike_h := 15.0 if (i % 2 == 0) else 10.0
		draw_rect(Rect2(spike_x - 2.0, throne_y - 80.0 - spike_h, 4.0, spike_h), Color(0.2, 0.02, 0.05, 0.35))
	# Heart on throne
	draw_circle(Vector2(throne_x, throne_y - 50.0), 8.0, Color(0.7, 0.05, 0.1, 0.3))
	# Seat
	draw_rect(Rect2(throne_x - 30.0, throne_y + 15.0, 60.0, 12.0), Color(0.2, 0.02, 0.05, 0.35))
	# Armrests
	draw_rect(Rect2(throne_x - 35.0, throne_y - 10.0, 8.0, 30.0), Color(0.2, 0.02, 0.05, 0.3))
	draw_rect(Rect2(throne_x + 27.0, throne_y - 10.0, 8.0, 30.0), Color(0.2, 0.02, 0.05, 0.3))

	# --- "OFF WITH THEIR HEADS" banner ---
	var banner_y := 130.0
	var banner_sway := sin(_time * 0.6) * 5.0
	draw_rect(Rect2(440.0, banner_y + banner_sway, 400.0, 28.0), Color(0.8, 0.08, 0.12, 0.35))
	# Banner end notches
	draw_line(Vector2(440.0, banner_y + banner_sway), Vector2(430.0, banner_y + banner_sway + 14.0), Color(0.8, 0.08, 0.12, 0.35), 3.0)
	draw_line(Vector2(840.0, banner_y + banner_sway), Vector2(850.0, banner_y + banner_sway + 14.0), Color(0.8, 0.08, 0.12, 0.35), 3.0)
	# Text approximation with small rectangles (block letters)
	var text_blocks := [0.0, 20.0, 40.0, 60.0, 100.0, 120.0, 140.0, 160.0, 200.0, 220.0, 240.0, 260.0, 280.0, 320.0, 340.0, 360.0, 380.0]
	for bx in text_blocks:
		draw_rect(Rect2(450.0 + bx, banner_y + 6.0 + banner_sway, 14.0, 4.0), Color(0.15, 0.02, 0.04, 0.5))
		draw_rect(Rect2(450.0 + bx, banner_y + 14.0 + banner_sway, 14.0, 4.0), Color(0.15, 0.02, 0.04, 0.5))

	# --- Card soldier formations (flanking path) ---
	for i in range(8):
		var sx := 100.0 + float(i) * 150.0
		var sy := 400.0 + sin(float(i) * 0.9) * 20.0
		var bob := sin(_time * 1.0 + float(i) * 0.7) * 2.0
		# Card body
		var is_heart := (i % 2 == 0)
		var card_col := Color(0.85, 0.1, 0.15, 0.35) if is_heart else Color(0.15, 0.15, 0.15, 0.3)
		draw_rect(Rect2(sx - 8.0, sy - 22.0 + bob, 16.0, 28.0), card_col)
		# Suit symbol
		var sym_col := Color(0.95, 0.2, 0.25, 0.45) if is_heart else Color(0.3, 0.3, 0.3, 0.4)
		draw_circle(Vector2(sx, sy - 12.0 + bob), 3.0, sym_col)
		# Spear
		draw_line(Vector2(sx + 10.0, sy - 20.0 + bob), Vector2(sx + 10.0, sy - 45.0 + bob), Color(0.5, 0.45, 0.3, 0.3), 1.5)
		# Spear tip
		draw_line(Vector2(sx + 10.0, sy - 45.0 + bob), Vector2(sx + 7.0, sy - 40.0 + bob), Color(0.6, 0.55, 0.5, 0.35), 1.5)
		draw_line(Vector2(sx + 10.0, sy - 45.0 + bob), Vector2(sx + 13.0, sy - 40.0 + bob), Color(0.6, 0.55, 0.5, 0.35), 1.5)

	# --- Rose garden â€” white roses being painted red ---
	for i in range(10):
		var rx := 60.0 + float(i) * 125.0
		var ry := 430.0 + sin(float(i) * 2.1) * 15.0
		# Stem
		var stem_sway := sin(_time * 0.9 + float(i) * 0.6) * 1.5
		draw_line(Vector2(rx + stem_sway, ry), Vector2(rx, ry + 25.0), Color(0.15, 0.35, 0.1, 0.4), 1.5)
		# Rose bloom â€” transition from white to red based on paint progress
		var paint_progress := clampf(sin(_time * 0.2 + float(i) * 0.8) * 0.5 + 0.5, 0.0, 1.0)
		var rose_white := Color(0.95, 0.92, 0.88, 0.5)
		var rose_red := Color(0.85, 0.1, 0.15, 0.55)
		var rose_col := rose_white.lerp(rose_red, paint_progress)
		draw_circle(Vector2(rx + stem_sway, ry), 6.0, rose_col)
		# Paint drip below partially-painted roses
		if paint_progress > 0.3:
			var drip_len := paint_progress * 12.0
			draw_line(Vector2(rx + stem_sway, ry + 5.0), Vector2(rx + stem_sway, ry + 5.0 + drip_len), Color(0.85, 0.08, 0.1, 0.3), 1.5)
			# Drip drop at bottom
			draw_circle(Vector2(rx + stem_sway, ry + 6.0 + drip_len), 1.5, Color(0.85, 0.08, 0.1, 0.25))

	# --- Heart motifs scattered ---
	for i in range(12):
		var hx := fmod(float(i) * 107.3, 1280.0)
		var hy := 100.0 + float(i) * 40.0 + sin(_time * 0.3 + float(i)) * 10.0
		var h_alpha := 0.08 + clampf(sin(_time * 0.6 + float(i) * 1.3), 0.0, 1.0) * 0.07
		var h_size := 4.0 + sin(float(i) * 1.5) * 2.0
		draw_circle(Vector2(hx - h_size * 0.4, hy), h_size, Color(0.8, 0.1, 0.15, h_alpha))
		draw_circle(Vector2(hx + h_size * 0.4, hy), h_size, Color(0.8, 0.1, 0.15, h_alpha))
		draw_rect(Rect2(hx - h_size, hy, h_size * 2.0, h_size * 1.0), Color(0.8, 0.1, 0.15, h_alpha))

	# === GROUND â€” red/black checkerboard courtyard ===
	var ground_y := 450.0
	draw_rect(Rect2(0, ground_y, 1280, 628.0 - ground_y), ground_color)
	var tile_size := 36.0
	var cols := int(1280.0 / tile_size) + 1
	var rows := int((628.0 - ground_y) / tile_size) + 1
	for row in range(rows):
		for col in range(cols):
			var is_red := (row + col) % 2 == 0
			var tile_col: Color
			if is_red:
				tile_col = Color(0.55, 0.08, 0.1, 0.3)
			else:
				tile_col = Color(0.08, 0.05, 0.05, 0.25)
			draw_rect(Rect2(float(col) * tile_size, ground_y + float(row) * tile_size, tile_size, tile_size), tile_col)

	# === DECORATIONS ===
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
				var tp2 = dec["pos"]
				draw_rect(Rect2(tp2.x - 4, tp2.y - 5, 8, 6), Color(0.8, 0.75, 0.6, 0.4))
				draw_arc(Vector2(tp2.x + 5, tp2.y - 2), 3, -PI * 0.5, PI * 0.5, 6, Color(0.8, 0.75, 0.6, 0.35), 1.0)

	# === PATH â€” red/black checkerboard path ===
	if enemy_path:
		var path_curve: Curve2D = enemy_path.curve
		if path_curve and path_curve.point_count > 1:
			var path_len := path_curve.get_baked_length()
			var tile_step := 16.0
			var num_tiles := int(path_len / tile_step)
			for i in range(num_tiles):
				var offset_dist := float(i) * tile_step
				var pt := path_curve.sample_baked(offset_dist)
				var is_red_tile := (i % 2 == 0)
				var path_col: Color
				if is_red_tile:
					path_col = Color(0.7, 0.1, 0.12, 0.55)
				else:
					path_col = Color(0.1, 0.05, 0.05, 0.5)
				draw_rect(Rect2(pt.x - 7.0, pt.y - 7.0, 14.0, 14.0), path_col)
				# Gold edge trim
				draw_rect(Rect2(pt.x - 8.0, pt.y - 8.0, 16.0, 16.0), Color(0.7, 0.55, 0.2, 0.1))

			# Heart-shaped path markers every few tiles
			for i in range(0, num_tiles, 8):
				var offset_dist := float(i) * tile_step
				var pt := path_curve.sample_baked(offset_dist)
				var marker_pulse := clampf(sin(_time * 1.0 + float(i) * 0.5), 0.0, 1.0) * 0.15
				draw_circle(Vector2(pt.x - 3.0, pt.y - 2.0), 4.0, Color(0.85, 0.1, 0.15, 0.15 + marker_pulse))
				draw_circle(Vector2(pt.x + 3.0, pt.y - 2.0), 4.0, Color(0.85, 0.1, 0.15, 0.15 + marker_pulse))

	# === FOREGROUND ===
	# Scattered playing cards at bottom
	for i in range(7):
		var fc_x := fmod(float(i) * 187.0 + _time * 6.0, 1400.0) - 60.0
		var fc_y := 570.0 + sin(_time * 0.4 + float(i) * 0.9) * 12.0
		var fc_alpha := 0.15 + clampf(sin(_time * 0.5 + float(i)), 0.0, 1.0) * 0.08
		# Card rectangle
		draw_rect(Rect2(fc_x - 6.0, fc_y - 9.0, 12.0, 18.0), Color(0.95, 0.92, 0.85, fc_alpha))
		# Red or black suit
		var is_red_card := (i % 2 == 0)
		var suit_c := Color(0.8, 0.1, 0.15, fc_alpha * 1.2) if is_red_card else Color(0.1, 0.1, 0.1, fc_alpha * 1.2)
		draw_circle(Vector2(fc_x, fc_y - 2.0), 2.0, suit_c)

	# Red paint splatters on ground
	for i in range(5):
		var splat_x := 150.0 + float(i) * 240.0
		var splat_y := 600.0 + sin(float(i) * 2.7) * 10.0
		var splat_r := 8.0 + sin(float(i) * 1.3) * 4.0
		draw_circle(Vector2(splat_x, splat_y), splat_r, Color(0.75, 0.06, 0.1, 0.12))
		# Smaller satellite splatters
		for j in range(3):
			var angle := float(j) * TAU / 3.0 + float(i)
			var dist := splat_r + 5.0
			var sub_x := splat_x + cos(angle) * dist
			var sub_y := splat_y + sin(angle) * dist
			draw_circle(Vector2(sub_x, sub_y), 2.5, Color(0.75, 0.06, 0.1, 0.08))

	# Bottom crimson fog
	for i in range(8):
		var fog_t := float(i) / 8.0
		var fog_y := 600.0 + fog_t * 28.0
		draw_rect(Rect2(0, fog_y, 1280, 4.0), Color(0.35, 0.05, 0.08, 0.08 + fog_t * 0.06))

func _draw_oz_ch2(sky_color: Color, ground_color: Color) -> void:
	# === SKY GRADIENT â€” dark green-black storm sky ===
	for i in range(40):
		var t = float(i) / 39.0
		var col = sky_color.lerp(Color(0.03, 0.08, 0.02, 1.0), t * 0.6)
		# Lightning flicker in storm clouds
		var lightning = clampf(sin(_time * 8.7 + t * 12.0) * sin(_time * 3.1), 0.0, 1.0)
		if lightning > 0.92:
			col = col.lerp(Color(0.6, 0.7, 0.5, 1.0), (lightning - 0.92) * 8.0)
		draw_rect(Rect2(0, 50 + t * 280, 1280, 8.5), col)

	# === STORM CLOUDS â€” roiling green-black masses ===
	for i in range(18):
		var cx = float(i) * 75.0 + sin(_time * 0.3 + float(i) * 0.9) * 30.0
		var cy = 70.0 + sin(float(i) * 1.7 + _time * 0.25) * 25.0
		var cr = 55.0 + sin(float(i) * 2.3) * 20.0
		var cloud_col = Color(0.04, 0.1, 0.03, 0.6 + sin(_time * 0.4 + float(i)) * 0.1)
		draw_circle(Vector2(cx, cy), cr, cloud_col)
		# Green-tinged underbelly
		draw_circle(Vector2(cx + 10.0, cy + 15.0), cr * 0.7, Color(0.08, 0.18, 0.05, 0.35))

	# === SICKLY GREEN MOON behind clouds ===
	var moon_x = 980.0
	var moon_y = 100.0
	draw_circle(Vector2(moon_x, moon_y), 42.0, Color(0.25, 0.45, 0.15, 0.35))
	draw_circle(Vector2(moon_x, moon_y), 34.0, Color(0.35, 0.55, 0.2, 0.5))
	draw_circle(Vector2(moon_x, moon_y), 26.0, Color(0.5, 0.7, 0.3, 0.6))
	# Moon craters
	draw_circle(Vector2(moon_x - 8.0, moon_y - 5.0), 6.0, Color(0.3, 0.5, 0.15, 0.3))
	draw_circle(Vector2(moon_x + 10.0, moon_y + 4.0), 4.0, Color(0.3, 0.5, 0.15, 0.25))

	# === BROOMSTICK SILHOUETTE crossing the moon (animated) ===
	var broom_phase = fmod(_time * 0.4, 2.0) - 1.0
	var broom_cx = moon_x + broom_phase * 80.0
	var broom_cy = moon_y + sin(broom_phase * 3.0) * 12.0
	if absf(broom_phase) < 0.8:
		# Rider silhouette
		var broom_pts = PackedVector2Array([
			Vector2(broom_cx - 18.0, broom_cy - 6.0),
			Vector2(broom_cx + 12.0, broom_cy - 2.0),
			Vector2(broom_cx + 22.0, broom_cy + 2.0),
			Vector2(broom_cx + 30.0, broom_cy + 6.0),
			Vector2(broom_cx + 30.0, broom_cy + 10.0),
			Vector2(broom_cx + 12.0, broom_cy + 4.0),
			Vector2(broom_cx - 8.0, broom_cy + 4.0),
			Vector2(broom_cx - 18.0, broom_cy)])
		draw_colored_polygon(broom_pts, Color(0.02, 0.02, 0.02, 0.85))
		# Pointy hat
		draw_colored_polygon(PackedVector2Array([
			Vector2(broom_cx - 12.0, broom_cy - 6.0),
			Vector2(broom_cx - 6.0, broom_cy - 22.0),
			Vector2(broom_cx - 2.0, broom_cy - 6.0)]), Color(0.02, 0.02, 0.02, 0.85))
		# Broom bristles
		for b in range(5):
			var boff = float(b) * 2.5 - 5.0
			draw_line(Vector2(broom_cx + 28.0, broom_cy + 6.0), Vector2(broom_cx + 40.0, broom_cy + 4.0 + boff), Color(0.02, 0.02, 0.02, 0.7), 1.0)

	# === DISTANT MOUNTAINS â€” dark jagged peaks ===
	for layer in range(3):
		var pts = PackedVector2Array()
		pts.append(Vector2(0, 330 - layer * 30))
		var lf = float(layer)
		for j in range(26):
			var mx = float(j) * 52.0
			var my = 210.0 - lf * 30.0 + sin(float(j) * 1.3 + lf * 2.0) * 45.0 + sin(float(j) * 0.4) * 30.0
			pts.append(Vector2(mx, my))
		pts.append(Vector2(1280, 330 - layer * 30))
		var dark = 0.03 + lf * 0.02
		draw_colored_polygon(pts, Color(dark, dark + 0.02, dark, 0.85 - lf * 0.1))

	# === WITCH'S CASTLE SILHOUETTE on tallest peak ===
	var castle_x = 350.0
	var castle_base = 165.0
	# Main tower
	draw_colored_polygon(PackedVector2Array([
		Vector2(castle_x - 25.0, castle_base), Vector2(castle_x - 20.0, castle_base - 80.0),
		Vector2(castle_x - 8.0, castle_base - 95.0), Vector2(castle_x, castle_base - 110.0),
		Vector2(castle_x + 8.0, castle_base - 95.0), Vector2(castle_x + 20.0, castle_base - 80.0),
		Vector2(castle_x + 25.0, castle_base)]), Color(0.02, 0.02, 0.02, 0.95))
	# Side towers
	for side in [-1.0, 1.0]:
		var sx = castle_x + side * 45.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(sx - 12.0, castle_base), Vector2(sx - 10.0, castle_base - 50.0),
			Vector2(sx, castle_base - 65.0), Vector2(sx + 10.0, castle_base - 50.0),
			Vector2(sx + 12.0, castle_base)]), Color(0.02, 0.02, 0.02, 0.95))
	# Castle windows â€” eerie green glow
	var win_glow = 0.5 + sin(_time * 1.5) * 0.2
	draw_circle(Vector2(castle_x, castle_base - 70.0), 4.0, Color(0.2, 0.6 * win_glow, 0.1, 0.7))
	draw_circle(Vector2(castle_x - 45.0, castle_base - 35.0), 3.0, Color(0.2, 0.5 * win_glow, 0.1, 0.6))
	draw_circle(Vector2(castle_x + 45.0, castle_base - 35.0), 3.0, Color(0.2, 0.5 * win_glow, 0.1, 0.6))

	# === HOURGLASS MOTIF â€” ghostly outline in the sky ===
	var hg_x = 160.0
	var hg_y = 130.0
	var hg_alpha = 0.12 + sin(_time * 0.8) * 0.05
	draw_colored_polygon(PackedVector2Array([
		Vector2(hg_x - 14.0, hg_y - 28.0), Vector2(hg_x + 14.0, hg_y - 28.0),
		Vector2(hg_x + 3.0, hg_y), Vector2(hg_x + 14.0, hg_y + 28.0),
		Vector2(hg_x - 14.0, hg_y + 28.0), Vector2(hg_x - 3.0, hg_y)]),
		Color(0.3, 0.6, 0.2, hg_alpha))
	# Sand falling
	var sand_y = hg_y - 10.0 + fmod(_time * 12.0, 20.0)
	if sand_y < hg_y + 20.0:
		draw_circle(Vector2(hg_x, sand_y), 1.5, Color(0.5, 0.7, 0.2, hg_alpha * 2.0))

	# === GREEN SMOKE RISING from castle ===
	for s in range(8):
		var sf = float(s)
		var smoke_t = fmod(_time * 0.6 + sf * 0.4, 3.5)
		var smoke_x = castle_x + sin(smoke_t * 2.0 + sf) * 15.0
		var smoke_y = castle_base - 110.0 - smoke_t * 30.0
		var smoke_r = 6.0 + smoke_t * 8.0
		var smoke_a = clampf(0.3 - smoke_t * 0.08, 0.0, 0.3)
		draw_circle(Vector2(smoke_x, smoke_y), smoke_r, Color(0.15, 0.5, 0.1, smoke_a))

	# === WINKIE GUARD TOWERS â€” flanking the scene ===
	for gx in [80.0, 1200.0]:
		var gy = 300.0
		# Tower body
		draw_rect(Rect2(gx - 14.0, gy - 55.0, 28.0, 55.0), Color(0.12, 0.1, 0.05, 0.75))
		# Crenellations
		for c in range(4):
			draw_rect(Rect2(gx - 14.0 + float(c) * 9.0, gy - 62.0, 5.0, 7.0), Color(0.12, 0.1, 0.05, 0.75))
		# Torch glow
		var torch_flicker = 0.6 + sin(_time * 5.0 + gx) * 0.15
		draw_circle(Vector2(gx, gy - 40.0), 5.0, Color(0.6, 0.3, 0.05, torch_flicker * 0.5))
		draw_circle(Vector2(gx, gy - 40.0), 3.0, Color(0.8, 0.5, 0.1, torch_flicker * 0.7))

	# === FLYING MONKEYS â€” animated swooping ===
	for m in range(4):
		var mf = float(m)
		var monkey_t = fmod(_time * 0.7 + mf * 1.8, 6.0)
		var monkey_x = monkey_t * 220.0 - 40.0
		var monkey_y = 140.0 + sin(monkey_t * 3.0 + mf * 2.0) * 35.0 + mf * 25.0
		if monkey_x > -20.0 and monkey_x < 1300.0:
			# Body
			draw_circle(Vector2(monkey_x, monkey_y), 5.0, Color(0.08, 0.06, 0.04, 0.7))
			# Wings flapping
			var wing_angle = sin(_time * 8.0 + mf * 3.0) * 0.6
			var wing_up = -12.0 + wing_angle * 10.0
			draw_line(Vector2(monkey_x - 4.0, monkey_y), Vector2(monkey_x - 16.0, monkey_y + wing_up), Color(0.1, 0.08, 0.05, 0.6), 2.0)
			draw_line(Vector2(monkey_x + 4.0, monkey_y), Vector2(monkey_x + 16.0, monkey_y + wing_up), Color(0.1, 0.08, 0.05, 0.6), 2.0)

	# === DEAD GNARLED TREES ===
	for tx in [50.0, 220.0, 600.0, 850.0, 1100.0, 1230.0]:
		var tree_base = 340.0 + sin(tx * 0.7) * 15.0
		var tree_h = 50.0 + sin(tx * 1.3) * 15.0
		var tree_col = Color(0.08, 0.06, 0.03, 0.7)
		# Trunk
		draw_line(Vector2(tx, tree_base), Vector2(tx + sin(tx) * 5.0, tree_base - tree_h), tree_col, 3.0)
		# Twisted branches
		for br in range(4):
			var bf = float(br)
			var by = tree_base - tree_h * (0.4 + bf * 0.15)
			var bx_off = (15.0 + bf * 8.0) * (1.0 if fmod(bf, 2.0) < 1.0 else -1.0)
			var sway = sin(_time * 0.7 + tx + bf) * 3.0
			draw_line(Vector2(tx, by), Vector2(tx + bx_off + sway, by - 12.0 - bf * 3.0), tree_col, 1.5)
			# Sub-branches
			draw_line(Vector2(tx + bx_off * 0.7 + sway, by - 8.0), Vector2(tx + bx_off * 1.1 + sway, by - 20.0), tree_col, 1.0)

	# === GROUND â€” barren dark earth ===
	var ground_pts = PackedVector2Array()
	ground_pts.append(Vector2(0, 628))
	for g in range(65):
		var gx = float(g) * 20.0
		var gy = 340.0 + sin(gx * 0.03 + 1.5) * 12.0 + sin(gx * 0.07) * 5.0
		ground_pts.append(Vector2(gx, gy))
	ground_pts.append(Vector2(1280, 628))
	draw_colored_polygon(ground_pts, ground_color)

	# Ground texture â€” cracked dry earth
	for i in range(30):
		var cx = float(i) * 43.0 + sin(float(i) * 3.7) * 20.0
		var cy = 380.0 + sin(float(i) * 1.9) * 60.0 + float(i) * 5.0
		if cy < 620.0:
			var crack_len = 15.0 + sin(float(i) * 2.3) * 8.0
			var crack_angle = sin(float(i) * 4.1) * 0.8
			draw_line(Vector2(cx, cy), Vector2(cx + cos(crack_angle) * crack_len, cy + sin(crack_angle) * crack_len), Color(0.05, 0.04, 0.02, 0.3), 1.0)

	# === DECORATIONS ===
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

	# === PATH â€” cracked dark stone road ===
	if enemy_path:
		var curve = enemy_path.curve
		if curve and curve.point_count > 0:
			var path_points = curve.tessellate()
			if path_points.size() > 1:
				# Dark stone base
				for k in range(path_points.size() - 1):
					var p1 = path_points[k]
					var p2 = path_points[k + 1]
					draw_line(p1, p2, Color(0.12, 0.1, 0.08, 0.8), 32.0)
				# Cracked stone overlay
				for k in range(path_points.size() - 1):
					var p1 = path_points[k]
					var p2 = path_points[k + 1]
					draw_line(p1, p2, Color(0.08, 0.07, 0.05, 0.5), 28.0)
				# Stone cracks along path
				for k in range(0, path_points.size() - 1, 4):
					var p = path_points[k]
					var crack_off = Vector2(sin(float(k) * 1.7) * 10.0, cos(float(k) * 2.1) * 6.0)
					draw_line(p + crack_off, p - crack_off, Color(0.04, 0.03, 0.02, 0.4), 1.0)
				# Dark edges
				for k in range(path_points.size() - 1):
					var p1 = path_points[k]
					var p2 = path_points[k + 1]
					var dir = (p2 - p1).normalized()
					var n = Vector2(-dir.y, dir.x)
					draw_line(p1 + n * 15.0, p2 + n * 15.0, Color(0.04, 0.03, 0.02, 0.35), 2.0)
					draw_line(p1 - n * 15.0, p2 - n * 15.0, Color(0.04, 0.03, 0.02, 0.35), 2.0)

	# === FOREGROUND â€” dark mist and atmosphere ===
	for i in range(6):
		var fi = float(i)
		var fog_x = fmod(fi * 250.0 + _time * 15.0, 1400.0) - 60.0
		var fog_y = 560.0 + sin(fi * 2.0) * 30.0
		draw_circle(Vector2(fog_x, fog_y), 50.0 + fi * 8.0, Color(0.05, 0.12, 0.03, 0.08))

	# Vignette â€” dark edges
	for v in range(8):
		var vf = float(v)
		var va = 0.04 * (8.0 - vf)
		draw_rect(Rect2(0, 50, vf * 2.0, 578), Color(0.0, 0.0, 0.0, va))
		draw_rect(Rect2(1280.0 - vf * 2.0, 50, vf * 2.0, 578), Color(0.0, 0.0, 0.0, va))


func _draw_oz_ch3(sky_color: Color, ground_color: Color) -> void:
	# === SKY / CEILING â€” emerald green crystalline glow ===
	for i in range(40):
		var t = float(i) / 39.0
		var col = sky_color.lerp(Color(0.05, 0.25, 0.08, 1.0), t * 0.7)
		# Pulsing emerald radiance
		var pulse = sin(_time * 0.6 + t * 4.0) * 0.04
		col = Color(col.r + pulse * 0.3, col.g + pulse, col.b + pulse * 0.3, 1.0)
		draw_rect(Rect2(0, 50 + t * 280, 1280, 8.5), col)

	# === JEWELED CEILING â€” faceted crystal pattern ===
	for i in range(22):
		var fi = float(i)
		var cx = fi * 62.0 + sin(fi * 1.7) * 15.0
		var cy = 65.0 + sin(fi * 2.3) * 12.0
		var jewel_size = 8.0 + sin(fi * 3.1) * 3.0
		var shimmer = (sin(_time * 1.8 + fi * 1.4) + 1.0) * 0.5
		# Emerald facet
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx, cy - jewel_size), Vector2(cx + jewel_size * 0.7, cy),
			Vector2(cx, cy + jewel_size * 0.5), Vector2(cx - jewel_size * 0.7, cy)]),
			Color(0.15, 0.6 + shimmer * 0.2, 0.2, 0.35 + shimmer * 0.15))
		# Light refraction lines
		if shimmer > 0.7:
			draw_line(Vector2(cx, cy), Vector2(cx + sin(fi) * 30.0, cy + 40.0 + fi * 3.0),
				Color(0.3, 0.8, 0.4, 0.06), 1.0)

	# === GREEN CRYSTAL WALLS â€” left and right ===
	for side in [0.0, 1.0]:
		var wall_x = side * 1200.0 + 20.0
		# Crystal column structures
		for j in range(6):
			var jf = float(j)
			var col_x = wall_x + sin(jf * 2.0) * 10.0
			var col_top = 70.0 + jf * 8.0
			var col_bot = 600.0 - jf * 10.0
			var glow = 0.3 + sin(_time * 1.2 + jf + side * 3.0) * 0.1
			# Crystal column body
			draw_rect(Rect2(col_x, col_top, 10.0 + jf * 2.0, col_bot - col_top),
				Color(0.1, 0.35 + glow, 0.12, 0.2 - jf * 0.02))
			# Facet highlights
			draw_line(Vector2(col_x + 2.0, col_top), Vector2(col_x + 2.0, col_bot),
				Color(0.3, 0.7, 0.35, 0.1), 1.0)

	# === EMERALD GLOW â€” ambient light from walls ===
	for i in range(5):
		var fi = float(i)
		var glow_x = fi * 320.0 + 80.0
		var glow_y = 300.0 + sin(fi * 2.0) * 50.0
		var glow_pulse = 0.06 + sin(_time * 0.9 + fi * 1.5) * 0.02
		draw_circle(Vector2(glow_x, glow_y), 120.0, Color(0.1, 0.4, 0.12, glow_pulse))
		draw_circle(Vector2(glow_x, glow_y), 60.0, Color(0.15, 0.5, 0.18, glow_pulse * 1.5))

	# === THRONE at far end â€” tall emerald chair ===
	var throne_x = 640.0
	var throne_y = 150.0
	# Throne back â€” tall pointed emerald
	draw_colored_polygon(PackedVector2Array([
		Vector2(throne_x - 30.0, throne_y + 60.0), Vector2(throne_x - 20.0, throne_y - 40.0),
		Vector2(throne_x - 8.0, throne_y - 70.0), Vector2(throne_x, throne_y - 80.0),
		Vector2(throne_x + 8.0, throne_y - 70.0), Vector2(throne_x + 20.0, throne_y - 40.0),
		Vector2(throne_x + 30.0, throne_y + 60.0)]),
		Color(0.08, 0.35, 0.1, 0.6))
	# Throne glow
	var throne_glow = 0.3 + sin(_time * 0.7) * 0.1
	draw_circle(Vector2(throne_x, throne_y - 20.0), 18.0, Color(0.2, 0.6, 0.25, throne_glow * 0.4))
	# Emerald jewel on throne top
	draw_circle(Vector2(throne_x, throne_y - 72.0), 6.0, Color(0.3, 0.85, 0.35, 0.7))
	draw_circle(Vector2(throne_x, throne_y - 72.0), 3.0, Color(0.6, 1.0, 0.65, 0.5))
	# Throne seat
	draw_rect(Rect2(throne_x - 24.0, throne_y + 40.0, 48.0, 12.0), Color(0.06, 0.28, 0.08, 0.55))
	# Armrests
	draw_rect(Rect2(throne_x - 32.0, throne_y + 20.0, 8.0, 32.0), Color(0.07, 0.3, 0.09, 0.5))
	draw_rect(Rect2(throne_x + 24.0, throne_y + 20.0, 8.0, 32.0), Color(0.07, 0.3, 0.09, 0.5))

	# === RUBY SLIPPERS MOTIF â€” glowing on throne steps ===
	var slipper_x = 640.0
	var slipper_y = 240.0
	var ruby_sparkle = (sin(_time * 2.5) + 1.0) * 0.5
	# Left slipper
	draw_colored_polygon(PackedVector2Array([
		Vector2(slipper_x - 15.0, slipper_y), Vector2(slipper_x - 5.0, slipper_y - 5.0),
		Vector2(slipper_x - 2.0, slipper_y - 3.0), Vector2(slipper_x - 3.0, slipper_y + 2.0),
		Vector2(slipper_x - 10.0, slipper_y + 4.0)]),
		Color(0.8, 0.1, 0.1, 0.5 + ruby_sparkle * 0.2))
	# Right slipper
	draw_colored_polygon(PackedVector2Array([
		Vector2(slipper_x + 5.0, slipper_y), Vector2(slipper_x + 15.0, slipper_y - 4.0),
		Vector2(slipper_x + 18.0, slipper_y - 1.0), Vector2(slipper_x + 16.0, slipper_y + 3.0),
		Vector2(slipper_x + 8.0, slipper_y + 4.0)]),
		Color(0.8, 0.1, 0.1, 0.5 + ruby_sparkle * 0.2))
	# Ruby glow
	draw_circle(Vector2(slipper_x + 2.0, slipper_y), 12.0, Color(0.7, 0.1, 0.1, 0.08 + ruby_sparkle * 0.06))

	# === NOME KING'S ROCKS â€” emerging through floor ===
	for i in range(7):
		var fi = float(i)
		var rock_x = 100.0 + fi * 170.0 + sin(fi * 3.3) * 40.0
		var rock_base_y = 420.0 + sin(fi * 2.1) * 30.0
		var emerge_phase = sin(_time * 0.5 + fi * 1.2)
		var rock_height = 20.0 + clampf(emerge_phase, 0.0, 1.0) * 25.0
		var rock_w = 18.0 + sin(fi * 1.7) * 6.0
		# Jagged rock shape
		draw_colored_polygon(PackedVector2Array([
			Vector2(rock_x - rock_w, rock_base_y),
			Vector2(rock_x - rock_w * 0.6, rock_base_y - rock_height * 0.7),
			Vector2(rock_x - rock_w * 0.2, rock_base_y - rock_height),
			Vector2(rock_x + rock_w * 0.3, rock_base_y - rock_height * 0.85),
			Vector2(rock_x + rock_w * 0.7, rock_base_y - rock_height * 0.5),
			Vector2(rock_x + rock_w, rock_base_y)]),
			Color(0.25, 0.18, 0.1, 0.5 + clampf(emerge_phase, 0.0, 1.0) * 0.2))
		# Cracks in rock
		draw_line(Vector2(rock_x, rock_base_y - rock_height * 0.3),
			Vector2(rock_x + rock_w * 0.3, rock_base_y - rock_height * 0.8),
			Color(0.15, 0.1, 0.05, 0.3), 1.0)
		# Dust particles when emerging
		if emerge_phase > 0.3:
			for d in range(3):
				var df = float(d)
				var dust_x = rock_x + sin(_time * 3.0 + df * 2.0 + fi) * 12.0
				var dust_y = rock_base_y - sin(_time * 2.0 + df + fi) * 10.0
				draw_circle(Vector2(dust_x, dust_y), 2.0, Color(0.3, 0.22, 0.12, 0.15))

	# === CRACKING FLOOR â€” tile pattern with fractures ===
	for row in range(8):
		var rf = float(row)
		var ty = 380.0 + rf * 32.0
		for col in range(20):
			var cf = float(col)
			var tx = cf * 68.0 + fmod(rf, 2.0) * 34.0
			# Tile outline
			draw_rect(Rect2(tx, ty, 64.0, 28.0), Color(0.1, 0.32, 0.12, 0.15), false, 1.0)
			# Cracks across some tiles
			if sin(rf * 3.1 + cf * 2.7) > 0.2:
				var crack_start = Vector2(tx + 10.0, ty + 14.0)
				var crack_end = Vector2(tx + 50.0 + sin(cf * 4.0) * 10.0, ty + 8.0 + cos(rf * 2.0) * 8.0)
				draw_line(crack_start, crack_end, Color(0.15, 0.08, 0.04, 0.3), 1.0)
				# Branch crack
				var mid = (crack_start + crack_end) * 0.5
				draw_line(mid, mid + Vector2(sin(cf) * 12.0, 10.0), Color(0.15, 0.08, 0.04, 0.2), 1.0)

	# === SHATTERED GREEN GLASS â€” debris scattered ===
	for i in range(12):
		var fi = float(i)
		var gx = 80.0 + fi * 105.0 + sin(fi * 2.7) * 30.0
		var gy = 400.0 + sin(fi * 1.9) * 50.0
		var gs = 4.0 + sin(fi * 3.2) * 2.0
		var glass_alpha = 0.2 + sin(_time * 1.5 + fi * 0.8) * 0.08
		# Triangular glass shard
		draw_colored_polygon(PackedVector2Array([
			Vector2(gx, gy - gs * 2.0),
			Vector2(gx + gs * 1.5, gy + gs),
			Vector2(gx - gs, gy + gs * 0.5)]),
			Color(0.25, 0.75, 0.3, glass_alpha))
		# Glint
		draw_line(Vector2(gx - 1.0, gy - gs), Vector2(gx + 2.0, gy + gs * 0.5),
			Color(0.5, 0.9, 0.55, glass_alpha * 0.7), 1.0)

	# === GROUND â€” emerald tile floor ===
	var ground_pts = PackedVector2Array()
	ground_pts.append(Vector2(0, 628))
	for g in range(65):
		var gx = float(g) * 20.0
		var gy = 370.0 + sin(gx * 0.02 + 0.5) * 8.0
		ground_pts.append(Vector2(gx, gy))
	ground_pts.append(Vector2(1280, 628))
	draw_colored_polygon(ground_pts, ground_color)

	# === DECORATIONS ===
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

	# === PATH â€” yellow brick transitioning to cracked emerald tiles ===
	if enemy_path:
		var curve = enemy_path.curve
		if curve and curve.point_count > 0:
			var path_points = curve.tessellate()
			if path_points.size() > 1:
				var total_pts = path_points.size()
				for k in range(total_pts - 1):
					var p1 = path_points[k]
					var p2 = path_points[k + 1]
					var progress = float(k) / float(total_pts - 1)
					# Transition: yellow brick (0.0) -> emerald tile (1.0)
					var yellow = Color(0.7, 0.6, 0.15, 0.7)
					var emerald = Color(0.12, 0.4, 0.15, 0.7)
					var path_col = yellow.lerp(emerald, progress)
					draw_line(p1, p2, path_col, 30.0)
				# Brick / tile pattern
				for k in range(0, total_pts - 1, 3):
					var p = path_points[k]
					var progress = float(k) / float(total_pts - 1)
					var dir = Vector2.ZERO
					if k + 1 < total_pts:
						dir = (path_points[k + 1] - p).normalized()
					var n = Vector2(-dir.y, dir.x)
					# Cross lines forming brick/tile pattern
					if progress < 0.5:
						# Yellow brick joints
						draw_line(p + n * 12.0, p - n * 12.0, Color(0.5, 0.42, 0.1, 0.3), 1.0)
					else:
						# Emerald tile cracks
						draw_line(p + n * 13.0, p - n * 13.0, Color(0.06, 0.2, 0.06, 0.35), 1.0)
						if sin(float(k) * 1.9) > 0.4:
							draw_line(p, p + n * 8.0 + dir * 10.0, Color(0.15, 0.08, 0.04, 0.25), 1.0)
				# Path edges
				for k in range(total_pts - 1):
					var p1 = path_points[k]
					var p2 = path_points[k + 1]
					var dir = (p2 - p1).normalized()
					var n = Vector2(-dir.y, dir.x)
					var progress = float(k) / float(total_pts - 1)
					var edge_col = Color(0.5, 0.42, 0.1, 0.3).lerp(Color(0.08, 0.3, 0.1, 0.35), progress)
					draw_line(p1 + n * 14.0, p2 + n * 14.0, edge_col, 2.0)
					draw_line(p1 - n * 14.0, p2 - n * 14.0, edge_col, 2.0)

	# === FOREGROUND â€” emerald sparkle particles ===
	for i in range(10):
		var fi = float(i)
		var spark_t = fmod(_time * 0.8 + fi * 0.7, 4.0)
		var spark_x = fi * 130.0 + sin(spark_t * 2.0 + fi) * 40.0
		var spark_y = 500.0 + sin(spark_t * 1.5 + fi * 3.0) * 60.0 - spark_t * 20.0
		var spark_alpha = clampf(0.25 - absf(spark_t - 2.0) * 0.12, 0.0, 0.25)
		draw_circle(Vector2(spark_x, spark_y), 2.0, Color(0.3, 0.9, 0.4, spark_alpha))
		draw_circle(Vector2(spark_x, spark_y), 1.0, Color(0.6, 1.0, 0.65, spark_alpha * 1.5))

	# === Green ambient fog at base ===
	for i in range(8):
		var fi = float(i)
		var fog_x = fmod(fi * 180.0 + _time * 10.0, 1400.0) - 60.0
		var fog_y = 580.0 + sin(fi * 1.7) * 20.0
		draw_circle(Vector2(fog_x, fog_y), 55.0 + fi * 6.0, Color(0.1, 0.35, 0.12, 0.06))

	# === Ceiling light beams ===
	for i in range(4):
		var fi = float(i)
		var bx = 200.0 + fi * 280.0
		var bs = sin(_time * 0.3 + fi * 1.5) * 15.0
		var ba = 0.03 + sin(_time * 0.7 + fi * 2.0) * 0.01
		draw_colored_polygon(PackedVector2Array([
			Vector2(bx - 8.0 + bs * 0.3, 55.0), Vector2(bx + 8.0 + bs * 0.3, 55.0),
			Vector2(bx + 40.0 + bs, 620.0), Vector2(bx - 40.0 + bs, 620.0)]),
			Color(0.2, 0.7, 0.25, ba))

func _draw_peter_ch2(sky_color: Color, ground_color: Color) -> void:
	# === SKY GRADIENT â€” Dark jungle night ===
	for i in range(32):
		var t = float(i) / 31.0
		var col = sky_color.lerp(Color(0.02, 0.06, 0.12), t)
		# Add faint green jungle haze in lower sky
		col = col.lerp(Color(0.03, 0.1, 0.06), t * t * 0.4)
		var y0 = int(t * 578.0) + 50
		var y1 = int((t + 1.0 / 31.0) * 578.0) + 50
		draw_rect(Rect2(0, y0, 1280, y1 - y0 + 1), col)

	# === STARS / ATMOSPHERE â€” Faint stars through canopy gaps ===
	var star_positions = [
		Vector2(120, 62), Vector2(340, 75), Vector2(580, 58), Vector2(790, 80),
		Vector2(950, 65), Vector2(1100, 72), Vector2(200, 90), Vector2(680, 68),
		Vector2(1020, 85), Vector2(440, 60), Vector2(860, 70), Vector2(1200, 78)
	]
	for sp in star_positions:
		var flicker = (sin(_time * 1.8 + sp.x * 0.03) + 1.0) * 0.5
		var blocked = sin(sp.x * 0.02 + sp.y * 0.05)
		if blocked > 0.1:
			draw_circle(sp, 0.8 + flicker * 0.5, Color(1.0, 0.97, 0.85, 0.15 + flicker * 0.2))

	# Moon glow behind canopy
	var moon_pos = Vector2(980, 90)
	draw_circle(moon_pos, 50.0, Color(0.6, 0.65, 0.8, 0.04))
	draw_circle(moon_pos, 30.0, Color(0.7, 0.75, 0.9, 0.07))
	draw_circle(moon_pos, 14.0, Color(0.85, 0.88, 0.95, 0.2))

	# Jungle mist layers
	for m in range(5):
		var my = 200.0 + float(m) * 70.0
		var mx_off = sin(_time * 0.15 + float(m) * 1.3) * 40.0
		var mist_alpha = 0.03 + float(m) * 0.008
		draw_rect(Rect2(mx_off - 50, my, 1380, 25), Color(0.15, 0.25, 0.18, mist_alpha))

	# === LANDMARKS ===

	# --- Skull Rock in distance (far right background) ---
	var skull_base = Vector2(1150, 200)
	var skull_pts: PackedVector2Array = PackedVector2Array([
		skull_base + Vector2(-60, 0), skull_base + Vector2(-55, -40),
		skull_base + Vector2(-40, -65), skull_base + Vector2(-15, -78),
		skull_base + Vector2(15, -78), skull_base + Vector2(40, -65),
		skull_base + Vector2(55, -40), skull_base + Vector2(60, 0)
	])
	draw_colored_polygon(skull_pts, Color(0.12, 0.1, 0.13, 0.6))
	# Skull eye sockets â€” faint red glow
	draw_circle(skull_base + Vector2(-18, -50), 9.0, Color(0.05, 0.03, 0.05, 0.7))
	draw_circle(skull_base + Vector2(18, -50), 9.0, Color(0.05, 0.03, 0.05, 0.7))
	var eye_pulse = (sin(_time * 1.5) + 1.0) * 0.5
	draw_circle(skull_base + Vector2(-18, -50), 4.0, Color(0.8, 0.1, 0.05, 0.2 + eye_pulse * 0.15))
	draw_circle(skull_base + Vector2(18, -50), 4.0, Color(0.8, 0.1, 0.05, 0.2 + eye_pulse * 0.15))
	# Nose cavity
	draw_circle(skull_base + Vector2(0, -38), 5.0, Color(0.04, 0.02, 0.04, 0.6))
	# Teeth
	for ti in range(5):
		var tx = skull_base.x - 12.0 + float(ti) * 6.0
		draw_line(Vector2(tx, skull_base.y - 25), Vector2(tx, skull_base.y - 19), Color(0.1, 0.08, 0.1, 0.5), 2.0)

	# --- Dense background canopy trees ---
	var bg_trees = [
		Vector2(50, 310), Vector2(180, 290), Vector2(350, 300), Vector2(500, 280),
		Vector2(650, 305), Vector2(800, 275), Vector2(960, 295), Vector2(1100, 285),
		Vector2(120, 320), Vector2(420, 315), Vector2(730, 310), Vector2(1030, 300)
	]
	for bt in bg_trees:
		var trunk_h = 120.0 + sin(bt.x * 0.01) * 30.0
		var canopy_r = 55.0 + cos(bt.x * 0.02) * 15.0
		# Trunk
		draw_line(bt, bt + Vector2(0, -trunk_h), Color(0.15, 0.1, 0.05, 0.7), 5.0)
		# Canopy mass
		var ct = bt + Vector2(0, -trunk_h)
		draw_circle(ct, canopy_r, Color(0.04, 0.18, 0.06, 0.6))
		draw_circle(ct + Vector2(-canopy_r * 0.4, canopy_r * 0.15), canopy_r * 0.7, Color(0.03, 0.15, 0.05, 0.55))
		draw_circle(ct + Vector2(canopy_r * 0.35, canopy_r * 0.1), canopy_r * 0.65, Color(0.05, 0.2, 0.07, 0.5))

	# --- Lost Boys' Treehouse Complex (center-left) ---
	# Main treehouse tree
	var th_base = Vector2(400, 480)
	var th_trunk_top = th_base + Vector2(0, -280)
	draw_line(th_base, th_trunk_top, Color(0.25, 0.16, 0.06), 14.0)
	# Branches
	var branches = [
		[th_base + Vector2(0, -180), Vector2(70, -40)],
		[th_base + Vector2(0, -220), Vector2(-80, -30)],
		[th_base + Vector2(0, -140), Vector2(-60, -50)],
		[th_base + Vector2(0, -250), Vector2(55, -25)]
	]
	for br in branches:
		draw_line(br[0], br[0] + br[1], Color(0.22, 0.14, 0.05), 5.0)

	# Treehouse platform
	var platform_y = th_base.y - 200.0
	draw_rect(Rect2(340, platform_y, 120, 8), Color(0.35, 0.22, 0.08))
	# Treehouse walls
	draw_rect(Rect2(350, platform_y - 55, 100, 55), Color(0.3, 0.2, 0.07, 0.85))
	# Roof (triangle)
	var roof_pts: PackedVector2Array = PackedVector2Array([
		Vector2(345, platform_y - 55), Vector2(400, platform_y - 90), Vector2(455, platform_y - 55)
	])
	draw_colored_polygon(roof_pts, Color(0.2, 0.35, 0.1, 0.9))
	# Window with warm light
	draw_rect(Rect2(375, platform_y - 45, 18, 16), Color(0.9, 0.7, 0.2, 0.6))
	draw_rect(Rect2(410, platform_y - 45, 18, 16), Color(0.9, 0.7, 0.2, 0.5))
	# Hidden door in trunk
	draw_rect(Rect2(391, th_base.y - 130, 18, 30), Color(0.18, 0.12, 0.04))
	var knob_pulse = (sin(_time * 2.2) + 1.0) * 0.5
	draw_circle(Vector2(405, th_base.y - 115), 2.5, Color(0.7, 0.6, 0.2, 0.5 + knob_pulse * 0.3))

	# Ladder from ground to platform
	var ladder_x = 355.0
	for li in range(8):
		var ly = th_base.y - 40.0 - float(li) * 20.0
		draw_line(Vector2(ladder_x, ly), Vector2(ladder_x + 16, ly), Color(0.4, 0.28, 0.1), 2.0)
	draw_line(Vector2(ladder_x, th_base.y - 40), Vector2(ladder_x, platform_y), Color(0.4, 0.28, 0.1), 2.0)
	draw_line(Vector2(ladder_x + 16, th_base.y - 40), Vector2(ladder_x + 16, platform_y), Color(0.4, 0.28, 0.1), 2.0)

	# Second treehouse (right side, smaller)
	var th2_base = Vector2(750, 460)
	draw_line(th2_base, th2_base + Vector2(0, -200), Color(0.22, 0.14, 0.05), 10.0)
	var plat2_y = th2_base.y - 160.0
	draw_rect(Rect2(710, plat2_y, 80, 6), Color(0.32, 0.2, 0.07))
	draw_rect(Rect2(718, plat2_y - 40, 64, 40), Color(0.28, 0.18, 0.06, 0.8))
	draw_rect(Rect2(738, plat2_y - 32, 14, 12), Color(0.85, 0.65, 0.15, 0.5))
	# Hidden door
	draw_rect(Rect2(742, th2_base.y - 100, 16, 26), Color(0.16, 0.1, 0.03))

	# --- Rope bridges between treehouses ---
	var rope_sag = sin(_time * 0.5) * 3.0
	for ri in range(20):
		var rt = float(ri) / 19.0
		var sag = sin(rt * PI) * (18.0 + rope_sag)
		var rp = Vector2(460, platform_y + 4).lerp(Vector2(710, plat2_y + 3), rt) + Vector2(0, sag)
		var rp_next_t = float(ri + 1) / 19.0
		var sag_next = sin(rp_next_t * PI) * (18.0 + rope_sag)
		var rp_next = Vector2(460, platform_y + 4).lerp(Vector2(710, plat2_y + 3), rp_next_t) + Vector2(0, sag_next)
		if ri < 19:
			draw_line(rp, rp_next, Color(0.45, 0.3, 0.1, 0.8), 2.0)
	# Rope rails
	for ri in range(20):
		var rt = float(ri) / 19.0
		var sag_top = sin(rt * PI) * (10.0 + rope_sag * 0.5)
		var rp_top = Vector2(460, platform_y - 15).lerp(Vector2(710, plat2_y - 15), rt) + Vector2(0, sag_top)
		var rp_top_next_t = float(ri + 1) / 19.0
		var sag_top_next = sin(rp_top_next_t * PI) * (10.0 + rope_sag * 0.5)
		var rp_top_next = Vector2(460, platform_y - 15).lerp(Vector2(710, plat2_y - 15), rp_top_next_t) + Vector2(0, sag_top_next)
		if ri < 19:
			draw_line(rp_top, rp_top_next, Color(0.45, 0.3, 0.1, 0.5), 1.5)

	# --- Fairy lanterns strung between trees ---
	var lantern_anchors = [
		[Vector2(180, 250), Vector2(350, 230)],
		[Vector2(500, 210), Vector2(650, 240)],
		[Vector2(800, 225), Vector2(960, 250)],
	]
	for la in lantern_anchors:
		for li in range(6):
			var lt = (float(li) + 0.5) / 6.0
			var lsag = sin(lt * PI) * 15.0
			var lp = la[0].lerp(la[1], lt) + Vector2(0, lsag)
			var lbob = sin(_time * 1.5 + float(li) * 0.8) * 2.0
			lp.y += lbob
			var lpulse = (sin(_time * 2.5 + float(li) * 1.1) + 1.0) * 0.5
			# Lantern body
			draw_circle(lp, 3.0, Color(1.0, 0.85, 0.2, 0.4 + lpulse * 0.3))
			# Glow
			draw_circle(lp, 10.0 + lpulse * 4.0, Color(1.0, 0.9, 0.3, 0.04 + lpulse * 0.03))

	# --- Pirate torchlight visible through trees (background right) ---
	var torch_positions = [Vector2(1050, 350), Vector2(1120, 380), Vector2(1000, 400)]
	for tp in torch_positions:
		var tflicker = (sin(_time * 4.0 + tp.x * 0.05) + 1.0) * 0.5
		draw_circle(tp, 5.0 + tflicker * 2.0, Color(1.0, 0.55, 0.1, 0.3 + tflicker * 0.2))
		draw_circle(tp, 18.0 + tflicker * 6.0, Color(1.0, 0.4, 0.05, 0.04 + tflicker * 0.03))
		# Torch stick
		draw_line(tp, tp + Vector2(0, 20), Color(0.3, 0.18, 0.05), 2.5)

	# --- Captain Hook's shadow looming (far left) ---
	var hook_shadow_base = Vector2(80, 380)
	var shadow_sway = sin(_time * 0.4) * 5.0
	# Tall menacing silhouette
	var hook_body: PackedVector2Array = PackedVector2Array([
		hook_shadow_base + Vector2(-15 + shadow_sway, 0),
		hook_shadow_base + Vector2(-20 + shadow_sway * 1.2, -60),
		hook_shadow_base + Vector2(-12 + shadow_sway * 1.4, -100),
		hook_shadow_base + Vector2(0 + shadow_sway * 1.5, -130),
		hook_shadow_base + Vector2(12 + shadow_sway * 1.4, -100),
		hook_shadow_base + Vector2(20 + shadow_sway * 1.2, -60),
		hook_shadow_base + Vector2(15 + shadow_sway, 0)
	])
	draw_colored_polygon(hook_body, Color(0.02, 0.02, 0.03, 0.6))
	# Hat silhouette
	var hat_center = hook_shadow_base + Vector2(shadow_sway * 1.5, -130)
	var hat_pts: PackedVector2Array = PackedVector2Array([
		hat_center + Vector2(-25, 0), hat_center + Vector2(-8, -25),
		hat_center + Vector2(8, -25), hat_center + Vector2(25, 0)
	])
	draw_colored_polygon(hat_pts, Color(0.02, 0.02, 0.03, 0.6))
	# Hook arm extending
	var hook_arm_end = hook_shadow_base + Vector2(35 + shadow_sway * 1.3, -80)
	draw_line(hook_shadow_base + Vector2(18 + shadow_sway * 1.3, -70), hook_arm_end, Color(0.02, 0.02, 0.03, 0.5), 3.0)
	# The hook curve
	var hook_tip = hook_arm_end + Vector2(8, 10)
	draw_line(hook_arm_end, hook_arm_end + Vector2(5, -8), Color(0.3, 0.3, 0.35, 0.5), 2.0)
	draw_line(hook_arm_end + Vector2(5, -8), hook_tip, Color(0.3, 0.3, 0.35, 0.5), 2.0)

	# === GROUND â€” Dense jungle floor ===
	var ground_y = 500.0
	# Ground gradient layers
	for gi in range(8):
		var gy = ground_y + float(gi) * 16.0
		var gt = float(gi) / 7.0
		var gc = ground_color.lerp(Color(0.05, 0.12, 0.04), gt * 0.5)
		draw_rect(Rect2(0, gy, 1280, 18), gc)

	# Leaf litter / undergrowth
	for ui in range(30):
		var ux = float(ui) * 44.0 + sin(float(ui) * 2.3) * 15.0
		var uy = ground_y - 5.0 + sin(float(ui) * 1.7) * 8.0
		var u_sway = sin(_time * 0.6 + float(ui) * 0.5) * 3.0
		var uh = 12.0 + sin(float(ui) * 3.1) * 6.0
		# Fern fronds
		draw_line(Vector2(ux + u_sway, uy), Vector2(ux - 6 + u_sway, uy - uh), Color(0.08, 0.25, 0.06, 0.6), 1.5)
		draw_line(Vector2(ux + u_sway, uy), Vector2(ux + 6 + u_sway, uy - uh * 0.8), Color(0.06, 0.22, 0.05, 0.5), 1.5)

	# === DECORATIONS ===
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
			"fairy":
				var fp = dec["pos"]
				var fo = dec["extra"]
				var drift = Vector2(sin(_time * 1.2 + fo) * 8.0, cos(_time * 0.9 + fo) * 5.0)
				var pulse = (sin(_time * 3.0 + fo) + 1.0) * 0.5
				draw_circle(fp + drift, 1.5 + pulse, Color(1.0, 0.92, 0.3, 0.5 + pulse * 0.3))
				draw_circle(fp + drift, 4.0 + pulse * 2.0, Color(1.0, 0.9, 0.3, 0.08 + pulse * 0.06))
			"star":
				var twinkle = (sin(_time * 2.0 + dec["extra"]) + 1.0) * 0.5
				var alpha = dec["size"] * (0.4 + twinkle * 0.6)
				draw_circle(dec["pos"], 1.0 + twinkle * 0.8, Color(1.0, 0.97, 0.8, alpha))

	# === PATH â€” Jungle trail (dark brown/green) ===
	if enemy_path:
		var curve = enemy_path.curve
		if curve and curve.point_count > 0:
			var path_length = curve.get_baked_length()
			var prev_pt = curve.sample_baked(0.0)
			var step_count = int(path_length / 6.0)
			for pi in range(1, step_count + 1):
				var dist = float(pi) / float(step_count) * path_length
				var pt = curve.sample_baked(dist)
				# Main dirt path
				draw_line(prev_pt, pt, Color(0.12, 0.08, 0.03, 0.9), 28.0)
				# Mossy edges
				draw_line(prev_pt, pt, Color(0.06, 0.18, 0.05, 0.35), 36.0)
				prev_pt = pt
			# Roots and stones on path
			for ri in range(15):
				var rd = float(ri) / 14.0 * path_length
				var rpt = curve.sample_baked(rd)
				var roff = Vector2(sin(float(ri) * 4.1) * 10.0, cos(float(ri) * 3.7) * 6.0)
				draw_circle(rpt + roff, 2.0 + sin(float(ri) * 2.3) * 1.0, Color(0.1, 0.07, 0.03, 0.4))

	# === FOREGROUND â€” Dense canopy overlay at top ===
	# Foreground canopy leaves draping down
	for fi in range(14):
		var fx = float(fi) * 95.0 + sin(float(fi) * 1.9) * 20.0
		var fy = 50.0 + sin(float(fi) * 2.7) * 15.0
		var f_sway = sin(_time * 0.35 + float(fi) * 0.7) * 4.0
		var leaf_len = 40.0 + sin(float(fi) * 1.3) * 15.0
		# Hanging vine
		draw_line(Vector2(fx + f_sway, fy), Vector2(fx + f_sway * 1.5, fy + leaf_len), Color(0.05, 0.2, 0.04, 0.5), 2.0)
		# Leaf cluster
		draw_circle(Vector2(fx + f_sway * 1.2, fy + leaf_len * 0.5), 18.0, Color(0.03, 0.14, 0.03, 0.4))
		draw_circle(Vector2(fx + f_sway * 0.8, fy + leaf_len * 0.3), 14.0, Color(0.04, 0.17, 0.05, 0.35))

	# Bottom foreground â€” thick underbrush
	for bi in range(20):
		var bx = float(bi) * 66.0 + sin(float(bi) * 3.3) * 10.0
		var by = 600.0 + sin(float(bi) * 1.5) * 15.0
		var b_sway = sin(_time * 0.4 + float(bi) * 0.6) * 3.0
		draw_circle(Vector2(bx + b_sway, by), 20.0 + sin(float(bi) * 2.1) * 8.0, Color(0.03, 0.12, 0.03, 0.5))

	# Foreground vines from top corners
	for vi in range(8):
		var vt = float(vi) / 7.0
		var vine_sway = sin(_time * 0.3 + vt * 2.0) * 6.0
		var v_left = Vector2(vine_sway, 50.0 + vt * 80.0)
		var v_right = Vector2(1280.0 + vine_sway, 50.0 + vt * 70.0)
		draw_circle(v_left, 10.0, Color(0.03, 0.15, 0.04, 0.25 - vt * 0.02))
		draw_circle(v_right, 10.0, Color(0.03, 0.15, 0.04, 0.25 - vt * 0.02))

	# Firefly particles in foreground
	for ffi in range(10):
		var ff_phase = float(ffi) * 1.7 + _time * 0.8
		var ffx = fmod(absf(sin(ff_phase * 0.3)) * 1280.0, 1280.0)
		var ffy = 400.0 + sin(ff_phase * 0.5) * 150.0
		var ff_drift = Vector2(sin(_time * 0.7 + float(ffi)) * 12.0, cos(_time * 0.5 + float(ffi)) * 8.0)
		var ff_bright = clampf((sin(_time * 3.5 + float(ffi) * 2.1) + 1.0) * 0.5, 0.0, 1.0)
		draw_circle(Vector2(ffx, ffy) + ff_drift, 1.5, Color(0.5, 1.0, 0.3, ff_bright * 0.5))
		draw_circle(Vector2(ffx, ffy) + ff_drift, 5.0, Color(0.4, 0.9, 0.2, ff_bright * 0.06))


func _draw_peter_ch3(sky_color: Color, ground_color: Color) -> void:
	# === SKY GRADIENT â€” Sunset battle colors (orange/red/purple) ===
	for i in range(32):
		var t = float(i) / 31.0
		var col: Color
		if t < 0.3:
			col = sky_color.lerp(Color(0.85, 0.35, 0.08), t / 0.3)
		elif t < 0.6:
			var t2 = (t - 0.3) / 0.3
			col = Color(0.85, 0.35, 0.08).lerp(Color(0.65, 0.12, 0.15), t2)
		else:
			var t3 = (t - 0.6) / 0.4
			col = Color(0.65, 0.12, 0.15).lerp(Color(0.2, 0.05, 0.25), t3)
		var y0 = int(t * 578.0) + 50
		var y1 = int((t + 1.0 / 31.0) * 578.0) + 50
		draw_rect(Rect2(0, y0, 1280, y1 - y0 + 1), col)

	# === STARS / ATMOSPHERE â€” Battle-torn sunset sky ===
	# Dramatic cloud streaks
	for ci in range(8):
		var cx = float(ci) * 170.0 + sin(float(ci) * 2.1) * 40.0
		var cy = 70.0 + sin(float(ci) * 1.5) * 25.0
		var cw = 120.0 + sin(float(ci) * 3.2) * 40.0
		var cloud_drift = sin(_time * 0.1 + float(ci) * 0.8) * 10.0
		draw_rect(Rect2(cx + cloud_drift, cy, cw, 8), Color(0.95, 0.5, 0.15, 0.12))
		draw_rect(Rect2(cx + cloud_drift + 10, cy + 10, cw * 0.7, 5), Color(0.9, 0.3, 0.1, 0.08))

	# Sun on horizon (low, half-sunk)
	var sun_pos = Vector2(200, 170)
	draw_circle(sun_pos, 55.0, Color(1.0, 0.6, 0.1, 0.08))
	draw_circle(sun_pos, 35.0, Color(1.0, 0.5, 0.05, 0.15))
	draw_circle(sun_pos, 18.0, Color(1.0, 0.75, 0.2, 0.3))

	# Smoke / cannon haze
	for si in range(6):
		var sx = 300.0 + float(si) * 160.0
		var sy = 120.0 + sin(float(si) * 2.5) * 40.0
		var s_drift = sin(_time * 0.2 + float(si)) * 20.0
		var s_rise = -_time * 3.0 + float(si) * 50.0
		var sfy = sy + fmod(s_rise, 100.0) - 50.0
		draw_circle(Vector2(sx + s_drift, sfy), 25.0 + sin(float(si) * 1.8) * 10.0, Color(0.3, 0.25, 0.2, 0.06))

	# === LANDMARKS ===

	# --- Dark water below ship ---
	var water_y = 480.0
	for wi in range(10):
		var wy = water_y + float(wi) * 15.0
		var wt = float(wi) / 9.0
		var wc = Color(0.02, 0.05, 0.15).lerp(Color(0.01, 0.02, 0.08), wt)
		draw_rect(Rect2(0, wy, 1280, 17), wc)
	# Wave details
	for wvi in range(25):
		var wx = float(wvi) * 52.0
		var wy_off = sin(_time * 0.8 + float(wvi) * 0.6) * 3.0
		var wave_x2 = wx + 30.0 + sin(float(wvi) * 1.2) * 10.0
		draw_line(Vector2(wx, water_y + 5.0 + wy_off), Vector2(wave_x2, water_y + 5.0 + wy_off + sin(_time * 0.9 + float(wvi)) * 2.0), Color(0.15, 0.2, 0.35, 0.15), 1.5)

	# --- Ship hull ---
	var hull_pts: PackedVector2Array = PackedVector2Array([
		Vector2(100, water_y), Vector2(50, water_y - 40),
		Vector2(80, water_y - 80), Vector2(200, water_y - 110),
		Vector2(1080, water_y - 110), Vector2(1200, water_y - 80),
		Vector2(1230, water_y - 40), Vector2(1180, water_y)
	])
	draw_colored_polygon(hull_pts, Color(0.22, 0.12, 0.04))
	# Hull wood planking
	for hi in range(6):
		var hy = water_y - 20.0 - float(hi) * 15.0
		draw_line(Vector2(90, hy), Vector2(1190, hy), Color(0.18, 0.1, 0.03, 0.4), 1.0)

	# --- Cannon ports ---
	var cannon_ys = [water_y - 45.0, water_y - 70.0]
	for cy in cannon_ys:
		for ci in range(7):
			var cx = 180.0 + float(ci) * 130.0
			# Port hole
			draw_rect(Rect2(cx - 10, cy - 8, 20, 16), Color(0.08, 0.04, 0.02))
			# Cannon barrel poking out
			draw_rect(Rect2(cx - 4, cy - 3, 18, 6), Color(0.15, 0.15, 0.15, 0.8))
			# Flash on one random cannon
			if ci == 3 and cy == cannon_ys[0]:
				var flash = clampf(sin(_time * 5.0), 0.0, 1.0)
				if flash > 0.8:
					draw_circle(Vector2(cx + 16, cy), 8.0, Color(1.0, 0.8, 0.2, 0.4))

	# --- Ship deck (main play area) ---
	var deck_y = water_y - 110.0
	draw_rect(Rect2(140, deck_y, 1000, 12), Color(0.3, 0.18, 0.06))
	# Deck planks
	for di in range(22):
		var dx = 150.0 + float(di) * 48.0
		draw_line(Vector2(dx, deck_y), Vector2(dx, deck_y + 12), Color(0.2, 0.12, 0.04, 0.5), 1.0)

	# Deck railing
	draw_line(Vector2(140, deck_y - 35), Vector2(1140, deck_y - 35), Color(0.25, 0.15, 0.05), 3.0)
	for ri in range(18):
		var rx = 155.0 + float(ri) * 56.0
		draw_line(Vector2(rx, deck_y), Vector2(rx, deck_y - 35), Color(0.25, 0.15, 0.05), 2.0)

	# --- Masts and rigging ---
	# Main mast (center)
	var mast1_x = 640.0
	draw_line(Vector2(mast1_x, deck_y), Vector2(mast1_x, 60), Color(0.28, 0.16, 0.05), 8.0)
	# Crow's nest
	draw_rect(Rect2(mast1_x - 18, 75, 36, 10), Color(0.25, 0.14, 0.04))
	draw_line(Vector2(mast1_x - 18, 75), Vector2(mast1_x - 12, 85), Color(0.25, 0.14, 0.04), 2.0)
	draw_line(Vector2(mast1_x + 18, 75), Vector2(mast1_x + 12, 85), Color(0.25, 0.14, 0.04), 2.0)
	# Cross beam
	draw_line(Vector2(mast1_x - 80, 120), Vector2(mast1_x + 80, 120), Color(0.28, 0.16, 0.05), 5.0)
	draw_line(Vector2(mast1_x - 60, 190), Vector2(mast1_x + 60, 190), Color(0.28, 0.16, 0.05), 4.0)
	# Sail (partially furled)
	var sail1_pts: PackedVector2Array = PackedVector2Array([
		Vector2(mast1_x - 75, 122), Vector2(mast1_x + 75, 122),
		Vector2(mast1_x + 55, 185), Vector2(mast1_x - 55, 185)
	])
	var sail_billow = sin(_time * 0.4) * 5.0
	draw_colored_polygon(sail1_pts, Color(0.85, 0.8, 0.7, 0.6))
	# Sail tear/battle damage
	draw_line(Vector2(mast1_x - 20, 140), Vector2(mast1_x + 5, 170), Color(0.4, 0.2, 0.1, 0.3), 2.0)

	# Fore mast
	var mast2_x = 340.0
	draw_line(Vector2(mast2_x, deck_y), Vector2(mast2_x, 100), Color(0.28, 0.16, 0.05), 6.0)
	draw_line(Vector2(mast2_x - 55, 140), Vector2(mast2_x + 55, 140), Color(0.28, 0.16, 0.05), 4.0)
	var sail2_pts: PackedVector2Array = PackedVector2Array([
		Vector2(mast2_x - 50, 142), Vector2(mast2_x + 50, 142),
		Vector2(mast2_x + 40, 210), Vector2(mast2_x - 40, 210)
	])
	draw_colored_polygon(sail2_pts, Color(0.82, 0.77, 0.68, 0.55))

	# Rear mast
	var mast3_x = 940.0
	draw_line(Vector2(mast3_x, deck_y), Vector2(mast3_x, 120), Color(0.28, 0.16, 0.05), 6.0)
	draw_line(Vector2(mast3_x - 50, 160), Vector2(mast3_x + 50, 160), Color(0.28, 0.16, 0.05), 4.0)

	# --- Rigging ropes (mast to mast, mast to hull) ---
	var rigging_lines = [
		[Vector2(mast1_x, 70), Vector2(mast2_x, 105)],
		[Vector2(mast1_x, 70), Vector2(mast3_x, 125)],
		[Vector2(mast2_x, 105), Vector2(140, deck_y - 30)],
		[Vector2(mast3_x, 125), Vector2(1140, deck_y - 30)],
		[Vector2(mast1_x, 120), Vector2(140, deck_y - 20)],
		[Vector2(mast1_x, 120), Vector2(1140, deck_y - 20)],
	]
	for rl in rigging_lines:
		draw_line(rl[0], rl[1], Color(0.2, 0.15, 0.08, 0.4), 1.0)

	# Rope nets on sides
	for ni in range(6):
		for nj in range(4):
			var nx = 160.0 + float(ni) * 15.0
			var ny = deck_y - 30.0 + float(nj) * 12.0
			draw_line(Vector2(nx, ny), Vector2(nx + 15, ny), Color(0.3, 0.2, 0.1, 0.25), 1.0)
			draw_line(Vector2(nx, ny), Vector2(nx, ny + 12), Color(0.3, 0.2, 0.1, 0.25), 1.0)

	# --- Skull-and-crossbones flag (on main mast, flapping) ---
	var flag_base = Vector2(mast1_x, 62)
	var flag_w = 45.0
	var flag_h = 30.0
	var flag_pts: PackedVector2Array = PackedVector2Array()
	for fi in range(10):
		var fx = flag_base.x + float(fi) / 9.0 * flag_w
		var fy_top = flag_base.y + sin(_time * 3.0 + float(fi) * 0.5) * 3.0
		flag_pts.append(Vector2(fx, fy_top))
	for fi in range(9, -1, -1):
		var fx = flag_base.x + float(fi) / 9.0 * flag_w
		var fy_bot = flag_base.y + flag_h + sin(_time * 3.0 + float(fi) * 0.5 + 0.5) * 3.0
		flag_pts.append(Vector2(fx, fy_bot))
	draw_colored_polygon(flag_pts, Color(0.05, 0.05, 0.05, 0.9))
	# Skull on flag
	var flag_center = flag_base + Vector2(flag_w * 0.5, flag_h * 0.45)
	var fc_wave = sin(_time * 3.0 + 2.0) * 2.0
	draw_circle(flag_center + Vector2(fc_wave, 0), 7.0, Color(0.9, 0.85, 0.8, 0.7))
	draw_circle(flag_center + Vector2(-3 + fc_wave, -1), 1.5, Color(0.05, 0.05, 0.05, 0.7))
	draw_circle(flag_center + Vector2(3 + fc_wave, -1), 1.5, Color(0.05, 0.05, 0.05, 0.7))
	# Crossbones
	draw_line(flag_center + Vector2(-8 + fc_wave, 5), flag_center + Vector2(8 + fc_wave, 11), Color(0.9, 0.85, 0.8, 0.6), 1.5)
	draw_line(flag_center + Vector2(8 + fc_wave, 5), flag_center + Vector2(-8 + fc_wave, 11), Color(0.9, 0.85, 0.8, 0.6), 1.5)

	# --- Plank extending over water (right side) ---
	var plank_start = Vector2(1100, deck_y + 5)
	var plank_end = Vector2(1250, deck_y + 15)
	var plank_bob = sin(_time * 1.2) * 2.0
	draw_line(plank_start, plank_end + Vector2(0, plank_bob), Color(0.35, 0.22, 0.08), 8.0)
	# Plank wood grain
	draw_line(plank_start + Vector2(0, -2), plank_end + Vector2(0, -2 + plank_bob), Color(0.28, 0.18, 0.06, 0.5), 1.0)
	draw_line(plank_start + Vector2(0, 2), plank_end + Vector2(0, 2 + plank_bob), Color(0.28, 0.18, 0.06, 0.5), 1.0)

	# --- Ticking crocodile below (in water under plank) ---
	var croc_base = Vector2(1200, water_y + 20)
	var croc_bob = sin(_time * 0.7) * 4.0
	var croc_y = croc_base.y + croc_bob
	# Body
	var croc_body: PackedVector2Array = PackedVector2Array([
		Vector2(croc_base.x - 40, croc_y - 5),
		Vector2(croc_base.x - 30, croc_y - 12),
		Vector2(croc_base.x, croc_y - 14),
		Vector2(croc_base.x + 25, croc_y - 10),
		Vector2(croc_base.x + 40, croc_y - 5),
		Vector2(croc_base.x + 35, croc_y + 3),
		Vector2(croc_base.x, croc_y + 6),
		Vector2(croc_base.x - 35, croc_y + 3)
	])
	draw_colored_polygon(croc_body, Color(0.15, 0.3, 0.1, 0.7))
	# Snout
	draw_line(Vector2(croc_base.x + 35, croc_y - 3), Vector2(croc_base.x + 55, croc_y - 1), Color(0.15, 0.3, 0.1, 0.7), 6.0)
	# Eye
	draw_circle(Vector2(croc_base.x + 20, croc_y - 11), 3.0, Color(0.9, 0.8, 0.1, 0.7))
	draw_circle(Vector2(croc_base.x + 20, croc_y - 11), 1.2, Color(0.1, 0.1, 0.05, 0.8))
	# Teeth
	for ti in range(4):
		var tx = croc_base.x + 38.0 + float(ti) * 5.0
		draw_line(Vector2(tx, croc_y - 3), Vector2(tx, croc_y + 1), Color(0.9, 0.9, 0.8, 0.5), 1.0)
	# Clock visible in water (the ticking clock!)
	var clock_pos = Vector2(croc_base.x - 10, croc_y + 25)
	var clock_pulse = (sin(_time * 6.28) + 1.0) * 0.5  # Ticking once per second
	draw_circle(clock_pos, 12.0, Color(0.7, 0.6, 0.3, 0.15 + clock_pulse * 0.1))
	draw_circle(clock_pos, 10.0, Color(0.85, 0.8, 0.6, 0.2 + clock_pulse * 0.1))
	# Clock hands
	var minute_angle = _time * 0.5
	var hour_angle = _time * 0.04
	draw_line(clock_pos, clock_pos + Vector2(sin(minute_angle) * 7.0, -cos(minute_angle) * 7.0), Color(0.2, 0.15, 0.05, 0.3), 1.0)
	draw_line(clock_pos, clock_pos + Vector2(sin(hour_angle) * 5.0, -cos(hour_angle) * 5.0), Color(0.2, 0.15, 0.05, 0.3), 1.5)
	# Tick-tock ripple
	draw_arc(clock_pos, 14.0 + clock_pulse * 3.0, 0, TAU, 24, Color(0.5, 0.5, 0.4, 0.06 + clock_pulse * 0.04), 1.0)

	# --- Treasure chests on deck ---
	var chest_positions = [Vector2(250, deck_y - 5), Vector2(850, deck_y - 5), Vector2(550, deck_y - 5)]
	for chi in range(chest_positions.size()):
		var cp = chest_positions[chi]
		# Chest body
		draw_rect(Rect2(cp.x - 12, cp.y - 14, 24, 14), Color(0.35, 0.2, 0.05))
		# Chest lid (slightly open on middle one)
		var lid_open = 0.0
		if chi == 2:
			lid_open = 3.0
			# Gold glow
			var g_pulse = (sin(_time * 2.0 + 1.0) + 1.0) * 0.5
			draw_circle(cp + Vector2(0, -16), 8.0, Color(1.0, 0.85, 0.2, 0.08 + g_pulse * 0.06))
		draw_rect(Rect2(cp.x - 13, cp.y - 18 - lid_open, 26, 6), Color(0.4, 0.25, 0.08))
		# Lock / clasp
		draw_circle(cp + Vector2(0, -12), 2.0, Color(0.7, 0.6, 0.15, 0.6))
		# Metal bands
		draw_line(Vector2(cp.x - 12, cp.y - 7), Vector2(cp.x + 12, cp.y - 7), Color(0.5, 0.4, 0.1, 0.4), 1.0)

	# === GROUND â€” Wooden ship deck (lower portion) ===
	for gi in range(6):
		var gy = water_y + float(gi) * 25.0
		var gt = float(gi) / 5.0
		var gc = Color(0.02, 0.04, 0.12).lerp(Color(0.01, 0.02, 0.06), gt)
		draw_rect(Rect2(0, gy, 1280, 27), gc)

	# === DECORATIONS ===
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
			"fairy":
				var fp = dec["pos"]
				var fo = dec["extra"]
				var drift = Vector2(sin(_time * 1.2 + fo) * 8.0, cos(_time * 0.9 + fo) * 5.0)
				var pulse = (sin(_time * 3.0 + fo) + 1.0) * 0.5
				draw_circle(fp + drift, 1.5 + pulse, Color(1.0, 0.92, 0.3, 0.5 + pulse * 0.3))
				draw_circle(fp + drift, 4.0 + pulse * 2.0, Color(1.0, 0.9, 0.3, 0.08 + pulse * 0.06))
			"star":
				var twinkle = (sin(_time * 2.0 + dec["extra"]) + 1.0) * 0.5
				var alpha = dec["size"] * (0.4 + twinkle * 0.6)
				draw_circle(dec["pos"], 1.0 + twinkle * 0.8, Color(1.0, 0.97, 0.8, alpha))

	# === PATH â€” Wooden ship deck planks (brown wood) ===
	if enemy_path:
		var curve = enemy_path.curve
		if curve and curve.point_count > 0:
			var path_length = curve.get_baked_length()
			var prev_pt = curve.sample_baked(0.0)
			var step_count = int(path_length / 6.0)
			for pi in range(1, step_count + 1):
				var dist = float(pi) / float(step_count) * path_length
				var pt = curve.sample_baked(dist)
				# Main wood plank path
				draw_line(prev_pt, pt, Color(0.32, 0.2, 0.07, 0.85), 30.0)
				# Lighter plank edges
				draw_line(prev_pt, pt, Color(0.38, 0.24, 0.1, 0.3), 36.0)
				prev_pt = pt
			# Plank line details along path
			for pi in range(30):
				var pd = float(pi) / 29.0 * path_length
				var ppt = curve.sample_baked(pd)
				# Cross-plank lines (nail seams)
				var pdir = Vector2.ZERO
				if pd + 5.0 < path_length:
					pdir = (curve.sample_baked(pd + 5.0) - ppt).normalized()
				var perp = Vector2(-pdir.y, pdir.x)
				draw_line(ppt + perp * 12.0, ppt - perp * 12.0, Color(0.2, 0.12, 0.04, 0.3), 1.0)
				# Nail heads
				draw_circle(ppt + perp * 10.0, 1.2, Color(0.25, 0.25, 0.2, 0.35))
				draw_circle(ppt - perp * 10.0, 1.2, Color(0.25, 0.25, 0.2, 0.35))

	# === FOREGROUND ===
	# Rope and rigging in foreground (parallax feel)
	for fi in range(5):
		var rope_x = 50.0 + float(fi) * 300.0
		var rope_sway = sin(_time * 0.5 + float(fi) * 1.2) * 8.0
		draw_line(Vector2(rope_x + rope_sway, 50), Vector2(rope_x + rope_sway * 0.3, deck_y), Color(0.2, 0.14, 0.06, 0.15), 2.0)

	# Cannon smoke puffs drifting across foreground
	for si in range(4):
		var smoke_phase = _time * 0.3 + float(si) * 1.5
		var smoke_x = fmod(absf(smoke_phase) * 80.0, 1400.0) - 60.0
		var smoke_y = 200.0 + float(si) * 80.0 + sin(smoke_phase) * 20.0
		var smoke_alpha = 0.04 + sin(smoke_phase * 0.5) * 0.02
		smoke_alpha = clampf(smoke_alpha, 0.0, 0.1)
		draw_circle(Vector2(smoke_x, smoke_y), 35.0 + sin(float(si) * 2.1) * 10.0, Color(0.4, 0.35, 0.3, smoke_alpha))
		draw_circle(Vector2(smoke_x + 20, smoke_y - 10), 25.0, Color(0.45, 0.4, 0.35, smoke_alpha * 0.7))

	# Water splashes at hull line
	for wi in range(12):
		var wx = 100.0 + float(wi) * 95.0
		var splash_t = sin(_time * 1.5 + float(wi) * 0.9)
		if splash_t > 0.5:
			var splash_h = (splash_t - 0.5) * 8.0
			draw_circle(Vector2(wx, water_y - splash_h), 2.5, Color(0.4, 0.5, 0.7, 0.2))

	# Dark vignette at edges for dramatic battle atmosphere
	for vi in range(10):
		var v_alpha = 0.03 * float(10 - vi)
		# Left edge
		draw_rect(Rect2(0, 50, float(vi) * 8, 578), Color(0.02, 0.01, 0.03, v_alpha))
		# Right edge
		draw_rect(Rect2(1280.0 - float(vi) * 8.0, 50, float(vi) * 8, 578), Color(0.02, 0.01, 0.03, v_alpha))

	# Sparks from battle (foreground particles)
	for spi in range(6):
		var sp_phase = _time * 2.0 + float(spi) * 1.1
		var sp_x = 300.0 + float(spi) * 130.0 + sin(sp_phase * 0.7) * 50.0
		var sp_y = 150.0 + fmod(absf(sp_phase * 40.0), 300.0)
		var sp_bright = clampf(1.0 - fmod(absf(sp_phase * 40.0), 300.0) / 300.0, 0.0, 1.0)
		draw_circle(Vector2(sp_x, sp_y), 1.0, Color(1.0, 0.7, 0.2, sp_bright * 0.4))

func _draw_phantom_ch2(sky_color: Color, ground_color: Color) -> void:
	# === CEILING / SKY â€” Dark underground brick tunnel ceiling ===
	for y_strip in range(0, 300, 4):
		var t = float(y_strip) / 300.0
		var ceiling_col = sky_color.lerp(Color(0.06, 0.04, 0.08, 1.0), t)
		# Subtle moisture shimmer on ceiling
		var moisture = sin(_time * 0.8 + float(y_strip) * 0.05) * 0.015
		ceiling_col = ceiling_col.lerp(Color(0.15, 0.18, 0.25), clampf(moisture, 0.0, 1.0))
		draw_rect(Rect2(0, 50 + y_strip, 1280, 4), ceiling_col)

	# === CEILING BRICKWORK â€” visible arched tunnel ceiling ===
	for bx in range(0, 1280, 48):
		for by in range(0, 5):
			var offset_x = 24.0 if by % 2 == 1 else 0.0
			var brick_y = 52.0 + float(by) * 18.0
			var brick_alpha = 0.12 - float(by) * 0.02
			draw_rect(Rect2(float(bx) + offset_x, brick_y, 46, 16), Color(0.25, 0.15, 0.1, brick_alpha))
			draw_line(Vector2(float(bx) + offset_x, brick_y), Vector2(float(bx) + offset_x + 46.0, brick_y), Color(0.1, 0.06, 0.04, brick_alpha * 0.7), 0.5)

	# === WATER DRIPPING FROM CEILING â€” animated droplets ===
	for i in range(18):
		var drip_x = 70.0 + float(i) * 68.0
		var drip_phase = fmod(_time * 0.7 + float(i) * 2.3, 3.0)
		var drip_start_y = 55.0 + sin(float(i) * 1.1) * 15.0
		if drip_phase < 2.0:
			# Droplet falling
			var drip_y = drip_start_y + drip_phase * 120.0
			var drop_alpha = 0.4 - drip_phase * 0.15
			draw_circle(Vector2(drip_x, drip_y), 1.5, Color(0.3, 0.4, 0.6, clampf(drop_alpha, 0.0, 1.0)))
			# Tiny trail
			draw_line(Vector2(drip_x, drip_y - 4.0), Vector2(drip_x, drip_y), Color(0.3, 0.4, 0.6, clampf(drop_alpha * 0.5, 0.0, 1.0)), 0.8)
		else:
			# Splash ripple at bottom
			var splash_t = (drip_phase - 2.0) * 3.0
			var splash_y = drip_start_y + 240.0
			var ripple_r = splash_t * 8.0
			draw_arc(Vector2(drip_x, splash_y), ripple_r, 0.0, TAU, 12, Color(0.3, 0.4, 0.6, clampf(0.3 - splash_t * 0.3, 0.0, 1.0)), 0.5)
		# Gathering droplet on ceiling
		var gather = sin(_time * 1.2 + float(i) * 3.0) * 0.3 + 0.5
		draw_circle(Vector2(drip_x, drip_start_y), 1.0 + gather, Color(0.3, 0.45, 0.65, 0.2))

	# === ATMOSPHERE â€” Underground haze and candlelight glow ===
	for i in range(8):
		var haze_x = 160.0 * float(i) + sin(_time * 0.15 + float(i)) * 30.0
		var haze_y = 250.0 + cos(_time * 0.2 + float(i) * 0.7) * 40.0
		draw_circle(Vector2(haze_x, haze_y), 90.0, Color(0.2, 0.15, 0.1, 0.025))
		draw_circle(Vector2(haze_x, haze_y), 55.0, Color(1.0, 0.7, 0.2, 0.015))

	# Candlelight pools on walls â€” flickering warm light
	for i in range(10):
		var cx = 60.0 + float(i) * 128.0
		var cy = 180.0 + sin(float(i) * 2.5) * 30.0
		var flicker = sin(_time * 4.5 + float(i) * 1.9) * 0.1 + 0.5
		draw_circle(Vector2(cx, cy), 45.0, Color(1.0, 0.65, 0.15, 0.02 * flicker))
		# Candle on wall sconce
		draw_line(Vector2(cx, cy + 10.0), Vector2(cx, cy - 8.0), Color(0.8, 0.75, 0.6, 0.35), 2.5)
		draw_circle(Vector2(cx, cy - 10.0), 2.5 + flicker * 2.0, Color(1.0, 0.8, 0.2, 0.5 + flicker * 0.3))
		draw_circle(Vector2(cx, cy - 10.0), 8.0, Color(1.0, 0.6, 0.1, 0.06))

	# === LANDMARKS ===
	# --- Descending stone stairs (left side) ---
	for step in range(8):
		var sx = 30.0 + float(step) * 22.0
		var sy = 350.0 + float(step) * 20.0
		var step_w = 24.0
		var step_h = 18.0
		draw_rect(Rect2(sx, sy, step_w, step_h), Color(0.22, 0.18, 0.16, 0.55))
		draw_line(Vector2(sx, sy), Vector2(sx + step_w, sy), Color(0.35, 0.3, 0.25, 0.4), 1.0)
		# Step shadow
		draw_rect(Rect2(sx, sy + step_h - 3.0, step_w, 3.0), Color(0.05, 0.03, 0.02, 0.3))

	# --- Iron gates (two locations) ---
	for gi in range(2):
		var gate_x = 320.0 + float(gi) * 600.0
		var gate_top = 140.0
		var gate_bot = 380.0
		# Gate frame
		draw_rect(Rect2(gate_x - 2, gate_top, 4, gate_bot - gate_top), Color(0.2, 0.18, 0.15, 0.5))
		draw_rect(Rect2(gate_x + 40, gate_top, 4, gate_bot - gate_top), Color(0.2, 0.18, 0.15, 0.5))
		draw_line(Vector2(gate_x, gate_top), Vector2(gate_x + 44, gate_top), Color(0.25, 0.2, 0.18, 0.5), 3.0)
		# Vertical bars
		for bar in range(5):
			var bar_x = gate_x + 6.0 + float(bar) * 8.0
			draw_line(Vector2(bar_x, gate_top + 4.0), Vector2(bar_x, gate_bot), Color(0.3, 0.25, 0.2, 0.4), 1.5)
		# Horizontal crossbar
		var mid_y = (gate_top + gate_bot) * 0.5
		draw_line(Vector2(gate_x + 2, mid_y), Vector2(gate_x + 42, mid_y), Color(0.3, 0.25, 0.2, 0.35), 1.5)

	# --- Mirror hall with reflections (center-right) ---
	for mi in range(4):
		var mx = 650.0 + float(mi) * 80.0
		var my = 160.0 + float(mi) * 15.0
		var mw = 30.0
		var mh = 50.0
		# Mirror frame (ornate gold)
		draw_rect(Rect2(mx - 3, my - 3, mw + 6, mh + 6), Color(0.7, 0.55, 0.1, 0.35))
		# Mirror surface â€” dark reflective
		draw_rect(Rect2(mx, my, mw, mh), Color(0.06, 0.04, 0.1, 0.65))
		# Reflection shimmer
		var shimmer_off = sin(_time * 1.8 + float(mi) * 1.2) * 0.08
		draw_rect(Rect2(mx + 4.0, my + 5.0, 6.0, mh - 10.0), Color(0.4, 0.35, 0.5, 0.08 + shimmer_off))

	# --- Phantom's white mask in center mirror ---
	var mask_x = 730.0
	var mask_y = 185.0
	var mask_pulse = sin(_time * 1.2) * 0.05 + 0.3
	# Half-mask shape (right side of face)
	draw_circle(Vector2(mask_x, mask_y), 10.0, Color(0.95, 0.92, 0.88, mask_pulse))
	draw_rect(Rect2(mask_x - 5, mask_y - 8, 10, 5), Color(0.95, 0.92, 0.88, mask_pulse))
	# Eye hole
	draw_circle(Vector2(mask_x + 2, mask_y - 3), 2.0, Color(0.02, 0.01, 0.05, mask_pulse + 0.1))
	# Eerie glow behind mask
	draw_circle(Vector2(mask_x, mask_y), 25.0, Color(0.5, 0.4, 0.6, 0.03))

	# --- Visual sound waves (echoing through tunnels) ---
	for sw in range(5):
		var wave_cx = 500.0 + float(sw) * 10.0
		var wave_cy = 280.0
		var wave_r = 20.0 + float(sw) * 18.0 + sin(_time * 2.5 + float(sw)) * 5.0
		var wave_alpha = 0.08 - float(sw) * 0.015
		draw_arc(Vector2(wave_cx, wave_cy), wave_r, -0.5, 0.5, 16, Color(0.6, 0.5, 0.8, clampf(wave_alpha, 0.0, 1.0)), 0.8)

	# --- Rats scurrying along the floor ---
	for ri in range(6):
		var rat_base_x = 100.0 + float(ri) * 190.0
		var rat_y = 510.0 + sin(float(ri) * 3.0) * 15.0
		var rat_run = fmod(_time * 1.5 + float(ri) * 4.0, 8.0)
		var rat_x = rat_base_x + rat_run * 20.0
		var rat_dir = 1.0 if ri % 2 == 0 else -1.0
		# Body
		draw_circle(Vector2(rat_x, rat_y), 3.0, Color(0.25, 0.2, 0.15, 0.4))
		# Head
		draw_circle(Vector2(rat_x + rat_dir * 4.0, rat_y - 1.0), 1.8, Color(0.28, 0.22, 0.16, 0.4))
		# Tail
		var tail_wave = sin(_time * 8.0 + float(ri) * 2.0) * 2.0
		draw_line(Vector2(rat_x - rat_dir * 3.0, rat_y), Vector2(rat_x - rat_dir * 9.0, rat_y - 2.0 + tail_wave), Color(0.3, 0.22, 0.15, 0.3), 0.7)

	# === TUNNEL WALLS â€” brick texture on sides ===
	for side in range(2):
		var wall_x = 0.0 if side == 0 else 1240.0
		var wall_w = 40.0
		for wy in range(0, 20):
			var brick_y2 = 140.0 + float(wy) * 25.0
			var off = 15.0 if wy % 2 == 1 else 0.0
			draw_rect(Rect2(wall_x + off, brick_y2, wall_w - 2, 23), Color(0.28, 0.16, 0.1, 0.25))
			draw_line(Vector2(wall_x, brick_y2), Vector2(wall_x + wall_w, brick_y2), Color(0.15, 0.08, 0.05, 0.15), 0.5)

	# === FLOOR â€” Wet stone tunnel floor with water reflections ===
	for y_strip in range(0, 148, 3):
		var t = float(y_strip) / 148.0
		var floor_col = ground_color.lerp(Color(0.12, 0.1, 0.13), t)
		# Water reflection ripples
		var water_ref = sin(_time * 1.5 + float(y_strip) * 0.15) * 0.02
		floor_col = floor_col.lerp(Color(0.2, 0.25, 0.35), clampf(absf(water_ref), 0.0, 1.0))
		draw_rect(Rect2(0, 480 + y_strip, 1280, 3), floor_col)

	# Wet stone floor â€” tile lines
	for fx in range(0, 1280, 64):
		for fy in range(0, 3):
			var tile_y = 485.0 + float(fy) * 48.0
			draw_line(Vector2(float(fx), tile_y), Vector2(float(fx) + 62.0, tile_y), Color(0.18, 0.14, 0.12, 0.12), 0.5)
		draw_line(Vector2(float(fx), 480.0), Vector2(float(fx), 628.0), Color(0.18, 0.14, 0.12, 0.08), 0.5)

	# Water puddle reflections on floor
	for pi in range(7):
		var px = 90.0 + float(pi) * 170.0
		var py = 530.0 + sin(float(pi) * 1.7) * 25.0
		var puddle_w = 30.0 + sin(float(pi) * 2.3) * 10.0
		var puddle_ripple = sin(_time * 2.0 + float(pi) * 1.5) * 0.03
		draw_rect(Rect2(px - puddle_w * 0.5, py - 3.0, puddle_w, 6.0), Color(0.15, 0.2, 0.3, 0.12 + puddle_ripple))

	# === DECORATIONS ===
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
			"sheet_music":
				var smp = dec["pos"]
				var sms = dec["size"]
				var drift = sin(_time * 0.6 + dec["extra"]) * 5.0
				draw_rect(Rect2(smp.x - sms + drift, smp.y - sms * 1.5, sms * 2, sms * 3), Color(0.85, 0.82, 0.7, 0.2))
				for line_idx in range(5):
					draw_line(Vector2(smp.x - sms + drift, smp.y - sms + float(line_idx) * sms * 0.4), Vector2(smp.x + sms + drift, smp.y - sms + float(line_idx) * sms * 0.4), Color(0.2, 0.15, 0.1, 0.15), 0.5)

	# === PATH â€” Wet stone tunnel floor ===
	if enemy_path:
		var curve = enemy_path.curve
		if curve and curve.point_count > 1:
			var points = curve.tessellate(6, 2.0)
			# Dark stone path base
			for i in range(points.size() - 1):
				var from_pt = enemy_path.to_global(points[i])
				var to_pt = enemy_path.to_global(points[i + 1])
				draw_line(from_pt, to_pt, Color(0.15, 0.12, 0.14, 0.7), 38.0)
			# Lighter center with water sheen
			for i in range(points.size() - 1):
				var from_pt = enemy_path.to_global(points[i])
				var to_pt = enemy_path.to_global(points[i + 1])
				var water_sheen = sin(_time * 1.8 + float(i) * 0.3) * 0.04
				draw_line(from_pt, to_pt, Color(0.2, 0.22, 0.28, 0.3 + water_sheen), 22.0)
			# Stone edge lines
			for i in range(points.size() - 1):
				var from_pt = enemy_path.to_global(points[i])
				var to_pt = enemy_path.to_global(points[i + 1])
				var dir = (to_pt - from_pt).normalized()
				var perp = Vector2(-dir.y, dir.x)
				draw_line(from_pt + perp * 19.0, to_pt + perp * 19.0, Color(0.25, 0.2, 0.18, 0.2), 1.0)
				draw_line(from_pt - perp * 19.0, to_pt - perp * 19.0, Color(0.25, 0.2, 0.18, 0.2), 1.0)

	# === FOREGROUND â€” Dripping stalactites, dust motes, cobwebs ===
	# Stalactites hanging from top
	for i in range(12):
		var st_x = 50.0 + float(i) * 105.0
		var st_len = 20.0 + sin(float(i) * 2.7) * 12.0
		var st_top = 50.0
		draw_line(Vector2(st_x, st_top), Vector2(st_x, st_top + st_len), Color(0.2, 0.15, 0.12, 0.25), 3.0)
		draw_line(Vector2(st_x, st_top), Vector2(st_x, st_top + st_len), Color(0.25, 0.2, 0.15, 0.15), 1.0)
		# Drip at tip
		var drip_pulse = sin(_time * 2.0 + float(i) * 1.3)
		if drip_pulse > 0.7:
			draw_circle(Vector2(st_x, st_top + st_len + 2.0), 1.2, Color(0.3, 0.4, 0.55, 0.3))

	# Floating dust motes
	for i in range(20):
		var dx = fmod(float(i) * 137.5 + _time * 8.0 + sin(_time * 0.3 + float(i)) * 30.0, 1280.0)
		var dy = 100.0 + float(i) * 25.0 + sin(_time * 0.5 + float(i) * 0.8) * 15.0
		var mote_alpha = sin(_time * 1.5 + float(i) * 0.7) * 0.06 + 0.06
		draw_circle(Vector2(dx, dy), 1.0, Color(0.9, 0.8, 0.5, clampf(mote_alpha, 0.0, 1.0)))

	# Cobwebs in corners
	for corner in range(2):
		var web_x = 5.0 if corner == 0 else 1275.0
		var web_dir = 1.0 if corner == 0 else -1.0
		for strand in range(5):
			var angle = float(strand) * 0.3
			var end_x = web_x + web_dir * cos(angle) * 50.0
			var end_y = 50.0 + sin(angle) * 50.0
			draw_line(Vector2(web_x, 50.0), Vector2(end_x, end_y), Color(0.6, 0.6, 0.55, 0.08), 0.5)

	# Vignette darkness at edges
	for v in range(40):
		var v_alpha = (1.0 - float(v) / 40.0) * 0.15
		draw_rect(Rect2(0, 50 + v, float(v) * 0.5, 1), Color(0.0, 0.0, 0.0, v_alpha))
		draw_rect(Rect2(1280.0 - float(v) * 0.5, 50 + v, float(v) * 0.5, 1), Color(0.0, 0.0, 0.0, v_alpha))


func _draw_phantom_ch3(sky_color: Color, ground_color: Color) -> void:
	# === CEILING / SKY â€” Deep purple-black cavern roof ===
	for y_strip in range(0, 200, 3):
		var t = float(y_strip) / 200.0
		var ceiling_col = sky_color.lerp(Color(0.05, 0.02, 0.08, 1.0), t)
		# Faint golden candlelight reflecting on ceiling
		var candle_glow = sin(_time * 0.6 + float(y_strip) * 0.04) * 0.01
		ceiling_col = ceiling_col.lerp(Color(0.4, 0.25, 0.05), clampf(candle_glow, 0.0, 1.0))
		draw_rect(Rect2(0, 50 + y_strip, 1280, 3), ceiling_col)

	# Cavern rock texture on ceiling
	for i in range(25):
		var rock_x = float(i) * 52.0 + sin(float(i) * 1.7) * 15.0
		var rock_y = 55.0 + sin(float(i) * 2.3) * 10.0
		var rock_r = 8.0 + sin(float(i) * 3.1) * 4.0
		draw_circle(Vector2(rock_x, rock_y), rock_r, Color(0.08, 0.04, 0.06, 0.2))

	# === ATMOSPHERE â€” Golden candlelight and purple haze ===
	# Large ambient glow zones
	for i in range(6):
		var glow_x = 100.0 + float(i) * 200.0 + sin(_time * 0.2 + float(i) * 1.5) * 20.0
		var glow_y = 300.0 + cos(_time * 0.15 + float(i)) * 30.0
		draw_circle(Vector2(glow_x, glow_y), 120.0, Color(1.0, 0.7, 0.15, 0.012))
		draw_circle(Vector2(glow_x, glow_y), 60.0, Color(1.0, 0.6, 0.1, 0.02))

	# Purple mist rising from water
	for i in range(14):
		var mist_x = float(i) * 95.0 + sin(_time * 0.25 + float(i) * 0.8) * 25.0
		var mist_y = 420.0 + sin(_time * 0.3 + float(i) * 1.2) * 20.0
		draw_circle(Vector2(mist_x, mist_y), 50.0, Color(0.2, 0.08, 0.25, 0.025))

	# === LANDMARKS ===
	# --- Massive organ pipes towering overhead (center-left) ---
	var organ_base_x = 200.0
	for pipe in range(14):
		var pipe_x = organ_base_x + float(pipe) * 18.0
		var pipe_h = 180.0 + sin(float(pipe) * 0.8) * 80.0 + cos(float(pipe) * 0.5) * 30.0
		var pipe_w = 10.0 + sin(float(pipe) * 1.3) * 3.0
		var pipe_top = 60.0
		# Pipe body â€” dark bronze/gold
		draw_rect(Rect2(pipe_x - pipe_w * 0.5, pipe_top, pipe_w, pipe_h), Color(0.35, 0.28, 0.12, 0.35))
		# Pipe highlight
		draw_rect(Rect2(pipe_x - pipe_w * 0.25, pipe_top, pipe_w * 0.3, pipe_h), Color(0.5, 0.4, 0.15, 0.12))
		# Pipe top cap
		draw_rect(Rect2(pipe_x - pipe_w * 0.6, pipe_top, pipe_w * 1.2, 4.0), Color(0.4, 0.32, 0.1, 0.4))
		# Sound vibration from pipes
		if pipe % 3 == 0:
			var vib = sin(_time * 3.0 + float(pipe) * 1.5) * 2.0
			draw_arc(Vector2(pipe_x, pipe_top - 5.0), 6.0 + absf(vib), -1.0, -2.1, 8, Color(0.5, 0.4, 0.7, 0.06), 0.5)

	# --- Underground lake â€” black water reflecting candles ---
	var lake_top = 430.0
	for y_strip in range(0, 198, 3):
		var t = float(y_strip) / 198.0
		var water_col = Color(0.03, 0.02, 0.06, 0.85).lerp(Color(0.02, 0.01, 0.04, 0.9), t)
		# Candle reflections rippling in water
		var ripple1 = sin(_time * 1.2 + float(y_strip) * 0.08) * 0.015
		var ripple2 = sin(_time * 0.9 + float(y_strip) * 0.12 + 2.0) * 0.01
		water_col = water_col.lerp(Color(1.0, 0.7, 0.15), clampf(ripple1 + ripple2, 0.0, 1.0))
		draw_rect(Rect2(0, lake_top + float(y_strip), 1280, 3), water_col)

	# Water surface ripples
	for i in range(10):
		var rip_x = 60.0 + float(i) * 125.0
		var rip_y = lake_top + 5.0 + sin(_time * 0.7 + float(i) * 1.3) * 3.0
		var rip_w = 30.0 + sin(float(i) * 2.1) * 10.0
		draw_line(Vector2(rip_x - rip_w, rip_y), Vector2(rip_x + rip_w, rip_y), Color(0.2, 0.15, 0.25, 0.12), 0.7)

	# Candle reflections in water â€” inverted/distorted golden streaks
	for i in range(8):
		var ref_x = 80.0 + float(i) * 155.0
		var ref_base = lake_top + 15.0
		var ref_len = 40.0 + sin(float(i) * 1.7) * 15.0
		var ref_wave = sin(_time * 1.5 + float(i) * 2.0) * 3.0
		draw_line(Vector2(ref_x + ref_wave, ref_base), Vector2(ref_x - ref_wave, ref_base + ref_len), Color(1.0, 0.7, 0.15, 0.06), 3.0)

	# --- Phantom's mask and cape center-stage ---
	var phantom_x = 640.0
	var phantom_y = 300.0
	var phantom_sway = sin(_time * 0.8) * 3.0

	# Cape â€” sweeping black fabric
	var cape_pts = PackedVector2Array()
	cape_pts.append(Vector2(phantom_x - 5.0 + phantom_sway, phantom_y - 30.0))
	cape_pts.append(Vector2(phantom_x - 40.0 + phantom_sway * 0.5, phantom_y + 60.0))
	cape_pts.append(Vector2(phantom_x - 25.0, phantom_y + 80.0))
	cape_pts.append(Vector2(phantom_x + 25.0, phantom_y + 80.0))
	cape_pts.append(Vector2(phantom_x + 40.0 + phantom_sway * 0.5, phantom_y + 60.0))
	cape_pts.append(Vector2(phantom_x + 5.0 + phantom_sway, phantom_y - 30.0))
	var cape_cols = PackedColorArray()
	for _ci in range(cape_pts.size()):
		cape_cols.append(Color(0.02, 0.01, 0.04, 0.5))
	draw_polygon(cape_pts, cape_cols)
	# Cape inner lining â€” dark red
	draw_line(Vector2(phantom_x - 35.0 + phantom_sway, phantom_y + 50.0), Vector2(phantom_x - 15.0, phantom_y + 75.0), Color(0.4, 0.05, 0.05, 0.25), 3.0)

	# Mask â€” white half-mask, iconic
	var mask_glow = sin(_time * 1.0) * 0.06 + 0.45
	draw_circle(Vector2(phantom_x + phantom_sway, phantom_y - 15.0), 14.0, Color(0.96, 0.93, 0.88, mask_glow))
	# Mask shaping â€” right half only
	draw_rect(Rect2(phantom_x + phantom_sway - 8, phantom_y - 28, 16, 8), Color(0.96, 0.93, 0.88, mask_glow))
	# Eye socket
	draw_circle(Vector2(phantom_x + phantom_sway + 3.0, phantom_y - 18.0), 3.0, Color(0.02, 0.01, 0.05, mask_glow + 0.15))
	# Eerie glow around phantom
	draw_circle(Vector2(phantom_x + phantom_sway, phantom_y), 50.0, Color(0.3, 0.15, 0.4, 0.025))

	# --- Monkey music box (right of phantom) ---
	var monkey_x = 850.0
	var monkey_y = 380.0
	# Box base
	draw_rect(Rect2(monkey_x - 15, monkey_y, 30, 20), Color(0.4, 0.25, 0.08, 0.4))
	draw_rect(Rect2(monkey_x - 13, monkey_y + 2, 26, 16), Color(0.5, 0.32, 0.1, 0.3))
	# Monkey figure
	draw_circle(Vector2(monkey_x, monkey_y - 6.0), 6.0, Color(0.35, 0.22, 0.1, 0.4))
	draw_circle(Vector2(monkey_x, monkey_y - 14.0), 4.5, Color(0.38, 0.25, 0.12, 0.4))
	# Cymbals â€” animated clapping
	var cymbal_angle = sin(_time * 4.0) * 0.4
	draw_circle(Vector2(monkey_x - 7.0 - cymbal_angle * 3.0, monkey_y - 10.0), 3.0, Color(0.7, 0.55, 0.1, 0.35))
	draw_circle(Vector2(monkey_x + 7.0 + cymbal_angle * 3.0, monkey_y - 10.0), 3.0, Color(0.7, 0.55, 0.1, 0.35))

	# --- Christine's wedding veil (left of phantom) ---
	var veil_x = 430.0
	var veil_y = 310.0
	var veil_drift = sin(_time * 0.5) * 4.0
	# Veil fabric â€” translucent white flowing
	for vi in range(6):
		var v_off_x = sin(_time * 0.7 + float(vi) * 0.9) * 5.0 + veil_drift
		var v_off_y = float(vi) * 12.0
		var v_width = 15.0 + float(vi) * 4.0
		var v_alpha = 0.15 - float(vi) * 0.02
		draw_line(Vector2(veil_x - v_width + v_off_x, veil_y + v_off_y), Vector2(veil_x + v_width + v_off_x, veil_y + v_off_y), Color(0.95, 0.93, 0.9, clampf(v_alpha, 0.0, 1.0)), 2.0)
	# Veil top crown/tiara
	draw_circle(Vector2(veil_x + veil_drift, veil_y - 5.0), 4.0, Color(0.85, 0.8, 0.75, 0.2))
	for ti in range(3):
		var tiara_x = veil_x + veil_drift + float(ti - 1) * 5.0
		draw_line(Vector2(tiara_x, veil_y - 5.0), Vector2(tiara_x, veil_y - 10.0 - float(1 - absi(ti - 1)) * 3.0), Color(0.8, 0.7, 0.4, 0.25), 1.0)

	# --- Roses scattered throughout ---
	for ri in range(12):
		var rose_x = 50.0 + float(ri) * 105.0 + sin(float(ri) * 3.7) * 30.0
		var rose_y = 400.0 + sin(float(ri) * 2.1) * 25.0
		var rose_size = 3.5 + sin(float(ri) * 1.9) * 1.5
		draw_circle(Vector2(rose_x, rose_y), rose_size, Color(0.85, 0.08, 0.08, 0.45))
		draw_circle(Vector2(rose_x, rose_y), rose_size * 0.5, Color(0.95, 0.15, 0.12, 0.35))
		# Stem
		draw_line(Vector2(rose_x, rose_y + rose_size), Vector2(rose_x + 3.0, rose_y + rose_size + 10.0), Color(0.15, 0.35, 0.1, 0.25), 0.8)

	# === FLOOR â€” Stone walkway over water ===
	# The walkway is a narrow stone bridge across the lake
	for y_strip in range(0, 30, 3):
		var t = float(y_strip) / 30.0
		var walkway_col = ground_color.lerp(Color(0.18, 0.14, 0.12), t)
		draw_rect(Rect2(200, 485 + y_strip, 880, 3), walkway_col)

	# Walkway stone texture
	for sx in range(0, 880, 44):
		var stone_x = 200.0 + float(sx)
		draw_line(Vector2(stone_x, 485.0), Vector2(stone_x, 515.0), Color(0.25, 0.2, 0.18, 0.12), 0.5)
	for sy in range(0, 2):
		draw_line(Vector2(200.0, 495.0 + float(sy) * 12.0), Vector2(1080.0, 495.0 + float(sy) * 12.0), Color(0.25, 0.2, 0.18, 0.1), 0.5)

	# Walkway edges â€” stone railing
	draw_line(Vector2(200.0, 485.0), Vector2(1080.0, 485.0), Color(0.3, 0.25, 0.2, 0.3), 2.0)
	draw_line(Vector2(200.0, 515.0), Vector2(1080.0, 515.0), Color(0.3, 0.25, 0.2, 0.3), 2.0)

	# Water visible on sides of walkway
	for side in range(2):
		var water_x = 0.0 if side == 0 else 1080.0
		var water_w = 200.0 if side == 0 else 200.0
		for wy in range(0, 50, 4):
			var ripple = sin(_time * 1.0 + float(wy) * 0.15 + float(side) * 2.0) * 0.01
			draw_rect(Rect2(water_x, 485.0 + float(wy), water_w, 4), Color(0.03, 0.02, 0.06, 0.5 + ripple))

	# === DECORATIONS ===
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
			"sheet_music":
				var smp = dec["pos"]
				var sms = dec["size"]
				var drift = sin(_time * 0.6 + dec["extra"]) * 5.0
				draw_rect(Rect2(smp.x - sms + drift, smp.y - sms * 1.5, sms * 2, sms * 3), Color(0.85, 0.82, 0.7, 0.2))
				for line_idx in range(5):
					draw_line(Vector2(smp.x - sms + drift, smp.y - sms + float(line_idx) * sms * 0.4), Vector2(smp.x + sms + drift, smp.y - sms + float(line_idx) * sms * 0.4), Color(0.2, 0.15, 0.1, 0.15), 0.5)

	# === PATH â€” Stone walkway over underground lake ===
	if enemy_path:
		var curve = enemy_path.curve
		if curve and curve.point_count > 1:
			var points = curve.tessellate(6, 2.0)
			# Water beneath path â€” dark reflective
			for i in range(points.size() - 1):
				var from_pt = enemy_path.to_global(points[i])
				var to_pt = enemy_path.to_global(points[i + 1])
				draw_line(from_pt, to_pt, Color(0.03, 0.02, 0.06, 0.6), 50.0)
			# Stone walkway base
			for i in range(points.size() - 1):
				var from_pt = enemy_path.to_global(points[i])
				var to_pt = enemy_path.to_global(points[i + 1])
				draw_line(from_pt, to_pt, Color(0.22, 0.18, 0.16, 0.65), 34.0)
			# Walkway surface â€” lighter stone
			for i in range(points.size() - 1):
				var from_pt = enemy_path.to_global(points[i])
				var to_pt = enemy_path.to_global(points[i + 1])
				draw_line(from_pt, to_pt, Color(0.28, 0.24, 0.2, 0.4), 24.0)
			# Candlelight reflections on path edges
			for i in range(0, points.size() - 1, 4):
				var from_pt = enemy_path.to_global(points[i])
				var glow_pulse = sin(_time * 2.0 + float(i) * 0.5) * 0.02
				draw_circle(from_pt, 20.0, Color(1.0, 0.65, 0.1, 0.015 + glow_pulse))
			# Edge lines
			for i in range(points.size() - 1):
				var from_pt = enemy_path.to_global(points[i])
				var to_pt = enemy_path.to_global(points[i + 1])
				var dir = (to_pt - from_pt).normalized()
				var perp = Vector2(-dir.y, dir.x)
				draw_line(from_pt + perp * 17.0, to_pt + perp * 17.0, Color(0.3, 0.22, 0.15, 0.25), 1.5)
				draw_line(from_pt - perp * 17.0, to_pt - perp * 17.0, Color(0.3, 0.22, 0.15, 0.25), 1.5)

	# === FOREGROUND â€” Floating candles, mist, rose petals falling ===
	# Floating candles on lake surface (foreground layer)
	for i in range(9):
		var fc_x = 70.0 + float(i) * 140.0 + sin(_time * 0.4 + float(i) * 1.7) * 15.0
		var fc_y = 540.0 + sin(_time * 0.6 + float(i) * 2.1) * 5.0
		# Candle body
		draw_rect(Rect2(fc_x - 2, fc_y - 10, 4, 10), Color(0.85, 0.8, 0.7, 0.35))
		# Flame
		var fc_flicker = sin(_time * 6.0 + float(i) * 2.3) * 1.5
		draw_circle(Vector2(fc_x, fc_y - 12.0 + fc_flicker), 2.5, Color(1.0, 0.8, 0.2, 0.55))
		draw_circle(Vector2(fc_x, fc_y - 12.0 + fc_flicker), 10.0, Color(1.0, 0.6, 0.1, 0.03))
		# Reflection in water below
		draw_line(Vector2(fc_x, fc_y + 2.0), Vector2(fc_x + sin(_time * 1.0 + float(i)) * 2.0, fc_y + 18.0), Color(1.0, 0.7, 0.15, 0.04), 2.0)

	# Falling rose petals
	for i in range(15):
		var petal_x = fmod(float(i) * 89.0 + _time * 12.0 + sin(_time * 0.4 + float(i) * 1.5) * 40.0, 1280.0)
		var petal_y = fmod(float(i) * 43.0 + _time * 18.0, 578.0) + 50.0
		var petal_rot = _time * 2.0 + float(i) * 1.3
		var petal_size = 2.0 + sin(float(i) * 2.5) * 0.8
		var px_off = cos(petal_rot) * petal_size
		var py_off = sin(petal_rot) * petal_size * 0.5
		draw_circle(Vector2(petal_x + px_off, petal_y + py_off), petal_size, Color(0.8, 0.1, 0.1, 0.18))

	# Low mist / fog across foreground
	for i in range(10):
		var fog_x = float(i) * 130.0 + sin(_time * 0.15 + float(i) * 0.6) * 40.0
		var fog_y = 580.0 + sin(_time * 0.3 + float(i) * 1.1) * 10.0
		draw_circle(Vector2(fog_x, fog_y), 70.0, Color(0.12, 0.06, 0.15, 0.03))
		draw_circle(Vector2(fog_x + 30.0, fog_y - 5.0), 45.0, Color(0.15, 0.08, 0.18, 0.025))

	# Musical notes floating up from the organ
	for i in range(7):
		var note_x = 220.0 + float(i) * 30.0 + sin(_time * 1.2 + float(i) * 1.8) * 15.0
		var note_y = 200.0 - fmod(_time * 15.0 + float(i) * 40.0, 180.0)
		var note_alpha = 0.12 - fmod(_time * 0.05 + float(i) * 0.15, 0.12)
		if note_y > 55.0:
			draw_circle(Vector2(note_x, note_y), 2.5, Color(0.7, 0.55, 0.9, clampf(note_alpha, 0.0, 1.0)))
			draw_line(Vector2(note_x + 2.5, note_y), Vector2(note_x + 2.5, note_y - 8.0), Color(0.7, 0.55, 0.9, clampf(note_alpha * 0.8, 0.0, 1.0)), 0.7)

	# Vignette â€” deep darkness at edges for dramatic framing
	for v in range(60):
		var v_alpha = (1.0 - float(v) / 60.0) * 0.2
		draw_rect(Rect2(0, 50 + v, float(v) * 0.8, 1), Color(0.0, 0.0, 0.0, v_alpha))
		draw_rect(Rect2(1280.0 - float(v) * 0.8, 50 + v, float(v) * 0.8, 1), Color(0.0, 0.0, 0.0, v_alpha))
		# Bottom vignette
		var bv_y = 628 - v
		draw_rect(Rect2(0, bv_y, 1280, 1), Color(0.0, 0.0, 0.0, v_alpha * 0.5))

func _draw_scrooge_ch2(sky_color: Color, ground_color: Color) -> void:
	# === SKY GRADIENT â€” Midnight spectral blue ===
	var midnight_base := Color(0.03, 0.04, 0.08)
	var spectral_blue := Color(0.05, 0.12, 0.2)
	for i in range(30):
		var t := float(i) / 29.0
		var band_color := midnight_base.lerp(spectral_blue, t * t)
		# Pulsing spectral glow across the whole sky
		var spectral_pulse := sin(_time * 0.4 + t * 3.0) * 0.02
		band_color.g += spectral_pulse
		band_color.b += spectral_pulse * 1.5
		var y_start := t * 300.0
		var y_height := 300.0 / 29.0 + 2.0
		draw_rect(Rect2(0, y_start, 1280, y_height), band_color)

	# === ATMOSPHERE â€” Spectral green/blue mist ===
	for i in range(12):
		var mx := float(i) * 110.0 + sin(_time * 0.3 + float(i)) * 30.0
		var my := 250.0 + sin(_time * 0.2 + float(i) * 0.7) * 40.0
		var mrad := 80.0 + sin(_time * 0.5 + float(i) * 1.3) * 20.0
		var green_tint := 0.15 + sin(_time * 0.6 + float(i)) * 0.05
		draw_circle(Vector2(mx, my), mrad, Color(0.1, green_tint, 0.2, 0.03))

	# Spectral aurora ribbons in upper sky
	for i in range(5):
		var ribbon_y := 60.0 + float(i) * 35.0
		var pts := PackedVector2Array()
		for s in range(20):
			var sx := float(s) * 68.0
			var sy := ribbon_y + sin(_time * 0.3 + float(s) * 0.5 + float(i)) * 15.0
			pts.append(Vector2(sx, sy))
		for s in range(pts.size() - 1):
			var ribbon_alpha := 0.04 + sin(_time * 0.4 + float(s) * 0.3) * 0.02
			draw_line(pts[s], pts[s + 1], Color(0.15, 0.4, 0.3, ribbon_alpha), 2.0)

	# === MOON â€” Pale ghostly moon ===
	var moon_pos := Vector2(950, 80)
	draw_circle(moon_pos, 35.0, Color(0.6, 0.65, 0.75, 0.15))
	draw_circle(moon_pos, 22.0, Color(0.7, 0.75, 0.85, 0.25))
	draw_circle(moon_pos, 12.0, Color(0.85, 0.88, 0.95, 0.4))

	# === CHURCH STEEPLE AT MIDNIGHT â€” far background ===
	var church_x := 180.0
	var church_base_y := 320.0
	# Main church body
	draw_rect(Rect2(church_x - 40, church_base_y - 100, 80, 100), Color(0.06, 0.06, 0.1, 0.7))
	# Steeple
	var steeple_pts := PackedVector2Array([
		Vector2(church_x - 20, church_base_y - 100),
		Vector2(church_x, church_base_y - 180),
		Vector2(church_x + 20, church_base_y - 100)
	])
	draw_colored_polygon(steeple_pts, Color(0.05, 0.05, 0.09, 0.8))
	# Cross on top
	draw_line(Vector2(church_x, church_base_y - 180), Vector2(church_x, church_base_y - 200), Color(0.3, 0.3, 0.35, 0.6), 2.0)
	draw_line(Vector2(church_x - 8, church_base_y - 192), Vector2(church_x + 8, church_base_y - 192), Color(0.3, 0.3, 0.35, 0.6), 2.0)
	# Clock face â€” midnight
	draw_circle(Vector2(church_x, church_base_y - 70), 12.0, Color(0.15, 0.15, 0.2, 0.5))
	draw_circle(Vector2(church_x, church_base_y - 70), 10.0, Color(0.6, 0.6, 0.55, 0.3))
	draw_line(Vector2(church_x, church_base_y - 70), Vector2(church_x, church_base_y - 80), Color(0.1, 0.1, 0.1, 0.5), 1.5)
	# Arched window glow
	draw_circle(Vector2(church_x, church_base_y - 45), 8.0, Color(0.2, 0.5, 0.4, 0.15))

	# === GHOST OF CHRISTMAS PAST â€” Golden sphere, upper left ===
	var past_x := 300.0 + sin(_time * 0.7) * 20.0
	var past_y := 140.0 + sin(_time * 0.5) * 15.0
	var past_glow := 0.3 + sin(_time * 2.0) * 0.1
	draw_circle(Vector2(past_x, past_y), 30.0, Color(1.0, 0.85, 0.3, 0.05))
	draw_circle(Vector2(past_x, past_y), 18.0, Color(1.0, 0.8, 0.2, 0.1))
	draw_circle(Vector2(past_x, past_y), 10.0, Color(1.0, 0.9, 0.5, past_glow))
	# Rays emanating
	for r in range(8):
		var ray_angle := float(r) * PI * 0.25 + _time * 0.3
		var ray_end := Vector2(past_x, past_y) + Vector2.from_angle(ray_angle) * (25.0 + sin(_time * 3.0 + float(r)) * 5.0)
		draw_line(Vector2(past_x, past_y), ray_end, Color(1.0, 0.85, 0.3, 0.08), 1.0)

	# === GHOST OF CHRISTMAS PRESENT â€” Jolly silhouette with holly crown ===
	var present_x := 700.0 + sin(_time * 0.4) * 10.0
	var present_y := 200.0
	# Large robed body
	var robe_pts := PackedVector2Array([
		Vector2(present_x - 25, present_y + 60),
		Vector2(present_x - 30, present_y),
		Vector2(present_x - 15, present_y - 40),
		Vector2(present_x, present_y - 50),
		Vector2(present_x + 15, present_y - 40),
		Vector2(present_x + 30, present_y),
		Vector2(present_x + 25, present_y + 60)
	])
	draw_colored_polygon(robe_pts, Color(0.1, 0.35, 0.15, 0.2))
	# Holly crown
	for h in range(5):
		var holly_angle := -PI * 0.3 + float(h) * 0.3
		var hx := present_x + cos(holly_angle) * 18.0
		var hy := present_y - 50.0 + sin(holly_angle) * 5.0 - 5.0
		draw_circle(Vector2(hx, hy), 3.0, Color(0.15, 0.5, 0.1, 0.3))
	# Holly berries
	draw_circle(Vector2(present_x - 5, present_y - 56), 2.0, Color(0.7, 0.1, 0.1, 0.3))
	draw_circle(Vector2(present_x + 5, present_y - 56), 2.0, Color(0.7, 0.1, 0.1, 0.3))

	# === TOMBSTONES â€” Graveyard ===
	var tombstones := [
		{"x": 400.0, "h": 50.0, "w": 28.0}, {"x": 520.0, "h": 42.0, "w": 24.0},
		{"x": 640.0, "h": 55.0, "w": 30.0}, {"x": 780.0, "h": 38.0, "w": 22.0},
		{"x": 880.0, "h": 48.0, "w": 26.0}, {"x": 1020.0, "h": 44.0, "w": 25.0},
		{"x": 1140.0, "h": 40.0, "w": 23.0}, {"x": 340.0, "h": 36.0, "w": 20.0}
	]
	var grave_y := 420.0
	for ts_data in tombstones:
		var tx: float = ts_data["x"]
		var th: float = ts_data["h"]
		var tw: float = ts_data["w"]
		# Tombstone body
		draw_rect(Rect2(tx - tw * 0.5, grave_y - th, tw, th), Color(0.18, 0.17, 0.2, 0.5))
		# Rounded top
		draw_circle(Vector2(tx, grave_y - th), tw * 0.5, Color(0.18, 0.17, 0.2, 0.5))
		# Spectral glow behind each stone
		var ts_glow := sin(_time * 0.8 + tx * 0.01) * 0.03
		draw_circle(Vector2(tx, grave_y - th * 0.5), tw * 1.2, Color(0.15, 0.4, 0.3, 0.04 + ts_glow))

	# === "EBENEZER SCROOGE" TOMBSTONE â€” prominent center ===
	var eb_x := 640.0
	var eb_y := 380.0
	var eb_w := 50.0
	var eb_h := 75.0
	draw_rect(Rect2(eb_x - eb_w * 0.5, eb_y - eb_h, eb_w, eb_h), Color(0.2, 0.19, 0.22, 0.65))
	draw_circle(Vector2(eb_x, eb_y - eb_h), eb_w * 0.5, Color(0.2, 0.19, 0.22, 0.65))
	# Engraved text lines (small horizontal marks suggesting letters)
	for line_i in range(3):
		var line_y2 := eb_y - eb_h + 20.0 + float(line_i) * 12.0
		var line_w2 := eb_w * (0.7 - float(line_i) * 0.1)
		draw_line(Vector2(eb_x - line_w2 * 0.5, line_y2), Vector2(eb_x + line_w2 * 0.5, line_y2), Color(0.35, 0.33, 0.38, 0.4), 1.5)
	# Eerie glow around Scrooge's tombstone
	var eb_glow := 0.06 + sin(_time * 1.2) * 0.03
	draw_circle(Vector2(eb_x, eb_y - eb_h * 0.5), 60.0, Color(0.2, 0.6, 0.4, eb_glow))

	# === GHOSTLY FIGURES RISING FROM GRAVES ===
	for gi in range(4):
		var ghost_x := 420.0 + float(gi) * 200.0
		var rise_offset := sin(_time * 0.6 + float(gi) * 1.5) * 12.0
		var ghost_base_y := 400.0 + rise_offset
		var ghost_alpha := 0.08 + sin(_time * 0.9 + float(gi) * 2.0) * 0.04
		# Wispy body shape
		var ghost_pts := PackedVector2Array([
			Vector2(ghost_x - 10, ghost_base_y),
			Vector2(ghost_x - 14, ghost_base_y - 25),
			Vector2(ghost_x - 8, ghost_base_y - 45),
			Vector2(ghost_x, ghost_base_y - 55 + rise_offset * 0.3),
			Vector2(ghost_x + 8, ghost_base_y - 45),
			Vector2(ghost_x + 14, ghost_base_y - 25),
			Vector2(ghost_x + 10, ghost_base_y)
		])
		draw_colored_polygon(ghost_pts, Color(0.5, 0.7, 0.6, ghost_alpha))
		# Eyes
		draw_circle(Vector2(ghost_x - 3, ghost_base_y - 45), 1.5, Color(0.7, 0.9, 0.8, ghost_alpha * 2.0))
		draw_circle(Vector2(ghost_x + 3, ghost_base_y - 45), 1.5, Color(0.7, 0.9, 0.8, ghost_alpha * 2.0))

	# === FLOATING CHAINS (animated) ===
	for ci in range(6):
		var chain_start_x := 150.0 + float(ci) * 190.0
		var chain_y_base := 280.0 + sin(_time * 0.7 + float(ci) * 1.1) * 25.0
		var chain_sway := sin(_time * 1.2 + float(ci) * 0.8) * 15.0
		for link in range(6):
			var lx := chain_start_x + chain_sway * (float(link) / 5.0) + sin(_time + float(link)) * 3.0
			var ly := chain_y_base + float(link) * 14.0
			# Oval chain link
			draw_arc(Vector2(lx, ly), 5.0, 0, TAU, 12, Color(0.35, 0.3, 0.28, 0.15 + sin(_time * 0.5 + float(ci)) * 0.05), 1.5)

	# === GROUND â€” Frozen graveyard earth with snow ===
	var ground_top := 440.0
	for gi2 in range(20):
		var gt := float(gi2) / 19.0
		var gy := ground_top + gt * (628.0 - ground_top)
		var gc := Color(0.08, 0.1, 0.12).lerp(Color(0.06, 0.07, 0.1), gt)
		# Snow tint near surface
		if gt < 0.3:
			gc = gc.lerp(Color(0.4, 0.42, 0.5), (1.0 - gt / 0.3) * 0.15)
		draw_rect(Rect2(0, gy, 1280, (628.0 - ground_top) / 19.0 + 2.0), gc)

	# Snow drifts along ground
	for sd in range(10):
		var sdx := float(sd) * 135.0 + 30.0
		var sdy := ground_top + 5.0 + sin(float(sd) * 2.3) * 8.0
		draw_circle(Vector2(sdx, sdy), 25.0 + sin(float(sd) * 1.7) * 10.0, Color(0.6, 0.62, 0.7, 0.08))

	# === DECORATIONS ===
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
				var cp2 = dec["pos"]
				var cs2 = dec["size"]
				draw_rect(Rect2(cp2.x - cs2 * 0.4, cp2.y - cs2 * 2, cs2 * 0.8, cs2 * 2), Color(0.15, 0.12, 0.1, 0.4))
				var cf = sin(_time * 0.5 + dec["extra"]) * 4.0
				draw_circle(Vector2(cp2.x + cf, cp2.y - cs2 * 2.2), 4.0, Color(0.4, 0.4, 0.45, 0.06))

	# === PATH â€” Icy cobblestone with frost ===
	if enemy_path:
		var curve: Curve2D = enemy_path.curve
		var path_len := curve.get_baked_length()
		var steps := int(path_len / 6.0)
		for i in range(steps):
			var t := float(i) / float(steps)
			var pos := curve.sample_baked(t * path_len)
			var next_t := clampf(t + 0.01, 0.0, 1.0)
			var next_pos := curve.sample_baked(next_t * path_len)
			var tangent := (next_pos - pos).normalized()
			var normal := Vector2(-tangent.y, tangent.x)
			# Icy cobblestone base
			var left := pos + normal * 22.0
			var right := pos - normal * 22.0
			draw_line(left, right, Color(0.25, 0.28, 0.35, 0.35), 1.0)
		# Cobblestone pattern
		for i2 in range(0, steps, 8):
			var t2 := float(i2) / float(steps)
			var pos2 := curve.sample_baked(t2 * path_len)
			var next_t2 := clampf(t2 + 0.01, 0.0, 1.0)
			var next_pos2 := curve.sample_baked(next_t2 * path_len)
			var tangent2 := (next_pos2 - pos2).normalized()
			var normal2 := Vector2(-tangent2.y, tangent2.x)
			# Cross lines for cobblestone look
			draw_line(pos2 + normal2 * 20.0, pos2 - normal2 * 20.0, Color(0.3, 0.35, 0.45, 0.2), 1.0)
		# Frost shimmer along path edges
		for i3 in range(0, steps, 12):
			var t3 := float(i3) / float(steps)
			var pos3 := curve.sample_baked(t3 * path_len)
			var next_t3 := clampf(t3 + 0.01, 0.0, 1.0)
			var next_pos3 := curve.sample_baked(next_t3 * path_len)
			var tangent3 := (next_pos3 - pos3).normalized()
			var normal3 := Vector2(-tangent3.y, tangent3.x)
			var frost_alpha := 0.06 + sin(_time * 2.0 + t3 * 10.0) * 0.03
			draw_circle(pos3 + normal3 * 24.0, 3.0, Color(0.7, 0.8, 0.95, frost_alpha))
			draw_circle(pos3 - normal3 * 24.0, 3.0, Color(0.7, 0.8, 0.95, frost_alpha))

	# === FOREGROUND â€” Low mist and frost particles ===
	for fi in range(8):
		var fx := float(fi) * 170.0 + sin(_time * 0.3 + float(fi) * 0.9) * 40.0
		var fy := 550.0 + sin(_time * 0.4 + float(fi) * 1.2) * 20.0
		draw_circle(Vector2(fx, fy), 50.0 + sin(_time * 0.5 + float(fi)) * 15.0, Color(0.15, 0.25, 0.2, 0.04))

	# Frost sparkle particles drifting down
	for sp in range(15):
		var sp_x := fmod(float(sp) * 97.0 + _time * 8.0 + sin(float(sp) * 3.7) * 200.0, 1280.0)
		var sp_y := fmod(float(sp) * 53.0 + _time * 12.0, 578.0) + 50.0
		var sp_alpha := 0.1 + sin(_time * 3.0 + float(sp) * 2.1) * 0.06
		draw_circle(Vector2(sp_x, sp_y), 1.5, Color(0.7, 0.85, 0.95, sp_alpha))

	# Foreground iron fence silhouettes
	for fence_i in range(20):
		var fence_x := float(fence_i) * 68.0 + 10.0
		var fence_base_y := 590.0
		draw_line(Vector2(fence_x, fence_base_y), Vector2(fence_x, fence_base_y - 35.0), Color(0.08, 0.08, 0.1, 0.3), 2.0)
		# Pointed top
		draw_line(Vector2(fence_x - 3, fence_base_y - 35.0), Vector2(fence_x, fence_base_y - 42.0), Color(0.08, 0.08, 0.1, 0.3), 1.5)
		draw_line(Vector2(fence_x + 3, fence_base_y - 35.0), Vector2(fence_x, fence_base_y - 42.0), Color(0.08, 0.08, 0.1, 0.3), 1.5)
	# Horizontal fence bars
	draw_line(Vector2(10, 570.0), Vector2(1270, 570.0), Color(0.08, 0.08, 0.1, 0.2), 1.5)
	draw_line(Vector2(10, 580.0), Vector2(1270, 580.0), Color(0.08, 0.08, 0.1, 0.2), 1.5)


func _draw_scrooge_ch3(sky_color: Color, ground_color: Color) -> void:
	# === SKY GRADIENT â€” Split dawn: warm gold left, cold gray right ===
	var warm_dawn := Color(0.45, 0.25, 0.08)
	var cold_gray := Color(0.12, 0.13, 0.18)
	var golden_top := Color(0.3, 0.18, 0.06)
	var pale_sky := Color(0.35, 0.3, 0.25)
	for i in range(30):
		var t := float(i) / 29.0
		var y_start := t * 300.0
		var y_height := 300.0 / 29.0 + 2.0
		# Draw sky in vertical strips blending left-warm to right-cold
		for sx in range(16):
			var xt := float(sx) / 15.0
			var left_color := golden_top.lerp(warm_dawn, t)
			var right_color := cold_gray.lerp(Color(0.15, 0.15, 0.2), t * 0.5)
			var band_color := left_color.lerp(right_color, xt)
			# Add golden sunrise glow near horizon on the left
			if t > 0.6 and xt < 0.4:
				var glow_strength := (t - 0.6) * 2.5 * (1.0 - xt / 0.4) * 0.3
				band_color = band_color.lerp(Color(0.8, 0.5, 0.15), glow_strength)
			draw_rect(Rect2(float(sx) * 80.0, y_start, 82.0, y_height), band_color)

	# === ATMOSPHERE â€” Golden light rays from left ===
	for ray in range(8):
		var ray_angle := -0.3 + float(ray) * 0.08
		var ray_length := 500.0 + sin(_time * 0.4 + float(ray)) * 50.0
		var ray_start := Vector2(0, 200.0 + float(ray) * 20.0)
		var ray_end := ray_start + Vector2.from_angle(ray_angle) * ray_length
		var ray_alpha := 0.03 + sin(_time * 0.5 + float(ray) * 0.7) * 0.015
		draw_line(ray_start, ray_end, Color(1.0, 0.8, 0.3, ray_alpha), 3.0 + float(ray) * 0.5)

	# Warm golden haze on left side
	for hz in range(6):
		var hx := 80.0 + float(hz) * 60.0 + sin(_time * 0.3 + float(hz)) * 15.0
		var hy := 200.0 + float(hz) * 30.0
		draw_circle(Vector2(hx, hy), 70.0 + sin(_time * 0.4 + float(hz) * 1.3) * 15.0, Color(0.9, 0.65, 0.2, 0.03))

	# Cold mist on right side
	for cm in range(5):
		var cx := 850.0 + float(cm) * 90.0 + sin(_time * 0.25 + float(cm)) * 20.0
		var cy := 180.0 + float(cm) * 40.0
		draw_circle(Vector2(cx, cy), 60.0, Color(0.2, 0.2, 0.25, 0.04))

	# === GHOST OF CHRISTMAS YET TO COME â€” Tall hooded shadow, right side ===
	var ghost_x := 1100.0 + sin(_time * 0.3) * 5.0
	var ghost_y := 180.0
	# Tall hooded cloak
	var cloak_pts := PackedVector2Array([
		Vector2(ghost_x - 20, ghost_y + 120),
		Vector2(ghost_x - 28, ghost_y + 40),
		Vector2(ghost_x - 22, ghost_y - 20),
		Vector2(ghost_x - 12, ghost_y - 60),
		Vector2(ghost_x, ghost_y - 75),
		Vector2(ghost_x + 12, ghost_y - 60),
		Vector2(ghost_x + 22, ghost_y - 20),
		Vector2(ghost_x + 28, ghost_y + 40),
		Vector2(ghost_x + 20, ghost_y + 120)
	])
	var cloak_alpha := 0.3 + sin(_time * 0.8) * 0.05
	draw_colored_polygon(cloak_pts, Color(0.02, 0.02, 0.04, cloak_alpha))
	# Hood darkness
	draw_circle(Vector2(ghost_x, ghost_y - 55), 14.0, Color(0.0, 0.0, 0.0, cloak_alpha * 0.8))
	# Pointing arm extending left
	var arm_sway := sin(_time * 0.6) * 3.0
	draw_line(Vector2(ghost_x - 20, ghost_y), Vector2(ghost_x - 55 + arm_sway, ghost_y - 10), Color(0.02, 0.02, 0.04, cloak_alpha * 0.7), 3.0)
	# Dark aura
	draw_circle(Vector2(ghost_x, ghost_y + 20), 50.0, Color(0.02, 0.02, 0.06, 0.06))

	# === LONDON ROOFTOPS â€” Snow-covered with chimneys ===
	var rooftop_data := [
		{"x": 100.0, "w": 120.0, "h": 80.0, "roof_h": 40.0},
		{"x": 250.0, "w": 100.0, "h": 95.0, "roof_h": 35.0},
		{"x": 380.0, "w": 140.0, "h": 70.0, "roof_h": 45.0},
		{"x": 560.0, "w": 110.0, "h": 85.0, "roof_h": 38.0},
		{"x": 700.0, "w": 130.0, "h": 75.0, "roof_h": 42.0},
		{"x": 860.0, "w": 105.0, "h": 90.0, "roof_h": 36.0},
		{"x": 1000.0, "w": 115.0, "h": 72.0, "roof_h": 40.0}
	]
	var rooftop_base_y := 360.0
	for rd in rooftop_data:
		var rx: float = rd["x"]
		var rw: float = rd["w"]
		var rh: float = rd["h"]
		var rrh: float = rd["roof_h"]
		var building_top := rooftop_base_y - rh
		# Building wall
		draw_rect(Rect2(rx, building_top, rw, rh), Color(0.12, 0.1, 0.1, 0.55))
		# Pitched roof
		var roof_pts := PackedVector2Array([
			Vector2(rx - 5, building_top),
			Vector2(rx + rw * 0.5, building_top - rrh),
			Vector2(rx + rw + 5, building_top)
		])
		draw_colored_polygon(roof_pts, Color(0.1, 0.08, 0.08, 0.6))
		# Snow on roof ridge
		draw_line(Vector2(rx - 2, building_top), Vector2(rx + rw * 0.5, building_top - rrh), Color(0.8, 0.82, 0.88, 0.2), 3.0)
		draw_line(Vector2(rx + rw * 0.5, building_top - rrh), Vector2(rx + rw + 2, building_top), Color(0.8, 0.82, 0.88, 0.2), 3.0)
		# Warm lit windows
		for wi in range(2):
			for wj in range(2):
				var win_x := rx + 15.0 + float(wi) * (rw - 30.0)
				var win_y := building_top + 15.0 + float(wj) * 25.0
				if win_y < rooftop_base_y - 10.0:
					draw_rect(Rect2(win_x - 5, win_y - 7, 10, 14), Color(0.9, 0.65, 0.2, 0.25))
					# Warm glow
					draw_circle(Vector2(win_x, win_y), 8.0, Color(0.95, 0.7, 0.25, 0.06))

	# === WREATHS AND HOLLY on buildings ===
	for wr_i in range(5):
		var wr_x := 160.0 + float(wr_i) * 220.0
		var wr_y := rooftop_base_y - 50.0
		# Wreath circle
		draw_arc(Vector2(wr_x, wr_y), 8.0, 0, TAU, 16, Color(0.1, 0.4, 0.12, 0.3), 2.5)
		# Red bow at bottom
		draw_circle(Vector2(wr_x, wr_y + 8.0), 2.5, Color(0.7, 0.1, 0.08, 0.3))
		# Holly leaves nearby
		draw_circle(Vector2(wr_x + 12.0, wr_y - 3.0), 3.0, Color(0.08, 0.35, 0.1, 0.2))
		draw_circle(Vector2(wr_x + 18.0, wr_y - 1.0), 2.5, Color(0.08, 0.35, 0.1, 0.2))
		draw_circle(Vector2(wr_x + 15.0, wr_y - 5.0), 1.5, Color(0.65, 0.08, 0.08, 0.25))

	# === CHURCH BELLS â€” Visual golden rings ===
	var bell_x := 200.0
	var bell_y := 160.0
	# Church tower in background
	draw_rect(Rect2(bell_x - 20, bell_y, 40, 100), Color(0.1, 0.09, 0.08, 0.5))
	var bell_steeple := PackedVector2Array([
		Vector2(bell_x - 15, bell_y),
		Vector2(bell_x, bell_y - 40),
		Vector2(bell_x + 15, bell_y)
	])
	draw_colored_polygon(bell_steeple, Color(0.1, 0.09, 0.08, 0.55))
	# Animated golden rings expanding outward
	for ring_i in range(4):
		var ring_radius := 15.0 + fmod(_time * 20.0 + float(ring_i) * 25.0, 100.0)
		var ring_alpha := clampf(0.12 - ring_radius * 0.001, 0.0, 0.12)
		draw_arc(Vector2(bell_x, bell_y - 20), ring_radius, 0, TAU, 24, Color(0.95, 0.8, 0.3, ring_alpha), 1.5)

	# === CHILDREN IN SNOW â€” Small figures on left side ===
	for chi in range(3):
		var child_x := 80.0 + float(chi) * 50.0
		var child_y := 430.0
		var bounce := absf(sin(_time * 2.0 + float(chi) * 1.5)) * 4.0
		# Simple body
		draw_circle(Vector2(child_x, child_y - 18.0 - bounce), 5.0, Color(0.5, 0.3, 0.15, 0.3))
		draw_rect(Rect2(child_x - 4, child_y - 13.0 - bounce, 8, 13), Color(0.4, 0.15, 0.1 + float(chi) * 0.08, 0.3))
		# Legs
		draw_line(Vector2(child_x - 2, child_y - bounce), Vector2(child_x - 3, child_y + 6.0), Color(0.25, 0.15, 0.1, 0.3), 1.5)
		draw_line(Vector2(child_x + 2, child_y - bounce), Vector2(child_x + 3, child_y + 6.0), Color(0.25, 0.15, 0.1, 0.3), 1.5)
		# Scarf
		var scarf_col := Color(0.7, 0.1, 0.1, 0.3) if chi != 1 else Color(0.1, 0.4, 0.1, 0.3)
		draw_line(Vector2(child_x - 3, child_y - 14.0 - bounce), Vector2(child_x - 8, child_y - 10.0 - bounce), scarf_col, 2.0)

	# === GROUND â€” Snow-covered cobblestone ===
	var ground_top := 440.0
	for gi in range(20):
		var gt := float(gi) / 19.0
		var gy := ground_top + gt * (628.0 - ground_top)
		# Transition: snow white on top, darker cobblestone beneath
		var gc := Color(0.55, 0.55, 0.6).lerp(Color(0.15, 0.13, 0.12), gt)
		# Warm golden reflection on left, cold on right
		if gt < 0.3:
			gc = gc.lerp(Color(0.7, 0.6, 0.45), (1.0 - gt / 0.3) * 0.1)
		draw_rect(Rect2(0, gy, 1280, (628.0 - ground_top) / 19.0 + 2.0), gc)

	# Snow accumulation patches
	for sp2 in range(14):
		var sx2 := float(sp2) * 95.0 + 20.0
		var sy2 := ground_top + 2.0 + sin(float(sp2) * 1.9) * 5.0
		draw_circle(Vector2(sx2, sy2), 20.0 + sin(float(sp2) * 2.7) * 8.0, Color(0.75, 0.77, 0.82, 0.1))

	# === DECORATIONS ===
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
				var cp2 = dec["pos"]
				var cs2 = dec["size"]
				draw_rect(Rect2(cp2.x - cs2 * 0.4, cp2.y - cs2 * 2, cs2 * 0.8, cs2 * 2), Color(0.15, 0.12, 0.1, 0.4))
				var cf = sin(_time * 0.5 + dec["extra"]) * 4.0
				draw_circle(Vector2(cp2.x + cf, cp2.y - cs2 * 2.2), 4.0, Color(0.4, 0.4, 0.45, 0.06))

	# === PATH â€” Snow-covered cobblestone ===
	if enemy_path:
		var curve: Curve2D = enemy_path.curve
		var path_len := curve.get_baked_length()
		var steps := int(path_len / 6.0)
		for i in range(steps):
			var t := float(i) / float(steps)
			var pos := curve.sample_baked(t * path_len)
			var next_t := clampf(t + 0.01, 0.0, 1.0)
			var next_pos := curve.sample_baked(next_t * path_len)
			var tangent := (next_pos - pos).normalized()
			var normal := Vector2(-tangent.y, tangent.x)
			# Snow-dusted cobblestone
			var left := pos + normal * 22.0
			var right := pos - normal * 22.0
			# Warm-cold gradient: left side of screen warmer
			var warmth := clampf(1.0 - pos.x / 1280.0, 0.0, 1.0) * 0.1
			draw_line(left, right, Color(0.35 + warmth, 0.32 + warmth * 0.5, 0.3, 0.3), 1.0)
		# Cobblestone cross-lines
		for i2 in range(0, steps, 8):
			var t2 := float(i2) / float(steps)
			var pos2 := curve.sample_baked(t2 * path_len)
			var next_t2 := clampf(t2 + 0.01, 0.0, 1.0)
			var next_pos2 := curve.sample_baked(next_t2 * path_len)
			var tangent2 := (next_pos2 - pos2).normalized()
			var normal2 := Vector2(-tangent2.y, tangent2.x)
			draw_line(pos2 + normal2 * 20.0, pos2 - normal2 * 20.0, Color(0.4, 0.38, 0.35, 0.15), 1.0)
		# Snow patches on path
		for i3 in range(0, steps, 15):
			var t3 := float(i3) / float(steps)
			var pos3 := curve.sample_baked(t3 * path_len)
			draw_circle(pos3, 6.0 + sin(float(i3) * 0.7) * 3.0, Color(0.8, 0.82, 0.87, 0.06))

	# === FOREGROUND â€” Falling snow and warm/cold atmosphere ===
	# Falling snowflakes
	for sf in range(25):
		var sway := sin(_time * 1.5 + float(sf) * 2.3) * 15.0
		var sf_x := fmod(float(sf) * 57.0 + sway + sin(float(sf) * 4.1) * 100.0, 1280.0)
		var sf_y := fmod(float(sf) * 37.0 + _time * (15.0 + float(sf) * 0.5), 578.0) + 50.0
		var sf_size := 1.0 + sin(float(sf) * 1.3) * 0.5
		var sf_alpha := 0.12 + sin(_time * 2.0 + float(sf)) * 0.04
		draw_circle(Vector2(sf_x, sf_y), sf_size, Color(0.9, 0.92, 0.95, sf_alpha))

	# Warm foreground glow on far left (dawn light hitting ground)
	draw_circle(Vector2(0, 500), 150.0, Color(0.8, 0.55, 0.15, 0.03))
	draw_circle(Vector2(50, 550), 100.0, Color(0.85, 0.6, 0.2, 0.025))

	# Cold shadow on right foreground
	draw_rect(Rect2(900, 500, 380, 128), Color(0.04, 0.04, 0.08, 0.06))

	# Foreground lamp post silhouette (closer, larger)
	var fg_lamp_x := 1200.0
	draw_line(Vector2(fg_lamp_x, 628), Vector2(fg_lamp_x, 520), Color(0.06, 0.05, 0.04, 0.4), 4.0)
	draw_rect(Rect2(fg_lamp_x - 8, 510, 16, 16), Color(0.08, 0.06, 0.05, 0.35))
	var fg_flicker := sin(_time * 5.0) * 0.1
	draw_circle(Vector2(fg_lamp_x, 508), 5.0 + fg_flicker, Color(1.0, 0.8, 0.3, 0.4 + fg_flicker))
	draw_circle(Vector2(fg_lamp_x, 508), 25.0, Color(1.0, 0.75, 0.25, 0.04))

func _on_tower_pressed(tower_type: TowerType, desc: String) -> void:
	_deselect_tower()
	if purchased_towers.has(tower_type):
		info_label.text = "%s is already placed!" % tower_info[tower_type]["name"]
		return
	selected_tower = tower_type
	placing_tower = true
	cancel_button.visible = true
	info_label.text = desc

func _on_cancel_placement() -> void:
	placing_tower = false
	cancel_button.visible = false
	info_label.text = "Placement cancelled."

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
			# Already purchased â€” green
			btn.text = "%s  âœ“" % tier_name
			btn.disabled = true
			cost_lbl.text = "OWNED"
			cost_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 0.3))
			status_rect.color = Color(0.08, 0.18, 0.06, 0.85)
			# Green border
			status_rect.get_child(0).color = Color(0.3, 0.7, 0.2, 0.5)
		elif i == tower.upgrade_tier:
			# Next available â€” check if affordable
			btn.text = tier_name
			var can_afford = gold >= tier_cost
			btn.disabled = not can_afford
			cost_lbl.text = "%dG" % tier_cost
			if can_afford:
				# Affordable â€” gold border
				cost_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
				status_rect.color = Color(0.14, 0.10, 0.06, 0.85)
				status_rect.get_child(0).color = Color(0.85, 0.65, 0.1, 0.6)
			else:
				# Too expensive â€” dark
				cost_lbl.add_theme_color_override("font_color", Color(0.6, 0.4, 0.3))
				status_rect.color = Color(0.10, 0.07, 0.12, 0.85)
				status_rect.get_child(0).color = Color(0.4, 0.3, 0.5, 0.3)
		else:
			# Locked â€” gray
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
	info_label.text = "Wave %d â€” %s (%d enemies)" % [wave, wave_name, enemies_to_spawn]
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
	_collect_session_damage()
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
	_collect_session_damage()
	var level_name = levels[current_level]["name"] if current_level >= 0 else "Level"
	var max_lives = (levels[current_level]["lives"] + difficulty_lives_bonus[selected_difficulty]) if current_level >= 0 else 20
	max_lives = max(10, max_lives)
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
		star_str += "â˜…"
	for i in range(3 - stars):
		star_str += "â˜†"
	var diff_name = ["Easy", "Medium", "Hard"][selected_difficulty]
	# Generate treasure chest loot
	_generate_chest_loot(stars)
	var loot_text = ""
	for item in chest_loot:
		loot_text += "  %s x%d" % [item["name"], item["amount"]]
	game_over_label.text = "%s (%s) COMPLETE! %s\nTreasure Chest:%s" % [level_name, diff_name, star_str, loot_text]
	game_over_label.add_theme_color_override("font_color", Color.GOLD)
	game_over_label.visible = true
	return_button.visible = true
	start_button.disabled = true
	chest_open = true
	chest_timer = 5.0

func _generate_chest_loot(stars: int) -> void:
	chest_loot.clear()
	var chapter = levels[current_level]["chapter"] if current_level >= 0 and current_level < levels.size() else 0
	# Tier based on difficulty: Easy=1, Medium=2, Hard=3
	var tier = selected_difficulty + 1
	# Chapter progression multiplier (later chapters = better base loot)
	var chapter_mult = 1.0 + chapter * 0.5  # Ch1=1.0, Ch2=1.5, Ch3=2.0
	# Stars bonus (more stars = more loot)
	var star_mult = 0.7 + float(stars) * 0.2  # 1star=0.9, 2star=1.1, 3star=1.3

	# === GOLD COINS ===
	var gold_base = [15, 35, 60][selected_difficulty]
	var gold_amount = int(float(gold_base) * chapter_mult * star_mult)
	chest_loot.append({"type": "gold", "amount": gold_amount, "name": "Gold"})

	# === RELIC SHARDS (always drop, more on higher tiers) ===
	var shard_base = [2, 5, 10][selected_difficulty]
	var shard_amount = int(float(shard_base) * chapter_mult * star_mult)
	chest_loot.append({"type": "shards", "amount": shard_amount, "name": "Relic Shards"})
	player_relic_shards += shard_amount

	# === QUILLS (chance increases with tier) ===
	var quill_chance = [0.3, 0.6, 0.9][selected_difficulty]
	if randf() < quill_chance * star_mult:
		var quill_amount = [1, 2, 4][selected_difficulty]
		quill_amount = int(float(quill_amount) * chapter_mult)
		chest_loot.append({"type": "quills", "amount": quill_amount, "name": "Quills"})
		player_quills += quill_amount

	# === STORYBOOK STARS (rare on Easy, common on Hard) ===
	var star_chance = [0.1, 0.3, 0.6][selected_difficulty]
	if randf() < star_chance * chapter_mult * 0.5:
		var sb_amount = [1, 1, 2][selected_difficulty]
		chest_loot.append({"type": "stars", "amount": sb_amount, "name": "Storybook Stars"})
		player_storybook_stars += sb_amount

	# === RELIC DROP (very rare on Easy, guaranteed on Hard Ch3) ===
	var relic_chance = [0.05, 0.15, 0.35][selected_difficulty]
	relic_chance *= chapter_mult * 0.5
	if selected_difficulty == 2 and chapter == 2:
		relic_chance = 1.0  # Guaranteed on Hard Chapter 3
	if randf() < relic_chance:
		# Award a random locked relic for the current character
		var char_idx = levels[current_level]["character"] if current_level >= 0 else 0
		var tower_type = survivor_types[char_idx]
		var p = survivor_progress.get(tower_type, {})
		var relics_unlocked = p.get("relics_unlocked", [false, false, false, false, false, false])
		var locked_relics: Array = []
		for ri in range(6):
			if ri < relics_unlocked.size() and not relics_unlocked[ri]:
				locked_relics.append(ri)
		if locked_relics.size() > 0:
			var chosen = locked_relics[randi() % locked_relics.size()]
			relics_unlocked[chosen] = true
			p["relics_unlocked"] = relics_unlocked
			var relic_data = survivor_relics.get(tower_type, [])
			var relic_name = relic_data[chosen]["name"] if chosen < relic_data.size() else "Relic"
			chest_loot.append({"type": "relic", "amount": 1, "name": relic_name})

	# Add gold to player
	gold += gold_amount

func _collect_session_damage() -> void:
	# Map script filenames to TowerType
	var script_to_type = {
		"robin_hood.gd": TowerType.ROBIN_HOOD,
		"alice.gd": TowerType.ALICE,
		"wicked_witch.gd": TowerType.WICKED_WITCH,
		"peter_pan.gd": TowerType.PETER_PAN,
		"phantom.gd": TowerType.PHANTOM,
		"scrooge.gd": TowerType.SCROOGE,
	}
	for tower in get_tree().get_nodes_in_group("towers"):
		if tower.get("damage_dealt") != null:
			var dmg = tower.damage_dealt
			var script_path = tower.get_script().resource_path if tower.get_script() else ""
			var fname = script_path.get_file()
			if script_to_type.has(fname):
				var tt = script_to_type[fname]
				session_damage[tt] = session_damage.get(tt, 0.0) + dmg
				# Apply to persistent progression
				if survivor_progress.has(tt):
					survivor_progress[tt]["xp"] += dmg
					# Accumulate total_damage for progressive abilities
					survivor_progress[tt]["total_damage"] = survivor_progress[tt].get("total_damage", 0.0) + dmg
					_check_ability_unlocks(tt)
					# Check for level ups
					while survivor_progress[tt]["xp"] >= survivor_progress[tt]["xp_next"]:
						survivor_progress[tt]["xp"] -= survivor_progress[tt]["xp_next"]
						survivor_progress[tt]["level"] += 1
						survivor_progress[tt]["xp_next"] = 500.0 * survivor_progress[tt]["level"]
						_on_survivor_level_up(tt, survivor_progress[tt]["level"])

func _on_survivor_level_up(tower_type, new_level: int) -> void:
	# Unlock gear at level 2, sidekicks at 3/5/8
	# Relics: 0,2,4 auto-earned at levels 2,6,10; relics 1,3,5 purchasable at levels 4,8,12
	if not survivor_progress.has(tower_type):
		return
	var p = survivor_progress[tower_type]
	if new_level >= 2:
		p["gear_unlocked"] = true
	var sk_levels = [3, 5, 8]
	for i in range(3):
		if new_level >= sk_levels[i]:
			p["sidekicks_unlocked"][i] = true
	# Level-earned relics (indices 0, 2, 4) auto-unlock
	var earned_levels = {0: 2, 2: 6, 4: 10}
	for relic_idx in earned_levels:
		if new_level >= earned_levels[relic_idx]:
			p["relics_unlocked"][relic_idx] = true
	# Purchasable relics (indices 1, 3, 5) become available but NOT auto-unlocked
	# They are unlocked via gold purchase in _on_relic_clicked()

# === PROGRESSIVE ABILITY SYSTEM ===

func register_tower_damage(tower_type: int, amount: float) -> void:
	if not survivor_progress.has(tower_type):
		return
	var p = survivor_progress[tower_type]
	p["total_damage"] = p.get("total_damage", 0.0) + amount
	_check_ability_unlocks(tower_type)

func _check_ability_unlocks(tower_type: int) -> void:
	if not survivor_progress.has(tower_type):
		return
	var p = survivor_progress[tower_type]
	var total = p.get("total_damage", 0.0)
	var unlocked = p.get("abilities_unlocked", [])
	if unlocked.size() < 9:
		unlocked.resize(9)
		for i in range(unlocked.size()):
			if unlocked[i] == null:
				unlocked[i] = false
		p["abilities_unlocked"] = unlocked
	for i in range(9):
		if not unlocked[i] and total >= PROGRESSIVE_ABILITY_THRESHOLDS[i]:
			unlocked[i] = true
			_show_ability_unlock_popup(tower_type, i)
			_notify_tower_ability_unlocked(tower_type, i)

func _show_ability_unlock_popup(tower_type: int, ability_index: int) -> void:
	_ability_popup_tower_type = tower_type
	_ability_popup_index = ability_index
	# Get ability name from tower scripts
	var script_to_type = {
		TowerType.ROBIN_HOOD: "robin_hood.gd",
		TowerType.ALICE: "alice.gd",
		TowerType.WICKED_WITCH: "wicked_witch.gd",
		TowerType.PETER_PAN: "peter_pan.gd",
		TowerType.PHANTOM: "phantom.gd",
		TowerType.SCROOGE: "scrooge.gd",
	}
	_ability_popup_name = "Ability %d" % (ability_index + 1)
	_ability_popup_desc = ""
	for tower in get_tree().get_nodes_in_group("towers"):
		var fname = tower.get_script().resource_path.get_file() if tower.get_script() else ""
		if script_to_type.get(tower_type, "") == fname:
			if tower.has_method("get_progressive_ability_name"):
				_ability_popup_name = tower.get_progressive_ability_name(ability_index)
			if tower.has_method("get_progressive_ability_desc"):
				_ability_popup_desc = tower.get_progressive_ability_desc(ability_index)
			break
	_ability_popup_timer = 3.0
	_ability_popup_freeze = 0.5
	queue_redraw()

func _notify_tower_ability_unlocked(tower_type: int, ability_index: int) -> void:
	var script_to_type = {
		TowerType.ROBIN_HOOD: "robin_hood.gd",
		TowerType.ALICE: "alice.gd",
		TowerType.WICKED_WITCH: "wicked_witch.gd",
		TowerType.PETER_PAN: "peter_pan.gd",
		TowerType.PHANTOM: "phantom.gd",
		TowerType.SCROOGE: "scrooge.gd",
	}
	for tower in get_tree().get_nodes_in_group("towers"):
		var fname = tower.get_script().resource_path.get_file() if tower.get_script() else ""
		if script_to_type.get(tower_type, "") == fname:
			if tower.has_method("activate_progressive_ability"):
				tower.activate_progressive_ability(ability_index)

func restore_life(amount: int = 1) -> void:
	lives = mini(lives + amount, 99)
	update_hud()

func _update_spawn_debuffs() -> void:
	# Reset spawn debuffs each frame based on active towers
	spawn_hp_reduction = 0.0
	spawn_permanent_slow = 1.0
	for tower in get_tree().get_nodes_in_group("towers"):
		if tower.has_method("get_spawn_debuffs"):
			var debuffs = tower.get_spawn_debuffs()
			spawn_hp_reduction = max(spawn_hp_reduction, debuffs.get("hp_reduction", 0.0))
			spawn_permanent_slow = min(spawn_permanent_slow, debuffs.get("permanent_slow", 1.0))

func show_ability_choice(tower: Node2D) -> void:
	_ability_tower = tower
	ability_title.text = "Choose an Ability"
	for i in range(4):
		if i < tower.TIER_NAMES.size():
			var desc = ""
			if tower.has("ABILITY_DESCRIPTIONS") and i < tower.ABILITY_DESCRIPTIONS.size():
				desc = " â€” " + tower.ABILITY_DESCRIPTIONS[i]
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
