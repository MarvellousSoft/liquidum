class_name DisableableScrollContainer
extends ScrollContainer

var disable_scroll := false

func _gui_input(_event):
	if disable_scroll:
		accept_event()
