# HUD im Stil der Vorlage: leuchtende Pixel-Ziffern oben links, Credits oben rechts,
# unten links kleine Leucht-Balken für Leben und Dash. Dazu Kombo, Bossleiste, Banner und Erfolge.
extends Control

const Neon = preload("res://scripts/core/neon.gd")
const UI = preload("res://scripts/ui/ui_kit.gd")

# 5x7-Pixelschrift für Ziffern
const GLYPHS := {
	"0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
	"1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
	"2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
	"3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
	"4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
	"5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
	"6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
	"7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
	"8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
	"9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
	"$": ["00100", "01111", "10100", "01110", "00101", "11110", "00100"],
	".": ["00000", "00000", "00000", "00000", "00000", "01100", "01100"],
}

var game
var banner_title := ""
var banner_sub := ""
var banner_col := Color.WHITE
var banner_t := 0.0
var banner_dur := 2.0
var dmg_flash := 0.0
var combo_pulse := 0.0
var shown_score := 0.0
var shown_credits := 0.0
var shown_hp := 1.0
var toasts: Array = []
var f_mono: Font
var f_ui: Font

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	f_mono = UI.font("mono")
	f_ui = UI.font("ui")

func refresh_section() -> void:
	shown_score = Run.score
	shown_credits = Run.credits

func banner(title: String, sub: String, col: Color, dur: float = 2.2) -> void:
	banner_title = title
	banner_sub = sub
	banner_col = col
	banner_t = dur
	banner_dur = dur

func flash_damage() -> void:
	dmg_flash = 0.35

func combo_pop() -> void:
	combo_pulse = 1.0

func achievement_toast(id: String) -> void:
	toasts.append({"id": id, "t": 4.0})

func _process(delta: float) -> void:
	banner_t = maxf(0.0, banner_t - delta)
	dmg_flash = maxf(0.0, dmg_flash - delta)
	combo_pulse = maxf(0.0, combo_pulse - delta * 3.0)
	shown_score = lerpf(shown_score, Run.score, clampf(10.0 * delta, 0.0, 1.0))
	shown_credits = lerpf(shown_credits, Run.credits, clampf(12.0 * delta, 0.0, 1.0))
	if game and game.player:
		shown_hp = lerpf(shown_hp, clampf(game.player.hp / game.player.max_hp(), 0.0, 1.0), clampf(8.0 * delta, 0.0, 1.0))
	for t in toasts:
		t["t"] -= delta
	toasts = toasts.filter(func(t): return t["t"] > 0.0)
	queue_redraw()

# Leuchtender Text: weicher Schein + heller Kern
func _glow_text(pos: Vector2, s: String, f: Font, size: int, c: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x := pos.x
	if align == HORIZONTAL_ALIGNMENT_RIGHT:
		x -= w
	elif align == HORIZONTAL_ALIGNMENT_CENTER:
		x -= w * 0.5
	Neon.halo(self, Vector2(x + w * 0.5, pos.y - size * 0.35), maxf(w * 0.6, size * 1.2), Neon.fade(c, 0.12))
	draw_string_outline(f, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, int(size * 0.25), Neon.fade(c, 0.18))
	draw_string(f, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Neon.hdr(c, 0.9))

# Pixel-Ziffern mit Leuchten, wie in der Vorlage
func _pixel_text(pos: Vector2, s: String, px: float, c: Color, align_right: bool = false) -> void:
	var adv := px * 6.0
	var total := adv * s.length() - px
	var x := pos.x - (total if align_right else 0.0)
	Neon.halo(self, Vector2(x + total * 0.5, pos.y + px * 3.5), maxf(total * 0.75, px * 9.0), Neon.fade(c, 0.22))
	for ch in s:
		var g: Array = GLYPHS.get(ch, [])
		for row in g.size():
			var line: String = g[row]
			for col in line.length():
				if line[col] == "1":
					var r := Rect2(x + col * px, pos.y + row * px, px * 0.92, px * 0.92)
					draw_rect(r.grow(px * 0.35), Neon.fade(c, 0.12))
					draw_rect(r, Neon.hdr(c, 1.1))
		x += adv

func _draw_net(vs: Vector2) -> void:
	if game.versus:
		var ids: Array = game.pvp_scores.keys()
		ids.sort_custom(func(a, b): return int(game.pvp_scores[a]) > int(game.pvp_scores[b]))
		var y := 26.0
		_glow_text(Vector2(vs.x * 0.5, y), "%d:%02d" % [int(game.pvp_time) / 60, int(game.pvp_time) % 60], f_mono, 20, Color(1, 1, 1, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
		y += 24.0
		for id in ids:
			var nm: String = Net.players.get(id, {}).get("name", "?")
			var c := Color(1.0, 0.85, 0.4) if id == Net.my_id() else Color(1, 1, 1, 0.75)
			_glow_text(Vector2(vs.x * 0.5, y), "%s   %d" % [nm, int(game.pvp_scores[id])], f_mono, 14, c, HORIZONTAL_ALIGNMENT_CENTER)
			y += 18.0
	else:
		# Koop: Mitspieler mit Lebensbalken oben links unter den Punkten
		var y := 118.0
		for r in game.remotes.values():
			if not is_instance_valid(r):
				continue
			var ratio: float = 0.0 if r.dead else clampf(r.hp / r.max_hp_v, 0.0, 1.0)
			_glow_text(Vector2(28, y), r.display_name, f_mono, 12, Neon.fade(r.color, 0.85))
			_glow_bar(Vector2(28, y + 5), 90.0, 3.0, ratio, r.color, r.dead)
			y += 24.0
	var ky := vs.y * 0.3
	for k in game.killfeed:
		k["t"] -= get_process_delta_time()
		var a := clampf(k["t"], 0.0, 1.0)
		_glow_text(Vector2(vs.x - 22, ky), k["text"], f_mono, 14, Neon.fade(Color(1.0, 0.5, 0.55), a), HORIZONTAL_ALIGNMENT_RIGHT)
		ky += 20.0
	game.killfeed = game.killfeed.filter(func(k): return k["t"] > 0.0)

# Kleiner Leucht-Balken
func _glow_bar(pos: Vector2, w: float, h: float, ratio: float, c: Color, dim: bool = false) -> void:
	var r := Rect2(pos, Vector2(w, h))
	draw_rect(r.grow(1.5), Neon.fade(c, 0.08))
	draw_rect(r, Color(c.r, c.g, c.b, 0.07))
	var fill := Rect2(pos, Vector2(w * clampf(ratio, 0.0, 1.0), h))
	if fill.size.x > 0.5:
		Neon.halo(self, fill.get_center(), clampf(fill.size.x * 0.35, 10.0, 40.0), Neon.fade(c, 0.05 if dim else 0.09))
		draw_rect(fill.grow(1.5), Neon.fade(c, 0.2 if dim else 0.35))
		draw_rect(fill, Neon.hdr(Neon.fade(c, 0.6 if dim else 1.0), 0.4 if dim else 1.0))

func _draw() -> void:
	if game == null or game.player == null:
		return
	var vs := get_viewport_rect().size
	var p = game.player
	var accent: Color = game.pal.get("accent", UI.ACCENT)
	# Punkte oben links
	var score_col := Color(0.78, 0.72, 1.0, 0.75).lerp(accent, 0.2)
	_pixel_text(Vector2(26, 20), str(int(round(shown_score))), 5.0, score_col)
	# Kombo unter den Punkten
	if Run.combo >= 2:
		var cs := 18 + int(combo_pulse * 8.0)
		_glow_text(Vector2(28, 84), "x%.1f  %s %d" % [Run.combo_mult(), L.t("combo"), Run.combo], f_mono, cs, Color(1.0, 0.8, 0.3, 0.95))
		var k := clampf(game.combo_t / Run.stats["combo_window"], 0.0, 1.0)
		draw_rect(Rect2(28, 90, 130 * k, 2), Neon.hdr(Neon.fade(Color(1.0, 0.8, 0.3), 0.8), 0.5))
	# Credits oben rechts
	_glow_text(Vector2(vs.x - 22, 36), "$" + UI.fmt_num(int(round(shown_credits))), f_ui, 22, Color(1.0, 0.92, 0.7, 0.95), HORIZONTAL_ALIGNMENT_RIGHT)
	# Leben und Dash unten links
	var hp_ratio := clampf(p.hp / p.max_hp(), 0.0, 1.0)
	var hc := Color(0.45, 1.0, 0.75) if hp_ratio > 0.35 else Color(1.0, 0.35, 0.4)
	var base := Vector2(24, vs.y - 34)
	draw_rect(Rect2(base, Vector2(160.0 * shown_hp, 6)), Neon.fade(Color(1, 1, 1), 0.25))
	_glow_bar(base, 160.0, 6.0, hp_ratio, hc)
	var dk: float = p.dash_ready_ratio()
	_glow_bar(base + Vector2(0, 14), 64.0, 3.0, dk, accent, dk < 1.0)
	var ix := base.x + 172.0
	if Run.stats["shield"] > 0:
		var sc := accent if p.shield_ready else Color(0.5, 0.5, 0.6, 0.4)
		Neon.circle(self, Vector2(ix + 4, base.y + 3), 5.0, sc, 1.4, 0.6 if p.shield_ready else 0.0)
		ix += 18.0
	for i in Run.revives_left:
		Neon.dot(self, Vector2(ix + 3, base.y + 3), 2.6, Color(1.0, 0.45, 0.65), 0.8)
		ix += 12.0
	# Multiplayer: Mitspieler, Versus-Punkte, Killfeed
	if Net.active:
		_draw_net(vs)
	# Bossleiste
	var b = game.boss
	if is_instance_valid(b) and not b.dead and b.state != "intro":
		var bw := minf(520.0, vs.x * 0.45)
		_glow_bar(Vector2(vs.x * 0.5 - bw * 0.5, 30), bw, 5.0, b.hp / b.max_hp, b.col)
		_glow_text(Vector2(vs.x * 0.5, 22), L.t("boss_name"), f_mono, 14, b.col, HORIZONTAL_ALIGNMENT_CENTER)
	# Banner (z. B. CHECKPOINT)
	if banner_t > 0.0:
		var k := banner_t / banner_dur
		var a := clampf(minf((1.0 - k) * 8.0, k * 4.0), 0.0, 1.0)
		var pop := 1.0 + (1.0 - minf((1.0 - k) * 6.0, 1.0)) * 0.25
		var by := vs.y * 0.17
		_glow_text(Vector2(vs.x * 0.5, by), banner_title, f_mono, int(30 * pop), Neon.fade(banner_col, a), HORIZONTAL_ALIGNMENT_CENTER)
		if banner_sub != "":
			_glow_text(Vector2(vs.x * 0.5, by + 30), banner_sub, f_mono, 17, Neon.fade(Color(1, 1, 1), a * 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	# Erfolg-Einblendungen
	var ty := 64.0
	for t in toasts:
		var a2 := clampf(minf(t["t"], 4.0 - t["t"]) * 3.0, 0.0, 1.0)
		var r := Rect2(vs.x - 330, ty, 308, 50)
		draw_rect(r, Color(0.0, 0.0, 0.0, 0.75 * a2))
		draw_rect(r, Neon.fade(UI.GOLD, a2 * 0.6), false, 1.2)
		_glow_text(Vector2(r.position.x + 12, ty + 20), L.t("achievement_unlocked"), f_mono, 12, Neon.fade(UI.GOLD, a2))
		_glow_text(Vector2(r.position.x + 12, ty + 40), L.t("ach_" + t["id"]), f_ui, 17, Neon.fade(Color(1, 1, 1), a2))
		ty += 58.0
	# Schaden: roter Rand
	if dmg_flash > 0.0:
		var a3 := dmg_flash / 0.35 * 0.28
		var tw := 50.0
		var c := Color(1, 0.1, 0.15, a3)
		draw_rect(Rect2(0, 0, vs.x, tw), c)
		draw_rect(Rect2(0, vs.y - tw, vs.x, tw), c)
		draw_rect(Rect2(0, 0, tw, vs.y), c)
		draw_rect(Rect2(vs.x - tw, 0, tw, vs.y), c)
	if hp_ratio < 0.3 and not p.dead:
		var pulse := 0.1 + 0.07 * sin(Time.get_ticks_msec() * 0.008)
		draw_rect(Rect2(0, 0, vs.x, 5), Color(1, 0.1, 0.1, pulse))
		draw_rect(Rect2(0, vs.y - 5, vs.x, 5), Color(1, 0.1, 0.1, pulse))
	if Save.setting("show_fps"):
		_glow_text(Vector2(vs.x - 22, vs.y - 18), "%d FPS" % Engine.get_frames_per_second(), f_mono, 13, Color(1, 1, 1, 0.45), HORIZONTAL_ALIGNMENT_RIGHT)
