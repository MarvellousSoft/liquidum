class_name CursorManager

const X = 1

enum CursorMode {
	Normal,
	Water,
	NoWater,
	Boat,
	NoBoat,
}

const IMAGES := [
	preload("res://assets/images/cursors/arrow-simple.png"),
	preload("res://assets/images/cursors/arrow-water.png"),
	preload("res://assets/images/cursors/arrow-nowater.png"),
	preload("res://assets/images/cursors/arrow-boat.png"),
	preload("res://assets/images/cursors/arrow-noboat.png"),
]

static func set_cursor(mode: CursorMode) -> void:
	print("Set cursor for %s " % CursorMode.find_key(mode))
	Input.set_custom_mouse_cursor(IMAGES[mode])

static func reset_cursor() -> void:
	set_cursor(CursorMode.Normal)
