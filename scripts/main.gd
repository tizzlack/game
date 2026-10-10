# Einstiegspunkt: Glow-Umgebung, Bildschirmwechsel mit Überblendung (Menü <-> Spiel), Testbot.
extends Node

const MainMenu = preload("res://scripts/ui/main_menu.gd")
const Game = preload("res://scripts/game/game.gd")
const PostFx = preload("res://scripts/game/post_fx.gd")

var current: Node
var fade_rect: ColorRect
var fading := false
var last_opts: Dictionary = {}
var post

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	RenderingServer.set_default_clear_color(Color.BLACK)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.background_canvas_max_layer = 10
	env.glow_enabled = true
	env.glow_intensity = 1.3
	env.glow_strength = 1.2
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.85
	env.glow_hdr_scale = 2.4
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.set("glow_levels/1", 0.5)
	env.set("glow_levels/2", 0.9)
	env.set("glow_levels/3", 1.0)
	env.set("glow_levels/4", 1.0)
	env.set("glow_levels/5", 0.9)
	env.set("glow_levels/6", 0.7)
	env.set("glow_levels/7", 0.0)
	we.environment = env
	add_child(we)
	post = PostFx.new()
	add_child(post)
	var fl := CanvasLayer.new()
	fl.layer = 100
	add_child(fl)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 1)
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fl.add_child(fade_rect)
	var args := OS.get_cmdline_user_args()
	if "--autotest" in args:
		var bot = load("res://scripts/dev/autotest.gd").new()
		bot.main = self
		add_child(bot)
		fade_rect.color.a = 0.0
		return
	show_menu()
	_fade_in()

func _fade_in() -> void:
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 0.0, 0.35)

# Blendet aus, führt cb aus, blendet wieder ein
func fade(cb: Callable) -> void:
	if fading:
		return
	fading = true
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, 0.25)
	await tw.finished
	cb.call()
	await get_tree().process_frame
	fading = false
	_fade_in()

func _swap(node: Node) -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	if current:
		current.queue_free()
	current = node
	add_child(node)

func show_menu() -> void:
	var m = MainMenu.new()
	m.start_run.connect(func(opts): fade(func(): start_run(opts)))
	m.quit_game.connect(func(): get_tree().quit())
	_swap(m)

func start_run(opts: Dictionary) -> void:
	last_opts = opts
	Run.start(opts)
	var g = Game.new()
	g.main = self
	g.quit_to_menu.connect(func(): fade(show_menu))
	g.restart_run.connect(func(): fade(func(): start_run(last_opts)))
	_swap(g)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if Run.active:
			Run.finish(false)
		Save.save_data()
