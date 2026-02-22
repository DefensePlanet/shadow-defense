extends Node2D
## Pistol Tower — auto-targets nearest enemy in range and fires bullets.

var damage: float = 30.0
var fire_rate: float = 1.8   # shots per second
var attack_range: float = 150.0
var fire_cooldown: float = 0.0
var gun_angle: float = 0.0
var target: Node2D = null
var _recoil: float = 0.0

var bullet_scene = preload("res://scenes/bullet.tscn")

func _process(delta: float) -> void:
	fire_cooldown -= delta
	_recoil = max(_recoil - delta * 8.0, 0.0)
	target = _find_nearest_enemy()

	if target:
		var desired = global_position.angle_to_point(target.global_position) + PI
		gun_angle = lerp_angle(gun_angle, desired, 12.0 * delta)
		if fire_cooldown <= 0.0:
			_shoot()
			fire_cooldown = 1.0 / fire_rate
			_recoil = 1.0

	queue_redraw()

func _find_nearest_enemy() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist: float = attack_range
	for enemy in enemies:
		var dist = global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest = enemy
			nearest_dist = dist
	return nearest

func _shoot() -> void:
	if not target:
		return
	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position + Vector2.from_angle(gun_angle) * 20.0
	bullet.damage = damage
	bullet.target = target
	get_tree().get_first_node_in_group("main").add_child(bullet)

func _draw() -> void:
	# Range ring (very subtle)
	draw_arc(Vector2.ZERO, attack_range, 0, TAU, 64, Color(1, 1, 1, 0.06), 1.0)

	# Base platform
	draw_circle(Vector2.ZERO, 24.0, Color(0.3, 0.3, 0.3))
	draw_circle(Vector2.ZERO, 20.0, Color(0.52, 0.52, 0.52))
	draw_circle(Vector2.ZERO, 16.0, Color(0.44, 0.44, 0.44))

	# Gun direction
	var dir = Vector2.from_angle(gun_angle)
	var perp = dir.rotated(PI / 2.0)
	var recoil_offset = dir * (-3.0 * _recoil)

	# Pistol grip (brown)
	var grip_base = recoil_offset + dir * 2.0
	draw_line(grip_base, grip_base - perp * 12.0, Color(0.45, 0.28, 0.12), 6.0)

	# Slide / body
	var slide_start = recoil_offset + dir * 2.0
	var slide_end = recoil_offset + dir * 22.0
	draw_line(slide_start, slide_end, Color(0.22, 0.22, 0.22), 7.0)

	# Barrel
	var barrel_end = recoil_offset + dir * 28.0
	draw_line(slide_end, barrel_end, Color(0.16, 0.16, 0.16), 4.5)

	# Muzzle flash (on recoil)
	if _recoil > 0.5:
		draw_circle(barrel_end + dir * 4.0, 5.0, Color(1.0, 0.9, 0.3, _recoil * 0.8))
