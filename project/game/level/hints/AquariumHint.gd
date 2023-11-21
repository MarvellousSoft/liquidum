extends HBoxContainer


@onready var AnimPlayer = $AnimationPlayer

func startup(delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	AnimPlayer.play("startup")

func set_values(size: float, amount: int, current: int, editor_mode: bool) -> void:
	$Size.text = str(size)
	$ExpectedAmount.text = "x%d" % amount
	$CurrentAmount.text = "(%d)" % current
	if current < amount or editor_mode:
		$CurrentAmount.add_theme_color_override("font_color", Global.COLORS.normal)
	elif current == amount:
		$CurrentAmount.add_theme_color_override("font_color", Global.COLORS.satisfied)
	else:
		$CurrentAmount.add_theme_color_override("font_color", Global.COLORS.error)
