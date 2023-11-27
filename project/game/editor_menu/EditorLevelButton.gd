extends Control

signal open(id: String)
signal delete(id: String)

var id: String


func setup(id_: String, full_name: String) -> void:
	id = id_
	$OpenButton.text = full_name

func _on_open_button_pressed():
	open.emit(id)


func _on_delete_button_pressed():
	if ConfirmationScreen.start_confirmation():
		if await ConfirmationScreen.pressed:
			delete.emit(id)
