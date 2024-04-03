extends Control

signal pressed(s : Node)

var idx

func setup(flair_data, new_idx):
	idx = new_idx
	%Flair.text = "  %s  " % flair_data.text
	%Flair.add_theme_color_override("font_color", flair_data.color)
	var contrast_color = Global.get_contrast_background(flair_data.color)
	%Flair.get_node("BG").modulate = contrast_color
	%Reason.text = flair_data.description


func press():
	$Button.set_pressed_no_signal(true)


func unpress():
	$Button.set_pressed_no_signal(false)


func _on_button_toggled(button_pressed):
	if button_pressed:
		pressed.emit(self)
	else:
		$Button.set_pressed_no_signal(true)
