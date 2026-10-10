# Dauerhafter Spielstand und Einstellungen (user://save.json).
extends Node

const Data = preload("res://scripts/core/data.gd")
var PATH := "user://save.json"
const VERSION := 1

signal achievement_unlocked(id: String)
signal bank_changed

var data: Dictionary = {}

func _ready() -> void:
	if "--autotest" in OS.get_cmdline_user_args():
		PATH = "user://save_autotest.json"
	load_data()
	apply_settings()

func defaults() -> Dictionary:
	return {
		"version": VERSION,
		"bank": 0,
		"upgrades": {},
		"weapons": ["blaster"],
		"weapon": "blaster",
		"skin": "frost",
		"achievements": {},
		"stats": {"kills": 0, "runs": 0, "wins": 0, "deaths": 0, "best_score": 0, "best_heat_won": -1,
			"total_credits": 0, "play_time": 0.0, "best_combo": 0, "bosses": 0, "loops": 0},
		"daily": {},
		"daily_streak": 0,
		"daily_last": "",
		"settings": {"master": 0.8, "music": 0.65, "sfx": 0.8, "fullscreen": true, "vsync": true,
			"shake": 1.0, "lang": "", "dmg_numbers": true, "show_fps": false, "vibration": true, "aim_assist": true},
	}

func load_data() -> void:
	data = defaults()
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Spielstand beschädigt, starte neu.")
		return
	_merge(data, parsed)

# Übernimmt gespeicherte Werte, behält aber neue Standardfelder
func _merge(dst: Dictionary, src: Dictionary) -> void:
	for k in src.keys():
		if dst.has(k) and typeof(dst[k]) == TYPE_DICTIONARY and typeof(src[k]) == TYPE_DICTIONARY and k in ["stats", "settings"]:
			_merge(dst[k], src[k])
		else:
			dst[k] = src[k]

func save_data() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Konnte Spielstand nicht schreiben.")
		return
	f.store_string(JSON.stringify(data, "\t"))

# --- Einstellungen ---
func setting(k: String):
	return data["settings"].get(k, defaults()["settings"].get(k))

func set_setting(k: String, v) -> void:
	data["settings"][k] = v
	apply_settings()
	save_data()

func apply_settings() -> void:
	if DisplayServer.get_name() != "headless" and not ("--autotest" in OS.get_cmdline_user_args()):
		var want_full: bool = setting("fullscreen")
		var mode := DisplayServer.window_get_mode()
		var is_full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		if want_full and not is_full:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif not want_full and is_full:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if setting("vsync") else DisplayServer.VSYNC_DISABLED)
	var lang: String = setting("lang")
	if lang == "":
		lang = "de" if OS.get_locale_language() == "de" else "en"
	L.set_lang(lang)
	if is_instance_valid(Sfx):
		Sfx.apply_volumes()

# --- Werkstatt ---
func upgrade_level(id: String) -> int:
	return int(data["upgrades"].get(id, 0))

func upgrade_cost(id: String) -> int:
	return Data.meta_cost(id, upgrade_level(id))

func can_buy_upgrade(id: String) -> bool:
	return upgrade_level(id) < Data.META[id]["max"] and data["bank"] >= upgrade_cost(id)

func buy_upgrade(id: String) -> bool:
	if not can_buy_upgrade(id):
		return false
	data["bank"] -= upgrade_cost(id)
	data["upgrades"][id] = upgrade_level(id) + 1
	save_data()
	bank_changed.emit()
	return true

func weapon_unlocked(id: String) -> bool:
	return id in data["weapons"]

func buy_weapon(id: String) -> bool:
	var cost: int = Data.WEAPONS[id]["cost"]
	if weapon_unlocked(id) or data["bank"] < cost:
		return false
	data["bank"] -= cost
	data["weapons"].append(id)
	data["weapon"] = id
	save_data()
	bank_changed.emit()
	if data["weapons"].size() >= Data.WEAPON_ORDER.size():
		unlock_achievement("arsenal")
	return true

func skin_unlocked(id: String) -> bool:
	var ach: String = Data.SKINS[id]["ach"]
	return ach == "" or has_achievement(ach)

func skin_color() -> Color:
	var id: String = data.get("skin", "frost")
	if not Data.SKINS.has(id) or not skin_unlocked(id):
		id = "frost"
	return Data.SKINS[id]["color"]

# --- Erfolge & Statistik ---
func has_achievement(id: String) -> bool:
	return data["achievements"].has(id)

func unlock_achievement(id: String) -> bool:
	if has_achievement(id) or not Data.ACHIEVEMENTS.has(id):
		return false
	data["achievements"][id] = Time.get_datetime_string_from_system()
	save_data()
	SteamService.set_achievement(Data.ACHIEVEMENTS[id])
	achievement_unlocked.emit(id)
	return true

func stat(k: String):
	return data["stats"].get(k, 0)

func add_stat(k: String, v) -> void:
	data["stats"][k] = data["stats"].get(k, 0) + v

func max_stat(k: String, v) -> bool:
	if v > data["stats"].get(k, 0):
		data["stats"][k] = v
		return true
	return false

func add_bank(v: int) -> void:
	data["bank"] += v
	add_stat("total_credits", v)
	if data["stats"]["total_credits"] >= 10000:
		unlock_achievement("rich")
	bank_changed.emit()

func max_heat_unlocked() -> int:
	return clampi(int(stat("best_heat_won")) + 1, 0, Data.MAX_HEAT)

func mutators_unlocked() -> bool:
	return int(stat("wins")) > 0

# --- Tägliche Herausforderung ---
static func today() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d%02d%02d" % [d.year, d.month, d.day]

func daily_best(day: String = "") -> int:
	if day == "":
		day = today()
	return int(data["daily"].get(day, 0))

func record_daily(score: int) -> bool:
	var day := today()
	var is_best := score > daily_best(day)
	if is_best:
		data["daily"][day] = score
	if data["daily_last"] != day:
		var yesterday := _yesterday()
		data["daily_streak"] = int(data["daily_streak"]) + 1 if data["daily_last"] == yesterday else 1
		data["daily_last"] = day
	unlock_achievement("daily")
	save_data()
	return is_best

static func _yesterday() -> String:
	var t := Time.get_unix_time_from_system() - 86400.0
	var d := Time.get_date_dict_from_unix_time(int(t))
	return "%04d%02d%02d" % [d.year, d.month, d.day]
