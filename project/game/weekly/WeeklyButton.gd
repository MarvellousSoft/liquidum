class_name WeeklyButton
extends RecurringMarathon

var l_gen := RandomLevelGenerator.new()

var curr_monday: String
var prev_monday: String
var deadline_str: String

func possible_flavors() -> Array[RandomFlavors.Flavor]:
	var arr: Array[RandomFlavors.Flavor] = []
	for i in 7:
		arr.append(i as RandomFlavors.Flavor)
	arr.append_array([RandomFlavors.Flavor.Basic, RandomFlavors.Flavor.Diagonals, RandomFlavors.Flavor.Everything])
	assert(arr.size() == marathon_size)
	return arr

func _init() -> void:
	tr_name = "WEEKLY"
	marathon_size = 10
	streak_max_mistakes = 5

func _day_strip_time(unixtime: int) -> String:
	var day_with_time := Time.get_date_string_from_unix_time(unixtime)
	return day_with_time.substr(0, day_with_time.find('T'))

func _update() -> void:
	var now_unix_ok_tz := RecurringMarathon._unixtime_ok_timezone()
	var now_dict := Time.get_datetime_dict_from_unix_time(now_unix_ok_tz)
	var days_back_till_monday: int = (now_dict.weekday - Time.WEEKDAY_MONDAY + 7) % 7
	curr_monday = _day_strip_time(now_unix_ok_tz - days_back_till_monday * 24 * 60 * 60)
	prev_monday = _day_strip_time(now_unix_ok_tz - (days_back_till_monday + 7) * 24 * 60 * 60)
	deadline_str = _day_strip_time(now_unix_ok_tz + (-days_back_till_monday + 6) * 24 * 60 * 60)
	deadline_str += "T23:59:59"
	super()

func generate_level(marathon_i: int) -> LevelData:
	var rng := RandomNumberGenerator.new()
	rng.seed = RandomHub.consistent_hash(curr_monday)
	# Here, use rng for stuff that only changes weekly
	var flavors := possible_flavors()
	Global.shuffle(flavors, rng)
	# And now, rng for this specific level
	rng.seed = RandomHub.consistent_hash("%s_%02d" % [curr_monday, marathon_i])
	var g := await RandomFlavors.gen(l_gen, rng, flavors[marathon_i - 1])
	if g != null:
		var full_name := "%s (%d⁄%d)" % [tr("WEEKLY_LEVEL"), marathon_i, marathon_size]
		return LevelData.new(full_name, "", g.export_data(), "")
	return null

func share_text(mistakes: int, secs: int, marathon_i: int) -> String:
	var mistakes_str: String = DailyButton._mistakes_str(mistakes)
	var text: String
	if marathon_i == marathon_size:
		text = "%s %s" % [tr(&"WEEKLY_SHARE_COMPLETE"), DailyButton._today()]
	else:
		text = tr(&"WEEKLY_SHARE_PARTIAL") % [DailyButton._today(), marathon_i, marathon_size]
	return "{text}\n\n🕑 {time} ({total})\n{mistakes} ({total})".format({
		text = text,
		today = DailyButton._today(),
		time = Level.time_str(secs),
		mistakes = mistakes_str,
		total = tr(&"TOTAL" if marathon_i == marathon_size else &"SO_FAR"),
	})

# Returns the string representation of the time when this marathon ends
func get_deadline() -> String:
	return deadline_str

func steam_current_leaderboard() -> String:
	return level_basename()

func steam_previous_leaderboard() -> String:
	return "weekly_%s" % [prev_monday]

func current_period() -> String:
	return curr_monday

func previous_period() -> String:
	return prev_monday
	
func level_basename() -> String:
	return "weekly_%s" % [curr_monday]

func steam_stats() -> Array[String]:
	return ["weekly"]

func google_leaderboard() -> String:
	return GooglePlayGameServices.ids.leaderboard_weekly_level_1h_mistake_penalty

func google_leaderboard_span() -> GooglePlayGameServices.TimeSpan:
	return GooglePlayGameServices.TimeSpan.TIME_SPAN_WEEKLY

func type() -> RecurringMarathon.Type:
	return RecurringMarathon.Type.Weekly
