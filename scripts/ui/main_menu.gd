# Hauptmenü mit animiertem Neon-Hintergrund und Unterseiten: Run-Setup, Tägliche Herausforderung, Werkstatt, Erfolge, Statistik, Optionen.
extends Control

const UI = preload("res://scripts/ui/ui_kit.gd")
const Data = preload("res://scripts/core/data.gd")
const Background = preload("res://scripts/world/background.gd")
const MenuScene = preload("res://scripts/ui/menu_scene.gd")
const Options = preload("res://scripts/ui/options_menu.gd")

signal start_run(opts: Dictionary)
signal quit_game

var content: Control
var bank_label: Label
var sel_weapon := "blaster"
var sel_heat := 0
var sel_mutators: Array = []
var screen := "home"
var net_message := ""
var host_mode := "coop"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	var bgl := CanvasLayer.new()
	bgl.layer = -10
	add_child(bgl)
	var bg := Background.new()
	bg.setup(Data.PALETTES[0], 7)
	bg.auto_scroll = 60.0
	bgl.add_child(bg)
	var scene := MenuScene.new()
	bgl.add_child(scene)
	sel_weapon = Save.data.get("weapon", "blaster")
	if not Save.weapon_unlocked(sel_weapon):
		sel_weapon = "blaster"
	sel_heat = mini(Save.max_heat_unlocked(), int(Save.data.get("last_heat", 0)))
	Sfx.music("menu")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Save.bank_changed.connect(_update_bank)
	Net.lobby_changed.connect(func():
		if screen == "mp" and is_inside_tree():
			show_multiplayer())
	Net.net_error.connect(func(msg):
		net_message = msg
		if screen == "mp" and is_inside_tree():
			show_multiplayer())
	if Save.data.has("net_name"):
		Net.my_name = Save.data["net_name"]
	if Net.active:
		show_multiplayer()
	else:
		show_home()

func _clear(scr: String = "") -> void:
	screen = scr
	if content:
		content.queue_free()
	content = Control.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(content)

func _focus_first(c: Control) -> void:
	await get_tree().process_frame
	if is_instance_valid(c) and c.is_inside_tree() and c.is_visible_in_tree():
		c.grab_focus()

func _update_bank() -> void:
	if is_instance_valid(bank_label):
		bank_label.text = "$" + UI.fmt_num(Save.data["bank"])

func _header(parent: Control, text: String) -> void:
	var t := UI.title(text, 48)
	parent.add_child(t)

func _bank_corner() -> void:
	var box := UI.vbox(2)
	box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	box.offset_left = -360
	box.offset_right = -30
	box.offset_top = 24
	box.alignment = BoxContainer.ALIGNMENT_END
	var l := UI.label(L.t("bank"), 16, UI.DIM, "mono")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(l)
	bank_label = UI.label("", 34, Color(UI.GOLD.r * 1.3, UI.GOLD.g * 1.3, UI.GOLD.b * 1.3), "title")
	bank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(bank_label)
	content.add_child(box)
	_update_bank()

# --- Startseite ---
func show_home() -> void:
	_clear("home")
	var left := UI.vbox(12)
	left.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	left.offset_left = 90
	left.offset_top = -300
	left.offset_right = 500
	left.offset_bottom = 300
	left.add_theme_constant_override("separation", 9)
	var t := UI.title("GLOWLINE", 80, Color(0.5, 0.9, 1.0))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	left.add_child(t)
	var sub := UI.label(L.t("tagline"), 20, Color(1.0, 0.45, 0.6), "mono")
	left.add_child(sub)
	left.add_child(UI.spacer(14))
	var play := UI.button(L.t("play"), show_setup)
	left.add_child(play)
	var daily := UI.button(L.t("daily") + _daily_suffix(), _start_daily)
	left.add_child(daily)
	left.add_child(UI.button(L.t("multiplayer"), show_multiplayer))
	left.add_child(UI.button(L.t("workshop"), show_workshop))
	left.add_child(UI.button(L.t("achievements"), show_achievements))
	left.add_child(UI.button(L.t("stats"), show_stats))
	left.add_child(UI.button(L.t("options"), show_options))
	left.add_child(UI.button(L.t("quit"), func(): quit_game.emit()))
	for c in left.get_children():
		if c is Button:
			c.custom_minimum_size.y = 44
	content.add_child(left)
	_bank_corner()
	var best := UI.label(L.t("best_score") + ": " + UI.fmt_num(Save.stat("best_score")), 16, UI.DIM, "mono")
	best.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	best.offset_left = -400
	best.offset_top = -50
	best.offset_right = -30
	best.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	content.add_child(best)
	var ver := UI.label("v" + str(ProjectSettings.get_setting("application/config/version")), 13, Color(1, 1, 1, 0.3), "mono")
	ver.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ver.offset_left = 20
	ver.offset_top = -34
	content.add_child(ver)
	_focus_first(play)

func _daily_suffix() -> String:
	var b := Save.daily_best()
	var s := ""
	if b > 0:
		s += "  ★ " + UI.fmt_num(b)
	if int(Save.data["daily_streak"]) > 1:
		s += "  " + L.t("streak") % int(Save.data["daily_streak"])
	return s

func _start_daily() -> void:
	start_run.emit({"daily": true})

# --- Run-Setup ---
func show_setup() -> void:
	_clear("setup")
	_bank_corner()
	var p := UI.panel()
	var v := UI.vbox(14)
	p.add_child(v)
	_header(v, L.t("new_run"))
	# Waffen
	v.add_child(UI.label(L.t("weapon"), 18, UI.DIM, "mono"))
	var wrow := UI.hbox(10)
	var first: Button = null
	for id in Data.WEAPON_ORDER:
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(150, 48)
		b.text = L.t("weapon_" + id)
		var unlocked := Save.weapon_unlocked(id)
		b.disabled = not unlocked
		if not unlocked:
			b.text = "× " + b.text
		b.button_pressed = id == sel_weapon
		b.pressed.connect(func():
			sel_weapon = id
			Sfx.play("ui_select", -6.0)
			show_setup())
		b.mouse_entered.connect(func():
			if not b.disabled:
				b.grab_focus())
		wrow.add_child(b)
		if id == sel_weapon:
			first = b
	v.add_child(wrow)
	var wd := UI.label(L.t("weapon_" + sel_weapon + "_d"), 17, Color(0.8, 0.9, 1.0))
	wd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wd.custom_minimum_size = Vector2(780, 0)
	v.add_child(wd)
	# Skins
	v.add_child(UI.label(L.t("skin"), 18, UI.DIM, "mono"))
	var srow := UI.hbox(10)
	for id in Data.SKIN_ORDER:
		var sc: Color = Data.SKINS[id]["color"]
		var b := Button.new()
		b.custom_minimum_size = Vector2(96, 44)
		b.toggle_mode = true
		var ok := Save.skin_unlocked(id)
		b.disabled = not ok
		b.text = L.t("skin_" + id) if ok else "?"
		b.tooltip_text = L.t("skin_locked") % L.t("ach_" + Data.SKINS[id]["ach"]) if not ok else ""
		b.button_pressed = id == Save.data.get("skin", "frost")
		b.add_theme_color_override("font_color", sc)
		b.add_theme_color_override("font_pressed_color", Color(sc.r * 1.6, sc.g * 1.6, sc.b * 1.6))
		b.pressed.connect(func():
			Save.data["skin"] = id
			Save.save_data()
			Sfx.play("ui_select", -6.0)
			show_setup())
		srow.add_child(b)
	v.add_child(srow)
	# Hitze (Schwierigkeit)
	var hrow := UI.hbox(14)
	var hl := UI.label(L.t("heat"), 18, UI.DIM, "mono")
	hl.custom_minimum_size = Vector2(120, 0)
	hrow.add_child(hl)
	var minus := UI.button("−", func():
		sel_heat = maxi(0, sel_heat - 1)
		show_setup(), 60)
	var plus := UI.button("+", func():
		sel_heat = mini(Save.max_heat_unlocked(), sel_heat + 1)
		show_setup(), 60)
	minus.disabled = sel_heat <= 0
	plus.disabled = sel_heat >= Save.max_heat_unlocked()
	hrow.add_child(minus)
	var hv := UI.label(str(sel_heat), 30, Color(1.0, 0.55, 0.3) if sel_heat > 0 else Color(1, 1, 1), "title")
	hv.custom_minimum_size = Vector2(40, 0)
	hv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hrow.add_child(hv)
	hrow.add_child(plus)
	var hd := UI.label(L.t("heat_d") % [int(sel_heat * 15)] if sel_heat > 0 else L.t("heat_0"), 16, UI.DIM)
	hd.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hrow.add_child(hd)
	v.add_child(hrow)
	if Save.max_heat_unlocked() == 0:
		v.add_child(UI.label(L.t("heat_locked"), 14, Color(1, 1, 1, 0.35), "mono"))
	# Modifikatoren
	if Save.mutators_unlocked():
		v.add_child(UI.label(L.t("mutators"), 18, UI.DIM, "mono"))
		var mrow := HFlowContainer.new()
		mrow.add_theme_constant_override("h_separation", 10)
		mrow.add_theme_constant_override("v_separation", 10)
		mrow.custom_minimum_size = Vector2(780, 0)
		for id in Data.MUTATOR_ORDER:
			var b := Button.new()
			b.toggle_mode = true
			b.button_pressed = id in sel_mutators
			var bonus: float = Data.MUTATORS[id]["bonus"]
			b.text = L.t("mut_" + id) + ("  +%d%%$" % int(bonus * 100) if bonus > 0.0 else "")
			b.tooltip_text = L.t("mut_" + id + "_d")
			b.custom_minimum_size = Vector2(240, 44)
			b.toggled.connect(func(on):
				if on and not id in sel_mutators:
					sel_mutators.append(id)
				elif not on:
					sel_mutators.erase(id)
				Sfx.play("ui_select", -6.0))
			mrow.add_child(b)
		v.add_child(mrow)
	else:
		v.add_child(UI.label(L.t("mutators_locked"), 14, Color(1, 1, 1, 0.35), "mono"))
	v.add_child(UI.spacer(8))
	var brow := UI.hbox(16)
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	var go := UI.button(L.t("start"), _start, 280)
	brow.add_child(UI.button(L.t("back"), show_home, 200))
	brow.add_child(go)
	v.add_child(brow)
	content.add_child(UI.center(p))
	_focus_first(go if first == null else go)

func _start() -> void:
	Save.data["weapon"] = sel_weapon
	Save.data["last_heat"] = sel_heat
	Save.save_data()
	start_run.emit({"weapon": sel_weapon, "heat": sel_heat, "mutators": sel_mutators.duplicate()})

# --- Werkstatt ---
func show_workshop() -> void:
	_clear("workshop")
	_bank_corner()
	var p := UI.panel()
	var v := UI.vbox(10)
	p.add_child(v)
	_header(v, L.t("workshop"))
	var sub := UI.label(L.t("workshop_sub"), 16, UI.DIM, "mono")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(900, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := UI.vbox(8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	v.add_child(scroll)
	var first: Control = null
	list.add_child(UI.label(L.t("upgrades"), 18, UI.ACCENT, "mono"))
	for id in Data.META_ORDER:
		var lvl := Save.upgrade_level(id)
		var mx: int = Data.META[id]["max"]
		var maxed := lvl >= mx
		var cost := Save.upgrade_cost(id)
		var b := _shop_row(list, L.t("meta_" + id), L.t("meta_" + id + "_d"), "%d/%d" % [lvl, mx],
			L.t("maxed") if maxed else "$" + UI.fmt_num(cost), maxed or Save.data["bank"] < cost)
		b.pressed.connect(func():
			if Save.buy_upgrade(id):
				Sfx.play("buy")
				show_workshop())
		if first == null:
			first = b
	list.add_child(UI.spacer(8))
	list.add_child(UI.label(L.t("weapons"), 18, UI.ACCENT, "mono"))
	for id in Data.WEAPON_ORDER:
		if id == "blaster":
			continue
		var owned := Save.weapon_unlocked(id)
		var cost: int = Data.WEAPONS[id]["cost"]
		var b := _shop_row(list, L.t("weapon_" + id), L.t("weapon_" + id + "_d"), "", L.t("owned") if owned else "$" + UI.fmt_num(cost), owned or Save.data["bank"] < cost)
		b.pressed.connect(func():
			if Save.buy_weapon(id):
				Sfx.play("buy")
				show_workshop())
	v.add_child(UI.spacer(6))
	var back := UI.button(L.t("back"), show_home, 220)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(back)
	content.add_child(UI.center(p))
	_focus_first(first if first and not (first as Button).disabled else back)

func _shop_row(list: VBoxContainer, title: String, desc: String, level: String, price: String, disabled: bool) -> Button:
	var row := UI.hbox(16)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var info := UI.vbox(0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tl := UI.label(title + ("   " + level if level != "" else ""), 20, Color(0.9, 0.97, 1.0))
	info.add_child(tl)
	var dl := UI.label(desc, 15, UI.DIM)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(dl)
	row.add_child(info)
	var b := UI.button(price, func(): pass, 170)
	b.disabled = disabled
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(b)
	list.add_child(row)
	return b

# --- Erfolge ---
func show_achievements() -> void:
	_clear("achievements")
	var p := UI.panel()
	var v := UI.vbox(10)
	p.add_child(v)
	var got: int = Save.data["achievements"].size()
	_header(v, L.t("achievements") + "  %d/%d" % [got, Data.ACH_ORDER.size()])
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(860, 480)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(grid)
	for id in Data.ACH_ORDER:
		var has := Save.has_achievement(id)
		var box := UI.vbox(0)
		box.custom_minimum_size = Vector2(410, 0)
		var c := UI.GOLD if has else Color(0.5, 0.55, 0.65)
		box.add_child(UI.label(("★ " if has else "☆ ") + L.t("ach_" + id), 20, c))
		var d := UI.label(L.t("ach_" + id + "_d"), 14, UI.DIM if has else Color(0.45, 0.5, 0.6))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(d)
		grid.add_child(box)
	v.add_child(scroll)
	var back := UI.button(L.t("back"), show_home, 220)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(back)
	content.add_child(UI.center(p))
	_focus_first(back)

# --- Statistik ---
func show_stats() -> void:
	_clear("stats")
	var p := UI.panel()
	var v := UI.vbox(10)
	p.add_child(v)
	_header(v, L.t("stats"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 60)
	grid.add_theme_constant_override("v_separation", 8)
	var rows := [
		["stat_runs", UI.fmt_num(Save.stat("runs"))],
		["stat_wins", UI.fmt_num(Save.stat("wins"))],
		["stat_kills", UI.fmt_num(Save.stat("kills"))],
		["stat_bosses", UI.fmt_num(Save.stat("bosses"))],
		["best_score", UI.fmt_num(Save.stat("best_score"))],
		["best_combo", UI.fmt_num(Save.stat("best_combo"))],
		["stat_heat", str(maxi(0, int(Save.stat("best_heat_won")))) if int(Save.stat("best_heat_won")) >= 0 else "-"],
		["stat_credits", "$" + UI.fmt_num(Save.stat("total_credits"))],
		["stat_time", UI.fmt_time(Save.stat("play_time"))],
		["stat_streak", str(Save.data["daily_streak"])],
	]
	for r in rows:
		grid.add_child(UI.label(L.t(r[0]), 20, UI.DIM))
		var val := UI.label(r[1], 20, Color(1, 1, 1), "mono")
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(val)
	v.add_child(grid)
	v.add_child(UI.spacer(10))
	var back := UI.button(L.t("back"), show_home, 220)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(back)
	content.add_child(UI.center(p))
	_focus_first(back)

func show_options() -> void:
	_clear("options")
	var o := Options.new()
	o.closed.connect(show_home)
	content.add_child(o)

# --- Multiplayer ---
func show_multiplayer() -> void:
	_clear("mp")
	var p := UI.panel()
	var v := UI.vbox(12)
	p.add_child(v)
	if not Net.active:
		_header(v, L.t("multiplayer"))
		var name_row := UI.hbox(14)
		var nl := UI.label(L.t("net_name"), 18, UI.DIM, "mono")
		nl.custom_minimum_size = Vector2(160, 0)
		name_row.add_child(nl)
		var ne := LineEdit.new()
		ne.text = Net.my_name
		ne.max_length = 16
		ne.custom_minimum_size = Vector2(320, 42)
		ne.text_changed.connect(func(tx):
			Net.my_name = tx if tx.strip_edges() != "" else "Player"
			Save.data["net_name"] = Net.my_name)
		name_row.add_child(ne)
		v.add_child(name_row)
		var mode_row := UI.hbox(10)
		var ml := UI.label(L.t("net_mode"), 18, UI.DIM, "mono")
		ml.custom_minimum_size = Vector2(160, 0)
		mode_row.add_child(ml)
		for m in ["coop", "versus"]:
			var b := Button.new()
			b.toggle_mode = true
			b.button_pressed = host_mode == m
			b.text = L.t("net_" + m)
			b.custom_minimum_size = Vector2(200, 44)
			b.pressed.connect(func():
				host_mode = m
				show_multiplayer())
			mode_row.add_child(b)
		v.add_child(mode_row)
		v.add_child(UI.spacer(4))
		var host_btn := UI.button(L.t("net_create"), func():
			Net.mode = host_mode
			net_message = ""
			Net.host_auto(), 420)
		v.add_child(host_btn)
		v.add_child(UI.label(L.t("net_via_steam") if Net.steam_available() else L.t("net_steam_off"), 13, Color(1, 1, 1, 0.45), "mono"))
		if Net.steam_available():
			v.add_child(UI.button(L.t("net_host_lan"), func():
				Net.mode = host_mode
				net_message = ""
				Net.host_lan(), 420))
		v.add_child(UI.spacer(6))
		v.add_child(UI.label(L.t("net_enter_code"), 16, UI.ACCENT, "mono"))
		var join_row := UI.hbox(10)
		var code := LineEdit.new()
		code.placeholder_text = "QX7K2M"
		code.text = Save.data.get("net_code", "")
		code.max_length = 15
		code.custom_minimum_size = Vector2(250, 44)
		code.add_theme_font_override("font", UI.font("mono"))
		code.add_theme_font_size_override("font_size", 24)
		var do_join := func():
			net_message = ""
			Save.data["net_code"] = code.text
			Save.save_data()
			Net.join_code(code.text)
		code.text_submitted.connect(func(_t): do_join.call())
		join_row.add_child(code)
		join_row.add_child(UI.button(L.t("net_join"), do_join, 160))
		v.add_child(join_row)
		if net_message != "":
			v.add_child(UI.label(net_message, 15, UI.RED, "mono"))
		var back := UI.button(L.t("back"), show_home, 220)
		back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(back)
		content.add_child(UI.center(p))
		_focus_first(host_btn)
		return
	# Lobby
	_header(v, L.t("net_lobby") + "  ·  " + L.t("net_" + Net.mode))
	if Net.is_host and Net.lobby_code != "":
		var crow := UI.hbox(16)
		crow.alignment = BoxContainer.ALIGNMENT_CENTER
		crow.add_child(UI.label(L.t("net_code"), 18, UI.DIM, "mono"))
		var cl := UI.label(Net.lobby_code, 40, Color(1.0, 0.9, 0.5), "mono")
		crow.add_child(cl)
		crow.add_child(UI.button(L.t("net_copy"), func():
			DisplayServer.clipboard_set(Net.lobby_code)
			Sfx.play("coin", -6.0), 150))
		v.add_child(crow)
		v.add_child(UI.label(L.t("net_code_hint"), 13, Color(1, 1, 1, 0.45), "mono"))
	if Net.players.is_empty():
		v.add_child(UI.label(L.t("net_connecting"), 18, UI.DIM, "mono"))
	for id in Net.players:
		var info: Dictionary = Net.players[id]
		var tag := "  [HOST]" if id == 1 else ""
		var rd: String = L.t("net_ready") if info.get("ready", false) or id == 1 else L.t("net_not_ready")
		var row := UI.hbox(20)
		var nm := UI.label(str(info.get("name", "?")) + tag, 20, Color(1.0, 0.85, 0.4) if id == Net.my_id() else Color(0.9, 0.95, 1.0))
		nm.custom_minimum_size = Vector2(300, 0)
		row.add_child(nm)
		row.add_child(UI.label(L.t("weapon_" + str(info.get("weapon", "blaster"))), 16, UI.DIM, "mono"))
		var rl := UI.label(rd, 16, UI.GREEN if rd == L.t("net_ready") else UI.DIM, "mono")
		rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(rl)
		row.custom_minimum_size = Vector2(640, 0)
		v.add_child(row)
	if Net.is_host and not Net.use_steam:
		v.add_child(UI.label(L.t("net_your_ip") + ": " + Net.local_ip() + "  (Port %d)" % Net.PORT, 13, UI.DIM, "mono"))
	if Net.players.size() < 2:
		v.add_child(UI.label(L.t("net_need_players"), 15, Color(1, 1, 1, 0.45), "mono"))
	v.add_child(UI.spacer(6))
	var brow := UI.hbox(14)
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	var first: Button
	if Net.is_host:
		var mode_btn := UI.button(L.t("net_mode") + ": " + L.t("net_" + Net.mode), func():
			Net.set_mode("versus" if Net.mode == "coop" else "coop"), 260)
		brow.add_child(mode_btn)
		var start := UI.button(L.t("start"), func(): Net.start_game(), 200)
		start.disabled = not Net.all_ready()
		brow.add_child(start)
		first = start if not start.disabled else mode_btn
	else:
		var me: Dictionary = Net.players.get(Net.my_id(), {})
		var is_ready: bool = me.get("ready", false)
		var rb := UI.button(L.t("net_not_ready") if is_ready else L.t("net_ready_btn"), func(): Net.set_ready(not is_ready), 260)
		brow.add_child(rb)
		first = rb
	if Net.use_steam:
		brow.add_child(UI.button(L.t("net_invite"), func(): Net.invite_friends(), 220))
	brow.add_child(UI.button(L.t("net_leave"), func():
		Net.leave()
		show_multiplayer(), 200))
	v.add_child(brow)
	v.add_child(UI.label(L.t("net_hint"), 13, Color(1, 1, 1, 0.4), "mono"))
	content.add_child(UI.center(p))
	_focus_first(first)

func _unhandled_input(event: InputEvent) -> void:
	if screen == "mp" and Net.active:
		return
	if event.is_action_pressed("ui_cancel") and content and not content.get_child_count() == 0:
		# Options-Seite behandelt Abbrechen selbst
		if content.get_child(0) is Options:
			return
		get_viewport().set_input_as_handled()
		Sfx.play("ui_back", -6.0)
		show_home()
