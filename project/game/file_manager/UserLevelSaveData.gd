# What the user did in the level
class_name UserLevelSaveData

const VERSION = 1

var grid_data: Dictionary
var mistakes: int
var timer_secs: float

func _init(grid_data_: Dictionary, mistakes_: int, timer_secs_: float) -> void:
	grid_data = grid_data_
	mistakes = mistakes_
	timer_secs = timer_secs_

func get_data() -> Dictionary:
	return {
		version = VERSION,
		grid_data = grid_data,
		mistakes = mistakes,
		timer_secs = timer_secs,
	}

static func load_data(data: Variant) -> UserLevelSaveData:
	if data == null:
		return null
	if data.version != VERSION:
		push_error("Invalid version %s, expected %d" % [data.version, VERSION])
		# If we ever change version, handle it here
	var new := UserLevelSaveData.new(data.grid_data, int(data.mistakes), float(data.timer_secs))
	return new
