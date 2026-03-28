extends Node
## UIScale — Responsive UI helper for phone adaptation.
## Provides scale factors and safe positioning based on actual viewport size.
## Addresses: #2 (Responsive UI), #15 (Safe area/notch handling)
## Enhanced: #21 (Thumb reachability), #23 (Portrait support),
## #24 (Damage number scaling), #25 (Adaptive font sizes),
## #46 (Left-handed layout), #47 (One-handed mode)

signal viewport_changed

var base_width: float = 1280.0
var base_height: float = 720.0
var scale_x: float = 1.0
var scale_y: float = 1.0
var scale_min: float = 1.0
var safe_area: Rect2 = Rect2()
var safe_margins: Dictionary = {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}

# Enhancement #21: Thumb zone tracking
var thumb_zone_center: Vector2 = Vector2.ZERO  # Bottom-center or adjusted for handedness
var thumb_zone_radius: float = 300.0
# Enhancement #23: Orientation
var is_portrait: bool = false
var aspect_ratio: float = 16.0 / 9.0
# Enhancement #47: One-handed viewport area
var playable_rect: Rect2 = Rect2()

func _ready() -> void:
	get_tree().root.size_changed.connect(_on_viewport_resized)
	_on_viewport_resized()

func _on_viewport_resized() -> void:
	var vp_size = get_viewport().get_visible_rect().size
	scale_x = vp_size.x / base_width
	scale_y = vp_size.y / base_height
	scale_min = minf(scale_x, scale_y)
	aspect_ratio = vp_size.x / maxf(vp_size.y, 1.0)
	is_portrait = vp_size.y > vp_size.x
	_update_safe_area()
	_update_thumb_zone()
	_update_playable_rect()
	viewport_changed.emit()

func _update_safe_area() -> void:
	var vp_size = get_viewport().get_visible_rect().size
	if DisplayServer.has_method("get_display_safe_area"):
		safe_area = DisplayServer.get_display_safe_area()
	else:
		safe_area = Rect2(Vector2.ZERO, vp_size)
	# Calculate margins in virtual (1280x720) coordinates
	var window_size = DisplayServer.window_get_size()
	if window_size.x > 0 and window_size.y > 0:
		var sx = base_width / float(window_size.x)
		var sy = base_height / float(window_size.y)
		safe_margins["left"] = safe_area.position.x * sx
		safe_margins["right"] = maxf(0.0, (float(window_size.x) - safe_area.end.x) * sx)
		safe_margins["top"] = safe_area.position.y * sy
		safe_margins["bottom"] = maxf(0.0, (float(window_size.y) - safe_area.end.y) * sy)
	else:
		safe_margins = {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}

## Enhancement #21: Compute thumb-reachable zone
func _update_thumb_zone() -> void:
	var left_handed = GameSettings.left_handed if GameSettings else false
	if left_handed:
		# Left-handed: thumb zone is bottom-left
		thumb_zone_center = Vector2(base_width * 0.3, base_height * 0.8)
	else:
		# Right-handed: thumb zone is bottom-right
		thumb_zone_center = Vector2(base_width * 0.7, base_height * 0.8)
	# Scale radius for small screens
	thumb_zone_radius = 300.0 * scale_min

## Enhancement #47: Compute playable rect for one-handed mode
func _update_playable_rect() -> void:
	var one_handed = GameSettings.one_handed if GameSettings else false
	if one_handed:
		# Shrink to bottom 65% of screen
		var top_offset = base_height * 0.35
		playable_rect = Rect2(
			safe_margins["left"],
			top_offset + safe_margins["top"],
			safe_width(),
			base_height - top_offset - safe_margins["top"] - safe_margins["bottom"]
		)
	else:
		playable_rect = Rect2(
			safe_margins["left"],
			safe_margins["top"],
			safe_width(),
			safe_height()
		)

## Convert a base-resolution position to safe position
func safe_pos(pos: Vector2) -> Vector2:
	return Vector2(pos.x + safe_margins["left"], pos.y + safe_margins["top"])

## Get usable width after safe area insets
func safe_width() -> float:
	return base_width - safe_margins["left"] - safe_margins["right"]

## Get usable height after safe area insets
func safe_height() -> float:
	return base_height - safe_margins["top"] - safe_margins["bottom"]

## Scale a size value proportionally
func scaled(value: float) -> float:
	return value * scale_min

## Enhancement #25: Scale a font size for readability on small screens
## Respects accessibility font_scale setting
func font_size(base_size: int) -> int:
	var font_scale = GameSettings.font_scale if GameSettings else 1.0
	var s = float(base_size) * scale_min * font_scale
	return maxi(int(s), 10)

## Enhancement #24: Scale damage numbers for readability
func damage_number_size(base_size: float, is_boss: bool = false) -> float:
	var s = base_size * scale_min
	if is_boss:
		s *= 1.5
	# Minimum readable size on phone
	return maxf(s, 12.0)

## Check if running on a small phone screen (< 5.5 inch equivalent)
func is_small_screen() -> bool:
	var vp = get_viewport().get_visible_rect().size
	return vp.x < 960 or vp.y < 540

## Check if device is a tablet
func is_tablet() -> bool:
	var vp = get_viewport().get_visible_rect().size
	return vp.x >= 1920 or vp.y >= 1080

## Get appropriate touch target size (minimum 44pt per Apple HIG)
func touch_target_size() -> float:
	return maxf(44.0 * scale_min, 44.0)

## Enhancement #21: Check if a position is within thumb reach
func is_in_thumb_zone(pos: Vector2) -> bool:
	return pos.distance_to(thumb_zone_center) <= thumb_zone_radius

## Enhancement #46: Get the X position for UI elements based on handedness
## Returns left-aligned X for right-handed, right-aligned for left-handed
func ui_anchor_x(default_x: float, width: float = 0.0) -> float:
	if GameSettings and GameSettings.left_handed:
		# Mirror: reflect around center
		return base_width - default_x - width
	return default_x

## Enhancement #46: Get mirrored position for left-handed mode
func mirror_pos(pos: Vector2) -> Vector2:
	if GameSettings and GameSettings.left_handed:
		return Vector2(base_width - pos.x, pos.y)
	return pos

## Enhancement #13: Get upgrade panel rect sized for touch targets
func upgrade_panel_rect() -> Rect2:
	if is_small_screen():
		# Full-width card on small screens
		return Rect2(20, base_height * 0.4, base_width - 40, base_height * 0.55)
	else:
		return Rect2(base_width * 0.25, base_height * 0.3, base_width * 0.5, base_height * 0.5)

## Enhancement #16: Get radial menu positions for tower selection
func get_radial_positions(center: Vector2, count: int, radius: float = 80.0) -> Array:
	var positions: Array = []
	var angle_step = TAU / float(count)
	var start_angle = -PI / 2.0  # Start from top
	for i in range(count):
		var angle = start_angle + angle_step * i
		positions.append(center + Vector2(cos(angle), sin(angle)) * radius * scale_min)
	return positions

## Get the bottom panel Y position (adjusted for one-handed mode)
func bottom_panel_y() -> float:
	if GameSettings and GameSettings.one_handed:
		return playable_rect.position.y + playable_rect.size.y - 90.0
	return base_height - 90.0

## Get the top bar Y position (adjusted for safe area)
func top_bar_y() -> float:
	return safe_margins["top"]
