class_name LevelData

const VERSION := 1

var full_name: String
var grid: GridModel

func get_data() -> Dictionary:
	return {
		version = VERSION,
		full_name = full_name,
		grid = grid.export_data(),
	}

func load_data(data: Dictionary) -> LevelData:
	if data.version != VERSION:
		push_error("Invalid version %s, expected %d" % [data.version, VERSION])
	var level := LevelData.new()
	level.full_name = data.full_name
	level.grid = GridModel.import_data(level.grid)
	return level
