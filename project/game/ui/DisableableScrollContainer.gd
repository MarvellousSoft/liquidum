class_name DisableableScrollContainer
extends ScrollContainer

var disable_scroll: bool:
	set(on):
		disable_scroll = on
		var mode := ScrollContainer.SCROLL_MODE_SHOW_NEVER if on else ScrollContainer.SCROLL_MODE_AUTO
		vertical_scroll_mode = mode
		horizontal_scroll_mode = mode
	get:
		return disable_scroll

func _gui_input(_event):
	if disable_scroll:
		accept_event()
