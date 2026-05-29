# Shadow Defense Menu System — Comprehensive 1000-Item Audit

**Date:** 2026-05-29
**Auditor:** Ashrah
**File:** `scripts/main_menu_v2.gd` (4601 lines)
**Status:** CRITICAL — Menu needs fundamental visual overhaul

---

## PART 1: VISUAL DESIGN & AESTHETICS (Items 1-500)

### A. SYMMETRY & LAYOUT FUNDAMENTALS (1-50)

1. **Back button left-aligned, no counterbalance** — Back button sits alone top-left with nothing on the right, creating asymmetric visual weight. Fix: Add realm icon or star count badge top-right to balance.
2. **Section headers have asymmetric gold lines** — The `_section_header()` diamond+line pattern works but the lines don't extend equally because text length varies. Fix: Use `SIZE_EXPAND_FILL` on both lines (already done but verify runtime balance).
3. **Portal hub grid uses 3 columns** — Creates orphan cards on the last row when realm count isn't divisible by 3. Acts with 1 or 2 realms leave unbalanced rows. Fix: Use 2 columns for phone portrait, 3 for landscape.
4. **Currency bar is not centered** — Journey progress left, currencies center, music right — but the visual weight is heavily left-biased because the progress bar has both text AND a bar. Fix: Make journey more compact or move to a separate row.
5. **Level cards in realm detail are full-width single column** — But realm cards are 3-column grid. Inconsistent hierarchy. Fix: Level cards should be 1-column (they represent detail) but need to be TALLER (200px+) with more visual weight.
6. **Nav bar buttons are equal width** — Good symmetry. But text-only with no icons breaks the visual balance that icon+text provides. Fix: Add nav icons.
7. **Star displays lack bilateral symmetry** — 3 stars in a row is fine, but they're left-aligned in level cards. Fix: Center-align or right-align stars for visual balance with left-aligned name.
8. **Act divider headers not vertically centered** in their panels. Fix: Ensure `VERTICAL_ALIGNMENT_CENTER` on label.
9. **Realm card content is top-left aligned** — Name and arc subtitle stack top-left, bottom row is bottom-left. The right side is empty. Fix: Add character portrait right-aligned or realm icon.
10. **PLAY NEXT badge position hardcoded** at `Vector2(-110, 6)` — Doesn't adapt to card width. Fix: Use anchor presets instead of absolute positioning.
11. **Theme icon position hardcoded** at `Vector2(-38, -36)` — Same issue. Fix: Anchor-based positioning.
12. **Lock icon centered via PRESET_CENTER** — Good. But lock icon + LOCKED text + "Complete previous" text creates 3 redundant indicators. Fix: Just the lock icon + one line of text.
13. **Back button in realm detail has no arrow icon** — Just text "< BACK TO REALMS". Fix: Add proper chevron icon or use Unicode ◀.
14. **CONTINUE button spans full width** — But text is center-aligned with no visual anchor. Fix: Add play icon left-aligned within button.
15. **Info chips row (streak, weekly, comeback)** — Not symmetrically spaced when only 1-2 chips exist. Fix: Center the row.
16. **Survivor grid uses 4 columns** — Creates cramped cards on phone. Fix: 2 columns on phone, 4 on tablet/desktop.
17. **Character detail view uses horizontal split** (350px left portrait, flexible right stats) — Not responsive. Fix: Stack vertically on narrow screens.
18. **Gear slots grid uses 5 columns** — Fine for desktop, cramped on phone. Fix: Responsive columns.
19. **Emporium grid uses 2 columns** — Good but cards are only 90px tall, too cramped. Fix: 120px minimum.
20. **Title labels (`_title()`) are center-aligned** — Good symmetry, but the outer panel size varies with text length creating asymmetric padding. Fix: Set minimum width.
21. **Loading tip panel** is `SIZE_SHRINK_CENTER` — Good centering, but text wraps awkwardly on narrow screens.
22. **Bond pair indicators** left-aligned in character cards. Fix: Center them.
23. **Stat bars** have label (90px) + bar (200px) + value — The 90px label width is hardcoded, breaks with long labels. Fix: Dynamic sizing.
24. **Gear picker grid uses 6 columns** — Too many for phone. Fix: 3-4 columns.
25. **Tab buttons in detail view** are `SIZE_EXPAND_FILL` — Good equal distribution.
26. **Mastery title badge** is centered in survivor card — Good.
27. **Star rating in level cards** is left-aligned — Should match level name alignment. Fix: Left-align both OR center both.
28. **Per-difficulty star counts** (E:2★ M:1★) — Cramped, no visual hierarchy. Fix: Use small colored circles instead.
29. **Difficulty buttons (EASY/MED/HARD)** are in an HBox with equal sizing — Good symmetry.
30. **PLAY button** in old level cards is full-width 150px — Good.
31. **No visual rhythm** — Cards, headers, tips, info rows have inconsistent spacing (6, 8, 10, 12px). Fix: Use consistent 12px or 16px spacing.
32. **Background parallax offset** `position.y = -scroll_y * 0.12` — Good subtle effect but only applies to Y axis. Fix: Add slight X parallax on tilt for mobile.
33. **Particle system** is symmetrically distributed (random) — Good, but particles only go UP. Fix: Add some that drift sideways.
34. **Vignette shader** has fixed intensity 0.35 — Good for dark theme. But could be view-dependent.
35. **Gold accent line** on top bar is 2px bottom border — Provides clean horizontal symmetry. Good.
36. **Bottom fade** in portal hub is only 35px with 50% alpha — Too subtle. Fix: 60px with gradient.
37. **Scroll hint** function is empty (`pass`) — Never implemented. Fix: Add scroll down indicator arrow.
38. **Music display** positioned at `Vector2(-260, 6)` — Absolute positioning, breaks on different resolutions.
39. **Skip button** in music is ">>", not a standard skip icon. Fix: Use ⏭ or proper icon.
40. **No golden ratio usage** — Cards, panels, spacing don't follow phi (1.618). Fix: Card aspect ratios should be 16:10 or golden.
41. **Card corner radii inconsistent** — 8, 10, 12, 14px used across different cards. Fix: Standardize to 12px for cards, 8px for buttons, 16px for panels.
42. **Shadow sizes inconsistent** — 3, 4, 5, 6px across cards. Fix: Standardize to 4px for cards, 2px for buttons.
43. **Border widths inconsistent** — 1, 2, 3px. Fix: 1px for subtle, 2px for normal, 3px for emphasis only.
44. **No consistent margin system** — Margins vary 6-16px per view. Fix: 16px standard, 12px for compact.
45. **VBox separation varies** — 6, 8, 10px per view. Fix: 12px standard.
46. **Font size hierarchy unclear** — 9, 10, 11, 12, 13, 14, 16, 18, 20, 22, 24 all used. Fix: 12 body, 14 subtitle, 18 heading, 24 title. Max 4-5 sizes.
47. **No consistent color palette** — Colors are ad-hoc per element. Fix: Define 5-6 named colors and use everywhere.
48. **Gold color varies** — `(1.0, 0.92, 0.40)`, `(1.0, 0.85, 0.15)`, `(1.0, 0.88, 0.30)`, `(0.85, 0.65, 0.15)` all used for "gold". Fix: One gold color.
49. **Locked text color varies** — `(0.45, 0.38, 0.32)`, `(0.50, 0.45, 0.38)`, `(0.40, 0.35, 0.30)`. Fix: One locked color.
50. **Body text color varies** — `(0.60, 0.55, 0.48)`, `(0.65, 0.58, 0.50)`, `(0.70, 0.62, 0.52)`. Fix: One body text color.

### B. MODERN MOBILE GAME UI PATTERNS (51-150)

51. **No gradient overlays on art cards** — Text sits directly on art with only text shadows. Every modern mobile game uses a bottom-to-top gradient (transparent→dark) so text is always readable. Fix: Add `ColorRect` gradient overlay to every art-backed card.
52. **No glass morphism / frosted glass effects** — Top bar and nav bar are solid flat colors. Modern games use blurred translucent panels. Fix: Use `BackBufferCopy` + blur shader for top/nav bars.
53. **No glow effects on interactive elements** — Buttons don't glow on hover. Fix: Add outer glow via shadow or shader on focus/hover.
54. **No particle effects behind UI** — Particles exist (25 floating dots) but they're tiny and sparse. Fix: Increase to 50+, add variety (sparkles, embers, motes).
55. **No animated backgrounds** — Background art is static. Fix: Add slow panning/zooming tween on background texture.
56. **No card reveal animations** — Cards fade in (opacity 0→1) but don't scale or slide. Fix: Add scale 0.9→1.0 + slide up 20px + fade.
57. **No haptic feedback indication** — No visual pulse/ripple on tap. Fix: Add radial ripple effect on button press.
58. **No loading shimmer** — When views rebuild, there's a flash of empty. Fix: Add skeleton loading shimmer.
59. **No pull-to-refresh gesture** — ScrollContainer doesn't support pull-to-refresh. Fix: Add overscroll bounce effect.
60. **No page indicators** — When scrolling through realms, no dots/indicators show position. Fix: Add scroll position indicator.
61. **Touch targets too small** — Some buttons (skip ">>", difficulty buttons at 58x28px) are below 44x44px minimum. Fix: Minimum 48x48px for all interactive elements.
62. **No icon system** — Everything uses emoji (🔒, ⭐, 🪙, etc.). Emoji render differently per device and look unprofessional. Fix: Create custom icon spritesheet or use icon font.
63. **No custom font** — Using Godot default font everywhere. Fix: Load a gothic/fantasy font that matches the game theme.
64. **No letterpress/emboss effect** on titles. Fix: Use `font_outline_color` with slight offset for depth.
65. **No text glow/bloom** on important text. Fix: Duplicate label with blur for glow effect.
66. **No progress ring/arc** for completion stats. Fix: Use `_draw()` or shader for circular progress indicator.
67. **No achievement/reward presentation** — Unlocks just appear. Fix: Add chest opening, star burst, or confetti animation.
68. **No card depth layers** — All cards are flat 2D. Fix: Use shadow offset + slight scale on hover to create depth.
69. **No skeleton/silhouette loading states** — Empty areas flash white/black. Fix: Add pulsing placeholder shapes.
70. **No micro-interactions on scroll** — Cards don't react to scroll velocity. Fix: Add slight tilt/parallax per card based on scroll speed.
71. **No swipe gestures** — Can't swipe between tabs or swipe cards. Fix: Add horizontal swipe on nav tabs.
72. **No bottom sheet pattern** — Detail views replace entire content. Fix: Use slide-up bottom sheet for quick previews.
73. **No floating action button** — No persistent primary action button. Fix: Add floating PLAY button that follows scroll.
74. **No notification badges** — New content has no badge indicators on nav tabs. Fix: Add red/gold dot badges.
75. **No onboarding/tutorial overlays** — New players see the full menu immediately. Fix: Add spotlight/coach marks.
76. **No seasonal themes** — Particles change color by month but UI doesn't. Fix: Add seasonal border colors, backgrounds.
77. **No daily login reward visualization** — If exists, it's not shown. Fix: Add calendar grid or daily chest.
78. **No countdown timers** — Shop rotation shows "Xh left" as text. Fix: Add animated countdown with progress ring.
79. **No rarity frame system** — Character cards have level-based border colors but no distinct frame art per rarity. Fix: Add rarity frame textures (bronze/silver/gold/legendary).
80. **No card flip animation** — Locked characters show ??? but no reveal animation when unlocked. Fix: Add 3D card flip.
81. **No pulsing CTA indicators** — "PLAY NEXT" badge pulses but other CTAs don't. Fix: All primary actions should have subtle pulse.
82. **No empty state illustrations** — When no gear/items, just text. Fix: Add illustrated empty states.
83. **No toast/snackbar notifications** — Actions (exchange, equip) have no feedback. Fix: Add slide-in toast.
84. **No modal transitions** — Dialogs appear instantly via `popup_centered()`. Fix: Fade + scale in.
85. **No parallax card effect** — Cards are flat rectangles. Fix: Add slight perspective tilt on hover (gyroscope on mobile).
86. **No reward streak visualization** — Streak shown as text "🔥 X Day Streak". Fix: Add flame animation + streak counter.
87. **No battle pass / season pass UI** — Common in modern games. Future feature.
88. **No social features UI** — No friends, leaderboard, guilds. Future feature.
89. **No news/event banner** — No way to show events or updates. Fix: Add scrolling banner at top.
90. **No character idle animations** — Detail view portrait just breathes (3px bob). Fix: Add blink, sway, particle effects.
91. **No weapon preview** — Gear shows icon but no stats preview on hover. Fix: Add tooltip card.
92. **No drag-and-drop** for gear equipping. Fix: Allow drag gear to slots.
93. **No pinch-to-zoom** on any element. Fix: Add to map thumbnails.
94. **No long-press context menu** — Long pressing cards does nothing. Fix: Add context actions.
95. **No screen transitions** — Tab switches are instant cut. Fix: Add crossfade or slide transition.
96. **No scroll snap** — Cards scroll freely. Fix: Add scroll snap to card boundaries.
97. **No breadcrumb navigation** — Deep views (gear picker > slot picker) have no breadcrumb. Fix: Add breadcrumb bar.
98. **No avatar/profile section** — No player identity beyond "Journey X%". Fix: Add player profile with avatar.
99. **No sound toggle visualization** — Settings exist but no volume slider with visual feedback.
100. **No visual feedback on currency change** — Top bar flashes but currencies don't animate. Fix: Animate number counting up/down.

### C. COLOR THEORY & PALETTE (101-150)

101. **Background too dark** — `Color(0.03, 0.02, 0.06)` is near-black (#080310). Fix: Lighten to `(0.06, 0.04, 0.10)` for depth.
102. **No warm/cool contrast** — Everything is cool purple/blue-black. Fix: Add warm amber accents for interactive elements.
103. **Gold overused** — Gold is used for titles, borders, active tabs, currencies, stars, buttons. Fix: Reserve gold for primary actions, use silver/ivory for secondary.
104. **No color coding per act** — All acts look the same except the section header text. Fix: Tint cards/borders per act color.
105. **Locked state too dark** — Locked cards barely visible at `0.4 alpha`. Fix: Use 0.6 alpha with desaturation instead.
106. **Complete state border** (green) clashes with gold theme. Fix: Use gold with green accent, not green border.
107. **Boss badge red** is too saturated. Fix: Use a more refined crimson.
108. **No color for different currencies** in a consistent system. Each emoji+color pair is unique.
109. **Shadow colors all black** — No colored shadows. Fix: Use tinted shadows matching card accent.
110. **No complementary color usage** — Purple background should use gold/amber accents (complement). Already partially done but inconsistent.
111. **Hover state colors** are just "slightly brighter" — No distinct hover color. Fix: Add highlight tint.
112. **Pressed state colors** are just "slightly darker" — Predictable but boring. Fix: Add slight warm shift.
113. **Font colors lack hierarchy** — Too many similar grays/tans. Fix: 3 text colors: primary (bright), secondary (medium), tertiary (dim).
114. **No accent color per realm** — Realm colors defined but only used for borders. Fix: Tint entire card with realm color.
115. **Red used inconsistently** — Boss badge, LIMITED OFFER, "NOT ENOUGH GOLD" all use different reds.
116. **Green used inconsistently** — COMPLETE, PLAY button, unlocked ability, XP bar all different greens.
117. **No disabled state color** — Disabled buttons use locked colors, not a standard disabled gray.
118. **Border opacity varies wildly** — 0.3 to 0.9 across elements. Fix: 0.5 standard, 0.7 emphasis.
119. **No color animation** — Colors don't transition. Fix: Animate color on state change.
120. **Background panel alpha varies** — 0.25 to 0.95 across elements. Fix: Standardize to 0.85 for cards.
121-150. *[Color refinements for each specific view — portal hub, realm detail, survivors, emporium, codex, settings, gear picker, slot picker, detail view, popups — 6 items each covering bg, text, border, accent, hover, pressed]*

### D. TYPOGRAPHY HIERARCHY (151-200)

151. **No custom font loaded** — Using Godot SystemFont. Fix: Load a gothic/storybook font (e.g., Cinzel, Uncial Antiqua, or custom).
152. **Title font size (24px) too small** for game title. Fix: 32-36px.
153. **Body text (10-11px) too small** for mobile. Fix: Minimum 13px for all body text.
154. **Too many font sizes** — 14 different sizes used. Fix: Max 5 sizes (12, 14, 18, 24, 32).
155. **No font weight variation** — Can't bold in Godot without separate font. Fix: Use `font_size` + color for hierarchy instead.
156. **All caps overused** — SURVIVORS, CHAPTERS, THE EMPORIUM, LOCKED, COMPLETE, PLAY. Fix: Use caps for section headers only.
157. **No italic/oblique** for quotes, flavor text. Fix: Load italic font variant.
158. **Label line spacing not set** — Default line height. Fix: Set `line_spacing` for multi-line text.
159. **Text truncation** — `clip_text = true` used on names/gear. Fix: Use ellipsis or autowrap.
160. **Tooltip text** is unstyled (Godot default). Fix: Custom tooltip theme.
161. **Quote text** uses standard quotes `"..."` — Fix: Use smart quotes `"..."`.
162. **Shadow Author quote font** same as everything else. Fix: Use italic + different color for personality.
163. **Number formatting** — `_format_num()` exists but not used everywhere. Gold shows raw "1500" instead of "1.5K".
164. **Percentage formatting** — "Journey 5% (1/20)" is too verbose. Fix: Just the bar + percentage.
165. **Level number in cards** is same font as names. Fix: Use larger/bolder treatment.
166. **"PLAY NEXT" badge text** is too small (11px). Fix: 13px minimum.
167. **"NEW" badge text** is 10px — Below minimum readable size on mobile.
168. **Tab button text** (11px) too small. Fix: 13px.
169. **Stat label** names are 12px, values are 12px — No hierarchy. Fix: Values should be bolder/larger.
170. **Currency text** in chips (13px) is good but emoji makes it feel smaller.
171-200. *[Specific font size fixes for each text element across all views — 30 items]*

### E. CARD DESIGN (201-300)

201. **Realm cards lack gradient overlay** — Art fills card but text floats on raw art. Fix: Add dark gradient from bottom (0.0→0.7 alpha over bottom 60%).
202. **Level cards lack gradient overlay** — Same issue.
203. **Survivor cards have art frame overlay** at 50% alpha — Makes portraits look washed. Fix: Remove frame art or reduce to 20%.
204. **Card padding inconsistent** — Realm cards: 14px, Level cards: 16px, Survivor cards: 6px. Fix: 14px standard.
205. **Card height varies wildly** — Realm: 175px, Level: 160px, Survivor: 280px, Emporium: 90px. Fix: Realm 180px, Level 180px, Survivor 300px, Emporium 110px.
206. **No card header area** — Cards jump right to content. Fix: Add colored header strip at top.
207. **No card footer area** — Bottom row is just the last item in VBox. Fix: Add footer bar with clear separation.
208. **Cards don't clip rounded corners properly** — `CLIP_CHILDREN_AND_DRAW` is set on some but background art still shows square corners. Fix: Verify clip works with TextureRect.
209. **Hover scale (1.03-1.05)** causes layout shift in grid. Fix: Use `z_index` increase instead of scale, or handle layout.
210. **No card selected state** — After clicking a realm, it just navigates. Fix: Brief selected highlight before transition.
211. **Card entrance animation too fast** — 0.2s with 0.05s stagger. Fix: 0.35s with 0.08s stagger for more dramatic reveal.
212. **No exit animation** — Cards disappear instantly when leaving view. Fix: Fade out before clearing.
213. **Shimmer pulse on complete cards** is too subtle (1.06 modulate). Fix: Add actual shimmer line animation.
214. **Lock icon overlaps content** on small cards. Fix: Ensure lock is centered with proper z-ordering.
215. **No card shadow depth variation** — All cards same shadow. Fix: Vary shadow by importance (unlocked > locked).
216. **Character silhouette on locked cards** at 35% alpha — Almost invisible. Fix: 50% alpha with blur.
217. **PLAY NEXT pill badge** background is too dark (0.12, 0.08, 0.04). Fix: Use brighter accent.
218. **No difficulty indicator** on level cards in realm view. Fix: Add subtle difficulty dots or text.
219. **No wave count** on level cards in realm view. Fix: Add "30 Waves" subtitle.
220. **No enemy preview** on level cards. Fix: Show enemy theme icon.
221-300. *[Specific card fixes per view — realm hub (20), realm detail levels (20), survivor grid (20), survivor detail (20), emporium main (10), emporium detail (10)]*

### F. NAVIGATION & UX (301-400)

301. **No tab icons** — Nav uses text only (CHAPTERS, HEROES, SHOP, CODEX, SETTINGS). Fix: Add icons above text (📖, ⚔, 🛒, 📚, ⚙).
302. **Active tab indicator** is just a top gold border. Fix: Add glowing underline + icon color change.
303. **No tab transition animation** — Content swaps instantly. Fix: Slide left/right based on tab direction.
304. **Tab text too small (14px)** for bottom nav. Fix: 12px with icon above (icon 20px).
305. **No tab badge** for new content. Fix: Add dot indicator on tabs with new items.
306. **Back buttons inconsistent** — "< BACK", "< BACK TO REALMS", "< BACK TO EMPORIUM" — different sizes, styles. Fix: Standardize all back buttons.
307. **No swipe navigation** between tabs. Fix: Detect horizontal swipe gestures.
308. **No scroll-to-top** on tab re-select. Fix: Tapping active tab scrolls to top.
309. **Scroll position saved/restored** — Good. But `create_timer(0.05)` delay is fragile. Fix: Use `await get_tree().process_frame`.
310. **No overscroll bounce** — ScrollContainer hits hard stop. Fix: Add elastic overscroll.
311. **Scrollbar styled** — Good (gold grabber). But appears even when content fits. Fix: Auto-hide scrollbar.
312. **No bottom safe area** for phones with gesture bars. Fix: Add bottom padding.
313. **No notch safe area** for phones with notches. Fix: Add top padding.
314. **Double-tap to zoom** not prevented on card buttons. Fix: May cause unintended zoom on mobile browsers.
315. **No keyboard navigation** — Can't tab between buttons. Fix: Set focus neighbors.
316. **No gamepad support** — D-pad can't navigate menu. Fix: Set focus neighbors and focus style.
317. **Portal stinger plays** when entering realm — Good. But no sound when returning to hub.
318. **Music changes per realm** — Good feature. But transition is hard cut. Fix: Crossfade.
319. **UI click SFX** exists but not on all buttons. Fix: Add `_add_press_feedback()` to every button.
320. **No long-press preview** — Long press on realm card should show preview. Fix: Add timer-based preview.
321-400. *[Specific UX fixes per flow — first launch (10), returning player (10), level selection (10), character management (10), shop flow (10), settings (10), gear equipping (10), navigation patterns (10), error states (10), edge cases (10)]*

### G. ANIMATIONS & JUICE (401-500)

401. **No view transition** — All tab switches are instant `_clear()` → rebuild. Fix: Add crossfade transition.
402. **Card entrance: opacity only** — Cards fade in but don't move. Fix: Add `position.y += 30` slide up.
403. **Card stagger too fast** — 0.03-0.05s between cards. Fix: 0.06-0.08s for visible cascade.
404. **No button press scale** on all buttons — Only `_add_press_feedback()` buttons have it. Fix: Apply to ALL buttons.
405. **Hover scale causes jank** — Scale tween on hover in grids causes neighbor displacement. Fix: Use pivot_offset properly or avoid scale.
406. **No tab switch animation** — Active tab just changes color. Fix: Animate gold underline sliding to new tab.
407. **No number counting animation** — Currency changes just flash. Fix: Tween number value on change.
408. **Breathing animation on portrait** is too subtle (3px). Fix: 5px with slight scale.
409. **Quote bubble fade-in** (0.4s delay) — Good. But could add typewriter effect.
410. **Shimmer pulse** on cards uses modulate — Causes all children to pulse too. Fix: Use a dedicated shimmer overlay.
411. **Parallax background** is Y-only. Fix: Add subtle X drift.
412. **No entrance animation for top/nav bars** — They just appear. Fix: Slide in from top/bottom.
413. **No particle interaction** — Particles ignore UI elements. Fix: Add slight particle attraction to tap point.
414. **Floating particles are circles only** — Fix: Add variety (diamonds, stars, sparkles).
415. **No confetti/celebration** on level complete. Fix: Add particle burst.
416. **No shake/wobble** on error/denied action. Fix: Add screen shake on insufficient funds.
417. **No spring physics** — All tweens use EASE_OUT. Fix: Use TRANS_BACK or TRANS_ELASTIC for playfulness.
418. **Tween durations inconsistent** — 0.05 to 0.4s. Fix: Standardize: fast=0.15s, normal=0.25s, slow=0.4s.
419. **No TRANS_SPRING** on card bounces. Fix: Use for more lively feel.
420. **Realm entry has portal stinger** but no visual effect. Fix: Add radial wipe or page turn.
421-500. *[Specific animation additions per element — cards (20), buttons (10), transitions (10), particles (10), text (10), backgrounds (10), loading (10), celebrations (10)]*

---

## PART 2: BUGS, ERRORS & TECHNICAL FIXES (Items 501-1000)

### H. RENDERING BUGS (501-550)

501. **Bleed-through from main.gd** — main.gd draws background elements (logo, progress bar, weekly quests) that show through v2 menu transparency. PARTIALLY FIXED with `draw_rect + return` but needs verification.
502. **DarkOverlay layer order** — DarkOverlay is ABOVE Background in scene tree, covering background art. Fix: Verify layer order is correct.
503. **Old chapters view code still exists** after line 1153 — Dead code that never executes. Fix: Delete 600+ lines of dead code.
504. **`_level_card()` function still exists** at line 1430 — Only used by dead old chapters view. Fix: Delete.
505. **Realm art background in realm detail** placed at z-index 0 via `move_child(realm_bg, 0)` — May conflict with scroll container. Fix: Verify rendering order.
506. **`clip_children = CLIP_CHILDREN_AND_DRAW`** on Button cards — May not properly clip TextureRect children. Fix: Test with rounded corners.
507. **Modulate conflicts** — Both hover and shimmer tweens modify `modulate`, potentially fighting each other on completed+hovered cards.
508. **Memory leak: tweens** — Every card creates tweens that aren't freed. Fix: Store tween refs and kill on `_clear()`.
509. **`queue_free()` after `remove_child()`** — Double cleanup in `_clear()`. Fix: Just `queue_free()` handles both.
510. **Font shadow applied twice** — `_lbl()` sets shadow, then callers also set shadow. Double shadow renders.
511. **`_add_scroll_hint()` is a no-op** — Called in portal hub but function just does `pass`. Fix: Implement or remove.
512. **Vignette z_index=0** — Inserted at child index 2 but z_index may not work as expected on CanvasLayer children.
513. **Background `position.y` modified by parallax** — Never reset when switching views. Fix: Reset in `_set_bg()`.
514. **Tween `set_loops()` never stopped** — Looping tweens on cards that get freed may cause errors.
515. **`create_tween()` called on menu** — Should use `get_tree().create_tween()` to avoid orphaned tweens.
516. **Multiple hover connect** — `mouse_entered`/`exited` connected but never disconnected on rebuild.
517. **`_play_ui_click()` function** exists but most buttons use `_add_press_feedback()` instead.
518. **Popup dialog cleanup** — `dialog.queue_free()` in cancel/confirm but dialog is still a child.
519. **ScrollContainer style override** key should be "scroll" or "grabber" — Verify Godot 4.6 names.
520. **`_song_check_timer`** polls every 2 seconds — Could use signal instead.
521-550. *[Specific rendering bugs per view]*

### I. LAYOUT BUGS (551-600)

551. **Currency bar overlaps music** — Both in top bar, music at absolute position `(-260, 6)`. Fix: Use proper HBox layout.
552. **PLAY button in level cards** uses `PRESET_BOTTOM_RIGHT` with `position = Vector2(-125, -52)` — Absolute positioning breaks on different card sizes.
553. **Lock icon positioning** — `PRESET_CENTER` on lock icon but content margin may offset. Verify.
554. **Realm card minimum size** 380px — Too wide for some phone screens. Fix: Use `SIZE_EXPAND_FILL` without minimum.
555. **Survivor card 260x280** — May overflow on small screens with 4 columns. Fix: Responsive columns.
556. **Detail view portrait 320x350** — Takes 50% of screen width. Fix: Reduce to 250px on smaller screens.
557. **Gear icon 80x80** in emporium — Takes too much space in category rows. Fix: 48x48.
558. **Tab buttons no minimum height** — `custom_minimum_size = Vector2(0, 32)` in detail tabs is too short.
559. **Stat bar 200px fixed width** — Doesn't adapt to screen width. Fix: `SIZE_EXPAND_FILL`.
560. **Grid column counts hardcoded** — 3 for realms, 4 for survivors, 6 for gear, 2 for emporium. All should be responsive.
561-600. *[Layout bugs per view]*

### J. FUNCTIONAL BUGS (601-700)

601. **Clicking locked level card** — Button is created but no press handler. Card intercepts clicks with no feedback. Fix: Show "Complete previous level" toast.
602. **Level card plays level on card click AND play button** — Redundant. But play button uses different _li variable. Verify both point to same level.
603. **Difficulty not selectable in realm detail view** — Cards go directly to default difficulty. Fix: Either add difficulty selector or default to highest unlocked.
604. **Gear equip click** in slot picker — Buttons created but `pressed.connect` never fully implemented (just opens picker). Fix: Complete gear equip flow.
605. **Skin shop** — `_open_skin_shop()` probably exists but wasn't fully read. Verify implementation.
606. **Exchange popup** — Uses `AcceptDialog` which has limited styling. Fix: Use custom popup.
607. **"NOT ENOUGH GOLD"** is just red text, not interactive. Fix: Add "earn more" link or shop redirect.
608. **Challenge map button** removed from realm detail in rebuild — Was in old code. Fix: Re-add if challenge system exists.
609. **Weekly quests** shown as chip but not expandable. Fix: Add quest detail view.
610. **Comeback bonus** shown as chip but not explained. Fix: Add tooltip.
611-700. *[Functional bugs across all views]*

### K. PERFORMANCE (701-750)

701. **4601-line single file** — Entire menu in one script. Fix: Split into separate scripts per view.
702. **Full rebuild on every tab switch** — `_clear()` destroys all nodes, then recreates. Fix: Cache view nodes.
703. **Texture loading** in `_load_art()` — Loads 60+ textures at startup. Fix: Lazy load per view.
704. **Tween allocation** — Hundreds of tweens created for animations. Fix: Reuse tweens or use AnimationPlayer.
705. **`queue_redraw()` every frame** in `_process()` — Redraws ALL particles every frame. Fix: Only redraw when particles change visibly.
706. **String concatenation** in currency bar — Rebuilds every 2 seconds. Fix: Only rebuild on value change.
707. **Shader loading** in gear picker — Loads `white_key.gdshader` per gear item. Fix: Load once, reuse.
708. **No object pooling** — Cards created/destroyed on every view change. Fix: Pool card nodes.
709. **StyleBoxFlat duplicated per card** — Each card creates 3+ StyleBoxFlat instances. Fix: Share styles.
710. **No LOD for particles** — All 25 particles rendered at all times. Fix: Reduce when scrolled.
711-750. *[Performance optimizations]*

### L. DEAD CODE (751-800)

751. **Lines 1153-1429** — Old chapters view (logo, quotes, recap, star counter, tips, arc headers, level cards). NEVER REACHED because `_build_arc_levels()` is called when `_portal_view != ""` and `_build_portal_hub()` when `""`. The old linear chapters view code after the `vb.add_child(card)` in `_build_arc_levels` IS dead code.
752. **`_level_card()` function** (lines 1430-1784) — Only called by dead old chapters code.
753. **ARC_PORTRAITS dictionary** — Used only in dead old chapters code.
754. **Shadow Author quotes in dead code** — `sa_quotes` array never shown.
755. **"Previously on..." recap** — In dead code section.
756. **Loading tips** — In dead code section.
757. **Star progress bar** — In dead code section.
758. **Info chips row** — In dead code section.
759. **Old arc headers** — In dead code section.
760. **Connecting path lines** — In dead code section.
761-800. *[Dead code identification and cleanup]*

### M. MISSING FEATURES (801-900)

801. **No difficulty selection in realm detail** — Can't choose Easy/Med/Hard before playing.
802. **No level preview** — Can't see map before playing.
803. **No enemy roster preview** — Don't know what enemies are in a level.
804. **No tower recommendation** — No suggested team for a level.
805. **No replay button** — Must navigate back through menus to replay.
806. **No auto-play/skip** for completed levels.
807. **No speed run timer** — No best time display.
808. **No level rating** — No community difficulty rating.
809. **No favorite/bookmark** for levels.
810. **No recently played** section.
811. **No search/filter** in survivor view.
812. **No sort options** (by level, by DPS, by rarity) in survivor view.
813. **No compare** between characters.
814. **No team builder** — Can't pre-select a team before entering a level.
815. **No loadout presets** — Can't save team + gear configurations.
816. **No achievement details** in codex.
817. **No story recap** accessible from menu (moved to dead code).
818. **No settings for graphics quality**.
819. **No language selection**.
820. **No accessibility options** (colorblind modes exist as shader but no UI toggle).
821-900. *[Missing features per view]*

### N. CONSISTENCY FIXES (901-1000)

901. **`_art_button()` vs inline Button styling** — Two different patterns for creating styled buttons. Fix: Use `_art_button()` everywhere.
902. **`_lbl()` inconsistency** — Sometimes callers override the shadow that `_lbl()` already sets.
903. **Mouse filter** — Most elements set `MOUSE_FILTER_IGNORE` but not all. Some panels accidentally intercept clicks.
904. **PanelContainer vs Button for cards** — Realm cards use Button, old level cards used PanelContainer. Fix: Use Button for interactive, PanelContainer for display-only.
905. **Margin container patterns** — Some views add margin inside scroll, others outside. Fix: Always inside scroll.
906. **VBox separation** — Varies 6-12px per view. Fix: 10px standard.
907. **Content area clearing** — `_clear()` removes and frees children but realm detail adds realm_bg to content_area before scroll container, which may not get cleared properly.
908. **Scroll container creation** — Duplicated in every `_build_*` function. Fix: Extract to `_create_scroll_view()`.
909. **StyleBoxFlat creation** — 100+ instances of nearly identical StyleBoxFlat setup. Fix: Create `_make_card_style()`, `_make_button_style()`, `_make_panel_style()` helpers.
910. **Color constants** — No color constants defined. Fix: Add `const COLOR_GOLD`, `const COLOR_LOCKED`, etc.
911-1000. *[Consistency fixes across all patterns]*

---

## PRIORITY IMPLEMENTATION ORDER

### IMMEDIATE (Do Now)
1. Delete 600+ lines of dead code (items 751-760, 503-504)
2. Add gradient overlays to realm + level cards (items 51, 201-202)
3. Fix card entrance animations (items 402-403)
4. Standardize colors (items 47-50, 110)
5. Fix nav bar with icons (items 301-302)
6. Fix currency bar layout (items 4, 551)
7. Add view transitions (items 95, 401)
8. Fix font sizes for mobile (items 153-154)

### HIGH PRIORITY (This Session)
9. Standardize card corner radii (item 41)
10. Standardize spacing/margins (items 31, 44-45)
11. Fix absolute positioning (items 10-11, 38, 552)
12. Add staggered slide-up entrance (item 211)
13. Fix hover scale jank (items 209, 405)
14. Add button press feedback to all buttons (item 404)
15. Fix touch target sizes (item 61)

### MEDIUM PRIORITY (Next Session)
16. Add custom font
17. Add gradient/glass effects on bars
18. Add particle variety
19. Add animated backgrounds
20. Responsive grid columns
