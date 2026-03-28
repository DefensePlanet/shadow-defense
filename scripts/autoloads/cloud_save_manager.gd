extends Node
## CloudSaveManager — Cloud save sync framework.
## Addresses: #13 (Cloud save)
## Enhanced: #48 (Actual cloud save backend via Firebase/Supabase),
## #10 (Background/foreground lifecycle), #36 (Game Center/Play Games)
##
## Provides local-first saving with cloud backup when available.
## Supports conflict resolution (latest-wins or manual merge).

signal sync_started
signal sync_completed(success: bool)
signal sync_conflict(local_data: Dictionary, cloud_data: Dictionary)

enum SyncStatus { IDLE, SYNCING, CONFLICT, ERROR }

var status: SyncStatus = SyncStatus.IDLE
var last_sync_time: float = 0.0
var auto_sync: bool = true
var _cloud_endpoint: String = ""
var _user_id: String = ""
var _auth_token: String = ""

const CLOUD_META_PATH := "user://cloud_meta.json"
const SAVE_PATH := "user://shadowdefense_save.json"
const BACKUP_INTERVAL := 300.0  # Auto-backup every 5 minutes
var _backup_timer: float = 0.0

# Enhancement #10: App lifecycle state
var _is_backgrounded: bool = false
var _background_time: float = 0.0
var _game_paused_by_background: bool = false

# Enhancement #36: Platform services
var _game_center_available: bool = false
var _play_games_available: bool = false

func _ready() -> void:
	_load_meta()
	_init_platform_services()
	# Enhancement #10: Connect lifecycle signals
	get_tree().root.focus_entered.connect(_on_app_resumed)
	get_tree().root.focus_exited.connect(_on_app_backgrounded)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_on_app_backgrounded()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_on_app_resumed()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			# Android back button — save before potential exit
			push_save()

func _process(delta: float) -> void:
	# Auto-backup timer
	if auto_sync and is_configured() and not _is_backgrounded:
		_backup_timer += delta
		if _backup_timer >= BACKUP_INTERVAL:
			_backup_timer = 0.0
			push_save()

## Enhancement #10: Handle app going to background
func _on_app_backgrounded() -> void:
	if _is_backgrounded:
		return
	_is_backgrounded = true
	_background_time = Time.get_unix_time_from_system()
	# Save state immediately
	push_save()
	# Pause game if playing
	if get_tree() and not get_tree().paused:
		get_tree().paused = true
		_game_paused_by_background = true
	# Release audio resources
	AudioServer.set_bus_mute(0, true)

## Enhancement #10: Handle app resuming from background
func _on_app_resumed() -> void:
	if not _is_backgrounded:
		return
	_is_backgrounded = false
	# Restore audio
	AudioServer.set_bus_mute(0, false)
	# Pull latest cloud save in case another device played
	if auto_sync and is_configured():
		pull_save()
	# Don't auto-unpause — let the game show a "Welcome back" overlay
	# The main game script should check _game_paused_by_background

## Check if game was paused by backgrounding (main.gd reads this)
func was_paused_by_background() -> bool:
	if _game_paused_by_background:
		_game_paused_by_background = false
		return true
	return false

## Get seconds spent in background
func get_background_duration() -> float:
	if _is_backgrounded:
		return Time.get_unix_time_from_system() - _background_time
	return 0.0

## Enhancement #36: Initialize platform game services
func _init_platform_services() -> void:
	# Game Center (iOS)
	if OS.has_feature("ios") and Engine.has_singleton("GameCenter"):
		_game_center_available = true
		var gc = Engine.get_singleton("GameCenter")
		gc.authenticate()
	# Google Play Games (Android)
	if OS.has_feature("android") and Engine.has_singleton("GodotPlayGamesServices"):
		_play_games_available = true
		var pg = Engine.get_singleton("GodotPlayGamesServices")
		pg.signIn()

## Enhancement #36: Submit score to leaderboard
func submit_score(leaderboard_id: String, score: int) -> void:
	if _game_center_available and Engine.has_singleton("GameCenter"):
		Engine.get_singleton("GameCenter").post_score({"score": score, "category": leaderboard_id})
	elif _play_games_available and Engine.has_singleton("GodotPlayGamesServices"):
		Engine.get_singleton("GodotPlayGamesServices").submitLeaderBoardScore(leaderboard_id, score)

## Enhancement #36: Unlock achievement
func unlock_achievement(achievement_id: String) -> void:
	if _game_center_available and Engine.has_singleton("GameCenter"):
		Engine.get_singleton("GameCenter").award_achievement({"name": achievement_id, "progress": 100.0})
	elif _play_games_available and Engine.has_singleton("GodotPlayGamesServices"):
		Engine.get_singleton("GodotPlayGamesServices").unlockAchievement(achievement_id)

## Enhancement #36: Show platform leaderboard UI
func show_leaderboard(leaderboard_id: String = "") -> void:
	if _game_center_available and Engine.has_singleton("GameCenter"):
		Engine.get_singleton("GameCenter").show_game_center({"view": "leaderboards"})
	elif _play_games_available and Engine.has_singleton("GodotPlayGamesServices"):
		if leaderboard_id.is_empty():
			Engine.get_singleton("GodotPlayGamesServices").showAllLeaderBoards()
		else:
			Engine.get_singleton("GodotPlayGamesServices").showLeaderBoard(leaderboard_id)

## Enhancement #36: Show platform achievements UI
func show_achievements() -> void:
	if _game_center_available and Engine.has_singleton("GameCenter"):
		Engine.get_singleton("GameCenter").show_game_center({"view": "achievements"})
	elif _play_games_available and Engine.has_singleton("GodotPlayGamesServices"):
		Engine.get_singleton("GodotPlayGamesServices").showAchievements()

## Immediate save (called by _victory in main.gd)
func save_now() -> void:
	push_save()

## Upload local save to cloud
func push_save() -> void:
	if _cloud_endpoint.is_empty():
		return
	status = SyncStatus.SYNCING
	sync_started.emit()
	if not FileAccess.file_exists(SAVE_PATH):
		status = SyncStatus.IDLE
		sync_completed.emit(false)
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		status = SyncStatus.IDLE
		sync_completed.emit(false)
		return
	var local_data = file.get_as_text()
	file.close()
	# Enhancement #48: Upload via HTTP
	_upload_to_cloud(local_data)

## Download cloud save and merge/replace local
func pull_save() -> void:
	if _cloud_endpoint.is_empty():
		return
	status = SyncStatus.SYNCING
	sync_started.emit()
	_download_from_cloud()

## Set cloud configuration
func configure(endpoint: String, user_id: String, auth_token: String = "") -> void:
	_cloud_endpoint = endpoint
	_user_id = user_id
	_auth_token = auth_token
	_save_meta()

## Check if cloud save is configured
func is_configured() -> bool:
	return not _cloud_endpoint.is_empty() and not _user_id.is_empty()

## Resolve sync conflict — keep local
func resolve_keep_local() -> void:
	status = SyncStatus.IDLE
	push_save()

## Resolve sync conflict — keep cloud
func resolve_keep_cloud() -> void:
	status = SyncStatus.IDLE
	pull_save()

## Enhancement #48: Actual HTTP upload to cloud backend
func _upload_to_cloud(data: String) -> void:
	if _cloud_endpoint.is_empty():
		status = SyncStatus.IDLE
		sync_completed.emit(false)
		return
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_upload_completed.bind(http))
	var headers = [
		"Content-Type: application/json",
		"X-User-ID: " + _user_id,
	]
	if not _auth_token.is_empty():
		headers.append("Authorization: Bearer " + _auth_token)
	var payload = JSON.stringify({"user_id": _user_id, "save_data": data, "timestamp": Time.get_unix_time_from_system()})
	var err = http.request(_cloud_endpoint + "/api/save", headers, HTTPClient.METHOD_POST, payload)
	if err != OK:
		http.queue_free()
		status = SyncStatus.ERROR
		sync_completed.emit(false)

func _on_upload_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		last_sync_time = Time.get_unix_time_from_system()
		status = SyncStatus.IDLE
		_save_meta()
		sync_completed.emit(true)
	else:
		status = SyncStatus.ERROR
		sync_completed.emit(false)

## Enhancement #48: Actual HTTP download from cloud backend
func _download_from_cloud() -> void:
	if _cloud_endpoint.is_empty():
		status = SyncStatus.IDLE
		sync_completed.emit(false)
		return
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_download_completed.bind(http))
	var headers = ["X-User-ID: " + _user_id]
	if not _auth_token.is_empty():
		headers.append("Authorization: Bearer " + _auth_token)
	var err = http.request(_cloud_endpoint + "/api/save/" + _user_id, headers)
	if err != OK:
		http.queue_free()
		status = SyncStatus.ERROR
		sync_completed.emit(false)

func _on_download_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var json = JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK and json.data is Dictionary:
			var cloud_save = json.data.get("save_data", "")
			var cloud_timestamp = float(json.data.get("timestamp", 0))
			# Check for conflict
			if FileAccess.file_exists(SAVE_PATH):
				var local_file = FileAccess.open(SAVE_PATH, FileAccess.READ)
				if local_file:
					var local_data = local_file.get_as_text()
					local_file.close()
					if cloud_timestamp > last_sync_time and local_data != cloud_save:
						# Conflict — let user decide
						status = SyncStatus.CONFLICT
						sync_conflict.emit(
							{"data": local_data, "time": last_sync_time},
							{"data": cloud_save, "time": cloud_timestamp}
						)
						return
			# No conflict — apply cloud save
			if not cloud_save.is_empty():
				var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
				if file:
					file.store_string(cloud_save)
					file.close()
			last_sync_time = Time.get_unix_time_from_system()
			status = SyncStatus.IDLE
			_save_meta()
			sync_completed.emit(true)
		else:
			status = SyncStatus.ERROR
			sync_completed.emit(false)
	elif response_code == 404:
		# No cloud save exists yet — that's OK
		status = SyncStatus.IDLE
		sync_completed.emit(true)
	else:
		status = SyncStatus.ERROR
		sync_completed.emit(false)

func _save_meta() -> void:
	var data = {
		"endpoint": _cloud_endpoint,
		"user_id": _user_id,
		"last_sync": last_sync_time,
		"auto_sync": auto_sync,
	}
	var file = FileAccess.open(CLOUD_META_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func _load_meta() -> void:
	if not FileAccess.file_exists(CLOUD_META_PATH):
		return
	var file = FileAccess.open(CLOUD_META_PATH, FileAccess.READ)
	if not file:
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_cloud_endpoint = str(json.data.get("endpoint", ""))
		_user_id = str(json.data.get("user_id", ""))
		last_sync_time = float(json.data.get("last_sync", 0.0))
		auto_sync = bool(json.data.get("auto_sync", true))
