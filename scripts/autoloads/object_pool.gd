extends Node
## ObjectPool — Recycles scene instances to reduce GC pressure on mobile.
## Addresses: #5 (Object pooling)

var _pools: Dictionary = {}  # scene_path -> Array of inactive nodes
var _active: Dictionary = {}  # scene_path -> Array of active nodes
var _scenes: Dictionary = {}  # scene_path -> PackedScene

const DEFAULT_POOL_SIZE := 20
const MAX_POOL_SIZE := 50

func _ready() -> void:
	pass

## Pre-warm a pool with inactive instances
func warm(scene: PackedScene, count: int = DEFAULT_POOL_SIZE) -> void:
	var path = scene.resource_path
	_scenes[path] = scene
	if not _pools.has(path):
		_pools[path] = []
		_active[path] = []
	for i in range(count):
		if _pools[path].size() >= MAX_POOL_SIZE:
			break
		var instance = scene.instantiate()
		instance.set_meta("_pool_path", path)
		instance.visible = false
		instance.process_mode = Node.PROCESS_MODE_DISABLED
		_pools[path].append(instance)

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
	# Only return to pool if under limit
	if _pools[path].size() < MAX_POOL_SIZE:
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
	var stats: Dictionary = {}
	for path in _pools:
		stats[path] = {
			"pooled": _pools[path].size(),
			"active": _active.get(path, []).size()
		}
	return stats

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
