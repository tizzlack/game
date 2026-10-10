# Strichfiguren für Spieler und Gegner mit prozeduraler Animation.
# pose() liefert Liniensegmente in lokalen Koordinaten (Füße bei y ≈ +27).
extends RefCounted

const Neon = preload("res://scripts/core/neon.gd")

const THIGH := 12.5
const SHIN := 12.5

static func _limb(from: Vector2, ang: float, length: float, md: float) -> Vector2:
	# ang: 0 = senkrecht nach unten, positiv = in Laufrichtung nach vorne
	return from + Vector2(sin(ang) * md, cos(ang)) * length

# phase: Laufzyklus, speed: 0..1.3, move_dir: -1/1, on_floor, aim: Einheitsvektor, gun: Länge der Waffe (0 = keine)
# extra: {"idle_t": Zeit, "spin": Drehwinkel (Salto), "dash": bool}
static func pose(phase: float, speed: float, move_dir: float, on_floor: bool, aim: Vector2, gun: float, vel_y: float = 0.0, recoil: float = 0.0, scale: float = 1.0, extra: Dictionary = {}) -> Dictionary:
	var md := 1.0 if move_dir >= 0.0 else -1.0
	var s := clampf(speed, 0.0, 1.2)
	var dash: bool = extra.get("dash", false)
	var idle_t: float = extra.get("idle_t", 0.0)
	var bob := 0.0
	var lean := 0.0
	var legs: Array = []  # [Oberschenkel-Winkel, Kniebeugung]
	if dash:
		lean = 0.55
		legs = [[0.7, 1.1], [-0.95, 0.35]]
	elif on_floor and s > 0.06:
		bob = -absf(cos(phase)) * 2.6 * s
		lean = 0.14 * s
		for off in [0.0, PI]:
			var ph: float = phase + off
			var thigh := sin(ph) * 0.78 * s
			var bend := (0.22 + 1.0 * maxf(0.0, cos(ph))) * s
			legs.append([thigh, bend])
	elif on_floor:
		bob = sin(idle_t * 2.2) * 0.7
		legs = [[0.13, 0.1], [-0.13, 0.06]]
	else:
		# Steigen: Beine angezogen, Fallen: Beine lang
		var k := clampf((vel_y + 300.0) / 700.0, 0.0, 1.0)
		legs = [[lerpf(0.95, 0.35, k), lerpf(1.55, 0.35, k)], [lerpf(-0.15, -0.35, k), lerpf(0.95, 0.15, k)]]
		lean = lerpf(0.1, -0.05, k)
	var hip := Vector2(0, 3.0 + bob)
	var torso_dir := Vector2(sin(lean) * md, -cos(lean))
	var neck := hip + torso_dir * 20.0
	var head := neck + torso_dir * 8.5 + Vector2(0, bob * 0.2)
	var segs: Array = []
	segs.append([hip, neck])
	for l in legs:
		var knee := _limb(hip, l[0], THIGH, md)
		var foot := _limb(knee, l[0] - l[1], SHIN, md)
		segs.append([hip, knee])
		segs.append([knee, foot])
	var shoulder := neck - torso_dir * 3.0
	var gun_a := Vector2.ZERO
	var gun_b := Vector2.ZERO
	if gun > 0.0:
		var perp := aim.orthogonal()
		if aim.x < 0.0:
			perp = -perp
		var hand := shoulder + aim * (17.0 - recoil * 5.0)
		var elbow := shoulder + aim * 8.0 + Vector2(0, 4)
		var support := shoulder + aim * (11.0 - recoil * 4.0) + perp * 2.0
		var elbow2 := shoulder + aim * 5.0 + Vector2(0, 6)
		segs.append([shoulder, elbow])
		segs.append([elbow, hand])
		segs.append([shoulder, elbow2])
		segs.append([elbow2, support])
		gun_a = hand - aim * 3.0
		gun_b = hand + aim * gun
	else:
		# Nahkämpfer: Arme schwingen gegenläufig zu den Beinen und greifen nach vorne
		for off in [0.0, PI]:
			var sw: float = (-sin(phase + off) * 0.7 * s) if on_floor else -0.9
			var up_ang := 1.25 + sw * 0.5
			var elbow := _limb(shoulder, up_ang, 9.0, md)
			var hand := _limb(elbow, up_ang + 0.35, 9.0, md)
			segs.append([shoulder, elbow])
			segs.append([elbow, hand])
	var spin: float = extra.get("spin", 0.0)
	if spin != 0.0:
		var c := Vector2(0, -4)
		for sg in segs:
			sg[0] = c + (sg[0] - c).rotated(spin)
			sg[1] = c + (sg[1] - c).rotated(spin)
		head = c + (head - c).rotated(spin)
		gun_a = c + (gun_a - c).rotated(spin)
		gun_b = c + (gun_b - c).rotated(spin)
	if scale != 1.0:
		for sg in segs:
			sg[0] *= scale
			sg[1] *= scale
		head *= scale
		gun_a *= scale
		gun_b *= scale
	return {"segs": segs, "head": head, "head_r": 6.5 * scale, "gun_a": gun_a, "gun_b": gun_b, "has_gun": gun > 0.0}

static func draw(ci: CanvasItem, p: Dictionary, c: Color, w: float = 2.2, glow: float = 1.0) -> void:
	for s in p["segs"]:
		Neon.line(ci, s[0], s[1], c, w, glow)
	# Gelenke rund schließen, damit die Linien nicht zerfasern
	for s in p["segs"]:
		ci.draw_circle(s[1], w * 0.5, Neon.hdr(c, 1.1 * glow))
	Neon.circle(ci, p["head"], p["head_r"], c, w, glow)
	if p["has_gun"]:
		Neon.line(ci, p["gun_a"], p["gun_b"], c, w * 1.7, glow)

# Wandelt die Pose in Weltkoordinaten (für Nachbilder)
static func to_global(p: Dictionary, xf: Transform2D) -> Dictionary:
	var segs: Array = []
	for s in p["segs"]:
		segs.append([xf * s[0], xf * s[1]])
	return {"segs": segs, "head": xf * p["head"], "head_r": p["head_r"], "gun_a": xf * p["gun_a"], "gun_b": xf * p["gun_b"], "has_gun": p["has_gun"]}
