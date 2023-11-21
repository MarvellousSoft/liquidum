class_name LevelSaveData

const VERSION = 1

var grid: GridModel
var mistakes: int
var timer_secs: float

func get_data() -> Dictionary:
	return {
		version = VERSION,
		grid = grid.export_data(),
		mistakes = mistakes,
		timer_secs = timer_secs,
	}

static func load_data(data: Dictionary, load_mode: GridModel.LoadMode) -> LevelSaveData:
	if data.version != VERSION:
		push_error("Invalid version %s, expected %d" % [data.version, VERSION])
		# If we ever change version, handle it here
	var new := LevelSaveData.new()
	new.grid = GridImpl.import_data(data.grid, load_mode)
	new.mistakes = int(data.mistakes)
	new.timer_secs = float(data.timer_secs)
	return new
