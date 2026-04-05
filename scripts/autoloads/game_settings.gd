extends Node
## GameSettings — Persistent settings manager.
## Addresses: #9 (Settings screen)
## Enhanced: #2 (Quality tiers), #22 (Speed controls), #38 (Audio buses),
## #46 (Left-handed mode), #47 (One-handed mode), #42 (Silent mode respect)

signal settings_changed

const SETTINGS_PATH := "user://settings.cfg"

# Audio
var master_volume: float = 1.0
var music_volume: float = 0.45
var sfx_volume: float = 1.0
var voice_volume: float = 1.0
var music_muted: bool = false
var sfx_muted: bool = false
var voice_muted: bool = false
var audio_ducking: bool = true  # Enhancement #41: duck music during voice

# Graphics
var quality_level: int = -1  # -1=Auto, 0=Low, 1=Medium, 2=High
var particle_effects: bool = true
var screen_shake: bool = true
var show_damage_numbers: bool = true
var fps_limit: int = 60
var env_particles: bool = true  # Enhancement #2: separate toggle
var draw_detail_level: int = 2  # 0=minimal, 1=standard, 2=full
var enemy_lod: bool = true  # Enhancement #7: LOD for distant enemies

# Gameplay
var auto_wave: bool = false
var auto_wave_delay: float = 3.0
var tower_confirm_placement: bool = false
var double_tap_deselect: bool = true
var game_speed: int = 1  # Enhancement #22: 1x, 2x, 3x
var drag_to_place: bool = true  # Enhancement #11: drag-and-drop tower placement
var gesture_shortcuts: bool = true  # Enhancement #12: swipe gestures on towers

# Accessibility
var font_scale: float = 1.0
var high_contrast: bool = false
var colorblind_mode: int = 0  # 0=Off, 1=Deuteranopia, 2=Protanopia, 3=Tritanopia
var reduced_motion: bool = false
var haptic_feedback: bool = true
var left_handed: bool = false  # Enhancement #46
var one_handed: bool = false  # Enhancement #47
var voiceover_hints: bool = false  # Enhancement #43 — off by default, enable in accessibility settings

# Controls
var touch_sensitivity: float = 1.0
var pinch_zoom: bool = true
var long_press_info: bool = true

# Language
var language: String = "en"

# Derived quality settings (computed from quality_level)
var effective_quality: int = 2  # Always 0/1/2 after auto-detect

func _ready() -> void:
	load_settings()
	if quality_level == -1:
		_auto_detect_quality()
	else:
		effective_quality = quality_level
	_apply_settings()

func _auto_detect_quality() -> void:
	# Enhancement #2: Auto-detect quality based on device capabilities
	var gpu_name = RenderingServer.get_rendering_device().get_device_name() if RenderingServer.get_rendering_device() else ""
	var is_mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")

	if not is_mobile:
		effective_quality = 2
		return

	# Check available memory (Godot doesn't expose this directly, estimate from OS)
	var vp_size = Vector2(1280, 720)
	if DisplayServer.window_get_size().x > 0:
		vp_size = Vector2(DisplayServer.window_get_size())

	# Low-res screens likely = low-end device
	if vp_size.x < 1080:
		effective_quality = 0
	elif vp_size.x < 1920:
		effective_quality = 1
	else:
		effective_quality = 2

	# Apply derived settings
	match effective_quality:
		0:
			particle_effects = false
			env_particles = false
			draw_detail_level = 0
			fps_limit = 30
			show_damage_numbers = false
		1:
			particle_effects = true
			env_particles = false
			draw_detail_level = 1
			fps_limit = 60
		2:
			particle_effects = true
			env_particles = true
			draw_detail_level = 2
			fps_limit = 60

## Get the effective game speed multiplier
func get_speed_scale() -> float:
	return float(clampi(game_speed, 1, 3))

## Cycle game speed 1 -> 2 -> 3 -> 1
func cycle_speed() -> void:
	game_speed = (game_speed % 3) + 1
	Engine.time_scale = get_speed_scale()
	settings_changed.emit()

## Set game speed directly
func set_speed(speed: int) -> void:
	game_speed = clampi(speed, 1, 3)
	Engine.time_scale = get_speed_scale()

## Cycle quality: Auto -> Low -> Medium -> High -> Auto
func cycle_quality() -> void:
	quality_level = (quality_level + 2) % 4 - 1  # -1, 0, 1, 2
	if quality_level == -1:
		_auto_detect_quality()
	else:
		effective_quality = quality_level
	settings_changed.emit()

## Get human-readable quality name
func get_quality_name() -> String:
	match quality_level:
		-1: return "AUTO"
		0: return "LOW"
		1: return "MED"
		2: return "HIGH"
	return "AUTO"

## Check if a feature should be enabled at current quality
func quality_allows(feature: String) -> bool:
	match feature:
		"env_particles": return effective_quality >= 2 and env_particles
		"wound_visuals": return effective_quality >= 1
		"tower_particles": return effective_quality >= 1 and particle_effects
		"smooth_transitions": return effective_quality >= 1 and not reduced_motion
		"damage_numbers": return show_damage_numbers
		"screen_shake": return screen_shake and not reduced_motion
		"enemy_lod": return enemy_lod
	return true

func save_settings() -> void:
	var config = ConfigFile.new()
	# Audio
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "voice_volume", voice_volume)
	config.set_value("audio", "music_muted", music_muted)
	config.set_value("audio", "sfx_muted", sfx_muted)
	config.set_value("audio", "voice_muted", voice_muted)
	config.set_value("audio", "audio_ducking", audio_ducking)
	# Graphics
	config.set_value("graphics", "quality_level", quality_level)
	config.set_value("graphics", "particle_effects", particle_effects)
	config.set_value("graphics", "screen_shake", screen_shake)
	config.set_value("graphics", "show_damage_numbers", show_damage_numbers)
	config.set_value("graphics", "fps_limit", fps_limit)
	config.set_value("graphics", "env_particles", env_particles)
	config.set_value("graphics", "draw_detail_level", draw_detail_level)
	config.set_value("graphics", "enemy_lod", enemy_lod)
	# Gameplay
	config.set_value("gameplay", "auto_wave", auto_wave)
	config.set_value("gameplay", "auto_wave_delay", auto_wave_delay)
	config.set_value("gameplay", "tower_confirm_placement", tower_confirm_placement)
	config.set_value("gameplay", "double_tap_deselect", double_tap_deselect)
	config.set_value("gameplay", "game_speed", game_speed)
	config.set_value("gameplay", "drag_to_place", drag_to_place)
	config.set_value("gameplay", "gesture_shortcuts", gesture_shortcuts)
	# Accessibility
	config.set_value("accessibility", "font_scale", font_scale)
	config.set_value("accessibility", "high_contrast", high_contrast)
	config.set_value("accessibility", "colorblind_mode", colorblind_mode)
	config.set_value("accessibility", "reduced_motion", reduced_motion)
	config.set_value("accessibility", "haptic_feedback", haptic_feedback)
	config.set_value("accessibility", "left_handed", left_handed)
	config.set_value("accessibility", "one_handed", one_handed)
	config.set_value("accessibility", "voiceover_hints", voiceover_hints)
	# Controls
	config.set_value("controls", "touch_sensitivity", touch_sensitivity)
	config.set_value("controls", "pinch_zoom", pinch_zoom)
	config.set_value("controls", "long_press_info", long_press_info)
	# Language
	config.set_value("general", "language", language)
	config.save(SETTINGS_PATH)
	_apply_settings()
	settings_changed.emit()

func load_settings() -> void:
	var config = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	# Audio
	master_volume = config.get_value("audio", "master_volume", 1.0)
	music_volume = config.get_value("audio", "music_volume", 0.8)
	sfx_volume = config.get_value("audio", "sfx_volume", 1.0)
	voice_volume = config.get_value("audio", "voice_volume", 1.0)
	music_muted = config.get_value("audio", "music_muted", false)
	sfx_muted = config.get_value("audio", "sfx_muted", false)
	voice_muted = config.get_value("audio", "voice_muted", false)
	audio_ducking = config.get_value("audio", "audio_ducking", true)
	# Graphics
	quality_level = config.get_value("graphics", "quality_level", -1)
	particle_effects = config.get_value("graphics", "particle_effects", true)
	screen_shake = config.get_value("graphics", "screen_shake", true)
	show_damage_numbers = config.get_value("graphics", "show_damage_numbers", true)
	fps_limit = config.get_value("graphics", "fps_limit", 60)
	env_particles = config.get_value("graphics", "env_particles", true)
	draw_detail_level = config.get_value("graphics", "draw_detail_level", 2)
	enemy_lod = config.get_value("graphics", "enemy_lod", true)
	# Gameplay
	auto_wave = config.get_value("gameplay", "auto_wave", false)
	auto_wave_delay = config.get_value("gameplay", "auto_wave_delay", 3.0)
	tower_confirm_placement = config.get_value("gameplay", "tower_confirm_placement", false)
	double_tap_deselect = config.get_value("gameplay", "double_tap_deselect", true)
	game_speed = config.get_value("gameplay", "game_speed", 1)
	drag_to_place = config.get_value("gameplay", "drag_to_place", true)
	gesture_shortcuts = config.get_value("gameplay", "gesture_shortcuts", true)
	# Accessibility
	font_scale = config.get_value("accessibility", "font_scale", 1.0)
	high_contrast = config.get_value("accessibility", "high_contrast", false)
	colorblind_mode = config.get_value("accessibility", "colorblind_mode", 0)
	reduced_motion = config.get_value("accessibility", "reduced_motion", false)
	haptic_feedback = config.get_value("accessibility", "haptic_feedback", true)
	left_handed = config.get_value("accessibility", "left_handed", false)
	one_handed = config.get_value("accessibility", "one_handed", false)
	voiceover_hints = config.get_value("accessibility", "voiceover_hints", true)
	# Controls
	touch_sensitivity = config.get_value("controls", "touch_sensitivity", 1.0)
	pinch_zoom = config.get_value("controls", "pinch_zoom", true)
	long_press_info = config.get_value("controls", "long_press_info", true)
	# Language
	language = config.get_value("general", "language", "en")
	_apply_settings()

func _apply_settings() -> void:
	# Enhancement #38: Apply audio bus volumes to separate buses
	_apply_audio_bus("Master", master_volume)
	_apply_audio_bus("Music", 0.0 if music_muted else music_volume * master_volume)
	_apply_audio_bus("SFX", 0.0 if sfx_muted else sfx_volume * master_volume)
	_apply_audio_bus("Voice", 0.0 if voice_muted else voice_volume * master_volume)
	# Enhancement #42: Respect silent mode
	_check_silent_mode()
	# Apply FPS limit
	Engine.max_fps = fps_limit
	# Apply game speed
	Engine.time_scale = get_speed_scale()
	# Apply language
	TranslationServer.set_locale(language)

func _apply_audio_bus(bus_name: String, volume: float) -> void:
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(volume))

func _check_silent_mode() -> void:
	# Enhancement #42: On mobile, if system volume is 0, mute game
	if OS.has_feature("mobile"):
		var master_bus = AudioServer.get_bus_index("Master")
		if master_bus >= 0:
			# Check if we should respect system mute
			if master_volume <= 0.01:
				AudioServer.set_bus_mute(master_bus, true)
			else:
				AudioServer.set_bus_mute(master_bus, false)

func reset_to_defaults() -> void:
	master_volume = 1.0
	music_volume = 0.45
	sfx_volume = 1.0
	voice_volume = 1.0
	music_muted = false
	sfx_muted = false
	voice_muted = false
	audio_ducking = true
	quality_level = -1
	particle_effects = true
	screen_shake = true
	show_damage_numbers = true
	fps_limit = 60
	env_particles = true
	draw_detail_level = 2
	enemy_lod = true
	auto_wave = false
	auto_wave_delay = 3.0
	tower_confirm_placement = false
	double_tap_deselect = true
	game_speed = 1
	drag_to_place = true
	gesture_shortcuts = true
	font_scale = 1.0
	high_contrast = false
	colorblind_mode = 0
	reduced_motion = false
	haptic_feedback = true
	left_handed = false
	one_handed = false
	voiceover_hints = true
	touch_sensitivity = 1.0
	pinch_zoom = true
	long_press_info = true
	language = "en"
	_auto_detect_quality()
	save_settings()
