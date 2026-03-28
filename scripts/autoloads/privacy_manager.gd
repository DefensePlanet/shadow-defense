extends Node
## PrivacyManager — Privacy consent and legal compliance.
## Addresses: #14 (Privacy policy / legal compliance)
## Enhanced: #45 (ATT — App Tracking Transparency for iOS)
##
## Handles GDPR consent, privacy policy display, data collection disclosure,
## age gate for COPPA compliance, and iOS ATT framework.

signal consent_given
signal consent_revoked
# Enhancement #45: ATT signal
signal att_status_changed(authorized: bool)

var consent_granted: bool = false
var consent_date: String = ""
var age_verified: bool = false
var data_collection_enabled: bool = false

# Enhancement #45: ATT state
var att_requested: bool = false
var att_authorized: bool = false  # true if user granted tracking, or platform doesn't require ATT

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
	"Advertising identifiers (unless you opt in)",
]

func _ready() -> void:
	_load_consent()
	# Enhancement #45: Check ATT status on iOS
	if OS.has_feature("ios"):
		_check_att_status()
	else:
		# Non-iOS platforms don't need ATT
		att_authorized = true

## Check if consent screen should be shown
func needs_consent() -> bool:
	return not consent_granted

## Enhancement #45: Check if ATT prompt should be shown (iOS 14.5+)
func needs_att_prompt() -> bool:
	if not OS.has_feature("ios"):
		return false
	return not att_requested

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

## Enhancement #45: Request ATT authorization (iOS)
func request_att_authorization() -> void:
	if not OS.has_feature("ios"):
		att_authorized = true
		att_requested = true
		_save_consent()
		att_status_changed.emit(true)
		return
	att_requested = true
	# Use iOS ATT plugin if available
	if Engine.has_singleton("AppTrackingTransparency"):
		var att = Engine.get_singleton("AppTrackingTransparency")
		att.request_authorization()
		# Connect to callback
		att.authorization_status_determined.connect(_on_att_determined)
	else:
		# No ATT plugin — assume authorized (pre-iOS 14.5 or no plugin)
		att_authorized = true
		_save_consent()
		att_status_changed.emit(true)

## Enhancement #45: Check current ATT status
func _check_att_status() -> void:
	if Engine.has_singleton("AppTrackingTransparency"):
		var att = Engine.get_singleton("AppTrackingTransparency")
		var status = att.get_authorization_status()
		match status:
			0:  # Not determined
				att_authorized = false
			1:  # Restricted
				att_authorized = false
				att_requested = true
			2:  # Denied
				att_authorized = false
				att_requested = true
			3:  # Authorized
				att_authorized = true
				att_requested = true
	else:
		att_authorized = true  # No plugin, assume OK

func _on_att_determined(status: int) -> void:
	att_authorized = (status == 3)  # 3 = authorized
	att_requested = true
	_save_consent()
	att_status_changed.emit(att_authorized)

## Check if data collection is fully authorized
func is_data_collection_ok() -> bool:
	return consent_granted and data_collection_enabled and (att_authorized or not OS.has_feature("ios"))

## Delete all user data (GDPR right to erasure)
func delete_all_data() -> void:
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
		"user://battle_pass.json",
		"user://daily_rewards.json",
	]
	for path in save_paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	consent_granted = false
	data_collection_enabled = false
	consent_revoked.emit()
	# Cancel scheduled notifications
	if AnalyticsManager:
		AnalyticsManager.cancel_all_notifications()

## Get privacy policy text
func get_privacy_policy_text() -> String:
	return """SHADOW DEFENSE: TALES FROM THE PAGES
PRIVACY POLICY

Last Updated: 2026-03-10

1. INFORMATION WE COLLECT
We collect anonymous gameplay statistics to improve the game experience. This includes levels completed, towers used, and session duration. No personally identifiable information is collected.

2. HOW WE USE INFORMATION
Gameplay data is used solely to improve game balance, fix bugs, and enhance the player experience. We do not sell or share your data with third parties.

3. DATA STORAGE
All game progress is stored locally on your device. Optional cloud save requires explicit opt-in.

4. CHILDREN'S PRIVACY (COPPA)
Shadow Defense does not knowingly collect data from children under 13. If you are under 13, data collection features are automatically disabled.

5. ADVERTISING
We may show optional rewarded video advertisements. You can remove all ads with a one-time purchase. We do not use advertising identifiers without your consent (see App Tracking Transparency on iOS).

6. YOUR RIGHTS (GDPR)
You may request deletion of all data at any time through the in-game Settings menu. You may revoke consent for data collection at any time.

7. APP TRACKING TRANSPARENCY (iOS)
On iOS, we will ask your permission before accessing your device's advertising identifier. You can change this at any time in iOS Settings.

8. CONTACT
For privacy concerns, visit: https://defenseplanet.org/privacy

9. CHANGES
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
		"att_requested": att_requested,
		"att_authorized": att_authorized,
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
		att_requested = bool(json.data.get("att_requested", false))
		att_authorized = bool(json.data.get("att_authorized", false))
