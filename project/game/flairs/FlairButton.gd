class_name FlairButton
extends Control

signal pressed(s: Node)

var id

func setup(flair_data):
	id = flair_data.id
	%Flair.text = "  %s  " % flair_data.text
	flair_data.apply_to_label(%Flair)
	%Reason.text = flair_data.description


func press():
	$Button.set_pressed_no_signal(true)


func unpress():
	$Button.set_pressed_no_signal(false)

func is_pressed() -> bool:
	return $Button.button_pressed


func _on_button_toggled(_button_pressed: bool) -> void:
	pressed.emit(self)
