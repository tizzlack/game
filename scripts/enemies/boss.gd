# Boss "Sentinel": schwebender Kern mit Ringsalven, Fächerschüssen, Laserschwenk, Drohnen und Geschossregen.
# Ab 50 % Leben Phase 2: schneller und mehr Geschosse.
extends "res://scripts/enemies/enemy.gd"

var arena := Rect2()
var world_i := 0
var state := "intro"
var state_t := 0.0
var t := 0.0
var phase2 := false
var hover_target := Vector2.ZERO
var home := Vector2.ZERO
var pattern_i := 0
var sub_t := 0.0
var sub_n := 0
var ring_off := 0.0
var laser_angle := 0.0
var laser_from := 0.0
var laser_to := 0.0
var laser_on := false
var laser_tele := false
var accent := Color.WHITE
var fight_time := 0.0

const PATTERNS := ["ring", "volley", "laser", "ring", "summon", "rain", "volley", "laser"]

func _init_stats() -> void:
	kind = "boss"
	max_hp = 1700.0
	contact_dmg = 25.0
	shot_dmg = 11.0
	speed = 0.0
	score_value = 2000
	credit_value = 60
	radius = 48.0
	shape_size = Vector2(96, 96)
	uses_gravity = false
	is_boss = true
	knock_resist = 1.0
	activate_dist = 99999.0

func setup_boss(a: Rect2, w: int, acc: Color) -> void:
	arena = a
	world_i = w
	accent = acc
	max_hp *= 1.0 + 0.55 * w
	hp = max_hp
	home = global_position
	hover_target = home

func _on_activate() -> void:
	state = "intro"
	state_t = 2.2
	global_position = home + Vector2(0, -420)

func _ai(delta: float, p) -> void:
	t += delta
	state_t -= delta
	sub_t -= delta
	if state != "intro":
		fight_time += delta
	if not phase2 and hp < max_hp * 0.5:
		phase2 = true
		game.boss_phase2()
		state = "idle"
		state_t = 1.0
		laser_on = false
		laser_tele = false
	var spd := 1.35 if phase2 else 1.0
	# Bewegung
	var bob := Vector2(sin(t * 1.3) * 30.0, sin(t * 2.1) * 18.0)
	var target := (home if state == "intro" else hover_target) + bob
	global_position = global_position.lerp(target, clampf(2.0 * delta, 0.0, 1.0))
	aim = (p.global_position - global_position).normalized()
	match state:
		"intro":
			if state_t <= 0.0:
				_next_idle()
		"idle":
			if state_t <= 0.0:
				_start_pattern()
		"ring":
			if sub_t <= 0.0:
				var n := 14 + world_i * 3 + (6 if phase2 else 0)
				for i in n:
					var ang := ring_off + TAU * i / n
					game.bullets.spawn_enemy(global_position + Vector2.from_angle(ang) * 50.0, Vector2.from_angle(ang) * 260.0 * spd, shot_dmg, col, 1.2)
				ring_off += 0.17
				sub_n -= 1
				sub_t = 0.55 / spd
				Sfx.play("enemy_shoot", -2.0, 0.7)
				game.fx.ring(global_position, col, 70.0, 0.3)
				if sub_n <= 0:
					_next_idle()
		"volley":
			if sub_t <= 0.0:
				var cnt := 5 + (2 if phase2 else 0)
				var base := aim.angle()
				for i in cnt:
					var ang := base + deg_to_rad((i - (cnt - 1) * 0.5) * 9.0)
					game.bullets.spawn_enemy(global_position + Vector2.from_angle(ang) * 50.0, Vector2.from_angle(ang) * 420.0 * spd, shot_dmg, col, 1.1)
				sub_n -= 1
				sub_t = 0.45 / spd
				Sfx.play("enemy_shoot", -2.0, 0.9)
				if sub_n <= 0:
					_next_idle()
		"laser":
			if laser_tele:
				laser_angle = lerp_angle(laser_angle, aim.angle(), 2.0 * delta)
				if state_t <= 0.0:
					laser_tele = false
					laser_on = true
					laser_from = laser_angle - 0.7
					laser_to = laser_angle + 0.7
					if randf() < 0.5:
						var tmp := laser_from
						laser_from = laser_to
						laser_to = tmp
					state_t = 1.4 / spd
					Sfx.play("laser", 0.0)
					game.shake(0.4)
			elif laser_on:
				var k := 1.0 - state_t / (1.4 / spd)
				laser_angle = lerp_angle(laser_from, laser_to, k)
				var dir := Vector2.from_angle(laser_angle)
				var rel: Vector2 = p.global_position - global_position
				var along := rel.dot(dir)
				var dist := absf(rel.cross(dir))
				if along > 0.0 and dist < 22.0:
					p.take_damage(shot_dmg * 1.6, global_position)
				if randf() < 0.6:
					game.fx.sparks(global_position + dir * minf(along, 900.0), col, 1, 200.0)
				if state_t <= 0.0:
					laser_on = false
					_next_idle()
		"summon":
			if sub_t <= 0.0:
				if game.count_kind("drone") < 4:
					game.spawn_enemy("drone", global_position + Vector2(randf_range(-60, 60), 40))
				sub_n -= 1
				sub_t = 0.4
				if sub_n <= 0:
					_next_idle()
		"rain":
			if sub_t <= 0.0:
				for i in (3 if phase2 else 2):
					var x := randf_range(arena.position.x + 40.0, arena.end.x - 40.0)
					game.bullets.spawn_enemy(Vector2(x, arena.position.y + 60.0), Vector2(randf_range(-30, 30), 330.0 * spd), shot_dmg, accent, 1.0)
				sub_n -= 1
				sub_t = 0.12 / spd
				if sub_n <= 0:
					_next_idle()

func _next_idle() -> void:
	state = "idle"
	state_t = (0.9 if phase2 else 1.4)
	var side := randf_range(-1.0, 1.0)
	hover_target = home + Vector2(side * arena.size.x * 0.32, randf_range(-60.0, 40.0))

func _start_pattern() -> void:
	var pat: String = PATTERNS[pattern_i % PATTERNS.size()]
	pattern_i += 1
	if pat == "summon" and world_i == 0 and not phase2:
		pat = "ring"
	if pat == "rain" and world_i == 0:
		pat = "volley"
	state = pat
	sub_t = 0.2
	match pat:
		"ring": sub_n = 3 + (1 if phase2 else 0)
		"volley": sub_n = 3 + (1 if phase2 else 0)
		"laser":
			laser_tele = true
			laser_angle = aim.angle()
			state_t = 1.0
			Sfx.play("charge", -2.0, 0.7)
		"summon": sub_n = 2 + world_i
		"rain": sub_n = 16 + (8 if phase2 else 0)

func take_damage(amount: float, dir: Vector2 = Vector2.ZERO, crit: bool = false) -> void:
	if state == "intro":
		return
	super.take_damage(amount, dir, crit)

func _draw() -> void:
	var c := draw_color()
	var r := 46.0
	var spin := t * (1.6 if phase2 else 0.9)
	var hex := PackedVector2Array()
	for i in 7:
		hex.append(Vector2.from_angle(spin + TAU * i / 6.0) * r)
	Neon.polyline(self, hex, c, 3.0)
	var hex2 := PackedVector2Array()
	for i in 7:
		hex2.append(Vector2.from_angle(-spin * 1.4 + TAU * i / 6.0 + 0.5) * (r * 0.62))
	Neon.polyline(self, hex2, Neon.fade(accent, 0.8), 2.0)
	var pulse := 1.0 + 0.15 * sin(t * 8.0)
	Neon.dot(self, aim * 8.0, 9.0 * pulse, c, 1.2)
	for i in 6:
		var a := -spin * 0.7 + TAU * i / 6.0
		var p1 := Vector2.from_angle(a) * (r + 18.0 + sin(t * 3.0 + i) * 6.0)
		Neon.line(self, p1, p1 + Vector2.from_angle(a + 1.2) * 12.0, Neon.fade(accent, 0.9), 2.0, 0.8)
	if laser_tele:
		var k := 1.0 - maxf(state_t, 0.0)
		var dir := Vector2.from_angle(laser_angle)
		var flick := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.06)
		draw_line(dir * 50.0, dir * 1800.0, Neon.fade(col, 0.2 + 0.4 * k * flick), 1.0 + k * 2.0)
	if laser_on:
		var dir := Vector2.from_angle(laser_angle)
		Neon.line(self, dir * 40.0, dir * 1800.0, col, 10.0, 1.2)
		draw_line(dir * 40.0, dir * 1800.0, Color(2.5, 2.5, 2.5), 3.0)
