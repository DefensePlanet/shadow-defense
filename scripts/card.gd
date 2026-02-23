extends Node2D
## Playing Card — fast projectile that slows enemies on hit. Can execute low-HP enemies.

var speed: float = 400.0
var damage: float = 12.0
var target: Node2D = null
var gold_bonus: int = 0
var source_tower: Node2D = null
var slow_amount: float = 0.7
var slow_duration: float = 1.5
var execute_threshold: float = 0.0
var _lifetime: float = 3.0
var _angle: float = 0.0
var _spin: float = 0.0

# Progressive ability support (set by Alice)
var bounce_count: int = 0
var split_count: int = 0
var _hit_targets: Array = []
var apply_paint: bool = false

func _process(delta: float) -> void:
	_lifetime -= delta
	_spin += delta * 12.0
	if _lifetime <= 0.0:
		queue_free()
		return

	if not is_instance_valid(target):
		queue_free()
		return

	var dir = global_position.direction_to(target.global_position)
	_angle = dir.angle()
	position += dir * speed * delta

	if global_position.distance_to(target.global_position) < 12.0:
		_hit_target(target)

	queue_redraw()

func _hit_target(t: Node2D) -> void:
	if not t.has_method("take_damage"):
		queue_free()
		return
	_hit_targets.append(t)

	# Execute check (Off With Their Heads!)
	if execute_threshold > 0.0 and t.health / t.max_health <= execute_threshold:
		var exec_dmg = t.health
		t.health = 0.0
		t.take_damage(0.0, true)
		if is_instance_valid(source_tower) and source_tower.has_method("register_damage"):
			source_tower.register_damage(exec_dmg)
		if gold_bonus > 0:
			var main = get_tree().get_first_node_in_group("main")
			if main:
				main.add_gold(gold_bonus)
		queue_free()
		return

	var will_kill = t.health - damage <= 0.0
	t.take_damage(damage, true)
	if is_instance_valid(source_tower) and source_tower.has_method("register_damage"):
		source_tower.register_damage(damage)

	# Apply slow (Drink Me)
	if is_instance_valid(t) and t.has_method("apply_slow"):
		t.apply_slow(slow_amount, slow_duration)

	# Apply paint stacks (Painting the Roses Red)
	if apply_paint and is_instance_valid(t) and t.has_method("apply_paint"):
		t.apply_paint()

	if will_kill:
		if gold_bonus > 0:
			var main = get_tree().get_first_node_in_group("main")
			if main:
				main.add_gold(gold_bonus)

	# Split mid-flight (Wonderland Madness — 1 becomes 3)
	if split_count > 0:
		split_count = 0
		_spawn_splits()

	# Bounce to next target
	if bounce_count > 0:
		bounce_count -= 1
		var next = _find_bounce_target()
		if next:
			target = next
			return
	queue_free()

func _find_bounce_target() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist: float = 150.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy in _hit_targets:
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest = enemy
			nearest_dist = dist
	return nearest

func _spawn_splits() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var available: Array = []
	for e in enemies:
		if e not in _hit_targets and e != target:
			available.append(e)
	available.shuffle()
	var main_node = get_tree().get_first_node_in_group("main")
	if not main_node:
		return
	var count = mini(2, available.size())
	for i in range(count):
		if is_instance_valid(source_tower) and source_tower.has_method("_fire_split_card"):
			source_tower._fire_split_card(available[i], _hit_targets.duplicate(), apply_paint)

func _draw() -> void:
	# Spinning playing card
	var spin_scale = abs(cos(_spin))
	var dir = Vector2.from_angle(_angle)
	var perp = dir.rotated(PI / 2.0)

	# Card body (white rectangle, squished by spin)
	var hw = 3.0 * spin_scale + 1.0
	var hh = 5.0
	var card_pts = PackedVector2Array([
		-perp * hw - dir * hh,
		perp * hw - dir * hh,
		perp * hw + dir * hh,
		-perp * hw + dir * hh,
	])
	draw_colored_polygon(card_pts, Color(0.95, 0.93, 0.88))

	# Red heart/diamond on card face
	if spin_scale > 0.3:
		draw_circle(dir * 1.0, 2.0, Color(0.85, 0.15, 0.15))

	# Card edge
	for i in range(4):
		draw_line(card_pts[i], card_pts[(i + 1) % 4], Color(0.3, 0.3, 0.3, 0.5), 0.8)
