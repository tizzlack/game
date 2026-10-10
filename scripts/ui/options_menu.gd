# Optionen: Lautstärke, Vollbild, VSync, Bildschirmwackeln, Sprache, Schadenszahlen, FPS. Wird in Haupt- und Pausenmenü genutzt.
extends Control

const UI = preload("res://scripts/ui/ui_kit.gd")

signal closed

var first: Control

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var p := UI.panel()
	var v := UI.vbox(14)
	p.add_child(v)
	v.add_child(UI.title(L.t("options"), 44))
	v.add_child(UI.spacer(6))
	first = _slider(v, "vol_master", "master")
	_slider(v, "vol_music", "music")
	_slider(v, "vol_sfx", "sfx")
	_slider(v, "screen_shake", "shake")
	_check(v, "fullscreen", "fullscreen")
	_check(v, "vsync", "vsync")
	_check(v, "dmg_numbers", "dmg_numbers")
	_check(v, "show_fps", "show_fps")
	var lang_row := UI.hbox(20)
	var ll := UI.label(L.t("language"), 20)
	ll.custom_minimum_size = Vector2(260, 0)
	lang_row.add_child(ll)
	var ob := OptionButton.new()
	ob.add_item("Deutsch", 0)
	ob.add_item("English", 1)
	ob.selected = 0 if L.lang == "de" else 1
	ob.custom_minimum_size = Vector2(260, 44)
	ob.item_selected.connect(func(i):
		Save.set_setting("lang", "de" if i == 0 else "en")
		Sfx.play("ui_select", -6.0))
	lang_row.add_child(ob)
	v.add_child(lang_row)
	var hint := UI.label(L.t("controls_info"), 15, UI.DIM, "mono")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(560, 0)
	v.add_child(UI.spacer(4))
	v.add_child(hint)
	v.add_child(UI.spacer(4))
	var back := UI.button(L.t("back"), close)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(back)
	add_child(UI.center(p))
	await get_tree().process_frame
	if is_inside_tree() and first:
		first.grab_focus()

func _slider(parent: Control, key: String, setting: String) -> HSlider:
	var row := UI.hbox(20)
	var l := UI.label(L.t(key), 20)
	l.custom_minimum_size = Vector2(260, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = Save.setting(setting)
	s.custom_minimum_size = Vector2(260, 30)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var val := UI.label("%d%%" % int(s.value * 100), 18, UI.DIM, "mono")
	val.custom_minimum_size = Vector2(60, 0)
	s.value_changed.connect(func(x):
		val.text = "%d%%" % int(x * 100)
		Save.data["settings"][setting] = x
		Sfx.apply_volumes()
		if setting == "sfx":
			Sfx.play("coin", -6.0))
	s.drag_ended.connect(func(_c): Save.save_data())
	s.focus_exited.connect(func(): Save.save_data())
	row.add_child(s)
	row.add_child(val)
	parent.add_child(row)
	return s

func _check(parent: Control, key: String, setting: String) -> void:
	var row := UI.hbox(20)
	var l := UI.label(L.t(key), 20)
	l.custom_minimum_size = Vector2(260, 0)
	row.add_child(l)
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = Save.setting(setting)
	b.text = L.t("on") if b.button_pressed else L.t("off")
	b.custom_minimum_size = Vector2(260, 44)
	b.toggled.connect(func(on):
		b.text = L.t("on") if on else L.t("off")
		Sfx.play("ui_select", -6.0)
		Save.set_setting(setting, on))
	b.mouse_entered.connect(func(): b.grab_focus())
	row.add_child(b)
	parent.add_child(row)

func close() -> void:
	Save.save_data()
	Sfx.play("ui_back", -6.0)
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
