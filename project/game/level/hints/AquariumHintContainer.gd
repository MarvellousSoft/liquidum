extends Control

const HINT_DELAY = .3

@onready var AnimPlayer = $AnimationPlayer
@onready var HintContainer = $PanelContainer/MarginContainer/VBox/HintContainer

func startup(delay : float) -> void:
	await get_tree().create_timer(delay).timeout
	AnimPlayer.play("startup")
	
	delay = HINT_DELAY
	for child in HintContainer.get_children():
		child.startup(delay)
		delay += HINT_DELAY 
