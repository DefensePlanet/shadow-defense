extends Node
## PerformanceMonitor — Frame budget monitoring with auto-quality adjustment.
## Enhancement #4 (Frame budget monitoring), #7 (LOD for enemies),
## #3 (Draw call awareness)
##
## Tracks frame time, detects sustained drops, and automatically
## downgrades/upgrades quality to maintain target frame rate.

signal quality_downgraded(new_level: int)
signal quality_upgraded(new_level: int)
signal performance_warning(fps: float, frame_ms: float)

# Frame time tracking
var _frame_times: Array = []
const SAMPLE_COUNT := 60  # Track last 60 frames
const TARGET_FRAME_MS := 16.67  # 60fps target
const DOWNGRADE_THRESHOLD_MS := 20.0  # Downgrade if > 50fps sustained
const UPGRADE_THRESHOLD_MS := 14.0  # Upgrade if stable < 14ms (>70fps)
const SUSTAINED_FRAMES := 30  # Must be sustained for 30 frames

var _downgrade_count: int = 0
var _upgrade_count: int = 0
var _last_adjustment_time: float = 0.0
const ADJUSTMENT_COOLDOWN := 10.0  # Don't adjust more than every 10 seconds

# Current stats (readable by debug HUD)
var current_fps: float = 60.0
var current_frame_ms: float = 16.67
var avg_frame_ms: float = 16.67
var max_frame_ms: float = 16.67
var active_enemies: int = 0
var active_objects: int = 0
var draw_calls: int = 0
var memory_usage_mb: float = 0.0

# LOD tracking (Enhancement #7)
var _lod_enemies: Dictionary = {}  # enemy_id -> lod_level (0=full, 1=reduced, 2=minimal)

# Battery-aware mode
var _battery_saver: bool = false

func _ready() -> void:
	# Check battery on mobile
	if OS.has_feature("mobile"):
		_check_battery()

func _process(delta: float) -> void:
	var frame_ms = delta * 1000.0
	_frame_times.append(frame_ms)
	if _frame_times.size() > SAMPLE_COUNT:
		_frame_times.pop_front()

	# Update current stats
	current_frame_ms = frame_ms
	current_fps = 1.0 / maxf(delta, 0.001)

	# Calculate averages every 30 frames
	if Engine.get_process_frames() % 30 == 0:
		_update_stats()
		_check_quality_adjustment()

	# Update object counts periodically
	if Engine.get_process_frames() % 60 == 0:
		_update_object_counts()
		if OS.has_feature("mobile") and Engine.get_process_frames() % 300 == 0:
			_check_battery()

## Update averaged statistics
func _update_stats() -> void:
	if _frame_times.is_empty():
		return
	var total := 0.0
	max_frame_ms = 0.0
	for ft in _frame_times:
		total += ft
		if ft > max_frame_ms:
			max_frame_ms = ft
	avg_frame_ms = total / float(_frame_times.size())

## Update object counts from pool and scene tree
func _update_object_counts() -> void:
	if ObjectPool:
		active_objects = ObjectPool.get_active_count()
	var enemies = get_tree().get_nodes_in_group("enemies")
	active_enemies = enemies.size()
	# Rough memory estimate
	memory_usage_mb = float(OS.get_static_memory_usage()) / 1048576.0

## Check if quality should be adjusted
func _check_quality_adjustment() -> void:
	if not GameSettings:
		return
	var now = Time.get_ticks_msec() / 1000.0
	if now - _last_adjustment_time < ADJUSTMENT_COOLDOWN:
		return

	if avg_frame_ms > DOWNGRADE_THRESHOLD_MS:
		_downgrade_count += 1
		_upgrade_count = 0
		if _downgrade_count >= SUSTAINED_FRAMES / 30:  # ~1 second sustained
			_downgrade_quality()
			_downgrade_count = 0
			_last_adjustment_time = now
	elif avg_frame_ms < UPGRADE_THRESHOLD_MS:
		_upgrade_count += 1
		_downgrade_count = 0
		if _upgrade_count >= (SUSTAINED_FRAMES * 3) / 30:  # ~3 seconds stable
			_upgrade_quality()
			_upgrade_count = 0
			_last_adjustment_time = now
	else:
		_downgrade_count = 0
		_upgrade_count = 0

## Downgrade quality one step
func _downgrade_quality() -> void:
	var current = GameSettings.effective_quality
	if current <= 0:
		return  # Already at minimum
	GameSettings.effective_quality = current - 1
	# Apply immediate changes
	match GameSettings.effective_quality:
		0:
			GameSettings.particle_effects = false
			GameSettings.env_particles = false
			GameSettings.show_damage_numbers = false
			GameSettings.draw_detail_level = 0
		1:
			GameSettings.env_particles = false
			GameSettings.draw_detail_level = 1
	quality_downgraded.emit(GameSettings.effective_quality)
	performance_warning.emit(current_fps, avg_frame_ms)

## Upgrade quality one step
func _upgrade_quality() -> void:
	var current = GameSettings.effective_quality
	# Don't upgrade beyond user's chosen quality
	var max_quality = GameSettings.quality_level if GameSettings.quality_level >= 0 else 2
	if current >= max_quality:
		return
	if _battery_saver and current >= 1:
		return  # Don't upgrade past medium in battery saver
	GameSettings.effective_quality = current + 1
	match GameSettings.effective_quality:
		1:
			GameSettings.particle_effects = true
			GameSettings.draw_detail_level = 1
		2:
			GameSettings.env_particles = true
			GameSettings.draw_detail_level = 2
			GameSettings.show_damage_numbers = true
	quality_upgraded.emit(GameSettings.effective_quality)

## Enhancement #7: Determine LOD level for an enemy
func get_enemy_lod(enemy: Node2D, camera_center: Vector2, nearest_tower_dist: float) -> int:
	if not GameSettings or not GameSettings.enemy_lod:
		return 0  # Full detail always
	# Off-screen: minimal
	var vp_size = get_viewport().get_visible_rect().size
	var screen_pos = enemy.global_position  # In canvas coordinates
	if screen_pos.x < -50 or screen_pos.x > vp_size.x + 50 or screen_pos.y < -50 or screen_pos.y > vp_size.y + 50:
		return 2  # Minimal: skip _draw(), simplified _process()
	# Far from any tower: reduced
	if nearest_tower_dist > 200.0:
		return 1  # Reduced: simplified visuals
	return 0  # Full detail

## Check battery level for battery-aware mode
func _check_battery() -> void:
	# Godot doesn't have direct battery API, but we can check power state
	if OS.has_feature("android"):
		# Android: could use JNI, for now estimate from thermal state
		_battery_saver = false  # Placeholder
	elif OS.has_feature("ios"):
		_battery_saver = false  # Placeholder

## Get a debug string for displaying performance info
func get_debug_string() -> String:
	return "FPS: %.0f | Frame: %.1fms | Avg: %.1fms | Max: %.1fms | Enemies: %d | Objects: %d | Quality: %d | Mem: %.0fMB" % [
		current_fps, current_frame_ms, avg_frame_ms, max_frame_ms,
		active_enemies, active_objects,
		GameSettings.effective_quality if GameSettings else -1,
		memory_usage_mb
	]
