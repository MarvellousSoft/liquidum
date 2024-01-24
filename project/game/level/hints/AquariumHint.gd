extends HBoxContainer

const ALPHA_SPEED = 4.0
const HIDE_ALPHA = 0.5
const COLORS = {
	"normal": {
		"dark": Color(0, 0.035, 0.141),
		"bg": Color(0.851, 1, 0.886),
		"water_color": Color(0.671, 1, 0.82),
		"depth_color": Color(0.078, 0.365, 0.529),
		"ray_value": 0.3,
	},
	"dark": {
		"dark": Color(0.671, 1, 0.82),
		"bg": Color(0.035, 0.212, 0.349),
		"water_color": Color(0.671, 1, 0.82),
		"depth_color": Color(0.275, 0.812, 0.702),
		"ray_value": 1.0,
	}
}

@onready var AnimPlayer = $AnimationPlayer
@onready var VisibilityButton: TextureButton = %VisibilityButton
@onready var Size = %Size
@onready var MiddleSeparator = %MiddleSeparator
@onready var ExpectedAmount = %ExpectedAmount
@onready var CurrentAmount: Label = %CurrentAmount
@onready var LeftContainer = %LeftContainer
@onready var RightContainer = %RightContainer
@onready var Water = %Water

var aquarium_size: float

func _ready():
	Profile.dark_mode_toggled.connect(update_dark_mode)
	Water.material = Water.material.duplicate()
	Water.material.set_shader_parameter("level", 0.0)
	modulate.a = 0.0
	update_dark_mode(Profile.get_option("dark_mode"))

func _process(dt):
	if VisibilityButton.visible:
		for node in [LeftContainer, RightContainer]:
			if VisibilityButton.is_pressed():
				node.modulate.a = min(node.modulate.a + ALPHA_SPEED*dt, 1.0)
			else:
				node.modulate.a = max(node.modulate.a - ALPHA_SPEED*dt, HIDE_ALPHA)


func update_dark_mode(is_dark : bool) -> void:
	var colors = COLORS.dark if is_dark else COLORS.normal
	%Water.modulate = colors.dark
	%Water.material.set_shader_parameter("water_color", colors.water_color)
	%Water.material.set_shader_parameter("depth_color", colors.depth_color)
	%Water.material.set_shader_parameter("ray_value", colors.ray_value)


func startup(delay: float) -> void:
	if delay > 0:
		await get_tree().create_timer(delay).timeout
	AnimPlayer.play("startup")


func instant_startup() -> void:
	modulate.a = 1.0
	Water.material.set_shader_parameter("level", 0.5)


func should_be_visible() -> bool:
	return VisibilityButton.visible and VisibilityButton.is_pressed()


func set_should_be_visible(b: bool) -> void:
	VisibilityButton.set_pressed(b)


func set_values(aq_size: float, amount: int, current: int, editor_mode: bool) -> void:
	VisibilityButton.visible = editor_mode
	aquarium_size = aq_size
	Size.text = str(aq_size)
	ExpectedAmount.text = "x%d" % amount
	if editor_mode:
		MiddleSeparator.hide()
		CurrentAmount.hide()
	else:
		MiddleSeparator.show()
		CurrentAmount.text = "(%d)" % current
		CurrentAmount.show()
	if current < amount or editor_mode:
		CurrentAmount.add_theme_color_override("font_color", Global.COLORS.normal)
	elif current == amount:
		CurrentAmount.add_theme_color_override("font_color", Global.COLORS.satisfied)
	else:
		CurrentAmount.add_theme_color_override("font_color", Global.COLORS.error)
