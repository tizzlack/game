# Optionale Steam-Anbindung über GodotSteam (GDExtension). Ohne GodotSteam läuft das Spiel normal, alle Aufrufe sind dann leer.
# Einrichtung: siehe STEAM.md
extends Node

var steam: Object = null
var enabled := false
var _pending_scores := {}  # Leaderboard-Name -> Punktzahl

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not Engine.has_singleton("Steam"):
		return
	steam = Engine.get_singleton("Steam")
	var res = steam.call("steamInitEx")
	var ok := false
	if typeof(res) == TYPE_DICTIONARY:
		ok = int(res.get("status", 1)) == 0
	elif typeof(res) == TYPE_BOOL:
		ok = res
	enabled = ok
	if not enabled:
		push_warning("Steam konnte nicht gestartet werden: %s" % str(res))
		return
	if steam.has_signal("leaderboard_find_result"):
		steam.connect("leaderboard_find_result", _on_leaderboard_found)
	# Bereits lokal freigeschaltete Erfolge nachtragen
	for id in Save.data["achievements"].keys():
		var Data = preload("res://scripts/core/data.gd")
		if Data.ACHIEVEMENTS.has(id):
			set_achievement(Data.ACHIEVEMENTS[id])

func _process(_d: float) -> void:
	if enabled:
		steam.call("run_callbacks")

func set_achievement(api_name: String) -> void:
	if not enabled:
		return
	steam.call("setAchievement", api_name)
	steam.call("storeStats")

func upload_score(board: String, score: int) -> void:
	if not enabled or not steam.has_method("findOrCreateLeaderboard"):
		return
	_pending_scores[board] = score
	# 2 = absteigend sortiert, 1 = numerische Anzeige
	steam.call("findOrCreateLeaderboard", board, 2, 1)

func _on_leaderboard_found(handle, found) -> void:
	if not found or _pending_scores.is_empty():
		return
	var board: String = _pending_scores.keys()[0]
	var score: int = _pending_scores[board]
	_pending_scores.erase(board)
	steam.call("uploadLeaderboardScore", score, true, PackedInt32Array(), handle)
