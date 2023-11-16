extends TextureRect

signal pressed_main_button(i: int, j: int)
signal pressed_second_button(i: int, j: int)
signal mouse_entered_button(i: int, j: int)

var i : int
var j : int


func setup(new_i : int, new_j : int) -> void:
	i = new_i
	j = new_j


func _on_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					pressed_main_button.emit(i, j)
				MOUSE_BUTTON_RIGHT:
					pressed_second_button.emit(i, j)


func _on_mouse_entered():
	mouse_entered_button.emit(i, j)
