extends Node
## ObjectPool — Recycles scene instances to reduce GC pressure on mobile.
## Addresses: #5 (Object pooling)
## Enhanced: #6 (Pre-warm during loading), #8 (Memory pressure handling),
## #9 (Lazy-load hero scenes)

var _pools: Dictionary = {}  # scene_path -> Array of inactive nodes
var _active: Dictionary = {}  # scene_path -> Array of active nodes
var _scenes: Dictionary = {}  # scene_path -> PackedScene

const DEFAULT_POOL_SIZE := 20
const MAX_POOL_SIZE := 50
const LOW_MEMORY_POOL_SIZE := 10  # Enhancement #8: Reduced pool when memory constrained

var _memory_constrained: bool = false
var _total_spawns: int = 0
var _total_despawns: int = 0

func _ready() -> void:
	pass

func _notification(what: int) -> void:
	# Enhancement #8: Handle memory pressure (mobile-only notification)
	if what == MainLoop.NOTIFICATION_OS_MEMORY_WARNING:
		_on_memory_warning()

## Enhancement #8: Respond to low memory
func _on_memory_warning() -> void:
	_memory_constrained = true
	# Aggressively trim all pools to LOW_MEMORY_POOL_SIZE
	for path in _pools:
		while _pools[path].size() > LOW_MEMORY_POOL_SIZE:
			var node = _pools[path].pop_back()
			if is_instance_valid(node):
				node.queue_free()
	# Clear audio cache if available
	if AudioCache:
		AudioCache.clear()
	push_warning("ObjectPool: Memory warning — trimmed pools to %d" % LOW_MEMORY_POOL_SIZE)

## Pre-warm a pool with inactive instances
func warm(scene: PackedScene, count: int = DEFAULT_POOL_SIZE) -> void:
	var path = scene.resource_path
	_scenes[path] = scene
	if not _pools.has(path):
		_pools[path] = []
		_active[path] = []
	var max_size = LOW_MEMORY_POOL_SIZE if _memory_constrained else MAX_POOL_SIZE
	for i in range(count):
		if _pools[path].size() >= max_size:
			break
		var instance = scene.instantiate()
		instance.set_meta("_pool_path", path)
		instance.visible = false
		instance.process_mode = Node.PROCESS_MODE_DISABLED
		_pools[path].append(instance)

## Enhancement #6: Pre-warm all pools needed for a level during loading screen
func warm_for_level(enemy_scene: PackedScene, tower_scenes: Array, projectile_scenes: Array) -> void:
	# Enemies — most important, spawn in batches
	var enemy_count = 30 if not _memory_constrained else 15
	warm(enemy_scene, enemy_count)
	# Projectiles — medium count per type
	for proj_scene in projectile_scenes:
		if proj_scene is PackedScene:
			warm(proj_scene, 10 if not _memory_constrained else 5)
	# Loading progress updates
	if LoadingManager:
		LoadingManager.set_progress(0.5)

## Enhancement #9: Load a hero scene async (for lazy-loading after unlock)
func load_scene_async(path: String) -> PackedScene:
	if _scenes.has(path):
		return _scenes[path]
	if LoadingManager:
		var res = await LoadingManager.load_resource_async(path)
		if res is PackedScene:
			_scenes[path] = res
			return res
	# Fallback: synchronous load
	var scene = load(path) as PackedScene
	if scene:
		_scenes[path] = scene
	return scene

## Get an instance from the pool (or create new if empty)
func spawn(scene: PackedScene, parent: Node = null) -> Node:
	var path = scene.resource_path
	if not _scenes.has(path):
		_scenes[path] = scene
	if not _pools.has(path):
		_pools[path] = []
		_active[path] = []
	var instance: Node
	if _pools[path].size() > 0:
		instance = _pools[path].pop_back()
	else:
		instance = scene.instantiate()
		instance.set_meta("_pool_path", path)
	instance.visible = true
	instance.process_mode = Node.PROCESS_MODE_INHERIT
	if parent:
		parent.add_child(instance)
	_active[path].append(instance)
	_total_spawns += 1
	# Call custom reset if the node has one
	if instance.has_method("pool_reset"):
		instance.pool_reset()
	return instance

## Return an instance to the pool
func despawn(instance: Node) -> void:
	if not instance or not is_instance_valid(instance):
		return
	var path = instance.get_meta("_pool_path", "")
	if path.is_empty():
		# Not a pooled object, just free it
		instance.queue_free()
		return
	if not _pools.has(path):
		_pools[path] = []
	if not _active.has(path):
		_active[path] = []
	_active[path].erase(instance)
	_total_despawns += 1
	# Only return to pool if under limit
	var max_size = LOW_MEMORY_POOL_SIZE if _memory_constrained else MAX_POOL_SIZE
	if _pools[path].size() < max_size:
		instance.visible = false
		instance.process_mode = Node.PROCESS_MODE_DISABLED
		if instance.get_parent():
			instance.get_parent().remove_child(instance)
		# Call custom cleanup if available
		if instance.has_method("pool_cleanup"):
			instance.pool_cleanup()
		_pools[path].append(instance)
	else:
		instance.queue_free()

## Get pool statistics
func get_stats() -> Dictionary:
	var stats: Dictionary = {
		"total_spawns": _total_spawns,
		"total_despawns": _total_despawns,
		"memory_constrained": _memory_constrained,
		"pools": {}
	}
	for path in _pools:
		stats["pools"][path] = {
			"pooled": _pools[path].size(),
			"active": _active.get(path, []).size()
		}
	return stats

## Get total active instance count (for performance monitoring)
func get_active_count() -> int:
	var total := 0
	for path in _active:
		total += _active[path].size()
	return total

## Clear all pools
func clear_all() -> void:
	for path in _pools:
		for node in _pools[path]:
			if is_instance_valid(node):
				node.queue_free()
	for path in _active:
		for node in _active[path]:
			if is_instance_valid(node):
				node.queue_free()
	_pools.clear()
	_active.clear()
	_memory_constrained = false
