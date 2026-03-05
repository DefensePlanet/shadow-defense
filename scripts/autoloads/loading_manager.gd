extends Node
## LoadingManager — Async loading with progress feedback.
## Addresses: #17 (Loading screens / state transitions)
##
## Provides non-blocking resource loading with progress callbacks.
## Shows a visual loading indicator during level transitions.

signal loading_started(label: String)
signal loading_progress(progress: float)
signal loading_completed
signal loading_failed(error: String)

var is_loading: bool = false
var current_progress: float = 0.0
var _loading_label: String = ""
var _pending_loads: Array = []
var _show_overlay: bool = false

# Loading screen draw state
var _overlay_alpha: float = 0.0
var _spinner_angle: float = 0.0
var _tip_index: int = 0

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
]

func _ready() -> void:
	_tip_index = randi() % TIPS.size()

## Start a loading sequence
func start_loading(label: String = "Loading...") -> void:
	is_loading = true
	current_progress = 0.0
	_loading_label = label
	_show_overlay = true
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

func _process(delta: float) -> void:
	if _show_overlay:
		_overlay_alpha = minf(_overlay_alpha + delta * 3.0, 1.0)
		_spinner_angle += delta * 360.0

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
