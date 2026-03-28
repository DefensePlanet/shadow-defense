extends Node
## LoadingManager — Async loading with progress feedback.
## Addresses: #17 (Loading screens / state transitions)
## Enhanced: #6 (Pre-warm pools during loading), #9 (Lazy-load hero scenes),
## #30 (Smooth page transitions)
##
## Provides non-blocking resource loading with progress callbacks.
## Shows a visual loading indicator during level transitions.

signal loading_started(label: String)
signal loading_progress(progress: float)
signal loading_completed
signal loading_failed(error: String)
# Enhancement #30: Transition signals
signal transition_started(from_view: String, to_view: String)
signal transition_completed

var is_loading: bool = false
var current_progress: float = 0.0
var _loading_label: String = ""
var _pending_loads: Array = []
var _show_overlay: bool = false

# Loading screen draw state
var _overlay_alpha: float = 0.0
var _spinner_angle: float = 0.0
var _tip_index: int = 0

# Enhancement #30: View transition state
var _transitioning: bool = false
var _transition_progress: float = 1.0  # 0->1 during transition
var _transition_type: String = "slide"  # "slide", "fade", "none"
var _transition_from: String = ""
var _transition_to: String = ""
const TRANSITION_DURATION := 0.25  # Seconds for view transitions

const TIPS: Array = [
	"Combine towers from the same novel for synergy bonuses!",
	"Upgrade your heroes in the Survivors tab for permanent power!",
	"Use the Emporium to trade currencies and buy gear.",
	"Place instruments to buff all towers in their radius.",
	"Complete daily quests for Crystal rewards.",
	"Equip gear matching a hero's story for set bonuses.",
	"Shadow Arena rewards increase with your wave count.",
	"Golden Shields unlock more gear slots for your heroes.",
	"Try branching upgrades for different playstyles.",
	"Don't forget to spin the Lucky Wheel each day!",
	"Tap a placed tower to see upgrade options and change targeting.",
	"Pinch to zoom during battle for a closer look!",
	"Swipe up on a tower to quickly upgrade it.",
	"Use 2x or 3x speed to play faster on the go.",
	"Left-handed mode is available in Settings > Accessibility.",
]

func _ready() -> void:
	_tip_index = randi() % TIPS.size()

func _process(delta: float) -> void:
	if _show_overlay:
		_overlay_alpha = minf(_overlay_alpha + delta * 3.0, 1.0)
		_spinner_angle += delta * 360.0
	# Enhancement #30: Process view transitions
	if _transitioning:
		var speed = 1.0 / maxf(TRANSITION_DURATION, 0.01)
		# Respect reduced motion
		if AccessibilityManager and AccessibilityManager.should_reduce_motion():
			_transition_progress = 1.0
			_transitioning = false
			transition_completed.emit()
		else:
			_transition_progress = minf(_transition_progress + delta * speed, 1.0)
			if _transition_progress >= 1.0:
				_transitioning = false
				transition_completed.emit()

## Start a loading sequence
func start_loading(label: String = "Loading...") -> void:
	is_loading = true
	current_progress = 0.0
	_loading_label = label
	_show_overlay = true
	_tip_index = randi() % TIPS.size()
	loading_started.emit(label)

## Update loading progress (0.0 - 1.0)
func set_progress(progress: float) -> void:
	current_progress = clampf(progress, 0.0, 1.0)
	loading_progress.emit(current_progress)

## Complete loading
func finish_loading() -> void:
	current_progress = 1.0
	is_loading = false
	loading_completed.emit()
	# Fade out overlay
	var tween = create_tween()
	tween.tween_property(self, "_overlay_alpha", 0.0, 0.3)
	tween.tween_callback(func(): _show_overlay = false)

## Fail loading
func fail_loading(error: String) -> void:
	is_loading = false
	loading_failed.emit(error)
	_show_overlay = false
	if AnalyticsManager:
		AnalyticsManager.log_error("Loading failed: " + error, "LoadingManager")

## Load a resource asynchronously
func load_resource_async(path: String) -> Resource:
	ResourceLoader.load_threaded_request(path)
	while true:
		var progress_array: Array = []
		var status = ResourceLoader.load_threaded_get_status(path, progress_array)
		match status:
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				if progress_array.size() > 0:
					set_progress(progress_array[0])
				await get_tree().process_frame
			ResourceLoader.THREAD_LOAD_LOADED:
				return ResourceLoader.load_threaded_get(path)
			_:
				fail_loading("Failed to load: " + path)
				return null
	return null

## Enhancement #6: Load level with pool pre-warming
func load_level(level_index: int, enemy_scene: PackedScene, tower_scenes: Array, projectile_scenes: Array) -> void:
	start_loading("Loading Chapter %d..." % (level_index + 1))
	set_progress(0.1)
	# Pre-warm object pools
	if ObjectPool:
		ObjectPool.warm_for_level(enemy_scene, tower_scenes, projectile_scenes)
	set_progress(0.5)
	# Pre-generate audio if needed
	await get_tree().process_frame
	set_progress(0.8)
	# Give a frame for UI to update
	await get_tree().process_frame
	set_progress(1.0)
	finish_loading()

## Enhancement #30: Start a view transition animation
func start_transition(from_view: String, to_view: String, type: String = "slide") -> void:
	_transition_from = from_view
	_transition_to = to_view
	_transition_type = type
	_transition_progress = 0.0
	_transitioning = true
	transition_started.emit(from_view, to_view)

## Enhancement #30: Get transition progress (0=start, 1=complete)
func get_transition_progress() -> float:
	return _transition_progress

## Enhancement #30: Get slide offset for transition animation
func get_transition_slide_offset() -> float:
	if not _transitioning:
		return 0.0
	# Ease out cubic
	var t = _transition_progress
	var eased = 1.0 - pow(1.0 - t, 3.0)
	match _transition_type:
		"slide":
			return (1.0 - eased) * 200.0  # Slide 200px
		"fade":
			return 0.0
		_:
			return 0.0

## Enhancement #30: Get fade alpha for transition
func get_transition_alpha() -> float:
	if not _transitioning:
		return 1.0
	var t = _transition_progress
	# Ease out
	return t * t

## Check if currently transitioning
func is_transitioning() -> bool:
	return _transitioning

## Check if loading overlay should be drawn
func should_draw() -> bool:
	return _show_overlay and _overlay_alpha > 0.01

## Get current loading tip
func get_tip() -> String:
	return TIPS[_tip_index % TIPS.size()]

## Get the loading label
func get_label() -> String:
	return _loading_label

## Get overlay alpha for drawing
func get_alpha() -> float:
	return _overlay_alpha

## Get spinner rotation
func get_spinner_angle() -> float:
	return _spinner_angle
