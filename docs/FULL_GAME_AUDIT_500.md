# Shadow Defense -- Full Game Audit (500 Findings)

**Audited:** `scripts/main.gd` (43,962 lines), `scripts/main_head.gd` (29,006 lines), plus 45 other `.gd` files
**Date:** 2026-05-29
**Scope:** Read-only analysis. No code modified.

---

## TABLE OF CONTENTS

1. [Architecture Issues (1-25)](#1-architecture-issues)
2. [Duplicate / Conflicting Code (26-50)](#2-duplicate--conflicting-code)
3. [Game Systems -- Tower Defense Core (51-80)](#3-game-systems----tower-defense-core)
4. [Character / Survivor System (81-120)](#4-character--survivor-system)
5. [Gear System (121-165)](#5-gear-system)
6. [Achievement System (166-195)](#6-achievement-system)
7. [Loot / Chest System (196-220)](#7-loot--chest-system)
8. [Progression System (221-260)](#8-progression-system)
9. [Economy / Currency (261-300)](#9-economy--currency)
10. [Shop / Emporium (301-330)](#10-shop--emporium)
11. [Story / Dialog System (331-355)](#11-story--dialog-system)
12. [Save / Load System (356-385)](#12-save--load-system)
13. [Music / Audio (386-410)](#13-music--audio)
14. [Visual Systems (411-440)](#14-visual-systems)
15. [Bugs / Issues (441-475)](#15-bugs--issues)
16. [Dead Code (476-490)](#16-dead-code)
17. [Balance Issues (491-500)](#17-balance-issues)

---

## 1. Architecture Issues

**1.** `main.gd` is 43,962 lines -- one of the largest single-file game scripts ever written in GDScript. Needs decomposition.
**2.** `main_head.gd` (29,006 lines) is an OLDER version of `main.gd` with only 12 TowerTypes in its enum (no ACT 4 characters). It appears to be dead/backup code.
**3.** The `main.gd` file contains data definitions, game logic, UI rendering, audio, save/load, and 500+ functions in a single class.
**4.** All UI is drawn procedurally via `_draw()` instead of using Godot's scene tree / Control nodes -- makes the file enormous.
**5.** There are 27+ separate "BATTD FEATURE" sections added incrementally, each appending state variables without refactoring.
**6.** The enum `TowerType` has grown to 20 entries (12 original + 8 ACT 4 characters) but many systems still hardcode index 0-11.
**7.** Many variable declarations appear twice -- once in lines 1-1000 (original block) and again in lines 2500-3900 (extended block), with different values.
**8.** The `_draw()` function at line 24381 is called every frame and contains the entire game rendering pipeline (~800+ lines of draw calls).
**9.** `_process()` at line 21722 handles all game tick logic in a single function (~500 lines).
**10.** No use of signals for game events -- everything is direct function calls.
**11.** `_input()` at line 23652 handles all input in one monolithic function (~300 lines).
**12.** Tower scripts (alice.gd=74K, dracula.gd=91K, etc.) are also extremely large individual files.
**13.** `enemy.gd` is 144,119 bytes (2,889 lines) -- the largest character script.
**14.** The `tower.gd` base class is only 726 lines -- most tower logic lives in individual character scripts.
**15.** No autoload/singleton pattern for global state -- everything lives on the main node.
**16.** Constants and data tables (gear items, achievements, quest templates) consume ~4,000 lines of the main file.
**17.** No type hints on many function parameters (e.g., `tower_type` is used as both int and enum throughout).
**18.** Color constants defined inline as `Color(r,g,b)` rather than named constants -- hundreds of occurrences.
**19.** The file has 5+ "music system" implementations layered on top of each other (procedural beat, layered music, polyrhythm).
**20.** `_ready()` at line 4171 calls 20+ initialization functions sequentially.
**21.** The `autoloads/` directory has 15 managers (accessibility, analytics, audio_cache, cloud_save, etc.) but most game logic bypasses them.
**22.** `main_menu_v2.gd` (4,265 lines) exists as a separate menu system but is loaded via `_load_menu_v2()` on demand.
**23.** Projectile scripts (bullet.gd, arrow.gd, blood_bolt.gd, etc.) are separate files -- good decomposition here.
**24.** Individual character scripts have their own complete upgrade/ability systems duplicated per character.
**25.** No use of Resources (.tres) for data -- all game data is hardcoded in GDScript dictionaries/arrays.

---

## 2. Duplicate / Conflicting Code

**26.** `selected_difficulty` declared at line 828 (`var selected_difficulty: int = 0`) AND again at line 2500 (`var selected_difficulty: int = 0`).
**27.** `difficulty_waves` defined at line 829 as `[20, 30, 40, 40]` AND at line 2506 as `[30, 40, 50, 60]` -- CONFLICTING VALUES. The second one overwrites.
**28.** `difficulty_fixed_lives` defined at line 832 AND line 2509 -- same values but duplicated.
**29.** `PURE_MODE` defined at line 833 AND line 2510 -- duplicate constant.
**30.** `player_quills` defined at line 838 AND line 2514.
**31.** `player_storybook_stars` defined at line 839 AND line 2516.
**32.** `player_gold` defined at line 840 AND line 2517.
**33.** `player_gear_shards` declared at line 838 in block 1 but replaced by `player_pages` at line 2515 in block 2. The old `player_gear_shards` currency is referenced in comments but no longer exists as a variable.
**34.** `chest_loot` declared at lines 843 and 2528.
**35.** `enemies_to_spawn`, `enemies_alive`, `spawn_timer`, `spawn_interval` all duplicated between block 1 and block 2.
**36.** `fast_forward` and `_game_speed_level` duplicated at lines 859/2544.
**37.** `game_paused` duplicated at lines 869/2559.
**38.** `sfx_muted` has CONFLICTING values: line 876 = `false`, line 2566 = `true` (SFX permanently disabled). Second one wins.
**39.** `placed_tower_positions` and `path_points` duplicated at lines 883/2572.
**40.** `_decorations` and `_time` duplicated at lines 887/2634 and 889/2654.
**41.** Shadow Author taunt system variables (`_sa_taunt_triggered`, `_sa_taunt_timer`, etc.) duplicated at lines 891-896 and 2657-2663.
**42.** Music system variables (`music_beat_index`, `music_player`, etc.) duplicated at lines 900-914 and 2670-2702.
**43.** Voice system variables duplicated at lines 912-921 and 2682-2692.
**44.** `_save_path` duplicated at lines 935 and 2705.
**45.** Emporium state variables duplicated at lines 937-951 and 2708-2721.
**46.** Chest opening variables duplicated at lines 954-961 and 2724-2731.
**47.** Victory chest variables duplicated at lines 964-968 and 2734-2737.
**48.** Knowledge tree variables duplicated at lines 972-977 and 2743-2748.
**49.** Daily rewards variables and schedule duplicated at lines 979-993 and 2750-2763. Block 1 uses `"shards"` type, block 2 uses `"pages"` type -- CONFLICTING.
**50.** Synergy variables duplicated at lines 996-999 and 2788-2792.

---

## 3. Game Systems -- Tower Defense Core

**51.** 12 base tower types: Robin Hood, Alice, Wicked Witch, Peter Pan, Phantom, Scrooge, Sherlock, Tarzan, Dracula, Merlin, Frankenstein, Shadow Author.
**52.** 8 ACT 4 tower types: Captain Hook, Queen of Hearts, Clayton, Headless Horseman, Medusa, Loki, Anubis, Captain Ahab (Ahab commented out/removed).
**53.** Tower costs range from 60G (Scrooge) to 300G (Loki/Anubis). Shadow Author costs 250G.
**54.** Fire rates range from 0.30 (Frankenstein -- slowest) to 1.00 (Loki -- fastest).
**55.** Damage ranges from 11 (Scrooge -- lowest) to 55 (Shadow Author -- highest).
**56.** Range values span 70.0 (Scrooge) to 200.0 (Robin Hood).
**57.** Only 6 towers are preloaded in `tower_scenes` -- the rest loaded at runtime after unlock.
**58.** Tower placement uses free placement with `MIN_PATH_DIST` (40.0) and `MIN_TOWER_DIST` (48.0) constraints.
**59.** `TOWER_SELECT_RADIUS` is 48.0 pixels for click-to-select.
**60.** Sell value appears to be a percentage of original cost (not documented in this file).
**61.** Tower repositioning costs 30% of base cost (`REPOSITION_COST_RATE = 0.30`).
**62.** Undo tower placement has a 3-second window (`UNDO_DURATION = 3.0`).
**63.** Wave system supports 10-60 waves depending on difficulty and level definition.
**64.** Difficulty modes: Easy (30 waves, 100 lives), Medium (40 waves, 50 lives), Hard (50 waves, 20 lives), Pure (60 waves, 1 life).
**65.** Auto-wave system with configurable delay: 1s, 2s, 3s, or 5s options.
**66.** Fast-forward multiplier exists via `_game_speed_level`.
**67.** Enemy spawning uses composition system -- waves mix normal, fast, armored, healer, shielded, swarm, elite, mini_boss, and boss types.
**68.** Enemy health scaling: Phase 1 (w1-5) 30-105 HP, Phase 6 (w33-40) 3400-5400 HP, with 1.25x global multiplier.
**69.** Enemy speed caps at 280.0 to prevent unplayable situations.
**70.** Boss waves at waves 20, 25, 30, 35 with 3.5x HP multiplier. Final wave boss has 12x HP and 3.5 scale.
**71.** MOAB villains spawn at waves 15/25/35 on Medium+ difficulty with 8x/20x/50x HP multipliers.
**72.** Commander enemies appear every 8th wave (from wave 6+) with 4 types: war_drum, standard_bearer, ink_priest, shadow_general.
**73.** Flying enemies have 5-10% chance on waves 8+, with 0.7x HP and 0.8x speed.
**74.** Difficulty multipliers: Easy=0.85x HP, Medium=1.0x, Hard=1.2x, Pure=1.5x.
**75.** Environmental events trigger randomly (~every 55 seconds) during waves -- 7 types including Ink Storm, Page Tear, Shadow Surge, Golden Hour.
**76.** Planning phase: 8 seconds of planning time before boss waves (5, 10, 15, 20, etc.).
**77.** Wave power-ups spawn every 12 seconds, last 8 seconds, max 3 active. Types: gold_bag, health_potion, boost_orb, speed_gem, gold_rush.
**78.** Path traps system: Spike Strip (30G, 50dmg x10 uses), Tar Pit (25G, 50% slow x8 uses), Fire Mine (50G, 150dmg x3 uses).
**79.** Tower sacrifice system exists (`_sacrifice_mode`).
**80.** Gold interest between waves: 5% rate, capped at 50G per wave.

---

## 4. Character / Survivor System

**81.** Max survivor level: 20 (`MAX_SURVIVOR_LEVEL`).
**82.** XP table follows BTD6-inspired sub-exponential curve: `[180, 460, 1000, 1860, 3280, 5180, 8320, 9380, 13620, 16380, 18200, 20100, 22100, 24200, 26400, 28800, 31400, 34200, 37200]`.
**83.** XP per wave: `WAVE_BASE_XP = 80.0` plus `WAVE_XP_GROWTH = 25.0` per wave number.
**84.** Difficulty XP multipliers: Easy=0.5x, Medium=1.0x, Hard=1.5x, Pure=3.0x.
**85.** Per-level bonuses: +3% damage, +2% range, +1.5% attack speed per level universally.
**86.** Role-specific extras per level (e.g., Robin Hood gets +2% range/level, Peter Pan gets +2% attack speed/level).
**87.** Named milestone power spikes at levels 4 (Awakening), 8 (Battle-Hardened), 12 (Veteran), 16 (Elite), 20 (Legendary).
**88.** Level 20 capstone: +25% damage, +15% range, +15% attack speed, +10% crit.
**89.** Character alignment system: Hero (Robin, Alice, Peter Pan, Sherlock, Tarzan, Merlin), Villain (Witch, Dracula, Hook, Queen, Clayton, Medusa, Horseman), Antihero (Phantom, Scrooge, Frankenstein, Shadow Author, Loki, Anubis).
**90.** Team composition bonuses: All Heroes (+10% dmg with 4+), All Villains (+12% dmg with 3+), Mixed (+8% all with 2+2), Antihero Trio (+15% CD speed with 3+).
**91.** Awakened Forms at level 20 for all 20 characters -- each gets a unique title, passive ability, and voice line.
**92.** Examples: Robin "Robin of the Emerald Arrow" (arrows pierce ALL), Alice "Queen of Logic" (+30% CD speed), Dracula "Vlad, The Redeemed Immortal" (heals 1 life per 10 kills).
**93.** 3-path upgrade system (BTD6-style): each character has 3 named paths with 3 tiers each.
**94.** Path costs: Tier 1 = 120G/120G/150G, Tier 2 = 350G/350G/400G, Tier 3 = 900G/900G/1200G.
**95.** Path restriction: max one path at tier 3, max two paths at tier 2+.
**96.** Character bonds between paired characters (+8% damage/speed when within 200 range): Robin+PeterPan, Alice+Witch, Phantom+Merlin, Scrooge+Frankenstein, Sherlock+Tarzan, Dracula+Merlin, plus 6 more pairs.
**97.** Bond dialog system: 12 unique conversations that trigger once per level when bonded characters are placed together.
**98.** Character home bonus: +10% all stats when placed on own chapter (`HOME_CHAPTER_BONUS`).
**99.** Character affinity system: +0.5 affinity per wave on home map, milestones at 10/25/50/75/100 with escalating bonuses.
**100.** Character descriptions stored in `survivor_descriptions` dictionary for all 12 base characters.
**101.** Character quotes stored in `character_quotes` array (12 entries).
**102.** Character novels stored in `character_novels` array -- references the original literary works.
**103.** Session damage tracking per character via `session_damage` dictionary.
**104.** Kill tracking per character in `survivor_progress[t]["total_kills"]`.
**105.** Kill milestones: 100 (Novice), 500, 1000 (Veteran), 5000, 10000 (Legend), 25000, 50000 (Mythic), 100000 (Prestige).
**106.** Progressive ability thresholds at damage milestones: 5K, 25K, 100K, 350K, 1M, 3M, 10M, 35M, 100M.
**107.** Spawn debuffs: Crystal Ball (-15% enemy HP) and Beneath the Opera (-30% enemy speed).
**108.** Each character has 3 sidekicks (defined in `survivor_sidekicks`) with unique descriptions.
**109.** Sidekick slots unlock at Golden Shield levels 3/6/9 (max 4 slots).
**110.** Sidekick bonuses: +5% damage (slot 1), +5% attack speed (slot 2), +10% gold (slot 3), +5% range (slot 4).
**111.** Awakening system costs: 500 shards + 50 quills per character.
**112.** Awakening passives: Rain of Arrows (Robin), Wonderland Chaos (Alice), Hex Storm (Witch), Never Grow Up (Peter Pan), Requiem (Phantom), Golden Touch (Scrooge).
**113.** Cosmic Ink: universal currency convertible to any character's XP (1 ink = 100 XP).
**114.** Stat respec system: base cost 50 pages, each respec costs 1.5x more.
**115.** Character mood system tracked via `_update_character_mood()`.
**116.** Trust system: `_increment_trust()`, `_get_trust_level()`, `_get_trust_title()`.
**117.** Character rank badges: Bronze (0), Silver (50), Gold (150), Platinum (350), Diamond (600), Mythic (1000).
**118.** Favorite characters: up to 3 can be pinned to top of grid.
**119.** Power rating system cached per character.
**120.** Level-up fanfare animation: 2.5 second duration with particles.

---

## 5. Gear System

**121.** 5 rarity tiers: Common, Uncommon, Rare, Epic, Legendary.
**122.** Tier colors: Common=gray, Uncommon=green, Rare=blue, Epic=purple, Legendary=gold.
**123.** Shard values: Common=10, Uncommon=25, Rare=100, Epic=300, Legendary=1000.
**124.** Total gear items in GEAR_ITEMS array: ~120+ items (36 common + 36 uncommon + 24 rare + 12 epic + 12 legendary).
**125.** Each of the 12 base characters has 3 Common items, 3 Uncommon items, 2 Rare items, 1 Epic item, 1 Legendary item.
**126.** Universal gear items exist at each tier (3 common, 3 uncommon, 3 rare, 3 epic).
**127.** Gear slot unlocks at survivor levels: 1, 1, 4, 8, 12, 16 (6 total slots).
**128.** Golden Shields system: 10 levels, XP costs `[100, 200, 350, 550, 800, 1100, 1500, 2000, 2800, 4000]`.
**129.** Gear effects include: damage, range, attack_speed, crit, crit_damage, slow, gold_bonus, lifesteal, burn, dodge, pierce, chain, splash_radius, armor_pierce, boss_damage, heal_nearby, execute, debuff_amp, aura_range, cooldown_reduction.
**130.** Epic gear has `per_level` scaling (0.02 per survivor level).
**131.** Legendary gear has `per_level` scaling (0.025 per survivor level).
**132.** Epic gear has `special` effects: split_arrow_3, bewitch_slow_30pct, poison_dot, ignore_terrain, double_stun_duration, double_kill_gold, crit_every_5th_3x, chain_lightning_3, life_steal_5pct, weakness_expose_25pct, vine_pull_enemies, element_cycle, ramping_damage_1pct, revive_once_50pct.
**133.** Legendary gear specials: activated_double_damage_10s, regen_1_life_per_wave, double_all_gold, global_buff_10pct, crit_25pct_5x, aura_burn_all, infinite_pierce, activated_time_stop_5s, death_explosion_50pct, life_save_once, double_projectile.
**134.** Character-specific gear (3+ same character pieces) gives +5% all stats per piece set bonus.
**135.** Gear set bonuses: Sherwood Ranger, Wonderland Chaos, Shadow Author, Gothic Horror -- each requires 3 specific pieces.
**136.** Gear crafting system with `CRAFTING_RECIPES`: 6 "ancient" tier recipes requiring pages/quills/ink.
**137.** Gear fusion system: combine 3 same-rarity items to get one of next tier.
**138.** Gear enchanting: costs 5 quills, applies random stat boost.
**139.** Gear reroll: costs 15 shards.
**140.** Gear loadout presets: up to 5 slots per character.
**141.** Gear locking system: prevents accidental salvage.
**142.** Gear comparison UI: shows stat differences.
**143.** Gear mastery: tracked per tower/gear combo, thresholds at 10/25/50/100 waves equipped, +5% effect per mastery level.
**144.** Gear collection codex: tracks all discovered gear IDs.
**145.** Gear wish list: up to 3 effect types.
**146.** Gear auto-equip function: `_auto_equip_best_gear()`.
**147.** Quick-equip from chest opening.
**148.** Pity timer: guaranteed Epic at 30 drops, guaranteed Legendary at 100 drops.
**149.** Lucky loot drop chance: 2% per kill.
**150.** Difficulty gear cap: Easy=up to uncommon, Medium=up to rare, Hard=up to epic, Pure=up to legendary.
**151.** Salvage rates: common=5, uncommon=15, rare=40, epic=120, legendary=400 (defined but `player_gear_shards` variable no longer exists -- migrated to `player_pages`).
**152.** Gear icon map: maps new gear IDs to procedural icon drawing keys.
**153.** Character-specific gear definitions in `survivor_gear` (old system, 12 items -- separate from GEAR_ITEMS).
**154.** Old `survivor_gear` system appears SUPERSEDED by `GEAR_ITEMS` but both exist in code.
**155.** Gear items with `"effects"` array use multi-stat format; items with single `"effect"` use simple format -- two different schemas coexist.
**156.** Mind Palace Key exists as both epic (id: `m_mind_palace_key`) and rare (id: `s_mind_palace_key`) -- potential confusion.
**157.** Literary Instruments: 6 aura support items (Harpsichord, Drums of War, Lyre, Flute, Organ, Violin) costing 100-175G.
**158.** Instruments are placed on the map and buff towers in radius.
**159.** Instrument picker UI controlled by `_instrument_picker_open`.
**160.** `owned_instruments` tracked as Dictionary (id -> count).
**161.** `placed_instruments` tracked as Array during gameplay.
**162.** Insta-towers system: pre-built towers with predetermined tier, placed for free.
**163.** `_gear_lookup` is a cache dictionary built by `_build_gear_lookup()`.
**164.** Gear scroll offsets tracked separately for shop, detail, emporium views.
**165.** Recent items feed: last 5 items acquired.

---

## 6. Achievement System

**166.** Total achievement definitions: ~225 achievements across 5 categories.
**167.** Categories: Combat, Tower, Economy, Progression, Bonus.
**168.** Combat achievements: 12 kill milestones (1 to 250,000), 4 boss kills, 10 damage milestones, 6 kill streaks, 14 completion/challenges, 6 wave survival.
**169.** Tower achievements: 12 building/placement, 4 synergies, 6 upgrades, 12 per-character mastery (level 10), 12 per-character max (level 20), 4 selling/strategy, 12 per-character kill counts.
**170.** Economy achievements: 8 gold, 8 emporium/chests, 8 currencies, 8 gear/salvage, 4 knowledge/instruments.
**171.** Progression achievements: 10 campaign, 6 character levels, 6 stars, 8 daily/meta, 4 meta-achievements, 6 arena/competitive.
**172.** Bonus achievements: 12 character bonds/personality, 12 sidekicks/special, 12 chapter-specific/hidden.
**173.** Achievement rewards: Pages, Quills, Stars, Trophy bonuses.
**174.** Achievement popup system: text + reward + 3-second timer.
**175.** Achievement points system: harder achievements give more points (difficulty * 5).
**176.** Achievement Shop with 8 items purchasable with achievement points (50-500 cost).
**177.** Shop items: Golden Chest (50pts), 50 Pages (30pts), 25 Quills (40pts), 5 Stars (75pts), 10 Ink (100pts), Energy Refill (20pts), title "Achiever" (200pts), title "Completionist" (500pts).
**178.** Achievement progress tracked in `achievement_progress` dictionary (id -> count).
**179.** Achievement unlock status in `achievements_unlocked` dictionary (id -> bool).
**180.** `_check_achievement()` handles both set-value and increment-value types.
**181.** Career stats tracked: 17 lifetime statistics including total_games_played, total_enemies_killed_lifetime, highest_single_hit, etc.
**182.** `"completionist"` achievement requires all 225 achievements (target: 225).
**183.** `"perfect_campaign"` requires 3 stars on all 37 levels.
**184.** `"all_hard"` requires completing all 37 levels on Hard -- rewards 10 stars + 50 trophies.
**185.** `"pure_mode_legend"` requires 5 Pure Mode completions -- rewards 5 stars + 25 trophies.
**186.** Character mastery achievements check level 10, not level 20 (the max level achievements are separate).
**187.** Bond achievements: 6 individual pair achievements + 1 "all bonds" achievement.
**188.** `"constellation"` achievement: earn all 111 possible stars -- rewards 10 stars + 50 trophies.
**189.** Achievements auto-save after unlock.
**190.** Trophy currency earned from achievement `trophy_bonus` fields.
**191.** Kill milestone achievements increment per kill, not per game.
**192.** Damage achievements track cumulative total_damage across all sessions.
**193.** Achievement categories are strings, not enums.
**194.** The `_check_achievement("full_roster", ...)` is called with the number of unique tower types placed.
**195.** Several achievement IDs reference old naming conventions (e.g., `"shard_collector"` description says "Pages" not "Shards").

---

## 7. Loot / Chest System

**196.** Three chest tiers: Bronze (30 shards to craft), Silver (75 shards), Gold (150 shards).
**197.** Chest opening has 7 phases: idle, shake, burst, cards_slide, cards_flip, pick, done.
**198.** `treasure_chests_owned` tracks owned count per tier.
**199.** Victory chest granted after level completion based on difficulty and star count.
**200.** `_generate_victory_cards()` creates loot cards based on difficulty and star rating.
**201.** `_generate_chest_cards()` creates cards for manually opened chests by tier.
**202.** Chest cards include gear items of varying rarity.
**203.** Victory equip overlay lets player assign gear directly from chest to a character.
**204.** Trinket pending system for chest-to-character equip flow.
**205.** Lucky loot drops: 2% chance per kill (`LUCKY_DROP_CHANCE = 0.02`), reduced from original 5%.
**206.** Pity timer ensures Epic within 30 drops, Legendary within 100 drops.
**207.** Loot crate system: `_roll_loot_crate()`, `_collect_loot_crate()`, `_draw_loot_crate_popup()`.
**208.** Map collectibles: up to 3 per level, found by clicking.
**209.** Storybook pages: one hidden page per level, gives 5 shard reward.
**210.** Post-victory stats screen: `_show_stats_screen` flag.
**211.** Early wave send bonus: `_early_send_bonus` tracks bonus for sending waves before timer.
**212.** Wave rush bonus: clear wave under 15 seconds for bonus gold.
**213.** Combo kill system: `_register_combo_kill()` tracks rapid kills, best combo persisted.
**214.** Perfect wave bonus: 10G for no lives lost during a wave (reduced from 20G).
**215.** Overkill bonus: 3G when overkill damage exceeds 2x enemy HP.
**216.** Gold interest: 5% interest on held gold between waves, capped at 50G.
**217.** Double cash mode: unlockable toggle that doubles all gold earned.
**218.** Bounty board: active bounties with kill-type objectives and rewards.
**219.** Placement streak: consecutive tower placements within 5s window give 5% discount per streak level.
**220.** Victory streak: consecutive wins give +5% gold and +5% XP per streak level.

---

## 8. Progression System

**221.** 90 total levels across 4 acts + expanded arc chapters.
**222.** ACT 1-3: 37 levels (Prologue + 12 character arcs x 3 chapters each).
**223.** ACT 4: 27 levels (9 starter hero weapon trials + 15 new character rescues + 3 narrator finale).
**224.** Expanded arc chapters: 26 additional levels (2 extra per existing arc).
**225.** Map thumb slugs defined for all 90 levels in `MAP_THUMB_SLUGS` array.
**226.** 13 arc_data entries for menu navigation.
**227.** Character unlock map: Sherlock (levels 1-3), Merlin (4-6), Tarzan (7-9), Dracula (10-12), Frankenstein (13-15), Shadow Author (34-36).
**228.** Level unlocking: `_is_level_unlocked()` at line 11713 determines accessibility.
**229.** Star rating: 0-3 stars per level based on performance.
**230.** Per-difficulty stars and medals tracked separately.
**231.** `level_best_wave` tracks best wave reached per level.
**232.** Prestige system: 6 tiers (Apprentice Scribe through Shadow Conqueror), requiring 1-12 prestige levels.
**233.** Prestige bonuses: 5-25% damage + 0-25% gold per tier.
**234.** Battle Pass: 100 tiers, 100 XP per tier, rewards every tier (major every 5/10).
**235.** Ranked seasons: 7 tiers (Bronze Scribe through Shadow Master), monthly reset keeping 30% of points.
**236.** Commander's Pass: separate progression tracked in `commander_pass_tier`/`commander_pass_xp`.
**237.** Loyalty/VIP system: 6 tiers (Reader through Grand Archivist), earned from all activity.
**238.** Loyalty bonuses: 0-25% bonus based on tier.
**239.** Endless mode: sub-exponential scaling, 6 difficulty tiers (Novice through Mythic at wave 100+).
**240.** Endless mutations: 8 types (Speed Surge, Camo Wave, Boss Rush, Shield Wall, Regen Wave, Swarm, Shadow Infested, Gold Drought).
**241.** Boss Rush mode: single powerful boss per wave, scaling health.
**242.** Shadow Arena: competitive mode with modifiers, weekly seed, crystals currency.
**243.** Odyssey mode: 3-map gauntlet with carry-over lives/gold, weekly rotation.
**244.** Daily challenge: special modifier + specific level, streak tracking.
**245.** Multi-step quest chains: 2 defined chains (Sherwood Saga, Gothic Trilogy) with 3 steps each.
**246.** Knowledge tree (Chronicles): branched skill tree unlocked with Knowledge Ink currency.
**247.** Knowledge bonuses affect: damage, range, attack_speed, crit, enemy_hp_reduce, boss_hp_reduce, enemy_slow, enemy_half_hp.
**248.** Star rewards: claimed at star count thresholds.
**249.** Recruitment missions: tracked as completed dictionary.
**250.** Dark skins: unlockable cosmetic character variants.
**251.** Mastery system: per-character mastery challenges.
**252.** Trials system: tracked usage in `trials_used`.
**253.** Fortress level: progresses based on overall completion.
**254.** Personal bests: tracked per level (waves survived, towers used).
**255.** Milestone titles: 7 tiers from Novice (0) to Eternal (50M) based on cumulative score.
**256.** Level restrictions: `_get_level_restrictions()` can limit tower count, banned types, restricted characters.
**257.** Corrupted maps: harder versions unlockable after completing an arc.
**258.** Challenge maps: special challenge variants.
**259.** Multi-entrance system: some levels have 2 enemy paths.
**260.** Day/night cycle per level affecting tower damage bonuses.

---

## 9. Economy / Currency

**261.** In-game gold: starting amount per level (100-200G depending on level), earned from kills and bonuses.
**262.** Persistent currencies: Quills, Pages (formerly Gear Shards), Storybook Stars, Gold (persistent), Knowledge Ink.
**263.** Additional currencies: Arena Crystals, Trophy Currency, Event Tokens, Achievement Points, Loyalty Points, Cosmic Ink.
**264.** Player Crystals: "addiction system" premium-style currency.
**265.** Energy/Stamina system: 20 max energy, 1 per 10 minutes regen, 1 per level (2 for Hard/Pure).
**266.** Resource exchange system: fluctuating daily rates (+-30%). Gold-to-Pages ~50G, Gold-to-Quills ~80G, Pages-to-Quills ~3.
**267.** Kill gold reward: scales from 2G (wave 1) to 15G+ (late waves). Bosses give 10-30G+ bonus.
**268.** Wave clear gold implied but not explicitly defined as a fixed bonus.
**269.** Scrooge has +2% gold bonus per level -- economy-focused character.
**270.** Scrooge's gear emphasizes gold_bonus effects.
**271.** Double Cash mode unlockable (doubles all gold earned when enabled).
**272.** Gold Rush power-up: next 10 kills drop 3x gold.
**273.** Interest system: 5% on held gold between waves (max 50G).
**274.** Early send bonus: `_early_send_bonus` gold for sending waves before timer.
**275.** Difficulty gold multipliers: Easy=0.60x, Medium=1.0x, Hard=1.15x, Pure=1.3x.
**276.** Idle rewards: calculated based on time away (`_calculate_idle_rewards()`).
**277.** Comeback bonus: checked at session start (`_check_comeback_bonus()`).
**278.** XP sharing: 15% of average XP distributed to unused characters (`XP_SHARE_RATIO = 0.15`).
**279.** Placement streak discount: 5% per streak level.
**280.** Victory streak bonuses: +5% gold and +5% XP per consecutive win.
**281.** Event tokens: season-specific currency earned during seasonal events.
**282.** Pages: primary upgrade currency (was "Gear Shards" in old system).
**283.** Quills: rare currency for premium items.
**284.** Stars: rarest standard currency, earned from high performance.
**285.** Knowledge Ink: spent on Chronicle/knowledge tree nodes.
**286.** Arena Crystals: exclusive Shadow Arena currency.
**287.** Trophy Currency: earned from Odyssey runs, spent in Trophy Store.
**288.** Achievement Points: earned from achievements, spent in Achievement Shop.
**289.** Loyalty Points: passive earning from all activity.
**290.** Cosmic Ink: universal XP currency (1 ink = 100 XP for any character).
**291.** Streak Shields: protect victory streaks.
**292.** Daily reward schedule: 7-day cycle (Pages, Quills, Gold, Pages, Star, Quills, Gold Chest).
**293.** Quest rewards: Pages/Quills/Stars/Ink depending on quest type and difficulty.
**294.** Battle Pass rewards: Gold/Pages/Quills/Stars on escalating tiers.
**295.** Ranked season tier-up rewards: Pages + Quills scaled by tier.
**296.** Kill milestone rewards: Pages, Chests, Quills, Stars at escalating thresholds.
**297.** Salvage rates exist in `salvage_rates` but reference old "gear shards" currency name.
**298.** `player_ink` variable defined at line 43466 (very late in file) -- used by crafting and achievement shop.
**299.** `player_ink` is NOT saved in `_save_game()` -- potential data loss bug.
**300.** Seasonal event shop items cost Event Tokens.

---

## 10. Shop / Emporium

**301.** 12 Emporium categories: Gold Exchange, Enchanted Quills, Gear Shards, Gear Chests, Survivor Packs, Storybook Stars, Trophy Store, Battle Powers, Gears, Salvage Workshop, Chest Forge, Instruments.
**302.** Emporium uses sub-panel navigation (category -> items).
**303.** Purchase confirmation system: double-click to confirm.
**304.** Purchase flash animation on successful buy.
**305.** Emporium scroll offset tracked.
**306.** `_init_emporium_items()` at line 5004 populates shop inventories.
**307.** Trophy Store: 3 sub-categories -- Auras (6 items, 5-15 trophies), Trails (4 items, 10-20 trophies), Fanfares (3 items, 15-25 trophies), Themes (3 items, 20-30 trophies).
**308.** Trophy Store cosmetics are persistent across sessions.
**309.** Equipped cosmetics tracked in `equipped_cosmetics` dictionary.
**310.** Daily Deals system: 3-4 items generated daily, seeded by date hash.
**311.** Deal refresh costs 5 quills (`DEAL_REFRESH_COST`).
**312.** Buy-all bonus available when all deals purchased.
**313.** Deal tier colors: common=gray, rare=blue, epic=purple, legendary=gold.
**314.** Battle Powers: 6 types (Quill Strike, Golden Bounty, Storybook Shield, Ink Freeze, Chapter Skip, Enchanted Towers).
**315.** Battle Power costs: 10-30 shards each.
**316.** Powers disabled in Pure Mode and Shadow Arena with "no_powers" modifier.
**317.** Wandering Merchant: refreshed periodically with random inventory.
**318.** Lucky Wheel: spin for random rewards (`_spin_wheel()`).
**319.** Battle Shop (in-game): 11 items purchasable during combat (25-200G).
**320.** Battle Shop cooldown: 15 seconds per item.
**321.** Battle Shop items include: Heal 5 Lives (75G), Gold Rush (30G), Time Stop (60G), War Cry (50G), Haste (40G), Ink Bomb (120G), Story Shield (80G), Author's Insight (25G), Reforge Tower (150G), Emergency Recruit (200G), Ink Infusion (100G).
**322.** Seasonal Events: 4 seasons (Winter Frost, Shadow Festival, Golden Pages, Summer Tales) with unique shops.
**323.** Event shop items include exclusive gear and cosmetics.
**324.** Golden Chest crafting: 3 tiers (Bronze=30 shards, Silver=75, Gold=150).
**325.** Chest Forge category in Emporium for crafting chests.
**326.** Salvage Workshop for dismantling gear into Pages/shards.
**327.** Gear Enchanting: costs 5 quills per enchant.
**328.** Instrument shop: 6 instruments costing 100-175G.
**329.** `"Gears"` and `"Gear Chests"` appear as separate Emporium categories.
**330.** Emporium badges: "AVAILABLE!", "SALE!", "NEW!" on category tiles.

---

## 11. Story / Dialog System

**331.** Story dialog system with typewriter effect and auto-advance.
**332.** `story_dialogs` dictionary maps keys like `"prologue"`, `"pre_level_N"`, `"post_level_N"` to dialog arrays.
**333.** Each dialog line: `{speaker, text, voice_type}`.
**334.** Story choices system: branching dialog with `_show_story_choices()`.
**335.** Choice flags stored in `story_choices_made` dictionary.
**336.** `story_seen` array tracks already-viewed dialogs (persisted).
**337.** `_populate_story_dialogs()` at line 13017 generates all dialog content (~800 lines of dialog text).
**338.** Act title cards: 3 acts defined (ACT I "Into the Pages", ACT II "The Shadow Stories", ACT III "The Final Chapter").
**339.** Act title card duration: 4 seconds.
**340.** Shadow Author taunt system: one random taunt per map, triggers at ~15 seconds.
**341.** Shadow Author taunts have cooldown of 25 seconds between taunts.
**342.** Shadow Author fight clips: 7 audio files (fight_0 through fight_6).
**343.** Character story clips loaded per-level for dialog voiceover.
**344.** Narrator story clips for character unlock moments.
**345.** Boss rescue animation: 5 phases (smoke, author_appears, grab, flash, fade).
**346.** Story portraits drawn procedurally with `_draw_story_portrait()`.
**347.** 20-system cinematic portrait engine: blink, mouth, particles, pupil drift, eyebrow micro-expression, weight shift, specular highlights, nostril movement, hand fidget, micro-expression flicker, idle variation, breath push.
**348.** Voice-over catchphrase system: placement quotes and fighting quotes per character.
**349.** Fighting quote timer: 25 seconds between fighting quotes.
**350.** Kill streak quotes at specific kill counts.
**351.** Idle quirks processed in `_process_idle_quirks()`.
**352.** Bond banter between paired characters.
**353.** Panic lines triggered when lives are low.
**354.** Victory and defeat quotes per character.
**355.** Rally cry system for team morale events.

---

## 12. Save / Load System

**356.** Save file path: `user://shadow_defense_save.json`.
**357.** Save format: JSON with tab-indented pretty-print.
**358.** Atomic write: writes to `.tmp`, then rotates backups (`.bak`, `.bak1`, `.bak2`).
**359.** Save version system: current version 3, with migration from v1 and v2.
**360.** v1->v2 migration: remaps 18 old level indices to new positions (0-17 -> 16-33).
**361.** v2->v3 migration: adds prestige, combo, milestone, daily challenge, boss rush fields.
**362.** Load attempts main save, then `.bak`, `.bak1`, `.bak2` in order.
**363.** Anti-cheat checksum: `_calculate_save_checksum()` and `_validate_save_checksum()`.
**364.** Checksum validation is warning-only (doesn't block loading tampered saves).
**365.** Survivor progress uses name-based keys for reorder safety (e.g., "Robin Hood" not "0").
**366.** Load supports both old int keys and new name keys for backward compatibility.
**367.** Level cap migration: caps loaded levels at `MAX_SURVIVOR_LEVEL` (20).
**368.** XP recalculation on load: uses new `HERO_XP_TABLE` instead of old `500*level`.
**369.** Gear system migration: supports old `"owned_bindings"` and `"equipped_bindings"` keys.
**370.** Old rarity tier names migrated: tattered->common, bound->uncommon, gilded->rare, mythic->epic, forbidden->legendary.
**371.** Energy regen on load: calculates minutes away and adds regenerated energy.
**372.** Gold migration: transfers old in-game gold to persistent `player_gold` if needed.
**373.** Quest migration: ensures `claimed` and `difficulty` fields exist.
**374.** Golden Shields migration: adds field to existing survivor progress if missing.
**375.** Prologue auto-trigger on first load (if `story_seen` is empty).
**376.** Daily challenge reset on date change.
**377.** Autosave indicator triggered on every save.
**378.** `_save_game()` is ~200 lines of field serialization.
**379.** `_load_game()` is ~460 lines of field deserialization.
**380.** Difficulty medals stored as arrays of 4 bools per level (Easy/Medium/Hard/Pure).
**381.** Difficulty stars stored as arrays of 4 ints per level.
**382.** Medal migration: marks Easy as beaten for old saves without per-difficulty data.
**383.** `player_ink` is used in crafting/achievement shop but NOT saved in `_save_game()` -- BUG.
**384.** `player_pages` replaced `player_gear_shards` but `salvage_rates` dict still references old values.
**385.** Save includes accessibility settings: colorblind_mode, text_scale, quality_level.

---

## 13. Music / Audio

**386.** Layered music system: 13 audio layers (drums + 12 character instruments).
**387.** Each character maps to a unique instrument: Robin=lute, Alice=celesta, Witch=organ, PeterPan=whistle, Phantom=piano, Scrooge=brass, Sherlock=harpsichord, Tarzan=djembe, Dracula=cello, Merlin=choir, Frankenstein=synth bass, ShadowAuthor=theremin.
**388.** 5 songs mapped to level groups: "Shadows of London" (Sherlock/Dracula), "The Enchanted Grove" (Merlin/Robin), "Wonderland Waltz" (Alice/Peter), "The Dark Laboratory" (Tarzan/Frankenstein), "The Final Verse" (Witch/Phantom/Scrooge/ShadowAuthor).
**389.** Each song has: BPM, musical key, scale, chord progression, world_mode, swing amount, drum style.
**390.** Tempo multiplier increases with tower upgrades.
**391.** Music intensity (0-1) rises during boss waves and late game.
**392.** Fade speeds: IN=0.8 units/sec (snappy), OUT=0.35 (gradual), PULSE DECAY=1.2 (fast snap-back).
**393.** Music beat clock: 140 BPM, beat interval ~0.4286s.
**394.** Tower layer activation: placing a tower fades in its instrument layer.
**395.** SFX permanently disabled on Windows build (`sfx_muted = true`).
**396.** Procedural SFX generation: UI click, wave start, wave complete, enemy death, victory, defeat, life lost.
**397.** Voice clips: placement catchphrases and fighting quotes loaded as MP3.
**398.** Shadow Author has 7 fight clips.
**399.** ElevenLabs TTS used for voice generation (Eryn voice for Ashrah, various for characters).
**400.** Audio stream player pool: 8 players for SFX.
**401.** Procedural formant voice generation: `_generate_formant_voice()`.
**402.** Music tracks loaded separately from layered system.
**403.** Skip song button in-game.
**404.** Voice mute toggle (`voices_muted`).
**405.** Polyrhythm system loaded at runtime if present.
**406.** Shadow Author taunt audio plays during taunts.
**407.** Story voice clips: narrator, male_hero, female_hero, monster categories.
**408.** Music generation rate: 44100 Hz.
**409.** 4-bar music loops.
**410.** `_on_song_changed()` callback for UI updates.

---

## 14. Visual Systems

**411.** All rendering done in procedural `_draw()` -- no scene-tree UI.
**412.** Per-level background drawing: 11+ unique `_draw_*_ch*()` functions for each realm chapter.
**413.** Novel-themed procedural backgrounds: `_draw_sherlock_novel()`, `_draw_alice_novel()`, etc.
**414.** Atmosphere system: 10 types (fog, snow, rain, embers, fireflies, ink_drip, lightning, petals, sand, bubbles).
**415.** Weather system: rain, snow, storm, fog, embers.
**416.** Lightning flash system.
**417.** Terrain zones: water, elevated, hazard, fog, sacred, ink_pool -- each with gameplay effects.
**418.** Secret paths: discoverable by dealing damage to marked areas.
**419.** Destructible objects: barrels, crates that drop gold/items.
**420.** Foreground layer drawn over gameplay.
**421.** Background story elements (scrolling clouds, etc.).
**422.** Day/night system affecting tower damage bonuses.
**423.** Dynamic hazards spawned during waves.
**424.** Ink splatters on enemy death.
**425.** Screen shake on boss spawns and explosions.
**426.** Floating text system: 196 `spawn_floating_text()` calls throughout code.
**427.** Gold pickup particles.
**428.** AoE impact effects.
**429.** Crit flash effects.
**430.** Build/placement effects.
**431.** Victory burst particles.
**432.** Defeat crack effects.
**433.** Spawn portal animation.
**434.** Boss health bar overlay.
**435.** Kill counter HUD.
**436.** Wave progress bar.
**437.** DPS meter.
**438.** Synergy aura visual indicators.
**439.** Tower buff icons.
**440.** AI-generated art textures loaded for portraits, maps, gear icons, enemies, etc. (20+ texture dictionaries).

---

## 15. Bugs / Issues

**441.** **CRITICAL: `player_ink` not saved.** `player_ink` (line 43466) is used in crafting recipes and achievement shop but never appears in `_save_game()`. All ink is lost on restart.
**442.** **CRITICAL: Massive variable duplication.** Lines 1-1000 and 2500-3900 declare the same variables with sometimes DIFFERENT values. GDScript will use the LAST declaration, but this creates confusion and potential bugs.
**443.** **CRITICAL: `difficulty_waves` conflict.** Block 1 says `[20, 30, 40, 40]`, block 2 says `[30, 40, 50, 60]`. The second overwrites, but the first may have been intentional for different contexts.
**444.** **CRITICAL: `sfx_muted` conflict.** Block 1 = `false`, block 2 = `true`. SFX is permanently disabled due to second declaration.
**445.** **BUG: `daily_rewards_schedule` conflict.** Block 1 uses `"shards"` type, block 2 uses `"pages"` type. Could cause `_claim_daily_reward()` to grant wrong currency.
**446.** **BUG: `salvage_rates` references `player_gear_shards` in comments but variable was renamed to `player_pages`.** The salvage amounts may be wrong for the new currency.
**447.** **BUG: `CHARACTER_ALIGNMENT` references TowerTypes that may not exist in some code paths.** `CAPTAIN_HOOK`, `QUEEN_OF_HEARTS`, etc. are defined in enum but have no preloaded scenes.
**448.** **BUG: `_buy_achievement_shop_item()` handles "energy" type but `player_energy` clamped with `mini()` -- should be `mini(player_energy + ..., MAX_ENERGY)`.** Actually this is correct.
**449.** **BUG: `_exchange_currency()` for `"quills_to_pages"` -- rate key defined (`quills_to_pages: 1`) but function concatenates `from_type + "_to_" + to_type` which would be `"quills_to_pages"`. Rate of 1 means 1 quill = 1 page exchange, but the reverse is 3 pages per quill. This seems unbalanced (should probably be 1 quill = 3 pages).
**450.** **BUG: `_check_quest_chain_progress()` uses `_kill_combo_best` for `"combo_kills_in_realm"` type, but this tracks global best combo, not realm-specific combo kills.**
**451.** **BUG: `"duo_battles"` quest chain step uses `career_stats.get("total_games_played")` as a proxy, which doesn't actually track duo usage.**
**452.** **BUG: `_activate_interactable()` "gate" type sets `enemy.speed *= -0.5` (negative speed). This would make enemies walk BACKWARD on the path briefly, which may cause path-following issues.**
**453.** **BUG: `_buy_battle_item("extra_slot")` does `placed_tower_positions.pop_back()` -- this removes the LAST placed tower's position record, potentially allowing towers to overlap.**
**454.** **BUG: `_buy_battle_item("tower_reforge")` checks for `"_meta_buffs" in selected_tower_node` which may not exist on all tower scripts.**
**455.** **BUG: `_generate_wave_composition()` uses `endless_mode` check but `endless_mode` may not be initialized before first wave.**
**456.** **BUG: Enemy resistances at line 22836 map theme 0 to Sherlock but Sherlock is theme 7.** Theme 0 is Robin Hood/Sherwood. The resistance assignments appear mixed up.
**457.** **BUG: `_get_wave_name()` reads `levels[current_level]["character"]` as fallback when `"enemy_theme"` key is missing, but `"character"` is often -1 (unset), causing key lookup failures in `boss_names`.**
**458.** **BUG: `_activate_power("chapter_skip")` kills all enemies but doesn't award gold/XP for skipped enemies.**
**459.** **BUG: `_complete_reposition()` searches `placed_tower_positions` by exact position match -- floating point comparison may fail.**
**460.** **BUG: `_odyssey_map_victory()` doesn't call `_save_game()` after updating carry-over state.**
**461.** **BUG: `boss_rescue_active` flag set but `boss_rescue_boss_ref` stores a node reference that may become invalid.**
**462.** **ISSUE: `_portrait_textures` declared at both line 196 AND line 2580 (different type: `:= {}` vs `: Dictionary = {}`).** The second overwrites.
**463.** **ISSUE: `_env_event_cooldown` starts at 0.0, meaning an environmental event can trigger on the very first frame of the very first wave.**
**464.** **ISSUE: `_check_environmental_event()` uses `randf() < 0.0003` per frame for timing, which is framerate-dependent. At 30fps, events trigger half as often as at 60fps.**
**465.** **ISSUE: `_generate_map_interactables()` uses hardcoded pixel positions (e.g., 500,350) that may not align with all map layouts.**
**466.** **ISSUE: `_can_upgrade_path()` logic allows certain invalid upgrade combinations when multiple paths are at tier 2.**
**467.** **ISSUE: Memory concern -- 20+ texture dictionaries loaded at startup (`_load_all_art_assets()`) for all 90 levels.**
**468.** **ISSUE: `_check_character_bonds()` at line 27974 iterates all tower pairs every time a tower is placed.**
**469.** **ISSUE: `get_cached_enemies()` returns `_cached_enemies` but cache update frequency is not visible in the read portions.**
**470.** **ISSUE: `_spawn_enemy()` function is 360 lines long with deeply nested conditionals.**
**471.** **ISSUE: No error handling in `_activate_power()` when `info_label` is null (possible during transitions).**
**472.** **ISSUE: `_craft_recipe()` deducts currencies before verifying the crafted item was successfully added.**
**473.** **ISSUE: Event shop `"cosmetic"` type in `_buy_event_shop_item()` has `pass` -- no actual cosmetic storage.**
**474.** **ISSUE: Achievement `"gold_chest"` type in `_buy_achievement_shop_item()` has `pass` -- no chest actually given.**
**475.** **ISSUE: `main_head.gd` has 29,006 lines of code that is essentially dead -- an older version of main.gd with only 12 characters.**

---

## 16. Dead Code

**476.** `main_head.gd` (29,006 lines) -- entire file appears to be a backup/older version of `main.gd`. Only 12 TowerTypes in its enum vs 20 in current.
**477.** `salvage_rates` dictionary at line 394 references old "gear shards" currency that no longer exists.
**478.** `survivor_gear` dictionary at lines 254-267 -- old single-item-per-character gear system superseded by `GEAR_ITEMS` array.
**479.** `(Old gear definitions removed - using GEAR_ITEMS)` comment at line 285 confirms the old system is dead.
**480.** `player_gear_shards` referenced in comments at line 395 but never declared in the active code block.
**481.** Block 1 variable declarations (lines 1-1000) are mostly dead -- overridden by block 2 (lines 2500+).
**482.** `CAPTAIN_AHAB` in TowerType enum but commented out everywhere with "removed -- Hook covers the ocean/pirate archetype."
**483.** `_gear_icon_map` at line 4072 maps only ~30 of 120+ gear IDs -- most gear has no icon mapping.
**484.** `storybook_pages_found` dictionary tracked but `PAGE_SHARD_REWARD = 5` uses old "shard" naming.
**485.** `_wave_composition` and `_wave_spawn_idx` defined at line 22270 but wave composition is regenerated each wave anyway.
**486.** `_env_event_active` and related vars defined at line 22275 mid-file rather than with other state vars.
**487.** `_repositioning_tower` and `_reposition_mode` defined at line 22293 mid-file.
**488.** Comment at line 22401 says "Wave preview uses existing enhanced system at line 41870+" -- but file is only 43,962 lines, so this reference may be stale.
**489.** `_gold_rush_timer` at line 22344 declared but only `_gold_rush_kills` is used for the gold rush feature.
**490.** `_reveal` battle shop item has `pass` -- no implementation.

---

## 17. Balance Issues

**491.** **Scrooge too cheap.** At 60G cost with 70 range and 11 damage, Scrooge is the cheapest tower. His +gold bonus makes him an auto-pick for economy strategies, potentially trivializing gold management.
**492.** **Shadow Author too expensive.** At 250G, Shadow Author costs 4x Scrooge but only 5x the damage. By the time you can afford 250G, the game is likely over or decided.
**493.** **ACT 4 characters extremely expensive.** Medusa (280G), Loki (300G), Anubis (300G) -- these may never be affordable in normal gameplay, especially on Hard/Pure with reduced gold.
**494.** **Easy mode gold nerf too harsh.** `DIFFICULTY_GOLD_MULT` Easy=0.60 (40% less gold than Medium). Combined with Easy having simpler enemies, this could make Easy harder economically than intended.
**495.** **Pure Mode XP is 3x but rewards are minimal.** 3x XP multiplier for Pure Mode (1 life) seems generous but offset by the extreme difficulty. However, it may create XP farming strategies.
**496.** **Gear set bonuses (+5% per piece) stack with per-level gear scaling.** A level 20 character with full epic/legendary gear set could have massive stat inflation (100%+ damage bonus from gear alone).
**497.** **Pity timer at 30 (Epic) and 100 (Legendary) may be too generous.** With 2% lucky drop chance per kill and hundreds of kills per level, players will hit pity timers regularly.
**498.** **Double Cash mode + Gold Interest + Victory Streak creates exponential gold scaling.** A player with all three active would earn ~2.5x normal gold, making Hard mode easier than intended.
**499.** **Battle Shop "Heal 5 Lives" at 75G is extremely cheap on Easy mode (100 lives).** On Easy, lives are abundant making this nearly useless, while on Pure (1 life) it's incredibly powerful -- but the flat cost doesn't scale.
**500.** **Awakened forms at level 20 are enormously powerful.** Examples: Robin's arrows pierce ALL enemies, Merlin gives +20% global tower damage, Frankenstein absorbs 1 leaked enemy per wave. Combined with level 20 capstone stats (+25% dmg, +15% range, +15% speed, +10% crit), a max-level awakened character trivializes most content.

---

## Summary Statistics

| Category | Count |
|----------|-------|
| Architecture Issues | 25 |
| Duplicate/Conflicting Code | 25 |
| Tower Defense Core | 30 |
| Character/Survivor System | 40 |
| Gear System | 45 |
| Achievement System | 30 |
| Loot/Chest System | 25 |
| Progression System | 40 |
| Economy/Currency | 40 |
| Shop/Emporium | 30 |
| Story/Dialog System | 25 |
| Save/Load System | 30 |
| Music/Audio | 25 |
| Visual Systems | 30 |
| Bugs/Issues | 35 |
| Dead Code | 15 |
| Balance Issues | 10 |
| **TOTAL** | **500** |

## Critical Fixes (Priority Order)

1. **Save `player_ink`** -- Add to `_save_game()` and `_load_game()`
2. **Remove duplicate variable blocks** -- Delete lines 1-1000 declarations that are overridden by lines 2500+
3. **Fix enemy resistance mapping** -- Theme 0 is Robin Hood, not Sherlock
4. **Fix gate interactable** -- Negative speed multiplier causes backwards walking
5. **Fix `_buy_battle_item("extra_slot")`** -- Don't remove last tower position
6. **Make environmental event timing framerate-independent** -- Use delta accumulation instead of `randf() < 0.0003`
7. **Fix `_exchange_currency` quills-to-pages rate** -- 1:1 exchange is unbalanced vs 3:1 reverse
8. **Decompose `main.gd`** -- Extract data tables, UI drawing, and subsystems into separate files

---

*Generated by Ashrah game audit system. Read-only analysis -- no code was modified.*
