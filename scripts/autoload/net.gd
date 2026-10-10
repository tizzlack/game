# Online-Multiplayer: Lobby über Steam (GodotSteam + SteamMultiplayerPeer) oder LAN/IP (ENet).
# Alle Spiel-Nachrichten laufen als RPC über diesen Autoload und werden an das laufende Spiel weitergereicht.
# Prinzip: Jeder steuert seine eigene Figur (keine Eingabeverzögerung), der Host berechnet die Gegner.
extends Node

signal lobby_changed
signal net_error(msg: String)
signal session_started(opts: Dictionary)
signal session_ended

const PORT := 24575
const MAX_PLAYERS := 4

var active := false
var is_host := false
var use_steam := false
var mode := "coop"  # coop | versus
var players := {}  # peer_id -> {"name", "skin", "weapon", "ready"}
var my_name := ""
var lobby_id := 0
var lobby_code := ""
var in_game := false
const CODE_CHARS := "ABCDEFGHJKMNPQRSTUVWXYZ23456789"  # ohne L, I, O, 0, 1 (L markiert LAN-Codes)
var game  # laufendes game.gd

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	my_name = OS.get_environment("USERNAME") if OS.has_environment("USERNAME") else OS.get_environment("USER")
	if SteamService.my_name() != "":
		my_name = SteamService.my_name()
	if my_name == "":
		my_name = "Player"
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func(): _fail(L.t("net_failed")))
	multiplayer.server_disconnected.connect(func(): _fail(L.t("net_host_left")))
	_connect_steam()

func my_id() -> int:
	return multiplayer.get_unique_id() if active else 1

func is_server() -> bool:
	return not active or multiplayer.is_server()

func player_count() -> int:
	return maxi(1, players.size())

func my_info() -> Dictionary:
	return {"name": my_name, "skin": Save.data.get("skin", "frost"), "weapon": Save.data.get("weapon", "blaster"), "ready": false}

func steam_available() -> bool:
	return SteamService.enabled and ClassDB.class_exists("SteamMultiplayerPeer")

# --- Verbinden ---
func host_lan() -> bool:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS - 1)
	if err != OK:
		_fail(L.t("net_port") % PORT)
		return false
	_begin_host(peer)
	lobby_code = encode_lan(local_ip())
	lobby_changed.emit()
	return true

# Lobby erstellen: über Steam (Relay, kein Portfreigabe nötig), sonst im LAN
func host_auto() -> void:
	if steam_available():
		host_steam()
	else:
		host_lan()

# Beitreten per Code: Steam-Code (6 Zeichen), LAN-Code (beginnt mit L) oder direkt eine IP
func join_code(code: String) -> void:
	code = code.strip_edges().to_upper().replace(" ", "")
	if code == "":
		return
	if code.count(".") == 3:
		join_lan(code)
	elif code.begins_with("L") and code.length() == 8:
		var ip := decode_lan(code)
		if ip == "":
			_fail(L.t("net_code_not_found"))
		else:
			join_lan(ip)
	elif steam_available():
		var s: Object = SteamService.steam
		s.call("addRequestLobbyListStringFilter", "game", "glowline", 0)
		s.call("addRequestLobbyListStringFilter", "code", code, 0)
		s.call("addRequestLobbyListDistanceFilter", 3)
		s.call("requestLobbyList")
	else:
		_fail(L.t("net_code_not_found"))

func local_ip() -> String:
	var best := "127.0.0.1"
	for a in IP.get_local_addresses():
		if a.count(".") != 3 or a.begins_with("127."):
			continue
		if a.begins_with("192.168.") or a.begins_with("10.") or a.begins_with("172."):
			return a
		best = a
	return best

static func encode_lan(ip: String) -> String:
	var parts := ip.split(".")
	if parts.size() != 4:
		return ""
	var v := 0
	for p in parts:
		v = v * 256 + clampi(int(p), 0, 255)
	var out := ""
	for i in 7:
		out = CODE_CHARS[v % CODE_CHARS.length()] + out
		v = v / CODE_CHARS.length()
	return "L" + out

static func decode_lan(code: String) -> String:
	var v := 0
	for ch in code.substr(1):
		var i := CODE_CHARS.find(ch)
		if i < 0:
			return ""
		v = v * CODE_CHARS.length() + i
	if v < 0 or v > 0xFFFFFFFF:
		return ""
	return "%d.%d.%d.%d" % [(v >> 24) & 255, (v >> 16) & 255, (v >> 8) & 255, v & 255]

func _random_code() -> String:
	var out := ""
	for i in 6:
		out += CODE_CHARS[randi() % CODE_CHARS.length()]
	return out

func join_lan(ip: String) -> bool:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip.strip_edges() if ip.strip_edges() != "" else "127.0.0.1", PORT)
	if err != OK:
		_fail(L.t("net_failed"))
		return false
	multiplayer.multiplayer_peer = peer
	active = true
	is_host = false
	use_steam = false
	players = {}
	lobby_changed.emit()
	return true

func host_steam() -> void:
	if not steam_available():
		_fail(L.t("net_no_steam"))
		return
	# 2 = öffentlich (nötig, damit die Lobby per Code gefunden wird), max. 4 Spieler
	SteamService.steam.call("createLobby", 2, MAX_PLAYERS)

func invite_friends() -> void:
	if use_steam and lobby_id != 0:
		SteamService.steam.call("activateGameOverlayInviteDialog", lobby_id)

func join_steam(id: int) -> void:
	if not steam_available():
		_fail(L.t("net_no_steam"))
		return
	SteamService.steam.call("joinLobby", id)

func _begin_host(peer: MultiplayerPeer) -> void:
	multiplayer.multiplayer_peer = peer
	active = true
	is_host = true
	players = {1: my_info()}
	lobby_changed.emit()

func leave() -> void:
	if use_steam and lobby_id != 0 and SteamService.enabled:
		SteamService.steam.call("leaveLobby", lobby_id)
	lobby_id = 0
	lobby_code = ""
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	active = false
	is_host = false
	use_steam = false
	in_game = false
	players = {}
	game = null
	lobby_changed.emit()
	session_ended.emit()

func _fail(msg: String) -> void:
	var was_in_game := in_game
	leave()
	net_error.emit(msg)
	if was_in_game:
		push_warning(msg)

# --- Steam-Lobby ---
func _connect_steam() -> void:
	if not SteamService.enabled:
		return
	var s: Object = SteamService.steam
	for pair in [["lobby_created", _on_lobby_created], ["lobby_joined", _on_lobby_joined], ["join_requested", _on_join_requested],
			["lobby_match_list", _on_lobby_match_list]]:
		if s.has_signal(pair[0]):
			s.connect(pair[0], pair[1])
	# Start über Steam-Einladung: +connect_lobby <id>
	var args := OS.get_cmdline_args()
	var i := args.find("+connect_lobby")
	if i >= 0 and i + 1 < args.size():
		join_steam.call_deferred(int(args[i + 1]))

func _on_lobby_created(result: int, id: int) -> void:
	if result != 1:
		_fail(L.t("net_failed"))
		return
	lobby_id = id
	use_steam = true
	var peer: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
	peer.call("create_host", 0)
	lobby_code = _random_code()
	SteamService.steam.call("setLobbyData", id, "name", my_name + "'s GLOWLINE")
	SteamService.steam.call("setLobbyData", id, "game", "glowline")
	SteamService.steam.call("setLobbyData", id, "code", lobby_code)
	SteamService.steam.call("setLobbyJoinable", id, true)
	_begin_host(peer)

func _on_lobby_joined(id: int, _perms: int, _locked: bool, response: int) -> void:
	if response != 1:
		_fail(L.t("net_failed"))
		return
	var owner: int = SteamService.steam.call("getLobbyOwner", id)
	if owner == SteamService.steam.call("getSteamID"):
		return  # eigene Lobby
	lobby_id = id
	use_steam = true
	var peer: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
	peer.call("create_client", owner, 0)
	multiplayer.multiplayer_peer = peer
	active = true
	is_host = false
	players = {}
	lobby_changed.emit()

func _on_lobby_match_list(lobbies: Array) -> void:
	if lobbies.is_empty():
		_fail(L.t("net_code_not_found"))
		return
	join_steam(int(lobbies[0]))

func _on_join_requested(id: int, _friend: int) -> void:
	if active:
		leave()
	join_steam(id)

# --- Lobby-Verwaltung ---
func _on_connected() -> void:
	register.rpc_id(1, my_info())

func _on_peer_connected(_id: int) -> void:
	pass  # Spieler meldet sich mit register()

func _on_peer_disconnected(id: int) -> void:
	players.erase(id)
	if game:
		game.net_peer_left(id)
	if is_host:
		_sync_lobby()
	lobby_changed.emit()

@rpc("any_peer", "reliable")
func register(info: Dictionary) -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	if in_game or players.size() >= MAX_PLAYERS:
		kick.rpc_id(id, L.t("net_full"))
		return
	info["ready"] = false
	players[id] = info
	_sync_lobby()

@rpc("authority", "reliable")
func kick(msg: String) -> void:
	_fail(msg)

func _sync_lobby() -> void:
	lobby_sync.rpc(players, mode)
	lobby_changed.emit()

@rpc("authority", "reliable")
func lobby_sync(p: Dictionary, m: String) -> void:
	players = p
	mode = m
	lobby_changed.emit()

func set_mode(m: String) -> void:
	if is_host:
		mode = m
		_sync_lobby()

func set_ready(r: bool) -> void:
	if is_host:
		players[1]["ready"] = r
		_sync_lobby()
	else:
		ready_changed.rpc_id(1, r, Save.data.get("skin", "frost"), Save.data.get("weapon", "blaster"))

@rpc("any_peer", "reliable")
func ready_changed(r: bool, skin: String, weapon: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	if is_host and players.has(id):
		players[id]["ready"] = r
		players[id]["skin"] = skin
		players[id]["weapon"] = weapon
		_sync_lobby()

func all_ready() -> bool:
	if players.size() < 2:
		return false
	for id in players:
		if id != 1 and not players[id]["ready"]:
			return false
	return true

func start_game() -> void:
	if not is_host:
		return
	players[1]["skin"] = Save.data.get("skin", "frost")
	players[1]["weapon"] = Save.data.get("weapon", "blaster")
	_sync_lobby()
	begin.rpc({"seed": randi(), "mode": mode})

@rpc("authority", "reliable", "call_local")
func begin(opts: Dictionary) -> void:
	in_game = true
	session_started.emit(opts)

func back_to_lobby() -> void:
	in_game = false
	game = null
	for id in players:
		players[id]["ready"] = false
	lobby_changed.emit()

# --- Spiel-Nachrichten (an game.gd weitergereicht) ---
func _g() -> bool:
	return game != null and is_instance_valid(game)

@rpc("any_peer", "unreliable_ordered")
func p_state(data: PackedFloat32Array) -> void:
	if _g():
		game.net_player_state(multiplayer.get_remote_sender_id(), data)

@rpc("any_peer", "unreliable")
func p_shot(origin: Vector2, vels: PackedVector2Array, weapon_id: String, crit: bool) -> void:
	if _g():
		game.net_remote_shot(multiplayer.get_remote_sender_id(), origin, vels, weapon_id, crit)

@rpc("any_peer", "reliable")
func carve(pos: Vector2, radius: float, normal: Vector2, seed_value: int) -> void:
	if _g():
		game.net_carve(pos, radius, normal, seed_value)

@rpc("any_peer", "reliable")
func fx_explosion(pos: Vector2, radius: float) -> void:
	if _g():
		game.net_fx_explosion(pos, radius)

@rpc("authority", "unreliable_ordered")
func e_snap(data: PackedFloat32Array) -> void:
	if _g():
		game.net_enemy_snapshot(data)

@rpc("authority", "reliable")
func e_bullet(pos: Vector2, vel: Vector2, dmg: float, col: Color, size: float) -> void:
	if _g():
		game.bullets.spawn_enemy(pos, vel, dmg, col, size, true)

@rpc("authority", "reliable")
func e_spawn(kind: String, pos: Vector2, id: int) -> void:
	if _g():
		game.net_spawn_enemy(kind, pos, id)

@rpc("authority", "reliable")
func e_died(id: int, killer: int, reward: bool) -> void:
	if _g():
		game.net_enemy_died(id, killer, reward)

@rpc("any_peer", "reliable")
func hit_enemy(id: int, dmg: float, dir: Vector2, crit: bool) -> void:
	if _g() and is_host:
		game.net_hit_enemy(id, dmg, dir, crit, multiplayer.get_remote_sender_id())

@rpc("any_peer", "reliable")
func req_clear() -> void:
	if _g() and is_host:
		game.net_request_clear()

@rpc("authority", "reliable", "call_local")
func sec_clear() -> void:
	if _g():
		game.net_section_clear()

@rpc("any_peer", "reliable", "call_local")
func card_done() -> void:
	if _g() and is_host:
		game.net_card_done(multiplayer.get_remote_sender_id())

@rpc("authority", "reliable", "call_local")
func next_sec() -> void:
	if _g():
		game.net_next_section()

@rpc("any_peer", "reliable", "call_local")
func cp_reached(index: int) -> void:
	if _g():
		game.net_checkpoint(index)

@rpc("authority", "reliable", "call_local")
func run_over(victory: bool) -> void:
	if _g():
		game.net_run_over(victory)

@rpc("any_peer", "reliable")
func pvp_hit(dmg: float, from_pos: Vector2) -> void:
	if _g():
		game.net_pvp_hit(dmg, from_pos, multiplayer.get_remote_sender_id())

@rpc("any_peer", "reliable", "call_local")
func pvp_death(killer: int) -> void:
	if _g():
		game.net_pvp_death(multiplayer.get_remote_sender_id(), killer)

@rpc("authority", "reliable", "call_local")
func pvp_scores(scores: Dictionary, time_left: float) -> void:
	if _g():
		game.net_pvp_scores(scores, time_left)

@rpc("authority", "reliable", "call_local")
func pvp_end(scores: Dictionary) -> void:
	if _g():
		game.net_pvp_end(scores)
