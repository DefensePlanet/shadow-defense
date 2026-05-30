# Shadow Defense — Implementation Roadmap

**Goal:** Get every system working, tested, and polished — phase by phase.
**Rule:** Nothing moves to the next phase until the current phase is tested and verified.

---

## PHASE 0: CLEANUP (Estimated: 1 session)
**Goal:** Remove hazards. Make the codebase safe to work in.

| # | Task | Why |
|---|---|---|
| 0.1 | Delete `main_head.gd` (29K lines dead code) | Confusing, never loaded, wastes git space |
| 0.2 | Remove duplicate variable block (lines 1-1000) | Block 2 (lines 2500+) overwrites everything — block 1 creates false confidence and conflicting values |
| 0.3 | Fix all conflicting duplicate values: `difficulty_waves`, `sfx_muted`, `daily_rewards_schedule` | Second block wins but first block values may have been intentional |
| 0.4 | Rename old `player_gear_shards` references to `player_pages` | Dead currency name still in comments and `salvage_rates` |
| 0.5 | Remove `CAPTAIN_AHAB` from TowerType enum | Commented out everywhere, Hook covers the role |
| 0.6 | Clean up `_gear_icon_map` — only 30 of 120+ gear items mapped | Missing icons = invisible gear in UI |

**Test:** Game launches, saves, loads. No parse errors. All existing functionality unchanged.

---

## PHASE 1: SAVE/LOAD INTEGRITY (Estimated: 1 session)
**Goal:** Every piece of player progress persists correctly.

| # | Task | Why |
|---|---|---|
| 1.1 | Verify `player_ink` save/load (DONE) | Was losing crafting currency |
| 1.2 | Add `unlocked_titles` to save/load | Titles purchased but never saved |
| 1.3 | Add `_extra_tower_slots` reset per level | Shouldn't persist across levels |
| 1.4 | Verify `treasure_chests_owned` saves all 3 tiers | Gold chest purchase now works — verify it persists |
| 1.5 | Verify `equipped_cosmetics` saves (auras, trails, fanfares, themes) | Trophy store purchases must persist |
| 1.6 | Verify `owned_instruments` saves | Literary instruments purchased in emporium |
| 1.7 | Add `player_crystals` to save if not already | Premium currency must never be lost |
| 1.8 | Verify `commander_pass_tier`/`commander_pass_xp` saves | Commander's Pass progression |
| 1.9 | Verify `knowledge_tree` unlocks save | Chronicle/knowledge tree nodes |
| 1.10 | Run save → close → load → verify ALL currencies match | Full round-trip test |

**Test:** Start game, earn/spend every currency type, save, close, reopen, verify all values match. Do this twice.

---

## PHASE 2: CORE COMBAT MECHANICS (Estimated: 2 sessions)
**Goal:** Tower defense gameplay is solid and bug-free.

| # | Task | Why |
|---|---|---|
| 2.1 | Fix gate interactable (DONE) | Enemies walked backward |
| 2.2 | Fix environmental event timing (DONE) | Framerate-dependent |
| 2.3 | Fix enemy resistance mapping (theme 0 = Robin Hood, not Sherlock) | Wrong enemies resist wrong towers |
| 2.4 | Fix `_complete_reposition()` floating-point position match | Tower reposition may silently fail |
| 2.5 | Fix `_can_upgrade_path()` allowing invalid upgrade combos | Players could potentially break the 3-path restriction |
| 2.6 | Fix `_activate_power("chapter_skip")` — award gold/XP for skipped enemies | Players lose rewards when using Chapter Skip power |
| 2.7 | Fix `_get_wave_name()` fallback when `enemy_theme = -1` | Key lookup failure in boss_names |
| 2.8 | Fix `_env_event_cooldown` starting at 0 | Event can trigger on first frame |
| 2.9 | Verify wave composition system for all 4 difficulties | Ensure enemy counts/types are reasonable |
| 2.10 | Verify MOAB villain spawning (waves 15/25/35) | These are meant to be dramatic — must work |
| 2.11 | Verify commander enemies (every 8th wave from wave 6+) | Ensure they spawn with correct abilities |
| 2.12 | Verify flying enemies (5-10% chance on waves 8+) | Ensure pathfinding works for flyers |
| 2.13 | Test all 5 path trap types (Spike Strip, Tar Pit, Fire Mine) | Verify damage, uses, and removal |
| 2.14 | Test tower sacrifice system | Ensure sacrificed tower is removed and benefit applied |
| 2.15 | Test gold interest between waves (5%, max 50G) | Verify math is correct |

**Test:** Play through Prologue level on each difficulty (Easy/Medium/Hard). Verify waves spawn correctly, enemies die, towers upgrade, gold flows, lives work. No crashes.

---

## PHASE 3: CHARACTER SYSTEM (Estimated: 2 sessions)
**Goal:** All 20 characters work correctly with leveling, abilities, and bonds.

| # | Task | Why |
|---|---|---|
| 3.1 | Verify all 12 base characters place and attack | Basic functionality |
| 3.2 | Verify all 8 ACT 4 characters place and attack | Newer characters less tested |
| 3.3 | Test 3-path upgrade system for 3 sample characters | Verify tier costs, restrictions, and stat bonuses |
| 3.4 | Verify XP earning per wave per difficulty | Check math against `HERO_XP_TABLE` |
| 3.5 | Verify level-up stat bonuses (+3% dmg, +2% range, +1.5% speed) | Ensure per-level scaling works |
| 3.6 | Verify role-specific extras (Robin +2% range, Peter +2% speed, etc.) | Character differentiation |
| 3.7 | Test character bond system — place Robin + Sherlock near each other | Verify +8% damage/speed within 200 range |
| 3.8 | Test character home bonus (+10% on own chapter) | Place Sherlock on Sherlock levels |
| 3.9 | Verify sidekick system — unlock at Golden Shield 3/6/9 | Sidekick bonuses should stack |
| 3.10 | Test Awakened Forms at level 20 for 2-3 characters | Verify unique passives activate |
| 3.11 | Verify XP sharing (15% to unused characters) | `XP_SHARE_RATIO` must work |
| 3.12 | Test character kill tracking and milestones | 100/500/1000 kill achievements |
| 3.13 | Verify character affinity system on home maps | +0.5 per wave, milestones at 10/25/50/75/100 |
| 3.14 | Test team composition bonuses (all heroes, all villains, mixed, antihero trio) | Verify damage/speed bonuses |

**Test:** Play 3 different levels with different team compositions. Verify XP earned, levels gained, bonds triggered, stats correct in survivor detail view.

---

## PHASE 4: GEAR SYSTEM (Estimated: 2 sessions)
**Goal:** Gear drops, equips, crafts, salvages, and buffs correctly.

| # | Task | Why |
|---|---|---|
| 4.1 | Verify gear drops from enemies (2% lucky drop chance) | Ensure loot actually appears |
| 4.2 | Verify pity timer (Epic at 30 drops, Legendary at 100) | Counter must persist and reset |
| 4.3 | Verify difficulty gear cap (Easy=uncommon max, Pure=legendary max) | Higher difficulty = better loot |
| 4.4 | Test equipping gear from chest opening screen | Quick-equip flow |
| 4.5 | Test equipping gear from survivor detail view | Slot picker → gear picker flow |
| 4.6 | Verify gear stat bonuses actually affect tower performance | Equip +20% damage gear → verify damage increase |
| 4.7 | Test gear set bonuses (+5% per piece from same character) | Equip 3 Robin Hood gear pieces |
| 4.8 | Verify gear crafting (6 ancient recipes) | Ensure ingredient deduction + item creation |
| 4.9 | Test gear fusion (3 same-rarity → next tier) | Verify rarity upgrade works |
| 4.10 | Test gear salvage → Pages conversion | Verify correct salvage rates per rarity |
| 4.11 | Test gear enchanting (5 quills → random stat boost) | Verify stat addition |
| 4.12 | Test gear loadout presets (save/load 5 configurations) | Verify persistence |
| 4.13 | Test gear locking (prevent accidental salvage) | Locked gear should be un-salvageable |
| 4.14 | Fix old `survivor_gear` vs new `GEAR_ITEMS` coexistence | Two gear schemas shouldn't conflict |
| 4.15 | Verify `_auto_equip_best_gear()` selects optimal gear | Ensure algorithm is reasonable |

**Test:** Play 5 levels, collect gear, equip on 3 different characters, verify stat changes in detail view, salvage extras, craft one item. Save/load and verify gear persists.

---

## PHASE 5: ACHIEVEMENTS & PROGRESSION (Estimated: 1-2 sessions)
**Goal:** All 225 achievements track and reward correctly.

| # | Task | Why |
|---|---|---|
| 5.1 | Fix achievement `"shard_collector"` description (says "Pages" not "Shards") | Outdated naming |
| 5.2 | Verify kill milestone achievements increment correctly | 1/10/50/100/500/1000 kills |
| 5.3 | Verify damage milestone achievements track cumulative total | Across all sessions |
| 5.4 | Test boss kill achievements | Track boss kills separately |
| 5.5 | Verify per-character mastery achievements (level 10 and level 20) | Separate thresholds |
| 5.6 | Test bond achievements — trigger all 6 pair achievements + "all bonds" | Place each bond pair |
| 5.7 | Verify achievement popup system (text + reward + timer) | Must show and auto-dismiss |
| 5.8 | Test achievement shop (DONE: gold_chest and title now work) | Verify all 8 items purchasable |
| 5.9 | Verify achievement points calculation (difficulty * 5) | Harder achievements = more points |
| 5.10 | Test star rating system (0-3 stars per level) | Verify star thresholds |
| 5.11 | Verify per-difficulty stars and medals save correctly | Arrays of 4 values per level |
| 5.12 | Test prestige system (6 tiers, bonuses) | Verify prestige unlocks and stat bonuses |
| 5.13 | Test Battle Pass progression (100 tiers, rewards) | Verify XP earning and tier-up |
| 5.14 | Verify daily challenge reset on date change | New challenge each day |

**Test:** Play through enough content to trigger 10+ different achievements. Verify popups, rewards, persistence. Check achievement shop purchases give correct items.

---

## PHASE 6: ECONOMY & SHOP (Estimated: 2 sessions)
**Goal:** All currencies flow correctly. Shop works. Nothing is free that shouldn't be.

| # | Task | Why |
|---|---|---|
| 6.1 | Fix `_exchange_currency` quills-to-pages rate (1:1 is too generous) | Should be 1 quill = 3 pages to match reverse |
| 6.2 | Verify gold exchange rates in Emporium | 100G→5 Quills, 250G→15 Pages, 500G→3 Stars |
| 6.3 | Test all Emporium category sub-views | Each of 14 categories opens correctly |
| 6.4 | Verify purchase confirmation flow (double-click) | Prevent accidental purchases |
| 6.5 | Test daily deals system (date-seeded, 3-4 items) | New deals each day |
| 6.6 | Test deal refresh (5 quills cost) | Verify cost deduction and new items |
| 6.7 | Test Trophy Store cosmetics (auras, trails, fanfares, themes) | Purchase and equip flow |
| 6.8 | Test Battle Powers (6 types, 10-30 pages each) | Buy and use in combat |
| 6.9 | Verify Battle Shop (11 items, 25-200G each, 15s cooldown) | Buy during combat |
| 6.10 | Test Lucky Wheel spin | Verify random rewards |
| 6.11 | Verify daily rewards (7-day cycle) | Correct currency type per day |
| 6.12 | Test idle rewards calculation | Correct rewards based on time away |
| 6.13 | Test comeback bonus | Activates for returning players |
| 6.14 | Verify energy system (20 max, 1/10min regen, 1-2 per level) | Not infinite plays |
| 6.15 | Test seasonal event shop (if any active season) | Event tokens → exclusive items |

**Test:** Open every Emporium category, buy one item from each, verify currency deductions. Check daily deals refresh. Use a Battle Power in combat. Verify all currencies in top bar update correctly.

---

## PHASE 7: STORY & AUDIO (Estimated: 1 session)
**Goal:** Story dialogs play correctly. Music works. Voice lines trigger.

| # | Task | Why |
|---|---|---|
| 7.1 | Test prologue dialog on fresh save | Auto-triggers on first load |
| 7.2 | Test pre-level and post-level story dialogs | Should play before/after levels |
| 7.3 | Test arc intro cinematics (first time entering each realm) | 12 unique intros |
| 7.4 | Test act title cards (ACT I, II, III) | 4-second display on act transition |
| 7.5 | Test Shadow Author taunt system | Random taunt at ~15s per map |
| 7.6 | Verify story_seen tracking (don't replay seen dialogs) | Persistence |
| 7.7 | Test story choices system | Branching dialog with flags |
| 7.8 | Test boss rescue animation (5 phases) | Smoke → author → grab → flash → fade |
| 7.9 | Verify layered music (13 tracks, per-tower instruments) | Place tower → instrument fades in |
| 7.10 | Test music track switching per realm | Correct song for each realm |
| 7.11 | Test voice placement quotes (per character) | Each character has unique lines |
| 7.12 | Test fighting quotes (25s cooldown between lines) | Not too frequent |
| 7.13 | Verify skip song button works | Skip → next track |
| 7.14 | Test boss fight dialog (HP threshold triggers) | Lines at specific HP percentages |

**Test:** Play Prologue with story enabled. Verify dialog shows, voice plays (if available), music matches realm, Shadow Author taunts. Enter a new realm for the first time — verify arc intro plays.

---

## PHASE 8: MENU POLISH (Estimated: 2 sessions)
**Goal:** Every menu view is beautiful and functional.

| # | Task | Why |
|---|---|---|
| 8.1 | Continue Emporium visual rebuild (items 31-200 from audit) | Current state is "little better" |
| 8.2 | Generate proper backgrounds for Emporium, Codex, Settings | Replace any with baked-in text |
| 8.3 | Polish character detail view (Stats, Gear, Allies, Abilities tabs) | Complex view needs testing |
| 8.4 | Fix gear picker UI in character detail | Equip flow must work |
| 8.5 | Fix skin shop UI | Cosmetic preview and purchase |
| 8.6 | Polish Codex view | Achievement display, lore entries |
| 8.7 | Polish Settings view | Volume sliders, accessibility, quality |
| 8.8 | Add proper responsive grid columns (2 on phone, 3-4 on desktop) | Current hardcoded columns |
| 8.9 | Test all nav tab transitions work correctly | No black screens, no bleed-through |
| 8.10 | Final visual audit — screenshot every view, list remaining issues | Comprehensive check |

**Test:** Screenshot every single view in the game. Tap every button. Open every sub-view. No crashes, no checkerboard, no overlapping text, no bleed-through.

---

## PHASE 9: BALANCE & TUNING (Estimated: 1-2 sessions)
**Goal:** Game feels fair, challenging, and rewarding.

| # | Task | Why |
|---|---|---|
| 9.1 | Review tower cost/damage/range ratios | Scrooge too cheap, Shadow Author too expensive |
| 9.2 | Review ACT 4 character costs (280-300G) | May be unaffordable in normal play |
| 9.3 | Review Easy mode gold nerf (0.60x) | May make Easy harder economically |
| 9.4 | Review Double Cash + Interest + Streak stacking | Potential exponential gold scaling |
| 9.5 | Review Awakened Form power level | May trivialize endgame content |
| 9.6 | Review pity timer rates | 30/100 may be too generous |
| 9.7 | Review gear set bonus stacking with per-level scaling | Could create 100%+ damage from gear alone |
| 9.8 | Review wave difficulty curve (Phase 1-6 HP scaling) | Ensure smooth difficulty ramp |
| 9.9 | Playtest Easy/Medium/Hard for first 3 realms | Verify fun factor and difficulty |
| 9.10 | Review economy flow — how many levels to buy first shop item? | Should be achievable but not trivial |

**Test:** Full playthrough of first 2 realms (10 levels) on Medium difficulty. Note where it feels too easy, too hard, or unfair. Adjust values.

---

## PHASE 10: PERFORMANCE & POLISH (Estimated: 1 session)
**Goal:** Game runs smoothly, no memory issues, clean codebase.

| # | Task | Why |
|---|---|---|
| 10.1 | Profile frame rate during combat (20+ towers, 50+ enemies) | Ensure 60fps on target hardware |
| 10.2 | Review texture loading (20+ dictionaries at startup) | May cause long load times |
| 10.3 | Review tween allocation (hundreds per session) | Potential memory leak |
| 10.4 | Consider extracting data tables to Resources (.tres) | 4000 lines of data in main.gd |
| 10.5 | Consider splitting main.gd into subsystem scripts | 44K lines is unmaintainable |
| 10.6 | Clean up remaining dead code references | Old variable names in comments |
| 10.7 | Add error handling to critical functions | Save/load, purchases, level transitions |
| 10.8 | Final compile check — zero warnings | Clean build |

**Test:** Run game for 30 minutes of continuous play. Monitor frame rate, memory usage. No degradation over time.

---

## PHASE SUMMARY

| Phase | Focus | Sessions | Priority |
|---|---|---|---|
| 0 | Cleanup | 1 | IMMEDIATE |
| 1 | Save/Load | 1 | CRITICAL |
| 2 | Combat | 2 | CRITICAL |
| 3 | Characters | 2 | HIGH |
| 4 | Gear | 2 | HIGH |
| 5 | Achievements | 1-2 | MEDIUM |
| 6 | Economy/Shop | 2 | MEDIUM |
| 7 | Story/Audio | 1 | MEDIUM |
| 8 | Menu Polish | 2 | HIGH |
| 9 | Balance | 1-2 | LOW (after gameplay works) |
| 10 | Performance | 1 | LOW (final pass) |
| **TOTAL** | | **16-19 sessions** | |

---

*Each phase ends with a test checkpoint. Nothing advances until the current phase passes testing. This prevents cascading bugs and ensures every system is verified before building on top of it.*
