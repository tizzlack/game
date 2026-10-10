# Läufer: rennt auf den Spieler zu, springt über Hindernisse, Kontaktschaden.
extends "res://scripts/enemies/enemy.gd"

var jump_cd := 0.0

func _init_stats() -> void:
	kind = "walker"
	max_hp = 30.0
	contact_dmg = 14.0
	speed = 175.0
	score_value = 25
	credit_value = 3

func _ai(delta: float, p) -> void:
	jump_cd -= delta
	var d: Vector2 = p.global_position - global_position
	var chasing := absf(d.x) < 700.0 and absf(d.y) < 320.0
	if chasing:
		facing = signf(d.x) if absf(d.x) > 4.0 else facing
	elif is_on_wall() or (is_on_floor() and not ground_ahead(facing)):
		facing = -facing
	var target := facing * speed * (1.0 if chasing else 0.45)
	if is_on_floor() and not ground_ahead(facing) and not (chasing and d.y > 40.0):
		target = 0.0
	velocity.x = move_toward(velocity.x, target, 1500.0 * delta)
	if is_on_floor() and jump_cd <= 0.0 and (is_on_wall() or (chasing and d.y < -90.0 and absf(d.x) < 180.0)):
		velocity.y = -640.0
		jump_cd = 0.8
	phase += absf(velocity.x) * delta * 0.05

func _draw() -> void:
	var p := Figure.pose(phase, absf(velocity.x) / 180.0, facing, is_on_floor(), Vector2(facing, 0), 0.0, velocity.y)
	Figure.draw(self, p, draw_color(), 2.2, 1.0)
	last_pose = p
	draw_visor(p, Vector2(facing, 0), Color(1.0, 0.85, 0.9))
