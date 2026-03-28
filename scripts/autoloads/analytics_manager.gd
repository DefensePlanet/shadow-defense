extends Node
## AnalyticsManager — Local analytics + remote hook framework.
## Addresses: #12 (Analytics / crash reporting)
## Enhanced: #35 (Push notifications), #36 (Game Center / Play Games achievements)
##
## Tracks sessions, funnels, retention, and crash data locally.
## Provides HTTP hook for remote analytics services (Firebase, GameAnalytics, etc.)

signal event_logged(event_name: String, params: Dictionary)

const ANALYTICS_PATH := "user://analytics.json"
const MAX_EVENTS := 500  # Keep last 500 events locally

var _events: Array = []
var _session_id: String = ""
var _session_start: float = 0.0
var _remote_endpoint: String = ""  # Set to your analytics endpoint
var _enabled: bool = true
var _batch_queue: Array = []  # Events queued for batch upload
const BATCH_SIZE := 20
const BATCH_INTERVAL := 60.0  # Upload batch every 60 seconds
var _batch_timer: float = 0.0

## Enable or disable analytics collection
func set_enabled(value: bool) -> void:
	_enabled = value

# Session tracking
var total_sessions: int = 0
var total_playtime_seconds: float = 0.0
var first_install_date: String = ""
var last_session_date: String = ""

# Enhancement #36: Achievement definitions
const ACHIEVEMENTS: Dictionary = {
	"first_victory": {"name": "First Victory", "desc": "Complete your first level"},
	"all_stars_act1": {"name": "Perfect Act I", "desc": "Earn 3 stars on all Act I levels"},
	"unlock_all_heroes": {"name": "Full Roster", "desc": "Unlock all 12 heroes"},
	"reach_wave_20": {"name": "Endurance", "desc": "Survive to wave 20"},
	"kill_1000": {"name": "Thousand Shadows", "desc": "Defeat 1000 enemies"},
	"kill_10000": {"name": "Shadow Slayer", "desc": "Defeat 10000 enemies"},
	"max_upgrade": {"name": "Fully Evolved", "desc": "Max upgrade any hero"},
	"no_lives_lost": {"name": "Untouchable", "desc": "Complete a level without losing lives"},
	"speed_run": {"name": "Speed Reader", "desc": "Complete a level in under 3 minutes"},
	"all_towers": {"name": "Full Formation", "desc": "Place all 6 tower types in one level"},
}

# Enhancement #35: Push notification scheduling
var _notifications_enabled: bool = false

func _ready() -> void:
	_session_id = _generate_session_id()
	_session_start = Time.get_ticks_msec() / 1000.0
	_load_analytics()
	total_sessions += 1
	last_session_date = Time.get_date_string_from_system()
	if first_install_date.is_empty():
		first_install_date = last_session_date
	log_event("session_start", {"session_id": _session_id, "platform": OS.get_name()})
	# Enhancement #35: Initialize push notifications
	_init_push_notifications()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		var duration = Time.get_ticks_msec() / 1000.0 - _session_start
		total_playtime_seconds += duration
		log_event("session_end", {"duration_seconds": duration})
		_flush_batch()
		_save_analytics()

func _process(delta: float) -> void:
	# Batch upload timer
	if not _remote_endpoint.is_empty() and _batch_queue.size() > 0:
		_batch_timer += delta
		if _batch_timer >= BATCH_INTERVAL or _batch_queue.size() >= BATCH_SIZE:
			_batch_timer = 0.0
			_flush_batch()

## Track an analytics event (alias for log_event, called by main.gd)
func track_event(event_name: String, params: Dictionary = {}) -> void:
	log_event(event_name, params)

## Log an analytics event
func log_event(event_name: String, params: Dictionary = {}) -> void:
	if not _enabled:
		return
	# Check privacy consent
	if PrivacyManager and not PrivacyManager.data_collection_enabled:
		return
	var event = {
		"event": event_name,
		"timestamp": Time.get_unix_time_from_system(),
		"session": _session_id,
		"params": params
	}
	_events.append(event)
	# Trim old events
	while _events.size() > MAX_EVENTS:
		_events.pop_front()
	event_logged.emit(event_name, params)
	# Queue for batch upload
	if not _remote_endpoint.is_empty():
		_batch_queue.append(event)

## Track level completion funnel
func track_level_complete(level_index: int, waves_survived: int, stars: int, duration_seconds: float) -> void:
	log_event("level_complete", {
		"level": level_index,
		"waves": waves_survived,
		"stars": stars,
		"duration": duration_seconds
	})
	# Enhancement #36: Check for achievements
	_check_achievement("first_victory")
	if stars == 3:
		_check_achievement("no_lives_lost")  # May need more context
	if duration_seconds < 180.0:
		_check_achievement("speed_run")

## Track level failure
func track_level_fail(level_index: int, wave_reached: int, duration_seconds: float) -> void:
	log_event("level_fail", {
		"level": level_index,
		"wave_reached": wave_reached,
		"duration": duration_seconds
	})

## Track tower placement
func track_tower_placed(tower_name: String, level_index: int) -> void:
	log_event("tower_placed", {"tower": tower_name, "level": level_index})

## Track purchase
func track_purchase(item_id: String, currency: String, amount: int) -> void:
	log_event("purchase", {"item": item_id, "currency": currency, "amount": amount})

## Track tutorial step completion
func track_tutorial_step(step: int, step_name: String) -> void:
	log_event("tutorial_step", {"step": step, "name": step_name})

## Track enemy kills (for kill-based achievements)
func track_kills(count: int, total_kills: int) -> void:
	if total_kills >= 1000:
		_check_achievement("kill_1000")
	if total_kills >= 10000:
		_check_achievement("kill_10000")

## Log an error/crash
func log_error(error_msg: String, context: String = "") -> void:
	log_event("error", {"message": error_msg, "context": context})

## Get retention data
func get_retention_days() -> int:
	if first_install_date.is_empty():
		return 0
	var first = Time.get_unix_time_from_datetime_string(first_install_date + "T00:00:00")
	var now = Time.get_unix_time_from_system()
	return int((now - first) / 86400.0)

## Enhancement #36: Check and unlock achievements
func _check_achievement(achievement_id: String) -> void:
	if not ACHIEVEMENTS.has(achievement_id):
		return
	# Report to platform services
	if CloudSaveManager:
		CloudSaveManager.unlock_achievement(achievement_id)
	log_event("achievement_unlocked", {"id": achievement_id, "name": ACHIEVEMENTS[achievement_id]["name"]})

## Enhancement #36: Submit score to leaderboards
func submit_leaderboard_score(board_id: String, score: int) -> void:
	if CloudSaveManager:
		CloudSaveManager.submit_score(board_id, score)
	log_event("leaderboard_submit", {"board": board_id, "score": score})

## Enhancement #35: Initialize push notifications
func _init_push_notifications() -> void:
	if OS.has_feature("ios") or OS.has_feature("android"):
		_notifications_enabled = true

## Enhancement #35: Schedule a local push notification
func schedule_notification(title: String, body: String, delay_seconds: int) -> void:
	if not _notifications_enabled:
		return
	# Use platform-specific notification API
	if OS.has_feature("android") and Engine.has_singleton("GodotNotification"):
		Engine.get_singleton("GodotNotification").schedule(title, body, delay_seconds)
	# iOS uses UNUserNotificationCenter — needs plugin
	log_event("notification_scheduled", {"title": title, "delay": delay_seconds})

## Enhancement #35: Schedule retention notifications
func schedule_retention_notifications() -> void:
	# "Your heroes miss you!" after 24h
	schedule_notification(
		"Shadow Defense",
		"Your heroes miss you! Daily rewards are waiting.",
		86400
	)
	# "New chapter unlocked!" after 48h
	schedule_notification(
		"Shadow Defense",
		"The Shadow Author is growing stronger... return to the pages!",
		172800
	)
	# "Weekly bonus!" after 7 days
	schedule_notification(
		"Shadow Defense",
		"Commander, weekly bonus chest is ready to claim!",
		604800
	)

## Cancel all scheduled notifications
func cancel_all_notifications() -> void:
	if OS.has_feature("android") and Engine.has_singleton("GodotNotification"):
		Engine.get_singleton("GodotNotification").cancelAll()

## Batch upload events to remote endpoint
func _flush_batch() -> void:
	if _batch_queue.is_empty() or _remote_endpoint.is_empty():
		return
	var batch = _batch_queue.duplicate()
	_batch_queue.clear()
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, _c, _h, _b): http.queue_free())
	var headers = ["Content-Type: application/json"]
	var payload = JSON.stringify({"events": batch, "session": _session_id})
	http.request(_remote_endpoint + "/api/events", headers, HTTPClient.METHOD_POST, payload)

func _generate_session_id() -> String:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	return "%08x%08x" % [rng.randi(), Time.get_ticks_msec()]

func _save_analytics() -> void:
	var data = {
		"total_sessions": total_sessions,
		"total_playtime": total_playtime_seconds,
		"first_install": first_install_date,
		"last_session": last_session_date,
		"recent_events": _events.slice(maxi(0, _events.size() - 100))  # Save last 100
	}
	var file = FileAccess.open(ANALYTICS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func _load_analytics() -> void:
	if not FileAccess.file_exists(ANALYTICS_PATH):
		return
	var file = FileAccess.open(ANALYTICS_PATH, FileAccess.READ)
	if not file:
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data = json.data
	if data is Dictionary:
		total_sessions = int(data.get("total_sessions", 0))
		total_playtime_seconds = float(data.get("total_playtime", 0.0))
		first_install_date = str(data.get("first_install", ""))
		last_session_date = str(data.get("last_session", ""))
