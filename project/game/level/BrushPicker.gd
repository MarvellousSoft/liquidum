extends Control

signal brushed_picked(mode : E.BrushMode)

var editor_mode := false

@onready var BGs = {
	E.BrushMode.Water: $BGs/Water,
	E.BrushMode.Boat: $BGs/Boat,
	E.BrushMode.Wall: $BGs/Wall,
	E.BrushMode.Block: $BGs/Block,
}
@onready var Images = {
	"self": $Images,
	E.BrushMode.Water: $Images/Water,
	E.BrushMode.Boat: $Images/Boat,
	E.BrushMode.Wall: $Images/Wall,
	E.BrushMode.Block: $Images/Block,
}
@onready var ButtonsContainer = $Buttons
@onready var Buttons = {
	E.BrushMode.Water: $Buttons/Water,
	E.BrushMode.Boat: $Buttons/Boat,
	E.BrushMode.Wall: $Buttons/Wall,
	E.BrushMode.Block: $Buttons/Block,
}
@onready var AnimPlayer = $AnimationPlayer

func _ready():
	setup(editor_mode)
	for button in E.BrushMode.values():
		(Buttons[button] as TextureButton).pressed.connect(_on_button_pressed.bind(button))
	AnimPlayer.play("startup")

func setup(editor_mode_: bool) -> void:
	editor_mode = editor_mode_
	for editor_button in [E.BrushMode.Wall, E.BrushMode.Block]:
		BGs[editor_button].set_visible(editor_mode)
		Images[editor_button].set_visible(editor_mode)
		Buttons[editor_button].set_visible(editor_mode)
	for button in Buttons.keys():
		Buttons[button].button_pressed = (button == E.BrushMode.Water)
	custom_minimum_size = ButtonsContainer.size

func _on_button_pressed(mode: E.BrushMode):
	# Doing radio logic by hand since Godot`s isn`t working for some reason
	for button in Buttons.keys():
		if button != mode:
			Buttons[button].button_pressed = false
	brushed_picked.emit(mode)
