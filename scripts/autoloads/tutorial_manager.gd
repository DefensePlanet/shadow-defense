extends Node
## TutorialManager — Interactive onboarding and tutorial system.
## Addresses: #10 (Tutorial / onboarding)
##
## Provides step-by-step guided tutorial with highlights,
## tooltips, and forced focus on UI elements.

signal tutorial_started
signal tutorial_step_changed(step: int)
signal tutorial_completed

var is_active: bool = false
var current_step: int = 0
var tutorial_completed_flag: bool = false
var _steps: Array = []
var _highlight_rect: Rect2 = Rect2()
var _message: String = ""
var _arrow_target: Vector2 = Vector2.ZERO
var _show_arrow: bool = false

const TUTORIAL_SAVE_KEY := "tutorial_completed"

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
		"message": "During battle, tap the tower buttons to select a hero.\nThen tap the battlefield to place them!",
		"highlight": Rect2(0, 630, 1280, 90),
		"arrow": Vector2(640, 670),
		"action": "tap_continue"
	},
	{
		"message": "Towers attack enemies automatically.\nTap a placed tower to upgrade it or change targeting!",
		"highlight": Rect2(200, 200, 880, 400),
		"arrow": Vector2(640, 400),
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
