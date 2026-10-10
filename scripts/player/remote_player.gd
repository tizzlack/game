# Figur eines anderen Spielers im Netzwerk: empfängt Zustände (~30/s), interpoliert flüssig, zeigt Namen.
# Im Versus ist sie trefferbar (Ebene 5), im Koop nicht.
extends AnimatableBody2D

const Neon = preload("res://scripts/core/neon.gd")
const Figure = preload("res://scripts/core/figure.gd")
const Data = preload("res://scripts/core/data.gd")

enum F { FLOOR = 1, SLIDE = 2, WALL_L = 4, WALL_R = 8, DASH = 16, SLAM = 32, DEAD = 64, INVULN = 128 }

var game
var peer_id := 0
var display_name := ""
var color := Color(0.75, 0.9, 1.0)
var weapon_len := 26.0
var target_pos := Vector2.ZERO
var velocity := Vector2.ZERO
var aim := Vector2.RIGHT
var flags := 0
var spin := 0.0
var hp := 100.0
var max_hp_v := 100.0
var dead := false
var run_phase := 0.0
var anim_t := 0.0
var has_state := false
var font: Font
var radius := 14.0

func setup(g, id: int, info: Dictionary, versus: bool) -> void:
	game = g
	peer_id = id
	display_name = info.get("name", "Player")
	var sk: String = info.get("skin", "frost")
	color = Data.SKINS[sk]["color"] if Data.SKINS.has(sk) else Color(0.75, 0.9, 1.0)
	var w: String = info.get("weapon", "blaster")
	weapon_len = Data.WEAPONS[w]["length"] if Data.WEAPONS.has(w) else 26.0
	collision_layer = 16 if versus else 0
	collision_mask = 0
	sync_to_physics = false

func _ready() -> void:
	var shape := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = 11.0
	cap.height = 54.0
	shape.shape = cap
	add_child(shape)
	z_index = 11
	font = load("res://assets/fonts/MonoFont.ttf")
	visible = false

func apply_state(d: PackedFloat32Array) -> void:
	if d.size() < 10:
		return
	target_pos = Vector2(d[0], d[1])
	velocity = Vector2(d[2], d[3])
	aim = Vector2(d[4], d[5])
	flags = int(d[6])
	spin = d[7]
	hp = d[8]
	max_hp_v = maxf(1.0, d[9])
	dead = flags & F.DEAD != 0
	if not has_state:
		global_position = target_pos
		has_state = true
	visible = not dead

# Gegner-KI und Kontaktschaden behandeln Remote-Spieler wie normale Ziele, Schaden regelt aber deren eigener Rechner
func take_damage(_amount: float, _from: Vector2) -> void:
	pass

func is_dodging() -> bool:
	return flags & (F.DASH | F.SLAM) != 0

func _physics_process(delta: float) -> void:
	if not has_state:
		return
	anim_t += delta
	# Vorhersage + Glättung
	target_pos += velocity * delta
	global_position = global_position.lerp(target_pos, clampf(18.0 * delta, 0.0, 1.0))
	if global_position.distance_to(target_pos) > 260.0:
		global_position = target_pos
	if flags & F.FLOOR:
		run_phase += absf(velocity.x) * delta * 0.052
	queue_redraw()

func _draw() -> void:
	if not has_state or dead:
		return
	var wall := 0
	if flags & F.WALL_L:
		wall = -1
	elif flags & F.WALL_R:
		wall = 1
	var slide := flags & F.SLIDE != 0
	var md := signf(velocity.x) if absf(velocity.x) > 20.0 else signf(aim.x) if aim.x != 0.0 else 1.0
	if wall != 0:
		md = float(wall)
	var extra := {"idle_t": anim_t, "spin": spin, "dash": flags & F.DASH != 0, "slide": slide, "wall": wall, "slam": flags & F.SLAM != 0}
	var p := Figure.pose(run_phase, absf(velocity.x) / 360.0, md, flags & F.FLOOR != 0, aim, 10.0 + weapon_len * 0.4, velocity.y, 0.0, 1.0, extra)
	var c := color
	if flags & F.INVULN and fmod(anim_t, 0.16) < 0.08:
		c = Neon.fade(c, 0.4)
	Neon.halo(self, Vector2(0, -6), 40.0, Neon.fade(c, 0.11))
	Figure.draw(self, p, c, 2.5, 1.0)
	# Name und kleine Lebensleiste über dem Kopf
	var w := font.get_string_size(display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(font, Vector2(-w * 0.5, -52), display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Neon.fade(c, 0.85))
	var r := clampf(hp / max_hp_v, 0.0, 1.0)
	draw_rect(Rect2(-18, -48, 36, 3), Color(1, 1, 1, 0.12))
	draw_rect(Rect2(-18, -48, 36 * r, 3), Neon.hdr(Neon.fade(Color(0.45, 1.0, 0.7) if r > 0.35 else Color(1, 0.35, 0.4), 0.9), 0.4))
