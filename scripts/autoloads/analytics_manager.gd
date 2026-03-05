extends Node
## AnalyticsManager — Local analytics + remote hook framework.
## Addresses: #12 (Analytics / crash reporting)
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

# Session tracking
var total_sessions: int = 0
var total_playtime_seconds: float = 0.0
var first_install_date: String = ""
var last_session_date: String = ""

func _ready() -> void:
	_session_id = _generate_session_id()
	_session_start = Time.get_ticks_msec() / 1000.0
	_load_analytics()
	total_sessions += 1
	last_session_date = Time.get_date_string_from_system()
	if first_install_date.is_empty():
		first_install_date = last_session_date
	log_event("session_start", {"session_id": _session_id, "platform": OS.get_name()})

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		var duration = Time.get_ticks_msec() / 1000.0 - _session_start
		total_playtime_seconds += duration
		log_event("session_end", {"duration_seconds": duration})
		_save_analytics()

## Log an analytics event
func log_event(event_name: String, params: Dictionary = {}) -> void:
	if not _enabled:
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
	# Send to remote if configured
	if not _remote_endpoint.is_empty():
		_send_remote(event)

## Track level completion funnel
func track_level_complete(level_index: int, waves_survived: int, stars: int, duration_seconds: float) -> void:
	log_event("level_complete", {
		"level": level_index,
		"waves": waves_survived,
		"stars": stars,
		"duration": duration_seconds
	})

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

func _generate_session_id() -> String:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	return "%08x%08x" % [rng.randi(), Time.get_ticks_msec()]

func _send_remote(_event: Dictionary) -> void:
	# Placeholder: implement HTTP POST to analytics endpoint
	# var http = HTTPRequest.new()
	# add_child(http)
	# http.request(_remote_endpoint, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(_event))
	pass

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
