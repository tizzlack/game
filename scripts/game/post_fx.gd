# Bildschirm-Nachbearbeitung: Vignette, leichte chromatische Aberration (stärker bei Treffern), feine Scanlines, Körnung.
extends CanvasLayer

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float aberration = 0.0012;
uniform float hit = 0.0;
uniform float vignette = 0.3;
uniform float scan = 0.0;
uniform float grain = 0.0;
uniform float t = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - 0.5;
	float ab = aberration + hit * 0.007;
	vec3 col;
	col.r = texture(screen_tex, uv + d * ab * 2.0).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - d * ab * 2.0).b;
	float v = smoothstep(0.9, 0.2, length(d * vec2(1.0, 0.85)));
	col *= mix(1.0 - vignette, 1.0, v);
	col *= 1.0 - scan * (0.5 + 0.5 * sin(FRAGCOORD.y * 1.6));
	col += (hash(FRAGCOORD.xy + vec2(t * 60.0, t * 37.0)) - 0.5) * grain;
	col.r += hit * 0.06 * (1.0 - v);
	COLOR = vec4(col, 1.0);
}
"""

var rect: ColorRect
var mat: ShaderMaterial
var hit := 0.0
var t := 0.0

func _ready() -> void:
	layer = 4
	process_mode = Node.PROCESS_MODE_ALWAYS
	rect = ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER
	mat = ShaderMaterial.new()
	mat.shader = sh
	rect.material = mat
	add_child(rect)

func kick(amount: float) -> void:
	hit = minf(1.0, hit + amount)

func _process(delta: float) -> void:
	t += delta
	hit = maxf(0.0, hit - delta * 2.5)
	mat.set_shader_parameter("hit", hit)
	mat.set_shader_parameter("t", fmod(t, 100.0))
