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
	Brush,
	Eraser,
}

static var IMAGES: Array
static var DARK_IMAGES: Array

static var cur_mode := CursorMode.Normal

static func _static_init() -> void:
	if ProjectSettings.get_setting("liquidum/is_mobile"):
		return
	IMAGES = [
		load("res://assets/images/cursors/arrow-simple.png"),
		load("res://assets/images/cursors/arrow-water.png"),
		load("res://assets/images/cursors/arrow-nowater.png"),
		load("res://assets/images/cursors/arrow-boat.png"),
		load("res://assets/images/cursors/arrow-noboat.png"),
		load("res://assets/images/cursors/arrow-wall.png"),
		load("res://assets/images/cursors/arrow-block.png"),
		load("res://assets/images/cursors/arrow-brush.png"),
		load("res://assets/images/cursors/arrow-eraser.png"),
	]
	DARK_IMAGES = [
		load("res://assets/images/cursors/dark-arrow-simple.png"),
		load("res://assets/images/cursors/dark-arrow-water.png"),
		load("res://assets/images/cursors/dark-arrow-nowater.png"),
		load("res://assets/images/cursors/dark-arrow-boat.png"),
		load("res://assets/images/cursors/dark-arrow-noboat.png"),
		load("res://assets/images/cursors/dark-arrow-wall.png"),
		load("res://assets/images/cursors/dark-arrow-block.png"),
		load("res://assets/images/cursors/dark-arrow-brush.png"),
		load("res://assets/images/cursors/dark-arrow-eraser.png"),
	]

static func _dark_mode_toggled(_on: bool) -> void:
	set_cursor(cur_mode)

static func set_cursor(mode: CursorMode) -> void:
	if Global.is_mobile:
		return
	cur_mode = mode
	Input.set_custom_mouse_cursor(IMAGES[mode] if not Profile.get_option('dark_mode') else DARK_IMAGES[mode])

static func reset_cursor() -> void:
	set_cursor(CursorMode.Normal)
