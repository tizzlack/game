# Pausenmenü mit Optionen, Aufgeben und Hauptmenü.
extends Control

const UI = preload("res://scripts/ui/ui_kit.gd")
const Options = preload("res://scripts/ui/options_menu.gd")

signal resume
signal give_up
signal to_menu

var box: VBoxContainer
var sub: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	box = UI.vbox(14)
	box.add_child(UI.title(L.t("paused"), 56))
	box.add_child(UI.spacer(10))
	box.add_child(UI.button(L.t("resume"), func(): resume.emit()))
	box.add_child(UI.button(L.t("options"), _open_options))
	box.add_child(UI.button(L.t("give_up"), func(): give_up.emit()))
	box.add_child(UI.button(L.t("main_menu"), func(): to_menu.emit()))
	var info := UI.label(L.t("run_info") % [Run.label(), UI.fmt_num(Run.score), UI.fmt_num(Run.credits)], 16, UI.DIM, "mono")
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(UI.spacer(8))
	box.add_child(info)
	add_child(UI.center(box))
	await get_tree().process_frame
	if is_inside_tree():
		box.get_child(2).grab_focus()

func _open_options() -> void:
	box.visible = false
	sub = Options.new()
	sub.closed.connect(func():
		sub.queue_free()
		sub = null
		box.visible = true
		box.get_child(3).grab_focus())
	add_child(sub)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if sub:
			sub.close()
		else:
			resume.emit()
