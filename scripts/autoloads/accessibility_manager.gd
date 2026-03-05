extends Node
## AccessibilityManager — Accessibility features for mobile.
## Addresses: #20 (Accessibility)
##
## Handles VoiceOver/TalkBack hints, font scaling, colorblind modes,
## reduced motion, and high contrast.

signal accessibility_changed

# Colorblind correction matrices (applied to shader uniforms)
const COLORBLIND_MATRICES = {
	0: [],  # Off
	1: [0.625, 0.375, 0.0, 0.7, 0.3, 0.0, 0.0, 0.3, 0.7],  # Deuteranopia
	2: [0.567, 0.433, 0.0, 0.558, 0.442, 0.0, 0.0, 0.242, 0.758],  # Protanopia
	3: [0.95, 0.05, 0.0, 0.0, 0.433, 0.567, 0.0, 0.475, 0.525],  # Tritanopia
}

var screen_reader_active: bool = false
var _announce_queue: Array = []

func _ready() -> void:
	# Detect if screen reader is active
	screen_reader_active = _detect_screen_reader()

## Announce text for screen readers (VoiceOver/TalkBack)
func announce(text: String, priority: bool = false) -> void:
	if priority:
		_announce_queue.push_front(text)
	else:
		_announce_queue.append(text)
	DisplayServer.tts_speak(text, "", 50, 1.0, 1.0)

## Stop current TTS
func stop_speaking() -> void:
	DisplayServer.tts_stop()
	_announce_queue.clear()

## Get scaled font size based on user preference
func scaled_font_size(base_size: int) -> int:
	var scale = GameSettings.font_scale if GameSettings else 1.0
	return maxi(int(float(base_size) * scale), 10)

## Check if reduced motion is enabled
func should_reduce_motion() -> bool:
	if GameSettings:
		return GameSettings.reduced_motion
	return false

## Check if high contrast is enabled
func is_high_contrast() -> bool:
	if GameSettings:
		return GameSettings.high_contrast
	return false

## Get colorblind-adjusted color
func adjust_color(color: Color) -> Color:
	var mode = GameSettings.colorblind_mode if GameSettings else 0
	if mode == 0:
		return color
	var matrix = COLORBLIND_MATRICES.get(mode, [])
	if matrix.is_empty():
		return color
	return Color(
		color.r * matrix[0] + color.g * matrix[1] + color.b * matrix[2],
		color.r * matrix[3] + color.g * matrix[4] + color.b * matrix[5],
		color.r * matrix[6] + color.g * matrix[7] + color.b * matrix[8],
		color.a
	)

## Make a button accessible
func make_accessible(control: Control, label: String, hint: String = "") -> void:
	control.tooltip_text = label
	if not hint.is_empty():
		control.tooltip_text += " - " + hint
	# Set minimum touch target size (44pt per Apple HIG)
	var min_size = 44.0
	if control.custom_minimum_size.x < min_size:
		control.custom_minimum_size.x = min_size
	if control.custom_minimum_size.y < min_size:
		control.custom_minimum_size.y = min_size

## Get animation speed multiplier (0.0 if reduced motion)
func anim_speed() -> float:
	if should_reduce_motion():
		return 0.0
	return 1.0

## Get animation duration (instant if reduced motion)
func anim_duration(base_duration: float) -> float:
	if should_reduce_motion():
		return 0.0
	return base_duration

func _detect_screen_reader() -> bool:
	# Check if TTS is available (indicates accessibility support)
	var voices = DisplayServer.tts_get_voices()
	return voices.size() > 0
