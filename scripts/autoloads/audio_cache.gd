extends Node
## AudioCache — Pre-generates and caches procedural audio samples.
## Addresses: #6 (Procedural audio optimization)
##
## Instead of each tower generating 441,000 float samples in _ready(),
## this cache generates them once and shares across all instances of the same tower.

var _cache: Dictionary = {}  # cache_key -> AudioStreamWAV
var _generating: bool = false

func _ready() -> void:
	pass

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

## Helper: Convert PackedFloat32Array samples to AudioStreamWAV
func samples_to_wav(samples: PackedFloat32Array, sample_rate: int = 44100) -> AudioStreamWAV:
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	var data = PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var s = clampf(samples[i], -1.0, 1.0)
		var val = int(s * 32767.0)
		data[i * 2] = val & 0xFF
		data[i * 2 + 1] = (val >> 8) & 0xFF
	wav.data = data
	return wav

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
