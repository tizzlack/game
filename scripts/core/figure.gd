# Strichfiguren für Spieler und Gegner. pose() liefert Liniensegmente in lokalen Koordinaten (Füße bei y = +27).
extends RefCounted

const Neon = preload("res://scripts/core/neon.gd")

# phase: Laufzyklus, speed: 0..1.3, move_dir: -1/1, on_floor, aim: Einheitsvektor, gun: Länge der Waffe (0 = keine)
static func pose(phase: float, speed: float, move_dir: float, on_floor: bool, aim: Vector2, gun: float, vel_y: float = 0.0, recoil: float = 0.0, scale: float = 1.0) -> Dictionary:
	var md := 1.0 if move_dir >= 0.0 else -1.0
	var hip := Vector2(0, 3)
	var lean := clampf(speed, 0.0, 1.0) * 3.5 * md
	var neck := Vector2(lean, -17)
	var head := neck + Vector2(lean * 0.25, -8.5)
	var segs: Array = []
	segs.append([hip, neck])
	if on_floor:
		var a := sin(phase) * 0.9 * clampf(speed, 0.0, 1.0)
		for s in [1.0, -1.0]:
			var ang: float = a * s
			var knee := hip + Vector2(sin(ang) * 12.5 * md, cos(ang) * 12.0)
			var bend := 0.2 + maxf(0.0, -sin(phase * s + 0.6)) * 0.9 * clampf(speed, 0.0, 1.0)
			var foot := knee + Vector2(sin(ang - bend) * 12.5 * md, cos(ang - bend) * 12.5)
			segs.append([hip, knee])
			segs.append([knee, foot])
	else:
		var tuck := clampf(-vel_y / 700.0, -0.6, 1.0)
		var k1 := hip + Vector2(6 * md, 10 - tuck * 3)
		var k2 := hip + Vector2(-4 * md, 11)
		segs.append([hip, k1])
		segs.append([k1, k1 + Vector2(-3 * md, 11)])
		segs.append([hip, k2])
		segs.append([k2, k2 + Vector2(-6 * md, 9 + tuck * 2)])
	var shoulder := neck + Vector2(0, 3)
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
		# Arme nach vorne gestreckt (Nahkampf-Gegner)
		var sw := sin(phase * 0.5) * 2.0
		segs.append([shoulder, shoulder + Vector2(9 * md, 3 + sw)])
		segs.append([shoulder + Vector2(9 * md, 3 + sw), shoulder + Vector2(19 * md, 1 + sw)])
		segs.append([shoulder, shoulder + Vector2(7 * md, 6 - sw)])
		segs.append([shoulder + Vector2(7 * md, 6 - sw), shoulder + Vector2(17 * md, 5 - sw)])
	if scale != 1.0:
		for s in segs:
			s[0] *= scale
			s[1] *= scale
		head *= scale
		gun_a *= scale
		gun_b *= scale
	return {"segs": segs, "head": head, "head_r": 6.5 * scale, "gun_a": gun_a, "gun_b": gun_b, "has_gun": gun > 0.0}

static func draw(ci: CanvasItem, p: Dictionary, c: Color, w: float = 2.2, glow: float = 1.0) -> void:
	for s in p["segs"]:
		Neon.line(ci, s[0], s[1], c, w, glow)
	Neon.circle(ci, p["head"], p["head_r"], c, w, glow)
	if p["has_gun"]:
		Neon.line(ci, p["gun_a"], p["gun_b"], c, w * 1.7, glow)

# Wandelt die Pose in Weltkoordinaten (für Nachbilder)
static func to_global(p: Dictionary, xf: Transform2D) -> Dictionary:
	var segs: Array = []
	for s in p["segs"]:
		segs.append([xf * s[0], xf * s[1]])
	return {"segs": segs, "head": xf * p["head"], "head_r": p["head_r"], "gun_a": xf * p["gun_a"], "gun_b": xf * p["gun_b"], "has_gun": p["has_gun"]}
