class_name UserData

static var _current: UserData = null
static var _current_profile: String = ""

static func current() -> UserData:
	if _current == null or _current_profile != FileManager.current_profile:
		_current_profile = FileManager.current_profile
		_current = FileManager._load_user_data()
	return _current

static func save(also_stats := true) -> void:
	var data := current()
	if also_stats:
		data.save_stats()
	FileManager._save_user_data(data)

const VERSION := 8

var random_levels_completed: Array[int]
# Used to generate random levels in some order
var random_levels_created: Array[int]
var endless_completed: Array[int]
var endless_good: Array[int]
var endless_created: Array[int]
var monthly_good_dailies: Array[int]
# For now this is NOT correct for users that started the game before the 1.2.3 version
# It is just used for iOS. If we want to use for everything, we need to make some transition
# code that reads the data from Steam and Google.
var insane_good_levels: int
# [daily, weekly]
var best_streak: Array[int]
var current_streak: Array[int]
# Last "day" you won the daily/weekly
var last_day: Array[String]
var selected_flair: int
# Last marathon replayed. Used to replay weekly levels.
var replay_completed: Array[int]
# Leaderboard uploads to be deduplicated. String -> float
var ld_uploads: Dictionary
# Cached display name from PlayFab
var display_name: String
var allow_streak_skip_this_one_time: bool

func _init(random_levels_completed_: Array[int], random_levels_created_: Array[int], endless_completed_: Array[int], endless_good_: Array[int], endless_created_: Array[int], best_streak_: Array[int], current_streak_: Array[int], last_day_: Array[String], monthly_good_dailies_: Array[int], selected_flair_: int, insane_good_levels_: int, replay_completed_: Array[int], ld_uploads_: Dictionary, display_name_: String, allow_streak_skip_this_one_time_: bool) -> void:
	random_levels_completed = random_levels_completed_
	random_levels_created = random_levels_created_
	endless_completed = endless_completed_
	endless_good = endless_good_
	endless_created = endless_created_
	best_streak = best_streak_
	current_streak = current_streak_
	last_day = last_day_
	monthly_good_dailies = monthly_good_dailies_
	selected_flair = selected_flair_
	insane_good_levels = insane_good_levels_
	replay_completed = replay_completed_
	ld_uploads = ld_uploads_
	display_name = display_name_
	allow_streak_skip_this_one_time = allow_streak_skip_this_one_time_

func get_data() -> Dictionary:
	var d := {
		version = VERSION,
		random_levels_completed = random_levels_completed,
		random_levels_created = random_levels_created,
		endless_completed = endless_completed,
		endless_good = endless_good,
		endless_created = endless_created,
		best_streak = best_streak,
		current_streak = current_streak,
		last_day = last_day,
		monthly_good_dailies = monthly_good_dailies,
		selected_flair = selected_flair,
		insane_good_levels = insane_good_levels,
		replay_completed = replay_completed,
		ld_uploads = ld_uploads,
	}
	if display_name != "":
		d.display_name = display_name
	return d

func save_stats() -> void:
	var stats := StatsTracker.instance()
	await stats.set_random_levels(random_levels_completed)
	await stats.set_endless_completed(endless_completed)
	var all_endless_good: int = 0
	for g in endless_good:
		all_endless_good += g
	await stats.set_endless_good(all_endless_good)
	for type in RecurringMarathon.Type.values():
		await stats.set_recurring_streak(type, current_streak[type], best_streak[type])

func bump_endless_completed(section: int) -> void:
	while endless_completed.size() < section:
		endless_completed.append(0)
	endless_completed[section - 1] += 1

func bump_endless_good(section: int) -> void:
	while endless_good.size() < section:
		endless_good.append(0)
	endless_good[section - 1] += 1

func bump_insane_good() -> int:
	insane_good_levels += 1
	return insane_good_levels

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
	# It started in February 2024 = 0 idx
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
	var endless_g: Array[int] = []
	var endless_c: Array[int] = []
	var monthly: Array[int] = []
	var best_streak_a: Array[int] = [0, 0]
	var cur_streak_a: Array[int] = [0, 0]
	var last_day_a: Array[String] = ["", ""]
	var replay_completed_a: Array[int] = [0, 0]
	var allow_streak_skip := false
	if data_ == null:
		for i in RandomHub.Difficulty.size():
			completed.append(0)
			created.append(0)
		for i in ExtraLevelLister.count_all_game_sections(true):
			endless.append(0)
			endless_g.append(0)
			endless_c.append(0)
		return UserData.new(completed, created, endless, endless_g, endless_c, best_streak_a, cur_streak_a, last_day_a, monthly, -1, 0, replay_completed_a, {}, "", false)
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
	if data.version < 4:
		data.version = 4
		data.endless_good = data.endless_completed.duplicate()
	if data.version < 5:
		data.version = 5
		data.selected_flair = "none"
	if data.version < 6:
		data.version = 6
		data.insane_good_levels = 0
	if data.version < 7:
		data.version = 7
		data.replay_completed = [0, 0]
	if data.version < 8:
		# Only allow skip when updating, this doesn't actually get saved
		allow_streak_skip = true
		data.version = 8
		data.ld_uploads = {}
	if data.version != VERSION:
		push_error("Invalid version %s, expected %d" % [data.version, VERSION])
	completed.assign(data.random_levels_completed)
	created.assign(data.random_levels_created)
	endless.assign(data.endless_completed)
	endless_g.assign(data.endless_good)
	endless_c.assign(data.get("endless_created", []))
	monthly.assign(data.get("monthly_good_dailies", []))
	best_streak_a.assign(data.best_streak)
	cur_streak_a.assign(data.current_streak)
	last_day_a.assign(data.last_day)
	replay_completed_a.assign(data.replay_completed)
	return UserData.new(completed, created, endless, endless_g, endless_c, best_streak_a, cur_streak_a, last_day_a, monthly, int(data.selected_flair), data.insane_good_levels, replay_completed_a, data.ld_uploads, data.get("display_name", ""), allow_streak_skip)
