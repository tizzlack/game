# Spielszene: baut den Abschnitt, steuert Kamera, Kampf-Ereignisse, Kombo, Checkpoints, Ziel, Tod und Übergänge.
extends Node2D

const Data = preload("res://scripts/core/data.gd")
const Neon = preload("res://scripts/core/neon.gd")
const LevelGen = preload("res://scripts/world/level_gen.gd")
const TerrainVis = preload("res://scripts/world/terrain_vis.gd")
const TerrainChunk = preload("res://scripts/world/terrain_chunk.gd")
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
const RemotePlayer = preload("res://scripts/player/remote_player.gd")
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
var chunks: Array = []
var carve_rng := RandomNumberGenerator.new()
var zoom_kick := 0.0
var speed_zoom := 0.0
const BASE_ZOOM := 1.2
# --- Multiplayer ---
const ENEMY_STRIDE := 14
const STATE_CODES := {"idle": 0, "aim": 1, "fire": 2, "windup": 3, "charge": 4, "walk": 5, "intro": 6,
	"ring": 7, "volley": 8, "laser": 9, "summon": 10, "rain": 11}
var versus := false
var remotes := {}  # peer_id -> RemotePlayer
var enemies_by_id := {}
var next_enemy_id := 0
var net_send_t := 0.0
var snap_t := 0.0
var clear_requested := false
var cards_done := {}
var pvp_scores := {}
var pvp_time := 180.0
var pvp_over := false
var last_attacker := 0
var killfeed: Array = []
const PVP_KILLS := 10

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
	if Net.active:
		Net.game = self
		versus = Run.net_mode == "versus"
		if versus:
			for id in Net.players:
				pvp_scores[id] = 0
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
	enemies_by_id.clear()
	next_enemy_id = 0
	remotes.clear()
	clear_requested = false
	cards_done.clear()
	chunks.clear()
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
	var tutorial: bool = Run.world == 0 and Run.section == 0 and Run.loop == 0 and int(Save.stat("runs")) <= 3 and not Net.active
	var length := 4200.0 + Run.world * 500.0 + Run.section * 350.0 + Run.loop * 600.0
	if versus:
		is_boss = false
		level = gen.generate_versus(Run.section_seed())
	else:
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
	if versus:
		player.position = _pvp_spawn_point()
	player.died.connect(_on_player_died)
	world.add_child(player)
	if Net.active:
		for id in Net.players:
			if id != Net.my_id():
				_add_remote(id)
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
		n.text = L.t(h["key"] + ("_pad" if Controls.using_gamepad else ""))
		n.position = h["pos"]
		props_node.add_child(n)
	if versus:
		Sfx.music("boss")
		hud.banner(L.t("versus"), L.t("versus_sub") % PVP_KILLS, pal["enemy"])
	elif is_boss:
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

func _activate_checkpoint(i: int) -> void:
	var cp = checkpoints[i]
	if cp.activated:
		return
	cp.activate()
	last_checkpoint = cp.position + Vector2(0, -40)
	hud.banner(L.t("checkpoint"), "", pal["accent"], 1.4)
	Sfx.play("checkpoint")
	if player.dead:
		if Net.active and not versus:
			player.revive(last_checkpoint, 0.4)
	else:
		player.heal(player.max_hp() * 0.2 * Run.stats["heal_mult"])
	Run.add_score(250)
	fx.ring(cp.position + Vector2(0, -126), pal["accent"], 80.0, 0.6)

func _spawn_goal(pos: Vector2) -> void:
	goal = Props.new()
	goal.kind = "goal"
	goal.pal = pal
	goal.position = pos
	props_node.add_child(goal)

func _build_terrain() -> void:
	var bottom: float = level["bottom"]
	var i := 0
	# Boden in Scheiben von max. 360 px schneiden, damit Löcher die Polygone klein halten
	for pts in level["ground"]:
		var x0: float = pts[0].x
		var x_end: float = pts[pts.size() - 1].x
		while x0 < x_end - 1.0:
			var x1 := minf(x0 + 360.0, x_end)
			if x_end - x1 < 80.0:
				x1 = x_end
			var top := PackedVector2Array()
			top.append(Vector2(x0, _y_on(pts, x0)))
			for p in pts:
				if p.x > x0 + 0.5 and p.x < x1 - 0.5:
					top.append(p)
			top.append(Vector2(x1, _y_on(pts, x1)))
			var poly := top.duplicate()
			poly.append(Vector2(x1, bottom))
			poly.append(Vector2(x0, bottom))
			var seam_xs: Array = []
			if x0 > pts[0].x + 0.5:
				seam_xs.append(x0)
			if x1 < x_end - 0.5:
				seam_xs.append(x1)
			_add_chunk("ground", poly, Run.section_seed() + i, seam_xs)
			i += 1
			x0 = x1
	for b in level["blocks"]:
		var r: Rect2 = b["rect"]
		if b["kind"] in ["building", "box"]:
			var poly := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
			_add_chunk(b["kind"], poly, Run.section_seed() + i, [])
			i += 1
			continue
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

func _add_chunk(kind: String, poly: PackedVector2Array, s: int, seam_xs: Array) -> void:
	var c = TerrainChunk.new()
	c.setup(kind, poly, pal, s, seam_xs)
	terrain.add_child(c)
	chunks.append(c)

static func _y_on(pts: PackedVector2Array, px: float) -> float:
	for i in range(1, pts.size()):
		if px <= pts[i].x:
			var a := pts[i - 1]
			var b := pts[i]
			return lerpf(a.y, b.y, 0.0 if b.x - a.x < 0.01 else (px - a.x) / (b.x - a.x))
	return pts[pts.size() - 1].y

# Stanzt ein Loch ins Gelände und lässt Splitter fliegen
func carve(pos: Vector2, radius: float, normal: Vector2 = Vector2.UP, seed_value: int = -1, from_net: bool = false) -> void:
	if radius <= 0.0:
		return
	if seed_value < 0:
		seed_value = randi()
	if Net.active and not from_net:
		Net.carve.rpc(pos, radius, normal, seed_value)
	carve_rng.seed = seed_value
	var shape = TerrainChunk.stair_shape(pos, radius, carve_rng)
	var rect := Rect2(pos - Vector2(radius, radius) * 1.2, Vector2(radius, radius) * 2.4)
	var hit_chunk = null
	for c in chunks:
		if c.carve(shape, rect):
			hit_chunk = c
	if hit_chunk:
		var col: Color = hit_chunk.edge_color(Vector2.ZERO, Vector2(1, 0) if absf(normal.y) > 0.5 else Vector2(0, 1))
		fx.chips(pos, col, int(clampf(radius * 0.8, 4.0, 24.0)), normal)

func spawn_enemy(kind: String, pos: Vector2, broadcast: bool = false, forced_id: int = -1):
	if not ENEMIES.has(kind):
		return null
	var e = ENEMIES[kind].new()
	e.net_id = forced_id if forced_id >= 0 else next_enemy_id
	next_enemy_id = maxi(next_enemy_id, e.net_id + 1)
	e.puppet = Net.active and not Net.is_host
	enemies_by_id[e.net_id] = e
	if broadcast and Net.active and Net.is_host:
		Net.e_spawn.rpc(kind, pos, e.net_id)
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
	if Net.active:
		_net_tick(delta)
	if player.dead:
		return
	var pp: Vector2 = player.global_position
	for i in checkpoints.size():
		var cp = checkpoints[i]
		if not cp.activated and pp.x >= cp.position.x - 10.0:
			_activate_checkpoint(i)
			if Net.active:
				Net.cp_reached.rpc(i)
	if goal and state in ["play", "boss_dead"] and absf(pp.x - goal.position.x) < 40.0 and pp.y > goal.position.y - 220.0:
		if not Net.active:
			_section_clear()
		elif not clear_requested:
			clear_requested = true
			if Net.is_host:
				Net.sec_clear.rpc()
			else:
				Net.req_clear.rpc_id(1)
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
	var follow = player
	if player.dead and Net.active:
		for r in remotes.values():
			if is_instance_valid(r) and not r.dead and r.has_state:
				follow = r
				break
	if follow != player:
		cam_pos = cam_pos.lerp(follow.global_position + Vector2(0, -55), clampf(5.0 * rdelta, 0.0, 1.0))
	elif not player.dead:
		var look := Vector2(player.aim.x * 110.0, -55.0 + player.aim.y * 50.0) + Vector2(player.velocity.x * 0.22, player.velocity.y * 0.06)
		var target: Vector2 = player.global_position + look
		if is_instance_valid(boss) and not boss.dead:
			# Bosskampf: Spieler und Boss gemeinsam im Bild
			target = target.lerp(boss.global_position, 0.38)
		cam_pos = cam_pos.lerp(target, clampf(7.0 * rdelta, 0.0, 1.0))
	var sh := trauma * trauma * shake_scale
	var t := Time.get_ticks_msec() * 0.001
	var offset := Vector2(sin(t * 47.0) + sin(t * 31.0) * 0.5, cos(t * 53.0) + sin(t * 29.0) * 0.5) * sh * 14.0
	camera.global_position = cam_pos + offset
	camera.rotation = sin(t * 23.0) * sh * 0.015
	zoom_kick = lerpf(zoom_kick, 0.0, clampf(6.0 * rdelta, 0.0, 1.0))
	# bei hohem Tempo leicht herauszoomen und weiter vorausschauen
	var spd := clampf((player.velocity.length() - 300.0) / 700.0, 0.0, 1.0)
	speed_zoom = lerpf(speed_zoom, spd, clampf(2.5 * rdelta, 0.0, 1.0))
	var boss_zoom := 0.12 if is_instance_valid(boss) and not boss.dead else 0.0
	camera.zoom = Vector2.ONE * BASE_ZOOM * (1.0 + zoom_kick - speed_zoom * 0.1 - boss_zoom)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and state == "play" and overlay == null:
		open_pause()
		get_viewport().set_input_as_handled()

# Controller-Vibration (stark 0..1, Dauer in Sekunden)
func rumble(strength: float, duration: float) -> void:
	Controls.rumble(strength, duration)

func shake(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)

# Kurzer Zoom-Stoß der Kamera und Bildschirm-Verzerrung
func punch(amount: float, aberration: float = 0.0) -> void:
	zoom_kick = minf(0.12, zoom_kick + amount)
	if aberration > 0.0 and main and main.post:
		main.post.kick(aberration)

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
	if versus:
		for r in remotes.values():
			if is_instance_valid(r) and not r.dead and r.global_position.distance_to(pos) < radius + 14.0:
				Net.pvp_hit.rpc_id(r.peer_id, dmg * 0.7, pos)
	if Net.active:
		Net.fx_explosion.rpc(pos, radius)
	fx.explosion(pos, Color(1.0, 0.6, 0.25), radius / 90.0)
	carve(pos, radius * 0.42)
	shake(0.25)
	punch(0.015)
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
# Nächstes lebendes Ziel für Gegner (eigener Spieler oder Mitspieler)
func target_for(pos: Vector2):
	var best = player
	var bd := INF
	if player and not player.dead:
		bd = player.global_position.distance_squared_to(pos)
	for r in remotes.values():
		if is_instance_valid(r) and r.has_state and not r.dead:
			var d: float = r.global_position.distance_squared_to(pos)
			if d < bd:
				bd = d
				best = r
	return best

func on_enemy_killed(e, reward: bool, killer: int = -1) -> void:
	if killer < 0:
		killer = e.last_hitter if Net.active else 1
	if Net.active and Net.is_host:
		Net.e_died.rpc(e.net_id, killer, reward)
	enemies_by_id.erase(e.net_id)
	var mine := killer == Net.my_id() or not Net.active
	var pos: Vector2 = e.global_position
	var big: bool = e.kind in ["brute", "turret"]
	fx.death_burst(pos, e.col, 1.4 if big else 1.0)
	Sfx.play_at("enemy_die", pos, -3.0)
	shake(0.22 if big else 0.1)
	if big:
		punch(0.02, 0.2)
	if e.is_boss:
		_boss_defeated(e)
		return
	if not reward:
		return
	pickups.drop_coins(pos, e.credit_value)
	if not mine:
		return
	var v := Run.add_kill(e.score_value)
	if player and not player.dead:
		player.on_kill()
	fx.text(pos + Vector2(0, -30), "+%d" % v, Color(1, 1, 1, 0.9), 18.0, 0.9)
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
	punch(0.03, 0.9)

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
	punch(0.1, 1.0)
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
	if Net.active:
		# auf die anderen warten, der Host startet dann für alle den nächsten Abschnitt
		hud.banner(L.t("net_waiting"), "", pal["accent"], 30.0)
		if Net.is_host:
			net_card_done(1)
		else:
			Net.card_done.rpc_id(1)
		return
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
	if versus:
		Net.pvp_death.rpc(last_attacker)
		await get_tree().create_timer(2.0).timeout
		if is_inside_tree() and not pvp_over:
			player.revive(_pvp_spawn_point(), 1.0)
		return
	if Run.revives_left > 0:
		Run.revives_left -= 1
		set_slowmo(0.35)
		await get_tree().create_timer(1.0, true, false, true).timeout
		set_slowmo(1.0)
		if not is_inside_tree():
			return
		var at: Vector2 = last_checkpoint if not Run.is_boss() else level["start"]
		player.revive(at, 0.5)
		cam_pos = at
		hud.banner(L.t("second_chance"), "", pal["accent"], 1.5)
		return
	if Net.active:
		# Koop: zuschauen, bis ein Mitspieler den nächsten Checkpoint erreicht
		hud.banner(L.t("net_spectate"), "", pal["accent"], 3.0)
		Run.hp = Run.stats["max_hp"] * 0.5
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
	if Net.active:
		go.net_mode = true
		go.retry.connect(func(): back_to_lobby())
		go.to_menu.connect(func(): back_to_lobby())
	else:
		go.retry.connect(func(): restart_run.emit())
		go.to_menu.connect(func(): quit_to_menu.emit())
	_show_overlay(go)

signal to_lobby

func back_to_lobby() -> void:
	Net.back_to_lobby()
	to_lobby.emit()

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
		if Net.active:
			Net.leave()
		quit_to_menu.emit())
	_show_overlay(pm)
	Sfx.play("ui_select")

func _show_overlay(c: Control) -> void:
	if overlay:
		overlay.queue_free()
	overlay = c
	overlay_layer.add_child(c)
	get_tree().paused = not Net.active  # im Multiplayer läuft das Spiel weiter
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

# =====================================================================
# Multiplayer
# =====================================================================
func _add_remote(id: int) -> void:
	if remotes.has(id) or not Net.players.has(id):
		return
	var r = RemotePlayer.new()
	r.setup(self, id, Net.players[id], versus)
	world.add_child(r)
	remotes[id] = r

func _pvp_spawn_point() -> Vector2:
	var pts: Array = level.get("pvp_spawns", [])
	if pts.is_empty():
		return level["start"]
	var best: Vector2 = pts[randi() % pts.size()]
	var best_d := -1.0
	for i in 6:
		var p: Vector2 = pts[randi() % pts.size()]
		var d := INF
		for r in remotes.values():
			if is_instance_valid(r) and not r.dead:
				d = minf(d, r.global_position.distance_to(p))
		if d > best_d:
			best_d = d
			best = p
	return best

func _player_flags() -> int:
	var f := 0
	if player.is_on_floor():
		f |= RemotePlayer.F.FLOOR
	if player.slide_t > 0.0:
		f |= RemotePlayer.F.SLIDE
	if player.wall_sliding:
		f |= RemotePlayer.F.WALL_L if player.wall_dir < 0 else RemotePlayer.F.WALL_R
	if player.dash_t > 0.0:
		f |= RemotePlayer.F.DASH
	if player.slamming:
		f |= RemotePlayer.F.SLAM
	if player.dead:
		f |= RemotePlayer.F.DEAD
	if player.invuln > 0.0:
		f |= RemotePlayer.F.INVULN
	return f

func _net_tick(delta: float) -> void:
	net_send_t -= delta
	if net_send_t <= 0.0 and player:
		net_send_t = 1.0 / 30.0
		var spin := 0.0
		if player.spin_t > 0.0:
			spin = (1.0 - player.spin_t / player.SPIN_TIME) * TAU * player.spin_dir
		Net.p_state.rpc(PackedFloat32Array([player.global_position.x, player.global_position.y, player.velocity.x, player.velocity.y,
			player.aim.x, player.aim.y, _player_flags(), spin, player.hp, player.max_hp()]))
	if not Net.is_host:
		return
	# Host: Gegner-Schnappschuss an alle
	snap_t -= delta
	if snap_t <= 0.0:
		snap_t = 1.0 / 20.0
		var data := PackedFloat32Array()
		for e in enemies:
			if not is_instance_valid(e) or e.dead or not e.active:
				continue
			data.append_array(e.net_snapshot())
		if data.size() > 0:
			Net.e_snap.rpc(data)
	# Koop: alle tot -> Run vorbei
	if not versus and state in ["play", "boss_dead"] and player.dead and Run.revives_left <= 0:
		var any_alive := false
		for r in remotes.values():
			if is_instance_valid(r) and (not r.has_state or not r.dead):
				any_alive = true
		if not any_alive:
			state = "over_pending"
			Net.run_over.rpc(false)
	# Versus: Zeitlimit
	if versus and not pvp_over:
		pvp_time -= delta
		if pvp_time <= 0.0:
			pvp_over = true
			Net.pvp_end.rpc(pvp_scores)

func net_peer_left(id: int) -> void:
	if remotes.has(id):
		var r = remotes[id]
		if is_instance_valid(r):
			fx.ring(r.global_position, r.color, 60.0, 0.5)
			r.queue_free()
		remotes.erase(id)
	cards_done.erase(id)
	if Net.is_host and not cards_done.is_empty():
		net_card_done(-1)

func net_player_state(id: int, data: PackedFloat32Array) -> void:
	if not remotes.has(id):
		_add_remote(id)
	if remotes.has(id):
		remotes[id].apply_state(data)

func net_remote_shot(id: int, origin: Vector2, vels: PackedVector2Array, weapon_id: String, crit: bool) -> void:
	if not Data.WEAPONS.has(weapon_id):
		return
	var w: Dictionary = Data.WEAPONS[weapon_id]
	for v in vels:
		bullets.spawn_visual(origin, v, w, crit)
	fx.muzzle(origin, vels[0].normalized() if vels.size() > 0 else Vector2.RIGHT, w["color"])
	Sfx.play_at(w["sfx"], origin, -10.0)

func net_carve(pos: Vector2, radius: float, normal: Vector2, seed_value: int) -> void:
	carve(pos, radius, normal, seed_value, true)

func net_fx_explosion(pos: Vector2, radius: float) -> void:
	fx.explosion(pos, Color(1.0, 0.6, 0.25), radius / 90.0)
	Sfx.play_at("explosion", pos, -4.0)
	if versus and player and not player.dead and player.global_position.distance_to(pos) < radius:
		pass  # Schaden kommt per pvp_hit vom Schützen

func net_enemy_snapshot(data: PackedFloat32Array) -> void:
	var i := 0
	while i + ENEMY_STRIDE <= data.size():
		var id := int(data[i])
		var e = enemies_by_id.get(id)
		if e and is_instance_valid(e) and not e.dead:
			e.apply_snapshot(data.slice(i, i + ENEMY_STRIDE))
		i += ENEMY_STRIDE

func net_spawn_enemy(kind: String, pos: Vector2, id: int) -> void:
	if not enemies_by_id.has(id):
		spawn_enemy(kind, pos, false, id)

func net_enemy_died(id: int, killer: int, reward: bool) -> void:
	var e = enemies_by_id.get(id)
	if e == null or not is_instance_valid(e) or e.dead:
		return
	e.die_remote(killer, reward)

func net_hit_enemy(id: int, dmg: float, dir: Vector2, crit: bool, from_peer: int) -> void:
	var e = enemies_by_id.get(id)
	if e and is_instance_valid(e) and not e.dead:
		e.pending_hitter = from_peer
		e.take_damage(dmg, dir, crit)

func net_request_clear() -> void:
	if state in ["play", "boss_dead"]:
		Net.sec_clear.rpc()

func net_section_clear() -> void:
	if state == "clear":
		return
	clear_requested = true
	if player.dead:
		player.revive(goal.position + Vector2(0, -40) if goal else player.global_position, 0.5)
	_section_clear()

func net_card_done(from_peer: int) -> void:
	if from_peer <= 0 and from_peer != -1:
		from_peer = 1
	if from_peer > 0:
		cards_done[from_peer] = true
	for id in Net.players:
		if not cards_done.has(id):
			return
	cards_done.clear()
	Net.next_sec.rpc()

func net_next_section() -> void:
	hud.banner_t = 0.0
	var victory := Run.advance()
	if victory:
		_end_run(true)
		return
	_next_section()

func net_checkpoint(index: int) -> void:
	if index >= 0 and index < checkpoints.size():
		_activate_checkpoint(index)

func net_run_over(victory: bool) -> void:
	if state == "over":
		return
	state = "dead"
	Sfx.stop_music(1.0)
	await get_tree().create_timer(1.2).timeout
	if is_inside_tree():
		_end_run(victory)

func net_pvp_hit(dmg: float, from_pos: Vector2, shooter: int) -> void:
	if player == null or player.dead or pvp_over:
		return
	last_attacker = shooter
	player.take_damage(dmg, from_pos)

func net_pvp_death(victim: int, killer: int) -> void:
	if victim <= 0:
		victim = Net.my_id()
	var vn: String = Net.players.get(victim, {}).get("name", "?")
	var kn: String = Net.players.get(killer, {}).get("name", "?")
	killfeed.append({"text": ("%s  >  %s" % [kn, vn]) if killer > 0 and killer != victim else vn, "t": 4.0})
	if killer == Net.my_id() and killer != victim:
		Run.add_kill(100)
		Sfx.play("combo", -2.0)
	if Net.is_host and not pvp_over:
		if killer > 0 and killer != victim:
			pvp_scores[killer] = int(pvp_scores.get(killer, 0)) + 1
		Net.pvp_scores.rpc(pvp_scores, pvp_time)
		for id in pvp_scores:
			if int(pvp_scores[id]) >= PVP_KILLS:
				pvp_over = true
				Net.pvp_end.rpc(pvp_scores)
				break

func net_pvp_scores(scores: Dictionary, time_left: float) -> void:
	pvp_scores = scores
	pvp_time = time_left

func net_pvp_end(scores: Dictionary) -> void:
	pvp_scores = scores
	pvp_over = true
	state = "over"
	player.frozen = true
	var my_kills := int(scores.get(Net.my_id(), 0))
	var best_id := -1
	var best := -1
	for id in scores:
		if int(scores[id]) > best:
			best = int(scores[id])
			best_id = id
	var won := best_id == Net.my_id()
	var earned := my_kills * 20 + (100 if won else 25)
	Save.add_bank(earned)
	Save.save_data()
	Sfx.play("clear" if won else "game_over")
	var go = GameOver.new()
	go.net_mode = true
	go.pvp_scores = scores
	go.summary = {"victory": won, "pvp": true, "credits": earned}
	go.retry.connect(func(): back_to_lobby())
	go.to_menu.connect(func(): back_to_lobby())
	_show_overlay(go)
