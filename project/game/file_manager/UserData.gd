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
	data.save_stats_to_steam()
	FileManager._save_user_data(data)


const VERSION := 2

var random_levels_completed: Array[int]
# Used to generate random levels in some order
var random_levels_created: Array[int]
var endless_completed: Array[int]
var best_streak: int
var current_streak: int
var last_day: String
var monthly_good_dailies: Array[int]

func _init(random_levels_completed_: Array[int], random_levels_created_: Array[int], endless_completed_: Array[int], best_streak_: int, current_streak_: int, last_day_: String, monthly_good_dailies_: Array[int]) -> void:
	random_levels_completed = random_levels_completed_
	random_levels_created = random_levels_created_
	endless_completed = endless_completed_
	best_streak = best_streak_
	current_streak = current_streak_
	last_day = last_day_
	monthly_good_dailies = monthly_good_dailies_

func get_data() -> Dictionary:
	return {
		version = VERSION,
		random_levels_completed = random_levels_completed,
		random_levels_created = random_levels_created,
		endless_completed = endless_completed,
		best_streak = best_streak,
		current_streak = current_streak,
		last_day = last_day,
		monthly_good_dailies = monthly_good_dailies,
	}

func save_stats_to_steam() -> void:
	if not SteamManager.enabled or not SteamManager.stats_received:
		return
	SteamStats.set_random_levels(random_levels_completed)
	SteamStats.set_endless_completed(endless_completed)
	SteamStats.set_current_streak(current_streak)

func bump_endless_completed(section: int) -> void:
	while endless_completed.size() < section:
		endless_completed.append(0)
	endless_completed[section - 1] += 1

func get_endless_completed(section: int) -> int:
	if endless_completed.size() < section:
		return 0
	return endless_completed[section - 1]

func _monthly_idx(date: String) -> int:
	var date_dict := Time.get_datetime_dict_from_datetime_string(date, false)
	# It started in February 2024
	return (date_dict.year - 2024) * 12 + (date_dict.month - 2)

func bump_monthy_good_dailies(date: String) -> int:
	var idx := _monthly_idx(date)
	while monthly_good_dailies.size() <= idx:
		monthly_good_dailies.append(0)
	monthly_good_dailies[idx] += 1
	return monthly_good_dailies[idx]

static func load_data(data_: Variant) -> UserData:
	var completed: Array[int] = []
	var created: Array[int] = []
	var endless: Array[int] = []
	var monthly: Array[int] = []
	if data_ == null:
		for i in RandomHub.Difficulty.size():
			completed.append(0)
			created.append(0)
		for i in ExtraLevelLister.count_all_game_sections():
			endless.append(0)
		return UserData.new(completed, created, endless, 0, 0, "", monthly)
	var data: Dictionary = data_
	if data.version < 2:
		data.version = 2
		for i in ExtraLevelLister.count_all_game_sections():
			endless.append(0)
		data.endless_completed = endless
	if data.version != VERSION:
		push_error("Invalid version %s, expected %d" % [data.version, VERSION])
	completed.assign(data.random_levels_completed)
	created.assign(data.random_levels_created)
	endless.assign(data.endless_completed)
	monthly.assign(data.get("monthly_good_dailies", []))
	return UserData.new(completed, created, endless, data.best_streak, data.current_streak, data.last_day, monthly)
