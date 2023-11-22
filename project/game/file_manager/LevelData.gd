class_name LevelData

const VERSION := 1

var full_name: String
var grid_data: Dictionary

func _init(full_name_: String, grid_data_: Dictionary) -> void:
	full_name = full_name_
	grid_data = grid_data_

func get_data() -> Dictionary:
	return {
		version = VERSION,
		full_name = full_name,
		grid_data = grid_data,
	}

static func load_data(data: Variant) -> LevelData:
	if data == null:
		return null
	if data.version != VERSION:
		push_error("Invalid version %s, expected %d" % [data.version, VERSION])
	return LevelData.new(data.full_name, data.grid_data)

