extends Control

signal brushed_picked(mode : E.BrushMode)

@onready var Buttons = {
	"water": $Buttons/Water,
	"boat": $Buttons/Boat
}

func _ready():
	Buttons.water.button_pressed = true


func _on_button_pressed(mode : E.BrushMode):
	emit_signal("brushed_picked", mode)
