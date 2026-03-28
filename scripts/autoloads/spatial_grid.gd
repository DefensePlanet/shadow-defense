extends Node
## SpatialGrid — Grid-based spatial partitioning for efficient tower targeting.
## Addresses: #8 (Spatial partitioning)
## Enhanced: #5 (Dirty-flag optimization — only re-register moved entities)
##
## Replaces O(towers * enemies) per-frame iteration with O(towers * nearby_enemies).
## Enemies register their cell, towers only check nearby cells within range.

const CELL_SIZE := 64.0
const MOVE_THRESHOLD_SQ := 1024.0  # (CELL_SIZE/2)^2 — skip re-register if moved less than half a cell

var _grid: Dictionary = {}  # Vector2i -> Array[Node2D]
var _entity_cells: Dictionary = {}  # node_id -> Vector2i
var _entity_positions: Dictionary = {}  # Enhancement #5: node_id -> last_registered Vector2

# Performance counters
var _register_calls: int = 0
var _skipped_calls: int = 0

func _ready() -> void:
	pass

## Convert world position to grid cell
func _pos_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(int(pos.x / CELL_SIZE), int(pos.y / CELL_SIZE))

## Register an entity in the grid
func register(entity: Node2D) -> void:
	_register_calls += 1
	var id = entity.get_instance_id()
	var pos = entity.global_position

	# Enhancement #5: Skip re-registration if entity hasn't moved much
	if _entity_positions.has(id):
		var last_pos: Vector2 = _entity_positions[id]
		if pos.distance_squared_to(last_pos) < MOVE_THRESHOLD_SQ:
			_skipped_calls += 1
			return

	var cell = _pos_to_cell(pos)
	# Remove from old cell if moved
	if _entity_cells.has(id):
		var old_cell = _entity_cells[id]
		if old_cell == cell:
			_entity_positions[id] = pos
			_skipped_calls += 1
			return  # Same cell, no change
		if _grid.has(old_cell):
			_grid[old_cell].erase(entity)
			if _grid[old_cell].is_empty():
				_grid.erase(old_cell)
	# Add to new cell
	_entity_cells[id] = cell
	_entity_positions[id] = pos
	if not _grid.has(cell):
		_grid[cell] = []
	_grid[cell].append(entity)

## Remove entity from grid
func unregister(entity: Node2D) -> void:
	var id = entity.get_instance_id()
	if _entity_cells.has(id):
		var cell = _entity_cells[id]
		if _grid.has(cell):
			_grid[cell].erase(entity)
			if _grid[cell].is_empty():
				_grid.erase(cell)
		_entity_cells.erase(id)
		_entity_positions.erase(id)

## Find all entities within range of a position
func query_radius(pos: Vector2, radius: float) -> Array:
	var results: Array = []
	var cell_radius = ceili(radius / CELL_SIZE)
	var center_cell = _pos_to_cell(pos)
	var radius_sq = radius * radius
	for dx in range(-cell_radius, cell_radius + 1):
		for dy in range(-cell_radius, cell_radius + 1):
			var check_cell = Vector2i(center_cell.x + dx, center_cell.y + dy)
			if _grid.has(check_cell):
				for entity in _grid[check_cell]:
					if is_instance_valid(entity) and entity.global_position.distance_squared_to(pos) <= radius_sq:
						results.append(entity)
	return results

## Find nearest entity within range
func find_nearest(pos: Vector2, radius: float) -> Node2D:
	var nearest: Node2D = null
	var nearest_dist_sq: float = radius * radius
	var cell_radius = ceili(radius / CELL_SIZE)
	var center_cell = _pos_to_cell(pos)
	for dx in range(-cell_radius, cell_radius + 1):
		for dy in range(-cell_radius, cell_radius + 1):
			var check_cell = Vector2i(center_cell.x + dx, center_cell.y + dy)
			if _grid.has(check_cell):
				for entity in _grid[check_cell]:
					if is_instance_valid(entity):
						var d = entity.global_position.distance_squared_to(pos)
						if d < nearest_dist_sq:
							nearest_dist_sq = d
							nearest = entity
	return nearest

## Find first entity along path within range (for "First" targeting)
func find_first_on_path(pos: Vector2, radius: float) -> Node2D:
	var candidates = query_radius(pos, radius)
	var best: Node2D = null
	var best_progress: float = -1.0
	for entity in candidates:
		if entity.has_method("get_path_progress"):
			var progress = entity.get_path_progress()
			if progress > best_progress:
				best_progress = progress
				best = entity
		elif entity.has_meta("path_progress"):
			var progress = entity.get_meta("path_progress")
			if progress > best_progress:
				best_progress = progress
				best = entity
	return best

## Enhancement #5: Optimized update — only re-register entities that moved significantly
func update_all() -> void:
	var stale_ids: Array = []
	for id in _entity_cells.keys():
		var entity = instance_from_id(id)
		if entity and is_instance_valid(entity) and entity is Node2D:
			register(entity)  # Will skip if entity hasn't moved enough
		else:
			stale_ids.append(id)
	# Clean up freed entities
	for id in stale_ids:
		var old_cell = _entity_cells[id]
		if _grid.has(old_cell):
			_grid[old_cell] = _grid[old_cell].filter(func(e): return is_instance_valid(e))
			if _grid[old_cell].is_empty():
				_grid.erase(old_cell)
		_entity_cells.erase(id)
		_entity_positions.erase(id)

## Clear entire grid (call on level transition)
func clear() -> void:
	_grid.clear()
	_entity_cells.clear()
	_entity_positions.clear()
	_register_calls = 0
	_skipped_calls = 0

## Get debug stats
func get_stats() -> Dictionary:
	var total_entities := 0
	for cell in _grid:
		total_entities += _grid[cell].size()
	var skip_rate = 0.0
	if _register_calls > 0:
		skip_rate = float(_skipped_calls) / float(_register_calls)
	return {
		"cells": _grid.size(),
		"entities": total_entities,
		"tracked": _entity_cells.size(),
		"register_calls": _register_calls,
		"skipped_calls": _skipped_calls,
		"skip_rate": skip_rate
	}
