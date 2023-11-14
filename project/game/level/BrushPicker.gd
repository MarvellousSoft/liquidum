extends Control

signal brushed_picked(mode : E.BrushMode)

@export var editor_mode := false

@onready var Images = {
	"self": $Images,
	"water": $Images/Water,
	"boat": $Images/Boat,
	"wall": $Images/Wall,
}
@onready var ButtonsContainer = $Buttons
@onready var Buttons = {
	"water": $Buttons/Water,
	"boat": $Buttons/Boat,
	"wall": $Buttons/Wall,
}
@onready var AnimPlayer = $AnimationPlayer

func _ready():
	if not editor_mode:
		Images.wall.hide()
		Buttons.wall.hide()
	Buttons.water.connect("pressed", _on_button_pressed.bind(Buttons.water, E.BrushMode.Water))
	Buttons.boat.connect("pressed", _on_button_pressed.bind(Buttons.boat, E.BrushMode.Boat))
	Buttons.wall.connect("pressed", _on_button_pressed.bind(Buttons.wall, E.BrushMode.Wall))
	
	Buttons.water.button_pressed = true
	custom_minimum_size = ButtonsContainer.size
	AnimPlayer.play("startup")


func _on_button_pressed(pressed_button : TextureButton, mode : E.BrushMode):
	#Doing radio logic by hand since Godot`s isn`t working for some reason
	for button in Buttons.values():
		if button != pressed_button:
			button.button_pressed = false
	emit_signal("brushed_picked", mode)
