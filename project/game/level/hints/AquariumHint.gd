extends HBoxContainer


@onready var AnimPlayer = $AnimationPlayer

func startup(delay : float) -> void:
	await get_tree().create_timer(delay).timeout
	AnimPlayer.play("startup")
