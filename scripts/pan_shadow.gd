extends Node2D
## Pan's Shadow — dark translucent figure that roams the map attacking enemies.

var source_tower: Node2D = null
var _time: float = 0.0
var _attack_timer: float = 1.0
var target: Node2D = null
var speed: float = 200.0

func _process(delta: float) -> void:
	_time += delta
	_attack_timer -= delta

	# Find nearest enemy across entire map
	if not is_instance_valid(target):
		target = _find_nearest_enemy()

	if is_instance_valid(target):
		var dir = global_position.direction_to(target.global_position)
		global_position += dir * speed * delta

		if global_position.distance_to(target.global_position) < 20.0 and _attack_timer <= 0.0:
			if target.has_method("take_damage") and is_instance_valid(source_tower):
				var dmg = source_tower.damage * 2.0
				target.take_damage(dmg)
				if source_tower.has_method("register_damage"):
					source_tower.register_damage(dmg)
				_attack_timer = 1.0
				target = _find_nearest_enemy()  # Find new target

	queue_redraw()

func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist: float = 999999.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_method("is_targetable") and not enemy.is_targetable():
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest = enemy
			nearest_dist = dist
	return nearest

func _draw() -> void:
	var shadow_alpha = 0.35 + sin(_time * 3.0) * 0.1
	var sc = Color(0.04, 0.04, 0.08, shadow_alpha)
	var sc_light = Color(0.04, 0.04, 0.08, shadow_alpha * 0.6)
	# Shadow head
	draw_circle(Vector2(0, -18), 6.0, sc)
	# Shadow body
	var body = PackedVector2Array([
		Vector2(-7, -12), Vector2(7, -12),
		Vector2(8, 4), Vector2(-8, 4),
	])
	draw_colored_polygon(body, sc)
	# Shadow legs
	draw_line(Vector2(-4, 4), Vector2(-5, 14), sc, 2.0)
	draw_line(Vector2(4, 4), Vector2(5, 14), sc, 2.0)
	# Shadow arms (wispy)
	var wave = sin(_time * 4.0) * 3.0
	draw_line(Vector2(-7, -8), Vector2(-16 - wave, -4), sc_light, 2.0)
	draw_line(Vector2(7, -8), Vector2(16 + wave, -4), sc_light, 2.0)
	# Wispy trail particles
	for i in range(5):
		var trail_pos = Vector2(sin(_time * 2.0 + float(i)) * 4.0, 4.0 + float(i) * 5.0)
		draw_circle(trail_pos, 3.0 - float(i) * 0.4, Color(0.04, 0.04, 0.08, shadow_alpha * 0.3 * (1.0 - float(i) * 0.15)))
