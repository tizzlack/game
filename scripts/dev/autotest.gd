# Automatischer Test: spielt das Spiel per Bot, macht Screenshots und beendet sich.
# Aufruf: godot --path . -- --autotest [--shots=DIR] [--time=SEK] [--god] [--weapon=ID] [--mode=menu|run] [--section=N] [--world=N]
extends Node

var main
var shots_dir := ""
var duration := 60.0
var god := false
var mode := "run"
var t := 0.0
var shot_t := 0.0
var shot_every := 4.0
var shot_n := 0
var jump_hold := 0.0
var stuck_t := 0.0
var last_x := 0.0
var menu_step := 0
var opts := {}
var start_world := 0
var start_section := 0
var frames := 0
var slow_frames := 0
var game_over_seen := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots_dir = a.substr(8)
		elif a.begins_with("--time="):
			duration = float(a.substr(7))
		elif a == "--god":
			god = true
		elif a.begins_with("--weapon="):
			opts["weapon"] = a.substr(9)
		elif a.begins_with("--mode="):
			mode = a.substr(7)
		elif a.begins_with("--world="):
			start_world = int(a.substr(8))
		elif a.begins_with("--section="):
			start_section = int(a.substr(10))
		elif a.begins_with("--every="):
			shot_every = float(a.substr(8))
	if shots_dir != "":
		DirAccess.make_dir_recursive_absolute(shots_dir)
	Save.data["bank"] = maxi(Save.data["bank"], 5000)
	if mode == "menu":
		main.show_menu()
	else:
		opts["seed"] = 12345
		main.start_run(opts)
		Run.world = start_world
		Run.section = start_section
		if start_world > 0 or start_section > 0:
			main.current.start_section()
	print("[autotest] mode=%s time=%.0f god=%s" % [mode, duration, god])

func _shot(tag: String) -> void:
	if shots_dir == "":
		return
	var img := get_viewport().get_texture().get_image()
	var p := "%s/%03d_%s.png" % [shots_dir, shot_n, tag]
	img.save_png(p)
	shot_n += 1
	print("[autotest] shot ", p)

func _process(delta: float) -> void:
	t += delta
	frames += 1
	if delta > 0.05:
		slow_frames += 1
	if t > duration:
		print("[autotest] done frames=%d slow=%d fps=%d score=%d kills=%d label=%s" % [frames, slow_frames, Engine.get_frames_per_second(), Run.score, Run.kills, Run.label()])
		_shot("end")
		get_tree().quit()
		return
	if mode == "menu":
		_menu_tour(delta)
		return
	var g = main.current
	if g == null or not g.has_method("start_section"):
		return
	shot_t += delta
	if shot_t >= shot_every:
		shot_t = 0.0
		_shot("run")
	if g.overlay:
		_handle_overlay(g)
		return
	var p = g.player
	if p == null or p.dead:
		_release_all()
		return
	p.god = god
	_drive(g, p, delta)

func _handle_overlay(g) -> void:
	_release_all()
	var o = g.overlay
	if o.has_method("_pick") and not o.done:
		_shot("cards")
		o._pick(o.options[0])
	elif o.get("victory_pending"):
		_shot("victory")
		o.finish_run.emit()
	elif o.has_signal("retry") and not game_over_seen:
		game_over_seen = true
		_shot("gameover")
		print("[autotest] game over: ", Run.label(), " score ", Run.score)
		duration = minf(duration, t + 1.0)

func _press(a: String, on: bool) -> void:
	if on:
		Input.action_press(a)
	else:
		Input.action_release(a)

func _release_all() -> void:
	for a in ["move_left", "move_right", "jump", "shoot", "dash", "move_down", "move_up"]:
		Input.action_release(a)

func _drive(g, p, delta: float) -> void:
	var pp: Vector2 = p.global_position
	var target = g.nearest_enemy(pp, 700.0)
	var dir := 1.0
	if g.boss and is_instance_valid(g.boss) and not g.boss.dead:
		target = g.boss
		dir = 1.0 if sin(t * 0.7) > 0.0 else -1.0
	elif g.goal and g.level.get("boss", false):
		dir = signf(g.goal.position.x - pp.x)
	if target:
		p.aim_override = (target.global_position - (pp + Vector2(0, -12))).normalized()
	else:
		p.aim_override = Vector2(1, -0.1)
	_press("move_right", dir > 0.0)
	_press("move_left", dir < 0.0)
	_press("shoot", true)
	# Springen bei Wand, Abgrund oder zufällig
	var space = p.get_world_2d().direct_space_state
	var ahead := pp + Vector2(dir * 40.0, 0)
	var q := PhysicsRayQueryParameters2D.create(ahead, ahead + Vector2(0, 120), 1 | 8)
	var gap: bool = space.intersect_ray(q).is_empty()
	var q2 := PhysicsRayQueryParameters2D.create(pp, pp + Vector2(dir * 50.0, 0), 1)
	var wall: bool = not space.intersect_ray(q2).is_empty()
	if absf(pp.x - last_x) < 1.0:
		stuck_t += delta
	else:
		stuck_t = 0.0
	last_x = pp.x
	if jump_hold > 0.0:
		jump_hold -= delta
		if jump_hold <= 0.0:
			_press("jump", false)
	elif (gap or wall or stuck_t > 0.4 or randf() < 0.004) and p.is_on_floor():
		_press("jump", true)
		jump_hold = 0.35
	elif not p.is_on_floor() and gap and p.velocity.y > 0.0 and randf() < 0.05:
		_press("jump", true)
		jump_hold = 0.2
	# neue Moves gelegentlich ausprobieren: Rutschen, Ground-Slam, Dash nach oben
	var slide: bool = p.is_on_floor() and absf(p.velocity.x) > 250.0 and randf() < 0.015
	var slam: bool = not p.is_on_floor() and p.velocity.y < 0.0 and randf() < 0.01
	_press("move_down", slide or slam)
	_press("move_up", randf() < 0.02)
	_press("dash", slam or (gap and not p.is_on_floor() and p.velocity.y > 100.0) or randf() < 0.004)

func _menu_tour(delta: float) -> void:
	shot_t += delta
	if shot_t < 1.2:
		return
	shot_t = 0.0
	var m = main.current
	match menu_step:
		0: _shot("menu_home")
		1: m.show_setup()
		2: _shot("menu_setup")
		3: m.show_workshop()
		4: _shot("menu_workshop")
		5: m.show_achievements()
		6: _shot("menu_achievements")
		7: m.show_stats()
		8: _shot("menu_stats")
		9: m.show_options()
		10: _shot("menu_options")
		11:
			duration = t
	menu_step += 1
