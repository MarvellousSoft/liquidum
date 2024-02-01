class_name CursorManager

const X = 1

enum CursorMode {
	Normal,
	Water,
	NoWater,
	Boat,
	NoBoat,
	Wall,
	Block,
}

const IMAGES := [
	preload("res://assets/images/cursors/arrow-simple.png"),
	preload("res://assets/images/cursors/arrow-water.png"),
	preload("res://assets/images/cursors/arrow-nowater.png"),
	preload("res://assets/images/cursors/arrow-boat.png"),
	preload("res://assets/images/cursors/arrow-noboat.png"),
	preload("res://assets/images/cursors/arrow-wall.png"),
	preload("res://assets/images/cursors/arrow-block.png"),
]

static func set_cursor(mode: CursorMode) -> void:
	if Global.is_mobile:
		return
	Input.set_custom_mouse_cursor(IMAGES[mode])

static func reset_cursor() -> void:
	set_cursor(CursorMode.Normal)
