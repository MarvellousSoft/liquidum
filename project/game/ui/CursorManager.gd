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

const DARK_IMAGES := [
	preload("res://assets/images/cursors/dark-arrow-simple.png"),
	preload("res://assets/images/cursors/dark-arrow-water.png"),
	preload("res://assets/images/cursors/dark-arrow-nowater.png"),
	preload("res://assets/images/cursors/dark-arrow-boat.png"),
	preload("res://assets/images/cursors/dark-arrow-noboat.png"),
	preload("res://assets/images/cursors/dark-arrow-wall.png"),
	preload("res://assets/images/cursors/dark-arrow-block.png"),
]

static var cur_mode := CursorMode.Normal

static func _dark_mode_toggled(_on: bool) -> void:
	set_cursor(cur_mode)

static func set_cursor(mode: CursorMode) -> void:
	if Global.is_mobile:
		return
	cur_mode = mode
	Input.set_custom_mouse_cursor(IMAGES[mode] if not Profile.get_option('dark_mode') else DARK_IMAGES[mode])

static func reset_cursor() -> void:
	set_cursor(CursorMode.Normal)
