# Upgrade-Auswahl nach jedem Abschnitt: 3–4 Karten, Neu würfeln gegen Credits.
extends Control

const UI = preload("res://scripts/ui/ui_kit.gd")
const Data = preload("res://scripts/core/data.gd")

signal chosen(id: String)

var min_rarity := 0
var row: HBoxContainer
var reroll_btn: Button
var options: Array = []
var done := false
var t := 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var v := UI.vbox(22)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var head := UI.title(L.t("choose_upgrade"), 44, UI.ACCENT)
	v.add_child(head)
	var sub := UI.label(L.t("choose_upgrade_sub") % Run.label(), 18, UI.DIM, "mono")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	row = UI.hbox(22)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var bottom := UI.hbox(18)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	reroll_btn = UI.button("", _reroll, 300)
	bottom.add_child(reroll_btn)
	v.add_child(bottom)
	var build := UI.label(_build_text(), 15, Color(0.7, 0.8, 0.9, 0.7), "mono")
	build.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	build.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	build.custom_minimum_size = Vector2(900, 0)
	v.add_child(build)
	add_child(UI.center(v))
	_roll()

func _build_text() -> String:
	if Run.cards.is_empty():
		return ""
	var parts: Array = []
	for id in Run.cards.keys():
		var n: int = Run.cards[id]
		parts.append(L.t("card_" + id) + ("" if n == 1 else " x%d" % n))
	return L.t("your_build") + ": " + ", ".join(parts)

func _roll() -> void:
	for c in row.get_children():
		c.queue_free()
	options = Run.roll_cards(Run.card_choices(), min_rarity)
	if options.is_empty():
		options = ["medkit"]
	var i := 0
	for id in options:
		row.add_child(_card(id, i))
		i += 1
	_update_reroll()
	await get_tree().process_frame
	if row.get_child_count() > 0 and is_inside_tree():
		(row.get_child(row.get_child_count() - options.size()) as Control).grab_focus()

func _card(id: String, idx: int) -> Button:
	var r: int = Data.CARDS[id]["rarity"]
	var rc: Color = Data.RARITY_COLORS[r]
	var b := Button.new()
	b.custom_minimum_size = Vector2(250, 320)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.02, 0.03, 0.07, 0.95)
	normal.border_color = Color(rc.r, rc.g, rc.b, 0.6)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	var hover := normal.duplicate()
	hover.border_color = Color(rc.r * 1.6, rc.g * 1.6, rc.b * 1.6)
	hover.set_border_width_all(3)
	hover.bg_color = Color(rc.r * 0.12, rc.g * 0.12, rc.b * 0.12, 0.97)
	hover.shadow_color = Color(rc.r, rc.g, rc.b, 0.35)
	hover.shadow_size = 16
	for st in ["normal", "disabled"]:
		b.add_theme_stylebox_override(st, normal)
	for st in ["hover", "pressed", "focus", "hover_pressed"]:
		b.add_theme_stylebox_override(st, hover)
	var v := UI.vbox(10)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 18
	v.offset_right = -18
	v.offset_top = 18
	v.offset_bottom = -18
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var key := UI.label("[%d]" % (idx + 1), 14, Color(1, 1, 1, 0.35), "mono")
	v.add_child(key)
	var rl := UI.label(L.t("rarity_%d" % r), 14, rc, "mono")
	v.add_child(rl)
	var name := UI.label(L.t("card_" + id), 26, Color(rc.r * 1.4, rc.g * 1.4, rc.b * 1.4), "title")
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(name)
	v.add_child(UI.spacer(4))
	var desc := UI.label(L.t("card_" + id + "_d"), 18, Color(0.85, 0.92, 1.0))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(desc)
	var have: int = Run.cards.get(id, 0)
	var mx: int = Data.CARDS[id]["max"]
	if mx > 1 and mx < 99:
		v.add_child(UI.label("%d / %d" % [have, mx], 15, Color(1, 1, 1, 0.45), "mono"))
	for c in v.get_children():
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	b.pressed.connect(func(): _pick(id))
	b.focus_entered.connect(func(): Sfx.play("ui_move", -12.0))
	b.mouse_entered.connect(func(): b.grab_focus())
	return b

func _update_reroll() -> void:
	var cost := Run.reroll_cost()
	if cost == 0:
		reroll_btn.text = L.t("reroll_free") % Run.free_rerolls
	else:
		reroll_btn.text = L.t("reroll") % cost
	reroll_btn.disabled = cost > Run.credits

func _reroll() -> void:
	if done:
		return
	var cost := Run.reroll_cost()
	if cost > Run.credits:
		return
	if cost == 0:
		Run.free_rerolls -= 1
	else:
		Run.credits -= cost
		Run.rerolls_paid += 1
	Sfx.play("card", -6.0, 1.3)
	_roll()

func _pick(id: String) -> void:
	if done:
		return
	done = true
	chosen.emit(id)

func _unhandled_input(event: InputEvent) -> void:
	if done:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.keycode
		if k >= KEY_1 and k <= KEY_4:
			var i := k - KEY_1
			if i < options.size():
				_pick(options[i])
				get_viewport().set_input_as_handled()
	if event.is_action_pressed("reroll"):
		_reroll()
		get_viewport().set_input_as_handled()
