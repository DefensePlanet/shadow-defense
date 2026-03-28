extends Node
## AudioCache — Pre-generates and caches procedural audio samples.
## Addresses: #6 (Procedural audio optimization)
## Enhanced: #8 (Memory pressure eviction), #38 (Audio bus routing),
## #39 (Music crossfading), #40 (Quality-based sample rates),
## #41 (Audio ducking during voice), #42 (Silent mode)
##
## Instead of each tower generating 441,000 float samples in _ready(),
## this cache generates them once and shares across all instances of the same tower.

var _cache: Dictionary = {}  # cache_key -> AudioStreamWAV
var _generating: bool = false

# Enhancement #39: Music crossfade system
var _current_music_player: AudioStreamPlayer = null
var _next_music_player: AudioStreamPlayer = null
var _crossfade_timer: float = 0.0
var _crossfade_duration: float = 1.5
var _is_crossfading: bool = false
var _target_music_path: String = ""

# Enhancement #41: Audio ducking state
var _ducking_active: bool = false
var _duck_restore_music: float = 1.0
var _duck_restore_sfx: float = 1.0
var _duck_timer: float = 0.0

func _ready() -> void:
	# Enhancement #38: Ensure audio buses exist
	_ensure_audio_buses()
	# Create music players for crossfading
	_current_music_player = AudioStreamPlayer.new()
	_current_music_player.bus = "Music"
	add_child(_current_music_player)
	_next_music_player = AudioStreamPlayer.new()
	_next_music_player.bus = "Music"
	_next_music_player.volume_db = -80.0
	add_child(_next_music_player)

func _process(delta: float) -> void:
	# Enhancement #39: Handle crossfade
	if _is_crossfading:
		_crossfade_timer += delta
		var t = clampf(_crossfade_timer / _crossfade_duration, 0.0, 1.0)
		_current_music_player.volume_db = linear_to_db(1.0 - t)
		_next_music_player.volume_db = linear_to_db(t)
		if t >= 1.0:
			_is_crossfading = false
			_current_music_player.stop()
			# Swap players
			var tmp = _current_music_player
			_current_music_player = _next_music_player
			_next_music_player = tmp
	# Enhancement #41: Handle duck fade-out
	if _ducking_active and _duck_timer > 0.0:
		_duck_timer -= delta
		if _duck_timer <= 0.0:
			_unduck()

## Enhancement #38: Create audio buses if they don't exist
func _ensure_audio_buses() -> void:
	var bus_names = ["Music", "SFX", "Voice"]
	for bus_name in bus_names:
		if AudioServer.get_bus_index(bus_name) < 0:
			var idx = AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")

## Get or generate a cached audio sample
func get_audio(key: String, generator: Callable) -> AudioStreamWAV:
	if _cache.has(key):
		return _cache[key]
	var audio = generator.call()
	_cache[key] = audio
	return audio

## Pre-generate audio for a tower type during loading
func pregenerate(key: String, generator: Callable) -> void:
	if not _cache.has(key):
		_cache[key] = generator.call()

## Check if a sample is already cached
func has_cached(key: String) -> bool:
	return _cache.has(key)

## Enhancement #40: Helper — Convert samples to WAV with quality-based sample rate
func samples_to_wav(samples: PackedFloat32Array, sample_rate: int = -1) -> AudioStreamWAV:
	# Auto-determine sample rate based on quality level
	if sample_rate < 0:
		var quality = GameSettings.effective_quality if GameSettings else 2
		match quality:
			0: sample_rate = 22050  # Low quality: half sample rate
			1: sample_rate = 32000  # Medium quality
			_: sample_rate = 44100  # High quality: full

	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false

	# Enhancement #40: Downsample if needed for lower quality
	var effective_samples = samples
	if sample_rate < 44100 and samples.size() > 0:
		var ratio = float(sample_rate) / 44100.0
		var new_size = int(float(samples.size()) * ratio)
		effective_samples = PackedFloat32Array()
		effective_samples.resize(new_size)
		for i in range(new_size):
			var src_idx = int(float(i) / ratio)
			src_idx = mini(src_idx, samples.size() - 1)
			effective_samples[i] = samples[src_idx]

	var data = PackedByteArray()
	data.resize(effective_samples.size() * 2)
	for i in effective_samples.size():
		var s = clampf(effective_samples[i], -1.0, 1.0)
		var val = int(s * 32767.0)
		data[i * 2] = val & 0xFF
		data[i * 2 + 1] = (val >> 8) & 0xFF
	wav.data = data
	return wav

## Enhancement #39: Play music with crossfade
func play_music(music_path: String, crossfade: float = 1.5) -> void:
	if music_path == _target_music_path and _current_music_player.playing:
		return  # Already playing this track
	_target_music_path = music_path

	var stream = load(music_path) as AudioStream
	if not stream:
		return

	if not _current_music_player.playing:
		# Nothing playing, just start directly
		_current_music_player.stream = stream
		_current_music_player.volume_db = 0.0
		_current_music_player.play()
		return

	# Crossfade to new track
	_next_music_player.stream = stream
	_next_music_player.volume_db = -80.0
	_next_music_player.play()
	_crossfade_timer = 0.0
	_crossfade_duration = crossfade
	_is_crossfading = true

## Stop music with fade-out
func stop_music(fade_duration: float = 0.5) -> void:
	_target_music_path = ""
	if _is_crossfading:
		_is_crossfading = false
		_next_music_player.stop()
	if _current_music_player.playing:
		var tween = create_tween()
		tween.tween_property(_current_music_player, "volume_db", -80.0, fade_duration)
		tween.tween_callback(_current_music_player.stop)

## Enhancement #41: Duck music and SFX during voice playback
func duck_for_voice(duration: float = 3.0) -> void:
	if not GameSettings or not GameSettings.audio_ducking:
		return
	_ducking_active = true
	_duck_timer = duration
	# Reduce Music to 40% and SFX to 60%
	var music_bus = AudioServer.get_bus_index("Music")
	var sfx_bus = AudioServer.get_bus_index("SFX")
	if music_bus >= 0:
		_duck_restore_music = db_to_linear(AudioServer.get_bus_volume_db(music_bus))
		AudioServer.set_bus_volume_db(music_bus, linear_to_db(_duck_restore_music * 0.4))
	if sfx_bus >= 0:
		_duck_restore_sfx = db_to_linear(AudioServer.get_bus_volume_db(sfx_bus))
		AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(_duck_restore_sfx * 0.6))

func _unduck() -> void:
	_ducking_active = false
	var music_bus = AudioServer.get_bus_index("Music")
	var sfx_bus = AudioServer.get_bus_index("SFX")
	if music_bus >= 0:
		AudioServer.set_bus_volume_db(music_bus, linear_to_db(_duck_restore_music))
	if sfx_bus >= 0:
		AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(_duck_restore_sfx))

## Get memory usage of the cache (approximate bytes)
func get_cache_size_bytes() -> int:
	var total := 0
	for key in _cache:
		var wav = _cache[key]
		if wav and wav is AudioStreamWAV:
			total += wav.data.size()
	return total

## Clear entire cache (call during scene transitions)
func clear() -> void:
	_cache.clear()

## Clear a specific entry
func evict(key: String) -> void:
	_cache.erase(key)
