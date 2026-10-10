# HUD: Punkte (oben links), Kombo, Leben, Credits (oben rechts), Zeit (unten links), Fortschritt, Bossleiste, Banner.
extends Control

const Neon = preload("res://scripts/core/neon.gd")
const UI = preload("res://scripts/ui/ui_kit.gd")
const Data = preload("res://scripts/core/data.gd")

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
var toasts: Array = []
var fps_label: Label
var f_title: Font
var f_mono: Font
var f_ui: Font

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	f_title = UI.font("title")
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
	for t in toasts:
		t["t"] -= delta
	toasts = toasts.filter(func(t): return t["t"] > 0.0)
	queue_redraw()

func _text(pos: Vector2, s: String, f: Font, size: int, c: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var x := pos.x
	if align == HORIZONTAL_ALIGNMENT_RIGHT:
		x -= f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	elif align == HORIZONTAL_ALIGNMENT_CENTER:
		x -= f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5
	draw_string(f, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)

func _draw() -> void:
	if game == null or game.player == null:
		return
	var vs := get_viewport_rect().size
	var p = game.player
	var accent: Color = game.pal.get("accent", UI.ACCENT)
	# Punkte groß und halbtransparent wie in Arcade-Spielen
	_text(Vector2(24, 70), str(int(round(shown_score))), f_title, 58, Color(1, 1, 1, 0.42))
	# Kombo
	if Run.combo >= 2:
		var cs := 26 + int(combo_pulse * 10.0)
		var cc := Neon.hdr(Color(1.0, 0.8, 0.3), 0.4 + combo_pulse)
		_text(Vector2(26, 106), "x%.1f  %s %d" % [Run.combo_mult(), L.t("combo"), Run.combo], f_mono, cs, cc)
		var k := clampf(game.combo_t / Run.stats["combo_window"], 0.0, 1.0)
		draw_rect(Rect2(26, 114, 180 * k, 3), Neon.fade(Color(1.0, 0.8, 0.3), 0.8))
	# Lebensleiste
	var hp_ratio := clampf(p.hp / p.max_hp(), 0.0, 1.0)
	var bar := Rect2(26, 128, 260, 12)
	draw_rect(bar, Color(0.1, 0.1, 0.15, 0.7))
	var hc := Color(0.4, 1.0, 0.6) if hp_ratio > 0.35 else Color(1.0, 0.35, 0.35)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * hp_ratio, bar.size.y)), Neon.hdr(Neon.fade(hc, 0.9), 0.3))
	for i in range(1, 10):
		var x := bar.position.x + bar.size.x * i / 10.0
		draw_line(Vector2(x, bar.position.y), Vector2(x, bar.end.y), Color(0, 0, 0, 0.6), 2.0)
	draw_rect(bar, Neon.fade(hc, 0.6), false, 1.5)
	_text(Vector2(bar.end.x + 10, bar.end.y + 1), "%d/%d" % [ceili(p.hp), int(p.max_hp())], f_mono, 15, Color(1, 1, 1, 0.7))
	var icon_x := 26.0
	if Run.stats["shield"] > 0:
		var sc := accent if p.shield_ready else Color(0.4, 0.4, 0.5, 0.6)
		draw_arc(Vector2(icon_x + 8, 160), 8, 0, TAU, 20, sc, 2.0)
		icon_x += 26.0
	if Run.revives_left > 0:
		_text(Vector2(icon_x, 165), "+1", f_mono, 15, Color(1.0, 0.45, 0.6))
		icon_x += 30.0
	# Dash-Anzeige
	var dk: float = p.dash_ready_ratio()
	draw_rect(Rect2(icon_x, 156, 50, 6), Color(0.1, 0.1, 0.15, 0.7))
	draw_rect(Rect2(icon_x, 156, 50 * dk, 6), Neon.fade(accent, 0.9 if dk >= 1.0 else 0.45))
	_text(Vector2(icon_x + 56, 163), "DASH", f_mono, 12, Neon.fade(accent, 0.7 if dk >= 1.0 else 0.35))
	# Credits oben rechts
	_text(Vector2(vs.x - 24, 46), "$" + UI.fmt_num(int(round(shown_credits))), f_title, 34, Neon.hdr(UI.GOLD, 0.3), HORIZONTAL_ALIGNMENT_RIGHT)
	var wname := L.t(game.pal["name"]) + "  " + Run.label()
	_text(Vector2(vs.x - 24, 74), wname, f_mono, 16, Color(1, 1, 1, 0.55), HORIZONTAL_ALIGNMENT_RIGHT)
	_text(Vector2(vs.x - 24, 96), L.t("weapon_" + Run.weapon_id), f_mono, 14, Color(1, 1, 1, 0.4), HORIZONTAL_ALIGNMENT_RIGHT)
	if Run.heat > 0:
		_text(Vector2(vs.x - 24, 116), L.t("heat") + " " + str(Run.heat), f_mono, 14, Color(1.0, 0.5, 0.3, 0.7), HORIZONTAL_ALIGNMENT_RIGHT)
	# Zeit unten links
	var tr := Rect2(18, vs.y - 46, 150, 30)
	draw_rect(tr, Color(0, 0, 0, 0.45))
	_text(Vector2(28, vs.y - 25), UI.fmt_time(Run.time), f_mono, 16, Color(1, 1, 1, 0.8))
	# Fortschritt
	if not game.level.get("boss", false):
		var w := minf(420.0, vs.x * 0.35)
		var px := vs.x * 0.5 - w * 0.5
		var prog := clampf(p.global_position.x / maxf(1.0, game.level["length"] - 300.0), 0.0, 1.0)
		draw_line(Vector2(px, 24), Vector2(px + w, 24), Color(1, 1, 1, 0.15), 2.0)
		draw_line(Vector2(px, 24), Vector2(px + w * prog, 24), Neon.fade(accent, 0.7), 2.0)
		for cp in game.checkpoints:
			var cx: float = px + w * clampf(cp.position.x / maxf(1.0, game.level["length"] - 300.0), 0.0, 1.0)
			draw_rect(Rect2(cx - 2, 19, 4, 10), Neon.fade(accent, 0.9 if cp.activated else 0.35))
		draw_circle(Vector2(px + w * prog, 24), 4.0, Neon.hdr(accent, 0.5))
	# Bossleiste
	var b = game.boss
	if is_instance_valid(b) and not b.dead and b.state != "intro":
		var bw := minf(640.0, vs.x * 0.6)
		var br := Rect2(vs.x * 0.5 - bw * 0.5, vs.y - 54, bw, 12)
		draw_rect(br, Color(0.1, 0.05, 0.08, 0.8))
		draw_rect(Rect2(br.position, Vector2(bw * clampf(b.hp / b.max_hp, 0.0, 1.0), 12)), Neon.hdr(b.col, 0.3))
		draw_rect(br, Neon.fade(b.col, 0.7), false, 1.5)
		draw_line(Vector2(br.position.x + bw * 0.5, br.position.y), Vector2(br.position.x + bw * 0.5, br.end.y), Color(0, 0, 0, 0.8), 2.0)
		_text(Vector2(vs.x * 0.5, br.position.y - 8), L.t("boss_name"), f_mono, 16, Neon.fade(b.col, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	# Banner
	if banner_t > 0.0:
		var k := banner_t / banner_dur
		var a := clampf(minf((1.0 - k) * 8.0, k * 4.0), 0.0, 1.0)
		var pop := 1.0 + (1.0 - minf((1.0 - k) * 6.0, 1.0)) * 0.3
		var size := int(46 * pop)
		_text(Vector2(vs.x * 0.5, vs.y * 0.3), banner_title, f_mono, size, Neon.hdr(Neon.fade(banner_col, a), 0.8), HORIZONTAL_ALIGNMENT_CENTER)
		if banner_sub != "":
			_text(Vector2(vs.x * 0.5, vs.y * 0.3 + 40), banner_sub, f_mono, 22, Neon.fade(Color(1, 1, 1), a * 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	# Erfolg-Einblendungen
	var ty := 140.0
	for t in toasts:
		var a2 := clampf(minf(t["t"], 4.0 - t["t"]) * 3.0, 0.0, 1.0)
		var r := Rect2(vs.x - 340, ty, 316, 54)
		draw_rect(r, Color(0.02, 0.03, 0.06, 0.85 * a2))
		draw_rect(r, Neon.fade(UI.GOLD, a2 * 0.8), false, 1.5)
		_text(Vector2(r.position.x + 14, ty + 22), L.t("achievement_unlocked"), f_mono, 13, Neon.fade(UI.GOLD, a2))
		_text(Vector2(r.position.x + 14, ty + 44), L.t("ach_" + t["id"]), f_ui, 18, Neon.fade(Color(1, 1, 1), a2))
		ty += 62.0
	# Schaden: roter Rand
	if dmg_flash > 0.0:
		var a3 := dmg_flash / 0.35 * 0.5
		var c := Color(1, 0.1, 0.15, a3)
		var tw := 60.0
		draw_rect(Rect2(0, 0, vs.x, tw), Color(c.r, c.g, c.b, a3 * 0.6))
		draw_rect(Rect2(0, vs.y - tw, vs.x, tw), Color(c.r, c.g, c.b, a3 * 0.6))
		draw_rect(Rect2(0, 0, tw, vs.y), Color(c.r, c.g, c.b, a3 * 0.6))
		draw_rect(Rect2(vs.x - tw, 0, tw, vs.y), Color(c.r, c.g, c.b, a3 * 0.6))
	if hp_ratio < 0.3 and not p.dead:
		var pulse := 0.12 + 0.08 * sin(Time.get_ticks_msec() * 0.008)
		draw_rect(Rect2(0, 0, vs.x, 8), Color(1, 0.1, 0.1, pulse))
		draw_rect(Rect2(0, vs.y - 8, vs.x, 8), Color(1, 0.1, 0.1, pulse))
	if Save.setting("show_fps"):
		_text(Vector2(vs.x * 0.5, vs.y - 14), "%d FPS" % Engine.get_frames_per_second(), f_mono, 13, Color(1, 1, 1, 0.5), HORIZONTAL_ALIGNMENT_CENTER)
