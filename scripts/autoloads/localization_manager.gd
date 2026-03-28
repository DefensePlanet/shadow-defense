extends Node
## LocalizationManager — i18n framework setup.
## Addresses: #18 (Localization)
## Enhanced: #49 (Translation CSV loading, key-based string lookup)
##
## Manages translation loading, language switching, and string lookup.
## Uses Godot's built-in TranslationServer with CSV-based translations.

signal language_changed(locale: String)

const SUPPORTED_LANGUAGES: Dictionary = {
	"en": "English",
	"es": "Espanol",
	"fr": "Francais",
	"de": "Deutsch",
	"pt": "Portugues",
	"ja": "Japanese",
	"ko": "Korean",
	"zh": "Chinese (Simplified)",
}

var current_locale: String = "en"

# Enhancement #49: Fallback dictionary for keys not in CSV
var _fallback_strings: Dictionary = {}

func _ready() -> void:
	# Set default locale
	current_locale = GameSettings.language if GameSettings else "en"
	TranslationServer.set_locale(current_locale)
	_load_fallback_strings()

## Switch language
func set_language(locale: String) -> void:
	if not SUPPORTED_LANGUAGES.has(locale):
		push_warning("Unsupported locale: %s, falling back to English" % locale)
		locale = "en"
	current_locale = locale
	TranslationServer.set_locale(locale)
	if GameSettings:
		GameSettings.language = locale
		GameSettings.save_settings()
	language_changed.emit(locale)

## Get translated string with fallback
func tr_safe(key: String, fallback: String = "") -> String:
	var translated = tr(key)
	if translated == key:
		# Not found in TranslationServer, try fallback dict
		if _fallback_strings.has(key):
			return _fallback_strings[key]
		if not fallback.is_empty():
			return fallback
	return translated

## Format a translated string with arguments
func tr_format(key: String, args: Array) -> String:
	var translated = tr_safe(key, key)
	if args.size() > 0:
		return translated % args
	return translated

## Get list of available languages
func get_available_languages() -> Dictionary:
	return SUPPORTED_LANGUAGES.duplicate()

## Get language display name
func get_language_name(locale: String) -> String:
	return SUPPORTED_LANGUAGES.get(locale, locale)

## Get current language display name
func get_current_language_name() -> String:
	return SUPPORTED_LANGUAGES.get(current_locale, current_locale)

## Enhancement #49: Get number formatted for locale
func format_number(value: int) -> String:
	var s = str(absi(value))
	var result = ""
	var sep = ","
	match current_locale:
		"de", "fr", "es", "pt":
			sep = "."
		"ja", "ko", "zh":
			sep = ","
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = sep + result
		result = s[i] + result
		count += 1
	if value < 0:
		result = "-" + result
	return result

## Enhancement #49: Get abbreviated number (1.5K, 2.3M)
func format_number_short(value: float) -> String:
	if value >= 1000000.0:
		return "%.1fM" % (value / 1000000.0)
	elif value >= 1000.0:
		return "%.1fK" % (value / 1000.0)
	return str(int(value))

## Enhancement #49: Load fallback strings for common UI text
## These serve as defaults until CSV translations are added
func _load_fallback_strings() -> void:
	_fallback_strings = {
		# Menu
		"MENU_PLAY": "PLAY",
		"MENU_CHAPTERS": "Chapters",
		"MENU_SURVIVORS": "Heroes",
		"MENU_EMPORIUM": "Emporium",
		"MENU_CHRONICLES": "Chronicles",
		"MENU_SETTINGS": "Settings",
		"MENU_CONTINUE": "Continue",
		"MENU_RESTART": "Restart",
		"MENU_QUIT": "Quit",
		# Battle
		"BATTLE_WAVE": "Wave",
		"BATTLE_GOLD": "Gold",
		"BATTLE_LIVES": "Lives",
		"BATTLE_START": "Start Wave",
		"BATTLE_SPEED_1X": "1x",
		"BATTLE_SPEED_2X": "2x",
		"BATTLE_SPEED_3X": "3x",
		"BATTLE_PAUSE": "Pause",
		# Tower
		"TOWER_UPGRADE": "Upgrade",
		"TOWER_SELL": "Sell",
		"TOWER_TARGET_FIRST": "First",
		"TOWER_TARGET_LAST": "Last",
		"TOWER_TARGET_CLOSE": "Close",
		"TOWER_TARGET_STRONG": "Strong",
		# Game Over
		"GAMEOVER_TITLE": "Game Over",
		"GAMEOVER_WAVE_REACHED": "Wave Reached",
		"GAMEOVER_RETRY": "Retry",
		"GAMEOVER_MENU": "Menu",
		"GAMEOVER_REVIVE": "Revive (Watch Ad)",
		# Victory
		"VICTORY_TITLE": "Victory!",
		"VICTORY_STARS": "Stars Earned",
		"VICTORY_REWARDS": "Rewards",
		"VICTORY_NEXT": "Next Chapter",
		"VICTORY_SHARE": "Share",
		# Settings
		"SETTINGS_AUDIO": "Audio",
		"SETTINGS_GRAPHICS": "Graphics",
		"SETTINGS_GAMEPLAY": "Gameplay",
		"SETTINGS_ACCESSIBILITY": "Accessibility",
		"SETTINGS_CONTROLS": "Controls",
		"SETTINGS_LANGUAGE": "Language",
		"SETTINGS_QUALITY_AUTO": "Auto",
		"SETTINGS_QUALITY_LOW": "Low",
		"SETTINGS_QUALITY_MED": "Medium",
		"SETTINGS_QUALITY_HIGH": "High",
		"SETTINGS_SPEED": "Game Speed",
		"SETTINGS_LEFT_HANDED": "Left-Handed Mode",
		"SETTINGS_ONE_HANDED": "One-Handed Mode",
		"SETTINGS_COLORBLIND": "Colorblind Mode",
		"SETTINGS_FONT_SIZE": "Font Size",
		# Accessibility
		"A11Y_REDUCED_MOTION": "Reduced Motion",
		"A11Y_HIGH_CONTRAST": "High Contrast",
		"A11Y_HAPTIC": "Haptic Feedback",
		"A11Y_VOICEOVER": "Screen Reader Hints",
	}
