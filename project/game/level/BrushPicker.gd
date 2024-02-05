extends Control

const IMAGES = {
	"dark": {
		"no_boat": preload("res://assets/images/ui/brush/brish_picker_noboat_dark.png"),
		"picker_pressed": preload("res://assets/images/ui/brush/brush_picker_pressed_dark.png"),
		"picker_hover": preload("res://assets/images/ui/brush/brush_picker_hover_dark.png"),
	},
	"normal": {
		"no_boat": preload("res://assets/images/ui/brush/brish_picker_noboat.png"),
		"picker_pressed": preload("res://assets/images/ui/brush/brush_picker_pressed.png"),
		"picker_hover": preload("res://assets/images/ui/brush/brush_picker_hover.png"),
	}
}

signal brushed_picked(mode : E.BrushMode)

var editor_mode := false
var active := true

@onready var Images = {
	"self": $CenterContainer/PanelContainer/Images,
	E.BrushMode.Water: $CenterContainer/PanelContainer/Images/Water,
	E.BrushMode.NoWater: $CenterContainer/PanelContainer/Images/NoWater,
	E.BrushMode.Boat: $CenterContainer/PanelContainer/Images/Boat,
	E.BrushMode.NoBoat: $CenterContainer/PanelContainer/Images/NoBoat,
	E.BrushMode.Wall: $CenterContainer/PanelContainer/Images/Wall,
	E.BrushMode.Block: $CenterContainer/PanelContainer/Images/Block,
}
@onready var ButtonsContainer = $CenterContainer/PanelContainer/Buttons
@onready var Buttons = {
	E.BrushMode.Water: $CenterContainer/PanelContainer/Buttons/Water,
	E.BrushMode.NoWater: $CenterContainer/PanelContainer/Buttons/NoWater,
	E.BrushMode.Boat: $CenterContainer/PanelContainer/Buttons/Boat,
	E.BrushMode.NoBoat: $CenterContainer/PanelContainer/Buttons/NoBoat,
	E.BrushMode.Wall: $CenterContainer/PanelContainer/Buttons/Wall,
	E.BrushMode.Block: $CenterContainer/PanelContainer/Buttons/Block,
}
@onready var AnimPlayer = $AnimationPlayer

func _ready():
	Profile.dark_mode_toggled.connect(_on_dark_mode_changed)
	_on_dark_mode_changed(Profile.get_option("dark_mode"))
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
	if event is InputEventKey:
		if event.pressed and event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var valid := get_valid_buttons()
			if event.keycode - KEY_1 < valid.size():
				_on_button_pressed(valid[event.keycode - KEY_1])

func nowater_finger_anim(show: bool) -> void:
	if show:
		%NoWater/FingerAnim.show()
	else:
		%NoWater/FingerAnim.queue_free()

func disable():
	active = false
	hide()


func setup(editor_mode_: bool) -> void:
	editor_mode = editor_mode_
	for editor_button in [E.BrushMode.Wall, E.BrushMode.Block]:
		Images[editor_button].set_visible(editor_mode)
		Buttons[editor_button].set_visible(editor_mode)
	for editor_button in [E.BrushMode.NoWater, E.BrushMode.NoBoat]:
		Images[editor_button].set_visible(not editor_mode)
		Buttons[editor_button].set_visible(not editor_mode)
	for button in Buttons.keys():
		Buttons[button].button_pressed = (button == E.BrushMode.Water)
	custom_minimum_size = ButtonsContainer.size


func enable_brush(brush_type : E.BrushMode) -> void:
	Images[brush_type].set_visible(true)
	Buttons[brush_type].set_visible(true)


func disable_brush(brush_type : E.BrushMode) -> void:
	Images[brush_type].set_visible(false)
	Buttons[brush_type].set_visible(false)


func get_valid_buttons() -> Array[E.BrushMode]:
	var valid_buttons: Array[E.BrushMode] = []
	for button_key in Buttons.keys():
		var button_node = Buttons[button_key]
		if button_node.visible:
			valid_buttons.push_back(button_key)
	return valid_buttons


func pick_next_brush() -> void:
	var valid_buttons := get_valid_buttons()
	assert(not valid_buttons.is_empty(), "No brush visible to pick next")
	
	var i = 0
	for button_key in valid_buttons:
		var button_node = Buttons[button_key]
		i += 1
		if button_node.button_pressed:
			break
	i = i % valid_buttons.size()
	_on_button_pressed(valid_buttons[i])


func pick_previous_brush() -> void:
	var valid_buttons := get_valid_buttons()
	assert(not valid_buttons.is_empty(), "No brush visible to pick next")
	
	var i = 0
	for button_key in valid_buttons:
		var button_node = Buttons[button_key]
		i += 1
		if button_node.button_pressed:
			break
	i = i % valid_buttons.size()
	_on_button_pressed(valid_buttons[i])


func _on_button_pressed(mode: E.BrushMode):
	AudioManager.play_sfx("change_brush")
	if mode == E.BrushMode.NoWater and %NoWater.has_node("FingerAnim"):
		var player: AnimationPlayer = %NoWater/FingerAnim/AnimationPlayer
		if player.assigned_animation != "disappear":
			player.play(&"disappear")
	# Doing radio logic by hand since Godot`s isn`t working for some reason
	for button in Buttons.keys():
		Buttons[button].button_pressed = (button == mode)
	brushed_picked.emit(mode)


func _on_dark_mode_changed(is_dark):
	var color = Global.get_color(is_dark)
	var images = IMAGES.dark if is_dark else IMAGES.normal
	%Boat.modulate = color.dark
	%Wall.modulate = color.dark
	%Block.modulate = color.dark
	%Water.material.set_shader_parameter("water_color", color.water_color)
	%Water.material.set_shader_parameter("depth_color", color.depth_color)
	%Water.material.set_shader_parameter("ray_value", color.ray_value)
	%NoBoat.texture = images.no_boat
	for button in Buttons.values():
		button.texture_pressed = images.picker_pressed
		button.texture_hover = images.picker_hover


func _on_button_mouse_entered():
	AudioManager.play_sfx("button_hover")
