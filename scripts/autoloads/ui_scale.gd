extends Node
## UIScale — Responsive UI helper for phone adaptation.
## Provides scale factors and safe positioning based on actual viewport size.
## Addresses: #2 (Responsive UI), #15 (Safe area/notch handling)

signal viewport_changed

var base_width: float = 1280.0
var base_height: float = 720.0
var scale_x: float = 1.0
var scale_y: float = 1.0
var scale_min: float = 1.0
var safe_area: Rect2 = Rect2()
var safe_margins: Dictionary = {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}

func _ready() -> void:
	get_tree().root.size_changed.connect(_on_viewport_resized)
	_on_viewport_resized()

func _on_viewport_resized() -> void:
	var vp_size = get_viewport().get_visible_rect().size
	scale_x = vp_size.x / base_width
	scale_y = vp_size.y / base_height
	scale_min = minf(scale_x, scale_y)
	_update_safe_area()
	viewport_changed.emit()

func _update_safe_area() -> void:
	var vp_size = get_viewport().get_visible_rect().size
	if DisplayServer.has_feature(DisplayServer.FEATURE_KEEP_SCREEN_ON):
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

## Scale a font size for readability on small screens
func font_size(base_size: int) -> int:
	var s = float(base_size) * scale_min
	return maxi(int(s), 10)

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
