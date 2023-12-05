# What the user did in the level
class_name UserLevelSaveData

const VERSION = 1

var grid_data: Dictionary
var is_empty: bool
var mistakes: int
var timer_secs: float

var best_mistakes: int = -1
var best_time_secs: float = -1.0

func _init(grid_data_: Dictionary, is_empty_: bool, mistakes_: int, timer_secs_: float) -> void:
	grid_data = grid_data_
	is_empty = is_empty_
	mistakes = mistakes_
	timer_secs = timer_secs_

func get_data() -> Dictionary:
	return {
		version = VERSION,
		grid_data = grid_data,
		is_empty = is_empty,
		mistakes = mistakes,
		timer_secs = timer_secs,
		best_mistakes = best_mistakes,
		best_time_secs = best_time_secs,
	}


func is_solution_empty() -> bool:
	return is_empty


func is_completed() -> bool:
	return best_mistakes >= 0

func save_completion(mistakes_: int, time: float) -> void:
	mistakes = mistakes_
	timer_secs = timer_secs
	best_mistakes = mistakes if best_mistakes == -1 else min(best_mistakes, mistakes)
	best_time_secs = time if best_time_secs == -1. else min(best_time_secs, time)

static func load_data(data: Variant) -> UserLevelSaveData:
	if data == null:
		return null
	if data.version != VERSION:
		push_error("Invalid version %s, expected %d" % [data.version, VERSION])
		# If we ever change version, handle it here
	var new := UserLevelSaveData.new(data.grid_data, bool(data.is_empty), int(data.mistakes), float(data.timer_secs))
	new.best_mistakes = int(data.best_mistakes)
	new.best_time_secs = float(data.best_time_secs)
	return new
