# Hero Sprite System — 200-Item Implementation Plan
## Shadow Defense: Tales from the Pages

### The Problem
We have TWO art styles that need to coexist:
1. **Tower Sprites** (existing) — Chibi cartoon, transparent bg, 120px render height, multiple poses (idle/attack/flair). Used IN-GAME on the map.
2. **Character Gear Art** (new) — Realistic portraits showing equipped gear. Used in MENUS (Heroes screen, gear inspection, codex).

The gear art CANNOT replace tower sprites directly — wrong style, wrong format. We need to generate NEW chibi tower sprites that show gear visually while matching the existing art quality.

### The Solution: Layered Hero Sprite System
Generate chibi versions of each gear piece as transparent overlays. The game composites base chibi + gear overlays at runtime. Same character, same poses, gear appears on top.

---

## PHASE 1: FOUNDATION — Art Pipeline Setup (Items 1-25)

### Art Generation Standards
1. Establish consistent chibi proportions: 2.5-head-tall ratio matching existing sprites (head is 40% of body height)
2. Lock canvas size at 512x512px with character centered, transparent background — matches existing tower sprite dimensions
3. Define consistent color palette per character that persists across ALL gear variations
4. Create a style reference sheet from existing sprites — line weight, shading style, eye proportions, body proportions
5. Test nano-banana image editing on existing chibi sprites to verify it maintains the cartoon style when adding gear
6. If nano-banana can't maintain chibi style via editing, generate full chibi sprites from scratch with gear described in prompt
7. Establish a naming convention: `{character}_{pose}_{gear_slot}_{item_id}.png` (e.g., `robin_hood_idle_crown_rh_l1.png`)
8. Create fallback rule: if a gear overlay looks bad, the game falls back to the base sprite (tower_sprites/) — no broken visuals ever
9. Define the 7 gear slots visually on a chibi body template: weapon (hand), crown (head), amulet (neck), bracers (arms), ring (hand glow), belt (waist), back (cape/wings/pack)
10. Create a test pipeline: generate 1 gear piece on Robin idle → verify it looks right → scale to all characters

### Pose System Architecture
11. Define the 6 core poses every character needs: idle, attack, shoot/cast, flair1, flair2, flair3
12. Define 2 additional poses for special characters: spin360 (Robin), spindown (Robin), shoot (Robin/Peter)
13. Map which poses exist per character currently (some only have idle + attack + 3 flairs)
14. Decide: do gear overlays need per-pose variants? YES — a crown must look right on idle AND attack poses
15. Calculate total image count: 18 characters x 6 poses x ~10 gear = 1,080 images at maximum. But with layered compositing, we only need per-pose overlays
16. Alternative approach: generate gear ONLY on idle pose, scale/rotate the overlay to match other poses via code. Cuts images by 6x
17. Decision: generate gear on idle + attack poses only (the two most visible). Flair poses use idle gear position. This cuts to ~360 images
18. Create the directory structure: `assets/hero_sprites/{character}/base/`, `assets/hero_sprites/{character}/gear/`
19. Keep tower_sprites/ completely untouched as fallback — rename nothing, delete nothing
20. Add a game setting: "Hero Sprites" toggle (ON = new gear-visible sprites, OFF = classic tower sprites)

### Godot Integration Planning
21. Design the GDScript gear rendering system: base sprite + overlay sprites composited via CanvasGroup or SubViewport
22. Evaluate performance: compositing 2-3 transparent PNGs per tower vs single sprite. Target: 60fps with 20 towers on screen
23. Plan the texture atlas: pack all hero sprites into sprite sheets for GPU efficiency
24. Design the gear-to-visual mapping: gear_data.gd item → visual overlay file path
25. Plan the animation system: idle breathing + attack recoil must work identically to current tower sprite system

---

## PHASE 2: BASE HERO SPRITES — Chibi Regen (Items 26-75)

### Why We Need New Chibis
26. Current tower sprites are LOCKED (sacred commit de39169). We don't modify them — we create NEW ones alongside them
27. New hero sprites must be generated with gear attachment points in mind (space on head for crown, hand positioned for weapons)
28. Each character needs a "clean" base that gear layers onto naturally

### Robin Hood (5 sprites)
29. Robin Hood idle — green hood, brown tunic, quiver, holding bow at rest, confident smirk. Transparent bg, chibi style matching existing
30. Robin Hood attack — drawing bow back, determined expression, leaning into shot
31. Robin Hood flair1 — victory pose, one arm raised, grinning
32. Robin Hood flair2 — spinning move, cloak flowing
33. Robin Hood flair3 — salute/wave, heroic stance

### Alice (5 sprites)
34. Alice idle — blue dress, white apron, holding potion bottle, curious expression
35. Alice attack — throwing/casting potion, determined look
36. Alice flair1 — curtsy with sparkles
37. Alice flair2 — growing/shrinking visual
38. Alice flair3 — tea party pose

### Wicked Witch (5 sprites)
39. Witch idle — pointed hat, black robes, holding broomstick, menacing grin
40. Witch attack — casting green fire, leaning forward
41. Witch flair1 — cackling pose
42. Witch flair2 — flying on broomstick
43. Witch flair3 — summoning monkeys gesture

### Peter Pan (5 sprites)
44. Peter Pan idle — green tunic, pointed hat, dagger at side, floating slightly
45. Peter Pan attack — slashing with dagger, mid-air
46. Peter Pan flair1 — crowing pose (arms up, one leg back)
47. Peter Pan flair2 — flying loop
48. Peter Pan flair3 — shadow play pose

### Phantom (5 sprites)
49. Phantom idle — half mask, black cape, holding rose, brooding
50. Phantom attack — throwing music note projectile, dramatic gesture
51. Phantom flair1 — cape flourish
52. Phantom flair2 — organ playing gesture
53. Phantom flair3 — chandelier drop pose

### Scrooge (5 sprites)
54. Scrooge idle — top hat, coat, walking stick, miserly expression
55. Scrooge attack — throwing coins/gold magic
56. Scrooge flair1 — money counting
57. Scrooge flair2 — ghost seeing (scared face)
58. Scrooge flair3 — reformed generous pose

### Dracula (5 sprites)
59. Dracula idle — cape, fangs, red eyes, aristocratic stance
60. Dracula attack — lunging with claws, cape spread
61. Dracula flair1 — bat transformation
62. Dracula flair2 — mesmerize pose
63. Dracula flair3 — hanging upside down

### Sherlock (5 sprites)
64. Sherlock idle — deerstalker, pipe, magnifying glass, analytical pose
65. Sherlock attack — throwing deduction projectile
66. Sherlock flair1 — "Elementary" finger point
67. Sherlock flair2 — violin playing
68. Sherlock flair3 — examining with magnifying glass

### Tarzan (5 sprites)
69. Tarzan idle — loincloth, muscular, spear at side, alert stance
70. Tarzan attack — throwing spear, powerful throw
71. Tarzan flair1 — chest beat (ape call)
72. Tarzan flair2 — vine swing
73. Tarzan flair3 — animal call pose

### Merlin (5 sprites)
74. Merlin idle — blue robes, long beard, crystal staff, wise stance
75. Merlin attack — casting spell from staff, magic circles

### Merlin continued + remaining characters (Items 76-95)
76. Merlin flair1 — shapeshifting shimmer
77. Merlin flair2 — time magic pose
78. Merlin flair3 — summoning Excalibur light

### Frankenstein (5 sprites)
79. Frankenstein idle — bolts, stitches, massive build, gentle expression despite size
80. Frankenstein attack — ground pound, electricity arcing
81. Frankenstein flair1 — confused head scratch
82. Frankenstein flair2 — electricity surge
83. Frankenstein flair3 — flower holding (gentle giant)

### Shadow Author (5 sprites)
84. Shadow Author idle — purple hooded robe, quill in hand, no glowing eyes, mysterious
85. Shadow Author attack — ink slash, pages flying
86. Shadow Author flair1 — writing in air
87. Shadow Author flair2 — page tornado
88. Shadow Author flair3 — closing book dramatic

### Anubis (5 sprites)
89. Anubis idle — jackal head, golden armor, ankh staff, regal stance
90. Anubis attack — soul judgement beam, scales of justice
91. Anubis flair1 — mummy summoning
92. Anubis flair2 — weighing heart pose
93. Anubis flair3 — underworld portal gesture

### Captain Hook (5 sprites)
94. Captain Hook idle — red coat, hook hand, feathered hat, sneering
95. Captain Hook attack — hook slash + pistol shot

### Captain Hook continued + remaining (Items 96-115)
96. Captain Hook flair1 — waving hook menacingly
97. Captain Hook flair2 — clock panic (hearing ticking)
98. Captain Hook flair3 — pirate captain pose, sword raised

### Clayton (5 sprites)
99. Clayton idle — safari outfit, rifle, pith helmet, predatory stance
100. Clayton attack — rifle shot, recoil
101. Clayton flair1 — trap setting
102. Clayton flair2 — binocular scouting
103. Clayton flair3 — trophy display pose

### Headless Horseman (5 sprites)
104. Headless Horseman idle — no head, holding pumpkin, cape flowing, mounted stance
105. Headless Horseman attack — throwing flaming pumpkin
106. Headless Horseman flair1 — pumpkin juggling
107. Headless Horseman flair2 — horse rearing
108. Headless Horseman flair3 — headless bow (comedic)

### Medusa (5 sprites)
109. Medusa idle — snake hair moving, scaled armor, shield at side, beautiful but deadly
110. Medusa attack — petrification gaze beam
111. Medusa flair1 — snake hair hiss
112. Medusa flair2 — mirror pose
113. Medusa flair3 — gorgon transformation

### Queen of Hearts (5 sprites)
114. Queen of Hearts idle — crown, red dress, scepter, imperious stance
115. Queen of Hearts attack — "OFF WITH THEIR HEAD" slash, card soldiers flying

### Queen continued + Narrator (Items 116-120)
116. Queen flair1 — croquet swing
117. Queen flair2 — decree pointing
118. Queen flair3 — card throw

### Narrator (3 sprites — special entity)
119. Narrator idle — cosmic energy form, radiant, above-all-stories presence
120. Narrator flair1 — reality rewriting gesture

---

## PHASE 3: GEAR OVERLAY GENERATION (Items 121-170)

### Per-Slot Overlay Strategy
121. Crown slot: generate transparent crown/headgear overlays positioned at top of chibi head. 10-15 unique crowns across tiers
122. Weapon slot: generate character-specific weapon overlays replacing the base weapon in-hand. Most impactful visual change
123. Amulet slot: small necklace/pendant overlays at chibi neck area. Subtle but visible
124. Bracer slot: arm wraps/gauntlets overlays on chibi forearms
125. Ring slot: hand glow effects rather than visible rings (too small at chibi scale). Color changes per tier
126. Belt slot: waist accessories, pouches, belt upgrades
127. Back slot: capes, wings, backpacks, floating objects behind character

### Tier Visual Language
128. Common gear — minimal visual change, subtle additions (small accessory, slight color shift)
129. Rare gear — noticeable addition with faint glow outline
130. Epic gear — dramatic addition with particle effects (sparkles, energy wisps drawn via code)
131. Legendary gear — transformative visual + persistent glow aura + unique color scheme
132. Ancient gear — character visually elevated, mythological energy, environment-affecting glow

### Robin Hood Gear Overlays (10)
133. Sherwood Shortbow overlay — slightly better bow replacing base bow
134. Lincoln Green Cloak overlay — cape addition behind character
135. Outlaw's Quiver overlay — golden quiver replacing base
136. Merry Men's Token overlay — belt medallion
137. Sherwood Longbow overlay — larger glowing green bow
138. Hood's Silver Arrow overlay — silver arrows in quiver, silver arrowhead drawn on attack
139. Marian's Favor overlay — pink ribbon on arm
140. Bow of the Green Knight overlay — massive split-shot enchanted bow, green energy
141. Sherwood Heart Oak overlay — vine armor growing on body
142. The Silver Arrow of Sherwood overlay — legendary golden bow, arrows leave trails

### Alice Gear Overlays (10)
143. Curious Teacup — teacup hanging from belt
144. Eat Me Cookie — apron pocket glow
145. Rabbit's Pocket Watch — golden watch chain at neck
146. Card Soldier's Shield — small card shield on arm
147. Cheshire Cat Grin — floating purple grin above shoulder (code particle)
148. Drink Me Potion — glowing blue bottle at belt
149. Looking Glass Shard — mirror fragment floating near hand (code particle)
150. Vorpal Blade — blue energy sword replacing base weapon
151. Queen's Croquet Mallet — flamingo mallet weapon
152. The Jabberwock's Eye — massive dragon eye amulet, pulsing glow

### Remaining Characters Overlay Approach (Items 153-170)
153. Dracula: blood pendant, bat cloak, coffin nail dagger, moonlit fang, crimson chalice, key, brooch, impaler stake, nocturne galaxy cloak, crimson throne aura
154. Wicked Witch: emerald shard float, poppy vial, broomstick splinter, monkey feather, crystal ball hover, ruby slipper, enchanted broomstick weapon, emerald crown, monkey scepter, grimmerie book
155. Peter Pan: fairy dust particles, lost boy dagger, shadow thread trail, acorn cap pin, tinker bell lantern float, compass at belt, croc tooth necklace, star map hover, enchanted cutlass weapon, second star halo
156. Phantom: mask chip brooch, rose at lapel, oar shard on back, chandelier crystal necklace, score sheets floating, lake gem blue glow, opera mask upgrade, organ keys floating, locket at chest, music aura
157. Scrooge: penny at belt, ledger under arm, chain link shackle, candle stub float, ghost child behind, lockbox at waist, walking stick weapon, future specter behind, crutch on back, redemption book above
158. Sherlock: magnifying lens in hand, pipe in mouth, notes floating, satchel on chest, wolf fang necklace, cipher disc float, fireplace iron weapon, brain aura, locket at chest, deduction tome behind
159. Tarzan: vine whip on arm, fang necklace, drum shield on back, leopard claw earring, gorilla pelt shoulder, jungle spear weapon, drum mallet on back, vine crown, war paint marks, jungle crystal chest
160. Merlin: crystal orb in hand, rune stone at belt, table splinter necklace, scroll floating, lake staff weapon, runestone orbit, signet ring glow, crystal shoulders, water aura, golden throne behind
161. Frankenstein: copper bolt neck, lab flask at belt, galvanic wire arms, leather straps chest, tesla coil shoulder, bride headband, battery backpack, lightning rods shoulders, serum syringe, promethean chest orb
162. Shadow Author: quill floating, torn page beside, margin notes around head, inkwell at belt, fountain pen weapon, bookmarked chapter float, plot twist scroll, inkwell of rewriting, foreshadowing pages, unwritten ending book
163. Anubis: canopic jar at belt, linen arm wraps, scarab brooch, jackal tooth necklace, scales floating, embalmer hook weapon, ankh at chest, feather of maat, was scepter, book of dead behind
164. Captain Hook: rusty hook upgrade, eye patch, cutlass weapon, ticking clock fragment, compass at belt, poisoned hook, croc gauntlet, enchanted hook, black flag behind, chronometer floating
165. Clayton: bullet bandolier, machete on back, pith helmet, net at belt, elephant gun weapon, jaw trap at belt, trophy belt, gatling rifle, trophy net on shoulder, great white hunter rifle
166. Headless Horseman: stirrup iron at belt, hessian cloak, graveyard vial necklace, pumpkin seed amulet, flaming pumpkin in hand, horseshoe at belt, spectral bridle, hellfire jack-o-lantern weapon, phantom steed aura, severed head held
167. Medusa: petrified scale armor, serpent fang needle hair, cracked mirror, gorgon hair coil glow, gaze fragment eye glow, viper venom drip, athena shield, perseus shield weapon, gorgon blood elixir aura, aegis of athena full
168. Queen of Hearts: chipped crown jewel, card armor plates, red rose thorn brooch, executioner blindfold, croquet flamingo weapon, royal decree floating, hedgehog cannonball at belt, vorpal axe weapon, throne decree aura, crimson crown
169. Approach for overlay generation: use nano-banana image editing on new hero sprite chibis, NOT on current tower sprites
170. Batch generation: run all overlays per character sequentially with 12s delays between API calls to avoid rate limiting

---

## PHASE 4: GODOT RUNTIME SYSTEM (Items 171-200)

### Gear Visual Rendering Engine
171. Create `hero_sprite_manager.gd` — singleton that manages loading and caching hero sprite textures
172. Create `gear_visual_map.gd` — maps gear item IDs to their overlay texture paths
173. Modify tower base class to support layered sprite rendering: base sprite + up to 7 gear overlay sprites
174. Implement CanvasGroup compositing for overlay stacking — transparent layers blend correctly
175. Add gear overlay z-ordering: back items behind character, front items in front (belt, weapon)
176. Implement idle animation for overlays — breathing scale must match base sprite exactly
177. Implement attack animation for overlays — recoil + squash-stretch must match base sprite
178. Add per-slot offset tables: exact pixel offset per gear slot per character per pose
179. Create a visual test scene: place each character with all 7 slots filled, verify no visual glitches
180. Implement the fallback: if any overlay fails to load, just show base sprite (never crash, never look broken)

### Gear Equip Visual Feedback
181. When player equips gear in menu: play equip animation (item flies to character, flash, gear appears)
182. When player unequips: reverse animation (item detaches, returns to inventory)
183. In-game tower placement: character appears with currently equipped gear already visible
184. Gear tier glow system: common=none, rare=subtle white, epic=blue pulse, legendary=gold pulse, ancient=prismatic
185. Gear particle effects via code (not sprites): sparkles, energy wisps, elemental auras matching gear type

### Menu Integration
186. Heroes menu shows realistic portrait art (character_gear/ images) — NOT the chibi versions
187. Gear inspection screen shows the realistic portrait with that specific gear piece highlighted
188. Gear comparison popup: side-by-side realistic art showing current vs new gear on character
189. Codex/collection screen: shows all gear art as a gallery the player unlocks
190. Gear set bonuses (if we add them later): unique visual effect when wearing 3+ pieces from same tier

### Performance & Polish
191. Texture atlas packing: combine all hero sprites into sprite sheets (TextureAtlas) for GPU batch rendering
192. LOD system: at zoomed-out camera levels, use simplified single-sprite instead of layered compositing
193. Memory management: only load hero sprite textures for characters currently placed on the map
194. Preload commonly used gear textures on level start to prevent stutter during equip
195. Stress test: 20 towers with full gear, all attacking simultaneously — must maintain 60fps

### Testing & Quality Assurance
196. Visual QA checklist per character: verify every gear piece looks correct in idle, attack, and all 3 flair poses
197. Color consistency check: same gear item must look the same color/style across different characters if universal
198. Edge case: what happens when the player equips gear then switches to classic tower sprites? Gear stats still apply, just visuals revert
199. A/B comparison mode for development: press a key to toggle between hero sprites and classic tower sprites in real-time
200. Final polish pass: review every single character with every single legendary/ancient gear equipped — these are the "endgame fantasy" visuals that make players feel powerful. If any look bad, regenerate until perfect

---

## PRIORITY ORDER

**Must do first (blocks everything):**
- Items 1-10: Art pipeline validation
- Items 26-33: Robin Hood hero sprites as proof of concept
- Items 133-142: Robin Hood gear overlays as proof of concept
- Items 171-180: Godot runtime rendering

**Do after validation:**
- Items 34-120: All remaining character hero sprites
- Items 143-170: All remaining gear overlays
- Items 181-200: Polish, performance, menu integration

**Timeline estimate:** Hero sprites are the bottleneck — ~90 base sprites + ~180 gear overlays = ~270 total images at minimum. At 5 images per batch with 12s delays = ~10 hours of generation time across multiple sessions.

---

## KEY DECISIONS NEEDED FROM JOHN

1. **Style match vs upgrade?** Do new hero sprites match EXACTLY the existing chibi tower sprite style, or can we evolve to a slightly higher-detail chibi (same proportions, more shading)?
2. **Overlay vs full regen?** Generate transparent gear overlays that layer on top, OR regenerate the entire character sprite with gear baked in? Layering = fewer images but needs code. Full regen = more images but simpler code.
3. **How many poses per gear?** Gear visible on idle + attack only, or ALL poses? Each additional pose multiplies images needed.
4. **Menu art vs in-game art?** The realistic portraits (character_gear/) are clearly menu art. Should we also show a "mini portrait" with gear in the in-game HUD next to health/ability cooldowns?
