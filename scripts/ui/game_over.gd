# Ergebnis-Bildschirm nach Tod oder Sieg; bei Sieg zuerst die Wahl: Endlos weiter oder Run beenden.
extends Control

const UI = preload("res://scripts/ui/ui_kit.gd")

signal retry
signal to_menu
signal continue_endless
signal finish_run

var summary: Dictionary = {}
var victory_pending := false
var first_btn: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var v := UI.vbox(12)
	if victory_pending:
		_build_victory_choice(v)
	else:
		_build_summary(v)
	add_child(UI.center(v))
	await get_tree().process_frame
	if is_inside_tree() and first_btn:
		first_btn.grab_focus()

func _build_victory_choice(v: VBoxContainer) -> void:
	v.add_child(UI.title(L.t("victory"), 64, UI.GOLD))
	var s := UI.label(L.t("victory_sub"), 20, UI.DIM)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	v.add_child(UI.spacer(16))
	first_btn = UI.button(L.t("continue_endless"), func(): continue_endless.emit(), 380)
	v.add_child(first_btn)
	v.add_child(UI.button(L.t("finish_run"), func(): finish_run.emit(), 380))
	var hint := UI.label(L.t("endless_hint"), 15, UI.DIM, "mono")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)

func _build_summary(v: VBoxContainer) -> void:
	var won: bool = summary.get("victory", false)
	v.add_child(UI.title(L.t("run_complete") if won else L.t("game_over"), 60, UI.GOLD if won else UI.RED))
	v.add_child(UI.spacer(6))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 6)
	_row(grid, L.t("reached"), summary.get("label", "-"))
	_row(grid, L.t("score"), UI.fmt_num(summary.get("score", 0)) + ("  " + L.t("new_best") if summary.get("best", false) else ""))
	_row(grid, L.t("kills"), str(summary.get("kills", 0)))
	_row(grid, L.t("best_combo"), str(summary.get("best_combo", 0)))
	_row(grid, L.t("time"), UI.fmt_time(summary.get("time", 0.0)))
	_row(grid, L.t("credits_earned"), "$" + UI.fmt_num(summary.get("credits", 0)))
	if summary.get("bonus", 0) > 0:
		_row(grid, L.t("victory_bonus"), "+$" + UI.fmt_num(summary.get("bonus", 0)))
	_row(grid, L.t("bank"), "$" + UI.fmt_num(Save.data["bank"]))
	if Run.daily:
		_row(grid, L.t("daily_best"), UI.fmt_num(Save.daily_best()) + ("  " + L.t("new_best") if summary.get("daily_best", false) else ""))
	v.add_child(UI.center(grid))
	var achs: Array = summary.get("achievements", [])
	if achs.size() > 0:
		v.add_child(UI.spacer(6))
		var names: Array = []
		for a in achs:
			names.append(L.t("ach_" + a))
		var al := UI.label(L.t("new_achievements") + ": " + ", ".join(names), 17, UI.GOLD, "mono")
		al.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		al.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		al.custom_minimum_size = Vector2(700, 0)
		v.add_child(al)
	v.add_child(UI.spacer(14))
	var tip := UI.label(L.t("tip_workshop"), 16, UI.DIM, "mono")
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tip)
	v.add_child(UI.spacer(6))
	var row := UI.hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	first_btn = UI.button(L.t("retry"), func(): retry.emit(), 260)
	row.add_child(first_btn)
	row.add_child(UI.button(L.t("main_menu"), func(): to_menu.emit(), 260))
	v.add_child(row)

func _row(grid: GridContainer, k: String, val: String) -> void:
	var a := UI.label(k, 20, UI.DIM)
	var b := UI.label(val, 20, Color(1, 1, 1), "mono")
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(a)
	grid.add_child(b)

func _unhandled_input(event: InputEvent) -> void:
	if not victory_pending and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		retry.emit()
