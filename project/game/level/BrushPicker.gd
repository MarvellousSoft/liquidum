extends Control

signal brushed_picked(mode : E.BrushMode)

var editor_mode := false
var active := true

@onready var Images = {
	"self": $CenterContainer/PanelContainer/Images,
	E.BrushMode.Water: $CenterContainer/PanelContainer/Images/Water,
	E.BrushMode.NoWater: $CenterContainer/PanelContainer/Images/NoWater,
	E.BrushMode.Boat: $CenterContainer/PanelContainer/Images/Boat,
	E.BrushMode.Wall: $CenterContainer/PanelContainer/Images/Wall,
	E.BrushMode.Block: $CenterContainer/PanelContainer/Images/Block,
}
@onready var ButtonsContainer = $CenterContainer/PanelContainer/Buttons
@onready var Buttons = {
	E.BrushMode.Water: $CenterContainer/PanelContainer/Buttons/Water,
	E.BrushMode.NoWater: $CenterContainer/PanelContainer/Buttons/NoWater,
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


func _input(event):
	if not active:
		return
	if event.is_action_pressed("pick_prev_brush"):
		pick_previous_brush()
	elif event.is_action_pressed("pick_next_brush"):
		pick_next_brush()


func disable():
	active = false
	hide()


func setup(editor_mode_: bool) -> void:
	editor_mode = editor_mode_
	for editor_button in [E.BrushMode.Wall, E.BrushMode.Block]:
		Images[editor_button].set_visible(editor_mode)
		Buttons[editor_button].set_visible(editor_mode)
	for button in Buttons.keys():
		Buttons[button].button_pressed = (button == E.BrushMode.Water)
	custom_minimum_size = ButtonsContainer.size


func enable_brush(brush_type : E.BrushMode) -> void:
	Images[brush_type].set_visible(true)
	Buttons[brush_type].set_visible(true)


func disable_brush(brush_type : E.BrushMode) -> void:
	Images[brush_type].set_visible(false)
	Buttons[brush_type].set_visible(false)


func pick_next_brush() -> void:
	var valid_buttons = []
	for button_key in Buttons.keys():
		var button_node = Buttons[button_key]
		if button_node.visible:
			valid_buttons.push_back(button_key)
	assert(not valid_buttons.is_empty(), "No brush visible to pick next")
	
	var i = 0
	for button_key in valid_buttons:
		var button_node = Buttons[button_key]
		i += 1
		if button_node.button_pressed:
			break
	i = i % valid_buttons.size()
	Buttons[valid_buttons[i]].button_pressed = true
	_on_button_pressed(valid_buttons[i])


func pick_previous_brush() -> void:
	var valid_buttons = []
	for button_key in Buttons.keys():
		var button_node = Buttons[button_key]
		if button_node.visible:
			valid_buttons.push_front(button_key)
	assert(not valid_buttons.is_empty(), "No brush visible to pick next")
	
	var i = 0
	for button_key in valid_buttons:
		var button_node = Buttons[button_key]
		i += 1
		if button_node.button_pressed:
			break
	i = i % valid_buttons.size()
	Buttons[valid_buttons[i]].button_pressed = true
	_on_button_pressed(valid_buttons[i])

func _on_button_pressed(mode: E.BrushMode):
	AudioManager.play_sfx("change_brush")
	# Doing radio logic by hand since Godot`s isn`t working for some reason
	for button in Buttons.keys():
		if button != mode:
			Buttons[button].button_pressed = false
	brushed_picked.emit(mode)
