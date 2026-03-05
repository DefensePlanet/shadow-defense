extends Node
## PrivacyManager — Privacy consent and legal compliance.
## Addresses: #14 (Privacy policy / legal compliance)
##
## Handles GDPR consent, privacy policy display, data collection disclosure,
## and age gate for COPPA compliance.

signal consent_given
signal consent_revoked

var consent_granted: bool = false
var consent_date: String = ""
var age_verified: bool = false
var data_collection_enabled: bool = false

const PRIVACY_PATH := "user://privacy_consent.json"
const PRIVACY_POLICY_URL := "https://defenseplanet.org/privacy"

# What data we collect (disclosed to user)
const DATA_DISCLOSURE := [
	"Game progress and save data (stored locally on your device)",
	"Anonymous gameplay statistics (levels played, towers used)",
	"Session duration and retention metrics",
	"Device type and OS version (for compatibility)",
	"Crash reports (if they occur)",
]

# What we do NOT collect
const DATA_NOT_COLLECTED := [
	"Personal information (name, email, phone)",
	"Location data",
	"Contact lists or photos",
	"Financial information",
	"Advertising identifiers",
]

func _ready() -> void:
	_load_consent()

## Check if consent screen should be shown
func needs_consent() -> bool:
	return not consent_granted

## Grant consent
func grant_consent() -> void:
	consent_granted = true
	consent_date = Time.get_date_string_from_system()
	data_collection_enabled = true
	_save_consent()
	consent_given.emit()

## Revoke consent
func revoke_consent() -> void:
	consent_granted = false
	data_collection_enabled = false
	_save_consent()
	consent_revoked.emit()

## Verify age (COPPA: must be 13+)
func verify_age(is_13_or_older: bool) -> void:
	age_verified = is_13_or_older
	if not is_13_or_older:
		# Disable all data collection for under-13
		data_collection_enabled = false
	_save_consent()

## Delete all user data (GDPR right to erasure)
func delete_all_data() -> void:
	# Delete save file
	var save_paths = [
		"user://shadowdefense_save.json",
		"user://shadowdefense_save.json.bak",
		"user://shadowdefense_save.json.bak1",
		"user://shadowdefense_save.json.bak2",
		"user://settings.cfg",
		"user://analytics.json",
		"user://purchases.json",
		"user://cloud_meta.json",
		"user://privacy_consent.json",
	]
	for path in save_paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	consent_granted = false
	data_collection_enabled = false
	consent_revoked.emit()

## Get privacy policy text
func get_privacy_policy_text() -> String:
	return """SHADOW DEFENSE: TALES FROM THE PAGES
PRIVACY POLICY

Last Updated: 2026-03-04

1. INFORMATION WE COLLECT
We collect anonymous gameplay statistics to improve the game experience. This includes levels completed, towers used, and session duration. No personally identifiable information is collected.

2. HOW WE USE INFORMATION
Gameplay data is used solely to improve game balance, fix bugs, and enhance the player experience. We do not sell or share your data with third parties.

3. DATA STORAGE
All game progress is stored locally on your device. Optional cloud save requires explicit opt-in.

4. CHILDREN'S PRIVACY (COPPA)
Shadow Defense does not knowingly collect data from children under 13. If you are under 13, data collection features are automatically disabled.

5. YOUR RIGHTS (GDPR)
You may request deletion of all data at any time through the in-game Settings menu. You may revoke consent for data collection at any time.

6. CONTACT
For privacy concerns, visit: https://defenseplanet.org/privacy

7. CHANGES
We may update this policy. Changes will be noted with an updated date above."""

## Get short disclosure for consent screen
func get_consent_summary() -> String:
	return "Shadow Defense collects anonymous gameplay stats (levels played, session duration) to improve the game. No personal data is collected. You can opt out anytime in Settings."

## Open privacy policy URL in browser
func open_privacy_policy() -> void:
	OS.shell_open(PRIVACY_POLICY_URL)

func _save_consent() -> void:
	var data = {
		"consent_granted": consent_granted,
		"consent_date": consent_date,
		"age_verified": age_verified,
		"data_collection": data_collection_enabled,
	}
	var file = FileAccess.open(PRIVACY_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func _load_consent() -> void:
	if not FileAccess.file_exists(PRIVACY_PATH):
		return
	var file = FileAccess.open(PRIVACY_PATH, FileAccess.READ)
	if not file:
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		consent_granted = bool(json.data.get("consent_granted", false))
		consent_date = str(json.data.get("consent_date", ""))
		age_verified = bool(json.data.get("age_verified", false))
		data_collection_enabled = bool(json.data.get("data_collection", false))
