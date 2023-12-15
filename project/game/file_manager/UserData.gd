class_name UserData

static var _current: UserData = null
static var _current_profile: String = ""

static func current() -> UserData:
	if _current == null or _current_profile != FileManager.current_profile:
		_current_profile = FileManager.current_profile
		_current = FileManager._load_user_data()
	return _current

static func save() -> void:
	FileManager._save_user_data(current())


const VERSION := 1

var random_levels_completed: Array[int]
var best_streak: int
var current_streak: int
var last_day: String

func _init(random_levels_completed_: Array[int], best_streak_: int, current_streak_: int, last_day_: String) -> void:
	random_levels_completed = random_levels_completed_
	best_streak = best_streak_
	current_streak = current_streak_
	last_day = last_day_

func get_data() -> Dictionary:
	return {
		version = VERSION,
		random_levels_completed = random_levels_completed,
		best_streak = best_streak,
		current_streak = current_streak,
		last_day = last_day,
	}

static func load_data(data_: Variant) -> UserData:
	var completed: Array[int] = []
	if data_ == null:
		for i in RandomHub.Difficulty.size():
			completed.append(0)
		return UserData.new(completed, 0, 0, "")
	var data: Dictionary = data_
	if data.version != VERSION:
		push_error("Invalid version %s, expected %d" % [data.version, VERSION])
	completed.assign(data.random_levels_completed)
	return UserData.new(completed, data.best_streak, data.current_streak, data.last_day)

