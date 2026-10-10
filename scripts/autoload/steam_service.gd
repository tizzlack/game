# Optionale Steam-Anbindung über GodotSteam (GDExtension). Ohne GodotSteam läuft das Spiel normal, alle Aufrufe sind dann leer.
# Einrichtung: siehe STEAM.md
extends Node

# 480 = "Spacewar", Valves offizielle Test-App. Solange du keine eigene App-ID hast, laufen Lobbys,
# Einladungen und Relay-Netzwerk darüber. Später nur diese Zahl (und steam_appid.txt) ersetzen.
const APP_ID := 480
const IS_TEST_APP := APP_ID == 480

var steam: Object = null
var enabled := false
var _pending_scores := {}  # Leaderboard-Name -> Punktzahl

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not Engine.has_singleton("Steam"):
		return
	# Steam liest die App-ID auch aus der Umgebung (wichtig, wenn das Spiel nicht über Steam gestartet wird)
	OS.set_environment("SteamAppId", str(APP_ID))
	OS.set_environment("SteamGameId", str(APP_ID))
	steam = Engine.get_singleton("Steam")
	var res = _init_steam()
	var ok := false
	if typeof(res) == TYPE_DICTIONARY:
		ok = int(res.get("status", 1)) == 0
	elif typeof(res) == TYPE_BOOL:
		ok = res
	enabled = ok
	if not enabled:
		push_warning("Steam konnte nicht gestartet werden (läuft der Steam-Client?): %s" % str(res))
		return
	if steam.has_signal("leaderboard_find_result"):
		steam.connect("leaderboard_find_result", _on_leaderboard_found)
	# Bereits lokal freigeschaltete Erfolge nachtragen
	var Data = preload("res://scripts/core/data.gd")
	for id in Save.data["achievements"].keys():
		if Data.ACHIEVEMENTS.has(id):
			set_achievement(Data.ACHIEVEMENTS[id])

# GodotSteam hat je nach Version andere Parameter für steamInitEx -> passend aufrufen
func _init_steam():
	for m in steam.get_method_list():
		if m["name"] != "steamInitEx":
			continue
		var args: Array = m["args"]
		if args.size() >= 1 and str(args[0]["name"]) == "app_id":
			return steam.call("steamInitEx", APP_ID, false)
		if args.size() >= 2 and str(args[1]["name"]) == "app_id":
			return steam.call("steamInitEx", false, APP_ID)
		return steam.call("steamInitEx")
	if steam.has_method("steamInit"):
		return steam.call("steamInit")
	return false

func _process(_d: float) -> void:
	if enabled:
		steam.call("run_callbacks")

# Bildschirmtastatur von Steam (nur im Big-Picture-Modus / auf dem Steam Deck sichtbar)
func show_keyboard(rect: Rect2) -> void:
	if enabled and steam.has_method("showFloatingGamepadTextInput"):
		steam.call("showFloatingGamepadTextInput", 0, int(rect.position.x), int(rect.position.y), int(rect.size.x), int(rect.size.y))

func my_name() -> String:
	if enabled and steam.has_method("getPersonaName"):
		return str(steam.call("getPersonaName"))
	return ""

func set_achievement(api_name: String) -> void:
	# Spacewar kennt unsere Erfolge nicht -> erst mit eigener App-ID aktiv
	if not enabled or IS_TEST_APP:
		return
	steam.call("setAchievement", api_name)
	steam.call("storeStats")

func upload_score(board: String, score: int) -> void:
	if not enabled or not steam.has_method("findOrCreateLeaderboard"):
		return
	# auf der Test-App eigene Namen verwenden, damit es keine Überschneidung mit anderen Spielen gibt
	var full := ("GLOWLINE_" + board) if IS_TEST_APP else board
	_pending_scores[full] = score
	# 2 = absteigend sortiert, 1 = numerische Anzeige
	steam.call("findOrCreateLeaderboard", full, 2, 1)

func _on_leaderboard_found(handle, found) -> void:
	if not found or _pending_scores.is_empty():
		return
	var board: String = _pending_scores.keys()[0]
	var score: int = _pending_scores[board]
	_pending_scores.erase(board)
	steam.call("uploadLeaderboardScore", score, true, PackedInt32Array(), handle)
