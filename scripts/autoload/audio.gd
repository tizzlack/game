# Sounds und Musik. Dateien kommen aus freien Quellen (CC0 / CC BY, siehe CREDITS.md), gebaut mit tools/build_audio.py.
extends Node

const SFX := ["shoot_blaster", "shoot_scatter", "shoot_pulse", "shoot_rail", "shoot_rocket", "enemy_shoot", "sniper_shot",
	"hit", "crit", "enemy_die", "explosion", "big_explosion", "jump", "land", "dash", "coin", "heal", "hurt", "shield",
	"checkpoint", "card", "ui_move", "ui_select", "ui_back", "boss_intro", "clear", "game_over", "lightning", "charge",
	"laser", "buy", "achievement", "combo"]
# Playlists: mehrere Stücke laufen nacheinander, ein einzelnes Stück wird geloopt
const MUSIC := {"menu": ["menu"], "run": ["run_1", "run_2", "run_3", "run_4"], "boss": ["boss"]}
const POOL_SIZE := 24

var streams := {}
var music_streams := {}
var pool: Array[AudioStreamPlayer] = []
var pool_i := 0
var last_play := {}
var music_a: AudioStreamPlayer
var music_b: AudioStreamPlayer
var current_music := ""
var track_i := {}  # Playlist -> aktuelles Stück

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	for n in SFX:
		var path := "res://assets/audio/sfx/%s.wav" % n
		if ResourceLoader.exists(path):
			streams[n] = load(path)
	for list_name in MUSIC:
		var tracks: Array = []
		for n in MUSIC[list_name]:
			var path := "res://assets/audio/music/%s.ogg" % n
			if ResourceLoader.exists(path):
				var st: AudioStreamOggVorbis = load(path)
				st.loop = MUSIC[list_name].size() == 1
				tracks.append(st)
		if not tracks.is_empty():
			music_streams[list_name] = tracks
			track_i[list_name] = randi() % tracks.size()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		pool.append(p)
	music_a = AudioStreamPlayer.new()
	music_b = AudioStreamPlayer.new()
	for m in [music_a, music_b]:
		m.bus = "Music"
		add_child(m)
		m.finished.connect(_on_track_finished.bind(m))
	apply_volumes()

func _ensure_buses() -> void:
	for b in ["Music", "SFX"]:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")

func apply_volumes() -> void:
	_ensure_buses()
	_set_bus("Master", Save.setting("master"))
	_set_bus("Music", Save.setting("music"))
	_set_bus("SFX", Save.setting("sfx"))

func _set_bus(bus: String, lin: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(lin, 0.0001)))
		AudioServer.set_bus_mute(i, lin <= 0.001)

func play(n: String, vol_db: float = 0.0, pitch: float = 1.0, pitch_var: float = 0.06) -> void:
	if not streams.has(n):
		return
	var now := Time.get_ticks_msec()
	if now - int(last_play.get(n, -1000)) < 35:
		return
	last_play[n] = now
	var p := pool[pool_i]
	pool_i = (pool_i + 1) % POOL_SIZE
	p.stream = streams[n]
	p.volume_db = vol_db
	p.pitch_scale = maxf(0.1, pitch * (1.0 + randf_range(-pitch_var, pitch_var)))
	p.play()

# Leiser, je weiter die Quelle von der Kamera entfernt ist
func play_at(n: String, pos: Vector2, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	var vp := get_viewport()
	var center := vp.get_camera_2d().get_screen_center_position() if vp.get_camera_2d() else pos
	var d := pos.distance_to(center)
	if d > 1400.0:
		return
	play(n, vol_db - clampf((d - 300.0) / 1100.0, 0.0, 1.0) * 14.0, pitch)

func music(n: String, fade: float = 1.2) -> void:
	if n == current_music or not music_streams.has(n):
		return
	current_music = n
	# Beim Wiedereinstieg in eine Playlist das nächste Stück nehmen (Abwechslung zwischen den Welten)
	var tracks: Array = music_streams[n]
	track_i[n] = (int(track_i.get(n, 0)) + 1) % tracks.size()
	_crossfade(tracks[track_i[n]], fade)

# Ende eines Stücks aus einer Playlist -> nächstes Stück
func _on_track_finished(m: AudioStreamPlayer) -> void:
	if current_music == "" or not music_streams.has(current_music):
		return
	var tracks: Array = music_streams[current_music]
	if m.stream not in tracks:
		return
	track_i[current_music] = (int(track_i.get(current_music, 0)) + 1) % tracks.size()
	m.stream = tracks[track_i[current_music]]
	m.volume_db = 0.0
	m.play()

func _crossfade(stream: AudioStream, fade: float) -> void:
	var old := music_a if music_a.playing else music_b
	var nxt := music_b if old == music_a else music_a
	nxt.stream = stream
	nxt.volume_db = -40.0
	nxt.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(nxt, "volume_db", 0.0, fade)
	if old.playing:
		tw.tween_property(old, "volume_db", -40.0, fade)
		tw.chain().tween_callback(old.stop)

func stop_music(fade: float = 1.0) -> void:
	current_music = ""
	for m in [music_a, music_b]:
		if m.playing:
			var tw := create_tween()
			tw.tween_property(m, "volume_db", -40.0, fade)
			tw.tween_callback(m.stop)
