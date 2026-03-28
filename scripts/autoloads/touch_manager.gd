extends Node
## TouchManager — Enhanced touch input with gestures.
## Addresses: #16 (Touch-optimized controls)
## Enhanced: #11 (Drag-and-drop tower placement), #12 (Gesture shortcuts),
## #14 (Pinch-to-zoom), #15 (Two-finger pan), #17 (Haptic feedback),
## #18 (Edge-of-screen auto-scroll), #19 (Double-tap quick info),
## #20 (Shake-to-undo)

signal tap(position: Vector2)
signal double_tap(position: Vector2)
signal long_press(position: Vector2)
signal pinch(center: Vector2, scale_factor: float)
signal swipe(direction: Vector2, velocity: float)
# Enhancement #11: Drag-and-drop signals
signal drag_started(position: Vector2)
signal drag_moved(position: Vector2)
signal drag_ended(position: Vector2)
signal drag_cancelled()
# Enhancement #12: Tower gesture signals
signal tower_swipe_up(tower_position: Vector2)
signal tower_swipe_down(tower_position: Vector2)
signal tower_swipe_left(tower_position: Vector2)
signal tower_swipe_right(tower_position: Vector2)
# Enhancement #15: Two-finger pan
signal pan(delta: Vector2)
# Enhancement #18: Edge scroll
signal edge_scroll(direction: Vector2)
# Enhancement #20: Shake-to-undo
signal shake_detected()

const DOUBLE_TAP_TIME := 0.3
const LONG_PRESS_TIME := 0.5
const SWIPE_MIN_DIST := 50.0
const PINCH_DEADZONE := 10.0
const DRAG_THRESHOLD := 15.0  # Min distance before drag starts
const EDGE_SCROLL_MARGIN := 60.0  # Pixels from edge to trigger scroll
const EDGE_SCROLL_SPEED := 300.0

var _touches: Dictionary = {}  # finger_index -> {start_pos, start_time, current_pos}
var _last_tap_time: float = 0.0
var _last_tap_pos: Vector2 = Vector2.ZERO
var _long_press_timer: float = 0.0
var _long_press_active: bool = false
var _pinch_start_dist: float = 0.0
var is_mobile: bool = false

# Enhancement #11: Drag state
var is_dragging: bool = false
var drag_position: Vector2 = Vector2.ZERO
var _drag_finger: int = -1
var _drag_start_pos: Vector2 = Vector2.ZERO

# Enhancement #15: Pan state
var _pan_last_center: Vector2 = Vector2.ZERO
var _is_panning: bool = false

# Enhancement #18: Edge scroll state
var _edge_scrolling: bool = false
var _edge_scroll_dir: Vector2 = Vector2.ZERO

# Enhancement #20: Shake detection
var _accel_samples: Array = []
const SHAKE_THRESHOLD := 25.0
const SHAKE_SAMPLE_COUNT := 10

# Enhancement #17: Haptic patterns
enum HapticStyle { LIGHT, MEDIUM, HEAVY, DOUBLE, SUCCESS, ERROR }

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
			# Cancel any drag in progress
			if is_dragging:
				is_dragging = false
				_drag_finger = -1
				drag_cancelled.emit()
			var keys = _touches.keys()
			_pinch_start_dist = _touches[keys[0]]["current_pos"].distance_to(_touches[keys[1]]["current_pos"])
			_pan_last_center = (_touches[keys[0]]["current_pos"] + _touches[keys[1]]["current_pos"]) / 2.0
			_is_panning = true
	else:
		if _touches.has(event.index):
			var touch = _touches[event.index]
			var dist = touch["start_pos"].distance_to(event.position)
			var duration = Time.get_ticks_msec() / 1000.0 - touch["start_time"]

			# Enhancement #11: End drag
			if is_dragging and event.index == _drag_finger:
				is_dragging = false
				_drag_finger = -1
				_edge_scrolling = false
				drag_ended.emit(event.position)
			# Single finger release — tap or swipe
			elif _touches.size() == 1 and not is_dragging:
				if dist < 20.0 and duration < 0.5:
					var now = Time.get_ticks_msec() / 1000.0
					if now - _last_tap_time < DOUBLE_TAP_TIME and _last_tap_pos.distance_to(event.position) < 40.0:
						double_tap.emit(event.position)
						_last_tap_time = 0.0
					else:
						tap.emit(event.position)
						_last_tap_time = now
						_last_tap_pos = event.position
				# Enhancement #12: Directional swipe detection
				elif dist >= SWIPE_MIN_DIST and duration < 0.4:
					var dir = (event.position - touch["start_pos"]).normalized()
					var vel = dist / duration
					swipe.emit(dir, vel)
					_emit_directional_swipe(dir, touch["start_pos"])

			_touches.erase(event.index)
		_long_press_active = false
		if _touches.size() < 2:
			_is_panning = false

func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if _touches.has(event.index):
		_touches[event.index]["current_pos"] = event.position

	# Enhancement #11: Drag-and-drop handling (single finger)
	if _touches.size() == 1 and not is_dragging and _long_press_active:
		if _touches.has(event.index):
			var touch = _touches[event.index]
			var dist = touch["start_pos"].distance_to(event.position)
			if dist > DRAG_THRESHOLD:
				# Check if drag-to-place is enabled
				if GameSettings and GameSettings.drag_to_place:
					is_dragging = true
					_drag_finger = event.index
					_drag_start_pos = touch["start_pos"]
					drag_position = event.position
					_long_press_active = false
					drag_started.emit(touch["start_pos"])

	if is_dragging and event.index == _drag_finger:
		drag_position = event.position
		drag_moved.emit(event.position)
		# Enhancement #18: Edge-of-screen auto-scroll
		_check_edge_scroll(event.position)

	# Pinch zoom and pan with 2 fingers
	if _touches.size() == 2:
		var keys = _touches.keys()
		var pos0 = _touches[keys[0]]["current_pos"]
		var pos1 = _touches[keys[1]]["current_pos"]
		var current_dist = pos0.distance_to(pos1)
		var center = (pos0 + pos1) / 2.0

		# Enhancement #14: Pinch-to-zoom
		if _pinch_start_dist > PINCH_DEADZONE and current_dist > PINCH_DEADZONE:
			if GameSettings and GameSettings.pinch_zoom:
				var scale_factor = current_dist / _pinch_start_dist
				pinch.emit(center, scale_factor)
			_pinch_start_dist = current_dist

		# Enhancement #15: Two-finger pan
		if _is_panning:
			var pan_delta = center - _pan_last_center
			if pan_delta.length() > 2.0:
				pan.emit(pan_delta)
			_pan_last_center = center

func _process(delta: float) -> void:
	# Long press detection
	if _long_press_active and _touches.size() == 1 and not is_dragging:
		_long_press_timer += delta
		if _long_press_timer >= LONG_PRESS_TIME:
			_long_press_active = false
			var key = _touches.keys()[0]
			long_press.emit(_touches[key]["current_pos"])

	# Enhancement #18: Emit edge scroll signal while dragging near edge
	if _edge_scrolling and is_dragging:
		edge_scroll.emit(_edge_scroll_dir * EDGE_SCROLL_SPEED * delta)

	# Enhancement #20: Shake detection via accelerometer
	if is_mobile:
		_detect_shake()

## Enhancement #12: Emit directional swipe on towers
func _emit_directional_swipe(dir: Vector2, origin: Vector2) -> void:
	if not GameSettings or not GameSettings.gesture_shortcuts:
		return
	# Determine primary direction
	if absf(dir.x) > absf(dir.y):
		if dir.x > 0:
			tower_swipe_right.emit(origin)
		else:
			tower_swipe_left.emit(origin)
	else:
		if dir.y < 0:  # Up (screen coords: negative Y = up)
			tower_swipe_up.emit(origin)
		else:
			tower_swipe_down.emit(origin)

## Enhancement #18: Check if drag position is near screen edge
func _check_edge_scroll(pos: Vector2) -> void:
	var vp_size = get_viewport().get_visible_rect().size
	var dir = Vector2.ZERO
	if pos.x < EDGE_SCROLL_MARGIN:
		dir.x = -1.0
	elif pos.x > vp_size.x - EDGE_SCROLL_MARGIN:
		dir.x = 1.0
	if pos.y < EDGE_SCROLL_MARGIN:
		dir.y = -1.0
	elif pos.y > vp_size.y - EDGE_SCROLL_MARGIN:
		dir.y = 1.0
	_edge_scrolling = dir != Vector2.ZERO
	_edge_scroll_dir = dir.normalized() if dir != Vector2.ZERO else Vector2.ZERO

## Enhancement #20: Detect device shake via accelerometer
func _detect_shake() -> void:
	var accel = Input.get_accelerometer()
	if accel == Vector3.ZERO:
		return
	_accel_samples.append(accel.length())
	if _accel_samples.size() > SHAKE_SAMPLE_COUNT:
		_accel_samples.pop_front()
	if _accel_samples.size() >= SHAKE_SAMPLE_COUNT:
		var avg = 0.0
		for s in _accel_samples:
			avg += s
		avg /= _accel_samples.size()
		var variance = 0.0
		for s in _accel_samples:
			variance += (s - avg) * (s - avg)
		variance /= _accel_samples.size()
		if variance > SHAKE_THRESHOLD:
			_accel_samples.clear()
			shake_detected.emit()

## Enhancement #17: Trigger haptic feedback with style
func haptic(style: int = HapticStyle.MEDIUM) -> void:
	if not is_mobile:
		return
	if GameSettings and not GameSettings.haptic_feedback:
		return
	var duration_ms: int = 15
	match style:
		HapticStyle.LIGHT:
			duration_ms = 10
		HapticStyle.MEDIUM:
			duration_ms = 25
		HapticStyle.HEAVY:
			duration_ms = 50
		HapticStyle.DOUBLE:
			Input.vibrate_handheld(15)
			await get_tree().create_timer(0.08).timeout
			duration_ms = 15
		HapticStyle.SUCCESS:
			Input.vibrate_handheld(10)
			await get_tree().create_timer(0.06).timeout
			Input.vibrate_handheld(10)
			await get_tree().create_timer(0.06).timeout
			duration_ms = 20
		HapticStyle.ERROR:
			duration_ms = 80
	Input.vibrate_handheld(duration_ms)
