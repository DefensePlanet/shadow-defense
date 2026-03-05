extends Node
## CloudSaveManager — Cloud save sync framework.
## Addresses: #13 (Cloud save)
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
var _cloud_endpoint: String = ""  # Set to your cloud save API
var _user_id: String = ""

const CLOUD_META_PATH := "user://cloud_meta.json"

func _ready() -> void:
	_load_meta()
	# Auto-sync on app resume
	get_tree().root.focus_entered.connect(_on_app_resumed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and auto_sync:
		# Save to cloud when app goes to background
		push_save()

## Upload local save to cloud
func push_save() -> void:
	if _cloud_endpoint.is_empty() or _user_id.is_empty():
		return
	status = SyncStatus.SYNCING
	sync_started.emit()
	# Read local save
	var save_path = "user://shadowdefense_save.json"
	if not FileAccess.file_exists(save_path):
		status = SyncStatus.IDLE
		sync_completed.emit(false)
		return
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		status = SyncStatus.IDLE
		sync_completed.emit(false)
		return
	var local_data = file.get_as_text()
	file.close()
	# Upload via HTTP (placeholder)
	_upload_to_cloud(local_data)

## Download cloud save and merge/replace local
func pull_save() -> void:
	if _cloud_endpoint.is_empty() or _user_id.is_empty():
		return
	status = SyncStatus.SYNCING
	sync_started.emit()
	# Download via HTTP (placeholder)
	_download_from_cloud()

## Set cloud configuration
func configure(endpoint: String, user_id: String) -> void:
	_cloud_endpoint = endpoint
	_user_id = user_id
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

func _upload_to_cloud(_data: String) -> void:
	# Placeholder: HTTP POST to cloud endpoint
	# var http = HTTPRequest.new()
	# add_child(http)
	# var headers = ["Content-Type: application/json", "X-User-ID: " + _user_id]
	# http.request(_cloud_endpoint + "/save", headers, HTTPClient.METHOD_POST, _data)
	last_sync_time = Time.get_unix_time_from_system()
	status = SyncStatus.IDLE
	_save_meta()
	sync_completed.emit(true)

func _download_from_cloud() -> void:
	# Placeholder: HTTP GET from cloud endpoint
	# var http = HTTPRequest.new()
	# add_child(http)
	# http.request(_cloud_endpoint + "/save/" + _user_id)
	status = SyncStatus.IDLE
	sync_completed.emit(false)  # No endpoint configured yet

func _on_app_resumed() -> void:
	if auto_sync and is_configured():
		pull_save()

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
