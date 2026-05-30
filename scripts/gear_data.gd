# gear_data.gd — Complete gear database (265 items)
# Generated for Shadow Defense: Tales from the Pages

const GEAR_ITEMS_V2: Array = [
	# ============================================================
	# COMMON TIER (100 items) — 48 character-specific + 52 universal
	# Single effect, values 0.05-0.12
	# ============================================================

	# --- Robin Hood (4 Common) ---
	{"id": "rh_c1", "name": "Sherwood Shortbow", "desc": "+8% damage", "tier": "common", "effect": "damage", "value": 0.08, "character": "robin_hood"},
	{"id": "rh_c2", "name": "Lincoln Green Cloak", "desc": "+6% dodge", "tier": "common", "effect": "dodge", "value": 0.06, "character": "robin_hood"},
	{"id": "rh_c3", "name": "Outlaw's Quiver", "desc": "+7% attack speed", "tier": "common", "effect": "attack_speed", "value": 0.07, "character": "robin_hood"},
	{"id": "rh_c4", "name": "Merry Men's Token", "desc": "+10% range", "tier": "common", "effect": "range", "value": 0.10, "character": "robin_hood"},

	# --- Alice (4 Common) ---
	{"id": "al_c1", "name": "Curious Teacup", "desc": "+7% attack speed", "tier": "common", "effect": "attack_speed", "value": 0.07, "character": "alice"},
	{"id": "al_c2", "name": "Eat Me Cookie", "desc": "+9% damage", "tier": "common", "effect": "damage", "value": 0.09, "character": "alice"},
	{"id": "al_c3", "name": "Rabbit's Pocket Watch", "desc": "+6% cooldown reduction", "tier": "common", "effect": "cooldown_reduction", "value": 0.06, "character": "alice"},
	{"id": "al_c4", "name": "Card Soldier's Shield", "desc": "+8% defense", "tier": "common", "effect": "defense", "value": 0.08, "character": "alice"},

	# --- Wicked Witch (4 Common) ---
	{"id": "ww_c1", "name": "Emerald Shard", "desc": "+8% damage", "tier": "common", "effect": "damage", "value": 0.08, "character": "wicked_witch"},
	{"id": "ww_c2", "name": "Poppy Pollen Vial", "desc": "+7% slow", "tier": "common", "effect": "slow", "value": 0.07, "character": "wicked_witch"},
	{"id": "ww_c3", "name": "Broomstick Splinter", "desc": "+10% range", "tier": "common", "effect": "range", "value": 0.10, "character": "wicked_witch"},
	{"id": "ww_c4", "name": "Monkey Wing Feather", "desc": "+6% attack speed", "tier": "common", "effect": "attack_speed", "value": 0.06, "character": "wicked_witch"},

	# --- Peter Pan (4 Common) ---
	{"id": "pp_c1", "name": "Fairy Dust Pinch", "desc": "+7% damage", "tier": "common", "effect": "damage", "value": 0.07, "character": "peter_pan"},
	{"id": "pp_c2", "name": "Lost Boy's Dagger", "desc": "+8% attack speed", "tier": "common", "effect": "attack_speed", "value": 0.08, "character": "peter_pan"},
	{"id": "pp_c3", "name": "Shadow Stitch Thread", "desc": "+6% dodge", "tier": "common", "effect": "dodge", "value": 0.06, "character": "peter_pan"},
	{"id": "pp_c4", "name": "Neverland Acorn Cap", "desc": "+5% defense", "tier": "common", "effect": "defense", "value": 0.05, "character": "peter_pan"},

	# --- Phantom (4 Common) ---
	{"id": "ph_c1", "name": "Porcelain Mask Chip", "desc": "+8% damage", "tier": "common", "effect": "damage", "value": 0.08, "character": "phantom"},
	{"id": "ph_c2", "name": "Opera House Rose", "desc": "+7% crit", "tier": "common", "effect": "crit", "value": 0.07, "character": "phantom"},
	{"id": "ph_c3", "name": "Gondola Oar Shard", "desc": "+6% range", "tier": "common", "effect": "range", "value": 0.06, "character": "phantom"},
	{"id": "ph_c4", "name": "Chandelier Crystal", "desc": "+10% splash_radius", "tier": "common", "effect": "splash_radius", "value": 0.10, "character": "phantom"},

	# --- Scrooge (4 Common) ---
	{"id": "sc_c1", "name": "Tarnished Penny", "desc": "+8% gold_bonus", "tier": "common", "effect": "gold_bonus", "value": 0.08, "character": "scrooge"},
	{"id": "sc_c2", "name": "Counting House Ledger", "desc": "+6% cooldown reduction", "tier": "common", "effect": "cooldown_reduction", "value": 0.06, "character": "scrooge"},
	{"id": "sc_c3", "name": "Ghost Chain Link", "desc": "+7% slow", "tier": "common", "effect": "slow", "value": 0.07, "character": "scrooge"},
	{"id": "sc_c4", "name": "Candle Stub", "desc": "+9% range", "tier": "common", "effect": "range", "value": 0.09, "character": "scrooge"},

	# --- Sherlock (4 Common) ---
	{"id": "sh_c1", "name": "Worn Magnifying Lens", "desc": "+10% range", "tier": "common", "effect": "range", "value": 0.10, "character": "sherlock"},
	{"id": "sh_c2", "name": "Baker Street Pipe", "desc": "+7% crit", "tier": "common", "effect": "crit", "value": 0.07, "character": "sherlock"},
	{"id": "sh_c3", "name": "Deduction Notes", "desc": "+8% damage", "tier": "common", "effect": "damage", "value": 0.08, "character": "sherlock"},
	{"id": "sh_c4", "name": "Watson's Field Kit", "desc": "+6% defense", "tier": "common", "effect": "defense", "value": 0.06, "character": "sherlock"},

	# --- Tarzan (4 Common) ---
	{"id": "tz_c1", "name": "Jungle Vine Whip", "desc": "+8% range", "tier": "common", "effect": "range", "value": 0.08, "character": "tarzan"},
	{"id": "tz_c2", "name": "Ape Fang Necklace", "desc": "+9% damage", "tier": "common", "effect": "damage", "value": 0.09, "character": "tarzan"},
	{"id": "tz_c3", "name": "Primal Drum Skin", "desc": "+7% attack speed", "tier": "common", "effect": "attack_speed", "value": 0.07, "character": "tarzan"},
	{"id": "tz_c4", "name": "Leopard Claw", "desc": "+6% crit", "tier": "common", "effect": "crit", "value": 0.06, "character": "tarzan"},

	# --- Dracula (4 Common) ---
	{"id": "dr_c1", "name": "Blood Drop Pendant", "desc": "+5% lifesteal", "tier": "common", "effect": "lifesteal", "value": 0.05, "character": "dracula"},
	{"id": "dr_c2", "name": "Bat Wing Cloak", "desc": "+7% dodge", "tier": "common", "effect": "dodge", "value": 0.07, "character": "dracula"},
	{"id": "dr_c3", "name": "Coffin Nail", "desc": "+8% damage", "tier": "common", "effect": "damage", "value": 0.08, "character": "dracula"},
	{"id": "dr_c4", "name": "Moonlit Fang", "desc": "+6% crit", "tier": "common", "effect": "crit", "value": 0.06, "character": "dracula"},

	# --- Merlin (4 Common) ---
	{"id": "mr_c1", "name": "Cracked Crystal Orb", "desc": "+9% range", "tier": "common", "effect": "range", "value": 0.09, "character": "merlin"},
	{"id": "mr_c2", "name": "Apprentice Rune Stone", "desc": "+7% damage", "tier": "common", "effect": "damage", "value": 0.07, "character": "merlin"},
	{"id": "mr_c3", "name": "Round Table Splinter", "desc": "+8% aura_range", "tier": "common", "effect": "aura_range", "value": 0.08, "character": "merlin"},
	{"id": "mr_c4", "name": "Prophecy Scroll Scrap", "desc": "+6% cooldown reduction", "tier": "common", "effect": "cooldown_reduction", "value": 0.06, "character": "merlin"},

	# --- Frankenstein (4 Common) ---
	{"id": "fr_c1", "name": "Copper Bolt", "desc": "+8% chain", "tier": "common", "effect": "chain", "value": 0.08, "character": "frankenstein"},
	{"id": "fr_c2", "name": "Lab Flask Shard", "desc": "+7% damage", "tier": "common", "effect": "damage", "value": 0.07, "character": "frankenstein"},
	{"id": "fr_c3", "name": "Galvanic Wire", "desc": "+9% attack speed", "tier": "common", "effect": "attack_speed", "value": 0.09, "character": "frankenstein"},
	{"id": "fr_c4", "name": "Stitched Leather Strap", "desc": "+6% defense", "tier": "common", "effect": "defense", "value": 0.06, "character": "frankenstein"},

	# --- Shadow Author (4 Common) ---
	{"id": "sa_c1", "name": "Ink-Stained Quill Tip", "desc": "+8% damage", "tier": "common", "effect": "damage", "value": 0.08, "character": "shadow_author"},
	{"id": "sa_c2", "name": "Torn Page Fragment", "desc": "+7% cooldown reduction", "tier": "common", "effect": "cooldown_reduction", "value": 0.07, "character": "shadow_author"},
	{"id": "sa_c3", "name": "Blotted Margin Note", "desc": "+6% debuff_amp", "tier": "common", "effect": "debuff_amp", "value": 0.06, "character": "shadow_author"},
	{"id": "sa_c4", "name": "Cheap Inkwell", "desc": "+10% range", "tier": "common", "effect": "range", "value": 0.10, "character": "shadow_author"},

	# --- Universal Common (52 items) ---
	{"id": "uc_01", "name": "Iron Arrowhead", "desc": "+5% damage", "tier": "common", "effect": "damage", "value": 0.05},
	{"id": "uc_02", "name": "Dented Buckler", "desc": "+6% defense", "tier": "common", "effect": "defense", "value": 0.06},
	{"id": "uc_03", "name": "Worn Leather Boots", "desc": "+5% dodge", "tier": "common", "effect": "dodge", "value": 0.05},
	{"id": "uc_04", "name": "Cracked Scope Lens", "desc": "+7% range", "tier": "common", "effect": "range", "value": 0.07},
	{"id": "uc_05", "name": "Oiled Bowstring", "desc": "+6% attack speed", "tier": "common", "effect": "attack_speed", "value": 0.06},
	{"id": "uc_06", "name": "Lucky Coin", "desc": "+5% gold_bonus", "tier": "common", "effect": "gold_bonus", "value": 0.05},
	{"id": "uc_07", "name": "Barbed Tip", "desc": "+8% crit", "tier": "common", "effect": "crit", "value": 0.08},
	{"id": "uc_08", "name": "Frost Pebble", "desc": "+5% slow", "tier": "common", "effect": "slow", "value": 0.05},
	{"id": "uc_09", "name": "Ember Coal", "desc": "+6% burn", "tier": "common", "effect": "burn", "value": 0.06},
	{"id": "uc_10", "name": "Sharpened Needle", "desc": "+7% pierce", "tier": "common", "effect": "pierce", "value": 0.07},
	{"id": "uc_11", "name": "Copper Ring", "desc": "+5% crit_damage", "tier": "common", "effect": "crit_damage", "value": 0.05},
	{"id": "uc_12", "name": "Tar Pouch", "desc": "+8% slow", "tier": "common", "effect": "slow", "value": 0.08},
	{"id": "uc_13", "name": "Wooden Shield Fragment", "desc": "+7% defense", "tier": "common", "effect": "defense", "value": 0.07},
	{"id": "uc_14", "name": "Rough Whetstone", "desc": "+6% damage", "tier": "common", "effect": "damage", "value": 0.06},
	{"id": "uc_15", "name": "Scouts Spyglass", "desc": "+9% range", "tier": "common", "effect": "range", "value": 0.09},
	{"id": "uc_16", "name": "Flint Striker", "desc": "+7% burn", "tier": "common", "effect": "burn", "value": 0.07},
	{"id": "uc_17", "name": "Feathered Charm", "desc": "+6% dodge", "tier": "common", "effect": "dodge", "value": 0.06},
	{"id": "uc_18", "name": "Silver Thimble", "desc": "+5% armor_pierce", "tier": "common", "effect": "armor_pierce", "value": 0.05},
	{"id": "uc_19", "name": "Venom Sac", "desc": "+7% poison", "tier": "common", "effect": "poison", "value": 0.07},
	{"id": "uc_20", "name": "Bronze Clasp", "desc": "+8% defense", "tier": "common", "effect": "defense", "value": 0.08},
	{"id": "uc_21", "name": "Traveler's Compass", "desc": "+6% range", "tier": "common", "effect": "range", "value": 0.06},
	{"id": "uc_22", "name": "Weighted Gloves", "desc": "+7% damage", "tier": "common", "effect": "damage", "value": 0.07},
	{"id": "uc_23", "name": "Tinker's Gear", "desc": "+5% cooldown reduction", "tier": "common", "effect": "cooldown_reduction", "value": 0.05},
	{"id": "uc_24", "name": "Smoke Pellet", "desc": "+6% dodge", "tier": "common", "effect": "dodge", "value": 0.06},
	{"id": "uc_25", "name": "Alchemist's Salt", "desc": "+8% burn", "tier": "common", "effect": "burn", "value": 0.08},
	{"id": "uc_26", "name": "Merchant's Abacus", "desc": "+7% gold_bonus", "tier": "common", "effect": "gold_bonus", "value": 0.07},
	{"id": "uc_27", "name": "Sturdy Chain Link", "desc": "+9% defense", "tier": "common", "effect": "defense", "value": 0.09},
	{"id": "uc_28", "name": "Splinter Shot", "desc": "+5% splash_radius", "tier": "common", "effect": "splash_radius", "value": 0.05},
	{"id": "uc_29", "name": "Crow Feather", "desc": "+8% attack speed", "tier": "common", "effect": "attack_speed", "value": 0.08},
	{"id": "uc_30", "name": "Rusty Nail", "desc": "+6% pierce", "tier": "common", "effect": "pierce", "value": 0.06},
	{"id": "uc_31", "name": "Polished Pebble", "desc": "+10% range", "tier": "common", "effect": "range", "value": 0.10},
	{"id": "uc_32", "name": "Thorn Bracelet", "desc": "+5% crit", "tier": "common", "effect": "crit", "value": 0.05},
	{"id": "uc_33", "name": "Old Compass Needle", "desc": "+7% armor_pierce", "tier": "common", "effect": "armor_pierce", "value": 0.07},
	{"id": "uc_34", "name": "Chipped Gemstone", "desc": "+6% crit_damage", "tier": "common", "effect": "crit_damage", "value": 0.06},
	{"id": "uc_35", "name": "Ironwood Bark", "desc": "+10% defense", "tier": "common", "effect": "defense", "value": 0.10},
	{"id": "uc_36", "name": "Resin Globe", "desc": "+7% splash_radius", "tier": "common", "effect": "splash_radius", "value": 0.07},
	{"id": "uc_37", "name": "Sparrow Talon", "desc": "+9% attack speed", "tier": "common", "effect": "attack_speed", "value": 0.09},
	{"id": "uc_38", "name": "Chalk Dust Pouch", "desc": "+5% debuff_amp", "tier": "common", "effect": "debuff_amp", "value": 0.05},
	{"id": "uc_39", "name": "Bee Sting Barb", "desc": "+8% poison", "tier": "common", "effect": "poison", "value": 0.08},
	{"id": "uc_40", "name": "Tin Soldier's Sword", "desc": "+10% damage", "tier": "common", "effect": "damage", "value": 0.10},
	{"id": "uc_41", "name": "Glass Bead", "desc": "+5% chain", "tier": "common", "effect": "chain", "value": 0.05},
	{"id": "uc_42", "name": "Hemp Rope Coil", "desc": "+6% slow", "tier": "common", "effect": "slow", "value": 0.06},
	{"id": "uc_43", "name": "Pine Pitch Ball", "desc": "+7% burn", "tier": "common", "effect": "burn", "value": 0.07},
	{"id": "uc_44", "name": "Parchment Scrap", "desc": "+8% cooldown reduction", "tier": "common", "effect": "cooldown_reduction", "value": 0.08},
	{"id": "uc_45", "name": "Bone Dice", "desc": "+12% crit", "tier": "common", "effect": "crit", "value": 0.12},
	{"id": "uc_46", "name": "Wax Seal Stamp", "desc": "+5% aura_range", "tier": "common", "effect": "aura_range", "value": 0.05},
	{"id": "uc_47", "name": "Horseshoe Nail", "desc": "+11% damage", "tier": "common", "effect": "damage", "value": 0.11},
	{"id": "uc_48", "name": "Dried Herb Bundle", "desc": "+6% heal_nearby", "tier": "common", "effect": "heal_nearby", "value": 0.06},
	{"id": "uc_49", "name": "Cobalt Dust", "desc": "+5% stun", "tier": "common", "effect": "stun", "value": 0.05},
	{"id": "uc_50", "name": "Leather Finger Guard", "desc": "+7% attack speed", "tier": "common", "effect": "attack_speed", "value": 0.07},
	{"id": "uc_51", "name": "Tallow Candle", "desc": "+8% range", "tier": "common", "effect": "range", "value": 0.08},
	{"id": "uc_52", "name": "Forged Washer", "desc": "+12% defense", "tier": "common", "effect": "defense", "value": 0.12},

	# ============================================================
	# RARE TIER (80 items) — 36 character-specific + 44 universal
	# 1-2 effects, values 0.10-0.20
	# ============================================================

	# --- Robin Hood (3 Rare) ---
	{"id": "rh_r1", "name": "Sherwood Longbow", "desc": "+15% damage, +10% range", "tier": "rare", "effects": [{"effect": "damage", "value": 0.15}, {"effect": "range", "value": 0.10}], "character": "robin_hood"},
	{"id": "rh_r2", "name": "Hood's Silver Arrow", "desc": "+12% crit, +10% crit_damage", "tier": "rare", "effects": [{"effect": "crit", "value": 0.12}, {"effect": "crit_damage", "value": 0.10}], "character": "robin_hood"},
	{"id": "rh_r3", "name": "Marian's Favor", "desc": "+13% dodge, +10% attack speed", "tier": "rare", "effects": [{"effect": "dodge", "value": 0.13}, {"effect": "attack_speed", "value": 0.10}], "character": "robin_hood"},

	# --- Alice (3 Rare) ---
	{"id": "al_r1", "name": "Cheshire Cat Grin", "desc": "+14% dodge, +10% crit", "tier": "rare", "effects": [{"effect": "dodge", "value": 0.14}, {"effect": "crit", "value": 0.10}], "character": "alice"},
	{"id": "al_r2", "name": "Drink Me Potion", "desc": "+15% attack speed", "tier": "rare", "effect": "attack_speed", "value": 0.15, "character": "alice"},
	{"id": "al_r3", "name": "Looking Glass Shard", "desc": "+12% damage, +10% pierce", "tier": "rare", "effects": [{"effect": "damage", "value": 0.12}, {"effect": "pierce", "value": 0.10}], "character": "alice"},

	# --- Wicked Witch (3 Rare) ---
	{"id": "ww_r1", "name": "Crystal Ball of Oz", "desc": "+15% range, +10% slow", "tier": "rare", "effects": [{"effect": "range", "value": 0.15}, {"effect": "slow", "value": 0.10}], "character": "wicked_witch"},
	{"id": "ww_r2", "name": "Ruby Slipper Heel", "desc": "+12% damage, +10% burn", "tier": "rare", "effects": [{"effect": "damage", "value": 0.12}, {"effect": "burn", "value": 0.10}], "character": "wicked_witch"},
	{"id": "ww_r3", "name": "Enchanted Broomstick", "desc": "+18% range", "tier": "rare", "effect": "range", "value": 0.18, "character": "wicked_witch"},

	# --- Peter Pan (3 Rare) ---
	{"id": "pp_r1", "name": "Tinker Bell's Lantern", "desc": "+13% damage, +12% aura_range", "tier": "rare", "effects": [{"effect": "damage", "value": 0.13}, {"effect": "aura_range", "value": 0.12}], "character": "peter_pan"},
	{"id": "pp_r2", "name": "Captain Hook's Compass", "desc": "+15% range, +10% crit", "tier": "rare", "effects": [{"effect": "range", "value": 0.15}, {"effect": "crit", "value": 0.10}], "character": "peter_pan"},
	{"id": "pp_r3", "name": "Crocodile Tooth", "desc": "+14% armor_pierce, +10% damage", "tier": "rare", "effects": [{"effect": "armor_pierce", "value": 0.14}, {"effect": "damage", "value": 0.10}], "character": "peter_pan"},

	# --- Phantom (3 Rare) ---
	{"id": "ph_r1", "name": "Phantom's Score Sheet", "desc": "+15% damage, +10% cooldown reduction", "tier": "rare", "effects": [{"effect": "damage", "value": 0.15}, {"effect": "cooldown_reduction", "value": 0.10}], "character": "phantom"},
	{"id": "ph_r2", "name": "Underground Lake Gem", "desc": "+12% crit, +12% crit_damage", "tier": "rare", "effects": [{"effect": "crit", "value": 0.12}, {"effect": "crit_damage", "value": 0.12}], "character": "phantom"},
	{"id": "ph_r3", "name": "Opera Mask Half", "desc": "+13% dodge, +12% debuff_amp", "tier": "rare", "effects": [{"effect": "dodge", "value": 0.13}, {"effect": "debuff_amp", "value": 0.12}], "character": "phantom"},

	# --- Scrooge (3 Rare) ---
	{"id": "sc_r1", "name": "Ghost of Christmas Past", "desc": "+15% gold_bonus, +10% cooldown reduction", "tier": "rare", "effects": [{"effect": "gold_bonus", "value": 0.15}, {"effect": "cooldown_reduction", "value": 0.10}], "character": "scrooge"},
	{"id": "sc_r2", "name": "Marley's Lockbox", "desc": "+18% gold_bonus", "tier": "rare", "effect": "gold_bonus", "value": 0.18, "character": "scrooge"},
	{"id": "sc_r3", "name": "Ebenezer's Walking Stick", "desc": "+12% damage, +10% slow", "tier": "rare", "effects": [{"effect": "damage", "value": 0.12}, {"effect": "slow", "value": 0.10}], "character": "scrooge"},

	# --- Sherlock (3 Rare) ---
	{"id": "sh_r1", "name": "Hound's Tooth", "desc": "+14% damage, +12% crit", "tier": "rare", "effects": [{"effect": "damage", "value": 0.14}, {"effect": "crit", "value": 0.12}], "character": "sherlock"},
	{"id": "sh_r2", "name": "Moriarty's Cipher", "desc": "+15% debuff_amp, +10% armor_pierce", "tier": "rare", "effects": [{"effect": "debuff_amp", "value": 0.15}, {"effect": "armor_pierce", "value": 0.10}], "character": "sherlock"},
	{"id": "sh_r3", "name": "221B Fireplace Iron", "desc": "+18% range", "tier": "rare", "effect": "range", "value": 0.18, "character": "sherlock"},

	# --- Tarzan (3 Rare) ---
	{"id": "tz_r1", "name": "Gorilla King's Pelt", "desc": "+15% defense, +10% damage", "tier": "rare", "effects": [{"effect": "defense", "value": 0.15}, {"effect": "damage", "value": 0.10}], "character": "tarzan"},
	{"id": "tz_r2", "name": "Jungle Spear", "desc": "+14% pierce, +12% damage", "tier": "rare", "effects": [{"effect": "pierce", "value": 0.14}, {"effect": "damage", "value": 0.12}], "character": "tarzan"},
	{"id": "tz_r3", "name": "War Drum Mallet", "desc": "+13% attack speed, +10% aura_speed", "tier": "rare", "effects": [{"effect": "attack_speed", "value": 0.13}, {"effect": "aura_speed", "value": 0.10}], "character": "tarzan"},

	# --- Dracula (3 Rare) ---
	{"id": "dr_r1", "name": "Crimson Chalice", "desc": "+12% lifesteal, +10% damage", "tier": "rare", "effects": [{"effect": "lifesteal", "value": 0.12}, {"effect": "damage", "value": 0.10}], "character": "dracula"},
	{"id": "dr_r2", "name": "Castle Transylvania Key", "desc": "+15% defense, +10% dodge", "tier": "rare", "effects": [{"effect": "defense", "value": 0.15}, {"effect": "dodge", "value": 0.10}], "character": "dracula"},
	{"id": "dr_r3", "name": "Moonstone Brooch", "desc": "+14% crit, +12% attack speed", "tier": "rare", "effects": [{"effect": "crit", "value": 0.14}, {"effect": "attack_speed", "value": 0.12}], "character": "dracula"},

	# --- Merlin (3 Rare) ---
	{"id": "mr_r1", "name": "Staff of the Lake", "desc": "+15% range, +12% damage", "tier": "rare", "effects": [{"effect": "range", "value": 0.15}, {"effect": "damage", "value": 0.12}], "character": "merlin"},
	{"id": "mr_r2", "name": "Enchanted Runestone", "desc": "+14% aura_range, +10% cooldown reduction", "tier": "rare", "effects": [{"effect": "aura_range", "value": 0.14}, {"effect": "cooldown_reduction", "value": 0.10}], "character": "merlin"},
	{"id": "mr_r3", "name": "Camelot Signet Ring", "desc": "+18% aura_range", "tier": "rare", "effect": "aura_range", "value": 0.18, "character": "merlin"},

	# --- Frankenstein (3 Rare) ---
	{"id": "fr_r1", "name": "Tesla Coil Shard", "desc": "+14% chain, +12% damage", "tier": "rare", "effects": [{"effect": "chain", "value": 0.14}, {"effect": "damage", "value": 0.12}], "character": "frankenstein"},
	{"id": "fr_r2", "name": "Bride's Headband", "desc": "+15% attack speed, +10% stun", "tier": "rare", "effects": [{"effect": "attack_speed", "value": 0.15}, {"effect": "stun", "value": 0.10}], "character": "frankenstein"},
	{"id": "fr_r3", "name": "Galvanic Battery", "desc": "+13% damage, +12% chain", "tier": "rare", "effects": [{"effect": "damage", "value": 0.13}, {"effect": "chain", "value": 0.12}], "character": "frankenstein"},

	# --- Shadow Author (3 Rare) ---
	{"id": "sa_r1", "name": "Fountain Pen of Revision", "desc": "+14% damage, +10% debuff_amp", "tier": "rare", "effects": [{"effect": "damage", "value": 0.14}, {"effect": "debuff_amp", "value": 0.10}], "character": "shadow_author"},
	{"id": "sa_r2", "name": "Bookmarked Chapter", "desc": "+15% cooldown reduction, +10% range", "tier": "rare", "effects": [{"effect": "cooldown_reduction", "value": 0.15}, {"effect": "range", "value": 0.10}], "character": "shadow_author"},
	{"id": "sa_r3", "name": "Plot Twist Scroll", "desc": "+12% crit, +12% crit_damage", "tier": "rare", "effects": [{"effect": "crit", "value": 0.12}, {"effect": "crit_damage", "value": 0.12}], "character": "shadow_author"},

	# --- Universal Rare (44 items) ---
	{"id": "ur_01", "name": "Steel Broadhead", "desc": "+15% damage", "tier": "rare", "effect": "damage", "value": 0.15},
	{"id": "ur_02", "name": "Reinforced Breastplate", "desc": "+15% defense, +10% stun", "tier": "rare", "effects": [{"effect": "defense", "value": 0.15}, {"effect": "stun", "value": 0.10}]},
	{"id": "ur_03", "name": "Hawk Eye Amulet", "desc": "+18% range", "tier": "rare", "effect": "range", "value": 0.18},
	{"id": "ur_04", "name": "Quicksilver Bracelet", "desc": "+15% attack speed", "tier": "rare", "effect": "attack_speed", "value": 0.15},
	{"id": "ur_05", "name": "Ruby Brooch", "desc": "+14% crit, +10% crit_damage", "tier": "rare", "effects": [{"effect": "crit", "value": 0.14}, {"effect": "crit_damage", "value": 0.10}]},
	{"id": "ur_06", "name": "Frostbound Quartz", "desc": "+15% slow, +10% damage", "tier": "rare", "effects": [{"effect": "slow", "value": 0.15}, {"effect": "damage", "value": 0.10}]},
	{"id": "ur_07", "name": "Treasure Hunter's Pouch", "desc": "+15% gold_bonus", "tier": "rare", "effect": "gold_bonus", "value": 0.15},
	{"id": "ur_08", "name": "Vampire's Kiss Ring", "desc": "+12% lifesteal", "tier": "rare", "effect": "lifesteal", "value": 0.12},
	{"id": "ur_09", "name": "Infernal Resin", "desc": "+14% burn, +10% splash_radius", "tier": "rare", "effects": [{"effect": "burn", "value": 0.14}, {"effect": "splash_radius", "value": 0.10}]},
	{"id": "ur_10", "name": "Acrobat's Sash", "desc": "+15% dodge", "tier": "rare", "effect": "dodge", "value": 0.15},
	{"id": "ur_11", "name": "Armor-Piercing Bolt", "desc": "+15% armor_pierce", "tier": "rare", "effect": "armor_pierce", "value": 0.15},
	{"id": "ur_12", "name": "Spiked Chain Whip", "desc": "+12% chain, +10% damage", "tier": "rare", "effects": [{"effect": "chain", "value": 0.12}, {"effect": "damage", "value": 0.10}]},
	{"id": "ur_13", "name": "Explosive Pouch", "desc": "+15% splash_radius", "tier": "rare", "effect": "splash_radius", "value": 0.15},
	{"id": "ur_14", "name": "Giant Slayer Charm", "desc": "+15% boss_damage", "tier": "rare", "effect": "boss_damage", "value": 0.15},
	{"id": "ur_15", "name": "Medic's Bandage Roll", "desc": "+12% heal_nearby", "tier": "rare", "effect": "heal_nearby", "value": 0.12},
	{"id": "ur_16", "name": "Executioner's Gauntlet", "desc": "+10% execute", "tier": "rare", "effect": "execute", "value": 0.10},
	{"id": "ur_17", "name": "Weakening Powder", "desc": "+14% debuff_amp", "tier": "rare", "effect": "debuff_amp", "value": 0.14},
	{"id": "ur_18", "name": "Battle Standard", "desc": "+15% aura_range", "tier": "rare", "effect": "aura_range", "value": 0.15},
	{"id": "ur_19", "name": "Clockwork Spring", "desc": "+12% cooldown reduction", "tier": "rare", "effect": "cooldown_reduction", "value": 0.12},
	{"id": "ur_20", "name": "Thunder Stone", "desc": "+12% stun, +10% damage", "tier": "rare", "effects": [{"effect": "stun", "value": 0.12}, {"effect": "damage", "value": 0.10}]},
	{"id": "ur_21", "name": "Serpent Fang", "desc": "+14% poison", "tier": "rare", "effect": "poison", "value": 0.14},
	{"id": "ur_22", "name": "Twin Shot Brace", "desc": "+12% multi_shot", "tier": "rare", "effect": "multi_shot", "value": 0.12},
	{"id": "ur_23", "name": "War Horn", "desc": "+13% aura_speed", "tier": "rare", "effect": "aura_speed", "value": 0.13},
	{"id": "ur_24", "name": "Mithril Chainmail", "desc": "+18% defense", "tier": "rare", "effect": "defense", "value": 0.18},
	{"id": "ur_25", "name": "Sapphire Sightstone", "desc": "+14% range, +10% crit", "tier": "rare", "effects": [{"effect": "range", "value": 0.14}, {"effect": "crit", "value": 0.10}]},
	{"id": "ur_26", "name": "Razorwind Fan", "desc": "+13% attack speed, +10% pierce", "tier": "rare", "effects": [{"effect": "attack_speed", "value": 0.13}, {"effect": "pierce", "value": 0.10}]},
	{"id": "ur_27", "name": "Gilded Scales", "desc": "+14% gold_bonus, +10% defense", "tier": "rare", "effects": [{"effect": "gold_bonus", "value": 0.14}, {"effect": "defense", "value": 0.10}]},
	{"id": "ur_28", "name": "Crimson Thorn", "desc": "+12% damage, +10% lifesteal", "tier": "rare", "effects": [{"effect": "damage", "value": 0.12}, {"effect": "lifesteal", "value": 0.10}]},
	{"id": "ur_29", "name": "Glacial Hammer", "desc": "+15% stun", "tier": "rare", "effect": "stun", "value": 0.15},
	{"id": "ur_30", "name": "Wildfire Oil", "desc": "+16% burn", "tier": "rare", "effect": "burn", "value": 0.16},
	{"id": "ur_31", "name": "Piercing Javelin", "desc": "+18% pierce", "tier": "rare", "effect": "pierce", "value": 0.18},
	{"id": "ur_32", "name": "Soul Siphon Pendant", "desc": "+15% lifesteal", "tier": "rare", "effect": "lifesteal", "value": 0.15},
	{"id": "ur_33", "name": "Titan's Knuckle", "desc": "+20% damage", "tier": "rare", "effect": "damage", "value": 0.20},
	{"id": "ur_34", "name": "Shadow Cloak", "desc": "+16% dodge, +10% damage", "tier": "rare", "effects": [{"effect": "dodge", "value": 0.16}, {"effect": "damage", "value": 0.10}]},
	{"id": "ur_35", "name": "Tempest Feather", "desc": "+18% attack speed", "tier": "rare", "effect": "attack_speed", "value": 0.18},
	{"id": "ur_36", "name": "Bounty Tracker", "desc": "+14% boss_damage, +10% crit", "tier": "rare", "effects": [{"effect": "boss_damage", "value": 0.14}, {"effect": "crit", "value": 0.10}]},
	{"id": "ur_37", "name": "Dragonfire Canister", "desc": "+15% burn, +10% splash_radius", "tier": "rare", "effects": [{"effect": "burn", "value": 0.15}, {"effect": "splash_radius", "value": 0.10}]},
	{"id": "ur_38", "name": "Plague Doctor Mask", "desc": "+16% poison, +10% debuff_amp", "tier": "rare", "effects": [{"effect": "poison", "value": 0.16}, {"effect": "debuff_amp", "value": 0.10}]},
	{"id": "ur_39", "name": "Fortune Cookie", "desc": "+18% gold_bonus", "tier": "rare", "effect": "gold_bonus", "value": 0.18},
	{"id": "ur_40", "name": "Rally Pennant", "desc": "+15% aura_speed, +10% aura_range", "tier": "rare", "effects": [{"effect": "aura_speed", "value": 0.15}, {"effect": "aura_range", "value": 0.10}]},
	{"id": "ur_41", "name": "Concussive Round", "desc": "+14% stun, +12% damage", "tier": "rare", "effects": [{"effect": "stun", "value": 0.14}, {"effect": "damage", "value": 0.12}]},
	{"id": "ur_42", "name": "Barbed Net", "desc": "+13% slow, +12% poison", "tier": "rare", "effects": [{"effect": "slow", "value": 0.13}, {"effect": "poison", "value": 0.12}]},
	{"id": "ur_43", "name": "Sniper's Bipod", "desc": "+20% range", "tier": "rare", "effect": "range", "value": 0.20},
	{"id": "ur_44", "name": "Berserker's Wristband", "desc": "+16% crit_damage", "tier": "rare", "effect": "crit_damage", "value": 0.16},

	# ============================================================
	# EPIC TIER (50 items) — 24 character-specific + 26 universal
	# 2-3 effects + special + per_level 0.02, values 0.15-0.25
	# ============================================================

	# --- Robin Hood (2 Epic) ---
	{"id": "rh_e1", "name": "Bow of the Green Knight", "desc": "+20% dmg, +15% range, split arrows", "tier": "epic", "effects": [{"effect": "damage", "value": 0.20}, {"effect": "range", "value": 0.15}], "special": "split_arrow_3", "per_level": 0.02, "character": "robin_hood"},
	{"id": "rh_e2", "name": "Sherwood Heart Oak", "desc": "+18% crit, +15% dodge, +12% attack speed", "tier": "epic", "effects": [{"effect": "crit", "value": 0.18}, {"effect": "dodge", "value": 0.15}, {"effect": "attack_speed", "value": 0.12}], "special": "vine_pull_enemies", "per_level": 0.02, "character": "robin_hood"},

	# --- Alice (2 Epic) ---
	{"id": "al_e1", "name": "Vorpal Blade", "desc": "+22% dmg, +15% crit, execute on low HP", "tier": "epic", "effects": [{"effect": "damage", "value": 0.22}, {"effect": "crit", "value": 0.15}], "special": "crit_every_5th_3x", "per_level": 0.02, "character": "alice"},
	{"id": "al_e2", "name": "Queen's Croquet Mallet", "desc": "+18% splash, +15% stun, +12% damage", "tier": "epic", "effects": [{"effect": "splash_radius", "value": 0.18}, {"effect": "stun", "value": 0.15}, {"effect": "damage", "value": 0.12}], "special": "double_stun_duration", "per_level": 0.02, "character": "alice"},

	# --- Wicked Witch (2 Epic) ---
	{"id": "ww_e1", "name": "Emerald City Crown", "desc": "+20% dmg, +18% slow, bewitch", "tier": "epic", "effects": [{"effect": "damage", "value": 0.20}, {"effect": "slow", "value": 0.18}], "special": "bewitch_slow_30pct", "per_level": 0.02, "character": "wicked_witch"},
	{"id": "ww_e2", "name": "Flying Monkey Scepter", "desc": "+17% range, +15% chain, +12% burn", "tier": "epic", "effects": [{"effect": "range", "value": 0.17}, {"effect": "chain", "value": 0.15}, {"effect": "burn", "value": 0.12}], "special": "chain_lightning_3", "per_level": 0.02, "character": "wicked_witch"},

	# --- Peter Pan (2 Epic) ---
	{"id": "pp_e1", "name": "Neverland Star Map", "desc": "+20% range, +15% dodge, ignore terrain", "tier": "epic", "effects": [{"effect": "range", "value": 0.20}, {"effect": "dodge", "value": 0.15}], "special": "ignore_terrain", "per_level": 0.02, "character": "peter_pan"},
	{"id": "pp_e2", "name": "Hook's Enchanted Cutlass", "desc": "+22% dmg, +15% armor_pierce, +12% crit", "tier": "epic", "effects": [{"effect": "damage", "value": 0.22}, {"effect": "armor_pierce", "value": 0.15}, {"effect": "crit", "value": 0.12}], "special": "ramping_damage_1pct", "per_level": 0.02, "character": "peter_pan"},

	# --- Phantom (2 Epic) ---
	{"id": "ph_e1", "name": "Organ of Despair", "desc": "+20% dmg, +15% debuff_amp, +12% aura_range", "tier": "epic", "effects": [{"effect": "damage", "value": 0.20}, {"effect": "debuff_amp", "value": 0.15}, {"effect": "aura_range", "value": 0.12}], "special": "weakness_expose_25pct", "per_level": 0.02, "character": "phantom"},
	{"id": "ph_e2", "name": "Christine's Locket", "desc": "+18% crit, +15% crit_damage, lifesteal", "tier": "epic", "effects": [{"effect": "crit", "value": 0.18}, {"effect": "crit_damage", "value": 0.15}], "special": "life_steal_5pct", "per_level": 0.02, "character": "phantom"},

	# --- Scrooge (2 Epic) ---
	{"id": "sc_e1", "name": "Ghost of Christmas Future", "desc": "+20% gold, +15% boss_dmg, double kill gold", "tier": "epic", "effects": [{"effect": "gold_bonus", "value": 0.20}, {"effect": "boss_damage", "value": 0.15}], "special": "double_kill_gold", "per_level": 0.02, "character": "scrooge"},
	{"id": "sc_e2", "name": "Tiny Tim's Crutch", "desc": "+18% heal, +15% aura_range, +12% defense", "tier": "epic", "effects": [{"effect": "heal_nearby", "value": 0.18}, {"effect": "aura_range", "value": 0.15}, {"effect": "defense", "value": 0.12}], "special": "regen_1_life_per_wave", "per_level": 0.02, "character": "scrooge"},

	# --- Sherlock (2 Epic) ---
	{"id": "sh_e1", "name": "Reichenbach Deduction", "desc": "+22% dmg, +15% crit, every 5th crit 3x", "tier": "epic", "effects": [{"effect": "damage", "value": 0.22}, {"effect": "crit", "value": 0.15}], "special": "crit_every_5th_3x", "per_level": 0.02, "character": "sherlock"},
	{"id": "sh_e2", "name": "Irene's Photograph", "desc": "+18% debuff_amp, +15% range, weakness expose", "tier": "epic", "effects": [{"effect": "debuff_amp", "value": 0.18}, {"effect": "range", "value": 0.15}], "special": "weakness_expose_25pct", "per_level": 0.02, "character": "sherlock"},

	# --- Tarzan (2 Epic) ---
	{"id": "tz_e1", "name": "Lord of the Apes Crown", "desc": "+20% dmg, +15% attack_speed, +12% defense", "tier": "epic", "effects": [{"effect": "damage", "value": 0.20}, {"effect": "attack_speed", "value": 0.15}, {"effect": "defense", "value": 0.12}], "special": "vine_pull_enemies", "per_level": 0.02, "character": "tarzan"},
	{"id": "tz_e2", "name": "Mangani War Paint", "desc": "+18% crit, +15% lifesteal, ramping damage", "tier": "epic", "effects": [{"effect": "crit", "value": 0.18}, {"effect": "lifesteal", "value": 0.15}], "special": "ramping_damage_1pct", "per_level": 0.02, "character": "tarzan"},

	# --- Dracula (2 Epic) ---
	{"id": "dr_e1", "name": "Vlad's Impaler Stake", "desc": "+22% dmg, +15% pierce, +12% lifesteal", "tier": "epic", "effects": [{"effect": "damage", "value": 0.22}, {"effect": "pierce", "value": 0.15}, {"effect": "lifesteal", "value": 0.12}], "special": "life_steal_5pct", "per_level": 0.02, "character": "dracula"},
	{"id": "dr_e2", "name": "Nocturne Cloak", "desc": "+20% dodge, +15% attack_speed, poison bite", "tier": "epic", "effects": [{"effect": "dodge", "value": 0.20}, {"effect": "attack_speed", "value": 0.15}], "special": "poison_dot", "per_level": 0.02, "character": "dracula"},

	# --- Merlin (2 Epic) ---
	{"id": "mr_e1", "name": "Crystal Cave Focus", "desc": "+20% range, +18% aura_range, element cycle", "tier": "epic", "effects": [{"effect": "range", "value": 0.20}, {"effect": "aura_range", "value": 0.18}], "special": "element_cycle", "per_level": 0.02, "character": "merlin"},
	{"id": "mr_e2", "name": "Nimue's Blessing", "desc": "+18% cooldown_red, +15% heal, +12% defense", "tier": "epic", "effects": [{"effect": "cooldown_reduction", "value": 0.18}, {"effect": "heal_nearby", "value": 0.15}, {"effect": "defense", "value": 0.12}], "special": "revive_once_50pct", "per_level": 0.02, "character": "merlin"},

	# --- Frankenstein (2 Epic) ---
	{"id": "fr_e1", "name": "Lightning Rod Array", "desc": "+22% chain, +15% stun, chain lightning", "tier": "epic", "effects": [{"effect": "chain", "value": 0.22}, {"effect": "stun", "value": 0.15}], "special": "chain_lightning_3", "per_level": 0.02, "character": "frankenstein"},
	{"id": "fr_e2", "name": "Reanimation Serum", "desc": "+18% attack_speed, +15% damage, +12% lifesteal", "tier": "epic", "effects": [{"effect": "attack_speed", "value": 0.18}, {"effect": "damage", "value": 0.15}, {"effect": "lifesteal", "value": 0.12}], "special": "revive_once_50pct", "per_level": 0.02, "character": "frankenstein"},

	# --- Shadow Author (2 Epic) ---
	{"id": "sa_e1", "name": "Inkwell of Rewriting", "desc": "+20% dmg, +15% debuff_amp, weakness expose", "tier": "epic", "effects": [{"effect": "damage", "value": 0.20}, {"effect": "debuff_amp", "value": 0.15}], "special": "weakness_expose_25pct", "per_level": 0.02, "character": "shadow_author"},
	{"id": "sa_e2", "name": "Chapter of Foreshadowing", "desc": "+18% cooldown_red, +15% crit, +12% range", "tier": "epic", "effects": [{"effect": "cooldown_reduction", "value": 0.18}, {"effect": "crit", "value": 0.15}, {"effect": "range", "value": 0.12}], "special": "activated_double_damage_10s", "per_level": 0.02, "character": "shadow_author"},

	# --- Universal Epic (26 items) ---
	{"id": "ue_01", "name": "Dragonbone Warbow", "desc": "+22% dmg, +15% pierce, split arrows", "tier": "epic", "effects": [{"effect": "damage", "value": 0.22}, {"effect": "pierce", "value": 0.15}], "special": "split_arrow_3", "per_level": 0.02},
	{"id": "ue_02", "name": "Frostfire Orb", "desc": "+18% burn, +15% slow, element cycle", "tier": "epic", "effects": [{"effect": "burn", "value": 0.18}, {"effect": "slow", "value": 0.15}], "special": "element_cycle", "per_level": 0.02},
	{"id": "ue_03", "name": "Titan's Girdle", "desc": "+22% defense, +15% damage, +12% stun", "tier": "epic", "effects": [{"effect": "defense", "value": 0.22}, {"effect": "damage", "value": 0.15}, {"effect": "stun", "value": 0.12}], "special": "double_stun_duration", "per_level": 0.02},
	{"id": "ue_04", "name": "Phantom Dancer Boots", "desc": "+20% dodge, +15% attack_speed, +12% crit", "tier": "epic", "effects": [{"effect": "dodge", "value": 0.20}, {"effect": "attack_speed", "value": 0.15}, {"effect": "crit", "value": 0.12}], "special": "ramping_damage_1pct", "per_level": 0.02},
	{"id": "ue_05", "name": "Midas Gloves", "desc": "+22% gold_bonus, +15% boss_damage", "tier": "epic", "effects": [{"effect": "gold_bonus", "value": 0.22}, {"effect": "boss_damage", "value": 0.15}], "special": "double_kill_gold", "per_level": 0.02},
	{"id": "ue_06", "name": "Nightshade Extract", "desc": "+20% poison, +15% debuff_amp, poison DoT", "tier": "epic", "effects": [{"effect": "poison", "value": 0.20}, {"effect": "debuff_amp", "value": 0.15}], "special": "poison_dot", "per_level": 0.02},
	{"id": "ue_07", "name": "Eagle Eye Scope", "desc": "+25% range, +15% crit", "tier": "epic", "effects": [{"effect": "range", "value": 0.25}, {"effect": "crit", "value": 0.15}], "special": "ignore_terrain", "per_level": 0.02},
	{"id": "ue_08", "name": "Berserker's Blood Paint", "desc": "+22% damage, +18% attack_speed", "tier": "epic", "effects": [{"effect": "damage", "value": 0.22}, {"effect": "attack_speed", "value": 0.18}], "special": "ramping_damage_1pct", "per_level": 0.02},
	{"id": "ue_09", "name": "Templar Shield", "desc": "+22% defense, +15% heal_nearby, revive once", "tier": "epic", "effects": [{"effect": "defense", "value": 0.22}, {"effect": "heal_nearby", "value": 0.15}], "special": "revive_once_50pct", "per_level": 0.02},
	{"id": "ue_10", "name": "Chain Lightning Coil", "desc": "+20% chain, +15% stun, chain lightning 3", "tier": "epic", "effects": [{"effect": "chain", "value": 0.20}, {"effect": "stun", "value": 0.15}], "special": "chain_lightning_3", "per_level": 0.02},
	{"id": "ue_11", "name": "Sniper's Focus Crystal", "desc": "+20% crit, +18% crit_damage, 5th crit 3x", "tier": "epic", "effects": [{"effect": "crit", "value": 0.20}, {"effect": "crit_damage", "value": 0.18}], "special": "crit_every_5th_3x", "per_level": 0.02},
	{"id": "ue_12", "name": "Soul Harvest Scythe", "desc": "+20% damage, +15% lifesteal, life steal 5%", "tier": "epic", "effects": [{"effect": "damage", "value": 0.20}, {"effect": "lifesteal", "value": 0.15}], "special": "life_steal_5pct", "per_level": 0.02},
	{"id": "ue_13", "name": "War Cry Totem", "desc": "+18% aura_range, +15% aura_speed, +12% damage", "tier": "epic", "effects": [{"effect": "aura_range", "value": 0.18}, {"effect": "aura_speed", "value": 0.15}, {"effect": "damage", "value": 0.12}], "special": "activated_double_damage_10s", "per_level": 0.02},
	{"id": "ue_14", "name": "Demolisher's Payload", "desc": "+22% splash_radius, +15% burn, +12% damage", "tier": "epic", "effects": [{"effect": "splash_radius", "value": 0.22}, {"effect": "burn", "value": 0.15}, {"effect": "damage", "value": 0.12}], "special": "bewitch_slow_30pct", "per_level": 0.02},
	{"id": "ue_15", "name": "Sentinel's Watch Helm", "desc": "+20% range, +15% defense, weakness expose", "tier": "epic", "effects": [{"effect": "range", "value": 0.20}, {"effect": "defense", "value": 0.15}], "special": "weakness_expose_25pct", "per_level": 0.02},
	{"id": "ue_16", "name": "Spider Silk Garrote", "desc": "+18% slow, +15% poison, +12% debuff_amp", "tier": "epic", "effects": [{"effect": "slow", "value": 0.18}, {"effect": "poison", "value": 0.15}, {"effect": "debuff_amp", "value": 0.12}], "special": "poison_dot", "per_level": 0.02},
	{"id": "ue_17", "name": "Chrono Gear", "desc": "+22% cooldown_red, +15% attack_speed", "tier": "epic", "effects": [{"effect": "cooldown_reduction", "value": 0.22}, {"effect": "attack_speed", "value": 0.15}], "special": "activated_double_damage_10s", "per_level": 0.02},
	{"id": "ue_18", "name": "Boss Hunter's Trophy", "desc": "+22% boss_damage, +15% armor_pierce, +12% crit", "tier": "epic", "effects": [{"effect": "boss_damage", "value": 0.22}, {"effect": "armor_pierce", "value": 0.15}, {"effect": "crit", "value": 0.12}], "special": "ramping_damage_1pct", "per_level": 0.02},
	{"id": "ue_19", "name": "Leech King's Fang", "desc": "+20% lifesteal, +15% poison, life steal 5%", "tier": "epic", "effects": [{"effect": "lifesteal", "value": 0.20}, {"effect": "poison", "value": 0.15}], "special": "life_steal_5pct", "per_level": 0.02},
	{"id": "ue_20", "name": "Multi-Bolt Crossbow", "desc": "+18% multi_shot, +15% damage, +12% attack_speed", "tier": "epic", "effects": [{"effect": "multi_shot", "value": 0.18}, {"effect": "damage", "value": 0.15}, {"effect": "attack_speed", "value": 0.12}], "special": "split_arrow_3", "per_level": 0.02},
	{"id": "ue_21", "name": "Guardian's Oath Ring", "desc": "+20% heal_nearby, +18% aura_range", "tier": "epic", "effects": [{"effect": "heal_nearby", "value": 0.20}, {"effect": "aura_range", "value": 0.18}], "special": "regen_1_life_per_wave", "per_level": 0.02},
	{"id": "ue_22", "name": "Firestorm Catalyst", "desc": "+22% burn, +15% splash_radius, +12% damage", "tier": "epic", "effects": [{"effect": "burn", "value": 0.22}, {"effect": "splash_radius", "value": 0.15}, {"effect": "damage", "value": 0.12}], "special": "element_cycle", "per_level": 0.02},
	{"id": "ue_23", "name": "Windwalker Cloak", "desc": "+22% dodge, +15% attack_speed, ignore terrain", "tier": "epic", "effects": [{"effect": "dodge", "value": 0.22}, {"effect": "attack_speed", "value": 0.15}], "special": "ignore_terrain", "per_level": 0.02},
	{"id": "ue_24", "name": "Executioner's Verdict", "desc": "+20% execute, +15% crit, +12% boss_damage", "tier": "epic", "effects": [{"effect": "execute", "value": 0.20}, {"effect": "crit", "value": 0.15}, {"effect": "boss_damage", "value": 0.12}], "special": "crit_every_5th_3x", "per_level": 0.02},
	{"id": "ue_25", "name": "Magnetic Rail", "desc": "+20% pierce, +18% damage, vine pull", "tier": "epic", "effects": [{"effect": "pierce", "value": 0.20}, {"effect": "damage", "value": 0.18}], "special": "vine_pull_enemies", "per_level": 0.02},
	{"id": "ue_26", "name": "Thunder Drum", "desc": "+18% stun, +15% aura_range, +12% chain", "tier": "epic", "effects": [{"effect": "stun", "value": 0.18}, {"effect": "aura_range", "value": 0.15}, {"effect": "chain", "value": 0.12}], "special": "double_stun_duration", "per_level": 0.02},

	# ============================================================
	# LEGENDARY TIER (25 items) — 12 character-specific + 13 universal
	# 2-3 effects + powerful special + per_level 0.025, values 0.20-0.30
	# ============================================================

	# --- Robin Hood (1 Legendary) ---
	{"id": "rh_l1", "name": "The Silver Arrow of Sherwood", "desc": "+28% dmg, +22% range, +18% crit — infinite pierce", "tier": "legendary", "effects": [{"effect": "damage", "value": 0.28}, {"effect": "range", "value": 0.22}, {"effect": "crit", "value": 0.18}], "special": "infinite_pierce", "per_level": 0.025, "character": "robin_hood"},

	# --- Alice (1 Legendary) ---
	{"id": "al_l1", "name": "The Jabberwock's Eye", "desc": "+25% dmg, +22% crit, +20% crit_dmg — crit 25% 5x", "tier": "legendary", "effects": [{"effect": "damage", "value": 0.25}, {"effect": "crit", "value": 0.22}, {"effect": "crit_damage", "value": 0.20}], "special": "crit_25pct_5x", "per_level": 0.025, "character": "alice"},

	# --- Wicked Witch (1 Legendary) ---
	{"id": "ww_l1", "name": "The Grimmerie", "desc": "+26% dmg, +22% debuff_amp, +18% slow — aura burn all", "tier": "legendary", "effects": [{"effect": "damage", "value": 0.26}, {"effect": "debuff_amp", "value": 0.22}, {"effect": "slow", "value": 0.18}], "special": "aura_burn_all", "per_level": 0.025, "character": "wicked_witch"},

	# --- Peter Pan (1 Legendary) ---
	{"id": "pp_l1", "name": "The Second Star", "desc": "+25% dmg, +22% dodge, +20% attack_speed — double projectile", "tier": "legendary", "effects": [{"effect": "damage", "value": 0.25}, {"effect": "dodge", "value": 0.22}, {"effect": "attack_speed", "value": 0.20}], "special": "double_projectile", "per_level": 0.025, "character": "peter_pan"},

	# --- Phantom (1 Legendary) ---
	{"id": "ph_l1", "name": "The Music of the Night", "desc": "+28% dmg, +22% debuff_amp, +18% aura_range — activated 2x dmg 10s", "tier": "legendary", "effects": [{"effect": "damage", "value": 0.28}, {"effect": "debuff_amp", "value": 0.22}, {"effect": "aura_range", "value": 0.18}], "special": "activated_double_damage_10s", "per_level": 0.025, "character": "phantom"},

	# --- Scrooge (1 Legendary) ---
	{"id": "sc_l1", "name": "Scrooge's Redemption Ledger", "desc": "+28% gold, +22% boss_dmg, +18% heal — double all gold", "tier": "legendary", "effects": [{"effect": "gold_bonus", "value": 0.28}, {"effect": "boss_damage", "value": 0.22}, {"effect": "heal_nearby", "value": 0.18}], "special": "double_all_gold", "per_level": 0.025, "character": "scrooge"},

	# --- Sherlock (1 Legendary) ---
	{"id": "sh_l1", "name": "The Art of Deduction", "desc": "+26% crit, +22% range, +20% debuff_amp — global buff 10%", "tier": "legendary", "effects": [{"effect": "crit", "value": 0.26}, {"effect": "range", "value": 0.22}, {"effect": "debuff_amp", "value": 0.20}], "special": "global_buff_10pct", "per_level": 0.025, "character": "sherlock"},

	# --- Tarzan (1 Legendary) ---
	{"id": "tz_l1", "name": "Heart of the Jungle", "desc": "+28% dmg, +22% attack_speed, +20% lifesteal — death explosion 50%", "tier": "legendary", "effects": [{"effect": "damage", "value": 0.28}, {"effect": "attack_speed", "value": 0.22}, {"effect": "lifesteal", "value": 0.20}], "special": "death_explosion_50pct", "per_level": 0.025, "character": "tarzan"},

	# --- Dracula (1 Legendary) ---
	{"id": "dr_l1", "name": "Nosferatu's Crimson Throne", "desc": "+25% dmg, +25% lifesteal, +20% dodge — life save once", "tier": "legendary", "effects": [{"effect": "damage", "value": 0.25}, {"effect": "lifesteal", "value": 0.25}, {"effect": "dodge", "value": 0.20}], "special": "life_save_once", "per_level": 0.025, "character": "dracula"},

	# --- Merlin (1 Legendary) ---
	{"id": "mr_l1", "name": "The Siege Perilous", "desc": "+25% aura_range, +22% cooldown_red, +20% heal — global buff 10%", "tier": "legendary", "effects": [{"effect": "aura_range", "value": 0.25}, {"effect": "cooldown_reduction", "value": 0.22}, {"effect": "heal_nearby", "value": 0.20}], "special": "global_buff_10pct", "per_level": 0.025, "character": "merlin"},

	# --- Frankenstein (1 Legendary) ---
	{"id": "fr_l1", "name": "The Promethean Spark", "desc": "+28% chain, +22% stun, +20% damage — death explosion 50%", "tier": "legendary", "effects": [{"effect": "chain", "value": 0.28}, {"effect": "stun", "value": 0.22}, {"effect": "damage", "value": 0.20}], "special": "death_explosion_50pct", "per_level": 0.025, "character": "frankenstein"},

	# --- Shadow Author (1 Legendary) ---
	{"id": "sa_l1", "name": "The Unwritten Ending", "desc": "+26% dmg, +22% cooldown_red, +20% debuff_amp — activated time stop 5s", "tier": "legendary", "effects": [{"effect": "damage", "value": 0.26}, {"effect": "cooldown_reduction", "value": 0.22}, {"effect": "debuff_amp", "value": 0.20}], "special": "activated_time_stop_5s", "per_level": 0.025, "character": "shadow_author"},

	# --- Universal Legendary (13 items) ---
	{"id": "ul_01", "name": "Crown of the Conqueror", "desc": "+30% dmg, +22% crit, +18% armor_pierce — crit 25% 5x", "tier": "legendary", "effects": [{"effect": "damage", "value": 0.30}, {"effect": "crit", "value": 0.22}, {"effect": "armor_pierce", "value": 0.18}], "special": "crit_25pct_5x", "per_level": 0.025},
	{"id": "ul_02", "name": "Aegis of the Fallen", "desc": "+28% defense, +22% heal, +18% aura_range — life save once", "tier": "legendary", "effects": [{"effect": "defense", "value": 0.28}, {"effect": "heal_nearby", "value": 0.22}, {"effect": "aura_range", "value": 0.18}], "special": "life_save_once", "per_level": 0.025},
	{"id": "ul_03", "name": "Stormcaller's Gauntlet", "desc": "+25% chain, +22% stun, +18% damage — chain lightning 3", "tier": "legendary", "effects": [{"effect": "chain", "value": 0.25}, {"effect": "stun", "value": 0.22}, {"effect": "damage", "value": 0.18}], "special": "chain_lightning_3", "per_level": 0.025},
	{"id": "ul_04", "name": "The Gilded Compass", "desc": "+28% gold, +22% range, +18% dodge — double all gold", "tier": "legendary", "effects": [{"effect": "gold_bonus", "value": 0.28}, {"effect": "range", "value": 0.22}, {"effect": "dodge", "value": 0.18}], "special": "double_all_gold", "per_level": 0.025},
	{"id": "ul_05", "name": "Hellfire Crucible", "desc": "+28% burn, +22% splash, +20% damage — aura burn all", "tier": "legendary", "effects": [{"effect": "burn", "value": 0.28}, {"effect": "splash_radius", "value": 0.22}, {"effect": "damage", "value": 0.20}], "special": "aura_burn_all", "per_level": 0.025},
	{"id": "ul_06", "name": "Wraithbane", "desc": "+30% boss_damage, +22% armor_pierce, +18% execute — infinite pierce", "tier": "legendary", "effects": [{"effect": "boss_damage", "value": 0.30}, {"effect": "armor_pierce", "value": 0.22}, {"effect": "execute", "value": 0.18}], "special": "infinite_pierce", "per_level": 0.025},
	{"id": "ul_07", "name": "Timekeeper's Hourglass", "desc": "+25% cooldown_red, +22% attack_speed, +18% range — activated time stop 5s", "tier": "legendary", "effects": [{"effect": "cooldown_reduction", "value": 0.25}, {"effect": "attack_speed", "value": 0.22}, {"effect": "range", "value": 0.18}], "special": "activated_time_stop_5s", "per_level": 0.025},
	{"id": "ul_08", "name": "Bloodmoon Talisman", "desc": "+25% lifesteal, +22% damage, +20% crit — life steal 5%", "tier": "legendary", "effects": [{"effect": "lifesteal", "value": 0.25}, {"effect": "damage", "value": 0.22}, {"effect": "crit", "value": 0.20}], "special": "life_steal_5pct", "per_level": 0.025},
	{"id": "ul_09", "name": "Oblivion's Edge", "desc": "+28% damage, +22% pierce, +20% attack_speed — double projectile", "tier": "legendary", "effects": [{"effect": "damage", "value": 0.28}, {"effect": "pierce", "value": 0.22}, {"effect": "attack_speed", "value": 0.20}], "special": "double_projectile", "per_level": 0.025},
	{"id": "ul_10", "name": "Winter's Embrace", "desc": "+28% slow, +22% debuff_amp, +18% defense — bewitch slow 30%", "tier": "legendary", "effects": [{"effect": "slow", "value": 0.28}, {"effect": "debuff_amp", "value": 0.22}, {"effect": "defense", "value": 0.18}], "special": "bewitch_slow_30pct", "per_level": 0.025},
	{"id": "ul_11", "name": "The Commander's Banner", "desc": "+25% aura_range, +22% aura_speed, +20% damage — global buff 10%", "tier": "legendary", "effects": [{"effect": "aura_range", "value": 0.25}, {"effect": "aura_speed", "value": 0.22}, {"effect": "damage", "value": 0.20}], "special": "global_buff_10pct", "per_level": 0.025},
	{"id": "ul_12", "name": "Viperstrike Gauntlet", "desc": "+25% poison, +22% attack_speed, +18% debuff_amp — poison DoT", "tier": "legendary", "effects": [{"effect": "poison", "value": 0.25}, {"effect": "attack_speed", "value": 0.22}, {"effect": "debuff_amp", "value": 0.18}], "special": "poison_dot", "per_level": 0.025},
	{"id": "ul_13", "name": "Bulwark of Ages", "desc": "+30% defense, +22% stun, +20% heal — revive once 50%", "tier": "legendary", "effects": [{"effect": "defense", "value": 0.30}, {"effect": "stun", "value": 0.22}, {"effect": "heal_nearby", "value": 0.20}], "special": "revive_once_50pct", "per_level": 0.025},

	# ============================================================
	# ANCIENT TIER (10 items) — all universal, endgame mythology artifacts
	# 3+ effects + unique special + per_level 0.03, values 0.25-0.40
	# ============================================================

	# 1. Shard of Excalibur — Arthurian
	{"id": "anc_01", "name": "Shard of Excalibur", "desc": "+35% dmg, +28% crit, +25% crit_dmg — crit 25% 5x multiplier", "tier": "ancient", "effects": [{"effect": "damage", "value": 0.35}, {"effect": "crit", "value": 0.28}, {"effect": "crit_damage", "value": 0.25}], "special": "crit_25pct_5x", "per_level": 0.03},

	# 2. Phoenix Plume — Greek
	{"id": "anc_02", "name": "Phoenix Plume", "desc": "+30% lifesteal, +28% heal, +25% defense — regen 1 life per wave", "tier": "ancient", "effects": [{"effect": "lifesteal", "value": 0.30}, {"effect": "heal_nearby", "value": 0.28}, {"effect": "defense", "value": 0.25}], "special": "regen_1_life_per_wave", "per_level": 0.03},

	# 3. Mjolnir Fragment — Norse
	{"id": "anc_03", "name": "Mjolnir Fragment", "desc": "+35% chain, +28% stun, +25% damage — chain lightning 3 + double stun", "tier": "ancient", "effects": [{"effect": "chain", "value": 0.35}, {"effect": "stun", "value": 0.28}, {"effect": "damage", "value": 0.25}], "special": "chain_lightning_3", "per_level": 0.03},

	# 4. Eye of Ra — Egyptian
	{"id": "anc_04", "name": "Eye of Ra", "desc": "+35% burn, +30% boss_dmg, +25% splash — aura burn all", "tier": "ancient", "effects": [{"effect": "burn", "value": 0.35}, {"effect": "boss_damage", "value": 0.30}, {"effect": "splash_radius", "value": 0.25}], "special": "aura_burn_all", "per_level": 0.03},

	# 5. Dragon Scale — Universal
	{"id": "anc_05", "name": "Dragon Scale", "desc": "+35% defense, +28% all stats, +25% heal — life save once", "tier": "ancient", "effects": [{"effect": "defense", "value": 0.35}, {"effect": "all", "value": 0.28}, {"effect": "heal_nearby", "value": 0.25}], "special": "life_save_once", "per_level": 0.03},

	# 6. Philosopher's Stone — Alchemy
	{"id": "anc_06", "name": "Philosopher's Stone", "desc": "+40% gold, +30% boss_dmg, +25% cooldown_red — double all gold", "tier": "ancient", "effects": [{"effect": "gold_bonus", "value": 0.40}, {"effect": "boss_damage", "value": 0.30}, {"effect": "cooldown_reduction", "value": 0.25}], "special": "double_all_gold", "per_level": 0.03},

	# 7. Pandora's Shard — Greek (all effects but cursed)
	{"id": "anc_07", "name": "Pandora's Shard", "desc": "+25% all stats, +25% debuff_amp, +25% damage — global buff 10%", "tier": "ancient", "effects": [{"effect": "all", "value": 0.25}, {"effect": "debuff_amp", "value": 0.25}, {"effect": "damage", "value": 0.25}], "special": "global_buff_10pct", "per_level": 0.03},

	# 8. Yggdrasil Bark — Norse
	{"id": "anc_08", "name": "Yggdrasil Bark", "desc": "+35% heal, +30% aura_range, +25% defense — regen 1 life per wave", "tier": "ancient", "effects": [{"effect": "heal_nearby", "value": 0.35}, {"effect": "aura_range", "value": 0.30}, {"effect": "defense", "value": 0.25}], "special": "regen_1_life_per_wave", "per_level": 0.03},

	# 9. Leviathan Tooth — Biblical
	{"id": "anc_09", "name": "Leviathan Tooth", "desc": "+35% pierce, +30% splash, +28% damage — infinite pierce", "tier": "ancient", "effects": [{"effect": "pierce", "value": 0.35}, {"effect": "splash_radius", "value": 0.30}, {"effect": "damage", "value": 0.28}], "special": "infinite_pierce", "per_level": 0.03},

	# 10. Void Ink — Shadow Author endgame
	{"id": "anc_10", "name": "Void Ink", "desc": "+35% dmg, +30% cooldown_red, +28% debuff_amp — activated time stop 5s", "tier": "ancient", "effects": [{"effect": "damage", "value": 0.35}, {"effect": "cooldown_reduction", "value": 0.30}, {"effect": "debuff_amp", "value": 0.28}], "special": "activated_time_stop_5s", "per_level": 0.03},
]
