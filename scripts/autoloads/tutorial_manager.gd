extends Node
## TutorialManager — Interactive onboarding and tutorial system.
## Addresses: #10 (Tutorial / onboarding)
## Enhanced: #27 (Contextual "next action" hints), #33 (Daily login reward system)
##
## Provides step-by-step guided tutorial with highlights,
## tooltips, and forced focus on UI elements.
## Also manages daily login rewards and contextual tips.

signal tutorial_started
signal tutorial_step_changed(step: int)
signal tutorial_completed
# Enhancement #33: Daily reward signals
signal daily_reward_available(day: int, reward: Dictionary)
signal daily_reward_claimed(day: int, reward: Dictionary)
# Enhancement #27: Contextual hint signals
signal hint_triggered(hint_text: String, target_pos: Vector2)

var is_active: bool = false
var current_step: int = 0
var tutorial_completed_flag: bool = false
var _steps: Array = []
var _highlight_rect: Rect2 = Rect2()
var _message: String = ""
var _arrow_target: Vector2 = Vector2.ZERO
var _show_arrow: bool = false

const TUTORIAL_SAVE_KEY := "tutorial_completed"

# Enhancement #33: Daily reward system
var daily_login_day: int = 0  # Current day in the 7-day cycle (0-6)
var daily_last_claim_date: String = ""
var daily_streak: int = 0
var daily_claimed_today: bool = false
const DAILY_REWARDS_PATH := "user://daily_rewards.json"

# Enhancement #33: 7-day reward cycle
const DAILY_REWARD_TABLE: Array = [
	{"type": "gold", "amount": 200, "label": "200 Gold"},
	{"type": "crystals", "amount": 10, "label": "10 Crystals"},
	{"type": "gold", "amount": 350, "label": "350 Gold"},
	{"type": "gear_chest", "amount": 1, "label": "Gear Chest"},
	{"type": "crystals", "amount": 25, "label": "25 Crystals"},
	{"type": "gold", "amount": 500, "label": "500 Gold"},
	{"type": "mega_chest", "amount": 1, "label": "Mega Chest!"},  # Day 7 bonus
]

# Enhancement #27: Contextual hints
var _hint_cooldowns: Dictionary = {}  # hint_id -> last_shown_time
const HINT_COOLDOWN := 120.0  # Don't show same hint within 2 minutes
var _pending_hints: Array = []

# Tutorial step definitions
const MAIN_TUTORIAL: Array = [
	{
		"message": "Welcome to Shadow Defense!\nThe Tome of Shadows has scattered heroes across the pages of classic novels.",
		"highlight": Rect2(0, 0, 1280, 720),
		"arrow": Vector2.ZERO,
		"action": "tap_continue"
	},
	{
		"message": "This is the Story Map. Each node is a chapter.\nTap a chapter to begin!",
		"highlight": Rect2(100, 80, 1080, 500),
		"arrow": Vector2(640, 300),
		"action": "tap_continue"
	},
	{
		"message": "Heroes tab shows your rescued characters.\nLevel them up and equip gear to make them stronger.",
		"highlight": Rect2(256, 660, 256, 60),
		"arrow": Vector2(384, 690),
		"action": "tap_continue"
	},
	{
		"message": "The Emporium has 14 shops.\nTrade currencies, buy gear, and open treasure chests!",
		"highlight": Rect2(512, 660, 256, 60),
		"arrow": Vector2(640, 690),
		"action": "tap_continue"
	},
	{
		"message": "Chronicles tracks your mastery.\nUnlock knowledge nodes for permanent bonuses.",
		"highlight": Rect2(768, 660, 256, 60),
		"arrow": Vector2(896, 690),
		"action": "tap_continue"
	},
	{
		"message": "During battle, tap a tower button to select a hero.\nThen tap the battlefield to place them!\n(Or drag from the button to place directly.)",
		"highlight": Rect2(0, 630, 1280, 90),
		"arrow": Vector2(640, 670),
		"action": "tap_continue"
	},
	{
		"message": "Towers attack enemies automatically.\nTap a placed tower to upgrade or change targeting!\nSwipe up to upgrade, swipe left to sell.",
		"highlight": Rect2(200, 200, 880, 400),
		"arrow": Vector2(640, 400),
		"action": "tap_continue"
	},
	{
		"message": "Use the speed button to play at 1x, 2x, or 3x speed.\nPerfect for playing on the go!",
		"highlight": Rect2(1100, 0, 180, 40),
		"arrow": Vector2(1190, 20),
		"action": "tap_continue"
	},
	{
		"message": "Complete levels to earn Stars, Gold, and Quills.\nRescue new heroes by finishing their story chapters!",
		"highlight": Rect2(0, 0, 1280, 720),
		"arrow": Vector2.ZERO,
		"action": "tap_continue"
	},
	{
		"message": "You're ready to defend the pages!\nGood luck, Commander!",
		"highlight": Rect2(0, 0, 1280, 720),
		"arrow": Vector2.ZERO,
		"action": "tap_continue"
	},
]

func _ready() -> void:
	_load_state()
	_load_daily_rewards()
	_check_daily_reward()

## Start the main tutorial
func start_tutorial() -> void:
	if tutorial_completed_flag:
		return
	_steps = MAIN_TUTORIAL
	current_step = 0
	is_active = true
	_apply_step()
	tutorial_started.emit()

## Advance to next step
func next_step() -> void:
	if not is_active:
		return
	current_step += 1
	if current_step >= _steps.size():
		complete_tutorial()
		return
	_apply_step()
	tutorial_step_changed.emit(current_step)
	if AnalyticsManager:
		AnalyticsManager.track_tutorial_step(current_step, _message.left(40))

## Complete the tutorial
func complete_tutorial() -> void:
	is_active = false
	tutorial_completed_flag = true
	_save_state()
	tutorial_completed.emit()

## Skip the tutorial entirely
func skip_tutorial() -> void:
	complete_tutorial()

## Check if tutorial should auto-start (first launch)
func should_auto_start() -> bool:
	return not tutorial_completed_flag

## Reset tutorial (for testing)
func reset() -> void:
	tutorial_completed_flag = false
	current_step = 0
	is_active = false
	_save_state()

func _apply_step() -> void:
	if current_step < _steps.size():
		var step = _steps[current_step]
		_message = step.get("message", "")
		_highlight_rect = step.get("highlight", Rect2())
		_arrow_target = step.get("arrow", Vector2.ZERO)
		_show_arrow = _arrow_target != Vector2.ZERO

## Get current tutorial message
func get_message() -> String:
	return _message

## Get highlight rectangle
func get_highlight() -> Rect2:
	return _highlight_rect

## Check if arrow should be shown
func has_arrow() -> bool:
	return _show_arrow

## Get arrow target position
func get_arrow_target() -> Vector2:
	return _arrow_target

## Get total step count
func get_total_steps() -> int:
	return _steps.size()

# === Enhancement #33: Daily Login Rewards ===

## Check if daily reward is available
func _check_daily_reward() -> void:
	var today = Time.get_date_string_from_system()
	if today == daily_last_claim_date:
		daily_claimed_today = true
		return
	daily_claimed_today = false
	# Check streak
	if not daily_last_claim_date.is_empty():
		var last = Time.get_unix_time_from_datetime_string(daily_last_claim_date + "T00:00:00")
		var now = Time.get_unix_time_from_system()
		var days_diff = int((now - last) / 86400.0)
		if days_diff == 1:
			daily_streak += 1
		elif days_diff > 1:
			daily_streak = 0  # Streak broken
			daily_login_day = 0  # Reset cycle
	daily_reward_available.emit(daily_login_day, get_daily_reward())

## Get today's daily reward
func get_daily_reward() -> Dictionary:
	return DAILY_REWARD_TABLE[daily_login_day % DAILY_REWARD_TABLE.size()]

## Get streak bonus multiplier
func get_streak_multiplier() -> float:
	# 10% bonus per streak day, max 50%
	return 1.0 + minf(float(daily_streak) * 0.1, 0.5)

## Claim daily reward
func claim_daily_reward() -> Dictionary:
	if daily_claimed_today:
		return {}
	var reward = get_daily_reward()
	daily_claimed_today = true
	daily_last_claim_date = Time.get_date_string_from_system()
	daily_login_day = (daily_login_day + 1) % DAILY_REWARD_TABLE.size()
	_save_daily_rewards()
	daily_reward_claimed.emit(daily_login_day - 1, reward)
	if AnalyticsManager:
		AnalyticsManager.log_event("daily_reward_claimed", {"day": daily_login_day, "streak": daily_streak})
	if TouchManager:
		TouchManager.haptic(TouchManager.HapticStyle.SUCCESS)
	return reward

## Check if daily reward can be claimed
func can_claim_daily() -> bool:
	return not daily_claimed_today

# === Enhancement #27: Contextual Hints ===

## Show a contextual hint if not on cooldown
func try_show_hint(hint_id: String, text: String, target: Vector2 = Vector2.ZERO) -> bool:
	var now = Time.get_ticks_msec() / 1000.0
	if _hint_cooldowns.has(hint_id):
		if now - _hint_cooldowns[hint_id] < HINT_COOLDOWN:
			return false
	_hint_cooldowns[hint_id] = now
	hint_triggered.emit(text, target)
	return true

## Contextual hints based on game state
func check_gameplay_hints(gold: int, wave: int, tower_count: int, has_upgrades: bool) -> void:
	if is_active:
		return  # Don't show hints during tutorial
	if tower_count == 0 and gold >= 60 and wave == 0:
		try_show_hint("place_first", "Tap a hero to select, then tap the path to place them!", Vector2(640, 670))
	elif has_upgrades and wave >= 3:
		try_show_hint("upgrade_available", "Your heroes have new upgrades! Tap a placed tower.", Vector2.ZERO)
	elif gold >= 200 and tower_count < 3 and wave >= 2:
		try_show_hint("spend_gold", "You have gold to spare! Place more heroes.", Vector2(640, 670))

func check_menu_hints(new_heroes: bool, unclaimed_daily: bool, unread_story: bool) -> void:
	if is_active:
		return
	if unclaimed_daily:
		try_show_hint("daily_reward", "Your daily reward is ready to claim!", Vector2(640, 360))
	elif new_heroes:
		try_show_hint("new_hero", "New hero unlocked! Check the Heroes tab.", Vector2(384, 690))
	elif unread_story:
		try_show_hint("new_story", "A new chapter awaits!", Vector2(640, 300))

# === Persistence ===

func _save_state() -> void:
	var config = ConfigFile.new()
	config.load("user://settings.cfg")
	config.set_value("tutorial", "completed", tutorial_completed_flag)
	config.set_value("tutorial", "step", current_step)
	config.save("user://settings.cfg")

func _load_state() -> void:
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		tutorial_completed_flag = config.get_value("tutorial", "completed", false)

func _save_daily_rewards() -> void:
	var data = {
		"day": daily_login_day,
		"last_claim": daily_last_claim_date,
		"streak": daily_streak,
	}
	var file = FileAccess.open(DAILY_REWARDS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func _load_daily_rewards() -> void:
	if not FileAccess.file_exists(DAILY_REWARDS_PATH):
		return
	var file = FileAccess.open(DAILY_REWARDS_PATH, FileAccess.READ)
	if not file:
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		daily_login_day = int(json.data.get("day", 0))
		daily_last_claim_date = str(json.data.get("last_claim", ""))
		daily_streak = int(json.data.get("streak", 0))
