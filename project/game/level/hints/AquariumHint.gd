extends HBoxContainer


@onready var AnimPlayer = $AnimationPlayer
@onready var CurrentAmount: Label = $CurrentAmount
@onready var VisibilityButton: TextureButton = %VisibilityButton

var aquarium_size: float

func startup(delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	AnimPlayer.play("startup")

func should_be_visible() -> bool:
	return VisibilityButton.visible and VisibilityButton.is_pressed()

func set_values(aq_size: float, amount: int, current: int, editor_mode: bool) -> void:
	VisibilityButton.visible = editor_mode
	aquarium_size = aq_size
	$Size.text = str(aq_size)
	$ExpectedAmount.text = "x%d" % amount
	if editor_mode:
		CurrentAmount.hide()
	else:
		CurrentAmount.text = "(%d)" % current
		CurrentAmount.show()
	if current < amount or editor_mode:
		CurrentAmount.add_theme_color_override("font_color", Global.COLORS.normal)
	elif current == amount:
		CurrentAmount.add_theme_color_override("font_color", Global.COLORS.satisfied)
	else:
		CurrentAmount.add_theme_color_override("font_color", Global.COLORS.error)
