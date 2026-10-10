# Spielfigur mit dynamischem Movement:
# Laufen mit Schwung, Sprung (Coyote-Time, Sprungpuffer, halbe Schwerkraft am Scheitel, Schnellfall), Doppelsprung,
# Wall-Slide und Walljump, Rutschen mit Rutsch-Sprung, 8-Richtungs-Dash mit Super-Sprung, Ground-Slam,
# Ecken-Korrektur und Kanten-Hochziehen. Dazu Zielen und Schießen.
extends CharacterBody2D

const Neon = preload("res://scripts/core/neon.gd")
const Figure = preload("res://scripts/core/figure.gd")
const Data = preload("res://scripts/core/data.gd")

signal died

const GRAVITY := 1950.0
const MAX_FALL := 1100.0
const FAST_FALL := 1550.0
const APEX_VY := 140.0          # unterhalb dieser Steiggeschwindigkeit gilt halbe Schwerkraft
const RUN_SPEED := 360.0
const MAX_SPEED := 950.0
const ACCEL_GROUND := 3600.0
const ACCEL_AIR := 2400.0
const FRICTION := 3200.0
const OVERSPEED_AIR := 380.0    # so langsam baut sich Überschuss-Tempo in der Luft ab
const OVERSPEED_GROUND := 1500.0
const JUMP_V := 760.0
const AIR_JUMP_V := 660.0
const WALL_JUMP := Vector2(430.0, 720.0)
const WALL_SLIDE_MAX := 170.0
const WALL_REACH := 7.0         # Walljump funktioniert auch knapp neben der Wand
const COYOTE := 0.11
const BUFFER := 0.13
const DASH_SPEED := 840.0
const DASH_TIME := 0.16
const DASH_CD := 0.32
const SUPER_JUMP_WINDOW := 0.12
const SLIDE_TIME := 0.5
const SLIDE_SPEED := 540.0
const SLAM_SPEED := 1500.0
const SPIN_TIME := 0.38

var game
var color := Color(0.75, 0.9, 1.0)
var weapon: Dictionary
var hp := 100.0
var invuln := 0.0
var coyote_t := 0.0
var buffer_t := 0.0
var air_jumps_left := 0
var dash_t := 0.0
var dash_cd_t := 0.0
var dash_vec := Vector2.RIGHT
var dash_charges := 1
var after_dash_t := 0.0
var dash_hits: Array = []
var slide_t := 0.0
var slide_dir := 1.0
var slamming := false
var wall_dir := 0
var wall_sliding := false
var wall_lock_t := 0.0
var fire_cd := 0.0
var aim := Vector2.RIGHT
var aim_override := Vector2.ZERO  # für den Testbot
var facing := 1.0
var run_phase := 0.0
var land_squash := 0.0
var recoil := 0.0
var shield_ready := false
var shield_t := 0.0
var drop_t := 0.0
var safe_pos := Vector2.ZERO
var ground_time := 0.0
var ghost_t := 0.0
var trail_t := 0.0
var spark_t := 0.0
var spin_t := 0.0
var spin_dir := 1.0
var anim_t := 0.0
var frozen := false
var dead := false
var hurt_flash := 0.0
var was_on_floor := false
var god := false  # Testmodus
var shape: CollisionShape2D
var cap: CapsuleShape2D

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 8
	shape = CollisionShape2D.new()
	cap = CapsuleShape2D.new()
	cap.radius = 11.0
	cap.height = 54.0
	shape.shape = cap
	add_child(shape)
	floor_max_angle = deg_to_rad(52.0)
	floor_snap_length = 12.0
	floor_constant_speed = true
	z_index = 12
	safe_pos = global_position
	weapon = Data.WEAPONS[Run.weapon_id]
	hp = Run.hp
	shield_ready = Run.stats["shield"] > 0

func max_hp() -> float:
	return Run.stats["max_hp"]

func dash_ready_ratio() -> float:
	if dash_charges <= 0:
		return 0.0
	return 1.0 - clampf(dash_cd_t / (DASH_CD * Run.stats["dash_cd_mult"]), 0.0, 1.0)

func is_dodging() -> bool:
	return dash_t > 0.0 or slamming

# Sprungfeld: weit nach oben schleudern, Dash und Doppelsprung auffrischen
func launch(power: float) -> void:
	velocity.y = -power
	slamming = false
	dash_t = 0.0
	dash_charges = 1
	air_jumps_left = Run.stats["air_jumps"]
	coyote_t = 0.0
	spin_t = SPIN_TIME
	spin_dir = facing
	_end_slide_silent()
	Sfx.play("jump", -4.0, 0.75)
	Sfx.play("dash", -8.0, 1.3)
	game.fx.ring(global_position + Vector2(0, 24), color, 60.0, 0.4)
	game.fx.sparks(global_position + Vector2(0, 26), color, 14, 500.0, Vector2.UP, 0.5)
	game.shake(0.2)
	game.rumble(0.4, 0.12)

func on_kill() -> void:
	# Abschüsse laden Luft-Dash und Doppelsprung wieder auf -> Kombos in der Luft
	dash_charges = 1
	air_jumps_left = Run.stats["air_jumps"]

func _physics_process(delta: float) -> void:
	if dead:
		return
	var s: Dictionary = Run.stats
	invuln = maxf(0.0, invuln - delta)
	hurt_flash = maxf(0.0, hurt_flash - delta)
	dash_cd_t = maxf(0.0, dash_cd_t - delta)
	fire_cd = maxf(0.0, fire_cd - delta)
	buffer_t = maxf(0.0, buffer_t - delta)
	coyote_t = maxf(0.0, coyote_t - delta)
	after_dash_t = maxf(0.0, after_dash_t - delta)
	wall_lock_t = maxf(0.0, wall_lock_t - delta)
	land_squash = maxf(0.0, land_squash - delta * 4.0)
	recoil = maxf(0.0, recoil - delta * 10.0)
	spin_t = maxf(0.0, spin_t - delta)
	anim_t += delta
	if s["shield"] > 0 and not shield_ready:
		shield_t -= delta
		if shield_t <= 0.0:
			shield_ready = true
			game.fx.ring(global_position, color, 40.0, 0.4)
	if drop_t > 0.0:
		drop_t -= delta
		if drop_t <= 0.0:
			set_collision_mask_value(4, true)

	var input_x := 0.0 if frozen else Input.get_axis("move_left", "move_right")
	var down := not frozen and Input.is_action_pressed("move_down")
	_update_aim()
	if not frozen and Input.is_action_just_pressed("jump"):
		buffer_t = BUFFER
	var on_floor := is_on_floor()
	if on_floor:
		coyote_t = COYOTE
		air_jumps_left = s["air_jumps"]
		dash_charges = 1
	wall_dir = 0 if on_floor else _wall_dir()
	if wall_dir != 0:
		dash_charges = 1
	var pre_vel := velocity

	if slamming:
		velocity = Vector2(0.0, SLAM_SPEED)
		ghost_t -= delta
		if ghost_t <= 0.0:
			ghost_t = 0.03
			game.fx.ghost(Figure.to_global(_pose(), global_transform), color, 0.4, 0.25)
	elif dash_t > 0.0:
		_dash_step(delta, s)
		# Super-Sprung: Springen während des Dashs am Boden
		if buffer_t > 0.0 and (on_floor or coyote_t > 0.0):
			_super_jump()
	else:
		_move_step(delta, s, input_x, down, on_floor)

	move_and_slide()
	_corner_correction(pre_vel)
	_ledge_pop(pre_vel, input_x)

	on_floor = is_on_floor()
	if on_floor and not was_on_floor:
		_land(pre_vel)
	was_on_floor = on_floor
	if slide_t > 0.0:
		slide_t -= delta
		if slide_t <= 0.0 or not on_floor or absf(velocity.x) < 120.0:
			_end_slide()
	if on_floor:
		run_phase += absf(velocity.x) * delta * 0.052
		ground_time += delta
		if ground_time > 0.25 and _solid_below():
			safe_pos = global_position
			ground_time = 0.0
	else:
		ground_time = 0.0

	if not frozen and Input.is_action_pressed("shoot") and fire_cd <= 0.0:
		_shoot()
	_effects(delta, on_floor)
	queue_redraw()

func _move_step(delta: float, s: Dictionary, input_x: float, down: bool, on_floor: bool) -> void:
	var run: float = RUN_SPEED * s["move_mult"]
	var target := input_x * run
	if slide_t > 0.0:
		# Rutschen: kaum Reibung; bergab wird man schneller und rutscht weiter
		var n := get_floor_normal() if on_floor else Vector2.UP
		if on_floor and signf(n.x) == slide_dir and absf(n.x) > 0.12:
			velocity.x = clampf(velocity.x + slide_dir * 1700.0 * absf(n.x) * delta, -MAX_SPEED, MAX_SPEED)
			slide_t = maxf(slide_t, 0.12)
		else:
			velocity.x = move_toward(velocity.x, slide_dir * run * 0.6, 520.0 * delta)
	else:
		var accel := ACCEL_GROUND if on_floor else ACCEL_AIR
		if wall_lock_t > 0.0:
			accel *= 0.3
		var over := absf(velocity.x) > run and (signf(velocity.x) == signf(input_x) or absf(input_x) < 0.1)
		if over:
			# Schwung behalten: Überschuss-Tempo baut sich nur langsam ab
			velocity.x = move_toward(velocity.x, signf(velocity.x) * run, (OVERSPEED_GROUND if on_floor else OVERSPEED_AIR) * delta)
		elif absf(input_x) < 0.1 and on_floor:
			velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		else:
			velocity.x = move_toward(velocity.x, target, accel * delta)
	# Schwerkraft: halb am Scheitel, verstärkt beim Schnellfall
	var g: float = GRAVITY * s["grav_mult"]
	var max_fall := MAX_FALL
	if not on_floor and absf(velocity.y) < APEX_VY and Input.is_action_pressed("jump"):
		g *= 0.5
	if not on_floor and down and velocity.y > 0.0 and wall_dir == 0:
		g *= 1.6
		max_fall = FAST_FALL
	velocity.y = minf(velocity.y + g * delta, max_fall)
	# Wall-Slide: in der Luft gegen die Wand drücken
	wall_sliding = wall_dir != 0 and velocity.y > 0.0 and signf(input_x) == wall_dir and slide_t <= 0.0
	if wall_sliding:
		velocity.y = minf(velocity.y, WALL_SLIDE_MAX)
	# Rutschen starten
	if on_floor and down and slide_t <= 0.0 and absf(velocity.x) > 220.0 and Input.is_action_just_pressed("move_down"):
		_start_slide()
	# Springen
	if buffer_t > 0.0 and down and on_floor and _on_ledge():
		drop_t = 0.25
		buffer_t = 0.0
		set_collision_mask_value(4, false)
		position.y += 2.0
	elif buffer_t > 0.0:
		if slide_t > 0.0 and (on_floor or coyote_t > 0.0):
			if _can_stand():
				_slide_jump()
			else:
				buffer_t = 0.0  # unter einer Decke: weiterrutschen statt festklemmen
		elif coyote_t > 0.0:
			if after_dash_t > 0.0:
				_super_jump()
			else:
				_jump(JUMP_V)
			coyote_t = 0.0
		elif wall_dir != 0 or _wall_dir() != 0:
			_wall_jump(wall_dir if wall_dir != 0 else _wall_dir())
		elif air_jumps_left > 0:
			air_jumps_left -= 1
			_jump(AIR_JUMP_V)
			spin_t = SPIN_TIME
			spin_dir = facing
			game.fx.ring(global_position + Vector2(0, 24), color, 30.0, 0.3)
	if not frozen and Input.is_action_just_released("jump") and velocity.y < -250.0:
		velocity.y *= 0.5
	# Dash / Ground-Slam
	if not frozen and Input.is_action_just_pressed("dash"):
		if not on_floor and down:
			_start_slam()
		elif dash_cd_t <= 0.0 and dash_charges > 0:
			_start_dash(input_x)

func _dash_step(delta: float, s: Dictionary) -> void:
	dash_t -= delta
	velocity = dash_vec * DASH_SPEED
	ghost_t -= delta
	if ghost_t <= 0.0:
		ghost_t = 0.022
		game.fx.ghost(Figure.to_global(_pose(), global_transform), color, 0.55, 0.3)
	if s["dash_dmg"] > 0.0:
		for e in game.enemies_near(global_position, 40.0):
			if not e in dash_hits:
				dash_hits.append(e)
				e.take_damage(s["dash_dmg"] * s["dmg_mult"], dash_vec, false)
	if dash_t <= 0.0:
		# Schwung aus dem Dash mitnehmen
		velocity = Vector2(dash_vec.x * maxf(RUN_SPEED * 1.25, absf(velocity.x) * 0.62), dash_vec.y * DASH_SPEED * 0.35)
		after_dash_t = SUPER_JUMP_WINDOW

func _update_aim() -> void:
	if aim_override != Vector2.ZERO:
		aim = aim_override.normalized()
	elif Controls.using_gamepad:
		aim = Controls.aim_vector(global_position, game)
	else:
		var m := get_global_mouse_position() - (global_position + Vector2(0, -12))
		if m.length() > 4.0:
			aim = m.normalized()
	if absf(aim.x) > 0.05:
		facing = signf(aim.x)

func _jump(v: float) -> void:
	velocity.y = -v
	buffer_t = 0.0
	Sfx.play("jump", -10.0)
	game.fx.dust(global_position + Vector2(0, 27), Neon.fade(color, 0.5), 4)

func _super_jump() -> void:
	# Dash + Sprung: flacher, sehr schneller Weitsprung
	var dir := signf(dash_vec.x) if absf(dash_vec.x) > 0.1 else facing
	dash_t = 0.0
	after_dash_t = 0.0
	velocity = Vector2(dir * 700.0, -JUMP_V * 0.82)
	buffer_t = 0.0
	coyote_t = 0.0
	Sfx.play("jump", -6.0, 1.25)
	game.fx.ring(global_position + Vector2(0, 20), color, 46.0, 0.35)
	game.fx.dust(global_position + Vector2(0, 27), color, 10)
	game.shake(0.15)
	game.rumble(0.3, 0.1)

func _wall_jump(dir: int) -> void:
	velocity = Vector2(-dir * WALL_JUMP.x, -WALL_JUMP.y)
	wall_lock_t = 0.15
	buffer_t = 0.0
	dash_charges = 1
	facing = -dir
	Sfx.play("jump", -8.0, 1.1)
	game.fx.dust(global_position + Vector2(dir * 12.0, 0), Neon.fade(color, 0.6), 8)

func _start_slide() -> void:
	slide_t = SLIDE_TIME
	slide_dir = signf(velocity.x)
	velocity.x = slide_dir * maxf(absf(velocity.x) * 1.15, SLIDE_SPEED)
	_set_small(true)
	Sfx.play("dash", -10.0, 0.8)
	game.fx.dust(global_position + Vector2(0, 27), color, 8)

func _end_slide() -> void:
	slide_t = 0.0
	if _can_stand():
		_set_small(false)
	else:
		slide_t = 0.1  # unter einer Decke weiter rutschen

func _slide_jump() -> void:
	velocity.x = slide_dir * minf(absf(velocity.x) * 1.12, 680.0)
	velocity.y = -JUMP_V * 0.9
	buffer_t = 0.0
	coyote_t = 0.0
	slide_t = 0.0
	_set_small(false)
	Sfx.play("jump", -7.0, 1.15)
	game.fx.dust(global_position + Vector2(0, 27), color, 8)

func _start_dash(input_x: float) -> void:
	var dy := 0.0
	if not frozen:
		dy = Input.get_axis("move_up", "move_down")
		if Controls.using_gamepad:
			dy = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
			if absf(dy) < 0.4:
				dy = 0.0
	var v := Vector2(input_x, dy)
	if v.length() < 0.3:
		v = Vector2(facing, 0.0)
	dash_vec = v.normalized()
	if is_on_floor() and dash_vec.y > 0.0:
		dash_vec = Vector2(signf(dash_vec.x) if dash_vec.x != 0.0 else facing, 0.0)
	dash_t = DASH_TIME
	dash_cd_t = DASH_CD * Run.stats["dash_cd_mult"]
	if not is_on_floor():
		dash_charges -= 1
	dash_hits.clear()
	_end_slide_silent()
	Sfx.play("dash", -6.0)
	game.shake(0.12)
	game.rumble(0.25, 0.08)

func _end_slide_silent() -> void:
	if slide_t > 0.0:
		slide_t = 0.0
		if _can_stand():
			_set_small(false)

func _start_slam() -> void:
	slamming = true
	dash_t = 0.0
	velocity = Vector2(0, SLAM_SPEED)
	Sfx.play("dash", -4.0, 0.7)

func _land(pre_vel: Vector2) -> void:
	land_squash = clampf(pre_vel.y / 900.0, 0.3, 1.0)
	game.fx.dust(global_position + Vector2(0, 27), Neon.fade(color, 0.6), 5)
	Sfx.play("land", -14.0)
	if slamming:
		slamming = false
		var dmg: float = 40.0 * Run.stats["dmg_mult"] + Run.stats["dash_dmg"]
		for e in game.enemies_near(global_position + Vector2(0, 20), 130.0):
			e.take_damage(dmg, (e.global_position - global_position).normalized() + Vector2(0, -0.8), false)
		if not game.slam_break(global_position + Vector2(0, 30)):
			game.carve(global_position + Vector2(0, 30), 26.0, Vector2.UP)
		game.fx.shockwave(global_position + Vector2(0, 26), color, 160.0)
		game.fx.ring(global_position + Vector2(0, 26), color, 120.0, 0.35)
		game.fx.sparks(global_position + Vector2(0, 26), color, 24, 600.0, Vector2.UP, 1.2)
		game.shake(0.55)
		game.punch(0.03, 0.3)
		game.hitstop(0.05)
		game.rumble(0.7, 0.18)
		Sfx.play("explosion", -4.0, 1.2)
		velocity.y = -260.0
		invuln = maxf(invuln, 0.2)
	elif pre_vel.y > 900.0:
		game.shake(0.15)

func _wall_dir() -> int:
	for d in [1, -1]:
		if test_move(global_transform, Vector2(d * WALL_REACH, 0)):
			# nur echte Wände, keine flachen Hänge
			var q := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -6), global_position + Vector2(d * (11.0 + WALL_REACH + 4.0), -6), 1)
			var hit := get_world_2d().direct_space_state.intersect_ray(q)
			if not hit.is_empty() and absf(hit["normal"].x) > 0.8:
				return d
	return 0

# Kopf stößt an eine Ecke -> seitlich vorbeischieben (wie in Celeste)
func _corner_correction(pre_vel: Vector2) -> void:
	if pre_vel.y >= -100.0 or not is_on_ceiling():
		return
	for off in [3.0, 6.0, 9.0, 12.0]:
		for dir in [1.0, -1.0]:
			var xf := global_transform.translated(Vector2(off * dir, 0))
			if not test_move(global_transform, Vector2(off * dir, 0)) and not test_move(xf, Vector2(0, -8)):
				position.x += off * dir
				velocity.y = pre_vel.y
				return

# Gegen eine niedrige Kante laufen/dashen -> automatisch hochziehen
func _ledge_pop(pre_vel: Vector2, input_x: float) -> void:
	if not is_on_wall() or absf(pre_vel.x) < 60.0:
		return
	var dir := signf(pre_vel.x)
	if absf(input_x) > 0.1 and signf(input_x) != dir and dash_t <= 0.0:
		return
	var max_h := 34.0 if dash_t > 0.0 else 18.0
	if not is_on_floor() and dash_t <= 0.0:
		max_h = 22.0
	var h := 6.0
	while h <= max_h:
		var up := Vector2(0, -h)
		if not test_move(global_transform, up) and not test_move(global_transform.translated(up), Vector2(dir * 6.0, 0)):
			position += up + Vector2(dir * 3.0, 0)
			velocity.x = pre_vel.x
			return
		h += 6.0

func _set_small(small: bool) -> void:
	if small:
		cap.height = 32.0
		shape.position = Vector2(0, 11)
	else:
		cap.height = 54.0
		shape.position = Vector2.ZERO

func _can_stand() -> bool:
	if cap.height >= 54.0:
		return true
	return not test_move(global_transform, Vector2(0, -24))

func _on_ledge() -> bool:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i).get_collider()
		if c and c.is_in_group("ledge"):
			return true
	return false

# Sicherer Rücksetzpunkt: fester Boden direkt unter der Figur, nicht am Abgrund
func _solid_below() -> bool:
	var space := get_world_2d().direct_space_state
	for ox in [-26.0, 26.0]:
		var from := global_position + Vector2(ox, 0)
		var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 60), 1)
		if space.intersect_ray(q).is_empty():
			return false
	return true

func _effects(delta: float, on_floor: bool) -> void:
	trail_t -= delta
	var speed := velocity.length()
	if dash_t <= 0.0 and not slamming and trail_t <= 0.0 and (absf(velocity.x) > 260.0 or not on_floor):
		trail_t = 0.05 if speed < 600.0 else 0.03
		game.fx.ghost(Figure.to_global(_pose(), global_transform), color.lerp(Color(0.3, 0.6, 1.0), 0.5), 0.22 if speed < 600.0 else 0.32, 0.22)
	spark_t -= delta
	if spark_t <= 0.0:
		spark_t = 0.04
		if wall_sliding:
			game.fx.sparks(global_position + Vector2(wall_dir * 11.0, -10.0), Color(1.0, 0.85, 0.5), 2, 160.0, Vector2(-wall_dir, -0.4), 0.6)
		elif slide_t > 0.0:
			game.fx.sparks(global_position + Vector2(-slide_dir * 6.0, 26.0), color, 2, 220.0, Vector2(-slide_dir, -0.5), 0.5)

func gun_tip() -> Vector2:
	return global_position + Vector2(0, -14 + (14 if slide_t > 0.0 else 0)) + aim * (27.0 + weapon["length"] * 0.4)

func _shoot() -> void:
	var s: Dictionary = Run.stats
	var rate: float = weapon["rate"] * s["rate_mult"]
	if s["adrenaline"] and hp < max_hp() * 0.35:
		rate *= 1.4
	fire_cd = 1.0 / rate
	var base_count: int = weapon["count"]
	var count: int = base_count + s["extra_proj"]
	var origin := gun_tip()
	var spread: float = weapon["spread"]
	var speed: float = weapon["speed"] * s["speed_mult"]
	var net_vels := PackedVector2Array()
	var any_crit := false
	for i in count:
		var ang := aim.angle()
		if base_count == 1 and count > 1:
			ang += deg_to_rad((i - (count - 1) * 0.5) * 7.0) + deg_to_rad(randf_range(-spread, spread) * 0.5)
		else:
			ang += deg_to_rad(randf_range(-spread, spread))
		var crit: bool = randf() < s["crit"]
		var v := Vector2.from_angle(ang) * speed * randf_range(0.94, 1.06)
		game.bullets.spawn_player(origin, v, weapon, crit)
		net_vels.append(v)
		any_crit = any_crit or crit
	if Net.active:
		Net.p_shot.rpc(origin, net_vels, Run.weapon_id, any_crit)
	game.fx.muzzle(origin, aim, weapon["color"])
	Sfx.play(weapon["sfx"], -7.0)
	recoil = 1.0
	if weapon["shake"] > 0.0:
		game.shake(weapon["shake"])
		game.rumble(weapon["shake"], 0.06)
	if base_count > 1 and not is_on_floor():
		velocity -= aim * 140.0  # Rückstoß der Streukanone in der Luft (Rocket-Jump-Gefühl)

func take_damage(amount: float, from_pos: Vector2) -> void:
	if dead or invuln > 0.0 or dash_t > 0.0 or slamming or frozen or god:
		return
	if shield_ready:
		shield_ready = false
		shield_t = 12.0 / Run.stats["shield"]
		invuln = 0.6
		game.fx.ring(global_position, color, 60.0, 0.5)
		game.fx.sparks(global_position, color, 14, 400.0)
		Sfx.play("shield", -3.0)
		return
	var dmg: float = amount * Run.stats["dmg_taken"]
	hp -= dmg
	Run.section_damage += dmg
	invuln = 0.9
	hurt_flash = 0.3
	var dir := signf(global_position.x - from_pos.x)
	if dir == 0.0:
		dir = -facing
	velocity = Vector2(dir * 320.0, -320.0)
	_end_slide_silent()
	game.shake(0.5)
	game.hitstop(0.05)
	game.on_player_hurt(dmg)
	game.rumble(0.8, 0.2)
	Sfx.play("hurt", -2.0)
	game.fx.sparks(global_position, Color(1, 0.3, 0.3), 12, 380.0)
	if hp <= 0.0:
		hp = 0.0
		_die()

func heal(amount: float) -> void:
	if dead:
		return
	var before := hp
	hp = minf(max_hp(), hp + amount)
	if hp > before:
		game.fx.text(global_position + Vector2(0, -50), "+%d" % int(hp - before), Color(0.4, 1.0, 0.5), 16.0)

func _die() -> void:
	dead = true
	visible = false
	set_physics_process(false)
	game.fx.explosion(global_position, color, 1.6)
	game.rumble(1.0, 0.4)
	died.emit()

func revive(at: Vector2, hp_ratio: float) -> void:
	dead = false
	visible = true
	slamming = false
	set_physics_process(true)
	global_position = at
	velocity = Vector2.ZERO
	hp = max_hp() * hp_ratio
	invuln = 2.0
	game.fx.ring(global_position, color, 90.0, 0.6)

func respawn_safe(damage: float) -> void:
	global_position = safe_pos + Vector2(0, -10)
	velocity = Vector2.ZERO
	slamming = false
	dash_t = 0.0
	invuln = 0.0
	take_damage(damage, global_position + Vector2(facing * -10, 0))
	if not dead:
		invuln = 1.2
		game.fx.ring(global_position, color, 70.0, 0.5)

func _pose() -> Dictionary:
	var md := signf(velocity.x) if absf(velocity.x) > 20.0 else facing
	var spin := 0.0
	if spin_t > 0.0:
		spin = (1.0 - spin_t / SPIN_TIME) * TAU * spin_dir
	var extra := {"idle_t": anim_t, "spin": spin, "dash": dash_t > 0.0, "slide": slide_t > 0.0,
		"wall": wall_dir if wall_sliding else 0, "slam": slamming}
	if slide_t > 0.0:
		md = slide_dir
	elif wall_sliding:
		md = float(wall_dir)
	var p := Figure.pose(run_phase, absf(velocity.x) / RUN_SPEED, md, is_on_floor(), aim, 10.0 + weapon["length"] * 0.4, velocity.y, recoil, 1.0, extra)
	if land_squash > 0.0:
		var sq := 1.0 - land_squash * 0.14
		for seg in p["segs"]:
			var a: Vector2 = seg[0]
			var b: Vector2 = seg[1]
			seg[0] = Vector2(a.x, 27.0 - (27.0 - a.y) * sq)
			seg[1] = Vector2(b.x, 27.0 - (27.0 - b.y) * sq)
		var h: Vector2 = p["head"]
		p["head"] = Vector2(h.x, 27.0 - (27.0 - h.y) * sq)
	return p

func _draw() -> void:
	var c := color
	if hurt_flash > 0.0:
		c = c.lerp(Color(1, 0.25, 0.25), hurt_flash / 0.3)
	if invuln > 0.0 and fmod(invuln, 0.16) < 0.08:
		c = Neon.fade(c, 0.35)
	if dash_t > 0.0 or slamming:
		c = Neon.hdr(c, 0.4)
	Neon.halo(self, Vector2(0, -6 + (12 if slide_t > 0.0 else 0)), 44.0, Neon.fade(c, 0.13))
	Figure.draw(self, _pose(), c, 2.6, 1.1)
	if shield_ready:
		draw_arc(Vector2(0, -2), 34.0, 0.0, TAU, 32, Neon.fade(color, 0.25 + 0.1 * sin(Time.get_ticks_msec() * 0.006)), 1.5)
