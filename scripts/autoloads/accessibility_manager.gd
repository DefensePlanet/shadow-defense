extends Node
## AccessibilityManager — Accessibility features for mobile.
## Addresses: #20 (Accessibility)
## Enhanced: #43 (Full VoiceOver/TalkBack), #44 (Colorblind shader),
## #46 (Left-handed mode), #47 (One-handed mode)
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
var _announce_cooldown: float = 0.0

# Enhancement #44: Colorblind shader layer
var _colorblind_canvas: CanvasLayer = null
var _colorblind_rect: ColorRect = null
var _colorblind_shader: ShaderMaterial = null

func _ready() -> void:
	# Detect if screen reader is active
	screen_reader_active = _detect_screen_reader()
	# Enhancement #44: Setup colorblind overlay
	_setup_colorblind_shader()

func _process(delta: float) -> void:
	# Enhancement #43: Process announcement queue
	if _announce_cooldown > 0.0:
		_announce_cooldown -= delta
	elif _announce_queue.size() > 0 and _announce_cooldown <= 0.0:
		var text = _announce_queue.pop_front()
		DisplayServer.tts_speak(text, "", 50, 1.0, 1.0)
		_announce_cooldown = 0.5  # Minimum gap between announcements

## Enhancement #43: Announce text for screen readers (VoiceOver/TalkBack)
func announce(text: String, priority: bool = false) -> void:
	if not GameSettings or not GameSettings.voiceover_hints:
		return
	if priority:
		_announce_queue.push_front(text)
	else:
		_announce_queue.append(text)
	# Keep queue manageable
	while _announce_queue.size() > 10:
		_announce_queue.pop_back()

## Enhancement #43: Announce game events
func announce_wave_start(wave: int, total: int) -> void:
	announce("Wave %d of %d" % [wave, total], true)

func announce_enemy_count(count: int) -> void:
	if count <= 5:
		announce("%d enemies remaining" % count)

func announce_tower_placed(tower_name: String) -> void:
	announce("%s placed" % tower_name)

func announce_upgrade(tower_name: String, tier: int) -> void:
	announce("%s upgraded to tier %d" % [tower_name, tier])

func announce_game_over(wave: int) -> void:
	announce("Game over at wave %d" % wave, true)

func announce_victory(stars: int) -> void:
	announce("Victory! %d stars earned" % stars, true)

func announce_gold_change(amount: int, total: int) -> void:
	if absf(amount) >= 50:
		if amount > 0:
			announce("Earned %d gold. Total: %d" % [amount, total])
		else:
			announce("Spent %d gold. Remaining: %d" % [absi(amount), total])

func announce_lives_change(lives: int) -> void:
	if lives <= 5:
		announce("Warning: %d lives remaining" % lives, true)

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

## Get high contrast version of a color
func contrast_color(color: Color, bg_is_dark: bool = true) -> Color:
	if not is_high_contrast():
		return color
	# Boost saturation and contrast
	var h = color.h
	var s = minf(color.s * 1.5, 1.0)
	var v = color.v
	if bg_is_dark:
		v = maxf(v, 0.7)  # Ensure text is bright on dark
	else:
		v = minf(v, 0.3)  # Ensure text is dark on light
	return Color.from_hsv(h, s, v, color.a)

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

## Enhancement #44: Setup colorblind correction shader
func _setup_colorblind_shader() -> void:
	_colorblind_canvas = CanvasLayer.new()
	_colorblind_canvas.layer = 100  # On top of everything
	add_child(_colorblind_canvas)

	_colorblind_rect = ColorRect.new()
	_colorblind_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_colorblind_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block input

	# Create shader
	var shader = Shader.new()
	shader.code = _get_colorblind_shader_code()
	_colorblind_shader = ShaderMaterial.new()
	_colorblind_shader.shader = shader
	_colorblind_rect.material = _colorblind_shader

	_colorblind_canvas.add_child(_colorblind_rect)
	_update_colorblind_shader()

## Enhancement #44: Update colorblind shader based on current mode
func _update_colorblind_shader() -> void:
	if not _colorblind_shader:
		return
	var mode = GameSettings.colorblind_mode if GameSettings else 0
	if mode == 0:
		_colorblind_rect.visible = false
		return
	_colorblind_rect.visible = true
	var matrix = COLORBLIND_MATRICES.get(mode, [])
	if matrix.size() >= 9:
		_colorblind_shader.set_shader_parameter("correction_matrix",
			[Vector3(matrix[0], matrix[1], matrix[2]),
			 Vector3(matrix[3], matrix[4], matrix[5]),
			 Vector3(matrix[6], matrix[7], matrix[8])])

## Apply accessibility changes (call when settings change)
func apply_changes() -> void:
	_update_colorblind_shader()
	accessibility_changed.emit()

func _get_colorblind_shader_code() -> String:
	return """shader_type canvas_item;
uniform vec3 correction_matrix[3];
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 corrected;
	corrected.r = dot(tex.rgb, correction_matrix[0]);
	corrected.g = dot(tex.rgb, correction_matrix[1]);
	corrected.b = dot(tex.rgb, correction_matrix[2]);
	COLOR = vec4(corrected, tex.a * step(0.01, tex.a));
}
"""

func _detect_screen_reader() -> bool:
	# Check if TTS is available (indicates accessibility support)
	var voices = DisplayServer.tts_get_voices()
	return voices.size() > 0
