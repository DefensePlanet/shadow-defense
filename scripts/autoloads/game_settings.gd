extends Node
## GameSettings — Persistent settings manager.
## Addresses: #9 (Settings screen)

signal settings_changed

const SETTINGS_PATH := "user://settings.cfg"

# Audio
var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 1.0
var voice_volume: float = 1.0

# Graphics
var quality_level: int = 2  # 0=Low, 1=Medium, 2=High
var particle_effects: bool = true
var screen_shake: bool = true
var show_damage_numbers: bool = true
var fps_limit: int = 60

# Gameplay
var auto_wave: bool = false
var auto_wave_delay: float = 3.0
var tower_confirm_placement: bool = false
var double_tap_deselect: bool = true

# Accessibility
var font_scale: float = 1.0
var high_contrast: bool = false
var colorblind_mode: int = 0  # 0=Off, 1=Deuteranopia, 2=Protanopia, 3=Tritanopia
var reduced_motion: bool = false
var haptic_feedback: bool = true

# Controls
var touch_sensitivity: float = 1.0
var pinch_zoom: bool = true
var long_press_info: bool = true

# Language
var language: String = "en"

func _ready() -> void:
	load_settings()

func save_settings() -> void:
	var config = ConfigFile.new()
	# Audio
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "voice_volume", voice_volume)
	# Graphics
	config.set_value("graphics", "quality_level", quality_level)
	config.set_value("graphics", "particle_effects", particle_effects)
	config.set_value("graphics", "screen_shake", screen_shake)
	config.set_value("graphics", "show_damage_numbers", show_damage_numbers)
	config.set_value("graphics", "fps_limit", fps_limit)
	# Gameplay
	config.set_value("gameplay", "auto_wave", auto_wave)
	config.set_value("gameplay", "auto_wave_delay", auto_wave_delay)
	config.set_value("gameplay", "tower_confirm_placement", tower_confirm_placement)
	config.set_value("gameplay", "double_tap_deselect", double_tap_deselect)
	# Accessibility
	config.set_value("accessibility", "font_scale", font_scale)
	config.set_value("accessibility", "high_contrast", high_contrast)
	config.set_value("accessibility", "colorblind_mode", colorblind_mode)
	config.set_value("accessibility", "reduced_motion", reduced_motion)
	config.set_value("accessibility", "haptic_feedback", haptic_feedback)
	# Controls
	config.set_value("controls", "touch_sensitivity", touch_sensitivity)
	config.set_value("controls", "pinch_zoom", pinch_zoom)
	config.set_value("controls", "long_press_info", long_press_info)
	# Language
	config.set_value("general", "language", language)
	config.save(SETTINGS_PATH)
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
	# Graphics
	quality_level = config.get_value("graphics", "quality_level", 2)
	particle_effects = config.get_value("graphics", "particle_effects", true)
	screen_shake = config.get_value("graphics", "screen_shake", true)
	show_damage_numbers = config.get_value("graphics", "show_damage_numbers", true)
	fps_limit = config.get_value("graphics", "fps_limit", 60)
	# Gameplay
	auto_wave = config.get_value("gameplay", "auto_wave", false)
	auto_wave_delay = config.get_value("gameplay", "auto_wave_delay", 3.0)
	tower_confirm_placement = config.get_value("gameplay", "tower_confirm_placement", false)
	double_tap_deselect = config.get_value("gameplay", "double_tap_deselect", true)
	# Accessibility
	font_scale = config.get_value("accessibility", "font_scale", 1.0)
	high_contrast = config.get_value("accessibility", "high_contrast", false)
	colorblind_mode = config.get_value("accessibility", "colorblind_mode", 0)
	reduced_motion = config.get_value("accessibility", "reduced_motion", false)
	haptic_feedback = config.get_value("accessibility", "haptic_feedback", true)
	# Controls
	touch_sensitivity = config.get_value("controls", "touch_sensitivity", 1.0)
	pinch_zoom = config.get_value("controls", "pinch_zoom", true)
	long_press_info = config.get_value("controls", "long_press_info", true)
	# Language
	language = config.get_value("general", "language", "en")
	_apply_settings()

func _apply_settings() -> void:
	# Apply audio bus volumes
	var master_bus = AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(master_volume))
	# Apply FPS limit
	Engine.max_fps = fps_limit
	# Apply language
	TranslationServer.set_locale(language)

func reset_to_defaults() -> void:
	master_volume = 1.0
	music_volume = 0.8
	sfx_volume = 1.0
	voice_volume = 1.0
	quality_level = 2
	particle_effects = true
	screen_shake = true
	show_damage_numbers = true
	fps_limit = 60
	auto_wave = false
	auto_wave_delay = 3.0
	tower_confirm_placement = false
	double_tap_deselect = true
	font_scale = 1.0
	high_contrast = false
	colorblind_mode = 0
	reduced_motion = false
	haptic_feedback = true
	touch_sensitivity = 1.0
	pinch_zoom = true
	long_press_info = true
	language = "en"
	save_settings()
