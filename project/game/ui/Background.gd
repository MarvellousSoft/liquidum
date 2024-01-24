extends CanvasLayer

const LERP_FACTOR = 4.0
const COLORS = {
	"dark_mode": {
		"top_color": Color("000924"),
		"bottom_color": Color("093659"),
	},
	"light_mode": {
		"top_color": Color("31b0b0"),
		"bottom_color": Color("46cfb3"),
	}
}
const CONSTS = {
	"desktop": {
		"window_size": Vector2(3840, 2160),
	},
	"mobile": {
		"window_size": Vector2(720, 1280),
	}
}
@onready var BG = $BG

var target_top_color
var target_bottom_color

func _ready():
	Profile.dark_mode_toggled.connect(_on_dark_mode_toggled)
	target_top_color = BG.material.get_shader_parameter("top_color")
	target_bottom_color = BG.material.get_shader_parameter("bottom_color")
	var data = CONSTS.desktop if not Global.is_mobile else CONSTS.mobile
	var ws = data.window_size
	BG.size = ws
	%Particles.position = Vector2(ws.x/2, ws.y + 200)
	var material = %Particles.process_material as ParticleProcessMaterial
	material.emission_box_extents.x = ws.x/2

func _process(dt):
	var top_color = BG.material.get_shader_parameter("top_color")
	var bottom_color = BG.material.get_shader_parameter("bottom_color")
	var lerp_ = clamp(LERP_FACTOR*dt, 0.0, 1.0)
	if top_color != target_top_color:
		top_color = top_color.lerp(target_top_color, lerp_)
		if top_color.is_equal_approx(target_top_color):
			top_color = target_top_color
		BG.material.set_shader_parameter("top_color", top_color)
	if bottom_color != target_bottom_color:
		bottom_color = bottom_color.lerp(target_bottom_color, lerp_)
		if bottom_color.is_equal_approx(target_bottom_color):
			bottom_color = target_bottom_color
		BG.material.set_shader_parameter("bottom_color", bottom_color)


func _on_dark_mode_toggled(dark_mode):
	var colors = COLORS.dark_mode if dark_mode else COLORS.light_mode
	target_top_color = colors.top_color
	target_bottom_color = colors.bottom_color
