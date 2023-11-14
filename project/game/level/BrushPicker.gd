extends Control

signal brushed_picked(mode : E.BrushMode)


@onready var Buttons = {
	"self": $Buttons,
	"water": $Buttons/Water,
	"boat": $Buttons/Boat
}
@onready var AnimPlayer = $AnimationPlayer

func _ready():
	Buttons.water.button_pressed = true
	custom_minimum_size = Buttons.self.size
	AnimPlayer.play("startup")


func _on_button_pressed(mode : E.BrushMode):
	emit_signal("brushed_picked", mode)
