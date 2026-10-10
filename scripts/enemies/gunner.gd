# Schütze: hält Abstand, zielt sichtbar und feuert kurze Salven.
extends "res://scripts/enemies/enemy.gd"

var state := "idle"
var state_t := 0.0
var shots_left := 0
var target_pos := Vector2.ZERO

func _init_stats() -> void:
	kind = "gunner"
	max_hp = 36.0
	contact_dmg = 8.0
	shot_dmg = 10.0
	speed = 90.0
	score_value = 35
	credit_value = 4

func _ai(delta: float, p) -> void:
	var d: Vector2 = p.global_position - global_position
	if absf(d.x) > 4.0 and state != "fire":
		facing = signf(d.x)
	var target_vx := 0.0
	if absf(d.x) < 200.0 and is_on_floor() and ground_ahead(-facing):
		target_vx = -facing * speed
	velocity.x = move_toward(velocity.x, target_vx, 900.0 * delta)
	phase += absf(velocity.x) * delta * 0.05
	state_t -= delta
	match state:
		"idle":
			aim = aim.lerp(d.normalized(), 6.0 * delta).normalized()
			cd -= delta
			if cd <= 0.0 and d.length() < 620.0 and has_los(p.global_position):
				state = "aim"
				state_t = 0.6
		"aim":
			target_pos = p.global_position + p.velocity * 0.15
			aim = aim.lerp((target_pos - eye()).normalized(), 10.0 * delta).normalized()
			if state_t <= 0.0:
				state = "fire"
				shots_left = 1 + int(minf(diff, 3.0) * 0.7)
				state_t = 0.0
		"fire":
			if state_t <= 0.0:
				shoot(eye() + aim * 100.0, 540.0, 4.0)
				shots_left -= 1
				state_t = 0.14
				if shots_left <= 0:
					state = "idle"
					cd = randf_range(1.3, 2.0)

func _draw() -> void:
	var p := Figure.pose(phase, absf(velocity.x) / 120.0, signf(velocity.x) if absf(velocity.x) > 10.0 else facing, is_on_floor(), aim, 14.0, velocity.y)
	Figure.draw(self, p, draw_color(), 2.2, 1.0)
	last_pose = p
	draw_visor(p, aim, Color(1.0, 0.85, 0.9))
	if state == "aim":
		draw_telegraph(to_local(target_pos), 1.0 - state_t / 0.6)
