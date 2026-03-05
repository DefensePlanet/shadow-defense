extends Node
## LocalizationManager — i18n framework setup.
## Addresses: #18 (Localization)
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

func _ready() -> void:
	# Set default locale
	current_locale = GameSettings.language if GameSettings else "en"
	TranslationServer.set_locale(current_locale)

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
	if translated == key and not fallback.is_empty():
		return fallback
	return translated

## Format a translated string with arguments
func tr_format(key: String, args: Array) -> String:
	var translated = tr(key)
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
