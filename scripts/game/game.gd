# Spielszene: baut den Abschnitt, steuert Kamera, Kampf-Ereignisse, Kombo, Checkpoints, Ziel, Tod und Übergänge.
extends Node2D

const Data = preload("res://scripts/core/data.gd")
const Neon = preload("res://scripts/core/neon.gd")
const LevelGen = preload("res://scripts/world/level_gen.gd")
const TerrainVis = preload("res://scripts/world/terrain_vis.gd")
const Background = preload("res://scripts/world/background.gd")
const Props = preload("res://scripts/world/props.gd")
const Fx = preload("res://scripts/game/fx.gd")
const Bullets = preload("res://scripts/game/bullets.gd")
const Pickups = preload("res://scripts/game/pickups.gd")
const Player = preload("res://scripts/player/player.gd")
const Hud = preload("res://scripts/ui/hud.gd")
const CardScreen = preload("res://scripts/ui/card_screen.gd")
const PauseMenu = preload("res://scripts/ui/pause_menu.gd")
const GameOver = preload("res://scripts/ui/game_over.gd")
const Cursor = preload("res://scripts/ui/cursor.gd")
const ENEMIES := {
	"walker": preload("res://scripts/enemies/walker.gd"),
	"brute": preload("res://scripts/enemies/brute.gd"),
	"gunner": preload("res://scripts/enemies/gunner.gd"),
	"sniper": preload("res://scripts/enemies/sniper.gd"),
	"turret": preload("res://scripts/enemies/turret.gd"),
	"drone": preload("res://scripts/enemies/drone.gd"),
	"boss": preload("res://scripts/enemies/boss.gd"),
}

signal quit_to_menu
signal restart_run

var main  # main.gd
var pal: Dictionary
var level: Dictionary
var world: Node2D
var terrain: Node2D
var enemies_node: Node2D
var props_node: Node2D
var player
var fx
var bullets
var pickups
var camera: Camera2D
var bg_layer: CanvasLayer
var bg
var hud_layer: CanvasLayer
var hud
var overlay_layer: CanvasLayer
var overlay: Control
var cursor_layer: CanvasLayer
var cursor
var kill_y := 2000.0
var state := "play"
var trauma := 0.0
var cam_pos := Vector2.ZERO
var combo_t := 0.0
var checkpoints: Array = []
var goal
var boss
var last_checkpoint := Vector2.ZERO
var hitstop_active := false
var base_time_scale := 1.0
var shake_scale := 1.0
var enemies: Array = []

func _ready() -> void:
	bg_layer = CanvasLayer.new()
	bg_layer.layer = -10
	add_child(bg_layer)
	bg = Background.new()
	bg_layer.add_child(bg)
	world = Node2D.new()
	add_child(world)
	camera = Camera2D.new()
	camera.zoom = Vector2(1.2, 1.2)
	add_child(camera)
	camera.make_current()
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 5
	add_child(hud_layer)
	hud = Hud.new()
	hud.game = self
	hud_layer.add_child(hud)
	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 20
	overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay_layer)
	cursor_layer = CanvasLayer.new()
	cursor_layer.layer = 40
	cursor_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(cursor_layer)
	cursor = Cursor.new()
	cursor.game = self
	cursor_layer.add_child(cursor)
	Save.achievement_unlocked.connect(_on_achievement)
	start_section()

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Save.achievement_unlocked.is_connected(_on_achievement):
		Save.achievement_unlocked.disconnect(_on_achievement)

# --- Aufbau ---
func start_section() -> void:
	for c in world.get_children():
		world.remove_child(c)
		c.queue_free()
	enemies.clear()
	checkpoints.clear()
	goal = null
	boss = null
	state = "play"
	combo_t = 0.0
	Run.combo = 0
	Run.section_damage = 0.0
	Run.section_time = 0.0
	shake_scale = Save.setting("shake")
	pal = Data.PALETTES[Run.palette_index()]
	var gen := LevelGen.new()
	var is_boss := Run.is_boss()
	var tutorial := Run.world == 0 and Run.section == 0 and Run.loop == 0 and int(Save.stat("runs")) <= 3
	var length := 4200.0 + Run.world * 500.0 + Run.section * 350.0 + Run.loop * 600.0
	level = gen.generate(Run.section_seed(), Run.difficulty(), length, is_boss, tutorial, Run.stats["enemy_count"])
	kill_y = level["kill_y"]
	terrain = Node2D.new()
	world.add_child(terrain)
	props_node = Node2D.new()
	world.add_child(props_node)
	pickups = Pickups.new()
	pickups.game = self
	world.add_child(pickups)
	enemies_node = Node2D.new()
	world.add_child(enemies_node)
	_build_terrain()
	player = Player.new()
	player.game = self
	player.color = Save.skin_color()
	player.position = level["start"]
	player.died.connect(_on_player_died)
	world.add_child(player)
	bullets = Bullets.new()
	bullets.game = self
	world.add_child(bullets)
	fx = Fx.new()
	fx.show_numbers = Save.setting("dmg_numbers")
	world.add_child(fx)
	last_checkpoint = level["start"]
	for s in level["spawns"]:
		spawn_enemy(s["kind"], s["pos"])
	for cpos in level["coins"]:
		pickups.place_coin(cpos)
	for cp in level["checkpoints"]:
		var n = Props.new()
		n.kind = "checkpoint"
		n.pal = pal
		n.position = cp
		props_node.add_child(n)
		checkpoints.append(n)
	for h in level["hints"]:
		var n = Props.new()
		n.kind = "hint"
		n.pal = pal
		n.text = L.t(h["key"])
		n.position = h["pos"]
		props_node.add_child(n)
	if is_boss:
		boss = spawn_enemy("boss", level["boss_pos"])
		boss.setup_boss(level["arena"], Run.world + Run.loop * 3, pal["accent"])
		Sfx.music("boss")
		hud.banner(L.t("boss_title"), L.t("boss_sub"), pal["enemy"])
		Sfx.play("boss_intro")
	else:
		_spawn_goal(level["goal"])
		Sfx.music("run")
		hud.banner(L.t(pal["name"]), Run.label(), pal["accent"])
	camera.limit_left = -470
	camera.limit_right = int(level["length"] + 20.0)
	camera.limit_bottom = int(LevelGen.BASE_Y + 330.0)
	camera.limit_top = -4000
	cam_pos = player.position + Vector2(200, -60)
	camera.global_position = cam_pos
	camera.reset_smoothing()
	bg.setup(pal, Run.section_seed())
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	hud.refresh_section()

func _spawn_goal(pos: Vector2) -> void:
	goal = Props.new()
	goal.kind = "goal"
	goal.pal = pal
	goal.position = pos
	props_node.add_child(goal)

func _build_terrain() -> void:
	var bottom: float = level["bottom"]
	var i := 0
	for pts in level["ground"]:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var poly := CollisionPolygon2D.new()
		var full: PackedVector2Array = pts.duplicate()
		full.append(Vector2(pts[pts.size() - 1].x, bottom))
		full.append(Vector2(pts[0].x, bottom))
		poly.polygon = full
		body.add_child(poly)
		var vis := TerrainVis.new()
		vis.setup_ground(pts, bottom, pal, Run.section_seed() + i)
		body.add_child(vis)
		terrain.add_child(body)
		i += 1
	for b in level["blocks"]:
		var r: Rect2 = b["rect"]
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = r.size
		cs.shape = shape
		cs.position = r.get_center()
		body.add_child(cs)
		var vis := TerrainVis.new()
		vis.setup_rect(b["kind"], r, pal, Run.section_seed() + i)
		body.add_child(vis)
		terrain.add_child(body)
		i += 1
	for r in level["ledges"]:
		var body := StaticBody2D.new()
		body.collision_layer = 8
		body.collision_mask = 0
		body.add_to_group("ledge")
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(r.size.x, 12.0)
		cs.shape = shape
		cs.position = Vector2(r.get_center().x, r.position.y + 6.0)
		cs.one_way_collision = true
		cs.one_way_collision_margin = 6.0
		body.add_child(cs)
		var vis := TerrainVis.new()
		vis.setup_rect("ledge", r, pal, Run.section_seed() + i)
		body.add_child(vis)
		terrain.add_child(body)
		i += 1
	for dcr in level["decor"]:
		var vis := TerrainVis.new()
		vis.setup_decor(dcr["kind"], dcr["pos"], pal, Run.section_seed() + i)
		terrain.add_child(vis)
		i += 1

func spawn_enemy(kind: String, pos: Vector2):
	if not ENEMIES.has(kind):
		return null
	var e = ENEMIES[kind].new()
	var c: Color = pal["enemy"]
	if kind == "sniper":
		c = Color(0.9, 0.4, 1.0)
	elif kind == "drone":
		c = pal["enemy"].lerp(Color(1, 0.6, 0.2), 0.35)
	e.setup(self, Run.difficulty(), c)
	if e.uses_gravity:
		pos.y += 27.0 - e.shape_size.y * 0.5
	e.position = pos
	enemies_node.add_child(e)
	enemies.append(e)
	return e

# --- Laufende Logik ---
func _physics_process(delta: float) -> void:
	if player == null:
		return
	if state == "play" or state == "boss_dead":
		Run.time += delta
		Run.section_time += delta
	if Run.combo > 0:
		combo_t -= delta
		if combo_t <= 0.0:
			Run.combo = 0
	if player.dead:
		return
	var pp: Vector2 = player.global_position
	for cp in checkpoints:
		if not cp.activated and pp.x >= cp.position.x - 10.0:
			cp.activate()
			last_checkpoint = cp.position + Vector2(0, -40)
			hud.banner(L.t("checkpoint"), "", pal["accent"], 1.4)
			Sfx.play("checkpoint")
			player.heal(player.max_hp() * 0.2 * Run.stats["heal_mult"])
			Run.add_score(250)
			fx.ring(cp.position + Vector2(0, -126), pal["accent"], 80.0, 0.6)
	if goal and state in ["play", "boss_dead"] and absf(pp.x - goal.position.x) < 40.0 and pp.y > goal.position.y - 220.0:
		_section_clear()
	if pp.y > kill_y and state == "play":
		player.respawn_safe(15.0 * (1.0 + 0.1 * Run.difficulty()))
	if is_instance_valid(boss) and not boss.dead:
		# Spieler bleibt in der Arena
		pass

func _process(delta: float) -> void:
	if player == null:
		return
	var rdelta := delta / maxf(Engine.time_scale, 0.001)
	trauma = maxf(0.0, trauma - rdelta * 1.6)
	if not player.dead:
		var look := Vector2(player.aim.x * 110.0, -55.0 + player.aim.y * 50.0) + Vector2(player.velocity.x * 0.15, 0)
		var target: Vector2 = player.global_position + look
		cam_pos = cam_pos.lerp(target, clampf(7.0 * rdelta, 0.0, 1.0))
	var sh := trauma * trauma * shake_scale
	var t := Time.get_ticks_msec() * 0.001
	var offset := Vector2(sin(t * 47.0) + sin(t * 31.0) * 0.5, cos(t * 53.0) + sin(t * 29.0) * 0.5) * sh * 14.0
	camera.global_position = cam_pos + offset
	camera.rotation = sin(t * 23.0) * sh * 0.015

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and state == "play" and overlay == null:
		open_pause()
		get_viewport().set_input_as_handled()

func shake(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)

func hitstop(dur: float) -> void:
	if hitstop_active:
		return
	hitstop_active = true
	Engine.time_scale = 0.05
	await get_tree().create_timer(dur, true, false, true).timeout
	Engine.time_scale = base_time_scale
	hitstop_active = false

func set_slowmo(v: float) -> void:
	base_time_scale = v
	if not hitstop_active:
		Engine.time_scale = v

# --- Kampf-Hilfen ---
func alive_enemies() -> Array:
	var out: Array = []
	for e in enemies:
		if is_instance_valid(e) and not e.dead:
			out.append(e)
	enemies = out
	return out

func enemies_near(pos: Vector2, r: float) -> Array:
	var out: Array = []
	for e in enemies:
		if is_instance_valid(e) and not e.dead and e.global_position.distance_to(pos) < r + e.radius:
			out.append(e)
	return out

func nearest_enemy(pos: Vector2, max_d: float):
	var best = null
	var bd := max_d
	for e in enemies:
		if is_instance_valid(e) and not e.dead and e.active:
			var d: float = e.global_position.distance_to(pos)
			if d < bd:
				bd = d
				best = e
	return best

func count_kind(kind: String) -> int:
	var n := 0
	for e in enemies:
		if is_instance_valid(e) and not e.dead and e.kind == kind:
			n += 1
	return n

func explode(pos: Vector2, radius: float, dmg: float) -> void:
	for e in enemies_near(pos, radius):
		var d: float = e.global_position.distance_to(pos)
		var k := 1.0 - 0.5 * clampf(d / radius, 0.0, 1.0)
		e.take_damage(dmg * k, (e.global_position - pos).normalized(), false)
	fx.explosion(pos, Color(1.0, 0.6, 0.25), radius / 90.0)
	shake(0.25)
	Sfx.play_at("explosion", pos, -4.0)

func chain_lightning(from_enemy, dmg: float) -> void:
	var src: Vector2 = from_enemy.global_position
	var hits := 0
	var used := [from_enemy]
	var cur := src
	while hits < 2:
		var best = null
		var bd := 240.0
		for e in enemies:
			if is_instance_valid(e) and not e.dead and not e in used:
				var d: float = e.global_position.distance_to(cur)
				if d < bd:
					bd = d
					best = e
		if best == null:
			break
		used.append(best)
		fx.bolt(cur, best.global_position, Color(0.6, 0.85, 1.0))
		var nxt: Vector2 = best.global_position
		best.take_damage(dmg, Vector2.ZERO, false)
		cur = nxt
		hits += 1
	if hits > 0:
		Sfx.play("lightning", -6.0)

# --- Ereignisse ---
func on_enemy_killed(e, reward: bool) -> void:
	var pos: Vector2 = e.global_position
	var big: bool = e.kind in ["brute", "turret"]
	fx.explosion(pos, e.col, 1.6 if big else 0.9)
	Sfx.play_at("enemy_die", pos, -3.0)
	shake(0.22 if big else 0.1)
	if e.is_boss:
		_boss_defeated(e)
		return
	if not reward:
		return
	var v := Run.add_kill(e.score_value)
	fx.text(pos + Vector2(0, -30), "+%d" % v, Color(1, 1, 1, 0.9), 18.0, 0.9)
	pickups.drop_coins(pos, e.credit_value)
	if randf() < 0.07 and Run.stats["heal_mult"] > 0.0:
		pickups.drop_heal(pos)
	if Run.stats["lifesteal"] > 0.0:
		player.heal(Run.stats["lifesteal"])
	combo_t = Run.stats["combo_window"]
	if Run.combo > 0 and Run.combo % 10 == 0:
		Sfx.play("combo", -2.0, 1.0 + minf(Run.combo / 10.0, 5.0) * 0.08)
		hud.combo_pop()

func on_player_hurt(_dmg: float) -> void:
	Run.combo = 0
	hud.flash_damage()

func boss_phase2() -> void:
	hud.banner(L.t("boss_phase2"), "", pal["enemy"], 1.2)
	shake(0.6)
	Sfx.play("boss_intro", 0.0, 1.2)

func _boss_defeated(b) -> void:
	state = "boss_dead"
	Run.bosses += 1
	var v := Run.add_kill(b.score_value)
	if b.fight_time < 90.0:
		Run.achievement("boss_fast")
	pickups.drop_coins(b.global_position, b.credit_value)
	pickups.drop_heal(b.global_position)
	pickups.drop_heal(b.global_position + Vector2(30, 0))
	bullets.clear()
	set_slowmo(0.3)
	shake(1.0)
	Sfx.play("big_explosion")
	for i in 5:
		fx.explosion(b.global_position + Vector2(randf_range(-60, 60), randf_range(-60, 60)), [b.col, pal["accent"], Color.WHITE][i % 3], 2.2)
	fx.shockwave(b.global_position, pal["accent"], 500.0)
	hud.banner(L.t("boss_down"), "+%d" % v, pal["accent"], 2.0)
	await get_tree().create_timer(1.2, true, false, true).timeout
	set_slowmo(1.0)
	if is_inside_tree():
		_spawn_goal(level["goal"])

func _section_clear() -> void:
	state = "clear"
	player.frozen = true
	player.velocity.x = 0.0
	Run.hp = player.hp
	var time_bonus := maxi(0, int(1500 - Run.section_time * 10.0))
	Run.add_score(500 + time_bonus)
	if Run.section_damage <= 0.0:
		Run.achievement("untouched")
	Sfx.play("clear")
	fx.shockwave(goal.position + Vector2(0, -60), pal["ground"], 400.0)
	fx.sparks(player.global_position, pal["ground"], 30, 600.0)
	hud.banner(L.t("section_clear"), "+%d" % (500 + time_bonus), pal["ground"], 1.6)
	await get_tree().create_timer(1.5).timeout
	if not is_inside_tree():
		return
	var was_boss := Run.is_boss()
	if was_boss:
		Run.hp = minf(Run.stats["max_hp"], Run.hp + Run.stats["max_hp"] * 0.3 * maxf(Run.stats["heal_mult"], 0.0))
	open_cards(1 if was_boss else 0)

func open_cards(min_rarity: int) -> void:
	var cs = CardScreen.new()
	cs.min_rarity = min_rarity
	cs.chosen.connect(_on_card_chosen)
	_show_overlay(cs)

func _on_card_chosen(id: String) -> void:
	Run.hp = player.hp if not player.dead else Run.hp
	Run.apply_card(id)
	Sfx.play("card")
	_close_overlay()
	var victory := Run.advance()
	if victory:
		_show_victory()
		return
	_next_section()

func _next_section() -> void:
	if main:
		main.fade(func(): start_section())
	else:
		start_section()

func _show_victory() -> void:
	var go = GameOver.new()
	go.victory_pending = true
	go.continue_endless.connect(func():
		_close_overlay()
		Run.start_endless()
		_next_section())
	go.finish_run.connect(func():
		_close_overlay()
		_end_run(true))
	_show_overlay(go)

func _on_player_died() -> void:
	Sfx.play("big_explosion")
	shake(1.0)
	Run.combo = 0
	if Run.revives_left > 0:
		Run.revives_left -= 1
		set_slowmo(0.35)
		await get_tree().create_timer(1.0, true, false, true).timeout
		set_slowmo(1.0)
		if not is_inside_tree():
			return
		var at := last_checkpoint if not Run.is_boss() else level["start"]
		player.revive(at, 0.5)
		cam_pos = at
		hud.banner(L.t("second_chance"), "", pal["accent"], 1.5)
		return
	state = "dead"
	set_slowmo(0.3)
	Sfx.stop_music(1.5)
	await get_tree().create_timer(1.6, true, false, true).timeout
	set_slowmo(1.0)
	if is_inside_tree():
		_end_run(Run.endless)

func _end_run(victory: bool) -> void:
	state = "over"
	Run.hp = player.hp
	var summary := Run.finish(victory)
	Sfx.play("clear" if victory else "game_over")
	var go = GameOver.new()
	go.summary = summary
	go.retry.connect(func(): restart_run.emit())
	go.to_menu.connect(func(): quit_to_menu.emit())
	_show_overlay(go)

func give_up() -> void:
	_close_overlay()
	_end_run(false)

# --- Overlays ---
func open_pause() -> void:
	var pm = PauseMenu.new()
	pm.resume.connect(_close_overlay)
	pm.give_up.connect(give_up)
	pm.to_menu.connect(func():
		Run.finish(false)
		quit_to_menu.emit())
	_show_overlay(pm)
	Sfx.play("ui_select")

func _show_overlay(c: Control) -> void:
	if overlay:
		overlay.queue_free()
	overlay = c
	overlay_layer.add_child(c)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _close_overlay() -> void:
	if overlay:
		overlay.queue_free()
		overlay = null
	get_tree().paused = false
	if state in ["play", "boss_dead"]:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func _on_achievement(id: String) -> void:
	hud.achievement_toast(id)
	Sfx.play("achievement", -3.0)
