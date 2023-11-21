extends Control

signal brushed_picked(mode : E.BrushMode)

var editor_mode := false

@onready var Images = {
	"self": $CenterContainer/PanelContainer/Images,
	E.BrushMode.Water: $CenterContainer/PanelContainer/Images/Water,
	E.BrushMode.Boat: $CenterContainer/PanelContainer/Images/Boat,
	E.BrushMode.Wall: $CenterContainer/PanelContainer/Images/Wall,
	E.BrushMode.Block: $CenterContainer/PanelContainer/Images/Block,
}
@onready var ButtonsContainer = $CenterContainer/PanelContainer/Buttons
@onready var Buttons = {
	E.BrushMode.Water: $CenterContainer/PanelContainer/Buttons/Water,
	E.BrushMode.Boat: $CenterContainer/PanelContainer/Buttons/Boat,
	E.BrushMode.Wall: $CenterContainer/PanelContainer/Buttons/Wall,
	E.BrushMode.Block: $CenterContainer/PanelContainer/Buttons/Block,
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
