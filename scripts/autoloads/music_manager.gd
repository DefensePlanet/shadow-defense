extends Node
## MusicManager — Centralized soundtrack system for Shadow Defense.
## Handles menu shuffle, per-map background music, skip, now-playing info,
## and volume/mute integration with GameSettings.

signal song_changed(title: String)
signal music_stopped

# All 26 soundtrack tracks (order matches filenames)
const TRACK_FILES: Array = [
	"res://audio/music/01-Parchment_Tongues.wav",
	"res://audio/music/02-Poisoned_Waltz.wav",
	"res://audio/music/03-Coral_Gavel.wav",
	"res://audio/music/04-Clock_Gears.wav",
	"res://audio/music/05-Oracle_Thread.wav",
	"res://audio/music/06-Witch_Forge_Grit.wav",
	"res://audio/music/07-Salt_Compass.wav",
	"res://audio/music/08-Coffin_Waltz.wav",
	"res://audio/music/09-Cathedral_Tongue.wav",
	"res://audio/music/10-Poisoned_Waltz_II.wav",
	"res://audio/music/11-Mushroom_Bellring.wav",
	"res://audio/music/12-Parchment_Tongues_II.wav",
	"res://audio/music/13-Grinning_Musicbox.wav",
	"res://audio/music/14-Glass_Slipper.wav",
	"res://audio/music/15-Grinning_Musicbox_II.wav",
	"res://audio/music/16-Glass_Slipper_II.wav",
	"res://audio/music/17-Glassblood_Sonata.wav",
	"res://audio/music/18-Mushroom_Bellring_II.wav",
	"res://audio/music/19-Brass_Incantation.wav",
	"res://audio/music/20-Crown_Gravel_Elegy.wav",
	"res://audio/music/21-Mercury_Vial.wav",
	"res://audio/music/22-Salt_Compass_II.wav",
	"res://audio/music/23-Cannon_Shell_Confetti.wav",
	"res://audio/music/24-Nightshade_Waltz.wav",
	"res://audio/music/25-Oracle_Thread_II.wav",
	"res://audio/music/26-Brass_Dominion.wav",
]

# Human-readable titles (derived from filenames)
const TRACK_TITLES: Array = [
	"Parchment Tongues",
	"Poisoned Waltz",
	"Coral Gavel",
	"Clock Gears",
	"Oracle Thread",
	"Witch Forge Grit",
	"Salt Compass",
	"Coffin Waltz",
	"Cathedral Tongue",
	"Poisoned Waltz II",
	"Mushroom Bellring",
	"Parchment Tongues II",
	"Grinning Musicbox",
	"Glass Slipper",
	"Grinning Musicbox II",
	"Glass Slipper II",
	"Glassblood Sonata",
	"Mushroom Bellring II",
	"Brass Incantation",
	"Crown Gravel Elegy",
	"Mercury Vial",
	"Salt Compass II",
	"Cannon Shell Confetti",
	"Nightshade Waltz",
	"Oracle Thread II",
	"Brass Dominion",
]

# Map level_idx -> track index (0-25). Brass Dominion (25) reserved for final map (36).
# Remaining 25 tracks distributed across levels 0-35.
const MAP_TRACK_ASSIGNMENTS: Dictionary = {
	# Sherlock + Dracula arc (Victorian Gothic)
	0: 0,   # Parchment Tongues
	1: 1,   # Poisoned Waltz
	2: 2,   # Coral Gavel
	3: 3,   # Clock Gears
	# Merlin + Robin Hood arc (Medieval Folk)
	4: 4,   # Oracle Thread
	5: 5,   # Witch Forge Grit
	6: 6,   # Salt Compass
	# Tarzan + Frankenstein arc (Primal Industrial)
	7: 7,   # Coffin Waltz
	8: 8,   # Cathedral Tongue
	9: 9,   # Poisoned Waltz II
	# Sherlock + Dracula continued
	10: 10,  # Mushroom Bellring
	11: 11,  # Parchment Tongues II
	12: 12,  # Grinning Musicbox
	# Tarzan + Frankenstein continued
	13: 13,  # Glass Slipper
	14: 14,  # Grinning Musicbox II
	15: 15,  # Glass Slipper II
	# Merlin + Robin Hood continued
	16: 16,  # Glassblood Sonata
	17: 17,  # Mushroom Bellring II
	18: 18,  # Brass Incantation
	# Alice + Peter Pan arc (Whimsical)
	19: 19,  # Crown Gravel Elegy
	20: 20,  # Mercury Vial
	21: 21,  # Salt Compass II
	# Grand Finale arc
	22: 22,  # Cannon Shell Confetti
	23: 23,  # Nightshade Waltz
	24: 24,  # Oracle Thread II
	25: 0,   # Parchment Tongues (cycle)
	26: 1,   # Poisoned Waltz (cycle)
	27: 2,   # Coral Gavel (cycle)
	28: 3,   # Clock Gears (cycle)
	29: 4,   # Oracle Thread (cycle)
	30: 5,   # Witch Forge Grit (cycle)
	31: 6,   # Salt Compass (cycle)
	32: 7,   # Coffin Waltz (cycle)
	33: 8,   # Cathedral Tongue (cycle)
	34: 9,   # Poisoned Waltz II (cycle)
	35: 10,  # Mushroom Bellring (cycle)
	36: 25,  # BRASS DOMINION — The Shadow Author's final map
}

# Loaded AudioStream resources
var _tracks: Array = []
var _player: AudioStreamPlayer = null
var _is_playing: bool = false
var _current_track_idx: int = -1
var _menu_playlist: Array = []  # Shuffled indices for menu mode
var _menu_playlist_pos: int = 0
var _is_map_mode: bool = false  # true = map music (half vol), false = menu music
var _map_volume_db: float = -12.0  # 25% volume for maps
var _menu_volume_db: float = 0.0  # Full volume for menu

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Music"
	_player.volume_db = _menu_volume_db
	add_child(_player)
	_player.finished.connect(_on_track_finished)
	_load_tracks()
	_build_menu_playlist()

func _load_tracks() -> void:
	for path in TRACK_FILES:
		if ResourceLoader.exists(path):
			var track = load(path)
			if track:
				_tracks.append(track)
			else:
				_tracks.append(null)
		else:
			_tracks.append(null)

func _build_menu_playlist() -> void:
	_menu_playlist.clear()
	for i in range(_tracks.size()):
		if _tracks[i] != null:
			_menu_playlist.append(i)
	_menu_playlist.shuffle()
	_menu_playlist_pos = 0

## Start shuffled menu music playback
func start_menu_music() -> void:
	_is_map_mode = false
	_player.volume_db = _menu_volume_db
	if _menu_playlist.is_empty():
		_build_menu_playlist()
	_is_playing = true
	_play_track(_menu_playlist[_menu_playlist_pos])

## Start map-specific music at half volume
func start_map_music(level_idx: int) -> void:
	_is_map_mode = true
	_player.volume_db = _map_volume_db
	var track_idx = MAP_TRACK_ASSIGNMENTS.get(level_idx, level_idx % _tracks.size())
	_is_playing = true
	_play_track(track_idx)

## Stop music with optional fade
func stop_music() -> void:
	_is_playing = false
	_current_track_idx = -1
	_player.stop()
	music_stopped.emit()

## Skip to next track (works in both menu and map mode)
func skip_track() -> void:
	if not _is_playing:
		return
	if _is_map_mode:
		# In map mode, pick a random track (not the current one)
		var candidates: Array = []
		for i in range(_tracks.size()):
			if i != _current_track_idx and _tracks[i] != null:
				candidates.append(i)
		if candidates.is_empty():
			return
		candidates.shuffle()
		_play_track(candidates[0])
	else:
		# Menu mode: advance playlist
		_menu_playlist_pos = (_menu_playlist_pos + 1) % _menu_playlist.size()
		if _menu_playlist_pos == 0:
			_menu_playlist.shuffle()
		_play_track(_menu_playlist[_menu_playlist_pos])

## Get the currently playing track title (empty string if nothing playing)
func get_current_title() -> String:
	if _current_track_idx >= 0 and _current_track_idx < TRACK_TITLES.size():
		return TRACK_TITLES[_current_track_idx]
	return ""

## Get current track index
func get_current_track_idx() -> int:
	return _current_track_idx

func _play_track(idx: int) -> void:
	if idx < 0 or idx >= _tracks.size() or _tracks[idx] == null:
		return
	_current_track_idx = idx
	_player.stream = _tracks[idx]
	_player.play()
	song_changed.emit(TRACK_TITLES[idx])

func _on_track_finished() -> void:
	if not _is_playing:
		return
	if _is_map_mode:
		# Replay the same map track (loop)
		if _current_track_idx >= 0 and _tracks[_current_track_idx] != null:
			_player.play()
	else:
		# Menu mode: advance to next in playlist
		_menu_playlist_pos = (_menu_playlist_pos + 1) % _menu_playlist.size()
		if _menu_playlist_pos == 0:
			_menu_playlist.shuffle()
		_play_track(_menu_playlist[_menu_playlist_pos])

## Called when GameSettings volume changes — update player volume
func apply_volume() -> void:
	if _is_map_mode:
		_player.volume_db = _map_volume_db
	else:
		_player.volume_db = _menu_volume_db
