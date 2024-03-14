class_name UserData

static var _current: UserData = null
static var _current_profile: String = ""

static func current() -> UserData:
	if _current == null or _current_profile != FileManager.current_profile:
		_current_profile = FileManager.current_profile
		_current = FileManager._load_user_data()
	return _current

static func save() -> void:
	var data := current()
	data.save_stats()
	FileManager._save_user_data(data)


const VERSION := 3

var random_levels_completed: Array[int]
# Used to generate random levels in some order
var random_levels_created: Array[int]
var endless_completed: Array[int]
var endless_created: Array[int]
var monthly_good_dailies: Array[int]
enum { DAILY, WEEKLY }
# [daily, weekly]
var best_streak: Array[int]
var current_streak: Array[int]
var last_day: Array[String]

func _init(random_levels_completed_: Array[int], random_levels_created_: Array[int], endless_completed_: Array[int], endless_created_: Array[int], best_streak_: Array[int], current_streak_: Array[int], last_day_: Array[String], monthly_good_dailies_: Array[int]) -> void:
	random_levels_completed = random_levels_completed_
	random_levels_created = random_levels_created_
	endless_completed = endless_completed_
	endless_created = endless_created_
	best_streak = best_streak_
	current_streak = current_streak_
	last_day = last_day_
	monthly_good_dailies = monthly_good_dailies_
	print(best_streak)
	print(current_streak)

func get_data() -> Dictionary:
	return {
		version = VERSION,
		random_levels_completed = random_levels_completed,
		random_levels_created = random_levels_created,
		endless_completed = endless_completed,
		endless_created = endless_created,
		best_streak = best_streak,
		current_streak = current_streak,
		last_day = last_day,
		monthly_good_dailies = monthly_good_dailies,
	}

func save_stats() -> void:
	var stats := StatsTracker.instance()
	stats.set_random_levels(random_levels_completed)
	stats.set_endless_completed(endless_completed)
	stats.set_daily_streak(current_streak[DAILY], best_streak[WEEKLY])
	stats.set_weekly_streak(current_streak[DAILY], best_streak[WEEKLY])

func bump_endless_completed(section: int) -> void:
	while endless_completed.size() < section:
		endless_completed.append(0)
	endless_completed[section - 1] += 1

func get_endless_completed(section: int) -> int:
	if endless_completed.size() < section:
		return 0
	return endless_completed[section - 1]

func bump_endless_created(section: int) -> int:
	while endless_created.size() < section:
		endless_created.append(0)
	endless_created[section - 1] += 1
	return endless_created[section - 1]

func get_endless_created(section: int) -> int:
	if endless_created.size() < section:
		return 0
	return endless_created[section - 1]

func _monthly_idx(date: String) -> int:
	var date_dict := Time.get_datetime_dict_from_datetime_string(date, false)
	# It started in February 2024
	var idx: int = (date_dict.year - 2024) * 12 + (date_dict.month - 2)
	while monthly_good_dailies.size() <= idx:
		monthly_good_dailies.append(0)
	return idx

func bump_monthy_good_dailies(date: String) -> int:
	var idx := _monthly_idx(date)
	monthly_good_dailies[idx] += 1
	return monthly_good_dailies[idx]

static func load_data(data_: Variant) -> UserData:
	var completed: Array[int] = []
	var created: Array[int] = []
	var endless: Array[int] = []
	var endless_c: Array[int] = []
	var monthly: Array[int] = []
	var best_streak_a: Array[int] = [0, 0]
	var cur_streak_a: Array[int] = [0, 0]
	var last_day_a: Array[String] = ["", ""]
	if data_ == null:
		for i in RandomHub.Difficulty.size():
			completed.append(0)
			created.append(0)
		for i in ExtraLevelLister.count_all_game_sections(true):
			endless.append(0)
			endless_c.append(0)
		return UserData.new(completed, created, endless, endless_c, best_streak_a, cur_streak_a, last_day_a, monthly)
	var data: Dictionary = data_
	if data.version < 2:
		data.version = 2
		for i in ExtraLevelLister.count_all_game_sections():
			endless.append(0)
		data.endless_completed = endless
	if data.version < 3:
		data.version = 3
		data.best_streak = [data.best_streak, 0]
		data.current_streak = [data.current_streak, 0]
		data.last_day = [data.last_day, ""]
	if data.version != VERSION:
		push_error("Invalid version %s, expected %d" % [data.version, VERSION])
	completed.assign(data.random_levels_completed)
	created.assign(data.random_levels_created)
	endless.assign(data.endless_completed)
	endless_c.assign(data.get("endless_created", []))
	monthly.assign(data.get("monthly_good_dailies", []))
	best_streak_a.assign(data.best_streak)
	cur_streak_a.assign(data.current_streak)
	last_day_a.assign(data.last_day)
	return UserData.new(completed, created, endless, endless_c, best_streak_a, cur_streak_a, last_day_a, monthly)
