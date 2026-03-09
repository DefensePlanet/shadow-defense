extends Node
## TouchManager — Enhanced touch input with gestures.
## Addresses: #16 (Touch-optimized controls)

signal tap(position: Vector2)
signal double_tap(position: Vector2)
signal long_press(position: Vector2)
signal pinch(center: Vector2, scale_factor: float)
signal swipe(direction: Vector2, velocity: float)

const DOUBLE_TAP_TIME := 0.3
const LONG_PRESS_TIME := 0.5
const SWIPE_MIN_DIST := 50.0
const PINCH_DEADZONE := 10.0

var _touches: Dictionary = {}  # finger_index -> {start_pos, start_time, current_pos}
var _last_tap_time: float = 0.0
var _last_tap_pos: Vector2 = Vector2.ZERO
var _long_press_timer: float = 0.0
var _long_press_active: bool = false
var _pinch_start_dist: float = 0.0
var is_mobile: bool = false

func _ready() -> void:
	is_mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	if not is_mobile:
		is_mobile = DisplayServer.is_touchscreen_available() if DisplayServer.has_method("is_touchscreen_available") else false

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)

func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = {
			"start_pos": event.position,
			"start_time": Time.get_ticks_msec() / 1000.0,
			"current_pos": event.position
		}
		if _touches.size() == 1:
			_long_press_timer = 0.0
			_long_press_active = true
		elif _touches.size() == 2:
			_long_press_active = false
			var keys = _touches.keys()
			_pinch_start_dist = _touches[keys[0]]["current_pos"].distance_to(_touches[keys[1]]["current_pos"])
	else:
		if _touches.has(event.index):
			var touch = _touches[event.index]
			var dist = touch["start_pos"].distance_to(event.position)
			var duration = Time.get_ticks_msec() / 1000.0 - touch["start_time"]
			# Single finger release
			if _touches.size() == 1 and dist < 20.0 and duration < 0.5:
				var now = Time.get_ticks_msec() / 1000.0
				if now - _last_tap_time < DOUBLE_TAP_TIME and _last_tap_pos.distance_to(event.position) < 40.0:
					double_tap.emit(event.position)
					_last_tap_time = 0.0
				else:
					tap.emit(event.position)
					_last_tap_time = now
					_last_tap_pos = event.position
			# Swipe detection
			elif dist >= SWIPE_MIN_DIST and duration < 0.4:
				var dir = (event.position - touch["start_pos"]).normalized()
				var vel = dist / duration
				swipe.emit(dir, vel)
			_touches.erase(event.index)
		_long_press_active = false

func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if _touches.has(event.index):
		_touches[event.index]["current_pos"] = event.position
	# Pinch zoom with 2 fingers
	if _touches.size() == 2:
		var keys = _touches.keys()
		var current_dist = _touches[keys[0]]["current_pos"].distance_to(_touches[keys[1]]["current_pos"])
		if _pinch_start_dist > PINCH_DEADZONE and current_dist > PINCH_DEADZONE:
			var scale_factor = current_dist / _pinch_start_dist
			var center = (_touches[keys[0]]["current_pos"] + _touches[keys[1]]["current_pos"]) / 2.0
			pinch.emit(center, scale_factor)
			_pinch_start_dist = current_dist

func _process(delta: float) -> void:
	if _long_press_active and _touches.size() == 1:
		_long_press_timer += delta
		if _long_press_timer >= LONG_PRESS_TIME:
			_long_press_active = false
			var key = _touches.keys()[0]
			long_press.emit(_touches[key]["current_pos"])

## Trigger haptic feedback if enabled and available
func haptic(style: int = 0) -> void:
	if not is_mobile:
		return
	if GameSettings and not GameSettings.haptic_feedback:
		return
	if OS.has_feature("ios"):
		# iOS haptic via OS.vibrate_handheld
		Input.vibrate_handheld(15 + style * 10)
	elif OS.has_feature("android"):
		Input.vibrate_handheld(20 + style * 15)
