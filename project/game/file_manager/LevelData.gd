class_name LevelData

const VERSION := 1

var full_name: String
var grid: GridModel

func _init(full_name_: String, grid_: GridModel) -> void:
	full_name = full_name_
	grid = grid_

func get_data() -> Dictionary:
	return {
		version = VERSION,
		full_name = full_name,
		grid = grid.export_data(),
	}

func load_data(data: Dictionary) -> LevelData:
	if data.version != VERSION:
		push_error("Invalid version %s, expected %d" % [data.version, VERSION])
	return LevelData.new(data.full_name, GridModel.import_data(data.grid))

