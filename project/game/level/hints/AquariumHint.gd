extends HBoxContainer

const ALPHA_SPEED = 4.0
const HIDE_ALPHA = 0.5

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
	Water.material = Water.material.duplicate()
	Water.material.set_shader_parameter("level", 0.0)
	modulate.a = 0.0


func _process(dt):
	if VisibilityButton.visible:
		for node in [LeftContainer, RightContainer]:
			if VisibilityButton.is_pressed():
				node.modulate.a = min(node.modulate.a + ALPHA_SPEED*dt, 1.0)
			else:
				node.modulate.a = max(node.modulate.a - ALPHA_SPEED*dt, HIDE_ALPHA)


func startup(delay: float) -> void:
	if delay > 0:
		await get_tree().create_timer(delay).timeout
	AnimPlayer.play("startup")


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
