# Scharfschütze: lange Ziellinie, dann ein sehr schneller, starker Schuss.
extends "res://scripts/enemies/enemy.gd"

var state := "idle"
var state_t := 0.0
const AIM_TIME := 1.1

func _init_stats() -> void:
	kind = "sniper"
	max_hp = 30.0
	contact_dmg = 8.0
	shot_dmg = 22.0
	speed = 0.0
	score_value = 45
	credit_value = 5
	activate_dist = 1100.0

func _ai(delta: float, p) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
	var to_p: Vector2 = p.global_position - eye()
	state_t -= delta
	match state:
		"idle":
			aim = aim.lerp(to_p.normalized(), 4.0 * delta).normalized()
			facing = signf(aim.x) if absf(aim.x) > 0.05 else facing
			cd -= delta
			if cd <= 0.0 and to_p.length() < 950.0 and has_los(p.global_position):
				state = "aim"
				state_t = AIM_TIME
				Sfx.play_at("charge", global_position, -8.0, 1.4)
		"aim":
			# folgt dem Spieler, friert kurz vor dem Schuss ein
			if state_t > 0.25:
				aim = aim.lerp(to_p.normalized(), 5.0 * delta).normalized()
			if state_t <= 0.0:
				var origin := eye() + aim * 24.0
				game.bullets.spawn_enemy(origin, aim * 1350.0, shot_dmg, col, 1.3)
				game.fx.muzzle(origin, aim, col)
				Sfx.play_at("sniper_shot", global_position, -3.0)
				state = "idle"
				cd = randf_range(2.4, 3.2)

func _draw() -> void:
	var p := Figure.pose(0.0, 0.0, facing, is_on_floor(), aim, 22.0, velocity.y)
	Figure.draw(self, p, draw_color(), 2.0, 1.0)
	if state == "aim":
		var k := 1.0 - state_t / AIM_TIME
		var from := Vector2(0, -14) + aim * 24.0
		var c := Neon.fade(col, 0.15 + 0.6 * k)
		if state_t < 0.25 and fmod(state_t, 0.08) < 0.04:
			c = Neon.hdr(col, 0.8)
		draw_line(from, from + aim * 1100.0, c, 1.0 + k * 1.5)
